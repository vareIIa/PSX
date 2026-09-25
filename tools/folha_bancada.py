"""Folha de contato das fotos da bancada de monstros (`BancadaMonstros`).

    python tools/folha_bancada.py <pasta> <saida.png> [filtro] [colunas] [largura]

Junta os PNG da pasta cujo nome contem `filtro` (padrao: todos), em ordem de
nome, numa grade com o nome escrito em cada um. `largura` e a largura de cada
celula em pixels (padrao 960). Para julgar em 4K, abra a foto sozinha; a folha e
para comparar planos e luzes lado a lado.
"""
import os
import sys
from PIL import Image, ImageDraw

pasta, saida = sys.argv[1], sys.argv[2]
filtro = sys.argv[3] if len(sys.argv) > 3 else ''
colunas = int(sys.argv[4]) if len(sys.argv) > 4 else 4
w = int(sys.argv[5]) if len(sys.argv) > 5 else 960
nomes = sorted(f for f in os.listdir(pasta) if f.endswith('.png') and filtro in f)
if not nomes:
	print('nenhuma foto em', pasta, 'com', repr(filtro))
	sys.exit(1)
primeira = Image.open(os.path.join(pasta, nomes[0]))
h = round(w * primeira.height / primeira.width)
linhas = (len(nomes) + colunas - 1) // colunas
out = Image.new('RGB', (w * colunas, h * linhas))
d = ImageDraw.Draw(out)
for i, f in enumerate(nomes):
	im = Image.open(os.path.join(pasta, f)).convert('RGB').resize((w, h), Image.LANCZOS)
	x, y = (i % colunas) * w, (i // colunas) * h
	out.paste(im, (x, y))
	d.rectangle([x, y, x + 8 * len(f) + 8, y + 16], fill=(0, 0, 0))
	d.text((x + 4, y + 2), f[:-4], fill=(255, 255, 0))
out.save(saida)
print(saida, len(nomes), 'fotos')
