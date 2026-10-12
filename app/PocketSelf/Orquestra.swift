// PocketSelf — teste de orquestração: dois motores residentes ao mesmo tempo (Qwen3.5 4B + Gemma 4 E2B).
// Disparado pelo cabo com --teste-orquestra; imprime [neo-orq] e fecha. Não muda o app normal.
import Foundation
import MLX
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers
import FoundationModels

enum TesteOrquestra {
    static func pegadaMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) { $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) } }
        return kr == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : -1
    }
    static func livreMB() -> Int { Int(os_proc_available_memory() / 1_048_576) }
    static func log(_ s: String) { print("[neo-orq] \(s) | pegada=\(Int(pegadaMB())) MB livre=\(livreMB()) MB termico=\(ProcessInfo.processInfo.thermalState.rawValue)") }

    struct Medida { let nome: String; let ttftMs: Double; let tps: Double; let tokens: Int; let texto: String }

    static func gerar(_ c: ModelContainer, nome: String, pergunta: String) async throws -> Medida {
        let s = ChatSession(c, instructions: "Responda em português do Brasil, em até 3 frases, sem Markdown.",
                            generateParameters: GenerateParameters(maxTokens: 120, temperature: 0.6), additionalContext: ["enable_thinking": false])
        let t0 = Date.timeIntervalSinceReferenceDate
        var t1 = 0.0, n = 0, txt = ""
        for try await p in s.streamResponse(to: pergunta) {
            if t1 == 0 { t1 = Date.timeIntervalSinceReferenceDate }
            n += 1; txt += p
        }
        let fim = Date.timeIntervalSinceReferenceDate
        return Medida(nome: nome, ttftMs: (t1 - t0) * 1000, tps: Double(n) / max(fim - t1, 0.001), tokens: n, texto: txt)
    }

    static func rodar() async {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("modelos")
        Memory.cacheLimit = 20 * 1024 * 1024
        log("inicio")
        do {
            if CommandLine.arguments.contains("--apple"), #available(iOS 26.0, *) {
                let disp = SystemLanguageModel.default.availability
                log("apple disponibilidade=\(disp) pt_BR=\(SystemLanguageModel.default.supportsLocale(Locale(identifier: "pt_BR")))")
                let qwen = try await LLMModelFactory.shared.loadContainer(from: base.appendingPathComponent("Qwen3.5-4B-MLX-4bit"), using: #huggingFaceTokenizerLoader())
                Memory.clearCache()
                log("qwen residente")
                let sess = LanguageModelSession(instructions: "Você é um assistente. Responda em português do Brasil, em até 2 frases.")
                for p in ["Oi, tudo bem? Me dá uma dica rápida para dormir melhor.", "Explique em poucas palavras o que é juros compostos."] {
                    let t0 = Date.timeIntervalSinceReferenceDate
                    var t1 = 0.0, n = 0, txt = ""
                    for try await parcial in sess.streamResponse(to: p) {
                        if t1 == 0 { t1 = Date.timeIntervalSinceReferenceDate }
                        n += 1; txt = parcial.content
                    }
                    log(String(format: "apple ttft=%.0f ms total=%.1f s | %@", (t1 - t0) * 1000, Date.timeIntervalSinceReferenceDate - t0, String(txt.replacingOccurrences(of: "\n", with: " ").prefix(180))))
                }
                // Colaboração simultânea: Apple responde enquanto o Qwen gera.
                let t = Date.timeIntervalSinceReferenceDate
                async let q = gerar(qwen, nome: "qwen", pergunta: "Em uma frase, por que beber água faz bem?")
                let a = try await LanguageModelSession().respond(to: "Em uma frase, em português, cite três frutas ricas em vitamina C.")
                let mq = try await q
                log(String(format: "paralelo apple+qwen total=%.1f s | qwen tps=%.1f | apple: %@", Date.timeIntervalSinceReferenceDate - t, mq.tps, String(a.content.prefix(120))))
                _ = qwen
                exit(0)
            }
            if CommandLine.arguments.contains("--so-gemma") {
                let t = Date.timeIntervalSinceReferenceDate
                let g = try await LLMModelFactory.shared.loadContainer(from: base.appendingPathComponent("gemma-4-e2b-it-4bit"), using: #huggingFaceTokenizerLoader())
                Memory.clearCache()
                log(String(format: "gemma sozinho carregado em %.1f s", Date.timeIntervalSinceReferenceDate - t))
                let m = try await gerar(g, nome: "gemma", pergunta: "Oi! Me dá uma dica rápida para dormir melhor.")
                Memory.clearCache()
                log(String(format: "gemma após resposta ttft=%.0f tps=%.1f | %@", m.ttftMs, m.tps, String(m.texto.prefix(140))))
                exit(0)
            }
            var t = Date.timeIntervalSinceReferenceDate
            let qwen = try await LLMModelFactory.shared.loadContainer(from: base.appendingPathComponent("Qwen3.5-4B-MLX-4bit"), using: #huggingFaceTokenizerLoader())
            log(String(format: "qwen carregado em %.1f s", Date.timeIntervalSinceReferenceDate - t))
            Memory.clearCache()
            log("qwen após limpar cache")
            let mq = try await gerar(qwen, nome: "qwen", pergunta: "Oi!")
            Memory.clearCache()
            log(String(format: "qwen após 1 resposta (tps=%.1f)", mq.tps))
            if livreMB() < 3200 { log("PARADA: memória insuficiente para o segundo motor"); exit(0) }
            t = Date.timeIntervalSinceReferenceDate
            let gemma = try await LLMModelFactory.shared.loadContainer(from: base.appendingPathComponent("gemma-4-e2b-it-4bit"), using: #huggingFaceTokenizerLoader())
            log(String(format: "gemma carregado em %.1f s (os dois residentes)", Date.timeIntervalSinceReferenceDate - t))

            let perguntas = ["Oi, tudo bem? Me dá uma dica rápida para dormir melhor.", "Explique em poucas palavras o que é juros compostos."]
            for p in perguntas {
                for (c, nome) in [(gemma, "gemma"), (qwen, "qwen")] {
                    let m = try await gerar(c, nome: nome, pergunta: p)
                    log(String(format: "sequencial %@ ttft=%.0f ms tps=%.1f tokens=%d | %@", m.nome, m.ttftMs, m.tps, m.tokens, String(m.texto.replacingOccurrences(of: "\n", with: " ").prefix(160))))
                }
            }

            // Os dois gerando ao mesmo tempo (colaboração simultânea).
            t = Date.timeIntervalSinceReferenceDate
            async let a = gerar(gemma, nome: "gemma", pergunta: "Liste em uma frase três frutas ricas em vitamina C.")
            async let b = gerar(qwen, nome: "qwen", pergunta: "Em uma frase, por que beber água faz bem?")
            let (ma, mb) = try await (a, b)
            log(String(format: "paralelo total=%.1f s | gemma ttft=%.0f tps=%.1f | qwen ttft=%.0f tps=%.1f", Date.timeIntervalSinceReferenceDate - t, ma.ttftMs, ma.tps, mb.ttftMs, mb.tps))

            // Colaboração em cadeia: Gemma rascunha rápido, Qwen revisa.
            t = Date.timeIntervalSinceReferenceDate
            let rascunho = try await gerar(gemma, nome: "gemma", pergunta: "Escreva uma mensagem curta e educada pedindo para remarcar uma reunião de amanhã.")
            let revisao = try await gerar(qwen, nome: "qwen", pergunta: "Revise e melhore este texto, mantendo curto e natural em português do Brasil: \(rascunho.texto)")
            log(String(format: "cadeia rascunho+revisao total=%.1f s | final: %@", Date.timeIntervalSinceReferenceDate - t, String(revisao.texto.replacingOccurrences(of: "\n", with: " ").prefix(200))))
            log("fim ok")
        } catch {
            log("ERRO \(error)")
        }
        exit(0)
    }
}
