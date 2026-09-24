## Mensagens: as conversas do aparelho, no iOS 4.
##
## A lista de conversas e cada uma com os baloes. O jogador escreve pelo teclado
## do computador e manda — e a mensagem fica "Nao Entregue", vermelha, como a da
## estrada: a rede da cidade caiu e nao voltou. O que ele manda fica guardado no
## aparelho.
##
## O desenho dos baloes e deste arquivo, e nao o `AppMensagens` da abertura: a
## cena da estrada e trabalhada por outra frente e muda com ela.
class_name AppConversas
extends AppIos

const FUNDO := Color("dbe2ec")
const BALAO_DELES := Color("f4f4f6")
const BALAO_MEU_CIMA := Color("78b8ff")
const BALAO_MEU_BAIXO := Color("1b78e8")
const CHAVE := &"sms"
## As conversas de fabrica: quem escreveu, o nome da conversa e as mensagens.
const CONVERSAS := [
	{"nome": "Viagem", "msgs": [["Lucas", "Chegamos!! Frio do cão"], ["Mari", "Cadê vc??"],
		["Lucas", "vc vem mesmo né?"]], "hora": "Ontem"},
	{"nome": "Mãe", "msgs": [["Mãe", "Filho, me liga quando puder."], ["Mãe", "Tá tudo bem?"],
		["Mãe", "Deixei comida na geladeira."]], "hora": "Qua"},
	{"nome": "REDE", "msgs": [["REDE", "REDE informa: instabilidade na sua regiao. Estamos trabalhando para normalizar o servico."]],
		"hora": "Ter"},
]

var _aberta: int = -1
var _texto: String = ""


func abrir() -> void:
	_aberta = -1
	sel = 0
	_texto = ""


func digitando() -> bool:
	return _aberta >= 0


func _minhas(i: int) -> Array:
	var todas: Dictionary = WorldState.obter(Celular.COORD, CHAVE, {})
	return todas.get(str(i), [])


func _mandar() -> void:
	var texto := _texto.strip_edges()
	if texto.is_empty() or _aberta < 0:
		return
	var todas: Dictionary = (WorldState.obter(Celular.COORD, CHAVE, {}) as Dictionary).duplicate(true)
	var lista: Array = todas.get(str(_aberta), [])
	lista.append(texto)
	todas[str(_aberta)] = lista
	WorldState.definir(Celular.COORD, CHAVE, todas)
	_texto = ""
	AudioDirector.tocar_ui(&"celular_ok", -12.0, 1.2)
	aviso("Nao Entregue", Color("d0342c"))


func tecla(ev: InputEventKey) -> bool:
	if _aberta < 0:
		return false
	if ev.keycode == KEY_BACKSPACE:
		_texto = _texto.substr(0, maxi(0, _texto.length() - 1))
		AudioDirector.tocar_ui(&"celular_tecla", -19.0)
		return true
	if ev.keycode == KEY_ENTER or ev.keycode == KEY_KP_ENTER:
		_mandar()
		return true
	if ev.keycode == KEY_ESCAPE:
		return false
	if ev.unicode >= 32 and _texto.length() < 80:
		_texto += char(ev.unicode)
		AudioDirector.tocar_ui(&"celular_tecla", -19.0)
		return true
	return false


func acao(nome: StringName) -> bool:
	if _aberta >= 0:
		match nome:
			&"voltar":
				sel = _aberta
				_aberta = -1
			&"ok":
				_mandar()
		return true
	match nome:
		&"cima": sel = maxi(0, sel - 1)
		&"baixo": sel = mini(CONVERSAS.size() - 1, sel + 1)
		&"ok":
			_aberta = sel
			_texto = ""
		&"voltar":
			return false
	return true


func tocar(id: Variant) -> bool:
	if super.tocar(id):
		return true
	if id is Array:
		var a: Array = id
		if a[0] == &"conversa":
			sel = int(a[1])
			_aberta = sel
		elif a[0] == &"enviar":
			_mandar()
		return true
	return false


func desenhar(visor: Control) -> void:
	v = visor
	if _aberta < 0:
		ret(Rect2(0.0, 0.0, L, alto_tela), Color.WHITE)
		_lista()
		nav("Mensagens", "", "Editar")
	else:
		ret(Rect2(0.0, 0.0, L, alto_tela), FUNDO)
		_conversa(CONVERSAS[_aberta])
		nav(String(CONVERSAS[_aberta]["nome"]), "Mensagens")
	desenhar_aviso()


func _lista() -> void:
	var y := TOPO + NAV
	for i in CONVERSAS.size():
		var c: Dictionary = CONVERSAS[i]
		var r := Rect2(0.0, y + float(i) * 30.0, L, 30.0)
		var marcada := (foco_visivel and sel == i) or sob_dedo(r)
		if marcada:
			grad_v(r, Color("058cf5"), Color("015de6"))
		var msgs: Array = c["msgs"]
		var ultima := String((msgs[msgs.size() - 1] as Array)[1])
		var minhas := _minhas(i)
		if not minhas.is_empty():
			ultima = String(minhas[minhas.size() - 1])
		var nao_lida := minhas.is_empty() and i < 2
		if nao_lida:
			v.draw_circle(Vector2(5.0, r.position.y + 9.0), 2.2, Color("2a7fe6") if not marcada else Color.WHITE)
		t(Vector2(10.0, r.position.y + 10.0), String(c["nome"]), 7, Color.WHITE if marcada else TINTA, f_bold)
		t(Vector2(0.0, r.position.y + 10.0), String(c["hora"]), 5,
			Color.WHITE if marcada else AZUL_IOS, f_semi, L - 12.0, HORIZONTAL_ALIGNMENT_RIGHT)
		seta(Vector2(L - 5.0, r.position.y + 8.5), Color.WHITE if marcada else Color("8e949c"))
		v.draw_multiline_string(f_reg, Vector2(10.0, r.position.y + 18.0), ultima,
			HORIZONTAL_ALIGNMENT_LEFT, L - 20.0, 6, 2, Color(1, 1, 1, 0.85) if marcada else FRACA)
		ret(Rect2(10.0, r.end.y - 0.4, L - 10.0, 0.4), Color("e0e3e7"))
		alvo(r, [&"conversa", i])


func _conversa(c: Dictionary) -> void:
	var campo_h := 16.0
	var y_campo := alto_tela - campo_h
	var baloes: Array = []
	for m: Array in c["msgs"]:
		baloes.append([String(m[0]), String(m[1])])
	for texto: Variant in _minhas(_aberta):
		baloes.append(["eu", String(texto)])
	var y := y_campo - 4.0
	var mostrou_nota := false
	for k in range(baloes.size() - 1, -1, -1):
		var autor := String(baloes[k][0])
		var eu := autor == "eu"
		var linhas := _quebrar(String(baloes[k][1]), 6, L - 52.0)
		if eu and not mostrou_nota:
			t(Vector2(0.0, y - 1.0), "Nao Entregue", 5, Color("d0342c"), f_semi, L - 6.0,
				HORIZONTAL_ALIGNMENT_RIGHT)
			y -= 7.0
			mostrou_nota = true
		var alto := 4.5 + float(linhas.size()) * 7.2 + 3.0
		var larg := 0.0
		for l: String in linhas:
			larg = maxf(larg, w(l, 6))
		larg += 11.0
		y -= alto
		var com_nome: bool = not eu and String(c["nome"]) != autor
		if com_nome:
			y -= 6.5
		if y < TOPO + NAV + 2.0:
			break
		var x := L - 5.0 - larg if eu else 6.0
		var r := Rect2(x, y + (6.5 if com_nome else 0.0), larg, alto)
		if com_nome:
			t(Vector2(x + 5.0, y + 5.0), autor, 5, FRACA, f_semi)
		arred(Rect2(r.position + Vector2(0.0, 0.6), r.size), 5.0, Color(0, 0, 0, 0.16))
		var pts := AppCelular.cantos(r, 5.0)
		var cores := PackedColorArray()
		for p: Vector2 in pts:
			var tt := (p.y - r.position.y) / r.size.y
			cores.append(BALAO_MEU_CIMA.lerp(BALAO_MEU_BAIXO, tt) if eu else BALAO_DELES.lerp(Color("dcdce2"), tt))
		v.draw_polygon(pts, cores)
		arred(Rect2(r.position.x + 2.0, r.position.y + 1.0, r.size.x - 4.0, minf(4.0, r.size.y * 0.35)), 2.0,
			Color(1, 1, 1, 0.28 if eu else 0.6))
		for q in linhas.size():
			t(Vector2(r.position.x + 5.5, r.position.y + 8.6 + float(q) * 7.2), linhas[q], 6,
				Color.WHITE if eu else TINTA)
		y -= 3.0
	# O campo e o Enviar.
	grad_v(Rect2(0.0, y_campo, L, campo_h), Color("e9ecf1"), Color("c3c9d3"))
	ret(Rect2(0.0, y_campo, L, 0.5), Color("9aa3b0"))
	var caixa := Rect2(5.0, y_campo + 3.0, L - 40.0, campo_h - 6.0)
	arred(caixa, 4.0, Color.WHITE)
	arred(caixa, 4.0, Color("8c95a3"), false, 0.5)
	var cursor := "|" if fmod(piscar, 1.0) < 0.55 else ""
	var mostrado := _texto + cursor
	if _texto.is_empty() and cursor.is_empty():
		t(caixa.position + Vector2(4.0, 7.3), "Mensagem de Texto", 6, Color("a4abb5"))
	t(caixa.position + Vector2(4.0, 7.3), _cauda(mostrado, 6, caixa.size.x - 8.0), 6, TINTA)
	var b := Rect2(L - 32.0, y_campo + 3.0, 28.0, 10.0)
	var ativo := not _texto.strip_edges().is_empty()
	grad_v(b, Color("5aa2f7") if ativo else Color("c9ced6"), Color("2f86f5") if ativo else Color("aeb5c0"))
	arred(b, 3.0, Color("27509a") if ativo else Color("8c95a3"), false, 0.5)
	t(Vector2(b.position.x, b.position.y + 7.3), "Enviar", 5, Color.WHITE, f_bold, b.size.x,
		HORIZONTAL_ALIGNMENT_CENTER)
	alvo(b, [&"enviar"])


## O fim do texto que cabe na largura: o campo mostra o que se esta digitando.
func _cauda(texto: String, tam: int, largura: float) -> String:
	var s := texto
	while s.length() > 1 and w(s, tam) > largura:
		s = s.substr(1)
	return s


func _quebrar(texto: String, tam: int, largura: float) -> Array[String]:
	var saida: Array[String] = []
	var linha := ""
	for palavra: String in texto.split(" ", false):
		var tenta := palavra if linha.is_empty() else linha + " " + palavra
		if w(tenta, tam) <= largura or linha.is_empty():
			linha = tenta
		else:
			saida.append(linha)
			linha = palavra
	if not linha.is_empty() or saida.is_empty():
		saida.append(linha)
	return saida
