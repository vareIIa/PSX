## Autoload UIManager — pilha de menus + overlay RE7 (EPICO_UI_RE7 Onda 1 / 1b).
##
## Contratos:
## - push_menu / pop_menu gerenciam a pilha e o overlay.
## - Pausa da arvore: por padrao NAO pausa (a PranchaInventario ja pausa).
##   Passe pausar=true so quando o chamador nao pausa sozinho.
## - Feature flag RE7_OVERLAY (default ON). Com OFF, a pilha ainda funciona
##   mas o ColorRect do shader fica desligado — caminho legado intacto.
## - Overlay fica em CAMADA_RE7_OVERLAY (acima do mundo, abaixo da prancha).
## - T_RE7_OPEN: tween intensity/scrim em paralelo; input NAO espera o tween.
extends Node

const SHADER_OVERLAY := "res://shaders/ui_menu_overlay.gdshader"

## Liga o filtro RE7 ao abrir menus. Desligar = legado sem overlay.
const RE7_OVERLAY := true

## Onda 3 SUPPORT — runners CLI (--ver-inspect-re7 / --ver-vitals-re7).
const CENA_VER_INSPECT_RE7 := "res://src/ui/re7/ver_inspect_re7.tscn"
const CENA_VER_VITALS_RE7 := "res://src/ui/re7/ver_vitals_re7.tscn"

## Pico de scrim no open (SPEC_VISUAL_RE7 / SPEC_MOTION_RE7 §3).
const SCRIM_PICO := 0.62

var _stack: Array[Node] = []
## FILO: Control (ou null) que tinha focus antes de cada push. Mesmo comprimento que _stack.
## Focus e deferred no 1o frame util — NAO gated pelo tween de open (SPEC_A11Y_RE7 §3).
var _focus_prev: Array = []  # Control or null per push
var _pause_owned: bool = false
var _anti_null_pendente: bool = false

var _camada: CanvasLayer
var _bbc: BackBufferCopy
var _rect: ColorRect
var _mat: ShaderMaterial
var _overlay_ligado: bool = false
var _tween_overlay: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar_overlay()
	_aplicar_overlay(false, true)


func _montar_overlay() -> void:
	_camada = CanvasLayer.new()
	_camada.name = "Re7OverlayLayer"
	_camada.layer = UiEstilo.CAMADA_RE7_OVERLAY
	_camada.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_camada)

	# Copia o frame ja desenhado antes do ColorRect ler SCREEN_TEXTURE.
	_bbc = BackBufferCopy.new()
	_bbc.name = "Re7BackBuffer"
	_bbc.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_camada.add_child(_bbc)

	_rect = ColorRect.new()
	_rect.name = "Re7OverlayRect"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.position = Vector2.ZERO
	_rect.size = UiEstilo.TELA

	var sh := load(SHADER_OVERLAY) as Shader
	if sh != null:
		_mat = ShaderMaterial.new()
		_mat.shader = sh
		_aplicar_params_spec()
		_rect.material = _mat
	else:
		push_warning("[UIManager] shader overlay ausente: %s" % SHADER_OVERLAY)
	_camada.add_child(_rect)


## Tokens SPEC_VISUAL_RE7 s4.2 — doses no meio da faixa aprovada.
func _aplicar_params_spec() -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter(&"blur_px", 1.15)
	_mat.set_shader_parameter(&"saturation", 0.6) # 1.0 - 0.4
	_mat.set_shader_parameter(&"ca_px", 0.6)
	_mat.set_shader_parameter(&"grain_amt", 0.045)
	_mat.set_shader_parameter(&"vignette_amt", 0.30)
	_mat.set_shader_parameter(&"scrim_amt", 0.0)
	_mat.set_shader_parameter(&"scrim_color", UiEstilo.RE7_SCRIM)
	_mat.set_shader_parameter(&"dirt_amt", 0.20)
	_mat.set_shader_parameter(&"warp_amt", 0.0015)
	_mat.set_shader_parameter(&"warp_hz", 0.06)
	_mat.set_shader_parameter(&"intensity", 0.0)
	_mat.set_shader_parameter(&"internal_res", UiEstilo.TELA)


func push_menu(node: Node, pausar: bool = false, kind: StringName = &"menu") -> void:
	if node == null:
		return
	# Re-push: remove entrada antiga (pilha + focus prev no mesmo indice).
	if _stack.has(node):
		var idx_old := _stack.find(node)
		_stack.remove_at(idx_old)
		if idx_old < _focus_prev.size():
			_focus_prev.remove_at(idx_old)
	var era_vazio := _stack.is_empty()
	# Captura quem tinha focus ANTES deste push (pode ser null = gameplay).
	var prev = get_viewport().gui_get_focus_owner()
	_stack.append(node)
	_focus_prev.append(prev)
	if era_vazio:
		# Duck/LP mundo (drone so para sistema/opcoes/save — ver AudioDirector).
		AudioDirector.on_menu_push(kind)
	if RE7_OVERLAY and era_vazio:
		_aplicar_overlay(true)
	elif RE7_OVERLAY and not _overlay_ligado:
		_aplicar_overlay(true)
	if pausar and not _pause_owned and _stack.size() == 1:
		# Sessao.pausar: sozinho, a arvore para como sempre; em rede, trava so o
		# jogador local (plano multiplayer 06 secao 6).
		Sessao.pausar(true)
		_pause_owned = true
	# Focus no 1o frame util (call_deferred) — NAO espera tween de open.
	call_deferred("_focar_menu", node)


func pop_menu() -> void:
	if _stack.is_empty():
		return
	_stack.pop_back()
	var prev = _focus_prev.pop_back() if not _focus_prev.is_empty() else null
	if _stack.is_empty():
		AudioDirector.on_menu_pop()
		_aplicar_overlay(false)
		if _pause_owned:
			Sessao.pausar(false)
			_pause_owned = false
		get_viewport().gui_release_focus()
	else:
		_restaurar_foco(prev)


func remove_menu(node: Node) -> void:
	if node == null or not _stack.has(node):
		return
	var idx := _stack.find(node)
	_stack.remove_at(idx)
	var prev = null
	if idx < _focus_prev.size():
		prev = _focus_prev[idx]
		_focus_prev.remove_at(idx)
	if _stack.is_empty():
		AudioDirector.on_menu_pop()
		_aplicar_overlay(false)
		if _pause_owned:
			Sessao.pausar(false)
			_pause_owned = false
		get_viewport().gui_release_focus()
	else:
		if RE7_OVERLAY:
			# Ainda ha menu: overlay permanece ligado (sem re-tween se ja aberto).
			if not _overlay_ligado:
				_aplicar_overlay(true)
		_restaurar_foco(prev)


func topo() -> Node:
	if _stack.is_empty():
		return null
	return _stack[_stack.size() - 1]


func profundidade() -> int:
	return _stack.size()


## SPEC_A11Y_RE7 §3: grab_focus no default do menu (foco_padrao ou 1o focusavel).
## Chamado deferred — input local do menu (lock ≤250ms) fica no consumidor; aqui nao ha lock global.
func _focar_menu(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.has_method("foco_padrao"):
		node.call("foco_padrao")
		return
	var c := _primeiro_focusavel(node)
	if c != null:
		c.grab_focus()


func _primeiro_focusavel(n: Node) -> Control:
	if n is Control:
		var ctl := n as Control
		if ctl.focus_mode != Control.FOCUS_NONE and ctl.is_visible_in_tree():
			return ctl
	for ch in n.get_children():
		var f := _primeiro_focusavel(ch)
		if f != null:
			return f
	return null


func _restaurar_foco(prev: Variant) -> void:
	if prev is Control and is_instance_valid(prev):
		(prev as Control).grab_focus()
	else:
		_focar_menu(topo())


## Guarda SPEC §2.3/§3.3: com menu no topo, focus owner nao fica null.
func _process(_delta: float) -> void:
	if _stack.is_empty():
		return
	if get_viewport().gui_get_focus_owner() != null:
		return
	if _anti_null_pendente:
		return
	_anti_null_pendente = true
	call_deferred("_anti_null_foco")


func _anti_null_foco() -> void:
	_anti_null_pendente = false
	if _stack.is_empty():
		return
	if get_viewport().gui_get_focus_owner() != null:
		return
	_focar_menu(topo())


func overlay_ativo() -> bool:
	return _overlay_ligado


func set_overlay_enabled(ligado: bool) -> void:
	if ligado and RE7_OVERLAY and not _stack.is_empty():
		_aplicar_overlay(true)
	elif not ligado:
		_aplicar_overlay(false)


func set_overlay_active(ligado: bool) -> void:
	set_overlay_enabled(ligado)


## imediato=true: snap (ready / feature flag off). Caso contrario: T_RE7_OPEN/CLOSE.
## Input NUNCA espera o tween — nao ha lock aqui (SPEC_MOTION_RE7 teto 250 ms).
func _aplicar_overlay(ligado: bool, imediato: bool = false) -> void:
	var quer := ligado and RE7_OVERLAY
	if quer:
		_overlay_ligado = true
		if _camada != null:
			_camada.visible = true
		if _rect != null:
			_rect.visible = true
		if imediato or not RE7_OVERLAY:
			_snap_overlay(1.0, SCRIM_PICO)
		else:
			_tween_open()
	else:
		_overlay_ligado = false
		if imediato or not RE7_OVERLAY or _mat == null:
			_snap_overlay(0.0, 0.0)
			if _camada != null:
				_camada.visible = false
			if _rect != null:
				_rect.visible = false
		else:
			_tween_close()


func _matar_overlay_tween() -> void:
	if _tween_overlay != null and _tween_overlay.is_valid():
		_tween_overlay.kill()
	_tween_overlay = null


func _snap_overlay(intensity: float, scrim: float) -> void:
	_matar_overlay_tween()
	if _mat != null:
		_mat.set_shader_parameter(&"intensity", intensity)
		_mat.set_shader_parameter(&"scrim_amt", scrim)
	if _rect != null:
		_rect.modulate = Color(1.0, 1.0, 1.0, intensity)


func _ler_intensity() -> float:
	if _mat == null:
		return 0.0
	var v: Variant = _mat.get_shader_parameter(&"intensity")
	return float(v) if v != null else 0.0


func _ler_scrim() -> float:
	if _mat == null:
		return 0.0
	var v: Variant = _mat.get_shader_parameter(&"scrim_amt")
	return float(v) if v != null else 0.0


func _tween_open() -> void:
	_matar_overlay_tween()
	# Parte do zero (ou do estado atual se reabrir no meio do close).
	var i0 := _ler_intensity()
	var s0 := _ler_scrim()
	if i0 > 0.95 and s0 > SCRIM_PICO * 0.9:
		_snap_overlay(1.0, SCRIM_PICO)
		return
	if _mat != null:
		_mat.set_shader_parameter(&"intensity", i0)
		_mat.set_shader_parameter(&"scrim_amt", s0)
	if _rect != null:
		_rect.modulate = Color(1.0, 1.0, 1.0, i0)
	_tween_overlay = create_tween()
	_tween_overlay.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween_overlay.set_parallel(true)
	# Scrim/DoF: TRANS_QUAD / EASE_OUT (SPEC_MOTION_RE7 §2).
	_tween_overlay.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_tween_overlay.tween_method(_set_intensity, i0, 1.0, UiEstilo.T_RE7_OPEN)
	_tween_overlay.tween_method(_set_scrim, s0, SCRIM_PICO, UiEstilo.T_RE7_OPEN)


func _tween_close() -> void:
	_matar_overlay_tween()
	var i0 := _ler_intensity()
	var s0 := _ler_scrim()
	if i0 <= 0.01:
		_snap_overlay(0.0, 0.0)
		if _camada != null:
			_camada.visible = false
		if _rect != null:
			_rect.visible = false
		return
	_tween_overlay = create_tween()
	_tween_overlay.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween_overlay.set_parallel(true)
	_tween_overlay.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_tween_overlay.tween_method(_set_intensity, i0, 0.0, UiEstilo.T_RE7_CLOSE)
	_tween_overlay.tween_method(_set_scrim, s0, 0.0, UiEstilo.T_RE7_CLOSE)
	_tween_overlay.finished.connect(func() -> void:
		if _overlay_ligado:
			return
		if _camada != null:
			_camada.visible = false
		if _rect != null:
			_rect.visible = false)


func _set_intensity(v: float) -> void:
	if _mat != null:
		_mat.set_shader_parameter(&"intensity", v)
	if _rect != null:
		_rect.modulate = Color(1.0, 1.0, 1.0, v)


func _set_scrim(v: float) -> void:
	if _mat != null:
		_mat.set_shader_parameter(&"scrim_amt", v)



func abrir_ver_inspect_re7() -> void:
	_abrir_ver_re7(CENA_VER_INSPECT_RE7, &"VerInspectRE7")


func abrir_ver_vitals_re7() -> void:
	_abrir_ver_re7(CENA_VER_VITALS_RE7, &"VerVitalsRE7")


func _abrir_ver_re7(path: String, nome: StringName) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("[UIManager] cena ver RE7 ausente: %s" % path)
		return
	# Remove runner anterior se ainda vivo (reentrada CLI).
	var root := get_tree().root
	var velho := root.get_node_or_null(NodePath(String(nome)))
	if velho != null:
		velho.queue_free()
	var node := packed.instantiate()
	node.name = String(nome)
	# process ALWAYS: captura funciona mesmo com árvore pausada pela prancha.
	if node is Node:
		(node as Node).process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(node)
	# Sem push_menu: runners fazem screenshot e get_tree().quit sozinhos.
