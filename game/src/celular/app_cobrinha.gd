## Cobrinha: o jogo do celular de todo mundo, de verdade.
##
## A cobra anda sozinha numa grade de LCD verde; as setas (ou WASD, o direcional,
## o analogico, ou arrastar o dedo) mudam a direcao. Cada fruta cresce a cobra e
## acelera um nada. Bater na parede ou no proprio rabo acaba a partida; o
## recorde fica no aparelho, e bater o recorde faz o telefone vibrar na mao.
class_name AppCobrinha
extends AppCelular

const COLS := 17
const LINS := 22
const CELULA := 7.6
const VELOCIDADE_INICIO := 6.5
const VELOCIDADE_MAX := 14.0
const LCD := Color("9bbc5a")
const LCD_ESCURO := Color("8aab4c")
const PIXEL := Color("1d2b0e")
const CHAVE := &"cobrinha_recorde"

enum Estado { MENU, JOGANDO, PAUSA, FIM }

var _estado: Estado = Estado.MENU
var _cobra: Array[Vector2i] = []
var _dir := Vector2i.RIGHT
var _fila: Array[Vector2i] = []
var _fruta := Vector2i.ZERO
var _pontos: int = 0
var _passo: float = 0.0
var _rng := RandomNumberGenerator.new()
var _bateu_recorde: bool = false


func abrir() -> void:
	if _estado == Estado.JOGANDO:
		_estado = Estado.PAUSA


static func recorde() -> int:
	return int(WorldState.obter(Celular.COORD, CHAVE, 0))


func _comecar() -> void:
	_rng.randomize()
	_cobra = [Vector2i(6, 11), Vector2i(5, 11), Vector2i(4, 11)]
	_dir = Vector2i.RIGHT
	_fila.clear()
	_pontos = 0
	_passo = 0.0
	_bateu_recorde = false
	_nova_fruta()
	_estado = Estado.JOGANDO
	AudioDirector.tocar_ui(&"celular_ok", -12.0)


func _nova_fruta() -> void:
	for tentativa in 200:
		var p := Vector2i(_rng.randi_range(0, COLS - 1), _rng.randi_range(0, LINS - 1))
		if not _cobra.has(p):
			_fruta = p
			return


func _virar(d: Vector2i) -> void:
	var ultima := _fila[_fila.size() - 1] if not _fila.is_empty() else _dir
	if d == -ultima or d == ultima or _fila.size() >= 3:
		return
	_fila.append(d)


func processar(delta: float) -> void:
	super.processar(delta)
	if _estado != Estado.JOGANDO:
		return
	var vel := minf(VELOCIDADE_MAX, VELOCIDADE_INICIO + float(_pontos) * 0.35)
	_passo += delta * vel
	while _passo >= 1.0 and _estado == Estado.JOGANDO:
		_passo -= 1.0
		_andar()


func _andar() -> void:
	if not _fila.is_empty():
		_dir = _fila.pop_front()
	var cabeca := _cobra[0] + _dir
	var fora := cabeca.x < 0 or cabeca.y < 0 or cabeca.x >= COLS or cabeca.y >= LINS
	if fora or _cobra.slice(0, _cobra.size() - 1).has(cabeca):
		_morrer()
		return
	_cobra.push_front(cabeca)
	if cabeca == _fruta:
		_pontos += 1
		AudioDirector.tocar_ui(&"celular_tecla", -10.0, 1.3)
		if _pontos > recorde():
			if not _bateu_recorde and recorde() > 0:
				Celular.vibrar(0.35)
			_bateu_recorde = true
			WorldState.definir(Celular.COORD, CHAVE, _pontos)
		_nova_fruta()
	else:
		_cobra.pop_back()


func _morrer() -> void:
	_estado = Estado.FIM
	AudioDirector.tocar_ui(&"celular_erro", -8.0)
	Celular.vibrar(0.25)


func acao(nome: StringName) -> bool:
	match _estado:
		Estado.JOGANDO:
			match nome:
				&"cima": _virar(Vector2i.UP)
				&"baixo": _virar(Vector2i.DOWN)
				&"esq": _virar(Vector2i.LEFT)
				&"dir": _virar(Vector2i.RIGHT)
				&"ok": _estado = Estado.PAUSA
				&"voltar": _estado = Estado.PAUSA
			return true
		Estado.PAUSA:
			if nome == &"ok":
				_estado = Estado.JOGANDO
				return true
			if nome == &"voltar":
				_estado = Estado.MENU
				return true
			return true
		_:
			if nome == &"ok":
				_comecar()
				return true
			return nome != &"voltar"


func toque(p: Vector2) -> bool:
	if _estado != Estado.JOGANDO:
		acao(&"ok")
		return true
	return false


func arrastar(_desde: Vector2, delta: Vector2, fim: bool) -> bool:
	if _estado != Estado.JOGANDO or fim or delta.length() < 1.2:
		return true
	if absf(delta.x) > absf(delta.y):
		_virar(Vector2i.RIGHT if delta.x > 0.0 else Vector2i.LEFT)
	else:
		_virar(Vector2i.DOWN if delta.y > 0.0 else Vector2i.UP)
	return true


func rolar(_passos: float) -> bool:
	return true


func desenhar(visor: Control) -> void:
	v = visor
	grad_v(Rect2(0.0, 0.0, L, alto_tela), Color("2b3a1c"), Color("0f160a"))
	var campo := Rect2((L - COLS * CELULA) * 0.5, TOPO + 18.0, COLS * CELULA, LINS * CELULA)
	# A moldura do LCD.
	arred(campo.grow(3.0), 3.0, Color("1a2410"))
	ret(campo, LCD)
	# A grade de pixels apagados do LCD: e o que diz "tela de telefone velho".
	for y in LINS:
		for x in COLS:
			ret(Rect2(campo.position + Vector2(x, y) * CELULA + Vector2(0.6, 0.6),
				Vector2(CELULA - 1.2, CELULA - 1.2)), LCD_ESCURO)
	t(Vector2(6.0, TOPO + 12.0), "%04d" % _pontos, 9, Color("c8e59a"), f_bold)
	t(Vector2(0.0, TOPO + 12.0), "RECORDE %04d" % recorde(), 6, Color("8fb262"), f_semi, L - 6.0,
		HORIZONTAL_ALIGNMENT_RIGHT)
	if _estado != Estado.MENU:
		for i in _cobra.size():
			var q := _cobra[i]
			var r := Rect2(campo.position + Vector2(q) * CELULA + Vector2(0.4, 0.4),
				Vector2(CELULA - 0.8, CELULA - 0.8))
			ret(r, PIXEL)
			if i == 0:
				# O olho, para a cobra ter frente.
				var olho := r.get_center() + Vector2(_dir) * 1.6 + Vector2(-_dir.y, _dir.x) * 1.4
				ret(Rect2(olho - Vector2(0.7, 0.7), Vector2(1.4, 1.4)), LCD)
		var f := campo.position + Vector2(_fruta) * CELULA + Vector2(CELULA, CELULA) * 0.5
		var pulsa := 1.0 + 0.15 * sin(piscar * 10.0)
		v.draw_circle(f, CELULA * 0.36 * pulsa, PIXEL)
		ret(Rect2(f + Vector2(-0.3, -CELULA * 0.55), Vector2(0.9, 1.6)), PIXEL)
	var msg := ""
	var sub := ""
	match _estado:
		Estado.MENU:
			msg = "COBRINHA"
			sub = "toque ou E para jogar"
		Estado.PAUSA:
			msg = "PAUSA"
			sub = "E continua, ESC sai"
		Estado.FIM:
			msg = "FIM DE JOGO"
			sub = ("NOVO RECORDE! " if _bateu_recorde else "") + "%d pontos" % _pontos
	if not msg.is_empty():
		var caixa := Rect2(campo.position.x + 10.0, campo.get_center().y - 18.0, campo.size.x - 20.0, 36.0)
		ret(caixa, Color(LCD, 0.92))
		v.draw_rect(caixa, PIXEL, false, 1.0)
		t(Vector2(caixa.position.x, caixa.position.y + 15.0), msg, 10, PIXEL, f_bold, caixa.size.x,
			HORIZONTAL_ALIGNMENT_CENTER)
		t(Vector2(caixa.position.x, caixa.position.y + 27.0), sub, 6, PIXEL, f_semi, caixa.size.x,
			HORIZONTAL_ALIGNMENT_CENTER)
	t(Vector2(0.0, alto_tela - 4.0), "setas / arrastar", 5, Color(0.8, 0.9, 0.6, 0.4), f_semi, L,
		HORIZONTAL_ALIGNMENT_CENTER)
