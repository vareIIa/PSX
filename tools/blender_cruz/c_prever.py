"""Previa rapida de forma (Cycles/HIP) de um .blend da cruz, com material simples.

blender -b <arquivo.blend> --python c_prever.py -- <prefixo_saida> [vistas] [px] [zoom]
vistas: lista separada por virgula de frente,34,lado,cabeca,costas,baixo
"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector, Matrix
from c_comum import *

argv = sys.argv[sys.argv.index("--") + 1:]
pref = argv[0]
vistas = (argv[1] if len(argv) > 1 else "frente,34,lado").split(",")
px = int(argv[2]) if len(argv) > 2 else 1200
cena = bpy.context.scene
ligar_hip()
cena.cycles.samples = 48
cena.cycles.use_denoising = True
cena.render.resolution_x = px
cena.render.resolution_y = px
cena.view_settings.view_transform = "AgX"
cena.world = bpy.data.worlds.new("W")
cena.world.use_nodes = True
cena.world.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.05, 0.055, 1)


def mat_simples(nome, cor, metal, rug):
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = cor + (1,)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rug
    return m


bronze = mat_simples("bronze", (0.55, 0.42, 0.28), 1.0, 0.38)
madeira = mat_simples("madeira", (0.16, 0.10, 0.06), 0.0, 0.7)
ferro = mat_simples("ferro", (0.12, 0.11, 0.10), 0.8, 0.5)
CONJ = os.environ.get("CRUZ_CONJ", "alta")
for o in cena.objects:
    if o.type != "MESH":
        continue
    n = o.name
    if (CONJ == "alta" and n.startswith("baixa_")) or (CONJ == "baixa" and not n.startswith("baixa_")):
        o.hide_render = True
        continue
    if o.data.materials:
        continue
    if any(k in n for k in ("haste", "trave", "madeira")):
        o.data.materials.append(madeira)
    elif any(k in n for k in ("cravo", "argola", "olhal")):
        o.data.materials.append(ferro)
    else:
        o.data.materials.append(bronze)

for o in list(cena.objects):
    if o.type in ("CAMERA", "LIGHT"):
        bpy.data.objects.remove(o)


def luz(nome, pos, alvo, e, tam):
    ld = bpy.data.lights.new(nome, "AREA")
    ld.energy = e
    ld.size = tam
    lo = bpy.data.objects.new(nome, ld)
    lo.location = pos
    lo.rotation_euler = (Vector(alvo) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
    cena.collection.objects.link(lo)


luz("chave", (-0.35, -0.45, 0.30), (0, 0, -0.08), 60, 0.25)
luz("contra", (0.40, 0.35, 0.20), (0, 0, -0.08), 45, 0.2)
luz("enche", (0.40, -0.40, -0.25), (0, 0, -0.08), 10, 0.4)

VIS = {
    "frente": ((0, -1, 0), (0, 0, -0.085), 0.20),
    "34": ((-0.7, -0.7, 0.12), (0, 0, -0.085), 0.20),
    "lado": ((1, 0, 0), (0, 0, -0.085), 0.20),
    "costas": ((0, 1, 0), (0, 0, -0.085), 0.20),
    "cabeca": ((-0.25, -1, 0.15), (-0.004, -0.012, -0.050), 0.040),
    "tronco": ((-0.1, -1, 0.05), (0.0, -0.01, -0.075), 0.075),
    "pernas": ((-0.3, -1, 0.0), (0.0, -0.01, -0.125), 0.060),
    "mao": ((-0.2, -1, 0.1), (-0.038, -0.008, -0.043), 0.030),
    "pes": ((-0.1, -1, 0.05), (0.0, -0.008, -0.141), 0.030),
    "pes_lado": ((1, -0.3, 0.0), (0.0, -0.008, -0.141), 0.030),
    "rosto": ((-0.15, -1, -0.1), (-0.004, -0.014, -0.050), 0.022),
    "baixo": ((0, -0.5, -1), (0, 0, -0.085), 0.20),
    "topo": ((-0.4, -1, 0.3), (0, -0.004, -0.018), 0.050),
    "quina": ((-0.6, -1, 0.3), (0.030, -0.004, -0.045), 0.030),
}
cam_d = bpy.data.cameras.new("cam")
cam_d.type = "ORTHO"
cam_d.clip_start = 0.001
cam = bpy.data.objects.new("cam", cam_d)
cena.collection.objects.link(cam)
cena.camera = cam
for v in vistas:
    d, alvo, esc = VIS[v]
    d = Vector(d).normalized()
    cam_d.ortho_scale = esc
    cam.location = Vector(alvo) + d * 1.0
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    cena.render.filepath = pref + "_" + v + ".png"
    bpy.ops.render.render(write_still=True)
    print("[prever]", cena.render.filepath)
