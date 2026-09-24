## Telefone: o teclado de discar, as recentes e a ligacao.
##
## Liga-se para quem esta nos Contatos ou para um numero digitado. Quem trabalha
## para o jogador (a equipe da estufa) atende e responde com uma frase curta; o
## resto da cidade cai na caixa postal — e onze da noite. A tela da ligacao e a
## do iOS 4: o nome grande, o tempo correndo e o botao vermelho de encerrar.
class_name AppTelefone
extends AppIos

enum Aba { RECENTES, TECLADO }
enum Estado { NADA, CHAMANDO, FALANDO, ENCERRADA }

const CHAMA_S := 4.5
const FALA_S := 4.0
const COORD_CHAMADAS := &"chamadas"
const RESPOSTAS := ["Fala, chefe. To no corre, depois te ligo.", "Alo? Ta tudo certo por aqui.",
	"Opa. Pode deixar que eu resolvo.", "To chegando. Dez minutos."]

var aba: Aba = Aba.TECLADO
var _numero: String = ""
var _estado: Estado = Estado.NADA
var _quem: Dictionary = {}
var _t: float = 0.0
var _fala: String = ""
var _toque: float = 0.0


func abrir() -> void:
	if _estado == Estado.NADA:
		aba = Aba.TECLADO
	sel = 0


func digitando() -> bool:
	return aba == Aba.TECLADO and _estado == Estado.NADA


## Liga para a pessoa `id` do registro civil.
func ligar(id: int) -> void:
	_quem = RegistroCivil.identidade(id)
	_numero = _telefone_de(id)
	_chamar()


static func _telefone_de(id: int) -> String:
	var n := posmod(id * 7919 + 1234567, 100000000)
	return "(11) 9%04d-%04d" % [n / 10000, n % 10000]


func _chamar() -> void:
	if _numero.is_empty():
		return
	_estado = Estado.CHAMANDO
	_t = 0.0
	_fala = ""
	_toque = 0.0
	AudioDirector.tocar_ui(&"celular_ok", -12.0, 0.8)
	var lista: Array = (WorldState.obter(Celular.COORD, COORD_CHAMADAS, []) as Array).duplicate()
	lista.push_front({"nome": String(_quem.get("nome", "")), "numero": _numero,
		"hora": SoFundo.hora(), "id": int(_quem.get("id", -1))})
	while lista.size() > 12:
		lista.pop_back()
	WorldState.definir(Celular.COORD, COORD_CHAMADAS, lista)


func _encerrar() -> void:
	_estado = Estado.ENCERRADA
	_t = 0.0
	AudioDirector.tocar_ui(&"clique", -10.0, 0.7)


func processar(delta: float) -> void:
	super.processar(delta)
	if _estado == Estado.NADA:
		return
	_t += delta
	match _estado:
		Estado.CHAMANDO:
			# O tu-tu da chamada: um toque a cada dois segundos.
			_toque -= delta
			if _toque <= 0.0:
				_toque = 2.0
				AudioDirector.tocar_ui(&"clique", -20.0, 0.55)
			if _t >= CHAMA_S:
				_estado = Estado.FALANDO
				_t = 0.0
				var id := int(_quem.get("id", -1))
				if id >= 0 and not Profissoes.titulos(id).is_empty():
					_fala = RESPOSTAS[posmod(id + int(Time.get_ticks_msec() / 1000), RESPOSTAS.size())]
				else:
					_fala = "Caixa postal. Deixe sua mensagem apos o sinal."
		Estado.FALANDO:
			if _t >= FALA_S + float(_fala.length()) * 0.03:
				_encerrar()
		Estado.ENCERRADA:
			if _t >= 1.2:
				_estado = Estado.NADA
				_quem = {}
				_numero = ""


func tecla(ev: InputEventKey) -> bool:
	if not digitando():
		return false
	var c := ev.keycode
	if (c >= KEY_0 and c <= KEY_9) or (c >= KEY_KP_0 and c <= KEY_KP_9):
		_discar(str(c - (KEY_0 if c <= KEY_9 else KEY_KP_0)))
		return true
	if c == KEY_BACKSPACE:
		_numero = _numero.substr(0, maxi(0, _numero.length() - 1))
		return true
	if c == KEY_ENTER or c == KEY_KP_ENTER:
		_quem = {}
		_chamar()
		return true
	return false


func _discar(d: String) -> void:
	if _numero.length() < 14:
		_numero += d
		AudioDirector.tocar_ui(&"celular_tecla", -12.0, 0.9 + 0.02 * float(d.to_int()))


func acao(nome: StringName) -> bool:
	if _estado == Estado.CHAMANDO or _estado == Estado.FALANDO:
		if nome == &"ok" or nome == &"voltar":
			_encerrar()
		return true
	match nome:
		&"esq", &"dir":
			aba = Aba.RECENTES if aba == Aba.TECLADO else Aba.TECLADO
			sel = 0
		&"cima":
			sel = maxi(0, sel - 1)
		&"baixo":
			sel += 1
		&"ok":
			if aba == Aba.TECLADO:
				_quem = {}
				_chamar()
			else:
				var lista: Array = WorldState.obter(Celular.COORD, COORD_CHAMADAS, [])
				if sel < lista.size():
					var c: Dictionary = lista[sel]
					if int(c.get("id", -1)) >= 0:
						ligar(int(c["id"]))
					else:
						_numero = String(c["numero"])
						_chamar()
		&"voltar":
			if aba == Aba.TECLADO and not _numero.is_empty():
				_numero = ""
				return true
			return false
	return true


func tocar(id: Variant) -> bool:
	if super.tocar(id):
		return true
	if not (id is Array):
		return false
	var a: Array = id
	match a[0]:
		&"tecla":
			_discar(String(a[1]))
		&"chamar":
			_quem = {}
			_chamar()
		&"apagar":
			_numero = _numero.substr(0, maxi(0, _numero.length() - 1))
		&"encerrar":
			_encerrar()
		&"aba":
			aba = int(a[1]) as Aba
			sel = 0
		&"recente":
			sel = int(a[1])
			aba = Aba.RECENTES
			acao(&"ok")
	return true


# --- desenho ------------------------------------------------------------------

func desenhar(visor: Control) -> void:
	v = visor
	if _estado != Estado.NADA:
		_ligacao()
		return
	ret(Rect2(0.0, 0.0, L, alto_tela), Color.WHITE)
	if aba == Aba.TECLADO:
		_teclado()
	else:
		_recentes()
		nav("Recentes")
	_abas()


func _teclado() -> void:
	var visor_r := Rect2(0.0, TOPO, L, 30.0)
	grad_v(visor_r, Color("2a2f38"), Color("0e1014"))
	var mostrado := _numero if not _numero.is_empty() else ""
	t(Vector2(0.0, TOPO + 21.0), cortar(mostrado, 14, L - 10.0, f_reg), 14, Color.WHITE, f_reg, L,
		HORIZONTAL_ALIGNMENT_CENTER)
	var teclas := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#"]
	var letras := ["", "ABC", "DEF", "GHI", "JKL", "MNO", "PQRS", "TUV", "WXYZ", "", "+", ""]
	var y0 := TOPO + 30.0
	var alto := 30.0
	var larg := L / 3.0
	for i in teclas.size():
		var r := Rect2(float(i % 3) * larg, y0 + float(i / 3) * alto, larg, alto)
		var cima := Color("e9ebee")
		var baixo := Color("c3c8cf")
		if sob_dedo(r):
			cima = Color("7fb2f5")
			baixo = Color("2f6fd6")
		grad_v(r, cima, baixo)
		v.draw_rect(r, Color("8f969f"), false, 0.4)
		t(Vector2(r.position.x, r.position.y + 17.0), teclas[i], 14, TINTA, f_reg, r.size.x,
			HORIZONTAL_ALIGNMENT_CENTER)
		t(Vector2(r.position.x, r.position.y + 25.0), letras[i], 4, Color("5a616b"), f_semi, r.size.x,
			HORIZONTAL_ALIGNMENT_CENTER)
		alvo(r, [&"tecla", teclas[i]])
	var yb := y0 + 4.0 * alto
	var chamar := Rect2(L / 3.0, yb, L / 3.0 * 2.0, alto_tela - 22.0 - yb)
	grad_v(Rect2(0.0, yb, L, chamar.size.y), Color("3a3f48"), Color("16181c"))
	var verde := Rect2(chamar.position.x + 3.0, yb + 3.0, chamar.size.x * 0.5 - 4.0, chamar.size.y - 6.0)
	grad_v(verde, Color("65d45a"), Color("1e9a2a"))
	arred(verde, 3.0, Color(0, 0, 0, 0.3), false, 0.5)
	CatalogoDeApps._fone(v, verde.get_center(), 7.0, Color.WHITE)
	alvo(verde, [&"chamar"])
	var apagar := Rect2(verde.end.x + 3.0, verde.position.y, verde.size.x, verde.size.y)
	t(Vector2(apagar.position.x, apagar.get_center().y + 3.0), "←", 9, Color(1, 1, 1, 0.8), f_bold,
		apagar.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	alvo(apagar, [&"apagar"])


func _recentes() -> void:
	var lista: Array = WorldState.obter(Celular.COORD, COORD_CHAMADAS, [])
	var y := TOPO + NAV
	sel = mini(sel, maxi(0, lista.size() - 1))
	if lista.is_empty():
		t(Vector2(0.0, y + 50.0), "Nenhuma chamada", 8, Color("9aa1ab"), f_bold, L,
			HORIZONTAL_ALIGNMENT_CENTER)
		return
	for i in mini(lista.size(), 9):
		var c: Dictionary = lista[i]
		var r := Rect2(0.0, y + float(i) * 18.0, L, 18.0)
		var marcada := (foco_visivel and sel == i) or sob_dedo(r)
		if marcada:
			grad_v(r, Color("058cf5"), Color("015de6"))
		var nome := String(c.get("nome", ""))
		nome = nome.capitalize() if not nome.is_empty() else String(c.get("numero", ""))
		t(Vector2(8.0, r.position.y + 11.5), cortar(nome, 7, L - 50.0, f_bold), 7,
			Color.WHITE if marcada else TINTA, f_bold)
		t(Vector2(0.0, r.position.y + 11.5), String(c.get("hora", "")), 6,
			Color.WHITE if marcada else AZUL_IOS, f_reg, L - 8.0, HORIZONTAL_ALIGNMENT_RIGHT)
		ret(Rect2(8.0, r.end.y - 0.4, L - 8.0, 0.4), Color("e0e3e7"))
		alvo(r, [&"recente", i])


func _abas() -> void:
	var r := Rect2(0.0, alto_tela - 22.0, L, 22.0)
	grad_v(Rect2(r.position, Vector2(L, 11.0)), Color("3b3b3d"), Color("1d1d1f"))
	ret(Rect2(0.0, r.position.y + 11.0, L, 11.0), Color("0b0b0c"))
	var nomes := ["Recentes", "Teclado"]
	for i in 2:
		var cel := Rect2(float(i) * L * 0.5, r.position.y, L * 0.5, r.size.y)
		var ativa := i == int(aba)
		if ativa:
			arred(cel.grow(-1.5), 2.0, Color(1, 1, 1, 0.13))
		var cor := Color("4fb2ff") if ativa else Color("9a9aa0")
		var c := cel.get_center() - Vector2(0.0, 3.0)
		if i == 0:
			v.draw_arc(c, 3.5, 0.0, TAU, 16, cor, 1.0, true)
			v.draw_line(c, c + Vector2(0.0, -2.4), cor, 0.8)
			v.draw_line(c, c + Vector2(1.8, 0.0), cor, 0.8)
		else:
			for k in 9:
				v.draw_circle(c + Vector2(float(k % 3 - 1) * 2.6, float(k / 3 - 1) * 2.6), 0.8, cor)
		t(Vector2(cel.position.x, cel.end.y - 2.5), nomes[i], 4, Color.WHITE if ativa else Color("9a9aa0"),
			f_semi, cel.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		alvo(cel, [&"aba", i])


## A tela da ligacao: o fundo escuro com o brilho de vidro, o nome, o tempo e o
## botao vermelho.
func _ligacao() -> void:
	grad_v(Rect2(0.0, 0.0, L, alto_tela), Color("2c3340"), Color("07090c"))
	var topo := Rect2(0.0, TOPO, L, 44.0)
	grad_v(topo, Color(1, 1, 1, 0.14), Color(1, 1, 1, 0.04))
	var nome := String(_quem.get("nome", "")).capitalize()
	if nome.is_empty():
		nome = _numero
	t(Vector2(0.0, TOPO + 18.0), cortar(nome, 10, L - 10.0, f_bold), 10, Color.WHITE, f_bold, L,
		HORIZONTAL_ALIGNMENT_CENTER)
	var estado := ""
	match _estado:
		Estado.CHAMANDO:
			estado = "chamando" + ".".repeat(int(_t * 2.0) % 4)
		Estado.FALANDO:
			estado = "%02d:%02d" % [int(_t) / 60, int(_t) % 60]
		Estado.ENCERRADA:
			estado = "chamada encerrada"
	t(Vector2(0.0, TOPO + 30.0), estado, 6, Color(1, 1, 1, 0.8), f_semi, L, HORIZONTAL_ALIGNMENT_CENTER)
	# Quem atende fala; a frase aparece como legenda no meio.
	if not _fala.is_empty() and _estado != Estado.CHAMANDO:
		var r := Rect2(8.0, 80.0, L - 16.0, 40.0)
		arred(r, 5.0, Color(1, 1, 1, 0.08))
		v.draw_multiline_string(f_reg, Vector2(r.position.x + 6.0, r.position.y + 13.0), "\"%s\"" % _fala,
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 12.0, 7, 3, Color(1, 1, 1, 0.92))
	# Os seis botoes do iOS, apagados, e o encerrar.
	var rotulos := ["mudo", "teclado", "viva-voz", "adicionar", "FaceTime", "contatos"]
	for i in 6:
		var b := Rect2(10.0 + float(i % 3) * 43.0, 128.0 + float(i / 3) * 24.0, 40.0, 21.0)
		arred(b, 3.0, Color(1, 1, 1, 0.1))
		arred(b, 3.0, Color(1, 1, 1, 0.2), false, 0.4)
		t(Vector2(b.position.x, b.position.y + 13.0), rotulos[i], 5, Color(1, 1, 1, 0.55), f_semi,
			b.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var fim := Rect2(10.0, alto_tela - 26.0, L - 20.0, 18.0)
	var cima := Color("f06a5f") if not sob_dedo(fim) else Color("c7473d")
	grad_v(fim, cima, Color("b3261e"))
	arred(fim, 3.5, Color(0, 0, 0, 0.35), false, 0.5)
	t(Vector2(fim.position.x, fim.position.y + 12.0), "Encerrar", 8, Color.WHITE, f_bold, fim.size.x,
		HORIZONTAL_ALIGNMENT_CENTER)
	alvo(fim, [&"encerrar"])
