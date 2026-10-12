import Foundation

@main struct Tests {
    static func rgb(_ h: String) -> (UInt8, UInt8, UInt8) {
        let v = UInt32(h, radix: 16) ?? 0
        return (UInt8(v >> 16 & 255), UInt8(v >> 8 & 255), UInt8(v & 255))
    }
    static func main() {
        let d = UserDefaults.standard
        for k in [Identidade.chaveNome, Identidade.chaveTratamento] { d.removeObject(forKey: k) }
        precondition(Identidade.nome == "PocketSelf" && Identidade.tratamento == "")
        precondition(Identidade.donoDe == "do usuário" && Identidade.donoSobre == "o usuário")
        d.set("  Luma ", forKey: Identidade.chaveNome); d.set(" Maria ", forKey: Identidade.chaveTratamento)
        precondition(Identidade.nome == "Luma" && Identidade.donoDe == "de Maria" && Identidade.donoSobre == "Maria")
        d.set("   ", forKey: Identidade.chaveNome)
        precondition(Identidade.nome == "PocketSelf")
        for k in [Identidade.chaveNome, Identidade.chaveTratamento] { d.removeObject(forKey: k) }

        var combinacoes = 0
        for e in Especie.allCases {
            for a in Acessorio.allCases {
                for h in Humor.allCases {
                    for o in Objeto.allCases {
                        for c in 0..<Paleta.corpos.count {
                            let g = Mascote(especie: e, cor: c, acessorio: a, humor: h, objeto: o).grade()
                            precondition(g.count == Mascote.altura, "altura \(e) \(a) \(h) \(o)")
                            for l in g {
                                precondition(l.count == Mascote.largura, "largura \(e) \(a) \(h) \(o): \(String(l))")
                                for ch in l where ch != "." { precondition(Mascote(especie: e, cor: c).hex(ch) != nil, "caractere \(ch)") }
                            }
                            combinacoes += 1
                        }
                    }
                }
            }
        }
        precondition(Mascote(cor: 99).corSegura == Paleta.corpos.count - 1 && Mascote(cor: -3).corSegura == 0)
        let m = Mascote(especie: .urso, cor: 3, acessorio: .coroa, humor: .esperto)
        precondition(Mascote.de(json: m.json()) == m && Mascote.de(json: "lixo") == nil && Mascote.de(json: nil) == nil)
        precondition(Especie.galeria.count == 14 && Acessorio.allCases.count == 14 && Objeto.allCases.count == 8)
        // JSON de instalação antiga (sem «objeto») continua válido.
        let antigo = "{\"especie\":\"urso\",\"cor\":2,\"acessorio\":\"coroa\",\"humor\":\"calmo\"}"
        precondition(Mascote.de(json: antigo) == Mascote(especie: .urso, cor: 2, acessorio: .coroa, humor: .calmo))
        // Cada espécie é visualmente distinta das outras (grade própria).
        var vistas = Set<String>()
        for e in Especie.galeria { vistas.insert(Mascote(especie: e).grade().map { String($0) }.joined()) }
        precondition(vistas.count == Especie.galeria.count, "espécies repetidas")

        // Folha de contato opcional: POCKETSELF_FOLHA=/caminho.ppm
        if let saida = ProcessInfo.processInfo.environment["POCKETSELF_FOLHA"] {
            let esc = 6, mx = 4
            let humores = Humor.allCases, acess = Acessorio.allCases, objs = Objeto.allCases
            let cols = humores.count * 2, linhasFolha = Especie.galeria.count
            let w = cols * (16 * esc + mx), h = linhasFolha * (18 * esc + mx)
            var px = [UInt8](repeating: 0xF2, count: w * h * 3)
            for (ri, e) in Especie.galeria.enumerated() {
                for ci in 0..<cols {
                    let hu = humores[ci % humores.count]
                    let ac = acess[(ri + ci / humores.count * 2) % acess.count]
                    let m = Mascote(especie: e, cor: (ri * 3 + ci) % Paleta.corpos.count, acessorio: ac, humor: hu, objeto: objs[(ri + ci) % objs.count])
                    for (y, l) in m.grade().enumerated() {
                        for (x, ch) in l.enumerated() {
                            guard let hx = m.hex(ch) else { continue }
                            let (r, g, b) = rgb(hx)
                            for dy in 0..<esc { for dx in 0..<esc {
                                let X = ci * (16 * esc + mx) + x * esc + dx, Y = ri * (18 * esc + mx) + y * esc + dy
                                let i = (Y * w + X) * 3; px[i] = r; px[i + 1] = g; px[i + 2] = b
                            } }
                        }
                    }
                }
            }
            var data = Data("P6\n\(w) \(h)\n255\n".utf8); data.append(contentsOf: px)
            try? data.write(to: URL(fileURLWithPath: saida))
        }
        // Elenco opcional: POCKETSELF_ELENCO=/caminho.ppm (7 colunas × 2 linhas, uma espécie por célula)
        if let saida = ProcessInfo.processInfo.environment["POCKETSELF_ELENCO"] {
            let esc = 8, cw = 16 * esc + 24, ch = 18 * esc + 40
            let w = 7 * cw, h = 2 * ch
            var px = [UInt8](repeating: 0xF8, count: w * h * 3)
            for (i, e) in Especie.galeria.enumerated() {
                let m = Mascote(especie: e, cor: [7, 0, 4, 6, 1, 3, 2, 1, 3, 4, 6, 5, 4, 0][i % 14], acessorio: .nenhum, humor: .feliz)
                let ox = (i % 7) * cw + 12, oy = (i / 7) * ch + 8
                for (y, l) in m.grade().enumerated() {
                    for (x, c) in l.enumerated() {
                        guard let hx = m.hex(c) else { continue }
                        let (r, g, b) = rgb(hx)
                        for dy in 0..<esc { for dx in 0..<esc {
                            let k = ((oy + y * esc + dy) * w + ox + x * esc + dx) * 3; px[k] = r; px[k + 1] = g; px[k + 2] = b
                        } }
                    }
                }
            }
            var data = Data("P6\n\(w) \(h)\n255\n".utf8); data.append(contentsOf: px)
            try? data.write(to: URL(fileURLWithPath: saida))
        }
        print("perfil: \(combinacoes) combinações válidas, identidade 6/6 aprovados")
    }
}
