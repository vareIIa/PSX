"""Fotos das grades (grades.json) sobre a batina endireitada, uma peca por vez:
azul a grade de ligar (na malha de IA), vermelho o repouso (pendurado).
blender -b reto.blend --python r_ver_grades.py -- <grades.json> <dir> <peca,peca|todas> [liga|rep|ambas] [sem_batina]"""
import sys, os, math, json
import bpy, bmesh
import numpy as np
from mathutils import Vector, Matrix
a = sys.argv[sys.argv.index("--") + 1:]
g = json.load(open(a[0])); saida = a[1]; quais = a[2].split(",")
modo = a[3] if len(a) > 3 else "ambas"
sem_batina = len(a) > 4 and a[4] == "sem_batina"
os.makedirs(saida, exist_ok=True)
def g2b(v): return Vector((v[0], -v[2], v[1]))
def malha_grade(nome, pts, w, h, cor, raio=0.003):
    b2 = bmesh.new()
    vs = [[b2.verts.new(pts[j * w + i]) for i in range(w)] for j in range(h)]
    for j in range(h):
        for i in range(w):
            b2.edges.new((vs[j][i], vs[j][(i + 1) % w]))
            if j + 1 < h: b2.edges.new((vs[j][i], vs[j + 1][i]))
    me = bpy.data.meshes.new(nome); b2.to_mesh(me); b2.free()
    o = bpy.data.objects.new(nome, me); bpy.context.scene.collection.objects.link(o)
    o.modifiers.new("fio", "SKIN")
    for sv in me.skin_vertices[0].data: sv.radius = (raio, raio)
    m = bpy.data.materials.new(nome); m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = cor
    me.materials.append(m)
for pc in g["pecas"]:
    if "todas" not in quais and pc["nome"] not in quais: continue
    if modo in ("liga", "ambas"):
        malha_grade(pc["nome"] + "_l", [g2b(p) for p in pc["liga"]], pc["w"], pc["h"], (0.1, 0.4, 1.0, 1))
    if modo in ("rep", "ambas"):
        malha_grade(pc["nome"] + "_r", [g2b(p) for p in pc["repouso"]], pc["w"], pc["h"], (1.0, 0.15, 0.1, 1))
ob = bpy.data.objects["Batina"]
if sem_batina:
    ob.hide_render = True
for mat in ob.data.materials:
    mat.surface_render_method = "BLENDED"
    mat.node_tree.nodes["Principled BSDF"].inputs["Alpha"].default_value = 0.3
cena = bpy.context.scene
for o in list(cena.objects):
    if o.type in ("CAMERA", "LIGHT"): bpy.data.objects.remove(o)
cena.render.engine = "BLENDER_EEVEE"; cena.render.resolution_x = 900; cena.render.resolution_y = 900
wd = bpy.data.worlds.new("w"); cena.world = wd; wd.use_nodes = True
wd.node_tree.nodes["Background"].inputs[0].default_value = (0.85, 0.85, 0.9, 1)
luz = bpy.data.lights.new("l", "SUN"); luz.energy = 3.0
lo = bpy.data.objects.new("l", luz); cena.collection.objects.link(lo)
lo.rotation_euler = (math.radians(50), 0, math.radians(30))
cam = bpy.data.cameras.new("c"); cam.type = "ORTHO"; cam.clip_start = 0.001; cam.clip_end = 30
co = bpy.data.objects.new("c", cam); cena.collection.objects.link(co); cena.camera = co
tag = "_".join(quais) + "_" + modo
for nome, dv, cc, esc in [("lado", Vector((1, 0, 0)), Vector((0, -0.15, 0.95)), 2.1),
                          ("frente", Vector((0, 1, 0)), Vector((0, 0, 0.95)), 2.1),
                          ("tq", Vector((0.7, 0.7, 0.3)), Vector((0, 0, 1.25)), 1.2),
                          ("costas", Vector((-0.6, -0.8, 0.2)), Vector((0, -0.2, 0.9)), 2.1)]:
    cam.ortho_scale = esc
    cima = Vector((0, 0, 1)); z_loc = dv.normalized(); x_loc = cima.cross(z_loc).normalized(); y_loc = z_loc.cross(x_loc)
    co.matrix_world = Matrix.Translation(cc + z_loc * 5.0) @ Matrix((x_loc, y_loc, z_loc)).transposed().to_4x4()
    cena.render.filepath = os.path.join(saida, "%s_%s.png" % (tag, nome))
    bpy.ops.render.render(write_still=True)
print("[ver_grades] ok", tag)
