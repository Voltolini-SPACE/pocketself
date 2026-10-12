# Servidor de modelo opcional (modo «Máximo» e visão do agente)

O PocketSelf **não depende** de servidor: conversa com modelos no aparelho. Um servidor próprio (Mac, PC com GPU, NVIDIA DGX Spark…) é opcional e serve para:
1. o motor «Máximo» (modelo grande para perguntas difíceis);
2. o modelo de visão do agente de controle do iPhone ([CONTROLE-DO-IPHONE.md](CONTROLE-DO-IPHONE.md)).

Requisito: API **compatível com OpenAI** (`/v1/chat/completions`, streaming SSE). Testado: vLLM e Ollama.

## Caminho pelo cabo (validado)
```
iPhone ──USB──► Mac (rede interna do cabo, 1º IP do bridge) ──túnel SSH──► servidor (127.0.0.1:PORTA)
```
No Mac:
```bash
ssh -o ControlPath=none -N -L <IP_DO_MAC_NO_CABO>:14290:127.0.0.1:<PORTA_DO_SERVIDOR> usuario@servidor
```
No app: **Ajustes › Motor de IA › Servidor opcional** — informe o endereço (ex.: `http://IP:PORTA/v1`) e o nome do modelo exatamente como o servidor o anuncia em `/v1/models`, e toque em «Testar conexão». Descubra o IP do Mac no cabo com `ifconfig | grep -A3 bridge` (aparelho conectado + «Compartilhar Internet»/rede USB ativa).

## Atenção
- O túnel precisa escutar no IP do **Mac visto pelo iPhone**, não em `127.0.0.1` do Mac.
- O iOS pede permissão de **Rede Local** na primeira conexão; negada, a conexão falha em silêncio.
- Diagnostique em camadas (rede/rota → DNS → TCP → SSH → túnel → HTTP). Falha de uma camada não prova que o servidor está desligado.
- O contexto da conversa é enviado ao seu servidor; use só equipamentos seus.
- Timeout na 1ª chamada: modelos grandes carregam a frio; repita.
