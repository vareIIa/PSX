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
const PAPEL := Color("ebe6d4")
const VINCO := Color("c4bba8")
const DESTAQUE := Color("8a2f1f")
## Capa azul do passaporte (print02) — filete sob o papel.
const CAPA := Color("2c4570")
const CELULA_SEL := Color("f4f1e6")

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
## Fundo de cabine atras da carteira: PackedScene 3D (preferido) ou PNG.
const CABINE_CENA := "res://scenes/player/cabine_fundo_criacao.tscn"
var _cabine: Texture2D
var _cabine_viewport: SubViewport
var _hover_aba: int = -1
var _hover_celula: int = -1
var _hover_visto: bool = false


func _ready() -> void:
	# Menu pausa a arvore nos paineis de papel; este Control precisa continuar
	# recebendo mouse e _process (balanco + hover) mesmo assim.
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_carregar_cabine()
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
	_viewport.process_mode = Node.PROCESS_MODE_ALWAYS
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
	camera.name = "CameraRetrato"
	# FOV um pouco mais aberto + look um pouco abaixo: ombro sobe no quadro e
	# o vão pescoco (Corpo) fica menos evidente no crop 3x4.
	camera.fov = 25.0
	camera.near = 0.05
	camera.position = Vector3(0.0, 1.34, -1.48)
	_viewport.add_child(camera)
	camera.look_at(Vector3(0.0, 1.34, 0.0), Vector3.UP)
	camera.current = true


## Refaz o corpo do retrato. A cada mudanca: o Corpo remonta em pouco mais de um
## milissegundo, e um retrato que so atualizasse ao confirmar seria adivinhar em
## vez de escolher.
func _refazer_corpo() -> void:
	if _corpo != null:
		_corpo.queue_free()
	_corpo = Corpo.new()
	_viewport.add_child(_corpo)
	var apar := aparencia_atual()
	_corpo.montar(apar)
	_corpo.rotation.y = _giro
	_corpo.animar(0.0, 0.016)
	_preencher_pescoco_retrato(apar)


## Publica: a verificacao le a aparencia montada sem abrir a tela.
func aparencia_atual() -> Dictionary:
	var ficha := RegistroCivil.jogador
	if ficha.is_empty():
		return Aparencia.de_ficha({"id": 7, "sexo": &"M", "idade": 31})
	return Aparencia.com_ajustes(Aparencia.de_ficha(ficha), _ajustes)


## Overlay 2D no 3x4: pinta pele+colarinho sobre o vão cabeça/tronco.
## Mais confiavel que malha 3D extra (BoneAttachment + balanco mole).
func _tapar_vao_pescoco_retrato() -> void:
	var apar := aparencia_atual()
	var pele := Aparencia.pele_na_tela(apar)
	var camisa: Color = (apar["casaco_cor"] if bool(apar.get("casaco", false))
		else apar["camisa_cor"])
	var cx := RETRATO.position.x + RETRATO.size.x * 0.5
	# Medido no capture: vão escuro em ~42–51% da altura do RETRATO.
	var y0 := RETRATO.position.y + RETRATO.size.y * 0.42
	draw_rect(Rect2(cx - 22.0, y0, 44.0, 24.0), pele)
	draw_rect(Rect2(cx - 18.0, y0 + 3.0, 36.0, 16.0), pele.darkened(0.10))
	draw_rect(Rect2(cx - 42.0, y0 + 18.0, 84.0, 24.0), camisa)
	draw_rect(Rect2(cx - 36.0, y0 + 20.0, 72.0, 8.0), camisa.lightened(0.08))


## So no retrato da carteira: o Corpo tem ~4 cm entre topo do tronco (y≈1,38)
## e a caixa da nuca (y≈1,425). Na rua some; no 3x4 vira "cabeca flutuando".
## Preenche localmente no osso da cabeca — nao mexe no Corpo global.
func _preencher_pescoco_retrato(apar: Dictionary) -> void:
	if _corpo == null:
		return
	var sk := _corpo.esqueleto()
	if sk == null:
		return
	var velho := sk.get_node_or_null("PescocoRetrato")
	if velho != null:
		velho.queue_free()
	var esc := float(apar.get("altura", 1.72)) / 1.72
	var att := BoneAttachment3D.new()
	att.name = "PescocoRetrato"
	att.bone_name = "cabeca"
	sk.add_child(att)
	# Abaixo do osso da cabeca (y local negativo) ate o ombro — bloco alto
	# o bastante para cobrir o vão mesmo com o balanco mole do pescoco.
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.17, 0.18 * esc, 0.15)
	mi.mesh = box
	mi.position = Vector3(0.0, -0.07 * esc, -0.03)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Aparencia.pele_na_tela(apar)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	att.add_child(mi)
	# Colarinho/ombro sob o pescoco (cor da camisa) — fecha contra o peito.
	var colo := MeshInstance3D.new()
	var box_c := BoxMesh.new()
	box_c.size = Vector3(0.30, 0.14 * esc, 0.20)
	colo.mesh = box_c
	colo.position = Vector3(0.0, -0.175 * esc, -0.02)
	var mat_c := StandardMaterial3D.new()
	var camisa: Color = (apar["casaco_cor"] if bool(apar.get("casaco", false))
		else apar["camisa_cor"])
	mat_c.albedo_color = camisa
	mat_c.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	colo.material_override = mat_c
	colo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	att.add_child(colo)


# --- abertura ---------------------------------------------------------------

func abrir() -> void:
	_ajustes = RegistroCivil.ajustes_do_jogador()
	_aba = 0
	_linha = LINHA_ABAS
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--criacao-aba="):
			ir_para_aba(a.trim_prefix("--criacao-aba="))
	_refazer_corpo()
	# A ficha pode nascer depois de a tela abrir — e o que acontece no caminho de
	# captura, e podia acontecer em qualquer ordem de inicializacao.
	if not RegistroCivil.jogador_mudou.is_connected(_ao_trocar_ficha):
		RegistroCivil.jogador_mudou.connect(_ao_trocar_ficha)
	queue_redraw()


## Liga retrato e fundo de cabine so enquanto a carteira esta aberta.
func _notification(o_que: int) -> void:
	if o_que != NOTIFICATION_VISIBILITY_CHANGED:
		return
	var modo := (SubViewport.UPDATE_ALWAYS
		if is_visible_in_tree() else SubViewport.UPDATE_DISABLED)
	if _viewport != null:
		_viewport.render_target_update_mode = modo
	if _cabine_viewport != null:
		_cabine_viewport.render_target_update_mode = modo


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
	# Cabine / interior atras da carteira. Preferencia: SubViewport 3D vivo
	# (sem HUD/LOCAL/HORA). Fallback: PNG estatico + mascara do canto.
	if _cabine_viewport != null:
		# Modulate sobe exposicao: a cabine live chega escura demais atras do
		# papel (e a vinheta do Menu ainda come um pouco). Sem lavar o documento.
		draw_texture_rect(_cabine_viewport.get_texture(), Rect2(Vector2.ZERO, TELA),
			false, Color(1.35, 1.28, 1.18, 1.0))
		draw_rect(Rect2(Vector2.ZERO, TELA), Color(0.01, 0.02, 0.03, 0.02))
	elif _cabine != null:
		draw_texture_rect(_cabine, Rect2(Vector2.ZERO, TELA), false)
		draw_rect(Rect2(Vector2.ZERO, TELA), Color(0.02, 0.03, 0.02, 0.22))
		# Esconde LOCAL:/HORA: bakeados no PNG da cabine (canto inf-dir).
		draw_rect(Rect2(275.0, 205.0, 205.0, 55.0), Color(0.02, 0.03, 0.02, 0.98))
	else:
		draw_rect(Rect2(Vector2.ZERO, TELA), Color(0.03, 0.04, 0.03, 0.42))

	_desenhar_papel()
	_desenhar_pagina_esquerda()
	_desenhar_pagina_direita()
	_desenhar_zona()
	# As maos por ULTIMO: os dedos passam por cima da borda de baixo do
	# documento, que e o que faz o papel parecer segurado em vez de colado na
	# tela. Desenhadas antes, elas sumiam inteiras atras dele.
	_desenhar_bracos()

	_texto(Vector2(0.0, 262.0),
		"[clique] abas/opcoes   [A/D] escolher   [W/S] campo   [E] ok   [ESC] voltar",
		Color(0.86, 0.83, 0.72), _fonte, HORIZONTAL_ALIGNMENT_CENTER, TELA.x)


## O papel entra torto. Coisa segurada na mao nao fica reta, e o jogo inteiro
## segue essa regra desde a prancha de inventario.
func _desenhar_papel() -> void:
	# Micro-balanco: documento vivo na mao, sem atrapalhar leitura.
	var osc := Vector2(sin(_relogio * 1.05) * 1.1, cos(_relogio * 0.85) * 0.9)
	var ang := INCLINACAO + sin(_relogio * 0.95) * 0.45
	draw_set_transform(DOC.position + osc + DOC.size * 0.5, deg_to_rad(ang),
		Vector2.ONE)
	var local := Rect2(-DOC.size * 0.5, DOC.size)
	# Capa azul do passaporte (print02): filete mais largo, como capa dura.
	draw_rect(Rect2(local.position + Vector2(-5.0, 3.0),
		Vector2(local.size.x + 10.0, local.size.y + 9.0)), CAPA)
	draw_rect(Rect2(local.position + Vector2(-4.0, 4.0),
		Vector2(local.size.x + 8.0, local.size.y + 7.0)), CAPA.lightened(0.08))
	draw_rect(Rect2(local.position + Vector2(3.0, 5.0), local.size),
		Color(0.02, 0.03, 0.02, 0.5))
	if _guilhoche != null:
		draw_texture_rect(_guilhoche, local, true, PAPEL)
	else:
		draw_rect(local, PAPEL)
	# Grade miuda de pagina (affordance passaporte) — so nas margens.
	var grade := Color(0.70, 0.66, 0.55, 0.18)
	for gx in range(1, 8):
		var gx_x := local.position.x + 8.0 + float(gx) * (local.size.x - 16.0) / 8.0
		draw_line(Vector2(gx_x, local.position.y + 8.0),
			Vector2(gx_x, local.end.y - 8.0), grade, 1.0)
	for gy in range(1, 5):
		var gy_y := local.position.y + 10.0 + float(gy) * (local.size.y - 20.0) / 5.0
		draw_line(Vector2(local.position.x + 8.0, gy_y),
			Vector2(local.end.x - 8.0, gy_y), grade, 1.0)
	draw_rect(local.grow(-3.0), Color(0.92, 0.89, 0.80, 0.28), false, 1.0)
	draw_rect(local.grow(-6.0), Color(CAPA.r, CAPA.g, CAPA.b, 0.22), false, 1.0)
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

	var balanco := Vector2(sin(_relogio * 1.05) * 1.0, cos(_relogio * 0.85) * 0.7)
	for lado: float in [-1.0, 1.0]:
		# Geometria do antebraco e punho
		var base_x := TELA.x * 0.5 + lado * 162.0
		var punho_x := TELA.x * 0.5 + lado * 92.0
		var base := Vector2(base_x, TELA.y + 30.0) + balanco
		var punho := Vector2(punho_x, 208.0) + balanco
		var eixo := (punho - base).normalized()
		var perp := Vector2(-eixo.y, eixo.x)
		# Lateral externa: +perp no braco esquerdo, -perp no direito.
		var ext := -1.0 if lado > 0.0 else 1.0

		# 1. Antebraco — quad convexo em ordem de contorno (sem bowtie).
		_poly4(base + perp * 28.0, base - perp * 28.0,
			punho - perp * 18.0, punho + perp * 18.0, manga)
		# Sombra na faixa externa (outer→inner→inner→outer).
		_poly4(
			base + perp * (ext * 28.0),
			base + perp * (ext * 10.0),
			punho + perp * (ext * 6.0),
			punho + perp * (ext * 18.0),
			manga_sombra)

		# 2. Punho / cuff
		var cuff_topo := punho + eixo * 9.0
		_poly4(punho - perp * 20.0, punho + perp * 20.0,
			cuff_topo + perp * 19.0, cuff_topo - perp * 19.0, manga_dobra)
		draw_line(punho - perp * 19.0, punho + perp * 19.0, manga_sombra, 1.5)

		# 3. Palma — larga, sobe por cima da borda do documento.
		var mao_base := cuff_topo + eixo * 1.0
		var palma_centro := mao_base + eixo * 16.0
		_poly4(
			mao_base - perp * 20.0,
			mao_base + perp * 20.0,
			palma_centro + perp * 21.0 + eixo * 8.0,
			palma_centro - perp * 19.0 + eixo * 8.0,
			tom_medio)
		# Eminencia tenar (volume na base do polegar).
		_poly4(
			mao_base - perp * (14.0 * ext),
			mao_base - perp * (4.0 * ext),
			palma_centro - perp * (6.0 * ext) + eixo * 2.0,
			palma_centro - perp * (16.0 * ext) + eixo * 2.0,
			tom_sombra.lightened(0.08))

		# 4. Dedos longos na borda inferior do documento.
		for i in 4:
			var offset_dedo := (float(i) - 1.5) * 7.8
			var d_origem := palma_centro + perp * (offset_dedo) + eixo * 5.0
			var d_ponta := d_origem + eixo * 26.0 - perp * (1.2 * lado)
			var d_larg := 4.0
			_poly4(
				d_origem - perp * d_larg,
				d_origem + perp * d_larg,
				d_ponta + perp * (d_larg - 0.8),
				d_ponta - perp * (d_larg - 0.8),
				pele if i % 2 == 0 else tom_medio)
			draw_line(d_ponta - perp * 2.0, d_ponta + perp * 2.0, tom_sombra, 1.0)

		# 5. Polegar sobre a margem do cartao.
		var pol_base := palma_centro - perp * (9.0 * lado) - eixo * 1.0
		var pol_junta := pol_base + Vector2(-lado * 18.0, -14.0)
		var pol_ponta := pol_junta + Vector2(-lado * 15.0, -9.0)
		var p_larg := 6.0
		_poly4(
			pol_base + perp * p_larg, pol_base - perp * p_larg,
			pol_junta - perp * (p_larg + 0.5), pol_junta + perp * (p_larg + 0.5),
			tom_medio)
		_poly4(
			pol_junta + perp * (p_larg + 0.5), pol_junta - perp * (p_larg + 0.5),
			pol_ponta - perp * (p_larg - 1.0), pol_ponta + perp * (p_larg - 1.0),
			pele)
		draw_line(pol_junta - Vector2(0.0, 3.0), pol_ponta - Vector2(0.0, 2.0),
			tom_luz, 1.2)
		var unha_pos := pol_ponta + Vector2(lado * 2.0, 0.0)
		_poly4(
			unha_pos + Vector2(-2.0, -2.0), unha_pos + Vector2(2.0, -2.0),
			unha_pos + Vector2(1.5, 2.0), unha_pos + Vector2(-1.5, 2.0),
			tom_luz.lightened(0.15))
		draw_line(pol_ponta + Vector2(-lado * 2.0, 4.0), pol_junta + Vector2(0.0, 5.0),
			Color(0.05, 0.08, 0.05, 0.5), 1.5)


## Quad convexo como dois triangulos. Evita "Invalid polygon data, triangulation
## failed" do draw_colored_polygon em quads com winding/ordem ambigua.
func _poly4(a: Vector2, b: Vector2, c: Vector2, d: Vector2, cor: Color) -> void:
	# Descarta degenerados (area ~0) antes de pedir triangulacao ao motor.
	if absf((b - a).cross(c - a)) < 0.35 and absf((c - a).cross(d - a)) < 0.35:
		return
	draw_colored_polygon(PackedVector2Array([a, b, c]), cor)
	draw_colored_polygon(PackedVector2Array([a, c, d]), cor)


func _desenhar_pagina_esquerda() -> void:
	if _brasao != null:
		draw_texture_rect(_brasao, Rect2(PAGINA_ESQ.position.x + 4.0, 26.0,
			18.0, 18.0), false)
	_texto(Vector2(PAGINA_ESQ.position.x + 26.0, 28.0), "REP. FED. DO BRASIL",
		Color(CAPA.r, CAPA.g, CAPA.b, 0.85), _fonte)
	_texto(Vector2(PAGINA_ESQ.position.x + 26.0, 39.0), "CARTEIRA DE", TINTA_FRACA)
	_texto(Vector2(PAGINA_ESQ.position.x + 26.0, 50.0), "IDENTIDADE", TINTA,
		_fonte_media)

	draw_rect(RETRATO.grow(2.0), TINTA)
	if _viewport != null:
		draw_texture_rect(_viewport.get_texture(), RETRATO, false)
	_tapar_vao_pescoco_retrato()
	# Cantoneiras do retrato 3x4 (passaporte).
	var c := RETRATO
	var k := 7.0
	var ck := Color(CAPA.r, CAPA.g, CAPA.b, 0.75)
	draw_line(c.position, c.position + Vector2(k, 0.0), ck, 1.5)
	draw_line(c.position, c.position + Vector2(0.0, k), ck, 1.5)
	draw_line(Vector2(c.end.x, c.position.y), Vector2(c.end.x - k, c.position.y), ck, 1.5)
	draw_line(Vector2(c.end.x, c.position.y), Vector2(c.end.x, c.position.y + k), ck, 1.5)
	draw_line(Vector2(c.position.x, c.end.y), Vector2(c.position.x + k, c.end.y), ck, 1.5)
	draw_line(Vector2(c.position.x, c.end.y), Vector2(c.position.x, c.end.y - k), ck, 1.5)
	draw_line(c.end, c.end - Vector2(k, 0.0), ck, 1.5)
	draw_line(c.end, c.end - Vector2(0.0, k), ck, 1.5)


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
	for i in ABAS.size():
		var r := _rect_aba(i)
		var ativa := i == _aba
		var hover := i == _hover_aba
		# Aba ativa sobe 2px (print02 raised tab). Hit-area permanece em _rect_aba.
		var visual := r
		if ativa:
			visual = Rect2(r.position.x, r.position.y - 2.0, r.size.x, r.size.y + 2.0)
			draw_rect(Rect2(visual.position + Vector2(1.0, 2.0), visual.size),
				Color(0.15, 0.12, 0.08, 0.28))
		var fill := (Color(0.93, 0.90, 0.80) if ativa
			else (Color(0.82, 0.80, 0.70) if hover else Color(0.74, 0.72, 0.62)))
		draw_rect(visual, fill)
		var borda := CELULA_SEL if ativa else (DESTAQUE if hover else TINTA_FRACA)
		draw_rect(visual, borda, false, 2.0 if ativa or hover else 1.0)
		if ativa and _linha == LINHA_ABAS:
			draw_rect(visual, DESTAQUE, false, 1.0)
		_icone_da_aba(String(ABAS[i]["icone"]), visual.get_center(),
			TINTA if ativa or hover else TINTA_FRACA)


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
	var y := 98.0
	for i in campos_da_aba().size():
		var campo := _campo(campos_da_aba()[i])
		var ativo := _linha == i + 1
		if ativo:
			draw_rect(Rect2(x - 3.0, y - 3.0, PAGINA_DIR.size.x - 6.0, 36.0),
				Color(0.86, 0.84, 0.74, 0.72))
		_texto(Vector2(x, y + 8.0), String(campo["rotulo"]),
			DESTAQUE if ativo else TINTA_FRACA)
		_desenhar_escolha(campo, Vector2(x, y + 12.0), ativo)
		y += 40.0


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
			var r := Rect2(em.x + float(k) * passo, em.y + 2.0, passo - 2.0, 16.0)
			var sel := k == indice
			var hov := ativo and k == _hover_celula
			draw_rect(r, Color(0.90, 0.88, 0.78) if sel
				else (Color(0.84, 0.82, 0.72) if hov else Color(0.76, 0.74, 0.64)))
			var borda := CELULA_SEL if sel else (DESTAQUE if hov else TINTA_FRACA)
			draw_rect(r.grow(1.0 if sel else 0.0), borda, false, 2.0 if sel else 1.0)
			_texto(Vector2(r.position.x, r.position.y + 12.0),
				String(itens[k]).substr(0, 4), TINTA, _fonte,
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		return

	if tipo == "cor":
		var cores := Aparencia.paleta(String(campo["paleta"]))
		var atual: Color = _ajustes.get(chave, cores[0])
		var passo := largura / float(maxi(1, cores.size()))
		for k in cores.size():
			var r := Rect2(em.x + float(k) * passo, em.y + 3.0,
				maxf(4.0, passo - 1.0), 14.0)
			draw_rect(r, cores[k])
			var sel := cores[k].is_equal_approx(atual)
			var hov := ativo and k == _hover_celula
			if sel:
				draw_rect(r.grow(1.5), CELULA_SEL, false, 2.0)
				if ativo:
					draw_rect(r.grow(2.5), DESTAQUE, false, 1.0)
			elif hov:
				draw_rect(r.grow(1.0), DESTAQUE, false, 1.0)
		return

	# Celula do atlas: mostra o desenho de verdade, e nao um numero.
	var quantos := int(campo["quantos"])
	var atual_i := int(_ajustes.get(chave, 0)) % quantos
	var linha := _linha_do_atlas(chave)
	var passo_cel := largura / float(quantos)
	for k in quantos:
		var r := Rect2(em.x + float(k) * passo_cel, em.y, passo_cel - 2.0, 20.0)
		draw_rect(r, Color(0.80, 0.78, 0.68, 0.55))
		# Grade interna leve (print02: celula clicavel).
		draw_rect(r.grow(-2.0), Color(0.55, 0.52, 0.42, 0.20), false, 1.0)
		if _atlas != null:
			draw_texture_rect_region(_atlas, r.grow(-1.0), Rect2(
				float(k * Aparencia.CELULA), float(linha * Aparencia.CELULA),
				float(Aparencia.CELULA), float(Aparencia.CELULA)))
		var sel := k == atual_i
		var hov := ativo and k == _hover_celula
		if sel:
			draw_rect(r.grow(1.0), CELULA_SEL, false, 2.0)
			if ativo:
				draw_rect(r.grow(2.0), DESTAQUE, false, 1.0)
		elif hov:
			draw_rect(r.grow(1.0), DESTAQUE, false, 1.0)


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
	var caixa := _rect_visto()
	draw_rect(Rect2(caixa.position + Vector2(1.0, 2.0), caixa.size),
		Color(0.12, 0.10, 0.08, 0.35))
	var fill := Color(0.94, 0.92, 0.84)
	if pronto:
		var pulso := 0.04 + 0.04 * sin(_relogio * 3.2)
		fill = Color(0.96, 0.90 + pulso, 0.78)
	draw_rect(caixa, fill)
	var borda := DESTAQUE if pronto or _hover_visto else TINTA_FRACA
	draw_rect(caixa, borda, false, 2.0 if (pronto or _hover_visto) else 1.5)
	var c := caixa.get_center()
	var cor := DESTAQUE if pronto or _hover_visto else TINTA
	draw_line(c + Vector2(-6.0, 0.0), c + Vector2(-1.0, 5.0), cor, 2.4)
	draw_line(c + Vector2(-1.0, 5.0), c + Vector2(7.0, -6.0), cor, 2.4)
	if pronto or _hover_visto:
		_texto(Vector2(PAGINA_DIR.end.x - 98.0, 42.0), "PRONTO", DESTAQUE)


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


# --- mouse / hit-areas ------------------------------------------------------

## Converte coordenada local do Control para o espaco logico 480x270 (TELA).
## Com stretch viewport o size costuma ja ser TELA; a conta cobre letterbox/escala.
func _para_tela(local: Vector2) -> Vector2:
	var s := size
	if s.x <= 1.0 or s.y <= 1.0:
		return local
	return Vector2(local.x * TELA.x / s.x, local.y * TELA.y / s.y)


func _rect_aba(i: int) -> Rect2:
	return Rect2(PAGINA_DIR.position.x + float(i) * 29.0, 68.0, 27.0, 20.0)


func _rect_visto() -> Rect2:
	return Rect2(PAGINA_DIR.end.x - 30.0, 24.0, 22.0, 22.0)


func _origem_campo(indice_campo: int) -> Vector2:
	return Vector2(PAGINA_DIR.position.x, 98.0 + float(indice_campo) * 40.0 + 12.0)


func _carregar_cabine() -> void:
	# Preferencia: PackedScene 3D (piloto FP). Fallback: PNG estatico.
	# Menu pausa a arvore em APARENCIA — SubViewport + cena em ALWAYS para o
	# micro-idle da cabine continuar (ver CabineFundoCriacao._process).
	if ResourceLoader.exists(CABINE_CENA):
		var packed := load(CABINE_CENA) as PackedScene
		if packed != null:
			_cabine_viewport = SubViewport.new()
			_cabine_viewport.name = "CabineFundo"
			_cabine_viewport.size = Vector2i(int(TELA.x), int(TELA.y))
			_cabine_viewport.own_world_3d = true
			_cabine_viewport.transparent_bg = false
			_cabine_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			_cabine_viewport.msaa_3d = Viewport.MSAA_DISABLED
			_cabine_viewport.process_mode = Node.PROCESS_MODE_ALWAYS
			add_child(_cabine_viewport)
			var cena := packed.instantiate()
			cena.process_mode = Node.PROCESS_MODE_ALWAYS
			_cabine_viewport.add_child(cena)
			print("[criacao] cabine live: %s" % CABINE_CENA)
			return

	# Interim Texture2D (+ mascara LOCAL/HORA no _draw).
	if ResourceLoader.exists(UI % "criacao_cabine"):
		_cabine = load(UI % "criacao_cabine") as Texture2D
		if _cabine != null:
			print("[criacao] cabine fallback PNG (asset)")
			return

	var candidatos: PackedStringArray = [
		"C:/Users/Administrator/Documents/Codes/Games/PSX/game/assets/ui/criacao_cabine.png",
		"C:/Users/Administrator/Documents/Codes/Games/PSX/captures/estrada_velha/cabine/fp_cabine_flag.png",
		"C:/Users/Administrator/Documents/Codes/Games/PSX/captures/estrada_velha/cabine/fp_01.png",
	]
	var raiz := ProjectSettings.globalize_path("res://")
	candidatos.append(raiz + "assets/ui/criacao_cabine.png")
	candidatos.append(raiz + "../captures/estrada_velha/cabine/fp_cabine_flag.png")
	for caminho: String in candidatos:
		var limpo := caminho.replace("\\", "/")
		while limpo.contains("/../"):
			# resolve um nivel: foo/bar/../x -> foo/x
			var i := limpo.find("/../")
			var esq := limpo.substr(0, i)
			var barra := esq.rfind("/")
			if barra < 0:
				break
			limpo = esq.substr(0, barra) + limpo.substr(i + 3)
		if not FileAccess.file_exists(limpo):
			continue
		var img := Image.new()
		if img.load(limpo) != OK:
			continue
		_cabine = ImageTexture.create_from_image(img)
		return


func _gui_input(evento: InputEvent) -> void:
	if evento is InputEventMouseButton:
		var mb := evento as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var pos := _para_tela(mb.position)
			if mb.pressed:
				if _clicar_em(pos):
					accept_event()
			else:
				if _arrastando_chave != &"":
					_arrastando_chave = &""
					_arrastando_campo = {}
					accept_event()
		return
	if evento is InputEventMouseMotion:
		var mm := evento as InputEventMouseMotion
		var pos := _para_tela(mm.position)
		if _arrastando_chave != &"" and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_arrastar_faixa(pos)
			accept_event()
		_atualizar_hover(pos)


func _atualizar_hover(pos: Vector2) -> void:
	var aba_antes := _hover_aba
	var cel_antes := _hover_celula
	var visto_antes := _hover_visto
	_hover_aba = -1
	_hover_celula = -1
	_hover_visto = _rect_visto().has_point(pos)
	for i in ABAS.size():
		if _rect_aba(i).has_point(pos):
			_hover_aba = i
			break
	if _hover_aba < 0 and not _hover_visto:
		for i in campos_da_aba().size():
			var campo := _campo(campos_da_aba()[i])
			var idx := _indice_celula_em(campo, _origem_campo(i), pos)
			if idx >= 0:
				_hover_celula = idx
				break
	if aba_antes != _hover_aba or cel_antes != _hover_celula or visto_antes != _hover_visto:
		queue_redraw()
	mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND
		if _hover_aba >= 0 or _hover_celula >= 0 or _hover_visto
		else Control.CURSOR_ARROW)


func _clicar_em(pos: Vector2) -> bool:
	if _rect_visto().has_point(pos):
		_linha = campos_da_aba().size() + 1
		AudioDirector.tocar_ui(&"clique", -16.0)
		queue_redraw()
		confirmar()
		return true
	for i in ABAS.size():
		if _rect_aba(i).has_point(pos):
			_aba = i
			_linha = LINHA_ABAS
			AudioDirector.tocar_ui(&"clique", -20.0)
			queue_redraw()
			return true
	for i in campos_da_aba().size():
		var campo := _campo(campos_da_aba()[i])
		if _aplicar_clique_campo(campo, _origem_campo(i), pos, i):
			return true
	return false


func _indice_celula_em(campo: Dictionary, em: Vector2, pos: Vector2) -> int:
	var chave: StringName = campo["chave"]
	var tipo := String(campo["tipo"])
	var largura := PAGINA_DIR.size.x - 12.0
	if tipo == "faixa":
		var barra := Rect2(em.x, em.y + 2.0, largura - 50.0, 14.0)
		return 0 if barra.has_point(pos) else -1
	if tipo == "lista":
		var itens: Array = campo["itens"]
		var passo := largura / float(itens.size())
		for k in itens.size():
			var r := Rect2(em.x + float(k) * passo, em.y + 2.0, passo - 2.0, 16.0)
			if r.has_point(pos):
				return k
		return -1
	if tipo == "cor":
		var cores := Aparencia.paleta(String(campo["paleta"]))
		var passo := largura / float(maxi(1, cores.size()))
		for k in cores.size():
			var r := Rect2(em.x + float(k) * passo, em.y + 3.0,
				maxf(4.0, passo - 1.0), 14.0)
			if r.has_point(pos):
				return k
		return -1
	var quantos := int(campo["quantos"])
	var passo_cel := largura / float(quantos)
	for k in quantos:
		var r := Rect2(em.x + float(k) * passo_cel, em.y, passo_cel - 2.0, 20.0)
		if r.has_point(pos):
			return k
	return -1


func _aplicar_clique_campo(campo: Dictionary, em: Vector2, pos: Vector2,
		indice_linha: int) -> bool:
	var chave: StringName = campo["chave"]
	var tipo := String(campo["tipo"])
	var largura := PAGINA_DIR.size.x - 12.0
	var idx := _indice_celula_em(campo, em, pos)
	if idx < 0:
		return false
	_linha = indice_linha + 1
	match tipo:
		"faixa":
			_arrastando_chave = chave
			_arrastando_campo = campo
			_arrastar_faixa(pos)
			AudioDirector.tocar_ui(&"clique", -18.0)
			return true
		"lista":
			_ajustes[chave] = idx
		"cor":
			var cores := Aparencia.paleta(String(campo["paleta"]))
			_ajustes[chave] = cores[idx]
		_:
			_ajustes[chave] = idx
	AudioDirector.tocar_ui(&"clique", -18.0)
	_refazer_corpo()
	queue_redraw()
	return true


func _arrastar_faixa(pos: Vector2) -> void:
	if _arrastando_chave == &"" or _arrastando_campo.is_empty():
		return
	var campo := _arrastando_campo
	var chave: StringName = _arrastando_chave
	var minimo := float(campo["minimo"])
	var maximo := float(campo["maximo"])
	# Descobre a origem Y pelo indice atual do campo na aba.
	var em := Vector2(PAGINA_DIR.position.x, 108.0)
	for i in campos_da_aba().size():
		if campos_da_aba()[i] == chave:
			em = _origem_campo(i)
			break
	var largura := PAGINA_DIR.size.x - 12.0
	var barra := Rect2(em.x, em.y + 6.0, largura - 50.0, 6.0)
	var t := clampf((pos.x - barra.position.x) / maxf(1.0, barra.size.x), 0.0, 1.0)
	_ajustes[chave] = lerpf(minimo, maximo, t)
	_refazer_corpo()
	queue_redraw()
