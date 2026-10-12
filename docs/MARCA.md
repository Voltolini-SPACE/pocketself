# Marca e identidade visual

## Logo
Um rosto saindo do bolso: «Pocket» + «Self». Pixel art, desenhada em uma grade de 20×20 (`scripts/gerar-marca.py` é a fonte única: gera os ícones do app, os SVGs e o `Marca.swift`).

| Arquivo | Uso |
|---|---|
| `docs/marca/pocketself-marca.svg` | só o símbolo |
| `docs/marca/pocketself-logo-claro.svg` / `-escuro.svg` | símbolo + nome, para fundo claro/escuro |
| `app/PocketSelf/Assets.xcassets/AppIcon.appiconset` | ícone do app (claro e escuro) |

Regenerar: `python3 scripts/gerar-marca.py` (requer Pillow). O desenho é original deste projeto, sob a licença MIT.

## Cores («Bolso»)
Papel quente + tinta índigo; a cor de destaque é escolhida pelo usuário.

| Token | Claro | Escuro |
|---|---|---|
| fundo | `#F8F5F0` | `#15122B` |
| superfície | `#FFFFFF` | `#201B3D` |
| texto | `#1E1A36` | `#F2EFFB` |
| texto secundário | `#5A5473` | `#BAB3D3` |
| borda de controle | `#857E9B` | `#8478B0` |
| separador | `#DDD7E8` | `#3A3563` |
| suave | `#EFEAF8` | `#2B2551` |
| perigo | `#B3261E` | idem |

Destaques: **Índigo** `#4F46E5`, **Menta** `#0F7A55`, **Coral** `#C0341D`, **Sol** `#8A5300` (valores do tema claro; os do escuro estão em `Tema.swift`).
Contraste conferido por `python3 scripts/verificar-contraste.py` (texto ≥ 4,5:1; bordas e botões ≥ 3:1) nos dois temas.

## Tipografia e forma
Fonte do sistema (respeita o tamanho de texto do usuário, de «pequeno» a «extra grande»). Pixel só na marca e nos personagens. Raio de cartão 12, botões 9, alvo mínimo de toque 44 pt.

## Personagens
14 espécies, 14 acessórios e 8 objetos, cada espécie com silhueta própria; 8 cores de corpo e 4 expressões (≈ 50 mil combinações válidas, conferidas em `tests/PerfilTests.swift`). Tudo desenhado em código — sem imagens de terceiros.

![Elenco](marca/personagens.png)

Espécies: gatinho, coelhinho, ursinho, robozinho, raposinha, dinozinho, cachorrinho, corujinha, sapinho, pinguinzinho, pandinha, alienzinho, fantasminha, polvinho.
Acessórios: óculos, coroa, laço, fone, chapéu de bruxo, cartola, boné, tapa-olho, gravata, flor, capacete, estrelas, cachecol.
Objetos (segurando): café, livro, estrela, coração, plantinha, balão, controle.

## Como propor um personagem novo
1. Em `Perfil.swift`, acrescente o caso em `Especie` (nome, `topo`, `camada` com linhas de 16 colunas).
2. Rode `bash tests/testar.sh` (verifica dimensões, caracteres e que a grade é diferente das demais).
3. Gere a folha: `POCKETSELF_FOLHA=/tmp/folha.ppm` ou `POCKETSELF_ELENCO=/tmp/elenco.ppm` ao rodar o teste de perfil, e confira visualmente.
