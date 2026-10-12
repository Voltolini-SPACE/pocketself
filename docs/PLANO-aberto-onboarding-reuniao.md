# Plano — versão aberta: montar o agente + função Reunião

Pedido do dono em 12/10/2026. Complementa `MISSAO-repositorio-publico.md` (publicar só após "sim").

## 1. Telas iniciais: montar o seu agente
Fluxo no primeiro uso (e reabrível em Ajustes):
1. **Boas-vindas** — o que o app faz; tudo roda no aparelho.
2. **Nome do agente** — campo livre (padrão sugerido: "PocketSelf"); passa a valer em prompts, saudação, voz e atalhos.
3. **Mascote** — galeria de personagens fofos em pixel art (grade com várias opções) + montador
   (corpo, cor, acessório, expressão). Cada opção é um `Sprite` 62×97 e um `Avatar` 41×39 gerados de camadas.
4. **Seu perfil** — como quer ser chamado e preferências (opcional, vira memória aprovada).
5. **Motor** — escolher modelo local compatível com o aparelho (9B só em 12 GB; E4B/E2B nos de 8 GB).

Implementação:
- `PerfilAgente` (nome, mascote, tratamento) em `UserDefaults`/JSON; sem "Voltolini" fixo em lugar nenhum
  (hoje `Memoria.textoParaInstrucoes` e os cabeçalhos fixam o nome do dono → trocar por `perfil.tratamento`).
- `Mascote` como camadas em `Assets.xcassets` + `MontadorMascote` (SwiftUI); `Sprite`/`Avatar` passam a ler do perfil.
- Arte: criar/gerar um conjunto original (licença MIT/CC0). Não reutilizar o personagem do dono.

## 2. Função "Reunião" — viabilidade
Objetivo: escuta aberta, anotando, organizando e resumindo, tudo no aparelho.

**Viável.** Peças:
| Peça | Como | Observação |
|---|---|---|
| Transcrição contínua | `SpeechAnalyzer`/`SpeechTranscriber` (iOS 26+, no aparelho, feito para longa duração, existe no SDK) | alvo do app é iOS 18: usar `#available(iOS 26)`; abaixo disso, `SFSpeechRecognizer` reiniciando a tarefa por segmentos (já usado em `Gravacao.swift`) |
| Quem falou | sem diarização nativa confiável; v1 marca só os trechos; v2 avalia modelo de diarização | declarar a limitação |
| Anotar/organizar | a cada N minutos o texto novo vai ao motor local: pontos-chave, decisões, tarefas (responsável/prazo), dúvidas | 9B (~14 tok/s) dá conta em blocos; o E4B é mais leve |
| Resumo final | ao encerrar: resumo, decisões, pendências, próximos passos; exportar texto/Notas/Arquivos | ferramentas `nota`/`agenda` já existem |
| Tela bloqueada | exige `UIBackgroundModes: audio` + sessão de áudio ativa | hoje a regra é "sem escuta em segundo plano"; decisão do dono |
| Memória/energia | transcrever + LLM juntos pesam; alternar (transcreve, e processa em pausas) | medir no 17: temperatura, bateria, pico de memória |
| Privacidade | indicador de gravação sempre visível; aviso para avisar os participantes (leis de gravação variam); nada sai do aparelho; apagar tudo com um toque | texto do aviso no onboarding |

Proposta de interface: aba/atalho "Reunião" → título, **Iniciar** → transcrição ao vivo + "Notas" (pontos, decisões, tarefas) → **Encerrar** → resumo editável → salvar/exportar.

Plano de validação (pelo cabo, no 17, sem voz humana na primeira rodada: áudio reproduzido do Mac):
1. Protótipo `Reuniao.swift` com `SpeechAnalyzer`; teste com áudio de 10 min em pt-BR → taxa de palavras, latência, memória.
2. Ciclo de notas com o 9B e com o E4B; medir tempo por bloco e qualidade (conferir contra roteiro conhecido).
3. Teste de 60 min: bateria, temperatura, estabilidade; tela travada só com a decisão do dono.
4. Registrar números neste diário.

## 3. Ordem sugerida
1. `PerfilAgente` + remover nome fixo (base para o público).
2. Onboarding + galeria/montador de mascotes.
3. Protótipo de Reunião e medições.
4. Verificação anti-dado-pessoal e repositório limpo (só publicar após "sim").
