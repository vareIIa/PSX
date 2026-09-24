#!/usr/bin/env python3
"""Atlas HD da vegetacao (MODERNO): cor, relevo e rugosidade de cada cartao.

    python tools/gerar_vegetacao_hd.py              os tres mapas, 4096 px
    python tools/gerar_vegetacao_hd.py --previa=DIR  e uma folha de contato
    python tools/gerar_vegetacao_hd.py --saida=DIR   grava fora do jogo (ensaio)

PLANO_FLORA_AAA, etapa 1. O `gerar_vegetacao.py` continua dono do atlas do PS1
STYLE (256 px, desenho chapado, 96 cores); este aqui so escreve o conjunto HD,
com as MESMAS dezesseis celulas no MESMO lugar, porque a UV do cartao e uma so
para os dois estilos.

O que muda do atlas antigo
--------------------------
O antigo pintava cada folha como uma elipse de cor chapada dentro de uma mancha
redonda. De perto a copa lia como ilustracao; contra o sol, como papelao.

Aqui cada celula e um RAMO construido: galhos que saem do fundo da copa, folhas
presas neles pela filotaxia da especie (a mangueira em roseta na ponta, o oiti
alternado, o ipe com o cacho de flor na ponta), e cada folha e uma superficie
com altura: inclinada, dobrada na nervura, arqueada. Tudo cai num buffer de
profundidade, e dele saem os quatro mapas:

    vegetacao_atlas.png      cor (sRGB) e alfa de cobertura
    vegetacao_atlas_n.png    normal em espaco de tangente: R = +u, G = +v
                             (v cresce PARA BAIXO na imagem, como a UV do Godot
                             e a base_tangente do psx_folha_pixel)
    vegetacao_atlas_ru.png   R rugosidade, G oclusao, B espessura (luz atraves)

A oclusao vem da profundidade: folha muito abaixo das vizinhas esta no miolo do
ramo e recebe menos ceu. A espessura e 1 na folha fina, cai no galho e na folha
seca; e ela que o shader usa para acender a copa contra o sol.

Desenho em 2x e reduz: a borda da folha sai com meio-tom, e o alfa de cobertura
da reducao e o que o mipmap do Godot continua.
"""

import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent
SAIDA_HD = RAIZ / "game" / "assets" / "textures_hd"

CEL = 1024          # lado da celula no atlas final (4 x 4 = 4096)
SS = 2              # superamostragem do desenho
N = 4
MARGEM = 0.05       # borda livre de cada celula (fracao do lado)

FUNDO = -1.0e9


def srgb(c):
    return np.array(c, np.float32) / 255.0


def suave(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


# --------------------------------------------------------------------- filtros

MODO = "edge"


def _max1(a: np.ndarray, r: int, eixo: int) -> np.ndarray:
    pad = [(0, 0)] * a.ndim
    pad[eixo] = (r, r)
    p = np.pad(a, pad, mode=MODO)
    v = np.lib.stride_tricks.sliding_window_view(p, 2 * r + 1, axis=eixo)
    return v.max(axis=-1)


def maximo(a: np.ndarray, r: int) -> np.ndarray:
    return _max1(_max1(a, r, 0), r, 1)


def _caixa1(a: np.ndarray, r: int, eixo: int) -> np.ndarray:
    pad = [(0, 0)] * a.ndim
    pad[eixo] = (r + 1, r)
    p = np.pad(a, pad, mode=MODO)
    c = np.cumsum(p, axis=eixo, dtype=np.float64)
    n = a.shape[eixo]
    alto = np.take(c, np.arange(2 * r + 1, 2 * r + 1 + n), axis=eixo)
    baixo = np.take(c, np.arange(0, n), axis=eixo)
    return ((alto - baixo) / (2 * r + 1)).astype(np.float32)


def borrar(a: np.ndarray, r: int) -> np.ndarray:
    for _ in range(2):
        a = _caixa1(_caixa1(a, r, 0), r, 1)
    return a


def reduzir(a: np.ndarray, k: int) -> np.ndarray:
    h = a.shape[0] // k
    w = a.shape[1] // k
    return a.reshape(h, k, w, k, *a.shape[2:]).mean(axis=(1, 3))


# ----------------------------------------------------------------------- tela

class Tela:
    """Buffer de desenho de uma celula: profundidade, cor, normal, rugosidade e
    espessura por pixel. `z` cresce para o olho."""

    def __init__(self, lado: int, rng: np.random.Generator, envolve: bool = False):
        """`envolve`: textura de ladrilho (sebe, grama). O desenho que passa de
        uma borda continua na oposta, e nada e descartado na margem."""
        self.L = lado
        self.envolve = envolve
        self._copia = False
        self.rng = rng
        self.z = np.full((lado, lado), FUNDO, np.float32)
        self.cor = np.zeros((lado, lado, 3), np.float32)
        self.n = np.zeros((lado, lado, 3), np.float32)
        self.n[..., 2] = 1.0
        self.rug = np.ones((lado, lado), np.float32)
        self.esp = np.zeros((lado, lado), np.float32)
        lim = 0 if envolve else int(lado * MARGEM)
        self.lim = (lim, lado - lim)

    def _em_volta(self, px, py, r, fn, *a, **k) -> bool:
        """No ladrilho, desenha as copias que atravessam a borda. Devolve True
        se ja desenhou tudo (quem chamou nao desenha de novo)."""
        L = self.L
        if r <= px <= L - r and r <= py <= L - r:
            return False
        self.envolve = False
        self._copia = True
        try:
            for dx in (-L, 0, L):
                for dy in (-L, 0, L):
                    if px + dx + r < 0 or px + dx - r > L or py + dy + r < 0 or py + dy - r > L:
                        continue
                    fn(px + dx, py + dy, *a, **k)
        finally:
            self.envolve = True
            self._copia = False
        return True

    def _caixa(self, x0, y0, x1, y1):
        a, b = self.lim
        x0 = max(a, int(math.floor(x0)))
        y0 = max(a, int(math.floor(y0)))
        x1 = min(b, int(math.ceil(x1)))
        y1 = min(b, int(math.ceil(y1)))
        if x1 <= x0 or y1 <= y0:
            return None
        yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
        return (slice(y0, y1), slice(x0, x1)), xx, yy

    def _gravar(self, sl, m, z, cor, nx, ny, nz, rug, esp):
        zt = self.z[sl]
        w = m & (z > zt)
        if not w.any():
            return
        zt[w] = z[w]
        c = self.cor[sl]
        for k in range(3):
            c[..., k][w] = cor[k][w] if isinstance(cor[k], np.ndarray) else cor[k]
        n = self.n[sl]
        n[..., 0][w] = nx[w]
        n[..., 1][w] = ny[w]
        n[..., 2][w] = nz[w]
        r = self.rug[sl]
        r[w] = rug[w] if isinstance(rug, np.ndarray) else rug
        e = self.esp[sl]
        e[w] = esp[w] if isinstance(esp, np.ndarray) else esp

    # ------------------------------------------------------------------ folha
    def folha(self, px, py, ang, comp, larg, z0, cor, *, forma=(0.4, 0.85),
              incl=0.0, rola=0.0, dobra=0.25, arco=0.12, curva=0.0, rug=0.5,
              esp=0.9, nerv=0.35, cor_nerv=None, n_nerv=7, borda=0.12,
              serra=0, ponta_seca=0.0):
        """Uma folha presa em (px, py), apontando para `ang`, de `comp` pixels
        e meia-largura maxima `larg`. `forma` = (onde a folha e mais larga, de 0
        a 1 do peciolo a ponta; expoente do perfil — abaixo de 1 arredonda, acima
        afina). `incl` e `rola` inclinam a folha (px de altura por px), `dobra`
        e o V da nervura, `arco` a barriga no comprimento, `curva` entorta a
        ponta para o lado."""
        if comp < 1.0 or larg < 0.3:
            return
        if self.envolve:
            r = comp * 1.05 + larg * 1.5 + abs(curva) * comp
            if self._em_volta(px, py, r, self.folha, ang, comp, larg, z0, cor, forma=forma,
                              incl=incl, rola=rola, dobra=dobra, arco=arco, curva=curva,
                              rug=rug, esp=esp, nerv=nerv, cor_nerv=cor_nerv, n_nerv=n_nerv,
                              borda=borda, serra=serra, ponta_seca=ponta_seca):
                return
        elif not self._copia:
            # Folha que sairia da celula nao entra: cortada pela margem ela vira
            # um risco reto no contorno do cartao, que o olho le como papel
            # recortado.
            a0, b0 = self.lim
            ca0, sa0 = math.cos(ang), math.sin(ang)
            for f in (0.5, 1.0):
                qx = px + ca0 * comp * f
                qy = py + sa0 * comp * f
                if min(qx, qy) - larg < a0 or max(qx, qy) + larg > b0:
                    return
        r = comp * 1.05 + larg * 1.5 + abs(curva) * comp
        caixa = self._caixa(px - r, py - r, px + r, py + r)
        if caixa is None:
            return
        sl, xx, yy = caixa
        ca, sa = math.cos(ang), math.sin(ang)
        dx = xx - px
        dy = yy - py
        u = (dx * ca + dy * sa) / comp
        v = (-dx * sa + dy * ca) / larg
        v = v - curva * u * u * (comp / larg)
        p = math.log(0.5) / math.log(max(0.05, min(0.95, forma[0])))
        uu = np.clip(u, 0.0, 1.0)
        w = np.sin(math.pi * uu ** p) ** forma[1]
        if serra:
            w = w * (1.0 - 0.07 * np.abs(np.sin(uu * serra * math.pi)))
        m = (u >= 0.0) & (u <= 1.0) & (np.abs(v) <= w)
        if not m.any():
            return
        av = np.abs(v)
        rel = av / np.maximum(w, 1e-3)
        sv = np.sign(v)
        # Altura e suas derivadas em (u, v).
        g = 0.05 * larg
        sg = 0.07
        e_g = np.exp(-(v / sg) ** 2)
        z = (z0 + incl * comp * u + rola * larg * v + dobra * larg * av
             - arco * comp * (2.0 * u - 1.0) ** 2 - g * e_g)
        dz_du = incl * comp - 4.0 * arco * comp * (2.0 * u - 1.0)
        dz_dv = rola * larg + dobra * larg * sv + g * 2.0 * v / (sg * sg) * e_g
        dz_dx = dz_du * (ca / comp) + dz_dv * (-sa / larg)
        dz_dy = dz_du * (sa / comp) + dz_dv * (ca / larg)
        inv = 1.0 / np.sqrt(dz_dx * dz_dx + dz_dy * dz_dy + 1.0)
        nx = -dz_dx * inv
        ny = -dz_dy * inv
        nz = inv
        # Cor: ponta um pouco mais clara, borda mais escura, nervura clara.
        base = np.asarray(cor, np.float32)
        f = (0.9 + 0.14 * u) * (1.0 - borda * suave(0.72, 1.0, rel))
        ruido = 1.0 + self.rng.normal(0.0, 0.025, m.shape).astype(np.float32)
        f = f * ruido
        cn = base * 1.35 + 0.06 if cor_nerv is None else np.asarray(cor_nerv, np.float32)
        t = u * n_nerv - rel * 1.3
        sec = np.clip(1.0 - np.abs(t - np.round(t)) / 0.06, 0.0, 1.0) * (rel < 0.9) * (u > 0.08)
        mistura = nerv * (np.exp(-(v / 0.045) ** 2) * (u < 0.96) + 0.35 * sec)
        canais = []
        for k in range(3):
            c = base[k] * f
            c = c + (cn[k] - c) * mistura
            if ponta_seca > 0.0:
                seco = suave(1.0 - ponta_seca, 1.0, u) * 0.7
                c = c + (np.float32([0.36, 0.29, 0.16][k]) - c) * seco
            canais.append(c)
        self._gravar(sl, m, z, canais, nx, ny, nz, rug, esp)

    # ------------------------------------------------------------------ galho
    def galho(self, pts, r0, r1, cor, rug=0.85, esp=0.06):
        """Polilinha de (x, y, z), grossura de r0 a r1 pixels, cilindrica."""
        n = len(pts) - 1
        base = np.asarray(cor, np.float32)
        for i in range(n):
            ax, ay, az = pts[i]
            bx, by, bz = pts[i + 1]
            ra = r0 + (r1 - r0) * i / n
            rb = r0 + (r1 - r0) * (i + 1) / n
            rm = max(ra, rb) + 1.0
            caixa = self._caixa(min(ax, bx) - rm, min(ay, by) - rm,
                                max(ax, bx) + rm, max(ay, by) + rm)
            if caixa is None:
                continue
            sl, xx, yy = caixa
            ex, ey = bx - ax, by - ay
            l2 = max(ex * ex + ey * ey, 1e-6)
            t = np.clip(((xx - ax) * ex + (yy - ay) * ey) / l2, 0.0, 1.0)
            cx = ax + t * ex
            cy = ay + t * ey
            ox = xx - cx
            oy = yy - cy
            d = np.sqrt(ox * ox + oy * oy)
            rr = ra + (rb - ra) * t
            m = d <= rr
            if not m.any():
                continue
            ll = math.sqrt(l2)
            px, py = -ey / ll, ex / ll
            off = np.clip((ox * px + oy * py) / np.maximum(rr, 1e-3), -1.0, 1.0)
            h = np.sqrt(np.maximum(1.0 - off * off, 0.0))
            z = az + t * (bz - az) + h * rr
            nx = px * off
            ny = py * off
            f = (0.7 + 0.3 * h) * (1.0 + self.rng.normal(0.0, 0.05, m.shape).astype(np.float32))
            # Casca: listras ao longo do galho.
            f = f * (0.92 + 0.08 * np.sin(off * 9.0 + t * ll * 0.3))
            canais = [base[k] * f for k in range(3)]
            self._gravar(sl, m, z, canais, nx, ny, h, rug, esp)

    # ------------------------------------------------------------------- flor
    def flor(self, px, py, raio, z0, cor, *, petalas=5, miolo=None, giro=0.0,
             funil=0.6, incl=0.0, rola=0.0, rug=0.6, esp=0.85, lobo=0.5, achata=1.0):
        """Flor vista de frente: petalas em volta de uma garganta. `funil` e o
        quanto a garganta afunda (trombeta do ipe) — sai na normal e na sombra."""
        if self.envolve:
            if self._em_volta(px, py, raio + 1, self.flor, raio, z0, cor, petalas=petalas,
                              miolo=miolo, giro=giro, funil=funil, incl=incl, rola=rola,
                              rug=rug, esp=esp, lobo=lobo, achata=achata):
                return
        elif not self._copia:
            a0, b0 = self.lim
            if min(px, py) - raio < a0 or max(px, py) + raio > b0:
                return
        caixa = self._caixa(px - raio - 1, py - raio - 1, px + raio + 1, py + raio + 1)
        if caixa is None:
            return
        sl, xx, yy = caixa
        dx = xx - px
        # `achata` < 1: a corola vista de lado vira elipse deitada.
        dy = (yy - py) / max(achata, 0.05)
        rr = np.sqrt(dx * dx + dy * dy) / raio
        th = np.arctan2(dy, dx) - giro
        # Contorno: lobos arredondados.
        cont = 1.0 - lobo * 0.35 * (1.0 - np.abs(np.cos(th * petalas * 0.5)) ** 0.6)
        m = rr <= cont
        if not m.any():
            return
        z = z0 - funil * raio * (1.0 - np.clip(rr, 0, 1)) ** 2 + incl * dx + rola * dy
        dzr = 2.0 * funil * (1.0 - np.clip(rr, 0, 1))
        ux = dx / np.maximum(rr * raio, 1e-3)
        uy = dy / np.maximum(rr * raio, 1e-3)
        dz_dx = dzr * ux + incl
        dz_dy = dzr * uy + rola
        inv = 1.0 / np.sqrt(dz_dx * dz_dx + dz_dy * dz_dy + 1.0)
        base = np.asarray(cor, np.float32)
        # Veio das petalas e a garganta mais escura.
        veio = 0.94 + 0.06 * np.cos(th * petalas * 3.0)
        f = veio * (0.9 + 0.1 * suave(0.05, 0.4, rr)) * (1.0 + self.rng.normal(0.0, 0.02, m.shape))
        canais = [base[k] * f for k in range(3)]
        if miolo is not None:
            mc = np.asarray(miolo, np.float32)
            g = 1.0 - suave(0.12, 0.3, rr)
            canais = [canais[k] + (mc[k] - canais[k]) * g for k in range(3)]
        self._gravar(sl, m, z, canais, -dz_dx * inv, -dz_dy * inv, inv, rug, esp)

    # -------------------------------------------------------------- resultado
    def mapas(self):
        """Reduz a superamostragem e devolve (rgba, normal, ru) em float 0..1."""
        global MODO
        MODO = "wrap" if self.envolve else "edge"
        cheio = self.z > FUNDO * 0.5
        cob = cheio.astype(np.float32)
        # Oclusao pela profundidade: quanto a folha esta abaixo do que a cerca.
        zf = np.where(cheio, self.z, np.nan)
        zmin = np.nanpercentile(zf, 2) if cheio.any() else 0.0
        zmax = np.nanpercentile(zf, 98) if cheio.any() else 1.0
        zz = np.where(cheio, self.z, zmin).astype(np.float32)
        k = 4
        pequeno = reduzir(zz, k)
        topo = maximo(pequeno, max(2, int(self.L * 0.025 / k)))
        topo = borrar(topo, max(1, int(self.L * 0.012 / k)))
        topo = np.repeat(np.repeat(topo, k, axis=0), k, axis=1)
        esc = max(zmax - zmin, 1.0)
        fundo = np.clip((topo - zz) / (0.35 * esc), 0.0, 1.0)
        prof = np.clip((zz - zmin) / esc, 0.0, 1.0)
        # Densidade: o miolo do ramo (muita cobertura em volta) recebe menos ceu.
        dens = borrar(reduzir(cob, k), max(1, int(self.L * 0.03 / k)))
        dens = np.repeat(np.repeat(dens, k, axis=0), k, axis=1)
        ao = (1.0 - 0.55 * fundo) * (0.62 + 0.38 * prof) * (1.0 - 0.25 * suave(0.5, 0.95, dens))
        ao = np.clip(ao, 0.18, 1.0)
        cor = self.cor * (0.55 + 0.45 * ao)[..., None]

        s = SS
        a = reduzir(cob, s)
        pa = np.maximum(a, 1e-6)
        rgb = reduzir(cor * cob[..., None], s) / pa[..., None]
        nrm = reduzir(self.n * cob[..., None], s)
        nrm[..., 2] += (1.0 - a) * 1.0
        nrm /= np.maximum(np.linalg.norm(nrm, axis=2, keepdims=True), 1e-6)
        rug = reduzir(self.rug * cob, s) / pa
        aor = reduzir(ao * cob, s) / pa
        esp = reduzir(self.esp * cob, s) / pa
        rug = np.where(a > 0, rug, 0.6)
        aor = np.where(a > 0, aor, 1.0)
        esp = np.where(a > 0, esp, 0.5)
        return (np.dstack([rgb, a]), nrm, np.dstack([rug, aor, esp]))


# -------------------------------------------------------------- estruturas

def _curva(rng, x0, y0, z0, ang, comp, passos, torce, dz):
    pts = [(x0, y0, z0)]
    a = ang
    x, y, z = x0, y0, z0
    seg = comp / passos
    for _ in range(passos):
        a += rng.normal(0.0, torce)
        x += math.cos(a) * seg
        y += math.sin(a) * seg
        z += dz * seg
        pts.append((x, y, z))
    return pts, a


def _ponto(pts, t):
    t = min(max(t, 0.0), 1.0) * (len(pts) - 1)
    i = min(int(t), len(pts) - 2)
    f = t - i
    a, b = pts[i], pts[i + 1]
    return tuple(a[k] + (b[k] - a[k]) * f for k in range(3)), math.atan2(b[1] - a[1], b[0] - a[0])


def _ang_para_cima(rng, dispersao=1.0):
    """Rumo de um galho principal: em volta toda, com preferencia para cima e
    para os lados (a copa e vista de fora; o ramo abre em leque)."""
    a = rng.uniform(0.0, math.tau)
    # Puxa para cima (y negativo na imagem) um pouco.
    return a - 0.35 * math.sin(a + math.pi / 2) * dispersao


class Especie:
    def __init__(self, **k):
        self.__dict__.update(k)


def ramo(t: Tela, e: Especie):
    """Ramo de copa: galhos saindo do centro do cartao para fora, folhas pela
    filotaxia da especie. O centro fica FUNDO (dentro da copa), as pontas no
    alto: e o que da a oclusao do miolo e a borda acesa."""
    rng = t.rng
    L = t.L
    cx, cy = L * 0.5, L * 0.52
    R = L * e.raio
    prof = L * 0.18
    # Enchimento do miolo: folhas fundas, para o cartao nao ser renda.
    for _ in range(int(e.enche)):
        a = rng.uniform(0, math.tau)
        d = R * 0.55 * math.sqrt(rng.uniform(0, 1))
        x, y = cx + math.cos(a) * d, cy + math.sin(a) * d * 0.9
        _folha_da_especie(t, e, x, y, rng.uniform(0, math.tau), -prof * rng.uniform(0.6, 1.0),
                          escala=rng.uniform(0.8, 1.05), fundo=True)
    for _ in range(e.ramos):
        ang = _ang_para_cima(rng)
        comp = min(R * rng.uniform(0.62, 0.95), L * 0.44 - L * e.comp * 0.8)
        pts, fim = _curva(rng, cx + rng.normal(0, R * 0.06), cy + rng.normal(0, R * 0.06),
                          -prof, ang, comp, 8, 0.12, prof / comp * 0.9)
        t.galho(pts, L * e.grossura, L * e.grossura * 0.35, e.casca)
        # Galhos de lado.
        subs = []
        for s in range(e.subs):
            f = rng.uniform(0.3, 0.85)
            (x, y, z), a0 = _ponto(pts, f)
            lado = 1 if s % 2 == 0 else -1
            a1 = a0 + lado * rng.uniform(0.5, 1.0)
            c1 = comp * (1.0 - f) * rng.uniform(0.55, 0.9)
            sp, _ = _curva(rng, x, y, z, a1, c1, 5, 0.15, 0.25 * prof / comp)
            t.galho(sp, L * e.grossura * 0.5, L * e.grossura * 0.22, e.casca)
            subs.append(sp)
        for linha in [pts] + subs:
            _folhas_no_galho(t, e, linha)


def _folhas_no_galho(t: Tela, e: Especie, pts):
    rng = t.rng
    if e.filotaxia == "roseta":
        # Mangueira: as folhas nascem em tufo na ponta do galho, caidas.
        (x, y, z), a = _ponto(pts, 1.0)
        n = rng.integers(e.roseta[0], e.roseta[1] + 1)
        for k in range(n):
            da = (k / n - 0.5) * 2.0 * rng.uniform(1.7, 2.4) + rng.normal(0, 0.15)
            _folha_da_especie(t, e, x, y, a + da, z + rng.uniform(-3, 8), escala=rng.uniform(0.8, 1.15))
        # E algumas mais velhas ao longo.
        for k in range(e.ao_longo):
            f = rng.uniform(0.35, 0.9)
            (x, y, z), a = _ponto(pts, f)
            lado = 1 if k % 2 == 0 else -1
            _folha_da_especie(t, e, x, y, a + lado * rng.uniform(0.6, 1.2), z,
                              escala=rng.uniform(0.75, 1.0))
    else:
        # Alterna: folha dos dois lados, apontando para a ponta.
        passo = e.passo * t.L
        comp = sum(math.dist(pts[i][:2], pts[i + 1][:2]) for i in range(len(pts) - 1))
        n = max(2, int(comp / passo))
        for k in range(n):
            f = (k + rng.uniform(0.2, 0.8)) / n
            (x, y, z), a = _ponto(pts, f)
            lado = 1 if k % 2 == 0 else -1
            _folha_da_especie(t, e, x, y, a + lado * rng.uniform(*e.angulo), z + rng.uniform(0, 4),
                              escala=rng.uniform(0.8, 1.1) * (0.8 + 0.3 * f))
        # Ponta: um par ou trio fechando o galho.
        (x, y, z), a = _ponto(pts, 1.0)
        for d in (-0.35, 0.0, 0.35):
            _folha_da_especie(t, e, x, y, a + d + rng.normal(0, 0.1), z + 3, escala=rng.uniform(0.7, 0.9))
    if getattr(e, "flor", None) is not None:
        (x, y, z), a = _ponto(pts, 1.0)
        e.flor(t, x, y, z + 6, a)


def _folha_da_especie(t: Tela, e: Especie, x, y, ang, z, escala=1.0, fundo=False):
    rng = t.rng
    L = t.L
    cores = e.cores
    c = np.asarray(cores[rng.integers(len(cores))], np.float32)
    c = c * rng.uniform(0.9, 1.1)
    # Folha nova (a brotacao cor de cobre da mangueira) e folha virada (o verso
    # e mais claro e mais cinza).
    verso = rng.random() < e.verso
    if getattr(e, "nova", 0.0) and rng.random() < e.nova:
        c = srgb((96, 58, 36)) * rng.uniform(0.85, 1.1)
    if verso:
        cinza = c.mean()
        c = c + (np.float32([cinza, cinza, cinza]) - c) * 0.35
        c = c * 1.28 + 0.03
    if fundo:
        c = c * 0.72
    seca = 0.0
    if rng.random() < e.seca:
        c = srgb(e.cor_seca) * rng.uniform(0.85, 1.1)
        seca = 1.0
    comp = L * e.comp * escala
    larg = comp * e.razao * 0.5
    t.folha(x, y, ang, comp, larg, z, c, forma=e.forma,
            incl=rng.normal(0.0, e.giro), rola=rng.normal(0.0, e.giro * 0.8),
            dobra=e.dobra * rng.uniform(0.6, 1.3), arco=e.arco,
            curva=rng.normal(0.0, e.curva), rug=(0.85 if verso else e.rug) + 0.15 * seca,
            esp=e.esp * (0.55 if seca else 1.0), nerv=e.nerv, n_nerv=e.n_nerv,
            serra=e.serra, ponta_seca=(0.25 if rng.random() < e.ponta_seca else 0.0))


# --------------------------------------------------------------- flores

def _cacho_ipe(cor_flor, miolo):
    def f(t: Tela, x, y, z, a):
        rng = t.rng
        L = t.L
        n = rng.integers(7, 13)
        for _ in range(n):
            d = L * rng.uniform(0.0, 0.05)
            b = rng.uniform(0, math.tau)
            c = np.asarray(cor_flor[rng.integers(len(cor_flor))], np.float32) * rng.uniform(0.9, 1.08)
            t.flor(x + math.cos(b) * d, y + math.sin(b) * d, L * rng.uniform(0.018, 0.026),
                   z + rng.uniform(0, 10), c, petalas=5, miolo=miolo, giro=rng.uniform(0, math.tau),
                   funil=0.4, incl=rng.normal(0, 0.3), rola=rng.normal(0, 0.3), esp=0.95)
    return f


def _bractea(cores):
    """Primavera: tres bracteas de papel em volta de uma florzinha branca."""
    def f(t: Tela, x, y, z, a):
        rng = t.rng
        L = t.L
        for _ in range(rng.integers(3, 6)):
            d = L * rng.uniform(0.0, 0.045)
            b = rng.uniform(0, math.tau)
            ox, oy = x + math.cos(b) * d, y + math.sin(b) * d
            c = np.asarray(cores[rng.integers(len(cores))], np.float32) * rng.uniform(0.9, 1.08)
            g = rng.uniform(0, math.tau)
            for k in range(3):
                t.folha(ox, oy, g + k * math.tau / 3, L * 0.03, L * 0.013, z + 4, c, forma=(0.45, 0.7),
                        incl=rng.normal(0, 0.3), rola=rng.normal(0, 0.3), dobra=0.1, arco=0.08,
                        rug=0.7, esp=1.0, nerv=0.15, n_nerv=5)
            t.flor(ox, oy, L * 0.004, z + 9, srgb((240, 236, 214)), petalas=5, funil=0.2)
    return f


# ------------------------------------------------------------- as celulas

def c_mangueira(t):
    ramo(t, Especie(raio=0.43, ramos=12, subs=2, enche=160, grossura=0.006,
                    casca=srgb((70, 58, 46)), filotaxia="roseta", roseta=(8, 13), ao_longo=3,
                    cores=[srgb((30, 56, 26)), srgb((38, 66, 30)), srgb((46, 76, 34)), srgb((34, 60, 30))],
                    comp=0.13, razao=0.26, forma=(0.42, 0.95), giro=0.45, dobra=0.3, arco=0.1,
                    curva=0.12, rug=0.32, esp=0.8, nerv=0.4, n_nerv=12, serra=0, verso=0.12,
                    seca=0.01, cor_seca=(104, 90, 52), ponta_seca=0.02, nova=0.012))


def c_miudo(t):
    """Oiti e sibipiruna: folha miuda, densa, alternada em galho fino."""
    ramo(t, Especie(raio=0.44, ramos=15, subs=5, enche=650, grossura=0.004,
                    casca=srgb((82, 70, 56)), filotaxia="alterna", passo=0.013, angulo=(0.5, 0.95),
                    cores=[srgb((40, 70, 32)), srgb((52, 86, 38)), srgb((62, 98, 44)), srgb((46, 78, 34))],
                    comp=0.042, razao=0.46, forma=(0.5, 0.75), giro=0.5, dobra=0.2, arco=0.08,
                    curva=0.05, rug=0.42, esp=0.9, nerv=0.25, n_nerv=6, serra=0, verso=0.14,
                    seca=0.02, cor_seca=(140, 118, 60), ponta_seca=0.0))


def c_claro(t):
    """Abacateiro: folha grande eliptica, verde-clara fosca."""
    ramo(t, Especie(raio=0.43, ramos=11, subs=3, enche=140, grossura=0.0055,
                    casca=srgb((88, 74, 58)), filotaxia="alterna", passo=0.04, angulo=(0.55, 1.0),
                    cores=[srgb((64, 98, 44)), srgb((78, 112, 52)), srgb((92, 128, 60)), srgb((70, 104, 46))],
                    comp=0.1, razao=0.42, forma=(0.55, 0.8), giro=0.45, dobra=0.22, arco=0.1,
                    curva=0.08, rug=0.6, esp=0.9, nerv=0.4, n_nerv=8, serra=0, verso=0.16,
                    seca=0.03, cor_seca=(150, 124, 64), ponta_seca=0.05))


def c_seco(t):
    """Ramo de folha seca de fim de inverno: galho a mostra, folha torta."""
    ramo(t, Especie(raio=0.42, ramos=10, subs=3, enche=70, grossura=0.006,
                    casca=srgb((92, 80, 64)), filotaxia="alterna", passo=0.035, angulo=(0.5, 1.1),
                    cores=[srgb((132, 112, 58)), srgb((150, 126, 66)), srgb((118, 100, 52)), srgb((104, 106, 56))],
                    comp=0.07, razao=0.4, forma=(0.5, 0.8), giro=0.7, dobra=0.45, arco=0.2,
                    curva=0.2, rug=0.8, esp=0.55, nerv=0.3, n_nerv=7, serra=0, verso=0.2,
                    seca=0.25, cor_seca=(120, 86, 50), ponta_seca=0.3))


def c_ipe(cores_flor, miolo):
    def f(t):
        ramo(t, Especie(raio=0.42, ramos=10, subs=3, enche=0, grossura=0.005,
                        casca=srgb((96, 92, 84)), filotaxia="alterna", passo=0.06, angulo=(0.6, 1.0),
                        cores=[srgb((78, 100, 46)), srgb((92, 112, 52))],
                        comp=0.045, razao=0.4, forma=(0.5, 0.8), giro=0.5, dobra=0.2, arco=0.1,
                        curva=0.05, rug=0.6, esp=0.9, nerv=0.3, n_nerv=6, serra=0, verso=0.1,
                        seca=0.0, cor_seca=(0, 0, 0), ponta_seca=0.0,
                        flor=_cacho_ipe(cores_flor, miolo)))
        # O ipe florido e so flor: um segundo passe de cachos pelo corpo do ramo.
        rng = t.rng
        L = t.L
        cx, cy = L * 0.5, L * 0.52
        cacho = _cacho_ipe(cores_flor, miolo)
        for _ in range(55):
            a = rng.uniform(0, math.tau)
            d = L * 0.38 * math.sqrt(rng.uniform(0, 1))
            cacho(t, cx + math.cos(a) * d, cy + math.sin(a) * d * 0.9, -L * 0.1 * rng.uniform(0, 1), a)
    return f


def c_primavera(t):
    ramo(t, Especie(raio=0.43, ramos=12, subs=3, enche=260, grossura=0.004,
                    casca=srgb((90, 76, 60)), filotaxia="alterna", passo=0.03, angulo=(0.5, 0.9),
                    cores=[srgb((46, 78, 36)), srgb((58, 92, 42))],
                    comp=0.05, razao=0.55, forma=(0.45, 0.7), giro=0.5, dobra=0.15, arco=0.08,
                    curva=0.05, rug=0.55, esp=0.9, nerv=0.3, n_nerv=6, serra=0, verso=0.1,
                    seca=0.0, cor_seca=(0, 0, 0), ponta_seca=0.0,
                    flor=_bractea([srgb((170, 26, 96)), srgb((196, 36, 116)), srgb((214, 60, 138))])))


def c_mata(t):
    """Mata de longe: cinco copas encostadas, folha miuda, o pe escuro e fechado."""
    rng = t.rng
    L = t.L
    base = Especie(raio=0.2, ramos=7, subs=2, enche=160, grossura=0.003,
                   casca=srgb((70, 62, 50)), filotaxia="alterna", passo=0.014, angulo=(0.5, 1.0),
                   cores=[srgb((34, 58, 30)), srgb((44, 72, 34)), srgb((56, 86, 40))],
                   comp=0.026, razao=0.45, forma=(0.5, 0.8), giro=0.5, dobra=0.2, arco=0.08,
                   curva=0.05, rug=0.6, esp=0.8, nerv=0.2, n_nerv=5, serra=0, verso=0.1,
                   seca=0.04, cor_seca=(120, 110, 60), ponta_seca=0.0)
    # O pe: folhagem escura larga, sem ceu por baixo.
    for _ in range(1400):
        x = L * rng.uniform(0.1, 0.9)
        y = L * rng.uniform(0.55, 0.9)
        _folha_da_especie(t, base, x, y, rng.uniform(0, math.tau), -L * 0.25, escala=1.2, fundo=True)
    copas = [(0.3, 0.44, 0.18), (0.68, 0.42, 0.18), (0.2, 0.6, 0.16), (0.5, 0.56, 0.2), (0.8, 0.6, 0.15)]
    tons = [1.0, 0.9, 1.1, 0.95, 1.05]
    for (x0, y0, r), k in zip(copas, tons):
        e = Especie(**base.__dict__)
        e.raio = r
        e.cores = [c * k for c in base.cores]
        sub = Tela(int(L), rng)
        ramo(sub, e)
        # Encaixa a copa pequena (desenhada no centro de uma tela cheia) no lugar.
        dx = int((x0 - 0.5) * L)
        dy = int((y0 - 0.52) * L)
        _colar(t, sub, dx, dy)


def _colar(t: Tela, s: Tela, dx, dy):
    L = t.L
    zs = np.roll(np.roll(s.z, dy, axis=0), dx, axis=1)
    if dy > 0:
        zs[:dy] = FUNDO
    elif dy < 0:
        zs[dy:] = FUNDO
    if dx > 0:
        zs[:, :dx] = FUNDO
    elif dx < 0:
        zs[:, dx:] = FUNDO
    w = zs > t.z
    lim = int(L * MARGEM)
    fora = np.ones_like(w)
    fora[lim:L - lim, lim:L - lim] = False
    w &= ~fora
    t.z[w] = zs[w]
    for nome in ("cor", "n"):
        a = np.roll(np.roll(getattr(s, nome), dy, axis=0), dx, axis=1)
        getattr(t, nome)[w] = a[w]
    for nome in ("rug", "esp"):
        a = np.roll(np.roll(getattr(s, nome), dy, axis=0), dx, axis=1)
        getattr(t, nome)[w] = a[w]


def c_palma(t):
    """Folha de palmeira: raque em arco, foliolos longos dos dois lados, pendendo."""
    rng = t.rng
    L = t.L
    pts = []
    for k in range(41):
        s = k / 40
        x = L * (0.08 + 0.84 * s)
        y = L * (0.5 - 0.22 * math.sin(s * math.pi * 0.85) + 0.1 * s)
        pts.append((x, y, -L * 0.02 + L * 0.05 * math.sin(s * math.pi)))
    t.galho(pts, L * 0.009, L * 0.003, srgb((120, 116, 70)), rug=0.6, esp=0.3)
    verdes = [srgb((64, 98, 40)), srgb((76, 110, 46)), srgb((88, 122, 52))]
    for k in range(2, 40):
        (x, y, z), a = _ponto(pts, k / 40)
        comp = L * (0.2 * math.sin(math.pi * min(1.0, (k / 40) * 1.15)) + 0.035)
        for lado in (-1, 1):
            for dup in range(2):
                aa = a + lado * (1.0 + rng.uniform(-0.18, 0.18)) + 0.4 + dup * 0.12 * lado
                c = verdes[rng.integers(3)] * rng.uniform(0.9, 1.1) * (0.9 if lado < 0 else 1.0)
                t.folha(x, y, aa, comp, L * 0.0085, z + dup * 2 + lado, c, forma=(0.3, 1.0),
                        incl=rng.normal(-0.15, 0.2), rola=rng.normal(0, 0.3), dobra=0.6, arco=0.04,
                        curva=0.06 * lado, rug=0.45, esp=0.85, nerv=0.45, n_nerv=0, ponta_seca=0.15 if rng.random() < 0.2 else 0.0)


def c_bananeira(t):
    """Folha de bananeira: larga, nervura central grossa, rasgada em tiras."""
    rng = t.rng
    L = t.L
    cx = L * 0.5
    topo, fundo = L * 0.07, L * 0.93
    # A folha inteira como faixas finas perpendiculares a nervura: cada faixa
    # e uma "folha" de uma lamina, e os rasgos sao faixas que faltam.
    n = 260
    rasgo = False
    for k in range(n):
        s = k / (n - 1)
        y = topo + (fundo - topo) * s
        meia = L * 0.21 * math.sin(math.pi * min(1.0, s * 1.06)) ** 0.6
        if 0.12 < s < 0.92 and rng.random() < (0.35 if rasgo else 0.06):
            rasgo = not rasgo
        if rasgo:
            continue
        for lado in (-1, 1):
            w = meia * rng.uniform(0.975, 1.0)
            c = srgb((82, 124, 50) if lado < 0 else (98, 138, 58)) * rng.uniform(0.95, 1.05)
            # Faixa: da nervura para fora, caindo um pouco para a ponta.
            ang = (math.pi / 2 - 0.18) if lado > 0 else (math.pi / 2 + 0.18)
            ang = -ang + math.pi if lado > 0 else ang + math.pi
            a = math.atan2(0.18, lado * 1.0)
            t.folha(cx, y, a, w, L * 0.0055, L * 0.02 * math.sin(math.pi * s), c, forma=(0.5, 0.05),
                    incl=-0.15, rola=rng.normal(0, 0.05), dobra=0.0, arco=0.02, curva=0.0,
                    rug=0.4, esp=0.9, nerv=0.0, n_nerv=0, borda=0.25,
                    ponta_seca=0.12 if rng.random() < 0.25 else 0.0)
    t.galho([(cx, topo, L * 0.03), (cx, fundo, L * 0.03)], L * 0.008, L * 0.011,
            srgb((176, 184, 116)), rug=0.5, esp=0.4)


def c_bambu(t):
    """Touceira de bambu: colmos com no, folha em lanca em leque no alto."""
    rng = t.rng
    L = t.L
    colmos = []
    for k in range(9):
        x0 = L * (0.36 + rng.uniform(-0.12, 0.12))
        x1 = x0 + L * rng.uniform(-0.25, 0.25)
        pts = [(x0 + (x1 - x0) * s, L * (0.95 - 0.88 * s), -L * 0.05 + k * 2) for s in np.linspace(0, 1, 12)]
        t.galho(pts, L * 0.009, L * 0.006, srgb((128, 136, 70)) * rng.uniform(0.9, 1.1), rug=0.35, esp=0.2)
        for s in (0.12, 0.27, 0.42, 0.57, 0.72, 0.87):
            (x, y, z), a = _ponto(pts, s)
            t.galho([(x - L * 0.011, y, z + L * 0.009), (x + L * 0.011, y, z + L * 0.009)],
                    L * 0.0035, L * 0.0035, srgb((92, 94, 50)), rug=0.5, esp=0.1)
        colmos.append(pts)
    verdes = [srgb((82, 116, 48)), srgb((96, 128, 56)), srgb((72, 104, 44))]
    for _ in range(700):
        pts = colmos[rng.integers(len(colmos))]
        s = rng.uniform(0.3, 1.0)
        (x, y, z), a = _ponto(pts, s)
        lado = 1 if rng.random() < 0.5 else -1
        aa = -math.pi / 2 + lado * rng.uniform(0.5, 1.6)
        t.folha(x, y, aa, L * rng.uniform(0.05, 0.08), L * 0.007, z + rng.uniform(0, 20),
                verdes[rng.integers(3)] * rng.uniform(0.9, 1.1), forma=(0.3, 1.1),
                incl=rng.normal(0, 0.4), rola=rng.normal(0, 0.3), dobra=0.3, arco=0.06,
                curva=0.12 * lado, rug=0.5, esp=0.9, nerv=0.3, n_nerv=0,
                ponta_seca=0.2 if rng.random() < 0.12 else 0.0)


def c_arbusto(t):
    ramo(t, Especie(raio=0.44, ramos=14, subs=4, enche=520, grossura=0.004,
                    casca=srgb((80, 68, 54)), filotaxia="alterna", passo=0.016, angulo=(0.5, 1.0),
                    cores=[srgb((38, 66, 30)), srgb((50, 82, 38)), srgb((62, 96, 44))],
                    comp=0.05, razao=0.5, forma=(0.5, 0.8), giro=0.5, dobra=0.2, arco=0.08,
                    curva=0.06, rug=0.55, esp=0.85, nerv=0.3, n_nerv=6, serra=8, verso=0.1,
                    seca=0.03, cor_seca=(140, 120, 62), ponta_seca=0.02))


def c_touceira(t):
    """Capim-colonião: laminas longas saindo de um tufo, algumas secas, e o
    pendao de semente."""
    rng = t.rng
    L = t.L
    for _ in range(240):
        x0 = L * (0.5 + rng.uniform(-0.09, 0.09))
        ang = -math.pi / 2 + rng.uniform(-1.05, 1.05)
        comp = L * rng.uniform(0.42, 0.86)
        seco = rng.random() < 0.22
        c = srgb((168, 152, 90) if seco else (92, 124, 56)) * rng.uniform(0.85, 1.12)
        lado = 1 if ang > -math.pi / 2 else -1
        t.folha(x0, L * 0.94, ang, comp, L * rng.uniform(0.004, 0.0065), rng.uniform(-40, 40), c,
                forma=(0.15, 0.6), incl=rng.normal(0.2, 0.3), rola=rng.normal(0, 0.3), dobra=0.5,
                arco=0.0, curva=0.1 * lado + rng.normal(0, 0.05), rug=0.6 + 0.2 * seco,
                esp=0.6 if seco else 0.9, nerv=0.35, n_nerv=0, borda=0.05,
                ponta_seca=0.3 if rng.random() < 0.4 else 0.0)
    for _ in range(8):
        x0 = L * (0.5 + rng.uniform(-0.05, 0.05))
        pts, _a = _curva(rng, x0, L * 0.94, 20, -math.pi / 2 + rng.uniform(-0.5, 0.5), L * 0.75, 10, 0.05, 0.0)
        t.galho(pts, L * 0.0022, L * 0.0015, srgb((150, 136, 84)), rug=0.7, esp=0.5)
        for s in np.linspace(0.75, 1.0, 12):
            (x, y, z), a = _ponto(pts, s)
            for lado in (-1, 1):
                t.folha(x, y, a + lado * 0.5, L * 0.03, L * 0.003, z + 3, srgb((176, 150, 110)),
                        forma=(0.4, 0.8), dobra=0.0, arco=0.0, rug=0.8, esp=0.6, nerv=0.0, n_nerv=0)


def c_hera(t):
    """Unha-de-gato cobrindo muro: folha miuda redonda, chapada contra a parede,
    em ramos rasteiros que se cruzam."""
    rng = t.rng
    L = t.L
    e = Especie(filotaxia="alterna", passo=0.016, angulo=(0.7, 1.3),
                cores=[srgb((44, 76, 36)), srgb((58, 94, 42)), srgb((72, 108, 50))],
                comp=0.03, razao=0.8, forma=(0.45, 0.6), giro=0.2, dobra=0.1, arco=0.06,
                curva=0.0, rug=0.5, esp=0.9, nerv=0.25, n_nerv=4, serra=0, verso=0.05,
                seca=0.03, cor_seca=(130, 110, 60), ponta_seca=0.0, casca=srgb((96, 82, 60)))
    for _ in range(75):
        x0 = L * rng.uniform(0.1, 0.9)
        y0 = L * rng.uniform(0.1, 0.9)
        pts, _a = _curva(rng, x0, y0, rng.uniform(-10, 10), rng.uniform(0, math.tau), L * rng.uniform(0.2, 0.45),
                         10, 0.25, 0.0)
        t.galho(pts, L * 0.0025, L * 0.0018, e.casca, esp=0.1)
        _folhas_no_galho(t, e, pts)


def c_flor(t):
    """Canteiro de beira de muro: folhagem baixa com beijinho e cravo."""
    rng = t.rng
    L = t.L
    e = Especie(raio=0.46, ramos=12, subs=3, enche=150, grossura=0.003,
                casca=srgb((70, 90, 44)), filotaxia="alterna", passo=0.022, angulo=(0.5, 1.0),
                cores=[srgb((52, 88, 40)), srgb((66, 104, 46)), srgb((80, 118, 54))],
                comp=0.045, razao=0.5, forma=(0.45, 0.8), giro=0.45, dobra=0.2, arco=0.08,
                curva=0.05, rug=0.55, esp=0.9, nerv=0.3, n_nerv=6, serra=10, verso=0.1,
                seca=0.02, cor_seca=(130, 110, 60), ponta_seca=0.0)
    ramo(t, e)
    cores = [((214, 44, 58), (250, 230, 120)), ((236, 234, 222), (240, 200, 60)),
             ((238, 110, 170), (250, 230, 200)), ((240, 150, 30), (180, 90, 20))]
    for _ in range(160):
        a = rng.uniform(0, math.tau)
        d = L * 0.4 * math.sqrt(rng.uniform(0, 1))
        x, y = L * 0.5 + math.cos(a) * d, L * 0.52 + math.sin(a) * d * 0.8
        if y > L * 0.78:
            continue
        c, m = cores[rng.integers(len(cores))]
        t.flor(x, y, L * rng.uniform(0.014, 0.022), L * 0.05 + rng.uniform(0, 20), srgb(c) * rng.uniform(0.92, 1.05),
               petalas=5, miolo=srgb(m), giro=rng.uniform(0, math.tau), funil=0.15, lobo=0.8,
               incl=rng.normal(0, 0.25), rola=rng.normal(0, 0.25))


def c_sombra(t):
    """O miolo da copa: folha escura e fechada, pouco contraste."""
    ramo(t, Especie(raio=0.46, ramos=14, subs=4, enche=1100, grossura=0.005,
                    casca=srgb((50, 42, 34)), filotaxia="alterna", passo=0.022, angulo=(0.5, 1.0),
                    cores=[srgb((22, 38, 20)), srgb((28, 48, 24)), srgb((34, 56, 28))],
                    comp=0.06, razao=0.4, forma=(0.45, 0.85), giro=0.5, dobra=0.25, arco=0.1,
                    curva=0.08, rug=0.55, esp=0.5, nerv=0.2, n_nerv=6, serra=0, verso=0.05,
                    seca=0.02, cor_seca=(90, 76, 44), ponta_seca=0.0))


CELULAS = [
    c_mangueira, c_miudo, c_claro, c_seco,
    c_ipe([srgb((236, 186, 22)), srgb((246, 204, 40)), srgb((226, 170, 18))], srgb((150, 96, 20))),
    c_ipe([srgb((222, 110, 168)), srgb((236, 138, 188)), srgb((206, 94, 152))], srgb((250, 220, 120))),
    c_primavera, c_mata,
    c_palma, c_bananeira, c_bambu, c_arbusto,
    c_touceira, c_hera, c_flor, c_sombra,
]


# ------------------------------------------------------------------- montar

def sangrar(arr: np.ndarray, a: np.ndarray) -> np.ndarray:
    """Espalha o conteudo das celulas cobertas por baixo do alfa zero (piramide
    de media ponderada). Serve para a cor, a normal e a rugosidade: o mipmap da
    borda do recorte nao puxa preto, cinza nem a celula vizinha."""
    c = arr.shape[2]
    niveis = [(arr * a[..., None], a)]
    while niveis[-1][1].shape[0] > 4:
        v, p = niveis[-1]
        h = v.shape[0] // 2
        v = v.reshape(h, 2, h, 2, c).mean(axis=(1, 3))
        p = p.reshape(h, 2, h, 2).mean(axis=(1, 3))
        niveis.append((v, p))
    cheio = niveis[-1][0] / np.maximum(niveis[-1][1], 1e-6)[..., None]
    for v, p in reversed(niveis[:-1]):
        cheio = cheio.repeat(2, axis=0).repeat(2, axis=1)
        aqui = v / np.maximum(p, 1e-6)[..., None]
        cheio = np.where((p > 0.02)[..., None], aqui, cheio)
    falta = a < 0.03
    return np.where(falta[..., None], cheio, arr)


def main() -> int:
    global SAIDA_HD
    previa = None
    for arg in sys.argv[1:]:
        if arg.startswith("--previa="):
            previa = Path(arg.split("=", 1)[1])
        elif arg.startswith("--saida="):
            SAIDA_HD = Path(arg.split("=", 1)[1])
    lado = CEL * N
    cor = np.zeros((lado, lado, 4), np.float32)
    nrm = np.zeros((lado, lado, 3), np.float32)
    ru = np.zeros((lado, lado, 3), np.float32)
    for k, fazer in enumerate(CELULAS):
        rng = np.random.default_rng(7700 + k)
        t = Tela(CEL * SS, rng)
        fazer(t)
        c, n, r = t.mapas()
        y, x = (k // N) * CEL, (k % N) * CEL
        cor[y:y + CEL, x:x + CEL] = c
        nrm[y:y + CEL, x:x + CEL] = n
        ru[y:y + CEL, x:x + CEL] = r
        print("celula %2d %-14s cobertura %.2f" % (k, fazer.__name__ if hasattr(fazer, "__name__") else "ipe",
                                                   float(c[..., 3].mean())))
    a = cor[..., 3]
    cor[..., :3] = sangrar(cor[..., :3], a)
    nrm = sangrar(nrm, a)
    nrm /= np.maximum(np.linalg.norm(nrm, axis=2, keepdims=True), 1e-6)
    ru = sangrar(ru, a)

    SAIDA_HD.mkdir(parents=True, exist_ok=True)
    def u8(x):
        return np.clip(x * 255.0 + 0.5, 0, 255).astype(np.uint8)
    Image.fromarray(u8(cor), "RGBA").save(SAIDA_HD / "vegetacao_atlas.png", optimize=True)
    Image.fromarray(u8(nrm * 0.5 + 0.5), "RGB").save(SAIDA_HD / "vegetacao_atlas_n.png", optimize=True)
    Image.fromarray(u8(ru), "RGB").save(SAIDA_HD / "vegetacao_atlas_ru.png", optimize=True)
    print("vegetacao_atlas HD", lado, "(cor, _n, _ru)")

    if previa is not None:
        previa.mkdir(parents=True, exist_ok=True)
        fundo = np.ones((lado, lado, 3), np.float32) * np.float32([0.62, 0.7, 0.8])
        comp = cor[..., :3] * a[..., None] + fundo * (1.0 - a[..., None])
        Image.fromarray(u8(comp), "RGB").resize((2048, 2048), Image.LANCZOS).save(previa / "atlas_hd_cor.png")
        # Iluminado: luz de cima-esquerda pela normal, vezes a oclusao.
        luz = np.float32([-0.45, -0.55, 0.7])
        luz /= np.linalg.norm(luz)
        d = np.clip((nrm * luz).sum(axis=2), 0, 1) * 0.8 + 0.25 * ru[..., 1]
        lit = cor[..., :3] * d[..., None] * 1.3
        comp = lit * a[..., None] + fundo * (1.0 - a[..., None])
        Image.fromarray(u8(comp), "RGB").resize((2048, 2048), Image.LANCZOS).save(previa / "atlas_hd_luz.png")
        Image.fromarray(u8(nrm * 0.5 + 0.5), "RGB").resize((1024, 1024), Image.LANCZOS).save(previa / "atlas_hd_n.png")
        Image.fromarray(u8(ru), "RGB").resize((1024, 1024), Image.LANCZOS).save(previa / "atlas_hd_ru.png")
        print("previa em", previa)
    return 0


if __name__ == "__main__":
    sys.exit(main())
