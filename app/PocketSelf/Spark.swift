// PocketSelf — Spark pelo cabo (motor «Máximo» e colaboração).
// Caminho (exemplo): iPhone → Mac (cabo) → túnel SSH → servidor OpenAI-compatível. URL em UserDefaults «servidorURL».
import Foundation

enum Spark {
    static var base: URL { URL(string: UserDefaults.standard.string(forKey: "servidorURL").flatMap { $0.isEmpty ? nil : $0 } ?? "http://127.0.0.1:14290/v1") ?? URL(string: "http://127.0.0.1:14290/v1")! }
    /// Modelo esperado no servidor (Ajustes › Motor de IA › Servidor opcional).
    static var modelo: String { UserDefaults.standard.string(forKey: "servidorModelo").flatMap { $0.isEmpty ? nil : $0 } ?? "nvidia/Qwen3.6-35B-A3B-NVFP4" }

    struct Msg: Codable { let role: String; let content: String }

    private static func erro(_ mensagem: String, codigo: Int = -1) -> NSError {
        NSError(domain: "spark", code: codigo, userInfo: [NSLocalizedDescriptionKey: mensagem])
    }

    /// Uma conexão válida precisa anunciar o modelo esperado, além de responder HTTP 200.
    static func disponivel() async -> Bool {
        var r = URLRequest(url: base.appendingPathComponent("models"), timeoutInterval: 2)
        r.httpMethod = "GET"
        guard !Task.isCancelled,
              let (dados, resp) = try? await URLSession.shared.data(for: r), !Task.isCancelled,
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let j = try? JSONSerialization.jsonObject(with: dados) as? [String: Any],
              let modelos = j["data"] as? [[String: Any]] else { return false }
        return modelos.contains { $0["id"] as? String == modelo }
    }

    /// Resposta SSE. EOF sem finalização, truncamento e erros do servidor são falhas explícitas.
    static func responder(_ mensagens: [Msg], maxTokens: Int = 1024, aoChegar: (String) -> Void) async throws {
        let rodada = try await transmitir(mensagens.map { ["role": $0.role, "content": $0.content] },
                                         ferramentas: [], maxTokens: maxTokens, aoChegar: aoChegar)
        guard rodada.chamadas.isEmpty else { throw erro("a Spark pediu ferramentas indisponíveis") }
    }

    static func perguntar(_ pergunta: String) async throws -> String {
        var saida = ""
        try await responder([Msg(role: "system", content: "Você é um especialista. Responda em português do Brasil, de forma completa e correta, sem Markdown pesado."),
                             Msg(role: "user", content: pergunta)], maxTokens: 900) { saida += $0 }
        return saida
    }

    /// Até quatro requisições, sem repetir ações. O texto anterior a uma ferramenta é descartado.
    static func responderComFerramentas(_ mensagens: [[String: Any]], ferramentas: [[String: Any]], maxTokens: Int,
                                        executar: (String, String) async throws -> String,
                                        aoChegar: ((String) -> Void)? = nil,
                                        aoChamarFerramenta: (() -> Void)? = nil) async throws -> String {
        var msgs = mensagens
        let permitidas = Set(ferramentas.compactMap { ($0["function"] as? [String: Any])?["name"] as? String })
        for rodada in 0..<4 {
            try Task.checkCancellation()
            let resposta = try await transmitir(msgs, ferramentas: ferramentas, maxTokens: maxTokens,
                                                aoChegar: { aoChegar?($0) }, aoChamarFerramenta: { aoChamarFerramenta?() })
            try Task.checkCancellation()
            if resposta.chamadas.isEmpty { return resposta.texto }

            // Valida o lote inteiro antes de qualquer efeito, inclusive chamadas posteriores.
            var ids = Set<String>()
            for chamada in resposta.chamadas {
                guard !chamada.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      ids.insert(chamada.id).inserted,
                      permitidas.contains(chamada.nome),
                      chamada.tipo == "function",
                      let dados = chamada.argumentos.data(using: .utf8),
                      (try? JSONSerialization.jsonObject(with: dados)) is [String: Any] else {
                    throw erro("chamada de ferramenta inválida ou não autorizada")
                }
            }
            guard rodada < 3 else { throw erro("a Spark atingiu o limite de quatro rodadas sem resposta final") }
            try Task.checkCancellation()
            msgs.append(["role": "assistant", "content": "", "tool_calls": resposta.chamadas.map(\.json)])
            for chamada in resposta.chamadas {
                try Task.checkCancellation()
                let resultado = try await executar(chamada.nome, chamada.argumentos)
                try Task.checkCancellation()
                msgs.append(["role": "tool", "tool_call_id": chamada.id, "content": resultado])
            }
        }
        throw erro("a Spark atingiu o limite de quatro rodadas sem resposta final")
    }

    private struct Chamada {
        var id = ""
        var tipo = ""
        var nome = ""
        var argumentos = ""
        var json: [String: Any] { ["id": id, "type": tipo, "function": ["name": nome, "arguments": argumentos]] }
    }

    private struct Resposta {
        var texto = ""
        var chamadas: [Chamada] = []
    }

    /// O parser mantém eventos SSE completos e monta fragmentos tool_calls pelo índice.
    private static func transmitir(_ mensagens: [[String: Any]], ferramentas: [[String: Any]], maxTokens: Int,
                                   aoChegar: (String) -> Void, aoChamarFerramenta: () -> Void = {}) async throws -> Resposta {
        try Task.checkCancellation()
        var r = URLRequest(url: base.appendingPathComponent("chat/completions"), timeoutInterval: 120)
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        var corpo: [String: Any] = ["model": modelo, "stream": true, "max_tokens": maxTokens, "temperature": 0.4,
                                    "messages": mensagens, "chat_template_kwargs": ["enable_thinking": false]]
        if !ferramentas.isEmpty { corpo["tools"] = ferramentas; corpo["tool_choice"] = "auto" }
        r.httpBody = try JSONSerialization.data(withJSONObject: corpo)
        let (bytes, resp) = try await URLSession.shared.bytes(for: r)
        try Task.checkCancellation()
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw erro("a Spark respondeu com erro HTTP", codigo: (resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        var resultado = Resposta()
        var chamadas: [Int: Chamada] = [:]
        var dadosEvento: [String] = []
        var tipoEvento = ""
        var finalizacao: String?
        var done = false
        var detectouFerramenta = false

        func consumirEvento() throws {
            defer { dadosEvento.removeAll(); tipoEvento = "" }
            guard tipoEvento != "error" else { throw erro("a Spark retornou um evento de erro") }
            guard !dadosEvento.isEmpty else { return }
            let payload = dadosEvento.joined(separator: "\n")
            if payload == "[DONE]" { done = true; return }
            guard let dados = payload.data(using: .utf8),
                  let j = try? JSONSerialization.jsonObject(with: dados) as? [String: Any] else {
                throw erro("JSON inválido no fluxo da Spark")
            }
            if j["error"] != nil { throw erro("a Spark retornou um erro no fluxo") }
            guard let escolhas = j["choices"] as? [[String: Any]] else { throw erro("evento SSE sem choices válidas") }
            // Eventos de uso podem ter choices vazio.
            guard let escolha = escolhas.first else { return }
            guard finalizacao == nil else { throw erro("conteúdo após a finalização da Spark") }
            guard let delta = escolha["delta"] as? [String: Any] else { throw erro("delta inválido no fluxo da Spark") }
            if delta["tool_calls"] != nil, !detectouFerramenta {
                detectouFerramenta = true
                resultado.texto = ""
                try Task.checkCancellation()
                aoChamarFerramenta()
                try Task.checkCancellation()
            }
            if let conteudo = delta["content"], !(conteudo is NSNull), !detectouFerramenta {
                guard let texto = conteudo as? String else { throw erro("texto inválido no fluxo da Spark") }
                resultado.texto += texto
                if !texto.isEmpty { aoChegar(texto) }
            }
            if let ferramentasDelta = delta["tool_calls"] {
                guard let fragmentos = ferramentasDelta as? [[String: Any]] else { throw erro("tool_calls inválido") }
                for fragmento in fragmentos {
                    guard let indice = fragmento["index"] as? Int, indice >= 0 else { throw erro("índice de ferramenta inválido") }
                    var chamada = chamadas[indice] ?? Chamada()
                    for chave in ["id", "type"] {
                        if let valor = fragmento[chave] {
                            guard let texto = valor as? String else { throw erro("campo de ferramenta inválido") }
                            if chave == "id" { chamada.id += texto } else { chamada.tipo += texto }
                        }
                    }
                    if let valor = fragmento["function"] {
                        guard let funcao = valor as? [String: Any] else { throw erro("função inválida") }
                        for chave in ["name", "arguments"] {
                            if let valor = funcao[chave] {
                                guard let texto = valor as? String else { throw erro("campo de função inválido") }
                                if chave == "name" { chamada.nome += texto } else { chamada.argumentos += texto }
                            }
                        }
                    }
                    chamadas[indice] = chamada
                }
            }
            if let motivo = escolha["finish_reason"], !(motivo is NSNull) {
                guard let motivo = motivo as? String else { throw erro("finalização inválida") }
                guard motivo == "stop" || motivo == "tool_calls" else {
                    throw erro(motivo == "length" ? "resposta da Spark truncada por limite de tokens" : "finalização inesperada da Spark: \(motivo)")
                }
                finalizacao = motivo
            }
        }

        func consumirLinha(_ bytesLinha: [UInt8]) throws {
            try Task.checkCancellation()
            var bytesLinha = bytesLinha
            if bytesLinha.last == 13 { bytesLinha.removeLast() }
            guard let linha = String(bytes: bytesLinha, encoding: .utf8) else { throw erro("UTF-8 inválido no fluxo da Spark") }
            if linha.isEmpty {
                try consumirEvento()
            } else if linha.hasPrefix("data:") {
                var dado = String(linha.dropFirst(5))
                if dado.hasPrefix(" ") { dado.removeFirst() }
                dadosEvento.append(dado)
            } else if linha.hasPrefix("event:") {
                tipoEvento = linha.dropFirst(6).trimmingCharacters(in: .whitespaces)
            }
        }
        // AsyncBytes.lines omite linhas vazias; SSE depende delas para delimitar eventos.
        var linha: [UInt8] = []
        for try await byte in bytes {
            try Task.checkCancellation()
            if byte == 10 {
                try consumirLinha(linha)
                linha.removeAll(keepingCapacity: true)
                if done { break }
            } else { linha.append(byte) }
        }
        try Task.checkCancellation()
        if !done {
            if !linha.isEmpty { try consumirLinha(linha) }
            try consumirEvento()
        }
        guard done || finalizacao != nil else { throw erro("fluxo da Spark terminou antes da finalização") }
        guard finalizacao != "tool_calls" || !chamadas.isEmpty,
              chamadas.isEmpty || finalizacao != "stop" else { throw erro("finalização incompatível com ferramentas") }
        resultado.chamadas = chamadas.keys.sorted().compactMap { chamadas[$0] }
        if !resultado.chamadas.isEmpty { resultado.texto = "" }
        return resultado
    }
}
