# Changelog

## 0.2.0 — 2026-10-12 (primeira versão pública)
- Chamada ao vivo offline em destaque; Reunião (ouvir, transcrever no aparelho com SpeechAnalyzer, notas e resumo); SOS em Morse e GPS sem internet; fidelidade do texto das mensagens; Apple Intelligence como motor; benchmark no aparelho; nova marca, cores e 14 personagens; apresentação, vitrine e copy de marketing.

## Histórico anterior (desenvolvimento)
- Apple Intelligence como motor selecionável (só texto); benchmark no aparelho (`--benchmark=`, Ajustes › Motor › Medir neste iPhone); catálogo sem números de outro aparelho; servidor opcional configurável em Ajustes; Gemma E4B com arquivo completo; medições no iPhone 17 Pro Max e do Edge0 35B em docs/BENCHMARK-IPHONE-17.md.
- Validado no iPhone 17 Pro Max; corrigidos: erro de servidor na 1ª abertura sem modelo, texto de erro no tema escuro, texto de privacidade das boas-vindas. Novo `scripts/capturar-telas.sh`.
- Nova marca (rosto saindo do bolso), cores «Bolso» com 4 destaques e contraste conferido por script; texto respeita o tamanho do sistema.
- 14 espécies, 14 acessórios e 8 objetos; JSON antigo de mascote continua válido.
- Tela inicial do chat com 10 ações rápidas (agenda, lembrete, web, foto, mensagem, música, imagem, outro app, nota, timer).

## 0.1.0 — 2026-10-12 (primeiro corte do repositório)
- Repositório novo e limpo, derivado do app privado NEO: sem personagem, ícone ou dados do autor; mascotes originais por camadas; ícone genérico gerado por `scripts/gerar-icone.py`.
- Bundle padrão `io.github.voltolini-space.pocketself`, sem equipe fixa (`--team`).
- Agente de controle do iPhone local (`agente-iphone/`); ferramenta `controlar_iphone` aponta para `127.0.0.1:14292`; filtro de elementos cobertos por barras.
- Scripts de ambiente, instalação, agente e verificação de dados pessoais; CI.
- Documentação de instalação (manual e por Claude Code/Codex), requisitos, assinatura de 7 dias, Apple Intelligence, funcionalidades e evidências.
- Compila para iOS sem assinatura (Xcode 27) e passa nos testes de lógica no Mac. **Ainda não reinstalado em aparelho.**
