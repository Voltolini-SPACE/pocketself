# PocketSelf — apresentação completa

> **Your AI. Your Pocket. Your Rules.** · Sua IA. Seu bolso. Suas regras.
> Todas as telas abaixo são **capturas reais** do app público rodando num iPhone 17 Pro Max (iOS 26.6), em 12/10/2026, geradas por `scripts/roteiro-apresentacao.py`. Versão em slides: [apresentacao/index.html](apresentacao/index.html).

## 1. O que é
Um agente pessoal de IA que **mora no seu iPhone**: conversa por voz e texto, entende fotos, pesquisa na web, cuida de agenda e lembretes, guarda só as memórias que você aprovar, e pode operar outros apps. Gratuito, código aberto (MIT), sem conta, sem assinatura. Cada pessoa cria o **seu** agente.

## 2. Primeiro uso: monte o seu agente
| Boas-vindas | Nome e tratamento | Montador de mascote |
|---|---|---|
| ![](../evidence/apresentacao/01-onboarding-boas-vindas.jpg) | ![](../evidence/apresentacao/02-onboarding-nome.jpg) | ![](../evidence/apresentacao/03-onboarding-montador-inicial.jpg) |

**14 personagens, 14 acessórios e 8 objetos para segurar**, 8 cores e 4 expressões (~50 mil combinações):

| Raposa + chapéu de bruxo + livro | Robô + óculos + café | Coruja + cachecol + plantinha | Pinguim + gravata + balão | Polvo + coroa + coração |
|---|---|---|---|---|
| ![](../evidence/apresentacao/04-montador-raposa-bruxo-livro.jpg) | ![](../evidence/apresentacao/05-montador-robo-oculos-cafe.jpg) | ![](../evidence/apresentacao/06-montador-coruja-cachecol-planta.jpg) | ![](../evidence/apresentacao/07-montador-pinguim-gravata-balao.jpg) | ![](../evidence/apresentacao/08-montador-polvo-coroa-coracao.jpg) |

![Elenco](marca/personagens.png)

## 3. Ligue para a sua IA — chamada ao vivo, offline
Toque em «Falar ao vivo» e converse como numa ligação. A fala é reconhecida no iPhone, a resposta é gerada pelo modelo local e a voz é sintetizada no aparelho — nada vai à internet. E para reuniões, a ação «Reunião» ouve, transcreve, organiza e resume, também no aparelho.

| Chamada ao vivo | Ação «Reunião» no chat |
|---|---|
| ![](../evidence/apresentacao/45-ao-vivo-chamada.jpg) | ![](../evidence/apresentacao/46-chat-acao-reuniao.jpg) |

## 3b. O chat e as ações rápidas
Tela inicial com **10 ações rápidas** (agenda, lembrete, web, foto, mensagem, música, imagem, outro app, nota, timer), nos temas claro e escuro, com a marca nova e a cor de destaque escolhida pelo usuário.

| Claro | Ações rápidas | Escuro |
|---|---|---|
| ![](../evidence/apresentacao/10-chat-inicio-claro.jpg) | ![](../evidence/apresentacao/11-chat-acoes-rapidas.jpg) | ![](../evidence/apresentacao/12-chat-inicio-escuro.jpg) |

## 4. O que o agente faz (provado no aparelho)
| Hora e data | Estado do aparelho | Lanterna |
|---|---|---|
| ![](../evidence/apresentacao/30-chat-hora-data.jpg) | ![](../evidence/apresentacao/31-chat-bateria.jpg) | ![](../evidence/apresentacao/32-chat-lanterna-ligar.jpg) |
| «Que horas são e que dia é hoje?» → hora e data corretas, decisão em 0,1 ms | bateria e memória livre do aparelho | a ferramenta liga a lanterna de verdade |

| Pesquisa na web (com rede) | Memória que você aprova | Apple Intelligence |
|---|---|---|
| ![](../evidence/apresentacao/34-chat-web-sem-internet.jpg) | ![](../evidence/apresentacao/36-chat-memoria.jpg) | ![](../evidence/apresentacao/39-chat-apple-intelligence.jpg) |
| fonte citada; o conteúdo da web é tratado como dado, nunca como ordem | o app **propõe**, você **aprova** («Guardar» / «Não guardar») | motor nativo da Apple, no aparelho e sem download |

| Criar imagem (Apple Intelligence) | Lembrete com confirmação | Mensagem com confirmação |
|---|---|---|
| ![](../evidence/apresentacao/35-chat-criar-imagem.jpg) | ![](../evidence/apresentacao/37-chat-lembrete.jpg) | ![](../evidence/apresentacao/38-chat-mensagem-confirmacao.jpg) |
| gerada no aparelho em segundos | o lembrete só é gravado depois do seu toque | o texto vai **exatamente** como você escreveu (proteção contra o modelo trocar palavras) |

**Honestidade na ação:** com o motor Apple Intelligence (só texto) um pedido de ação recebe um aviso claro em vez de uma promessa falsa:

![](../evidence/apresentacao/40-chat-apple-pedido-de-acao.jpg)

## 5. Ajustes: tudo configurável
| Visão geral | Meu agente | Aparência (4 destaques, claro/escuro) |
|---|---|---|
| ![](../evidence/apresentacao/13-ajustes.jpg) | ![](../evidence/apresentacao/14-ajustes-meu-agente.jpg) | ![](../evidence/apresentacao/16-ajustes-aparencia.jpg) |

| Voz e áudio | Motor de IA com benchmark | Controle do iPhone |
|---|---|---|
| ![](../evidence/apresentacao/17-ajustes-voz.jpg) | ![](../evidence/apresentacao/18-ajustes-motor.jpg) | ![](../evidence/apresentacao/15-ajustes-controle.jpg) |

| Integrações | Memória | Sobre |
|---|---|---|
| ![](../evidence/apresentacao/20-ajustes-integracoes.jpg) | ![](../evidence/apresentacao/21-ajustes-memoria.jpg) | ![](../evidence/apresentacao/23-ajustes-sobre.jpg) |

![PocketSelf Decide](../evidence/apresentacao/19-ajustes-decide.jpg)

## 6. Motores e desempenho (medido no aparelho)
O app mede cada motor no próprio iPhone (**Ajustes › Motor › Medir neste iPhone**). No 17 Pro Max: Gemma 4 E2B **47,7 tok/s**, Qwen3.5 4B **26,1**, Gemma 4 E4B **23,4**, Qwen3.5 9B **14,4**; Apple Intelligence responde em ~0,3 s (quente); Edge0 35B (app à parte) **9,1 tok/s**. Detalhes: [BENCHMARK-IPHONE-17.md](BENCHMARK-IPHONE-17.md).

## 7. Privacidade e segurança
Sem conta, sem telemetria. Ação com efeito externo (mensagem, evento, ligação) só depois do seu toque. O agente de controle **para** diante de enviar, pagar, excluir, publicar e senha. Detalhes e limites honestos: [SECURITY.md](../SECURITY.md) e [VALIDACAO-FUNCIONAL.md](VALIDACAO-FUNCIONAL.md).

## 8. Sem sinal, sem problema (novo)
Ferramentas que funcionam **sem internet**, validadas no iPhone 17 Pro Max: **sinal de SOS em luz** (a lanterna pisca ··· −−− ··· — 5 repetições em ~42 s), **localização por GPS** (coordenadas com precisão de ±8 m; captura não publicada porque mostra um local real), **brilho** e **timer**.

| SOS com a lanterna | Pouca bateria: brilho em 10% |
|---|---|
| ![](../evidence/apresentacao/42-chat-sos-lanterna.jpg) | ![](../evidence/apresentacao/43-chat-bateria-brilho.jpg) | Base do comercial: [comercial/ROTEIRO-SEM-SINAL.md](comercial/ROTEIRO-SEM-SINAL.md).

## 9. Como começar
[INSTALACAO.md](INSTALACAO.md) (manual) · [INSTALACAO-COM-IA.md](INSTALACAO-COM-IA.md) (Claude Code ou Codex) · assinatura gratuita vale 7 dias: [ASSINATURA-7-DIAS.md](ASSINATURA-7-DIAS.md).

## 10. O que ainda falta
Reunião (escuta, notas e resumo), perfis de autonomia, navegador integrado, ferramentas no motor Apple Intelligence, receber arquivos de fora (PDF, `.ics`, `.vcf`, QR). Ver [POCKETSELF-visao-e-roadmap.md](POCKETSELF-visao-e-roadmap.md).
