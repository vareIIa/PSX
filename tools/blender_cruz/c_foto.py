"""Fotos de julgamento (Cycles) a partir dos .glb EXPORTADOS: fundo cinza escuro, luz chave + contraluz.

blender -b --factory-startup --python c_foto.py -- <crucifixo.glb> <elo.glb> <pasta> <vistas> [amostras]
vistas: frente,34,lado,close,corrente,costas

Os .glb vem no eixo do Godot e o importador devolve Z para cima: o corpo olha
+Y do Blender (= -Z do Godot) e a origem e o centro da argola.
"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector, Matrix
from c_comum import *

argv = sys.argv[sys.argv.index("--") + 1:]
GLB_CRUZ, GLB_ELO, PASTA = argv[0], argv[1], argv[2]
VISTAS = argv[3].split(",")
AMOSTRAS = int(argv[4]) if len(argv) > 4 else 256
PASSO = 0.0108
limpar()
cena = bpy.context.scene
ligar_hip()
cena.cycles.samples = AMOSTRAS
cena.cycles.use_denoising = True
cena.view_settings.view_transform = "AgX"
cena.view_settings.look = "AgX - Medium High Contrast"


def importar(caminho):
    antes = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=caminho)
    novos = [o for o in bpy.data.objects if o not in antes]
    return [o for o in novos if o.type == "MESH"][0]


cruz = importar(GLB_CRUZ)
elo = importar(GLB_ELO)
elo.hide_render = True
print("[foto] cruz tris", tris(cruz), "elo tris", tris(elo))

# mundo: cinza escuro chapado para a camera, gradiente suave para os reflexos do metal
w = bpy.data.worlds.new("W")
cena.world = w
try:
    w.use_nodes = True
except Exception:
    pass
nt = w.node_tree
nt.nodes.clear()
tc = nt.nodes.new("ShaderNodeTexCoord")
sep = nt.nodes.new("ShaderNodeSeparateXYZ")
nt.links.new(tc.outputs["Generated"], sep.inputs["Vector"])
rp = nt.nodes.new("ShaderNodeValToRGB")
rp.color_ramp.elements[0].position = 0.35
rp.color_ramp.elements[0].color = (0.004, 0.004, 0.005, 1)
rp.color_ramp.elements[1].position = 0.75
rp.color_ramp.elements[1].color = (0.11, 0.105, 0.10, 1)
nt.links.new(sep.outputs["Z"], rp.inputs["Fac"])
bg_ref = nt.nodes.new("ShaderNodeBackground")
nt.links.new(rp.outputs["Color"], bg_ref.inputs["Color"])
bg_cam = nt.nodes.new("ShaderNodeBackground")
bg_cam.inputs["Color"].default_value = (0.030, 0.030, 0.032, 1)
lp = nt.nodes.new("ShaderNodeLightPath")
mx = nt.nodes.new("ShaderNodeMixShader")
nt.links.new(lp.outputs["Is Camera Ray"], mx.inputs[0])
nt.links.new(bg_ref.outputs["Background"], mx.inputs[1])
nt.links.new(bg_cam.outputs["Background"], mx.inputs[2])
out = nt.nodes.new("ShaderNodeOutputWorld")
nt.links.new(mx.outputs[0], out.inputs["Surface"])


def luz(nome, pos, alvo, e, tam, cor=(1, 1, 1)):
    ld = bpy.data.lights.new(nome, "AREA")
    ld.energy = e
    ld.size = tam
    ld.color = cor
    lo = bpy.data.objects.new(nome, ld)
    lo.location = pos
    lo.rotation_euler = (Vector(alvo) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
    cena.collection.objects.link(lo)
    return lo


CENTRO = Vector((0, 0.004, -0.085))
luzes = [luz("chave", (-0.30, 0.42, 0.20), CENTRO, 9.0, 0.22, (1.0, 0.93, 0.82)),
         luz("contra", (0.22, -0.42, 0.26), CENTRO, 10.0, 0.12, (0.80, 0.88, 1.0)),
         luz("enche", (0.35, 0.40, -0.25), CENTRO, 1.6, 0.35)]

for l in luzes:     # depuracao: CRUZ_SEM_LUZ=contra,enche apaga luzes pelo nome
    if l.name in os.environ.get("CRUZ_SEM_LUZ", "").split(","):
        l.data.energy = 0.0
cam_d = bpy.data.cameras.new("cam")
cam_d.clip_start = 0.005
cam = bpy.data.objects.new("cam", cam_d)
cena.collection.objects.link(cam)
cena.camera = cam


def mirar(pos, alvo, lente, px):
    cam.location = pos
    cam.rotation_euler = (Vector(alvo) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
    cam_d.lens = lente
    cam_d.sensor_width = 36
    cena.render.resolution_x = px
    cena.render.resolution_y = px


def corrente():
    """13 elos em catenaria (c=0,03 m), alternando 90 graus, com a cruz pendurada no do meio."""
    c = 0.030
    zB = 0.0058                        # centro do elo de baixo acima do centro da argola
    obs = []
    for j in range(-6, 7):
        s = j * PASSO
        x = c * math.asinh(s / c)
        z = c * (math.cosh(x / c) - 1) + zB
        fi = math.atan(s / c)          # angulo da tangente com a horizontal
        # elo no Blender importado: comprido em Z, plano XZ -> deita no comprido (X) e inclina pela tangente
        M = Matrix.Translation((x, 0, z)) @ Matrix.Rotation(fi, 4, "Y").inverted() @ Matrix.Rotation(math.pi / 2, 4, "Y")
        if j % 2:
            M = M @ Matrix.Rotation(math.pi / 2, 4, "Z")
        o = elo.copy()
        o.hide_render = False
        o.matrix_world = M
        cena.collection.objects.link(o)
        obs.append(o)
    return obs


VIS = {
    "frente": ((0, 0.47, -0.083), (0, 0, -0.083), 85, 1600),
    "costas": ((0, -0.47, -0.083), (0, 0, -0.083), 85, 1600),
    "34": ((-0.30, 0.36, -0.03), (0, 0, -0.083), 85, 1600),
    "lado": ((-0.47, 0.0, -0.083), (0, 0, -0.083), 85, 1600),
    "close": ((0.0, 0.150 + 0.012, -0.100), (0.0, 0.012, -0.100), 45, 2048),
    "corrente": ((0.05, 0.75, -0.05), (0.0, 0.0, -0.045), 85, 1600),
    "rosto": ((0.02, 0.070, -0.050), (0.004, 0.012, -0.058), 50, 1400),
    "pes": ((0.0, 0.070, -0.140), (0.0, 0.010, -0.145), 50, 1200),
    "mao": ((0.030, 0.060, -0.052), (0.039, 0.006, -0.052), 50, 1200),
}
nomes = {"frente": "crucifixo_frente", "costas": "crucifixo_costas", "34": "crucifixo_34",
         "lado": "crucifixo_lado", "close": "crucifixo_close", "corrente": "corrente",
         "rosto": "x_rosto", "pes": "x_pes", "mao": "x_mao"}
for v in VISTAS:
    extra = []
    if v == "corrente":
        extra = corrente()
    pos, alvo, lente, px = VIS[v]
    mirar(pos, alvo, lente, px)
    cena.render.filepath = os.path.join(PASTA, nomes[v] + ".png")
    bpy.ops.render.render(write_still=True)
    print("[foto]", cena.render.filepath)
    for o in extra:
        bpy.data.objects.remove(o, do_unlink=True)
