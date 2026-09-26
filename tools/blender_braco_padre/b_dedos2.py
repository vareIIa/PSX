"""Linha central dos 5 dedos: da ponta (dada aproximada, ajustada ao maximo
geodesico perto dela) ate o punho, pelo caminho mais curto na pele; em cada
ponto do caminho, o centro da bola geodesica local (o miolo do dedo).

blender -b <blend com mao_jogo> --python b_dedos2.py -- <saida.json>
"""
import sys, json, heapq
import bpy
import numpy as np

argv = sys.argv[sys.argv.index("--") + 1:]
saida = argv[0]
PUNHO_Y = -0.40
# pontas aproximadas (y, z) lidas da foto do dorso (+x)
PONTAS = {"polegar": (-0.620, 0.142), "indicador": (-0.665, 0.180),
          "medio": (-0.687, 0.214), "anelar": (-0.672, 0.250), "minimo": (-0.645, 0.315)}
if len(argv) > 1:
    cfg = json.load(open(argv[1]))
    PUNHO_Y = cfg["punho_y"]
    PONTAS = {k: tuple(v) for k, v in cfg["pontas"].items()}
BOLA = 0.011  # raio geodesico da bola do miolo (m)
PASSO = 0.004

ob = bpy.data.objects["mao_jogo"]
me = ob.data
mw = np.array(ob.matrix_world)
co = np.array([v.co[:] for v in me.vertices])
co = co @ mw[:3, :3].T + mw[:3, 3]
n = len(co)
dentro = co[:, 1] < PUNHO_Y + 0.02
viz = [[] for _ in range(n)]
for e in me.edges:
    a, b = e.vertices
    if dentro[a] and dentro[b]:
        w = float(np.linalg.norm(co[a] - co[b]))
        viz[a].append((b, w))
        viz[b].append((a, w))


def dijkstra(fontes, limite=np.inf):
    dist = {}
    pred = {}
    fila = [(0.0, s, -1) for s in fontes]
    heapq.heapify(fila)
    while fila:
        d, a, p = heapq.heappop(fila)
        if a in dist:
            continue
        dist[a] = d
        pred[a] = p
        if d > limite:
            continue
        for b, w in viz[a]:
            if b not in dist:
                heapq.heappush(fila, (d + w, b, a))
    return dist, pred


fontes = [int(i) for i in np.nonzero(dentro & (co[:, 1] > PUNHO_Y - 0.004) & (co[:, 1] < PUNHO_Y + 0.004))[0]]
dist, pred = dijkstra(fontes)
print("[dedos2] vertices alcancados", len(dist))
res = {}
for nome, (ty, tz) in PONTAS.items():
    cand = [i for i in dist if abs(co[i, 1] - ty) < 0.015 and abs(co[i, 2] - tz) < 0.015]
    ponta = max(cand, key=lambda i: dist[i])
    cam = [ponta]
    while pred[cam[-1]] >= 0:
        cam.append(pred[cam[-1]])
    # amostra a cada PASSO de distancia
    pts = []
    raios = []
    alvo = dist[ponta]
    for i in cam:
        if dist[i] <= alvo:
            d_loc, _ = dijkstra([i], BOLA)
            ids = np.array([j for j, dj in d_loc.items() if dj <= BOLA])
            c = co[ids].mean(axis=0)
            pts.append({"d": dist[i], "c": c.tolist(), "sup": co[i].tolist(),
                        "r": float(np.linalg.norm(co[ids] - c, axis=1).mean())})
            alvo -= PASSO
    res[nome] = {"ponta": co[ponta].tolist(), "comp": dist[ponta], "pts": pts}
    print("[dedos2] %-9s ponta=(%.3f %.3f %.3f) comp=%.3f pontos=%d" % (
        nome, co[ponta, 0], co[ponta, 1], co[ponta, 2], dist[ponta], len(pts)))
json.dump(res, open(saida, "w"))
