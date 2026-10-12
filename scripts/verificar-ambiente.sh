#!/bin/bash
# PocketSelf — confere se o Mac e o iPhone estão prontos. Só lê; não altera nada.
# Saída: [ok] / [falta] / [aviso] por item; código de saída 1 se faltar algo obrigatório.
falta=0
ok()   { echo "[ok]    $*"; }
aviso(){ echo "[aviso] $*"; }
nok()  { echo "[falta] $*"; falta=1; }

[ "$(uname -s)" = Darwin ] && ok "macOS $(sw_vers -productVersion)" || nok "macOS é obrigatório (Xcode só existe nele)"
if xcodebuild -version >/dev/null 2>&1; then
  v=$(xcodebuild -version | head -1); maj=$(echo "$v" | sed -E 's/[^0-9]*([0-9]+).*/\1/')
  [ "${maj:-0}" -ge 26 ] && ok "$v" || nok "$v — precisa Xcode 26 ou mais novo (App Store ou developer.apple.com)"
else nok "Xcode não instalado/selecionado (xcode-select -s /Applications/Xcode.app)"; fi
xcrun --find devicectl >/dev/null 2>&1 && ok "devicectl (instala e abre apps pelo cabo)" || nok "devicectl ausente (vem com o Xcode 15+)"
command -v xcodegen >/dev/null && ok "xcodegen $(xcodegen --version 2>/dev/null | head -1)" || nok "xcodegen ausente: brew install xcodegen"
command -v git >/dev/null && ok "git" || nok "git ausente"
command -v python3 >/dev/null && ok "python3 (só para o ícone e verificações)" || aviso "python3 ausente (opcional)"
command -v hf >/dev/null || command -v huggingface-cli >/dev/null && ok "Hugging Face CLI (baixar modelos)" || aviso "CLI do Hugging Face ausente: pip install -U huggingface_hub (só para baixar modelos)"
command -v ios >/dev/null && ok "go-ios (opcional, diagnóstico)" || aviso "go-ios ausente (opcional): brew install go-ios"

echo "--- aparelhos conectados (devicectl) ---"
if xcrun devicectl list devices 2>/dev/null | grep -E "iPhone" ; then :; else aviso "nenhum iPhone listado: conecte o cabo, desbloqueie e toque em «Confiar neste computador»"; fi
echo "--- equipes de assinatura no Keychain ---"
if security find-identity -v -p codesigning 2>/dev/null | grep -E "Apple Development" | sed 's/^ *[0-9]*) [A-F0-9]* //'; then :; else aviso "nenhuma identidade «Apple Development»: Xcode > Settings > Accounts > adicione o Apple ID (grátis) e deixe criar o certificado"; fi
echo
[ $falta -eq 0 ] && echo "Ambiente pronto para compilar." || echo "Resolva os itens [falta] e rode de novo."
exit $falta
