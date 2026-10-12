# AGENTS.md — instruções para IAs de código (Codex e outras)

Projeto: **PocketSelf**, app iOS (SwiftUI + MLX) de agente pessoal local-first. Idioma da documentação e das conversas com o dono: **português do Brasil**.

## Comandos
- Conferir ambiente: `scripts/verificar-ambiente.sh` (só lê).
- Testes de lógica (sem aparelho): `bash tests/testar.sh`.
- Verificar dados pessoais/segredos: `bash scripts/anti-dados-pessoais.sh` (deve passar antes de qualquer commit).
- Compilar sem assinatura: `scripts/instalar-no-iphone.sh --sem-assinatura`.
- Instalar no iPhone: `scripts/instalar-no-iphone.sh --team <TEAM_ID> [--device <UDID>] [--bundle-prefix <prefixo>]`.
- Projeto Xcode é **gerado**: `cd app && xcodegen generate`. Arquivo Swift novo exige regenerar. Não commitar `*.xcodeproj`.

## Regras
1. **Peça o Team ID e o UDID ao usuário**; nunca invente nem leia de outro lugar.
2. **Não apague apps do iPhone** sem autorização explícita, nomeando qual app. Limite da conta gratuita: 3 apps de desenvolvedor.
3. **Não digite senhas**, não entre em contas, não aceite termos pelo usuário.
4. Instalar ferramentas no Mac (brew etc.): avise antes e instale só o necessário.
5. A assinatura gratuita **vale 7 dias**; reinstalar por cima (não desinstalar) preserva dados. Ver `docs/ASSINATURA-7-DIAS.md`.
6. Não criar dados pessoais, UDIDs, IPs privados, tokens ou e-mails no repositório. Tokens ficam em `~/.config/pocketself/` (fora do git).
7. Ação com efeito externo no app (enviar, agendar, ligar, apagar) exige confirmação do usuário na tela; não contorne.
8. Cada mudança de comportamento ganha teste em `tests/` ou `agente-iphone/testes/` e entrada em `docs/FUNCIONALIDADES.md` (status e evidência).
9. Só alegue «validado» com evidência (log, comando e resultado). Distinga: compilou · passou no teste de lógica · rodou no aparelho.

## Mapa
`app/PocketSelf/` app · `app/Pacotes/VozNeural` voz Kokoro (Apache-2.0) · `agente-iphone/` agente XCUITest · `scripts/` · `tests/` · `docs/` · `evidence/` logs reais.
