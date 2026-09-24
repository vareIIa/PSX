## O tropeco medido: quem balanca, quem da passo e quem cai.
##
##     godot --headless --path game --script res://tests/medir_tropeco.gd
##
## `Equilibrio` e conta pura (pendulo invertido), entao a regua roda sem
## fisica: empurra, avanca o relogio e le o que aconteceu.
##
## - empurrao leve (0,25 m/s, um ombro esbarrando andando): balanca e volta
##   sem dar passo;
## - medio (1,1 m/s, trombada correndo): da de um a quatro passos, todos para o
##   lado do empurrao, e se recupera em pe;
## - forte (2,6 m/s, carro devagar, empurrao de verdade): cai;
## - de lado e de costas o passo acompanha o empurrao, nao a frente do corpo.
##
## E no Corpo, pela ponta (memoria: "animacao se mede pela ponta"):
## - `inclinacao` para a frente leva a cabeca para -Z do corpo, para a direita
##   leva para +X, com os pes no lugar;
## - `rumo_passo` de lado leva o pe que avanca para o lado.
extends SceneTree

const O := Corpo.Osso
const DT := 1.0 / 60.0

var _passou := 0
var _total := 0


func _init() -> void:
	_rodar()


func _rodar() -> void:
	await process_frame
	_empurroes()
	_desenho()
	print("[tropeco] %d/%d" % [_passou, _total])
	quit(0 if _passou == _total else 1)


func _simular(dv: Vector3) -> Dictionary:
	var eq := Equilibrio.new(1.72)
	eq.empurrar(dv)
	var andou := Vector3.ZERO
	var maior := 0.0
	var t := 0.0
	var direcao_ok := true
	var parou_em := -1.0
	while t < 5.0:
		var pe := eq.passo(DT)
		if eq.caiu():
			break
		andou += pe * DT
		if pe.length() > 0.01 and pe.normalized().dot(dv.normalized()) < 0.7:
			direcao_ok = false
		maior = maxf(maior, eq.inclinacao_local(0.0).length())
		t += DT
		if parou_em < 0.0 and not eq.ativo():
			parou_em = t
	return {"caiu": eq.caiu(), "passos": eq.passos_dados(), "andou": andou,
		"inclinou": maior, "direcao": direcao_ok, "parou": parou_em,
		"sobra": eq.desvio.length()}


func _empurroes() -> void:
	var leve := _simular(Vector3(0.25, 0.0, 0.0))
	_conta("leve: balanca sem passo", not leve["caiu"] and int(leve["passos"]) == 0,
		"%d passos, inclinou %.3f rad" % [leve["passos"], leve["inclinou"]])
	_conta("leve: volta ao prumo", float(leve["sobra"]) < 0.01,
		"sobra %.3f m" % leve["sobra"])
	for rumo: Vector3 in [Vector3(1.1, 0.0, 0.0), Vector3(0.0, 0.0, -1.1),
			Vector3(-0.78, 0.0, 0.78), Vector3(1.8, 0.0, 0.0)]:
		var m := _simular(rumo)
		_conta("medio %s: tropeca e fica de pe" % rumo, not m["caiu"]
			and int(m["passos"]) >= 1 and int(m["passos"]) <= 4,
			"%d passos, andou %.2f m" % [m["passos"], (m["andou"] as Vector3).length()])
		_conta("medio %s: passo para o lado do empurrao" % rumo, bool(m["direcao"])
			and (m["andou"] as Vector3).normalized().dot(rumo.normalized()) > 0.9,
			"andou %s" % (m["andou"] as Vector3).snappedf(0.01))
		_conta("medio %s: para" % rumo, float(m["sobra"]) < 0.02, "sobra %.3f m" % m["sobra"])
	var forte := _simular(Vector3(0.0, 0.0, 2.6))
	_conta("forte: cai", bool(forte["caiu"]), "%d passos" % forte["passos"])


func _cabeca(c: Corpo) -> Vector3:
	var sk := c.esqueleto()
	return (sk.get_bone_global_pose(O.CABECA) * Vector3(0.0, 0.15, 0.0))


func _pe(c: Corpo, canela: int) -> Vector3:
	var sk := c.esqueleto()
	return sk.get_bone_global_pose(canela) * Vector3(0.0, -Corpo.Y_JOELHO * c.altura() / Corpo.ALTURA_REF, 0.0)


func _desenho() -> void:
	var c := Corpo.new()
	root.add_child(c)
	c.montar(Aparencia.de_ficha({"id": 5, "sexo": &"F", "idade": 28}))
	c.animar(0.0, DT)
	var reto := _cabeca(c)
	var pe_reto := _pe(c, O.CANELA_E)
	c.inclinacao = Vector2(0.0, 0.2)
	c.animar(0.0, DT)
	var frente := _cabeca(c)
	_conta("inclinar para a frente leva a cabeca a -Z", frente.z < reto.z - 0.15,
		"dz %.2f m" % (frente.z - reto.z))
	_conta("inclinando, o pe fica no lugar", _pe(c, O.CANELA_E).distance_to(pe_reto) < 0.05,
		"%.3f m" % _pe(c, O.CANELA_E).distance_to(pe_reto))
	c.inclinacao = Vector2(0.2, 0.0)
	c.animar(0.0, DT)
	var direita := _cabeca(c)
	_conta("inclinar para a direita leva a cabeca a +X", direita.x > reto.x + 0.15,
		"dx %.2f m" % (direita.x - reto.x))
	c.inclinacao = Vector2.ZERO
	# Passo de lado: meio ciclo andando, com o rumo para a direita.
	c.rumo_passo = PI * 0.5
	var maior_x := -INF
	var menor_x := INF
	for i in 60:
		c.animar(1.2, DT)
		var px := _pe(c, O.CANELA_D).x
		maior_x = maxf(maior_x, px)
		menor_x = minf(menor_x, px)
	var pe_z := _pe(c, O.CANELA_D).z
	_conta("passo de lado balanca o pe em x", maior_x - menor_x > 0.25,
		"amplitude %.2f m em x (z %.2f)" % [maior_x - menor_x, pe_z])
	c.queue_free()


func _conta(nome: String, ok: bool, texto: String = "") -> void:
	_total += 1
	if ok:
		_passou += 1
	print("  [%s] %s  %s" % ["ok" if ok else "FALHOU", nome, texto])
