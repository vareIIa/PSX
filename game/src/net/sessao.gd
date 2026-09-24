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
## sao `AvatarRemoto`, fora do grupo. Nenhum dos 43 lugares do jogo que procuram
## "o jogador" (contados em 21/09/2026) precisa saber que existe rede para o amigo
## aparecer na rua.
##
## Plano: MULTIPLAYER/PLANO/03_ARQUITETURA.md, 04, 18 e 20.
extends Node

signal modo_mudou(modo: int)
signal lista_mudou()
signal recado(texto: String)
signal conexao_falhou(motivo: String)

enum Modo { SOLO, HOSPEDANDO, DEDICADO, CONECTANDO, CLIENTE }

## Canais ENet: 0 evento confiavel, 1 estado continuo, 2 carga (o mundo de quem
## entra; ver MundoEmRede).
const CANAL_EVENTO := 0
const CANAL_ESTADO := 1
const CANAIS := 3

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
## Dois corpos a pe mais perto que isto se afastam, sem bloqueio (plano 07 secao
## 6). Bloqueio duro com 120 ms de atraso vira briga de porta no corredor.
const DISTANCIA_PESSOAL := 0.55
## Velocidade maxima do empurrao, em m/s: menos que um passo, para ninguem ser
## arrastado por quem anda para cima dele.
const EMPURRAO := 1.6

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
## O mundo compartilhado (porta, item, carga de entrada). Filho, e nao mais
## codigo aqui dentro: este arquivo ja passa de 1.400 linhas.
var _mundo: MundoEmRede
## Caido e levantar (plano 08 secao 3.3). Publico: o `Desmaio`, o boneco do
## amigo e o bot falam com ele direto.
var socorro: SocorroEmRede
## Dar item a um amigo (plano 08 secao 1.3): `Sessao.mochilas.dar(alvo, espaco, qtd)`.
var mochilas: MochilasEmRede
## Em rede o menu nao pausa: trava o jogador e marca `F_AUSENTE` (`pausar`).
var _ausente := false
var _travado_antes_da_pausa := false
## Campos privados de outra frente que a rede le por nome e que ja faltaram uma
## vez: avisa uma vez so, e nao a 20 Hz.
var _campos_ausentes: Dictionary = {}

# --- assinatura do mundo (ver AssinaturaDoMundo) ---
var _assinatura: String = ""
## Escrita pela thread; lida so depois de `wait_for_task_completion`.
var _assinatura_da_thread: String = ""
var _tarefa_assinatura: int = -1
var _assinatura_falhou := false


## Quantas vezes o servidor devolveu ESTE jogador ao ultimo ponto aceito. Para
## o teste de ponta a ponta: rota honesta (interior, desmaio, save) tem de dar 0.
var correcoes := 0
## `--mp-validacao=corrigir`: o anfitriao sobe com a validacao dura.
var _validacao_pedida := ""
## `--traco-servidor`: cada estado recebido no console (diagnostico de rede).
var _traco_servidor := OS.get_cmdline_user_args().has("--traco-servidor")


## Movimentos implausiveis contados pelo servidor, de todos os jogadores.
func suspeitas_total() -> int:
	var n := 0
	for id: int in _validadores:
		n += (_validadores[id] as ValidadorMovimento).suspeitas
	return n


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
	# O nome importa: RPC acha o no pelo caminho, e /root/Sessao/Mundo tem de ser
	# o mesmo no jogo, no bot e no dedicado.
	_mundo = MundoEmRede.new()
	_mundo.name = "Mundo"
	add_child(_mundo)
	socorro = SocorroEmRede.new()
	socorro.name = "Socorro"
	add_child(socorro)
	mochilas = MochilasEmRede.new()
	mochilas.name = "Mochilas"
	add_child(mochilas)

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

	# Carregar um save no meio da sessao troca o mundo inteiro de uma vez.
	SaveGame.carregou.connect(_ao_carregar_save)

	set_process(false)
	set_physics_process(false)
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
	if not _validacao_pedida.is_empty():
		c.validacao = _validacao_pedida
	c.nome = nome if not nome.is_empty() else "MUNDO DE %s" % _meu_nome()
	c.senha = senha
	return _subir_servidor(c, Modo.HOSPEDANDO)


## Sobe o servidor dedicado. Chamado por `ServidorDedicado`.
##
## No dedicado a assinatura da cidade e calculada AQUI, na subida e sem thread.
## E o unico momento em que o processo pode parar sem ninguem esperando; em
## thread, a primeira compilacao do gerador (o `ChunkBuilder` e as dependencias
## dele, que o dedicado nunca carregava) disputava o carregador com o laco e
## custou um quadro de 100-120 ms com oito bots entrando juntos (medido).
func hospedar_dedicado(c: ConfigServidor) -> Error:
	if _assinatura.is_empty():
		var t0 := Time.get_ticks_usec()
		_calcular_assinatura()
		_assinatura = _assinatura_da_thread
		print("[servidor] assinatura da cidade %s (%d ms)" % [
			_assinatura if not _assinatura.is_empty() else "INDISPONIVEL",
			(Time.get_ticks_usec() - t0) / 1000])
		if _assinatura.is_empty():
			_assinatura_falhou = true
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
	var err := peer.create_client(host, p, CANAIS)
	if err != OK:
		_recado("Nao deu para ligar para %s:%d (erro %d)." % [host, p, err])
		return err
	if CriptoRede.ligada():
		err = peer.host.dtls_client_setup(host, CriptoRede.opcoes_do_cliente())
		if err != OK:
			peer.close()
			_recado("Nao deu para cifrar a ligacao (erro %d)." % err)
			return err
	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	# A assinatura da cidade vai no pedido. Comeca agora, em thread: a conexao
	# e o desafio levam mais que os ~80 ms dela.
	assinatura_do_mundo()
	_mundo.antes_de_entrar()
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
	# Antes de limpar: quem jogava no mundo de outro volta ao proprio (P11).
	_mundo.ao_sair()
	_limpar()
	_mudar_modo(Modo.SOLO)
	set_process(false)
	set_physics_process(false)
	# Quem estava com o menu aberto quando a sessao caiu volta ao solo com o menu
	# aberto: a arvore para, como pararia se ele o tivesse aberto sozinho.
	if _ausente:
		var p := jogador_local()
		if p != null:
			p.travar(_travado_antes_da_pausa)
		_ausente = false
		get_tree().paused = true
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


## O `Player` deste processo. Nulo no dedicado, e enquanto a cidade nao existe.
func jogador_local() -> Player:
	return corpo_local() as Player


## Os corpos de gente que este processo enxerga: o jogador local e os bonecos
## desenhados. `espaco` < 0 = qualquer espaco.
##
## Em SOLO devolve so o jogador local, e por isso quem troca "o jogador" por
## esta lista funciona igual sozinho (plano 06 secao 5).
func corpos(espaco: int = -1) -> Array[Node3D]:
	var saida: Array[Node3D] = []
	var p := corpo_local()
	if p != null and (espaco < 0 or espaco_do_corpo(p) == espaco):
		saida.append(p)
	for id: int in _avatares:
		var av: AvatarRemoto = _avatares[id]
		if not av.visible or av.estado.is_empty():
			continue
		if espaco >= 0 and int(av.estado.get("espaco", -1)) != espaco:
			continue
		saida.append(av)
	return saida


## O corpo mais perto de `origem`, ate `raio`. Nulo se ninguem.
func mais_perto(origem: Vector3, raio: float, espaco: int = -1) -> Node3D:
	var melhor: Node3D = null
	var d2 := raio * raio
	for c: Node3D in corpos(espaco):
		var d := c.global_position.distance_squared_to(origem)
		if d < d2:
			d2 = d
			melhor = c
	return melhor


## O jogo acabou de mover o jogador local de uma vez (respawn, carregar save,
## acordar). Quem desenha corta seco em vez de deslizar o corpo pela cidade, e o
## servidor nao conta como velocidade. Em SOLO nao faz nada.
func anunciar_teletransporte() -> void:
	if em_rede():
		_teleporte_pendente = true


## A pausa do jogo. Em SOLO, exatamente a de sempre: a arvore para. Em rede o
## mundo nao e so deste processo — o anfitriao que abre a prancha congelaria no
## meio da rua para todos e pararia o relogio da cidade de todo mundo (quem anda o
## relogio e a HUD, que pausa junto). Entao, em rede, trava so o jogador local e
## avisa os outros (`F_AUSENTE`). Plano 06 secao 6.
##
## Quem chama nao precisa saber qual dos dois aconteceu: `pausado()` responde.
func pausar(sim: bool) -> void:
	if not em_rede():
		get_tree().paused = sim
		return
	if sim == _ausente:
		return
	_ausente = sim
	var p := jogador_local()
	if p == null:
		return
	# Quem ja estava preso (sentado no sofa, em conversa) volta preso ao fechar o
	# menu. Soltar aqui largaria o jogador de pe no meio do sofa.
	if sim:
		_travado_antes_da_pausa = p.travado
		p.travar(true)
	else:
		p.travar(_travado_antes_da_pausa)


func pausado() -> bool:
	return _ausente if em_rede() else get_tree().paused


## Pode abrir o que em solo pausaria a arvore. Em rede nada pausa, entao o que
## depende de mundo parado (modo foto congelando a cena) pergunta aqui.
func mundo_para() -> bool:
	return not em_rede()


# --- mundo compartilhado (MundoEmRede, plano 04 secoes 4 a 7) ----------------------

## Muda uma chave do mundo. Em SOLO e o `WorldState.definir` de sempre; em rede e
## classe 2: o efeito ja aconteceu no no que chama, o pedido vai junto, e a chave
## volta a `padrao` se o servidor negar.
func mudar_mundo(coord: Vector2i, chave: StringName, valor: Variant,
		padrao: Variant = null) -> void:
	_mundo.mudar(coord, chave, valor, padrao)


## Pede ao servidor um item do chao (classe 1). `ao_responder(ok, motivo)` diz o
## que ele decidiu; com `ok`, o item ja esta na mochila.
func pedir_item(coord: Vector2i, indice: int, item: StringName, qtd: int,
		ao_responder: Callable = Callable()) -> void:
	_mundo.pedir_item(coord, indice, item, qtd, ao_responder)


## Da para mexer no mundo agora. Falso so no cliente que ainda espera a carga.
func mundo_pronto() -> bool:
	return _mundo.pronto()


func cabe_na_mochila(item: StringName, qtd: int) -> bool:
	return MundoEmRede.cabe(item, qtd)


## O mundo que o save desta maquina grava: [mundo, visitados]. Jogando no mundo
## de outro, e o proprio (P9).
func mundo_para_salvar() -> Array:
	return _mundo.para_salvar()


func mundo() -> MundoEmRede:
	return _mundo


## O ultimo estado ACEITO de um jogador, no servidor. Vazio se nao ha nenhum.
func estado_aceito(id: int) -> Dictionary:
	return _estados.get(id, {})


## Para quem o servidor pode mandar agora (ver `_destinos`).
func destinos() -> Array[int]:
	return _destinos()


## A assinatura da cidade desta maquina (`AssinaturaDoMundo`). Vazia enquanto a
## thread calcula; comeca a calcular na primeira chamada.
func assinatura_do_mundo() -> String:
	if not _assinatura.is_empty() or _assinatura_falhou:
		return _assinatura
	if _tarefa_assinatura < 0:
		_tarefa_assinatura = WorkerThreadPool.add_task(_calcular_assinatura, false,
			"assinatura do mundo")
		return ""
	if WorkerThreadPool.is_task_completed(_tarefa_assinatura):
		WorkerThreadPool.wait_for_task_completion(_tarefa_assinatura)
		_tarefa_assinatura = -1
		_assinatura = _assinatura_da_thread
		# A thread terminou sem resultado: o gerador quebrou no meio (um script da
		# cidade que nao compila, por exemplo). Esperar para sempre travaria a
		# entrada; segue sem assinatura, e a versao continua valendo.
		if _assinatura.is_empty():
			_assinatura_falhou = true
			push_warning("[sessao] a assinatura da cidade nao saiu; a entrada segue so pela versao")
	return _assinatura


## Espera a assinatura ficar pronta. Coroutine: `await esperar_assinatura()`.
## Devolve vazio se ela nao pode ser calculada.
func esperar_assinatura() -> String:
	while assinatura_do_mundo().is_empty() and not _assinatura_falhou:
		await get_tree().process_frame
	return _assinatura


func _calcular_assinatura() -> void:
	# Lambda, e nao `ChunkBuilder.construir` direto: e o mesmo construtor que o
	# ChunkManager chama em thread, entao ja e seguro aqui.
	_assinatura_da_thread = AssinaturaDoMundo.calcular(
		func(cx: int, cz: int) -> Dictionary: return ChunkBuilder.construir(cx, cz))


## Em que espaco o corpo esta (rua, estrada, qual interior).
func espaco_do_corpo(c: Node3D) -> int:
	var y := c.global_position.y
	if y > ProtocoloRede.Y_ESTRADA:
		return ProtocoloRede.ESPACO_ESTRADA
	if y > ProtocoloRede.Y_INTERIOR:
		return ProtocoloRede.espaco_interior(Interiores.tipo_atual(), _semente_do_interior())
	return ProtocoloRede.ESPACO_RUA


## A semente do interior atual. `interiores.gd` e de outra frente: se ela ganhar
## o acessor publico (plano 06 secao 8), ele vale; senao, o campo privado por nome.
## Se o nome sumir, todos os interiores caem num espaco so — o amigo do bar
## apareceria no mercado —, e por isso o aviso.
func _semente_do_interior() -> int:
	if Interiores.has_method(&"semente_atual"):
		return int(Interiores.call(&"semente_atual"))
	return int(_campo(Interiores, &"_semente", 0))


## Le um campo de um no de outra frente por nome. Se o campo nao existir mais,
## avisa UMA vez e devolve `padrao`: a rede passa a mandar um valor neutro em vez
## de quebrar, mas ninguem fica sem saber.
func _campo(o: Object, nome: StringName, padrao: Variant) -> Variant:
	if o != null and nome in o:
		return o.get(nome)
	if not _campos_ausentes.has(nome):
		_campos_ausentes[nome] = true
		push_warning("[sessao] campo '%s' sumiu de %s; a rede manda '%s' no lugar" % [
			nome, o, padrao])
	return padrao


## [host, porta]. Ver `ProtocoloRede.separar_endereco`.
static func separar_endereco(s: String) -> Array:
	return ProtocoloRede.separar_endereco(s)


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
	var err := peer.create_server(c.porta, c.max_jogadores + 4, CANAIS)
	if err != OK:
		_recado("Nao deu para abrir a porta %d (erro %d). Outro programa usando?" % [c.porta, err])
		return err
	# Defeito do Godot (enet_multiplayer_peer.cpp, create_server): ele passa
	# `max_channels + 2` na vaga do `in_bandwidth` do enet_host_create. O servidor
	# anunciava "recebo 5 bytes/s", o ENet dividia isso entre os conectados e o
	# `enet_host_bandwidth_throttle` de cada cliente cravava o teto do
	# estrangulador em 1 de 32: so 2 estados em 32 saiam, por segundos (medido
	# 23/09 pelo PEER_PACKET_THROTTLE_LIMIT). Zerar antes de alguem conectar faz o
	# VERIFY_CONNECT ja anunciar "sem limite".
	peer.host.bandwidth_limit(0, 0)
	if CriptoRede.ligada():
		err = peer.host.dtls_server_setup(CriptoRede.opcoes_do_servidor())
		if err != OK:
			peer.close()
			_recado("Nao deu para cifrar a sessao (erro %d)." % err)
			return err
	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	# Le o ponto de nascimento AGORA, com ninguem conectado. Ler na primeira
	# entrada carrega a cidade.tscn (e o player, e os scripts dela) no meio do
	# laco do servidor: medido 130 ms de quadro parado para todo mundo.
	ponto_inicial()
	# A assinatura da cidade vai no desafio de todo mundo que entrar. Em thread.
	assinatura_do_mundo()
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
		"cidade": assinatura_do_mundo(),
	}


# --- autenticacao ------------------------------------------------------------------------
# Roda ANTES de o peer existir para o jogo: sem `complete_auth`, nenhum RPC dele
# e entregue. Ver ProtocoloRede, secao de autenticacao.

func _ao_peer_autenticando(id: int) -> void:
	if not multiplayer.is_server():
		return
	# O desafio leva a assinatura da cidade. No dedicado ela ficou pronta ao subir;
	# no anfitriao que acabou de abrir, pode faltar uma fracao de segundo.
	var cidade := await esperar_assinatura()
	var mp := multiplayer as SceneMultiplayer
	if not eh_servidor() or not mp.get_authenticating_peers().has(id):
		return
	var nonce := ProtocoloRede.novo_nonce()
	_nonces[id] = nonce
	mp.send_auth(id, ProtocoloRede.mensagem({
		"tipo": "desafio",
		"jogo": ProtocoloRede.JOGO,
		"v": ProtocoloRede.VERSAO,
		"cidade": cidade,
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
		jogadores.size() + _pedidos.size(), config.max_jogadores, _assinatura)
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
			_responder_desafio(msg)
		"veredito":
			if bool(msg.get("ok", false)):
				mp.complete_auth(1)
			else:
				_recusa = String(msg.get("motivo", ProtocoloRede.RECUSA_PEDIDO))
				_falhar.call_deferred(_recusa)


## O desafio do servidor: confere jogo, versao e cidade, e manda o pedido.
##
## A cidade e conferida aqui E no servidor. Aqui, para quem entra ler o motivo
## sem esperar a volta; la, porque o servidor e quem decide.
func _responder_desafio(msg: Dictionary) -> void:
	if String(msg.get("jogo", "")) != ProtocoloRede.JOGO:
		_falhar.call_deferred(ProtocoloRede.RECUSA_JOGO)
		return
	if int(msg.get("v", -1)) != ProtocoloRede.VERSAO:
		_falhar.call_deferred(ProtocoloRede.RECUSA_VERSAO)
		return
	var cidade := await esperar_assinatura()
	if modo != Modo.CONECTANDO:
		return
	var cidade_dele := String(msg.get("cidade", ""))
	if not cidade_dele.is_empty() and cidade_dele != cidade:
		print("[sessao] cidade do servidor %s, a minha %s" % [cidade_dele, cidade])
		_falhar.call_deferred(ProtocoloRede.RECUSA_CIDADE)
		return
	nome_servidor = ProtocoloRede.sanear_texto(String(msg.get("nome", "")), 32).to_upper()
	var prova := ""
	if bool(msg.get("senha", false)):
		prova = ProtocoloRede.prova_de_senha(
			String(_pedido_local.get("senha", "")), String(msg.get("nonce", "")))
	(multiplayer as SceneMultiplayer).send_auth(1, ProtocoloRede.mensagem({
		"tipo": "pedido",
		"jogo": ProtocoloRede.JOGO,
		"v": ProtocoloRede.VERSAO,
		"cidade": cidade,
		"nome": _pedido_local.get("nome", ""),
		"aparencia": _pedido_local.get("aparencia", {}),
		"prova": prova,
	}))


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
		ProtocoloRede.sem_estrangular(enet.get_peer(id))

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
	# O mundo inteiro, no canal 2, antes de qualquer pedido dele valer.
	_mundo.enviar_carga(id)
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
		ProtocoloRede.sem_estrangular(enet.get_peer(1))


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


## Estado e instantaneo vao "unreliable" puro, sem sequencia do ENet. O
## "unreliable_ordered" do ENet amarra cada pacote ao numero de sequencia
## CONFIAVEL do canal: uma mensagem confiavel perdida (o Godot manda as de
## caminho quando alguem entra) segura todo estado posterior ate o reenvio. Com
## 150 ms de ida e volta e 2% de perda eram buracos de 0,5 a 1,2 s: seq 7 a 22 de
## um bot nunca chegavam (medido 23/09, `mp_teste.sh --rede-ruim`). A ordem quem
## garante e a propria rede do jogo: o servidor descarta seq velho, o buffer
## descarta amostra mais velha que a ultima, e o relogio usa o maximo da janela.
@rpc("authority", "call_remote", "unreliable", 1)
func _instantaneo(bytes: PackedByteArray) -> void:
	var inst := ProtocoloRede.ler_instantaneo(bytes)
	if inst.is_empty():
		return
	var agora := _agora()
	var t := float(inst["t"])
	_relogio_rede.amostrar(t, agora)
	var lista: Dictionary = inst["jogadores"]
	var t_agora := tempo_servidor()
	for id: int in lista:
		if id == meu_id or not jogadores.has(id):
			continue
		var e: Dictionary = lista[id]
		var t_e := float(e["t"])
		_garantir_avatar(id).buffer.empurrar(t_e, e, t_agora - t_e)
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
	_falar_no_avatar(-1, ProtocoloRede.sanear_nome(nome),
		ProtocoloRede.sanear_texto(texto, ProtocoloRede.CHAT_MAX))


## A linha de chat sai da boca de quem escreveu (`AvatarRemoto.falar`). O
## cliente so recebe o nome; acha o avatar por ele.
func _falar_no_avatar(id: int, nome: String, texto: String) -> void:
	if id < 0:
		for outro: int in jogadores:
			if String((jogadores[outro] as Dictionary).get("nome", "")) == nome:
				id = outro
				break
	if _avatares.has(id) and is_instance_valid(_avatares[id]):
		(_avatares[id] as AvatarRemoto).falar(texto)


@rpc("authority", "call_remote", "reliable", 0)
func _aviso(texto: String) -> void:
	_recado(ProtocoloRede.sanear_texto(texto, ProtocoloRede.CHAT_MAX))


## O servidor recusou o movimento e devolve o jogador ao ultimo ponto aceito.
@rpc("authority", "call_remote", "reliable", 0)
func _corrigir(pos: Vector3) -> void:
	correcoes += 1
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

@rpc("any_peer", "call_remote", "unreliable", 1)
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
	if _traco_servidor:
		print("[traco-srv] %s seq %d t %.3f agora %.3f aceita %.3f" % [
			jogadores[id]["nome"], seq, float(pacote["t"]), agora, t_amostra])
	var val: ValidadorMovimento = _validadores[id]
	var teleportes := val.teleportes
	if not val.conferir(e["pos"], int(e["flags"]), int(e["espaco"]), seq, agora):
		_registrar_suspeita(id, val)
		if config.validacao == "corrigir":
			_corrigir.rpc_id(id, val.ultimo_aceito())
			return
	elif val.teleportes > teleportes:
		# Aceito, mas contado: e o atalho que um cliente adulterado usaria.
		print("[servidor] %s (peer %d) se teletransportou para %s — %d no total" % [
			jogadores[id]["nome"], id, e["pos"], val.teleportes])
	_estados[id] = e
	_amostrado_em[id] = t_amostra
	_visto_em[id] = agora
	if modo == Modo.HOSPEDANDO:
		_garantir_avatar(id).buffer.empurrar(t_amostra, e, agora - t_amostra)


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


func _physics_process(delta: float) -> void:
	_afastar_dos_outros(delta)


## Dois amigos a pe no mesmo lugar se afastam devagar, sem bater (plano 07 secao
## 6). Cada maquina afasta so o PROPRIO jogador — o boneco do outro e desenho, e
## quem move o corpo dele e a maquina dele, que faz a mesma conta do lado de la.
## Somadas, as duas metades desfazem a sobreposicao sem ninguem empurrar ninguem
## pela rede.
##
## `move_and_collide`, e nao posicao: o empurrao respeita parede. Quem esta
## encostado num canto nao atravessa o canto porque o amigo chegou.
func _afastar_dos_outros(delta: float) -> void:
	var p := jogador_local()
	if p == null or p.travado or p.dirigindo() or _campo(p, &"_bike", null) != null:
		return
	var esp := espaco_do_corpo(p)
	var empurra := Vector3.ZERO
	for id: int in _avatares:
		var av: AvatarRemoto = _avatares[id]
		if not av.visible or av.estado.is_empty():
			continue
		# Carro e bicicleta sao colisao de verdade, na Fase 4; aqui so gente a pe.
		if int(av.estado.get("flags", 0)) & (ProtocoloRede.F_CARRO | ProtocoloRede.F_BICICLETA):
			continue
		if int(av.estado.get("espaco", -1)) != esp:
			continue
		var d := p.global_position - av.global_position
		if absf(d.y) > 1.5:
			continue
		d.y = 0.0
		var dist := d.length()
		if dist >= DISTANCIA_PESSOAL:
			continue
		# Os dois no mesmo ponto exato (chegada no mesmo lugar): qualquer lado
		# serve, e o id do outro escolhe um sem dividir por zero.
		var dir := d / dist if dist > 0.001 else Vector3(cos(float(id)), 0.0, sin(float(id)))
		empurra += dir * (1.0 - dist / DISTANCIA_PESSOAL)
	if empurra == Vector3.ZERO:
		return
	p.move_and_collide(empurra.limit_length(1.0) * EMPURRAO * delta)


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
	var c := corpo_local()
	var espaco_local := espaco_do_corpo(c) if c != null else -1
	var camera := get_viewport().get_camera_3d()
	for id: int in _avatares:
		var av: AvatarRemoto = _avatares[id]
		# Cada amigo no proprio atraso: o que mora longe (ou atras de Wi-Fi ruim)
		# chega mais velho, e desenhar todos no mesmo atraso fazia o de longe
		# viver de extrapolacao.
		var t_desenho := t_servidor - av.buffer.avancar_atraso(delta)
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
	var arfagem := 0.0
	var flags := 0
	var e := {}
	if c is Player:
		var p := c as Player
		rapidez = Vector2(p.velocity.x, p.velocity.z).length()
		# Campos privados do Player (outra frente): por nome, com aviso se sumirem.
		# Plano 06 secao 3 pede acessores publicos; ate la, `_campo`.
		arfagem = float(_campo(p, &"_pitch", 0.0))
		if _campo(p, &"_agachado", false) == true:
			flags |= ProtocoloRede.F_AGACHADO
		if p.lanterna_ligada:
			flags |= ProtocoloRede.F_LANTERNA
		if p.is_on_floor():
			flags |= ProtocoloRede.F_NO_CHAO
		if rapidez > Player.VEL_ANDAR + 0.4:
			flags |= ProtocoloRede.F_CORRENDO
		# Sentado: `Player.ocupar` poe o rotulo de saida (sofa, cadeira, o PS2).
		if not String(_campo(p, &"_rotulo_ocupacao", "")).is_empty():
			flags |= ProtocoloRede.F_SENTADO
		# Atropelado, no chao (TomboDoJogador): o amigo ve o corpo cair.
		var tombo := p.get_node_or_null(^"TomboDoJogador")
		if tombo != null and bool(tombo.call(&"caido")):
			flags |= ProtocoloRede.F_CAIDO
		# Vida baixa: o amigo ve o boneco mancar.
		if Inventario.vida * 10 <= Inventario.vida_maxima * 3:
			flags |= ProtocoloRede.F_FERIDO
		var carro: Carro = p.carro() if p.dirigindo() else null
		if carro != null and is_instance_valid(carro):
			# No carro, o que e de quem anda a pe nao vale; os bits sao do carro
			# (ProtocoloRede.F_FAROL, F_FREANDO, F_FREIO_DE_MAO).
			flags &= ProtocoloRede.F_NO_CHAO
			flags |= ProtocoloRede.F_CARRO
			if carro.ligado:
				flags |= ProtocoloRede.F_FAROL
			if _campo(carro, &"_freando", false) == true:
				flags |= ProtocoloRede.F_FREANDO
			if carro.freio_de_mao():
				flags |= ProtocoloRede.F_FREIO_DE_MAO
			pos = carro.global_position
			yaw = carro.global_rotation.y
			rapidez = carro.linear_velocity.length()
			arfagem = 0.0
			e["modelo"] = int(carro.modelo)
			e["semente"] = carro.semente
		elif _campo(p, &"_bike", null) != null:
			flags |= ProtocoloRede.F_BICICLETA
	else:
		flags = int(c.get_meta(&"flags", ProtocoloRede.F_NO_CHAO))
		rapidez = float(c.get_meta(&"rapidez", 0.0))
		arfagem = float(c.get_meta(&"arfagem", 0.0))
		if flags & ProtocoloRede.F_CARRO:
			e["modelo"] = int(c.get_meta(&"modelo", 0))
			e["semente"] = int(c.get_meta(&"semente", 0))
	if _ausente:
		flags |= ProtocoloRede.F_AUSENTE
	# Vida zero em rede (`SocorroEmRede`): no chao ate alguem levantar ou apagar.
	if socorro.caido:
		flags |= ProtocoloRede.F_CAIDO

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
	e["arfagem"] = arfagem
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
##
## A altura sai do relevo (relevo.gd), e nao da cena: o ponto de nascimento da
## cidade.tscn esta em y = 0,5 e o terreno ali desceu para -17,6 m quando a
## ladeira entrou. Quem chegasse por ele ficaria no ar esperando um chao que o
## raio nao alcanca, e cairia 18 m. Perto do anfitriao vale o mais alto entre ele
## e o relevo: ele pode estar numa calcada ou num patamar acima do terreno.
func _ponto_de_chegada(slot: int) -> Array:
	var base := ponto_inicial()
	var perto_do_host := false
	if modo == Modo.HOSPEDANDO and _estados.has(1):
		var host: Dictionary = _estados[1]
		if int(host["espaco"]) == ProtocoloRede.ESPACO_RUA and not (
				int(host["flags"]) & ProtocoloRede.F_CARRO):
			base = host["pos"]
			perto_do_host = true
	if not perto_do_host:
		base.y = Relevo.altura(base.x, base.z)
	var angulo := TAU * float(slot % 8) / 8.0
	var raio := 1.6 + 0.8 * floorf(float(slot) / 8.0)
	var p := base + Vector3(cos(angulo), 0.0, sin(angulo)) * raio
	p.y = maxf(base.y, Relevo.altura(p.x, p.z)) + 1.0
	return [p, base + Vector3.UP * 1.5]


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
			destino + Vector3.UP * 4.0, destino + Vector3.DOWN * 12.0)
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
		elif a.begins_with("--mp-validacao="):
			_validacao_pedida = a.trim_prefix("--mp-validacao=")
		elif a.begins_with("--mp-nome="):
			_perfil_injetado["nome"] = a.trim_prefix("--mp-nome=")
		elif a == "--mp-painel" and _painel != null:
			_painel.abrir()
	# `--mp-sonda=`: o teste de ponta a ponta no jogo de verdade (tools/mp_e2e.sh).
	var sonda := SondaE2E.configurar(args)
	if sonda != null:
		add_child(sonda)
	if hospedar_porta > 0:
		hospedar(hospedar_porta, maximo, "", senha)
	elif not entrar_em.is_empty():
		entrar(entrar_em, -1, senha)


func _mudar_modo(novo: Modo) -> void:
	if novo == modo:
		return
	var estava_solo := modo == Modo.SOLO
	modo = novo
	# O empurrao entre corpos so existe onde ha jogador local e bonecos.
	set_physics_process(novo == Modo.HOSPEDANDO or novo == Modo.CLIENTE)
	# Abriu a sessao com a arvore parada (menu aberto por cima do F7): a pausa vira
	# a de rede, e o menu, ao fechar, destrava pelo mesmo `pausar`.
	if estava_solo and novo != Modo.SOLO and novo != Modo.DEDICADO and get_tree().paused:
		get_tree().paused = false
		pausar(true)
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
	_mundo.zerar()
	socorro.zerar()
	mochilas.zerar()
	_seq = 0
	_tick = 0
	_acc_tick = 0.0
	_ultima_pos_enviada = Vector3.INF
	_ultimo_espaco_enviado = -1
	lista_mudou.emit()


func _esquecer(id: int) -> void:
	_mundo.esquecer(id)
	socorro.esquecer(id)
	mochilas.esquecer(id)
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
	_falar_no_avatar(id, nome, texto)


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


## Recado so desta maquina (feed e console), sem passar pela rede.
func avisar_local(texto: String) -> void:
	_recado(texto)


## O save ja foi aplicado (SaveGame nao avisa antes). Sozinho nao ha nada a fazer.
## Anfitriao: o mundo que os convidados espelham acabou de ser trocado, e eles
## recebem a carga de novo (`MundoEmRede.recarregar_todos`); o salto do corpo
## ate o ponto do save e teletransporte anunciado. Convidado: carregar o proprio
## jogo e voltar para ele — o WorldState ja e o do save, entao nao ha mundo
## proprio a devolver, e a sessao acaba.
func _ao_carregar_save(_espaco: int) -> void:
	if modo == Modo.HOSPEDANDO:
		anunciar_teletransporte()
		_mundo.ressincronizar_cena()
		_mundo.recarregar_todos()
		_recado("Voce carregou um jogo; quem esta com voce recebeu o mundo de novo.")
	elif modo == Modo.CLIENTE or modo == Modo.CONECTANDO:
		# Ainda em rede: a porta so escuta o mundo enquanto e compartilhada.
		_mundo.ressincronizar_cena()
		_mundo.largar_mundo_do_anfitriao()
		sair("Voce carregou um jogo salvo e saiu da sessao.")


func _recado(texto: String) -> void:
	print("[sessao] %s" % texto)
	recado.emit(texto)


## Relogio monotono em segundos, com a precisao de um double. `Time.get_ticks_usec`
## e nao o tempo do sistema: ajuste de hora do Windows no meio da partida nao pode
## fazer o amigo voltar no tempo.
func _agora() -> float:
	return float(Time.get_ticks_usec()) / 1000000.0
