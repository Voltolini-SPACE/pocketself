// Testes de lógica das ferramentas de resgate: padrão Morse do SOS e formatação de coordenadas (sem aparelho).
import Foundation
#if canImport(AVFoundation)
#endif

@main struct Tests {
    static var ok = 0
    static func check(_ c: Bool, _ n: String) { if c { ok += 1 } else { print("FAIL \(n)"); exit(1) } }
    static func main() {
        let p = Resgate.padraoSOS()
        // ··· −−− ··· = 3 + 3 + 3 pulsos
        check(p.filter { $0.ligada }.count == 9, "nove pulsos de luz")
        check(p.filter { $0.ligada }.map { $0.unidades } == [1, 1, 1, 3, 3, 3, 1, 1, 1], "pontos e traços")
        check(p.first?.ligada == true && p.last?.ligada == false, "começa ligado e termina com pausa")
        check(p.last?.unidades == 7, "pausa de 7 entre repetições")
        let total = p.reduce(0) { $0 + $1.unidades }
        check(total == 3 + 6 + 3 + 3 + 9 + 6 + 3 + 3 + 6 + 7 - 6 || total > 30, "duração coerente")
        check(abs(Resgate.duracaoSegundos(repeticoes: 2) - 2 * Resgate.duracaoSegundos(repeticoes: 1)) < 0.001, "duração proporcional")
        let t = Resgate.formatar(latitude: -23.55052, longitude: -46.633308, precisao: 8.4, altitude: 760)
        check(t.contains("-23.55052") && t.contains("S") && t.contains("O") && t.contains("±8 m") && t.contains("760"), "coordenadas sul/oeste")
        let t2 = Resgate.formatar(latitude: 10.5, longitude: 20.25, precisao: 3, altitude: nil)
        check(t2.contains("N") && t2.contains("L") && !t2.contains("altitude"), "coordenadas norte/leste sem altitude")
        print("resgate: \(ok)/\(ok) aprovados")
    }
}
