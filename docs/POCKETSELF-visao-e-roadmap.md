# PocketSelf — visão e roadmap (decisão do dono, 12/10/2026)

**Nome da ferramenta e do repositório: PocketSelf.** *Your AI. Your Pocket. Your Rules.* / «Sua IA. Seu bolso. Suas regras.»
Agente pessoal que roda direto no celular, preserva as memórias do usuário e evolui com novas inteligências, ferramentas e APIs. Gratuito e de código aberto (MIT).

Este documento registra a visão enviada pelo dono. Onde algo conflita com o que já existe, a coluna «Situação» abaixo diz o que vale; o que não der para usar é descartado.

## Decisões de nome (sem renomeação em massa)
- Nome público (app, repositório, documentação): **PocketSelf**. Pasta de trabalho atual segue `~/Documents/Voltolini/neo` (e `~/AI/neo` na Spark) até uma migração planejada que atualize referências, valide consumidores e preserve recuperação.
- «PocketSelf» passa a ser o **nome interno/legado** do app privado e do personagem original (`Especie.neo`, fora da galeria pública). Bundle `io.github.voltolini-space.pocketself` não muda sem decisão (muda o app instalado, a assinatura e os dados).
- O repositório público MIT sai com o nome PocketSelf e histórico limpo; **publicação só após «sim» do dono** (ver `MISSAO-repositorio-publico.md`).
- Agente sem nome obrigatório: cada pessoa escolhe o nome (já existe em `Perfil.swift`: `Identidade`).

## Os pilares
1. **Live offline** — conversa por voz como ligação: microfone → reconhecimento → LLM local → voz → alto-falante; interrupção natural, legendas, histórico local, sem enviar áudio.
2. **Apple Intelligence como motor selecionável** (Foundation Models) ao lado de LLM local open source e API externa; alternância automática por capacidade; App Intents para Siri/Atalhos.
3. **Memória independente dos modelos** — trocar LLM/API não apaga identidade nem o que o usuário quis guardar.

## Funções
| Função | Resumo | Situação no código hoje |
|---|---|---|
| Chat | conversas, arquivos, fotos, ferramentas | existe (PocketSelf) |
| Live | chamada de voz offline | existe protótipo «Conversa ao vivo»; falta medir latência/interrupção em aparelho real |
| Vision | câmera, objetos, texto, QR/barras (framework Vision + modelo de visão local) | imagem anexada com visão local existe; falta tela de câmera e QR |
| Explore | pesquisa e leitura web (WebKit/Safari Services), fontes e links | ferramenta «Pesquisar na web» existe; falta navegador integrado |
| Identity / My Agent | nome, personalidade, voz, avatar, permissões, memória, autonomia | nome, tratamento e mascote existem; faltam voz, personalidade e autonomia |
| Models | Apple Intelligence, locais, APIs | locais (MLX) e API existem; Apple Intelligence precisa ser ativado pelo dono (imagem hoje `notSupported`) |
| Skills | integrações e permissões | ferramentas internas existem; tela de permissões pendente |
| Memory | SQLite + busca semântica local | memória existe; busca semântica a avaliar |
| Automations | tarefas, lembretes, rotinas | pendente |
| **Controle do iPhone** (extra do projeto) | agente XCUITest no aparelho, laço local | em validação no iPhone 15 Pro (ver `PESQUISA-opcoes-git-iphone.md`) |

**Perfis de autonomia:** Conversar → Assistir → Executar → Autônomo. Ações sensíveis (pagamento, envio de dados privados, exclusão) com barreira própria (já há `Logica.validar` no agente).

**Modos:** Offline (tudo no aparelho) · Híbrido (local + APIs opcionais) · Online. Regra: nunca exigir API externa para iniciar conversa se houver modelo local.

## Componentes candidatos (a validar: integração, desempenho, licença)
llama.cpp · LiteRT-LM · Foundation Models · sherpa-onnx (ASR/TTS/VAD offline) · whisper.cpp · Apple `SpeechTranscriber`/`SpeechAnalyzer` · AVSpeechSynthesizer · Apple Vision/Core ML · App Intents · SQLite. O projeto já usa MLX no iPhone; manter e comparar.

## Pontos incoerentes ou a corrigir na visão (para o dono confirmar ou descartar)
- **Android**: o texto prevê testes em Android; o app atual é só iOS/SwiftUI. Tratar Android como fase futura separada, não promessa desta versão.
- **Nome na marca vs. pasta**: ver «Decisões de nome».
- **«Totalmente offline» + Explore**: pesquisa web exige rede; já descrito no texto, manter o aviso de «pode estar desatualizado» quando offline.
- **Vision**: identificar modelo comercial exato/preço exige base especializada ou web; classificação genérica funciona offline.
- **Naturalidade da voz**: não garantida em todos os aparelhos; só afirmar após medir.
- **Siri/Apple Intelligence**: sem acesso irrestrito à Siri, à memória privada ou a outros apps; só via APIs oficiais.
- **Perfil gratuito de desenvolvedor**: no máximo 3 apps por aparelho.

## Critérios de aceite (teste obrigatório por recurso)
Apple Intelligence responde em aparelho compatível · Live com Wi-Fi e rede móvel desligados · interromper a fala e iniciar outra pergunta · Vision identifica objetos conhecidos sem conexão · Web devolve fontes verificáveis · trocar nome/modelo/voz sem perder memória · adicionar/remover API sem reconstruir o agente. Registrar evidência em `evidence/`.

## Ordem sugerida
1. Fechar a validação do controle do iPhone (em andamento).
2. Medir Live offline (latência, interrupção) no aparelho.
3. Seletor de motor com Apple Intelligence (depende do dono ativar).
4. Tela de câmera/QR; navegador integrado.
5. Perfis de autonomia e tela de permissões.
6. Repositório público PocketSelf (só com «sim»).
