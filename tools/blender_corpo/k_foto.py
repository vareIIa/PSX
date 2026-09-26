"""Fotos do corpo no esqueleto do jogo (corpo_jogo.blend): repouso de frente,
de lado e de tres quartos, e uma pose forcada (bracos, cabeca, tronco, joelho)
para julgar o peso.

blender -b corpo_jogo.blend --python k_foto.py -- <saida_prefixo>
"""
import sys, math
import bpy
from mathutils import Vector, Matrix, Euler
pref = sys.argv[sys.argv.index("--") + 1]
cena = bpy.context.scene
cena.render.engine = "BLENDER_EEVEE"
cena.render.resolution_x = 900
cena.render.resolution_y = 1300
w = bpy.data.worlds.new("w"); cena.world = w
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.35, 0.36, 0.4, 1)
for ang, en in ((50, 3.0), (-120, 1.2)):
    luz = bpy.data.lights.new("l", "SUN"); luz.energy = en
    lo = bpy.data.objects.new("l", luz); cena.collection.objects.link(lo)
    lo.rotation_euler = (math.radians(55), 0, math.radians(ang))
cam = bpy.data.cameras.new("c"); cam.clip_start = 0.01
co = bpy.data.objects.new("c", cam); cena.collection.objects.link(co); cena.camera = co
arm = bpy.data.objects["Jogo"]


def olhar(pos, alvo, orto=None):
    d = (Vector(alvo) - Vector(pos)).normalized()
    co.matrix_world = Matrix.Translation(pos) @ d.to_track_quat("-Z", "Y").to_matrix().to_4x4()
    if orto:
        cam.type = "ORTHO"; cam.ortho_scale = orto
    else:
        cam.type = "PERSP"; cam.lens = 50


def foto(nome):
    cena.render.filepath = pref + "_" + nome + ".png"
    bpy.ops.render.render(write_still=True)


olhar((0, 4, 0.85), (0, 0, 0.85), 1.9); foto("frente")
olhar((4, 0, 0.85), (0, 0, 0.85), 1.9); foto("lado")
olhar((0.7, 0.9, 1.45), (0, 0, 1.25)); foto("ombro")
olhar((-0.25, -0.7, 1.4), (0, 0, 1.3)); foto("costas")
# pose forcada
pb = arm.pose.bones
def gira(nome, x=0, y=0, z=0):
    b = pb[nome]; b.rotation_mode = "XYZ"; b.rotation_euler = Euler((math.radians(x), math.radians(y), math.radians(z)))
gira("braco_d", x=-80)          # braco para a frente
gira("antebraco_d", x=-70)      # cotovelo dobrado
gira("braco_e", z=-60)          # braco para o lado
gira("torso", x=-25)            # curva para a frente
gira("cabeca", x=20, z=15)
gira("coxa_e", x=-40)
gira("canela_e", x=60)
bpy.context.view_layer.update()
olhar((1.6, 2.4, 1.2), (0, 0, 0.95)); foto("pose")
olhar((0.9, 0.9, 1.5), (0, 0, 1.3)); foto("pose_ombro")
