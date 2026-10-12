#!/bin/bash
# PocketSelf — abre o app no iPhone com argumentos de teste e captura as telas (validação visual sem tocar na tela).
# Requer: app instalado, aparelho desbloqueado, go-ios (`brew install go-ios`). Não captura a aba Agenda de propósito:
# ela abre o pedido de permissão do sistema e pode mostrar eventos pessoais do calendário.
# Uso: scripts/capturar-telas.sh --device <UDID> [--bundle io.github.voltolini-space.pocketself] [--saida evidence/aparelho]
set -euo pipefail
dev=""; bundle="io.github.voltolini-space.pocketself"; saida="evidence/aparelho"
while [ $# -gt 0 ]; do case "$1" in --device) dev="$2"; shift 2;; --bundle) bundle="$2"; shift 2;; --saida) saida="$2"; shift 2;;
  -h|--help) sed -n 2,6p "$0"; exit 0;; *) echo "opção desconhecida: $1" >&2; exit 2;; esac; done
[ -n "$dev" ] || { echo "Informe --device <UDID>." >&2; exit 2; }
mkdir -p "$saida"; export ENABLE_GO_IOS_AGENT=user
pgrep -f "ios tunnel start" >/dev/null || { (nohup ios tunnel start --userspace --udid="$dev" >/dev/null 2>&1 &); sleep 8; }
cap() { n=$1; shift
  xcrun devicectl device process launch --device "$dev" --terminate-existing "$bundle" -- "$@" >/dev/null 2>&1 || { echo "falhou ao abrir ($n)"; return; }
  sleep 5; ios screenshot --udid="$dev" --output="$saida/$n.png" >/dev/null 2>&1 && echo "ok $n" || echo "falhou captura ($n)"
}
# «-chave valor» entra direto no UserDefaults do app (domínio de argumentos); «--x=y» são os argumentos de teste do app.
P=(-agenteConcluido YES -agenteNome Luma -agenteTratamento Ana)
cap 01-boas-vindas --perfil=novo --tema=claro
cap 02-chat-claro --tema=claro --aba=chat "${P[@]}"
cap 03-chat-escuro --tema=escuro --aba=chat "${P[@]}"
cap 04-ajustes-claro --tema=claro --aba=ajustes "${P[@]}"
# Histórico: só capture se não houver conversas pessoais (a tela mostra os títulos); não commite essas capturas.
# cap 05-historico --tema=escuro --aba=historico "${P[@]}"
