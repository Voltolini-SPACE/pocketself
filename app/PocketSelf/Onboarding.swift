// PocketSelf — «monte o seu agente»: nome, tratamento e mascote. Primeira abertura e Ajustes › Meu agente.
import SwiftUI

/// Estado do agente escolhido pela pessoa. Os mesmos valores são lidos por `Identidade` em qualquer prompt.
@Observable
@MainActor
final class PerfilAgente {
    var nome: String { didSet { UserDefaults.standard.set(nome, forKey: Identidade.chaveNome) } }
    var tratamento: String { didSet { UserDefaults.standard.set(tratamento, forKey: Identidade.chaveTratamento) } }
    var mascote: Mascote { didSet { UserDefaults.standard.set(mascote.json(), forKey: Identidade.chaveMascote) } }
    var concluido: Bool { didSet { UserDefaults.standard.set(concluido, forKey: Identidade.chaveConcluido) } }

    init() {
        let d = UserDefaults.standard
        switch Preferencias.argumento("perfil") {
        case "novo":
            for k in [Identidade.chaveNome, Identidade.chaveTratamento, Identidade.chaveMascote, Identidade.chaveConcluido] { d.removeObject(forKey: k) }
        default:
            break
        }
        nome = d.string(forKey: Identidade.chaveNome) ?? "PocketSelf"
        tratamento = d.string(forKey: Identidade.chaveTratamento) ?? ""
        var m = Mascote.de(json: d.string(forKey: Identidade.chaveMascote)) ?? Mascote()
        // Teste/demonstração pelo cabo: `--mascote=especie,cor,acessorio,humor,objeto` (ex.: coruja,1,bruxo,feliz,livro).
        if let a = Preferencias.argumento("mascote") {
            let p = a.split(separator: ",").map(String.init)
            if p.count >= 5, let e = Especie(rawValue: p[0]), let c = Int(p[1]), let ac = Acessorio(rawValue: p[2]), let h = Humor(rawValue: p[3]), let o = Objeto(rawValue: p[4]) {
                m = Mascote(especie: e, cor: c, acessorio: ac, humor: h, objeto: o)
            }
        }
        mascote = m
        concluido = d.bool(forKey: Identidade.chaveConcluido)
    }

    var galeria: [Especie] { Especie.galeria }
}

// MARK: - Desenho do mascote

struct MascoteView: View {
    var mascote: Mascote
    var altura: CGFloat = 120
    /// Só a cabeça (avatar pequeno).
    var rosto = false

    var body: some View {
        let linhas = rosto ? Mascote.alturaRosto : Mascote.altura
        let lado = altura / CGFloat(linhas)
        let grade = mascote.grade()
        Canvas { ctx, _ in
            for (y, linha) in grade.prefix(linhas).enumerated() {
                for (x, ch) in linha.enumerated() {
                    guard let hex = mascote.hex(ch) else { continue }
                    let r = CGRect(x: CGFloat(x) * lado, y: CGFloat(y) * lado, width: lado + 0.4, height: lado + 0.4)
                    ctx.fill(Path(r), with: .color(Color(hex: hex)))
                }
            }
        }
        .frame(width: lado * CGFloat(Mascote.largura), height: altura)
        .accessibilityHidden(true)
    }
}

// MARK: - Montador

private struct Chip: View {
    var texto: String
    var ativo: Bool
    var tinta: Color
    var acao: () -> Void
    var body: some View {
        Button(action: acao) {
            Text(texto).font(.footnote.weight(.semibold))
                .foregroundStyle(ativo ? Color.white : Tema.texto)
                .padding(.horizontal, 12).frame(minHeight: 36)
                .background(ativo ? tinta : Tema.superficie, in: Capsule())
                .overlay(Capsule().stroke(ativo ? tinta : Tema.borda, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(ativo ? .isSelected : [])
    }
}

struct MontadorMascote: View {
    @Binding var mascote: Mascote
    var galeria: [Especie]
    var tinta: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Palco(altura: 190) { MascoteView(mascote: mascote, altura: 144).padding(.vertical, 20) }

            RotuloDeGrupo(texto: "Personagem")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(galeria, id: \.self) { e in
                        let atual = Mascote(especie: e, cor: mascote.cor, acessorio: .nenhum, humor: mascote.humor, objeto: .nenhum)
                        Button { mascote.especie = e } label: {
                            VStack(spacing: 4) {
                                MascoteView(mascote: atual, altura: 52, rosto: true).frame(width: 66, height: 52)
                                Text(e.nome).font(.caption2).foregroundStyle(Tema.texto)
                            }
                            .padding(8)
                            .background(Tema.superficie, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(mascote.especie == e ? tinta : Tema.separador, lineWidth: mascote.especie == e ? 2 : 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(e.nome)
                        .accessibilityAddTraits(mascote.especie == e ? .isSelected : [])
                    }
                }
                .padding(2)
            }

            RotuloDeGrupo(texto: "Cor")
            HStack(spacing: 10) {
                ForEach(Array(Paleta.corpos.enumerated()), id: \.offset) { i, c in
                    Button { mascote.cor = i } label: {
                        Circle().fill(Color(hex: c.corpo)).frame(width: 30, height: 30)
                            .overlay(Circle().stroke(mascote.corSegura == i ? tinta : Tema.borda, lineWidth: mascote.corSegura == i ? 3 : 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(c.nome)
                    .accessibilityAddTraits(mascote.corSegura == i ? .isSelected : [])
                }
            }

            RotuloDeGrupo(texto: "Acessório")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) { ForEach(Acessorio.allCases, id: \.self) { a in Chip(texto: a.nome, ativo: mascote.acessorio == a, tinta: tinta) { mascote.acessorio = a } } }
            }

            RotuloDeGrupo(texto: "Segurando")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) { ForEach(Objeto.allCases, id: \.self) { o in Chip(texto: o.nome, ativo: mascote.objeto == o, tinta: tinta) { mascote.objeto = o } } }
            }

            RotuloDeGrupo(texto: "Expressão")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) { ForEach(Humor.allCases, id: \.self) { h in Chip(texto: h.nome, ativo: mascote.humor == h, tinta: tinta) { mascote.humor = h } } }
            }

            Button {
                mascote = Mascote(especie: galeria.randomElement() ?? .gato, cor: Int.random(in: 0..<Paleta.corpos.count),
                                  acessorio: Acessorio.allCases.randomElement() ?? .nenhum, humor: Humor.allCases.randomElement() ?? .feliz,
                                  objeto: Objeto.allCases.randomElement() ?? .nenhum)
            } label: { Label("Surpreenda-me", systemImage: "dice") }
                .buttonStyle(BotaoSecundario())
                .padding(.top, 6)
        }
    }
}

// MARK: - Campos de nome

private struct CamposDeNome: View {
    @Bindable var perfil: PerfilAgente
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RotuloDeGrupo(texto: "Nome do agente")
            TextField("Ex.: Luma, Bento, Tico…", text: $perfil.nome)
                .textInputAutocapitalization(.words).submitLabel(.done)
                .padding(12).background(Tema.superficie, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Tema.borda, lineWidth: 1))
            RotuloDeGrupo(texto: "Como ele chama você")
            TextField("Seu nome ou apelido (opcional)", text: $perfil.tratamento)
                .textInputAutocapitalization(.words).submitLabel(.done)
                .padding(12).background(Tema.superficie, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Tema.borda, lineWidth: 1))
            Text("Fica só neste iPhone. O agente usa esse nome ao falar e ao se apresentar.").font(.caption).foregroundStyle(Tema.secundario)
        }
    }
}

// MARK: - Fluxo da primeira abertura

struct OnboardingView: View {
    @Environment(PerfilAgente.self) private var perfil
    @Environment(Preferencias.self) private var prefs
    @State private var passo = 0

    private var tinta: Color { Tema.acao(prefs.destaque) }
    private var nomeValido: Bool { !perfil.nome.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        @Bindable var p = perfil
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                ForEach(0..<4, id: \.self) { i in Capsule().fill(i <= passo ? tinta : Tema.separador).frame(height: 4) }
            }
            .padding(.horizontal, Tema.margem).padding(.top, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    switch passo {
                    case 0: boasVindas
                    case 1:
                        Text("PASSO 1 DE 3").font(.caption.weight(.bold)).kerning(2).foregroundStyle(tinta)
                        Text("Como ele se chama?").font(Tema.titulo).foregroundStyle(Tema.texto)
                        CamposDeNome(perfil: p)
                    case 2:
                        Text("PASSO 2 DE 3").font(.caption.weight(.bold)).kerning(2).foregroundStyle(tinta)
                        Text("Monte o mascote.").font(Tema.titulo).foregroundStyle(Tema.texto)
                        MontadorMascote(mascote: $p.mascote, galeria: perfil.galeria, tinta: tinta)
                    default: pronto
                    }
                }
                .padding(Tema.margem)
            }

            VStack(spacing: 10) {
                Button(passo == 3 ? "Começar" : "Continuar") {
                    if passo == 3 { perfil.nome = perfil.nome.trimmingCharacters(in: .whitespaces); perfil.concluido = true } else { passo += 1 }
                }
                .buttonStyle(BotaoPrimario(cor: tinta))
                .disabled(passo == 1 && !nomeValido)
                if passo > 0 { Button("Voltar") { passo -= 1 }.buttonStyle(BotaoSecundario()) }
            }
            .padding(Tema.margem)
        }
        .background(Tema.fundo.ignoresSafeArea())
    }

    private var boasVindas: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BEM-VINDO").font(.caption.weight(.bold)).kerning(2).foregroundStyle(tinta).padding(.top, 8)
            Text("Seu assistente,\ndo seu jeito.").font(Tema.titulo).foregroundStyle(Tema.texto)
            Palco(altura: 190) { MascoteView(mascote: perfil.mascote, altura: 144).padding(.vertical, 20) }
            Text("Escolha um nome e monte o mascote. A conversa, a voz e a memória ficam neste iPhone, sem conta. Só a pesquisa na web e um servidor que você configurar usam a internet.")
                .font(.callout).foregroundStyle(Tema.secundario)
        }
    }

    private var pronto: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PRONTO").font(.caption.weight(.bold)).kerning(2).foregroundStyle(tinta).padding(.top, 8)
            Text("Prazer, eu sou \(perfil.nome.trimmingCharacters(in: .whitespaces)).").font(Tema.titulo).foregroundStyle(Tema.texto)
            Palco(altura: 190) { MascoteView(mascote: perfil.mascote, altura: 144).padding(.vertical, 20) }
            Text(perfil.tratamento.isEmpty ? "Vamos começar." : "Vamos começar, \(perfil.tratamento).").font(.callout.weight(.semibold)).foregroundStyle(Tema.texto)
            Text("Você pode mudar nome e mascote quando quiser em Ajustes › Meu agente. O modelo de IA e a voz também se escolhem em Ajustes.")
                .font(.footnote).foregroundStyle(Tema.secundario)
        }
    }
}

// MARK: - Ajustes › Meu agente

struct MeuAgenteView: View {
    @Environment(PerfilAgente.self) private var perfil
    @Environment(Preferencias.self) private var prefs

    var body: some View {
        @Bindable var p = perfil
        TelaAjuste(titulo: "Meu agente", subtitulo: "Nome, tratamento e mascote. Vale em todas as conversas.") {
            CamposDeNome(perfil: p)
            MontadorMascote(mascote: $p.mascote, galeria: perfil.galeria, tinta: Tema.acao(prefs.destaque))
        }
    }
}
