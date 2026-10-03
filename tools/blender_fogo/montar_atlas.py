"""Junta os quadros da chama (`r_fogo.py`) no flipbook do `IncendioDoCapo`.

    python tools/blender_fogo/montar_atlas.py <dir_de_trabalho> <saida.png>

- recorta a caixa que a chama ocupa em todos os quadros, sempre a mesma, sem
  a lamina lisa do pe (ver X0..Y1);
- fecha o laco: os ultimos LACO quadros se fundem nos que vieram antes do
  primeiro, e o quadro 0 continua o ultimo sem salto (o flipbook toca em laco
  nas particulas que vivem mais que ele);
- grava em cinza (so a intensidade: a cor e a rampa do shader do jogo), em
  COLUNAS x LINHAS quadros.
"""
import os
import sys

import numpy as np
from PIL import Image

DIR, SAIDA = sys.argv[1], sys.argv[2]
COLUNAS, LINHAS = 8, 6
N = COLUNAS * LINHAS
LACO = 12
# A caixa (px do quadro de 256x512 do r_fogo): a chama vai de x 63 a 196 e de
# y 199 a 505 no pior quadro. Os 30 cm de baixo (y > 400) sao a lamina lisa
# que sai das bocas antes de virar turbulencia: ficam de fora. O pe do quadro
# ja e chama larga e revolta, e no jogo ele nasce atras da borda da chapa.
X0, X1 = 48, 208
Y0, Y1 = 176, 400

quadros = sorted(f for f in os.listdir(os.path.join(DIR, "quadros")) if f.endswith(".png"))
if len(quadros) < N + LACO:
    sys.exit("faltam quadros: %d, pede %d" % (len(quadros), N + LACO))
q = [np.asarray(Image.open(os.path.join(DIR, "quadros", f)).convert("L"), dtype=np.float32)
     [Y0:Y1, X0:X1] for f in quadros[:N + LACO]]
saida = []
for i in range(N):
    a = q[i + LACO]
    if i >= N - LACO:
        # Do quadro N-LACO em diante a sequencia desliza para o comeco: no
        # ultimo ela ja e quase o quadro LACO-1, e o 0 (= q[LACO]) vem depois.
        w = (i - (N - LACO) + 1) / (LACO + 1)
        a = a * (1.0 - w) + q[i - (N - LACO)] * w
    saida.append(a)
h, w = saida[0].shape
atlas = np.zeros((h * LINHAS, w * COLUNAS), np.float32)
for i, a in enumerate(saida):
    c, l = i % COLUNAS, i // COLUNAS
    atlas[l * h:(l + 1) * h, c * w:(c + 1) * w] = a
# A borda de cada quadro fica preta: com mipmap, a chama do vizinho nao vaza.
for c in range(COLUNAS + 1):
    atlas[:, max(0, c * w - 1):c * w + 1] = 0.0
for l in range(LINHAS + 1):
    atlas[max(0, l * h - 1):l * h + 1, :] = 0.0
Image.fromarray(np.clip(atlas, 0, 255).astype(np.uint8), "L").save(SAIDA, optimize=True)
print("[montar_atlas] %s: %d quadros de %dx%d em %dx%d" % (SAIDA, N, w, h, COLUNAS, LINHAS))
