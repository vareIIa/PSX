# -*- coding: utf-8 -*-
from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\abertura.gd")
t = p.read_text(encoding="utf-8")

# 1) LIVRE before deitar (ENCOSTADO tucks legs into a lean pose = cubos)
old = """\t\tfigura.postura(Corpo.Postura.ENCOSTADO)
\t\t_montar_maos(figura)
\t\t_deitar(figura, true)
\t\t# FP acordar precisa do mesh das pernas no frame (ref 01 calca+bota).
\t\t_jogador.mostrar_corpo(true)"""
new = """\t\t# LIVRE (nao ENCOSTADO): pernas esticadas. ENCOSTADO encolhia e o FP
\t\t# lia as coxas como cubos marrons no meio do quadro.
\t\tfigura.postura(Corpo.Postura.LIVRE)
\t\t_montar_maos(figura)
\t\t_deitar(figura, true)
\t\t_jogador.mostrar_corpo(true)"""
if old not in t:
    raise SystemExit("postura block missing")
t = t.replace(old, new, 1)

# 2) Replace look/camera section with feet-locked look_de + await timing later
old_plano_body = """\t# Olhar inicial viesado pros PES (-eixo) pra calca/bota lerem no terco baixo.
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
\t\t+ Vector3.UP * ACORDA_OLHAR_ALTURA.y)

\tCinema.mover(
\t\tcam_de, cam_ate,
\t\tolhar_de, olhar_ate,
\t\tACORDA_DURACAO, ACORDA_FOV.x, ACORDA_FOV.y)

\t# HUD ja com valores da Praca (montado invisivel em executar). Sobe antes
\t# da cortina abrir — mesmo contrato da Estrada Velha.
\tif _hud != null:
\t\t_hud.visible = true
\tawait Cinema.clarear(2.2)
\tCinema.legenda(FALAS["acorda"], 2.2)
\t# Shot no chao ANTES de levantar — e a prova da ref 01.
\tawait _capturar_plano("01_acordar_chao")
\tawait get_tree().create_timer(ACORDA_ANTES).timeout

\tif figura != null:
\t\t_levantar(figura, ACORDA_SUBIDA)
\tawait get_tree().create_timer(ACORDA_SUBIDA).timeout

\tawait _capturar_plano("01_acordar_pe")"""

new_plano_body = """\t# Olhar DE trava nos pes (calca+bota). Olhar ATE sobe pro miolo Matriz.
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
\t\tACORDA_DURACAO, ACORDA_FOV.x, ACORDA_FOV.y)

\tif _hud != null:
\t\t_hud.visible = true
\tawait Cinema.clarear(2.2)
\tCinema.legenda(FALAS["acorda"], 2.2)
\tawait _capturar_plano("01_acordar_chao")
\tawait get_tree().create_timer(ACORDA_ANTES).timeout

\tif figura != null:
\t\t_levantar(figura, ACORDA_SUBIDA)
\t# Espera o MAIOR entre subida do corpo e fim do tween da camera.
\tvar elapsed := (Time.get_ticks_msec() - t0) / 1000.0
\tvar falta_cam := maxf(0.0, ACORDA_DURACAO - elapsed)
\tvar falta_corpo := maxf(0.0, ACORDA_SUBIDA)
\tawait get_tree().create_timer(maxf(falta_cam, falta_corpo)).timeout

\tawait _capturar_plano("01_acordar_pe")"""

if old_plano_body not in t:
    raise SystemExit("plano body block missing")
t = t.replace(old_plano_body, new_plano_body, 1)

p.write_text(t, encoding="utf-8")
print("OK v3")
