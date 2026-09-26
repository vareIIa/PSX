"""Poses de teste do braco riggado, fotografadas em perspectiva (EEVEE).

blender -b <mao_riggada.blend> --python b_pose.py -- <saida_dir>
"""
import sys, os, math
import bpy
from mathutils import Vector, Euler, Matrix

argv = sys.argv[sys.argv.index("--") + 1:]
saida = argv[0]
os.makedirs(saida, exist_ok=True)
cena = bpy.context.scene
arm = bpy.data.objects["braco_padre"]
R = math.radians
DEDOS = ["indicador", "medio", "anelar", "minimo"]

POSES = {
    "repouso": {},
    "punho": dict([(d + "_1", (R(-75), 0, 0)) for d in DEDOS] + [(d + "_2", (R(-90), 0, 0)) for d in DEDOS]
                  + [(d + "_3", (R(-55), 0, 0)) for d in DEDOS]
                  + [("polegar_2", (R(-35), 0, 0)), ("polegar_3", (R(-50), 0, 0)), ("polegar_1", (R(-20), 0, R(15)))]),
    "aberta": dict([(d + "_1", (R(25), 0, R(s))) for d, s in zip(DEDOS, [-12, -3, 6, 15])]
                   + [(d + "_2", (R(15), 0, 0)) for d in DEDOS] + [(d + "_3", (R(10), 0, 0)) for d in DEDOS]
                   + [("polegar_1", (R(20), 0, R(-25)))]),
    "cotovelo": {"antebraco": (R(-90), 0, 0), "antebraco_giro": (0, R(70), 0), "mao": (R(-45), 0, R(15))},
    "pano": {"manga_a_1": (R(40), 0, 0), "manga_b_2": (R(-50), 0, 0), "faixa_pulso_2": (R(60), 0, 0),
             "faixa_cot_a_1": (R(-45), 0, 0)},
}
# camera e luz
if cena.world is None:
    cena.world = bpy.data.worlds.new("W")
cena.world.use_nodes = True
cena.world.node_tree.nodes["Background"].inputs[0].default_value = (0.35, 0.36, 0.38, 1)
for nome, rot, e in [("chave", (R(40), 0, R(35)), 3.0), ("contra", (R(-60), 0, R(200)), 1.5)]:
    ld = bpy.data.lights.new(nome, "SUN")
    ld.energy = e
    lo = bpy.data.objects.new(nome, ld)
    lo.rotation_euler = rot
    cena.collection.objects.link(lo)
cena.render.engine = "BLENDER_EEVEE"
cena.render.resolution_x = 1000
cena.render.resolution_y = 1000
cam_d = bpy.data.cameras.new("cam")
cam_d.lens = 50
cam_d.clip_start = 0.005
cam = bpy.data.objects.new("cam", cam_d)
cena.collection.objects.link(cam)
cena.camera = cam


def mirar(de, para):
    d = (Vector(para) - Vector(de)).normalized()
    cam.location = Vector(de)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


import json as _json
_V = _os_env = __import__("os").environ.get("POSE_VISTAS", "")
VISTAS = {
    "mao_dorso": ((0.42, -0.60, 0.26), (0.0, -0.56, 0.24)),
    "mao_palma": ((-0.42, -0.62, 0.22), (0.0, -0.56, 0.24)),
    "mao_baixo": ((0.10, -0.62, -0.25), (0.0, -0.56, 0.23)),
    "braco": ((1.6, -0.1, 0.5), (0.0, -0.1, 0.22)),
    "cima": ((0.0, -0.15, 1.9), (0.0, -0.15, 0.25)),
    "cotovelo_perto": ((0.05, 0.05, 0.75), (0.0, -0.03, 0.25)),
    "pulso_perto": ((0.35, -0.40, 0.40), (0.01, -0.42, 0.25)),
    "pano_perto": ((0.45, 0.30, 0.10), (0.0, 0.38, 0.15)),
}
if _V:
    VISTAS.update({k: tuple(tuple(x) for x in v) for k, v in _json.load(open(_V)).items()})
import os as _os
SO = _os.environ.get("POSE_SO", "")
for nome_p, pose in POSES.items():
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = pose.get(pb.name, (0, 0, 0))
    bpy.context.view_layer.update()
    vistas = ["braco"] if nome_p in ("cotovelo", "pano") else ["mao_dorso", "mao_palma", "mao_baixo"]
    if nome_p == "cotovelo":
        vistas = ["cima", "cotovelo_perto", "pulso_perto"]
    if nome_p == "pano":
        vistas = ["braco", "pano_perto"]
    if SO and nome_p not in SO.split(","):
        continue
    for nome_v in vistas:
        de, para = VISTAS[nome_v]
        if False:
            # a mao foi junto com o antebraco: mira nela
            mb = arm.matrix_world @ arm.pose.bones["mao"].head
            de, para = (mb.x + 0.40, mb.y - 0.05, mb.z + 0.10), (mb.x, mb.y, mb.z)
        mirar(de, para)
        cena.render.filepath = os.path.join(saida, "%s_%s.png" % (nome_p, nome_v))
        bpy.ops.render.render(write_still=True)
        print("[pose]", nome_p, nome_v)
