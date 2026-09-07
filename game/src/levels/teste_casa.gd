## Rotina de verificacao da casa e do morador.
##
## Roda no jogo de verdade porque tudo que ela afirma depende de coisa que so
## existe rodando: a casa e montada numa thread, o morador mede distancia real
## ate o jogador e gira com limite de velocidade, e a conversa guarda estado no
## WorldState entre uma entrada e outra.
##
## Imprime linhas `[casa] chave=valor` que tools/verificar_casa.py confere.
class_name TesteCasa
extends RefCounted

const SEMENTE := 77123
## Quantos frames esperar por algo que depende da thread ou de uma animacao.
const ESPERA_LONGA := 3.5
const ESPERA_CURTA := 0.35


static func executar(cena: Node, jogador: Node3D) -> void:
	var arvore := cena.get_tree()
	await arvore.create_timer(1.0).timeout

	_relatar("inicio", 1)
	var retorno := jogador.global_transform

	Interiores.entrar(SEMENTE, retorno, &"casa")
	await arvore.create_timer(ESPERA_LONGA).timeout
	_relatar("entrou", 1 if Interiores.dentro else 0)

	var interior := arvore.current_scene.get_node_or_null("Interior")
	if interior == null:
		_relatar("interior_ausente", 1)
		_encerrar(arvore)
		return

	_medir_cidade()
	_medir_casa(interior)
	var npc := await _testar_morador(arvore, interior, jogador)
	await _testar_conversa(arvore, npc, jogador)
	await _testar_porta_trancada(arvore, interior, jogador)
	await _testar_saida(arvore, jogador, retorno)

	_relatar("fim", 1)
	_encerrar(arvore)


static func _encerrar(arvore: SceneTree) -> void:
	AudioDirector.silenciar_tudo()
	await arvore.process_frame
	arvore.quit(0)


static func _relatar(chave: String, valor: Variant) -> void:
	print("[casa] %s=%s" % [chave, valor])


# --- cidade -----------------------------------------------------------------

## Conta as portas de casa e de apartamento num pedaco da cidade.
##
## Verificar so o interior provaria metade: a casa pode estar perfeita e nenhuma
## porta da rua levar ate ela. Como o conteudo do chunk sai da coordenada, da
## para contar sem carregar nada.
static func _medir_cidade() -> void:
	var casas := 0
	var apartamentos := 0
	for cx in range(-6, 6):
		for cz in range(-6, 6):
			for prop: Dictionary in ChunkBuilder.construir(cx, cz)["props"]:
				if prop.get("tipo", "") != "porta":
					continue
				if prop.get("interior", &"apartamento") == &"casa":
					casas += 1
				else:
					apartamentos += 1
	_relatar("portas_casa", casas)
	_relatar("portas_apartamento", apartamentos)


# --- geometria --------------------------------------------------------------

static func _medir_casa(interior: Node) -> void:
	var tris := 0
	var malhas := 0
	for filho: Node in interior.get_children():
		if filho is MeshInstance3D:
			malhas += 1
			tris += PSXMesh.triangle_count((filho as MeshInstance3D).mesh)
	_relatar("tris", tris)
	_relatar("malhas", malhas)

	var corpo := interior.get_node_or_null("Colisao")
	_relatar("colisores", corpo.get_child_count() if corpo != null else 0)

	var luzes := 0
	for filho: Node in interior.get_children():
		if filho is Lampada:
			luzes += 1
	_relatar("luzes", luzes)


# --- morador ----------------------------------------------------------------

static func _testar_morador(arvore: SceneTree, interior: Node,
		jogador: Node3D) -> Npc:
	var npc: Npc = null
	for filho: Node in interior.get_children():
		if filho is Npc:
			npc = filho
			break
	if npc == null:
		_relatar("npc_ausente", 1)
		return null
	_relatar("npc", 1)

	# De costas: o angulo entre a frente dele e a direcao do jogador tem que ser
	# grande. E a encenacao de entrada, e ela so funciona se ele comecar virado
	# para a janela em vez de para a porta.
	_relatar("npc_de_costas", snappedf(_angulo_ate(npc, jogador), 0.01))

	# Aproxima o jogador. Teleporta em vez de andar: o teste e da reacao do
	# morador, nao do controlador, que ja tem verificacao propria.
	jogador.global_position = npc.global_position \
		+ npc.global_transform.basis.x * 2.2 + Vector3(0.0, 0.15, 0.0)
	await arvore.create_timer(ESPERA_LONGA).timeout
	_relatar("npc_virou", snappedf(_angulo_ate(npc, jogador), 0.01))
	return npc


## Angulo entre a frente do no e a direcao do jogador, em radianos.
static func _angulo_ate(npc: Node3D, jogador: Node3D) -> float:
	var d := jogador.global_position - npc.global_position
	d.y = 0.0
	if d.length() < 0.01:
		return 0.0
	return absf(angle_difference(npc.rotation.y, atan2(-d.x, -d.z)))


# --- conversa ---------------------------------------------------------------

static func _testar_conversa(arvore: SceneTree, npc: Npc, jogador: Node3D) -> void:
	if npc == null:
		return
	Inventario.de_dicionario({"espacos": [], "vida": 100})
	await arvore.process_frame

	npc.interagir(jogador)
	await arvore.create_timer(ESPERA_CURTA).timeout
	_relatar("dialogo_abriu", 1 if Dialogo.ativo else 0)
	_relatar("jogador_travado", 1 if bool(jogador.get("travado")) else 0)

	# Anda a conversa inteira. O teto existe para o teste falhar em vez de rodar
	# para sempre se a caixa deixar de fechar.
	var passos := 0
	while Dialogo.ativo and passos < 64:
		Dialogo.avancar()
		passos += 1
		await arvore.process_frame
	_relatar("dialogo_passos", passos)
	_relatar("dialogo_fechou", 0 if Dialogo.ativo else 1)
	await arvore.create_timer(ESPERA_CURTA).timeout
	_relatar("jogador_solto", 0 if bool(jogador.get("travado")) else 1)

	# O presente da primeira conversa. Qual item e depende do perfil da casa —
	# quem esta de mudanca da pilha, quem mora sozinho ha quarenta anos da
	# remedio — entao o teste pergunta ao morador em vez de supor.
	_relatar("presente", Inventario.quantidade(
		FalasMorador.PRESENTE_DO_PERFIL.get(npc.perfil, &"remedio")))

	# Segunda conversa: o assunto tem que ser outro. Repetir a fala de chegada
	# seria o defeito mais visivel que um personagem desses pode ter.
	var proximo := FalasMorador.proxima(SEMENTE, npc.ficha, npc.perfil)
	_relatar("assunto_avancou", 1 if proximo["chave"] != &"chegada" else 0)
	_relatar("assunto_2", String(proximo["chave"]))


# --- porta trancada ---------------------------------------------------------

static func _testar_porta_trancada(arvore: SceneTree, interior: Node,
		jogador: Node3D) -> void:
	var porta: Porta = null
	for filho: Node in interior.get_children():
		if filho is Porta and (filho as Porta).trancada:
			porta = filho
			break
	if porta == null:
		_relatar("porta_trancada_ausente", 1)
		return
	_relatar("porta_trancada", 1)
	_relatar("porta_rotulo_trancada", 1 if porta.rotulo_atual() == "Trancada" else 0)

	porta.interagir(jogador)
	await arvore.create_timer(ESPERA_LONGA).timeout
	# Trancada de verdade: acionar nao pode ter tirado o jogador do interior.
	_relatar("porta_trancada_nao_abre", 1 if Interiores.dentro else 0)


# --- saida ------------------------------------------------------------------

static func _testar_saida(arvore: SceneTree, jogador: Node3D,
		retorno: Transform3D) -> void:
	# A rua e esvaziada antes de sair. Este teste mede POSICAO do jogador, e
	# qualquer corpo encostado nele desloca a medida: o motor separa dois
	# CharacterBody3D sobrepostos empurrando os dois. O pedestre ja evita o
	# jogador por conta propria, mas medir com a calcada vazia tira a variavel
	# do teste em vez de confiar que ela e pequena.
	Multidao.parar()
	Interiores.sair()
	await arvore.create_timer(ESPERA_LONGA).timeout
	_relatar("saiu", 0 if Interiores.dentro else 1)
	_relatar("dist_do_retorno",
		snappedf(jogador.global_position.distance_to(retorno.origin), 0.01))
