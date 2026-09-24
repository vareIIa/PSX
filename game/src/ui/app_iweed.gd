## iWeed: o aplicativo. A tela do motor que mora em `world/iweed.gd`.
##
## Cinco abas, como um app de entrega de verdade:
##   PEDIDOS   o que chegou agora: quem, o que, quanto paga, onde e quando.
##             Aceitar leva voce; passar para a equipe manda Jota ou Helmer.
##   AGENDA    o que ja esta combinado, na ordem do horario, com quem vai.
##   CLIENTES  a carteira: satisfacao, quantos pedidos e o que a Super fez.
##   EQUIPE    o estoque da estufa e o que cada um esta fazendo agora.
##   GANHOS    saldo e extrato.
class_name AppIWeed
extends AppCelular

enum Aba { PEDIDOS, AGENDA, CLIENTES, EQUIPE, GANHOS, LOJA }
const NOMES_ABA := ["PEDIDOS", "AGENDA", "CLIENTES", "EQUIPE", "GANHOS", "LOJA"]

const FUNDO := Color("090d0b")
const PAINEL := Color("131b16")
const PAINEL_SEL := Color("1a2a20")
const VERDE := Color("6fe39a")
const VERDE_ESCURO := Color("1d5a35")
const TINTA := Color("e4f2e8")
const FRACA := Color("7d8f84")
const OURO := Color("f2d46b")
const LARANJA := Color("ffb45c")
const VERMELHO := Color("ff6a4a")
const ROXO := Color("b48cff")

const CONTEUDO_Y := 51.0
const CONTEUDO_FIM := 168.0

## Int, e nao Aba: `as Aba` num int devolve null em silencio.
var _aba: int = Aba.PEDIDOS
var _sel := 0
var _rol := 0
var _itens: Array = []
## Quando o jogador pede o perfil de alguem da equipe ou da carteira, o celular
## troca para o Trampo e volta para ca no ESC.
var abrir_perfil_de: Dictionary = {}
## Conversa aberta com o cliente de um pedido (-1 = nenhuma) e a resposta
## rapida escolhida.
var _chat := -1
var _chat_sel := 0
const AZUL := Color("8fcaff")
const BALAO_CLIENTE := Color("1d2a33")
const BALAO_EU := Color("1d4d31")


func abrir() -> void:
	_chat = -1
	_aba = Aba.PEDIDOS if not IWeed.abertos().is_empty() or IWeed.agenda().is_empty() \
		else Aba.AGENDA
	_sel = 0
	_rol = 0
	abrir_perfil_de = {}


func voltar_da_aba(aba: int) -> void:
	_aba = aba if aba >= 0 and aba < NOMES_ABA.size() else Aba.PEDIDOS
	abrir_perfil_de = {}


func aba() -> int:
	return int(_aba)


func definir_aba(a: int) -> void:
	_aba = clampi(a, 0, NOMES_ABA.size() - 1)
	_sel = 0
	_rol = 0


func processar(delta: float) -> void:
	super.processar(delta)
	_itens = _montar_itens()
	_sel = clampi(_sel, 0, maxi(0, _itens.size() - 1))


func _montar_itens() -> Array:
	match _aba:
		Aba.PEDIDOS:
			return IWeed.abertos()
		Aba.AGENDA:
			return IWeed.agenda()
		Aba.CLIENTES:
			var lista := IWeed.clientes().duplicate()
			lista.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return float(a["satisfacao"]) > float(b["satisfacao"]))
			return lista
		Aba.EQUIPE:
			var ids: Array = []
			for chave: StringName in [&"entregador", &"fazendeiro"]:
				for id: Variant in Profissoes.empregados(chave):
					if not ids.has(int(id)):
						ids.append(int(id))
			return ids
		Aba.LOJA:
			return IWeed.LOJA.duplicate()
	return []


# --- entrada ----------------------------------------------------------------------

## Publica: abre a conversa de um pedido (testes e capturas).
func abrir_chat(n: int) -> void:
	_chat = n
	_chat_sel = 0


func chat_aberto() -> int:
	return _chat


func tecla(ev: InputEventKey) -> bool:
	if _chat >= 0:
		return false
	if ev.keycode == KEY_M and (_aba == Aba.PEDIDOS or _aba == Aba.AGENDA):
		var p := _pedido_selecionado()
		if not p.is_empty():
			abrir_chat(int(p["n"]))
			AudioDirector.tocar_ui(&"celular_ok", -12.0)
			return true
	match ev.keycode:
		KEY_O:
			IWeed.definir_online(not IWeed.online())
			aviso("VOCE ESTA ONLINE" if IWeed.online() else "VOCE ESTA OFFLINE",
				VERDE if IWeed.online() else FRACA)
			AudioDirector.tocar_ui(&"celular_ok", -10.0)
			return true
		KEY_F:
			var p := _pedido_selecionado()
			if p.is_empty():
				return false
			if IWeed.passar(int(p["n"])):
				aviso("%s VAI ENTREGAR" % IWeed.apelido(int(IWeed.pedido(int(p["n"]))["entregador"])),
					VERDE)
				AudioDirector.tocar_ui(&"celular_ok", -10.0)
			else:
				aviso("EQUIPE OCUPADA OU SEM ESTOQUE", LARANJA)
				AudioDirector.tocar_ui(&"celular_erro", -10.0)
			return true
		KEY_X:
			if _aba != Aba.PEDIDOS:
				return false
			var p := _pedido_selecionado()
			if p.is_empty():
				return false
			IWeed.recusar(int(p["n"]))
			aviso("PEDIDO RECUSADO", FRACA)
			AudioDirector.tocar_ui(&"clique", -10.0)
			return true
	return false


func _pedido_selecionado() -> Dictionary:
	if (_aba != Aba.PEDIDOS and _aba != Aba.AGENDA) or _itens.is_empty():
		return {}
	return _itens[_sel]


func acao(nome: StringName) -> bool:
	if _chat >= 0:
		return _acao_chat(nome)
	match nome:
		&"esq":
			definir_aba(posmod(int(_aba) - 1, NOMES_ABA.size()))
		&"dir":
			definir_aba(posmod(int(_aba) + 1, NOMES_ABA.size()))
		&"cima":
			_sel = maxi(0, _sel - 1)
		&"baixo":
			_sel = mini(maxi(0, _itens.size() - 1), _sel + 1)
		&"voltar":
			return false
		&"ok":
			_confirmar()
	return true


# --- conversa ---------------------------------------------------------------------

## Respostas rapidas conforme o estado do pedido: [rotulo, acao].
func _respostas(p: Dictionary) -> Array:
	var estado := String(p.get("estado", ""))
	if estado == "novo":
		var saida: Array = [["ACEITAR  %s" % Dinheiro.formatar(int(p["preco"])), "aceitar"]]
		if not bool(p.get("negociado", false)):
			saida.append(["FAZ %s?" % Dinheiro.formatar(int(roundf(float(p["preco"]) * 1.25))), "n25"])
			saida.append(["FAZ %s?" % Dinheiro.formatar(int(roundf(float(p["preco"]) * 1.5))), "n50"])
		saida.append(["PASSAR PRA EQUIPE", "equipe"])
		return saida
	if estado == "aceito" and String(p["quem"]) == "":
		var saida: Array = [["TO CHEGANDO", "chegando"]]
		if not bool(p.get("atrasou", false)):
			saida.append(["VOU ATRASAR UM POUCO", "atrasar"])
		saida.append(["MARCAR NO GPS", "gps"])
		return saida
	return []


func _acao_chat(nome: StringName) -> bool:
	var p := IWeed.pedido(_chat)
	var respostas := _respostas(p)
	match nome:
		&"voltar":
			_chat = -1
		&"cima":
			_chat_sel = maxi(0, _chat_sel - 1)
		&"baixo":
			_chat_sel = mini(maxi(0, respostas.size() - 1), _chat_sel + 1)
		&"ok":
			if respostas.is_empty():
				return true
			var acao := String(respostas[clampi(_chat_sel, 0, respostas.size() - 1)][1])
			match acao:
				"aceitar":
					IWeed.aceitar(_chat)
					aviso("ACEITO. ROTA NO GPS", VERDE)
				"n25", "n50":
					var r := IWeed.negociar(_chat, 1.25 if acao == "n25" else 1.5)
					if bool(r.get("aceitou", false)):
						aviso("TOPOU", VERDE)
					elif bool(r.get("cancelou", false)):
						aviso("DESISTIU DO PEDIDO", LARANJA)
					else:
						aviso("NAO TOPOU", LARANJA)
				"equipe":
					if IWeed.passar(_chat):
						aviso("A EQUIPE VAI", VERDE)
					else:
						aviso("EQUIPE OCUPADA OU SEM ESTOQUE", LARANJA)
				"chegando":
					IWeed.responder_cliente(_chat, "To chegando.")
				"atrasar":
					IWeed.atrasar(_chat)
				"gps":
					IWeed.marcar_no_gps(_chat)
					aviso("ROTA NO GPS", VERDE)
			AudioDirector.tocar_ui(&"celular_ok", -12.0)
			_chat_sel = 0
	return true


func _desenhar_chat() -> void:
	var p := IWeed.pedido(_chat)
	if p.is_empty():
		_chat = -1
		return
	var id := int(p["cliente"])
	var nome := IWeed.nome_curto(id)
	# Cabecalho da conversa por cima das abas.
	ret(Rect2(0.0, TOPO, L, 26.0), Color("0f1a13"))
	v.draw_polyline(PackedVector2Array([Vector2(8.5, TOPO + 9.0), Vector2(5.5, TOPO + 13.0),
		Vector2(8.5, TOPO + 17.0)]), TINTA, 0.8, true)
	avatar(Vector2(21.0, TOPO + 13.0), 7.0, nome, AppCelular.cor_de(id))
	t(Vector2(32.0, TOPO + 12.0), nome.to_upper(), 7, TINTA, f_semi)
	var produto := String(p["produto"])
	t(Vector2(32.0, TOPO + 20.5), "%dx %s  ·  %s" % [int(p["qtd"]), IWeed.nome_do_produto(produto),
		Dinheiro.formatar(int(p["preco"]))], 5, _cor_produto(produto), f_semi)
	var estado := String(p["estado"])
	var rotulo_estado: String = {"novo": "PEDIDO", "aceito": "COMBINADO", "a_caminho": "EQUIPE A CAMINHO",
		"entregue": "ENTREGUE", "atrasado": "ENTREGUE", "falhou": "FALHOU",
		"recusado": "RECUSADO", "expirado": "EXPIROU"}.get(estado, "")
	t(Vector2(L - 58.0, TOPO + 12.0), rotulo_estado, 5, FRACA, f_semi, 53.0,
		HORIZONTAL_ALIGNMENT_RIGHT)

	# Baloes, de baixo para cima, acima das respostas.
	var respostas := _respostas(p)
	var base := A - 18.0 - float(respostas.size()) * 13.0 - 3.0
	var msgs := IWeed.mensagens(p)
	var y := base
	for k in range(msgs.size() - 1, -1, -1):
		var m: Array = msgs[k]
		var autor := String(m[0])
		var texto := String(m[1])
		var largura_max := L - 44.0
		var linhas := _quebrar(texto, 6, largura_max - 8.0)
		var alto := 5.0 + float(linhas.size()) * 7.5 + 5.0
		y -= alto + 3.0
		if y < TOPO + 28.0:
			break
		var larg := 0.0
		for l: String in linhas:
			larg = maxf(larg, w(l, 6))
		larg = minf(largura_max, larg + 10.0)
		var eu := autor == "eu"
		var x := L - 5.0 - larg if eu else 5.0
		var r := Rect2(x, y, larg, alto)
		arred(r, 4.0, BALAO_EU if eu else BALAO_CLIENTE)
		for q in linhas.size():
			t(Vector2(r.position.x + 5.0, r.position.y + 9.5 + float(q) * 7.5), linhas[q], 6,
				TINTA if eu else Color("dbe8f2"))
		var m_hora := int(m[2])
		if k == msgs.size() - 1:
			t(Vector2(r.position.x if not eu else r.end.x - 20.0, r.end.y + 6.0),
				"%02d:%02d" % [m_hora / 60, m_hora % 60], 4, FRACA, f_reg, 20.0,
				HORIZONTAL_ALIGNMENT_LEFT if not eu else HORIZONTAL_ALIGNMENT_RIGHT)

	# Respostas rapidas.
	var ry := A - 18.0 - float(respostas.size()) * 13.0
	for k in respostas.size():
		var r := Rect2(5.0, ry + float(k) * 13.0, L - 10.0, 11.0)
		var sel := k == clampi(_chat_sel, 0, respostas.size() - 1)
		arred(r, 5.5, Color(VERDE, 0.22) if sel else Color(1, 1, 1, 0.06))
		if sel:
			arred(r, 5.5, Color(VERDE, 0.8), false, 0.5)
		t(Vector2(r.position.x, r.position.y + 7.8), String(respostas[k][0]), 6,
			VERDE if sel else TINTA, f_semi, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	rodape([["E", "ENVIAR"], ["ESC", "VOLTAR"]] if not respostas.is_empty()
		else [["ESC", "VOLTAR"]], FUNDO, TINTA, FRACA)


## Quebra `texto` em linhas que cabem em `largura`.
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
	if not linha.is_empty():
		saida.append(linha)
	return saida


func _confirmar() -> void:
	match _aba:
		Aba.PEDIDOS:
			if _itens.is_empty():
				if not IWeed.online():
					IWeed.definir_online(true)
					aviso("VOCE ESTA ONLINE", VERDE)
					AudioDirector.tocar_ui(&"celular_ok", -10.0)
				return
			var p: Dictionary = _itens[_sel]
			if IWeed.aceitar(int(p["n"])):
				aviso("ACEITO. ROTA NO GPS", VERDE)
				AudioDirector.tocar_ui(&"celular_ok", -8.0)
		Aba.AGENDA:
			if _itens.is_empty():
				return
			var p: Dictionary = _itens[_sel]
			if String(p["quem"]) == "":
				IWeed.marcar_no_gps(int(p["n"]))
				aviso("ROTA NO GPS", VERDE)
				AudioDirector.tocar_ui(&"celular_ok", -10.0)
		Aba.CLIENTES:
			if not _itens.is_empty():
				abrir_perfil_de = RegistroCivil.identidade(int(_itens[_sel]["id"]))
		Aba.EQUIPE:
			if not _itens.is_empty():
				abrir_perfil_de = RegistroCivil.identidade(int(_itens[_sel]))
		Aba.LOJA:
			if _itens.is_empty():
				return
			var r := IWeed.comprar(String(_itens[_sel]["id"]))
			aviso(String(r["texto"]), VERDE if bool(r["ok"]) else LARANJA)
			AudioDirector.tocar_ui(&"celular_ok" if bool(r["ok"]) else &"celular_erro", -10.0)


# --- desenho ----------------------------------------------------------------------

func desenhar(visor: Control) -> void:
	v = visor
	ret(Rect2(0.0, 0.0, L, A), FUNDO)
	if _chat >= 0:
		_desenhar_chat()
		desenhar_aviso()
		return
	_cabecalho()
	_abas()
	match _aba:
		Aba.PEDIDOS:
			_desenhar_pedidos()
		Aba.AGENDA:
			_desenhar_agenda()
		Aba.CLIENTES:
			_desenhar_clientes()
		Aba.EQUIPE:
			_desenhar_equipe()
		Aba.GANHOS:
			_desenhar_ganhos()
		Aba.LOJA:
			_desenhar_loja()
	desenhar_aviso()


func _cabecalho() -> void:
	grad_v(Rect2(0.0, TOPO, L, 22.0), Color("0f1a13"), FUNDO)
	var ic := Rect2(5.0, TOPO + 4.0, 14.0, 14.0)
	arred(ic, 3.4, VERDE_ESCURO)
	AppCelular.folha(v, ic.get_center(), 5.2, VERDE)
	t(Vector2(22.0, TOPO + 15.5), "i", 10, VERDE, f_bold)
	t(Vector2(22.0 + w("i", 10, f_bold), TOPO + 15.5), "Weed", 10, TINTA, f_bold)
	var saldo := Dinheiro.formatar(Dinheiro.saldo())
	t(Vector2(58.0, TOPO + 14.5), saldo, 7, OURO, f_semi, 40.0, HORIZONTAL_ALIGNMENT_RIGHT)
	var on := IWeed.online()
	var pill := Rect2(L - 42.0, TOPO + 5.5, 37.0, 11.0)
	arred(pill, 5.5, Color(VERDE, 0.16) if on else Color(1, 1, 1, 0.06))
	var pulso := 0.55 + 0.45 * sin(piscar * 4.0) if on else 1.0
	v.draw_circle(pill.position + Vector2(6.0, 5.5), 1.8, Color(VERDE if on else FRACA, pulso))
	t(pill.position + Vector2(10.0, 8.0), "ONLINE" if on else "OFFLINE", 5,
		VERDE if on else FRACA, f_semi, pill.size.x - 12.0, HORIZONTAL_ALIGNMENT_CENTER)


func _abas() -> void:
	var y := TOPO + 22.0
	ret(Rect2(0.0, y, L, 15.0), Color("0d1410"))
	var passo := L / float(NOMES_ABA.size())
	for k in NOMES_ABA.size():
		var c := Vector2(passo * (float(k) + 0.5), y + 7.0)
		var ativo := k == int(_aba)
		var cor := VERDE if ativo else FRACA
		_icone_aba(k, c, cor)
		# Contador de pedidos novos na primeira aba, como badge de app.
		if k == 0:
			var n := IWeed.abertos().size()
			if n > 0:
				v.draw_circle(c + Vector2(5.0, -4.0), 3.2, VERMELHO)
				t(c + Vector2(1.8, -2.0), str(n), 5, Color.WHITE, f_bold, 6.4,
					HORIZONTAL_ALIGNMENT_CENTER)
		if ativo:
			arred(Rect2(c.x - 9.0, y + 13.2, 18.0, 1.6), 0.8, VERDE)
	t(Vector2(7.0, CONTEUDO_Y + 5.0), NOMES_ABA[int(_aba)], 6, FRACA, f_semi)


func _icone_aba(k: int, c: Vector2, cor: Color) -> void:
	var l := 0.7
	match k:
		0:
			v.draw_polyline(PackedVector2Array([c + Vector2(-4, -1), c + Vector2(-4, 3),
				c + Vector2(4, 3), c + Vector2(4, -1)]), cor, l, true)
			v.draw_polyline(PackedVector2Array([c + Vector2(-4, -1), c + Vector2(-1.5, -1),
				c + Vector2(-1, 0.6), c + Vector2(1, 0.6), c + Vector2(1.5, -1),
				c + Vector2(4, -1)]), cor, l, true)
			v.draw_line(c + Vector2(0, -4), c + Vector2(0, -1.5), cor, l, true)
		1:
			var r := Rect2(c - Vector2(4, 3), Vector2(8, 7))
			var pts := AppCelular.cantos(r, 1.0)
			pts.append(pts[0])
			v.draw_polyline(pts, cor, l, true)
			v.draw_line(c + Vector2(-4, -1), c + Vector2(4, -1), cor, l, true)
			v.draw_line(c + Vector2(-2, -4.2), c + Vector2(-2, -2.4), cor, l, true)
			v.draw_line(c + Vector2(2, -4.2), c + Vector2(2, -2.4), cor, l, true)
		2:
			v.draw_arc(c + Vector2(0, -1.6), 1.7, 0, TAU, 14, cor, l, true)
			v.draw_arc(c + Vector2(0, 4.0), 3.4, PI, TAU, 12, cor, l, true)
		3:
			v.draw_arc(c + Vector2(-2.2, -1.6), 1.5, 0, TAU, 12, cor, l, true)
			v.draw_arc(c + Vector2(2.2, -1.6), 1.5, 0, TAU, 12, cor, l, true)
			v.draw_arc(c + Vector2(-2.2, 3.6), 2.6, PI, TAU, 10, cor, l, true)
			v.draw_arc(c + Vector2(2.2, 3.6), 2.6, PI, TAU, 10, cor, l, true)
		4:
			v.draw_arc(c, 3.8, 0, TAU, 18, cor, l, true)
			t(c + Vector2(-3.8, 2.2), "$", 6, cor, f_bold, 7.6, HORIZONTAL_ALIGNMENT_CENTER)
		5:
			# Sacola de compra.
			v.draw_polyline(PackedVector2Array([c + Vector2(-3.6, -1.2), c + Vector2(3.6, -1.2),
				c + Vector2(3.0, 3.6), c + Vector2(-3.0, 3.6), c + Vector2(-3.6, -1.2)]), cor, l, true)
			v.draw_arc(c + Vector2(0, -1.4), 1.8, PI, TAU, 10, cor, l, true)


func _cartao(r: Rect2, sel: bool) -> void:
	arred(r, 3.0, PAINEL_SEL if sel else PAINEL)
	if sel:
		arred(r, 3.0, Color(VERDE, 0.7), false, 0.6)


func _cor_produto(produto: String) -> Color:
	if IWeed.e_variedade(produto):
		# A cor da variedade (a do rotulo e da luz do andar), clareada: no fundo
		# quase preto do app a Chorona e a Morcega sumiam no tom de origem.
		return Variedades.cor(StringName(produto)).lightened(0.3)
	return ROXO if produto == "super" else VERDE


func _rolar(altura: float) -> int:
	var cabem := maxi(1, int((CONTEUDO_FIM - CONTEUDO_Y - 8.0) / altura))
	if _sel < _rol:
		_rol = _sel
	elif _sel >= _rol + cabem:
		_rol = _sel - cabem + 1
	return cabem


func _desenhar_pedidos() -> void:
	if _itens.is_empty():
		var c := Vector2(L * 0.5, 96.0)
		if not IWeed.online():
			v.draw_arc(c, 11.0, 0.9, 5.4, 24, FRACA, 1.2, true)
			t(Vector2(0.0, 122.0), "VOCE ESTA OFFLINE", 8, TINTA, f_semi, L,
				HORIZONTAL_ALIGNMENT_CENTER)
			t(Vector2(0.0, 132.0), "A equipe cuida dos pedidos.", 6, FRACA, f_reg, L,
				HORIZONTAL_ALIGNMENT_CENTER)
			var b := Rect2(L * 0.5 - 34.0, 139.0, 68.0, 14.0)
			arred(b, 7.0, VERDE)
			t(Vector2(b.position.x, b.position.y + 9.8), "FICAR ONLINE", 6, FUNDO, f_bold,
				b.size.x, HORIZONTAL_ALIGNMENT_CENTER)
			rodape([["E", "FICAR ONLINE"], ["A D", "ABAS"]], FUNDO, TINTA, FRACA)
			return
		# Radar procurando: tres aneis crescendo e sumindo.
		for k in 3:
			var f := fmod(piscar * 0.6 + float(k) / 3.0, 1.0)
			v.draw_arc(c, 4.0 + f * 20.0, 0.0, TAU, 32, Color(VERDE, (1.0 - f) * 0.6), 0.8, true)
		AppCelular.folha(v, c, 5.0, VERDE)
		t(Vector2(0.0, 128.0), "PROCURANDO PEDIDOS", 7, TINTA, f_semi, L,
			HORIZONTAL_ALIGNMENT_CENTER)
		var prox := float(WorldState.obter(IWeed.COORD, &"proximo", 0.0))
		t(Vector2(0.0, 138.0), "proximo em ~%s" % IWeed.falta(prox).to_lower(), 6, FRACA,
			f_reg, L, HORIZONTAL_ALIGNMENT_CENTER)
		rodape([["O", "FICAR OFFLINE"], ["A D", "ABAS"]], FUNDO, TINTA, FRACA)
		return
	var alto := 41.0
	var cabem := _rolar(alto)
	var jogador := v.get_tree().get_first_node_in_group(&"player") as Node3D
	for k in range(_rol, mini(_itens.size(), _rol + cabem)):
		var p: Dictionary = _itens[k]
		var r := Rect2(4.0, CONTEUDO_Y + 9.0 + float(k - _rol) * alto, L - 8.0, alto - 3.0)
		var sel := k == _sel
		_cartao(r, sel)
		var id := int(p["cliente"])
		var nome := IWeed.nome_curto(id)
		avatar(r.position + Vector2(10.0, 10.0), 6.0, nome, AppCelular.cor_de(id))
		t(r.position + Vector2(20.0, 12.5), cortar(nome.to_upper(), 7, r.size.x - 62.0, f_semi),
			7, TINTA, f_semi)
		t(Vector2(r.end.x - 44.0, r.position.y + 12.5), Dinheiro.formatar(int(p["preco"])), 8,
			OURO, f_bold, 40.0, HORIZONTAL_ALIGNMENT_RIGHT)
		var produto := String(p["produto"])
		var cp := _cor_produto(produto)
		var cw := chip(r.position + Vector2(20.0, 22.5), "%dx %s" % [int(p["qtd"]),
			IWeed.nome_do_produto(produto)], Color(cp, 0.16), cp, 5)
		t(r.position + Vector2(24.0 + cw, 22.5), "%s - %s" % [IWeed.hora(float(p["inicio"])),
			IWeed.hora(float(p["fim"]))], 6, TINTA)
		var lugar := "%s  %s" % [String(p["lugar"]), String(p.get("rua", ""))]
		if jogador != null:
			var d := Vector2(float(p["x"]) - jogador.global_position.x,
				float(p["z"]) - jogador.global_position.z).length()
			lugar = "%d m  ·  %s" % [roundi(d), lugar.strip_edges()]
		t(r.position + Vector2(6.0, 32.0), cortar(lugar, 6, r.size.x - 52.0), 6, FRACA)
		var expira := float(p["expira"])
		var resta := clampf((expira - IWeed.agora()) / IWeed.PRAZO_ACEITAR, 0.0, 1.0)
		t(Vector2(r.end.x - 46.0, r.position.y + 32.0), "EXPIRA %s" % IWeed.falta(expira), 5,
			LARANJA if resta < 0.4 else FRACA, f_semi, 42.0, HORIZONTAL_ALIGNMENT_RIGHT)
		ret(Rect2(r.position.x + 3.0, r.end.y - 1.6, (r.size.x - 6.0) * resta, 0.8),
			Color(LARANJA if resta < 0.4 else VERDE, 0.8))
	rodape([["E", "ACEITAR"], ["F", "EQUIPE"], ["M", "CONVERSA"]], FUNDO, TINTA, FRACA)


func _desenhar_agenda() -> void:
	var y := CONTEUDO_Y + 9.0
	if _itens.is_empty():
		t(Vector2(0.0, y + 22.0), "NADA COMBINADO", 7, TINTA, f_semi, L,
			HORIZONTAL_ALIGNMENT_CENTER)
		t(Vector2(0.0, y + 32.0), "Aceite um pedido na aba ao lado.", 6, FRACA, f_reg, L,
			HORIZONTAL_ALIGNMENT_CENTER)
		y += 44.0
	else:
		var alto := 33.0
		var cabem := mini(_rolar(alto), 2)
		for k in range(_rol, mini(_itens.size(), _rol + cabem)):
			var p: Dictionary = _itens[k]
			var r := Rect2(4.0, y, L - 8.0, alto - 3.0)
			_cartao(r, k == _sel)
			var inicio := float(p["inicio"])
			t(r.position + Vector2(6.0, 12.0), IWeed.hora(inicio), 9, TINTA, f_bold)
			t(r.position + Vector2(6.0, 20.5), "ate %s" % IWeed.hora(float(p["fim"])), 5, FRACA)
			var nome := IWeed.nome_curto(int(p["cliente"])).to_upper()
			t(r.position + Vector2(38.0, 11.0), cortar(nome, 7, r.size.x - 82.0, f_semi), 7,
				TINTA, f_semi)
			var produto := String(p["produto"])
			var cp := _cor_produto(produto)
			chip(r.position + Vector2(38.0, 21.0), "%dx %s" % [int(p["qtd"]),
				IWeed.nome_do_produto(produto)], Color(cp, 0.16), cp, 5)
			var quem := String(p["quem"])
			var voce := quem == ""
			var rotulo := "VOCE" if voce else IWeed.apelido(int(p["entregador"]))
			var wq := w(rotulo, 5, f_semi) + 6.0
			chip(Vector2(r.end.x - wq - 4.0, r.position.y + 10.0), rotulo,
				Color(OURO if voce else VERDE, 0.18), OURO if voce else VERDE, 5)
			var status := ""
			var cor := FRACA
			var t_abs := IWeed.agora()
			if voce:
				if t_abs < inicio:
					status = "EM %s" % IWeed.falta(inicio)
				else:
					status = "RESTAM %s" % IWeed.falta(float(p["fim"]))
					cor = LARANJA
			elif t_abs < float(p["chega"]):
				status = "CHEGA %s" % IWeed.hora(float(p["chega"]))
				cor = VERDE
			else:
				status = "ENTREGANDO"
				cor = VERDE
			t(Vector2(r.end.x - 54.0, r.position.y + 21.5), status, 5, cor, f_semi, 50.0,
				HORIZONTAL_ALIGNMENT_RIGHT)
			y += alto
		if _itens.size() > cabem:
			t(Vector2(0.0, y + 4.0), "+%d na agenda" % (_itens.size() - cabem), 5, FRACA,
				f_semi, L, HORIZONTAL_ALIGNMENT_CENTER)
			y += 6.0
	# Recentes.
	y += 6.0
	t(Vector2(7.0, y + 4.0), "RECENTES", 5, FRACA, f_semi)
	y += 8.0
	var hist := IWeed.historico()
	for k in mini(hist.size(), int((CONTEUDO_FIM - y) / 12.0)):
		var p: Dictionary = hist[k]
		var estado := String(p["estado"])
		var c := Vector2(10.0, y + 5.0)
		var cor := OURO if estado == "entregue" else (LARANJA if estado == "atrasado" else VERMELHO)
		if estado == "entregue":
			v.draw_polyline(PackedVector2Array([c + Vector2(-2.4, 0), c + Vector2(-0.6, 1.8),
				c + Vector2(2.6, -2.0)]), cor, 0.8, true)
		elif estado == "atrasado":
			t(c + Vector2(-3.0, 2.4), "!", 7, cor, f_bold, 6.0, HORIZONTAL_ALIGNMENT_CENTER)
		else:
			v.draw_line(c + Vector2(-2, -2), c + Vector2(2, 2), cor, 0.8, true)
			v.draw_line(c + Vector2(2, -2), c + Vector2(-2, 2), cor, 0.8, true)
		var quem := "voce" if String(p.get("quem", "")) == "" or int(p.get("entregador", -1)) < 0 \
			else IWeed.apelido(int(p["entregador"])).to_lower()
		t(Vector2(17.0, y + 7.0), cortar("%s  ·  %s" % [IWeed.nome_curto(int(p["cliente"])), quem],
			6, 80.0), 6, TINTA)
		var valor := ""
		match estado:
			"entregue", "atrasado":
				valor = "+" + Dinheiro.formatar(int(p["preco"]))
			"falhou":
				valor = "FALHOU"
			"expirado":
				valor = "EXPIROU"
			"recusado":
				valor = "RECUSADO"
		t(Vector2(L - 50.0, y + 7.0), valor, 6, cor, f_semi, 45.0, HORIZONTAL_ALIGNMENT_RIGHT)
		y += 12.0
	rodape([["E", "GPS"], ["F", "EQUIPE"], ["M", "CONVERSA"]], FUNDO, TINTA, FRACA)


func _desenhar_clientes() -> void:
	if _itens.is_empty():
		t(Vector2(0.0, 100.0), "SEM CLIENTES AINDA", 7, TINTA, f_semi, L,
			HORIZONTAL_ALIGNMENT_CENTER)
		return
	var alto := 27.0
	var cabem := _rolar(alto)
	for k in range(_rol, mini(_itens.size(), _rol + cabem)):
		var c: Dictionary = _itens[k]
		var id := int(c["id"])
		var r := Rect2(4.0, CONTEUDO_Y + 9.0 + float(k - _rol) * alto, L - 8.0, alto - 3.0)
		_cartao(r, k == _sel)
		var nome := IWeed.nome_curto(id)
		avatar(r.position + Vector2(10.0, r.size.y * 0.5), 6.5, nome, AppCelular.cor_de(id))
		var estado := String(c["estado"])
		var fora := estado != "ativo"
		t(r.position + Vector2(21.0, 10.0), cortar(nome.to_upper(), 7, 58.0, f_semi), 7,
			FRACA if fora else TINTA, f_semi)
		var s := float(c["satisfacao"]) / 100.0
		var cor_s := VERDE if s > 0.6 else (LARANJA if s > 0.3 else VERMELHO)
		barra(Rect2(r.end.x - 42.0, r.position.y + 6.0, 30.0, 2.6), s, Color(1, 1, 1, 0.08), cor_s)
		t(Vector2(r.end.x - 11.0, r.position.y + 9.5), "%d" % roundi(s * 100.0), 5, cor_s,
			f_semi, 9.0, HORIZONTAL_ALIGNMENT_RIGHT)
		var sub := "%d PEDIDO%s  ·  %s" % [int(c["pedidos"]), "S" if int(c["pedidos"]) != 1 else "",
			"SUPER" if String(c["gosto"]) == "super" else "MACONHA"]
		t(r.position + Vector2(21.0, 19.0), cortar(sub, 5, 60.0), 5, FRACA, f_semi)
		var tag := ""
		var cor_tag := VERDE
		match estado:
			"explodiu":
				tag = "EXPLODIU"
				cor_tag = VERMELHO
			"orbita":
				tag = "EM ORBITA"
				cor_tag = ROXO
			"x9":
				tag = "X9"
				cor_tag = VERMELHO
			_:
				if bool(c.get("olho", false)):
					tag = "OLHO DE GATO"
		if not tag.is_empty():
			var wt := w(tag, 5, f_semi) + 6.0
			chip(Vector2(r.end.x - wt - 3.0, r.position.y + 19.5), tag, Color(cor_tag, 0.16),
				cor_tag, 5)
	rodape([["E", "PERFIL"], ["A D", "ABAS"]], FUNDO, TINTA, FRACA)


func _desenhar_equipe() -> void:
	var y := CONTEUDO_Y + 9.0
	# Estoque.
	var r0 := Rect2(4.0, y, L - 8.0, 20.0)
	arred(r0, 3.0, PAINEL)
	# As variedades na prateleira: uma bolinha da cor de cada uma e a conta, na
	# linha do titulo, que encurta para caber (as oito em 8 x 12,5 px). So as
	# que tem. Linha a mais embaixo empurrava o Helmer para fora da tela.
	var especiais: Array[String] = IWeed.variedades_pediveis(true)
	t(r0.position + Vector2(6.0, 8.0), "ESTOQUE" if not especiais.is_empty()
		else "ESTOQUE DA ESTUFA", 5, FRACA, f_semi)
	var x := r0.position.x + 36.0
	for produto: String in especiais:
		var cp := _cor_produto(produto)
		v.draw_circle(Vector2(x, r0.position.y + 6.0), 2.0, cp)
		t(Vector2(x + 3.0, r0.position.y + 8.0), "%d" % IWeed.estoque(produto), 5, cp, f_semi)
		x += 12.5
	AppCelular.folha(v, r0.position + Vector2(10.0, 14.5), 3.4, VERDE)
	t(r0.position + Vector2(16.0, 17.0), "MACONHA %d" % IWeed.estoque("maconha"), 6, VERDE, f_semi)
	AppCelular.folha(v, r0.position + Vector2(72.0, 14.5), 3.4, ROXO)
	t(r0.position + Vector2(78.0, 17.0), "SUPER %d" % IWeed.estoque("super"), 6, ROXO, f_semi)
	y += 24.0
	if _itens.is_empty():
		t(Vector2(0.0, y + 20.0), "NINGUEM NA EQUIPE", 7, TINTA, f_semi, L,
			HORIZONTAL_ALIGNMENT_CENTER)
		return
	var alto := 39.0
	var cabem := maxi(1, int((CONTEUDO_FIM - y) / alto))
	if _sel < _rol:
		_rol = _sel
	elif _sel >= _rol + cabem:
		_rol = _sel - cabem + 1
	for k in range(_rol, mini(_itens.size(), _rol + cabem)):
		var id := int(_itens[k])
		var r := Rect2(4.0, y, L - 8.0, alto - 3.0)
		_cartao(r, k == _sel)
		var nome := IWeed.apelido(id)
		avatar(r.position + Vector2(11.0, 11.0), 7.0, nome, AppCelular.cor_de(id))
		t(r.position + Vector2(22.0, 11.0), nome, 8, TINTA, f_bold)
		var cx := r.position.x + 24.0 + w(nome, 8, f_bold)
		var titulos := Profissoes.titulos(id)
		var cabe := cx
		for c: String in titulos:
			cabe += w(c, 5, f_semi) + 8.0
		# Titulo inteiro quando cabe; nome comprido de contratado encolhe para a
		# primeira silaba com ponto, e nao para "FAZE".
		for c: String in titulos:
			var rotulo := c if cabe <= r.end.x - 4.0 else c.substr(0, 3) + "."
			cx += chip(Vector2(cx, r.position.y + 10.5), rotulo, Color(VERDE, 0.14),
				VERDE, 5) + 2.0
		var s := IWeed.situacao(id)
		var fora := bool(s["fora"])
		var cor := LARANJA if fora else VERDE
		v.draw_circle(r.position + Vector2(24.0, 19.0), 1.6,
			Color(cor, 0.6 + 0.4 * sin(piscar * 4.0)))
		t(r.position + Vector2(28.0, 21.0), cortar(String(s["texto"]), 6, r.size.x - 32.0, f_semi),
			6, cor, f_semi)
		var st := IWeed.estatisticas(id)
		var entregas := int(st["entregas"])
		var linha := "%d ENTREGA%s  ·  %d TAREFA%s" % [entregas, "" if entregas == 1 else "S",
			int(st["tarefas"]), "" if int(st["tarefas"]) == 1 else "S"]
		if not String(s.get("quando", "")).is_empty():
			linha = String(s["quando"]) + "  ·  " + linha
		t(r.position + Vector2(24.0, 30.0), cortar(linha, 5, r.size.x - 28.0), 5, FRACA, f_semi)
		y += alto
	rodape([["E", "PERFIL"], ["A D", "ABAS"]], FUNDO, TINTA, FRACA)


func _desenhar_loja() -> void:
	var alto := 30.0
	var cabem := _rolar(alto)
	var saldo := Dinheiro.saldo()
	for k in range(_rol, mini(_itens.size(), _rol + cabem)):
		var d: Dictionary = _itens[k]
		var id := String(d["id"])
		var r := Rect2(4.0, CONTEUDO_Y + 9.0 + float(k - _rol) * alto, L - 8.0, alto - 3.0)
		_cartao(r, k == _sel)
		var custo := IWeed.preco(id)
		var maximo := custo < 0
		var pode := not maximo and saldo >= custo
		t(r.position + Vector2(6.0, 10.5), cortar(String(d["nome"]), 7, r.size.x - 50.0, f_semi), 7,
			TINTA if pode or maximo else FRACA, f_semi)
		t(r.position + Vector2(6.0, 20.0), cortar(String(d["desc"]), 5, r.size.x - 12.0), 5, FRACA,
			f_semi)
		var rotulo := "MAXIMO" if maximo else Dinheiro.formatar(custo)
		t(Vector2(r.end.x - 46.0, r.position.y + 10.5), rotulo, 7,
			VERDE if maximo else (OURO if pode else Color(OURO, 0.4)), f_bold, 42.0,
			HORIZONTAL_ALIGNMENT_RIGHT)
		# Niveis comprados, em pontos, para melhoria de mais de um nivel.
		var precos: Array = d["precos"]
		if not d.has("item") and not bool(d.get("repete", false)) and precos.size() > 1:
			var n := IWeed.nivel(id)
			for q in precos.size():
				v.draw_circle(Vector2(r.end.x - 8.0 - float(precos.size() - 1 - q) * 5.0,
					r.position.y + 19.0), 1.4, VERDE if q < n else Color(1, 1, 1, 0.15))
	rodape([["E", "COMPRAR"], ["A D", "ABAS"]], FUNDO, TINTA, FRACA)


func _desenhar_ganhos() -> void:
	var y := CONTEUDO_Y + 9.0
	var r := Rect2(4.0, y, L - 8.0, 32.0)
	grad_h(r, Color("1a2a1f"), Color("13201a"))
	arred(r, 3.0, Color(OURO, 0.35), false, 0.5)
	t(r.position + Vector2(7.0, 9.0), "SALDO", 5, FRACA, f_semi)
	t(r.position + Vector2(7.0, 25.0), Dinheiro.formatar(Dinheiro.saldo()), 15, OURO, f_bold)
	y += 36.0
	var voce_n := int(WorldState.obter(IWeed.COORD, &"voce_entregas", 0))
	var voce_r := int(WorldState.obter(IWeed.COORD, &"voce_ganho", 0))
	var equipe_n := 0
	for id in IWeed.equipe():
		equipe_n += int(IWeed.estatisticas(id)["entregas"])
	for k in 2:
		var tr := Rect2(4.0 + float(k) * 70.0, y, 68.0, 22.0)
		arred(tr, 3.0, PAINEL)
		t(tr.position + Vector2(5.0, 8.0), "SUAS ENTREGAS" if k == 0 else "DA EQUIPE", 5,
			FRACA, f_semi)
		t(tr.position + Vector2(5.0, 18.0), ("%d  ·  %s" % [voce_n, Dinheiro.formatar(voce_r)])
			if k == 0 else "%d entrega%s" % [equipe_n, "" if equipe_n == 1 else "s"], 6, TINTA, f_semi)
	y += 27.0
	t(Vector2(7.0, y + 3.0), "EXTRATO", 5, FRACA, f_semi)
	y += 7.0
	var ex := Dinheiro.extrato()
	if ex.is_empty():
		t(Vector2(0.0, y + 14.0), "Nenhum movimento ainda.", 6, FRACA, f_reg, L,
			HORIZONTAL_ALIGNMENT_CENTER)
	for k in mini(ex.size(), int((CONTEUDO_FIM - y) / 11.0)):
		var e: Dictionary = ex[k]
		var valor := int(e["valor"])
		var hora := int(e.get("hora", 0))
		t(Vector2(7.0, y + 7.0), ("+" if valor > 0 else "") + Dinheiro.formatar(valor), 6,
			OURO if valor > 0 else VERMELHO, f_semi)
		t(Vector2(44.0, y + 7.0), cortar(String(e["motivo"]), 5, 70.0), 5, FRACA, f_semi)
		t(Vector2(L - 26.0, y + 7.0), "%02d:%02d" % [hora / 60, hora % 60], 5, FRACA, f_reg, 20.0,
			HORIZONTAL_ALIGNMENT_RIGHT)
		y += 11.0
	rodape([["A D", "ABAS"], ["ESC", "SAIR"]], FUNDO, TINTA, FRACA)
