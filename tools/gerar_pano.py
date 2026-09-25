"""Gera o pano 4K do capuz, da murca e da batina dos encapuzados da estrada.

La grossa de batina velha: sarja 2/2 de fio fiado a mao (grosso e fino ao longo
do fio, cada fio num tom), fibra solta em cima da trama, feltro onde o pano
esfrega, sujeira e furos de traca com a trama desfiada em volta.

Saidas em game/assets/monstros/pano/ (4096x4096, tileaveis, o tile cobre
TILE_M metros de pano):
- pano_mapa.png  RGBA
    R  altura da trama (0 fundo, 1 topo do fio)
    G  tom do fio (varia fio a fio, com a fibra)
    B  desgaste: onde o pano feltrou e ficou liso e ralo
    A  furo: 1 no buraco, cai a zero na borda desfiada (o shader corta por
       limiar, e o limiar cresce com o quanto o pano e velho)
- pano_n.png     normal (espaco tangente, +Y para cima na imagem)

Uso:
    python tools/gerar_pano.py [--previa DIR]
"""
import os
import sys

import numpy as np
from PIL import Image

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SAIDA = os.path.join(RAIZ, 'game', 'assets', 'monstros', 'pano')
TEX = 4096
TILE_M = 0.40
# Fios por tile em cada direcao: 2 mm de fio, la grossa.
FIOS = 196
# Profundidade da trama em metros, para a normal.
PROF = 0.0009
FUROS = 5


def espectro(n):
	fy = np.fft.fftfreq(n)[:, None].astype(np.float32)
	fx = np.fft.rfftfreq(n)[None, :].astype(np.float32)
	return fx, fy


def normalizar(r):
	r = r - r.min()
	return (r / max(r.max(), 1e-9)).astype(np.float32)


def fbm(n, beta, semente, corte=None):
	"""Ruido fractal tileavel (1/f^beta), opcionalmente sem as altas."""
	g = np.random.default_rng(semente)
	F = np.fft.rfft2(g.standard_normal((n, n)).astype(np.float32))
	fx, fy = espectro(n)
	f = np.sqrt(fx * fx + fy * fy)
	f[0, 0] = 1.0
	F *= 1.0 / f ** beta
	if corte is not None:
		F *= np.exp(-(f / corte) ** 2)
	F[0, 0] = 0
	return normalizar(np.fft.irfft2(F, s=(n, n)))


def estirado(n, semente, sx, sy):
	"""Ruido tileavel esticado: fibra que corre ao longo de um eixo."""
	g = np.random.default_rng(semente)
	F = np.fft.rfft2(g.standard_normal((n, n)).astype(np.float32))
	fx, fy = espectro(n)
	F *= np.exp(-(fx / sx) ** 2 - (fy / sy) ** 2)
	F[0, 0] = 0
	return normalizar(np.fft.irfft2(F, s=(n, n)))


def borrar(img, sigma):
	n = img.shape[0]
	F = np.fft.rfft2(img)
	fx, fy = espectro(n)
	F *= np.exp(-2 * (np.pi * sigma) ** 2 * (fx * fx + fy * fy))
	return np.fft.irfft2(F, s=img.shape).astype(np.float32)


def ss(a, b, x):
	t = np.clip((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


def por_fio(indice, semente, lo, hi):
	"""Um valor sorteado por fio (indice inteiro, com a volta do tile)."""
	g = np.random.default_rng(semente)
	tabela = g.uniform(lo, hi, FIOS).astype(np.float32)
	return tabela[np.mod(indice, FIOS)]


def trama(n):
	print('pano: trama...')
	eixo = (np.arange(n, dtype=np.float32) + 0.5) / n * FIOS
	# O fio fiado a mao nao corre reto: ondula devagar, e o pano esticado no
	# corpo puxa a trama. Deslocamento em fracao de fio, tileavel.
	ox = (fbm(n, 2.4, 31) - 0.5) * 1.6 + (fbm(n, 1.5, 131, 0.02) - 0.5) * 0.9
	oy = (fbm(n, 2.4, 32) - 0.5) * 1.6 + (fbm(n, 1.5, 132, 0.02) - 0.5) * 0.9
	u = eixo[None, :] + ox
	v = eixo[:, None] + oy
	i = np.floor(u).astype(np.int32)
	j = np.floor(v).astype(np.int32)
	fu = u - i
	fv = v - j

	# Espessura do fio: sorteada por fio e variando ao longo dele (o slub da
	# la fiada a mao, grosso e fino).
	slub_v = estirado(n, 33, 0.35 * FIOS / n * 4, 3.0 / n * 40)
	slub_h = estirado(n, 34, 3.0 / n * 40, 0.35 * FIOS / n * 4)
	esp_urdume = por_fio(i, 35, 0.70, 1.05) * (0.70 + 0.55 * slub_v)
	esp_trama = por_fio(j, 36, 0.70, 1.05) * (0.70 + 0.55 * slub_h)

	# Sarja 2/2: o urdume fica por cima quando (i + j) mod 4 < 2. A passagem de
	# cima para baixo e suave entre os centros de celula.
	def estado(ii, jj):
		return np.where(np.mod(ii + jj, 4) < 2, 1.0, -1.0).astype(np.float32)

	tv = v - 0.5
	j0 = np.floor(tv).astype(np.int32)
	s_urdume = estado(i, j0) + (estado(i, j0 + 1) - estado(i, j0)) * ss(0.0, 1.0, tv - j0)
	tu = u - 0.5
	i0 = np.floor(tu).astype(np.int32)
	s_trama = -(estado(i0, j) + (estado(i0 + 1, j) - estado(i0, j)) * ss(0.0, 1.0, tu - i0))

	def perfil(f, e):
		d = (f - 0.5) / (0.5 * e)
		return np.clip(1.0 - d * d, 0.0, 1.0) ** 0.8

	h_urdume = perfil(fu, esp_urdume) * (0.58 + 0.42 * s_urdume)
	h_trama = perfil(fv, esp_trama) * (0.58 + 0.42 * s_trama)

	# A fibra: estrias ao longo de cada fio, e a torcao do fio (listras
	# inclinadas de meio fio).
	print('pano: fibra...')
	fibra_v = estirado(n, 37, 0.9 * FIOS / n * 6, 0.9 * FIOS / n)
	fibra_h = estirado(n, 38, 0.9 * FIOS / n, 0.9 * FIOS / n * 6)
	torcao_v = 0.5 + 0.5 * np.sin((fu * 1.0 + v * 2.2) * 2 * np.pi)
	torcao_h = 0.5 + 0.5 * np.sin((fv * 1.0 + u * 2.2) * 2 * np.pi)
	h_urdume = h_urdume * (0.80 + 0.14 * fibra_v + 0.10 * torcao_v)
	h_trama = h_trama * (0.80 + 0.14 * fibra_h + 0.10 * torcao_h)
	cima_urdume = h_urdume >= h_trama
	altura = np.maximum(h_urdume, h_trama)

	# Tom: cada fio foi tingido num banho um pouco diferente.
	tom = np.where(cima_urdume,
		por_fio(i, 39, 0.0, 1.0) * 0.55 + fibra_v * 0.45,
		por_fio(j, 40, 0.0, 1.0) * 0.55 + fibra_h * 0.45).astype(np.float32)
	return altura.astype(np.float32), tom


def feltro(n, altura):
	print('pano: feltro e penugem...')
	# Penugem: fibra solta em cima da trama, que enche o vao entre os fios.
	penugem = fbm(n, 0.9, 41)
	penugem = borrar(penugem, 1.2)
	penugem = normalizar(penugem)
	# Onde o pano esfrega (cotovelo, barra, ombro) a trama feltra: lisa, rala,
	# e a penugem deita. Manchas grandes e medias.
	desgaste = normalizar(fbm(n, 2.3, 42) * 0.7 + fbm(n, 1.6, 43) * 0.3)
	desgaste = ss(0.38, 0.80, desgaste)
	liso = borrar(altura, 5.0)
	# Bolinhas de la (pilling): nos acima do feltro.
	bolas = ss(0.80, 0.93, fbm(n, 0.4, 44)) * ss(0.30, 0.6, desgaste + 0.2)
	bolas = borrar(bolas, 2.0)
	# Penugem grossa, em tufos: a la velha nao mostra o fio limpo em lugar
	# nenhum.
	tufos = normalizar(borrar(fbm(n, 0.7, 45), 3.0))
	# O vao entre os fios nunca fica vazio: a fibra solta enche ate um terco,
	# e a borda do fio some nela (maximo suave).
	fundo = 0.30 + 0.30 * penugem + 0.15 * tufos
	k = 0.12
	altura = np.maximum(altura, fundo) + k * np.log1p(np.exp(-np.abs(altura - fundo) / k)) - k * np.log(2.0)
	# Pelo: fibra fina e arrepiada por cima de tudo, sem borrar.
	pelo = fbm(n, 0.35, 46)
	h = altura * 0.70 + penugem * 0.10 + tufos * 0.10 + pelo * 0.10
	h = h * (1.0 - desgaste * 0.60) + liso * desgaste * 0.42 + penugem * desgaste * 0.16
	h = np.maximum(h, bolas * 0.9)
	return np.clip(h, 0, 1).astype(np.float32), desgaste.astype(np.float32)


def furos(n, altura):
	print('pano: furos de traca...')
	g = np.random.default_rng(51)
	ang = fbm(n, 1.4, 52)
	borda = fbm(n, 1.1, 53)
	yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
	mascara = np.zeros((n, n), np.float32)
	for _ in range(FUROS):
		cx, cy = g.uniform(0, n, 2)
		r = g.uniform(0.006, 0.020) * n
		# Distancia com a volta do tile.
		dx = np.abs(xx - cx)
		dy = np.abs(yy - cy)
		dx = np.minimum(dx, n - dx)
		dy = np.minimum(dy, n - dy)
		d = np.sqrt(dx * dx + dy * dy)
		# Contorno roido: a traca come fio a fio.
		rr = r * (0.55 + 0.9 * borda + 0.25 * np.sin(ang * 12.0))
		mascara = np.maximum(mascara, ss(1.35, 0.6, d / np.maximum(rr, 1.0)))
	# Na borda do furo sobram fios soltos: o furo passa pelo vao, nao pelo fio.
	furo = np.clip(mascara * 1.25 - altura * 0.45 * (mascara < 0.98), 0, 1)
	return furo.astype(np.float32)


def normal(altura):
	h = altura * PROF
	passo = TILE_M / altura.shape[0]
	dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) / (2 * passo)
	dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) / (2 * passo)
	nn = np.stack([-dx, dy, np.ones_like(h)], -1)
	nn /= np.linalg.norm(nn, axis=-1, keepdims=True)
	return nn


def main():
	args = sys.argv[1:]
	dir_previa = args[args.index('--previa') + 1] if '--previa' in args else None
	n = TEX
	altura, tom = trama(n)
	altura, desgaste = feltro(n, altura)
	furo = furos(n, altura)
	altura = altura * (1.0 - furo)
	os.makedirs(SAIDA, exist_ok=True)
	mapa = np.stack([altura, tom, desgaste, furo], -1)
	Image.fromarray((np.clip(mapa, 0, 1) * 255 + 0.5).astype(np.uint8), 'RGBA').save(
		os.path.join(SAIDA, 'pano_mapa.png'))
	nn = normal(altura)
	Image.fromarray(((nn * 0.5 + 0.5) * 255 + 0.5).astype(np.uint8), 'RGB').save(
		os.path.join(SAIDA, 'pano_n.png'))
	if dir_previa:
		os.makedirs(dir_previa, exist_ok=True)
		# Um recorte 1:1 e o tile inteiro reduzido, com uma luz rasante.
		luz = np.clip(nn[..., 0] * -0.6 + nn[..., 1] * 0.5 + nn[..., 2] * 0.62, 0, 1)
		cor = (0.10 + 0.9 * luz) * (0.75 + 0.25 * tom) * (1.0 - 0.8 * furo)
		img = (np.clip(cor, 0, 1) * 255).astype(np.uint8)
		Image.fromarray(img[:1024, :1024]).save(os.path.join(dir_previa, 'pano_recorte.png'))
		Image.fromarray(img).resize((1024, 1024), Image.LANCZOS).save(
			os.path.join(dir_previa, 'pano_tile.png'))
	print('ok pano')


if __name__ == '__main__':
	main()
