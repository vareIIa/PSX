"""Esqueleto do braco do padre e pesos na malha de jogo.

blender -b <mao_assada.blend> --python b_esqueleto.py -- <juntas.json> <saida.blend>

Ossos (Y ao longo do osso; Z de todo osso do braco e da mao aponta para o
DORSO, entao dobrar o dedo e girar em X local):
  braco -> antebraco -> antebraco_giro -> mao -> dedos
  pano: manga_a/b/c (no braco), faixa_cot_a/b (no antebraco), faixa_pulso (no giro)
O braco foi gerado na horizontal (ao longo de -Y do Blender) com o pano caindo
em -Z: as cadeias de pano descem em -Z, na direcao da gravidade do modelo.
"""
import sys, json
import bpy
import numpy as np
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
J = json.load(open(argv[0]))
saida = argv[1]
CFG = json.load(open(argv[2])) if len(argv) > 2 else {}
cena = bpy.context.scene
mao = bpy.data.objects["mao_jogo"]
mw = mao.matrix_world
co = np.array([(mw @ v.co)[:] for v in mao.data.vertices])

DORSO = Vector((1, 0, 0))
V = lambda p: Vector(p)
br = J["braco"]
dd = J["dedos"]
if not CFG:
    # a base do polegar (trapezio): do lado do polegar do punho, e nao no meio
    dd["polegar"][0]["p"] = [0.022, -0.470, 0.212]
    # as bases dos metacarpos, abertas em leque no punho
    for nome, dz in [("indicador", -0.012), ("medio", 0.0), ("anelar", 0.008), ("minimo", 0.016)]:
        p = dd[nome][0]["p"]
        dd[nome][0]["p"] = [p[0], -0.452, 0.248 + dz]
elif CFG.get("polegar_base"):
    dd["polegar"][0]["p"] = CFG["polegar_base"]

arm_d = bpy.data.armatures.new("braco_padre")
arm = bpy.data.objects.new("braco_padre", arm_d)
cena.collection.objects.link(arm)
bpy.ops.object.select_all(action="DESELECT")
bpy.context.view_layer.objects.active = arm
arm.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
eb = arm_d.edit_bones


def osso(nome, cab, cauda, pai=None, ligado=False, rolo=DORSO):
    b = eb.new(nome)
    b.head = V(cab)
    b.tail = V(cauda)
    if pai:
        b.parent = eb[pai]
        b.use_connect = ligado
    b.align_roll(rolo)
    return b


osso("braco", br["ombro"], br["cotovelo"])
osso("antebraco", br["cotovelo"], br["antebraco_meio"], "braco", True)
osso("antebraco_giro", br["antebraco_meio"], br["punho"], "antebraco", True)
mcp_medio = dd["medio"][1]["p"]
osso("mao", br["punho"], mcp_medio, "antebraco_giro", True)
# polegar: trapezio -> mcp -> ip -> ponta (o dorso dele olha para fora e para baixo)
pol = [q["p"] for q in dd["polegar"]]
rolo_pol = Vector((1, 0, -0.8)).normalized()
osso("polegar_1", pol[0], pol[1], "mao", False, rolo_pol)
osso("polegar_2", pol[1], pol[2], "polegar_1", True, rolo_pol)
osso("polegar_3", pol[2], pol[3], "polegar_2", True, rolo_pol)
for nome in ["indicador", "medio", "anelar", "minimo"]:
    q = [x["p"] for x in dd[nome]]
    osso(nome + "_0", q[0], q[1], "mao", False)
    osso(nome + "_1", q[1], q[2], nome + "_0", True)
    osso(nome + "_2", q[2], q[3], nome + "_1", True)
    osso(nome + "_3", q[3], q[4], nome + "_2", True)


# O pano: em cada faixa de Y, o pano que cai abaixo do braco. A cadeia desce do
# pe do braco ate a borda de baixo, pelo meio do pano em X.
Z_TOPO = CFG.get("pano_z_topo", 0.215)


def cadeia(nome, y, meia, pai, n, z_topo=None):
    z_topo = Z_TOPO if z_topo is None else z_topo
    f = co[(np.abs(co[:, 1] - y) < meia) & (co[:, 2] < z_topo - 0.01)]
    if len(f) < 20:
        print("[esq] sem pano em", nome, y)
        return
    z_fim = float(f[:, 2].min()) + 0.006
    xs = []
    zs = np.linspace(z_topo, z_fim, n + 1)
    for z in zs:
        g = f[np.abs(f[:, 2] - z) < 0.01]
        xs.append(float(g[:, 0].mean()) if len(g) else float(f[:, 0].mean()))
    ant = pai
    for i in range(n):
        b = osso("%s_%d" % (nome, i + 1), (xs[i], y, zs[i]), (xs[i + 1], y, zs[i + 1]),
                 ant, i > 0, Vector((0, 1, 0)))
        ant = b.name
    print("[esq] pano %s y=%.3f z %.3f -> %.3f (%d pontos)" % (nome, y, z_topo, z_fim, len(f)))


for c in CFG.get("cadeias", [["manga_a", 0.450, 0.02, "braco", 3], ["manga_b", 0.385, 0.02, "braco", 3],
                               ["manga_c", 0.320, 0.02, "braco", 2],
                               ["faixa_cot_a", -0.105, 0.015, "antebraco", 3],
                               ["faixa_cot_b", -0.155, 0.015, "antebraco", 3],
                               ["faixa_pulso", -0.300, 0.015, "antebraco_giro", 4]]):
    cadeia(*c)
bpy.ops.object.mode_set(mode="OBJECT")
print("[esq] ossos", len(arm_d.bones), [b.name for b in arm_d.bones])

# pesos automaticos (calor) na malha fechada
bpy.ops.object.select_all(action="DESELECT")
mao.select_set(True)
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.parent_set(type="ARMATURE_AUTO")
vg = mao.vertex_groups
print("[esq] grupos", len(vg))
sem = 0
for v in mao.data.vertices:
    if not v.groups or sum(g.weight for g in v.groups) < 1e-4:
        sem += 1
print("[esq] vertices sem peso", sem)
# limpa: no maximo 4 ossos, normalizado, sem migalha
bpy.context.view_layer.objects.active = mao
bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
bpy.ops.object.vertex_group_clean(group_select_mode="ALL", limit=0.01)
bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
bpy.ops.object.mode_set(mode="OBJECT")
sem = sum(1 for v in mao.data.vertices if not v.groups)
print("[esq] vertices sem peso depois da limpeza", sem)
bpy.ops.wm.save_as_mainfile(filepath=saida)
print("[esq] fim")
