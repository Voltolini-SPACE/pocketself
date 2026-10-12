# Instalação passo a passo

Tempo estimado: 20–40 min (a primeira compilação baixa dependências). Conferir tudo antes: `scripts/verificar-ambiente.sh`.

## 1. Preparar o Mac
1. Instale o **Xcode 26+**, abra uma vez, aceite a licença e instale a plataforma iOS.
2. `xcode-select -s /Applications/Xcode.app`
3. `brew install xcodegen` (Homebrew: https://brew.sh)
4. Xcode › Settings › Accounts › **+** › Apple ID. Selecione a conta e anote o **Team ID** (10 caracteres) em «Manage Certificates»/na lista de times. Deixe o Xcode criar o certificado **Apple Development**.

## 2. Preparar o iPhone
Siga [REQUISITOS.md](REQUISITOS.md#no-iphone-uma-vez): Modo de Desenvolvedor, confiar no computador, aparelho desbloqueado.

## 3. Obter o código
```bash
git clone https://github.com/Voltolini-SPACE/pocketself.git
cd pocketself
bash tests/testar.sh          # opcional: testes de lógica no Mac (sem aparelho)
```

## 4. Compilar e instalar
```bash
scripts/instalar-no-iphone.sh --team SEU_TEAM_ID
# se o Xcode reclamar que o bundle já existe em outra conta, use um prefixo só seu:
scripts/instalar-no-iphone.sh --team SEU_TEAM_ID --bundle-prefix io.github.seuusuario
```
Na 1ª abertura, confie no perfil: Ajustes › Geral › VPN e Gerenciamento de Dispositivo.
(Só testar a compilação, sem iPhone e sem conta: `scripts/instalar-no-iphone.sh --sem-assinatura`.)

Equivalente manual:
```bash
cd app && xcodegen generate
xcodebuild -project PocketSelf.xcodeproj -scheme PocketSelf -configuration Release \
  -destination generic/platform=iOS -derivedDataPath .build-device \
  -allowProvisioningUpdates -skipPackagePluginValidation -skipMacroValidation \
  DEVELOPMENT_TEAM=SEU_TEAM_ID PRODUCT_BUNDLE_IDENTIFIER=io.github.seuusuario.pocketself build
xcrun devicectl device install app --device <UDID> .build-device/Build/Products/Release-iphoneos/PocketSelf.app
```

## 5. Instalar um modelo (para conversar sem internet)
Sem modelo o app abre, mas só os recursos que não dependem dele funcionam. Escolha e copie um modelo: [MODELOS.md](MODELOS.md).

## 6. Primeira abertura
Boas-vindas → nome do agente → mascote → como te chamar → motor. Tudo pode ser mudado depois em Ajustes › Meu agente.

## 7. (Opcional) Controle do iPhone
[CONTROLE-DO-IPHONE.md](CONTROLE-DO-IPHONE.md). Consome +2 vagas de app.

## 8. Renovar a cada 7 dias
[ASSINATURA-7-DIAS.md](ASSINATURA-7-DIAS.md).

## Problemas
[SOLUCAO-DE-PROBLEMAS.md](SOLUCAO-DE-PROBLEMAS.md).
