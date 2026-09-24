## A pausa em abas: MAPA, MISSOES, INVENTARIO, PERSONAGEM, SISTEMA.
##
## Por que abas, e nao a prancha
## -----------------------------
## A prancha de inventario era a pausa inteira: colagem de papel, fita, faixa de
## couro, polaroide e, por cima, a folha creme do menu de sistema. Tres linguas
## na mesma tela (papel, RE7 e o HUD novo), e o mapa, as missoes e o dinheiro so
## existiam espalhados pelo celular. O hub junta o que o jogador procura quando
## para — onde estou, o que falta, o que carrego, quem sou, e o jogo — no mesmo
## vocabulario do HUD (`HudTema`), como RDR2 e Cyberpunk.
##
## Entrada
## -------
##   ESC / START        abre (na ultima aba) e fecha; com submodo aberto, volta
##   TAB / SELECT       toque: abre direto no INVENTARIO (aberto, fecha)
##                      segurado: expande o HUD enquanto estiver apertado
##   Q E / LB RB        troca de aba (clique na aba tambem)
##   W S A D / analogico, E / A: dentro da aba
class_name PausaHub
extends CanvasLayer

signal fechou()
signal pediu_titulo()
signal pediu_carregar(espaco: int)

const ABAS := ["MAPA", "MISSOES", "INVENTARIO", "PERSONAGEM", "SISTEMA"]
enum Aba { MAPA, MISSOES, INVENTARIO, PERSONAGEM, SISTEMA }

## Onde as abas desenham. O resto e moldura: barra de abas e rodape.
const AREA := Rect2(24.0, 44.0, 432.0, 192.0)
const BARRA_Y := 14.0
const RODAPE_Y := 247.0
## Camada: acima da prancha antiga (110) e do veu do UIManager (108), abaixo do
## pos (150) — a pausa recebe o mesmo grao que o resto da imagem.
const CAMADA := 112

var aberta := false
var aba_atual: int = Aba.MAPA

var _raiz: Control
## Rodape (teclas, saldo, hora) acima do pos. No PS1 a vinheta multiplica o canto
## e comia a primeira e a ultima dica — texto de 7 px e o que o `UiEstilo` manda
## para CAMADA_ACIMA_DO_POS. So ele sobe; a moldura continua recebendo o grao.
var _camada_rodape: CanvasLayer
var _rodape: Control
var _abas: Array[PausaAba] = []
var _alfa := 0.0
var _hits_abas: Array[Rect2] = []
var _mouse_antes: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
## TAB apertado desde (ms), ou -1. A decisao entre abrir e expandir e no soltar.
var _tab_desde := -1
## Quanto segurar para virar "expandir": abaixo disto e toque.
const SEGURAR_MS := 300


func _ready() -> void:
	layer = CAMADA
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"pausa_hub")
	_raiz = Control.new()
	_raiz.name = "PausaHub"
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_raiz)
	_raiz.position = Vector2.ZERO
	_raiz.size = HudTema.TELA
	_raiz.draw.connect(_desenhar_moldura)
	_raiz.gui_input.connect(_ao_mouse)
	_camada_rodape = CanvasLayer.new()
	_camada_rodape.name = "RodapeAcimaDoPos"
	_camada_rodape.layer = UiEstilo.CAMADA_ACIMA_DO_POS
	_camada_rodape.visible = false
	add_child(_camada_rodape)
	_rodape = Control.new()
	_rodape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rodape.position = Vector2.ZERO
	_rodape.size = HudTema.TELA
	_rodape.draw.connect(func() -> void: _desenhar_rodape(_rodape))
	_camada_rodape.add_child(_rodape)
	for cena: GDScript in [PausaAbaMapa, PausaAbaMissoes, PausaAbaInventario,
			PausaAbaPersonagem, PausaAbaSistema]:
		var aba: PausaAba = cena.new()
		aba.area = AREA
		aba.hub = self
		aba.visible = false
		_raiz.add_child(aba)
		_abas.append(aba)
	visible = false
	if OS.get_cmdline_user_args().has("--pausa-teclas"):
		_simular_teclas.call_deferred()


## So teste: aperta ESC e depois Q de verdade (pela fila de entrada do motor), e
## o hub tem de abrir no MAPA e ir para a SISTEMA. Prova o caminho que o
## jogador usa, e nao o `abrir()` que a captura chama direto.
func _simular_teclas() -> void:
	await get_tree().create_timer(2.5).timeout
	# TAB segurado: expande, nao abre. TAB tocado: abre no INVENTARIO.
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.physical_keycode = KEY_TAB
	tab.pressed = true
	Input.parse_input_event(tab)
	await get_tree().create_timer(0.6).timeout
	print("[pausa] tab segurado -> expandido=%s aberta=%s" % [HudConfig.expandido, aberta])
	var solta := tab.duplicate() as InputEventKey
	solta.pressed = false
	Input.parse_input_event(solta)
	await get_tree().create_timer(0.2).timeout
	print("[pausa] tab solto -> expandido=%s aberta=%s" % [HudConfig.expandido, aberta])
	Input.parse_input_event(tab)
	await get_tree().process_frame
	Input.parse_input_event(solta)
	await get_tree().create_timer(0.3).timeout
	print("[pausa] tab tocado -> aberta=%s aba=%s" % [aberta, ABAS[aba_atual]])
	Input.parse_input_event(tab)
	await get_tree().process_frame
	Input.parse_input_event(solta)
	await get_tree().create_timer(0.4).timeout
	print("[pausa] tab de novo -> aberta=%s" % aberta)
	# O hub lembra a ultima aba; o roteiro de ESC parte do MAPA.
	aba_atual = Aba.MAPA
	# ESC abre no MAPA, Q vai para SISTEMA, S S desce ate IMAGEM, ENTER entra
	# nela, ESC sai da pagina (o hub fica), ESC fecha.
	var passos := [[KEY_ESCAPE, "abriu"], [KEY_Q, "sistema"], [KEY_S, ""], [KEY_S, ""],
		[KEY_ENTER, "dentro de imagem"], [KEY_ESCAPE, "saiu da pagina"], [KEY_ESCAPE, "fechou"]]
	for passo: Array in passos:
		for apertada: bool in [true, false]:
			var ev := InputEventKey.new()
			ev.keycode = passo[0]
			ev.physical_keycode = passo[0]
			ev.pressed = apertada
			Input.parse_input_event(ev)
			await get_tree().process_frame
		await get_tree().create_timer(0.4).timeout
		if not String(passo[1]).is_empty():
			print("[pausa] %s -> aberta=%s aba=%s ocupada=%s" % [passo[1], aberta,
				ABAS[aba_atual], _abas[aba_atual].ocupada()])


# --- abrir e fechar -----------------------------------------------------------

func abrir(qual: int = -1) -> void:
	if qual >= 0:
		aba_atual = qual
	if aberta:
		_trocar_para(aba_atual)
		return
	aberta = true
	visible = true
	_mouse_antes = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sessao.pausar(true)
	UIManager.push_menu(self, false, &"pausa")
	AudioDirector.tocar_confirm(-14.0)
	_trocar_para(aba_atual, false)
	var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_method(_definir_alfa, 0.0, 1.0, UiEstilo.T_RE7_OPEN)


func fechar() -> void:
	if not aberta:
		return
	aberta = false
	Settings.save_config()
	UIManager.remove_menu(self)
	Sessao.pausar(false)
	Input.mouse_mode = _mouse_antes
	AudioDirector.tocar_nav(-18.0)
	var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_method(_definir_alfa, _alfa, 0.0, UiEstilo.T_RE7_CLOSE)
	t.tween_callback(func() -> void:
		if not aberta:
			visible = false)
	fechou.emit()


func _definir_alfa(v: float) -> void:
	_alfa = v
	_raiz.modulate.a = v
	_raiz.queue_redraw()


func _trocar_para(qual: int, som: bool = true) -> void:
	aba_atual = posmod(qual, _abas.size())
	for i in _abas.size():
		_abas[i].visible = i == aba_atual
	_abas[aba_atual].ao_entrar()
	if som:
		AudioDirector.tocar_nav(-18.0)
	_raiz.queue_redraw()


func aba(qual: int) -> PausaAba:
	return _abas[qual]


# --- entrada ------------------------------------------------------------------

## Outra tela de jogo por cima? Com celular, GPS, documento ou conversa aberta a
## tecla de pausa e deles.
func _outra_tela() -> bool:
	for nome: String in ["Celular", "Gps", "Terminal", "Documento", "Dialogo", "Conversa"]:
		var no := get_node_or_null(NodePath("/root/" + nome))
		if no != null and bool(no.get(&"ativo")):
			return true
	var cinema := get_node_or_null(^"/root/Cinema")
	if cinema != null and bool(cinema.get(&"ativa")):
		return true
	# Menu de titulo aberto: ESC e dele (a mesma regra da prancha).
	var pai := get_parent()
	if pai != null:
		for n: Node in pai.get_children():
			if n is Menu and (n as Menu).visible:
				return true
	return false


func _unhandled_input(evento: InputEvent) -> void:
	if not aberta:
		if _outra_tela() or UIManager.profundidade() > 0:
			return
		if evento.is_action_pressed(&"pausa"):
			abrir()
			get_viewport().set_input_as_handled()
		elif evento.is_action_pressed(&"inventario") and not evento.is_echo():
			_tab_desde = Time.get_ticks_msec()
			get_viewport().set_input_as_handled()
		elif evento.is_action_released(&"inventario") and _tab_desde >= 0:
			var foi_toque := Time.get_ticks_msec() - _tab_desde < SEGURAR_MS
			_tab_desde = -1
			HudConfig.expandido = false
			if foi_toque:
				abrir(Aba.INVENTARIO)
			get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()
	if evento.is_echo():
		return
	if evento.is_action_pressed(&"pausa"):
		var a := _abas[aba_atual]
		if not (a.ocupada() and a.voltar()):
			fechar()
		return
	if evento.is_action_pressed(&"inventario"):
		fechar()
		return
	if _troca_de_aba(evento):
		return
	_abas[aba_atual].tratar(evento)


func _process(_delta: float) -> void:
	# Documento e as outras telas abrem por cima da pausa (130 > 112): o rodape,
	# que mora acima delas, sai enquanto estiverem na frente.
	var com_rodape := visible and _alfa > 0.0 and not _outra_tela()
	_camada_rodape.visible = com_rodape
	if com_rodape:
		_rodape.modulate.a = _alfa
		_rodape.queue_redraw()
	# TAB segurado alem do toque: HUD expandido ate soltar. Se a tela mudou no
	# meio (celular abriu), solta sozinho.
	if _tab_desde >= 0:
		if _outra_tela() or aberta:
			_tab_desde = -1
			HudConfig.expandido = false
		elif Time.get_ticks_msec() - _tab_desde >= SEGURAR_MS:
			HudConfig.expandido = true


func _troca_de_aba(evento: InputEvent) -> bool:
	var passo := 0
	var tecla := evento as InputEventKey
	if tecla != null and tecla.pressed:
		if tecla.physical_keycode == KEY_Q:
			passo = -1
		elif tecla.physical_keycode == KEY_E and not _abas[aba_atual].ocupada():
			# E tambem e "escolher". Troca de aba so quando a aba nao esta num
			# submodo que precise dele.
			passo = 1
	var botao := evento as InputEventJoypadButton
	if botao != null and botao.pressed:
		if botao.button_index == JOY_BUTTON_LEFT_SHOULDER:
			passo = -1
		elif botao.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			passo = 1
	if passo == 0:
		return false
	_trocar_para(aba_atual + passo)
	return true


func _ao_mouse(evento: InputEvent) -> void:
	var mb := evento as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	for i in _hits_abas.size():
		if _hits_abas[i].has_point(mb.position):
			_trocar_para(i)
			_raiz.accept_event()
			return


# --- moldura ------------------------------------------------------------------

func _desenhar_moldura() -> void:
	var ci := _raiz
	# Veu escuro por cima do mundo (o desfoque e o do UIManager, na camada 108).
	ci.draw_rect(Rect2(Vector2.ZERO, HudTema.TELA), Color(0.015, 0.02, 0.025, 0.62))
	# Degrade mais fechado em cima e embaixo: a moldura assenta, o meio respira.
	for faixa: Array in [[0.0, 40.0, 0.5, 0.0], [HudTema.TELA.y - 34.0, 34.0, 0.0, 0.5]]:
		var y: float = faixa[0]
		var h: float = faixa[1]
		var c0 := Color(0.0, 0.0, 0.0, faixa[2])
		var c1 := Color(0.0, 0.0, 0.0, faixa[3])
		ci.draw_polygon(PackedVector2Array([Vector2(0.0, y), Vector2(HudTema.TELA.x, y),
			Vector2(HudTema.TELA.x, y + h), Vector2(0.0, y + h)]),
			PackedColorArray([c0, c0, c1, c1]))
	_desenhar_abas(ci)


func _desenhar_abas(ci: Control) -> void:
	var f := HudTema.fonte(600, 2)
	var tam := HudTema.T_CORPO + 1
	var vao := 18.0
	var larguras: Array[float] = []
	var total := 0.0
	for nome: String in ABAS:
		var w := HudTema.largura(f, nome, tam)
		larguras.append(w)
		total += w
	total += vao * float(ABAS.size() - 1)
	var x := roundf((HudTema.TELA.x - total) * 0.5)
	var h := HudTema.altura(f, tam)
	_hits_abas.clear()
	for i in ABAS.size():
		var ativa := i == aba_atual
		var cor := HudTema.TEXTO if ativa else HudTema.fraco()
		HudTema.texto(ci, f, Vector2(x, BARRA_Y), ABAS[i], tam, cor if ativa
			else HudTema.alfa(cor, 0.8))
		if ativa:
			ci.draw_rect(Rect2(x, BARRA_Y + h + 3.0, larguras[i], 1.2), HudTema.acento())
		_hits_abas.append(Rect2(x - vao * 0.5, BARRA_Y - 6.0, larguras[i] + vao, h + 14.0))
		x += larguras[i] + vao
	# Teclas de troca nas pontas da fila.
	var ctl := Settings.get(&"controle") as Controle
	var pad := ctl != null and ctl.dispositivo == Controle.Dispositivo.CONTROLE
	var esq := HudLayout.glifo("LB", true) if pad else "Q"
	var dir := HudLayout.glifo("RB", true) if pad else "E"
	var xi := roundf((HudTema.TELA.x - total) * 0.5) - 8.0 - HudTema.largura_tecla(esq)
	HudTema.tecla(ci, Vector2(xi, BARRA_Y - 0.5), esq)
	HudTema.tecla(ci, Vector2(x - vao + 8.0, BARRA_Y - 0.5), dir)
	# Fio da barra, de ponta a ponta da area.
	ci.draw_rect(Rect2(AREA.position.x, BARRA_Y + h + 4.5, AREA.size.x, 0.5),
		HudTema.alfa(HudTema.TEXTO, 0.12))


func _desenhar_rodape(ci: Control) -> void:
	var dicas: Array = _abas[aba_atual].dicas()
	dicas.append(["ESC", "FECHAR"])
	var frase := ""
	for d: Array in dicas:
		frase += "[%s] %s   " % [d[0], d[1]]
	HudObjetivo.desenhar_frase(ci, Vector2(AREA.position.x, RODAPE_Y), frase.strip_edges(),
		HudTema.T_ROTULO, 1.0, HudTema.fraco())
	# Direita: dinheiro, hora e onde.
	var ws := get_node_or_null(^"/root/WorldState")
	var rel: Relogio = ws.get(&"relogio") as Relogio if ws != null else null
	var partes: PackedStringArray = [Dinheiro.formatar(Dinheiro.saldo())]
	if rel != null:
		partes.append("DIA %d  ·  %s %s" % [rel.dia, rel.dia_da_semana(), rel.texto()])
	var texto := "  ·  ".join(partes)
	var fs := HudTema.semi()
	var w := HudTema.largura(fs, texto, HudTema.T_CORPO)
	HudTema.texto(ci, fs, Vector2(AREA.end.x - w, RODAPE_Y + 0.5), texto, HudTema.T_CORPO,
		HudTema.TEXTO)
