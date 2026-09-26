"""Foto ortografica com o material de verdade (EEVEE), camera num eixo do mundo.

blender -b <blend> --python b_foto.py -- <saida.png> <eixo: +x|-x|+z|-z|+y|-y> <cx> <cy> <cz> <escala> [px]

Imprime o mapeamento pixel -> mundo: u (direita) e v (baixo) em [0,1].
"""
import sys, math
import bpy
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index("--") + 1:]
saida, eixo = argv[0], argv[1]
c = Vector((float(argv[2]), float(argv[3]), float(argv[4])))
escala = float(argv[5])
px = int(argv[6]) if len(argv) > 6 else 1400

cena = bpy.context.scene
cena.render.engine = "BLENDER_EEVEE"
cena.render.resolution_x = px
cena.render.resolution_y = px
if cena.world is None:
    cena.world = bpy.data.worlds.new("W")
cena.world.use_nodes = True
bg = cena.world.node_tree.nodes.get("Background")
if bg:
    bg.inputs[0].default_value = (0.35, 0.36, 0.38, 1)
    bg.inputs[1].default_value = 1.0
for o in list(cena.objects):
    if o.type in ("CAMERA", "LIGHT"):
        bpy.data.objects.remove(o)
# luz chave e contra
for nome, rot, e in [("chave", (math.radians(40), 0, math.radians(35)), 3.0),
                     ("contra", (math.radians(-60), 0, math.radians(200)), 1.5)]:
    ld = bpy.data.lights.new(nome, "SUN")
    ld.energy = e
    lo = bpy.data.objects.new(nome, ld)
    lo.rotation_euler = rot
    cena.collection.objects.link(lo)

d = {"+x": Vector((1, 0, 0)), "-x": Vector((-1, 0, 0)), "+z": Vector((0, 0, 1)),
     "-z": Vector((0, 0, -1)), "+y": Vector((0, 1, 0)), "-y": Vector((0, -1, 0))}[eixo]
cima = Vector((0, 1, 0)) if abs(d.y) < 0.9 else Vector((0, 0, 1))
z_loc = d  # camera olha -Z local; entao Z local aponta para tras (para d)
x_loc = cima.cross(z_loc).normalized()
y_loc = z_loc.cross(x_loc).normalized()
rot = Matrix((x_loc, y_loc, z_loc)).transposed().to_4x4()
cam_d = bpy.data.cameras.new("cam")
cam_d.type = "ORTHO"
cam_d.ortho_scale = escala
cam_d.clip_start = 0.001
cam_d.clip_end = 10.0
cam = bpy.data.objects.new("cam", cam_d)
cam.matrix_world = Matrix.Translation(c + d * 2.0) @ rot
cena.collection.objects.link(cam)
cena.camera = cam
cena.render.filepath = saida
bpy.ops.render.render(write_still=True)
# mundo = c + (u-0.5)*escala*x_loc + (0.5-v)*escala*y_loc
print("[foto] %s eixo=%s c=%s escala=%.4f direita=%s cima=%s" % (
    saida, eixo, tuple(round(a, 4) for a in c), escala,
    tuple(round(a, 3) for a in x_loc), tuple(round(a, 3) for a in y_loc)))
