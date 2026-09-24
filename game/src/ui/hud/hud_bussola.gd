## Bussola do topo: uma fita de rumo com o objetivo pregado nela.
##
## Por que ela existe se ja ha radar
## ---------------------------------
## Porque o radar responde "onde" e a bussola responde "para que lado eu viro".
## O objetivo a 600 m esta fora de qualquer radar de 76 px; na fita ele e um
## losango que anda para o meio conforme o jogador vira, com a distancia embaixo.
## Era o trabalho da setinha do cartao de papel, feito no lugar em que o olho ja
## esta — o centro de cima, e nao o canto.
##
## Convencao: norte e -Z, leste e +X (a mesma de `Mapa` e de `Gps._bussola`).
class_name HudBussola
extends Control

## Quanto de horizonte a fita mostra, de ponta a ponta.
const ABERTURA := deg_to_rad(150.0)
## Rosa em portugues. Leste e L e oeste e O, como na placa da rua.
const ROSA := ["N", "NE", "L", "SE", "S", "SO", "O", "NO"]
## Meia abertura em que o alvo costuma estar na tela (FOV de ~70 graus).
const CAMPO_DO_MARCADOR := deg_to_rad(30.0)

var alvo: Node3D
## Escala do HUD. A fita mantem a largura NA TELA; so letra e altura crescem.
var escala := 1.0

var _rumo := 0.0
var _marcas: Array[Dictionary] = []
## Proxima manobra do GPS (`HudNavegacao.proxima`) e o nome da rua seguinte.
var _manobra: Dictionary = {}
var _rua_seguinte := ""
var _ponto_da_rua := Vector2.INF
var _desde_gps := 99.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	if alvo == null or not is_instance_valid(alvo):
		alvo = get_tree().get_first_node_in_group(&"player") as Node3D
		if alvo == null:
			return
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var f := -cam.global_transform.basis.z
		if Vector2(f.x, f.z).length() > 0.01:
			# 0 = norte, cresce para o leste.
			_rumo = atan2(f.x, -f.z)
	_marcas.clear()
	var eu := alvo.global_position
	if not Interiores.dentro:
		var m := Missoes.posicao_do_alvo()
		if m != Vector3.INF:
			_marcas.append({"pos": m, "tipo": &"missao"})
		if not Gps.destino.is_empty():
			var d: Vector3 = Gps.destino["mundo"]
			if m == Vector3.INF or Vector2(d.x - m.x, d.z - m.z).length() > 4.0:
				_marcas.append({"pos": d, "tipo": &"destino"})
	for m: Dictionary in _marcas:
		var p: Vector3 = m["pos"]
		var dx := p.x - eu.x
		var dz := p.z - eu.z
		m["rumo"] = atan2(dx, -dz)
		m["dist"] = Vector2(dx, dz).length()
	_atualizar_gps(eu, _delta)
	queue_redraw()


## Tres vezes por segundo basta: a 60 km/h o carro anda 5 m entre duas contas,
## e o numero da distancia ja arredonda de 5 em 5.
func _atualizar_gps(eu: Vector3, delta: float) -> void:
	_desde_gps += delta
	if _desde_gps < 0.3:
		return
	_desde_gps = 0.0
	if not HudConfig.ver_gps() or Interiores.dentro or Gps.destino.is_empty():
		_manobra = {}
		return
	_manobra = HudNavegacao.proxima(Gps.rota_do_destino(), Vector2(eu.x, eu.z))
	if _manobra.is_empty():
		return
	# O nome da rua seguinte so muda quando a manobra muda de esquina.
	var depois: Vector2 = _manobra["depois"]
	if depois != _ponto_da_rua:
		_ponto_da_rua = depois
		_rua_seguinte = NomesDeRua.rua_perto(Vector3(depois.x, 0.0, depois.y))
		if _manobra["tipo"] == &"chegada":
			_rua_seguinte = String(Gps.destino.get("nome", "")).to_upper()


## A fita em coordenada logica, ja com a largura corrigida pela escala.
func _r() -> Rect2:
	var w := HudLayout.largura_logica(HudLayout.BUSSOLA.size.x, escala)
	return Rect2(HudLayout.PIVO_BUSSOLA.x - w * 0.5, HudLayout.M, w, HudLayout.BUSSOLA.size.y)


func _x_de(rumo: float) -> float:
	var r := _r()
	var rel := wrapf(rumo - _rumo, -PI, PI)
	return r.get_center().x + rel / (ABERTURA * 0.5) * (r.size.x * 0.5)


## Alfa pela distancia do meio: a fita some nas pontas em vez de acabar num
## corte seco.
func _alfa_de(x: float) -> float:
	var r := _r()
	var d := absf(x - r.get_center().x) / (r.size.x * 0.5)
	return clampf((1.0 - d) / 0.28, 0.0, 1.0)


func _draw() -> void:
	var r := _r()
	var linha_y := r.position.y + 9.0
	var f := HudTema.semi()
	var f_reg := HudTema.regular()

	# Linha de base em degradê dos dois lados.
	var meio := r.get_center().x
	for lado: float in [-1.0, 1.0]:
		var ponta := meio + lado * r.size.x * 0.5
		draw_polygon(PackedVector2Array([Vector2(meio, linha_y), Vector2(ponta, linha_y),
				Vector2(ponta, linha_y + 0.6), Vector2(meio, linha_y + 0.6)]),
			PackedColorArray([HudTema.alfa(HudTema.TEXTO, 0.5), HudTema.alfa(HudTema.TEXTO, 0.0),
				HudTema.alfa(HudTema.TEXTO, 0.0), HudTema.alfa(HudTema.TEXTO, 0.5)]))

	# Tique a cada 15 graus; letra a cada 45.
	for i in 24:
		var rumo := deg_to_rad(float(i) * 15.0)
		var x := _x_de(rumo)
		var a := _alfa_de(x)
		if a <= 0.0:
			continue
		if i % 3 == 0:
			var nome: String = ROSA[floori(i / 3.0)]
			var principal := nome.length() == 1
			var tam := HudTema.T_ROTULO if principal else HudTema.T_MICRO
			var cor := HudTema.TEXTO if principal else HudTema.fraco()
			if nome == "N":
				cor = HudTema.acento()
			var fonte := f if principal else f_reg
			var w := HudTema.largura(fonte, nome, tam)
			HudTema.texto(self, fonte, Vector2(x - w * 0.5, linha_y - 1.0 - HudTema.altura(fonte, tam)),
				nome, tam, HudTema.alfa(cor, a))
		else:
			draw_rect(Rect2(x - 0.25, linha_y - 2.0, 0.5, 2.0),
				HudTema.alfa(HudTema.fraco(), a * 0.8))

	# Marca do meio: onde a frente esta.
	HudTema.poligono(self, PackedVector2Array([Vector2(meio - 2.2, linha_y + 1.6),
		Vector2(meio + 2.2, linha_y + 1.6), Vector2(meio, linha_y - 0.6)]), HudTema.TEXTO)

	# Objetivo e destino. Fora da abertura eles ficam presos na ponta da fita,
	# com uma seta dizendo para que lado virar.
	for m: Dictionary in _marcas:
		var rel := wrapf(float(m["rumo"]) - _rumo, -PI, PI)
		var fora := absf(rel) > ABERTURA * 0.5
		var x := _x_de(float(m["rumo"]))
		if fora:
			x = meio + signf(rel) * (r.size.x * 0.5 - 4.0)
		var cor := HudTema.acento() if m["tipo"] == &"missao" else Color("ffd27a")
		var c := Vector2(x, linha_y + 5.0)
		if m["tipo"] == &"missao":
			HudTema.losango(self, c, 3.0, cor)
		else:
			draw_circle(c, 3.6, Color(0.0, 0.0, 0.0, 0.7), true, -1.0, true)
			draw_circle(c, 2.6, cor, true, -1.0, true)
		if fora:
			var s := signf(rel)
			HudTema.poligono(self, PackedVector2Array([c + Vector2(s * 5.0, -2.2),
				c + Vector2(s * 7.6, 0.0), c + Vector2(s * 5.0, 2.2)]), cor)
			continue
		# Com o alvo dentro do campo de visao o marcador 3D ja escreve a distancia
		# em cima do proprio lugar; repetir aqui era o mesmo numero duas vezes.
		if HudConfig.ver_marcador() and absf(rel) < CAMPO_DO_MARCADOR:
			continue
		var d := HudTema.distancia(float(m["dist"]))
		var w := HudTema.largura(f, d, HudTema.T_MICRO)
		HudTema.texto(self, f, Vector2(x - w * 0.5, c.y + 3.6), d, HudTema.T_MICRO,
			HudTema.alfa(HudTema.TEXTO, 0.9))

	_desenhar_gps(r)


## "[seta] 40 m  R. DA SAUDADE", centrado embaixo da fita. Com o nome da rua a
## seta ja diz o verbo; sem nome (ou na chegada) entra o verbo por extenso.
## Cortar "VIRE A DIREITA AV. P..." para caber os dois lia pior que qualquer um.
func _desenhar_gps(r: Rect2) -> void:
	if _manobra.is_empty():
		return
	var tipo: StringName = _manobra["tipo"]
	var f_semi := HudTema.semi()
	var f_rot := HudTema.rotulo()
	var y := r.position.y + HudLayout.BUSSOLA.size.y + 1.0
	var h := HudLayout.GPS_ALTURA - 2.0
	var dist := HudTema.distancia(float(_manobra["dist"]))
	var verbo := HudNavegacao.verbo(tipo)
	var rua := _rua_seguinte
	var tam := HudTema.T_MICRO
	var w_icone := 9.0
	var w_dist := HudTema.largura(f_semi, dist, HudTema.T_ROTULO)
	var largura := HudLayout.largura_logica(HudLayout.GPS_LARGURA, escala)
	var sobra := largura - w_icone - w_dist - 19.0
	var resto := verbo if rua.is_empty() or tipo == &"siga" else rua
	resto = HudTema.encurtar(f_rot, resto, tam, sobra)
	var w := w_icone + 4.0 + w_dist + 5.0 + HudTema.largura(f_rot, resto, tam)
	var x := r.get_center().x - w * 0.5
	# Pilula escura: a linha do GPS e instrucao, e se le com calma.
	HudTema.painel(self, Rect2(x - 5.0, y, w + 10.0, h), 0.85, h * 0.5 - 0.1)
	var c := Vector2(x + w_icone * 0.5, y + h * 0.5)
	_icone_manobra(c, tipo, HudTema.acento())
	x += w_icone + 4.0
	HudTema.texto(self, f_semi, Vector2(x, y + (h - HudTema.altura(f_semi, HudTema.T_ROTULO)) * 0.5),
		dist, HudTema.T_ROTULO, HudTema.TEXTO)
	x += w_dist + 5.0
	HudTema.texto(self, f_rot, Vector2(x, y + (h - HudTema.altura(f_rot, tam)) * 0.5), resto, tam,
		HudTema.fraco())


## Seta da manobra, desenhada em linha com ponta. Vetor: nitida em 4K.
func _icone_manobra(c: Vector2, tipo: StringName, cor: Color) -> void:
	var l := 1.1
	match tipo:
		&"direita", &"esquerda":
			var s := 1.0 if tipo == &"direita" else -1.0
			draw_polyline(PackedVector2Array([c + Vector2(-1.5 * s, 4.0), c + Vector2(-1.5 * s, -0.5),
				c + Vector2(2.5 * s, -0.5)]), cor, l, true)
			HudTema.poligono(self, PackedVector2Array([c + Vector2(2.0 * s, -3.0),
				c + Vector2(4.6 * s, -0.5), c + Vector2(2.0 * s, 2.0)]), cor)
		&"retorno":
			draw_arc(c + Vector2(0.0, -0.5), 2.2, PI, TAU, 10, cor, l, true)
			draw_line(c + Vector2(-2.2, -0.5), c + Vector2(-2.2, 4.0), cor, l, true)
			draw_line(c + Vector2(2.2, -0.5), c + Vector2(2.2, 2.0), cor, l, true)
			HudTema.poligono(self, PackedVector2Array([c + Vector2(0.4, 1.6),
				c + Vector2(4.0, 1.6), c + Vector2(2.2, 4.2)]), cor)
		&"chegada":
			HudTema.losango(self, c, 3.2, cor)
		_:
			draw_line(c + Vector2(0.0, 4.0), c + Vector2(0.0, -1.5), cor, l, true)
			HudTema.poligono(self, PackedVector2Array([c + Vector2(-2.6, -1.0),
				c + Vector2(0.0, -4.2), c + Vector2(2.6, -1.0)]), cor)
