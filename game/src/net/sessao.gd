## A sessao de rede: com quem se joga, e o fio entre as maquinas. Autoload
## `Sessao`.
##
## Um modelo so, tres jeitos de rodar
## ----------------------------------
## Quem manda no mundo e sempre o SERVIDOR, que e o peer 1. O que muda e se ha
## um jogador sentado nele:
##
##   HOSPEDANDO  o jogo aberto para amigos (LAN, Hamachi, Radmin). O processo e o
##               servidor E um jogador — o "Abrir para LAN" de qualquer jogo.
##   DEDICADO    o mesmo servidor, sem jogador, sem tela (servidor_dedicado.tscn,
##               --headless). Roda numa VPS, num container, num PC no canto.
##   CLIENTE     um jogo que entrou num dos dois. Nao sabe qual e: o protocolo e
##               o mesmo, e por isso o dedicado nao e um segundo produto.
##
## SOLO e o jogo de sempre. Em SOLO este no nao processa nada (P16 do plano).
##
## Por que tudo mora aqui, e nao na cena
## -------------------------------------
## RPC do Godot acha o no pelo CAMINHO. O servidor dedicado roda uma cena
## principal que nao e a cidade — ele nao precisa de menu, de camera, nem da
## abertura. Se os RPCs morassem em /root/Cidade, o servidor nao teria para onde
## entregar. Um autoload tem o mesmo caminho em qualquer processo: /root/Sessao.
## Os bonecos dos outros jogadores sao filhos daqui pela mesma razao.
##
## Por que o jogador local nao muda
## --------------------------------
## O `Player` continua sendo o de sempre, filho estatico da cidade.tscn. A Sessao
## o acha pelo grupo `player` (o UNICO uso novo de `get_first_node_in_group`
## permitido, plano 06), le posicao e estado dele, e manda. Os outros jogadores
## sao `AvatarRemoto`, fora do grupo. Nenhum dos 31 lugares do jogo que procuram
## "o jogador" precisa saber que existe rede para o amigo aparecer na rua.
##
## Plano: MULTIPLAYER/PLANO/03_ARQUITETURA.md, 04, 18 e 20.
extends Node

signal modo_mudou(modo: int)
signal lista_mudou()
signal recado(texto: String)
signal conexao_falhou(motivo: String)

enum Modo { SOLO, HOSPEDANDO, DEDICADO, CONECTANDO, CLIENTE }

## Canais ENet: 0 evento confiavel, 1 estado continuo.
const CANAL_EVENTO := 0
const CANAL_ESTADO := 1

## De quanto em quanto tempo o servidor acerta o relogio de jogo dos clientes.
const INTERVALO_RELOGIO := 5.0
const INTERVALO_PING := 2.0
## Sem estado de um jogador por tanto tempo, o boneco some: saiu do raio de
## interesse, foi para outro espaco, ou a conexao esta morrendo.
const SUMIR_APOS := 1.0
## Pacotes de estado por segundo que um cliente pode mandar. O triplo do tick:
## a rajada depois de um soluco de Wi-Fi passa, inundacao nao.
const TETO_ESTADO_POR_S := ProtocoloRede.TICK_HZ * 3
## Mensagens de chat por janela de 5 s.
const TETO_CHAT := 5

var modo: Modo = Modo.SOLO
## O servidor desta maquina, quando ela hospeda.
var config: ConfigServidor
var meu_id: int = 0
var nome_servidor: String = ""
var mensagem_servidor: String = ""
## id -> {"nome": String, "aparencia": Dictionary, "ping": int}. Inclui este
## processo quando ele joga (HOSPEDANDO ou CLIENTE).
var jogadores: Dictionary = {}

# --- servidor ---
var _nonces: Dictionary = {}
var _pedidos: Dictionary = {}
var _estados: Dictionary = {}
var _validadores: Dictionary = {}
var _ultimo_seq: Dictionary = {}
## id -> hora (do servidor) em que o estado guardado foi lido no cliente.
var _amostrado_em: Dictionary = {}
var _cotas: Dictionary = {}
var _cotas_chat: Dictionary = {}
var _log_suspeita: Dictionary = {}
var _tick: int = 0
var _acc_relogio := 0.0
var _acc_ping := 0.0
var _ponto_inicial_cache := Vector3.INF

# --- cliente (e o anfitriao, que tambem desenha os outros) ---
var _relogio_rede := RelogioDeRede.new()
var _seq: int = 0
var _avatares: Dictionary = {}
var _visto_em: Dictionary = {}
var _pedido_local: Dictionary = {}
var _ultima_pos_enviada := Vector3.INF
var _ultimo_espaco_enviado: int = -1
var _teleporte_pendente := false
## Motivo que o servidor deu ao recusar. Tem precedencia sobre a queda de
## conexao que vem logo depois dele: quem errou a senha tem de ler "senha
## errada", e nao "o servidor fechou".
var _recusa: String = ""

var _acc_tick := 0.0
var _corpo_local: Node3D
var _perfil_injetado: Dictionary = {}
var _raiz_avatares: Node3D
var _descoberta: DescobertaLan
var _painel: PainelOnline


func _ready() -> void:
	# A rede tem de andar com a arvore pausada: o anfitriao que abre o menu de
	# sistema nao pode congelar o mundo de quem esta conectado nele.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Depois da logica do jogo no quadro: a posicao lida e a DESTE quadro, e nao a
	# do anterior. Um quadro de atraso sao 17 ms, que a 2,4 m/s viram 4 cm de
	# erro em quem desenha o amigo, somados a todo o resto.
	process_priority = 100
	_raiz_avatares = Node3D.new()
	_raiz_avatares.name = "Jogadores"
	add_child(_raiz_avatares)
	_descoberta = DescobertaLan.new()
	_descoberta.name = "DescobertaLan"
	add_child(_descoberta)

	var mp := multiplayer as SceneMultiplayer
	mp.auth_callback = _ao_receber_autenticacao
	mp.auth_timeout = ProtocoloRede.TEMPO_AUTENTICACAO
	# Cliente nao conversa com cliente. Tudo passa pelo servidor, que e quem
	# valida — relay ligado deixaria um cliente mandar RPC direto a outro.
	mp.server_relay = false
	mp.peer_authenticating.connect(_ao_peer_autenticando)
	mp.peer_authentication_failed.connect(_ao_autenticacao_falhou)
	mp.peer_connected.connect(_ao_peer_conectou)
	mp.peer_disconnected.connect(_ao_peer_saiu)
	mp.connected_to_server.connect(_ao_conectar)
	mp.connection_failed.connect(_ao_falhar_conexao)
	mp.server_disconnected.connect(_ao_servidor_cair)

	set_process(false)
	if DisplayServer.get_name() != "headless":
		_painel = PainelOnline.new()
		_painel.name = "PainelOnline"
		add_child(_painel)
	_ler_linha_de_comando.call_deferred()


func _exit_tree() -> void:
	# Fechar o peer manda o aviso de desconexao do ENet: quem esta do outro lado
	# ve "saiu" na hora, e nao depois de oito segundos de silencio.
	if multiplayer.multiplayer_peer != null and not (
			multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()


# --- API ---------------------------------------------------------------------------

func em_rede() -> bool:
	return modo != Modo.SOLO


func eh_servidor() -> bool:
	return modo == Modo.HOSPEDANDO or modo == Modo.DEDICADO


func eh_cliente() -> bool:
	return modo == Modo.CLIENTE or modo == Modo.CONECTANDO


## Abre este jogo para amigos. `max_jogadores` conta o anfitriao.
func hospedar(porta: int = ProtocoloRede.PORTA_PADRAO,
		max_jogadores: int = ProtocoloRede.MAX_JOGADORES_PADRAO,
		nome: String = "", senha: String = "") -> Error:
	var c := ConfigServidor.new()
	c.porta = porta
	c.max_jogadores = max_jogadores
	c.nome = nome if not nome.is_empty() else "MUNDO DE %s" % _meu_nome()
	c.senha = senha
	return _subir_servidor(c, Modo.HOSPEDANDO)


## Sobe o servidor dedicado. Chamado por `ServidorDedicado`.
func hospedar_dedicado(c: ConfigServidor) -> Error:
	return _subir_servidor(c, Modo.DEDICADO)


## Entra num servidor. `endereco` aceita IP, nome (DNS) e "host:porta".
func entrar(endereco: String, porta: int = -1, senha: String = "") -> Error:
	var alvo := separar_endereco(endereco)
	var host: String = alvo[0]
	var p: int = porta if porta > 0 else int(alvo[1])
	if host.is_empty():
		return ERR_INVALID_PARAMETER
	sair()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(host, p, 2)
	if err != OK:
		_recado("Nao deu para ligar para %s:%d (erro %d)." % [host, p, err])
		return err
	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	_pedido_local = {
		"nome": _meu_nome(),
		"aparencia": _minha_aparencia(),
		"senha": senha,
	}
	_relogio_rede.zerar()
	_recusa = ""
	multiplayer.multiplayer_peer = peer
	_mudar_modo(Modo.CONECTANDO)
	set_process(true)
	_recado("Ligando para %s:%d..." % [host, p])
	return OK


## Sai da sessao. O mundo desta maquina continua — quem era cliente segue
## jogando sozinho onde estava, como o plano P11 revisado pede.
func sair(motivo: String = "") -> void:
	if modo == Modo.SOLO:
		return
	var peer := multiplayer.multiplayer_peer
	if peer != null and not (peer is OfflineMultiplayerPeer):
		peer.close()
	multiplayer.multiplayer_peer = null
	_descoberta.parar()
	_limpar()
	_mudar_modo(Modo.SOLO)
	set_process(false)
	if not motivo.is_empty():
		_recado(motivo)


## Manda uma linha de chat para a sessao.
func falar(texto: String) -> void:
	var limpo := ProtocoloRede.sanear_texto(texto, ProtocoloRede.CHAT_MAX)
	if limpo.is_empty() or modo == Modo.SOLO or modo == Modo.CONECTANDO:
		return
	if eh_servidor():
		_difundir_chat(meu_id if modo == Modo.HOSPEDANDO else 0, limpo)
	else:
		_pedir_chat.rpc_id(1, limpo)


## Servidor: tira alguem da sessao.
func expulsar(id: int, motivo: String = "") -> void:
	if not eh_servidor() or not jogadores.has(id) or id == meu_id:
		return
	_aviso.rpc_id(id, "Voce saiu do servidor: %s" % (motivo if not motivo.is_empty() else "expulso"))
	_derrubar_depois(id)


## Servidor: recado para todo mundo.
func anunciar_a_todos(texto: String) -> void:
	if not eh_servidor():
		return
	var limpo := ProtocoloRede.sanear_texto(texto, ProtocoloRede.CHAT_MAX)
	for id: int in _destinos():
		_aviso.rpc_id(id, limpo)
	_recado(limpo)


## Troca o corpo que esta maquina manda para a rede. Sem isto, e o `Player` do
## grupo. Bot de teste e captura injetam um Node3D qualquer, com `flags` e
## `rapidez` em metadado.
func definir_corpo_local(corpo: Node3D, perfil: Dictionary = {}) -> void:
	_corpo_local = corpo
	_perfil_injetado = perfil


func corpo_local() -> Node3D:
	if _corpo_local != null and is_instance_valid(_corpo_local):
		return _corpo_local
	if modo == Modo.DEDICADO:
		return null
	var p := get_tree().get_first_node_in_group(&"player") as Node3D
	if p != null:
		_corpo_local = p
	return p


func avatares() -> Dictionary:
	return _avatares


## A hora do servidor, estimada deste lado. No servidor, a propria.
func tempo_servidor() -> float:
	if eh_servidor():
		return _agora()
	return _relogio_rede.agora(_agora())


## O relogio do servidor ja foi estimado (chegou o primeiro instantaneo).
func relogio_pronto() -> bool:
	return eh_servidor() or _relogio_rede.pronto()


## O instante que os bonecos estao desenhando agora.
func tempo_de_desenho() -> float:
	return tempo_servidor() - ProtocoloRede.ATRASO_INTERPOLACAO


func ponto_inicial() -> Vector3:
	if _ponto_inicial_cache == Vector3.INF:
		_ponto_inicial_cache = _ler_ponto_inicial()
	return _ponto_inicial_cache


func descoberta() -> DescobertaLan:
	return _descoberta


func painel() -> PainelOnline:
	return _painel


## Em que espaco o corpo esta (rua, estrada, qual interior).
func espaco_do_corpo(c: Node3D) -> int:
	var y := c.global_position.y
	if y > ProtocoloRede.Y_ESTRADA:
		return ProtocoloRede.ESPACO_ESTRADA
	if y > ProtocoloRede.Y_INTERIOR:
		# `_semente` e privado de interiores.gd, que esta em edicao em outra
		# frente; o acesso por `get` nao quebra se o nome mudar, so junta todos
		# os interiores num espaco. Fase 2: trocar por um acessor publico.
		var s: Variant = Interiores.get(&"_semente")
		var semente := int(s) if typeof(s) == TYPE_INT else 0
		return ProtocoloRede.espaco_interior(Interiores.tipo_atual(), semente)
	return ProtocoloRede.ESPACO_RUA


static func separar_endereco(s: String) -> Array:
	var limpo := s.strip_edges()
	var porta := ProtocoloRede.PORTA_PADRAO
	var i := limpo.rfind(":")
	# Um ":" so e porta. Mais de um e IPv6 sem colchete, e fica inteiro.
	if i > 0 and limpo.count(":") == 1:
		var p := limpo.substr(i + 1).to_int()
		if p > 0 and p <= 65535:
			porta = p
		limpo = limpo.substr(0, i)
	return [limpo, porta]


# --- subir servidor -------------------------------------------------------------------

func _subir_servidor(c: ConfigServidor, novo_modo: Modo) -> Error:
	var problemas := c.erros()
	if not problemas.is_empty():
		for p: String in problemas:
			push_error("[sessao] configuracao: %s" % p)
		return ERR_INVALID_PARAMETER
	sair()
	var peer := ENetMultiplayerPeer.new()
	# Quatro conexoes de folga acima do maximo: quem chega com o servidor cheio
	# precisa CONECTAR para ouvir "servidor cheio". Sem folga o ENet recusa no
	# transporte e o jogador ve um timeout mudo.
	var err := peer.create_server(c.porta, c.max_jogadores + 4, 2)
	if err != OK:
		_recado("Nao deu para abrir a porta %d (erro %d). Outro programa usando?" % [c.porta, err])
		return err
	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	# Le o ponto de nascimento AGORA, com ninguem conectado. Ler na primeira
	# entrada carrega a cidade.tscn (e o player, e os scripts dela) no meio do
	# laco do servidor: medido 130 ms de quadro parado para todo mundo.
	ponto_inicial()
	config = c
	meu_id = 1
	nome_servidor = c.nome_publico()
	mensagem_servidor = ProtocoloRede.sanear_texto(c.mensagem, ProtocoloRede.CHAT_MAX)
	_limpar()
	if novo_modo == Modo.HOSPEDANDO:
		jogadores[1] = {"nome": _meu_nome(), "aparencia": _minha_aparencia(), "ping": 0}
	multiplayer.multiplayer_peer = peer
	_mudar_modo(novo_modo)
	set_process(true)
	if c.anunciar_lan:
		_descoberta.anunciar(_conteudo_do_anuncio)
	_recado("Servidor aberto na porta %d." % c.porta)
	return OK


func _conteudo_do_anuncio() -> Dictionary:
	return {
		"nome": nome_servidor,
		"porta": config.porta if config != null else ProtocoloRede.PORTA_PADRAO,
		"n": jogadores.size(),
		"max": config.max_jogadores if config != null else 0,
		"senha": config != null and not config.senha.is_empty(),
	}


# --- autenticacao ------------------------------------------------------------------------
# Roda ANTES de o peer existir para o jogo: sem `complete_auth`, nenhum RPC dele
# e entregue. Ver ProtocoloRede, secao de autenticacao.

func _ao_peer_autenticando(id: int) -> void:
	if not multiplayer.is_server():
		return
	var nonce := ProtocoloRede.novo_nonce()
	_nonces[id] = nonce
	(multiplayer as SceneMultiplayer).send_auth(id, ProtocoloRede.mensagem({
		"tipo": "desafio",
		"jogo": ProtocoloRede.JOGO,
		"v": ProtocoloRede.VERSAO,
		"nonce": nonce,
		"senha": not config.senha.is_empty(),
		"nome": nome_servidor,
		"n": jogadores.size(),
		"max": config.max_jogadores,
	}))


func _ao_receber_autenticacao(id: int, dados: PackedByteArray) -> void:
	var msg := ProtocoloRede.ler_mensagem(dados)
	if multiplayer.is_server():
		_julgar_pedido(id, msg)
	else:
		_responder_servidor(msg)


func _julgar_pedido(id: int, msg: Dictionary) -> void:
	if not _nonces.has(id):
		return
	var nonce: String = _nonces[id]
	_nonces.erase(id)
	var mp := multiplayer as SceneMultiplayer
	var motivo := ProtocoloRede.julgar_pedido(msg, nonce, config.senha,
		jogadores.size() + _pedidos.size(), config.max_jogadores)
	if not motivo.is_empty():
		mp.send_auth(id, ProtocoloRede.mensagem(
			{"tipo": "veredito", "ok": false, "motivo": motivo}))
		print("[servidor] recusado peer %d: %s" % [id, motivo])
		_derrubar_depois(id)
		return
	_pedidos[id] = {
		"nome": ProtocoloRede.sanear_nome(String(msg.get("nome", ""))),
		"aparencia": ProtocoloRede.sanear_aparencia(msg.get("aparencia", {})),
		"ping": 0,
	}
	mp.send_auth(id, ProtocoloRede.mensagem({"tipo": "veredito", "ok": true, "motivo": ""}))
	mp.complete_auth(id)


func _responder_servidor(msg: Dictionary) -> void:
	var mp := multiplayer as SceneMultiplayer
	match String(msg.get("tipo", "")):
		"desafio":
			if String(msg.get("jogo", "")) != ProtocoloRede.JOGO:
				_falhar.call_deferred(ProtocoloRede.RECUSA_JOGO)
				return
			if int(msg.get("v", -1)) != ProtocoloRede.VERSAO:
				_falhar.call_deferred(ProtocoloRede.RECUSA_VERSAO)
				return
			nome_servidor = ProtocoloRede.sanear_texto(String(msg.get("nome", "")), 32).to_upper()
			var prova := ""
			if bool(msg.get("senha", false)):
				prova = ProtocoloRede.prova_de_senha(
					String(_pedido_local.get("senha", "")), String(msg.get("nonce", "")))
			mp.send_auth(1, ProtocoloRede.mensagem({
				"tipo": "pedido",
				"jogo": ProtocoloRede.JOGO,
				"v": ProtocoloRede.VERSAO,
				"nome": _pedido_local.get("nome", ""),
				"aparencia": _pedido_local.get("aparencia", {}),
				"prova": prova,
			}))
		"veredito":
			if bool(msg.get("ok", false)):
				mp.complete_auth(1)
			else:
				_recusa = String(msg.get("motivo", ProtocoloRede.RECUSA_PEDIDO))
				_falhar.call_deferred(_recusa)


func _ao_autenticacao_falhou(id: int) -> void:
	if multiplayer.is_server():
		_nonces.erase(id)
		_pedidos.erase(id)
		return
	if modo == Modo.CONECTANDO:
		_falhar.call_deferred("O servidor nao respondeu a apresentacao a tempo.")


## Servidor: derruba um peer daqui a pouco, depois de a ultima mensagem sair.
##
## Quem foi recusado sai sozinho ao ler o veredito; isto e so para quem nao sai.
## Dois segundos, e nao menos: no cliente o ENet entrega a DESCONEXAO antes dos
## pacotes que chegaram no mesmo quadro, e com a maquina carregada (16 processos
## no teste) 0,3 s fazia quem errou a senha ler "o servidor fechou" em vez de
## "senha errada".
func _derrubar_depois(id: int) -> void:
	get_tree().create_timer(2.0, true, false, true).timeout.connect(func() -> void:
		if not eh_servidor() or multiplayer.multiplayer_peer == null:
			return
		# O recusado costuma sair sozinho ao ler o veredito; derrubar quem ja
		# saiu e erro do ENet no log (medido no teste de "servidor cheio").
		var mp := multiplayer as SceneMultiplayer
		if mp.get_peers().has(id) or mp.get_authenticating_peers().has(id):
			mp.disconnect_peer(id))


# --- conexao ---------------------------------------------------------------------------

func _ao_peer_conectou(id: int) -> void:
	if not multiplayer.is_server():
		return
	if not _pedidos.has(id):
		# Conectou sem passar pelo julgamento: nao deveria acontecer. Fora.
		(multiplayer as SceneMultiplayer).disconnect_peer(id)
		return
	var perfil: Dictionary = _pedidos[id]
	_pedidos.erase(id)
	var slot := jogadores.size()
	jogadores[id] = perfil
	_validadores[id] = ValidadorMovimento.new()
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet != null and enet.get_peer(id) != null:
		enet.get_peer(id).set_timeout(0, ProtocoloRede.TIMEOUT_MIN_MS, ProtocoloRede.TIMEOUT_MAX_MS)

	var chegada := _ponto_de_chegada(slot)
	_boas_vindas.rpc_id(id, {
		"id": id,
		"jogadores": jogadores,
		"servidor": nome_servidor,
		"mensagem": mensagem_servidor,
		"relogio": WorldState.relogio.segundos,
		"chegada": chegada[0],
		"olhar": chegada[1],
	})
	for outro: int in _destinos():
		if outro != id:
			_jogador_entrou.rpc_id(outro, id, perfil)
	if modo == Modo.HOSPEDANDO:
		_garantir_avatar(id)
	print("[servidor] entrou %s (peer %d) — %d/%d" % [
		perfil["nome"], id, jogadores.size(), config.max_jogadores])
	_recado("%s entrou." % perfil["nome"])
	lista_mudou.emit()


func _ao_peer_saiu(id: int) -> void:
	if not multiplayer.is_server():
		return
	_nonces.erase(id)
	_pedidos.erase(id)
	if not jogadores.has(id):
		return
	var nome := String(jogadores[id]["nome"])
	jogadores.erase(id)
	_esquecer(id)
	for outro: int in _destinos():
		_jogador_saiu.rpc_id(outro, id, "saiu")
	print("[servidor] saiu %s (peer %d) — %d/%d" % [
		nome, id, jogadores.size(), config.max_jogadores])
	_recado("%s saiu." % nome)
	lista_mudou.emit()


func _ao_conectar() -> void:
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet != null and enet.get_peer(1) != null:
		enet.get_peer(1).set_timeout(0, ProtocoloRede.TIMEOUT_MIN_MS, ProtocoloRede.TIMEOUT_MAX_MS)


func _ao_falhar_conexao() -> void:
	_falhar("Ninguem respondeu nesse endereco.")


func _ao_servidor_cair() -> void:
	if modo == Modo.CONECTANDO:
		_falhar("O servidor fechou a porta.")
		return
	sair("O servidor fechou. Voce continua sozinho aqui.")


func _falhar(motivo: String) -> void:
	if modo == Modo.SOLO:
		return
	var m := _recusa if not _recusa.is_empty() else motivo
	_recusa = ""
	var texto := String(ProtocoloRede.TEXTO_RECUSA.get(m, m))
	sair()
	_recado(texto)
	conexao_falhou.emit(texto)


# --- RPC: servidor -> cliente ----------------------------------------------------------

@rpc("authority", "call_remote", "reliable", 0)
func _boas_vindas(dados: Dictionary) -> void:
	meu_id = multiplayer.get_unique_id()
	jogadores.clear()
	var lista: Dictionary = dados.get("jogadores", {})
	for k: Variant in lista:
		if typeof(k) == TYPE_INT and typeof(lista[k]) == TYPE_DICTIONARY:
			jogadores[int(k)] = _perfil_seguro(lista[k])
	nome_servidor = ProtocoloRede.sanear_texto(String(dados.get("servidor", "")), 32).to_upper()
	mensagem_servidor = ProtocoloRede.sanear_texto(String(dados.get("mensagem", "")), ProtocoloRede.CHAT_MAX)
	var relogio: Variant = dados.get("relogio", null)
	if typeof(relogio) == TYPE_FLOAT and is_finite(float(relogio)):
		WorldState.relogio.segundos = fposmod(float(relogio), float(Relogio.DIA))
	_mudar_modo(Modo.CLIENTE)
	for id: int in jogadores:
		if id != meu_id:
			_garantir_avatar(id)
	_recado("Voce entrou em %s." % nome_servidor)
	if not mensagem_servidor.is_empty():
		_recado(mensagem_servidor)
	lista_mudou.emit()
	var chegada: Variant = dados.get("chegada", null)
	var olhar: Variant = dados.get("olhar", null)
	if typeof(chegada) == TYPE_VECTOR3 and typeof(olhar) == TYPE_VECTOR3:
		_chegar(chegada, olhar)


@rpc("authority", "call_remote", "reliable", 0)
func _jogador_entrou(id: int, perfil: Dictionary) -> void:
	if id == meu_id:
		return
	jogadores[id] = _perfil_seguro(perfil)
	_garantir_avatar(id)
	_recado("%s entrou." % jogadores[id]["nome"])
	lista_mudou.emit()


@rpc("authority", "call_remote", "reliable", 0)
func _jogador_saiu(id: int, _motivo: String) -> void:
	if not jogadores.has(id):
		return
	var nome := String(jogadores[id]["nome"])
	jogadores.erase(id)
	_esquecer(id)
	_recado("%s saiu." % nome)
	lista_mudou.emit()


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _instantaneo(bytes: PackedByteArray) -> void:
	var inst := ProtocoloRede.ler_instantaneo(bytes)
	if inst.is_empty():
		return
	var agora := _agora()
	var t := float(inst["t"])
	_relogio_rede.amostrar(t, agora)
	var lista: Dictionary = inst["jogadores"]
	for id: int in lista:
		if id == meu_id or not jogadores.has(id):
			continue
		var e: Dictionary = lista[id]
		_garantir_avatar(id).buffer.empurrar(float(e["t"]), e)
		_visto_em[id] = agora


@rpc("authority", "call_remote", "reliable", 0)
func _relogio(segundos: float) -> void:
	if not is_finite(segundos):
		return
	var r := WorldState.relogio
	# O cliente avanca o proprio relogio na HUD; so se acerta quando descolou.
	# Acertar sempre faria o minuto da faixa tremer para tras e para a frente.
	if absf(r.segundos - segundos) > 1.0:
		r.segundos = fposmod(segundos, float(Relogio.DIA))


@rpc("authority", "call_remote", "unreliable", 0)
func _pings(lista: Dictionary) -> void:
	for k: Variant in lista:
		if typeof(k) == TYPE_INT and jogadores.has(int(k)):
			jogadores[int(k)]["ping"] = clampi(int(lista[k]), 0, 9999)
	lista_mudou.emit()


@rpc("authority", "call_remote", "reliable", 0)
func _chat(nome: String, texto: String) -> void:
	_recado("%s: %s" % [ProtocoloRede.sanear_nome(nome),
		ProtocoloRede.sanear_texto(texto, ProtocoloRede.CHAT_MAX)])


@rpc("authority", "call_remote", "reliable", 0)
func _aviso(texto: String) -> void:
	_recado(ProtocoloRede.sanear_texto(texto, ProtocoloRede.CHAT_MAX))


## O servidor recusou o movimento e devolve o jogador ao ultimo ponto aceito.
@rpc("authority", "call_remote", "reliable", 0)
func _corrigir(pos: Vector3) -> void:
	var c := corpo_local()
	if c == null or not ProtocoloRede.estado_valido({"pos": pos}):
		return
	if c is Player and (c as Player).dirigindo():
		return
	c.global_position = pos
	if c is Player:
		(c as Player).zerar_velocidade()
	_teleporte_pendente = true


# --- RPC: cliente -> servidor ------------------------------------------------------------

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _estado_do_cliente(bytes: PackedByteArray) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if not jogadores.has(id) or not _dentro_da_cota(id):
		return
	var pacote := ProtocoloRede.ler_pacote_do_cliente(bytes)
	if pacote.is_empty():
		return
	var seq := int(pacote["seq"])
	if seq <= int(_ultimo_seq.get(id, -1)):
		return
	_ultimo_seq[id] = seq
	var e: Dictionary = pacote["estado"]
	var agora := _agora()
	var t_amostra := ProtocoloRede.hora_de_amostra_aceita(float(pacote["t"]), agora)
	var val: ValidadorMovimento = _validadores[id]
	if not val.conferir(e["pos"], int(e["flags"]), int(e["espaco"]), seq, agora):
		_registrar_suspeita(id, val)
		if config.validacao == "corrigir":
			_corrigir.rpc_id(id, val.ultimo_aceito())
			return
	_estados[id] = e
	_amostrado_em[id] = t_amostra
	_visto_em[id] = agora
	if modo == Modo.HOSPEDANDO:
		_garantir_avatar(id).buffer.empurrar(t_amostra, e)


@rpc("any_peer", "call_remote", "reliable", 0)
func _pedir_chat(texto: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if not jogadores.has(id):
		return
	var agora := _agora()
	var janela: Array = _cotas_chat.get(id, [])
	janela = janela.filter(func(t: float) -> bool: return agora - t < 5.0)
	if janela.size() >= TETO_CHAT:
		return
	janela.append(agora)
	_cotas_chat[id] = janela
	_difundir_chat(id, ProtocoloRede.sanear_texto(texto, ProtocoloRede.CHAT_MAX))


# --- laco ---------------------------------------------------------------------------------

func _process(delta: float) -> void:
	match modo:
		Modo.HOSPEDANDO, Modo.DEDICADO:
			_processar_servidor(delta)
		Modo.CLIENTE:
			_processar_cliente(delta)


func _processar_servidor(delta: float) -> void:
	var agora := _agora()
	if modo == Modo.DEDICADO:
		# Quem anda o relogio da cidade e a HUD (hud_cidade.gd). O dedicado nao
		# tem HUD — sem esta linha a cidade dele fica as 22:43 para sempre, e todo
		# cliente que entra e puxado de volta para la.
		WorldState.relogio.avancar(delta)
	elif modo == Modo.HOSPEDANDO:
		var e := _estado_local()
		if not e.is_empty():
			_estados[1] = e
			_amostrado_em[1] = agora

	_acc_tick += delta
	var passo := 1.0 / float(ProtocoloRede.TICK_HZ)
	if _acc_tick >= passo:
		# fmod e nao subtracao: depois de um engasgo de 300 ms nao se mandam seis
		# instantaneos de uma vez, manda-se um, com a hora certa.
		_acc_tick = fmod(_acc_tick, passo)
		_tick += 1
		_enviar_instantaneos(agora)

	_acc_relogio += delta
	if _acc_relogio >= INTERVALO_RELOGIO:
		_acc_relogio = 0.0
		for id: int in _destinos():
			_relogio.rpc_id(id, WorldState.relogio.segundos)

	_acc_ping += delta
	if _acc_ping >= INTERVALO_PING:
		_acc_ping = 0.0
		_medir_pings()

	if modo == Modo.HOSPEDANDO:
		_desenhar_avatares(agora, delta)


func _processar_cliente(delta: float) -> void:
	# Estado so sai depois do primeiro instantaneo (~50 ms apos entrar): antes
	# dele nao ha relogio para carimbar, e um carimbo de outra fonte nos primeiros
	# pacotes faz a linha do tempo do jogador pular no meio (medido no teste: o bot
	# que entrou depois aparecia 80 cm fora do lugar no primeiro segundo).
	_acc_tick += delta
	var passo := 1.0 / float(ProtocoloRede.TICK_HZ)
	if _acc_tick >= passo and _relogio_rede.pronto():
		_acc_tick = fmod(_acc_tick, passo)
		var e := _estado_local()
		if not e.is_empty():
			_seq += 1
			_estado_do_cliente.rpc_id(1, ProtocoloRede.pacote_do_cliente(
				_seq, tempo_servidor(), e))
	if _relogio_rede.pronto():
		_desenhar_avatares(_relogio_rede.agora(_agora()), delta)


## Um instantaneo por cliente, so com quem interessa a ele: mesmo espaco e dentro
## do raio. E aqui que o custo por jogador se decide — com 32 jogadores
## espalhados, cada um recebe os poucos que estao perto.
func _enviar_instantaneos(agora: float) -> void:
	var raio2 := ProtocoloRede.RAIO_INTERESSE * ProtocoloRede.RAIO_INTERESSE
	for destino: int in _destinos():
		var dele: Dictionary = _estados.get(destino, {})
		var entradas: Array = []
		for id: int in _estados:
			if id == destino or not jogadores.has(id):
				continue
			var e: Dictionary = _estados[id]
			if not dele.is_empty():
				if int(e["espaco"]) != int(dele["espaco"]):
					continue
				var pa: Vector3 = e["pos"]
				var pb: Vector3 = dele["pos"]
				if Vector2(pa.x - pb.x, pa.z - pb.z).length_squared() > raio2:
					continue
			var ent := e.duplicate()
			ent["id"] = id
			ent["t"] = float(_amostrado_em.get(id, agora))
			entradas.append(ent)
		_instantaneo.rpc_id(destino, ProtocoloRede.instantaneo(_tick, agora, entradas))


func _desenhar_avatares(t_servidor: float, delta: float) -> void:
	var agora := _agora()
	var t_desenho := t_servidor - ProtocoloRede.ATRASO_INTERPOLACAO
	var c := corpo_local()
	var espaco_local := espaco_do_corpo(c) if c != null else -1
	var camera := get_viewport().get_camera_3d()
	for id: int in _avatares:
		var av: AvatarRemoto = _avatares[id]
		av.t_desenho = t_desenho
		if agora - float(_visto_em.get(id, -INF)) > SUMIR_APOS:
			av.desenhar({}, delta, espaco_local, camera)
			continue
		# Nada chegou ainda para o instante que se desenha: o boneco espera. Mostrar
		# a primeira amostra antes da hora dela e congelar o amigo no lugar por
		# ate um atraso inteiro e depois ve-lo dar um pulo — medido: 85 cm de
		# erro no boneco que acabou de entrar.
		if not av.buffer.cobre(t_desenho):
			av.desenhar({}, delta, espaco_local, camera)
			continue
		av.desenhar(av.buffer.amostrar(t_desenho), delta, espaco_local, camera)


## Para quem o servidor pode mandar agora: na lista, e com o ENet ainda
## conectado. Um peer no meio da desconexao continua em `get_peers()` por um
## quadro e recusa pacote ("max channels: 0") — medido com dois bots saindo juntos.
func _destinos() -> Array[int]:
	var saida: Array[int] = []
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	for id: int in multiplayer.get_peers():
		if not jogadores.has(id):
			continue
		if enet != null:
			var p := enet.get_peer(id)
			if p == null or p.get_state() != ENetPacketPeer.STATE_CONNECTED:
				continue
		saida.append(id)
	return saida


func _medir_pings() -> void:
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet == null:
		return
	var lista := {}
	for id: int in jogadores:
		if id == meu_id:
			lista[id] = 0
			continue
		var p := enet.get_peer(id)
		if p != null:
			lista[id] = int(p.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
	for id: int in lista:
		jogadores[id]["ping"] = lista[id]
	for id: int in _destinos():
		_pings.rpc_id(id, lista)
	lista_mudou.emit()


# --- estado local -------------------------------------------------------------------------

func _estado_local() -> Dictionary:
	var c := corpo_local()
	if c == null:
		return {}
	var pos := c.global_position
	var yaw := c.global_rotation.y
	var rapidez := 0.0
	var flags := 0
	var e := {}
	if c is Player:
		var p := c as Player
		rapidez = Vector2(p.velocity.x, p.velocity.z).length()
		if p.get(&"_agachado") == true:
			flags |= ProtocoloRede.F_AGACHADO
		if p.lanterna_ligada:
			flags |= ProtocoloRede.F_LANTERNA
		if p.is_on_floor():
			flags |= ProtocoloRede.F_NO_CHAO
		if rapidez > Player.VEL_ANDAR + 0.4:
			flags |= ProtocoloRede.F_CORRENDO
		var carro: Carro = p.carro() if p.dirigindo() else null
		if carro != null and is_instance_valid(carro):
			flags |= ProtocoloRede.F_CARRO
			pos = carro.global_position
			yaw = carro.global_rotation.y
			rapidez = carro.linear_velocity.length()
			e["modelo"] = int(carro.modelo)
			e["semente"] = carro.semente
		elif p.get(&"_bike") != null:
			flags |= ProtocoloRede.F_BICICLETA
	else:
		flags = int(c.get_meta(&"flags", ProtocoloRede.F_NO_CHAO))
		rapidez = float(c.get_meta(&"rapidez", 0.0))

	var espaco := espaco_do_corpo(c)
	# Teletransporte local (entrar em interior, respawn, carregar save): avisa, e
	# quem desenha corta em vez de deslizar o amigo por dentro das paredes.
	if _teleporte_pendente or espaco != _ultimo_espaco_enviado or (
			_ultima_pos_enviada != Vector3.INF
			and pos.distance_to(_ultima_pos_enviada) > ProtocoloRede.SALTO_TELEPORTE
			and not (flags & ProtocoloRede.F_CARRO)):
		flags |= ProtocoloRede.F_TELEPORTE
	_teleporte_pendente = false
	_ultima_pos_enviada = pos
	_ultimo_espaco_enviado = espaco
	e["pos"] = pos
	e["yaw"] = yaw
	e["rapidez"] = rapidez
	e["flags"] = flags
	e["espaco"] = espaco
	return e


# --- chegada ------------------------------------------------------------------------------

## Onde quem entra aparece, e para onde ele olha: [posicao, olhar].
##
## No jogo aberto para amigos, do lado do anfitriao — entrar no mundo de alguem
## e aparecer perto dele, nao na praca a dois quarteiroes. No dedicado, no ponto
## em que a cidade poe o jogador. Em volta de um circulo, para dois que chegam
## juntos nao nascerem um dentro do outro.
func _ponto_de_chegada(slot: int) -> Array:
	var base := ponto_inicial()
	if modo == Modo.HOSPEDANDO and _estados.has(1):
		var host: Dictionary = _estados[1]
		if int(host["espaco"]) == ProtocoloRede.ESPACO_RUA and not (
				int(host["flags"]) & ProtocoloRede.F_CARRO):
			base = host["pos"]
	var angulo := TAU * float(slot % 8) / 8.0
	var raio := 1.6 + 0.8 * floorf(float(slot) / 8.0)
	return [base + Vector3(cos(angulo), 0.0, sin(angulo)) * raio, base + Vector3.UP * 1.5]


## Leva o jogador local ao ponto de chegada sem cair do mapa.
##
## O chunk do destino pode nao existir ainda: o ChunkManager monta em thread,
## depois que o jogador chega. Soltar a fisica antes do chao existir e ver o
## amigo cair pela cidade. Entao o corpo fica parado no ar ate um raio para baixo
## achar chao — a mesma espera da bicicleta do respawn (cidade.gd).
func _chegar(destino: Vector3, olhar: Vector3) -> void:
	var p := corpo_local() as Player
	if p == null or p.travado or p.dirigindo():
		return
	if espaco_do_corpo(p) != ProtocoloRede.ESPACO_RUA:
		return
	p.set_physics_process(false)
	p.global_position = destino + Vector3.UP * 0.5
	p.zerar_velocidade()
	_teleporte_pendente = true
	for _i in 360:
		await get_tree().physics_frame
		if not is_instance_valid(p):
			return
		var q := PhysicsRayQueryParameters3D.create(
			destino + Vector3.UP * 3.0, destino + Vector3.DOWN * 6.0)
		q.exclude = [p.get_rid()]
		var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			p.global_position = (hit["position"] as Vector3) + Vector3.UP * 0.05
			break
	p.set_physics_process(true)
	p.olhar_para(olhar)


## O ponto em que a cidade.tscn poe o jogador, lido da cena sem instancia-la.
## Constante escrita a mao envelheceria na primeira vez que alguem mudasse o
## nascimento; a cena e a verdade.
func _ler_ponto_inicial() -> Vector3:
	var reserva := Vector3(-80.0, 0.5, 112.0)
	var cena := load("res://scenes/test/cidade.tscn") as PackedScene
	if cena == null:
		return reserva
	var st := cena.get_state()
	for i in st.get_node_count():
		if st.get_node_name(i) != &"Player" or st.get_node_path(i) != NodePath("./Player"):
			continue
		for j in st.get_node_property_count(i):
			if st.get_node_property_name(i, j) == &"transform":
				return (st.get_node_property_value(i, j) as Transform3D).origin
	return reserva


# --- apoio --------------------------------------------------------------------------------

func _ler_linha_de_comando() -> void:
	var args := OS.get_cmdline_user_args()
	var hospedar_porta := -1
	var entrar_em := ""
	var senha := ""
	var maximo := ProtocoloRede.MAX_JOGADORES_PADRAO
	for a: String in args:
		if a == "--mp-hospedar":
			hospedar_porta = ProtocoloRede.PORTA_PADRAO
		elif a.begins_with("--mp-hospedar="):
			hospedar_porta = a.trim_prefix("--mp-hospedar=").to_int()
		elif a.begins_with("--mp-entrar="):
			entrar_em = a.trim_prefix("--mp-entrar=")
		elif a.begins_with("--mp-senha="):
			senha = a.trim_prefix("--mp-senha=")
		elif a.begins_with("--mp-max="):
			maximo = a.trim_prefix("--mp-max=").to_int()
		elif a.begins_with("--mp-nome="):
			_perfil_injetado["nome"] = a.trim_prefix("--mp-nome=")
		elif a == "--mp-painel" and _painel != null:
			_painel.abrir()
	if hospedar_porta > 0:
		hospedar(hospedar_porta, maximo, "", senha)
	elif not entrar_em.is_empty():
		entrar(entrar_em, -1, senha)


func _mudar_modo(novo: Modo) -> void:
	if novo == modo:
		return
	modo = novo
	modo_mudou.emit(modo)


func _limpar() -> void:
	for id: int in _avatares.keys():
		_esquecer(id)
	jogadores.clear()
	_nonces.clear()
	_pedidos.clear()
	_estados.clear()
	_amostrado_em.clear()
	_validadores.clear()
	_ultimo_seq.clear()
	_cotas.clear()
	_cotas_chat.clear()
	_log_suspeita.clear()
	_visto_em.clear()
	_relogio_rede.zerar()
	_seq = 0
	_tick = 0
	_acc_tick = 0.0
	_ultima_pos_enviada = Vector3.INF
	_ultimo_espaco_enviado = -1
	lista_mudou.emit()


func _esquecer(id: int) -> void:
	_estados.erase(id)
	_amostrado_em.erase(id)
	_validadores.erase(id)
	_ultimo_seq.erase(id)
	_cotas.erase(id)
	_cotas_chat.erase(id)
	_visto_em.erase(id)
	if _avatares.has(id):
		(_avatares[id] as Node).queue_free()
		_avatares.erase(id)


func _garantir_avatar(id: int) -> AvatarRemoto:
	if _avatares.has(id):
		return _avatares[id]
	var av := AvatarRemoto.new()
	_raiz_avatares.add_child(av)
	av.configurar(id, jogadores.get(id, {"nome": "?", "aparencia": {}}))
	av.visible = false
	_avatares[id] = av
	return av


func _perfil_seguro(p: Variant) -> Dictionary:
	var d: Dictionary = p if typeof(p) == TYPE_DICTIONARY else {}
	return {
		"nome": ProtocoloRede.sanear_nome(String(d.get("nome", ""))),
		"aparencia": ProtocoloRede.sanear_aparencia(d.get("aparencia", {})),
		"ping": clampi(int(d.get("ping", 0)), 0, 9999),
	}


func _dentro_da_cota(id: int) -> bool:
	var agora := _agora()
	var c: Dictionary = _cotas.get(id, {"t": agora, "n": 0})
	if agora - float(c["t"]) >= 1.0:
		c = {"t": agora, "n": 0}
	c["n"] = int(c["n"]) + 1
	_cotas[id] = c
	return int(c["n"]) <= TETO_ESTADO_POR_S


func _registrar_suspeita(id: int, val: ValidadorMovimento) -> void:
	var agora := _agora()
	if agora - float(_log_suspeita.get(id, -INF)) < 1.0:
		return
	_log_suspeita[id] = agora
	print("[servidor] movimento implausivel de %s (peer %d): %s — %d no total" % [
		jogadores[id]["nome"], id, val.ultima_suspeita, val.suspeitas])


func _difundir_chat(id: int, texto: String) -> void:
	if texto.is_empty():
		return
	var nome := String(jogadores[id]["nome"]) if jogadores.has(id) else "SERVIDOR"
	for destino: int in _destinos():
		_chat.rpc_id(destino, nome, texto)
	_recado("%s: %s" % [nome, texto])


func _meu_nome() -> String:
	if _perfil_injetado.has("nome"):
		return ProtocoloRede.sanear_nome(String(_perfil_injetado["nome"]))
	var ficha := RegistroCivil.jogador
	var n := String(ficha.get("primeiro", ""))
	if n.is_empty():
		n = String(ficha.get("nome", "")).get_slice(" ", 0)
	return ProtocoloRede.sanear_nome(n)


func _minha_aparencia() -> Dictionary:
	if _perfil_injetado.has("aparencia"):
		return ProtocoloRede.sanear_aparencia(_perfil_injetado["aparencia"])
	return ProtocoloRede.sanear_aparencia(
		RegistroCivil.jogador.get("aparencia", ProtocoloRede.aparencia_de_referencia()))


func _recado(texto: String) -> void:
	print("[sessao] %s" % texto)
	recado.emit(texto)


## Relogio monotono em segundos, com a precisao de um double. `Time.get_ticks_usec`
## e nao o tempo do sistema: ajuste de hora do Windows no meio da partida nao pode
## fazer o amigo voltar no tempo.
func _agora() -> float:
	return float(Time.get_ticks_usec()) / 1000000.0
