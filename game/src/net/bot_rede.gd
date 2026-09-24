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
var _ultimo_quadro_us := 0
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

## --- caido e levantar (plano 08 secao 3.3) ---
## `--bot-cair-em=T[,T2...]`: horas do servidor em que a vida deste bot zera.
var _quedas: Array[float] = []
## `--bot-levantar=T,BOTn`: na hora T vai a pe ate BOTn caido e pede levantar.
var _levantar: Dictionary = {}
## Onde o corpo fica enquanto esta no chao ou indo ajudar (INF = trajetoria).
var _fixo := Vector3.INF
var _socorro := {"quedas": 0, "levantado_por": [], "apagou": 0, "viu_caido": {},
	"pediu_levantar": 0}

## --- mochila (plano 08 secao 1.3) ---
## `--bot-kit=id:qtd,id:qtd`: a mochila com que o bot entra, na ordem.
var _kit: Array = []
## `--bot-dar=T,BOTn,espaco,qtd` (pode repetir): a pe ate BOTn e da.
var _dares: Array[Dictionary] = []
var _respostas_dar: Array = []
var _recebidos: Array = []
var _mochila_ini: Dictionary = {}


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
		elif a.begins_with("--bot-cair-em="):
			for t: String in a.trim_prefix("--bot-cair-em=").split(","):
				_quedas.append(t.to_float())
		elif a.begins_with("--bot-levantar="):
			var s := a.trim_prefix("--bot-levantar=").split(",")
			if s.size() >= 2:
				_levantar = {"em": s[0].to_float(), "alvo": s[1], "feito": false}
		elif a.begins_with("--bot-kit="):
			for par: String in a.trim_prefix("--bot-kit=").split(","):
				var kv := par.split(":")
				if kv.size() == 2:
					_kit.append([StringName(kv[0]), kv[1].to_int()])
		elif a.begins_with("--bot-dar="):
			var d := a.trim_prefix("--bot-dar=").split(",")
			if d.size() >= 4:
				_dares.append({"em": d[0].to_float(), "alvo": d[1], "espaco": d[2].to_int(),
					"qtd": d[3].to_int(), "feito": false})
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
	# `--bot-parado` sem centro: fica no comeco da propria trajetoria (quem recebe
	# um item espera ali).
	if _parado and _centro == Vector3.INF:
		_fixo = _corpo.global_position
	Sessao.definir_corpo_local(_corpo, {"nome": "BOT%d" % _indice})
	Sessao.conexao_falhou.connect(func(m: String) -> void: _recusa = m)
	Sessao.recado.connect(func(t: String) -> void:
		if t.begins_with("BOT") and t.contains(": "):
			_chat_ouvido.append(t)
			if _chat_ms < 0 and _t_falou >= 0.0 and t.begins_with("BOT%d: " % _indice):
				_chat_ms = roundi((_t - _t_falou) * 1000.0))
	Sessao.mundo().negado.connect(func(m: int) -> void:
		_negados.append(String(ValidadorDeMundo.Motivo.find_key(m))))
	# O bot entra com a mochila do kit, e nao com a que o `Inventario` trouxer.
	Inventario.de_dicionario({"espacos": [], "vida": Inventario.vida_maxima})
	for par: Array in _kit:
		Inventario.adicionar(par[0], par[1])
	_mochila_ini = _contar_mochila()
	Sessao.mochilas.deu.connect(func(ok: bool, item: StringName, qtd: int, motivo: String) -> void:
		_respostas_dar.append([ok, String(item), qtd, motivo]))
	Sessao.mochilas.recebeu.connect(func(item: StringName, qtd: int, de: String) -> void:
		_recebidos.append([String(item), qtd, de]))
	Sessao.socorro.levantado.connect(func(por: String) -> void:
		(_socorro["levantado_por"] as Array).append(por)
		_voltar_a_trajetoria())
	# Sem `Desmaio` no bot: quem apaga volta a trajetoria e avisa que acordou.
	Sessao.socorro.apagou.connect(func() -> void:
		_socorro["apagou"] = int(_socorro["apagou"]) + 1
		_voltar_a_trajetoria()
		Sessao.socorro.acordei())
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
	# Pelo relogio de parede, e nao pelo `delta`: o Godot ceifa o delta de um
	# quadro longo, e o engasgo de montar o boneco de quem acabou de entrar sumia
	# da medida.
	var agora_us := Time.get_ticks_usec()
	if _entrou_em >= 0.0 and _ultimo_quadro_us > 0:
		_quadro_max = maxf(_quadro_max, (agora_us - _ultimo_quadro_us) / 1000000.0)
	_ultimo_quadro_us = agora_us
	if Sessao.modo == Sessao.Modo.CLIENTE and Sessao.relogio_pronto():
		if _entrou_em < 0.0:
			_entrou_em = _t
			_recebido_ini = _bytes_recebidos()
		var ts := Sessao.tempo_servidor()
		_tracar(ts)
		_socorrer(ts, delta)
		if _fixo != Vector3.INF:
			_corpo.global_position = _fixo
		elif _centro != Vector3.INF and _parado:
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
		if int(av.estado.get("flags", 0)) & ProtocoloRede.F_CAIDO:
			(_socorro["viu_caido"] as Dictionary)[av.nome] = true
		if _t - _entrou_em > AQUECIMENTO:
			var erro := av.global_position.distance_to(trajetoria(outro, av.t_desenho))
			if av.t_desenho > av.buffer.ultimo_t() + ProtocoloRede.EXTRAPOLACAO_MAX:
				_famintas += 1
				_famintas_max_cm = maxf(_famintas_max_cm, erro * 100.0)
				_marcar_fome(av.nome, av.t_desenho - av.buffer.ultimo_t())
			else:
				_erros.append(erro)


## Surtos de fome, por boneco: [nome, hora do servidor em que comecou, maior
## atraso do dado em s]. Surto que para por mais de 0,5 s e outro surto.
var _surtos: Array = []


## `--bot-traco`: a cada 100 ms, a hora estimada do servidor e, por boneco, a
## hora desenhada e a da ultima amostra. Para achar de onde vem uma fome.
var _t_traco := 0.0


func _tracar(ts: float) -> void:
	if not OS.get_cmdline_user_args().has("--bot-traco") or ts - _t_traco < 0.1:
		return
	_t_traco = ts
	var partes: PackedStringArray = ["%.2f" % ts]
	for id: int in Sessao.avatares():
		var av: AvatarRemoto = Sessao.avatares()[id]
		partes.append("%s:%.2f/%.2f" % [av.nome, av.t_desenho, av.buffer.ultimo_t()])
	# O estrangulador do ENet deste lado: valor/teto, acel/desacel/intervalo, e a
	# ida e volta que ele compara (ultima e sua variacao).
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	var p: ENetPacketPeer = enet.get_peer(1) if enet != null else null
	if p != null:
		partes.append("enet:%d/%d a%d d%d i%d rtt%d ult%d var%d seq%d" % [
			p.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE),
			p.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_LIMIT),
			p.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_ACCELERATION),
			p.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_DECELERATION),
			p.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_INTERVAL),
			p.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME),
			p.get_statistic(ENetPacketPeer.PEER_LAST_ROUND_TRIP_TIME),
			p.get_statistic(ENetPacketPeer.PEER_LAST_ROUND_TRIP_TIME_VARIANCE),
			Sessao._seq])
	print("[traco] ", " ".join(partes))


func _marcar_fome(nome: String, atraso: float) -> void:
	var agora := Sessao.tempo_servidor()
	for s: Array in _surtos:
		if s[0] == nome and agora - float(s[3]) < 0.5:
			s[2] = maxf(float(s[2]), atraso)
			s[3] = agora
			return
	_surtos.append([nome, snappedf(agora, 0.01), atraso, agora])


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
		"mochila_ini": _mochila_ini,
		"mochila_fim": _contar_mochila(),
		"deu": _respostas_dar,
		"recebeu": _recebidos,
		"socorro": {"quedas": _socorro["quedas"], "levantado_por": _socorro["levantado_por"],
			"apagou": _socorro["apagou"], "viu_caido": (_socorro["viu_caido"] as Dictionary).keys(),
			"pediu_levantar": _socorro["pediu_levantar"]},
		"amostras": n,
		"famintas": _famintas,
		"famintas_max_cm": snappedf(_famintas_max_cm, 0.01),
		"erro_p50_cm": _cm(ordenados, 0.50),
		"erro_p95_cm": _cm(ordenados, 0.95),
		"erro_max_cm": _cm(ordenados, 1.0),
		"ping_ms": int(eu.get("ping", -1)),
		"quadro_max_ms": roundi(_quadro_max * 1000.0),
		# Quantos estados este bot mandou e quantos quadros rodou desde que subiu:
		# a taxa de envio e o ritmo do laco, para separar rede de processo lento.
		"estados_enviados": int(Sessao.get("_seq")),
		"quadros": Engine.get_process_frames(),
		"segundos": snappedf(Time.get_ticks_msec() / 1000.0, 0.1),
		"enet": _estatisticas_enet(),
		"surtos": _surtos.map(func(x: Array) -> Array: return [x[0], x[1], snappedf(float(x[2]), 0.01)]),
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
## Cai nas horas de `--bot-cair-em`, e vai levantar quem `--bot-levantar` pede.
func _socorrer(ts: float, delta: float) -> void:
	if not _quedas.is_empty() and ts >= _quedas[0] and not Sessao.socorro.caido:
		_quedas.pop_front()
		_socorro["quedas"] = int(_socorro["quedas"]) + 1
		_fixo = _corpo.global_position
		Sessao.socorro.cair()
	for d: Dictionary in _dares:
		if bool(d["feito"]) or ts < float(d["em"]):
			continue
		var quem := _andar_ate(String(d["alvo"]), delta)
		if quem >= 0:
			d["feito"] = true
			Sessao.mochilas.dar(quem, int(d["espaco"]), int(d["qtd"]))
			_voltar_a_trajetoria.call_deferred()
		# Um de cada vez: o segundo espera o primeiro chegar.
		break
	if _levantar.is_empty() or bool(_levantar["feito"]) or ts < float(_levantar["em"]):
		return
	if not Sessao.socorro.caidos.has(_id_de(String(_levantar["alvo"]))):
		return
	var alvo := _andar_ate(String(_levantar["alvo"]), delta)
	if alvo < 0:
		return
	_levantar["feito"] = true
	_socorro["pediu_levantar"] = int(_socorro["pediu_levantar"]) + 1
	Sessao.socorro.pedir_levantar(alvo)
	_voltar_a_trajetoria.call_deferred()


## Anda a pe ate o boneco de `nome`, na velocidade de andar (o servidor valida
## o caminho como o de qualquer jogador). Devolve o id dele ao chegar, -1 antes.
func _andar_ate(nome: String, delta: float) -> int:
	var alvo := _id_de(nome)
	if alvo < 0:
		return -1
	if _fixo == Vector3.INF:
		_fixo = _corpo.global_position
	var la := (Sessao.avatares()[alvo] as AvatarRemoto).global_position
	var falta := Vector3(la.x - _fixo.x, 0.0, la.z - _fixo.z)
	# Mira 0,7 m e chega a 0,85: mirando o limite exato, a conta em float parava
	# a um fio dele e o pedido nunca saia.
	if falta.length() > 0.85:
		_fixo += falta.normalized() * minf(VELOCIDADE * delta, falta.length() - 0.7)
		return -1
	return alvo


func _id_de(nome: String) -> int:
	for id: int in Sessao.avatares():
		if (Sessao.avatares()[id] as AvatarRemoto).nome == nome:
			return id
	return -1


func _contar_mochila() -> Dictionary:
	var n := {}
	for e: Dictionary in Inventario.espacos:
		if not e.is_empty():
			var id := String((e["item"] as Item).id)
			n[id] = int(n.get(id, 0)) + int(e["qtd"])
	return n


## Solta o corpo de volta ao circulo. O salto e declarado: quem desenha corta em
## vez de deslizar, e o validador do servidor nao conta como velocidade.
func _voltar_a_trajetoria() -> void:
	_fixo = Vector3.INF
	Sessao.anunciar_teletransporte()


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


## O que o ENet deste bot diz ter feito: datagramas mandados e recebidos, e o
## estrangulador e a perda que ele mede no servidor.
func _estatisticas_enet() -> Dictionary:
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet == null or enet.host == null:
		return {}
	var p := enet.get_peer(1)
	return {
		"mandados": enet.host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_PACKETS),
		"recebidos": enet.host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_PACKETS),
		"estrangulador": p.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE) if p != null else -1,
		"perda": p.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS) if p != null else -1,
	}
