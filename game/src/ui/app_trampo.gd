## Trampo: perfis de trabalho da cidade.
##
## E onde a opcao TRABALHO da conversa abre: a pessoa mostra o perfil dela no
## celular do jogador. E e tambem uma busca — por nome, como no computador do
## mercadinho —, entao da para ver onde trabalha, em que horario e se esta no
## expediente qualquer pessoa que o registro civil alcance (quem esta por perto,
## quem voce ja conheceu e a familia deles).
##
## Para a equipe da estufa o perfil e de verdade: funcoes da folha de pagamento,
## o que a pessoa esta fazendo agora — regando o vaso 3, indo ao orelhao da Rua
## Tal — e os numeros do iWeed e da plantacao.
class_name AppTrampo
extends AppCelular

enum Tela { REDE, PERFIL }

const FUNDO := Color("eef2f6")
const CABECALHO := Color("0e3a5b")
const ACENTO := Color("1f86d1")
const TINTA := Color("17232e")
const FRACA := Color("687887")
const CARTAO := Color("ffffff")
const DIVISA := Color("d7dfe7")
const VERDE := Color("2f9e63")

const LINHA := 23.0
const LISTA_Y := 66.0
## Onde a lista acaba na tela de 186 do aparelho antigo. Na tela mais alta do
## iPhone ela desce junto com o rodape (`_lista_fim`).
const LISTA_FIM := 168.0


func _lista_fim() -> float:
	return LISTA_FIM + (alto_tela - A)


## A rolagem de uma lista pelo dedo, como a do iPhone: o conteudo acompanha o
## dedo no arrasto e, ao soltar, corre no embalo que o dedo tinha, freando; a
## roda do mouse desliza ate o alvo. A tecla nao passa pelo embalo: ela fixa o
## valor (`fixar`) e anda por linha inteira, como sempre andou. O iWeed usa a
## mesma (`AppTrampo.Rolagem`).
class Rolagem:
	## Freio do embalo (1/s) e o embalo maximo (unidades por segundo).
	const ATRITO := 4.5
	const VEL_MAX := 900.0
	## O embalo e o quanto o dedo andou nos ultimos `JANELA_MS` antes de soltar:
	## o dedo que parou antes de levantar nao arremessa a lista.
	const JANELA_MS := 100

	var px := 0.0
	var alvo := 0.0
	var vel := 0.0
	## Quem desenha a lista diz ate onde ela rola.
	var maximo := 0.0
	var arrastando := false
	var _inicio_ms := 0
	## (ms desde o inicio do arrasto, quanto o dedo andou em y), recentes.
	var _amostras: Array[Vector2] = []

	func fixar(valor: float) -> void:
		px = valor
		alvo = valor
		vel = 0.0

	func limitar() -> void:
		px = clampf(px, 0.0, maximo)
		alvo = clampf(alvo, 0.0, maximo)

	## `dy` e o quanto o dedo andou neste passo; `fim` quando ele levanta.
	func arrastar(dy: float, fim: bool) -> void:
		var agora := Time.get_ticks_msec()
		if fim:
			arrastando = false
			var t := float(agora - _inicio_ms)
			var soma := 0.0
			for a: Vector2 in _amostras:
				if t - a.x <= float(JANELA_MS):
					soma += a.y
			var janela := clampf(t, 16.0, float(JANELA_MS)) / 1000.0
			vel = clampf(-soma / janela, -VEL_MAX, VEL_MAX)
			_amostras.clear()
			return
		if not arrastando:
			arrastando = true
			_inicio_ms = agora
			_amostras.clear()
		vel = 0.0
		px = clampf(px - dy, 0.0, maximo)
		alvo = px
		var t_agora := float(agora - _inicio_ms)
		_amostras.append(Vector2(t_agora, dy))
		while not _amostras.is_empty() and t_agora - _amostras[0].x > float(JANELA_MS):
			_amostras.pop_front()

	## O dedo desceu: a lista que corria (embalo ou roda) para onde esta.
	## Devolve se ela corria — o toque entao so a segurou, e nao escolhe nada.
	func parar() -> bool:
		var corria := absf(vel) > 40.0 or absf(alvo - px) > 2.0
		vel = 0.0
		alvo = px
		return corria

	## A roda: `d` unidades para baixo (negativo, para cima).
	func rolar(d: float) -> void:
		vel = 0.0
		alvo = clampf(alvo + d, 0.0, maximo)

	func passo(delta: float) -> void:
		if arrastando:
			return
		if absf(vel) > 6.0:
			px += vel * delta
			vel *= exp(-ATRITO * delta)
			if px <= 0.0 or px >= maximo:
				vel = 0.0
			px = clampf(px, 0.0, maximo)
			alvo = px
		else:
			vel = 0.0
			px = lerpf(px, alvo, minf(1.0, delta * 14.0))


var _tela := Tela.REDE
var _busca := ""
var _foco_busca := false
var _lista: Array[int] = []
var _linhas: Dictionary = {}
var _resultado := false
var _sel := 0
var _rol := 0
var _ficha: Dictionary = {}
var _perfil: Dictionary = {}
var _foto: ImageTexture
## A rolagem da lista da rede (`_rol` e a mesma, em linhas, para a tecla) e a do
## perfil.
var _rl := Rolagem.new()
var _rp := Rolagem.new()
## O dedo desceu com a lista correndo: o toque que vem so a segura.
var _segurou_lista := false
var _apertava := false
var _alto_perfil := 0.0
## Para onde o ESC do perfil leva: `rede`, `fechar` (veio da conversa) ou
## `iweed` (veio da equipe ou dos clientes do iWeed).
var _volta := &"rede"
var saida := &"inicio"


func abrir() -> void:
	_tela = Tela.REDE
	_busca = ""
	_foco_busca = false
	_resultado = false
	_sel = 0
	_rol = 0
	_rl.fixar(0.0)
	_volta = &"rede"
	saida = &"inicio"
	_montar_rede()


func mostrar_perfil(ficha: Dictionary, volta: StringName) -> void:
	if _lista.is_empty():
		_montar_rede()
	_ficha = RegistroCivil.identidade(int(ficha["id"])) if ficha.has("id") else ficha
	if ficha.has("apelido"):
		_ficha = _ficha.duplicate()
		_ficha["apelido"] = ficha["apelido"]
	_perfil = PerfilTrabalho.de(_ficha)
	_foto = Retrato.gerar_textura(_ficha.get("aparencia", {}))
	_tela = Tela.PERFIL
	_rp.fixar(0.0)
	_volta = volta
	RegistroCivil.conhecer(int(_ficha["id"]))


func ficha_aberta() -> Dictionary:
	return _ficha if _tela == Tela.PERFIL else {}


func digitando() -> bool:
	return _tela == Tela.REDE and _foco_busca


func processar(delta: float) -> void:
	super.processar(delta)
	# Como no iPhone: o dedo que desce numa lista correndo so a segura.
	if apertando and not _apertava:
		var corria_l := _rl.parar()
		var corria_p := _rp.parar()
		_segurou_lista = corria_l or corria_p
	_apertava = apertando
	_rl.passo(delta)
	_rp.passo(delta)
	# O "agora" do perfil muda enquanto se olha: Jota termina de regar e vai
	# para o proximo vaso. Refeito duas vezes por segundo.
	if _tela == Tela.PERFIL and fmod(piscar, 0.5) < delta:
		_perfil = PerfilTrabalho.de(_ficha)


# --- dados ------------------------------------------------------------------------

func _montar_rede() -> void:
	_lista.clear()
	_linhas.clear()
	var eu := RegistroCivil.id_do_jogador()
	for chave: StringName in [&"fazendeiro", &"entregador"]:
		for id: Variant in Profissoes.empregados(chave):
			if not _lista.has(int(id)):
				_lista.append(int(id))
	for id: int in RegistroCivil.conhecidos():
		if _lista.has(id) or id == eu or _lista.size() >= 30:
			continue
		if FalasNpc.tem_trabalho(RegistroCivil.identidade(id)):
			_lista.append(id)
	_resultado = false
	_legendar()


func _buscar() -> void:
	var texto := _busca.strip_edges()
	if texto.length() < RegistroCivil.MINIMO_BUSCA:
		aviso("DIGITE 3 LETRAS OU MAIS", Color("d9822b"))
		AudioDirector.tocar_ui(&"celular_erro", -12.0)
		return
	_lista.clear()
	# A equipe entra sempre: quem trabalha para voce esta na sua rede mesmo
	# quando nao esta por perto — e o registro so busca quem esta.
	var procurado := texto.to_upper()
	for chave: StringName in [&"fazendeiro", &"entregador"]:
		for bruto: Variant in Profissoes.empregados(chave):
			var id := int(bruto)
			var f := RegistroCivil.identidade(id)
			var papel := String(RegistroCivil.personagem_de(id)).to_upper()
			if not _lista.has(id) and (String(f.get("nome", "")).contains(procurado)
					or (not papel.is_empty() and papel.contains(procurado))):
				_lista.append(id)
	for id: int in RegistroCivil.buscar_por_nome(texto):
		if not _lista.has(id):
			_lista.append(id)
	_resultado = true
	_foco_busca = false
	_sel = 0
	_rol = 0
	_rl.fixar(0.0)
	_legendar()
	AudioDirector.tocar_ui(&"celular_ok" if not _lista.is_empty() else &"celular_erro", -12.0)


## Nome e linha de baixo de cada pessoa da lista, montados uma vez.
func _legendar() -> void:
	for id in _lista:
		var f := RegistroCivil.identidade(id)
		var cargos := Profissoes.titulos(id)
		var sub := ""
		if not cargos.is_empty():
			sub = " E ".join(cargos) + "  ·  ESTUFA"
		elif FalasNpc.tem_trabalho(f):
			var p := PerfilTrabalho.de(f)
			sub = "%s  ·  %s" % [String(f["profissao"]), String(p["local"])]
		else:
			sub = "%s  ·  SEM PERFIL" % String(f.get("profissao", ""))
		var papel := RegistroCivil.personagem_de(id)
		var nome := String(f["nome"])
		if papel != &"":
			nome = "%s (%s)" % [String(papel).to_upper(), String(f.get("primeiro", ""))]
		_linhas[id] = {"nome": nome, "sub": sub, "equipe": not cargos.is_empty()}


# --- entrada ----------------------------------------------------------------------

func tecla(ev: InputEventKey) -> bool:
	var codigo := ev.keycode
	if _tela == Tela.PERFIL:
		if codigo == KEY_D and not _ficha.is_empty():
			Documento.abrir(_ficha)
			return true
		return false
	if _foco_busca:
		if codigo == KEY_ENTER or codigo == KEY_KP_ENTER:
			_buscar()
			return true
		if codigo == KEY_BACKSPACE:
			_busca = _busca.substr(0, maxi(0, _busca.length() - 1))
			AudioDirector.tocar_ui(&"celular_tecla", -18.0)
			return true
		if codigo == KEY_DOWN or codigo == KEY_UP or codigo == KEY_ESCAPE:
			return false
		var c := char(ev.unicode).to_upper() if ev.unicode > 0 else ""
		if (c >= "A" and c <= "Z") or c == " ":
			if _busca.length() < 24:
				_busca += c
				AudioDirector.tocar_ui(&"celular_tecla", -14.0)
			return true
		return false
	# Letra fora do campo pula para o campo — menos as de andar e usar.
	var letra := char(ev.unicode).to_upper() if ev.unicode > 0 else ""
	if letra >= "A" and letra <= "Z" and not "WASDECQ".contains(letra):
		_foco_busca = true
		_busca = letra
		AudioDirector.tocar_ui(&"celular_tecla", -14.0)
		return true
	return false


func acao(nome: StringName) -> bool:
	if _tela == Tela.PERFIL:
		match nome:
			&"cima":
				_rp.fixar(maxf(0.0, _rp.alvo - 22.0))
			&"baixo":
				_rp.fixar(minf(maxf(0.0, _alto_perfil - (_lista_fim() - TOPO)), _rp.alvo + 22.0))
			&"voltar":
				if _volta == &"fechar" or _volta == &"iweed":
					saida = _volta
					return false
				_tela = Tela.REDE
		return true

	match nome:
		&"cima":
			if _foco_busca:
				return true
			if _sel <= 0:
				_foco_busca = true
			else:
				_sel -= 1
		&"baixo":
			if _foco_busca:
				_foco_busca = false
				_sel = 0
			elif not _lista.is_empty():
				_sel = mini(_sel + 1, _lista.size() - 1)
		&"ok":
			if _foco_busca:
				_buscar()
			elif not _lista.is_empty():
				AudioDirector.tocar_ui(&"celular_ok", -12.0)
				mostrar_perfil(RegistroCivil.identidade(_lista[_sel]), &"rede")
		&"voltar":
			if _foco_busca:
				_foco_busca = false
				if not _busca.is_empty():
					_busca = ""
				return true
			if _resultado:
				_busca = ""
				_montar_rede()
				_sel = 0
				_rol = 0
				_rl.fixar(0.0)
				return true
			saida = &"inicio"
			return false
	var cabem := int((_lista_fim() - LISTA_Y) / LINHA)
	# Parte de onde o dedo deixou a lista; so com tecla, `_rl.px` ja e `_rol`
	# linhas inteiras e isto nao muda nada.
	_rol = clampi(roundi(_rl.px / LINHA), 0, maxi(0, _lista.size() - cabem))
	if _sel < _rol:
		_rol = _sel
	elif _sel >= _rol + cabem:
		_rol = _sel - cabem + 1
	_rl.fixar(float(_rol) * LINHA)
	return true


# --- toque ------------------------------------------------------------------------
# O dedo faz o que a tecla faz, pelo mesmo caminho: tocar uma pessoa da lista e
# escolher a linha e apertar E; a tecla do rodape tocada e a tecla apertada.

func tocar(id: Variant) -> bool:
	if not (id is Array) or (id as Array).is_empty():
		return false
	var a: Array = id
	match a[0]:
		&"rodape":
			return _tecla_do_rodape(String(a[1]))
		&"busca":
			# O campo tocado ganha o cursor, como a seta para cima na primeira
			# linha; as letras vem do teclado.
			if _tela == Tela.REDE and not _foco_busca:
				_foco_busca = true
				AudioDirector.tocar_ui(&"celular_tecla", -14.0)
			return true
		&"linha":
			var k := int(a[1])
			if _tela != Tela.REDE or k < 0 or k >= _lista.size():
				return false
			if _segurou_lista:
				_segurou_lista = false
				return false
			_foco_busca = false
			_sel = k
			return acao(&"ok")
	return false


func _tecla_do_rodape(letra: String) -> bool:
	match letra:
		"E", "ENTER":
			acao(&"ok")
		"↓":
			acao(&"baixo")
		"ESC":
			AppTrampo.voltar_pelo_celular()
		"D":
			return tecla(AppTrampo.tecla_falsa(KEY_D))
		_:
			return false
	return true


## O ESC tocado vai pelo mesmo caminho da tecla: o `Celular` pergunta ao app
## (`acao(&"voltar")`) e, na raiz dele, sai para onde o app disser — a grade, o
## iWeed ou fechar o aparelho. Chamar so o `acao` nao sairia da raiz.
static func voltar_pelo_celular() -> void:
	Celular.call(&"_voltar")


## A tecla de uma letra como o teclado a entregaria, para o rodape tocado usar o
## mesmo `tecla` da tecla de verdade.
static func tecla_falsa(codigo: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = codigo
	ev.physical_keycode = codigo
	ev.pressed = true
	if codigo >= KEY_A and codigo <= KEY_Z:
		ev.unicode = int(codigo) + 32
	return ev


## O dedo sobre `r`, sem estar rolando a lista: o realce de quem aperta. Quem
## arrasta nao "aperta" a linha em que o dedo comecou.
func _apertado(r: Rect2) -> bool:
	return sob_dedo(r) and not _rl.arrastando and not _rp.arrastando


func arrastar(_desde: Vector2, delta: Vector2, fim: bool) -> bool:
	if fim:
		# Solta as duas: o arrasto pode ter comecado na outra tela.
		for r: Rolagem in [_rl, _rp]:
			if r.arrastando:
				r.arrastar(0.0, true)
		return true
	if _tela == Tela.PERFIL:
		_rp.arrastar(delta.y, fim)
	else:
		_rl.arrastar(delta.y, fim)
	return true


func rolar(passos: float) -> bool:
	if passos == 0.0:
		return false
	if _tela == Tela.PERFIL:
		_rp.rolar(passos * 22.0)
	else:
		_rl.rolar(passos * LINHA)
	return true


# --- desenho ----------------------------------------------------------------------

func desenhar(visor: Control) -> void:
	v = visor
	ret(Rect2(0.0, 0.0, L, alto_tela), FUNDO)
	if _tela == Tela.PERFIL:
		_desenhar_perfil()
	else:
		_desenhar_rede()
	desenhar_aviso()


func _cabecalho(titulo: String) -> void:
	ret(Rect2(0.0, TOPO, L, 22.0), CABECALHO)
	AppCelular.maleta(v, Vector2(12.0, TOPO + 11.5), 4.6, Color("7cc4f5"))
	t(Vector2(21.0, TOPO + 15.5), "trampo", 10, Color.WHITE, f_bold)
	t(Vector2(L - 60.0, TOPO + 14.5), titulo, 6, Color(1, 1, 1, 0.6), f_semi, 54.0,
		HORIZONTAL_ALIGNMENT_RIGHT)


func _desenhar_rede() -> void:
	# A lista primeiro: a linha que sobe alem do topo passa por baixo do campo de
	# busca, desenhado depois por cima dela.
	if _lista.is_empty():
		var msg := "Ninguem com esse nome\npor aqui." if _resultado \
			else "Converse com as pessoas\nna rua e elas aparecem aqui."
		v.draw_multiline_string(f_reg, Vector2(8.0, LISTA_Y + 16.0), msg,
			HORIZONTAL_ALIGNMENT_CENTER, L - 16.0, 7, 3, FRACA)
	else:
		_desenhar_lista()
	ret(Rect2(0.0, 0.0, L, LISTA_Y - 1.0), FUNDO)
	if _rl.px > 0.5:
		grad_v(Rect2(0.0, LISTA_Y - 1.0, L, 4.0), FUNDO, Color(FUNDO, 0.0))

	_cabecalho("REDE")
	# Campo de busca.
	var campo := Rect2(6.0, 38.0, L - 12.0, 15.0)
	arred(campo, 7.5, Color("e6edf4") if _apertado(campo.grow(2.0)) else CARTAO)
	alvo(campo.grow(2.0), [&"busca"])
	arred(campo, 7.5, ACENTO if _foco_busca else DIVISA, false, 0.8 if _foco_busca else 0.5)
	var lupa := campo.position + Vector2(9.0, 7.0)
	v.draw_arc(lupa, 2.6, 0.0, TAU, 14, FRACA, 0.8, true)
	v.draw_line(lupa + Vector2(1.9, 1.9), lupa + Vector2(4.0, 4.0), FRACA, 0.9, true)
	if _busca.is_empty() and not _foco_busca:
		t(campo.position + Vector2(17.0, 10.3), "Buscar pessoa pelo nome", 7, FRACA)
	else:
		var mostrado := _busca
		t(campo.position + Vector2(17.0, 10.3), cortar(mostrado, 7, campo.size.x - 26.0, f_semi),
			7, TINTA, f_semi)
		if _foco_busca and fmod(piscar, 0.9) < 0.5:
			var x := campo.position.x + 17.5 + w(mostrado, 7, f_semi)
			v.draw_line(Vector2(x, campo.position.y + 3.5), Vector2(x, campo.end.y - 3.5),
				ACENTO, 0.7)

	var titulo := ("RESULTADOS PARA \"%s\"" % _busca.strip_edges()) if _resultado else "SUA REDE"
	t(Vector2(8.0, LISTA_Y - 5.0), cortar(titulo, 6, L - 40.0, f_semi), 6, FRACA, f_semi)
	t(Vector2(L - 30.0, LISTA_Y - 5.0), str(_lista.size()), 6, FRACA, f_semi, 22.0,
		HORIZONTAL_ALIGNMENT_RIGHT)

	if _foco_busca:
		rodape([["ENTER", "BUSCAR"], ["↓", "LISTA"], ["ESC", "LIMPAR"]], FUNDO, TINTA, FRACA)
	else:
		rodape([["E", "VER PERFIL"], ["ESC", "VOLTAR"]], FUNDO, TINTA, FRACA)


## As pessoas, na rolagem do dedo (`_rl`). A tecla so muda `_rol`, e a rolagem
## vai junto em linhas inteiras (`acao`). A moldura da escolha so aparece com a
## tecla ou o controle: com o dedo, marca quem esta sendo apertado.
func _desenhar_lista() -> void:
	var area := Rect2(0.0, LISTA_Y, L, _lista_fim() - LISTA_Y)
	var cabem := int(area.size.y / LINHA)
	_rl.maximo = maxf(0.0, float(_lista.size() - cabem) * LINHA)
	_rl.limitar()
	for k in range(maxi(0, int(_rl.px / LINHA)), _lista.size()):
		var id := _lista[k]
		var y := LISTA_Y + float(k) * LINHA - _rl.px
		# Passa por baixo do rodape ate sumir nele.
		if y >= alto_tela - 14.0:
			break
		var r := Rect2(4.0, y, L - 8.0, LINHA - 1.5)
		var toque := r.intersection(area)
		var apertada := toque.has_area() and _apertado(toque)
		var sel := k == _sel and not _foco_busca and foco_visivel
		arred(r, 3.0, Color("d0e3f4") if apertada else (Color("e3f0fb") if sel else CARTAO))
		if sel:
			arred(Rect2(r.position.x, r.position.y + 3.0, 1.6, r.size.y - 6.0), 0.8, ACENTO)
		var dados: Dictionary = _linhas.get(id, {})
		var nome := String(dados.get("nome", "?"))
		avatar(r.position + Vector2(11.0, r.size.y * 0.5), 7.0, nome, AppCelular.cor_de(id))
		var equipe := bool(dados.get("equipe", false))
		var largura_nome := r.size.x - 30.0 - (26.0 if equipe else 0.0)
		t(r.position + Vector2(22.0, 9.5), cortar(nome, 7, largura_nome, f_semi), 7,
			TINTA, f_semi)
		t(r.position + Vector2(22.0, 17.5), cortar(String(dados.get("sub", "")), 6,
			r.size.x - 28.0), 6, FRACA)
		if equipe:
			chip(Vector2(r.end.x - 29.0, r.position.y + 9.0), "EQUIPE", Color("d7f0e2"),
				VERDE, 5)
		if toque.has_area():
			alvo(toque, [&"linha", k])
	if _rl.maximo > 0.0:
		var frac := float(cabem) / float(_lista.size())
		var alto := area.size.y * frac
		var y0 := LISTA_Y + (area.size.y - alto) * _rl.px / _rl.maximo
		arred(Rect2(L - 2.5, y0, 1.5, alto), 0.75, Color(FRACA, 0.5))


func _desenhar_perfil() -> void:
	if _ficha.is_empty():
		return
	var p := _perfil
	var equipe := bool(p.get("equipe", false))
	var oy := -_rp.px
	# Capa.
	var capa := Rect2(0.0, TOPO + oy, L, 30.0)
	if equipe:
		grad_h(capa, Color("14532f"), Color("2f9e63"))
		AppCelular.folha(v, Vector2(L - 16.0, TOPO + 15.0 + oy), 9.0, Color(1, 1, 1, 0.14))
	else:
		grad_h(capa, Color("0e3a5b"), Color("2275b3"))
		AppCelular.maleta(v, Vector2(L - 16.0, TOPO + 15.0 + oy), 7.0, Color(1, 1, 1, 0.14))
	t(Vector2(7.0, TOPO + 10.0 + oy), "trampo", 7, Color(1, 1, 1, 0.75), f_bold)

	# Retrato na moldura, meio para fora da capa.
	var foto := Rect2(7.0, TOPO + 16.0 + oy, 44.0, 56.0)
	ret(Rect2(foto.position + Vector2(1.0, 1.5), foto.size), Color(0, 0, 0, 0.18))
	ret(foto, Color.WHITE)
	if _foto != null:
		v.draw_texture_rect(_foto, foto.grow(-2.0), false)

	var x := 56.0
	var nome := String(_ficha.get("nome", ""))
	var apelido := String(_ficha.get("apelido", ""))
	if apelido.is_empty() and RegistroCivil.personagem_de(int(_ficha["id"])) != &"":
		apelido = String(RegistroCivil.personagem_de(int(_ficha["id"]))).to_upper()
	var y := TOPO + 40.0 + oy
	if not apelido.is_empty():
		t(Vector2(x, y), apelido, 10, TINTA, f_bold)
		y += 8.0
		t(Vector2(x, y), cortar(nome, 6, L - x - 5.0), 6, FRACA)
	else:
		v.draw_multiline_string(f_semi, Vector2(x, y), nome, HORIZONTAL_ALIGNMENT_LEFT,
			L - x - 5.0, 8, 2, TINTA)
		y += 9.0 if w(nome, 8, f_semi) < L - x - 5.0 else 17.0
	y += 9.0
	t(Vector2(x, y), cortar(String(p.get("titulo", "")), 6, L - x - 5.0, f_semi), 6,
		ACENTO, f_semi)
	y += 10.0
	if equipe:
		var cx := x
		for c: String in p.get("cargos", PackedStringArray()):
			cx += chip(Vector2(cx, y), c, Color("d7f0e2"), VERDE, 5) + 3.0

	# Agora.
	var ay := TOPO + 86.0 + oy
	arred(Rect2(5.0, ay - 9.0, L - 10.0, 22.0 if not String(p.get("agora_extra", "")).is_empty()
		else 15.0), 3.0, CARTAO)
	var ativo := bool(p.get("ativo", false))
	var cor_agora := Color("e0892b") if bool(p.get("fora", false)) \
		else (VERDE if ativo else FRACA)
	var pulso := 0.6 + 0.4 * sin(piscar * 4.0) if ativo else 1.0
	v.draw_circle(Vector2(12.0, ay - 1.8), 2.2, Color(cor_agora, pulso))
	t(Vector2(18.0, ay + 0.5), "AGORA", 5, FRACA, f_semi)
	t(Vector2(40.0, ay + 0.5), cortar(String(p.get("agora", "")), 6, L - 48.0, f_semi), 6,
		cor_agora.darkened(0.15), f_semi)
	if not String(p.get("agora_extra", "")).is_empty():
		t(Vector2(40.0, ay + 8.5), String(p["agora_extra"]), 6, FRACA)

	# Ficha de trabalho.
	var iy := ay + (24.0 if not String(p.get("agora_extra", "")).is_empty() else 17.0)
	for par: Array in [["LOCAL", String(p.get("local", ""))],
			["HORARIO", String(p.get("horario", ""))],
			["TEMPO", String(p.get("desde", ""))]]:
		t(Vector2(8.0, iy), String(par[0]), 5, FRACA, f_semi)
		t(Vector2(8.0, iy + 8.0), cortar(String(par[1]), 7, L - 16.0), 7, TINTA)
		iy += 17.0
		v.draw_line(Vector2(8.0, iy - 5.0), Vector2(L - 8.0, iy - 5.0), DIVISA, 0.4)
	t(Vector2(8.0, iy), "AVALIACAO", 5, FRACA, f_semi)
	estrelas(Vector2(8.0, iy + 5.5), float(p.get("estrelas", 0.0)), 2.6, Color("f2b632"),
		Color("d5dde5"))
	t(Vector2(40.0, iy + 8.0), "%.1f  (%d)" % [float(p.get("estrelas", 0.0)),
		int(p.get("avaliacoes", 0))], 6, FRACA)
	iy += 17.0

	if equipe:
		var st: Dictionary = p.get("stats", {})
		var entregas := int(st.get("entregas", 0))
		var prazo := roundi(100.0 * float(st.get("no_prazo", 0)) / float(maxi(1, entregas)))
		var tiles := [["ENTREGAS", str(entregas)],
			["NO PRAZO", ("%d%%" % prazo) if entregas > 0 else "-"],
			["TAREFAS NA ESTUFA", str(int(st.get("tarefas", 0)))],
			["RENDEU", Dinheiro.formatar(int(st.get("ganho", 0)))]]
		for k in tiles.size():
			var col := k % 2
			var lin := k / 2
			var r := Rect2(5.0 + float(col) * 69.0, iy + float(lin) * 26.0, 67.0, 23.0)
			arred(r, 3.0, CARTAO)
			t(r.position + Vector2(6.0, 12.0), String(tiles[k][1]), 9, TINTA, f_bold)
			t(r.position + Vector2(6.0, 19.5), String(tiles[k][0]), 5, FRACA, f_semi)
		iy += 54.0
		var sobre := String(p.get("sobre", ""))
		if not sobre.is_empty():
			v.draw_multiline_string(f_reg, Vector2(8.0, iy + 4.0), "\"%s\"" % sobre,
				HORIZONTAL_ALIGNMENT_LEFT, L - 16.0, 6, 3, FRACA)
			iy += 22.0
	elif not FalasNpc.tem_trabalho(_ficha):
		t(Vector2(8.0, iy + 4.0), "SEM VINCULO PROFISSIONAL", 6, FRACA, f_semi)
		iy += 12.0
	_alto_perfil = iy - oy - TOPO + 6.0
	_rp.maximo = maxf(0.0, _alto_perfil - (_lista_fim() - TOPO))
	_rp.limitar()

	var volta := "FECHAR" if _volta == &"fechar" else "VOLTAR"
	rodape([["D", "IDENTIDADE"], ["ESC", volta]], FUNDO, TINTA, FRACA)
