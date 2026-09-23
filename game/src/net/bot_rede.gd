## Cliente de teste sem tela: entra num servidor, anda em circulo e mede o que ve
## dos outros bots.
##
##     Godot --headless --path game res://scenes/net/bot_rede.tscn -- \
##         --bot-entrar=127.0.0.1:24599 --bot-indice=0 --bot-duracao=10
##
## A medida e o erro do boneco remoto contra a VERDADE. Cada bot anda numa
## trajetoria que e funcao pura do indice e da hora do servidor; entao o bot A
## sabe exatamente onde o bot B estava no instante que o boneco de B esta
## desenhando, e a distancia entre os dois e o erro de toda a cadeia — relogio,
## instantaneo, perda, interpolacao. "O amigo parece andar certo" vira um numero
## em centimetros (plano 14, nivel 4).
##
## No fim imprime uma linha `[bot] RESULTADO {json}` e sai. `tools/mp_teste.sh`
## le essas linhas.
class_name BotRede
extends Node3D

## A pe, na velocidade de andar do `Player`, em circulo de 6 m.
const RAIO := 6.0
const VELOCIDADE := 2.4
## Segundos depois de entrar que nao contam: o relogio de rede ainda converge e
## o buffer ainda nao tem par para interpolar.
const AQUECIMENTO := 1.5

var _indice := 0
var _duracao := 10.0
var _endereco := ""
var _senha := ""
var _corpo: Node3D
var _t := 0.0
var _entrou_em := -1.0
var _erros := PackedFloat64Array()
## Amostras em que nada tinha chegado para o instante desenhado, alem do teto de
## extrapolacao: o boneco estava parado esperando pacote. Isso mede ENTREGA
## (processo engasgado, rede), nao interpolacao, e e contado a parte — misturar
## os dois fazia um soluco de 0,4 s da maquina parecer defeito do buffer.
var _famintas := 0
var _famintas_max_cm := 0.0
var _vistos: Dictionary = {}
var _recusa := ""
var _recebido_ini := 0
var _flags_extra := 0
## `--bot-falar=texto`: manda uma linha de chat dois segundos depois de entrar.
var _falar := ""
var _falou := false
## Recados de chat ouvidos ("NOME: texto"), para o teste conferir a entrega.
var _chat_ouvido: PackedStringArray = []
var _modelo := 0
var _semente := 0
var _acumulado := 0
var _terminado := false
## Modo de cena (`--bot-centro=`): anda num circulo escolhido, no chao do relevo,
## para ser fotografado pelo jogo de verdade. Nao mede — a verdade dos outros
## bots e a trajetoria padrao.
var _centro := Vector3.INF
var _raio_cena := RAIO
## Maior intervalo entre dois quadros deste processo, em s. Com nove Godots numa
## maquina de oito nucleos o sistema engasga processos, e um bot parado no ar
## continua "andando" na trajetoria ideal — o erro que isso gera e da bancada,
## nao da rede. O resultado traz o numero para separar os dois.
var _quadro_max := 0.0
## `--bot-atraso=S`: espera S segundos, depois de pronto, antes de ligar. O bot
## que testa "servidor cheio" nasce com os outros e entra depois deles.
var _atraso := 0.0
var _arfagem := 0.0
## `--bot-parado` com `--bot-centro`: fica no centro, virado para `--bot-giro`
## graus. Para foto: o carro do amigo parado de motor ligado, num lugar e num
## rumo conhecidos, e nao passando pela camera na hora que der.
var _parado := false
var _giro := 0.0

## --- mundo compartilhado (plano 04) ---
## `--bot-acao-em=T`: hora do SERVIDOR em que este bot mexe no mundo. Dois bots
## com o mesmo T pedem o mesmo item no mesmo instante, que e o teste da disputa.
var _acao_em := -1.0
var _agiu := false
## `--bot-mundo=cx,cz,chave` (pode repetir): manda `Sessao.mudar_mundo` true.
var _mudancas: Array[Dictionary] = []
## `--bot-pegar=cx,cz,indice,item`.
var _pegar: Dictionary = {}
## `--bot-ler=cx,cz,chave` (pode repetir): o que o `WorldState` diz no fim.
var _leituras: Array[Dictionary] = []
var _pegou: Variant = null
var _motivo_pegar := ""
var _negados: Array[String] = []
var _item_antes := 0
## Hora em que o recado saiu, para medir a ida e volta do chat.
var _t_falou := -1.0
var _chat_ms := -1


func _ready() -> void:
	Engine.max_fps = 60
	# Antes da Sessao (100): o corpo tem de estar no lugar deste quadro quando
	# ela le e manda.
	process_priority = -100
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--bot-entrar="):
			_endereco = a.trim_prefix("--bot-entrar=")
		elif a.begins_with("--bot-indice="):
			_indice = a.trim_prefix("--bot-indice=").to_int()
		elif a.begins_with("--bot-duracao="):
			_duracao = a.trim_prefix("--bot-duracao=").to_float()
		elif a.begins_with("--bot-senha="):
			_senha = a.trim_prefix("--bot-senha=")
		elif a.begins_with("--bot-centro="):
			var p := a.trim_prefix("--bot-centro=").split(",")
			if p.size() >= 2:
				_centro = Vector3(float(p[0]), 0.0, float(p[1]))
		elif a.begins_with("--bot-raio="):
			_raio_cena = a.trim_prefix("--bot-raio=").to_float()
		elif a.begins_with("--bot-carro="):
			var c := a.trim_prefix("--bot-carro=").split(",")
			_flags_extra |= ProtocoloRede.F_CARRO
			_modelo = int(c[0])
			_semente = int(c[1]) if c.size() > 1 else 0
		elif a.begins_with("--bot-falar="):
			_falar = a.trim_prefix("--bot-falar=")
		elif a.begins_with("--bot-atraso="):
			_atraso = a.trim_prefix("--bot-atraso=").to_float()
		elif a == "--bot-parado":
			_parado = true
		elif a.begins_with("--bot-giro="):
			_giro = deg_to_rad(a.trim_prefix("--bot-giro=").to_float())
		elif a.begins_with("--bot-arfagem="):
			# Graus; negativo olha para baixo. A lanterna do boneco aponta junto.
			_arfagem = deg_to_rad(a.trim_prefix("--bot-arfagem=").to_float())
		elif a == "--bot-lanterna":
			_flags_extra |= ProtocoloRede.F_LANTERNA
		elif a == "--bot-agachado":
			_flags_extra |= ProtocoloRede.F_AGACHADO
		elif a == "--bot-sentado":
			_flags_extra |= ProtocoloRede.F_SENTADO
		elif a == "--bot-bicicleta":
			_flags_extra |= ProtocoloRede.F_BICICLETA
		elif a == "--bot-ausente":
			_flags_extra |= ProtocoloRede.F_AUSENTE
		elif a.begins_with("--bot-acao-em="):
			_acao_em = a.trim_prefix("--bot-acao-em=").to_float()
		elif a.begins_with("--bot-mundo="):
			var m := a.trim_prefix("--bot-mundo=").split(",")
			if m.size() >= 3:
				_mudancas.append({"coord": Vector2i(int(m[0]), int(m[1])),
					"chave": StringName(m[2])})
		elif a.begins_with("--bot-pegar="):
			var g := a.trim_prefix("--bot-pegar=").split(",")
			if g.size() >= 4:
				_pegar = {"coord": Vector2i(int(g[0]), int(g[1])), "indice": int(g[2]),
					"item": StringName(g[3])}
		elif a.begins_with("--bot-ler="):
			var l := a.trim_prefix("--bot-ler=").split(",")
			if l.size() >= 3:
				_leituras.append({"coord": Vector2i(int(l[0]), int(l[1])),
					"chave": StringName(l[2])})
	_corpo = Node3D.new()
	_corpo.name = "CorpoBot"
	add_child(_corpo)
	_corpo.set_meta(&"flags", ProtocoloRede.F_NO_CHAO | _flags_extra)
	_corpo.set_meta(&"rapidez", VELOCIDADE)
	_corpo.set_meta(&"modelo", _modelo)
	_corpo.set_meta(&"semente", _semente)
	_corpo.set_meta(&"arfagem", _arfagem)
	_corpo.global_position = trajetoria(_indice, 0.0)
	Sessao.definir_corpo_local(_corpo, {"nome": "BOT%d" % _indice})
	Sessao.conexao_falhou.connect(func(m: String) -> void: _recusa = m)
	Sessao.recado.connect(func(t: String) -> void:
		if t.begins_with("BOT") and t.contains(": "):
			_chat_ouvido.append(t)
			if _chat_ms < 0 and _t_falou >= 0.0 and t.begins_with("BOT%d: " % _indice):
				_chat_ms = roundi((_t - _t_falou) * 1000.0))
	Sessao.mundo().negado.connect(func(m: int) -> void:
		_negados.append(String(ValidadorDeMundo.Motivo.find_key(m))))
	# A assinatura da cidade ANTES de ligar. Ela compila o gerador inteiro (a
	# primeira vez, ~150 ms de CPU e a arvore de scripts da cidade); com nove
	# processos numa maquina, calcular ao entrar punha essa carga no meio da
	# medida dos bots que ja estavam dentro. Medido: fome de 4 % e p95 de 19 cm
	# num cenario que da 0 % e 0,1 cm sem ela. Um jogador de verdade paga isso
	# uma vez, em thread; o bot paga antes do relogio comecar.
	await Sessao.esperar_assinatura()
	if _atraso > 0.0:
		await get_tree().create_timer(_atraso).timeout
	if Sessao.entrar(_endereco, -1, _senha) != OK:
		_recusa = "entrar() falhou"


func _process(delta: float) -> void:
	if _terminado:
		return
	_t += delta
	if _entrou_em >= 0.0:
		_quadro_max = maxf(_quadro_max, delta)
	if Sessao.modo == Sessao.Modo.CLIENTE and Sessao.relogio_pronto():
		if _entrou_em < 0.0:
			_entrou_em = _t
			_recebido_ini = _bytes_recebidos()
		var ts := Sessao.tempo_servidor()
		if _centro != Vector3.INF and _parado:
			_corpo.global_position = Vector3(_centro.x, Relevo.altura(_centro.x, _centro.z), _centro.z)
			_corpo.rotation.y = _giro
			_corpo.set_meta(&"rapidez", 0.0)
		elif _centro != Vector3.INF:
			var w := VELOCIDADE / _raio_cena
			var a := w * ts + float(_indice) * 1.3
			var p := _centro + Vector3(cos(a), 0.0, sin(a)) * _raio_cena
			p.y = Relevo.altura(p.x, p.z)
			_corpo.global_position = p
			# Tangente ao circulo, no sentido de `a` crescente: (-sen a, 0, cos a).
			# Corpo e Carro olham para -Z, e -Z girado de t vale (-sen t, 0, -cos t);
			# igualando, t = PI - a.
			_corpo.rotation.y = PI - a
		else:
			_corpo.global_position = trajetoria(_indice, ts)
			_corpo.rotation.y = -(VELOCIDADE / RAIO) * ts
		_medir()
		_agir()
		if not _falar.is_empty() and not _falou and _t - _entrou_em > 2.0:
			_falou = true
			_t_falou = _t
			Sessao.falar(_falar)
	var desistiu := not _recusa.is_empty() and Sessao.modo == Sessao.Modo.SOLO
	if _t >= _duracao or desistiu:
		_terminar()


## Mexe no mundo na hora combinada. Espera a carga de entrada: antes dela o
## servidor cala qualquer pedido, e o bot leria "nao aconteceu nada".
func _agir() -> void:
	if _agiu or not Sessao.mundo_pronto():
		return
	if _acao_em >= 0.0 and Sessao.tempo_servidor() < _acao_em:
		return
	if _mudancas.is_empty() and _pegar.is_empty():
		return
	_agiu = true
	for m: Dictionary in _mudancas:
		Sessao.mudar_mundo(m["coord"], m["chave"], true, false)
	if not _pegar.is_empty():
		var item: StringName = _pegar["item"]
		_item_antes = Inventario.quantidade(item)
		Sessao.pedir_item(_pegar["coord"], int(_pegar["indice"]), item, 1,
			func(ok: bool, motivo: int) -> void:
				_pegou = ok
				_motivo_pegar = String(ValidadorDeMundo.Motivo.find_key(motivo)))


func _medir() -> void:
	var avatares := Sessao.avatares()
	for id: int in avatares:
		var av: AvatarRemoto = avatares[id]
		if not av.visible:
			continue
		var outro := _indice_de(av.nome)
		if outro < 0:
			continue
		_vistos[av.nome] = true
		if _t - _entrou_em > AQUECIMENTO:
			var erro := av.global_position.distance_to(trajetoria(outro, av.t_desenho))
			if av.t_desenho > av.buffer.ultimo_t() + ProtocoloRede.EXTRAPOLACAO_MAX:
				_famintas += 1
				_famintas_max_cm = maxf(_famintas_max_cm, erro * 100.0)
			else:
				_erros.append(erro)


func _terminar() -> void:
	_terminado = true
	var ordenados := Array(_erros)
	ordenados.sort()
	var n := ordenados.size()
	var segundos := maxf(_t - _entrou_em, 0.001) if _entrou_em >= 0.0 else 0.0
	var eu: Dictionary = Sessao.jogadores.get(Sessao.meu_id, {})
	var resultado := {
		"indice": _indice,
		"estado": "ok" if _entrou_em >= 0.0 else ("recusado" if not _recusa.is_empty() else "sem_conexao"),
		"recusa": _recusa,
		"vistos": _vistos.keys(),
		"amostras": n,
		"famintas": _famintas,
		"famintas_max_cm": snappedf(_famintas_max_cm, 0.01),
		"erro_p50_cm": _cm(ordenados, 0.50),
		"erro_p95_cm": _cm(ordenados, 0.95),
		"erro_max_cm": _cm(ordenados, 1.0),
		"ping_ms": int(eu.get("ping", -1)),
		"quadro_max_ms": roundi(_quadro_max * 1000.0),
		"chat_ouvido": Array(_chat_ouvido),
		"chat_ms": _chat_ms,
		# O mundo compartilhado: o que chegou na entrada, o que este bot conseguiu
		# mudar, e o que ele le no fim.
		"mundo_pronto": Sessao.mundo_pronto(),
		"mundo": Sessao.mundo().ultima_carga,
		"pegou": _pegou,
		"motivo_pegar": _motivo_pegar,
		"mochila_item": (Inventario.quantidade(StringName(_pegar["item"])) - _item_antes
			if not _pegar.is_empty() else 0),
		"negados": Array(_negados),
		"lidos": _ler_do_mundo(),
		# O bot nao tem HUD, entao o relogio dele so anda se o servidor acertar.
		# Segundos de jogo alem da hora inicial (22:43) = prova de sincronia.
		"relogio_avancou_s": snappedf(WorldState.relogio.segundos - float(Relogio.INICIO), 0.1),
		"recebido_kbps": (float(_bytes_recebidos() - _recebido_ini) / 1024.0 / segundos
			if _entrou_em >= 0.0 else 0.0),
	}
	print("[bot] RESULTADO %s" % JSON.stringify(resultado))
	Sessao.sair()
	get_tree().quit(0)


func _ler_do_mundo() -> Dictionary:
	var saida := {}
	for l: Dictionary in _leituras:
		var coord: Vector2i = l["coord"]
		saida["%d,%d|%s" % [coord.x, coord.y, l["chave"]]] = WorldState.obter(
			coord, l["chave"], null)
	return saida


## Onde o bot `i` esta na hora de servidor `t`. Funcao pura: e a verdade contra
## a qual os outros bots medem o boneco dele.
static func trajetoria(i: int, t: float) -> Vector3:
	var a := (VELOCIDADE / RAIO) * t + float(i) * 1.3
	return Vector3(float(i) * 4.0 + cos(a) * RAIO, 0.5, sin(a) * RAIO)


static func _indice_de(nome: String) -> int:
	if not nome.begins_with("BOT"):
		return -1
	var resto := nome.trim_prefix("BOT")
	return resto.to_int() if resto.is_valid_int() else -1


static func _cm(ordenados: Array, q: float) -> float:
	if ordenados.is_empty():
		return -1.0
	var i := clampi(ceili(q * float(ordenados.size())) - 1, 0, ordenados.size() - 1)
	return snappedf(float(ordenados[i]) * 100.0, 0.01)


func _bytes_recebidos() -> int:
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet == null or enet.host == null:
		return 0
	# pop_statistic zera o contador a cada leitura; acumula aqui.
	_acumulado += int(enet.host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA))
	return _acumulado

