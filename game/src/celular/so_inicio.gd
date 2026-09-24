## A tela de inicio do iPhone do jogo: a grade de icones, as paginas, o dock de
## vidro e o modo de editar (os icones tremendo, com o "x" de apagar).
##
## As medidas sao as do iOS 4 levadas para a tela de 146 x 219: icone de 57
## pontos vira 26 unidades, a grade anda 76 pontos na horizontal e 88 na
## vertical, quatro por fileira, quatro fileiras por pagina, e o dock de 92
## pontos embaixo com quatro apps fixos.
##
## Quem abre, instala e apaga e o `Celular`; aqui so se desenha e se diz o que o
## jogador pediu.
class_name SoInicio
extends AppCelular

const ICONE := 26.0
const PASSO_X := 34.7
const PASSO_Y := 40.1
const X0 := 7.95
const Y0 := 15.0
const POR_PAGINA := 16
const DOCK_ALTO := 42.0
const DOCK_Y0 := 183.0
## O rotulo embaixo do icone.
const ROTULO := 5
## Quanto os icones tremem no modo de editar (graus) e a que ritmo.
const TREME_GRAUS := 2.4
const TREME_HZ := 2.6
## Arrasto horizontal que troca de pagina (unidades).
const VIRA_PAGINA := 24.0

signal pediu_abrir(id: StringName, de: Rect2)
signal pediu_apagar(id: StringName)

var pagina: int = 0
var editando: bool = false
## Foco de tecla/controle: indice na pagina (0 a 15) ou no dock (100 + i).
var foco: int = 0
## Os icones chegando (0 a 1): sobe quando a tela destrava.
var chegada: float = 1.0
var _desliza: float = 0.0
var _desliza_v: float = 0.0
var _apertado_em: Variant = null


func apps_da_pagina(p: int) -> Array[StringName]:
	var todos: Array[StringName] = Celular.apps_da_tela()
	var saida: Array[StringName] = []
	for i in range(p * POR_PAGINA, mini(todos.size(), (p + 1) * POR_PAGINA)):
		saida.append(todos[i])
	return saida


func paginas() -> int:
	return maxi(1, ceili(float(Celular.apps_da_tela().size()) / float(POR_PAGINA)))


func rect_do_icone(i: int) -> Rect2:
	if i >= 100:
		return Rect2(X0 + float(i - 100) * PASSO_X, DOCK_Y0, ICONE, ICONE)
	var col := i % 4
	var lin := i / 4
	return Rect2(X0 + float(col) * PASSO_X, Y0 + float(lin) * PASSO_Y, ICONE, ICONE)


func id_no_foco() -> StringName:
	if foco >= 100:
		var d := CatalogoDeApps.DOCK
		return d[foco - 100] if foco - 100 < d.size() else &""
	var ids := apps_da_pagina(pagina)
	return ids[foco] if foco < ids.size() else &""


func abrir() -> void:
	editando = false
	_desliza = 0.0
	pagina = clampi(pagina, 0, paginas() - 1)


func processar(delta: float) -> void:
	super.processar(delta)
	chegada = minf(1.0, chegada + delta / 0.5)
	# A pagina volta para o lugar com mola, como o dedo que solta a tela.
	if not apertando:
		_desliza_v += (-_desliza * 260.0 - _desliza_v * 26.0) * delta
		_desliza += _desliza_v * delta
		if absf(_desliza) < 0.05 and absf(_desliza_v) < 0.5:
			_desliza = 0.0
			_desliza_v = 0.0


# --- entrada ------------------------------------------------------------------

func acao(nome: StringName) -> bool:
	var n := apps_da_pagina(pagina).size()
	match nome:
		&"esq", &"dir":
			var passo := -1 if nome == &"esq" else 1
			if foco >= 100:
				foco = 100 + posmod(foco - 100 + passo, CatalogoDeApps.DOCK.size())
			else:
				var col := foco % 4
				if (col == 0 and passo < 0) or ((col == 3 or foco + 1 >= n) and passo > 0):
					_virar(passo)
				else:
					foco = clampi(foco + passo, 0, maxi(0, n - 1))
		&"cima":
			if foco >= 100:
				var col := foco - 100
				var linhas := ceili(float(n) / 4.0)
				foco = mini(n - 1, (linhas - 1) * 4 + col) if n > 0 else foco
				if foco < 0:
					foco = 100 + col
			elif foco >= 4:
				foco -= 4
		&"baixo":
			if foco < 100:
				if foco + 4 < n:
					foco += 4
				else:
					foco = 100 + mini(foco % 4, CatalogoDeApps.DOCK.size() - 1)
		&"ok":
			var id := id_no_foco()
			if id == &"":
				return true
			if editando:
				if not CatalogoDeApps.do_sistema(id) and Celular.progresso_de(id) < 0.0:
					pediu_apagar.emit(id)
				return true
			pediu_abrir.emit(id, rect_do_icone(foco))
		&"editar":
			editando = not editando
			AudioDirector.tocar_ui(&"clique", -16.0)
		&"voltar":
			if editando:
				editando = false
				return true
			if pagina != 0:
				_desliza = -L * 0.6
				_desliza_v = 0.0
				pagina = 0
				foco = 0
				return true
			return false
	return true


func _virar(passo: int) -> void:
	var nova := clampi(pagina + passo, 0, paginas() - 1)
	if nova == pagina:
		# Na ponta: a pagina resiste, estica e volta.
		_desliza_v -= float(passo) * 90.0
		return
	pagina = nova
	# Chega deslizando do lado de onde veio.
	_desliza = float(passo) * L * 0.6
	_desliza_v = 0.0
	foco = 0 if passo > 0 else mini(3, maxi(0, apps_da_pagina(pagina).size() - 1))
	AudioDirector.tocar_ui(&"clique", -24.0)


func tocar(id: Variant) -> bool:
	if not (id is Array):
		return false
	var a: Array = id
	var qual: StringName = a[0]
	var indice: int = a[1]
	if a.size() > 2 and a[2] == &"x":
		pediu_apagar.emit(qual)
		return true
	if editando:
		return true
	foco = indice
	pediu_abrir.emit(qual, rect_do_icone(indice))
	return true


func segurar(p: Vector2) -> bool:
	var id: Variant = alvo_em(p)
	if id == null or editando:
		return false
	editando = true
	AudioDirector.tocar_ui(&"clique", -12.0)
	return true


func arrastar(_desde: Vector2, delta: Vector2, fim: bool) -> bool:
	if not fim:
		_desliza += delta.x
		# Na ponta, o arrasto rende a metade: a pagina resiste.
		if (pagina == 0 and _desliza > 0.0) or (pagina == paginas() - 1 and _desliza < 0.0):
			_desliza -= delta.x * 0.55
		return true
	if _desliza < -VIRA_PAGINA and pagina < paginas() - 1:
		pagina += 1
		_desliza += L
		foco = 0
		AudioDirector.tocar_ui(&"clique", -24.0)
	elif _desliza > VIRA_PAGINA and pagina > 0:
		pagina -= 1
		_desliza -= L
		foco = 0
		AudioDirector.tocar_ui(&"clique", -24.0)
	return true


func rolar(passos: float) -> bool:
	_virar(1 if passos > 0.0 else -1)
	return true


# --- desenho ------------------------------------------------------------------

func desenhar(visor: Control) -> void:
	v = visor
	SoFundo.desenhar(v, Celular.fundo_de_tela, piscar, alto_tela)
	var n_pag := paginas()
	# A pagina de agora e as vizinhas, deslocadas pelo arrasto.
	for p in range(maxi(0, pagina - 1), mini(n_pag, pagina + 2)):
		var dx := float(p - pagina) * L + _desliza
		if absf(dx) >= L:
			continue
		_pagina(p, dx, p == pagina)
	_pontos(n_pag)
	_dock()


func _pagina(p: int, dx: float, atual: bool) -> void:
	var ids := apps_da_pagina(p)
	for i in ids.size():
		var r := rect_do_icone(i)
		r.position.x += dx
		_icone(ids[i], r, i, atual and foco == i and foco_visivel, atual)


func _pontos(n: int) -> void:
	if n <= 1:
		return
	var y := DOCK_Y0 - 9.5
	var passo := 6.0
	var x0 := L * 0.5 - float(n - 1) * passo * 0.5
	for i in n:
		v.draw_circle(Vector2(x0 + float(i) * passo, y), 1.35,
			Color(1, 1, 1, 0.95 if i == pagina else 0.35))


## A prateleira de vidro do iOS 4: um trapezio claro em perspectiva com a borda
## de cima acesa, e o reflexo dos icones embaixo.
func _dock() -> void:
	var topo := alto_tela - DOCK_ALTO
	var y_prateleira := DOCK_Y0 + ICONE - 5.0
	var chao := PackedVector2Array([Vector2(-2.0, alto_tela), Vector2(4.0, y_prateleira),
		Vector2(L - 4.0, y_prateleira), Vector2(L + 2.0, alto_tela)])
	v.draw_polygon(chao, PackedColorArray([Color(0.75, 0.8, 0.88, 0.32),
		Color(0.9, 0.93, 0.98, 0.55), Color(0.9, 0.93, 0.98, 0.55),
		Color(0.75, 0.8, 0.88, 0.32)]))
	v.draw_line(Vector2(4.0, y_prateleira), Vector2(L - 4.0, y_prateleira),
		Color(1, 1, 1, 0.85), 0.5)
	grad_v(Rect2(0.0, topo, L, y_prateleira - topo), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.18))
	var d := CatalogoDeApps.DOCK
	for i in d.size():
		var r := rect_do_icone(100 + i)
		# O reflexo: o icone de cabeca para baixo, apagado, sob a prateleira.
		v.draw_set_transform(Vector2(r.position.x, r.end.y + 1.0 + ICONE), 0.0, Vector2(1.0, -1.0))
		CatalogoDeApps.icone(v, d[i], Rect2(0.0, 0.0, ICONE, ICONE), 0.2)
		v.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_icone(d[i], r, 100 + i, foco == 100 + i and foco_visivel, true)


## Um icone com rotulo, emblema, progresso de download e o tremor de editar.
func _icone(id: StringName, r: Rect2, indice: int, focado: bool, tocavel: bool) -> void:
	var c := r.get_center()
	var escala := 1.0
	var giro := 0.0
	var alfa := 1.0
	# Chegando: os icones vem de fora, grandes e transparentes, e assentam.
	if chegada < 1.0:
		var atraso := clampf(c.distance_to(Vector2(L * 0.5, alto_tela * 0.45)) / 120.0, 0.0, 1.0) * 0.35
		var k := clampf((chegada - atraso) / (1.0 - atraso), 0.0, 1.0)
		k = 1.0 - pow(1.0 - k, 3.0)
		var fora := (c - Vector2(L * 0.5, alto_tela * 0.45)) * 0.9
		c += fora * (1.0 - k)
		escala *= lerpf(2.2, 1.0, k)
		alfa = k
	if editando:
		giro = deg_to_rad(TREME_GRAUS) * sin(piscar * TAU * TREME_HZ + float(indice) * 1.7)
	if focado:
		escala *= 1.08
	var baixando := Celular.progresso_de(id)
	var apertado := tocavel and sob_dedo(r) and not editando
	v.draw_set_transform(c, giro, Vector2(escala, escala))
	var local := Rect2(-ICONE * 0.5, -ICONE * 0.5, ICONE, ICONE)
	if focado:
		arred(local.grow(2.2), 7.0, Color(1.0, 1.0, 1.0, 0.28 * alfa))
		arred(local.grow(1.2), 6.0, Color(1.0, 1.0, 1.0, 0.5 * alfa), false, 0.6)
	# A sombra do icone no fundo.
	arred(Rect2(local.position + Vector2(0.0, 1.2), local.size), 5.0, Color(0, 0, 0, 0.35 * alfa))
	CatalogoDeApps.icone(v, id, local, alfa, baixando >= 0.0)
	if apertado:
		arred(local, 5.0, Color(0, 0, 0, 0.38))
	if baixando >= 0.0:
		var barra := Rect2(local.position.x + 3.0, local.end.y - 5.5, ICONE - 6.0, 2.4)
		arred(barra, 1.2, Color(0.1, 0.12, 0.16, 0.75 * alfa))
		arred(Rect2(barra.position, Vector2(maxf(2.4, barra.size.x * baixando), barra.size.y)), 1.2,
			Color(0.35, 0.7, 1.0, alfa))
	var emblema := Celular.emblema(id)
	if emblema > 0 and not editando:
		var ec := Vector2(local.end.x - 1.0, local.position.y + 1.0)
		v.draw_circle(ec, 5.0, Color(1, 1, 1, alfa))
		v.draw_circle(ec, 4.3, Color(0.86, 0.1, 0.08, alfa))
		v.draw_circle(ec + Vector2(0.0, -1.2), 3.2, Color(1, 0.5, 0.45, 0.35 * alfa))
		t(Vector2(ec.x - 5.0, ec.y + 2.1), str(emblema) if emblema < 100 else "99+", 6,
			Color(1, 1, 1, alfa), f_bold, 10.0, HORIZONTAL_ALIGNMENT_CENTER)
	# O rotulo, branco com sombra.
	var rotulo := CatalogoDeApps.nome(id)
	if baixando >= 0.0:
		rotulo = "Instalando..." if baixando > 0.75 else "Carregando..."
	rotulo = cortar(rotulo, ROTULO, PASSO_X - 1.0, f_semi)
	var ry := ICONE * 0.5 + 6.6
	t(Vector2(-PASSO_X * 0.5, ry + 0.45), rotulo, ROTULO, Color(0, 0, 0, 0.7 * alfa), f_semi,
		PASSO_X, HORIZONTAL_ALIGNMENT_CENTER)
	t(Vector2(-PASSO_X * 0.5, ry), rotulo, ROTULO, Color(1, 1, 1, alfa), f_semi, PASSO_X,
		HORIZONTAL_ALIGNMENT_CENTER)
	# O "x" de apagar, no canto de cima a esquerda.
	var pode_apagar := editando and not CatalogoDeApps.do_sistema(id) and baixando < 0.0
	if pode_apagar:
		var xc := local.position + Vector2(1.5, 1.5)
		v.draw_circle(xc, 4.6, Color(1, 1, 1, alfa))
		v.draw_circle(xc, 3.9, Color(0.08, 0.08, 0.09, alfa))
		var a := 1.5
		v.draw_line(xc + Vector2(-a, -a), xc + Vector2(a, a), Color(1, 1, 1, alfa), 0.8, true)
		v.draw_line(xc + Vector2(-a, a), xc + Vector2(a, -a), Color(1, 1, 1, alfa), 0.8, true)
	v.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if tocavel and alfa > 0.5:
		if pode_apagar:
			alvo(Rect2(r.position - Vector2(4.0, 4.0), Vector2(10.0, 10.0)), [id, indice, &"x"])
		alvo(r.grow(3.0), [id, indice])
