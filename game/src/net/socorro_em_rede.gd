## Caido e levantar (plano 08 secao 3.3, plano 13 item 3.9).
##
## No solo, vida zero e o `Desmaio`: apaga, pula tres a cinco horas e acorda no
## orelhao. Em rede o relogio e de todos, e o pulo mandaria a madrugada dos
## amigos para o amanhecer. Entao, em rede, vida zero e CAIR: o corpo fica no
## chao (`F_CAIDO`, o amigo ve o boneco de pano) e, por 30 s, quem chegar a um
## metro e meio e segurar [E] por 3 s levanta o caido com 25 de vida. Sem ajuda,
## ele apaga e acorda no ultimo ponto de volta, na mesma hora de todo mundo.
##
## Quem decide e o SERVIDOR: ele conta os 30 s, confere a distancia e o espaco
## de quem levanta pelas posicoes que ele mesmo aceitou, e manda o acordar. O
## segurar da tecla e so da tela de quem ajuda; a prova e do servidor.
##
## Mora fora da `Sessao` pelo mesmo motivo do `MundoEmRede`: o no tem RPC
## proprio (Sessao/Socorro, o mesmo caminho em toda maquina).
class_name SocorroEmRede
extends Node

## Quanto o caido espera ajuda antes de apagar, em s. `--mp-socorro-espera=S`
## no servidor muda (o teste nao espera meio minuto).
const ESPERA := 30.0
## Alcance de quem levanta, e a folga do servidor por cima: a posicao que ele
## tem de cada um e a do ultimo estado aceito, ate um tick atras.
const ALCANCE := 1.5
const FOLGA_DO_SERVIDOR := 1.0
## Quanto se segura [E] para levantar alguem.
const SEGURAR := 3.0
const VIDA_LEVANTADO := 25

## Esta maquina: eu cai e ainda nao levantei nem acordei.
signal caiu()
## Alguem me levantou (nome de quem).
signal levantado(por: String)
## Ninguem veio: apaguei. Quem ouve (o `Desmaio`) escurece, leva ao ponto de
## volta e chama `acordei`.
signal apagou()

var caido := false
## Quem esta no chao agora, visto daqui (id -> true). O servidor e quem manda;
## o cliente guarda para o [E] saber a quem oferecer ajuda.
var caidos: Dictionary = {}

# --- servidor ---
## id -> hora (relogio da Sessao) em que caiu.
var _desde: Dictionary = {}
var _espera: float = ESPERA

# --- quem ajuda ---
var _alvo: int = 0
var _segurado: float = 0.0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--mp-socorro-espera="):
			_espera = maxf(1.0, a.trim_prefix("--mp-socorro-espera=").to_float())


func _process(delta: float) -> void:
	if Sessao.eh_servidor() and not _desde.is_empty():
		var agora := Sessao.tempo_servidor()
		for id: int in _desde.keys():
			if agora - float(_desde[id]) >= _espera:
				_apagar(id)
	if _alvo != 0:
		_segurar(delta)


# --- quem caiu -------------------------------------------------------------------------

## Vida zero em rede. Fora de rede nao faz nada: o `Desmaio` de sempre cuida.
func cair() -> void:
	if not Sessao.em_rede() or caido:
		return
	caido = true
	caiu.emit()
	if Sessao.eh_servidor():
		_servidor_caiu(Sessao.meu_id)
	else:
		_eu_cai.rpc_id(1)


## O caido que apagou ja esta no ponto de volta: o corpo pode aparecer de pe.
## Antes disso o amigo veria o boneco levantar no meio da rua e so depois sumir.
func acordei() -> void:
	caido = false


# --- quem ajuda ------------------------------------------------------------------------

## O [E] no boneco caido de `id`. Vale enquanto a tecla continuar apertada.
func comecar_a_levantar(id: int) -> void:
	if caido or not caidos.has(id):
		return
	_alvo = id
	_segurado = 0.0


## 0..1 do segurar em andamento para `id`; negativo se nao ha.
func progresso(id: int) -> float:
	return _segurado / SEGURAR if _alvo == id else -1.0


## Pede ao servidor, sem o segurar (o bot usa; o jogador chega aqui pelo [E]).
func pedir_levantar(id: int) -> void:
	if Sessao.eh_servidor():
		_julgar_levantar(Sessao.meu_id, id)
	elif Sessao.em_rede():
		_pedir_levantar.rpc_id(1, id)


func _segurar(delta: float) -> void:
	var av: AvatarRemoto = Sessao.avatares().get(_alvo)
	var eu := Sessao.corpo_local()
	var perto := av != null and eu != null and caidos.has(_alvo) and \
		eu.global_position.distance_to(av.global_position) <= ALCANCE
	if not perto or caido or not Input.is_action_pressed(&"interagir"):
		_alvo = 0
		_segurado = 0.0
		return
	_segurado += delta
	if _segurado >= SEGURAR:
		var id := _alvo
		_alvo = 0
		_segurado = 0.0
		pedir_levantar(id)


# --- servidor --------------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable", 0)
func _eu_cai() -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if Sessao.jogadores.has(id):
		_servidor_caiu(id)


func _servidor_caiu(id: int) -> void:
	if _desde.has(id):
		return
	_desde[id] = Sessao.tempo_servidor()
	for outro: int in _destinos():
		_caiu_alguem.rpc_id(outro, id)
	_ao_cair_alguem(id)


@rpc("any_peer", "call_remote", "reliable", 0)
func _pedir_levantar(alvo: int) -> void:
	if not multiplayer.is_server():
		return
	_julgar_levantar(multiplayer.get_remote_sender_id(), alvo)


## Levanta `alvo` a pedido de `quem`, se der. Devolve o motivo da recusa, ou "".
func _julgar_levantar(quem: int, alvo: int) -> String:
	if not _desde.has(alvo):
		return "nao esta caido"
	if quem == alvo or _desde.has(quem) or not Sessao.jogadores.has(quem):
		return "quem pede nao pode"
	var a := Sessao.estado_aceito(quem)
	var b := Sessao.estado_aceito(alvo)
	if a.is_empty() or b.is_empty() or int(a["espaco"]) != int(b["espaco"]):
		return "outro lugar"
	if (a["pos"] as Vector3).distance_to(b["pos"]) > ALCANCE + FOLGA_DO_SERVIDOR:
		return "longe"
	_desde.erase(alvo)
	var nome_quem := _nome(quem)
	if alvo == Sessao.meu_id:
		_levantado_por(nome_quem)
	else:
		_levantado_por.rpc_id(alvo, nome_quem)
	for outro: int in _destinos():
		_levantou_alguem.rpc_id(outro, alvo, nome_quem)
	_ao_levantar_alguem(alvo, nome_quem)
	return ""


func _apagar(id: int) -> void:
	_desde.erase(id)
	if id == Sessao.meu_id:
		_apagou_aqui()
	elif Sessao.jogadores.has(id):
		_apagou_aqui.rpc_id(id)
	for outro: int in _destinos():
		_apagou_alguem.rpc_id(outro, id)
	_ao_apagar_alguem(id)


## Para quem o servidor manda eventos: todo cliente, menos ele mesmo.
func _destinos() -> Array[int]:
	var ids: Array[int] = []
	for id: int in multiplayer.get_peers():
		if Sessao.jogadores.has(id):
			ids.append(id)
	return ids


# --- eventos -----------------------------------------------------------------------------

@rpc("authority", "call_remote", "reliable", 0)
func _caiu_alguem(id: int) -> void:
	_ao_cair_alguem(id)


@rpc("authority", "call_remote", "reliable", 0)
func _levantou_alguem(id: int, por: String) -> void:
	_ao_levantar_alguem(id, ProtocoloRede.sanear_nome(por))


@rpc("authority", "call_remote", "reliable", 0)
func _apagou_alguem(id: int) -> void:
	_ao_apagar_alguem(id)


@rpc("authority", "call_remote", "reliable", 0)
func _levantado_por(por: String) -> void:
	if not caido:
		return
	caido = false
	caidos.erase(Sessao.meu_id)
	Sessao.avisar_local("%s te levantou." % ProtocoloRede.sanear_nome(por))
	levantado.emit(ProtocoloRede.sanear_nome(por))


@rpc("authority", "call_remote", "reliable", 0)
func _apagou_aqui() -> void:
	if not caido:
		return
	caidos.erase(Sessao.meu_id)
	apagou.emit()


func _ao_cair_alguem(id: int) -> void:
	caidos[id] = true
	if id != Sessao.meu_id:
		Sessao.avisar_local("%s caiu. Segure [E] perto dele para levantar." % _nome(id))


func _ao_levantar_alguem(id: int, por: String) -> void:
	caidos.erase(id)
	if id != Sessao.meu_id:
		Sessao.avisar_local("%s levantou %s." % [por, _nome(id)])


func _ao_apagar_alguem(id: int) -> void:
	caidos.erase(id)
	if id != Sessao.meu_id:
		Sessao.avisar_local("%s apagou." % _nome(id))


func _nome(id: int) -> String:
	return String((Sessao.jogadores.get(id, {}) as Dictionary).get("nome", "Alguem"))


# --- ciclo -----------------------------------------------------------------------------

func esquecer(id: int) -> void:
	_desde.erase(id)
	caidos.erase(id)
	if _alvo == id:
		_alvo = 0


## A sessao acabou. Quem estava no chao nao fica no chao para sempre: apaga e
## acorda no ponto de volta (o `Desmaio` ja sabe que nao pula hora nesse caso).
func zerar() -> void:
	_desde.clear()
	caidos.clear()
	_alvo = 0
	_segurado = 0.0
	if caido:
		apagou.emit()
