# Funcionalidades: o que existe e como foi validado

> Auditoria de ferramentas, avisos e entradas, com defeitos, lacunas e roteiro manual de 28 passos: [VALIDACAO-FUNCIONAL.md](VALIDACAO-FUNCIONAL.md). Os logs só provam lembrete, lanterna, timer, abrir app e mensagem; o restante está 🟡 até o roteiro rodar no aparelho.

Atualizado em 2026-10-12. **Níveis de prova** (do mais fraco ao mais forte): `C` compila · `T` passa em teste de lógica no Mac · `A` rodou no aparelho com log · `U` uso real acompanhado. Só chamamos de ✅ o que tem `A` ou mais. Logs em `evidence/logs-aparelho-2026-10/` (coletados no app privado que originou o projeto, em 10–12/10/2026; o app público foi recompilado e passou nos testes de lógica, mas **ainda não foi reinstalado em aparelho**).

| Área | Funcionalidade | Estado | Prova | Evidência / observação |
|---|---|---|---|---|
| Conversa | Chat local (Qwen3.5 4B/9B, Gemma 4 E2B/E4B) | ✅ | A | `dialogo-voz.log`: 17,8 tok/s, 1ª palavra 274–289 ms com cache; `qwen9b-iphone17.log` |
| Conversa | Troca de motor sem perder histórico | ✅ | A | `integracoes-2.log` |
| Conversa | Modo «Máximo» (servidor próprio) | ✅ | A | `spark-maximo.log`: 151–179 ms 1ª parte, ~39 partes/s (medidas históricas, não garantia) |
| Voz | Falar ao vivo, interrupção por voz | ✅ | A | `kokoro-2.log`; primeira frase 0,6–1,4 s |
| Voz | Reconhecimento pt-BR no aparelho + voz do sistema | ✅ | A | `Gravacao.swift`/`Voz.swift` |
| Voz | Voz neural Kokoro (pt-BR) | 🟡 | A | sotaque ainda irregular; experimental |
| Decisão | «Decide» (Naive Bayes + n-gramas + temperatura calibrada) | ✅ | T+A | `decide.log`; testes `PersistenciaTests`; ECE 0,04–0,15 conforme o treino |
| Agenda | Calendário e lembretes (só com confirmação) | 🟡 | A | `verificacao-ferramentas.log`, `decide.log` |
| Notas | Notas e alarme por Atalho; timer; lanterna; brilho | 🟡 | A | `apps.log` |
| Web | Pesquisar e ler páginas (conteúdo = dado) | ✅ | A | `web.log` |
| Visão | OCR e classificação (Vision) | ✅ | A | `visao-2.log` |
| Visão | Gemma 4 descrevendo imagens | ✅ | A | `gemma-visao.log` (~9,5 s) |
| Visão | QR/código de barras, câmera dedicada («Vision») | 🔲 | — | roadmap |
| Imagem | Criar imagem (Image Playground) | ✅* | A | 5,1 s no 17 Pro Max com Apple Intelligence ligado (`benchmark-17/imagem-apple-intelligence-ativo.log`). *Sem ele: «não suporta» |
| Contatos | Buscar contato, mensagem, e-mail, ligação (confirmação) | 🟡 | A | `integracoes-2.log` |
| Música | Tocar/buscar (Apple Music local, Spotify por URL) | ✅ | A | `spotify-2.log` |
| Atalhos | App Intents: Perguntar · Ao vivo · Pesquisar · Criar imagem | ✅ | A | criados; botão de Ação é do usuário |
| Memória | O app propõe, o usuário aprova; vale para todos os motores | ✅ | T+A | `PersistenciaTests` |
| Histórico | Conversas persistidas, exportar/apagar | ✅ | T | `PersistenciaTests` |
| Identidade | Nome, tratamento, mascote (14 espécies × 8 cores × 14 acessórios × 8 objetos × 4 expressões) | 🟡 | T+C | ~50 mil combinações válidas em teste; folha de contato conferida no Mac; **validação visual no aparelho pendente** — [MARCA.md](MARCA.md) |
| Visual | Nova marca, cores «Bolso» (4 destaques), cartões de ações rápidas no chat | 🟡 | T+C | contraste WCAG conferido por script (`verificar-contraste.py`); layout **ainda não visto em aparelho** |
| Controle | Agente XCUITest no iPhone (ver, decidir, agir em qualquer app) | 🟡 | A | tarefa «Ajustes › Geral › Sobre» concluiu no iPhone 17 Pro Max; no 15 Pro corrigimos o toque sob a barra de busca (teste de lógica 12/12), repetição no aparelho pendente — [CONTROLE-DO-IPHONE.md](CONTROLE-DO-IPHONE.md) |
| Controle | Barreira de irreversíveis (enviar, pagar, excluir, senha) | ✅ | T+A | `Logica.validar`; bloqueio validado ao vivo |
| Apple | Foundation Models como motor selecionável | ✅ | A | iPhone 17 Pro Max: 1ª palavra 0,74 s no chat; [APPLE-INTELLIGENCE.md](APPLE-INTELLIGENCE.md) |
| Resgate | Sinal de SOS em Morse pela lanterna; localização por GPS sem internet | ✅ | T+A | iPhone 17: SOS 5× (~42 s); GPS ±8 m; `tests/ResgateTests.swift` |
| Fidelidade | Mensagem/e-mail usam as palavras exatas do usuário quando o modelo as altera («chego»→«cheiro») | ✅ | T+A | `tests/FidelidadeTests.swift`; cena 38 no aparelho |
| Apple | Ferramentas no motor Apple Intelligence (as mesmas do app, com as mesmas confirmações) | 🟡 | C | ponte `FerramentaApple` (esquema dinâmico); compila; validação no aparelho pendente |
| Desempenho | Benchmark no aparelho (`--benchmark=` / Ajustes) e catálogo sem números de outro aparelho | ✅ | A | [BENCHMARK-IPHONE-17.md](BENCHMARK-IPHONE-17.md) |
| Motor | Edge0 35B (app à parte, MoE com streaming de SSD) | 🟡 | A | 9,1 tok/s no 17 Pro Max; não embutido (exige ~20 GB livres) |
| Reunião | Escuta contínua, transcrição longa no aparelho (SpeechAnalyzer, iOS 26), notas a cada minuto (pontos, decisões, tarefas, dúvidas), resumo final, salvar e compartilhar em Markdown | 🟡 | T+A | iPhone 17: áudio de 75 s transcrito no aparelho em 4,4 s (122 palavras, `evidence/reuniao/`); notas e resumo pelo motor e escuta ao vivo **ainda sem validação no aparelho** (o aparelho estava em uso); `tests/ReuniaoTests.swift` 13/13 |
| Autonomia | Perfis Conversar/Assistir/Executar/Autônomo | 🔲 | — | roadmap |
| Web | Navegador integrado | 🔲 | — | roadmap |
| Android | — | 🔲 | — | fora do escopo da v1 |

## Validação em aparelho do app público (2026-10-12, iPhone 17 Pro Max, iOS 26.6)
Instalado pelo `scripts/instalar-no-iphone.sh` (assinatura gratuita, bundle `io.github.voltolini-space.pocketself`), aberto e capturado por `scripts/capturar-telas.sh` — capturas em `evidence/aparelho-17-2026-10-12/` (sem dados pessoais).
- ✅ Instalar e abrir pelo cabo; boas-vindas, Chat (claro/escuro), Ajustes: layout, nova marca e cores renderizam como projetado; nome e tratamento do agente aparecem no placeholder, na saudação e em «Meu agente».
- ✅ A Agenda pede a permissão do sistema com o nosso texto de uso (verificado; não captura para não expor o calendário).
- 🔧 **Defeito achado só no aparelho e corrigido:** sem nenhum modelo copiado, o app escolhia o servidor opcional («Spark») e mostrava «A Spark não respondeu… túnel no Mac» já na abertura. Agora orienta a copiar um modelo (docs/MODELOS.md).
- 🔧 Texto de erro em vermelho ficava ilegível no tema escuro: criado `perigoTexto` (≥ 4,5:1, conferido por script).
- 🔧 Boas-vindas dizia «sem enviar nada para a internet»: corrigido (pesquisa na web e servidor opcional usam rede).
- 🟡 Ainda **sem modelo no aparelho**: conversa, voz ao vivo, visão e ferramentas dependentes do modelo seguem sem validação em aparelho neste app público.

## Testes automáticos no Mac (`bash tests/testar.sh`)
Cliente do servidor (SSE, ferramentas, cancelamento) · formatação de texto · contexto de resposta · persistência de histórico/memória/decisor · validação isolada · perfil e mascotes · lógica do agente (12). Última execução completa: 2026-10-12, todos aprovados.

## Compilação
`evidence/2026-10-12-build-ios-sem-assinatura.log` (app) e `…-build-agente-sem-assinatura.log` (agente): `BUILD SUCCEEDED` / `TEST BUILD SUCCEEDED` com Xcode 27, sem assinatura.

## Pendências de validação do app público
1. Instalar o app público (bundle novo) num aparelho e repetir as rotinas dos logs acima.
2. Validar a tela de boas-vindas/mascote por captura no aparelho.
3. Repetir a tarefa do agente no iPhone 15 Pro.
