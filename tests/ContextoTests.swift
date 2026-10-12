import Foundation
@main struct Tests {
 static func main() {
  let msgs = [Spark.Msg(role: "user", content: "anterior"), Spark.Msg(role: "assistant", content: "resposta"), Spark.Msg(role: "user", content: "pedido")]
  let atual = ContextoResposta.historico(instrucoes: "sistema", mensagens: msgs, pedido: "imagem OCR\nPedido do usuário: pedido")
  precondition(atual.count == 4)
  precondition(atual.map(\.content) == ["sistema", "anterior", "resposta", "imagem OCR\nPedido do usuário: pedido"])
  precondition(ContextoResposta.anteriores(msgs).map(\.content) == ["anterior", "resposta"])
  precondition(ContextoResposta.anteriores(Array(msgs.dropLast())).count == 2)
  let hoje = ContextoResposta.hoje()
  precondition(ContextoResposta.instrucoes(base: "chat", voz: "voz", porVoz: true, memoria: "preferencia") == "vozpreferencia" + hoje)
  precondition(ContextoResposta.instrucoes(base: "chat", voz: "voz", porVoz: false, memoria: "preferencia") == "chatpreferencia" + hoje)
  precondition(hoje.contains("hora_e_data") && hoje.contains("Hoje é "))
  let dia = ContextoResposta.hoje(Date(timeIntervalSince1970: 1_791_800_000))
  precondition(dia.contains("2026"))
  print("contexto: 8/8 aprovados")
 }
}
