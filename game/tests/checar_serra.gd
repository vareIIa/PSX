## A serra do horizonte (SerraDaCidade): a forma e as luzes.
##
##     godot --headless --path game --script res://tests/checar_serra.gd
##
## O que ele prova
## ---------------
##   emenda     o recorte de cada crista da a volta sem degrau (0 e TAU)
##   forma      cada crista de morro tem morro de verdade: o recorte varia (nao e
##              faixa reta) e fica dentro de [0, 1,7] da elevacao
##   pico       a torre fica no ponto mais alto da serra de tras
##   raio       o anel mora antes das estrelas (320 m) e alem da cidade (~215 m)
##   luzes      nenhuma luz de sitio flutua no ceu: todas abaixo do cume da crista
##              em que estao; a estrada dos carros abaixo do morro mais baixo do
##              trecho
##
## Sai com 1 se algum criterio falhar.
extends SceneTree

var _falhas: PackedStringArray = []
var _total := 0


func _initialize() -> void:
	_rodar.call_deferred()


func _afirmar(msg: String, cond: bool) -> void:
	_total += 1
	if not cond:
		_falhas.append(msg)


func _rodar() -> void:
	# Por carga tardia: pelo nome, a classe puxa autoload antes de existir.
	var S: GDScript = load("res://src/world/serra_da_cidade.gd")
	var raios: Array = S.RAIOS
	var elev: Array = S.ELEVACAO
	for crista in raios.size():
		var a := float(S.perfil(0.0, crista))
		var b := float(S.perfil(TAU - 0.0001, crista))
		_afirmar("crista %d: emenda sem degrau (%.3f / %.3f)" % [crista, a, b],
			absf(a - b) < 0.01)
		var menor := INF
		var maior := -INF
		for k in 720:
			var h := float(S.perfil(TAU * k / 720.0, crista))
			menor = minf(menor, h)
			maior = maxf(maior, h)
		_afirmar("crista %d: recorte dentro da faixa (%.2f..%.2f)" % [crista, menor, maior],
			menor >= 0.0 and maior <= 1.7)
		_afirmar("crista %d: recorte de morro, nao faixa (amplitude %.2f)" % [crista,
			maior - menor], maior - menor > 0.4)
	var pico := float(S.angulo_da_torre())
	var topo := float(S.perfil(pico, raios.size() - 1))
	var acima := 0
	for k in 3600:
		if float(S.perfil(TAU * k / 3600.0, raios.size() - 1)) > topo + 0.005:
			acima += 1
	_afirmar("a torre fica no ponto mais alto da serra de tras (%d amostras acima)" % acima,
		acima == 0)
	_afirmar("anel antes das estrelas e alem da cidade (%.0f..%.0f m)" % [raios[0], raios[-1]],
		float(raios[0]) > 230.0 and float(raios[-1]) < 318.0)

	# As luzes: monta a malha como o jogo monta e confere cada quad.
	var serra: MeshInstance3D = S.new()
	var malha: ArrayMesh = serra._montar_luzes()
	var arr := malha.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var no_ceu := 0
	var sitios := 0
	var carro_alto := 0
	for q in range(0, v.size(), 6):
		var tipo := uv[q].x
		var centro := Vector3.ZERO
		for k in 6:
			centro += v[q + k] / 6.0
		var ang := atan2(centro.x, centro.z)
		var r := Vector2(centro.x, centro.z).length()
		if tipo == 1.0:
			sitios += 1
			# A crista da luz e a de raio logo acima do dela.
			var crista := 0
			for c in raios.size():
				if r < float(raios[c]):
					crista = c
					break
			var cume := float(S.perfil(ang, crista)) * tan(deg_to_rad(float(elev[crista]))) \
				* float(raios[crista])
			if centro.y > cume:
				no_ceu += 1
		elif tipo == 3.0:
			# O farol gira pelo trecho: confere o morro mais baixo dele.
			var meio := deg_to_rad(float(S.ESTRADA.x))
			var largo := deg_to_rad(float(S.ESTRADA.y))
			var baixo := INF
			for k in 48:
				baixo = minf(baixo, float(S.perfil(meio + largo * (k / 47.0 - 0.5), 1)))
			if centro.y > baixo * tan(deg_to_rad(float(elev[1]))) * float(raios[1]):
				carro_alto += 1
	serra.free()
	print("-- %d luzes de sitio, %d no ceu; %d farois acima do morro" % [sitios, no_ceu, carro_alto])
	_afirmar("ha luz de sitio (%d)" % sitios, sitios > 100)
	_afirmar("nenhuma luz de sitio no ceu (%d)" % no_ceu, no_ceu == 0)
	_afirmar("farol abaixo do morro do trecho (%d)" % carro_alto, carro_alto == 0)

	print("")
	if _falhas.is_empty():
		print("OK — %d assercoes" % _total)
		quit(0)
		return
	print("FALHOU — %d de %d assercoes" % [_falhas.size(), _total])
	for f: String in _falhas:
		print("  x %s" % f)
	quit(1)
