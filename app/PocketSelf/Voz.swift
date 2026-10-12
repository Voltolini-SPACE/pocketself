// PocketSelf — conversa ao vivo: ouve em pt-BR no aparelho, responde pelo motor local e fala frase a frase.
// Conversa por voz com interrupção. Latência medida pelo projeto em 10/2026; meça no seu aparelho.
// O cancelamento de eco do iOS recusa neste aparelho (-10849): há plano B sem eco e filtro de eco por palavras.
import AVFoundation
import Speech
import SwiftUI

/// Pedido de reconhecimento compartilhado com a thread de áudio (o tap do microfone).
/// Converte o áudio para mono 16 kHz e registra o nível a cada ~1 s para diagnóstico pelo cabo.
final class CaixaPedido: @unchecked Sendable {
    private let trava = NSLock()
    private var pedido: SFSpeechAudioBufferRecognitionRequest?
    private let alvo = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!
    private var conversor: AVAudioConverter?
    private var origem: AVAudioFormat?
    private var amostras = 0
    private var somaQuadrados: Double = 0
    private var pico: Float = 0
    private var recebidos = 0
    /// Silenciado de verdade: nenhum quadro vai ao reconhecimento.
    private var silenciado = false

    var buffersRecebidos: Int { trava.lock(); defer { trava.unlock() }; return recebidos }
    func trocar(_ p: SFSpeechAudioBufferRecognitionRequest?) { trava.lock(); pedido = p; trava.unlock() }
    func silenciar(_ s: Bool) { trava.lock(); silenciado = s; trava.unlock() }

    func anexar(_ b: AVAudioPCMBuffer) {
        trava.lock(); recebidos += 1; let mudo = silenciado; let p = pedido; trava.unlock()
        medir(b)
        guard !mudo, let p else { return }
        if let convertido = converter(b) { p.append(convertido) }
    }

    private func converter(_ b: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        if origem == nil || origem! != b.format {
            origem = b.format
            conversor = AVAudioConverter(from: b.format, to: alvo)
        }
        guard let conversor else { return nil }
        let capacidade = AVAudioFrameCount(Double(b.frameLength) * alvo.sampleRate / b.format.sampleRate) + 256
        guard let saida = AVAudioPCMBuffer(pcmFormat: alvo, frameCapacity: capacidade) else { return nil }
        var entregue = false
        var erro: NSError?
        conversor.convert(to: saida, error: &erro) { _, status in
            if entregue { status.pointee = .noDataNow; return nil }
            entregue = true
            status.pointee = .haveData
            return b
        }
        return (erro == nil && saida.frameLength > 0) ? saida : nil
    }

    private func medir(_ b: AVAudioPCMBuffer) {
        guard let dados = b.floatChannelData else { return }
        let n = Int(b.frameLength)
        for i in 0..<n { let v = dados[0][i]; somaQuadrados += Double(v * v); pico = max(pico, abs(v)) }
        amostras += n
        if amostras >= Int(b.format.sampleRate) * 5 {
            print(String(format: "[neo-voz] microfone rms=%.4f pico=%.3f", sqrt(somaQuadrados / Double(amostras)), pico))
            amostras = 0; somaQuadrados = 0; pico = 0
        }
    }
}

@Observable
@MainActor
final class ConversaPorVoz: NSObject {
    enum Estado { case ocioso, ouvindo, pensando, falando }

    var estado = Estado.ocioso
    var emChamada = false
    var preparando = false
    var silenciado = false
    var ouvido = ""
    var aviso = ""
    var segundos = 0
    var ecoCancelado = false

    /// Ligações com o app: enviar um turno ao motor e observar a saída.
    @ObservationIgnored var enviar: ((String) -> Void)?
    @ObservationIgnored var saidaDoMotor: (() -> String)?
    @ObservationIgnored var motorGerando: (() -> Bool)?
    @ObservationIgnored var pararMotor: (() -> Void)?
    /// Voz neural escolhida em Ajustes (vazio = voz do sistema).
    @ObservationIgnored var vozNeural: () -> String = { "" }
    @ObservationIgnored private var filaNeural: Task<Void, Never>?

    @ObservationIgnored private let reconhecedor = SFSpeechRecognizer(locale: Locale(identifier: "pt-BR"))
    @ObservationIgnored private let motor = AVAudioEngine()
    @ObservationIgnored private let tocador = AVAudioPlayerNode()
    @ObservationIgnored private let mixerSilencioso = AVAudioMixerNode()
    @ObservationIgnored private let caixa = CaixaPedido()
    @ObservationIgnored private var pedido: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var tarefa: SFSpeechRecognitionTask?
    @ObservationIgnored private var idTarefa = UUID()
    @ObservationIgnored private var silencio: Task<Void, Never>?
    @ObservationIgnored private let sintetizador = AVSpeechSynthesizer()
    @ObservationIgnored private var leitor: Task<Void, Never>?
    @ObservationIgnored private var relogio: Task<Void, Never>?
    @ObservationIgnored private var motorPronto = false
    @ObservationIgnored private var formatoTocador: AVAudioFormat?
    @ObservationIgnored private var conversores: [String: AVAudioConverter] = [:]
    @ObservationIgnored private var falados = 0
    @ObservationIgnored private var frasesSintetizando = 0
    @ObservationIgnored private var buffersNaFila = 0
    @ObservationIgnored private var geracaoTerminou = false
    @ObservationIgnored private var fimDaFala: TimeInterval = 0
    @ObservationIgnored private var primeiraFala = true
    @ObservationIgnored private var faladoRecente = ""

    var voz: AVSpeechSynthesisVoice? {
        let vozes = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "pt-BR" }
        return vozes.max { $0.quality.rawValue < $1.quality.rawValue } ?? AVSpeechSynthesisVoice(language: "pt-BR")
    }

    var cronometro: String { String(format: "%02d:%02d", segundos / 60, segundos % 60) }

    /// Estado em texto (fonte da verdade para a tela; a animação é só apoio).
    var rotuloEstado: String {
        if silenciado && estado == .ouvindo { return "Microfone silenciado" }
        switch estado {
        case .ocioso: return preparando ? "Preparando" : "Microfone desligado"
        case .ouvindo: return "Ouvindo"
        case .pensando: return "Preparando resposta"
        case .falando: return "PocketSelf respondendo"
        }
    }
    var subtituloEstado: String {
        if silenciado && estado == .ouvindo { return "Nenhum áudio novo está sendo enviado." }
        switch estado {
        case .ocioso: return preparando ? "Abrindo o microfone…" : "Abrir esta tela não inicia a captura."
        case .ouvindo: return "Fale com naturalidade. Pausa de 1 s envia."
        case .pensando: return "Você pode interromper falando."
        case .falando: return ecoCancelado ? "Fale por cima para interromper." : "Sem cancelamento de eco: fale mais alto para interromper, ou toque em Parar."
        }
    }

    private func log(_ s: String) { print("[neo-voz] \(s)") }

    // MARK: Chamada

    func iniciarChamada() {
        guard !emChamada, !preparando else { return }
        preparando = true
        Task {
            let ok = await self.preparar()
            self.preparando = false
            guard ok else { return }
            self.emChamada = true
            self.silenciado = false
            self.caixa.silenciar(false)
            self.segundos = 0
            UIApplication.shared.isIdleTimerDisabled = true
            self.relogio = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    self?.segundos += 1
                }
            }
            self.estado = .ouvindo
            self.ouvido = ""
            self.novaEscuta()
            self.log("chamada iniciada")
        }
    }

    /// Encerrar é idempotente e vence qualquer estado: para captura e fala, invalida callbacks antigos.
    func encerrarChamada() {
        guard emChamada else { return }
        emChamada = false
        pararResposta(motivo: "fim da chamada")
        caixa.trocar(nil)
        pedido?.endAudio()
        tarefa?.cancel()
        idTarefa = UUID()
        silencio?.cancel()
        relogio?.cancel()
        estado = .ocioso
        silenciado = false
        UIApplication.shared.isIdleTimerDisabled = false
        log("chamada encerrada duracao_s=\(segundos)")
    }

    /// Mute real: os quadros do microfone deixam de ir ao reconhecimento; a saída continua controlada à parte.
    func alternarSilencio() {
        silenciado.toggle()
        caixa.silenciar(silenciado)
        if silenciado { silencio?.cancel(); ouvido = "" } else if estado == .ouvindo { novaEscuta() }
        log("silenciado=\(silenciado)")
    }

    func pararRespostaPeloBotao() {
        guard estado == .pensando || estado == .falando else { return }
        pararResposta(motivo: "botao")
        estado = .ouvindo
        ouvido = ""
    }

    // MARK: Áudio

    private func preparar() async -> Bool {
        aviso = ""
        let autorizado = await withCheckedContinuation { c in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) }
        }
        let microfone = await AVAudioApplication.requestRecordPermission()
        guard autorizado, microfone else {
            aviso = "O microfone ou o reconhecimento de fala está desativado para o PocketSelf. Você pode continuar escrevendo, ou liberar em Ajustes do iPhone."
            return false
        }
        guard let reconhecedor, reconhecedor.isAvailable else {
            aviso = "Reconhecimento em português indisponível neste momento."
            return false
        }
        if !reconhecedor.supportsOnDeviceRecognition {
            aviso = "O português ainda não está baixado no aparelho: a fala iria ao servidor da Apple (precisa de internet)."
        }
        guard !motorPronto else { return true }
        do {
            let sessao = AVAudioSession.sharedInstance()
            try sessao.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try sessao.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            aviso = "Falha ao abrir o áudio: \(error.localizedDescription)"
            log(aviso)
            return false
        }
        for comEco in [true, false] {
            do {
                try montarMotor(cancelamentoDeEco: comEco)
                let antes = caixa.buffersRecebidos
                try? await Task.sleep(for: .milliseconds(1500))
                let chegaram = caixa.buffersRecebidos - antes
                log("motor pronto eco=\(comEco) buffers_em_1_5s=\(chegaram) no_aparelho=\(reconhecedor.supportsOnDeviceRecognition) voz=\(voz?.identifier ?? "-") qualidade=\(voz?.quality.rawValue ?? 0)")
                if chegaram > 0 {
                    motorPronto = true
                    ecoCancelado = comEco
                    return true
                }
                desmontarMotor()
            } catch {
                log("falha ao montar motor eco=\(comEco): \(error.localizedDescription)")
                desmontarMotor()
            }
        }
        aviso = "O microfone não entregou áudio. Feche e abra o PocketSelf."
        return false
    }

    private func montarMotor(cancelamentoDeEco: Bool) throws {
        let entrada = motor.inputNode
        try entrada.setVoiceProcessingEnabled(cancelamentoDeEco)
        let formatoEntrada = entrada.outputFormat(forBus: 0)
        let taxa = motor.outputNode.outputFormat(forBus: 0).sampleRate
        let formato = AVAudioFormat(standardFormatWithSampleRate: taxa > 0 ? taxa : 48_000, channels: 1)!
        formatoTocador = formato
        if tocador.engine == nil { motor.attach(tocador) }
        if mixerSilencioso.engine == nil { motor.attach(mixerSilencioso) }
        motor.connect(tocador, to: motor.mainMixerNode, format: formato)
        motor.connect(entrada, to: mixerSilencioso, format: formatoEntrada)
        motor.connect(mixerSilencioso, to: motor.mainMixerNode, format: formatoEntrada)
        mixerSilencioso.outputVolume = 0
        entrada.removeTap(onBus: 0)
        let caixa = self.caixa
        entrada.installTap(onBus: 0, bufferSize: 1024, format: formatoEntrada) { buffer, _ in caixa.anexar(buffer) }
        motor.prepare()
        try motor.start()
    }

    private func desmontarMotor() {
        motor.inputNode.removeTap(onBus: 0)
        if motor.isRunning { motor.stop() }
        motor.reset()
    }

    private func novaEscuta() {
        guard let reconhecedor else { return }
        tarefa?.cancel()
        pedido?.endAudio()
        let novo = SFSpeechAudioBufferRecognitionRequest()
        novo.shouldReportPartialResults = true
        novo.addsPunctuation = true
        novo.requiresOnDeviceRecognition = reconhecedor.supportsOnDeviceRecognition
        pedido = novo
        caixa.trocar(novo)
        let id = UUID()
        idTarefa = id
        tarefa = reconhecedor.recognitionTask(with: novo) { [weak self] resultado, erro in
            let texto = resultado?.bestTranscription.formattedString
            let final = resultado?.isFinal ?? false
            let mensagemErro = erro?.localizedDescription
            Task { @MainActor in
                guard let self, self.idTarefa == id else { return }   // callback de sessão antiga é descartado
                self.aoReconhecer(texto: texto, final: final, erro: mensagemErro)
            }
        }
    }

    private func aoReconhecer(texto: String?, final: Bool, erro: String?) {
        guard emChamada else { return }
        if let texto {
            if silenciado { return }
            switch estado {
            case .ouvindo:
                ouvido = texto
                reiniciarSilencio()
                if final { encerrarTurno() }
            case .pensando, .falando:
                if palavras(texto).count >= 2, !pareceEco(texto) {
                    log("interrupcao ouvido=\(texto)")
                    pararResposta(motivo: "interrupcao")
                    estado = .ouvindo
                    ouvido = texto
                    reiniciarSilencio()
                }
            case .ocioso:
                break
            }
        } else if let erro {
            log("reconhecimento encerrado: \(erro)")
            if emChamada { novaEscuta() }
        }
    }

    private func palavras(_ s: String) -> [String] {
        s.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count > 1 }
    }

    private func pareceEco(_ s: String) -> Bool {
        let ouvidas = palavras(s)
        guard !ouvidas.isEmpty else { return true }
        let ditas = Set(palavras(faladoRecente))
        let iguais = ouvidas.filter { ditas.contains($0) }.count
        return Double(iguais) / Double(ouvidas.count) >= 0.6
    }

    private func reiniciarSilencio() {
        silencio?.cancel()
        silencio = Task { [weak self] in
            let n = self?.palavras(self?.ouvido ?? "").count ?? 0
            try? await Task.sleep(for: .milliseconds(n < 4 ? 1500 : 1100))
            guard !Task.isCancelled else { return }
            self?.encerrarTurno()
        }
    }

    // MARK: Turno

    private func encerrarTurno() {
        guard estado == .ouvindo else { return }
        silencio?.cancel()
        let texto = ouvido.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !texto.isEmpty else { return }
        fimDaFala = Date.timeIntervalSinceReferenceDate
        log("ouvido=\(texto)")
        novaEscuta()
        estado = .pensando
        falados = 0
        frasesSintetizando = 0
        buffersNaFila = 0
        geracaoTerminou = false
        primeiraFala = true
        faladoRecente = ""
        enviar?(texto)
        acompanharResposta()
    }

    private func acompanharResposta() {
        leitor?.cancel()
        leitor = Task { [weak self] in
            var comecou = false
            while !Task.isCancelled {
                guard let self else { return }
                let gerando = self.motorGerando?() ?? false
                if gerando { comecou = true }
                let terminou = comecou && !gerando
                self.falarFrasesProntas(de: self.saidaDoMotor?() ?? "", final: terminou)
                if terminou {
                    self.geracaoTerminou = true
                    self.verificarFim()
                    return
                }
                try? await Task.sleep(for: .milliseconds(80))
            }
        }
    }

    private func falarFrasesProntas(de texto: String, final: Bool) {
        guard estado == .pensando || estado == .falando else { return }
        let chars = Array(texto)
        guard falados < chars.count else { return }
        var corte = -1
        for i in falados..<chars.count where ".!?;:\n".contains(chars[i]) { corte = i }
        if corte < falados, chars.count - falados > 70 {
            for i in falados..<chars.count where chars[i] == "," && i - falados > 40 { corte = i; break }
        }
        if final { corte = chars.count - 1 }
        guard corte >= falados else { return }
        let frase = String(chars[falados...corte]).trimmingCharacters(in: .whitespacesAndNewlines)
        falados = corte + 1
        guard !frase.isEmpty else { return }
        falar(frase)
    }

    private func falar(_ frase: String) {
        let neural = vozNeural()
        if !neural.isEmpty, VozNeural.instalada {
            faladoRecente = String((faladoRecente + " " + frase).suffix(400))
            frasesSintetizando += 1
            let anterior = filaNeural
            filaNeural = Task { [weak self] in
                await anterior?.value                       // mantém a ordem das frases
                let b = await VozNeural.shared.sintetizar(frase, voz: neural)
                guard let self, !Task.isCancelled else { return }
                if let b { self.tocar(b) }
                self.tocar(AVAudioPCMBuffer(pcmFormat: VozNeural.shared.formato, frameCapacity: 1)!)   // fim da frase
            }
            return
        }
        let fala = AVSpeechUtterance(string: frase)
        fala.voice = voz
        fala.rate = AVSpeechUtteranceDefaultSpeechRate * 1.05
        faladoRecente = String((faladoRecente + " " + frase).suffix(400))
        frasesSintetizando += 1
        sintetizador.write(fala) { [weak self] buffer in
            guard let pcm = buffer as? AVAudioPCMBuffer else { return }
            let copia = Self.copiar(pcm)
            Task { @MainActor in self?.tocar(copia) }
        }
    }

    private static func copiar(_ b: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        guard b.frameLength > 0, let c = AVAudioPCMBuffer(pcmFormat: b.format, frameCapacity: b.frameLength) else { return b }
        c.frameLength = b.frameLength
        let n = Int(b.frameLength)
        if let o = b.floatChannelData, let d = c.floatChannelData {
            for ch in 0..<Int(b.format.channelCount) { d[ch].update(from: o[ch], count: n) }
        } else if let o = b.int16ChannelData, let d = c.int16ChannelData {
            for ch in 0..<Int(b.format.channelCount) { d[ch].update(from: o[ch], count: n) }
        } else if let o = b.int32ChannelData, let d = c.int32ChannelData {
            for ch in 0..<Int(b.format.channelCount) { d[ch].update(from: o[ch], count: n) }
        }
        return c
    }

    private func tocar(_ pcm: AVAudioPCMBuffer) {
        guard estado == .pensando || estado == .falando, let destino = formatoTocador else { return }
        if pcm.frameLength == 0 {
            frasesSintetizando = max(0, frasesSintetizando - 1)
            verificarFim()
            return
        }
        guard let convertido = converter(pcm, para: destino) else { return }
        if primeiraFala {
            primeiraFala = false
            log(String(format: "latencia_ate_primeira_frase_s=%.2f", Date.timeIntervalSinceReferenceDate - fimDaFala))
        }
        estado = .falando
        buffersNaFila += 1
        tocador.scheduleBuffer(convertido) { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.buffersNaFila = max(0, self.buffersNaFila - 1)
                self.verificarFim()
            }
        }
        if !tocador.isPlaying { tocador.play() }
    }

    private func converter(_ b: AVAudioPCMBuffer, para destino: AVAudioFormat) -> AVAudioPCMBuffer? {
        if b.format == destino { return b }
        let chave = "\(b.format.sampleRate)-\(b.format.commonFormat.rawValue)-\(b.format.channelCount)"
        let conv: AVAudioConverter
        if let c = conversores[chave] { conv = c } else {
            guard let c = AVAudioConverter(from: b.format, to: destino) else { return nil }
            conversores[chave] = c
            conv = c
        }
        let capacidade = AVAudioFrameCount(Double(b.frameLength) * destino.sampleRate / b.format.sampleRate) + 1024
        guard let saida = AVAudioPCMBuffer(pcmFormat: destino, frameCapacity: capacidade) else { return nil }
        var entregue = false
        var erro: NSError?
        conv.convert(to: saida, error: &erro) { _, status in
            if entregue { status.pointee = .noDataNow; return nil }
            entregue = true
            status.pointee = .haveData
            return b
        }
        return erro == nil ? saida : nil
    }

    private func verificarFim() {
        guard estado == .falando || estado == .pensando,
              geracaoTerminou, frasesSintetizando == 0, buffersNaFila == 0 else { return }
        log(String(format: "turno_total_s=%.2f", Date.timeIntervalSinceReferenceDate - fimDaFala))
        if emChamada {
            estado = .ouvindo
            ouvido = ""
        } else {
            estado = .ocioso
        }
    }

    private func pararResposta(motivo: String) {
        leitor?.cancel()
        leitor = nil
        if motorGerando?() ?? false { pararMotor?() }
        sintetizador.stopSpeaking(at: .immediate)
        filaNeural?.cancel()
        filaNeural = nil
        tocador.stop()
        frasesSintetizando = 0
        buffersNaFila = 0
        geracaoTerminou = false
        if !emChamada { estado = .ocioso }
        log("resposta parada motivo=\(motivo)")
    }
}
