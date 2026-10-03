"""Mede o que a `SondaDoCapuz` (--capuz-sonda=DIR) despejou: a malha desenhada
da batina AAA (capuz, murca, batina), o corpo AAA na pele e a cabeca, quadro a
quadro, e responde:

- onde a cabeca esta em relacao ao capuz, ao pescoco do corpo e a murca;
- a maior penetracao do pano no corpo e na cabeca, e do corpo e da cabeca no
  pano (mm e onde);
- (com --tela) onde o queixo, o pescoco e os ombros caem na imagem, para a
  medida de luminancia dos quadros cheios.

    python tools/sonda_capuz.py DIR/<padre> [--de=T] [--ate=T] [--cada=N]
        [--quadro=T --ver=saida.png --foto=quadro_cheio.png] [--json=saida.json]

A malha e refeita como o shader faz (`BatinaAAA.SHADER`: Catmull-Rom das
particulas, referencial local, desvio escalado e recolhido no amassado), o corpo
pela pele (soma das ligacoes por peso) e a cabeca pela transformacao dela com a
queixada girada (`CabecaDoPadre.QUEIXADA`).

Penetracao (mm), pelo vizinho mais perto na outra malha e a normal dele:
- pano no corpo / na cabeca: vertice do pano do lado de dentro da pele;
- corpo / cabeca no pano: vertice da pele do lado de fora do pano que o cobre
  (o pano e casca fechada: a face de dentro olha para o corpo; um vertice da
  pele atras da face de dentro, no sentido da normal dela, furou).
"""
import glob
import json
import os
import sys

import numpy as np
from scipy.spatial import cKDTree


def arg(nome, padrao=None):
    for a in sys.argv[1:]:
        if a.startswith("--" + nome + "="):
            return a.split("=", 1)[1]
        if a == "--" + nome:
            return True
    return padrao


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def pesos(t):
    t2 = t * t
    t3 = t2 * t
    return np.stack([-0.5 * t3 + t2 - 0.5 * t, 1.5 * t3 - 2.5 * t2 + 1.0,
                     -1.5 * t3 + 2.0 * t2 + 0.5 * t, 0.5 * t3 - 0.5 * t2], -1)


def dpesos(t):
    t2 = t * t
    return np.stack([-1.5 * t2 + 2.0 * t - 0.5, 4.5 * t2 - 5.0 * t,
                     -4.5 * t2 + 4.0 * t + 0.5, 1.5 * t2 - t], -1)


def mat(tr):
    """[x, y, z, origem] (colunas) -> 4x4."""
    m = np.eye(4)
    m[:3, 0] = tr[0]
    m[:3, 1] = tr[1]
    m[:3, 2] = tr[2]
    m[:3, 3] = tr[3]
    return m


def normalizar(v):
    return v / np.maximum(np.linalg.norm(v, axis=-1, keepdims=True), 1e-12)


class Estatico:
    def __init__(self, d):
        self.d = d
        self.e = json.load(open(os.path.join(d, "estatico.json")))
        self.s = float(self.e["s"])
        f32 = lambda n: np.fromfile(os.path.join(d, n + ".f32"), np.float32)
        i32 = lambda n: np.fromfile(os.path.join(d, n + ".i32"), np.int32)
        self.sup = []
        for sp in self.e["batina"]:
            b = sp["base"]
            n = sp["n"]
            self.sup.append({
                "pos": f32(b + "_pos").reshape(n, 3).astype(np.float64),
                "nor": f32(b + "_nor").reshape(n, 3).astype(np.float64),
                "uv2": f32(b + "_uv2").reshape(n, 2).astype(np.float64),
                "c0": f32(b + "_c0").reshape(n, 4).astype(np.float64),
                "c1": f32(b + "_c1").reshape(n, 4).astype(np.float64),
                "c2": f32(b + "_c2").reshape(n, 4).astype(np.float64),
                "ind": i32(b + "_ind").reshape(-1, 3),
            })
        self.grades = self.e["grades_batina"]
        self.corpo = None
        if "corpo" in self.e:
            c = self.e["corpo"][0]
            b = c["base"]
            n = c["n"]
            por = c["por"]
            self.corpo = {
                "pos": f32(b + "_pos").reshape(n, 3).astype(np.float64),
                "nor": f32(b + "_nor").reshape(n, 3).astype(np.float64),
                "ossos": i32(b + "_ossos").reshape(n, por),
                "pesos": f32(b + "_pesos").reshape(n, por).astype(np.float64),
                "cor": f32(b + "_cor").reshape(n, 4),
                "ind": i32(b + "_ind").reshape(-1, 3),
            }
            self.bind_osso = self.e["corpo_bind_osso"]
        self.cabeca = None
        if "cabeca" in self.e:
            n = self.e["cabeca"]["n"]
            self.cabeca = {
                "pos": f32("cabeca_pos").reshape(n, 3).astype(np.float64),
                "nor": f32("cabeca_nor").reshape(n, 3).astype(np.float64),
                "uv": f32("cabeca_uv").reshape(n, 2).astype(np.float64),
            }


class CampoDaCabeca:
    """O `CABECA_SDF` que o shader da batina le (sdf.f32 e sdf.json de
    `tools/gerar_sdf_cabeca.py`), com o mesmo empurrao."""
    FAIXA = 0.022
    FOLGA = 0.006

    def __init__(self, d):
        from scipy.ndimage import map_coordinates
        self.mc = map_coordinates
        j = json.load(open(os.path.join(d, "sdf.json")))
        self.n = np.array(j["n"])
        self.lo = np.array(j["minimo"])
        self.tam = np.array(j["tamanho"])
        self.v = np.fromfile(os.path.join(d, "sdf.f32"), np.float32).reshape(self.n[2], self.n[1], self.n[0])
        # A textura e meio float.
        self.v = self.v.astype(np.float16).astype(np.float64)

    def amostra(self, q):
        c = (q - self.lo) / self.tam * self.n - 0.5
        return self.mc(self.v, [c[:, 2], c[:, 1], c[:, 0]], order=1, mode="nearest")

    def dist(self, q, queixada, pivo):
        d = self.amostra(q)
        if queixada > 0.0:
            m = q[:, 1] < pivo[1] + 0.03
            r = q[m] - pivo
            c, s = np.cos(queixada), np.sin(queixada)
            qj = pivo + np.stack([r[:, 0], c * r[:, 1] - s * r[:, 2], s * r[:, 1] + c * r[:, 2]], -1)
            d[m] = np.minimum(d[m], self.amostra(qj))
        return d

    def empurrar(self, p, nr, cab, escala, queixada, pivo, forca=1.0):
        inv = np.linalg.inv(cab)
        q = p @ inv[:3, :3].T + inv[:3, 3]
        uvw = (q - self.lo) / self.tam
        dentro = np.all((uvw > 0.01) & (uvw < 0.99), axis=1)
        idx = np.where(dentro)[0]
        if not len(idx):
            return p, nr
        qq = q[idx]
        d = self.dist(qq, queixada, pivo) * escala
        faixa = d < self.FAIXA
        idx, qq, d = idx[faixa], qq[faixa], d[faixa]
        e = 0.004
        g = np.zeros_like(qq)
        for k in range(3):
            de = np.zeros(3)
            de[k] = e
            g[:, k] = self.dist(qq + de, queixada, pivo) - self.dist(qq - de, queixada, pivo)
        gw = normalizar(g @ inv[:3, :3] + np.array([0.0, 1e-9, 0.0]))
        u = self.FAIXA - d
        rm = self.FAIXA - self.FOLGA
        fica = rm * (1.0 - np.exp(-u / rm))
        p = p.copy()
        p[idx] += gw * (u - fica)[:, None] * forca
        deita = (1.0 - np.exp(-u / rm)) * forca
        nn = nr.copy()
        sg = np.sign(np.sum(nr[idx] * gw, -1) + 1e-4)
        nn[idx] = normalizar(nr[idx] * (1 - deita * 0.8)[:, None] + gw * sg[:, None] * (deita * 0.8)[:, None])
        # O segundo empurrao, so ate a folga.
        q2 = p[idx] @ inv[:3, :3].T + inv[:3, 3]
        d2 = self.dist(q2, queixada, pivo) * escala
        m2 = d2 < self.FOLGA
        if m2.any():
            i2, qq2 = idx[m2], q2[m2]
            g2 = np.zeros_like(qq2)
            for k in range(3):
                de = np.zeros(3)
                de[k] = e
                g2[:, k] = self.dist(qq2 + de, queixada, pivo) - self.dist(qq2 - de, queixada, pivo)
            gw2 = normalizar(g2 @ inv[:3, :3] + np.array([0.0, 1e-9, 0.0]))
            p[i2] += gw2 * (self.FOLGA - d2[m2])[:, None] * forca
        return p, nn


CAMPO = None
# A boca do capuz aberta dos outros padres (`BatinaAAA.CABECA_JANELA`): o pano
# na frente da cara, colado nela, nao e desenhado. `--janela` liga no modelo.
JANELA = (0.066, 0.090)
JANELA_Y = -0.02
JANELA_PERTO = 0.035
USAR_JANELA = False


USAR_DESCARTE = False


def na_janela(ql, escala):
    """Os pontos `ql` (espaco da cabeca) que o fragmento dos outros padres
    descarta (`BatinaAAA.CABECA_JANELA`): na boca do capuz (a elipse com a
    borda ondulada, perto da pele) e, com `USAR_DESCARTE`, dentro da pele."""
    if CAMPO is None or not len(ql):
        return np.zeros(len(ql), bool)
    uvw = (ql - CAMPO.lo) / CAMPO.tam
    caixa = np.all((uvw > 0) & (uvw < 1), axis=1)
    m = np.zeros(len(ql), bool)
    if not caixa.any():
        return m
    idx = np.where(caixa)[0]
    q = ql[idx]
    d = CAMPO.amostra(q) * escala
    r = np.stack([q[:, 0] / JANELA[0], (q[:, 1] - JANELA_Y) / JANELA[1]], -1)
    e = np.linalg.norm(r, axis=1)
    a = np.arctan2(r[:, 1], r[:, 0])
    borda = 1.0 + 0.045 * np.sin(a * 5.0 + 1.3) + 0.025 * np.sin(a * 11.0 + 0.4)
    fora = (q[:, 2] < -0.02) & (e < borda) & (d < JANELA_PERTO)
    if USAR_DESCARTE:
        fora |= d < 0.0
    m[idx] = fora
    return m


class Quadro:
    def __init__(self, est, caminho):
        self.est = est
        self.q = json.load(open(caminho))
        self.t = float(self.q["t"])
        tudo = np.fromfile(caminho[:-5] + ".f32", np.float32).astype(np.float64)
        self.parts = []
        for nome, w, h, o in self.q["grades"]:
            self.parts.append((tudo[o:o + w * h * 3].reshape(w * h, 3), int(w), int(h)))

    # --- pano ---
    def _superficie(self, gid, g):
        P, w, h = self.parts[gid]
        gx = np.mod(g[:, 0], w)
        gy = np.clip(g[:, 1], 0.0, h - 1)
        bx = np.floor(gx).astype(np.int64)
        by = np.floor(gy).astype(np.int64)
        fx = gx - bx
        fy = gy - by
        wx, wy, dx, dy = pesos(fx), pesos(fy), dpesos(fx), dpesos(fy)
        p = np.zeros((len(g), 3))
        du = np.zeros((len(g), 3))
        dv = np.zeros((len(g), 3))
        for j in range(4):
            lin = np.clip(by + j - 1, 0, h - 1)
            l = np.zeros((len(g), 3))
            ld = np.zeros((len(g), 3))
            for i in range(4):
                col = np.mod(bx + i - 1, w)
                q = P[lin * w + col]
                l += q * wx[:, i:i + 1]
                ld += q * dx[:, i:i + 1]
            p += l * wy[:, j:j + 1]
            du += ld * wy[:, j:j + 1]
            dv += l * dy[:, j:j + 1]
        return p, du, dv

    def _ponto(self, ids, g, o, area0):
        n = len(g)
        p = np.zeros((n, 3))
        T = np.zeros((n, 3))
        B = np.zeros((n, 3))
        N = np.zeros((n, 3))
        rec = np.ones(n)
        s = self.est.s
        for gid in np.unique(ids):
            m = ids == gid
            if gid >= len(self.parts):
                continue
            pp, du, dv = self._superficie(gid, g[m])
            cr = np.cross(du, dv)
            nn = normalizar(cr + np.array([0.0, 1e-12, 0.0]))
            tt = normalizar(du - nn * np.sum(nn * du, -1, keepdims=True) + np.array([1e-12, 0.0, 0.0]))
            bb = np.cross(nn, tt)
            r = np.ones(m.sum())
            a0 = area0[m]
            com = a0 > 0.0
            r[com] = smoothstep(0.12, 0.40, np.linalg.norm(cr[com], axis=-1) / (a0[com] * s * s))
            oo = o[m]
            p[m] = pp + (tt * oo[:, 0:1] + bb * oo[:, 1:2] + nn * oo[:, 2:3]) * s * r[:, None]
            T[m], B[m], N[m], rec[m] = tt, bb, nn, r
        return p, T, B, N, rec

    def pano(self, si):
        """Vertices e normais desenhados da superficie `si` (mundo)."""
        sp = self.est.sup[si]
        c0, c1, c2 = sp["c0"], sp["c1"], sp["c2"]
        ids = np.rint(c0[:, 3]).astype(np.int64)
        p, T, B, N, rec = self._ponto(ids, sp["uv2"], c0[:, :3], c2[:, 3])
        mix2 = c1[:, 2]
        com = mix2 > 0.0
        if com.any():
            ids2 = np.rint(c1[com, 3]).astype(np.int64)
            p2, _, _, _, _ = self._ponto(ids2, c1[com, :2], c2[com, :3], np.zeros(com.sum()))
            p[com] = p[com] * (1.0 - mix2[com, None]) + p2 * mix2[com, None]
        n = sp["nor"]
        nr = T * n[:, 0:1] + B * n[:, 1:2] + N * n[:, 2:3]
        nr = normalizar(N * (1.0 - rec[:, None]) + nr * rec[:, None])
        forca = float(self.q.get("sdf_cabeca_forca", 1.0))
        if CAMPO is not None and float(self.q.get("sdf_cabeca_escala", 0.0)) > 0.0 and forca > 0.0                 and ("sdf_cabeca" in self.q or "cabeca" in self.q):
            # A cabeca que o shader usou (a pose do osso), a menor escala dela e
            # a forca (esmaece com a distancia da lente).
            cab = mat(self.q["sdf_cabeca"] if "sdf_cabeca" in self.q else self.q["cabeca"])
            q = float(self.q.get("sdf_queixada", float(self.q.get("abre", 0.0)) * float(self.q.get("giro_max", 0.22))))
            p, nr = CAMPO.empurrar(p, nr, cab, float(self.q["sdf_cabeca_escala"]), q,
                                   np.array(self.q.get("pivo", [0.0, -0.018, 0.03])), forca)
        # A grade de cada vertice (a da maioria, sem a mistura).
        return p, nr, ids

    # --- corpo ---
    def corpo(self):
        c = self.est.corpo
        if c is None or "binds" not in self.q:
            return None
        esq = mat(self.q["esqueleto"])
        ossos = [mat(o) for o in self.q["ossos"]]
        binds = [mat(b) for b in self.q["binds"]]
        M = np.stack([ossos[self.est.bind_osso[i]] @ binds[i] for i in range(len(binds))])
        esc = np.array([np.linalg.norm(m[:3, 0]) for m in M])
        W = c["pesos"]
        O = c["ossos"]
        Mv = np.einsum("nk,nkij->nij", W, M[O])
        v = np.einsum("nij,nj->ni", Mv[:, :3, :3], c["pos"]) + Mv[:, :3, 3]
        nv = np.einsum("nij,nj->ni", Mv[:, :3, :3], c["nor"])
        v = v @ esq[:3, :3].T + esq[:3, 3]
        nv = normalizar(nv @ esq[:3, :3].T)
        # Some quem esta esmagado (o braco trocado: ligacao a 1e-4).
        vivo = np.einsum("nk,nk->n", W, (esc[O] > 0.01).astype(np.float64)) > 0.5
        dono = O[np.arange(len(O)), np.argmax(W, axis=1)]
        return v, nv, vivo, dono, c["cor"][:, 1] > 0.5

    # --- cabeca ---
    def cabeca(self):
        h = self.est.cabeca
        if h is None or "cabeca" not in self.q:
            return None
        m = mat(self.q["cabeca"])
        a = -float(self.q.get("abre", 0.0)) * float(self.q.get("giro_max", 0.22)) * h["uv"][:, 0]
        pv = np.array(self.q.get("pivo", [0.0, -0.018, 0.03]))
        v = h["pos"] - pv
        ca, sa = np.cos(a), np.sin(a)
        vr = np.stack([v[:, 0], ca * v[:, 1] - sa * v[:, 2], sa * v[:, 1] + ca * v[:, 2]], -1) + pv
        n = h["nor"]
        nr = np.stack([n[:, 0], ca * n[:, 1] - sa * n[:, 2], sa * n[:, 1] + ca * n[:, 2]], -1)
        w = vr @ m[:3, :3].T + m[:3, 3]
        nw = normalizar(nr @ m[:3, :3].T)
        return w, nw

    def projetar(self, p, tam=(1920, 1080)):
        cam = mat(self.q["lente"])
        inv = np.linalg.inv(cam)
        pc = p @ inv[:3, :3].T + inv[:3, 3]
        f = 1.0 / np.tan(np.radians(float(self.q["fov"])) * 0.5)
        asp = tam[0] / tam[1]
        z = -pc[:, 2]
        x = pc[:, 0] / z * f / asp
        y = pc[:, 1] / z * f
        return np.stack([(x + 1) * 0.5 * tam[0], (1 - y) * 0.5 * tam[1]], -1), z


NOMES_OSSO = ["quadril", "torso", "cabeca", "braco_e", "antebraco_e", "braco_d", "antebraco_d",
              "coxa_e", "canela_e", "coxa_d", "canela_d", "saia_f", "saia_t", "barriga"]


def dentro(pts, pele, npele, arvore, raio=0.05, k=4):
    """Quanto cada ponto de `pts` esta do lado de dentro da pele (m, > 0 dentro),
    pelo vizinho mais perto e pela maioria de `k` (sinal da normal)."""
    d, i = arvore.query(pts, k=k, distance_upper_bound=raio)
    ok = np.isfinite(d[:, 0])
    pen = np.full(len(pts), -np.inf)
    if not ok.any():
        return pen, np.full(len(pts), -1)
    ii = i[ok]
    val = np.isfinite(d[ok])
    ii_c = np.where(val, ii, 0)
    rel = pts[ok][:, None, :] - pele[ii_c]
    sd = np.sum(rel * npele[ii_c], -1)
    sd = np.where(val, sd, np.nan)
    neg = np.nansum(sd < 0, 1)
    tot = np.sum(val, 1)
    maioria = neg * 2 > tot
    p = np.where(maioria, -sd[:, 0], -np.inf)
    pen[np.where(ok)[0]] = np.where(np.isnan(p), -np.inf, p)
    viz = np.full(len(pts), -1)
    viz[np.where(ok)[0]] = ii[:, 0]
    return pen, viz


def furou(pele, npele, pano, npano, arvore_pano, raio=0.04, lateral=0.012):
    """Quanto cada vertice da pele passou da face de DENTRO do pano que o cobre
    (m, > 0 furou). A face de dentro e a do pano cuja normal olha contra a da
    pele; o vertice so conta se estiver debaixo dela (a menos de `lateral` do
    raio pela normal)."""
    d, i = arvore_pano.query(pele, k=8, distance_upper_bound=raio)
    pen = np.full(len(pele), -np.inf)
    val = np.isfinite(d)
    ii = np.where(val, i, 0)
    q = pano[ii]
    nq = npano[ii]
    face_dentro = np.sum(nq * npele[:, None, :], -1) < -0.2
    rel = pele[:, None, :] - q
    h = np.sum(rel * nq, -1)
    lat = np.linalg.norm(rel - nq * h[..., None], axis=-1)
    usa = val & face_dentro & (lat < lateral)
    # h > 0: a pele esta do lado da normal da face de dentro (para o corpo): ok.
    # h < 0: passou da face de dentro.
    fundo = np.where(usa, -h, -np.inf)
    # O mais perto que cobre decide (o primeiro valido na ordem de distancia).
    primeiro = np.argmax(usa, axis=1)
    tem = usa.any(1)
    pen[tem] = fundo[np.arange(len(pele))[tem], primeiro[tem]]
    return pen


def regiao_da_cabeca(p):
    """O nome do lugar de um ponto no espaco da cabeca (metros da pessoa de
    1,72 m, rosto para -z)."""
    x, y, z = p
    if y < -0.105:
        return "pescoco" if z > -0.035 else "queixo"
    if abs(x) > 0.066 and -0.05 < y < 0.045:
        return "orelha"
    if z < -0.03 and y < 0.07:
        return "rosto" if y > -0.06 else "boca/mandibula"
    if y > 0.03 or z >= -0.03:
        return "cranio"
    return "testa"


def _no_espaco_da_cabeca(qd, p):
    m = mat(qd.q["cabeca"])
    return (p - m[:3, 3]) @ np.linalg.inv(m[:3, :3]).T


def _amostrar_tris(P, tris, n=12):
    """Pontos espalhados em cada triangulo (baricentricas numa grade n)."""
    ab = []
    for i in range(n + 1):
        for j in range(n + 1 - i):
            ab.append((i / n, j / n))
    ab = np.array(ab)
    a, b = ab[:, 0], ab[:, 1]
    A, B, C = P[tris[:, 0]], P[tris[:, 1]], P[tris[:, 2]]
    return (A[:, None, :] * (1 - a - b)[None, :, None] + B[:, None, :] * a[None, :, None]
            + C[:, None, :] * b[None, :, None]).reshape(-1, 3)


def atravessa_cabeca(hl, cl, s, passo_graus=0.5):
    """O pano do lado de dentro da pele da cabeca, pelo raio que sai do centro
    dela: para cada vertice da pele que e o primeiro que o raio encontra, se ha
    pano no mesmo raio mais perto do centro, o pano esta dentro da cabeca (ou
    ela passou por ele) e o fundo e a diferenca. `hl` a pele e `cl` os pontos do
    pano, os dois no espaco da cabeca (pessoa de 1,72 m); devolve o fundo em
    metros de verdade (x `s`) por vertice da pele (0 fora)."""
    fundo = np.zeros(len(hl))
    NT = int(round(180 / passo_graus))
    NP = 2 * NT
    for centro, sel in [(np.array([0.0, 0.0, 0.0]), hl[:, 1] > -0.10),
                        (np.array([0.0, -0.16, 0.018]), hl[:, 1] <= -0.10)]:
        def bins(q):
            d = q - centro
            r = np.linalg.norm(d, axis=1)
            th = np.arccos(np.clip(d[:, 1] / np.maximum(r, 1e-9), -1, 1))
            ph = np.arctan2(d[:, 0], d[:, 2])
            it = np.clip((th / np.pi * NT).astype(int), 0, NT - 1)
            ip = np.clip(((ph + np.pi) / (2 * np.pi) * NP).astype(int), 0, NP - 1)
            return it * NP + ip, r
        bh, rh = bins(hl)
        hmin = np.full(NT * NP, np.inf)
        np.minimum.at(hmin, bh, rh)
        bc, rc = bins(cl)
        cmin = np.full(NT * NP, np.inf)
        np.minimum.at(cmin, bc, rc)
        primeiro = rh <= hmin[bh] + 0.002
        f = rh - cmin[bh]
        ok = sel & primeiro & (f > 0.001)
        fundo[ok] = np.maximum(fundo[ok], f[ok] * s)
    return fundo


def medir(est, qd, quer_corpo=True, quer_cabeca=True):
    out = {"t": qd.t}
    some = qd.q.get("batina_some", [False] * len(est.sup))
    tipos = [g["tipo"] for g in est.grades]
    pano_p, pano_n, pano_g, pano_t = [], [], [], []
    base = 0
    for si in range(len(est.sup)):
        if si < len(some) and some[si]:
            continue
        p, n, g = qd.pano(si)
        pano_p.append(p)
        pano_n.append(n)
        pano_g.append(g)
        pano_t.append(est.sup[si]["ind"] + base)
        base += len(p)
    TRI = np.concatenate(pano_t)
    P = np.concatenate(pano_p)
    NP = np.concatenate(pano_n)
    G = np.concatenate(pano_g)
    arv_pano = cKDTree(P)
    tipo = lambda g: tipos[g] if g < len(tipos) else str(g)
    corpo = qd.corpo() if quer_corpo and qd.q.get("corpo_visivel", True) else None
    cab = qd.cabeca() if quer_cabeca and qd.q.get("cabeca_visivel", True) else None
    if corpo is not None:
        v, nv, vivo, dono, tunica = corpo
        vv, nvv, dv = v[vivo], nv[vivo], dono[vivo]
        arv = cKDTree(vv)
        pen, viz = dentro(P, vv, nvv, arv)
        parte_viz = np.where(viz >= 0, dv[np.maximum(viz, 0)], -1)
        pc = furou(vv, nvv, P, NP, arv_pano)
        # O que se ve na janela: pescoco, tronco e braco de cima (as pernas
        # ficam atras da porta).
        for nome, ossos in [("tronco", (1, 13, 2)), ("braco", (3, 5)), ("pernas", (0, 7, 9, 8, 10))]:
            m = np.isin(parte_viz, ossos)
            pm = np.where(m, pen, -np.inf)
            k = int(np.argmax(pm))
            out["pano_no_%s_mm" % nome] = float(pm[k] * 1000) if np.isfinite(pm[k]) and pm[k] > 0 else 0.0
            out["pano_no_%s_onde" % nome] = tipo(G[k]) if np.isfinite(pm[k]) and pm[k] > 0 else "-"
            m2 = np.isin(dv, ossos)
            pm2 = np.where(m2, pc, -np.inf)
            k2 = int(np.argmax(pm2))
            out["%s_no_pano_mm" % nome] = float(pm2[k2] * 1000) if np.isfinite(pm2[k2]) and pm2[k2] > 0 else 0.0
    if cab is not None:
        hv, hn = cab
        # So o pano perto da cabeca (a caixa dela e 6 cm).
        lo, hi = hv.min(0) - 0.06, hv.max(0) + 0.06
        perto = np.all((P > lo) & (P < hi), axis=1)
        idx = np.where(perto)[0]
        arv_h = cKDTree(hv)
        pen = np.full(len(P), -np.inf)
        if len(idx):
            pp, _ = dentro(P[idx], hv, hn, arv_h, raio=0.20, k=5)
            pen[idx] = pp
        k = int(np.argmax(pen))
        ok = np.isfinite(pen[k]) and pen[k] > 0
        out["pano_na_cabeca_mm"] = float(pen[k] * 1000) if ok else 0.0
        if ok:
            lp = _no_espaco_da_cabeca(qd, P[k:k + 1])[0]
            out["pano_na_cabeca_onde"] = "%s na %s (%.0f,%.0f,%.0f mm)" % (tipo(G[k]), regiao_da_cabeca(lp),
                                                                        lp[0] * 1000, lp[1] * 1000, lp[2] * 1000)
        else:
            out["pano_na_cabeca_onde"] = "-"
        out["pano_na_cabeca_n2mm"] = int(np.sum(pen > 0.002))
        pc = furou(hv[::2], hn[::2], P, NP, arv_pano)
        k = int(np.argmax(pc))
        ok = np.isfinite(pc[k]) and pc[k] > 0
        out["cabeca_no_pano_mm"] = float(pc[k] * 1000) if ok else 0.0
        if ok:
            lp = _no_espaco_da_cabeca(qd, hv[::2][k:k + 1])[0]
            out["cabeca_no_pano_onde"] = "%s (%.0f,%.0f,%.0f mm)" % (regiao_da_cabeca(lp), lp[0] * 1000,
                                                                   lp[1] * 1000, lp[2] * 1000)
        else:
            out["cabeca_no_pano_onde"] = "-"
        out["cabeca_no_pano_n2mm"] = int(np.sum(pc > 0.002))
        # O pano do lado de dentro da pele, pelo raio do centro da cabeca (os
        # dois sentidos: o pano que entra e a orelha ou o queixo que saem).
        m = mat(qd.q["cabeca"])
        sc_ = np.linalg.norm(m[:3, 0])
        hl = _no_espaco_da_cabeca(qd, hv)
        cl_all = _no_espaco_da_cabeca(qd, P)
        lo_l, hi_l = hl.min(0) - 0.02, hl.max(0) + 0.02
        perto_t = np.any(np.all((cl_all[TRI] > lo_l) & (cl_all[TRI] < hi_l), axis=2), axis=1)
        tris = TRI[perto_t]
        if len(tris):
            amostras = _amostrar_tris(cl_all, tris)
            f = atravessa_cabeca(hl, amostras, sc_)
            k = int(np.argmax(f))
            out["atravessa_mm"] = float(f[k] * 1000)
            out["atravessa_onde"] = "%s (%.0f,%.0f,%.0f mm)" % (regiao_da_cabeca(hl[k]), hl[k][0] * 1000,
                                                              hl[k][1] * 1000, hl[k][2] * 1000) if f[k] > 0 else "-"
            out["atravessa_n2mm"] = int(np.sum(f > 0.002))
            regs = {}
            for i in np.where(f > 0.002)[0]:
                r = regiao_da_cabeca(hl[i])
                regs[r] = regs.get(r, 0) + 1
            out["atravessa_regioes"] = regs
        else:
            out["atravessa_mm"] = 0.0
            out["atravessa_onde"] = "-"
            out["atravessa_n2mm"] = 0
            out["atravessa_regioes"] = {}
    return out, (P, NP, G, corpo, cab)


def main():
    global CAMPO
    d = sys.argv[1]
    if arg("sdf"):
        CAMPO = CampoDaCabeca(arg("sdf"))
    est = Estatico(d)
    de = float(arg("de", -1e9))
    ate = float(arg("ate", 1e9))
    cada = int(arg("cada", 1))
    arqs = sorted(glob.glob(os.path.join(d, "q_*.json")))
    arqs = [a for a in arqs if de <= float(os.path.basename(a)[2:-5]) <= ate][::cada]
    res = []
    for a in arqs:
        qd = Quadro(est, a)
        o, _ = medir(est, qd)
        res.append(o)
        print(" ".join("%s=%s" % (k, ("%.1f" % v) if isinstance(v, float) else v) for k, v in o.items()), flush=True)
    if arg("json"):
        json.dump(res, open(arg("json"), "w"), indent=1)
    if res:
        for chave in ["atravessa_mm", "pano_na_cabeca_mm", "cabeca_no_pano_mm", "pano_no_tronco_mm", "tronco_no_pano_mm",
                      "pano_no_braco_mm", "braco_no_pano_mm", "pano_no_pernas_mm"]:
            vals = [r[chave] for r in res if chave in r]
            if vals:
                k = int(np.argmax(vals))
                print("PIOR %s = %.1f mm em t=%.2f (%s); mediana %.1f" % (
                    chave, vals[k], res[k]["t"], res[k].get(chave.replace("_mm", "_onde"), ""),
                    float(np.median(vals))))


if __name__ == "__main__":
    main()
