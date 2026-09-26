"""Importa o braco (glb do gerador), aplica o giro do no, solda as costuras e
alinha o braco ao longo de -Y do Blender (a mao em -Y, o ombro em +Y), girando
so em torno de Z: o pano continua caindo em -Z, como o gerador fez.

blender -b --python b_alinhar.py -- <glb> <saida.blend>

O objeto sai com o nome `mao_jogo`, o material do gerador e as UV dele.
"""
import sys, math
import bpy
import bmesh
import numpy as np
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
glb, saida = argv[0], argv[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
ob = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
ob.name = "mao_jogo"
ob.data.name = "mao_jogo"
bpy.context.view_layer.objects.active = ob
ob.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

bm = bmesh.new()
bm.from_mesh(ob.data)
antes = len(bm.verts)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
nm = sum(1 for e in bm.edges if not e.is_manifold)
bordas = sum(1 for e in bm.edges if e.is_boundary)
bm.to_mesh(ob.data)
bm.free()
print("[alinhar] soldados", antes - len(ob.data.vertices), "verts", len(ob.data.vertices),
      "nao-manifold", nm, "borda", bordas)
for p in ob.data.polygons:
    p.use_smooth = True

co = np.array([v.co[:] for v in ob.data.vertices])
xy = co[:, :2] - co[:, :2].mean(axis=0)
w, vec = np.linalg.eigh(xy.T @ xy)
eixo = vec[:, np.argmax(w)]
t = xy @ eixo
lo, hi = t.min(), t.max()
L = hi - lo
# a ponta do ombro e a que tem pano caindo ate o chao (z minimo perto de 0)
fim_lo = co[t < lo + 0.12 * L]
fim_hi = co[t > hi - 0.12 * L]
print("[alinhar] eixo", eixo.round(3), "comprimento %.3f" % L,
      "zmin lo %.3f hi %.3f" % (fim_lo[:, 2].min(), fim_hi[:, 2].min()))
ombro_em_hi = fim_hi[:, 2].min() < fim_lo[:, 2].min()
para_mao = -eixo if ombro_em_hi else eixo  # do ombro para a mao
ang = math.atan2(para_mao[1], para_mao[0])
alvo = -math.pi / 2  # -Y
giro = Matrix.Rotation(alvo - ang, 4, "Z")
centro = Vector((co[:, 0].mean(), co[:, 1].mean(), 0.0))
ob.data.transform(Matrix.Translation(-centro))
ob.data.transform(giro)
ob.data.update()
co = np.array([v.co[:] for v in ob.data.vertices])
print("[alinhar] caixa", co.min(axis=0).round(3), co.max(axis=0).round(3))
bpy.ops.wm.save_as_mainfile(filepath=saida)
