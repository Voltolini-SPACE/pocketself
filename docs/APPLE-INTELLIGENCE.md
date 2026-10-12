# Apple Intelligence no PocketSelf

Resumo honesto do que existe hoje, o que foi medido e o que falta.

## Já usado hoje
| Recurso | Como | Estado |
|---|---|---|
| **Criar imagem** | `ImagePlayground` / `ImageCreator` (iOS 18.4+), estilo ilustração/animação | ✅ 5,1 s no iPhone 17 Pro Max com Apple Intelligence ligado; ~10 s em outro aparelho (`evidence/`) |
| **Atalhos / Siri** | `App Intents`: «Perguntar», «Conversar ao vivo», «Pesquisar», «Criar imagem» | ✅ criados; botão de Ação é configuração do usuário |
| **Vision** (OCR, classificação) | framework `Vision`, no aparelho | ✅ `visao-2.log` |

## Requisitos para criar imagem
Aparelho compatível (iPhone 15 Pro ou mais novo; ver a lista da Apple), **Apple Intelligence ligado** em Ajustes › Apple Intelligence e Siri, idioma suportado e modelos baixados pelo sistema. No iPhone 17 Pro Max **sem** Apple Intelligence ligado o app respondeu «Geração de imagem indisponível: este aparelho não suporta» (`imagem-iphone17-sem-apple-intelligence.log`). Ligar é ação do usuário; o app não consegue ligar.

## Modelo de linguagem nativo (Foundation Models) — agora é um motor do app
Em **Ajustes › Motor de IA › Apple Intelligence** (iOS 26+, Apple Intelligence ligado). Sem download; o app libera o motor MLX antes de usá-lo, porque os dois não cabem juntos na memória (confirmado: com o Qwen 4B residente o teste de co-residência recusou o segundo motor, `livre=1325 MB`).

Validado no iPhone 17 Pro Max (iOS 26.6.1, Apple Intelligence ligado), `evidence/benchmark-17/`:
- disponibilidade `available`; resposta de chat sobre juros compostos: 1ª palavra 0,74 s, 4 atualizações (`chat-apple-intelligence.log`);
- benchmark: 1ª palavra 1,04 s a frio e 0,27 s a quente, ~32 MB de memória do app (`pocketself-apple.log`); a Apple entrega *atualizações cumulativas*, então não há tok/s comparável;
- criar imagem com o Apple Intelligence ligado: gerada em 5,1 s (`imagem-apple-intelligence-ativo.log`; antes de ligar: «este aparelho não suporta»).

**Ferramentas (novo, em validação):** o motor Apple passa a receber as mesmas ferramentas dos motores locais (lembrete, agenda, mensagem, lanterna, SOS, GPS…), convertidas para `Tool` do Foundation Models com esquema dinâmico, e com as mesmas confirmações na tela. Se ele não chamar a ferramenta num pedido de ação, o app avisa «nada foi preparado». A sessão é nova a cada turno (o histórico recente vai no prompt). Falta: ferramentas pelo framework (`Tool`), alternância automática por capacidade e uso de `@Generable` para saída estruturada.

## Limites que não mudamos
O PocketSelf **não** acessa a Siri, a memória privada do Apple Intelligence nem outros apps além das APIs e permissões oficiais. Ele integra por App Intents/Atalhos e Foundation Models quando disponíveis.

## Como validar no seu aparelho
1. Ajustes › Apple Intelligence e Siri › ligar e aguardar o download.
2. No app: «Crie uma imagem de um farol ao entardecer». Esperado: imagem no chat em ~10 s.
3. Sem Apple Intelligence: resposta de indisponibilidade (comportamento esperado, não é falha do app).
