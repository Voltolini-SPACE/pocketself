// PocketSelf — diagnóstico pelo cabo, opt-in. Somente o turno atual; nunca exporta o histórico pessoal.
import Foundation

enum ValidacaoResposta {
    static var ativa: Bool { CommandLine.arguments.contains("--validar-respostas") }

    /// Modo diagnóstico usa arquivos próprios. Sem a flag, os caminhos normais são preservados.
    static func arquivoIsolado(_ nome: String, argumentos: [String] = CommandLine.arguments,
                              pasta: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]) -> URL? {
        guard argumentos.contains("--validar-respostas") else { return nil }
        return pasta.appendingPathComponent("neo-validacao-\(nome).json")
    }

    private struct Turno: Encodable {
        let pergunta: String
        let resposta: String
        let interrompida: Bool
        let erro: String?
        let motor: String?
        let ferramenta: String
        let primeira_ms: Double
    }

    static func linha(pergunta: String, resposta: String, interrompida: Bool, erro: String?,
                      motor: String?, ferramenta: String, primeiraMs: Double) throws -> String {
        let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys]
        let d = try enc.encode(Turno(pergunta: pergunta, resposta: resposta, interrompida: interrompida,
                                     erro: erro, motor: motor, ferramenta: ferramenta, primeira_ms: primeiraMs))
        return String(decoding: d, as: UTF8.self)
    }
}
