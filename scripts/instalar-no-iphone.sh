#!/bin/bash
# PocketSelf — compila, assina com a SUA equipe e instala no iPhone pelo cabo. Rode de novo a cada 7 dias (conta gratuita).
# Uso: scripts/instalar-no-iphone.sh --team ABCDE12345 [--device <UDID|nome>] [--bundle-prefix io.github.SEUUSUARIO] [--so-compilar] [--sem-assinatura]
#  --team            ID da equipe (Xcode > Settings > Accounts > seu Apple ID > «Team ID»), 10 caracteres
#  --device          UDID ou nome (padrão: o único iPhone conectado)
#  --bundle-prefix   prefixo único seu para o bundle (padrão: io.github.voltolini-space; o Xcode recusa se outra conta já usa)
#  --so-compilar     não instala (útil para testar a compilação)
#  --sem-assinatura  compila sem assinar (CI/verificação); implica --so-compilar
#  --nao-abrir       instala sem abrir o app (por exemplo, se você estiver usando o iPhone)
set -euo pipefail
raiz="$(cd "$(dirname "$0")/.." && pwd -P)"
team=""; dev=""; prefixo="io.github.voltolini-space"; instalar=1; assinar=1; abrir=1
while [ $# -gt 0 ]; do case "$1" in
  --team) team="$2"; shift 2;; --device) dev="$2"; shift 2;; --bundle-prefix) prefixo="$2"; shift 2;;
  --so-compilar) instalar=0; shift;; --nao-abrir) abrir=0; shift;; --sem-assinatura) assinar=0; instalar=0; shift;;
  -h|--help) sed -n 2,9p "$0"; exit 0;; *) echo "opção desconhecida: $1" >&2; exit 2;; esac; done
[ $assinar -eq 0 ] || [ -n "$team" ] || { echo "Informe --team <ID da equipe>. Veja docs/INSTALACAO.md." >&2; exit 2; }
bundle="$prefixo.pocketself"

cd "$raiz/app"
xcodegen generate >/dev/null
args=(-project PocketSelf.xcodeproj -scheme PocketSelf -configuration Release -destination generic/platform=iOS
      -derivedDataPath .build-device -skipPackagePluginValidation -skipMacroValidation
      PRODUCT_BUNDLE_IDENTIFIER="$bundle")
if [ $assinar -eq 1 ]; then args+=(-allowProvisioningUpdates DEVELOPMENT_TEAM="$team"); else args+=(CODE_SIGNING_ALLOWED=NO); fi
echo "==> compilando ($bundle)…"
xcodebuild "${args[@]}" build | grep -E "error:|warning: .*signing|BUILD (SUCCEEDED|FAILED)" || true
app=".build-device/Build/Products/Release-iphoneos/PocketSelf.app"
[ -d "$app" ] || { echo "Compilação falhou: $app não existe. Veja docs/SOLUCAO-DE-PROBLEMAS.md." >&2; exit 1; }
[ $instalar -eq 1 ] || { echo "Compilado em app/$app (não instalado)."; exit 0; }

if [ -z "$dev" ]; then
  dev="$(xcrun devicectl list devices 2>/dev/null | awk '/iPhone/ && /connected|available/ {for(i=1;i<=NF;i++) if ($i ~ /^[0-9A-F-]{25,}$/) {print $i; exit}}')"
  [ -n "$dev" ] || { echo "Nenhum iPhone conectado/desbloqueado. Use --device." >&2; exit 1; }
fi
echo "==> instalando em $dev…"
xcrun devicectl device install app --device "$dev" "$app"
[ $abrir -eq 1 ] || { echo "Instalado (não aberto)."; exit 0; }
echo "==> abrindo…"
xcrun devicectl device process launch --device "$dev" "$bundle" || echo "Abra o app manualmente (aparelho desbloqueado; confie no perfil em Ajustes > Geral > VPN e Gerenciamento de Dispositivo)."
echo "Pronto. Validade da assinatura gratuita: 7 dias — rode este script de novo antes disso (dados preservados)."
