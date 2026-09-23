## Rotina de verificacao da estufa: o ciclo de cultivo, a folha de pagamento e
## os dois que trabalham la dentro.
##
## Por que ela existe
## ------------------
## Quase nada desta frente cabe numa captura. Uma foto da estufa mostra plantas
## bonitas em vasos, e mostraria exatamente a mesma coisa se:
##
##   - regar nao fizesse nada
##   - a planta crescesse com o vaso seco
##   - a terra nunca gastasse
##   - o estado se perdesse ao sair pela porta
##   - Helmer estivesse contratado e nao trabalhasse
##   - o trabalho de quem fica enquanto o jogador esta fora nao acontecesse
##
## Os seis sao defeitos que um sistema de cultivo tem por padrao ate alguem
## provar que nao. Esta rotina prova, dentro do jogo rodando, com fisica e com
## os autoloads de verdade.
##
## O relogio e adiantado a mao (`WorldState.relogio.definir_minutos`) em vez de
## esperar: um ciclo de planta leva doze minutos de relogio, e um teste que
## espera doze minutos nao e rodado por ninguem. O que se adianta e o MESMO
## relogio que o jogo le, entao o caminho testado e o caminho real.
##
## Imprime linhas `[estufa] chave=valor` que tools/verificar_estufa.py confere.
class_name TesteEstufa
extends RefCounted

const SEMENTE := 77551
## A mesma conta de CasaFumacaBuilder._porta_dos_fundos: a estufa daquela casa.
const SEMENTE_ESTUFA := SEMENTE + 4242

const ESPERA_LONGA := 3.5
const ESPERA_CURTA := 0.35

## Quanto tempo se da aos fazendeiros para mexerem em alguma coisa.
##
## Uma tarefa custa a caminhada ate o insumo, a caminhada ate o vaso e o gesto.
## Vinte e cinco segundos e folgado para dois deles, e curto o bastante para a
## rotina inteira caber num minuto e meio.
const ESPERA_TRABALHO := 25.0


static func executar(cena: Node, jogador: Node3D) -> void:
	var arvore := cena.get_tree()
	# O iWeed manda a dupla entregar sozinho. Esta rotina mede a estufa parada:
	# Jota saindo pela porta no meio dela seria o jogo certo e a medida errada.
	IWeed.pausado = true
	await arvore.create_timer(1.0).timeout
	_relatar("inicio", 1)

	# A folha de pagamento comeca limpa. Sem isto a rotina mediria o que sobrou
	# de uma partida anterior no mesmo save.
	WorldState.limpar()

	var retorno := jogador.global_transform
	Interiores.entrar(SEMENTE, retorno, &"casa_fumaca")
	await arvore.create_timer(ESPERA_LONGA).timeout
	Interiores.atravessar(SEMENTE_ESTUFA, &"estufa",
		Vector3(3.8, 0.0, 1.35), Vector3(3.8, 1.45, 8.4))
	await arvore.create_timer(ESPERA_LONGA).timeout
	_relatar("entrou_na_estufa",
		1 if Interiores.tipo_atual() == &"estufa" else 0)

	var p := _plantacao(arvore)
	if p == null:
		_relatar("plantacao_ausente", 1)
		_encerrar(arvore)
		return

	_medir_sala(arvore, p)
	_medir_gente(arvore)
	await _testar_ciclo(arvore, p)
	await _testar_crescimento(arvore, p)
	await _testar_colheita(arvore, p)
	await _testar_persistencia(arvore, jogador)
	_testar_ausencia()
	await _testar_fazendeiros(arvore)
	await _testar_contratacao(arvore, jogador)
	_testar_lista_de_opcoes()

	_relatar("fim", 1)
	_encerrar(arvore)


static func _encerrar(arvore: SceneTree) -> void:
	AudioDirector.silenciar_tudo()
	await arvore.process_frame
	arvore.quit(0)


static func _relatar(chave: String, valor: Variant) -> void:
	print("[estufa] %s=%s" % [chave, valor])


static func _plantacao(arvore: SceneTree) -> Plantacao:
	return arvore.get_first_node_in_group(&"plantacao") as Plantacao


# --- a sala -----------------------------------------------------------------

## Quantos vasos, quantas malhas e quantos nascem vazios.
##
## `malhas` e a afirmacao que protege o orcamento de desenho: a plantacao tem de
## ser duas malhas — a do material opaco e a da folhagem — e nao uma por vaso.
## Com um no por vaso seriam vinte e quatro chamadas de desenho numa sala so,
## contra 120 no jogo inteiro, e nada na tela avisaria.
static func _medir_sala(arvore: SceneTree, p: Plantacao) -> void:
	_relatar("vasos", p.vasos_em.size())
	_relatar("potes", p.potes_em.size())
	var malhas := 0
	for filho: Node in p.get_children():
		if filho is MeshInstance3D:
			malhas += 1
	_relatar("malhas", malhas)
	_relatar("triangulos_plantacao", p.triangulos())

	var censo := Plantio.censo(p.vasos())
	_relatar("vazios_no_inicio", int(censo[&"vazio"]))
	_relatar("prontas_no_inicio", int(censo[&"pronta"]))

	# Areas de interacao: uma por vaso, mais as quatro da estacao de insumos e
	# da prateleira. Sao Area3D e nao desenham nada.
	var areas := 0
	for filho: Node in p.get_children():
		if filho is Interativo:
			areas += 1
	_relatar("areas", areas)
	_relatar("plantacao_nos",
		arvore.get_nodes_in_group(&"plantacao").size())

	# O comodo inteiro contra o orcamento do ART-BIBLE: 6.000 triangulos por
	# pedaco de mundo, 120 chamadas de desenho no jogo todo. A sala dobrou de
	# comprimento e ganhou vinte e quatro vasos vivos; o numero tem de ser dito,
	# e nao suposto.
	# O comodo e o PAI da plantacao, e nao `current_scene/Interior`.
	#
	# Atravessar uma porta interna manda o comodo anterior para `queue_free` e
	# acrescenta o novo no mesmo quadro: os dois convivem por um instante com o
	# mesmo nome, e o Godot renomeia o recem-chegado em silencio. Procurar por
	# nome devolve nulo e o relatorio some sem erro nenhum — foi o que
	# aconteceu, e e o mesmo tropeco que ja tinha custado o `assentos = 1` da
	# verificacao da casa.
	var interior := p.get_parent()
	if interior != null:
		var tris := 0
		var malhas_do_comodo := 0
		for filho: Node in interior.get_children():
			var mi := filho as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			malhas_do_comodo += 1
			tris += PSXMesh.triangle_count(mi.mesh)
		_relatar("triangulos_comodo", tris + p.triangulos())
		_relatar("malhas_do_comodo", malhas_do_comodo + 3)

	# O corredor esta LIVRE de ponta a ponta?
	#
	# A captura da entrada faz a sala parecer ter uns sete metros, e sete metros
	# seria um comodo diferente do que a planta descreve. Olhar a imagem nao
	# resolve isso — nevoa e queda de luz encurtam qualquer corredor —, entao a
	# resposta vem de um raio: da soleira ate onde ele bater.
	#
	# Desde a estufa de dez andares o corredor termina no ELEVADOR, e nao na
	# parede do fundo: a cabine parada no terreo esta de grade aberta para o
	# corredor e o raio entra nela ate a parede de barras do outro lado, a uns
	# 15,5 m da soleira. Muito menos que isso quer dizer que ha alguma coisa
	# atravessada no meio da sala, e ai a estufa comprida existe so no arquivo.
	var espaco := p.get_world_3d().direct_space_state
	var de := Plantacao.new().global_position
	de = Interiores.DESLOCAMENTO + EstufaBuilder.ENTRADA 		+ Vector3(0.0, 1.2, 0.0)
	var ate := Interiores.DESLOCAMENTO 		+ Vector3(EstufaBuilder.ENTRADA.x, 1.2, EstufaBuilder.FUNDO + 1.0)
	var consulta := PhysicsRayQueryParameters3D.create(de, ate)
	consulta.collide_with_areas = false
	var achou := espaco.intersect_ray(consulta)
	var alcance: float = (EstufaBuilder.FUNDO + 1.0 - EstufaBuilder.ENTRADA.z)
	if not achou.is_empty():
		alcance = de.distance_to(Vector3(achou["position"]))
	_relatar("corredor_livre_cm", roundi(alcance * 100.0))
	_relatar("corredor_chega_ao_fundo",
		1 if alcance > EstufaBuilder.ELEVADOR.z + Elevador.LADO * 0.5
			- EstufaBuilder.ENTRADA.z - 0.6
		else 0)


## Quem esta trabalhando ali, e se a pose nova poe o pe dentro do chao.
##
## O criterio do pe existe porque ja aconteceu: a pose de sentado da sala da
## frente punha o pe tres centimetros abaixo do piso e ninguem viu por duas
## fases. A postura TRABALHANDO e nova, e pose nova nao medida nao vale.
static func _medir_gente(arvore: SceneTree) -> void:
	var total := 0
	var jota := 0
	var helmer := 0
	var pe_abaixo := 0
	var menor := 99.0
	for no: Node in arvore.get_nodes_in_group(&"convidado"):
		var c := no as Convidado
		if c == null or not c.is_inside_tree():
			continue
		total += 1
		var nome := FalasNpc.rotulo(c.ficha)
		if nome == "JOTA":
			jota += 1
		if nome == "HELMER":
			helmer += 1
		var baixo := _pe_mais_baixo(c)
		menor = minf(menor, baixo)
		if baixo < -0.02:
			pe_abaixo += 1
	_relatar("gente_na_estufa", total)
	_relatar("jota", jota)
	_relatar("helmer", helmer)
	_relatar("pe_abaixo_do_piso", pe_abaixo)
	_relatar("osso_mais_baixo_cm", roundi(menor * 100.0))
	_relatar("na_folha", Profissoes.quantos(&"fazendeiro"))
	_medir_elenco(arvore)


## Jota e Helmer sao as MESMAS pessoas, sempre.
##
## O resto da cidade e derivado do id: a cara sai de um hash e ninguem escolheu
## qual. Estes dois nao — a aparencia deles e escrita a mao em `Aparencia.ELENCO`
## e amarrada ao id pelo `RegistroCivil.marcar_personagem`.
##
## O que pode dar errado sem ninguem ver
## -------------------------------------
## A amarracao passa por tres lugares (WorldState, o cache de fichas do registro
## e a tabela do elenco), e se qualquer um falhar o que aparece na sala e uma
## pessoa sorteada qualquer — de oculos ou nao, de bigode ou nao, da altura que
## calhar. Continua sendo um NPC plausivel num galpao, e nada na tela acusa.
##
## Por isso os criterios sao sobre os TRACOS que os identificam, e nao sobre
## "existe alguem chamado Jota".
static func _medir_elenco(arvore: SceneTree) -> void:
	var fichas: Dictionary = {}
	for no: Node in arvore.get_nodes_in_group(&"convidado"):
		var c := no as Convidado
		if c == null:
			continue
		var nome := FalasNpc.rotulo(c.ficha)
		if nome == "JOTA" or nome == "HELMER":
			fichas[nome] = c.ficha
	if not fichas.has("JOTA") or not fichas.has("HELMER"):
		_relatar("elenco_incompleto", 1)
		return

	var j: Dictionary = fichas["JOTA"]
	var h: Dictionary = fichas["HELMER"]
	var aj: Dictionary = j["aparencia"]
	var ah: Dictionary = h["aparencia"]

	# O rosto vem da linha do elenco, e nao do sorteio.
	_relatar("jota_rosto_proprio",
		1 if int(aj["linha_rosto"]) == Aparencia.LINHA_ELENCO else 0)
	_relatar("helmer_rosto_proprio",
		1 if int(ah["linha_rosto"]) == Aparencia.LINHA_ELENCO else 0)
	# E sao rostos DIFERENTES. Dois personagens apontando para a mesma celula
	# seriam a mesma pessoa com dois nomes, e o criterio de cima passaria.
	_relatar("elenco_rostos_distintos",
		1 if int(aj["rosto"]) != int(ah["rosto"]) else 0)
	# O alargador e o unico traco que se ve de perfil, e e a cor dele que separa
	# os dois quando o rosto ja nao se le.
	_relatar("elenco_perfis_distintos",
		1 if int(aj["perfil"]) != int(ah["perfil"]) else 0)

	_relatar("jota_altura_cm", roundi(float(aj["altura"]) * 100.0))
	_relatar("helmer_altura_cm", roundi(float(ah["altura"]) * 100.0))
	_relatar("jota_mais_alto",
		1 if float(aj["altura"]) - float(ah["altura"]) > 0.10 else 0)
	_relatar("jota_tatuado", 1 if bool(aj.get("tatuagem", false)) else 0)

	# Coque e cacho sao GEOMETRIA, e nao textura.
	#
	# Marcar `coque` e `cacheado` na tabela nao prova nada sozinho: se
	# `Corpo._montar_cabelo` deixasse de ler as duas chaves, a ficha continuaria
	# dizendo que Jota tem coque e o boneco sairia de cabelo solto. O que prova e
	# o corpo ficar MAIOR — sao as caixas a mais do novelo e dos seis tufos.
	_relatar("jota_coque", 1 if bool(aj.get("coque", false)) else 0)
	_relatar("helmer_cacheado", 1 if bool(ah.get("cacheado", false)) else 0)
	_relatar("elenco_cabelos_distintos",
		1 if bool(aj.get("coque", false)) != bool(ah.get("coque", false))
		and bool(aj.get("cacheado", false)) != bool(ah.get("cacheado", false))
		else 0)

	var liso := Corpo.new()
	liso.montar(_sem_penteado(aj))
	var com_coque := Corpo.new()
	com_coque.montar(aj)
	var com_cacho := Corpo.new()
	com_cacho.montar(ah)
	_relatar("tris_cabelo_liso", liso.triangulos())
	_relatar("tris_com_coque", com_coque.triangulos())
	_relatar("tris_com_cacho", com_cacho.triangulos())
	_relatar("coque_e_geometria",
		1 if com_coque.triangulos() > liso.triangulos() else 0)
	_relatar("cacho_e_geometria",
		1 if com_cacho.triangulos() > liso.triangulos() + 40 else 0)
	liso.free()
	com_coque.free()
	com_cacho.free()

	_relatar("helmer_sem_tatuagem",
		0 if bool(ah.get("tatuagem", false)) else 1)

	# A ficha que o DOCUMENTO usa e a mesma que o corpo usa.
	#
	# E o criterio que amarra as duas pontas: o retrato da identidade e do
	# celular sai de `RegistroCivil.identidade`, e o corpo na sala tambem. Se o
	# personagem fosse aplicado so na hora de criar o no — que foi a primeira
	# ideia —, Jota teria uma cara na estufa e outra na carteira dele.
	var da_carteira := RegistroCivil.identidade(int(j["id"]))
	var ac: Dictionary = da_carteira["aparencia"]
	_relatar("elenco_na_identidade",
		1 if int(ac["rosto"]) == int(aj["rosto"])
		and int(ac["linha_rosto"]) == Aparencia.LINHA_ELENCO else 0)
	_relatar("elenco_apelido_na_ficha",
		1 if String(da_carteira.get("apelido", "")) == "JOTA" else 0)
## A mesma pessoa sem penteado nenhum, para servir de linha de base.
static func _sem_penteado(a: Dictionary) -> Dictionary:
	var saida := a.duplicate(true)
	saida["coque"] = false
	saida["cacheado"] = false
	return saida


static func _pe_mais_baixo(c: Convidado) -> float:
	var corpo := c.get_node_or_null("Corpo") as Corpo
	if corpo == null:
		return 0.0
	var esq := corpo.esqueleto()
	if esq == null or esq.get_bone_count() == 0:
		return 0.0
	esq.force_update_all_bone_transforms()
	var menor := 1e9
	var base := esq.global_transform
	for k in esq.get_bone_count():
		menor = minf(menor, (base * esq.get_bone_global_pose(k)).origin.y)
	return menor - c.global_position.y


# --- o ciclo ----------------------------------------------------------------

## Acha um vaso numa fase, para nao depender de qual indice caiu onde.
static func _achar(p: Plantacao, fase: Plantio.Fase) -> int:
	var v := p.vasos()
	for i in Plantio.quantos(v):
		if Plantio.fase_de(v, i) == fase:
			return i
	return -1


## A escada do Schedule I, degrau por degrau, pelo caminho do jogador: mochila,
## rotulo, tecla de interagir.
##
## Nao chama `Plantio.aplicar` direto. O que esta sendo testado e a amarracao —
## inventario, area de interacao, regra e malha —, e chamar a regra no meio
## testaria a regra sozinha, que e a unica parte que nao corre risco.
static func _testar_ciclo(arvore: SceneTree, p: Plantacao) -> void:
	var i := _achar(p, Plantio.Fase.VAZIO)
	if i < 0:
		_relatar("sem_vaso_vazio", 1)
		return
	var area := p.get_node_or_null("Vaso%d" % i) as Interativo
	if area == null:
		_relatar("area_do_vaso_ausente", 1)
		return

	# Mochila vazia. O vaso tem de recusar, e tem de DIZER o que falta.
	Inventario.de_dicionario({"espacos": [], "vida": 100})
	await arvore.process_frame
	p.call("_atualizar_rotulos")
	_relatar("rotulo_sem_terra",
		1 if area.rotulo_atual() == "Precisa de terra" else 0)
	area.interagir(null)
	_relatar("ciclo_sem_terra",
		1 if Plantio.fase_de(p.vasos(), i) == Plantio.Fase.VAZIO else 0)

	# Agora com terra na mochila, pela estacao de insumos — que e de onde o
	# jogador tira, e nao de um `adicionar` escrito aqui.
	var saco := p.get_node_or_null("Terra") as Interativo
	if saco != null:
		saco.interagir(null)
	_relatar("saco_deu_terra", Inventario.quantidade(&"terra"))
	p.call("_atualizar_rotulos")
	_relatar("rotulo_com_terra",
		1 if area.rotulo_atual() == "Por terra no vaso" else 0)

	var antes := Inventario.quantidade(&"terra")
	area.interagir(null)
	_relatar("ciclo_vazio_terra",
		1 if Plantio.fase_de(p.vasos(), i) == Plantio.Fase.TERRA else 0)
	_relatar("gastou_terra", 1 if Inventario.quantidade(&"terra") == antes - 1
		else 0)

	# Semente.
	var caixa := p.get_node_or_null("Sementes") as Interativo
	if caixa != null:
		caixa.interagir(null)
	area.interagir(null)
	_relatar("ciclo_terra_semente",
		1 if Plantio.fase_de(p.vasos(), i) == Plantio.Fase.SEMEADO else 0)

	# Agua. O regador vem do tanque, cheio, e gasta uma carga por rega.
	var tanque := p.get_node_or_null("Tanque") as Interativo
	if tanque != null:
		tanque.interagir(null)
	_relatar("pegou_regador", 1 if Inventario.tem(&"regador") else 0)
	var carga := p.agua_do_regador()
	area.interagir(null)
	_relatar("ciclo_semente_agua",
		1 if Plantio.fase_de(p.vasos(), i) == Plantio.Fase.CRESCENDO else 0)
	_relatar("regador_gastou",
		1 if p.agua_do_regador() == carga - 1 else 0)


## O tempo faz a planta crescer — e SO com agua.
##
## Em duas partes, e a divisao importa.
##
## A primeira mede o NO, na sala de verdade: adianta o relogio e confere que a
## planta andou. E o unico jeito de provar que `Plantacao._process` esta ligado
## ao relogio do mundo.
##
## A segunda mede a REGRA, num vaso solto que nao esta em sala nenhuma. Tem de
## ser assim: Jota e Helmer estao trabalhando o tempo todo do outro lado, e
## regam o que ficou com sede. Medir "a agua acaba" dentro de uma sala com dois
## fazendeiros e medir os fazendeiros — foi o que a primeira versao fez, e ela
## falhava com razao.
static func _testar_crescimento(arvore: SceneTree, p: Plantacao) -> void:
	var i := _achar(p, Plantio.Fase.CRESCENDO)
	if i < 0:
		_relatar("sem_vaso_crescendo", 1)
		return
	var antes := Plantio.crescimento_de(p.vasos(), i)
	_adiantar(4)
	await arvore.create_timer(1.0).timeout
	var meio := Plantio.crescimento_de(p.vasos(), i)
	_relatar("cresceu_com_agua", 1 if meio > antes + 0.05 else 0)
	_relatar("cresceu_quanto_mil", roundi((meio - antes) * 1000.0))

	# Um vaso so, fora da sala: recem-regado e depois esquecido.
	var solto: Array = [Plantio.Fase.CRESCENDO, Plantio.MIL, 0, 0]
	Plantio._correr_o_tempo(solto, Plantio.MINUTOS_DE_AGUA + 12.0)
	var seco := Plantio.crescimento_de(solto, 0)
	_relatar("agua_acabou", 1 if Plantio.agua_de(solto, 0) <= 0.001 else 0)
	# A rega paga oito minutos de crescimento dos doze do ciclo. Nao paga o
	# ciclo inteiro DE PROPOSITO: e essa folga que da trabalho ao fazendeiro.
	_relatar("uma_rega_nao_fecha_o_ciclo",
		1 if seco < 1.0 else 0)
	Plantio._correr_o_tempo(solto, 40.0)
	_relatar("nao_cresceu_seco",
		1 if absf(Plantio.crescimento_de(solto, 0) - seco) < 0.001 else 0)


## Colher rende, e a terra envelhece.
static func _testar_colheita(arvore: SceneTree, p: Plantacao) -> void:
	var i := _achar(p, Plantio.Fase.PRONTA)
	if i < 0:
		_relatar("sem_vaso_pronto", 1)
		return
	var area := p.get_node_or_null("Vaso%d" % i) as Interativo
	var antes := p.colhido()
	if area != null:
		area.interagir(null)
	_relatar("colheita", p.colhido() - antes)
	_relatar("colheu_volta_pra_terra",
		1 if Plantio.fase_de(p.vasos(), i) == Plantio.Fase.TERRA else 0)

	# Mais duas colheitas no mesmo vaso: a terra aguenta tres e depois acaba.
	#
	# O tempo aqui corre pela REGRA e nao pelo no. A primeira versao adiantava o
	# relogio e esperava um quadro, mas a `Plantacao` so reavalia de meio em meio
	# segundo: nada crescia, o vaso ficava em CRESCENDO e as duas colheitas
	# seguintes nao aconteciam. O criterio dizia "a terra nao envelhece", que era
	# verdade sobre o teste e mentira sobre o jogo.
	for _k in 2:
		var v := p.vasos()
		Plantio.aplicar(v, i, &"semente")
		# DUAS regas, e nao uma. Uma paga oito minutos dos doze do ciclo — a
		# planta chega a dois tercos e para. A primeira versao regava uma vez,
		# o vaso nunca ficava pronto, as colheitas seguintes nao aconteciam e o
		# criterio acusava a terra de nao envelhecer. A terra estava certa; o
		# teste e que nao sabia regar.
		for _rega in 2:
			Plantio.aplicar(v, i, &"agua")
			Plantio._correr_o_tempo(v, Plantio.MINUTOS_DE_AGUA)
		Plantio.aplicar(v, i, &"colher")
	_relatar("terra_envelhece",
		1 if Plantio.fase_de(p.vasos(), i) == Plantio.Fase.VAZIO else 0)

	# A prateleira mostra o que foi colhido.
	var prat := Plantio.prateleira(p.colhido())
	_relatar("potes_cheios", int(prat["cheios"]))

	# E o jogador pega de la para a mochila, e o placar diminui.
	var potes := p.get_node_or_null("Potes") as Interativo
	var no_placar := p.colhido()
	_relatar("placar_antes", no_placar)
	var na_mochila := Inventario.quantidade(&"maconha")
	if potes != null:
		potes.interagir(null)
	_relatar("pegou_da_prateleira",
		1 if Inventario.quantidade(&"maconha") > na_mochila else 0)
	_relatar("maconha_antes", na_mochila)
	_relatar("maconha_depois", Inventario.quantidade(&"maconha"))
	_relatar("placar_depois", p.colhido())
	_relatar("placar_diminuiu", 1 if p.colhido() < no_placar else 0)


# --- persistencia -----------------------------------------------------------

## Sair pela porta e voltar tem de devolver a mesma estufa.
##
## E o defeito mais silencioso de todos: tudo funciona, o jogador planta quatro
## vasos, sai para a sala, volta — e a estufa esta como estava na primeira vez.
## Nada na tela acusa, e o trabalho inteiro do jogador foi jogado fora.
##
## O que se compara nao e o censo
## -------------------------------
## A primeira versao comparava quantos vasos havia em cada fase antes e depois,
## e falhava sempre — com razao. Jota e Helmer continuam trabalhando durante os
## sete segundos da ida e da volta, entao o censo MUDA, e mudar e o certo.
## Comparar censo ali media os dois fazendeiros, e nao a memoria.
##
## O que se compara sao duas marcas que so a memoria explica:
##
##   colhido    posto em 777 antes de sair. Trabalho de fazendeiro so AUMENTA
##              esse numero; nada no jogo o zera. Voltar com menos de 777 quer
##              dizer que a estufa foi remontada do zero.
##   vaso 23    o ultimo da ultima linha, posto para CRESCENDO. Numa estufa
##              recem-semeada ele nasce VAZIO (ver Plantio._esticar), e nenhum
##              trabalho de fazendeiro leva um vaso de CRESCENDO de volta para
##              vazio no meio do caminho.
static func _testar_persistencia(arvore: SceneTree, jogador: Node3D) -> void:
	var p := _plantacao(arvore)
	var v := p.vasos()
	var ultimo := Plantio.quantos(v) - 1
	v[ultimo * Plantio.CAMPOS + Plantio.FASE] = Plantio.Fase.CRESCENDO
	v[ultimo * Plantio.CAMPOS + Plantio.CRESCIMENTO] = 500
	v[ultimo * Plantio.CAMPOS + Plantio.AGUA] = 900
	p.set("_estado", {
		"vasos": v, "colhido": 777, "regador": p.agua_do_regador(),
		"minuto": float(WorldState.relogio.minutos()),
	})
	Plantio.gravar(SEMENTE_ESTUFA, p.get("_estado"))

	Interiores.sair()
	await arvore.create_timer(ESPERA_LONGA).timeout
	Interiores.atravessar(SEMENTE_ESTUFA, &"estufa",
		Vector3(3.8, 0.0, 1.35), Vector3(3.8, 1.45, 8.4))
	await arvore.create_timer(ESPERA_LONGA).timeout

	var q := _plantacao(arvore)
	if q == null:
		_relatar("voltou_sem_plantacao", 1)
		return
	var fase_depois := Plantio.fase_de(q.vasos(), ultimo)
	_relatar("vaso_marcado_depois", int(fase_depois))
	_relatar("sobreviveu_a_saida",
		1 if fase_depois >= Plantio.Fase.CRESCENDO else 0)
	_relatar("colhido_depois", q.colhido())
	_relatar("colhido_sobreviveu", 1 if q.colhido() >= 777 else 0)
	if jogador != null:
		_relatar("jogador_na_estufa",
			1 if jogador.global_position.y > 1000.0 else 0)

	# E os dois continuam sendo os dois. A amarracao com o personagem mora no
	# WorldState; se ela nao sobrevivesse a remontagem do comodo, sair e voltar
	# devolveria dois desconhecidos de nome Jota e Helmer.
	var elenco := 0
	for no: Node in arvore.get_nodes_in_group(&"convidado"):
		var c := no as Convidado
		if c == null:
			continue
		var nome := FalasNpc.rotulo(c.ficha)
		if nome != "JOTA" and nome != "HELMER":
			continue
		var ap: Dictionary = c.ficha["aparencia"]
		if int(ap.get("linha_rosto", 0)) == Aparencia.LINHA_ELENCO:
			elenco += 1
	_relatar("elenco_depois_da_porta", elenco)


# --- o trabalho de quem fica ------------------------------------------------

## Meia hora de relogio longe da estufa, com e sem gente contratada.
##
## Este e o par que da sentido a contratar alguem. Sem ninguem na folha, o tempo
## so seca a terra: nada e colhido e nada e plantado. Com gente, o trabalho
## acontece — em passo de gente, `MINUTOS_POR_TAREFA` por tarefa.
##
## Roda na REGRA e nao na sala porque e a regra que corre quando o jogador nao
## esta: o comodo nem existe na arvore nessa hora.
static func _testar_ausencia() -> void:
	var vasos: Array = []
	for _k in 6:
		vasos.append_array([Plantio.Fase.PRONTA, 500, 1000, 0])

	var parado := vasos.duplicate()
	_relatar("sem_fazendeiro_colheu", Plantio._trabalhar(parado, 0))
	var sozinho := vasos.duplicate()
	var tarefas := int(30.0 / Plantio.MINUTOS_POR_TAREFA)
	var colheu := Plantio._trabalhar(sozinho, tarefas)
	_relatar("com_fazendeiro_colheu", 1 if colheu > 0 else 0)
	_relatar("colheu_quanto", colheu)
	# E o trabalho e LIMITADO pelo tempo: um fazendeiro em dois minutos nao
	# colhe a estufa inteira. Sem este teto, contratar alguem viraria um botao
	# de pular para o fim.
	var pouco := vasos.duplicate()
	var em_dois := Plantio._trabalhar(pouco,
		int(2.0 / Plantio.MINUTOS_POR_TAREFA))
	_relatar("trabalho_limitado", 1 if em_dois < colheu else 0)


## Jota e Helmer mexem em alguma coisa, com o jogador olhando.
##
## Mede o CENSO antes e depois: se nenhuma fase mudou em vinte e cinco segundos
## com dois fazendeiros e uma sala cheia de vaso pedindo coisa, a rotina deles
## nao esta rodando — e nada na tela diria isso, porque um NPC parado num
## galpao parece um NPC normal.
static func _testar_fazendeiros(arvore: SceneTree) -> void:
	var p := _plantacao(arvore)
	if p == null:
		return
	# Deixa servico para eles: dois vasos prontos e dois com sede.
	var v := p.vasos()
	for i in mini(4, Plantio.quantos(v)):
		Plantio.aplicar(v, i, Plantio.acao(v, i))
	var antes := Plantio.censo(v).duplicate()
	var colhido_antes := p.colhido()

	var trabalhando := 0
	var fim := float(Time.get_ticks_msec()) / 1000.0 + ESPERA_TRABALHO
	while float(Time.get_ticks_msec()) / 1000.0 < fim:
		await arvore.create_timer(0.25).timeout
		for no: Node in arvore.get_nodes_in_group(&"convidado"):
			var c := no as Convidado
			if c != null and c.get("rotina") == &"fazendeiro" \
					and c.get("_estado") == Convidado.Estado.TRABALHANDO:
				trabalhando += 1
	_relatar("viu_alguem_trabalhando", 1 if trabalhando > 0 else 0)

	var depois := Plantio.censo(p.vasos())
	var mudou := 0
	for chave: StringName in antes:
		if int(antes[chave]) != int(depois[chave]):
			mudou = 1
	if p.colhido() != colhido_antes:
		mudou = 1
	_relatar("fazendeiro_mexeu", mudou)


# --- contratar --------------------------------------------------------------

## A aba de servicos, de ponta a ponta, numa pessoa qualquer da cidade.
static func _testar_contratacao(arvore: SceneTree, jogador: Node3D) -> void:
	var id := RegistroCivil.id_de_faixa(4242, 24, 50)
	var ficha := RegistroCivil.identidade(id)
	_relatar("servicos_na_rua",
		1 if _tem_opcao(FalasNpc.opcoes(ficha, &"rua"), &"servicos") else 0)
	_relatar("servicos_no_volante",
		1 if _tem_opcao(FalasNpc.opcoes(ficha, &"volante"), &"servicos") else 0)

	var na_folha := Profissoes.quantos(&"fazendeiro")
	_relatar("contratou", 1 if Profissoes.contratar(id, &"fazendeiro") else 0)
	_relatar("folha_cresceu",
		1 if Profissoes.quantos(&"fazendeiro") == na_folha + 1 else 0)
	_relatar("profissao_gravada",
		1 if Profissoes.e(id, &"fazendeiro") else 0)
	# Contratar duas vezes a mesma pessoa nao pode empilhar duas vagas.
	Profissoes.contratar(id, &"fazendeiro")
	_relatar("nao_duplica",
		1 if Profissoes.quantos(&"fazendeiro") == na_folha + 1 else 0)

	# A aba mostra DISPENSAR para quem ja esta contratado, e nao o contrato de
	# novo: e a mesma folha servindo as duas pontas da decisao.
	var abas := Profissoes.opcoes(id)
	_relatar("aba_mostra_dispensar",
		1 if _tem_opcao(abas, &"demitir_fazendeiro") else 0)
	Profissoes.responder(ficha, &"demitir_fazendeiro")
	_relatar("demitiu", 1 if Profissoes.de(id) == &"" else 0)
	_relatar("folha_voltou",
		1 if Profissoes.quantos(&"fazendeiro") == na_folha else 0)

	# A fala do fazendeiro le o estado REAL da sala.
	await _testar_fala_do_fazendeiro(arvore, jogador)


static func _tem_opcao(lista: Array[Dictionary], chave: StringName) -> bool:
	for o: Dictionary in lista:
		if StringName(o["chave"]) == chave:
			return true
	return false


## Helmer diz um numero, e o numero confere.
##
## E a unica fala do jogo que le o mundo antes de falar, e por isso e a unica
## que pode estar errada de um jeito que so aparece andando ate la. O teste faz
## o que o jogador faria: conta os vasos prontos e ve se a frase bate.
static func _testar_fala_do_fazendeiro(arvore: SceneTree,
		_jogador: Node3D) -> void:
	var p := _plantacao(arvore)
	if p == null:
		return
	# Deixa um numero conhecido de vasos prontos.
	var v := p.vasos()
	for i in Plantio.quantos(v):
		if Plantio.fase_de(v, i) == Plantio.Fase.PRONTA:
			Plantio.aplicar(v, i, &"colher")
	for i in 3:
		if i < Plantio.quantos(v):
			v[i * Plantio.CAMPOS + Plantio.FASE] = Plantio.Fase.PRONTA
			v[i * Plantio.CAMPOS + Plantio.CRESCIMENTO] = Plantio.MIL

	var quem: Convidado = null
	for no: Node in arvore.get_nodes_in_group(&"convidado"):
		var c := no as Convidado
		if c != null and Profissoes.e(int(c.ficha["id"]), &"fazendeiro"):
			quem = c
			break
	if quem == null:
		_relatar("fazendeiro_ausente", 1)
		return

	var f := quem.ficha.duplicate()
	f["estufa"] = Plantio.censo(p.vasos())
	_relatar("plantio_na_estufa",
		1 if _tem_opcao(FalasNpc.opcoes(f, &"estufa"), &"plantio") else 0)
	_relatar("plantio_na_rua",
		1 if _tem_opcao(FalasNpc.opcoes(f, &"rua"), &"plantio") else 0)
	var linhas := FalasNpc.responder(f, &"plantio")
	var texto := " ".join(linhas)
	_relatar("fala_diz_o_numero", 1 if texto.contains("3") else 0)

	# E quem NAO e da estufa nao sabe de nada.
	var estranho := RegistroCivil.identidade(
		RegistroCivil.id_de_faixa(9182, 24, 50))
	estranho["estufa"] = Plantio.censo(p.vasos())
	var fora := " ".join(FalasNpc.responder(estranho, &"plantio"))
	_relatar("de_fora_nao_sabe", 1 if not fora.contains("3") else 0)
	_testar_entrega_da_super(arvore)


## A Super: com doses no bolso, Jota e Helmer oferecem levar, a lista continua
## cabendo na folha (no terreo e no andar 10) e o acerto tira as doses do bolso
## e poe na conta da dupla.
static func _testar_entrega_da_super(arvore: SceneTree) -> void:
	var jota: Convidado = null
	for no: Node in arvore.get_nodes_in_group(&"convidado"):
		var c := no as Convidado
		if c != null and RegistroCivil.personagem_de(int(c.ficha["id"])) == &"jota":
			jota = c
	if jota == null:
		_relatar("super_sem_jota", 1)
		return
	var f := jota.ficha
	_relatar("super_sem_dose_nao_oferece",
		0 if _tem_opcao(FalasNpc.opcoes(f, &"estufa"), &"entregar") else 1)
	Inventario.adicionar(EntregasDaSuper.ITEM, 3)
	var no_terreo := FalasNpc.opcoes(f, &"estufa")
	_relatar("super_oferece_entrega", 1 if _tem_opcao(no_terreo, &"entregar") else 0)
	FalasNpc.andar_dez = true
	var no_dez := FalasNpc.opcoes(f, &"estufa")
	FalasNpc.andar_dez = false
	_relatar("super_assunto_no_dez", 1 if _tem_opcao(no_dez, &"super") else 0)
	_relatar("super_lista_cabe", 1 if maxi(no_terreo.size(), no_dez.size())
		<= Conversa.MAX_OPCOES else 0)
	var antes := EntregasDaSuper.pendentes()
	FalasNpc.responder(f, &"entregar")
	_relatar("super_doses_saem_do_bolso",
		1 if Inventario.quantidade(EntregasDaSuper.ITEM) == 0 else 0)
	_relatar("super_dupla_recebe", EntregasDaSuper.pendentes() - antes)


# --- a folha de assuntos ----------------------------------------------------

## Nenhuma conversa do jogo pode ter mais opcoes do que a folha desenha.
##
## Este criterio existe por um defeito que estava no jogo e que nenhuma captura
## pegaria: dentro da casa da fumaca a lista tinha SETE opcoes e a folha
## desenhava SEIS. A setima era VER IDENTIDADE — a opcao que o jogo inteiro
## ensina o jogador a procurar —, e ela simplesmente nao aparecia. O teste da
## casa passava porque `Conversa.escolher` acha por chave, sem olhar a tela.
static func _testar_lista_de_opcoes() -> void:
	var ficha := RegistroCivil.identidade(
		RegistroCivil.id_de_faixa(5150, 24, 50))
	var maior := 0
	for contexto: StringName in [&"rua", &"casa", &"estufa", &"volante"]:
		var n := FalasNpc.opcoes(ficha, contexto).size()
		maior = maxi(maior, n)
		_relatar("opcoes_%s" % contexto, n)
	_relatar("maior_lista", maior)
	_relatar("lista_cabe", 1 if maior <= Conversa.MAX_OPCOES else 0)


# --- relogio ----------------------------------------------------------------

## Adianta o relogio do mundo em `minutos`. E o mesmo relogio do jogo, e por
## isso o que a plantacao faz aqui e o que ela faria numa partida de verdade.
static func _adiantar(minutos: int) -> void:
	WorldState.relogio.definir_minutos(
		(WorldState.relogio.minutos() + minutos) % (24 * 60))
