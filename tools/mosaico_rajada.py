"""Mosaico de uma rajada (`--susto-rajada=<pasta>` da abertura): python tools/mosaico_rajada.py <pasta_r> <t0> <t1> <saida.png> [colunas] [n]

Escolhe `n` quadros (padrao 16) igualmente espacados entre t0 e t1 (relogio da
cena) e monta uma grade com o tempo escrito em cada um.
"""
import os
import sys
from PIL import Image, ImageDraw

pasta, t0, t1, saida = sys.argv[1], float(sys.argv[2]), float(sys.argv[3]), sys.argv[4]
colunas = int(sys.argv[5]) if len(sys.argv) > 5 else 4
n = int(sys.argv[6]) if len(sys.argv) > 6 else 16
quadros = []
for f in os.listdir(pasta):
	if f.startswith('r_') and f.endswith('.png'):
		quadros.append((float(f[2:-4]), f))
quadros.sort()
dentro = [q for q in quadros if t0 <= q[0] <= t1]
if not dentro:
	print('nada entre', t0, t1, 'de', quadros[0][0] if quadros else None, quadros[-1][0] if quadros else None)
	sys.exit(1)
if len(dentro) > n:
	passo = (len(dentro) - 1) / (n - 1)
	dentro = [dentro[round(i * passo)] for i in range(n)]
w, h = 320, 180
linhas = (len(dentro) + colunas - 1) // colunas
out = Image.new('RGB', (w * colunas, h * linhas))
d = ImageDraw.Draw(out)
for i, (t, f) in enumerate(dentro):
	im = Image.open(os.path.join(pasta, f)).convert('RGB').resize((w, h))
	x, y = (i % colunas) * w, (i // colunas) * h
	out.paste(im, (x, y))
	d.rectangle([x, y, x + 52, y + 13], fill=(0, 0, 0))
	d.text((x + 3, y + 1), '%.2f' % t, fill=(255, 255, 0))
out.save(saida)
print(saida, len(dentro), 'quadros', dentro[0][0], '->', dentro[-1][0])
