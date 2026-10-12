#!/bin/bash
# PocketSelf — liga o agente de controle do iPhone (runner XCUITest que roda NO aparelho).
# O Mac só mantém a sessão do Xcode viva; o laço (ver tela → decidir → agir) roda no iPhone e fala com um
# modelo OpenAI-compatível (com visão, de preferência). Veja docs/CONTROLE-DO-IPHONE.md.
# Uso: scripts/agente-iphone.sh --team ABCDE12345 --device <UDID> --llm http://IP:PORTA/v1 [--modelo qwen3-vl:30b-a3b-instruct]
#                               [--horas 8] [--sem-visao] [--agente-id io.github.SEU.pocketselfagente] [--parar]
# (--agente-id: a conta gratuita só cria 10 App IDs a cada 7 dias; reutilize um ID já registrado.)
set -euo pipefail
raiz="$(cd "$(dirname "$0")/.." && pwd -P)"
team=""; dev=""; llm=""; modelo="qwen3-vl:30b-a3b-instruct"; horas=8; visao=1; parar=0; agente_id="io.github.voltolini-space.pocketselfagente"
while [ $# -gt 0 ]; do case "$1" in
  --team) team="$2"; shift 2;; --device) dev="$2"; shift 2;; --llm) llm="$2"; shift 2;; --modelo) modelo="$2"; shift 2;;
  --horas) horas="$2"; shift 2;; --sem-visao) visao=0; shift;; --agente-id) agente_id="$2"; shift 2;; --parar) parar=1; shift;;
  -h|--help) sed -n 2,9p "$0"; exit 0;; *) echo "opção desconhecida: $1" >&2; exit 2;; esac; done
if [ $parar -eq 1 ]; then pkill -f "xcodebuild test-without-building" && echo "sessão encerrada" || echo "nenhuma sessão"; exit 0; fi
[ -n "$team" ] && [ -n "$dev" ] && [ -n "$llm" ] || { echo "Faltam --team, --device e --llm." >&2; exit 2; }

# token: gerado uma vez, guardado fora do repositório
cfg="$HOME/.config/pocketself"; mkdir -p "$cfg"; chmod 700 "$cfg"
[ -s "$cfg/agente.token" ] || { openssl rand -hex 12 > "$cfg/agente.token"; chmod 600 "$cfg/agente.token"; }

cd "$raiz/agente-iphone"
export PS_AGENTE_ID="$agente_id"
xcodegen generate >/dev/null
pkill -f "xcodebuild test-without-building" 2>/dev/null || true
echo "==> compilando o runner para o aparelho $dev…"
xcodebuild -project PocketSelfAgente.xcodeproj -scheme PocketSelfAgente -destination "platform=iOS,id=$dev" \
  -derivedDataPath .build -allowProvisioningUpdates -skipPackagePluginValidation DEVELOPMENT_TEAM="$team" build-for-testing \
  | grep -E "error:|TEST BUILD" || true
xctestrun="$(ls .build/Build/Products/*.xctestrun 2>/dev/null | head -1)"
[ -n "$xctestrun" ] || { echo "Sem .xctestrun: a compilação falhou (veja docs/SOLUCAO-DE-PROBLEMAS.md)." >&2; exit 1; }

export TEST_RUNNER_POCKETSELF_TOKEN="$(cat "$cfg/agente.token")" TEST_RUNNER_POCKETSELF_LLM="$llm" \
       TEST_RUNNER_POCKETSELF_MODELO="$modelo" TEST_RUNNER_POCKETSELF_HORAS="$horas" TEST_RUNNER_POCKETSELF_VISAO="$visao"
log="${TMPDIR:-/tmp}/pocketself-agente.log"
echo "==> iniciando a sessão (log: $log). Deixe o iPhone DESBLOQUEADO na primeira vez."
nohup xcodebuild test-without-building -xctestrun "$xctestrun" -destination "platform=iOS,id=$dev" >"$log" 2>&1 &
echo "Sessão iniciada (pid $!). O código do agente (cole em Ajustes › Controle do iPhone no app):"
echo "  $(cat "$cfg/agente.token")"
echo "Para encerrar: scripts/agente-iphone.sh --parar"
