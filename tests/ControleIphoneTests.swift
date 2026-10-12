// Testes do cliente do agente do iPhone (ControleIphone.swift, trecho puro até «import SwiftUI», extraído por tests/testar.sh).
// O agente é simulado por URLProtocol; nenhuma conexão real é aberta. Cobre o texto que o modelo recebe em cada estado/erro.
import Foundation

final class ControleMock: URLProtocol {
    nonisolated(unsafe) static var resposta: (URLRequest) -> (Int, String)? = { _ in nil }
    nonisolated(unsafe) static var pedidos: [(metodo: String, caminho: String, auth: String, corpo: [String: Any])] = []
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    static func corpo(_ r: URLRequest) -> [String: Any] {
        var data = r.httpBody ?? Data()
        if data.isEmpty, let s = r.httpBodyStream {
            s.open(); defer { s.close() }
            var buf = [UInt8](repeating: 0, count: 4096)
            while s.hasBytesAvailable { let n = s.read(&buf, maxLength: buf.count); if n <= 0 { break }; data.append(buf, count: n) }
        }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }
    override func startLoading() {
        Self.pedidos.append((request.httpMethod ?? "", request.url?.path ?? "", request.value(forHTTPHeaderField: "Authorization") ?? "", Self.corpo(request)))
        guard let (status, corpo) = Self.resposta(request) else { client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost)); return }
        let r = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: r, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(corpo.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@main struct ControleIphoneTests {
    static func servir(_ r: @escaping (URLRequest) -> (Int, String)?) { ControleMock.resposta = r; ControleMock.pedidos = [] }

    static func resumos() {
        let r = ControleIphone.resumo
        T.check(r(["estado": "executando"]) == "Em andamento no iPhone.", "resumo: executando sem log")
        let log = (1...8).map { "passo \($0)" }
        let exec = r(["estado": "executando", "log": log])
        T.check(exec.contains("passo 8") && exec.contains("passo 3") && !exec.contains("passo 2;") && exec.contains("controle_resultado"), "resumo: executando mostra só os 6 últimos passos e manda consultar de novo", exec)
        T.check(r(["estado": "concluida", "resposta": "Versão 26.0"]) == "Concluída: Versão 26.0", "resumo: concluída")
        T.check(r(["estado": "aguarda_dono", "resposta": "Parei por segurança: «Enviar» não se desfaz"]).hasPrefix("Parei e aguardo o dono:"), "resumo: aguarda o dono")
        T.check(r(["estado": "limite", "resposta": "x"]) == "Não terminou: x", "resumo: limite de passos")
        T.check(r(["estado": "falhou", "resposta": "boom"]) == "Falhou: boom" && r([:]) == "Falhou: ", "resumo: falhou e estado desconhecido caem em «Falhou»")
        T.lacuna("resumo: estado desconhecido/ausente vira «Falhou:» sem texto (nada diz ao dono o que houve)", confirmada: r([:]) == "Falhou: ")
    }

    static func rede() async {
        let d = UserDefaults.standard
        d.removeObject(forKey: ControleIphone.chaveToken); d.removeObject(forKey: ControleIphone.chaveTarefa)
        T.check(ControleIphone.base.absoluteString == "http://127.0.0.1:14292" && ControleIphone.base.host == "127.0.0.1", "base do agente é loopback 127.0.0.1:14292")
        T.check(ControleIphone.token.isEmpty, "sem token configurado")
        servir { _ in (200, "{}") }
        let sem = await ControleIphone.iniciar("abrir Ajustes")
        T.check(sem == "O controle do iPhone não está ligado: falta o código do agente em Ajustes › Controle do iPhone." && ControleMock.pedidos.isEmpty, "iniciar sem token: avisa e NÃO faz requisição", sem)
        T.check(await ControleIphone.resultado() == "Não há tarefa de controle recente.", "resultado sem tarefa anterior")

        d.set("token-de-teste", forKey: ControleIphone.chaveToken)
        servir { _ in (409, #"{"erro":"já há uma tarefa em andamento"}"#) }
        let ocupado = await ControleIphone.iniciar("qualquer")
        T.check(ocupado == "O agente recusou: já há uma tarefa em andamento.", "iniciar 409: repassa o motivo", ocupado)
        T.check(ControleMock.pedidos.first?.metodo == "POST" && ControleMock.pedidos.first?.caminho == "/tarefa" && ControleMock.pedidos.first?.auth == "Bearer token-de-teste", "iniciar: POST /tarefa com Authorization: Bearer <token>")
        T.check(ControleMock.pedidos.first?.corpo["objetivo"] as? String == "qualquer", "iniciar: corpo JSON {objetivo}")
        servir { _ in (401, #"{"erro":"sem autorização"}"#) }
        T.check(await ControleIphone.iniciar("x") == "O agente recusou: sem autorização.", "iniciar 401: token errado é informado")
        servir { _ in (500, "") }
        T.check(await ControleIphone.iniciar("x") == "O agente não aceitou a tarefa (código 500).", "iniciar 500 sem corpo: mensagem com código")
        servir { _ in nil }
        let off = await ControleIphone.iniciar("x")
        T.check(off.hasPrefix("Não alcancei o agente do iPhone") && off.contains("CONTROLE-DO-IPHONE.md"), "iniciar sem agente no ar: orienta a ligar a sessão", off)
        T.check(await ControleIphone.resultado() == "Não há tarefa de controle recente.", "falhas não gravam id de tarefa")

        servir { _ in nil }
        d.set("abc123", forKey: ControleIphone.chaveTarefa)
        T.check(await ControleIphone.resultado() == "Não alcancei o agente do iPhone.", "resultado com agente fora do ar")
        servir { _ in (200, "[1,2]") }
        T.check(await ControleIphone.resultado() == "Resposta ilegível do agente.", "resultado com JSON que não é objeto")
        servir { _ in (200, "isto não é json") }
        let ilegivel = await ControleIphone.resultado()
        T.lacuna("resultado: corpo que não é JSON é relatado como «Não alcancei o agente» (diagnóstico enganoso)", confirmada: ilegivel == "Não alcancei o agente do iPhone.")
        servir { r in r.url?.path == "/tarefa/abc123" ? (200, #"{"id":"abc123","estado":"concluida","resposta":"Versão 26.0","log":["passo 1: tocou «Geral»"]}"#) : nil }
        T.check(await ControleIphone.resultado() == "Concluída: Versão 26.0" && ControleMock.pedidos.last?.caminho == "/tarefa/abc123" && ControleMock.pedidos.last?.metodo == "GET", "resultado consulta GET /tarefa/<id> guardado")

        servir { _ in (200, #"{"agente":true,"tarefas":2}"#) }
        T.check(await ControleIphone.sondarLocal() == "Agente local respondeu (2 tarefas).", "sondarLocal: agente no ar")
        servir { _ in (200, #"{"agente":false}"#) }
        T.check(await ControleIphone.sondarLocal() == "Agente local respondeu com erro.", "sondarLocal: resposta sem agente=true")
        servir { _ in (401, #"{"erro":"sem autorização"}"#) }
        T.check(await ControleIphone.sondarLocal() == "Agente local respondeu com erro.", "sondarLocal: 401")
        servir { _ in nil }
        T.check((await ControleIphone.sondarLocal()).hasPrefix("Agente local não respondeu:"), "sondarLocal: sem agente")

        // Caminho feliz completo (inclui a espera fixa de 6 s do código).
        d.removeObject(forKey: ControleIphone.chaveTarefa)
        servir { r in
            if r.httpMethod == "POST" { return (202, #"{"id":"t1"}"#) }
            return (200, #"{"id":"t1","estado":"executando","resposta":"","log":["passo 1: abriu com.apple.Preferences"]}"#)
        }
        let t0 = Date()
        let ok = await ControleIphone.iniciar("Abra Ajustes e diga a versão")
        let dt = Date().timeIntervalSince(t0)
        T.check(ok.hasPrefix("Tarefa iniciada no iPhone. Em andamento no iPhone (último: passo 1: abriu com.apple.Preferences)"), "iniciar 202: confirma início e já traz o estado", ok)
        T.check(d.string(forKey: ControleIphone.chaveTarefa) == "t1", "iniciar 202: guarda o id da tarefa")
        T.lacuna("iniciar bloqueia a chamada da ferramenta por \(String(format: "%.1f", dt)) s fixos (Task.sleep 6 s) antes de consultar o estado", confirmada: dt >= 5.9)

        d.removeObject(forKey: ControleIphone.chaveToken); d.removeObject(forKey: ControleIphone.chaveTarefa)
        let fonte = T.ler("app/PocketSelf/ControleIphone.swift")
        T.lacuna("token do agente em UserDefaults (texto claro) e enviado em http (loopback) — aceitável no loopback, mas não está no Keychain", confirmada: fonte.contains("UserDefaults.standard.string(forKey: chaveToken)") && fonte.contains("http://127.0.0.1:14292"))
        T.lacuna("o app não limita o tamanho do objetivo nem pede confirmação antes de iniciar o agente (a ferramenta controlar_iphone age direto; o corte de 500 caracteres e a barreira ficam no runner)", confirmada: !fonte.contains("prefix(") )
    }

    static func main() async {
        _ = URLProtocol.registerClass(ControleMock.self)
        resumos()
        await rede()
        T.fim("controle-iphone")
    }
}
