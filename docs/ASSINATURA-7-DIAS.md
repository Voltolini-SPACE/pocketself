# A licença de 7 dias (conta gratuita da Apple)

## O que acontece
Apps instalados com um **Apple ID gratuito** (Personal Team) são assinados com um perfil de provisionamento que **expira em 7 dias**. Depois disso o ícone continua lá, mas o iOS recusa abrir o app. Com a conta paga do Apple Developer Program a validade é de 1 ano.

Isto vale para qualquer app instalado direto pelo Xcode, não é um limite do PocketSelf.

## Como renovar (grátis, ~1–3 min)
1. Conecte o iPhone pelo cabo, desbloqueado.
2. Rode de novo o mesmo comando de instalação:
   ```bash
   scripts/instalar-no-iphone.sh --team SEU_TEAM_ID
   ```
   O script recompila, reassina e reinstala **por cima**. Histórico, memória, decisões e modelos copiados ficam (o app não é desinstalado).
3. Anote a data: o novo prazo é 7 dias a partir da instalação.

> **Nunca apague o app** para «reinstalar»: isso apaga os dados e os modelos. Instale por cima.

## Lembrete automático (opcional)
Crie um lembrete recorrente no app Lembretes/Calendário a cada 6 dias, ou um agendamento no Mac:
```bash
# exemplo: avisar no Mac todo dia 06 às 09:00 (adapte)
( crontab -l 2>/dev/null; echo '0 9 */6 * * osascript -e "display notification \"Renove o PocketSelf (7 dias)\" with title \"PocketSelf\""' ) | crontab -
```

## Limites relacionados da conta gratuita
- Máx. **3 apps** de desenvolvedor por iPhone (PocketSelf + agente de controle = 3).
- Limite semanal de **novos App IDs**: reutilize sempre o mesmo `--bundle-prefix`.
- Cada app extra instalado por esta via consome uma vaga; remova o que não usa.

## Alternativas (não validadas por este projeto)
- **Conta paga** (Developer Program): 1 ano de validade, TestFlight.
- **Renovadores de terceiros** (AltStore/SideStore): renovam por Wi-Fi. Não os testamos; avalie os riscos de cada ferramenta.

## Como saber quando vence
Ajustes › Geral › VPN e Gerenciamento de Dispositivo › seu Apple ID: mostra o perfil. Se o app não abre e pede «Confiar», é o prazo ou a confiança — rode o script.
