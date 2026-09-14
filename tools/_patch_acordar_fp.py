# -*- coding: utf-8 -*-
from pathlib import Path

path = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\abertura.gd")
text = path.read_text(encoding="utf-8")

# --- 1) Replace ACORDA constants by slicing between markers ---
c0 = text.find("# --- plano da praca ---------------------------------------------------------")
c1 = text.find("## Ate onde procurar o parque, em chunks.")
if c0 < 0 or c1 < 0:
    raise SystemExit(f"const markers missing {c0} {c1}")

new_consts = """# --- plano da praca ---------------------------------------------------------
## Acordar FP na Praca da Matriz (ref 01): deitado no chao, pernas no frame,
## camera sobe com ele. Cinema AAA em PSX STYLE.
##
## Terceira pessoa lateral foi aposentada — a print pede o olhar DELE no calcamento,
## com igreja/coreto alem dos pes (layout do Cleiton). Constantes PRACA_* abaixo
## sobram para enquadramentos 02-04 depois do levantar.
const PRACA_ALTURA := Vector2(4.6, 3.2)
const PRACA_FRENTE := Vector2(3.0, 10.0)
const PRACA_OLHAR := Vector2(19.0, 21.0)
const PRACA_FOV := Vector2(64.0, 58.0)
const PRACA_DURACAO := 15.5
## Olho deitado -> olho em pe. Baixo o bastante pra ver as proprias pernas.
const ACORDA_ALTURA := Vector2(0.24, 1.58)
## Distancia pes->cabeca ao longo do eixo do corpo (metros).
const ACORDA_CABECA := 1.52
## Altura do alvo do olhar (chao perto dos pes -> horizonte da praca).
const ACORDA_OLHAR_ALTURA := Vector2(0.10, 1.20)
## Quao longe o olhar mira no comeco (pes) e no fim (praca adentro).
const ACORDA_OLHAR_PERTO := 0.45
const ACORDA_OLHAR_LONGE := 12.0
## Bicicleta: lado oposto ao tronco, fora do cone FP.
const ACORDA_LADO := 1.95
## Para que lado da bussola o corpo caido aponta (ajuste fino do yaw local).
const DEITADO_GIRO := 0.7
## Espessura de meio corpo deitado, em metros.
const DEITADO_ALTURA := 0.18
## FOV largo no chao (claustrofobia PSX), fecha um pouco ao levantar.
const ACORDA_FOV := Vector2(70.0, 60.0)
const ACORDA_DURACAO := 9.0
## Quanto tempo ele fica caido antes de se mexer, e quanto leva para levantar.
const ACORDA_ANTES := 3.4
const ACORDA_SUBIDA := 2.2

"""
text = text[:c0] + new_consts + text[c1:]

# --- 2) _lado_livre ---
old_lado = """\tvar a := meio + lado * ACORDA_LADO + Vector3.UP * ACORDA_ALTURA.x
\tvar b := meio + lado * (ACORDA_LADO * 1.15) + Vector3.UP * ACORDA_ALTURA.y
\treturn _linha_livre(a, meio) and _linha_livre(b, meio)"""
new_lado = """\t# So decide o lado da BICICLETA. A camera do acordar e FP na cabeca.
\tvar a := meio + lado * ACORDA_LADO + Vector3.UP * 0.6
\tvar b := meio + lado * (ACORDA_LADO * 1.15) + Vector3.UP * 1.2
\treturn _linha_livre(a, meio) and _linha_livre(b, meio)"""
if old_lado not in text:
    raise SystemExit("lado body not found")
text = text.replace(old_lado, new_lado, 1)

# --- 3) _plano_da_praca by markers ---
p0 = text.find("## De cima, na direcao do parque em que ele acordou.")
p1 = text.find("## Ha vista livre entre estes dois pontos?")
if p0 < 0 or p1 < 0:
    raise SystemExit(f"plano markers missing {p0} {p1}")

new_plano = '''## Acordar em primeira pessoa no chao da praca (ref 01).
##
## E o primeiro plano do jogo, e o unico que fala do passado. Vem antes da rua
## de proposito: a fala da rua ("preciso seguir ela pra sair") so quer dizer
## alguma coisa depois de o jogador saber que ele nao escolheu estar aqui.
##
## Camera na cabeca, olhando na direcao dos pes (-eixo) para as pernas encharem
## o terco de baixo do quadro — e a praca (coreto/igreja quando o Cleiton tiver
## geometria) aparecer alem delas. Sobe com o levantar ate a altura dos olhos.
func _plano_da_praca(pose: Dictionary) -> void:
\tvar onde: Vector3 = pose["onde"]
\tvar eixo: Vector3 = pose["eixo"]
\tvar figura := _jogador.figura()

\t# Direcao do olhar alem dos pes: preferir o centro do parque mais perto
\t# (coreto no miolo). Sem parque no alcance, cai no -eixo do corpo.
\tvar frente_praca := -eixo
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
\t\t+ Vector3.UP * ACORDA_OLHAR_ALTURA.y)

\tCinema.mover(
\t\tcam_de, cam_ate,
\t\tolhar_de, olhar_ate,
\t\tACORDA_DURACAO, ACORDA_FOV.x, ACORDA_FOV.y)

\tawait Cinema.clarear(2.2)
\tCinema.legenda(FALAS["acorda"], 2.2)
\t# Shot no chao ANTES de levantar — e a prova da ref 01.
\tawait _capturar_plano("01_acordar_chao")
\tawait get_tree().create_timer(ACORDA_ANTES).timeout

\tif figura != null:
\t\t_levantar(figura, ACORDA_SUBIDA)
\tawait get_tree().create_timer(ACORDA_SUBIDA).timeout

\tawait _capturar_plano("01_acordar_pe")
\tfor chave: String in ["praca_1", "praca_2", "praca_3", "praca_4", "praca_5"]:
\t\tCinema.legenda(FALAS[chave], 3.6)
\t\tawait get_tree().create_timer(3.9).timeout


'''
text = text[:p0] + new_plano + text[p1:]

# --- 4) orient before deitar ---
old_orient = """\tvar onde := _jogador.global_position

\tvar figura := _jogador.figura()
\tif figura != null:
\t\tfigura.postura(Corpo.Postura.ENCOSTADO)
\t\t_montar_maos(figura)
\t\t_deitar(figura, true)"""

new_orient = """\tvar onde := _jogador.global_position

\t# Virar pra praca antes de deitar: pes apontam pro miolo (coreto), cabeca
\t# pra fora — assim o FP olhando -eixo enquadra a praca alem das pernas.
\tvar praca_alvo := _praca_mais_perto(onde)
\tif praca_alvo != Vector3.INF:
\t\tvar para := Vector3(praca_alvo.x - onde.x, 0.0, praca_alvo.z - onde.z)
\t\tif para.length_squared() > 1.0:
\t\t\t# Em pe, frente do jogador = (-sin y, 0, -cos y). Olhar pra praca.
\t\t\t_jogador.rotation.y = atan2(-para.x, -para.z)

\tvar figura := _jogador.figura()
\tif figura != null:
\t\tfigura.postura(Corpo.Postura.ENCOSTADO)
\t\t_montar_maos(figura)
\t\t_deitar(figura, true)"""

if old_orient not in text:
    raise SystemExit("orient block not found")
text = text.replace(old_orient, new_orient, 1)

# --- 5) dual capture path ---
needle = '\tprint("[abertura] captura %s (%dx%d)" % [abs_path, image.get_width(), image.get_height()])'
extra = '''\tprint("[abertura] captura %s (%dx%d)" % [abs_path, image.get_width(), image.get_height()])
\t# Task AAA praca: espelho em captures/praca_matriz/cine/ (raiz do repo).
\tif nome.begins_with("01_acordar") or nome.begins_with("praca_"):
\t\tvar game_dir := ProjectSettings.globalize_path("res://").rstrip("/\\\\")
\t\tvar cine_dir := game_dir.path_join("..").path_join("captures").path_join("praca_matriz").path_join("cine")
\t\tDirAccess.make_dir_recursive_absolute(cine_dir)
\t\tvar cine := cine_dir.path_join("%s.png" % nome)
\t\tvar err2 := image.save_png(cine)
\t\tif err2 == OK:
\t\t\tprint("[abertura] cine %s" % cine)
\t\telse:
\t\t\tpush_warning("Abertura: falha cine %s (erro %d)" % [cine, err2])'''
if needle not in text:
    raise SystemExit("capture print not found")
if "praca_matriz/cine" not in text:
    text = text.replace(needle, extra, 1)

path.write_text(text, encoding="utf-8")
print("OK", path)
print("ACORDA_CABECA", "ACORDA_CABECA" in text)
print("01_acordar_chao", "01_acordar_chao" in text)
print("praca_alvo", "praca_alvo" in text)
