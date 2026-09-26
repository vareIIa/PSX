"""As grades de particulas do pano (`PanoGPU`) ajustadas na batina AAA.

A batina de IA (endireitada por `r_endireitar`, no quadro do padre de 1,72 m)
vira tres pecas de pano, cada uma uma grade W x H fechada em tubo, como as de
`CapuzMacabro.vestir_pano`:
- capuz: raios do centro do cranio para fora (angulo polar de baixo para
  cima); a linha 0 abraca o pescoco (presa); na boca do capuz a grade passa
  na frente do rosto, curta e puxada (a malha nao tem vertice ali);
- murca: raios de um vertice no pescoco para baixo e para fora (sino); pega a
  camada de FORA que nao e o capuz deitado no ombro; por coluna, a ultima
  linha e a barra dela (`barra_z`: frente, lado e costas, medidas nas fotos).
  Nas costas e na gola a murca e a batina sao uma camada so: as duas grades
  ficam na mesma parede e `r_ligar` mistura as duas ali;
- batina: raios horizontais do eixo do corpo ate a barra; pega a camada de
  DENTRO. Comeca na gola nas costas (a capa) e logo abaixo da barra da murca
  na frente e nos lados (`topo_z`): no peito a murca e a unica camada.
Cada no da grade e o meio da parede (entre as duas faces do pano).

Duas formas por peca:
- `liga`: a grade em cima da malha de IA. E nela que `r_ligar` prende cada
  vertice da malha (a malha anda com a grade);
- `repouso`: onde o pano quer ficar no padre parado. No capuz e na murca e a
  mesma (a forma que o modelo desenhou; pendurada, a murca caia no peito e
  passava para tras do cordao da cintura); na batina e a grade pendurada:
  solta sob gravidade, presa na linha 0, batendo nos colisores do padre
  despejado e no chao. A capa de IA vinha soprada para tras (vento); parada
  ela cai.

Sai `grades.json` em coordenada do Godot (Y para cima, frente -Z), na pessoa de
referencia (escala 1), e fotos das grades sobre a batina.

blender -b reto.blend --python r_grades.py -- <padre.json> <cfg.json> <saida_dir>
"""
import sys, os, json, math
import bpy, bmesh
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

a = sys.argv[sys.argv.index("--") + 1:]
padre = json.load(open(a[0]))
cfg = json.load(open(a[1]))
saida = a[2]
os.makedirs(saida, exist_ok=True)

TORSO, CABECA, QUADRIL = 1, 2, 0


def g2b(v):
    return np.array([v[0], -v[2], v[1]])


def b2g(p):
    p = np.asarray(p)
    return np.stack([p[..., 0], p[..., 2], -p[..., 1]], axis=-1)


ob = bpy.data.objects["Batina"]
bm = bmesh.new()
bm.from_mesh(ob.data)
bm.transform(ob.matrix_world)
bvh = BVHTree.FromBMesh(bm)


# O rotulo de cada face da malha: qual grade a leva (-1 ainda sem). Os raios
# que ajustam as grades marcam as faces da camada que escolheram; o resto e
# inundado pela malha (`inundar`). `r_ligar` prende cada vertice na grade do
# rotulo das faces dele: camadas que so se encostam (a murca deitada no peito)
# nao se misturam, e cada uma balanca com a sua grade.
ROTULO = np.full(len(bm.faces), -1, dtype=int)
PRIORIDADE = {}   # peca -> prioridade (maior ganha a face disputada)


def acertos(o, d, longe=2.0, com_face=False):
    """Distancias ao longo do raio de todas as faces cruzadas (e as faces)."""
    r = []
    p = Vector(o)
    d = Vector(d)
    ida = 0.0
    for _ in range(12):
        hit, _n, fi, dist = bvh.ray_cast(p, d, longe - ida)
        if hit is None:
            break
        ida += dist
        r.append((ida, fi) if com_face else ida)
        p = hit + d * 1e-4
        ida += 1e-4
    return r


def pares(h, parede, com_face=False):
    """Junta as faces em camadas: duas faces a menos de `parede` sao as duas
    paredes do mesmo pano; sobra uma face so, ela e a camada."""
    if not com_face:
        h = [(x, -1) for x in h]
    cam = []
    k = 0
    while k < len(h):
        if k + 1 < len(h) and h[k + 1][0] - h[k][0] < parede:
            cam.append((0.5 * (h[k][0] + h[k + 1][0]), (h[k][1], h[k + 1][1])))
            k += 2
        else:
            cam.append((h[k][0], (h[k][1],)))
            k += 1
    return cam if com_face else [x for x, _f in cam]


def rotular(peca, faces):
    for fi in faces:
        if fi < 0:
            continue
        atual = ROTULO[fi]
        if atual < 0 or PRIORIDADE[peca] > PRIORIDADE[atual]:
            ROTULO[fi] = peca


def azimute(i, w):
    t = 2 * math.pi * i / w
    return math.sin(t), math.cos(t)


def preencher(pos, falta, w, h, periodico, voltas=400):
    """Os nos sem acerto viram a media dos vizinhos (relaxa pela grade)."""
    pos = pos.copy()
    idx = np.argwhere(falta)
    if len(idx) == 0:
        return pos
    # comeca pela media da linha
    for (j, i) in idx:
        linha = [pos[j, x] for x in range(w) if not falta[j, x]]
        if linha:
            pos[j, i] = np.mean(linha, axis=0)
    for _ in range(voltas):
        for (j, i) in idx:
            viz = []
            for dj, di in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                jj, ii = j + dj, i + di
                if periodico:
                    ii %= w
                if 0 <= jj < h and 0 <= ii < w:
                    viz.append(pos[jj, ii])
            pos[j, i] = np.mean(viz, axis=0)
    return pos


# ------------------------------------------------------------------ capuz
def grade_capuz(c):
    w, h = c["w"], c["h"]
    cranio = g2b(padre["cranio"]["centro"]) + np.array(c.get("origem_desloca", [0, 0, 0]))
    pos = np.zeros((h, w, 3))
    falta = np.zeros((h, w), bool)
    for j in range(h):
        v = j / (h - 1)
        fi = math.radians(c["polar"][0] + (c["polar"][1] - c["polar"][0]) * v)
        for i in range(w):
            sx, cy = azimute(i, w)
            d = np.array([math.sin(fi) * sx, math.sin(fi) * cy, math.cos(fi)])
            hs = pares(acertos(cranio, d, c["alcance"], True), c["parede"], True)
            if not hs:
                falta[j, i] = True
                continue
            pos[j, i] = cranio + d * hs[0][0]
    buraco = falta.copy()
    pos = preencher(pos, falta, w, h, True)
    return pos, buraco


# ------------------------------------------------------------------ murca
def barra_da_murca(c, sx, cy):
    """Altura da barra da murca no azimute (frente, lado, costas), medida nas
    fotos da batina endireitada; o rasgado da barra fica na malha."""
    f, l, t = c["barra_z"]
    return l + (f - l) * max(cy, 0.0) ** 2 + (t - l) * max(-cy, 0.0) ** 2


def grade_murca(c, perto_do_capuz):
    w, h = c["w"], c["h"]
    apice = np.array(c["apice"])
    passos = np.radians(np.arange(c["desce"][0], c["desce"][1], 0.25))
    pos = np.zeros((h, w, 3))

    def fora(d):
        # a camada de fora que nao e o capuz deitado no ombro
        cam = pares(acertos(apice, d, 1.5), c["parede"])
        for x in reversed(cam):
            if not perto_do_capuz(apice + d * x):
                return x
        return None

    for i in range(w):
        sx, cy = azimute(i, w)
        zb = barra_da_murca(c, sx, cy)
        barra = passos[-1]
        for ps in passos:
            d = np.array([math.cos(ps) * sx, math.cos(ps) * cy, -math.sin(ps)])
            x = fora(d)
            if x is not None and (apice + d * x)[2] < zb:
                barra = ps
                break
        for j in range(h):
            v = j / (h - 1)
            ps = passos[0] + (barra - passos[0]) * v
            d = np.array([math.cos(ps) * sx, math.cos(ps) * cy, -math.sin(ps)])
            x = fora(d)
            pos[j, i] = apice + d * (x if x is not None else 0.3)
    return pos


# ------------------------------------------------------------------ batina
def topo_da_batina(c, cy):
    """Onde a batina comeca na coluna: nas costas na gola (a capa), na frente e
    nos lados logo abaixo da barra da murca (no peito so ha a murca)."""
    f, l, t = c["topo_z"]
    return l + (f - l) * max(cy, 0.0) ** 2 + (t - l) * max(-cy, 0.0) ** 2


def grade_batina(c):
    w, h = c["w"], c["h"]
    pos = np.zeros((h, w, 3))
    falta = np.zeros((h, w), bool)
    for j in range(h):
        v = j / (h - 1)
        for i in range(w):
            sx, cy = azimute(i, w)
            alto = topo_da_batina(c, cy)
            z = alto + (c["baixo"] - alto) * v
            o = np.array([0.0, c["eixo_y"], z])
            d = np.array([sx, cy, 0.0])
            cam = pares(acertos(o, d, 1.5), c["parede"])
            if not cam:
                falta[j, i] = True
                continue
            pos[j, i] = o + d * cam[0]
    pos = preencher(pos, falta, w, h, True)
    return pos, falta


# ------------------------------------------------------------------ manga
MANGA_ATR = None
if "manga" in ob.data.attributes:
    MANGA_ATR = np.array([a.value for a in ob.data.attributes["manga"].data])
BVH_MANGA = {}


def bvh_da_manga(lado):
    """So as faces da manga (atributo `manga` do `r_limpar --mangas`): o raio
    que sai do braco nao acha a batina pelo buraco da costura."""
    if lado in BVH_MANGA:
        return BVH_MANGA[lado]
    sinal = -1 if lado == "E" else 1
    bm.faces.ensure_lookup_table()
    fs = [f for f in bm.faces if MANGA_ATR[f.index] == sinal]
    vs = {}
    pts = []
    polys = []
    for f in fs:
        pl = []
        for v in f.verts:
            if v.index not in vs:
                vs[v.index] = len(pts)
                pts.append(v.co.copy())
            pl.append(vs[v.index])
        polys.append(pl)
    BVH_MANGA[lado] = BVHTree.FromPolygons(pts, polys)
    return BVH_MANGA[lado]


def grade_manga(c):
    """Tubo em volta do eixo do braco: linhas do alto da manga (debaixo da
    murca) ate a franja do punho, colunas em volta (raios horizontais)."""
    w, h = c["w"], c["h"]
    lado = c["lado"]
    eixo = eixo_do_braco(lado)
    arvore = bvh_da_manga(lado)
    pos = np.zeros((h, w, 3))
    falta = np.zeros((h, w), bool)
    for j in range(h):
        z = c["topo"] + (c["baixo"] - c["topo"]) * j / (h - 1)
        o = no_eixo(eixo, z)
        for i in range(w):
            sx, cy = azimute(i, w)
            d = np.array([sx, cy, 0.0])
            hs = []
            p = Vector(o)
            ida = 0.0
            for _ in range(8):
                hit, _n, _fi, dist = arvore.ray_cast(p, Vector(d), 0.4 - ida)
                if hit is None:
                    break
                ida += dist
                hs.append(ida)
                p = hit + Vector(d) * 1e-4
                ida += 1e-4
            cam = pares(hs, c["parede"])
            if not cam:
                falta[j, i] = True
                continue
            pos[j, i] = o + d * cam[0]
    pos = preencher(pos, falta, w, h, True)
    return pos, falta


# --------------------------------------------------------- colisores e drape
def colisores():
    r = []
    for col in padre["colisores"]:
        r.append((g2b(col["a"]), g2b(col["b"]), col["r"], col["osso"]))
    return r


BRACO = {"E": 3, "D": 5}
ANTEBRACO = {"E": 4, "D": 6}


def eixo_do_braco(lado):
    """O eixo do braco no repouso (Blender), de cima para baixo: ombro,
    cotovelo, punho (as capsulas do braco e do antebraco do corpo)."""
    ca = [c for c in padre["colisores"] if c["osso"] == BRACO[lado]][0]
    cb = [c for c in padre["colisores"] if c["osso"] == ANTEBRACO[lado]][0]
    return np.array([g2b(ca["a"]), g2b(ca["b"]), g2b(cb["b"])])


def no_eixo(eixo, z):
    """O ponto do eixo na altura z (estende a primeira e a ultima perna)."""
    zs = eixo[:, 2]
    for k in range(len(eixo) - 1):
        a, b = eixo[k], eixo[k + 1]
        if z >= b[2] or k == len(eixo) - 2:
            t = (a[2] - z) / max(a[2] - b[2], 1e-9)
            return a + (b - a) * t
    return eixo[-1]


def pendurar(pos, c, cols):
    """Solta a grade sob gravidade (Verlet + ligacoes por Jacobi, como o
    compute do `PanoGPU`), a linha 0 presa, batendo nos colisores e no chao."""
    h, w, _ = pos.shape
    p = pos.reshape(-1, 3).copy()
    n = len(p)
    presa = np.zeros(n, bool)
    presa[:w] = True
    lig = []
    for j in range(h):
        for i in range(w):
            k = j * w + i
            for dj, di, kk in ((0, 1, 1.0), (1, 0, 1.0), (1, 1, 0.6), (1, -1, 0.6), (0, 2, 0.3), (2, 0, 0.3)):
                jj, ii = j + dj, (i + di) % w
                if jj < h:
                    lig.append((k, jj * w + ii, kk))
    lig = np.array(lig)
    ia = lig[:, 0].astype(int)
    ib = lig[:, 1].astype(int)
    rig = lig[:, 2]
    L = np.linalg.norm(p[ia] - p[ib], axis=1)
    pv = p.copy()
    dt = 1.0 / 240.0
    g = np.array([0.0, 0.0, -9.8])
    esp = c.get("espessura", 0.012)
    for _passo in range(int(c["drape_s"] / dt)):
        vel = (p - pv) * (1.0 - 2.5 * dt)
        pv = p.copy()
        p = p + vel + g * dt * dt
        p[presa] = pos.reshape(-1, 3)[presa]
        for _it in range(8):
            d = p[ib] - p[ia]
            dist = np.linalg.norm(d, axis=1) + 1e-9
            corr = (dist - L) / dist
            # pano dobra: compressao mole na dobra (ligacoes de 2)
            corr = np.where((corr < 0) & (rig < 0.5), corr * 0.15, corr)
            dd = d * (corr * rig * 0.5)[:, None]
            soma = np.zeros_like(p)
            cnt = np.zeros(n)
            np.add.at(soma, ia, dd)
            np.add.at(soma, ib, -dd)
            np.add.at(cnt, ia, 1)
            np.add.at(cnt, ib, 1)
            p = p + soma / np.maximum(cnt, 1)[:, None] * 1.5
            p[presa] = pos.reshape(-1, 3)[presa]
        for (ca, cb, r, _o) in cols:
            ab = cb - ca
            t = np.clip(((p - ca) @ ab) / max(ab @ ab, 1e-9), 0, 1)
            q = ca + t[:, None] * ab
            d = p - q
            l = np.linalg.norm(d, axis=1)
            dentro = l < r + esp
            nn = d[dentro] / np.maximum(l[dentro], 1e-6)[:, None]
            p[dentro] = q[dentro] + nn * (r + esp)
        chao = p[:, 2] < esp
        p[chao, 2] = esp
        pv[chao] = pv[chao] + (p[chao] - pv[chao]) * 0.85
    return p.reshape(h, w, 3)


# ------------------------------------------------------------ rotulos
DENSO = 3   # raios de rotulo por no de grade, em cada direcao


def rotular_capuz(k, c):
    cranio = g2b(padre["cranio"]["centro"]) + np.array(c.get("origem_desloca", [0, 0, 0]))
    w, h = c["w"] * DENSO, c["h"] * DENSO
    for j in range(h):
        fi = math.radians(c["polar"][0] + (c["polar"][1] - c["polar"][0]) * j / (h - 1))
        for i in range(w):
            sx, cy = azimute(i, w)
            d = np.array([math.sin(fi) * sx, math.sin(fi) * cy, math.cos(fi)])
            hs = pares(acertos(cranio, d, c["alcance"], True), c["parede"], True)
            if hs:
                rotular(k, hs[0][1])


def rotular_murca(k, c, perto_do_capuz):
    apice = np.array(c["apice"])
    passos = np.radians(np.arange(c["desce"][0], c["desce"][1], 0.25))
    w = c["w"] * DENSO
    for i in range(w):
        sx, cy = azimute(i, w)
        zb = barra_da_murca(c, sx, cy)
        for ps in passos:
            d = np.array([math.cos(ps) * sx, math.cos(ps) * cy, -math.sin(ps)])
            cam = pares(acertos(apice, d, 1.5, True), c["parede"], True)
            fora = None
            for x, fs in reversed(cam):
                if not perto_do_capuz(apice + d * x):
                    fora = (x, fs)
                    break
            if fora is None:
                continue
            if (apice + d * fora[0])[2] < zb:
                break
            rotular(k, fora[1])


def rotular_batina(k, c):
    w, h = c["w"] * DENSO, c["h"] * DENSO
    for j in range(h):
        for i in range(w):
            sx, cy = azimute(i, w)
            alto = topo_da_batina(c, cy)
            z = alto + (c["baixo"] - alto) * j / (h - 1)
            o = np.array([0.0, c["eixo_y"], z])
            cam = pares(acertos(o, np.array([sx, cy, 0.0]), 1.5, True), c["parede"], True)
            if cam:
                rotular(k, cam[0][1])


def inundar():
    """As faces sem rotulo pegam o da vizinha rotulada mais perto (em faces),
    todas as frentes andando juntas."""
    bm.faces.ensure_lookup_table()
    frente = [f.index for f in bm.faces if ROTULO[f.index] >= 0]
    while frente:
        nova = []
        for fi in frente:
            for e in bm.faces[fi].edges:
                for g in e.link_faces:
                    if ROTULO[g.index] < 0:
                        ROTULO[g.index] = ROTULO[fi]
                        nova.append(g.index)
        frente = nova


# ------------------------------------------------------------ alisar e dobra
def alisar(pos, voltas, fixa_linha0=True, lam=0.5, mu=-0.53):
    """Taubin (encolhe quase nada): a grade de ligar vira um lencol liso. As
    dobras da malha de IA ficam no desvio de cada vertice, e nao na grade: onde
    a grade dobrava sobre si a normal virava, e quando o pano alisava na fisica
    o desvio para fora apontava para dentro (a parede de dentro aparecia)."""
    p = pos.copy()
    h, w = p.shape[:2]
    for _ in range(voltas):
        for fator in (lam, mu):
            viz = np.zeros_like(p)
            cnt = np.zeros((h, w, 1))
            viz[:, :] += np.roll(p, 1, axis=1) + np.roll(p, -1, axis=1)
            cnt += 2
            viz[1:] += p[:-1]
            cnt[1:] += 1
            viz[:-1] += p[1:]
            cnt[:-1] += 1
            q = p + fator * (viz / cnt - p)
            if fixa_linha0:
                q[0] = p[0]
            p = q
    return p


def dobras(pos):
    """Quantas celulas tem a normal (du x dv) virada contra a maioria."""
    du = np.roll(pos, -1, axis=1) - np.roll(pos, 1, axis=1)
    dv = np.zeros_like(pos)
    dv[1:-1] = pos[2:] - pos[:-2]
    dv[0] = pos[1] - pos[0]
    dv[-1] = pos[-1] - pos[-2]
    n = np.cross(du, dv)
    centro = pos.reshape(-1, 3).mean(0)
    radial = pos - centro
    radial[..., 2] *= 0.3
    sinal = np.sign(np.sum(n * radial, axis=-1))
    maioria = 1 if (sinal > 0).sum() >= (sinal < 0).sum() else -1
    return int((sinal == -maioria).sum())


# ------------------------------------------------------------------ pesos
def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def tabela(vals, v):
    f = v * (len(vals) - 1)
    k = min(int(f), len(vals) - 2)
    return vals[k] + (vals[k + 1] - vals[k]) * (f - k)


def bvh_da_grade(pos):
    h, w = pos.shape[:2]
    vs = [Vector(p) for p in pos.reshape(-1, 3)]
    fs = []
    for j in range(h - 1):
        for i in range(w):
            fs.append((j * w + i, j * w + (i + 1) % w, (j + 1) * w + (i + 1) % w, (j + 1) * w + i))
    return BVHTree.FromPolygons(vs, fs)


pecas = []
cols = colisores()
capuz_bvh = None
for k, c in enumerate(cfg["pecas"]):
    PRIORIDADE[k] = c["prioridade"]
for c in cfg["pecas"]:
    tipo = c["tipo"]
    buraco = None
    if tipo == "capuz":
        liga, buraco = grade_capuz(c)
        capuz_bvh = bvh_da_grade(liga)
    elif tipo == "murca":
        perto = (lambda p: capuz_bvh.find_nearest(Vector(p), c["longe_do_capuz"])[0] is not None)             if capuz_bvh is not None else (lambda p: False)
        liga = grade_murca(c, perto)
    elif tipo == "manga":
        liga, _falta = grade_manga(c)
    else:
        liga, _falta = grade_batina(c)
    antes = dobras(liga)
    if c.get("alisar", 0) > 0:
        liga = alisar(liga, c["alisar"])
    print("[grades] %s: celulas com a normal virada %d -> %d" % (c["nome"], antes, dobras(liga)))
    h, w = liga.shape[:2]
    # A batina passa entre o tronco e o braco de cima: nao ve o braco (como no
    # jogo, `BatinaAAA._nao_ve`).
    cols_p = [x for x in cols if not (tipo == "batina" and x[3] in (BRACO["E"], BRACO["D"]))]
    rep = pendurar(liga, c, cols_p) if c.get("drape_s", 0) > 0 else liga.copy()
    v = np.repeat((np.arange(h) / (h - 1))[:, None], w, axis=1)
    z = liga[:, :, 2]
    if tipo == "capuz":
        oa = np.full((h, w), TORSO)
        ob_ = np.full((h, w), CABECA)
        pb = smooth(c["cabeca_de"][0], c["cabeca_de"][1], v)
    elif tipo == "murca":
        oa = np.full((h, w), TORSO)
        ob_ = np.full((h, w), TORSO)
        pb = np.zeros((h, w))
    elif tipo == "manga":
        # Presa no braco em cima e no antebraco embaixo, misturada no cotovelo.
        eixo = eixo_do_braco(c["lado"])
        oa = np.full((h, w), BRACO[c["lado"]])
        ob_ = np.full((h, w), ANTEBRACO[c["lado"]])
        zc = eixo[1][2]
        pb = smooth(zc + c.get("cotovelo_faixa", 0.06), zc - c.get("cotovelo_faixa", 0.06), z)
    else:
        oa = np.full((h, w), TORSO)
        ob_ = np.full((h, w), QUADRIL)
        pb = smooth(c["quadril_de"][0], c["quadril_de"][1], z)
    fo = np.vectorize(lambda x: tabela(c["folgas"], x))(v)
    pu = np.vectorize(lambda x: tabela(c["puxas"], x))(v)
    pr = (v == 0).astype(int)
    ex = np.ones((h, w), int)
    if buraco is not None:
        # A boca do capuz nao e buraco na grade: um no que so segue o osso ao
        # lado de um que simula dobra a superficie entre os dois (a borda da
        # boca virava estilhaco). O no da boca simula, mas curto e puxado.
        fo[buraco] = c.get("boca_folga", 0.006)
        pu[buraco] = c.get("boca_puxa", 6.0)
    an = np.repeat(np.arange(w)[None, :], h, axis=0)
    an = np.where(v <= c.get("ancora_ate", 1.0), an, -1)
    peca = {"nome": c["nome"], "tipo": tipo, "w": w, "h": h, "periodico": True,
            "liga": b2g(liga).reshape(-1, 3).round(5).tolist(),
            "repouso": b2g(rep).reshape(-1, 3).round(5).tolist(),
            "osso_a": oa.reshape(-1).tolist(), "osso_b": ob_.reshape(-1).tolist(),
            "peso_b": pb.reshape(-1).round(4).tolist(),
            "folga": fo.reshape(-1).round(4).tolist(), "puxa": pu.reshape(-1).round(3).tolist(),
            "preso": pr.reshape(-1).tolist(), "existe": ex.reshape(-1).tolist(),
            "ancora": an.reshape(-1).tolist(), "opcoes": c.get("opcoes", {})}
    pecas.append(peca)
    mv = np.linalg.norm(rep - liga, axis=2)
    print("[grades] %s %dx%d buracos=%d desce_max=%.3f media=%.3f" % (
        c["nome"], w, h, int((ex == 0).sum()), mv.max(), mv.mean()))
json.dump({"altura_ref": padre["altura"], "pecas": pecas}, open(os.path.join(saida, "grades.json"), "w"))

# --- rotulos das faces ---
for k, c in enumerate(cfg["pecas"]):
    if c["tipo"] == "capuz":
        rotular_capuz(k, c)
    elif c["tipo"] == "murca":
        rotular_murca(k, c, (lambda p: capuz_bvh.find_nearest(Vector(p), c["longe_do_capuz"])[0] is not None))
    elif c["tipo"] == "batina":
        rotular_batina(k, c)
for k, c in enumerate(cfg["pecas"]):
    if c["tipo"] == "manga" and MANGA_ATR is not None:
        ROTULO[MANGA_ATR == (-1 if c["lado"] == "E" else 1)] = k
if MANGA_ATR is not None:
    # O resto da malha nunca vai para a grade de uma manga.
    ids_manga = [k for k, c in enumerate(cfg["pecas"]) if c["tipo"] == "manga"]
    ROTULO[(MANGA_ATR == 0) & np.isin(ROTULO, ids_manga)] = -1
print("[grades] faces rotuladas pelos raios: %d de %d" % (int((ROTULO >= 0).sum()), len(ROTULO)))
inundar()
for k, c in enumerate(cfg["pecas"]):
    print("[grades] rotulo %s: %d faces" % (c["nome"], int((ROTULO == k).sum())))
json.dump(ROTULO.tolist(), open(os.path.join(saida, "rotulos.json"), "w"))
# pinta a batina pelo rotulo (fotos)
ca = ob.data.color_attributes.new("rotulo", "BYTE_COLOR", "CORNER")
cores = [(0.9, 0.2, 0.15, 1), (0.2, 0.8, 0.25, 1), (0.2, 0.35, 0.95, 1), (0.95, 0.8, 0.1, 1), (0.8, 0.2, 0.9, 1)]
for poly in ob.data.polygons:
    cor = cores[ROTULO[poly.index]] if ROTULO[poly.index] >= 0 else (1, 1, 1, 1)
    for li in poly.loop_indices:
        ca.data[li].color = cor
mat_r = bpy.data.materials.new("rotulo")
mat_r.use_nodes = True
at = mat_r.node_tree.nodes.new("ShaderNodeVertexColor")
at.layer_name = "rotulo"
mat_r.node_tree.links.new(at.outputs["Color"], mat_r.node_tree.nodes["Principled BSDF"].inputs["Base Color"])


# ------------------------------------------------------------------ fotos
def malha_grade(nome, pts, cor, raio=0.004):
    h, w = pts.shape[:2]
    b2 = bmesh.new()
    vs = [[b2.verts.new(Vector(pts[j, i])) for i in range(w)] for j in range(h)]
    for j in range(h):
        for i in range(w):
            b2.edges.new((vs[j][i], vs[j][(i + 1) % w]))
            if j + 1 < h:
                b2.edges.new((vs[j][i], vs[j + 1][i]))
    me = bpy.data.meshes.new(nome)
    b2.to_mesh(me)
    b2.free()
    o = bpy.data.objects.new(nome, me)
    bpy.context.scene.collection.objects.link(o)
    sk = o.modifiers.new("fio", "SKIN")
    for sv in me.skin_vertices[0].data:
        sv.radius = (raio, raio)
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = cor
    me.materials.append(m)
    return o


ob.data.materials.clear()
ob.data.materials.append(mat_r)
cena = bpy.context.scene
for o in list(cena.objects):
    if o.type in ("CAMERA", "LIGHT"):
        bpy.data.objects.remove(o)
cena.render.engine = "BLENDER_EEVEE"
cena.render.resolution_x = 1000
cena.render.resolution_y = 1000
wd = bpy.data.worlds.new("w")
cena.world = wd
wd.use_nodes = True
wd.node_tree.nodes["Background"].inputs[0].default_value = (0.85, 0.85, 0.9, 1)
luz = bpy.data.lights.new("l", "SUN")
luz.energy = 3.0
lo = bpy.data.objects.new("l", luz)
cena.collection.objects.link(lo)
lo.rotation_euler = (math.radians(50), 0, math.radians(30))
cam = bpy.data.cameras.new("c")
cam.type = "ORTHO"
cam.clip_start = 0.001
cam.clip_end = 30
co = bpy.data.objects.new("c", cam)
cena.collection.objects.link(co)
cena.camera = co
for nome, dv, cc, esc in [("lado", Vector((1, 0, 0)), Vector((0, -0.15, 0.95)), 2.1),
                          ("frente", Vector((0, 1, 0)), Vector((0, 0, 0.95)), 2.1),
                          ("tq", Vector((0.7, 0.7, 0.3)), Vector((0, 0, 1.2)), 1.4),
                          ("costas", Vector((-0.6, -0.8, 0.2)), Vector((0, -0.2, 0.9)), 2.1)]:
    cam.ortho_scale = esc
    cima = Vector((0, 0, 1))
    z_loc = dv.normalized()
    x_loc = cima.cross(z_loc).normalized()
    y_loc = z_loc.cross(x_loc)
    co.matrix_world = Matrix.Translation(cc + z_loc * 5.0) @ Matrix((x_loc, y_loc, z_loc)).transposed().to_4x4()
    cena.render.filepath = os.path.join(saida, "rotulos_%s.png" % nome)
    bpy.ops.render.render(write_still=True)
print("[grades] ok")
