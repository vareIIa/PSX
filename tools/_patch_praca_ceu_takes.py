# -*- coding: utf-8 -*-
"""Rewrite _plano_da_praca: POV ceu + takes externos deitado + FALAS."""
from pathlib import Path

p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\abertura.gd")
t = p.read_text(encoding="utf-8")

# --- FALAS keys ---
old_falas = '''const FALAS := {
	"acorda": "...",
	"praca_1": "Eu tava indo pra Sao Thome das Letras.",
	"praca_2": "A galera de la e estranha demais.",
	"praca_3": "Parece personagem de jogo de terror. Credo.",
	"praca_4": "Ai eu acordei no chao desse parque.",
	"praca_5": "E ate agora nao sei como vim parar aqui.",
	"avenida_1": "Essa e a avenida principal da cidade...",
	"avenida_2": "Sem maldade, parece que essa avenida nao tem fim.",
	"blitz": "E tem blitz na saida. Claro que tem.",
	"mercado_1": "Tenho uns quarenta reais no bolso.",
	"mercado_2": "E to morrendo de fome.",
	"casa": "Eu sei la que tipo de gente mora nessa cidade...",
	"poste_1": "To preocupado pra saber como vou sair daqui.",
	"poste_2": "Nao devia ter ido pra Sao Thome.",
	"poste_3": "Ja falei que aquele lugar e estranho pra porra.",
	"bituca": "Que saudade de casa. Quero sair daqui logo...",
}'''

new_falas = '''const FALAS := {
	"acorda": "...",
	"praca_1": "Ultima coisa que eu lembro era o farol na terra.",
	"praca_2": "Ai... apagou. Tipo, do nada.",
	"praca_3": "E eu acordo no meio de uma praca.",
	"praca_4": "Cade o carro? Cade a estrada?",
	"praca_5": "Isso aqui nao e a pousada. Nem de longe.",
	"avenida_1": "Tem gente. Tem luz. Mas nao parece... normal.",
	"avenida_2": "Sem maldade, eu nao reconheco nada disso.",
	"blitz": "E tem blitz na saida. Claro que tem.",
	"mercado_1": "Tenho uns quarenta reais no bolso.",
	"mercado_2": "E to morrendo de fome.",
	"casa": "Eu sei la que tipo de gente mora nessa cidade...",
	"poste_1": "To preocupado pra saber como vou sair daqui.",
	"poste_2": "Nao era pra eu ter pegado essa estrada.",
	"poste_3": "Sao Thome, a galera, a pousada... tudo sumiu da minha cabeca.",
	"bituca": "Que saudade de casa. Quero sair daqui logo...",
}'''

if old_falas not in t:
    raise SystemExit("FALAS block not found (already patched?)")
t = t.replace(old_falas, new_falas, 1)

# --- header plan blurb ---
t = t.replace(
	"##   1. A praca onde ele acorda: deitado, levanta, cinco falas de contexto.",
	"##   1. A praca: POV olho no ceu/nevoa, depois takes externos dele ainda deitado.",
	1,
)

# --- praca section constants comment ---
old_const_doc = '''# --- plano da praca ---------------------------------------------------------
## Acordar FP na Praca da Matriz (ref 01): deitado no chao, pernas no frame,
## camera sobe com ele. Cinema AAA em PSX STYLE.
##
## Terceira pessoa lateral foi aposentada — a print pede o olhar DELE no calcamento,
## com igreja/coreto alem dos pes (layout do Cleiton). Constantes PRACA_* abaixo
## sobram para enquadramentos 02-04 depois do levantar.'''

new_const_doc = '''# --- plano da praca ---------------------------------------------------------
## Acordar na Praca da Matriz: POV olho no ceu/nevoa, depois takes externos
## orbitando o corpo AINDA DEITADO (sem levantar, sem props FP de pernas).
## Pin 270,-40; eixo igreja ~271,-51 (Cleiton). Constantes PRACA_* / ACORDA_*
## abaixo ficam como referencia de escala; o roteiro novo monta os takes na mao.'''

if old_const_doc not in t:
    raise SystemExit("praca const doc not found")
t = t.replace(old_const_doc, new_const_doc, 1)

# --- replace from docblock before _limpar_pernas through end of _plano_da_praca ---
# Keep FP helpers unused (dead) OR remove call sites only — rewrite plano.

marker_start = "## Acordar em primeira pessoa no chao da praca (ref 01)."
marker_end = "\n\n## Ha vista livre entre estes dois pontos?"

i0 = t.find(marker_start)
i1 = t.find(marker_end)
if i0 < 0 or i1 < 0:
    raise SystemExit(f"plano markers missing i0={i0} i1={i1}")

# Find the start of the function doc — go back to include prior blank? 
# Actually we want to keep _limpar/_caixa/_montar helpers. The docblock above
# _plano is what marker_start is. Helpers are BEFORE that docblock.
# Looking at file:
#   _limpar_pernas_fp ...
#   _caixa_fp ...
#   _montar_pernas_fp ...
#   ## Acordar em primeira pessoa...  <-- marker_start
#   func _plano_da_praca ...
# So replacing from marker_start to marker_end replaces doc + function only. Good.

new_plano = r'''## Acordar na praca: POV ceu/nevoa, depois takes externos ainda deitado.
##
## Sem _levantar, sem props FP de pernas. Corpo fica no chao (pin 270,-40).
## Cada legenda = um take novo (corte / enquadramento).

func _plano_da_praca(pose: Dictionary) -> void:
	var onde: Vector3 = pose["onde"]
	var figura := _jogador.figura()

	# Cleiton: igreja ~271,-54.75 fachada; look axis ~271,-51; coreto ~264,-46 W.
	var igreja := Vector3(271.0, onde.y + 3.5, -51.0)
	var meio_corpo := Vector3(onde.x, onde.y + 0.35, onde.z)

	# Lampiao quente a SW (esquerda do pin).
	if _apoio != null and is_instance_valid(_apoio):
		_apoio.global_position = Vector3(265.0, onde.y + 3.4, -40.0)
		_apoio.light_color = Color("ffb45a")
		_apoio.light_energy = 6.0
		_apoio.omni_range = 10.0

	# --- Part A: POV olho no ceu / nevoa (sem stand-up) --------------------
	_limpar_pernas_fp()
	_jogador.mostrar_corpo(false)
	if figura != null:
		figura.postura(Corpo.Postura.DEITADO_ACORDAR)

	var cam_olho := Vector3(onde.x, onde.y + 0.18, onde.z)
	# Quase reto pra cima: so nevoa/ceu. Desvio minimo em Z pro look_at.
	var olhar_ceu := Vector3(onde.x, onde.y + 22.0, onde.z - 0.8)
	var olhar_esq := Vector3(onde.x - 10.0, onde.y + 16.0, onde.z - 1.5)
	var olhar_dir := Vector3(onde.x + 10.0, onde.y + 16.0, onde.z - 1.5)

	Cinema.enquadrar(cam_olho, olhar_ceu, 70.0)

	if _hud != null:
		_hud.visible = true
	await Cinema.clarear(1.8)
	Cinema.legenda(FALAS["acorda"], 1.8)
	# Abrir o olho olhando o ceu, depois varrer esquerda -> direita (ainda nevoa).
	Cinema.mover(cam_olho, cam_olho, olhar_ceu, olhar_esq, 1.0, 70.0, 68.0)
	await get_tree().create_timer(1.0).timeout
	Cinema.mover(cam_olho, cam_olho, olhar_esq, olhar_dir, 1.35, 68.0, 68.0)
	await get_tree().create_timer(0.55).timeout
	await _capturar_plano("01_acordar_ceu")
	await get_tree().create_timer(0.85).timeout

	# --- Part B: takes externos, corpo AINDA DEITADO -----------------------
	await Cinema.corte(0.14)
	_jogador.mostrar_corpo(true)
	if figura != null:
		figura.postura(Corpo.Postura.DEITADO_ACORDAR)

	# praca_1 — high 3/4 overhead, corpo FG, igreja atras.
	var c1 := Vector3(onde.x - 1.8, onde.y + 8.2, onde.z + 5.2)
	var l1 := Vector3(igreja.x, onde.y + 2.0, igreja.z)
	Cinema.enquadrar(c1, l1, 56.0)
	await Cinema.clarear(0.35)
	Cinema.legenda(FALAS["praca_1"], 3.8)
	await get_tree().create_timer(0.55).timeout
	await _capturar_plano("02_deitado_igreja")
	await get_tree().create_timer(3.3).timeout

	# praca_2 — lower 3/4 from SW; coreto a esquerda, igreja atras do corpo.
	await Cinema.corte(0.1)
	var c2 := Vector3(onde.x - 6.0, onde.y + 2.6, onde.z + 3.8)
	var l2 := Vector3(igreja.x, onde.y + 1.5, igreja.z)
	Cinema.enquadrar(c2, l2, 54.0)
	await Cinema.clarear(0.28)
	Cinema.legenda(FALAS["praca_2"], 3.2)
	await get_tree().create_timer(0.5).timeout
	await _capturar_plano("praca_2")
	await get_tree().create_timer(2.8).timeout

	# praca_3 — perfil / lado do corpo, leitura da praca.
	await Cinema.corte(0.1)
	var c3 := Vector3(onde.x + 5.5, onde.y + 1.9, onde.z + 0.6)
	var l3 := Vector3(onde.x - 1.0, onde.y + 0.55, onde.z - 2.5)
	Cinema.mover(
		c3, Vector3(c3.x - 0.6, c3.y - 0.15, c3.z - 0.8),
		l3, Vector3(l3.x - 0.4, l3.y, l3.z - 1.2),
		3.2, 58.0, 54.0)
	await Cinema.clarear(0.28)
	Cinema.legenda(FALAS["praca_3"], 3.4)
	await get_tree().create_timer(0.5).timeout
	await _capturar_plano("praca_3")
	await get_tree().create_timer(3.0).timeout

	# praca_4 — closer face/torso deitado, igreja soft bg.
	await Cinema.corte(0.1)
	var c4 := Vector3(onde.x + 1.6, onde.y + 1.15, onde.z + 2.2)
	var l4 := Vector3(onde.x - 0.2, onde.y + 0.45, onde.z - 0.4)
	Cinema.enquadrar(c4, l4, 48.0)
	await Cinema.clarear(0.28)
	Cinema.legenda(FALAS["praca_4"], 3.2)
	await get_tree().create_timer(0.5).timeout
	await _capturar_plano("praca_4")
	await get_tree().create_timer(2.8).timeout

	# praca_5 — wider establishing: corpo + igreja + lampiao.
	await Cinema.corte(0.1)
	var c5 := Vector3(onde.x - 7.5, onde.y + 4.8, onde.z + 7.0)
	var l5 := Vector3(igreja.x - 1.0, onde.y + 2.4, igreja.z)
	Cinema.enquadrar(c5, l5, 62.0)
	await Cinema.clarear(0.28)
	Cinema.legenda(FALAS["praca_5"], 3.6)
	await get_tree().create_timer(0.5).timeout
	await _capturar_plano("praca_5")
	await get_tree().create_timer(3.2).timeout

	if _hud != null:
		_hud.visible = false

	# Proximos planos escondem/re-posam o corpo; desfaz o deitar SEM animacao
	# de levantar (nao e stand-up cinematografico).
	if figura != null:
		_deitar(figura, false)
		figura.postura(Corpo.Postura.LIVRE)
'''

t = t[:i0] + new_plano + t[i1:]

# --- dual-write captures for 02_deitado ---
old_cap = '''\tif nome.begins_with("01_acordar") or nome.begins_with("praca_"):'''
new_cap = '''\tif (nome.begins_with("01_acordar") or nome.begins_with("02_deitado")
			or nome.begins_with("praca_")):'''
if old_cap not in t:
    raise SystemExit("capturar dual-write needle missing")
t = t.replace(old_cap, new_cap, 1)

# --- avenida / poste durations tied to FALAS ---
reps = [
    ('Cinema.legenda(FALAS["avenida_1"], 5.2)', 'Cinema.legenda(FALAS["avenida_1"], 3.8)'),
    ('Cinema.legenda(FALAS["avenida_2"], 5.4)', 'Cinema.legenda(FALAS["avenida_2"], 3.8)'),
    ('Cinema.legenda(FALAS["poste_3"], 4.0)', 'Cinema.legenda(FALAS["poste_3"], 4.2)'),
]
for a, b in reps:
    if a not in t:
        raise SystemExit(f"missing duration needle: {a}")
    t = t.replace(a, b, 1)

p.write_text(t, encoding="utf-8")
print("OK patched abertura.gd", len(t))
