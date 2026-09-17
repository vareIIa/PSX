## A foto 3x4 de uma pessoa, montada a partir do mesmo atlas que veste o corpo
## dela no mundo.
##
## Esta e a peca que amarra o sistema inteiro. O documento que o NPC tira do
## bolso, a ficha que o aplicativo do governo devolve e o sujeito parado na
## esquina precisam ser reconhecivelmente a MESMA pessoa — se a foto fosse
## desenhada a parte, seriam tres pessoas com o mesmo nome, e a consulta por CPF
## perderia o sentido de ser uma consulta.
##
## Entao a foto e literalmente recortada do atlas: a celula de rosto que o crânio
## dele usa em 3D, tingida pelo mesmo tom de pele, com a mesma calota de cabelo
## na mesma cor e a gola da mesma roupa. Nada aqui e escolhido; tudo e lido.
##
## O fundo cinza-azulado e o gasto do papel sao os unicos enfeites, e existem
## para a imagem ler como foto de cartorio e nao como sprite.
class_name Retrato
extends RefCounted

const ATLAS := "res://assets/textures/npc_atlas.png"

const LARGURA := 40
const ALTURA := 52

## Onde a cabeca pousa dentro da foto.
const CABECA_X := 4
const CABECA_Y := 7

## Fundo do estudio. Escuro de proposito, e nao o cinza claro de cabine.
##
## O primeiro valor era um cinza-azulado de luminancia 0,60, muito perto da pele
## clara em 0,75. Numa foto de 40 px isso quer dizer que a cabeca nao recorta do
## fundo: no visor verde do celular, que ainda mapeia tudo para uma escala so, a
## foto virava um retangulo chapado onde nao dava para reconhecer ninguem. O
## contraste entre cabeca e fundo e a unica coisa que uma foto deste tamanho tem.
const FUNDO := Color("4d5761")
const FUNDO_BAIXO := Color("323a43")

static var _atlas: Image = null


static func _pegar_atlas() -> Image:
	if _atlas != null:
		return _atlas
	var tex := load(ATLAS) as Texture2D
	if tex == null:
		push_error("Retrato: atlas ausente em %s" % ATLAS)
		return null
	_atlas = tex.get_image()
	if _atlas == null:
		return null
	if _atlas.is_compressed():
		_atlas.decompress()
	_atlas.convert(Image.FORMAT_RGBA8)
	return _atlas


static func _celula(img: Image, coluna: int, linha: int, x: int, y: int) -> Color:
	return img.get_pixel(coluna * Aparencia.CELULA + x, linha * Aparencia.CELULA + y)


static func _multiplicar(a: Color, b: Color) -> Color:
	return Color(a.r * b.r, a.g * b.g, a.b * b.b, a.a)


## Imagem da foto. Devolve null se o atlas nao carregou.
static func gerar(aparencia: Dictionary) -> Image:
	var atlas := _pegar_atlas()
	if atlas == null:
		return null

	var foto := Image.create(LARGURA, ALTURA, false, Image.FORMAT_RGBA8)
	# Fundo em degrade, mais escuro embaixo. Fundo chapado le como recorte
	# colado; o degrade sozinho ja poe a pessoa dentro de um estudio.
	for y in ALTURA:
		var t := float(y) / float(ALTURA - 1)
		var cor := FUNDO.lerp(FUNDO_BAIXO, t)
		for x in LARGURA:
			foto.set_pixel(x, y, cor)

	var pele: Color = aparencia.get("pele", Color.WHITE)
	var roupa: Color = (aparencia["casaco_cor"] if bool(aparencia.get("casaco", false))
		else aparencia.get("camisa_cor", Color("6f6a60")))

	_ombros(foto, atlas, aparencia, roupa)
	_pescoco(foto, atlas, pele)
	_cabeca(foto, atlas, aparencia, pele)
	_cabelo(foto, atlas, aparencia)
	_envelhecer(foto)
	return foto


static func gerar_textura(aparencia: Dictionary) -> ImageTexture:
	var img := gerar(aparencia)
	if img == null:
		return null
	return ImageTexture.create_from_image(img)


## A mesma foto, mapeada para a escala de um visor monocromatico.
##
## Existe porque tingir a foto colorida de verde no desenho NAO funciona: o
## fundo cinza-azulado e a pele clara tem luminancia parecida, e multiplicar os
## dois pelo mesmo verde entrega dois verdes parecidos — a foto vira um bloco
## chapado e nao da para reconhecer ninguem. Aqui a luminancia de cada pixel
## vira a POSICAO entre o fundo do visor e o verde aceso, entao cabelo escuro
## continua escuro e rosto claro continua claro. E o que um LCD verde de 1998
## fazia com uma foto, e e o que mantem a consulta util.
static func gerar_textura_lcd(aparencia: Dictionary, fundo: Color,
		aceso: Color) -> ImageTexture:
	var img := gerar(aparencia)
	if img == null:
		return null
	for y in img.get_height():
		for x in img.get_width():
			var lum := img.get_pixel(x, y).get_luminance()
			# Espicha o contraste antes de mapear: a faixa util de uma foto 3x4
			# fica toda entre 0,25 e 0,8, e sem esticar o visor mostra meio tom.
			var t := clampf((lum - 0.22) / 0.56, 0.0, 1.0)
			img.set_pixel(x, y, fundo.lerp(aceso, t))
	return ImageTexture.create_from_image(img)


static func _ombros(foto: Image, atlas: Image, aparencia: Dictionary,
		roupa: Color) -> void:
	var coluna := int(aparencia.get("casaco_cel", 0)) if bool(aparencia.get("casaco", false)) else int(aparencia.get("camisa", 0))
	var linha := Aparencia.LINHA_CASACO if bool(aparencia.get("casaco", false)) else Aparencia.LINHA_CAMISA
	for y in range(40, ALTURA):
		# Os ombros abrem conforme descem, que e o corte de qualquer foto de
		# documento: cabeca inteira, um dedo de tronco.
		var meio := 4 + (y - 40)
		for x in range(maxi(0, 20 - meio - 6), mini(LARGURA, 20 + meio + 6)):
			var textura := _celula(atlas, coluna, linha,
				posmod(x * 2, Aparencia.CELULA), posmod(y, Aparencia.CELULA))
			foto.set_pixel(x, y, _multiplicar(textura, roupa))


static func _pescoco(foto: Image, atlas: Image, pele: Color) -> void:
	for y in range(36, 44):
		for x in range(15, 25):
			var textura := _celula(atlas, Aparencia.PECA_NUCA,
				Aparencia.LINHA_PECAS, x, y)
			# Sombra do queixo no alto do pescoco. Sem ela a cabeca parece
			# apoiada num cilindro claro.
			var escurecer := 0.72 if y < 40 else 0.86
			foto.set_pixel(x, y, _multiplicar(textura, pele) * escurecer)


static func _cabeca(foto: Image, atlas: Image, aparencia: Dictionary,
		pele: Color) -> void:
	var coluna := int(aparencia.get("rosto", 0))
	var linha := int(aparencia.get("linha_rosto", Aparencia.LINHA_ROSTO_M))
	for y in Aparencia.CELULA:
		for x in Aparencia.CELULA:
			var destino_x := CABECA_X + x
			var destino_y := CABECA_Y + y
			if destino_x < 0 or destino_x >= LARGURA or destino_y >= ALTURA:
				continue
			foto.set_pixel(destino_x, destino_y,
				_multiplicar(_celula(atlas, coluna, linha, x, y), pele))


static func _cabelo(foto: Image, atlas: Image, aparencia: Dictionary) -> void:
	if bool(aparencia.get("calvo", false)):
		return
	var coluna := int(aparencia.get("cabelo", 0))
	# A linha vem da ficha: sem isto, a foto do documento de Helmer puxaria
	# a celula 6 da linha de cabelo COMUM, que e fio liso, e a carteira dele
	# mostraria um penteado que o corpo dele nao tem.
	var linha_cabelo := int(aparencia.get("linha_cabelo",
		Aparencia.LINHA_CABELO))
	var cor: Color = aparencia.get("cabelo_cor", Color("332619"))
	var comprimento := int(aparencia.get("cabelo_comprimento", 0))
	# Franja: cinco linhas em cima da testa. Mais que isso come a sobrancelha, e
	# rosto sem sobrancelha em 32 px perde metade da expressao.
	var franja := 5
	var lateral: int = [10, 18, 26][clampi(comprimento, 0, 2)]

	for y in range(0, franja + lateral):
		for x in Aparencia.CELULA:
			var dentro_da_franja := y < franja
			var na_lateral := x < 4 or x >= Aparencia.CELULA - 4
			if not dentro_da_franja and not na_lateral:
				continue
			var destino_x := CABECA_X + x
			var destino_y := CABECA_Y + y
			if destino_y >= ALTURA:
				continue
			var textura := _celula(atlas, coluna, linha_cabelo,
				x, posmod(y, Aparencia.CELULA))
			foto.set_pixel(destino_x, destino_y, _multiplicar(textura, cor))


## Grao e cantos gastos. E o que separa "imagem gerada" de "foto colada num
## documento que anda no bolso de alguem ha dez anos".
static func _envelhecer(foto: Image) -> void:
	for y in ALTURA:
		for x in LARGURA:
			var h := absi(int(x * 7919 + y * 104729)) % 100
			var cor := foto.get_pixel(x, y)
			if h < 7:
				cor = cor.lightened(0.06)
			elif h > 93:
				cor = cor.darkened(0.06)
			# Vinheta: as bordas da foto escurecem, como toda foto 3x4 de maquina
			# de cabine escurece.
			var dx := absf(float(x) - LARGURA * 0.5) / (LARGURA * 0.5)
			var dy := absf(float(y) - ALTURA * 0.5) / (ALTURA * 0.5)
			var borda := maxf(dx, dy)
			if borda > 0.78:
				cor = cor.darkened((borda - 0.78) * 0.8)
			foto.set_pixel(x, y, cor)
