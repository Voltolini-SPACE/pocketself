# Benchmark no iPhone 17 Pro Max (2026-10-12)

Medido **no aparelho**, pelo próprio app (`--benchmark=todos` ou Ajustes › Motor de IA › «Medir neste iPhone»). iPhone18,2, 11,4 GB de RAM, iOS 26.6.1, temperatura do sistema 0 antes e depois. O pedido é fixo: «Explique em três frases, em português do Brasil, por que o céu é azul.» (96 tokens no máximo). Logs: `evidence/benchmark-17/`.

| Motor | Ritmo | 1ª palavra (a frio) | 1ª palavra (quente) | Carga | Memória do app |
|---|---|---|---|---|---|
| Gemma 4 E2B | **47.7 tok/s** | 4.79 s | 0.09 s | 1.1 s | 2.7 GB (3.5 GB livres) |
| Qwen3.5 4B | **26.1 tok/s** | 2.56 s | 0.15 s | 1.1 s | 2.4 GB (3.7 GB livres) |
| Qwen3.5 9B | **14.4 tok/s** | 0.66 s | 0.29 s | 2.6 s | 5.0 GB (1.1 GB livres) |
| Gemma 4 E4B | **23.4 tok/s** | 0.72 s | 0.20 s | 1.9 s | 4.2 GB (1.9 GB livres) |
| Apple Intelligence | 7.9 *atualizações*/s | 2.75 s | 0.30 s | 0 | 105 MB |
| Edge0 35B (app à parte) | **9,1 tok/s** (1º turno) · 8,1 (2º) | 13,8 s | 1,1 s (2º turno) | — | pico 3,7 GB |

Execução final (`pocketself-todos-final.log`); uma execução anterior (`pocketself-todos.log`) deu valores próximos (E2B 46,7 · 4B 26,1 · 9B 14,2 tok/s). A 1ª palavra a frio varia bastante (compilação dos kernels na primeira geração).

Notas:
- **Apple Intelligence:** o sistema entrega a resposta em *atualizações cumulativas*, não token a token; por isso a coluna mede atualizações por segundo, não é comparável a tok/s.
- **Gemma 4 E4B:** o arquivo que estava no aparelho vinha **truncado** (3,8 GB de 5,1 GB) e falhava ao carregar (`invalid data offsets`, visível em `pocketself-todos.log`). Foi baixado de novo, completo (5.146.800.534 bytes), e carrega e responde na execução final. Confira o tamanho do `model.safetensors` ao copiar.
- **Edge0 35B** (https://github.com/Edge0-AI/Edge0, Apache-2.0) roda em app próprio com o checkpoint reempacotado (~18 GB no app) e streaming de experts do SSD. Medido: 64 tokens, TTFT 13,8 s (1ª conversa, prefill 6,7 tok/s), 2ª conversa TTFT 1,1 s; prompt longo: TTFT 48,8 s (prefill 32,9 tok/s), decode 5,65 tok/s; temperatura 0. Para comparação, o mesmo motor no iPhone 15 Pro (memória ampliada) deu ~5,8 tok/s. **Não está embutido no PocketSelf**: exige ~20 GB livres só para instalar (o instalador do iOS recusou com 12 GB livres) e um pacote próprio.
- Os números variam com temperatura, bateria e o que mais está aberto; repita no seu aparelho.

## Incidente que vale registrar
Uma instalação que falhou por «Insufficient storage» (Edge0, 19,7 GB necessários, 12 GB livres) foi seguida do **apagamento do conteúdo do app PocketSelf** no aparelho (modelos e dados). Os arquivos estavam em backup no Mac e foram reenviados. Antes de instalar algo grande, confira `ios diskspace` (go-ios) ou Ajustes › Geral › Armazenamento, e mantenha backup dos modelos no Mac.
