# -*- coding: utf-8 -*-
"""Patch carroceria.gd: glass two-sided + MAREA/FUSCA enum + Fusca body."""
from pathlib import Path
path = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\render\carroceria.gd")
text = path.read_text(encoding="utf-8")

# 1) Enum
old_enum = "enum Modelo { SEDA, HATCH, PERUA, PICAPE, TAXI }"
new_enum = "enum Modelo { SEDA, HATCH, PERUA, PICAPE, TAXI, MAREA, FUSCA }"
assert old_enum in text, "enum not found"
text = text.replace(old_enum, new_enum, 1)

# 2) TINTA_FUSCA after TINTA_TAXI
old_taxi = "const TINTA_TAXI := Color(0.94, 0.76, 0.16)"
new_taxi = """const TINTA_TAXI := Color(0.94, 0.76, 0.16)
## Bege sujo/enferrujado das refs do Fusca. Fora da tabela: o Fusca do transito
## tem que ler enferrujado, nao sortear creme limpo de Marea.
const TINTA_FUSCA := Color(0.78, 0.72, 0.62)"""
assert old_taxi in text
text = text.replace(old_taxi, new_taxi, 1)

# 3) MEDIDAS — append MAREA + FUSCA
old_med = """\tModelo.TAXI:   {"c": 4.30, "l": 1.70, "capo": 0.90, "teto": 1.42, "eixo": 2.55, "cabine": 0.46},
}"""
new_med = """\tModelo.TAXI:   {"c": 4.30, "l": 1.70, "capo": 0.90, "teto": 1.42, "eixo": 2.55, "cabine": 0.46},
\t# Marea: comprimento unico para a cabine casar por medida. Detalhe e de Renato.
\tModelo.MAREA:  {"c": 4.39, "l": 1.74, "capo": 0.92, "teto": 1.44, "eixo": 2.59, "cabine": 0.48},
\t# Fusca: proporcao de besouro, NAO sedan. Curto, estreito, teto alto, eixo curto.
\tModelo.FUSCA:  {"c": 4.02, "l": 1.54, "capo": 0.84, "teto": 1.50, "eixo": 2.40, "cabine": 0.42},
}"""
assert old_med in text, "MEDIDAS block not found"
text = text.replace(old_med, new_med, 1)

# 4) montar() — tint/suja + branch Fusca
old_montar_body = """\tvar cor := TINTA_TAXI if modelo == Modelo.TAXI else tinta
\tvar suja := (semente % 7) == 0

\tvar corpo := PSXMesh.dados_vazios()
\tvar luzes := PSXMesh.dados_vazios()

\t_lataria(corpo, comp, larg, capo, teto, cabine, cor, suja)
\t_vidros(corpo, comp, larg, capo, teto, cabine)
\t_frente_e_tras(corpo, luzes, comp, larg, capo, cor, modelo)
\tif modelo == Modelo.PICAPE:
\t\t_cacamba(corpo, comp, larg, capo, cabine, cor)
\tif modelo == Modelo.TAXI:
\t\t_letreiro(corpo, larg, teto, comp, cabine)"""

new_montar_body = """\tvar cor := TINTA_TAXI if modelo == Modelo.TAXI else tinta
\tif modelo == Modelo.FUSCA:
\t\tcor = TINTA_FUSCA
\t# Fusca das refs e sempre sujo; os outros continuam com a chance de 1 em 7.
\tvar suja := modelo == Modelo.FUSCA or (semente % 7) == 0

\tvar corpo := PSXMesh.dados_vazios()
\tvar luzes := PSXMesh.dados_vazios()

\tif modelo == Modelo.FUSCA:
\t\t_lataria_fusca(corpo, comp, larg, capo, teto, cabine, cor)
\t\t_vidros(corpo, comp, larg, capo, teto, cabine)
\t\t_frente_e_tras(corpo, luzes, comp, larg, capo, cor, modelo)
\telse:
\t\t_lataria(corpo, comp, larg, capo, teto, cabine, cor, suja)
\t\t_vidros(corpo, comp, larg, capo, teto, cabine)
\t\t_frente_e_tras(corpo, luzes, comp, larg, capo, cor, modelo)
\t\tif modelo == Modelo.PICAPE:
\t\t\t_cacamba(corpo, comp, larg, capo, cabine, cor)
\t\tif modelo == Modelo.TAXI:
\t\t\t_letreiro(corpo, larg, teto, comp, cabine)"""
assert old_montar_body in text, "montar body not found"
text = text.replace(old_montar_body, new_montar_body, 1)

# 5) _face_dois_lados after _face
old_face = """static func _face(dados: Dictionary, tamanho: Vector2, xform: Transform3D,
\t\tcor: Color, celula: Vector2i) -> void:
\tvar d := PSXMesh.placa_dados(tamanho, 100.0, Color.WHITE)
\tvar r := uv(celula)
\tvar uvs: PackedVector2Array = d["uv"]
\tfor k in uvs.size():
\t\tuvs[k] = r.position + uvs[k] * r.size
\td["uv"] = uvs
\tPSXMesh.acumular_tingido(dados, d, xform, cor)


## Um paralelepipedo com celula por face, e sem as faces que ninguem ve."""

new_face = """static func _face(dados: Dictionary, tamanho: Vector2, xform: Transform3D,
\t\tcor: Color, celula: Vector2i) -> void:
\tvar d := PSXMesh.placa_dados(tamanho, 100.0, Color.WHITE)
\tvar r := uv(celula)
\tvar uvs: PackedVector2Array = d["uv"]
\tfor k in uvs.size():
\t\tuvs[k] = r.position + uvs[k] * r.size
\td["uv"] = uvs
\tPSXMesh.acumular_tingido(dados, d, xform, cor)


## Placa com verso. O psx_surface usa cull_back; vidro de uma face some quando a
## camera esta do outro lado (cabine olhando para fora, ou rua olhando o verso
## de um para-brisa invertido). Marea e Fusca herdam o mesmo caminho — sem
## material novo, sem celula nova: C_PARABRISA / C_VIDRO_* + VIDRO dos dois lados.
static func _face_dois_lados(dados: Dictionary, tamanho: Vector2, xform: Transform3D,
\t\tcor: Color, celula: Vector2i) -> void:
\t_face(dados, tamanho, xform, cor, celula)
\t_face(dados, tamanho,
\t\txform * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO), cor, celula)


## Um paralelepipedo com celula por face, e sem as faces que ninguem ve."""
assert old_face in text, "_face block not found"
text = text.replace(old_face, new_face, 1)

path.write_text(text, encoding="utf-8")
print("pass1 ok", path.stat().st_size)
