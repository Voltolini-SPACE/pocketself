// PocketSelf — Reunião: escuta contínua, transcrição no aparelho, notas organizadas pelo motor (a cada bloco novo)
// e resumo final. Nada sai do iPhone. O áudio NÃO é guardado; só o texto, e só se você salvar.
// Limitação declarada: o iOS só mantém o microfone com o app aberto (a tela fica acesa durante a reunião).
import AVFoundation
import Speech
import SwiftUI
import UIKit
import CallKit

@Observable
@MainActor
final class Reuniao {
    enum Estado: Equatable { case pronta, ouvindo, pausada, resumindo, concluida }
    var estado = Estado.pronta
    var titulo = ""
    var segmentos: [String] = []
    var parcial = ""
    var segundos = 0
    var nivel: Float = 0
    var notas = NotasReuniao()
    var resumo = ""
    var aviso = ""
    var organizando = false
    let inicio = Date()

    @ObservationIgnored weak var motor: Motor?
    @ObservationIgnored private let reconhecedor = SFSpeechRecognizer(locale: Locale(identifier: "pt-BR"))
    @ObservationIgnored private let audio = AVAudioEngine()
    @ObservationIgnored private let caixa = CaixaPedido()
    @ObservationIgnored private var pedido: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var tarefa: SFSpeechRecognitionTask?
    @ObservationIgnored private var relogio: Task<Void, Never>?
    @ObservationIgnored private var ciclo: Task<Void, Never>?
    @ObservationIgnored private var processados = 0
    @ObservationIgnored private var geracao = UUID()
    @ObservationIgnored private var analise: AnyObject?       // CaixaAnalise (iOS 26+)
    @ObservationIgnored private var analisador: AnyObject?    // SpeechAnalyzer (iOS 26+)
    @ObservationIgnored private var leituraResultados: Task<Void, Never>?
    /// Qual motor de fala está em uso (aparece na tela e nos logs).
    var motorFala = ""

    var transcricao: String { ReuniaoLogica.transcricao(segmentos, parcial: parcial) }
    var palavras: Int { transcricao.split(separator: " ").count }

    /// Há uma ligação (telefone, FaceTime, WhatsApp…) em andamento? O iOS reserva o microfone para ela.
    static var emLigacao: Bool { CXCallObserver().calls.contains { !$0.hasEnded } }

    func iniciar() async {
        aviso = ""
        if Self.emLigacao {
            aviso = "Há uma ligação em andamento: o iPhone reserva o microfone para a chamada e nenhum app pode ouvir ou gravar a conversa. Encerre a ligação para usar a Reunião (e lembre-se de avisar os participantes)."
            print("[pocketself-reuniao] bloqueada: ligação em andamento"); return
        }
        let fala = await withCheckedContinuation { c in SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) } }
        let mic = await AVAudioApplication.requestRecordPermission()
        guard fala, mic else { aviso = "Libere o microfone e o reconhecimento de fala para o PocketSelf em Ajustes do iPhone."; return }
        guard let reconhecedor, reconhecedor.isAvailable else { aviso = "Reconhecimento em português indisponível neste aparelho."; return }
        if #available(iOS 26.0, *), await iniciarAnalisador() { return }
        if !reconhecedor.supportsOnDeviceRecognition { aviso = "Atenção: o reconhecimento no aparelho não está disponível; o iOS pode usar a rede." }
        motorFala = "SFSpeechRecognizer"
        do {
            let s = AVAudioSession.sharedInstance()
            try s.setCategory(.record, mode: .measurement)
            try s.setActive(true, options: .notifyOthersOnDeactivation)
            let entrada = audio.inputNode
            entrada.removeTap(onBus: 0)
            entrada.installTap(onBus: 0, bufferSize: 2048, format: entrada.outputFormat(forBus: 0)) { [weak self, caixa] b, _ in
                caixa.anexar(b)
                if let d = b.floatChannelData {
                    var q: Float = 0; let n = Int(b.frameLength)
                    for i in 0..<n { q += d[0][i] * d[0][i] }
                    let rms = n > 0 ? sqrt(q / Float(n)) : 0
                    Task { @MainActor in self?.nivel = min(rms * 8, 1) }
                }
            }
            audio.prepare(); try audio.start()
        } catch { aviso = "Não consegui abrir o microfone (\(error.localizedDescription)). Se outro app estiver usando o áudio, feche-o e tente de novo."; return }
        UIApplication.shared.isIdleTimerDisabled = true
        estado = .ouvindo
        novoTrecho()
        relogio = Task { [weak self] in while !Task.isCancelled { try? await Task.sleep(for: .seconds(1)); if self?.estado == .ouvindo { self?.segundos += 1 } } }
        // A cada 50 s fecha o trecho (o reconhecimento contínuo do iOS tem limite de duração) e organiza as notas.
        ciclo = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(50))
                guard let self, self.estado == .ouvindo else { continue }
                self.novoTrecho()
                await self.organizar()
            }
        }
        print("[pocketself-reuniao] inicio no_aparelho=\(reconhecedor.supportsOnDeviceRecognition)")
    }

    /// Caminho do iOS 26+: um único SpeechAnalyzer para a reunião inteira (sem reiniciar trechos).
    @available(iOS 26.0, *)
    private func iniciarAnalisador() async -> Bool {
        do {
            let t = try await TranscricaoLonga.transcritor(volatil: true)
            guard let formato = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [t]) else { return false }
            let (fluxo, cont) = AsyncStream<AnalyzerInput>.makeStream()
            let caixaA = CaixaAnalise(formato: formato, continuacao: cont)
            let a = SpeechAnalyzer(modules: [t])
            try await a.start(inputSequence: fluxo)
            let s = AVAudioSession.sharedInstance()
            try s.setCategory(.record, mode: .measurement)
            try s.setActive(true, options: .notifyOthersOnDeactivation)
            let entrada = audio.inputNode
            entrada.removeTap(onBus: 0)
            entrada.installTap(onBus: 0, bufferSize: 4096, format: entrada.outputFormat(forBus: 0)) { [weak self] b, _ in
                caixaA.anexar(b)
                if let d = b.floatChannelData {
                    var q: Float = 0; let n = Int(b.frameLength)
                    for i in 0..<n { q += d[0][i] * d[0][i] }
                    let rms = n > 0 ? sqrt(q / Float(n)) : 0
                    Task { @MainActor in self?.nivel = min(rms * 8, 1) }
                }
            }
            audio.prepare(); try audio.start()
            analise = caixaA; analisador = a; motorFala = "SpeechAnalyzer (iOS 26)"
            leituraResultados = Task { [weak self] in
                do {
                    for try await r in t.results {
                        let texto = String(r.text.characters)
                        await MainActor.run {
                            guard let self else { return }
                            if r.isFinal { if !texto.trimmingCharacters(in: .whitespaces).isEmpty { self.segmentos.append(texto) }; self.parcial = "" }
                            else { self.parcial = texto }
                        }
                    }
                } catch { await MainActor.run { self?.aviso = "Transcrição interrompida: \(error.localizedDescription)" } }
            }
            UIApplication.shared.isIdleTimerDisabled = true
            estado = .ouvindo
            relogio = Task { [weak self] in while !Task.isCancelled { try? await Task.sleep(for: .seconds(1)); if self?.estado == .ouvindo { self?.segundos += 1 } } }
            ciclo = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(60))
                    guard let self, self.estado == .ouvindo else { continue }
                    await self.organizar()
                }
            }
            print("[pocketself-reuniao] inicio motor=SpeechAnalyzer formato=\(formato.sampleRate)Hz")
            return true
        } catch {
            print("[pocketself-reuniao] SpeechAnalyzer indisponível: \(error.localizedDescription); usando SFSpeechRecognizer")
            return false
        }
    }

    /// Fecha o trecho atual e abre um novo pedido de reconhecimento, sem desligar o microfone.
    private func novoTrecho() {
        guard let reconhecedor else { return }
        let p = parcial.trimmingCharacters(in: .whitespacesAndNewlines)
        if !p.isEmpty { segmentos.append(p) }
        parcial = ""
        pedido?.endAudio(); tarefa?.cancel()
        let novo = SFSpeechAudioBufferRecognitionRequest()
        novo.shouldReportPartialResults = true
        novo.addsPunctuation = true
        novo.requiresOnDeviceRecognition = reconhecedor.supportsOnDeviceRecognition
        pedido = novo; caixa.trocar(novo)
        let id = UUID(); geracao = id
        tarefa = reconhecedor.recognitionTask(with: novo) { [weak self] r, e in
            let t = r?.bestTranscription.formattedString; let final = r?.isFinal ?? false
            Task { @MainActor in
                guard let self, self.geracao == id else { return }
                if let t { self.parcial = t }
                if final || e != nil, self.estado == .ouvindo { self.novoTrecho() }
            }
        }
    }

    func pausar() {
        guard estado == .ouvindo else { return }
        if #available(iOS 26.0, *), let c = analise as? CaixaAnalise { c.silenciar(true) } else { novoTrecho(); caixa.silenciar(true) }
        estado = .pausada
    }
    func retomar() {
        guard estado == .pausada else { return }
        if #available(iOS 26.0, *), let c = analise as? CaixaAnalise { c.silenciar(false) } else { caixa.silenciar(false) }
        estado = .ouvindo
    }

    /// Envia ao motor o texto ainda não organizado e incorpora as notas.
    func organizar() async {
        guard !organizando, let motor, motor.carregado != nil, !motor.gerando else { return }
        let completa = transcricao
        guard let bloco = ReuniaoLogica.blocoNovo(completa, processados: processados) else { return }
        organizando = true; defer { organizando = false }
        let t0 = Date()
        do {
            let r = try await motor.gerarTexto(ReuniaoLogica.pedidoNotas(bloco), instrucoes: ReuniaoLogica.instrucoes)
            notas.incorporar(ReuniaoLogica.lerNotas(r))
            processados = completa.count
            print(String(format: "[pocketself-reuniao] notas bloco=%d chars em %.1f s · itens=%d", bloco.count, Date().timeIntervalSince(t0), notas.pontos.count + notas.decisoes.count + notas.tarefas.count + notas.duvidas.count))
        } catch { aviso = "Não consegui organizar agora: \(error.localizedDescription)" }
    }

    /// Para de ouvir, organiza o que faltou e escreve o resumo final.
    func encerrar() async {
        relogio?.cancel(); ciclo?.cancel()
        if #available(iOS 26.0, *), let c = analise as? CaixaAnalise, let a = analisador as? SpeechAnalyzer {
            audio.inputNode.removeTap(onBus: 0); if audio.isRunning { audio.stop() }
            c.terminar()
            try? await a.finalizeAndFinishThroughEndOfInput()
            _ = await leituraResultados?.value
            analise = nil; analisador = nil
        }
        let p = parcial.trimmingCharacters(in: .whitespacesAndNewlines)
        if !p.isEmpty { segmentos.append(p) }
        parcial = ""; geracao = UUID()
        pedido?.endAudio(); tarefa?.cancel(); caixa.trocar(nil)
        audio.inputNode.removeTap(onBus: 0); if audio.isRunning { audio.stop() }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        UIApplication.shared.isIdleTimerDisabled = false
        estado = .resumindo
        await organizarTudo()
        if let motor, motor.carregado != nil, !transcricao.isEmpty {
            let t0 = Date()
            do {
                resumo = try await motor.gerarTexto(ReuniaoLogica.pedidoResumo(transcricao, notas: notas), instrucoes: "Você escreve resumos fiéis de reuniões, em português do Brasil.", maxTokens: 500)
                print(String(format: "[pocketself-reuniao] resumo em %.1f s (%d chars)", Date().timeIntervalSince(t0), resumo.count))
            } catch { aviso = "Não consegui escrever o resumo: \(error.localizedDescription)" }
        } else if motor?.carregado == nil {
            aviso = "Nenhum motor carregado: a transcrição foi guardada, mas notas e resumo precisam de um modelo."
        }
        estado = .concluida
        print("[pocketself-reuniao] fim duracao_s=\(segundos) palavras=\(palavras)")
    }

    /// Ao encerrar, organiza o restante mesmo que seja menor que um bloco.
    private func organizarTudo() async {
        guard let motor, motor.carregado != nil else { return }
        let completa = transcricao
        guard completa.count > processados else { return }
        let resto = String(completa.dropFirst(processados).suffix(ReuniaoLogica.maximoBloco))
        guard resto.split(separator: " ").count >= 8 else { return }
        if let r = try? await motor.gerarTexto(ReuniaoLogica.pedidoNotas(resto), instrucoes: ReuniaoLogica.instrucoes) {
            notas.incorporar(ReuniaoLogica.lerNotas(r)); processados = completa.count
        }
    }

    var markdown: String { ReuniaoLogica.markdown(titulo: titulo, data: inicio, segundos: segundos, notas: notas, resumo: resumo, transcricao: transcricao) }

    /// Salva em Documents/reunioes/ e devolve a URL (para compartilhar).
    func salvarArquivo() -> URL? {
        let pasta = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("reunioes")
        try? FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
        let url = pasta.appendingPathComponent(ReuniaoLogica.nomeArquivo(titulo: titulo, data: inicio))
        do { try markdown.write(to: url, atomically: true, encoding: .utf8); return url } catch { aviso = "Não consegui salvar: \(error.localizedDescription)"; return nil }
    }

    /// Validação pelo cabo: transcreve um arquivo de áudio (Documents/<nome>) como se fosse a reunião e gera notas e resumo.
    func processarArquivo(_ nome: String) async {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(nome)
        guard let reconhecedor else { return }
        titulo = titulo.isEmpty ? "Reunião de teste" : titulo
        estado = .ouvindo
        if #available(iOS 26.0, *) {
            let t0 = Date()
            do {
                let texto = try await TranscricaoLonga.arquivo(url)
                segmentos = texto.isEmpty ? [] : [texto]; segundos = Int(Date().timeIntervalSince(t0)); motorFala = "SpeechAnalyzer (iOS 26)"
                print(String(format: "[pocketself-reuniao] arquivo transcrito (SpeechAnalyzer) em %.1f s · %d palavras", Date().timeIntervalSince(t0), palavras))
                processados = 0; await organizar(); await encerrar()
                if let u = salvarArquivo() { print("[pocketself-reuniao] salvo \(u.lastPathComponent)\n\(markdown)") }
                return
            } catch { print("[pocketself-reuniao] SpeechAnalyzer falhou no arquivo: \(error.localizedDescription)") }
        }
        let r = SFSpeechURLRecognitionRequest(url: url)
        r.requiresOnDeviceRecognition = reconhecedor.supportsOnDeviceRecognition; r.addsPunctuation = true; r.shouldReportPartialResults = false
        let t0 = Date()
        let texto: String = await withCheckedContinuation { c in
            var feito = false
            reconhecedor.recognitionTask(with: r) { res, e in
                if feito { return }
                if let res, res.isFinal { feito = true; c.resume(returning: res.bestTranscription.formattedString) }
                else if e != nil { feito = true; c.resume(returning: "") }
            }
        }
        segmentos = texto.isEmpty ? [] : [texto]
        segundos = Int(Date().timeIntervalSince(t0))
        print(String(format: "[pocketself-reuniao] arquivo transcrito em %.1f s · %d palavras · no_aparelho=%d", Date().timeIntervalSince(t0), palavras, reconhecedor.supportsOnDeviceRecognition ? 1 : 0))
        processados = 0
        await organizar()
        await encerrar()
        if let u = salvarArquivo() { print("[pocketself-reuniao] salvo \(u.lastPathComponent)\n\(markdown)") }
    }
}

struct ReuniaoView: View {
    @Environment(\.dismiss) private var fechar
    @Environment(Motor.self) private var motor
    @Environment(Preferencias.self) private var prefs
    @Environment(Historico.self) private var historico
    @State private var r = Reuniao()
    @State private var aba = 0
    @State private var arquivo: URL?
    @State private var salvo = false
    var arquivoDeTeste: String? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                cabecalho
                Picker("", selection: $aba) { Text("Notas").tag(0); Text("Transcrição").tag(1); if !r.resumo.isEmpty { Text("Resumo").tag(2) } }
                    .pickerStyle(.segmented)
                ScrollView {
                    Group {
                        switch aba {
                        case 1: Text(r.transcricao.isEmpty ? "A transcrição aparece aqui enquanto as pessoas falam." : r.transcricao)
                        case 2: Text(r.resumo)
                        default: Text(.init(r.notas.vazia ? (r.organizando ? "Organizando as primeiras notas…" : "As notas são organizadas a cada minuto: pontos importantes, decisões, tarefas e dúvidas.") : ReuniaoLogica.markdownNotas(r.notas).replacingOccurrences(of: "### ", with: "**").replacingOccurrences(of: "\n- ", with: "\n• ")))
                        }
                    }
                    .font(.callout).foregroundStyle(Tema.texto).frame(maxWidth: .infinity, alignment: .leading).padding(14)
                }
                .background(Tema.superficie, in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(Tema.separador))
                if !r.aviso.isEmpty { Aviso(texto: r.aviso, cor: Tema.perigoTexto) }
                controles
            }
            .padding(Tema.margem)
            .background(Tema.fundo)
            .navigationTitle("Reunião").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fechar") { Task { if r.estado == .ouvindo || r.estado == .pausada { await r.encerrar() }; fechar() } } } }
            .task {
                r.motor = motor
                if let a = arquivoDeTeste { aba = 0; await r.processarArquivo(a); aba = 2 }
            }
        }
    }

    private var cabecalho: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Título da reunião", text: $r.titulo).font(.title3.weight(.bold)).foregroundStyle(Tema.texto)
            HStack(spacing: 10) {
                Circle().fill(r.estado == .ouvindo ? Tema.perigo : Tema.secundario).frame(width: 10, height: 10)
                Text(rotuloEstado).font(.footnote.weight(.semibold)).foregroundStyle(Tema.texto)
                Text(ReuniaoLogica.duracao(r.segundos)).font(.footnote.monospacedDigit()).foregroundStyle(Tema.secundario)
                Spacer()
                Text("\(r.palavras) palavras").font(.footnote).foregroundStyle(Tema.secundario)
            }
            if r.estado == .ouvindo {
                RoundedRectangle(cornerRadius: 2).fill(Tema.tinta(prefs.destaque)).frame(width: 30 + CGFloat(r.nivel) * 220, height: 5).animation(.linear(duration: 0.1), value: r.nivel)
            }
            if !r.motorFala.isEmpty { Text("Fala: \(r.motorFala)").font(.caption2).foregroundStyle(Tema.secundario) }
            Text("Tudo é transcrito e organizado neste iPhone, sem internet. O áudio não é guardado. Avise os participantes de que está anotando.")
                .font(.caption).foregroundStyle(Tema.secundario)
        }
    }

    private var rotuloEstado: String {
        switch r.estado {
        case .pronta: return "Pronta para ouvir"; case .ouvindo: return r.organizando ? "Ouvindo · organizando notas" : "Ouvindo"
        case .pausada: return "Pausada"; case .resumindo: return "Escrevendo o resumo…"; case .concluida: return "Concluída"
        }
    }

    @ViewBuilder private var controles: some View {
        switch r.estado {
        case .pronta:
            Button { Task { await r.iniciar() } } label: { Label("Começar a ouvir", systemImage: "mic.fill") }.buttonStyle(BotaoPrimario(cor: Tema.acao(prefs.destaque)))
        case .ouvindo, .pausada:
            HStack(spacing: 10) {
                Button { r.estado == .ouvindo ? r.pausar() : r.retomar() } label: { Label(r.estado == .ouvindo ? "Pausar" : "Retomar", systemImage: r.estado == .ouvindo ? "pause.fill" : "play.fill") }
                    .buttonStyle(BotaoSecundario())
                Button { Task { await r.encerrar(); aba = 2 } } label: { Label("Encerrar e resumir", systemImage: "checkmark") }
                    .buttonStyle(BotaoPrimario(cor: Tema.acao(prefs.destaque)))
            }
        case .resumindo:
            ProgressView("Organizando e resumindo no aparelho…").frame(maxWidth: .infinity)
        case .concluida:
            HStack(spacing: 10) {
                if let arquivo { ShareLink(item: arquivo) { Label("Compartilhar", systemImage: "square.and.arrow.up") }.buttonStyle(BotaoSecundario()) }
                Button {
                    arquivo = r.salvarArquivo()
                    let c = historico.nova()
                    historico.renomear(c.id, para: r.titulo.isEmpty ? "Reunião" : "Reunião: \(r.titulo)")
                    historico.anexar(Mensagem(deNEO: true, texto: r.markdown, nota: true), em: c.id)
                    salvo = true
                } label: { Label(salvo ? "Salvo no histórico" : "Salvar", systemImage: salvo ? "checkmark" : "tray.and.arrow.down") }
                    .buttonStyle(BotaoPrimario(cor: Tema.acao(prefs.destaque))).disabled(salvo)
            }
        }
    }
}
