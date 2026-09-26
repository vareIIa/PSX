"""Madeira, titulo INRI, cravos, olhal e argola do crucifixo: malhas ALTA e BAIXA.

blender -b corpo_alto.blend --python c_cruz.py -- <saida.blend>

Referencial de construcao (Blender): topo da haste em z=0, haste ate z=-0,16,
trave com eixo em z=-0,0448 (28% da altura), frente da madeira em y=-0,0045,
corpo olhando -Y. A origem final (centro do furo da argola) fica em
ORIGEM_Z e e aplicada na exportacao.

Objetos novos: alta_haste, alta_trave, alta_titulo, alta_letras, alta_cravos,
alta_olhal, alta_argola; baixa_haste, baixa_trave, baixa_titulo, baixa_cravos,
baixa_olhal, baixa_argola.
"""
import sys, os, math, random, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
import numpy as np
from mathutils import Vector, Matrix, noise
from mathutils.bvhtree import BVHTree
from c_comum import *

argv = sys.argv[sys.argv.index("--") + 1:]
SAIDA_BLEND = argv[0]
random.seed(11)
H = 0.160            # altura total da haste
Z_TRAVE = -0.0448    # eixo da trave (28% de H a partir do topo)
L_TRAVE = 0.095
LARG = 0.014         # largura das pecas
PROF = 0.009         # profundidade
Y0 = -PROF / 2       # frente da madeira
RESSALTO = 0.0002    # a trave fica 0,2 mm a frente da haste (junta a meia-madeira)

# olhal (parafuso de olho) no topo e argola que o atravessa
OLHAL_R, OLHAL_F = 0.0017, 0.00055          # raio da linha de centro, raio do fio
ARGOLA_R, ARGOLA_F = 0.0042, 0.0008
Z_OLHAL = OLHAL_R + OLHAL_F + 0.0001
Z_ARGOLA = Z_OLHAL + (OLHAL_R - OLHAL_F) - ARGOLA_F + ARGOLA_R   # o fio da argola apoia no alto do furo do olhal
ORIGEM_Z = Z_ARGOLA


def caixa(nome, cx, cy, cz, sx, sy, sz, chanfro, seg):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(sx, sy, sz), verts=bm.verts)
    bmesh.ops.translate(bm, vec=(cx, cy, cz), verts=bm.verts)
    bmesh.ops.bevel(bm, geom=bm.edges[:] + bm.verts[:], offset=chanfro, segments=seg, profile=0.5,
                    affect="EDGES")
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    return ligar(bpy.data.objects.new(nome, me))


def cortes(ob, eixo, a, b, passo):
    """Cortes transversais regulares (para a silhueta gasta seguir a alta)."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    n = int(round((b - a) / passo))
    for k in range(1, n):
        c = a + (b - a) * k / n
        co = [0, 0, 0]
        co[eixo] = c
        no = [0, 0, 0]
        no[eixo] = 1
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=no)
    bm.to_mesh(ob.data)
    bm.free()


def ruido(P, esc, oct=3, sem=0.0):
    return np.array([noise.fractal(Vector((p[0] * esc + sem, p[1] * esc, p[2] * esc)), 0.6, 2.0, oct) for p in P])


def madeira_gasta(ob, cx, cy, hx, hy, z0, z1, eixo_long, sem):
    """Desloca a malha densa da peca: quinas comidas, amassados e rachas ao longo do veio."""
    co = co_de(ob)
    nv = normais_de(ob)
    # distancias as faces no referencial da peca (u = transversal larga, w = profundidade, l = comprimento)
    if eixo_long == 2:
        u, l = co[:, 0] - cx, co[:, 2]
    else:
        u, l = co[:, 2] - cx, co[:, 0]
    w = co[:, 1] - cy
    dists = np.stack([hx - np.abs(u), hy - np.abs(w), l - z0, z1 - l], 1)
    dists.sort(1)
    d_quina = dists[:, 1]
    n1 = ruido(co, 130.0, 2, sem)           # zonas de desgaste ao longo da quina (~8 mm)
    n2 = ruido(co, 700.0, 1, sem + 7)       # lascas
    n3 = ruido(co, 60.0, 1, sem + 3)        # empeno leve das faces
    quina = np.clip(1 - d_quina / 0.0018, 0, 1) ** 2
    gasto = np.clip((n1 + 0.15) / 0.6, 0, 1) ** 2
    lasca = np.clip((n2 - 0.35) / 0.2, 0, 1) * np.clip(1 - d_quina / 0.0009, 0, 1)
    d = -quina * (0.00012 + 0.00042 * gasto) - 0.00030 * lasca + 0.00005 * n3
    # amassados
    for k in range(26):
        p = np.array([random.uniform(-1, 1), random.uniform(-1, 1), random.uniform(0, 1)])
        if eixo_long == 2:
            c = np.array([cx + p[0] * hx, cy + p[1] * hy, z0 + (z1 - z0) * p[2]])
        else:
            c = np.array([z0 + (z1 - z0) * p[2], cy + p[1] * hy, cx + p[0] * hx])
        r = random.uniform(0.0004, 0.0012)
        dist = np.linalg.norm(co - c, axis=1)
        d -= random.uniform(0.00008, 0.00025) * np.exp(-(dist / r) ** 2)
    # rachas finas ao longo do veio (na frente e nos lados)
    for k in range(5):
        u0 = random.uniform(-0.75, 0.75) * hx
        la = z0 + (z1 - z0) * random.uniform(0.0, 0.5)
        lb = la + (z1 - z0) * random.uniform(0.25, 0.6)
        onda = 0.00025 * np.sin(l * random.uniform(120, 260) + k)
        na_frente = np.abs(w + hy) < 0.0006 if k % 2 == 0 else np.abs(w - hy) < 0.0006
        m = np.exp(-((u - u0 - onda) / 0.00009) ** 2) * np.clip((l - la) / 0.006, 0, 1) * np.clip((lb - l) / 0.006, 0, 1)
        d -= 0.00030 * m * na_frente
    co += nv * d[:, None]
    por_co(ob, co)


# ------------------------------------------------------------- madeira ALTA
haste = caixa("alta_haste", 0, 0, -H / 2, LARG, PROF, H, 0.0009, 3)
trave = caixa("alta_trave", 0, -RESSALTO, Z_TRAVE, L_TRAVE, PROF, LARG, 0.0009, 3)
for ob in (haste, trave):
    remesh(ob, 0.00016)
print("[cruz] haste", len(haste.data.vertices), "trave", len(trave.data.vertices))
madeira_gasta(haste, 0.0, 0.0, LARG / 2, PROF / 2, -H, 0.0, 2, 3.1)
madeira_gasta(trave, Z_TRAVE, -RESSALTO, LARG / 2, PROF / 2, -L_TRAVE / 2, L_TRAVE / 2, 0, 9.7)
for ob in (haste, trave):
    suave(ob)

# ------------------------------------------------------------- madeira BAIXA
bh = caixa("baixa_haste", 0, 0, -H / 2, LARG, PROF, H, 0.0009, 2)
bt = caixa("baixa_trave", 0, -RESSALTO, Z_TRAVE, L_TRAVE, PROF, LARG, 0.0009, 2)
cortes(bh, 2, -H + 0.001, -0.001, 0.010)
cortes(bt, 0, -L_TRAVE / 2 + 0.001, L_TRAVE / 2 - 0.001, 0.010)
for b, a in ((bh, haste), (bt, trave)):
    sw = b.modifiers.new("sw", "SHRINKWRAP")
    sw.target = a
    sw.wrap_method = "NEAREST_SURFACEPOINT"
    aplicar(b)
    suave(b)
    # bordas vivas no chanfro: normal por angulo
    b.data.set_sharp_from_angle(angle=math.radians(50))

# --------------------------------------------------------------- titulo INRI
TIT_W, TIT_H, TIT_T = 0.0215, 0.0088, 0.0011
TIT_Z = -0.0270
tit_y = Y0 - TIT_T / 2
titulo = caixa("alta_titulo", 0, tit_y, TIT_Z, TIT_W, TIT_T, TIT_H, 0.00028, 3)
rolos = []
for s in (-1, 1):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=24, radius1=0.00085, radius2=0.00085, depth=TIT_H + 0.0006)
    bmesh.ops.translate(bm, vec=(s * (TIT_W / 2 + 0.0002), tit_y + 0.0002, TIT_Z), verts=bm.verts)
    me = bpy.data.meshes.new("rolo")
    bm.to_mesh(me)
    bm.free()
    rolos.append(ligar(bpy.data.objects.new("rolo", me)))
titulo = juntar([titulo] + rolos, "alta_titulo")
remesh(titulo, 0.00005)
# moldura em relevo baixo e martelado leve
co = co_de(titulo)
nv = normais_de(titulo)
fr = (co[:, 1] < tit_y - TIT_T / 2 + 0.0002) & (np.abs(co[:, 0]) < TIT_W / 2 - 0.0002)
borda = np.minimum(TIT_W / 2 - 0.0007 - np.abs(co[:, 0]), TIT_H / 2 - 0.0006 - np.abs(co[:, 2] - TIT_Z))
d = 0.00012 * np.clip(1 - np.abs(borda) / 0.00022, 0, 1) * fr
d += 0.00003 * ruido(co, 2500.0, 2, 4.0)
co += nv * d[:, None]
por_co(titulo, co)
suave(titulo)
# letras: Times bold, em relevo
fonte = bpy.data.fonts.load(r"C:\Windows\Fonts\timesbd.ttf")
cu = bpy.data.curves.new("inri", "FONT")
cu.body = "INRI"
cu.font = fonte
cu.size = 0.0078
cu.space_character = 1.12
cu.align_x = "CENTER"
cu.align_y = "CENTER"
cu.extrude = 0.00016
cu.bevel_depth = 0.00005
cu.bevel_resolution = 2
tx = ligar(bpy.data.objects.new("inri", cu))
tx.rotation_euler = (math.radians(90), 0, 0)
tx.location = (0, tit_y - TIT_T / 2 - 0.00006, TIT_Z - 0.0002)
bpy.context.view_layer.update()
dg = bpy.context.evaluated_depsgraph_get()
me = bpy.data.meshes.new_from_object(tx.evaluated_get(dg))
me.transform(tx.matrix_world)
letras = ligar(bpy.data.objects.new("alta_letras", me))
bpy.data.objects.remove(tx, do_unlink=True)
print("[cruz] letras", len(letras.data.vertices))
# baixa do titulo: placa chanfrada e dois rolos de 6 lados
bti = caixa("baixa_titulo", 0, tit_y, TIT_Z, TIT_W, TIT_T, TIT_H, 0.00028, 1)
brol = []
for s in (-1, 1):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=0.00088, radius2=0.00088, depth=TIT_H + 0.0006)
    bmesh.ops.translate(bm, vec=(s * (TIT_W / 2 + 0.0002), tit_y + 0.0002, TIT_Z), verts=bm.verts)
    me = bpy.data.meshes.new("rolo")
    bm.to_mesh(me)
    bm.free()
    brol.append(ligar(bpy.data.objects.new("rolo", me)))
bti = juntar([bti] + brol, "baixa_titulo")
suave(bti)
bti.data.set_sharp_from_angle(angle=math.radians(50))

# ------------------------------------------------------------------ cravos
corpo = [bpy.data.objects[n] for n in ("corpo",)]
me_c = corpo[0].data
bvh = BVHTree.FromPolygons([v.co[:] for v in me_c.vertices], [p.vertices[:] for p in me_c.polygons])


def na_pele(x, z):
    hit = bvh.ray_cast(Vector((x, -0.05, z)), Vector((0, 1, 0)))
    return hit[0]


# centro da palma (humano +-0,665 ; 1,71) e o meio do pe direito, por cima do esquerdo
pontos = []
for s in (-1, 1):
    pontos.append(na_pele(s * 0.665 * 0.060, Z_TRAVE))
zp = -0.0448 + ((0.96 - (0.96 - (-0.02)) * 0.93) - 1.71) * 0.060
pontos.append(na_pele(0.0008, zp))
print("[cruz] cravos em", [tuple(round(c, 4) for c in p) for p in pontos])


def cravo(c, alta):
    """Cabeca forjada abaulada apontando para -Y, espiga entrando na carne."""
    R = 0.00115 if alta else 0.00118
    if alta:
        ob = esfera_cubo("cravo", 20)
        co = co_de(ob)
        co[:, 1] = np.minimum(co[:, 1], 0.25)            # achata a base
        co *= np.array([R, 0.00062, R])
        # facetas de martelo
        n = ruido(co, 2200.0, 1, c.x * 100)
        co[:, 1] -= 0.00004 * n * (co[:, 1] < 0)
        por_co(ob, co)
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=12, radius1=0.00042, radius2=0.00030, depth=0.003)
        bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90), 3, "X"), verts=bm.verts)
        bmesh.ops.translate(bm, vec=(0, 0.0015, 0), verts=bm.verts)
        me = bpy.data.meshes.new("esp")
        bm.to_mesh(me)
        bm.free()
        esp = ligar(bpy.data.objects.new("esp", me))
        ob = juntar([ob, esp], "cravo")
    else:
        verts = [(0, -0.00062, 0)]
        for k in range(8):
            a = 2 * math.pi * k / 8 + math.pi / 8
            verts.append((R * 0.62 * math.cos(a), -0.00048, R * 0.62 * math.sin(a)))
        for k in range(8):
            a = 2 * math.pi * k / 8 + math.pi / 8
            verts.append((R * math.cos(a), 0.00012, R * math.sin(a)))
        faces = [(0, 1 + k, 1 + (k + 1) % 8) for k in range(8)]              # normal para -Y (fora)
        faces += [(1 + k, 9 + k, 9 + (k + 1) % 8, 1 + (k + 1) % 8) for k in range(8)]
        ob = malha("cravo", verts, faces)
    ob.data.transform(Matrix.Translation(c + Vector((0, 0.00018, 0))))
    return ob


alta_cravos = juntar([cravo(p, True) for p in pontos], "alta_cravos")
suave(alta_cravos)
baixa_cravos = juntar([cravo(p, False) for p in pontos], "baixa_cravos")
suave(baixa_cravos)


# ---------------------------------------------------------- olhal e argola
def anel_toro(nome, R, r, plano, centro, seg, lados):
    pts = []
    for k in range(seg):
        a = 2 * math.pi * k / seg
        if plano == "XZ":
            pts.append(Vector((R * math.cos(a), 0, R * math.sin(a))) + centro)
        else:
            pts.append(Vector((0, R * math.cos(a), R * math.sin(a))) + centro)
    return tubo(nome, pts, r, lados=lados, laco=True)


olhal = anel_toro("alta_olhal", OLHAL_R, OLHAL_F, "XZ", Vector((0, 0, Z_OLHAL)), 48, 16)
bm = bmesh.new()
bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=0.00045, radius2=0.00045, depth=0.0032)
bmesh.ops.translate(bm, vec=(0, 0, Z_OLHAL - OLHAL_R - 0.0012), verts=bm.verts)
me = bpy.data.meshes.new("rosca")
bm.to_mesh(me)
bm.free()
rosca = ligar(bpy.data.objects.new("rosca", me))
olhal = juntar([olhal, rosca], "alta_olhal")
argola = anel_toro("alta_argola", ARGOLA_R, ARGOLA_F, "YZ", Vector((0, 0, Z_ARGOLA)), 64, 16)
b_olhal = anel_toro("baixa_olhal", OLHAL_R, OLHAL_F, "XZ", Vector((0, 0, Z_OLHAL)), 10, 5)
b_argola = anel_toro("baixa_argola", ARGOLA_R, ARGOLA_F, "YZ", Vector((0, 0, Z_ARGOLA)), 16, 6)
for o in (olhal, argola, b_olhal, b_argola):
    suave(o)

meta = {"ORIGEM_Z": ORIGEM_Z, "Z_OLHAL": Z_OLHAL, "Z_ARGOLA": Z_ARGOLA, "ARGOLA_R": ARGOLA_R,
        "ARGOLA_F": ARGOLA_F, "cravos": [tuple(p) for p in pontos], "TIT_Z": TIT_Z}
bpy.context.scene["cruz_meta"] = json.dumps(meta)
for o in bpy.data.objects:
    if o.name.startswith("baixa_"):
        print("[cruz] %-14s tris=%d" % (o.name, tris(o)))
print("[cruz] meta", meta)
bpy.ops.wm.save_as_mainfile(filepath=SAIDA_BLEND)
print("[cruz] salvo", SAIDA_BLEND)
