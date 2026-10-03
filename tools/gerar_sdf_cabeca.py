"""O campo de distancia com sinal da cabeca dos padres de fundo (`CabecaDeFundo`,
a pele `CabecaDoPadre._malha_pele`), para a `BatinaAAA` e o `PanoGPU` tirarem o
pano de dentro dela (`BatinaAAA.CABECA_SDF`). So os padres que NAO sao o
principal leem este campo: o principal fica sem ele.

Por que: o pano colide na placa com capsulas (o cranio e o pescoco), mas o que
se desenha e a grade mais um desvio por vertice de ate ~15 cm: a parede de
dentro do capuz e a barra dele passavam pela orelha, pela mandibula e pelo
cranio (a `SondaDoCapuz` mediu). O shader e a fisica leem a distancia da pele
de verdade (com orelha, queixo e o pescoco dela) e empurram o pano para fora.

    python tools/gerar_sdf_cabeca.py [DIR_DE_TRABALHO]

1. o Godot despeja a pele da cabeca de fundo (`--despejar`);
2. aqui: distancia sem sinal pela arvore dos vertices e centros de triangulo,
   o sinal pelo que o lado de fora alcanca (preenchimento a partir da borda da
   grade; perto da pele, pela normal do vertice mais perto);
3. o Godot monta a textura 3D (meio float, metros da pessoa de 1,72 m).

Base: `tools/gerar_sdf_cabeca.py` da frente CAPUZ (worktree PSX_capuz), que
fazia o minimo das duas peles (principal e fundo).
"""
import json
import os
import subprocess
import sys

import numpy as np
from scipy import ndimage
from scipy.spatial import cKDTree

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(AQUI)
G = os.environ.get("GODOT", os.path.join(RAIZ, ".tools", "Godot_v4.7.2-stable_win64_console.exe"))
if not os.path.exists(G):
    G = os.path.join(os.path.dirname(RAIZ), "PSX", ".tools", "Godot_v4.7.2-stable_win64_console.exe")
PASSO = 0.004
MARGEM = 0.04
PELES = ("fundo",)


def godot(*args):
    r = subprocess.run([G, "--headless", "--path", os.path.join(RAIZ, "game"),
                        "res://scenes/test/gerar_sdf_cabeca.tscn", "--"] + list(args),
                       capture_output=True, text=True)
    for l in (r.stdout + r.stderr).splitlines():
        if "gerar_sdf_cabeca" in l or "ERROR" in l:
            print(l)


def sdf_da_malha(v, n, ind, centros_grade, forma):
    tri = v[ind]
    amostras = np.concatenate([v, tri.mean(1)])
    arv = cKDTree(amostras)
    du, _ = arv.query(centros_grade)
    livre = (du > PASSO * 0.75).reshape(forma)
    rot, _n = ndimage.label(livre)
    borda = set(np.unique(np.concatenate([rot[0].ravel(), rot[-1].ravel(), rot[:, 0].ravel(),
                                           rot[:, -1].ravel(), rot[:, :, 0].ravel(), rot[:, :, -1].ravel()])))
    borda.discard(0)
    fora = np.isin(rot, list(borda)).ravel()
    dentro = livre.ravel() & ~fora
    faixa = ~livre.ravel()
    arv_v = cKDTree(v)
    _d, i = arv_v.query(centros_grade[faixa], k=8)
    lado = np.sum((centros_grade[faixa][:, None, :] - v[i]) * n[i], -1)
    fora_faixa = np.sum(lado > 0, 1) >= 4
    sinal = np.where(fora, 1.0, -1.0)
    sinal[np.where(faixa)[0]] = np.where(fora_faixa, 1.0, -1.0)
    sinal[dentro] = -1.0
    return du * sinal


def main():
    d = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else os.path.join(RAIZ, ".sdf_cabeca")
    os.makedirs(d, exist_ok=True)
    if "--sem-godot" not in sys.argv:
        godot("--despejar=" + d)
    malhas = []
    for nome in PELES:
        p = os.path.join(d, nome + "_pos.f32")
        if not os.path.exists(p):
            continue
        v = np.fromfile(p, np.float32).reshape(-1, 3).astype(np.float64)
        n = np.fromfile(os.path.join(d, nome + "_nor.f32"), np.float32).reshape(-1, 3).astype(np.float64)
        ind = np.fromfile(os.path.join(d, nome + "_ind.i32"), np.int32).reshape(-1, 3)
        malhas.append((nome, v, n, ind))
    lo = np.min([m[1].min(0) for m in malhas], 0) - MARGEM
    hi = np.max([m[1].max(0) for m in malhas], 0) + MARGEM
    nn = np.ceil((hi - lo) / PASSO).astype(int)
    tam = nn * PASSO
    xs = lo[0] + (np.arange(nn[0]) + 0.5) * PASSO
    ys = lo[1] + (np.arange(nn[1]) + 0.5) * PASSO
    zs = lo[2] + (np.arange(nn[2]) + 0.5) * PASSO
    Z, Y, X = np.meshgrid(zs, ys, xs, indexing="ij")
    centros = np.stack([X.ravel(), Y.ravel(), Z.ravel()], -1)
    forma = (nn[2], nn[1], nn[0])
    sdf = None
    for nome, v, n, ind in malhas:
        s = sdf_da_malha(v, n, ind, centros, forma)
        sdf = s if sdf is None else np.minimum(sdf, s)
        print("[sdf] %s: %d vertices, %d dentro" % (nome, len(v), int(np.sum(s < 0))))
    sdf = sdf.astype(np.float32)
    sdf.tofile(os.path.join(d, "sdf.f32"))
    json.dump({"n": nn.tolist(), "minimo": lo.tolist(), "tamanho": tam.tolist(), "passo": PASSO,
               "peles": list(PELES)}, open(os.path.join(d, "sdf.json"), "w"))
    # Conferencia pelo trilinear nos vertices (deve dar ~0) e no centro (< 0).
    from scipy.ndimage import map_coordinates
    for nome, v, n, ind in malhas:
        c = (v - lo) / PASSO - 0.5
        val = map_coordinates(sdf.reshape(forma), [c[:, 2], c[:, 1], c[:, 0]], order=1)
        print("[sdf] %s na pele: p5 %.1f mm p50 %.1f mm p95 %.1f mm" % (nome, *(np.percentile(val, [5, 50, 95]) * 1000)))
    c0 = (np.array([[0.0, 0.0, 0.0]]) - lo) / PASSO - 0.5
    print("[sdf] centro: %.1f mm; grade %s, de %s ate %s" % (
        map_coordinates(sdf.reshape(forma), [c0[:, 2], c0[:, 1], c0[:, 0]], order=1)[0] * 1000,
        nn.tolist(), lo.round(3).tolist(), hi.round(3).tolist()))
    if "--sem-godot" not in sys.argv:
        godot("--montar=" + d)


if __name__ == "__main__":
    main()
