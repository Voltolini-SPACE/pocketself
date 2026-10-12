// PocketSelf — transcrição longa no aparelho com o SpeechAnalyzer (iOS 26+), feito para reuniões e áudios longos.
// Abaixo do iOS 26 a Reunião usa o SFSpeechRecognizer com trechos reiniciados (Reuniao.swift).
import AVFoundation
import Speech

@available(iOS 26.0, *)
enum TranscricaoLonga {
    /// Transcritor pt-BR. Se o modelo de fala ainda não estiver no aparelho, pede a instalação (requer rede uma vez).
    static func transcritor(volatil: Bool) async throws -> SpeechTranscriber {
        let local = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "pt-BR")) ?? Locale(identifier: "pt-BR")
        let t = SpeechTranscriber(locale: local, transcriptionOptions: [], reportingOptions: volatil ? [.volatileResults] : [], attributeOptions: [])
        if let pedido = try await AssetInventory.assetInstallationRequest(supporting: [t]) { try await pedido.downloadAndInstall() }
        return t
    }

    /// Transcreve um arquivo inteiro e devolve o texto final.
    static func arquivo(_ url: URL) async throws -> String {
        let t = try await transcritor(volatil: false)
        let analisador = SpeechAnalyzer(modules: [t])
        let leitura = Task { () -> String in
            var partes: [String] = []
            for try await r in t.results where r.isFinal { partes.append(String(r.text.characters)) }
            return partes.joined(separator: " ")
        }
        let f = try AVAudioFile(forReading: url)
        if let fim = try await analisador.analyzeSequence(from: f) { try await analisador.finalizeAndFinish(through: fim) }
        else { await analisador.cancelAndFinishNow() }
        return try await leitura.value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Ponte entre o microfone (thread de áudio) e o SpeechAnalyzer: converte o formato e entrega os quadros.
@available(iOS 26.0, *)
final class CaixaAnalise: @unchecked Sendable {
    private let trava = NSLock()
    private var continuacao: AsyncStream<AnalyzerInput>.Continuation?
    private var conversor: AVAudioConverter?
    private var origem: AVAudioFormat?
    private var silenciado = false
    let formato: AVAudioFormat

    init(formato: AVAudioFormat, continuacao: AsyncStream<AnalyzerInput>.Continuation) { self.formato = formato; self.continuacao = continuacao }
    func silenciar(_ s: Bool) { trava.lock(); silenciado = s; trava.unlock() }
    func terminar() { trava.lock(); continuacao?.finish(); continuacao = nil; trava.unlock() }

    func anexar(_ b: AVAudioPCMBuffer) {
        trava.lock(); defer { trava.unlock() }
        guard !silenciado, let continuacao else { return }
        if origem == nil || origem! != b.format { origem = b.format; conversor = AVAudioConverter(from: b.format, to: formato) }
        guard let conversor else { return }
        let cap = AVAudioFrameCount(Double(b.frameLength) * formato.sampleRate / b.format.sampleRate) + 512
        guard let saida = AVAudioPCMBuffer(pcmFormat: formato, frameCapacity: cap) else { return }
        var entregue = false
        var erro: NSError?
        conversor.convert(to: saida, error: &erro) { _, estado in
            if entregue { estado.pointee = .noDataNow; return nil }
            entregue = true; estado.pointee = .haveData; return b
        }
        if erro == nil, saida.frameLength > 0 { continuacao.yield(AnalyzerInput(buffer: saida)) }
    }
}
