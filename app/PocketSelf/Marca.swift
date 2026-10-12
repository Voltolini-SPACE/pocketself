// PocketSelf — marca em pixel art. GERADO por scripts/gerar-marca.py: não edite à mão.
import SwiftUI

enum MarcaGrade {
    static let linhas = [
        ".....II......II.....",
        "....ICC......CCI....",
        "....IIIIIIIIIIII....",
        "...ICCLLLLLLLLCCI...",
        "...ICCCCCCCCCCCCI...",
        "...ICCCCCCCCCCCCI...",
        "...ICCWECCCCWECCI...",
        "...ICCEECCCCEECCI...",
        "...IBBCCCCCCCCBBI...",
        "...ICCCCECCECCCCI...",
        "...ICCCCCEECCCCCI...",
        "..IIIIIIIIIIIIIIII..",
        ".IDDDDDDDDDDDDDDDDI.",
        ".IDSDSDSDSDSDSDSDDI.",
        ".IPPPPPPPSSPPPPPPPI.",
        ".IPPPPPPPSSPPPPPPPI.",
        ".IPPPPPPPSSPPPPPPPI.",
        ".IPPPPPPPPPPPPPPPPI.",
        ".IPPPPPPPPPPPPPPPPI.",
        "..IIIIIIIIIIIIIIII.."
    ]
    static let contornoEscuro = "A79CE0"
    static func hex(_ c: Character, escuro: Bool = false) -> String? {
        if c == "I" && escuro { return contornoEscuro }
        switch c {
        case "I": return "1E1A36"
        case "E": return "1E1A36"
        case "C": return "FF7A59"
        case "L": return "FFB09C"
        case "W": return "FFFFFF"
        case "B": return "FF9DB0"
        case "P": return "4F46E5"
        case "D": return "3730B8"
        case "S": return "C7C3FF"
        default: return nil
        }
    }
}

/// A marca (rosto saindo do bolso). Pixel só aqui e nos personagens.
struct MarcaView: View {
    var altura: CGFloat = 28
    @Environment(\.colorScheme) private var esquema
    var body: some View {
        let n = CGFloat(MarcaGrade.linhas.count)
        let lado = altura / n
        Canvas { ctx, _ in
            for (y, linha) in MarcaGrade.linhas.enumerated() {
                for (x, ch) in linha.enumerated() {
                    guard let h = MarcaGrade.hex(ch, escuro: esquema == .dark) else { continue }
                    ctx.fill(Path(CGRect(x: CGFloat(x) * lado, y: CGFloat(y) * lado, width: lado + 0.4, height: lado + 0.4)), with: .color(Color(hex: h)))
                }
            }
        }
        .frame(width: altura, height: altura)
        .accessibilityHidden(true)
    }
}
