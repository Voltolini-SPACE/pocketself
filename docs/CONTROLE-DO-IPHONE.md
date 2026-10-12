# Controle do iPhone: o agente que opera qualquer app

## A ideia
Um app comum **não pode** tocar em outros apps (sandbox do iOS). Um **runner XCUITest** pode: ele lê a tela de qualquer app pela árvore de acessibilidade e injeta toques e digitação, como as ferramentas de teste da Apple. O PocketSelf usa isso de dentro do próprio aparelho:

```
Mac (Xcode)  ──mantém viva──►  sessão xcodebuild test-without-building
                                    │
iPhone: runner PocketSelfAgente ────┤ laço: ler tela (+ captura 480 px) → pedir ação ao modelo → validar → tocar/digitar/rolar
        servidor HTTP 127.0.0.1:14292 (token)   ◄── app PocketSelf (ferramenta controlar_iphone)
        modelo (OpenAI-compatível, de preferência com visão) em outro equipamento da rede/cabo
```
O Mac **não decide nada**: só mantém a sessão. Se a sessão cair, o agente para.

## Ações e segurança
Ações: `tocar · digitar · deslizar · rolar · abrir · inicio · voltar · esperar · fim`. A barreira (`Logica.validar`) **impede**: tocar em elementos de envio/pagamento/exclusão/publicação (por texto), digitar em campos de senha, bundles malformados. Nesses casos a tarefa vira `aguarda_dono` e pede você. Elementos cobertos por barras sobrepostas (busca, ferramentas, abas) são descartados da lista para o modelo não tocar «por baixo».

## Requisitos
- Conta gratuita: o agente usa **+2 vagas** (app anfitrião + runner). Com o PocketSelf são 3 — o limite.
- iPhone desbloqueado ao iniciar; sessão ativa durante o uso.
- Um modelo OpenAI-compatível alcançável **pelo iPhone**. Testado: Ollama com `qwen3-vl:30b-a3b-instruct` (visão) via túnel SSH pelo cabo. [SERVIDOR-OPCIONAL.md](SERVIDOR-OPCIONAL.md).

## Ligar
```bash
scripts/agente-iphone.sh --team SEU_TEAM_ID --device <UDID> --llm http://IP_DO_MAC_PELO_CABO:PORTA/v1
```
O script gera um token (em `~/.config/pocketself/agente.token`), compila o runner, inicia a sessão e mostra o código. Cole o código no app: **Ajustes › Controle do iPhone**. Encerrar: `scripts/agente-iphone.sh --parar`.

Variáveis do runner (`TEST_RUNNER_POCKETSELF_*`): `TOKEN`, `LLM`, `MODELO`, `HORAS` (padrão 8), `VISAO` (`1` envia captura).

## Diagnóstico a partir do Mac
```bash
ios forward 14292 14292 --udid=<UDID> &      # go-ios
scripts/agente-iphone-tarefa.sh "Abra Ajustes, entre em Geral > Sobre e diga a versão do iOS"
curl -H "Authorization: Bearer $(cat ~/.config/pocketself/agente.token)" 127.0.0.1:14292/captura   # JPEG base64
```
Rotas: `GET /estado · /tarefa/<id> · /elementos · /captura · /rede`, `POST /tarefa {"objetivo": "..."}`.

## Lições registradas
- Ler a árvore de um app que não está em primeiro plano é falha do XCTest e derruba o servidor: o agente confere o estado antes e espera a tela assentar.
- Sem Wi-Fi no aparelho (ou em Modo Avião), o modelo precisa vir **por cabo** (rede USB do Mac). Verifique a rede antes de culpar o serviço.
- Timeout na 1ª chamada pode ser carga a frio do modelo grande: repita antes de concluir que há falha.
- `go-ios screenshot` no iOS 26 exige `ios tunnel start`; a rota `/captura` do runner evita isso.

## Estado de validação
Veja [FUNCIONALIDADES.md](FUNCIONALIDADES.md): 🟡 funciona; repetição de ponta a ponta no iPhone 15 Pro pendente após a correção do filtro de barras.
