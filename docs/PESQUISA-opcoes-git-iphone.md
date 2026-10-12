# Pesquisa — opções no GitHub para o PocketSelf no iPhone (12/10/2026)

Objetivo: ver o que existe pronto para Mac/PC que dá para converter para o iPhone e aprimorar o PocketSelf.
Só fatos lidos nas páginas; licenças a reconferir antes de reutilizar código.

## Frente 1 — Controle do iPhone por IA
| Projeto | O que faz | Licença | Aproveitável |
|---|---|---|---|
| leeguooooo/iphone-use | MCP em Rust + runner XCTest próprio no aparelho, servidor HTTP com token por execução; USB ou **Wi-Fi** (túnel cifrado após configuração por cabo); espera a tela assentar antes de responder | PolyForm Shield (código aberto-visível, não OSI; proíbe produto concorrente) | **Ideias**: Wi-Fi após setup, «esperar tela assentar». Não copiar código. |
| lycorp-jp/sim-use | Lê acessibilidade de aparelho físico pelo daemon de auditoria via usbmux, sem runner nem assinatura | a conferir | Alternativa ao runner; ainda precisa de host |
| minitap-ai/mobile-use | Agente multi-nó; iOS só em simulador | Apache-2.0 | Modelo por nó, endpoint compatível OpenAI, saída estruturada |
| callstack/agent-device | CLI/MCP/API para iOS, Android etc. | MIT | Comandos e API tipada de referência |
| TonyWu2333/iphone-harness | Appium/XCUITest + aprendizado de «skills» por app | a conferir | Ideia de memória por app |

Conclusão: **ninguém roda 100% dentro do iPhone** — todos dependem de um host com Xcode ou usbmux. A nossa arquitetura (laço no runner do aparelho, host só mantém a sessão) é a mesma linha, com laço local.

## Frente 2 — Motor local no iPhone
- ml-explore/mlx-swift-lm (biblioteca MLX), llama.cpp `llama.swiftui`, tattn/LocalLLMClient (GGUF + MLX numa API), rudrankriyam/Foundation-Models-Framework-Example e -Lab (Apple Foundation Models, @Generable).
- Aprimorar: **saída estruturada** (@Generable / gramática) para as ações do agente reduz JSON inválido.

## Frente 3 — Reunião
- Apple SpeechAnalyzer (iOS 26) é ~55% mais rápido que Whisper large-v3 em teste da MacStories; WhisperKit (argmaxinc) como alternativa com timestamps por palavra. TypeWhisper (código aberto, iOS em beta) tem transcrição ao vivo. Nenhum app aberto reúne transcrição + notas + resumo no aparelho.

## Decisões / próximos passos
1. Visão: já ligada no agente (screenshot 480 px + lista); tarefa «Geral › Sobre» concluiu em 3 passos.
2. Medir **sem cabo (Wi-Fi)** a sessão host — referência: iphone-use.
3. Adicionar «esperar tela assentar» no laço antes de ler a árvore.
4. Testar saída estruturada para as ações.
5. Reunião: protótipo com SpeechAnalyzer; WhisperKit como reserva.
