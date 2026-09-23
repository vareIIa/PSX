## Rotina de verificacao da loja de conveniencia.
##
## Roda no jogo de verdade porque quase tudo que ela afirma so existe rodando: a
## loja e montada numa thread, a porta ve quem chega pela fisica, o ambiente e
## trocado pela soleira e o cliente anda pela malha de navegacao.
##
## Dois modos
## ----------
##   (padrao)      a loja que EXISTE NA RUA (PLANO_MERCADO_AAA, F1). O teste
##                 ANDA: da calcada, pela porta automatica, ate a camara fria,
##                 apertando a tecla de andar. Nenhuma linha chama
##                 `Interiores.entrar`; se a porta nao abrir, ele esbarra no vidro
##                 e o numero diz.
##   --teleporte   o comodo teleportado que a abertura ainda usa: a mesma planta,
##                 com a frente fosca, dois mil metros acima da cidade.
##
## Imprime linhas `[mercado] chave=valor` que tools/verificar_mercado.py confere.
## Com janela, fotografa em captures/mercado_aaa/f1/.
class_name TesteMercado
extends RefCounted

const SEMENTE := 77451
const ESPERA_LONGA := 3.5
const ESPERA_CURTA := 0.4
## Raio da varredura da cidade, em chunks. O criterio da F1 pede dez lojas nele.
const RAIO_CIDADE := 12
const PASTA_CAPTURA := "captures/mercado_aaa/f1"
## As fotos do produto (F2) vao para a pasta da fase delas.
const PASTA_F2 := "captures/mercado_aaa/f2"
static var _pasta := PASTA_CAPTURA

## Superficies que precisam existir na loja montada. Sao o que separa a loja de
## uma sala branca com caixas: prateleira cheia, camara fria e o piso da loja.
const SUPERFICIES_EXIGIDAS: Array[StringName] = [
	&"mercado_chapa", &"mercado_espinha", &"mercado_luz",
	&"mercado_piso", &"mercado_teto",
]

## Superficies que so existem por causa dos fundos.
const SUPERFICIES_SERVICO: Array[StringName] = [
	&"mercado_azulejo", &"mercado_estoque", &"mercado_papelao",
	&"mercado_avisos", &"mercado_terminal", &"concreto", &"piso_ceramico",
]

## Pontos onde uma pessoa em pe tem de caber, em coordenada de planta.
##
## Contar triangulo e colisor prova que a geometria existe; nao prova que ela tem
## BURACO onde deveria. Uma parede fechada por engano na frente de uma porta
## passaria por todos os outros numeros, e o jogador esbarraria no nada.
const POUSOS: Array[Dictionary] = [
	{"nome": "salao", "pos": Vector3(11.0, 0.95, 1.9)},
	{"nome": "corredor_central", "pos": Vector3(11.0, 0.95, 6.0)},
	{"nome": "fila_do_caixa", "pos": Vector3(7.3, 0.95, 3.4)},
	{"nome": "atras_do_balcao", "pos": Vector3(5.25, 0.95, 4.9)},
	{"nome": "corredor_servico", "pos": Vector3(8.0, 0.95, 11.6)},
	{"nome": "garagem", "pos": Vector3(2.3, 0.95, 2.4)},
	{"nome": "banheiro", "pos": Vector3(1.4, 0.95, 13.4)},
	{"nome": "copa", "pos": Vector3(5.3, 0.95, 13.6)},
	{"nome": "escritorio", "pos": Vector3(9.4, 0.95, 13.6)},
	{"nome": "estoque", "pos": Vector3(12.9, 0.95, 13.4)},
]

## Travessias que precisam estar ABERTAS, em coordenada de planta. Cada uma
## atravessa um vao: se a verga, a folha ou a colisao de parede invadirem o vao,
## o raio bate e a linha acusa.
const TRAVESSIAS: Array[Dictionary] = [
	{"nome": "salao_para_corredor",
		"de": Vector3(5.7, 1.0, 9.9), "ate": Vector3(5.7, 1.0, 11.6)},
	{"nome": "corredor_para_garagem",
		"de": Vector3(2.3, 1.0, 11.6), "ate": Vector3(2.3, 1.0, 9.6)},
	{"nome": "corredor_para_banheiro",
		"de": Vector3(1.4, 1.0, 11.6), "ate": Vector3(1.4, 1.0, 13.4)},
	{"nome": "corredor_para_copa",
		"de": Vector3(5.3, 1.0, 11.6), "ate": Vector3(5.3, 1.0, 13.4)},
	{"nome": "corredor_para_escritorio",
		"de": Vector3(9.4, 1.0, 11.6), "ate": Vector3(9.4, 1.0, 13.4)},
	{"nome": "corredor_para_estoque",
		"de": Vector3(12.9, 1.0, 11.6), "ate": Vector3(12.9, 1.0, 13.4)},
]

## O vao do portao, que no comodo teleportado fica FECHADO: do outro lado dele
## nao ha cidade.
const BARRADA := {"de": Vector3(2.3, 1.0, 1.5), "ate": Vector3(2.3, 1.0, -0.6)}


static func executar(cena: Node, jogador: Node3D) -> void:
	if OS.get_cmdline_user_args().has("--teleporte"):
		await _executar_teleporte(cena, jogador)
		return
	await _executar_na_rua(cena, jogador)


static func _encerrar(arvore: SceneTree) -> void:
	for acao: StringName in [&"mover_frente", &"mover_tras", &"mover_esq", &"mover_dir"]:
		Input.action_release(acao)
	AudioDirector.silenciar_tudo()
	await arvore.process_frame
	arvore.quit(0)


static func _relatar(chave: String, valor: Variant) -> void:
	print("[mercado] %s=%s" % [chave, valor])


# =============================================================================
# A loja na rua
# =============================================================================

static func _executar_na_rua(cena: Node, jogador: Node3D) -> void:
	var arvore := cena.get_tree()
	await arvore.create_timer(1.0).timeout
	_relatar("inicio", 1)

	var lojas := _medir_cidade_na_rua()
	if lojas.is_empty():
		_relatar("loja_ausente", 1)
		_encerrar(arvore)
		return
	var loja: Dictionary = lojas[0]
	_medir_chunk_da_loja(loja)
	_medir_fileiras(lojas)

	# A rua sem ninguem: a medida abaixo e de POSICAO do jogador, e um pedestre
	# encostado nele o empurra pela recuperacao de penetracao do motor.
	Multidao.parar()

	# Da porta anunciada ao mapa ate a loja montada: o jogador vai para a
	# calcada, o streaming carrega, a loja pre-aquece. Sem fisica enquanto isso:
	# o chunk ainda nao tem chao, e a gravidade o levaria para baixo do mundo.
	var porta_d: Dictionary = loja["porta"]
	var porta_mundo := _no_mundo(loja, Vector3(porta_d["pos"]))
	var planta_local: Transform3D = porta_d["planta"]
	var chao := porta_mundo.y - KitModular.ALTURA_MEIO_FIO
	var em_aprox := Transform3D(planta_local.basis,
		_no_mundo(loja, planta_local.origin) + Vector3(0.0, chao, 0.0))
	jogador.set_physics_process(false)
	jogador.global_position = em_aprox * Vector3(MercadoBuilder.CENTRO_PORTA - 6.0,
		0.6, -1.75)
	var casa := await _esperar_loja(arvore, porta_mundo)
	jogador.set_physics_process(true)
	if casa == null:
		_relatar("loja_nao_montou", 1)
		_encerrar(arvore)
		return
	var em := casa.global_transform
	var sala := casa.get_node_or_null(^"Sala") as Node3D
	_relatar("loja_montou", 1)
	_medir_calcada(jogador, em)

	var porta := _perto_no_grupo(arvore, &"porta_automatica", em * Vector3(
		MercadoBuilder.CENTRO_PORTA, 0.0, 0.0), 3.0) as PortaAutomatica
	var portao := _perto_no_grupo(arvore, &"portao_enrolar", em * Vector3(
		MercadoBuilder.EIXO_PORTAO, 0.0, 0.0), 3.0) as PortaoEnrolar
	_relatar("porta_automatica", 1 if porta != null else 0)
	_relatar("portao_enrolar", 1 if portao != null else 0)
	_relatar("frente_da_loja", 1 if _perto_no_grupo_por_nome(arvore, casa,
		"FrenteDaLoja") else 0)

	# O cliente: quem vem comprar nasce na calcada e entra pela porta.
	var entradas: Array[Node3D] = []
	if porta != null:
		porta.alguem_entrou.connect(func(quem: Node3D) -> void: entradas.append(quem))

	# --- a fachada, de perto e de longe ---------------------------------------
	# Do meio da rua, de frente para a loja: vitrine, letreiro, portao, predio.
	await _posar(arvore, jogador, em * Vector3(MercadoBuilder.CENTRO_PORTA - 2.5, 0.6, -6.5),
		em * Vector3(8.0, 2.0, 0.0))
	await _foto(arvore, "00_fachada")

	# --- a caminhada --------------------------------------------------------
	# Comeca seis metros ao lado da porta, na calcada, e vai ate a camara fria.
	var inicio := em * Vector3(MercadoBuilder.CENTRO_PORTA - 6.0, 0.6, -1.75)
	jogador.global_position = inicio
	if jogador.has_method("zerar_velocidade"):
		jogador.call("zerar_velocidade")
	await arvore.create_timer(0.6).timeout
	_olhar(jogador, em * Vector3(MercadoBuilder.CENTRO_PORTA, 1.4, 0.0))
	await arvore.create_timer(0.5).timeout
	await _foto(arvore, "01_calcada")

	var pontos: Array[Vector3] = [
		em * Vector3(MercadoBuilder.CENTRO_PORTA, 0.0, -1.75),
		em * Vector3(MercadoBuilder.CENTRO_PORTA, 0.0, 1.3),
		em * Vector3(MercadoBuilder.CENTRO_PORTA, 0.0, 5.6),
		em * Vector3(MercadoBuilder.CENTRO_PORTA, 0.0, 9.2),
	]
	var medida := {"salto_max": 0.0, "cortina_max": 0.0, "isolado": 0,
		"no_mundo": 0, "porta_max": 0.0, "porta_ao_cruzar": -1.0,
		"empacou_s": 0.0, "fotografou_porta": false}
	var lado_antes := [1.0]
	var a_cada := func(p: Vector3) -> void:
		var cortina := Interiores._cortina.color.a if Interiores._cortina != null else 0.0
		medida["cortina_max"] = maxf(float(medida["cortina_max"]), cortina)
		if Interiores.isolado():
			medida["isolado"] = 1
		if Interiores.no_mundo:
			medida["no_mundo"] = 1
		if porta == null:
			return
		medida["porta_max"] = maxf(float(medida["porta_max"]), porta.abertura())
		var local := porta.to_local(p)
		var lado := signf(local.z)
		if lado < 0.0 and lado_antes[0] > 0.0:
			medida["porta_ao_cruzar"] = porta.abertura()
		if absf(local.z) > 0.05:
			lado_antes[0] = lado
		if not bool(medida["fotografou_porta"]) and local.z < 1.6 and local.z > 0.0:
			medida["fotografou_porta"] = true
			_foto_ja(arvore, "02_porta_abrindo")
		# No meio do corredor central, olhando para a camara fria.
		if not medida.has("fotografou_fundo") and (em.affine_inverse() * p).z > 5.2:
			medida["fotografou_fundo"] = true
			_foto_ja(arvore, "03_camara_fria")
	var chegou := await _andar(arvore, jogador, pontos, 30.0, a_cada, medida, em)
	_relatar("chegou_na_geladeira", 1 if chegou else 0)
	if OS.get_cmdline_user_args().has("--tour"):
		await _tour(arvore, jogador, em)
		_encerrar(arvore)
		return
	if sala != null:
		await _testar_prateleira(arvore, jogador, sala, em)
	_relatar("salto_max", snappedf(float(medida["salto_max"]), 0.001))
	_relatar("cortina_max", snappedf(float(medida["cortina_max"]), 0.001))
	_relatar("isolado", medida["isolado"])
	_relatar("entrou_no_mundo", medida["no_mundo"])
	_relatar("porta_abriu", snappedf(float(medida["porta_max"]), 0.01))
	_relatar("porta_ao_cruzar", snappedf(float(medida["porta_ao_cruzar"]), 0.01))
	_relatar("empacou_s", snappedf(float(medida["empacou_s"]), 0.01))
	_relatar("jogador_entrou_pela_porta", 1 if entradas.has(jogador) else 0)

	var fog := arvore.get_first_node_in_group(&"fog_controller") as FogController
	if fog != null:
		_relatar("ambiente", String(fog.preset_ativo()))

	# De volta para a porta: o vidro visto de dentro.
	_olhar(jogador, em * Vector3(9.0, 1.3, 0.0))
	await arvore.create_timer(0.6).timeout
	await _foto(arvore, "04_vitrine_de_dentro")

	if sala != null:
		_medir_loja(sala)
		_medir_servico(sala)
		_medir_planta(jogador, em)
		await _medir_gente(arvore, sala, em, entradas)
		await _testar_atendimento(arvore, sala, jogador)
		await _testar_terminal(arvore)

	if portao != null:
		await _testar_portao_na_rua(arvore, jogador, sala, em, portao)

	_relatar("fim", 1)
	_encerrar(arvore)


## As lojas da cidade num raio de RAIO_CIDADE chunks, da mais perto para a mais
## longe da origem. Nenhuma pode ser teleportada: onde a loja nao cabe inteira,
## a porta e de outra coisa.
static func _medir_cidade_na_rua() -> Array[Dictionary]:
	var lojas: Array[Dictionary] = []
	var teleportadas := 0
	for raio in RAIO_CIDADE + 1:
		for cx in range(-raio, raio + 1):
			for cz in range(-raio, raio + 1):
				if maxi(absi(cx), absi(cz)) != raio:
					continue
				for ponto: Dictionary in ChunkBuilder.pontos_de_interesse(cx, cz):
					if ponto.get("tipo", &"") != &"porta" \
							or ponto.get("interior", &"") != &"mercado":
						continue
					if bool(ponto.get("mundo", false)):
						lojas.append({"cx": cx, "cz": cz, "porta": ponto})
					else:
						teleportadas += 1
	_relatar("lojas_r12", lojas.size())
	_relatar("lojas_teleportadas", teleportadas)
	return lojas


## Um ponto local do chunk da loja, no mundo.
static func _no_mundo(loja: Dictionary, local: Vector3) -> Vector3:
	return local + Vector3(float(loja["cx"]) * KitModular.CHUNK, 0.0,
		float(loja["cz"]) * KitModular.CHUNK)


## O chunk da loja montado em dados: os quatro props da loja existem, e nada da
## quadra entra na pegada dela.
##
## A pegada e varrida numa grade de meio metro, a um metro do piso. Qualquer
## caixa de colisao do chunk que contenha um desses pontos e intrusa: muro de
## quintal da fileira do outro eixo, divisa de lote, predio. A loja e oca no
## terreo, e o proprio chunk nao poe colisao ali (PredioMercado).
static func _medir_chunk_da_loja(loja: Dictionary) -> void:
	var cx := int(loja["cx"])
	var cz := int(loja["cz"])
	var dados := ChunkBuilder.construir(cx, cz)
	var tipos: Dictionary = {}
	var planta := Transform3D()
	for prop: Dictionary in dados["props"]:
		tipos[String(prop.get("tipo", ""))] = true
		if prop.get("tipo", "") == "interior_mundo" and prop.get("interior", &"") == &"mercado":
			planta = prop["planta"]
	var props_da_loja := 0
	for t: String in ["porta_automatica", "portao_enrolar", "malha_fronteira",
			"interior_mundo"]:
		if tipos.has(t):
			props_da_loja += 1
	_relatar("props_da_loja", props_da_loja)
	_relatar("porta_teleporte_no_chunk", 1 if _tem_porta_de_mercado(dados) else 0)
	var sup: Dictionary = dados["superficies"]
	_relatar("letreiro", 1 if sup.has(&"mercado_letreiro") else 0)

	var invadidos := 0
	var piso := planta.origin.y
	var x := 0.5
	while x < MercadoBuilder.LARGURA - 0.4:
		var z := 0.5
		while z < MercadoBuilder.FUNDO - 0.4:
			var p := planta * Vector3(x, 1.0, z)
			for c: Dictionary in dados["colisao"]:
				# O mapa de altura do relevo tambem mora na lista, sem caixa.
				if not c.has("tamanho"):
					continue
				var centro: Vector3 = c["pos"]
				var meio: Vector3 = Vector3(c["tamanho"]) * 0.5
				if absf(p.x - centro.x) < meio.x and absf(p.z - centro.z) < meio.z \
						and centro.y - meio.y < piso + 2.6 and centro.y + meio.y > piso + 0.3:
					invadidos += 1
					break
			z += 0.5
		x += 0.5
	_relatar("lote_invadido", invadidos)


## O chao da calcada na frente da loja, medido por raio, em altura de planta.
##
## A loja assenta o piso pela soleira da porta (ChunkBuilder._erguer_lote). Se o
## passeio subir ao longo da fachada, o portao, oito metros adiante, abre para
## um degrau que ninguem desenhou. O numero que importa e o desnivel entre o
## passeio e o piso na frente de cada boca.
static func _medir_calcada(jogador: Node3D, em: Transform3D) -> void:
	var espaco := jogador.get_world_3d().direct_space_state
	var alturas: Array[String] = []
	var maior := -INF
	var menor := INF
	var x := 0.5
	while x < MercadoBuilder.LARGURA:
		var r := PhysicsRayQueryParameters3D.create(em * Vector3(x, 2.0, -1.6),
			em * Vector3(x, -3.0, -1.6))
		r.collision_mask = 1
		r.exclude = [jogador.get_rid()]
		var bate := espaco.intersect_ray(r)
		if not bate.is_empty():
			var y := (em.affine_inverse() * Vector3(bate["position"])).y
			alturas.append("%.2f" % y)
			maior = maxf(maior, y)
			menor = minf(menor, y)
		x += 2.0
	_relatar("calcada_y", ",".join(alturas))
	_relatar("calcada_desnivel", snappedf(maior - menor, 0.01))


## A fileira da face da loja fecha de ponta a ponta, em todas as lojas.
##
## A loja come um trecho da face, e o resto da face e repartido entre os outros
## predios (ChunkBuilder._fileira). Se a conta do trecho livre errar, sobra um
## vao sem predio — uma boca para o patio no meio do quarteirao. A regua anda
## pela face a meio metro, quatro metros para dentro e cinco de altura (acima do
## terreo oco da loja, dentro do predio de cima), e conta onde nao ha massa.
static func _medir_fileiras(lojas: Array[Dictionary]) -> void:
	var buracos := 0
	var pior := ""
	for loja: Dictionary in lojas:
		var cx := int(loja["cx"])
		var cz := int(loja["cz"])
		var porta: Dictionary = loja["porta"]
		var face := ChunkBuilder._face_de_rua(cx, cz)
		if face.is_empty():
			continue
		var dados := ChunkBuilder.construir(cx, cz)
		var normal := KitModular._normal(int(face["direcao"]))
		var eixo: Vector3 = face["eixo"]
		var canto: Vector3 = face["canto"]
		var comp := float(face["comprimento"])
		var de := float(porta["lote_inicio"])
		var ate := de + LoteNoMundo.lote(&"mercado").x
		var aqui := 0
		var vazios: Array[float] = []
		var t := 0.5
		while t < comp - 0.5:
			# O lote da loja e oco no terreo: ali quem fecha e ela mesma.
			if t > de and t < ate:
				t += 0.5
				continue
			# Metro e meio acima do chao DAQUELE ponto: predio de um andar so tem
			# tres metros, e na ladeira cada lote assenta na altura dele.
			var p := canto + eixo * t - normal * 4.0
			p.y = Relevo.local(cx, cz, p) + KitModular.ALTURA_MEIO_FIO + 1.5
			var tem := false
			for c: Dictionary in dados["colisao"]:
				if not c.has("tamanho"):
					continue
				var centro: Vector3 = c["pos"]
				var meio: Vector3 = Vector3(c["tamanho"]) * 0.5
				if absf(p.x - centro.x) <= meio.x and absf(p.y - centro.y) <= meio.y \
						and absf(p.z - centro.z) <= meio.z:
					tem = true
					break
			if not tem:
				aqui += 1
				vazios.append(t)
			t += 0.5
		# Uma amostra so e a emenda entre dois predios, onde as caixas se tocam
		# e o ponto cai no fio. Buraco de verdade e mais de um metro.
		if aqui > 2:
			buracos += aqui
			pior += "%d,%d:%.1fm(dir%d,comp%.1f,lote%.1f,de%.1f,ate%.1f) " % [cx, cz,
				float(aqui) * 0.5, int(face["direcao"]), comp, de, vazios[0], vazios[-1]]
	_relatar("fileira_buracos", buracos)
	if not pior.is_empty():
		_relatar("fileira_onde", pior.strip_edges().replace(" ", ";"))


static func _tem_porta_de_mercado(dados: Dictionary) -> bool:
	for prop: Dictionary in dados["props"]:
		if prop.get("tipo", "") == "porta" and prop.get("interior", &"") == &"mercado":
			return true
	return false


## Espera a loja da porta pre-aquecer e o ultimo prop nascer.
static func _esperar_loja(arvore: SceneTree, porta: Vector3) -> InteriorNoMundo:
	var t := 0.0
	while t < 25.0:
		await arvore.create_timer(0.25).timeout
		t += 0.25
		for no: Node in arvore.get_nodes_in_group(&"interior_mundo"):
			var casa := no as InteriorNoMundo
			if casa == null or casa.planta != &"mercado":
				continue
			if casa.global_position.distance_to(porta) > 20.0:
				continue
			if casa._conteudo != null and casa._fila.is_empty() and casa._tarefa < 0:
				_relatar("montagem_s", snappedf(t, 0.25))
				return casa
	return null


static func _perto_no_grupo(arvore: SceneTree, grupo: StringName, ponto: Vector3,
		raio: float) -> Node3D:
	var melhor: Node3D = null
	var perto := raio
	for no: Node in arvore.get_nodes_in_group(grupo):
		var n := no as Node3D
		if n == null:
			continue
		var d := n.global_position.distance_to(ponto)
		if d < perto:
			perto = d
			melhor = n
	return melhor


## A malha de fronteira da loja existe no chunk, irma do InteriorNoMundo.
static func _perto_no_grupo_por_nome(_arvore: SceneTree, casa: Node3D,
		nome: String) -> bool:
	var pai := casa.get_parent()
	return pai != null and pai.find_child(nome, false, false) != null


## Poe o jogador num lugar, olhando para um ponto, e espera assentar.
static func _posar(arvore: SceneTree, jogador: Node3D, onde: Vector3, alvo: Vector3) -> void:
	jogador.global_position = onde
	if jogador.has_method("zerar_velocidade"):
		jogador.call("zerar_velocidade")
	await arvore.create_timer(0.5).timeout
	_olhar(jogador, alvo)
	await arvore.create_timer(0.4).timeout


static func _olhar(jogador: Node3D, alvo: Vector3) -> void:
	if jogador.has_method("olhar_para"):
		jogador.call("olhar_para", alvo)


## Anda pelos pontos apertando a tecla de andar, de verdade: e o mesmo caminho
## do teclado (Input), e nao uma chamada de metodo. Mede o salto por quadro de
## fisica e o tempo parado com a tecla apertada.
static func _andar(arvore: SceneTree, jogador: Node3D, pontos: Array[Vector3],
		limite: float, a_cada: Callable, medida: Dictionary,
		em: Transform3D = Transform3D()) -> bool:
	var i := 0
	var t := 0.0
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var anterior := jogador.global_position
	Input.action_press(&"mover_frente")
	while i < pontos.size() and t < limite:
		await arvore.physics_frame
		t += dt
		var p := jogador.global_position
		var passo := p.distance_to(anterior)
		medida["salto_max"] = maxf(float(medida["salto_max"]), passo)
		if passo < 0.15 * dt:
			medida["empacou_s"] = float(medida["empacou_s"]) + dt
		anterior = p
		a_cada.call(p)
		var alvo := pontos[i]
		if Vector2(alvo.x - p.x, alvo.z - p.z).length() < 0.4:
			i += 1
			continue
		_olhar(jogador, Vector3(alvo.x, p.y + Player.ALTURA_OLHO, alvo.z))
	Input.action_release(&"mover_frente")
	_relatar("caminhada_s", snappedf(t, 0.1))
	if i < pontos.size():
		# Onde parou, e por que pode ter parado: e o que transforma "empacou" em
		# um lugar da planta.
		var body := jogador as CharacterBody3D
		_relatar("parou_no_ponto", i)
		_relatar("parou_em", "%.2f,%.2f,%.2f" % [jogador.global_position.x,
			jogador.global_position.y, jogador.global_position.z])
		_relatar("parou_faltando", snappedf(Vector2(pontos[i].x - jogador.global_position.x,
			pontos[i].z - jogador.global_position.z).length(), 0.01))
		_relatar("parou_travado", 1 if bool(jogador.get("travado")) else 0)
		_relatar("parou_velocidade", snappedf(body.velocity.length(), 0.01) if body != null else -1.0)
		_relatar("parou_no_chao", 1 if body != null and body.is_on_floor() else 0)
		if body != null:
			for k in body.get_slide_collision_count():
				var col := body.get_slide_collision(k)
				var outro := col.get_collider() as Node
				var na_planta := em.affine_inverse() * col.get_position()
				_relatar("parou_bateu_%d" % k, "%s@%s:planta%s" % [outro.name if outro != null else "?",
					str(col.get_normal().snapped(Vector3(0.01, 0.01, 0.01))),
					str(na_planta.snapped(Vector3(0.01, 0.01, 0.01)))])
				# Qual caixa e: dono, centro e tamanho, na planta.
				var dono := outro as CollisionObject3D
				if dono != null:
					var forma_id := dono.shape_find_owner(col.get_collider_shape_index())
					var forma := dono.shape_owner_get_owner(forma_id) as CollisionShape3D
					if forma != null and forma.shape is BoxShape3D:
						_relatar("parou_caixa_%d" % k, "%s/%s c=%s t=%s" % [
							dono.get_parent().name if dono.get_parent() != null else "?",
							dono.name,
							str((em.affine_inverse() * forma.global_position).snapped(
								Vector3(0.01, 0.01, 0.01))),
							str((forma.shape as BoxShape3D).size.snapped(Vector3(0.01, 0.01, 0.01)))])
		_relatar("parou_na_planta", str((em.affine_inverse() * jogador.global_position).snapped(
			Vector3(0.01, 0.01, 0.01))))
	return i >= pontos.size()


# --- gente --------------------------------------------------------------------

## O cliente vai da calcada ao caixa sozinho, e o atendente fica no posto.
##
## E o criterio da F0 medido na loja da rua: "cliente chega ao caixa sem
## ir_ao_caixa". Antes ele ficava parado na gondola para sempre — `_chegou_na_casa`
## nao avancava a compra.
static func _medir_gente(arvore: SceneTree, sala: Node3D, em: Transform3D,
		entradas: Array[Node3D]) -> void:
	var cliente: Convidado = null
	var atendente: Convidado = null
	for filho: Node in sala.get_children():
		var c := filho as Convidado
		if c == null:
			continue
		if c is AtendenteLoja:
			atendente = c
		elif c.rotina == &"compra":
			cliente = c
	_relatar("atendente_classe", 1 if atendente != null else 0)
	_relatar("cliente_existe", 1 if cliente != null else 0)
	if cliente == null:
		return
	var caixa := em * MercadoBuilder.POSTO_CLIENTE
	var t := 0.0
	while t < 45.0:
		if Vector2(cliente.global_position.x - caixa.x,
				cliente.global_position.z - caixa.z).length() < 0.7:
			break
		await arvore.create_timer(0.25).timeout
		t += 0.25
	_relatar("cliente_no_caixa_s", snappedf(t, 0.25))
	_relatar("cliente_entrou_pela_porta", 1 if entradas.has(cliente) else 0)
	if atendente != null:
		var posto := em * MercadoBuilder.POSTO_ATENDENTE
		_relatar("atendente_fora_do_posto",
			snappedf(Vector2(atendente.global_position.x - posto.x,
				atendente.global_position.z - posto.z).length(), 0.01))
	# O caixa visto da fila: cliente, balcao, atendente e a parede de cigarro.
	var jogador := sala.get_tree().get_first_node_in_group(&"player") as Node3D
	if jogador != null:
		await _posar(arvore, jogador, em * Vector3(8.9, 0.3, 4.6),
			em * Vector3(5.6, 1.3, 2.6))
	await _foto(arvore, "05_caixa")


# --- portao -------------------------------------------------------------------

## A botoeira sobe o portao, e o jogador sai andando pela garagem.
static func _testar_portao_na_rua(arvore: SceneTree, jogador: Node3D, sala: Node3D,
		em: Transform3D, portao: PortaoEnrolar) -> void:
	var botoeira: BotoeiraPortao = null
	if sala != null:
		botoeira = sala.find_child("BotoeiraPortao", false, false) as BotoeiraPortao
	_relatar("botoeira", 1 if botoeira != null else 0)
	if botoeira == null:
		return
	_relatar("botoeira_acha_portao", 1 if botoeira.portao() == portao else 0)
	# Por dentro da garagem, na frente da botoeira.
	jogador.global_position = em * Vector3(3.4, 0.4, 1.8)
	if jogador.has_method("zerar_velocidade"):
		jogador.call("zerar_velocidade")
	await arvore.create_timer(0.4).timeout
	botoeira.interagir(jogador)
	await arvore.create_timer(PortaoEnrolar.DURACAO + 0.6).timeout
	_relatar("portao_abertura", snappedf(portao.abertura(), 0.01))
	_olhar(jogador, em * Vector3(MercadoBuilder.EIXO_PORTAO, 1.2, -4.0))
	await arvore.create_timer(0.4).timeout
	await _foto(arvore, "06_portao_aberto")

	var pontos: Array[Vector3] = [
		em * Vector3(MercadoBuilder.EIXO_PORTAO, 0.0, 1.0),
		em * Vector3(MercadoBuilder.EIXO_PORTAO, 0.0, -1.8),
	]
	var medida := {"salto_max": 0.0, "empacou_s": 0.0}
	var saiu := await _andar(arvore, jogador, pontos, 12.0,
		func(_p: Vector3) -> void: pass, medida, em)
	await arvore.create_timer(0.3).timeout
	_relatar("saiu_pelo_portao", 1 if saiu and not Interiores.dentro else 0)
	_relatar("portao_salto_max", snappedf(float(medida["salto_max"]), 0.001))
	portao.fechar()


# --- passeio de auditoria -------------------------------------------------------

## Os quadros da auditoria: cada comodo como o jogador o ve, da porta e de
## dentro. Coordenada de planta; `olho` no piso, `alvo` na altura que importa.
const TOUR: Array[Dictionary] = [
	{"nome": "a01_salao_da_porta", "olho": Vector3(11.0, 0.0, 1.0), "alvo": Vector3(11.0, 1.2, 10.0)},
	{"nome": "a02_salao_diagonal", "olho": Vector3(16.3, 0.0, 1.0), "alvo": Vector3(7.0, 1.0, 8.5)},
	{"nome": "a03_salao_do_fundo", "olho": Vector3(15.0, 0.0, 9.6), "alvo": Vector3(8.0, 1.0, 1.0)},
	{"nome": "a04_caixa_do_cliente", "olho": Vector3(8.6, 0.0, 2.6), "alvo": Vector3(5.6, 1.1, 3.9)},
	{"nome": "a05_atras_do_balcao", "olho": Vector3(5.2, 0.0, 6.6), "alvo": Vector3(6.4, 1.0, 1.2)},
	{"nome": "a06_revistas_sorvete", "olho": Vector3(11.5, 0.0, 3.0), "alvo": Vector3(13.5, 0.6, 0.3)},
	{"nome": "a07_teto_calhas", "olho": Vector3(11.0, 0.0, 2.0), "alvo": Vector3(12.0, 2.9, 7.0)},
	{"nome": "a08_garagem_do_vao", "olho": Vector3(2.3, 0.0, 10.3), "alvo": Vector3(2.3, 1.0, 1.0)},
	{"nome": "a09_garagem_estante", "olho": Vector3(3.5, 0.0, 5.6), "alvo": Vector3(0.3, 1.1, 6.6)},
	{"nome": "a10_garagem_portao", "olho": Vector3(2.6, 0.0, 8.6), "alvo": Vector3(2.3, 1.3, 0.0)},
	{"nome": "a11_garagem_paletes", "olho": Vector3(1.0, 0.0, 2.0), "alvo": Vector3(3.5, 0.6, 7.5)},
	{"nome": "a12_corredor_oeste", "olho": Vector3(1.2, 0.0, 11.6), "alvo": Vector3(16.0, 1.2, 11.6)},
	{"nome": "a13_corredor_leste", "olho": Vector3(16.0, 0.0, 11.6), "alvo": Vector3(1.0, 1.2, 11.6)},
	{"nome": "a14_banheiro", "olho": Vector3(1.6, 0.0, 12.9), "alvo": Vector3(0.9, 0.7, 16.0)},
	{"nome": "a15_banheiro_pia", "olho": Vector3(0.7, 0.0, 13.3), "alvo": Vector3(2.8, 1.2, 14.2)},
	{"nome": "a16_copa", "olho": Vector3(5.3, 0.0, 12.9), "alvo": Vector3(5.6, 0.9, 16.0)},
	{"nome": "a17_copa_armario", "olho": Vector3(6.6, 0.0, 15.0), "alvo": Vector3(3.0, 1.0, 14.3)},
	{"nome": "a18_escritorio", "olho": Vector3(9.4, 0.0, 12.9), "alvo": Vector3(9.2, 1.0, 16.0)},
	{"nome": "a19_estoque", "olho": Vector3(12.6, 0.0, 12.9), "alvo": Vector3(15.8, 1.0, 15.6)},
	{"nome": "a20_estoque_estante", "olho": Vector3(15.2, 0.0, 13.0), "alvo": Vector3(13.2, 1.1, 16.0)},
]


## Passeio de fotos para a auditoria (`--tour`): um quadro por comodo, e sai.
static func _tour(arvore: SceneTree, jogador: Node3D, em: Transform3D) -> void:
	_pasta = "captures/mercado_aaa/auditoria"
	for q: Dictionary in TOUR:
		await _posar(arvore, jogador, em * Vector3(q["olho"]), em * Vector3(q["alvo"]))
		await arvore.create_timer(0.35).timeout
		await _foto(arvore, String(q["nome"]))
	# A fachada e a calcada, por ultimo: de fora a loja inteira aparece pelo vidro.
	await _posar(arvore, jogador, em * Vector3(8.5, 0.6, -6.5), em * Vector3(8.0, 2.0, 0.0))
	await arvore.create_timer(0.5).timeout
	await _foto(arvore, "a21_fachada")
	await _posar(arvore, jogador, em * Vector3(11.0, 0.6, -2.6), em * Vector3(11.0, 1.2, 6.0))
	await arvore.create_timer(0.5).timeout
	await _foto(arvore, "a22_vitrine_da_calcada")
	_pasta = PASTA_CAPTURA


# --- fotos --------------------------------------------------------------------

## Fotografa o quadro corrente, se houver janela. Espera dois quadros para a
## imagem ja ter o que acabou de mudar.
static func _foto(arvore: SceneTree, nome: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await arvore.process_frame
	await arvore.process_frame
	_foto_ja(arvore, nome)


static func _foto_ja(arvore: SceneTree, nome: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var raiz := ProjectSettings.globalize_path("res://").path_join("..")
	var pasta := raiz.path_join(_pasta)
	DirAccess.make_dir_recursive_absolute(pasta)
	var img := arvore.root.get_viewport().get_texture().get_image()
	img.save_png(pasta.path_join(nome + ".png"))
	_relatar("foto_" + nome, 1)


# =============================================================================
# O comodo teleportado (a abertura)
# =============================================================================

static func _executar_teleporte(cena: Node, jogador: Node3D) -> void:
	var arvore := cena.get_tree()
	await arvore.create_timer(1.0).timeout

	_relatar("inicio", 1)
	var retorno := jogador.global_transform

	Interiores.entrar(SEMENTE, retorno, &"mercado")
	await arvore.create_timer(ESPERA_LONGA).timeout
	_relatar("entrou", 1 if Interiores.dentro else 0)

	var interior := arvore.current_scene.get_node_or_null("Interior")
	if interior == null:
		_relatar("interior_ausente", 1)
		_encerrar(arvore)
		return

	_medir_loja(interior)
	_medir_servico(interior)
	_medir_planta(jogador, Transform3D(Basis.IDENTITY, Interiores.DESLOCAMENTO))
	_medir_barrada(jogador)
	_medir_ambiente(arvore)
	await _testar_mercadoria(arvore, interior, jogador)
	await _testar_atendimento(arvore, interior, jogador)
	await _testar_terminal(arvore)

	# O portao vem antes da porta da frente porque ele TAMBEM sai para a rua. As
	# duas saidas precisam ser medidas a partir da mesma entrada.
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
	# Todas as fontes de luz do comodo, e nao so as `Lampada`: para o
	# renderizador a OmniLight crua do leitor e o telefone contam igual.
	_relatar("luzes_totais", _contar_luzes(interior))

	var faltando: Array[String] = []
	for exigida: StringName in SUPERFICIES_EXIGIDAS:
		if not superficies.has(String(exigida)):
			faltando.append(String(exigida))
	_relatar("superficies", superficies.size())
	_relatar("superficies_faltando", faltando.size())
	if not faltando.is_empty():
		_relatar("faltou", ",".join(faltando))


static func _contar_luzes(no: Node) -> int:
	var total := 0
	for filho: Node in no.get_children():
		if filho is OmniLight3D or filho is SpotLight3D:
			total += 1
		total += _contar_luzes(filho)
	return total


static func _medir_ambiente(arvore: SceneTree) -> void:
	var fog := arvore.get_first_node_in_group(&"fog_controller") as FogController
	if fog == null:
		_relatar("fog_ausente", 1)
		return
	_relatar("ambiente", String(fog.preset_ativo()))


static func _medir_servico(interior: Node) -> void:
	var superficies: Array[String] = []
	var batentes := 0
	var computadores := 0

	for filho: Node in interior.get_children():
		if filho is MeshInstance3D:
			superficies.append(filho.name)
		elif filho is Interativo:
			if filho.name.begins_with("PortaBatente"):
				batentes += 1
			elif filho.name.begins_with("Computador"):
				computadores += 1

	var faltando: Array[String] = []
	for exigida: StringName in SUPERFICIES_SERVICO:
		if not superficies.has(String(exigida)):
			faltando.append(String(exigida))
	_relatar("servico_faltando", faltando.size())
	if not faltando.is_empty():
		_relatar("faltou_servico", ",".join(faltando))
	# Quatro portas de folha: a de servico e as tres do fundo. O vao da garagem e
	# o do estoque nao tem folha de proposito.
	_relatar("portas_batente", batentes)
	_relatar("computador", computadores)


## Espaco livre e passagem, medidos com a fisica de verdade. `em` leva a planta
## ao mundo: a loja da rua ou a teleportada.
static func _medir_planta(jogador: Node3D, em: Transform3D) -> void:
	var espaco := jogador.get_world_3d().direct_space_state
	var forma := SphereShape3D.new()
	# Trinta e cinco centimetros de raio: "cabe alguem aqui", e nao "cabe com
	# folga de arquiteto". Vao de porta de 90 cm tem de passar.
	forma.radius = 0.35
	var ocupados: Array[String] = []
	for pouso: Dictionary in POUSOS:
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = forma
		q.transform = Transform3D(Basis.IDENTITY, em * Vector3(pouso["pos"]))
		q.collision_mask = 1
		q.exclude = [jogador.get_rid()]
		for r: Dictionary in espaco.intersect_shape(q, 4):
			# Gente em pe nao e defeito de planta: e o que a planta existe para
			# caber.
			if r.get("collider") is Convidado:
				continue
			ocupados.append(String(pouso["nome"]))
			break
	_relatar("pousos_ocupados", ocupados.size())
	if not ocupados.is_empty():
		_relatar("ocupado", ",".join(ocupados))

	var fechadas: Array[String] = []
	for t: Dictionary in TRAVESSIAS:
		var r := PhysicsRayQueryParameters3D.create(em * Vector3(t["de"]),
			em * Vector3(t["ate"]))
		r.collision_mask = 1
		r.exclude = [jogador.get_rid()]
		var bate := espaco.intersect_ray(r)
		if not bate.is_empty() and not (bate.get("collider") is Convidado):
			fechadas.append(String(t["nome"]))
	_relatar("travessias_fechadas", fechadas.size())
	if not fechadas.is_empty():
		_relatar("travessia_fechada", ",".join(fechadas))


static func _medir_barrada(jogador: Node3D) -> void:
	var espaco := jogador.get_world_3d().direct_space_state
	var d := Interiores.DESLOCAMENTO
	var r := PhysicsRayQueryParameters3D.create(d + Vector3(BARRADA["de"]),
		d + Vector3(BARRADA["ate"]))
	r.collision_mask = 1
	r.exclude = [jogador.get_rid()]
	_relatar("portao_barra", 0 if espaco.intersect_ray(r).is_empty() else 1)


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


# --- saida e portao do comodo teleportado ------------------------------------

static func _testar_saida(arvore: SceneTree, interior: Node, jogador: Node3D,
		retorno: Transform3D) -> void:
	var saida := interior.get_node_or_null("Saida") as Interativo
	if saida == null:
		_relatar("saida_ausente", 1)
		return
	var porta := saida.get_node_or_null("PortaAutomatica")
	_relatar("porta_automatica", 1 if porta != null else 0)
	_relatar("folhas", porta.get_child_count() if porta != null else 0)
	var folha: Node3D = null
	var antes := 0.0
	if porta != null and porta.get_child_count() > 0:
		folha = porta.get_child(0) as Node3D
		antes = folha.position.x
	Multidao.parar()
	saida.interagir(jogador)
	await arvore.create_timer(0.42).timeout
	if folha != null and is_instance_valid(folha):
		_relatar("folha_correu", 1 if absf(folha.position.x - antes) > 0.25 else 0)
	await arvore.create_timer(ESPERA_LONGA).timeout
	_relatar("saiu", 0 if Interiores.dentro else 1)
	var plano := Vector2(jogador.global_position.x - retorno.origin.x,
		jogador.global_position.z - retorno.origin.z)
	_relatar("desvio_no_plano", snappedf(plano.length(), 0.01))
	var fog := arvore.get_first_node_in_group(&"fog_controller") as FogController
	if fog != null:
		_relatar("ambiente_apos_sair", String(fog.preset_ativo()))


## Sair pelo portao teleportado devolve o jogador na calcada, a CENTRO_PORTA -
## EIXO_PORTAO metros da porta ao longo da fachada.
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
	await arvore.create_timer(0.4).timeout
	if folha != null and is_instance_valid(folha):
		_relatar("portao_folha_subiu", 1 if folha.scale.y < antes - 0.2 else 0)
	await arvore.create_timer(ESPERA_LONGA).timeout
	_relatar("saiu_pelo_portao", 0 if Interiores.dentro else 1)
	var d := jogador.global_position - retorno.origin
	_relatar("portao_lateral", snappedf(d.dot(retorno.basis.x), 0.01))
	_relatar("portao_afastou", snappedf(d.dot(retorno.basis.z), 0.01))


# --- atendimento no balcao --------------------------------------------------

## A sequencia inteira do caixa: carteira, leitor, camera, terminal.
##
## O que ela prova que nenhuma captura prova: que a carteira em cima do balcao e
## a do CLIENTE que esta ali (MercadoBuilder.SAL_DO_CLIENTE).
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
	if carteira == null or leitor == null:
		return
	_relatar("leitor_comeca_travado", 0 if leitor.habilitado else 1)

	var id_carteira := int(balcao.get_meta(&"id_da_carteira", -1))
	var ids: Array[int] = []
	for filho: Node in interior.get_children():
		if filho is Convidado:
			var f: Dictionary = (filho as Convidado).ficha
			if not f.is_empty():
				ids.append(int(f["id"]))
	_relatar("gente_no_balcao", ids.size())
	_relatar("carteira_e_de_quem_esta_ali", 1 if ids.has(id_carteira) else 0)
	var rota := 0
	for filho: Node in interior.get_children():
		if filho is Convidado and (filho as Convidado).rotina == &"compra":
			rota = 1
			(filho as Convidado).ir_ao_caixa()
	_relatar("cliente_tem_rota_de_compra", rota)
	await arvore.process_frame
	_relatar("compra_no_balcao",
		1 if interior.get_node_or_null("CompraBalcao") != null else 0)

	carteira.interagir(jogador)
	await arvore.create_timer(ESPERA_CURTA).timeout
	_relatar("carteira_abriu_documento", 1 if Documento.ativo else 0)
	Documento.fechar()
	await arvore.create_timer(ESPERA_CURTA).timeout
	_relatar("leitor_armou", 1 if leitor.habilitado else 0)

	var giro_antes := jogador.rotation.y
	leitor.interagir(jogador)
	await arvore.create_timer(1.8).timeout
	_relatar("leitor_abriu_terminal", 1 if Terminal.ativo else 0)
	_relatar("terminal_veio_com_o_cliente",
		1 if int(Terminal.ficha_aberta().get("id", -1)) == id_carteira else 0)
	_relatar("camera_virou",
		snappedf(absf(rad_to_deg(wrapf(jogador.rotation.y - giro_antes, -PI, PI))), 0.1))
	Terminal.fechar()
	await arvore.create_timer(ESPERA_CURTA).timeout

	# O caminho em que o terminal RECUSA abrir: com a carteira aberta em tela
	# cheia, `pode_abrir` cai, e quem travou o jogador tem de soltar.
	var f_cliente := RegistroCivil.identidade(id_carteira)
	Documento.abrir(f_cliente)
	await arvore.process_frame
	leitor.interagir(jogador)
	await arvore.create_timer(1.8).timeout
	_relatar("leitor_recusado_abriu_terminal", 1 if Terminal.ativo else 0)
	_relatar("leitor_recusado_nao_travou", 0 if bool(jogador.get("travado")) else 1)
	Documento.fechar()
	await arvore.create_timer(ESPERA_CURTA).timeout
	if jogador.has_method("travar"):
		jogador.call("travar", false)


# --- computador do balcao ---------------------------------------------------

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
	_relatar("terminal_recusa_invalido",
		0 if Terminal.consultar_cpf("11111111111") else 1)
	_relatar("terminal_mesma_mae",
		1 if Terminal.ficha_aberta().get("mae", "") == esperada["mae"] else 0)
	Terminal.fechar()
	await arvore.create_timer(ESPERA_CURTA).timeout
	_relatar("terminal_fechou", 0 if Terminal.ativo else 1)


# =============================================================================
# O produto (F2)
# =============================================================================

## Aperta e solta uma acao pelo mesmo caminho do teclado.
static func _apertar(arvore: SceneTree, acao: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = acao
	ev.pressed = true
	Input.parse_input_event(ev)
	await arvore.process_frame
	var solta := InputEventAction.new()
	solta.action = acao
	solta.pressed = false
	Input.parse_input_event(solta)
	await arvore.physics_frame
	await arvore.physics_frame


static func _prompt(jogador: Node) -> String:
	var alvo: Interativo = jogador.call("alvo_atual") if jogador.has_method("alvo_atual") else null
	return alvo.rotulo_atual() if alvo != null else ""


static func _unidades(p: PrateleiraViva) -> int:
	var total := 0
	for v: Dictionary in p.vagas:
		for q: int in v["colunas"]:
			total += q
	return total


## Geladeira: abrir, pegar, ler, devolver — tudo pela tecla, com o estoque
## conferido nas duas pontas. Depois as fotos do salao cheio.
static func _testar_prateleira(arvore: SceneTree, jogador: Node3D, sala: Node3D,
		em: Transform3D) -> void:
	_pasta = PASTA_F2
	var p := sala.find_child("PrateleiraViva", true, false) as PrateleiraViva
	_relatar("prateleira_viva", 1 if p != null else 0)
	if p == null:
		_pasta = PASTA_CAPTURA
		return
	# Orcamento: instancias desenhadas, triangulos e chamadas de desenho.
	var tris := 0
	var chamadas := 0
	var instancias := 0
	for filho in p.get_children():
		if filho is MultiMeshInstance3D and (filho as MultiMeshInstance3D).multimesh != null:
			var mm := (filho as MultiMeshInstance3D).multimesh
			if filho.name == "Destaque":
				continue
			chamadas += 1
			instancias += mm.instance_count
			tris += mm.instance_count * mm.mesh.surface_get_array_index_len(0) / 3
	_relatar("produto_instancias", instancias)
	_relatar("produto_triangulos", tris)
	_relatar("produto_chamadas", chamadas)
	_relatar("produto_vagas", p.vagas.size())
	var inicial := _unidades(p)

	# Na frente da geladeira, olhando a terceira prateleira de uma porta.
	var olho := em * Vector3(MercadoBuilder.CENTRO_PORTA + 0.2, 0.0, 9.0)
	var mira := em * Vector3(MercadoBuilder.CENTRO_PORTA + 0.2, 1.1, 10.1)
	await _posar(arvore, jogador, olho, mira)
	await arvore.create_timer(0.3).timeout
	var antes := _prompt(jogador)
	_relatar("prompt_geladeira_fechada", antes)
	await _foto(arvore, "07_geladeira")
	await _apertar(arvore, &"interagir")
	await arvore.create_timer(0.7).timeout
	var aberta := _prompt(jogador)
	_relatar("prompt_geladeira_aberta", aberta)
	await _foto(arvore, "08_geladeira_aberta")
	await _apertar(arvore, &"interagir")
	await arvore.create_timer(0.5).timeout
	var mao := StringName(EstoqueMercado.na_mao().get("sku", ""))
	_relatar("na_mao", mao)
	_relatar("pegou_um", 1 if _unidades(p) == inicial - 1 and mao != &"" else 0)
	await _foto(arvore, "09_na_mao")
	await _apertar(arvore, &"examinar")
	await arvore.create_timer(1.6).timeout
	await _foto(arvore, "10_lendo")
	await _apertar(arvore, &"examinar")
	await arvore.create_timer(0.4).timeout
	_relatar("prompt_devolver", _prompt(jogador))
	await _apertar(arvore, &"interagir")
	await arvore.create_timer(0.6).timeout
	_relatar("devolveu", 1 if _unidades(p) == inicial 		and StringName(EstoqueMercado.na_mao().get("sku", "")) == &"" else 0)
	var s := EstoqueMercado.saidas(p.loja)
	var fora := 0
	for d: int in s:
		fora += int(s[d])
	_relatar("conservacao_fora", fora)

	# O salao cheio: o corredor do meio, as pontas vistas da porta, o cigarro.
	await _posar(arvore, jogador, em * Vector3(MercadoBuilder.CENTRO_PORTA, 0.0, 3.4),
		em * Vector3(MercadoBuilder.CENTRO_PORTA + 0.6, 0.9, 7.5))
	await arvore.create_timer(0.4).timeout
	await _foto(arvore, "11_corredor")
	await _posar(arvore, jogador, em * Vector3(12.9, 0.0, 1.2),
		em * Vector3(12.2, 0.8, 3.0))
	await _foto(arvore, "12_ponta_panetone")
	await _posar(arvore, jogador, em * Vector3(12.9, 0.0, 6.0),
		em * Vector3(12.19 + 0.43, 0.7, 6.0))
	await _foto(arvore, "13_prateleira_de_perto")
	await _posar(arvore, jogador, em * Vector3(7.3, 0.0, 3.2),
		em * Vector3(4.8, 1.6, 3.2))
	await _foto(arvore, "14_cigarro")
	await _posar(arvore, jogador, em * Vector3(10.5, 0.0, 8.95),
		em * Vector3(14.0, 1.0, 10.2))
	await _foto(arvore, "15_camara_fria")

	# O custo: tempo de quadro sem vsync, do corredor olhando as gondolas, com e
	# sem os produtos, alternando para a outra placa ou o turbo nao decidirem.
	await _posar(arvore, jogador, em * Vector3(MercadoBuilder.CENTRO_PORTA, 0.0, 2.4),
		em * Vector3(MercadoBuilder.CENTRO_PORTA, 0.9, 8.0))
	var vsync := DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var com: Array[float] = []
	var sem: Array[float] = []
	for rodada in 4:
		p.visible = rodada % 2 == 0
		await arvore.create_timer(0.3).timeout
		var ms := await _tempo_de_quadro(arvore, 90)
		(com if p.visible else sem).append(ms)
	p.visible = true
	DisplayServer.window_set_vsync_mode(vsync)
	com.sort()
	sem.sort()
	_relatar("quadro_ms_com_produto", snappedf(com[0], 0.01))
	_relatar("quadro_ms_sem_produto", snappedf(sem[0], 0.01))
	_relatar("gpu", RenderingServer.get_video_adapter_name())
	_pasta = PASTA_CAPTURA


## Mediana do tempo entre quadros, em ms, sobre `n` quadros.
static func _tempo_de_quadro(arvore: SceneTree, n: int) -> float:
	var tempos: Array[float] = []
	var antes := Time.get_ticks_usec()
	for k in n:
		await arvore.process_frame
		var agora := Time.get_ticks_usec()
		tempos.append(float(agora - antes) / 1000.0)
		antes = agora
	tempos.sort()
	return tempos[n / 2]
