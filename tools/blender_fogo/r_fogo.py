# A chama do incendio do capo, simulada de verdade (Mantaflow) e fotografada
# quadro a quadro (Cycles), para virar o flipbook do `IncendioDoCapo`.
#
#   blender -b --python r_fogo.py -- <dir> [res] [quadros] [px] [forca] [ruido]
#   (o do jogo: 176 60 256 6 0 — ver fazer.sh)
#
# Uma lingua de fogo de motor: tres bocas desiguais ao longo de uma fresta de
# 0,34 m soltam combustivel pulsando, o gas queima e sobe, e a lente e
# ortografica, de lado, no preto. So emissao: a densidade fica em zero, a
# chama e a luz dela. A fumaca e outra coisa (a particula de fumaca do jogo).
#
# Saida: <dir>/quadros/q_NNNN.png (cinza 8 bits, vista Standard: so a
# intensidade; a cor e a rampa do shader do jogo) do quadro INICIO em diante;
# `montar_atlas.py` junta.
import bpy
import os
import sys
import time

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
DIR = os.path.abspath(argv[0] if argv else "fogo_obra")
RES = int(argv[1]) if len(argv) > 1 else 112
QUADROS = int(argv[2]) if len(argv) > 2 else 64
PX = int(argv[3]) if len(argv) > 3 else 256
FORCA = float(argv[4]) if len(argv) > 4 else 9.0
# A malha fina do ruido (upres) deixava a chama felpuda, como fumaca: sem ela e
# com a grade base mais fina, a lingua sai com a borda da folha de reacao.
RUIDO = (argv[5] == "1") if len(argv) > 5 else False
# O gas leva uns 35 quadros para encher a coluna; antes disso a chama e um
# toco subindo.
INICIO = 40
FIM = INICIO + QUADROS - 1
os.makedirs(os.path.join(DIR, "quadros"), exist_ok=True)


def log(*a):
    print("[r_fogo]", *a, flush=True)


bpy.ops.wm.read_factory_settings(use_empty=True)
cena = bpy.context.scene
cena.render.fps = 30
cena.frame_start = 1
cena.frame_end = FIM

# --- dominio: 0,7 x 0,5 x 1,4 m, o chao em z = 0 ---------------------------
LARG, PROF, ALT = 0.7, 0.5, 1.4
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0.0, ALT * 0.5))
dom = bpy.context.active_object
dom.name = "Dominio"
dom.scale = (LARG, PROF, ALT)
bpy.ops.object.transform_apply(scale=True)
mod = dom.modifiers.new("Fluido", "FLUID")
mod.fluid_type = "DOMAIN"
ds = mod.domain_settings
ds.domain_type = "GAS"
ds.resolution_max = RES
ds.use_collision_border_top = False
ds.use_collision_border_front = False
ds.use_collision_border_back = False
ds.use_collision_border_left = False
ds.use_collision_border_right = False
ds.vorticity = 0.3
ds.alpha = 0.2
ds.beta = 1.4
ds.burning_rate = 1.3
ds.flame_smoke = 0.0
ds.flame_vorticity = 2.0
ds.flame_ignition = 1.5
ds.flame_max_temp = 3.0
ds.use_noise = RUIDO
ds.noise_scale = 2
ds.noise_strength = 1.4
ds.noise_pos_scale = 2.2
ds.noise_time_anim = 0.35
ds.cache_type = "ALL"
ds.cache_directory = os.path.join(DIR, "cache")
ds.cache_frame_start = 1
ds.cache_frame_end = FIM
ds.cache_data_format = "OPENVDB"

# --- a fresta que solta o combustivel --------------------------------------
# Tres bocas desiguais ao longo da fresta, e nao uma barra: o combustivel sai
# por onde a chapa rasgou, e a base da chama ja nasce com desenho.
BOCAS = [((-0.11, 0.0, 0.05), (0.12, 0.10, 0.04)), ((0.03, 0.01, 0.05), (0.08, 0.08, 0.05)),
    ((0.13, -0.01, 0.05), (0.09, 0.09, 0.035))]
nuvem = bpy.data.textures.new("Pulso", "CLOUDS")
nuvem.noise_scale = 0.08
nuvem.noise_depth = 2
nuvem.contrast = 1.6
fontes = []
for i, (onde, tam) in enumerate(BOCAS):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=onde)
    fonte = bpy.context.active_object
    fonte.name = "Boca%d" % i
    fonte.scale = tam
    bpy.ops.object.transform_apply(scale=True)
    fm = fonte.modifiers.new("Fluido", "FLUID")
    fm.fluid_type = "FLOW"
    fs = fm.flow_settings
    fs.flow_type = "FIRE"
    fs.flow_behavior = "INFLOW"
    fs.flow_source = "MESH"
    fs.fuel_amount = 1.3 + 0.2 * i
    # `surface_distance` e em celulas (padrao 1,5): 0,02 nao soltava nada.
    fs.use_initial_velocity = False
    fs.subframes = 1
    # `hide_render` tira a fonte do bake tambem (a chama nao nascia): so a
    # lente deixa de ve-la.
    fonte.visible_camera = False
    # A boca pulsa: uma textura de nuvem correndo por ela modula o combustivel,
    # e a base da chama deixa de ser uma lamina lisa.
    fs.use_texture = True
    fs.noise_texture = nuvem
    fs.texture_map_type = "AUTO"
    fs.texture_size = 0.6
    for q, z in ((1, 0.0), (FIM, 0.045 * FIM)):
        fs.texture_offset = z + 0.37 * i
        fs.keyframe_insert("texture_offset", frame=q)
    fontes.append(fonte)

# Um sopro de turbulencia: fogo de motor lambe, nao sobe em coluna de vela.
bpy.ops.object.effector_add(type="TURBULENCE", location=(0.0, 0.0, 0.4))
turb = bpy.context.active_object
turb.field.strength = 2.0
turb.field.size = 0.25
turb.field.flow = 0.0

t0 = time.time()
with bpy.context.temp_override(scene=cena, active_object=dom, object=dom,
        selected_objects=[dom], selected_editable_objects=[dom]):
    bpy.ops.fluid.bake_all()
log("bake %.1f s (res %d, %d quadros)" % (time.time() - t0, RES, FIM))

# --- material: so emissao, cor pela chama ----------------------------------
mat = bpy.data.materials.new("Chama")
mat.use_nodes = True
nt = mat.node_tree
for n in list(nt.nodes):
    nt.nodes.remove(n)
saida = nt.nodes.new("ShaderNodeOutputMaterial")
vol = nt.nodes.new("ShaderNodeVolumePrincipled")
vol.inputs["Density"].default_value = 0.0
at = nt.nodes.new("ShaderNodeAttribute")
at.attribute_name = "flame"
# A borda da lingua: a chama do Mantaflow e um campo difuso, e a de verdade
# tem a folha de reacao — borda definida. O degrau suave de 0,22 a 0,8
# recorta a lingua sem serrilhar.
pot = nt.nodes.new("ShaderNodeMapRange")
pot.interpolation_type = "SMOOTHERSTEP"
pot.inputs["From Min"].default_value = 0.22
pot.inputs["From Max"].default_value = 0.8
mult = nt.nodes.new("ShaderNodeMath")
mult.operation = "MULTIPLY"
mult.inputs[1].default_value = FORCA
nt.links.new(at.outputs["Fac"], pot.inputs["Value"])
nt.links.new(pot.outputs["Result"], mult.inputs[0])
# Cinza: quem pinta e a rampa do shader do jogo (ajusta sem voltar aqui).
vol.inputs["Emission Color"].default_value = (1.0, 1.0, 1.0, 1.0)
nt.links.new(mult.outputs["Value"], vol.inputs["Emission Strength"])
nt.links.new(vol.outputs["Volume"], saida.inputs["Volume"])
dom.data.materials.append(mat)

# --- lente e mundo ---------------------------------------------------------
mundo = bpy.data.worlds.new("Preto")
mundo.use_nodes = True
mundo.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.0
cena.world = mundo
cam_d = bpy.data.cameras.new("Lente")
cam_d.type = "ORTHO"
cam_d.ortho_scale = ALT
cam = bpy.data.objects.new("Lente", cam_d)
cena.collection.objects.link(cam)
cam.location = (0.0, -3.0, ALT * 0.5)
cam.rotation_euler = (1.5707963, 0.0, 0.0)
cena.camera = cam

r = cena.render
r.engine = "CYCLES"
r.resolution_x = PX
r.resolution_y = PX * 2
r.resolution_percentage = 100
# Fundo preto opaco: com o filme transparente a emissao pura sai com alfa
# zero, e o PNG (alfa reto) jogava a cor fora.
r.film_transparent = False
r.image_settings.file_format = "PNG"
r.image_settings.color_mode = "BW"
r.image_settings.color_depth = "8"
cena.view_settings.view_transform = "Standard"
cena.view_settings.look = "None"
cena.view_settings.exposure = 0.0
cena.cycles.samples = 64
cena.cycles.use_denoising = False
cena.cycles.volume_step_rate = 0.25
cena.cycles.max_bounces = 0
try:
    prefs = bpy.context.preferences.addons["cycles"].preferences
    prefs.compute_device_type = "HIP"
    prefs.get_devices()
    usou = False
    for d in prefs.devices:
        # So a placa de video: a integrada atrasa e muda o resultado nenhum.
        d.use = d.type == "HIP" and "9070" in d.name
        usou = usou or d.use
    cena.cycles.device = "GPU" if usou else "CPU"
    log("device", cena.cycles.device, [d.name for d in prefs.devices if d.use])
except Exception as ex:
    log("sem HIP:", ex)
    cena.cycles.device = "CPU"

t0 = time.time()
for f in range(INICIO, FIM + 1):
    cena.frame_set(f)
    if f == INICIO or os.environ.get("FOGO_DEPURA"):
        ev = dom.evaluated_get(bpy.context.evaluated_depsgraph_get())
        d2 = ev.modifiers["Fluido"].domain_settings
        fl = list(d2.flame_grid)
        de = list(d2.density_grid)
        te = list(d2.temperature_grid)
        log("quadro", f, "chama max", max(fl) if fl else None, "dens max",
            max(de) if de else None, "temp max", max(te) if te else None,
            "celulas", len(fl))
    r.filepath = os.path.join(DIR, "quadros", "q_%04d.png" % (f - INICIO))
    bpy.ops.render.render(write_still=True)
log("render %.1f s (%d quadros de %dx%d)" % (time.time() - t0, QUADROS, PX, PX * 2))
