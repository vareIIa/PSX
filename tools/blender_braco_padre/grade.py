"""Grade de coordenadas do mundo por cima de uma foto ortografica do b_foto.py.

python grade.py <foto> <saida> <eixo> <cx> <cy> <cz> <escala> [passo_cm=1] [lado_px]
Linhas finas a cada `passo` cm, fortes e com rotulo a cada 5x.
"""
import sys
from PIL import Image, ImageDraw

foto, saida, eixo = sys.argv[1], sys.argv[2], sys.argv[3]
c = [float(a) for a in sys.argv[4:7]]
s = float(sys.argv[7])
passo = float(sys.argv[8]) / 100.0 if len(sys.argv) > 8 else 0.01
lado = int(sys.argv[9]) if len(sys.argv) > 9 else 1400
# (eixo do mundo na direita, sinal), (eixo do mundo em cima, sinal)
MAPA = {"+x": ((2, -1), (1, 1)), "-x": ((2, 1), (1, 1)), "+z": ((0, 1), (1, 1)),
        "-z": ((0, -1), (1, 1)), "+y": ((0, -1), (2, 1)), "-y": ((0, 1), (2, 1))}
(ed, sd), (ec, sc) = MAPA[eixo]
NOMES = "xyz"
im = Image.open(foto).convert("RGB").resize((lado, lado))
d = ImageDraw.Draw(im)


def u_de(w):
	return (0.5 + (w - c[ed]) * sd / s) * lado


def v_de(w):
	return (0.5 - (w - c[ec]) * sc / s) * lado


import math
lo_d = c[ed] - s / 2
hi_d = c[ed] + s / 2
k = math.floor(lo_d / passo)
while k * passo <= hi_d:
	w = k * passo
	u = u_de(w)
	forte = k % 5 == 0
	d.line([(u, 0), (u, lado)], fill=(255, 220, 0) if forte else (120, 110, 40), width=1)
	if forte:
		d.text((u + 2, 2), "%s%.2f" % (NOMES[ed], w), fill=(255, 255, 0))
	k += 1
lo_c = c[ec] - s / 2
hi_c = c[ec] + s / 2
k = math.floor(lo_c / passo)
while k * passo <= hi_c:
	w = k * passo
	v = v_de(w)
	forte = k % 5 == 0
	d.line([(0, v), (lado, v)], fill=(0, 220, 255) if forte else (40, 100, 120), width=1)
	if forte:
		d.text((2, v + 2), "%s%.2f" % (NOMES[ec], w), fill=(0, 255, 255))
	k += 1
im.save(saida)
