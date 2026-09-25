"""Monta os atlas dos impostores da mata a partir dos quadros assados.

Entrada: a pasta que `game/tests/assar_impostores.tscn` escreveu (quadros de
1024 px, cor e normal, mais meta.json). Saida, em game/assets/impostores/:

  <nome>_cor.png   atlas RGBA (sRGB): colunas = azimutes, linhas = elevacoes
  <nome>_nrm.png   atlas RGB: a normal no espaco da arvore, n * 0,5 + 0,5
  impostores.json  raio, centro e grade de cada variante (o jogo le daqui)

O que este passo faz alem de colar:
- Reduz cada quadro pela METADE com alfa pre-multiplicado. O assador desenha em
  1024 com MSAA; a reducao da a borda da folha um alfa macio, que e o que o
  shader afia de novo em qualquer distancia (e o mip nao come a copa).
- Empurra a cor para dentro do transparente (push-pull). Sem isso o fundo do
  quadro e preto, e o mip de longe mistura esse preto na borda de toda copa:
  aureola escura em volta de cada arvore contra a nevoa clara.

  python tools/montar_impostores.py PASTA_DOS_QUADROS [--quadro=512]
"""
import json
import os
import sys

import numpy as np
from PIL import Image

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SAIDA = os.path.join(RAIZ, "game", "assets", "impostores")


def reduzir(rgba, alvo):
    """Reduz com alfa pre-multiplicado (media de caixa, fator inteiro)."""
    h, w = rgba.shape[:2]
    f = h // alvo
    a = rgba[..., 3:4]
    pre = np.concatenate([rgba[..., :3] * a, a], axis=-1)
    pre = pre.reshape(alvo, f, alvo, f, 4).mean(axis=(1, 3))
    a2 = pre[..., 3:4]
    cor = np.where(a2 > 1e-5, pre[..., :3] / np.maximum(a2, 1e-5), 0.0)
    return np.concatenate([cor, a2], axis=-1)


def empurrar(cor, peso):
    """Push-pull: preenche onde peso ~ 0 com a media das vizinhancas cheias."""
    niveis = [(cor * peso[..., None], peso)]
    c, p = niveis[0]
    while c.shape[0] > 1 and c.shape[1] > 1:
        h, w = c.shape[0] // 2, c.shape[1] // 2
        c = c[: h * 2, : w * 2].reshape(h, 2, w, 2, -1).sum(axis=(1, 3))
        p = p[: h * 2, : w * 2].reshape(h, 2, w, 2).sum(axis=(1, 3))
        niveis.append((c, p))
    # Desce preenchendo: cada nivel pega do de cima onde nao tem peso proprio.
    cheio = niveis[-1][0] / np.maximum(niveis[-1][1], 1e-6)[..., None]
    for c, p in reversed(niveis[:-1]):
        cima = np.repeat(np.repeat(cheio, 2, axis=0), 2, axis=1)
        cima = np.pad(cima, ((0, c.shape[0] - cima.shape[0]), (0, c.shape[1] - cima.shape[1]), (0, 0)),
                      mode="edge")
        proprio = c / np.maximum(p, 1e-6)[..., None]
        k = np.clip(p, 0.0, 1.0)[..., None]
        cheio = proprio * k + cima * (1.0 - k)
    return cheio


IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="res://assets/impostores/%s"

[params]

compress/mode=2
compress/high_quality=true
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=2
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=false
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
"""


def importar(nome_png):
    """O .import de cada atlas: BC7 com mip, e a normal NAO vira mapa de normal
    (e normal do espaco da arvore em RGB; o modo de mapa de normal guardaria so
    dois canais)."""
    caminho = os.path.join(SAIDA, nome_png + ".import")
    if not os.path.exists(caminho):
        open(caminho, "w", encoding="utf-8", newline="\n").write(IMPORT % nome_png)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    pasta = sys.argv[1]
    alvo = 512
    limpo = False
    for arg in sys.argv[2:]:
        if arg.startswith("--quadro="):
            alvo = int(arg.split("=")[1])
        elif arg == "--limpo":
            # O json lista so as variantes desta assada (as antigas saem da mata).
            limpo = True
    meta = json.load(open(os.path.join(pasta, "meta.json"), encoding="utf-8"))
    colunas = int(meta["azimutes"])
    linhas = len(meta["elevacoes"])
    os.makedirs(SAIDA, exist_ok=True)
    antigo = {}
    caminho_json = os.path.join(SAIDA, "impostores.json")
    if os.path.exists(caminho_json) and not limpo:
        antigo = {v["nome"]: v for v in json.load(open(caminho_json, encoding="utf-8"))["variantes"]}
    for v in meta["variantes"]:
        nome = v["nome"]
        cor_atlas = np.zeros((linhas * alvo, colunas * alvo, 4), np.float32)
        nrm_atlas = np.zeros((linhas * alvo, colunas * alvo, 3), np.float32)
        for fila in range(linhas):
            for col in range(colunas):
                c = np.asarray(Image.open(os.path.join(pasta, "%s_cor_%d_%d.png" % (nome, fila, col)))
                               .convert("RGBA"), np.float32) / 255.0
                n = np.asarray(Image.open(os.path.join(pasta, "%s_nrm_%d_%d.png" % (nome, fila, col)))
                               .convert("RGBA"), np.float32) / 255.0
                c = reduzir(c, alvo)
                # A normal reduz pesada pela mesma cobertura, e renormaliza.
                n = reduzir(n, alvo)
                vec = n[..., :3] * 2.0 - 1.0
                vec /= np.maximum(np.linalg.norm(vec, axis=-1, keepdims=True), 1e-5)
                peso = (c[..., 3] > 0.02).astype(np.float32) * c[..., 3]
                cor = empurrar(c[..., :3], peso)
                vec = empurrar(vec, peso)
                vec /= np.maximum(np.linalg.norm(vec, axis=-1, keepdims=True), 1e-5)
                y, x = fila * alvo, col * alvo
                cor_atlas[y:y + alvo, x:x + alvo, :3] = cor
                cor_atlas[y:y + alvo, x:x + alvo, 3] = c[..., 3]
                nrm_atlas[y:y + alvo, x:x + alvo] = vec * 0.5 + 0.5
        Image.fromarray((np.clip(cor_atlas, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(
            os.path.join(SAIDA, nome + "_cor.png"), optimize=True)
        Image.fromarray((np.clip(nrm_atlas, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB").save(
            os.path.join(SAIDA, nome + "_nrm.png"), optimize=True)
        importar(nome + "_cor.png")
        importar(nome + "_nrm.png")
        antigo[nome] = {"nome": nome, "raio": v["raio"], "centro": v["centro"],
                        "altura": v["altura"], "base_y": v["base_y"]}
        print("%s: %s" % (nome, os.path.getsize(os.path.join(SAIDA, nome + "_cor.png"))))
    json.dump({"azimutes": colunas, "elevacoes": meta["elevacoes"], "quadro": alvo,
               "variantes": [antigo[k] for k in sorted(antigo)]},
              open(caminho_json, "w", encoding="utf-8"), indent=1)


if __name__ == "__main__":
    main()
