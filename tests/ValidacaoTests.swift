import Foundation
@main struct Tests {
 static func main() throws {
  let pasta = URL(fileURLWithPath: "/tmp/neo-validacao")
  precondition(ValidacaoResposta.arquivoIsolado("conversas", argumentos: [], pasta: pasta) == nil)
  precondition(ValidacaoResposta.arquivoIsolado("conversas", argumentos: ["--validar-respostas"], pasta: pasta)?.lastPathComponent == "neo-validacao-conversas.json")
  precondition(ValidacaoResposta.arquivoIsolado("memoria", argumentos: ["--validar-respostas"], pasta: pasta)?.lastPathComponent == "neo-validacao-memoria.json")
  let linha = try ValidacaoResposta.linha(pergunta: "sintético", resposta: "R$ 18.166,97\nprintf \"$HOME $0\"", interrompida: false, erro: nil, motor: "Spark", ferramenta: "", primeiraMs: 123)
  let obj = try JSONSerialization.jsonObject(with: Data(linha.utf8)) as! [String: Any]
  precondition(obj["resposta"] as? String == "R$ 18.166,97\nprintf \"$HOME $0\"")
  precondition(Set(obj.keys) == Set(["pergunta","resposta","interrompida","motor","ferramenta","primeira_ms"]))
  let e = try ValidacaoResposta.linha(pergunta: "falha", resposta: "", interrompida: true, erro: "offline", motor: nil, ferramenta: "", primeiraMs: 0)
  let erro = try JSONSerialization.jsonObject(with: Data(e.utf8)) as! [String: Any]
  precondition(erro["erro"] as? String == "offline" && erro["interrompida"] as? Bool == true)
  print("validação isolada: 6/6 aprovados")
 }
}
