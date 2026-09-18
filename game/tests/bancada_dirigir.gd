## Dinamica do carro: balanco, rolagem, curva, freio de mao e deriva.
##
##     godot --headless --fixed-fps 60 --path game --script res://tests/bancada_dirigir.gd
##     ... -- --modelo=SEDA,PICAPE      so estes modelos (padrao: SEDA, PICAPE, FUSCA)
##     ... -- --so=queda,freio_mao      so estes cenarios
##     ... -- --csv=DIR                 grava a serie de cada cenario em CSV
##     ... -- --molhado                 pista molhada (padrao: seca)
##     ... -- --ajuste=atrito:1.2,comp:1.5,relax:2.2,roll:0.1,estab:0.35
##                                      sobrescreve as rodas depois de montar:
##                                      e a varredura que acha os numeros da ficha
##
## `--fixed-fps 60` faz cada quadro valer exatamente um passo de fisica e tira o
## relogio de parede da conta: a bancada roda tao depressa quanto a CPU deixa, e
## o resultado nao depende de a maquina estar ocupada.
##
## Por que existe
## --------------
## O jogador reportou (17/09/2026): "a suspensao do carro e bem ruim, ele fica
## pulando de um lado pro outro", e pediu direcao mais realista e deriva no
## freio de mao. Nenhum teste media nada disso: `TesteCarro` mede arrancada,
## rumo e freada na rua, e `bancada_batida` mede amassado. Balanco e rolagem so
## se afirmam com a serie no tempo, num chao que nao muda — bancada, e nao rua
## (memoria: "bancada offline para o que a rua nao deixa medir").
##
## Os cenarios
## -----------
##   queda      o carro solto 8 cm acima do ponto de repouso. Quantas vezes ele
##              passa do ponto, e em quanto tempo assenta.
##   rolagem    o carro solto parado, deitado 3 graus de lado. E o "pula de um
##              lado pro outro" isolado: quantas vezes a carroceria cruza o
##              nivel antes de parar.
##   esterco    a 60 km/h, volante todo para a esquerda por 1,5 s e solto. Mede a
##              aceleracao lateral (g), a rolagem na curva, e o que sobra de
##              balanco depois de soltar.
##   slalom     a 70 km/h, volante em senoide de 0,5 Hz por dois ciclos, e solto.
##   skidpad    volante fixo a meio curso e velocidade subindo devagar: a maior
##              aceleracao lateral que o pneu sustenta. E o numero que diz se o
##              pneu e de rua ou de cola.
##   freio_mao  a 50 km/h, volante todo para a esquerda e freio de mao por 1 s.
##              Quanto o carro gira, quanto escorrega, e se roda de vez.
##   deriva     freio de mao por 0,5 s para soltar a traseira, e depois
##              acelerador e contra-esterco proporcional ao escorregamento, como
##              um motorista faria. Quanto tempo a deriva se sustenta.
##   reta       a 100 km/h sem mao no volante por 5 s: o carro nao pode serpentear.
##   freada     de 80 km/h ao pedal no fundo: a distancia nao pode piorar.
##
## Os criterios, por modelo (medidos em 18/09/2026 contra o carro de antes:
## 4 a 6 picos de balanco em 3,4 a 4 s, 2,1 a 2,5 g de curva, 11 a 17 graus de
## rolagem no slalom, freio de mao que parava o carro em 45 graus):
##   D1 queda      no maximo 1 pico, assenta em ate 0,8 s
##   D2 rolagem    no maximo 2 picos, assenta em ate 1 s
##   D3 pneu       0,70 a 1,05 g no skidpad (0,50 a 0,80 com --molhado)
##   D4 curva      volante no batente sem soltar a traseira (beta ate 5 graus), e
##                 ao soltar no maximo 2 picos de rolagem em ate 0,8 s
##   D5 slalom     rolagem ate 5 graus, no maximo 1 pico depois, sem capotar
##   D6 freio mao  gira pelo menos 40 graus no primeiro segundo (29 com --molhado)
##   D7 deriva     sustenta pelo menos 1,5 s, sem rodar
##   D8 reta       rumo desvia menos de 0,5 grau
##   D9 freada     pelo menos 5,5 m/s2 (4,0 com --molhado)
extends SceneTree

const PASSO := 1.0 / 60.0

const MODELOS := {
	"SEDA": 0, "HATCH": 1, "PERUA": 2, "PICAPE": 3, "TAXI": 4, "MAREA": 5,
	"FUSCA": 6,
}
const CENARIOS := ["queda", "rolagem", "esterco", "slalom", "skidpad",
	"freio_mao", "deriva", "reta", "freada"]

## O `Carro` vem por `load`: ele depende de autoloads, e um script de SceneTree
## e compilado antes de eles existirem. Mesmo motivo da `bancada_batida`.
var _script_carro: GDScript
var _modelos: Array[String] = ["SEDA", "PICAPE", "FUSCA"]
var _so: Array[String] = []
var _csv := ""
var _ajuste := {}
var _molhado := false
var _mundo: Node3D
## A serie do cenario em curso, uma linha por passo.
var _serie: Array[String] = []
var _passou := 0
var _total := 0


func _init() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--modelo="):
			_modelos.assign(a.trim_prefix("--modelo=").to_upper().split(","))
		elif a.begins_with("--so="):
			_so.assign(a.trim_prefix("--so=").split(","))
		elif a.begins_with("--csv="):
			_csv = a.trim_prefix("--csv=")
		elif a == "--molhado":
			_molhado = true
		elif a.begins_with("--ajuste="):
			for par: String in a.trim_prefix("--ajuste=").split(","):
				var kv := par.split(":")
				_ajuste[kv[0]] = kv[1].to_float()
	_rodar.call_deferred()


func _rodar() -> void:
	await process_frame
	_script_carro = load("res://src/world/carro.gd") as GDScript
	_mundo = Node3D.new()
	root.add_child(_mundo)
	# Chao plano de 4 km: a deriva e o skidpad andam centenas de metros.
	var chao := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(4000.0, 1.0, 4000.0)
	forma.shape = caixa
	chao.add_child(forma)
	chao.position = Vector3(0.0, -0.5, 0.0)
	_mundo.add_child(chao)
	for nome: String in _modelos:
		if not MODELOS.has(nome):
			print("modelo desconhecido: %s" % nome)
			continue
		print("\n=== %s ===" % nome)
		for cen: String in CENARIOS:
			if not _so.is_empty() and not _so.has(cen):
				continue
			# Um `match`, e nao `call("_c_" + cen)`: corrotina chamada por nome
			# nao devolve nada que o `await` espere, e os cenarios rodariam
			# todos juntos no mesmo chao.
			match cen:
				"queda": await _c_queda(nome)
				"rolagem": await _c_rolagem(nome)
				"esterco": await _c_esterco(nome)
				"slalom": await _c_slalom(nome)
				"skidpad": await _c_skidpad(nome)
				"freio_mao": await _c_freio_mao(nome)
				"deriva": await _c_deriva(nome)
				"reta": await _c_reta(nome)
				"freada": await _c_freada(nome)
	print("
%d de %d criterios" % [_passou, _total])
	quit(0 if _passou == _total else 1)


# --- o carro ----------------------------------------------------------------

func _novo(nome: String) -> VehicleBody3D:
	var c: VehicleBody3D = _script_carro.new()
	c.set(&"modelo", MODELOS[nome])
	c.set(&"semente", 3)
	c.set(&"motorista", 0)  # NINGUEM
	_mundo.add_child(c)
	c.call(&"pousar", Vector3(0.0, 0.6, 0.0), 0.0)
	await physics_frame
	c.set(&"ligado", true)
	c.call(&"assumir", Node3D.new())
	c.call(&"pilotar", 0.0, 0.0, 0.0)
	# O clima e da BANCADA, e nao do `settings.cfg` de quem esta na maquina: a
	# primeira rodada mediu pista molhada sem saber, porque o preset salvo era de
	# chuva, e o pneu de 0,90 da ficha virou 0,65 g no skidpad.
	var seco := float((c.get(&"_ficha") as Dictionary)["atrito"])
	var fator := float(_script_carro.get_script_constant_map()["MOLHADO"]) if _molhado else 1.0
	for r: VehicleWheel3D in c.get(&"_rodas"):
		r.wheel_friction_slip = seco * fator
		if _ajuste.has("atrito"):
			r.wheel_friction_slip = _ajuste["atrito"]
		if _ajuste.has("comp"):
			r.damping_compression = _ajuste["comp"]
		if _ajuste.has("relax"):
			r.damping_relaxation = _ajuste["relax"]
		if _ajuste.has("roll"):
			r.wheel_roll_influence = _ajuste["roll"]
	if _ajuste.has("estab"):
		c.set(&"_estabilizadora", _ajuste["estab"])
	# Assenta antes de qualquer medida. Quatro segundos, e nao um e meio: com
	# a suspensao de antes o carro ainda balancava do pouso aos 1,5 s, e a
	# queda media o balanco do pouso junto com o dela.
	for _q in 240:
		await physics_frame
	return c


func _jogar_fora(c: VehicleBody3D) -> void:
	c.call(&"devolver")
	c.queue_free()
	await physics_frame
	await physics_frame


## Rolagem, arfagem, rumo e escorregamento, em graus.
static func _atitude(c: VehicleBody3D) -> Dictionary:
	var b := c.global_transform.basis
	var frente := -b.z
	var v := c.linear_velocity
	var vh := Vector3(v.x, 0.0, v.z)
	var fh := Vector3(frente.x, 0.0, frente.z).normalized()
	var beta := 0.0
	if vh.length() > 1.0:
		# Positivo: a velocidade aponta para a ESQUERDA do nariz.
		beta = rad_to_deg(atan2(fh.cross(vh).y, fh.dot(vh)))
	return {
		# Positivo: deitado para a direita (o lado esquerdo sobe).
		"rolagem": rad_to_deg(asin(clampf(b.x.y, -1.0, 1.0))),
		"arfagem": rad_to_deg(asin(clampf(frente.y, -1.0, 1.0))),
		"rumo": rad_to_deg(atan2(-frente.x, -frente.z)),
		"beta": beta,
		"vel": vh.length(),
		"guinada": rad_to_deg(c.angular_velocity.y),
	}


## Leva o carro a `alvo` m/s em linha reta, com o pe controlado.
func _embalar(c: VehicleBody3D, alvo: float) -> void:
	for _q in int(40.0 / PASSO):
		var v: float = c.call(&"velocidade")
		if v >= alvo - 0.2:
			break
		c.call(&"pilotar", 1.0, 0.0, 0.0)
		await physics_frame
	# Meio segundo no ritmo, para a carroceria assentar do tranco da troca.
	for _q in 30:
		_manter(c, alvo, 0.0)
		await physics_frame
	# Um carro que nao embalou mede o nada: o criterio do cenario reprova, e
	# sem este aviso a reprovacao parece de freio ou de curva. Aconteceu no
	# controle com o carro antigo: freada "de 0 km/h" contada como freio fraco.
	var v: float = c.call(&"velocidade")
	if v < alvo * 0.8:
		print("[aviso] o carro nao embalou: pedido %.0f km/h, ficou em %.0f" % [alvo * 3.6, v * 3.6])


## Controle de velocidade simples, com o esterco pedido.
static func _manter(c: VehicleBody3D, alvo: float, esterco: float) -> void:
	var v: float = c.call(&"velocidade")
	var erro := alvo - v
	c.call(&"pilotar", clampf(erro * 0.6 + 0.25, 0.0, 1.0),
		clampf(-erro * 0.3, 0.0, 1.0), esterco)


func _gravar(t: float, c: VehicleBody3D, extra := "") -> void:
	if _csv == "":
		return
	var a := _atitude(c)
	# Escorregamento de cada eixo, o pior das duas rodas (1 - skidinfo).
	var rodas: Array = c.get(&"_rodas")
	var eixos := [0.0, 0.0]
	for k in rodas.size():
		var r: VehicleWheel3D = rodas[k]
		if r.is_in_contact():
			eixos[k / 2] = maxf(eixos[k / 2], 1.0 - clampf(r.get_skidinfo(), 0.0, 1.0))
	_serie.append("%.3f,%.4f,%.3f,%.3f,%.2f,%.2f,%.2f,%.2f,%.3f,%.3f%s" % [t,
		c.global_position.y, a["rolagem"], a["arfagem"], a["rumo"], a["beta"],
		a["vel"], a["guinada"], eixos[0], eixos[1], extra])


func _salvar(nome: String, cen: String) -> void:
	if _csv == "" or _serie.is_empty():
		_serie.clear()
		return
	DirAccess.make_dir_recursive_absolute(_csv)
	var f := FileAccess.open(_csv.path_join("%s_%s.csv" % [nome.to_lower(), cen]),
		FileAccess.WRITE)
	f.store_line("t,y,rolagem,arfagem,rumo,beta,vel,guinada,desl_frente,desl_tras")
	for l in _serie:
		f.store_line(l)
	f.close()
	_serie.clear()


func _conta(nome: String, criterio: String, ok: bool, texto: String) -> void:
	_total += 1
	if ok:
		_passou += 1
	print("%s %s %s: %s" % ["[ok]" if ok else "[X ]", nome, criterio, texto])


static func _relatar(nome: String, cen: String, chave: String, valor: Variant) -> void:
	print("[dirigir] %s %s %s=%s" % [nome, cen, chave, str(valor)])


## Quantos picos uma serie tem, com amplitude acima de `limiar` em torno do
## REPOUSO, e quando ela entra de vez em `faixa`. O repouso e a media do ultimo
## meio segundo, e nao o valor de antes do empurrao: medir contra um ponto que
## nao e o de equilibrio conta como balanco o que e so o carro assentando.
static func _oscilacao(ts: PackedFloat32Array, xs: PackedFloat32Array,
		limiar: float, faixa: float) -> Dictionary:
	var centro := 0.0
	var n := mini(30, xs.size())
	for i in range(xs.size() - n, xs.size()):
		centro += xs[i] / float(n)
	var picos: Array[float] = []
	for i in range(1, xs.size() - 1):
		var d0 := xs[i] - xs[i - 1]
		var d1 := xs[i + 1] - xs[i]
		if d0 * d1 < 0.0 and absf(xs[i] - centro) > limiar:
			picos.append(xs[i] - centro)
	var assentou := 0.0
	for i in xs.size():
		if absf(xs[i] - centro) > faixa:
			assentou = ts[i]
	# Razao de amortecimento pelo decremento logaritmico entre os dois
	# primeiros picos do MESMO lado.
	var zeta := -1.0
	if picos.size() >= 3 and absf(picos[0]) > 1e-6 and absf(picos[2]) > 1e-6 \
			and signf(picos[0]) == signf(picos[2]):
		var dl := log(absf(picos[0]) / absf(picos[2]))
		zeta = dl / sqrt(4.0 * PI * PI + dl * dl)
	return {"picos": picos, "assentou": assentou, "zeta": zeta}


# --- cenarios ---------------------------------------------------------------

func _c_queda(nome: String) -> void:
	var c := await _novo(nome)
	var rid := c.get_rid()
	var t := Transform3D(c.global_transform.basis, c.global_position + Vector3(0, 0.08, 0))
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, t)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
	c.global_transform = t
	var ts := PackedFloat32Array()
	var ys := PackedFloat32Array()
	for q in 240:
		await physics_frame
		ts.append(q * PASSO)
		ys.append(c.global_position.y)
		_gravar(q * PASSO, c)
	var o := _oscilacao(ts, ys, 0.003, 0.005)
	var repouso := ys[ys.size() - 1]
	var mais_fundo := 0.0
	for y in ys:
		mais_fundo = minf(mais_fundo, y - repouso)
	_relatar(nome, "queda", "picos", (o["picos"] as Array).size())
	_relatar(nome, "queda", "zeta", "%.2f" % o["zeta"])
	_relatar(nome, "queda", "assenta_s", "%.2f" % o["assentou"])
	_relatar(nome, "queda", "afunda_cm", "%.1f" % (mais_fundo * 100.0))
	_conta(nome, "D1 queda", (o["picos"] as Array).size() <= 1 and o["assentou"] <= 0.8,
		"%d pico(s), assenta em %.2f s" % [(o["picos"] as Array).size(), o["assentou"]])
	_salvar(nome, "queda")
	await _jogar_fora(c)


func _c_rolagem(nome: String) -> void:
	var c := await _novo(nome)
	var base := c.global_transform
	var rid := c.get_rid()
	var t := Transform3D(base.basis * Basis(Vector3.BACK, deg_to_rad(3.0)),
		base.origin + Vector3(0, 0.02, 0))
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, t)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
	c.global_transform = t
	var ts := PackedFloat32Array()
	var rs := PackedFloat32Array()
	for q in 240:
		await physics_frame
		ts.append(q * PASSO)
		rs.append(float(_atitude(c)["rolagem"]))
		_gravar(q * PASSO, c)
	var o := _oscilacao(ts, rs, 0.2, 0.3)
	_relatar(nome, "rolagem", "picos", (o["picos"] as Array).size())
	_relatar(nome, "rolagem", "zeta", "%.2f" % o["zeta"])
	_relatar(nome, "rolagem", "assenta_s", "%.2f" % o["assentou"])
	_conta(nome, "D2 rolagem", (o["picos"] as Array).size() <= 2 and o["assentou"] <= 1.0,
		"%d pico(s), assenta em %.2f s" % [(o["picos"] as Array).size(), o["assentou"]])
	_salvar(nome, "rolagem")
	await _jogar_fora(c)


func _c_esterco(nome: String) -> void:
	var c := await _novo(nome)
	var alvo := 60.0 / 3.6
	await _embalar(c, alvo)
	var rumo0 := float(_atitude(c)["rumo"])
	var lat_max := 0.0
	var rol_max := 0.0
	var beta_max := 0.0
	var v_ant := c.linear_velocity
	var t := 0.0
	# Curva: 1,5 s de volante no batente.
	for q in 90:
		_manter(c, alvo, -1.0)
		await physics_frame
		var a := _atitude(c)
		var acel := (c.linear_velocity - v_ant) / PASSO
		v_ant = c.linear_velocity
		var lado := c.global_transform.basis.x
		if q > 10:
			lat_max = maxf(lat_max, absf(acel.dot(lado)))
		rol_max = maxf(rol_max, absf(float(a["rolagem"])))
		beta_max = maxf(beta_max, absf(float(a["beta"])))
		_gravar(t, c)
		t += PASSO
	var rumo1 := float(_atitude(c)["rumo"])
	# Solta: 3 s em frente, mesmo pe.
	var ts := PackedFloat32Array()
	var rs := PackedFloat32Array()
	var gs := PackedFloat32Array()
	for q in 180:
		_manter(c, alvo, 0.0)
		await physics_frame
		var a := _atitude(c)
		ts.append(q * PASSO)
		rs.append(float(a["rolagem"]))
		gs.append(float(a["guinada"]))
		_gravar(t, c)
		t += PASSO
	var o := _oscilacao(ts, rs, 0.15, 0.3)
	var og := _oscilacao(ts, gs, 1.0, 1.0)
	_relatar(nome, "esterco", "lateral_g", "%.2f" % (lat_max / 9.8))
	_relatar(nome, "esterco", "rolagem_graus", "%.2f" % rol_max)
	_relatar(nome, "esterco", "beta_max", "%.1f" % beta_max)
	_relatar(nome, "esterco", "girou_graus", "%.0f" % absf(wrapf(rumo1 - rumo0, -180.0, 180.0)))
	_relatar(nome, "esterco", "picos_rolagem_depois", (o["picos"] as Array).size())
	_relatar(nome, "esterco", "rolagem_assenta_s", "%.2f" % o["assentou"])
	_relatar(nome, "esterco", "picos_guinada_depois", (og["picos"] as Array).size())
	_relatar(nome, "esterco", "guinada_assenta_s", "%.2f" % og["assentou"])
	_conta(nome, "D4 curva", beta_max <= 5.0 and (o["picos"] as Array).size() <= 2
			and o["assentou"] <= 0.8,
		"%.2f g, traseira a %.1f graus, ao soltar %d pico(s) em %.2f s" % [lat_max / 9.8,
			beta_max, (o["picos"] as Array).size(), o["assentou"]])
	_salvar(nome, "esterco")
	await _jogar_fora(c)


func _c_slalom(nome: String) -> void:
	var c := await _novo(nome)
	var alvo := 70.0 / 3.6
	await _embalar(c, alvo)
	var rol_max := 0.0
	var t := 0.0
	for q in 240:
		_manter(c, alvo, sin(TAU * 0.5 * t) * 0.8)
		await physics_frame
		rol_max = maxf(rol_max, absf(float(_atitude(c)["rolagem"])))
		_gravar(t, c)
		t += PASSO
	var ts := PackedFloat32Array()
	var rs := PackedFloat32Array()
	var gs := PackedFloat32Array()
	for q in 180:
		_manter(c, alvo, 0.0)
		await physics_frame
		var a := _atitude(c)
		ts.append(q * PASSO)
		rs.append(float(a["rolagem"]))
		gs.append(float(a["guinada"]))
		_gravar(t, c)
		t += PASSO
	var o := _oscilacao(ts, rs, 0.15, 0.3)
	var og := _oscilacao(ts, gs, 1.0, 1.0)
	_relatar(nome, "slalom", "rolagem_graus", "%.2f" % rol_max)
	_relatar(nome, "slalom", "picos_rolagem_depois", (o["picos"] as Array).size())
	_relatar(nome, "slalom", "rolagem_assenta_s", "%.2f" % o["assentou"])
	_relatar(nome, "slalom", "picos_guinada_depois", (og["picos"] as Array).size())
	_relatar(nome, "slalom", "capotou", 1 if c.call(&"capotado") else 0)
	_conta(nome, "D5 slalom", rol_max <= 5.0 and (o["picos"] as Array).size() <= 1
			and not c.call(&"capotado"),
		"rolagem %.2f graus, %d pico(s) depois" % [rol_max, (o["picos"] as Array).size()])
	_salvar(nome, "slalom")
	await _jogar_fora(c)


func _c_skidpad(nome: String) -> void:
	var c := await _novo(nome)
	await _embalar(c, 5.0)
	var lat_max := 0.0
	var v_no_max := 0.0
	var v_ant := c.linear_velocity
	var alvo := 5.0
	var t := 0.0
	# Volante fixo, velocidade subindo 1 m/s por segundo ate o pneu desistir ou
	# o esterco fechar.
	var lat_media := 0.0
	for q in int(25.0 / PASSO):
		alvo += PASSO
		_manter(c, alvo, -0.5)
		await physics_frame
		var acel := (c.linear_velocity - v_ant) / PASSO
		v_ant = c.linear_velocity
		lat_media = lerpf(lat_media, absf(acel.dot(c.global_transform.basis.x)), 0.1)
		if lat_media > lat_max:
			lat_max = lat_media
			v_no_max = c.linear_velocity.length()
		_gravar(t, c)
		t += PASSO
		if c.call(&"capotado"):
			break
	_relatar(nome, "skidpad", "lateral_max_g", "%.2f" % (lat_max / 9.8))
	_relatar(nome, "skidpad", "no_kmh", "%.0f" % (v_no_max * 3.6))
	_relatar(nome, "skidpad", "capotou", 1 if c.call(&"capotado") else 0)
	var g := lat_max / 9.8
	var faixa := Vector2(0.50, 0.80) if _molhado else Vector2(0.70, 1.05)
	_conta(nome, "D3 pneu", g >= faixa.x and g <= faixa.y,
		"%.2f g (faixa %.2f a %.2f)" % [g, faixa.x, faixa.y])
	_salvar(nome, "skidpad")
	await _jogar_fora(c)


func _c_freio_mao(nome: String) -> void:
	var c := await _novo(nome)
	var alvo := 50.0 / 3.6
	await _embalar(c, alvo)
	var rumo0 := float(_atitude(c)["rumo"])
	var beta_max := 0.0
	var t := 0.0
	var girou_1s := 0.0
	var ultimo := rumo0
	var giro_total := 0.0
	# Volante no batente e freio de mao por 1 s, sem acelerador.
	for q in 180:
		var puxado := q < 60
		c.call(&"puxar_freio_de_mao", puxado)
		c.call(&"pilotar", 0.0, 0.0, -1.0)
		await physics_frame
		var a := _atitude(c)
		giro_total += wrapf(float(a["rumo"]) - ultimo, -180.0, 180.0)
		ultimo = float(a["rumo"])
		if q == 59:
			girou_1s = giro_total
		beta_max = maxf(beta_max, absf(float(a["beta"])))
		_gravar(t, c)
		t += PASSO
	c.call(&"puxar_freio_de_mao", false)
	_relatar(nome, "freio_mao", "girou_em_1s", "%.0f" % absf(girou_1s))
	_relatar(nome, "freio_mao", "girou_em_3s", "%.0f" % absf(giro_total))
	_relatar(nome, "freio_mao", "beta_max", "%.0f" % beta_max)
	_relatar(nome, "freio_mao", "vel_final_kmh", "%.0f" % (c.linear_velocity.length() * 3.6))
	_relatar(nome, "freio_mao", "capotou", 1 if c.call(&"capotado") else 0)
	# Na chuva a frente tem 72% da aderencia e gira o carro menos no comeco (em
	# tres segundos ele gira MAIS que no seco): o piso acompanha a aderencia.
	var piso := 29.0 if _molhado else 40.0
	_conta(nome, "D6 freio de mao", absf(girou_1s) >= piso,
		"%.0f graus no primeiro segundo, %.0f em tres (piso %.0f)" % [absf(girou_1s),
			absf(giro_total), piso])
	_salvar(nome, "freio_mao")
	await _jogar_fora(c)


func _c_deriva(nome: String) -> void:
	var c := await _novo(nome)
	var alvo := 50.0 / 3.6
	await _embalar(c, alvo)
	var t := 0.0
	var em_deriva := 0.0
	var beta_max := 0.0
	var rodou := false
	# 0,6 s de freio de mao com o volante todo para a esquerda: solta a traseira.
	for q in 36:
		c.call(&"puxar_freio_de_mao", true)
		c.call(&"pilotar", 0.0, 0.0, -1.0)
		await physics_frame
		_gravar(t, c)
		t += PASSO
	c.call(&"puxar_freio_de_mao", false)
	# Depois, 4 s de motorista que QUER a deriva, com TECLADO: volante em -1, 0
	# ou +1, acelerador em 0 ou 1. Passou de 25 graus, contra-esterco cheio (as
	# rodas para onde o carro vai); abaixo de 15, volante para dentro da curva;
	# atravessou demais, tira o pe. Um motorista que contra-esterca ate alinhar
	# o carro esta SAINDO da deriva, e era o que a primeira versao desta bancada
	# media; um de volante proporcional nao e o jogador.
	#
	# A curva e para a esquerda, entao o carro atravessado escorrega para a
	# direita do nariz (`beta` negativo) e o contra-esterco e para a direita.
	for q in 240:
		var a := _atitude(c)
		var beta := absf(float(a["beta"]))
		var volante := 0.0
		if beta > 25.0:
			volante = 1.0
		elif beta < 15.0:
			volante = -1.0
		c.call(&"pilotar", 1.0 if beta < 35.0 else 0.0, 0.0, volante)
		await physics_frame
		a = _atitude(c)
		beta = absf(float(a["beta"]))
		beta_max = maxf(beta_max, beta)
		if beta > 90.0:
			rodou = true
		if beta >= 10.0 and beta <= 60.0 and float(a["vel"]) > 3.0:
			em_deriva += PASSO
		_gravar(t, c)
		t += PASSO
	_relatar(nome, "deriva", "segundos_em_deriva", "%.2f" % em_deriva)
	_relatar(nome, "deriva", "beta_max", "%.0f" % beta_max)
	_relatar(nome, "deriva", "rodou", 1 if rodou else 0)
	_conta(nome, "D7 deriva", em_deriva >= 1.5 and not rodou,
		"%.2f s em deriva, escorregou ate %.0f graus%s" % [em_deriva, beta_max,
			", RODOU" if rodou else ""])
	_relatar(nome, "deriva", "ainda_derivando", 1 if c.call(&"derivando") else 0)
	_relatar(nome, "deriva", "vel_final_kmh", "%.0f" % (c.linear_velocity.length() * 3.6))
	_salvar(nome, "deriva")
	await _jogar_fora(c)


func _c_reta(nome: String) -> void:
	var c := await _novo(nome)
	var alvo := 100.0 / 3.6
	await _embalar(c, alvo)
	var rumo0 := float(_atitude(c)["rumo"])
	var desvio := 0.0
	var guinada_max := 0.0
	for q in 300:
		_manter(c, alvo, 0.0)
		await physics_frame
		var a := _atitude(c)
		desvio = maxf(desvio, absf(wrapf(float(a["rumo"]) - rumo0, -180.0, 180.0)))
		guinada_max = maxf(guinada_max, absf(float(a["guinada"])))
		_gravar(q * PASSO, c)
	_relatar(nome, "reta", "vel_kmh", "%.0f" % (c.linear_velocity.length() * 3.6))
	_relatar(nome, "reta", "rumo_desvio_graus", "%.2f" % desvio)
	_conta(nome, "D8 reta", desvio < 0.5, "rumo desviou %.2f graus" % desvio)
	_relatar(nome, "reta", "guinada_max_gps", "%.2f" % guinada_max)
	_salvar(nome, "reta")
	await _jogar_fora(c)


func _c_freada(nome: String) -> void:
	var c := await _novo(nome)
	var alvo := 80.0 / 3.6
	await _embalar(c, alvo)
	var p0 := c.global_position
	var v0 := c.linear_velocity.length()
	var arf_max := 0.0
	for q in 600:
		c.call(&"pilotar", 0.0, 1.0, 0.0)
		await physics_frame
		arf_max = maxf(arf_max, absf(float(_atitude(c)["arfagem"])))
		_gravar(q * PASSO, c)
		if c.linear_velocity.length() < 0.3:
			break
	var d := Vector2(c.global_position.x - p0.x, c.global_position.z - p0.z).length()
	_relatar(nome, "freada", "de_kmh", "%.0f" % (v0 * 3.6))
	_relatar(nome, "freada", "metros", "%.1f" % d)
	var desacel := v0 * v0 / maxf(0.01, 2.0 * d)
	_relatar(nome, "freada", "desacel_ms2", "%.2f" % desacel)
	var piso := 4.0 if _molhado else 5.5
	_conta(nome, "D9 freada", desacel >= piso,
		"%.2f m/s2 em %.1f m (piso %.1f)" % [desacel, d, piso])
	_relatar(nome, "freada", "mergulho_graus", "%.2f" % arf_max)
	_salvar(nome, "freada")
	await _jogar_fora(c)
