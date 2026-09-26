"""Batina de IA -> malha base da batina AAA dos padres.

Tira o que nao e pano e o que o jogo poe por conta propria:
- a cruz, a haste e a fita em V do pescoco (o crucifixo e a corrente novos tem
  fisica propria, ver tools/blender_cruz): faces na frente do peito e as de
  rugosidade baixa (metal) na regiao do pescoco, crescidas por vizinhanca;
- as mangas (cada padre traz o braco com a manga dele: `BracosPodres`,
  `BracoDoPadre`): face cujo raio para o eixo do corpo acha outra parede antes
  de VAO (vazio estreito da manga, e nao o miolo do corpo), na faixa das mangas.
Tapa os buracos com uma membrana subdividida e alisada, com a cor lisa de pano.

blender -b --python r_limpar.py -- <glb> <saida.blend>
"""
import sys
import bpy, bmesh
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

argv = sys.argv[sys.argv.index("--") + 1:]
glb, saida = argv[0], argv[1]
# `--mangas`: as mangas ficam (separadas da batina, cada uma uma peca solta da
# malha) para vestir o `CorpoAAA`, que tem braco dentro delas.
MANTER_MANGAS = "--mangas" in argv

# A fita e a cruz (coordenadas da malha do gerador, Z para cima, frente -Y).
def e_fita(c, rug):
    return (c.y < -0.168 and 0.28 < c.z < 0.70 and abs(c.x) < 0.10) or \
        (-0.07 < c.x < 0.06 and 0.64 < c.z < 0.73 and c.y < -0.08 and rug < 0.86)
def cresce_fita(c, rug):
    return rug < 0.9 and c.z < 0.74 and c.y < -0.08 and abs(c.x) < 0.1
ANEIS_FITA = 6
# As mangas: faixa (z, |x|, y), o eixo do corpo (y) e o vao.
MANGA_Z = (0.38, 0.615)
MANGA_XMIN = 0.095
MANGA_Y = (-0.085, 0.07)
EIXO_Y = 0.03
VAO = 0.09
# Ate onde desce a franja do punho (abaixo dela o tubo da manga pegava a saia).
MANGA_FRANJA = 0.33
PAREDE = 0.012

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
ob = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
ob.name = "Batina"
ob.data.name = "Batina"
bpy.context.view_layer.objects.active = ob
ob.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
imgs = {("mr" if "metallic" in i.name else "n" if "normal" in i.name else "cor"): i for i in bpy.data.images}
def pixels(img):
    W, H = img.size
    px = np.empty(W * H * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    return px.reshape(H, W, 4)
mr = pixels(imgs["mr"])
cor = pixels(imgs["cor"])
H, W = mr.shape[:2]
def texel(a, uv):
    return a[min(int(uv.x % 1 * H), H - 1) if False else min(int(uv.y % 1 * H), H - 1),
             min(int(uv.x % 1 * W), W - 1)]

bm = bmesh.new()
bm.from_mesh(ob.data)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
uvl = bm.loops.layers.uv.active
bm.faces.ensure_lookup_table()

def rug_de(f):
    us = [l[uvl].uv for l in f.loops]
    us.append(sum(us, start=Vector((0, 0))) / len(us))
    return sum(float(texel(mr, u)[1]) for u in us) / len(us)

# --- fita e cruz ---
P = [(f.calc_center_median(), rug_de(f)) for f in bm.faces]
fita = set(i for i, (c, r) in enumerate(P) if e_fita(c, r))
for _ in range(ANEIS_FITA):
    novos = set()
    for i in fita:
        for e in bm.faces[i].edges:
            for g in e.link_faces:
                if g.index not in fita and cresce_fita(*P[g.index]):
                    novos.add(g.index)
    if not novos:
        break
    fita |= novos

# --- mangas ---
bvh = BVHTree.FromBMesh(bm)
manga = set()
for f in bm.faces:
    c = P[f.index][0]
    if not (MANGA_Z[0] < c.z < MANGA_Z[1] and abs(c.x) > MANGA_XMIN and MANGA_Y[0] < c.y < MANGA_Y[1]):
        continue
    d = Vector((-c.x, EIXO_Y - c.y, 0.0)).normalized()
    p = c + d * 1e-4
    acertos = []
    for _ in range(4):
        hit, _n, _i, _d = bvh.ray_cast(p, d, 1.0)
        if hit is None:
            break
        acertos.append((hit - c).length)
        p = hit + d * 1e-4
    resto = [x for x in acertos if x > PAREDE]
    if resto and resto[0] < VAO:
        manga.add(f.index)
print("[r_limpar] fita %d faces, mangas %d faces" % (len(fita), len(manga)))
def vizinhas(f):
    return [g for e in f.edges for g in e.link_faces if g is not f]


def maior_pedaco(conj, sinal):
    """O maior pedaco ligado (por aresta) das faces de `conj` do lado `sinal`."""
    resto = set(i for i in conj if (P[i][0].x > 0) == (sinal > 0))
    melhor = set()
    while resto:
        i0 = resto.pop()
        pilha = [i0]
        comp = {i0}
        while pilha:
            f = bm.faces[pilha.pop()]
            for g in vizinhas(f):
                if g.index in resto:
                    resto.discard(g.index)
                    comp.add(g.index)
                    pilha.append(g.index)
        if len(comp) > len(melhor):
            melhor = comp
    return melhor


if MANTER_MANGAS:
    # O raio acerta face a face e deixa a manga salpicada: voto dos vizinhos
    # (duas voltas), e fica o maior pedaco de cada lado.
    for _ in range(3):
        novo = set()
        for f in bm.faces:
            if f.index in fita:
                continue
            c = P[f.index][0]
            if not (MANGA_Z[0] - 0.01 < c.z < MANGA_Z[1] + 0.01 and abs(c.x) > MANGA_XMIN - 0.01):
                continue
            vz = vizinhas(f)
            votos = sum(1 for g in vz if g.index in manga) + (1 if f.index in manga else 0)
            if votos * 2 > len(vz) + 1:
                novo.add(f.index)
        manga = novo
    lados = {}
    TUBO = {}
    for sinal in (-1, 1):
        lados[sinal] = maior_pedaco(manga, sinal)
    # A franja do punho vai com a manga: faces ligadas abaixo da faixa, dentro
    # do tubo dela (eixo por PCA dos centros, raio de 95%).
    for sinal, pedaco in lados.items():
        cs = np.array([tuple(P[i][0]) for i in pedaco])
        m0 = cs.mean(0)
        _u, _s, vt = np.linalg.svd(cs - m0)
        eixo = vt[0] / np.linalg.norm(vt[0])
        rel = cs - m0
        dist = np.linalg.norm(rel - np.outer(rel @ eixo, eixo), axis=1)
        R = float(np.percentile(dist, 95)) * 1.15
        for _ in range(60):
            novos = set()
            for i in pedaco:
                for g in vizinhas(bm.faces[i]):
                    if g.index in pedaco or g.index in fita:
                        continue
                    c = np.array(tuple(P[g.index][0]))
                    r = c - m0
                    d = np.linalg.norm(r - (r @ eixo) * eixo)
                    if MANGA_FRANJA < c[2] < MANGA_Z[0] + 0.03 and d < R:
                        novos.add(g.index)
            if not novos:
                break
            pedaco |= novos
        TUBO[sinal] = (m0, eixo, R)
        print("[r_limpar] manga %+d: %d faces, eixo %s raio %.3f" % (sinal, len(pedaco), np.round(eixo, 2), R))
    manga = lados[-1] | lados[1]
    corte = [e for e in bm.edges if len(e.link_faces) >= 2 and
             len(set(g.index in manga for g in e.link_faces)) == 2]
    # A costura, por posicao (o split cria arestas novas): so ela e tapada; a
    # boca do punho (borda que ja existia) fica aberta.
    def chave_aresta(e):
        a, b = (tuple(round(x, 6) for x in v.co) for v in e.verts)
        return (a, b) if a < b else (b, a)
    COSTURA = set(chave_aresta(e) for e in corte)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index in fita], context="FACES")
    bmesh.ops.split_edges(bm, edges=[e for e in corte if e.is_valid])
    print("[r_limpar] mangas mantidas: %d faces, %d arestas de costura cortadas" % (len(manga), len(corte)))
else:
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index in fita or f.index in manga], context="FACES")

# --- pecas soltas: a cruz de baixo (na frente) e farelos ---
bm.verts.ensure_lookup_table()
visto = set()
for v in list(bm.verts):
    if not v.is_valid or v.index in visto:
        continue
    pilha = [v]
    visto.add(v.index)
    g = []
    while pilha:
        a = pilha.pop()
        g.append(a)
        for e in a.link_edges:
            b = e.other_vert(a)
            if b.index not in visto:
                visto.add(b.index)
                pilha.append(b)
    if len(g) < 60 or (len(g) < 5000 and max(a.co.y for a in g) < -0.12):
        bmesh.ops.delete(bm, geom=g, context="VERTS")

# --- tampa: membrana subdividida e alisada, cor lisa de pano ---
antes = set(bm.faces)
bordas = [e for e in bm.edges if e.is_boundary]
if MANTER_MANGAS:
    # Tapa tudo como antes (o buraco da fita no peito, sem o qual os raios da
    # murca passavam e achavam a camada de tras), menos a boca da manga: borda
    # de face da manga so se for costura.
    def na_manga(f):
        c = np.array(tuple(f.calc_center_median()))
        for sinal, (m0, eixo, R) in TUBO.items():
            r = c - m0
            if np.linalg.norm(r - (r @ eixo) * eixo) < R * 1.1 and (c[0] > 0) == (sinal > 0)                     and MANGA_FRANJA - 0.02 < c[2] < MANGA_Z[1] + 0.01:
                return True
        return False
    bordas = [e for e in bordas if chave_aresta(e) in COSTURA
              or not any(na_manga(f) for f in e.link_faces)]
bmesh.ops.holes_fill(bm, edges=bordas, sides=0)
novas = [f for f in bm.faces if f not in antes]
bmesh.ops.triangulate(bm, faces=novas, quad_method="BEAUTY", ngon_method="BEAUTY")
novas = [f for f in bm.faces if f not in antes]
borda_v = set(v for f in novas for v in f.verts)
internas = [e for e in set(e for f in novas for e in f.edges) if all(lf in novas for lf in e.link_faces) and len(e.link_faces) == 2]
if internas:
    bmesh.ops.subdivide_edges(bm, edges=internas, cuts=2, use_grid_fill=True)
novas = [f for f in bm.faces if f not in antes]
miolo = [v for v in set(v for f in novas for v in f.verts) if v not in borda_v]
for _ in range(30):
    bmesh.ops.smooth_vert(bm, verts=miolo, factor=0.6, use_axis_x=True, use_axis_y=True, use_axis_z=True)
# --- remendo: a trama de pano nos tampos ---
# Com um texel so (a cor lisa) o buraco da fita no peito virava um retangulo
# chapado e mais escuro que a murca, debaixo do queixo, onde a janela enquadra o
# padre de perto. O atlas do gerador nao tem canto livre para ele (a UV e
# fragmentada), entao o tampo leva coordenadas planas proprias, na densidade de
# UV do pano em volta, marcadas com U >= 2 (a UV do gerador vai de 0 a 1). O
# shader da `BatinaAAA` repete ali, em espelho, um quadrado de pano limpo do
# proprio atlas (`remendo.json`: origem e lado): cor, relevo e rugosidade de pano
# de verdade, na mesma resolucao. A cor casa com a borda por vertice: a
# diferenca (linear) entre o pano original na borda e o recorte ali vai no
# atributo `remendo` (rgb = 0,5 + dif / 2), espalhada para dentro por peso de
# distancia. Fora dos tampos, `remendo` = (0,5, 0,5, 0,5, 1): nada muda.
import json, os, random, math
RU = 1024          # raster da UV (texel de 4 px do atlas de 4K)
REMENDO_U = 2.0    # o U dos tampos comeca aqui
bm.faces.index_update()
ids_tampo = [f.index for f in novas]
tampo_lay = bm.faces.layers.int.new("tampo")
remendo_lay = bm.verts.layers.float_color.new("remendo")
bm.faces.ensure_lookup_table()
bm.verts.ensure_lookup_table()
uvl = bm.loops.layers.uv.active
novas = [bm.faces[i] for i in ids_tampo]
novas_set = set(novas)
for f in novas:
    f[tampo_lay] = 1
for v in bm.verts:
    v[remendo_lay] = (0.5, 0.5, 0.5, 1.0)
orig = [f for f in bm.faces if f not in novas_set]


def linear(c):
    c = np.asarray(c, np.float64)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def media(u, v, r=2):
    """A cor (sRGB) do atlas em volta de (u, v), UV do Blender (v para cima)."""
    y = int(min(max(v, 0.0), 0.999999) * cor.shape[0])
    x = int(min(max(u, 0.0), 0.999999) * cor.shape[1])
    return cor[max(y - r, 0):y + r + 1, max(x - r, 0):x + r + 1, :3].reshape(-1, 3).mean(0)


def rasterizar(faces, valor, alvo):
    for f in faces:
        us = [l[uvl].uv for l in f.loops]
        for k in range(1, len(us) - 1):
            t = np.array([[us[0].x, us[0].y], [us[k].x, us[k].y], [us[k + 1].x, us[k + 1].y]]) * RU
            x0, y0 = np.maximum(np.floor(t.min(0)).astype(int), 0)
            x1, y1 = np.minimum(np.ceil(t.max(0)).astype(int), RU - 1)
            if x1 < x0 or y1 < y0:
                continue
            xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)

            def lado(p, q):
                return (q[0] - p[0]) * (ys - p[1]) - (q[1] - p[1]) * (xs - p[0])
            s0, s1, s2 = lado(t[0], t[1]), lado(t[1], t[2]), lado(t[2], t[0])
            dentro = ((s0 >= 0) & (s1 >= 0) & (s2 >= 0)) | ((s0 <= 0) & (s1 <= 0) & (s2 <= 0))
            bloco = alvo[y0:y1 + 1, x0:x1 + 1]
            bloco[dentro] = valor(f)


# Ilhas da UV (faces ligadas por aresta sem costura de UV) no raster: o recorte
# tem de cair inteiro numa ilha so, senao pega a costura e o vizinho do atlas.
pai = {f.index: f.index for f in orig}


def raiz(i):
    while pai[i] != i:
        pai[i] = pai[pai[i]]
        i = pai[i]
    return i


for e in bm.edges:
    fs = [f for f in e.link_faces if f.index in pai]
    if len(fs) != 2:
        continue
    fa, fb = fs
    la = {l.vert: l[uvl].uv for l in fa.loops}
    lb = {l.vert: l[uvl].uv for l in fb.loops}
    if all((la[v] - lb[v]).length < 1e-6 for v in e.verts):
        pai[raiz(fa.index)] = raiz(fb.index)
ilha = np.full((RU, RU), -1, np.int32)
rasterizar(orig, lambda f: raiz(f.index), ilha)
cor_r = cor[::max(cor.shape[0] // RU, 1), ::max(cor.shape[1] // RU, 1), :3][:RU, :RU]

# Os tampos e a cor da borda de todos.
visto = set()
grupos = []
for f0 in novas:
    if f0 in visto:
        continue
    pilha = [f0]
    visto.add(f0)
    g = []
    while pilha:
        f = pilha.pop()
        g.append(f)
        for e in f.edges:
            for h2 in e.link_faces:
                if h2 in novas_set and h2 not in visto:
                    visto.add(h2)
                    pilha.append(h2)
    grupos.append(g)
bordas = []
for tampo in grupos:
    b = {}
    for f in tampo:
        for v in f.verts:
            if v in b:
                continue
            for l in v.link_loops:
                if l.face not in novas_set:
                    b[v] = l[uvl].uv.copy()
                    break
    bordas.append(b)
cor_alvo = np.median([media(u.x, u.y) for b in bordas for u in b.values()], axis=0)

# O recorte: o maior quadrado (ate 160 texels do raster, 640 px) numa ilha so, com
# a cor perto da borda dos tampos e pouca variacao (pano, nao costura nem mancha).
random.seed(7)
rc = None
lado_r = 160
while lado_r >= 16 and rc is None:
    melhor = None
    for _ in range(6000):
        y = random.randrange(0, RU - lado_r)
        x = random.randrange(0, RU - lado_r)
        i0 = ilha[y, x]
        if i0 < 0 or not np.all(ilha[y:y + lado_r, x:x + lado_r] == i0):
            continue
        c = cor_r[y:y + lado_r, x:x + lado_r]
        nota = float(np.linalg.norm(c.reshape(-1, 3).mean(0) - cor_alvo)) + 0.5 * float(c.mean(2).std())
        if melhor is None or nota < melhor[0]:
            melhor = (nota, x / RU, y / RU)
    if melhor is not None:
        rc = (melhor[1], melhor[2], lado_r / RU)
    lado_r = int(lado_r * 0.8)
assert rc is not None, "sem recorte de pano"
RX, RY, RL = rc
print("[r_limpar] recorte do remendo: %d px em (%.3f, %.3f)" % (round(RL * 4096), RX, RY))


def no_recorte(a, b):
    """A UV do Blender que o shader le no ponto (a, b) do tampo (a, b: a
    coordenada plana, em UV; o shader espelha em Godot, com v = 1 - v)."""
    gv = 1.0 - b
    q = np.array([a, gv]) / RL
    m = np.mod(q, 2.0)
    r = np.where(m > 1.0, 2.0 - m, m)
    ug = RX + r[0] * RL
    vg = (1.0 - (RY + RL)) + r[1] * RL
    return ug, 1.0 - vg


lisos = 0
for tampo, borda in zip(grupos, bordas):
    viz = [g for f in tampo for e in f.edges for g in e.link_faces if g not in novas_set]
    verts = list(set(v for f in tampo for v in f.verts))
    if not viz or not borda:
        lisos += len(tampo)
        continue
    n = sum((g.normal for g in viz), Vector()).normalized()
    razoes = []
    for g in viz:
        us = [l[uvl].uv for l in g.loops]
        a_uv = sum(abs((us[k].x - us[0].x) * (us[k + 1].y - us[0].y) - (us[k + 1].x - us[0].x) * (us[k].y - us[0].y)) * 0.5
                   for k in range(1, len(us) - 1))
        razoes.append(a_uv / max(g.calc_area(), 1e-12))
    dens = math.sqrt(float(np.median(razoes)))  # UV por metro
    cima = Vector((0.0, 0.0, 1.0))
    ey = cima - n * n.dot(cima)
    ey = ey.normalized() if ey.length > 0.3 else n.cross(Vector((1.0, 0.0, 0.0))).normalized()
    ex = ey.cross(n).normalized()
    c = sum((v.co for v in verts), Vector()) / len(verts)
    ab = {v: ((v.co - c).dot(ex) * dens, (v.co - c).dot(ey) * dens) for v in verts}
    a0 = min(p[0] for p in ab.values())
    b0 = min(p[1] for p in ab.values())
    ab = {v: (p[0] - a0, p[1] - b0) for v, p in ab.items()}
    for f in tampo:
        for l in f.loops:
            l[uvl].uv = Vector((REMENDO_U + ab[l.vert][0], ab[l.vert][1]))
    # A diferenca de cor na borda, e para dentro por peso de distancia.
    pts, difs = [], []
    for v, uv in borda.items():
        alvo = linear(media(uv.x, uv.y))
        u2, v2 = no_recorte(*ab[v])
        agora = linear(media(u2, v2))
        pts.append(v.co.copy())
        difs.append(alvo - agora)
    difs = np.array(difs)
    for v in verts:
        if v in borda:
            d = difs[list(borda.keys()).index(v)]
        else:
            w = np.array([1.0 / ((v.co - p).length_squared + 1e-4) for p in pts])
            d = (w[:, None] * difs).sum(0) / w.sum()
        d = np.clip(0.5 + d * 0.5, 0.0, 1.0)
        v[remendo_lay] = (float(d[0]), float(d[1]), float(d[2]), 1.0)
    if len(tampo) > 40:
        print("[r_limpar] remendo %d faces, centro %s, dif media %s" % (
            len(tampo), tuple(round(x, 3) for x in c), np.round(difs.mean(0), 3)))
json.dump({"u": REMENDO_U, "origem": [RX, 1.0 - (RY + RL)], "lado": RL},
          open(os.path.join(os.path.dirname(saida), "remendo.json"), "w"))
print("[r_limpar] remendos: %d tampos; %d faces na cor lisa" % (len(grupos), lisos))
borda = sum(1 for e in bm.edges if e.is_boundary)
print("[r_limpar] tampos: %d faces, borda restante %d; verts %d faces %d" % (
    len(novas), borda, len(bm.verts), len(bm.faces)))
if MANTER_MANGAS:
    # Cada peca solta com a maioria das faces fora do corpo (|x| > MANGA_XMIN,
    # na faixa das mangas) e uma manga: -1 a esquerda do jogo, +1 a direita
    # (o gerador olha -Y: o +X dele e a esquerda de quem veste... gravado pelo
    # sinal de x da propria malha; r_endireitar espelha).
    lado = bm.faces.layers.int.new("manga")
    bm.faces.ensure_lookup_table()
    visto = set()
    for f0 in bm.faces:
        if f0.index in visto:
            continue
        pilha = [f0]
        visto.add(f0.index)
        comp = []
        while pilha:
            f = pilha.pop()
            comp.append(f)
            for e in f.edges:
                for g in e.link_faces:
                    if g.index not in visto:
                        visto.add(g.index)
                        pilha.append(g)
        cs = np.array([tuple(f.calc_center_median()) for f in comp])
        # A peca e da manga se o centro dela cai no tubo de um lado (a manga
        # inteira, e as ilhas que o corte soltou em volta dela).
        c = cs.mean(0)
        for sinal, (m0, eixo, R) in TUBO.items():
            r = c - m0
            d = np.linalg.norm(r - (r @ eixo) * eixo)
            if d < R * 1.1 and (c[0] > 0) == (sinal > 0) and len(comp) < 0.3 * len(bm.faces)                     and MANGA_Z[0] - 0.12 < c[2] < MANGA_Z[1]:
                for f in comp:
                    f[lado] = sinal
                if len(comp) > 500:
                    print("[r_limpar] manga %+d: peca de %d faces, z %.3f..%.3f" % (sinal, len(comp), cs[:, 2].min(), cs[:, 2].max()))
                break
bm.to_mesh(ob.data)
bm.free()
bpy.ops.wm.save_as_mainfile(filepath=saida)
print("[r_limpar] ok", saida)
