# Arquitetura

```
iPhone (SwiftUI, iOS 18+)
 ├─ Decisor («Decide») ── intenção em ~0,1 ms, probabilidade calibrada ──► escolhe ferramentas e motor
 ├─ Motor ── MLX local (Qwen3.5 / Gemma 4) | servidor OpenAI-compatível («Máximo») | [Apple Foundation Models: roadmap]
 │    └─ Ferramentas: hora/data · aparelho · agenda · lembretes · notas · alarme · timer · memória · web · imagem ·
 │       contatos/mensagem/e-mail/ligação · música · abrir app/Atalho · controlar_iphone · consultar_servidor
 ├─ Voz: Speech (pt-BR no aparelho) + AVSpeech (+ Kokoro CoreML, experimental)
 ├─ Visão: Vision (OCR/classificação) + Gemma 4 (VLM)
 ├─ Identidade: PerfilAgente (nome, tratamento, mascote em pixel art por camadas, 100% em código)
 └─ Dados no app: conversas.json · memoria.json · decisor.json · modelos em Documents/modelos
agente-iphone/ (runner XCUITest no aparelho) ──127.0.0.1:14292──► ferramenta controlar_iphone
```

## Princípios
- **Local primeiro:** nada obrigatório sai do aparelho; servidor e web são opcionais e visíveis.
- **Confirmação para efeito externo:** ferramentas «preparam»; o usuário toca para confirmar; o modelo é instruído a não afirmar que foi feito antes disso.
- **Conteúdo externo é dado, não ordem** (web, e-mails, páginas lidas).
- **Memória independente do motor:** o histórico e a memória aprovada valem para qualquer modelo.
- **Medir antes de afirmar:** só números de `evidence/`.

## Arquivos-chave (`app/PocketSelf/`)
`Motor.swift` (catálogo e carga de modelos) · `Decisor.swift` · `Ferramentas.swift` · `Spark.swift` (cliente do servidor; nome histórico) · `Voz.swift`/`Gravacao.swift` · `Visao.swift` · `Memoria.swift`/`Historico.swift` · `Perfil.swift`/`Onboarding.swift` (identidade e mascote) · `Integracoes.swift` (App Intents) · `ControleIphone.swift` · `Orquestra.swift` (bancada de testes de co-residência de modelos, inclui Apple Foundation Models).
