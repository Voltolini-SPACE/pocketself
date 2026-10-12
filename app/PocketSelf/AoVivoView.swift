// PocketSelf — «Falar ao vivo»: preparação com microfone desligado → sessão vinculada à conversa atual.
import SwiftUI

struct AoVivoView: View {
    @Environment(\.dismiss) private var fechar
    @Environment(Historico.self) private var historico
    @Environment(Motor.self) private var motor
    @Environment(Preferencias.self) private var prefs
    @Environment(ConversaPorVoz.self) private var voz
    @Environment(\.accessibilityReduceMotion) private var reduzMovimento

    private var tinta: Color { Tema.tinta(prefs.destaque) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button { fechar() } label: { Image(systemName: voz.emChamada ? "chevron.down" : "chevron.left") }
                    .buttonStyle(BotaoIcone())
                    .accessibilityLabel(voz.emChamada ? "Minimizar sessão" : "Voltar")
                VStack(alignment: .leading, spacing: 3) {
                    Text("Conversa ao vivo").font(.callout.weight(.semibold)).foregroundStyle(Tema.texto)
                    Text("PocketSelf · assistente pessoal").font(.caption).foregroundStyle(Tema.secundario)
                }
                Spacer()
            }
            .padding(.horizontal, 18).padding(.vertical, 10)
            .background(Tema.superficie)
            Rectangle().fill(Tema.separador).frame(height: 1)

            if voz.emChamada { sessao } else { preparacao }
        }
        .background(Tema.fundo)
        .presentationDragIndicator(.visible)
        .onAppear(perform: ligar)
    }

    // MARK: Preparação (captura desligada)

    private var preparacao: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("VOZ, SEM COMPLICAÇÃO").font(.caption.weight(.bold)).kerning(2).foregroundStyle(tinta).padding(.top, 8)
                Text("Fale naturalmente.\nContinue de onde parou.").font(Tema.titulo).foregroundStyle(Tema.texto).multilineTextAlignment(.center)
                Palco(altura: 188) { Sprite(altura: 150).padding(.vertical, 18) }
                Text(voz.rotuloEstado).font(.title3.weight(.bold)).foregroundStyle(Tema.texto)
                Text(voz.subtituloEstado).font(.callout).foregroundStyle(Tema.secundario)
                Aviso(texto: "Tudo acontece neste iPhone: a fala é reconhecida, a resposta é gerada pelo \(motor.carregado?.nome ?? "motor local") e a voz é sintetizada aqui. Nada vai à internet. Com a tela bloqueada, a sessão pausa.")
                if !voz.aviso.isEmpty { Aviso(texto: voz.aviso, cor: Tema.perigoTexto) }
                if let erro = motor.erro { Aviso(texto: erro, cor: Tema.perigoTexto) }
                Button {
                    voz.iniciarChamada()
                } label: {
                    if voz.preparando { ProgressView().tint(.white) } else { Label("Iniciar conversa", systemImage: "waveform") }
                }
                .buttonStyle(BotaoPrimario(cor: Tema.acao(prefs.destaque), altura: 56))
                .disabled(voz.preparando || motor.carregado == nil || motor.carregando)
                Button("Continuar escrevendo") { fechar() }.buttonStyle(BotaoSecundario())
                if motor.carregado == nil {
                    Text(motor.carregando ? motor.estado : "Nenhum motor carregado.").font(.caption).foregroundStyle(Tema.secundario)
                }
                Text("Mesma conversa · voz nos dois sentidos\nSem escuta em segundo plano.").font(.caption).foregroundStyle(Tema.secundario).multilineTextAlignment(.center)
            }
            .padding(Tema.margem)
        }
    }

    // MARK: Sessão

    private var sessao: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 12) {
                    Text("SESSÃO AO VIVO · \(voz.cronometro)").font(.caption.weight(.bold)).kerning(2).foregroundStyle(tinta).padding(.top, 8)
                    Text("Voz: \(motor.carregado?.nome ?? "—") · áudio: iPhone").font(.footnote).foregroundStyle(Tema.secundario)
                    Palco(altura: 188) {
                        Sprite(altura: 150).padding(.vertical, 18)
                            .scaleEffect(voz.estado == .falando && !reduzMovimento ? 1.03 : 1)
                            .animation(reduzMovimento ? nil : .easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: voz.estado == .falando)
                    }
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 1).fill(voz.silenciado ? Tema.secundario : tinta).frame(width: 8, height: 8)
                        Text(voz.rotuloEstado).font(.title3.weight(.bold)).foregroundStyle(Tema.texto)
                    }
                    Text(voz.subtituloEstado).font(.footnote).foregroundStyle(Tema.secundario).multilineTextAlignment(.center)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Transcrição").font(.caption).foregroundStyle(Tema.secundario)
                        if !voz.ouvido.isEmpty { Text("Você: \(voz.ouvido)").font(.callout).foregroundStyle(Tema.texto) }
                        if voz.estado == .pensando || voz.estado == .falando {
                            Text("PocketSelf: \(String(motor.saida.suffix(220)))").font(.callout).foregroundStyle(Tema.texto)
                        }
                        if voz.ouvido.isEmpty && voz.estado == .ouvindo { Text("…").font(.callout).foregroundStyle(Tema.secundario) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Tema.superficie, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Tema.separador, lineWidth: 1))
                    if !voz.aviso.isEmpty { Aviso(texto: voz.aviso) }
                    if voz.estado == .pensando || voz.estado == .falando {
                        Button { voz.pararRespostaPeloBotao() } label: { Label("Parar resposta", systemImage: "stop.fill") }
                            .buttonStyle(BotaoSecundario())
                    }
                }
                .padding(Tema.margem)
            }
            Rectangle().fill(Tema.separador).frame(height: 1)
            HStack(spacing: 10) {
                controle(voz.silenciado ? "Retomar" : "Silenciar", voz.silenciado ? "mic.fill" : "mic.slash.fill") { voz.alternarSilencio() }
                Button {
                    voz.encerrarChamada()
                } label: {
                    VStack(spacing: 8) { Image(systemName: "phone.down.fill"); Text("Encerrar").font(.caption) }
                        .frame(maxWidth: .infinity, minHeight: 64)
                }
                .buttonStyle(BotaoPerigo())
                controle("Minimizar", "bubble.left") { fechar() }
            }
            .padding(16)
            .background(Tema.superficie)
        }
    }

    private func controle(_ titulo: String, _ icone: String, acao: @escaping () -> Void) -> some View {
        Button(action: acao) {
            VStack(spacing: 8) { Image(systemName: icone); Text(titulo).font(.caption) }
                .frame(maxWidth: .infinity, minHeight: 64)
        }
        .buttonStyle(BotaoSecundario(altura: 64))
    }

    // MARK: Ligação com motor e histórico

    private func ligar() {
        voz.vozNeural = { prefs.vozNeural }
        voz.saidaDoMotor = { motor.saida }
        voz.motorGerando = { motor.gerando }
        voz.pararMotor = { motor.parar() }
        voz.enviar = { texto in
            let c = historico.atualOuNova()
            historico.anexar(Mensagem(deNEO: false, texto: texto, porVoz: true), em: c.id)
            guard let atual = historico.conversa(c.id) else { return }
            let nome = motor.carregado?.nome
            motor.responder(texto, conversa: atual, maxTokens: 300, semFerramentas: true) { saida, interrompida in
                let r = saida.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !r.isEmpty else { return }
                historico.anexar(Mensagem(deNEO: true, texto: r, motor: nome, interrompida: interrompida, porVoz: true), em: atual.id)
            }
        }
    }
}
