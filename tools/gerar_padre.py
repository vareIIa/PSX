"""A cabeca do padre principal (Parte 1 de INTRO-PADRE/PLANO_MONSTROS.md).

    python tools/gerar_padre.py [--so-malha] [--so-texturas] [--previa DIR]

Gera em game/assets/monstros/padre/:
  cabeca.glb     a pele (malha esculpida) e a boca (dentes e gengiva)
  pele_mapa.png  4096 tileavel RGBA: R altura da racha, G veias, B manchas, A poros
  pele_n.png     4096 tileavel: a normal da racha e dos poros (OpenGL, y para cima)

A referencia e a criatura em INTRO-PADRE/referencia/padre_principal_*.png: calvo,
olho redondo arregalado em olheira funda, nariz pequeno, boca larga aberta e
torta com dentes pequenos, pele branca craquelada com veias mortas, pescoco fino.

Como a cabeca e feita
---------------------
Um campo de distancia (SDF) de elipsoides e capsulas somados e subtraidos com
uniao suave — cranio, massa do rosto, arcada, macas, orbitas, nariz, boca, orelhas,
pescoco com tendoes — mais um ruido de carne de um milimetro. O marching cubes
tira a superficie; a normal sai do gradiente do campo, lisa. Unidades em metros,
na medida de uma pessoa de 1,72 m (o `Corpo` escala), com a origem no centro da
caixa de cabeca do `Corpo` e o rosto para -Z.

O que vai por vertice (a textura de detalhe e tileavel e amostrada em triplanar
no espaco do objeto, entao o que e de LUGAR vai no vertice):
  COLOR_0.r  olheira (1 no aro escuro em volta do olho)
  COLOR_0.g  labio (1 na borda da boca)
  COLOR_0.b  oclusao ambiente (1 aberto, 0 fundo), calculada no proprio campo
  COLOR_0.a  goela (1 dentro da boca)
  TEXCOORD_0.x  peso da queixada (1 gira inteiro com a boca abrindo)
  TEXCOORD_0.y  onde a veia aparece mais (temporas, pescoco, em volta dos olhos)
Na boca: COLOR_0.r gengiva, .g podre (mancha do dente), .b oclusao.
"""
import json
import os
import struct
import sys

import numpy as np
from PIL import Image
from skimage import measure

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SAIDA = os.path.join(RAIZ, 'game', 'assets', 'monstros', 'padre')

# --- medidas (m) -------------------------------------------------------------
# O olho: centro, raio do globo. O resto do rosto se mede dele.
OLHO = np.array([0.031, 0.004, -0.0590])
# A orbita fica onde estava: o globo recua para dentro dela, e nao ela com ele.
ORBITA = np.array([0.031, 0.005, -0.0755])
OLHO_R = 0.0125
# A boca: centro da abertura, meia largura, meia altura, e o quanto os cantos
# sobem (m por m^2 de x): o sorriso torto que nao desmancha.
BOCA_C = np.array([0.0, -0.060, -0.093])
BOCA_MEIA = np.array([0.031, 0.0095])
BOCA_CURVA = 11.0
# O pivo da queixada (a articulacao, na frente da orelha).
PIVO = np.array([0.0, -0.018, 0.030])
# Arcada dos dentes: z no meio e curvatura (z = z0 + a x^2).
ARCADA_Z = -0.087
ARCADA_A = 11.0
VOXEL = 0.0017
VOXEL_BOCA = 0.00035
TEX = 4096

rng = np.random.default_rng(1977)


# --- SDF --------------------------------------------------------------------
def elipsoide(p, c, r):
	q = (p - c) / r
	k0 = np.linalg.norm(q, axis=-1)
	k1 = np.linalg.norm(q / r, axis=-1)
	return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)


def capsula(p, a, b, r):
	pa = p - a
	ba = b - a
	h = np.clip((pa @ ba) / (ba @ ba), 0.0, 1.0)
	return np.linalg.norm(pa - h[..., None] * ba, axis=-1) - r


def smin(a, b, k):
	h = np.maximum(k - np.abs(a - b), 0.0) / k
	return np.minimum(a, b) - h * h * k * 0.25


def smax(a, b, k):
	return -smin(-a, -b, k)


def espelho(p):
	q = p.copy()
	q[..., 0] = np.abs(q[..., 0])
	return q


class Ruido3:
	"""Ruido de valor 3D suave, de uma grade aleatoria fixa."""

	def __init__(self, n=48, semente=5):
		g = np.random.default_rng(semente)
		self.g = g.random((n, n, n)).astype(np.float32)
		self.n = n

	def __call__(self, p, escala):
		q = p * escala + 7.3
		i = np.floor(q).astype(np.int64)
		f = q - i
		f = f * f * (3.0 - 2.0 * f)
		n = self.n
		i0 = i % n
		i1 = (i + 1) % n
		g = self.g
		def v(a, b, c):
			return g[a[..., 0], b[..., 1], c[..., 2]]
		x0 = v(i0, i0, i0) * (1 - f[..., 0]) + v(i1, i0, i0) * f[..., 0]
		x1 = v(i0, i1, i0) * (1 - f[..., 0]) + v(i1, i1, i0) * f[..., 0]
		x2 = v(i0, i0, i1) * (1 - f[..., 0]) + v(i1, i0, i1) * f[..., 0]
		x3 = v(i0, i1, i1) * (1 - f[..., 0]) + v(i1, i1, i1) * f[..., 0]
		y0 = x0 * (1 - f[..., 1]) + x1 * f[..., 1]
		y1 = x2 * (1 - f[..., 1]) + x3 * f[..., 1]
		return y0 * (1 - f[..., 2]) + y1 * f[..., 2]


RUIDO = Ruido3()


def boca_abertura(p):
	"""A fenda da boca: elipsoide achatado cujo eixo sobe nos cantos."""
	q = p - BOCA_C
	q = q.copy()
	q[..., 1] -= BOCA_CURVA * q[..., 0] ** 2
	return elipsoide(q, np.zeros(3), np.array([BOCA_MEIA[0], BOCA_MEIA[1], 0.022]))


def boca_cavidade(p):
	return elipsoide(p, np.array([0.0, -0.064, -0.062]), np.array([0.027, 0.019, 0.030]))


def cabeca(p):
	m = espelho(p)
	# Cranio: alto e um pouco comprido para tras, calvo.
	d = elipsoide(p, np.array([0.0, 0.026, 0.012]), np.array([0.071, 0.089, 0.096]))
	# A massa do rosto e a queixada.
	d = smin(d, elipsoide(p, np.array([0.0, -0.040, -0.032]), np.array([0.057, 0.066, 0.068])), 0.035)
	d = smin(d, elipsoide(m, np.array([0.044, -0.060, -0.006]), np.array([0.015, 0.026, 0.032])), 0.02)
	d = smin(d, elipsoide(p, np.array([0.0, -0.098, -0.070]), np.array([0.019, 0.015, 0.019])), 0.016)
	# O meio do rosto para a frente (maxila): sem ela o rosto era um prato.
	d = smin(d, elipsoide(p, np.array([0.0, -0.040, -0.072]), np.array([0.036, 0.034, 0.030])), 0.02)
	# Arcada da sobrancelha, sem pelo, e as macas altas.
	d = smin(d, capsula(m, np.array([0.0, 0.026, -0.080]), np.array([0.046, 0.024, -0.071]), 0.010), 0.016)
	d = smin(d, elipsoide(m, np.array([0.046, -0.010, -0.058]), np.array([0.019, 0.013, 0.021])), 0.014)
	# Bochecha chupada debaixo da maca, e a tempora funda.
	d = smax(d, -elipsoide(m, np.array([0.049, -0.044, -0.066]), np.array([0.018, 0.020, 0.016])), 0.02)
	d = smax(d, -elipsoide(m, np.array([0.074, 0.022, -0.036]), np.array([0.011, 0.024, 0.022])), 0.018)
	# Orbitas: o aro ao redor de um olho sem palpebra.
	d = smax(d, -elipsoide(m, ORBITA,
		np.array([0.0190, 0.0172, 0.0165])), 0.006)
	# Nariz pequeno e achatado: ponte, ponta, asas e narinas.
	d = smin(d, capsula(p, np.array([0.0, 0.004, -0.083]), np.array([0.0, -0.027, -0.104]), 0.0065), 0.012)
	d = smin(d, elipsoide(p, np.array([0.0, -0.031, -0.104]), np.array([0.010, 0.0085, 0.009])), 0.008)
	d = smin(d, elipsoide(m, np.array([0.0105, -0.034, -0.098]), np.array([0.0075, 0.0065, 0.0075])), 0.006)
	d = smax(d, -elipsoide(m, np.array([0.0062, -0.039, -0.102]), np.array([0.0032, 0.0022, 0.0048])), 0.002)
	# Labios finos em volta da fenda, e a fenda e a boca por dentro.
	q = p - BOCA_C
	q = q.copy()
	q[..., 1] -= BOCA_CURVA * q[..., 0] ** 2
	d = smin(d, elipsoide(q, np.array([0.0, 0.0, -0.001]), np.array([0.034, 0.014, 0.008])), 0.008)
	d = smax(d, -boca_abertura(p), 0.004)
	d = smax(d, -boca_cavidade(p), 0.006)
	# Orelhas pequenas, coladas, com a concha.
	d = smin(d, elipsoide(m, np.array([0.074, -0.004, 0.012]), np.array([0.009, 0.026, 0.016])), 0.007)
	d = smax(d, -elipsoide(m, np.array([0.082, -0.004, 0.013]), np.array([0.0035, 0.016, 0.009])), 0.003)
	# Pescoco fino com os dois tendoes e o pomo.
	d = smin(d, capsula(p, np.array([0.0, -0.075, 0.022]), np.array([0.0, -0.215, 0.030]), 0.040), 0.03)
	d = smin(d, capsula(m, np.array([0.052, -0.050, 0.030]), np.array([0.014, -0.205, -0.030]), 0.0085), 0.014)
	d = smin(d, elipsoide(p, np.array([0.0, -0.138, -0.012]), np.array([0.008, 0.011, 0.007])), 0.012)
	# O pescoco termina dentro da murca.
	d = np.maximum(d, -(p[..., 1] + 0.205))
	# Carne: calombo de um milimetro e poro mais fino, como cera que escorreu.
	d += (RUIDO(p, 45.0) - 0.5) * 0.0022 + (RUIDO(p, 140.0) - 0.5) * 0.0007
	return d


def dentes(p):
	"""Os dentes e a gengiva: [sdf, gengiva(0-1), podre(0-1), queixada(0/1)]."""
	x = p[..., 0]
	d = np.full(p.shape[:-1], 1.0)
	gengiva = np.full(p.shape[:-1], 1.0)
	cima_top = BOCA_C[1] + BOCA_MEIA[1] + BOCA_CURVA * x ** 2
	baixo_top = BOCA_C[1] - BOCA_MEIA[1] + BOCA_CURVA * x ** 2
	# A gengiva: um cordao ao longo da arcada, logo atras do labio.
	# Acima da raiz do dente de cima e abaixo da do de baixo: o dente pende
	# da gengiva para a abertura.
	for y0, fundo in ((cima_top + 0.0030, 0.0), (baixo_top - 0.0030, 0.0)):
		q = p.copy()
		q[..., 1] -= y0
		q[..., 2] -= ARCADA_Z + 0.002 + ARCADA_A * x ** 2
		g = np.sqrt((q[..., 1] / 0.0026) ** 2 + (q[..., 2] / 0.0040) ** 2) * 0.0030 - 0.0030
		g = np.maximum(g, np.abs(x) - 0.030)
		gengiva = np.minimum(gengiva, g)
	d = np.minimum(d, gengiva)
	podre = np.zeros(p.shape[:-1])
	queixo = np.zeros(p.shape[:-1])
	g = np.random.default_rng(31)
	for fila in (0, 1):
		# Poucos, separados, de tamanho desigual: dente de gente que apodreceu,
		# e nao uma fileira de estaca.
		n = 11
		xs = np.linspace(-0.025, 0.025, n) + g.normal(0, 0.0005, n)
		for i, x0 in enumerate(xs):
			if g.random() < 0.18:
				continue  # falta
			larg = g.uniform(0.0026, 0.0036) * (0.85 if abs(x0) > 0.018 else 1.0)
			alto = g.uniform(0.0035, 0.0058) * (1.0 if fila == 0 else 0.8)
			quebrado = g.random() < 0.2
			if quebrado:
				alto *= 0.55
			ponta = 1.0 if abs(x0) > 0.012 and g.random() < 0.5 else 0.0
			inclina = g.normal(0, 0.16)
			z0 = ARCADA_Z + ARCADA_A * x0 ** 2
			y_raiz = (BOCA_C[1] + BOCA_MEIA[1] + 0.0012 + BOCA_CURVA * x0 ** 2) if fila == 0 \
				else (BOCA_C[1] - BOCA_MEIA[1] - 0.0012 + BOCA_CURVA * x0 ** 2)
			sentido = -1.0 if fila == 0 else 1.0
			q = p - np.array([x0, y_raiz, z0])
			c, s_ = np.cos(inclina), np.sin(inclina)
			qx = c * q[..., 0] - s_ * q[..., 1]
			qy = s_ * q[..., 0] + c * q[..., 1]
			ang = np.arctan(2.0 * ARCADA_A * x0)
			ca, sa = np.cos(ang), np.sin(ang)
			qx2 = ca * qx + sa * q[..., 2]
			qz = -sa * qx + ca * q[..., 2]
			t = np.clip(qy * sentido / alto, 0.0, 1.0)
			meia = larg * 0.5 * (1.0 - (0.2 + 0.6 * ponta) * t ** 2)
			fundo = 0.0016 * (1.0 - 0.35 * t)
			dy = np.maximum(-qy * sentido - 0.003, qy * sentido - alto)
			dd = np.maximum(np.maximum(np.abs(qx2) - meia, np.abs(qz) - fundo), dy) - 0.0003
			antes = d
			d = np.minimum(d, dd)
			este = dd < antes
			sujo = g.uniform(0.0, 0.5) + (0.5 if quebrado else 0.0)
			podre = np.where(este, np.clip(sujo + (1 - t) ** 3 * 0.4, 0, 1), podre)
			queixo = np.where(este, float(fila), queixo)
	# Gengiva de baixo gira com a queixada.
	queixo = np.where(gengiva <= d + 1e-6, (p[..., 1] < BOCA_C[1]).astype(float), queixo)
	gmask = np.clip(1.0 - (gengiva - d) / 0.0008, 0.0, 1.0)
	return d, gmask, podre, queixo


def gradiente(f, p, e=0.0003):
	dx = np.array([e, 0, 0])
	dy = np.array([0, e, 0])
	dz = np.array([0, 0, e])
	g = np.stack([f(p + dx) - f(p - dx), f(p + dy) - f(p - dy), f(p + dz) - f(p - dz)], -1)
	return g / np.maximum(np.linalg.norm(g, axis=-1, keepdims=True), 1e-9)


def oclusao(f, p, n):
	ao = np.zeros(len(p))
	peso = 1.0
	for h in (0.002, 0.005, 0.009, 0.015, 0.024):
		ao += peso * np.maximum(h - f(p + n * h), 0.0) / h
		peso *= 0.62
	return np.clip(1.0 - ao * 0.55, 0.0, 1.0)


def superficie(f, lo, hi, voxel):
	xs = np.arange(lo[0], hi[0], voxel)
	ys = np.arange(lo[1], hi[1], voxel)
	zs = np.arange(lo[2], hi[2], voxel)
	vol = np.empty((len(xs), len(ys), len(zs)), np.float32)
	for i, x in enumerate(xs):
		yy, zz = np.meshgrid(ys, zs, indexing='ij')
		pts = np.stack([np.full_like(yy, x), yy, zz], -1)
		vol[i] = f(pts)
	v, faces, _, _ = measure.marching_cubes(vol, 0.0, spacing=(voxel, voxel, voxel))
	v = v + np.array(lo)
	return v, faces, vol, (xs, ys, zs)


def orientar(v, faces, n):
	"""Poe as faces no sentido anti-horario visto de fora (glTF)."""
	a, b, c = v[faces[:, 0]], v[faces[:, 1]], v[faces[:, 2]]
	fn = np.cross(b - a, c - a)
	nm = n[faces[:, 0]] + n[faces[:, 1]] + n[faces[:, 2]]
	errado = (fn * nm).sum(-1) < 0
	faces = faces.copy()
	faces[errado] = faces[errado][:, [0, 2, 1]]
	return faces


def mouth_line(x):
	return BOCA_C[1] + BOCA_CURVA * np.minimum(x ** 2, 0.03 ** 2)


def ss(a, b, x):
	t = np.clip((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3 - 2 * t)


def mascaras_pele(v):
	x, y, z = v[:, 0], v[:, 1], v[:, 2]
	# Olheira: aro escuro do olho, que desce mais do que sobe (a bolsa).
	olheira = np.zeros(len(v))
	for s in (-1.0, 1.0):
		c = OLHO * np.array([s, 1, 1])
		q = v - c
		q[:, 1] = np.where(q[:, 1] < 0, q[:, 1] * 0.72, q[:, 1] * 1.1)
		d = np.linalg.norm(q[:, :2], axis=-1)
		olheira = np.maximum(olheira, ss(0.040, 0.015, d) * ss(0.012, -0.02, z - c[2]))
	# Labio: perto da fenda; goela: dentro da boca.
	db = boca_abertura(v)
	labio = ss(0.011, 0.001, db)
	dc = boca_cavidade(v)
	goela = np.maximum(ss(0.001, -0.003, db) * ss(-0.092, -0.084, z), ss(0.006, 0.0, dc))
	# Queixada: abaixo da linha da boca, na frente do pivo, ate o comeco do
	# pescoco; a bochecha estica (meio peso).
	abaixo = ss(0.002, -0.010, y - mouth_line(x))
	frente = ss(0.035, 0.005, z)
	pescoco = ss(-0.150, -0.118, y)
	lado = 1.0 - 0.45 * ss(0.030, 0.055, np.abs(x))
	queixada = abaixo * frente * pescoco * lado
	# Dentro da boca, o chao da boca vai com a queixada, o ceu fica.
	queixada = np.where(goela > 0.5, ss(-0.060, -0.070, y) * frente, queixada)
	# Veias: tempora, testa do lado, em volta do olho, pescoco, e a calva.
	veia = 0.25 + 0.75 * ss(0.45, 0.75, RUIDO(v, 22.0))
	tempora = ss(0.03, 0.07, np.abs(x)) * ss(-0.03, 0.02, y)
	pesc = ss(-0.09, -0.13, y)
	veia = np.clip(veia * (0.5 + 0.6 * tempora + 0.6 * pesc + 0.5 * olheira), 0, 1)
	return olheira, labio, goela, queixada, veia


# --- glb --------------------------------------------------------------------
def escrever_glb(caminho, malhas):
	"""malhas: lista de (nome, pos, nor, cor(N,4), uv(N,2), idx)."""
	bin_ = bytearray()
	views, acc, meshes, nodes = [], [], [], []

	def add(arr, alvo, tipo, comp, minmax=False):
		arr = np.ascontiguousarray(arr)
		while len(bin_) % 4:
			bin_.append(0)
		off = len(bin_)
		bin_.extend(arr.tobytes())
		views.append({'buffer': 0, 'byteOffset': off, 'byteLength': arr.nbytes, 'target': alvo})
		a = {'bufferView': len(views) - 1, 'componentType': comp, 'count': int(arr.shape[0]), 'type': tipo}
		if minmax:
			a['min'] = arr.min(0).tolist()
			a['max'] = arr.max(0).tolist()
		acc.append(a)
		return len(acc) - 1

	for nome, pos, nor, cor, uv, idx in malhas:
		ap = add(pos.astype(np.float32), 34962, 'VEC3', 5126, True)
		an = add(nor.astype(np.float32), 34962, 'VEC3', 5126)
		ac = add(cor.astype(np.float32), 34962, 'VEC4', 5126)
		au = add(uv.astype(np.float32), 34962, 'VEC2', 5126)
		ai = add(idx.astype(np.uint32).reshape(-1), 34963, 'SCALAR', 5125)
		meshes.append({'name': nome, 'primitives': [{'attributes': {
			'POSITION': ap, 'NORMAL': an, 'COLOR_0': ac, 'TEXCOORD_0': au}, 'indices': ai}]})
		nodes.append({'name': nome, 'mesh': len(meshes) - 1})
	while len(bin_) % 4:
		bin_.append(0)
	doc = {'asset': {'version': '2.0', 'generator': 'tools/gerar_padre.py'},
		'scene': 0, 'scenes': [{'nodes': list(range(len(nodes)))}], 'nodes': nodes,
		'meshes': meshes, 'accessors': acc, 'bufferViews': views,
		'buffers': [{'byteLength': len(bin_)}]}
	js = json.dumps(doc, separators=(',', ':')).encode()
	while len(js) % 4:
		js += b' '
	with open(caminho, 'wb') as f:
		f.write(struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(bin_)))
		f.write(struct.pack('<II', len(js), 0x4E4F534A))
		f.write(js)
		f.write(struct.pack('<II', len(bin_), 0x004E4942))
		f.write(bin_)


def previa(vol, eixos, caminho, lado=False):
	"""Um relevo sombreado da frente (ou do lado) direto do volume: rapido para
	julgar a forma sem abrir o jogo."""
	xs, ys, zs = eixos
	dentro = vol < 0
	if lado:
		# olhando de +x para -x: primeiro voxel dentro vindo de x grande
		idx = np.where(dentro.any(0), len(xs) - 1 - np.argmax(dentro[::-1], axis=0), -1)
		prof = np.where(idx >= 0, xs[np.clip(idx, 0, None)], np.nan)
		img = prof[::-1]
		sinal = 1.0
	else:
		idx = np.where(dentro.any(2), np.argmax(dentro, axis=2), -1)
		prof = np.where(idx >= 0, -zs[np.clip(idx, 0, None)], np.nan)
		img = prof.T[::-1]
		sinal = 1.0
	h = np.nan_to_num(img, nan=np.nanmin(img) - 0.02)
	gy, gx = np.gradient(h)
	n = np.stack([-gx * sinal * 250, gy * 250, np.ones_like(h)], -1)
	n /= np.linalg.norm(n, axis=-1, keepdims=True)
	luz = np.array([-0.4, 0.5, 0.75])
	luz /= np.linalg.norm(luz)
	c = np.clip((n * luz).sum(-1), 0, 1) ** 1.2
	c = np.where(np.isnan(img), 0.08, c)
	im = Image.fromarray((c * 255).astype(np.uint8)).resize(
		(img.shape[1] * 3, img.shape[0] * 3), Image.LANCZOS)
	im.save(caminho)


def gerar_malha(dir_previa=None):
	lo = (-0.095, -0.212, -0.118)
	hi = (0.095, 0.132, 0.122)
	print('cabeca: campo...')
	v, f, vol, eixos = superficie(cabeca, lo, hi, VOXEL)
	if dir_previa:
		os.makedirs(dir_previa, exist_ok=True)
		previa(vol, eixos, os.path.join(dir_previa, 'frente.png'))
		previa(vol, eixos, os.path.join(dir_previa, 'lado.png'), True)
	n = gradiente(cabeca, v)
	f = orientar(v, f, n)
	ao = oclusao(cabeca, v, n)
	olheira, labio, goela, queixada, veia = mascaras_pele(v)
	# A borda da boca e o fundo das orbitas escurecem tambem pela oclusao.
	cor = np.stack([olheira, labio, ao, goela], -1)
	uv = np.stack([queixada, veia], -1)
	print('cabeca: %d vertices, %d triangulos' % (len(v), len(f)))

	print('boca: campo...')
	blo = (-0.034, -0.084, -0.100)
	bhi = (0.034, -0.036, -0.066)
	f_d = lambda p: dentes(p)[0]
	bv, bf, bvol, _ = superficie(f_d, blo, bhi, VOXEL_BOCA)
	bn = gradiente(f_d, bv, 0.0001)
	bf = orientar(bv, bf, bn)
	_, gm, podre, queixo = dentes(bv)
	# A oclusao dos dentes vem da cabeca: o fundo da boca e escuro.
	bao = oclusao(cabeca, bv, bn) * oclusao(f_d, bv, bn)
	bcor = np.stack([gm, podre, bao, np.zeros(len(bv))], -1)
	buv = np.stack([queixo, np.zeros(len(bv))], -1)
	print('boca: %d vertices, %d triangulos' % (len(bv), len(bf)))

	os.makedirs(SAIDA, exist_ok=True)
	escrever_glb(os.path.join(SAIDA, 'cabeca.glb'), [
		('Pele', v, n, cor, uv, f),
		('Boca', bv, bn, bcor, buv, bf),
	])
	print('ok', os.path.join(SAIDA, 'cabeca.glb'))


# --- texturas ---------------------------------------------------------------
def fbm_periodico(n, beta, semente):
	"""Ruido fractal tileavel: ruido branco filtrado no espectro (1/f^beta)."""
	g = np.random.default_rng(semente)
	w = g.standard_normal((n, n)).astype(np.float32)
	F = np.fft.rfft2(w)
	fy = np.fft.fftfreq(n)[:, None]
	fx = np.fft.rfftfreq(n)[None, :]
	f = np.sqrt(fx * fx + fy * fy)
	f[0, 0] = 1.0
	F *= (1.0 / f ** beta)
	F[0, 0] = 0
	r = np.fft.irfft2(F, s=(n, n)).astype(np.float32)
	r -= r.min()
	r /= r.max()
	return r


def borrar_periodico(img, sigma):
	n = img.shape[0]
	F = np.fft.rfft2(img)
	fy = np.fft.fftfreq(n)[:, None]
	fx = np.fft.rfftfreq(n)[None, :]
	F *= np.exp(-2 * (np.pi * sigma) ** 2 * (fx * fx + fy * fy))
	return np.fft.irfft2(F, s=img.shape).astype(np.float32)


def voronoi_borda(n, celulas, semente, warp_x, warp_y, forca):
	"""Distancia a borda (F2-F1) de um Voronoi tileavel, com o dominio torcido."""
	g = np.random.default_rng(semente)
	# pts[i, j] = (x, y) em celulas; i e a coluna x, j a linha y
	# O ponto fica longe da borda da celula: dois pontos quase juntos faziam uma
	# fatia de celula, e a fatia inteira lia como racha (uma mancha escura).
	pts = np.stack([np.arange(celulas)[:, None] + g.uniform(0.18, 0.82, (celulas, celulas)),
		np.arange(celulas)[None, :] + g.uniform(0.18, 0.82, (celulas, celulas))], -1).astype(np.float32)
	out = np.empty((n, n), np.float32)
	passo = 256
	u = (np.arange(n, dtype=np.float32) + 0.5) / n * celulas
	for y0 in range(0, n, passo):
		yy = u[y0:y0 + passo][:, None] + warp_y[y0:y0 + passo] * forca
		xx = u[None, :] + warp_x[y0:y0 + passo] * forca
		cx = np.floor(xx).astype(np.int32)
		cy = np.floor(yy).astype(np.int32)
		f1 = np.full(xx.shape, 9.0, np.float32)
		f2 = np.full(xx.shape, 9.0, np.float32)
		for ox in (-1, 0, 1):
			for oy in (-1, 0, 1):
				ix = cx + ox
				iy = cy + oy
				p = pts[ix % celulas, iy % celulas]
				px = p[..., 0] + (ix - ix % celulas)
				py = p[..., 1] + (iy - iy % celulas)
				d = np.sqrt((px - xx) ** 2 + (py - yy) ** 2)
				menor = d < f1
				f2 = np.where(menor, f1, np.minimum(f2, d))
				f1 = np.where(menor, d, f1)
		out[y0:y0 + passo] = f2 - f1
	return out


def veias(n, semente):
	"""Arvores de veia desenhadas num plano que da a volta (tileavel)."""
	from PIL import ImageDraw
	g = np.random.default_rng(semente)
	im = Image.new('F', (n, n), 0.0)
	d = ImageDraw.Draw(im)

	def linha(a, b, w, v):
		for ox in (-n, 0, n):
			for oy in (-n, 0, n):
				d.line([(a[0] + ox, a[1] + oy), (b[0] + ox, b[1] + oy)], fill=v, width=int(max(1, w)))

	pilha = []
	for _ in range(64):
		pilha.append((g.uniform(0, n), g.uniform(0, n), g.uniform(0, 2 * np.pi), g.uniform(8, 15), 0))
	while pilha:
		x, y, a, w, nivel = pilha.pop()
		comp = g.uniform(260, 520) / (1 + nivel * 0.6)
		passos = int(comp / 10)
		for _ in range(passos):
			a += g.normal(0, 0.22)
			nx, ny = x + np.cos(a) * 10, y + np.sin(a) * 10
			linha((x, y), (nx, ny), w, 1.0)
			x, y = nx, ny
			w *= 0.985
			if nivel < 4 and g.random() < 0.05:
				pilha.append((x, y, a + g.choice([-1, 1]) * g.uniform(0.5, 1.1), w * 0.7, nivel + 1))
		if nivel < 4:
			pilha.append((x, y, a + g.normal(0, 0.5), w * 0.75, nivel + 1))
	arr = np.array(im, np.float32)
	arr = borrar_periodico(arr, 2.2)
	return np.clip(arr / max(arr.max(), 1e-6), 0, 1)


def gerar_texturas():
	n = TEX
	print('texturas: ruidos...')
	wx = fbm_periodico(n, 1.6, 11) - 0.5
	wy = fbm_periodico(n, 1.6, 12) - 0.5
	print('texturas: rachas grandes...')
	grande = voronoi_borda(n, 11, 21, wx, wy, 1.4)
	print('texturas: rachas finas...')
	fina = voronoi_borda(n, 34, 22, wx * 0.8, wy * 0.8, 2.2)
	densidade = fbm_periodico(n, 1.8, 13)
	# Perfil da racha: vale estreito e fundo; o fino so em parte da pele.
	r_g = np.exp(-(grande / 0.030) ** 2)
	r_f = np.exp(-(fina / 0.045) ** 2) * np.clip((densidade - 0.30) * 3.0, 0, 1)
	# A placa entre rachas empena um pouco nas bordas (a tinta que descasca).
	placa = np.clip(grande / 0.25, 0, 1) ** 0.5 * 0.25 + np.clip(fina / 0.3, 0, 1) ** 0.5 * 0.12
	poros = fbm_periodico(n, 0.6, 14)
	altura = 0.55 + placa - 0.62 * r_g - 0.38 * r_f + (poros - 0.5) * 0.06
	altura = np.clip(altura, 0, 1)
	print('texturas: veias...')
	v = veias(n, 15)
	manchas = fbm_periodico(n, 2.2, 16)
	mapa = np.stack([altura, v, manchas, poros], -1)
	os.makedirs(SAIDA, exist_ok=True)
	Image.fromarray((mapa * 255 + 0.5).astype(np.uint8), 'RGBA').save(os.path.join(SAIDA, 'pele_mapa.png'))
	# Normal: do gradiente da altura (com a volta), em metros: o tile cobre
	# `TILE_M` e a racha tem uns 0,35 mm de fundo.
	tile_m = 0.24
	prof = 0.00035
	h = altura * prof
	dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) / (2 * tile_m / n)
	dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) / (2 * tile_m / n)
	nn = np.stack([-dx, dy, np.ones_like(h)], -1)
	nn /= np.linalg.norm(nn, axis=-1, keepdims=True)
	Image.fromarray(((nn * 0.5 + 0.5) * 255 + 0.5).astype(np.uint8), 'RGB').save(os.path.join(SAIDA, 'pele_n.png'))
	print('ok texturas')


if __name__ == '__main__':
	args = sys.argv[1:]
	dir_previa = None
	if '--previa' in args:
		dir_previa = args[args.index('--previa') + 1]
	if '--so-texturas' not in args:
		gerar_malha(dir_previa)
	if '--so-malha' not in args:
		gerar_texturas()
