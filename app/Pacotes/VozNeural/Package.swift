// swift-tools-version:5.10
// NEO — só o Kokoro TTS (e o AudioCommon de que ele depende), extraídos de soniqo/speech-swift @ cbcdfc6 (Apache-2.0).
// Extraído para não puxar o pacote inteiro, que fixa outra versão do MLX.
import PackageDescription

let package = Package(
    name: "VozNeural",
    platforms: [.iOS("18.0"), .macOS("15.0")],
    products: [.library(name: "KokoroTTS", targets: ["KokoroTTS"])],
    dependencies: [.package(url: "https://github.com/huggingface/swift-transformers", from: "1.3.0")],
    targets: [
        .target(name: "AudioCommon", dependencies: [.product(name: "Hub", package: "swift-transformers")]),
        .target(name: "KokoroTTS", dependencies: ["AudioCommon"], resources: [.process("Resources")]),
    ]
)
