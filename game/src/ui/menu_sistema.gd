## Menu de sistema em jogo �?" os tres pauzinhos da prancha.
##
## Upgrade AAA (19/09/2026): pauzinhos hit >=32x32, folha RAIZ com hierarquia,
## focus stain+barra+`>`, mouse parity, motion T_RE7_* / focus T_RE7_FOCUS (P0 F POLISH_PANEL).
## Fonte de opcoes: OpcoesLista. Tokens: UiEstilo.
class_name MenuSistema
extends Control

enum Pagina { RAIZ, VIDEO, AUDIO, CARREGAR, HUD, HUD_PECAS, HUD_EXIBICAO }

signal continuar()
signal sair_para_titulo()
signal carregou(espaco: int)

const FOLHA_X := 144.0
const FOLHA_Y := 44.0
const FOLHA_L := 192.0
const PAD := 12.0
const VAO := 2.0

## Hit invisivel A11y (SPEC_VISUAL A2). Placa visual fica centrada nele.
const HIT_ABA := Rect2(440.0, 4.0, 34.0, 24.0)
## Placa 22x18 centrada no hit (offset +5,+7).
const PLACA_ABA := Rect2(447.0, 8.0, 20.0, 16.0)
## Barras 14x2, gap 3, centradas na placa.
const BARRA_L := 14.0
const BARRA_A := 2.0
const BARRA_GAP := 3.0

## Indices de hairline na RAIZ (depois de CARREGAR e depois de HUD).
const RAIZ_DIVISORES := [1, 4]
## Na pagina HUD: depois do modo, depois da opacidade e antes das subpaginas.
const HUD_DIVISORES := [0, 2, 4]

## Modelo de linha. Tudo — texto, destaque, barra, area de clique e divisor —
## sai do TOPO da linha. A versao anterior usava a altura de clique de 32 px como
## passo entre linhas e ancorava tudo em `baseline - 32 + 3`: o destaque ficava
## inteiro acima do texto, a barra vermelha solta, o divisor cortava IMAGEM ao
## meio e a folha passava do pe da tela (medido na print do usuario).
const LINHA := 16.0
const PASSO := 18.0
## Do topo da folha ao topo da primeira linha: margem, titulo e as duas reguas.
const CABECALHO := 36.0
## Da ultima linha ao pe da folha, onde mora a dica de teclas.
const RODAPE := 22.0
## Indices de hairline em VIDEO (depois de ESTILO e depois de NEVOA).
const VIDEO_DIVISORES := [0, 2]

var pagina: Pagina = Pagina.RAIZ
var aberto: bool = false
var _audio_menu_own: bool = false
var _uimanager_pushed: bool = false

var _sel: int = 0
var _fonte: Font
var _fonte_titulo: Font
var _tam_body: int = UiEstilo.RE7_SIZE_BODY
var _tam_title: int = UiEstilo.RE7_SIZE_TITLE
var _tam_micro: int = UiEstilo.RE7_SIZE_MICRO
var _linha: float = 13.0
var _hit_linha: float = 14.0
var _itens: Array[Dictionary] = []
var _camada_aba: CanvasLayer
var _aba: Control
var _hit_aba: Control
var _hits_linha: Array[Control] = []

## Motion / focus (SPEC_MOTION).
var _folha_alfa: float = 0.0
var _folha_dy: float = 8.0
var _conteudo_alfa: float = 1.0
var _foco_alfa: float = 1.0
var _aba_hover: bool = false
var _tween_folha: Tween
var _tween_foco: Tween
var _tween_pagina: Tween
var _input_travado: bool = false
## Ignora mouse_entered ate o mouse mexer (evita roubar foco do CONTINUAR).
var _hover_armado: bool = false
## Relogio do stagger de linhas no open (SPEC_MOTION / ADDENDUM RE).
var _stagger_t: float = 99.0
var _aba_pressed: bool = false

## P0 F — StyleBox RE7 consumer (nao reescreve draw_rect da folha).
var _painel_re7: Panel

## Onda 4 RE7 — Save Cards panel (on-top da pagina CARREGAR).
var _save_panel: SaveCardsPanelRe7
var _stick_gate: MenuStickGate = MenuStickGate.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	size = UiEstilo.TELA
	z_index = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	# RE7: SystemFont sans — sem psx_*.fnt nesta superficie (PO2).
	_fonte = UiEstilo.fonte_re7(400)
	_fonte_titulo = UiEstilo.fonte_re7(600)
	_tam_body = UiEstilo.RE7_SIZE_BODY
	_tam_title = UiEstilo.RE7_SIZE_TITLE
	_tam_micro = UiEstilo.RE7_SIZE_MICRO
	_linha = float(UiEstilo.RE7_LINE_BODY)
	# A11Y_FOCUS_STACK: hit linha ≥32 UI (SPEC §5); token HIT_LINHA_MIN tambem 32.
	_hit_linha = maxf(_linha, maxf(float(UiEstilo.HIT_LINHA_MIN), 32.0))
	visibility_changed.connect(queue_redraw)
	_montar_aba()
	_montar_painel_re7()


func _montar_aba() -> void:
	_camada_aba = CanvasLayer.new()
	_camada_aba.name = "AbaAcimaDoPos"
	_camada_aba.layer = UiEstilo.CAMADA_ACIMA_DO_POS
	_camada_aba.visible = false
	add_child(_camada_aba)

	_aba = Control.new()
	_aba.name = "Pauzinhos"
	_aba.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aba.position = Vector2.ZERO
	_aba.size = UiEstilo.TELA
	_aba.draw.connect(_desenhar_pauzinhos)
	_camada_aba.add_child(_aba)

	_hit_aba = Control.new()
	_hit_aba.name = "HitPauzinhos"
	_hit_aba.mouse_filter = Control.MOUSE_FILTER_STOP
	_hit_aba.position = HIT_ABA.position
	_hit_aba.size = HIT_ABA.size
	_hit_aba.mouse_entered.connect(_ao_aba_hover.bind(true))
	_hit_aba.mouse_exited.connect(_ao_aba_hover.bind(false))
	_hit_aba.gui_input.connect(_ao_aba_input)
	_aba.add_child(_hit_aba)


func _montar_painel_re7() -> void:
	## Painel StyleBox atras da folha papel (show_behind_parent). Draw_rect da folha intacto.
	_painel_re7 = Panel.new()
	_painel_re7.name = "PainelRe7"
	_painel_re7.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel_re7.show_behind_parent = true
	_painel_re7.add_theme_stylebox_override("panel", UiEstilo.style_re7_panel())
	_painel_re7.visible = false
	_painel_re7.modulate = Color(1, 1, 1, 0)
	add_child(_painel_re7)
	move_child(_painel_re7, 0)
	_sincronizar_painel_re7()


func _sincronizar_painel_re7() -> void:
	if _painel_re7 == null:
		return
	# CARREGAR: so scrim + SaveCardsPanelRe7 — esconde paper StyleBox.
	if pagina == Pagina.CARREGAR and _save_panel != null and _save_panel.visible:
		_painel_re7.visible = false
		_painel_re7.modulate = Color(1, 1, 1, 0)
		return
	var folha := _folha()
	folha.position.y += _folha_dy
	var pad := float(UiEstilo.RE7_SAFE_HARD)
	_painel_re7.position = folha.position - Vector2(pad, pad)
	_painel_re7.size = folha.size + Vector2(pad * 2.0, pad * 2.0)
	var a := clampf(_folha_alfa, 0.0, 1.0)
	_painel_re7.modulate = Color(1, 1, 1, a)
	_painel_re7.visible = a > 0.01


func mostrar_aba(ligada: bool) -> void:
	if _camada_aba != null:
		_camada_aba.visible = ligada
	if _aba != null:
		_aba.queue_redraw()


## SPEC_A11Y_RE7 §3 — default focus quando UIManager.push_menu chama deferred.
## Sistema usa _sel custom p/ D-pad nas linhas; hits tem FOCUS_ALL p/ grab_focus / SaveCards.
func foco_padrao() -> void:
	if pagina == Pagina.CARREGAR and _save_panel != null and _save_panel.visible:
		_save_panel.foco_padrao()
		return
	_sel = 0
	if not _hits_linha.is_empty() and is_instance_valid(_hits_linha[0]):
		if _hits_linha[0].focus_mode != Control.FOCUS_NONE:
			_hits_linha[0].grab_focus()
	queue_redraw()


# --- UIManager stack (FILO nested sob prancha) -------------------------------

func _empilhar_uimanager(kind: StringName) -> void:
	if _uimanager_pushed:
		return
	UIManager.push_menu(self, false, kind)
	_uimanager_pushed = true


func _desempilhar_uimanager() -> void:
	if not _uimanager_pushed:
		return
	UIManager.remove_menu(self)
	_uimanager_pushed = false

# --- estado -----------------------------------------------------------------

func abrir() -> void:
	aberto = true
	_hover_armado = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _aba != null:
		_aba.queue_redraw()
	_ir_para(Pagina.RAIZ, false)
	_animar_abrir()
	# Nested sob prancha: UIManager so dispara audio se stack vazia — drone local.
	_empilhar_uimanager(&"sistema")
	AudioDirector.drone_on()


func fechar(animado: bool = true) -> void:
	if not aberto:
		return
	if not animado:
		_matar(_tween_folha)
		_input_travado = false
		_fechar_imediato()
		return
	_animar_fechar()


func abrir_em(qual: Pagina) -> void:
	aberto = true
	_hover_armado = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _aba != null:
		_aba.queue_redraw()
	_ir_para(qual, false)
	# Captura: assenta sem esperar tween longo.
	_folha_alfa = 1.0
	_folha_dy = 0.0
	_conteudo_alfa = 1.0
	_foco_alfa = 1.0
	_sincronizar_painel_re7()
	_stagger_t = 99.0
	_input_travado = false
	queue_redraw()
	# Capture/CLI: CARREGAR → kind save (duck+drone); demais → sistema.
	# Uma entrada UIManager por sessao aberta — _ir_para nao empurra de novo.
	var kind: StringName = &"save" if qual == Pagina.CARREGAR else &"sistema"
	var profundidade_antes := UIManager.profundidade()
	var ja_empilhado := _uimanager_pushed
	_empilhar_uimanager(kind)
	if ja_empilhado:
		# Ja no stack (ex.: _ir_para / reentrada) — so foco; sem 2o push/audio.
		pass
	elif profundidade_antes == 0:
		# UIManager.push_menu ja chamou on_menu_push(kind) (stack era vazia).
		_audio_menu_own = false
	else:
		# Nested (ex.: sob prancha): audio local uma vez.
		AudioDirector.on_menu_push(kind)
		_audio_menu_own = true


func _fechar_imediato() -> void:
	aberto = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_folha_alfa = 0.0
	_folha_dy = 0.0
	if _save_panel != null:
		_save_panel.visible = false
	_limpar_hits_linha()
	if _aba != null:
		_aba.queue_redraw()
	_sincronizar_painel_re7()
	Settings.save_config()
	if _audio_menu_own:
		_audio_menu_own = false
		AudioDirector.on_menu_pop()
	else:
		AudioDirector.drone_off()
	# FILO: tira sistema do stack antes da prancha chamar remove_menu(self).
	_desempilhar_uimanager()
	queue_redraw()


func _ir_para(qual: Pagina, animar: bool = true) -> void:
	var anterior := pagina
	pagina = qual
	_sel = 0
	_itens = _montar_itens(qual)
	_reconstruir_hits_linha()
	_sync_save_panel(qual)
	if animar and aberto and anterior != qual:
		_animar_pagina()
	else:
		_conteudo_alfa = 1.0
		_foco_alfa = 1.0
		queue_redraw()


func _montar_itens(qual: Pagina) -> Array[Dictionary]:
	match qual:
		Pagina.VIDEO:
			var v := OpcoesLista.video()
			v.append(_voltar())
			return v
		Pagina.AUDIO:
			var a := OpcoesLista.audio()
			a.append(_voltar())
			return a
		Pagina.HUD:
			var h := OpcoesLista.hud()
			h.append(_nav("EXIBICAO", func() -> void: _ir_para(Pagina.HUD_EXIBICAO)))
			h.append(_nav("PECAS DO HUD", func() -> void: _ir_para(Pagina.HUD_PECAS)))
			h.append(_voltar())
			return h
		Pagina.HUD_EXIBICAO:
			var ex := OpcoesLista.hud_exibicao()
			ex.append(_acao("VOLTAR", func() -> void: _ir_para(Pagina.HUD)))
			return ex
		Pagina.HUD_PECAS:
			var pp := OpcoesLista.hud_pecas()
			# Volta para o HUD, e nao para a raiz: e uma subpagina.
			pp.append(_acao("VOLTAR", func() -> void: _ir_para(Pagina.HUD)))
			return pp
		Pagina.CARREGAR:
			# Onda 4: lista papel substituida pelo SaveCardsPanelRe7.
			return []
		_:
			return _raiz()


func _raiz() -> Array[Dictionary]:
	var tem_save := false
	for i in SaveGame.ESPACOS:
		tem_save = tem_save or SaveGame.existe(i)
	return [
		_acao("CONTINUAR", func() -> void:
			fechar(false)
			continuar.emit()),
		_nav("CARREGAR", func() -> void: _ir_para(Pagina.CARREGAR), tem_save),
		_nav("IMAGEM", func() -> void: _ir_para(Pagina.VIDEO)),
		_nav("SOM", func() -> void: _ir_para(Pagina.AUDIO)),
		_nav("HUD", func() -> void: _ir_para(Pagina.HUD)),
		_acao_destrutiva("SAIR PARA O TITULO", func() -> void:
			fechar(false)
			sair_para_titulo.emit()),
	]


func _espacos() -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	for i in SaveGame.ESPACOS:
		var n := i
		var existe := SaveGame.existe(n)
		var resumo := SaveGame.resumo(n) if existe else {}
		var rotulo := "ESPACO %d" % (n + 1)
		var valor := "VAZIO"
		if existe:
			valor = String(resumo.get("local", "")).to_upper()
			if valor.is_empty():
				valor = "GRAVADO"
		saida.append({
			"rotulo": rotulo,
			"ler": func() -> String: return valor,
			"acionar": func() -> void:
				if not existe:
					AudioDirector.tocar_nav(-18.0)
					return
				fechar(false)
				carregou.emit(n),
			"vivo": existe,
		})
	saida.append(_voltar())
	return saida


func _acao(rotulo: String, quando: Callable, vivo: bool = true) -> Dictionary:
	return {
		"rotulo": rotulo,
		"ler": func() -> String: return "",
		"acionar": quando,
		"vivo": vivo,
	}


func _nav(rotulo: String, quando: Callable, vivo: bool = true) -> Dictionary:
	var d := _acao(rotulo, quando, vivo)
	d["nav"] = true
	return d


func _acao_destrutiva(rotulo: String, quando: Callable) -> Dictionary:
	var d := _acao(rotulo, quando, true)
	d["destrutivo"] = true
	return d


func _voltar() -> Dictionary:
	return _acao("VOLTAR", func() -> void:
		if pagina == Pagina.RAIZ:
			fechar(true)
		else:
			_ir_para(Pagina.RAIZ))


# --- mouse hits -------------------------------------------------------------

func _limpar_hits_linha() -> void:
	for h in _hits_linha:
		if is_instance_valid(h):
			h.queue_free()
	_hits_linha.clear()


func _reconstruir_hits_linha() -> void:
	_limpar_hits_linha()
	if not aberto:
		return
	var ys := _topos_linhas()
	for i in _itens.size():
		var hit := Control.new()
		hit.name = "HitLinha%d" % i
		hit.mouse_filter = Control.MOUSE_FILTER_STOP
		hit.focus_mode = Control.FOCUS_ALL
		# As areas de clique ladrilham as linhas: cada uma do topo da sua linha
		# ao topo da proxima, sem buraco e sem sobrepor a vizinha.
		hit.position = Vector2(FOLHA_X + PAD - 6.0, ys[i] - 1.0 + _folha_dy)
		hit.size = Vector2(FOLHA_L - PAD * 2.0 + 12.0, PASSO)
		var idx := i
		hit.mouse_entered.connect(func() -> void: _ao_linha_hover(idx))
		hit.gui_input.connect(func(ev: InputEvent) -> void: _ao_linha_input(ev, idx))
		hit.focus_entered.connect(func() -> void:
			if aberto and not _input_travado and _sel != idx:
				_sel = idx
				queue_redraw())
		add_child(hit)
		_hits_linha.append(hit)
	_wire_hits_focus_neighbors()
	# So armamos hover no proximo frame / no primeiro movimento.
	_hover_armado = false
	call_deferred("_armar_hover_depois")


func _wire_hits_focus_neighbors() -> void:
	var n := _hits_linha.size()
	for i in n:
		var h := _hits_linha[i]
		var prev: Control = _hits_linha[i - 1] if i > 0 else h
		var nxt: Control = _hits_linha[i + 1] if i < n - 1 else h
		h.focus_neighbor_top = h.get_path_to(prev)
		h.focus_neighbor_bottom = h.get_path_to(nxt)
		h.focus_neighbor_left = h.get_path_to(h)
		h.focus_neighbor_right = h.get_path_to(h)


func _reposicionar_hits() -> void:
	if _hits_linha.is_empty():
		return
	var ys := _topos_linhas()
	for i in mini(_hits_linha.size(), ys.size()):
		_hits_linha[i].position = Vector2(FOLHA_X + PAD - 6.0, ys[i] - 1.0 + _folha_dy)


func _ao_aba_hover(ligado: bool) -> void:
	_aba_hover = ligado
	if _aba != null:
		_aba.queue_redraw()


func _ao_aba_input(evento: InputEvent) -> void:
	if evento is InputEventMouseButton:
		var mb := evento as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_aba_pressed = true
				if _aba != null:
					_aba.queue_redraw()
				accept_event()
			else:
				if _aba_pressed:
					_aba_pressed = false
					if _aba != null:
						_aba.queue_redraw()
					accept_event()
					if aberto:
						fechar()
					else:
						abrir()


func _ao_linha_hover(idx: int) -> void:
	if not _hover_armado or not aberto or _input_travado:
		return
	_focar(idx, true)


func _armar_hover_depois() -> void:
	# Um frame: controles novos sob o cursor nao roubam o default CONTINUAR.
	await get_tree().process_frame
	_hover_armado = true


func _ao_linha_input(evento: InputEvent, idx: int) -> void:

	if not aberto or _input_travado:
		return
	if evento is InputEventMouseButton:
		var mb := evento as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			accept_event()
			_focar(idx, false)
			_acionar()


func _gui_input(evento: InputEvent) -> void:
	# Clique no scrim (fora da folha) fecha �?" mesma saida de ESC na RAIZ.
	if not aberto or _input_travado:
		return
	if evento is InputEventMouseMotion:
		_hover_armado = true
	if evento is InputEventMouseButton:
		var mb := evento as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var folha := _folha()
			folha.position.y += _folha_dy
			if not folha.has_point(mb.position):
				accept_event()
				if pagina == Pagina.RAIZ:
					fechar()
				else:
					_ir_para(Pagina.RAIZ)


# --- entrada ----------------------------------------------------------------

func tratar(evento: InputEvent) -> bool:
	if not aberto:
		return false
	if _input_travado:
		return true
	# Onda 4: na pagina CARREGAR o painel RE7 dono do focus (gui antes de unhandled).
	if pagina == Pagina.CARREGAR and _save_panel != null and _save_panel.visible:
		if evento.is_action_pressed("examinar") or evento.is_action_pressed("pausa"):
			_ir_para(Pagina.RAIZ)
			return true
		# Stick/motion: consome com menu no topo (SaveCards dono do focus Godot).
		if evento is InputEventJoypadMotion:
			return true
		return true
	# Stick esquerdo → 1 passo (deadzone≥0.5 / cruz). Right stick ignorado no gate.
	if evento is InputEventJoypadMotion:
		var st: Vector2i = _stick_gate.poll()
		if st.y < 0:
			_andar(-1)
		elif st.y > 0:
			_andar(1)
		elif st.x != 0:
			_ajustar(st.x)
		return true
	if evento.is_action_pressed("mover_frente") or evento.is_action_pressed("ui_up"):
		_andar(-1)
	elif evento.is_action_pressed("mover_tras") or evento.is_action_pressed("ui_down"):
		_andar(1)
	elif evento.is_action_pressed("mover_esq"):
		_ajustar(-1)
	elif evento.is_action_pressed("mover_dir"):
		_ajustar(1)
	elif evento.is_action_pressed("interagir") or evento.is_action_pressed("ui_accept"):
		_acionar()
	elif evento.is_action_pressed("examinar") or evento.is_action_pressed("pausa"):
		if pagina == Pagina.RAIZ:
			fechar()
		else:
			_ir_para(Pagina.RAIZ)
	else:
		return false
	return true


func _andar(passo: int) -> void:
	if _itens.is_empty():
		return
	_focar(posmod(_sel + passo, _itens.size()), true)


func _focar(idx: int, com_som: bool) -> void:
	if idx == _sel:
		return
	_sel = idx
	if com_som:
		AudioDirector.tocar_nav(-18.0)
	if idx >= 0 and idx < _hits_linha.size() and is_instance_valid(_hits_linha[idx]):
		if not _hits_linha[idx].has_focus():
			_hits_linha[idx].grab_focus()
	_animar_foco()
	queue_redraw()


func _ajustar(passo: int) -> void:
	if _sel >= _itens.size():
		return
	var item := _itens[_sel]
	if not item.has("aplicar"):
		return
	var aplicar: Callable = item["aplicar"]
	aplicar.call(passo)
	AudioDirector.tocar_nav(-20.0)
	queue_redraw()


func _acionar() -> void:
	if _sel >= _itens.size():
		return
	var item := _itens[_sel]
	if item.has("acionar"):
		AudioDirector.tocar_confirm(-14.0)
		var quando: Callable = item["acionar"]
		quando.call()
		queue_redraw()
		return
	_ajustar(1)


func _process(delta: float) -> void:
	if not aberto:
		return
	# Cascata de linhas: 35 ms/linha, teto no open (SPEC_MOTION).
	if _stagger_t < 4.0:
		_stagger_t += delta
		queue_redraw()


# --- motion -----------------------------------------------------------------

func _matar(tw: Tween) -> void:
	if tw != null and tw.is_valid():
		tw.kill()


func _animar_abrir() -> void:
	_matar(_tween_folha)
	_folha_alfa = 0.0
	_folha_dy = 8.0
	_conteudo_alfa = 1.0
	_foco_alfa = 1.0
	_stagger_t = 0.0
	_input_travado = true
	_sincronizar_painel_re7()
	_tween_folha = create_tween()
	_tween_folha.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween_folha.set_parallel(true)
	## P0 F: T_RE7_OPEN 0.22 · QUAD (sem BACK/ELASTIC/BOUNCE) · lock <250ms
	_tween_folha.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_tween_folha.tween_method(func(v: float) -> void:
		_folha_alfa = v
		_sincronizar_painel_re7()
		queue_redraw()
		_reposicionar_hits(), 0.0, 1.0, UiEstilo.T_RE7_OPEN)
	_tween_folha.tween_method(func(v: float) -> void:
		_folha_dy = v
		_sincronizar_painel_re7()
		queue_redraw()
		_reposicionar_hits(), 8.0, 0.0, UiEstilo.T_RE7_OPEN)
	_tween_folha.finished.connect(func() -> void:
		_input_travado = false
		_reposicionar_hits()
		_sincronizar_painel_re7())


func _animar_fechar() -> void:
	_matar(_tween_folha)
	_input_travado = true
	_tween_folha = create_tween()
	_tween_folha.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween_folha.set_parallel(true)
	## P0 F: T_RE7_CLOSE 0.14 · QUAD · sem BACK/ELASTIC/BOUNCE
	_tween_folha.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_tween_folha.tween_method(func(v: float) -> void:
		_folha_alfa = v
		_sincronizar_painel_re7()
		queue_redraw(), _folha_alfa, 0.0, UiEstilo.T_RE7_CLOSE)
	_tween_folha.tween_method(func(v: float) -> void:
		_folha_dy = v
		_sincronizar_painel_re7()
		queue_redraw()
		_reposicionar_hits(), _folha_dy, 6.0, UiEstilo.T_RE7_CLOSE)
	_tween_folha.finished.connect(func() -> void:
		_input_travado = false
		_fechar_imediato())


func _animar_pagina() -> void:
	_matar(_tween_pagina)
	_input_travado = true
	_conteudo_alfa = 0.0
	_tween_pagina = create_tween()
	_tween_pagina.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween_pagina.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween_pagina.tween_method(func(v: float) -> void:
		_conteudo_alfa = v
		queue_redraw(), 0.0, 1.0, UiEstilo.T_MENU_PAGE)
	_tween_pagina.finished.connect(func() -> void:
		_input_travado = false)


func _animar_foco() -> void:
	_matar(_tween_foco)
	_foco_alfa = 0.35
	_tween_foco = create_tween()
	_tween_foco.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween_foco.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_tween_foco.tween_method(func(v: float) -> void:
		_foco_alfa = v
		queue_redraw(), 0.35, 1.0, UiEstilo.T_RE7_FOCUS)


# --- layout -----------------------------------------------------------------

func _divisores() -> Array:
	match pagina:
		Pagina.RAIZ:
			return RAIZ_DIVISORES
		Pagina.VIDEO:
			return VIDEO_DIVISORES
		Pagina.AUDIO:
			# Master vs resto, se houver master + >=4 buses.
			if _itens.size() >= 5:
				return [0]
			return []
		Pagina.HUD:
			return HUD_DIVISORES
		_:
			return []


func _gap_divisor(i: int) -> float:
	# Ultimo divisor da raiz (antes de SAIR): um respiro maior, e o botao que
	# desfaz a partida.
	return 10.0 if (pagina == Pagina.RAIZ and i == 4) else 7.0


func _altura() -> float:
	var h := CABECALHO + float(_itens.size()) * PASSO + RODAPE
	var divs := _divisores()
	for i in _itens.size():
		if i in divs and i < _itens.size() - 1:
			h += _gap_divisor(i)
	return h


## A folha fica centrada na altura quando e alta (IMAGEM tem nove linhas), e no
## lugar de sempre quando cabe — perto do botao dos tres pauzinhos.
func _folha() -> Rect2:
	var alto := _altura()
	var y := clampf((UiEstilo.TELA.y - alto) * 0.5, 12.0, FOLHA_Y)
	return Rect2(FOLHA_X, y, FOLHA_L, alto)


## Topo de cada linha, sem o deslocamento da animacao.
func _topos_linhas() -> Array[float]:
	var y := _folha().position.y + CABECALHO
	var saida: Array[float] = []
	var divs := _divisores()
	for i in _itens.size():
		saida.append(y)
		y += PASSO
		if i in divs:
			y += _gap_divisor(i)
	return saida


## Linha de base do texto de cada linha. Mantido para quem ainda pergunta por
## ela; o desenho usa o topo.
func _ys_linhas() -> Array[float]:
	var saida: Array[float] = []
	for topo in _topos_linhas():
		saida.append(topo + LINHA * 0.5 + 4.0)
	return saida


# --- desenho ----------------------------------------------------------------

func _draw() -> void:
	if not aberto and _folha_alfa <= 0.01:
		return
	var alfa := clampf(_folha_alfa, 0.0, 1.0)
	var folha := _folha()
	folha.position.y += _folha_dy

	# Scrim tinta (nunca blur/glass) �?" ADDENDUM RE.
	draw_rect(Rect2(Vector2.ZERO, UiEstilo.TELA), Color(0.02, 0.02, 0.03, 0.58 * alfa))

	# Onda 4: CARREGAR = scrim + SaveCardsPanelRe7 (sem folha papel).
	if pagina == Pagina.CARREGAR and _save_panel != null and _save_panel.visible:
		return


	# Sombra em camadas (peso RE) �?" offsets duros, sem blur.
	for off_a in [[3.0, 3.0, 0.50], [1.0, 1.0, 0.35]]:
		var sombra := Color(0.05, 0.04, 0.03, float(off_a[2]) * alfa)
		draw_rect(Rect2(folha.position + Vector2(float(off_a[0]), float(off_a[1])), folha.size), sombra)
	var papel := UiEstilo.PAPEL
	papel.a = alfa
	draw_rect(folha, papel)
	# Inset highlight (skeuomorph leve) �?" 1 px topo/esquerda.
	var luz := Color(1.0, 0.98, 0.90, 0.22 * alfa)
	draw_rect(Rect2(folha.position.x + 1.0, folha.position.y + 1.0, folha.size.x - 2.0, 1.0), luz)
	draw_rect(Rect2(folha.position.x + 1.0, folha.position.y + 1.0, 1.0, folha.size.y - 2.0), luz)
	var borda := UiEstilo.TINTA
	borda.a = alfa
	draw_rect(folha, borda, false, UiEstilo.PAPEL_BORDA)

	var ca := clampf(_conteudo_alfa * alfa, 0.0, 1.0)
	_desenhar_conteudo(folha, ca)


func _desenhar_conteudo(folha: Rect2, ca: float) -> void:
	# Titulo pause-root = SISTEMA (nunca OPCOES).
	var nomes: Array[String] = ["SISTEMA", "IMAGEM", "SOM", "CARREGAR", "HUD", "PECAS DO HUD",
		"EXIBICAO DO HUD"]
	var titulo: String = nomes[int(pagina)]
	var y := folha.position.y + PAD + 10.0
	var cor_titulo := UiEstilo.TINTA_TITULO
	cor_titulo.a = ca
	draw_string(_fonte_titulo, Vector2(folha.position.x + PAD, y), titulo,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, _tam_title, cor_titulo)
	# Filete duplo sob o titulo: regua de 1 px, vao e fio fino.
	var cor_regua := UiEstilo.TINTA
	cor_regua.a = ca * 0.85
	draw_rect(Rect2(folha.position.x + PAD, y + 5.0, folha.size.x - PAD * 2.0, 1.0), cor_regua)
	var cor_fio := UiEstilo.TINTA_FRACA
	cor_fio.a = ca * 0.7
	draw_rect(Rect2(folha.position.x + PAD, y + 8.0, folha.size.x - PAD * 2.0, 0.6), cor_fio)

	var topos := _topos_linhas()
	var dy := folha.position.y - _folha().position.y
	var divs := _divisores()
	var com_icone := pagina == Pagina.RAIZ
	for i in _itens.size():
		var item := _itens[i]
		var ativo := i == _sel
		var vivo := bool(item.get("vivo", true))
		var destrutivo := bool(item.get("destrutivo", false))
		# Stagger RE: linha i entra apos i*35ms; CONTINUAR (0) no frame util.
		var linha_a := clampf((_stagger_t - float(i) * 0.035) / 0.08, 0.0, 1.0)
		var ca_l := ca * linha_a
		var cor := UiEstilo.TINTA
		if ativo or destrutivo:
			cor = UiEstilo.DESTAQUE
		elif not vivo:
			cor = Color(0.55, 0.50, 0.42)
		cor.a = ca_l

		var topo := topos[i] + dy + (1.0 - linha_a) * 3.0
		var faixa := Rect2(folha.position.x + PAD - 6.0, topo, folha.size.x - PAD * 2.0 + 12.0, LINHA)
		var base := topo + LINHA * 0.5 + 4.0
		if ativo:
			# Mancha de tinta do tamanho da linha e a barra ferrugem no meio
			# dela: o foco abraca o texto, e nao a linha de cima.
			var stain_a := (0.11 if destrutivo else 0.09) * _foco_alfa * ca_l
			draw_rect(faixa, Color(0.0, 0.0, 0.0, stain_a))
			var barra_cor := UiEstilo.DESTAQUE
			barra_cor.a = ca_l * _foco_alfa
			draw_rect(Rect2(folha.position.x + 5.0, topo + 3.0, 2.0, LINHA - 6.0), barra_cor)

		var rotulo := String(item["rotulo"])
		var x_rotulo := folha.position.x + PAD + (2.0 if ativo else 0.0)
		if com_icone:
			var cor_icone := cor if ativo or destrutivo else Color(UiEstilo.TINTA_FRACA, ca_l)
			_icone_item(rotulo, Vector2(folha.position.x + PAD + 4.0 + (2.0 if ativo else 0.0),
				topo + LINHA * 0.5), cor_icone)
			x_rotulo += 13.0
		_texto(rotulo, Vector2(x_rotulo, base), cor)

		# Chevron so em nav (abre pagina).
		if bool(item.get("nav", false)):
			var chev := ">"
			var cw := UiEstilo.largura_tam(_fonte, chev, _tam_body)
			var ccor := cor if ativo else UiEstilo.TINTA_FRACA
			ccor.a = ca_l
			_texto(chev, Vector2(folha.end.x - PAD - cw, base), ccor)

		var ler: Callable = item["ler"]
		var valor := String(ler.call())
		if not valor.is_empty():
			if OpcoesLista.eh_trilha(valor):
				var nivel := OpcoesLista.nivel_trilha(valor)
				var tw := UiEstilo.RE7_SLIDER_TRACK_W
				var th := UiEstilo.RE7_SLIDER_TRACK_H
				OpcoesLista.desenhar_trilha(self,
					Vector2(folha.end.x - PAD - tw, topo + (LINHA - th) * 0.5), nivel)
			else:
				var sobra := folha.size.x - PAD * 2.0 \
					- UiEstilo.largura_tam(_fonte, rotulo, _tam_body) - 8.0
				valor = UiEstilo.encurtar_tam(_fonte, valor, maxf(sobra, 12.0), _tam_body)
				var w := UiEstilo.largura_tam(_fonte, valor, _tam_body)
				var vc := cor if ativo else UiEstilo.TINTA_FRACA
				vc.a = ca_l
				_texto(valor, Vector2(folha.end.x - PAD - w, base), vc)

		if i in divs and i < _itens.size() - 1:
			# O divisor fica no meio do vao entre esta faixa e a proxima.
			var meio := topos[i] + dy + LINHA + (PASSO - LINHA + _gap_divisor(i)) * 0.5
			var hair := UiEstilo.TINTA_FRACA
			hair.a = ca * 0.6
			draw_rect(Rect2(folha.position.x + PAD, meio, folha.size.x - PAD * 2.0, 0.6), hair)

	# Teclas desenhadas como teclas, no pe da folha.
	var dicas: Array = [["W S", "MOVER"], ["E", "ESCOLHER"], ["ESC", "FECHAR"]]
	if pagina in [Pagina.VIDEO, Pagina.AUDIO, Pagina.HUD, Pagina.HUD_PECAS, Pagina.HUD_EXIBICAO]:
		dicas = [["A D", "AJUSTAR"], ["Q", "VOLTAR"]]
	var x := folha.position.x + PAD
	var cy := folha.end.y - 10.0
	for d: Array in dicas:
		var tecla := String(d[0])
		var wt := maxf(9.0, UiEstilo.largura_tam(_fonte_titulo, tecla, _tam_micro - 2) + 5.0)
		var caixa := Rect2(x, cy - 4.5, wt, 9.0)
		var cor_t := UiEstilo.TINTA
		cor_t.a = ca * 0.75
		draw_rect(caixa, Color(0.0, 0.0, 0.0, 0.06 * ca))
		draw_rect(caixa, cor_t, false, 0.6)
		draw_string(_fonte_titulo, Vector2(x, cy + 2.4), tecla, HORIZONTAL_ALIGNMENT_CENTER, wt,
			_tam_micro - 2, cor_t)
		x += wt + 3.0
		var rot := String(d[1])
		var dc := UiEstilo.TINTA_FRACA
		dc.a = ca
		draw_string(_fonte, Vector2(x, cy + 2.6), rot, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			_tam_micro - 1, dc)
		x += UiEstilo.largura_tam(_fonte, rot, _tam_micro - 1) + 8.0


## Glifo de 7 px por item da raiz. A mao acha SAIR e CONTINUAR pela forma.
func _icone_item(rotulo: String, c: Vector2, cor: Color) -> void:
	var l := 0.8
	match rotulo:
		"CONTINUAR":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-2.2, -3.2),
				c + Vector2(3.2, 0.0), c + Vector2(-2.2, 3.2)]), cor)
		"CARREGAR":
			draw_polyline(PackedVector2Array([c + Vector2(-3.5, -2.6), c + Vector2(-1.0, -2.6),
				c + Vector2(0.0, -1.6), c + Vector2(3.5, -1.6), c + Vector2(3.5, 3.0),
				c + Vector2(-3.5, 3.0), c + Vector2(-3.5, -2.6)]), cor, l, true)
		"IMAGEM":
			draw_rect(Rect2(c + Vector2(-3.6, -2.8), Vector2(7.2, 4.8)), cor, false, l)
			draw_line(c + Vector2(-1.4, 3.2), c + Vector2(1.4, 3.2), cor, l, true)
		"SOM":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-3.4, -1.2), c + Vector2(-1.6, -1.2),
				c + Vector2(0.6, -3.2), c + Vector2(0.6, 3.2), c + Vector2(-1.6, 1.2),
				c + Vector2(-3.4, 1.2)]), cor)
			draw_arc(c + Vector2(0.8, 0.0), 2.6, -0.9, 0.9, 8, cor, l, true)
		"HUD":
			# Quatro cantos de visor: e o que o HUD e, o enquadramento da tela.
			for q: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var canto := c + Vector2(3.4 * q.x, 2.8 * q.y)
				draw_polyline(PackedVector2Array([canto - Vector2(0.0, 1.8 * q.y), canto,
					canto - Vector2(1.8 * q.x, 0.0)]), cor, l, true)
		"SAIR PARA O TITULO":
			draw_polyline(PackedVector2Array([c + Vector2(0.4, -3.2), c + Vector2(-3.0, -3.2),
				c + Vector2(-3.0, 3.2), c + Vector2(0.4, 3.2)]), cor, l, true)
			draw_line(c + Vector2(-1.2, 0.0), c + Vector2(3.6, 0.0), cor, l, true)
			draw_polyline(PackedVector2Array([c + Vector2(1.8, -1.8), c + Vector2(3.6, 0.0),
				c + Vector2(1.8, 1.8)]), cor, l, true)


func _desenhar_pauzinhos() -> void:
	if _aba == null:
		return
	var placa := PLACA_ABA
	# Com a folha aberta o botao recua: ele fica acima do escurecimento (camada
	# 160) e, claro como o papel, disputava o olho com o proprio menu.
	var k := 0.4 if aberto else 1.0
	# Sombra leve no canto.
	_aba.draw_rect(Rect2(placa.position + Vector2(1.0, 1.0), placa.size),
		Color(0.05, 0.04, 0.03, 0.35 * k))
	var fill := UiEstilo.PAPEL_ABERTO if aberto else UiEstilo.PAPEL
	fill.a *= k
	if _aba_pressed:
		fill = Color(fill.r * 0.92, fill.g * 0.92, fill.b * 0.92, fill.a)
	_aba.draw_rect(placa, fill)
	var borda := UiEstilo.DESTAQUE if ((_aba_hover or _aba_pressed) and not aberto) else UiEstilo.TINTA
	borda.a *= k
	_aba.draw_rect(placa, borda, false, 1.0)
	var cor := UiEstilo.DESTAQUE if aberto else UiEstilo.TINTA
	cor.a *= k
	var bx := placa.position.x + (placa.size.x - BARRA_L) * 0.5
	var total_h := BARRA_A * 3.0 + BARRA_GAP * 2.0
	var by0 := placa.position.y + (placa.size.y - total_h) * 0.5
	for i in 3:
		_aba.draw_rect(Rect2(bx, by0 + float(i) * (BARRA_A + BARRA_GAP), BARRA_L, BARRA_A), cor)


func _texto(s: String, onde: Vector2, cor: Color, tamanho: int = -1) -> void:
	var tam := _tam_body if tamanho < 0 else tamanho
	draw_string(_fonte, onde, s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, tam, cor)



# --- Onda 4 Save Cards (RE7) -------------------------------------------------

func _ensure_save_panel() -> void:
	if _save_panel != null:
		return
	# Prefer scene se existir; fallback .new().
	var inst: Node = null
	var packed: PackedScene = load("res://src/ui/re7/save_panel.tscn") as PackedScene
	if packed != null:
		inst = packed.instantiate()
	if inst is SaveCardsPanelRe7:
		_save_panel = inst as SaveCardsPanelRe7
	else:
		_save_panel = SaveCardsPanelRe7.new()
	_save_panel.name = "SaveCardsPanelRe7"
	_save_panel.visible = false
	_save_panel.z_index = 40
	_save_panel.custom_minimum_size = Vector2(220, 200)
	_save_panel.size = Vector2(220, 200)
	# Centrado na TELA 480x270 (painel ~220x200).
	_save_panel.position = Vector2(130.0, 31.0)
	add_child(_save_panel)
	_save_panel.pediu_carregar.connect(_on_save_panel_carregar)
	_save_panel.pediu_voltar.connect(_on_save_panel_voltar)


func _sync_save_panel(qual: Pagina) -> void:
	_ensure_save_panel()
	var mostrar := aberto and qual == Pagina.CARREGAR
	_save_panel.visible = mostrar
	if mostrar:
		# Pagina CARREGAR = kind save; so scrim + cards (sem paper).
		_save_panel.refresh_from_savegame()
		_save_panel.call_deferred("foco_padrao")
	_sincronizar_painel_re7()
	queue_redraw()


func _on_save_panel_carregar(espaco: int) -> void:
	if not SaveGame.existe(espaco):
		# Soft deny — card filled já tocou confirm no accept.
		AudioDirector.tocar_nav(-20.0)
		return
	fechar(false)
	carregou.emit(espaco)


func _on_save_panel_voltar() -> void:
	# Nav já no SaveCardsPanelRe7._on_voltar_pressed.
	# Restore focus RAIZ CONTINUAR (FILO local — prancha ainda no UIManager).
	_ir_para(Pagina.RAIZ)
	call_deferred("foco_padrao")

