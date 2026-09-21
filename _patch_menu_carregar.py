# -*- coding: utf-8 -*-
from pathlib import Path

path = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\ui\menu.gd")
text = path.read_text(encoding="utf-8")
orig = text

def must_replace(old: str, new: str, label: str) -> None:
    global text
    if old not in text:
        raise SystemExit(f"FAIL: block not found: {label}\n---\n{old[:200]!r}")
    text = text.replace(old, new, 1)
    print("OK:", label)

# 1) Vars
must_replace(
"""var _itens_espacos: Array[Label] = []
var _nota_espacos: Label
## A linha que explica o item escolhido. Ver `_texto_da_nota`.
var _nota_titulo: Label""",
"""var _itens_espacos: Array[Label] = []
var _nota_espacos: Label
## Painel RE7 de cards de save no titulo (substitui a lista legado ESPACOS).
var _save_panel: SaveCardsPanelRe7
var _audio_save_pushed: bool = false
## A linha que explica o item escolhido. Ver `_texto_da_nota`.
var _nota_titulo: Label""",
"vars")

# 2) Rewrite _montar_carregar + handlers
must_replace(
"""## A pagina dos tres espacos de save.
##
## Mesma lista, mesma placa, mesma fonte: e a MESMA tela, uma pagina adiante.
## Tela nova com vocabulario proprio era o caminho mais curto e o errado - o menu
## de sistema em jogo ja tem uma pagina CARREGAR, e duas telas que fazem a mesma
## coisa com desenhos diferentes ensinam duas vezes.
##
## O rotulo e fixo ("ESPACO 1"); o que varia - o lugar e a hora do save - vai na
## nota embaixo da lista, que muda conforme o cursor anda. Por que assim: o resumo
## inteiro numa linha de 137 px sairia cortado com reticencia em toda partida cujo
## lugar tenha mais de doze letras, e "A CASA DA FUMACA" tem dezesseis.
func _montar_carregar() -> void:
	_no_carregar = Control.new()
	_no_carregar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_no_carregar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_no_carregar)

	var par := _fazer_titulo_serif(_no_carregar, TITULO_ONDE_MENU)
	par[1].text = "CARREGAR"
	par[0].text = "CARREGAR"

	_montar_lista(_no_carregar, TituloLayout.ESPACOS, _abas_espacos,
		_marcas_espacos, _realces_espacos, _itens_espacos)

	var caixa_nota := TituloLayout.nota()
	_nota_espacos = _rotulo(_no_carregar, "", caixa_nota.position, caixa_nota.size,
		FONTE_P, NOTA_COR, HORIZONTAL_ALIGNMENT_CENTER)
	_nota_espacos.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	_nota_espacos.add_theme_constant_override(&"outline_size", 3)

	var caixa_dica := TituloLayout.dica()
	var dica := _rotulo(_no_carregar, "[W/S] mover   [E] carregar   [ESC] voltar",
		caixa_dica.position, caixa_dica.size, FONTE_P,
		Color(0.78, 0.76, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	dica.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	dica.add_theme_constant_override(&"outline_size", 4)
	_no_carregar.visible = false""",
"""## A pagina CARREGAR do titulo: serif + SaveCardsPanelRe7.
##
## A lista legado (TituloLayout.ESPACOS / placas) saiu: o menu de sistema em jogo
## ja usa SaveCardsPanelRe7, e duas telas que fazem a mesma coisa com desenhos
## diferentes ensinam duas vezes. `_abas_espacos` / `_itens_espacos` / nota
## ficam vazios de proposito — guards em `_pintar_lista` e input evitam crash.
func _montar_carregar() -> void:
	_no_carregar = Control.new()
	_no_carregar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_no_carregar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_no_carregar)

	var par := _fazer_titulo_serif(_no_carregar, TITULO_ONDE_MENU)
	par[1].text = "CARREGAR"
	par[0].text = "CARREGAR"

	_save_panel = SaveCardsPanelRe7.new()
	_save_panel.name = "SaveCardsPanelRe7"
	_save_panel.z_index = 20
	_save_panel.position = Vector2(130.0, 31.0)
	_no_carregar.add_child(_save_panel)
	_save_panel.pediu_carregar.connect(_on_title_save_carregar)
	_save_panel.pediu_voltar.connect(_on_title_save_voltar)

	_no_carregar.visible = false


func _on_title_save_carregar(espaco: int) -> void:
	if not SaveGame.existe(espaco):
		return
	if SaveGame.carregar(espaco):
		_pop_save_audio()
		esconder()
		continuar.emit()


func _on_title_save_voltar() -> void:
	_pop_save_audio()
	mostrar(Painel.TITULO)


func _push_save_audio() -> void:
	if _audio_save_pushed:
		return
	AudioDirector.on_menu_push(&"save")
	_audio_save_pushed = true


func _pop_save_audio() -> void:
	if not _audio_save_pushed:
		return
	AudioDirector.on_menu_pop()
	_audio_save_pushed = false""",
"montar_carregar")

# 3) Guard animar entrada
must_replace(
"""func _animar_entrada_espacos() -> void:
	var tw := create_tween()""",
"""func _animar_entrada_espacos() -> void:
	if _itens_espacos.is_empty():
		return
	var tw := create_tween()""",
"animar_entrada")

# 4) lista foco — so TITULO
must_replace(
"""func _lista_tem_foco() -> bool:
	return painel == Painel.TITULO or painel == Painel.CARREGAR""",
"""func _lista_tem_foco() -> bool:
	# CARREGAR do titulo usa SaveCardsPanelRe7 — o painel e dono do foco.
	return painel == Painel.TITULO""",
"lista_tem_foco")

# 5) mostrar head — pop on leave
must_replace(
"""func mostrar(qual: Painel) -> void:
	var vinha_titulo := visible and painel == Painel.TITULO
	# O menu ja estava na tela antes desta troca de painel? Ver a cortina preta
	# mais abaixo.
	_menu_estava_na_tela = visible
	painel = qual
	_selecionado = 0""",
"""func mostrar(qual: Painel) -> void:
	var vinha_titulo := visible and painel == Painel.TITULO
	var vinha_carregar := painel == Painel.CARREGAR
	# O menu ja estava na tela antes desta troca de painel? Ver a cortina preta
	# mais abaixo.
	_menu_estava_na_tela = visible
	painel = qual
	if vinha_carregar and qual != Painel.CARREGAR:
		_pop_save_audio()
	_selecionado = 0""",
"mostrar_head")

# 6) mostrar CARREGAR body
must_replace(
"""	if qual == Painel.CARREGAR:
		_animar_entrada_espacos()
	# Boot, titulo e a pagina de saves deixam o mundo vivo. Outros pausam.""",
"""	if qual == Painel.CARREGAR:
		_push_save_audio()
		if _save_panel != null:
			_save_panel.refresh_from_savegame()
			_save_panel.call_deferred("foco_padrao")
		# Lista legado vazia: animacao de placas no-op.
		_animar_entrada_espacos()
	# Boot, titulo e a pagina de saves deixam o mundo vivo. Outros pausam.""",
"mostrar_carregar")

# 7) esconder
must_replace(
"""func esconder() -> void:
	visible = false
	_animando_titulo = false
	_transicionando = false
	_boot_pronto = false""",
"""func esconder() -> void:
	_pop_save_audio()
	visible = false
	_animando_titulo = false
	_transicionando = false
	_boot_pronto = false""",
"esconder")

# 8) _atualizar guards
must_replace(
"""	_pintar_lista(Painel.TITULO, TituloLayout.ITENS, _itens_titulo, _abas_titulo,
		_marcas_titulo, _realces_titulo)
	_pintar_lista(Painel.CARREGAR, TituloLayout.ESPACOS, _itens_espacos,
		_abas_espacos, _marcas_espacos, _realces_espacos)
	if _nota_titulo != null and painel == Painel.TITULO:
		_nota_titulo.text = _texto_da_nota()
	if _nota_espacos != null and painel == Painel.CARREGAR:
		_nota_espacos.text = _texto_da_nota()""",
"""	_pintar_lista(Painel.TITULO, TituloLayout.ITENS, _itens_titulo, _abas_titulo,
		_marcas_titulo, _realces_titulo)
	if not _itens_espacos.is_empty():
		_pintar_lista(Painel.CARREGAR, TituloLayout.ESPACOS, _itens_espacos,
			_abas_espacos, _marcas_espacos, _realces_espacos)
	if _nota_titulo != null and painel == Painel.TITULO:
		_nota_titulo.text = _texto_da_nota()
	if _nota_espacos != null and painel == Painel.CARREGAR and not _itens_espacos.is_empty():
		_nota_espacos.text = _texto_da_nota()""",
"atualizar")

# 9) _entrada_viva
must_replace(
"""func _entrada_viva(dono: Painel, entradas: Array, i: int) -> bool:
	if dono == Painel.CARREGAR:
		return i >= SaveGame.ESPACOS or SaveGame.existe(i)
	return _item_vivo(String(entradas[i]))""",
"""func _entrada_viva(dono: Painel, entradas: Array, i: int) -> bool:
	if dono == Painel.CARREGAR:
		if _itens_espacos.is_empty():
			return false
		return i >= SaveGame.ESPACOS or SaveGame.existe(i)
	return _item_vivo(String(entradas[i]))""",
"entrada_viva")

# 10) _texto_da_nota — only the CARREGAR guard at top (ASCII-safe match)
old_nota = """func _texto_da_nota() -> String:
	if painel == Painel.CARREGAR:
		if _selecionado >= SaveGame.ESPACOS:
			return \"volta para o menu\""""
new_nota = """func _texto_da_nota() -> String:
	if painel == Painel.CARREGAR:
		if _itens_espacos.is_empty():
			return \"\"
		if _selecionado >= SaveGame.ESPACOS:
			return \"volta para o menu\""""
must_replace(old_nota, new_nota, "texto_da_nota")

# 11) _unhandled_input
must_replace(
"""	if painel == Painel.APARENCIA:
		_criacao.navegar(evento)
		get_viewport().set_input_as_handled()
		return

	# Quantos itens a tecla percorre: depende de QUAL lista esta na tela.
	var n := _opcoes.size()
	if painel == Painel.TITULO:
		n = _itens_titulo.size()
	elif painel == Painel.CARREGAR:
		n = _itens_espacos.size()

	if evento.is_action_pressed("mover_tras"):""",
"""	if painel == Painel.APARENCIA:
		_criacao.navegar(evento)
		get_viewport().set_input_as_handled()
		return

	# SaveCardsPanelRe7 e dono do foco em CARREGAR — nao dirigir lista legado.
	if painel == Painel.CARREGAR and _save_panel != null and _save_panel.visible:
		if evento.is_action_pressed("pausa"):
			mostrar(Painel.TITULO)
			get_viewport().set_input_as_handled()
		return

	# Quantos itens a tecla percorre: depende de QUAL lista esta na tela.
	var n := _opcoes.size()
	if painel == Painel.TITULO:
		n = _itens_titulo.size()
	elif painel == Painel.CARREGAR:
		n = _itens_espacos.size()
		if n == 0:
			return

	if evento.is_action_pressed("mover_tras"):""",
"unhandled_input")

# 12) _acionar
must_replace(
"""	if painel == Painel.CARREGAR:
		_acionar_espaco()
		return""",
"""	if painel == Painel.CARREGAR:
		# Painel RE7 emite pediu_carregar; lista legado so se ainda existir.
		if _save_panel != null and _itens_espacos.is_empty():
			return
		_acionar_espaco()
		return""",
"acionar")

if text == orig:
    raise SystemExit("FAIL: no changes applied")

path.write_text(text, encoding="utf-8")
print("WROTE", path, "bytes", path.stat().st_size)
