// PocketSelf Decide — Sistema 1 próprio (estilo Jev/TypeSafe), 100% no aparelho.
// Não gera texto: devolve uma decisão tipada com probabilidade calibrada, em milissegundos.
// Porte do decidir.mjs da Spark: n-gramas + Naive Bayes multinomial + temperatura calibrada por validação cruzada.
// Aprende com o uso: cada ferramenta que o modelo chamou e cada confirmação do dono vira exemplo local.
import Foundation

enum Intencao: String, Codable, CaseIterable {
    case conversa, hora, aparelho, agenda_listar, agenda_criar, lembrete, memoria, web, apps, contato, imagem, profundo
    var nome: String {
        switch self {
        case .conversa: return "conversa"
        case .hora: return "hora e data"
        case .aparelho: return "estado do aparelho"
        case .agenda_listar: return "ver agenda"
        case .agenda_criar: return "marcar compromisso"
        case .lembrete: return "lembrete"
        case .memoria: return "guardar na memória"
        case .web: return "pesquisa na web"
        case .apps: return "notas, alarmes, música e atalhos"
        case .contato: return "contatos, mensagem e ligação"
        case .imagem: return "criar imagem"
        case .profundo: return "pergunta difícil (servidor)"
        }
    }
    /// Ferramentas que a sessão precisa expor para esta intenção (o resto fica fora do prompt).
    var ferramentas: [String] {
        switch self {
        case .conversa: return []
        case .hora: return ["hora_e_data"]
        case .aparelho: return ["estado_do_aparelho", "minha_localizacao"]
        case .agenda_listar: return ["hora_e_data", "agenda_listar"]
        case .agenda_criar: return ["hora_e_data", "agenda_criar"]
        case .lembrete: return ["hora_e_data", "lembrete_criar"]
        case .memoria: return ["lembrar"]
        case .web: return ["pesquisar_web", "ler_pagina"]
        case .apps: return ["hora_e_data", "criar_nota", "criar_alarme", "rodar_atalho", "tocar_musica", "abrir_app", "lanterna", "sinalizar_sos", "brilho_tela", "timer", "controlar_iphone", "controle_resultado"]
        case .contato: return ["buscar_contato", "enviar_mensagem", "enviar_email", "ligar"]
        case .imagem: return ["criar_imagem"]
        case .profundo: return ["consultar_spark"]
        }
    }
    static func daTipo(_ t: Pendencia.Tipo) -> Intencao {
        switch t { case .evento: return .agenda_criar; case .lembrete: return .lembrete; case .nota, .alarme, .atalho: return .apps; case .mensagem, .email, .ligacao: return .contato }
    }

    static func daFerramenta(_ nome: String) -> Intencao? {
        switch nome {
        case "hora_e_data": return .hora
        case "estado_do_aparelho", "minha_localizacao": return .aparelho
        case "agenda_listar": return .agenda_listar
        case "agenda_criar": return .agenda_criar
        case "lembrete_criar": return .lembrete
        case "lembrar": return .memoria
        case "pesquisar_web", "ler_pagina": return .web
        case "criar_nota", "criar_alarme", "rodar_atalho", "tocar_musica", "abrir_app", "lanterna", "sinalizar_sos", "brilho_tela", "timer", "controlar_iphone", "controle_resultado": return .apps
        case "buscar_contato", "enviar_mensagem", "enviar_email", "ligar": return .contato
        case "criar_imagem": return .imagem
        case "consultar_spark": return .profundo
        default: return nil
        }
    }
}

struct Exemplo: Codable, Equatable {
    var texto: String
    var classe: Intencao
    var origem: String      // semente | ferramenta | confirmacao | dono
    var em = Date()
}

struct Decisao {
    let classe: Intencao
    let probabilidade: Double
    let ranking: [(Intencao, Double)]
    let ms: Double
    var confiavel: Bool { probabilidade >= Decisor.limiar }
    var resumo: String { String(format: "%@ %.2f · %.1f ms", classe.nome, probabilidade, ms) }
}

@Observable
@MainActor
final class Decisor {
    static let limiar = 0.80

    private(set) var exemplos: [Exemplo] = []
    private(set) var temperatura = 1.0
    private(set) var ece = 0.0
    private(set) var acertoCV = 0.0
    private(set) var ultimas: [String] = []

    @ObservationIgnored private var modelo = Modelo()

    private let arquivo: URL

    init(arquivo: URL? = nil) {
        self.arquivo = arquivo ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("decisor.json")
        if let d = try? Data(contentsOf: self.arquivo) {
            let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
            exemplos = (try? dec.decode([Exemplo].self, from: d)) ?? []
        }
        do {  // sementes novas entram em atualizações; as já existentes não duplicam
            let existentes = Set(exemplos.map { $0.texto })
            for (classe, frases) in Self.sementes where true {
                for f in frases where !existentes.contains(f) { exemplos.append(Exemplo(texto: f, classe: classe, origem: "semente")) }
            }
        }
        treinar()
    }

    // MARK: Uso

    func decidir(_ texto: String) -> Decisao {
        let t0 = Date.timeIntervalSinceReferenceDate
        let probs = modelo.probabilidades(texto, temperatura: temperatura)
        let ranking = probs.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
        let (classe, p) = ranking.first ?? (.conversa, 1)
        let d = Decisao(classe: classe, probabilidade: p, ranking: ranking, ms: (Date.timeIntervalSinceReferenceDate - t0) * 1000)
        ultimas.insert("\(String(texto.prefix(40))) → \(d.resumo)", at: 0)
        if ultimas.count > 20 { ultimas.removeLast() }
        print(String(format: "[neo-decide] classe=%@ p=%.2f ms=%.2f confiavel=%d", classe.rawValue, p, d.ms, d.confiavel ? 1 : 0))
        return d
    }

    /// Aprendizado legítimo: o uso real vira exemplo. Retreina e recalibra em milissegundos.
    func aprender(_ texto: String, classe: Intencao, origem: String) {
        let t = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count >= 3, !exemplos.contains(where: { $0.texto == t && $0.classe == classe }) else { return }
        exemplos.append(Exemplo(texto: t, classe: classe, origem: origem))
        salvar()
        treinar()
        print("[neo-decide] aprendeu classe=\(classe.rawValue) origem=\(origem) total=\(exemplos.count)")
    }

    func esquecer(_ e: Exemplo) {
        exemplos.removeAll { $0 == e }
        salvar(); treinar()
    }

    var porOrigem: [(String, Int)] {
        Dictionary(grouping: exemplos, by: { $0.origem }).map { ($0.key, $0.value.count) }.sorted { $0.0 < $1.0 }
    }

    private func salvar() {
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        if let d = try? enc.encode(exemplos) {
            let novo = arquivo.appendingPathExtension("novo")
            try? d.write(to: novo, options: .atomic)
            _ = try? FileManager.default.replaceItemAt(arquivo, withItemAt: novo)
        }
    }

    // MARK: Treino e calibração

    private func treinar() {
        let t0 = Date.timeIntervalSinceReferenceDate
        modelo = Modelo(exemplos: exemplos)
        (temperatura, ece, acertoCV) = Self.calibrar(exemplos)
        print(String(format: "[neo-decide] treinado exemplos=%d T=%.2f ECE=%.3f acertoCV=%.2f em %.0f ms", exemplos.count, temperatura, ece, acertoCV, (Date.timeIntervalSinceReferenceDate - t0) * 1000))
    }

    /// Validação cruzada em 5 partes: escolhe a temperatura que minimiza o ECE fora da amostra.
    private static func calibrar(_ ex: [Exemplo]) -> (Double, Double, Double) {
        guard ex.count >= 10 else { return (1, 0, 0) }
        let k = 5
        var partes: [[Exemplo]] = Array(repeating: [], count: k)
        for (i, e) in ex.enumerated() { partes[i % k].append(e) }
        // logits fora da amostra, por exemplo
        var foraDaAmostra: [([Intencao: Double], Intencao)] = []
        for i in 0..<k {
            let treino = partes.enumerated().filter { $0.offset != i }.flatMap { $0.element }
            let m = Modelo(exemplos: treino)
            for e in partes[i] { foraDaAmostra.append((m.logVerossimilhancas(e.texto), e.classe)) }
        }
        var melhorT = 1.0, melhorECE = Double.infinity, acerto = 0.0
        for T in stride(from: 0.2, through: 6.0, by: 0.2) {
            var e = 0.0, a = 0.0
            // ECE com 10 faixas
            var faixas = Array(repeating: (conf: 0.0, acc: 0.0, n: 0.0), count: 10)
            for (logs, verdade) in foraDaAmostra {
                let p = Modelo.softmax(logs, temperatura: T)
                guard let top = p.max(by: { $0.value < $1.value }) else { continue }
                let certo = top.key == verdade ? 1.0 : 0.0
                a += certo
                let f = min(Int(top.value * 10), 9)
                faixas[f].conf += top.value; faixas[f].acc += certo; faixas[f].n += 1
            }
            let n = Double(foraDaAmostra.count)
            for fx in faixas where fx.n > 0 { e += (fx.n / n) * abs(fx.acc / fx.n - fx.conf / fx.n) }
            if e < melhorECE { melhorECE = e; melhorT = T; acerto = a / n }
        }
        return (melhorT, melhorECE, acerto)
    }

    // MARK: Modelo (n-gramas + Naive Bayes multinomial)

    struct Modelo {
        private var contagem: [Intencao: [String: Double]] = [:]
        private var total: [Intencao: Double] = [:]
        private var prior: [Intencao: Double] = [:]
        private var vocabulario = 1.0

        init() {}
        init(exemplos: [Exemplo]) {
            var vocab = Set<String>()
            for e in exemplos {
                let fs = Modelo.tracos(e.texto)
                for f in fs { contagem[e.classe, default: [:]][f, default: 0] += 1; vocab.insert(f) }
                total[e.classe, default: 0] += Double(fs.count)
                prior[e.classe, default: 0] += 1
            }
            vocabulario = Double(max(vocab.count, 1))
        }

        static func normalizar(_ s: String) -> String {
            s.lowercased().folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
        }

        /// Palavras, bigramas de palavras e trigramas de caracteres (robusto a erro de digitação e fala).
        static func tracos(_ s: String) -> [String] {
            let palavras = normalizar(s).components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
            var fs: [String] = []
            for (i, p) in palavras.enumerated() {
                fs.append("w:" + p)
                if i + 1 < palavras.count { fs.append("b:" + p + "_" + palavras[i + 1]) }
                let c = Array("_" + p + "_")
                if c.count >= 3 { for j in 0...(c.count - 3) { fs.append("c:" + String(c[j..<j + 3])) } }
            }
            return fs
        }

        func logVerossimilhancas(_ texto: String) -> [Intencao: Double] {
            let fs = Modelo.tracos(texto)
            let nTotal = prior.values.reduce(0, +)
            var out: [Intencao: Double] = [:]
            for c in Intencao.allCases {
                let pc = (prior[c] ?? 0) + 1
                var l = log(pc / (nTotal + Double(Intencao.allCases.count)))
                let tot = (total[c] ?? 0) + vocabulario
                let cont = contagem[c] ?? [:]
                for f in fs { l += log(((cont[f] ?? 0) + 1) / tot) }
                out[c] = l
            }
            return out
        }

        static func softmax(_ logs: [Intencao: Double], temperatura: Double) -> [Intencao: Double] {
            let m = logs.values.max() ?? 0
            var exps: [Intencao: Double] = [:]
            for (c, l) in logs { exps[c] = exp((l - m) / temperatura) }
            let z = exps.values.reduce(0, +)
            return exps.mapValues { $0 / max(z, 1e-12) }
        }

        func probabilidades(_ texto: String, temperatura: Double) -> [Intencao: Double] {
            Modelo.softmax(logVerossimilhancas(texto), temperatura: temperatura)
        }
    }

    // MARK: Sementes (pt-BR)

    static let sementes: [(Intencao, [String])] = [
        (.profundo, ["Analise em detalhes os prós e contras de abrir uma empresa", "Faça um plano de estudos completo de 3 meses para aprender Python", "Explique passo a passo como calcular o financiamento de um imóvel com juros de 1% ao mês", "Escreva um código em Swift que ordena uma lista de contatos por nome", "Compare detalhadamente três estratégias de investimento para longo prazo", "Escreva um texto longo e bem estruturado sobre liderança", "Resolva este problema de lógica com raciocínio completo", "Pense com calma e me dê uma análise profunda sobre esse contrato", "Monte uma estratégia de marketing completa para uma padaria", "Calcule quanto rende 10 mil reais por 5 anos a 1% ao mês"]),
        (.imagem, ["Crie uma imagem de um gato astronauta", "Desenhe um robô tomando café", "Gere uma ilustração de uma praia ao pôr do sol", "Faça um desenho de um cachorro de óculos", "Crie uma imagem para o meu aniversário", "Desenha uma casa na montanha em estilo esboço", "Quero uma figura de um foguete", "Gere um avatar de um mago", "Crie uma ilustração de uma cidade futurista", "Faça uma imagem fofa de um panda"]),
        (.apps, ["Faça sinal de SOS com a lanterna", "Pisque a lanterna pedindo socorro", "Estou perdido, sinalize SOS com a luz", "Abra o Spotify e toque Djavan", "Toca um podcast no Spotify", "Abre o YouTube com vídeos de receita", "Chama um Uber para o aeroporto", "Abre o WhatsApp", "Liga a lanterna", "Apaga a lanterna", "Diminui o brilho da tela", "Põe um timer de 10 minutos", "Me avisa daqui a 5 minutos que o café está pronto", "Abre o Instagram", "Mostra no mapa a farmácia mais próxima", "Crie uma nota com a lista de compras", "Anota no Notas: ideias para o projeto", "Coloque um alarme para as 6 da manhã", "Me acorda às 7h", "Põe um alarme às 14:30 chamado reunião", "Toque Legião Urbana", "Toca uma música do Djavan", "Pausa a música", "Rode o atalho Boa noite", "Execute o atalho Chegando em casa", "Acenda as luzes da sala", "Salve isso numa nota"]),
        (.contato, ["Qual o telefone da Maria?", "Mande uma mensagem para o João dizendo que vou atrasar", "Envie um e-mail para o contador pedindo o boleto", "Ligue para a minha esposa", "Liga para o Pedro", "Manda um SMS para o Carlos: chego em 10 minutos", "Qual o e-mail do Carlos?", "Escreve para a Ana que a reunião foi adiada", "Procure o contato do dentista", "Telefone para a farmácia"]),
        (.web, ["Pesquise na internet o preço do dólar hoje", "Quais as últimas notícias sobre inteligência artificial?", "Procure na web o horário do jogo do Brasil", "Busque o site oficial da Apple", "Qual a previsão do tempo para amanhã em Curitiba?", "Pesquise quem ganhou o jogo ontem", "Leia esta página: https://example.com", "Me traga as notícias de hoje", "Quanto está a cotação do bitcoin agora?", "Pesquise avaliações do iPhone 17", "Procure o telefone da farmácia mais próxima", "O que está acontecendo no mundo hoje?"]),
        (.conversa, ["Oi, tudo bem?", "Bom dia", "Me explique o que é inteligência artificial", "Qual a capital da França?", "Me ajude a escrever um e-mail para um cliente", "Resuma este texto em três frases", "O que você acha dessa ideia?", "Traduza para o inglês: bom dia", "Me conte uma curiosidade", "Como funciona a internet?", "Quero explorar uma ideia com você", "Me dê três sugestões de nome para um projeto", "Explique de forma simples o que é um cartão de crédito", "Qual a diferença entre PIX e TED?", "Corrige o português desta frase", "Conte uma piada curta", "O que é um iPhone?", "Me ajude a organizar as ideias de uma reunião", "Escreva um parágrafo sobre liderança", "Sim", "Não, obrigado", "Continue", "Pode repetir?", "Responda só sim ou não: o céu é azul?"]),
        (.hora, ["Que horas são?", "Que dia é hoje?", "Que dia e que horas são agora?", "Hoje é que dia da semana?", "Me diz a data de hoje", "Em que ano estamos?", "Que horas são agora?", "Já passou do meio-dia?", "Qual é a data completa de hoje?", "Hoje é sexta?", "Quantos dias faltam para o fim do mês?", "Que dia será depois de amanhã?"]),
        (.aparelho, ["Qual é a minha localização?", "Onde eu estou agora?", "Me diga minhas coordenadas de GPS", "Qual a minha latitude e longitude?", "Como está a bateria?", "Como está a bateria deste iPhone?", "O iPhone está quente?", "Quanta memória livre tem?", "Qual o estado do aparelho?", "Está carregando?", "Me diz a porcentagem da bateria", "O celular está esquentando?", "Quanto de memória o app pode usar?", "Diagnóstico do aparelho"]),
        (.agenda_listar, ["O que tenho na agenda hoje?", "Quais são meus compromissos de amanhã?", "Veja minha agenda de hoje", "Tenho algo marcado esta semana?", "Mostre meus próximos compromissos", "O que tem no meu calendário?", "Tenho reunião hoje?", "Liste a agenda dos próximos três dias", "Que horas é minha próxima reunião?", "Estou livre amanhã à tarde?", "Me ajude a organizar o meu dia de hoje"]),
        (.agenda_criar, ["Marque uma reunião amanhã às 10", "Agende um almoço com o Pedro na sexta ao meio-dia", "Coloque na agenda dentista terça às 15h", "Crie um compromisso para segunda às 9: visita ao cliente", "Marca pra mim uma call às 16h", "Agenda uma consulta médica dia 20 às 8 da manhã", "Reserve uma hora amanhã para estudar", "Bloqueie minha agenda sexta à tarde", "Marque o aniversário da Ana no sábado", "Coloque no calendário a entrega do projeto dia 30"]),
        (.lembrete, ["Me lembre de ligar para o contador amanhã às 9", "Lembrete: pagar a conta de luz", "Me lembra de tomar o remédio às 20h", "Cria um lembrete para comprar leite", "Não me deixe esquecer de enviar o relatório na sexta", "Me lembre amanhã de manhã de responder o e-mail", "Lembra de mim: renovar o seguro do carro", "Adiciona um lembrete para o aniversário do João", "Me avise às 18h de buscar as crianças", "Me lembre daqui a uma hora de beber água", "Quero um lembrete para amanhã às 8 de pagar a conta"]),
        (.memoria, ["Guarde isso: eu prefiro respostas curtas", "Lembre que minha filha se chama Ana", "Anote que eu moro em Curitiba", "Para você saber: eu trabalho com meios de pagamento", "Memorize que eu acordo às 6 da manhã", "Eu prefiro respostas curtas e diretas, sem enrolação", "Quero que você lembre que meu carro é um Corolla", "Salve na memória: minha esposa se chama Maria", "Lembre-se que eu sou alérgico a camarão", "Guarde que o meu projeto principal se chama PocketSelf"]),
    ]
}
