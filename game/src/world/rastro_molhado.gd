## O caminho que o pneu abre na lamina d'agua: a parte "rastro" do criterio A19
## do PLANO_AAA_4K.
##
## Nao e a marca de borracha (`RastroPneu`), que e derrapagem. Aqui o carro anda
## reto e devagar e, mesmo assim, o pneu espreme a agua para os lados: no rastro
## a lamina fica fina e o asfalto volta a ser asfalto — fosco, sem o reflexo do
## poste — por um ou dois segundos, ate a chuva encher de novo.
##
## Por isso e um `Decal` com mapa de rugosidade, e nao uma faixa escura: o que
## muda no rastro e o REFLEXO. O decal escreve a rugosidade antes do reflexo de
## tela ler, entao o poste some de dentro do rastro e continua fora dele. A borda
## do rastro vai para o outro lado (mais lisa): e para la que a agua foi.
##
## Um pool pequeno por roda de tras, reapontado em pedacos cujo comprimento
## cresce com a velocidade, e desbotando com a idade. Quem cria e o
## `DiretorChuvaFora`, so no MODERNO.
class_name RastroMolhado
extends Node3D

const POR_TRILHA := 6
## Comprimento de cada pedaco: 1,2 m devagar, ate 3,2 m correndo.
const PASSO_MIN := 1.2
const PASSO_MAX := 3.2
const PASSO_POR_MS := 0.28
## Segundos ate a chuva fechar o rastro.
const VIDA := 2.4
## Largura da banda de rodagem, com a borda de agua.
const LARGURA := 0.26
const MOLHADO_MINIMO := 0.3
const VEL_MINIMA := 0.8
## Longe da camera o rastro nao se ve, e o decal nao se paga.
const ALCANCE := 40.0

static var _cor: Texture2D
static var _orm: Texture2D

var _carro: Node3D
var _rodas: Array[VehicleWheel3D] = []
var _trilhas: Array[Dictionary] = []
var _carimbos := 0


func acompanhar(c: Node3D, rodas: Array[VehicleWheel3D]) -> void:
	name = "RastroMolhado"
	top_level = true
	_carro = c
	_rodas = rodas
	_texturas()
	for _k in _rodas.size():
		var decals: Array[Decal] = []
		for i in POR_TRILHA:
			var d := Decal.new()
			d.visible = false
			d.texture_albedo = _cor
			d.texture_orm = _orm
			# Cor nenhuma: o rastro e rugosidade, nao tinta. Com 0,22 de um
			# cinza medio, o rastro saia MAIS CLARO que a rua molhada — uma faixa
			# pintada, e nao um caminho aberto na agua.
			d.albedo_mix = 0.0
			# A roda passa por dentro da caixa logo depois do carimbo; o que nao
			# olha para cima (o pneu, o para-choque) fica de fora.
			d.normal_fade = 0.5
			d.upper_fade = 0.3
			d.lower_fade = 0.3
			d.distance_fade_enabled = true
			d.distance_fade_begin = ALCANCE * 0.75
			d.distance_fade_length = ALCANCE * 0.25
			add_child(d)
			decals.append(d)
		# Array empacotado e valor: preparado antes de entrar no dicionario.
		var idades := PackedFloat32Array()
		idades.resize(POR_TRILHA)
		idades.fill(VIDA)
		_trilhas.append({
			"decals": decals,
			"idade": idades,
			"proximo": 0,
			"ultimo": Vector3.ZERO,
			"tem": false,
		})


func _physics_process(delta: float) -> void:
	if _carro == null or not is_instance_valid(_carro):
		return
	for t: Dictionary in _trilhas:
		var idades: PackedFloat32Array = t["idade"]
		var decals: Array[Decal] = t["decals"]
		for i in POR_TRILHA:
			if idades[i] >= VIDA:
				continue
			idades[i] += delta
			var d := decals[i]
			if idades[i] >= VIDA:
				d.visible = false
			else:
				d.modulate.a = 1.0 - idades[i] / VIDA
		t["idade"] = idades

	var molhado: float = Clima.molhado_visivel()
	var vel := absf(float(_carro.call(&"velocidade"))) if _carro.has_method(&"velocidade") else 0.0
	var camera := get_viewport().get_camera_3d()
	var perto := camera != null \
		and camera.global_position.distance_to(_carro.global_position) <= ALCANCE
	var anda := molhado >= MOLHADO_MINIMO and vel >= VEL_MINIMA and perto
	var passo := clampf(vel * PASSO_POR_MS, PASSO_MIN, PASSO_MAX)
	for k in _rodas.size():
		var roda := _rodas[k]
		var t := _trilhas[k]
		if not anda or not is_instance_valid(roda):
			t["tem"] = false
			continue
		var p := roda.global_position - _carro.global_basis.y * roda.wheel_radius
		if bool(t["tem"]) and p.distance_to(t["ultimo"]) < passo:
			continue
		# O chao, por raio, so na hora do carimbo: dois raios por pedaco. Da o
		# ponto e a normal de verdade, e dispensa o contato da `VehicleWheel3D`,
		# que so existe com a fisica do carro rodando.
		var chao := _chao(roda.global_position, roda.wheel_radius)
		if chao.is_empty():
			t["tem"] = false
			continue
		var onde: Vector3 = chao["position"]
		if bool(t["tem"]):
			_carimbar(t, t["ultimo"], onde, chao["normal"])
		t["ultimo"] = onde
		t["tem"] = true


func _chao(centro: Vector3, raio: float) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(centro, centro + Vector3.DOWN * (raio + 0.3), 1)
	if _carro is CollisionObject3D:
		q.exclude = [(_carro as CollisionObject3D).get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q)


func _carimbar(t: Dictionary, de: Vector3, ate: Vector3, cima: Vector3) -> void:
	var i: int = t["proximo"]
	t["proximo"] = (i + 1) % POR_TRILHA
	var d: Decal = (t["decals"] as Array[Decal])[i]
	var ao_longo := ate - de
	ao_longo -= cima * ao_longo.dot(cima)
	var comprimento := ao_longo.length()
	if comprimento < 0.01:
		return
	var z := ao_longo / comprimento
	var x := cima.cross(z).normalized()
	d.global_transform = Transform3D(Basis(x, cima, z), (de + ate) * 0.5 + cima * 0.04)
	# Sobra de 12 cm: o pedaco cobre a ponta desbotada do anterior. Sem ela a
	# emenda era um risco claro atravessando o rastro; com 30 cm, a faixa
	# coberta duas vezes saia mais fosca, e o risco ficava escuro.
	d.size = Vector3(LARGURA, 0.34, comprimento + 0.12)
	d.modulate.a = 1.0
	d.visible = true
	var idades: PackedFloat32Array = t["idade"]
	idades[i] = 0.0
	t["idade"] = idades
	_carimbos += 1


## Quantos pedacos ja foram carimbados. Para bancada.
func carimbos() -> int:
	return _carimbos


## Quantos pedacos estao visiveis agora.
func visiveis() -> int:
	var n := 0
	for t: Dictionary in _trilhas:
		for d: Decal in t["decals"]:
			if d.visible:
				n += 1
	return n


## Cor com mascara, e rugosidade com desenho de banda de rodagem.
##
## Pequenas e feitas uma vez por sessao, em memoria: 32 x 128 px.
static func _texturas() -> void:
	if _cor != null:
		return
	const L := 32
	const A := 128
	var cor := Image.create(L, A, false, Image.FORMAT_RGBA8)
	var orm := Image.create(L, A, false, Image.FORMAT_RGBA8)
	for y in A:
		# Ponta do pedaco some devagar: um pedaco encosta no seguinte sem
		# costura dura.
		var ponta := smoothstep(0.0, 2.0, float(y)) * smoothstep(0.0, 2.0, float(A - 1 - y))
		# Sulco transversal, fraco: com contraste cheio ele virava uma escada
		# desenhada no meio do reflexo.
		var sulco := 0.5 + 0.5 * sin(float(y) * 0.9)
		for x in L:
			var u := (float(x) + 0.5) / float(L) * 2.0 - 1.0
			var miolo := 1.0 - smoothstep(0.55, 0.78, absf(u))
			var borda := smoothstep(0.62, 0.8, absf(u)) * (1.0 - smoothstep(0.9, 1.0, absf(u)))
			var alfa := clampf(miolo + borda * 0.3, 0.0, 1.0) * ponta
			cor.set_pixel(x, y, Color(0.1, 0.1, 0.1, alfa))
			# Miolo quase fosco (a agua saiu), sulco um pouco menos (guarda
			# agua), borda lisa (a agua foi para la). Medido na bancada: com o
			# miolo em 0,72 o poste ainda acendia o rastro inteiro de lado a
			# lado, porque a GGX larga rente ao chao ainda devolve muito.
			var rug := lerpf(0.95, 0.86, sulco) if miolo > 0.5 else 0.1
			orm.set_pixel(x, y, Color(1.0, rug, 0.0, 1.0))
	cor.generate_mipmaps()
	orm.generate_mipmaps()
	_cor = ImageTexture.create_from_image(cor)
	_orm = ImageTexture.create_from_image(orm)
