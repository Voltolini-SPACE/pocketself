// PocketSelf — áudio avulso (gravar → revisar transcrição → enviar) e leitor de respostas em voz alta.
// Nada é transmitido: a transcrição é feita no aparelho; o envio é uma ação explícita.
import AVFoundation
import Speech
import SwiftUI

@Observable
@MainActor
final class GravacaoAvulsa {
    enum Estado { case preparado, gravando, revisao }
    var estado = Estado.preparado
    var transcricao = ""
    var aviso = ""
    var segundos = 0
    var nivel: Float = 0

    @ObservationIgnored private let reconhecedor = SFSpeechRecognizer(locale: Locale(identifier: "pt-BR"))
    @ObservationIgnored private let motor = AVAudioEngine()
    @ObservationIgnored private var pedido: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var tarefa: SFSpeechRecognitionTask?
    @ObservationIgnored private var relogio: Task<Void, Never>?
    @ObservationIgnored private var idTarefa = UUID()

    func iniciar() async {
        aviso = ""
        let fala = await withCheckedContinuation { c in SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) } }
        let mic = await AVAudioApplication.requestRecordPermission()
        guard fala, mic else { aviso = "O microfone ou o reconhecimento de fala está desativado para o PocketSelf. Você pode continuar escrevendo."; return }
        guard let reconhecedor, reconhecedor.isAvailable else { aviso = "Reconhecimento em português indisponível."; return }
        do {
            let sessao = AVAudioSession.sharedInstance()
            try sessao.setCategory(.record, mode: .measurement)
            try sessao.setActive(true, options: .notifyOthersOnDeactivation)
            let entrada = motor.inputNode
            let formato = entrada.outputFormat(forBus: 0)
            let novo = SFSpeechAudioBufferRecognitionRequest()
            novo.shouldReportPartialResults = true
            novo.addsPunctuation = true
            novo.requiresOnDeviceRecognition = reconhecedor.supportsOnDeviceRecognition
            pedido = novo
            entrada.removeTap(onBus: 0)
            entrada.installTap(onBus: 0, bufferSize: 1024, format: formato) { [weak self] buffer, _ in
                novo.append(buffer)
                if let d = buffer.floatChannelData {
                    var s: Float = 0; let n = Int(buffer.frameLength)
                    for i in 0..<n { s += d[0][i] * d[0][i] }
                    let rms = n > 0 ? sqrt(s / Float(n)) : 0
                    Task { @MainActor in self?.nivel = min(rms * 8, 1) }
                }
            }
            motor.prepare()
            try motor.start()
        } catch {
            aviso = "Falha ao abrir o microfone: \(error.localizedDescription)"
            return
        }
        transcricao = ""
        segundos = 0
        estado = .gravando
        let id = UUID(); idTarefa = id
        tarefa = reconhecedor.recognitionTask(with: pedido!) { [weak self] r, e in
            let t = r?.bestTranscription.formattedString
            Task { @MainActor in
                guard let self, self.idTarefa == id else { return }
                if let t { self.transcricao = t }
                if e != nil, self.estado == .gravando { self.parar() }
            }
        }
        relogio = Task { [weak self] in
            while !Task.isCancelled { try? await Task.sleep(for: .seconds(1)); self?.segundos += 1 }
        }
        print("[neo-voz] gravacao iniciada no_aparelho=\(reconhecedor.supportsOnDeviceRecognition)")
    }

    func parar() {
        relogio?.cancel()
        motor.inputNode.removeTap(onBus: 0)
        if motor.isRunning { motor.stop() }
        pedido?.endAudio()
        estado = .revisao
        // Dá 1 s ao reconhecimento para fechar a transcrição final; depois cancela a tarefa.
        let id = idTarefa
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard let self, self.idTarefa == id else { return }
            self.tarefa?.cancel()
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            print("[neo-voz] gravacao parada duracao_s=\(self.segundos) palavras=\(self.transcricao.split(separator: " ").count)")
        }
    }

    func descartar() {
        if estado == .gravando { parar() }
        idTarefa = UUID()
        tarefa?.cancel()
        transcricao = ""
        estado = .preparado
    }
}

/// Lê um texto em voz alta (ação deliberada do chat). Não abre microfone.
@Observable
@MainActor
final class Leitor: NSObject, AVSpeechSynthesizerDelegate {
    var lendo: UUID?
    @ObservationIgnored private let sintetizador = AVSpeechSynthesizer()
    @ObservationIgnored private let motorAudio = AVAudioEngine()
    @ObservationIgnored private let tocador = AVAudioPlayerNode()
    @ObservationIgnored private var tarefa: Task<Void, Never>?
    /// Voz neural (vazio = sistema), definida pelo app.
    @ObservationIgnored var vozNeural: () -> String = { "" }

    override init() { super.init(); sintetizador.delegate = self }

    func ler(_ texto: String, id: UUID) {
        parar()
        let neural = vozNeural()
        if !neural.isEmpty, VozNeural.instalada {
            lendo = id
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try? AVAudioSession.sharedInstance().setActive(true)
            if tocador.engine == nil { motorAudio.attach(tocador) }
            motorAudio.connect(tocador, to: motorAudio.mainMixerNode, format: VozNeural.shared.formato)
            try? motorAudio.start()
            let frases = texto.components(separatedBy: CharacterSet(charactersIn: ".!?\n")).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            tarefa = Task { [weak self] in
                for f in frases {
                    guard let self, !Task.isCancelled, self.lendo == id else { return }
                    if let b = await VozNeural.shared.sintetizar(f + ".", voz: neural) {
                        self.tocador.scheduleBuffer(b, completionHandler: nil)
                        if !self.tocador.isPlaying { self.tocador.play() }
                    }
                }
            }
            return
        }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        let f = AVSpeechUtterance(string: texto)
        let vozes = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "pt-BR" }
        f.voice = vozes.max { $0.quality.rawValue < $1.quality.rawValue } ?? AVSpeechSynthesisVoice(language: "pt-BR")
        f.rate = AVSpeechUtteranceDefaultSpeechRate * 1.05
        lendo = id
        sintetizador.speak(f)
    }

    func parar() {
        if sintetizador.isSpeaking { sintetizador.stopSpeaking(at: .immediate) }
        tarefa?.cancel(); tarefa = nil
        tocador.stop()
        lendo = nil
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        Task { @MainActor in self.lendo = nil }
    }
}

/// Folha de gravação avulsa: nada é enviado ao parar; o envio é o botão.
struct GravacaoSheet: View {
    @Environment(\.dismiss) private var fechar
    @Environment(Preferencias.self) private var prefs
    @State private var g = GravacaoAvulsa()
    var aoEnviar: (String) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Capsule().fill(Tema.separador).frame(width: 40, height: 5).padding(.top, 8)
            Text(g.estado == .revisao ? "Revise antes de enviar" : "Mensagem de áudio").font(.title3.weight(.bold)).foregroundStyle(Tema.texto)
            switch g.estado {
            case .preparado:
                Text("Microfone desligado. Toque para gravar; a transcrição é feita neste iPhone.").font(.footnote).foregroundStyle(Tema.secundario).multilineTextAlignment(.center)
                Button { Task { await g.iniciar() } } label: { Label("Gravar", systemImage: "mic.fill") }
                    .buttonStyle(BotaoPrimario(cor: Tema.acao(prefs.destaque), altura: 56))
            case .gravando:
                Text(String(format: "%02d:%02d", g.segundos / 60, g.segundos % 60)).font(.system(size: 32, weight: .bold, design: .rounded)).monospacedDigit().foregroundStyle(Tema.texto)
                RoundedRectangle(cornerRadius: 2).fill(Tema.tinta(prefs.destaque)).frame(width: 40 + CGFloat(g.nivel) * 200, height: 6).animation(.linear(duration: 0.1), value: g.nivel)
                    .accessibilityLabel("Nível do microfone")
                Text(g.transcricao.isEmpty ? "Ouvindo…" : g.transcricao).font(.callout).foregroundStyle(Tema.texto).frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14).background(Tema.superficie, in: RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Tema.separador))
                Button { g.parar() } label: { Label("Parar", systemImage: "stop.fill") }.buttonStyle(BotaoPrimario(cor: Tema.acao(prefs.destaque)))
            case .revisao:
                TextField("Transcrição", text: Binding(get: { g.transcricao }, set: { g.transcricao = $0 }), axis: .vertical)
                    .lineLimit(3...8).font(.callout).foregroundStyle(Tema.texto)
                    .padding(14).background(Tema.superficie, in: RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Tema.borda))
                Text("Editar o texto não altera o áudio; o áudio não é guardado.").font(.caption).foregroundStyle(Tema.secundario)
                Button {
                    let t = g.transcricao.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !t.isEmpty else { return }
                    aoEnviar(t); fechar()
                } label: { Label("Enviar", systemImage: "arrow.up") }
                    .buttonStyle(BotaoPrimario(cor: Tema.acao(prefs.destaque), altura: 56))
                    .disabled(g.transcricao.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Regravar") { g.descartar() }.buttonStyle(BotaoSecundario())
            }
            if !g.aviso.isEmpty { Aviso(texto: g.aviso, cor: Tema.perigoTexto) }
            Button("Descartar") { g.descartar(); fechar() }.font(.callout).foregroundStyle(Tema.perigoTexto).frame(minHeight: 44)
            Spacer()
        }
        .padding(.horizontal, Tema.margem)
        .background(Tema.fundo)
        .presentationDetents([.medium, .large])
        .onDisappear { g.descartar() }
    }
}
