## MAPA: a cidade inteira na paleta do radar, com grade, pinos e rota.
##
## O que se faz aqui
## -----------------
##   W A S D / analogico / arrastar   anda pelo mapa
##   Z X / roda do mouse              zoom
##   ENTER / clique                   marca destino na mira (traca a rota no GPS);
##                                    em cima do destino atual, desmarca
##   H                                volta para onde o jogador esta
##
## Marcar destino usa o mesmo caminho do iWeed (`IWeed.marcar_no_gps`): o GPS nao
## tem setter publico, e o contrato dele e `destino` + `rota` + `destino_mudou`.
## Quem desenha a rota no radar, na bussola e no curva a curva le dali.
class_name PausaAbaMapa
extends PausaAba

const ESCALAS: Array[float] = [1.6, 2.6, 4.0, 6.5, 10.0]
## Metros por segundo de pan, em pixel de tela: anda a mesma velocidade na tela
## em qualquer zoom.
const PAN_PX := 150.0
const LEGENDA := 118.0

var _mapa: Mapa
## Mira, rotulo e escala: por cima do mapa (filho desenha depois do pai).
var _sobre: Control
var _centro := Vector3.ZERO
var _i_escala := 1
var _arrastando := false


func _ready() -> void:
	super._ready()
	_mapa = Mapa.new()
	_mapa.estilo = Mapa.Estilo.PAGINA
	_mapa.escuro = true
	_mapa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mapa)
	_sobre = Control.new()
	_sobre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sobre.position = Vector2.ZERO
	_sobre.size = HudTema.TELA
	_sobre.draw.connect(_desenhar_sobre)
	add_child(_sobre)
	set_process(false)


func _caixa() -> Rect2:
	return Rect2(area.position, Vector2(area.size.x - LEGENDA - 10.0, area.size.y))


func ao_entrar() -> void:
	var r := _caixa()
	_mapa.position = r.position
	_mapa.size = r.size
	_centrar_no_jogador()
	set_process(true)
	queue_redraw()


func _jogador() -> Node3D:
	return get_tree().get_first_node_in_group(&"player") as Node3D


func _centrar_no_jogador() -> void:
	var j := _jogador()
	if j != null:
		_centro = j.global_position
	_aplicar()


func _aplicar() -> void:
	var j := _jogador()
	_mapa.metros_por_pixel = ESCALAS[_i_escala]
	_mapa.centro = _centro
	if j != null:
		_mapa.pos_jogador = j.global_position
		_mapa.rumo = j.rotation.y
	_mapa.pinos = Gps.pinos_do_destino()
	_mapa.rota = Gps.rota_do_destino()
	_mapa.forcar_redesenho()
	queue_redraw()
	_sobre.queue_redraw()


func _process(delta: float) -> void:
	if not visible or not bool(hub.get(&"aberta")):
		set_process(false)
		return
	var v := Input.get_vector(&"mover_esq", &"mover_dir", &"mover_frente", &"mover_tras")
	if v.length() > 0.05:
		var passo := v * PAN_PX * delta * ESCALAS[_i_escala]
		_centro += Vector3(passo.x, 0.0, passo.y)
		_aplicar()


func dicas() -> Array:
	return [["WASD", "MOVER"], ["Z X", "ZOOM"], ["ENTER", "MARCAR"], ["H", "VOCE"]]


func tratar(evento: InputEvent) -> bool:
	var tecla := evento as InputEventKey
	if tecla != null and tecla.pressed:
		match tecla.physical_keycode:
			KEY_Z:
				_zoom(-1)
				return true
			KEY_X:
				_zoom(1)
				return true
			KEY_H:
				_centrar_no_jogador()
				return true
	# Controle: gatilhos dao zoom (RT aproxima, como a roda para cima), Y volta
	# ao jogador. So evento de joypad: no teclado estas acoes sao CTRL, F e Q.
	if evento is InputEventJoypadButton or evento is InputEventJoypadMotion:
		if evento.is_action_pressed(&"veiculo"):
			_zoom(-1)
			return true
		if evento.is_action_pressed(&"agachar"):
			_zoom(1)
			return true
		if evento.is_action_pressed(&"examinar"):
			_centrar_no_jogador()
			return true
	if evento.is_action_pressed(&"ui_accept") or evento.is_action_pressed(&"interagir"):
		_marcar(_centro)
		return true
	var mb := evento as InputEventMouseButton
	if mb != null and _caixa().has_point(mb.position):
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom(-1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom(1)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and mb.double_click:
				_marcar(_mundo_de(mb.position))
			_arrastando = mb.pressed
		return true
	var mm := evento as InputEventMouseMotion
	if mm != null and _arrastando:
		var d := -mm.relative * ESCALAS[_i_escala]
		_centro += Vector3(d.x, 0.0, d.y)
		_aplicar()
		return true
	return false


func _gui_input(evento: InputEvent) -> void:
	if tratar(evento):
		accept_event()


func _zoom(passo: int) -> void:
	_i_escala = clampi(_i_escala + passo, 0, ESCALAS.size() - 1)
	AudioDirector.tocar_nav(-20.0)
	_aplicar()


func _mundo_de(tela: Vector2) -> Vector3:
	var r := _caixa()
	var off := (tela - r.get_center()) * ESCALAS[_i_escala]
	return _centro + Vector3(off.x, 0.0, off.y)


## Marca (ou desmarca) o destino do GPS em `mundo`.
func _marcar(mundo: Vector3) -> void:
	var j := _jogador()
	if not Gps.destino.is_empty():
		var d: Vector3 = Gps.destino["mundo"]
		# Mira em cima do destino atual: desmarca. Seis pixels de tolerancia.
		if Vector2(d.x - mundo.x, d.z - mundo.z).length() < 6.0 * ESCALAS[_i_escala]:
			Gps.destino = {}
			Gps.rota = PackedVector2Array()
			Gps.destino_mudou.emit()
			AudioDirector.tocar_nav(-16.0)
			_aplicar()
			return
	var cx := floori(mundo.x / MalhaUrbana.TAM)
	var cz := floori(mundo.z / MalhaUrbana.TAM)
	var rua := NomesDeRua.rua_perto(mundo)
	Gps.destino = {
		"categoria": &"marca",
		"nome": "MARCA NO MAPA",
		"mundo": mundo,
		"chunk": Vector2i(cx, cz),
		"icone": &"",
		"endereco": rua if not rua.is_empty() else "%d-%d" % [cx, cz],
	}
	Gps.rota = Rota.tracar(j.global_position if j != null else mundo, mundo)
	Gps.destino_mudou.emit()
	AudioDirector.tocar_confirm(-14.0)
	_aplicar()


# --- desenho ------------------------------------------------------------------

func _draw() -> void:
	HudTema.sombra(self, _caixa(), 1.0, 0.0)
	_desenhar_legenda()


func _desenhar_sobre() -> void:
	var ci := _sobre
	var r := _caixa()
	ci.draw_rect(r, Color(0.0, 0.0, 0.0, 0.6), false, 1.5)
	# Mira no centro.
	var c := r.get_center()
	var cor := HudTema.alfa(HudTema.TEXTO, 0.85)
	for d: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		ci.draw_line(c + d * 3.0, c + d * 8.0, Color(0.0, 0.0, 0.0, 0.6), 1.6, true)
		ci.draw_line(c + d * 3.0, c + d * 8.0, cor, 0.7, true)
	# Lugar sob a mira, em cima do mapa.
	var q := MalhaUrbana.quadra_de(floori(_centro.x / MalhaUrbana.TAM),
		floori(_centro.z / MalhaUrbana.TAM))
	var lugar := NomesDeRua.rua_perto(_centro)
	var bairro := String(ParqueBuilder.planta(q)["nome"]) if int(q["uso"]) == MalhaUrbana.Uso.PARQUE \
		else MalhaUrbana.nome_do_distrito(q["distrito"])
	var topo := "%s  ·  %s" % [lugar, bairro.to_upper()] if not lugar.is_empty() else bairro.to_upper()
	HudTema.veu_horizontal(ci, Rect2(r.position, Vector2(r.size.x, 14.0)), true, 0.9)
	HudTema.texto(ci, HudTema.rotulo(), r.position + Vector2(6.0, 3.0), topo, HudTema.T_ROTULO,
		HudTema.TEXTO)
	# Escala no canto de baixo.
	var metros := 50.0 if ESCALAS[_i_escala] < 3.0 else (100.0 if ESCALAS[_i_escala] < 6.0 else 200.0)
	var w := metros / ESCALAS[_i_escala]
	var pe := Vector2(r.position.x + 8.0, r.end.y - 8.0)
	ci.draw_line(pe, pe + Vector2(w, 0.0), HudTema.TEXTO, 1.0, true)
	ci.draw_line(pe, pe + Vector2(0.0, -3.0), HudTema.TEXTO, 1.0, true)
	ci.draw_line(pe + Vector2(w, 0.0), pe + Vector2(w, -3.0), HudTema.TEXTO, 1.0, true)
	HudTema.texto(ci, HudTema.semi(), pe + Vector2(w + 4.0, -7.0), "%d m" % metros,
		HudTema.T_MICRO, HudTema.TEXTO)


func _desenhar_legenda() -> void:
	var x := area.end.x - LEGENDA
	var y := area.position.y
	y += secao(Vector2(x, y), "DESTINO", LEGENDA)
	var f := HudTema.regular()
	var fs := HudTema.semi()
	var h := HudTema.altura(f, HudTema.T_CORPO)
	if Gps.destino.is_empty():
		HudTema.texto(self, f, Vector2(x, y), "Nenhum. ENTER marca", HudTema.T_CORPO, HudTema.fraco())
		y += h
		HudTema.texto(self, f, Vector2(x, y), "um ponto no mapa.", HudTema.T_CORPO, HudTema.fraco())
		y += h + 8.0
	else:
		var nome := HudTema.encurtar(fs, String(Gps.destino.get("nome", "")), HudTema.T_CORPO, LEGENDA)
		HudTema.texto(self, fs, Vector2(x, y), nome, HudTema.T_CORPO, Color("ffd27a"))
		y += h
		var end_ := HudTema.encurtar(f, String(Gps.destino.get("endereco", "")), HudTema.T_CORPO, LEGENDA)
		HudTema.texto(self, f, Vector2(x, y), end_, HudTema.T_CORPO, HudTema.fraco())
		y += h
		var andando := Rota.comprimento(Gps.rota_do_destino())
		if andando > 0.0:
			HudTema.texto(self, fs, Vector2(x, y), "%s a pe" % HudTema.distancia(andando),
				HudTema.T_CORPO, HudTema.TEXTO)
			y += h
		y += 8.0
	if not Missoes.atual.is_empty():
		y += secao(Vector2(x, y), "MISSAO", LEGENDA)
		HudTema.losango(self, Vector2(x + 3.0, y + h * 0.5), 2.6, HudTema.acento())
		HudTema.texto(self, fs, Vector2(x + 9.0, y), HudTema.encurtar(fs,
			String(Missoes.atual.get("titulo", "")), HudTema.T_CORPO, LEGENDA - 9.0),
			HudTema.T_CORPO, HudTema.TEXTO)
		y += h + 8.0
	y += secao(Vector2(x, y), "LEGENDA", LEGENDA)
	for par: Array in [[&"casa_verde", "Casa da fumaca"], [&"casa", "Casa"], [&"mercado", "Mercado"],
			[&"bar", "Bar"], [&"telefone", "Orelhao"], [&"parque", "Parque"]]:
		HudTema.blip(self, Vector2(x + 4.0, y + h * 0.5), par[0], 1.1)
		HudTema.texto(self, f, Vector2(x + 12.0, y), String(par[1]), HudTema.T_CORPO,
			HudTema.fraco())
		y += h + 1.0
