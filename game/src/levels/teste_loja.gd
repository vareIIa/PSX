## Rotina de verificacao das lojas de verdade (LojaViva).
##
## Imprime linhas `[loja] chave=valor` que tools/verificar_lojas.py confere.
##
## O que prova: a rua comercial nao tem mais loja de casca (placa de loja so
## onde ha loja), cada loja tem quem atende e quem compra, entra-se nela andando
## da calcada sem atravessar nada e sem carregar interior, e a conversa com quem
## atende VENDE: o saldo desce e o item entra na mochila.
class_name TesteLoja
extends RefCounted

const ESPERA_LONGA := 3.5
## Janela do censo: a mesma do levantamento que achou 241 lojas de casca.
const JANELA_X := Vector2i(-8, 8)
const JANELA_Z := Vector2i(-10, 10)
const PASSO := 0.15
const PEITO := 0.95
## Da calcada ate 2,4 m dentro do salao: o corredor do cliente, antes do balcao
## (planta BALCAO) e da ilha (planta LIVRE).
const CAMINHO_DE := -2.0
const CAMINHO_ATE := 2.4


static func executar(cena: Node, jogador: Node3D) -> void:
	var arvore := cena.get_tree()
	await arvore.create_timer(1.5).timeout
	_relatar("inicio", 1)
	var loja := _medir_cidade()
	if loja.is_empty():
		_relatar("loja_para_medir", 0)
		_relatar("fim", 1)
		_encerrar(arvore)
		return
	_relatar("loja_para_medir", 1)
	_relatar("ramo_medido", loja["id"])
	Multidao.parar()
	await _medir_no_lugar(arvore, jogador, loja)
	await _comprar(arvore, jogador, loja)
	_relatar("fim", 1)
	_encerrar(arvore)


static func _encerrar(arvore: SceneTree) -> void:
	AudioDirector.silenciar_tudo()
	await arvore.process_frame
	arvore.quit(0)


static func _relatar(chave: String, valor: Variant) -> void:
	print("[loja] %s=%s" % [chave, valor])


# --- a cidade -------------------------------------------------------------------

## Lojas, ramos, equipe e clientes na janela; e as placas de loja que sobraram
## fora de loja (o nome da ComercioVivo sai em `letreiro_nome`).
static func _medir_cidade() -> Dictionary:
	var lojas := 0
	var ramos := {}
	var sem_equipe := 0
	var sem_cliente := 0
	var sem_produto := 0
	var placas_sem_loja := 0
	var tris_max := 0
	var perto := {}
	var dist_perto := INF
	for cx in range(JANELA_X.x, JANELA_X.y):
		for cz in range(JANELA_Z.x, JANELA_Z.y):
			var d := ChunkBuilder.construir(cx, cz)
			var sup: Dictionary = d["superficies"]
			var lista: Array = d["lojas"]
			if lista.is_empty():
				if sup.has(&"letreiro_nome") and not PSXMesh.dados_vazio(sup[&"letreiro_nome"]):
					placas_sem_loja += 1
				continue
			lojas += lista.size()
			tris_max = maxi(tris_max, int(d["triangulos"]))
			if not sup.has(&"loja_produtos") or PSXMesh.dados_vazio(sup[&"loja_produtos"]):
				sem_produto += 1
			var equipe := 0
			var clientes := 0
			var piso := NAN
			for p: Dictionary in d["props"]:
				if p.get("tipo", "") != "convidado":
					continue
				if p.get("contexto", &"") == &"loja":
					equipe += 1
					piso = Vector3(p["pos"]).y
				elif int(p.get("semente", 0)) >= 91509 + cx * 613 + cz * 1277 \
						and int(p.get("semente", 0)) < 91509 + cx * 613 + cz * 1277 + 400:
					clientes += 1
			if equipe == 0:
				sem_equipe += 1
			if clientes == 0 and String(lista[0]["id"]) != "borracharia":
				sem_cliente += 1
			for l: Dictionary in lista:
				ramos[l["id"]] = int(ramos.get(l["id"], 0)) + 1
				var origem := Vector3(cx * KitModular.CHUNK, 0.0, cz * KitModular.CHUNK)
				var boca: Vector3 = Vector3(l["boca"]) + origem
				var dist := Vector2(boca.x, boca.z).length()
				if dist < dist_perto and is_finite(piso):
					dist_perto = dist
					perto = l.duplicate()
					perto["boca"] = Vector3(boca.x, piso, boca.z)
					perto["plano"] = LojaViva.plano(cx, cz, float(l["largura"]))
	_relatar("lojas", lojas)
	_relatar("ramos", ramos.size())
	_relatar("lojas_sem_equipe", sem_equipe)
	_relatar("lojas_sem_cliente", sem_cliente)
	_relatar("lojas_sem_produto", sem_produto)
	_relatar("placas_sem_loja", placas_sem_loja)
	_relatar("tris_do_pior_chunk_de_loja", tris_max)
	return perto


# --- o lugar --------------------------------------------------------------------

static func _medir_no_lugar(arvore: SceneTree, jogador: Node3D, loja: Dictionary) -> void:
	var boca: Vector3 = loja["boca"]
	var nor: Vector3 = loja["normal"]
	var lat := KitModular._lateral(FundosBuilder._direcao_de(nor))
	var plano: Dictionary = loja["plano"]
	# Pela porta de vidro, na vitrine; pelo meio, na porta de aco.
	var x := 0.0
	if LojaViva.RAMOS[int(plano["ramo"])]["fachada"] == &"vitrine":
		x = float(plano["lado_porta"]) * (float(plano["boca"]) - float(plano["porta_w"])) * 0.5
	var ponto := func(z: float) -> Vector3:
		return boca + lat * x - nor * z
	jogador.global_position = ponto.call(CAMINHO_DE) + Vector3(0.0, 0.1, 0.0)
	if jogador.has_method("olhar_para"):
		jogador.call("olhar_para", ponto.call(4.0) + Vector3(0.0, 1.4, 0.0))
	if jogador.has_method("zerar_velocidade"):
		jogador.call("zerar_velocidade")
	await arvore.create_timer(ESPERA_LONGA).timeout

	var gente := 0
	var atendentes := 0
	var luzes := 0
	var portas := 0
	var centro: Vector3 = ponto.call(3.5)
	for no: Node in _todos(arvore.current_scene):
		var n3 := no as Node3D
		if n3 == null or not n3.is_inside_tree():
			continue
		if n3.global_position.distance_to(centro) > 6.0:
			continue
		if no is Convidado:
			gente += 1
			if not (no as Convidado).funcao.is_empty():
				atendentes += 1
		elif no is Porta:
			portas += 1
		elif no is OmniLight3D or no is SpotLight3D:
			luzes += 1
	_relatar("gente_na_loja", gente)
	_relatar("atendentes", atendentes)
	_relatar("luzes_na_loja", luzes)
	_relatar("portas_na_loja", portas)
	_relatar("dentro_de_interior", 1 if Interiores.dentro else 0)

	var espaco := jogador.get_world_3d().direct_space_state
	var forma := SphereShape3D.new()
	forma.radius = 0.3
	var bloqueado := 0
	var chegou := CAMINHO_DE
	var z := CAMINHO_DE
	while z <= CAMINHO_ATE:
		var onde: Vector3 = ponto.call(z)
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = forma
		q.transform = Transform3D(Basis.IDENTITY, onde + Vector3(0.0, PEITO, 0.0))
		q.collision_mask = 1
		q.exclude = [jogador.get_rid()]
		# So o que e do mundo: gente (Convidado) na frente nao conta como parede.
		var batidas := espaco.intersect_shape(q, 4)
		var solido := false
		for b: Dictionary in batidas:
			if not (b["collider"] is CharacterBody3D):
				solido = true
		if solido:
			bloqueado += 1
		else:
			chegou = z
		jogador.global_position = onde + Vector3(0.0, 0.1, 0.0)
		await arvore.physics_frame
		z += PASSO
	_relatar("caminho_bloqueado", bloqueado)
	_relatar("chegou_ate", snappedf(chegou, 0.01))
	# Piso rente a calcada: o chao sob o jogador la dentro e o da boca.
	var raio := PhysicsRayQueryParameters3D.create(ponto.call(1.5) + Vector3(0.0, 1.0, 0.0),
		ponto.call(1.5) + Vector3(0.0, -1.0, 0.0), 1, [jogador.get_rid()])
	var chao := espaco.intersect_ray(raio)
	_relatar("degrau_na_boca", snappedf(absf(float(Vector3(chao.get("position",
		Vector3(0, 99, 0))).y) - (boca.y)), 0.01) if not chao.is_empty() else 99.0)
	_relatar("dentro_apos_caminhar", 1 if Interiores.dentro else 0)


static func _todos(no: Node) -> Array[Node]:
	var saida: Array[Node] = [no]
	for filho: Node in no.get_children():
		saida.append_array(_todos(filho))
	return saida


# --- a compra -------------------------------------------------------------------

## Fala com quem atende e compra o primeiro item do ramo (ou usa o servico).
static func _comprar(arvore: SceneTree, jogador: Node3D, loja: Dictionary) -> void:
	var boca: Vector3 = loja["boca"]
	var atendente: Convidado = null
	var melhor := INF
	for no: Node in arvore.get_nodes_in_group(&"convidado"):
		var c := no as Convidado
		if c == null or c.funcao.is_empty():
			continue
		var d := c.global_position.distance_to(boca)
		if d < melhor:
			melhor = d
			atendente = c
	if atendente == null or melhor > 10.0:
		_relatar("atendente_achado", 0)
		return
	_relatar("atendente_achado", 1)
	_relatar("rotulo", "\"%s\"" % atendente.get_node("Gatilho").call("rotulo_atual")
		if atendente.has_node("Gatilho") else "?")
	var r: Dictionary = LojaViva.RAMOS[int(loja["ramo"])]
	Dinheiro.receber(100, "TESTE DA LOJA")
	var saldo0 := Dinheiro.saldo()
	atendente.abordar(jogador)
	await arvore.create_timer(0.6).timeout
	# O cumprimento vem antes da lista: avanca ate ela aparecer (TesteNpc).
	for k in 12:
		Conversa.avancar()
		await arvore.process_frame
	var chaves := Conversa.chaves()
	_relatar("opcoes", ",".join(chaves))
	_relatar("conversa_aberta", 1 if Conversa.ativo else 0)
	_relatar("opcao_sobre", 1 if chaves.has(&"loja_sobre") else 0)
	var venda: Array = r["venda"]
	if venda.is_empty():
		_relatar("compra", "sem_mercadoria")
		var s: StringName = StringName("loja_servico_" + String(r["servico"]))
		_relatar("opcao_servico", 1 if chaves.has(s) else 0)
	else:
		var item: StringName = venda[0]
		var antes := Inventario.quantidade(item)
		var chave := StringName("loja_comprar_" + String(item))
		_relatar("opcao_comprar", 1 if chaves.has(chave) else 0)
		Conversa.escolher(chave)
		await arvore.create_timer(0.4).timeout
		_relatar("pagou", saldo0 - Dinheiro.saldo())
		_relatar("preco", int(LojaViva.ITENS[item]["preco"]))
		_relatar("item_na_mochila", Inventario.quantidade(item) - antes)
