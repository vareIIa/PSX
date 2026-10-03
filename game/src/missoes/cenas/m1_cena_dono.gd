## Missao 1, Cena 1: o dono (roteiro M1-C1-01 a 13, escolha E1).
##
## Comeca na soleira, com o dono abrindo a porta (o comportamento de atender
## que a casa ja tinha), ou na bancada, se o jogador falou com ele sem bater.
## O M1-C1-05 (o acompanhamento entrando na sala) virou corte preto: o jogador
## nao e um ator que anda por roteiro, e o corte do roteiro ja prevê o preto.
##
## A bancada e o posto do dono, no fim do corredor (`CasaFumacaBuilder._gente`):
## o jogador para entre ele e a porta, que e onde a conversa cabe sem parede no
## meio da lente.
class_name M1CenaDono
extends RefCounted

## Do posto do dono ate onde o jogador fica, na direcao da porta.
const FRENTE := 1.25


static func rodar(d: DiretorMissao1, na_porta: bool) -> void:
	var dono := d.dono
	var j := d.jogador()
	if dono == null or not is_instance_valid(dono) or j == null:
		d.dono_terminou()
		return
	var porta := d.casa_porta
	var rua := -porta.basis.z
	rua.y = 0.0
	rua = rua.normalized() if rua.length() > 0.01 else Vector3.FORWARD
	var posto := dono.posto_antes_da_porta() if na_porta else dono.global_position
	d.entrar_em_cena()

	if na_porta:
		dono.estacionar(dono.global_position, j.global_position)
		d.virar_jogador(dono.global_position)
		# M1-C1-01: a fachada de frente, o jogador pequeno na porta, de costas.
		AudioDirector.tocar(&"porta_trinco", porta.origin, -6.0)
		var olho := porta.origin + Vector3.UP * 1.7
		var de := porta.origin + rua * 9.0 + Vector3.UP * 2.3
		await d.dolly(de, de - rua * 1.0, olho, olho, 68.0, 3.5)
		# M1-C1-02: por cima do ombro do jogador, o dono no vao.
		AudioDirector.tocar(&"porta_abre", porta.origin, -4.0)
		d.plano(PlanoCena.Tipo.SOBRE_OMBRO, dono, j, 0.0, {"lado": 1})
		await d.fala("DONO", _l(["Você é o cara da praça. Já ouvi falar."]), dono)
		# M1-C1-03
		d.plano(PlanoCena.Tipo.CLOSE, j, dono, 0.0, {"lado": 1})
		await d.eu(_l(["Ouviu de quem?"]))
		# M1-C1-04
		d.plano(PlanoCena.Tipo.DOIS_MEDIO, dono, j, 0.0, {"lado": 1})
		dono.gargalhar()
		await d.fala("DONO", _l(["Cidade pequena.",
			"Entra. Fecha a porta que a névoa vem junto."]), dono)
		await d.corte_preto(0.4)

	# A bancada: o dono no posto, o jogador entre ele e a porta.
	var para_porta := porta.origin - posto
	para_porta.y = 0.0
	para_porta = para_porta.normalized() if para_porta.length() > 0.01 else rua
	var aqui := posto + para_porta * FRENTE
	aqui.y = posto.y
	d.por_jogador(aqui, posto)
	dono.estacionar(posto, aqui)
	await d.esperar(0.1)

	# M1-C1-06
	d.plano(PlanoCena.Tipo.DOIS_MEDIO, dono, j, 0.0, {"lado": 1})
	await d.fala("DONO", _l(["Ninguém entra nessa cidade faz tempo, %s. Sair é que é o problema."
		% d.primeiro_nome()]), dono)
	# M1-C1-07
	d.plano(PlanoCena.Tipo.CLOSE, j, dono, 0.0, {"lado": 1})
	await d.eu(_l(["Como você sabe meu nome?"]))
	# M1-C1-08: dolly de 30 cm no dono, pausa antes da fala.
	d.plano(PlanoCena.Tipo.DOLLY_IN, dono, j, 3.5, {"lado": 1, "distancia": 1.5})
	await d.esperar(0.6)
	await d.fala("DONO", _l(["Aqui todo mundo sabe o nome de todo mundo. Até de quem acabou de chegar."]), dono)

	# M1-C1-09 e a escolha E1.
	d.plano(PlanoCena.Tipo.SOBRE_OMBRO, j, dono, 0.0, {"lado": 1})
	var opcoes: Array[Dictionary] = [
		{"chave": &"e1_contar", "titulo": "Contar da estrada",
			"borboleta": &"m1_contou_ao_dono", "valor": true},
		{"chave": &"e1_passagem", "titulo": "Só de passagem",
			"borboleta": &"m1_contou_ao_dono", "valor": false},
	]
	var r := await d.pergunta("DONO", "E aí. O que te trouxe?", opcoes, dono)
	if r == &"e1_contar":
		d.plano(PlanoCena.Tipo.CLOSE, j, dono, 0.0, {"lado": 1})
		await d.eu(_l(["Eu tava indo pra São Thomé. Apaguei na estrada e acordei no chão da praça."]))
		d.plano(PlanoCena.Tipo.CLOSE, dono, j, 0.0, {"lado": 1})
		await d.fala("DONO", _l(["Fala baixo. Aqui dentro isso dá azar.",
			"...Já teve gente perguntando de você hoje."]), dono)
	else:
		d.plano(PlanoCena.Tipo.CLOSE, j, dono, 0.0, {"lado": 1})
		await d.eu(_l(["Tô só de passagem."]))
		d.plano(PlanoCena.Tipo.DOIS_MEDIO, dono, j, 0.0, {"lado": -1})
		dono.gargalhar()
		_sala_ri(d, dono)
		await d.fala("DONO", _l(["De passagem! Ó, ele tá de passagem!"]), dono)

	# M1-C1-12: a mao empurrando o pagamento pela bancada.
	var meio := dono.global_position.lerp(j.global_position, 0.45) + Vector3.UP * 0.95
	d.plano(PlanoCena.Tipo.CLOSE_EXTREMO, dono, j, 0.0, {"lado": 1, "ponto": meio})
	d.gesto(dono, Corpo.GestoCena.EMPURRAR_NA_BANCADA, meio)
	await d.fala("DONO", _l(["Toma. Você vai precisar mais do que eu."]), dono)
	_pagar(dono)
	AudioDirector.tocar_ui(&"pegar", -8.0)

	# M1-C1-13: aponta o porao, depois a porta da rua.
	d.plano(PlanoCena.Tipo.DOIS_MEDIO, dono, j, 0.0, {"lado": 1})
	var estufa := d.estufa_da_casa()
	var porao := estufa.to_global(EstufaBuilder.PORAO_ENTRADA) if estufa != null \
		else posto - para_porta * 3.0
	d.gesto(dono, Corpo.GestoCena.APONTAR, porao + Vector3.UP * 1.2)
	await d.fala("DONO", _l(["Os meninos tão lá embaixo, no porão. Se quiser conhecer quem sabe das coisas..."]), dono)
	d.gesto(dono, Corpo.GestoCena.APONTAR, porta.origin + Vector3.UP * 1.2)
	await d.fala("DONO", _l(["Se não, a porta é aquela."]), dono)

	await d.sair_de_cena()
	dono.liberar()
	d.dono_terminou()


static func _l(linhas: Array) -> Array[String]:
	var saida: Array[String] = []
	for l: Variant in linhas:
		saida.append(String(l))
	return saida


## A sala inteira ri de "de passagem" (M1-C1-11b): quem esta perto, em cascata.
static func _sala_ri(d: DiretorMissao1, dono: Convidado) -> void:
	var n := 0
	for no: Node in d.get_tree().get_nodes_in_group(&"convidado"):
		var c := no as Convidado
		if c == null or c == dono or not c.is_inside_tree():
			continue
		if c.global_position.distance_to(dono.global_position) > 12.0:
			continue
		n += 1
		d.get_tree().create_timer(0.25 + 0.3 * n).timeout.connect(func() -> void:
			if is_instance_valid(c):
				c.gargalhar())
		if n >= 4:
			break


## O pagamento que o dono ja dava (`Convidado._pagar_o_que_o_dono_deve`): o
## bilhete, uma vez so, e a marca de que respondeu.
static func _pagar(dono: Convidado) -> void:
	if dono.ficha.is_empty():
		return
	var coord := Vector2i(int(dono.ficha["id"]), FalasNpc.PESSOA)
	WorldState.definir(coord, &"dono_respondeu", true)
	if bool(WorldState.obter(coord, &"dono_pagou", false)):
		return
	if Inventario.adicionar(&"bilhete") > 0:
		return
	WorldState.definir(coord, &"dono_pagou", true)
