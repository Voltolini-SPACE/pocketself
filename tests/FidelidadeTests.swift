import Foundation

@main struct Tests {
    static var ok = 0
    static func check(_ c: Bool, _ n: String) { if c { ok += 1 } else { print("FAIL \(n)"); exit(1) } }
    static func main() {
        let p = "Mande uma mensagem para o número 555-0100 dizendo: chego em 10 minutos."
        check(Fidelidade.trechoLiteral(p) == "chego em 10 minutos.", "trecho depois de «dizendo:»")
        check(Fidelidade.textoFiel(modelo: "cheiro em 10 minutos", pedido: p) == "chego em 10 minutos.", "«cheiro» volta a «chego»")
        check(Fidelidade.textoFiel(modelo: "chego em 10 minutos.", pedido: p) == "chego em 10 minutos.", "texto correto fica")
        check(Fidelidade.textoFiel(modelo: "Chego em 10 minutos", pedido: p) == "chego em 10 minutos." || Fidelidade.textoFiel(modelo: "Chego em 10 minutos", pedido: p) == "Chego em 10 minutos", "maiúscula não quebra")
        check(Fidelidade.trechoLiteral("Mande para a Ana: «te amo, tá?»") == "te amo, tá?", "aspas francesas")
        check(Fidelidade.trechoLiteral("Mande um oi para o João") == nil, "sem literal")
        check(Fidelidade.textoFiel(modelo: "Oi, João! Tudo bem?", pedido: "Mande um oi para o João") == "Oi, João! Tudo bem?", "sem literal usa o do modelo")
        // mensagem composta pelo modelo a partir de instrução: não sobrescrever
        check(Fidelidade.textoFiel(modelo: "Olá Ana, vou me atrasar uns 20 minutos, desculpe!", pedido: "Mande uma mensagem para Ana: avise que vou atrasar") == "Olá Ana, vou me atrasar uns 20 minutos, desculpe!", "instrução não vira literal")
        check(Fidelidade.distancia("abc", "abc") == 0 && Fidelidade.distancia("abc", "xyz") == 1, "distância")
        check(Fidelidade.corrigirCitacoes("A mensagem foi preparada com o texto \"cago em 10 minutos\". Confirme.", literal: "chego em 10 minutos.") == "A mensagem foi preparada com o texto \"chego em 10 minutos\". Confirme.", "citação corrigida")
        check(Fidelidade.corrigirCitacoes("Enviei «bom dia» para você.", literal: "chego em 10 minutos.") == "Enviei «bom dia» para você.", "citação diferente fica")
        print("fidelidade: \(ok)/\(ok) aprovados")
    }
}
