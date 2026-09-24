## O mundo compartilhado: pedidos de mudanca, revisao e a carga de entrada.
## Filho da `Sessao` (/root/Sessao/Mundo), pelo mesmo motivo dela: RPC acha o no
## pelo caminho, e so um autoload tem o mesmo caminho no jogo, no bot e no
## dedicado.
##
## Duas classes de interacao passam por aqui (plano 04 secao 4.1):
##   classe 2, preve  `mudar`: o efeito ja aconteceu no no; o pedido vai junto e,
##                    se o servidor negar, a chave volta ao valor dele
##   classe 1, espera `pedir_item`: o gesto toca ja, o item so some quando o
##                    servidor confirma — dois no mesmo tick, um leva
##
## Em SOLO nada disto roda: `mudar` e o `WorldState.definir` de sempre (P16).
##
## Plano: MULTIPLAYER/PLANO/04_CONTRATO_DE_REDE.md, secoes 4 a 7.
class_name MundoEmRede
extends Node

signal carregado()
## O servidor recusou um pedido desta maquina. Para o bot de teste e para quem
## quiser explicar a recusa na tela.
signal negado(motivo: int)

## Canal ENet da carga de entrada. No canal 0 ela travaria chat e eventos atras
## do ultimo pedaco: o canal confiavel do ENet e ordenado (plano 04 secao 1).
const CANAL_CARGA := 2
## Sem resposta do servidor por tanto tempo, o pedido de item desiste.
const TEMPO_RESPOSTA := 5.0
## Previsao (classe 2) sem resposta por tanto tempo volta ao valor do servidor.
## Dois motivos: o servidor CALA de proposito quem estourou a cota (plano 04
## secao 6), e sem prazo a porta prevista ficaria aberta para sempre so na tela
## de quem a abriu; e uma previsao pendente para sempre e um vazamento.
const PRAZO_PREVISAO := 6.0

## Disputa de item (a "vantagem do anfitriao"): o pedido do anfitriao chega na
## hora e o do convidado paga meia ida e volta, entao no empate o anfitriao
## levaria sempre. O servidor segura o PRIMEIRO pedido de um item por meia ida
## e volta do convidado mais lento (no maximo isto), e quem agiu antes, na hora
## em que agiu, leva. A hora e estimada pelo ping que o SERVIDOR mede, nunca por
## relogio do cliente. Em rede local a janela e zero.
const JANELA_MAX := 0.15
## O mapa e do grupo (plano 13 item 3.11): cada um manda os chunks que pisou, em
## lote, e o servidor espalha. Dez segundos e o bastante para o mapa do amigo
## acompanhar sem virar trafego de posicao.
const LOTE_VISITADOS := 10.0
## Coordenadas por lote. Andar a pe ou de carro nao chega perto; o teto e contra
## cliente adulterado que manda a cidade inteira de uma vez.
const TETO_VISITADOS := 1024

# --- servidor ---
var _rev: int = 0
## "cx,cz|indice" -> {"fecha": t, "candidatos": [{id, seq, coord, indice, item, qtd,
## instante, chegada, cb}]}
var _disputas: Dictionary = {}
## coord de chunk -> sementes das casas que existem na rua nele (o mapa e puro).
var _casas_do_chunk: Dictionary = {}
## Chaves sem politica ja avisadas no console ("faixa|chave").
var _avisadas: Dictionary = {}
## Visitados que o grupo ja conhece (mandados daqui ou recebidos de la).
var _visitados_mandados: Dictionary = {}
var _t_visitados := 0.0
## id -> true depois que a carga saiu. Pedido antes disso cai calado (secao 6).
var _prontos: Dictionary = {}
var _baldes: Dictionary = {}

# --- cliente ---
var _espelho := EspelhoDeMundo.new()
var _montagem := CargaDeMundo.Montagem.new()
var _seq: int = 0
## seq -> {"item", "qtd", "cb", "t"}: pedidos de item esperando o servidor.
var _esperas: Dictionary = {}
## seq -> hora do pedido: previsoes esperando resposta (ver PRAZO_PREVISAO).
var _previstas: Dictionary = {}
## O mundo desta maquina antes de entrar: [mundo, visitados]. Volta quando a
## sessao acaba (P11: cada um continua no proprio mundo) e e o que o orelhao
## grava enquanto se joga no mundo de outro (P9).
var _mundo_proprio: Array = []
var _trocado := false
var _t_carga := -1.0
## Para o teste: {"bytes", "partes", "ms", "rev"} da ultima carga recebida.
var ultima_carga: Dictionary = {}


func _ready() -> void:
	WorldState.rede = _ao_definir


func _exit_tree() -> void:
	if WorldState.rede == Callable(self, &"_ao_definir"):
		WorldState.rede = Callable()


func _process(delta: float) -> void:
	if not _disputas.is_empty():
		_fechar_disputas(false)
	if Sessao.em_rede() and pronto():
		_t_visitados += delta
		if _t_visitados >= LOTE_VISITADOS:
			_t_visitados = 0.0
			_mandar_visitados()
	if _esperas.is_empty() and _previstas.is_empty():
		return
	var agora := _agora()
	for seq: int in _esperas.keys():
		if agora - float((_esperas[seq] as Dictionary)["t"]) > TEMPO_RESPOSTA:
			_responder(seq, false, ValidadorDeMundo.Motivo.INVALIDO)
	for seq: int in _previstas.keys():
		if agora - float(_previstas[seq]) > PRAZO_PREVISAO:
			_previstas.erase(seq)
			var escritas := _espelho.negado(seq)
			if not escritas.is_empty():
				push_warning("[sessao] o servidor nao respondeu a mudanca %d; o mundo volta ao dele" % seq)
				_aplicar_escritas(escritas)


# --- API (pela Sessao) --------------------------------------------------------------

## Pode mexer no mundo agora. O cliente espera a carga de entrada: antes dela
## abriria uma porta que o servidor ja sabe aberta.
func pronto() -> bool:
	if not Sessao.em_rede() or Sessao.eh_servidor():
		return true
	return Sessao.modo == Sessao.Modo.CLIENTE and _espelho.carregado


## Classe 2. O efeito ja aconteceu no no que chama; aqui ele vira mundo.
## `padrao` e o valor da chave quando ela nunca foi escrita (porta fechada =
## false): e para ele que a chave volta se o servidor negar.
func mudar(coord: Vector2i, chave: StringName, valor: Variant, padrao: Variant = null) -> void:
	if not Sessao.em_rede():
		WorldState.definir_local(coord, chave, valor)
		return
	if Sessao.eh_servidor():
		_aplicar_pedido(Sessao.meu_id, 0, coord, chave, valor, padrao)
		return
	if not pronto():
		return
	var anterior: Variant = WorldState.obter(coord, chave, padrao)
	var fundir := bool(PoliticaDeMundo.regra(coord, chave)["fundir"])
	var remendo := {}
	if fundir:
		remendo = FusaoDeMundo.diferenca(anterior, valor if valor is Dictionary else {})
		if FusaoDeMundo.vazio(remendo):
			WorldState.definir_local(coord, chave, valor)
			return
	_seq += 1
	_espelho.prever(coord.x, coord.y, chave, valor, anterior, _seq)
	_previstas[_seq] = _agora()
	WorldState.definir_local(coord, chave, valor)
	if fundir:
		_pedir_fusao.rpc_id(1, _seq, coord.x, coord.y, chave, remendo)
	else:
		_pedir_mundo.rpc_id(1, _seq, coord.x, coord.y, chave, valor)


## O caminho de TODA escrita do WorldState em rede (`WorldState.rede`). Devolve
## verdadeiro quando tomou conta dela; falso deixa o WorldState gravar so aqui.
## Plano 13 item 3.4: os sistemas do jogo continuam chamando `definir`.
func _ao_definir(coord: Vector2i, chave: StringName, valor: Variant) -> bool:
	if not Sessao.em_rede():
		return false
	var regra := PoliticaDeMundo.regra(coord, chave)
	match int(regra["dono"]):
		PoliticaDeMundo.Dono.MUNDO:
			# Item so muda por `pedir_item` (classe 1). Quem grava item direto em
			# rede esta no caminho de solo por engano: fica so aqui, e avisa.
			if String(chave).begins_with(ValidadorDeMundo.PREFIXO_SO_POR_PEDIDO):
				_avisar_uma_vez(coord, chave, "item gravado direto em rede; use Sessao.pedir_item")
				return false
			# Antes de a carga chegar o cliente escreveria no mundo velho: fica
			# local, e a carga a substitui.
			if not pronto():
				return false
			mudar(coord, chave, valor, WorldState.obter(coord, chave, null))
			return true
		PoliticaDeMundo.Dono.LOCAL:
			if not bool(regra["conhecida"]):
				_avisar_uma_vez(coord, chave, "chave sem politica de rede; fica so nesta maquina")
	return false


func _avisar_uma_vez(coord: Vector2i, chave: StringName, texto: String) -> void:
	var k := "%d|%s" % [ValidadorDeMundo.faixa(coord), chave]
	if _avisadas.has(k):
		return
	_avisadas[k] = true
	push_warning("[mundo] %s: (%d, %d) %s. Ver PoliticaDeMundo." % [texto, coord.x, coord.y, chave])


## Classe 1: pegar um item do chao. `ao_responder(ok: bool, motivo: int)` e
## chamado quando o servidor decide (ou quando desiste de esperar). Com `ok`, o
## item ja esta na mochila: quem credita e este no, e nao o `ItemNoChao` — o
## chunk pode descarregar no meio da espera, e o item continua sendo de quem
## pediu.
func pedir_item(coord: Vector2i, indice: int, item: StringName, qtd: int,
		ao_responder: Callable = Callable()) -> void:
	if Sessao.eh_servidor():
		_entrar_na_disputa(Sessao.meu_id, 0, coord, indice, item, qtd, ao_responder)
		return
	if not pronto():
		if ao_responder.is_valid():
			ao_responder.call(false, ValidadorDeMundo.Motivo.NAO_PRONTO)
		return
	_seq += 1
	_esperas[_seq] = {"item": item, "qtd": qtd, "cb": ao_responder, "t": _agora()}
	_pedir_item.rpc_id(1, _seq, coord.x, coord.y, indice, item, qtd)


## A quantidade inteira cabe na mochila. Em rede o item e pego inteiro ou nao e
## pego: a chave do mundo e um booleano, e "pegou dois de tres" viraria o
## terceiro sumindo do mundo sem entrar em mochila nenhuma.
static func cabe(id: StringName, qtd: int) -> bool:
	var item := Inventario.definicao(id)
	if item == null or qtd < 1:
		return false
	var pilha := item.max_pilha if item.e_empilhavel() else 1
	var resta := qtd
	for e: Dictionary in Inventario.espacos:
		if e.is_empty():
			resta -= pilha
		elif item.e_empilhavel() and (e["item"] as Item).id == id:
			resta -= item.max_pilha - int(e["qtd"])
		if resta <= 0:
			return true
	return resta <= 0


## O mundo que o save desta maquina grava: o proprio, mesmo jogando no de
## outro (P9 — o convidado nao grava o mundo do anfitriao).
func para_salvar() -> Array:
	if _trocado and _mundo_proprio.size() == 2:
		# O mapa grava tudo o que ele viu, inclusive no mundo do amigo: a rua e a
		# mesma cidade, e esquecer o bairro que se andou junto seria perder mapa.
		return [_mundo_proprio[0], _unir_visitados(_mundo_proprio[1], WorldState.visitados_para_lista())]
	return [WorldState.para_dicionario(), WorldState.visitados_para_lista()]


static func _unir_visitados(a: Variant, b: Variant) -> PackedStringArray:
	var d := {}
	for lista: Variant in [a, b]:
		if lista is PackedStringArray or lista is Array:
			for k: Variant in lista:
				d[String(k)] = true
	return PackedStringArray(d.keys())


# --- ciclo da sessao (chamado pela Sessao) --------------------------------------------

## Cliente, antes de ligar.
func antes_de_entrar() -> void:
	_zerar_cliente()
	_mundo_proprio = []


## A sessao acabou. Quem jogava no mundo de outro volta ao proprio (P11), com o
## estado pessoal que tem AGORA — a carteira gasta na sessao continua gasta.
func ao_sair() -> void:
	for seq: int in _esperas.keys():
		_responder(seq, false, ValidadorDeMundo.Motivo.NAO_PRONTO)
	if _trocado and _mundo_proprio.size() == 2:
		var meu: Dictionary = _mundo_proprio[0]
		_trocar_mundo(_com_pessoais_de_agora(meu),
			_unir_visitados(_mundo_proprio[1], WorldState.visitados_para_lista()))
	_zerar_cliente()
	_mundo_proprio = []


func zerar() -> void:
	_rev = 0
	_prontos.clear()
	_baldes.clear()
	# Quem esperava a disputa ouve "nao deu": a sessao acabou no meio.
	for k: String in _disputas:
		for c: Dictionary in (_disputas[k] as Dictionary)["candidatos"]:
			var cb: Callable = c["cb"]
			if cb.is_valid():
				cb.call(false, ValidadorDeMundo.Motivo.NAO_PRONTO)
	_disputas.clear()
	_zerar_cliente()


func esquecer(id: int) -> void:
	_prontos.erase(id)
	_baldes.erase(id)


## Servidor: o mundo inteiro mudou de uma vez (o anfitriao carregou um save no
## meio da sessao). Quem ja estava dentro recebe o mundo de novo, pelo mesmo
## canal da entrada; o espelho de cada um sabe que e recarga.
func recarregar_todos() -> void:
	for id: int in _prontos.keys():
		enviar_carga(id)


## O WorldState foi trocado por fora (save carregado), sem `mudou`: a porta e o
## item que ja estao na cena ainda mostram o mundo velho. A porta le o mundo e
## assenta sem animar; o item que o mundo novo diz pego some. O item que o mundo
## novo diz NAO pego e ja sumiu desta cena volta quando o chunk remontar.
func ressincronizar_cena() -> void:
	if not is_inside_tree():
		return
	get_tree().call_group(&"porta", &"_sincronizar", true)
	for n: Node in get_tree().get_nodes_in_group(&"item_no_chao"):
		var it := n as ItemNoChao
		if it != null and bool(WorldState.obter(it.chunk, it.chave(), false)):
			it.call(&"_sumir")


## Cliente: o mundo desta maquina deixou de ser o do anfitriao por decisao do
## jogador (carregou o proprio save). Nao ha mais mundo proprio a devolver na
## saida: o que esta no WorldState agora E o dele.
func largar_mundo_do_anfitriao() -> void:
	_trocado = false
	_mundo_proprio = []


## Servidor: manda o mundo inteiro a quem acabou de entrar, no canal 2.
func enviar_carga(id: int) -> void:
	var t0 := Time.get_ticks_usec()
	var partes := CargaDeMundo.empacotar(PoliticaDeMundo.sem_pessoais(WorldState.para_dicionario()),
		WorldState.visitados_para_lista())
	var total := 0
	for i in partes.size():
		total += partes[i].size()
		_estado_de_mundo.rpc_id(id, _rev, i, partes.size(), partes[i])
	_prontos[id] = true
	print("[servidor] mundo para peer %d: %.1f KB em %d parte(s), rev %d, %d chunks alterados (%d ms)" % [
		id, total / 1024.0, partes.size(), _rev, WorldState.chunks_alterados(),
		(Time.get_ticks_usec() - t0) / 1000])


## Enche o mundo do servidor com `n` chunks alterados de mentira, com a cara de
## uma tarde de jogo (itens pegos, falas ditas, portas). So para medir a carga.
static func preencher_sintetico(n: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in n:
		var coord := Vector2i(rng.randi_range(-60, 60), rng.randi_range(-60, 60))
		WorldState.definir(coord, StringName("item_%d" % rng.randi_range(0, 11)), true)
		if rng.randf() < 0.4:
			WorldState.definir(coord, ChaveMundo.de_posicao(
				Vector3(rng.randf_range(0, 32), rng.randf_range(-5, 5), rng.randf_range(0, 32))), true)
		if rng.randf() < 0.3:
			WorldState.definir(Vector2i(rng.randi_range(1, 99999), 424243),
				StringName("npc_fala_%d" % rng.randi_range(0, 30)), true)
		WorldState.visitar(coord)


# --- RPC: cliente -> servidor ------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable", 0)
func _pedir_mundo(seq: int, cx: int, cz: int, chave: StringName, valor: Variant) -> void:
	if not multiplayer.is_server():
		return
	_aplicar_pedido(multiplayer.get_remote_sender_id(), seq, Vector2i(cx, cz), chave, valor, null)


@rpc("any_peer", "call_remote", "reliable", 0)
func _pedir_item(seq: int, cx: int, cz: int, indice: int, item: StringName, qtd: int) -> void:
	if not multiplayer.is_server():
		return
	_entrar_na_disputa(multiplayer.get_remote_sender_id(), seq, Vector2i(cx, cz), indice, item,
		qtd, Callable())


## Um lote de chunks visitados de um jogador: [x0, z0, x1, z1, ...].
@rpc("any_peer", "call_remote", "reliable", 0)
func _pedir_visitados(lote: PackedInt32Array) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if not _prontos.has(id) or not _dentro_da_cota(id):
		return
	if lote.size() % 2 != 0 or lote.size() > TETO_VISITADOS * 2:
		return
	_espalhar_visitados(id, lote)


## Mudanca por diferenca (prateleira, plantio): ver `FusaoDeMundo`.
@rpc("any_peer", "call_remote", "reliable", 0)
func _pedir_fusao(seq: int, cx: int, cz: int, chave: StringName, remendo: Variant) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	var coord := Vector2i(cx, cz)
	var r := ValidadorDeMundo.julgar_fusao(coord, chave, remendo,
		WorldState.obter(coord, chave, null), _quem(id, coord))
	var m := int(r[0])
	if m != ValidadorDeMundo.Motivo.OK:
		if not m in ValidadorDeMundo.SILENCIOSOS:
			_negado.rpc_id(id, seq, m)
		return
	_difundir(id, seq, coord, chave, r[1])


# --- RPC: servidor -> cliente ------------------------------------------------------------

@rpc("authority", "call_remote", "reliable", 0)
func _mundo_mudou(rev: int, cx: int, cz: int, chave: StringName, valor: Variant,
		autor: int, seq: int) -> void:
	var eu := multiplayer.get_unique_id()
	_aplicar_escritas(_espelho.receber({"rev": rev, "cx": cx, "cz": cz, "chave": chave,
		"valor": valor, "autor": autor, "seq": seq}, eu))
	if autor == eu:
		_previstas.erase(seq)
	if autor == eu and _esperas.has(seq):
		var e: Dictionary = _esperas[seq]
		_creditar(StringName(e["item"]), int(e["qtd"]))
		_responder(seq, true, ValidadorDeMundo.Motivo.OK)


@rpc("authority", "call_remote", "reliable", 0)
func _visitados_novos(lote: PackedInt32Array) -> void:
	_visitar_lote(lote)


@rpc("authority", "call_remote", "reliable", 0)
func _negado(seq: int, motivo: int) -> void:
	_previstas.erase(seq)
	_aplicar_escritas(_espelho.negado(seq))
	if _esperas.has(seq):
		_responder(seq, false, motivo)
	negado.emit(motivo)


@rpc("authority", "call_remote", "reliable", CANAL_CARGA)
func _estado_de_mundo(rev: int, parte: int, total: int, dados: PackedByteArray) -> void:
	if Sessao.modo != Sessao.Modo.CONECTANDO and Sessao.modo != Sessao.Modo.CLIENTE:
		return
	# Com o espelho ja carregado, isto e uma RECARGA: o anfitriao carregou um
	# save. O mundo proprio desta maquina ja foi fotografado na primeira carga.
	var recarga := _espelho.carregado
	if _t_carga < 0.0:
		_t_carga = _agora()
	# Canais diferentes nao tem ordem entre si: um pedaco pode chegar antes das
	# boas-vindas (canal 0). Por isso a carga se fecha sozinha, pelo ultimo
	# pedaco, e nao por uma mensagem de "pronto" no canal 0 — que poderia chegar
	# antes dos dados que anuncia.
	if not _montagem.receber(rev, parte, total, dados):
		return
	var v := CargaDeMundo.desempacotar(_montagem.partes())
	if v.is_empty():
		push_error("[sessao] o mundo do servidor chegou quebrado")
		Sessao.sair("O mundo do servidor chegou quebrado. Voce continua sozinho aqui.")
		return
	var bytes := 0
	for p: PackedByteArray in _montagem.partes():
		bytes += p.size()
	var recebido: Dictionary = v[0]
	if not recarga:
		# O mundo desta maquina e fotografado AGORA, e nao ao ligar: entre um e
		# outro o jogador continuou andando (e pegando) no proprio mundo.
		_mundo_proprio = [WorldState.para_dicionario().duplicate(true),
			WorldState.visitados_para_lista()]
	# O mapa de quem entra e a uniao: o bairro que o anfitriao ja andou aparece, e
	# o que este jogador andou sozinho continua la (e vai para o grupo no lote).
	var mapa := _unir_visitados(v[1], WorldState.visitados_para_lista())
	_trocar_mundo(_com_pessoais_de_agora(recebido), mapa)
	for k: String in (v[1] as PackedStringArray):
		var c: Variant = PoliticaDeMundo.coord_de_texto(k)
		if c != null:
			_visitados_mandados[c] = true
	_trocado = true
	if recarga:
		_aplicar_escritas(_espelho.recarga_concluida(rev, multiplayer.get_unique_id()))
		Sessao.avisar_local("O anfitriao carregou outro jogo. O mundo foi atualizado.")
	else:
		_aplicar_escritas(_espelho.concluir_carga(rev, multiplayer.get_unique_id()))
	if _espelho.transbordou:
		# Mais mudancas durante a carga do que o espelho guarda. Jogar assim e
		# jogar num mundo meio errado, e nao ha como pedir a carga de novo.
		Sessao.sair("O mundo mudou demais enquanto voce entrava. Tente de novo.")
		return
	ultima_carga = {"bytes": bytes, "partes": total, "rev": rev,
		"ms": roundi((_agora() - _t_carga) * 1000.0)}
	_montagem.zerar()
	print("[sessao] mundo do servidor carregado: %.1f KB em %d parte(s), %d ms" % [
		bytes / 1024.0, total, int(ultima_carga["ms"])])
	carregado.emit()


# --- servidor ------------------------------------------------------------------------------

## O que o servidor sabe de quem pediu. A ficha da cota e gasta AQUI, antes de
## julgar: pedido invalido ou de longe tem de gastar ficha tambem, senao quem
## manda lixo em rajada nunca e calado e ganha um eco de graca (plano 04 secao 6,
## conferencia 2).
func _quem(id: int, coord := Vector2i(0, -1)) -> Dictionary:
	var e: Dictionary = Sessao.estado_aceito(id)
	var espaco: Variant = e.get("espaco", -1)
	var pos: Variant = e.get("pos", Vector3.INF)
	var q := {
		"pronto": id == Sessao.meu_id or _prontos.has(id),
		"cota": _dentro_da_cota(id),
		"espaco": int(espaco) if typeof(espaco) == TYPE_INT else -1,
		"pos": pos if typeof(pos) == TYPE_VECTOR3 else Vector3.INF,
	}
	# Coisa de comodo pedida da rua: vale se a casa que existe na rua estiver perto.
	if coord.y == PoliticaDeMundo.INTERIOR and int(q["espaco"]) == ProtocoloRede.ESPACO_RUA:
		q["casas_perto"] = _casas_perto(q["pos"])
	return q


## As sementes das casas da rua nos 3x3 chunks em volta de `pos`. O mapa e funcao
## pura da coordenada (`ChunkBuilder.pontos_de_interesse`), e o dedicado, que nao
## monta cidade, sabe o mesmo que o jogo. Guardado por chunk: a cidade nao muda.
func _casas_perto(pos: Vector3) -> Array:
	var saida: Array = []
	if not (is_finite(pos.x) and is_finite(pos.z)):
		return saida
	var c0 := ChaveMundo.coord_da_rua(pos)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var c := c0 + Vector2i(dx, dz)
			if not _casas_do_chunk.has(c):
				var sementes: Array = []
				for p: Dictionary in ChunkBuilder.pontos_de_interesse(c.x, c.y):
					if p.has("semente"):
						sementes.append(int(p["semente"]))
				_casas_do_chunk[c] = sementes
			saida.append_array(_casas_do_chunk[c])
	return saida


func _dentro_da_cota(id: int) -> bool:
	if id == Sessao.meu_id:
		return true
	if not _baldes.has(id):
		_baldes[id] = ValidadorDeMundo.Balde.new()
	return (_baldes[id] as ValidadorDeMundo.Balde).gastar(_agora())


func _aplicar_pedido(id: int, seq: int, coord: Vector2i, chave: StringName,
		valor: Variant, padrao: Variant) -> void:
	if id == Sessao.meu_id and not String(chave).begins_with("porta_"):
		# O anfitriao e a autoridade: o que o jogo DELE grava (contratar, plantar,
		# tirar da prateleira) e verdade, e so falta difundir. A porta ainda passa
		# pelo julgamento, que e o mesmo do convidado e ja tem teste.
		_difundir(id, seq, coord, chave, valor)
		return
	var m := ValidadorDeMundo.julgar(coord, chave, valor, _quem(id, coord))
	if m != ValidadorDeMundo.Motivo.OK:
		if id == Sessao.meu_id:
			# O anfitriao ja mexeu no no. Nao ha pedido para negar: o no volta ao
			# valor do mundo pelo mesmo sinal que moveria a porta de um cliente.
			WorldState.mudou.emit(coord, chave, WorldState.obter(coord, chave, padrao))
		elif not m in ValidadorDeMundo.SILENCIOSOS:
			_negado.rpc_id(id, seq, m)
		return
	_difundir(id, seq, coord, chave, valor)


func _julgar_item(id: int, seq: int, coord: Vector2i, indice: int, item: StringName,
		qtd: int) -> int:
	var chave := StringName("item_%d" % indice)
	# A mochila do remetente so se confere quando ela esta nesta maquina, que e o
	# caso do anfitriao. A do cliente vira `MochilaDoServidor` na 3.8; ate la ele
	# confere antes de pedir (`Sessao.cabe_na_mochila`), e o servidor confia.
	var cabe := id != Sessao.meu_id or MundoEmRede.cabe(item, qtd)
	var quem := _quem(id, coord)
	if id == Sessao.meu_id:
		# O anfitriao pode pedir antes de o proprio estado ser aceito (primeiros
		# quadros, logo depois de um teletransporte): o lugar dele nao se confere.
		quem["espaco"] = ProtocoloRede.ESPACO_RUA
		quem["pos"] = Vector3((coord.x + 0.5) * ValidadorDeMundo.CHUNK, 0.0,
			(coord.y + 0.5) * ValidadorDeMundo.CHUNK)
		quem["casas_perto"] = [coord.x]
	var m := ValidadorDeMundo.julgar_item(coord, indice, Inventario.definicao(item) != null,
		qtd, quem, bool(WorldState.obter(coord, chave, false) == true), cabe)
	if m != ValidadorDeMundo.Motivo.OK:
		if id != Sessao.meu_id and not m in ValidadorDeMundo.SILENCIOSOS:
			_negado.rpc_id(id, seq, m)
		return m
	_difundir(id, seq, coord, chave, true)
	return m


## Aceito: vira mundo aqui e em todo mundo, com a revisao nova. Vai tambem para
## quem esta no meio da carga — o espelho dele guarda e descarta o que ja veio
## dentro da fotografia (plano 04 secao 4.4).
func _difundir(id: int, seq: int, coord: Vector2i, chave: StringName, valor: Variant) -> void:
	WorldState.definir_local(coord, chave, valor)
	_rev += 1
	for destino: int in Sessao.destinos():
		_mundo_mudou.rpc_id(destino, _rev, coord.x, coord.y, chave, valor, id, seq)


# --- cliente -------------------------------------------------------------------------------

func _aplicar_escritas(escritas: Array) -> void:
	for w: Dictionary in escritas:
		var c := Vector2i(int(w["cx"]), int(w["cz"]))
		# Voltar para "nunca escrita" e apagar, e nao gravar null: quem le com
		# padrao (`obter(c, k, 0)`) receberia null e quebraria no int().
		if w["valor"] == null:
			WorldState.apagar_local(c, StringName(w["chave"]))
		else:
			WorldState.definir_local(c, StringName(w["chave"]), w["valor"])


func _responder(seq: int, ok: bool, motivo: int) -> void:
	if not _esperas.has(seq):
		return
	var cb: Callable = (_esperas[seq] as Dictionary)["cb"]
	_esperas.erase(seq)
	if not ok and motivo != ValidadorDeMundo.Motivo.NAO_PRONTO:
		Sessao.recado.emit(ValidadorDeMundo.texto(motivo))
	if cb.is_valid():
		cb.call(ok, motivo)


func _creditar(item: StringName, qtd: int) -> void:
	var sobra := Inventario.adicionar(item, qtd)
	if sobra > 0:
		# A mochila encheu entre o pedido e a confirmacao (pegou outra coisa no
		# meio). O item ja e dele no mundo; largar o resto no chao e o
		# `_pedir_largar` da Fase 3.8. Ate la, o resto se perde — e fica no log.
		push_warning("[sessao] %d x %s nao couberam na mochila depois da confirmacao" % [sobra, item])


## Troca o mundo desta maquina e avisa os nos vivos do que mudou: a porta aberta
## no servidor abre aqui, o item ja pego some. Chave que existia e deixou de
## existir chega como `null`, e quem ouve le `null` como "nunca mexido".
func _trocar_mundo(novo: Dictionary, visitados: Variant) -> void:
	var velho := WorldState.para_dicionario()
	WorldState.de_dicionario(novo)
	WorldState.visitados_de_lista(Array(visitados) if visitados is PackedStringArray else [])
	var chaves := {}
	for k: String in velho:
		chaves[k] = true
	for k: String in novo:
		chaves[k] = true
	for k: String in chaves:
		var partes := k.split(",")
		if partes.size() != 2:
			continue
		var coord := Vector2i(int(partes[0]), int(partes[1]))
		var a: Dictionary = velho.get(k, {})
		var b: Dictionary = novo.get(k, {})
		for chave: Variant in _uniao(a.keys(), b.keys()):
			var va: Variant = a.get(chave, null)
			var vb: Variant = b.get(chave, null)
			if typeof(va) != typeof(vb) or va != vb:
				WorldState.mudou.emit(coord, StringName(chave), vb)


static func _uniao(a: Array, b: Array) -> Array:
	var d := {}
	for x: Variant in a:
		d[x] = true
	for x: Variant in b:
		d[x] = true
	return d.keys()


## `mundo` com o estado pessoal desta maquina como ele esta agora: o que e da
## pessoa no `mundo` sai, e entra o de agora (a carteira gasta na sessao continua
## gasta, a conversa ouvida continua ouvida).
static func _com_pessoais_de_agora(mundo: Dictionary) -> Dictionary:
	var meus := PoliticaDeMundo.so_pessoais(WorldState.para_dicionario()).duplicate(true)
	return PoliticaDeMundo.juntar(PoliticaDeMundo.sem_pessoais(mundo), meus)


# --- mapa do grupo --------------------------------------------------------------------

func _mandar_visitados() -> void:
	var lote := PackedInt32Array()
	for c: Vector2i in WorldState.coords_visitadas():
		if _visitados_mandados.has(c):
			continue
		_visitados_mandados[c] = true
		lote.append(c.x)
		lote.append(c.y)
		if lote.size() >= TETO_VISITADOS * 2:
			break
	if lote.is_empty():
		return
	if Sessao.eh_servidor():
		_espalhar_visitados(Sessao.meu_id, lote)
	else:
		_pedir_visitados.rpc_id(1, lote)


## Servidor: o lote entra no mapa daqui e vai a todos, menos a quem mandou.
func _espalhar_visitados(autor: int, lote: PackedInt32Array) -> void:
	_visitar_lote(lote)
	for destino: int in Sessao.destinos():
		if destino != autor:
			_visitados_novos.rpc_id(destino, lote)


func _visitar_lote(lote: PackedInt32Array) -> void:
	for i in range(0, lote.size() - 1, 2):
		var c := Vector2i(lote[i], lote[i + 1])
		# So rua: coordenada de faixa reservada no mapa nao desenha nada.
		if absi(c.x) > 100000 or absi(c.y) > 100000:
			continue
		WorldState.visitar(c)
		_visitados_mandados[c] = true


# --- disputa de item ------------------------------------------------------------------

## Um pedido de item entra na disputa daquele item. A primeira entrada abre a
## janela; ela fecha em meia ida e volta do convidado mais lento.
func _entrar_na_disputa(id: int, seq: int, coord: Vector2i, indice: int, item: StringName,
		qtd: int, cb: Callable) -> void:
	var agora := _agora()
	var k := "%d,%d|%d" % [coord.x, coord.y, indice]
	var c := {"id": id, "seq": seq, "coord": coord, "indice": indice, "item": item, "qtd": qtd,
		"instante": agora - _meia_volta(id), "chegada": agora, "cb": cb}
	if not _disputas.has(k):
		_disputas[k] = {"fecha": agora + _janela(), "candidatos": [c]}
	else:
		((_disputas[k] as Dictionary)["candidatos"] as Array).append(c)
	_fechar_disputas(false)


func _fechar_disputas(todas: bool) -> void:
	var agora := _agora()
	for k: String in _disputas.keys():
		var d: Dictionary = _disputas[k]
		if not todas and agora < float(d["fecha"]):
			continue
		_disputas.erase(k)
		for c: Dictionary in ValidadorDeMundo.ordem_da_disputa(d["candidatos"]):
			var m := _julgar_item(int(c["id"]), int(c["seq"]), c["coord"], int(c["indice"]),
				StringName(c["item"]), int(c["qtd"]))
			if int(c["id"]) == Sessao.meu_id:
				if m == ValidadorDeMundo.Motivo.OK:
					_creditar(StringName(c["item"]), int(c["qtd"]))
				elif not m in ValidadorDeMundo.SILENCIOSOS:
					Sessao.recado.emit(ValidadorDeMundo.texto(m))
				var cb: Callable = c["cb"]
				if cb.is_valid():
					cb.call(m == ValidadorDeMundo.Motivo.OK, m)


## Meia ida e volta de um peer, em s, medida pelo ENet deste servidor.
func _meia_volta(id: int) -> float:
	if id == Sessao.meu_id:
		return 0.0
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet == null:
		return 0.0
	var p := enet.get_peer(id)
	if p == null:
		return 0.0
	return clampf(p.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME) / 2000.0, 0.0, JANELA_MAX)


func _janela() -> float:
	var maior := 0.0
	for id: int in _prontos:
		maior = maxf(maior, _meia_volta(id))
	return maior


func _zerar_cliente() -> void:
	# Outro grupo, outro mapa: o que foi mandado ao anterior vai de novo.
	_visitados_mandados.clear()
	_t_visitados = 0.0
	_espelho.zerar()
	_montagem.zerar()
	_esperas.clear()
	_previstas.clear()
	_seq = 0
	_trocado = false
	_t_carga = -1.0


func _agora() -> float:
	return float(Time.get_ticks_usec()) / 1000000.0
