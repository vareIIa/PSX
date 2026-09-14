# -*- coding: utf-8 -*-
from pathlib import Path
root = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX")
bp = root / "game/src/world/estrada_builder.gd"
b = bp.read_text(encoding="utf-8")

def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f"FAIL {label}")
    return text.replace(old, new, 1)

b = replace_once(b, "const RECUO_ARVORE := 3.8", "const RECUO_ARVORE := 7.6", "recuo")
b = replace_once(b, "KitEstrada.beira(sup, pa, la, rng, 18)", "KitEstrada.beira(sup, pa, la, rng, 7)", "beira_count")

old_mata = """\tfor _i in 64:
\t\tvar s := s0 + rng.randf_range(-1.0, TRECHO + 1.0)
\t\tvar lado := 1.0 if rng.randf() < 0.5 else -1.0
\t\t# Distribuicao puxada para perto: `d` sai de um sorteio elevado ao
\t\t# quadrado, o que poe mais arvore na primeira dezena de metros. E onde
\t\t# elas aparecem inteiras e onde a parede do corredor se forma; longe, a
\t\t# nevoa ja resolve com a massa.
\t\tvar t := rng.randf()
\t\tvar d := lerpf(RECUO_ARVORE, 26.0, t * t)
\t\tvar base := ponto_em(s) + lado_em(s) * (d * lado)
\t\tbase.y += altura_lateral(d)

\t\tvar raio := lerpf(1.6, 2.8, rng.randf())
\t\tvar livre := true
\t\tfor k in ocupado.size():
\t\t\tif base.distance_to(ocupado[k]) < (raio + raios[k]) * 0.62:
\t\t\t\tlivre = false
\t\t\t\tbreak
\t\tif not livre:
\t\t\tcontinue

\t\tvar porte := clampf(rng.randf_range(0.2, 1.0) + d * 0.012, 0.0, 1.0)
\t\tvar r: float
\t\tif rng.randf() < 0.55:
\t\t\tr = KitEstrada.conifera(sup, base, porte, rng)
\t\telse:
\t\t\tr = KitEstrada.arvore(sup, base, porte, rng, rng.randf() < 0.16)
\t\tocupado.append(base)
\t\traios.append(r)

\t\t# Arbusto no pe de uma arvore em cada tres. E o que tapa a juncao entre
\t\t# o tronco e o chao, que e por onde se ve o vazio de uma mata gerada.
\t\tif rng.randf() < 0.62:
\t\t\tKitParque.arbusto(sup, base + Vector3(rng.randf_range(-1.2, 1.2),
\t\t\t\t0.0, rng.randf_range(-1.2, 1.2)), rng.randf_range(0.7, 1.3), rng)

\t# A parede do fundo: massa de folha a partir de vinte metros, os dois lados.
\tfor _i in 28:"""

new_mata = """\t# P0: corredor aberto — menos arvores, longe da pista, sem parede na cara.
\tfor _i in 28:
\t\tvar s := s0 + rng.randf_range(-1.0, TRECHO + 1.0)
\t\tvar lado := 1.0 if rng.randf() < 0.5 else -1.0
\t\t# Distribuicao EMPURRADA para longe (sqrt): corredor le o carro no TP.
\t\tvar t := rng.randf()
\t\tvar d := lerpf(RECUO_ARVORE, 28.0, sqrt(t))
\t\tvar base := ponto_em(s) + lado_em(s) * (d * lado)
\t\tbase.y += altura_lateral(d)

\t\tvar raio := lerpf(1.3, 2.2, rng.randf())
\t\tvar livre := true
\t\tfor k in ocupado.size():
\t\t\tif base.distance_to(ocupado[k]) < (raio + raios[k]) * 0.78:
\t\t\t\tlivre = false
\t\t\t\tbreak
\t\tif not livre:
\t\t\tcontinue

\t\tvar porte := clampf(rng.randf_range(0.15, 0.9) + d * 0.01, 0.0, 1.0)
\t\tvar r: float
\t\tif rng.randf() < 0.55:
\t\t\tr = KitEstrada.conifera(sup, base, porte, rng)
\t\telse:
\t\t\tr = KitEstrada.arvore(sup, base, porte, rng, rng.randf() < 0.14)
\t\tocupado.append(base)
\t\traios.append(r)

\t\tif rng.randf() < 0.4:
\t\t\tKitParque.arbusto(sup, base + Vector3(rng.randf_range(-1.0, 1.0),
\t\t\t\t0.0, rng.randf_range(-1.0, 1.0)), rng.randf_range(0.6, 1.1), rng)

\t# Parede de folha so no FUNDO (nevoa), nao na beira da pista.
\tfor _i in 16:"""

b = replace_once(b, old_mata, new_mata, "mata")

old_cipo = """\t# Cipos / galhos pendurados cruzando a pista — densidade da ref 04.
\tvar n_cipo := 8 if ancora_captura else (5 if rng.randf() < 0.8 else 2)
\tfor _i in n_cipo:
\t\tvar s := s0 + rng.randf_range(0.5, TRECHO - 0.5)
\t\tvar lado := 1.0 if rng.randf() < 0.5 else -1.0
\t\tvar ancora := ponto_em(s) + lado_em(s) * (lado * rng.randf_range(2.8, 5.2))
\t\tancora.y += altura_lateral(4.0) + rng.randf_range(3.0, 5.0)
\t\tvar sobre := ponto_em(s + rng.randf_range(-1.2, 1.2)) + lado_em(s) * (lado * rng.randf_range(-1.2, 0.4))
\t\tsobre.y += rng.randf_range(2.15, 3.0)
\t\tKitEstrada.cipo(sup, ancora, sobre, rng)"""

# tolerate dash encoding
import re
m = re.search(r"\t# Cipos / galhos pendurados.*?\n\t\tKitEstrada\.cipo\(sup, ancora, sobre, rng\)", b, re.S)
if not m:
    raise SystemExit("FAIL detalhes_cipo regex")
new_cipo = """\t# Cipos esparsos no TOPO — fios, nao parede preta (P0).
\tvar n_cipo := 4 if ancora_captura else (2 if rng.randf() < 0.55 else 0)
\tfor _i in n_cipo:
\t\tvar s := s0 + rng.randf_range(0.5, TRECHO - 0.5)
\t\tvar lado := 1.0 if rng.randf() < 0.5 else -1.0
\t\tvar ancora := ponto_em(s) + lado_em(s) * (lado * rng.randf_range(4.0, 6.5))
\t\tancora.y += altura_lateral(5.0) + rng.randf_range(4.0, 6.0)
\t\tvar sobre := ponto_em(s + rng.randf_range(-0.8, 0.8)) + lado_em(s) * (lado * rng.randf_range(-0.6, 1.2))
\t\tsobre.y += rng.randf_range(2.6, 3.4)
\t\tKitEstrada.cipo(sup, ancora, sobre, rng)"""
b = b[:m.start()] + new_cipo + b[m.end():]
print("detalhes_cipo OK")

# props_facho: replace from casa EXPLICITA through arbustos
m2 = re.search(r"\t# Casa EXPLICITA no cone direito.*?\n\t\tKitParque\.arbusto\(sup, bp, rng\.randf_range\(0\.85, 1\.35\), rng\)", b, re.S)
if not m2:
    raise SystemExit("FAIL props regex")
new_props = """\t# Casa EXPLICITA no cone direito, fora do leito (P0 + ref 04).
\tvar s := s_carro + 6.5
\tvar d_casa := KitEstrada.MEIA_PISTA + 1.35
\tvar base := ponto_em(s) + lado_em(s) * d_casa
\tbase.y += altura_lateral(d_casa)
\tvar giro := atan2(direcao_em(s).x, direcao_em(s).z) + PI * 0.5
\tKitEstrada.casa_beira(sup, base, giro, rng)
\t# Cerca no facho direito — fora da pista.
\tvar d_c := KitEstrada.MEIA_PISTA + 0.95
\tvar a := ponto_em(s_carro + 2.5) + lado_em(s_carro + 2.5) * d_c
\tvar bb := ponto_em(s + 5.0) + lado_em(s + 5.0) * d_c
\ta.y += altura_lateral(d_c)
\tbb.y += altura_lateral(d_c)
\tKitEstrada.cerca(sup, a, bb, rng)
\tvar a2 := ponto_em(s - 1.0) + lado_em(s - 1.0) * (d_casa - 0.35)
\tvar b2 := ponto_em(s + 4.0) + lado_em(s + 4.0) * (d_casa - 0.35)
\ta2.y += altura_lateral(d_casa - 0.35)
\tb2.y += altura_lateral(d_casa - 0.35)
\tKitEstrada.cerca(sup, a2, b2, rng)
\tvar d_m := -(KitEstrada.MEIA_PISTA + 1.0)
\tvar m0 := ponto_em(s - 2.0) + lado_em(s - 2.0) * d_m
\tvar m1 := ponto_em(s + 6.0) + lado_em(s + 6.0) * d_m
\tm0.y += altura_lateral(absf(d_m))
\tm1.y += altura_lateral(absf(d_m))
\tKitEstrada.muro_baixo(sup, m0, m1, rng)
\t# Cipos no TOPO do para-brisa — fios esparsos, corredor livre no centro.
\tfor i in 6:
\t\tvar sc := s_carro + 2.0 + float(i) * 2.0
\t\tvar lado := 1.0 if i % 2 == 0 else -1.0
\t\tvar ancora := ponto_em(sc) + lado_em(sc) * (lado * rng.randf_range(4.2, 6.0))
\t\tancora.y += altura_lateral(5.0) + rng.randf_range(4.2, 5.8)
\t\tvar sobre := ponto_em(sc + rng.randf_range(-0.4, 0.4)) + lado_em(sc) * (lado * rng.randf_range(-0.4, 1.0))
\t\tsobre.y += rng.randf_range(2.7, 3.35)
\t\tKitEstrada.cipo(sup, ancora, sobre, rng)
\t# Brush FORA do leito — so beira.
\tfor i in 12:
\t\tvar sb := s_carro + rng.randf_range(2.0, 14.0)
\t\tvar lado := 1.0 if rng.randf() < 0.58 else -1.0
\t\tvar d := rng.randf_range(KitEstrada.MEIA_PISTA + 0.7, KitEstrada.MEIA_PISTA + 3.0)
\t\tvar pp := ponto_em(sb) + lado_em(sb) * (d * lado)
\t\tpp.y += altura_lateral(d)
\t\tKitEstrada.tufo(sup, pp,
\t\t\t[KitEstrada.C_CAPIM, KitEstrada.C_SAMAMBAIA, KitEstrada.C_MOITA_BAIXA,
\t\t\t\tKitEstrada.C_FOLHA_LARGA, KitEstrada.C_GALHO_SECO][rng.randi() % 5],
\t\t\trng.randf_range(0.7, 1.35), rng.randf_range(0.0, TAU),
\t\t\tColor(0.78, 0.86, 0.62))
\tfor i in 3:
\t\tvar off := lado_em(s) * (d_casa + 0.35) + direcao_em(s) * (rng.randf_range(-1.2, 1.8))
\t\tvar bp := ponto_em(s) + off
\t\tbp.y += altura_lateral(d_casa)
\t\tKitParque.arbusto(sup, bp, rng.randf_range(0.7, 1.15), rng)"""
b = b[:m2.start()] + new_props + b[m2.end():]
print("props OK")

old_floor = "\t\t\t\tvar tom := 0.86 - float(k) * 0.06 + rng.randf_range(-0.04, 0.04)\n\t\t\t\tvar cor := Color(tom, tom * 0.98, tom * 0.9)"
new_floor = "\t\t\t\tvar tom := 0.92 - float(k) * 0.05 + rng.randf_range(-0.03, 0.03)\n\t\t\t\t# Coluna 0 (rente ao leito): barro quente, nao cinza.\n\t\t\t\tvar cor := Color(tom * 1.05, tom * 0.72, tom * 0.48) if k == 0 else Color(tom * 0.85, tom * 0.78, tom * 0.62)"
b = replace_once(b, old_floor, new_floor, "floor")

bp.write_text(b, encoding="utf-8")
print("builder OK", len(b))
