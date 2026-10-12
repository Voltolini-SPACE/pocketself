// Testes de lógica pura de Integracoes.swift: URL do app Atalhos, número de telefone, mapa de apps (Apps.url), pergunta externa
// (Atalhos/Siri → PocketSelf) e contratos estáticos dos App Intents. Trechos puros extraídos do arquivo real por tests/testar.sh.
import Foundation

@main struct IntegracoesTests {
    static let fonte = T.ler("app/PocketSelf/Integracoes.swift")

    static func parametros(_ u: URL?) -> [String: String] {
        guard let u, let c = URLComponents(url: u, resolvingAgainstBaseURL: false) else { return [:] }
        return Dictionary(uniqueKeysWithValues: (c.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    }

    static func atalhos() {
        T.check(Integracoes.atalhoNota == "PocketSelf Nota" && Integracoes.atalhoAlarme == "PocketSelf Alarme", "nomes exatos dos atalhos que o dono precisa criar")
        let u = Integracoes.urlAtalho(Integracoes.atalhoNota, texto: "comprar pão & leite = 2")
        T.check(u?.scheme == "shortcuts" && u?.host == "x-callback-url" && u?.path == "/run-shortcut", "urlAtalho: shortcuts://x-callback-url/run-shortcut", u?.absoluteString ?? "nil")
        let p = parametros(u)
        T.check(p["name"] == "PocketSelf Nota" && p["input"] == "text" && p["text"] == "comprar pão & leite = 2", "urlAtalho: nome, input=text e texto preservados (& e = sobrevivem)", "\(p)")
        T.check(parametros(Integracoes.urlAtalho("Boa noite", texto: nil)) == ["name": "Boa noite"], "urlAtalho: sem texto não envia input")
        let acentos = parametros(Integracoes.urlAtalho("Chegando em casa", texto: "açaí, café ☕️"))
        T.check(acentos["text"] == "açaí, café ☕️", "urlAtalho: acentos e emoji preservados", "\(acentos)")
        T.check(Integracoes.urlAtalho("", texto: "x") != nil, "urlAtalho: nome vazio ainda monta URL (o Atalhos recusa)")
        let alarme = parametros(Integracoes.urlAtalho(Integracoes.atalhoAlarme, texto: "06:30 | Acordar"))
        T.check(alarme["text"] == "06:30 | Acordar", "alarme: texto «HH:MM | rótulo» chega intacto ao atalho (separador « | »)", "\(alarme)")
    }

    static func numeros() {
        T.check(Integracoes.numeroLimpo("(41) 5555-0100") == "4155550100", "numeroLimpo: formatação brasileira")
        T.check(Integracoes.numeroLimpo("+55 41 5555-0100") == "+554155550100", "numeroLimpo: preserva +")
        T.check(Integracoes.numeroLimpo("Maria") == "", "numeroLimpo: nome vira vazio")
        T.check(Integracoes.numeroLimpo("1+2+3") == "1+2+3", "numeroLimpo: não valida posição do +")
        T.check(Integracoes.numeroLimpo("ramal 12 *31 #") == "12" + "31", "numeroLimpo: descarta *, # e letras")
    }

    static func mapaDeApps() {
        func ok(_ app: String, _ busca: String?, _ nome: String, _ url: String, _ rotulo: String) {
            let r = Apps.url(app: app, busca: busca)
            T.check(r?.nome == nome && r?.url.absoluteString == url, "Apps.url \(rotulo)", "\(r?.nome ?? "nil") \(r?.url.absoluteString ?? "nil")")
        }
        ok("spotify", "Djavan", "Spotify", "spotify:search:Djavan", "spotify com busca")
        ok("Spotify", nil, "Spotify", "spotify:", "spotify sem busca (maiúscula)")
        ok("youtube", "receita de bolo", "YouTube", "youtube://results?search_query=receita%20de%20bolo", "youtube com busca (espaços)")
        ok("you tube", nil, "YouTube", "youtube://", "«you tube» com espaço")
        ok("zap", "oi", "WhatsApp", "whatsapp://send?text=oi", "apelido zap")
        ok("WhatsApp", nil, "WhatsApp", "whatsapp://", "whatsapp sem busca")
        ok("instagram", "natgeo", "Instagram", "instagram://user?username=natgeo", "instagram abre perfil")
        ok("telegram", nil, "Telegram", "tg://", "telegram")
        ok("mapas", "padaria", "Mapas", "maps://?q=padaria", "mapas com busca")
        ok("maps", nil, "Mapas", "maps://", "maps sem busca")
        ok("safari", "tempo em Curitiba", "Safari", "https://www.google.com/search?q=tempo%20em%20Curitiba", "safari pesquisa no Google")
        ok("Música", nil, "Música", "music://", "música (acento ignorado)")
        ok("apple music", nil, "Música", "music://", "apple music")
        ok("Calendário", nil, "Calendário", "calshow://", "calendário (acento ignorado)")
        ok("lembretes", nil, "Lembretes", "x-apple-reminderkit://", "lembretes")
        ok("fotos", nil, "Fotos", "photos-redirect://", "fotos")
        ok("atalhos", nil, "Atalhos", "shortcuts://", "atalhos")
        ok("uber", nil, "Uber", "uber://", "uber sem destino")
        T.check(Apps.url(app: "tiktok", busca: nil) == nil && Apps.url(app: "", busca: nil) == nil && Apps.url(app: "banco", busca: "saldo") == nil, "Apps.url: app desconhecido ou vazio → nil (o modelo recebe «Não sei abrir»)")
        T.check(Apps.url(app: "spotify", busca: "")?.url.absoluteString == "spotify:", "Apps.url: busca vazia = abrir sem busca")
        // Cada URL gerada precisa ser válida e ter esquema estável.
        let esquemas = ["spotify", "youtube", "whatsapp", "instagram", "tg", "uber", "maps", "shortcuts", "music", "photos-redirect", "calshow", "x-apple-reminderkit", "app-settings", "https"]
        for app in ["spotify", "youtube", "whatsapp", "instagram", "telegram", "uber", "mapas", "ajustes", "safari", "musica", "fotos", "calendario", "lembretes", "atalhos"] {
            for busca in [nil, "açaí com leite", "100% café"] as [String?] {
                let r = Apps.url(app: app, busca: busca)
                T.check(r != nil && esquemas.contains(r!.url.scheme ?? ""), "Apps.url(\(app), \(busca ?? "nil")) gera URL com esquema conhecido", r?.url.absoluteString ?? "nil")
            }
        }
        // Defeitos/riscos (registrados, não corrigidos):
        let yt = Apps.url(app: "youtube", busca: "rock&roll=1")?.url.absoluteString ?? ""
        T.lacuna("Apps.url: '&' e '=' na busca não são codificados e quebram a consulta (youtube: \(yt))", confirmada: yt.hasSuffix("search_query=rock&roll=1"))
        let uber = Apps.url(app: "uber", busca: "Av. Paulista, 1000")?.url.absoluteString ?? ""
        T.lacuna("Apps.url: destino do Uber é codificado duas vezes («%2520») neste Foundation (macOS); não verificado no iOS", confirmada: uber.contains("%2520"), uber)
        T.lacuna("Apps.url: «instalar» (contém «insta») abre o Instagram — casamento por substring", confirmada: Apps.url(app: "instalar", busca: nil)?.nome == "Instagram")
        T.lacuna("Apps.url: «ajustes» abre os ajustes do PocketSelf, não os Ajustes do iOS", confirmada: Apps.url(app: "ajustes do iPhone", busca: nil)?.url.absoluteString == "app-settings:")
        T.lacuna("Apps.url: «google maps» abre o Mapas da Apple", confirmada: Apps.url(app: "google maps", busca: nil)?.nome == "Mapas")
        T.lacuna("Apps.url: busca só com espaços pesquisa «%20%20» em vez de abrir sem busca", confirmada: Apps.url(app: "safari", busca: "   ")?.url.absoluteString.contains("%20%20") == true)
        T.lacuna("Apps.url: ordem da lista decide empate («spotify musica» vira Spotify, não Música)", confirmada: Apps.url(app: "spotify musica", busca: nil)?.nome == "Spotify")
    }

    static func timer() {
        // Timer2.agendar usa notificações do sistema (não executável aqui); só a aritmética de exibição é verificável pelo texto.
        T.lacuna("timer: \"\\(Int(minutos))\" trunca frações — timer de 0,5 min diz «0 min» na criação e no aviso (Int(0.5) = \(Int(0.5)))", confirmada: fonte.contains("Timer de \\(Int(minutos)) min criado") && fonte.contains("Tempo esgotado (\\(Int(minutos)) min).") && Int(0.5) == 0)
        T.check(fonte.contains("max(5, minutos * 60)"), "timer: disparo mínimo de 5 segundos")
        T.check(fonte.contains("Sem permissão de notificações. O usuário pode liberar em Ajustes do iPhone › Notificações › PocketSelf."), "timer sem permissão: orienta o caminho em Ajustes")
    }

    static func perguntaExterna() {
        let d = UserDefaults.standard
        d.removeObject(forKey: PerguntaExterna.chave); d.removeObject(forKey: PerguntaExterna.chaveAoVivo)
        T.check(PerguntaExterna.retirar() == nil && PerguntaExterna.retirarAoVivo() == false, "PerguntaExterna: vazia no começo")
        PerguntaExterna.guardar("Que horas são?")
        T.check(PerguntaExterna.retirar() == "Que horas são?", "PerguntaExterna: guardar → retirar devolve o texto")
        T.check(PerguntaExterna.retirar() == nil, "PerguntaExterna: retirar consome (não repete a pergunta)")
        PerguntaExterna.pedirAoVivo()
        T.check(PerguntaExterna.retirarAoVivo() == true && PerguntaExterna.retirarAoVivo() == false, "PerguntaExterna: pedido de «ao vivo» é consumido uma vez")
        PerguntaExterna.guardar("a"); PerguntaExterna.guardar("b")
        T.check(PerguntaExterna.retirar() == "b", "PerguntaExterna: duas perguntas seguidas — a última vence (a primeira se perde)")
        T.lacuna("PerguntaExterna: só uma pergunta pendente por vez e sem expiração (pergunta antiga pode ser enviada dias depois)", confirmada: !(T.regex(#"enum PerguntaExterna \{(.*?)\n\}"#, em: fonte).first ?? "").contains("Date"))
    }

    static func contratosDosIntents() {
        let intents = T.regex(#"struct (\w+): AppIntent"#, em: fonte)
        T.check(intents == ["PerguntarAoNEO", "ConversarAoVivoNEO", "PesquisarComNEO", "CriarImagemNEO"], "4 App Intents declarados", "\(intents)")
        T.check(fonte.components(separatedBy: "static var openAppWhenRun = true").count - 1 == 4, "todos os App Intents abrem o app (openAppWhenRun)")
        let frases = T.regex(#"phrases: \[([^\]]*)\]"#, em: fonte)
        T.check(frases.count == 4, "4 conjuntos de frases de AppShortcut", "\(frases.count)")
        for f in frases {
            let cada = T.regex(#""([^"]*)""#, em: f)
            T.check(!cada.isEmpty && cada.allSatisfy { $0.contains("\\(.applicationName)") }, "frases de AppShortcut contêm \\(.applicationName) (exigência do sistema)", f)
        }
        T.check(fonte.contains("\"Pesquise na web: \\(assunto)\"") && fonte.contains("\"Crie uma imagem: \\(descricao)\""), "Intents de pesquisa e imagem reescrevem o parâmetro como pedido ao chat")
        T.check(fonte.contains("PerguntaExterna.guardar(pergunta)"), "Intent «Perguntar» guarda o texto cru (sem confirmação extra)")
        let ajustes = T.ler("app/PocketSelf/AjustesView.swift")
        T.check(ajustes.contains("«PocketSelf Nota»") && ajustes.contains("«PocketSelf Alarme»"), "Ajustes › Integrações explica a receita dos dois atalhos com os nomes exatos")
        T.lacuna("Intent «Perguntar»: qualquer app/atalho pode injetar texto no chat sem passar por confirmação (o texto é tratado como fala do dono)", confirmada: fonte.contains("PerguntaExterna.guardar(pergunta)"))
    }

    static func main() {
        atalhos()
        numeros()
        mapaDeApps()
        timer()
        perguntaExterna()
        contratosDosIntents()
        T.fim("integrações")
    }
}
