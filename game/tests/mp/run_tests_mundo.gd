## Mundo compartilhado, nivel 2 (plano 04 secao 11): o que a Fase 3 decide sem
## socket e sem autoload.
##
##     godot --headless --path game --script res://tests/mp/run_tests_mundo.gd
##
## Cobre:
## - ChaveMundo: a chave por posicao de quem o gerador nao numerou (secao 3.3);
## - ValidadorDeMundo: cada motivo da tabela da secao 6, na ordem, e a cota;
## - EspelhoDeMundo: previsao, revisao e espera da carga (secoes 4.3, 4.4, 7);
## - CargaDeMundo: a carga de entrada em pedacos, e lixo que nao quebra (5.1).
## - PoliticaDeMundo: de quem e cada escrita (mundo, pessoa, local);
## - FusaoDeMundo: duas maos na mesma prateleira nao se apagam;
## - comodo por semente, casa que existe na rua, e a ordem da disputa de item.
##
## O que depende de dois processos (item disputado no mesmo tick, porta vista por
## um terceiro que entrou depois, tempo ate `_mundo_pronto`) e o nivel 4.
extends SceneTree

const M := ValidadorDeMundo.Motivo

var _falhas: PackedStringArray = []
var _total: int = 0


func _initialize() -> void:
	print("\n=== mundo compartilhado ===\n")
	_chave_mundo()
	_validador_valores()
	_validador_julgar()
	_validador_item()
	_balde()
	_politica()
	_fusao()
	_validador_familias()
	_disputa()
	_espelho_previsao()
	_espelho_carga()
	_espelho_recarga()
	_carga_ida_e_volta()
	_carga_montagem()
	_carga_lixo()

	print("")
	if _falhas.is_empty():
		print("OK \u2014 %d assercoes" % _total)
		quit(0)
		return
	print("FALHOU \u2014 %d de %d assercoes" % [_falhas.size(), _total])
	for f: String in _falhas:
		print("  x %s" % f)
	quit(1)


func _check(cond: bool, msg: String) -> void:
	_total += 1
	if not cond:
		_falhas.append(msg)


func _secao(nome: String) -> void:
	print("-- %s" % nome)


# --- ChaveMundo -----------------------------------------------------------------------

func _chave_mundo() -> void:
	_secao("chave por posicao")
	var porta := Vector3(2.0, 1.2, 16.0)
	_check(ChaveMundo.de_posicao(porta) == &"porta_20_12_160", "decimetros: %s" % ChaveMundo.de_posicao(porta))
	_check(ChaveMundo.de_posicao(porta) == ChaveMundo.de_posicao(Vector3(2.0, 1.2, 16.0)),
		"mesma posicao, mesma chave")
	_check(ChaveMundo.de_posicao(porta) != ChaveMundo.de_posicao(porta + Vector3(0.1, 0, 0)),
		"1 dm em x muda a chave")
	_check(ChaveMundo.de_posicao(porta) != ChaveMundo.de_posicao(porta + Vector3(0, 0, -0.1)),
		"1 dm em z muda a chave")
	_check(ChaveMundo.de_posicao(porta) == ChaveMundo.de_posicao(porta + Vector3(0.0004, -0.0004, 0.0004)),
		"0,4 mm de ruido nao muda")
	_check(String(ChaveMundo.de_posicao(porta, "gaveta")).begins_with("gaveta_"), "prefixo proprio")

	_check(ChaveMundo.coord_da_rua(Vector3(-0.1, 0, -31.9)) == Vector2i(-1, -1),
		"coord negativa arredonda para baixo")
	_check(ChaveMundo.coord_da_rua(Vector3(0, 0, 0)) == Vector2i(0, 0), "origem e do chunk 0")
	_check(ChaveMundo.coord_da_rua(Vector3(31.99, 5, 32.0)) == Vector2i(0, 1), "borda do chunk")
	_check(ChaveMundo.coord_da_rua(Vector3(-32.0, 0, -32.01)) == Vector2i(-1, -2), "borda negativa")

	# Ida e volta: posicao global -> (coord, chave) e a chave e a da posicao local.
	var coord := Vector2i(-3, 5)
	var global := ChaveMundo.origem_da_rua(coord) + porta
	var dr := ChaveMundo.da_rua(global)
	_check(dr[0] == coord and dr[1] == &"porta_20_12_160", "da_rua em chunk negativo: %s" % [dr])
	_check(dr[1] == ChaveMundo.de_posicao(global - ChaveMundo.origem_da_rua(dr[0])),
		"da_rua e de_posicao concordam")
	var borda := ChaveMundo.da_rua(Vector3(-0.1, 0, -31.9))
	_check(borda[0] == Vector2i(-1, -1) and borda[1] == &"porta_319_0_1",
		"local no chunk negativo e positivo: %s" % [borda])
	# O mesmo ponto visto de duas maquinas: somas em ordem diferente, mesma chave.
	var a := ChaveMundo.da_rua(Vector3(-40.0, 0.0, 70.0) + Vector3(0.33, 0.0, 0.07))
	var b := ChaveMundo.da_rua(Vector3(-39.67, 0.0, 70.07))
	_check(a == b, "mesmo ponto por dois caminhos de soma")

	_check(ChaveMundo.de_posicao(Vector3(NAN, 0, 0)) == &"", "NaN da chave vazia")
	_check(ChaveMundo.da_rua(Vector3(0, INF, 0)) == [Vector2i.ZERO, &""], "INF da coord zero e chave vazia")
	_check(ChaveMundo.coord_da_rua(Vector3(NAN, 0, NAN)) == Vector2i.ZERO, "coord de NaN nao quebra")
	# A chave que sai daqui e aceita pelo servidor, com sinal e tudo.
	var negativa := ChaveMundo.de_posicao(Vector3(-1.5, -12.94, 3.0))
	_check(negativa == &"porta_-15_-129_30", "componentes negativos: %s" % negativa)
	_check(ValidadorDeMundo.chave_aceita(negativa), "chave com sinal passa no validador")
	_check(ValidadorDeMundo.chave_aceita(ChaveMundo.de_posicao(Vector3(31.9, 20.0, 31.9))),
		"chave no canto do chunk passa no validador")


# --- ValidadorDeMundo -------------------------------------------------------------------

func _validador_valores() -> void:
	_secao("validador: chave e valor")
	for bom: Variant in [true, false, 0, -7, 1.5, "abc", &"abc", Vector2i(3, -4), Vector3(1, 2, 3),
			PackedInt32Array([1, 2, 3]), "x".repeat(ValidadorDeMundo.VALOR_MAX_BYTES)]:
		_check(ValidadorDeMundo.valor_aceito(bom), "valor aceito: %s" % type_string(typeof(bom)))
	var grande := PackedInt32Array()
	grande.resize(ValidadorDeMundo.VALOR_MAX_BYTES / 4)
	_check(ValidadorDeMundo.valor_aceito(grande), "PackedInt32Array no teto")
	grande.append(1)
	_check(not ValidadorDeMundo.valor_aceito(grande), "PackedInt32Array acima do teto")
	# 129 caracteres de 2 bytes em UTF-8: comprimento abaixo do teto, bytes acima.
	var acentuado := String.chr(0xE3).repeat(129)
	_check(acentuado.length() < ValidadorDeMundo.VALOR_MAX_BYTES
		and not ValidadorDeMundo.valor_aceito(acentuado), "teto em bytes, nao em caracteres")
	var objeto := RefCounted.new()
	for ruim: Variant in [null, objeto, {}, {"a": 1}, [], [1], NAN, INF, -INF,
			"x".repeat(ValidadorDeMundo.VALOR_MAX_BYTES + 1), Vector3(NAN, 0, 0), Vector3(0, 0, INF),
			Callable(), Vector2(1, 2), Color.RED, PackedByteArray([1]), Transform3D()]:
		_check(not ValidadorDeMundo.valor_aceito(ruim), "valor recusado: %s" % type_string(typeof(ruim)))

	for boa: StringName in [&"porta_20_12_160", &"item_0", &"item_4095", &"porta_-15_-129_30"]:
		_check(ValidadorDeMundo.chave_aceita(boa), "chave aceita: %s" % boa)
	for ruim: StringName in [&"", &"item_", &"porta_", &"Porta_1", &"dinheiro", &"saldo", &"npc_fala",
			&"porta_1 2", &"porta_1.5", &"porta_1/2", StringName("porta_" + String.chr(0xE9)),
			StringName("porta_" + "1".repeat(ValidadorDeMundo.CHAVE_MAX))]:
		_check(not ValidadorDeMundo.chave_aceita(ruim), "chave recusada: '%s'" % ruim)
	_check(ValidadorDeMundo.chave_aceita(StringName("porta_" + "1".repeat(ValidadorDeMundo.CHAVE_MAX - 6))),
		"chave no teto de %d" % ValidadorDeMundo.CHAVE_MAX)

	_check(ValidadorDeMundo.faixa(Vector2i(-3, 5)) == ValidadorDeMundo.Faixa.RUA, "faixa de rua")
	_check(ValidadorDeMundo.faixa(Vector2i(77451, 424242)) == ValidadorDeMundo.Faixa.INTERIOR, "faixa de interior")
	for outra: Vector2i in [Vector2i(-8, 424243), Vector2i(-9, 424243), Vector2i(12, 424243),
			Vector2i(0, 424244), Vector2i(0, 424245), Vector2i(0, 2147483647)]:
		_check(ValidadorDeMundo.faixa(outra) == ValidadorDeMundo.Faixa.OUTRA, "faixa reservada %s" % outra)


func _rua(pos: Vector3 = Vector3(10, 0.5, 10)) -> Dictionary:
	return {"pronto": true, "espaco": ProtocoloRede.ESPACO_RUA, "pos": pos}


func _interior() -> Dictionary:
	return {"pronto": true, "espaco": ProtocoloRede.espaco_interior(&"mercado", 77451),
		"pos": Vector3(500, 2000.5, 3)}


func _validador_julgar() -> void:
	_secao("validador: pedido de mundo")
	var porta := &"porta_20_12_160"
	var dentro := Vector2i(77451, 424242)
	_check(ValidadorDeMundo.julgar(Vector2i.ZERO, porta, true, _rua()) == M.OK, "porta no mesmo chunk")
	var nao_pronto := _rua()
	nao_pronto["pronto"] = false
	_check(ValidadorDeMundo.julgar(Vector2i.ZERO, porta, true, nao_pronto) == M.NAO_PRONTO, "sem _mundo_pronto")
	_check(ValidadorDeMundo.julgar(Vector2i.ZERO, &"lixo", null, nao_pronto) == M.NAO_PRONTO,
		"NAO_PRONTO vem antes de tudo")
	_check(ValidadorDeMundo.julgar(Vector2i.ZERO, porta, true, {}) == M.NAO_PRONTO, "quem vazio")
	_check(ValidadorDeMundo.julgar(Vector2i.ZERO, &"saldo", 10, _rua()) == M.INVALIDO, "chave fora da lista")
	_check(ValidadorDeMundo.julgar(Vector2i.ZERO, porta, null, _rua()) == M.INVALIDO, "valor null")
	_check(ValidadorDeMundo.julgar(Vector2i.ZERO, porta, RefCounted.new(), _rua()) == M.INVALIDO, "valor objeto")
	_check(ValidadorDeMundo.julgar(Vector2i.ZERO, porta, {"x": 1}, _rua()) == M.INVALIDO, "valor dicionario")
	_check(ValidadorDeMundo.julgar(Vector2i.ZERO, porta, NAN, _rua()) == M.INVALIDO, "valor NaN")
	_check(ValidadorDeMundo.julgar(Vector2i.ZERO, porta, "x".repeat(300), _rua()) == M.INVALIDO,
		"texto grande demais")
	# Item so muda pelo _pedir_item: por aqui, "item_3" = false duplicaria o item.
	_check(ValidadorDeMundo.julgar(Vector2i.ZERO, &"item_3", false, _rua()) == M.INVALIDO,
		"item nao muda pelo pedido generico")
	# Faixa de pessoa: Dinheiro e IWeed sao por jogador, nunca mundo.
	_check(ValidadorDeMundo.julgar(Vector2i(-8, 424243), &"porta_1", 999, _rua()) == M.INVALIDO,
		"coord do Dinheiro")
	_check(ValidadorDeMundo.julgar(Vector2i(-9, 424243), &"porta_1", true, _interior()) == M.INVALIDO,
		"coord do IWeed, mesmo de dentro de um interior")
	_check(ValidadorDeMundo.julgar(Vector2i(0, 424244), &"porta_1", true, _rua()) == M.INVALIDO, "folha de vagas")
	# Porta e bool em toda maquina: outro tipo passaria no filtro geral e iria a
	# todo cliente e ao save do anfitriao.
	_check(ValidadorDeMundo.julgar(Vector2i.ZERO, porta, false, _rua()) == M.OK, "porta fechada")
	for torto: Variant in [1, 0, 1.0, "true", &"aberta", Vector2i(1, 0), Vector3(1, 0, 0),
			PackedInt32Array([1])]:
		_check(ValidadorDeMundo.valor_aceito(torto)
			and ValidadorDeMundo.julgar(Vector2i.ZERO, porta, torto, _rua()) == M.INVALIDO,
			"porta com valor %s" % type_string(typeof(torto)))

	# Cota e a conferencia 2: vem antes de chave, valor, espaco e alcance.
	var sem_cota := _rua()
	sem_cota["cota"] = false
	_check(ValidadorDeMundo.julgar(Vector2i.ZERO, porta, true, sem_cota) == M.COTA, "sem cota")
	_check(ValidadorDeMundo.julgar(Vector2i.ZERO, &"lixo", null, sem_cota) == M.COTA,
		"pedido invalido sem cota e calado, nao respondido")
	_check(ValidadorDeMundo.julgar(Vector2i(9, 9), porta, true, sem_cota) == M.COTA, "longe sem cota e calado")
	var sem_cota_dentro := _interior()
	sem_cota_dentro["cota"] = false
	_check(ValidadorDeMundo.julgar(Vector2i.ZERO, porta, true, sem_cota_dentro) == M.COTA,
		"espaco errado sem cota e calado")
	var nada := nao_pronto.duplicate()
	nada["cota"] = false
	_check(ValidadorDeMundo.julgar(Vector2i.ZERO, porta, true, nada) == M.NAO_PRONTO, "NAO_PRONTO antes da cota")

	# Campo torto no `quem` nunca pode virar OK: `bool(null)` e erro de script, e
	# funcao que para no erro devolve 0, que e OK. O pedido e de 99 chunks longe.
	var fora := Vector2i(99, 99)
	for torto: Dictionary in [{"pronto": null}, {"pronto": "sim", "espaco": 0, "pos": Vector3.ZERO},
			{"pronto": 1, "espaco": 0, "pos": Vector3.ZERO},
			{"pronto": true, "espaco": null, "pos": Vector3.ZERO},
			{"pronto": true, "espaco": "0", "pos": Vector3.ZERO},
			{"pronto": true, "espaco": 0.0, "pos": Vector3.ZERO},
			{"pronto": true, "cota": null, "espaco": 0, "pos": Vector3.ZERO},
			{"pronto": true, "espaco": 0, "pos": null}]:
		_check(ValidadorDeMundo.julgar(fora, porta, true, torto) != M.OK, "quem torto: %s" % [torto])
		_check(ValidadorDeMundo.julgar_item(fora, 3, true, 1, torto, false) != M.OK,
			"quem torto no item: %s" % [torto])

	_check(ValidadorDeMundo.julgar(Vector2i.ZERO, porta, true, _interior()) == M.ESPACO,
		"chave de rua pedida de dentro de um interior")
	_check(ValidadorDeMundo.julgar(dentro, porta, true, _rua()) == M.ESPACO,
		"chave de interior pedida da rua")
	var estrada := _rua()
	estrada["espaco"] = ProtocoloRede.ESPACO_ESTRADA
	_check(ValidadorDeMundo.julgar(Vector2i.ZERO, porta, true, estrada) == M.ESPACO, "rua pedida da estrada")
	_check(ValidadorDeMundo.julgar(dentro, porta, true, estrada) == M.ESPACO, "interior pedido da estrada")
	var sem_espaco := _rua()
	sem_espaco.erase("espaco")
	_check(ValidadorDeMundo.julgar(Vector2i.ZERO, porta, true, sem_espaco) == M.ESPACO, "espaco desconhecido")
	_check(ValidadorDeMundo.julgar(dentro, porta, true, _interior()) == M.OK,
		"interior pedido de dentro (sem distancia na Fase 3)")

	# Alcance: o jogador em (10, 10) esta no chunk (0, 0).
	for perto: Vector2i in [Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(0, 1)]:
		_check(ValidadorDeMundo.julgar(perto, porta, true, _rua()) == M.OK, "1 chunk de distancia: %s" % perto)
	for longe: Vector2i in [Vector2i(2, 0), Vector2i(0, -2), Vector2i(2, 2), Vector2i(-2, 1)]:
		_check(ValidadorDeMundo.julgar(longe, porta, true, _rua()) == M.LONGE, "2 chunks: %s" % longe)
	# Jogador em chunk negativo: -0,1 esta no -1.
	var negativo := _rua(Vector3(-0.1, 0.5, -0.1))
	_check(ValidadorDeMundo.julgar(Vector2i(-2, -2), porta, true, negativo) == M.OK, "vizinho em coord negativa")
	_check(ValidadorDeMundo.julgar(Vector2i(1, 1), porta, true, negativo) == M.LONGE,
		"de -1 a 1 sao dois chunks")
	for sem_pos: Vector3 in [Vector3.INF, Vector3(NAN, 0, 0), Vector3(1e30, 0, 0)]:
		_check(ValidadorDeMundo.julgar(Vector2i.ZERO, porta, true, _rua(sem_pos)) == M.LONGE,
			"posicao %s" % sem_pos)
	var sem_campo := _rua()
	sem_campo.erase("pos")
	_check(ValidadorDeMundo.julgar(Vector2i.ZERO, porta, true, sem_campo) == M.LONGE, "sem posicao")
	# ESPACO vem antes de LONGE: quem esta no interior e longe ouve o motivo do espaco.
	_check(ValidadorDeMundo.julgar(Vector2i(50, 50), porta, true, _interior()) == M.ESPACO,
		"espaco antes de alcance")

	# Texto para o jogador.
	for m: int in [M.ESPACO, M.LONGE, M.JA_FOI, M.OCUPADO, M.CHEIO, M.INVALIDO]:
		_check(not ValidadorDeMundo.texto(m).is_empty(), "motivo %d tem texto" % m)
		_check(not ValidadorDeMundo.SILENCIOSOS.has(m), "motivo %d e respondido" % m)
	_check(ValidadorDeMundo.SILENCIOSOS.has(M.NAO_PRONTO) and ValidadorDeMundo.SILENCIOSOS.has(M.COTA),
		"NAO_PRONTO e COTA sao calados")
	_check(ValidadorDeMundo.texto(M.OK) == "", "OK sem texto")
	_check(ValidadorDeMundo.texto(M.JA_FOI) == "Alguem pegou antes.", "texto do JA_FOI")
	_check(ValidadorDeMundo.texto(200) == ValidadorDeMundo.texto(M.INVALIDO), "motivo desconhecido le como INVALIDO")
	_check(M.CHEIO < 256, "motivo cabe em u8")


func _validador_item() -> void:
	_secao("validador: pedido de item")
	var c := Vector2i.ZERO
	_check(ValidadorDeMundo.julgar_item(c, 3, true, 1, _rua(), false) == M.OK, "item no chao, perto")
	_check(ValidadorDeMundo.julgar_item(c, 3, true, 1, _rua(), true) == M.JA_FOI, "item ja pego")
	_check(ValidadorDeMundo.julgar_item(c, 3, true, 1, _rua(), false, false) == M.CHEIO, "mochila cheia")
	_check(ValidadorDeMundo.julgar_item(c, 3, true, 1, _rua(), true, false) == M.JA_FOI,
		"ja pego vem antes de mochila cheia")
	var nao_pronto := _rua()
	nao_pronto["pronto"] = false
	_check(ValidadorDeMundo.julgar_item(c, -1, false, 0, nao_pronto, true) == M.NAO_PRONTO, "sem _mundo_pronto")
	_check(ValidadorDeMundo.julgar_item(c, 0, true, 1, _rua(), false) == M.OK, "indice 0")
	_check(ValidadorDeMundo.julgar_item(c, 4095, true, 99, _rua(), false) == M.OK, "indice e qtd no teto")
	_check(ValidadorDeMundo.julgar_item(c, -1, true, 1, _rua(), false) == M.INVALIDO, "indice negativo")
	_check(ValidadorDeMundo.julgar_item(c, 4096, true, 1, _rua(), false) == M.INVALIDO, "indice acima do teto")
	_check(ValidadorDeMundo.julgar_item(c, 3, true, 0, _rua(), false) == M.INVALIDO, "qtd zero")
	_check(ValidadorDeMundo.julgar_item(c, 3, true, 100, _rua(), false) == M.INVALIDO, "qtd acima de 99")
	_check(ValidadorDeMundo.julgar_item(c, 3, false, 1, _rua(), false) == M.INVALIDO, "item fora da tabela")
	_check(ValidadorDeMundo.julgar_item(Vector2i(-8, 424243), 3, true, 1, _rua(), false) == M.INVALIDO,
		"item em faixa reservada")
	_check(ValidadorDeMundo.julgar_item(c, 3, true, 1, _interior(), false) == M.ESPACO, "item de rua, de dentro")
	_check(ValidadorDeMundo.julgar_item(Vector2i(77451, 424242), 3, true, 1, _interior(), false) == M.OK,
		"item de interior, de dentro")
	# Longe de um item ja pego ouve "longe": nao entrega o que ele nao ve.
	_check(ValidadorDeMundo.julgar_item(Vector2i(5, 5), 3, true, 1, _rua(), true) == M.LONGE,
		"longe vem antes de ja pego")
	_check(ValidadorDeMundo.julgar_item(c, 3, true, 1, _interior(), true) == M.ESPACO,
		"espaco vem antes de ja pego")
	var sem_cota := _rua()
	sem_cota["cota"] = false
	_check(ValidadorDeMundo.julgar_item(c, 3, true, 1, sem_cota, false) == M.COTA, "item sem cota")
	_check(ValidadorDeMundo.julgar_item(c, -1, false, 0, sem_cota, true) == M.COTA,
		"item invalido sem cota e calado")
	_check(ValidadorDeMundo.julgar_item(Vector2i(5, 5), 3, true, 1, sem_cota, true) == M.COTA,
		"item longe sem cota e calado")
	nao_pronto["cota"] = false
	_check(ValidadorDeMundo.julgar_item(c, 3, true, 1, nao_pronto, false) == M.NAO_PRONTO,
		"item: NAO_PRONTO antes da cota")


func _balde() -> void:
	_secao("cota de pedidos")
	var b := ValidadorDeMundo.Balde.new()
	var rajada := 0
	for _i in 10:
		if b.gastar(100.0):
			rajada += 1
	_check(rajada == 10, "rajada de 10 passa (%d)" % rajada)
	_check(not b.gastar(100.0), "o 11o no mesmo instante e calado")
	var depois := 0
	for _i in 10:
		if b.gastar(100.5):
			depois += 1
	_check(depois == 5, "meio segundo depois voltam 5 (%d)" % depois)
	_check(not b.gastar(99.0), "relogio para tras nao enche o balde")
	var cheio := ValidadorDeMundo.Balde.new()
	cheio.gastar(0.0)
	cheio.gastar(3600.0)
	_check(cheio.fichas <= ValidadorDeMundo.RAJADA, "uma hora parado nao passa da rajada")
	var nan := ValidadorDeMundo.Balde.new()
	nan.gastar(NAN)
	_check(is_finite(nan.fichas) and nan.gastar(1.0), "hora NaN nao envenena o balde")


# --- EspelhoDeMundo ------------------------------------------------------------------------

const EU := 7
const OUTRO := 9


func _ev(rev: int, chave: StringName, valor: Variant, autor: int, seq: int, cx: int = 0, cz: int = 0) -> Dictionary:
	return {"rev": rev, "cx": cx, "cz": cz, "chave": chave, "valor": valor, "autor": autor, "seq": seq}


func _escreve(escritas: Array[Dictionary], valor: Variant) -> bool:
	return escritas.size() == 1 and escritas[0]["valor"] == valor


func _espelho_previsao() -> void:
	_secao("espelho: previsao")
	var porta := &"porta_20_12_160"
	var e := EspelhoDeMundo.new()
	_check(e.concluir_carga(10, EU).is_empty() and e.carregado and e.rev_base == 10, "carga vazia")

	# Confirmada: a tela ja mostra, nada a escrever.
	e.prever(0, 0, porta, true, false, 1)
	_check(e.pendentes() == 1, "previsao pendente")
	_check(e.receber(_ev(11, porta, true, EU, 1), EU).is_empty(), "confirmacao nao escreve")
	_check(e.pendentes() == 0, "confirmacao tira de pendente")

	# Outro autor na mesma chave: a previsao cede, a tela mostra o servidor.
	e.prever(0, 0, porta, false, true, 2)
	var w := e.receber(_ev(12, porta, true, OUTRO, 40), EU)
	_check(_escreve(w, true), "outro autor derruba a previsao: %s" % [w])
	_check(w.size() == 1 and w[0]["cx"] == 0 and w[0]["cz"] == 0 and w[0]["chave"] == porta,
		"escrita diz onde")
	_check(e.pendentes() == 0, "previsao derrubada sai de pendente")
	# A confirmacao atrasada da previsao que cedeu: o servidor a aplicou depois, e
	# ela e o valor final.
	_check(_escreve(e.receber(_ev(13, porta, false, EU, 2), EU), false), "confirmacao atrasada escreve")
	_check(e.negado(2).is_empty(), "negacao de previsao que ja cedeu nao escreve")

	# Duas previsoes na mesma chave; a mais velha confirma, a mais nova e negada.
	e.prever(0, 0, porta, true, false, 3)
	e.prever(0, 0, porta, false, true, 4)
	_check(e.pendentes() == 1, "uma pendente por chave")
	_check(e.receber(_ev(14, porta, true, EU, 3), EU).is_empty(), "confirmacao da mais velha nao escreve")
	_check(e.pendentes() == 1, "a mais nova continua pendente")
	_check(_escreve(e.negado(4), true), "negacao da mais nova volta ao valor que o servidor confirmou")
	_check(e.pendentes() == 0, "negada sai de pendente")

	# Negacao volta ao anterior; negacao velha nao faz nada.
	e.prever(0, 0, porta, true, false, 5)
	_check(_escreve(e.negado(5), false), "negacao volta ao anterior")
	_check(e.negado(5).is_empty(), "negar duas vezes nao escreve de novo")
	e.prever(0, 0, porta, true, false, 6)
	e.prever(0, 0, porta, false, true, 7)
	_check(e.negado(6).is_empty() and e.pendentes() == 1, "negacao substituida nao escreve")
	_check(_escreve(e.negado(7), false), "a ultima negada volta ao primeiro anterior, nao ao da tela")
	_check(e.negado(999).is_empty(), "seq desconhecido")

	# Chaves diferentes nao se misturam: mesma chave em outro chunk, outra chave.
	e.prever(0, 0, porta, true, false, 8)
	_check(_escreve(e.receber(_ev(15, porta, false, OUTRO, 1, 1, 0), EU), false),
		"mesma chave em outro chunk escreve")
	_check(_escreve(e.receber(_ev(16, &"porta_1_1_1", true, OUTRO, 2), EU), true), "outra chave escreve")
	_check(e.pendentes() == 1, "a previsao de (0,0) continua")
	# Evento velho depois da carga cai.
	_check(e.receber(_ev(10, porta, false, OUTRO, 3), EU).is_empty(), "rev da carga cai")
	_check(e.receber(_ev(3, porta, false, OUTRO, 3), EU).is_empty(), "rev antigo cai")
	_check(e.pendentes() == 1, "evento velho nao derruba previsao")

	# Tres autores de uma chave, na ordem do servidor: minha 20, a dele, minha 21.
	var f := EspelhoDeMundo.new()
	f.concluir_carga(0, EU)
	f.prever(0, 0, porta, 1, 0, 20)
	f.prever(0, 0, porta, 2, 1, 21)
	_check(f.receber(_ev(1, porta, 1, EU, 20), EU).is_empty(), "minha velha confirmada, a nova voa")
	_check(_escreve(f.receber(_ev(2, porta, 3, OUTRO, 1), EU), 3), "a dele derruba a nova")
	_check(_escreve(f.receber(_ev(3, porta, 2, EU, 21), EU), 2), "a minha nova chega depois e e a final")
	_check(f.pendentes() == 0 and f.negado(21).is_empty(), "nada pendente")
	# A dele, depois minha 30 aceita e minha 31 negada: fica a 30.
	f.prever(0, 0, porta, 5, 2, 30)
	f.prever(0, 0, porta, 6, 5, 31)
	_check(_escreve(f.receber(_ev(4, porta, 4, OUTRO, 2), EU), 4), "a dele antes das minhas")
	_check(_escreve(f.receber(_ev(5, porta, 5, EU, 30), EU), 5), "minha 30 depois da dele escreve")
	_check(f.negado(31).is_empty(), "negar a 31 que ja cedeu nao volta nada")
	# Derrubada, previsao nova, e so depois a confirmacao da velha: a negacao da
	# nova volta ao valor da velha, que o servidor aplicou depois do outro.
	f.prever(0, 0, porta, 7, 5, 40)
	_check(_escreve(f.receber(_ev(6, porta, 8, OUTRO, 3), EU), 8), "derrubada")
	f.prever(0, 0, porta, 9, 8, 41)
	_check(f.receber(_ev(7, porta, 7, EU, 40), EU).is_empty(), "minha 40 confirmada sob a 41")
	_check(_escreve(f.negado(41), 7), "negada a 41, volta a 7 e nao ao 8 da tela de antes")

	_espelho_modelo()


## Um cliente com espelho, outro autor e o servidor, sorteados: o servidor
## processa na ordem de chegada, o canal 0 entrega na ordem, e a carga chega no
## canal 2 em qualquer ponto dele. No fim, a tela do cliente e a do servidor.
func _espelho_modelo() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var divergiu := 0
	var pendurado := 0
	var primeiro := ""
	for cenario in 3000:
		var r := _modelo_um(rng)
		if r != "":
			if r.begins_with("pendente"):
				pendurado += 1
			else:
				divergiu += 1
			if primeiro.is_empty():
				primeiro = "cenario %d: %s" % [cenario, r]
	_check(divergiu == 0, "3000 cenarios sorteados: %d terminaram diferentes do servidor (%s)" % [divergiu, primeiro])
	_check(pendurado == 0, "3000 cenarios sorteados: %d ficaram com previsao pendente (%s)" % [pendurado, primeiro])


const _LUGARES_MODELO: Array = [[0, &"porta_1_1_1"], [0, &"porta_2_2_2"], [1, &"porta_1_1_1"]]


func _modelo_um(rng: RandomNumberGenerator) -> String:
	var servidor := {}
	var rev := 0
	for _i in rng.randi_range(0, 4):
		rev += 1
		var l0: Array = _LUGARES_MODELO[rng.randi_range(0, 2)]
		servidor["%d|%s" % [l0[0], l0[1]]] = rng.randi_range(0, 3)
	var e := EspelhoDeMundo.new()
	var tela := {}
	var para_servidor: Array = []
	var canal0: Array = []
	var foto := {}
	var rev_foto := -1
	var carga_chegou := false
	var seq := 0
	var passos := rng.randi_range(4, 60)
	var passo := 0
	while true:
		var drenando := passo >= passos
		if drenando and carga_chegou and para_servidor.is_empty() and canal0.is_empty():
			break
		passo += 1
		var acao := rng.randi_range(0, 5)
		if drenando:
			acao = [2, 3, 4][rng.randi_range(0, 2)]
		match acao:
			0:
				var l: Array = _LUGARES_MODELO[rng.randi_range(0, 2)]
				var v := rng.randi_range(0, 3)
				rev += 1
				servidor["%d|%s" % [l[0], l[1]]] = v
				canal0.append({"ev": {"rev": rev, "cx": l[0], "cz": 0, "chave": l[1], "valor": v,
					"autor": OUTRO, "seq": 0}})
			1:
				if carga_chegou:
					var l: Array = _LUGARES_MODELO[rng.randi_range(0, 2)]
					var k := "%d|%s" % [l[0], l[1]]
					var v := rng.randi_range(0, 3)
					seq += 1
					e.prever(l[0], 0, l[1], v, tela.get(k, -1), seq)
					tela[k] = v
					para_servidor.append([seq, l, v])
			2:
				if not para_servidor.is_empty():
					var ped: Array = para_servidor.pop_front()
					var l: Array = ped[1]
					if rng.randf() < 0.3:
						canal0.append({"neg": ped[0]})
					else:
						rev += 1
						servidor["%d|%s" % [l[0], l[1]]] = ped[2]
						canal0.append({"ev": {"rev": rev, "cx": l[0], "cz": 0, "chave": l[1],
							"valor": ped[2], "autor": EU, "seq": ped[0]}})
			3:
				if not canal0.is_empty():
					var m: Dictionary = canal0.pop_front()
					if m.has("neg"):
						_modelo_aplicar(tela, e.negado(int(m["neg"])))
					else:
						_modelo_aplicar(tela, e.receber(m["ev"], EU))
			4, 5:
				if rev_foto < 0:
					foto = servidor.duplicate()
					rev_foto = rev
				elif not carga_chegou and (drenando or rng.randf() < 0.3):
					tela = foto.duplicate()
					_modelo_aplicar(tela, e.concluir_carga(rev_foto, EU))
					carga_chegou = true
	var chaves := {}
	for k: String in servidor:
		chaves[k] = true
	for k: String in tela:
		chaves[k] = true
	for k: String in chaves:
		if tela.get(k, -1) != servidor.get(k, -1):
			return "%s: tela %s, servidor %s" % [k, tela.get(k, -1), servidor.get(k, -1)]
	if e.pendentes() != 0:
		return "pendente: %d" % e.pendentes()
	return ""


func _modelo_aplicar(tela: Dictionary, escritas: Array[Dictionary]) -> void:
	for w: Dictionary in escritas:
		tela["%d|%s" % [int(w["cx"]), w["chave"]]] = w["valor"]


func _espelho_carga() -> void:
	_secao("espelho: espera da carga")
	var porta := &"porta_20_12_160"
	var e := EspelhoDeMundo.new()
	_check(not e.carregado and e.rev_base == -1, "comeca sem carga")
	_check(e.receber(_ev(4, porta, true, OUTRO, 1), EU).is_empty(), "antes da carga espera")
	_check(e.receber(_ev(5, porta, false, OUTRO, 2), EU).is_empty(), "espera 2")
	_check(e.receber(_ev(6, porta, true, OUTRO, 3), EU).is_empty(), "espera 3")
	_check(e.receber(_ev(7, porta, false, EU, 1), EU).is_empty(), "espera 4")
	_check(e.receber(_ev(8, &"item_2", true, OUTRO, 4, -3, 5), EU).is_empty(), "espera 5")
	var w := e.concluir_carga(5, EU)
	_check(w.size() == 3, "so o que veio depois da carga (rev 6, 7, 8): %d" % w.size())
	if w.size() == 3:
		_check(w[0]["valor"] == true and w[1]["valor"] == false and w[2]["chave"] == &"item_2",
			"na ordem de chegada")
		_check(w[2]["cx"] == -3 and w[2]["cz"] == 5, "coord negativa volta")
	_check(e.receber(_ev(9, porta, true, OUTRO, 5), EU).size() == 1, "depois da carga aplica direto")
	_check(e.concluir_carga(9, EU).is_empty(), "espera ja esvaziou")

	var cheio := EspelhoDeMundo.new()
	for i in EspelhoDeMundo.TETO_ESPERA:
		cheio.receber(_ev(100 + i, porta, i % 2 == 0, OUTRO, i), EU)
	_check(not cheio.transbordou, "no teto ainda nao transbordou")
	cheio.receber(_ev(99999, porta, true, OUTRO, 1), EU)
	_check(cheio.transbordou, "acima do teto marca transbordou")
	_check(cheio.concluir_carga(0, EU).size() == EspelhoDeMundo.TETO_ESPERA, "espera nao passa do teto")
	_check(cheio.transbordou, "transbordou fica ate zerar")
	cheio.prever(0, 0, porta, true, false, 1)
	cheio.zerar()
	_check(not cheio.carregado and cheio.rev_base == -1 and not cheio.transbordou
		and cheio.pendentes() == 0, "zerar volta ao comeco")
	_check(cheio.negado(1).is_empty(), "zerar esquece as previsoes")


## O anfitriao carregou um save no meio da sessao e mandou o mundo de novo. O
## espelho ja esta carregado, entao os eventos continuam sendo aplicados; os que
## o servidor mandou DEPOIS da recarga e chegaram ANTES dela tem de voltar por
## cima, e os de antes ficam dentro dela.
func _espelho_recarga() -> void:
	_secao("espelho: recarga no meio da sessao")
	var porta := &"porta_20_12_160"
	var e := EspelhoDeMundo.new()
	e.concluir_carga(10, EU)
	_check(e.receber(_ev(11, porta, true, OUTRO, 1), EU).size() == 1, "aplica antes da recarga")
	# A recarga sai com rev 12; o evento 13 foi mandado depois e chegou antes dela.
	_check(e.receber(_ev(12, &"item_1", true, OUTRO, 2), EU).size() == 1, "rev 12 aplica")
	_check(e.receber(_ev(13, porta, false, OUTRO, 3), EU).size() == 1, "rev 13 aplica")
	e.prever(0, 0, &"item_5", true, false, 7)
	var w := e.recarga_concluida(12, EU)
	_check(w.size() == 1, "so o evento mais novo que a recarga volta: %d" % w.size())
	if w.size() == 1:
		_check(w[0]["chave"] == porta and w[0]["valor"] == false, "e com o valor dele")
	_check(e.rev_base == 12 and e.carregado, "rev_base passa a ser a da recarga")
	_check(e.pendentes() == 0, "previsoes do mundo velho caem")
	_check(e.negado(7).is_empty(), "negar a previsao velha nao reverte para o mundo velho")
	_check(e.receber(_ev(12, &"item_1", true, OUTRO, 2), EU).is_empty(),
		"evento repetido dentro da recarga cai")
	_check(e.receber(_ev(14, &"item_5", true, EU, 7), EU).size() == 1,
		"confirmacao atrasada da previsao velha passa como evento comum")
	_check(not e.transbordou, "recarga normal nao transborda")
	var w2 := e.recarga_concluida(20, EU)
	_check(w2.is_empty(), "segunda recarga mais nova que tudo nao reaplica nada")

	var longa := EspelhoDeMundo.new()
	longa.concluir_carga(0, EU)
	for i in EspelhoDeMundo.TETO_RECENTES + 10:
		longa.receber(_ev(100 + i, porta, i % 2 == 0, OUTRO, i), EU)
	longa.recarga_concluida(50, EU)
	_check(longa.transbordou, "mais eventos que a lembranca dentro de uma recarga marca transbordou")
	var curta := EspelhoDeMundo.new()
	curta.concluir_carga(0, EU)
	for i in EspelhoDeMundo.TETO_RECENTES + 10:
		curta.receber(_ev(100 + i, porta, i % 2 == 0, OUTRO, i), EU)
	_check(curta.recarga_concluida(100 + EspelhoDeMundo.TETO_RECENTES, EU).size() == 9
		and not curta.transbordou, "lembranca cheia mas com a recarga dentro dela: sem perda")


# --- CargaDeMundo ---------------------------------------------------------------------------

## Uma hora de jogo, feita a mao: 600 chunks alterados (porta, item, fala, coisa
## largada), alguns interiores e pessoas, e 2000 chunks visitados.
func _mundo_de_uma_hora() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var mundo := {}
	for _i in 600:
		var cx := rng.randi_range(-60, 60)
		var cz := rng.randi_range(-60, 60)
		var d: Dictionary = {}
		d[StringName("item_%d" % rng.randi_range(0, 40))] = true
		d[StringName("porta_%d_%d_%d" % [rng.randi_range(0, 320), rng.randi_range(0, 40),
			rng.randi_range(0, 320)])] = rng.randf() < 0.5
		if rng.randf() < 0.5:
			d[&"npc_fala"] = rng.randi_range(0, 12)
		if rng.randf() < 0.3:
			d[&"largado"] = Vector3(rng.randf_range(0, 32), rng.randf_range(0, 3), rng.randf_range(0, 32))
		mundo["%d,%d" % [cx, cz]] = d
	for _i in 40:
		mundo["%d,%d" % [rng.randi_range(70000, 99000), 424242]] = {&"plantio": rng.randi_range(0, 5),
			&"item_1": true}
	for _i in 80:
		mundo["%d,%d" % [rng.randi_range(1, 50000), 424243]] = {&"npc_ja_disse": true, &"profissao": &"padeiro"}
	var visitados := PackedStringArray()
	var cx0 := 0
	var cz0 := 0
	for _i in 2000:
		cx0 += rng.randi_range(-1, 1)
		cz0 += rng.randi_range(-1, 1)
		visitados.append("%d,%d" % [cx0, cz0])
	return [mundo, visitados]


func _carga_ida_e_volta() -> void:
	_secao("carga: ida e volta")
	var hora := _mundo_de_uma_hora()
	var mundo: Dictionary = hora[0]
	var visitados: PackedStringArray = hora[1]
	var partes := CargaDeMundo.empacotar(mundo, visitados)
	var comp := 0
	for p: PackedByteArray in partes:
		comp += p.size()
	var bruto := var_to_bytes([mundo, visitados]).size()
	print("   1 h de jogo: %d chunks, %d visitados; %d bytes brutos, %d comprimidos (%.0f%%), %d parte(s)"
		% [mundo.size(), visitados.size(), bruto, comp, 100.0 * comp / bruto, partes.size()])
	_check(not partes.is_empty(), "ao menos uma parte")
	var volta := CargaDeMundo.desempacotar(partes)
	_check(volta.size() == 2, "desempacota")
	if volta.size() == 2:
		_check(volta[0] == mundo, "mundo volta igual")
		_check(volta[1] == visitados, "visitados voltam iguais")
		var um: Dictionary = volta[0][mundo.keys()[0]]
		var chaves_ok := true
		for k: Variant in um:
			if typeof(k) != TYPE_STRING_NAME:
				chaves_ok = false
		_check(chaves_ok, "chaves voltam StringName")
	var vazio := CargaDeMundo.empacotar({}, PackedStringArray())
	_check(vazio.size() == 1, "mundo vazio e uma parte")
	_check(CargaDeMundo.desempacotar(vazio) == [{}, PackedStringArray()], "mundo vazio volta")

	# Mundo grande e sem repeticao: tem de passar de 16 KB comprimido.
	var grande := _mundo_grande()
	var gp := CargaDeMundo.empacotar(grande, PackedStringArray(["0,0"]))
	var maior := 0
	var soma := 0
	for p: PackedByteArray in gp:
		maior = maxi(maior, p.size())
		soma += p.size()
	print("   mundo grande: %d bytes comprimidos, %d partes" % [soma, gp.size()])
	_check(soma > CargaDeMundo.PEDACO and gp.size() == ceili(float(soma) / CargaDeMundo.PEDACO),
		"acima de 16 KB corta em %d partes" % gp.size())
	_check(maior <= CargaDeMundo.PEDACO, "nenhuma parte passa de %d" % CargaDeMundo.PEDACO)
	var gv := CargaDeMundo.desempacotar(gp)
	_check(gv.size() == 2 and gv[0] == grande, "mundo grande volta igual")


func _mundo_grande() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var mundo := {}
	for i in 3000:
		mundo["%d,%d" % [i, -i]] = {&"porta_1_2_3": rng.randi(), &"largado": Vector3(rng.randf(), rng.randf(), rng.randf())}
	return mundo


func _carga_montagem() -> void:
	_secao("carga: montagem")
	var partes := CargaDeMundo.empacotar(_mundo_grande(), PackedStringArray())
	var n := partes.size()
	var m := CargaDeMundo.Montagem.new()
	var completou_cedo := false
	# Fora de ordem: de tras para a frente.
	for i in range(n - 1, 0, -1):
		if m.receber(3, i, n, partes[i]):
			completou_cedo = true
	_check(not completou_cedo and not m.completa(), "incompleta ate a ultima parte")
	_check(m.partes().is_empty(), "incompleta nao entrega partes")
	var bytes_antes := m.bytes
	_check(not m.receber(3, n - 1, n, partes[n - 1]) and m.bytes == bytes_antes, "parte repetida e ignorada")
	# Parte fora das regras nao mexe no que ja chegou.
	var lixo := PackedByteArray([1, 2, 3])
	var grande := PackedByteArray()
	grande.resize(CargaDeMundo.PEDACO + 1)
	_check(not m.receber(3, 0, 0, lixo), "total zero")
	_check(not m.receber(3, 0, CargaDeMundo.TETO_PARTES + 1, lixo), "total acima do teto")
	_check(not m.receber(3, n, n, lixo), "parte alem do total")
	_check(not m.receber(3, -1, n, lixo), "parte negativa")
	_check(not m.receber(3, 0, n, PackedByteArray()), "parte vazia")
	_check(not m.receber(3, 0, n, grande), "parte acima de 16 KB")
	_check(m.rev == 3 and m.total == n and m.bytes == bytes_antes, "recusadas nao mexem no estado")
	_check(m.receber(3, 0, n, partes[0]), "a que faltava completa")
	var volta := CargaDeMundo.desempacotar(m.partes())
	_check(volta.size() == 2 and volta[0] == _mundo_grande(), "montada fora de ordem volta igual")

	# Carga nova substitui a velha pela metade.
	var m2 := CargaDeMundo.Montagem.new()
	m2.receber(1, 0, n, partes[0])
	m2.receber(1, 1, n, partes[1])
	var pequena := CargaDeMundo.empacotar({"0,0": {&"porta_1_1_1": true}}, PackedStringArray())
	_check(m2.receber(2, 0, pequena.size(), pequena[0]), "rev nova recomeca e completa")
	_check(m2.rev == 2 and m2.total == 1, "a velha foi descartada")
	_check(CargaDeMundo.desempacotar(m2.partes()).size() == 2, "a nova desempacota")
	m2.zerar()
	_check(m2.rev == -1 and m2.total == 0 and m2.bytes == 0 and not m2.completa(), "zerar")


func _carga_lixo() -> void:
	_secao("carga: lixo nao quebra")
	var partes := CargaDeMundo.empacotar(_mundo_grande(), PackedStringArray(["1,2"]))
	var n := partes.size()
	_check(CargaDeMundo.desempacotar([]).is_empty(), "sem partes")
	_check(CargaDeMundo.desempacotar([PackedByteArray([1, 2])]).is_empty(), "dois bytes")
	_check(CargaDeMundo.desempacotar(["texto", 3]).is_empty(), "partes que nao sao bytes")
	var sem_meio := partes.duplicate()
	sem_meio.remove_at(1)
	_check(CargaDeMundo.desempacotar(sem_meio).is_empty(), "parte do meio faltando")
	var cortada := partes.duplicate()
	var ultima: PackedByteArray = cortada[n - 1]
	cortada[n - 1] = ultima.slice(0, ultima.size() - 10)
	_check(CargaDeMundo.desempacotar(cortada).is_empty(), "ultima parte cortada")
	var trocada := partes.duplicate()
	trocada[0] = partes[1]
	trocada[1] = partes[0]
	_check(CargaDeMundo.desempacotar(trocada).is_empty(), "partes fora de ordem")
	var magico := partes.duplicate()
	var p0: PackedByteArray = (magico[0] as PackedByteArray).duplicate()
	p0[5] = p0[5] ^ 0xFF
	magico[0] = p0
	_check(CargaDeMundo.desempacotar(magico).is_empty(), "quadro zstd estragado")

	# Bytes trocados no meio: sem checksum, o zstd pode ate descomprimir. O que se
	# exige e nao quebrar e so devolver coisa com a forma certa.
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var forma_ok := true
	var recusadas := 0
	for _tentativa in 40:
		var sujas := partes.duplicate()
		var qual := rng.randi_range(0, n - 1)
		var p: PackedByteArray = (sujas[qual] as PackedByteArray).duplicate()
		var onde := rng.randi_range(8 if qual == 0 else 0, p.size() - 1)
		p[onde] = p[onde] ^ (1 + rng.randi_range(0, 254))
		sujas[qual] = p
		var r := CargaDeMundo.desempacotar(sujas)
		if r.is_empty():
			recusadas += 1
		elif r.size() != 2 or typeof(r[0]) != TYPE_DICTIONARY or typeof(r[1]) != TYPE_PACKED_STRING_ARRAY:
			forma_ok = false
	print("   40 bytes trocados: %d recusados, o resto descomprimiu com a forma certa" % recusadas)
	_check(forma_ok, "byte trocado nunca devolve forma errada")

	# Cabecalho mentindo o tamanho.
	var comp := var_to_bytes([{}, PackedStringArray()]).compress(FileAccess.COMPRESSION_ZSTD)
	_check(CargaDeMundo.desempacotar([_com_cabecalho(CargaDeMundo.TETO_BRUTO + 1, comp)]).is_empty(),
		"cabecalho acima do teto")
	_check(CargaDeMundo.desempacotar([_com_cabecalho(0, comp)]).is_empty(), "cabecalho zero")
	var certo := var_to_bytes([{}, PackedStringArray()]).size()
	_check(CargaDeMundo.desempacotar([_com_cabecalho(certo + 100, comp)]).is_empty(),
		"cabecalho maior que o conteudo")
	_check(CargaDeMundo.desempacotar([_com_cabecalho(certo, comp)]).size() == 2, "cabecalho certo passa")

	# Lixo puro.
	var lixo := PackedByteArray()
	for _i in 4000:
		lixo.append(rng.randi_range(0, 255))
	_check(CargaDeMundo.desempacotar([lixo]).is_empty(), "4000 bytes de lixo")
	var lixo_com_cabecalho := _com_cabecalho(1000, lixo)
	_check(CargaDeMundo.desempacotar([lixo_com_cabecalho]).is_empty(), "lixo com cabecalho plausivel")

	# Descomprime, mas nao tem a forma de uma carga.
	for errado: Variant in [{"a": 1}, 42, [1, 2, 3], [{}, PackedStringArray(), 3], [{}, ["0,0"]],
			[[], PackedStringArray()], [{"x": {}}, PackedStringArray()], [{"1,2,3": {}}, PackedStringArray()],
			[{"1,a": {}}, PackedStringArray()], [{"1,2": 5}, PackedStringArray()],
			[{Vector2i(1, 2): {}}, PackedStringArray()], [{"0,0": {5: true}}, PackedStringArray()],
			[{"0,0": {&"item_1": true, Vector2i(1, 1): true}}, PackedStringArray()]]:
		_check(CargaDeMundo.desempacotar(_empacotar_cru(errado)).is_empty(), "forma errada: %s" % [errado])
	# O anfitriao que abriu um save tem chaves String (JSON), e a carga dele passa.
	var de_save := [{"0,0": {"item_1": true, "npc_fala": 3.0}, "2,-1": {&"porta_1_2_3": true}},
		PackedStringArray(["0,0"])]
	var volta_save := CargaDeMundo.desempacotar(_empacotar_cru(de_save))
	_check(volta_save.size() == 2 and volta_save[0] == de_save[0], "chaves String de save passam")

	# Mundo que passaria de 512 partes nao sai do servidor.
	var ruido := Crypto.new().generate_random_bytes(CargaDeMundo.TETO_PARTES * CargaDeMundo.PEDACO + 1024)
	_check(CargaDeMundo.empacotar({"0,0": {&"x": ruido}}, PackedStringArray()).is_empty(),
		"acima de %d partes nao empacota" % CargaDeMundo.TETO_PARTES)
	# Um objeto codificado nao e instanciado.
	var com_objeto := var_to_bytes_with_objects([{"0,0": {&"x": RefCounted.new()}}, PackedStringArray()])
	var obj_comp := _com_cabecalho(com_objeto.size(), com_objeto.compress(FileAccess.COMPRESSION_ZSTD))
	_check(CargaDeMundo.desempacotar([obj_comp]).is_empty(), "carga com objeto e recusada")


func _com_cabecalho(tam: int, comp: PackedByteArray) -> PackedByteArray:
	var buf := PackedByteArray()
	buf.resize(4)
	buf.encode_u32(0, tam)
	buf.append_array(comp)
	return buf


func _empacotar_cru(v: Variant) -> Array:
	var bruto := var_to_bytes(v)
	return [_com_cabecalho(bruto.size(), bruto.compress(FileAccess.COMPRESSION_ZSTD))]


# --- PoliticaDeMundo ------------------------------------------------------------------------

const D := PoliticaDeMundo.Dono
const L := PoliticaDeMundo.Lugar


func _r(cx: int, cz: int, chave: String) -> Dictionary:
	return PoliticaDeMundo.regra(Vector2i(cx, cz), StringName(chave))


func _politica() -> void:
	_secao("politica: de quem e cada escrita")
	var casos := [
		# cx, cz, chave, dono, lugar (-1 = nao importa), fundir
		[3, -6, "porta_91_-100_201", D.MUNDO, L.RUA, false],
		[-2, 7, "item_4", D.MUNDO, L.RUA, false],
		[0, 0, "saldo", D.LOCAL, -1, false],
		[-8, 424243, "saldo", D.PESSOA, -1, false],
		[-9, 424243, "pedidos", D.PESSOA, -1, false],
		[-7, 424243, "pendentes", D.PESSOA, -1, false],
		[-7, 424243, "porta_1", D.PESSOA, -1, false],
		[123, 424243, "npc_role", D.PESSOA, -1, false],
		[123, 424243, "dono_pagou", D.PESSOA, -1, false],
		[123, 424243, "iw_ganho", D.PESSOA, -1, false],
		[123, 424243, "tarefas", D.PESSOA, -1, false],
		[123, 424243, "funcoes", D.MUNDO, L.LIVRE, false],
		[123, 424243, "profissao", D.MUNDO, L.LIVRE, false],
		[123, 424243, "personagem", D.LOCAL, -1, false],
		[0, 424244, "fazendeiro", D.MUNDO, L.LIVRE, false],
		[1, 424244, "fazendeiro", D.LOCAL, -1, false],
		[-10, 424245, "mao", D.PESSOA, -1, false],
		[-10, 424245, "loja_3", D.MUNDO, L.LIVRE, true],
		[77551, 424242, "plantio", D.MUNDO, L.COMODO, true],
		[77551, 424242, "item_2", D.MUNDO, L.COMODO, false],
		[77551, 424242, "porta_1_2_3", D.MUNDO, L.COMODO, false],
		[77551, 424242, "falou_chegada", D.PESSOA, -1, false],
		[77551, 424242, "repeticao", D.PESSOA, -1, false],
		[77551, 424242, "novidade", D.LOCAL, -1, false],
		[5, 424299, "item_1", D.LOCAL, -1, false],
	]
	for c: Array in casos:
		var r := _r(c[0], c[1], c[2])
		var ok: bool = int(r["dono"]) == int(c[3]) and bool(r["fundir"]) == bool(c[5]) \
			and (int(c[4]) < 0 or int(r["lugar"]) == int(c[4]))
		_check(ok, "regra de (%d, %d) %s: %s" % [c[0], c[1], c[2], r])
	_check(bool(_r(123, 424243, "personagem")["conhecida"]), "personagem e local declarado")
	_check(not bool(_r(0, 0, "saldo")["conhecida"]), "chave sem dono e avisada")
	_check(not bool(_r(77551, 424242, "novidade")["conhecida"]), "chave nova de comodo e avisada")

	var mundo := {
		"-8,424243": {"saldo": 90},
		"3,-6": {"porta_1_2_3": true, "item_0": true},
		"77551,424242": {"plantio": {"regador": 3}, "falou_chegada": true},
		"-10,424245": {"mao": {"sku": "x"}, "loja_1": {"vagas": {}}},
		"lixo": 5,
	}
	var sem := PoliticaDeMundo.sem_pessoais(mundo)
	var so := PoliticaDeMundo.so_pessoais(mundo)
	_check(not sem.has("-8,424243"), "carteira nao vai na carga")
	_check(sem["77551,424242"] == {"plantio": {"regador": 3}}, "conversa sai, plantio fica")
	_check(sem["-10,424245"] == {"loja_1": {"vagas": {}}}, "mao sai, prateleira fica")
	_check(sem.has("lixo"), "o que nao se le como coord passa sem ser tocado")
	_check(so.size() == 3 and so["-8,424243"] == {"saldo": 90}
		and so["77551,424242"] == {"falou_chegada": true} and so["-10,424245"] == {"mao": {"sku": "x"}},
		"so os pessoais: %s" % [so])
	var do_anfitriao := {"-8,424243": {"saldo": 5000}, "3,-6": {"porta_1_2_3": false},
		"77551,424242": {"falou_chegada": false, "plantio": {"regador": 1}}}
	var junto := PoliticaDeMundo.juntar(PoliticaDeMundo.sem_pessoais(do_anfitriao), so)
	_check(junto["-8,424243"] == {"saldo": 90}, "entra com a propria carteira, nao a do anfitriao")
	_check(junto["3,-6"] == {"porta_1_2_3": false}, "a porta e a do anfitriao")
	_check(junto["77551,424242"] == {"plantio": {"regador": 1}, "falou_chegada": true},
		"o plantio e do anfitriao e a conversa e a propria: %s" % [junto["77551,424242"]])
	_check(do_anfitriao["-8,424243"] == {"saldo": 5000}, "juntar nao mexe no original")


# --- FusaoDeMundo ---------------------------------------------------------------------------

func _fusao() -> void:
	_secao("fusao: escrita por diferenca")
	var base := {"vagas": {"1": {"sku": "arroz", "colunas": [3, 3]}, "2": {"sku": "feijao", "colunas": [2]}},
		"caixa": 10}
	var a := base.duplicate(true)
	a["vagas"]["1"]["colunas"] = [2, 3]
	var b := base.duplicate(true)
	b["vagas"]["2"]["colunas"] = [1]
	b["caixa"] = 12
	var ra := FusaoDeMundo.diferenca(base, a)
	var rb := FusaoDeMundo.diferenca(base, b)
	_check(FusaoDeMundo.aplicar(base, ra) == a, "ida e volta de A")
	_check(FusaoDeMundo.aplicar(base, rb) == b, "ida e volta de B")
	var ab: Variant = FusaoDeMundo.aplicar(FusaoDeMundo.aplicar(base, ra), rb)
	var ba: Variant = FusaoDeMundo.aplicar(FusaoDeMundo.aplicar(base, rb), ra)
	_check(ab == ba, "a ordem das duas mudancas nao importa")
	_check(ab is Dictionary and ab["vagas"]["1"]["colunas"] == [2, 3] and ab["vagas"]["2"]["colunas"] == [1]
		and ab["caixa"] == 12, "as duas prateleiras mexidas ficam: %s" % [ab])
	# O que a troca inteira faria: o segundo a chegar devolve o produto do primeiro.
	_check(b["vagas"]["1"]["colunas"] == [3, 3], "(controle) o valor inteiro de B apagaria A")
	_check(base["vagas"]["1"]["colunas"] == [3, 3], "aplicar nao mexe na base")
	_check(FusaoDeMundo.vazio(FusaoDeMundo.diferenca(base, base.duplicate(true))), "igual e vazio")
	var sem_caixa := base.duplicate(true)
	sem_caixa.erase("caixa")
	var rc := FusaoDeMundo.diferenca(base, sem_caixa)
	_check(FusaoDeMundo.aplicar(base, rc) == sem_caixa, "chave apagada some")
	_check(FusaoDeMundo.aplicar(null, FusaoDeMundo.diferenca(null, base)) == base, "do nada ao valor")
	var vasos := {"vasos": [1, 2, 3], "minuto": 10.0}
	var vasos2 := {"vasos": [1, 5, 3], "minuto": 12.5}
	_check(FusaoDeMundo.aplicar(vasos, FusaoDeMundo.diferenca(vasos, vasos2)) == vasos2, "lista troca inteira")
	for torto: Variant in [null, 3, "x", {"p": 3}, {"a": "x"}, {"p": {"k": {"__r": true, "p": 1}}}]:
		_check(FusaoDeMundo.aplicar(base, torto) == null, "remendo torto recusado: %s" % [torto])
	var fundo: Variant = 1
	for i in FusaoDeMundo.FUNDO_MAX + 2:
		fundo = [fundo]
	for sujo: Variant in [RefCounted.new(), NAN, Callable(), {Vector2(1, 2): 1}, fundo, [INF],
			{"a": Transform3D()}]:
		_check(not FusaoDeMundo.valor_limpo(sujo), "valor sujo recusado: %s" % type_string(typeof(sujo)))
	_check(FusaoDeMundo.valor_limpo(base) and FusaoDeMundo.valor_limpo(ra), "dado de jogo passa")


# --- Validador pelas familias ---------------------------------------------------------------

func _validador_familias() -> void:
	_secao("validador: familias, comodo e casa da rua")
	var p := Vector2i(123, 424243)
	_check(ValidadorDeMundo.julgar(p, &"profissao", &"fazendeiro", _rua()) == M.OK, "profissao, de qualquer lugar")
	_check(ValidadorDeMundo.julgar(p, &"profissao", "fazendeiro", _interior()) == M.OK,
		"profissao como String (save em JSON)")
	_check(ValidadorDeMundo.julgar(p, &"profissao", 3, _rua()) == M.INVALIDO, "profissao com numero")
	_check(ValidadorDeMundo.julgar(p, &"funcoes", ["fazendeiro"], _rua()) == M.OK, "funcoes em lista")
	_check(ValidadorDeMundo.julgar(p, &"funcoes", [RefCounted.new()], _rua()) == M.INVALIDO,
		"objeto dentro da lista")
	var enorme: Array = []
	enorme.resize(PoliticaDeMundo.TETO_ESTRUTURA)
	enorme.fill("xxxxxxxx")
	_check(ValidadorDeMundo.julgar(p, &"funcoes", enorme, _rua()) == M.INVALIDO, "lista acima do teto")
	_check(ValidadorDeMundo.julgar(Vector2i(0, 424244), &"fazendeiro", [4, 9], _rua()) == M.OK, "folha de vagas")
	for pessoal: Array in [[p, &"npc_role", true], [p, &"dono_pagou", true],
			[Vector2i(-10, 424245), &"mao", {}], [Vector2i(-7, 424243), &"pendentes", 3],
			[Vector2i(77551, 424242), &"falou_chegada", true], [p, &"personagem", &"helmer"]]:
		_check(ValidadorDeMundo.julgar(pessoal[0], pessoal[1], pessoal[2], _rua()) == M.INVALIDO,
			"%s e da pessoa ou local: o servidor nao aceita" % pessoal[1])

	# Fusao pela prateleira.
	var loja := Vector2i(-10, 424245)
	var base := {"vagas": {"1": {"sku": "arroz", "colunas": [3]}}}
	var novo := {"vagas": {"1": {"sku": "arroz", "colunas": [2]}}}
	var remendo := FusaoDeMundo.diferenca(base, novo)
	var r := ValidadorDeMundo.julgar_fusao(loja, &"loja_1", remendo, base, _rua())
	_check(r[0] == M.OK and r[1] == novo, "fusao na prateleira: %s" % [r])
	_check(ValidadorDeMundo.julgar_fusao(loja, &"mao", remendo, base, _rua())[0] == M.INVALIDO,
		"fusao em chave pessoal")
	_check(ValidadorDeMundo.julgar_fusao(Vector2i.ZERO, &"porta_1_1_1", remendo, null, _rua())[0] == M.INVALIDO,
		"fusao em chave que troca inteira")
	_check(ValidadorDeMundo.julgar_fusao(loja, &"loja_1", {"p": 5}, base, _rua())[0] == M.INVALIDO,
		"remendo torto")
	_check(ValidadorDeMundo.julgar_fusao(loja, &"loja_1", {"p": {"x": RefCounted.new()}}, base, _rua())[0]
		== M.INVALIDO, "remendo com objeto")
	var np := _rua()
	np["pronto"] = false
	_check(ValidadorDeMundo.julgar_fusao(loja, &"lixo", 3, null, np)[0] == M.NAO_PRONTO, "fusao: NAO_PRONTO primeiro")
	var sc := _rua()
	sc["cota"] = false
	_check(ValidadorDeMundo.julgar_fusao(loja, &"lixo", 3, null, sc)[0] == M.COTA, "fusao: cota em segundo")

	# Comodo: QUAL interior, pelo tipo e pela semente.
	var fumaca := Vector2i(77551, 424242)
	var na_estufa := {"pronto": true, "espaco": ProtocoloRede.espaco_interior(&"estufa", 77551),
		"pos": Vector3(0, 2000, 0)}
	var no_bar := {"pronto": true, "espaco": ProtocoloRede.espaco_interior(&"bar", 77551),
		"pos": Vector3(0, 2000, 0)}
	var em_outra := {"pronto": true, "espaco": ProtocoloRede.espaco_interior(&"estufa", 99999),
		"pos": Vector3(0, 2000, 0)}
	var r2 := ValidadorDeMundo.julgar_fusao(fumaca, &"plantio", FusaoDeMundo.diferenca(null, {"regador": 2}),
		null, na_estufa)
	_check(r2[0] == M.OK, "plantio de dentro da estufa daquela semente")
	_check(ValidadorDeMundo.julgar(fumaca, &"porta_1_2_3", true, no_bar) == M.OK, "o bar daquela semente")
	_check(ValidadorDeMundo.julgar(fumaca, &"porta_1_2_3", true, em_outra) == M.ESPACO,
		"estufa de OUTRA semente nao mexe nesta")
	var falso := {"pronto": true, "espaco": 777, "pos": Vector3(0, 2000, 0)}
	_check(ValidadorDeMundo.julgar(fumaca, &"porta_1_2_3", true, falso) == M.ESPACO,
		"espaco inventado nao passa")
	# Casa que existe na rua: o jogador esta na RUA.
	var na_calcada := _rua()
	na_calcada["casas_perto"] = [11, 77551]
	_check(ValidadorDeMundo.julgar_item(fumaca, 2, true, 1, na_calcada, false) == M.OK,
		"item da casa que existe na rua, com a casa perto")
	_check(ValidadorDeMundo.julgar_item(fumaca, 2, true, 1, _rua(), false) == M.ESPACO,
		"item de comodo pedido da rua sem casa perto")
	var longe := _rua()
	longe["casas_perto"] = [11]
	_check(ValidadorDeMundo.julgar_item(fumaca, 2, true, 1, longe, false) == M.ESPACO, "casa de outra semente")
	var torto := _rua()
	torto["casas_perto"] = "77551"
	_check(ValidadorDeMundo.julgar_item(fumaca, 2, true, 1, torto, false) == M.ESPACO, "casas_perto torto")
	for t: StringName in [&"apartamento", &"casa", &"mercado", &"casa_fumaca", &"estufa", &"bar"]:
		_check(ProtocoloRede.TIPOS_DE_INTERIOR.has(t), "tipo de interior conhecido: %s" % t)


# --- Disputa de item ------------------------------------------------------------------------

func _disputa() -> void:
	_secao("disputa: quem agiu antes leva")
	# O anfitriao aperta em 1,000 s e o pedido chega na hora. O convidado apertou
	# em 0,990 s, com 80 ms de ida e volta: chega em 1,030 s. Ele agiu antes.
	var anf := {"id": 1, "instante": 1.000, "chegada": 1.000}
	var conv := {"id": 55, "instante": 1.030 - 0.040, "chegada": 1.030}
	var o := ValidadorDeMundo.ordem_da_disputa([anf, conv])
	_check(int(o[0]["id"]) == 55, "o convidado que agiu antes leva, mesmo chegando depois")
	var tarde := {"id": 55, "instante": 1.080 - 0.040, "chegada": 1.080}
	_check(int(ValidadorDeMundo.ordem_da_disputa([tarde, anf])[0]["id"]) == 1, "quem agiu depois perde")
	var igual_a := {"id": 9, "instante": 2.0, "chegada": 2.05}
	var igual_b := {"id": 7, "instante": 2.0, "chegada": 2.01}
	_check(int(ValidadorDeMundo.ordem_da_disputa([igual_a, igual_b])[0]["id"]) == 7, "empate: quem chegou antes")
	var c1 := {"id": 9, "instante": 3.0, "chegada": 3.0}
	var c2 := {"id": 4, "instante": 3.0, "chegada": 3.0}
	_check(int(ValidadorDeMundo.ordem_da_disputa([c1, c2])[0]["id"]) == 4, "empate total: menor id")
	var lista := [anf, conv]
	ValidadorDeMundo.ordem_da_disputa(lista)
	_check(int(lista[0]["id"]) == 1, "ordenar nao mexe na lista de quem chama")
