## Notas, no papel amarelo pautado do iOS 4: a lista de notas e a nota aberta.
##
## E o caderno do investigador: um CPF lido na carteira de alguem, um endereco,
## um nome. Escreve-se pelo teclado do computador; as notas ficam no aparelho
## (no WorldState, com o save).
class_name AppNotas
extends AppIos

const PAPEL := Color("fbf1a9")
const PAPEL_ESCURO := Color("f2e27d")
const PAUTA := Color(0.55, 0.62, 0.8, 0.45)
const MARGEM := Color(0.85, 0.3, 0.3, 0.5)
const TINTA_NOTA := Color("2a2419")
const COURO := Color("6b4526")
const CHAVE := &"notas"
const PASSO := 9.0

var _aberta: int = -1


static func notas() -> Array:
	return (WorldState.obter(Celular.COORD, CHAVE, []) as Array).duplicate()


static func _gravar(lista: Array) -> void:
	WorldState.definir(Celular.COORD, CHAVE, lista)


func abrir() -> void:
	_aberta = -1
	sel = 0


func digitando() -> bool:
	return _aberta >= 0


func _nova() -> void:
	var lista := notas()
	lista.push_front({"texto": "", "hora": SoFundo.hora(), "dia": SoFundo.data_por_extenso()})
	_gravar(lista)
	_aberta = 0
	AudioDirector.tocar_ui(&"clique", -14.0)


func _texto() -> String:
	var lista := notas()
	return String((lista[_aberta] as Dictionary).get("texto", "")) if _aberta < lista.size() else ""


func _escrever(texto: String) -> void:
	var lista := notas()
	if _aberta >= lista.size():
		return
	var n: Dictionary = (lista[_aberta] as Dictionary).duplicate()
	n["texto"] = texto
	n["hora"] = SoFundo.hora()
	lista[_aberta] = n
	_gravar(lista)


## Fecha a nota; vazia, ela some, como no iOS.
func _fechar_nota() -> void:
	if _aberta >= 0 and _texto().strip_edges().is_empty():
		var lista := notas()
		lista.remove_at(_aberta)
		_gravar(lista)
	sel = maxi(0, _aberta)
	_aberta = -1


func tecla(ev: InputEventKey) -> bool:
	if _aberta < 0:
		if ev.keycode == KEY_N or ev.keycode == KEY_INSERT:
			_nova()
			return true
		if ev.keycode == KEY_DELETE and not notas().is_empty():
			var lista := notas()
			lista.remove_at(clampi(sel, 0, lista.size() - 1))
			_gravar(lista)
			sel = clampi(sel, 0, maxi(0, lista.size() - 1))
			return true
		return false
	var texto := _texto()
	match ev.keycode:
		KEY_BACKSPACE:
			_escrever(texto.substr(0, maxi(0, texto.length() - 1)))
			AudioDirector.tocar_ui(&"celular_tecla", -20.0)
			return true
		KEY_ENTER, KEY_KP_ENTER:
			_escrever(texto + "\n")
			return true
		KEY_ESCAPE:
			return false
	if ev.unicode >= 32 and texto.length() < 400:
		_escrever(texto + char(ev.unicode))
		AudioDirector.tocar_ui(&"celular_tecla", -20.0)
		return true
	return false


func acao(nome: StringName) -> bool:
	if _aberta >= 0:
		if nome == &"voltar":
			_fechar_nota()
		return true
	var n := notas().size()
	match nome:
		&"cima": sel = maxi(0, sel - 1)
		&"baixo": sel = mini(n, sel + 1)
		&"ok":
			if sel >= n:
				_nova()
			else:
				_aberta = sel
		&"voltar": return false
	return true


func tocar(id: Variant) -> bool:
	if id is Array and (id as Array)[0] == &"nav_direita":
		_nova()
		return true
	if super.tocar(id):
		return true
	if id is Array and (id as Array)[0] == &"nota":
		sel = int((id as Array)[1])
		_aberta = sel
		return true
	return false


func desenhar(visor: Control) -> void:
	v = visor
	_papel()
	if _aberta < 0:
		_lista()
		nav("Notas (%d)" % notas().size(), "", "+")
	else:
		_nota()
		nav("Nota", "Notas")


## O papel: amarelo com as linhas da pauta e a margem vermelha, e a costura de
## couro em cima (o iOS 4 inteiro).
func _papel() -> void:
	grad_v(Rect2(0.0, 0.0, L, alto_tela), PAPEL, PAPEL_ESCURO)
	var y := TOPO + NAV + 14.0
	while y < alto_tela:
		ret(Rect2(0.0, y, L, 0.4), PAUTA)
		y += PASSO
	ret(Rect2(15.0, TOPO + NAV, 0.4, alto_tela), MARGEM)
	ret(Rect2(17.0, TOPO + NAV, 0.4, alto_tela), MARGEM)


func _lista() -> void:
	var lista := notas()
	var y := TOPO + NAV + 14.0
	for i in lista.size() + 1:
		var r := Rect2(0.0, y + float(i) * PASSO * 2.0 - PASSO * 2.0 + 0.4, L, PASSO * 2.0)
		if r.position.y > alto_tela:
			break
		var marcada := (foco_visivel and sel == i) or sob_dedo(r)
		if marcada:
			ret(r, Color(0.35, 0.55, 0.9, 0.22))
		if i == lista.size():
			t(Vector2(21.0, r.end.y - 5.0), "+ Nova nota", 7, Color(TINTA_NOTA, 0.55), f_semi)
			alvo(r, [&"nav_direita"])
			break
		var n: Dictionary = lista[i]
		var texto := String(n.get("texto", "")).split("\n")[0]
		t(Vector2(21.0, r.end.y - 5.0), cortar(texto if not texto.is_empty() else "Nova nota", 8,
			L - 60.0, f_reg), 8, TINTA_NOTA, f_reg)
		t(Vector2(0.0, r.end.y - 5.0), String(n.get("hora", "")), 5, Color("9a7b3a"), f_semi, L - 6.0,
			HORIZONTAL_ALIGNMENT_RIGHT)
		alvo(r, [&"nota", i])


func _nota() -> void:
	var lista := notas()
	if _aberta >= lista.size():
		return
	var n: Dictionary = lista[_aberta]
	t(Vector2(0.0, TOPO + NAV + 9.0), "%s  %s" % [String(n.get("dia", "")), String(n.get("hora", ""))], 5,
		Color("9a7b3a"), f_semi, L, HORIZONTAL_ALIGNMENT_CENTER)
	var linhas := _linhas(String(n.get("texto", "")), 8, L - 26.0)
	var y := TOPO + NAV + 14.0 + PASSO - 2.0
	for i in linhas.size():
		var linha: String = linhas[i]
		if i == linhas.size() - 1 and fmod(piscar, 1.0) < 0.55:
			linha += "|"
		t(Vector2(21.0, y + float(i) * PASSO), linha, 8, TINTA_NOTA, f_reg)


## Quebra respeitando as linhas que o jogador fez e a largura do papel.
func _linhas(texto: String, tam: int, largura: float) -> Array[String]:
	var saida: Array[String] = []
	for paragrafo: String in texto.split("\n"):
		var linha := ""
		for palavra: String in paragrafo.split(" "):
			var tenta := palavra if linha.is_empty() else linha + " " + palavra
			if w(tenta, tam) <= largura or linha.is_empty():
				linha = tenta
			else:
				saida.append(linha)
				linha = palavra
		saida.append(linha)
	return saida
