## Dano nos carros da rua (PLANO_CARROS_AAA, F8).
##
##     godot --headless --path game --script res://tests/bancada_dano.gd
##
##   D1  amassado de fabrica: a lataria montada com uma batida do lado +X afunda
##       pelo menos 1,5 cm daquele lado, e nada do lado -X. O de fabrica e leve
##       de proposito (forca 0,20 a 0,38, `Carro._amassados_de_fabrica`): a
##       0,35 a medida deu 1,9 cm, que ja muda a luz na chapa lisa
##   D2  o cache do casco nao sai amassado: o carro seguinte, liso, e identico
##       ao liso de antes, vertice a vertice
##   D3  o carro da rua que leva uma batida forte amassa (a malha dele muda) e
##       ganha a trinca no vidro do lado da pancada
##   D4  batida fraca nao trinca
extends SceneTree

var _passou := 0
var _total := 0


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	await process_frame
	var liso := Carroceria.montar(Carroceria.Modelo.SEDA, Carroceria.TINTAS[3], 11)
	var batido := Carroceria.montar(Carroceria.Modelo.SEDA, Carroceria.TINTAS[3], 11,
		true, true, [[Vector3(1.0, 0.0, 0.2), 0.35]])
	var v0: PackedVector3Array = (liso["corpo"] as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var v1: PackedVector3Array = (batido["corpo"] as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var maior_mais := 0.0
	var maior_menos := 0.0
	for k in mini(v0.size(), v1.size()):
		var d := v0[k].distance_to(v1[k])
		if v0[k].x > 0.2:
			maior_mais = maxf(maior_mais, d)
		elif v0[k].x < -0.2:
			maior_menos = maxf(maior_menos, d)
	_conta("D1 amassado de fabrica", maior_mais >= 0.015 and maior_menos < 0.001,
		"lado +X afundou %.3f m, lado -X %.4f m" % [maior_mais, maior_menos])

	var liso2 := Carroceria.montar(Carroceria.Modelo.SEDA, Carroceria.TINTAS[3], 11)
	var v2: PackedVector3Array = (liso2["corpo"] as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var diff := 0.0
	for k in mini(v0.size(), v2.size()):
		diff = maxf(diff, v0[k].distance_to(v2[k]))
	_conta("D2 cache intacto", diff < 1e-6 and v0.size() == v2.size(),
		"maior diferenca %.6f m" % diff)

	var script_carro := load("res://src/world/carro.gd") as GDScript
	var mundo := Node3D.new()
	root.add_child(mundo)
	var c: VehicleBody3D = script_carro.new()
	c.set(&"modelo", Carroceria.Modelo.SEDA)
	c.set(&"semente", 3)
	c.set(&"motorista", 0)
	mundo.add_child(c)
	await physics_frame
	var lataria: MeshInstance3D = c.get(&"_corpo_malha")
	var antes: PackedVector3Array = (lataria.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	c.call(&"levar_batida", c.global_position + c.global_transform.basis.x * 3.0, 0.9)
	var amassado: Amassado = c.get(&"_amassado")
	for _q in 120:
		await process_frame
		if not amassado.ocupado():
			break
	var depois: PackedVector3Array = (lataria.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var mexeu := 0.0
	for k in mini(antes.size(), depois.size()):
		mexeu = maxf(mexeu, antes[k].distance_to(depois[k]))
	if depois.size() != antes.size():
		mexeu = maxf(mexeu, 1.0)
	var trinca: Vector4 = c.get(&"_trinca")
	_conta("D3 batida no carro da rua", mexeu > 0.02 and trinca.w > 0.0 and trinca.x > 0.0,
		"malha mexeu %.3f m, trinca %s" % [mexeu, str(trinca)])

	var c2: VehicleBody3D = script_carro.new()
	c2.set(&"modelo", Carroceria.Modelo.HATCH)
	c2.set(&"semente", 4)
	c2.set(&"motorista", 0)
	mundo.add_child(c2)
	await physics_frame
	c2.call(&"levar_batida", c2.global_position - c2.global_transform.basis.z * 3.0, 0.3)
	var t2: Vector4 = c2.get(&"_trinca")
	_conta("D4 batida fraca nao trinca", t2.w == 0.0, "trinca %s" % str(t2))

	print("\n%d de %d criterios" % [_passou, _total])
	quit(0 if _passou == _total else 1)


func _conta(criterio: String, ok: bool, texto: String) -> void:
	_total += 1
	if ok:
		_passou += 1
	print("%s %s: %s" % ["[ok]" if ok else "[X ]", criterio, texto])
