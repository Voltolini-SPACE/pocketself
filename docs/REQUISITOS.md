# Requisitos: o que você precisa para instalar, conectar e acessar

## Obrigatório

| Item | Detalhe | Como conferir |
|---|---|---|
| **Mac** com macOS atual | Xcode só existe no macOS. | `scripts/verificar-ambiente.sh` |
| **Xcode 26 ou mais novo** | App Store ou developer.apple.com. Abra uma vez e aceite a licença; instale a plataforma iOS pedida. | `xcodebuild -version` |
| **iPhone** com **iOS 18+** | Testado: iPhone 15 Pro (iOS 26) e 17 Pro Max. Motores maiores (9B/E4B) pedem 12 GB de RAM. | Ajustes › Geral › Sobre |
| **Cabo USB** de dados | Instalar, copiar modelos e depurar pelo cabo. | `xcrun devicectl list devices` |
| **Apple ID** (gratuito basta) | Adicione em Xcode › Settings › Accounts; o Xcode cria o certificado «Apple Development». | `security find-identity -v -p codesigning` |
| **xcodegen** | Gera o projeto Xcode a partir de `app/project.yml`. | `brew install xcodegen` |
| **git** | Vem com as ferramentas de linha de comando do Xcode. | `git --version` |

## No iPhone (uma vez)

1. **Modo de Desenvolvedor**: Ajustes › Privacidade e Segurança › Modo de Desenvolvedor › ligar (reinicia).
2. **Confiar no computador** quando o cabo for conectado.
3. **Confiar no perfil** do seu Apple ID depois da 1ª instalação: Ajustes › Geral › VPN e Gerenciamento de Dispositivo.
4. Deixar o aparelho **desbloqueado** durante instalar/abrir pelo cabo.
5. Permissões do app (pedidas quando necessárias): microfone, reconhecimento de fala, câmera, agenda, lembretes, contatos, Apple Music.

## Opcional (cada um habilita uma coisa)

| Item | Habilita | Observação |
|---|---|---|
| **Hugging Face CLI** (`pip install -U huggingface_hub`) | baixar os modelos MLX | veja [MODELOS.md](MODELOS.md) |
| **Apple Intelligence ligado** (iPhone 15 Pro ou mais novo) | criar imagem e o motor «Apple Intelligence» | [APPLE-INTELLIGENCE.md](APPLE-INTELLIGENCE.md) |
| **Atalhos (Shortcuts)** | frases «PocketSelf Nota/Alarme» e ações encadeadas | app nativo da Apple |
| **go-ios** (`brew install go-ios`) | diagnóstico e encaminhar a porta do agente ao Mac | não é necessário para usar o app |
| **Servidor de modelo** (Ollama, vLLM… no Mac/PC/DGX Spark) + túnel SSH | modo «Máximo» e o modelo de visão do agente de controle | [SERVIDOR-OPCIONAL.md](SERVIDOR-OPCIONAL.md) |
| **Claude Code ou Codex CLI** | instalar e operar por prompt | [INSTALACAO-COM-IA.md](INSTALACAO-COM-IA.md) |
| **Apps de terceiros** (Spotify, WhatsApp, YouTube…) | o PocketSelf abre/busca por esquema de URL | já listados em `LSApplicationQueriesSchemes` |

## Limites da conta gratuita (importante)

- Assinatura **vale 7 dias** → [ASSINATURA-7-DIAS.md](ASSINATURA-7-DIAS.md).
- No máximo **3 apps de desenvolvedor por aparelho**. O PocketSelf usa 1; o agente de controle usa +2 (app anfitrião e runner).
- Limite semanal de novos identificadores de app: se estourar, espere ou use o mesmo `--bundle-prefix` sempre.
