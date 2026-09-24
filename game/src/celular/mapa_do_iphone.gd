## O mapa do app Mapas: a cidade desenhada como o iPhone de 2010 a mostrava, com
## os mapas do Google — chao creme, rua branca de contorno cinza, avenida
## amarela, parque verde e o nome das ruas deitado ao longo delas.
##
## Nao le a cena. Pergunta a `MalhaUrbana` onde passa rua e onde termina a
## quadra, como o `Mapa` do minimapa e do pause: o mapa NAO PODE divergir do
## mundo, e os dois leem a mesma funcao. O que muda e so a tinta.
##
## Diferente do `Mapa`, este nao tem nevoa do que nao foi visitado. O jogo
## escondia as ruas do papel do pause porque aquele mapa e o que o personagem
## sabe; este e o do Google, que conhece a cidade inteira. O que continua
## escondido sao os LUGARES: alfinete so cai onde o jogador buscou.
##
## Desenho em duas camadas de coordenada: o chao (quadras e ruas) em METROS, por
## uma transformacao do canvas — a rua de 10 m fica com 10 m em qualquer zoom —;
## e o que e interface (nomes, alfinetes, a bolinha azul) em unidades da tela,
## com tamanho fixo.
class_name MapaDoIphone
extends RefCounted

const TAM := MalhaUrbana.TAM

enum Estilo { MAPA, SATELITE, HIBRIDO }

## Menor largura de uma rua na tela (unidades): longe, a rua de 6 m sumiria
## entre duas quadras.
const RUA_MIN := 1.1
const AVENIDA_MIN := 1.9
## Contorno das ruas (unidades, de cada lado).
const CONTORNO := 0.32
## Abaixo disto (metros por unidade) aparecem os predios na fita das quadras;
## acima, os nomes das ruas comuns somem e so as avenidas ficam.
const PREDIOS_ATE := 1.6
const NOMES_ATE := 2.6
const NOMES_AVENIDA_ATE := 6.0
## Tamanho da letra dos nomes de rua (unidades).
const LETRA := 4

# Paleta do Google de 2010.
const CHAO := Color("f1eee6")
const QUADRA := Color("ede9e0")
const PREDIO := Color("e2ddd2")
const PREDIO_LINHA := Color("d5cfc2")
const PARQUE := Color("c5dea0")
const PARQUE_CAMINHO := Color("e3ecd0")
const BALDIO := Color("e8e3d4")
const RUA := Color("ffffff")
const RUA_LINHA := Color("cdc6b8")
const AVENIDA := Color("fbe07c")
const AVENIDA_LINHA := Color("e0b150")
const NOME := Color("4d4a44")
const NOME_HALO := Color(1.0, 1.0, 1.0, 0.9)

# Satelite: a foto de cima, escura, com o telhado de cada quadra.
const SAT_CHAO := Color("3f4436")
const SAT_TELHADO := Color("6f6a5e")
const SAT_PARQUE := Color("3f5a2d")
const SAT_RUA := Color("4b4b49")
const SAT_BALDIO := Color("5a5645")

## Cores do transito: livre, lento, parado.
const TRANSITO := [Color("4bb543"), Color("f3c12e"), Color("d8352a")]

var centro := Vector2.ZERO
## Metros por unidade da tela.
var mpu: float = 2.0
## Giro do mapa (rad): o rumo de quem segura, no modo bussola.
var giro: float = 0.0
## Onde o mapa aparece, em unidades do app.
var area := Rect2(0.0, 0.0, 219.0, 146.0)
var estilo: Estilo = Estilo.MAPA
var transito: bool = false

var _cache_de := Rect2i()
var _quadras: Array[Dictionary] = []
var _vias: Array[Dictionary] = []
var _curvas: Array[Dictionary] = []
var _carros_t: float = 999.0
var _carga: Dictionary = {}


# --- coordenadas ------------------------------------------------------------------

## Do mundo (x, z) para a tela.
func xf() -> Transform2D:
	return Transform2D(giro, Vector2(1.0 / mpu, 1.0 / mpu), 0.0, area.get_center()) \
		* Transform2D(0.0, -centro)


func para_tela(mundo: Vector2) -> Vector2:
	return xf() * mundo


func para_mundo(tela: Vector2) -> Vector2:
	return xf().affine_inverse() * tela


## Um deslocamento na tela vira quanto o centro anda no mundo.
func arrastar(delta_tela: Vector2) -> void:
	centro -= delta_tela.rotated(-giro) * mpu


## Zoom em volta de um ponto da tela: o que esta sob o dedo fica sob o dedo.
func zoom_em(tela: Vector2, novo_mpu: float) -> void:
	var antes := para_mundo(tela)
	mpu = novo_mpu
	var depois := para_mundo(tela)
	centro += antes - depois


## O retangulo do mundo que a area mostra (com o giro, a caixa que o contem).
func visivel() -> Rect2:
	var inv := xf().affine_inverse()
	var r := Rect2(inv * area.position, Vector2.ZERO)
	for p: Vector2 in [Vector2(area.end.x, area.position.y), area.end,
			Vector2(area.position.x, area.end.y)]:
		r = r.expand(inv * p)
	return r


# --- cache ------------------------------------------------------------------------

## Le quadras e ruas do pedaco de cidade que cabe na tela, com um chunk de sobra.
## So refaz quando a vista sai do que ja foi lido.
func _ler(vis: Rect2) -> void:
	var c0 := Vector2i(floori(vis.position.x / TAM) - 1, floori(vis.position.y / TAM) - 1)
	var c1 := Vector2i(ceili(vis.end.x / TAM) + 1, ceili(vis.end.y / TAM) + 1)
	var pedido := Rect2i(c0, c1 - c0)
	if _cache_de.has_area() and _cache_de.encloses(pedido):
		return
	# Le com folga: arrastar um pouco nao pode reler a cidade a cada quadro.
	var folga := maxi(2, (c1.x - c0.x) / 3)
	c0 -= Vector2i(folga, folga)
	c1 += Vector2i(folga, folga)
	_cache_de = Rect2i(c0, c1 - c0)
	_quadras.clear()
	_vias.clear()
	_curvas.clear()
	var vistas := {}
	for cz in range(c0.y, c1.y):
		for cx in range(c0.x, c1.x):
			var q := MalhaUrbana.quadra_de(cx, cz)
			var id: Vector2i = q["id"]
			if vistas.has(id):
				continue
			vistas[id] = true
			var r := MalhaUrbana.retangulo_da_quadra(q)
			var d := {"r": r, "uso": int(q["uso"]), "h": int(q["semente"]), "caminhos": []}
			if int(q["uso"]) == MalhaUrbana.Uso.PARQUE:
				var plano := ParqueBuilder.planta(q)
				var origem := Vector2(float(q["x0"]) * TAM, float(q["z0"]) * TAM)
				var faixas: Array = []
				for f: Rect2 in ParqueBuilder.faixas_de_caminho(plano):
					faixas.append(Rect2(f.position + origem, f.size))
				d["caminhos"] = faixas
			_quadras.append(d)
			if bool(q.get("serpentina", false)):
				var ci := floori(float(q["x0"]) / float(MalhaUrbana.PERIODO))
				var cj := floori(float(q["z0"]) / float(MalhaUrbana.PERIODO))
				var s := Serpentina.dados(ci, cj)
				if not s.is_empty():
					_curvas.append({"pts": PackedVector2Array(s["caminho"]),
						"nome": NomesDeRua.nome_serpentina(ci, cj)})
	# As ruas: cada trecho de linha da grade que tem via.
	for i in range(c0.x, c1.x + 1):
		for j in range(c0.y, c1.y):
			var v := MalhaUrbana.via_x_em(i, j)
			if v != MalhaUrbana.Via.NENHUMA:
				_vias.append({"a": Vector2(float(i) * TAM, float(j) * TAM),
					"b": Vector2(float(i) * TAM, float(j + 1) * TAM), "via": v,
					"nome": NomesDeRua.nome_x(i, j), "linha": Vector2i(0, i), "passo": j})
	for j in range(c0.y, c1.y + 1):
		for i in range(c0.x, c1.x):
			var v := MalhaUrbana.via_z_em(j, i)
			if v != MalhaUrbana.Via.NENHUMA:
				_vias.append({"a": Vector2(float(i) * TAM, float(j) * TAM),
					"b": Vector2(float(i + 1) * TAM, float(j) * TAM), "via": v,
					"nome": NomesDeRua.nome_z(j, i), "linha": Vector2i(1, j), "passo": i})


## Quantos carros ha em cada trecho de rua, lido do `Transito` a cada segundo.
func _contar_carros(delta: float) -> void:
	_carros_t += delta
	if _carros_t < 1.0:
		return
	_carros_t = 0.0
	_carga.clear()
	var arvore := Engine.get_main_loop() as SceneTree
	var transito_no: Node = arvore.root.get_node_or_null(^"/root/Transito") if arvore != null else null
	if transito_no == null or not transito_no.has_method(&"lista"):
		return
	for c: Variant in transito_no.call(&"lista"):
		if not (c is Node3D) or not is_instance_valid(c):
			continue
		var p := (c as Node3D).global_position
		var i := roundi(p.x / TAM)
		var j := roundi(p.z / TAM)
		# O trecho mais perto: na linha x (perto de i*TAM) ou na linha z.
		var chave: String
		if absf(p.x - float(i) * TAM) < absf(p.z - float(j) * TAM):
			chave = "x%d_%d" % [i, floori(p.z / TAM)]
		else:
			chave = "z%d_%d" % [j, floori(p.x / TAM)]
		var vel := 0.0
		if c is RigidBody3D:
			vel = (c as RigidBody3D).linear_velocity.length()
		var atual: Vector2 = _carga.get(chave, Vector2.ZERO)
		_carga[chave] = atual + Vector2(1.0, vel)


func processar(delta: float) -> void:
	if transito:
		_contar_carros(delta)


# --- desenho ----------------------------------------------------------------------

func desenhar(ci: CanvasItem, fonte: Font, fonte_forte: Font) -> void:
	var vis := visivel()
	_ler(vis)
	var sat := estilo != Estilo.MAPA
	ci.draw_rect(area, SAT_CHAO if sat else CHAO)
	ci.draw_set_transform_matrix(xf())
	var larga := vis.grow(TAM)
	for q: Dictionary in _quadras:
		var r: Rect2 = q["r"]
		if not r.intersects(larga):
			continue
		_desenhar_quadra(ci, q, sat)
	_desenhar_ruas(ci, larga, sat)
	if transito:
		_desenhar_transito(ci, larga)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	if estilo != Estilo.SATELITE:
		_desenhar_nomes(ci, fonte, fonte_forte, sat)


func _desenhar_quadra(ci: CanvasItem, q: Dictionary, sat: bool) -> void:
	var r: Rect2 = q["r"]
	match int(q["uso"]):
		MalhaUrbana.Uso.PARQUE:
			ci.draw_rect(r, SAT_PARQUE if sat else PARQUE)
			for f: Rect2 in q["caminhos"]:
				ci.draw_rect(f, SAT_PARQUE.lightened(0.15) if sat else PARQUE_CAMINHO)
		MalhaUrbana.Uso.BALDIO:
			ci.draw_rect(r, SAT_BALDIO if sat else BALDIO)
		_:
			if sat:
				# Cada quadra com o seu telhado: variar a tinta por quadra e o que
				# faz a foto de cima ler como bairro, e nao como tabuleiro.
				var h := int(q["h"])
				var t := SAT_TELHADO.darkened(float(h % 7) * 0.035).lerp(Color("7b5e4a"),
					float((h / 7) % 5) * 0.08)
				ci.draw_rect(r, t)
				var fita := minf(ChunkBuilder.PROF_PREDIO, minf(r.size.x, r.size.y) * 0.5)
				ci.draw_rect(r.grow(-fita), SAT_CHAO.lightened(0.05))
				return
			ci.draw_rect(r, QUADRA)
			if mpu <= PREDIOS_ATE:
				# A fita de predios em volta da quadra, com o miolo vazio: e o
				# desenho de predio que o Google comecou a mostrar nas capitais.
				var fita := minf(ChunkBuilder.PROF_PREDIO, minf(r.size.x, r.size.y) * 0.5)
				var k := clampf((PREDIOS_ATE - mpu) / 0.4, 0.0, 1.0)
				var cor := Color(PREDIO, k)
				ci.draw_rect(Rect2(r.position, Vector2(r.size.x, fita)), cor)
				ci.draw_rect(Rect2(Vector2(r.position.x, r.end.y - fita), Vector2(r.size.x, fita)), cor)
				ci.draw_rect(Rect2(r.position + Vector2(0.0, fita), Vector2(fita, r.size.y - fita * 2.0)), cor)
				ci.draw_rect(Rect2(Vector2(r.end.x - fita, r.position.y + fita),
					Vector2(fita, r.size.y - fita * 2.0)), cor)
				ci.draw_rect(r, Color(PREDIO_LINHA, k), false, mpu * 0.35)


func _largura(v: int) -> float:
	var real := MalhaUrbana.meia_pista(v) * 2.0
	var minimo := (AVENIDA_MIN if v == MalhaUrbana.Via.AVENIDA else RUA_MIN) * mpu
	return maxf(real, minimo)


## Todos os contornos primeiro, depois todo o miolo: assim o cruzamento de duas
## ruas funde, em vez de uma riscar o contorno por cima da outra.
func _desenhar_ruas(ci: CanvasItem, larga: Rect2, sat: bool) -> void:
	var c := CONTORNO * mpu
	var visiveis: Array[Dictionary] = []
	for v: Dictionary in _vias:
		var a: Vector2 = v["a"]
		var b: Vector2 = v["b"]
		if larga.has_point(a) or larga.has_point(b):
			visiveis.append(v)
	if sat:
		for v: Dictionary in visiveis:
			_trecho(ci, v, _largura(int(v["via"])), SAT_RUA)
		if estilo == Estilo.HIBRIDO:
			for v: Dictionary in visiveis:
				if int(v["via"]) == MalhaUrbana.Via.AVENIDA:
					_trecho(ci, v, _largura(int(v["via"])) * 0.55, Color(AVENIDA, 0.55))
		for s: Dictionary in _curvas:
			ci.draw_polyline(s["pts"], SAT_RUA, Serpentina.MEIA_PISTA * 2.0, true)
		return
	for v: Dictionary in visiveis:
		var av := int(v["via"]) == MalhaUrbana.Via.AVENIDA
		_trecho(ci, v, _largura(int(v["via"])) + c * 2.0, AVENIDA_LINHA if av else RUA_LINHA)
	for s: Dictionary in _curvas:
		ci.draw_polyline(s["pts"], RUA_LINHA, maxf(Serpentina.MEIA_PISTA * 2.0, RUA_MIN * mpu) + c * 2.0, true)
	for v: Dictionary in visiveis:
		if int(v["via"]) != MalhaUrbana.Via.AVENIDA:
			_trecho(ci, v, _largura(int(v["via"])), RUA)
	for s: Dictionary in _curvas:
		ci.draw_polyline(s["pts"], RUA, maxf(Serpentina.MEIA_PISTA * 2.0, RUA_MIN * mpu), true)
	for v: Dictionary in visiveis:
		if int(v["via"]) == MalhaUrbana.Via.AVENIDA:
			_trecho(ci, v, _largura(int(v["via"])), AVENIDA)


## Um trecho reto, esticado meia largura nas pontas para fechar a esquina.
func _trecho(ci: CanvasItem, v: Dictionary, largura: float, cor: Color) -> void:
	var a: Vector2 = v["a"]
	var b: Vector2 = v["b"]
	var d := (b - a).normalized() * largura * 0.5
	var n := Vector2(-d.y, d.x)
	ci.draw_colored_polygon(PackedVector2Array([a - d + n, b + d + n, b + d - n, a - d - n]), cor)


## A camada de transito do Google: cada trecho com carro pintado de verde,
## amarelo ou vermelho pela velocidade de quem esta nele.
func _desenhar_transito(ci: CanvasItem, larga: Rect2) -> void:
	for v: Dictionary in _vias:
		var a: Vector2 = v["a"]
		if not larga.has_point(a):
			continue
		var linha: Vector2i = v["linha"]
		var chave := "%s%d_%d" % ["x" if linha.x == 0 else "z", linha.y, int(v["passo"])]
		if not _carga.has(chave):
			continue
		var carga: Vector2 = _carga[chave]
		var media := carga.y / maxf(carga.x, 1.0)
		var cor: Color = TRANSITO[0]
		if media < 2.0 or carga.x >= 4.0:
			cor = TRANSITO[2]
		elif media < 6.0 or carga.x >= 2.0:
			cor = TRANSITO[1]
		_trecho(ci, v, maxf(_largura(int(v["via"])) * 0.45, 1.0 * mpu), Color(cor, 0.9))


## Os nomes deitados ao longo das ruas, sempre de pe para quem le. Um por trecho
## longo o bastante, e a mesma rua nao repete o nome em trechos vizinhos.
func _desenhar_nomes(ci: CanvasItem, fonte: Font, forte: Font, sat: bool) -> void:
	if mpu > NOMES_AVENIDA_ATE:
		return
	var m := xf()
	var ja := {}
	var tinta := Color.WHITE if sat else NOME
	var halo := Color(0.0, 0.0, 0.0, 0.7) if sat else NOME_HALO
	for v: Dictionary in _vias:
		var nome := String(v["nome"])
		if nome.is_empty():
			continue
		var av := int(v["via"]) == MalhaUrbana.Via.AVENIDA
		if not av and mpu > NOMES_ATE:
			continue
		var linha: Vector2i = v["linha"]
		# Um nome a cada tres trechos da mesma linha: o bastante para achar a rua,
		# pouco para virar papel de parede.
		var passo := int(v["passo"])
		var grupo := "%d_%d_%d" % [linha.x, linha.y, floori(float(passo) / 3.0)]
		if ja.has(grupo):
			continue
		var a := m * (v["a"] as Vector2)
		var b := m * (v["b"] as Vector2)
		var meio := (a + b) * 0.5
		if not area.grow(-4.0).has_point(meio):
			continue
		var f := forte if av else fonte
		var tam := LETRA
		var texto := _curto(nome)
		var larg := f.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
		if larg > a.distance_to(b) * 0.92:
			continue
		ja[grupo] = true
		var ang := (b - a).angle()
		if ang > PI * 0.5:
			ang -= PI
		elif ang < -PI * 0.5:
			ang += PI
		ci.draw_set_transform(meio, ang, Vector2.ONE)
		var p := Vector2(-larg * 0.5, float(tam) * 0.36)
		ci.draw_string_outline(f, p, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, 2, halo)
		ci.draw_string(f, p, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, tinta)
	for s: Dictionary in _curvas:
		var pts: PackedVector2Array = s["pts"]
		if pts.size() < 2 or mpu > NOMES_ATE:
			continue
		var k := pts.size() / 2
		var a := m * pts[k - 1]
		var b := m * pts[k]
		var meio := (a + b) * 0.5
		if not area.grow(-4.0).has_point(meio):
			continue
		var ang := (b - a).angle()
		if ang > PI * 0.5:
			ang -= PI
		elif ang < -PI * 0.5:
			ang += PI
		var texto := _curto(String(s["nome"]))
		var larg := fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, LETRA).x
		ci.draw_set_transform(meio, ang, Vector2.ONE)
		ci.draw_string_outline(fonte, Vector2(-larg * 0.5, LETRA * 0.36), texto,
			HORIZONTAL_ALIGNMENT_LEFT, -1, LETRA, 2, halo)
		ci.draw_string(fonte, Vector2(-larg * 0.5, LETRA * 0.36), texto,
			HORIZONTAL_ALIGNMENT_LEFT, -1, LETRA, tinta)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## "AV. BRASIL" vira "Av. Brasil": o Google escreve em caixa baixa.
static func _curto(nome: String) -> String:
	var saida: PackedStringArray = []
	var pequenas := ["DA", "DE", "DO", "DAS", "DOS", "E"]
	var i := 0
	for p: String in nome.split(" ", false):
		if i > 0 and pequenas.has(p):
			saida.append(p.to_lower())
		else:
			saida.append(p.substr(0, 1) + p.substr(1).to_lower())
		i += 1
	return " ".join(saida)
