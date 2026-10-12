// PocketSelf — ferramentas de sobrevivência que funcionam SEM internet: sinal de SOS em luz (Morse na lanterna)
// e localização por GPS. O GPS do iPhone não depende de rede; só pode levar até ~1 minuto a céu aberto.
import Foundation
import AVFoundation
import CoreLocation

extension Resgate {
    nonisolated(unsafe) private static var tarefa: Task<Void, Never>?

    @MainActor static func sinalizarSOS(repeticoes: Int) -> String {
        guard let d = AVCaptureDevice.default(for: .video), d.hasTorch else { return "Este aparelho não tem lanterna disponível." }
        let n = max(1, min(repeticoes, 20))
        tarefa?.cancel()
        tarefa = Task {
            defer { try? d.lockForConfiguration(); d.torchMode = .off; d.unlockForConfiguration() }
            for _ in 0..<n {
                for passo in padraoSOS() {
                    if Task.isCancelled { return }
                    try? d.lockForConfiguration()
                    if passo.ligada { try? d.setTorchModeOn(level: 1) } else { d.torchMode = .off }
                    d.unlockForConfiguration()
                    try? await Task.sleep(nanoseconds: UInt64(passo.unidades) * unidade)
                }
            }
        }
        return String(format: "Sinal de SOS em luz iniciado: %d repetições (~%.0f s). Aponte a lanterna para o horizonte, para aviões ou barcos. Para parar, diga «pare o SOS» ou desligue a lanterna.", n, duracaoSegundos(repeticoes: n))
    }
    @MainActor static func pararSOS() -> String { tarefa?.cancel(); tarefa = nil; return Apps.lanterna(false) }
}

/// Localização por GPS, uma leitura só. Pede permissão «ao usar o app» na primeira vez.
@MainActor final class LocalizacaoUmaVez: NSObject, CLLocationManagerDelegate {
    private let gerente = CLLocationManager()
    private var continuacao: CheckedContinuation<String, Never>?
    private static var vivo: LocalizacaoUmaVez?

    static func obter(limite: TimeInterval = 40) async -> String {
        let l = LocalizacaoUmaVez(); vivo = l
        return await l.ler(limite: limite)
    }
    private func ler(limite: TimeInterval) async -> String {
        gerente.delegate = self
        gerente.desiredAccuracy = kCLLocationAccuracyBest
        switch gerente.authorizationStatus {
        case .denied, .restricted: Self.vivo = nil; return "Sem permissão de localização. Libere em Ajustes do iPhone › Privacidade › Serviços de Localização › PocketSelf."
        case .notDetermined: gerente.requestWhenInUseAuthorization()
        default: gerente.requestLocation()
        }
        Task { try? await Task.sleep(nanoseconds: UInt64(limite * 1_000_000_000)); self.concluir("Não consegui um sinal de GPS em \(Int(limite)) s. Vá para um lugar aberto, sem cobertura, e tente de novo.") }
        return await withCheckedContinuation { continuacao = $0 }
    }
    private func concluir(_ texto: String) { continuacao?.resume(returning: texto); continuacao = nil; Self.vivo = nil }
    nonisolated func locationManagerDidChangeAuthorization(_ g: CLLocationManager) {
        Task { @MainActor in
            switch g.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways: g.requestLocation()
            case .denied, .restricted: self.concluir("Sem permissão de localização. Libere em Ajustes do iPhone › Privacidade › Serviços de Localização › PocketSelf.")
            default: break
            }
        }
    }
    nonisolated func locationManager(_ g: CLLocationManager, didUpdateLocations l: [CLLocation]) {
        guard let x = l.last else { return }
        let t = Resgate.formatar(latitude: x.coordinate.latitude, longitude: x.coordinate.longitude, precisao: x.horizontalAccuracy, altitude: x.verticalAccuracy > 0 ? x.altitude : nil)
        Task { @MainActor in self.concluir("Localização por GPS (funciona sem internet): \(t). Anote ou transmita essas coordenadas ao resgate.") }
    }
    nonisolated func locationManager(_ g: CLLocationManager, didFailWithError e: Error) {
        Task { @MainActor in self.concluir("Não consegui a localização: \(e.localizedDescription)") }
    }
}
