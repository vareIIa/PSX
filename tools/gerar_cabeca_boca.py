"""A pele do padre com a boca nova (`boca_padre_forma.py`): a cabeca de
`gerar_padre.py` com a fenda torta, os labios de verdade e os sulcos, a malha
mais fina em volta da boca e os rasgos de cada cabecada em blend shapes.

    python tools/gerar_cabeca_boca.py

Gera game/assets/monstros/padre/boca/cabeca_boca.glb, so com a `Pele`, que a
`CabecaDoPadre` usa quando a boca nova esta ligada (os de fundo continuam com
`cabeca.glb`).

Por que a malha fina: o marching cubes da cabeca anda de 1,7 em 1,7 mm; o
labio de cima tem 5 mm, o tuberculo 1 mm e um rasgo 2 mm, e nessa grade tudo
isso vira calombo. As arestas cujo meio cai perto da boca sao divididas (duas
vezes, ate ~0,4 mm), com os triangulos vizinhos divididos junto (sem fenda), e
cada vertice novo e levado de volta a superficie pelo gradiente do campo.

Atributos: os da `gerar_padre.py` (COLOR_0 olheira, labio, oclusao, goela;
TEXCOORD_0 queixada, veia) e mais:
  TEXCOORD_1.x  o rasgo: golpe em que abre (1, 2, 3) + 0,95 x a forca (0..1);
                0 onde nada rasga
  TEXCOORD_1.y  o inchaco dos labios (0..1)
Blend shapes `golpe1`, `golpe2`, `golpe3`: o deslocamento de cada golpe,
incremental (a cena poe o peso k em clamp(dano - (k - 1), 0, 1)).
"""
import json
import os
import struct
import sys

import numpy as np

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
import gerar_padre as gp  # noqa: E402
import boca_padre_forma as forma  # noqa: E402

RAIZ = os.path.dirname(AQUI)
SAIDA = os.path.join(RAIZ, 'game', 'assets', 'monstros', 'padre', 'boca', 'cabeca_boca.glb')

# A regiao que ganha malha fina: um elipsoide em volta da boca (os cantos, o
# rasgo da bochecha, o filtro e o sulco nasolabial).
FINA_C = np.array([0.0, -0.064, -0.090])
FINA_R = np.array([0.052, 0.034, 0.028])
FINA_VEZES = 2


def na_regiao(p):
	return np.sum(((p - FINA_C) / FINA_R) ** 2, axis=-1) < 1.0


def projetar(p, f, vezes=3):
	for _ in range(vezes):
		d = f(p)
		g = gp.gradiente(f, p, 0.0001)
		p = p - g * d[:, None]
	return p


def refinar(v, fa, f):
	"""Divide as arestas cujo meio esta na regiao (1, 2 ou 3 por triangulo, sem
	fenda) e projeta os vertices novos no campo."""
	m = len(fa)
	e = np.concatenate([fa[:, [0, 1]], fa[:, [1, 2]], fa[:, [2, 0]]])
	es = np.sort(e, axis=1)
	uniq, inv = np.unique(es, axis=0, return_inverse=True)
	inv = inv.reshape(-1)
	meio = (v[uniq[:, 0]] + v[uniq[:, 1]]) * 0.5
	divide = na_regiao(meio)
	novo = np.full(len(uniq), -1, np.int64)
	novo[divide] = len(v) + np.arange(divide.sum())
	pv = projetar(meio[divide], f)
	v = np.concatenate([v, pv])
	ab, bc, ca = novo[inv[:m]], novo[inv[m:2 * m]], novo[inv[2 * m:]]
	a, b, c = fa[:, 0], fa[:, 1], fa[:, 2]
	sa, sb, sc = ab >= 0, bc >= 0, ca >= 0
	out = []
	k = ~sa & ~sb & ~sc
	out.append(np.stack([a[k], b[k], c[k]], 1))
	k = sa & sb & sc
	out += [np.stack([a[k], ab[k], ca[k]], 1), np.stack([ab[k], b[k], bc[k]], 1),
		np.stack([ca[k], bc[k], c[k]], 1), np.stack([ab[k], bc[k], ca[k]], 1)]
	k = sa & ~sb & ~sc
	out += [np.stack([a[k], ab[k], c[k]], 1), np.stack([ab[k], b[k], c[k]], 1)]
	k = ~sa & sb & ~sc
	out += [np.stack([a[k], b[k], bc[k]], 1), np.stack([a[k], bc[k], c[k]], 1)]
	k = ~sa & ~sb & sc
	out += [np.stack([a[k], b[k], ca[k]], 1), np.stack([ca[k], b[k], c[k]], 1)]
	k = sa & sb & ~sc
	out += [np.stack([ab[k], b[k], bc[k]], 1), np.stack([a[k], ab[k], bc[k]], 1),
		np.stack([a[k], bc[k], c[k]], 1)]
	k = ~sa & sb & sc
	out += [np.stack([bc[k], c[k], ca[k]], 1), np.stack([a[k], b[k], bc[k]], 1),
		np.stack([a[k], bc[k], ca[k]], 1)]
	k = sa & ~sb & sc
	out += [np.stack([a[k], ab[k], ca[k]], 1), np.stack([ab[k], b[k], c[k]], 1),
		np.stack([ab[k], c[k], ca[k]], 1)]
	return v, np.concatenate(out)


def normais_das_faces(p, f):
	n = np.zeros_like(p)
	fn = np.cross(p[f[:, 1]] - p[f[:, 0]], p[f[:, 2]] - p[f[:, 0]])
	for k in range(3):
		np.add.at(n, f[:, k], fn)
	return n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)


def escrever(caminho, pos, nor, cor, uv, uv2, idx, alvos, nomes):
	bin_ = bytearray()
	views, acc = [], []

	def add(arr, alvo, tipo, comp, minmax=False):
		arr = np.ascontiguousarray(arr)
		while len(bin_) % 4:
			bin_.append(0)
		off = len(bin_)
		bin_.extend(arr.tobytes())
		vw = {'buffer': 0, 'byteOffset': off, 'byteLength': arr.nbytes}
		if alvo:
			vw['target'] = alvo
		views.append(vw)
		a = {'bufferView': len(views) - 1, 'componentType': comp, 'count': int(arr.shape[0]), 'type': tipo}
		if minmax:
			a['min'] = arr.min(0).tolist()
			a['max'] = arr.max(0).tolist()
		acc.append(a)
		return len(acc) - 1

	at = {
		'POSITION': add(pos.astype(np.float32), 34962, 'VEC3', 5126, True),
		'NORMAL': add(nor.astype(np.float32), 34962, 'VEC3', 5126),
		'COLOR_0': add(cor.astype(np.float32), 34962, 'VEC4', 5126),
		'TEXCOORD_0': add(uv.astype(np.float32), 34962, 'VEC2', 5126),
		'TEXCOORD_1': add(uv2.astype(np.float32), 34962, 'VEC2', 5126),
	}
	ai = add(idx.astype(np.uint32).reshape(-1), 34963, 'SCALAR', 5125)
	targets = []
	for dp, dn in alvos:
		targets.append({'POSITION': add(dp.astype(np.float32), 34962, 'VEC3', 5126, True),
			'NORMAL': add(dn.astype(np.float32), 34962, 'VEC3', 5126)})
	while len(bin_) % 4:
		bin_.append(0)
	doc = {'asset': {'version': '2.0', 'generator': 'tools/gerar_cabeca_boca.py'},
		'scene': 0, 'scenes': [{'nodes': [0]}], 'nodes': [{'name': 'Pele', 'mesh': 0}],
		'meshes': [{'name': 'Pele', 'primitives': [{'attributes': at, 'indices': ai, 'targets': targets}],
			'weights': [0.0] * len(targets), 'extras': {'targetNames': nomes}}],
		'accessors': acc, 'bufferViews': views, 'buffers': [{'byteLength': len(bin_)}]}
	js = json.dumps(doc, separators=(',', ':')).encode()
	while len(js) % 4:
		js += b' '
	with open(caminho, 'wb') as f:
		f.write(struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(bin_)))
		f.write(struct.pack('<II', len(js), 0x4E4F534A))
		f.write(js)
		f.write(struct.pack('<II', len(bin_), 0x004E4942))
		f.write(bin_)


def main():
	lo = (-0.095, -0.212, -0.122)
	hi = (0.095, 0.132, 0.122)
	print('pele: campo...')
	v, fa, _, _ = gp.superficie(forma.cabeca, lo, hi, gp.VOXEL)
	print('pele: %d vertices, %d triangulos' % (len(v), len(fa)))
	for i in range(FINA_VEZES):
		v, fa = refinar(v, fa, forma.cabeca)
		print('pele fina %d: %d vertices, %d triangulos' % (i + 1, len(v), len(fa)))
	n = gp.gradiente(forma.cabeca, v)
	fa = gp.orientar(v, fa, n)
	ao = gp.oclusao(forma.cabeca, v, n)
	olheira, labio, goela, queixada, veia = forma.mascaras(v)
	cor = np.stack([olheira, labio, ao, goela], -1)
	uv = np.stack([queixada, veia], -1)
	desl, carne, inch = forma.rasgos(v)
	# O rasgo: o primeiro golpe que abre aquele vertice, e a forca.
	golpe = np.zeros(len(v))
	forca = np.zeros(len(v))
	for k in (2, 1, 0):
		tem = carne[k] > 0.12
		golpe = np.where(tem, k + 1, golpe)
		forca = np.where(tem, np.maximum(forca, carne[k]), forca)
	uv2 = np.stack([np.where(golpe > 0, golpe + 0.95 * np.clip(forca, 0, 1), 0.0), inch], -1)
	# Os blend shapes: posicao incremental e a normal que muda com ela.
	alvos = []
	base = v.copy()
	nb = normais_das_faces(base, fa)
	for k in range(3):
		prox = base + desl[k]
		nk = normais_das_faces(prox, fa)
		alvos.append((desl[k], nk - nb))
		base, nb = prox, nk
		print('golpe %d: %d vertices mexem, ate %.1f mm' % (k + 1, int((np.abs(desl[k]).sum(1) > 1e-5).sum()),
			np.linalg.norm(desl[k], axis=1).max() * 1000))
	os.makedirs(os.path.dirname(SAIDA), exist_ok=True)
	escrever(SAIDA, v, n, cor, uv, uv2, fa, alvos, ['golpe1', 'golpe2', 'golpe3'])
	print('ok', SAIDA)


if __name__ == '__main__':
	main()
