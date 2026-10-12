// PocketSelf — voz neural Kokoro (82M, CoreML no Neural Engine, Apache-2.0). Fala em pt-BR com vozes pf_dora, pm_alex, pm_santa.
// Carrega uma vez da pasta Documents/modelos/Kokoro-82M-CoreML (copiada pelo cabo), sem internet.
import AVFoundation
import Foundation
import KokoroTTS

@MainActor
final class VozNeural {
    static let shared = VozNeural()
    static let vozes: [(id: String, nome: String)] = [("pf_dora", "Dora (feminina)"), ("pm_alex", "Alex (masculina)"), ("pm_santa", "Santa (masculina, grave)")]
    static var pasta: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("modelos/Kokoro-82M-CoreML") }
    static var instalada: Bool { FileManager.default.fileExists(atPath: pasta.appendingPathComponent("vocab_index.json").path) }

    private var modelo: KokoroTTSModel?
    private var carregando: Task<KokoroTTSModel?, Never>?
    let formato = AVAudioFormat(standardFormatWithSampleRate: 24_000, channels: 1)!

    func preparar() async -> Bool {
        if modelo != nil { return true }
        guard Self.instalada else { return false }
        if carregando == nil {
            carregando = Task {
                let t0 = Date.timeIntervalSinceReferenceDate
                do {
                    let m = try await KokoroTTSModel.fromPretrained(modelId: "local/kokoro", cacheDir: Self.pasta, offlineMode: true)
                    print(String(format: "[neo-voz] kokoro carregado em %.1f s", Date.timeIntervalSinceReferenceDate - t0))
                    return m
                } catch { print("[neo-voz] kokoro falhou ao carregar: \(error)"); return nil }
            }
        }
        modelo = await carregando?.value
        return modelo != nil
    }

    /// Sintetiza uma frase (fora da thread principal) e devolve o áudio pronto para tocar.
    func sintetizar(_ frase: String, voz: String) async -> AVAudioPCMBuffer? {
        guard await preparar(), let m = modelo else { return nil }
        let t0 = Date.timeIntervalSinceReferenceDate
        let amostras: [Float]? = await Task.detached(priority: .userInitiated) {
            try? m.synthesize(text: frase, voice: voz, language: "pt", speed: 1.0)
        }.value
        guard let amostras, !amostras.isEmpty, let b = AVAudioPCMBuffer(pcmFormat: formato, frameCapacity: AVAudioFrameCount(amostras.count)) else { return nil }
        b.frameLength = AVAudioFrameCount(amostras.count)
        amostras.withUnsafeBufferPointer { b.floatChannelData![0].update(from: $0.baseAddress!, count: amostras.count) }
        print(String(format: "[neo-voz] kokoro frase=%d chars audio=%.1f s em %.2f s", frase.count, Double(amostras.count) / 24_000, Date.timeIntervalSinceReferenceDate - t0))
        return b
    }
}
