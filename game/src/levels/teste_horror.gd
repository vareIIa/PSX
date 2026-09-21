## Rotina de verificacao dos sistemas da Fase 5 e da primeira ameaca.
##
## Roda no jogo de verdade, com fisica, porque e disso que os sistemas dependem:
## o radio mede distancia real, o inimigo faz raio de visao, o golpe chama
## `ferir`, o save le a posicao do corpo, o desmaio teleporta atras do preto.
## Uma suite headless nao exerce nada disso.
##
## Imprime linhas `[horror] chave=valor` que tools/verificar_horror.py confere.
class_name TesteHorror
extends RefCounted

const ESPACO_TESTE := 2


static func executar(cena: Node, jogador: Node3D) -> void:
	var arvore := cena.get_tree()
	await arvore.create_timer(1.0).timeout

	# A rua fica vazia durante o teste inteiro. Duas medidas daqui sao de posicao
	# do jogador e uma e de ruido com ele parado; um pedestre encostado nele mexe
	# nas tres, e a multidao nao e o assunto deste arquivo.
	Multidao.parar()

	_relatar("inicio", 1)
	var desmaio := arvore.get_first_node_in_group(&"desmaio") as Desmaio
	if desmaio != null:
		desmaio.instantaneo = true
	await _testar_inventario(arvore)
	await _testar_radio(cena, arvore, jogador)
	await _testar_inimigo(cena, arvore, jogador)
	await _testar_golpe(cena, arvore, jogador)
	await _testar_save(arvore, jogador)
	await _testar_desmaio(arvore, jogador)
	_relatar("fim", 1)
	# Um frame para o servidor de audio devolver os playbacks antes de encerrar.
	AudioDirector.silenciar_tudo()
	await arvore.process_frame
	arvore.quit(0)


static func _relatar(chave: String, valor: Variant) -> void:
	print("[horror] %s=%s" % [chave, valor])


# --- inventario -------------------------------------------------------------

static func _testar_inventario(arvore: SceneTree) -> void:
	Inventario.de_dicionario({"espacos": [], "vida": 100})
	await arvore.process_frame

	_relatar("inv_vazio", Inventario.espacos_livres())

	Inventario.adicionar(&"municao_9mm", 12)
	_relatar("inv_municao", Inventario.quantidade(&"municao_9mm"))

	# Empilhamento: 12 balas cabem num espaco so, com teto de 30.
	_relatar("inv_ocupados_apos_pilha", Inventario.ESPACOS - Inventario.espacos_livres())

	# Enche a bolsa e confirma que a sobra volta em vez de sumir.
	for i in Inventario.ESPACOS:
		Inventario.adicionar(&"pistola", 1)
	var sobra := Inventario.adicionar(&"chave_apartamento", 1)
	_relatar("inv_sobra_com_bolsa_cheia", sobra)

	# Cura consome e nao passa do maximo.
	Inventario.de_dicionario({"espacos": [], "vida": 40})
	Inventario.adicionar(&"bandagem", 2)
	var usou := Inventario.usar(0)
	_relatar("inv_curou", 1 if usou else 0)
	_relatar("inv_vida_apos_cura", Inventario.vida)
	_relatar("inv_bandagens_restantes", Inventario.quantidade(&"bandagem"))


# --- radio ------------------------------------------------------------------

static func _testar_radio(cena: Node, arvore: SceneTree, jogador: Node3D) -> void:
	var radio: Radio = jogador.get("radio")
	if radio == null:
		_relatar("radio_ausente", 1)
		return

	Inventario.adicionar(&"radio", 1)
	radio.ligado = true

	var alvo := Inimigo.new()
	alvo.semente = 777
	alvo.agride = false
	cena.add_child(alvo)

	for distancia: float in [40.0, 20.0, 10.0, 4.0]:
		alvo.global_position = jogador.global_position - jogador.global_transform.basis.z * distancia
		# Tempo para a suavizacao alcancar o alvo: a leitura instantanea mediria
		# a rampa, nao o valor.
		for i in 90:
			await arvore.physics_frame
		_relatar("radio_%d_m" % int(distancia), snappedf(radio.intensidade, 0.01))

	radio.ligado = false
	alvo.free()
	await arvore.process_frame


# --- inimigo ----------------------------------------------------------------

static func _testar_inimigo(cena: Node, arvore: SceneTree, jogador: Node3D) -> void:
	var inimigo := Inimigo.new()
	inimigo.semente = 4242
	inimigo.agride = false
	cena.add_child(inimigo)
	await arvore.physics_frame

	# De frente, na linha de visao: tem que perceber.
	var frente := jogador.global_position - jogador.global_transform.basis.z * 9.0
	inimigo.global_position = frente
	inimigo.look_at(jogador.global_position, Vector3.UP)
	for i in 20:
		await arvore.physics_frame
	_relatar("inimigo_ve_de_frente", 1 if inimigo.estado != Inimigo.Estado.VAGANDO
		and inimigo.estado != Inimigo.Estado.PARADO else 0)

	# Longe demais: nao pode perceber.
	var outro := Inimigo.new()
	outro.semente = 4243
	outro.agride = false
	cena.add_child(outro)
	outro.global_position = jogador.global_position \
		- jogador.global_transform.basis.z * (Inimigo.ALCANCE_VISAO + 25.0)
	outro.look_at(jogador.global_position, Vector3.UP)
	for i in 20:
		await arvore.physics_frame
	_relatar("inimigo_nao_ve_de_longe",
		1 if outro.estado in [Inimigo.Estado.VAGANDO, Inimigo.Estado.PARADO] else 0)

	# Solta os inimigos ANTES de medir, e zera a velocidade. A afirmacao aqui e
	# sobre a funcao de ruido: parado nao faz barulho. Com um inimigo a nove
	# metros caminhando para cima do jogador durante o teste, o empurrao dele
	# aparece como velocidade e a medicao passa a falar de outra coisa — este
	# criterio falhou uma vez no executavel e passou no editor pelo mesmo motivo.
	inimigo.free()
	outro.free()
	jogador.velocity = Vector3.ZERO
	await arvore.physics_frame
	_relatar("ruido_parado", snappedf(jogador.call("nivel_de_ruido"), 0.01))
	await arvore.process_frame


# --- save -------------------------------------------------------------------

static func _testar_save(arvore: SceneTree, jogador: Node3D) -> void:
	Inventario.de_dicionario({"espacos": [], "vida": 55})
	Inventario.adicionar(&"pe_de_cabra", 1)
	Inventario.adicionar(&"municao_9mm", 7)
	jogador.global_position = Vector3(12.0, 0.4 + Relevo.altura(12.0, -37.0), -37.0)
	jogador.set("bateria", 0.42)
	await arvore.physics_frame

	_relatar("save_gravou", 1 if SaveGame.salvar(ESPACO_TESTE, "teste") else 0)

	# Estraga tudo antes de carregar: se o carregamento nao restaurar, o teste
	# tem que falhar, e nao passar por coincidencia.
	Inventario.de_dicionario({"espacos": [], "vida": 10})
	Inventario.adicionar(&"bilhete", 1)
	jogador.global_position = Vector3(-400.0, 0.4, 400.0)
	jogador.set("bateria", 1.0)
	await arvore.physics_frame

	_relatar("save_carregou", 1 if SaveGame.carregar(ESPACO_TESTE) else 0)
	await arvore.physics_frame

	_relatar("save_vida", Inventario.vida)
	_relatar("save_municao", Inventario.quantidade(&"municao_9mm"))
	_relatar("save_pe_de_cabra", Inventario.quantidade(&"pe_de_cabra"))
	_relatar("save_bilhete_sumiu", 1 if Inventario.quantidade(&"bilhete") == 0 else 0)
	_relatar("save_bateria", snappedf(float(jogador.get("bateria")), 0.01))
	_relatar("save_dist_do_ponto",
		snappedf(jogador.global_position.distance_to(Vector3(12.0, 0.4 + Relevo.altura(12.0, -37.0), -37.0)), 0.01))

	SaveGame.apagar(ESPACO_TESTE)


# --- golpe ------------------------------------------------------------------

static func _testar_golpe(cena: Node, arvore: SceneTree, jogador: Node3D) -> void:
	# Os inimigos que o chunk plantou no mundo nao entram nesta medida.
	for n: Node in arvore.get_nodes_in_group(&"inimigo"):
		if n is Inimigo:
			(n as Inimigo).agride = false
	Inventario.de_dicionario({"espacos": [], "vida": 80})
	var inimigo := Inimigo.new()
	inimigo.semente = 9001
	inimigo.agride = true
	cena.add_child(inimigo)
	await arvore.physics_frame

	inimigo.global_position = jogador.global_position \
			- jogador.global_transform.basis.z * 1.2
	inimigo.look_at(jogador.global_position, Vector3.UP)
	inimigo.estado = Inimigo.Estado.PERSEGUINDO
	inimigo.ultimo_visto = jogador.global_position
	for i in 12:
		await arvore.physics_frame

	_relatar("inimigo_feriu", 1 if Inventario.vida < 80 else 0)
	_relatar("inimigo_dano", 80 - Inventario.vida)
	inimigo.free()
	await arvore.process_frame


# --- desmaio ----------------------------------------------------------------

static func _testar_desmaio(arvore: SceneTree, jogador: Node3D) -> void:
	var desmaio := arvore.get_first_node_in_group(&"desmaio") as Desmaio
	_relatar("desmaio_ausente", 0 if desmaio != null else 1)
	if desmaio == null:
		return

	# O save do bloco anterior emitiu `salvou`, e o desmaio lembrou a posicao
	# do jogador naquele momento. A prova e essa ligacao, nao um `lembrar_ponto`
	# chamado na mao: se o sinal nao estiver conectado, ele acorda onde caiu.
	var destino := Vector3(12.0, 0.4 + Relevo.altura(12.0, -37.0), -37.0)
	var minutos0 := WorldState.relogio.minutos()
	Inventario.de_dicionario({"espacos": [], "vida": 1})
	Inventario.ferir(5, jogador.global_position)

	_relatar("desmaio_vida", Inventario.vida)
	_relatar("desmaio_acordou", 1 if Inventario.vida == Desmaio.VIDA_AO_ACORDAR else 0)
	var perdidos := posmod(WorldState.relogio.minutos() - minutos0 + 24 * 60, 24 * 60)
	_relatar("desmaio_minutos_perdidos", perdidos)
	_relatar("desmaio_dist_do_orelhao",
			snappedf(jogador.global_position.distance_to(destino), 0.01))
	await arvore.process_frame
