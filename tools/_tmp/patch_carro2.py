from pathlib import Path
src = Path(r"game/src/world/carro_cena.gd")
t = src.read_text(encoding="utf-8")

a = '''func _ready() -> void:
	_medidas = Carroceria.montar(Carroceria.Modelo.SEDA, TINTA, SEMENTE)
	_montar_lataria()
	_montar_eixos()
	_montar_cabine()
	_montar_som()
	assentar()'''
b = '''func _ready() -> void:
	_medidas = Carroceria.montar(MODELO, TINTA, SEMENTE)
	_montar_lataria()
	_montar_eixos()
	_montar_cabine()
	_montar_farois()
	_montar_som()
	assentar()'''
if a not in t: raise SystemExit("ready missing")
t = t.replace(a,b,1)

a = '''func _montar_cabine() -> void:
	cabine = CarroCabine.new()
	cabine.name = "Cabine"
	add_child(cabine)
	cabine.montar(_medidas)

	suporte_camera = Node3D.new()
	suporte_camera.name = "Olho"
	suporte_camera.position = cabine.olho()
	add_child(suporte_camera)


func _montar_som() -> void:'''
b = '''func _montar_cabine() -> void:
	cabine = CarroCabine.new()
	cabine.name = "Cabine"
	add_child(cabine)
	cabine.montar(_medidas)

	suporte_camera = Node3D.new()
	suporte_camera.name = "Olho"
	suporte_camera.position = cabine.olho()
	add_child(suporte_camera)

	suporte_chase = Node3D.new()
	suporte_chase.name = "Chase"
	var comp := float(_medidas["comprimento"])
	suporte_chase.position = Vector3(0.25, float(_medidas["altura"]) + 0.55,
		comp * 0.55 + 1.8)
	add_child(suporte_chase)


func _montar_farois() -> void:
	_farol = SpotLight3D.new()
	_farol.name = "Farol"
	var comp := float(_medidas["comprimento"])
	_farol.position = Vector3(0.0, 0.62, -comp * 0.5 + 0.1)
	_farol.rotation.x = deg_to_rad(-9.0)
	_farol.spot_range = 28.0
	_farol.spot_angle = 36.0
	_farol.spot_angle_attenuation = 0.85
	_farol.light_energy = 4.4
	_farol.light_color = Color(1.0, 0.93, 0.8)
	_farol.shadow_enabled = false
	_farol.visible = false
	add_child(_farol)

	_facho = MeshInstance3D.new()
	_facho.name = "Facho"
	var cor_f := Color(1.0, 0.93, 0.8, 0.55)
	_facho.mesh = PSXMesh.cone(0.10, 2.6, 10.0, 8, 3,
		cor_f, Color(cor_f.r, cor_f.g, cor_f.b, 0.0))
	if ResourceLoader.exists(MAT_CONE):
		_facho.material_override = load(MAT_CONE)
	_facho.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_facho.sorting_offset = -1.0
	_facho.position = _farol.position
	_facho.rotation.x = PI * 0.5 + deg_to_rad(-9.0)
	_facho.visible = false
	add_child(_facho)


func acender_farois(aceso: bool = true) -> void:
	farois_acesos = aceso
	if _farol != null:
		_farol.visible = aceso
	if _facho != null:
		_facho.visible = aceso


func mostrar_cabine(visivel: bool) -> void:
	if cabine != null:
		cabine.visible = visivel


func _montar_som() -> void:'''
if a not in t: raise SystemExit("cabine missing")
t = t.replace(a,b,1)

a = '''func avancar(delta: float) -> void:
	var passo := velocidade / 3.6 * delta
	distancia += passo
	# Negativo: uma roda que anda para a frente gira para tras em torno do
	# proprio +X. E a mesma conta de `Carro._girar_rodas`, e trocar o sinal poe
	# o carro andando com as rodas girando ao contrario — que e um defeito que
	# ninguem consegue nao ver depois que reparou uma vez.
	_rolo = wrapf(_rolo - passo / Carroceria.RAIO_RODA, -PI, PI)
	if estrada != null:
		estrada.atualizar(distancia)
	_aplicar_transformada(delta)
	if _som != null:
		_som.atualizar(velocidade / 3.6, marcha(), true, delta)
	if cabine != null:
		cabine.marcar(velocidade)
		cabine.estercar(_curva / CURVA_CHEIA)'''
b = '''func dirigir(delta: float) -> void:
	if not jogavel:
		return
	var acelera := Input.get_action_strength(&"mover_frente")
	var freia := Input.get_action_strength(&"mover_tras")
	var esq := Input.get_action_strength(&"mover_esq")
	var dir_in := Input.get_action_strength(&"mover_dir")

	if acelera > 0.05:
		velocidade = move_toward(velocidade, VEL_MAX_JOGAVEL * acelera,
			ACEL_JOGAVEL * delta)
	elif freia > 0.05:
		velocidade = move_toward(velocidade, -18.0 * freia, FREIO_JOGAVEL * delta)
	else:
		velocidade = move_toward(velocidade, 0.0, MOTOR_JOGAVEL * delta)

	var alvo_esterco := (esq - dir_in)
	_esterco_jogador = move_toward(_esterco_jogador, alvo_esterco,
		ESTERCO_RESPOSTA * delta)
	var alvo_desvio := DESVIO_LATERAL + _esterco_jogador * DESVIO_JOGAVEL
	_desvio = lerpf(_desvio, alvo_desvio, clampf(delta * 2.0, 0.0, 1.0))


func avancar(delta: float) -> void:
	if jogavel:
		dirigir(delta)
	var passo := velocidade / 3.6 * delta
	distancia += passo
	# Negativo: uma roda que anda para a frente gira para tras em torno do
	# proprio +X. E a mesma conta de `Carro._girar_rodas`, e trocar o sinal poe
	# o carro andando com as rodas girando ao contrario — que e um defeito que
	# ninguem consegue nao ver depois que reparou uma vez.
	_rolo = wrapf(_rolo - passo / Carroceria.RAIO_RODA, -PI, PI)
	if estrada != null:
		estrada.atualizar(distancia)
	_aplicar_transformada(delta)
	if _som != null:
		_som.atualizar(velocidade / 3.6, marcha(), true, delta)
	if cabine != null:
		cabine.marcar(absf(velocidade))
		var volante := _curva / CURVA_CHEIA
		if jogavel:
			volante = clampf(volante + _esterco_jogador, -1.0, 1.0)
		cabine.estercar(volante)'''
if a not in t: raise SystemExit("avancar missing")
t = t.replace(a,b,1)

a = '''	var base := Basis.looking_at(dir, Vector3.UP)
	var salto := 0.0
	var fase := 0.0
	for onda: Dictionary in CHACOALHO_ONDA:
		salto += float(onda["amp"]) * sin(s / float(onda["onda"]) * TAU)
		fase += sin(s / float(onda["onda"]) * TAU + 1.1)
	# O chacoalho some com o carro parado: um carro de motor ligado vibra, mas
	# nao pula. Sem isto o plano com o carro parado treme sozinho.
	var forca := clampf(velocidade / 45.0, 0.0, 1.0)
	var arfa := deg_to_rad(ARFAR * fase * 0.5 * forca)
	var rola := deg_to_rad(ROLAR * sin(s / 5.3 * TAU) * forca
		- INCLINA_CURVA * _curva / CURVA_CHEIA)
	base = base * Basis(Vector3.RIGHT, arfa) * Basis(Vector3.FORWARD, rola)

	transform = Transform3D(base,
		p + lado * DESVIO_LATERAL + Vector3(0.0, salto * forca, 0.0))

	# Basis composta, e nao Euler: escrever `rotation.y` depois de `rotation.x`
	# corrompe a ordem e a roda comeca a cambar. Mesma correcao que o Carro do
	# transito ja carrega.
	if _eixo_frente != null:
		_eixo_frente.transform.basis = (Basis(Vector3.UP, -_curva * 1.6)
			* Basis(Vector3.RIGHT, _rolo))
	if _eixo_tras != null:
		_eixo_tras.transform.basis = Basis(Vector3.RIGHT, _rolo)'''
b = '''	var base := Basis.looking_at(dir, Vector3.UP)
	if jogavel and absf(_esterco_jogador) > 0.01:
		base = base * Basis(Vector3.UP, _esterco_jogador * 0.12)
	var salto := 0.0
	var fase := 0.0
	for onda: Dictionary in CHACOALHO_ONDA:
		salto += float(onda["amp"]) * sin(s / float(onda["onda"]) * TAU)
		fase += sin(s / float(onda["onda"]) * TAU + 1.1)
	# O chacoalho some com o carro parado: um carro de motor ligado vibra, mas
	# nao pula. Sem isto o plano com o carro parado treme sozinho.
	var forca := clampf(absf(velocidade) / 40.0, 0.0, 1.0)
	var arfa := deg_to_rad(ARFAR * fase * 0.5 * forca)
	var rola := deg_to_rad(ROLAR * sin(s / 5.3 * TAU) * forca
		- INCLINA_CURVA * (_curva / CURVA_CHEIA + _esterco_jogador * 0.35))
	base = base * Basis(Vector3.RIGHT, arfa) * Basis(Vector3.FORWARD, rola)

	var desvio := _desvio if jogavel else DESVIO_LATERAL
	transform = Transform3D(base,
		p + lado * desvio + Vector3(0.0, salto * forca, 0.0))

	# Basis composta, e nao Euler: escrever `rotation.y` depois de `rotation.x`
	# corrompe a ordem e a roda comeca a cambar. Mesma correcao que o Carro do
	# transito ja carrega.
	var esterco_roda := -_curva * 1.6
	if jogavel:
		esterco_roda -= _esterco_jogador * 0.45
	if _eixo_frente != null:
		_eixo_frente.transform.basis = (Basis(Vector3.UP, esterco_roda)
			* Basis(Vector3.RIGHT, _rolo))
	if _eixo_tras != null:
		_eixo_tras.transform.basis = Basis(Vector3.RIGHT, _rolo)'''
if a not in t: raise SystemExit("transform missing")
t = t.replace(a,b,1)

t = t.replace("if velocidade > limite:", "if absf(velocidade) > limite:", 1)

src.write_text(t, encoding="utf-8")
print("pass2 ok", len(t))
