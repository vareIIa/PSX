## Mochila em rede: dar item a um amigo (plano 08 secoes 1.2 e 1.3, plano 13
## item 3.8).
##
## O servidor guarda uma `MochilaDoServidor` de cada convidado, a sombra do que
## ele tem. O convidado manda a propria mochila ao entrar e a cada mudanca (meio
## segundo de folga), e o servidor so aceita o que presta (item que existe,
## pilha que cabe). A do anfitriao e o proprio `Inventario` dele.
##
## Dar e ATOMICO no servidor: tira de A, poe em B, e o que nao coube em B volta
## para A. Depois avisa os dois. Um item dado nunca existe nos dois lugares, e o
## mesmo item nao se da duas vezes, porque a sombra de A ja desceu antes de a
## resposta chegar.
##
## O que ainda nao e do servidor: pegar item do mundo ja e (`_pedir_item`), mas a
## compra, a colheita e a entrega de NPC continuam escrevendo no `Inventario`
## local, e o servidor so fica sabendo pela sombra. A mochila inteira do servidor
## (kit inicial dele, mochila guardada pelo token) e a Fase 6.
class_name MochilasEmRede
extends Node

## Distancia de quem da para quem recebe, e a folga do servidor por cima (a
## posicao que ele tem e a do ultimo estado aceito).
const ALCANCE := 2.0
const FOLGA_DO_SERVIDOR := 1.0
## Espera antes de mandar a mochila depois de uma mudanca: a prancha mexe em
## tres espacos num clique e sai um pacote so.
const FOLGA_ENVIO := 0.5
## Relatorios de mochila por segundo que o servidor aceita de um convidado.
const TETO_RELATORIOS := 6

## Resposta de `dar`: se deu, quanto foi, e o motivo quando nao.
signal deu(ok: bool, item: StringName, qtd: int, motivo: String)
signal recebeu(item: StringName, qtd: int, de: String)

# --- servidor ---
var _sombras: Dictionary = {}
var _cotas: Dictionary = {}

# --- cliente ---
var _sujo := true
var _espera := 0.0
var _seq := 0
var _pedidos: Dictionary = {}


func _ready() -> void:
	Inventario.mudou.connect(_ao_mudar_a_mochila)


func _process(delta: float) -> void:
	if Sessao.modo != Sessao.Modo.CLIENTE or not Sessao.mundo_pronto() or not _sujo:
		return
	_espera -= delta
	if _espera > 0.0:
		return
	_sujo = false
	_minha_mochila.rpc_id(1, Inventario.para_dicionario())


func _ao_mudar_a_mochila() -> void:
	if not _sujo:
		_espera = FOLGA_ENVIO
	_sujo = true


# --- quem da -----------------------------------------------------------------------------

## Da `qtd` do item do espaco `espaco` da minha mochila ao jogador `alvo`.
## Responde por `deu`.
func dar(alvo: int, espaco: int, qtd: int) -> void:
	if not Sessao.em_rede():
		deu.emit(false, &"", 0, "sozinho")
		return
	if Sessao.eh_servidor():
		_julgar_dar(Sessao.meu_id, 0, alvo, espaco, qtd)
		return
	# A sombra do servidor tem de estar em dia antes do pedido: a mudanca da
	# mochila que ainda esta na folga vai agora, no mesmo canal, antes dele.
	if _sujo:
		_sujo = false
		_minha_mochila.rpc_id(1, Inventario.para_dicionario())
	_seq += 1
	_pedidos[_seq] = true
	_pedir_dar.rpc_id(1, _seq, alvo, espaco, qtd)


# --- servidor ----------------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable", 0)
func _minha_mochila(dados: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if not Sessao.jogadores.has(id):
		return
	var agora := Sessao.tempo_servidor()
	var janela: Array = (_cotas.get(id, []) as Array).filter(
		func(t: float) -> bool: return agora - t < 1.0)
	if janela.size() >= TETO_RELATORIOS:
		return
	janela.append(agora)
	_cotas[id] = janela
	_sombra(id).de_dicionario(dados)


@rpc("any_peer", "call_remote", "reliable", 0)
func _pedir_dar(seq: int, alvo: int, espaco: int, qtd: int) -> void:
	if not multiplayer.is_server():
		return
	_julgar_dar(multiplayer.get_remote_sender_id(), seq, alvo, espaco, qtd)


## Faz a transferencia se der. Devolve o motivo da recusa, ou "".
func _julgar_dar(quem: int, seq: int, alvo: int, espaco: int, qtd: int) -> String:
	var motivo := _conferir_dar(quem, alvo)
	var ma := _sombra(quem)
	var mb := _sombra(alvo)
	var saiu := {}
	if motivo.is_empty():
		saiu = ma.tirar_do_espaco(espaco, qtd)
		if saiu.is_empty():
			motivo = "nao tem"
	if not motivo.is_empty():
		_responder(quem, seq, false, &"", 0, motivo)
		return motivo
	var item: StringName = saiu["id"]
	var sobra := mb.adicionar(item, qtd)
	var dado := qtd - sobra
	if sobra > 0:
		# Nao coube tudo: o resto volta para quem deu, na sombra e na mao dele.
		ma.adicionar(item, sobra)
	if dado <= 0:
		_responder(quem, seq, false, item, 0, "sem lugar")
		return "sem lugar"
	var de := _nome(quem)
	if alvo == Sessao.meu_id:
		_recebeu_item(item, dado, de)
	else:
		_recebeu_item.rpc_id(alvo, item, dado, de)
	_responder(quem, seq, true, item, dado, "")
	return ""


func _conferir_dar(quem: int, alvo: int) -> String:
	if quem == alvo or not Sessao.jogadores.has(alvo) or not Sessao.jogadores.has(quem):
		return "ninguem"
	if Sessao.socorro.caidos.has(quem):
		return "caido"
	var a := Sessao.estado_aceito(quem)
	var b := Sessao.estado_aceito(alvo)
	if a.is_empty() or b.is_empty() or int(a["espaco"]) != int(b["espaco"]):
		return "outro lugar"
	if (a["pos"] as Vector3).distance_to(b["pos"]) > ALCANCE + FOLGA_DO_SERVIDOR:
		return "longe"
	return ""


func _responder(quem: int, seq: int, ok: bool, item: StringName, qtd: int, motivo: String) -> void:
	if quem == Sessao.meu_id:
		_resposta_dar(seq, ok, item, qtd, motivo)
	else:
		_resposta_dar.rpc_id(quem, seq, ok, item, qtd, motivo)


## A mochila de `id` como o servidor a conhece. A do anfitriao e o `Inventario`
## dele, lido na hora de cada pedido (as mudancas voltam a ele pelas respostas).
func _sombra(id: int) -> MochilaDoServidor:
	if id == Sessao.meu_id and Sessao.modo == Sessao.Modo.HOSPEDANDO:
		var m := MochilaDoServidor.new(_pilha)
		m.de_dicionario(Inventario.para_dicionario())
		return m
	if not _sombras.has(id):
		_sombras[id] = MochilaDoServidor.new(_pilha)
	return _sombras[id]


# --- respostas -----------------------------------------------------------------------------

@rpc("authority", "call_remote", "reliable", 0)
func _resposta_dar(seq: int, ok: bool, item: StringName, qtd: int, motivo: String) -> void:
	_pedidos.erase(seq)
	if ok:
		Inventario.remover(item, qtd)
		var def: Item = Inventario.definicao(item)
		Sessao.avisar_local("Voce deu %d %s." % [qtd, def.nome if def != null else String(item)])
	deu.emit(ok, item, qtd, motivo)


@rpc("authority", "call_remote", "reliable", 0)
func _recebeu_item(item: StringName, qtd: int, de: String) -> void:
	if Inventario.definicao(item) == null or qtd <= 0:
		return
	var sobra := Inventario.adicionar(item, qtd)
	var def: Item = Inventario.definicao(item)
	Sessao.avisar_local("%s te deu %d %s." % [ProtocoloRede.sanear_nome(de), qtd - sobra, def.nome])
	recebeu.emit(item, qtd - sobra, ProtocoloRede.sanear_nome(de))


## A pilha maxima de um item pelas definicoes do `Inventario` (1 = nao empilha,
## 0 = nao existe). Fica aqui, e nao na `MochilaDoServidor`, para ela seguir pura
## (o teste de nivel 2 nao enxerga autoload).
static func _pilha(id: StringName) -> int:
	var item: Item = Inventario.definicao(id)
	if item == null:
		return 0
	return item.max_pilha if item.e_empilhavel() else 1


func _nome(id: int) -> String:
	return String((Sessao.jogadores.get(id, {}) as Dictionary).get("nome", "Alguem"))


func esquecer(id: int) -> void:
	_sombras.erase(id)
	_cotas.erase(id)


func zerar() -> void:
	_sombras.clear()
	_cotas.clear()
	_pedidos.clear()
	_sujo = true
