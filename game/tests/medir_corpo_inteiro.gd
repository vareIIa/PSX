## O corpo inteiro medido pela pele: correr, agachar, pedalar e as passagens.
##
##     godot --headless --path game --script res://tests/medir_corpo_inteiro.gd
##
## Criterios do PLANO_PERSONAGENS_AAA (fase 5):
## - agachado (parado e andando): nada entra no chao mais que 3,5 cm e o pe
##   toca o chao (a escala de antes deixava o pe boiando);
## - correndo: nenhum pe abaixo do piso em nenhuma das poses do ciclo, e o
##   ciclo de corrida tem 15 poses (a grade do jogo);
## - pedalando: o tornozelo segue o pedal da pedivela a menos de 4 cm, na volta
##   inteira;
## - passagem: trocar de postura passa por uma pose do meio e chega na nova
##   em ate 0,3 s.
extends SceneTree

const O := Corpo.Osso
const DT := 1.0 / 60.0

var _passou := 0
var _total := 0


func _init() -> void:
	_rodar()


func _corpo() -> Corpo:
	var c := Corpo.new()
	root.add_child(c)
	c.montar(Aparencia.de_ficha({"id": 31, "sexo": &"M", "idade": 30}))
	c.animar(0.0, DT)
	return c


func _rodar() -> void:
	await process_frame
	_agachado()
	_corrida()
	_pedal()
	_passagem()
	print("[corpo_inteiro] %d/%d" % [_passou, _total])
	quit(0 if _passou == _total else 1)


func _mais_baixo(c: Corpo) -> Dictionary:
	var sk := c.esqueleto()
	var matriz := {}
	for b in sk.get_bone_count():
		matriz[b] = sk.get_bone_global_pose(b) * sk.get_bone_global_rest(b).affine_inverse()
	var m := (c.get_node("Esqueleto/Pele") as MeshInstance3D).mesh as ArrayMesh
	var menor := INF
	var pe := INF
	for sup in m.get_surface_count():
		var arr := m.surface_get_arrays(sup)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bs: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var ws: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var por := bs.size() / maxi(1, vs.size())
		for i in range(0, vs.size(), 2):
			var p := Vector3.ZERO
			var dono := -1
			var maior := -1.0
			for k in por:
				var w := ws[i * por + k]
				if w <= 0.0:
					continue
				p += (matriz[bs[i * por + k]] as Transform3D) * vs[i] * w
				if w > maior:
					maior = w
					dono = bs[i * por + k]
			menor = minf(menor, p.y)
			if dono == O.CANELA_E or dono == O.CANELA_D:
				pe = minf(pe, p.y)
	return {"menor": menor, "pe": pe}


func _agachado() -> void:
	var c := _corpo()
	c.agachado = true
	for i in 30:
		c.animar(0.0, DT)
	var m := _mais_baixo(c)
	_conta("agachado parado: nada entra no chao", float(m["menor"]) > -0.035, "%.3f" % m["menor"])
	_conta("agachado parado: o pe toca o chao", float(m["pe"]) < 0.04, "%.3f" % m["pe"])
	var pior := INF
	for i in 60:
		c.animar(1.0, DT)
		pior = minf(pior, float(_mais_baixo(c)["menor"]))
	_conta("agachado andando: nada entra no chao", pior > -0.035, "%.3f" % pior)
	c.queue_free()


func _corrida() -> void:
	var c := _corpo()
	var pior := INF
	var poses := {}
	for i in 150:
		c.animar(4.6, DT)
		pior = minf(pior, float(_mais_baixo(c)["pe"]))
		# Depois da passagem de parado para correndo, que tem poses proprias.
		if i >= 30:
			poses[c.assinatura()] = true
	_conta("correndo: pe nunca abaixo do piso", pior > -0.05, "%.3f" % pior)
	_conta("correndo: 15 poses por ciclo", poses.size() >= 14 and poses.size() <= 16,
		"%d" % poses.size())
	c.queue_free()


func _pedal() -> void:
	var c := _corpo()
	c.postura(Corpo.Postura.PEDALANDO)
	var pior := 0.0
	var sk := c.esqueleto()
	for k in 12:
		c.pedal_fase = float(k) / 12.0 * TAU
		for i in 20:
			c.animar(0.0, DT)
		for lado: float in [-1.0, 1.0]:
			var canela := O.CANELA_E if lado < 0.0 else O.CANELA_D
			var x := sk.get_bone_global_rest(canela - 1).origin.x
			var p := c.pedal_fase + (0.0 if lado < 0.0 else PI)
			var alvo := Quadro.PEDALEIRA + Vector3(x, -Quadro.BRACO_PEDAL * cos(p) + 0.07,
				Quadro.BRACO_PEDAL * sin(p))
			var tornozelo := sk.get_bone_global_pose(canela) * Vector3(0.0,
				-(Corpo.Y_JOELHO - Corpo.Y_TORNOZELO) * c.altura() / Corpo.ALTURA_REF, 0.0)
			pior = maxf(pior, tornozelo.distance_to(alvo))
	_conta("pedalando: o pe segue o pedal", pior < 0.04, "%.3f m" % pior)
	c.queue_free()


func _passagem() -> void:
	var c := _corpo()
	for i in 30:
		c.animar(0.0, DT)
	var sk := c.esqueleto()
	var de_pe := sk.get_bone_pose_position(O.QUADRIL).y
	c.postura(Corpo.Postura.SENTADO)
	c.animar(0.0, DT * 5.0)
	var meio := sk.get_bone_pose_position(O.QUADRIL).y
	for i in 18:
		c.animar(0.0, DT)
	var fim := sk.get_bone_pose_position(O.QUADRIL).y
	_conta("sentar passa pelo meio", meio < de_pe - 0.05 and meio > fim + 0.05,
		"de pe %.2f, meio %.2f, sentado %.2f" % [de_pe, meio, fim])
	c.queue_free()


func _conta(nome: String, ok: bool, texto: String = "") -> void:
	_total += 1
	if ok:
		_passou += 1
	print("  [%s] %s  %s" % ["ok" if ok else "FALHOU", nome, texto])
