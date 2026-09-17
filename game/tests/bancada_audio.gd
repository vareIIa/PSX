## Som espacial: o criterio A27 do PLANO_AAA_4K.
##
##     godot --path game --resolution 400x300 --script res://tests/bancada_audio.gd
##     (SEM --headless: o driver mudo nao devolve amostra nenhuma)
##
## Como se mede som sem ouvido
## ---------------------------
## Um `AudioEffectCapture` no Master devolve as amostras que iriam para a caixa.
## A partir delas tudo e conta: energia, queda, e frequencia por cruzamento de
## zero. Nenhuma medida aqui depende de alguem achar que ouviu diferenca.
##
## O estouro e um rajada de ruido de 120 ms. Ruido, e nao estalo: um estalo tem
## energia demais no agudo e de menos no grave, e mediria o filtro e nao o
## ambiente. Cento e vinte milissegundos e o tempo de um passo — o som que mais
## toca neste jogo.
##
## O que cada medida faz
## ---------------------
## A27a  **Eco por ambiente.** A CAUDA depois que a rajada acaba, em decibeis
##       abaixo dela. Rua aberta quase nao tem; tunel tem muito. A medida e a
##       razao entre ambientes, e nao um numero absoluto: o absoluto depende do
##       volume do sistema, a razao nao.
## A27b  **Oclusao.** A mesma fonte com e sem parede entre ela e o ouvinte:
##       quanto cai em decibeis, e quanto do AGUDO some (parede come agudo
##       primeiro; so baixar o volume soa como fonte distante, nao como fonte
##       atras da parede).
## A27c  **Doppler.** A frequencia medida por cruzamento de zero, com a fonte
##       vindo e com a fonte indo.
extends SceneTree

const TAXA := 48000.0
const TOM := 440.0
## Duracao da rajada de ruido, e o silencio depois dela.
const RAJADA := 0.12
const RABO := 1.2

var _captura: AudioEffectCapture
var _ecos: Node
var _passou := 0
var _total := 0


func _init() -> void:
	_medir()


func _medir() -> void:
	await process_frame
	_captura = AudioEffectCapture.new()
	_captura.buffer_length = 4.0
	AudioServer.add_bus_effect(0, _captura)
	# A bancada manda no volume: o jogo le o do jogador em `user://settings.cfg`,
	# e medir a diferenca entre dois sons com o deslizador do dono da maquina no
	# meio do caminho seria medir o deslizador.
	# Sem isto o viewport nao processa som 3D e todo tocador posicional sai mudo:
	# medido, pico 0,000001 contra 0,46 do mesmo som em 2D.
	root.audio_listener_enable_3d = true
	for nome: StringName in [&"Master", &"SFX"]:
		var i := AudioServer.get_bus_index(nome)
		if i >= 0:
			AudioServer.set_bus_volume_db(i, 0.0)
			AudioServer.set_bus_mute(i, false)
	await process_frame
	print("\n=== A27: som espacial ===")
	print("driver %s, %.0f Hz\n" % [AudioServer.get_driver_name(), AudioServer.get_mix_rate()])
	await _medir_eco()
	await _medir_oclusao()
	await _medir_doppler()
	print("\n%d de %d criterios" % [_passou, _total])
	quit(0 if _passou == _total else 1)


func _conta(nome: String, ok: bool, texto: String) -> void:
	_total += 1
	if ok:
		_passou += 1
	print("%s %s: %s" % ["[ok]" if ok else "[X ]", nome, texto])


# --- A27a: eco por ambiente -------------------------------------------------

func _medir_eco() -> void:
	_ecos = root.get_node_or_null(^"/root/Eco")
	if _ecos == null:
		_conta("A27a eco por ambiente", false,
			"o autoload Eco nao existe; medindo so o que o bus ja faz")
		var cauda := await _cauda_do_ambiente("")
		print("      cauda do bus como esta: %.1f dB" % cauda)
		return
	var medidas := {}
	for nome: String in _ecos.call(&"nomes"):
		medidas[nome] = await _cauda_do_ambiente(nome)
	var rua: float = medidas.get("rua", -99.0)
	var tunel: float = medidas.get("tunel", -99.0)
	var sala: float = medidas.get("sala", -99.0)
	var carro: float = medidas.get("carro", -99.0)
	# Cauda e negativa (abaixo da rajada): tunel MAIOR que rua quer dizer menos
	# negativo. Seis decibeis sao o dobro de pressao sonora — e o degrau que
	# alguem ouve sem estar procurando.
	_conta("A27a eco por ambiente", tunel - rua >= 6.0 and sala > rua and carro <= rua + 2.0,
		"cauda: rua %.1f dB, rua estreita %.1f, tunel %.1f, sala %.1f, carro %.1f"
			% [rua, medidas.get("rua_estreita", -99.0), tunel, sala, carro])
	for nome: String in medidas:
		print("      %-14s %.1f dB" % [nome, medidas[nome]])


func _cauda_do_ambiente(nome: String) -> float:
	if _ecos != null and nome != "":
		_ecos.call(&"forcar", nome)
		# O eco entra em rampa; a medida espera ele chegar.
		for _i in 40:
			await process_frame
	var dados := await _tocar_rajada()
	return _cauda(dados)


## Rajada de ruido no bus de efeitos, e as amostras que sairam.
func _tocar_rajada() -> PackedFloat32Array:
	var p := AudioStreamPlayer.new()
	var g := AudioStreamGenerator.new()
	g.mix_rate = TAXA
	g.buffer_length = 0.5
	p.stream = g
	p.bus = &"SFX"
	root.add_child(p)
	p.play()
	var saida := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260917
	var escritas := 0
	var alvo := int(TAXA * RAJADA)
	_esvaziar()
	while escritas < alvo:
		var playback: AudioStreamGeneratorPlayback = p.get_stream_playback()
		var n := mini(playback.get_frames_available(), alvo - escritas)
		for _i in n:
			var v := rng.randf_range(-0.5, 0.5)
			playback.push_frame(Vector2(v, v))
		escritas += n
		await process_frame
		_recolher(saida)
	var quadros_rabo := int(TAXA * RABO)
	while saida.size() < alvo + quadros_rabo:
		await process_frame
		if not _recolher(saida):
			break
	p.queue_free()
	return saida


func _esvaziar() -> void:
	_captura.clear_buffer()


func _recolher(saida: PackedFloat32Array) -> bool:
	var n := _captura.get_frames_available()
	if n <= 0:
		return true
	var buf := _captura.get_buffer(n)
	for f: Vector2 in buf:
		saida.append((f.x + f.y) * 0.5)
	return true


## Energia da cauda em relacao a rajada, em decibeis.
##
## A janela da cauda comeca 60 ms depois do fim da rajada — antes disso ainda ha
## som direto na sala e a medida somaria a propria rajada.
func _cauda(dados: PackedFloat32Array) -> float:
	if dados.is_empty():
		return -99.0
	var fim_rajada := int(TAXA * RAJADA)
	var inicio := fim_rajada + int(TAXA * 0.06)
	var fim := mini(dados.size(), fim_rajada + int(TAXA * 0.6))
	if inicio >= fim:
		return -99.0
	return _db(_rms(dados, inicio, fim) / maxf(_rms(dados, 0, fim_rajada), 1e-9))


static func _rms(dados: PackedFloat32Array, de: int, ate: int) -> float:
	var soma := 0.0
	var n := 0
	for i in range(maxi(0, de), mini(dados.size(), ate)):
		soma += dados[i] * dados[i]
		n += 1
	if n == 0:
		return 0.0
	return sqrt(soma / float(n))


## Um tom em `AudioStreamWAV`, com um harmonico oito vezes acima.
##
## WAV, e nao `AudioStreamGenerator`: medido, gerador dentro de
## `AudioStreamPlayer3D` sai MUDO (pico 0,000001 contra 0,41 do mesmo som em
## WAV). O harmonico existe para a medida de oclusao enxergar o corte de agudo —
## senoide pura atravessa um passa-baixa de 900 Hz sem perder nada.
static func _onda(frequencia: float, segundos: float, com_harmonico: bool) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(TAXA)
	wav.stereo = false
	var n := int(TAXA * segundos)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var fase := 0.0
	for i in n:
		var v := sin(fase * TAU) * 0.6
		if com_harmonico:
			v = sin(fase * TAU) * 0.45 + sin(fase * TAU * 8.0) * 0.3
		bytes.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
		fase = fmod(fase + frequencia / TAXA, 1.0)
	wav.data = bytes
	return wav


## Fracao da energia que esta no agudo, pela derivada do sinal.
static func _agudo(dados: PackedFloat32Array) -> float:
	if dados.size() < 2:
		return 0.0
	var alta := 0.0
	var tudo := 0.0
	for i in range(1, dados.size()):
		var d := dados[i] - dados[i - 1]
		alta += d * d
		tudo += dados[i] * dados[i]
	return alta / maxf(tudo, 1e-9)


static func _db(razao: float) -> float:
	return 20.0 * log(maxf(razao, 1e-9)) / log(10.0)


# --- A27b: oclusao ----------------------------------------------------------

func _medir_oclusao() -> void:
	var som := root.get_node_or_null(^"/root/AudioDirector")
	if som == null or not som.has_method("oclusao"):
		_conta("A27b oclusao", false, "o AudioDirector ainda nao sabe ocluir")
		return
	var mundo := _mundo_com_parede()
	await process_frame
	await process_frame
	var livre: Dictionary = som.call(&"oclusao", Vector3(0.0, 1.0, -6.0), Vector3(0.0, 1.0, 0.0))
	var atras: Dictionary = som.call(&"oclusao", Vector3(0.0, 1.0, 6.0), Vector3(0.0, 1.0, 0.0))
	var db_livre := float(livre.get("db", 0.0))
	var db_atras := float(atras.get("db", 0.0))
	var corte_atras := float(atras.get("corte", 20000.0))
	var queda := db_livre - db_atras
	# O que o ouvido recebe, e nao so o que a conta decidiu: a mesma fonte tocada
	# dos dois lados, medida na saida.
	var frente := await _tocar_3d(Vector3(0.0, 1.0, -6.0), 0.0, &"SFX")
	var fundo := await _tocar_3d(Vector3(0.0, 1.0, 6.0), db_atras, &"Abafado")
	var medido := _db(_rms(frente, 0, frente.size()) / maxf(_rms(fundo, 0, fundo.size()), 1e-9))
	# Quanto do que sobrou e AGUDO. A derivada do sinal e um passa-alta pobre e
	# suficiente: ela realca o que muda rapido, que e exatamente o agudo.
	var agudo_frente := _agudo(frente)
	var agudo_fundo := _agudo(fundo)
	mundo.queue_free()
	_conta("A27b oclusao", queda >= 6.0 and medido >= 5.0 and agudo_fundo < agudo_frente * 0.6,
		"atras da parede: -%.1f dB pedidos, -%.1f dB medidos, e o agudo cai de %.2f para %.2f"
			% [queda, medido, agudo_frente, agudo_fundo])


## Parede de concreto entre o ouvinte (origem) e o fundo da cena.
func _mundo_com_parede() -> Node3D:
	var raiz := Node3D.new()
	var corpo := StaticBody3D.new()
	corpo.position = Vector3(0.0, 1.0, 3.0)
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(12.0, 6.0, 0.4)
	forma.shape = caixa
	corpo.add_child(forma)
	raiz.add_child(corpo)
	# Camera, e nao `AudioListener3D`: e a camera que o jogo usa como ouvido, e
	# com ela o mesmo som mede 0,41 de pico contra 0,046 sem.
	var ouvinte := Camera3D.new()
	ouvinte.position = Vector3(0.0, 1.0, 0.0)
	raiz.add_child(ouvinte)
	root.add_child(raiz)
	ouvinte.current = true
	return raiz


## Um tom numa posicao, com o volume pedido, no bus pedido.
func _tocar_3d(pos: Vector3, db: float, bus: StringName) -> PackedFloat32Array:
	var p := AudioStreamPlayer3D.new()
	p.stream = _onda(TOM, 0.5, true)
	p.bus = bus
	p.position = pos
	p.volume_db = db
	p.unit_size = 20.0
	root.add_child(p)
	_esvaziar()
	p.play()
	var saida := await _recolher_ate(int(TAXA * 0.3))
	p.queue_free()
	return saida


## Espera a saida render as amostras pedidas, com prazo.
func _recolher_ate(quantas: int) -> PackedFloat32Array:
	var saida := PackedFloat32Array()
	for _i in 120:
		await process_frame
		_recolher(saida)
		if saida.size() >= quantas:
			break
	return saida


# --- A27c: doppler ----------------------------------------------------------

func _medir_doppler() -> void:
	# Ouvido proprio: o da medida de oclusao foi descartado junto com a parede, e
	# som 3D sem camera corrente sai dez vezes mais baixo (medido).
	var ouvinte := Camera3D.new()
	ouvinte.position = Vector3(0.0, 1.0, 0.0)
	root.add_child(ouvinte)
	ouvinte.current = true
	await process_frame
	var vindo := await _passagem(-1.0)
	var indo := await _passagem(1.0)
	ouvinte.queue_free()
	var f_vindo := _frequencia(vindo)
	var f_indo := _frequencia(indo)
	var razao := f_vindo / maxf(f_indo, 1.0)
	_conta("A27c doppler", razao >= 1.02,
		"a fonte vindo soa %.0f Hz e indo %.0f Hz (%.1f%% de diferenca)"
			% [f_vindo, f_indo, (razao - 1.0) * 100.0])


## Fonte com velocidade RADIAL: vindo para o ouvinte, ou indo embora.
##
## Nao e uma passagem de lado. Numa passagem, metade do trecho e aproximacao e a
## outra metade e afastamento, e a frequencia media das duas volta a ser a
## original — a medida daria zero de diferenca com o doppler funcionando
## perfeitamente. Aqui a fonte so vem, ou so vai, e a 20 m/s: 343/(343-20) da
## 6,2% para cima vindo e 5,5% para baixo indo.
##
## Dois quadros parada antes de tocar porque, com o doppler ligado, o motor mede
## a velocidade do no entre quadros — e o salto do nascimento ate a posicao
## inicial e uma velocidade absurda que entrava como mudez.
func _passagem(sentido: float) -> PackedFloat32Array:
	var p := AudioStreamPlayer3D.new()
	p.stream = _onda(TOM, 1.0, false)
	p.bus = &"SFX"
	p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_IDLE_STEP
	p.unit_size = 20.0
	p.position = Vector3(1.0, 1.0, -6.0 if sentido < 0.0 else -1.5)
	root.add_child(p)
	await process_frame
	await process_frame
	_esvaziar()
	p.play()
	var saida := PackedFloat32Array()
	var alvo := int(TAXA * 0.2)
	for _i in 60:
		# sentido -1: vindo (z sobe para perto de zero). sentido +1: indo embora.
		p.position += Vector3(0.0, 0.0, -20.0 * sentido) / 60.0
		await process_frame
		_recolher(saida)
		if saida.size() >= alvo:
			break
	p.queue_free()
	return saida


## Frequencia por cruzamento de zero, com histerese. Vale porque o sinal e um
## tom so.
##
## Histerese, e nao um piso simples: descartar as amostras pequenas descarta
## exatamente as que estao EM CIMA do zero, que sao as unicas que interessam —
## a primeira versao respondia 0 Hz com meio segundo de tom limpo na mao. Aqui a
## conta e outra: o sinal so muda de estado depois de passar de +piso ou de
## -piso, e o que se conta sao as trocas de estado.
static func _frequencia(dados: PackedFloat32Array) -> float:
	var pico := 0.0
	for v in dados:
		pico = maxf(pico, absf(v))
	if pico <= 1e-6:
		return 0.0
	var piso := pico * 0.25
	var estado := 0
	var trocas := 0
	var primeiro := -1
	var ultimo := -1
	for i in dados.size():
		var v := dados[i]
		var novo := estado
		if v > piso:
			novo = 1
		elif v < -piso:
			novo = -1
		if novo != estado and estado != 0:
			trocas += 1
			if primeiro < 0:
				primeiro = i
			ultimo = i
		estado = novo
	if trocas < 4 or ultimo <= primeiro:
		return 0.0
	var segundos := float(ultimo - primeiro) / TAXA
	return float(trocas - 1) * 0.5 / maxf(segundos, 1e-6)
