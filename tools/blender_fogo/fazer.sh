#!/usr/bin/env bash
# A chama do incendio do capo do zero: simula (Mantaflow), fotografa (Cycles
# na placa) e monta o flipbook do jogo.
#
#   tools/blender_fogo/fazer.sh <dir_de_trabalho>
#
# Passos:
#   r_fogo        bake de 99 quadros (grade 176, sem ruido), 60 quadros de
#                 256x512 em cinza a partir do 40                -> <dir>/quadros
#   montar_atlas  recorta a lingua (sem a lamina lisa do pe), fecha o laco
#                 (12 quadros), 8x6 quadros de 160x224            -> fx_fogo_chama.png
# Depois: `godot --headless --path game --import` (o .import pede VRAM
# comprimida em canal unico, BC4, com mipmap: ~1,1 MB na placa).
#
# O Mantaflow grava `waveletNoiseTile.bin` na pasta de onde o Blender roda:
# roda-se de dentro do dir de trabalho para ele nao cair no repositorio.
set -euo pipefail
T="$(cd "$1" 2>/dev/null || mkdir -p "$1"; cd "$1" && pwd)"
AQUI="$(cd "$(dirname "$0")" && pwd)"
RAIZ="$(cd "$AQUI/../.." && pwd)"
BL="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"
( cd "$T" && "$BL" -b --python "$AQUI/r_fogo.py" -- "$T" 176 60 256 6 0 | grep "\[r_fogo\]" )
python "$AQUI/montar_atlas.py" "$T" "$RAIZ/game/assets/textures/fx_fogo_chama.png"
