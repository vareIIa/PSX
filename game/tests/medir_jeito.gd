## O jeito de cada um medido: cada pessoa anda do seu jeito, sempre o mesmo.
##
##     godot --headless --path game --script res://tests/medir_jeito.gd
##
## Criterios do PLANO_PERSONAGENS_AAA (fase 3) e dos gestos (fase 4):
## - 50 fichas seguidas dao >= 40 jeitos distintos; a mesma ficha, o mesmo jeito;
## - o jeito muda a POSE de andar (dois jeitos diferentes, mesma fase: ossos
##   diferentes), e nao so o numero;
## - parado, o ocio da pessoa dispara sozinho depois do intervalo dela, e so
##   parado (andando nao);
## - a fala escolhe gesto pela frase: "Nao..." nega com a cabeca, o desconfiado
##   nao gesticula com as maos, "voce" do mandao aponta.
extends SceneTree

var _passou := 0
var _total := 0


func _init() -> void:
	_rodar()


func _ficha(id: int) -> Dictionary:
	var sexo := &"F" if id % 2 == 0 else &"M"
	return {"id": id, "personalidade": id % 12, "idade": 20 + (id * 7) % 60, "sexo": sexo,
		"aparencia": Aparencia.de_ficha({"id": id, "sexo": sexo, "idade": 20 + (id * 7) % 60})}


func _rodar() -> void:
	await process_frame
	var assinaturas := {}
	var iguais := true
	for id in range(100, 150):
		var f := _ficha(id)
		var a := Jeito.assinatura(Jeito.de(f))
		assinaturas[a] = true
		iguais = iguais and a == Jeito.assinatura(Jeito.de(f))
	_conta("50 fichas, jeitos distintos", assinaturas.size() >= 40, "%d" % assinaturas.size())
	_conta("mesma ficha, mesmo jeito", iguais)
	_pose()
	_ocio()
	_gestos()
	_olhar()
	print("[jeito] %d/%d" % [_passou, _total])
	quit(0 if _passou == _total else 1)


func _braco_d(c: Corpo) -> Vector3:
	return c.esqueleto().get_bone_pose_rotation(Corpo.Osso.BRACO_D).get_euler()


func _pose() -> void:
	var a := Aparencia.de_ficha({"id": 9, "sexo": &"M", "idade": 30})
	var c1 := Corpo.new()
	var c2 := Corpo.new()
	root.add_child(c1)
	root.add_child(c2)
	c1.montar(a)
	c2.montar(a)
	var j1 := Jeito.neutro()
	var j2 := Jeito.neutro()
	j2["maos"] = Jeito.Maos.BOLSO
	j2["curvatura"] = -0.08
	c1.jeito = j1
	c2.jeito = j2
	for i in 20:
		c1.animar(1.3, 1.0 / 60.0)
		c2.animar(1.3, 1.0 / 60.0)
	var d := _braco_d(c1).distance_to(_braco_d(c2))
	var t1 := c1.esqueleto().get_bone_pose_rotation(Corpo.Osso.TORSO).get_euler().x
	var t2 := c2.esqueleto().get_bone_pose_rotation(Corpo.Osso.TORSO).get_euler().x
	_conta("maos no bolso mudam o braco andando", d > 0.3, "%.2f rad" % d)
	_conta("curvatura curva o tronco", t2 < t1 - 0.05, "%.2f contra %.2f" % [t2, t1])
	c1.queue_free()
	c2.queue_free()


func _ocio() -> void:
	var c := Corpo.new()
	root.add_child(c)
	c.montar(Aparencia.de_ficha({"id": 4, "sexo": &"F", "idade": 40}))
	var j := Jeito.neutro()
	j["ocios"] = [ReacaoCorpo.OCIO_CRUZA, ReacaoCorpo.OCIO_PESO, ReacaoCorpo.OCIO_OLHAR]
	j["intervalo"] = 2.0
	c.jeito = j
	var andando_reagiu := false
	for i in 200:
		c.animar(1.2, 1.0 / 60.0)
		andando_reagiu = andando_reagiu or c.reacao() != 0
	var parado_reagiu := -1
	for i in 200:
		c.animar(0.0, 1.0 / 60.0)
		if parado_reagiu < 0 and c.reacao() != 0:
			parado_reagiu = c.reacao()
	_conta("andando nao faz ocio", not andando_reagiu)
	_conta("parado faz o ocio preferido", parado_reagiu == ReacaoCorpo.OCIO_CRUZA,
		ReacaoCorpo.nome(parado_reagiu))
	c.queue_free()


func _gestos() -> void:
	var g := GestoDaFala.escolher("Nao sei de nada.", 4)
	_conta("\"Nao...\" nega com a cabeca", not g.is_empty()
		and int(g[0][1]) == ReacaoCorpo.GESTO_NEGA)
	g = GestoDaFala.escolher("Voce acha que eu tenho tempo pra isso? Tenho nao!", 0)
	var so_cabeca := true
	for x: Array in g:
		so_cabeca = so_cabeca and int(x[1]) in [ReacaoCorpo.GESTO_NEGA, ReacaoCorpo.GESTO_CONCORDA]
	_conta("desconfiado nao gesticula com as maos", so_cabeca)
	g = GestoDaFala.escolher("Voce vai sair daqui agora.", 9)
	var aponta := false
	for x: Array in g:
		aponta = aponta or int(x[1]) == ReacaoCorpo.GESTO_APONTA
	_conta("o mandao aponta no \"voce\"", aponta)
	# A fala leva o gesto ao corpo.
	var c := Corpo.new()
	root.add_child(c)
	c.montar(Aparencia.de_ficha({"id": 6, "sexo": &"M", "idade": 30}))
	var f := Fala.new()
	root.add_child(f)
	var corpos: Array[Corpo] = [c]
	f.corpos = corpos
	f.personalidade = 4
	f.dizer("Nao sei de nada, moco.")
	f._avancar_um_passo()
	_conta("a fala poe o gesto no corpo", c.reacao() == ReacaoCorpo.GESTO_NEGA,
		ReacaoCorpo.nome(c.reacao()))
	f.pular()
	f.queue_free()
	c.queue_free()


## O olho chega antes da cabeca, e volta ao meio quando a cabeca chega.
func _olhar() -> void:
	var c := Corpo.new()
	c.detalhado = true
	root.add_child(c)
	c.montar(Aparencia.de_ficha({"id": 22, "sexo": &"F", "idade": 29}))
	c.rosto.pisca = false
	c.animar(0.0, 1.0 / 60.0)
	c.olhar_lateral(0.9)
	c.animar(0.0, 1.0 / 60.0)
	var cabeca0 := c.esqueleto().get_bone_pose_rotation(Corpo.Osso.CABECA).get_euler().y
	var olho0 := c.rosto.estado(&"olho_e")
	for i in 90:
		c.animar(0.0, 1.0 / 60.0)
	var cabeca1 := c.esqueleto().get_bone_pose_rotation(Corpo.Osso.CABECA).get_euler().y
	var olho1 := c.rosto.estado(&"olho_e")
	_conta("o olho vai primeiro", olho0 == &"OLHA_DIR" and absf(cabeca0) < 0.3,
		"olho %s, cabeca %.2f" % [olho0, cabeca0])
	_conta("a cabeca chega e o olho volta ao meio", absf(cabeca1 - 0.9) < 0.1 and olho1 == &"",
		"cabeca %.2f, olho %s" % [cabeca1, olho1])
	c.queue_free()


func _conta(nome: String, ok: bool, texto: String = "") -> void:
	_total += 1
	if ok:
		_passou += 1
	print("  [%s] %s  %s" % ["ok" if ok else "FALHOU", nome, texto])
