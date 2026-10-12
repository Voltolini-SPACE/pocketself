import Foundation
@main struct Tests {
 static func main() {
  let casos: [(String,String)] = [
   ("lista.sorted { $0.nome < $1.nome }", "lista.sorted { $0.nome < $1.nome }"),
   ("echo $HOME", "echo $HOME"),
   ("$0+$1", "$0+$1"),
   ("echo $HOME+$PATH", "echo $HOME+$PATH"),
   ("Preço: R$ 18.166,97", "Preço: R$ 18.166,97"),
   ("Custa $20 e $30", "Custa $20 e $30"),
   ("$M \\approx 10 \\times 2$", "M ≈ 10 × 2"),
   ("$$x^{60}$$", "x^60"),
   ("`$M \\times $0`", "`$M \\times $0`"),
   ("```swift\nlet x = $0\n```", "```swift\nlet x = $0\n```"),
   ("### Resultado\n**Certo**", "Resultado\nCerto"),
   ("Valor $pendente", "Valor $pendente")
  ]
  var falhas=0
  for (entrada, esperado) in casos {
   let obtido=RespostaTexto.limpar(entrada)
   if obtido != esperado { falhas += 1; print("FAIL \(entrada.debugDescription): \(obtido.debugDescription), esperado \(esperado.debugDescription)") }
  }
  print("formatação: \(casos.count-falhas)/\(casos.count) aprovados")
  if falhas > 0 { exit(1) }
 }
}
