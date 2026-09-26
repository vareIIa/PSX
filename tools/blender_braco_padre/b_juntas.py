"""Juntas do braco e da mao no miolo da malha.

blender -b <mao_assada.blend> --python b_juntas.py -- <dedos2.json> <saida.json>

Dedos: o ponto da pele no caminho geodesico na distancia escolhida de cada
junta; o miolo e o meio da corda que atravessa a malha a partir dele, para
dentro (contra a normal). Braco: o centro da fatia do tronco do braco (sem as
pontas de pano) em cada altura de Y.
"""
import sys, json
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

argv = sys.argv[sys.argv.index("--") + 1:]
dedos = json.load(open(argv[0]))
saida = argv[1]
CFG = json.load(open(argv[2])) if len(argv) > 2 else {}

# Distancia geodesica (do punho) de cada junta, lida das dobras da linha central.
JUNTAS = {
    "polegar": [0.045, 0.110, 0.190],
    "indicador": [0.040, 0.130, 0.205, 0.265],
    "medio": [0.040, 0.140, 0.215, 0.275],
    "anelar": [0.040, 0.130, 0.207, 0.250],
    "minimo": [0.040, 0.115, 0.170, 0.225],
}
if CFG:
    JUNTAS = CFG["juntas"]
ob = bpy.data.objects["mao_jogo"]
dg = bpy.context.evaluated_depsgraph_get()
bvh = BVHTree.FromObject(ob, dg)
mw = ob.matrix_world


def miolo(p_sup):
    p = Vector(p_sup)
    loc, nor, _, _ = bvh.find_nearest(p)
    n = nor.normalized()
    ini = loc - n * 0.0005
    hit, _, _, d = bvh.ray_cast(ini, -n, 0.08)
    if hit is None:
        return loc - n * 0.006, 0.012
    return (loc + hit) * 0.5, (hit - loc).length


res = {"dedos": {}, "braco": {}}
for nome, ds in JUNTAS.items():
    pts = dedos[nome]["pts"]
    lista = []
    for d in ds:
        q = min(pts, key=lambda q: abs(q["d"] - d))
        c, esp = miolo(q["sup"])
        lista.append({"d": d, "p": list(c), "esp": esp})
    ponta = Vector(dedos[nome]["ponta"])
    lista.append({"d": dedos[nome]["comp"], "p": list(ponta), "esp": 0.0})
    res["dedos"][nome] = lista
    print("[juntas] %-9s" % nome, " ".join("(%.3f %.3f %.3f|%.1fmm)" % (
        j["p"][0], j["p"][1], j["p"][2], j["esp"] * 1000) for j in lista))

# braco: centro do tronco em cada Y (pontas de pano fora: so o que esta perto do eixo)
co = np.array([(mw @ v.co)[:] for v in ob.data.vertices])
EIXO_Z = CFG.get("eixo_z", 0.25)
JANELA = CFG.get("janela_z", 0.045)
BY = CFG.get("braco_y", {"ombro": 0.43, "cotovelo": -0.03, "antebraco_meio": -0.225,
                         "punho": -0.425, "manga_topo": 0.48})
for nome, y in BY.items():
    f = co[(np.abs(co[:, 1] - y) < 0.006) & (np.abs(co[:, 2] - EIXO_Z) < JANELA)]
    c = [(f[:, 0].min() + f[:, 0].max()) / 2, y, (f[:, 2].min() + f[:, 2].max()) / 2]
    res["braco"][nome] = c
    print("[juntas] %-14s (%.3f %.3f %.3f) x=[%.3f %.3f] z=[%.3f %.3f] n=%d" % (
        nome, c[0], c[1], c[2], f[:, 0].min(), f[:, 0].max(), f[:, 2].min(), f[:, 2].max(), len(f)))
json.dump(res, open(saida, "w"), indent=1)
