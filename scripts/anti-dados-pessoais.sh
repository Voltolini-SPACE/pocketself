#!/bin/bash
# PocketSelf — bloqueia dados pessoais e segredos no repositório. Roda no CI e antes de cada commit/publicação.
# Sai com código 1 se achar algo. Padrões em scripts/anti-dados-pessoais.padroes (um regex por linha, ERE).
cd "$(dirname "$0")/.."
padroes="scripts/anti-dados-pessoais.padroes"
# Termos pessoais do mantenedor (nomes, IDs de conta) ficam FORA do repositório, num arquivo local opcional.
privados="${POCKETSELF_PADROES_PRIVADOS:-$HOME/.config/pocketself/padroes-privados.txt}"
achou=0
while IFS= read -r p; do
  case "$p" in ''|'#'*) continue;; esac
  r=$(git ls-files -z --cached --others --exclude-standard | xargs -0 grep -InE -- "$p" 2>/dev/null \
      | grep -v "^scripts/anti-dados-pessoais" || true)
  if [ -n "$r" ]; then echo "== padrão: $p"; echo "$r" | head -8; achou=1; fi
done < <(cat "$padroes"; [ -f "$privados" ] && cat "$privados")
[ $achou -eq 0 ] && echo "OK: nenhum dado pessoal ou segredo encontrado." || { echo "FALHOU: remova ou troque por exemplo neutro." >&2; exit 1; }
