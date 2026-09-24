## Autoload. A camada de cena cortada: tarjas, legenda, cortina e a camera que
## nao e a do jogador.
##
## O que este arquivo NAO faz
## --------------------------
## Ele nao sabe nenhum plano. Nao ha um unico numero da abertura aqui dentro —
## nem posicao de camera, nem texto, nem duracao. Isso mora em `abertura.gd`,
## que e o roteiro. Aqui estao so os verbos que um roteiro precisa: entrar,
## enquadrar, mover, dizer, cortar, sair.
##
## A divisao vale a pena porque a abertura nao vai ser a unica cena cortada do
## jogo, e a segunda nao pode custar reescrever tarja e legenda.
##
## Por que a camera e nossa e nao a do jogador
## -------------------------------------------
## Porque um plano de cinema precisa estar onde a pessoa NAO esta. O primeiro
## enquadramento olha o sujeito de cima, a nove metros de altura; o segundo esta
## dentro de outra casa. Nenhum dos dois cabe numa camera pendurada na cabeca de
## quem esta encostado na parede. Entao a camera cinematica e um no proprio,
## solto no mundo, e `assumir` guarda qual era a corrente para `devolver`
## conseguir voltar exatamente para ela — e nao para "alguma camera do jogador",
## que numa cena com carro e bicicleta ja sao tres.
##
## Camada 145
## ----------
## Acima da cortina do Interiores (140), que e o que faz as tarjas continuarem
## na tela durante a entrada e a saida do comodo do segundo plano — sem isso a
## imagem perde a moldura justamente no corte, que e onde ela mais importa.
## Abaixo do pos-processamento (150), porque legenda de cena cortada tem de
## receber grao e dither como o resto: texto limpo sobre imagem suja entrega a
## interface.
extends CanvasLayer

const TELA := Vector2(480.0, 270.0)
const FONTE_M := "res://assets/fontes/psx_media.fnt"
const FONTE_L := "res://assets/fontes/psx_titulo.fnt"

## Altura de cada tarja. Trinta e tres px em 270 deixam 204 de imagem, e
## 480/204 da 2,353:1 — o CinemaScope de verdade, e o numero inteiro mais perto
## dele que a grade de 270 px permite (com 30 px dava 2,29:1, que nao e formato
## de nada). As tarjas de `dialogo.gd` tem 14 e sao outra coisa: la e uma caixa
## de fala, aqui a tela inteira muda de formato.
const TARJA := 33.0
## O formato que as tarjas produzem, para quem precisar conferir.
const FORMATO := TELA.x / (TELA.y - TARJA * 2.0)

## Quanto as tarjas levam para entrar e para sair. A entrada e mais lenta que a
## saida de proposito: entrar em cena cortada e um anuncio, sair e uma devolucao
## — e devolver o controle devagar deixa o jogador com a mao na tecla sem poder
## andar, que e o unico jeito de irritar alguem no primeiro minuto de jogo.
const ENTRA := 0.55
const SAI := 0.34

## Faixa da legenda, medida da base da imagem para cima. Fica DENTRO do quadro,
## e nao em cima da tarja: texto na tarja preta le como legenda de filme
## estrangeiro, e o que se quer aqui e pensamento de quem esta na tela.
const LEGENDA_Y := 48.0
const LEGENDA_MARGEM := 28.0

## Quanto a legenda leva para aparecer e para sair, e quanto ela sobe entrando.
## Sem a subida o texto pisca no lugar e le como aviso de sistema.
const LEGENDA_FADE := 0.55
const LEGENDA_SOBE := 6.0

## Branco limpo. O bege anterior (0,92/0,89/0,80) sumia na calcada de sodio
## e no asfalto escuro ao mesmo tempo: contraste fraco nas duas metades. Branco
## + contorno + sombra le em qualquer fundo noturno da cidade.
const COR_TEXTO := HudTema.TEXTO

## Legenda em vetor, na gramatica RE7 da conversa. A de pixel (titulo 18 com
## contorno de 7) virava em 4K uma faixa de letra dura e grossa por cima da cena;
## agora e semibold 11 sobre um fundo escuro do tamanho do texto, e quem fala
## ganha uma etiqueta em ferrugem acima — "JOTA · CELULAR" —, como nos jogos em
## que a legenda diz de quem e a voz antes do que ela diz.
const TAM_LEGENDA := 11
const TAM_FALANTE := 7
const COR_FALANTE := UiEstilo.RE7_ACCENT_HOT

signal comecou()
signal acabou()

var ativa: bool = false

var _raiz: Control
var _tarja_topo: ColorRect
var _tarja_base: ColorRect
var _cortina: ColorRect
## Contador das falas fora de cena. Ver `fala`: so a ultima esconde a raiz.
var _falas_soltas := 0
## Fora de cena o HUD esta na tela. Enquanto o prompt de interacao morava no
## rodape, a fala avulsa subia 24 px para nao escrever por cima dele; com o HUD
## vetorial o prompt foi para ~30 px abaixo do meio (`HudLayout.PROMPT_Y`), e
## subir agora poria a legenda EM CIMA dele. Zero: a legenda fica no lugar dela.
const ACIMA_DO_HUD := 0.0
var _acima_do_hud := 0.0
var _legenda: Label
var _fundo: Panel
var _falante: Label
var _caixa_fundo: StyleBoxFlat
## Corpo da legenda e do nome, das opcoes (Opcoes > HUD > LEGENDAS). Lido a
## cada fala nova: trocar no menu vale a partir da proxima frase.
var _tam := TAM_LEGENDA
var _tam_nome := TAM_FALANTE
var _re_falante := RegEx.new()
var _falas_na_espera: Array[String] = []
var _camera: Camera3D
var _anterior: Camera3D
var _tween_legenda: Tween
## O movimento de camera em andamento. Guardado porque ele precisa MORRER junto
## com a camera: o tween vive neste no, e nao nela, e sobreviveria a ela.
var _tween_camera: Tween


func _ready() -> void:
	layer = 145
	# Sempre. Uma cena cortada que para de desenhar quando alguem abre o
	# inventario deixaria o jogador olhando para o mundo sem moldura.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar()
	_raiz.visible = false


func _montar() -> void:
	_raiz = Control.new()
	_raiz.name = "Cinematica"
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)

	_tarja_topo = _tarja("TarjaTopo")
	_tarja_base = _tarja("TarjaBase")

	_legenda = Label.new()
	_legenda.name = "Legenda"
	_legenda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_legenda.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_legenda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_legenda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_legenda.add_theme_color_override(&"font_color", COR_TEXTO)
	# A rua a noite tem calcada clara sob poste de sodio e asfalto preto no mesmo
	# quadro. O contorno grosso da versao de pixel resolvia isso; em vetor quem
	# resolve e o fundo escuro atras do texto (`_fundo`), e um contorno fino so
	# para a borda da letra nao sangrar no fundo.
	_legenda.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.55))
	_legenda.add_theme_constant_override(&"outline_size", 1)
	_legenda.add_theme_font_override(&"font", UiEstilo.fonte_re7(UiEstilo.RE7_WEIGHT_SEMIBOLD))
	_legenda.add_theme_font_size_override(&"font_size", TAM_LEGENDA)
	_legenda.add_theme_constant_override(&"line_spacing", 1)
	_raiz.add_child(_legenda)

	# O fundo e a etiqueta sao filhos da legenda: entram, sobem e somem junto com
	# ela no mesmo tween, sem ninguem precisar lembrar deles.
	_fundo = Panel.new()
	_fundo.name = "LegendaFundo"
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fundo.show_behind_parent = true
	var caixa := StyleBoxFlat.new()
	# O painel do HUD (`HudTema.PAINEL`), um pouco mais leve: e fala, nao aviso.
	caixa.bg_color = Color(HudTema.PAINEL, 0.62)
	caixa.set_corner_radius_all(3)
	caixa.anti_aliasing = true
	_caixa_fundo = caixa
	_fundo.add_theme_stylebox_override(&"panel", caixa)
	_legenda.add_child(_fundo)
	_falante = Label.new()
	_falante.name = "LegendaFalante"
	_falante.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_falante.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var espacada := FontVariation.new()
	espacada.base_font = UiEstilo.fonte_re7(UiEstilo.RE7_WEIGHT_SEMIBOLD)
	espacada.spacing_glyph = 1
	_falante.add_theme_font_override(&"font", espacada)
	_falante.add_theme_font_size_override(&"font_size", TAM_FALANTE)
	_falante.add_theme_color_override(&"font_color", COR_FALANTE)
	_legenda.add_child(_falante)
	_re_falante.compile("^([A-Z][A-Z0-9 ]{0,22}?)(?: \\(([a-z]+)\\))?: (.+)$")
	_legenda.position = Vector2(LEGENDA_MARGEM, TELA.y - LEGENDA_Y - 48.0)
	_legenda.size = Vector2(TELA.x - LEGENDA_MARGEM * 2.0, 48.0)
	_legenda.modulate.a = 0.0

	# A cortina fica ACIMA das tarjas: escurecer entre dois planos tem de apagar
	# a imagem inteira, moldura junto, senao o corte deixa duas faixas pretas
	# desenhadas por cima do preto e a tela mostra a costura.
	_cortina = ColorRect.new()
	_cortina.name = "Cortina"
	_cortina.color = Color(0, 0, 0, 0)
	_cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_cortina)
	_cortina.set_anchors_preset(Control.PRESET_FULL_RECT)


func _tarja(nome: String) -> ColorRect:
	var c := ColorRect.new()
	c.name = nome
	c.color = Color(0, 0, 0, 1)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(c)
	c.size = Vector2(TELA.x, TARJA)
	return c


# --- entrar e sair ----------------------------------------------------------

## Entra em cena cortada: as tarjas fecham, o jogador para de responder a tecla
## e o HUD sai da tela.
##
## `imediato` monta tudo ja fechado, sem animacao. E o que a abertura usa: ela
## comeca com a tela preta, e uma tarja deslizando atras de uma cortina opaca e
## trabalho que ninguem ve.
func iniciar(imediato: bool = false) -> void:
	if ativa:
		return
	ativa = true
	_raiz.visible = true
	_travar_jogador(true)
	_mostrar_hud(false)

	_tarja_topo.position.y = 0.0 if imediato else -TARJA
	_tarja_base.position.y = TELA.y - (TARJA if imediato else 0.0)
	if not imediato:
		var t := create_tween().set_parallel(true)
		t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		t.tween_property(_tarja_topo, "position:y", 0.0, ENTRA)
		t.tween_property(_tarja_base, "position:y", TELA.y - TARJA, ENTRA)
	comecou.emit()


## Sai de cena cortada. As tarjas abrem, a camera volta a ser a do jogador e o
## controle e devolvido. Espera a animacao terminar antes de sinalizar.
func encerrar() -> void:
	if not ativa:
		return
	ativa = false
	legenda("")
	devolver()

	var t := create_tween().set_parallel(true)
	t.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(_tarja_topo, "position:y", -TARJA, SAI)
	t.tween_property(_tarja_base, "position:y", TELA.y, SAI)
	await t.finished

	_raiz.visible = false
	_travar_jogador(false)
	_mostrar_hud(true)
	acabou.emit()


func _travar_jogador(preso: bool) -> void:
	var jogador := get_tree().get_first_node_in_group(&"player")
	if jogador != null and jogador.has_method("travar"):
		jogador.call("travar", preso)


## Esconde o que e do jogo e nao da cena: minimapa, cartao de missao, prompt.
##
## Pelo grupo, e nao por nome de classe. Toda camada de HUD se registra em
## `hud` no proprio _ready, e assim uma tela nova nasce ja sabendo desaparecer
## durante uma cena cortada, sem ninguem precisar lembrar de vir aqui.
func _mostrar_hud(visivel: bool) -> void:
	for no: Node in get_tree().get_nodes_in_group(&"hud"):
		var camada := no as CanvasItem
		if camada != null:
			camada.visible = visivel
			continue
		var layer := no as CanvasLayer
		if layer != null:
			layer.visible = visivel


# --- camera -----------------------------------------------------------------

## A camera da cena cortada passa a ser a corrente. Devolve ela, para o roteiro
## poder mexer no que precisar.
##
## Guarda qual era a anterior. Numa cena com carro e bicicleta ha mais de uma
## camera de jogador, e "volta para a do jogador" nao e uma instrucao que se
## possa cumprir sem ter anotado qual era.
func assumir() -> Camera3D:
	if _camera == null:
		_camera = Camera3D.new()
		_camera.name = "CameraCinematica"
		# Longe o bastante para o plano alto enxergar a rua inteira. O corte por
		# distancia de verdade quem faz e a nevoa, como no resto do jogo.
		_camera.far = 600.0
		_camera.near = 0.05
	# `current_scene` e nulo entre uma troca de cena e outra (e em bancada), e ai
	# a camera ficava FORA da arvore: `enquadrar` chamava `look_at` num no solto
	# e o plano inteiro acontecia na camera errada, com uma linha de erro por
	# quadro como unico aviso.
	var cena: Node = get_tree().current_scene
	if cena == null or not cena.is_inside_tree():
		cena = get_tree().root
	if _camera.get_parent() != cena:
		if _camera.get_parent() != null:
			_camera.get_parent().remove_child(_camera)
		cena.add_child(_camera)
	if _anterior == null:
		_anterior = get_viewport().get_camera_3d()
	_camera.current = true
	return _camera


## Devolve a camera que era a corrente antes de `assumir`.
func devolver() -> void:
	# Primeiro o tween, depois a camera. Ao contrario, o movimento continua
	# escrevendo posicao num objeto liberado durante o quadro que falta para o
	# `queue_free` acontecer — e como o tween e um laco por quadro, isso vira uma
	# linha de erro a cada quadro ate a cena acabar. Foi o que encheu o log e
	# comeu o terceiro plano da abertura inteiro.
	_matar_movimento()
	if _anterior != null and is_instance_valid(_anterior):
		_anterior.current = true
	_anterior = null
	if _camera != null and is_instance_valid(_camera):
		_camera.queue_free()
		_camera = null


## Poe a camera num ponto olhando para outro.
##
## `look_at` reclama quando os dois pontos estao na mesma vertical — o vetor
## para cima e o de frente ficam paralelos e a base nao fecha. Um plano de cima
## olhando reto para baixo e exatamente esse caso, e e um plano que se vai
## querer mais cedo ou mais tarde, entao o desvio de um milimetro em Z fica aqui
## e nao no roteiro.
func enquadrar(de: Vector3, para: Vector3, fov: float = 60.0) -> void:
	var cam := assumir()
	cam.fov = fov
	cam.global_position = de
	_olhar(cam, para)


## Profundidade de campo do plano (PLANO_AAA_4K, A30 e A15).
##
## So a cena cortada e o modo foto tem desfoque de foco — no jogo em si ele
## seria uma lente entre o jogador e o mundo. Aqui ele e uma escolha de plano:
## "o sujeito esta a tres metros, o resto e fundo".
##
## Os atributos sao uma COPIA dos do mundo e ficam na camera cinematica, que e
## descartada em `devolver`. Assim nao ha o que restaurar na saida, e um plano
## que esqueca de desligar o foco nao deixa a cidade borrada.
##
## `forca` e a abertura do diafragma: 0 desliga. `transicao` e quantos metros a
## imagem leva para sair do nitido — curta demais vira recorte, longa demais nao
## le como foco.
func profundidade(foco_m: float, forca: float = 0.08, transicao: float = 2.0) -> void:
	var cam := assumir()
	var atrib := cam.attributes as CameraAttributesPractical
	if atrib == null:
		var mundo := get_tree().get_first_node_in_group(&"fog_controller") as WorldEnvironment
		var base: CameraAttributes = null
		if mundo != null:
			base = mundo.camera_attributes
		if base is CameraAttributesPractical:
			atrib = (base as CameraAttributesPractical).duplicate() as CameraAttributesPractical
		else:
			atrib = CameraAttributesPractical.new()
		cam.attributes = atrib
	atrib.dof_blur_amount = forca
	atrib.dof_blur_far_enabled = forca > 0.0
	atrib.dof_blur_far_distance = foco_m
	atrib.dof_blur_far_transition = transicao
	atrib.dof_blur_near_enabled = forca > 0.0
	atrib.dof_blur_near_distance = maxf(0.1, foco_m - transicao)
	atrib.dof_blur_near_transition = transicao


## Plano sem foco seletivo: tudo nitido, que e o padrao.
func sem_profundidade() -> void:
	if _camera == null:
		return
	var atrib := _camera.attributes as CameraAttributesPractical
	if atrib == null:
		return
	atrib.dof_blur_far_enabled = false
	atrib.dof_blur_near_enabled = false
	atrib.dof_blur_amount = 0.0


func _matar_movimento() -> void:
	if _tween_camera != null and _tween_camera.is_valid():
		_tween_camera.kill()
	_tween_camera = null


## `look_at` com o desvio do caso vertical ja aplicado.
static func _olhar(cam: Camera3D, para: Vector3) -> void:
	var alvo := para
	var de := cam.global_position
	if absf(alvo.x - de.x) < 0.001 and absf(alvo.z - de.z) < 0.001:
		alvo.z += 0.001
	cam.look_at(alvo, Vector3.UP)


## Anda com a camera de um par de pontos ate outro, no tempo dado.
##
## Interpola a POSICAO e o ALVO, e nao a transformada: interpolar transformada
## faz a camera girar em volta do proprio eixo enquanto anda, e o assunto do
## quadro escapa pelo canto. Interpolando o alvo, o que estiver no meio da tela
## continua no meio da tela do primeiro ao ultimo quadro.
func mover(de: Vector3, ate: Vector3, olhar_de: Vector3, olhar_ate: Vector3,
		duracao: float, fov: float = 60.0, fov_final: float = -1.0) -> void:
	var cam := assumir()
	_matar_movimento()
	var t := create_tween()
	_tween_camera = t
	t.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_method(func(k: float) -> void:
		if not is_instance_valid(cam):
			return
		cam.global_position = de.lerp(ate, k)
		cam.fov = fov if fov_final < 0.0 else lerpf(fov, fov_final, k)
		_olhar(cam, olhar_de.lerp(olhar_ate, k)),
		0.0, 1.0, duracao)


# --- legenda ----------------------------------------------------------------

## Mostra uma linha de pensamento. Texto vazio apaga a que estiver na tela.
##
## Nao e a caixa de fala do `dialogo.gd`, e nao pode ser: aquela tem nome de quem
## fala, moldura de papel e avanca no botao. Isto e o sujeito pensando, ninguem
## responde e nao ha o que apertar — entao aparece e some sozinha, subindo cinco
## pixels. A diferenca de forma e o que diz ao jogador que ele nao esta em
## conversa nenhuma.
## Quanto tempo esta linha precisa ficar na tela para ser LIDA.
##
## Catorze caracteres por segundo e o ritmo de legenda de cinema em portugues —
## a regra de bolso da area fica entre 12 e 17, e 14 e o meio dela com margem
## para quem esta dirigindo enquanto le. O tempo de aparecer e o de sumir entram
## na conta porque durante os dois a legenda nao esta legivel: a soma e o tempo
## em que a frase existe, nao o tempo em que ela da para ler.
##
## O piso de 1,8 s existe para a linha curta. "Acorda." tem oito caracteres e
## meio segundo de leitura, e meio segundo na tela le como piscada de erro.
const CARACTERES_POR_SEGUNDO := 14.0
const LEITURA_MINIMA := 1.8


static func tempo_de_leitura(texto: String) -> float:
	var limpo := texto.strip_edges()
	if limpo.is_empty():
		return 0.0
	return maxf(LEITURA_MINIMA,
		float(limpo.length()) / CARACTERES_POR_SEGUNDO + LEGENDA_FADE * 2.0)


## Poe a legenda na tela.
##
## `duracao` e um PEDIDO, e nao uma ordem: quem escreve o roteiro acerta o ritmo
## do plano, e o tempo de leitura e o piso. Uma frase de sessenta caracteres nao
## fica meio segundo na tela por causa de um numero digitado errado no roteiro.
func legenda(texto: String, duracao: float = 0.0) -> void:
	if _tween_legenda != null and _tween_legenda.is_valid():
		_tween_legenda.kill()
	_aplicar_opcoes()
	var base := TELA.y - LEGENDA_Y - _altura_da_legenda(texto) - _acima_do_hud

	if texto.is_empty():
		_tween_legenda = create_tween()
		_tween_legenda.tween_property(_legenda, "modulate:a", 0.0, LEGENDA_FADE)
		return

	# "JOTA (celular): Entrega saindo." vira etiqueta JOTA · CELULAR e o texto.
	# So casa nome em maiuscula antes de dois-pontos: o "10  SO O JOTA E O
	# HELMER" do elevador e os pensamentos da abertura passam inteiros.
	var falante := ""
	var dito := texto
	var achou := _re_falante.search(texto)
	if achou != null:
		falante = achou.get_string(1).strip_edges()
		if not achou.get_string(2).is_empty():
			falante += "  ·  " + achou.get_string(2).to_upper()
		dito = achou.get_string(3)
	if not HudConfig.legenda_com_nome():
		falante = ""
	var alto := _altura_da_legenda(dito)
	base = TELA.y - LEGENDA_Y - alto - _acima_do_hud
	_legenda.text = dito
	_legenda.size.y = alto
	var fonte := _legenda.get_theme_font(&"font")
	var largura := minf(_legenda.size.x, fonte.get_multiline_string_size(dito,
		HORIZONTAL_ALIGNMENT_CENTER, _legenda.size.x, _tam).x)
	# A etiqueta mora DENTRO da caixa, numa linha propria em cima: solta sobre o
	# chao claro, ferrugem com letra espacada lia 1,3:1 de contraste.
	var com_nome := not falante.is_empty()
	# Quem fala segue a cor de destaque das opcoes do HUD (daltonismo).
	_falante.add_theme_color_override(&"font_color", HudTema.acento())
	var fonte_nome := _falante.get_theme_font(&"font")
	if com_nome:
		largura = maxf(largura, fonte_nome.get_string_size(falante, HORIZONTAL_ALIGNMENT_LEFT,
			-1, _tam_nome).x)
	var topo_caixa := -5.0 - (float(_tam_nome) + 4.0 if com_nome else 0.0)
	_fundo.position = Vector2((_legenda.size.x - largura) * 0.5 - 10.0, topo_caixa)
	_fundo.size = Vector2(largura + 20.0, alto - topo_caixa + 4.0)
	_falante.text = falante
	_falante.visible = com_nome
	_falante.position = Vector2(0.0, topo_caixa + 3.0)
	_falante.size = Vector2(_legenda.size.x, float(_tam_nome) + 3.0)
	_legenda.position.y = base + LEGENDA_SOBE
	_legenda.modulate.a = 0.0
	_tween_legenda = create_tween().set_parallel(true)
	_tween_legenda.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween_legenda.tween_property(_legenda, "modulate:a", 1.0, LEGENDA_FADE)
	_tween_legenda.tween_property(_legenda, "position:y", base, LEGENDA_FADE)
	if duracao <= 0.0:
		return
	# Sai sozinha ao fim do tempo pedido. O roteiro nao devia precisar lembrar de
	# apagar cada linha que escreveu.
	duracao = maxf(duracao, tempo_de_leitura(texto))
	_tween_legenda.chain().tween_interval(maxf(0.0, duracao - LEGENDA_FADE))
	_tween_legenda.chain().tween_property(_legenda, "modulate:a", 0.0,
		LEGENDA_FADE)


## Uma fala de alguem na sala, fora de cena cortada: a mesma legenda, sem tarja
## e sem travar o jogador.
##
## O jogo nao tinha legenda fora de cena — o murmurio da casa da fumaca e so
## voz —, e o andar 10 da estufa precisa que Jota e Helmer sejam LIDOS enquanto
## o jogador anda pela sala. Travar trinta segundos de piada numa cena cortada
## trocaria a sala por um filme. Dentro de uma cena, isto e so a legenda.
func fala(texto: String) -> void:
	# Com uma conversa aberta, a fala solta espera ela fechar: por cima, a
	# legenda cobria o nome de quem fala e a lista de assuntos (o JOTA no
	# celular narrando o efeito da Super no meio da abordagem da blitz).
	if not ativa and Conversa.ativo:
		_falas_na_espera.append(texto)
		if not Conversa.fechou.is_connected(_soltar_falas):
			Conversa.fechou.connect(_soltar_falas, CONNECT_ONE_SHOT)
		return
	var tempo := tempo_de_leitura(texto)
	if not ativa:
		# Cortina fechada e outra coisa acontecendo na tela: fala nenhuma entra
		# por cima de um corte para preto.
		if _cortina.color.a > 0.01:
			return
		_tarja_topo.position.y = -TARJA
		_tarja_base.position.y = TELA.y
		_raiz.visible = true
		_falas_soltas += 1
		var minha := _falas_soltas
		get_tree().create_timer(tempo + LEGENDA_FADE).timeout.connect(func() -> void:
			if not ativa and minha == _falas_soltas:
				_raiz.visible = false)
		_acima_do_hud = ACIMA_DO_HUD
	legenda(texto, tempo)
	_acima_do_hud = 0.0


## Tamanho e fundo das opcoes. So muda o tema quando a opcao mudou: trocar
## override de fonte a cada fala refaria o texto a toa.
func _aplicar_opcoes() -> void:
	var tam := HudConfig.legenda_corpo()
	var tam_nome := HudConfig.legenda_corpo_nome()
	if tam != _tam:
		_tam = tam
		_legenda.add_theme_font_size_override(&"font_size", _tam)
	if tam_nome != _tam_nome:
		_tam_nome = tam_nome
		_falante.add_theme_font_size_override(&"font_size", _tam_nome)
	_caixa_fundo.bg_color = Color(HudTema.PAINEL, HudConfig.legenda_alfa_fundo())


## Quanto a legenda vai ocupar, com o texto QUE VAI ENTRAR.
##
## A caixa cresce para CIMA, e nao para baixo: a base dela e o que fica a
## distancia certa da tarja de baixo. Antes a altura vinha de `_legenda.size.y`,
## que ainda era a do texto ANTERIOR — uma linha de tres linhas nascia com a
## altura de uma e vazava 11 px para dentro da tarja, comendo a ultima linha
## justamente na frase mais longa.
func _altura_da_legenda(texto: String) -> float:
	var fonte := _legenda.get_theme_font(&"font")
	if fonte == null or texto.strip_edges().is_empty():
		return _legenda.size.y
	# Medido pela propria fonte no tamanho pedido. `UiEstilo.quebrar` mede fonte
	# de sistema a 16 (ver UiEstilo.tamanho_nativo) e ignora "\n".
	var tam := fonte.get_multiline_string_size(texto, HORIZONTAL_ALIGNMENT_CENTER,
		_legenda.size.x, _tam)
	var linhas := maxf(1.0, roundf(tam.y / fonte.get_height(_tam)))
	return tam.y + (linhas - 1.0) * 1.0


# --- cortina ----------------------------------------------------------------

func escurecer(duracao: float = 0.35) -> void:
	var t := create_tween()
	t.tween_property(_cortina, "color:a", 1.0, duracao)
	await t.finished


func clarear(duracao: float = 0.5) -> void:
	var t := create_tween()
	t.tween_property(_cortina, "color:a", 0.0, duracao)
	await t.finished


## Preto entre dois planos. Nao e um fade: e um corte, e o preto no meio existe
## so para o olho nao carregar o quadro anterior para dentro do seguinte.
func corte(preto: float = 0.12) -> void:
	_cortina.color.a = 1.0
	await get_tree().create_timer(preto).timeout


## A tela ja nasce preta. Serve para quem vai montar o primeiro plano antes de
## mostrar qualquer coisa.
func fechar_de_imediato() -> void:
	_cortina.color.a = 1.0


# --- diagnostico ------------------------------------------------------------
# Leituras do estado da moldura. Existem para a verificacao automatizada
# conseguir dizer se a tarja esta onde devia sem depender de olhar a imagem.

func tarja_topo_y() -> float:
	return _tarja_topo.position.y


func tarja_base_y() -> float:
	return _tarja_base.position.y


func raiz_visivel() -> bool:
	return _raiz.visible


func cortina_alfa() -> float:
	return _cortina.color.a


## Solta, uma a uma, as falas que chegaram durante a conversa. So a ultima de
## cada vez importa para quem acabou de sair dela; as antigas viraram passado.
func _soltar_falas() -> void:
	if _falas_na_espera.is_empty():
		return
	var ultima: String = _falas_na_espera[_falas_na_espera.size() - 1]
	_falas_na_espera.clear()
	await get_tree().create_timer(0.3).timeout
	fala(ultima)

