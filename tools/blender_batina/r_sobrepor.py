"""Sobrepoe a batina (base.blend, malha do gerador) ao padre do jogo despejado
(`dump_padre_repouso`: OBJ e JSON em coordenada do Godot) para julgar o ajuste.
Tudo no quadro do Blender com o padre olhando +Y (o glTF leva a -Z do Godot).

A batina: gira 180 graus em Z (a frente dela e -Y), escala ESCALA e anda
DESLOCA.

blender -b base.blend --python r_sobrepor.py -- <dump_dir> <quem> <dir_fotos> ESCALA dx dy dz [reto]
(`reto`: a batina ja esta no quadro do padre, de `r_endireitar`; nao gira.)
"""
import sys, os, math, json
import bpy, bmesh
from mathutils import Vector, Matrix

a = sys.argv[sys.argv.index("--") + 1:]
dump, quem, fotos = a[0], a[1], a[2]
ESC = float(a[3]); DES = Vector((float(a[4]), float(a[5]), float(a[6])))
os.makedirs(fotos, exist_ok=True)
cena = bpy.context.scene
rob = bpy.data.objects["Batina"]
GIRA = not (len(a) > 7 and a[7] == "reto")
rob.matrix_world = Matrix.Translation(DES) @ Matrix.Scale(ESC, 4) @ (Matrix.Rotation(math.pi, 4, "Z") if GIRA else Matrix())

def g2b(v):
    return Vector((v[0], -v[2], v[1]))

d = json.load(open(os.path.join(dump, quem + ".json")))
# o corpo
bpy.ops.wm.obj_import(filepath=os.path.join(dump, quem + ".obj"), forward_axis="NEGATIVE_Z", up_axis="Y")
corpo_mat = bpy.data.materials.new("corpo"); corpo_mat.use_nodes = True
corpo_mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.9, 0.55, 0.2, 1)
for o in bpy.context.selected_objects:
    if o.type == "MESH":
        o.data.materials.clear(); o.data.materials.append(corpo_mat)
        if o.name.startswith(("Pano", "Murca", "Batina.")):
            bpy.data.objects.remove(o)
# ossos: bastoes
bm = bmesh.new()
for o in d["ossos"]:
    if o["pai"] < 0:
        continue
    p0 = g2b(d["ossos"][o["pai"]]["o"]); p1 = g2b(o["o"])
    if (p1 - p0).length < 1e-4:
        continue
    m = bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=0.012, radius2=0.012, depth=(p1 - p0).length)
    rot = (p1 - p0).to_track_quat("Z", "Y").to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=Matrix.Translation((p0 + p1) / 2) @ rot, verts=m["verts"])
c = d["cranio"]
m = bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=8, radius=1.0)
bmesh.ops.transform(bm, matrix=Matrix.Translation(g2b(c["centro"])) @ Matrix.Diagonal((c["meio"][0], c["meio"][2], c["meio"][1], 1.0)), verts=m["verts"])
me = bpy.data.meshes.new("ossos"); bm.to_mesh(me); bm.free()
oo = bpy.data.objects.new("Ossos", me); cena.collection.objects.link(oo)
om = bpy.data.materials.new("osso"); om.use_nodes = True
om.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.1, 0.9, 0.2, 1)
me.materials.append(om)
# batina transparente
for mat in rob.data.materials:
    mat.surface_render_method = "BLENDED"
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Alpha"].default_value = 0.45
for o in list(cena.objects):
    if o.type in ("CAMERA", "LIGHT"):
        bpy.data.objects.remove(o)
cena.render.engine = "BLENDER_EEVEE"; cena.render.resolution_x = 900; cena.render.resolution_y = 900
w = bpy.data.worlds.new("w"); cena.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.85, 0.85, 0.9, 1)
luz = bpy.data.lights.new("l", "SUN"); luz.energy = 3.0
lo = bpy.data.objects.new("l", luz); cena.collection.objects.link(lo)
lo.rotation_euler = (math.radians(50), 0, math.radians(30))
cam = bpy.data.cameras.new("c"); cam.type = "ORTHO"; cam.clip_start = 0.001; cam.clip_end = 30
co = bpy.data.objects.new("c", cam); cena.collection.objects.link(co); cena.camera = co
for nome, dv, cc, esc in [("lado", Vector((1, 0, 0)), Vector((0, 0, 0.95)), 2.1),
                          ("frente", Vector((0, 1, 0)), Vector((0, 0, 0.95)), 2.1),
                          ("cabeca_lado", Vector((1, 0, 0)), Vector((0, 0.1, 1.5)), 0.8)]:
    cam.ortho_scale = esc
    cima = Vector((0, 0, 1)); z_loc = dv.normalized(); x_loc = cima.cross(z_loc).normalized(); y_loc = z_loc.cross(x_loc)
    co.matrix_world = Matrix.Translation(cc + z_loc * 5.0) @ Matrix((x_loc, y_loc, z_loc)).transposed().to_4x4()
    cena.render.filepath = os.path.join(fotos, "sob_%s_%s.png" % (quem, nome))
    bpy.ops.render.render(write_still=True)
print("[sobrepor] ok")
