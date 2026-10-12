// PocketSelf Agente — lógica pura do laço (só Foundation): simplificar a árvore da tela, montar o pedido ao modelo,
// extrair a ação e a barreira de segurança. Roda no runner do iPhone e é testada no Mac (testes/).
import Foundation

struct No {
    var tipo: String, rotulo: String, valor: String
    var x: Double, y: Double, w: Double, h: Double
    var visivel = true
    var filhos: [No] = []
}

struct Elemento: Equatable {
    var n = 0
    var tipo: String, rotulo: String
    var x: Int, y: Int
    var valor: String
}

struct Acao: Equatable {
    var nome: String
    var n: Int? = nil, texto: String? = nil, direcao: String? = nil, bundle: String? = nil, resposta: String? = nil
}

enum Logica {
    static let tiposUteis: Set<String> = ["Button", "Cell", "TextField", "SecureTextField", "TextView", "SearchField", "Switch",
        "Link", "StaticText", "Image", "Tab", "TabBar", "Toggle", "Slider", "Picker", "PickerWheel", "Key", "Icon", "Other"]
    static let acoes: Set<String> = ["tocar", "digitar", "deslizar", "rolar", "abrir", "inicio", "voltar", "esperar", "fim"]
    static let irreversivel = try! NSRegularExpression(pattern:
        "\\b(enviar|send|comprar|buy|pagar|pay|excluir|apagar|delete|remover|remove|publicar|post|transferir|transfer|confirmar pedido|place order|finalizar|sair da conta|sign out|log out|logout|sair|redefinir|reset|apagar tudo|erase|ligar|chamar|call|aceitar|accept|assinar|sign|postar|tweetar|deletar|descartar|discard|desinstalar|uninstall|cancelar assinatura|unsubscribe|autorizar|authorize|permitir|allow|aprovar|approve|doar|donate|sacar|withdraw|pix|compartilhar|share)\\b",
        options: .caseInsensitive)

    static func ehIrreversivel(_ s: String) -> Bool {
        irreversivel.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
    }

    static func simplificar(_ raiz: No, largura: Double, altura: Double, limite: Int = 70) -> [Elemento] {
        var achados: [Elemento] = []
        // Barras sobrepostas (busca, barra de ferramentas): o que fica por baixo não recebe toque.
        var coberturas: [(x: Double, y: Double, w: Double, h: Double)] = []
        func coletaCoberturas(_ no: No) {
            if ["SearchField", "TabBar", "Toolbar"].contains(no.tipo), no.visivel, no.w > 0, no.h > 0 { coberturas.append((no.x, no.y, no.w, no.h)) }
            no.filhos.forEach(coletaCoberturas)
        }
        coletaCoberturas(raiz)
        func coberto(_ cx: Double, _ cy: Double) -> Bool {
            // Barra na metade inferior esconde tudo dali para baixo; na superior, tudo dali para cima.
            coberturas.contains { b in
                guard cx >= b.x, cx <= b.x + b.w else { return false }
                return b.y + b.h / 2 > altura / 2 ? cy >= b.y : cy <= b.y + b.h
            }
        }
        func anda(_ no: No, dentro: Bool = false) {
            let ehCobertura = ["SearchField", "TabBar", "Toolbar"].contains(no.tipo)
            let rot = no.rotulo.trimmingCharacters(in: .whitespacesAndNewlines)
            if tiposUteis.contains(no.tipo), no.visivel, no.w > 0, no.h > 0 {
                let cx = no.x + no.w / 2, cy = no.y + no.h / 2
                let interativo = !["StaticText", "Image", "Other"].contains(no.tipo)
                if cx >= 0, cx <= largura, cy >= 0, cy <= altura, !rot.isEmpty || interativo, dentro || ehCobertura || !coberto(cx, cy) {
                    let comValor = ["TextField", "SearchField", "TextView", "Switch"].contains(no.tipo)
                    achados.append(Elemento(tipo: no.tipo, rotulo: String(rot.prefix(80)), x: Int(cx.rounded()), y: Int(cy.rounded()),
                                            valor: comValor ? String(no.valor.prefix(60)) : ""))
                }
            }
            no.filhos.forEach { anda($0, dentro: dentro || ehCobertura) }
        }
        anda(raiz)
        let botoes = achados.filter { ["Button", "Cell", "Link", "Tab"].contains($0.tipo) && !$0.rotulo.isEmpty }
        func redundante(_ e: Elemento) -> Bool {
            if e.tipo == "Image" { return true }
            if e.tipo == "Cell" && e.rotulo.isEmpty { return true }
            if e.tipo == "Other" && !e.rotulo.isEmpty {
                return achados.contains { $0 != e && $0.tipo != "Other" && $0.rotulo == e.rotulo && abs($0.y - e.y) < 40 }
                    || achados.contains { $0 != e && $0.tipo == "Other" && $0.rotulo == e.rotulo && $0.y < e.y }
            }
            if e.tipo == "StaticText" {
                return botoes.contains { $0 != e && $0.rotulo.contains(e.rotulo) && abs($0.x - e.x) < 400 && abs($0.y - e.y) < 30 }
            }
            return false
        }
        var vistos = Set<String>(), saida: [Elemento] = []
        for e in achados where !redundante(e) {
            let k = "\(e.tipo)|\(e.rotulo)|\(e.x / 6)|\(e.y / 6)"
            if vistos.insert(k).inserted { saida.append(e) }
        }
        return saida.prefix(limite).enumerated().map { var e = $1; e.n = $0 + 1; return e }
    }

    static func descrever(_ els: [Elemento]) -> String {
        if els.isEmpty { return "(tela sem elementos legíveis)" }
        return els.map { e in "\(e.n). \(e.tipo) \"\(e.rotulo)\"" + (e.valor.isEmpty ? "" : " valor=\"\(e.valor)\"") }.joined(separator: "\n")
    }

    static func extrairAcao(_ bruto: String) -> Acao? {
        var t = bruto
        while let a = t.range(of: "<think>"), let b = t.range(of: "</think>", range: a.upperBound..<t.endIndex) { t.removeSubrange(a.lowerBound..<b.upperBound) }
        let c = Array(t)
        var i = 0
        while i < c.count {
            if c[i] == "{" {
                var j = c.count - 1
                while j > i {
                    if c[j] == "}", let d = String(c[i...j]).data(using: .utf8),
                       let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any],
                       let nome = o["acao"] as? String, acoes.contains(nome) {
                        return Acao(nome: nome, n: (o["n"] as? Int) ?? (o["n"] as? Double).map(Int.init), texto: o["texto"] as? String,
                                    direcao: o["direcao"] as? String, bundle: o["bundle"] as? String, resposta: o["resposta"] as? String)
                    }
                    j -= 1
                }
            }
            i += 1
        }
        return nil
    }

    /// Barreira de segurança: roda antes de qualquer toque real. (ok, motivo)
    static func validar(_ a: Acao, _ els: [Elemento]) -> (Bool, String) {
        let porN = Dictionary(uniqueKeysWithValues: els.map { ($0.n, $0) })
        switch a.nome {
        case "tocar":
            guard let n = a.n, let e = porN[n] else { return (false, "elemento inexistente") }
            if ehIrreversivel(e.rotulo) { return (false, "«\(e.rotulo)» não se desfaz: preciso da confirmação do dono") }
        case "digitar":
            if let n = a.n, let e = porN[n], e.tipo == "SecureTextField" { return (false, "campo de senha: o dono digita") }
            if a.n == nil, els.contains(where: { $0.tipo == "SecureTextField" }) { return (false, "há campo de senha na tela: indique o campo (n) ou deixe o dono digitar") }
            if (a.texto ?? "").trimmingCharacters(in: .whitespaces).isEmpty { return (false, "texto vazio") }
        case "deslizar", "rolar":
            if !["cima", "baixo", "esquerda", "direita"].contains(a.direcao ?? "") { return (false, "direção inválida") }
        case "abrir":
            let b = a.bundle ?? ""
            if b.range(of: "^[A-Za-z0-9.\\-]{3,120}$", options: .regularExpression) == nil { return (false, "bundle inválido") }
        default: break
        }
        return (true, "")
    }

    static let sistema = """
    Você controla um iPhone pela tela, em nome do dono. A cada passo recebe o OBJETIVO, o app em primeiro plano e a lista numerada dos elementos visíveis.
    Responda SOMENTE com um JSON, sem texto: {"acao": ..., ...}
    Ações: {"acao":"tocar","n":N} · {"acao":"digitar","texto":"...","n":N opcional} · {"acao":"rolar","direcao":"baixo|cima"} (baixo = ver o que está mais abaixo na tela; cima = ver o que está acima) · {"acao":"deslizar","direcao":"esquerda|direita"} (só para carrosséis e páginas) · {"acao":"abrir","bundle":"com.apple.mobilesafari"} · {"acao":"inicio"} · {"acao":"voltar"} · {"acao":"esperar"} · {"acao":"fim","resposta":"o que o dono precisa saber"}
    Bundles úteis: com.apple.mobilesafari, com.apple.MobileSMS, com.apple.mobilenotes, com.apple.reminders, com.apple.Preferences, com.apple.mobilecal, com.apple.Maps, com.apple.camera, com.apple.Music, com.apple.mobileslideshow, com.apple.mobilephone, com.apple.Health, com.apple.shortcuts, com.apple.AppStore, com.burbn.instagram, net.whatsapp.WhatsApp, com.spotify.client.
    Só aparece o que está visível na tela agora. Se o item que você precisa NÃO está na lista, role com {"acao":"rolar","direcao":"baixo"} e olhe de novo; não toque em títulos ou textos que não levam a lugar nenhum. Se um toque não mudou a tela, não repita: tente outra coisa. Para sair de uma tela use "voltar".
    Regras: um passo por vez; nunca invente elementos; nunca toque em enviar, pagar, excluir ou publicar (pare com "fim" e diga o que falta confirmar); nunca digite senha; se o objetivo foi cumprido ou é impossível, responda "fim" com um resumo curto em português.
    """

    static func mensagens(objetivo: String, app: String, elementos: [Elemento], historico: [String]) -> [[String: String]] {
        let passos = historico.suffix(8).map { "- \($0)" }.joined(separator: "\n")
        let u = "OBJETIVO: \(objetivo)\nAPP EM PRIMEIRO PLANO: \(app)\nPASSOS JÁ FEITOS:\n\(passos.isEmpty ? "(nenhum)" : passos)\nELEMENTOS:\n\(descrever(elementos))"
        return [["role": "system", "content": sistema], ["role": "user", "content": u]]
    }
}
