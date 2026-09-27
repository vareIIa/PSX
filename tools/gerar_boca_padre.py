"""A boca do padre principal: arcada, gengiva, lingua e a poca de sangue
(Parte 1 de INTRO-PADRE/PLANO_BOCA_SANGUE.md).

    python tools/gerar_boca_padre.py [--so-malha] [--so-texturas]

Gera em game/assets/monstros/padre/boca/:
  boca_padre.glb   Dentes (todas as versoes numa malha), Gengiva, Lingua, Poca e
                   as pecas que voam (Lasca_*)
  esmalte_mapa.png 2048 tileavel: R trinca do esmalte, G periquimacia, B mancha,
                   A grao
  gengiva_mapa.png 2048 tileavel: R pontilhado, G vasinho, B mancha, A grao
  lingua_mapa.png  2048 tileavel: R papila filiforme, G fungiforme, B saburra
e game/src/render/boca_padre_dados.gd, a tabela dos dentes para o jogo.

Por que existe
--------------
A boca de dentro era a do Vitruvian (CharMorph): 64 pecas de dente com 68
vertices cada, uma lingua enorme e lisa e a gengiva por morph. De perto, em 4K,
os dentes eram plastico, a fileira de baixo sumia atras da lingua e nos cantos
sobrava o vao preto. E o pedido e que os dentes QUEBREM, um a um, a cada
cabecada: isso pede dente de verdade, com dentina e polpa por dentro.

Como e feito
------------
Cada dente e um campo de distancia no espaco dele (x mesiodistal, + para o fundo
da boca; y do colo para a ponta; z labio-lingual, + para dentro): o corte
transversal e uma superelipse cujas medidas mudam com a altura (colo, coroa,
borda), a ponta e um telhado (a borda do incisivo, a cuspide do canino, as duas
cuspides do pre-molar) e a raiz afina ate o apice.

A malha NAO sai de marching cubes: cada vertice e um raio de uma grade
(calota de baixo, cilindro, calota de cima) que sai da espinha do dente e para
onde o campo cruza zero. Assim todo dente tem a mesma contagem, sem
decimacao, e as versoes quebradas saem do MESMO campo cortado por um plano
serrilhado: o toco e o campo com o plano por cima, a coroa que voa e o campo
com o plano por baixo. A face da quebra ganha dentina e polpa pela
profundidade dentro do dente inteiro.

Atributos (Dentes e Lasca_*):
  COLOR_0.r   face da quebra (1)
  COLOR_0.g   o que a quebra mostra: 0 esmalte, ~0,6 dentina, 1 polpa
  COLOR_0.b   oclusao (a boca e o vao entre os dentes)
  COLOR_0.a   do colo (1) a ponta (0)
  TEXCOORD_0  x peso da queixada (0 em cima, 1 embaixo), y id do dente (0..23)
  TEXCOORD_1  x versao (0 inteiro, 1 lascado, 2 toco, 9 peca solta), y a volta
              do dente (0..1), para a trinca correr no comprido
"""
import json
import os
import sys

import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
import gerar_padre as gp  # noqa: E402
import boca_padre_forma as forma  # noqa: E402

RAIZ = os.path.dirname(AQUI)
SAIDA = os.path.join(RAIZ, 'game', 'assets', 'monstros', 'padre', 'boca')
DADOS = os.path.join(RAIZ, 'game', 'src', 'render', 'boca_padre_dados.gd')

MM = 0.001
# O dente de gente em mm, reduzido: a cabeca e a de 1,72 m e a boca e larga.
ESCALA = 0.9
# A fenda da boca da cabeca (tools/gerar_padre.py): a arcada acompanha a curva.
BOCA_C = gp.BOCA_C
BOCA_MEIA = gp.BOCA_MEIA
BOCA_CURVA = gp.BOCA_CURVA
PIVO = gp.PIVO
GIRO_QUEIXADA = 0.22

# Tipos: [largura no colo, largura maxima, espessura no colo, coroa, raiz,
# inclinacao da coroa para fora (graus)].
TIPOS = {
	'IC_S': [7.0, 8.6, 7.0, 10.5, 13.0, 16.0],
	'IL_S': [5.2, 6.7, 6.2, 9.0, 13.0, 18.0],
	'C_S': [5.6, 7.7, 8.0, 10.0, 17.0, 12.0],
	'P1_S': [4.9, 7.1, 9.0, 8.5, 14.0, 7.0],
	'P2_S': [4.8, 6.7, 9.0, 8.0, 14.0, 5.0],
	'M1_S': [7.6, 10.2, 11.0, 7.5, 12.5, 3.0],
	'IC_I': [3.6, 5.3, 5.8, 9.0, 12.5, 11.0],
	'IL_I': [3.9, 5.9, 6.1, 9.5, 14.0, 10.0],
	'C_I': [5.3, 6.9, 7.6, 11.0, 16.0, 8.0],
	'P1_I': [4.9, 7.0, 7.6, 8.5, 14.0, 5.0],
	'P2_I': [5.0, 7.1, 8.1, 8.0, 14.5, 3.0],
	'M1_I': [8.6, 11.0, 10.4, 7.5, 13.0, 2.0],
}
# Da linha do meio para o fundo, em cada meia arcada.
ORDEM = ['IC', 'IL', 'C', 'P1', 'P2', 'M1']
# Numeracao FDI por (arcada, lado): lado +1 e o +x da malha, que e o lado
# DIREITO do padre (o rosto olha -Z).
QUADRANTE = {(0, 1): 1, (0, -1): 2, (1, -1): 3, (1, 1): 4}

# A arcada no colo: z = Z0 + A x^2 (o centro dos dentes).
ARCO = {0: (-0.0908, 19.0), 1: (-0.0880, 21.0)}
# O colo (a linha da gengiva) fica isto alem da borda da fenda: escondido no
# labio, e a coroa aparece inteira abaixo dele.
COLO_ALEM = {0: 0.0010, 1: 0.0010}

# Os dentes que quebram tem versao lascada e toco: os da frente (1 a 4) das
# duas arcadas. O resto so tem o inteiro.
QUEBRAM = ('IC', 'IL', 'C', 'P1')

# Grade de cada malha de dente: voltas, linhas da calota de baixo, do cilindro
# (raiz, coroa) e da calota de cima.
GRADE_FRENTE = (48, 6, 13, 27, 12)
GRADE_FUNDO = (40, 5, 10, 21, 10)

TEX = 2048


def ss(a, b, x):
	return gp.ss(a, b, x)


def smax(a, b, k):
	return gp.smax(a, b, k)


def smin(a, b, k):
	return gp.smin(a, b, k)


# --- o dente -------------------------------------------------------------------
class Dente:
	"""Um dente: o campo no espaco dele, o lugar na boca e as quebras."""

	def __init__(self, arcada, lado, ordem, g):
		self.arcada = arcada
		self.lado = lado
		self.ordem = ordem
		self.nome = ORDEM[ordem]
		self.tipo = self.nome + ('_S' if arcada == 0 else '_I')
		self.fdi = QUADRANTE[(arcada, lado)] * 10 + ordem + 1
		wc, wi, tc, lc, lr, incl = TIPOS[self.tipo]
		v = g.normal(0.0, 1.0, 8)
		k = ESCALA
		self.wc = wc * k * MM * (1.0 + 0.03 * v[0])
		self.wi = wi * k * MM * (1.0 + 0.04 * v[0])
		self.tc = tc * k * MM * (1.0 + 0.03 * v[1])
		self.lc = lc * k * MM * (1.0 + 0.06 * v[2])
		self.lr = lr * k * MM
		self.incl = np.radians(incl + 3.0 * v[3])
		# Torto: gira no proprio eixo, deita para o lado, desce ou sobe, vai
		# para dentro ou para fora.
		self.giro = np.radians(7.0 * v[4])
		self.deita = np.radians(3.0 * v[5])
		self.desce = 0.45 * MM * v[6]
		self.recua = 0.35 * MM * v[7]
		self.gasto = g.uniform(0.0, 0.7) * MM
		self.semente = int(g.integers(0, 1 << 30))
		self.mancha = float(g.uniform(0.0, 1.0))
		self.ondas = g.uniform(0.0, 2.0 * np.pi, 3)
		self.quebra = self.nome in QUEBRAM
		# O plano da quebra do toco (espaco do dente): altura na coroa (fracao),
		# a inclinacao mesiodistal e a labio-lingual (a face mais alta de fora).
		# Parte na metade de baixo da coroa: o toco precisa passar do labio para
		# ler como dente quebrado, e nao como falta de dente.
		self.u_toco = g.uniform(0.56, 0.72)
		self.inc_x = g.uniform(-0.5, 0.5)
		self.inc_z = g.uniform(0.2, 0.42)
		# O canto que lasca: o de fora (distal) ou o do meio (mesial).
		self.canto = float(g.choice([-1.0, 1.0]))
		self.r_lasca = g.uniform(0.66, 0.78)

	# O perfil: meias medidas do corte, centro e expoente, pela altura y.
	def perfil(self, y):
		lc, lr = self.lc, self.lr
		t = np.clip(y / lc, 0.0, 1.0)
		tr = np.clip(-y / lr, 0.0, 1.0)
		n = self.nome
		rx_c = self.wc * 0.5
		rz_c = self.tc * 0.5
		rx = rx_c + (self.wi * 0.5 - rx_c) * ss(0.0, 0.55, t)
		if n in ('IC', 'IL'):
			borda = (0.55 if self.arcada == 0 else 0.5) * MM
			rz = rz_c + (borda - rz_c) * ss(0.0, 1.0, t) ** 0.85
			cz = -(rz_c - rz) * 0.8
			pw = 2.6
		elif n == 'C':
			rz = rz_c + (1.3 * MM - rz_c) * ss(0.1, 1.0, t) ** 1.1
			cz = -(rz_c - rz) * 0.55
			pw = 2.3
		elif n in ('P1', 'P2'):
			rz = rz_c * (1.0 + 0.1 * ss(0.0, 0.4, t) - 0.18 * ss(0.5, 1.0, t))
			cz = np.zeros_like(y)
			pw = 2.2
		else:
			rz = rz_c * (1.0 + 0.08 * ss(0.0, 0.35, t) - 0.12 * ss(0.5, 1.0, t))
			cz = np.zeros_like(y)
			pw = 2.9
		cx = np.zeros_like(y)
		if n == 'C':
			cx = -0.1 * self.wi * ss(0.5, 1.0, t)
		# A raiz afina ate o apice, e o colo aperta um nada.
		na_raiz = y < 0.0
		rx = np.where(na_raiz, rx_c * 0.93 * (1.0 - 0.72 * tr ** 1.25), rx)
		rz = np.where(na_raiz, rz_c * 0.95 * (1.0 - 0.62 * tr ** 1.2), rz)
		cz = np.where(na_raiz, 0.0, cz)
		cx = np.where(na_raiz, 0.0, cx)
		aperto = 1.0 - 0.05 * np.exp(-(y / (1.2 * MM)) ** 2)
		return rx * aperto, rz * aperto, cx, cz, pw

	def topo(self, x, z, rx_i):
		"""A altura da ponta da coroa em (x, z): borda, cuspide ou as duas
		cuspides do pre-molar."""
		lc = self.lc - self.gasto
		n = self.nome
		if n in ('IC', 'IL'):
			xn = np.clip(x / rx_i, -1.5, 1.5)
			# O canto de fora mais redondo que o do meio; a borda gasta e ondulada.
			canto = np.where(xn > 0, 1.4, 0.6) * MM * ss(0.45, 1.05, np.abs(xn)) ** 2
			onda = 0.12 * MM * (np.sin(xn * 5.0 + self.ondas[0]) + 0.6 * np.sin(xn * 11.0 + self.ondas[1]))
			return lc - canto + onda
		if n == 'C':
			dx = x + 0.1 * self.wi
			incl = np.where(dx < 0, 0.62, 0.78)
			return lc - np.abs(dx) * incl - 25.0 * z ** 2
		if n in ('P1', 'P2'):
			zn = z / (self.tc * 0.5)
			fora = lc - np.abs(x) * 0.62
			dentro = lc - 1.6 * MM - np.abs(x) * 0.5
			sulco = 1.3 * MM * np.exp(-((zn - 0.08) / 0.22) ** 2)
			return np.maximum(np.where(zn < 0.08, fora, dentro), lc - 3.2 * MM) - sulco \
				- 0.25 * MM * zn ** 2
		# Molar: quatro cuspides.
		xn = x / (self.wi * 0.5)
		zn = z / (self.tc * 0.5)
		c = np.zeros_like(x)
		for cxn, czn, h in ((-0.45, -0.45, 1.0), (0.45, -0.45, 0.9), (-0.45, 0.45, 0.8), (0.45, 0.45, 0.7)):
			c = np.maximum(c, h * np.exp(-((xn - cxn) ** 2 + (zn - czn) ** 2) / 0.12))
		return lc - 1.8 * MM * (1.0 - c)

	def campo(self, p):
		"""O dente inteiro: distancia (aproximada) no espaco do dente."""
		x, y, z = p[..., 0], p[..., 1], p[..., 2]
		rx, rz, cx, cz, pw = self.perfil(y)
		dx = x - cx
		dz = z - cz
		t = np.clip(y / self.lc, 0.0, 1.0)
		if self.nome in ('IC', 'IL'):
			# A pa por dentro (lingual) e o cingulo no colo.
			fora_x = np.clip(1.0 - (dx / np.maximum(rx, 1e-6)) ** 2, 0.0, 1.0)
			pa = 0.34 * ss(0.25, 0.5, t) * (1.0 - ss(0.82, 1.0, t)) * fora_x
			cing = 0.18 * np.exp(-((t - 0.13) / 0.1) ** 2) * fora_x
			dz = np.where(dz > 0.0, dz / np.maximum(1.0 - pa + cing, 0.3), dz)
		qx = np.abs(dx) / np.maximum(rx, 1e-7)
		qz = np.abs(dz) / np.maximum(rz, 1e-7)
		nrm = (qx ** pw + qz ** pw) ** (1.0 / pw)
		d = (nrm - 1.0) * np.minimum(rx, rz)
		rx_i = self.wi * 0.5
		d = smax(d, y - self.topo(x, z, rx_i), 0.45 * MM)
		d = smax(d, -(y + self.lr), 0.9 * MM)
		# Carne do esmalte: o calombo de um decimo de milimetro.
		d += (gp.RUIDO(p + self.semente % 97 * 0.01, 1400.0) - 0.5) * 0.06 * MM
		return d

	def polpa(self, p):
		x, y, z = p[..., 0], p[..., 1], p[..., 2]
		rx, rz, cx, cz, _ = self.perfil(y)
		t = y / self.lc
		k = np.where(y >= 0.0, 0.3 * (1.0 - ss(0.3, 0.52, t)), 0.3 * (1.0 - 0.6 * np.clip(-y / self.lr, 0, 1)))
		q = ((x - cx) / np.maximum(rx * k, 1e-7)) ** 2 + ((z - cz) / np.maximum(rz * k, 1e-7)) ** 2
		return (q < 1.0) & (y > -self.lr * 0.85)

	# As quebras: g(p) < 0 fica. O serrilhado e o de uma quebra conchoidal.
	def _serra(self, p, amp):
		s = self.semente % 1013 * 0.001
		return (gp.RUIDO(p + s, 850.0) - 0.5) * amp + (gp.RUIDO(p + s + 0.3, 2600.0) - 0.5) * amp * 0.3

	def g_toco(self, p):
		n = np.array([self.inc_x, 1.0, self.inc_z])
		n = n / np.linalg.norm(n)
		o = np.array([0.0, self.lc * self.u_toco, 0.0])
		return (p - o) @ n + self._serra(p, 0.9 * MM)

	def g_lasca(self, p):
		if self.nome == 'C':
			n = np.array([0.3 * self.canto, 1.0, -0.3])
			o = np.array([-0.1 * self.wi, self.lc * 0.8, 0.0])
		else:
			n = np.array([0.8 * self.canto, 0.7, -0.35])
			o = np.array([0.55 * self.canto * self.wi * 0.5, self.lc * self.r_lasca, 0.0])
		n = n / np.linalg.norm(n)
		return (p - o) @ n + self._serra(p, 0.55 * MM)

	def versao(self, qual):
		"""O campo de cada versao: 0 inteiro, 1 lascado, 2 toco; e das pecas:
		'canto' (a lasca do 0 para o 1), 'coroa0' e 'coroa1' (o que sai no
		toco, vindo do 0 ou do 1)."""
		k = 0.07 * MM
		if qual == 0:
			return self.campo
		if qual == 1:
			return lambda p: smax(self.campo(p), self.g_lasca(p), k)
		if qual == 2:
			return lambda p: smax(self.campo(p), self.g_toco(p), k)
		if qual == 'canto':
			return lambda p: smax(self.campo(p), -self.g_lasca(p), k)
		if qual == 'coroa0':
			return lambda p: smax(self.campo(p), -self.g_toco(p), k)
		if qual == 'coroa1':
			return lambda p: smax(smax(self.campo(p), self.g_lasca(p), k), -self.g_toco(p), k)
		raise ValueError(qual)

	def espinha(self, qual):
		"""O comeco e o fim da espinha (y) de onde saem os raios da versao."""
		ya = -self.lr + 1.4 * MM
		yb = self.lc - 1.1 * MM
		if self.nome in ('P1', 'P2', 'M1'):
			yb = self.lc - 2.4 * MM
		if qual == 2:
			yb = min(yb, self.lc * self.u_toco - (abs(self.inc_x) * self.wi * 0.5
				+ self.inc_z * self.tc * 0.5) - 0.9 * MM)
		if qual == 1:
			yb = min(yb, self.lc * self.r_lasca - 1.2 * MM) if self.nome != 'C' else min(yb, self.lc * 0.8 - 1.4 * MM)
		return ya, yb


# --- a malha por raios ---------------------------------------------------------
def primeira_saida(f, o, d, alcance, passos=110):
	"""Para cada raio (o, d), onde o campo f sai de dentro pela primeira vez."""
	ts = np.linspace(0.0, alcance, passos)
	pts = o[:, None, :] + d[:, None, :] * ts[None, :, None]
	v = f(pts)
	fora = v >= 0.0
	# Quem ja nasce fora (a espinha fora do solido) fica no comeco.
	i = np.where(fora.any(1), np.argmax(fora, 1), passos - 1)
	i = np.maximum(i, 1)
	a = ts[i - 1].copy()
	b = ts[i].copy()
	for _ in range(16):
		m = (a + b) * 0.5
		fm = f(o + d * m[:, None])
		dentro = fm < 0.0
		a = np.where(dentro, m, a)
		b = np.where(dentro, b, m)
	return (a + b) * 0.5


def gradiente(f, p, e=0.015 * MM):
	g = np.stack([f(p + [e, 0, 0]) - f(p - [e, 0, 0]), f(p + [0, e, 0]) - f(p - [0, e, 0]),
		f(p + [0, 0, e]) - f(p - [0, 0, e])], -1)
	return g / np.maximum(np.linalg.norm(g, axis=-1, keepdims=True), 1e-12)


def grade_de_raios(dente, qual, grade):
	"""Os raios da grade: calota de baixo, cilindro e calota de cima, da espinha.
	Devolve (origens, direcoes, voltas, linhas)."""
	nu, nb, nr, nc, nt = grade
	ya, yb = dente.espinha(qual)
	phi = np.linspace(0.0, 2.0 * np.pi, nu, endpoint=False)
	linhas = []
	# calota de baixo: do polo (theta 0) ao equador
	for j in range(nb):
		th = (j / nb) * np.pi * 0.5
		linhas.append(('b', ya, th))
	# cilindro: raiz ate o colo, e o colo ate yb (mais denso na coroa)
	ys = np.concatenate([np.linspace(ya, 0.0, nr, endpoint=False), np.linspace(0.0, yb, nc)])
	if yb <= 0.0:
		ys = np.linspace(ya, yb, nr + nc)
	for y in ys:
		linhas.append(('c', y, 0.0))
	for j in range(1, nt + 1):
		th = np.pi * 0.5 - (j / nt) * np.pi * 0.5
		linhas.append(('t', yb, th))
	o = []
	d = []
	for tipo, y, th in linhas:
		y = np.full(nu, y)
		_, _, cx, cz, _ = dente.perfil(y)
		oo = np.stack([cx, y, cz], -1)
		if tipo == 'c':
			dd = np.stack([np.cos(phi), np.zeros(nu), np.sin(phi)], -1)
		elif tipo == 'b':
			dd = np.stack([np.sin(th) * np.cos(phi), -np.cos(th) * np.ones(nu), np.sin(th) * np.sin(phi)], -1)
		else:
			dd = np.stack([np.sin(th) * np.cos(phi), np.cos(th) * np.ones(nu), np.sin(th) * np.sin(phi)], -1)
		o.append(oo)
		d.append(dd)
	return np.concatenate(o), np.concatenate(d), nu, len(linhas)


def grade_esferica(centro, nu, nv):
	"""Raios de uma esfera a partir de `centro` (as pecas soltas)."""
	phi = np.linspace(0.0, 2.0 * np.pi, nu, endpoint=False)
	o = []
	d = []
	for j in range(nv + 1):
		th = np.pi * j / nv
		dd = np.stack([np.sin(th) * np.cos(phi), -np.cos(th) * np.ones(nu), np.sin(th) * np.sin(phi)], -1)
		o.append(np.tile(centro, (nu, 1)))
		d.append(dd)
	return np.concatenate(o), np.concatenate(d), nu, nv + 1


def faces_da_grade(nu, nv):
	f = []
	for j in range(nv - 1):
		for i in range(nu):
			a = j * nu + i
			b = j * nu + (i + 1) % nu
			c = (j + 1) * nu + i
			e = (j + 1) * nu + (i + 1) % nu
			f.append((a, c, b))
			f.append((b, c, e))
	return np.array(f, np.int64)


def malha_do_dente(dente, qual, grade, centro=None):
	"""Pontos e normais (espaco do dente), faces e a volta de cada vertice."""
	f = dente.versao(qual)
	if centro is None:
		o, d, nu, nv = grade_de_raios(dente, qual, grade)
	else:
		o, d, nu, nv = grade_esferica(centro, grade[0], grade[1])
	t = primeira_saida(f, o, d, 7.5 * MM)
	p = o + d * t[:, None]
	n = gradiente(f, p)
	faces = faces_da_grade(nu, nv)
	volta = np.tile(np.arange(nu) / nu, nv)
	return p, n, faces, volta


def cores_da_quebra(dente, qual, p):
	"""R: face da quebra; G: esmalte (0), dentina (~0,6) ou polpa (1)."""
	inteiro = dente.campo(p)
	if qual in (0,):
		return np.zeros(len(p)), np.zeros(len(p))
	na_quebra = inteiro < -0.05 * MM
	prof = -inteiro
	g = np.where(prof < 0.8 * MM, 0.15 * prof / (0.8 * MM), 0.35 + 0.3 * np.clip((prof - 0.8 * MM) / (1.5 * MM), 0, 1))
	g = np.where(dente.polpa(p), 1.0, g)
	return na_quebra.astype(float), np.where(na_quebra, g, 0.0)


def centro_da_peca(dente, qual):
	"""Um ponto bem dentro da peca, para os raios da esfera: a media de pontos
	que caem dentro dela."""
	g = np.random.default_rng(dente.semente % 1000 + (7 if qual == 'canto' else 11))
	lo = np.array([-dente.wi * 0.6, dente.lc * 0.2, -dente.tc * 0.6])
	hi = np.array([dente.wi * 0.6, dente.lc * 1.05, dente.tc * 0.6])
	pts = lo + (hi - lo) * g.random((60000, 3))
	dentro = dente.versao(qual)(pts) < -0.25 * MM
	if dentro.sum() < 10:
		dentro = dente.versao(qual)(pts) < 0.0
	c = pts[dentro].mean(0)
	# O centro de massa de uma lasca torta pode cair fora dela: o ponto de
	# dentro mais perto da media.
	q = pts[dentro]
	return q[np.argmin(np.linalg.norm(q - c, axis=1))]


# --- a arcada ------------------------------------------------------------------
def arco_pontos(arcada):
	z0, a = ARCO[arcada]
	xs = np.linspace(0.0, 0.05, 5001)
	zs = z0 + a * xs ** 2
	s = np.concatenate([[0.0], np.cumsum(np.hypot(np.diff(xs), np.diff(zs)))])
	return xs, zs, s


def x_no_arco(arcada, s_alvo):
	xs, _, s = arco_pontos(arcada)
	return float(np.interp(s_alvo, s, xs))


def linha_da_fenda(arcada, x):
	"""A borda da fenda sem o torto da boca (`boca_padre_forma.meio_liso`): os
	dentes ficam retos, e a boca torta por cima mostra gengiva de um lado e
	cobre do outro."""
	meio = forma.meio_liso(x)
	return meio + forma.ALTO_CIMA if arcada == 0 else meio - forma.ALTO_BAIXO


def colocar(dentes_da_arcada, arcada):
	"""Poe cada dente na arcada: o centro do colo, e a base do espaco do dente
	(colunas x, y, z) no espaco da cabeca."""
	z0, a = ARCO[arcada]
	for lado in (1, -1):
		s = 0.0
		fila = [d for d in dentes_da_arcada if d.lado == lado]
		fila.sort(key=lambda d: d.ordem)
		g = np.random.default_rng(900 + arcada * 10 + lado)
		for d in fila:
			vao = g.uniform(0.0, 0.12) * MM
			larg = max(d.wi, d.wc) * 0.96
			sc = s + vao + larg * 0.5
			s = sc + larg * 0.5
			x = x_no_arco(arcada, sc) * lado
			z = z0 + a * x * x
			tang = np.array([lado, 0.0, 2.0 * a * x * lado])
			tang /= np.linalg.norm(tang)
			dentro = np.array([-2.0 * a * x, 0.0, 1.0])
			dentro /= np.linalg.norm(dentro)
			coroa = np.array([0.0, -1.0 if arcada == 0 else 1.0, 0.0])
			# A coroa inclinada para fora (labial = -dentro).
			yax = coroa * np.cos(d.incl) - dentro * np.sin(d.incl)
			# Deita para o lado e gira no eixo: dente torto.
			yax = rodar(yax, dentro, d.deita)
			xax = tang - yax * (tang @ yax)
			xax /= np.linalg.norm(xax)
			xax = rodar(xax, yax, d.giro)
			zax = dentro - yax * (dentro @ yax) - xax * (dentro @ xax)
			zax /= np.linalg.norm(zax)
			y_colo = linha_da_fenda(arcada, x) + (COLO_ALEM[arcada] if arcada == 0 else -COLO_ALEM[arcada])
			c = np.array([x, y_colo, z]) - coroa * d.desce + dentro * d.recua
			d.centro = c
			d.base = np.stack([xax, yax, zax], 1)


def rodar(v, eixo, ang):
	eixo = eixo / np.linalg.norm(eixo)
	return v * np.cos(ang) + np.cross(eixo, v) * np.sin(ang) + eixo * (eixo @ v) * (1 - np.cos(ang))


def para_cabeca(d, p, n):
	return d.centro + p @ d.base.T, n @ d.base.T


def dentro_da_pele(p):
	"""O que vaza da cara (fora da pele e fora da fenda e da boca) volta para
	dentro dela, pelo gradiente da cabeca: a raiz e a gengiva de baixo passavam
	pelo queixo. So mexe no escondido."""
	p = p.copy()
	for _ in range(4):
		d = forma.cabeca(p)
		vaza = (d > -0.6 * MM) & ~forma.na_boca(p)
		if not vaza.any():
			break
		gr = gp.gradiente(forma.cabeca, p[vaza])
		p[vaza] -= gr * (d[vaza] + 0.9 * MM)[:, None]
	return p


def ao_da_boca(p, n):
	"""A oclusao que a cabeca faz dentro da boca (labios, bochecha, ceu)."""
	return gp.oclusao(forma.cabeca, p, n)


# --- gengiva ---------------------------------------------------------------------
def gengiva(dentes, arcada):
	"""A gengiva de uma arcada: um tubo varrido ao longo do arco, com a crista
	recortada (margem no colo, papila entre os dentes) e o corpo subindo (em cima)
	ou descendo (embaixo) para dentro da carne."""
	z0, a = ARCO[arcada]
	fila = sorted([d for d in dentes if d.arcada == arcada], key=lambda d: d.centro[0])
	xs_c = np.array([d.centro[0] for d in fila])
	colo_c = np.array([d.centro[1] for d in fila])
	tc_c = np.array([d.tc for d in fila])
	meia_c = np.array([max(d.wc, d.wi * 0.8) * 0.5 for d in fila])
	# Os contatos entre vizinhos: e dali que a papila desce.
	contatos = (xs_c[:-1] + meia_c[:-1] + xs_c[1:] - meia_c[1:]) * 0.5
	sent = -1.0 if arcada == 0 else 1.0  # para onde a coroa aponta (y)
	x_fim = max(abs(xs_c.min()), abs(xs_c.max())) + 4.5 * MM
	n_s = 220
	n_v = 36
	xs = np.linspace(-x_fim, x_fim, n_s)
	pos = []
	nor = []
	cor = []
	uv = []
	uv2 = []
	alfa = np.linspace(0.0, 2.0 * np.pi, n_v, endpoint=False)
	for x in xs:
		z = z0 + a * x * x
		dentro = np.array([-2.0 * a * x, 0.0, 1.0])
		dentro /= np.linalg.norm(dentro)
		# O dente mais perto e a papila (0 no meio do dente, 1 no contato).
		i = int(np.argmin(np.abs(xs_c - x)))
		d = fila[i]
		meia = meia_c[i]
		papila = float(np.max(np.clip(1.0 - np.abs(contatos - x) / (1.9 * MM), 0.0, 1.0) ** 2))
		fim = ss(x_fim - 3.0 * MM, x_fim, abs(x))
		y_colo = float(np.interp(x, xs_c, colo_c))
		# A crista: 1 mm alem do colo no meio do dente, a papila desce 2,6 mm.
		crista = y_colo + sent * (0.9 * MM + 2.6 * MM * papila) - sent * fim * 4.0 * MM
		alto = 5.5 * MM
		largo = float(np.interp(x, xs_c, tc_c)) * 0.5 + 1.1 * MM
		centro_w = 0.3 * MM
		yc = crista - sent * alto
		for k, al in enumerate(alfa):
			ca, sa = np.cos(al), np.sin(al)
			w = centro_w + largo * np.sign(ca) * np.abs(ca) ** 0.75
			# sa = +1: a crista (para o lado da coroa)
			h = yc + sent * alto * np.sign(sa) * np.abs(sa) ** 0.6
			# O corpo vira para dentro da carne; o fim do tubo afina.
			k_fim = 1.0 - 0.9 * fim
			w *= k_fim
			p = np.array([x, h, z]) + dentro * w
			pos.append(p)
			na_crista = ss(-0.2, 0.85, sa)
			cor.append([na_crista, papila * na_crista, 1.0, 0.0])
			uv.append([float(arcada), float(fila[i].indice)])
			# A distancia ao colo do dente (o alveolo): no plano do arco.
			dz = w / max(d.tc * 0.5, 1e-6)
			dx = (x - d.centro[0]) / max(meia, 1e-6)
			uv2.append([float(np.sqrt(dx * dx + dz * dz)), na_crista])
	pos = np.array(pos)
	cor = np.array(cor)
	faces = []
	for s in range(n_s - 1):
		for k in range(n_v):
			a0 = s * n_v + k
			b0 = s * n_v + (k + 1) % n_v
			c0 = (s + 1) * n_v + k
			e0 = (s + 1) * n_v + (k + 1) % n_v
			faces.append((a0, c0, b0))
			faces.append((b0, c0, e0))
	faces = np.array(faces, np.int64)
	pos = dentro_da_pele(pos)
	faces = para_fora(pos, faces)
	nor = normais_da_malha(pos, faces)
	# As tampas das pontas ficam dentro da bochecha: nao precisam fechar.
	cor[:, 2] = ao_da_boca(pos, nor)
	# Grao da carne: ruido no proprio lugar, 0,15 mm.
	pos = pos + nor * ((gp.RUIDO(pos, 1100.0) - 0.5) * 0.25 * MM)[:, None]
	return pos, nor, cor, np.array(uv), np.array(uv2), faces


def para_fora(p, f):
	"""Vira as faces para fora pelo volume com sinal: a grade da lingua e a da
	gengiva de cima nasciam do avesso, e o cull_back mostrava o lado de dentro
	(uma mancha escura no meio da boca)."""
	c = p.mean(0)
	a, b, d = p[f[:, 0]] - c, p[f[:, 1]] - c, p[f[:, 2]] - c
	if np.einsum('ij,ij->i', a, np.cross(b, d)).sum() < 0.0:
		f = f[:, [0, 2, 1]]
	return f


def normais_da_malha(p, f):
	n = np.zeros_like(p)
	fn = np.cross(p[f[:, 1]] - p[f[:, 0]], p[f[:, 2]] - p[f[:, 0]])
	for k in range(3):
		np.add.at(n, f[:, k], fn)
	return n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)


# --- lingua e poca -------------------------------------------------------------
def lingua():
	"""A lingua deitada no chao da boca, atras da fileira de baixo: menor e mais
	baixa que a do Vitruvian, com o sulco do meio e a ponta mais estreita."""
	nu, nv = 72, 44
	c = np.array([0.0, -0.0718, -0.0595])
	r = np.array([0.0182, 0.0074, 0.0252])
	pos = []
	uv = []
	uv2 = []
	for j in range(nv + 1):
		th = np.pi * j / nv
		for i in range(nu):
			ph = 2.0 * np.pi * i / nu
			q = np.array([np.sin(th) * np.cos(ph), np.cos(th), np.sin(th) * np.sin(ph)])
			p = c + q * r
			z = p[2]
			# A ponta (frente, -z) mais estreita e um fio mais baixa.
			frente = ss(-0.070, -0.086, z)
			p[0] = c[0] + (p[0] - c[0]) * (1.0 - 0.3 * frente)
			p[1] -= 0.0012 * frente
			# O dorso achatado e o sulco do meio.
			cima = ss(0.0, 0.6, q[1])
			p[1] = c[1] + (p[1] - c[1]) * (1.0 - 0.25 * cima)
			p[1] -= 0.0009 * np.exp(-(p[0] / 0.0026) ** 2) * cima * (1.0 - ss(-0.04, -0.035, z))
			pos.append(p)
			uv.append([1.0, frente])
			uv2.append([ph / (2.0 * np.pi), th / np.pi])
	pos = np.array(pos)
	faces = para_fora(pos, faces_da_grade(nu, nv + 1))
	nor = normais_da_malha(pos, faces)
	ao = ao_da_boca(pos, nor)
	cor = np.stack([np.zeros(len(pos)), np.zeros(len(pos)), ao, np.zeros(len(pos))], -1)
	return pos, nor, cor, np.array(uv), np.array(uv2), faces


def poca(dentes):
	"""A poca de sangue no chao da boca: uma folha em y = 0 (o nivel vem do
	shader), cortada por dentro da fileira de baixo. COLOR_0.r = 1 dentro."""
	fila = [d for d in dentes if d.arcada == 1]
	z0, a = ARCO[1]
	n = 48
	xs = np.linspace(-0.030, 0.030, n)
	zs = np.linspace(-0.094, -0.034, n)
	pos = []
	cor = []
	for z in zs:
		for x in xs:
			# por dentro do arco (lingual) e dentro da boca
			z_arco = z0 + a * x * x + 2.0 * MM
			dentro = ss(-0.6 * MM, 0.6 * MM, z - z_arco)
			pos.append([x, 0.0, z])
			cor.append([dentro, 0.0, 1.0, 0.0])
	pos = np.array(pos)
	f = []
	for j in range(n - 1):
		for i in range(n - 1):
			a0 = j * n + i
			f.append((a0, a0 + n, a0 + 1))
			f.append((a0 + 1, a0 + n, a0 + n + 1))
	f = np.array(f, np.int64)
	nor = np.tile([0.0, 1.0, 0.0], (len(pos), 1))
	uv = np.tile([1.0, 0.0], (len(pos), 1))
	return pos, nor, np.array(cor), uv, np.zeros((len(pos), 2)), f


# --- glb -------------------------------------------------------------------------
def escrever_glb(caminho, malhas):
	"""malhas: (nome, pos, nor, cor, uv, uv2, idx, translacao)."""
	import json as _json
	import struct
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

	for nome, pos, nor, cor, uv, uv2, idx, tr in malhas:
		ap = add(pos.astype(np.float32), 34962, 'VEC3', 5126, True)
		an = add(nor.astype(np.float32), 34962, 'VEC3', 5126)
		ac = add(cor.astype(np.float32), 34962, 'VEC4', 5126)
		au = add(uv.astype(np.float32), 34962, 'VEC2', 5126)
		au2 = add(uv2.astype(np.float32), 34962, 'VEC2', 5126)
		ai = add(idx.astype(np.uint32).reshape(-1), 34963, 'SCALAR', 5125)
		meshes.append({'name': nome, 'primitives': [{'attributes': {
			'POSITION': ap, 'NORMAL': an, 'COLOR_0': ac, 'TEXCOORD_0': au, 'TEXCOORD_1': au2},
			'indices': ai}]})
		no = {'name': nome, 'mesh': len(meshes) - 1}
		if tr is not None:
			no['translation'] = [float(v) for v in tr]
		nodes.append(no)
	while len(bin_) % 4:
		bin_.append(0)
	doc = {'asset': {'version': '2.0', 'generator': 'tools/gerar_boca_padre.py'},
		'scene': 0, 'scenes': [{'nodes': list(range(len(nodes)))}], 'nodes': nodes,
		'meshes': meshes, 'accessors': acc, 'bufferViews': views,
		'buffers': [{'byteLength': len(bin_)}]}
	js = _json.dumps(doc, separators=(',', ':')).encode()
	while len(js) % 4:
		js += b' '
	with open(caminho, 'wb') as f:
		f.write(struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(bin_)))
		f.write(struct.pack('<II', len(js), 0x4E4F534A))
		f.write(js)
		f.write(struct.pack('<II', len(bin_), 0x004E4942))
		f.write(bin_)


# --- a queixada ----------------------------------------------------------------
def girar_queixada(p, abre):
	"""A mesma conta do shader: gira em x em volta do pivo, -abre * giro."""
	a = -abre * GIRO_QUEIXADA
	c, s = np.cos(a), np.sin(a)
	q = p - PIVO
	return PIVO + np.stack([q[:, 0], c * q[:, 1] - s * q[:, 2], s * q[:, 1] + c * q[:, 2]], -1)


def abre_minimo(dentes, amostras):
	"""Ate onde a queixada fecha (abre < 0) antes de um dente de baixo entrar num
	de cima: a borda do visema M."""
	de_cima = [d for d in dentes if d.arcada == 0]
	pts = np.concatenate([amostras[d.indice] for d in dentes if d.arcada == 1])

	def bate(abre):
		q = girar_queixada(pts, abre)
		for d in de_cima:
			loc = (q - d.centro) @ d.base
			perto = np.linalg.norm(loc, axis=1) < 0.02
			if perto.any() and (d.campo(loc[perto]) < -0.2 * MM).any():
				return True
		return False

	lo, hi = -1.0, 0.0
	if not bate(lo):
		return lo
	for _ in range(20):
		m = (lo + hi) * 0.5
		if bate(m):
			lo = m
		else:
			hi = m
	return hi


# --- tudo --------------------------------------------------------------------------
def montar_dentes():
	g = np.random.default_rng(4471)
	dentes = []
	for arcada in (0, 1):
		for lado in (1, -1):
			for ordem in range(6):
				dentes.append(Dente(arcada, lado, ordem, g))
	for arcada in (0, 1):
		colocar([d for d in dentes if d.arcada == arcada], arcada)
	# Indice: em cada arcada do +x (direita do padre) ao -x.
	for arcada in (0, 1):
		fila = sorted([d for d in dentes if d.arcada == arcada], key=lambda d: -d.centro[0])
		for k, d in enumerate(fila):
			d.indice = arcada * 12 + k
	return sorted(dentes, key=lambda d: d.indice)


def gerar_malha():
	os.makedirs(SAIDA, exist_ok=True)
	dentes = montar_dentes()
	blocos = []
	pecas = []
	tabela = []
	amostras = {}
	for d in dentes:
		grade = GRADE_FRENTE if d.ordem < 4 else GRADE_FUNDO
		versoes = [0, 1, 2] if d.quebra else [0]
		linha = {'id': d.indice, 'fdi': d.fdi, 'arcada': d.arcada, 'versoes': versoes, 'pecas': {}}
		for qual in versoes:
			p, n, f, volta = malha_do_dente(d, qual, grade)
			r, gq = cores_da_quebra(d, qual, p)
			ph, nh = para_cabeca(d, p, n)
			ph = dentro_da_pele(ph)
			if qual == 0:
				amostras[d.indice] = ph[::3]
			t = np.clip(1.0 - p[:, 1] / d.lc, 0.0, 1.0)
			ao = ao_da_boca(ph, nh)
			# O vao entre os dentes: escurece junto do contato, no colo mais.
			rx, _, cx, _, _ = d.perfil(p[:, 1])
			vao = ss(0.72, 1.0, np.abs(p[:, 0] - cx) / np.maximum(rx, 1e-6))
			ao = ao * (1.0 - 0.35 * vao * (0.4 + 0.6 * t))
			cor = np.stack([r, gq, ao, t], -1)
			uv = np.stack([np.full(len(p), float(d.arcada)), np.full(len(p), float(d.indice))], -1)
			uv2 = np.stack([np.full(len(p), float(qual)), volta], -1)
			f = gp.orientar(ph, f, nh)
			blocos.append((ph, nh, cor, uv, uv2, f))
			print('dente %d (%d) versao %d: %d vertices' % (d.indice, d.fdi, qual, len(p)))
		# As pecas que voam, cada uma centrada no proprio centro (o jogo poe o
		# no no centro e ela gira em volta dele).
		quais = ['inteiro']
		if d.quebra:
			quais += ['canto', 'coroa0', 'coroa1']
		for qual in quais:
			if qual == 'inteiro':
				p, n, f, volta = malha_do_dente(d, 0, grade)
				r = np.zeros(len(p))
				gq = np.zeros(len(p))
			else:
				c = centro_da_peca(d, qual)
				p, n, f, volta = malha_do_dente(d, qual, (40, 30), centro=c)
				r, gq = cores_da_quebra(d, qual, p)
			ph, nh = para_cabeca(d, p, n)
			t = np.clip(1.0 - p[:, 1] / d.lc, 0.0, 1.0)
			ao = np.full(len(p), 0.9)
			cor = np.stack([r, gq, ao, t], -1)
			uv = np.stack([np.zeros(len(p)), np.full(len(p), float(d.indice))], -1)
			uv2 = np.stack([np.full(len(p), 9.0), volta], -1)
			f = gp.orientar(ph, f, nh)
			cm = ph.mean(0)
			nome = 'Lasca_%d_%s' % (d.indice, qual)
			pecas.append((nome, ph - cm, nh, cor, uv, uv2, f, cm))
			vol = abs(np.einsum('ij,ij->i', ph[f[:, 0]] - cm, np.cross(ph[f[:, 1]] - cm, ph[f[:, 2]] - cm)).sum()) / 6.0
			linha['pecas'][qual] = {'centro': cm.tolist(), 'volume_mm3': vol * 1e9}
		linha['centro'] = d.centro.tolist()
		linha['eixo'] = d.base[:, 1].tolist()
		linha['fora'] = (-d.base[:, 2]).tolist()
		linha['largura'] = float(d.wi)
		linha['coroa'] = float(d.lc)
		linha['altura_toco'] = float(d.lc * d.u_toco)
		tabela.append(linha)
	# Uma malha so para todos os dentes.
	pos, nor, cor, uv, uv2, idx = [], [], [], [], [], []
	base = 0
	for ph, nh, c, u, u2, f in blocos:
		pos.append(ph)
		nor.append(nh)
		cor.append(c)
		uv.append(u)
		uv2.append(u2)
		idx.append(f + base)
		base += len(ph)
	dentes_malha = ('Dentes', np.concatenate(pos), np.concatenate(nor), np.concatenate(cor),
		np.concatenate(uv), np.concatenate(uv2), np.concatenate(idx), None)
	print('dentes: %d vertices, %d triangulos' % (base, sum(len(f) for f in idx)))
	gs = []
	for arcada in (0, 1):
		gs.append(gengiva(dentes, arcada))
	gp_ = np.concatenate([x[0] for x in gs])
	gn = np.concatenate([x[1] for x in gs])
	gc = np.concatenate([x[2] for x in gs])
	gu = np.concatenate([x[3] for x in gs])
	gu2 = np.concatenate([x[4] for x in gs])
	gf = np.concatenate([gs[0][5], gs[1][5] + len(gs[0][0])])
	gf = gp.orientar(gp_, gf, gn)
	print('gengiva: %d vertices' % len(gp_))
	lp, ln, lc, lu, lu2, lf = lingua()
	lf = gp.orientar(lp, lf, ln)
	pp, pn, pc, pu, pu2, pf = poca(dentes)
	malhas = [dentes_malha,
		('Gengiva', gp_, gn, gc, gu, gu2, gf, None),
		('Lingua', lp, ln, lc, lu, lu2, lf, None),
		('Poca', pp, pn, pc, pu, pu2, pf, None)] + pecas
	escrever_glb(os.path.join(SAIDA, 'boca_padre.glb'), malhas)
	amin = abre_minimo(dentes, amostras)
	print('abre minimo (os dentes se encostam): %.3f' % amin)
	escrever_dados(tabela, amin)
	print('ok', os.path.join(SAIDA, 'boca_padre.glb'))


def escrever_dados(tabela, amin):
	def v3(v):
		return 'Vector3(%.5f, %.5f, %.5f)' % tuple(v)

	linhas = [
		'## GERADO por tools/gerar_boca_padre.py: nao edite a mao.',
		'##',
		'## A tabela dos dentes da boca nova do padre (`DentesDoPadre`): cada dente',
		'## com o id (0..11 em cima, 12..23 embaixo, do +x ao -x da malha), o numero',
		'## FDI, as versoes que a malha `Dentes` tem, o centro do colo, o eixo (do colo',
		'## para a ponta), o lado de fora e as pecas soltas (centro no espaco da cabeca,',
		'## volume em mm3).',
		'class_name BocaPadreDados',
		'extends RefCounted',
		'',
		'## A queixada fecha ate aqui (abre < 0) sem um dente entrar no outro.',
		'const ABRE_MINIMO := %.4f' % amin,
		'',
		'const DENTES := [',
	]
	for t in tabela:
		pecas = ', '.join('&"%s": [%s, %.3f]' % (k, v3(v['centro']), v['volume_mm3']) for k, v in t['pecas'].items())
		linhas.append('\t{"id": %d, "fdi": %d, "arcada": %d, "versoes": %s, "centro": %s, "eixo": %s, "fora": %s, '
			'"largura": %.5f, "coroa": %.5f, "toco": %.5f, "pecas": {%s}},' % (
				t['id'], t['fdi'], t['arcada'], t['versoes'], v3(t['centro']), v3(t['eixo']), v3(t['fora']),
				t['largura'], t['coroa'], t['altura_toco'], pecas))
	linhas.append(']')
	with open(DADOS, 'w', newline='\n') as f:
		f.write('\n'.join(linhas) + '\n')
	print('ok', DADOS)


# --- texturas ------------------------------------------------------------------
def gerar_texturas():
	n = TEX
	os.makedirs(SAIDA, exist_ok=True)
	print('esmalte...')
	# Trinca do esmalte: linhas finas no comprido do dente (v), quebradas.
	wx = gp.fbm_periodico(n, 1.6, 41) - 0.5
	wy = gp.fbm_periodico(n, 1.6, 42) - 0.5
	# (x da textura e a volta do dente, y o comprido): linhas quase retas no
	# comprido, torcidas de leve, cada uma aparecendo num trecho.
	g = np.random.default_rng(43)
	uu = np.arange(n, dtype=np.float32)[None, :] / n + wx * 0.05
	dist = np.full((n, n), 1.0, np.float32)
	for x0 in g.random(14):
		dd = np.abs(((uu - x0 + 0.5) % 1.0) - 0.5)
		dist = np.minimum(dist, dd)
	trinca = np.exp(-(dist * n / 1.3) ** 2) * np.clip((gp.fbm_periodico(n, 1.4, 44) - 0.4) * 3.0, 0, 1)
	# Periquimacia: as ondas finas atravessadas (na volta), perto do colo.
	vv = np.arange(n, dtype=np.float32)[:, None] / n
	peri = 0.5 + 0.5 * np.sin(2 * np.pi * (vv * 90.0 + wx * 2.0))
	peri = np.broadcast_to(peri, (n, n)).astype(np.float32)
	mancha = gp.fbm_periodico(n, 2.4, 45)
	grao = gp.fbm_periodico(n, 0.7, 46)
	mapa = np.stack([trinca, peri, mancha, grao], -1)
	Image.fromarray((np.clip(mapa, 0, 1) * 255 + 0.5).astype(np.uint8), 'RGBA').save(os.path.join(SAIDA, 'esmalte_mapa.png'))
	h = peri * 0.35 + grao * 0.65 - trinca * 0.5

	print('gengiva...')
	pont = gp.fbm_periodico(n, 0.35, 51)
	pont = np.clip((pont - 0.45) * 4.0, 0, 1)
	vaso = gp.veias(n, 52) * 0.8
	manch = gp.fbm_periodico(n, 2.2, 53)
	gr = gp.fbm_periodico(n, 0.8, 54)
	mapa = np.stack([pont, vaso, manch, gr], -1)
	Image.fromarray((np.clip(mapa, 0, 1) * 255 + 0.5).astype(np.uint8), 'RGBA').save(os.path.join(SAIDA, 'gengiva_mapa.png'))

	print('lingua...')
	# Papilas filiformes: pontos densos; fungiformes: poucas, maiores.
	g = np.random.default_rng(61)
	fil = np.zeros((n, n), np.float32)
	ys = g.integers(0, n, 90000)
	xs = g.integers(0, n, 90000)
	fil[ys, xs] = 1.0
	fil = gp.borrar_periodico(fil, 2.0)
	fil = np.clip(fil / np.percentile(fil, 99.5), 0, 1)
	fun = np.zeros((n, n), np.float32)
	ys = g.integers(0, n, 2500)
	xs = g.integers(0, n, 2500)
	fun[ys, xs] = 1.0
	fun = gp.borrar_periodico(fun, 5.0)
	fun = np.clip(fun / np.percentile(fun, 99.9), 0, 1)
	sab = gp.fbm_periodico(n, 2.0, 62)
	mapa = np.stack([fil, fun, sab, gp.fbm_periodico(n, 0.8, 63)], -1)
	Image.fromarray((np.clip(mapa, 0, 1) * 255 + 0.5).astype(np.uint8), 'RGBA').save(os.path.join(SAIDA, 'lingua_mapa.png'))
	print('ok texturas')


def normal_de(h, caminho, forca):
	n = h.shape[0]
	dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * forca
	dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * forca
	nn = np.stack([-dx, dy, np.ones_like(h)], -1)
	nn /= np.linalg.norm(nn, axis=-1, keepdims=True)
	Image.fromarray(((nn * 0.5 + 0.5) * 255 + 0.5).astype(np.uint8), 'RGB').save(caminho)


if __name__ == '__main__':
	args = sys.argv[1:]
	if '--so-texturas' not in args:
		gerar_malha()
	if '--so-malha' not in args:
		gerar_texturas()
