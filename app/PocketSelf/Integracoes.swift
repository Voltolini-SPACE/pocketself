// PocketSelf — integrações com os apps do iPhone.
// • Atalhos (sentido PocketSelf → Atalhos): roda um atalho do dono (Notas, alarmes, Casa…) por shortcuts://, sempre com confirmação.
// • Atalhos (sentido Atalhos/Siri → PocketSelf): App Intent «Perguntar ao PocketSelf».
// • Contatos (leitura), mensagem, e-mail e ligação (o PocketSelf prepara; o envio é do dono, no app do sistema).
// • Música da biblioteca do aparelho (MediaPlayer).
import AppIntents
import Contacts
import Foundation
import MediaPlayer
import UIKit

enum Integracoes {
    /// Atalhos que o dono cria uma vez no app Atalhos (receita em Ajustes › Integrações).
    static let atalhoNota = "PocketSelf Nota"
    static let atalhoAlarme = "PocketSelf Alarme"

    static func urlAtalho(_ nome: String, texto: String?) -> URL? {
        var c = URLComponents(string: "shortcuts://x-callback-url/run-shortcut")!
        var q = [URLQueryItem(name: "name", value: nome)]
        if let texto { q += [URLQueryItem(name: "input", value: "text"), URLQueryItem(name: "text", value: texto)] }
        c.queryItems = q
        return c.url
    }

    static func numeroLimpo(_ s: String) -> String { s.filter { $0.isNumber || $0 == "+" } }

    // MARK: Contatos

    static func buscarContatos(_ nome: String) async -> String {
        let loja = CNContactStore()
        let ok: Bool
        if CNContactStore.authorizationStatus(for: .contacts) == .authorized { ok = true }
        else { ok = (try? await loja.requestAccess(for: .contacts)) ?? false }
        guard ok else { return "Sem acesso aos Contatos. O usuário pode liberar em Ajustes do iPhone › Privacidade › Contatos." }
        let chaves: [CNKeyDescriptor] = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey, CNContactEmailAddressesKey].map { $0 as CNKeyDescriptor }
        let achados = (try? loja.unifiedContacts(matching: CNContact.predicateForContacts(matchingName: nome), keysToFetch: chaves)) ?? []
        if achados.isEmpty { return "Nenhum contato encontrado com «\(nome)»." }
        return achados.prefix(5).map { c in
            let tel = c.phoneNumbers.prefix(2).map { $0.value.stringValue }.joined(separator: ", ")
            let mail = c.emailAddresses.first.map { String($0.value) } ?? ""
            return "- \(c.givenName) \(c.familyName)" + (tel.isEmpty ? "" : " · tel \(tel)") + (mail.isEmpty ? "" : " · e-mail \(mail)")
        }.joined(separator: "\n")
    }

    // MARK: Música

    @MainActor
    static func tocarMusica(_ busca: String) async -> String {
        let st = await withCheckedContinuation { c in MPMediaLibrary.requestAuthorization { c.resume(returning: $0) } }
        guard st == .authorized else { return "Sem acesso à biblioteca de música. O usuário pode liberar em Ajustes do iPhone › Privacidade › Mídia e Apple Music." }
        func consulta(_ prop: String) -> [MPMediaItem] {
            let q = MPMediaQuery.songs()
            q.addFilterPredicate(MPMediaPropertyPredicate(value: busca, forProperty: prop, comparisonType: .contains))
            return q.items ?? []
        }
        let itens = consulta(MPMediaItemPropertyTitle) + consulta(MPMediaItemPropertyArtist) + consulta(MPMediaItemPropertyAlbumTitle)
        guard let primeira = itens.first else {
            // Não está guardada no iPhone: abre a busca no Spotify (instalado), que toca pela internet do cabo.
            if let alvo = Apps.url(app: "spotify", busca: busca) {
                await UIApplication.shared.open(alvo.url)
                print("[neo-ferramenta] abriu=Spotify url=\(alvo.url.absoluteString.prefix(80))")
                return "Não estava guardada no iPhone; abri o Spotify buscando «\(busca)». Toque no primeiro resultado para começar."
            }
            return "Não achei «\(busca)» nas músicas guardadas neste iPhone."
        }
        let player = MPMusicPlayerController.systemMusicPlayer
        player.setQueue(with: MPMediaItemCollection(items: Array(itens.prefix(50))))
        player.play()
        return "Tocando «\(primeira.title ?? "?")» de \(primeira.artist ?? "?") no app Música."
    }

    static func pararMusica() -> String {
        MPMusicPlayerController.systemMusicPlayer.pause()
        return "Música pausada."
    }
}

// MARK: - Sentido Atalhos/Siri → PocketSelf

/// Pergunta deixada pelo Atalhos para o chat processar ao abrir.
enum PerguntaExterna {
    static let chave = "perguntaExterna"
    static let chaveAoVivo = "aoVivoExterno"
    static func pedirAoVivo() { UserDefaults.standard.set(true, forKey: chaveAoVivo) }
    static func retirarAoVivo() -> Bool {
        let b = UserDefaults.standard.bool(forKey: chaveAoVivo)
        UserDefaults.standard.removeObject(forKey: chaveAoVivo)
        return b
    }
    static func guardar(_ t: String) { UserDefaults.standard.set(t, forKey: chave) }
    static func retirar() -> String? {
        let t = UserDefaults.standard.string(forKey: chave)
        UserDefaults.standard.removeObject(forKey: chave)
        return t
    }
}

struct PerguntarAoNEO: AppIntent {
    static var title: LocalizedStringResource = "Perguntar ao PocketSelf"
    static var description = IntentDescription("Abre o PocketSelf e envia a pergunta para o assistente que roda no iPhone.")
    static var openAppWhenRun = true

    @Parameter(title: "Pergunta") var pergunta: String

    @MainActor
    func perform() async throws -> some IntentResult {
        PerguntaExterna.guardar(pergunta)
        return .result()
    }
}

struct ConversarAoVivoNEO: AppIntent {
    static var title: LocalizedStringResource = "Conversa ao vivo com o PocketSelf"
    static var description = IntentDescription("Abre o PocketSelf já em conversa por voz, ideal para o Botão de Ação.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        PerguntaExterna.pedirAoVivo()
        return .result()
    }
}

struct PesquisarComNEO: AppIntent {
    static var title: LocalizedStringResource = "Pesquisar na web com o PocketSelf"
    static var description = IntentDescription("O PocketSelf pesquisa na web e responde.")
    static var openAppWhenRun = true

    @Parameter(title: "Assunto") var assunto: String

    @MainActor
    func perform() async throws -> some IntentResult {
        PerguntaExterna.guardar("Pesquise na web: \(assunto)")
        return .result()
    }
}

struct CriarImagemNEO: AppIntent {
    static var title: LocalizedStringResource = "Criar imagem com o PocketSelf"
    static var description = IntentDescription("O PocketSelf cria uma imagem no iPhone a partir da descrição.")
    static var openAppWhenRun = true

    @Parameter(title: "Descrição") var descricao: String

    @MainActor
    func perform() async throws -> some IntentResult {
        PerguntaExterna.guardar("Crie uma imagem: \(descricao)")
        return .result()
    }
}

struct AtalhosDoNEO: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: PerguntarAoNEO(), phrases: ["Perguntar ao \(.applicationName)", "Falar com o \(.applicationName)"],
                    shortTitle: "Perguntar ao PocketSelf", systemImageName: "bubble.left")
        AppShortcut(intent: ConversarAoVivoNEO(), phrases: ["Conversa ao vivo no \(.applicationName)", "Abrir o \(.applicationName) por voz"],
                    shortTitle: "Conversa ao vivo", systemImageName: "waveform")
        AppShortcut(intent: PesquisarComNEO(), phrases: ["Pesquisar com o \(.applicationName)"],
                    shortTitle: "Pesquisar na web", systemImageName: "magnifyingglass")
        AppShortcut(intent: CriarImagemNEO(), phrases: ["Criar imagem com o \(.applicationName)"],
                    shortTitle: "Criar imagem", systemImageName: "photo")
    }
}

// MARK: - Abrir apps (com busca) e controles do aparelho

import AVFoundation

enum Apps {
    /// Apps conhecidos: nome falado → montagem da URL (com ou sem busca).
    static func url(app: String, busca: String?) -> (nome: String, url: URL)? {
        // «&», «=», «+», «#» e «;» têm sentido próprio na URL: codificar também.
        let permitidos = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&=+#;/?"))
        let q = (busca ?? "").addingPercentEncoding(withAllowedCharacters: permitidos) ?? ""
        let a = app.lowercased().folding(options: .diacriticInsensitive, locale: nil)
        let tem = !q.isEmpty
        let mapa: [(chaves: [String], nome: String, comBusca: String, semBusca: String)] = [
            (["spotify"], "Spotify", "spotify:search:\(q)", "spotify:"),
            (["youtube", "you tube"], "YouTube", "youtube://results?search_query=\(q)", "youtube://"),
            (["whatsapp", "zap"], "WhatsApp", "whatsapp://send?text=\(q)", "whatsapp://"),
            (["instagram", "insta"], "Instagram", "instagram://user?username=\(q)", "instagram://"),
            (["telegram"], "Telegram", "tg://msg?text=\(q)", "tg://"),
            (["uber"], "Uber", "uber://?action=setPickup&pickup=my_location&dropoff[formatted_address]=\(q)", "uber://"),
            (["mapas", "maps", "mapa"], "Mapas", "maps://?q=\(q)", "maps://"),
            (["ajustes", "configuracoes", "settings"], "Ajustes do PocketSelf", "app-settings:", "app-settings:"),
            (["safari", "navegador", "site"], "Safari", "https://www.google.com/search?q=\(q)", "https://www.google.com"),
            (["musica", "apple music"], "Música", "music://", "music://"),
            (["fotos"], "Fotos", "photos-redirect://", "photos-redirect://"),
            (["calendario"], "Calendário", "calshow://", "calshow://"),
            (["lembretes"], "Lembretes", "x-apple-reminderkit://", "x-apple-reminderkit://"),
            (["atalhos"], "Atalhos", "shortcuts://", "shortcuts://"),
        ]
        guard let m = mapa.first(where: { $0.chaves.contains { a.contains($0) } }), let u = URL(string: tem ? m.comBusca : m.semBusca) else { return nil }
        return (m.nome, u)
    }

    @MainActor
    static func lanterna(_ ligar: Bool, nivel: Float = 1) -> String {
        guard let d = AVCaptureDevice.default(for: .video), d.hasTorch else { return "Este aparelho não tem lanterna disponível." }
        do {
            try d.lockForConfiguration()
            if ligar { try d.setTorchModeOn(level: max(0.1, min(nivel, 1))) } else { d.torchMode = .off }
            d.unlockForConfiguration()
            return ligar ? "Lanterna ligada." : "Lanterna desligada."
        } catch { return "Não consegui mexer na lanterna: \(error.localizedDescription)" }
    }

    @MainActor
    static func brilho(_ porcentagem: Int) -> String {
        let v = CGFloat(max(0, min(porcentagem, 100))) / 100
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.brightness = v
        return "Brilho da tela em \(Int(v * 100))%."
    }
}

/// Timer simples dentro do PocketSelf: avisa com notificação local (precisa permitir notificações).
import UserNotifications
enum Timer2 {
    static func agendar(minutos: Double, rotulo: String) async -> String {
        let c = UNUserNotificationCenter.current()
        let ok = (try? await c.requestAuthorization(options: [.alert, .sound])) ?? false
        guard ok else { return "Sem permissão de notificações. O usuário pode liberar em Ajustes do iPhone › Notificações › PocketSelf." }
        let conteudo = UNMutableNotificationContent()
        conteudo.title = "⏱️ " + (rotulo.isEmpty ? "Timer do PocketSelf" : rotulo)
        conteudo.body = "Tempo esgotado (\(Int(minutos)) min)."
        conteudo.sound = .default
        let gatilho = UNTimeIntervalNotificationTrigger(timeInterval: max(5, minutos * 60), repeats: false)
        do {
            try await c.add(UNNotificationRequest(identifier: UUID().uuidString, content: conteudo, trigger: gatilho))
            let fim = Date().addingTimeInterval(minutos * 60)
            let f = DateFormatter(); f.timeStyle = .short
            return "Timer de \(Int(minutos)) min criado; toca às \(f.string(from: fim))."
        } catch { return "Não consegui criar o timer: \(error.localizedDescription)" }
    }
}
