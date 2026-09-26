#!/usr/bin/env bash
# A batina AAA vestida no corpo AAA (os padres com corpo de verdade, mangas
# com braco dentro): do glb da batina e do glb do corpo ate os arquivos do jogo.
#
#   tools/blender_batina/fazer_corpo.sh <glb_batina> <glb_corpo> <dir_de_trabalho>
#
# Passos:
#   dump_padre      o padre do jogo no repouso (ossos, colisores)      -> padre/romeiro.json
#   k_corpo         corpo pesado e posto nos ossos do Corpo, sem a cabeca,
#                   com as capsulas do pano medidas nele               -> corpo/corpo_jogo.blend, padre_corpo.json
#   k_dedos         formas dos dedos na malha pronta                   -> dedos/dedos.json
#   k_corpo --dedos de novo, com o repouso relaxado assado e as formas -> corpo/corpo_aaa.bin
#   gerar_corpo_aaa o ArrayMesh do corpo (+ texturas)
#   r_limpar --mangas  tira cruz e fita; as mangas ficam, soltas      -> base.blend
#                   e os tampos dos buracos com a trama do remendo    -> remendo.json
#   r_endireitar    em pe, estreita a batina, manga no braco do corpo -> reto.blend
#   r_ao            a oclusao assada, com corpo e cabeca dentro       -> batina_aaa_ao.png (+ AO dos tampos no reto.blend)
#   k_ao            a oclusao do corpo, com a batina e a cabeca       -> corpo_aaa_ao.png
#   r_grades        capuz, murca, batina e as duas mangas             -> grades/
#   r_ligar         cada vertice na grade dele                        -> obra/batina_aaa.bin
#   gerar_batina_aaa  o ArrayMesh da batina
set -euo pipefail
GLB="$1"
CORPO="$2"
T="$3"
AQUI="$(cd "$(dirname "$0")" && pwd)"
RAIZ="$(cd "$AQUI/../.." && pwd)"
BL="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"
G="${GODOT:-$RAIZ/.tools/Godot_v4.7.2-stable_win64_console.exe}"
[ -x "$G" ] || G="$RAIZ/../PSX/.tools/Godot_v4.7.2-stable_win64_console.exe"
ASSETS="$RAIZ/game/assets/monstros/padre/batina_aaa"
ASSETS_C="$RAIZ/game/assets/monstros/padre/corpo_aaa"
mkdir -p "$T/padre" "$T/corpo" "$T/dedos" "$T/grades" "$T/obra" "$ASSETS" "$ASSETS_C"
"$G" --headless --path "$RAIZ/game" res://scenes/test/dump_padre_repouso.tscn -- --saida="$T/padre" | grep "\[dump_padre\]"
"$BL" -b --python "$AQUI/../blender_corpo/k_corpo.py" -- "$CORPO" "$AQUI/../blender_corpo/cfg_corpo.json" "$T/padre/romeiro.json" "$T/corpo" | grep "\[corpo\]"
# Os dedos saem da malha pronta (indices do corpo_jogo.blend) e voltam para ela:
# o repouso relaxado assado, garra e aberta como formas.
"$BL" -b "$T/corpo/corpo_jogo.blend" --python "$AQUI/../blender_corpo/k_dedos.py" -- "$T/dedos" "$AQUI/../blender_corpo/cfg_dedos.json" --malha-fina --sem-fotos | grep "\[dedos\] mao"
"$BL" -b --python "$AQUI/../blender_corpo/k_corpo.py" -- "$CORPO" "$AQUI/../blender_corpo/cfg_corpo.json" "$T/padre/romeiro.json" "$T/corpo" --dedos="$T/dedos/dedos.json" | grep "\[corpo\]"
python "$AQUI/r_texturas.py" "$CORPO" "$ASSETS_C" corpo_aaa
"$BL" -b --python "$AQUI/r_limpar.py" -- "$GLB" "$T/base.blend" --mangas | grep "\[r_limpar\]"
"$BL" -b "$T/base.blend" --python "$AQUI/r_endireitar.py" -- "$AQUI/cfg_endireitar_corpo.json" "$T/reto.blend" | grep "\[endireitar\]"
"$BL" -b "$T/reto.blend" --python "$AQUI/r_ao.py" -- "$T/corpo/corpo_jogo.blend" "$T/padre/romeiro.json" "$ASSETS/batina_aaa_ao.png" | grep "\[ao\]"
"$BL" -b "$T/corpo/corpo_jogo.blend" --python "$AQUI/../blender_corpo/k_ao.py" -- "$T/reto.blend" "$T/padre/romeiro.json" "$ASSETS_C/corpo_aaa_ao.png" | grep "\[corpo_ao\]"
"$BL" -b "$T/reto.blend" --python "$AQUI/r_grades.py" -- "$T/corpo/padre_corpo.json" "$AQUI/cfg_grades_corpo.json" "$T/grades" | grep "\[grades\]"
"$BL" -b "$T/reto.blend" --python "$AQUI/r_ligar.py" -- "$T/grades/grades.json" "$T/grades/rotulos.json" "$T/obra" | grep "\[ligar\]"
python "$AQUI/r_texturas.py" "$GLB" "$ASSETS" batina_aaa
cp "$T/grades/grades.json" "$ASSETS/batina_aaa_grades.json"
cp "$T/remendo.json" "$ASSETS/batina_aaa_remendo.json"
"$G" --headless --path "$RAIZ/game" --import > /dev/null 2>&1 || true
"$G" --headless --path "$RAIZ/game" res://scenes/test/gerar_corpo_aaa.tscn -- --entrada="$T/corpo" | grep "\[gerar_corpo_aaa\]"
"$G" --headless --path "$RAIZ/game" res://scenes/test/gerar_batina_aaa.tscn -- --entrada="$T/obra" | grep "\[gerar_batina_aaa\]"
