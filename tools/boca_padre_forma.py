"""A forma da boca nova do padre: a fenda torta, os labios, os sulcos e os
rasgos de cada cabecada. E a mesma para a pele (`gerar_cabeca_boca.py`) e
para a arcada (`gerar_boca_padre.py`).

Por que existe
--------------
A boca da cabeca (`gerar_padre.py`) era uma fenda eliptica dobrada por uma
parabola (`BOCA_CURVA`), com um anel liso de labio em volta: um sorriso
perfeito, simetrico, de desenho. O pedido (26/09/2026) e a boca com forma de
boca: o labio de cima fino com o tuberculo, o de baixo cheio, os cantos em
alturas diferentes, o labio arreganhado de um lado e caido do outro, a borda
irregular, o filtro do nariz, os sulcos. E que ela se estrague a cada golpe:
o labio de cima parte, o canto rasga para a bochecha, uma aba do labio fica
pendurada.

Unidades em metros, no espaco da malha da cabeca (rosto para -Z, +x e a
DIREITA do padre).
"""
import numpy as np

import gerar_padre as gp

ss = gp.ss

BOCA_C = gp.BOCA_C
# A curva do meio da fenda (m por m^2): a metade da antiga. Com 11 os cantos
# subiam 1 cm e a boca lia como sorriso.
CURVA = 5.5
# A boca torta: o canto direito (+x) mais baixo que o esquerdo (m por m).
TORTA = -0.05
# Onde fica cada canto (m): o esquerdo puxado para o lado.
XC_DIR = 0.0305
XC_ESQ = 0.0325
# Meia altura da fenda em repouso, em cima e embaixo do meio (m).
ALTO_CIMA = 0.0092
ALTO_BAIXO = 0.0098
# A meia profundidade do tunel da fenda (m).
FUNDO = 0.022


def xc(x):
	return np.where(x >= 0.0, XC_DIR, XC_ESQ)


def envelope(x):
	"""1 no meio da boca, 0 nos cantos, sem ponta."""
	return np.clip(1.0 - (x / xc(x)) ** 2, 0.0, 1.0) ** 0.55


def envelope_labio(x):
	return np.clip(1.0 - (x / (xc(x) + 0.004)) ** 2, 0.0, 1.0) ** 0.5


def meio(x):
	xx = np.clip(x, -0.036, 0.036)
	return BOCA_C[1] + CURVA * xx * xx + TORTA * xx


def meio_liso(x):
	"""A linha dos dentes: a mesma curva, sem o torto (a boca torta por cima de
	dentes retos mostra a gengiva de um lado e cobre do outro)."""
	return BOCA_C[1] + CURVA * np.minimum(x * x, 0.03 ** 2)


def alto_cima(x):
	e = envelope(x)
	# O labio arreganhado em cima do canino esquerdo, o tuberculo no meio e a
	# borda rachada.
	rosna = 0.0028 * np.exp(-((x + 0.016) / 0.007) ** 2)
	tuberculo = -0.0012 * np.exp(-(x / 0.004) ** 2)
	irreg = 0.00045 * np.sin(x * 430.0 + 1.3) + 0.00025 * np.sin(x * 1130.0 + 0.4)
	return (ALTO_CIMA + rosna + tuberculo + irreg) * e


def alto_baixo(x):
	e = envelope(x)
	# O labio de baixo caido do lado direito, e a borda irregular.
	cai = 0.0032 * np.exp(-((x - 0.013) / 0.010) ** 2)
	irreg = 0.0004 * np.sin(x * 390.0 + 2.1) + 0.00025 * np.sin(x * 970.0 + 1.7)
	return (ALTO_BAIXO + cai + irreg) * e


def borda_cima(x):
	return meio(x) + alto_cima(x)


def borda_baixo(x):
	return meio(x) - alto_baixo(x)


def abertura(p):
	"""A fenda (negativo dentro): o tunel de labio a labio, afinando para a
	frente e para o fundo."""
	x, y, z = p[..., 0], p[..., 1], p[..., 2]
	s = np.clip(np.abs(z - BOCA_C[2]) / FUNDO, 0.0, 1.0)
	afina = np.sqrt(np.maximum(1.0 - s * s, 0.0))
	m = meio(x)
	d = np.maximum(y - (m + alto_cima(x) * afina), (m - alto_baixo(x) * afina) - y)
	d = np.maximum(d, np.abs(x) - xc(x) * np.maximum(afina, 0.05))
	return np.maximum(d, np.abs(z - BOCA_C[2]) - FUNDO)


def labios(p):
	"""Quanto os labios saem da cara (m): o de cima fino, o de baixo cheio."""
	x, y, z = p[..., 0], p[..., 1], p[..., 2]
	vc = y - borda_cima(x)
	vb = borda_baixo(x) - y
	cima = 0.0030 * np.exp(-((vc - 0.0028) / 0.0038) ** 2) * ss(-0.004, -0.001, vc)
	baixo = 0.0044 * np.exp(-((vb - 0.0038) / 0.0048) ** 2) * ss(-0.004, -0.001, vb)
	return (cima + baixo) * envelope_labio(x) * ss(-0.080, -0.094, z)


def _dist_segmento(x, y, a, b):
	ab = b - a
	t = np.clip(((x - a[0]) * ab[0] + (y - a[1]) * ab[1]) / (ab @ ab), 0.0, 1.0)
	return np.hypot(x - a[0] - t * ab[0], y - a[1] - t * ab[1]), t


def relevo(p):
	"""O filtro do nariz, o sulco nasolabial e o do queixo (m, + para fora)."""
	x, y, z = p[..., 0], p[..., 1], p[..., 2]
	bc = borda_cima(x)
	filtro = 0.0008 * np.exp(-((np.abs(x) - 0.0048) / 0.0017) ** 2) \
		* ss(bc + 0.004, bc + 0.008, y) * ss(-0.033, -0.039, y)
	yq = borda_baixo(x) - 0.013
	queixo = -0.0014 * np.exp(-((y - yq) / 0.0024) ** 2) * np.clip(1.0 - (x / 0.021) ** 2, 0.0, 1.0)
	naso = np.zeros_like(x)
	for lado in (-1.0, 1.0):
		a = np.array([0.0135 * lado, -0.037])
		b = np.array([0.037 * lado, -0.072])
		d, t = _dist_segmento(x, y, a, b)
		naso += -0.0013 * np.exp(-(d / 0.0024) ** 2) * ss(0.0, 0.15, t) * ss(1.0, 0.75, t)
	return (filtro + queixo + naso) * ss(-0.070, -0.090, z)


def cabeca(p):
	"""A cabeca de `gerar_padre.cabeca` com a boca nova: a almofada da boca menor
	no quadro torto, os labios e os sulcos por cima, e a fenda nova."""
	m = gp.espelho(p)
	elipsoide, capsula, smin, smax = gp.elipsoide, gp.capsula, gp.smin, gp.smax
	d = elipsoide(p, np.array([0.0, 0.026, 0.012]), np.array([0.071, 0.089, 0.096]))
	d = smin(d, elipsoide(p, np.array([0.0, -0.040, -0.032]), np.array([0.057, 0.066, 0.068])), 0.035)
	d = smin(d, elipsoide(m, np.array([0.044, -0.060, -0.006]), np.array([0.015, 0.026, 0.032])), 0.02)
	d = smin(d, elipsoide(p, np.array([0.0, -0.098, -0.070]), np.array([0.019, 0.015, 0.019])), 0.016)
	d = smin(d, elipsoide(p, np.array([0.0, -0.040, -0.072]), np.array([0.036, 0.034, 0.030])), 0.02)
	d = smin(d, capsula(m, np.array([0.0, 0.026, -0.080]), np.array([0.046, 0.024, -0.071]), 0.010), 0.016)
	d = smin(d, elipsoide(m, np.array([0.046, -0.010, -0.058]), np.array([0.019, 0.013, 0.021])), 0.014)
	d = smax(d, -elipsoide(m, np.array([0.049, -0.044, -0.066]), np.array([0.018, 0.020, 0.016])), 0.02)
	d = smax(d, -elipsoide(m, np.array([0.074, 0.022, -0.036]), np.array([0.011, 0.024, 0.022])), 0.018)
	d = smax(d, -elipsoide(m, gp.ORBITA, np.array([0.0190, 0.0172, 0.0165])), 0.006)
	d = smin(d, capsula(p, np.array([0.0, 0.004, -0.083]), np.array([0.0, -0.027, -0.104]), 0.0065), 0.012)
	d = smin(d, elipsoide(p, np.array([0.0, -0.031, -0.104]), np.array([0.010, 0.0085, 0.009])), 0.008)
	d = smin(d, elipsoide(m, np.array([0.0105, -0.034, -0.098]), np.array([0.0075, 0.0065, 0.0075])), 0.006)
	d = smax(d, -elipsoide(m, np.array([0.0062, -0.039, -0.102]), np.array([0.0032, 0.0022, 0.0048])), 0.002)
	# A boca nova.
	q = p - BOCA_C
	q = q.copy()
	q[..., 1] = p[..., 1] - meio(p[..., 0])
	d = smin(d, elipsoide(q, np.array([0.0, 0.0, -0.001]), np.array([0.034, 0.013, 0.008])), 0.008)
	d = d - labios(p) - relevo(p)
	d = smax(d, -abertura(p), 0.0035)
	d = smax(d, -gp.boca_cavidade(p), 0.006)
	d = smin(d, elipsoide(m, np.array([0.074, -0.004, 0.012]), np.array([0.009, 0.026, 0.016])), 0.007)
	d = smax(d, -elipsoide(m, np.array([0.082, -0.004, 0.013]), np.array([0.0035, 0.016, 0.009])), 0.003)
	d = smin(d, capsula(p, np.array([0.0, -0.075, 0.022]), np.array([0.0, -0.215, 0.030]), 0.040), 0.03)
	d = smin(d, capsula(m, np.array([0.052, -0.050, 0.030]), np.array([0.014, -0.205, -0.030]), 0.0085), 0.014)
	d = smin(d, elipsoide(p, np.array([0.0, -0.138, -0.012]), np.array([0.008, 0.011, 0.007])), 0.012)
	d = np.maximum(d, -(p[..., 1] + 0.205))
	d += (gp.RUIDO(p, 45.0) - 0.5) * 0.0022 + (gp.RUIDO(p, 140.0) - 0.5) * 0.0007
	return d


def na_boca(p):
	"""Dentro da fenda ou da boca (com a folga do smax que as cava)."""
	return (abertura(p) < 0.003) | (gp.boca_cavidade(p) < 0.005)


# --- os rasgos de cada golpe --------------------------------------------------
# Onde o labio de cima parte (golpe 1), onde o de baixo parte (golpe 2), a aba
# do labio de cima que fica pendurada (golpe 3) e o canto que rasga para a
# bochecha (golpe 2, o direito).
PARTE_CIMA = -0.006
PARTE_BAIXO = 0.004
ABA = (-0.003, 0.013)


def rasgos(v):
	"""Para cada vertice (posicao de repouso): o deslocamento de cada golpe (3
	arrays N x 3, incrementais), a carne viva de cada golpe (3 arrays 0..1) e o
	inchaco (0..1)."""
	x, y, z = v[:, 0], v[:, 1], v[:, 2]
	n = len(v)
	bc = borda_cima(x)
	bb = borda_baixo(x)
	vc = y - bc
	vb = bb - y
	frente = ss(-0.074, -0.088, z)
	faixa_c = ss(-0.004, -0.001, vc) * ss(0.011, 0.007, vc) * frente
	faixa_b = ss(-0.004, -0.001, vb) * ss(0.013, 0.009, vb) * frente
	inch = np.maximum(ss(0.009, 0.002, np.abs(vc - 0.003)) * (vc > -0.003),
		ss(0.011, 0.003, np.abs(vb - 0.004)) * (vb > -0.003)) * frente * envelope_labio(x)

	# Golpe 1: o labio de cima parte em PARTE_CIMA (os dois lados se afastam e a
	# borda sobe em V), e os dois labios incham.
	d1 = np.zeros((n, 3))
	dx = x - PARTE_CIMA
	d1[:, 0] = np.sign(dx) * 0.0017 * np.exp(-(dx / 0.0030) ** 2) * faixa_c
	d1[:, 1] = 0.0038 * np.exp(-(dx / 0.0024) ** 2) * ss(0.010, 0.0, vc) * faixa_c
	d1[:, 2] = -0.0007 * inch
	r1 = np.exp(-(dx / 0.0019) ** 2) * faixa_c * ss(0.010, 0.004, vc)

	# Golpe 2: o canto direito rasga para a bochecha (em cima sobe, embaixo
	# desce, abrindo ate 2,4 mm e afinando para a ponta), o labio de baixo cai
	# mais do lado direito e parte em PARTE_BAIXO.
	d2 = np.zeros((n, 3))
	x0, x1 = XC_DIR - 0.004, XC_DIR + 0.015
	# O rasgo sobe um pouco para a bochecha, torto.
	yt = meio(x) + 0.14 * np.maximum(x - x0, 0.0) + 0.0005 * np.sin(x * 700.0)
	t = np.clip((x - x0) / (x1 - x0), 0.0, 1.0)
	abre = 0.0038 * (1.0 - t) ** 0.7 * ss(x0 - 0.004, x0, x) * ss(x1 + 0.001, x1 - 0.002, x)
	lado = np.tanh((y - yt) / 0.0006)
	perto = np.exp(-(np.abs(y - yt) / 0.0045) ** 2) * ss(-0.068, -0.084, z)
	d2[:, 1] = lado * abre * perto
	r2 = np.exp(-((y - yt) / 0.0016) ** 2) * (abre > 0.0002) * ss(-0.068, -0.084, z) \
		* np.clip(abre / 0.0012, 0.0, 1.0)
	cai = -0.0026 * np.exp(-((x - 0.012) / 0.011) ** 2) * faixa_b * (x > -0.01)
	d2[:, 1] += cai
	dxb = x - PARTE_BAIXO
	d2[:, 0] += np.sign(dxb) * 0.0010 * np.exp(-(dxb / 0.0026) ** 2) * faixa_b
	d2[:, 1] += -0.0022 * np.exp(-(dxb / 0.0019) ** 2) * ss(0.010, 0.0, vb) * faixa_b
	r2 = np.maximum(r2, np.exp(-(dxb / 0.0014) ** 2) * faixa_b * ss(0.010, 0.004, vb))
	d2[:, 2] += -0.0005 * inch

	# Golpe 3: a aba do labio de cima entre ABA[0] e ABA[1] rasga dos dois lados
	# e cai sobre os tocos, virando um fio para fora; e tudo incha mais.
	# A aba nao e um bloco: afina para baixo, as bordas rasgadas serrilham, o
	# lado direito cai mais (torta), a ponta vira para fora e a borda de baixo
	# e irregular.
	d3 = np.zeros((n, 3))
	sv = np.clip(1.0 - vc / 0.0095, 0.0, 1.0) * (vc > -0.004)
	xa = ABA[0] + 0.0016 * sv + 0.0006 * np.sin(sv * 17.0 + 2.0) + 0.0003 * np.sin(y * 3100.0)
	xb = ABA[1] - 0.0042 * sv + 0.0006 * np.sin(sv * 13.0 + 0.5) + 0.0003 * np.sin(y * 2700.0 + 1.0)
	dentro = ss(xa - 0.0005, xa + 0.0010, x) * ss(xb + 0.0005, xb - 0.0010, x)
	lado_d = np.clip((x - xa) / np.maximum(xb - xa, 1e-4), 0.0, 1.0)
	aba = dentro * sv ** 0.8 * frente
	d3[:, 1] = -0.0070 * aba * (0.8 + 0.4 * lado_d) - 0.0013 * dentro * sv ** 3 * frente \
		* (0.5 + 0.5 * np.sin(x * 1500.0 + 0.7))
	d3[:, 2] = -0.0026 * dentro * sv ** 1.5 * frente
	d3[:, 0] = 0.0012 * aba * (lado_d - 0.5)
	r3 = (np.exp(-((x - xa) / 0.0011) ** 2) + np.exp(-((x - xb) / 0.0011) ** 2)) \
		* faixa_c * ss(0.011, 0.006, vc)
	d3[:, 2] += -0.0006 * inch
	return [d1, d2, d3], [np.clip(r1, 0, 1), np.clip(r2, 0, 1), np.clip(r3, 0, 1)], inch


def mascaras(v):
	"""As mascaras da pele (as de `gerar_padre.mascaras_pele`) com a boca nova: o
	vermelhao do labio com a borda marcada e o arco do cupido."""
	olheira, _, _, _, veia = gp.mascaras_pele(v)
	x, y, z = v[:, 0], v[:, 1], v[:, 2]
	el = envelope_labio(x)
	arco = 0.0012 * np.exp(-((np.abs(x) - 0.005) / 0.003) ** 2) - 0.0007 * np.exp(-(x / 0.0022) ** 2)
	vb_cima = borda_cima(x) + (0.0052 + arco) * el
	vb_baixo = borda_baixo(x) - 0.0072 * el
	m = meio(x)
	cima = ss(vb_cima + 0.0005, vb_cima - 0.0005, y) * (y > m)
	baixo = ss(vb_baixo - 0.0005, vb_baixo + 0.0005, y) * (y <= m)
	labio = np.maximum(cima, baixo) * ss(xc(x) + 0.004, xc(x) + 0.001, np.abs(x)) * ss(-0.076, -0.088, z)
	db = abertura(v)
	dc = gp.boca_cavidade(v)
	goela = np.maximum(ss(0.001, -0.003, db) * ss(-0.092, -0.084, z), ss(0.006, 0.0, dc))
	abaixo = ss(0.002, -0.010, y - m)
	frente = ss(0.035, 0.005, z)
	pescoco = ss(-0.150, -0.118, y)
	lado = 1.0 - 0.45 * ss(0.030, 0.055, np.abs(x))
	queixada = abaixo * frente * pescoco * lado
	queixada = np.where(goela > 0.5, ss(m, m - 0.008, y) * frente, queixada)
	return olheira, labio, goela, queixada, veia
