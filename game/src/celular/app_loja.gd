## A App Store do iPhone do jogo, no desenho do iOS 4: barra azul-acinzentada em
## cima, lista de apps com o botao de preco, a pagina de cada app e a barra de
## abas preta embaixo.
##
## O fluxo e o do aparelho de verdade: o botao de preco vira "INSTALAR" no
## primeiro toque e so instala no segundo, e instalar leva de volta a tela de
## inicio, onde o icone novo aparece "Carregando...". Espaco e dinheiro sao de
## verdade: sem espaco a loja manda apagar alguma coisa, e o app pago sai do
## saldo do jogador.
class_name AppLoja
extends AppCelular

enum Aba { DESTAQUES, TOP, BUSCAR, COMPRADOS }

const ABAS := ["Destaques", "Top 25", "Buscar", "Comprados"]
const NAV := 17.0
const ABA_ALTO := 22.0
const LINHA := 29.0
const FUNDO := Color("e4e7ec")
const NAV_CIMA := Color("b8c5d6")
const NAV_BAIXO := Color("6e84a3")
const NAV_LINHA := Color("2d3f5a")
const TINTA := Color("1a1d22")
const FRACA := Color("7b8594")
const AZUL := Color("2a6fd6")
const VERDE := Color("37a246")
const DIVISA := Color("c9ced6")

var aba: Aba = Aba.DESTAQUES
var _sel: int = 0
## A rolagem de agora e a que ela persegue (unidades).
var _rol: float = 0.0
var _rol_alvo: float = 0.0
## O app aberto na pagina de detalhe (vazio: a lista).
var _detalhe: StringName = &""
## O app cujo botao ja virou "INSTALAR" e espera o segundo toque.
var _armado: StringName = &""
var _busca: String = ""
var _foco_busca: bool = false


func abrir() -> void:
	_detalhe = &""
	_armado = &""
	_sel = 0
	_rol = 0.0
	_rol_alvo = 0.0


func digitando() -> bool:
	return aba == Aba.BUSCAR and _foco_busca and _detalhe == &""


## A lista da aba de agora.
func lista() -> Array[StringName]:
	var saida: Array[StringName] = []
	match aba:
		Aba.DESTAQUES:
			saida = CatalogoDeApps.DESTAQUES.duplicate()
		Aba.TOP:
			var todos: Array[StringName] = []
			for id: StringName in CatalogoDeApps.APPS:
				if not CatalogoDeApps.do_sistema(id):
					todos.append(id)
			todos.sort_custom(func(a: StringName, b: StringName) -> bool:
				return int(CatalogoDeApps.dados(a).get("votos", 0)) > int(CatalogoDeApps.dados(b).get("votos", 0)))
			saida = todos
		Aba.BUSCAR:
			var q := _busca.strip_edges().to_lower()
			if q.is_empty():
				return saida
			for id: StringName in CatalogoDeApps.APPS:
				if CatalogoDeApps.do_sistema(id):
					continue
				var d := CatalogoDeApps.dados(id)
				if String(d["nome"]).to_lower().contains(q) or String(d.get("cat", "")).to_lower().contains(q) \
						or String(d.get("dev", "")).to_lower().contains(q):
					saida.append(id)
		Aba.COMPRADOS:
			for id: StringName in Celular.comprados():
				saida.append(id)
	return saida


func processar(delta: float) -> void:
	super.processar(delta)
	_rol = lerpf(_rol, _rol_alvo, minf(1.0, delta * 14.0))


# --- entrada ------------------------------------------------------------------

func acao(nome: StringName) -> bool:
	if _detalhe != &"":
		match nome:
			&"ok":
				_apertar_botao(_detalhe)
			&"voltar":
				_detalhe = &""
				_armado = &""
			&"cima", &"baixo":
				pass
		return true
	var n := lista().size()
	match nome:
		&"esq", &"dir":
			if _foco_busca:
				return true
			_trocar_aba(posmod(int(aba) + (1 if nome == &"dir" else -1), ABAS.size()))
		&"cima":
			if aba == Aba.BUSCAR and _sel <= 0:
				_foco_busca = true
			else:
				_sel = maxi(0, _sel - 1)
		&"baixo":
			if _foco_busca:
				_foco_busca = false
				_sel = 0
			else:
				_sel = mini(maxi(0, n - 1), _sel + 1)
		&"ok":
			if _foco_busca:
				_foco_busca = false
			elif n > 0:
				_abrir_detalhe(lista()[_sel])
		&"voltar":
			if _foco_busca:
				_foco_busca = false
				return true
			if _armado != &"":
				_armado = &""
				return true
			return false
	_seguir_selecao()
	return true


func tecla(ev: InputEventKey) -> bool:
	if not digitando():
		# Letra na aba de busca vai para o campo, como no Trampo.
		if aba == Aba.BUSCAR and _detalhe == &"" and ev.unicode > 0:
			var c := char(ev.unicode)
			if c.to_upper() >= "A" and c.to_upper() <= "Z" and not "WASDECQ".contains(c.to_upper()):
				_foco_busca = true
				_busca = c
				_sel = 0
				AudioDirector.tocar_ui(&"celular_tecla", -16.0)
				return true
		return false
	if ev.keycode == KEY_BACKSPACE:
		_busca = _busca.substr(0, maxi(0, _busca.length() - 1))
		AudioDirector.tocar_ui(&"celular_tecla", -18.0)
		return true
	if ev.keycode == KEY_ENTER or ev.keycode == KEY_KP_ENTER:
		_foco_busca = false
		_sel = 0
		return true
	if ev.keycode in [KEY_UP, KEY_DOWN, KEY_ESCAPE]:
		return false
	if ev.unicode > 0 and _busca.length() < 20:
		_busca += char(ev.unicode)
		_sel = 0
		AudioDirector.tocar_ui(&"celular_tecla", -16.0)
		return true
	return false


func tocar(id: Variant) -> bool:
	if id is Array:
		var a: Array = id
		match a[0]:
			&"aba":
				_trocar_aba(int(a[1]))
			&"linha":
				_sel = int(a[1])
				_abrir_detalhe(StringName(a[2]))
			&"botao":
				_apertar_botao(StringName(a[1]))
			&"voltar":
				_detalhe = &""
				_armado = &""
			&"busca":
				_foco_busca = true
		return true
	return false


func arrastar(_desde: Vector2, delta: Vector2, _fim: bool) -> bool:
	if _detalhe != &"":
		return false
	_rol_alvo = clampf(_rol_alvo - delta.y, 0.0, _rol_maximo())
	_rol = _rol_alvo
	return true


func rolar(passos: float) -> bool:
	if _detalhe != &"":
		return true
	_rol_alvo = clampf(_rol_alvo + passos * LINHA * 0.8, 0.0, _rol_maximo())
	return true


func _trocar_aba(nova: int) -> void:
	aba = nova as Aba
	_sel = 0
	_rol = 0.0
	_rol_alvo = 0.0
	_armado = &""
	_foco_busca = aba == Aba.BUSCAR and _busca.is_empty()
	AudioDirector.tocar_ui(&"clique", -20.0)


func _abrir_detalhe(id: StringName) -> void:
	_detalhe = id
	_armado = &""
	AudioDirector.tocar_ui(&"clique", -18.0)


## O botao de preco: o primeiro toque arma ("INSTALAR"), o segundo instala. Ja
## instalado, ele abre o app.
func _apertar_botao(id: StringName) -> void:
	if Celular.progresso_de(id) >= 0.0:
		return
	if Celular.instalado(id):
		Celular.abrir_da_loja(id)
		return
	if _armado != id:
		_armado = id
		AudioDirector.tocar_ui(&"clique", -14.0)
		return
	_armado = &""
	Celular.instalar(id)


func _area_da_lista() -> Rect2:
	var y0 := TOPO + NAV
	if aba == Aba.BUSCAR:
		y0 += 20.0
	elif aba == Aba.DESTAQUES:
		y0 += 0.0
	return Rect2(0.0, y0, L, alto_tela - ABA_ALTO - y0)


func _topo_da_lista() -> float:
	return 58.0 if aba == Aba.DESTAQUES else 0.0


func _rol_maximo() -> float:
	var area := _area_da_lista()
	return maxf(0.0, _topo_da_lista() + float(lista().size()) * LINHA - area.size.y + 4.0)


## A rolagem segue a selecao de tecla: a linha escolhida nunca fica fora.
func _seguir_selecao() -> void:
	var area := _area_da_lista()
	var y := _topo_da_lista() + float(_sel) * LINHA
	if y < _rol_alvo:
		_rol_alvo = maxf(0.0, y - (_topo_da_lista() if _sel == 0 else 0.0))
	elif y + LINHA > _rol_alvo + area.size.y:
		_rol_alvo = y + LINHA - area.size.y
	_rol_alvo = clampf(_rol_alvo, 0.0, _rol_maximo())


# --- desenho ------------------------------------------------------------------

func desenhar(visor: Control) -> void:
	v = visor
	ret(Rect2(0.0, 0.0, L, alto_tela), FUNDO)
	if _detalhe != &"":
		_pagina_do_app(_detalhe)
		_barra_nav(CatalogoDeApps.nome(_detalhe), true)
	else:
		var area := _area_da_lista()
		if aba == Aba.BUSCAR:
			_campo_busca()
		_lista(area)
		_barra_nav(ABAS[aba], false)
	_abas()
	desenhar_aviso()


func _barra_nav(titulo: String, com_voltar: bool) -> void:
	grad_v(Rect2(0.0, TOPO, L, NAV), NAV_CIMA, NAV_BAIXO)
	ret(Rect2(0.0, TOPO, L, 0.5), Color(1, 1, 1, 0.45))
	ret(Rect2(0.0, TOPO + NAV - 0.6, L, 0.6), NAV_LINHA)
	var nome := cortar(titulo, 7, L - 70.0, f_bold)
	t(Vector2(0.0, TOPO + 12.6), nome, 7, Color(0, 0, 0, 0.35), f_bold, L, HORIZONTAL_ALIGNMENT_CENTER)
	t(Vector2(0.0, TOPO + 12.0), nome, 7, Color.WHITE, f_bold, L, HORIZONTAL_ALIGNMENT_CENTER)
	if com_voltar:
		var b := Rect2(4.0, TOPO + 3.5, 31.0, 10.0)
		var pts := PackedVector2Array([Vector2(b.position.x, b.position.y + b.size.y * 0.5),
			Vector2(b.position.x + 5.0, b.position.y), Vector2(b.end.x - 1.5, b.position.y),
			Vector2(b.end.x, b.position.y + 1.5), Vector2(b.end.x, b.end.y - 1.5),
			Vector2(b.end.x - 1.5, b.end.y), Vector2(b.position.x + 5.0, b.end.y)])
		v.draw_colored_polygon(pts, Color("4f6a92") if not sob_dedo(b.grow(3.0)) else Color("34507a"))
		pts.append(pts[0])
		v.draw_polyline(pts, Color(NAV_LINHA, 0.8), 0.5, true)
		t(Vector2(b.position.x + 4.0, b.position.y + 7.4), ABAS[aba], 5, Color.WHITE, f_semi,
			b.size.x - 4.0, HORIZONTAL_ALIGNMENT_CENTER)
		alvo(b.grow(3.0), [&"voltar"])


func _campo_busca() -> void:
	var faixa := Rect2(0.0, TOPO + NAV, L, 20.0)
	grad_v(faixa, Color("c9d1dc"), Color("aab5c3"))
	var campo := Rect2(6.0, faixa.position.y + 4.0, L - 12.0, 12.0)
	arred(campo, 6.0, Color.WHITE)
	arred(campo, 6.0, AZUL if _foco_busca else Color("8c95a3"), false, 0.6 if _foco_busca else 0.4)
	var lupa := campo.position + Vector2(7.0, 5.8)
	v.draw_arc(lupa, 2.2, 0.0, TAU, 12, FRACA, 0.7, true)
	v.draw_line(lupa + Vector2(1.6, 1.6), lupa + Vector2(3.4, 3.4), FRACA, 0.8, true)
	if _busca.is_empty() and not _foco_busca:
		t(campo.position + Vector2(13.0, 8.3), "Apps, jogos, categorias", 6, FRACA)
	else:
		t(campo.position + Vector2(13.0, 8.3), cortar(_busca, 6, campo.size.x - 20.0), 6, TINTA)
		if _foco_busca and fmod(piscar, 0.9) < 0.5:
			var x := campo.position.x + 13.4 + w(_busca, 6)
			v.draw_line(Vector2(x, campo.position.y + 2.5), Vector2(x, campo.end.y - 2.5), AZUL, 0.6)
	alvo(campo, [&"busca"])


func _lista(area: Rect2) -> void:
	var ids := lista()
	var y := area.position.y - _rol
	if aba == Aba.DESTAQUES:
		_vitrine(Rect2(4.0, y + 4.0, L - 8.0, 50.0))
		y += _topo_da_lista()
	if ids.is_empty():
		var msg := "Nada instalado ainda." if aba == Aba.COMPRADOS else "Digite o nome de um app."
		t(Vector2(0.0, area.position.y + 30.0), msg, 7, FRACA, f_semi, L, HORIZONTAL_ALIGNMENT_CENTER)
		return
	for i in ids.size():
		var r := Rect2(0.0, y + float(i) * LINHA, L, LINHA)
		if r.end.y < area.position.y or r.position.y > area.end.y:
			continue
		_linha(ids[i], i, r, area)


## O destaque do topo: o app da vez num cartaz com degrade.
func _vitrine(r: Rect2) -> void:
	var id := CatalogoDeApps.DESTAQUES[0]
	var d := CatalogoDeApps.dados(id)
	var pts := AppCelular.cantos(r, 4.0)
	var cores := PackedColorArray()
	for p: Vector2 in pts:
		var k := clampf((p.x - r.position.x) / r.size.x, 0.0, 1.0)
		cores.append((d["c2"] as Color).darkened(0.35).lerp((d["c1"] as Color).darkened(0.1), k))
	v.draw_polygon(pts, cores)
	arred(Rect2(r.position.x, r.position.y, r.size.x, r.size.y * 0.45), 4.0, Color(1, 1, 1, 0.12))
	CatalogoDeApps.icone(v, id, Rect2(r.position + Vector2(8.0, 10.0), Vector2(30.0, 30.0)))
	t(r.position + Vector2(45.0, 18.0), String(d["nome"]) + " " + String(d.get("versao", "")),
		10, Color.WHITE, f_bold)
	t(r.position + Vector2(45.0, 28.0), "O classico esta de volta.", 6, Color(1, 1, 1, 0.9), f_semi)
	t(r.position + Vector2(45.0, 37.0), "Novo em Jogos", 5, Color(1, 1, 1, 0.7), f_semi)
	alvo(r, [&"linha", -1, id])


func _linha(id: StringName, i: int, r: Rect2, area: Rect2) -> void:
	var d := CatalogoDeApps.dados(id)
	var sel := i == _sel and foco_visivel and not _foco_busca
	if sel or sob_dedo(r):
		ret(r, Color("cfdcf0"))
	ret(Rect2(0.0, r.end.y - 0.5, L, 0.5), DIVISA)
	var x := 5.0
	if aba == Aba.TOP:
		t(Vector2(2.0, r.position.y + 17.0), str(i + 1), 6, FRACA, f_semi, 8.0,
			HORIZONTAL_ALIGNMENT_CENTER)
		x = 11.0
	CatalogoDeApps.icone(v, id, Rect2(x, r.position.y + 3.5, 22.0, 22.0))
	var tx := x + 27.0
	var largura := L - tx - 38.0
	t(Vector2(tx, r.position.y + 10.0), cortar(String(d["nome"]), 7, largura, f_bold), 7, TINTA, f_bold)
	t(Vector2(tx, r.position.y + 17.5), cortar(String(d.get("dev", "")), 5, largura, f_semi), 5,
		FRACA, f_semi)
	estrelas(Vector2(tx, r.position.y + 23.0), float(d.get("nota", 0.0)), 1.6, Color("f2a93b"),
		Color("c8ccd3"))
	t(Vector2(tx + 20.0, r.position.y + 25.0), "(%d)" % int(d.get("votos", 0)), 5, FRACA)
	var b := _botao(id, Vector2(L - 36.0, r.position.y + 9.0), r.position.y >= area.position.y)
	alvo(Rect2(0.0, maxf(r.position.y, area.position.y), L - 38.0,
		minf(r.end.y, area.end.y) - maxf(r.position.y, area.position.y)), [&"linha", i, id])
	if b.position.y >= area.position.y and b.end.y <= area.end.y:
		alvo(b.grow(2.0), [&"botao", id])


## O botao de preco do iOS 4: contorno azul e texto azul; armado, verde e cheio;
## baixando, uma barra de progresso.
func _botao(id: StringName, p: Vector2, _visivel: bool) -> Rect2:
	var r := Rect2(p, Vector2(32.0, 11.0))
	var baixando := Celular.progresso_de(id)
	if baixando >= 0.0:
		arred(Rect2(r.position.x, r.position.y + 3.5, r.size.x, 4.0), 2.0, Color("c3c9d2"))
		arred(Rect2(r.position.x, r.position.y + 3.5, maxf(4.0, r.size.x * baixando), 4.0), 2.0, AZUL)
		return r
	var texto := CatalogoDeApps.rotulo_preco(id)
	var cheio := false
	var cor := AZUL
	if Celular.instalado(id):
		texto = "ABRIR"
	elif _armado == id:
		texto = "COMPRAR" if CatalogoDeApps.preco(id) > 0 else "INSTALAR"
		cheio = true
		cor = VERDE
	if cheio:
		grad_v(r, cor.lightened(0.25), cor)
		arred(r, 2.5, cor.darkened(0.3), false, 0.5)
		t(Vector2(r.position.x, r.position.y + 7.6), texto, 5, Color.WHITE, f_bold, r.size.x,
			HORIZONTAL_ALIGNMENT_CENTER)
	else:
		arred(r, 2.5, Color(1, 1, 1, 0.9) if not sob_dedo(r.grow(2.0)) else Color("dfe8f7"))
		arred(r, 2.5, Color(cor, 0.85), false, 0.55)
		t(Vector2(r.position.x, r.position.y + 7.6), texto, 5, cor, f_bold, r.size.x,
			HORIZONTAL_ALIGNMENT_CENTER)
	return r


func _pagina_do_app(id: StringName) -> void:
	var d := CatalogoDeApps.dados(id)
	var y := TOPO + NAV + 6.0
	grad_v(Rect2(0.0, TOPO + NAV, L, 52.0), Color("f7f8fa"), Color("dfe3e9"))
	CatalogoDeApps.icone(v, id, Rect2(7.0, y, 36.0, 36.0))
	t(Vector2(49.0, y + 9.0), cortar(String(d["nome"]), 9, L - 55.0, f_bold), 9, TINTA, f_bold)
	t(Vector2(49.0, y + 17.0), cortar(String(d.get("dev", "")), 6, L - 55.0, f_semi), 6, FRACA, f_semi)
	estrelas(Vector2(49.0, y + 23.5), float(d.get("nota", 0.0)), 2.0, Color("f2a93b"), Color("c8ccd3"))
	t(Vector2(72.0, y + 25.5), "%d avaliacoes" % int(d.get("votos", 0)), 5, FRACA)
	var b := _botao(id, Vector2(49.0, y + 29.0), true)
	alvo(b.grow(2.0), [&"botao", id])
	if foco_visivel:
		arred(b.grow(1.4), 3.4, Color(AZUL, 0.5), false, 0.6)
	y += 50.0
	ret(Rect2(0.0, y - 2.0, L, 0.5), DIVISA)
	t(Vector2(7.0, y + 7.0), "Descricao", 7, TINTA, f_bold)
	v.draw_multiline_string(f_reg, Vector2(7.0, y + 16.0), String(d.get("sobre", "")),
		HORIZONTAL_ALIGNMENT_LEFT, L - 14.0, 6, 6, Color("3a4049"))
	y += 60.0
	ret(Rect2(0.0, y, L, 0.5), DIVISA)
	var livre := Celular.espaco_livre()
	var mb := CatalogoDeApps.tamanho(id)
	var info := [["Categoria", String(d.get("cat", ""))], ["Versao", String(d.get("versao", "1.0"))],
		["Tamanho", CatalogoDeApps.formatar_mb(mb)], ["Disponivel", CatalogoDeApps.formatar_mb(livre)]]
	for k in info.size():
		var yy := y + 8.0 + float(k) * 9.0
		t(Vector2(7.0, yy), String(info[k][0]), 6, FRACA, f_semi)
		var cor := TINTA
		if k == 3 and not Celular.instalado(id) and mb > livre:
			cor = Color("d0342c")
		t(Vector2(50.0, yy), String(info[k][1]), 6, cor)
	if CatalogoDeApps.preco(id) > 0 and not Celular.instalado(id):
		t(Vector2(7.0, y + 46.0), "Seu saldo: " + Dinheiro.formatar(Dinheiro.saldo()), 6, FRACA, f_semi)


func _abas() -> void:
	var r := Rect2(0.0, alto_tela - ABA_ALTO, L, ABA_ALTO)
	grad_v(Rect2(r.position, Vector2(L, r.size.y * 0.5)), Color("3b3b3d"), Color("1d1d1f"))
	ret(Rect2(0.0, r.position.y + r.size.y * 0.5, L, r.size.y * 0.5), Color("0b0b0c"))
	ret(Rect2(0.0, r.position.y, L, 0.5), Color("5c5c60"))
	var larg := L / float(ABAS.size())
	for i in ABAS.size():
		var cel := Rect2(float(i) * larg, r.position.y, larg, r.size.y)
		var ativa := i == int(aba)
		if ativa:
			arred(cel.grow(-1.5), 2.0, Color(1, 1, 1, 0.13))
		var cor := Color("4fb2ff") if ativa else Color("9a9aa0")
		_icone_aba(i, cel.get_center() - Vector2(0.0, 3.0), cor)
		t(Vector2(cel.position.x, cel.end.y - 2.5), ABAS[i], 4, Color.WHITE if ativa else Color("9a9aa0"),
			f_semi, cel.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		alvo(cel, [&"aba", i])


func _icone_aba(i: int, c: Vector2, cor: Color) -> void:
	match i:
		0:
			var pts := PackedVector2Array()
			for k in 10:
				var a := -PI * 0.5 + float(k) * PI / 5.0
				pts.append(c + Vector2(cos(a), sin(a)) * (4.5 if k % 2 == 0 else 2.0))
			v.draw_colored_polygon(pts, cor)
		1:
			for k in 3:
				v.draw_rect(Rect2(c.x - 4.0, c.y - 3.5 + float(k) * 3.0, 8.0, 1.6), cor)
		2:
			v.draw_arc(c + Vector2(-0.8, -0.8), 2.8, 0.0, TAU, 14, cor, 1.0, true)
			v.draw_line(c + Vector2(1.2, 1.2), c + Vector2(3.8, 3.8), cor, 1.2, true)
		3:
			v.draw_rect(Rect2(c.x - 4.0, c.y - 1.0, 8.0, 5.0), cor)
			v.draw_line(c + Vector2(0.0, -4.5), c + Vector2(0.0, 1.5), cor, 1.1)
			v.draw_colored_polygon(PackedVector2Array([c + Vector2(-2.2, -0.5), c + Vector2(2.2, -0.5),
				c + Vector2(0.0, 2.0)]), cor)
