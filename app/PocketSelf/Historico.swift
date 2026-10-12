// PocketSelf — histórico de conversas, guardado neste iPhone (Documents/conversas.json, gravação atômica).
import Foundation

struct Mensagem: Identifiable, Codable, Equatable {
    var id = UUID()
    var deNEO: Bool
    var texto: String
    var hora = Date()
    var motor: String? = nil
    var interrompida = false
    var porVoz = false
    /// Nota do sistema (comprovante de ação, aviso): não vai ao modelo como fala.
    var nota: Bool? = nil
    /// Decisão do Sistema 1 que orientou o turno (medida, não inventada).
    var decisao: String? = nil
    /// Imagem gerada no aparelho (arquivo em Documents/imagens).
    var imagem: String? = nil
}

struct Conversa: Identifiable, Codable, Equatable {
    var id = UUID()
    var titulo = ""
    var criadaEm = Date()
    var atualizadaEm = Date()
    var fixada = false
    var mensagens: [Mensagem] = []

    var tituloExibido: String {
        if !titulo.isEmpty { return titulo }
        if let primeira = mensagens.first(where: { !$0.deNEO })?.texto {
            let linha = primeira.replacingOccurrences(of: "\n", with: " ")
            return linha.count > 42 ? String(linha.prefix(42)) + "…" : linha
        }
        return "Nova conversa"
    }
    var resumo: String {
        guard let ultima = mensagens.last else { return "Sem mensagens" }
        let linha = ultima.texto.replacingOccurrences(of: "\n", with: " ")
        return (ultima.deNEO ? "PocketSelf: " : "Você: ") + (linha.count > 60 ? String(linha.prefix(60)) + "…" : linha)
    }
    var teveVoz: Bool { mensagens.contains { $0.porVoz } }
}

@Observable
@MainActor
final class Historico {
    private(set) var conversas: [Conversa] = []
    var atualId: UUID?

    private let arquivo: URL

    init(arquivo: URL? = nil) {
        self.arquivo = arquivo ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("conversas.json")
        carregar()
    }

    private func carregar() {
        guard let dados = try? Data(contentsOf: arquivo) else { return }
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        conversas = (try? dec.decode([Conversa].self, from: dados)) ?? []
    }

    private func salvar() {
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601; enc.outputFormatting = [.sortedKeys]
        guard let dados = try? enc.encode(conversas) else { return }
        let novo = arquivo.appendingPathExtension("novo")
        do {
            try dados.write(to: novo, options: .atomic)
            _ = try FileManager.default.replaceItemAt(arquivo, withItemAt: novo)
        } catch {
            print("[neo] falha ao salvar histórico: \(error.localizedDescription)")
        }
    }

    var atual: Conversa? { conversas.first { $0.id == atualId } }

    func conversa(_ id: UUID) -> Conversa? { conversas.first { $0.id == id } }

    /// Conversas em ordem: fixadas primeiro, depois as mais recentes.
    var ordenadas: [Conversa] {
        conversas.sorted {
            if $0.fixada != $1.fixada { return $0.fixada }
            return $0.atualizadaEm > $1.atualizadaEm
        }
    }

    @discardableResult
    func nova() -> Conversa {
        // Uma conversa vazia já aberta é reaproveitada; não cria lixo no histórico.
        if let c = atual, c.mensagens.isEmpty { return c }
        let c = Conversa()
        conversas.insert(c, at: 0)
        atualId = c.id
        salvar()
        return c
    }

    func atualOuNova() -> Conversa { atual ?? nova() }

    func abrir(_ id: UUID) { atualId = id }

    func atualizar(_ c: Conversa) {
        guard let i = conversas.firstIndex(where: { $0.id == c.id }) else { return }
        var c = c
        c.atualizadaEm = Date()
        conversas[i] = c
        salvar()
    }

    func anexar(_ m: Mensagem, em id: UUID) {
        guard var c = conversa(id) else { return }
        c.mensagens.append(m)
        atualizar(c)
    }

    func fixar(_ id: UUID) {
        guard var c = conversa(id) else { return }
        c.fixada.toggle()
        atualizar(c)
    }

    func renomear(_ id: UUID, para titulo: String) {
        guard var c = conversa(id) else { return }
        c.titulo = String(titulo.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        atualizar(c)
    }

    /// Remove a conversa e suas mensagens deste iPhone. Se era a aberta, o chat volta vazio.
    func excluir(_ id: UUID) {
        conversas.removeAll { $0.id == id }
        if atualId == id { atualId = nil }
        salvar()
    }

    func apagarTudo() {
        conversas = []
        atualId = nil
        salvar()
    }

    /// Exportação legível para revisão antes de compartilhar.
    func exportarTexto() -> String {
        let f = DateFormatter(); f.dateStyle = .short; f.timeStyle = .short
        var s = "PocketSelf — conversas exportadas em \(f.string(from: Date()))\n"
        for c in ordenadas {
            s += "\n==== \(c.tituloExibido) · \(f.string(from: c.criadaEm))\(c.fixada ? " · fixada" : "")\n"
            for m in c.mensagens {
                s += "[\(f.string(from: m.hora))] \(m.deNEO ? "PocketSelf" : "Você")\(m.porVoz ? " (voz)" : ""): \(m.texto)\n"
            }
        }
        return s
    }
}

enum Navegacao {
    enum Aba: Hashable { case chat, agenda, historico, ajustes }
}

@Observable
final class Rota {
    var aba: Navegacao.Aba = {
        switch Preferencias.argumento("aba") {
        case "historico": return .historico
        case "ajustes": return .ajustes
        case "agenda": return .agenda
        default: return .chat
        }
    }()
}
