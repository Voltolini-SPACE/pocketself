// Apoio comum dos testes de validação funcional (só Foundation). Compilado junto de cada arquivo de teste novo.
// Convenção: check = regressão (falha o teste); lacuna = comportamento que o app tem HOJE e que é um defeito/risco
// documentado em docs/VALIDACAO-FUNCIONAL.md (nunca falha: imprime se a lacuna continua ou foi corrigida).
import Foundation

enum T {
    nonisolated(unsafe) static var total = 0
    nonisolated(unsafe) static var falhas = 0
    nonisolated(unsafe) static var lacunas = 0

    static func check(_ ok: Bool, _ nome: String, _ detalhe: @autoclosure () -> String = "") {
        total += 1
        if !ok { falhas += 1 }
        print("\(ok ? "PASS" : "FAIL") \(nome)" + (ok ? "" : " :: \(detalhe())"))
    }

    /// `confirmada` = a lacuna ainda existe (o defeito descrito continua no app). Não conta como falha.
    static func lacuna(_ nome: String, confirmada: Bool, _ detalhe: String = "") {
        lacunas += 1
        print("\(confirmada ? "LACUNA" : "LACUNA-CORRIGIDA") \(nome)" + (detalhe.isEmpty ? "" : " :: \(detalhe)"))
    }

    static func fim(_ rotulo: String) -> Never {
        print("\(rotulo): \(total - falhas)/\(total) aprovados, \(lacunas) lacunas registradas")
        exit(falhas == 0 ? 0 : 1)
    }

    /// Lê um arquivo do repositório (os testes rodam com a raiz do repositório como diretório atual).
    static func ler(_ caminho: String) -> String {
        guard let s = try? String(contentsOfFile: caminho, encoding: .utf8) else {
            print("FAIL arquivo ilegível: \(caminho)"); exit(2)
        }
        return s
    }

    static func regex(_ padrao: String, em texto: String, grupo: Int = 1) -> [String] {
        guard let re = try? NSRegularExpression(pattern: padrao, options: [.dotMatchesLineSeparators]) else { return [] }
        let ns = texto as NSString
        return re.matches(in: texto, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range(at: grupo)) }
    }
}
