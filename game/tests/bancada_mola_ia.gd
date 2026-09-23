## A carroceria do carro da IA sobre molas (PLANO_CARROS_AAA, F10).
##
##     godot --headless --path game --script res://tests/bancada_mola_ia.gd
##
## O carro da rua e cinematico; a mola e visual e mora em `Carro._balancar`.
## Aqui ela e alimentada com os tres movimentos que a rua produz, sem rua:
##
##   M1  freada de 50 a 0 km/h a 8 m/s2: o BICO desce (a frente da lataria fica
##       mais baixa que a traseira), entre 1 e 3 graus
##   M2  parado depois da freada: o balanco de volta existe (passa do zero) e
##       assenta em ate 2 s
##   M3  arrancada: a traseira senta (o bico sobe)
##   M4  curva a esquerda a 8 m/s: o lado de FORA (direito, +X) desce
##   M5  as rodas nao se mexem: so a lataria balanca
##   M6  assumir o volante devolve a lataria ao chassi
extends SceneTree

const PASSO := 1.0 / 60.0

var _passou := 0
var _total := 0


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	await process_frame
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
	var comp := float((c.get(&"_medidas") as Dictionary)["comprimento"])
	var larg := float((c.get(&"_medidas") as Dictionary)["largura"])
	var roda := c.get(&"_eixo_tras") as Node3D
	var roda_antes := roda.transform

	# M1: freada.
	var v := 14.0
	var pior := 0.0
	c.set(&"_giro", 0.0)
	while v > 0.0:
		v = maxf(0.0, v - 8.0 * PASSO)
		c.set(&"_velocidade", v)
		c.call(&"_balancar", PASSO)
		pior = minf(pior, _arfar(lataria, comp))
	_conta("M1 bico desce", pior < -1.0 and pior > -3.0, "arfar minimo %.2f graus" % pior)

	# M2: balanco de volta e assentar.
	var passou_do_zero := false
	var assentou := 0.0
	for q in int(3.0 / PASSO):
		c.call(&"_balancar", PASSO)
		var a := _arfar(lataria, comp)
		if a > 0.05:
			passou_do_zero = true
		if absf(a) > 0.1:
			assentou = float(q) * PASSO
	_conta("M2 balanco de volta", passou_do_zero and assentou < 2.0,
		"passou do zero: %s, assentou em %.2f s" % [passou_do_zero, assentou])

	# M3: arrancada.
	var maior := 0.0
	for q in int(2.0 / PASSO):
		v = minf(12.0, v + 4.2 * PASSO)
		c.set(&"_velocidade", v)
		c.call(&"_balancar", PASSO)
		maior = maxf(maior, _arfar(lataria, comp))
	_conta("M3 traseira senta", maior > 0.4, "arfar maximo %.2f graus" % maior)

	# M4: curva a esquerda (o giro cresce).
	c.set(&"_velocidade", 8.0)
	var giro := 0.0
	var rolar := 0.0
	for q in int(2.0 / PASSO):
		giro += 0.6 * PASSO
		c.set(&"_giro", giro)
		c.call(&"_balancar", PASSO)
		rolar = _rolar(lataria, larg)
	_conta("M4 fora desce", rolar > 0.5 and rolar < 4.5,
		"lado esquerdo %.2f graus acima do direito" % rolar)

	# M5: rodas paradas.
	_conta("M5 rodas no chassi", roda.transform.is_equal_approx(roda_antes),
		"eixo traseiro %s" % str(roda.transform.origin))

	# M6: assumir devolve.
	c.set(&"ligado", true)
	c.call(&"assumir", Node3D.new())
	_conta("M6 assumir zera", lataria.transform.is_equal_approx(Transform3D.IDENTITY),
		"lataria %s" % str(lataria.transform.origin))

	print("\n%d de %d criterios" % [_passou, _total])
	quit(0 if _passou == _total else 1)


## Arfar da lataria em graus, pela altura do bico menos a da traseira. Positivo:
## bico acima.
static func _arfar(l: MeshInstance3D, comp: float) -> float:
	var frente := l.transform * Vector3(0.0, 0.5, -comp * 0.5)
	var tras := l.transform * Vector3(0.0, 0.5, comp * 0.5)
	return rad_to_deg(atan2(frente.y - tras.y, comp))


## Rolar em graus: o lado esquerdo (-X) acima do direito e positivo.
static func _rolar(l: MeshInstance3D, larg: float) -> float:
	var esq := l.transform * Vector3(-larg * 0.5, 0.5, 0.0)
	var dir := l.transform * Vector3(larg * 0.5, 0.5, 0.0)
	return rad_to_deg(atan2(esq.y - dir.y, larg))


func _conta(criterio: String, ok: bool, texto: String) -> void:
	_total += 1
	if ok:
		_passou += 1
	print("%s %s: %s" % ["[ok]" if ok else "[X ]", criterio, texto])
