## Rotina de verificacao da loja de conveniencia.
##
## Roda no jogo de verdade porque quase tudo que ela afirma so existe rodando: a
## loja e montada numa thread, o ambiente e trocado pelo controlador de nevoa, a
## porta automatica e um tween e o ponto de save le a posicao do corpo.
##
## Imprime linhas `[mercado] chave=valor` que tools/verificar_mercado.py confere.
class_name TesteMercado
extends RefCounted

const SEMENTE := 77451
const ESPERA_LONGA := 3.5
const ESPERA_CURTA := 0.4

## Superficies que precisam existir na loja montada. Sao o que separa a loja de
## uma sala branca com caixas: prateleira cheia, camara fria e vidro de vitrine.
const SUPERFICIES_EXIGIDAS: Array[StringName] = [
	&"mercado_prateleira_0", &"mercado_geladeira", &"mercado_vidro",
	&"mercado_piso", &"mercado_teto",
]


static func executar(cena: Node, jogador: Node3D) -> void:
	var arvore := cena.get_tree()
	await arvore.create_timer(1.0).timeout

	_relatar("inicio", 1)
	var retorno := jogador.global_transform

	Interiores.entrar(SEMENTE, retorno, &"mercado")
	await arvore.create_timer(ESPERA_LONGA).timeout
	_relatar("entrou", 1 if Interiores.dentro else 0)

	# A varredura da cidade vem depois de entrar, e nao antes, de proposito: ela
	# monta cento e quarenta chunks na thread principal e trava a imagem por
	# alguns segundos. Com o jogador parado na rua, esse tranco o deixava
	# encaixado no chao e a fisica passava a empurra-lo de lado para desencaixar.
	# Aqui dentro ele esta parado num piso recem criado e nada disso acontece.
	_medir_cidade()

	var interior := arvore.current_scene.get_node_or_null("Interior")
	if interior == null:
		_relatar("interior_ausente", 1)
		_encerrar(arvore)
		return

	_medir_loja(interior)
	_medir_servico(interior)
	_medir_planta(jogador)
	_medir_ambiente(arvore)
	await _testar_mercadoria(arvore, interior, jogador)
	await _testar_atendimento(arvore, interior, jogador)
	await _testar_terminal(arvore)

	# O portao vem antes da porta da frente porque ele TAMBEM sai para a rua. As
	# duas saidas precisam ser medidas a partir da mesma entrada, senao a segunda
	# estaria medindo o retorno que a primeira deixou.
	await _testar_portao(arvore, interior, jogador, retorno)

	Interiores.entrar(SEMENTE, retorno, &"mercado")
	await arvore.create_timer(ESPERA_LONGA).timeout
	_relatar("reentrou", 1 if Interiores.dentro else 0)
	interior = arvore.current_scene.get_node_or_null("Interior")
	if interior == null:
		_relatar("interior_ausente", 1)
		_encerrar(arvore)
		return
	await _testar_saida(arvore, interior, jogador, retorno)

	_relatar("fim", 1)
	_encerrar(arvore)


static func _encerrar(arvore: SceneTree) -> void:
	AudioDirector.silenciar_tudo()
	await arvore.process_frame
	arvore.quit(0)


static func _relatar(chave: String, valor: Variant) -> void:
	print("[mercado] %s=%s" % [chave, valor])


# --- cidade -----------------------------------------------------------------

## Conta as portas de cada tipo num pedaco da cidade, e confere que a loja tem
## fachada propria na rua.
##
## Verificar so o interior provaria metade: a loja pode estar perfeita e nenhuma
## porta levar ate ela, ou levar sem nada na fachada que diga que ali tem loja.
static func _medir_cidade() -> void:
	var por_tipo: Dictionary[StringName, int] = {}
	var deslizantes := 0
	var chunks_com_fachada := 0
	var chunks_com_portao := 0
	## Onde o portao caiu em relacao a porta da loja, medido pela calcada.
	var lateral_do_portao := 0.0
	## Quanto ele avanca sobre a calcada, a partir do plano da parede.
	var profundidade_do_portao := 0.0

	# Doze por doze chunks, quase 400 m de lado. Basta para pegar varios
	# distritos e nao custa os segundos que uma varredura maior custaria: cada
	# chunk aqui e montado inteiro, com geometria.
	for cx in range(-6, 6):
		for cz in range(-6, 6):
			var dados := ChunkBuilder.construir(cx, cz)
			var tem_loja := false
			var porta_da_loja: Dictionary = {}
			for prop: Dictionary in dados["props"]:
				if prop.get("tipo", "") != "porta":
					continue
				var tipo: StringName = prop.get("interior", &"apartamento")
				por_tipo[tipo] = int(por_tipo.get(tipo, 0)) + 1
				if bool(prop.get("deslizante", false)):
					deslizantes += 1
				if tipo == &"mercado":
					tem_loja = true
					porta_da_loja = prop
			# A fachada da loja entra na superficie do chunk, entao o chunk que
			# tem porta de mercado precisa ter tambem o letreiro aceso e — desde
			# que a loja ganhou garagem — o portao de servico ao lado dele. As
			# duas bocas do mesmo lugar tem de aparecer na mesma calcada, senao
			# o jogador sai por dentro do portao e cai na frente de uma parede.
			if tem_loja:
				var sup: Dictionary = dados["superficies"]
				if sup.has(&"mercado_letreiro") and not PSXMesh.dados_vazio(sup[&"mercado_letreiro"]):
					chunks_com_fachada += 1
				if sup.has(&"mercado_portao") and not PSXMesh.dados_vazio(sup[&"mercado_portao"]):
					chunks_com_portao += 1
					lateral_do_portao = _lateral_do_portao(sup, porta_da_loja)
					profundidade_do_portao = _profundidade_do_portao(
						sup, porta_da_loja)

	_relatar("portas_mercado", int(por_tipo.get(&"mercado", 0)))
	_relatar("portas_casa", int(por_tipo.get(&"casa", 0)))
	_relatar("portas_apartamento", int(por_tipo.get(&"apartamento", 0)))
	_relatar("portas_deslizantes", deslizantes)
	_relatar("chunks_com_fachada", chunks_com_fachada)
	_relatar("chunks_com_portao", chunks_com_portao)
	_relatar("lateral_do_portao", snappedf(lateral_do_portao, 0.01))
	_relatar("profundidade_do_portao", snappedf(profundidade_do_portao, 0.01))


## A que distancia o portao ficou do vao da porta, medido AO LONGO DA CALCADA.
##
## E a medida que nenhuma captura deu. A fachada tem duas bocas e a distancia
## entre elas sai de KitMercado.AFASTAMENTO_PORTAO em dois lugares diferentes:
## aqui, no desenho do chunk, e la dentro, no deslocamento com que a garagem
## cospe o jogador na rua. Se os dois discordarem de SINAL, o jogador atravessa
## o portao e aparece do outro lado da loja, na frente de uma parede — e as duas
## metades continuam certas quando olhadas em separado.
##
## O sinal e o que importa, e por isso a medida e projetada no eixo lateral da
## porta em vez de ser uma distancia. Distancia absoluta da o mesmo numero para
## os dois lados, que e exatamente o erro que ela precisaria pegar.
static func _lateral_do_portao(sup: Dictionary, porta: Dictionary) -> float:
	if porta.is_empty():
		return 0.0
	var giro := float(porta.get("giro", 0.0))
	var lateral := Vector3(cos(giro), 0.0, -sin(giro))
	# O centro da frente de loja fica uma folha adiante da batente esquerda, que
	# e o que o prop guarda. Ver ChunkBuilder._fachada_de_loja.
	var centro: Vector3 = Vector3(porta["pos"]) + lateral * Porta.FOLHA_LARGURA
	return (_centro_de(sup[&"mercado_portao"]) - centro).dot(lateral)


## Quanto o portao avanca sobre a calcada, a partir do plano da parede.
##
## E a segunda metade de `_lateral_do_portao`, e existe porque a primeira sozinha
## nao bastava. Uma fachada tem DOIS eixos, e a medida lateral fixa so um deles:
## com ela verde, o portao ainda podia estar treze centimetros dentro do predio,
## que foi exatamente onde ele passou uma noite inteira. Ele existia na malha, no
## lugar certo da calcada, com a luz de sodio acesa em cima — e a parede na
## frente. Nenhum dos quarenta e seis numeros se mexeu.
##
## O sinal e tudo: negativo quer dizer enterrado. O teto tambem importa, mas por
## outra razao — passando da vitrine, o portao deixa de ser a boca de servico ao
## lado da loja e vira um volume plantado na calcada.
##
## O zero da medida e o plano da PAREDE. O prop da porta guarda a batente ja
## empurrada pela saliencia da loja (ver _porta_do_chunk), entao ele volta para
## a parede aqui, e nao no chamador: quem le esta funcao precisa saber de onde o
## numero e contado.
static func _profundidade_do_portao(sup: Dictionary, porta: Dictionary) -> float:
	if porta.is_empty():
		return 0.0
	var giro := float(porta.get("giro", 0.0))
	var normal := Vector3(sin(giro), 0.0, cos(giro))
	var parede: Vector3 = (Vector3(porta["pos"])
		- normal * (KitMercado.SALIENCIA + 0.02))
	return (_centro_de(sup[&"mercado_portao"]) - parede).dot(normal)


## Centro da caixa envolvente de uma superficie acumulada.
##
## Le os vertices do dicionario do PSXMesh e nao o AABB de um no: aqui nao ha no
## nenhum, o chunk nunca entrou na arvore. Que e uma sorte — AABB de MeshInstance
## nao e confiavel no renderizador de compatibilidade.
static func _centro_de(dados: Dictionary) -> Vector3:
	# A chave e "v", e nao "vertices" — ver PSXMesh.dados_vazios. Escrita errada
	# ela nao estoura: devolve um array vazio, o centro sai na origem e a medida
	# vira um numero plausivel e falso. Foi o que aconteceu na primeira versao
	# desta funcao, e por vinte minutos pareceu que o portao e que estava torto.
	var vs: PackedVector3Array = dados["v"]
	if vs.is_empty():
		return Vector3.ZERO
	var mn := vs[0]
	var mx := vs[0]
	for v: Vector3 in vs:
		mn = mn.min(v)
		mx = mx.max(v)
	return (mn + mx) * 0.5


# --- loja montada -----------------------------------------------------------

static func _medir_loja(interior: Node) -> void:
	var tris := 0
	var superficies: Array[String] = []
	var luzes := 0
	var saves := 0
	var itens := 0

	for filho: Node in interior.get_children():
		if filho is MeshInstance3D:
			superficies.append(filho.name)
			tris += PSXMesh.triangle_count((filho as MeshInstance3D).mesh)
		elif filho is Lampada:
			luzes += 1
		elif filho is PontoDeSave:
			saves += 1
		elif filho is ItemNoChao:
			itens += 1

	_relatar("tris", tris)
	_relatar("luzes", luzes)
	_relatar("ponto_de_save", saves)
	_relatar("itens", itens)

	var corpo := interior.get_node_or_null("Colisao")
	_relatar("colisores", corpo.get_child_count() if corpo != null else 0)

	# Todas as fontes de luz do comodo, e nao so as `Lampada`.
	#
	# O renderizador nao sabe da diferenca entre uma Lampada e a OmniLight crua
	# que o leitor do balcao usa: para ele sao duas luzes disputando o mesmo
	# limite por objeto. Contar so as Lampada media 13 num comodo que tem 14, e
	# a conta que importa e a que o motor faz.
	_relatar("luzes_totais", _contar_luzes(interior))

	var faltando: Array[String] = []
	for exigida: StringName in SUPERFICIES_EXIGIDAS:
		if not superficies.has(String(exigida)):
			faltando.append(String(exigida))
	_relatar("superficies", superficies.size())
	_relatar("superficies_faltando", faltando.size())
	if not faltando.is_empty():
		_relatar("faltou", ",".join(faltando))


## Quantas OmniLight3D existem na subarvore, em qualquer profundidade.
##
## Recursiva porque as fontes nao estao todas no mesmo nivel: a `Lampada` e um
## Node3D que PENDURA uma OmniLight dentro de si, e a do leitor do balcao esta
## dois niveis abaixo, dentro do no de atendimento.
static func _contar_luzes(no: Node) -> int:
	var total := 0
	for filho: Node in no.get_children():
		if filho is OmniLight3D or filho is SpotLight3D:
			total += 1
		total += _contar_luzes(filho)
	return total


## A loja pede o proprio ambiente: branco e chapado, contra o quente e baixo da
## casa. Metade do efeito do comodo esta ai, entao vale conferir.
static func _medir_ambiente(arvore: SceneTree) -> void:
	var fog := arvore.get_first_node_in_group(&"fog_controller") as FogController
	if fog == null:
		_relatar("fog_ausente", 1)
		return
	_relatar("ambiente", String(fog.preset_ativo()))


# --- mercadoria -------------------------------------------------------------

static func _testar_mercadoria(arvore: SceneTree, interior: Node,
		jogador: Node3D) -> void:
	Inventario.de_dicionario({"espacos": [], "vida": 100})
	await arvore.process_frame

	var item: ItemNoChao = null
	for filho: Node in interior.get_children():
		if filho is ItemNoChao:
			item = filho
			break
	if item == null:
		_relatar("item_ausente", 1)
		return

	var id: StringName = item.item_id
	item.interagir(jogador)
	await arvore.create_timer(ESPERA_CURTA).timeout
	_relatar("pegou_da_prateleira", 1 if Inventario.tem(id) else 0)


# --- saida ------------------------------------------------------------------

static func _testar_saida(arvore: SceneTree, interior: Node, jogador: Node3D,
		retorno: Transform3D) -> void:
	var saida := interior.get_node_or_null("Saida") as Interativo
	if saida == null:
		_relatar("saida_ausente", 1)
		return

	# Porta automatica: duas folhas de vidro penduradas num no orientado.
	var porta := saida.get_node_or_null("PortaAutomatica")
	_relatar("porta_automatica", 1 if porta != null else 0)
	_relatar("folhas", porta.get_child_count() if porta != null else 0)

	var folha: Node3D = null
	var antes := 0.0
	if porta != null and porta.get_child_count() > 0:
		folha = porta.get_child(0) as Node3D
		antes = folha.position.x

	# A rua e esvaziada antes de sair. Mesma razao do teste da casa: a medida
	# abaixo e de POSICAO do jogador, e um corpo encostado nele a desloca pela
	# recuperacao de penetracao do motor.
	Multidao.parar()
	saida.interagir(jogador)
	# A folha e medida no meio da animacao, e nao no fim: sair libera o interior
	# inteiro, e a essa altura o no ja nao existe para ser consultado.
	await arvore.create_timer(0.42).timeout
	if folha != null and is_instance_valid(folha):
		_relatar("folha_correu",
			1 if absf(folha.position.x - antes) > 0.25 else 0)

	await arvore.create_timer(ESPERA_LONGA).timeout
	_relatar("saiu", 0 if Interiores.dentro else 1)
	_relatar("dist_do_retorno",
		snappedf(jogador.global_position.distance_to(retorno.origin), 0.01))
	# Separado porque as duas coisas falham por motivos diferentes. Deslocamento
	# no plano quer dizer que o retorno foi gravado ou restaurado errado; queda
	# quer dizer so que a pose gravada estava no ar e o corpo assentou no chao,
	# que e o comportamento certo.
	var plano := Vector2(jogador.global_position.x - retorno.origin.x,
		jogador.global_position.z - retorno.origin.z)
	_relatar("desvio_no_plano", snappedf(plano.length(), 0.01))
	_relatar("queda", snappedf(retorno.origin.y - jogador.global_position.y, 0.01))

	var fog := arvore.get_first_node_in_group(&"fog_controller") as FogController
	if fog != null:
		_relatar("ambiente_apos_sair", String(fog.preset_ativo()))


# --- bloco de servico -------------------------------------------------------

## Superficies que so existem por causa dos fundos. Sao o que separa "a loja
## ganhou mais metro quadrado" de "a loja ganhou o lado de dentro dela": azulejo
## de banheiro, estante de deposito, papelao de entrega, cortica de quadro de
## avisos, folha de portao e a tela do computador.
##
## `mercado_portao` NAO entra aqui, e nao por esquecimento: dentro da garagem a
## folha do portao e um no que sobe, e nao uma superficie da malha fundida. Quem
## prova que ela existe e `portao_folha_subiu`, e quem prova que o portao aparece
## na rua e `chunks_com_portao`.
const SUPERFICIES_SERVICO: Array[StringName] = [
	&"mercado_azulejo", &"mercado_estoque", &"mercado_papelao",
	&"mercado_avisos", &"mercado_terminal", &"concreto", &"piso_ceramico",
]

## Pontos onde uma pessoa em pe tem de caber, em coordenada de planta.
##
## E a medida que nenhuma outra faz. Contar triangulo, colisor e superficie prova
## que a geometria existe; nao prova que ela tem BURACO onde deveria. Uma parede
## fechada por engano na frente da porta de servico passaria por todos os outros
## numeros deste arquivo com nota cheia, e o jogador esbarraria no nada.
const POUSOS: Array[Dictionary] = [
	{"nome": "salao", "pos": Vector3(12.8, 0.95, 1.7)},
	{"nome": "corredor_central", "pos": Vector3(12.8, 0.95, 7.2)},
	{"nome": "fila_do_caixa", "pos": Vector3(9.6, 0.95, 3.0)},
	# Ao SUL da registradora. O ponto media a faixa de trabalho do atendente e
	# passou a cair em cima do proprio atendente quando o balcao foi agrupado na
	# ponta norte — e um corpo em pe nao e defeito de planta, e o que a planta
	# existe para caber. A medida continua sendo da arquitetura: e o mesmo
	# corredor, um metro e meio antes.
	{"nome": "atras_do_balcao", "pos": Vector3(7.2, 0.95, 3.2)},
	{"nome": "corredor_servico", "pos": Vector3(3.3, 0.95, 7.0)},
	{"nome": "garagem", "pos": Vector3(3.3, 0.95, 2.6)},
	{"nome": "banheiro", "pos": Vector3(1.5, 0.95, 9.6)},
	{"nome": "copa", "pos": Vector3(5.05, 0.95, 9.4)},
]

## Travessias que precisam estar ABERTAS, em coordenada de planta.
##
## Cada uma atravessa um vao de porta. Se a verga, a folha ou a colisao de parede
## invadirem o vao, o raio bate e a linha reporta zero — que e exatamente o
## defeito que nao aparece em captura, porque de longe a porta parece uma porta.
const TRAVESSIAS: Array[Dictionary] = [
	{"nome": "caixa_para_corredor",
		"de": Vector3(7.5, 1.0, 6.6), "ate": Vector3(5.2, 1.0, 6.6)},
	{"nome": "corredor_para_garagem",
		"de": Vector3(3.3, 1.0, 7.0), "ate": Vector3(3.3, 1.0, 4.6)},
	{"nome": "corredor_para_banheiro",
		"de": Vector3(1.55, 1.0, 7.6), "ate": Vector3(1.55, 1.0, 9.4)},
	{"nome": "corredor_para_copa",
		"de": Vector3(5.05, 1.0, 7.6), "ate": Vector3(5.05, 1.0, 9.4)},
]

## E a travessia que precisa estar FECHADA: o vao do portao, com ele abaixado.
##
## Sem este bloco o jogador andaria para fora da planta, e do outro lado do
## portao nao ha cidade — ha dois mil metros de ar. O portao so se atravessa
## acionando, porque aciona-lo ja e sair para a rua.
const BARRADA := {"de": Vector3(3.3, 1.0, 2.2), "ate": Vector3(3.3, 1.0, -0.6)}


static func _medir_servico(interior: Node) -> void:
	var superficies: Array[String] = []
	var batentes := 0
	var portoes := 0
	var computadores := 0

	for filho: Node in interior.get_children():
		if filho is MeshInstance3D:
			superficies.append(filho.name)
		elif filho is Interativo:
			if filho.name.begins_with("PortaBatente"):
				batentes += 1
			elif filho.name.begins_with("PortaoGaragem"):
				portoes += 1
			elif filho.name.begins_with("Computador"):
				computadores += 1

	var faltando: Array[String] = []
	for exigida: StringName in SUPERFICIES_SERVICO:
		if not superficies.has(String(exigida)):
			faltando.append(String(exigida))
	_relatar("servico_faltando", faltando.size())
	if not faltando.is_empty():
		_relatar("faltou_servico", ",".join(faltando))

	# Tres portas de folha: a de servico atras do caixa, a do banheiro e a da
	# copa. O vao para a garagem nao tem folha de proposito — e o caminho que o
	# funcionario faz com as maos ocupadas.
	_relatar("portas_batente", batentes)
	_relatar("portao_garagem", portoes)
	_relatar("computador", computadores)


## Espaco livre e passagem, medidos com a fisica de verdade.
static func _medir_planta(jogador: Node3D) -> void:
	var espaco := jogador.get_world_3d().direct_space_state
	var desloc := Interiores.DESLOCAMENTO

	var forma := SphereShape3D.new()
	# Trinta e cinco centimetros de raio: um pouco mais estreito que uma pessoa,
	# para a medida ser "cabe alguem aqui" e nao "cabe alguem aqui com folga de
	# arquiteto". Vao de porta de 90 cm tem de passar.
	forma.radius = 0.35
	var ocupados: Array[String] = []
	for pouso: Dictionary in POUSOS:
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = forma
		q.transform = Transform3D(Basis.IDENTITY, desloc + Vector3(pouso["pos"]))
		q.collision_mask = 1
		q.exclude = [jogador.get_rid()]
		if not espaco.intersect_shape(q, 1).is_empty():
			ocupados.append(String(pouso["nome"]))
	_relatar("pousos_ocupados", ocupados.size())
	if not ocupados.is_empty():
		_relatar("ocupado", ",".join(ocupados))

	var fechadas: Array[String] = []
	for t: Dictionary in TRAVESSIAS:
		var r := PhysicsRayQueryParameters3D.create(
			desloc + Vector3(t["de"]), desloc + Vector3(t["ate"]))
		r.collision_mask = 1
		r.exclude = [jogador.get_rid()]
		if not espaco.intersect_ray(r).is_empty():
			fechadas.append(String(t["nome"]))
	_relatar("travessias_fechadas", fechadas.size())
	if not fechadas.is_empty():
		_relatar("travessia_fechada", ",".join(fechadas))

	var r_portao := PhysicsRayQueryParameters3D.create(
		desloc + Vector3(BARRADA["de"]), desloc + Vector3(BARRADA["ate"]))
	r_portao.collision_mask = 1
	r_portao.exclude = [jogador.get_rid()]
	_relatar("portao_barra", 0 if espaco.intersect_ray(r_portao).is_empty() else 1)


# --- computador do balcao ---------------------------------------------------

## A consulta por CPF no monitor do caixa.
##
## Nao inventa numero: pega o CPF de uma pessoa que o registro civil ja tem e
## confere que a ficha que volta e a DAQUELA pessoa. E o que prova que o terminal
## le o mesmo banco que a carteira do NPC e o portal do celular, em vez de
## desenhar uma ficha bonita e vazia.
static func _testar_terminal(arvore: SceneTree) -> void:
	Terminal.abrir()
	await arvore.create_timer(ESPERA_CURTA).timeout
	_relatar("terminal_abriu", 1 if Terminal.ativo else 0)

	var id := RegistroCivil.id_de_transeunte(90210)
	var esperada := RegistroCivil.identidade(id)
	var achou := Terminal.consultar_cpf(RegistroCivil.cpf_de(id))
	await arvore.process_frame
	_relatar("terminal_consultou", 1 if achou else 0)
	_relatar("terminal_ficha_confere",
		1 if Terminal.ficha_aberta().get("id", -1) == id else 0)
	_relatar("terminal_tem_foto", 1 if Terminal.tem_foto() else 0)
	# O terminal tem de recusar numero inventado pela mesma razao que o portal
	# recusa: o CPF e o endereco da ficha, e nao um sorteio.
	_relatar("terminal_recusa_invalido",
		0 if Terminal.consultar_cpf("11111111111") else 1)
	_relatar("terminal_vinculos", RegistroCivil.vinculos(id).size())

	# Nome, mae e endereco tem de bater com o que a carteira mostraria.
	_relatar("terminal_mesma_mae",
		1 if Terminal.ficha_aberta().get("mae", "") == esperada["mae"] else 0)

	Terminal.fechar()
	await arvore.create_timer(ESPERA_CURTA).timeout
	_relatar("terminal_fechou", 0 if Terminal.ativo else 1)


# --- portao da garagem ------------------------------------------------------

## Sair pelo portao devolve o jogador na calcada, AO LADO da porta da loja.
##
## A medida e feita no referencial da fachada e nao em metros soltos: o que
## importa nao e "andou seis metros", e "andou seis metros PARA O LADO e um pouco
## para a rua". Um sinal trocado poria o jogador dentro do predio vizinho, e a
## distancia absoluta seria a mesma.
static func _testar_portao(arvore: SceneTree, interior: Node, jogador: Node3D,
		retorno: Transform3D) -> void:
	var portao: Interativo = null
	for filho: Node in interior.get_children():
		if filho is Interativo and filho.name.begins_with("PortaoGaragem"):
			portao = filho
			break
	if portao == null:
		_relatar("portao_ausente", 1)
		return

	var folha := portao.get_node_or_null("Folha") as Node3D
	var antes := folha.scale.y if folha != null else -1.0

	Multidao.parar()
	portao.interagir(jogador)
	# A folha e medida no meio da subida: sair libera o interior inteiro, e
	# depois disso o no ja nao existe para ser consultado.
	await arvore.create_timer(0.4).timeout
	if folha != null and is_instance_valid(folha):
		_relatar("portao_folha_subiu", 1 if folha.scale.y < antes - 0.2 else 0)

	await arvore.create_timer(ESPERA_LONGA).timeout
	_relatar("saiu_pelo_portao", 0 if Interiores.dentro else 1)

	var d := jogador.global_position - retorno.origin
	_relatar("portao_lateral", snappedf(d.dot(retorno.basis.x), 0.01))
	_relatar("portao_afastou", snappedf(d.dot(retorno.basis.z), 0.01))
	_relatar("portao_queda", snappedf(retorno.origin.y - jogador.global_position.y, 0.01))


# --- atendimento no balcao --------------------------------------------------

## A sequencia inteira do caixa: carteira, leitor, camera, terminal.
##
## O que ela prova que nenhuma captura prova: que a carteira em cima do balcao e
## a do CLIENTE parado ali. As duas pessoas saem de `id_de_faixa` chamado em dois
## arquivos diferentes, com a semente e a faixa combinadas so por convencao (ver
## MercadoBuilder.SAL_DO_CLIENTE). Se um dos dois lados mudar, o balcao continua
## funcionando perfeitamente e passa a mostrar a carteira de um desconhecido —
## e o jogo nao teria como reclamar.
static func _testar_atendimento(arvore: SceneTree, interior: Node,
		jogador: Node3D) -> void:
	var balcao := interior.get_node_or_null("AtendimentoBalcao")
	if balcao == null:
		_relatar("atendimento_ausente", 1)
		return

	var carteira := balcao.get_node_or_null("Identidade") as Interativo
	var leitor := balcao.get_node_or_null("Leitor") as Interativo
	_relatar("balcao_tem_carteira", 1 if carteira != null else 0)
	_relatar("balcao_tem_leitor", 1 if leitor != null else 0)
	_relatar("balcao_tem_luz",
		1 if balcao.get_node_or_null("LuzLeitor") != null else 0)
	if carteira == null or leitor == null:
		return

	# O leitor nasce desligado: ele so tem o que ler depois da carteira aberta.
	_relatar("leitor_comeca_travado", 0 if leitor.habilitado else 1)

	# --- a carteira e do cliente do balcao ---
	var id_carteira := int(balcao.get_meta(&"id_da_carteira", -1))
	var ids_no_comodo: Array[int] = []
	for filho: Node in interior.get_children():
		if filho is Convidado:
			var f: Dictionary = (filho as Convidado).ficha
			if not f.is_empty():
				ids_no_comodo.append(int(f["id"]))
	_relatar("gente_no_balcao", ids_no_comodo.size())
	_relatar("carteira_e_de_quem_esta_ali",
		1 if ids_no_comodo.has(id_carteira) else 0)
	var rota := 0
	for filho: Node in interior.get_children():
		if filho is Convidado and (filho as Convidado).rotina == &"compra":
			rota = 1
			(filho as Convidado).ir_ao_caixa()
	_relatar("cliente_tem_rota_de_compra", rota)
	await arvore.process_frame
	_relatar("compra_no_balcao",
		1 if interior.get_node_or_null("CompraBalcao") != null else 0)

	# --- abrir a carteira arma o leitor ---
	carteira.interagir(jogador)
	await arvore.create_timer(ESPERA_CURTA).timeout
	_relatar("carteira_abriu_documento", 1 if Documento.ativo else 0)
	Documento.fechar()
	await arvore.create_timer(ESPERA_CURTA).timeout
	_relatar("leitor_armou", 1 if leitor.habilitado else 0)

	# --- passar no leitor leva ao terminal, ja na ficha certa ---
	var giro_antes := jogador.rotation.y
	leitor.interagir(jogador)
	# Tres bipes de 0,24 s mais meio segundo de camera, com folga.
	await arvore.create_timer(1.8).timeout
	_relatar("leitor_abriu_terminal", 1 if Terminal.ativo else 0)
	_relatar("terminal_veio_com_o_cliente",
		1 if int(Terminal.ficha_aberta().get("id", -1)) == id_carteira else 0)
	# A camera tem de ter virado. Em graus, e nao em radianos: a folga de
	# tolerancia fica legivel para quem for ajustar o balcao depois.
	_relatar("camera_virou",
		snappedf(absf(rad_to_deg(wrapf(jogador.rotation.y - giro_antes,
			-PI, PI))), 0.1))

	# --- busca por nome, com o cliente como cobaia ---
	var f_cliente := RegistroCivil.identidade(id_carteira)
	var primeiro := String(f_cliente.get("primeiro", ""))
	_relatar("busca_por_nome_acha",
		1 if RegistroCivil.buscar_por_nome(primeiro).has(id_carteira) else 0)
	# Nome curto demais nao busca: com duas letras a lista deixa de ser resposta.
	_relatar("busca_por_nome_curta_recusa",
		1 if RegistroCivil.buscar_por_nome("AN").is_empty() else 0)
	# Nome que nao existe no indice local devolve vazio, e nao a cidade inteira.
	_relatar("busca_por_nome_invento",
		1 if RegistroCivil.buscar_por_nome("ZQXWJ").is_empty() else 0)

	Terminal.fechar()
	await arvore.create_timer(ESPERA_CURTA).timeout

	# --- o caminho em que o terminal RECUSA abrir ---
	#
	# E o buraco que mais custava caro e o que menos aparecia. A sequencia trava
	# o jogador para virar a camera e contava com o terminal para destrava-lo;
	# `Terminal.abrir` recusa em silencio quando ha telefone na mao, conversa em
	# andamento ou o jogo esta pausado, e nesses casos ninguem mais viria. O
	# jogador ficava preso olhando para o monitor, sem tecla que resolvesse.
	#
	# A carteira aberta em tela cheia e a maneira mais barata de reproduzir a
	# recusa dentro de um teste: `Documento.ativo` derruba `pode_abrir`.
	Documento.abrir(f_cliente)
	await arvore.process_frame
	leitor.interagir(jogador)
	await arvore.create_timer(1.8).timeout
	_relatar("leitor_recusado_abriu_terminal", 1 if Terminal.ativo else 0)
	_relatar("leitor_recusado_nao_travou",
		0 if bool(jogador.get("travado")) else 1)
	Documento.fechar()
	await arvore.create_timer(ESPERA_CURTA).timeout

	if jogador.has_method("travar"):
		jogador.call("travar", false)
