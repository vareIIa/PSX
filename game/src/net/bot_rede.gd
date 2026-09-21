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
var _acumulado := 0
var _terminado := false
var _diag := 0
## Maior intervalo entre dois quadros deste processo, em s. Com nove Godots numa
## maquina de oito nucleos o sistema engasga processos, e um bot parado no ar
## continua "andando" na trajetoria ideal — o erro que isso gera e da bancada,
## nao da rede. O resultado traz o numero para separar os dois.
var _quadro_max := 0.0


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
	_corpo = Node3D.new()
	_corpo.name = "CorpoBot"
	add_child(_corpo)
	_corpo.set_meta(&"flags", ProtocoloRede.F_NO_CHAO)
	_corpo.set_meta(&"rapidez", VELOCIDADE)
	_corpo.global_position = trajetoria(_indice, 0.0)
	Sessao.definir_corpo_local(_corpo, {"nome": "BOT%d" % _indice})
	Sessao.conexao_falhou.connect(func(m: String) -> void: _recusa = m)
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
		_corpo.global_position = trajetoria(_indice, ts)
		_corpo.rotation.y = -(VELOCIDADE / RAIO) * ts
		_medir()
	var desistiu := not _recusa.is_empty() and Sessao.modo == Sessao.Modo.SOLO
	if _t >= _duracao or desistiu:
		_terminar()


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
				if erro > 0.10 and _diag < 6:
					_diag += 1
					var bt: PackedFloat64Array = av.buffer.get(&"_t")
					var be: Array = av.buffer.get(&"_e")
					var k := bt.size()
					var txt := ""
					for j in range(maxi(0, k - 4), k):
						var ej: Dictionary = be[j]
						txt += " [t=%.3f d=%.2f fl=%d]" % [bt[j], (ej["pos"] as Vector3).distance_to(trajetoria(outro, bt[j])), int(ej["flags"])]
					print("[diag] tj=%.2f %s err=%.2f tdes=%.3f ult=%.3f%s" % [_t - _entrou_em, av.nome, erro, av.t_desenho, av.buffer.ultimo_t(), txt])


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
		"recebido_kbps": (float(_bytes_recebidos() - _recebido_ini) / 1024.0 / segundos
			if _entrou_em >= 0.0 else 0.0),
	}
	print("[bot] RESULTADO %s" % JSON.stringify(resultado))
	Sessao.sair()
	get_tree().quit(0)


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

