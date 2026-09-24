## Vitais do rodape esquerdo: vida, folego, lanterna e PROCURADO.
##
## A regra e a mesma que `HudCidade` ja seguia para a vida, estendida a tudo:
## barra cheia parada num canto o jogo inteiro e o oposto do que este jogo quer
## parecer. Cada bloco aparece quando MUDA e some quando volta a nao dizer nada
## (RDR2, TLOU, Skyrim). Abaixo do limite grave ele fica.
##
##     vida       cai -> fica `T_LEITURA`; abaixo de 40% nao some
##     folego     aparece enquanto nao esta cheio (correr gasta)
##     lanterna   aparece acesa; fica se a bateria esta abaixo de 25%
##     PROCURADO  enquanto a blitz te procura, com o tempo que falta
##
## Os blocos andam juntos: o que some deixa o espaco, e o seguinte escorrega
## para a esquerda em vez de deixar buraco.
class_name HudEstado
extends Control

const VIDA_GRAVE := 0.4
const FEIXE_ALERTA := 0.25
const BARRA := Vector2(46.0, 3.0)
const VAO := 10.0

var alvo: Node3D

var _vida := 1.0
var _t_vida := 0.0
## Alfa atual de cada bloco, 0..1. Anda para o alvo em `T_ENTRA`/`T_SAI`.
var _alfa := {"vida": 0.0, "folego": 0.0, "lanterna": 0.0, "procurado": 0.0}
var _folego := 1.0
var _lanterna := false
var _bateria := 1.0
var _procurado := false
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Inventario.vida_mudou.connect(_ao_mudar_vida)
	_vida = float(Inventario.vida) / float(maxi(1, Inventario.vida_maxima))


func _ao_mudar_vida(atual: int, maximo: int) -> void:
	var antes := _vida
	_vida = float(atual) / float(maxi(1, maximo))
	# So mudanca de verdade chama a barra. Carga de save emite `vida_mudou` com o
	# mesmo valor, e abrir o jogo com a barra na tela seria anunciar nada.
	if not is_equal_approx(_vida, antes):
		_t_vida = HudTema.T_LEITURA


func _process(delta: float) -> void:
	_t += delta
	if alvo == null or not is_instance_valid(alvo):
		alvo = get_tree().get_first_node_in_group(&"player") as Node3D
	if _t_vida > 0.0:
		_t_vida -= delta
	var quer := {"vida": 0.0, "folego": 0.0, "lanterna": 0.0, "procurado": 0.0}
	quer["vida"] = 1.0 if _t_vida > 0.0 or _vida <= VIDA_GRAVE else 0.0
	if alvo != null:
		_folego = float(alvo.get(&"folego")) / Player.FOLEGO_MAX
		_lanterna = bool(alvo.get(&"lanterna_ligada"))
		_bateria = float(alvo.get(&"bateria"))
		var dirigindo := alvo.has_method(&"dirigindo") and bool(alvo.call(&"dirigindo"))
		quer["folego"] = 1.0 if _folego < 0.995 and not dirigindo else 0.0
		var tem := Inventario.tem(&"lanterna")
		quer["lanterna"] = 1.0 if tem and (_lanterna or _bateria < FEIXE_ALERTA) else 0.0
	_procurado = BlitzNoCaminho.procurado()
	quer["procurado"] = 1.0 if _procurado else 0.0
	# Opcoes > HUD > VITAIS. SEMPRE mostra o que se aplica (lanterna so com
	# lanterna na bolsa, folego so a pe); DESLIGADOS apaga tudo menos o selo de
	# PROCURADO, que e aviso de estado de jogo e nao medidor.
	match HudConfig.modo_vitais():
		HudConfig.Vitais.SEMPRE:
			quer["vida"] = 1.0
			if alvo != null:
				var a_pe := not (alvo.has_method(&"dirigindo") and bool(alvo.call(&"dirigindo")))
				quer["folego"] = 1.0 if a_pe else 0.0
				quer["lanterna"] = 1.0 if Inventario.tem(&"lanterna") else 0.0
		HudConfig.Vitais.DESLIGADOS:
			quer["vida"] = 0.0
			quer["folego"] = 0.0
			quer["lanterna"] = 0.0
	for k: String in _alfa:
		var q: float = quer[k]
		var tempo := HudTema.T_ENTRA if q > float(_alfa[k]) else HudTema.T_SAI * 2.0
		_alfa[k] = move_toward(float(_alfa[k]), q, delta / tempo)
	queue_redraw()


func _draw() -> void:
	var r := HudLayout.ESTADO
	var x := r.position.x
	var meio := r.get_center().y
	var f := HudTema.rotulo()
	var tam := HudTema.T_MICRO

	var a: float = _alfa["vida"]
	if a > 0.0:
		var grave := _vida <= VIDA_GRAVE
		var cor := HudTema.PERIGO if grave else HudTema.TEXTO
		# Pulso so no grave: a barra que respira e a tensao, nao a informacao.
		if grave:
			a *= 0.72 + 0.28 * sin(_t * 5.0)
		_cruz(Vector2(x + 3.5, meio), 3.2, HudTema.alfa(cor, a))
		HudTema.barra(self, Rect2(x + 10.0, meio - BARRA.y * 0.5, BARRA.x, BARRA.y),
			_vida, cor, a)
		x += (10.0 + BARRA.x + VAO) * float(_alfa["vida"])

	a = _alfa["folego"]
	if a > 0.0:
		var cor := HudTema.ALERTA if _folego < 0.25 else HudTema.fraco()
		_pulmao(Vector2(x + 3.5, meio), HudTema.alfa(cor, a))
		HudTema.barra(self, Rect2(x + 10.0, meio - 1.0, 30.0, 2.0), _folego, cor, a)
		x += (10.0 + 30.0 + VAO) * a

	a = _alfa["lanterna"]
	if a > 0.0:
		var alerta := _bateria < FEIXE_ALERTA
		var cor := HudTema.ALERTA if alerta else HudTema.TEXTO
		if alerta and _bateria < 0.12:
			a *= 0.6 + 0.4 * sin(_t * 8.0)
		_lanterna_icone(Vector2(x, meio), HudTema.alfa(cor, a), _lanterna)
		# Quatro gomos: o que o jogador precisa saber e "cheia / metade / acabando",
		# nao a porcentagem.
		var gomos := clampi(ceili(_bateria * 4.0), 0, 4)
		for i in 4:
			var g := Rect2(x + 13.0 + float(i) * 4.5, meio - 2.0, 3.5, 4.0)
			draw_rect(g, HudTema.alfa(Color(0.0, 0.0, 0.0, 0.55), a))
			if i < gomos:
				draw_rect(g.grow(-0.5), HudTema.alfa(cor, a))
		x += (13.0 + 18.0 + VAO) * float(_alfa["lanterna"])

	a = _alfa["procurado"]
	if a > 0.0:
		var t := "PROCURADO"
		var w := HudTema.largura(f, t, tam) + 8.0
		var h := HudTema.altura(f, tam) + 2.0
		var caixa := Rect2(x, meio - h * 0.5, w, h)
		var pulso := 0.55 + 0.45 * absf(sin(_t * 3.0))
		HudTema.poligono(self, HudTema.cantos(caixa, 1.5), HudTema.alfa(HudTema.PERIGO, a * pulso))
		HudTema.texto(self, f, caixa.position + Vector2(4.0, 1.0), t, tam,
			HudTema.alfa(Color.WHITE, a))


func _cruz(c: Vector2, r: float, cor: Color) -> void:
	var b := r * 0.36
	draw_rect(Rect2(c.x - b, c.y - r, b * 2.0, r * 2.0), cor)
	draw_rect(Rect2(c.x - r, c.y - b, r * 2.0, b * 2.0), cor)


func _pulmao(c: Vector2, cor: Color) -> void:
	# Tres riscos de vento: o icone de folego de qualquer jogo de acao.
	for i in 3:
		var y := c.y - 2.4 + float(i) * 2.4
		var w := 6.0 - absf(float(i) - 1.0) * 2.0
		draw_line(Vector2(c.x - 3.0, y), Vector2(c.x - 3.0 + w, y), cor, 0.9)


func _lanterna_icone(o: Vector2, cor: Color, acesa: bool) -> void:
	draw_rect(Rect2(o.x, o.y - 1.2, 5.0, 2.4), cor)
	HudTema.poligono(self, PackedVector2Array([Vector2(o.x + 5.0, o.y - 1.2),
		Vector2(o.x + 7.5, o.y - 2.6), Vector2(o.x + 7.5, o.y + 2.6),
		Vector2(o.x + 5.0, o.y + 1.2)]), cor)
	if acesa:
		for k in 3:
			var ang := (float(k) - 1.0) * 0.45
			var d := Vector2(cos(ang), sin(ang))
			draw_line(Vector2(o.x + 9.0, o.y) + d * 0.5, Vector2(o.x + 9.0, o.y) + d * 2.6,
				cor, 0.7)
