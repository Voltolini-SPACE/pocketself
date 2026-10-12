import Foundation
@main struct T {
    static func main() {
        let raiz = No(tipo: "Other", rotulo: "", valor: "", x: 0, y: 0, w: 440, h: 956, filhos: [
            No(tipo: "Button", rotulo: "Geral", valor: "", x: 0, y: 100, w: 440, h: 50, filhos: [
                No(tipo: "StaticText", rotulo: "Geral", valor: "", x: 20, y: 110, w: 100, h: 30),
                No(tipo: "Image", rotulo: "", valor: "", x: 10, y: 110, w: 30, h: 30)]),
            No(tipo: "Button", rotulo: "Enviar", valor: "", x: 0, y: 300, w: 100, h: 50),
            No(tipo: "SecureTextField", rotulo: "Senha", valor: "x", x: 0, y: 400, w: 200, h: 40),
            No(tipo: "Button", rotulo: "Fora", valor: "", x: 0, y: 2000, w: 100, h: 50)])
        let els = Logica.simplificar(raiz, largura: 440, altura: 956)
        precondition(els.map(\.rotulo) == ["Geral", "Enviar", "Senha"], "\(els)")
        precondition(els.map(\.n) == [1, 2, 3])
        precondition(Logica.descrever(els).hasPrefix("1. Button \"Geral\""))
        let a = Logica.extrairAcao("<think>x {\"acao\":\"fim\"}</think> ok {\"acao\":\"tocar\",\"n\":1} fim")
        precondition(a == Acao(nome: "tocar", n: 1), "\(String(describing: a))")
        precondition(Logica.extrairAcao("sem json") == nil && Logica.extrairAcao("{\"acao\":\"voar\"}") == nil)
        precondition(Logica.validar(Acao(nome: "tocar", n: 1), els).0)
        precondition(!Logica.validar(Acao(nome: "tocar", n: 2), els).0)
        precondition(Logica.validar(Acao(nome: "tocar", n: 2), els).1.contains("confirmação"))
        precondition(!Logica.validar(Acao(nome: "digitar", n: 3, texto: "123"), els).0)
        precondition(!Logica.validar(Acao(nome: "abrir", bundle: "a b;rm"), els).0)
        precondition(Logica.validar(Acao(nome: "abrir", bundle: "com.apple.Preferences"), els).0)
        precondition(Logica.mensagens(objetivo: "x", app: "y", elementos: els, historico: []).count == 2)
        let tela = No(tipo: "Application", rotulo: "", valor: "", x: 0, y: 0, w: 393, h: 852, filhos: [
            No(tipo: "Button", rotulo: "Visível", valor: "", x: 10, y: 100, w: 300, h: 40),
            No(tipo: "Button", rotulo: "Geral", valor: "", x: 10, y: 790, w: 300, h: 40),
            No(tipo: "SearchField", rotulo: "Buscar", valor: "", x: 0, y: 770, w: 393, h: 82)])
        let r = Logica.simplificar(tela, largura: 393, altura: 852).map { $0.rotulo }
        precondition(r.contains("Visível") && r.contains("Buscar") && !r.contains("Geral"), "\(r)")
        print("logica: 12/12 aprovados")
    }
}
