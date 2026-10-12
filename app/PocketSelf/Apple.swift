// PocketSelf — Apple Intelligence como motor selecionável (modelo de linguagem nativo, no aparelho, sem download).
// Exige iOS 26+, aparelho compatível e Apple Intelligence ligado. Por ora responde só texto: não chama ferramentas.
import Foundation
#if canImport(FoundationModels)
import FoundationModels
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
    static func transmitir(_ historico: [Spark.Msg], aoChegar: (String) -> Void) async throws {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let instrucoes = historico.first { $0.role == "system" }?.content ?? ""
            let resto = historico.filter { $0.role != "system" }
            guard let pedido = resto.last else { return }
            // O modelo nativo recebe o histórico recente como texto (a sessão é nova a cada turno: sem memória de cache entre turnos).
            let anteriores = resto.dropLast().suffix(8).map { ($0.role == "assistant" ? "Assistente: " : "Usuário: ") + $0.content }.joined(separator: "\n")
            let prompt = anteriores.isEmpty ? pedido.content : "Conversa até aqui:\n\(anteriores)\n\nResponda ao último pedido do usuário: \(pedido.content)"
            let sessao = LanguageModelSession(instructions: instrucoes)
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
