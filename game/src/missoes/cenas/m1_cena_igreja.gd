## Missao 1, Cenas 6B e 7: na igreja e a frente da capela (os dois caminhos).
##
## 6B so no ramo da recusa: o jogador fala com o Berg na praca. Os dois ramos
## terminam no mesmo C7, com os dois ao pe da escadaria (`Lugares.igreja`).
class_name M1CenaIgreja
extends RefCounted

## Altura das duas linhas do titulo do C7-09, em fracao da tela.
const TITULO_ALTO := 0.062
const SUBTITULO_ALTO := 0.026


static func rodar(d: DiretorMissao1, de_carona: bool) -> void:
	var berg := d.berg
	var j := d.jogador()
	var ig := Lugares.igreja()
	# Os pontos da igreja vem sem o relevo: tudo sobe junto com o chao do pe.
	var pe_cru: Vector3 = ig["frente"]
	var pe := d.no_chao(pe_cru)
	var dy := Vector3.UP * (pe.y - pe_cru.y)
	var porta: Vector3 = ig["mundo"] + dy
	berg.rotulo = ""
	berg.olhar_para(j)
	d.entrar_em_cena()

	if not de_carona:
		# M1-C6B-01: da escadaria, olhando a praca: o jogador chegando, o Berg
		# de costas em primeiro plano.
		berg.andar_ate(berg.global_position)
		d.virar_jogador(berg.global_position)
		var degrau := pe + Vector3(0.0, 1.4, -1.4)
		await d.quadro(degrau, berg.global_position.lerp(j.global_position, 0.6) + Vector3.UP * 1.2,
			68.0, 3.0)
		# M1-C6B-02: vira, um sorriso enorme.
		berg.encarar(j.global_position, true)
		d.plano(PlanoCena.Tipo.CLOSE, berg, j, 0.0, {"lado": 1})
		await d.fala("BERG", _l(["Olha só quem apareceu."]), berg)
		# M1-C6B-03
		d.plano(PlanoCena.Tipo.DOIS_MEDIO, berg, j, 0.0, {"lado": 1})
		berg.gargalhar(1)
		await d.fala("BERG", _l(["Falei. Ninguém vai longe aqui.",
			"Deu a volta no mundo e caiu no mesmo lugar."]), berg)
		# M1-C6B-04: serio, indica a igreja com a cabeca.
		d.plano(PlanoCena.Tipo.CLOSE, berg, j, 0.0, {"lado": -1})
		await d.fala("BERG", _l(["Vem. Quero te mostrar uma coisa."]), berg)

	# Os dois ao pe da escadaria, no corte preto.
	await d.corte_preto(0.4)
	if berg.fumando():
		berg.jogar_bituca()
	berg.global_position = d.no_chao(pe + DiretorMissao1.FRENTE_BERG)
	berg.encarar(porta)
	d.por_jogador(pe + DiretorMissao1.FRENTE_JOGADOR, porta)
	await d.esperar(0.1)

	# M1-C7-01: de longe, do outro lado da praca; a capela enorme no alto do
	# quadro, os dois pequenos. Dolly lento de 3 m.
	var centro: Vector3 = ig["centro"] + dy
	var torre := centro + Vector3.UP * 9.0
	var longe := pe + Vector3(0.0, 0.7, 24.0)
	await d.dolly(longe, longe - Vector3(0.0, 0.0, 3.0), torre, torre, 68.0, 5.0)
	# M1-C7-02: de costas para a lente, olhando a torre.
	await d.quadro(pe + Vector3(0.2, 1.55, 5.2), torre, 50.0, 3.0)
	# M1-C7-03: aponta o calcamento, o lugar do pino.
	var pino: Vector3 = ig["pino"] + dy
	berg.encarar(pino, true)
	d.plano(PlanoCena.Tipo.CLOSE, berg, j, 0.0, {"lado": 1})
	d.gesto(berg, Corpo.GestoCena.APONTAR, pino)
	await d.fala("BERG", _l(["Foi ali que cê acordou. Ó. Bem ali."]), berg)
	# M1-C7-04: do alto, o calcamento vazio; o zumbido da abertura volta.
	d.quadro(pino + Vector3(0.0, 9.0, 3.5), pino, 55.0)
	AudioDirector.tocar_ui(&"zumbido_loop", -24.0)
	await d.fala("BERG", _l(["Eu acordei no mesmo lugar. Na mesma pedra."]), berg)
	# M1-C7-05
	d.virar_jogador(pino)
	d.plano(PlanoCena.Tipo.CLOSE, j, berg, 2.0, {"lado": 1})
	await d.esperar(2.0)
	# M1-C7-06: contra a torre iluminada.
	berg.encarar(j.global_position, true)
	d.plano(PlanoCena.Tipo.CONTRA_PLONGEE, berg, j, 0.0, {"lado": 1})
	await d.fala("BERG", _l(["Cidade sem fim, sem placa, sem saída... e todo mundo acorda aqui.",
		"Isso não é coincidência, sô."]), berg)
	if bool(Borboleta.valor(&"m1_contou_do_padre_ao_berg", false)):
		# M1-C7-06v
		d.plano(PlanoCena.Tipo.CLOSE, berg, j, 0.0, {"lado": -1})
		await d.fala("BERG", _l(["Se ele tá esperando alguém, é aqui dentro."]), berg)
	# M1-C7-07: sobe dois degraus, vira, abaixa os oculos.
	d.virar_jogador(berg.global_position)
	d.plano(PlanoCena.Tipo.SOBRE_OMBRO, berg, j, 0.0, {"lado": 1})
	await berg.andar_ate(pe + Vector3(-0.5, 0.0, -0.95))
	berg.encarar(j.global_position)
	await berg.fazer(Corpo.GestoCena.BAIXAR_OCULOS)
	await d.fala("BERG", _l(["Amanhã a gente entra. Hoje cê dorme. Cê vai precisar."]), berg)
	berg.fazer(Corpo.GestoCena.SUBIR_OCULOS)

	# M1-C7-08: a grua sobe pela fachada ate acima da torre; a cidade e nevoa.
	var de := pe + Vector3(0.0, 2.0, 6.0)
	var ate := centro + Vector3(0.0, 45.0, 16.0)
	d.dolly(de, ate, centro + Vector3.UP * 5.0, centro + Vector3(0.0, 24.0, -60.0), 60.0, 8.0)
	await d.esperar(1.5)
	AudioDirector.tocar(&"sino_igreja", centro + Vector3.UP * 14.0, -4.0, 0.8)
	await d.esperar(5.0)
	await Cinema.escurecer(1.5)

	# M1-C7-09: preto, o titulo.
	var cartao := _titulo(d.get_viewport().get_visible_rect().size.y)
	d.get_tree().root.add_child(cartao)
	AudioDirector.tocar_ui(&"celular_ok", -6.0)
	await d.esperar(3.5)
	var t := cartao.create_tween()
	t.tween_property(cartao.get_child(0), "modulate:a", 0.0, 0.6)
	await t.finished
	cartao.queue_free()

	# O controle volta na praca, o Berg encostado no carro.
	if d.carro != null and is_instance_valid(d.carro):
		var vaga: Transform3D = d.carro.global_transform
		berg.global_position = d.no_chao(vaga * Vector3(-1.6, 0.0, -1.2))
	d.por_jogador(pe + DiretorMissao1.FRENTE_JOGADOR + Vector3(0.0, 0.0, 2.5), pe + Vector3(0.0, 0.0, 12.0))
	await d.sair_de_cena()
	await Cinema.clarear(0.6)
	d.concluir()


static func _l(linhas: Array) -> Array[String]:
	var saida: Array[String] = []
	for l: Variant in linhas:
		saida.append(String(l))
	return saida


## "MISSAO CONCLUIDA / VOCE NAO VAI LONGE" centralizado, acima da cortina do
## Cinema (camada 145).
static func _titulo(altura_tela: float) -> CanvasLayer:
	var camada := CanvasLayer.new()
	camada.name = "TituloM1"
	camada.layer = 150
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(raiz)
	var caixa := VBoxContainer.new()
	caixa.set_anchors_preset(Control.PRESET_CENTER)
	caixa.alignment = BoxContainer.ALIGNMENT_CENTER
	caixa.grow_horizontal = Control.GROW_DIRECTION_BOTH
	caixa.grow_vertical = Control.GROW_DIRECTION_BOTH
	raiz.add_child(caixa)
	# A fonte da legenda do Cinema, em vetor: o titulo tem de ler igual em 4K.
	var linhas := [["MISSÃO CONCLUÍDA", SUBTITULO_ALTO, Color("ebe3cc", 0.7)],
		[DiretorMissao1.TITULO, TITULO_ALTO, Color("ebe3cc")]]
	for l: Array in linhas:
		var rot := Label.new()
		rot.text = String(l[0])
		rot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rot.add_theme_font_override(&"font", UiEstilo.fonte_re7(UiEstilo.RE7_WEIGHT_SEMIBOLD))
		rot.add_theme_font_size_override(&"font_size", maxi(8, roundi(altura_tela * float(l[1]))))
		rot.add_theme_color_override(&"font_color", l[2] as Color)
		caixa.add_child(rot)
	return camada
