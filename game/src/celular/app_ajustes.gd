## Ajustes, no iOS 4: tabela agrupada sobre o fundo listrado.
##
## O que se ajusta aqui mexe de verdade: o brilho e o do vidro na mao (e da luz
## que ele joga no rosto), o fundo de tela e o do bloqueio e do inicio, e em Uso
## o jogador ve o que ocupa o aparelho e apaga o que quiser para caber o que
## quer baixar.
class_name AppAjustes
extends AppIos

enum Tela { RAIZ, USO, FUNDO, SOBRE }

const LINHA := 19.0
const GRUPO := 8.0

var _tela: Tela = Tela.RAIZ


func abrir() -> void:
	_tela = Tela.RAIZ
	sel = 0
	rol = 0.0
	rol_alvo = 0.0


func mostrar_uso() -> void:
	_tela = Tela.USO
	sel = 0
	rol_alvo = 0.0


static func brilho() -> float:
	return float(WorldState.obter(Celular.COORD, &"brilho", 0.8))


func _itens() -> int:
	match _tela:
		Tela.RAIZ:
			return 4
		Tela.USO:
			return _apps_do_uso().size()
		Tela.FUNDO:
			return SoFundo.NOMES.size()
	return 0


func _apps_do_uso() -> Array[StringName]:
	var lista: Array[StringName] = []
	for id: StringName in Celular.apps_da_tela():
		if not CatalogoDeApps.do_sistema(id) and Celular.instalado(id):
			lista.append(id)
	lista.sort_custom(func(a: StringName, b: StringName) -> bool:
		return CatalogoDeApps.tamanho(a) > CatalogoDeApps.tamanho(b))
	return lista


func acao(nome: StringName) -> bool:
	var n := _itens()
	match nome:
		&"cima":
			sel = maxi(0, sel - 1)
		&"baixo":
			sel = mini(maxi(0, n - 1), sel + 1)
		&"esq", &"dir":
			if _tela == Tela.RAIZ and sel == 0:
				_mudar_brilho(-0.1 if nome == &"esq" else 0.1)
			elif _tela == Tela.FUNDO:
				sel = posmod(sel + (1 if nome == &"dir" else -1), n)
		&"ok":
			_escolher(sel)
		&"voltar":
			if _tela == Tela.RAIZ:
				return false
			_tela = Tela.RAIZ
			sel = 0
			rol_alvo = 0.0
	return true


func tocar(id: Variant) -> bool:
	if super.tocar(id):
		return true
	if id is Array:
		var a: Array = id
		if a[0] == &"item":
			sel = int(a[1])
			_escolher(sel)
			return true
		if a[0] == &"brilho":
			return true
	return false


func arrastar(desde: Vector2, delta: Vector2, fim: bool) -> bool:
	if _tela == Tela.RAIZ and _trilho().grow(6.0).has_point(desde):
		if not fim:
			_mudar_brilho(delta.x / _trilho().size.x)
		return true
	return super.arrastar(desde, delta, fim)


func toque(p: Vector2) -> bool:
	if _tela == Tela.RAIZ and _trilho().grow(5.0).has_point(p):
		var k := clampf((p.x - _trilho().position.x) / _trilho().size.x, 0.05, 1.0)
		WorldState.definir(Celular.COORD, &"brilho", k)
		return true
	return super.toque(p)


func _mudar_brilho(d: float) -> void:
	WorldState.definir(Celular.COORD, &"brilho", clampf(brilho() + d, 0.05, 1.0))


func _escolher(i: int) -> void:
	match _tela:
		Tela.RAIZ:
			match i:
				1: _tela = Tela.FUNDO
				2: _tela = Tela.USO
				3: _tela = Tela.SOBRE
				_: return
			sel = Celular.fundo_de_tela if _tela == Tela.FUNDO else 0
			rol_alvo = 0.0
			AudioDirector.tocar_ui(&"clique", -20.0)
		Tela.USO:
			var lista := _apps_do_uso()
			if i < lista.size():
				Celular.pedir_apagar(lista[i])
		Tela.FUNDO:
			Celular.fundo_de_tela = i
			AudioDirector.tocar_ui(&"celular_ok", -16.0)


func _trilho() -> Rect2:
	return Rect2(30.0, TOPO + NAV + GRUPO + 7.5, L - 60.0, 3.0)


# --- desenho ------------------------------------------------------------------

func desenhar(visor: Control) -> void:
	v = visor
	fundo_listrado()
	match _tela:
		Tela.RAIZ:
			_raiz()
			nav("Ajustes")
		Tela.USO:
			_uso()
			nav("Uso", "Ajustes")
		Tela.FUNDO:
			_fundos()
			nav("Fundo de Tela", "Ajustes")
		Tela.SOBRE:
			_sobre()
			nav("Sobre", "Ajustes")


func _raiz() -> void:
	var y := TOPO + NAV + GRUPO - rol
	# O brilho: o sol pequeno, o trilho e o sol grande, numa celula so.
	var r := Rect2(6.0, y, L - 12.0, LINHA)
	celula(r, true, true, false)
	if foco_visivel and sel == 0:
		arred(r.grow(0.8), 4.5, Color(SELECIONADA, 0.7), false, 0.8)
	var tr := _trilho()
	tr.position.y = y + 7.5
	_sol(Vector2(tr.position.x - 9.0, tr.get_center().y), 1.6)
	_sol(Vector2(tr.end.x + 9.0, tr.get_center().y), 2.6)
	barra_ios(tr, brilho(), Color("3a8ef0"))
	var bx := tr.position.x + tr.size.x * brilho()
	v.draw_circle(Vector2(bx, tr.get_center().y), 4.2, Color(0, 0, 0, 0.2))
	v.draw_circle(Vector2(bx, tr.get_center().y - 0.3), 3.9, Color("f4f5f7"))
	v.draw_arc(Vector2(bx, tr.get_center().y - 0.3), 3.9, 0.0, TAU, 20, Color("8f959d"), 0.4, true)
	alvo(r, [&"brilho"])
	y += LINHA + GRUPO
	var livre := CatalogoDeApps.formatar_mb(Celular.espaco_livre())
	var itens := [["Fundo de Tela", SoFundo.NOMES[posmod(Celular.fundo_de_tela, SoFundo.NOMES.size())]],
		["Uso", livre + " livres"]]
	for k in itens.size():
		linha_de_grupo(Rect2(6.0, y + float(k) * LINHA, L - 12.0, LINHA), k + 1, 3,
			String(itens[k][0]), String(itens[k][1]), true, [&"item", k + 1])
	# "Sobre" e o ultimo do grupo; a borda de cima dele e reta.
	var rs := Rect2(6.0, y + 2.0 * LINHA, L - 12.0, LINHA)
	var marcada := (foco_visivel and sel == 3) or sob_dedo(rs)
	celula(rs, false, true, marcada)
	t(Vector2(rs.position.x + 7.0, rs.get_center().y + 2.4), "Sobre", 7,
		Color.WHITE if marcada else TINTA, f_bold)
	seta(Vector2(rs.end.x - 6.0, rs.get_center().y), Color.WHITE if marcada else Color("8e949c"))
	alvo(rs, [&"item", 3])
	y += 3.0 * LINHA + GRUPO
	var eu := RegistroCivil.jogador
	var dono := "iPhone de " + String(eu.get("primeiro", "Voce")).capitalize() if not eu.is_empty() else "iPhone"
	t(Vector2(0.0, y + 6.0), dono, 6, Color("4c566a"), f_semi, L, HORIZONTAL_ALIGNMENT_CENTER)
	t(Vector2(0.0, y + 14.0), "iOS 4.3.3", 5, Color("6d7683"), f_reg, L, HORIZONTAL_ALIGNMENT_CENTER)


func _sol(c: Vector2, r: float) -> void:
	v.draw_circle(c, r, Color("7a818b"))
	for k in 8:
		var a := float(k) * TAU / 8.0
		v.draw_line(c + Vector2(cos(a), sin(a)) * (r + 0.8), c + Vector2(cos(a), sin(a)) * (r + 1.9),
			Color("7a818b"), 0.5)


func _uso() -> void:
	var y0 := TOPO + NAV + GRUPO
	var y := y0 - rol
	# A barra do aparelho: sistema, fotos, musica, apps e o que sobra.
	var r := Rect2(6.0, y, L - 12.0, 34.0)
	celula(r, true, true, false)
	var usado := Celular.espaco_usado()
	var total := CatalogoDeApps.CAPACIDADE_MB
	t(Vector2(r.position.x + 7.0, y + 10.0), "Usado", 6, TINTA, f_bold)
	t(Vector2(r.position.x, y + 10.0), CatalogoDeApps.formatar_mb(usado), 6, AZUL_IOS, f_reg,
		r.size.x - 7.0, HORIZONTAL_ALIGNMENT_RIGHT)
	var br := Rect2(r.position.x + 7.0, y + 15.0, r.size.x - 14.0, 5.0)
	var partes := [[CatalogoDeApps.SISTEMA_MB, Color("8e949c")], [CatalogoDeApps.FOTOS_MB, Color("f2a93b")],
		[CatalogoDeApps.MUSICAS_MB, Color("e0507a")], [usado - CatalogoDeApps.SISTEMA_MB
		- CatalogoDeApps.FOTOS_MB - CatalogoDeApps.MUSICAS_MB, Color("3a8ef0")]]
	arred(br, 2.5, Color("dfe3e8"))
	var x := br.position.x
	for p: Array in partes:
		var larg := br.size.x * float(p[0]) / total
		ret(Rect2(x, br.position.y, larg, br.size.y), p[1])
		x += larg
	arred(br, 2.5, Color(0, 0, 0, 0.2), false, 0.4)
	var legenda := [["Sistema", Color("8e949c")], ["Fotos", Color("f2a93b")], ["Musica", Color("e0507a")],
		["Apps", Color("3a8ef0")]]
	var lx := br.position.x
	for l: Array in legenda:
		v.draw_circle(Vector2(lx + 1.5, y + 26.0), 1.5, l[1])
		t(Vector2(lx + 4.5, y + 28.0), String(l[0]), 5, FRACA, f_semi)
		lx += 30.0
	y += 34.0 + GRUPO
	t(Vector2(8.0, y + 4.0), "Disponivel: " + CatalogoDeApps.formatar_mb(Celular.espaco_livre()), 6,
		Color("4c566a"), f_semi)
	y += 9.0
	var lista := _apps_do_uso()
	if lista.is_empty():
		t(Vector2(0.0, y + 14.0), "Nenhum app para apagar.", 6, FRACA, f_semi, L, HORIZONTAL_ALIGNMENT_CENTER)
	for i in lista.size():
		var rr := Rect2(6.0, y + float(i) * LINHA, L - 12.0, LINHA)
		var marcada := (foco_visivel and sel == i) or sob_dedo(rr)
		celula(rr, i == 0, i == lista.size() - 1, marcada)
		CatalogoDeApps.icone(v, lista[i], Rect2(rr.position.x + 4.0, rr.position.y + 3.0, 13.0, 13.0))
		t(Vector2(rr.position.x + 21.0, rr.get_center().y + 2.4), CatalogoDeApps.nome(lista[i]), 7,
			Color.WHITE if marcada else TINTA, f_bold)
		t(Vector2(rr.position.x, rr.get_center().y + 2.2),
			CatalogoDeApps.formatar_mb(CatalogoDeApps.tamanho(lista[i])), 6,
			Color.WHITE if marcada else AZUL_IOS, f_reg, rr.size.x - 7.0, HORIZONTAL_ALIGNMENT_RIGHT)
		alvo(rr, [&"item", i])
	var alto_janela := alto_tela - y0 - 4.0
	var total_conteudo := 34.0 + GRUPO + 9.0 + float(lista.size()) * LINHA + 20.0
	if foco_visivel:
		seguir(34.0 + GRUPO + 9.0 + float(sel) * LINHA, LINHA, alto_janela, total_conteudo)
	if not lista.is_empty():
		t(Vector2(0.0, y + float(lista.size()) * LINHA + 10.0), "Toque num app para apagar.", 5,
			Color("4c566a"), f_semi, L, HORIZONTAL_ALIGNMENT_CENTER)


func _fundos() -> void:
	var y := TOPO + NAV + 10.0
	var larg := 38.0
	var alto := 57.0
	var vao := (L - larg * 3.0) / 4.0
	for i in SoFundo.NOMES.size():
		var r := Rect2(vao + float(i) * (larg + vao), y, larg, alto)
		# O fundo em miniatura: desenhado inteiro e escalado para a moldura.
		v.draw_set_transform(r.position, 0.0, Vector2(larg / L, alto / alto_tela))
		SoFundo.desenhar(v, i, piscar, alto_tela)
		v.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var escolhido := i == Celular.fundo_de_tela
		ret(Rect2(r.position.x - 0.8, r.position.y - 0.8, r.size.x + 1.6, 0.8), Color.WHITE)
		v.draw_rect(r.grow(0.6), Color.WHITE, false, 1.2)
		if (foco_visivel and sel == i) or sob_dedo(r):
			v.draw_rect(r.grow(2.0), Color(SELECIONADA, 0.9), false, 1.0)
		t(Vector2(r.position.x, r.end.y + 8.0), SoFundo.NOMES[i], 6, TINTA if escolhido else FRACA,
			f_bold if escolhido else f_semi, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		if escolhido:
			v.draw_circle(Vector2(r.get_center().x, r.end.y + 13.0), 1.4, SELECIONADA)
		alvo(r, [&"item", i])
	# O fundo escolhido, grande, embaixo: como fica o inicio.
	var p := Rect2(L * 0.5 - 30.0, y + alto + 22.0, 60.0, 90.0)
	v.draw_set_transform(p.position, 0.0, Vector2(p.size.x / L, p.size.y / alto_tela))
	SoFundo.desenhar(v, Celular.fundo_de_tela, piscar, alto_tela)
	v.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	v.draw_rect(p.grow(2.0), Color("1b1d21"), false, 3.5)
	t(Vector2(p.position.x, p.position.y + 18.0), SoFundo.hora(), 11, Color.WHITE, f_reg, p.size.x,
		HORIZONTAL_ALIGNMENT_CENTER)


func _sobre() -> void:
	var y := TOPO + NAV + GRUPO
	var eu := RegistroCivil.jogador
	var nome := "iPhone de " + String(eu.get("primeiro", "Voce")).capitalize() if not eu.is_empty() else "iPhone"
	var itens := [["Nome", nome], ["Capacidade", "8 GB"],
		["Disponivel", CatalogoDeApps.formatar_mb(Celular.espaco_livre())],
		["Apps", str(Celular.apps_da_tela().size() + CatalogoDeApps.DOCK.size())],
		["Versao", "4.3.3 (8J2)"], ["Modelo", "MC603BR"], ["Operadora", "REDE 3G"]]
	for k in itens.size():
		linha_de_grupo(Rect2(6.0, y + float(k) * LINHA, L - 12.0, LINHA), k,
			itens.size(), String(itens[k][0]), String(itens[k][1]), false, null, false)
	y += float(itens.size()) * LINHA + GRUPO
	if not eu.is_empty():
		t(Vector2(8.0, y + 4.0), "PORTADOR", 5, Color("4c566a"), f_semi)
		linha_de_grupo(Rect2(6.0, y + 8.0, L - 12.0, LINHA), 0, 2, "Nome",
			String(eu.get("nome", "")).capitalize(), false, null, false)
		linha_de_grupo(Rect2(6.0, y + 8.0 + LINHA, L - 12.0, LINHA), 1, 2, "CPF",
			String(eu.get("cpf", "")), false, null, false)
