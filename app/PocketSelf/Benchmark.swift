// PocketSelf — benchmark no próprio aparelho. Mede carga, primeira palavra (a frio e a quente), ritmo, memória e temperatura.
// Pelo app: Ajustes › Motor de IA › «Medir neste iPhone». Pelo cabo: `--benchmark=todos` (ou ids separados por vírgula);
// o resultado sai no console como `[pocketself-bench] {json}` e fica guardado no aparelho.
import Foundation

enum Benchmark {
    static let chave = "benchmarks"
    /// Pedido fixo e curto, para comparar aparelhos e motores.
    static let pedido = "Explique em três frases, em português do Brasil, por que o céu é azul."

    struct Resultado: Codable, Equatable {
        var motor: String, nome: String
        var aparelho: String, ramGB: Double, sistema: String, data: String
        var cargaS: Double, primeiraFrioMs: Double, primeiraQuenteMs: Double, tokS: Double, tokens: Int
        var pegadaMB: Int, livreMB: Int, termicoAntes: Int, termicoDepois: Int
    }

    static func identificadorDoAparelho() -> String {
        var u = utsname(); uname(&u)
        return withUnsafePointer(to: &u.machine) { $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) } }
    }

    static var todos: [String: Resultado] {
        guard let d = UserDefaults.standard.data(forKey: chave), let m = try? JSONDecoder().decode([String: Resultado].self, from: d) else { return [:] }
        return m
    }
    static func guardar(_ r: Resultado) {
        var m = todos; m[r.motor] = r
        if let d = try? JSONEncoder().encode(m) { UserDefaults.standard.set(d, forKey: chave) }
    }
    static func resumo(_ id: String) -> String? {
        guard let r = todos[id] else { return nil }
        return String(format: "medido aqui: %.1f tok/s · 1ª palavra %.1f s (a frio %.1f s) · carga %.0f s", r.tokS, r.primeiraQuenteMs / 1000, r.primeiraFrioMs / 1000, r.cargaS)
    }

    /// Carrega o motor, mede e guarda. Devolve nil se o modelo não está instalado ou falhou.
    @MainActor static func medir(_ info: MotorInfo, motor: Motor) async -> Resultado? {
        guard motor.instalado(info), info.pasta != nil || info.id == "apple", !motor.gerando else { return nil }
        let termicoAntes = ProcessInfo.processInfo.thermalState.rawValue
        let t0 = Date.timeIntervalSinceReferenceDate
        do {
            try await motor.carregar(info)
            let carga = Date.timeIntervalSinceReferenceDate - t0
            let m = try await motor.medirDesempenho()
            let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm"
            let r = Resultado(motor: info.id, nome: info.nome, aparelho: identificadorDoAparelho(),
                              ramGB: (Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824 * 10).rounded() / 10,
                              sistema: ProcessInfo.processInfo.operatingSystemVersionString, data: f.string(from: Date()),
                              cargaS: carga, primeiraFrioMs: m.frioMs, primeiraQuenteMs: m.quenteMs, tokS: m.tokS, tokens: m.tokens,
                              pegadaMB: Int(TesteOrquestra.pegadaMB()), livreMB: TesteOrquestra.livreMB(),
                              termicoAntes: termicoAntes, termicoDepois: ProcessInfo.processInfo.thermalState.rawValue)
            guardar(r)
            if let d = try? JSONEncoder().encode(r), let s = String(data: d, encoding: .utf8) { print("[pocketself-bench] \(s)") }
            return r
        } catch {
            print("[pocketself-bench] falhou \(info.id): \(error.localizedDescription)")
            return nil
        }
    }

    /// `--benchmark=todos|id1,id2`: roda em sequência e imprime um resumo.
    @MainActor static func rodarPorArgumento(motor: Motor) async {
        guard let arg = Preferencias.argumento("benchmark") else { return }
        let ids = arg == "todos" ? Motor.catalogo.filter { $0.pasta != nil || $0.id == "apple" }.map(\.id) : arg.split(separator: ",").map(String.init)
        for id in ids { if let info = motor.info(id) { _ = await medir(info, motor: motor) } }
        motor.descarregar()
        print("[pocketself-bench] fim")
    }
}
