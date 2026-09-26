#!/usr/bin/env bash
# A batina AAA do zero: da malha do gerador (CONTEXT) ate os arquivos do jogo.
#
#   tools/blender_batina/fazer.sh <glb_do_gerador> <dir_de_trabalho>
#
# Passos (ver o cabecalho de cada script):
#   r_limpar      tira cruz, fita e mangas; tapa os buracos       -> base.blend
#   r_endireitar  em pe, na pessoa de 1,72 m, tudo em triangulo   -> reto.blend
#   dump_padre    o padre do jogo no repouso (ossos, colisores)   -> padre/romeiro.json
#   r_grades      as tres grades, o repouso pendurado, os rotulos -> grades/
#   r_ligar       cada vertice na grade dele                      -> obra/batina_aaa.bin
#   r_texturas    as texturas PBR do glb, sem recodificar
#   gerar_batina_aaa  o ArrayMesh do jogo
set -euo pipefail
GLB="$1"
T="$2"
AQUI="$(cd "$(dirname "$0")" && pwd)"
RAIZ="$(cd "$AQUI/../.." && pwd)"
BL="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"
G="${GODOT:-$RAIZ/.tools/Godot_v4.7.2-stable_win64_console.exe}"
[ -x "$G" ] || G="$RAIZ/../PSX/.tools/Godot_v4.7.2-stable_win64_console.exe"
ASSETS="$RAIZ/game/assets/monstros/padre/batina_aaa"
mkdir -p "$T/padre" "$T/grades" "$T/obra" "$ASSETS"
"$BL" -b --python "$AQUI/r_limpar.py" -- "$GLB" "$T/base.blend" | grep "\[r_limpar\]"
"$BL" -b "$T/base.blend" --python "$AQUI/r_endireitar.py" -- "$AQUI/cfg_endireitar.json" "$T/reto.blend" | grep "\[endireitar\]"
"$G" --headless --path "$RAIZ/game" res://scenes/test/dump_padre_repouso.tscn -- --saida="$T/padre" | grep "\[dump_padre\]"
"$BL" -b "$T/reto.blend" --python "$AQUI/r_grades.py" -- "$T/padre/romeiro.json" "$AQUI/cfg_grades.json" "$T/grades" | grep "\[grades\]"
"$BL" -b "$T/reto.blend" --python "$AQUI/r_ligar.py" -- "$T/grades/grades.json" "$T/grades/rotulos.json" "$T/obra" | grep "\[ligar\]"
python "$AQUI/r_texturas.py" "$GLB" "$ASSETS" batina_aaa
cp "$T/grades/grades.json" "$ASSETS/batina_aaa_grades.json"
cp "$T/remendo.json" "$ASSETS/batina_aaa_remendo.json"
"$G" --headless --path "$RAIZ/game" --import > /dev/null 2>&1 || true
"$G" --headless --path "$RAIZ/game" res://scenes/test/gerar_batina_aaa.tscn -- --entrada="$T/obra" | grep "\[gerar_batina_aaa\]"
