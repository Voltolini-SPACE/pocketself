// PocketSelf — identidade «Bolso»: papel quente + tinta índigo, pixel só na marca e nos personagens.
// Contraste conferido por scripts/verificar-contraste.py (texto ≥ 4,5:1, bordas e botões ≥ 3:1). Texto usa a fonte do sistema (Dynamic Type).
import SwiftUI
import UIKit

/// Cor de destaque escolhida em Ajustes › Aparência. Erro e encerrar nunca mudam com ela.
enum Destaque: String, CaseIterable, Codable, Identifiable {
    case indigo, menta, coral, sol
    var id: String { rawValue }
    var nome: String {
        switch self {
        case .indigo: return "Índigo"
        case .menta: return "Menta"
        case .coral: return "Coral"
        case .sol: return "Sol"
        }
    }
    /// Claro: fundo do botão e tinta de texto (iguais). Escuro: fundo do botão (≥ 3:1 no fundo) e tinta (≥ 4,5:1).
    var claro: String {
        switch self { case .indigo: return "4F46E5"; case .menta: return "0F7A55"; case .coral: return "C0341D"; case .sol: return "8A5300" }
    }
    var escuroFundo: String {
        switch self { case .indigo: return "5B52F0"; case .menta: return "12865C"; case .coral: return "CE3B22"; case .sol: return "A86500" }
    }
    var escuroTinta: String {
        switch self { case .indigo: return "B4B0FF"; case .menta: return "7FE0B8"; case .coral: return "FFA08F"; case .sol: return "FFC857" }
    }
}

enum ModoTema: String, CaseIterable, Codable, Identifiable {
    case automatico, claro, escuro
    var id: String { rawValue }
    var nome: String {
        switch self { case .automatico: return "Automático"; case .claro: return "Claro"; case .escuro: return "Escuro" }
    }
    var esquema: ColorScheme? {
        switch self { case .automatico: return nil; case .claro: return .light; case .escuro: return .dark }
    }
}

extension UIColor {
    convenience init(hex: String) {
        var v: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&v)
        self.init(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }
}

extension Color {
    init(hex: String) { self.init(UIColor(hex: hex)) }
    /// Cor que troca sozinha entre claro e escuro.
    static func dinamica(_ claro: String, _ escuro: String) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: escuro) : UIColor(hex: claro) })
    }
}

enum Tema {
    static let fundo = Color.dinamica("F8F5F0", "15122B")
    static let superficie = Color.dinamica("FFFFFF", "201B3D")
    static let texto = Color.dinamica("1E1A36", "F2EFFB")
    static let secundario = Color.dinamica("5A5473", "BAB3D3")
    /// v1.1: contorno de campo e botão secundário (≥ 3:1 nos dois temas).
    static let borda = Color.dinamica("857E9B", "8478B0")
    /// Separador decorativo de lista (sem exigência de contraste).
    static let separador = Color.dinamica("DDD7E8", "3A3563")
    static let suave = Color.dinamica("EFEAF8", "2B2551")
    /// Fundo do botão de perigo (texto branco por cima).
    static let perigo = Color(hex: "B3261E")
    /// Texto e ícone de erro: mais claro no escuro para manter ≥ 4,5:1.
    static let perigoTexto = Color.dinamica("B3261E", "FF8A80")

    static func acao(_ d: Destaque) -> Color { .dinamica(d.claro, d.escuroFundo) }
    static func tinta(_ d: Destaque) -> Color { .dinamica(d.claro, d.escuroTinta) }

    static let margem: CGFloat = 16
    static let raio: CGFloat = 12
    /// Título de tela (padrão compacto, como nos apps de chat): 26 pt.
    static let titulo = Font.system(size: 22, weight: .bold)
}

/// Preferências do aparelho (não dependem de conta nem de IA).
@Observable
final class Preferencias {
    var modoTema: ModoTema { didSet { UserDefaults.standard.set(modoTema.rawValue, forKey: "modoTema") } }
    var destaque: Destaque { didSet { UserDefaults.standard.set(destaque.rawValue, forKey: "destaque") } }
    var motorId: String { didSet { UserDefaults.standard.set(motorId, forKey: "motorId") } }
    var falarNoChat: Bool { didSet { UserDefaults.standard.set(falarNoChat, forKey: "falarNoChat") } }
    /// Voz neural Kokoro (mais natural). Vazio = voz do sistema.
    var vozNeural: String { didSet { UserDefaults.standard.set(vozNeural, forKey: "vozNeural") } }

    /// Argumento de execução pelo cabo (`--nome=valor`), usado nas verificações sem tocar na tela.
    static func argumento(_ nome: String) -> String? {
        CommandLine.arguments.first { $0.hasPrefix("--\(nome)=") }.map { String($0.dropFirst(nome.count + 3)) }
    }

    init() {
        let d = UserDefaults.standard
        if let t = Self.argumento("tema"), let m = ModoTema(rawValue: t) { d.set(m.rawValue, forKey: "modoTema") }
        modoTema = ModoTema(rawValue: d.string(forKey: "modoTema") ?? "") ?? .automatico
        destaque = Destaque(rawValue: d.string(forKey: "destaque") ?? "") ?? .indigo
        if let m = Self.argumento("motor") { d.set(m, forKey: "motorId") }
        motorId = d.string(forKey: "motorId") ?? "qwen3.5-4b"
        falarNoChat = d.bool(forKey: "falarNoChat")
        if let v = Self.argumento("voz") { d.set(v == "sistema" ? "" : v, forKey: "vozNeural") }
        vozNeural = d.object(forKey: "vozNeural") as? String ?? ""
    }
}

// MARK: - Estilos de botão

struct BotaoPrimario: ButtonStyle {
    var cor: Color
    var altura: CGFloat = 52
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: altura)
            .background(cor.opacity(configuration.isPressed ? 0.85 : 1), in: RoundedRectangle(cornerRadius: 9))
    }
}

struct BotaoSecundario: ButtonStyle {
    var altura: CGFloat = 48
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Tema.texto)
            .frame(maxWidth: .infinity, minHeight: altura)
            .background(Tema.superficie.opacity(configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Tema.borda, lineWidth: 1))
    }
}

struct BotaoPerigo: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Tema.perigo.opacity(configuration.isPressed ? 0.85 : 1), in: RoundedRectangle(cornerRadius: 9))
    }
}

/// Botão quadrado 44×44 com contorno (o «+» do cabeçalho, o «+» do compositor).
struct BotaoIcone: ButtonStyle {
    var lado: CGFloat = 40
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(Tema.texto)
            .frame(width: lado, height: lado)
            .background(Tema.superficie.opacity(configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Tema.borda, lineWidth: 1))
    }
}

/// Cartão branco com contorno fino, usado em listas de Ajustes e Histórico.
struct Cartao<Conteudo: View>: View {
    @ViewBuilder var conteudo: Conteudo
    var body: some View {
        VStack(spacing: 0) { conteudo }
            .background(Tema.superficie, in: RoundedRectangle(cornerRadius: Tema.raio))
            .overlay(RoundedRectangle(cornerRadius: Tema.raio).stroke(Tema.separador, lineWidth: 1))
    }
}

struct RotuloDeGrupo: View {
    var texto: String
    var body: some View {
        Text(texto.uppercased())
            .font(.caption.weight(.semibold))
            .kerning(1)
            .foregroundStyle(Tema.secundario)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 18)
            .padding(.bottom, 8)
    }
}

/// Aviso com barra lateral na cor de destaque (o «callout» do brandbook).
struct Aviso: View {
    var texto: String
    var cor: Color = Tema.secundario
    var body: some View {
        Text(texto)
            .font(.footnote)
            .foregroundStyle(cor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(13)
            .background(Tema.suave, in: RoundedRectangle(cornerRadius: 4))
            .overlay(alignment: .leading) { Rectangle().fill(Tema.tinta(.indigo)).frame(width: 3) }
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
