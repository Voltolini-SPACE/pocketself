// PocketSelf — apresentação de texto sem alterar código ou valores monetários.
import Foundation

enum RespostaTexto {
    static func limpar(_ texto: String) -> String {
        // Blocos e trechos de código são literais, inclusive quando o bloco ainda não fechou.
        let codigo = try! NSRegularExpression(pattern: "```[\\s\\S]*?(?:```|\\z)|`[^`\\n]*`")
        let ns = texto as NSString
        var saida = ""
        var inicio = 0
        for trecho in codigo.matches(in: texto, range: NSRange(location: 0, length: ns.length)) {
            saida += limparProsa(ns.substring(with: NSRange(location: inicio, length: trecho.range.location - inicio)))
            saida += ns.substring(with: trecho.range)
            inicio = NSMaxRange(trecho.range)
        }
        saida += limparProsa(ns.substring(from: inicio))
        return saida
    }

    private static func limparProsa(_ texto: String) -> String {
        var x = texto
        // Só delimitadores identificados de matemática são retirados. R$, $HOME e $0 são literais.
        for padrao in ["\\$\\$([\\s\\S]*?)\\$\\$", "\\\\\\(([\\s\\S]*?)\\\\\\)", "\\\\\\[([\\s\\S]*?)\\\\\\]"] {
            x = substituir(x, padrao: padrao) { normalizarFormula($0[1]) }
        }
        x = substituir(x, padrao: "(?<![\\w\\\\])\\$([^$\\n]+)\\$") { grupos in
            let conteudo = grupos[1]
            let formula = conteudo.contains("\\") || conteudo.range(of: "^[A-Za-z0-9](?:\\^\\{?\\w+\\}?)?$", options: .regularExpression) != nil
                || (conteudo == conteudo.trimmingCharacters(in: .whitespaces) && conteudo.range(of: "[=^+*/]", options: .regularExpression) != nil && conteudo.range(of: "[A-Za-z0-9})]$", options: .regularExpression) != nil)
            return formula ? normalizarFormula(conteudo) : grupos[0]
        }
        x = normalizarFormula(x)
        x = x.replacingOccurrences(of: "(?m)^#{1,6} ", with: "", options: .regularExpression)
        return x.replacingOccurrences(of: "\\*\\*(?=\\S)(.+?)(?<=\\S)\\*\\*", with: "$1", options: .regularExpression)
    }

    private static func normalizarFormula(_ texto: String) -> String {
        var x = texto
        for (de, para) in [("\\times", "×"), ("\\approx", "≈"), ("\\cdot", "·"), ("\\div", "÷"), ("\\%", "%")] {
            x = x.replacingOccurrences(of: de, with: para)
        }
        x = x.replacingOccurrences(of: "\\\\frac\\{([^}]*)\\}\\{([^}]*)\\}", with: "($1)/($2)", options: .regularExpression)
        return x.replacingOccurrences(of: "\\^\\{([^}]*)\\}", with: "^$1", options: .regularExpression)
    }

    private static func substituir(_ texto: String, padrao: String, transformar: ([String]) -> String) -> String {
        let regex = try! NSRegularExpression(pattern: padrao)
        let ns = texto as NSString
        var resultado = texto
        for match in regex.matches(in: texto, range: NSRange(location: 0, length: ns.length)).reversed() {
            let grupos = (0..<match.numberOfRanges).map { ns.substring(with: match.range(at: $0)) }
            if let range = Range(match.range, in: resultado) { resultado.replaceSubrange(range, with: transformar(grupos)) }
        }
        return resultado
    }
}
