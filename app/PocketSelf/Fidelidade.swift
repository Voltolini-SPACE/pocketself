// PocketSelf — fidelidade ao que o usuário escreveu. Modelos pequenos às vezes «corrigem» ou trocam palavras ao
// repassar o texto de uma mensagem para a ferramenta (ex.: «chego» virou «cheiro»). Quando o pedido traz o texto
// literal depois de «dizendo:», «:», aspas etc. e o texto do modelo é só uma variação dele, usamos as palavras do usuário.
import Foundation

enum Fidelidade {
    /// Trecho literal que o usuário pediu para enviar, ou nil se o pedido não traz um.
    static func trechoLiteral(_ pedido: String) -> String? {
        let p = pedido.trimmingCharacters(in: .whitespacesAndNewlines)
        // 1) entre aspas
        if let r = p.range(of: #"["“«](.+?)["”»]"#, options: .regularExpression) {
            let t = String(p[r]).dropFirst().dropLast().trimmingCharacters(in: .whitespaces)
            if !t.isEmpty { return t }
        }
        // 2) depois de um marcador: «dizendo:», «dizendo que», «diga:», «escrevendo:», «com o texto», «com a mensagem», ou o último «:»
        let marcadores = [#"(?i)\b(?:dizendo|diga|dizer|escrevendo|escreva|avisando|avise)\s*:\s*"#, #"(?i)\b(?:com o texto|com a mensagem)\s*:?\s*"#, #":\s*"#]
        for m in marcadores {
            if let r = p.range(of: m, options: .regularExpression) {
                var t = String(p[r.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                while let u = t.last, ".!?".contains(u), t.count > 1, false { t.removeLast() }
                if !t.isEmpty, t.count <= 400 { return t }
            }
        }
        return nil
    }

    static func normalizar(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .components(separatedBy: CharacterSet.alphanumerics.inverted).joined(separator: " ")
            .split(separator: " ").joined(separator: " ")
    }

    /// Distância de edição normalizada (0 = igual, 1 = totalmente diferente).
    static func distancia(_ a: String, _ b: String) -> Double {
        let x = Array(a), y = Array(b)
        if x.isEmpty && y.isEmpty { return 0 }
        if x.isEmpty || y.isEmpty { return 1 }
        var linha = Array(0...y.count)
        for i in 1...x.count {
            var anterior = linha[0]; linha[0] = i
            for j in 1...y.count {
                let atual = linha[j]
                linha[j] = min(linha[j] + 1, linha[j - 1] + 1, anterior + (x[i - 1] == y[j - 1] ? 0 : 1))
                anterior = atual
            }
        }
        return Double(linha[y.count]) / Double(max(x.count, y.count))
    }

    /// O texto que deve ir para a mensagem: o literal do usuário quando o modelo só o variou; senão, o do modelo.
    static func textoFiel(modelo: String, pedido: String) -> String {
        guard let literal = trechoLiteral(pedido) else { return modelo }
        let a = normalizar(modelo), b = normalizar(literal)
        if a == b { return literal.trimmingCharacters(in: .whitespacesAndNewlines) == modelo.trimmingCharacters(in: .whitespacesAndNewlines) ? modelo : literal }
        // Só substitui quando é claramente a mesma frase com palavras trocadas (evita sobrescrever uma mensagem que o modelo
        // realmente compôs a partir de uma instrução como «avise que vou atrasar»).
        return distancia(a, b) <= 0.35 ? literal : modelo
    }

    /// Corrige citações na resposta do modelo («…» ou "…") que se parecem com o texto literal enviado, para o chat não
    /// mostrar uma versão diferente da que vai na mensagem (ex.: «cago» no lugar de «chego»).
    static func corrigirCitacoes(_ resposta: String, literal: String) -> String {
        let alvo = literal.trimmingCharacters(in: CharacterSet(charactersIn: " .!?"))
        guard !alvo.isEmpty, let re = try? NSRegularExpression(pattern: #"(["“«])([^"”»]{1,400})(["”»])"#) else { return resposta }
        var r = resposta
        for m in re.matches(in: resposta, range: NSRange(resposta.startIndex..., in: resposta)).reversed() {
            guard let faixa = Range(m.range(at: 2), in: resposta) else { continue }
            let citado = String(resposta[faixa])
            if normalizar(citado) != normalizar(alvo), distancia(normalizar(citado), normalizar(alvo)) <= 0.5, let fr = Range(m.range(at: 2), in: r) {
                r.replaceSubrange(fr, with: alvo)
            }
        }
        return r
    }
}
