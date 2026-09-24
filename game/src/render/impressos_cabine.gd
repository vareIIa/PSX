## A arte impressa do interior: mostradores, luzes-espia, escalas do ar,
## serigrafia do radio e a grade do cambio, numa folha so.
##
## Por que uma folha assada, e nao celula do painel_atlas
## ------------------------------------------------------
## O velocimetro do painel_atlas e uma celula de 128 px pintada a mao para
## 480x270: em 4K, com o mostrador ocupando 400 px da tela, os numeros eram
## quatro pixels borrados. Aqui tudo e desenhado com a fonte do Godot em 2048 x
## 1024 e gravado em `FOLHA`, importada COM mipmaps — nitido de perto e sem
## cintilar a 480x270.
##
## A folha e assada, e nao desenhada em jogo, porque o `SubViewport` que a
## desenharia so renderiza com GPU de verdade (em `--headless` a cabine sairia
## sem mostrador) e custaria uma leitura de volta da GPU para ganhar mipmap.
##
##     godot --path game --script res://tests/assar_impressos_cabine.gd
##
## Formato
## -------
## RGBA: rgb e a cor da tinta, alfa e a cobertura. O shader poe a tinta por cima
## da cor da peca (`CabineMateriais.impresso`) e acende o que e claro quando o
## painel acende. Um mostrador e tinta ate a borda (o fundo preto dele tambem e
## tinta); a escala do botao do ar e so o anel, o resto e transparente e deixa o
## plastico aparecer.
class_name ImpressosCabine
extends RefCounted

const FOLHA := "res://assets/textures/cabine_impressos.png"
const TAMANHO := Vector2i(2048, 1024)

# --- regioes da folha, em pixels --------------------------------------------

const R_VELOCIMETRO := Rect2(0, 0, 512, 512)
const R_CONTA_GIROS := Rect2(512, 0, 512, 512)
const R_COMBUSTIVEL := Rect2(1024, 0, 256, 256)
const R_TEMPERATURA := Rect2(1280, 0, 256, 256)
const R_VENTILADOR := Rect2(1536, 0, 256, 256)
const R_AR_TEMPERATURA := Rect2(1792, 0, 256, 256)
const R_AR_DIRECAO := Rect2(1536, 256, 256, 256)
const R_CAMBIO := Rect2(1792, 256, 256, 256)
## Serigrafia do toca-fitas, na proporcao da frente dele (178 x 50 mm).
const R_RADIO := Rect2(0, 512, 1024, 288)
## A mesma serigrafia para a faixa do ar, embaixo do radio (178 x 30 mm).
const R_PLACA_AR := Rect2(1024, 512, 1024, 172)

## Luzes-espia: oito icones de 128 px, em duas fileiras de quatro.
const ESPIA_ORIGEM := Vector2(1024, 256)
const ESPIA_LADO := 128.0
enum Espia {SETA_ESQ, SETA_DIR, FAROL_ALTO, FREIO, BATERIA, OLEO, CINTO, MOTOR}

## Icones de botao (pisca-alerta, desembacador, neblina, luz do painel), quatro
## de 128 px numa fileira.
const BOTAO_ORIGEM := Vector2(0, 800)
enum Botao {ALERTA, DESEMBACADOR, NEBLINA, LANTERNA}

# --- escalas ----------------------------------------------------------------
# Os ponteiros 3D giram pelas mesmas contas, entao elas moram aqui e nao na
# cabine: um risco pintado num angulo e o ponteiro chegando noutro e o defeito
# mais visivel que um painel pode ter.

## Angulo do zero e varredura, em graus, no sentido da matematica (0 as tres
## horas, anti-horario) visto do motorista.
const ARCO_ZERO := 225.0
const ARCO := 270.0
const VEL_FUNDO := 200.0
const GIRO_FUNDO := 8000.0
const GIRO_VERMELHO := 6500.0
## Os pequenos: um quarto de volta em cima, de "vazio" (esquerda) a "cheio".
const PEQ_ZERO := 135.0
const PEQ_ARCO := 90.0

const TINTA := Color(0.93, 0.92, 0.88)
const TINTA_APAGADA := Color(0.62, 0.62, 0.60)
const VERMELHO := Color(0.92, 0.16, 0.10)
const FUNDO_MOSTRADOR := Color(0.028, 0.028, 0.032)


## Angulo do ponteiro do velocimetro, em radianos, para `kmh`.
static func angulo_velocidade(kmh: float) -> float:
	return deg_to_rad(ARCO_ZERO - ARCO * clampf(kmh / VEL_FUNDO, 0.0, 1.0))


static func angulo_giro(rpm: float) -> float:
	return deg_to_rad(ARCO_ZERO - ARCO * clampf(rpm / GIRO_FUNDO, 0.0, 1.0))


## Para combustivel e temperatura: `t` de 0 (vazio/frio) a 1 (cheio/quente).
static func angulo_pequeno(t: float) -> float:
	return deg_to_rad(PEQ_ZERO - PEQ_ARCO * clampf(t, 0.0, 1.0))


## A regiao de uma luz-espia, em pixels.
static func regiao_espia(qual: int) -> Rect2:
	return Rect2(ESPIA_ORIGEM + Vector2(float(qual % 4), float(qual / 4)) * ESPIA_LADO,
		Vector2.ONE * ESPIA_LADO)


static func regiao_botao(qual: int) -> Rect2:
	return Rect2(BOTAO_ORIGEM + Vector2(float(qual) * 128.0, 0.0), Vector2(128, 128))


## Uma regiao em UV da folha (0..1).
static func uv(r: Rect2) -> Rect2:
	var t := Vector2(TAMANHO)
	return Rect2(r.position / t, r.size / t)


# --- desenho ----------------------------------------------------------------

## Desenha a folha inteira em `ci`. Chamado pelo assador, dentro do `_draw` de
## um Control do tamanho de `TAMANHO`.
static func desenhar(ci: CanvasItem) -> void:
	var f := _fonte(false)
	var fn := _fonte(true)
	_velocimetro(ci, R_VELOCIMETRO, fn, f)
	_conta_giros(ci, R_CONTA_GIROS, fn, f)
	_pequeno(ci, R_COMBUSTIVEL, "0", "1/1", f, true)
	_pequeno(ci, R_TEMPERATURA, "C", "H", f, false)
	_escala_ventilador(ci, R_VENTILADOR, fn)
	_escala_ar_temperatura(ci, R_AR_TEMPERATURA)
	_escala_direcao(ci, R_AR_DIRECAO)
	_grade_cambio(ci, R_CAMBIO, fn)
	for k in 8:
		_espia(ci, regiao_espia(k), k)
	for k in 4:
		_botao(ci, regiao_botao(k), k)
	_serigrafia_radio(ci, R_RADIO, f, fn)
	_serigrafia_ar(ci, R_PLACA_AR, f)


static func _fonte(negrito: bool) -> Font:
	var base := ThemeDB.fallback_font
	var v := FontVariation.new()
	v.base_font = base
	if negrito:
		v.variation_embolden = 0.9
	# Condensada, como a tipografia DIN dos paineis da epoca.
	v.variation_transform = Transform2D(Vector2(0.86, 0.0), Vector2(0.0, 1.0),
		Vector2.ZERO)
	return v


static func _texto(ci: CanvasItem, f: Font, centro: Vector2, s: String,
		tam: int, cor: Color) -> void:
	var larg := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam)
	var asc := f.get_ascent(tam)
	var desc := f.get_descent(tam)
	ci.draw_string(f, centro + Vector2(-larg.x * 0.5, (asc - desc) * 0.5 - 1.0), s,
		HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor)


static func _ponto(c: Vector2, r: float, graus: float) -> Vector2:
	var a := deg_to_rad(graus)
	return c + Vector2(cos(a), -sin(a)) * r


static func _risco(ci: CanvasItem, c: Vector2, r0: float, r1: float,
		graus: float, largura: float, cor: Color) -> void:
	ci.draw_line(_ponto(c, r0, graus), _ponto(c, r1, graus), cor, largura, true)


## O fundo de mostrador: disco preto com um degrade quase imperceptivel, que e
## o que tira o "recorte de cartolina" da face.
static func _fundo(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c, r, FUNDO_MOSTRADOR)
	for k in 12:
		var t := float(k) / 12.0
		ci.draw_circle(c, r * (1.0 - t * 0.55),
			Color(0.05, 0.05, 0.056, 0.10))
	# Um filete fino a 4 px da borda: o aro pintado dos mostradores Veglia.
	ci.draw_arc(c, r - 10.0, 0.0, TAU, 128, Color(0.30, 0.30, 0.31), 2.0, true)


static func _velocimetro(ci: CanvasItem, r: Rect2, fn: Font, f: Font) -> void:
	var c := r.get_center()
	var raio := r.size.x * 0.5 - 4.0
	_fundo(ci, c, raio)
	var v := 0
	while v <= int(VEL_FUNDO):
		var g := ARCO_ZERO - ARCO * float(v) / VEL_FUNDO
		if v % 20 == 0:
			_risco(ci, c, raio - 58.0, raio - 20.0, g, 6.0, TINTA)
			_texto(ci, fn, _ponto(c, raio - 90.0, g), str(v), 34, TINTA)
		elif v % 10 == 0:
			_risco(ci, c, raio - 46.0, raio - 20.0, g, 4.0, TINTA)
		else:
			_risco(ci, c, raio - 36.0, raio - 20.0, g, 2.5, TINTA_APAGADA)
		v += 5
	_texto(ci, f, c + Vector2(0, -86), "km/h", 30, TINTA_APAGADA)
	# Hodometro de tambor: seis algarismos brancos em janelas pretas, o ultimo
	# invertido, que e o das centenas de metro.
	var digitos := "087432"
	var larg := 22.0
	var x0 := c.x - larg * 3.0
	var y0 := c.y + 150.0
	ci.draw_rect(Rect2(x0 - 5, y0 - 5, larg * 6 + 10, 44), Color(0.16, 0.16, 0.17))
	for k in 6:
		var caixa := Rect2(x0 + larg * k + 2, y0, larg - 4, 34)
		var ultimo := k == 5
		ci.draw_rect(caixa, TINTA if ultimo else Color(0.01, 0.01, 0.012))
		_texto(ci, fn, caixa.get_center(), digitos[k], 26,
			Color(0.02, 0.02, 0.02) if ultimo else TINTA)


static func _conta_giros(ci: CanvasItem, r: Rect2, fn: Font, f: Font) -> void:
	var c := r.get_center()
	var raio := r.size.x * 0.5 - 4.0
	_fundo(ci, c, raio)
	# A faixa vermelha por baixo dos riscos, do limite ao fundo.
	var g0 := ARCO_ZERO - ARCO * GIRO_VERMELHO / GIRO_FUNDO
	var g1 := ARCO_ZERO - ARCO
	ci.draw_arc(c, raio - 30.0, deg_to_rad(-g0), deg_to_rad(-g1), 48, VERMELHO,
		20.0, true)
	var rpm := 0
	while rpm <= int(GIRO_FUNDO):
		var g := ARCO_ZERO - ARCO * float(rpm) / GIRO_FUNDO
		var cor := VERMELHO if rpm >= int(GIRO_VERMELHO) else TINTA
		if rpm % 1000 == 0:
			_risco(ci, c, raio - 58.0, raio - 20.0, g, 6.0, cor)
			_texto(ci, fn, _ponto(c, raio - 92.0, g), str(rpm / 1000), 44, cor)
		elif rpm % 500 == 0:
			_risco(ci, c, raio - 46.0, raio - 20.0, g, 4.0, cor)
		else:
			_risco(ci, c, raio - 34.0, raio - 20.0, g, 2.5,
				VERMELHO if rpm >= int(GIRO_VERMELHO) else TINTA_APAGADA)
		rpm += 250
	_texto(ci, f, c + Vector2(0, -86), "x1000", 28, TINTA_APAGADA)
	_texto(ci, f, c + Vector2(0, -56), "rpm", 26, TINTA_APAGADA)
	# O relogio analogico das versoes de luxo nao cabe; fica a marca do fabricante
	# do instrumento, que era o que se lia no rodape de todo conta-giros.
	_texto(ci, f, c + Vector2(0, 120), "VDO", 24, Color(0.40, 0.40, 0.40))


static func _pequeno(ci: CanvasItem, r: Rect2, vazio: String, cheio: String,
		f: Font, combustivel: bool) -> void:
	var c := r.get_center()
	var raio := r.size.x * 0.5 - 3.0
	_fundo(ci, c, raio)
	for k in 9:
		var t := float(k) / 8.0
		var g := PEQ_ZERO - PEQ_ARCO * t
		var perigo := (t <= 0.125) if combustivel else (t >= 0.875)
		var cor := VERMELHO if perigo else TINTA
		var grande := k % 4 == 0
		_risco(ci, c, raio - (38.0 if grande else 28.0), raio - 12.0, g,
			5.0 if grande else 3.0, cor)
	_texto(ci, f, _ponto(c, raio - 58.0, PEQ_ZERO - 4.0), vazio, 24,
		VERMELHO if combustivel else TINTA)
	_texto(ci, f, _ponto(c, raio - 58.0, PEQ_ZERO - PEQ_ARCO + 4.0), cheio, 24,
		TINTA if combustivel else VERMELHO)
	if combustivel:
		_bomba(ci, c + Vector2(0, 40), 1.0, TINTA_APAGADA)
	else:
		_termometro(ci, c + Vector2(0, 40), 1.0, TINTA_APAGADA)


static func _bomba(ci: CanvasItem, c: Vector2, s: float, cor: Color) -> void:
	ci.draw_rect(Rect2(c + Vector2(-14, -20) * s, Vector2(20, 36) * s), cor)
	ci.draw_rect(Rect2(c + Vector2(-10, -15) * s, Vector2(12, 9) * s),
		FUNDO_MOSTRADOR)
	ci.draw_polyline(PackedVector2Array([c + Vector2(6, -12) * s,
		c + Vector2(14, -6) * s, c + Vector2(14, 10) * s,
		c + Vector2(18, 10) * s, c + Vector2(18, -10) * s]), cor, 3.0 * s, true)


static func _termometro(ci: CanvasItem, c: Vector2, s: float, cor: Color) -> void:
	ci.draw_line(c + Vector2(0, -22) * s, c + Vector2(0, 6) * s, cor, 6.0 * s, true)
	ci.draw_circle(c + Vector2(0, 10) * s, 8.0 * s, cor)
	for k in 3:
		ci.draw_line(c + Vector2(4, -18 + k * 8) * s, c + Vector2(12, -18 + k * 8) * s,
			cor, 3.0 * s, true)
	# As ondas da agua do radiador embaixo.
	for k in 2:
		var y := 24.0 + k * 7.0
		var pts := PackedVector2Array()
		for i in 9:
			var x := -20.0 + i * 5.0
			pts.append(c + Vector2(x, y + sin(i * 1.6) * 2.5) * s)
		ci.draw_polyline(pts, cor, 2.5 * s, true)


## A escala do ventilador: 0 a 4 em volta do botao, e o icone da ventoinha.
static func _escala_ventilador(ci: CanvasItem, r: Rect2, fn: Font) -> void:
	var c := r.get_center()
	for k in 5:
		var g := 225.0 - 67.5 * float(k)
		_texto(ci, fn, _ponto(c, 104.0, g), str(k), 30, TINTA)
		_risco(ci, c, 80.0, 90.0, g, 4.0, TINTA)
	_ventoinha(ci, c + Vector2(0, 96), 0.8, TINTA)


static func _ventoinha(ci: CanvasItem, c: Vector2, s: float, cor: Color) -> void:
	for k in 3:
		var a := TAU * float(k) / 3.0
		var pts := PackedVector2Array()
		for i in 7:
			var t := float(i) / 6.0
			var ang := a + t * 1.2
			pts.append(c + Vector2(cos(ang), sin(ang)) * (4.0 + 16.0 * sin(t * PI)) * s)
		pts.append(c)
		ci.draw_colored_polygon(pts, cor)
	ci.draw_circle(c, 4.0 * s, cor)


## A escala de temperatura do ar: o degrade de azul a vermelho em arco.
static func _escala_ar_temperatura(ci: CanvasItem, r: Rect2) -> void:
	var c := r.get_center()
	var n := 36
	for k in n:
		var t0 := float(k) / float(n)
		var t1 := float(k + 1) / float(n)
		var cor := Color(0.18, 0.42, 0.92).lerp(Color(0.92, 0.18, 0.10), t0)
		var g0 := 225.0 - 270.0 * t0
		var g1 := 225.0 - 270.0 * t1
		ci.draw_arc(c, 90.0, deg_to_rad(-g0), deg_to_rad(-g1), 4, cor, 12.0 + 8.0 * t0,
			true)
	_termometro(ci, c + Vector2(0, 94), 0.7, TINTA)


## A direcao do ar: rosto, rosto e pes, pes, pes e para-brisa, para-brisa.
static func _escala_direcao(ci: CanvasItem, r: Rect2) -> void:
	var c := r.get_center()
	for k in 5:
		var g := 225.0 - 67.5 * float(k)
		var p := _ponto(c, 102.0, g)
		_risco(ci, c, 70.0, 80.0, g, 4.0, TINTA)
		_boneco(ci, p, k)


static func _boneco(ci: CanvasItem, p: Vector2, modo: int) -> void:
	var s := 0.85
	# Cabeca e corpo sentado, de perfil.
	ci.draw_circle(p + Vector2(-6, -18) * s, 6.0 * s, TINTA)
	ci.draw_polyline(PackedVector2Array([p + Vector2(-8, -10) * s,
		p + Vector2(-10, 8) * s, p + Vector2(6, 8) * s, p + Vector2(8, 22) * s]),
		TINTA, 4.0 * s, true)
	var setas: Array = []
	if modo <= 1:
		setas.append([p + Vector2(22, -16) * s, p + Vector2(4, -14) * s])
	if modo >= 1 and modo <= 3:
		setas.append([p + Vector2(24, 18) * s, p + Vector2(10, 20) * s])
	if modo >= 3:
		ci.draw_line(p + Vector2(14, -34) * s, p + Vector2(26, -12) * s, TINTA,
			4.0 * s, true)
		setas.append([p + Vector2(12, -2) * s, p + Vector2(20, -24) * s])
	for par: Array in setas:
		var a: Vector2 = par[0]
		var b: Vector2 = par[1]
		ci.draw_line(a, b, TINTA, 3.0 * s, true)
		var d := (b - a).normalized()
		var l := Vector2(-d.y, d.x)
		ci.draw_colored_polygon(PackedVector2Array([b + d * 6.0 * s,
			b - d * 2.0 * s + l * 5.0 * s, b - d * 2.0 * s - l * 5.0 * s]), TINTA)


## O topo do pomo do cambio: a grade em H das cinco marchas e a re.
static func _grade_cambio(ci: CanvasItem, r: Rect2, fn: Font) -> void:
	var c := r.get_center()
	var cor := TINTA
	var l := 7.0
	ci.draw_line(c + Vector2(-60, 0), c + Vector2(60, 0), cor, l, true)
	for x: float in [-60.0, 0.0, 60.0]:
		ci.draw_line(c + Vector2(x, -46), c + Vector2(x, 46), cor, l, true)
	_texto(ci, fn, c + Vector2(-60, -74), "1", 34, cor)
	_texto(ci, fn, c + Vector2(-60, 76), "2", 34, cor)
	_texto(ci, fn, c + Vector2(0, -74), "3", 34, cor)
	_texto(ci, fn, c + Vector2(0, 76), "4", 34, cor)
	_texto(ci, fn, c + Vector2(60, -74), "5", 34, cor)
	_texto(ci, fn, c + Vector2(60, 76), "R", 34, cor)


static func _espia(ci: CanvasItem, r: Rect2, qual: int) -> void:
	var c := r.get_center()
	var cor := Color.WHITE
	match qual:
		Espia.SETA_ESQ, Espia.SETA_DIR:
			var s := -1.0 if qual == Espia.SETA_ESQ else 1.0
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(40 * s, 0), c + Vector2(4 * s, -34), c + Vector2(4 * s, -14),
				c + Vector2(-36 * s, -14), c + Vector2(-36 * s, 14),
				c + Vector2(4 * s, 14), c + Vector2(4 * s, 34)]), cor)
		Espia.FAROL_ALTO:
			var pts := PackedVector2Array()
			for k in 17:
				var a := -PI * 0.5 + PI * float(k) / 16.0
				pts.append(c + Vector2(-8, 0) + Vector2(cos(a) * 30, sin(a) * 30))
			ci.draw_colored_polygon(pts, cor)
			for k in 5:
				var y := -24.0 + 12.0 * k
				ci.draw_line(c + Vector2(-16, y), c + Vector2(-44, y), cor, 6.0, true)
		Espia.FREIO:
			ci.draw_arc(c, 34.0, 0.0, TAU, 48, cor, 7.0, true)
			ci.draw_arc(c, 46.0, deg_to_rad(125), deg_to_rad(235), 16, cor, 6.0, true)
			ci.draw_arc(c, 46.0, deg_to_rad(-55), deg_to_rad(55), 16, cor, 6.0, true)
			ci.draw_line(c + Vector2(0, -20), c + Vector2(0, 8), cor, 8.0, true)
			ci.draw_circle(c + Vector2(0, 20), 5.0, cor)
		Espia.BATERIA:
			ci.draw_rect(Rect2(c + Vector2(-40, -22), Vector2(80, 50)), cor, false, 7.0)
			ci.draw_rect(Rect2(c + Vector2(-30, -32), Vector2(14, 10)), cor)
			ci.draw_rect(Rect2(c + Vector2(16, -32), Vector2(14, 10)), cor)
			ci.draw_line(c + Vector2(-28, 2), c + Vector2(-12, 2), cor, 6.0)
			ci.draw_line(c + Vector2(12, 2), c + Vector2(28, 2), cor, 6.0)
			ci.draw_line(c + Vector2(20, -6), c + Vector2(20, 10), cor, 6.0)
		Espia.OLEO:
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-40, -6), c + Vector2(10, -6), c + Vector2(40, -20),
				c + Vector2(20, 18), c + Vector2(-40, 18)]), cor)
			ci.draw_line(c + Vector2(-26, -6), c + Vector2(-26, -18), cor, 6.0)
			ci.draw_circle(c + Vector2(44, 6), 5.0, cor)
		Espia.CINTO:
			ci.draw_circle(c + Vector2(-6, -30), 9.0, cor)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-14, -16),
				c + Vector2(-20, 20), c + Vector2(14, 20), c + Vector2(20, 40)]),
				cor, 8.0, true)
			ci.draw_line(c + Vector2(-2, -20), c + Vector2(-26, 14), cor, 5.0, true)
		Espia.MOTOR:
			ci.draw_rect(Rect2(c + Vector2(-34, -18), Vector2(60, 40)), cor, false, 7.0)
			ci.draw_rect(Rect2(c + Vector2(-20, -30), Vector2(26, 10)), cor)
			ci.draw_line(c + Vector2(26, -2), c + Vector2(42, -2), cor, 6.0)
			ci.draw_line(c + Vector2(42, -14), c + Vector2(42, 12), cor, 6.0)
			ci.draw_line(c + Vector2(-34, 2), c + Vector2(-46, 2), cor, 6.0)


static func _botao(ci: CanvasItem, r: Rect2, qual: int) -> void:
	var c := r.get_center()
	match qual:
		Botao.ALERTA:
			# O triangulo vermelho duplo do pisca-alerta.
			var t := PackedVector2Array()
			for k in 3:
				var a := -PI * 0.5 + TAU * float(k) / 3.0
				t.append(c + Vector2(cos(a), sin(a)) * 46.0 + Vector2(0, 6))
			t.append(t[0])
			ci.draw_polyline(t, VERMELHO, 12.0, true)
			var u := PackedVector2Array()
			for k in 3:
				var a := -PI * 0.5 + TAU * float(k) / 3.0
				u.append(c + Vector2(cos(a), sin(a)) * 20.0 + Vector2(0, 6))
			u.append(u[0])
			ci.draw_polyline(u, VERMELHO, 7.0, true)
		Botao.DESEMBACADOR:
			ci.draw_rect(Rect2(c + Vector2(-38, -26), Vector2(76, 52)), TINTA, false, 6.0)
			for k in 3:
				var x := -18.0 + 18.0 * k
				var pts := PackedVector2Array()
				for i in 7:
					pts.append(c + Vector2(x + sin(i * 1.3) * 5.0, 18.0 - 6.0 * i))
				ci.draw_polyline(pts, Color(1.0, 0.62, 0.15), 4.0, true)
		Botao.NEBLINA:
			var pts := PackedVector2Array()
			for k in 17:
				var a := PI * 0.5 + PI * float(k) / 16.0
				pts.append(c + Vector2(10, 0) + Vector2(cos(a) * 26, sin(a) * 26))
			ci.draw_colored_polygon(pts, Color(0.35, 0.95, 0.35))
			for k in 3:
				var y := -14.0 + 14.0 * k
				ci.draw_line(c + Vector2(18, y), c + Vector2(44, y + 6), Color(0.35, 0.95, 0.35), 5.0)
			ci.draw_line(c + Vector2(28, -24), c + Vector2(28, 28), Color(0.35, 0.95, 0.35), 3.0)
		Botao.LANTERNA:
			ci.draw_circle(c + Vector2(-16, 0), 14.0, TINTA)
			ci.draw_circle(c + Vector2(16, 0), 14.0, TINTA)
			for k in 3:
				var y := -12.0 + 12.0 * k
				ci.draw_line(c + Vector2(-34, y), c + Vector2(-46, y), TINTA, 4.0)
				ci.draw_line(c + Vector2(34, y), c + Vector2(46, y), TINTA, 4.0)


## A frente do toca-fitas, 178 x 50 mm, em 5,75 px por mm. So a SERIGRAFIA:
## botoes, fita e visor sao pecas 3D por cima, nas posicoes de `RadioLayout`.
static func _serigrafia_radio(ci: CanvasItem, r: Rect2, f: Font, fn: Font) -> void:
	var o := r.position
	var mm := r.size.x / 178.0
	var cinza := Color(0.72, 0.72, 0.70)
	var p := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * mm
	_texto(ci, fn, p.call(14.0, 40.5), "VOL", 26, cinza)
	_texto(ci, f, p.call(14.0, 45.5), "PUSH ON", 16, cinza)
	_texto(ci, fn, p.call(164.0, 40.5), "TUNE", 26, cinza)
	_texto(ci, f, p.call(164.0, 45.5), "BAND", 16, cinza)
	# A marca: fantasia, em italico de fabrica de som dos anos 90.
	var marca := FontVariation.new()
	marca.base_font = ThemeDB.fallback_font
	marca.variation_embolden = 1.2
	marca.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(-0.28, 1.0),
		Vector2.ZERO)
	_texto(ci, marca, p.call(137.0, 4.2), "TROPICAL", 30, Color(0.86, 0.84, 0.80))
	_texto(ci, f, p.call(74.0, 4.0), "AUTO REVERSE  -  DOLBY B NR", 17, cinza)
	# Os algarismos das memorias, embaixo de cada tecla.
	for k in 6:
		var x := 31.0 + 14.4 * float(k) + 6.6
		_texto(ci, fn, p.call(x, 47.2), str(k + 1), 20, cinza)
	_texto(ci, f, p.call(129.5, 47.2), "AM/FM", 16, cinza)
	_texto(ci, f, p.call(145.5, 47.2), "LOUD", 16, cinza)
	# Os filetes de acabamento, que separam a gaveta da fita do resto.
	ci.draw_line(p.call(28.0, 1.8), p.call(28.0, 48.2), Color(0.35, 0.35, 0.35), 2.0)
	ci.draw_line(p.call(120.0, 1.8), p.call(120.0, 48.2), Color(0.35, 0.35, 0.35), 2.0)


## A faixa do ar embaixo do radio: rotulos e o icone de cada tecla.
static func _serigrafia_ar(ci: CanvasItem, r: Rect2, f: Font) -> void:
	var o := r.position
	var mm := r.size.x / 178.0
	var cinza := Color(0.72, 0.72, 0.70)
	var p := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * mm
	_texto(ci, f, p.call(89.0, 27.0), "A/C", 18, cinza)
	_texto(ci, f, p.call(30.0, 27.0), "AR", 16, cinza)
	_texto(ci, f, p.call(148.0, 27.0), "DIST", 16, cinza)
