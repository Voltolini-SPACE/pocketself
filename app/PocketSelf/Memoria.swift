// PocketSelf — memória entre conversas, compartilhada por todos os motores.
// Os modelos não aprendem sozinhos (pesos fixos); o que aprende é o PocketSelf: fatos e preferências
// propostos pela IA ou cadastrados pelo dono, aprovados um a um, e injetados nas instruções de qualquer motor.
import Foundation

struct MemoriaItem: Identifiable, Codable, Equatable {
    enum Status: String, Codable { case proposto, ativo, suspenso }
    enum Categoria: String, Codable, CaseIterable {
        case preferencia, fato, projeto, pessoa
        var nome: String {
            switch self { case .preferencia: return "Preferência"; case .fato: return "Fato"; case .projeto: return "Projeto"; case .pessoa: return "Pessoa" }
        }
    }
    var id = UUID()
    var conteudo: String
    var categoria: Categoria = .fato
    var status: Status = .proposto
    var origemConversa: UUID? = nil
    var origemTexto: String? = nil     // trecho da conversa que justificou a proposta
    var criadoEm = Date()
    var revisadoEm = Date()
    var usadoEm: Date? = nil
}

@Observable
@MainActor
final class Memoria {
    private(set) var itens: [MemoriaItem] = []
    /// Desligar o uso não apaga os itens (regra do brandbook).
    var ligada: Bool { didSet { UserDefaults.standard.set(ligada, forKey: "memoriaLigada"); versao += 1 } }
    /// Muda a cada alteração que afeta as instruções; o motor refaz o prefixo quando vê outra versão.
    private(set) var versao = 0

    private let arquivo: URL

    init(arquivo: URL? = nil) {
        self.arquivo = arquivo ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("memoria.json")
        ligada = UserDefaults.standard.object(forKey: "memoriaLigada") as? Bool ?? true
        if let d = try? Data(contentsOf: self.arquivo) {
            let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
            itens = (try? dec.decode([MemoriaItem].self, from: d)) ?? []
        }
    }

    private func salvar() {
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601; enc.outputFormatting = [.sortedKeys]
        guard let d = try? enc.encode(itens) else { return }
        let novo = arquivo.appendingPathExtension("novo")
        do {
            try d.write(to: novo, options: .atomic)
            _ = try FileManager.default.replaceItemAt(arquivo, withItemAt: novo)
        } catch { print("[neo] falha ao salvar memória: \(error.localizedDescription)") }
        versao += 1
    }

    var ativos: [MemoriaItem] { itens.filter { $0.status == .ativo } }
    var propostos: [MemoriaItem] { itens.filter { $0.status == .proposto } }

    /// Proposta da IA (ferramenta `lembrar`) ou do dono. Nada vira memória sem aprovação.
    @discardableResult
    func propor(_ conteudo: String, categoria: MemoriaItem.Categoria, conversa: UUID?, trecho: String?) -> MemoriaItem? {
        let c = conteudo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !c.isEmpty, c.count <= 300 else { return nil }
        if itens.contains(where: { $0.conteudo.caseInsensitiveCompare(c) == .orderedSame && $0.status != .suspenso }) { return nil }
        let item = MemoriaItem(conteudo: c, categoria: categoria, origemConversa: conversa, origemTexto: trecho.map { String($0.prefix(200)) })
        itens.insert(item, at: 0)
        salvar()
        return item
    }

    func aprovar(_ id: UUID) { mudar(id) { $0.status = .ativo } }
    func suspender(_ id: UUID) { mudar(id) { $0.status = .suspenso } }
    func reativar(_ id: UUID) { mudar(id) { $0.status = .ativo } }
    func editar(_ id: UUID, conteudo: String, categoria: MemoriaItem.Categoria) {
        mudar(id) { $0.conteudo = String(conteudo.trimmingCharacters(in: .whitespacesAndNewlines).prefix(300)); $0.categoria = categoria }
    }
    func excluir(_ id: UUID) { itens.removeAll { $0.id == id }; salvar() }
    func cadastrar(_ conteudo: String, categoria: MemoriaItem.Categoria) {
        if let item = propor(conteudo, categoria: categoria, conversa: nil, trecho: nil) { aprovar(item.id) }
    }

    private func mudar(_ id: UUID, _ f: (inout MemoriaItem) -> Void) {
        guard let i = itens.firstIndex(where: { $0.id == id }) else { return }
        f(&itens[i]); itens[i].revisadoEm = Date(); salvar()
    }

    func marcarUso() {
        let agora = Date()
        for i in itens.indices where itens[i].status == .ativo { itens[i].usadoEm = agora }
        // uso não altera a versão (não refaz o prefixo); salva sem bump
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        if let d = try? enc.encode(itens) { try? d.write(to: arquivo, options: .atomic) }
    }

    /// Bloco injetado nas instruções de todo motor. Vazio se desligada ou sem itens ativos.
    func textoParaInstrucoes() -> String {
        guard ligada, !ativos.isEmpty else { return "" }
        let linhas = ativos.prefix(40).map { "- [\($0.categoria.nome)] \($0.conteudo)" }
        return "\n\nO que você sabe sobre \(Identidade.donoSobre) (memória aprovada; use quando ajudar, sem repetir à toa):\n" + linhas.joined(separator: "\n")
    }
}
