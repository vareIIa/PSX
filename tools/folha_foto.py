"""Folha FOTO para os atlas de flora (PLANO_FLORA_AAA, rodada 3).

As folhas dos atlas das rodadas 1 e 2 eram DESENHADAS (`Tela.folha`: elipse com
nervura e dobra). De perto, em 4K, liam como ilustracao. Aqui cada folha e uma
FOTO escaneada do ambientCG (CC0, `tools/baixar_flora_cc0.py`): o contorno, a
nervura, a mancha, o furo de lagarta e o relevo sao da folha de verdade.

Como a foto vira folha do atlas
-------------------------------
1. Cada LeafSet e uma prancha de 2048 com 4 a 16 folhas soltas sobre fundo
   transparente, com mapa de opacidade, cor, normal (OpenGL) e rugosidade.
2. `banco(id)` separa as folhas (componente conexo da opacidade), acha o eixo de
   cada uma (componente principal da mascara) e gira a folha para o eixo x,
   peciolo a esquerda — o mesmo referencial do `Tela.folha` (u da base a ponta).
   O mapa normal gira junto, VETOR e imagem.
3. Guarda uma piramide de cada folha (media 2x2 pre-multiplicada pelo alfa): a
   folha do atlas tem de 30 a 300 px e a foto 700; sem a piramide a reducao
   serrilharia o contorno.
4. `Tela.folha_foto` (em gerar_vegetacao_hd.py) carimba a folha no ramo com a
   mesma altura, inclinacao, dobra e arco da folha desenhada, e soma a normal da
   foto a normal da forma.

A COR da especie continua a da tabela (o verde escuro da mangueira, o claro do
abacateiro): a foto entra como DETALHE relativo (cor do pixel / cor media da
folha), porque as pranchas sao escaneadas a luz chapada e o verde delas e claro
demais para copa de Minas, e porque a tinta de vertice da copa multiplica por
cima (memoria "tinta multiplica a celula").
"""
from __future__ import annotations

import io
import math
import zipfile
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent
CACHE = RAIZ / ".tools" / "cache_flora"

# Para onde aponta o peciolo na prancha escaneada (a base da folha).
BASE = {
    "LeafSet001": (0, 1), "LeafSet003": (0, 1), "LeafSet004": (0, 1), "LeafSet013": (0, 1),
    "LeafSet014": (0, 1), "LeafSet017": (0, 1), "LeafSet018": (0, 1), "LeafSet022": (0, 1),
    "LeafSet024": (0, 1), "Leaf003": (0, 1), "LeafSet023": (-1, 0), "LeafSet006": (-1, 0),
    "LeafSet008": (-1, 0), "LeafSet030": (1, 0), "LeafSet021": (0, 1),
    "Foliage001": (0, 1), "Foliage004": (0, 1), "Foliage006": (0, 1), "Foliage002": (0, 1),
    "Foliage003": (0, 1),
}

# Folha larga, sem eixo claro: gira pela prancha, e nao pela mascara.
FIXO = {"LeafSet017", "LeafSet004", "LeafSet023"}

_BANCOS: dict[str, list["Folha"]] = {}


class Folha:
    """Uma folha da foto, deitada no eixo x (base em x = 0, ponta em x = W)."""

    def __init__(self, cor: np.ndarray, a: np.ndarray, n: np.ndarray, r: np.ndarray):
        self.niveis = []
        cor_p = cor * a[..., None]
        n_p = n * a[..., None]
        r_p = r * a
        nivel = (cor_p, a, n_p, r_p)
        while True:
            c, aa, nn, rr = nivel
            pa = np.maximum(aa, 1e-4)
            self.niveis.append((c / pa[..., None], aa, nn / pa[..., None], rr / pa))
            h, w = aa.shape
            if min(h, w) < 12:
                break
            h2, w2 = h // 2, w // 2
            nivel = tuple(x[:h2 * 2, :w2 * 2].reshape(h2, 2, w2, 2, *x.shape[2:]).mean(axis=(1, 3))
                          for x in nivel)
        m = a > 0.5
        self.W = a.shape[1]
        self.H = a.shape[0]
        self.media = (cor[m].mean(axis=0) if m.any() else np.float32([0.4, 0.5, 0.2])).astype(np.float32)
        self.rug_media = float(r[m].mean()) if m.any() else 0.5
        # Largura relativa: meia-largura maxima sobre o comprimento.
        col = m.any(axis=0)
        self.razao = float(self.H) / float(max(self.W, 1))
        self.comp_util = float(col.sum()) / float(max(self.W, 1))

    def nivel_para(self, comp_px: float):
        k = 0
        while k + 1 < len(self.niveis) and self.niveis[k + 1][1].shape[1] >= comp_px:
            k += 1
        return self.niveis[k]


def _ler(z: zipfile.ZipFile, sufixo: str, modo: str):
    for nome in z.namelist():
        if nome.endswith(sufixo):
            return Image.open(io.BytesIO(z.read(nome))).convert(modo)
    return None


def _componentes(m: np.ndarray, minimo: int) -> list[tuple[int, int, int, int]]:
    """Caixas (y0, y1, x0, x1) dos componentes conexos de `m` (4 vizinhos)."""
    h, w = m.shape
    visto = np.zeros_like(m, bool)
    caixas = []
    for y in range(h):
        for x in range(w):
            if not m[y, x] or visto[y, x]:
                continue
            fila = deque([(y, x)])
            visto[y, x] = True
            y0 = y1 = y
            x0 = x1 = x
            n = 0
            while fila:
                cy, cx = fila.popleft()
                n += 1
                y0, y1, x0, x1 = min(y0, cy), max(y1, cy), min(x0, cx), max(x1, cx)
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ny, nx = cy + dy, cx + dx
                    if 0 <= ny < h and 0 <= nx < w and m[ny, nx] and not visto[ny, nx]:
                        visto[ny, nx] = True
                        fila.append((ny, nx))
            if n >= minimo:
                caixas.append((y0, y1 + 1, x0, x1 + 1))
    return caixas


def _girar(arr: np.ndarray, graus: float) -> np.ndarray:
    """Gira cada canal (PIL, modo F) pelo centro, com a tela aumentada."""
    if arr.ndim == 2:
        return np.array(Image.fromarray(arr.astype(np.float32), "F").rotate(
            graus, resample=Image.BILINEAR, expand=True), np.float32)
    return np.dstack([_girar(arr[..., k], graus) for k in range(arr.shape[2])])


def banco(asset_id: str, maximo: int = 24) -> list[Folha]:
    """As folhas de uma prancha, deitadas no eixo x. Vazio sem o cache."""
    if asset_id in _BANCOS:
        return _BANCOS[asset_id]
    caminho = CACHE / f"{asset_id}_2K-JPG.zip"
    if not caminho.exists():
        _BANCOS[asset_id] = []
        return []
    z = zipfile.ZipFile(caminho)
    cor = _ler(z, "_Color.jpg", "RGB")
    op = _ler(z, "_Opacity.jpg", "L")
    nor = _ler(z, "_NormalGL.jpg", "RGB")
    rug = _ler(z, "_Roughness.jpg", "L")
    if cor is None or op is None:
        _BANCOS[asset_id] = []
        return []
    cor = np.asarray(cor, np.float32) / 255.0
    a = np.asarray(op, np.float32) / 255.0
    n = (np.asarray(nor, np.float32) / 255.0 * 2.0 - 1.0) if nor is not None \
        else np.dstack([np.zeros_like(a), np.zeros_like(a), np.ones_like(a)])
    # OpenGL: G para CIMA na imagem; aqui, como no atlas, v cresce para BAIXO.
    n[..., 1] = -n[..., 1]
    r = (np.asarray(rug, np.float32) / 255.0) if rug is not None else np.full_like(a, 0.5)
    k = 8
    h, w = a.shape
    peq = a[:h // k * k, :w // k * k].reshape(h // k, k, w // k, k).max(axis=(1, 3)) > 0.3
    caixas = _componentes(peq, 12)
    base = BASE.get(asset_id, (0, 1))
    folhas: list[Folha] = []
    for (y0, y1, x0, x1) in caixas:
        y0, y1, x0, x1 = max(0, y0 * k - 4), min(h, y1 * k + 4), max(0, x0 * k - 4), min(w, x1 * k + 4)
        aa = a[y0:y1, x0:x1].copy()
        m = aa > 0.5
        if m.sum() < 400:
            continue
        # Componente principal da mascara: o eixo da folha.
        ys, xs = np.nonzero(m)
        cx, cy = xs.mean(), ys.mean()
        cov = np.cov(np.vstack([xs - cx, ys - cy]))
        val, vec = np.linalg.eigh(cov)
        eixo = vec[:, int(np.argmax(val))]
        if asset_id in FIXO:
            # Folha larga (hera): o eixo principal da mascara cai de lado; o eixo
            # e o da prancha, do peciolo para a ponta.
            eixo = -np.float64(base)
        # A base fica do lado para onde o peciolo aponta na prancha.
        if eixo[0] * base[0] + eixo[1] * base[1] > 0.0:
            eixo = -eixo
        # O eixo aponta da base para a ponta; gira para +x. PIL gira no sentido
        # anti-horario da TELA; em y para baixo, o vetor (x, y) vai para
        # (x cos + y sen, -x sen + y cos).
        ang = math.degrees(math.atan2(-eixo[1], eixo[0]))
        cc = cor[y0:y1, x0:x1]
        nn = n[y0:y1, x0:x1]
        rr = r[y0:y1, x0:x1]
        ag = _girar(aa, -ang)
        cg = _girar(cc * aa[..., None], -ang)
        ng = _girar(nn * aa[..., None], -ang)
        rg = _girar(rr * aa, -ang)
        pa = np.maximum(ag, 1e-4)
        cg /= pa[..., None]
        ng /= pa[..., None]
        rg /= pa
        # O vetor gira junto: a imagem girou -ang na tela.
        fi = math.radians(-ang)
        nx = ng[..., 0] * math.cos(fi) + ng[..., 1] * math.sin(fi)
        ny = -ng[..., 0] * math.sin(fi) + ng[..., 1] * math.cos(fi)
        ng = np.dstack([nx, ny, ng[..., 2]])
        m2 = ag > 0.5
        if not m2.any():
            continue
        ys, xs = np.nonzero(m2)
        ya, yb, xa, xb = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        # Centro na nervura (o meio da caixa em y), um pixel de folga.
        ya, yb = max(0, ya - 1), min(ag.shape[0], yb + 1)
        xa, xb = max(0, xa - 1), min(ag.shape[1], xb + 1)
        fo = Folha(np.clip(cg[ya:yb, xa:xb], 0, 1), np.clip(ag[ya:yb, xa:xb], 0, 1),
                   ng[ya:yb, xa:xb], np.clip(rg[ya:yb, xa:xb], 0, 1))
        # Capim e pendao sao compridos: o componente largo de uma prancha de
        # capim e sobra de recorte (virava um borrao rosa no capim-gordura).
        if asset_id.startswith("Foliage") and fo.razao > 0.2:
            continue
        folhas.append(fo)
        if len(folhas) >= maximo:
            break
    _BANCOS[asset_id] = folhas
    return folhas


def amostrar(img: np.ndarray, sx: np.ndarray, sy: np.ndarray) -> np.ndarray:
    """Bilinear de `img` (h, w[, c]) nas coordenadas de pixel (sx, sy)."""
    h, w = img.shape[:2]
    x0 = np.clip(np.floor(sx - 0.5), 0, w - 1).astype(np.int32)
    y0 = np.clip(np.floor(sy - 0.5), 0, h - 1).astype(np.int32)
    x1 = np.minimum(x0 + 1, w - 1)
    y1 = np.minimum(y0 + 1, h - 1)
    fx = np.clip(sx - 0.5 - x0, 0.0, 1.0)
    fy = np.clip(sy - 0.5 - y0, 0.0, 1.0)
    if img.ndim == 3:
        fx = fx[..., None]
        fy = fy[..., None]
    a = img[y0, x0] * (1 - fx) + img[y0, x1] * fx
    b = img[y1, x0] * (1 - fx) + img[y1, x1] * fx
    return a * (1 - fy) + b * fy


def disponivel() -> bool:
    return CACHE.exists() and any(CACHE.glob("LeafSet*_2K-JPG.zip"))
