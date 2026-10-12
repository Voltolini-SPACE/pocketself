#!/usr/bin/env python3
"""Gera a marca do PocketSelf a partir de UMA grade de pixels: ícones do app (claro/escuro), SVGs do logo e
app/PocketSelf/Marca.swift (a mesma grade desenhada em SwiftUI). Arte original deste projeto (MIT). Requer Pillow.
Uso: python3 scripts/gerar-marca.py"""
import os
from PIL import Image
N = 20
g = [["."] * N for _ in range(N)]
def pt(x, y, c):
    if 0 <= x < N and 0 <= y < N: g[y][x] = c
def rect(x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1): pt(x, y, c)
def caixa(x0, y0, x1, y1, c, borda="I"):
    rect(x0, y0, x1, y1, borda); rect(x0 + 1, y0 + 1, x1 - 1, y1 - 1, c)
    for (x, y) in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)): pt(x, y, ".")
# orelhas
for (x, y) in ((3, 2), (4, 1), (5, 0), (6, 0), (13, 0), (14, 0), (15, 1), (16, 2)): pt(x, y, "I")
for (x, y) in ((4, 2), (5, 1), (6, 1), (13, 1), (14, 1), (15, 2)): pt(x, y, "C")
# cabeça
caixa(3, 2, 16, 12, "C")
rect(6, 3, 13, 3, "L")                     # brilho no alto
# olhos, bochechas e sorriso
rect(6, 6, 7, 7, "E"); rect(12, 6, 13, 7, "E"); pt(6, 6, "W"); pt(12, 6, "W")
rect(4, 8, 5, 8, "B"); rect(14, 8, 15, 8, "B")
pt(8, 9, "E"); pt(11, 9, "E"); rect(9, 10, 10, 10, "E")
# bolso por cima do corpo
caixa(1, 11, 18, 19, "P")
rect(2, 12, 17, 13, "D")                   # barra do bolso
for x in range(3, 17, 2): pt(x, 13, "S")   # pontos de costura
for (x, y) in ((9, 15), (10, 15), (9, 16), (10, 16)): pt(x, y, "S")   # brilho no bolso
pt(9, 14, "S"); pt(10, 14, "S")
pal = {"I": "1E1A36", "E": "1E1A36", "C": "FF7A59", "L": "FFB09C", "W": "FFFFFF", "B": "FF9DB0", "P": "4F46E5", "D": "3730B8", "S": "C7C3FF"}
grade = ["".join(l) for l in g]

def icone(fundo, saida, contorno=None):
    esc, off = 40, (1024 - N * 40) // 2
    im = Image.new("RGB", (1024, 1024), tuple(int(fundo[i:i+2], 16) for i in (0, 2, 4)))
    px = im.load()
    for y, l in enumerate(grade):
        for x, ch in enumerate(l):
            if ch in pal:
                hexa = contorno if (ch == "I" and contorno) else pal[ch]
                cor = tuple(int(hexa[i:i+2], 16) for i in (0, 2, 4))
                for dy in range(esc):
                    for dx in range(esc): px[off + x * esc + dx, off + y * esc + dy] = cor
    im.save(saida)
d = "app/PocketSelf/Assets.xcassets/AppIcon.appiconset"
os.makedirs(d, exist_ok=True)
icone("F8F5F0", f"{d}/icone-claro.png"); icone("15122B", f"{d}/icone-escuro.png", contorno="A79CE0")

def svg_marca(fundo=None):
    r = "".join(f'<rect x="{x}" y="{y}" width="1" height="1" fill="#{pal[ch]}"/>' for y, l in enumerate(grade) for x, ch in enumerate(l) if ch in pal)
    bg = f'<rect width="{N}" height="{N}" fill="#{fundo}"/>' if fundo else ""
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {N} {N}" shape-rendering="crispEdges">{bg}{r}</svg>'
os.makedirs("docs/marca", exist_ok=True)
open("docs/marca/pocketself-marca.svg", "w").write(svg_marca())
def lockup(tinta, destaque):
    r = "".join(f'<rect x="{x}" y="{y}" width="1" height="1" fill="#{pal[ch]}"/>' for y, l in enumerate(grade) for x, ch in enumerate(l) if ch in pal)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 150 20" role="img" aria-label="PocketSelf">'
            f'<g shape-rendering="crispEdges">{r}</g>'
            f'<text x="26" y="15" font-family="SF Pro Rounded, Nunito, Avenir Next, system-ui, sans-serif" font-size="14" font-weight="800" fill="#{tinta}">Pocket<tspan fill="#{destaque}">Self</tspan></text></svg>')
open("docs/marca/pocketself-logo-claro.svg", "w").write(lockup("1E1A36", "C0341D"))
open("docs/marca/pocketself-logo-escuro.svg", "w").write(lockup("F2EFFB", "FFA08F"))

# mesma grade em SwiftUI (um só desenho para app, ícone e docs)
linhas = ",\n        ".join(f'"{l}"' for l in grade)
cores = "\n".join(f'        case "{k}": return "{v}"' for k, v in pal.items())
open("app/PocketSelf/Marca.swift", "w").write(f'''// PocketSelf — marca em pixel art. GERADO por scripts/gerar-marca.py: não edite à mão.
import SwiftUI

enum MarcaGrade {{
    static let linhas = [
        {linhas}
    ]
    static let contornoEscuro = "A79CE0"
    static func hex(_ c: Character, escuro: Bool = false) -> String? {{
        if c == "I" && escuro {{ return contornoEscuro }}
        switch c {{
{cores}
        default: return nil
        }}
    }}
}}

/// A marca (rosto saindo do bolso). Pixel só aqui e nos personagens.
struct MarcaView: View {{
    var altura: CGFloat = 28
    @Environment(\.colorScheme) private var esquema
    var body: some View {{
        let n = CGFloat(MarcaGrade.linhas.count)
        let lado = altura / n
        Canvas {{ ctx, _ in
            for (y, linha) in MarcaGrade.linhas.enumerated() {{
                for (x, ch) in linha.enumerated() {{
                    guard let h = MarcaGrade.hex(ch, escuro: esquema == .dark) else {{ continue }}
                    ctx.fill(Path(CGRect(x: CGFloat(x) * lado, y: CGFloat(y) * lado, width: lado + 0.4, height: lado + 0.4)), with: .color(Color(hex: h)))
                }}
            }}
        }}
        .frame(width: altura, height: altura)
        .accessibilityHidden(true)
    }}
}}
''')
print("marca gerada:", len(grade), "linhas")
