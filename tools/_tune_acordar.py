from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\abertura.gd")
t = p.read_text(encoding="utf-8")

# Spawn further south + slight west so church sits right of coreto in frame
old = """\t\torigem = Vector3(matriz.x, origem.y, matriz.z + 8.0)
\t\t_jogador.global_position = origem + Vector3.UP * 0.5
\t\t_jogador.rotation.y = 0.0"""
new = """\t\t# Sul-oeste do coreto: igreja fica a direita no quadro (ref 01).
\t\torigem = Vector3(matriz.x - 4.0, origem.y, matriz.z + 12.0)
\t\t_jogador.global_position = origem + Vector3.UP * 0.5
\t\t# Olhar pro miolo (coreto/igreja ao norte).
\t\tvar para_m := Vector3(matriz.x - origem.x, 0.0, matriz.z - 6.0 - origem.z)
\t\t_jogador.rotation.y = atan2(-para_m.x, -para_m.z)"""
if old not in t:
    raise SystemExit("spawn offset not found")
t = t.replace(old, new, 1)

# Stronger leg read: lower look start, look closer to feet first
t2 = t.replace(
    "const ACORDA_OLHAR_ALTURA := Vector2(0.10, 1.20)",
    "const ACORDA_OLHAR_ALTURA := Vector2(0.04, 1.35)",
    1,
)
t2 = t2.replace(
    "const ACORDA_OLHAR_PERTO := 0.45",
    "const ACORDA_OLHAR_PERTO := 0.25",
    1,
)
t2 = t2.replace(
    "const ACORDA_OLHAR_LONGE := 12.0",
    "const ACORDA_OLHAR_LONGE := 16.0",
    1,
)
t2 = t2.replace(
    "const ACORDA_ALTURA := Vector2(0.24, 1.58)",
    "const ACORDA_ALTURA := Vector2(0.18, 1.62)",
    1,
)
t2 = t2.replace(
    "const ACORDA_CABECA := 1.52",
    "const ACORDA_CABECA := 1.35",
    1,
)
if t2 == t:
    raise SystemExit("const tune failed")
t = t2

# In _plano_da_praca: look_de prefer feet along -eixo blend with park
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

new_look = """\t# Olhar inicial: mistura pes (-eixo) + miolo da praca, pra pernas no terco
\t# de baixo E coreto/igreja alem delas.
\tvar frente_pes := -eixo
\tif frente_pes.length_squared() < 0.01:
\t\tfrente_pes = Vector3.FORWARD
\tfrente_pes = frente_pes.normalized()
\tvar frente_praca := frente_pes
\tvar praca := _praca_mais_perto(onde)
\tif praca != Vector3.INF:
\t\tvar d := Vector3(praca.x - onde.x, 0.0, praca.z - 4.0 - onde.z)
\t\tif d.length_squared() > 0.25:
\t\t\tfrente_praca = d.normalized()
\tvar frente_inicio := (frente_pes * 0.65 + frente_praca * 0.35).normalized()

\tvar cabeca := onde + eixo * ACORDA_CABECA
\tvar cam_de := cabeca + Vector3.UP * ACORDA_ALTURA.x
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

p.write_text(t, encoding="utf-8")
print("tuned")
