#!/bin/bash
# PocketSelf — testes de lógica pura (sem iPhone, sem rede, sem modelos). Exige macOS com o Swift do Xcode.
set -euo pipefail
raiz="$(cd "$(dirname "$0")/.." && pwd -P)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/pocketself-testes.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
cd "$raiz"
[ "$(uname -s)" = Darwin ] || { echo "Os testes Swift exigem macOS." >&2; exit 2; }
A=app/PocketSelf
roda() { # nome  arquivos...
  local nome="$1"; shift
  [ -z "${SO:-}" ] || [ "$SO" = "$nome" ] || return 0   # SO=nome roda só um teste (desenvolvimento)
  swiftc -module-cache-path "$tmp/cache" -swift-version 5 -parse-as-library "$@" -o "$tmp/$nome"
  "$tmp/$nome"
}
# Trechos puros de arquivos que importam UIKit/EventKit/MLX são extraídos TEXTUALMENTE do arquivo real do app
# (nada é copiado para o repositório; o arquivo gerado vive em $tmp). Trecho vazio = o app mudou: o teste falha de propósito.
trecho() { # arquivo  regex-início  regex-fim (linha que fecha o trecho, inclusive)
  local r; r="$(awk -v ini="$2" -v fim="$3" '$0 ~ ini {on=1} on {print} on && $0 ~ fim {exit}' "$1")"
  [ -n "$r" ] || { echo "ERRO: trecho não encontrado em $1 ($2)" >&2; exit 3; }
  printf '%s\n' "$r"
}
ate_import_swiftui() { awk '/^import SwiftUI/ {exit} {print}' "$1"; }
mkdir -p "$tmp/ext"
{ echo "import Foundation"
  trecho $A/Ferramentas.swift '^struct SemEntrada' '^struct ControleEntrada'
  trecho $A/Ferramentas.swift '^struct Pendencia' '^}$'
  trecho $A/Ferramentas.swift '^enum Datas' '^}$'; } > "$tmp/ext/ExtFerramentas.swift"
{ echo "import Foundation"; echo "enum Integracoes {"
  trecho $A/Integracoes.swift 'static let atalhoNota' 'static let atalhoAlarme'
  trecho $A/Integracoes.swift 'static func urlAtalho' '^    }$'
  trecho $A/Integracoes.swift 'static func numeroLimpo' 'numeroLimpo'
  echo "}"; echo "enum Apps {"
  trecho $A/Integracoes.swift 'static func url[(]app' '^    }$'
  echo "}"
  trecho $A/Integracoes.swift '^enum PerguntaExterna' '^}$'; } > "$tmp/ext/ExtIntegracoes.swift"
ate_import_swiftui $A/ControleIphone.swift > "$tmp/ext/ExtControle.swift"
{ echo "import Foundation"
  trecho $A/Visao.swift '^struct AnaliseDeImagem' '^}$'
  echo "enum Visao {"; trecho $A/Visao.swift 'nonisolated static func traduzir' '^    }$'; echo "}"
  echo "enum GeradorDeImagem {"; trecho $A/Imagem.swift 'static func explicar' '^    }$'; echo "}"; } > "$tmp/ext/ExtVisao.swift"
X="$tmp/ext"

roda resgate    $A/ResgateLogica.swift tests/ResgateTests.swift
roda fidelidade $A/Fidelidade.swift tests/FidelidadeTests.swift
roda reuniao    $A/ReuniaoLogica.swift tests/ReuniaoTests.swift
roda spark      $A/Spark.swift tests/SparkTests.swift
roda texto      $A/RespostaTexto.swift tests/RespostaTextoTests.swift
roda contexto   $A/Spark.swift $A/ContextoResposta.swift tests/ContextoTests.swift
roda persist    $A/Perfil.swift $A/Historico.swift $A/Memoria.swift $A/Decisor.swift tests/PersistenciaTests.swift
roda validacao  $A/ValidacaoResposta.swift tests/ValidacaoTests.swift
roda perfil     $A/Perfil.swift tests/PerfilTests.swift
# agente do iPhone (lógica pura: simplificação da árvore, barreira de irreversíveis, validação de ações)
roda agente     agente-iphone/Fonte/Logica.swift agente-iphone/testes/LogicaTests.swift
roda ferramentas $X/ExtFerramentas.swift $X/ExtIntegracoes.swift tests/Ajuda.swift tests/FerramentasTests.swift
python3 scripts/verificar-contraste.py | tail -1
roda integracoes $X/ExtIntegracoes.swift tests/Ajuda.swift tests/IntegracoesTests.swift
roda web        $A/Web.swift tests/Ajuda.swift tests/WebTests.swift
roda decisor     $A/Decisor.swift $X/ExtFerramentas.swift tests/Ajuda.swift tests/DecisorClassesTests.swift
roda agentebarreira agente-iphone/Fonte/Logica.swift tests/Ajuda.swift tests/AgenteBarreiraTests.swift
roda controle     $X/ExtControle.swift tests/Ajuda.swift tests/ControleIphoneTests.swift
roda visaoimagem $X/ExtVisao.swift tests/Ajuda.swift tests/VisaoImagemTests.swift
roda memoria     $A/Perfil.swift $A/Memoria.swift tests/Ajuda.swift tests/MemoriaTests.swift
roda contratos    tests/Ajuda.swift tests/ContratosEstaticosTests.swift
echo "OK: todos os testes de lógica passaram."
