# -*- coding: utf-8 -*-
"""Pin spawn Cleiton + tune FP legs for ref 01."""
from pathlib import Path

p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\abertura.gd")
t = p.read_text(encoding="utf-8")

# --- consts tune ---
replacements = [
    ("const ACORDA_ALTURA := Vector2(0.24, 1.58)", "const ACORDA_ALTURA := Vector2(0.16, 1.62)"),
    ("const ACORDA_CABECA := 1.52", "const ACORDA_CABECA := 1.28"),
    ("const ACORDA_OLHAR_ALTURA := Vector2(0.10, 1.20)", "const ACORDA_OLHAR_ALTURA := Vector2(0.03, 1.40)"),
    ("const ACORDA_OLHAR_PERTO := 0.45", "const ACORDA_OLHAR_PERTO := 0.20"),
    ("const ACORDA_OLHAR_LONGE := 12.0", "const ACORDA_OLHAR_LONGE := 18.0"),
    ("const ACORDA_FOV := Vector2(70.0, 60.0)", "const ACORDA_FOV := Vector2(72.0, 58.0)"),
]
for a, b in replacements:
    if a not in t:
        raise SystemExit(f"missing const: {a}")
    t = t.replace(a, b, 1)

# --- pin spawn to Cleiton cluster (~272, -48), south-west for church-right ---
old_spawn = """\tvar origem := _nasceu_em
\t# Acordar NA Matriz: ~8 m ao sul do coreto, olhando norte (igreja). Sem isto
\t# o ponto_inicial cai num parquinho e a ref 01 vira balanco/trepa-trepa.
\tvar matriz := _praca_mais_perto(origem)
\tif matriz != Vector3.INF:
\t\torigem = Vector3(matriz.x, origem.y, matriz.z + 8.0)
\t\t_jogador.global_position = origem + Vector3.UP * 0.5
\t\t_jogador.rotation.y = 0.0
\t\t_jogador.zerar_velocidade()
\t\t_nasceu_em = origem"""

new_spawn = """\tvar origem := _nasceu_em
\t# Pin Cleiton (cluster Matriz ~272,-48). Sul-oeste do coreto: igreja a direita
\t# no quadro, coreto no meio, postes no anel (ref 01).
\tconst PIN_MATRIZ := Vector3(272.0, 0.0, -48.0)
\tvar matriz := _praca_mais_perto(PIN_MATRIZ)
\tif matriz == Vector3.INF:
\t\tmatriz = PIN_MATRIZ
\t# ~12 m ao sul, 4 m a oeste do miolo.
\torigem = Vector3(matriz.x - 4.0, origem.y, matriz.z + 12.0)
\t_jogador.global_position = origem + Vector3.UP * 0.5
\tvar para_m := Vector3(matriz.x - origem.x, 0.0, (matriz.z - 6.0) - origem.z)
\tif para_m.length_squared() > 0.01:
\t\t_jogador.rotation.y = atan2(-para_m.x, -para_m.z)
\telse:
\t\t_jogador.rotation.y = 0.0
\t_jogador.zerar_velocidade()
\t_nasceu_em = origem
\t# Espera streaming do chunk da Matriz antes de testar chao.
\tfor _k in 90:
\t\tawait get_tree().physics_frame"""

if old_spawn not in t:
    # try without comment variants
    raise SystemExit("spawn block not found — dump nearby")
t = t.replace(old_spawn, new_spawn, 1)

# --- look block: bias toward feet for leg silhouette ---
old_look = """\tvar frente_praca := -eixo
\tvar praca := _praca_mais_perto(onde)
\tif praca != Vector3.INF:
\t\tvar d := Vector3(praca.x - onde.x, 0.0, praca.z - onde.z)
\t\tif d.length_squared() > 0.25:
\t\t\tfrente_praca = d.normalized()

\tvar cabeca := onde + eixo * ACORDA_CABECA
\tvar cam_de := cabeca + Vector3.UP * ACORDA_ALTURA.x
\tvar cam_ate := onde + Vector3.UP * ACORDA_ALTURA.y
\tvar olhar_de := (
\t\tonde + frente_praca * ACORDA_OLHAR_PERTO
\t\t+ Vector3.UP * ACORDA_OLHAR_ALTURA.x)
\tvar olhar_ate := (
\t\tonde + frente_praca * ACORDA_OLHAR_LONGE
\t\t+ Vector3.UP * ACORDA_OLHAR_ALTURA.y)"""

new_look = """\t# Olhar inicial viesado pros PES (-eixo) pra calca/bota lerem no terco baixo.
\t# Miolo da praca (igreja/coreto) puxa o olhar final.
\tvar frente_pes := -eixo
\tif frente_pes.length_squared() < 0.01:
\t\tfrente_pes = Vector3(0.0, 0.0, -1.0)
\tfrente_pes = frente_pes.normalized()
\tvar frente_praca := frente_pes
\tvar praca := _praca_mais_perto(onde)
\tif praca == Vector3.INF:
\t\tpraca = Vector3(272.0, 0.0, -48.0)
\tvar d := Vector3(praca.x - onde.x, 0.0, (praca.z - 5.0) - onde.z)
\tif d.length_squared() > 0.25:
\t\tfrente_praca = d.normalized()
\tvar frente_inicio := (frente_pes * 0.75 + frente_praca * 0.25).normalized()

\tvar cabeca := onde + eixo * ACORDA_CABECA
\t# Ligeiro offset lateral pra nao atravessar o tronco (cubo no meio do frame).
\tvar ombro := eixo.cross(Vector3.UP)
\tif ombro.length_squared() < 0.01:
\t\tombro = Vector3.RIGHT
\tombro = ombro.normalized() * 0.08
\tvar cam_de := cabeca + ombro + Vector3.UP * ACORDA_ALTURA.x
\tvar cam_ate := onde + Vector3.UP * ACORDA_ALTURA.y
\tvar olhar_de := (
\t\tonde + frente_inicio * ACORDA_OLHAR_PERTO
\t\t+ Vector3.UP * ACORDA_OLHAR_ALTURA.x)
\tvar olhar_ate := (
\t\tonde + frente_praca * ACORDA_OLHAR_LONGE
\t\t+ Vector3.UP * ACORDA_OLHAR_ALTURA.y)"""

if old_look not in t:
    raise SystemExit("look block not found")
t = t.replace(old_look, new_look, 1)

# Ensure body visible during FP wake (legs must render)
old_show = "\t\tfigura.postura(Corpo.Postura.ENCOSTADO)\n\t\t_montar_maos(figura)\n\t\t_deitar(figura, true)"
new_show = "\t\tfigura.postura(Corpo.Postura.ENCOSTADO)\n\t\t_montar_maos(figura)\n\t\t_deitar(figura, true)\n\t\t# FP acordar precisa do mesh das pernas no frame (ref 01 calca+bota).\n\t\t_jogador.mostrar_corpo(true)"
if old_show not in t:
    raise SystemExit("deitar show block not found")
t = t.replace(old_show, new_show, 1)

p.write_text(t, encoding="utf-8")
print("OK patch_acordar_v2")
print("PIN", "272.0" in t)
print("frente_pes", "frente_pes" in t)
