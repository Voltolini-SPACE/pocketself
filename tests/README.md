# Regressões do PocketSelf

No macOS, execute `bash tests/testar.sh`. Os testes compilam os arquivos reais do app em uma pasta temporária e limpam os binários ao terminar. Exigem o Swift do Xcode; não carregam MLX nem modelos.

- `SparkTests.swift`: intercepta HTTP por URLProtocol dentro do processo de teste; verifica SSE, modelo, chamadas de ferramentas, validação de lote e cancelamento. Nenhuma requisição é enviada à Spark e nenhuma ferramenta do aparelho é executada.
- `RespostaTextoTests.swift`: preservação de código, cifrões e moedas, conversão de fórmulas e texto.
- `ContextoTests.swift`: histórico com uma única pergunta atual, anexos e memória no modo voz.

- `ImplantacaoTests.py`: usa repositórios Git locais e SSH simulado para garantir que a versão publicada é a versão testada e que commit reprovado não é enviado.

Compilação iOS e testes reais no aparelho são verificações adicionais. A Spark Linux guarda o espelho do app iOS e não executa a suíte Swift/Foundation Darwin; checksum ou documentos presentes não substituem esses testes.

- `GanchoTests.py`: o gancho aguarda a entrega terminar e distingue commit salvo de sincronização reprovada.

Validação adicional (11/10/2026):

- `PersistenciaTests.swift`: instâncias reais de histórico, memória e decisor em diretórios temporários; cria, atualiza e recarrega arquivos. Stubs cobrem apenas tipos de UI/navegação. O salvamento original passou antes de qualquer correção; a suspeita de perda na primeira gravação não foi confirmada no Mac.
- `ValidacaoTests.swift`: contrato dos caminhos isolados e do JSON de um turno. Sem `--validar-respostas`, os caminhos normais permanecem inalterados.

Para validar texto no iPhone pelo cabo, inicie o app com `--motor=spark --validar-respostas --perguntas=pergunta1|pergunta2`. O modo usa `neo-validacao-conversas.json`, `neo-validacao-memoria.json` e `neo-validacao-decisor.json`, separados dos dados pessoais. O console imprime `[neo-validacao]` por turno e `[neo-validacao-fim] mensagens_recarregadas=N` no último. Pode conter o texto sintético integral: não use perguntas privadas nesse diagnóstico. Reabra sem esses argumentos ao terminar. As preferências de UserDefaults continuam compartilhadas. O console exige controle físico autorizado do aparelho.
