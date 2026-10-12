# Modelos: baixar e copiar para o iPhone

Os modelos **não vêm no repositório** (centenas de MB a GB). Baixe no Mac e copie pelo cabo para a pasta do app. Baixar direto no iPhone travou nos testes; o caminho validado é Mac → cabo.

| Motor no app | Pasta esperada em `Documents/modelos/` | Repositório de origem (Hugging Face) | RAM | Medido (iPhone 17 Pro Max) |
|---|---|---|---|---|
| Gemma 4 E2B (leve, também vê imagens) | `gemma-4-e2b-it-4bit` | `mlx-community/gemma-4-e2b-it-4bit` | 8 GB | 46,7 tok/s |
| **Qwen3.5 4B** (padrão) | `Qwen3.5-4B-MLX-4bit` | `mlx-community/Qwen3.5-4B-MLX-4bit` | 8 GB | 26,1 tok/s |
| Qwen3.5 9B (profundo) | `Qwen3.5-9B-MLX-4bit` | `mlx-community/Qwen3.5-9B-MLX-4bit` | 12 GB | 14,2 tok/s |
| Gemma 4 E4B (profundo, vê imagens) | `gemma-4-e4b-it-4bit` | `mlx-community/gemma-4-e4b-it-4bit` (5,1 GB; confira o tamanho) | 12 GB | veja [BENCHMARK-IPHONE-17.md](BENCHMARK-IPHONE-17.md) |
| Voz neural Kokoro (opcional, experimental) | `Kokoro-82M-CoreML` | veja `app/Pacotes/VozNeural/README.md` | pequena | sotaque pt-BR ainda irregular |

Medições: [BENCHMARK-IPHONE-17.md](BENCHMARK-IPHONE-17.md) (e, para outros aparelhos, `evidence/logs-aparelho-2026-10/`). Você mesmo mede no seu: Ajustes › Motor de IA › «Medir neste iPhone». Cada modelo tem **licença própria** (Qwen: Apache-2.0 na maioria das versões; Gemma: termos de uso do Google). Leia a página do modelo antes de usar ou redistribuir.

## Baixar no Mac
```bash
pip install -U huggingface_hub
hf download mlx-community/Qwen3.5-4B-MLX-4bit --local-dir ~/pocketself-modelos/Qwen3.5-4B-MLX-4bit
```
(`huggingface-cli download …` em versões antigas.)

## Template de chat do Qwen3.5 (importante para a velocidade)
O Qwen3.5 é híbrido e o cache não rebobina: qualquer divergência no prefixo força reprocessar tudo. Substitua o template da pasta do modelo pelo corrigido deste repositório:
```bash
cp app/templates/qwen3.5-chat_template.jinja ~/pocketself-modelos/Qwen3.5-4B-MLX-4bit/chat_template.jinja
```
(Se o modelo trouxer o template dentro do `tokenizer_config.json`, ajuste lá; sem o patch o app funciona, só fica mais lento nas respostas longas.)

## Copiar para o iPhone (cabo, aparelho desbloqueado, app já instalado)
```bash
BUNDLE=io.github.voltolini-space.pocketself      # o mesmo usado na instalação
UDID=<UDID do iPhone>                            # xcrun devicectl list devices
xcrun devicectl device copy to --device $UDID --domain-type appDataContainer --domain-identifier $BUNDLE \
  --source ~/pocketself-modelos/Qwen3.5-4B-MLX-4bit --destination Documents/modelos/Qwen3.5-4B-MLX-4bit
```
Nota: `devicectl copy` não sobrescreve; para atualizar, apague o destino antes (pelo Xcode › Window › Devices and Simulators › app › Download Container, ou reinstalando o conteúdo). Depois abra o app › Ajustes › motor.

## Limites de memória
Um motor por vez na memória (~6 GB utilizáveis num iPhone de 8 GB com o entitlement de memória ampliada). Modelos maiores que isso são encerrados pelo iOS (sinal 9). O app libera o motor de texto antes de usar o de visão.
