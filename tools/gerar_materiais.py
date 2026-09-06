#!/usr/bin/env python3
"""Gera os ShaderMaterial .tres a partir de uma tabela unica.

Material escrito na mao vira drift: um esquece o use_affine, outro poe uv_tile
diferente sem motivo. A tabela e a fonte da verdade, o .tres e derivado.

    python tools/gerar_materiais.py
"""

from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
DESTINO = RAIZ / "game" / "resources" / "materials"
TEXTURAS = RAIZ / "game" / "assets" / "textures"

MODELO = '''[gd_resource type="ShaderMaterial" load_steps=3 format=3]

[ext_resource type="Shader" path="res://shaders/psx_surface.gdshader" id="1_shader"]
[ext_resource type="Texture2D" path="res://assets/textures/{tex}.png" id="2_tex"]

[resource]
resource_name = "mat_{nome}"
shader = ExtResource("1_shader")
shader_parameter/albedo_tex = ExtResource("2_tex")
shader_parameter/tint = Color({tint}, 1)
shader_parameter/uv_tile = Vector2({tile}, {tile})
shader_parameter/snap_resolution = Vector2(240, 135)
shader_parameter/use_snap = {snap}
shader_parameter/use_affine = {affine}
shader_parameter/alpha_cutoff = 0.0
shader_parameter/emission_color = Color({emis}, 1)
shader_parameter/emission_energy = {energia}
'''

# uv_tile multiplica a UV que o PSXMesh ja gera a 0.5 por metro. Ou seja, o
# numero de repeticoes por metro e 0.5 * uv_tile:
#   uv_tile 1.0  -> um tile a cada 2 m
#   uv_tile 0.5  -> um tile a cada 4 m
# O PS1 trabalhava perto de 32 a 64 pixels por metro. Com textura de 256 px,
# um tile a cada 4 m da 64 px/m, que e o alvo.
#
# nome                textura              uv_tile  tint                 snap     affine
MATERIAIS = [
    # --- chao e rua ---
    ("asfalto",          "asfalto",           0.5, "1, 1, 1",            "true",  "true"),
    ("asfalto_remendo",  "asfalto_remendo",   0.5, "1, 1, 1",            "true",  "true"),
    ("asfalto_faixa",    "asfalto_faixa",     0.5, "1, 1, 1",            "true",  "true"),
    ("calcada",          "calcada",           0.6, "1, 1, 1",            "true",  "true"),
    ("calcada_ladrilho", "calcada_ladrilho",  0.6, "1, 1, 1",            "true",  "true"),
    ("meio_fio",         "meio_fio",          1.0, "1, 1, 1",            "true",  "true"),
    ("terra",            "terra",             0.5, "1, 1, 1",            "true",  "true"),
    # --- paredes externas ---
    ("concreto",         "concreto_parede",   0.6, "1, 1, 1",            "true",  "true"),
    ("concreto_sujo",    "concreto_sujo",     0.6, "1, 1, 1",            "true",  "true"),
    ("azulejo",          "azulejo_fachada",   0.8, "1, 1, 1",            "true",  "true"),
    ("tijolo",           "tijolo",            0.8, "1, 1, 1",            "true",  "true"),
    ("metal_ondulado",   "metal_ondulado",    1.0, "1, 1, 1",            "true",  "true"),
    ("metal_enferrujado","metal_enferrujado", 1.0, "1, 1, 1",            "true",  "true"),
    # --- interiores ---
    ("piso",             "piso_madeira",      0.7, "1, 1, 1",            "true",  "true"),
    ("piso_ceramico",    "piso_ceramico",     0.7, "1, 1, 1",            "true",  "true"),
    ("reboco",           "reboco",            0.6, "1, 1, 1",            "true",  "true"),
    # Teto e o mesmo reboco rebaixado por tint. E a economia descrita na skill
    # psx-assets: variar material sem multiplicar arquivo de textura.
    ("teto",             "reboco",            0.6, "0.62, 0.61, 0.57",   "true",  "true"),
    ("personagem",       "reboco",            1.4, "1, 1, 1",            "true",  "true"),
    ("tabua",            "madeira_tabua",     1.0, "1, 1, 1",            "true",  "true"),
    ("porta",            "porta",             1.0, "1, 1, 1",            "true",  "true"),
    # --- fontes de luz propria, a assinatura da rua noturna ---
    ("vitrine",          "reboco",            0.6, "1, 1, 1",            "true",  "true"),
    ("maquina_venda",    "calcada_ladrilho",  1.4, "1, 1, 1",            "true",  "true"),
    ("janela_acesa",     "reboco",            1.2, "1, 0.94, 0.8",       "true",  "true"),
    ("letreiro",         "azulejo_fachada",   1.6, "1, 1, 1",            "true",  "true"),
    ("janela_apagada",   "metal",             1.2, "0.14, 0.16, 0.18",   "true",  "true"),
    # Objeto pequeno e colado na camera: snap nele vira ruido estroboscopico.
    # ART-BIBLE secao 3.
    ("metal",            "metal",             1.0, "1, 1, 1",            "false", "false"),
]


# Materiais que emitem luz propria. Cor e energia da emissao.
EMISSIVOS: dict[str, tuple[str, float]] = {
    "vitrine":       ("1, 0.95, 0.86", 1.35),
    "maquina_venda": ("1, 0.93, 0.85", 2.0),
    "janela_acesa":  ("1, 0.82, 0.55", 0.95),
    "letreiro":      ("1, 0.5, 0.38",  2.2),
    "personagem":    ("0.55, 0.6, 0.62", 0.42),
}


def main() -> int:
    DESTINO.mkdir(parents=True, exist_ok=True)
    existentes = {p.stem for p in DESTINO.glob("mat_*.tres")}
    gerados: set[str] = set()
    faltando: list[str] = []

    for nome, tex, tile, tint, snap, affine in MATERIAIS:
        if not (TEXTURAS / f"{tex}.png").exists():
            faltando.append(f"mat_{nome} -> {tex}.png")
            continue
        alvo = DESTINO / f"mat_{nome}.tres"
        emis, energia = EMISSIVOS.get(nome, ("0, 0, 0", 0.0))
        alvo.write_text(MODELO.format(nome=nome, tex=tex, tile=f"{tile:g}",
                                      tint=tint, snap=snap, affine=affine,
                                      emis=emis, energia=f"{energia:g}"),
                        encoding="utf-8")
        gerados.add(alvo.stem)
        print(f"mat_{nome:18s} <- {tex}.png   uv_tile {tile:g}")

    for orfao in sorted(existentes - gerados):
        (DESTINO / f"{orfao}.tres").unlink()
        print(f"removido {orfao}.tres (fora da tabela)")

    if faltando:
        print("\ntextura ausente para:")
        for f in faltando:
            print("  ", f)
        return 1

    print(f"\n{len(gerados)} materiais")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
