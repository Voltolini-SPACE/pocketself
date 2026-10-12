// PocketSelf — visão no aparelho (Vision framework, offline): lê texto (OCR pt-BR) e reconhece o que há na imagem.
// A imagem não sai do iPhone; o que vai ao modelo é só o texto extraído, marcado como conteúdo da imagem.
import PhotosUI
import SwiftUI
import UIKit
import Vision

struct AnaliseDeImagem: Equatable {
    var texto: String
    var rotulos: [String]
    var ms: Double
    var descricao: String? = nil

    /// Contexto que acompanha a pergunta do dono.
    var contexto: String {
        var s = "[Imagem anexada pelo usuário, analisada neste iPhone]"
        if let d = descricao, !d.isEmpty { s += "\nO que a imagem mostra (descrição feita por um modelo de visão neste iPhone): " + d }
        else { s += rotulos.isEmpty ? "" : "\nParece conter: " + rotulos.joined(separator: ", ") + "." }
        s += texto.isEmpty ? "\nNenhum texto legível." : "\nTexto lido na imagem (OCR, pode ter erros):\n" + String(texto.prefix(2500))
        return s
    }
}

enum Visao {
    static func analisar(_ imagem: UIImage) async -> AnaliseDeImagem {
        let t0 = Date.timeIntervalSinceReferenceDate
        guard let cg = imagem.cgImage else { return AnaliseDeImagem(texto: "", rotulos: [], ms: 0) }
        let resultado: (String, [String]) = await Task.detached(priority: .userInitiated) {
            let ocr = VNRecognizeTextRequest()
            ocr.recognitionLevel = .accurate
            ocr.recognitionLanguages = ["pt-BR", "en-US"]
            ocr.usesLanguageCorrection = true
            let classe = VNClassifyImageRequest()
            let h = VNImageRequestHandler(cgImage: cg, orientation: CGImagePropertyOrientation(imagem.imageOrientation))
            try? h.perform([ocr, classe])
            let linhas = (ocr.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            let rotulos = (classe.results ?? []).filter { $0.confidence > 0.3 }.prefix(5).map { Visao.traduzir($0.identifier) }
            return (linhas.joined(separator: "\n"), Array(rotulos))
        }.value
        let a = AnaliseDeImagem(texto: resultado.0, rotulos: resultado.1, ms: (Date.timeIntervalSinceReferenceDate - t0) * 1000)
        print(String(format: "[neo-visao] linhas=%d rotulos=%@ ms=%.0f", a.texto.split(separator: "\n").count, a.rotulos.joined(separator: ","), a.ms))
        return a
    }

    /// Rótulos do Vision vêm em inglês; os comuns são traduzidos, o resto segue como está.
    nonisolated static func traduzir(_ r: String) -> String {
        let t: [String: String] = ["document": "documento", "text": "texto", "paper": "papel", "receipt": "recibo", "screenshot": "captura de tela",
            "person": "pessoa", "people": "pessoas", "food": "comida", "dog": "cachorro", "cat": "gato", "car": "carro", "vehicle": "veículo",
            "outdoor": "ambiente externo", "indoor": "ambiente interno", "sky": "céu", "plant": "planta", "building": "prédio", "computer": "computador",
            "phone": "telefone", "card": "cartão", "table": "mesa", "child": "criança", "beach": "praia", "drink": "bebida", "sign": "placa"]
        return t[r.lowercased()] ?? r.replacingOccurrences(of: "_", with: " ")
    }
}

extension CGImagePropertyOrientation {
    init(_ o: UIImage.Orientation) {
        switch o {
        case .up: self = .up; case .down: self = .down; case .left: self = .left; case .right: self = .right
        case .upMirrored: self = .upMirrored; case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored; case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

/// Câmera do sistema (foto única). Só abre por ação do dono.
struct Camera: UIViewControllerRepresentable {
    var aoTirar: (UIImage) -> Void
    @Environment(\.dismiss) private var fechar
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let c = UIImagePickerController()
        c.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        c.delegate = context.coordinator
        return c
    }
    func updateUIViewController(_ c: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coord { Coord(self) }
    final class Coord: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let pai: Camera
        init(_ p: Camera) { pai = p }
        func imagePickerController(_ p: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage { pai.aoTirar(img) }
            pai.fechar()
        }
        func imagePickerControllerDidCancel(_ p: UIImagePickerController) { pai.fechar() }
    }
}

// MARK: - Gemma 4 olhando a foto (modelo de visão, no aparelho)

import CoreImage
import MLX
import MLXHuggingFace
import MLXLMCommon
import MLXVLM
import Tokenizers

enum VisaoGemma {
    static var pasta: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("modelos/gemma-4-e2b-it-4bit") }
    static var instalado: Bool { FileManager.default.fileExists(atPath: pasta.appendingPathComponent("config.json").path) }

    /// Descreve a foto em pt-BR. Carrega o Gemma 4 como visão só para isso e libera em seguida.
    static func descrever(_ imagem: UIImage) async -> String? {
        guard instalado, let cg = imagem.cgImage else { return nil }
        let t0 = Date.timeIntervalSinceReferenceDate
        do {
            let c = try await VLMModelFactory.shared.loadContainer(from: pasta, using: #huggingFaceTokenizerLoader())
            let s = ChatSession(c, instructions: "Você descreve imagens em português do Brasil, de forma objetiva, em até 4 frases. Diga o que aparece, pessoas, objetos, texto visível e o contexto. Não invente.",
                                generateParameters: GenerateParameters(maxTokens: 220, temperature: 0.3))
            let ci = CIImage(cgImage: cg).oriented(CGImagePropertyOrientation(imagem.imageOrientation))
            let texto = try await s.respond(to: "Descreva esta imagem.", image: .ciImage(ci))
            Memory.clearCache()
            print(String(format: "[neo-visao] gemma descreveu em %.1f s: %@", Date.timeIntervalSinceReferenceDate - t0, String(texto.prefix(160))))
            return texto.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("[neo-visao] gemma falhou: \(error)")
            return nil
        }
    }
}
