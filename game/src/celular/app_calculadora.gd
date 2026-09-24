## Calculadora, no desenho da do iOS 4: o visor claro de LCD em cima, as teclas
## pretas de vidro, as operacoes cinza e o igual laranja.
##
## Conta de verdade, com os numeros do teclado do computador (e + - * / Enter),
## com o mouse nas teclas e com o controle andando pela grade.
class_name AppCalculadora
extends AppCelular

const TECLAS := [["mc", "m+", "m-", "mr"], ["C", "±", "÷", "×"], ["7", "8", "9", "−"],
	["4", "5", "6", "+"], ["1", "2", "3", "="], ["0", "0", ".", "="]]

var _visor: String = "0"
var _acumulado: float = 0.0
var _operacao: String = ""
var _novo: bool = true
var _memoria: float = 0.0
var _foco := Vector2i(0, 2)
var _apertada: String = ""
var _apertada_t: float = 0.0


func processar(delta: float) -> void:
	super.processar(delta)
	_apertada_t = maxf(0.0, _apertada_t - delta)


func tecla(ev: InputEventKey) -> bool:
	var c := char(ev.unicode) if ev.unicode > 0 else ""
	match ev.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			_apertar("=")
			return true
		KEY_BACKSPACE:
			if not _novo and _visor.length() > 1:
				_visor = _visor.substr(0, _visor.length() - 1)
			else:
				_visor = "0"
				_novo = true
			return true
	var mapa := {"+": "+", "-": "−", "*": "×", "x": "×", "/": "÷", ",": ".", ".": ".", "=": "="}
	if c >= "0" and c <= "9":
		_apertar(c)
		return true
	if mapa.has(c):
		_apertar(String(mapa[c]))
		return true
	return false


func acao(nome: StringName) -> bool:
	match nome:
		&"cima": _foco.y = maxi(0, _foco.y - 1)
		&"baixo": _foco.y = mini(TECLAS.size() - 1, _foco.y + 1)
		&"esq": _foco.x = maxi(0, _foco.x - 1)
		&"dir": _foco.x = mini(3, _foco.x + 1)
		&"ok": _apertar(String(TECLAS[_foco.y][_foco.x]))
		&"voltar": return false
	return true


func tocar(id: Variant) -> bool:
	if id is String:
		_apertar(id)
		return true
	return false


func _numero() -> float:
	return _visor.to_float()


func _mostrar(x: float) -> void:
	if is_inf(x) or is_nan(x):
		_visor = "Erro"
		return
	if absf(x - roundf(x)) < 1e-9 and absf(x) < 1e12:
		_visor = str(int(roundf(x)))
	else:
		_visor = ("%.8f" % x).rstrip("0").rstrip(".")
	if _visor.length() > 12:
		_visor = "%.6e" % x


func _apertar(k: String) -> void:
	_apertada = k
	_apertada_t = 0.12
	AudioDirector.tocar_ui(&"celular_tecla", -16.0)
	if k >= "0" and k <= "9":
		if _novo or _visor == "0" or _visor == "Erro":
			_visor = k
			_novo = false
		elif _visor.length() < 12:
			_visor += k
		return
	match k:
		".":
			if _novo:
				_visor = "0."
				_novo = false
			elif not _visor.contains("."):
				_visor += "."
		"C":
			_visor = "0"
			_acumulado = 0.0
			_operacao = ""
			_novo = true
		"±":
			_mostrar(-_numero())
		"+", "−", "×", "÷":
			if not _operacao.is_empty() and not _novo:
				_mostrar(_conta(_acumulado, _numero(), _operacao))
			_acumulado = _numero()
			_operacao = k
			_novo = true
		"=":
			if not _operacao.is_empty():
				_mostrar(_conta(_acumulado, _numero(), _operacao))
				_operacao = ""
				_novo = true
		"mc": _memoria = 0.0
		"m+": _memoria += _numero()
		"m-": _memoria -= _numero()
		"mr":
			_mostrar(_memoria)
			_novo = true


static func _conta(a: float, b: float, op: String) -> float:
	match op:
		"+": return a + b
		"−": return a - b
		"×": return a * b
		"÷": return a / b if b != 0.0 else INF
	return b


func desenhar(visor: Control) -> void:
	v = visor
	grad_v(Rect2(0.0, 0.0, L, alto_tela), Color("3a3e44"), Color("15171a"))
	# O visor de LCD: cinza-esverdeado claro com o brilho de vidro em cima.
	var d := Rect2(6.0, TOPO + 8.0, L - 12.0, 36.0)
	grad_v(d, Color("dfe6d8"), Color("b9c4b0"))
	arred(d, 2.0, Color(0, 0, 0, 0.5), false, 0.6)
	ret(Rect2(d.position.x, d.position.y, d.size.x, d.size.y * 0.4), Color(1, 1, 1, 0.18))
	if absf(_memoria) > 0.0:
		t(d.position + Vector2(4.0, 9.0), "M", 5, Color("2c3326"), f_bold)
	if not _operacao.is_empty():
		t(d.position + Vector2(4.0, 30.0), _operacao, 6, Color("2c3326"), f_bold)
	var tam := 20 if _visor.length() <= 8 else 14
	t(Vector2(d.position.x, d.end.y - 8.0), _visor, tam, Color("1f251a"), f_reg, d.size.x - 6.0,
		HORIZONTAL_ALIGNMENT_RIGHT)
	var y0 := d.end.y + 8.0
	var alto := (alto_tela - y0 - 6.0) / float(TECLAS.size())
	var larg := (L - 12.0) / 4.0
	for lin in TECLAS.size():
		for col in 4:
			var k := String(TECLAS[lin][col])
			# O zero ocupa duas casas, o igual duas fileiras: desenha so a primeira.
			if lin == 5 and col == 1:
				continue
			if lin == 5 and col == 3:
				continue
			var r := Rect2(6.0 + float(col) * larg, y0 + float(lin) * alto, larg, alto).grow(-1.2)
			if k == "0" and col == 0:
				r.size.x = larg * 2.0 - 2.4
			if k == "=" and lin == 4:
				r.size.y = alto * 2.0 - 2.4
			var cima := Color("56595f")
			var baixo := Color("25272b")
			var tinta := Color.WHITE
			if col == 3 or lin <= 1:
				cima = Color("a9adb3")
				baixo = Color("6e737a")
				tinta = Color("1c1e21")
			if k == "=":
				cima = Color("ffb04a")
				baixo = Color("e0660f")
				tinta = Color.WHITE
			var focada := foco_visivel and ((_foco == Vector2i(col, lin)) or (lin == 5 and _foco.y == 5
				and ((k == "0" and _foco.x <= 1))) or (k == "=" and _foco.x == 3 and _foco.y >= 4))
			if sob_dedo(r) or (_apertada == k and _apertada_t > 0.0):
				cima = cima.darkened(0.3)
				baixo = baixo.darkened(0.3)
			var pts := AppCelular.cantos(r, 3.0)
			var cores := PackedColorArray()
			for p: Vector2 in pts:
				cores.append(cima.lerp(baixo, (p.y - r.position.y) / r.size.y))
			v.draw_polygon(pts, cores)
			arred(r, 3.0, Color(0, 0, 0, 0.6), false, 0.5)
			arred(Rect2(r.position.x + 1.0, r.position.y + 0.8, r.size.x - 2.0, r.size.y * 0.45), 2.5,
				Color(1, 1, 1, 0.12))
			if focada:
				arred(r.grow(1.0), 3.5, Color(1, 1, 1, 0.8), false, 0.8)
			var tt := 9 if k.length() == 1 else 6
			t(Vector2(r.position.x, r.get_center().y + float(tt) * 0.36), k, tt, tinta, f_semi, r.size.x,
				HORIZONTAL_ALIGNMENT_CENTER)
			alvo(r, k)
