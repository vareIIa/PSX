"""Endireita a batina do gerador (curvada para a frente) e poe no quadro do
padre do jogo: em pe, olhando +Y no Blender (-Z no Godot), na pessoa de
referencia de 1,72 m (`Corpo.ALTURA_REF`), pe no chao em z=0.

Duas dobras suaves, nas coordenadas do gerador (Z para cima, frente -Y):
- na cintura: tudo acima do pivo gira para tras TRONCO graus, misturado por
  altura numa faixa de +-FAIXA_CINTURA;
- no pescoco: o capuz gira para tras CABECA graus em volta do pivo do pescoco
  (depois da primeira dobra), misturado pela distancia acima dele.
Depois centra o corpo (miolo da cintura em x=y=0), gira 180 graus em Z e
escala ESCALA. Grava a malha endireitada.

blender -b base.blend --python r_endireitar.py -- <cfg.json> <saida.blend>
"""
import sys, json, math
import bpy
import numpy as np

a = sys.argv[sys.argv.index("--") + 1:]
cfg = json.load(open(a[0]))
saida = a[1]
ob = bpy.data.objects["Batina"]
me = ob.data
n = len(me.vertices)
co = np.empty(n * 3, dtype=np.float64)
me.vertices.foreach_get("co", co)
co = co.reshape(n, 3)

def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)

def gira_x(p, piv, ang):
    # gira em volta do eixo X que passa por piv (y, z); ang por vertice (rad).
    # ang > 0 leva o que esta acima do pivo para +Y (para tras, no gerador).
    y = p[:, 1] - piv[0]
    z = p[:, 2] - piv[1]
    c = np.cos(ang); s = np.sin(ang)
    q = p.copy()
    q[:, 1] = piv[0] + y * c + z * s
    q[:, 2] = piv[1] - y * s + z * c
    return q

cin = cfg["pivo_cintura"]          # [y, z]
w1 = smooth(cin[1] - cfg["faixa_cintura"], cin[1] + cfg["faixa_cintura"], co[:, 2])
p1 = gira_x(co, cin, math.radians(cfg["tronco"]) * w1)
pes = cfg["pivo_pescoco"]          # [y, z], ja depois da primeira dobra
dy = p1[:, 1] - pes[0]
dz = p1[:, 2] - pes[1]
# acima do pivo e na frente da nuca: o capuz
w2 = smooth(-cfg["faixa_pescoco"], cfg["faixa_pescoco"], dz) * smooth(cfg["nuca_y"] + 0.03, cfg["nuca_y"] - 0.03, p1[:, 1])
p2 = gira_x(p1, pes, math.radians(cfg["cabeca"]) * w2)
# centra, gira 180 em Z, escala
cx, cy = cfg["centro_xy"]


def quadro_do_jogo(q):
    q = q.copy()
    q[:, 0] -= cx
    q[:, 1] -= cy
    q[:, 0] *= -1.0
    q[:, 1] *= -1.0
    return q * cfg["escala"]


p2 = quadro_do_jogo(p2)
chao0 = p2[:, 2].min() - cfg.get("chao", 0.0)
p2[:, 2] -= chao0

# As mangas (`r_limpar --mangas`, atributo de face `manga`): nao dobram com a
# cintura (pendem do ombro, no gerador ja na vertical) e vao para o braco do
# corpo (`CorpoAAA`).
lado_v = np.zeros(n, dtype=int)
at = me.attributes.get("manga")
if at is not None:
    for poly in me.polygons:
        v = at.data[poly.index].value
        if v != 0:
            for vi in poly.vertices:
                lado_v[vi] = v
larg = cfg.get("largura")
if larg:
    # A batina do gerador e mais larga que o corpo: estreita por altura (x e,
    # menos, y), em volta do eixo do corpo. O capuz fica (a cabeca e a mesma).
    zs_t = np.array([a[0] for a in larg])
    fs_t = np.array([a[1] for a in larg])
    fx = np.interp(p2[:, 2], zs_t, fs_t)
    fy = 1.0 - (1.0 - fx) * cfg.get("largura_fundo", 0.6)
    corpo = lado_v == 0
    p2[corpo, 0] *= fx[corpo]
    p2[corpo, 1] *= fy[corpo]
mg = cfg.get("mangas")
if mg and (lado_v != 0).any():
    bracos = mg["bracos"]   # por lado do jogo (-1 esq, +1 dir): pontos do eixo (Blender, z para cima)
    pm = quadro_do_jogo(co)
    pm[:, 2] -= chao0
    for sinal_bruto in (-1, 1):
        m = lado_v == sinal_bruto
        if not m.any():
            continue
        q = pm[m]
        lado = 1 if q[:, 0].mean() > 0 else -1
        eixo = np.array(bracos["d" if lado > 0 else "e"])     # [[x, y, z], ...] de cima para baixo
        # O eixo da manga, altura a altura: o meio da caixa de cada fatia de 2
        # cm (a media dos vertices puxava para o lado de mais malha e deixava
        # o antebraco por fora), alisado; abaixo da boca vale o da boca.
        zb = np.arange(q[:, 2].min(), q[:, 2].max() + 0.02, 0.02)
        cen = []
        for z0 in zb:
            f = np.abs(q[:, 2] - z0) < 0.012
            cen.append((q[f, :2].min(0) + q[f, :2].max(0)) * 0.5 if f.sum() > 20 else [np.nan, np.nan])
        cen = np.array(cen)
        ok = ~np.isnan(cen[:, 0])
        # a franja (pouca malha e torta) nao conta: o eixo abaixo da boca e o dela
        cuff = zb[ok].min() + mg.get("franja", 0.06)
        ok &= zb >= cuff
        for k in (0, 1):
            cen[:, k] = np.interp(zb, zb[ok], cen[ok, k])
            cen[:, k] = np.convolve(np.pad(cen[:, k], 3, mode="edge"), np.ones(7) / 7, mode="valid")
        cx_ = np.interp(q[:, 2], zb, cen[:, 0])
        cy_ = np.interp(q[:, 2], zb, cen[:, 1])
        c0 = np.array([cx_.mean(), cy_.mean()])
        # alarga/estreita em volta do proprio eixo e sobe
        q[:, 0] = cx_ + (q[:, 0] - cx_) * mg.get("largura", 1.0)
        q[:, 1] = cy_ + (q[:, 1] - cy_) * mg.get("largura", 1.0)
        z_antes = q[:, 2].copy()
        q[:, 2] += mg.get("sobe", 0.0)
        # o eixo da manga vai para o eixo do braco, altura a altura
        zs_e = eixo[::-1, 2]
        ax = np.interp(q[:, 2], zs_e, eixo[::-1, 0])
        ay = np.interp(q[:, 2], zs_e, eixo[::-1, 1])
        q[:, 0] += ax - cx_
        q[:, 1] += ay - cy_
        p2[m] = q
        print("[endireitar] manga %+d: z %.3f..%.3f, centro (%.3f, %.3f) -> braco" % (
            lado, q[:, 2].min(), q[:, 2].max(), c0[0], c0[1]))
    # o atributo passa a dizer o lado do jogo (x do Blender depois do giro)
    for poly in me.polygons:
        v = at.data[poly.index].value
        if v != 0:
            at.data[poly.index].value = 1 if p2[poly.vertices[0], 0] > 0 else -1
me.vertices.foreach_set("co", p2.reshape(-1))
me.update()
# Tudo em triangulo: `r_grades` rotula faces pelo indice e `r_ligar` le as
# mesmas faces.
import bmesh
bm = bmesh.new()
bm.from_mesh(me)
bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 3])
bm.to_mesh(me)
bm.free()
print("[endireitar] caixa", p2.min(0).round(3), p2.max(0).round(3))
bpy.ops.wm.save_as_mainfile(filepath=saida)
print("[endireitar] ok", saida)
