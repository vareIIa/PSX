## Portal: a consulta de CPF da prefeitura. E a segunda metade do registro civil
## — a primeira e a carteira que o NPC tira do bolso; esta e digitar um numero e
## receber a ficha de alguem: a mae, o endereco e quem mais mora la.
##
## Era a tela verde do aparelho de 1998; agora e um app de governo no iPhone,
## com o mesmo laco: entrar com o proprio CPF (TAB preenche o seu), consultar o
## numero anotado, abrir a ficha, ver quem mora no mesmo endereco. O teclado
## numerico aparece na tela quando o campo esta em foco, e o mouse digita nele;
## o teclado do computador digita direto.
class_name AppPortal
extends AppIos

enum Tela { LOGIN, MENU, CONSULTA, FICHA, VINCULOS }

const VERDE := Color("1f7a4a")
const VERDE_CLARO := Color("2f9e63")
const AMARELO := Color("ffd23f")
const TECLA_ALTA := 14.0
const MENU := ["Consultar CPF", "Meus dados", "Quem mora comigo", "Sair"]

var _tela: Tela = Tela.LOGIN
var _logado: bool = false
var _digitado: String = ""
var _ficha: Dictionary = {}
var _foto: ImageTexture
var _vinculos: Array[Dictionary] = []


func abrir() -> void:
	_tela = Tela.MENU if _logado else Tela.LOGIN
	_digitado = ""
	sel = 0
	rol_alvo = 0.0


func digitando() -> bool:
	return _tela == Tela.LOGIN or _tela == Tela.CONSULTA


## Publica: abre a ficha de `cpf` sem digitar (testes, capturas).
func consultar(cpf: String) -> bool:
	var id := RegistroCivil.id_de_cpf(cpf)
	if id < 0:
		return false
	_logado = true
	_mostrar_ficha(RegistroCivil.identidade(id))
	return true


func tecla(ev: InputEventKey) -> bool:
	var codigo := ev.keycode
	if digitando():
		if (codigo >= KEY_0 and codigo <= KEY_9) or (codigo >= KEY_KP_0 and codigo <= KEY_KP_9):
			_digito(str(codigo - (KEY_0 if codigo <= KEY_9 else KEY_KP_0)))
			return true
		if codigo == KEY_BACKSPACE:
			_apagar()
			return true
		if codigo == KEY_ENTER or codigo == KEY_KP_ENTER:
			_confirmar()
			return true
		if codigo == KEY_TAB and _tela == Tela.LOGIN:
			# O proprio CPF: o jogador ja tem o numero no bolso.
			var eu := RegistroCivil.jogador
			if not eu.is_empty():
				_digitado = String(eu["cpf"]).replace(".", "").replace("-", "")
				AudioDirector.tocar_ui(&"celular_tecla", -10.0)
			return true
		return false
	if _tela == Tela.FICHA:
		if codigo == KEY_V:
			_ver_vinculos(int(_ficha["id"]))
			return true
		if codigo == KEY_D:
			Documento.abrir(_ficha)
			return true
	return false


func _digito(d: String) -> void:
	if _digitado.length() >= 11:
		return
	_digitado += d
	AudioDirector.tocar_ui(&"celular_tecla", -14.0)


func _apagar() -> void:
	_digitado = _digitado.substr(0, maxi(0, _digitado.length() - 1))
	AudioDirector.tocar_ui(&"celular_tecla", -18.0)


func _confirmar() -> void:
	if _tela == Tela.LOGIN:
		var id := RegistroCivil.id_de_cpf(_digitado)
		if id < 0 or id != RegistroCivil.id_do_jogador():
			# Entrar como outra pessoa seria o fim da graca: o portal existe para o
			# jogador precisar do CPF ALHEIO para consultar.
			aviso("CPF INVALIDO" if id < 0 else "ESSE CPF NAO E SEU", Color("d0342c"))
			AudioDirector.tocar_ui(&"celular_erro", -10.0)
			return
		_logado = true
		_tela = Tela.MENU
		_digitado = ""
		sel = 0
		AudioDirector.tocar_ui(&"celular_ok", -8.0)
	elif _tela == Tela.CONSULTA:
		var id := RegistroCivil.id_de_cpf(_digitado)
		if id < 0:
			aviso("NAO ENCONTRADO", Color("d0342c"))
			AudioDirector.tocar_ui(&"celular_erro", -10.0)
			return
		AudioDirector.tocar_ui(&"celular_ok", -10.0)
		_mostrar_ficha(RegistroCivil.identidade(id))


func _mostrar_ficha(f: Dictionary) -> void:
	if f.is_empty():
		return
	_ficha = f
	_foto = Retrato.gerar_textura(f.get("aparencia", {}))
	_tela = Tela.FICHA
	sel = 0
	rol_alvo = 0.0
	# Consultar alguem poe a pessoa na agenda.
	RegistroCivil.conhecer(int(f["id"]))


func _ver_vinculos(id: int) -> void:
	_vinculos = RegistroCivil.vinculos(id)
	_tela = Tela.VINCULOS
	sel = 0
	rol_alvo = 0.0


func acao(nome: StringName) -> bool:
	match _tela:
		Tela.MENU:
			match nome:
				&"cima": sel = maxi(0, sel - 1)
				&"baixo": sel = mini(MENU.size() - 1, sel + 1)
				&"ok": _menu(sel)
				&"voltar": return false
		Tela.LOGIN, Tela.CONSULTA:
			match nome:
				&"ok": _confirmar()
				&"voltar":
					if _tela == Tela.LOGIN:
						return false
					_tela = Tela.MENU
					sel = 0
		Tela.FICHA:
			match nome:
				&"cima": sel = maxi(0, sel - 1)
				&"baixo": sel = mini(1, sel + 1)
				&"ok":
					if sel == 0:
						_ver_vinculos(int(_ficha["id"]))
					else:
						Documento.abrir(_ficha)
				&"voltar":
					_tela = Tela.MENU if _logado else Tela.LOGIN
					sel = 0
		Tela.VINCULOS:
			match nome:
				&"cima": sel = maxi(0, sel - 1)
				&"baixo": sel = mini(maxi(0, _vinculos.size() - 1), sel + 1)
				&"ok":
					if not _vinculos.is_empty():
						_mostrar_ficha(RegistroCivil.identidade(int(_vinculos[sel]["id"])))
				&"voltar":
					if _ficha.is_empty():
						_tela = Tela.MENU
					else:
						_tela = Tela.FICHA
					sel = 0
	return true


func _menu(i: int) -> void:
	match i:
		0:
			_tela = Tela.CONSULTA
			_digitado = ""
		1:
			_mostrar_ficha(RegistroCivil.jogador)
		2:
			_ficha = {}
			_ver_vinculos(RegistroCivil.id_do_jogador())
		3:
			_logado = false
			_tela = Tela.LOGIN
			_digitado = ""
	AudioDirector.tocar_ui(&"clique", -18.0)


func tocar(id: Variant) -> bool:
	if super.tocar(id):
		return true
	if not (id is Array):
		return false
	var a: Array = id
	match a[0]:
		&"tecla":
			var k := String(a[1])
			if k == "<":
				_apagar()
			elif k == "ok":
				_confirmar()
			else:
				_digito(k)
		&"menu":
			sel = int(a[1])
			_menu(sel)
		&"ficha":
			sel = int(a[1])
			acao(&"ok")
		&"vinculo":
			sel = int(a[1])
			acao(&"ok")
		&"meu_cpf":
			var ev := InputEventKey.new()
			ev.keycode = KEY_TAB
			tecla(ev)
	return true


# --- desenho ------------------------------------------------------------------

func desenhar(visor: Control) -> void:
	v = visor
	ret(Rect2(0.0, 0.0, L, alto_tela), Color("eef1ee"))
	match _tela:
		Tela.LOGIN:
			_cabecalho()
			_campo("Entre com o seu CPF", TOPO + 58.0)
			_link_meu_cpf(TOPO + 88.0)
			_teclado()
		Tela.MENU:
			_cabecalho()
			_menu_desenho()
		Tela.CONSULTA:
			_cabecalho()
			_campo("CPF de quem voce procura", TOPO + 58.0)
			t(Vector2(8.0, TOPO + 92.0), "O numero esta na carteira de", 6, FRACA)
			t(Vector2(8.0, TOPO + 100.0), "quem voce encontrar na rua.", 6, FRACA)
			_teclado()
		Tela.FICHA:
			_ficha_desenho()
		Tela.VINCULOS:
			_vinculos_desenho()
	match _tela:
		Tela.LOGIN, Tela.MENU:
			nav("Portal", "Inicio")
		Tela.CONSULTA:
			nav("Consulta", "Portal")
		Tela.FICHA:
			nav("Ficha", "Portal")
		Tela.VINCULOS:
			nav("Mesmo endereco", "Ficha" if not _ficha.is_empty() else "Portal")
	desenhar_aviso()


## A faixa verde e amarela do governo, com o brasao.
func _cabecalho() -> void:
	var r := Rect2(0.0, TOPO + NAV, L, 30.0)
	grad_v(r, VERDE_CLARO, VERDE)
	ret(Rect2(0.0, r.end.y, L, 2.0), AMARELO)
	var c := Vector2(20.0, r.get_center().y)
	v.draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -9.0), c + Vector2(8.0, -5.0),
		c + Vector2(6.5, 5.0), c + Vector2(0.0, 9.0), c + Vector2(-6.5, 5.0), c + Vector2(-8.0, -5.0)]),
		Color(1, 1, 1, 0.92))
	v.draw_circle(c, 3.6, Color("2a64b8"))
	t(Vector2(33.0, r.position.y + 13.0), "PORTAL DO CIDADAO", 7, Color.WHITE, f_bold)
	t(Vector2(33.0, r.position.y + 22.0), "Prefeitura Municipal", 5, Color(1, 1, 1, 0.85), f_semi)
	if _logado:
		var eu := RegistroCivil.jogador
		t(Vector2(33.0, r.position.y + 28.5), "Conectado: " + String(eu.get("primeiro", "?")).capitalize(),
			4, Color(1, 1, 1, 0.8), f_semi)


func _campo(etiqueta: String, y: float) -> void:
	t(Vector2(8.0, y - 4.0), etiqueta, 6, FRACA, f_semi)
	var r := Rect2(6.0, y, L - 12.0, 17.0)
	arred(r, 3.0, Color.WHITE)
	arred(r, 3.0, VERDE_CLARO, false, 0.8)
	var mostrado := _formatar_cpf(_digitado)
	var cursor := "|" if fmod(piscar, 0.9) < 0.5 and _digitado.length() < 11 else ""
	if mostrado.is_empty() and cursor.is_empty():
		t(r.position + Vector2(6.0, 11.5), "000.000.000-00", 9, Color("c3c9c4"), f_semi)
	t(r.position + Vector2(6.0, 11.5), mostrado + cursor, 9, TINTA, f_semi)


func _link_meu_cpf(y: float) -> void:
	var r := Rect2(6.0, y, L - 12.0, 12.0)
	t(Vector2(0.0, y + 8.0), "Usar o meu CPF (TAB)", 6, AZUL if not sob_dedo(r) else AZUL.darkened(0.3),
		f_semi, L, HORIZONTAL_ALIGNMENT_CENTER)
	alvo(r, [&"meu_cpf"])


static func _formatar_cpf(digitos: String) -> String:
	var s := ""
	for i in digitos.length():
		if i == 3 or i == 6:
			s += "."
		elif i == 9:
			s += "-"
		s += digitos[i]
	return s


## O teclado numerico do iOS: tres colunas, cinza-azulado, com o apagar.
func _teclado() -> void:
	var teclas := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "ok", "0", "<"]
	var alto := TECLA_ALTA * 4.0 + 1.5 * 3.0 + 3.0
	var y0 := alto_tela - alto
	grad_v(Rect2(0.0, y0, L, alto), Color("5e6a7c"), Color("3c4656"))
	var larg := (L - 4.0 * 1.5) / 3.0
	for i in teclas.size():
		var col := i % 3
		var lin := i / 3
		var r := Rect2(1.5 + float(col) * (larg + 1.5), y0 + 1.5 + float(lin) * (TECLA_ALTA + 1.5),
			larg, TECLA_ALTA)
		var k := String(teclas[i])
		var especial := k == "ok" or k == "<"
		var cima := Color("f4f5f7") if not especial else Color("a9b2c0")
		var baixo := Color("d4d8de") if not especial else Color("8893a3")
		if sob_dedo(r):
			cima = cima.darkened(0.25)
			baixo = baixo.darkened(0.25)
		if k == "ok":
			cima = Color("4ea3f5") if _digitado.length() == 11 else cima
			baixo = Color("1f6fd0") if _digitado.length() == 11 else baixo
		var pts := AppCelular.cantos(r, 2.0)
		var cores := PackedColorArray()
		for p: Vector2 in pts:
			cores.append(cima.lerp(baixo, (p.y - r.position.y) / r.size.y))
		v.draw_polygon(pts, cores)
		arred(Rect2(r.position + Vector2(0.0, 0.6), r.size), 2.0, Color(0, 0, 0, 0.35), false, 0.5)
		var rotulo := "OK" if k == "ok" else ("←" if k == "<" else k)
		var cor := Color.WHITE if k == "ok" and _digitado.length() == 11 else TINTA
		t(Vector2(r.position.x, r.position.y + 10.5), rotulo, 9 if not especial else 7, cor,
			f_semi, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		alvo(r, [&"tecla", k])


func _menu_desenho() -> void:
	var y := TOPO + NAV + 42.0
	var eu := RegistroCivil.jogador
	t(Vector2(8.0, y - 4.0), "SERVICOS", 5, Color("4c566a"), f_semi)
	for i in MENU.size():
		linha_de_grupo(Rect2(6.0, y + float(i) * 19.0, L - 12.0, 19.0), i, MENU.size(), MENU[i], "",
			i < 3, [&"menu", i])
	y += float(MENU.size()) * 19.0 + 10.0
	if not eu.is_empty():
		t(Vector2(0.0, y + 6.0), "CPF " + String(eu.get("cpf", "")), 6, FRACA, f_semi, L,
			HORIZONTAL_ALIGNMENT_CENTER)


func _ficha_desenho() -> void:
	if _ficha.is_empty():
		return
	var f := _ficha
	var y := TOPO + NAV + 6.0
	var cartao := Rect2(6.0, y, L - 12.0, 64.0)
	arred(Rect2(cartao.position + Vector2(0.0, 1.0), cartao.size), 4.0, Color(0, 0, 0, 0.15))
	arred(cartao, 4.0, Color.WHITE)
	ret(Rect2(cartao.position.x, cartao.position.y, cartao.size.x, 3.0), VERDE_CLARO)
	var foto := Rect2(cartao.position + Vector2(5.0, 7.0), Vector2(40.0, 52.0))
	ret(foto, Color("dde3de"))
	if _foto != null:
		v.draw_texture_rect(_foto, foto, false)
	var x := foto.end.x + 6.0
	var larg := cartao.end.x - x - 4.0
	v.draw_multiline_string(f_bold, Vector2(x, y + 14.0), String(f["nome"]).capitalize(),
		HORIZONTAL_ALIGNMENT_LEFT, larg, 7, 2, TINTA)
	t(Vector2(x, y + 33.0), String(f["cpf"]), 7, TINTA, f_semi)
	var situacao := int(f["situacao"])
	var regular := situacao == RegistroCivil.Situacao.REGULAR
	chip(Vector2(x, y + 44.0), RegistroCivil.nome_da_situacao(situacao),
		Color("d7f0e2") if regular else Color("fbe0dc"), VERDE if regular else Color("c0392b"), 5)
	t(Vector2(x, y + 56.0), "Nasc. %s  ·  %s" % [String(f["nascimento"]),
		"M" if StringName(f["sexo"]) == &"M" else "F"], 5, FRACA, f_semi)
	y = cartao.end.y + 6.0
	var campos := [["Profissao", String(f["profissao"]).capitalize()], ["Mae", String(f["mae"]).capitalize()],
		["Endereco", String(f["endereco"])]]
	for par: Array in campos:
		t(Vector2(8.0, y + 6.0), String(par[0]).to_upper(), 5, Color("4c566a"), f_semi)
		v.draw_multiline_string(f_reg, Vector2(8.0, y + 14.0), String(par[1]), HORIZONTAL_ALIGNMENT_LEFT,
			L - 16.0, 6, 2, TINTA)
		y += 22.0 if w(String(par[1]), 6) < L - 16.0 else 29.0
	y += 2.0
	linha_de_grupo(Rect2(6.0, y, L - 12.0, 17.0), 0, 2, "Quem mora junto", "", true, [&"ficha", 0])
	linha_de_grupo(Rect2(6.0, y + 17.0, L - 12.0, 17.0), 1, 2, "Ver carteira (D)", "", true, [&"ficha", 1])


func _vinculos_desenho() -> void:
	var y0 := TOPO + NAV + 6.0
	if _vinculos.is_empty():
		t(Vector2(0.0, y0 + 40.0), "Ninguem mais neste endereco.", 6, FRACA, f_semi, L,
			HORIZONTAL_ALIGNMENT_CENTER)
		return
	var linha := 22.0
	var alto := alto_tela - y0 - 4.0
	if foco_visivel:
		seguir(float(sel) * linha, linha, alto, float(_vinculos.size()) * linha)
	var y := y0 - rol
	for i in _vinculos.size():
		var vv := _vinculos[i]
		var r := Rect2(6.0, y + float(i) * linha, L - 12.0, linha)
		if r.end.y < y0 or r.position.y > alto_tela:
			continue
		var marcada := (foco_visivel and sel == i) or sob_dedo(r)
		celula(r, i == 0, i == _vinculos.size() - 1, marcada)
		var morto := int(vv["situacao"]) == RegistroCivil.Situacao.FALECIDO
		var nome := String(vv["nome"]).capitalize()
		avatar(r.position + Vector2(10.0, linha * 0.5), 6.5, nome, AppCelular.cor_de(int(vv["id"])))
		t(Vector2(r.position.x + 20.0, r.position.y + 9.5), cortar(nome, 7, r.size.x - 34.0, f_bold), 7,
			Color.WHITE if marcada else (Color("c0392b") if morto else TINTA), f_bold)
		t(Vector2(r.position.x + 20.0, r.position.y + 17.5), "%s, %d anos%s" % [String(vv["relacao"]).capitalize(),
			int(vv["idade"]), "  ·  falecido" if morto else ""], 5,
			Color(1, 1, 1, 0.85) if marcada else FRACA, f_semi)
		seta(Vector2(r.end.x - 6.0, r.get_center().y), Color.WHITE if marcada else Color("8e949c"))
		alvo(r, [&"vinculo", i])
