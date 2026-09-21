## O jogo de futebol que passa na TV da casa da fumaca — e que da para jogar.
##
## Por que um jogo de verdade, e nao quatro quadros de atlas
## ---------------------------------------------------------
## A TV antiga trocava quatro celulas de 32 px a oito por segundo. De longe lia
## como "futebol"; de perto, sentado no sofa, era um GIF. A casa da fumaca e o
## lugar de gente jogando PS2 — o jogo e o centro da sala, e a imagem dele e a
## luz dela (PLANO_CASA_FUMACA_V2, 5.2 e F4b).
##
## Aqui e uma partida inteira, simulada: vinte e dois jogadores em 4-4-2, bola
## com altura, passe, chute, goleiro, gol com replay, relogio de noventa minutos
## em quatro de verdade, placar e radar no canto — a gramatica de tela de futebol
## de PS2 de 2006. Desenhada em 2D num SubViewport de 320 x 240 (a TV projeta
## a textura dele no tubo), com camera de transmissao: o campo em perspectiva,
## a torcida do outro lado, placas de publicidade.
##
## Custo: um CanvasItem, ~150 primitivas por quadro, simulacao a 30 Hz. Nada 3D.
##
## Quem joga
## ---------
## Sozinha, a partida e CPU contra CPU — e o que os dois do tapete estao jogando.
## `humano = true` poe o time da casa (esquerda para a direita) na mao de quem
## pegou o controle (ControlePS2): o jogador da vez e o do time mais perto da
## bola, com a seta em cima, como sempre foi.
class_name PartidaPS2
extends Node2D

const LARGURA := 320
const ALTURA := 240
const CAMPO := Vector2(105.0, 68.0)
const GOL_MEIA := 3.66
const TRAVESSAO := 2.44
const PASSO := 1.0 / 30.0

## Camera de transmissao. PX_M e pixels por metro na linha de baixo da tela
## (~24 m de largura visiveis); a camera segue a bola em comprimento E em
## profundidade, mostrando FAIXA metros do campo entre Y_FUNDO e Y_FRENTE. Com
## o campo inteiro na tela os jogadores viravam pontos de 4 px: a camera de
## futebol de PS2 e fechada, e e isso que faz o jogador ser gente.
const PX_M := 13.5
const Y_FUNDO := 58.0
const Y_FRENTE := 236.0
const FAIXA := 30.0
const ESCALA_FUNDO := 0.62

## Um minuto de jogo em segundos de verdade.
const MINUTO := 2.6

const VEL_ANDA := 5.4
const VEL_CORRE := 7.4
const VEL_PASSE := 17.0
const VEL_CHUTE := 27.0
const ATRITO := 0.978
const ALCANCE_DOMINIO := 0.95

enum Estado { MENU, JOGO, GOL, REPLAY, INTERVALO, FIM }

## Times de camisa, com as duas cores e a sigla do placar.
const TIMES: Array[Array] = [
	["COR", "CORINTHIANS", Color("f2f2f2"), Color("111111")],
	["FLA", "FLAMENGO", Color("c8102e"), Color("111111")],
	["PAL", "PALMEIRAS", Color("0b6e3a"), Color("f2f2f2")],
	["SAO", "SAO PAULO", Color("f2f2f2"), Color("c8102e")],
	["SAN", "SANTOS", Color("f5f5f5"), Color("222222")],
	["VAS", "VASCO", Color("111111"), Color("f2f2f2")],
	["GRE", "GREMIO", Color("1b75bb"), Color("111111")],
	["INT", "INTERNACIONAL", Color("d40d12"), Color("f2f2f2")],
	["CRU", "CRUZEIRO", Color("1e3f9a"), Color("f2f2f2")],
	["CAM", "ATLETICO-MG", Color("202020"), Color("f2f2f2")],
	["BAH", "BAHIA", Color("1e5bb8"), Color("d6202a")],
	["SPT", "SPORT", Color("c8102e"), Color("111111")],
]

## 4-4-2, com o time atacando para +X. Goleiro primeiro.
const FORMACAO: Array[Vector2] = [
	Vector2(3.0, 34.0),
	Vector2(20.0, 10.0), Vector2(18.0, 26.0), Vector2(18.0, 42.0), Vector2(20.0, 58.0),
	Vector2(38.0, 12.0), Vector2(35.0, 28.0), Vector2(35.0, 40.0), Vector2(38.0, 56.0),
	Vector2(48.0, 27.0), Vector2(49.0, 41.0),
]

var humano: bool = false
## TV de bar e de casa comum: a mesma partida, como transmissao — cartao de "AO
## VIVO" no lugar do menu do Bomba Patch, e sem radar.
var transmissao: bool = false
var estado: Estado = Estado.MENU

var _rng := RandomNumberGenerator.new()
var _times: Array[int] = [0, 1]
var _placar: Array[int] = [0, 0]
var _minuto: float = 0.0
var _relogio_estado: float = 0.0
var _acumulado: float = 0.0
var _t: float = 0.0

# Jogadores: indice 0..10 time 0, 11..21 time 1.
var _pos: PackedVector2Array = PackedVector2Array()
var _vel: PackedVector2Array = PackedVector2Array()
var _fase: PackedFloat32Array = PackedFloat32Array()
var _dono: int = -1
var _alvo_passe: int = -1
var _ultimo_toque: int = -1
var _bola := Vector2.ZERO
var _bola_z := 0.0
var _bola_v := Vector2.ZERO
var _bola_vz := 0.0
var _cam_x := 52.5
var _cam_y := 34.0
var _saida_de: int = 0
## Quem acabou de chutar nao domina a propria bola no quadro seguinte: ela sai
## do pe dele, a setenta centimetros.
var _bloqueado: int = -1
var _bloqueio: float = 0.0

# Humano.
var _eixo := Vector2.ZERO
var _correndo := false
var _pediu_passe := false
var _pediu_chute := false
var _controlado: int = -1
var _olhando := Vector2.RIGHT

# Replay: fotos a 15 Hz dos ultimos 4 s.
const REPLAY_FOTOS := 60
var _fotos: Array[Dictionary] = []
var _foto_tick: int = 0
var _replay_i: int = 0
var _quem_marcou: int = 0

## Contagem para `tests/partida_ps2_sim.gd`: chutes, defesas, bolas pela linha
## de fundo. Nao muda o jogo.
var estat := {"chutes": 0, "defesas": 0, "fundo": 0, "lateral": 0}

var _fonte_p: Font
var _fonte_m: Font
var _fonte_t: Font


func _ready() -> void:
	_rng.randomize()
	_fonte_p = load("res://assets/fontes/psx_pequena.fnt") as Font
	_fonte_m = load("res://assets/fontes/psx_media.fnt") as Font
	_fonte_t = load("res://assets/fontes/psx_titulo.fnt") as Font
	for k in 22:
		_pos.append(Vector2.ZERO)
		_vel.append(Vector2.ZERO)
		_fase.append(_rng.randf() * TAU)
	_nova_partida()


# --- API de quem joga e de quem ilumina --------------------------------------

## A entrada do controle, lida a cada quadro por ControlePS2.
func entrada(eixo: Vector2, correndo: bool) -> void:
	_eixo = eixo.limit_length(1.0)
	_correndo = correndo


func passe() -> void:
	if estado == Estado.JOGO:
		_pediu_passe = true
	elif estado == Estado.MENU:
		_relogio_estado = 99.0


func chute() -> void:
	if estado == Estado.JOGO:
		_pediu_chute = true
	elif estado == Estado.REPLAY:
		_relogio_estado = 99.0


## A cor media da imagem, para a luz da TV. Calculada do estado, e nao lida da
## textura: ler o quadro de volta da placa de video a cada quadro custaria mais
## que a partida inteira.
func cor_media() -> Color:
	match estado:
		Estado.MENU:
			return Color(0.25, 0.35, 0.85)
		Estado.GOL:
			var p := 0.5 + 0.5 * sin(_t * 18.0)
			return Color(0.9, 0.85, 0.55).lerp(Color(0.35, 0.6, 0.35), p * 0.5)
		Estado.REPLAY:
			return Color(0.40, 0.55, 0.50)
		Estado.INTERVALO, Estado.FIM:
			return Color(0.20, 0.25, 0.55)
	return Color(0.32, 0.58, 0.34)


func brilho() -> float:
	match estado:
		Estado.GOL:
			return 1.15 + 0.2 * sin(_t * 18.0)
		Estado.MENU, Estado.INTERVALO, Estado.FIM:
			return 0.75
	return 1.0


# --- tempo --------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	_acumulado = minf(_acumulado + delta, 0.25)
	var mudou := false
	while _acumulado >= PASSO:
		_acumulado -= PASSO
		_tick()
		mudou = true
	if mudou:
		queue_redraw()


func _tick() -> void:
	_relogio_estado += PASSO
	match estado:
		Estado.MENU:
			if _relogio_estado > 3.2:
				_pontape(_saida_de)
				estado = Estado.JOGO
		Estado.JOGO:
			_simular()
			_minuto += PASSO / MINUTO
			if _minuto >= 45.0 and _minuto - PASSO / MINUTO < 45.0:
				estado = Estado.INTERVALO
				_relogio_estado = 0.0
			elif _minuto >= 90.0:
				estado = Estado.FIM
				_relogio_estado = 0.0
		Estado.GOL:
			_simular_bola()
			_comemorar()
			if _relogio_estado > 2.6:
				estado = Estado.REPLAY
				_relogio_estado = 0.0
				_replay_i = 0
		Estado.REPLAY:
			_replay_i = mini(_replay_i + 1, _fotos.size() * 2 - 1)
			if _relogio_estado > float(_fotos.size()) / 15.0 * 1.0 + 0.4:
				_pontape(1 - _quem_marcou)
				estado = Estado.JOGO
				_relogio_estado = 0.0
		Estado.INTERVALO:
			if _relogio_estado > 3.0:
				_pontape(1)
				estado = Estado.JOGO
				_relogio_estado = 0.0
				_minuto = 45.01
		Estado.FIM:
			if _relogio_estado > 5.0:
				_nova_partida()
	_cam_x = lerpf(_cam_x, clampf(_bola.x, 14.0, CAMPO.x - 14.0), 0.08)
	_cam_y = lerpf(_cam_y, _y_da_camera(_bola.y), 0.06)


## Centro da faixa de profundidade visivel, preso para nao mostrar alem de 5 m
## fora das linhas laterais.
static func _y_da_camera(bola_y: float) -> float:
	return clampf(bola_y, FAIXA * 0.5 - 5.0, CAMPO.y - FAIXA * 0.5 + 5.0)


func _nova_partida() -> void:
	var a := _rng.randi() % TIMES.size()
	var b := (a + 1 + _rng.randi() % (TIMES.size() - 1)) % TIMES.size()
	_times = [a, b]
	_placar = [0, 0]
	_minuto = 0.0
	_saida_de = _rng.randi() % 2
	estado = Estado.MENU
	_relogio_estado = 0.0
	_pontape(_saida_de)


## Todo mundo na formacao, bola no meio com quem sai.
func _pontape(time: int) -> void:
	for k in 22:
		_pos[k] = _casa(k, Vector2(52.5, 34.0))
		_vel[k] = Vector2.ZERO
	_bola = Vector2(52.5, 34.0)
	_bola_v = Vector2.ZERO
	_bola_z = 0.0
	_bola_vz = 0.0
	var quem := 9 + time * 11
	_pos[quem] = _bola - Vector2(0.8 * _sentido(time), 0.0)
	_dono = quem
	_alvo_passe = -1
	_fotos.clear()


static func _time_de(k: int) -> int:
	return 0 if k < 11 else 1


static func _sentido(time: int) -> float:
	return 1.0 if time == 0 else -1.0


## Posicao de formacao do jogador, deslocada pela bola: o bloco inteiro sobe e
## desce junto, e se estreita para o lado da jogada.
func _casa(k: int, bola: Vector2) -> Vector2:
	var time := _time_de(k)
	var f: Vector2 = FORMACAO[k % 11]
	var x := f.x if time == 0 else CAMPO.x - f.x
	var y := f.y
	if k % 11 == 0:
		return Vector2(x, clampf(lerpf(34.0, bola.y, 0.35), 30.0, 38.0))
	var avanco := (bola.x - 52.5) * 0.55
	var ataca := _dono >= 0 and _time_de(_dono) == time
	avanco += (10.0 if ataca else -3.0) * _sentido(time)
	x = clampf(x + avanco, 4.0, CAMPO.x - 4.0)
	y = lerpf(y, bola.y, 0.22)
	return Vector2(x, y)


# --- simulacao ---------------------------------------------------------------

func _simular() -> void:
	_bloqueio -= PASSO
	_atualizar_controlado()
	for k in 22:
		_mover(k)
	_simular_bola()
	_disputar()
	_checar_saida()
	_foto()


func _atualizar_controlado() -> void:
	if not humano:
		_controlado = -1
		return
	if _dono >= 0 and _dono < 11:
		_controlado = _dono
		return
	if _alvo_passe >= 0 and _alvo_passe < 11:
		_controlado = _alvo_passe
		return
	var melhor := _controlado
	var d_melhor := INF if melhor < 0 else _pos[melhor].distance_to(_bola) - 3.0
	for k in range(1, 11):
		var d := _pos[k].distance_to(_bola)
		if d < d_melhor:
			d_melhor = d
			melhor = k
	_controlado = melhor


func _mover(k: int) -> void:
	var time := _time_de(k)
	var alvo := _casa(k, _bola)
	var vel_max := VEL_ANDA
	var tem_bola := _dono == k

	if k == _controlado and humano:
		var v := _eixo * (VEL_CORRE if _correndo else VEL_ANDA)
		if v.length() > 0.2:
			_olhando = v.normalized()
		_vel[k] = _vel[k].lerp(v, 0.3)
		if tem_bola:
			if _pediu_chute:
				_chutar(k, _eixo.y)
			elif _pediu_passe:
				_passar(k, _olhando)
		elif _pediu_chute or _pediu_passe:
			# Sem a bola, o botao e o bote: um carrinho curto na direcao dela.
			if _pos[k].distance_to(_bola) < 2.2 and _dono >= 11:
				_roubar(k, 0.55)
		_pediu_chute = false
		_pediu_passe = false
		_pos[k] = _limitar(_pos[k] + _vel[k] * PASSO)
		_fase[k] += _vel[k].length() * PASSO * 2.4
		return

	if tem_bola:
		_conduzir(k)
		return
	if k == _alvo_passe:
		alvo = _bola + _bola_v * 0.35
		vel_max = VEL_CORRE
	elif k % 11 == 0:
		# Goleiro: na linha, acompanhando a bola, e sai quando ela entra na area.
		var gx := 1.5 if time == 0 else CAMPO.x - 1.5
		alvo = Vector2(gx, clampf(_bola.y, 34.0 - GOL_MEIA, 34.0 + GOL_MEIA))
		var perto_do_gol := absf(_bola.x - gx) < 16.0 and absf(_bola.y - 34.0) < 20.0
		if perto_do_gol and _dono < 0 and absf(_bola.x - gx) < 7.0:
			alvo = _bola
			vel_max = VEL_CORRE
	else:
		var defende := _dono < 0 or _time_de(_dono) != time
		if defende and k == _mais_perto_da_bola(time):
			alvo = _bola + _bola_v * 0.25
			vel_max = VEL_CORRE * 0.84
	var dir := alvo - _pos[k]
	var quer := Vector2.ZERO
	if dir.length() > 0.4:
		quer = dir.normalized() * minf(vel_max, dir.length() * 2.2)
	_vel[k] = _vel[k].lerp(quer, 0.12)
	_pos[k] = _limitar(_pos[k] + _vel[k] * PASSO)
	_fase[k] += _vel[k].length() * PASSO * 2.4


func _mais_perto_da_bola(time: int) -> int:
	var melhor := -1
	var d_melhor := INF
	for k in range(time * 11 + 1, time * 11 + 11):
		if k == _controlado and humano:
			continue
		var d := _pos[k].distance_to(_bola)
		if d < d_melhor:
			d_melhor = d
			melhor = k
	return melhor


## A CPU com a bola: leva para o gol, passa quando apertam, chuta de perto.
func _conduzir(k: int) -> void:
	var time := _time_de(k)
	var gol := Vector2(CAMPO.x if time == 0 else 0.0, 34.0)
	var ate_gol := _pos[k].distance_to(gol)
	var rumo := (gol + Vector2(0.0, sin(_t * 0.7 + k) * 8.0) - _pos[k]).normalized()
	# Marcador na frente: desvia para o lado livre.
	var pressao := _pressao(k)
	if pressao.length() > 0.0:
		rumo = (rumo - pressao * 0.7).normalized()
	# Com espaco, arranca; apertado, conduz devagar e protege.
	var vel := VEL_CORRE * 0.9 if pressao.length() < 0.2 else VEL_ANDA * 0.9
	_vel[k] = _vel[k].lerp(rumo * vel, 0.15)
	_pos[k] = _limitar(_pos[k] + _vel[k] * PASSO)
	_fase[k] += _vel[k].length() * PASSO * 2.4
	if k % 11 == 0:
		_passar(k, Vector2(_sentido(time), 0.0))
		return
	if ate_gol < 36.0 and _rng.randf() < (0.12 if ate_gol < 18.0 else 0.04):
		_chutar(k, _rng.randf_range(-0.8, 0.8))
	elif pressao.length() > 0.3 and _rng.randf() < 0.10:
		_passar(k, rumo)
	elif _rng.randf() < 0.012:
		_passar(k, rumo)


## Vetor apontando para o adversario mais perto, com peso pela proximidade.
func _pressao(k: int) -> Vector2:
	var outro := 1 - _time_de(k)
	var soma := Vector2.ZERO
	for j in range(outro * 11, outro * 11 + 11):
		var d := _pos[j] - _pos[k]
		var dist := d.length()
		if dist < 4.0 and dist > 0.01:
			soma += d / dist * (1.0 - dist / 4.0)
	return soma


## Passe para o companheiro mais bem colocado na direcao pedida.
func _passar(k: int, dir: Vector2) -> void:
	var time := _time_de(k)
	var melhor := -1
	var nota_melhor := -INF
	for j in range(time * 11 + 1, time * 11 + 11):
		if j == k:
			continue
		var d := _pos[j] - _pos[k]
		var dist := d.length()
		if dist < 5.0 or dist > 38.0:
			continue
		var alinhado := d.normalized().dot(dir.normalized())
		var avanca := d.x * _sentido(time) * 0.04
		var livre := 1.0 - minf(_pressao(j).length(), 1.0)
		var nota := alinhado * 2.0 + avanca + livre - dist * 0.015
		if nota > nota_melhor:
			nota_melhor = nota
			melhor = j
	if melhor < 0:
		return
	var destino := _pos[melhor] + _vel[melhor] * 0.5
	var v := destino - _bola
	var forca := clampf(v.length() * 1.3, 9.0, VEL_PASSE + 4.0)
	_bola_v = v.normalized() * forca
	_bola_vz = 2.5 if v.length() > 25.0 else 0.0
	_dono = -1
	_alvo_passe = melhor
	_ultimo_toque = k
	_bloqueado = k
	_bloqueio = 0.35


## Chute ao gol. `mira` de -1 a 1 escolhe o canto.
func _chutar(k: int, mira: float) -> void:
	var time := _time_de(k)
	var gx := CAMPO.x + 0.5 if time == 0 else -0.5
	var erro := _rng.randf_range(-2.2, 2.2) * (1.0 + _pos[k].distance_to(Vector2(gx, 34.0)) / 25.0)
	var destino := Vector2(gx, 34.0 + clampf(mira, -1.0, 1.0) * (GOL_MEIA - 0.6) + erro)
	estat["chutes"] += 1
	_bola_v = (destino - _bola).normalized() * VEL_CHUTE * _rng.randf_range(0.85, 1.05)
	_bola_vz = _rng.randf_range(1.5, 5.2)
	_dono = -1
	_alvo_passe = -1
	_ultimo_toque = k
	_bloqueado = k
	_bloqueio = 0.35


func _roubar(k: int, chance: float) -> void:
	if _rng.randf() < chance:
		_dono = k
		_alvo_passe = -1
		_ultimo_toque = k


func _simular_bola() -> void:
	if _dono >= 0:
		var frente := _vel[_dono].normalized() if _vel[_dono].length() > 0.3 \
			else Vector2(_sentido(_time_de(_dono)), 0.0)
		_bola = _bola.lerp(_pos[_dono] + frente * 0.7, 0.5)
		_bola_v = _vel[_dono]
		_bola_z = 0.0
		_bola_vz = 0.0
		return
	_bola += _bola_v * PASSO
	_bola_z += _bola_vz * PASSO
	if _bola_z > 0.0:
		_bola_vz -= 9.8 * PASSO
	else:
		_bola_z = 0.0
		if _bola_vz < -2.0:
			_bola_vz = -_bola_vz * 0.45
		else:
			_bola_vz = 0.0
		_bola_v *= ATRITO


## Quem esta perto da bola solta domina; quem esta perto de quem tem a bola
## pode tomar.
func _disputar() -> void:
	if _dono < 0:
		if _bola_z > 1.9:
			return
		var rapida := _bola_v.length() > 19.0
		var melhor := -1
		var d_melhor := INF
		for k in 22:
			if k == _bloqueado and _bloqueio > 0.0:
				continue
			var goleiro := k % 11 == 0
			# O goleiro alcanca quase o dobro: e o mergulho.
			var d := _pos[k].distance_to(_bola) / (1.8 if goleiro else 1.0)
			if d >= ALCANCE_DOMINIO or d >= d_melhor:
				continue
			# Bola forte passa de quem nao e o alvo — e as vezes do goleiro.
			if rapida and k != _alvo_passe and _rng.randf() > (0.3 if goleiro else 0.2):
				continue
			d_melhor = d
			melhor = k
		if melhor >= 0:
			if melhor % 11 == 0 and rapida:
				estat["defesas"] += 1
			_dono = melhor
			_alvo_passe = -1
			_ultimo_toque = melhor
		return
	var time := _time_de(_dono)
	var outro := 1 - time
	for j in range(outro * 11, outro * 11 + 11):
		if j == _controlado and humano:
			continue
		if _pos[j].distance_to(_pos[_dono]) < 0.9 and _rng.randf() < 0.009:
			_roubar(j, 1.0)
			return


func _checar_saida() -> void:
	if _dono >= 0:
		return
	# Gol.
	if (_bola.x < 0.0 or _bola.x > CAMPO.x) and absf(_bola.y - 34.0) < GOL_MEIA \
			and _bola_z < TRAVESSAO:
		_quem_marcou = 0 if _bola.x > CAMPO.x else 1
		_placar[_quem_marcou] += 1
		estado = Estado.GOL
		_relogio_estado = 0.0
		_bola_v *= 0.2
		return
	# Lateral: bola para o outro time, na linha.
	if _bola.y < -0.5 or _bola.y > CAMPO.y + 0.5:
		estat["lateral"] += 1
		var time := 1 - _time_de(maxi(_ultimo_toque, 0))
		_bola = Vector2(clampf(_bola.x, 2.0, CAMPO.x - 2.0), clampf(_bola.y, 0.5, CAMPO.y - 0.5))
		_dar_a(time)
		return
	# Linha de fundo: tiro de meta para quem defende.
	if _bola.x < -0.5 or _bola.x > CAMPO.x + 0.5:
		estat["fundo"] += 1
		var defende := 0 if _bola.x < 0.0 else 1
		_bola = Vector2(5.5 if defende == 0 else CAMPO.x - 5.5, 34.0)
		_bola_z = 0.0
		_pos[defende * 11] = _bola - Vector2(0.8 * _sentido(defende), 0.0)
		_dono = defende * 11


func _dar_a(time: int) -> void:
	var melhor := -1
	var d_melhor := INF
	for k in range(time * 11 + 1, time * 11 + 11):
		var d := _pos[k].distance_to(_bola)
		if d < d_melhor:
			d_melhor = d
			melhor = k
	_pos[melhor] = _bola
	_bola_v = Vector2.ZERO
	_bola_vz = 0.0
	_bola_z = 0.0
	_dono = melhor


func _limitar(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, -2.0, CAMPO.x + 2.0), clampf(p.y, -1.5, CAMPO.y + 1.5))


## Depois do gol, quem marcou corre para a bandeirinha e o resto volta devagar.
func _comemorar() -> void:
	var canto := Vector2(CAMPO.x - 2.0 if _quem_marcou == 0 else 2.0, CAMPO.y - 1.0)
	for k in 22:
		var alvo := canto if _time_de(k) == _quem_marcou and k % 11 != 0 \
			else _casa(k, Vector2(52.5, 34.0))
		var d := alvo - _pos[k]
		var v := d.normalized() * minf(VEL_ANDA, d.length()) if d.length() > 1.0 else Vector2.ZERO
		_vel[k] = _vel[k].lerp(v, 0.1)
		_pos[k] += _vel[k] * PASSO
		_fase[k] += _vel[k].length() * PASSO * 2.4


func _foto() -> void:
	_foto_tick += 1
	if _foto_tick % 2 != 0:
		return
	_fotos.append({"p": _pos.duplicate(), "f": _fase.duplicate(), "b": _bola, "z": _bola_z})
	if _fotos.size() > REPLAY_FOTOS:
		_fotos.pop_front()


# --- desenho ------------------------------------------------------------------

## Campo (metros) para tela (pixels), com altura em metros. `cam` e o ponto do
## campo no centro da tela (x) e no meio da faixa visivel (y).
func _tela(p: Vector2, z: float = 0.0, cam: Vector2 = Vector2(-1.0, -1.0)) -> Vector2:
	var c := Vector2(_cam_x, _cam_y) if cam.x < 0.0 else cam
	var t := (p.y - (c.y - FAIXA * 0.5)) / FAIXA
	var s := _escala_t(t)
	return Vector2(160.0 + (p.x - c.x) * PX_M * s,
		lerpf(Y_FUNDO, Y_FRENTE, t) - z * PX_M * s * 0.85)


static func _escala_t(t: float) -> float:
	return maxf(lerpf(ESCALA_FUNDO, 1.0, t), 0.3)


func _escala(y: float, cam: Vector2) -> float:
	return _escala_t((y - (cam.y - FAIXA * 0.5)) / FAIXA)


func _draw() -> void:
	match estado:
		Estado.MENU:
			_desenhar_menu()
			return
		Estado.INTERVALO, Estado.FIM:
			_desenhar_campo(_pos, _fase, _bola, _bola_z, Vector2(_cam_x, _cam_y))
			_desenhar_quadro_placar(estado == Estado.FIM)
			return
		Estado.REPLAY:
			var i := clampi(_replay_i / 2, 0, maxi(_fotos.size() - 1, 0))
			if _fotos.is_empty():
				_desenhar_campo(_pos, _fase, _bola, _bola_z, Vector2(_cam_x, _cam_y))
			else:
				var f: Dictionary = _fotos[i]
				var b: Vector2 = f["b"]
				var cam := Vector2(clampf(b.x, 14.0, CAMPO.x - 14.0), _y_da_camera(b.y))
				_desenhar_campo(f["p"], f["f"], b, f["z"], cam)
			_desenhar_replay()
			return
	_desenhar_campo(_pos, _fase, _bola, _bola_z, Vector2(_cam_x, _cam_y))
	_desenhar_placar()
	if transmissao:
		_desenhar_ao_vivo()
	else:
		_desenhar_radar()
	if estado == Estado.GOL:
		_desenhar_gol()


func _desenhar_campo(pos: PackedVector2Array, fase: PackedFloat32Array,
		bola: Vector2, bola_z: float, cam: Vector2) -> void:
	# Ceu de estadio a noite e a arquibancada, acima da linha de fundo.
	draw_rect(Rect2(0, 0, LARGURA, ALTURA), Color(0.05, 0.06, 0.09))
	var linha_fundo := _tela(Vector2(cam.x, -2.5), 0.0, cam).y
	var s_fundo := _escala(-2.5, cam)
	var arq_base := linha_fundo - 9.0 * s_fundo
	var arq_topo := arq_base - 70.0 * s_fundo
	if arq_base > 0.0:
		draw_rect(Rect2(0, arq_topo, LARGURA, arq_base - arq_topo), Color(0.12, 0.12, 0.15))
		var passo_fila := 5.0 * s_fundo
		var fila := 0
		var y := arq_base - passo_fila
		while y > arq_topo and fila < 16:
			var desloca := (cam.x - 52.5) * PX_M * s_fundo * 0.9 + fila * 13.0
			for i in 64:
				var h := hash(i * 7919 + fila * 104729 + 13)
				var x := fposmod(float(i) * 5.3 * s_fundo * 1.9 - desloca + float(h % 7), float(LARGURA) + 40.0) - 20.0
				var c := Color.from_hsv(float(h % 97) / 97.0, 0.45, 0.30 + float(h % 5) * 0.09)
				if (h + int(_t * 4.0)) % 173 == 0:
					c = Color(1.5, 1.5, 1.4)
				draw_rect(Rect2(x, y, maxf(1.0, 2.4 * s_fundo), maxf(1.0, 2.8 * s_fundo)), c)
			y -= passo_fila
			fila += 1
		# Placas de publicidade na beira do campo, presas ao campo.
		var placas := ["BOMBA", "GUARANA", "PS2", "RADIO 98", "BAR DO ZE", "CERVEJA"]
		var cores := [Color("d6202a"), Color("0b6e3a"), Color("1e3f9a"), Color("e8a317"), Color("5a2d82"), Color("c8102e")]
		var larg_placa := 9.0 * PX_M * s_fundo
		for i in 12:
			var x0 := float(i) * 9.0 - 1.0
			var a := _tela(Vector2(x0, -2.0), 0.0, cam)
			if a.x < -larg_placa or a.x > LARGURA:
				continue
			var alto := 7.0 * s_fundo
			draw_rect(Rect2(a.x, a.y - alto, larg_placa - 1.0, alto), cores[i % cores.size()])
			draw_string(_fonte_p, Vector2(a.x + 3, a.y - 1.0), placas[i % placas.size()],
				HORIZONTAL_ALIGNMENT_LEFT, larg_placa - 4.0, 11, Color(1, 1, 1, 0.9))

	# Grama listrada: faixas de 5,25 m ao longo do comprimento.
	var n := 20
	for i in n:
		var x0 := CAMPO.x * float(i) / float(n)
		var x1 := CAMPO.x * float(i + 1) / float(n)
		var cor := Color(0.18, 0.46, 0.16) if i % 2 == 0 else Color(0.22, 0.53, 0.19)
		var q := PackedVector2Array([
			_tela(Vector2(x0 - 6.0 if i == 0 else x0, -1.6), 0.0, cam),
			_tela(Vector2(x1 + 6.0 if i == n - 1 else x1, -1.6), 0.0, cam),
			_tela(Vector2(x1 + 6.0 if i == n - 1 else x1, CAMPO.y + 6.0), 0.0, cam),
			_tela(Vector2(x0 - 6.0 if i == 0 else x0, CAMPO.y + 6.0), 0.0, cam)])
		draw_colored_polygon(q, cor)

	# Linhas.
	var branco := Color(0.92, 0.95, 0.9, 0.9)
	_linha_campo([Vector2(0, 0), Vector2(CAMPO.x, 0), CAMPO, Vector2(0, CAMPO.y), Vector2(0, 0)], branco, cam)
	_linha_campo([Vector2(52.5, 0), Vector2(52.5, CAMPO.y)], branco, cam)
	var circulo: Array[Vector2] = []
	for i in 25:
		var a := TAU * float(i) / 24.0
		circulo.append(Vector2(52.5, 34.0) + Vector2(cos(a), sin(a)) * 9.15)
	_linha_campo(circulo, branco, cam)
	for lado: float in [0.0, 1.0]:
		var x := lado * CAMPO.x
		var s := 1.0 - 2.0 * lado
		_linha_campo([Vector2(x, 13.85), Vector2(x + s * 16.5, 13.85), Vector2(x + s * 16.5, 54.15), Vector2(x, 54.15)], branco, cam)
		_linha_campo([Vector2(x, 24.85), Vector2(x + s * 5.5, 24.85), Vector2(x + s * 5.5, 43.15), Vector2(x, 43.15)], branco, cam)
	# Gols: rede atras, traves e travessao.
	for lado: float in [0.0, 1.0]:
		var x := lado * CAMPO.x
		var fundo := x - (1.0 - 2.0 * lado) * 2.0
		var a := _tela(Vector2(x, 34.0 - GOL_MEIA), 0.0, cam)
		var b := _tela(Vector2(x, 34.0 + GOL_MEIA), 0.0, cam)
		var at := _tela(Vector2(x, 34.0 - GOL_MEIA), TRAVESSAO, cam)
		var bt := _tela(Vector2(x, 34.0 + GOL_MEIA), TRAVESSAO, cam)
		var fa := _tela(Vector2(fundo, 34.0 - GOL_MEIA), 0.0, cam)
		var fb := _tela(Vector2(fundo, 34.0 + GOL_MEIA), 0.0, cam)
		var fat := _tela(Vector2(fundo, 34.0 - GOL_MEIA), TRAVESSAO * 0.8, cam)
		var fbt := _tela(Vector2(fundo, 34.0 + GOL_MEIA), TRAVESSAO * 0.8, cam)
		draw_colored_polygon(PackedVector2Array([at, bt, fbt, fat]), Color(0.85, 0.88, 0.9, 0.18))
		draw_colored_polygon(PackedVector2Array([fat, fbt, fb, fa]), Color(0.85, 0.88, 0.9, 0.22))
		draw_line(a, at, Color.WHITE, 1.5)
		draw_line(b, bt, Color.WHITE, 1.5)
		draw_line(at, bt, Color.WHITE, 1.5)

	# Jogadores e bola, do fundo para a frente.
	var ordem: Array[int] = []
	for k in 22:
		ordem.append(k)
	ordem.sort_custom(func(a: int, b: int) -> bool: return pos[a].y < pos[b].y)
	var bola_desenhada := false
	for k in ordem:
		if not bola_desenhada and bola.y < pos[k].y:
			_desenhar_bola(bola, bola_z, cam)
			bola_desenhada = true
		_desenhar_jogador(k, pos[k], fase[k], cam)
	if not bola_desenhada:
		_desenhar_bola(bola, bola_z, cam)


func _linha_campo(pontos: Array, cor: Color, cam: Vector2) -> void:
	var tela := PackedVector2Array()
	for p: Vector2 in pontos:
		tela.append(_tela(p, 0.0, cam))
	draw_polyline(tela, cor, 1.0)


func _desenhar_jogador(k: int, p: Vector2, fase: float, cam: Vector2) -> void:
	var time := _time_de(k)
	var t: Array = TIMES[_times[time]]
	var camisa: Color = t[2]
	var calcao: Color = t[3]
	if k % 11 == 0:
		camisa = Color("e8d317") if time == 0 else Color("2fb34a")
		calcao = Color(0.1, 0.1, 0.1)
	var s := _escala(p.y, cam)
	var pe := _tela(p, 0.0, cam)
	if pe.x < -10.0 or pe.x > LARGURA + 10.0:
		return
	var u := PX_M * s
	# Sombra.
	draw_set_transform(pe, 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, u * 0.45, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)
	var passo := sin(fase) * u * 0.18
	var pele := Color(0.62, 0.42, 0.30) if (k * 7) % 3 == 0 else Color(0.85, 0.66, 0.52)
	# Pernas, calcao, camisa, cabeca.
	draw_line(pe + Vector2(-u * 0.10 + passo, 0), pe + Vector2(-u * 0.08, -u * 0.55), pele * 0.9, maxf(1.0, u * 0.13))
	draw_line(pe + Vector2(u * 0.10 - passo, 0), pe + Vector2(u * 0.08, -u * 0.55), pele * 0.9, maxf(1.0, u * 0.13))
	draw_rect(Rect2(pe + Vector2(-u * 0.17, -u * 0.72), Vector2(u * 0.34, u * 0.2)), calcao)
	draw_rect(Rect2(pe + Vector2(-u * 0.19, -u * 1.25), Vector2(u * 0.38, u * 0.55)), camisa)
	draw_circle(pe + Vector2(0, -u * 1.38), u * 0.13, pele)
	# A seta de quem o humano controla.
	if humano and k == _controlado:
		var topo := pe + Vector2(0, -u * 1.7)
		var pisca := 0.75 + 0.25 * sin(_t * 10.0)
		draw_colored_polygon(PackedVector2Array([topo + Vector2(-3, -5), topo + Vector2(3, -5), topo]),
			Color(0.3, 0.8, 1.0) * pisca)
		draw_string(_fonte_p, topo + Vector2(-5, -6), "P1", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.3, 0.8, 1.0))


func _desenhar_bola(b: Vector2, z: float, cam: Vector2) -> void:
	var s := _escala(b.y, cam)
	var chao := _tela(b, 0.0, cam)
	draw_set_transform(chao, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 2.0 * s + 0.5, Color(0, 0, 0, 0.4))
	draw_set_transform(Vector2.ZERO)
	var no_ar := _tela(b, z + 0.11, cam)
	draw_circle(no_ar, 2.1 * s + 0.4, Color(0.97, 0.97, 0.95))
	draw_circle(no_ar + Vector2(0.5, 0.4), 0.8 * s, Color(0.2, 0.2, 0.2))


func _desenhar_placar() -> void:
	var a: Array = TIMES[_times[0]]
	var b: Array = TIMES[_times[1]]
	# [cor] SIG [0-0] SIG [cor] [minuto], em caixas separadas como na TV.
	draw_rect(Rect2(8, 6, 104, 15), Color(0.05, 0.08, 0.2, 0.88))
	draw_rect(Rect2(8, 6, 4, 15), a[2])
	draw_rect(Rect2(108, 6, 4, 15), b[2])
	draw_string(_fonte_p, Vector2(15, 17), a[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
	draw_rect(Rect2(44, 7, 32, 13), Color(0.9, 0.9, 0.95, 0.95))
	draw_string(_fonte_p, Vector2(44, 17), "%d-%d" % [_placar[0], _placar[1]],
		HORIZONTAL_ALIGNMENT_CENTER, 32, 11, Color(0.05, 0.05, 0.1))
	draw_string(_fonte_p, Vector2(79, 17), b[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
	var m := mini(int(_minuto), 90)
	draw_rect(Rect2(114, 6, 26, 15), Color(0.05, 0.08, 0.2, 0.88))
	draw_string(_fonte_p, Vector2(114, 17), "%02d'" % m, HORIZONTAL_ALIGNMENT_CENTER, 26, 11, Color(1.0, 0.85, 0.2))


func _desenhar_radar() -> void:
	var r := Rect2(125, 208, 70, 28)
	draw_rect(r, Color(0.0, 0.15, 0.05, 0.55))
	draw_rect(r, Color(1, 1, 1, 0.5), false, 1.0)
	draw_line(Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.end.y), Color(1, 1, 1, 0.35))
	for k in 22:
		var q := r.position + Vector2(_pos[k].x / CAMPO.x * r.size.x, _pos[k].y / CAMPO.y * r.size.y)
		var c: Color = TIMES[_times[_time_de(k)]][2]
		if humano and k == _controlado:
			c = Color(0.3, 0.8, 1.0)
		draw_rect(Rect2(q - Vector2(1, 1), Vector2(2, 2)), c)
	var qb := r.position + Vector2(_bola.x / CAMPO.x * r.size.x, _bola.y / CAMPO.y * r.size.y)
	draw_rect(Rect2(qb - Vector2(1, 1), Vector2(2, 2)), Color(1, 1, 0.4))


func _desenhar_gol() -> void:
	var escala := 1.0 + 0.12 * sin(_t * 14.0)
	var cor := Color(1.0, 0.85, 0.2) if int(_t * 8.0) % 2 == 0 else Color(1.0, 1.0, 1.0)
	draw_set_transform(Vector2(160, 110), sin(_t * 3.0) * 0.05, Vector2(escala * 2.0, escala * 2.0))
	draw_string(_fonte_t, Vector2(-38, 6), "GOOOOL!", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0, 0, 0, 0.6))
	draw_string(_fonte_t, Vector2(-39, 5), "GOOOOL!", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, cor)
	draw_set_transform(Vector2.ZERO)
	var quem: Array = TIMES[_times[_quem_marcou]]
	draw_rect(Rect2(60, 150, 200, 18), Color(0.05, 0.08, 0.2, 0.85))
	draw_string(_fonte_m, Vector2(60, 164), quem[1], HORIZONTAL_ALIGNMENT_CENTER, 200, 14, Color.WHITE)


func _desenhar_replay() -> void:
	draw_rect(Rect2(0, 0, LARGURA, 14), Color(0, 0, 0, 0.9))
	draw_rect(Rect2(0, ALTURA - 14, LARGURA, 14), Color(0, 0, 0, 0.9))
	if int(_t * 2.0) % 2 == 0:
		draw_circle(Vector2(LARGURA - 58, 24), 4.0, Color(0.9, 0.1, 0.1))
	draw_string(_fonte_m, Vector2(LARGURA - 50, 29), "REPLAY", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)


func _desenhar_quadro_placar(fim: bool) -> void:
	draw_rect(Rect2(0, 0, LARGURA, ALTURA), Color(0.02, 0.03, 0.10, 0.72))
	var a: Array = TIMES[_times[0]]
	var b: Array = TIMES[_times[1]]
	var titulo := "FIM DE JOGO" if fim else "INTERVALO"
	draw_string(_fonte_t, Vector2(0, 70), titulo, HORIZONTAL_ALIGNMENT_CENTER, LARGURA, 18, Color(1.0, 0.85, 0.2))
	draw_rect(Rect2(40, 96, 240, 40), Color(0.05, 0.08, 0.25, 0.95))
	draw_rect(Rect2(40, 96, 6, 40), a[2])
	draw_rect(Rect2(274, 96, 6, 40), b[2])
	draw_string(_fonte_m, Vector2(50, 121), a[1], HORIZONTAL_ALIGNMENT_LEFT, 100, 14, Color.WHITE)
	draw_string(_fonte_m, Vector2(170, 121), b[1], HORIZONTAL_ALIGNMENT_RIGHT, 100, 14, Color.WHITE)
	draw_string(_fonte_t, Vector2(0, 124), "%d  -  %d" % [_placar[0], _placar[1]], HORIZONTAL_ALIGNMENT_CENTER, LARGURA, 18, Color.WHITE)


func _desenhar_ao_vivo() -> void:
	draw_rect(Rect2(LARGURA - 62, 6, 54, 13), Color(0.75, 0.05, 0.08, 0.9))
	if int(_t * 1.5) % 2 == 0:
		draw_circle(Vector2(LARGURA - 55, 12.5), 2.5, Color.WHITE)
	draw_string(_fonte_p, Vector2(LARGURA - 50, 17), "AO VIVO", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)


func _desenhar_menu() -> void:
	if transmissao:
		_desenhar_abertura_tv()
		return
	for i in 24:
		var y := float(i) * 10.0
		draw_rect(Rect2(0, y, LARGURA, 10), Color(0.04, 0.07, 0.22).lerp(Color(0.10, 0.22, 0.55), float(i) / 24.0))
	# Faixas diagonais correndo, como toda tela de titulo da epoca.
	for i in 8:
		var x := fposmod(float(i) * 60.0 + _t * 40.0, 480.0) - 80.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 20, 0), Vector2(x - 60, ALTURA), Vector2(x - 80, ALTURA)]),
			Color(1, 1, 1, 0.04))
	draw_string(_fonte_t, Vector2(0, 62), "BOMBA PATCH", HORIZONTAL_ALIGNMENT_CENTER, LARGURA, 18, Color(1.0, 0.85, 0.2))
	draw_string(_fonte_m, Vector2(0, 80), "2 0 0 9   BRASILEIRAO", HORIZONTAL_ALIGNMENT_CENTER, LARGURA, 14, Color(0.8, 0.9, 1.0))
	var a: Array = TIMES[_times[0]]
	var b: Array = TIMES[_times[1]]
	draw_rect(Rect2(30, 110, 110, 34), a[2].darkened(0.2))
	draw_rect(Rect2(180, 110, 110, 34), b[2].darkened(0.2))
	draw_string(_fonte_m, Vector2(30, 132), a[1], HORIZONTAL_ALIGNMENT_CENTER, 110, 14, a[3] if a[2].get_luminance() > 0.6 else Color.WHITE)
	draw_string(_fonte_m, Vector2(180, 132), b[1], HORIZONTAL_ALIGNMENT_CENTER, 110, 14, b[3] if b[2].get_luminance() > 0.6 else Color.WHITE)
	draw_string(_fonte_t, Vector2(0, 134), "X", HORIZONTAL_ALIGNMENT_CENTER, LARGURA, 18, Color.WHITE)
	if int(_t * 2.0) % 2 == 0:
		draw_string(_fonte_m, Vector2(0, 190), "PRESS START", HORIZONTAL_ALIGNMENT_CENTER, LARGURA, 14, Color.WHITE)


## A vinheta de transmissao antes do jogo: os dois escudos e o horario.
func _desenhar_abertura_tv() -> void:
	draw_rect(Rect2(0, 0, LARGURA, ALTURA), Color(0.02, 0.10, 0.05))
	for i in 12:
		var y := float(i) * 20.0
		draw_rect(Rect2(0, y, LARGURA, 10), Color(0.04, 0.16, 0.08))
	var a: Array = TIMES[_times[0]]
	var b: Array = TIMES[_times[1]]
	draw_string(_fonte_m, Vector2(0, 58), "BRASILEIRAO", HORIZONTAL_ALIGNMENT_CENTER, LARGURA, 14, Color(1.0, 0.85, 0.2))
	for lado in 2:
		var t: Array = a if lado == 0 else b
		var cx := 90.0 if lado == 0 else 230.0
		draw_circle(Vector2(cx, 120), 30.0, t[2])
		draw_arc(Vector2(cx, 120), 30.0, 0.0, TAU, 32, t[3], 3.0)
		draw_string(_fonte_t, Vector2(cx - 30, 127), t[0], HORIZONTAL_ALIGNMENT_CENTER, 60, 18,
			t[3] if t[2].get_luminance() > 0.6 else Color.WHITE)
		draw_string(_fonte_p, Vector2(cx - 60, 170), t[1], HORIZONTAL_ALIGNMENT_CENTER, 120, 11, Color.WHITE)
	draw_string(_fonte_t, Vector2(0, 127), "X", HORIZONTAL_ALIGNMENT_CENTER, LARGURA, 18, Color.WHITE)
	_desenhar_ao_vivo()
