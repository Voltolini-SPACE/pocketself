// PocketSelf — controle do iPhone. Um app comum não toca em outros apps (sandbox do iOS); quem faz isso é o
// agente do iPhone (agente-iphone/), um runner XCUITest que roda NO aparelho, lê a tela por acessibilidade e decide
// cada passo. Ele serve HTTP só em loopback (127.0.0.1:14292) com token. O PocketSelf entrega o objetivo e lê o resultado.
import Foundation

enum ControleIphone {
    static let chaveToken = "controleToken", chaveTarefa = "controleUltimaTarefa"
    static let base = URL(string: "http://127.0.0.1:14292")!

    static var token: String { UserDefaults.standard.string(forKey: chaveToken) ?? "" }

    private static func pedido(_ caminho: String, metodo: String = "GET", corpo: [String: String]? = nil, tempo: TimeInterval = 5) -> URLRequest {
        var r = URLRequest(url: base.appendingPathComponent(caminho), timeoutInterval: tempo)
        r.httpMethod = metodo
        r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let corpo { r.httpBody = try? JSONSerialization.data(withJSONObject: corpo); r.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        return r
    }

    /// Texto curto para o modelo sobre o estado de uma tarefa (JSON do agente).
    static func resumo(_ j: [String: Any]) -> String {
        let estado = j["estado"] as? String ?? "?"
        let resposta = j["resposta"] as? String ?? ""
        let passos = (j["log"] as? [String] ?? []).suffix(6).joined(separator: "; ")
        switch estado {
        case "executando": return "Em andamento no iPhone" + (passos.isEmpty ? "." : " (último: \(passos)). Consulte de novo com controle_resultado.")
        case "concluida": return "Concluída: \(resposta)"
        case "aguarda_dono": return "Parei e aguardo o dono: \(resposta)"
        case "limite": return "Não terminou: \(resposta)"
        default: return "Falhou: \(resposta)"
        }
    }

    static func iniciar(_ objetivo: String) async -> String {
        guard !token.isEmpty else { return "O controle do iPhone não está ligado: falta o código do agente em Ajustes › Controle do iPhone." }
        do {
            let (dados, resp) = try await URLSession.shared.data(for: pedido("tarefa", metodo: "POST", corpo: ["objetivo": objetivo]))
            let http = resp as? HTTPURLResponse
            let j = (try? JSONSerialization.jsonObject(with: dados) as? [String: Any]) ?? [:]
            guard http?.statusCode == 202, let id = j["id"] as? String else {
                return (j["erro"] as? String).map { "O agente recusou: \($0)." } ?? "O agente não aceitou a tarefa (código \(http?.statusCode ?? 0))."
            }
            UserDefaults.standard.set(id, forKey: chaveTarefa)
            // Dá alguns segundos para o primeiro passo; depois a tarefa segue sozinha (o PocketSelf pode ir para segundo plano).
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            return "Tarefa iniciada no iPhone. " + (await resultado())
        } catch {
            return "Não alcancei o agente do iPhone (sessão de teste ativa? veja docs/CONTROLE-DO-IPHONE.md)."
        }
    }

    /// Sonda: o agente que roda NO aparelho responde em 127.0.0.1:14292? (sem Mac no caminho)
    static func sondarLocal() async -> String {
        do {
            let (d, resp) = try await URLSession.shared.data(for: pedido("estado", tempo: 4))
            let ok = (resp as? HTTPURLResponse)?.statusCode == 200
            let j = (try? JSONSerialization.jsonObject(with: d) as? [String: Any]) ?? [:]
            return ok && j["agente"] as? Bool == true ? "Agente local respondeu (\(j["tarefas"] as? Int ?? 0) tarefas)." : "Agente local respondeu com erro."
        } catch { return "Agente local não respondeu: \((error as NSError).code)." }
    }

    static func resultado() async -> String {
        guard let id = UserDefaults.standard.string(forKey: chaveTarefa) else { return "Não há tarefa de controle recente." }
        do {
            let (dados, _) = try await URLSession.shared.data(for: pedido("tarefa/\(id)"))
            guard let j = try JSONSerialization.jsonObject(with: dados) as? [String: Any] else { return "Resposta ilegível do agente." }
            return resumo(j)
        } catch { return "Não alcancei o agente do iPhone." }
    }
}

import SwiftUI

struct ControleIphoneView: View {
    @State private var codigo = ControleIphone.token
    @State private var estado = ""
    var body: some View {
        TelaAjuste(titulo: "Controle do iPhone", subtitulo: "O PocketSelf faz tarefas em qualquer app usando o agente que roda no próprio iPhone.") {
            RotuloDeGrupo(texto: "Código do agente")
            SecureField("Cole o código do agente", text: $codigo)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .padding(12).background(Tema.superficie, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Tema.borda, lineWidth: 1))
                .onChange(of: codigo) { _, novo in UserDefaults.standard.set(novo.trimmingCharacters(in: .whitespacesAndNewlines), forKey: ControleIphone.chaveToken) }
            Text("O código é o token definido ao iniciar a sessão do agente (scripts/agente-iphone.sh). Precisa do aparelho desbloqueado e da sessão de teste ativa no Xcode. Veja docs/CONTROLE-DO-IPHONE.md.")
                .font(.caption).foregroundStyle(Tema.secundario)
            Button("Ver a última tarefa") {
                Task { estado = await ControleIphone.resultado() }
            }.buttonStyle(BotaoSecundario())
            Button("Sondar o agente neste aparelho") { Task { estado = await ControleIphone.sondarLocal() } }.buttonStyle(BotaoSecundario())
            if !estado.isEmpty { Text(estado).font(.footnote).foregroundStyle(Tema.secundario) }
            Text("Segurança: enviar, pagar, excluir, publicar e digitar senha nunca são feitos sozinhos; a tarefa para e pede você.")
                .font(.caption).foregroundStyle(Tema.secundario)
        }
    }
}
