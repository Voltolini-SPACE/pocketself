import Foundation
// Dependências de navegação/UI não exercidas: os três armazenamentos são reais.
enum Preferencias { static func argumento(_ nome: String) -> String? { nil } }
struct Pendencia { enum Tipo { case evento, lembrete, nota, alarme, atalho, mensagem, email, ligacao } }
@main struct Tests {
 @MainActor static func main() throws {
  let pasta = FileManager.default.temporaryDirectory.appendingPathComponent("neo-persistencia-\(UUID())")
  try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: pasta) }
  var falhas = 0; var total = 0
  func check(_ ok: Bool, _ nome: String) { total += 1; if !ok { falhas += 1 }; print("\(ok ? "PASS" : "FAIL") \(nome)") }
  let ch = pasta.appendingPathComponent("conversas.json")
  let h = Historico(arquivo: ch); let c = h.nova()
  h.anexar(Mensagem(deNEO: false, texto: "entrada sintética"), em: c.id)
  check(Historico(arquivo: ch).conversa(c.id)?.mensagens.first?.texto == "entrada sintética", "histórico cria e recarrega primeiro arquivo")
  h.anexar(Mensagem(deNEO: true, texto: "resposta sintética"), em: c.id)
  check(Historico(arquivo: ch).conversa(c.id)?.mensagens.count == 2, "histórico atualiza arquivo existente")
  h.excluir(c.id);check(Historico(arquivo: ch).conversas.isEmpty, "exclusão persiste")
  let cm = pasta.appendingPathComponent("memoria.json")
  let m = Memoria(arquivo: cm)
  let item = m.propor("Prefiro exemplos sintéticos", categoria: .preferencia, conversa: nil, trecho: nil)!
  check(Memoria(arquivo: cm).propostos.first?.conteudo == "Prefiro exemplos sintéticos", "memória proposta persiste sem marcarUso")
  check(Memoria(arquivo: cm).ativos.isEmpty, "proposta permanece sem aprovação")
  m.aprovar(item.id);check(Memoria(arquivo: cm).ativos.first?.id == item.id, "aprovação persiste")
  m.suspender(item.id);check(Memoria(arquivo: cm).itens.first?.status == .suspenso, "suspensão persiste")
  let cd = pasta.appendingPathComponent("decisor.json")
  let d = Decisor(arquivo: cd);let qtd = d.exemplos.count
  d.aprender("Uma entrada sintética de aprendizado", classe: .conversa, origem: "validação")
  check(Decisor(arquivo: cd).exemplos.contains { $0.texto == "Uma entrada sintética de aprendizado" && $0.origem == "validação" }, "decisor cria primeiro arquivo e recarrega exemplo")
  d.aprender("Outro exemplo sintético independente", classe: .hora, origem: "validação")
  check(Decisor(arquivo: cd).exemplos.count == qtd + 2, "decisor atualiza arquivo existente")
  print("persistência: \(total-falhas)/\(total) aprovados")
  if falhas > 0 { exit(1) }
 }
}
