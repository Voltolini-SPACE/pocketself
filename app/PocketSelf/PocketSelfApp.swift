// PocketSelf — assistente pessoal para iPhone (código aberto, MIT).
// Três destinos fixos: Chat, Histórico e Ajustes. «Falar ao vivo» é uma sessão, não uma aba.
import SwiftUI

@main
struct PocketSelfApp: App {
    init() {
        // Roteiros de validação pelo cabo: impede o bloqueio automático da tela enquanto o app está aberto.
        if CommandLine.arguments.contains("--acordado") { UIApplication.shared.isIdleTimerDisabled = true }
        if CommandLine.arguments.contains("--teste-orquestra") { Task { await TesteOrquestra.rodar() } }
    }
    @State private var historico = Historico(arquivo: ValidacaoResposta.arquivoIsolado("conversas"))
    @State private var memoria = Memoria(arquivo: ValidacaoResposta.arquivoIsolado("memoria"))
    @State private var motor = Motor()
    @State private var prefs = Preferencias()
    @State private var rota = Rota()
    @State private var voz = ConversaPorVoz()
    @State private var leitor = Leitor()
    @State private var perfil = PerfilAgente()

    var body: some Scene {
        WindowGroup {
            Raiz()
                .environment(historico)
                .environment(memoria)
                .environment(motor)
                .environment(prefs)
                .environment(rota)
                .environment(voz)
                .environment(leitor)
                .environment(perfil)
                .preferredColorScheme(prefs.modoTema.esquema)
                .tint(Tema.tinta(prefs.destaque))
                .onAppear { motor.memoria = memoria; leitor.vozNeural = { prefs.vozNeural } }
                .task { await Benchmark.rodarPorArgumento(motor: motor) }
        }
    }
}

struct Raiz: View {
    @Environment(Rota.self) private var rota
    @Environment(ConversaPorVoz.self) private var voz
    @Environment(Leitor.self) private var leitor
    @Environment(PerfilAgente.self) private var perfil
    @Environment(\.scenePhase) private var fase

    var body: some View {
        @Bindable var r = rota
        TabView(selection: $r.aba) {
            ChatView()
                .tabItem { Label("Chat", systemImage: "bubble.left.and.text.bubble.right") }
                .tag(Navegacao.Aba.chat)
            AgendaView()
                .tabItem { Label("Agenda", systemImage: "calendar") }
                .tag(Navegacao.Aba.agenda)
            HistoricoView()
                .tabItem { Label("Histórico", systemImage: "clock.arrow.circlepath") }
                .tag(Navegacao.Aba.historico)
            AjustesView()
                .tabItem { Label("Ajustes", systemImage: "gearshape") }
                .tag(Navegacao.Aba.ajustes)
        }
        .fullScreenCover(isPresented: Binding(get: { !perfil.concluido }, set: { _ in })) { OnboardingView() }
        .dynamicTypeSize(.small ... .xxxLarge)   // respeita o tamanho de texto do usuário, com limites que mantêm o layout
        .onChange(of: fase) { _, nova in
            // Política inicial: sair do app ou bloquear a tela encerra a captura e a leitura (o iOS também para a GPU).
            if nova != .active {
                if voz.emChamada { voz.encerrarChamada() }
                leitor.parar()
            }
        }
    }
}
