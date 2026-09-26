"""Prende cada vertice da batina AAA nas grades do pano (`grades.json`) e
exporta a malha para o Godot (`gerar_batina_aaa` monta o ArrayMesh).

Por vertice de desenho (vertice x UV x normal), em coordenada do Godot:
- a grade A mais perto (capuz 0, murca 1, batina 2), a coordenada de grade gA
  (coluna, linha; o ponto mais perto na superficie Catmull-Rom da grade) e o
  desvio oA no referencial local da grade ali (T, B, N);
- onde duas grades passam juntas (a gola, as costas onde murca e capa sao uma
  camada so), a segunda grade B, gB, oB e o peso wB: o vertice fica entre as
  duas, e a costura nao abre quando elas se mexem diferente;
- a normal e a tangente no referencial de A.

A superficie e o referencial sao os mesmos do shader (`BatinaAAA`):
S(g) = Catmull-Rom nas particulas (linhas presas nas pontas, colunas em volta),
dS/dgx e dS/dgy pelas derivadas dos pesos, N = normalize(dS/dgx x dS/dgy),
T = normalize(dS/dgx - N (N . dS/dgx)), B = N x T.

blender -b reto.blend --python r_ligar.py -- <grades.json> <rotulos.json> <saida_dir>

A grade de cada vertice e o rotulo da face dele (`r_grades`: qual camada os
raios de ajuste acharam ali). Face sem rotulo (um farrapo solto) vai na grade
mais perto. Nao ha mistura entre camadas: a murca deitada no peito e a
batina logo abaixo encostam, mas cada uma balanca com a sua grade.
Sai `batina_aaa.bin` (arrays float32/uint32 em sequencia) e `batina_aaa.json`
(contagens e ordem).
"""
import sys, os, json
import bpy, bmesh
import numpy as np
from mathutils import Vector
from mathutils.kdtree import KDTree

a = sys.argv[sys.argv.index("--") + 1:]
grades = json.load(open(a[0]))
rotulos = json.load(open(a[1]))
saida = a[2]
os.makedirs(saida, exist_ok=True)
AMOSTRA = 8          # amostras por celula na busca inicial
NEWTON = 8


def pesos(t):
    t2 = t * t
    t3 = t2 * t
    return np.stack([-0.5 * t3 + t2 - 0.5 * t, 1.5 * t3 - 2.5 * t2 + 1.0,
                     -1.5 * t3 + 2.0 * t2 + 0.5 * t, 0.5 * t3 - 0.5 * t2], axis=1)


def dpesos(t):
    t2 = t * t
    return np.stack([-1.5 * t2 + 2.0 * t - 0.5, 4.5 * t2 - 5.0 * t,
                     -4.5 * t2 + 4.0 * t + 0.5, 1.5 * t2 - t], axis=1)


def avaliar(P, g):
    """S, dS/dgx, dS/dgy na grade P (H, W, 3) nas coordenadas g (n, 2)."""
    H, W = P.shape[:2]
    gx = np.mod(g[:, 0], W)
    gy = np.clip(g[:, 1], 0.0, H - 1.0)
    bx = np.floor(gx).astype(int)
    by = np.floor(gy).astype(int)
    fx = gx - bx
    fy = gy - by
    wx, wy, dx, dy = pesos(fx), pesos(fy), dpesos(fx), dpesos(fy)
    S = np.zeros((len(g), 3))
    Du = np.zeros((len(g), 3))
    Dv = np.zeros((len(g), 3))
    for j in range(4):
        lin = np.clip(by + j - 1, 0, H - 1)
        for i in range(4):
            col = np.mod(bx + i - 1, W)
            Pij = P[lin, col]
            S += (wy[:, j] * wx[:, i])[:, None] * Pij
            Du += (wy[:, j] * dx[:, i])[:, None] * Pij
            Dv += (dy[:, j] * wx[:, i])[:, None] * Pij
    return S, Du, Dv


def referencial(Du, Dv):
    N = np.cross(Du, Dv)
    N /= np.maximum(np.linalg.norm(N, axis=1), 1e-12)[:, None]
    T = Du - N * np.sum(N * Du, axis=1)[:, None]
    T /= np.maximum(np.linalg.norm(T, axis=1), 1e-12)[:, None]
    B = np.cross(N, T)
    return T, B, N


def mais_perto(P, pts):
    """Coordenada de grade do ponto mais perto de cada ponto em pts."""
    H, W = P.shape[:2]
    us = np.arange(0, W, 1.0 / AMOSTRA)
    vs = np.arange(0, H - 1 + 1e-6, 1.0 / AMOSTRA)
    gu, gv = np.meshgrid(us, vs)
    g0 = np.stack([gu.ravel(), gv.ravel()], axis=1)
    S0, _, _ = avaliar(P, g0)
    kd = KDTree(len(S0))
    for k, s in enumerate(S0):
        kd.insert(Vector(s), k)
    kd.balance()
    g = np.array([g0[kd.find(Vector(p))[1]] for p in pts])
    for _ in range(NEWTON):
        S, Du, Dv = avaliar(P, g)
        r = S - pts
        a11 = np.sum(Du * Du, 1)
        a12 = np.sum(Du * Dv, 1)
        a22 = np.sum(Dv * Dv, 1)
        b1 = np.sum(Du * r, 1)
        b2 = np.sum(Dv * r, 1)
        det = a11 * a22 - a12 * a12
        ok = np.abs(det) > 1e-14
        d1 = np.where(ok, (a22 * b1 - a12 * b2) / np.where(ok, det, 1), 0)
        d2 = np.where(ok, (a11 * b2 - a12 * b1) / np.where(ok, det, 1), 0)
        # passo limitado a meia celula: Newton longe do minimo pula
        d1 = np.clip(d1, -0.5, 0.5)
        d2 = np.clip(d2, -0.5, 0.5)
        g = g - np.stack([d1, d2], 1)
        g[:, 0] = np.mod(g[:, 0], W)
        g[:, 1] = np.clip(g[:, 1], 0.0, H - 1.0)
    S, Du, Dv = avaliar(P, g)
    return g, S, Du, Dv


# --- a malha de desenho, em coordenada do Godot ---
ob = bpy.data.objects["Batina"]
me = ob.data
bmt = bmesh.new()
bmt.from_mesh(me)
bmesh.ops.triangulate(bmt, faces=[f for f in bmt.faces if len(f.verts) > 3])
bmt.to_mesh(me)
bmt.free()
me.calc_tangents()
uvl = me.uv_layers.active.data
# O remendo dos tampos (`r_limpar`, `r_ao`): rgb = 0,5 + a diferenca de cor / 2,
# alfa = a AO. Fora dos tampos, (0,5, 0,5, 0,5, 1).
rem = me.attributes.get("remendo")
chave_vert = {}
vpos, vnor, vtan, vuv, vrot, vcor = [], [], [], [], [], []
indices = []
for poly in me.polygons:
    assert poly.loop_total == 3, "triangule antes"
    for li in poly.loop_indices:
        lo = me.loops[li]
        co = me.vertices[lo.vertex_index].co
        n = lo.normal
        t = lo.tangent
        uv = uvl[li].uv
        k = (lo.vertex_index, round(uv.x, 5), round(uv.y, 5), round(n.x, 3), round(n.y, 3), round(n.z, 3))
        idx = chave_vert.get(k)
        if idx is None:
            idx = len(vpos)
            chave_vert[k] = idx
            vpos.append((co.x, co.z, -co.y))
            vnor.append((n.x, n.z, -n.y))
            vtan.append((t.x, t.z, -t.y, lo.bitangent_sign))
            vuv.append((uv.x, 1.0 - uv.y))
            vrot.append(rotulos[poly.index])
            vcor.append(tuple(rem.data[lo.vertex_index].color) if rem is not None else (0.5, 0.5, 0.5, 1.0))
        indices.append(idx)
vpos = np.array(vpos)
vnor = np.array(vnor)
vtan = np.array(vtan)
vuv = np.array(vuv)
# O Blender da o triangulo anti-horario visto de fora; o Godot desenha de fora
# o horario (ver memoria duas-armadilhas-mudas-do-godot): inverte a ordem.
tri = np.array(indices, dtype=np.uint32).reshape(-1, 3)[:, [0, 2, 1]]
n = len(vpos)
print("[ligar] vertices de desenho", n, "triangulos", len(tri))

# --- prende em cada grade ---
P = []
for pc in grades["pecas"]:
    P.append(np.array(pc["liga"]).reshape(pc["h"], pc["w"], 3))
res = []
for k, Pk in enumerate(P):
    g, S, Du, Dv = mais_perto(Pk, vpos)
    d = np.linalg.norm(vpos - S, axis=1)
    res.append((g, S, Du, Dv, d))
    print("[ligar] grade %s: distancia media %.4f, p95 %.4f" % (grades["pecas"][k]["nome"], d.mean(), np.percentile(d, 95)))
dist = np.stack([r[4] for r in res], 1)
vrot = np.array(vrot)
idA = np.where(vrot >= 0, vrot, np.argmin(dist, 1))
print("[ligar] sem rotulo (grade mais perto): %d vertices" % int((vrot < 0).sum()))
idB = idA.copy()
wB = np.zeros(n)


def local(ids):
    g = np.zeros((n, 2))
    o = np.zeros((n, 3))
    T = np.zeros((n, 3))
    B = np.zeros((n, 3))
    N = np.zeros((n, 3))
    for k in range(len(P)):
        m = ids == k
        gk, S, Du, Dv, _ = res[k]
        Tk, Bk, Nk = referencial(Du[m], Dv[m])
        dd = vpos[m] - S[m]
        g[m] = gk[m]
        o[m] = np.stack([np.sum(dd * Tk, 1), np.sum(dd * Bk, 1), np.sum(dd * Nk, 1)], 1)
        T[m], B[m], N[m] = Tk, Bk, Nk
    return g, o, T, B, N


gA, oA, TA, BA, NA = local(idA)
# A area da grade A em cada vertice (|dS/dgx x dS/dgy| na ligacao): o shader
# compara com a de agora e, onde o pano amassa muito, recolhe o desvio (a
# grade dobrada girava o referencial e o desvio virava espeto).
areaA = np.zeros(n)
for k in range(len(P)):
    m = idA == k
    _gk, _S, Du, Dv, _d = res[k]
    areaA[m] = np.linalg.norm(np.cross(Du[m], Dv[m]), axis=1)
gB, oB, _, _, _ = local(idB)
nl = np.stack([np.sum(vnor * TA, 1), np.sum(vnor * BA, 1), np.sum(vnor * NA, 1)], 1)
tl = np.stack([np.sum(vtan[:, :3] * TA, 1), np.sum(vtan[:, :3] * BA, 1), np.sum(vtan[:, :3] * NA, 1)], 1)
nl /= np.maximum(np.linalg.norm(nl, axis=1), 1e-9)[:, None]
tl /= np.maximum(np.linalg.norm(tl, axis=1), 1e-9)[:, None]
for k, pc in enumerate(grades["pecas"]):
    print("[ligar] %s: %d vertices (A), %d misturados com ela (B)" % (
        pc["nome"], int((idA == k).sum()), int(((idB == k) & (wB > 0)).sum())))
print("[ligar] desvio |oA|: media %.4f max %.4f" % (np.linalg.norm(oA, axis=1).mean(), np.linalg.norm(oA, axis=1).max()))

# --- confere: remontar pela grade tem de devolver a malha ---
def remontar(ids, g, o):
    r = np.zeros((n, 3))
    for k in range(len(P)):
        m = ids == k
        S, Du, Dv = avaliar(P[k], g[m])
        T, B, N = referencial(Du, Dv)
        r[m] = S + T * o[m, 0:1] + B * o[m, 1:2] + N * o[m, 2:3]
    return r
rA = remontar(idA, gA, oA)
rB = remontar(idB, gB, oB)
r = rA * (1 - wB)[:, None] + rB * wB[:, None]
err = np.linalg.norm(r - vpos, axis=1)
print("[ligar] remontado: erro max %.6f m, medio %.7f" % (err.max(), err.mean()))

# --- grava ---
f32 = np.float32
blocos = [
    ("pos", vpos.astype(f32)),
    ("nor_local", nl.astype(f32)),
    ("tan_local", np.concatenate([tl, vtan[:, 3:4]], 1).astype(f32)),
    ("uv", vuv.astype(f32)),
    ("ga", gA.astype(f32)),
    ("oa", np.concatenate([oA, idA[:, None]], 1).astype(f32)),
    ("gb", np.concatenate([gB, wB[:, None], idB[:, None]], 1).astype(f32)),
    ("ob", np.concatenate([oB, areaA[:, None]], 1).astype(f32)),
    ("cor", np.array(vcor).astype(f32)),
]
# A densidade da UV do gerador em metros (a pessoa de referencia): o shader
# poe a trama de la por cima nesse tamanho real.
ta, tb, tc = vpos[tri[:, 0]], vpos[tri[:, 1]], vpos[tri[:, 2]]
ua, ub, uc = vuv[tri[:, 0]], vuv[tri[:, 1]], vuv[tri[:, 2]]
a3 = np.linalg.norm(np.cross(tb - ta, tc - ta), axis=1) * 0.5
auv = np.abs((ub[:, 0] - ua[:, 0]) * (uc[:, 1] - ua[:, 1]) - (uc[:, 0] - ua[:, 0]) * (ub[:, 1] - ua[:, 1])) * 0.5
ok = (a3 > 1e-9) & (auv > 1e-12) & (ua[:, 0] < 1.5)
uv_por_metro = float(np.median(np.sqrt(auv[ok] / a3[ok])))
print("[ligar] UV por metro: %.3f" % uv_por_metro)
cab = {"vertices": n, "triangulos": int(len(tri)), "blocos": [], "grades": [p["nome"] for p in grades["pecas"]],
       "uv_por_metro": uv_por_metro}
with open(os.path.join(saida, "batina_aaa.bin"), "wb") as fb:
    off = 0
    for nome, arr in blocos:
        b = np.ascontiguousarray(arr).tobytes()
        cab["blocos"].append({"nome": nome, "offset": off, "comps": int(arr.shape[1]), "tipo": "f32"})
        fb.write(b)
        off += len(b)
    b = np.ascontiguousarray(tri.reshape(-1)).astype(np.uint32).tobytes()
    cab["blocos"].append({"nome": "indices", "offset": off, "comps": 1, "tipo": "u32"})
    fb.write(b)
json.dump(cab, open(os.path.join(saida, "batina_aaa.json"), "w"), indent=1)
print("[ligar] ok")

# --- estatistica do desvio por grade (o tangencial e o que gira com o pano) ---
for k, pc in enumerate(grades["pecas"]):
    m = idA == k
    if not m.any():
        continue
    tang = np.linalg.norm(oA[m, :2], axis=1)
    nor = np.abs(oA[m, 2])
    print("[ligar] %s desvio tangencial p50 %.4f p95 %.4f max %.4f | normal p50 %.4f p95 %.4f max %.4f | gy max %.2f de %d" % (
        pc["nome"], np.percentile(tang, 50), np.percentile(tang, 95), tang.max(),
        np.percentile(nor, 50), np.percentile(nor, 95), nor.max(), gA[m, 1].max(), pc["h"] - 1))
