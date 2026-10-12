// PocketSelf — aba Ajustes: preferências por grupo. Tudo aplicado no aparelho, sem conta.
import AVFoundation
import SwiftUI

struct AjustesView: View {
    @Environment(Preferencias.self) private var prefs
    @Environment(PerfilAgente.self) private var perfil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Cabecalho()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Do seu jeito.").font(Tema.titulo).foregroundStyle(Tema.texto)
                        Text("Presença, preferências e controle.").font(.footnote).foregroundStyle(Tema.secundario).padding(.top, 4)
                        HStack(spacing: 12) {
                            Avatar(tamanho: 44)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(Identidade.tratamento.isEmpty ? perfil.nome : Identidade.tratamento).font(.callout.weight(.semibold)).foregroundStyle(Tema.texto)
                                Text("Tudo neste iPhone · sem conta").font(.caption).foregroundStyle(Tema.secundario)
                            }
                        }
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Tema.suave, in: RoundedRectangle(cornerRadius: Tema.raio))
                        .overlay(RoundedRectangle(cornerRadius: Tema.raio).stroke(Tema.separador, lineWidth: 1))
                        .padding(.top, 14)

                        RotuloDeGrupo(texto: "Experiência")
                        Cartao {
                            Linha("Meu agente", "Nome, tratamento e mascote", "face.smiling", valor: perfil.nome) { MeuAgenteView() }
                            Linha("Controle do iPhone", "Tarefas em qualquer app", "hand.tap") { ControleIphoneView() }
                            Linha("Aparência", "Tema, cores e tamanho de leitura", "paintpalette", valor: prefs.modoTema.nome) { AparenciaView() }
                            Linha("Voz e áudio", "Vozes instaladas e reprodução", "waveform") { VozView() }
                            Linha("Motor de IA e esforço", "Só o que roda de verdade", "cpu", valor: Motor.catalogo.first { $0.id == prefs.motorId }?.esforco ?? "") { MotorView() }
                            Linha("PocketSelf Decide (Sistema 1)", "Decisões em milissegundos, calibradas", "bolt") { DecisorView() }
                            Linha("Integrações", "Atalhos, Notas, alarmes, música, contatos", "square.stack.3d.up") { IntegracoesView() }
                        }
                        RotuloDeGrupo(texto: "Seus dados")
                        Cartao {
                            Linha("Memória", "O que o PocketSelf pode lembrar", "pin") { MemoriaView() }
                            Linha("Privacidade e dados", "Onde ficam, exportar e apagar", "checkmark.shield") { PrivacidadeView() }
                        }
                        RotuloDeGrupo(texto: "Aplicativo")
                        Cartao {
                            Linha("Sobre o PocketSelf", "Versão, ícone e limites da conta", "info.circle") { SobreView() }
                        }
                    }
                    .padding(Tema.margem)
                }
            }
            .background(Tema.fundo)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

/// Linha de navegação de um cartão de Ajustes.
struct Linha<Destino: View>: View {
    var titulo: String
    var detalhe: String
    var icone: String
    var valor: String = ""
    @ViewBuilder var destino: () -> Destino

    init(_ titulo: String, _ detalhe: String, _ icone: String, valor: String = "", @ViewBuilder destino: @escaping () -> Destino) {
        self.titulo = titulo; self.detalhe = detalhe; self.icone = icone; self.valor = valor; self.destino = destino
    }

    var body: some View {
        NavigationLink { destino() } label: {
            HStack(spacing: 11) {
                Image(systemName: icone).foregroundStyle(Tema.secundario).frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(titulo).font(.footnote).foregroundStyle(Tema.texto).multilineTextAlignment(.leading)
                    Text(detalhe).font(.caption2).foregroundStyle(Tema.secundario).multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                if !valor.isEmpty { Text(valor).font(.caption2).foregroundStyle(Tema.secundario) }
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Tema.secundario)
            }
            .padding(.horizontal, 14).padding(.vertical, 10).frame(minHeight: 50)
        }
        Rectangle().fill(Tema.separador).frame(height: 1).padding(.leading, 47)
    }
}

/// Moldura comum das telas internas de Ajustes.
struct TelaAjuste<Conteudo: View>: View {
    var titulo: String
    var subtitulo: String
    @ViewBuilder var conteudo: Conteudo
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(titulo).font(Tema.titulo).foregroundStyle(Tema.texto)
                Text(subtitulo).font(.footnote).foregroundStyle(Tema.secundario)
                conteudo
            }
            .padding(Tema.margem)
        }
        .background(Tema.fundo)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Aparência

struct AparenciaView: View {
    @Environment(Preferencias.self) private var prefs
    var body: some View {
        @Bindable var p = prefs
        TelaAjuste(titulo: "Aparência", subtitulo: "O tema muda cores; não muda tamanho de texto, nomes de funções nem a posição das abas.") {
            Picker("Tema", selection: $p.modoTema) { ForEach(ModoTema.allCases) { Text($0.nome).tag($0) } }
                .pickerStyle(.segmented)
            RotuloDeGrupo(texto: "Cor de destaque")
            HStack(spacing: 14) {
                ForEach(Destaque.allCases) { d in
                    Button { p.destaque = d } label: {
                        RoundedRectangle(cornerRadius: 8).fill(Tema.acao(d)).frame(width: 48, height: 48)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Tema.texto, lineWidth: p.destaque == d ? 3 : 0))
                            .overlay { if p.destaque == d { Image(systemName: "checkmark").foregroundStyle(.white).bold() } }
                    }
                    .accessibilityLabel(d.nome)
                }
            }
            Text("Vermelho de encerrar e avisos de erro não mudam com a cor de destaque.").font(.caption).foregroundStyle(Tema.secundario)
            RotuloDeGrupo(texto: "Prévia")
            Cartao {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 7) { Avatar(tamanho: 22); Text("PocketSelf").font(.caption.weight(.bold)).foregroundStyle(Tema.texto) }
                    Text("O texto cresce com o tamanho de leitura do iPhone (Ajustes › Acessibilidade › Tamanho do texto).").font(.callout).foregroundStyle(Tema.texto)
                    Button("Ação principal") {}.buttonStyle(BotaoPrimario(cor: Tema.acao(p.destaque)))
                    Button("Ação secundária") {}.buttonStyle(BotaoSecundario())
                }
                .padding(18)
            }
        }
    }
}

// MARK: - Voz

struct VozView: View {
    @Environment(Preferencias.self) private var prefs
    @Environment(Leitor.self) private var leitorExemplo
    private var vozes: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("pt") }.sorted { $0.quality.rawValue > $1.quality.rawValue }
    }
    private func qualidade(_ v: AVSpeechSynthesisVoice) -> String {
        switch v.quality { case .premium: return "Premium"; case .enhanced: return "Aprimorada"; default: return "Compacta" }
    }
    var body: some View {
        TelaAjuste(titulo: "Voz e áudio", subtitulo: "A fala é reconhecida e gerada neste iPhone. O PocketSelf usa a melhor voz em português instalada.") {
            RotuloDeGrupo(texto: "Voz do PocketSelf")
            Cartao {
                @Bindable var p = prefs
                Picker("Voz", selection: $p.vozNeural) {
                    ForEach(VozNeural.vozes, id: \.id) { Text("\($0.nome) · neural (experimental)").tag($0.id) }
                    Text("Voz do iPhone").tag("")
                }
                .pickerStyle(.inline).labelsHidden()
            }
            Text(VozNeural.instalada ? "Vozes neurais Kokoro (experimental): o sotaque em português ainda não é bom. Recomendado: voz do iPhone com a «Luciana (Premium)» baixada." : "Voz neural não instalada: copie a pasta Kokoro-82M-CoreML pelo cabo.").font(.caption).foregroundStyle(Tema.secundario)
            Button("Ouvir exemplo") { leitorExemplo.ler("Oi! Eu sou o PocketSelf, seu assistente pessoal. Posso ajudar com a agenda, a pesquisa e as suas ideias.", id: UUID()) }
                .buttonStyle(BotaoSecundario(altura: 40))
            RotuloDeGrupo(texto: "Vozes do sistema em português")
            Cartao {
                ForEach(vozes, id: \.identifier) { v in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(v.name).font(.callout).foregroundStyle(Tema.texto)
                            Text("\(v.language) · \(qualidade(v))").font(.caption).foregroundStyle(Tema.secundario)
                        }
                        Spacer()
                    }
                    .padding(14)
                    Rectangle().fill(Tema.separador).frame(height: 1)
                }
            }
            Aviso(texto: "Para uma voz mais natural, baixe a «Luciana (Premium)» em Ajustes do iPhone › Acessibilidade › Conteúdo Falado › Vozes › Português. O PocketSelf passa a usá-la sozinho.")
            RotuloDeGrupo(texto: "Reprodução")
            Cartao {
                @Bindable var p = prefs
                Toggle(isOn: $p.falarNoChat) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Ler respostas do chat em voz alta").font(.callout).foregroundStyle(Tema.texto)
                        Text("Desligado por padrão. A conversa ao vivo sempre fala.").font(.caption).foregroundStyle(Tema.secundario)
                    }
                }
                .padding(14)
            }
            Aviso(texto: "Neste aparelho o cancelamento de eco do iOS não está disponível: na conversa ao vivo, use fone de ouvido ou fale mais alto para interromper.")
        }
    }
}

// MARK: - Motor

struct MotorView: View {
    @Environment(Motor.self) private var motor
    @Environment(Preferencias.self) private var prefs
    var body: some View {
        TelaAjuste(titulo: "Motor de IA e esforço", subtitulo: "Esforço é o motor que responde. Nenhuma combinação é presumida: só aparece o que foi medido neste iPhone.") {
            ForEach(Motor.catalogo) { m in
                let instalado = motor.instalado(m)
                Button {
                    guard instalado, !motor.gerando, !motor.carregando else { return }
                    Task {
                        do { try await motor.carregar(m); prefs.motorId = m.id }
                        catch { motor.erro = error.localizedDescription }
                    }
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(m.esforco) · \(m.nome)").font(.callout.weight(.semibold)).foregroundStyle(instalado ? Tema.texto : Tema.secundario)
                            Text(m.descricao).font(.caption).foregroundStyle(Tema.secundario)
                            Text("\(m.requisito) · \(m.onde)").font(.caption2).foregroundStyle(Tema.secundario)
                            if m.pasta != nil || m.id == "apple" { Text(Benchmark.resumo(m.id) ?? "ainda não medido neste iPhone").font(.caption2).foregroundStyle(Tema.tinta(prefs.destaque)) }
                        }
                        Spacer()
                        if prefs.motorId == m.id { Image(systemName: "checkmark").foregroundStyle(Tema.tinta(prefs.destaque)).bold() }
                    }
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Tema.superficie, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(prefs.motorId == m.id ? Tema.acao(prefs.destaque) : Tema.separador, lineWidth: prefs.motorId == m.id ? 2 : 1))
                }
                .disabled(!instalado || motor.carregando || motor.gerando)
            }
            BotaoBenchmark()
            ServidorOpcional()
            if let c = motor.carregado {
                Aviso(texto: "Carregado agora: \(c.nome). Último turno: \(motor.tokens) fragmentos de texto, primeiro texto em \(Int(motor.primeiraPalavraMs)) ms, \(String(format: "%.1f", motor.tokPorSegundo)) fragmentos/s.")
            }
        }
    }
}

/// Mede, neste aparelho, os motores instalados (carga, primeira palavra, tok/s, memória).
struct BotaoBenchmark: View {
    @Environment(Motor.self) private var motor
    @State private var medindo = false
    @State private var andamento = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RotuloDeGrupo(texto: "Desempenho")
            Button(medindo ? "Medindo…" : "Medir neste iPhone") {
                medindo = true
                Task {
                    for m in Motor.catalogo where (m.pasta != nil || m.id == "apple") && motor.instalado(m) {
                        andamento = "Medindo \(m.nome)…"
                        _ = await Benchmark.medir(m, motor: motor)
                    }
                    andamento = "Pronto. Os números aparecem em cada motor."
                    medindo = false
                }
            }.buttonStyle(BotaoSecundario()).disabled(medindo || motor.gerando)
            if !andamento.isEmpty { Text(andamento).font(.footnote).foregroundStyle(Tema.secundario) }
            Text("Cada motor instalado gera o mesmo texto curto duas vezes. Leva alguns minutos e esquenta o aparelho; deixe-o ligado na tomada e no app.").font(.caption).foregroundStyle(Tema.secundario)
        }
    }
}

/// Servidor opcional compatível com a API da OpenAI (Ollama, vLLM…): modo «Máximo» e consulta a um modelo maior.
struct ServidorOpcional: View {
    @AppStorage("servidorURL") private var url = ""
    @AppStorage("servidorModelo") private var modeloServidor = ""
    @State private var resultado = ""
    @State private var testando = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RotuloDeGrupo(texto: "Servidor opcional (modo Máximo)")
            campo("Endereço, ex.: http://servidor.local:11434/v1", $url)
            campo("Modelo, ex.: qwen3-vl:30b-a3b-instruct", $modeloServidor)
            Button(testando ? "Testando…" : "Testar conexão") {
                testando = true; resultado = ""
                Task {
                    let ok = await Spark.disponivel()
                    resultado = ok ? "Servidor respondeu e anuncia o modelo «\(Spark.modelo)»." : "Sem resposta, ou o modelo «\(Spark.modelo)» não está na lista do servidor. Confira endereço, rede (e a permissão de Rede Local do iOS)."
                    testando = false
                }
            }.buttonStyle(BotaoSecundario()).disabled(testando)
            if !resultado.isEmpty { Text(resultado).font(.footnote).foregroundStyle(Tema.secundario) }
            Text("Opcional. O contexto da conversa vai para este servidor: use só equipamento seu.").font(.caption).foregroundStyle(Tema.secundario)
        }
    }
    private func campo(_ dica: String, _ valor: Binding<String>) -> some View {
        TextField(dica, text: valor)
            .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
            .padding(12).background(Tema.superficie, in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Tema.borda, lineWidth: 1))
    }
}

// MARK: - Decisor

struct DecisorView: View {
    @Environment(Motor.self) private var motor
    var body: some View {
        let d = motor.decisor
        TelaAjuste(titulo: "PocketSelf Decide", subtitulo: "Sistema 1 próprio: antes de acordar o modelo, decide a intenção do pedido em milissegundos, com probabilidade calibrada. Abaixo de \(Int(Decisor.limiar * 100))% ele não decide: o modelo recebe todas as ferramentas.") {
            Cartao {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Exemplos: \(d.exemplos.count) · " + d.porOrigem.map { "\($0.0) \($0.1)" }.joined(separator: " · ")).font(.footnote).foregroundStyle(Tema.texto)
                    Text(String(format: "Calibração (validação cruzada em 5 partes): ECE %.3f · acerto %.0f%% · temperatura %.1f", d.ece, d.acertoCV * 100, d.temperatura)).font(.footnote).foregroundStyle(Tema.secundario)
                    Text("Aprende com o uso: a ferramenta que o modelo chamou e as suas confirmações viram exemplos. Os modelos de linguagem continuam fixos.").font(.caption).foregroundStyle(Tema.secundario)
                }
                .padding(14)
            }
            RotuloDeGrupo(texto: "Últimas decisões")
            Cartao {
                if d.ultimas.isEmpty { Text("Nenhuma ainda.").font(.footnote).foregroundStyle(Tema.secundario).padding(14) }
                ForEach(Array(d.ultimas.enumerated()), id: \.offset) { _, u in
                    Text(u).font(.caption).foregroundStyle(Tema.texto).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 14).padding(.vertical, 8)
                    Rectangle().fill(Tema.separador).frame(height: 1)
                }
            }
            RotuloDeGrupo(texto: "Exemplos aprendidos com o uso")
            let aprendidos = d.exemplos.filter { $0.origem != "semente" }
            if aprendidos.isEmpty { Text("Ainda só as sementes.").font(.footnote).foregroundStyle(Tema.secundario) }
            ForEach(aprendidos.reversed(), id: \.texto) { e in
                Cartao {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(e.texto).font(.footnote).foregroundStyle(Tema.texto)
                            Text("\(e.classe.nome) · \(e.origem)").font(.caption2).foregroundStyle(Tema.secundario)
                        }
                        Spacer()
                        Button("Esquecer", role: .destructive) { motor.decisor.esquecer(e) }.font(.caption.weight(.semibold))
                    }
                    .padding(12)
                }
            }
        }
    }
}

// MARK: - Integrações

struct IntegracoesView: View {
    var body: some View {
        TelaAjuste(titulo: "Integrações", subtitulo: "O que o PocketSelf consegue acionar no iPhone. Agenda, lembretes, mensagens, e-mail e ligações só acontecem depois da sua confirmação na tela. Abrir apps, música, lanterna, brilho, timer e criar imagem são imediatos; o controle do iPhone para e pede você nas ações que não se desfazem.") {
            Cartao {
                VStack(alignment: .leading, spacing: 10) {
                    item("Agenda e Lembretes", "lê e grava (depois do seu toque)")
                    item("Contatos", "procura telefone e e-mail")
                    item("Mensagens, Mail e Telefone", "abre preenchido; o envio é seu")
                    item("Música", "toca o que está guardado neste iPhone")
                    item("Atalhos", "roda qualquer atalho seu pelo nome")
                    item("Notas e Relógio", "por dois atalhos que você cria uma vez")
                    item("Siri e Atalhos → PocketSelf", "ação «Perguntar ao PocketSelf» no app Atalhos")
                }
                .padding(14)
            }
            RotuloDeGrupo(texto: "Crie uma vez no app Atalhos")
            Aviso(texto: "«PocketSelf Nota»: ação Receber entrada (Texto) → Criar nota com Entrada do Atalho.\n«PocketSelf Alarme»: Receber entrada (Texto) → Dividir texto por « | » → Criar alarme com o primeiro item como horário e o segundo como nome.\nO nome do atalho tem de ser exatamente esse.")
            Aviso(texto: "Se este iPhone não tiver linha celular, SMS e ligação comum não completam; iMessage, e-mail e FaceTime precisam de internet.")
        }
    }
    private func item(_ t: String, _ d: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(t).font(.footnote.weight(.semibold)).foregroundStyle(Tema.texto)
            Text(d).font(.caption2).foregroundStyle(Tema.secundario)
        }
    }
}

// MARK: - Memória

struct MemoriaView: View {
    @Environment(Memoria.self) private var memoria
    @Environment(Preferencias.self) private var prefs
    @State private var novo = ""
    @State private var novaCategoria = MemoriaItem.Categoria.fato
    @State private var editando: MemoriaItem?
    @State private var textoEdicao = ""

    private static let data: DateFormatter = { let f = DateFormatter(); f.dateStyle = .short; return f }()

    var body: some View {
        @Bindable var m = memoria
        TelaAjuste(titulo: "Memória", subtitulo: "O que o PocketSelf sabe sobre você. Vale para todos os motores: os modelos não aprendem sozinhos; quem lembra é o PocketSelf, e só com a sua aprovação.") {
            Cartao {
                Toggle(isOn: $m.ligada) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Usar memória nas conversas").font(.callout).foregroundStyle(Tema.texto)
                        Text("Desligar não apaga os itens.").font(.caption).foregroundStyle(Tema.secundario)
                    }
                }
                .padding(14)
            }
            if !memoria.propostos.isEmpty {
                RotuloDeGrupo(texto: "Propostas do PocketSelf · \(memoria.propostos.count)")
                ForEach(memoria.propostos) { item in
                    Cartao {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.conteudo).font(.callout).foregroundStyle(Tema.texto)
                            Text("\(item.categoria.nome) · proposta em \(Self.data.string(from: item.criadoEm))").font(.caption).foregroundStyle(Tema.secundario)
                            HStack(spacing: 8) {
                                Button("Guardar") { memoria.aprovar(item.id) }.buttonStyle(BotaoPrimario(cor: Tema.acao(prefs.destaque), altura: 44))
                                Button("Não guardar") { memoria.excluir(item.id) }.buttonStyle(BotaoSecundario(altura: 44))
                            }
                        }
                        .padding(14)
                    }
                }
            }
            RotuloDeGrupo(texto: "Cadastrar")
            Cartao {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Ex.: Prefiro respostas curtas", text: $novo, axis: .vertical).font(.callout).foregroundStyle(Tema.texto)
                    Picker("Categoria", selection: $novaCategoria) { ForEach(MemoriaItem.Categoria.allCases, id: \.self) { Text($0.nome).tag($0) } }.pickerStyle(.segmented)
                    Button("Guardar") { memoria.cadastrar(novo, categoria: novaCategoria); novo = "" }
                        .buttonStyle(BotaoPrimario(cor: Tema.acao(prefs.destaque), altura: 44))
                        .disabled(novo.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(14)
            }
            RotuloDeGrupo(texto: "O que o PocketSelf lembra · \(memoria.ativos.count)")
            if memoria.ativos.isEmpty && memoria.itens.filter({ $0.status == .suspenso }).isEmpty {
                Text("Nada guardado ainda. O PocketSelf propõe durante as conversas; você aprova aqui ou no chat.").font(.footnote).foregroundStyle(Tema.secundario)
            }
            ForEach(memoria.itens.filter { $0.status != .proposto }) { item in
                Cartao {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.conteudo).font(.callout).foregroundStyle(item.status == .ativo ? Tema.texto : Tema.secundario)
                        Text("\(item.categoria.nome) · \(item.status == .ativo ? "ativa" : "suspensa") · revisada em \(Self.data.string(from: item.revisadoEm))" + (item.origemConversa != nil ? " · origem: conversa" : " · cadastro manual"))
                            .font(.caption).foregroundStyle(Tema.secundario)
                        HStack(spacing: 12) {
                            Button("Editar") { editando = item; textoEdicao = item.conteudo }
                            Button(item.status == .ativo ? "Suspender" : "Reativar") { item.status == .ativo ? memoria.suspender(item.id) : memoria.reativar(item.id) }
                            Button("Excluir", role: .destructive) { memoria.excluir(item.id) }
                        }
                        .font(.footnote.weight(.semibold)).frame(minHeight: 44)
                    }
                    .padding(14)
                }
            }
            Aviso(texto: "Senhas, documentos e dados sensíveis nunca entram aqui. Itens ativos são enviados ao motor como contexto; quando a memória muda, o motor refaz o prefixo (alguns segundos).")
        }
        .alert("Editar memória", isPresented: Binding(get: { editando != nil }, set: { if !$0 { editando = nil } })) {
            TextField("Conteúdo", text: $textoEdicao)
            Button("Salvar") { if let e = editando { memoria.editar(e.id, conteudo: textoEdicao, categoria: e.categoria) }; editando = nil }
            Button("Cancelar", role: .cancel) { editando = nil }
        }
    }
}

// MARK: - Privacidade

struct PrivacidadeView: View {
    @Environment(Historico.self) private var historico
    @Environment(Motor.self) private var motor
    @State private var confirmarApagar = false
    var body: some View {
        TelaAjuste(titulo: "Privacidade e dados", subtitulo: "O PocketSelf não tem conta nem servidor próprio. Conversas, memória e modelos ficam neste iPhone; só saem a pesquisa na web, o conteúdo que você manda para um servidor que configurar, e o agente de controle (tela e texto vão ao modelo que você apontar).") {
            Cartao {
                VStack(alignment: .leading, spacing: 10) {
                    item("Conversas", "neste iPhone, em Documents/conversas.json")
                    item("Fala e voz", "reconhecidas e geradas no aparelho")
                    item("Modelos de IA", "rodam no aparelho; só a pesquisa web e o servidor opcional usam rede")
                    item("Áudio bruto", "não é guardado")
                    item("Servidor opcional", "opcional: o contexto da conversa vai ao servidor que você configurar")
                }
                .padding(14)
            }
            ShareLink(item: historico.exportarTexto(), preview: SharePreview("Conversas do PocketSelf")) {
                Label("Exportar conversas (texto)", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(BotaoSecundario())
            Button { confirmarApagar = true } label: { Label("Apagar todas as conversas", systemImage: "trash") }
                .buttonStyle(BotaoPerigo())
                .confirmationDialog("Apagar todas as conversas deste iPhone?", isPresented: $confirmarApagar, titleVisibility: .visible) {
                    Button("Apagar tudo", role: .destructive) {
                        for c in historico.conversas { motor.esquecer(conversa: c.id) }
                        historico.apagarTudo()
                    }
                    Button("Cancelar", role: .cancel) {}
                } message: { Text("Ação permanente. Não há cópia em outro lugar.") }
        }
    }
    private func item(_ t: String, _ d: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(t).font(.callout.weight(.semibold)).foregroundStyle(Tema.texto)
            Text(d).font(.caption).foregroundStyle(Tema.secundario)
        }
    }
}

// MARK: - Sobre

struct SobreView: View {
    private var versao: String {
        let b = Bundle.main
        return "\(b.infoDictionary?["CFBundleShortVersionString"] ?? "?") (\(b.infoDictionary?["CFBundleVersion"] ?? "?"))"
    }
    var body: some View {
        TelaAjuste(titulo: "Sobre o app", subtitulo: "Assistente pessoal para iPhone, feito para rodar no aparelho.") {
            Cartao {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 14) {
                        MarcaView(altura: 64)
                        VStack(alignment: .leading, spacing: 4) {
                            Lettering(altura: 22)
                            Text("Versão \(versao)").font(.caption).foregroundStyle(Tema.secundario)
                        }
                    }
                }
                .padding(14)
            }
            Aviso(texto: "Instalado com conta de desenvolvedor gratuita: o app vence 7 dias após a instalação e precisa ser reinstalado pelo cabo do Mac. Os dados ficam.")
            Aviso(texto: "Motores: mlx-swift-lm (MIT). Voz: reconhecimento e síntese do iOS. Personagens, ícone e marca: arte original do projeto, sob a licença MIT.")
        }
    }
}
