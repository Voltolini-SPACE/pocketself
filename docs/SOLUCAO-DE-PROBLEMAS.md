# Solução de problemas

| Sintoma | Causa provável | O que fazer |
|---|---|---|
| App não abre depois de alguns dias | assinatura gratuita venceu (7 dias) ou perfil não confiado | `scripts/instalar-no-iphone.sh --team …` (por cima, sem desinstalar); confie em Ajustes › Geral › VPN e Gerenciamento de Dispositivo |
| «maximum number of installed apps using a free developer profile» | limite de 3 apps | desinstale **você** um app de desenvolvedor que não use e tente de novo |
| «No Account for Team» / «No signing certificate» | Apple ID não está no Xcode | Xcode › Settings › Accounts › + |
| «Bundle identifier is not available» | outra conta já usa esse ID | use `--bundle-prefix io.github.seuusuario` |
| «Developer Mode disabled» | Modo de Desenvolvedor desligado | Ajustes › Privacidade e Segurança › Modo de Desenvolvedor |
| `devicectl` não lista o iPhone | cabo só de carga, aparelho bloqueado, sem «Confiar» | outro cabo de dados, desbloquear, tocar em Confiar |
| Falha ao resolver pacotes Swift | sem internet na 1ª compilação | conecte o Mac; repita |
| Erro de macros/plugins | validação de pacotes | já passamos `-skipPackagePluginValidation -skipMacroValidation` |
| Projeto Xcode «sem arquivos» | `.xcodeproj` é gerado | `cd app && xcodegen generate` |
| App fecha ao carregar modelo (sinal 9) | modelo maior que a memória | use 4B/E2B em 8 GB; um motor por vez |
| «Geração de imagem indisponível» | Apple Intelligence desligado/sem suporte | [APPLE-INTELLIGENCE.md](APPLE-INTELLIGENCE.md) |
| Modo «Máximo» não conecta | túnel/IP/Rede Local | [SERVIDOR-OPCIONAL.md](SERVIDOR-OPCIONAL.md) |
| Agente de controle responde vazio/morre | app alvo não estava em primeiro plano; aparelho bloqueado | desbloqueie e reinicie a sessão; ver [CONTROLE-DO-IPHONE.md](CONTROLE-DO-IPHONE.md) |
| Agente com «tempo esgotado» no modelo | modelo carregando a frio, rede errada, Modo Avião | repita; confira a rota até o modelo antes de culpar o serviço |
| Agente toca no mesmo item sem avançar | item coberto por barra de busca/abas | corrigido na lógica (`Logica.simplificar`); atualize |
| Instalação falha com «Insufficient storage» | o instalador do iOS precisa de ~1× o tamanho do app livre **além** do app | libere espaço antes; depois de uma falha dessas o conteúdo (modelos) do PocketSelf pode ser apagado: mantenha os modelos em backup no Mac ([BENCHMARK-IPHONE-17.md](BENCHMARK-IPHONE-17.md)) |
| `Gemma 4 E4B` não carrega (`invalid data offsets`) | `model.safetensors` truncado na cópia/download | compare o tamanho com o do Hugging Face (5.146.800.534 bytes) e copie de novo |
