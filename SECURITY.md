# Segurança

- **Relatar vulnerabilidade:** abra um *security advisory* privado no GitHub do repositório (Security › Report a vulnerability). Não publique detalhes antes da correção.
- **Modelo de ameaça resumido:** conteúdo externo (web, mensagens) é tratado como dado; ações com efeito externo exigem confirmação na tela; o agente de controle recusa enviar/pagar/excluir/publicar/digitar senha e só aceita requisições com token em loopback (`127.0.0.1:14292`).
- **Segredos:** o token do agente fica em `~/.config/pocketself/agente.token` (0600), fora do git. `scripts/anti-dados-pessoais.sh` bloqueia chaves e dados pessoais no repositório.
- **Servidor opcional:** o contexto da conversa vai para o servidor que você configurar; use equipamento seu.
