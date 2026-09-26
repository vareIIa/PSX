"""Assa a oclusao de ambiente (AO) da batina AAA, no repouso do jogo, com o
corpo e a cabeca dentro dela, na UV do gerador.

Por que: no jogo o fundo do capuz e das dobras via o ceu inteiro. O pano quase
preto de dentro do capuz refletia o ambiente e a contraluz como vinil
(preto-azulado brilhante), e nada escurecia a boca do capuz em volta do rosto.
O SSAO da tela so pega o que a camera ve e so a luz ambiente; a AO assada da
propria roupa, com a pessoa dentro, sabe que o fundo do capuz e uma cavidade.
No Godot, `AO` apaga a luz ambiente e o reflexo do ceu ali, e `AO_LIGHT_AFFECT`
escurece um pouco a luz direta.

Oclusores: a batina (ela mesma), o corpo do jogo (`corpo_jogo.blend`, sem
cabeca) e a cabeca como um elipsoide do tamanho do cranio do `Corpo`
(`romeiro.json`: `cranio`). A cabeca do padre principal e proporcional (1,134x,
a mesma escala da altura), entao uma AO serve para todos.

Os tampos do `r_limpar` (U >= 2, a trama repetida do shader) ficam fora do
assado, so fazendo sombra: a UV deles cairia de volta no atlas. A AO deles vai
por vertice no alfa do atributo `remendo`, tirada da borda assada e espalhada
para dentro, e o `reto.blend` e gravado com ela (o `r_ligar` exporta).

blender -b reto.blend --python r_ao.py -- <corpo_jogo.blend> <romeiro.json> <saida.png> [lado]

Confere antes de assar: sobreposicao de UV (duas faces no mesmo texel dariam
AO trocada) e quantas arestas de borda ha (pano de uma camada so pede AO dos
dois lados).
"""
import sys, os, json, math
import bpy, bmesh
import numpy as np

a = sys.argv[sys.argv.index("--") + 1:]
corpo_blend, romeiro_json, saida = a[0], a[1], a[2]
LADO = int(a[3]) if len(a) > 3 else 2048
AMOSTRAS = 256
# Alcance da AO: as dobras tem 1-5 cm; a boca do capuz, uns 15 cm ate o rosto.
ALCANCE = 0.30

batina = bpy.data.objects["Batina"]
me_inteira = batina.data
tem_tampo = "tampo" in me_inteira.attributes
me = me_inteira.copy()
batina.data = me
tampos = None
if tem_tampo:
    tampos = bpy.data.objects.new("TampoAO", me_inteira.copy())
    bpy.context.scene.collection.objects.link(tampos)
    for obj, fica in ((batina, 0), (tampos, 1)):
        b = bmesh.new()
        b.from_mesh(obj.data)
        lay = b.faces.layers.int.get("tampo")
        bmesh.ops.delete(b, geom=[f for f in b.faces if f[lay] != fica], context="FACES")
        b.to_mesh(obj.data)
        b.free()
    print("[ao] tampos fora do assado: %d faces" % len(tampos.data.polygons))

# --- conferencias ---
bm = bmesh.new()
bm.from_mesh(me)
borda = sum(1 for e in bm.edges if e.is_boundary)
print("[ao] batina: %d vertices, %d faces, %d arestas de borda" % (len(bm.verts), len(bm.faces), len(bm.edges)))
print("[ao] arestas de borda: %d (%.1f%%)" % (borda, 100.0 * borda / max(len(bm.edges), 1)))
uvl = bm.loops.layers.uv.active
R = 512
cont = np.zeros((R, R), np.int32)
degeneradas = 0
for f in bm.faces:
    us = [l[uvl].uv for l in f.loops]
    for k in range(1, len(us) - 1):
        t = np.array([[us[0].x, us[0].y], [us[k].x, us[k].y], [us[k + 1].x, us[k + 1].y]]) * R
        area = (t[1, 0] - t[0, 0]) * (t[2, 1] - t[0, 1]) - (t[2, 0] - t[0, 0]) * (t[1, 1] - t[0, 1])
        if abs(area) < 1e-6:
            degeneradas += 1
            continue
        x0, y0 = np.floor(t.min(0)).astype(int)
        x1, y1 = np.ceil(t.max(0)).astype(int)
        x0, y0 = max(x0, 0), max(y0, 0)
        x1, y1 = min(x1, R - 1), min(y1, R - 1)
        if x1 < x0 or y1 < y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        def lado(p, q):
            return (q[0] - p[0]) * (ys - p[1]) - (q[1] - p[1]) * (xs - p[0])
        s0, s1, s2 = lado(t[0], t[1]), lado(t[1], t[2]), lado(t[2], t[0])
        dentro = ((s0 >= 0) & (s1 >= 0) & (s2 >= 0)) | ((s0 <= 0) & (s1 <= 0) & (s2 <= 0))
        cont[y0:y1 + 1, x0:x1 + 1] += dentro
cobertos = int((cont > 0).sum())
duplos = int((cont > 1).sum())
print("[ao] UV %d: %d texels cobertos, %d com mais de uma face (%.2f%%), %d triangulos sem area" % (
    R, cobertos, duplos, 100.0 * duplos / max(cobertos, 1), degeneradas))
bm.free()

# --- oclusores ---
with bpy.data.libraries.load(corpo_blend) as (de, para):
    para.objects = [n for n in de.objects if n == "Corpo"]
for o in para.objects:
    bpy.context.scene.collection.objects.link(o)
    o.hide_render = False
cr = json.load(open(romeiro_json))["cranio"]
c, m = cr["centro"], cr["meio"]
# Godot (x, y, z) -> Blender do jogo (x, -z, y)
bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=24, radius=1.0,
    location=(c[0], -c[2], c[1]))
cab = bpy.context.active_object
cab.name = "CabecaAO"
cab.scale = (m[0], m[2], m[1])
print("[ao] cabeca: centro %s meio %s" % (tuple(round(v, 3) for v in cab.location), tuple(round(v, 3) for v in cab.scale)))

# --- bake ---
sc = bpy.context.scene
sc.render.engine = "CYCLES"
pr = bpy.context.preferences.addons["cycles"].preferences
for tipo in ("HIP", "OPTIX", "CUDA"):
    try:
        pr.compute_device_type = tipo
        pr.get_devices()
        if any(d.type == tipo for d in pr.devices):
            for d in pr.devices:
                d.use = True
            sc.cycles.device = "GPU"
            print("[ao] placa", tipo)
            break
    except Exception:
        pass
sc.cycles.samples = AMOSTRAS
if sc.world is None:
    sc.world = bpy.data.worlds.new("mundo")
sc.world.light_settings.distance = ALCANCE
img = bpy.data.images.new("batina_ao", LADO, LADO, alpha=False, float_buffer=True)
img.colorspace_settings.name = "Non-Color"
for mat in me.materials:
    nt = mat.node_tree
    n = nt.nodes.new("ShaderNodeTexImage")
    n.image = img
    nt.nodes.active = n
bpy.ops.object.select_all(action="DESELECT")
batina.select_set(True)
bpy.context.view_layer.objects.active = batina
sc.render.bake.margin = 16
sc.render.bake.margin_type = "EXTEND"
bpy.ops.object.bake(type="AO")
px = np.array(img.pixels[:]).reshape(LADO, LADO, 4)[..., 0]
print("[ao] AO: p5 %.2f p50 %.2f p95 %.2f" % tuple(np.percentile(px[cont.repeat(LADO // R, 0).repeat(LADO // R, 1) > 0], [5, 50, 95])))
# Cinza de 8 bits (a AO nao precisa de mais, e o Godot comprime).
st = sc.render.image_settings
st.file_format = "PNG"
st.color_mode = "BW"
st.color_depth = "8"
img.save_render(saida, scene=sc)

# --- a AO dos tampos, por vertice ---
# Assada direto nos vertices deles (a borda do buraco encosta na parede de
# dentro da casca, fechada e preta: tirar a AO dela escurecia o tampo).
ao_tampo = {}
if tampos is not None:
    ca = tampos.data.color_attributes.new("ao_v", "FLOAT_COLOR", "POINT")
    tampos.data.color_attributes.active_color = ca
    bpy.ops.object.select_all(action="DESELECT")
    tampos.select_set(True)
    bpy.context.view_layer.objects.active = tampos
    sc.render.bake.target = "VERTEX_COLORS"
    bpy.ops.object.bake(type="AO")
    sc.render.bake.target = "IMAGE_TEXTURES"
    from mathutils.kdtree import KDTree
    kd = KDTree(len(tampos.data.vertices))
    for v in tampos.data.vertices:
        kd.insert(v.co, v.index)
    kd.balance()
    ao_v = [c.color[0] for c in tampos.data.color_attributes["ao_v"].data]
for mat in me.materials:
    nt = mat.node_tree
    for nd in [nd for nd in nt.nodes if nd.type == "TEX_IMAGE" and nd.image == img]:
        nt.nodes.remove(nd)
batina.data = me_inteira
if tampos is not None:
    b = bmesh.new()
    b.from_mesh(me_inteira)
    lay = b.faces.layers.int.get("tampo")
    rem = b.verts.layers.float_color.get("remendo")
    vals = []
    for v in b.verts:
        if not any(f[lay] for f in v.link_faces):
            continue
        _co, i, _d = kd.find(v.co)
        c = v[rem]
        v[rem] = (c[0], c[1], c[2], float(ao_v[i]))
        vals.append(ao_v[i])
    b.to_mesh(me_inteira)
    b.free()
    print("[ao] tampos: %d vertices, AO p5 %.2f p50 %.2f p95 %.2f" % ((len(vals),) + tuple(np.percentile(vals, [5, 50, 95]))))
for o in [o for o in bpy.data.objects if o.name in ("TampoAO", "CabecaAO", "Corpo")]:
    bpy.data.objects.remove(o, do_unlink=True)
if tampos is not None:
    bpy.ops.wm.save_mainfile()
print("[ao] ok", saida)
