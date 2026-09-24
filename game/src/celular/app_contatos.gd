## Contatos: todo mundo que o jogador conheceu na rua ou consultou no Portal,
## em ordem alfabetica com a letra de cada grupo, como no iOS.
##
## O cartao de cada pessoa tem a foto (a do mesmo atlas que a veste na rua), o
## CPF e o que da para fazer com ela: ligar, consultar no Portal, ver o perfil de
## trabalho no Trampo e ver a carteira.
class_name AppContatos
extends AppIos

const LINHA := 16.0
const ACOES := ["Ligar", "Consultar no Portal", "Perfil no Trampo", "Ver carteira"]

var _lista: Array[int] = []
var _pessoa: Dictionary = {}
var _foto: ImageTexture


func abrir() -> void:
	_pessoa = {}
	sel = 0
	rol = 0.0
	rol_alvo = 0.0
	_montar()


func _montar() -> void:
	_lista = RegistroCivil.conhecidos().duplicate()
	_lista.sort_custom(func(a: int, b: int) -> bool:
		return String(RegistroCivil.identidade(a).get("nome", "")) < String(RegistroCivil.identidade(b).get("nome", "")))


func abrir_pessoa(id: int) -> void:
	_pessoa = RegistroCivil.identidade(id)
	_foto = Retrato.gerar_textura(_pessoa.get("aparencia", {}))
	sel = 0
	AudioDirector.tocar_ui(&"clique", -18.0)


func acao(nome: StringName) -> bool:
	if not _pessoa.is_empty():
		match nome:
			&"cima": sel = maxi(0, sel - 1)
			&"baixo": sel = mini(ACOES.size() - 1, sel + 1)
			&"ok": _fazer(sel)
			&"voltar":
				sel = maxi(0, _lista.find(int(_pessoa["id"])))
				_pessoa = {}
		return true
	match nome:
		&"cima": sel = maxi(0, sel - 1)
		&"baixo": sel = mini(maxi(0, _lista.size() - 1), sel + 1)
		&"ok":
			if not _lista.is_empty():
				abrir_pessoa(_lista[sel])
		&"voltar":
			return false
	return true


func _fazer(i: int) -> void:
	var id := int(_pessoa["id"])
	match i:
		0:
			var tel := Celular.trocar_para(&"telefone") as AppTelefone
			if tel != null:
				tel.ligar(id)
		1:
			var portal := Celular.trocar_para(&"portal") as AppPortal
			if portal != null:
				portal.consultar(String(_pessoa["cpf"]))
		2:
			if Celular.trocar_para(&"trampo") != null:
				Celular.trampo().mostrar_perfil(_pessoa, &"rede")
		3:
			Documento.abrir(_pessoa)


func tocar(id: Variant) -> bool:
	if super.tocar(id):
		return true
	if id is Array:
		var a: Array = id
		if a[0] == &"pessoa":
			sel = int(a[1])
			abrir_pessoa(_lista[sel])
		elif a[0] == &"acao":
			sel = int(a[1])
			_fazer(sel)
		return true
	return false


func desenhar(visor: Control) -> void:
	v = visor
	if _pessoa.is_empty():
		ret(Rect2(0.0, 0.0, L, alto_tela), Color.WHITE)
		_lista_desenho()
		nav("Contatos")
	else:
		fundo_listrado()
		_cartao()
		nav("Info", "Contatos")


func _lista_desenho() -> void:
	var y0 := TOPO + NAV
	if _lista.is_empty():
		t(Vector2(0.0, y0 + 50.0), "Sem Contatos", 9, Color("9aa1ab"), f_bold, L, HORIZONTAL_ALIGNMENT_CENTER)
		t(Vector2(0.0, y0 + 62.0), "Fale com alguem na rua e o", 6, FRACA, f_reg, L, HORIZONTAL_ALIGNMENT_CENTER)
		t(Vector2(0.0, y0 + 70.0), "nome aparece aqui.", 6, FRACA, f_reg, L, HORIZONTAL_ALIGNMENT_CENTER)
		return
	# O conteudo: cabecalho de letra toda vez que a inicial muda.
	var itens: Array = []
	var letra := ""
	for i in _lista.size():
		var f := RegistroCivil.identidade(_lista[i])
		var nome := String(f.get("nome", "?"))
		var ini := nome.substr(0, 1).to_upper()
		if ini != letra:
			letra = ini
			itens.append({"letra": ini})
		itens.append({"i": i, "f": f})
	var y_sel := 0.0
	var yy := 0.0
	for it: Dictionary in itens:
		var h := 8.0 if it.has("letra") else LINHA
		if it.has("i") and int(it["i"]) == sel:
			y_sel = yy
		yy += h
	var alto := alto_tela - y0
	if foco_visivel:
		seguir(y_sel, LINHA, alto, yy)
	var y := y0 - rol
	var eu := RegistroCivil.id_do_jogador()
	for it: Dictionary in itens:
		if it.has("letra"):
			if y > y0 - 8.0 and y < alto_tela:
				grad_v(Rect2(0.0, y, L, 8.0), Color("a5b1bf"), Color("8c99a8"))
				t(Vector2(5.0, y + 6.3), String(it["letra"]), 6, Color.WHITE, f_bold)
			y += 8.0
			continue
		var i := int(it["i"])
		var r := Rect2(0.0, y, L, LINHA)
		if r.end.y > y0 and r.position.y < alto_tela:
			var marcada := (foco_visivel and sel == i) or sob_dedo(r)
			if marcada:
				grad_v(r, Color("058cf5"), Color("015de6"))
			var f: Dictionary = it["f"]
			var partes := String(f.get("nome", "")).capitalize().split(" ")
			var primeiro := partes[0] if partes.size() > 0 else ""
			var resto := " ".join(partes.slice(1)) if partes.size() > 1 else ""
			var cor := Color.WHITE if marcada else TINTA
			t(Vector2(8.0, y + 10.5), primeiro, 7, cor, f_reg)
			t(Vector2(8.0 + w(primeiro + " ", 7), y + 10.5), cortar(resto, 7, L - 30.0 - w(primeiro, 7), f_bold),
				7, cor, f_bold)
			if _lista[i] == eu:
				t(Vector2(0.0, y + 10.5), "eu", 5, Color(1, 1, 1, 0.8) if marcada else FRACA, f_semi,
					L - 8.0, HORIZONTAL_ALIGNMENT_RIGHT)
			ret(Rect2(8.0, r.end.y - 0.4, L - 8.0, 0.4), Color("e0e3e7"))
			alvo(r, [&"pessoa", i])
		y += LINHA


func _cartao() -> void:
	var f := _pessoa
	var y := TOPO + NAV + 7.0
	var foto := Rect2(8.0, y, 36.0, 46.0)
	arred(Rect2(foto.position + Vector2(0.0, 1.0), foto.size), 3.0, Color(0, 0, 0, 0.2))
	arred(foto.grow(1.5), 3.5, Color.WHITE)
	if _foto != null:
		v.draw_texture_rect(_foto, foto, false)
	var x := foto.end.x + 8.0
	v.draw_multiline_string(f_bold, Vector2(x, y + 12.0), String(f.get("nome", "")).capitalize(),
		HORIZONTAL_ALIGNMENT_LEFT, L - x - 6.0, 8, 2, TINTA)
	t(Vector2(x, y + 36.0), String(f.get("profissao", "")).capitalize(), 6, Color("4c566a"), f_semi)
	y += 54.0
	linha_de_grupo(Rect2(6.0, y, L - 12.0, 17.0), 0, 2, "CPF", String(f.get("cpf", "")), false, null, false)
	linha_de_grupo(Rect2(6.0, y + 17.0, L - 12.0, 17.0), 1, 2, "Endereco",
		cortar(String(f.get("endereco", "")), 6, 70.0), false, null, false)
	y += 34.0 + 8.0
	for i in ACOES.size():
		var r := Rect2(6.0, y + float(i) * 17.0, L - 12.0, 17.0)
		var marcada := (foco_visivel and sel == i) or sob_dedo(r)
		celula(r, i == 0, i == ACOES.size() - 1, marcada)
		t(Vector2(r.position.x, r.get_center().y + 2.4), ACOES[i], 7,
			Color.WHITE if marcada else AZUL_IOS, f_bold, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		alvo(r, [&"acao", i])
