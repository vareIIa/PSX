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
	_medir_ambiente(arvore)
	await _testar_mercadoria(arvore, interior, jogador)
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

	# Doze por doze chunks, quase 400 m de lado. Basta para pegar varios
	# distritos e nao custa os segundos que uma varredura maior custaria: cada
	# chunk aqui e montado inteiro, com geometria.
	for cx in range(-6, 6):
		for cz in range(-6, 6):
			var dados := ChunkBuilder.construir(cx, cz)
			var tem_loja := false
			for prop: Dictionary in dados["props"]:
				if prop.get("tipo", "") != "porta":
					continue
				var tipo: StringName = prop.get("interior", &"apartamento")
				por_tipo[tipo] = int(por_tipo.get(tipo, 0)) + 1
				if bool(prop.get("deslizante", false)):
					deslizantes += 1
				if tipo == &"mercado":
					tem_loja = true
			# A fachada da loja entra na superficie do chunk, entao o chunk que
			# tem porta de mercado precisa ter tambem o letreiro aceso.
			if tem_loja:
				var sup: Dictionary = dados["superficies"]
				if sup.has(&"mercado_letreiro") and not PSXMesh.dados_vazio(sup[&"mercado_letreiro"]):
					chunks_com_fachada += 1

	_relatar("portas_mercado", int(por_tipo.get(&"mercado", 0)))
	_relatar("portas_casa", int(por_tipo.get(&"casa", 0)))
	_relatar("portas_apartamento", int(por_tipo.get(&"apartamento", 0)))
	_relatar("portas_deslizantes", deslizantes)
	_relatar("chunks_com_fachada", chunks_com_fachada)


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

	var faltando: Array[String] = []
	for exigida: StringName in SUPERFICIES_EXIGIDAS:
		if not superficies.has(String(exigida)):
			faltando.append(String(exigida))
	_relatar("superficies", superficies.size())
	_relatar("superficies_faltando", faltando.size())
	if not faltando.is_empty():
		_relatar("faltou", ",".join(faltando))


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
