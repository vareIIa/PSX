## Palco e verificacao da camera de cinema, da fala com escolha e do olho.
##
## Dois usos:
##
##   `tests/m1_a.gd`          bancada sem cidade: monta um chao, uma parede, dois
##                            Ator e o Marea de cena, percorre os 13 planos e
##                            AFIRMA onde a lente ficou; depois roda uma
##                            `Escolha.perguntar` com borboleta e confere a flag
##                            e o `OlhoBorboleta.terminou`.
##   `TesteCinema.executar`   na cidade, para VER: o mesmo palco na frente do
##                            jogador, cada plano com o nome dele na legenda e
##                            uma pergunta de verdade no fim, esperando a tecla.
##                            Quem liga e o `cidade.gd` (flag `--teste-cinema`,
##                            a cargo da tarefa de missao, dona do arquivo).
##
## O que se afirma, e por que
## --------------------------
## Headless nao renderiza, entao "o plano ficou bonito" nao e verificavel aqui.
## O que e: a lente esta onde o tipo promete (close perto do rosto, grua alta,
## POV no olho, interior DENTRO da caixa do carro), olha para o assunto, respeita
## o lado da linha de acao, nao nasce atras de parede, e os planos moveis andam
## na direcao certa. E isso que quebra quando alguem mexe em sinal de eixo.
class_name TesteCinema
extends RefCounted

const LADO_A := Vector3(0.0, 0.0, 0.0)
const LADO_B := Vector3(0.0, 0.0, -1.6)
## Duracao de cada plano na bancada e na demonstracao.
const DUR_BANCADA := 0.35
const DUR_DEMO := 2.6

static var _falhas: PackedStringArray = []
static var _total := 0


# --- palco ------------------------------------------------------------------

## Chao, dois personagens frente a frente, o carro de lado e uma parede longe
## (a do teste de oclusao fica com um terceiro, sozinho). `origem` e o rumo
## posicionam tudo, para a demo nascer na frente do jogador.
static func montar_palco(pai: Node3D, origem: Transform3D = Transform3D.IDENTITY,
		com_chao: bool = true) -> Dictionary:
	var raiz := Node3D.new()
	raiz.name = "PalcoCinema"
	pai.add_child(raiz)
	raiz.global_transform = origem
	if com_chao:
		_caixa(raiz, Vector3(60.0, 0.2, 60.0), Vector3(0.0, -0.1, 0.0))

	var a := _ator(raiz, Elenco.BERG, LADO_A, LADO_B)
	var b := _ator(raiz, Elenco.HELMER, LADO_B, LADO_A)

	var carro := Carro.new()
	carro.name = "MareaDeCena"
	var ficha := Elenco.ficha(Elenco.BERG)
	carro.preparar(ficha, Vector2i.ZERO, Vector4i.ZERO, int(ficha.get("id", 1)))
	carro.modelo = Carroceria.Modelo.MAREA
	carro.tinta_fixa = Color(0.04, 0.04, 0.05)
	carro.set_meta(&"ignorar_ia", true)
	raiz.add_child(carro)
	carro.estacionar_solto(origem * Vector3(4.5, 0.0, -0.8), origem.basis.get_euler().y)

	# Sozinho de frente para uma parede a 1 m: o close padrao (lente a 1,15 m
	# do rosto, para a frente) nasceria dentro dela.
	var c := _ator(raiz, Elenco.JOTA, Vector3(-9.0, 0.0, 0.0), Vector3(-9.0, 0.0, -5.0))
	var parede := _caixa(raiz, Vector3(4.0, 3.0, 0.2), Vector3(-9.0, 1.5, -1.0))
	return {"raiz": raiz, "a": a, "b": b, "carro": carro, "sozinho": c, "parede": parede}


static func _ator(raiz: Node3D, quem: StringName, onde: Vector3, olha: Vector3) -> Ator:
	var a := Ator.new()
	a.name = String(quem).capitalize()
	a.preparar(quem, Elenco.ficha(quem))
	raiz.add_child(a)
	a.position = onde
	a.encarar(raiz.global_transform * olha)
	return a


static func _caixa(raiz: Node3D, tamanho: Vector3, onde: Vector3) -> StaticBody3D:
	var corpo := StaticBody3D.new()
	corpo.collision_layer = 1
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = tamanho
	forma.shape = caixa
	corpo.add_child(forma)
	var malha := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tamanho
	malha.mesh = bm
	corpo.add_child(malha)
	raiz.add_child(corpo)
	corpo.position = onde
	return corpo


# --- bancada ------------------------------------------------------------------

## Roda tudo e devolve as falhas. Vazio = passou.
static func verificar(arvore: SceneTree, palco: Dictionary) -> PackedStringArray:
	_falhas = PackedStringArray()
	_total = 0
	var cinema := arvore.root.get_node(^"/root/Cinema")
	# Dois quadros de fisica para a parede e os corpos entrarem no espaco: o
	# raio de oclusao consulta o servidor de fisica, e corpo recem-criado so
	# existe la depois do primeiro passo.
	await arvore.physics_frame
	await arvore.physics_frame
	cinema.call(&"iniciar", true)
	await _planos(arvore, palco)
	await _regra_dos_180(palco)
	await _oclusao(palco)
	await _tremor(arvore)
	await cinema.call(&"encerrar")
	await _escolha(arvore, palco)
	await _olho(arvore)
	print("")
	print("%d de %d afirmacoes" % [_total - _falhas.size(), _total])
	return _falhas


static func _afirmar(ok: bool, nome: String, detalhe: String = "") -> void:
	_total += 1
	if ok:
		print("[OK] %s" % nome)
	else:
		print("[X ] %s  %s" % [nome, detalhe])
		_falhas.append(nome)


static func _cam(arvore: SceneTree) -> Camera3D:
	return arvore.root.get_viewport().get_camera_3d()


## A lente olha para o ponto? (o ponto cai perto do meio do quadro)
static func _olha(cam: Camera3D, ponto: Vector3, folga: float = 0.97) -> bool:
	var frente := -cam.global_transform.basis.z
	var para := (ponto - cam.global_position).normalized()
	return frente.dot(para) > folga


static func _planos(arvore: SceneTree, palco: Dictionary) -> void:
	var a: Ator = palco["a"]
	var b: Ator = palco["b"]
	var carro: Carro = palco["carro"]
	var cinema := arvore.root.get_node(^"/root/Cinema")
	var olho_a := PlanoCena.olho_de(a)

	for tipo: int in PlanoCena.Tipo.values():
		var alvo: Node3D = carro if tipo == PlanoCena.Tipo.CARRO_INTERIOR else a
		var outro: Node3D = b
		var dur := DUR_BANCADA
		await cinema.call(&"plano", tipo, alvo, outro, dur, {"lado": 1})
		var q: Dictionary = cinema.get(&"ultimo_plano")
		var cam := _cam(arvore)
		var nome := "plano %s" % PlanoCena.Tipo.keys()[tipo]
		_afirmar(cam != null and cam.name == "CameraCinematica", nome + ": camera do cinema e a corrente")
		if cam == null:
			continue
		var p := cam.global_position
		_afirmar(p.is_finite(), nome + ": posicao finita", str(p))
		match tipo:
			PlanoCena.Tipo.ESTABELECIMENTO:
				_afirmar(p.y > 4.0 and p.distance_to(olho_a) > 9.0, nome + ": alto e longe", str(p))
			PlanoCena.Tipo.DOIS_MEDIO:
				var meio := olho_a.lerp(PlanoCena.olho_de(b), 0.5)
				var d := p.distance_to(meio)
				_afirmar(d > 2.0 and d < 6.0, nome + ": distancia de dois-shot", "%.2f" % d)
				_afirmar(_olha(cam, meio - Vector3.UP * 0.25, 0.95), nome + ": olha o meio dos dois")
			PlanoCena.Tipo.CLOSE:
				var d2 := p.distance_to(olho_a)
				_afirmar(d2 > 0.8 and d2 < 1.6, nome + ": perto do rosto", "%.2f" % d2)
				_afirmar(absf(cam.fov - 34.0) < 0.5, nome + ": lente de close (34)", str(cam.fov))
				_afirmar(_olha(cam, olho_a), nome + ": olha o rosto")
			PlanoCena.Tipo.CLOSE_EXTREMO:
				_afirmar(p.distance_to(olho_a) < 0.9, nome + ": colado nos olhos")
				_afirmar(absf(cam.fov - 22.0) < 0.5, nome + ": lente 22")
			PlanoCena.Tipo.SOBRE_OMBRO:
				var olho_b := PlanoCena.olho_de(b)
				_afirmar(p.distance_to(olho_b) < 1.1, nome + ": atras do ombro de quem escuta",
					"%.2f" % p.distance_to(olho_b))
				# Quem escuta fica entre a lente e quem fala: a lente esta do lado
				# de B, mais longe de A do que B esta.
				_afirmar(p.distance_to(olho_a) > olho_b.distance_to(olho_a), nome + ": B entre a lente e A")
				_afirmar(_olha(cam, olho_a, 0.98), nome + ": olha A")
			PlanoCena.Tipo.CONTRA_PLONGEE:
				_afirmar(p.y < 0.8 and -cam.global_transform.basis.z.y > 0.2, nome + ": de baixo para cima")
			PlanoCena.Tipo.PLONGEE:
				_afirmar(p.y > 3.0 and -cam.global_transform.basis.z.y < -0.3, nome + ": de cima para baixo")
			PlanoCena.Tipo.CARRO_INTERIOR:
				var local := carro.global_transform.affine_inverse() * p
				var m := carro.medidas()
				var dentro := absf(local.x) < float(m["largura"]) * 0.5 \
					and absf(local.z) < float(m["comprimento"]) * 0.5 \
					and local.y > 0.3 and local.y < float(m["altura"])
				_afirmar(dentro, nome + ": lente dentro da cabine", str(local))
				var banco: Vector3 = m["banco_motorista"]
				_afirmar(local.z < banco.z, nome + ": na frente dos bancos, de costas para o vidro")
			PlanoCena.Tipo.CEU_GRUA:
				var de: Vector3 = q["de"]
				_afirmar(p.y > de.y + 10.0, nome + ": subiu (%.1f -> %.1f)" % [de.y, p.y])
			PlanoCena.Tipo.ACOMPANHAMENTO:
				pass
			PlanoCena.Tipo.DOLLY_IN:
				var de_i: Vector3 = q["de"]
				_afirmar(p.distance_to(olho_a) < de_i.distance_to(olho_a) - 1.0, nome + ": chegou mais perto")
			PlanoCena.Tipo.DOLLY_OUT:
				var de_o: Vector3 = q["de"]
				_afirmar(p.distance_to(olho_a) > de_o.distance_to(olho_a) + 1.0, nome + ": foi para longe")
			PlanoCena.Tipo.POV:
				_afirmar(p.distance_to(olho_a) < 0.3, nome + ": no olho de A")
				_afirmar(_olha(cam, PlanoCena.olho_de(b), 0.99), nome + ": olhando B")

	# Acompanhamento de verdade: o alvo anda tres metros e a lente vai junto.
	var de_a := a.global_position
	var andar := a.create_tween()
	andar.tween_property(a, "global_position", de_a + PlanoCena.frente_de(a) * 3.0, 1.0)
	await cinema.call(&"plano", PlanoCena.Tipo.ACOMPANHAMENTO, a, null, 1.2, {})
	var cam2 := _cam(arvore)
	var d3 := cam2.global_position.distance_to(PlanoCena.olho_de(a))
	_afirmar(d3 > 1.5 and d3 < 5.0, "acompanhamento: a lente seguiu quem andou", "%.2f" % d3)
	_afirmar(_olha(cam2, PlanoCena.olho_de(a), 0.9), "acompanhamento: e continua olhando")
	a.global_position = de_a
	a.encarar(b.global_position)

	# Interior com o carro andando: a lente vai parafusada nele.
	await cinema.call(&"plano", PlanoCena.Tipo.CARRO_INTERIOR, carro, null, 0.0, {})
	var antes := carro.global_transform.affine_inverse() * _cam(arvore).global_position
	carro.global_position += carro.global_transform.basis.z * -2.0
	await arvore.process_frame
	await arvore.process_frame
	var depois := carro.global_transform.affine_inverse() * _cam(arvore).global_position
	_afirmar(antes.distance_to(depois) < 0.05, "interior do carro: a lente anda com o carro",
		"%.3f" % antes.distance_to(depois))
	carro.global_position -= carro.global_transform.basis.z * -2.0


## Mesmo lado da linha em todos os planos de uma conversa; lado oposto so com
## `lado` trocado.
static func _regra_dos_180(palco: Dictionary) -> void:
	var a: Ator = palco["a"]
	var b: Ator = palco["b"]
	var eixo := b.global_position - a.global_position
	var normal := eixo.normalized().cross(Vector3.UP)
	var lados: Array[float] = []
	for tipo: int in [PlanoCena.Tipo.DOIS_MEDIO, PlanoCena.Tipo.CLOSE, PlanoCena.Tipo.SOBRE_OMBRO]:
		for quem: int in 2:
			var alvo := a if quem == 0 else b
			var outro := b if quem == 0 else a
			# O lado e da linha, nao de quem fala: o contraplano recebe o mesmo
			# `lado` e tem de cair do mesmo lado.
			var q := PlanoCena.calcular(tipo, alvo, outro, {"lado": 1})
			var de: Vector3 = q["de"]
			lados.append(signf((de - a.global_position).dot(normal)))
	var todos_iguais := true
	for s: float in lados:
		todos_iguais = todos_iguais and s == lados[0]
	_afirmar(todos_iguais, "180 graus: plano e contraplano do mesmo lado da linha", str(lados))
	var q1 := PlanoCena.calcular(PlanoCena.Tipo.DOIS_MEDIO, a, b, {"lado": 1})
	var q2 := PlanoCena.calcular(PlanoCena.Tipo.DOIS_MEDIO, a, b, {"lado": -1})
	var s1 := signf((Vector3(q1["de"]) - a.global_position).dot(normal))
	var s2 := signf((Vector3(q2["de"]) - a.global_position).dot(normal))
	_afirmar(s1 == -s2, "180 graus: trocar `lado` atravessa a linha")


static func _oclusao(palco: Dictionary) -> void:
	var c: Ator = palco["sozinho"]
	var parede: StaticBody3D = palco["parede"]
	var q := PlanoCena.calcular(PlanoCena.Tipo.CLOSE, c, null, {"distancia": 2.4})
	var de: Vector3 = q["de"]
	var olho := PlanoCena.olho_de(c)
	_afirmar(bool(q["ocluido"]), "oclusao: o raio achou a parede")
	# A lente ficou do lado de ca da parede (a face dela que da para o ator).
	var face_z := parede.global_position.z + 0.1
	_afirmar(de.z > face_z and olho.distance_to(de) < 1.0,
		"oclusao: a lente veio para a frente da parede", str(de))
	var livre := PlanoCena.calcular(PlanoCena.Tipo.CLOSE, palco["a"], palco["b"], {})
	_afirmar(not bool(livre["ocluido"]), "oclusao: sem parede a lente fica onde o plano manda")


static func _tremor(arvore: SceneTree) -> void:
	var cinema := arvore.root.get_node(^"/root/Cinema")
	cinema.call(&"tremor", 0.6)
	var mexeu := false
	for i: int in 20:
		await arvore.process_frame
		var cam := _cam(arvore)
		if cam != null and (absf(cam.h_offset) > 0.001 or absf(cam.v_offset) > 0.001):
			mexeu = true
	_afirmar(mexeu, "tremor: a lente treme")
	cinema.call(&"tremor", 0.0)
	await arvore.process_frame
	var cam2 := _cam(arvore)
	_afirmar(cam2.h_offset == 0.0 and cam2.v_offset == 0.0, "tremor: zero devolve a lente parada")


static func _escolha(arvore: SceneTree, palco: Dictionary) -> void:
	var escolha := arvore.root.get_node(^"/root/Escolha")
	var borboleta := arvore.root.get_node(^"/root/Borboleta")
	var berg: Ator = palco["a"]
	borboleta.call(&"limpar")

	var fim: Array[bool] = [false]
	var falar := func() -> void:
		var linhas: Array[String] = ["Eu te vi na praca, rapaz.", "No chao. Igual eu fiquei."]
		await escolha.call(&"falar", "BERG", linhas, berg)
		fim[0] = true
	falar.call()
	await arvore.process_frame
	_afirmar(bool(escolha.get(&"ativo")), "escolha: a caixa abriu")
	_afirmar(escolha.call(&"nome_na_fita") == "BERG", "escolha: nome na fita")
	_afirmar(String(escolha.call(&"texto")).begins_with("Eu te vi"), "escolha: primeira linha no papel")
	var toques := 0
	while not fim[0] and toques < 20:
		escolha.call(&"avancar")
		toques += 1
		await arvore.process_frame
	_afirmar(fim[0] and toques >= 2 and toques <= 4,
		"escolha: duas linhas avancando na tecla (completar, seguir)", str(toques))

	var resposta: Array[StringName] = [&""]
	var perguntar := func() -> void:
		var opcoes: Array[Dictionary] = [
			{"chave": &"aceitar", "titulo": "Entrar no carro", "borboleta": &"m1_aceitou_carona_berg", "valor": true},
			{"chave": &"recusar", "titulo": "Nao, valeu", "borboleta": &"m1_aceitou_carona_berg", "valor": false},
		]
		resposta[0] = await escolha.call(&"perguntar", "BERG", "Vai entrar ou nao vai?", opcoes, berg)
	perguntar.call()
	# A caixa nao pode ter fechado entre a fala e a pergunta.
	_afirmar(bool(escolha.get(&"ativo")), "escolha: a caixa nao pisca entre fala e pergunta")
	escolha.call(&"avancar")
	await arvore.process_frame
	_afirmar(bool(escolha.call(&"escolhendo")), "escolha: a lista abre quando a pergunta termina")
	_afirmar(str(escolha.call(&"chaves")) == str([&"aceitar", &"recusar"]), "escolha: as opcoes na ordem")
	var olho := arvore.root.get_node(^"/root/OlhoBorboleta")
	var terminou: Array[bool] = [false]
	olho.connect(&"terminou", func() -> void: terminou[0] = true, CONNECT_ONE_SHOT)
	_afirmar(bool(escolha.call(&"escolher", &"recusar")), "escolha: escolher por chave")
	await arvore.process_frame
	_afirmar(resposta[0] == &"recusar", "escolha: perguntar devolve a chave", str(resposta[0]))
	_afirmar(borboleta.call(&"tem", &"m1_aceitou_carona_berg")
		and borboleta.call(&"valor", &"m1_aceitou_carona_berg") == false,
		"escolha: a flag do efeito borboleta foi gravada com o valor da opcao")
	_afirmar(bool(olho.call(&"mostrando")), "olho: apareceu na escolha com borboleta")
	var espera := 0.0
	while not terminou[0] and espera < 4.0:
		await arvore.process_frame
		espera += arvore.root.get_process_delta_time()
	_afirmar(terminou[0], "olho: OlhoBorboleta.terminou chegou", "%.2f s" % espera)
	_afirmar(espera > 1.6 and espera < 2.4, "olho: durou ~1,9 s", "%.2f" % espera)

	# Opcao sem borboleta e so conversa: nada de olho.
	var perguntar2 := func() -> void:
		var opcoes: Array[Dictionary] = [{"chave": &"so_conversa", "titulo": "E dai?"}]
		resposta[0] = await escolha.call(&"perguntar", "BERG", "", opcoes, berg)
	perguntar2.call()
	await arvore.process_frame
	escolha.call(&"escolher", &"so_conversa")
	await arvore.process_frame
	_afirmar(resposta[0] == &"so_conversa" and not bool(olho.call(&"mostrando")),
		"escolha: opcao sem borboleta nao mostra o olho")
	await arvore.create_timer(0.4).timeout
	_afirmar(not bool(escolha.get(&"ativo")), "escolha: a caixa fecha depois da ultima fala")


static func _olho(_arvore: SceneTree) -> void:
	var O: GDScript = load("res://src/ui/olho_borboleta.gd")
	_afirmar(is_equal_approx(O.pose_abertura(0.0), 0.0) and is_equal_approx(O.pose_abertura(0.5), 1.0),
		"olho: abre nos primeiros 0,25 s")
	_afirmar(O.pose_iris(0.6) < -0.99, "olho: olha para a esquerda", str(O.pose_iris(0.6)))
	_afirmar(O.pose_iris(1.1) > 0.99, "olho: olha para a direita", str(O.pose_iris(1.1)))
	_afirmar(is_equal_approx(O.pose_iris(1.44), 0.0) or absf(O.pose_iris(1.44)) < 0.05,
		"olho: volta ao centro")
	_afirmar(O.pose_abertura(1.5) < 0.01, "olho: pisca")
	_afirmar(O.pose_alfa(1.89) < 0.05 and absf(O.pose_alfa(1.0) - 0.55) < 0.001,
		"olho: alfa 0,55 e some no fim")


# --- demonstracao na cidade ---------------------------------------------------

## Monta o palco na frente do jogador e mostra os 13 planos com o nome de cada
## um na legenda, depois uma pergunta de verdade (espera a tecla).
static func executar(cena: Node, jogador: Node3D) -> void:
	var arvore := cena.get_tree()
	var frente := -jogador.global_transform.basis.z
	frente.y = 0.0
	var origem := Transform3D(Basis(Vector3.UP, atan2(-frente.x, -frente.z)),
		jogador.global_position + frente.normalized() * 4.0)
	var palco := montar_palco(cena as Node3D, origem, false)
	var a: Ator = palco["a"]
	var b: Ator = palco["b"]
	var carro: Carro = palco["carro"]
	var cinema := arvore.root.get_node(^"/root/Cinema")
	await arvore.create_timer(0.5).timeout
	cinema.call(&"iniciar")
	for tipo: int in PlanoCena.Tipo.values():
		var alvo: Node3D = carro if tipo == PlanoCena.Tipo.CARRO_INTERIOR else a
		cinema.call(&"legenda", PlanoCena.Tipo.keys()[tipo].replace("_", " "), DUR_DEMO)
		await cinema.call(&"plano", tipo, alvo, b, DUR_DEMO, {"lado": 1})
	await cinema.call(&"plano", PlanoCena.Tipo.SOBRE_OMBRO, a, b, 0.0, {"lado": 1})
	var escolha := arvore.root.get_node(^"/root/Escolha")
	var linhas: Array[String] = ["Eu te vi acordando no chao da praca.",
		"Aconteceu igualzinho comigo, uai."]
	await escolha.call(&"falar", "BERG", linhas, a)
	var opcoes: Array[Dictionary] = [
		{"chave": &"aceitar", "titulo": "Entrar no carro", "borboleta": &"m1_aceitou_carona_berg", "valor": true},
		{"chave": &"recusar", "titulo": "Nao, valeu", "borboleta": &"m1_aceitou_carona_berg", "valor": false},
	]
	cinema.call(&"plano", PlanoCena.Tipo.CLOSE, a, b, 0.0, {"lado": 1})
	var r: StringName = await escolha.call(&"perguntar", "BERG", "E ai, vai entrar ou nao vai?", opcoes, a)
	print("[teste-cinema] escolheu %s" % r)
	await arvore.create_timer(2.2).timeout
	await cinema.call(&"encerrar")
	palco["raiz"].queue_free()
