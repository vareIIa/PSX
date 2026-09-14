# -*- coding: utf-8 -*-
from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\abertura.gd")
t = p.read_text(encoding="utf-8")

# Insert helper before _plano_da_praca if missing
helper = '''
## Posicao mundo de um osso do Corpo (apos _deitar).
func _ponto_osso(figura: Corpo, osso: int) -> Vector3:
\tvar sk := figura.esqueleto()
\tif sk == null:
\t\treturn figura.global_position
\treturn (sk.global_transform * sk.get_bone_global_pose(osso)).origin


'''

if "_ponto_osso(" not in t:
    marker = "# --- plano da praca ---------------------------------------------------------\n\n## Acordar em primeira pessoa"
    if marker not in t:
        raise SystemExit("marker for helper missing")
    t = t.replace(marker, "# --- plano da praca ---------------------------------------------------------\n" + helper + "## Acordar em primeira pessoa", 1)

# Replace camera math block inside _plano_da_praca (from olhar DE comment through Cinema.mover call)
old = """\t# Olhar DE trava nos pes (calca+bota). Olhar ATE sobe pro miolo Matriz.
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

\tvar cabeca := onde + eixo * ACORDA_CABECA
\tvar ombro := eixo.cross(Vector3.UP)
\tif ombro.length_squared() < 0.01:
\t\tombro = Vector3.RIGHT
\tombro = ombro.normalized() * 0.06
\tvar cam_de := cabeca + ombro + Vector3.UP * ACORDA_ALTURA.x
\tvar cam_ate := onde + Vector3.UP * ACORDA_ALTURA.y
\t# Alvo inicial = os proprios pes no calcamento (ref 01).
\tvar olhar_de := onde + frente_pes * 0.12 + Vector3.UP * 0.05
\tvar olhar_ate := (
\t\tonde + frente_praca * ACORDA_OLHAR_LONGE
\t\t+ Vector3.UP * ACORDA_OLHAR_ALTURA.y)

\t# Cinema.mover NAO espera — cronometramos o pe capture pro fim do tween.
\tvar t0 := Time.get_ticks_msec()
\tCinema.mover(
\t\tcam_de, cam_ate,
\t\tolhar_de, olhar_ate,
\t\tACORDA_DURACAO, ACORDA_FOV.x, ACORDA_FOV.y)"""

new = """\t# Camera pelos OSSOS (nao por eixo estimado): cabeca -> meio das canelas.
\t# Foi o que faltava pra calca+bota lerem no terco baixo em vez de cubo solto.
\tvar praca := _praca_mais_perto(onde)
\tif praca == Vector3.INF:
\t\tpraca = Vector3(272.0, 0.0, -48.0)
\tvar frente_praca := Vector3(praca.x - onde.x, 0.0, (praca.z - 5.0) - onde.z)
\tif frente_praca.length_squared() < 0.01:
\t\tfrente_praca = -eixo if eixo.length_squared() > 0.01 else Vector3(0.0, 0.0, -1.0)
\tfrente_praca = frente_praca.normalized()

\tvar cam_de: Vector3
\tvar olhar_de: Vector3
\tif figura != null:
\t\tvar p_cabeca := _ponto_osso(figura, Corpo.Osso.CABECA)
\t\tvar p_pe_e := _ponto_osso(figura, Corpo.Osso.CANELA_E)
\t\tvar p_pe_d := _ponto_osso(figura, Corpo.Osso.CANELA_D)
\t\tvar p_pes := (p_pe_e + p_pe_d) * 0.5
\t\t# Um palmo atras/acima da cabeca pra nao nascer DENTRO do mesh.
\t\tcam_de = p_cabeca - frente_praca * 0.12 + Vector3.UP * 0.08
\t\t# Mira entre os pes, um pouco alem — calca+bota no terco baixo, praca atras.
\t\tolhar_de = p_pes + frente_praca * 0.35 + Vector3.UP * 0.02
\telse:
\t\tcam_de = onde + eixo * ACORDA_CABECA + Vector3.UP * ACORDA_ALTURA.x
\t\tolhar_de = onde - eixo * 0.2 + Vector3.UP * 0.05

\tvar cam_ate := onde + Vector3.UP * ACORDA_ALTURA.y
\tvar olhar_ate := onde + frente_praca * ACORDA_OLHAR_LONGE + Vector3.UP * ACORDA_OLHAR_ALTURA.y

\tvar t0 := Time.get_ticks_msec()
\tCinema.mover(
\t\tcam_de, cam_ate,
\t\tolhar_de, olhar_ate,
\t\tACORDA_DURACAO, ACORDA_FOV.x, ACORDA_FOV.y)"""

if old not in t:
    raise SystemExit("camera block v3 not found for v4")
t = t.replace(old, new, 1)
p.write_text(t, encoding="utf-8")
print("OK v4 bone camera")
