# Instalar com Claude Code ou Codex

A forma mais simples: deixe a sua IA de código conferir o ambiente, compilar e instalar, e **parar para você nos passos que só você pode fazer** (login do Apple ID, desbloquear o iPhone, confiar no perfil).

O repositório já traz instruções para as duas ferramentas: [`AGENTS.md`](../AGENTS.md) (Codex e outros) e [`CLAUDE.md`](../CLAUDE.md) (Claude Code). Elas leem esses arquivos ao abrir a pasta.

## Claude Code
```bash
git clone https://github.com/Voltolini-SPACE/pocketself.git && cd pocketself
claude
```
Cole:
```
Instale o PocketSelf no meu iPhone seguindo o CLAUDE.md. Primeiro rode scripts/verificar-ambiente.sh e me diga o que falta.
Peça meu Team ID quando precisar, não invente. Pare e me avise sempre que eu precisar agir no iPhone ou no Xcode.
Não instale nada além do necessário e não apague nenhum app do iPhone sem eu autorizar.
```

## Codex
```bash
git clone https://github.com/Voltolini-SPACE/pocketself.git && cd pocketself
codex
```
Cole o mesmo prompt (troque «CLAUDE.md» por «AGENTS.md»).

## O que a IA faz sozinha
- Conferir ambiente (`scripts/verificar-ambiente.sh`), rodar `tests/testar.sh`.
- Instalar o que falta no Mac (`xcodegen` via Homebrew) **depois de avisar**.
- Compilar e instalar (`scripts/instalar-no-iphone.sh --team …`).
- Diagnosticar erros de assinatura/compilação com `docs/SOLUCAO-DE-PROBLEMAS.md`.

## O que só você faz
- Entrar com o Apple ID no Xcode e informar o Team ID.
- Ligar o Modo de Desenvolvedor, desbloquear o iPhone, tocar em «Confiar».
- Escolher o que desinstalar se bater o limite de 3 apps (a IA **não** deve apagar apps sozinha).
- Digitar senhas (nenhuma IA deve digitar senha de conta por você).
- Ativar o Apple Intelligence (Ajustes › Apple Intelligence e Siri).

## Dica de segurança
Revise os comandos que a IA pedir para executar. Os scripts deste repositório só escrevem dentro do projeto, em `~/.config/pocketself` (token do agente) e instalam o app no iPhone que você indicar.
