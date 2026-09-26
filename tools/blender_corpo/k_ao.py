"""Assa a oclusao de ambiente (AO) do corpo AAA dos padres, no repouso do jogo,
com a batina e a cabeca em volta, na UV do gerador.

Por que: o pescoco do corpo fica entre o queixo e a murca, e na janela (o padre
debrucado, a camera de baixo) ele aparecia como um toco cinza chapado aceso
pelo farol. Dentro do capuz, debaixo da murca, na axila e dentro da manga o
corpo quase nao ve o ceu: a AO assada com a roupa em volta escurece isso, e no
Godot `AO_LIGHT_AFFECT` escurece tambem a luz direta ali.

Oclusores: a batina no repouso (`reto.blend`, objeto `Batina`) e a cabeca como
um elipsoide do tamanho do cranio do `Corpo` (`romeiro.json`: `cranio`).

blender -b corpo_jogo.blend --python k_ao.py -- <reto.blend> <romeiro.json> <saida.png> [lado]
"""
import sys, json
import bpy
import numpy as np

a = sys.argv[sys.argv.index("--") + 1:]
reto_blend, romeiro_json, saida = a[0], a[1], a[2]
LADO = int(a[3]) if len(a) > 3 else 2048
AMOSTRAS = 256
ALCANCE = 0.30

corpo = bpy.data.objects["Corpo"]
with bpy.data.libraries.load(reto_blend) as (de, para):
    para.objects = [n for n in de.objects if n == "Batina"]
for o in para.objects:
    bpy.context.scene.collection.objects.link(o)
cr = json.load(open(romeiro_json))["cranio"]
c, m = cr["centro"], cr["meio"]
# Godot (x, y, z) -> Blender do jogo (x, -z, y)
bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=24, radius=1.0, location=(c[0], -c[2], c[1]))
cab = bpy.context.active_object
cab.name = "CabecaAO"
cab.scale = (m[0], m[2], m[1])
# O corpo pode ter armadura: a AO e no repouso da malha.
for md in corpo.modifiers:
    md.show_render = False

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
            break
    except Exception:
        pass
sc.cycles.samples = AMOSTRAS
if sc.world is None:
    sc.world = bpy.data.worlds.new("mundo")
sc.world.light_settings.distance = ALCANCE
img = bpy.data.images.new("corpo_ao", LADO, LADO, alpha=False, float_buffer=True)
img.colorspace_settings.name = "Non-Color"
if not corpo.data.materials:
    corpo.data.materials.append(bpy.data.materials.new("corpo"))
for mat in corpo.data.materials:
    mat.use_nodes = True
    nt = mat.node_tree
    n = nt.nodes.new("ShaderNodeTexImage")
    n.image = img
    nt.nodes.active = n
bpy.ops.object.select_all(action="DESELECT")
corpo.select_set(True)
bpy.context.view_layer.objects.active = corpo
sc.render.bake.margin = 16
sc.render.bake.margin_type = "EXTEND"
bpy.ops.object.bake(type="AO")
px = np.array(img.pixels[:]).reshape(LADO, LADO, 4)[..., 0]
print("[corpo_ao] AO: p5 %.2f p50 %.2f p95 %.2f" % tuple(np.percentile(px, [5, 50, 95])))
st = sc.render.image_settings
st.file_format = "PNG"
st.color_mode = "BW"
st.color_depth = "8"
img.save_render(saida, scene=sc)
print("[corpo_ao] ok", saida)
