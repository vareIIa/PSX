## A voz de um NPC: silabas sem palavra nenhuma, na altura daquela pessoa.
##
## Por que a fala nao pode ser entendida
## -------------------------------------
## O texto ja esta na tela. Uma voz que dissesse a mesma coisa competiria com a
## leitura, precisaria de gravacao por linha — e a cidade tem linha infinita —
## e envelheceria mal na primeira frase repetida.
##
## Entao a voz nao diz: ela SOA. Oito silabas sintetizadas por banco, escolhidas
## sem ordem, com a afinacao vinda da altura e do sexo da pessoa e o ritmo vindo
## do temperamento. O ouvido reconhece corpo, idade e humor sem entender uma
## palavra, que e exatamente o efeito que o pedido descreve.
##
## Volume baixo e obrigatorio, nao gosto. Alto, a silaba vira desenho animado;
## baixa, ela passa por murmurio de gente e o cerebro completa o resto.
class_name Voz
extends AudioStreamPlayer3D

## Silabas por banco. Ver tools/gerar_audio.py.
const SILABAS := 8

## Intervalo base entre silabas, em segundos.
const INTERVALO := 0.135

## Teto de silabas por linha. Frase longa nao vira ladainha: a voz para e o
## texto continua, que e como o cerebro ja espera que legenda funcione.
const MAX_SILABAS := 7

var _banco := &"m"
var _afinacao: float = 1.0
var _cadencia: float = 1.0
var _restantes: int = 0
var _relogio: float = 0.0
var _passo: int = 0
var _total: int = 0
var _pergunta: bool = false
var _semente: int = 0
## dB a mais (grito) ou a menos (sussurro) nas silabas da `Fala`.
var volume_extra: float = 0.0


func _init() -> void:
	bus = &"SFX"
	# Curto de proposito. A conversa acontece a dois metros; alcance maior faria
	# o murmurio de uma esquina chegar na outra.
	max_distance = 14.0
	unit_size = 2.4
	attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	volume_db = -13.0
	set_process(false)


func configurar(ficha: Dictionary) -> void:
	var aparencia: Dictionary = ficha.get("aparencia", {})
	_banco = &"f" if StringName(ficha.get("sexo", &"M")) == &"F" else &"m"
	_afinacao = clampf(float(aparencia.get("voz", 1.0)), 0.62, 1.72)
	var p := Personalidade.de(int(ficha.get("personalidade", 0)))
	_afinacao = clampf(_afinacao + float(p["voz"]), 0.6, 1.8)
	_cadencia = float(p["cadencia"])
	_semente = int(ficha.get("id", 0))


## Comeca a murmurar uma linha. O numero de silabas sai do tamanho do texto, para
## uma frase curta nao soar como discurso.
func dizer(texto: String) -> void:
	if AudioDirector.silencioso():
		return
	_total = clampi(int(texto.length() / 9.0) + 1, 1, MAX_SILABAS)
	_restantes = _total
	_passo = 0
	_relogio = 0.0
	_pergunta = texto.ends_with("?")
	set_process(true)


## Uma silaba so, da vogal pedida, para quem conduz o ritmo por fora (`Fala`).
## `t` e onde a silaba cai na frase (0 a 1), para a entonacao; os bancos 1-8 sao
## a, e, o, i, u, a, e, o (`tools/gerar_audio.py`), e as duas versoes de a, e e
## o se alternam pela pessoa e pela silaba, senao a mesma vogal repetida soa
## como bipe.
func silaba(vogal: String, t: float, ultima: bool, pergunta: bool) -> void:
	if AudioDirector.silencioso():
		return
	var par := absi(_semente + int(t * 97.0)) % 2 == 0
	var indice := 1
	match vogal:
		"a":
			indice = 1 if par else 6
		"e":
			indice = 2 if par else 7
		"o":
			indice = 3 if par else 8
		"i":
			indice = 4
		_:
			indice = 5
	var s := AudioDirector.stream(StringName("voz_%s_%d" % [_banco, indice]))
	if s == null:
		return
	var curva := 1.0 + sin(t * PI) * 0.06 - t * 0.10
	if pergunta and ultima:
		curva += 0.22
	self.stream = s
	pitch_scale = clampf(_afinacao * curva, 0.5, 2.0)
	volume_db = -13.0 - (3.0 if ultima else 0.0) + volume_extra
	play()


func parar() -> void:
	_restantes = 0
	set_process(false)
	stop()


func _process(delta: float) -> void:
	if _restantes <= 0:
		set_process(false)
		return
	_relogio -= delta
	if _relogio > 0.0:
		return

	var indice := 1 + absi(_semente * 31 + _passo * 7919) % SILABAS
	var stream := AudioDirector.stream(StringName("voz_%s_%d" % [_banco, indice]))
	if stream == null:
		_restantes = 0
		return

	# Entonacao. A frase sobe no meio e desce no fim; pergunta faz o contrario na
	# ultima silaba. Sem isso a fala sai plana e vira bipe de maquina.
	var t := float(_passo) / float(maxi(1, _total - 1))
	var curva := 1.0 + sin(t * PI) * 0.06 - t * 0.10
	if _pergunta and _passo == _total - 1:
		curva += 0.22

	self.stream = stream
	pitch_scale = clampf(_afinacao * curva, 0.5, 2.0)
	# A ultima silaba sai um pouco mais baixa: e como uma frase termina.
	volume_db = -13.0 - (3.0 if _passo == _total - 1 else 0.0)
	play()

	_passo += 1
	_restantes -= 1
	_relogio = INTERVALO / _cadencia * (0.86 + 0.28 * float(absi(
		_semente + _passo * 13) % 5) * 0.25)
