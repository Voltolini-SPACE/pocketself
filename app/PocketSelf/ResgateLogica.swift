// PocketSelf — lógica pura do resgate (sem UIKit): padrão Morse do SOS e formatação de coordenadas. Testável no Mac.
import Foundation

enum Resgate {
    /// SOS em Morse: ··· −−− ··· (unidade de 0,25 s: ponto 1, traço 3, espaço entre símbolos 1, entre letras 3, entre repetições 7).
    static let unidade: UInt64 = 250_000_000

    /// Sequência (ligada?, unidades) de uma repetição de SOS.
    static func padraoSOS() -> [(ligada: Bool, unidades: Int)] {
        var p: [(Bool, Int)] = []
        func letra(_ pulsos: [Int]) { for (i, u) in pulsos.enumerated() { p.append((true, u)); if i < pulsos.count - 1 { p.append((false, 1)) } } }
        letra([1, 1, 1]); p.append((false, 3)); letra([3, 3, 3]); p.append((false, 3)); letra([1, 1, 1]); p.append((false, 7))
        return p
    }
    static func duracaoSegundos(repeticoes: Int) -> Double {
        Double(padraoSOS().reduce(0) { $0 + $1.unidades }) * Double(unidade) / 1_000_000_000 * Double(repeticoes)
    }
    static func formatar(latitude: Double, longitude: Double, precisao: Double, altitude: Double?) -> String {
        let ns = latitude >= 0 ? "N" : "S", lo = longitude >= 0 ? "L" : "O"
        func grau(_ v: Double) -> String { let a = abs(v), g = Int(a), m = Int((a - Double(g)) * 60), s = (a - Double(g) - Double(m) / 60) * 3600; return String(format: "%d°%02d′%04.1f″", g, m, s) }
        var t = String(format: "%.5f, %.5f", latitude, longitude) + " — \(grau(latitude)) \(ns), \(grau(longitude)) \(lo) (precisão de ±\(Int(precisao)) m"
        if let altitude { t += String(format: ", altitude %.0f m", altitude) }
        return t + ")"
    }
}
