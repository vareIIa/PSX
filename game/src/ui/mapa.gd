## Desenho do mapa da cidade. Serve o minimapa do canto e a pagina do pause.
##
## Nao le a cena. Pergunta a MalhaUrbana onde passa rua e onde termina a quadra,
## e ao ChunkBuilder quais sao os pontos de interesse do chunk. Por isso o mapa de
## pausa consegue mostrar 600 m de bairro num quadro: nenhum daqueles chunks
## precisa estar carregado, nem existir como geometria.
##
## A consequencia importante e que o mapa NAO PODE divergir do mundo. Os dois leem
## a mesma funcao. Um mapa desenhado a partir de uma copia da regra fica certo no
## dia em que e escrito e erra no primeiro ajuste do gerador — e erra em silencio,
## que e o pior tipo de erro num mapa.
##
## Como se le
## ----------
## Papel claro e rua; o que esta desenhado por cima e construido. A mancha escura
## em volta de cada quadra e a fita de predios, com 8 m, que e onde o jogador anda
## rente. O miolo palido e patio fechado, onde nao se entra. Verde e parque, com
## os caminhos abertos em claro por dentro.
##
## Icone so aparece onde o jogador ja esteve, ou onde ele esta agora. Um mapa que
## ja nasce com todas as lojas marcadas tira do jogo a unica coisa que a
## exploracao dava.
class_name Mapa
extends Control

enum Estilo {
	CARTAO,   ## minimapa do canto: pequeno, sem legenda, com moldura
	PAGINA,   ## mapa do pause: grande, com grade, escala e legenda
}

const TAM := KitModular.CHUNK
const ICONE := "res://assets/ui/icone_%s.png"
const PAPEL_TEX := "res://assets/ui/ui_papel.png"

## Fita de predios em volta da quadra. E a mesma medida que o ChunkBuilder usa
## para a profundidade do volume, e tem de continuar sendo.
const FITA_PREDIO := ChunkBuilder.PROF_PREDIO

# Papel e tinta, na mesma paleta da prancha de inventario: com outra, o mapa
# viraria uma janela de outro jogo dentro deste.
#
# A escala de VALOR importa mais que a cor. Num cartao de 82 px atras de grao,
# dither e vinheta, so a diferenca de claro para escuro sobrevive — o mapa tem de
# funcionar em preto e branco antes de funcionar em cor.
#
#   claro   o papel, que ja e a rua; a avenida vem mais clara ainda
#   medio   patio de quadra, terreno baldio
#   escuro  fita de predios
const PAPEL := Color("ded6b8")
const AVENIDA := Color("f6efd4")
const PREDIO := Color("4b4231")
const PATIO := Color("b0a68a")
const PARQUE := Color("6d7c4e")
const CAMINHO := Color("d6cdab")
const BALDIO := Color("a3947a")
const GRADE := Color("bab08e")
const TINTA := Color("2a1f16")
const TINTA_FRACA := Color("6a5a44")
## Vela do desconhecido. Clareia e lava o contraste em vez de escurecer: um mapa
## de papel nao fica preto onde nao foi desenhado, fica em branco.
const NEVOA := Color(0.88, 0.85, 0.74, 0.62)

var centro := Vector3.ZERO
var rumo: float = 0.0
var metros_por_pixel: float = 2.1
var estilo: Estilo = Estilo.CARTAO
## Deixa o mapa inteiro visivel, sem a nevoa do que nao foi visitado. So o modo
## de captura usa: numa foto o jogador nunca andou.
var revelar_tudo: bool = false

## Onde o jogador esta, quando a vista NAO esta centrada nele.
##
## O cartao do canto e a pagina do pause sempre centram na pessoa, entao para
## eles isto continua sendo o proprio `centro` e nao precisa ser preenchido. O
## GPS e o primeiro a olhar para outro lugar: sem este campo a seta ficaria
## grudada no meio da tela e o mapa diria que o jogador esta no mercado que ele
## acabou de selecionar do outro lado do bairro.
var pos_jogador := Vector3.INF

## Marcas por cima de tudo, inclusive da nevoa. Cada uma e
## `{"pos": Vector2 (x,z de mundo), "icone": StringName, "destaque": bool}`.
##
## Existem porque o GPS precisa mostrar um destino que fica em quadra nunca
## visitada — que e justamente o caso em que apontar um destino serve para
## alguma coisa. Marca de destino nao e descoberta: ela nao revela a rua em
## volta, so diz "e para la".
var pinos: Array[Dictionary] = []

var _icones: Dictionary[StringName, Texture2D] = {}
var _papel: Texture2D
var _ultimo_centro := Vector3(1e9, 0.0, 0.0)


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for nome: StringName in [&"mercado", &"casa", &"casa_verde", &"predio",
			&"parque", &"telefone", &"porta", &"jogador", &"norte"]:
		var caminho := ICONE % nome
		if ResourceLoader.exists(caminho):
			_icones[nome] = load(caminho)
	if ResourceLoader.exists(PAPEL_TEX):
		_papel = load(PAPEL_TEX)


## Move o mapa. Só redesenha quando vale a pena: o mapa varre dezenas de chunks
## por quadro desenhado, e a 60 Hz isso e trabalho jogado fora — a 2 m por pixel
## o jogador precisa andar dois metros para um pixel mudar de lugar.
func apontar(pos: Vector3, novo_rumo: float) -> void:
	rumo = novo_rumo
	centro = pos
	if pos.distance_squared_to(_ultimo_centro) < metros_por_pixel * metros_por_pixel:
		return
	_ultimo_centro = pos
	queue_redraw()


func forcar_redesenho() -> void:
	_ultimo_centro = Vector3(1e9, 0.0, 0.0)
	queue_redraw()


# --- desenho ----------------------------------------------------------------

func _draw() -> void:
	var meia := size * 0.5
	draw_rect(Rect2(Vector2.ZERO, size), PAPEL)
	# Fibra do papel por baixo de tudo. Um fundo chapado denuncia o mapa como
	# painel de interface; a mesma textura da prancha o devolve para o mundo de
	# papel e fita em que o resto da interface vive.
	if _papel != null:
		draw_texture_rect(_papel, Rect2(Vector2.ZERO, size), true,
			Color(1.0, 1.0, 1.0, 0.55))

	# O papel claro ja e a rua. Desenhar rua por cima do papel custaria uma faixa
	# por linha de grade; desenhar quadra sobre papel custa um retangulo por
	# quadra, que e menos, e o resultado e o mesmo.
	var alcance := (meia.length() * metros_por_pixel) + TAM
	var c0 := Vector2i(floori((centro.x - alcance) / TAM), floori((centro.z - alcance) / TAM))
	var c1 := Vector2i(ceili((centro.x + alcance) / TAM), ceili((centro.z + alcance) / TAM))

	_desenhar_avenidas(c0, c1)

	var quadras: Dictionary[Vector2i, Dictionary] = {}
	for cz in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var q := MalhaUrbana.quadra_de(cx, cz)
			quadras[q["id"]] = q
	for id: Vector2i in quadras:
		_desenhar_quadra(quadras[id])

	if estilo == Estilo.PAGINA:
		_desenhar_grade(c0, c1)

	_desenhar_pontos(c0, c1)
	_desenhar_nevoa(c0, c1)
	_desenhar_pinos()
	_desenhar_jogador()

	if estilo == Estilo.CARTAO:
		draw_rect(Rect2(Vector2.ZERO, size), TINTA, false, 1.0)
		_desenhar_icone(&"norte", Vector2(size.x - 9.0, 9.0), 0.72)


## Eixo da avenida, em tom mais claro que a rua comum. E o unico jeito de a
## hierarquia de vias existir no mapa: sem isto todas as ruas sao a mesma faixa
## de papel e o jogador nao tem por onde se orientar.
func _desenhar_avenidas(c0: Vector2i, c1: Vector2i) -> void:
	for i in range(c0.x, c1.x + 2):
		if MalhaUrbana.via_x(i) != MalhaUrbana.Via.AVENIDA:
			continue
		var meia := MalhaUrbana.meia_pista(MalhaUrbana.Via.AVENIDA)
		var a := _para_tela(Vector2(float(i) * TAM - meia, float(c0.y) * TAM))
		var b := _para_tela(Vector2(float(i) * TAM + meia, float(c1.y + 1) * TAM))
		draw_rect(Rect2(a, b - a), AVENIDA)
	for i in range(c0.y, c1.y + 2):
		if MalhaUrbana.via_z(i) != MalhaUrbana.Via.AVENIDA:
			continue
		var meia := MalhaUrbana.meia_pista(MalhaUrbana.Via.AVENIDA)
		var a := _para_tela(Vector2(float(c0.x) * TAM, float(i) * TAM - meia))
		var b := _para_tela(Vector2(float(c1.x + 1) * TAM, float(i) * TAM + meia))
		draw_rect(Rect2(a, b - a), AVENIDA)


func _desenhar_quadra(q: Dictionary) -> void:
	var mundo := MalhaUrbana.retangulo_da_quadra(q)
	var a := _para_tela(mundo.position)
	var b := _para_tela(mundo.end)
	var r := Rect2(a, b - a)
	if not r.intersects(Rect2(Vector2.ZERO, size)):
		return

	match int(q["uso"]):
		MalhaUrbana.Uso.PARQUE:
			draw_rect(r, PARQUE)
			var plano := ParqueBuilder.planta(q)
			var origem := Vector2(float(q["x0"]) * TAM, float(q["z0"]) * TAM)
			for faixa: Rect2 in ParqueBuilder.faixas_de_caminho(plano):
				var pa := _para_tela(faixa.position + origem)
				var pb := _para_tela(faixa.end + origem)
				# Caminho de 2,6 m tem menos de dois pixels no minimapa. Sem o
				# minimo de um pixel ele some, e o parque vira uma mancha verde
				# sem nada dentro.
				var largura := maxf(pb.x - pa.x, 1.0)
				var altura := maxf(pb.y - pa.y, 1.0)
				draw_rect(Rect2(pa, Vector2(largura, altura)), CAMINHO)
		MalhaUrbana.Uso.BALDIO:
			draw_rect(r, BALDIO)
			draw_rect(r, TINTA_FRACA, false, 1.0)
		_:
			draw_rect(r, PATIO)
			# Fita de predios em volta. Quatro retangulos, e nao um contorno
			# grosso: contorno com espessura desenha metade para fora da quadra e
			# come a calcada.
			var fita := FITA_PREDIO / metros_por_pixel
			var largura := minf(fita, r.size.x * 0.5)
			var altura := minf(fita, r.size.y * 0.5)
			draw_rect(Rect2(r.position, Vector2(r.size.x, altura)), PREDIO)
			draw_rect(Rect2(Vector2(r.position.x, r.end.y - altura),
				Vector2(r.size.x, altura)), PREDIO)
			draw_rect(Rect2(r.position, Vector2(largura, r.size.y)), PREDIO)
			draw_rect(Rect2(Vector2(r.end.x - largura, r.position.y),
				Vector2(largura, r.size.y)), PREDIO)
			# Contorno fino. Sem ele duas quadras separadas por uma viela de 4 m
			# viram uma mancha escura so no cartao pequeno.
			draw_rect(r, TINTA, false, 1.0)


## Grade de 160 m, que e o passo da avenida. So na pagina: no cartao ela
## competiria com a rua.
func _desenhar_grade(c0: Vector2i, c1: Vector2i) -> void:
	var passo := MalhaUrbana.PERIODO
	for i in range(c0.x, c1.x + 2):
		if posmod(i, passo) != 0:
			continue
		var x := _para_tela(Vector2(float(i) * TAM, 0.0)).x
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), GRADE, 1.0)
	for i in range(c0.y, c1.y + 2):
		if posmod(i, passo) != 0:
			continue
		var y := _para_tela(Vector2(0.0, float(i) * TAM)).y
		draw_line(Vector2(0.0, y), Vector2(size.x, y), GRADE, 1.0)


## Acima desta escala o icone deixa de informar. Um icone tem 11 px; a 5 m por
## pixel um quarteirao inteiro tem 13, entao tres icones vizinhos viram uma
## mancha e a varredura de tres mil chunks e paga para nada.
const ESCALA_SEM_ICONE := 5.5


func _desenhar_pontos(c0: Vector2i, c1: Vector2i) -> void:
	if metros_por_pixel > ESCALA_SEM_ICONE:
		return
	for cz in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			if not _conhecido(Vector2i(cx, cz)):
				continue
			var origem := Vector2(float(cx) * TAM, float(cz) * TAM)
			for ponto: Dictionary in ChunkBuilder.pontos_de_interesse(cx, cz):
				var p: Vector3 = ponto["pos"]
				var tela := _para_tela(origem + Vector2(p.x, p.z))
				if not Rect2(Vector2.ZERO, size).grow(8.0).has_point(tela):
					continue
				var icone := _icone_de(ponto)
				# Porta de apartamento vira ponto, e nao icone. Uma em cada tres
				# quadras tem uma; em icone cheio elas cobriam o mapa inteiro e
				# escondiam justamente o que o mapa existe para achar. Como ponto
				# a informacao continua la e o desenho respira.
				if icone == &"predio":
					if estilo == Estilo.PAGINA:
						draw_rect(Rect2(tela - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), TINTA)
					continue
				_desenhar_icone(icone, tela,
					0.72 if estilo == Estilo.PAGINA else 0.62)


## Que icone representa o ponto. A porta muda de cara conforme o que ha atras
## dela, e e essa distincao que faz o mapa valer: achar a loja de longe.
func _icone_de(ponto: Dictionary) -> StringName:
	match ponto["tipo"]:
		&"parque":
			return &"parque"
		&"telefone":
			return &"telefone"
		&"porta":
			match ponto["interior"]:
				&"mercado":
					return &"mercado"
				&"casa":
					return &"casa"
				# A casa da fumaca tem icone proprio, e e a unica porta do jogo
				# que tem. E o unico destino da cidade que o jogador vai QUERER
				# reencontrar depois de sair, e achar uma porta em vinte quadras
				# iguais sem marca no mapa e sorte, nao exploracao.
				&"casa_fumaca":
					return &"casa_verde"
				_:
					return &"predio"
		_:
			return &"porta"


## Vela por cima do que o jogador nao conhece. Nao esconde a rua — ele ve a
## cidade da janela — mas tira o contraste, e o percorrido fica destacado sozinho.
func _desenhar_nevoa(c0: Vector2i, c1: Vector2i) -> void:
	if revelar_tudo:
		return
	for cz in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			if _conhecido(Vector2i(cx, cz)):
				continue
			var a := _para_tela(Vector2(float(cx) * TAM, float(cz) * TAM))
			var b := _para_tela(Vector2(float(cx + 1) * TAM, float(cz + 1) * TAM))
			draw_rect(Rect2(a, b - a), NEVOA)


func _conhecido(coord: Vector2i) -> bool:
	if revelar_tudo:
		return true
	return WorldState.visitado(coord) or ChunkManager.esta_carregado(coord)


## Alfinete de destino. Nao usa textura: e a unica marca do mapa que precisa
## aparecer sobre a nevoa, e um icone de 16 px chapado sobre a vela clara some.
## Anel escuro por fora, miolo claro, e uma cruz de mira quando e o destino
## escolhido — em preto e branco continua sendo a coisa mais escura da tela.
const ALVO := Color("8a2f1c")


func _desenhar_pinos() -> void:
	var quadro := Rect2(Vector2.ZERO, size)
	for pino: Dictionary in pinos:
		var mundo: Vector2 = pino["pos"]
		var p := _para_tela(mundo)
		var destaque := bool(pino.get("destaque", false))
		if not quadro.grow(10.0).has_point(p):
			continue
		var icone: StringName = pino.get("icone", &"")
		if icone != &"" and _icones.has(icone) and not destaque:
			_desenhar_icone(icone, p, 0.62)
			continue
		var raio := 4.5 if destaque else 3.0
		draw_circle(p, raio + 1.5, TINTA)
		draw_circle(p, raio, ALVO)
		if destaque:
			draw_line(p - Vector2(9.0, 0.0), p + Vector2(9.0, 0.0), TINTA, 1.0)
			draw_line(p - Vector2(0.0, 9.0), p + Vector2(0.0, 9.0), TINTA, 1.0)


func _desenhar_jogador() -> void:
	var eu := centro if pos_jogador == Vector3.INF else pos_jogador
	var p := _para_tela(Vector2(eu.x, eu.z))
	# Com a vista longe da pessoa a seta sairia do quadro e o mapa perderia a
	# unica referencia que importa. Encostada na borda ela vira bussola: aponta
	# para onde o jogador ficou.
	p = p.clamp(Vector2(6.0, 6.0), size - Vector2(6.0, 6.0))
	var frente := Vector2(-sin(rumo), -cos(rumo))
	var lado := Vector2(frente.y, -frente.x)
	var escala := 5.0 if estilo == Estilo.CARTAO else 6.5
	# Contorno escuro por baixo. A seta e a unica coisa do mapa que precisa ser
	# achada sem procurar, e vermelho sobre bege claro nao basta atras do grao.
	for passo: Array in [[escala * 1.34, TINTA], [escala, Color("9c3320")]]:
		var e: float = passo[0]
		draw_colored_polygon(PackedVector2Array([
			p + frente * e,
			p + lado * e * 0.62 - frente * e * 0.55,
			p - frente * e * 0.22,
			p - lado * e * 0.62 - frente * e * 0.55,
		]), passo[1])


func _desenhar_icone(nome: StringName, em: Vector2, escala: float) -> void:
	var tex: Texture2D = _icones.get(nome)
	if tex == null:
		return
	var lado := 16.0 * escala
	draw_texture_rect(tex, Rect2(em - Vector2(lado, lado) * 0.5,
		Vector2(lado, lado)), false)


func _para_tela(mundo: Vector2) -> Vector2:
	return (mundo - Vector2(centro.x, centro.z)) / metros_por_pixel + size * 0.5


## Nome do lugar sob o jogador, para o cabecalho da pagina.
func onde_estou() -> String:
	var coord := Vector2i(floori(centro.x / TAM), floori(centro.z / TAM))
	var q := MalhaUrbana.quadra_de(coord.x, coord.y)
	if int(q["uso"]) == MalhaUrbana.Uso.PARQUE:
		return String(ParqueBuilder.planta(q)["nome"])
	return MalhaUrbana.nome_do_distrito(q["distrito"])
