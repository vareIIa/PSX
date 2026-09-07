## Criacao de personagem: a propria carteira, aberta nas maos.
##
## A forma e o assunto
## -------------------
## Isto nao e um menu de opcoes com um boneco do lado. E o documento do jogador,
## aberto e segurado por ele — as maos aparecem embaixo, com a manga da camisa
## que ele acabou de escolher e a cor de pele que ele acabou de escolher. A
## pagina da esquerda tem a foto; a da direita tem os campos.
##
## Isso resolve de uma vez uma coisa que um menu nao resolve: o jogo inteiro
## depois desta tela e sobre documento — o NPC mostra o dele, o portal do celular
## consulta pelo CPF, a carteira fica no inventario. Comecar a partida montando a
## propria carteira poe o jogador dentro dessa gramatica antes da primeira rua.
##
## O que se escolhe, e o que nao
## -----------------------------
## Rosto, pele, cabelo, roupa, calca, chapeu, altura e porte. Numero, data de
## nascimento e naturalidade estao impressos na mesma pagina e nao se mexem:
## sairam do registro civil quando a ficha foi emitida. Ver os dois lado a lado e
## o que diz isso sem uma linha de texto explicando.
##
## O retrato e 3D de verdade: um SubViewport com mundo proprio e o MESMO Corpo
## que anda na calcada, montado pela mesma funcao. Trocar de camisa aqui e trocar
## a malha que vai andar na rua daqui a dez segundos, e por isso o retrato nao
## tem como mentir.
class_name CriacaoAparencia
extends Control

const UI := "res://assets/ui/%s.png"
const FONTE_P := "res://assets/fontes/psx_pequena.fnt"
const FONTE_M := "res://assets/fontes/psx_media.fnt"
const FONTE_MONO := "res://assets/fontes/psx_mono.fnt"
const ATLAS := "res://assets/textures/npc_atlas.png"

const TELA := Vector2(480.0, 270.0)
## A carteira aberta: duas paginas, levemente tortas, como coisa segurada.
const DOC := Rect2(56.0, 14.0, 368.0, 184.0)
const INCLINACAO := -1.4
const PAGINA_ESQ := Rect2(64.0, 22.0, 158.0, 168.0)
const PAGINA_DIR := Rect2(232.0, 22.0, 184.0, 168.0)
## Janela do retrato, dentro da pagina da esquerda.
const RETRATO := Rect2(76.0, 54.0, 134.0, 124.0)

const TINTA := Color("22301f")
const TINTA_FRACA := Color("5c6b52")
const PAPEL := Color("e3e9d6")
const VINCO := Color("b9c3aa")
const DESTAQUE := Color("8a2f1f")

## Abas de categoria. Cada uma diz quais campos de Aparencia.AJUSTES mostra.
const ABAS: Array[Dictionary] = [
	{"nome": "ROSTO", "icone": "rosto", "campos": [&"rosto", &"pele"]},
	{"nome": "CABELO", "icone": "cabelo", "campos": [&"cabelo", &"cabelo_cor"]},
	{"nome": "ROUPA", "icone": "camisa", "campos": [&"camisa", &"camisa_cor"]},
	{"nome": "CALCA", "icone": "calca", "campos": [&"calca", &"calca_cor"]},
	{"nome": "CHAPEU", "icone": "chapeu", "campos": [&"chapeu_tipo"]},
	{"nome": "CORPO", "icone": "corpo", "campos": [&"altura", &"gordura"]},
]

## Primeira linha navegavel: a fileira de abas. Depois vem um campo por linha, e
## por ultimo o visto de aceite.
const LINHA_ABAS := 0

signal confirmou()
signal voltou()

var _ajustes: Dictionary = {}
var _aba: int = 0
var _linha: int = 0
var _relogio: float = 0.0

var _viewport: SubViewport
var _corpo: Corpo
var _giro: float = 0.0
var _atlas: Texture2D
var _fonte: Font
var _fonte_media: Font
var _mono: Font
var _guilhoche: Texture2D
var _brasao: Texture2D
var _arrastando_chave: StringName = &""
var _arrastando_campo: Dictionary = {}
const BOTAO_VOLTAR := Rect2(64.0, 252.0, 110.0, 15.0)
const BOTAO_CONFIRMAR := Rect2(306.0, 252.0, 110.0, 15.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_atlas = load(ATLAS) as Texture2D
	_fonte = load(FONTE_P) as Font
	_fonte_media = load(FONTE_M) as Font
	_mono = load(FONTE_MONO) as Font
	if ResourceLoader.exists(UI % "doc_guilhoche"):
		_guilhoche = load(UI % "doc_guilhoche") as Texture2D
	if ResourceLoader.exists(UI % "doc_brasao"):
		_brasao = load(UI % "doc_brasao") as Texture2D
	_montar_retrato()


# --- retrato 3D -------------------------------------------------------------

func _montar_retrato() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(int(RETRATO.size.x), int(RETRATO.size.y))
	# Mundo proprio: sem isto o retrato renderiza a cidade que esta atras do
	# menu, com nevoa e chuva, e o personagem some no meio dela.
	_viewport.own_world_3d = true
	_viewport.transparent_bg = false
	# Desligado enquanto a tela nao esta aberta. Um SubViewport nao para de
	# renderizar so porque o Control que desenha a textura dele esta escondido:
	# ele e um alvo de renderizacao proprio e continua desenhando personagem,
	# luz e ambiente a sessenta quadros por segundo pela partida inteira. Quem
	# liga e desliga e a visibilidade, logo abaixo.
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	add_child(_viewport)

	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	# Fundo de foto de documento: o mesmo cinza-azulado frio do Retrato do RG.
	env.background_color = Color("4d5761")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8e8c80")
	env.ambient_light_energy = 1.05
	ambiente.environment = env
	_viewport.add_child(ambiente)

	var luz := DirectionalLight3D.new()
	luz.light_energy = 1.45
	luz.rotation = Vector3(deg_to_rad(-22.0), deg_to_rad(-150.0), 0.0)
	luz.shadow_enabled = false
	_viewport.add_child(luz)

	# A frente do personagem fica em -Z. A câmera precisa ficar em -Z olhando
	# para a frente (+Z) para enquadrar o rosto e o peito, como uma foto 3x4.
	var camera := Camera3D.new()
	camera.fov = 24.0
	camera.near = 0.05
	camera.position = Vector3(0.0, 1.42, -1.75)
	_viewport.add_child(camera)
	camera.look_at(Vector3(0.0, 1.40, 0.0), Vector3.UP)
	camera.current = true


## Refaz o corpo do retrato. A cada mudanca: o Corpo remonta em pouco mais de um
## milissegundo, e um retrato que so atualizasse ao confirmar seria adivinhar em
## vez de escolher.
func _refazer_corpo() -> void:
	if _corpo != null:
		_corpo.queue_free()
	_corpo = Corpo.new()
	_viewport.add_child(_corpo)
	_corpo.montar(aparencia_atual())
	_corpo.rotation.y = _giro
	_corpo.animar(0.0, 0.016)


## Publica: a verificacao le a aparencia montada sem abrir a tela.
func aparencia_atual() -> Dictionary:
	var ficha := RegistroCivil.jogador
	if ficha.is_empty():
		return Aparencia.de_ficha({"id": 7, "sexo": &"M", "idade": 31})
	return Aparencia.com_ajustes(Aparencia.de_ficha(ficha), _ajustes)


# --- abertura ---------------------------------------------------------------

func abrir() -> void:
	_ajustes = RegistroCivil.ajustes_do_jogador()
	_aba = 0
	_linha = LINHA_ABAS
	_refazer_corpo()
	# A ficha pode nascer depois de a tela abrir — e o que acontece no caminho de
	# captura, e podia acontecer em qualquer ordem de inicializacao.
	if not RegistroCivil.jogador_mudou.is_connected(_ao_trocar_ficha):
		RegistroCivil.jogador_mudou.connect(_ao_trocar_ficha)
	queue_redraw()


## Liga o retrato so enquanto a carteira esta aberta. Ver _montar_retrato.
func _notification(o_que: int) -> void:
	if o_que != NOTIFICATION_VISIBILITY_CHANGED or _viewport == null:
		return
	_viewport.render_target_update_mode = (SubViewport.UPDATE_ALWAYS
		if is_visible_in_tree() else SubViewport.UPDATE_DISABLED)


func _ao_trocar_ficha() -> void:
	if not visible or not _ajustes.is_empty():
		return
	_ajustes = RegistroCivil.ajustes_do_jogador()
	_refazer_corpo()
	queue_redraw()


func _process(delta: float) -> void:
	_relogio += delta
	# Gira devagar em volta da frente, e nunca muito: e de frente que se escolhe
	# rosto e camisa. A volta completa mostraria as costas metade do tempo.
	_giro = sin(_relogio * 0.5) * 0.4
	if _corpo != null:
		_corpo.rotation.y = _giro
		_corpo.animar(0.0, delta)
	queue_redraw()


# --- desenho ----------------------------------------------------------------

func _texto(pos: Vector2, txt: String, cor: Color = TINTA, fonte: Font = null,
		alinhamento: int = HORIZONTAL_ALIGNMENT_LEFT, largura: float = -1.0) -> void:
	var f := fonte if fonte != null else _fonte
	if f != null:
		draw_string(f, pos, txt, alinhamento, largura, 11, cor)


func _draw() -> void:
	# Escurece o mundo atras. O documento e uma coisa que se traz para perto do
	# rosto, e o que esta atras dele sai de foco.
	draw_rect(Rect2(Vector2.ZERO, TELA), Color(0.03, 0.04, 0.03, 0.68))

	_desenhar_papel()
	_desenhar_pagina_esquerda()
	_desenhar_pagina_direita()
	_desenhar_zona()
	# As maos por ULTIMO: os dedos passam por cima da borda de baixo do
	# documento, que e o que faz o papel parecer segurado em vez de colado na
	# tela. Desenhadas antes, elas sumiam inteiras atras dele.
	_desenhar_bracos()

	_texto(Vector2(0.0, 262.0),
		"[A/D] escolher   [W/S] campo   [E] confirmar   [ESC] voltar",
		Color(0.86, 0.83, 0.72), _fonte, HORIZONTAL_ALIGNMENT_CENTER, TELA.x)


## O papel entra torto. Coisa segurada na mao nao fica reta, e o jogo inteiro
## segue essa regra desde a prancha de inventario.
func _desenhar_papel() -> void:
	draw_set_transform(DOC.position + DOC.size * 0.5, deg_to_rad(INCLINACAO),
		Vector2.ONE)
	var local := Rect2(-DOC.size * 0.5, DOC.size)
	draw_rect(Rect2(local.position + Vector2(3.0, 5.0), local.size),
		Color(0.02, 0.03, 0.02, 0.5))
	if _guilhoche != null:
		draw_texture_rect(_guilhoche, local, true, PAPEL)
	else:
		draw_rect(local, PAPEL)
	draw_rect(local, TINTA_FRACA, false, 1.0)
	# Vinco do meio: e o que faz duas paginas em vez de um cartaz.
	draw_rect(Rect2(-1.0, local.position.y + 6.0, 2.0, local.size.y - 12.0), VINCO)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## As maos que seguram a carteira de identidade.
##
## Redesenhadas com anatomia convincente low-poly PSX: antebraco com perspectiva,
## punho com dobra e volume de tecido, palma que apoia a base da carteira e
## polegar pousado sobre a margem inferior prendendo o documento, alem dos dedos
## de apoio visiveis na borda externa. Ambas acompanham dinamicamente o tom de
## pele e a cor de camisa ou casaco escolhidos pelo jogador.
func _desenhar_bracos() -> void:
	var a := aparencia_atual()
	var pele := Aparencia.pele_na_tela(a)
	var manga: Color = (a["casaco_cor"] if bool(a.get("casaco", false))
		else a["camisa_cor"])
	var tom_sombra := pele.darkened(0.26)
	var tom_medio := pele.darkened(0.12)
	var tom_luz := pele.lightened(0.10)
	var manga_sombra := manga.darkened(0.32)
	var manga_dobra := manga.lightened(0.12)

	for lado: float in [-1.0, 1.0]:
		# Geometria do antebraço e punho
		var base_x := TELA.x * 0.5 + lado * 154.0
		var punho_x := TELA.x * 0.5 + lado * 98.0
		var base := Vector2(base_x, TELA.y + 26.0)
		var punho := Vector2(punho_x, 218.0)
		var eixo := (punho - base).normalized()
		var perp := Vector2(-eixo.y, eixo.x)

		# 1. Antebraço (manga com corte angular e sombreamento bilateral)
		draw_colored_polygon(PackedVector2Array([
			base + perp * 26.0,
			base - perp * 26.0,
			punho - perp * 17.0,
			punho + perp * 17.0
		]), manga)
		# Sombra na lateral externa do braço
		draw_colored_polygon(PackedVector2Array([
			base + perp * (26.0 if lado < 0.0 else -10.0),
			base + perp * (10.0 if lado < 0.0 else -26.0),
			punho + perp * (17.0 if lado < 0.0 else -6.0),
			punho + perp * (6.0 if lado < 0.0 else -17.0)
		]), manga_sombra)

		# 2. Punho dobrado da camisa/jaqueta (cuff) com costura e volume
		var cuff_topo := punho + eixo * 8.0
		draw_colored_polygon(PackedVector2Array([
			punho - perp * 19.0,
			punho + perp * 19.0,
			cuff_topo + perp * 18.0,
			cuff_topo - perp * 18.0
		]), manga_dobra)
		draw_line(punho - perp * 18.0, punho + perp * 18.0, manga_sombra, 1.5)

		# 3. Base da palma da mão (eminência tenar / calcanhar da mão)
		var mao_base := cuff_topo + eixo * 2.0
		var palma_centro := mao_base + eixo * 12.0
		draw_colored_polygon(PackedVector2Array([
			mao_base - perp * 16.0,
			mao_base + perp * 16.0,
			palma_centro + perp * 17.0 + eixo * 4.0,
			palma_centro - perp * 15.0 + eixo * 4.0
		]), tom_medio)

		# 4. Dedos de apoio na borda externa inferior do documento
		# Os nós dos dedos contornam a borda lateral/inferior do papel
		for i in 3:
			var offset_dedo := (float(i) - 1.0) * 6.5
			var d_origem := palma_centro + perp * (10.0 * lado + offset_dedo) + eixo * 2.0
			var d_ponta := d_origem + eixo * 14.0 - perp * (2.0 * lado)
			var d_larg := 4.0
			draw_colored_polygon(PackedVector2Array([
				d_origem - perp * d_larg,
				d_origem + perp * d_larg,
				d_ponta + perp * (d_larg - 1.0),
				d_ponta - perp * (d_larg - 1.0)
			]), pele if i % 2 == 0 else tom_medio)
			# Unha/nó sutil em estilo PSX
			draw_line(d_ponta - perp * 2.0, d_ponta + perp * 2.0, tom_sombra, 1.0)

		# 5. O POLEGAR: a peça-chave que faz o documento parecer SEGURADO de verdade.
		# O polegar se projeta para dentro e para cima, com a ponta pressionando
		# a borda frontal do cartão plastificado.
		var pol_base := palma_centro - perp * (6.0 * lado) - eixo * 2.0
		var pol_junta := pol_base + Vector2(-lado * 14.0, -10.0)
		var pol_ponta := pol_junta + Vector2(-lado * 11.0, -7.0)
		var p_larg := 5.0

		# Falange proximal do polegar
		draw_colored_polygon(PackedVector2Array([
			pol_base + perp * p_larg,
			pol_base - perp * p_larg,
			pol_junta - perp * (p_larg + 0.5),
			pol_junta + perp * (p_larg + 0.5)
		]), tom_medio)

		# Falange distal (ponta do polegar sobrepondo a identidade)
		draw_colored_polygon(PackedVector2Array([
			pol_junta + perp * (p_larg + 0.5),
			pol_junta - perp * (p_larg + 0.5),
			pol_ponta - perp * (p_larg - 1.2),
			pol_ponta + perp * (p_larg - 1.2)
		]), pele)

		# Realce de luz no topo do polegar
		draw_line(pol_junta - Vector2(0.0, 3.0), pol_ponta - Vector2(0.0, 2.0), tom_luz, 1.2)
		# Unha do polegar (pequeno trapézio sutil low-poly)
		var unha_pos := pol_ponta + Vector2(lado * 2.0, 0.0)
		draw_colored_polygon(PackedVector2Array([
			unha_pos + Vector2(-2.0, -2.0),
			unha_pos + Vector2(2.0, -2.0),
			unha_pos + Vector2(1.5, 2.0),
			unha_pos + Vector2(-1.5, 2.0)
		]), tom_luz.lightened(0.15))
		# Sombra de oclusão de contato do polegar contra o papel
		draw_line(pol_ponta + Vector2(-lado * 2.0, 4.0), pol_junta + Vector2(0.0, 5.0),
			Color(0.05, 0.08, 0.05, 0.5), 1.5)


func _desenhar_pagina_esquerda() -> void:
	if _brasao != null:
		draw_texture_rect(_brasao, Rect2(PAGINA_ESQ.position.x + 4.0, 26.0,
			18.0, 18.0), false)
	_texto(Vector2(PAGINA_ESQ.position.x + 26.0, 33.0), "CARTEIRA DE", TINTA_FRACA)
	_texto(Vector2(PAGINA_ESQ.position.x + 26.0, 46.0), "IDENTIDADE", TINTA,
		_fonte_media)

	draw_rect(RETRATO.grow(2.0), TINTA)
	if _viewport != null:
		draw_texture_rect(_viewport.get_texture(), RETRATO, false)


func _desenhar_pagina_direita() -> void:
	var x := PAGINA_DIR.position.x
	var ficha := RegistroCivil.jogador

	# Os campos impressos. Sao justamente os que NAO se escolhem.
	if not ficha.is_empty():
		# A etiqueta miuda em cima e o valor embaixo, como no RG do inventario.
		# Lado a lado, "NOME" e o nome se encostavam: a fonte pequena rende nove
		# pixels por caractere e quatro letras ja tomam trinta e seis.
		_texto(Vector2(x, 32.0), "NOME", TINTA_FRACA)
		_texto(Vector2(x, 43.0), String(ficha["nome"]).substr(0, 22), TINTA)
		_texto(Vector2(x, 55.0), "CPF", TINTA_FRACA)
		_texto(Vector2(x + 32.0, 55.0), String(ficha["cpf"]), TINTA, _mono)
		# A UF depois do numero, com folga: o CPF em fonte mono ocupa noventa e
		# oito pixels e as duas coisas se encostavam.
		_texto(Vector2(x + 136.0, 55.0), String(ficha["uf"]), TINTA_FRACA)

	draw_rect(Rect2(x, 62.0, PAGINA_DIR.size.x - 10.0, 1.0), VINCO)
	_desenhar_abas()
	_desenhar_campos()
	_desenhar_visto()


## Fileira de abas com icone desenhado, como na referencia. Icone e nao palavra
## porque seis palavras de cinco letras nao cabem em 174 pixels.
func _desenhar_abas() -> void:
	var x := PAGINA_DIR.position.x
	var largura := 28.0
	for i in ABAS.size():
		var r := Rect2(x + float(i) * (largura + 1.0), 68.0, largura, 19.0)
		var ativa := i == _aba
		draw_rect(r, Color(0.83, 0.86, 0.76) if ativa else Color(0.73, 0.77, 0.67))
		draw_rect(r, DESTAQUE if (ativa and _linha == LINHA_ABAS) else TINTA_FRACA,
			false, 1.0)
		_icone_da_aba(String(ABAS[i]["icone"]), r.get_center(),
			TINTA if ativa else TINTA_FRACA)



## Os icones sao desenhados com primitivas, e nao lidos de arquivo. Sao seis
## silhuetas de doze pixels: um PNG para cada custaria seis arquivos e um passo
## de pipeline para o que cabe em quatro linhas.
func _icone_da_aba(qual: String, centro: Vector2, cor: Color) -> void:
	match qual:
		"rosto":
			draw_rect(Rect2(centro.x - 5.0, centro.y - 6.0, 10.0, 12.0), cor, false, 1.0)
			draw_rect(Rect2(centro.x - 3.0, centro.y - 2.0, 2.0, 2.0), cor)
			draw_rect(Rect2(centro.x + 1.0, centro.y - 2.0, 2.0, 2.0), cor)
			draw_rect(Rect2(centro.x - 2.0, centro.y + 3.0, 4.0, 1.0), cor)
		"cabelo":
			draw_rect(Rect2(centro.x - 5.0, centro.y - 1.0, 10.0, 7.0), cor, false, 1.0)
			draw_rect(Rect2(centro.x - 6.0, centro.y - 6.0, 12.0, 5.0), cor)
		"camisa":
			draw_colored_polygon(PackedVector2Array([
				centro + Vector2(-6.0, -5.0), centro + Vector2(-2.0, -5.0),
				centro + Vector2(0.0, -3.0), centro + Vector2(2.0, -5.0),
				centro + Vector2(6.0, -5.0), centro + Vector2(6.0, 0.0),
				centro + Vector2(4.0, 0.0), centro + Vector2(4.0, 6.0),
				centro + Vector2(-4.0, 6.0), centro + Vector2(-4.0, 0.0),
				centro + Vector2(-6.0, 0.0)]), cor)
		"calca":
			draw_rect(Rect2(centro.x - 5.0, centro.y - 6.0, 10.0, 4.0), cor)
			draw_rect(Rect2(centro.x - 5.0, centro.y - 2.0, 4.0, 8.0), cor)
			draw_rect(Rect2(centro.x + 1.0, centro.y - 2.0, 4.0, 8.0), cor)
		"chapeu":
			draw_rect(Rect2(centro.x - 7.0, centro.y + 1.0, 14.0, 2.0), cor)
			draw_colored_polygon(PackedVector2Array([
				centro + Vector2(-4.0, 1.0), centro + Vector2(-3.0, -5.0),
				centro + Vector2(3.0, -5.0), centro + Vector2(4.0, 1.0)]), cor)
		_:
			draw_rect(Rect2(centro.x - 2.0, centro.y - 6.0, 4.0, 4.0), cor)
			draw_rect(Rect2(centro.x - 4.0, centro.y - 1.0, 8.0, 4.0), cor)
			draw_rect(Rect2(centro.x - 3.0, centro.y + 3.0, 2.0, 4.0), cor)
			draw_rect(Rect2(centro.x + 1.0, centro.y + 3.0, 2.0, 4.0), cor)


## Publica: os campos da aba aberta. A navegacao e a verificacao leem daqui.
func campos_da_aba() -> Array:
	return ABAS[_aba]["campos"]


func _desenhar_campos() -> void:
	var x := PAGINA_DIR.position.x
	var y := 96.0
	for i in campos_da_aba().size():
		var campo := _campo(campos_da_aba()[i])
		var ativo := _linha == i + 1
		if ativo:
			draw_rect(Rect2(x - 3.0, y - 3.0, PAGINA_DIR.size.x - 6.0, 34.0),
				Color(0.79, 0.83, 0.72, 0.85))
		_texto(Vector2(x, y + 8.0), String(campo["rotulo"]),
			DESTAQUE if ativo else TINTA_FRACA)
		_desenhar_escolha(campo, Vector2(x, y + 12.0), ativo)
		y += 38.0


static func _campo(chave: StringName) -> Dictionary:
	for c: Dictionary in Aparencia.AJUSTES:
		if StringName(c["chave"]) == chave:
			return c
	return Aparencia.AJUSTES[0]


func _desenhar_escolha(campo: Dictionary, em: Vector2, ativo: bool) -> void:
	var chave: StringName = campo["chave"]
	var tipo := String(campo["tipo"])
	var largura := PAGINA_DIR.size.x - 12.0

	if tipo == "faixa":
		var minimo := float(campo["minimo"])
		var maximo := float(campo["maximo"])
		var t := clampf((float(_ajustes.get(chave, minimo)) - minimo)
			/ maxf(0.001, maximo - minimo), 0.0, 1.0)
		var barra := Rect2(em.x, em.y + 6.0, largura - 50.0, 6.0)
		draw_rect(barra, Color(0.70, 0.74, 0.64))
		draw_rect(Rect2(barra.position, Vector2(barra.size.x * t, barra.size.y)),
			DESTAQUE if ativo else TINTA_FRACA)
		draw_rect(Rect2(barra.position.x + barra.size.x * t - 2.0,
			barra.position.y - 3.0, 5.0, 12.0), TINTA)
		var valor_atual := float(_ajustes.get(chave, minimo))
		var texto := ("%.2f m" % valor_atual
			if chave == &"altura" else _nome_do_porte(t))
		_texto(Vector2(em.x + largura - 44.0, em.y + 14.0), texto, TINTA)
		return

	if tipo == "lista":
		var itens: Array = campo["itens"]
		var indice := int(_ajustes.get(chave, 0)) % itens.size()
		var passo := largura / float(itens.size())
		for k in itens.size():
			var r := Rect2(em.x + float(k) * passo, em.y + 2.0, passo - 2.0, 15.0)
			draw_rect(r, Color(0.87, 0.89, 0.80) if k == indice
				else Color(0.75, 0.78, 0.69))
			draw_rect(r, DESTAQUE if (k == indice and ativo) else TINTA_FRACA,
				false, 1.0)
			_texto(Vector2(r.position.x, r.position.y + 11.0),
				String(itens[k]).substr(0, 4), TINTA, _fonte,
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		return

	if tipo == "cor":
		var cores := Aparencia.paleta(String(campo["paleta"]))
		var atual: Color = _ajustes.get(chave, cores[0])
		var passo := largura / float(maxi(1, cores.size()))
		for k in cores.size():
			var r := Rect2(em.x + float(k) * passo, em.y + 3.0,
				maxf(4.0, passo - 1.0), 13.0)
			draw_rect(r, cores[k])
			if cores[k].is_equal_approx(atual):
				draw_rect(r.grow(1.0), DESTAQUE if ativo else TINTA, false, 1.0)
		return

	# Celula do atlas: mostra o desenho de verdade, e nao um numero.
	var quantos := int(campo["quantos"])
	var atual_i := int(_ajustes.get(chave, 0)) % quantos
	var linha := _linha_do_atlas(chave)
	var passo_cel := largura / float(quantos)
	for k in quantos:
		var r := Rect2(em.x + float(k) * passo_cel, em.y, passo_cel - 2.0, 18.0)
		if _atlas != null:
			draw_texture_rect_region(_atlas, r, Rect2(
				float(k * Aparencia.CELULA), float(linha * Aparencia.CELULA),
				float(Aparencia.CELULA), float(Aparencia.CELULA)))
		if k == atual_i:
			draw_rect(r.grow(1.0), DESTAQUE if ativo else TINTA, false, 1.0)


func _linha_do_atlas(chave: StringName) -> int:
	match chave:
		&"rosto":
			var ficha := RegistroCivil.jogador
			return (Aparencia.LINHA_ROSTO_F
				if StringName(ficha.get("sexo", &"M")) == &"F"
				else Aparencia.LINHA_ROSTO_M)
		&"cabelo":
			return Aparencia.LINHA_CABELO
		&"calca":
			return Aparencia.LINHA_CALCA
		_:
			return Aparencia.LINHA_CAMISA


## O visto de aceite, no canto de cima da pagina — o mesmo lugar da referencia.
func _desenhar_visto() -> void:
	var pronto := _linha == campos_da_aba().size() + 1
	var caixa := Rect2(PAGINA_DIR.end.x - 26.0, 26.0, 18.0, 18.0)
	draw_rect(caixa, Color(0.88, 0.9, 0.82))
	draw_rect(caixa, DESTAQUE if pronto else TINTA_FRACA, false, 1.0)
	var c := caixa.get_center()
	var cor := DESTAQUE if pronto else TINTA
	draw_line(c + Vector2(-5.0, 0.0), c + Vector2(-1.0, 4.0), cor, 2.0)
	draw_line(c + Vector2(-1.0, 4.0), c + Vector2(5.0, -5.0), cor, 2.0)
	if pronto:
		_texto(Vector2(PAGINA_DIR.end.x - 92.0, 40.0), "PRONTO", DESTAQUE)


## Zona de leitura no rodape, como no RG do inventario.
func _desenhar_zona() -> void:
	var ficha := RegistroCivil.jogador
	if ficha.is_empty():
		return
	var numero := String(ficha["cpf"]).replace(".", "").replace("-", "")
	var zona := "IDBRA%s<<%s" % [numero,
		String(ficha["sobrenome"]).replace(" ", "<")]
	_texto(Vector2(DOC.position.x + 10.0, DOC.end.y - 7.0), zona.substr(0, 44),
		TINTA_FRACA, _mono)


static func _nome_do_porte(t: float) -> String:
	if t < 0.2:
		return "MAGRO"
	if t < 0.4:
		return "SECO"
	if t < 0.62:
		return "MEDIO"
	if t < 0.82:
		return "FORTE"
	return "GORDO"


# --- entrada ----------------------------------------------------------------

## Publica: a verificacao mexe nos campos sem simular tecla.
func mudar(passo: int) -> void:
	if _linha == LINHA_ABAS:
		_aba = posmod(_aba + passo, ABAS.size())
		AudioDirector.tocar_ui(&"clique", -20.0)
		queue_redraw()
		return
	var indice := _linha - 1
	if indice >= campos_da_aba().size():
		return

	var campo := _campo(campos_da_aba()[indice])
	var chave: StringName = campo["chave"]
	match String(campo["tipo"]):
		"faixa":
			var minimo := float(campo["minimo"])
			var maximo := float(campo["maximo"])
			var atual := float(_ajustes.get(chave, minimo))
			# Vinte passos de ponta a ponta: menos e grosseiro, mais vira uma
			# viagem de teclado ate o outro extremo.
			_ajustes[chave] = clampf(atual + float(passo) * (maximo - minimo) / 20.0,
				minimo, maximo)
		"lista":
			var itens: Array = campo["itens"]
			_ajustes[chave] = posmod(int(_ajustes.get(chave, 0)) + passo, itens.size())
		"cor":
			var cores := Aparencia.paleta(String(campo["paleta"]))
			var atual_cor: Color = _ajustes.get(chave, cores[0])
			var i := 0
			for k in cores.size():
				if cores[k].is_equal_approx(atual_cor):
					i = k
					break
			_ajustes[chave] = cores[posmod(i + passo, cores.size())]
		_:
			var quantos := int(campo["quantos"])
			_ajustes[chave] = posmod(int(_ajustes.get(chave, 0)) + passo, quantos)

	AudioDirector.tocar_ui(&"clique", -18.0)
	_refazer_corpo()
	queue_redraw()


## Publica: escolhe a aba pelo nome, para a verificacao nao depender da ordem.
func ir_para_aba(nome: String) -> bool:
	for i in ABAS.size():
		if String(ABAS[i]["nome"]) == nome:
			_aba = i
			_linha = 1
			queue_redraw()
			return true
	return false


func confirmar() -> void:
	RegistroCivil.ajustar_jogador(_ajustes)
	AudioDirector.tocar_ui(&"pegar", -8.0)
	confirmou.emit()


func navegar(evento: InputEvent) -> void:
	var total := campos_da_aba().size() + 2
	if evento.is_action_pressed("mover_tras") or evento.is_action_pressed("ui_down"):
		_linha = posmod(_linha + 1, total)
		AudioDirector.tocar_ui(&"clique", -24.0)
	elif evento.is_action_pressed("mover_frente") or evento.is_action_pressed("ui_up"):
		_linha = posmod(_linha - 1, total)
		AudioDirector.tocar_ui(&"clique", -24.0)
	elif evento.is_action_pressed("mover_dir") or evento.is_action_pressed("ui_right"):
		mudar(1)
	elif evento.is_action_pressed("mover_esq") or evento.is_action_pressed("ui_left"):
		mudar(-1)
	elif evento.is_action_pressed("interagir") or evento.is_action_pressed("ui_accept"):
		if _linha == campos_da_aba().size() + 1:
			confirmar()
		else:
			mudar(1)
	elif evento.is_action_pressed("pausa"):
		voltou.emit()
	else:
		return
	queue_redraw()
