"""Utilidades comuns dos scripts do crucifixo (Blender 5.2, sem janela).

Convencao de eixos durante a modelagem (Blender): Z para cima ao longo da
haste, o corpo olha para -Y (vista de frente do Blender). Na exportacao o
objeto gira 180 graus em Z: o glTF manda Blender -Y para +Z, e o Godot quer
o corpo olhando para -Z.
"""
import os, math
import bpy, bmesh
import numpy as np
from mathutils import Vector, Matrix

RASC = os.environ.get("CRUZ_RASC", r"C:\Users\Administrator\AppData\Local\Temp\claude\c--Users-Administrator-Documents-Codes-Games-PSX\9adae52a-b195-45f6-a31b-65da15e595f3\scratchpad\cruz")
AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.normpath(os.path.join(AQUI, "..", ".."))
SAIDA = os.path.join(RAIZ, "game", "assets", "monstros", "padre", "cruz")


def limpar():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for col in (bpy.data.meshes, bpy.data.materials, bpy.data.images, bpy.data.curves,
                bpy.data.lights, bpy.data.cameras):
        for d in list(col):
            if d.users == 0:
                col.remove(d)


def ligar(ob):
    bpy.context.scene.collection.objects.link(ob)
    return ob


def malha(nome, verts, faces, edges=()):
    me = bpy.data.meshes.new(nome)
    me.from_pydata([tuple(map(float, v)) for v in verts], list(edges), [tuple(map(int, f)) for f in faces])
    me.update()
    return ligar(bpy.data.objects.new(nome, me))


def co_de(ob):
    n = len(ob.data.vertices)
    a = np.empty(n * 3)
    ob.data.vertices.foreach_get("co", a)
    return a.reshape(-1, 3)


def por_co(ob, a):
    ob.data.vertices.foreach_set("co", np.ascontiguousarray(a, dtype=np.float64).ravel())
    ob.data.update()


def normais_de(ob):
    me = ob.data
    n = len(me.vertices)
    a = np.empty(n * 3)
    me.vertex_normals.foreach_get("vector", a)
    return a.reshape(-1, 3)


def aplicar(ob, manter=()):
    """Aplica todos os modificadores pelo grafo avaliado (sem operador)."""
    dg = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(dg)
    me = bpy.data.meshes.new_from_object(ev, preserve_all_data_layers=True, depsgraph=dg)
    velho = ob.data
    for m in list(ob.modifiers):
        if m.name not in manter:
            ob.modifiers.remove(m)
    ob.data = me
    if velho.users == 0:
        bpy.data.meshes.remove(velho)
    return ob


def remesh(ob, voxel, suave=True):
    m = ob.modifiers.new("remesh", "REMESH")
    m.mode = "VOXEL"
    m.voxel_size = voxel
    m.adaptivity = 0.0
    m.use_smooth_shade = suave
    return aplicar(ob)


def suavizar(ob, fator=0.5, rep=5):
    m = ob.modifiers.new("suave", "SMOOTH")
    m.factor = fator
    m.iterations = rep
    return aplicar(ob)


def juntar(obs, nome):
    """Junta objetos numa malha so (bmesh), aplicando a matriz de cada um."""
    bpy.context.view_layer.update()
    bm = bmesh.new()
    for o in obs:
        me = o.data.copy()
        me.transform(o.matrix_world)
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    for o in obs:
        bpy.data.objects.remove(o, do_unlink=True)
    return ligar(bpy.data.objects.new(nome, me))


def suave(ob, on=True):
    ob.data.shade_smooth() if on else ob.data.shade_flat()


def tris(ob):
    ob.data.calc_loop_triangles()
    return len(ob.data.loop_triangles)


def cadeia_skin(nome, pts, sub=2):
    """Cadeia de vertices com raio (x, y, z, r) ou (x, y, z, rx, ry) + Skin + Subsurf."""
    verts = [p[:3] for p in pts]
    edges = [(i, i + 1) for i in range(len(pts) - 1)]
    ob = malha(nome, verts, [], edges)
    sk = ob.modifiers.new("skin", "SKIN")
    sk.use_smooth_shade = True
    sk.branch_smoothing = 0.0
    sv = ob.data.skin_vertices[0].data
    for i, p in enumerate(pts):
        rx = p[3]
        ry = p[4] if len(p) > 4 else p[3]
        sv[i].radius = (rx, ry)
        sv[i].use_root = (i == 0)
    s = ob.modifiers.new("sub", "SUBSURF")
    s.levels = sub
    s.render_levels = sub
    return aplicar(ob)


def esfera_cubo(nome, n=48, raio=1.0):
    """Esfera de quads (cubo subdividido e normalizado): densidade quase uniforme."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=2.0)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=n - 1, use_grid_fill=True)
    for v in bm.verts:
        v.co = v.co.normalized() * raio
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    return ligar(bpy.data.objects.new(nome, me))


def tubo(nome, pontos, raios, lados=8, fechar=True, laco=False):
    """Tubo por quadros de transporte paralelo ao longo de uma polilinha."""
    P = [Vector(p) for p in pontos]
    n = len(P)
    T = []
    for i in range(n):
        if laco:
            t = P[(i + 1) % n] - P[(i - 1) % n]
        else:
            t = P[min(i + 1, n - 1)] - P[max(i - 1, 0)]
        T.append(t.normalized())
    ref = Vector((0, 0, 1)) if abs(T[0].z) < 0.9 else Vector((1, 0, 0))
    N = [(ref - T[0] * ref.dot(T[0])).normalized()]
    for i in range(1, n):
        v = N[-1] - T[i] * N[-1].dot(T[i])
        N.append(v.normalized())
    verts, faces = [], []
    for i in range(n):
        B = T[i].cross(N[i])
        r = raios[i] if hasattr(raios, "__len__") else raios
        for k in range(lados):
            a = 2 * math.pi * k / lados
            verts.append(P[i] + (N[i] * math.cos(a) + B * math.sin(a)) * r)
    m = n if laco else n - 1
    for i in range(m):
        j = (i + 1) % n
        for k in range(lados):
            kk = (k + 1) % lados
            faces.append((i * lados + k, i * lados + kk, j * lados + kk, j * lados + k))   # normal para fora
    if fechar and not laco:
        c0 = len(verts)
        verts.append(P[0])
        verts.append(P[-1])
        for k in range(lados):
            kk = (k + 1) % lados
            faces.append((c0, kk, k))
            faces.append((c0 + 1, (n - 1) * lados + k, (n - 1) * lados + kk))
    return malha(nome, verts, faces)


def ligar_hip():
    cena = bpy.context.scene
    cena.render.engine = "CYCLES"
    try:
        pr = bpy.context.preferences.addons["cycles"].preferences
        pr.compute_device_type = "HIP"
        pr.refresh_devices()
        ok = False
        for d in pr.devices:
            d.use = ("9070" in d.name)
            ok = ok or d.use
        cena.cycles.device = "GPU" if ok else "CPU"
    except Exception as e:
        print("[hip] sem GPU:", e)
        cena.cycles.device = "CPU"
    print("[hip] device", cena.cycles.device)
