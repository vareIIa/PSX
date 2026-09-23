## Mensagens, no desenho do iPhone 4/5: a conversa do grupo da viagem.
##
## Por que existe
## --------------
## A cena da estrada tem uma fala — "cheguei a escrever a desculpa no celular.
## Nao mandei." — e ate aqui ela era dita por cima de um retangulo aceso na mao
## dele. Agora a camera mostra o que esta escrito: o grupo da viagem, a ultima
## pergunta sem resposta ("vc vem mesmo ne?"), e no campo de texto a desculpa
## pronta, com o cursor piscando no fim e o ENVIAR aceso. Ele olha, e apaga
## letra por letra. A fala vem depois, e so confirma o que o jogador ja viu.
##
## O desenho
## ---------
## E o Mensagens do iOS 6, que e o que o aparelho do corpo (`fone_corpo.png`)
## lembra: barra de navegacao azul-acinzentada com degrade, balao cinza-claro
## de quem manda e azul com brilho de quem responde, o campo de texto branco e
## arredondado numa faixa cinza, o botao ENVIAR, e o teclado claro embaixo. O
## teclado nao e enfeite: e ele que diz "esta digitando" sem precisar de mao
## nenhuma na tela.
##
## Nao e um app da grade. Na grade o icone MENSAGENS continua sem sinal; este so
## abre pela cena, por `Celular.abrir_conversa_em_cena`.
class_name AppMensagens
extends AppCelular

# --- cores do iOS 6 ---------------------------------------------------------
const FUNDO := Color("dbe2ec")
const NAV_CIMA := Color("b8c5d6")
const NAV_BAIXO := Color("6e84a3")
const NAV_LINHA := Color("2d3f5a")
const BOTAO_NAV := Color("4f6a92")
const BALAO_DELES_CIMA := Color("ffffff")
const BALAO_DELES_BAIXO := Color("e3e3e8")
const BALAO_MEU_CIMA := Color("78b8ff")
const BALAO_MEU_BAIXO := Color("1b78e8")
const TINTA := Color("1a1a1a")
const TINTA_FRACA := Color("7b8594")
const BARRA_CIMA := Color("e9ecf1")
const BARRA_BAIXO := Color("c3c9d3")
const TECLADO := Color("d0d5dd")
const TECLA := Color("fbfbfc")
const TECLA_SOMBRA := Color("8a929e")
const ENVIAR := Color("2f86f5")

## Altura da barra de navegacao, do campo de texto e do teclado.
const NAV := 17.0
const CAMPO_MIN := 16.0
const TECLADO_ALTO := 56.0
## Letras por segundo quando a desculpa esta sendo apagada. Rapido, mas nao de
## uma vez: e o polegar segurando o apagar, e ele acelera.
const APAGA_INICIO := 14.0
const APAGA_FIM := 60.0

var contato: String = ""
## [[autor, texto], ...]. Autor "eu" e dele; qualquer outro e o nome que
## aparece em cima do balao, como no grupo do iOS.
var mensagens: Array = []
var quando: String = ""
var rascunho: String = ""
## Quantas letras do rascunho estao no campo agora.
var _letras: float = 0.0
var _apagando: bool = false


## Poe a conversa no aparelho. Nao anima nada: o rascunho ja esta inteiro no
## campo, porque ele o escreveu antes — a cena comeca com ele olhando para ela.
func preparar(nome: String, lista: Array, hora: String, texto: String) -> void:
	contato = nome
	mensagens = lista
	quando = hora
	rascunho = texto
	_letras = float(texto.length())
	_apagando = false


## Segura o apagar ate o campo esvaziar.
func apagar_rascunho() -> void:
	_apagando = true


func rascunho_vazio() -> bool:
	return _letras <= 0.0


func processar(delta: float) -> void:
	super(delta)
	if _apagando and _letras > 0.0:
		# Acelera: o apagar de telefone repete devagar e depois dispara.
		var feito := 1.0 - _letras / maxf(1.0, float(rascunho.length()))
		_letras = maxf(0.0, _letras - lerpf(APAGA_INICIO, APAGA_FIM, feito) * delta)


func acao(nome: StringName) -> bool:
	return nome != &"voltar"


func desenhar(visor: Control) -> void:
	v = visor
	ret(Rect2(0.0, 0.0, L, A), FUNDO)
	var texto := rascunho.substr(0, int(ceil(_letras)))
	var linhas_campo := _quebrar(texto + "|", 6, L - 44.0)
	var campo := maxf(CAMPO_MIN, 7.0 + float(linhas_campo.size()) * 7.2)
	var y_campo := A - TECLADO_ALTO - campo
	_baloes(TOPO + NAV + 2.0, y_campo - 2.0)
	_navegacao()
	_campo(y_campo, campo, linhas_campo, texto)
	_teclado(A - TECLADO_ALTO)


# --- partes -----------------------------------------------------------------

func _navegacao() -> void:
	grad_v(Rect2(0.0, TOPO, L, NAV), NAV_CIMA, NAV_BAIXO)
	ret(Rect2(0.0, TOPO + NAV - 0.6, L, 0.6), NAV_LINHA)
	# Botao de voltar em forma de seta, como o do iOS 6.
	var b := Rect2(4.0, TOPO + 3.5, 30.0, 10.0)
	var pts := PackedVector2Array([
		Vector2(b.position.x, b.position.y + b.size.y * 0.5),
		Vector2(b.position.x + 5.0, b.position.y),
		Vector2(b.end.x - 1.5, b.position.y),
		Vector2(b.end.x, b.position.y + 1.5),
		Vector2(b.end.x, b.end.y - 1.5),
		Vector2(b.end.x - 1.5, b.end.y),
		Vector2(b.position.x + 5.0, b.end.y)])
	v.draw_colored_polygon(pts, BOTAO_NAV)
	pts.append(pts[0])
	v.draw_polyline(pts, Color(NAV_LINHA, 0.8), 0.5, true)
	t(Vector2(b.position.x + 4.0, b.position.y + 7.4), "Voltar", 5, Color.WHITE,
		f_semi, b.size.x - 4.0, HORIZONTAL_ALIGNMENT_CENTER)
	var nome := cortar(contato, 7, L - 76.0, f_bold)
	# Sombra de um pixel embaixo do titulo: e o relevo de letra do iOS 6.
	t(Vector2(0.0, TOPO + 12.6), nome, 7, Color(0.0, 0.0, 0.0, 0.35), f_bold, L,
		HORIZONTAL_ALIGNMENT_CENTER)
	t(Vector2(0.0, TOPO + 12.0), nome, 7, Color.WHITE, f_bold, L,
		HORIZONTAL_ALIGNMENT_CENTER)
	var e := Rect2(L - 26.0, TOPO + 3.5, 22.0, 10.0)
	arred(e, 2.0, BOTAO_NAV)
	arred(e, 2.0, Color(NAV_LINHA, 0.8), false, 0.5)
	t(Vector2(e.position.x, e.position.y + 7.4), "Editar", 5, Color.WHITE, f_semi,
		e.size.x, HORIZONTAL_ALIGNMENT_CENTER)


## Os baloes, de baixo para cima, a partir do campo de texto.
func _baloes(topo: float, fundo: float) -> void:
	var y := fundo
	for k in range(mensagens.size() - 1, -1, -1):
		var m: Array = mensagens[k]
		var autor := String(m[0])
		var eu := autor == "eu"
		var linhas := _quebrar(String(m[1]), 6, L - 52.0)
		var alto := 4.5 + float(linhas.size()) * 7.2 + 3.0
		var larg := 0.0
		for l: String in linhas:
			larg = maxf(larg, w(l, 6))
		larg += 11.0
		y -= alto
		if not eu:
			y -= 6.5
		if y < topo + 9.0:
			break
		var x := L - 5.0 - larg if eu else 6.0
		var r := Rect2(x, y + (0.0 if eu else 6.5), larg, alto)
		if not eu:
			t(Vector2(x + 5.0, y + 5.0), autor, 5, TINTA_FRACA, f_semi)
		# Sombra, corpo com degrade e brilho em cima: o balao do iOS 6 e um
		# objeto, e nao uma etiqueta chapada.
		arred(Rect2(r.position + Vector2(0.0, 0.6), r.size), 5.0, Color(0, 0, 0, 0.18))
		_balao(r, BALAO_MEU_CIMA if eu else BALAO_DELES_CIMA,
			BALAO_MEU_BAIXO if eu else BALAO_DELES_BAIXO)
		arred(Rect2(r.position.x + 2.0, r.position.y + 1.0, r.size.x - 4.0,
			minf(4.0, r.size.y * 0.35)), 2.0, Color(1, 1, 1, 0.28 if eu else 0.6))
		for q in linhas.size():
			t(Vector2(r.position.x + 5.5, r.position.y + 8.6 + float(q) * 7.2), linhas[q],
				6, Color.WHITE if eu else TINTA)
		y -= 3.0
	# A hora da conversa, centrada, acima de tudo que coube.
	if not quando.is_empty():
		t(Vector2(0.0, maxf(topo + 6.0, y - 1.0)), quando, 5, TINTA_FRACA, f_semi, L,
			HORIZONTAL_ALIGNMENT_CENTER)


## Um balao com degrade vertical dentro do contorno arredondado.
func _balao(r: Rect2, cima: Color, baixo: Color) -> void:
	var pts := AppCelular.cantos(r, 5.0)
	var cores := PackedColorArray()
	for p: Vector2 in pts:
		cores.append(cima.lerp(baixo, clampf((p.y - r.position.y) / r.size.y, 0.0, 1.0)))
	v.draw_polygon(pts, cores)


func _campo(y: float, alto: float, linhas: Array[String], texto: String) -> void:
	grad_v(Rect2(0.0, y, L, alto), BARRA_CIMA, BARRA_BAIXO)
	ret(Rect2(0.0, y, L, 0.5), Color("9aa3b0"))
	var caixa := Rect2(5.0, y + 3.0, L - 40.0, alto - 6.0)
	arred(caixa, 4.0, Color.WHITE)
	arred(caixa, 4.0, Color("8c95a3"), false, 0.5)
	# O cursor pisca e fica no fim do texto: a barra que `_quebrar` recebeu
	# entra no desenho so metade do tempo.
	var cursor := fmod(piscar, 1.0) < 0.55
	for q in linhas.size():
		var linha: String = linhas[q]
		var ultima := q == linhas.size() - 1
		if ultima:
			linha = linha.trim_suffix("|")
		t(Vector2(caixa.position.x + 4.0, caixa.position.y + 7.2 + float(q) * 7.2),
			linha, 6, TINTA)
		if ultima and cursor:
			var x := caixa.position.x + 4.0 + w(linha, 6) + 0.6
			ret(Rect2(x, caixa.position.y + 2.2 + float(q) * 7.2, 0.8, 6.4), ENVIAR)
	# ENVIAR: azul com texto, apagado quando nao ha o que mandar.
	var b := Rect2(L - 32.0, y + alto - 13.0, 28.0, 10.0)
	var ativo := not texto.is_empty()
	grad_v(b, ENVIAR.lightened(0.25) if ativo else Color("c9ced6"),
		ENVIAR if ativo else Color("aeb5c0"))
	arred(b, 3.0, Color("27509a") if ativo else Color("8c95a3"), false, 0.5)
	t(Vector2(b.position.x, b.position.y + 7.3), "Enviar", 5,
		Color.WHITE if ativo else Color("eef1f5"), f_bold, b.size.x,
		HORIZONTAL_ALIGNMENT_CENTER)


## O teclado claro do iOS 6: tres fileiras de letras e a barra de espaco.
func _teclado(y: float) -> void:
	grad_v(Rect2(0.0, y, L, TECLADO_ALTO), Color("dde1e7"), Color("b9bfc8"))
	var fileiras := ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
	var passo := (L - 4.0) / 10.0
	var tecla_l := passo - 1.6
	var tecla_a := 11.0
	for f in fileiras.size():
		var letras: String = fileiras[f]
		var yy := y + 3.0 + float(f) * (tecla_a + 2.2)
		var x0 := 2.0 + (L - 4.0 - passo * float(letras.length())) * 0.5
		for i in letras.length():
			var r := Rect2(x0 + float(i) * passo + 0.8, yy, tecla_l, tecla_a)
			# A tecla de apagar acende enquanto ele segura.
			arred(Rect2(r.position + Vector2(0.0, 0.7), r.size), 1.6, TECLA_SOMBRA)
			arred(r, 1.6, TECLA)
			t(Vector2(r.position.x, r.position.y + 7.6), letras[i], 6, TINTA,
				f_reg, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		if f == 2:
			# Shift e apagar nas pontas da ultima fileira.
			var sh := Rect2(2.0, yy, passo * 1.3, tecla_a)
			arred(Rect2(sh.position + Vector2(0.0, 0.7), sh.size), 1.6, TECLA_SOMBRA)
			arred(sh, 1.6, Color("aab2be"))
			var ap := Rect2(L - 2.0 - passo * 1.3, yy, passo * 1.3, tecla_a)
			arred(Rect2(ap.position + Vector2(0.0, 0.7), ap.size), 1.6, TECLA_SOMBRA)
			arred(ap, 1.6, ENVIAR if _apagando and _letras > 0.0 else Color("aab2be"))
			v.draw_polyline(PackedVector2Array([
				Vector2(ap.position.x + 3.0, ap.position.y + 5.5),
				Vector2(ap.position.x + 5.5, ap.position.y + 3.0),
				Vector2(ap.end.x - 3.0, ap.position.y + 3.0),
				Vector2(ap.end.x - 3.0, ap.end.y - 3.0),
				Vector2(ap.position.x + 5.5, ap.end.y - 3.0),
				Vector2(ap.position.x + 3.0, ap.position.y + 5.5)]),
				Color.WHITE, 0.6, true)
	var yb := y + 3.0 + 3.0 * (tecla_a + 2.2)
	var num := Rect2(2.0, yb, passo * 2.2, tecla_a)
	arred(num, 1.6, Color("aab2be"))
	t(Vector2(num.position.x, num.position.y + 7.6), "123", 5, TINTA, f_semi,
		num.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var espaco := Rect2(num.end.x + 1.6, yb, L - 4.0 - num.size.x * 2.0 - 3.2, tecla_a)
	arred(Rect2(espaco.position + Vector2(0.0, 0.7), espaco.size), 1.6, TECLA_SOMBRA)
	arred(espaco, 1.6, TECLA)
	t(Vector2(espaco.position.x, espaco.position.y + 7.6), "espaço", 5, TINTA_FRACA,
		f_semi, espaco.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var ok := Rect2(espaco.end.x + 1.6, yb, num.size.x, tecla_a)
	arred(ok, 1.6, Color("aab2be"))
	t(Vector2(ok.position.x, ok.position.y + 7.6), "OK", 5, TINTA, f_semi,
		ok.size.x, HORIZONTAL_ALIGNMENT_CENTER)


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
	if not linha.is_empty() or saida.is_empty():
		saida.append(linha)
	return saida
