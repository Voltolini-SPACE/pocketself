import Foundation

@main struct Tests {
    static var ok = 0
    static func check(_ c: Bool, _ n: String) { if c { ok += 1 } else { print("FAIL \(n)"); exit(1) } }
    static func main() {
        let r = """
        **PONTOS:**
        - Lançamento do app previsto para novembro
        1. Orçamento de marketing aprovado em 20 mil
        DECISOES: lançar primeiro no iPhone
        TAREFAS:
        • Ana prepara as capturas até sexta
        - Bruno revisa o texto da loja
        DÚVIDAS:
        - (nada)
        """
        let n = ReuniaoLogica.lerNotas(r)
        check(n.pontos == ["Lançamento do app previsto para novembro", "Orçamento de marketing aprovado em 20 mil"], "pontos \(n.pontos)")
        check(n.decisoes == ["lançar primeiro no iPhone"], "decisão na mesma linha \(n.decisoes)")
        check(n.tarefas.count == 2 && n.tarefas[0].hasPrefix("Ana"), "tarefas \(n.tarefas)")
        check(n.duvidas.isEmpty, "«(nada)» ignorado")
        var acumulado = n
        acumulado.incorporar(ReuniaoLogica.lerNotas("TAREFAS:\n- ana prepara as capturas ate sexta\n- Carla agenda a demo"))
        check(acumulado.tarefas.count == 3, "sem repetir item igual (acento/caixa)")
        check(ReuniaoLogica.blocoNovo(String(repeating: "a", count: 100), processados: 0) == nil, "bloco pequeno espera")
        check(ReuniaoLogica.blocoNovo(String(repeating: "a", count: 500), processados: 100)?.count == 400, "bloco novo")
        check(ReuniaoLogica.blocoNovo(String(repeating: "a", count: 20_000), processados: 0)?.count == ReuniaoLogica.maximoBloco, "limite do bloco")
        check(ReuniaoLogica.transcricao(["Bom dia.", " Vamos começar. "], parcial: "Primeiro item") == "Bom dia. Vamos começar. Primeiro item", "junta segmentos")
        let md = ReuniaoLogica.markdown(titulo: "Planejamento", data: Date(timeIntervalSince1970: 0), segundos: 754, notas: n, resumo: "Resumo curto.", transcricao: "texto")
        check(md.contains("# Planejamento") && md.contains("12 min 34 s") && md.contains("### Decisões") && md.contains("## Transcrição"), "markdown")
        check(ReuniaoLogica.nomeArquivo(titulo: "Lançamento do App!", data: Date(timeIntervalSince1970: 0)).hasSuffix("-lancamento-do-app.md"), "nome de arquivo")
        check(ReuniaoLogica.duracao(3725) == "1 h 02 min", "duração longa")
        check(ReuniaoLogica.markdownNotas(NotasReuniao()).contains("Sem notas"), "sem notas")
        print("reuniao: \(ok)/\(ok) aprovados")
    }
}
