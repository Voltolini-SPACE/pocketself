// PocketSelf — aba Chat: vazio (presença do personagem) e conversa ativa (leitura em foco).
import PhotosUI
import SwiftUI

struct ChatView: View {
    @Environment(PerfilAgente.self) private var perfil
    @Environment(Historico.self) private var historico
    @Environment(Memoria.self) private var memoria
    @Environment(Motor.self) private var motor
    @Environment(Preferencias.self) private var prefs
    @Environment(ConversaPorVoz.self) private var voz
    @Environment(Leitor.self) private var leitor

    @State private var texto = ""
    @State private var mostrarAoVivo = false
    @State private var mostrarReuniao = false
    @State private var mostrarMotor = false
    @State private var mostrarGravacao = false
    @State private var filaDePerguntas: [String] = []
    @State private var anexo: AnaliseDeImagem?
    @State private var anexoImagem: UIImage?
    @State private var analisando = false
    @State private var etapaAnexo = ""
    @State private var fotoItem: PhotosPickerItem?
    @State private var mostrarFotos = false
    @State private var mostrarCamera = false
    @FocusState private var focoNoCampo: Bool

    private var conversa: Conversa? { historico.atual }
    private var tinta: Color { Tema.tinta(prefs.destaque) }
    private var pendenciasDaConversa: [Pendencia] { motor.ferramentas.pendencias.filter { $0.conversa == conversa?.id } }
    private var propostasDaConversa: [MemoriaItem] { memoria.propostos.filter { $0.origemConversa == conversa?.id } }

    var body: some View {
        VStack(spacing: 0) {
            Cabecalho(acaoMais: { novaConversa() })
            if voz.emChamada && !mostrarAoVivo { faixaSessao }
            if motor.carregando { faixaMotor }
            if let erro = motor.erro { Aviso(texto: erro, cor: Tema.perigoTexto).padding(.horizontal, 16).padding(.top, 8) }
            if let c = conversa, !c.mensagens.isEmpty { lista(c) } else { vazio }
            compositor
        }
        .background(Tema.fundo)
        .sheet(isPresented: $mostrarAoVivo) { AoVivoView() }
        .fullScreenCover(isPresented: $mostrarReuniao) { ReuniaoView(arquivoDeTeste: Preferencias.argumento("reuniao-arquivo")) }
        .sheet(isPresented: $mostrarMotor) { MotorSheet() }
        .photosPicker(isPresented: $mostrarFotos, selection: $fotoItem, matching: .images)
        .onChange(of: fotoItem) { _, item in
            guard let item else { return }
            Task { if let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) { await anexar(img) }; fotoItem = nil }
        }
        .fullScreenCover(isPresented: $mostrarCamera) { Camera { img in Task { await anexar(img) } }.ignoresSafeArea() }
        .sheet(isPresented: $mostrarGravacao) { GravacaoSheet { t in enviar(t, porVoz: true) } }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            if PerguntaExterna.retirarAoVivo() { mostrarAoVivo = true }
            if Preferencias.argumento("reuniao-arquivo") != nil || CommandLine.arguments.contains("--reuniao") { Task { await garantirMotor(); mostrarReuniao = true } }
            if let p = PerguntaExterna.retirar() { historico.nova(); enviar(p) }
        }
        .task {
            // Aquece a voz neural em segundo plano (a 1ª síntese compila o modelo no Neural Engine, ~9 s).
            if !prefs.vozNeural.isEmpty, VozNeural.instalada { Task { _ = await VozNeural.shared.sintetizar("Olá.", voz: prefs.vozNeural) } }
            await garantirMotor()
            // Verificação pelo cabo: `--pergunta=...` ou `--perguntas=a|b|c` (uma por turno, na mesma conversa).
            if let p = Preferencias.argumento("perguntas") { filaDePerguntas = p.components(separatedBy: "|").filter { !$0.isEmpty } }
            else if let p = Preferencias.argumento("pergunta"), !p.isEmpty { filaDePerguntas = [p] }
            if let nome = Preferencias.argumento("imagem") {
                let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(nome)
                if let img = UIImage(contentsOfFile: url.path) { await anexar(img) }
            }
            if PerguntaExterna.retirarAoVivo() { mostrarAoVivo = true }
            if let p = PerguntaExterna.retirar() { filaDePerguntas.append(p) }
            if let t = Preferencias.argumento("ler") { leitor.vozNeural = { prefs.vozNeural }; leitor.ler(t, id: UUID()) }
            if !filaDePerguntas.isEmpty { historico.nova(); proximaPergunta() }
        }
    }

    private func proximaPergunta() {
        guard !filaDePerguntas.isEmpty, !motor.gerando else { return }
        enviar(filaDePerguntas.removeFirst())
    }

    // MARK: Vazio

    private var vazio: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(perfil.tratamento.isEmpty ? "OLÁ." : "OLÁ, \(perfil.tratamento.uppercased()).").font(.caption.weight(.bold)).kerning(2).foregroundStyle(tinta)
                Text("O que vamos\ntirar do papel?").font(Tema.titulo).foregroundStyle(Tema.texto)
                Text("Uma ideia, uma dúvida ou o seu próximo passo.").font(.footnote).foregroundStyle(Tema.secundario)
                Palco(altura: 100) {
                    HStack(spacing: 16) {
                        Sprite(altura: 76)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Pode falar.\nEu acompanho.").font(.callout.weight(.semibold)).foregroundStyle(Tema.texto)
                            Text("Texto ou voz. Você escolhe.").font(.caption).foregroundStyle(Tema.secundario)
                        }
                    }
                    .padding(.vertical, 12)
                }
                .padding(.top, 4)
                Button { mostrarAoVivo = true } label: { Label("Falar ao vivo", systemImage: "waveform") }
                    .buttonStyle(BotaoPrimario(cor: Tema.acao(prefs.destaque), altura: 50))
                RotuloDeGrupo(texto: "Experimente")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(Self.acoesRapidas) { a in atalho(a) }
                }
            }
            .padding(Tema.margem)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    struct AcaoRapida: Identifiable {
        let id: String, titulo: String, detalhe: String, icone: String, pedido: String
    }
    static let acoesRapidas: [AcaoRapida] = [
        .init(id: "reuniao", titulo: "Reunião", detalhe: "ouve, anota e resume", icone: "person.2.wave.2", pedido: ""),
        .init(id: "dia", titulo: "Organizar o dia", detalhe: "agenda e prioridades", icone: "calendar", pedido: "Veja minha agenda de hoje e me ajude a organizar o dia."),
        .init(id: "lembrete", titulo: "Criar lembrete", detalhe: "com a sua confirmação", icone: "bell", pedido: "Me lembre amanhã às 9h de "),
        .init(id: "web", titulo: "Pesquisar na web", detalhe: "com fontes", icone: "globe", pedido: "Pesquise na internet "),
        .init(id: "foto", titulo: "Ler uma foto", detalhe: "recibo, documento, placa", icone: "camera.viewfinder", pedido: "Vou tirar uma foto: leia o texto e me diga o que é importante."),
        .init(id: "mensagem", titulo: "Mandar mensagem", detalhe: "contato, e-mail, ligação", icone: "paperplane", pedido: "Mande uma mensagem para "),
        .init(id: "musica", titulo: "Tocar música", detalhe: "Apple Music ou Spotify", icone: "music.note", pedido: "Toque "),
        .init(id: "imagem", titulo: "Criar imagem", detalhe: "Image Playground", icone: "sparkles", pedido: "Crie uma imagem de "),
        .init(id: "controle", titulo: "Usar outro app", detalhe: "agente de controle", icone: "hand.tap", pedido: "No meu iPhone, abra o app "),
        .init(id: "nota", titulo: "Anotar uma ideia", detalhe: "no app Notas", icone: "note.text", pedido: "Crie uma nota com o título «Ideia» e o texto: "),
        .init(id: "timer", titulo: "Marcar um tempo", detalhe: "timer ou alarme", icone: "timer", pedido: "Ligue um timer de 10 minutos."),
    ]

    private func atalho(_ a: AcaoRapida) -> some View {
        Button {
            if a.id == "reuniao" { mostrarReuniao = true; return }
            texto = a.pedido
            focoNoCampo = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: a.icone).font(.body.weight(.semibold)).foregroundStyle(Color.white)
                    .frame(width: 34, height: 34).background(Tema.acao(prefs.destaque), in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 1) {
                    Text(a.titulo).font(.footnote.weight(.semibold)).foregroundStyle(Tema.texto).lineLimit(1).minimumScaleFactor(0.8)
                    Text(a.detalhe).font(.caption2).foregroundStyle(Tema.secundario).lineLimit(1).minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .padding(.horizontal, 10)
        }
        .buttonStyle(BotaoSecundario(altura: 52))
        .accessibilityLabel("\(a.titulo), \(a.detalhe)")
    }

    // MARK: Conversa

    private func lista(_ c: Conversa) -> some View {
        ScrollViewReader { leitorRolagem in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(c.mensagens) { m in
                        Bolha(mensagem: m)
                            .contextMenu { menuDaMensagem(m) }
                    }
                    if motor.gerando {
                        Bolha(mensagem: Mensagem(deNEO: true, texto: motor.saida, motor: motor.carregado?.nome), parcial: true, ferramenta: motor.ferramentas.ultimaChamada)
                    }
                    ForEach(pendenciasDaConversa) { p in CartaoDeAcao(pendencia: p) }
                    ForEach(propostasDaConversa) { m in CartaoDeMemoria(item: m) }
                    Color.clear.frame(height: 1).id("fim")
                }
                .padding(Tema.margem)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: motor.saida) { _, _ in if motor.gerando { leitorRolagem.scrollTo("fim", anchor: .bottom) } }
            .onChange(of: c.mensagens.count) { _, _ in withAnimation { leitorRolagem.scrollTo("fim", anchor: .bottom) } }
            .onChange(of: pendenciasDaConversa.count + propostasDaConversa.count) { _, _ in withAnimation { leitorRolagem.scrollTo("fim", anchor: .bottom) } }
            .onAppear { leitorRolagem.scrollTo("fim", anchor: .bottom) }
        }
    }

    @ViewBuilder
    private func menuDaMensagem(_ m: Mensagem) -> some View {
        Button("Copiar", systemImage: "doc.on.doc") { UIPasteboard.general.string = m.texto }
        if m.deNEO {
            if leitor.lendo == m.id {
                Button("Parar leitura", systemImage: "stop.fill") { leitor.parar() }
            } else {
                Button("Ler em voz alta", systemImage: "speaker.wave.2") { leitor.ler(m.texto, id: m.id) }
            }
        } else {
            Button("Guardar na memória", systemImage: "pin") {
                memoria.propor(m.texto, categoria: .fato, conversa: conversa?.id, trecho: m.texto)
            }
        }
    }

    // MARK: Compositor

    private var compositor: some View {
        VStack(spacing: 6) {
            Rectangle().fill(Tema.separador).frame(height: 1)
            if analisando || anexo != nil { chipDeAnexo }
            HStack(alignment: .bottom, spacing: 6) {
                Menu {
                    Button("Tirar foto", systemImage: "camera") { mostrarCamera = true }
                    Button("Escolher foto", systemImage: "photo") { mostrarFotos = true }
                } label: {
                    Image(systemName: "plus").font(.body.weight(.medium)).foregroundStyle(Tema.texto).frame(width: 36, height: 36)
                }
                .padding(.leading, 6).padding(.bottom, 4)
                .accessibilityLabel("Anexar foto")
                TextField("Pergunte a \(perfil.nome)", text: $texto, axis: .vertical)
                    .lineLimit(1...6)
                    .font(.callout)
                    .foregroundStyle(Tema.texto)
                    .focused($focoNoCampo)
                    .padding(.leading, 14)
                    .padding(.vertical, 10)
                Button { mostrarGravacao = true } label: {
                    Image(systemName: "mic").font(.body.weight(.medium)).foregroundStyle(Tema.texto).frame(width: 36, height: 36)
                }
                .disabled(voz.emChamada || motor.gerando)
                .accessibilityLabel("Gravar mensagem de áudio")
                if motor.gerando {
                    Button { motor.parar() } label: {
                        Image(systemName: "stop.fill").font(.caption.weight(.bold)).foregroundStyle(Tema.fundo)
                            .frame(width: 32, height: 32).background(Tema.texto, in: Circle())
                    }
                    .padding(.trailing, 6).padding(.bottom, 4)
                    .accessibilityLabel("Parar resposta")
                } else {
                    Button { enviar(texto) } label: {
                        Image(systemName: "arrow.up").font(.body.weight(.bold)).foregroundStyle(podeEnviar ? Tema.fundo : Tema.superficie)
                            .frame(width: 32, height: 32)
                            .background(podeEnviar ? Tema.texto : Tema.borda, in: Circle())
                    }
                    .disabled(!podeEnviar)
                    .padding(.trailing, 6).padding(.bottom, 4)
                    .accessibilityLabel("Enviar mensagem")
                }
            }
            .background(Tema.fundo, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Tema.borda, lineWidth: 1))
            .padding(.horizontal, 12)
            .padding(.top, 8)
            HStack {
                chip(motor.carregado?.nome ?? "Motor", "cpu") { mostrarMotor = true }
                Spacer()
                chip(motor.carregado?.esforco ?? "—", "chart.bar") { mostrarMotor = true }
                Spacer()
                chip("Ao vivo", "waveform", destaque: true) { mostrarAoVivo = true }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        }
        .background(Tema.superficie)
    }

    private func chip(_ titulo: String, _ icone: String, destaque: Bool = false, acao: @escaping () -> Void) -> some View {
        Button(action: acao) {
            Label(titulo, systemImage: icone)
                .font(.caption2.weight(destaque ? .bold : .regular))
                .foregroundStyle(destaque ? tinta : Tema.secundario)
                .frame(minHeight: 36)
        }
    }

    private var podeEnviar: Bool {
        (!texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || anexo != nil) && !motor.carregando && !analisando
    }

    private var chipDeAnexo: some View {
        HStack(spacing: 8) {
            if let img = anexoImagem {
                Image(uiImage: img).resizable().scaledToFill().frame(width: 36, height: 36).clipShape(RoundedRectangle(cornerRadius: 6))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(analisando ? (etapaAnexo.isEmpty ? "Lendo a imagem no iPhone…" : etapaAnexo) : "Foto anexada").font(.caption.weight(.semibold)).foregroundStyle(Tema.texto)
                if let a = anexo {
                    Text(a.descricao.map { String($0.prefix(70)) + "…" } ?? (a.texto.isEmpty ? (a.rotulos.first.map { "parece: \($0)" } ?? "sem texto legível") : "\(a.texto.split(separator: "\n").count) linhas de texto lidas"))
                        .font(.caption2).foregroundStyle(Tema.secundario)
                }
            }
            Spacer()
            Button { anexo = nil; anexoImagem = nil } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Tema.secundario) }
                .frame(width: 44, height: 44).accessibilityLabel("Remover foto")
        }
        .padding(.horizontal, 12).padding(.top, 6)
    }

    private func anexar(_ img: UIImage) async {
        analisando = true
        anexoImagem = img
        var a = await Visao.analisar(img)
        anexo = a
        etapaAnexo = "Gemma 4 olhando a foto…"
        // Modelos locais não cabem juntos (9B + Gemma = sinal 9 no 17): libera o texto, descreve, e o próximo envio recarrega.
        if motor.carregado != nil, motor.carregado?.id != "spark", !motor.carregando { motor.parar(); motor.descarregar() }
        a.descricao = await VisaoGemma.descrever(img)
        anexo = a
        etapaAnexo = ""
        analisando = false
    }

    // MARK: Faixas

    private var faixaMotor: some View {
        HStack(spacing: 8) {
            ProgressView().tint(tinta)
            Text(motor.estado).font(.footnote).foregroundStyle(Tema.secundario)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(Tema.suave)
    }

    private var faixaSessao: some View {
        HStack {
            Image(systemName: "waveform")
            Button { mostrarAoVivo = true } label: {
                Text("Sessão ao vivo ativa · \(voz.rotuloEstado)").font(.footnote.weight(.semibold)).frame(maxWidth: .infinity, alignment: .leading)
            }
            Button("Encerrar") { voz.encerrarChamada() }.font(.footnote.weight(.bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16).frame(minHeight: 44)
        .background(Tema.acao(prefs.destaque))
    }

    // MARK: Ações

    private func novaConversa() {
        motor.ferramentas.limparResolvidas(da: conversa?.id)
        historico.nova()
        focoNoCampo = false
    }

    private func garantirMotor() async {
        guard motor.carregado == nil, !motor.carregando else { return }
        let escolhido = motor.info(prefs.motorId) ?? Motor.catalogo[1]
        // O servidor opcional não entra como «instalado» por padrão: sem modelo local, orientar em vez de falhar na rede.
        let alvo = motor.instalado(escolhido) ? escolhido : Motor.catalogo.first { $0.pasta != nil && motor.instalado($0) }
        guard let alvo else {
            motor.erro = "Ainda não há modelo de IA neste iPhone. O app abre, mas as respostas precisam de um: copie um pelo cabo (docs/MODELOS.md) ou, em Ajustes, aponte um servidor."
            return
        }
        try? await motor.carregar(alvo)
    }

    private func enviar(_ bruto: String, porVoz: Bool = false) {
        var t = bruto.trimmingCharacters(in: .whitespacesAndNewlines)
        let foto = anexo
        if t.isEmpty, foto != nil { t = "O que tem nesta imagem? Resuma o que for importante." }
        guard !t.isEmpty, !motor.gerando else { return }
        texto = ""
        anexo = nil
        anexoImagem = nil
        leitor.parar()
        let c = historico.atualOuNova()
        historico.anexar(Mensagem(deNEO: false, texto: (foto != nil ? "📷 " : "") + t, porVoz: porVoz), em: c.id)
        if let foto { t = foto.contexto + "\n\nPedido do usuário: " + t }
        guard let atual = historico.conversa(c.id) else { return }
        Task {
            await garantirMotor()
            guard motor.carregado != nil else { return }
            let nome = motor.carregado?.nome
            let modoVoz = Preferencias.argumento("modo") == "voz"   // teste pelo cabo: simula o ao vivo
            motor.responder(t, conversa: atual, maxTokens: modoVoz ? 300 : 1024, semFerramentas: modoVoz) { saida, interrompida in
                let resposta = saida.trimmingCharacters(in: .whitespacesAndNewlines)
                let ultimoTeste = ValidacaoResposta.ativa && filaDePerguntas.isEmpty
                defer {
                    if ultimoTeste {
                        let recarregado = Historico(arquivo: ValidacaoResposta.arquivoIsolado("conversas"))
                        let quantidade = recarregado.conversa(atual.id)?.mensagens.count ?? 0
                        print("[neo-validacao-fim] mensagens_recarregadas=\(quantidade)")
                    }
                }
                if ValidacaoResposta.ativa {
                    do {
                        let linha = try ValidacaoResposta.linha(pergunta: t, resposta: resposta, interrompida: interrompida,
                            erro: motor.erro, motor: nome, ferramenta: motor.ferramentas.ultimaChamada, primeiraMs: motor.primeiraPalavraMs)
                        print("[neo-validacao] \(linha)")
                    } catch { print("[neo-validacao-erro] \(error.localizedDescription)") }
                }
                guard !resposta.isEmpty || interrompida else { proximaPergunta(); return }
                let m = Mensagem(deNEO: true, texto: resposta.isEmpty ? "(resposta interrompida antes da primeira palavra)" : resposta,
                                 motor: nome, interrompida: interrompida, porVoz: porVoz, decisao: motor.ultimaDecisao?.resumo)
                var mi = m; mi.imagem = motor.ferramentas.imagemGerada; motor.ferramentas.imagemGerada = nil
                let mFinal = mi
                historico.anexar(mFinal, em: atual.id)
                if prefs.falarNoChat, !resposta.isEmpty, !voz.emChamada { leitor.ler(resposta, id: mFinal.id) }
                proximaPergunta()
            }
        }
    }
}

/// Mensagem: a do usuário à direita em superfície suave; a do PocketSelf ocupa a largura, com avatar e motor.
struct Bolha: View {
    var mensagem: Mensagem
    var parcial = false
    var ferramenta = ""

    private static let hora: DateFormatter = { let f = DateFormatter(); f.timeStyle = .short; return f }()

    var body: some View {
        if mensagem.nota == true {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal").foregroundStyle(Tema.secundario)
                Text(mensagem.texto).font(.footnote).foregroundStyle(Tema.secundario)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if mensagem.deNEO {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Avatar(tamanho: 20)
                    Text("PocketSelf").font(.caption2.weight(.bold)).foregroundStyle(Tema.texto)
                    if let motor = mensagem.motor {
                        Text(motor).font(.caption2).foregroundStyle(Tema.secundario)
                    }
                    if mensagem.porVoz { Image(systemName: "waveform").font(.caption2).foregroundStyle(Tema.secundario) }
                }
                if mensagem.texto.isEmpty && parcial {
                    Text(ferramenta.isEmpty ? "Preparando resposta…" : "Consultando \(ferramenta.replacingOccurrences(of: "_", with: " "))…")
                        .font(.callout).foregroundStyle(Tema.secundario)
                } else {
                    Text(mensagem.texto).font(.callout).foregroundStyle(Tema.texto).textSelection(.enabled)
                    if let img = mensagem.imagem, let ui = UIImage(contentsOfFile: GeradorDeImagem.url(img).path) {
                        Image(uiImage: ui).resizable().scaledToFit().frame(maxWidth: 280).clipShape(RoundedRectangle(cornerRadius: 12))
                            .contextMenu { ShareLink(item: Image(uiImage: ui), preview: SharePreview("Imagem do PocketSelf", image: Image(uiImage: ui))) }
                    }
                }
                if mensagem.interrompida {
                    Text("Interrompida").font(.caption2.weight(.semibold)).foregroundStyle(Tema.secundario)
                }
                if !parcial {
                    Text(Self.hora.string(from: mensagem.hora) + (mensagem.decisao.map { " · decisão: \($0)" } ?? "")).font(.caption2).foregroundStyle(Tema.secundario)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 5) {
                Text(mensagem.texto).font(.callout).foregroundStyle(Tema.texto).textSelection(.enabled)
                HStack(spacing: 6) {
                    if mensagem.porVoz { Image(systemName: "waveform").font(.caption2) }
                    Text(Self.hora.string(from: mensagem.hora)).font(.caption2)
                }
                .foregroundStyle(Tema.secundario)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Tema.suave, in: RoundedRectangle(cornerRadius: 18))
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.leading, 56)
        }
    }
}

/// Card de ferramenta: prévia → confirmação → comprovante. Sucesso só com retorno do sistema.
struct CartaoDeAcao: View {
    var pendencia: Pendencia
    @Environment(Motor.self) private var motor
    @Environment(Historico.self) private var historico
    @Environment(Preferencias.self) private var prefs

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: pendencia.tipo.icone).foregroundStyle(Tema.tinta(prefs.destaque))
                Text(pendencia.tipo.nome).font(.caption.weight(.bold)).foregroundStyle(Tema.texto)
                Spacer()
                Text(rotuloEstado).font(.caption2.weight(.semibold)).foregroundStyle(corEstado)
            }
            Text(pendencia.titulo).font(.callout.weight(.semibold)).foregroundStyle(Tema.texto)
            Text(pendencia.detalhe + (pendencia.local.map { " · \($0)" } ?? "")).font(.footnote).foregroundStyle(Tema.secundario)
            switch pendencia.estado {
            case .pendente:
                Text(pendencia.tipo.destino).font(.caption).foregroundStyle(Tema.secundario)
                HStack(spacing: 8) {
                    Button("Confirmar") {
                        Task {
                            await motor.ferramentas.confirmar(pendencia.id)
                            if let cid = pendencia.conversa, let ultima = historico.conversa(cid)?.mensagens.last(where: { !$0.deNEO })?.texto {
                                motor.decisor.aprender(ultima, classe: Intencao.daTipo(pendencia.tipo), origem: "confirmacao")
                            }
                            if let p = motor.ferramentas.pendencias.first(where: { $0.id == pendencia.id }), case .feita(let c) = p.estado, let cid = p.conversa {
                                historico.anexar(Mensagem(deNEO: true, texto: "\(c): \(p.titulo), \(p.detalhe).", nota: true), em: cid)
                            }
                        }
                    }
                    .buttonStyle(BotaoPrimario(cor: Tema.acao(prefs.destaque), altura: 44))
                    Button("Cancelar") { motor.ferramentas.cancelar(pendencia.id) }.buttonStyle(BotaoSecundario(altura: 44))
                }
            case .feita(let c): Text(c).font(.caption).foregroundStyle(Tema.secundario)
            case .falhou(let e): Text(e).font(.caption).foregroundStyle(Tema.perigoTexto)
            case .cancelada: EmptyView()
            }
        }
        .padding(14)
        .background(Tema.superficie, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(pendencia.estado == .pendente ? Tema.acao(prefs.destaque) : Tema.separador, lineWidth: pendencia.estado == .pendente ? 2 : 1))
    }

    private var rotuloEstado: String {
        switch pendencia.estado { case .pendente: return "aguardando você"; case .feita: return "feito"; case .falhou: return "falhou"; case .cancelada: return "cancelado" }
    }
    private var corEstado: Color {
        switch pendencia.estado { case .falhou: return Tema.perigoTexto; case .feita: return Tema.tinta(.menta); default: return Tema.secundario }
    }
}

/// Proposta de memória: texto exato + Guardar / Editar depois / Não guardar.
struct CartaoDeMemoria: View {
    var item: MemoriaItem
    @Environment(Memoria.self) private var memoria
    @Environment(Preferencias.self) private var prefs

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "pin").foregroundStyle(Tema.tinta(prefs.destaque))
                Text("Guardar na memória?").font(.caption.weight(.bold)).foregroundStyle(Tema.texto)
                Spacer()
                Text(item.categoria.nome).font(.caption2).foregroundStyle(Tema.secundario)
            }
            Text(item.conteudo).font(.callout).foregroundStyle(Tema.texto)
            Text("Vale para todos os motores. Você revisa e apaga em Ajustes › Memória.").font(.caption).foregroundStyle(Tema.secundario)
            HStack(spacing: 8) {
                Button("Guardar") { memoria.aprovar(item.id) }.buttonStyle(BotaoPrimario(cor: Tema.acao(prefs.destaque), altura: 44))
                Button("Não guardar") { memoria.excluir(item.id) }.buttonStyle(BotaoSecundario(altura: 44))
            }
        }
        .padding(14)
        .background(Tema.superficie, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Tema.acao(prefs.destaque), lineWidth: 2))
    }
}

/// Folha de motor/esforço: catálogo real, com indisponibilidade explicada.
struct MotorSheet: View {
    @Environment(Motor.self) private var motor
    @Environment(Preferencias.self) private var prefs
    @Environment(\.dismiss) private var fechar

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("A inteligência certa para a tarefa.").font(.title2.weight(.bold)).foregroundStyle(Tema.texto)
                    Text("Esforço é o motor que responde. Os três primeiros rodam neste iPhone; só um fica na memória por vez, e a troca leva alguns segundos. Histórico e memória são do PocketSelf: trocar de motor não perde nada.")
                        .font(.footnote).foregroundStyle(Tema.secundario)
                    ForEach(Motor.catalogo) { m in opcao(m) }
                    Aviso(texto: "As velocidades mostradas foram medidas neste iPhone (Ajustes › Motor de IA › Medir neste iPhone). O motor da conversa ao vivo é o mesmo do chat.")
                }
                .padding(Tema.margem)
            }
            .background(Tema.fundo)
            .navigationTitle("Motor e esforço")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fechar") { fechar() } } }
        }
    }

    private func opcao(_ m: MotorInfo) -> some View {
        let instalado = motor.instalado(m)
        let ativo = motor.carregado?.id == m.id
        return Button {
            guard instalado, !motor.gerando, !motor.carregando else { return }
            Task {
                do { try await motor.carregar(m); prefs.motorId = m.id }
                catch { motor.erro = error.localizedDescription }
            }
            fechar()
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: m.pasta == nil ? "cpu" : "cpu.fill").foregroundStyle(instalado ? Tema.tinta(prefs.destaque) : Tema.secundario).padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(m.esforco) · \(m.nome)").font(.callout.weight(.semibold)).foregroundStyle(instalado ? Tema.texto : Tema.secundario)
                    Text(m.descricao).font(.caption).foregroundStyle(Tema.secundario)
                    Text("\(m.requisito) · \(Benchmark.resumo(m.id) ?? m.onde)").font(.caption2).foregroundStyle(Tema.secundario)
                    if !instalado {
                        Text(m.id == "apple" ? (AppleIA.indisponibilidade ?? "") : (m.pasta == nil ? "Indisponível nesta versão" : "Modelo não copiado para este iPhone")).font(.caption2.weight(.semibold)).foregroundStyle(Tema.perigoTexto)
                    }
                }
                Spacer()
                if ativo { Image(systemName: "checkmark").foregroundStyle(Tema.tinta(prefs.destaque)).font(.body.weight(.bold)) }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tema.superficie, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(ativo ? Tema.acao(prefs.destaque) : Tema.separador, lineWidth: ativo ? 2 : 1))
        }
        .disabled(!instalado || motor.carregando || motor.gerando)
    }
}
