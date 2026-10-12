// PocketSelf Agente — roda DENTRO do iPhone como runner de UI test. Enxerga e toca em qualquer app pela API de
// acessibilidade do XCUITest, decide cada passo com um modelo (URL configurável) e atende o PocketSelf em 127.0.0.1.
import XCTest
import Network
import UIKit

@MainActor final class Aparelho {
    var atual = "com.apple.springboard"
    private var apps: [String: XCUIApplication] = [:]
    var tamanho: CGSize { app(atual).frame.size }

    func app(_ b: String) -> XCUIApplication {
        if let a = apps[b] { return a }
        let a = XCUIApplication(bundleIdentifier: b); apps[b] = a; return a
    }

    static func nome(_ t: XCUIElement.ElementType) -> String {
        switch t {
        case .button: return "Button"; case .cell: return "Cell"; case .textField: return "TextField"
        case .secureTextField: return "SecureTextField"; case .staticText: return "StaticText"; case .image: return "Image"
        case .switch: return "Switch"; case .link: return "Link"; case .tab: return "Tab"; case .tabBar: return "TabBar"
        case .searchField: return "SearchField"; case .textView: return "TextView"; case .toggle: return "Toggle"
        case .slider: return "Slider"; case .picker: return "Picker"; case .pickerWheel: return "PickerWheel"
        case .key: return "Key"; case .icon: return "Icon"; default: return "Other"
        }
    }

    func converter(_ s: XCUIElementSnapshot) -> No {
        let f = s.frame
        return No(tipo: Self.nome(s.elementType), rotulo: s.label.isEmpty ? s.identifier : s.label, valor: (s.value as? String) ?? "",
                  x: f.origin.x, y: f.origin.y, w: f.size.width, h: f.size.height, visivel: true,
                  filhos: s.children.map { converter($0) })
    }

    static let conhecidos = ["com.apple.mobilesafari", "com.apple.MobileSMS", "com.apple.mobilenotes", "com.apple.reminders",
        "com.apple.Preferences", "com.apple.mobilecal", "com.apple.Maps", "com.apple.camera", "com.apple.Music", "com.apple.mobileslideshow",
        "com.apple.mobilephone", "com.apple.Health", "com.apple.shortcuts", "com.apple.AppStore", "com.burbn.instagram",
        "net.whatsapp.WhatsApp", "com.spotify.client", "io.github.voltolini-space.pocketself"]

    /// Descobre qual app está na frente (o iOS não oferece isso direto ao XCUITest).
    func detectarFrontal() {
        for b in Array(apps.keys) + Self.conhecidos where b != "com.apple.springboard" {
            if app(b).state == .runningForeground { atual = b; return }
        }
        if app("com.apple.springboard").state == .runningForeground { atual = "com.apple.springboard" }
    }

    /// Captura da tela em JPEG reduzido (largura ~480 px) em base64, para o modelo ENXERGAR o que está na tela.
    func captura() -> String? {
        let img = XCUIScreen.main.screenshot().image
        let alvo = CGSize(width: 480, height: 480 * img.size.height / max(img.size.width, 1))
        let r = UIGraphicsImageRenderer(size: alvo, format: { let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f }())
        let menor = r.image { _ in img.draw(in: CGRect(origin: .zero, size: alvo)) }
        return menor.jpegData(compressionQuality: 0.6)?.base64EncodedString()
    }

    func elementos() throws -> [Elemento] {
        detectarFrontal()
        let t = tamanho
        // Snapshot de app que não está rodando vira falha do XCTest e mata o servidor: garantir antes.
        if app(atual).state != .runningForeground {
            app(atual).activate()
            if !app(atual).wait(for: .runningForeground, timeout: 6) { atual = "com.apple.springboard"; app(atual).activate() }
        }
        // Espera a tela assentar: repete a leitura até duas seguidas iguais (máx. ~2,5 s).
        var anterior: [Elemento] = []
        var atualLeitura = Logica.simplificar(converter(try app(atual).snapshot()), largura: t.width, altura: t.height)
        for _ in 0..<5 where atualLeitura != anterior || atualLeitura.isEmpty {
            anterior = atualLeitura
            Thread.sleep(forTimeInterval: 0.5)
            atualLeitura = Logica.simplificar(converter(try app(atual).snapshot()), largura: t.width, altura: t.height)
        }
        return atualLeitura
    }

    private func ponto(_ x: Double, _ y: Double) -> XCUICoordinate {
        app(atual).coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y))
    }
    func tocar(_ x: Int, _ y: Int) { ponto(Double(x), Double(y)).tap() }
    func digitar(_ s: String) { app(atual).typeText(s) }
    func deslizar(_ d: String) {
        let t = tamanho, cx = t.width / 2, cy = t.height / 2, dx = t.width * 0.3, dy = t.height * 0.3
        let (a, b): ((Double, Double), (Double, Double)) = switch d {
        case "cima": ((cx, cy + dy), (cx, cy - dy)); case "baixo": ((cx, cy - dy), (cx, cy + dy))
        case "esquerda": ((cx + dx, cy), (cx - dx, cy)); default: ((cx - dx, cy), (cx + dx, cy))
        }
        ponto(a.0, a.1).press(forDuration: 0.1, thenDragTo: ponto(b.0, b.1))
    }
    func abrir(_ b: String) { let a = app(b); a.activate(); _ = a.wait(for: .runningForeground, timeout: 6); atual = b }
    func inicio() { XCUIDevice.shared.press(.home); atual = "com.apple.springboard" }
    func arrastar(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) { ponto(x1, y1).press(forDuration: 0.1, thenDragTo: ponto(x2, y2)) }
    func voltar() { let t = tamanho; ponto(2, t.height / 2).press(forDuration: 0.1, thenDragTo: ponto(t.width * 0.6, t.height / 2)) }
}

struct ConfigAgente {
    var llm = ProcessInfo.processInfo.environment["POCKETSELF_LLM"] ?? "http://127.0.0.1:11434/v1"
    var modelo = ProcessInfo.processInfo.environment["POCKETSELF_MODELO"] ?? "nvidia/Qwen3.6-35B-A3B-NVFP4"
    var token = ProcessInfo.processInfo.environment["POCKETSELF_TOKEN"] ?? ""
    var maxPassos = 14
    var visao = (ProcessInfo.processInfo.environment["POCKETSELF_VISAO"] ?? "1") != "0"
}

struct Tarefa: Codable {
    var id: String, objetivo: String, estado: String, resposta: String, log: [String]
}

@MainActor final class Agente {
    let cfg = ConfigAgente()
    let aparelho = Aparelho()
    var tarefas: [String: Tarefa] = [:]
    var parar = false

    func pedirModelo(_ msgs: [[String: String]], imagem: String? = nil) async throws -> String {
        var corpoMsgs: [[String: Any]] = msgs
        if let imagem, var ultima = corpoMsgs.popLast(), let texto = ultima["content"] as? String {
            ultima["content"] = [["type": "image_url", "image_url": ["url": "data:image/jpeg;base64," + imagem]],
                                 ["type": "text", "text": texto + "\n(A imagem anexa é a captura da tela agora; use-a para entender o que há na tela.)"]] as [[String: Any]]
            corpoMsgs.append(ultima)
        }
        var r = URLRequest(url: URL(string: cfg.llm + "/chat/completions")!, timeoutInterval: 120)
        r.httpMethod = "POST"; r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try JSONSerialization.data(withJSONObject: ["model": cfg.modelo, "messages": corpoMsgs, "max_tokens": 300, "temperature": 0,
                                                                 "chat_template_kwargs": ["enable_thinking": false]] as [String: Any])
        let (d, _) = try await URLSession.shared.data(for: r)
        let j = try JSONSerialization.jsonObject(with: d) as? [String: Any]
        return (((j?["choices"] as? [[String: Any]])?.first?["message"] as? [String: Any])?["content"] as? String) ?? ""
    }

    func executar(_ a: Acao, _ els: [Elemento]) async -> String {
        let porN = Dictionary(uniqueKeysWithValues: els.map { ($0.n, $0) })
        switch a.nome {
        case "tocar": if let e = a.n.flatMap({ porN[$0] }) { aparelho.tocar(e.x, e.y); return "tocou «\(e.rotulo)»" }
        case "digitar":
            if let e = a.n.flatMap({ porN[$0] }) { aparelho.tocar(e.x, e.y); try? await Task.sleep(nanoseconds: 600_000_000) }
            aparelho.digitar(a.texto ?? ""); return "digitou «\(a.texto ?? "")»"
        case "rolar": aparelho.deslizar(a.direcao == "baixo" ? "cima" : "baixo"); return "rolou para \(a.direcao ?? "baixo")"
        case "deslizar": aparelho.deslizar(a.direcao ?? "cima"); return "deslizou para \(a.direcao ?? "")"
        case "abrir": aparelho.abrir(a.bundle ?? ""); return "abriu \(a.bundle ?? "")"
        case "inicio": aparelho.inicio(); return "voltou à tela inicial"
        case "voltar": aparelho.voltar(); return "voltou"
        case "esperar": try? await Task.sleep(nanoseconds: 2_000_000_000); return "esperou"
        default: break
        }
        return ""
    }

    func rodar(_ id: String) async {
        guard var t = tarefas[id] else { return }
        func grava() { tarefas[id] = t }
        var historico: [String] = [], recusas = 0
        for passo in 1...cfg.maxPassos {
            do {
                let els = try aparelho.elementos()
                let bruto = try await pedirModelo(Logica.mensagens(objetivo: t.objetivo, app: aparelho.atual, elementos: els, historico: historico), imagem: cfg.visao ? aparelho.captura() : nil)
                guard let acao = Logica.extrairAcao(bruto) else {
                    recusas += 1; t.log.append("passo \(passo): resposta sem ação válida"); grava()
                    if recusas >= 3 { t.estado = "falhou"; t.resposta = "O modelo não respondeu num formato válido."; grava(); return }
                    continue
                }
                if acao.nome == "fim" { t.estado = "concluida"; t.resposta = String((acao.resposta ?? "Pronto.").prefix(600)); grava(); return }
                let (ok, motivo) = Logica.validar(acao, els)
                if !ok {
                    t.log.append("passo \(passo): BLOQUEADO — \(motivo)"); grava()
                    if motivo.contains("confirmação") || motivo.contains("senha") {
                        t.estado = "aguarda_dono"; t.resposta = "Parei por segurança: \(motivo)."; grava(); return
                    }
                    historico.append("ação recusada (\(motivo))"); continue
                }
                let feito = await executar(acao, els)
                historico.append(feito); t.log.append("passo \(passo): \(feito)"); grava()
                try? await Task.sleep(nanoseconds: 1_200_000_000)
            } catch {
                t.estado = "falhou"; t.resposta = "Falha no passo \(passo): \((error as NSError).localizedDescription)"; grava(); return
            }
        }
        t.estado = "limite"; t.resposta = "Não consegui concluir em poucos passos; veja o que já foi feito."; grava()
    }

    func iniciar(_ objetivo: String) -> String? {
        if tarefas.values.contains(where: { $0.estado == "executando" }) { return nil }
        let id = String(UUID().uuidString.prefix(8)).lowercased()
        tarefas[id] = Tarefa(id: id, objetivo: String(objetivo.prefix(500)), estado: "executando", resposta: "", log: [])
        Task { await self.rodar(id) }
        return id
    }
}

// MARK: - servidor HTTP em 127.0.0.1 (só o próprio aparelho alcança)

@MainActor final class Servidor {
    let agente: Agente
    var escuta: NWListener?
    init(_ a: Agente) { agente = a }

    func iniciar(porta: UInt16 = 14292) throws {
        let p = NWParameters.tcp
        p.requiredInterfaceType = .loopback
        let l = try NWListener(using: p, on: NWEndpoint.Port(rawValue: porta)!)
        l.newConnectionHandler = { c in Task { @MainActor in self.atender(c) } }
        l.start(queue: .main)
        escuta = l
    }

    private func atender(_ c: NWConnection) {
        c.start(queue: .main)
        ler(c, Data())
    }

    private func ler(_ c: NWConnection, _ acc: Data) {
        c.receive(minimumIncompleteLength: 1, maximumLength: 65536) { d, _, fim, erro in
            Task { @MainActor in
                var tudo = acc; if let d { tudo.append(d) }
                if let sep = tudo.range(of: Data("\r\n\r\n".utf8)) {
                    let cab = String(decoding: tudo[..<sep.lowerBound], as: UTF8.self)
                    let tam = cab.lowercased().components(separatedBy: "content-length:").dropFirst().first
                        .flatMap { Int($0.prefix(while: { $0 != "\r" }).trimmingCharacters(in: .whitespaces)) } ?? 0
                    if tudo.count - sep.upperBound >= tam {
                        let corpo = tudo[sep.upperBound...]
                        self.responder(c, cab, Data(corpo)); return
                    }
                }
                if fim || erro != nil { c.cancel(); return }
                self.ler(c, tudo)
            }
        }
    }

    private func enviar(_ c: NWConnection, _ codigo: Int, _ obj: Any) {
        let d = (try? JSONSerialization.data(withJSONObject: obj)) ?? Data("{}".utf8)
        let cab = "HTTP/1.1 \(codigo) OK\r\nContent-Type: application/json; charset=utf-8\r\nContent-Length: \(d.count)\r\nConnection: close\r\n\r\n"
        c.send(content: Data(cab.utf8) + d, completion: .contentProcessed { _ in c.cancel() })
    }

    private func responder(_ c: NWConnection, _ cab: String, _ corpo: Data) {
        let linhas = cab.components(separatedBy: "\r\n")
        let partes = (linhas.first ?? "").split(separator: " ").map(String.init)
        guard partes.count >= 2 else { return enviar(c, 400, ["erro": "pedido inválido"]) }
        let (metodo, caminho) = (partes[0], partes[1])
        let auth = linhas.first { $0.lowercased().hasPrefix("authorization:") }?.dropFirst(14).trimmingCharacters(in: .whitespaces) ?? ""
        guard !agente.cfg.token.isEmpty, auth == "Bearer \(agente.cfg.token)" else { return enviar(c, 401, ["erro": "sem autorização"]) }
        if metodo == "GET", caminho == "/estado" { return enviar(c, 200, ["agente": true, "tarefas": agente.tarefas.count]) }
        if metodo == "GET", caminho.hasPrefix("/tarefa/"), let t = agente.tarefas[String(caminho.dropFirst(8))] {
            return enviar(c, 200, ["id": t.id, "estado": t.estado, "resposta": t.resposta, "log": t.log])
        }
        if metodo == "GET", caminho == "/captura" {
            return enviar(c, 200, ["jpeg": agente.aparelho.captura() ?? "", "largura": agente.aparelho.tamanho.width, "altura": agente.aparelho.tamanho.height])
        }
        if metodo == "GET", caminho == "/rede" {
            var out: [String] = []; var ifa: UnsafeMutablePointer<ifaddrs>?
            if getifaddrs(&ifa) == 0 {
                var p = ifa
                while let i = p { defer { p = i.pointee.ifa_next }
                    guard let a = i.pointee.ifa_addr, a.pointee.sa_family == UInt8(AF_INET) || a.pointee.sa_family == UInt8(AF_INET6) else { continue }
                    var h = [CChar](repeating: 0, count: 100)
                    getnameinfo(a, socklen_t(a.pointee.sa_len), &h, 100, nil, 0, NI_NUMERICHOST)
                    out.append(String(cString: i.pointee.ifa_name) + " " + String(cString: h))
                }
                freeifaddrs(ifa)
            }
            return enviar(c, 200, ["interfaces": out])
        }
        if metodo == "GET", caminho == "/elementos" {
            let els = (try? agente.aparelho.elementos()) ?? []
            return enviar(c, 200, ["app": agente.aparelho.atual, "texto": Logica.descrever(els)])
        }
        // Modo manual (sem modelo): executa UMA ação direta, com a mesma barreira de irreversíveis. Serve a roteiros de validação.
        // Corpo: {"acao":"tocar|digitar|rolar|deslizar|abrir|inicio|voltar|esperar", "rotulo":"…", "texto":"…", "bundle":"…", "direcao":"…", "x":N, "y":N}
        if metodo == "POST", caminho == "/acao" {
            guard let j = (try? JSONSerialization.jsonObject(with: corpo)) as? [String: Any], let nome = j["acao"] as? String else { return enviar(c, 400, ["erro": "acao ausente"]) }
            if nome == "tocar", let x = j["x"] as? Int, let y = j["y"] as? Int { agente.aparelho.tocar(x, y); return enviar(c, 200, ["resultado": "tocou em (\(x), \(y))"]) }
            // Alertas do sistema (permissões): toca no botão que contém o rótulo. Só rótulos de permissão comuns.
            if nome == "alerta", let r = j["rotulo"] as? String {
                let sb = agente.aparelho.app("com.apple.springboard")
                guard sb.alerts.firstMatch.exists else { return enviar(c, 404, ["erro": "nenhum alerta na tela"]) }
                // Preferir o botão de rótulo exato («Permitir» antes de «Não Permitir»).
                let exato = sb.alerts.firstMatch.buttons.matching(NSPredicate(format: "label ==[c] %@", r)).firstMatch
                let botao = exato.exists ? exato : sb.alerts.firstMatch.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@ AND NOT label CONTAINS[c] %@", r, "Não")).firstMatch
                if botao.exists { let t = botao.label; botao.tap(); return enviar(c, 200, ["resultado": "alerta: tocou «\(t)»"]) }
                return enviar(c, 404, ["erro": "nenhum alerta com «\(r)»"])
            }
            if nome == "arrastar", let r = j["rotulo"] as? String, let dx = j["dx"] as? Double {
                let els = (try? agente.aparelho.elementos()) ?? []
                let alvo = r.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
                guard let e = els.first(where: { $0.rotulo.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).contains(alvo) }) else { return enviar(c, 404, ["erro": "elemento «\(r)» não está na tela"]) }
                agente.aparelho.arrastar(Double(e.x), Double(e.y), Double(e.x) + dx, Double(e.y)); return enviar(c, 200, ["resultado": "arrastou a partir de «\(e.rotulo)»"])
            }
            if nome == "arrastar", let x = j["x"] as? Double, let y = j["y"] as? Double, let x2 = j["x2"] as? Double, let y2 = j["y2"] as? Double {
                agente.aparelho.arrastar(x, y, x2, y2); return enviar(c, 200, ["resultado": "arrastou"])
            }
            let els = (try? agente.aparelho.elementos()) ?? []
            var n = j["n"] as? Int
            if let r = j["rotulo"] as? String {
                let alvo = r.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
                n = els.first { $0.rotulo.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).contains(alvo) }?.n
                if n == nil { return enviar(c, 404, ["erro": "elemento «\(r)» não está na tela"]) }
            }
            let a = Acao(nome: nome, n: n, texto: j["texto"] as? String, direcao: j["direcao"] as? String, bundle: j["bundle"] as? String)
            let (ok, motivo) = Logica.validar(a, els)
            guard ok else { return enviar(c, 403, ["erro": motivo]) }
            Task { @MainActor in
                let r = await self.agente.executar(a, els)
                self.enviar(c, 200, ["resultado": r])
            }
            return
        }
        if metodo == "POST", caminho == "/tarefa" {
            let o = ((try? JSONSerialization.jsonObject(with: corpo)) as? [String: Any])?["objetivo"] as? String
            guard let obj = o?.trimmingCharacters(in: .whitespacesAndNewlines), !obj.isEmpty else { return enviar(c, 400, ["erro": "objetivo vazio"]) }
            guard let id = agente.iniciar(obj) else { return enviar(c, 409, ["erro": "já há uma tarefa em andamento"]) }
            return enviar(c, 202, ["id": id])
        }
        enviar(c, 404, ["erro": "não encontrado"])
    }
}

final class AgenteTests: XCTestCase {
    /// Fica de pé servindo o PocketSelf até acabar o tempo (padrão 8 h) ou o Mac encerrar a sessão.
    @MainActor func testServir() async throws {
        continueAfterFailure = true
        let agente = Agente()
        let servidor = Servidor(agente)
        try servidor.iniciar()
        let horas = Double(ProcessInfo.processInfo.environment["POCKETSELF_HORAS"] ?? "") ?? 8
        let fim = Date().addingTimeInterval(horas * 3600)
        while Date() < fim && !agente.parar { try await Task.sleep(nanoseconds: 1_000_000_000) }
    }
}
