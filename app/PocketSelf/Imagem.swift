// PocketSelf — criação de imagem no aparelho (Image Playground / ImageCreator, iOS 18.4+).
// Exige Apple Intelligence ligada; roda no iPhone. Estilos da Apple: animação, ilustração, esboço.
import Foundation
import ImagePlayground
import UIKit

enum GeradorDeImagem {
    struct Erro: LocalizedError { let errorDescription: String? }

    /// Gera e salva em Documents/imagens; devolve o nome do arquivo.
    @MainActor
    static func gerar(_ descricao: String, estilo: String?) async throws -> String {
        guard #available(iOS 18.4, *) else { throw Erro(errorDescription: "Precisa do iOS 18.4 ou mais novo.") }
        let t0 = Date.timeIntervalSinceReferenceDate
        let criador: ImageCreator
        do { criador = try await ImageCreator() } catch {
            throw Erro(errorDescription: "Geração de imagem indisponível: \(explicar(error)).")
        }
        let disponiveis = criador.availableStyles
        let pedido: ImagePlaygroundStyle = {
            switch (estilo ?? "").lowercased() {
            case "esboco", "esboço", "sketch": return .sketch
            case "ilustracao", "ilustração", "illustration": return .illustration
            default: return .animation
            }
        }()
        let escolhido = disponiveis.contains(pedido) ? pedido : (disponiveis.first ?? .animation)
        var arquivo: String?
        for try await img in criador.images(for: [.text(descricao)], style: escolhido, limit: 1) {
            let ui = UIImage(cgImage: img.cgImage)
            let pasta = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("imagens")
            try? FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
            let nome = "img-\(Int(Date().timeIntervalSince1970)).png"
            try ui.pngData()?.write(to: pasta.appendingPathComponent(nome))
            arquivo = nome
            break
        }
        guard let arquivo else { throw Erro(errorDescription: "Nenhuma imagem gerada.") }
        print(String(format: "[neo-imagem] gerada=%@ estilo=%@ s=%.1f", arquivo, "\(escolhido)", Date.timeIntervalSinceReferenceDate - t0))
        return arquivo
    }

    static func explicar(_ e: Error) -> String {
        let d = "\(e)"
        if d.contains("notSupported") { return "este aparelho não suporta" }
        if d.contains("unavailable") { return "Apple Intelligence desligada ou ainda baixando (Ajustes › Apple Intelligence e Siri)" }
        if d.contains("unsupportedLanguage") { return "idioma não suportado; tente descrever em inglês" }
        if d.contains("backgroundCreationForbidden") { return "o PocketSelf precisa estar aberto na tela" }
        return e.localizedDescription
    }

    static func url(_ nome: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("imagens").appendingPathComponent(nome)
    }
}
