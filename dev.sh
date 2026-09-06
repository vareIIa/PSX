#!/usr/bin/env bash
# Fluxo de trabalho do projeto. Rode da raiz do repositorio.
#
#   ./dev.sh check          niveis 1 e 2 de validacao — use antes de todo commit
#   ./dev.sh import         reimporta assets depois de adicionar arquivo
#   ./dev.sh test           so a suite de assercoes
#   ./dev.sh run            abre o jogo
#   ./dev.sh edit           abre o editor
#   ./dev.sh shot [preset]  captura a cena principal num preset de nevoa
#   ./dev.sh walk           verifica que o controlador move de verdade
#   ./dev.sh sheet          refaz a folha de comparacao com as referencias
#   ./dev.sh textures       rebaixa as texturas CC0 e regenera os materiais
#
# Niveis de validacao em docs/PADROES-ENGENHARIA.md.

set -euo pipefail
cd "$(dirname "$0")"

GODOT=".tools/Godot_v4.7.2-stable_win64_console.exe"
GAME="game"
CAPS="$(pwd)/captures"

[ -x "$GODOT" ] || { echo "Godot nao encontrado em $GODOT"; exit 1; }

nivel1() {
  echo "== nivel 1: carga e sintaxe =="
  local saida
  saida="$("$GODOT" --headless --path "$GAME" --quit 2>&1)"
  echo "$saida"
  if echo "$saida" | grep -qiE "SCRIPT ERROR|ERROR:|WARNING:|Parse Error"; then
    echo ">> nivel 1 FALHOU"; return 1
  fi
  echo ">> nivel 1 ok"
}

nivel2() {
  echo "== nivel 2: contrato PSX =="
  "$GODOT" --headless --path "$GAME" --script res://tests/run_tests.gd
}

case "${1:-check}" in
  check)    nivel1 && nivel2 ;;
  import)   "$GODOT" --headless --path "$GAME" --import ;;
  test)     nivel2 ;;
  run)      "$GODOT" --path "$GAME" ;;
  edit)     "$GODOT" -e --path "$GAME" ;;
  walk)     python tools/verificar_movimento.py ;;
  textures) python tools/baixar_texturas.py && python tools/gerar_materiais.py && "$0" import ;;
  sheet)    python tools/montar_comparacao.py ;;
  shot)
    preset="${2:-off}"
    mkdir -p "$CAPS"
    "$GODOT" --path "$GAME" --resolution 1280x720 -- \
      --fog="$preset" --shot="$CAPS/fase1_$preset.png" --shot-frame=40 --shot-quit
    echo "captures/fase1_$preset.png"
    ;;
  *) sed -n '2,20p' "$0"; exit 1 ;;
esac
