// PocketSelf — personagem, marca e cabeçalho. Pixel art ampliado por vizinho mais próximo (nunca borrado).
import SwiftUI

/// Corpo inteiro (62×97). Abertura e sessão ao vivo.
struct Sprite: View {
    @Environment(PerfilAgente.self) private var perfil
    var altura: CGFloat = 132
    var body: some View {
        MascoteView(mascote: perfil.mascote, altura: altura)
            .accessibilityLabel(perfil.nome)
    }
}

/// Rosto. Cabeçalho, mensagens, perfil.
struct Avatar: View {
    @Environment(PerfilAgente.self) private var perfil
    var tamanho: CGFloat = 32
    var body: some View {
        // Largura pedida → altura equivalente (rosto 16×13).
        MascoteView(mascote: perfil.mascote, altura: tamanho * 13 / 16, rosto: true)
            .accessibilityHidden(true)
    }
}

/// Nome da marca em texto: «Pocket» na tinta do tema, «Self» na cor de destaque.
struct Lettering: View {
    var altura: CGFloat = 22
    @Environment(Preferencias.self) private var prefs
    var body: some View {
        (Text("Pocket").foregroundStyle(Tema.texto) + Text("Self").foregroundStyle(Tema.tinta(prefs.destaque)))
            .font(.system(size: altura, weight: .heavy, design: .rounded)).minimumScaleFactor(0.5).lineLimit(1)
            .accessibilityLabel("PocketSelf")
    }
}

/// Cabeçalho das três abas: avatar + marca + subtítulo; «+» só onde faz sentido.
struct Cabecalho: View {
    var subtitulo = "Seu assistente pessoal"
    var acaoMais: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                MarcaView(altura: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Lettering(altura: 18)
                    Text(subtitulo).font(.caption2).foregroundStyle(Tema.secundario)
                }
                Spacer()
                if let acaoMais {
                    Button(action: acaoMais) { Image(systemName: "plus") }
                        .buttonStyle(BotaoIcone())
                        .accessibilityLabel("Nova conversa")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Tema.superficie)
            Rectangle().fill(Tema.separador).frame(height: 1)
        }
    }
}

/// Palco do personagem: fundo suave com cantoneiras pixeladas.
struct Palco<Conteudo: View>: View {
    var altura: CGFloat = 132
    @ViewBuilder var conteudo: Conteudo
    var body: some View {
        conteudo
            .frame(maxWidth: .infinity, minHeight: altura)
            .background(Tema.suave, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Tema.separador, lineWidth: 1))
            .overlay(alignment: .topLeading) { Cantoneira().padding(12) }
            .overlay(alignment: .bottomTrailing) { Cantoneira().rotationEffect(.degrees(180)).padding(12) }
    }
}

private struct Cantoneira: View {
    var body: some View {
        Path { p in
            p.move(to: CGPoint(x: 0, y: 14)); p.addLine(to: .zero); p.addLine(to: CGPoint(x: 14, y: 0))
        }
        .stroke(Tema.separador, lineWidth: 3)
        .frame(width: 14, height: 14)
    }
}
