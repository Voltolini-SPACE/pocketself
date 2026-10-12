// PocketSelf — identidade do agente (nome, tratamento) e mascote montado por camadas em pixel art.
// Só Foundation: testável no Mac sem simulador. As telas ficam em MascoteView.swift e Onboarding.swift.
import Foundation

/// Nome do agente e como ele chama a pessoa. Lido direto do UserDefaults para valer em qualquer prompt.
enum Identidade {
    static let chaveNome = "agenteNome", chaveTratamento = "agenteTratamento"
    static let chaveMascote = "agenteMascote", chaveConcluido = "agenteConcluido"

    static var nome: String {
        let n = (UserDefaults.standard.string(forKey: chaveNome) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "PocketSelf" : n
    }
    /// Como o agente chama a pessoa. Vazio = sem nome próprio.
    static var tratamento: String {
        (UserDefaults.standard.string(forKey: chaveTratamento) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    /// «de Maria» / «do usuário», para frases como «assistente pessoal de …».
    static var donoDe: String { tratamento.isEmpty ? "do usuário" : "de \(tratamento)" }
    /// «sobre Maria» / «sobre o usuário».
    static var donoSobre: String { tratamento.isEmpty ? "o usuário" : tratamento }
}

// MARK: - Mascote

enum Especie: String, CaseIterable, Codable {
    case gato, coelho, urso, robo, raposa, dino
    case cachorro, coruja, sapo, pinguim, panda, alien, fantasma, polvo

    static var galeria: [Especie] { allCases }

    var nome: String {
        switch self {
        case .gato: return "Gatinho"; case .coelho: return "Coelhinho"; case .urso: return "Ursinho"
        case .robo: return "Robozinho"; case .raposa: return "Raposinha"; case .dino: return "Dinozinho"
        case .cachorro: return "Cachorrinho"; case .coruja: return "Corujinha"; case .sapo: return "Sapinho"; case .pinguim: return "Pinguinzinho"
        case .panda: return "Pandinha"; case .alien: return "Alienzinho"; case .fantasma: return "Fantasminha"; case .polvo: return "Polvinho"
        }
    }
    /// Linhas 0…3 da grade (orelhas, antena, espinhos).
    fileprivate var topo: [String] {
        switch self {
        case .gato:
            return ["...O........O...", "...OO......OO...", "...OAO....OAO...", "...OAAOOOOAAO..."]
        case .raposa:
            return ["..O..........O..", "..OO........OO..", "..OAO......OAO..", "..OAAOOOOOOAAO.."]
        case .coelho:
            return ["....OO....OO....", "...OAAO..OAAO...", "...OAAO..OAAO...", "...OAAOOOOAAO..."]
        case .urso:
            return ["................", "...OOO....OOO...", "..OAAAO..OAAAO..", "..OAAAOOOOAAAO.."]
        case .robo:
            return [".......OO.......", ".......OO.......", "......OAAO......", "....OOOOOOOO...."]
        case .dino:
            return ["................", ".......OO.......", "......OAAO......", "....OOOAAOOO...."]
        case .cachorro, .coruja, .sapo, .pinguim, .panda, .alien, .fantasma, .polvo:
            return ["................", "................", "................", "....OOOOOOOO...."]
        }
    }
    fileprivate var focinho: Bool { self == .gato || self == .raposa || self == .urso || self == .cachorro || self == .panda }
    /// Espécies que desenham os próprios olhos: a expressão só mexe na boca e nas bochechas.
    fileprivate var olhosProprios: Bool { self == .coruja || self == .sapo || self == .alien }
    /// Camada própria da espécie (linha → texto de 16 colunas), aplicada antes da expressão.
    fileprivate var camada: [Int: String] {
        switch self {
        case .raposa:
            return [8: "..OBBBBBBBBBBO..", 9: "..OLLBLLLLBLLO..", 10: "..OBLLLLLLLLBO..", 11: "...OBBLLLLBBO..."]
        case .cachorro:
            return [3: "..OOO......OOO..", 4: ".OAAAO....OAAAO.", 5: ".OAAAO....OAAAO.", 6: ".OAAAO....OAAAO.", 7: "..OAO......OAO..", 9: "..OBBLLKKLLBBO.."]
        case .coruja:
            return [1: "..OO........OO..", 2: "..OAO......OAO..", 3: "..OAAOOOOOOAAO..",
                    5: "..OBBBBBBBBBBO..", 6: "..OLLLOBBOLLLO..", 7: "..OLKWLNNLKWLO..", 8: "..OLKKLNNLKKLO..", 9: "..OBLLLBBLLLBO..", 10: "..OBBBBBBBBBBO.."]
        case .sapo:
            return [1: "...OOO....OOO...", 2: "..OWWWO..OWWWO..", 3: "..OWKWOOOOWKWO..", 4: "...OBBBBBBBBO...",
                    5: "..OBBBBBBBBBBO..", 9: "..OPPBBBBBBPPO.."]
        case .pinguim:
            return [4: "...OKKKKKKKKO...", 5: "..OKKKKKKKKKKO..", 6: "..OKKLLLLLLKKO..", 7: "..OKLLLLLLLLKO..", 8: "..OKLLLLLLLLKO..",
                    9: "..OKLLLNNLLLKO..", 10: "..OKLLNNNNLLKO..", 11: "...OKLLLLLLKO...", 13: "...OKKLLLLKKO...", 14: "..OKKLLLLLLKKO..", 15: "...OKLLLLLLKO..."]
        case .panda:
            return [1: "...OOO....OOO...", 2: "..OKKKO..OKKKO..", 3: "..OKKKOOOOKKKO..",
                    6: "..OBKKKBBKKKBO..", 7: "..OBKKKBBKKKBO..", 13: "...OKKBBBBKKO...", 14: "..OKKBLLLLBKKO..", 15: "...OKBLLLLBKO..."]
        case .alien:
            return [0: ".....O....O.....", 1: ".....OY..YO.....", 2: "......O..O......", 3: ".....OOOOOO.....", 4: "...OBBBBBBBBO...",
                    5: "..OBBBBBBBBBBO..", 6: "..OBKKKBBKKKBO..", 7: "..OBKKWBBKKWBO..", 8: "..OBKKKBBKKKBO..", 9: "...OBBBBBBBBO...", 10: "....OBBBBBBO...."]
        case .fantasma:
            return [3: "....OOOOOOOO....", 4: "...OLLLLLLLLO...", 5: "..OLLLLLLLLLLO..", 13: "..OLLLLLLLLLLO..", 14: "..OLLLLLLLLLLO..", 15: "..OLLLLLLLLLLO..",
                    16: "..OLLOLLLLOLLO..", 17: "...O.OLLLLO.O..."]
        case .polvo:
            return [4: "...OBBBBBBBBO...", 12: "...OOOOOOOOOO...", 13: "..OBBBBBBBBBBO..", 14: "..OBOBBOOBBOBO..", 15: "..OAOBAOOABOAO..",
                    16: "..OA.OA..AO.AO..", 17: "..OO.OO..OO.OO.."]
        default: return [:]
        }
    }
}

enum Acessorio: String, CaseIterable, Codable {
    case nenhum, oculos, coroa, laco, fone, bruxo, cartola, bone, tapaolho, borboleta, flor, capacete, estrelas, cachecol
    var nome: String {
        switch self { case .nenhum: return "Nenhum"; case .oculos: return "Óculos"; case .coroa: return "Coroa"; case .laco: return "Laço"; case .fone: return "Fone"
        case .bruxo: return "Chapéu de bruxo"; case .cartola: return "Cartola"; case .bone: return "Boné"; case .tapaolho: return "Tapa-olho"
        case .borboleta: return "Gravata"; case .flor: return "Flor"; case .capacete: return "Capacete"; case .estrelas: return "Estrelas"; case .cachecol: return "Cachecol" }
    }
    fileprivate var camada: [Int: String] {
        switch self {
        case .nenhum: return [:]
        case .oculos: return [6: "...GGGG..GGGG...", 7: "...G..GGGG..G...", 8: "...G..G..G..G...", 9: "...GGGG..GGGG..."]
        case .coroa: return [1: ".....Y.YY.Y.....", 2: ".....YYYYYY.....", 3: ".....YOYYOY....."]
        case .laco: return [3: ".........RR.RR..", 4: "..........RRR..."]
        case .fone: return [5: "....GGGGGGGG....", 6: "..GG........GG..", 7: "..GG........GG..", 8: "..GG........GG.."]
        case .bruxo: return [0: ".......QQ.......", 1: "......QQQQ......", 2: ".....QQYYQQ.....", 3: "..QQQQQQQQQQQQ.."]
        case .cartola: return [0: "....KKKKKKKK....", 1: "....KKKKKKKK....", 2: "....KRRRRRRK....", 3: "..KKKKKKKKKKKK.."]
        case .bone: return [2: ".....RRRRRR.....", 3: "....RRRRRRRRRR..", 4: "...RRRRRRRRRRR.."]
        case .tapaolho: return [6: "..KKKKKKKKKKKK..", 7: "........KKKK....", 8: "........KKKK...."]
        case .borboleta: return [12: "....RRR..RRR....", 13: ".....RRRRRR....."]
        case .flor: return [2: "..........PP....", 3: ".........PYYP...", 4: "..........PP...."]
        case .capacete: return [2: ".....YYYYYY.....", 3: "...YYYYYYYYYY...", 4: "...YYOOOOOOYY..."]
        case .estrelas: return [0: "..Y..........Y..", 1: ".YYY........YYY.", 2: "..Y..........Y.."]
        case .cachecol: return [12: "...RRRRRRRRRR...", 13: "....RRY..RRR....", 14: ".........RR....."]
        }
    }
}

/// O que o personagem segura (canto inferior direito).
enum Objeto: String, CaseIterable, Codable {
    case nenhum, cafe, livro, estrela, coracao, planta, balao, controle
    var nome: String {
        switch self {
        case .nenhum: return "Nada"; case .cafe: return "Café"; case .livro: return "Livro"; case .estrela: return "Estrela"
        case .coracao: return "Coração"; case .planta: return "Plantinha"; case .balao: return "Balão"; case .controle: return "Controle"
        }
    }
    fileprivate var camada: [Int: String] {
        switch self {
        case .nenhum: return [:]
        case .cafe: return [12: "............W.W.", 13: "..........OOOOO.", 14: "..........OMMMOO", 15: "..........OMMMO.", 16: "...........OOO.."]
        case .livro: return [13: ".........OOOOOO.", 14: ".........OQQUQO.", 15: ".........OQQUQO.", 16: ".........OOOOOO."]
        case .estrela: return [12: "...........Y....", 13: "..........YYY...", 14: "........YYYYYYY.", 15: "..........YYY...", 16: ".........YY.YY.."]
        case .coracao: return [13: "..........RR.RR.", 14: ".........RRRRRRR", 15: "..........RRRRR.", 16: "...........RRR.."]
        case .planta: return [12: ".........V.V....", 13: "..........VV....", 14: ".........OMMMO..", 15: ".........OMMMO..", 16: "..........OOO..."]
        case .balao: return [11: "..........RRR...", 12: ".........RRRRR..", 13: ".........RRRRR..", 14: "..........RRR...", 15: "...........O....", 16: "...........O...."]
        case .controle: return [14: "........OOOOOOOO", 15: "........OKYKKRKO", 16: "........OOOOOOOO"]
        }
    }
}

enum Humor: String, CaseIterable, Codable {
    case feliz, calmo, surpreso, esperto
    var nome: String {
        switch self { case .feliz: return "Feliz"; case .calmo: return "Calmo"; case .surpreso: return "Surpreso"; case .esperto: return "Esperto" }
    }
    fileprivate var rosto: [Int: String] {
        let bochechas = "...PP......PP..."
        switch self {
        case .feliz:
            return [7: "....EE....EE....", 8: "....EW....EW....", 9: bochechas, 10: "......E..E......", 11: ".......EE......."]
        case .calmo:
            return [8: "....EE....EE....", 9: bochechas, 10: ".......EE......."]
        case .surpreso:
            return [6: "....EE....EE....", 7: "....EW....EW....", 8: "....EE....EE....", 9: bochechas, 10: ".......EE......."]
        case .esperto:
            return [7: "..........EE....", 8: "....EE....EW....", 9: bochechas, 10: "......E..E......", 11: ".......EE......."]
        }
    }
}

/// Cores do corpo: nome, corpo, claro (barriga/focinho), acento (orelhas/bochecha).
enum Paleta {
    static let corpos: [(nome: String, corpo: String, claro: String, acento: String)] = [
        ("Rosa", "F6B8C8", "FFF1F4", "E98AA6"), ("Pêssego", "FFC9A3", "FFF3E8", "F29A72"),
        ("Creme", "F3E2B3", "FFFBEA", "E3C27A"), ("Menta", "A9E4CC", "F0FFF8", "6FCBA4"),
        ("Céu", "A9D3F5", "F1F8FF", "6FA8E0"), ("Lavanda", "CDB9F2", "F7F2FF", "A58BE0"),
        ("Cinza", "C9CED6", "F5F6F8", "9AA2B0"), ("Laranja", "F8B26A", "FFF0DD", "E98A3A"),
    ]
    static let contorno = "2B2438", olho = "2B2438", brilho = "FFFFFF", bochecha = "F48FA6"
    static let amarelo = "F7CF3D", vermelho = "E5484D", cinza = "6B7280"
    static let preto = "2B2438", laranja = "F59E0B", roxo = "7C3AED", azul = "38BDF8", marrom = "8B5A2B", verde = "22C55E"
}

struct Mascote: Codable, Equatable {
    var especie: Especie = .gato
    var cor = 0
    var acessorio: Acessorio = .nenhum
    var humor: Humor = .feliz
    var objeto: Objeto = .nenhum

    static let largura = 16, altura = 18, alturaRosto = 13

    var corSegura: Int { min(max(cor, 0), Paleta.corpos.count - 1) }

    /// Grade de caracteres: O contorno, B corpo, L claro, A acento, E olho, W brilho, P bochecha, G cinza, Y amarelo, R vermelho,
    /// K preto, N laranja, Q roxo, U azul, M marrom.
    func grade() -> [[Character]] {
        var linhas = [
            "................", "................", "................", "....OOOOOOOO....",
            "...OBBBBBBBBO...", "..OBBBBBBBBBBO..", "..OBBBBBBBBBBO..", "..OBBBBBBBBBBO..",
            "..OBBBBBBBBBBO..", "..OBBBBBBBBBBO..", "..OBBBBBBBBBBO..", "...OBBBBBBBBO...",
            "....OOOOOOOO....", "...OBBBBBBBBO...", "..OBBLLLLLLBBO..", "...OBLLLLLLBO...",
            "....OOOOOOOO....", "....OO....OO....",
        ].map { Array($0) }
        for (i, t) in especie.topo.enumerated() { linhas[i] = Array(t) }
        if especie.focinho {
            linhas[9] = Array("..OBBLLLLLLBBO..")
            linhas[10] = Array("..OBBLLLLLLBBO..")
        }
        for (r, t) in especie.camada { linhas[r] = Array(t) }
        var rosto = humor.rosto
        if especie.olhosProprios { rosto = rosto.filter { $0.key >= 9 } }
        for camada in [rosto, acessorio.camada, objeto.camada] {
            for (r, t) in camada {
                for (c, ch) in Array(t).enumerated() where ch != "." { linhas[r][c] = ch }
            }
        }
        return linhas
    }

    /// Cor hexadecimal de um caractere da grade (nil = transparente).
    func hex(_ ch: Character) -> String? {
        let p = Paleta.corpos[corSegura]
        switch ch {
        case "O": return Paleta.contorno
        case "B": return p.corpo
        case "L": return p.claro
        case "A": return p.acento
        case "E": return Paleta.olho
        case "W": return Paleta.brilho
        case "P": return Paleta.bochecha
        case "G": return Paleta.cinza
        case "Y": return Paleta.amarelo
        case "R": return Paleta.vermelho
        case "K": return Paleta.preto
        case "N": return Paleta.laranja
        case "Q": return Paleta.roxo
        case "U": return Paleta.azul
        case "M": return Paleta.marrom
        case "V": return Paleta.verde
        default: return nil
        }
    }

    init(especie: Especie = .gato, cor: Int = 0, acessorio: Acessorio = .nenhum, humor: Humor = .feliz, objeto: Objeto = .nenhum) {
        self.especie = especie; self.cor = cor; self.acessorio = acessorio; self.humor = humor; self.objeto = objeto
    }
    /// Instalações antigas não têm `objeto` no JSON: o padrão cobre a falta.
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        especie = (try? c.decode(Especie.self, forKey: .especie)) ?? .gato
        cor = (try? c.decode(Int.self, forKey: .cor)) ?? 0
        acessorio = (try? c.decode(Acessorio.self, forKey: .acessorio)) ?? .nenhum
        humor = (try? c.decode(Humor.self, forKey: .humor)) ?? .feliz
        objeto = (try? c.decode(Objeto.self, forKey: .objeto)) ?? .nenhum
    }

    func json() -> String {
        (try? JSONEncoder().encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }
    static func de(json: String?) -> Mascote? {
        json.flatMap { $0.data(using: .utf8) }.flatMap { try? JSONDecoder().decode(Mascote.self, from: $0) }
    }
}
