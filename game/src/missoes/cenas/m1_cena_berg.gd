## Missao 1, Cenas 3, 4A, 5A, 6A e 4B: o Berg (escolhas E3, E5 e E6).
##
## Comeca com o jogador cruzando a porta da rua da casa da fumaca. O Marea ja
## esta na calcada com o Berg encostado (`DiretorMissao1._montar_berg_na_porta`).
##
## O jogador no carro
## ------------------
## Da porta do carona (4A-03) ate descer na praca (6A-03), quem aparece no banco
## e um Ator com a ficha do jogador (o duble): ele abre a porta, senta de carona,
## olha a janela e desce, com os mesmos verbos do Berg. O Player de verdade fica
## escondido e preso ao carro — o streaming da cidade segue ele, entao a cidade
## vai montando em volta do Marea. Na descida os dois trocam de lugar dentro do
## mesmo quadro.
##
## Os planos de dentro do carro andando
## ------------------------------------
## Close, close extremo, sobre o ombro e POV com o carro rodando sao feitos com
## a lente presa no espaco do carro (`DiretorMissao1.lente_presa`); interior e
## acompanhamento usam o `Cinema.plano`, que ja prende a lente.
class_name M1CenaBerg
extends RefCounted

## Corte de tempo da corrida (nota do 5A): mais longe que isto da igreja, um
## corte preto leva o carro a `CHEGADA` metros da vaga.
const CORTE_DE_TEMPO := 150.0
const CHEGADA := 45.0


static func rodar(d: DiretorMissao1) -> void:
	var berg := d.berg
	var carro := d.carro
	var j := d.jogador()
	var porta := d.casa_porta
	var rua := -porta.basis.z
	rua.y = 0.0
	rua = rua.normalized() if rua.length() > 0.01 else Vector3.FORWARD
	d.virar_jogador(berg.global_position)
	berg.olhar_para(j)
	d.entrar_em_cena()

	# M1-C3-01: do outro lado da rua, baixo; o Marea desfocado no primeiro plano.
	AudioDirector.tocar(&"porta_trinco", porta.origin, -8.0)
	var lado := Vector3.UP.cross(-rua).normalized()
	var de := porta.origin + rua * 12.5 - lado * 2.0 + Vector3.UP * 0.8
	await d.quadro(de, porta.origin + Vector3.UP * 1.3, 68.0, 3.5)
	# M1-C3-02: a brasa acende num trago, o reflexo nos oculos.
	d.plano(PlanoCena.Tipo.CLOSE_EXTREMO, berg, j, 0.0, {"lado": 1})
	AudioDirector.tocar(&"cigarro_traga", berg.global_position, -10.0)
	await d.esperar(1.5)
	# M1-C3-03
	d.plano(PlanoCena.Tipo.SOBRE_OMBRO, j, berg, 0.0, {"lado": 1})
	berg.jogar_bituca()
	await d.fala("BERG", _l(["Até que enfim. Pensei que cê tinha virado móvel lá dentro."]), berg)
	# M1-C3-04
	d.plano(PlanoCena.Tipo.CLOSE, j, berg, 0.0, {"lado": 1})
	await d.eu(_l(["Quem é você?"]))
	# M1-C3-05: desencosta, mao aberta, ourigado, as chaves no dedo.
	d.plano(PlanoCena.Tipo.DOIS_MEDIO, berg, j, 0.0, {"lado": 1})
	await berg.fazer(Corpo.GestoCena.DESENCOSTAR)
	berg.ouricado(true)
	await d.fala("BERG", _l(["Calma, calma, calma. Berg. Prazer. Eu também não sou daqui."]), berg)
	# M1-C3-06
	d.plano(PlanoCena.Tipo.CLOSE, berg, j, 0.0, {"lado": 1})
	await d.fala("BERG", _l(["Eu te vi hoje. Na praça. Cê tava deitado no chão de pedra, olhando pro céu igual peixe fora d'água."]), berg)
	# M1-C3-07
	d.plano(PlanoCena.Tipo.CLOSE, j, berg, 0.0, {"lado": 1})
	await d.eu(_l(["Você me viu... e me deixou lá?"]))
	# M1-C3-08
	d.plano(PlanoCena.Tipo.DOIS_MEDIO, berg, j, 0.0, {"lado": 1})
	await d.fala("BERG", _l(["Tava vendo se cê levantava sozinho. Todo mundo levanta. Eu levantei."]), berg)
	# Variantes antes do C3-09.
	if bool(Borboleta.valor(&"m1_desceu_ao_porao", false)):
		d.plano(PlanoCena.Tipo.CLOSE, berg, j, 0.0, {"lado": 1})
		await d.fala("BERG", _l(["Cê desceu lá com o Jota e o Helmer, né? Tá com cheiro de estufa."]), berg)
	if bool(Borboleta.valor(&"m1_contou_ao_dono", false)):
		d.plano(PlanoCena.Tipo.CLOSE, berg, j, 0.0, {"lado": -1})
		await d.fala("BERG", _l(["O dono aí me ligou. Falou que cê tava perguntando da estrada."]), berg)
	# M1-C3-09: os oculos, o radio chia sozinho.
	d.plano(PlanoCena.Tipo.CLOSE_EXTREMO, berg, j, 0.0, {"lado": 1})
	AudioDirector.tocar(&"estatica", carro.global_position, -12.0)
	await d.fala("BERG", _l(["Deixa eu adivinhar. Estrada de terra. Indo pra São Thomé.",
		"O farol pegou alguma coisa... e apagou."]), berg)
	# M1-C3-10
	d.plano(PlanoCena.Tipo.DOLLY_IN, j, berg, 2.2, {"lado": 1, "distancia": 1.4})
	await d.eu(_l(["...Como você sabe disso?"]))

	# M1-C3-11: de baixo, contra o ceu; ele vai ate a traseira e bate no adesivo.
	berg.ouricado(false)
	var lado_carro := 1.0 if carro.to_local(berg.global_position).x >= 0.0 else -1.0
	var m := carro.medidas()
	var meio_c := float(m.get("comprimento", 4.39)) * 0.5
	var traseira := carro.global_transform * Vector3(lado_carro * 1.25, 0.0, meio_c - 0.3)
	var vidro := carro.global_transform * Vector3(lado_carro * 0.35, 1.15, meio_c - 0.55)
	d.plano(PlanoCena.Tipo.CONTRA_PLONGEE, berg, j, 0.0, {"lado": 1})
	var falou := [false]
	var fala_11 := func() -> void:
		await d.fala("BERG", _l(["Porque comigo foi igualzinho. Eu ia pra São Thomé ver disco voador.",
			"Acordei no chão daquela praça. Com essa mesma cara que cê tá fazendo agora."]), berg)
		falou[0] = true
	fala_11.call()
	await d.andar(berg, traseira)
	await berg.fazer(Corpo.GestoCena.BATER_NO_VIDRO, vidro, lado_carro)
	AudioDirector.tocar(&"clique", vidro, -6.0, 0.6)
	# M1-C3-12: o adesivo, a chuva escorrendo nas letras.
	var atras := carro.global_transform * Vector3(0.0, 1.2, meio_c + 1.3)
	await d.quadro(atras, carro.global_transform * Vector3(0.0, 1.1, meio_c - 0.4), 22.0, 1.5)
	while not falou[0]:
		await d.esperar(0.1)
	# M1-C3-13: volta para a frente do carro, abre os bracos para a rua.
	d.plano(PlanoCena.Tipo.DOIS_MEDIO, berg, j, 0.0, {"lado": 1})
	berg.encostar_no_carro(carro, lado_carro)
	await d.fala("BERG", _l(["Olha. Cê tá com cara de quem vai sair andando até achar a saída. Vou te poupar esse trabalho."]), berg)
	# M1-C3-14 e a escolha E3.
	d.plano(PlanoCena.Tipo.SOBRE_OMBRO, berg, j, 0.0, {"lado": 1})
	var opcoes: Array[Dictionary] = [
		{"chave": &"e3_entrar", "titulo": "Entrar no carro",
			"borboleta": &"m1_aceitou_carona_berg", "valor": true},
		{"chave": &"e3_recusar", "titulo": "Recusar",
			"borboleta": &"m1_aceitou_carona_berg", "valor": false},
	]
	var r := await d.pergunta("BERG",
		"Entra aí. Te explico no caminho. Tem um lugar que eu quero te mostrar.", opcoes, berg)
	if r == &"e3_entrar":
		await _carona(d, berg, carro, j)
	else:
		await _papel(d, berg, carro, j, rua)


static func _l(linhas: Array) -> Array[String]:
	var saida: Array[String] = []
	for l: Variant in linhas:
		saida.append(String(l))
	return saida


# --- 4A, 5A e 6A: a carona ------------------------------------------------------

static func _carona(d: DiretorMissao1, berg: Ator, carro: Carro, j: Player) -> void:
	# M1-C4A-01: sorri e bate duas vezes no teto.
	d.plano(PlanoCena.Tipo.DOIS_MEDIO, berg, j, 0.0, {"lado": 1})
	var teto := carro.global_transform * Vector3(0.0, float(carro.medidas().get("altura", 1.4)), 0.0)
	await berg.fazer(Corpo.GestoCena.DESENCOSTAR)
	berg.fazer(Corpo.GestoCena.BATER_NO_VIDRO, teto)
	for i in 2:
		d.get_tree().create_timer(0.35 + 0.22 * i).timeout.connect(func() -> void:
			AudioDirector.tocar(&"clique", teto, -4.0, 0.45))
	await d.fala("BERG", _l(["Isso. Gostei de você."]), berg)

	# M1-C4A-02: ele contorna a frente ate a porta do motorista; o jogador vai
	# para a do carona. Daqui ate a praca, quem esta no banco e o duble.
	var duble := _duble(d, j)
	d.prender_jogador_a(carro)
	d.plano(PlanoCena.Tipo.ACOMPANHAMENTO, berg, null, 0.0, {})
	var andou := [0]
	var contorna := func() -> void:
		await berg.contornar_carro(carro, Carro.Banco.MOTORISTA)
		andou[0] += 1
	contorna.call()
	# O Berg sai do paralama da calcada primeiro: os dois nao se trombam.
	await d.esperar(1.1)
	await d.andar(duble, carro.ponto_da_porta(Carro.Banco.PASSAGEIRO).origin)
	while andou[0] < 1:
		await d.esperar(0.1)

	# M1-C4A-03: do banco de tras, as duas portas abrem quase juntas.
	d.plano(PlanoCena.Tipo.CARRO_INTERIOR, carro, null, 0.0, {"de_tras": true})
	var sentou := [0]
	var entra_berg := func() -> void:
		await berg.entrar_no_carro(carro, Carro.Banco.MOTORISTA)
		sentou[0] += 1
	var entra_duble := func() -> void:
		await d.esperar(0.3)
		await duble.entrar_no_carro(carro, Carro.Banco.PASSAGEIRO)
		sentou[0] += 1
	entra_berg.call()
	entra_duble.call()
	while sentou[0] < 2:
		await d.esperar(0.1)
	berg.olhar_para(duble)
	duble.olhar_para(berg)
	# M1-C4A-04: a chave na ignicao.
	var bm := _banco(carro)
	await d.lente_presa(carro, bm + Vector3(0.3, 0.38, -0.25), bm + Vector3(0.12, 0.28, -0.55), 22.0)
	AudioDirector.tocar(&"motor_partida", carro.global_position, -4.0)
	await d.esperar(1.8)

	# M1-C4A-05: rente ao chao, do lado da calcada, o carro sai. A corrida
	# comeca aqui e a conversa vai junto.
	var ig := Lugares.igreja()
	var vaga: Transform3D = ig["vaga"]
	var rota := {"chegou": false, "fim": false}
	var chao := carro.global_transform * Vector3(2.8, 0.25, -0.6)
	d.quadro(chao, carro.global_transform * Vector3(0.6, 0.35, -1.6), 68.0)
	_dirigir(d, carro, vaga.origin, rota)
	await d.esperar(3.0)

	await _corrida(d, berg, duble, carro)

	# Fim da conversa: chega. Longe demais, corte de tempo.
	rota["fim"] = true
	await _chegar(d, carro, vaga, rota)

	# M1-C5A-20: pelo para-brisa, a torre da capela azul.
	var olho_duble := _cabeca(carro, false)
	d.lente_presa(carro, olho_duble + Vector3(-0.05, 0.02, -0.05),
		olho_duble + Vector3(-0.2, 0.6, -30.0), 70.0)
	await d.fala("BERG", _l(["Chegamos."]), berg)

	# M1-C6A-01: rente ao meio-fio da praca, sobe na calcada torto.
	var baixo := d.no_chao(vaga * Vector3(2.6, 0.0, -3.4)) + Vector3.UP * 0.22
	d.quadro(baixo, d.no_chao(vaga.origin) + Vector3.UP * 0.4, 55.0)
	await carro.estacionar_na_calcada(vaga, true)
	AudioDirector.tocar(&"clique", carro.global_position, -6.0, 0.8)
	await d.esperar(0.8)
	# M1-C6A-02: do painel. Ele tira a chave.
	d.plano(PlanoCena.Tipo.CARRO_INTERIOR, carro, null, 0.0, {})
	await d.fala("BERG", _l(["Estacionamento VIP."]), berg)
	# M1-C6A-03: os dois saindo pelas duas portas.
	var fora := carro.global_transform * Vector3(0.0, 1.5, -float(carro.medidas().get("comprimento", 4.4)) * 0.5 - 4.5)
	d.quadro(fora, carro.global_transform * Vector3(0.0, 1.0, 0.0), 50.0)
	var desceu := [0]
	var sai_berg := func() -> void:
		await berg.sair_do_carro(carro, Carro.Banco.MOTORISTA)
		desceu[0] += 1
	var sai_duble := func() -> void:
		await duble.sair_do_carro(carro, Carro.Banco.PASSAGEIRO)
		desceu[0] += 1
	sai_berg.call()
	sai_duble.call()
	while desceu[0] < 2:
		await d.esperar(0.1)
	# A troca: o jogador volta no lugar do duble, no mesmo quadro.
	var igreja: Vector3 = d.no_chao(ig["frente"])
	d.soltar_jogador(duble.global_position, igreja)
	j.mostrar_corpo(true)
	duble.queue_free()
	d.duble = null
	# M1-C6A-04: por cima do ombro do Berg, que ja vai para a igreja.
	berg.encarar(igreja)
	berg.andar_ate(berg.global_position + (igreja - berg.global_position).normalized() * 1.5)
	d.plano(PlanoCena.Tipo.SOBRE_OMBRO, j, berg, 0.0, {"lado": 1})
	await d.esperar(0.6)
	berg.fazer(Corpo.GestoCena.OLHAR_PARA_TRAS, j.global_position)
	await d.fala("BERG", _l(["Vem."]), berg)
	await d.sair_de_cena()
	d.comecar_seguir()


## O ator que faz o jogador dentro do carro: mesma ficha, mesmo lugar.
static func _duble(d: DiretorMissao1, j: Player) -> Ator:
	var a := Ator.new()
	a.name = "Duble"
	a.preparar(&"voce", RegistroCivil.jogador.duplicate(true))
	d.get_tree().current_scene.add_child(a)
	a.global_transform = Transform3D(Basis(Vector3.UP, j.rotation.y), j.global_position)
	d.duble = a
	j.mostrar_corpo(false)
	return a


## Topo do banco do motorista no espaco do carro.
static func _banco(carro: Carro) -> Vector3:
	var m := carro.medidas()
	return m.get("banco_motorista", Vector3(-0.4, 0.46, -0.2))


## A cabeca de quem esta sentado, no espaco do carro.
static func _cabeca(carro: Carro, motorista: bool) -> Vector3:
	var b := _banco(carro)
	if not motorista:
		b.x = -b.x
	return b + Vector3(0.0, 0.66, 0.06)


static func _dirigir(_d: DiretorMissao1, carro: Carro, alvo: Vector3, rota: Dictionary) -> void:
	await carro.ir_para(alvo)
	if not is_instance_valid(carro):
		return
	rota["chegou"] = true
	# Chegou com a conversa no meio: da a volta no quarteirao (os planos de
	# fora escondem) ate a conversa acabar.
	if not bool(rota["fim"]):
		carro.vagar(9999.0)


## Depois da conversa: perto, deixa chegar; longe, corte de tempo para os
## ultimos metros (nota do 5A).
static func _chegar(d: DiretorMissao1, carro: Carro, vaga: Transform3D, rota: Dictionary) -> void:
	var longe := carro.global_position.distance_to(vaga.origin) > CORTE_DE_TEMPO
	if not longe and bool(rota["chegou"]):
		await carro.ir_para(vaga.origin)
		return
	if not longe:
		var espera := 0.0
		while not bool(rota["chegou"]) and espera < 60.0:
			await d.esperar(0.25)
			espera += 0.25
		if bool(rota["chegou"]):
			return
	# M1-C5A-19: atras do carro, as lanternas, a rua reta; e o corte.
	await d.lente_presa(carro, Vector3(0.0, 2.0, 8.0), Vector3(0.0, 1.0, -6.0), 58.0, 3.0)
	await d.corte_preto(0.4)
	carro.parar_cena()
	var atras := vaga.origin + vaga.basis.z * CHEGADA
	var giro := vaga.basis.get_euler().y
	var pose := carro.pose_no_chao(atras, giro)
	carro.pousar(pose.origin, giro)
	carro.global_transform = pose
	# A cidade monta em volta do carro (o jogador escondido vai junto).
	var t := 0.0
	while t < 6.0 and not ChunkManager.esta_carregado(ChunkManager.coord_de(atras)):
		await d.esperar(0.2)
		t += 0.2
	await d.esperar(0.4)
	pose = carro.pose_no_chao(atras, giro)
	carro.pousar(pose.origin, giro)
	carro.global_transform = pose
	var chegou := [false]
	var ir := func() -> void:
		await carro.ir_para(vaga.origin)
		chegou[0] = true
	ir.call()
	d.lente_presa(carro, Vector3(0.0, 2.0, 8.0), Vector3(0.0, 1.0, -6.0), 58.0)
	var espera2 := 0.0
	while not chegou[0] and espera2 < 40.0:
		await d.esperar(0.25)
		espera2 += 0.25


## M1-C5A-01 a 18: a conversa no carro (E5 e E6).
static func _corrida(d: DiretorMissao1, berg: Ator, duble: Ator, carro: Carro) -> void:
	var hb := _cabeca(carro, true)
	var hd := _cabeca(carro, false)
	# M1-C5A-01: de cima, o Marea sozinho na avenida; a grua sobe acompanhando.
	await d.lente_presa(carro, Vector3(0.0, 15.0, 9.0), Vector3(0.0, 0.0, -8.0), 60.0,
		5.0, Vector3(0.0, 30.0, 14.0))
	# M1-C5A-02: do banco de tras, limpador batendo.
	Cinema.tremor(0.12)
	d.plano(PlanoCena.Tipo.CARRO_INTERIOR, carro, null, 0.0, {"de_tras": true})
	await d.fala("BERG", _l(["Primeira semana eu fiz o que cê ia fazer. Enchi o tanque e fui reto.",
		"Nove horas reto."]), berg)
	# M1-C5A-03
	d.lente_presa(carro, hd + Vector3(-0.5, 0.0, -0.7), hd, 34.0)
	await d.eu(_l(["E?"]))
	# M1-C5A-04
	d.lente_presa(carro, hb + Vector3(0.5, 0.0, -0.7), hb, 34.0)
	await d.fala("BERG", _l(["E a cidade foi junto. Rua, poste, mercado, casa da fumaça...",
		"Já reparou que tem casa da fumaça em todo canto? Parece franquia."]), berg)
	# M1-C5A-05: pelo para-brisa, a rua saindo da nevoa.
	d.lente_presa(carro, hd + Vector3(-0.05, 0.0, -0.05), hd + Vector3(-0.1, -0.2, -30.0), 70.0)
	await d.fala("BERG", _l(["Pintei um poste de spray rosa pra marcar. Voltei procurando. Nunca mais achei.",
		"As ruas mudam quando cê vira as costas, sô."]), berg)
	# M1-C5A-06
	d.lente_presa(carro, hd + Vector3(-0.5, 0.0, -0.7), hd, 34.0)
	await d.eu(_l(["Isso não existe."]))
	# M1-C5A-07: por cima do ombro do jogador, o queixo apontando a nevoa.
	d.lente_presa(carro, hd + Vector3(0.18, 0.1, 0.4), hb, 42.0)
	await d.fala("BERG", _l(["Fala isso pra ela."]), berg)
	# M1-C5A-08: o dedo no botao do radio.
	var radio := Vector3(0.0, 0.72, _banco(carro).z - 0.55)
	d.lente_presa(carro, radio + Vector3(0.25, 0.2, 0.3), radio, 22.0)
	berg.fazer(Corpo.GestoCena.MEXER_NO_RADIO, carro.global_transform * radio)
	AudioDirector.tocar_ui(&"radio_click", -10.0)
	AudioDirector.tocar_ui(&"estatica", -16.0)
	await d.esperar(1.5)
	# M1-C5A-09: do painel. Pega o funk.
	d.plano(PlanoCena.Tipo.CARRO_INTERIOR, carro, null, 0.0, {})
	AudioDirector.tocar_ui(&"funk_batida", -14.0)
	await d.fala("BERG", _l(["Só pega essa rádio. Toca a mesma música desde que eu cheguei.",
		"Eu já sei a letra de trás pra frente."]), berg)
	# M1-C5A-10: de fora, rente as rodas, postes passando.
	Cinema.tremor(0.0)
	await d.lente_presa(carro, Vector3(3.0, 1.0, 1.2), Vector3(0.0, 0.6, 0.0), 58.0,
		3.5, Vector3(3.0, 1.0, -1.2))
	# M1-C5A-11: ele abaixa o volume. Serio. E5.
	Cinema.tremor(0.1)
	d.lente_presa(carro, hb + Vector3(0.5, 0.0, -0.7), hb, 34.0)
	var opcoes5: Array[Dictionary] = [
		{"chave": &"e5_padre", "titulo": "Contar do padre",
			"borboleta": &"m1_contou_do_padre_ao_berg", "valor": true},
		{"chave": &"e5_nada", "titulo": "Não vi nada",
			"borboleta": &"m1_contou_do_padre_ao_berg", "valor": false},
	]
	var r5 := await d.pergunta("BERG",
		"Me fala uma coisa. Antes de apagar... cê viu alguém na estrada?", opcoes5, berg)
	if r5 == &"e5_padre":
		# 12a a 15a
		await d.lente_presa(carro, hd + Vector3(-0.45, 0.0, -0.65), hd, 34.0, 0.0,
			hd + Vector3(-0.35, 0.0, -0.5))
		await d.eu(_l(["Um padre. Parado no meio da estrada. Ele... sorriu pra mim."]))
		var volante := _banco(carro) + Vector3(0.0, 0.42, -0.45)
		d.lente_presa(carro, volante + Vector3(0.3, 0.18, 0.25), volante, 22.0)
		berg.fazer(Corpo.GestoCena.APERTAR_VOLANTE)
		AudioDirector.tocar_ui(&"interferencia", -14.0)
		await d.esperar(2.0)
		d.plano(PlanoCena.Tipo.CARRO_INTERIOR, carro, null, 0.0, {"de_tras": true})
		await d.esperar(1.2)
		await d.fala("BERG", _l(["...Sorrindo.", "Eu nunca falei disso pra ninguém.",
			"Eu também vi ele."]), berg)
		d.lente_presa(carro, hb + Vector3(0.65, 0.0, -0.1), hb, 34.0)
		await d.fala("BERG", _l(["É por isso que eu vou pra igreja toda noite.",
			"Se ele tá em algum lugar nessa cidade, é lá."]), berg)
		AudioDirector.tocar_ui(&"radio_click", -10.0)
	else:
		# 12b e 13b
		d.lente_presa(carro, hd + Vector3(-0.5, 0.0, -0.7), hd, 34.0)
		duble.olhar_para(null)
		await d.eu(_l(["Não. Só escuro."]))
		d.lente_presa(carro, hb + Vector3(0.5, 0.0, -0.7), hb, 34.0)
		await berg.fazer(Corpo.GestoCena.BAIXAR_OCULOS)
		await d.fala("BERG", _l(["Hm.", "Tá bom. Cê é que sabe."]), berg)
		berg.fazer(Corpo.GestoCena.SUBIR_OCULOS)
		duble.olhar_para(berg)

	# M1-C5A-16: bem alto, a esquina, a nevoa engolindo as ruas. A grua desce.
	Cinema.tremor(0.0)
	d.lente_presa(carro, Vector3(0.0, 40.0, 12.0), Vector3(0.0, 0.0, -10.0), 60.0,
		4.5, Vector3(0.0, 22.0, 9.0))
	await d.fala("BERG", _l(["Uma coisa eu aprendi. Nessa cidade nada fica no lugar.",
		"Só a igreja. A igreja tá sempre lá."]), berg)
	# M1-C5A-17 e a escolha E6.
	Cinema.tremor(0.12)
	d.plano(PlanoCena.Tipo.CARRO_INTERIOR, carro, null, 0.0, {"de_tras": true})
	var opcoes6: Array[Dictionary] = [
		{"chave": &"e6_bonde", "titulo": "Falar do Lucas e da Mari",
			"borboleta": &"m1_falou_do_bonde", "valor": true},
		{"chave": &"e6_ninguem", "titulo": "Não tinha ninguém",
			"borboleta": &"m1_falou_do_bonde", "valor": false},
	]
	var r6 := await d.pergunta("BERG", "Cê tinha alguém te esperando? Lá em São Thomé?",
		opcoes6, berg)
	if r6 == &"e6_bonde":
		d.lente_presa(carro, hd + Vector3(-0.5, 0.0, -0.7), hd, 34.0)
		await d.eu(_l(["O bonde. Uns amigos. O Lucas e a Mari já tavam lá."]))
		# 18a2: o retrovisor, o banco de tras vazio; a estatica da um pico.
		var espelho := Vector3(0.0, 1.22, _banco(carro).z - 0.45)
		d.lente_presa(carro, hb + Vector3(0.2, 0.05, -0.15), espelho, 22.0)
		await d.esperar(1.0)
		AudioDirector.tocar_ui(&"estatica", -8.0)
		await d.esperar(1.5)
		d.lente_presa(carro, hb + Vector3(0.5, 0.0, -0.7), hb, 34.0)
		await d.fala("BERG", _l(["Lucas e Mari.", "...Tem uns nomes que a gente escuta por aqui.",
			"Esquece. Nome comum."]), berg)
	else:
		d.lente_presa(carro, hd + Vector3(-0.5, 0.0, -0.7), hd, 34.0)
		await d.eu(_l(["Ninguém. Eu ia sozinho."]))
		d.lente_presa(carro, hb + Vector3(0.5, 0.0, -0.7), hb, 34.0)
		await d.fala("BERG", _l(["Melhor. Ninguém sentindo sua falta, ninguém vindo te procurar.",
			"...Ou pior."]), berg)
	Cinema.tremor(0.0)


# --- 4B: o papel -------------------------------------------------------------------

static func _papel(d: DiretorMissao1, berg: Ator, carro: Carro, j: Player, rua: Vector3) -> void:
	# M1-C4B-01
	d.plano(PlanoCena.Tipo.CLOSE, berg, j, 0.0, {"lado": 1})
	await d.fala("BERG", _l(["Hm."]), berg)
	# M1-C4B-02: desencosta e tira o papel do bolso.
	d.plano(PlanoCena.Tipo.DOIS_MEDIO, berg, j, 0.0, {"lado": 1})
	await berg.fazer(Corpo.GestoCena.DESENCOSTAR)
	AudioDirector.tocar(&"papel", berg.global_position, -10.0)
	# M1-C4B-03: o papel caindo e pousando aos pes do jogador.
	var para_berg := berg.global_position - j.global_position
	para_berg.y = 0.0
	para_berg = para_berg.normalized()
	var pouso := j.global_position + para_berg * 0.45
	var lateral := para_berg.cross(Vector3.UP).normalized()
	berg.mirar_papel(pouso)
	var caiu: Array[BilheteNoAr] = [null]
	berg.papel_caiu.connect(func(p: BilheteNoAr) -> void: caiu[0] = p, CONNECT_ONE_SHOT)
	berg.fazer(Corpo.GestoCena.JOGAR_PAPEL, pouso)
	d.dolly(pouso + lateral * 0.9 + Vector3.UP * 1.1, pouso + lateral * 0.75 + Vector3.UP * 0.45,
		pouso + Vector3.UP * 0.7, pouso, 30.0, 2.5)
	await d.fala("BERG", _l(["Eu sei que você vai precisar."]), berg)
	var espera := 0.0
	while caiu[0] == null and espera < 4.0:
		await d.esperar(0.1)
		espera += 0.1
	d.papel = caiu[0]
	# M1-C4B-04: contorna a frente, a mao no capo, ate a porta do motorista.
	d.plano(PlanoCena.Tipo.ACOMPANHAMENTO, berg, null, 0.0, {})
	await berg.contornar_carro(carro, Carro.Banco.MOTORISTA)
	# M1-C4B-05: de tras do jogador, por cima do teto.
	var de := j.global_position - para_berg * 1.1 + Vector3.UP * 2.0
	await d.quadro(de, berg.global_position + Vector3.UP * 1.3, 50.0, 1.2)
	# M1-C4B-06: olha para o jogador por cima do teto.
	berg.encarar(j.global_position, true)
	berg.olhar_para(j)
	d.plano(PlanoCena.Tipo.CLOSE, berg, j, 1.5, {"lado": 1})
	await d.esperar(1.5)
	# M1-C4B-07: o indicador abaixa os oculos.
	d.plano(PlanoCena.Tipo.DOLLY_IN, berg, j, 2.0, {"lado": 1, "distancia": 1.1})
	await berg.fazer(Corpo.GestoCena.BAIXAR_OCULOS)
	# M1-C4B-08: os olhos a mostra; a risada.
	d.plano(PlanoCena.Tipo.CLOSE, berg, j, 0.0, {"lado": 1})
	await d.fala("BERG", _l(["Não vou me preocupar. Sei que você não vai longe."]), berg)
	berg.gargalhar(1)
	await d.esperar(1.4)
	# M1-C4B-09: de dentro, do banco do carona: senta, puxa a porta.
	var hd := _cabeca(carro, false)
	d.lente_presa(carro, hd + Vector3(0.05, 0.0, 0.05), _cabeca(carro, true) + Vector3(-0.2, -0.05, 0.0), 60.0)
	await berg.entrar_no_carro(carro, Carro.Banco.MOTORISTA)
	berg.fazer(Corpo.GestoCena.SUBIR_OCULOS)
	AudioDirector.tocar(&"motor_partida", carro.global_position, -4.0)
	await d.esperar(1.0)
	# M1-C4B-10: rente ao meio-fio, a roda desce da calcada. O passeio comeca.
	d.comecar_recusa()
	var roda := carro.global_transform * Vector3(2.4, 0.2, -1.0)
	d.quadro(roda, carro.global_transform * Vector3(0.8, 0.3, -1.3), 55.0)
	await d.esperar(2.0)
	# M1-C4B-11: da janela da casa, o jogador pequeno, o papel, o Marea indo.
	var janela := d.casa_porta.origin + Vector3.UP * 4.2 - rua * 0.4 + rua.cross(Vector3.UP) * 1.5
	d.dolly(janela, janela + Vector3.UP * 3.0, j.global_position, j.global_position + rua * 4.0, 55.0, 4.5)
	await d.esperar(3.0)
	# As tarjas saem com as lanternas ainda a vista.
	await d.sair_de_cena()
