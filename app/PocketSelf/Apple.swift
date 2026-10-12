// PocketSelf — Apple Intelligence como motor selecionável (modelo de linguagem nativo, no aparelho, sem download).
// Exige iOS 26+, aparelho compatível e Apple Intelligence ligado. Usa as mesmas ferramentas dos motores locais (FerramentaApple).
import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif
import MLXLMCommon

#if canImport(FoundationModels)
/// Ponte: cada ferramenta do PocketSelf (esquema JSON das ferramentas) vira uma `Tool` do Foundation Models.
/// Assim o Apple Intelligence usa as MESMAS ferramentas (com as mesmas confirmações) que os motores locais.
@available(iOS 26.0, *)
struct FerramentaApple: FoundationModels.Tool {
    let name: String
    let description: String
    let parameters: GenerationSchema
    let executar: @Sendable (String, [String: JSONValue]) async throws -> String

    func call(arguments: GeneratedContent) async throws -> String {
        let dic = (try? JSONDecoder().decode([String: JSONValue].self, from: Data(arguments.jsonString.utf8))) ?? [:]
        return try await executar(name, dic)
    }

    /// Converte o esquema no formato das ferramentas MLX (`{"function": {"name", "description", "parameters"}}`).
    static func de(_ spec: [String: any Sendable], executar: @escaping @Sendable (String, [String: JSONValue]) async throws -> String) -> FerramentaApple? {
        guard let f = spec["function"] as? [String: any Sendable], let nome = f["name"] as? String else { return nil }
        let desc = f["description"] as? String ?? nome
        let par = f["parameters"] as? [String: any Sendable] ?? [:]
        let props = par["properties"] as? [String: any Sendable] ?? [:]
        let obrigatorios = Set(par["required"] as? [String] ?? [])
        var propriedades: [DynamicGenerationSchema.Property] = []
        for (chave, valor) in props.sorted(by: { $0.key < $1.key }) {
            let p = valor as? [String: any Sendable] ?? [:]
            let tipo = (p["type"] as? String ?? "string").lowercased()
            let esquema: DynamicGenerationSchema
            switch tipo {
            case "integer", "int": esquema = DynamicGenerationSchema(type: Int.self)
            case "number", "double", "float": esquema = DynamicGenerationSchema(type: Double.self)
            case "boolean", "bool": esquema = DynamicGenerationSchema(type: Bool.self)
            default: esquema = DynamicGenerationSchema(type: String.self)
            }
            propriedades.append(.init(name: chave, description: p["description"] as? String, schema: esquema, isOptional: !obrigatorios.contains(chave)))
        }
        let raiz = DynamicGenerationSchema(name: nome, description: desc, properties: propriedades)
        guard let schema = try? GenerationSchema(root: raiz, dependencies: []) else { return nil }
        return FerramentaApple(name: nome, description: desc, parameters: schema, executar: executar)
    }
}
#endif

enum AppleIA {
    /// nil = disponível; senão, o motivo em português.
    static var indisponibilidade: String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available: return nil
            case .unavailable(let motivo):
                switch motivo {
                case .deviceNotEligible: return "Este aparelho não é compatível com o Apple Intelligence."
                case .appleIntelligenceNotEnabled: return "Ligue o Apple Intelligence em Ajustes › Apple Intelligence e Siri."
                case .modelNotReady: return "O modelo da Apple ainda está sendo baixado pelo sistema. Tente de novo mais tarde."
                @unknown default: return "O modelo da Apple não está disponível agora."
                }
            }
        }
        #endif
        return "Precisa do iOS 26 ou mais novo."
    }
    static var disponivel: Bool { indisponibilidade == nil }

    /// Resposta em fluxo. `historico` vem de ContextoResposta.historico: [system, anteriores…, pedido].
    static func transmitir(_ historico: [Spark.Msg], ferramentas: [[String: any Sendable]] = [], executar: (@Sendable (String, [String: JSONValue]) async throws -> String)? = nil, aoChegar: (String) -> Void) async throws {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let instrucoes = historico.first { $0.role == "system" }?.content ?? ""
            let resto = historico.filter { $0.role != "system" }
            guard let pedido = resto.last else { return }
            // O modelo nativo recebe o histórico recente como texto (a sessão é nova a cada turno: sem memória de cache entre turnos).
            let anteriores = resto.dropLast().suffix(8).map { ($0.role == "assistant" ? "Assistente: " : "Usuário: ") + $0.content }.joined(separator: "\n")
            let prompt = anteriores.isEmpty ? pedido.content : "Conversa até aqui:\n\(anteriores)\n\nResponda ao último pedido do usuário: \(pedido.content)"
            let tools: [any FoundationModels.Tool] = executar.map { ex in ferramentas.compactMap { FerramentaApple.de($0, executar: ex) } } ?? []
            let sessao = LanguageModelSession(tools: tools, instructions: instrucoes)
            var anterior = ""
            for try await parcial in sessao.streamResponse(to: prompt) {
                try Task.checkCancellation()
                let atual = parcial.content
                aoChegar(atual.hasPrefix(anterior) ? String(atual.dropFirst(anterior.count)) : atual)
                anterior = atual
            }
            return
        }
        #endif
        throw NSError(domain: "apple", code: -1, userInfo: [NSLocalizedDescriptionKey: indisponibilidade ?? "indisponível"])
    }
}
