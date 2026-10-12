// PocketSelf — Reunião: lógica pura (sem áudio nem modelo). Organiza a transcrição em blocos, monta os pedidos ao
// modelo, lê as notas que ele devolve e exporta em Markdown. Testável no Mac (tests/ReuniaoTests.swift).
import Foundation

struct NotasReuniao: Codable, Equatable {
    var pontos: [String] = []
    var decisoes: [String] = []
    var tarefas: [String] = []
    var duvidas: [String] = []
    var vazia: Bool { pontos.isEmpty && decisoes.isEmpty && tarefas.isEmpty && duvidas.isEmpty }

    /// Junta notas novas às existentes, sem repetir itens (comparação sem acento/caixa).
    mutating func incorporar(_ n: NotasReuniao) {
        func unir(_ a: inout [String], _ b: [String]) {
            for x in b {
                let k = ReuniaoLogica.chave(x)
                if !k.isEmpty, !a.contains(where: { ReuniaoLogica.chave($0) == k }) { a.append(x) }
            }
        }
        unir(&pontos, n.pontos); unir(&decisoes, n.decisoes); unir(&tarefas, n.tarefas); unir(&duvidas, n.duvidas)
    }
}

enum ReuniaoLogica {
    /// Tamanho mínimo de texto novo para valer a pena pedir notas ao modelo.
    static let minimoBloco = 280
    /// Limite de caracteres enviados ao modelo por pedido (cabe na janela dos motores locais).
    static let maximoBloco = 6000

    static func chave(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// Transcrição completa a partir dos segmentos fechados e do trecho parcial em curso.
    static func transcricao(_ segmentos: [String], parcial: String) -> String {
        (segmentos + [parcial]).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// Texto ainda não enviado ao modelo (a partir do caractere `processados`), limitado ao final mais recente.
    static func blocoNovo(_ completa: String, processados: Int) -> String? {
        guard completa.count - processados >= minimoBloco else { return nil }
        let novo = String(completa.dropFirst(min(processados, completa.count)))
        return String(novo.suffix(maximoBloco))
    }

    static let instrucoes = """
        Você organiza anotações de uma reunião em português do Brasil. Responda APENAS com quatro seções, cada item numa linha começando com "- ":
        PONTOS: (assuntos e informações importantes)
        DECISOES: (o que foi decidido)
        TAREFAS: (quem faz o quê e quando, se foi dito)
        DUVIDAS: (perguntas em aberto)
        Use frases curtas. Não invente nada que não esteja no texto. Se uma seção não tiver itens, escreva "- (nada)".
        """

    static func pedidoNotas(_ bloco: String) -> String {
        "Trecho da transcrição (pode ter erros de reconhecimento de voz):\n\"\"\"\n\(bloco)\n\"\"\"\nOrganize em PONTOS, DECISOES, TAREFAS e DUVIDAS."
    }

    static func pedidoResumo(_ transcricao: String, notas: NotasReuniao) -> String {
        """
        Escreva o resumo final da reunião em português do Brasil, em até 6 frases, claro e objetivo, sem inventar fatos. \
        Termine com uma linha "Próximos passos:" seguida das tarefas mais importantes.
        Notas organizadas:
        \(markdownNotas(notas))
        Transcrição (final, pode ter erros):
        \"\"\"
        \(String(transcricao.suffix(maximoBloco)))
        \"\"\"
        """
    }

    /// Lê a resposta do modelo nas quatro seções. Tolera acentos, maiúsculas, «**», números e marcadores variados.
    static func lerNotas(_ texto: String) -> NotasReuniao {
        var n = NotasReuniao()
        var secao: WritableKeyPath<NotasReuniao, [String]>? = nil
        for bruta in texto.components(separatedBy: .newlines) {
            let linha = bruta.trimmingCharacters(in: .whitespaces)
            if linha.isEmpty { continue }
            let cab = chave(linha)
            func comeca(_ p: String) -> Bool { cab.hasPrefix(p) && linha.count < 40 + p.count }
            if comeca("pontos") || comeca("pontos importantes") || comeca("assuntos") { secao = \.pontos; if let r = resto(linha) { n[keyPath: \.pontos].append(r) }; continue }
            if comeca("decisoes") || comeca("decisao") { secao = \.decisoes; if let r = resto(linha) { n[keyPath: \.decisoes].append(r) }; continue }
            if comeca("tarefas") || comeca("acoes") || comeca("proximos passos") { secao = \.tarefas; if let r = resto(linha) { n[keyPath: \.tarefas].append(r) }; continue }
            if comeca("duvidas") || comeca("perguntas") || comeca("questoes") { secao = \.duvidas; if let r = resto(linha) { n[keyPath: \.duvidas].append(r) }; continue }
            guard let s = secao else { continue }
            var item = linha
            while let c = item.first, "-*•·–—0123456789.)".contains(c) || c == " " { item.removeFirst() }
            item = item.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespaces)
            let k = chave(item)
            if item.isEmpty || k == "nada" || k == "nenhum" || k == "nenhuma" || k.hasPrefix("nada ") { continue }
            n[keyPath: s].append(item)
        }
        return n
    }

    /// Texto depois de «SEÇÃO:» na mesma linha (ex.: «DECISOES: lançar sexta»), se houver.
    private static func resto(_ linha: String) -> String? {
        guard let i = linha.firstIndex(of: ":") else { return nil }
        let r = linha[linha.index(after: i)...].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "**", with: "")
        let k = chave(r)
        return r.isEmpty || k == "nada" || k == "nenhum" || k == "nenhuma" ? nil : r
    }

    static func markdownNotas(_ n: NotasReuniao) -> String {
        func sec(_ t: String, _ itens: [String]) -> String { itens.isEmpty ? "" : "### \(t)\n" + itens.map { "- \($0)" }.joined(separator: "\n") + "\n" }
        let s = sec("Pontos importantes", n.pontos) + sec("Decisões", n.decisoes) + sec("Tarefas", n.tarefas) + sec("Dúvidas em aberto", n.duvidas)
        return s.isEmpty ? "_Sem notas ainda._\n" : s
    }

    static func duracao(_ segundos: Int) -> String {
        segundos >= 3600 ? String(format: "%d h %02d min", segundos / 3600, segundos % 3600 / 60) : String(format: "%d min %02d s", segundos / 60, segundos % 60)
    }

    static func markdown(titulo: String, data: Date, segundos: Int, notas: NotasReuniao, resumo: String, transcricao: String) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "pt_BR"); f.dateStyle = .long; f.timeStyle = .short
        return """
            # \(titulo.isEmpty ? "Reunião" : titulo)
            \(f.string(from: data)) · duração \(duracao(segundos)) · registrado no aparelho pelo PocketSelf

            ## Resumo
            \(resumo.isEmpty ? "_Sem resumo._" : resumo)

            ## Notas
            \(markdownNotas(notas))
            ## Transcrição
            \(transcricao.isEmpty ? "_Sem transcrição._" : transcricao)
            """
    }

    /// Nome de arquivo seguro: «2026-10-12-1930-planejamento-do-lancamento.md».
    static func nomeArquivo(titulo: String, data: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd-HHmm"; f.locale = Locale(identifier: "en_US_POSIX")
        let base = chave(titulo).replacingOccurrences(of: " ", with: "-")
        return f.string(from: data) + (base.isEmpty ? "-reuniao" : "-" + String(base.prefix(40))) + ".md"
    }
}
