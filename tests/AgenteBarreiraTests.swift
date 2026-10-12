// Testes da barreira de segurança do agente do iPhone (agente-iphone/Fonte/Logica.swift): rótulos irreversíveis em PT/EN,
// campo de senha, bundle, extração de ação do texto do modelo, privacidade do snapshot e acoplamento com o Runner.
// Complementa agente-iphone/testes/LogicaTests.swift (12 asserções). Lógica pura: nada toca um aparelho.
import Foundation

@main struct AgenteBarreiraTests {
    static func els(_ itens: [(String, String)]) -> [Elemento] {
        itens.enumerated().map { Elemento(n: $0.offset + 1, tipo: $0.element.0, rotulo: $0.element.1, x: 10, y: 10 + $0.offset * 50, valor: "") }
    }

    static func rotulos() {
        let bloqueados = ["Enviar", "enviar", "ENVIAR", "Enviar mensagem", "Send", "Comprar agora", "Buy now", "Pagar", "Pay", "Apple Pay", "Excluir", "Excluir conta",
                          "Apagar", "Apagar tudo", "Delete", "Delete Account", "Remover", "Remove", "Publicar", "Post", "Transferir", "Transfer", "Confirmar pedido",
                          "Place order", "Finalizar compra", "Sair da conta", "Sign out", "Redefinir", "Reset", "Erase All Content"]
        for r in bloqueados { T.check(Logica.ehIrreversivel(r), "barreira bloqueia «\(r)»") }
        let livres = ["Geral", "Voltar", "Buscar", "Ajustes", "Wi-Fi", "Cancelar", "Mensagens", "Minhas compras", "Postagens", "Support", "Pagamento", "Sobre", "Bluetooth", "Rolar"]
        for r in livres { T.check(!Logica.ehIrreversivel(r), "barreira NÃO bloqueia «\(r)»") }
        // Falsos positivos aceitáveis (falham para o lado seguro):
        T.check(Logica.ehIrreversivel("Remover da tela de início") && Logica.ehIrreversivel("Post office"), "falso positivo conhecido e seguro: palavra isolada «remover»/«post» em qualquer rótulo")
        // Lacunas: ações com efeito difícil de desfazer que a lista NÃO cobre hoje.
        let lacunas = ["Ligar", "Call", "Chamar", "Aceitar", "Accept", "Confirmar", "Confirm", "Assinar", "Subscribe", "Autorizar", "Postar", "Deletar",
                       "Cancelar assinatura", "Cancel subscription", "Fazer pedido", "Concluir compra", "Complete Purchase", "Submit", "Doar", "Donate", "Log Out",
                       "Encerrar sessão", "Desinstalar", "Uninstall", "Limpar tudo", "Clear All", "Compartilhar", "Share", "Responder", "Reply", "Aprovar", "Pedir"]
        let naoBloqueados = lacunas.filter { !Logica.ehIrreversivel($0) }
        T.lacuna("\(naoBloqueados.count) de \(lacunas.count) rótulos de efeito externo/irreversível NÃO são barrados", confirmada: naoBloqueados.count > 0, naoBloqueados.joined(separator: " | "))
        T.lacuna("rótulos só por ícone/acessibilidade vazia («paperplane», sem texto) não são analisados — a barreira só lê o texto do rótulo", confirmada: !Logica.ehIrreversivel("paperplane.fill") && !Logica.ehIrreversivel(""))
    }

    static func validar() {
        let lista = els([("Button", "Geral"), ("Button", "Enviar"), ("SecureTextField", "Senha"), ("TextField", "Número do cartão"), ("Button", "Cancelar")])
        T.check(Logica.validar(Acao(nome: "tocar", n: 1), lista).0, "tocar em botão comum é permitido")
        let env = Logica.validar(Acao(nome: "tocar", n: 2), lista)
        T.check(!env.0 && env.1.contains("confirmação") && env.1.contains("Enviar"), "tocar em «Enviar» é barrado e pede confirmação", env.1)
        T.check(!Logica.validar(Acao(nome: "tocar", n: 99), lista).0 && !Logica.validar(Acao(nome: "tocar"), lista).0, "tocar em n inexistente ou ausente é barrado")
        let senha = Logica.validar(Acao(nome: "digitar", n: 3, texto: "123"), lista)
        T.check(!senha.0 && senha.1.contains("senha"), "digitar em SecureTextField é barrado", senha.1)
        T.check(Logica.validar(Acao(nome: "digitar", n: 4, texto: "olá"), lista).0, "digitar em campo comum é permitido")
        T.check(!Logica.validar(Acao(nome: "digitar", n: 4, texto: "   "), lista).0 && !Logica.validar(Acao(nome: "digitar", n: 4), lista).0, "digitar texto vazio é barrado")
        for dir in ["cima", "baixo", "esquerda", "direita"] { T.check(Logica.validar(Acao(nome: "rolar", direcao: dir), lista).0 && Logica.validar(Acao(nome: "deslizar", direcao: dir), lista).0, "rolar/deslizar \(dir)") }
        T.check(!Logica.validar(Acao(nome: "rolar", direcao: "diagonal"), lista).0 && !Logica.validar(Acao(nome: "rolar"), lista).0, "direção inválida ou ausente é barrada")
        for ok in ["com.apple.Preferences", "net.whatsapp.WhatsApp", "abc", "a.b-c.D1"] { T.check(Logica.validar(Acao(nome: "abrir", bundle: ok), lista).0, "bundle válido «\(ok)»") }
        for ruim in ["", "ab", "a b", "a;rm -rf", "../x", "com/apple", String(repeating: "a", count: 121), "com.apple.é"] { T.check(!Logica.validar(Acao(nome: "abrir", bundle: ruim), lista).0, "bundle inválido «\(ruim.prefix(20))»") }
        for livre in ["inicio", "voltar", "esperar", "fim"] { T.check(Logica.validar(Acao(nome: livre), lista).0, "ação sem alvo «\(livre)» passa") }
        // Acoplamento com Runner/Agente.swift: o motivo decide se a tarefa vira «aguarda_dono».
        let motivosDono = [Logica.validar(Acao(nome: "tocar", n: 2), lista).1, senha.1]
        let motivosRecusa = [Logica.validar(Acao(nome: "tocar", n: 99), lista).1, Logica.validar(Acao(nome: "digitar", n: 4), lista).1,
                             Logica.validar(Acao(nome: "rolar", direcao: "x"), lista).1, Logica.validar(Acao(nome: "abrir", bundle: "x"), lista).1]
        T.check(motivosDono.allSatisfy { $0.contains("confirmação") || $0.contains("senha") }, "motivos de irreversível/senha contêm as palavras que o Runner usa para parar em aguarda_dono")
        T.check(motivosRecusa.allSatisfy { !$0.contains("confirmação") && !$0.contains("senha") }, "motivos de erro comum NÃO contêm essas palavras (a tarefa continua em vez de parar)")
        let runner = T.ler("agente-iphone/Runner/Agente.swift")
        T.check(runner.contains("motivo.contains(\"confirmação\") || motivo.contains(\"senha\")"), "Runner usa exatamente «confirmação»/«senha» para parar")
        // Lacunas da validação
        T.lacuna("digitar SEM n (campo em foco) não passa pela checagem de SecureTextField — pode digitar numa senha já focada", confirmada: Logica.validar(Acao(nome: "digitar", texto: "123456"), lista).0)
        T.lacuna("o texto digitado nunca é analisado (número de cartão em campo comum, instruções vindas da tela)", confirmada: Logica.validar(Acao(nome: "digitar", n: 4, texto: "4111 1111 1111 1111"), lista).0)
        T.lacuna("campo comum cujo rótulo é «Número do cartão»/«CVV»/«Password» (TextField, não Secure) aceita digitação", confirmada: Logica.validar(Acao(nome: "digitar", n: 4, texto: "123"), lista).0)
        T.check(!Logica.validar(Acao(nome: "abrir", bundle: "com.apple.Preferences\n"), lista).0, "bundle com quebra de linha no fim é rejeitado")
        T.lacuna("abrir aceita qualquer bundle válido, inclusive Telefone/Carteira/bancos — só a lista no prompt sugere os usuais", confirmada: Logica.validar(Acao(nome: "abrir", bundle: "com.apple.mobilephone"), lista).0 && Logica.validar(Acao(nome: "abrir", bundle: "com.apple.Passbook"), lista).0)
    }

    static func extrair() {
        T.check(Logica.extrairAcao(#"{"acao":"tocar","n":3}"#) == Acao(nome: "tocar", n: 3), "extrai JSON puro")
        T.check(Logica.extrairAcao("```json\n{\"acao\":\"rolar\",\"direcao\":\"baixo\"}\n```")?.direcao == "baixo", "extrai JSON dentro de cerca de código")
        T.check(Logica.extrairAcao("Vou tocar. {\"acao\":\"tocar\",\"n\":2} pronto")?.n == 2, "extrai JSON cercado de texto")
        T.check(Logica.extrairAcao(#"{"acao":"tocar","n":3.0}"#)?.n == 3, "n decimal (3.0) vira inteiro")
        T.check(Logica.extrairAcao(#"{"acao":"tocar","n":"3"}"#)?.n == nil, "n como texto é ignorado (a validação barra depois)")
        T.check(Logica.extrairAcao("<think>{\"acao\":\"tocar\",\"n\":9}</think>{\"acao\":\"voltar\"}")?.nome == "voltar", "ignora ação dentro de <think>")
        T.check(Logica.extrairAcao(#"{"acao":"fim","resposta":"feito {ok}"}"#)?.resposta == "feito {ok}", "chaves dentro de texto da resposta")
        T.check(Logica.extrairAcao(#"{"acao":"voar"}"#) == nil && Logica.extrairAcao("nada") == nil && Logica.extrairAcao("") == nil && Logica.extrairAcao("{") == nil, "ação desconhecida, vazio e lixo → nil")
        T.check(Logica.extrairAcao(#"{"acao":"tocar","n":1} depois {"acao":"fim"}"#)?.nome == "tocar", "duas ações: vale a primeira")
        T.check(Logica.extrairAcao(#"{"acao":"digitar","texto":"olá","n":2}"#)?.texto == "olá", "texto digitado preservado")
        let t0 = Date()
        _ = Logica.extrairAcao(String(repeating: "{", count: 1200) + "sem fim")
        let dt = Date().timeIntervalSince(t0)
        T.check(dt < 5, "saída hostil com 1200 chaves não trava (tempo \(String(format: "%.2f", dt)) s)")
        T.lacuna("se o modelo responder 2 ações, a segunda é descartada em silêncio (o Runner executa só uma por passo)", confirmada: Logica.extrairAcao(#"{"acao":"voltar"}{"acao":"inicio"}"#)?.nome == "voltar")
    }

    static func privacidade() {
        let raiz = No(tipo: "Application", rotulo: "", valor: "", x: 0, y: 0, w: 400, h: 800, filhos: [
            No(tipo: "TextField", rotulo: "Nome", valor: "texto digitado visível", x: 10, y: 100, w: 300, h: 40),
            No(tipo: "SecureTextField", rotulo: "Senha", valor: "segredo-que-nao-pode-sair", x: 10, y: 160, w: 300, h: 40),
            No(tipo: "Button", rotulo: String(repeating: "x", count: 200), valor: "", x: 10, y: 220, w: 300, h: 40),
        ])
        let lista = Logica.simplificar(raiz, largura: 400, altura: 800)
        let senha = lista.first { $0.tipo == "SecureTextField" }
        T.check(senha != nil && senha?.valor == "", "valor do campo de senha NÃO entra na lista enviada ao modelo")
        T.check(lista.first { $0.tipo == "TextField" }?.valor == "texto digitado visível", "valor de campo comum entra na lista (vai ao modelo)")
        T.check(lista.last?.rotulo.count == 80, "rótulo truncado em 80 caracteres")
        let texto = Logica.descrever(lista)
        T.check(!texto.contains("segredo-que-nao-pode-sair"), "descrição para o prompt não contém o valor da senha")
        T.lacuna("o rótulo/valor de campos comuns (nome, e-mail, números) e a captura de tela JPEG vão ao servidor do modelo (URL configurável) — dado pessoal sai do aparelho se o LLM for externo", confirmada: T.ler("agente-iphone/Runner/Agente.swift").contains("data:image/jpeg;base64"))
        let muitos = No(tipo: "Application", rotulo: "", valor: "", x: 0, y: 0, w: 400, h: 4000, filhos: (0..<200).map { No(tipo: "Button", rotulo: "Item \($0)", valor: "", x: 10, y: Double($0) * 10 + 5, w: 100, h: 8) })
        T.check(Logica.simplificar(muitos, largura: 400, altura: 4000).count == 70, "lista limitada a 70 elementos")
        T.check(Logica.simplificar(muitos, largura: 400, altura: 4000, limite: 5).map { $0.n } == [1, 2, 3, 4, 5], "numeração sequencial a partir de 1")
        T.check(Logica.descrever([]) == "(tela sem elementos legíveis)", "tela vazia descrita")
        let m = Logica.mensagens(objetivo: "abrir Geral", app: "com.apple.Preferences", elementos: lista, historico: (1...12).map { "passo \($0)" })
        let u = m[1]["content"] ?? ""
        T.check(m[0]["role"] == "system" && m[1]["role"] == "user" && u.contains("OBJETIVO: abrir Geral") && u.contains("APP EM PRIMEIRO PLANO: com.apple.Preferences"), "mensagens: papéis e campos")
        T.check(!u.contains("- passo 4") && u.contains("- passo 5") && u.contains("- passo 12"), "mensagens: só os 8 últimos passos entram")
        let s = m[0]["content"] ?? ""
        T.check(s.contains("nunca toque em enviar, pagar, excluir ou publicar") && s.contains("nunca digite senha") && s.contains("SOMENTE com um JSON"), "prompt do agente repete as regras de segurança")
        T.check(Logica.mensagens(objetivo: "x", app: "y", elementos: [], historico: [])[1]["content"]?.contains("(nenhum)") == true, "sem histórico: «(nenhum)»")
    }

    static func runner() {
        let r = T.ler("agente-iphone/Runner/Agente.swift")
        T.check(r.contains("p.requiredInterfaceType = .loopback"), "servidor do agente só aceita interface loopback")
        T.check(r.contains("guard !agente.cfg.token.isEmpty, auth == \"Bearer \\(agente.cfg.token)\""), "toda rota exige token não vazio (sem token configurado → 401)")
        T.check(r.contains("var maxPassos = 14") && r.contains("String(objetivo.prefix(500))"), "limite de 14 passos e objetivo de até 500 caracteres")
        T.check(r.contains("if tarefas.values.contains(where: { $0.estado == \"executando\" }) { return nil }") && r.contains("409"), "uma tarefa por vez (409 se já houver)")
        T.check(r.contains("if recusas >= 3"), "3 respostas sem ação válida encerram a tarefa")
        T.check(r.contains("let (ok, motivo) = Logica.validar(acao, els)"), "toda ação passa por Logica.validar antes de executar")
        T.lacuna("o token do agente é comparado com == (não em tempo constante) e fica em UserDefaults do PocketSelf (texto claro, não Keychain)", confirmada: r.contains("auth == \"Bearer") && T.ler("app/PocketSelf/ControleIphone.swift").contains("UserDefaults.standard.string(forKey: chaveToken)"))
        T.lacuna("a barreira usa o rótulo do elemento da lista ANTERIOR ao toque: se a tela mudar entre a leitura e o toque o rótulo pode estar desatualizado (toque por coordenada)", confirmada: r.contains("aparelho.tocar(e.x, e.y)"))
    }

    static func main() {
        rotulos()
        validar()
        extrair()
        privacidade()
        runner()
        T.fim("agente-barreira")
    }
}
