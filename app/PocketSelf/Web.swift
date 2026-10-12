// PocketSelf — pesquisa e leitura da web. Só funciona com rede.
// Busca no DuckDuckGo Lite (sem chave, sem conta) e lê páginas convertendo HTML em texto.
// Conteúdo da web é dado, nunca instrução: o resultado vai marcado como «conteúdo externo».
import Foundation

enum Web {
    static let agente = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

    struct Resultado { let titulo: String; let url: String; let trecho: String }

    static func pesquisar(_ consulta: String, limite: Int = 5) async throws -> [Resultado] {
        var c = URLComponents(string: "https://lite.duckduckgo.com/lite/")!
        c.queryItems = [URLQueryItem(name: "q", value: consulta), URLQueryItem(name: "kl", value: "br-pt")]
        var req = URLRequest(url: c.url!, timeoutInterval: 12)
        req.setValue(agente, forHTTPHeaderField: "User-Agent")
        let (dados, _) = try await URLSession.shared.data(for: req)
        let html = String(decoding: dados, as: UTF8.self)
        // Linhas: <a rel="nofollow" href="URL" class='result-link'>TÍTULO</a> ... <td class='result-snippet'>TRECHO</td>
        let links = captura(html, #"<a[^>]+href="([^"]+)"[^>]*class=['"]result-link['"][^>]*>(.*?)</a>"#)
        let trechos = captura(html, #"<td[^>]*class=['"]result-snippet['"][^>]*>(.*?)</td>"#).map { $0[0] }
        var saida: [Resultado] = []
        for (i, l) in links.enumerated() where saida.count < limite {
            var url = l[0]
            if url.hasPrefix("//") { url = "https:" + url }
            if let u = URLComponents(string: url), let real = u.queryItems?.first(where: { $0.name == "uddg" })?.value { url = real }
            saida.append(Resultado(titulo: texto(de: l[1]), url: url, trecho: i < trechos.count ? texto(de: trechos[i]) : ""))
        }
        return saida
    }

    static func ler(_ endereco: String, limite: Int = 3500) async throws -> String {
        guard let url = URL(string: endereco), ["http", "https"].contains(url.scheme ?? "") else { return "Endereço inválido." }
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.setValue(agente, forHTTPHeaderField: "User-Agent")
        let (dados, resp) = try await URLSession.shared.data(for: req)
        let tipo = (resp as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type") ?? ""
        guard tipo.contains("html") || tipo.contains("text") else { return "Conteúdo não é texto (\(tipo))." }
        var html = String(decoding: dados.prefix(800_000), as: UTF8.self)
        let titulo = captura(html, #"<title[^>]*>(.*?)</title>"#).first.map { texto(de: $0[0]) } ?? ""
        for tag in ["script", "style", "noscript", "svg", "nav", "footer", "header", "form", "aside"] {
            html = html.replacingOccurrences(of: "<\(tag)[^>]*>[\\s\\S]*?</\(tag)>", with: " ", options: [.regularExpression, .caseInsensitive])
        }
        html = html.replacingOccurrences(of: "<(br|/p|/div|/li|/h[1-6]|/tr)[^>]*>", with: "\n", options: [.regularExpression, .caseInsensitive])
        let corpo = texto(de: html)
            .components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.count > 30 }
            .joined(separator: "\n")
        return "Título: \(titulo)\nEndereço: \(endereco)\n\n" + String(corpo.prefix(limite))
    }

    private static func captura(_ s: String, _ padrao: String) -> [[String]] {
        guard let re = try? NSRegularExpression(pattern: padrao, options: [.dotMatchesLineSeparators, .caseInsensitive]) else { return [] }
        let ns = s as NSString
        return re.matches(in: s, range: NSRange(location: 0, length: ns.length)).map { m in
            (1..<m.numberOfRanges).map { m.range(at: $0).location == NSNotFound ? "" : ns.substring(with: m.range(at: $0)) }
        }
    }

    static func texto(de html: String) -> String {
        var t = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        for (a, b) in [("&amp;", "&"), ("&quot;", "\""), ("&#x27;", "'"), ("&#39;", "'"), ("&lt;", "<"), ("&gt;", ">"), ("&nbsp;", " ")] { t = t.replacingOccurrences(of: a, with: b) }
        t = t.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: "\\n\\s*\\n+", with: "\n", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
