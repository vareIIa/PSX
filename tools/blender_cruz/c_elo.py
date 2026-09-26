"""Um elo da corrente (oval alongado de ferro escuro), exportado em elo.glb.

blender -b --factory-startup --python c_elo.py -- <saida.glb> <pasta_rascunho>

Elo: 16 mm de comprimento externo, 10 mm de largura externa, fio de 2,6 mm.
Linha de centro: oval de quatro arcos (ponta de raio 3,0 mm >= o fio, entao o
elo seguinte encosta exatamente na ponta de dentro) com meia-comprimento
6,7 mm e meia-largura 3,7 mm. Secao de 5 lados com um vertice apontando para
fora no plano do elo: a medida externa fecha exata.
PASSO (centro a centro de dois elos encaixados) = 16 - 2 x 2,6 = 10,8 mm.
Eixos no Godot: comprido em Y, plano do anel em XY, centro na origem.
(No Blender: comprido em Z, plano XZ; o exportador leva Z->Y e -Y->Z.)
"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import numpy as np
from mathutils import Vector
from c_comum import *

argv = sys.argv[sys.argv.index("--") + 1:]
SAIDA_GLB, PASTA = argv[0], argv[1]
C_EXT, L_EXT, FIO = 0.016, 0.010, 0.0026
r = FIO / 2
a, b, r1 = C_EXT / 2 - r, L_EXT / 2 - r, 0.0030          # 6,7 / 3,7 / 3,0 mm
R = (b * b + (a - r1) ** 2 - r1 * r1) / (2 * (b - r1))  # raio do arco do lado (13,13 mm)
PASSO = C_EXT - 2 * FIO
limpar()


def ponto(tang):
    """Ponto da linha de centro no 1o quadrante pelo angulo da tangente (0 = ponta de cima)."""
    lim = math.atan2(a - r1, R - b)                       # angulo em que o arco da ponta vira arco do lado
    ang = math.pi / 2 - tang                              # angulo polar em torno do centro do arco
    if ang >= lim:
        return Vector((r1 * math.cos(ang), (a - r1) + r1 * math.sin(ang)))
    return Vector(((b - R) + R * math.cos(ang), R * math.sin(ang)))


# 16 pontos: ponta, 22,5, 45, 67,5 graus e o lado, em cada quadrante
quad = [ponto(math.radians(t)) for t in (0.0, 22.5, 45.0, 67.5)]
pts2 = []
for q in quad:                                   # de cima (ponta) descendo pela direita
    pts2.append((q.x, q.y))
pts2.append((b, 0.0))
for q in reversed(quad[1:]):
    pts2.append((q.x, -q.y))
pts2.append((0.0, -a))
for q in quad[1:]:
    pts2.append((-q.x, -q.y))
pts2.append((-b, 0.0))
for q in reversed(quad[1:]):
    pts2.append((-q.x, q.y))
N = len(pts2)
assert N == 16, N
LADOS = 5
P = [Vector((x, 0.0, y)) for x, y in pts2]          # plano XZ do Blender, comprido em Z
verts, faces, uvs = [], [], []
comp = [0.0]
for i in range(N):
    comp.append(comp[-1] + (P[(i + 1) % N] - P[i]).length)
for i in range(N):
    t = (P[(i + 1) % N] - P[(i - 1) % N]).normalized()
    fora = Vector((0, 1, 0)).cross(t).normalized()       # normal no plano do elo, para fora
    if fora.dot(P[i]) < 0:
        fora = -fora
    y = Vector((0, 1, 0))
    for k in range(LADOS):
        ang = 2 * math.pi * k / LADOS
        verts.append(P[i] + (fora * math.cos(ang) + y * math.sin(ang)) * r)
for i in range(N):
    j = (i + 1) % N
    for k in range(LADOS):
        kk = (k + 1) % LADOS
        faces.append((i * LADOS + k, i * LADOS + kk, j * LADOS + kk, j * LADOS + k))
        u0, u1 = comp[i] / comp[-1], comp[i + 1] / comp[-1]
        v0, v1 = k / LADOS, (k + 1) / LADOS
        uvs.append([(u0, v0), (u0, v1), (u1, v1), (u1, v0)])
# as faces precisam apontar para fora do fio: confere na primeira e inverte todas se preciso
f0 = [verts[q] for q in faces[0]]
nrm = (f0[1] - f0[0]).cross(f0[3] - f0[0])
if nrm.dot((f0[0] + f0[2]) * 0.5 - P[0]) < 0:
    faces = [tuple(reversed(f)) for f in faces]
    uvs = [list(reversed(q)) for q in uvs]
ob = malha("elo", verts, faces)
me = ob.data
uvl = me.uv_layers.new(name="UV")
for f, q in zip(me.polygons, uvs):
    for li, uv in zip(f.loop_indices, q):
        uvl.data[li].uv = uv
suave(ob)

# textura pequena: ferro escuro com ferrugem mais funda por dentro do elo (v ~ 0,5)
S = 128
rng = np.random.default_rng(4)
u = np.linspace(0, 1, S, endpoint=False)[None, :].repeat(S, 0)
v = np.linspace(0, 1, S, endpoint=False)[:, None].repeat(S, 1)


def ruido2(esc, sem):
    g = np.random.default_rng(sem).random((esc, esc))
    x = u * esc
    y = v * esc
    i0, j0 = x.astype(int) % esc, y.astype(int) % esc
    fx, fy = x - np.floor(x), y - np.floor(y)
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    i1, j1 = (i0 + 1) % esc, (j0 + 1) % esc
    return (g[j0, i0] * (1 - fx) * (1 - fy) + g[j0, i1] * fx * (1 - fy)
            + g[j1, i0] * (1 - fx) * fy + g[j1, i1] * fx * fy)


n1 = 0.6 * ruido2(8, 1) + 0.4 * ruido2(24, 2)
dentro = np.exp(-((v - 0.5) / 0.22) ** 2)                  # k=0 e para fora; o meio de v e o lado de dentro
ferr = np.clip((n1 * 0.9 + dentro * 0.45 - 0.55) / 0.25, 0, 1)
ferro = np.stack([0.068, 0.064, 0.059])[None, None, :] * (0.8 + 0.5 * n1[..., None])
rust = np.stack([0.15, 0.062, 0.026])[None, None, :] * (0.7 + 0.6 * ruido2(32, 3)[..., None])
cor = ferro * (1 - ferr[..., None]) + rust * ferr[..., None]
srgb = np.where(cor <= 0.0031308, cor * 12.92, 1.055 * np.power(cor, 1 / 2.4) - 0.055)
orm = np.stack([0.75 + 0.25 * (1 - dentro), 0.55 + 0.35 * ferr, 0.55 - 0.45 * ferr], -1)


def imagem(nome, arr, cs):
    im = bpy.data.images.new(nome, S, S, alpha=False)
    im.colorspace_settings.name = cs          # antes dos pixels: trocar depois regenera a imagem (preta)
    rgba = np.concatenate([arr, np.ones((S, S, 1))], -1).astype(np.float32)
    im.pixels.foreach_set(rgba.ravel())
    im.update()
    im.filepath_raw = os.path.join(PASTA, nome + ".png")
    im.file_format = "PNG"
    im.save()
    return im


os.makedirs(PASTA, exist_ok=True)
i_cor = imagem("elo_cor", srgb, "sRGB")
i_orm = imagem("elo_orm", orm, "Non-Color")
m = bpy.data.materials.new("elo_ferro")
try:
    m.use_nodes = True
except Exception:
    pass
nt = m.node_tree
nt.nodes.clear()
tc = nt.nodes.new("ShaderNodeTexImage")
tc.image = i_cor
to = nt.nodes.new("ShaderNodeTexImage")
to.image = i_orm
sep = nt.nodes.new("ShaderNodeSeparateColor")
bs = nt.nodes.new("ShaderNodeBsdfPrincipled")
out = nt.nodes.new("ShaderNodeOutputMaterial")
nt.links.new(tc.outputs["Color"], bs.inputs["Base Color"])
nt.links.new(to.outputs["Color"], sep.inputs["Color"])
nt.links.new(sep.outputs["Green"], bs.inputs["Roughness"])
nt.links.new(sep.outputs["Blue"], bs.inputs["Metallic"])
nt.links.new(bs.outputs["BSDF"], out.inputs["Surface"])
gl = bpy.data.node_groups.new("glTF Material Output", "ShaderNodeTree")
gl.interface.new_socket(name="Occlusion", in_out="INPUT", socket_type="NodeSocketFloat")
ng = nt.nodes.new("ShaderNodeGroup")
ng.node_tree = gl
nt.links.new(sep.outputs["Red"], ng.inputs["Occlusion"])
m.use_backface_culling = True
me.materials.append(m)
co = co_de(ob)
print("[elo] tris", tris(ob), "caixa", (co.max(0) - co.min(0)).round(5), "R", round(R, 5), "passo", PASSO)
for o in bpy.context.scene.objects:
    o.select_set(o == ob)
bpy.context.view_layer.objects.active = ob
bpy.ops.export_scene.gltf(filepath=SAIDA_GLB, export_format="GLB", use_selection=True, export_yup=True,
                          export_apply=True, export_texcoords=True, export_normals=True, export_tangents=False,
                          export_materials="EXPORT", export_image_format="AUTO", export_animations=False)
print("[elo] glb", SAIDA_GLB)
