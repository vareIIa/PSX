## Missao 1, Cena 2: Jota e Helmer no porao (roteiro M1-C2-01 a 15, escolha E2).
##
## Dispara no ultimo degrau da escada em U (`EstufaBuilder.PORAO_ENTRADA`). A
## dupla e de Convidados marcados no elenco, levados ao porao pela missao
## (`Elenco.levar_dupla_ao_porao`). Se algum dos dois estiver fora (entrega da
## Super na rua), entra um Ator com a ficha dele so para a cena: a dupla e
## unica, mas o porao nao pode ficar com meio elenco.
class_name M1CenaPorao
extends RefCounted

## O "barato" depois de aceitar (roteiro E2): 45 s, saindo em rampa nos 10 finais.
const BARATO := 45.0
const BARATO_SAIDA := 10.0


static func rodar(d: DiretorMissao1) -> void:
	Borboleta.marcar(&"m1_desceu_ao_porao", true, false)
	var estufa := d.estufa_da_casa()
	var j := d.jogador()
	if estufa == null or j == null:
		d.porao_terminou()
		return
	var temporarios: Array[Node] = []
	var helmer := _da_dupla(d, estufa, Elenco.HELMER, temporarios)
	var jota := _da_dupla(d, estufa, Elenco.JOTA, temporarios)
	var meio := estufa.to_global(Vector3(EstufaBuilder.PORAO_AREA.get_center().x, 0.0,
		EstufaBuilder.PORAO_AREA.get_center().y))
	var lampada := d.get_tree().get_first_node_in_group(&"lampada_porao")
	d.por_jogador(j.global_position, meio)
	d.entrar_em_cena()

	# M1-C2-01: POV descendo o ultimo degrau, a lampada balancando no facho roxo.
	_balancar(lampada, 0.35)
	var olho := j.global_position + Vector3.UP * 1.62
	var frente := (meio - j.global_position)
	frente.y = 0.0
	frente = frente.normalized()
	AudioDirector.tocar(&"passo_madeira_1", j.global_position, -8.0)
	await d.dolly(olho - frente * 0.8 + Vector3.UP * 0.35, olho,
		meio + Vector3.UP * 1.0, meio + Vector3.UP * 1.3, 70.0, 3.0)

	# M1-C2-02: de um canto baixo, o porao inteiro. Helmer conta de costas.
	var canto := estufa.to_global(Vector3(0.35, 0.55, 0.3))
	await d.quadro(canto, meio + Vector3.UP * 0.9, 68.0)
	await d.fala("HELMER", _l(["Trinta e dois... trinta e três... Fecha a porta, tá vazando cheiro."]), helmer)

	# M1-C2-03: Jota se endireita e bate a cabeca na lampada.
	d.plano(PlanoCena.Tipo.DOIS_MEDIO, jota, j, 0.0, {"lado": 1})
	d.gesto(jota, Corpo.GestoCena.BATER_A_CABECA)
	await d.esperar(0.35)
	_balancar(lampada, 1.0)
	await d.fala("JOTA", _l(["Ai! ...Ô, é o cara da praça!"]), jota)
	# M1-C2-04
	d.plano(PlanoCena.Tipo.CONTRA_PLONGEE, jota, j, 0.0, {"lado": 1})
	await d.fala("JOTA", _l(["Cê caiu do céu mesmo? Tão falando que cê caiu do céu."]), jota)
	# M1-C2-05
	d.plano(PlanoCena.Tipo.CLOSE, j, jota, 0.0, {"lado": 1})
	await d.eu(_l(["Eu acordei no chão."]))
	# M1-C2-06
	d.plano(PlanoCena.Tipo.SOBRE_OMBRO, helmer, j, 0.0, {"lado": 1})
	await d.fala("HELMER", _l(["Dá no mesmo. Cento e quarenta e sete."]), helmer)
	# M1-C2-07
	d.plano(PlanoCena.Tipo.DOIS_MEDIO, jota, j, 0.0, {"lado": 1})
	d.gesto(jota, Corpo.GestoCena.APONTAR, helmer.global_position + Vector3.UP * 1.3)
	await d.fala("JOTA", _l(["O Helmer conta tudo. Planta, dinheiro, os dias..."]), jota)
	# M1-C2-08
	d.plano(PlanoCena.Tipo.CLOSE, j, helmer, 0.0, {"lado": 1})
	await d.eu(_l(["Faz quantos dias que vocês tão aqui?"]))
	# M1-C2-09: Helmer para, vira devagar. Dolly ate o close.
	d.gesto(helmer, Corpo.GestoCena.VIRAR_DEVAGAR, j.global_position + Vector3.UP * 1.5)
	await d.plano(PlanoCena.Tipo.DOLLY_IN, helmer, j, 3.0, {"lado": 1})
	await d.fala("HELMER", _l(["...Aí eu parei de contar."]), helmer)

	# M1-C2-10 e a escolha E2.
	d.plano(PlanoCena.Tipo.DOIS_MEDIO, jota, j, 0.0, {"lado": 1})
	d.gesto(jota, Corpo.GestoCena.OFERECER, j.global_position + Vector3.UP * 1.2)
	var opcoes: Array[Dictionary] = [
		{"chave": &"e2_aceitar", "titulo": "Aceitar",
			"borboleta": &"m1_fumou_com_a_dupla", "valor": true},
		{"chave": &"e2_recusar", "titulo": "Recusar",
			"borboleta": &"m1_fumou_com_a_dupla", "valor": false},
	]
	var r := await d.pergunta("JOTA",
		"Cola aí. A primeira é por conta da casa. Olho de gato garantido.", opcoes, jota)
	if r == &"e2_aceitar":
		await _trago(d, j, jota)
		d.plano(PlanoCena.Tipo.DOIS_MEDIO, jota, helmer, 0.0, {"lado": 1})
		jota.call(&"gargalhar")
		await d.fala("JOTA", _l(["Ihhh, olha o olho dele!"]), jota)
		await d.fala("HELMER", _l(["Quatro segundos pra bater. Anotado."]), helmer)
	else:
		d.plano(PlanoCena.Tipo.DOIS_MEDIO, jota, j, 0.0, {"lado": -1})
		jota.call(&"gargalhar")
		await d.fala("JOTA", _l(["Careta!"]), jota)
		await d.fala("HELMER", _l(["Sobra mais. Cento e quarenta e oito."]), helmer)

	# M1-C2-13 a 15
	d.plano(PlanoCena.Tipo.DOIS_MEDIO, jota, j, 0.0, {"lado": 1})
	await d.fala("JOTA", _l(["Quando cansar de procurar a saída, volta aqui. Tem vaga na estufa."]), jota)
	d.plano(PlanoCena.Tipo.CLOSE, helmer, j, 0.0, {"lado": 1})
	await d.fala("HELMER", _l(["Ele não volta."]), helmer)
	d.plano(PlanoCena.Tipo.CLOSE, jota, j, 0.0, {"lado": 1})
	await d.fala("JOTA", _l(["Todo mundo volta."]), jota)

	await d.sair_de_cena()
	for n: Node in temporarios:
		if is_instance_valid(n):
			n.queue_free()
	d.porao_terminou()
	if r == &"e2_aceitar":
		var b := Barato.new()
		b.name = "BaratoM1"
		d.get_tree().root.add_child(b)


static func _l(linhas: Array) -> Array[String]:
	var saida: Array[String] = []
	for l: Variant in linhas:
		saida.append(String(l))
	return saida


static func _balancar(lampada: Node, forca: float) -> void:
	if lampada != null and lampada.has_method(&"balancar"):
		lampada.call(&"balancar", forca)


## O Convidado da dupla no lugar do porao, ou um Ator com a ficha dele.
static func _da_dupla(d: DiretorMissao1, estufa: Node3D, quem: StringName,
		temporarios: Array[Node]) -> Node3D:
	var lugar := Elenco.lugar_no_porao(quem)
	var pos := estufa.to_global(lugar["pos"])
	var olhar := estufa.to_global(lugar["olhar"])
	var c := Elenco.no(d.get_tree(), quem) as Convidado
	if c != null and c.global_position.distance_to(pos) < 25.0:
		c.estacionar(pos, olhar)
		return c
	var a := Ator.new()
	a.name = "%sDaCena" % String(quem).capitalize()
	a.preparar(quem, Elenco.ficha(quem))
	d.get_tree().current_scene.add_child(a)
	a.global_position = pos
	a.encarar(olhar)
	temporarios.append(a)
	return a


## M1-C2-11a: POV, a mao pega o baseado, a brasa sobe ate a lente e a fumaca
## cobre a tela.
static func _trago(d: DiretorMissao1, j: Node3D, jota: Node3D) -> void:
	await d.plano(PlanoCena.Tipo.POV, j, jota, 0.0, {})
	var cam := d.get_viewport().get_camera_3d()
	if cam == null:
		return
	var baseado := Cigarro.new()
	baseado.name = "BaseadoDaCasa"
	d.get_tree().current_scene.add_child(baseado)
	baseado.montar(null, 2208)
	var frente := -cam.global_basis.z
	var de := cam.global_position + frente * 0.75 - cam.global_basis.y * 0.25 + cam.global_basis.x * 0.12
	var ate := cam.global_position + frente * 0.16 - cam.global_basis.y * 0.04
	baseado.global_transform = Transform3D(Basis.looking_at(-cam.global_basis.x), de)
	var t := baseado.create_tween().set_parallel(true)
	t.tween_property(baseado, "global_position", ate, 1.2).set_trans(Tween.TRANS_SINE)
	t.chain().tween_property(baseado, "puxada", 1.0, 0.3)
	AudioDirector.tocar_ui(&"cigarro_traga", -12.0)
	await d.esperar(1.9)
	baseado.queue_free()


## Os 45 s de barato na pos (roteiro E2): aberracao +60%, matiz oscilando 8
## graus, saindo em rampa. Mexe nos uniforms do PSXPost e devolve os do
## Settings e do preset de nevoa no fim.
class Barato extends Node:
	var _t := 0.0
	var _posts: Array[PSXPost] = []

	func _ready() -> void:
		_achar(get_tree().root)

	func _achar(n: Node) -> void:
		if n is PSXPost:
			_posts.append(n as PSXPost)
		for f: Node in n.get_children():
			_achar(f)

	func _process(delta: float) -> void:
		_t += delta
		var forca := 1.0 - clampf((_t - (BARATO - BARATO_SAIDA)) / BARATO_SAIDA, 0.0, 1.0)
		var matiz := deg_to_rad(8.0) * sin(_t * 0.9) * forca
		var tinta := Color.from_hsv(fposmod(matiz / TAU, 1.0), 0.12 * forca, 1.0)
		for p: PSXPost in _posts:
			if not is_instance_valid(p):
				continue
			var m := p.material as ShaderMaterial
			if m == null:
				continue
			m.set_shader_parameter(&"chromatic", Settings.chromatic * (1.0 + 0.6 * forca))
			var base: Color = Settings.fog_preset().grade_tint if Settings.fog_preset() != null \
				else Color.WHITE
			m.set_shader_parameter(&"grade_tint", base * tinta)
		if _t >= BARATO:
			for p: PSXPost in _posts:
				if is_instance_valid(p):
					p.call(&"_apply_settings")
					p.call(&"_apply_grade", Settings.fog_preset())
			queue_free()
