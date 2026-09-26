"""Corpo de IA (glb do gerador, em pose T) -> corpo dos padres, no esqueleto do
`Corpo` do jogo, sem a cabeca (a cabeca e a `CabecaDoPadre`).

1. Solda a costura de UV (o import duplica o vertice em toda costura) e poe o
   corpo no quadro do jogo: olhando +Y no Blender (-Z no Godot), escala
   `escala` (a base do pescoco cai na do `Corpo` de 1,72 m).
2. Pesa a pele por calor (ARMATURE_AUTO) num esqueleto com os nomes e a
   hierarquia do `Corpo`, posto nas juntas DESTE corpo (medidas em
   `cfg_corpo.json`, na malha do gerador: Z para cima, frente -Y, o braco
   direito dele em +X).
3. Leva cada osso da junta do corpo para a junta do `Corpo` despejado
   (`padre.json`, repouso global do romeiro de 1,72 m): gira (o braco desce da
   pose T), estica ao longo do osso (so ate a junta de baixo; a mao e o pe vao
   rigidos) e translada. Os giros entram por quaternio duplo (o ombro nao
   murcha no giro de 90 graus); o estica entra linear.
4. O pescoco afina ate caber no pescoco da cabeca e e cortado dentro dela.
5. Exporta para o Godot (`gerar_corpo_aaa` monta o ArrayMesh): por vertice de
   desenho posicao, normal, tangente, UV, 4 ossos e 4 pesos (o indice e o do
   osso do `Corpo`, que e o da ligacao na Skin).

blender -b --python k_corpo.py -- <glb> <cfg.json> <padre.json> <saida_dir> [--dedos=dedos.json]
"""
import sys, os, json, math
import bpy, bmesh
import numpy as np
from mathutils import Vector, Matrix, Quaternion

a = sys.argv[sys.argv.index("--") + 1:]
DEDOS = next((x.split("=", 1)[1] for x in a if x.startswith("--dedos=")), None)
a = [x for x in a if not x.startswith("--")]
glb, cfg, padre, saida = a[0], json.load(open(a[1])), json.load(open(a[2])), a[3]
os.makedirs(saida, exist_ok=True)
S = cfg["escala"]
NOMES = [o["nome"] for o in padre["ossos"]]
PAIS = [o["pai"] for o in padre["ossos"]]
IDX = {n: i for i, n in enumerate(NOMES)}


def g2j(v):
    """Godot -> quadro do jogo no Blender (x, -z, y)."""
    return Vector((v[0], -v[2], v[1]))


def r2j(p, lado=1.0):
    """Malha do gerador -> quadro do jogo: gira 180 em Z e escala. `lado` +1 e o
    lado +X do jogo (o braco esquerdo do gerador, espelho da medida)."""
    return Vector((lado * abs(p[0]) * S if lado else -p[0] * S, -p[1] * S, p[2] * S))


# --- 1. importa, solda, quadro do jogo ---
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
ob = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
ob.name = "Corpo"
bpy.context.view_layer.objects.active = ob
ob.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bm = bmesh.new()
bm.from_mesh(ob.data)
antes = len(bm.verts)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
bm.transform(Matrix.Scale(S, 4) @ Matrix.Rotation(math.pi, 4, "Z"))
bm.to_mesh(ob.data)
bm.free()
print("[corpo] solda: %d -> %d vertices" % (antes, len(ob.data.vertices)))

# --- juntas: do corpo (j_*) e do Corpo do jogo (J_*) ---
def junta_corpo(nome, lado):
    return r2j(cfg[nome], lado)

ossos_jogo = {o["nome"]: g2j(o["o"]) for o in padre["ossos"]}
Y_PUNHO = 0.85 * padre["altura"] / 1.72
# Cada osso: (cabeca no corpo, fim do estica no corpo, rabo no corpo [para o calor],
#             cabeca no jogo, fim do estica no jogo)
chao = Vector((0, 0, 0))
OSSOS = {}
qc = Vector((0.0, -cfg["quadril"][1] * S, cfg["quadril"][2] * S))
tc = Vector((0.0, -cfg["quadril"][1] * S, cfg["base_torso_z"] * S))
pc = Vector((0.0, -cfg["pescoco_eixo_y"] * S, cfg["pescoco_z"] * S))
topo = Vector((0.0, -cfg["pescoco_eixo_y"] * S, cfg["topo_z"] * S))
OSSOS["quadril"] = (qc, tc, tc, ossos_jogo["quadril"], ossos_jogo["torso"])
OSSOS["torso"] = (tc, pc, pc, ossos_jogo["torso"], ossos_jogo["cabeca"])
OSSOS["cabeca"] = (pc, topo, topo, ossos_jogo["cabeca"], ossos_jogo["cabeca"] + (topo - pc))
for lado, suf in ((-1.0, "_e"), (1.0, "_d")):
    om, co_, pu, pm = (junta_corpo(k, lado) for k in ("ombro", "cotovelo", "punho", "ponta_mao"))
    # O braco nao fica no eixo do osso: o ombro do `Corpo` e largo (cabide) e
    # o braco centrado nele deixava o ombro reto; entra 1,5 cm no ombro e abre
    # para baixo (4 graus no braco, 6 no antebraco), e a mao pende fora da saia.
    bd = cfg["braco_desloca"]
    Jom = ossos_jogo["braco" + suf] + Vector((lado * bd["ombro"], 0.0, 0.0))
    Jco = ossos_jogo["antebraco" + suf] + Vector((lado * bd["cotovelo"], 0.0, 0.0))
    Jpu = Vector((ossos_jogo["antebraco" + suf].x + lado * bd["punho"], Jco.y, Y_PUNHO))
    OSSOS["braco" + suf] = (om, co_, co_, Jom, Jco)
    OSSOS["antebraco" + suf] = (co_, pu, pm, Jco, Jpu)
    qu, jo, to = (junta_corpo(k, lado) for k in ("quadril", "joelho", "tornozelo"))
    Jqu = ossos_jogo["coxa" + suf]
    Jjo = ossos_jogo["canela" + suf]
    # O pe fica no chao: o tornozelo do jogo e o do corpo na altura, sob o joelho.
    Jto = Vector((Jjo.x, Jjo.y, to.z))
    OSSOS["coxa" + suf] = (qu, jo, jo, Jqu, Jjo)
    OSSOS["canela" + suf] = (jo, to, Vector((to.x, to.y - 0.02, 0.01)), Jjo, Jto)

# --- 2. peso por calor ---
arm = bpy.data.armatures.new("Esqueleto")
aob = bpy.data.objects.new("Esqueleto", arm)
bpy.context.scene.collection.objects.link(aob)
bpy.context.view_layer.objects.active = aob
bpy.ops.object.mode_set(mode="EDIT")
eb = {}
for nome in NOMES:
    if nome not in OSSOS:
        continue
    h, _e, t, _H, _E = OSSOS[nome]
    b = arm.edit_bones.new(nome)
    b.head = h
    b.tail = t if (t - h).length > 1e-4 else h + Vector((0, 0, 0.05))
    eb[nome] = b
for nome, b in eb.items():
    p = PAIS[IDX[nome]]
    if p >= 0 and NOMES[p] in eb:
        b.parent = eb[NOMES[p]]
        b.use_connect = False
bpy.ops.object.mode_set(mode="OBJECT")
bpy.ops.object.select_all(action="DESELECT")
ob.select_set(True)
aob.select_set(True)
bpy.context.view_layer.objects.active = aob
bpy.ops.object.parent_set(type="ARMATURE_AUTO")
me = ob.data
n = len(me.vertices)
W = np.zeros((n, len(NOMES)))
gidx = {g.index: IDX[g.name] for g in ob.vertex_groups if g.name in IDX}
for v in me.vertices:
    for g in v.groups:
        if g.group in gidx:
            W[v.index, gidx[g.group]] = g.weight
soma = W.sum(1)
print("[corpo] calor: %d vertices sem peso" % int((soma < 1e-6).sum()))
# Vertice sem peso (peca solta que o calor nao alcanca): o osso mais perto.
co = np.empty(n * 3)
me.vertices.foreach_get("co", co)
co = co.reshape(n, 3)
if (soma < 1e-6).any():
    segs = [(IDX[k], np.array(v[0]), np.array(v[2])) for k, v in OSSOS.items()]
    for i in np.where(soma < 1e-6)[0]:
        best, bd = 0, 1e9
        for bi, h, t in segs:
            d = t - h
            u = np.clip(np.dot(co[i] - h, d) / max(np.dot(d, d), 1e-9), 0, 1)
            dist = np.linalg.norm(co[i] - (h + d * u))
            if dist < bd:
                best, bd = bi, dist
        W[i, best] = 1.0
# 4 ossos por vertice, normalizado.
ordem = np.argsort(-W, axis=1)[:, :4]
w4 = np.take_along_axis(W, ordem, 1)
w4 /= w4.sum(1, keepdims=True)
# So para descer o braco: a passagem tronco -> braco mais curta (o calor
# espalha o ombro e o giro de 90 graus fazia um gancho largo).
wr = w4.copy()
a0, a1 = cfg.get("afia_ombro", [0.0, 1.0])
braco = np.isin(ordem, [IDX["braco_e"], IDX["braco_d"]])
wb = np.where(braco, wr, 0.0).sum(1)
t_ = np.clip((wb - a0) / (a1 - a0), 0.0, 1.0)
wb2 = t_ * t_ * (3 - 2 * t_)
tem = (wb > 1e-6) & (wb < 1 - 1e-6)
fb = np.where(tem, wb2 / np.maximum(wb, 1e-9), 1.0)
fo = np.where(tem, (1 - wb2) / np.maximum(1 - wb, 1e-9), 1.0)
wr = np.where(braco, wr * fb[:, None], wr * fo[:, None])
wr /= wr.sum(1, keepdims=True)

# --- 3. leva cada osso para a junta do Corpo ---
def rot_de(a, b):
    a = a.normalized(); b = b.normalized()
    return a.rotation_difference(b)

transf = {}
for nome, (h, e, _t, H, E) in OSSOS.items():
    d_c = e - h
    d_j = E - H
    L = d_c.length
    k = d_j.length / L if L > 1e-6 and d_j.length > 1e-6 else 1.0
    q = rot_de(d_c, d_j) if L > 1e-6 and d_j.length > 1e-6 else Quaternion()
    transf[IDX[nome]] = (np.array(h), np.array(d_c.normalized()) if L > 1e-6 else np.zeros(3), L, k, q, np.array(H))
    print("[corpo] %-12s estica %.3f  giro %.1f graus" % (nome, k, math.degrees(q.angle)))
# estica (linear) no quadro do corpo
desl = np.zeros((n, 3))
for j in range(4):
    for bi in np.unique(ordem[:, j]):
        if bi not in transf:
            continue
        m = ordem[:, j] == bi
        h, ax, L, k, q, H = transf[bi]
        if abs(k - 1.0) < 1e-6:
            continue
        proj = np.clip((co[m] - h) @ ax, 0.0, L)
        desl[m] += wr[m, j:j + 1] * (ax[None, :] * (k - 1.0) * proj[:, None])
co1 = co + desl


# giro + translacao por quaternio duplo
def dq_de(q, h, H):
    # v' = q (v - h) q* + H  ->  translacao t = H - q h q*
    t = np.array(H) - np.array(q @ Vector(h))
    q0 = np.array([q.w, q.x, q.y, q.z])
    tq = np.array([0.0, *t])
    qe = 0.5 * qmul(tq, q0)
    return q0, qe


def qmul(a, b):
    w1, x1, y1, z1 = a
    w2, x2, y2, z2 = b
    return np.array([w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2, w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2,
                     w1 * y2 - x1 * z2 + y1 * w2 + z1 * x2, w1 * z2 + x1 * y2 - y1 * x2 + z1 * w2])


DQ = np.zeros((len(NOMES), 2, 4))
DQ[:, 0, 0] = 1.0
for bi, (h, ax, L, k, q, H) in transf.items():
    DQ[bi, 0], DQ[bi, 1] = dq_de(q, h, H)
b0 = np.zeros((n, 4))
be = np.zeros((n, 4))
piv = DQ[ordem[:, 0], 0]
for j in range(4):
    r = DQ[ordem[:, j], 0]
    e = DQ[ordem[:, j], 1]
    sgn = np.sign(np.sum(r * piv, 1))
    sgn[sgn == 0] = 1
    b0 += (wr[:, j] * sgn)[:, None] * r
    be += (wr[:, j] * sgn)[:, None] * e
nrm = np.linalg.norm(b0, axis=1, keepdims=True)
b0 /= nrm
be /= nrm
w_, x_, y_, z_ = b0.T
# rotaciona co1 pelo real, soma a translacao do dual: t = 2 * be * conj(b0)
R = np.stack([
    np.stack([1 - 2 * (y_ * y_ + z_ * z_), 2 * (x_ * y_ - w_ * z_), 2 * (x_ * z_ + w_ * y_)], 1),
    np.stack([2 * (x_ * y_ + w_ * z_), 1 - 2 * (x_ * x_ + z_ * z_), 2 * (y_ * z_ - w_ * x_)], 1),
    np.stack([2 * (x_ * z_ - w_ * y_), 2 * (y_ * z_ + w_ * x_), 1 - 2 * (x_ * x_ + y_ * y_)], 1)], 1)
conj = b0 * np.array([1, -1, -1, -1])
tq = np.array([qmul(be[i], conj[i]) for i in range(n)]) * 2.0
co2 = np.einsum("nij,nj->ni", R, co1) + tq[:, 1:]

# --- 4. pescoco: afina ate o pescoco da cabeca e corta dentro dela ---
za, zb = cfg["afina_z"][0] * S, cfg["afina_z"][1] * S
dz = ossos_jogo["cabeca"].z - cfg["pescoco_z"] * S
za += dz
zb += dz
zcorte = cfg["corte_z"] * S + dz
yc0 = -cfg["pescoco_eixo_y"] * S + (ossos_jogo["torso"].y - tc.y)
pf = cfg["pescoco_final"]
r0, r1 = cfg["afina_raio"][0] * S, cfg["afina_raio"][1] * S
dx = co2[:, 0]
dy = co2[:, 1] - yc0
rad = np.sqrt(dx * dx + dy * dy)


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


# A seccao natural do pescoco na altura do corte (meia largura em x e y).
faixa = (np.abs(co2[:, 2] - zb) < 0.004) & (rad < r0)
mx = max(np.abs(dx[faixa]).max(), 1e-3)
my_f = max((-dy[faixa]).max(), 1e-3)
my_t = max(dy[faixa].max(), 1e-3)
print("[corpo] pescoco no corte: meia largura %.3f, frente %.3f, tras %.3f" % (mx, my_f, my_t))
w = smooth(za, zb, co2[:, 2]) * (1.0 - smooth(r0, r1, rad))
fx = pf["meio"][0] / mx
fyf = pf["meio"][1] / my_f
fyt = pf["meio"][1] / my_t
fy = np.where(dy < 0, fyf, fyt)
yc1 = pf["centro_y"]
co3 = co2.copy()
co3[:, 0] = dx * (1 - w) + dx * fx * w
co3[:, 1] = (yc0 + dy) * (1 - w) + (yc1 + dy * fy) * w
# Limpa a dobra do giro (ombro) e do afinar (pescoco): Corrective Smooth
# preso na pose T, so onde o peso passa de um osso para outro no ombro e no
# pescoco afinado (mais tres aneis).
ob.modifiers.clear()
wbr = np.where(np.isin(ordem, [IDX["braco_e"], IDX["braco_d"]]), w4, 0.0).sum(1)
zona = ((wbr > 0.02) & (wbr < 0.98)) | (w > 0.01)
bmz = bmesh.new()
bmz.from_mesh(me)
bmz.verts.ensure_lookup_table()
for _ in range(cfg.get("suaviza_aneis", 3)):
    novo = zona.copy()
    for e in bmz.edges:
        i, j = e.verts[0].index, e.verts[1].index
        if zona[i] or zona[j]:
            novo[i] = novo[j] = True
    zona = novo
bmz.free()
gz = ob.vertex_groups.new(name="suaviza")
gz.add([int(i) for i in np.where(zona)[0]], 1.0, "REPLACE")
cs = ob.modifiers.new("Suaviza", "CORRECTIVE_SMOOTH")
cs.vertex_group = "suaviza"
cs.rest_source = "BIND"
cs.iterations = cfg.get("suaviza_voltas", 30)
cs.factor = 0.5
cs.smooth_type = "LENGTH_WEIGHTED"
cs.use_pin_boundary = False
bpy.ops.object.select_all(action="DESELECT")
ob.select_set(True)
bpy.context.view_layer.objects.active = ob
bpy.ops.object.correctivesmooth_bind(modifier="Suaviza")
me.vertices.foreach_set("co", co3.reshape(-1))
me.update()
bpy.ops.object.modifier_apply(modifier="Suaviza")
if "suaviza" in ob.vertex_groups:
    ob.vertex_groups.remove(ob.vertex_groups["suaviza"])
co3 = np.empty(n * 3)
me.vertices.foreach_get("co", co3)
co3 = co3.reshape(n, 3)
print("[corpo] suaviza: %d vertices" % int(zona.sum()))
bm = bmesh.new()
bm.from_mesh(me)
bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], dist=1e-5,
                             plane_co=(0, 0, zcorte), plane_no=(0, 0, 1), clear_outer=True)
borda = [e for e in bm.edges if e.is_boundary and all(abs(v.co.z - zcorte) < 1e-4 for v in e.verts)]
bmesh.ops.holes_fill(bm, edges=borda, sides=0)
bmesh.ops.triangulate(bm, faces=bm.faces[:])
# A mao: o decimador do gerador deixou triangulos compridos (ate 57 mm) nas
# paredes entre os dedos; dobrados (a garra, `k_dedos`) viram lascas. Divide as
# arestas da mao acima de 1 cm, duas voltas.
def na_mao(v):
    return abs(v.co.x) > MAO_X and v.co.z < MAO_Z
MAO_X, MAO_Z = cfg.get("mao_refina", [0.2, 0.775])
for volta in range(2):
    longas = [e for e in bm.edges if all(na_mao(v) for v in e.verts) and e.calc_length() > 0.010]
    if not longas:
        break
    bmesh.ops.subdivide_edges(bm, edges=longas, cuts=1, use_grid_fill=False)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 3])
bm.to_mesh(me)
bm.free()
me.update()
print("[corpo] corte em z=%.3f: %d vertices, %d triangulos" % (zcorte, len(me.vertices), len(me.polygons)))
# Os pesos seguem pelo vertice: o bisect cria vertices na linha do corte (pesos
# do vizinho mais perto).
from mathutils.kdtree import KDTree
kd = KDTree(n)
for i in range(n):
    kd.insert(co3[i], i)
kd.balance()
n2 = len(me.vertices)
co4 = np.empty(n2 * 3)
me.vertices.foreach_get("co", co4)
co4 = co4.reshape(n2, 3)
origem = np.array([kd.find(co4[i])[1] for i in range(n2)])
ordem2 = ordem[origem]
w42 = w4[origem]

# --- colisores do pano, medidos no corpo pronto ---
# (quadro do jogo no Blender; saem no Godot, no espaco de cada osso)
dom = ordem2[:, 0]
wdom = w42[:, 0]


def seg_dist(P, a, b):
    ab = b - a
    t = np.clip(((P - a) @ ab) / max(ab @ ab, 1e-9), 0.0, 1.0)
    return np.linalg.norm(P - (a + t[:, None] * ab), axis=1), t


def j2g(p):
    return [float(p[0]), float(p[2]), float(-p[1])]


colis = []   # [osso, a (global Godot), b, raio]
for lado, suf in ((-1.0, "_e"), (1.0, "_d")):
    _h, _e, _t, Jom, Jco = OSSOS["braco" + suf]
    _h2, _e2, _t2, _Jc, Jpu = OSSOS["antebraco" + suf]
    Jom, Jco, Jpu = np.array(Jom), np.array(Jco), np.array(Jpu)
    m = (dom == IDX["braco" + suf]) & (wdom > 0.6)
    d, t = seg_dist(co4[m], Jom, Jco)
    rb = float(np.percentile(d[(t > 0.15) & (t < 0.95)], 75))
    m = (dom == IDX["antebraco" + suf]) & (wdom > 0.6)
    d, t = seg_dist(co4[m], Jco, Jpu)
    dentro = (t > 0.02) & (t < 0.98)
    ra = float(np.percentile(d[dentro], 75))
    # a mao: do punho ate a ponta mais longe no eixo do antebraco
    eixo = (Jpu - Jco) / np.linalg.norm(Jpu - Jco)
    proj = (co4[m] - Jpu) @ eixo
    alem = proj > 0
    ponta = Jpu + eixo * float(proj[alem].max())
    dm, _ = seg_dist(co4[m][alem], Jpu, ponta)
    rm = float(np.percentile(dm, 60))
    colis.append([IDX["braco" + suf], j2g(Jom), j2g(Jco), rb])
    colis.append([IDX["antebraco" + suf], j2g(Jco), j2g(Jpu), ra])
    colis.append([IDX["antebraco" + suf], j2g(Jpu), j2g(ponta - eixo * rm), rm])
    for osso, fim in (("coxa", "canela"), ("canela", None)):
        a0 = np.array(ossos_jogo[osso + suf])
        b0 = np.array(ossos_jogo[fim + suf]) if fim else np.array([a0[0], a0[1], 0.07 * padre["altura"] / 1.72])
        m = (dom == IDX[osso + suf]) & (wdom > 0.6)
        d, t = seg_dist(co4[m], a0, b0)
        r = float(np.percentile(d[(t > 0.1) & (t < 0.9)], 70))
        colis.append([IDX[osso + suf], j2g(a0), j2g(b0), r])
# tronco: capsulas deitadas (em x) nas alturas do peito, da barriga e do quadril
bracos = [IDX[k] for k in ("braco_e", "braco_d", "antebraco_e", "antebraco_d")]
tronco = ~np.isin(dom, bracos) & (np.abs(co4[:, 0]) < 0.2)
for zg, osso in ((1.26, "torso"), (1.10, "torso"), (0.95, "quadril")):
    zb = zg * padre["altura"] / 1.72
    m = tronco & (np.abs(co4[:, 2] - zb) < 0.012)
    P = co4[m]
    X = float(np.percentile(np.abs(P[:, 0]), 98))
    yf = float(P[:, 1].max())    # frente (+y no Blender)
    yt = float(P[:, 1].min())
    r = 0.5 * (yf - yt)
    yc = 0.5 * (yf + yt)
    lx = max(X - r, 0.01)
    colis.append([IDX[osso], j2g((-lx, yc, zb)), j2g((lx, yc, zb)), r])
for c in colis:
    print("[corpo] colisor %-12s r=%.3f  a=%s b=%s" % (NOMES[c[0]], c[3], np.round(c[1], 3), np.round(c[2], 3)))

# Guarda o .blend (com o esqueleto no repouso do jogo): as fotos de pose e o
# `k_dedos` (os indices das formas dos dedos sao os vertices daqui, sem elas).
ob.parent = None
ob.modifiers.clear()
for g in list(ob.vertex_groups):
    ob.vertex_groups.remove(g)
bpy.data.objects.remove(aob)
arm2 = bpy.data.armatures.new("Jogo")
aob2 = bpy.data.objects.new("Jogo", arm2)
bpy.context.scene.collection.objects.link(aob2)
bpy.context.view_layer.objects.active = aob2
bpy.ops.object.mode_set(mode="EDIT")
eb2 = {}
for i, nome in enumerate(NOMES):
    b = arm2.edit_bones.new(nome)
    b.head = ossos_jogo[nome]
    filhos = [ossos_jogo[NOMES[j]] for j in range(len(NOMES)) if PAIS[j] == i and NOMES[j] in OSSOS]
    if nome.startswith("antebraco"):
        b.tail = Vector((b.head.x, b.head.y, Y_PUNHO))
    elif nome.startswith("canela"):
        b.tail = Vector((b.head.x, b.head.y, 0.07))
    elif nome == "cabeca":
        b.tail = b.head + Vector((0, 0, 0.25))
    elif nome == "torso":
        b.tail = ossos_jogo["cabeca"]
    elif filhos and nome != "quadril":
        b.tail = filhos[0]
    else:
        b.tail = b.head + Vector((0, 0, 0.06 if nome == "quadril" else 0.1))
    eb2[nome] = b
for i, nome in enumerate(NOMES):
    if PAIS[i] >= 0:
        eb2[nome].parent = eb2[NOMES[PAIS[i]]]
bpy.ops.object.mode_set(mode="OBJECT")
grupos = [ob.vertex_groups.new(name=nm) for nm in NOMES]
for vi in range(n2):
    for j in range(4):
        if w42[vi, j] > 0:
            grupos[ordem2[vi, j]].add([vi], float(w42[vi, j]), "REPLACE")
md = ob.modifiers.new("Esqueleto", "ARMATURE")
md.object = aob2
md.use_deform_preserve_volume = False
ob.parent = aob2
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(saida, "corpo_jogo.blend"))
print("[corpo] corpo_jogo.blend: %d vertices (os indices do `k_dedos`)" % n2)

# --- 5. os dedos (`k_dedos`): o repouso relaxado vai assado na malha; garra e
# aberta viram formas (posicao e normal de alvo), uma por lado ---
FORMAS = ["garra_e", "garra_d", "aberta_e", "aberta_d"]
formas_pos = {}
formas_nor = {}
if DEDOS:
    dd = json.load(open(DEDOS))["formas"]
    base = np.empty(n2 * 3)
    me.vertices.foreach_get("co", base)
    base = base.reshape(n2, 3)
    idx = np.array(dd["relaxa"]["idx"], dtype=int)
    assert idx.max() < n2, "dedos.json de outra malha (%d >= %d vertices)" % (idx.max(), n2)
    base[idx] += np.array(dd["relaxa"]["d"])
    for nome in FORMAS:
        alvo = base.copy()
        ix = np.array(dd[nome]["idx"], dtype=int)
        alvo[ix] += np.array(dd[nome]["d"])
        me.vertices.foreach_set("co", alvo.reshape(-1))
        me.update()
        nr = np.empty(n2 * 3)
        me.vertices.foreach_get("normal", nr)
        formas_pos[nome] = alvo
        formas_nor[nome] = nr.reshape(n2, 3)
    me.vertices.foreach_set("co", base.reshape(-1))
    me.update()
    print("[corpo] dedos: relaxa assada (%d vertices), formas %s" % (len(idx), FORMAS))

# --- 6. exporta ---
me.calc_tangents()
uvl = me.uv_layers.active.data
chave = {}
vpos, vnor, vtan, vuv, vb, vw, vvi = [], [], [], [], [], [], []
ind = []
for poly in me.polygons:
    for li in poly.loop_indices:
        lo = me.loops[li]
        vi = lo.vertex_index
        uv = uvl[li].uv
        k = (vi, round(uv.x, 5), round(uv.y, 5))
        idx = chave.get(k)
        if idx is None:
            idx = len(vpos)
            chave[k] = idx
            c = me.vertices[vi].co
            nn = me.vertices[vi].normal
            t = lo.tangent
            vpos.append((c.x, c.z, -c.y))
            vnor.append((nn.x, nn.z, -nn.y))
            vtan.append((t.x, t.z, -t.y, lo.bitangent_sign))
            vuv.append((uv.x, 1.0 - uv.y))
            vb.append(ordem2[vi])
            vw.append(w42[vi])
            vvi.append(vi)
        ind.append(idx)
vpos = np.array(vpos, dtype=np.float32)
tri = np.array(ind, dtype=np.uint32).reshape(-1, 3)[:, [0, 2, 1]]
f32 = np.float32
blocos = [
    ("pos", vpos),
    ("nor", np.array(vnor, dtype=f32)),
    ("tan", np.array(vtan, dtype=f32)),
    ("uv", np.array(vuv, dtype=f32)),
    ("ossos", np.array(vb, dtype=f32)),
    ("pesos", np.array(vw, dtype=f32)),
]
vvi = np.array(vvi, dtype=int)
for nome in formas_pos:
    P = formas_pos[nome][vvi]
    N = formas_nor[nome][vvi]
    blocos.append(("forma_%s_pos" % nome, np.stack([P[:, 0], P[:, 2], -P[:, 1]], 1).astype(f32)))
    blocos.append(("forma_%s_nor" % nome, np.stack([N[:, 0], N[:, 2], -N[:, 1]], 1).astype(f32)))
cab = {"vertices": int(len(vpos)), "triangulos": int(len(tri)), "blocos": [], "ossos": NOMES,
       "repouso": [j2g(ossos_jogo[nm]) for nm in NOMES], "altura_ref": padre["altura"],
       "colisores": colis, "formas": list(formas_pos.keys())}
with open(os.path.join(saida, "corpo_aaa.bin"), "wb") as fb:
    off = 0
    for nome, arr in blocos:
        b = np.ascontiguousarray(arr).tobytes()
        cab["blocos"].append({"nome": nome, "offset": off, "comps": int(arr.shape[1])})
        fb.write(b)
        off += len(b)
    b = np.ascontiguousarray(tri.reshape(-1)).tobytes()
    cab["blocos"].append({"nome": "indices", "offset": off, "comps": 1})
    fb.write(b)
json.dump(cab, open(os.path.join(saida, "corpo_aaa.json"), "w"), indent=1)
pc_ = dict(padre)
pc_["colisores"] = [{"osso": c[0], "a": c[1], "b": c[2], "r": c[3]} for c in colis] +     [c for c in padre["colisores"] if c["osso"] == IDX["cabeca"]]
json.dump(pc_, open(os.path.join(saida, "padre_corpo.json"), "w"), indent=1)
print("[corpo] exportado: %d vertices de desenho, %d triangulos" % (len(vpos), len(tri)))
print("[corpo] caixa (Godot)", vpos.min(0).round(3), vpos.max(0).round(3))

print("[corpo] ok", saida)
