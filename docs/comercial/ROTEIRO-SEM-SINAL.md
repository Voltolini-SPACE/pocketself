# Comercial «SEM SINAL» — roteiro e storyboard (60 s)

**Conceito:** quando a rede some, a sua IA continua — e **atende a sua ligação**. O coração do filme é a **chamada de voz ao vivo totalmente offline**: Ana fala com o agente como numa ligação, em modo avião. Uma mulher naufraga numa ilha deserta, sem sinal, e usa o PocketSelf (que roda no próprio iPhone) para se orientar, organizar a sobrevivência e pedir resgate.
**Tom:** cinematográfico, quente, esperançoso; protagonista capaz, carismática e elegante (sem sensualização). Formato 16:9 (e corte 9:16), trilha orquestral crescente, som direto de ondas/vento.
**Verdade antes de tudo:** cada cena de tela usa uma função que existe no app. O que o app faz offline: conversa com modelo local, hora/bateria/brilho, timer, lanterna e **sinal de SOS em Morse**, **localização por GPS** (funciona sem internet), lembretes. Aviso final obrigatório: «Cena fictícia. A IA pode errar; em emergência real, acione as autoridades.»

## Personagem
**Ana**, 30 e poucos, exploradora de veleiro. Cabelos molhados e presos, camisa de linho rasgada, shorts de caminhada; pele queimada de sol, olhar determinado. Não é vítima: é protagonista.

## Cenas
| # | Tempo | Imagem | Som / fala | Tela do app (real) |
|---|---|---|---|---|
| 1 | 0–5 s | Aurora. Mar calmo, destroços de um veleiro na praia. Ana acorda na areia, respira fundo. Plano aberto → plano médio. | Ondas, gaivotas, trilha mínima. | — |
| 2 | 5–9 s | Close no iPhone: «Sem serviço», modo avião. Ela acha uma sombra e abre o PocketSelf. | Piano entra. | Ícone do app / chat inicial (`10-chat-inicio-claro`) |
| 3 | 9–16 s | Ana toca em «Falar ao vivo»: a tela de chamada se abre com o ícone de modo avião visível; ela fala com o celular junto ao rosto, como numa ligação. | ANA: «Estou numa ilha. Sem sinal. E agora?» AGENTE (voz calma): «Calma, Ana. Eu funciono sem internet. Vamos em ordem: segurança, água, abrigo e sinal.» | Chat com pergunta e resposta (cena gravada no 17) |
| 4 | 16–24 s | Montagem: abrigo de folhas, coco, filtragem, fogueira pequena. Relógio de sol. | AGENTE (off): «Verifique a fogueira a cada 30 minutos. Eu aviso.» | Timer criado (`timer`) |
| 5 | 24–31 s | Penhasco ao entardecer. Ana segura o celular no alto. | ANA: «Onde eu estou?» AGENTE: «Pelo GPS: …°S, …°O. Anote estas coordenadas.» | Resposta de `minha_localizacao` |
| 6 | 31–38 s | Noite. Bateria baixa. Ela baixa o brilho, aperta o celular contra o peito. | AGENTE: «Bateria em 14%. Reduzi o brilho. Guarde para o sinal.» | Bateria + brilho (`31-chat-bateria`) |
| 7 | 38–48 s | Praia à noite, fogueira. Ana aponta a lanterna do celular para o horizonte: pisca em SOS (··· −−− ···). Luz atravessa a escuridão. | AGENTE: «Sinalizando SOS com a lanterna.» Trilha cresce. | `sinalizar_sos` |
| 8 | 48–54 s | No horizonte, luzes de um barco/helicóptero respondem. Ana ri e chora, acena. | Motor ao longe, vento, trilha explode. | — |
| 9 | 54–60 s | Fecho sobre o mar ao amanhecer; o celular na mão dela. Logo sobe. | Voz: «Sua IA. Seu bolso. Suas regras.» | Logo animada |

## Texto na tela
- 00:55 **PocketSelf** (logo)
- **Ligue para a sua IA. Mesmo sem sinal.** · Código aberto · github.com/Voltolini-SPACE/pocketself (somente após a publicação)
- Rodapé: «Cena fictícia. A IA pode errar; em emergência real, acione as autoridades.»

## Trilha e voz
Trilha orquestral original ou livre de direitos. Voz do agente: pt-BR neutra, calma (TTS local). Ana: dublagem humana quando possível.

## Entregas
`comercial-sem-sinal-16x9.mp4`, `-9x16.mp4`, versão de 30 s, capa e roteiro.
