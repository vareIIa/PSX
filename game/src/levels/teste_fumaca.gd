## Rotina de verificacao da casa da fumaca e da primeira missao do jogo.
##
## Roda no jogo de verdade porque tudo que ela afirma depende de coisa que so
## existe rodando: a planta e montada numa thread, as nove pessoas sao corpos
## com esqueleto animado, a conversa guarda estado no WorldState e a missao
## atravessa tres sistemas — GPS, Interiores e Conversa — para fechar.
##
## Por que ela existe
## ------------------
## O resto desta frente foi provado por MEDIDA (tests/medir_*.gd) ou por
## CAPTURA. Uma coisa nao cabia em nenhuma das duas: "o jogador fala com o dono
## e a missao termina". Medida nao alcanca — e comportamento de tres autoloads
## conversando — e captura menos ainda, porque o que se ve numa foto e a caixa
## de dialogo aberta, nao a etapa avancando atras dela.
##
## Sem esta rotina, a unica afirmacao daquela fase era "eu li o codigo e parece
## certo", que e exatamente o tipo de frase que o PLANO_CASA_FUMACA diz nao
## aceitar.
##
## Imprime linhas `[fumaca] chave=valor` que tools/verificar_fumaca.py confere.
class_name TesteFumaca
extends RefCounted

const SEMENTE := 77551
const ESPERA_LONGA := 3.5
const ESPERA_CURTA := 0.35

## Teto de passos da conversa. Existe para o teste FALHAR em vez de rodar para
## sempre se a caixa deixar de fechar.
const MAX_PASSOS := 80

## O osso mais baixo de toda a sala, para o relatorio dizer QUANTO e nao so que
## passou do piso.
static var _menor_osso: float = 99.0


static func executar(cena: Node, jogador: Node3D) -> void:
	var arvore := cena.get_tree()
	await arvore.create_timer(1.0).timeout
	_relatar("inicio", 1)

	var retorno := jogador.global_transform
	_missao_ate_a_porta(jogador)

	Interiores.entrar(SEMENTE, retorno, &"casa_fumaca")
	await arvore.create_timer(ESPERA_LONGA).timeout
	_relatar("entrou", 1 if Interiores.dentro else 0)
	# Entrar fecha a etapa 1 e abre a de achar o dono. Se isto sair 1, a missao
	# voltou a terminar na soleira.
	_relatar("etapa_apos_entrar", _etapa())

	var interior := arvore.current_scene.get_node_or_null("Interior")
	if interior == null:
		_relatar("interior_ausente", 1)
		_encerrar(arvore)
		return

	_medir_gente(arvore)
	var dono := _achar_dono(arvore)
	await _testar_conversa_do_dono(arvore, dono, jogador)
	await _testar_assento(arvore, interior, jogador)
	await _testar_bolsa_cheia(arvore)

	_relatar("fim", 1)
	_encerrar(arvore)


static func _encerrar(arvore: SceneTree) -> void:
	AudioDirector.silenciar_tudo()
	await arvore.process_frame
	arvore.quit(0)


static func _relatar(chave: String, valor: Variant) -> void:
	print("[fumaca] %s=%s" % [chave, valor])


static func _etapa() -> int:
	return -1 if Missoes.atual.is_empty() else int(Missoes.atual["etapa"])


# --- missao -----------------------------------------------------------------

## Leva a missao do zero ate a porta, pelo caminho do jogador.
##
## Nao chama `avancar()` para pular etapa: o que esta sendo testado e a
## amarracao entre os sistemas, e um atalho aqui testaria o atalho. A etapa 0
## fecha quando o GPS traca uma rota para uma casa da fumaca, que e a licao de
## mapa que a missao existe para dar.
static func _missao_ate_a_porta(jogador: Node3D) -> void:
	Missoes.limpar()
	var missao := Missoes.comecar_primeira(jogador.global_position)
	_relatar("missao_comecou", 0 if missao.is_empty() else 1)
	_relatar("missao_etapas", 0 if missao.is_empty()
		else (missao["etapas"] as Array).size())
	_relatar("etapa_inicial", _etapa())

	# O app precisa estar ABERTO: `filtrar_por` mexe na lista do aparelho, e a
	# lista so existe depois que ele monta. E a mesma sequencia que a abertura
	# faz ao entregar o jogo ao jogador.
	Gps.abrir()
	_relatar("gps_casas", Gps.filtrar_por(&"casa_fumaca"))
	Gps.tracar_rota_no_primeiro()
	_relatar("etapa_apos_rota", _etapa())


# --- a gente da sala --------------------------------------------------------

## Quem esta na sala, e com o que na mao.
##
## Duas afirmacoes aqui vieram de defeito real:
##
##   controle    era pendurado em todo `papel != LIVRE`, e papel e POSTURA. Os
##               dois clientes sentados do bar assistiam futebol com DualShock
##               na mao. Agora e `com_controle`, e tem de ser exatamente dois.
##   pe_no_piso  a pose de sentado punha o pe tres centimetros ABAIXO do chao e
##               o joelho 39 cm atras do corpo. `medir_sentado.gd` prova isso no
##               esqueleto solto; aqui a prova e no corpo que esta na sala.
static func _medir_gente(arvore: SceneTree) -> void:
	var total := 0
	var com_controle := 0
	var fumando := 0
	var donos := 0
	var pe_abaixo := 0
	_menor_osso = 99.0
	for no: Node in arvore.get_nodes_in_group(&"convidado"):
		var c := no as Convidado
		if c == null or not c.is_inside_tree():
			continue
		total += 1
		if c.com_controle:
			com_controle += 1
		if c.fumando:
			fumando += 1
		if c.dono_da_casa:
			donos += 1
		var baixo := _pe_mais_baixo(c)
		_menor_osso = minf(_menor_osso, baixo)
		if baixo < -0.02:
			pe_abaixo += 1
	_relatar("gente", total)
	_relatar("com_controle", com_controle)
	_relatar("fumando", fumando)
	_relatar("donos", donos)
	_relatar("pe_abaixo_do_piso", pe_abaixo)
	_relatar("osso_mais_baixo_cm", roundi(_menor_osso * 100.0))


## O ponto mais baixo do esqueleto de alguem, em relacao ao piso do comodo.
static func _pe_mais_baixo(c: Convidado) -> float:
	var corpo := c.get_node_or_null("Corpo") as Corpo
	if corpo == null:
		return 0.0
	var esq := corpo.esqueleto()
	if esq == null:
		return 0.0
	# Sem isto as poses lidas sao as do quadro anterior, ou nenhuma.
	esq.force_update_all_bone_transforms()
	if esq.get_bone_count() == 0:
		return 0.0
	# A transformada de referencia e a do ESQUELETO, e nao a do corpo: a pose de
	# osso ja e relativa a ele, e `esq.global_transform` ja carrega a cadeia
	# Convidado -> Corpo -> Esqueleto inteira.
	var menor := 1e9
	var base := esq.global_transform
	for k in esq.get_bone_count():
		menor = minf(menor, (base * esq.get_bone_global_pose(k)).origin.y)
	# O piso do interior nao esta em zero: os comodos sao montados deslocados.
	return menor - c.global_position.y


static func _achar_dono(arvore: SceneTree) -> Convidado:
	for no: Node in arvore.get_nodes_in_group(&"convidado"):
		var c := no as Convidado
		if c != null and c.dono_da_casa:
			return c
	return null


# --- a conversa que fecha a missao ------------------------------------------

static func _testar_conversa_do_dono(arvore: SceneTree, dono: Convidado,
		jogador: Node3D) -> void:
	if dono == null:
		_relatar("dono_ausente", 1)
		return
	Inventario.de_dicionario({"espacos": [], "vida": 100})
	await arvore.process_frame

	_relatar("dono_rotulo_proprio",
		1 if dono.get_node("Gatilho").rotulo_atual().contains("dono") else 0)

	dono.abordar(jogador)
	await arvore.create_timer(ESPERA_CURTA).timeout
	_relatar("conversa_abriu", 1 if Conversa.ativo else 0)

	# O assunto da casa tem de estar na lista. Na rua ele nao pode estar — e por
	# isso as duas perguntas, e nao so a primeira.
	var f := dono.ficha.duplicate()
	f["dono_da_casa"] = true
	_relatar("role_na_casa", 1 if _tem_assunto(f, &"casa", &"role") else 0)
	_relatar("role_na_rua", 1 if _tem_assunto(f, &"rua", &"role") else 0)

	# `escolher` so acha o assunto depois que a LISTA abriu, e ela abre quando a
	# saudacao termina. Entao a rotina avanca a caixa ate o assunto existir, que
	# e literalmente o que o jogador faz: aperta ate aparecer o menu.
	var achou := false
	var tentativas := 0
	while not achou and tentativas < 12 and Conversa.ativo:
		achou = Conversa.escolher(&"role")
		if achou:
			break
		Conversa.avancar()
		tentativas += 1
		await arvore.process_frame
	_relatar("escolheu_role", 1 if achou else 0)
	_relatar("passos_ate_a_lista", tentativas)
	# Anda as linhas da resposta e depois ENCERRA pela opcao de sair.
	#
	# `avancar` sozinho nunca fecha esta caixa: terminada a resposta, ela volta
	# para a lista de assuntos e fica la esperando uma escolha. A primeira versao
	# deste teste batia no teto de 80 passos e reportava "nao fechou", que era
	# verdade sobre o teste e mentira sobre o jogo.
	# `sair` e escolhido UMA vez, e depois so se anda. Escolhendo a cada volta, a
	# despedida reiniciava sozinha e a caixa nunca chegava ao fim — a segunda
	# versao deste teste batia no teto de 80 passos por isso, e de novo era
	# verdade sobre o teste e mentira sobre o jogo.
	var passos := 0
	var pediu_para_sair := false
	while Conversa.ativo and passos < MAX_PASSOS:
		if not pediu_para_sair and Conversa.escolher(&"sair"):
			pediu_para_sair = true
		else:
			Conversa.avancar()
		passos += 1
		await arvore.process_frame
	_relatar("conversa_passos", passos)
	_relatar("conversa_fechou", 0 if Conversa.ativo else 1)

	await arvore.create_timer(ESPERA_CURTA).timeout
	_relatar("etapa_apos_falar", _etapa())
	_relatar("missao_concluida", 1 if Missoes.atual.is_empty() else 0)
	_relatar("presente", Inventario.quantidade(&"bilhete"))


static func _tem_assunto(ficha: Dictionary, contexto: StringName,
		chave: StringName) -> bool:
	for o: Dictionary in FalasNpc.opcoes(ficha, contexto):
		if StringName(o["chave"]) == chave:
			return true
	return false


# --- sentar -----------------------------------------------------------------

## Sentar baixa a LENTE e prende o jogador; levantar devolve tudo.
##
## O que este teste protege e a simetria. Uma interacao que muda tres coisas —
## posicao, altura do olho e trava — e esquece de desfazer UMA delas deixa o
## jogador de pe no meio da sala enxergando a 86 cm pelo resto da partida, e
## nada na tela diz por que. E o tipo de defeito que so aparece depois de o
## jogador ja ter saido da casa.
static func _testar_assento(arvore: SceneTree, interior: Node,
		jogador: Node3D) -> void:
	# Conta por CLASSE e rotulo, e nao por nome: Godot renomeia o segundo no
	# homonimo e o nome deixa de ser um jeito confiavel de achar o par.
	var assentos: Array[Interativo] = []
	for filho: Node in interior.get_children():
		var a := filho as Interativo
		if a != null and a.rotulo.begins_with("Sentar"):
			assentos.append(a)
	_relatar("assentos", assentos.size())
	if assentos.is_empty():
		return

	var antes := jogador.global_position
	var cadeira := assentos[0]
	cadeira.interagir(jogador)
	await arvore.create_timer(ESPERA_CURTA).timeout
	_relatar("sentado_travado", 1 if bool(jogador.get("travado")) else 0)
	_relatar("sentado_olho_cm", roundi(float(jogador.get("olho_override")) * 100.0))
	_relatar("sentado_mudou_de_lugar",
		1 if jogador.global_position.distance_to(antes) > 0.3 else 0)
	_relatar("sentado_rotulo_levantar",
		1 if cadeira.rotulo_atual().contains("Levantar") else 0)

	cadeira.interagir(jogador)
	await arvore.create_timer(ESPERA_CURTA).timeout
	_relatar("levantou_solto", 0 if bool(jogador.get("travado")) else 1)
	_relatar("levantou_olho_livre",
		1 if float(jogador.get("olho_override")) < 0.0 else 0)
	_relatar("levantou_voltou",
		1 if jogador.global_position.distance_to(antes) < 0.3 else 0)


# --- o defeito que travava a missao -----------------------------------------

## Bolsa cheia nao pode travar a primeira missao do jogo.
##
## Presente e missao estavam amarrados: `Inventario.adicionar` devolve 0 com a
## bolsa cheia, a funcao saia antes de `dono_respondeu()` e a etapa ficava
## aberta para sempre, sem nada na tela dizendo por que. Este teste prova a
## separacao — com a bolsa entupida, a missao fecha do mesmo jeito e o item so
## nao entra.
static func _testar_bolsa_cheia(arvore: SceneTree) -> void:
	Missoes.limpar()
	Missoes.comecar_primeira(Vector3.ZERO)
	if Missoes.atual.is_empty():
		_relatar("bolsa_cheia_sem_missao", 1)
		return
	Missoes.avancar()
	Missoes.avancar()
	_relatar("bolsa_etapa_antes", _etapa())
	Missoes.dono_respondeu()
	await arvore.process_frame
	_relatar("bolsa_missao_concluida", 1 if Missoes.atual.is_empty() else 0)
