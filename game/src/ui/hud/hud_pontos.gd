## Pontos de interacao: um pontinho sobre o que da para acionar perto.
##
## O prompt so aparece quando o raio da camera ja esta EM CIMA da coisa — o
## jogador precisava saber que a geladeira abria para mira-la. The Last of Us e
## RE resolvem com um ponto discreto sobre cada coisa acionavel perto, que
## cresce quando ela vira o alvo. E o convite; o prompt e a resposta.
##
## O que entra
## -----------
## Todo `Interativo` habilitado a ate `RAIO` m, visivel da camera (um raio contra
## a camada do mundo: porta atras da parede nao ganha ponto), na frente dela.
## Ficam de fora carro e pedestre — a rua tem dezenas, e o convite do carro ja
## e o prompt de chegar perto — e a face de prateleira do mercado, que sao
## centenas lado a lado. No maximo `MAXIMO`, os mais perto.
##
## Custo: uma consulta de esfera e ate `MAXIMO` raios a cada `INTERVALO`; o
## desenho so projeta e anima.
class_name HudPontos
extends Control

const RAIO := 6.5
const MAXIMO := 8
const INTERVALO := 0.15
## Alfa cheio ate aqui; some ate `RAIO`.
const CHEIO := 3.0
const T_FADE := 0.18
## Quanto o ponto sobe numa pessoa, do meio da forma ao peito.
const PEITO := 0.5

## Escala do HUD (posta pelo `HudAAA`): o ponto cresce com o resto.
var escala := 1.0

var _desde := 99.0
var _t := 0.0
## instance_id -> {no, alfa, quer, alvo}
var _pontos: Dictionary = {}
var _consulta: PhysicsShapeQueryParameters3D
var _raio: PhysicsRayQueryParameters3D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var esfera := SphereShape3D.new()
	esfera.radius = RAIO
	_consulta = PhysicsShapeQueryParameters3D.new()
	_consulta.shape = esfera
	_consulta.collision_mask = Interativo.CAMADA
	_consulta.collide_with_areas = true
	_consulta.collide_with_bodies = false
	_raio = PhysicsRayQueryParameters3D.new()
	_raio.collision_mask = 1
	_raio.collide_with_areas = false


func _process(delta: float) -> void:
	_t += delta
	_desde += delta
	var jogador := get_tree().get_first_node_in_group(&"player") as Player
	var ligado := HudConfig.ver_pontos() and jogador != null and not jogador.dirigindo() \
		and not jogador.travado
	if ligado and _desde >= INTERVALO:
		_desde = 0.0
		_colher(jogador)
	elif not ligado:
		for id: int in _pontos:
			(_pontos[id] as Dictionary)["quer"] = 0.0
	var alvo: Interativo = jogador.alvo_atual() if jogador != null else null
	for id: int in _pontos.keys():
		var p: Dictionary = _pontos[id]
		if not is_instance_valid(p["no"]):
			_pontos.erase(id)
			continue
		p["alvo"] = alvo != null and p["no"] == alvo
		p["alfa"] = move_toward(float(p["alfa"]), float(p["quer"]), delta / T_FADE)
		if float(p["alfa"]) <= 0.0 and float(p["quer"]) <= 0.0:
			_pontos.erase(id)
	queue_redraw()


func _colher(jogador: Player) -> void:
	var mundo := jogador.get_world_3d()
	var cam := get_viewport().get_camera_3d()
	if mundo == null or cam == null:
		return
	var espaco := mundo.direct_space_state
	_consulta.transform = Transform3D(Basis(), jogador.global_position)
	var achados: Array[Dictionary] = []
	for hit: Dictionary in espaco.intersect_shape(_consulta, 48):
		var no := hit.get("collider") as Interativo
		if no == null or not no.habilitado or not no.is_visible_in_tree():
			continue
		if HudPontos.fica_de_fora(no):
			continue
		var pos := HudPontos.centro_de(no)
		var dist := pos.distance_to(jogador.global_position)
		if dist > RAIO:
			continue
		achados.append({"no": no, "pos": pos, "dist": dist})
	achados.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["dist"]) < float(b["dist"]))
	var vistos := {}
	for a: Dictionary in achados.slice(0, MAXIMO):
		var pos: Vector3 = a["pos"]
		if Suavidade.atras(cam, pos):
			continue
		# Parede entre a lente e o ponto: sem ponto. O raio para um palmo antes,
		# para a propria moldura da porta nao contar como parede.
		var de := cam.global_position
		_raio.from = de
		_raio.to = de + (pos - de) * maxf(0.0, 1.0 - 0.35 / maxf(0.35, de.distance_to(pos)))
		_raio.exclude = [jogador.get_rid()]
		if not espaco.intersect_ray(_raio).is_empty():
			continue
		var no: Interativo = a["no"]
		var id := no.get_instance_id()
		var quer := clampf((RAIO - float(a["dist"])) / (RAIO - CHEIO), 0.0, 1.0)
		if _pontos.has(id):
			(_pontos[id] as Dictionary)["quer"] = quer
		else:
			_pontos[id] = {"no": no, "alfa": 0.0, "quer": quer, "alvo": false}
		vistos[id] = true
	for id: int in _pontos:
		if not vistos.has(id):
			(_pontos[id] as Dictionary)["quer"] = 0.0


## Carro e pedestre acionam por um `Gatilho` filho, e nao herdam de
## `Interativo`: quem decide e o dono. Face de prateleira e ela mesma.
static func fica_de_fora(no: Interativo) -> bool:
	if no is FaceDePrateleira:
		return true
	var pai := no.get_parent()
	return pai is Carro or pai is Pedestre


## Onde o ponto fica: o meio da forma de colisao da area, que e onde o objeto e
## acionado (a area da porta fica um palmo a frente dela, na altura da macaneta).
##
## Em gente o meio da forma e a cintura: o ponto sobe para o peito, onde o olho
## procura quem fala.
static func centro_de(no: Interativo) -> Vector3:
	var gente := no is Npc or no.get_parent() is Convidado
	var subir := Vector3(0.0, PEITO, 0.0) if gente else Vector3.ZERO
	for filho: Node in no.get_children():
		var forma := filho as CollisionShape3D
		if forma != null:
			return forma.global_position + subir
	return no.global_position + subir


func _draw() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _pontos.is_empty():
		return
	var tela := get_viewport().get_visible_rect().size
	var pulso := 0.5 + 0.5 * sin(_t * 3.0)
	for id: int in _pontos:
		var p: Dictionary = _pontos[id]
		var al := HudTema.saida_cubica(float(p["alfa"]))
		if al <= 0.0 or not is_instance_valid(p["no"]):
			continue
		var pos := HudPontos.centro_de(p["no"])
		# Pela lente interpolada (`Suavidade`), a mesma que desenhou o quadro.
		if Suavidade.atras(cam, pos):
			continue
		var s := Suavidade.projetar(cam, pos) * HudTema.TELA / tela
		draw_set_transform(s, 0.0, Vector2(escala, escala))
		if bool(p["alvo"]):
			# O alvo: anel de destaque em volta do ponto. O prompt diz o resto.
			draw_circle(Vector2.ZERO, 4.6, Color(0.0, 0.0, 0.0, 0.35 * al), true, -1.0, true)
			draw_arc(Vector2.ZERO, 3.9 + pulso * 0.4, 0.0, TAU, 28,
				HudTema.alfa(HudTema.acento(), al), 0.9, true)
			draw_circle(Vector2.ZERO, 1.5, HudTema.alfa(HudTema.TEXTO, al), true, -1.0, true)
		else:
			draw_circle(Vector2.ZERO, 2.1, Color(0.0, 0.0, 0.0, 0.55 * al), true, -1.0, true)
			draw_circle(Vector2.ZERO, 1.35, HudTema.alfa(HudTema.TEXTO, 0.9 * al), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)
