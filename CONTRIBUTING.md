# Contribuir com o PocketSelf

Obrigado! Idioma: português do Brasil (código e identificadores podem ficar no original).

1. Fork → branch curta (`feat/…`, `fix/…`).
2. `bash tests/testar.sh` e `bash scripts/anti-dados-pessoais.sh` precisam passar.
3. Toda mudança de comportamento: teste em `tests/` (ou `agente-iphone/testes/`) e linha em `docs/FUNCIONALIDADES.md` com o **nível de prova** (C/T/A/U) — não escreva «validado» sem evidência.
4. Nada de dados pessoais, UDID, IP privado, tokens, capturas de conversas reais. Evidências: logs sintéticos.
5. `*.xcodeproj` não vai ao git (use `xcodegen`).
6. Commits pequenos, mensagem no imperativo, em português.
7. Segurança de ação: não remova confirmações nem a barreira de irreversíveis do agente.

Dúvidas e ideias: abra uma issue. Vulnerabilidades: veja [SECURITY.md](SECURITY.md).
