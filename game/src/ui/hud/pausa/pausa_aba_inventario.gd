## INVENTARIO: os oito espacos da bolsa, o item escolhido e o que fazer com ele.
##
##   W A S D / setas   escolhe o espaco
##   ENTER  (A)        usa (curativo cura; o resto diz que nao da)
##   X      (Y)        examina: documento abre o documento; o resto gira em 3D
##
## A inspecao 3D e a mesma da prancha (`ItemInspectViewport`, Onda 3), montada
## no painel da direita. Ela trata a propria entrada enquanto aberta; ESC fecha.
class_name PausaAbaInventario
extends PausaAba

const CELULA := 34.0
const VAO := 5.0
const COLUNAS := 4
const INSPECAO := "res://src/ui/re7/inspect_viewport.tscn"

var _sel := 0
var _inspecao: Control
var _examinando := false
var _aviso := ""
var _t_aviso := 0.0


func ao_entrar() -> void:
	_fechar_inspecao()
	queue_redraw()


func _process(delta: float) -> void:
	if _t_aviso > 0.0:
		_t_aviso -= delta
		queue_redraw()


func ocupada() -> bool:
	return _examinando


func voltar() -> bool:
	if _examinando:
		_fechar_inspecao()
		queue_redraw()
		return true
	return false


func dicas() -> Array:
	if _examinando:
		return [["MOUSE", "GIRAR"]]
	var ctl := Settings.get(&"controle") as Controle
	var pad := ctl != null and ctl.dispositivo == Controle.Dispositivo.CONTROLE
	# No controle o X da tecla e o Y do botao: a dica ja vem com o botao marcado.
	return [["WASD", "ESCOLHER"], ["ENTER", "USAR"], [HudLayout.glifo("Y", true) if pad else "X",
		"EXAMINAR"]]


func _item(i: int) -> Item:
	if i < 0 or i >= Inventario.espacos.size():
		return null
	var e: Dictionary = Inventario.espacos[i]
	return e.get("item") as Item if not e.is_empty() else null


func tratar(evento: InputEvent) -> bool:
	if _examinando:
		return false
	var d := Vector2i.ZERO
	if evento.is_action_pressed(&"mover_esq") or evento.is_action_pressed(&"ui_left"):
		d.x = -1
	elif evento.is_action_pressed(&"mover_dir") or evento.is_action_pressed(&"ui_right"):
		d.x = 1
	elif evento.is_action_pressed(&"mover_frente") or evento.is_action_pressed(&"ui_up"):
		d.y = -1
	elif evento.is_action_pressed(&"mover_tras") or evento.is_action_pressed(&"ui_down"):
		d.y = 1
	if d != Vector2i.ZERO:
		var linhas := ceili(float(Inventario.ESPACOS) / COLUNAS)
		var col := posmod(_sel % COLUNAS + d.x, COLUNAS)
		var lin := posmod(floori(float(_sel) / COLUNAS) + d.y, linhas)
		_sel = clampi(lin * COLUNAS + col, 0, Inventario.ESPACOS - 1)
		AudioDirector.tocar_nav(-20.0)
		queue_redraw()
		return true
	if evento.is_action_pressed(&"ui_accept"):
		_usar()
		return true
	var tecla := evento as InputEventKey
	var examinar := tecla != null and tecla.pressed and tecla.physical_keycode == KEY_X
	var botao := evento as InputEventJoypadButton
	examinar = examinar or (botao != null and botao.pressed and botao.button_index == JOY_BUTTON_Y)
	if examinar:
		_examinar()
		return true
	var mb := evento as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		for i in Inventario.ESPACOS:
			if _celula(i).has_point(mb.position):
				if i == _sel and mb.double_click:
					_usar()
				_sel = i
				queue_redraw()
				return true
	return false


func _gui_input(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and tratar(evento):
		accept_event()


func _usar() -> void:
	var item := _item(_sel)
	if item == null:
		return
	if Inventario.usar(_sel):
		AudioDirector.tocar_confirm(-14.0)
		_avisar("%s usado." % item.nome)
	else:
		AudioDirector.tocar_nav(-12.0)
		if item.cura > 0:
			_avisar("A vida ja esta cheia.")
		else:
			_avisar("Nao da para usar isto agora.")
	queue_redraw()


func _avisar(texto: String) -> void:
	_aviso = texto
	_t_aviso = 2.2


func _examinar() -> void:
	var item := _item(_sel)
	if item == null:
		return
	# O documento se le, e nao se gira: abre a tela dele (como a prancha fazia).
	if item.id == &"identidade" and not RegistroCivil.jogador.is_empty():
		Documento.abrir(RegistroCivil.jogador)
		return
	if _inspecao == null and ResourceLoader.exists(INSPECAO):
		var cena := load(INSPECAO) as PackedScene
		if cena != null:
			_inspecao = cena.instantiate() as Control
			add_child(_inspecao)
			if _inspecao.has_signal(&"closed"):
				_inspecao.connect(&"closed", func() -> void:
					_examinando = false
					queue_redraw())
	if _inspecao == null:
		return
	var r := _detalhe()
	_inspecao.position = r.position + Vector2(8.0, 8.0)
	_inspecao.size = Vector2(r.size.x - 16.0, r.size.y - 60.0)
	_inspecao.visible = true
	_inspecao.z_index = 5
	_inspecao.mouse_filter = Control.MOUSE_FILTER_STOP
	if _inspecao.has_method(&"set_item"):
		_inspecao.call(&"set_item", item.id)
	if _inspecao.has_method(&"enter"):
		_inspecao.call(&"enter")
	_examinando = true
	AudioDirector.tocar_confirm(-16.0)
	queue_redraw()


func _fechar_inspecao() -> void:
	_examinando = false
	if _inspecao != null:
		if _inspecao.has_method(&"exit"):
			_inspecao.call(&"exit")
		_inspecao.visible = false


# --- desenho ------------------------------------------------------------------

func _celula(i: int) -> Rect2:
	var col := i % COLUNAS
	var lin := floori(float(i) / COLUNAS)
	var o := area.position + Vector2(0.0, 18.0)
	return Rect2(o + Vector2(col * (CELULA + VAO), lin * (CELULA + VAO)), Vector2(CELULA, CELULA))


func _detalhe() -> Rect2:
	var x := area.position.x + COLUNAS * (CELULA + VAO) + 14.0
	return Rect2(x, area.position.y, area.end.x - x, area.size.y)


func _draw() -> void:
	var usados := 0
	for e: Dictionary in Inventario.espacos:
		if not e.is_empty():
			usados += 1
	var largura_grade := COLUNAS * (CELULA + VAO) - VAO
	secao(area.position, "BOLSA  ·  %d/%d" % [usados, Inventario.ESPACOS], largura_grade)
	var fs := HudTema.semi()
	for i in Inventario.ESPACOS:
		var r := _celula(i)
		var item := _item(i)
		var focada := i == _sel
		draw_colored_polygon(HudTema.cantos(r, 2.5), Color(1.0, 1.0, 1.0, 0.09 if focada else 0.045))
		if item != null and item.icone != null:
			draw_texture_rect(item.icone, r.grow(-5.0), false)
			var qtd := int((Inventario.espacos[i] as Dictionary).get("qtd", 1))
			if qtd > 1:
				var t := "x%d" % qtd
				var w := HudTema.largura(fs, t, HudTema.T_MICRO)
				HudTema.texto(self, fs, r.end - Vector2(w + 3.0, 10.0), t, HudTema.T_MICRO,
					HudTema.TEXTO)
		var borda := HudTema.cantos(r, 2.5)
		borda.append(borda[0])
		draw_polyline(borda, HudTema.acento() if focada else Color(1.0, 1.0, 1.0, 0.12),
			1.0 if focada else 0.5, true)
	# Vida embaixo da grade: e o que decide usar ou nao o curativo.
	var yv := _celula(Inventario.ESPACOS - 1).end.y + 12.0
	var fv := HudTema.rotulo()
	HudTema.texto(self, fv, Vector2(area.position.x, yv), "VIDA", HudTema.T_ROTULO, HudTema.fraco())
	var vida := float(Inventario.vida) / float(maxi(1, Inventario.vida_maxima))
	HudTema.barra(self, Rect2(area.position.x + 30.0, yv + 3.0, largura_grade - 30.0, 3.0), vida,
		HudTema.PERIGO if vida <= 0.4 else HudTema.TEXTO)
	HudTema.texto(self, fs, Vector2(area.position.x + 30.0, yv + 9.0),
		String(Inventario.estado()), HudTema.T_MICRO, HudTema.fraco())
	_desenhar_detalhe()


func _desenhar_detalhe() -> void:
	var r := _detalhe()
	HudTema.painel(self, r, 0.9, 3.0)
	var item := _item(_sel)
	var x := r.position.x + 10.0
	var y := r.position.y + 8.0
	var w := r.size.x - 20.0
	if item == null:
		HudTema.texto(self, HudTema.regular(), Vector2(x, y), "Espaco vazio.", HudTema.T_CORPO,
			HudTema.fraco())
		return
	if not _examinando:
		# Icone grande: o mesmo desenho da celula, a primeira coisa que o olho acha.
		if item.icone != null:
			var lado := 64.0
			draw_texture_rect(item.icone, Rect2(Vector2(r.get_center().x - lado * 0.5, y), Vector2(lado, lado)),
				false)
		y += 70.0
	else:
		y = r.end.y - 52.0
	var ft := HudTema.fonte(700, 1)
	HudTema.texto(self, ft, Vector2(x, y), item.nome.to_upper(), HudTema.T_TITULO, HudTema.TEXTO)
	y += HudTema.altura(ft, HudTema.T_TITULO)
	HudTema.texto(self, HudTema.rotulo(), Vector2(x, y), item.rotulo_tipo(), HudTema.T_MICRO,
		HudTema.acento())
	y += HudTema.altura(HudTema.rotulo(), HudTema.T_MICRO) + 4.0
	if not _examinando:
		var f := HudTema.regular()
		var h := HudTema.altura(f, HudTema.T_CORPO)
		for l: String in HudTema.quebrar(f, item.descricao, HudTema.T_CORPO, w):
			if y > r.end.y - h - 12.0:
				break
			HudTema.texto(self, f, Vector2(x, y), l, HudTema.T_CORPO, HudTema.fraco())
			y += h
	if _t_aviso > 0.0:
		var fs := HudTema.semi()
		HudTema.texto(self, fs, Vector2(x, r.end.y - 14.0), _aviso, HudTema.T_ROTULO,
			HudTema.alfa(HudTema.ALERTA, clampf(_t_aviso, 0.0, 1.0)))
