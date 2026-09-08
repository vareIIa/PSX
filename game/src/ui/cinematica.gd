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

## Altura de cada tarja. Trinta px em 270 deixam 210 de imagem, ou seja 2,29:1 —
## a proporcao de cinema que a epoca imitava. As tarjas de `dialogo.gd` tem 14 e
## sao outra coisa: la e uma caixa de fala, aqui a tela inteira muda de formato.
const TARJA := 30.0

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
const COR_TEXTO := Color(0.98, 0.98, 0.96)

signal comecou()
signal acabou()

var ativa: bool = false

var _raiz: Control
var _tarja_topo: ColorRect
var _tarja_base: ColorRect
var _cortina: ColorRect
var _legenda: Label
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
	# Contorno grosso + sombra. A legenda cai sobre a rua, que a noite tem
	# calcada clara sob poste de sodio e asfalto preto no mesmo quadro: sem os
	# dois o texto some numa metade da tela em qualquer cor que ele tenha.
	_legenda.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 1))
	_legenda.add_theme_constant_override(&"outline_size", 7)
	_legenda.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.85))
	_legenda.add_theme_constant_override(&"shadow_offset_x", 1)
	_legenda.add_theme_constant_override(&"shadow_offset_y", 1)
	# Titulo quando cabe: letra maior, leitura AAA a 480x270. Media como reserva.
	if ResourceLoader.exists(FONTE_L):
		_legenda.add_theme_font_override(&"font", load(FONTE_L))
	elif ResourceLoader.exists(FONTE_M):
		_legenda.add_theme_font_override(&"font", load(FONTE_M))
	_raiz.add_child(_legenda)
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
	var cena := get_tree().current_scene
	if cena != null and _camera.get_parent() != cena:
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
func legenda(texto: String, duracao: float = 0.0) -> void:
	if _tween_legenda != null and _tween_legenda.is_valid():
		_tween_legenda.kill()
	var base := TELA.y - LEGENDA_Y - _legenda.size.y

	if texto.is_empty():
		_tween_legenda = create_tween()
		_tween_legenda.tween_property(_legenda, "modulate:a", 0.0, LEGENDA_FADE)
		return

	_legenda.text = texto
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
	_tween_legenda.chain().tween_interval(maxf(0.0, duracao - LEGENDA_FADE))
	_tween_legenda.chain().tween_property(_legenda, "modulate:a", 0.0,
		LEGENDA_FADE)


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
