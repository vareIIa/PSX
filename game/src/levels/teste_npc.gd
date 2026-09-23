## Rotina de verificacao da gente da cidade.
##
## O teste que mais importa aqui e o de ida e volta do CPF. O sistema inteiro —
## carteira na mao do NPC, consulta no celular, agenda, vinculos — se apoia numa
## afirmacao unica: o CPF e uma funcao invertivel do id da pessoa. Se a inversa
## errar um caso em mil, uma consulta em mil devolve a ficha de OUTRA pessoa, com
## nome e foto trocados, e isso e o tipo de defeito que ninguem reproduz de
## proposito e todo mundo encontra jogando.
##
## Por isso a ida e volta roda em milhares de ids, e nao em tres.
##
## O resto verifica o que so existe rodando: a malha de gente nasce do streaming,
## o corpo e uma malha com pele que so o servidor de renderizacao monta, a
## conversa e um Control que digita texto, e o celular le o mesmo registro que a
## carteira. Nada disso da para afirmar de fora do jogo.
##
## Imprime linhas `[npc] chave=valor` que tools/verificar_npc.py confere.
class_name TesteNpc
extends RefCounted

## Quantos assuntos uma conversa de calcada oferece hoje. Ver o uso abaixo.
const OPCOES_NA_RUA := 7

## Amostra da ida e volta do CPF. Mil e o suficiente para pegar erro de um em
## cem; abaixo disso o teste passa a ser decorativo.
const AMOSTRA := 1200

## Quanto tempo esperar a rua se povoar antes de medir.
const ESPERA_MULTIDAO := 7.0


static func executar(cena: Node, jogador: Node3D) -> void:
	var arvore := cena.get_tree()
	await arvore.create_timer(1.0).timeout

	_relatar("inicio", 1)
	_medir_numeros()
	_medir_familia()
	_medir_aparencia()
	await _medir_corpo(cena)
	_medir_falas()
	_medir_rotas()
	_medir_audio()

	await _medir_multidao(cena, jogador)
	_medir_calcada(cena, jogador)
	await _medir_conversa(cena)
	await _medir_celular(cena)
	await _medir_gps(cena, jogador)
	_medir_criacao()

	_relatar("fim", 1)
	AudioDirector.silenciar_tudo()
	await arvore.process_frame
	arvore.quit(0)


static func _relatar(chave: String, valor: Variant) -> void:
	print("[npc] %s=%s" % [chave, valor])


# --- numeros ----------------------------------------------------------------

static func _medir_numeros() -> void:
	var erros_cpf := 0
	var erros_rg := 0
	var formatos := 0
	for k in AMOSTRA:
		var id := posmod(k * 7919 + k * k * 31, RegistroCivil.POPULACAO)
		var cpf := RegistroCivil.cpf_formatado(id)
		if RegistroCivil.id_de_cpf(cpf) != id:
			erros_cpf += 1
		if RegistroCivil.id_de_rg(RegistroCivil.rg_de(id)) != id:
			erros_rg += 1
		if RegistroCivil.cpf_de(id).length() == 11:
			formatos += 1
	_relatar("cpf_amostra", AMOSTRA)
	_relatar("cpf_ida_volta_erros", erros_cpf)
	_relatar("rg_ida_volta_erros", erros_rg)
	_relatar("cpf_formato_ok", formatos)

	# Numero inventado tem de ser recusado quase sempre. Se a taxa de aceitacao
	# subir, o verificador de digito parou de valer e a consulta virou sorteio.
	var aceitos := 0
	var testados := 4000
	for k in testados:
		var bruto := ""
		for d in 11:
			bruto += str(posmod(k * 37 + d * 911 + d * d * 13, 10))
		if RegistroCivil.id_de_cpf(bruto) >= 0:
			aceitos += 1
	_relatar("cpf_ao_acaso_testados", testados)
	_relatar("cpf_ao_acaso_aceitos", aceitos)

	# Duas fichas do mesmo id, com o cache limpo no meio, tem de sair iguais.
	var alvo := 4242424
	var a := RegistroCivil.identidade(alvo).duplicate(true)
	# Cache, e nao o registro inteiro: limpar tudo apagaria a ficha do jogador e
	# as medidas do celula la embaixo mediriam um portador inexistente. Ja
	# aconteceu, e o sintoma foi "consulta_propria=0" sem nenhum erro.
	RegistroCivil.esquecer_cache()
	var b := RegistroCivil.identidade(alvo)
	var iguais := 1
	for chave: String in ["nome", "cpf", "rg", "mae", "pai", "nascimento",
			"endereco", "profissao"]:
		if String(a[chave]) != String(b[chave]):
			iguais = 0
	_relatar("ficha_determinista", iguais)


# --- familia ----------------------------------------------------------------

static func _medir_familia() -> void:
	var casas := 0
	var filiacao_ok := 0
	var vinculos_certos := 0
	var falecidos := 0
	var idades_impossiveis := 0

	for k in 400:
		var lar_id := 1000 + k * 13
		var l := RegistroCivil.lar(lar_id)
		var papeis: Array = l["papeis"]
		casas += 1
		if RegistroCivil.vinculos(lar_id << 3).size() == 7:
			vinculos_certos += 1

		var chefe := RegistroCivil.identidade(lar_id << 3)
		for slot in 8:
			var f := RegistroCivil.identidade((lar_id << 3) | slot)
			if int(f["situacao"]) == RegistroCivil.Situacao.FALECIDO:
				falecidos += 1
			if int(f["idade"]) < 0 or int(f["idade"]) > 100:
				idades_impossiveis += 1
			if int(papeis[slot]) != RegistroCivil.Papel.FILHO:
				continue
			# O filho tem de ser mais novo que o chefe da casa, e a filiacao dele
			# tem de citar gente que mora ali — nao um nome solto.
			if int(f["idade"]) >= int(chefe["idade"]):
				idades_impossiveis += 1
			var pais := "%s|%s" % [f["mae"], f["pai"]]
			if pais.contains(String(chefe["nome"])):
				filiacao_ok += 1

	_relatar("casas", casas)
	_relatar("vinculos_completos", vinculos_certos)
	_relatar("filiacao_ligada", filiacao_ok)
	_relatar("falecidos_no_registro", falecidos)
	_relatar("idades_impossiveis", idades_impossiveis)

	# O endereco tem de cair num lugar que existe: coordenada de chunk com nome
	# de distrito. Endereco decorativo tira o sentido de consultar o endereco.
	var enderecos: Dictionary[String, bool] = {}
	for k in 200:
		var f := RegistroCivil.identidade(k * 977)
		enderecos[String(f["endereco"])] = true
	_relatar("enderecos_distintos", enderecos.size())


# --- aparencia --------------------------------------------------------------

static func _medir_aparencia() -> void:
	var silhuetas: Dictionary[String, bool] = {}
	var peles: Dictionary[String, bool] = {}
	var vozes: Dictionary[int, bool] = {}
	var com_casaco := 0
	var com_saia := 0
	var calvos := 0
	for k in 300:
		var f := RegistroCivil.identidade(k * 6113 + 17)
		var a: Dictionary = f["aparencia"]
		silhuetas["%d-%d-%d-%d" % [int(a["rosto"]), int(a["cabelo"]),
			int(a["camisa"]), int(a["calca"])]] = true
		peles[String(Color(a["pele"]).to_html(false))] = true
		vozes[int(float(a["voz"]) * 20.0)] = true
		if bool(a["casaco"]):
			com_casaco += 1
		if bool(a["saia"]):
			com_saia += 1
		if bool(a["calvo"]):
			calvos += 1
	_relatar("silhuetas_distintas", silhuetas.size())
	_relatar("tons_de_pele", peles.size())
	_relatar("alturas_de_voz", vozes.size())
	_relatar("com_casaco", com_casaco)
	_relatar("com_saia", com_saia)
	_relatar("calvos", calvos)

	var atlas := load("res://assets/textures/npc_atlas.png") as Texture2D
	_relatar("atlas_existe", 1 if atlas != null else 0)
	_relatar("atlas_lado", atlas.get_width() if atlas != null else 0)


# --- corpo ------------------------------------------------------------------

static func _medir_corpo(cena: Node) -> void:
	var f := RegistroCivil.identidade(31337)
	var corpo := Corpo.new()
	cena.add_child(corpo)
	corpo.montar(f["aparencia"])
	await cena.get_tree().process_frame

	_relatar("corpo_triangulos", corpo.triangulos())
	_relatar("corpo_ossos", corpo.ossos())
	# Uma malha por pessoa e o motivo de existir o esqueleto. Se isto virar dez,
	# dez pedestres na tela estouram o teto de draw call sozinhos.
	_relatar("corpo_malhas", _contar_malhas(corpo))

	# Quantizacao: um ciclo inteiro de caminhada tem de produzir exatamente o
	# numero de poses do contrato, nem uma a mais.
	var poses: Dictionary[int, bool] = {}
	for passo in 240:
		corpo.animar(1.4, 1.0 / 60.0)
		poses[corpo.assinatura()] = true
	_relatar("poses_por_ciclo", poses.size())

	# Parado tambem tem de mexer: respiracao. Um corpo com uma pose so parado le
	# como manequim.
	var poses_parado: Dictionary[int, bool] = {}
	for passo in 240:
		corpo.animar(0.0, 1.0 / 60.0)
		poses_parado[corpo.assinatura()] = true
	_relatar("poses_parado", poses_parado.size())

	corpo.queue_free()

	var retrato := Retrato.gerar(f["aparencia"])
	_relatar("retrato_largura", retrato.get_width() if retrato != null else 0)
	_relatar("retrato_altura", retrato.get_height() if retrato != null else 0)
	var cores: Dictionary[String, bool] = {}
	if retrato != null:
		for y in retrato.get_height():
			for x in retrato.get_width():
				cores[retrato.get_pixel(x, y).to_html(false)] = true
	_relatar("retrato_cores", cores.size())


## Um ponto de calcada em distrito de comercio, o mais perto possivel de onde o
## jogador esta. Devolve a propria posicao se nao houver nenhum por perto.
static func _esquina_movimentada(de: Vector3) -> Vector3:
	var melhor := de
	var melhor_d := INF
	for raio in [3, 6, 10]:
		for dz in range(-raio, raio + 1):
			for dx in range(-raio, raio + 1):
				var cx := floori(de.x / MalhaUrbana.TAM) + dx
				var cz := floori(de.z / MalhaUrbana.TAM) + dz
				if MalhaUrbana.distrito_de(cx, cz) != MalhaUrbana.Distrito.COMERCIAL:
					continue
				if not Rotas.existe_no(cx, cz):
					continue
				var p := Rotas.ponto(Vector4i(cx, cz, 1, 1))
				var d := p.distance_to(de)
				if d < melhor_d:
					melhor_d = d
					melhor = p
		if melhor_d < INF:
			break
	# A mesma folga acima do chao que o nascimento tinha: a esquina pode estar
	# metros acima ou abaixo dele no morro (Relevo; Rotas.ponto ja vem no chao).
	return Vector3(melhor.x, melhor.y + de.y - Relevo.altura(de.x, de.z), melhor.z)


## Diz o que esta no caminho: o no que colidiu e a caixa exata que pegou.
##
## Sem isto a investigacao vira adivinhacao — foram tres rodadas mexendo na
## posicao da linha de marcha antes de eu parar e imprimir o que estava la.
static func _descrever_bloqueio(batida: Dictionary) -> void:
	var col: Object = batida.get("collider")
	if col == null:
		return
	_relatar("bloqueio_no", (col as Node).name if col is Node else "?")
	var corpo := col as CollisionObject3D
	if corpo == null:
		return
	var dono := corpo.shape_find_owner(int(batida.get("shape", 0)))
	var forma := corpo.shape_owner_get_shape(dono, 0)
	var onde := corpo.global_transform * corpo.shape_owner_get_transform(dono)
	_relatar("bloqueio_forma", forma.get_class())
	if forma is BoxShape3D:
		var t: Vector3 = (forma as BoxShape3D).size
		_relatar("bloqueio_tamanho", "%.2fx%.2fx%.2f" % [t.x, t.y, t.z])
	_relatar("bloqueio_centro", "%.1f,%.2f,%.1f"
		% [onde.origin.x, onde.origin.y, onde.origin.z])


static func _contar_malhas(no: Node) -> int:
	var n := 1 if no is MeshInstance3D else 0
	for filho: Node in no.get_children():
		n += _contar_malhas(filho)
	return n


# --- falas ------------------------------------------------------------------

static func _medir_falas() -> void:
	_relatar("personalidades", Personalidade.QUANTAS)

	var marcadores_soltos := 0
	var linhas := 0
	var textos: Dictionary[String, bool] = {}
	var opcoes_erradas := 0
	var opcoes_fora_do_papel := 0
	var ultima_e_documento := 0

	for p in Personalidade.QUANTAS:
		# Duas fichas por temperamento, para provar que a MESMA personalidade
		# produz conversas diferentes quando a ficha muda.
		for variante in 2:
			var id := _id_com_personalidade(p, variante)
			if id < 0:
				continue
			var f := RegistroCivil.identidade(id)
			var lista := FalasNpc.opcoes(f)
			# Sete na calcada: nevoa, bairro, quem e voce, o assunto proprio da
			# personalidade, contratar servicos, encerrar e ver identidade.
			#
			# Eram seis ate a profissao de fazendeiro existir. O numero esta
			# escrito aqui de proposito e nao deduzido da propria lista: se um
			# assunto sumir por acidente, uma conta deduzida concordaria com o
			# erro e este teste diria que esta tudo bem.
			# Quem tem profissao ganha TRABALHO (o perfil no Trampo): oito.
			var esperado := OPCOES_NA_RUA + (1 if FalasNpc.tem_trabalho(f) else 0)
			if lista.size() != esperado:
				opcoes_erradas += 1
			if lista.size() > Conversa.MAX_OPCOES:
				opcoes_fora_do_papel += 1
			if String(lista[lista.size() - 1]["titulo"]) == FalasNpc.TITULO_DOCUMENTO:
				ultima_e_documento += 1
			textos[FalasNpc.saudacao(f)] = true
			for opcao: Dictionary in lista:
				for linha: String in FalasNpc.responder(f,
						StringName(opcao["chave"])):
					linhas += 1
					textos[linha] = true
					# Marcador que sobrou e a falha classica de texto costurado:
					# aparece "{profissao}" na tela e a ilusao acaba na hora.
					if linha.contains("{") or linha.contains("}"):
						marcadores_soltos += 1

	_relatar("falas_linhas", linhas)
	_relatar("falas_distintas", textos.size())
	_relatar("falas_marcador_solto", marcadores_soltos)
	_relatar("opcoes_erradas", opcoes_erradas)
	# Opcao que nao cabe na folha nao existe para o jogador: ela simplesmente
	# nao e desenhada, e nada avisa. Ver Conversa.MAX_OPCOES.
	_relatar("opcoes_fora_do_papel", opcoes_fora_do_papel)
	_relatar("ultima_opcao_documento", ultima_e_documento)

	# O rotulo esconde o nome ate a pessoa dizer o nome. E o que separa povoar a
	# cidade de conhecer alguem.
	var novo := RegistroCivil.identidade(555111)
	var antes := FalasNpc.rotulo(novo)
	FalasNpc.marcar(555111, &"voce")
	var depois := FalasNpc.rotulo(novo)
	_relatar("rotulo_anonimo", 1 if antes != String(novo["nome"]) else 0)
	_relatar("rotulo_nomeado", 1 if depois == String(novo["nome"]) else 0)


static func _id_com_personalidade(alvo: int, variante: int) -> int:
	for k in 4000:
		var id := posmod((k + variante * 7919) * 2711 + 13,
			RegistroCivil.POPULACAO)
		var f := RegistroCivil.identidade(id)
		if not f.is_empty() and int(f["personalidade"]) == alvo:
			return id
	return -1


# --- rotas ------------------------------------------------------------------

static func _medir_rotas() -> void:
	var no := Rotas.no_mais_proximo(Vector3.ZERO)
	var travas := 0
	var fora_da_calcada := 0
	var visitados: Dictionary[Vector4i, bool] = {}
	var anterior := no

	for passo in 300:
		var vizinhos := Rotas.vizinhos(no)
		if vizinhos.size() != 4:
			travas += 1
			break
		# No entroncamento em T o braco que nao existe devolve o proprio no — e
		# o pedestre de verdade pula essa aresta (Pedestre._escolher_destino).
		# Isso nao e beco. Beco e o canto sem DUAS saidas distintas.
		var saidas: Array[Vector4i] = []
		for v: Vector4i in vizinhos:
			if v != no and not saidas.has(v):
				saidas.append(v)
		if saidas.size() < 2:
			travas += 1
		var escolhido := vizinhos[passo % 4]
		if escolhido == no and not saidas.is_empty():
			escolhido = saidas[passo % saidas.size()]
		visitados[no] = true

		# O ponto tem de cair na calcada: fora do retangulo da quadra e dentro da
		# faixa entre o meio-fio e a fachada. Um no dentro da quadra poria gente
		# andando atraves de predio.
		var ponto := Rotas.ponto(no)
		var q := MalhaUrbana.quadra_de(floori(ponto.x / MalhaUrbana.TAM),
			floori(ponto.z / MalhaUrbana.TAM))
		if MalhaUrbana.retangulo_da_quadra(q).has_point(Vector2(ponto.x, ponto.z)):
			fora_da_calcada += 1

		anterior = no
		no = escolhido

	_relatar("rotas_visitadas", visitados.size())
	_relatar("rotas_travadas", travas)
	_relatar("rotas_dentro_da_quadra", fora_da_calcada)

	var esquinas := Rotas.esquinas_perto(Vector3.ZERO, 20.0, 44.0)
	_relatar("esquinas_na_coroa", esquinas.size())
	_relatar("movimento_comercial", "%.2f" % Rotas.movimento(anterior))


# --- audio ------------------------------------------------------------------

static func _medir_audio() -> void:
	var vozes := 0
	for banco: String in ["m", "f"]:
		for i in range(1, 9):
			if AudioDirector.tem(StringName("voz_%s_%d" % [banco, i])):
				vozes += 1
	_relatar("amostras_de_voz", vozes)
	var celular := 0
	for nome: StringName in [&"celular_abre", &"celular_tecla", &"celular_ok",
			&"celular_erro", &"papel"]:
		if AudioDirector.tem(nome):
			celular += 1
	_relatar("sons_de_celular", celular)


# --- multidao ---------------------------------------------------------------

static func _medir_multidao(cena: Node, jogador: Node3D) -> void:
	var arvore := cena.get_tree()

	# Leva o jogador para um distrito de comercio antes de medir.
	#
	# A origem do mundo cai em zona industrial, onde o movimento e 0,22: o teto
	# de gente e dois e cada candidato a nascer e recusado em quatro de cada
	# cinco tentativas. Medir a multidao ali e medir o distrito errado — e em uma
	# execucao em tres nao nascia ninguem e o teste reprovava um sistema que
	# estava certo. No comercio o movimento e 1,0.
	var destino := _esquina_movimentada(jogador.global_position)
	jogador.global_position = destino
	if jogador.has_method("zerar_velocidade"):
		jogador.call("zerar_velocidade")
	# O streaming precisa montar o bairro novo antes de haver calcada onde nascer.
	await arvore.create_timer(4.0).timeout
	await arvore.create_timer(ESPERA_MULTIDAO).timeout

	var vivos := Multidao.lista()
	_relatar("pedestres_vivos", vivos.size())
	_relatar("pedestres_nascidos", Multidao.nascimentos)
	# Diagnostico do berco. Quando ninguem nasce, a causa e sempre uma destas
	# tres: nao ha calcada na coroa, o chunk dela nao esta montado, ou o distrito
	# nao tem movimento. Sem os tres numeros, a busca comeca no escuro.
	var trechos := Rotas.trechos_perto(jogador.global_position,
		Multidao.RAIO_NASCER_MIN, Multidao.RAIO_NASCER_MAX)
	_relatar("trechos_na_coroa", trechos.size())
	var montados := 0
	for t: Dictionary in trechos:
		if ChunkManager.esta_carregado(ChunkManager.coord_de(t["ponto"])):
			montados += 1
	_relatar("trechos_montados", montados)
	_relatar("multidao_ativa", 1 if Multidao.ativo else 0)
	_relatar("chunks_carregados", ChunkManager.chunks_carregados())
	_relatar("jogador_em", "%.0f,%.0f" % [jogador.global_position.x,
		jogador.global_position.z])
	if not trechos.is_empty():
		var t0: Vector3 = trechos[0]["ponto"]
		_relatar("primeiro_trecho", "%.0f,%.0f" % [t0.x, t0.z])
		_relatar("coord_do_trecho", "%d,%d" % [ChunkManager.coord_de(t0).x,
			ChunkManager.coord_de(t0).y])

	if vivos.is_empty():
		_relatar("pedestre_andou", 0)
		_relatar("pedestre_no_chao", 0)
		_relatar("pedestres_distintos", 0)
		return

	# Ninguem pode nascer com a mesma ficha de outro que ja esta na rua.
	var ids: Dictionary[int, bool] = {}
	for p: Pedestre in vivos:
		ids[int(p.ficha["id"])] = true
	_relatar("pedestres_distintos", ids.size())

	# Acorda quem estava parado. Ver Pedestre.acordar: sem isto a medida vira
	# sorteio, porque a pausa de descanso dura mais que a janela de medicao.
	var antes: Array[Vector3] = []
	for p: Pedestre in vivos:
		p.acordar()
		antes.append(p.global_position)
	await arvore.create_timer(3.0).timeout

	var andaram := 0
	var no_chao := 0
	var sem_chao := 0
	var pior_desnivel := 0.0
	var medidos := 0
	var soma_dist := 0.0
	var travados := 0
	for i in vivos.size():
		var p := vivos[i]
		if not is_instance_valid(p):
			continue
		medidos += 1
		var percorreu := p.global_position.distance_to(antes[i])
		soma_dist += percorreu
		if percorreu < 0.05:
			travados += 1
		if percorreu > 0.8:
			andaram += 1
		# A altura sai de um raio para baixo; se ela divergir do chao, a pessoa
		# esta flutuando ou enterrada, e isso nao aparece em captura de longe.
		#
		# O que se reporta e o PIOR desnivel em metros, e nao quantos passaram: um
		# contador so diz que algo esta errado, o desnivel diz o quanto — e um
		# pedestre subindo a guia de quinze centimetros, que e legitimo, deixa de
		# ser confundido com um flutuando a um metro.
		var espaco := p.get_world_3d().direct_space_state
		var consulta := PhysicsRayQueryParameters3D.create(
			p.global_position + Vector3.UP * 1.5,
			p.global_position + Vector3.DOWN * 2.0, 1)
		consulta.exclude = [p.get_rid()]
		var achado := espaco.intersect_ray(consulta)
		if achado.is_empty():
			sem_chao += 1
			if sem_chao == 1:
				_relatar("sem_chao_em", "%.0f,%.0f" % [p.global_position.x,
					p.global_position.z])
				_relatar("sem_chao_chunk_montado",
					1 if ChunkManager.esta_carregado(
						ChunkManager.coord_de(p.global_position)) else 0)
		else:
			no_chao += 1
			pior_desnivel = maxf(pior_desnivel,
				absf((achado["position"] as Vector3).y - p.global_position.y))
	# Por que quem nao andou nao andou. Sem isto, "metade da rua parada" pode ser
	# tanto comportamento correto quanto uma multidao travada, e nao ha como
	# distinguir os dois olhando o numero.
	var estados := {&"andando": 0, &"pausa": 0, &"social": 0, &"atendendo": 0}
	for p: Pedestre in vivos:
		if is_instance_valid(p):
			estados[p.estado_nome()] += 1
	for chave: StringName in estados:
		_relatar("estado_%s" % chave, estados[chave])

	_relatar("pedestre_dist_media", "%.2f" % (soma_dist / float(maxi(1, medidos))))
	_relatar("pedestre_travado", travados)
	# A pior fracao de vida que alguem passou andando sem sair do lugar, contada
	# SO entre quem ja passou da idade de aposentadoria.
	#
	# A multidao recolhe quem desistiu de andar depois de seis segundos. Medir
	# quem tem menos que isso e medir gente que o sistema ainda vai resolver, e
	# foi o que reprovou o teste quatro vezes seguidas com o mecanismo
	# funcionando. O contrato nao e "ninguem trava" — numa cidade gerada isso nao
	# da para prometer — e sim "quem trava nao fica".
	var pior_travamento := 0.0
	var maduros := 0
	for p: Pedestre in vivos:
		if is_instance_valid(p) and p.vivo_ha() > 7.0:
			maduros += 1
			pior_travamento = maxf(pior_travamento, p.fracao_travada())
	_relatar("pedestres_maduros", maduros)
	_relatar("pedestre_fracao_travada", "%.3f" % pior_travamento if maduros > 0
		else "-1")
	_relatar("pedestres_retirados", Multidao.retirados)
	_relatar("pedestres_medidos", medidos)
	_relatar("pedestre_andou", andaram)
	_relatar("pedestre_no_chao", no_chao)
	_relatar("pedestre_sem_chao", sem_chao)
	_relatar("pedestre_desnivel_pior", "%.3f" % pior_desnivel)

	# Conversa entre pedestres. Nao da para esperar acontecer sozinha dentro do
	# teste — depende de dois deles se cruzarem no mesmo trecho — entao o par e
	# formado a mao e o que se mede e a consequencia: os dois param, viram um
	# para o outro e deixam de estar livres.
	if vivos.size() >= 2 and is_instance_valid(vivos[0]) and is_instance_valid(vivos[1]):
		# Sem novas conversas durante a medida: a multidao junta um par a cada
		# quatro segundos e pode reunir exatamente estes dois de novo, o que faz
		# uma conversa que ACABOU parecer uma que nunca acaba.
		Multidao.convivio = false
		vivos[0].iniciar_conversa(vivos[1], 6.0)
		vivos[1].iniciar_conversa(vivos[0], 6.0)
		await arvore.create_timer(1.2).timeout
		var ocupados := 0
		for k in 2:
			if not vivos[k].esta_livre():
				ocupados += 1
		_relatar("conversa_entre_npcs", ocupados)
		# Viraram um para o outro? O angulo entre o rumo de cada um e a direcao
		# do outro tem de ser pequeno nos dois.
		var olhando := 0
		for k in 2:
			var d := vivos[1 - k].global_position - vivos[k].global_position
			d.y = 0.0
			if absf(angle_difference(vivos[k].rotation.y,
					atan2(-d.x, -d.z))) < 0.5:
				olhando += 1
		_relatar("npcs_se_encaram", olhando)
		await arvore.create_timer(5.5).timeout
		# O que se mede e se AQUELA conversa acabou, e nao se as duas pessoas
		# estao livres: numa rua movimentada a multidao junta pares a cada quatro
		# segundos, e um dos dois pode ja estar conversando com outra pessoa
		# quando a medida acontece. Exigir "livre" reprovava por isso.
		_relatar("conversa_de_rua_terminou",
			1 if vivos[0].parceiro() != vivos[1] and vivos[1].parceiro() != vivos[0]
			else 0)
		Multidao.convivio = true
	else:
		_relatar("conversa_entre_npcs", -1)
		_relatar("npcs_se_encaram", -1)
		_relatar("conversa_de_rua_terminou", -1)

	# Custo, medido em A e B. O numero absoluto de chamadas de desenho nao diz
	# nada sobre a multidao: a cidade ja gasta a maior parte do orcamento, e
	# atribuir o total a ela seria culpar o ultimo a chegar. O que importa e o
	# DELTA — quanto custa cada pessoa a mais na tela. Com pele, tem de ser uma
	# chamada por pessoa; se este numero subir, o esqueleto parou de valer.
	var com_gente := int(Performance.get_monitor(
		Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	for p: Pedestre in vivos:
		if is_instance_valid(p):
			p.visible = false
	await arvore.process_frame
	await arvore.process_frame
	var sem_gente := int(Performance.get_monitor(
		Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	for p: Pedestre in vivos:
		if is_instance_valid(p):
			p.visible = true
	_relatar("draw_calls", com_gente)
	_relatar("draw_calls_sem_multidao", sem_gente)
	_relatar("draw_calls_por_pessoa", "%.2f"
		% (float(com_gente - sem_gente) / float(maxi(1, vivos.size()))))
	_relatar("distancia_do_jogador", "%.1f" % vivos[0].global_position.distance_to(
		jogador.global_position))


## Quanto da linha de marcha esta desimpedido.
##
## E a medida que faltava. "Gente demais desistindo de andar" nao diz ONDE nem
## POR QUE; isto varre a calcada com a mesma capsula do pedestre e conta quantos
## metros dela tem alguma coisa solida em cima. Se a linha passar dentro do
## poste, da arvore ou do orelhao, o numero denuncia na hora — e sem ele a
## investigacao vira tentativa e erro sobre a posicao da linha.
static func _medir_calcada(cena: Node, jogador: Node3D) -> void:
	var espaco := jogador.get_world_3d().direct_space_state
	var forma := CapsuleShape3D.new()
	forma.radius = 0.26
	forma.height = 1.25
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma
	consulta.collision_mask = 1
	# Fora as pessoas. A pergunta e se o CENARIO deixa passar; contar pedestre
	# como obstaculo mede a lotacao da calcada, nao a geometria dela — e foi
	# exatamente essa confusao que me fez mexer tres vezes na posicao da linha de
	# marcha atras de um poste que nao existia.
	var fora: Array[RID] = []
	for p: Pedestre in Multidao.lista():
		if is_instance_valid(p):
			fora.append(p.get_rid())
	var jog := jogador as CollisionObject3D
	if jog != null:
		fora.append(jog.get_rid())
	consulta.exclude = fora

	# Varre a linha e tambem cinco faixas paralelas a ela, de um metro para cada
	# lado. Uma varredura so diz QUE esta bloqueado; cinco dizem ONDE esta o
	# caminho livre, que e a informacao de que se precisa para consertar.
	var deslocamentos: Array[float] = [-1.0, -0.5, 0.0, 0.5, 1.0]
	var amostras := 0
	var bloqueadas: Array[int] = [0, 0, 0, 0, 0]
	var primeiro := ""
	var no := Rotas.no_mais_proximo(jogador.global_position)
	for k in 2:
		var destino := Rotas.vizinhos(no)[k]
		if destino == no or not Rotas.aresta_caminhavel(no, k):
			continue
		var a := Rotas.ponto(no)
		var b := Rotas.ponto(destino)
		var reta := b - a
		if reta.length() < 1.0:
			continue
		# O lado positivo aponta para longe do eixo da via, ou seja para o predio.
		var lado := Vector3(-reta.z, 0.0, reta.x).normalized()
		var meio := (Rotas.ponto(no) + Rotas.ponto(destino)) * 0.5
		var eixo := Vector3(float(no.x) * Rotas.TAM, 0.0, float(no.y) * Rotas.TAM)
		if lado.dot(meio - eixo) < 0.0:
			lado = -lado
		var passos := mini(60, maxi(1, int(a.distance_to(b))))
		for i in range(1, passos):
			var ponto := a.lerp(b, float(i) / float(passos))
			if not ChunkManager.esta_carregado(ChunkManager.coord_de(ponto)):
				continue
			amostras += 1
			for d in deslocamentos.size():
				consulta.transform = Transform3D(Basis(),
					ponto + lado * deslocamentos[d] + Vector3(0.0, 0.95, 0.0))
				var batidas := espaco.intersect_shape(consulta, 1)
				if not batidas.is_empty():
					bloqueadas[d] += 1
					if d == 2 and primeiro == "":
						primeiro = "%.1f,%.1f" % [ponto.x, ponto.z]
						_descrever_bloqueio(batidas[0])
	_relatar("calcada_amostras", amostras)
	for d in deslocamentos.size():
		_relatar("calcada_bloqueada_%d" % d, bloqueadas[d])
	_relatar("calcada_bloqueada", bloqueadas[2])
	if primeiro != "":
		_relatar("calcada_primeiro_bloqueio", primeiro)


# --- conversa ---------------------------------------------------------------

static func _medir_conversa(cena: Node) -> void:
	var arvore := cena.get_tree()
	var vivos := Multidao.lista()
	if vivos.is_empty():
		_relatar("conversa_abriu", 0)
		_relatar("conversa_opcoes", 0)
		_relatar("documento_abriu", 0)
		return

	var alvo := vivos[0]
	var ficha: Dictionary = alvo.ficha
	alvo.abordar(cena)
	await arvore.create_timer(0.6).timeout
	_relatar("conversa_abriu", 1 if Conversa.ativo else 0)

	# Avanca ate a lista de assuntos aparecer.
	for k in 12:
		Conversa.avancar()
		await arvore.process_frame
	var opcoes := FalasNpc.opcoes(ficha)
	_relatar("conversa_opcoes", opcoes.size())

	Conversa.escolher(&"voce")
	await arvore.create_timer(0.4).timeout
	for k in 12:
		Conversa.avancar()
		await arvore.process_frame
	_relatar("conversa_nomeou", 1 if FalasNpc.ja_falou(int(ficha["id"]), &"voce") else 0)

	Conversa.escolher(&"documento")
	await arvore.create_timer(2.0).timeout
	_relatar("documento_abriu", 1 if Documento.ativo else 0)
	Documento.fechar()
	await arvore.create_timer(0.3).timeout

	Conversa.escolher(&"sair")
	for k in 8:
		Conversa.avancar()
		await arvore.process_frame
	_relatar("conversa_fechou", 0 if Conversa.ativo else 1)
	_relatar("agenda", RegistroCivil.conhecidos().size())


## A tela de criacao muda a pessoa, e a mudanca sobrevive ao save.
##
## O que se verifica nao e a interface e sim o caminho dela: ajuste -> aparencia
## -> corpo -> save -> carga -> mesma aparencia. Se qualquer elo perder o dado, o
## jogador termina a criacao, salva, carrega e vira outra pessoa — que e o tipo
## de defeito que so aparece depois de horas de jogo.
static func _medir_criacao() -> void:
	_relatar("ajustes_disponiveis", Aparencia.AJUSTES.size())

	var antes: Dictionary = RegistroCivil.jogador.get("aparencia", {})
	antes = antes.duplicate(true)
	var ajustes := RegistroCivil.ajustes_do_jogador()
	_relatar("ajustes_iniciais", ajustes.size())

	# Muda tudo o que da para mudar, para o topo de cada faixa.
	ajustes[&"rosto"] = (int(antes.get("rosto", 0)) + 3) % Aparencia.VARIANTES
	ajustes[&"pele"] = Aparencia.PELES[Aparencia.PELES.size() - 1]
	ajustes[&"cabelo_cor"] = Aparencia.CABELOS[0]
	ajustes[&"chapeu_tipo"] = 3
	ajustes[&"altura"] = 1.91
	ajustes[&"gordura"] = 0.95
	RegistroCivil.ajustar_jogador(ajustes)

	var depois: Dictionary = RegistroCivil.jogador["aparencia"]
	_relatar("ajuste_pegou_rosto",
		1 if int(depois["rosto"]) == int(ajustes[&"rosto"]) else 0)
	_relatar("ajuste_pegou_altura",
		1 if absf(float(depois["altura"]) - 1.91) < 0.001 else 0)
	_relatar("ajuste_pegou_chapeu", 1 if bool(depois["chapeu"]) else 0)

	# O corpo tem de nascer diferente: mais alto e mais largo, com chapeu.
	var magro := Corpo.new()
	magro.montar(Aparencia.com_ajustes(antes,
		{&"altura": 1.55, &"gordura": 0.0, &"chapeu_tipo": 0}))
	var gordo := Corpo.new()
	gordo.montar(depois)
	_relatar("corpo_altura_magro", "%.2f" % magro.altura())
	_relatar("corpo_altura_gordo", "%.2f" % gordo.altura())
	_relatar("corpo_tris_magro", magro.triangulos())
	_relatar("corpo_tris_gordo", gordo.triangulos())
	magro.free()
	gordo.free()

	# Ida e volta pelo save. As cores viram texto e voltam; um erro ai troca a
	# roupa do jogador silenciosamente na primeira carga.
	var salvo := RegistroCivil.para_dicionario()
	RegistroCivil.esquecer_cache()
	RegistroCivil.de_dicionario(salvo)
	var recarregado: Dictionary = RegistroCivil.jogador["aparencia"]
	var iguais := 1
	for chave: String in ["rosto", "altura", "gordura", "chapeu_tipo"]:
		if str(recarregado.get(chave)) != str(depois.get(chave)):
			iguais = 0
	if not Color(recarregado["pele"]).is_equal_approx(Color(depois["pele"])):
		iguais = 0
	_relatar("aparencia_sobrevive_ao_save", iguais)


# --- celular ----------------------------------------------------------------

static func _medir_celular(cena: Node) -> void:
	var arvore := cena.get_tree()
	Celular.abrir()
	await arvore.create_timer(0.4).timeout
	_relatar("celular_abriu", 1 if Celular.ativo else 0)

	var eu := RegistroCivil.jogador
	_relatar("jogador_tem_ficha", 0 if eu.is_empty() else 1)
	_relatar("jogador_tem_documento", 1 if Inventario.tem(&"identidade") else 0)

	# A consulta do proprio CPF tem de achar o proprio nome. E o laco completo:
	# a carteira no inventario mostra o numero, o portal aceita o numero.
	var achou := Celular.consultar_cpf(String(eu.get("cpf", "")))
	_relatar("consulta_propria", 1 if achou else 0)

	# E um numero inventado tem de nao achar nada.
	_relatar("consulta_invalida", 0 if Celular.consultar_cpf("11111111111") else 1)

	# Uma pessoa da rua consultada pelo CPF devolve a ficha dela, com vinculos.
	var vivos := Multidao.lista()
	if not vivos.is_empty():
		var outro: Dictionary = vivos[0].ficha
		_relatar("consulta_de_terceiro",
			1 if Celular.consultar_cpf(String(outro["cpf"])) else 0)
		_relatar("vinculos_de_terceiro",
			RegistroCivil.vinculos(int(outro["id"])).size())
	Celular.fechar()
	await arvore.process_frame
	_relatar("celular_fechou", 0 if Celular.ativo else 1)


# --- gps --------------------------------------------------------------------

## O aparelho deitado tem de achar a cidade a partir de uma varredura estatica,
## sem chunk carregado. Nenhum filtro pode abrir vazio: um GPS que lista zero
## lugares e uma tela que so ensina que nao vale a pena abrir.
static func _medir_gps(cena: Node, jogador: Node3D) -> void:
	var arvore := cena.get_tree()
	Gps.abrir()
	await arvore.create_timer(0.4).timeout
	_relatar("gps_abriu", 1 if Gps.ativo else 0)
	_relatar("gps_travou_jogador", 1 if jogador.get("travado") else 0)

	var vazios := 0
	for filtro: Dictionary in Gps.FILTROS:
		var quantos := Gps.filtrar_por(StringName(filtro["id"]))
		_relatar("gps_%s" % filtro["id"], quantos)
		if quantos <= 0:
			vazios += 1
	_relatar("gps_filtros_vazios", vazios)

	# A casa da fumaca e o motivo de o filtro existir. Se ela sumir da varredura,
	# o app perdeu a unica coisa que o jogador vai abrir o telefone para procurar.
	var casas := Gps.filtrar_por(&"casa_fumaca")
	_relatar("gps_casa_verde", casas)
	Gps.tracar_rota_no_primeiro()
	_relatar("gps_rota_tracada", 0 if Gps.destino.is_empty() else 1)
	_relatar("gps_rota_tem_rotulo",
		1 if Gps.rotulo_do_destino(jogador.global_position) != "" else 0)
	_relatar("gps_rota_no_minimapa", Gps.pinos_do_destino().size())

	Gps.fechar()
	await arvore.process_frame
	_relatar("gps_fechou", 0 if Gps.ativo else 1)
