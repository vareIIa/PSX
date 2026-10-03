"""As sondas da carne do rosto (`CarneDoRosto`), tiradas da malha da pele.

A carne precisa saber, no processador, que parte da cara esta mais perto do
vidro: o toque, a velocidade dele e onde ele nasce (a onda, o hematoma). Ler a
malha de volta no jogo custa quadro (85 mil vertices), entao a forma vai em
pontos: a pele de fora (sem a goela), reduzida numa grade de SONDA_VOXEL, so a
metade que pode encostar num vidro (a frente e o alto da cabeca).

Nao depende de indice nem de atributo novo: e a posicao de repouso, no espaco
da malha (rosto para -Z, +x a direita dele). Com a malha nova da boca
(`cabeca_boca.glb`), rode de novo e as sondas saem dela.

	python tools/gerar_mapa_carne.py [malha.glb]

Reescreve o bloco entre `# SONDAS-INICIO` e `# SONDAS-FIM` em
`game/src/render/carne_do_rosto.gd`.
"""
import json
import os
import struct
import sys

import numpy as np

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PADRE = os.path.join(RAIZ, 'game', 'assets', 'monstros', 'padre')
ALVO = os.path.join(RAIZ, 'game', 'src', 'render', 'carne_do_rosto.gd')
# Lado da celula da grade (m): a 16 mm a flecha de uma cara de raio 8 cm entre
# duas sondas e de 0,4 mm, abaixo do que o toque precisa.
SONDA_VOXEL = 0.016


def ler_pele(caminho):
	with open(caminho, 'rb') as f:
		dados = f.read()
	_, _, total = struct.unpack_from('<III', dados, 0)
	off = 12
	chunks = []
	while off < total:
		n, _tipo = struct.unpack_from('<II', dados, off)
		chunks.append(dados[off + 8: off + 8 + n])
		off += 8 + n
	js = json.loads(chunks[0])
	b = chunks[1]
	malha = [m for m in js['meshes'] if m.get('name', '').startswith('Pele')][0]
	prim = malha['primitives'][0]

	def acc(i):
		a = js['accessors'][i]
		bv = js['bufferViews'][a['bufferView']]
		comp = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[a['type']]
		dt = {5126: np.float32, 5123: np.uint16, 5125: np.uint32, 5121: np.uint8}[a['componentType']]
		o = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
		arr = np.frombuffer(b, dtype=dt, count=a['count'] * comp, offset=o).reshape(a['count'], comp)
		if a.get('normalized') and dt != np.float32:
			arr = arr.astype(np.float32) / np.iinfo(dt).max
		return arr.astype(np.float64)

	at = prim['attributes']
	v = acc(at['POSITION'])
	cor = acc(at['COLOR_0']) if 'COLOR_0' in at else np.zeros((len(v), 4))
	return v, cor


def sondas(v, cor):
	# A pele de fora: a goela (COLOR.a) e a boca por dentro nunca encostam.
	fora = cor[:, 3] < 0.5
	# A metade que encosta: a frente (z < 0,04) e o alto (y > 0,06). A nuca e o
	# pescoco de tras nao batem em vidro nenhum.
	parte = (v[:, 2] < 0.04) | (v[:, 1] > 0.06)
	# O pescoco abaixo do queixo so pela frente.
	parte &= (v[:, 1] > -0.13) | (v[:, 2] < -0.005)
	p = v[fora & parte]
	chave = np.floor(p / SONDA_VOXEL).astype(np.int64)
	_, inv = np.unique(chave, axis=0, return_inverse=True)
	inv = inv.reshape(-1)
	n = inv.max() + 1
	soma = np.zeros((n, 3))
	np.add.at(soma, inv, p)
	cont = np.bincount(inv, minlength=n)
	media = soma / cont[:, None]
	# A media da celula cai dentro da curva: fica o vertice mais perto dela,
	# que esta na pele.
	melhor = np.full(n, np.inf)
	escolha = np.zeros((n, 3))
	d = np.linalg.norm(p - media[inv], axis=1)
	ordem = np.argsort(d)
	visto = np.zeros(n, bool)
	for i in ordem:
		k = inv[i]
		if not visto[k]:
			visto[k] = True
			escolha[k] = p[i]
	return escolha


def escrever(pts):
	with open(ALVO, 'r', encoding='utf-8', newline='') as f:
		txt = f.read()
	a = txt.index('# SONDAS-INICIO')
	b = txt.index('# SONDAS-FIM')
	linhas = ['# SONDAS-INICIO (tools/gerar_mapa_carne.py, %d pontos)\n' % len(pts),
		'const SONDAS := [\n']
	lote = []
	for q in pts:
		lote.append('Vector3(%.4f, %.4f, %.4f)' % tuple(q))
		if len(lote) == 3:
			linhas.append('\t' + ', '.join(lote) + ',\n')
			lote = []
	if lote:
		linhas.append('\t' + ', '.join(lote) + ',\n')
	linhas.append(']\n')
	lo = pts.min(0)
	hi = pts.max(0)
	linhas.append('## A caixa das sondas: longe dela, nem se olha o vidro.\n')
	linhas.append('const CAIXA_SONDAS := AABB(Vector3(%.4f, %.4f, %.4f), Vector3(%.4f, %.4f, %.4f))\n'
		% (lo[0], lo[1], lo[2], hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]))
	txt = txt[:a] + ''.join(linhas) + txt[b:]
	with open(ALVO, 'w', encoding='utf-8', newline='') as f:
		f.write(txt)


def main():
	caminho = sys.argv[1] if len(sys.argv) > 1 else os.path.join(PADRE, 'cabeca.glb')
	v, cor = ler_pele(caminho)
	pts = sondas(v, cor)
	print('%s: %d vertices, %d sondas' % (os.path.basename(caminho), len(v), len(pts)))
	if os.path.exists(ALVO):
		escrever(pts)
		print('escrito em', ALVO)


if __name__ == '__main__':
	main()
