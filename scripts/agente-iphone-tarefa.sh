#!/bin/bash
# PocketSelf — dispara uma tarefa no agente do iPhone a partir do Mac e acompanha o resultado (diagnóstico).
# Precisa de `ios forward 14292 14292 --udid=<UDID>` (go-ios) para o Mac enxergar a porta do aparelho.
# Uso: scripts/agente-iphone-tarefa.sh "Abra os Ajustes, entre em Geral > Sobre e diga a versão do iOS" [tentativas]
set -euo pipefail
T="$(cat "$HOME/.config/pocketself/agente.token")"; H="Authorization: Bearer $T"; U=127.0.0.1:14292
curl -s -m 5 -H "$H" $U/estado | grep -q agente || { echo "Agente não responde em $U (sessão ativa? ios forward?)." >&2; exit 1; }
ID=$(curl -s -m 8 -X POST -H "$H" -d "{\"objetivo\":\"$1\"}" $U/tarefa | python3 -c "import sys,json;print(json.load(sys.stdin)['id'])")
echo "tarefa $ID"
for _ in $(seq 1 "${2:-30}"); do
  sleep 8; r=$(curl -s -m 6 -H "$H" $U/tarefa/$ID); e=$(echo "$r" | python3 -c "import sys,json;print(json.load(sys.stdin)['estado'])")
  [ "$e" != executando ] && break
done
echo "$r" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['estado'],'|',d['resposta']);[print(' ',l) for l in d['log']]"
