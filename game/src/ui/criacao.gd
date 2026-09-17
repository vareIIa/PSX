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

## A carteira aberta, e TODO o resto do documento sai destes quatro numeros.
##
## Antes daqui cada peca trazia a propria coordenada absoluta: as duas paginas,
## o retrato, a primeira linha de campo, a fileira de abas, o visto e a altura
## da pega das maos. Sete lugares para o mesmo valor. Descer a carteira trinta
## pixels significava achar os sete, e o que ficasse para tras so aparecia em
## captura — o visto flutuando fora do papel, a aba na altura errada. Ja
## aconteceu, e o comentario de `LINHA_UM` ja avisava que ia acontecer de novo.
##
## Agora move-se `DOC_Y` e a carteira inteira desce junto.
const DOC_X := CarteiraLayout.DOC_X
const DOC_Y := CarteiraLayout.DOC_Y
const DOC_L := CarteiraLayout.DOC_L
const DOC_A := CarteiraLayout.DOC_A
const DOC := CarteiraLayout.DOC

## A carteira fica RETA.
##
## Ela entrava com 1,4 grau de inclinacao, pela regra da casa de que coisa
## segurada na mao nao fica reta — a mesma da prancha de inventario. Numa
## prancha de madeira aquilo le como peso; num documento de 308 por 156 numa
## tela de 480 por 270, com texto miudo e um retrato retangular dentro, le como
## imagem torta. O papel continua respirando: `_angulo_doc` mantem um balanco de
## um sexto de grau, que e movimento sem ser tortura de linha reta.
const INCLINACAO := 0.0
const PAGINA_ESQ := CarteiraLayout.PAGINA_ESQ
const PAGINA_DIR := CarteiraLayout.PAGINA_DIR
const RETRATO := CarteiraLayout.RETRATO

const TINTA := Color("22301f")
const TINTA_FRACA := Color("5c6b52")
const PAPEL := Color("ebe6d4")
const VINCO := Color("c4bba8")
const DESTAQUE := Color("8a2f1f")
## Capa azul do passaporte (print02) — filete sob o papel.
const CAPA := Color("2c4570")
const CELULA_SEL := Color("f4f1e6")

## Abas de categoria. Cada uma diz quais campos de Aparencia.AJUSTES mostra.
## As abas moram em `CarteiraLayout`: e a aba mais cheia que decide a altura
## do documento, e quem mede isso e o teste.
const ABAS := CarteiraLayout.ABAS


## Primeira linha navegavel: a fileira de abas. Depois vem um campo por linha, e
## por ultimo o visto de aceite.
const LINHA_ABAS := 0

## Onde a primeira linha de campo comeca, em pixels de tela.
##
## E uma constante e nao um numero solto porque a carteira encolheu uma vez e
## vai encolher de novo: com a altura escrita em cada funcao, mudar a folha
## significa cacar o mesmo numero em quatro lugares e descobrir na captura o que
## ficou para tras. A altura de cada linha vem de `_altura_do_campo`.
const LINHA_UM := CarteiraLayout.LINHA_UM
const CAMPO_ROTULO := CarteiraLayout.CAMPO_ROTULO
const CAMPO_RESPIRO := CarteiraLayout.CAMPO_RESPIRO
const CAMPO_WIDGET := CarteiraLayout.CAMPO_WIDGET
const CAMPOS_FUNDO := CarteiraLayout.CAMPOS_FUNDO

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
var _vinheta: Texture2D
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
	# `set_anchors_and_offsets_preset`, e nao `set_anchors_preset`.
	#
	# A versao sem offsets PRESERVA o retangulo que o Control tem na hora, e na
	# hora ele nao tem nenhum: nasce zero por zero e as offsets sao calculadas
	# para manter zero por zero. Depois o pai cresce, as ancoras acompanham, e
	# as offsets negativas anulam o crescimento — o Control fica com area zero
	# para sempre. Desenha certo (draw_* nao le o retangulo) e nao recebe clique
	# nenhum: era esta linha que deixava "[clique] abas/opcoes" mentindo no
	# rodape desta tela.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_carregar_cabine()
	_atlas = load(ATLAS) as Texture2D
	_fonte = load(FONTE_P) as Font
	_fonte_media = load(FONTE_M) as Font
	_mono = load(FONTE_MONO) as Font
	if ResourceLoader.exists(UI % "doc_guilhoche"):
		_guilhoche = load(UI % "doc_guilhoche") as Texture2D
	if ResourceLoader.exists(UI % "doc_brasao"):
		_brasao = load(UI % "doc_brasao") as Texture2D
	if ResourceLoader.exists(UI % "ui_vinheta"):
		_vinheta = load(UI % "ui_vinheta") as Texture2D
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
	camera.position = Vector3(0.0, ALTURA_REF - RETRATO_ABAIXO, -RETRATO_DIST)
	_viewport.add_child(camera)
	camera.look_at(Vector3(0.0, ALTURA_REF - RETRATO_ABAIXO, 0.0), Vector3.UP)
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
	_enquadrar_retrato(float(apar.get("altura", ALTURA_REF)))


## A foto 3x4 acompanha a altura de quem esta nela.
##
## A lente estava cravada em y = 1,34, e a conta diz que ela cortava a cabeca.
##
## A janela mostra 0,655 m de mundo na vertical: duas vezes 1,48 m de distancia
## vezes a tangente de 12,5°, que e metade do FOV de 25. Com o centro em 1,34, o
## topo do quadro cai em 1,67 — quatro centimetros ABAIXO do alto da cabeca de
## quem tem 1,72 m, e mais ainda de quem puxa o deslizador de ALTURA para cima.
## O corte aparecia em toda ficha de pessoa alta, e a captura do CORPO com 1,73 m
## mostra o topo da cabeca encostado na moldura.
##
## Entao a lente deixa de ser altura fixa e passa a ser DISTANCIA ate o alto da
## cabeca: centro = altura + folga − metade da janela = altura − 0,27. Assim a
## foto e a mesma foto para 1,50 m e para 2,00 m, que e o que uma foto 3x4 e.
const ALTURA_REF := 1.72
const RETRATO_ABAIXO := 0.27
const RETRATO_DIST := 1.48


func _enquadrar_retrato(altura: float) -> void:
	var cam := _viewport.get_node_or_null("CameraRetrato") as Camera3D
	if cam == null:
		return
	var linha := clampf(altura, 1.40, 2.05) - RETRATO_ABAIXO
	cam.position = Vector3(0.0, linha, -RETRATO_DIST)
	cam.look_at(Vector3(0.0, linha, 0.0), Vector3.UP)


## Publica: a verificacao le a aparencia montada sem abrir a tela.
func aparencia_atual() -> Dictionary:
	var ficha := RegistroCivil.jogador
	if ficha.is_empty():
		return Aparencia.de_ficha({"id": 7, "sexo": &"M", "idade": 31})
	return Aparencia.com_ajustes(Aparencia.de_ficha(ficha), _ajustes)


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
	# O PESCOCO, e nao um tapume.
	#
	# O que havia aqui eram duas caixas dimensionadas para TAPAR: uma de dezessete
	# centimetros de largura por dezoito de altura empurrada tres centimetros
	# para a FRENTE, e um "colo" de trinta por vinte por baixo. Fora da tela do
	# retrato, empurradas para frente do torso, elas nao liam como pescoco: liam
	# como um bloco claro pendurado na frente do peito. Era esse o bloco fixo
	# que aparecia no meio da foto.
	#
	# Um pescoco tem largura de pescoco e fica no eixo do corpo. Onze por doze
	# por onze, centrado em Z, encaixa entre a cabeca e os ombros e some — que e
	# a definicao de sucesso para uma peca que so existe para nao ter buraco.
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	# Alto o bastante para ENTRAR no tronco, e nao so para encostar nele. Com
	# doze centimetros ele parava no ar e o vao reaparecia logo abaixo: a peca
	# tem de mergulhar dentro dos ombros, onde o excesso fica escondido.
	box.size = Vector3(0.125, 0.24 * esc, 0.115)
	mi.mesh = box
	mi.position = Vector3(0.0, -0.135 * esc, 0.0)
	var mat := StandardMaterial3D.new()
	# Sombreado, e nao chapado. Com `UNSHADED` o pescoco sai no tom cheio da
	# pele enquanto cabeca e tronco recebem a luz do estudio do retrato — e o
	# pedaco mais claro da foto passa a ser justamente o que devia sumir.
	mat.albedo_color = Aparencia.pele_na_tela(apar).darkened(0.12)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	att.add_child(mi)


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


## Liga o retrato so enquanto a carteira esta aberta.
##
## A cabine NAO entra aqui: ela vive mais que esta tela. A ficha de cadastro, que
## vem imediatamente antes, desenha o mesmo fundo — as duas telas sao o mesmo
## carro parado no mesmo minuto — entao quem liga e desliga a cabine e o Menu,
## por `ativar_fundo`, e nao a visibilidade deste Control.
func _notification(o_que: int) -> void:
	if o_que != NOTIFICATION_VISIBILITY_CHANGED:
		return
	if _viewport != null:
		_viewport.render_target_update_mode = (SubViewport.UPDATE_ALWAYS
			if is_visible_in_tree() else SubViewport.UPDATE_DISABLED)


## A cabine viva, para quem mais precisar dela desenhar.
##
## Um SubViewport de mundo proprio custa uma estrada, um carro e um ceu; dois
## deles para mostrar a mesma coisa em duas telas seguidas seria pagar duas
## vezes por um plano so — e as duas versoes divergiriam no primeiro ajuste.
func textura_cabine() -> Texture2D:
	if _cabine_viewport != null:
		return _cabine_viewport.get_texture()
	return _cabine


## Liga ou desliga a renderizacao da cabine.
##
## Um SubViewport nao para de desenhar so porque ninguem esta olhando: ele e um
## alvo proprio e continuaria montando estrada, carro e nevoa a sessenta quadros
## por segundo pela partida inteira.
func ativar_fundo(ligado: bool) -> void:
	if _cabine_viewport == null:
		return
	_cabine_viewport.render_target_update_mode = (SubViewport.UPDATE_ALWAYS
		if ligado else SubViewport.UPDATE_DISABLED)


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
		# Modulate NEUTRO, e essa e a terceira e ultima parada de um numero que ja
		# foi 1,35 e depois 1,10.
		#
		# Ele existia para compensar um fundo escuro demais, e cada vez que o
		# fundo era consertado o compensador sobrava. Agora o que chega aqui e a
		# Estrada Velha com a nevoa da propria estrada e a cabine acesa por uma
		# lampada de teto: ja esta exposta como a cena que vem no corte seguinte,
		# e qualquer ganho aqui e uma segunda exposicao por cima da primeira —
		# que aparece primeiro nos pretos, levantando-os, e e exatamente a
		# diferenca que separava esta tela do plano DENTRO da cena.
		draw_texture_rect(_cabine_viewport.get_texture(), Rect2(Vector2.ZERO, TELA),
			false, Color(1.0, 1.0, 1.0, 1.0))
		draw_rect(Rect2(Vector2.ZERO, TELA), Color(0.01, 0.02, 0.03, 0.02))
		# Mesma vinheta da ficha, que e a tela imediatamente anterior. Duas telas
		# seguidas no mesmo carro nao podem ter cantos fotografados por regras
		# diferentes: a troca de painel passa a ler como troca de camera.
		if _vinheta != null:
			draw_texture_rect(_vinheta, Rect2(Vector2.ZERO, TELA), false,
				Color(1.0, 1.0, 1.0, 0.62))
	elif _cabine != null:
		draw_texture_rect(_cabine, Rect2(Vector2.ZERO, TELA), false)
		draw_rect(Rect2(Vector2.ZERO, TELA), Color(0.02, 0.03, 0.02, 0.22))
		# Esconde LOCAL:/HORA: bakeados no PNG da cabine (canto inf-dir).
		draw_rect(Rect2(275.0, 205.0, 205.0, 55.0), Color(0.02, 0.03, 0.02, 0.98))
	else:
		draw_rect(Rect2(Vector2.ZERO, TELA), Color(0.03, 0.04, 0.03, 0.42))

	# `--so-fundo`: desenha a cabine e para.
	#
	# Bandeira de captura, e permanente por merecimento. Toda pergunta sobre a
	# CENA desta tela — o volante esta no lugar? a lampada acende o forro? o
	# carro andou? — precisa olhar o fundo sem o documento em cima, e ate agora
	# isso vinha sendo feito com remendo temporario que era esquecido no arquivo
	# na metade das vezes. Mesmo padrao de `--nome-teste=` e `--criacao-aba=`.
	if OS.get_cmdline_user_args().has("--so-fundo"):
		return

	# A ordem das camadas E o efeito de segurar. A mao inteira entra ANTES do
	# papel, e o papel come tudo o que passa por tras dele; depois das paginas
	# volta so o polegar, na margem lateral, que e a unica parte da mao que fica
	# na frente de um documento que alguem esta segurando. Ver `_desenhar_maos`.
	_desenhar_maos()
	_desenhar_papel()
	_desenhar_pagina_esquerda()
	_desenhar_pagina_direita()
	_desenhar_zona()
	_desenhar_sombra_das_maos()
	_desenhar_polegares()

	# Tarja atras da dica, como na ficha. Sem ela o texto claro caia metade sobre
	# o painel escuro e metade sobre a madeira clara do console, e a segunda
	# metade sumia.
	draw_rect(Rect2(0.0, 256.0, TELA.x, 14.0), Color(0.03, 0.035, 0.04, 0.72))
	_texto(Vector2(0.0, 266.0),
		"[clique] abas/opcoes   [A/D] escolher   [W/S] campo   [E] ok   [ESC] voltar",
		Color(0.90, 0.87, 0.78), _fonte, HORIZONTAL_ALIGNMENT_CENTER, TELA.x)


## O micro-balanco do documento, num lugar so.
##
## Papel, polegares e maos tem de andar JUNTOS. Se cada um recalcular o proprio
## seno, eles divergem no primeiro ajuste e o polegar descola da borda que esta
## segurando — defeito que nao aparece em captura parada e que ninguem deixa de
## ver em movimento.
##
## Amplitude de carro PARADO, e ja foi o triplo disso.
##
## O fundo desta tela e um carro encostado no acostamento, medido e conferido:
## a mata atras da janela nao anda um pixel. Mesmo assim a tela lia como carro
## em movimento, e a culpa era daqui — o documento ocupa tres quartos do quadro,
## e um documento gingando tres quartos de quadro E o balanco de quem esta
## andando. Mao parada tambem treme, so que em fracao de pixel e devagar.
func _balanco_doc() -> Vector2:
	return Vector2(sin(_relogio * 0.66) * 0.40, cos(_relogio * 0.54) * 0.32)


func _angulo_doc() -> float:
	return INCLINACAO + sin(_relogio * 0.60) * 0.16


## O papel entra torto. Coisa segurada na mao nao fica reta, e o jogo inteiro
## segue essa regra desde a prancha de inventario.
func _desenhar_papel() -> void:
	draw_set_transform(DOC.position + _balanco_doc() + DOC.size * 0.5,
		deg_to_rad(_angulo_doc()), Vector2.ONE)
	var local := Rect2(-DOC.size * 0.5, DOC.size)
	# Capa azul do passaporte (print02): filete mais largo, como capa dura.
	draw_rect(Rect2(local.position + Vector2(-5.0, 3.0),
		Vector2(local.size.x + 10.0, local.size.y + 9.0)), CAPA)
	draw_rect(Rect2(local.position + Vector2(-4.0, 4.0),
		Vector2(local.size.x + 8.0, local.size.y + 7.0)), CAPA.lightened(0.08))
	# Sombra so na borda: com o papel translucido, uma mancha do tamanho da folha
	# apareceria atraves dela.
	draw_rect(Rect2(local.position.x + 3.0, local.end.y, local.size.x, 5.0),
		Color(0.02, 0.03, 0.02, 0.45))
	draw_rect(Rect2(local.end.x, local.position.y + 5.0, 3.0, local.size.y),
		Color(0.02, 0.03, 0.02, 0.45))
	# O papel 2D entra TRANSLUCIDO, por cima da folha 3D.
	#
	# A folha e um quad de verdade dentro da cabine, acesa pela luz de teto (ver
	# `CabineFundoCriacao.pedir_folha`). Opaca por cima dela, a camada 2D
	# apagava a iluminacao inteira; ausente, a tinta escura ficava sobre papel de
	# quarenta e nove de 255 e a carteira parava de ser legivel — que e a queixa
	# que abriu esta tela.
	#
	# Meio a meio: a leitura fica garantida pela camada pintada e o que a lampada
	# faz no papel atravessa. Acender e apagar a luz do teto muda a carteira.
	if _guilhoche != null:
		draw_texture_rect(_guilhoche, local, true, PAPEL)
	else:
		draw_rect(local, PAPEL)
	_desenhar_seguranca(local)
	draw_rect(local.grow(-3.0), Color(0.92, 0.89, 0.80, 0.28), false, 1.0)
	draw_rect(local.grow(-6.0), Color(CAPA.r, CAPA.g, CAPA.b, 0.22), false, 1.0)
	draw_rect(local, TINTA_FRACA, false, 1.0)
	# Vinco do meio: e o que faz duas paginas em vez de um cartaz.
	draw_rect(Rect2(-1.0, local.position.y + 6.0, 2.0, local.size.y - 12.0), VINCO)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Os elementos de seguranca do documento: guilhoche em onda e a faixa do
## holograma.
##
## O que havia aqui era uma grade de oito por cinco atravessando a carteira
## inteira. Grade grossa e regular nao le como papel-moeda nem como documento:
## le como PLANILHA, e era ela que fazia o cartao parecer um painel de menu com
## texto em cima.
##
## O que um documento tem no lugar disso e guilhoche — a onda fina e continua
## que a impressora de seguranca desenha e que ninguem consegue reproduzir numa
## copiadora. Aqui sao senos de periodos incomensuraveis, num alfa tao baixo que
## de longe le como textura de papel e de perto le como impressao.
##
## E a FAIXA: a banda diagonal translucida do holograma. E o unico elemento que
## diz "documento oficial" sozinho, sem texto nenhum, e e o que amarra as duas
## paginas numa peca so em vez de duas colunas lado a lado.
func _desenhar_seguranca(local: Rect2) -> void:
	var linha := Color(CAPA.r, CAPA.g, CAPA.b, 0.10)
	var passo := 7.0
	var y := local.position.y + 10.0
	while y < local.end.y - 8.0:
		var pontos := PackedVector2Array()
		var x := local.position.x + 6.0
		while x < local.end.x - 6.0:
			# Dois senos em razao irracional: um so repete o desenho a cada
			# volta e a onda vira listra.
			var ondulado := sin(x * 0.11 + y * 0.05) * 1.7 + sin(x * 0.043) * 1.1
			pontos.append(Vector2(x, y + ondulado))
			x += 6.0
		if pontos.size() > 1:
			draw_polyline(pontos, linha, 1.0)
		y += passo

	# A faixa do holograma, atravessando de baixo a esquerda para cima a
	# direita. Duas bandas paralelas com uma aresta clara entre elas: e o que da
	# a impressao de pelicula, e nao de mancha.
	var largura := local.size.x
	var altura := local.size.y
	for k in 2:
		var desloc := -largura * 0.10 + float(k) * largura * 0.16
		var esp := 34.0 - float(k) * 12.0
		var faixa := PackedVector2Array([
			Vector2(local.position.x + desloc, local.end.y),
			Vector2(local.position.x + desloc + esp, local.end.y),
			Vector2(local.position.x + desloc + esp + altura * 0.55,
				local.position.y),
			Vector2(local.position.x + desloc + altura * 0.55, local.position.y),
		])
		# So o preenchimento, sem aresta desenhada. Uma linha clara na beirada
		# da faixa nao le como pelicula: le como RISCO no papel, e a carteira
		# passa a parecer arranhada em vez de holografada.
		draw_colored_polygon(faixa, Color(0.72, 0.86, 0.80, 0.06))


## Onde a mao encosta na carteira, em altura de tela.
##
## Perto do canto de baixo. Com o olho virado para o colo, o documento e o que
## esta em cima e as maos vem de BAIXO — que e a unica coisa que a versao
## anterior nao tinha: ela punha as maos nas laterais, na altura do meio da
## folha, que e onde a mao fica quando alguem segura um papel na frente do
## rosto. Nao e essa a pose.
const PEGA_Y := DOC_Y + 146.0

## Meio caminho entre a borda do papel e a beirada da tela, para cada lado.
const MAO_LARGURA := 46.0


## As maos que seguram a carteira, em quatro formas por mao.
##
## Solucao simples, e a simplicidade e a decisao
## ----------------------------------------------
## As versoes anteriores tinham antebraco, punho, dorso, monte do polegar, quatro
## dedos com contorno individual, vinco entre eles e unha: doze formas por mao,
## dentro de uma faixa de quarenta e seis pixels. Nesse tamanho, doze formas nao
## somam uma mao — elas viram uma mancha com riscos dentro, e cada rodada de
## detalhe piorava, porque o problema nunca foi falta de detalhe.
##
## O que le a esta distancia e SILHUETA e VALOR. Entao sao quatro formas: a
## manga, o dorso arredondado com tres reentrancias que sugerem os nos, o
## polegar por cima do papel e a sombra que a mao joga nele. Nada de dedo
## individual, nada de unha, nada de vinco.
##
## A ordem continua sendo o truque: manga e dorso ANTES do papel — o papel come
## o que passa por tras — e so o polegar depois, porque polegar e a unica parte
## da mao que fica na frente de um documento que alguem segura.
func _desenhar_maos() -> void:
	var a := aparencia_atual()
	var pele := Aparencia.pele_na_tela(a)
	var manga: Color = (a["casaco_cor"] if bool(a.get("casaco", false))
		else a["camisa_cor"])
	# Exposicao de cabine noturna: a carne base sai escurecida e quem devolve a
	# forma e a aresta virada para o papel, que e o refletor do quadro.
	var carne := pele.darkened(0.40)
	var funda := pele.darkened(0.70)
	var aresta := pele.lightened(0.08)
	var tecido := manga.darkened(0.58)
	var osc := _balanco_doc()

	for lado: float in [-1.0, 1.0]:
		var bx := (DOC.position.x if lado < 0.0 else DOC.end.x) + osc.x
		# A direita pega um pouco mais embaixo: duas maos na mesma altura leem
		# como decalque espelhado.
		var py := PEGA_Y + osc.y + (0.0 if lado < 0.0 else 5.0)
		var cx := bx + lado * 6.0

		# 1. Manga, subindo do rodape da tela.
		_poly4(
			Vector2(cx - lado * MAO_LARGURA * 0.34, py + 26.0),
			Vector2(cx + lado * MAO_LARGURA * 0.46, py + 30.0),
			Vector2(cx + lado * MAO_LARGURA * 0.66, TELA.y + 12.0),
			Vector2(cx - lado * MAO_LARGURA * 0.44, TELA.y + 12.0),
			tecido)
		draw_line(Vector2(cx - lado * MAO_LARGURA * 0.34, py + 26.0),
			Vector2(cx - lado * MAO_LARGURA * 0.44, TELA.y + 12.0),
			manga.darkened(0.30), 1.5)

		# 2. Dorso: uma forma so, com o alto arredondado.
		var dorso := PackedVector2Array([
			Vector2(cx - lado * MAO_LARGURA * 0.40, py - 6.0),
			Vector2(cx - lado * MAO_LARGURA * 0.24, py - 14.0),
			Vector2(cx + lado * MAO_LARGURA * 0.22, py - 15.0),
			Vector2(cx + lado * MAO_LARGURA * 0.44, py - 7.0),
			Vector2(cx + lado * MAO_LARGURA * 0.50, py + 18.0),
			Vector2(cx + lado * MAO_LARGURA * 0.40, py + 29.0),
			Vector2(cx - lado * MAO_LARGURA * 0.34, py + 27.0),
		])
		draw_colored_polygon(dorso, carne)
		draw_polyline(dorso, funda, 1.0)
		draw_line(dorso[6], dorso[0], funda, 1.0)

		# 3. Tres reentrancias no alto: os nos dos dedos que entram atras do
		#    papel. Tres riscos curtos fazem o que quatro dedos desenhados nao
		#    faziam, porque aqui o que falta e separacao, nao anatomia.
		for k in 3:
			var t := 0.26 + float(k) * 0.24
			var nx := cx + lado * MAO_LARGURA * (t - 0.36)
			draw_line(Vector2(nx, py - 13.0), Vector2(nx, py - 3.0), funda, 1.4)
		# Aresta acesa na beirada virada para o documento.
		draw_line(dorso[3], dorso[4], aresta, 1.5)


## Os polegares, por cima do papel. Um por mao, dois segmentos, sem unha.
##
## Chamado por `_draw` DEPOIS das paginas, e nao de dentro de `_desenhar_maos`:
## sendo desenhado junto com o resto da mao ele saia antes do papel e sumia
## atras dele, e a mao voltava a ler como mao ATRAS da carteira.
func _desenhar_polegares() -> void:
	var a := aparencia_atual()
	var pele := Aparencia.pele_na_tela(a)
	var funda := pele.darkened(0.70)
	var osc := _balanco_doc()
	var meia := pele.darkened(0.16)
	for lado: float in [-1.0, 1.0]:
		var bx := (DOC.position.x if lado < 0.0 else DOC.end.x) + osc.x
		var py := PEGA_Y + osc.y + (0.0 if lado < 0.0 else 5.0)
		var cx := bx + lado * 6.0
		# Nasce no dorso, atravessa a borda e sobe pela margem do papel.
		var base := Vector2(cx + lado * 4.0, py - 6.0)
		var ponta := Vector2(bx - lado * 20.0, py - 30.0)
		var meio := base.lerp(ponta, 0.5) + Vector2(-lado * 3.0, 0.0)
		var perp := (ponta - base).normalized()
		perp = Vector2(-perp.y, perp.x)
		# Sombra do polegar no papel, dois pixels para dentro.
		_poly4(base + perp * 7.0 + Vector2(2.0, 2.0),
			base - perp * 7.0 + Vector2(2.0, 2.0),
			ponta - perp * 4.0 + Vector2(2.0, 2.0),
			ponta + perp * 4.0 + Vector2(2.0, 2.0),
			Color(0.08, 0.09, 0.07, 0.24))
		_poly4(base + perp * 7.0, base - perp * 7.0,
			meio - perp * 6.0, meio + perp * 6.0, meia)
		_poly4(meio + perp * 6.0, meio - perp * 6.0,
			ponta - perp * 4.0, ponta + perp * 4.0, pele)
		draw_line(base + perp * 7.0, ponta + perp * 4.0, funda, 1.0)
		draw_line(base - perp * 7.0, ponta - perp * 4.0, funda, 1.0)


## A sombra que as maos jogam NO papel, desenhada depois dele.
##
## Sem ela o papel fica flutuando na frente das maos em vez de estar apoiado
## nelas. Duas faixas encostadas no canto de baixo custam quase nada.
func _desenhar_sombra_das_maos() -> void:
	var osc := _balanco_doc()
	for lado: float in [-1.0, 1.0]:
		var bx := (DOC.position.x if lado < 0.0 else DOC.end.x) + osc.x
		var py := PEGA_Y + osc.y + (0.0 if lado < 0.0 else 5.0)
		for k in 3:
			var larg := 16.0 - float(k) * 5.0
			var x := bx if lado < 0.0 else bx - larg
			draw_rect(Rect2(x, py - 30.0, larg, DOC.end.y - py + 34.0),
				Color(0.06, 0.05, 0.04, 0.09))


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
		draw_texture_rect(_brasao, Rect2(PAGINA_ESQ.position.x + 1.0, DOC_Y + 8.0,
			15.0, 15.0), false)
	_texto(Vector2(PAGINA_ESQ.position.x + 19.0, DOC_Y + 18.0), "REP. FED. DO BRASIL",
		Color(CAPA.r, CAPA.g, CAPA.b, 0.85), _fonte)
	_texto(Vector2(PAGINA_ESQ.position.x + 19.0, DOC_Y + 29.0), "CARTEIRA DE",
		TINTA_FRACA)
	_texto(Vector2(PAGINA_ESQ.position.x + 19.0, DOC_Y + 41.0), "IDENTIDADE", TINTA,
		_fonte_media)

	draw_rect(RETRATO.grow(2.0), TINTA)
	if _viewport != null:
		draw_texture_rect(_viewport.get_texture(), RETRATO, false)
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
		var larg_nome := _rect_visto().position.x - 6.0 - x
		_texto(Vector2(x, DOC_Y + 12.0), "NOME", TINTA_FRACA)
		# A UF subiu para a linha do rotulo, alinhada a direita. Na pagina larga
		# ela cabia depois do CPF; com cento e trinta e seis pixels de coluna o
		# numero sozinho ja come tudo, e os dois se encostavam.
		_texto(Vector2(x, DOC_Y + 12.0), String(ficha["uf"]), TINTA_FRACA, _fonte,
			HORIZONTAL_ALIGNMENT_RIGHT, larg_nome)
		_texto(Vector2(x, DOC_Y + 24.0),
			_nome_na_pagina(String(ficha["nome"]), larg_nome), TINTA)
		_texto(Vector2(x, DOC_Y + 35.0), "CPF", TINTA_FRACA)
		_texto(Vector2(x + 26.0, DOC_Y + 35.0), String(ficha["cpf"]), TINTA, _mono)

	draw_rect(Rect2(x, DOC_Y + 40.0, PAGINA_DIR.size.x - 6.0, 1.0), VINCO)
	_desenhar_abas()
	_desenhar_campos()
	_desenhar_visto()


## O nome do titular na largura que a pagina realmente tem.
##
## O corte era `substr(0, 22)`, e vinte e dois caracteres desta fonte dao quase
## duzentos pixels — cinquenta a mais do que existe entre a margem e a caixa do
## visto. "JOTA FERNANDES RODRIGUES" entrava por baixo do tique de aceite.
## Contar caractere so funciona em fonte monoespacada, e esta nao e.
##
## E documento nao corta nome no meio: ABREVIA. Primeiro os nomes do meio viram
## inicial, depois some o meio inteiro, e so em ultimo caso, quando nem "NOME
## SOBRENOME" cabe, e que se trunca — que e a mesma ordem que um cartorio segue
## para caber uma linha numa via impressa.
func _nome_na_pagina(nome: String, largura: float) -> String:
	if _largura_do_texto(nome) <= largura:
		return nome
	var partes := nome.split(" ", false)
	if partes.size() > 2:
		var iniciais: PackedStringArray = []
		for i in range(1, partes.size() - 1):
			iniciais.append(partes[i].substr(0, 1) + ".")
		var abreviado := "%s %s %s" % [partes[0], " ".join(iniciais), partes[-1]]
		if _largura_do_texto(abreviado) <= largura:
			return abreviado
	if partes.size() > 1:
		var so_pontas := "%s %s" % [partes[0], partes[-1]]
		if _largura_do_texto(so_pontas) <= largura:
			return so_pontas
	var corte := nome
	while corte.length() > 1 and _largura_do_texto(corte) > largura:
		corte = corte.substr(0, corte.length() - 1)
	return corte


func _largura_do_texto(s: String) -> float:
	if _fonte == null:
		return 0.0
	return _fonte.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11).x


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
		# Paleta de documento, e nao cinza de widget. As caixas cinza que havia
		# aqui eram a coisa mais parecida com menu de sistema que a carteira
		# tinha: documento impresso nao tem cinza neutro em lugar nenhum, e o
		# olho reconhece isso antes de conseguir dizer por que.
		var fill := (Color(0.95, 0.93, 0.85) if ativa
			else (Color(0.84, 0.83, 0.72) if hover else Color(0.77, 0.77, 0.67)))
		draw_rect(visual, fill)
		# Aba inativa afunda: filete escuro no topo, como papel dobrado para
		# tras. A ativa ganha luz no lugar da sombra.
		if ativa:
			draw_rect(Rect2(visual.position, Vector2(visual.size.x, 2.0)),
				Color(1.0, 0.99, 0.94, 0.75))
		else:
			draw_rect(Rect2(visual.position, Vector2(visual.size.x, 2.0)),
				Color(0.42, 0.40, 0.32, 0.35))
		var borda := DESTAQUE if (ativa or hover) else TINTA_FRACA
		draw_rect(visual, borda, false, 2.0 if ativa or hover else 1.0)
		# A aba ativa se emenda na pagina: tres pixels de papel cobrindo a linha
		# de baixo. E o que transforma seis caixas soltas numa fileira de abas.
		if ativa:
			draw_rect(Rect2(visual.position.x + 2.0, visual.end.y - 2.0,
				visual.size.x - 4.0, 3.0), fill)
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
		"casaco":
			# Casaco aberto: dois panos com lapela e a fresta no meio. Sem a
			# fresta o icone vira o mesmo bloco da camisa e as duas abas ficam
			# indistinguiveis em doze pixels.
			draw_colored_polygon(PackedVector2Array([
				centro + Vector2(-6.0, -5.0), centro + Vector2(-1.0, -5.0),
				centro + Vector2(-1.0, 6.0), centro + Vector2(-6.0, 6.0)]), cor)
			draw_colored_polygon(PackedVector2Array([
				centro + Vector2(6.0, -5.0), centro + Vector2(1.0, -5.0),
				centro + Vector2(1.0, 6.0), centro + Vector2(6.0, 6.0)]), cor)
			draw_line(centro + Vector2(-4.0, -5.0), centro + Vector2(-1.0, 0.0),
				CELULA_SEL, 1.0)
			draw_line(centro + Vector2(4.0, -5.0), centro + Vector2(1.0, 0.0),
				CELULA_SEL, 1.0)
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
	var y := LINHA_UM
	for i in campos_da_aba().size():
		var campo := _campo(campos_da_aba()[i])
		var ativo := _linha == i + 1
		var alto := _altura_do_campo(campo)
		if ativo:
			draw_rect(Rect2(x - 3.0, y - 3.0, PAGINA_DIR.size.x - 2.0, alto - 2.0),
				Color(0.86, 0.84, 0.74, 0.72))
		_texto(Vector2(x, y + 8.0), String(campo["rotulo"]),
			DESTAQUE if ativo else TINTA_FRACA)
		_desenhar_escolha(campo, Vector2(x, y + CAMPO_ROTULO), ativo)
		y += alto


## Quanto a linha deste campo ocupa. A conta mora em `CarteiraLayout`.
func _altura_do_campo(campo: Dictionary) -> float:
	return CarteiraLayout.altura_da_linha(String(campo["tipo"]))


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
		var barra := Rect2(em.x, em.y + 5.0, largura - 50.0, 6.0)
		draw_rect(barra, Color(0.70, 0.74, 0.64))
		draw_rect(Rect2(barra.position, Vector2(barra.size.x * t, barra.size.y)),
			DESTAQUE if ativo else TINTA_FRACA)
		draw_rect(Rect2(barra.position.x + barra.size.x * t - 2.0,
			barra.position.y - 3.0, 5.0, 12.0), TINTA)
		var valor_atual := float(_ajustes.get(chave, minimo))
		var texto := ("%.2f m" % valor_atual
			if chave == &"altura" else _nome_do_porte(t))
		_texto(Vector2(em.x + largura - 44.0, em.y + 13.0), texto, TINTA)
		return

	if tipo == "lista":
		var itens: Array = campo["itens"]
		var indice := int(_ajustes.get(chave, 0)) % itens.size()
		var passo := largura / float(itens.size())
		for k in itens.size():
			var r := Rect2(em.x + float(k) * passo, em.y, passo - 2.0,
				float(CAMPO_WIDGET["lista"]))
			var sel := k == indice
			var hov := ativo and k == _hover_celula
			draw_rect(r, Color(0.90, 0.88, 0.78) if sel
				else (Color(0.84, 0.82, 0.72) if hov else Color(0.76, 0.74, 0.64)))
			var borda := CELULA_SEL if sel else (DESTAQUE if hov else TINTA_FRACA)
			draw_rect(r.grow(1.0 if sel else 0.0), borda, false, 2.0 if sel else 1.0)
			_texto(Vector2(r.position.x, r.position.y + 11.0),
				String(itens[k]).substr(0, 4), TINTA, _fonte,
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		return

	if tipo == "cor":
		var cores := Aparencia.paleta(String(campo["paleta"]))
		var atual: Color = _ajustes.get(chave, cores[0])
		var passo := largura / float(maxi(1, cores.size()))
		for k in cores.size():
			var r := Rect2(em.x + float(k) * passo, em.y + 1.0,
				maxf(4.0, passo - 1.0), float(CAMPO_WIDGET["cor"]) - 2.0)
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
		var r := Rect2(em.x + float(k) * passo_cel, em.y, passo_cel - 2.0,
			float(CAMPO_WIDGET["celula"]))
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
		&"casaco_cel":
			return Aparencia.LINHA_CASACO
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
		_texto(Vector2(PAGINA_DIR.position.x, DOC_Y + 4.0), "PRONTO", DESTAQUE, _fonte,
			HORIZONTAL_ALIGNMENT_RIGHT, PAGINA_DIR.size.x - 28.0)


## Zona de leitura no rodape, como no RG do inventario.
func _desenhar_zona() -> void:
	var ficha := RegistroCivil.jogador
	if ficha.is_empty():
		return
	var numero := String(ficha["cpf"]).replace(".", "").replace("-", "")
	var zona := "IDBRA%s<<%s" % [numero,
		String(ficha["sobrenome"]).replace(" ", "<")]
	# Recuada e encurtada porque os polegares moram nas duas margens laterais:
	# comecando na antiga folga de dez pixels, a zona passava por baixo do
	# polegar esquerdo e as tres primeiras letras sumiam.
	_texto(Vector2(DOC.position.x + 34.0, DOC.end.y - 7.0), zona.substr(0, 30),
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


## A largura da aba sai da CONTAGEM de abas, e nao de um numero fixo.
##
## A fileira ganhou a setima aba (agasalho) e as seis de antes tinham largura
## escrita a mao: a nova entrava por fora da pagina. Dividir a coluna pelo
## tamanho de ABAS faz a fileira caber sozinha na proxima que entrar.
func _rect_aba(i: int) -> Rect2:
	var passo := PAGINA_DIR.size.x / float(ABAS.size())
	return Rect2(PAGINA_DIR.position.x + float(i) * passo, DOC_Y + 44.0,
		passo - 2.0, 18.0)


func _rect_visto() -> Rect2:
	return Rect2(PAGINA_DIR.end.x - 24.0, DOC_Y + 8.0, 20.0, 20.0)


## Onde a linha de um campo comeca, empilhando as alturas de quem veio antes.
##
## E a MESMA acumulacao de `_desenhar_campos`, e tem de ser: esta funcao e a que
## o mouse consulta. Se as duas discordarem, o desenho aparece num lugar e o
## clique acontece noutro — que e o pior defeito possivel numa tela clicavel,
## porque ele nao aparece em captura nenhuma.
func _origem_campo(indice_campo: int) -> Vector2:
	var y := LINHA_UM
	for i in campos_da_aba().size():
		if i == indice_campo:
			break
		y += _altura_do_campo(_campo(campos_da_aba()[i]))
	return Vector2(PAGINA_DIR.position.x, y + CAMPO_ROTULO)


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
	var em := Vector2(PAGINA_DIR.position.x, DOC_Y + 30.0)
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
