## O branco do fim da estrada: o golpe na janela vira tela branca e sobra so o
## corpo dele — zumbido no ouvido, coracao, a respiracao cortada — e uma segunda
## respiracao, calma, colada do lado esquerdo, que nao e dele.
##
## Por que e um no proprio, e nao a cortina do Cinema
## -------------------------------------------------
## A cortina do `Cinema` e preta e so mexe em alfa; toda a praca e a cidade
## cortam por ela. Pintar a cortina de branco faria cada corte seguinte piscar
## branco. E o branco precisa ATRAVESSAR a troca de cena: a estrada desmonta
## debaixo dele, a praca monta debaixo dele, e so entao ele se dissolve no ceu.
## Por isso ele e filho da cena da cidade, nao da estrada, e quem o apaga e a
## `Abertura` (`dissolver`).
##
## O mundo cortado
## ---------------
## O bus `Ambiente` (chuva, vento) e mutado no quadro do golpe — corte seco, e
## nao fade: o silencio de uma vez e metade do susto. Os sons do corpo tocam no
## `SFX`, entao obedecem ao volume de efeitos do jogador; a respiracao calma vai
## num bus proprio com panoramico a esquerda, enviado ao `SFX`.
class_name BrancoDoSusto
extends CanvasLayer

## A cor do ceu de nevoa da praca, onde o branco termina. O branco nao some:
## ele esfria ate esta cor e a imagem aparece por baixo.
const COR_CEU := Color(0.71, 0.74, 0.76)
const BUS_ESQUERDA := &"SustoEsquerda"

var _tela: ColorRect
var _tocadores: Array[AudioStreamPlayer] = []
var _mudo_ambiente: bool = false


func _init() -> void:
	name = "BrancoDoSusto"
	# Acima do Cinema (legendas e tarjas) e do celular (128).
	layer = 200


func _ready() -> void:
	_tela = ColorRect.new()
	_tela.name = "Branco"
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.color = Color(1.0, 1.0, 1.0, 0.0)
	_tela.position = Vector2.ZERO
	# Tamanho explicito: FULL_RECT sob CanvasLayer mede 0x0.
	_tela.size = Vector2(4096.0, 4096.0)
	add_child(_tela)


## O golpe. Tudo no mesmo quadro: a tela branca, o mundo cortado e o corpo.
func estourar() -> void:
	_tela.color = Color.WHITE
	_cortar_mundo(true)
	_tocar(&"zumbido_loop", -9.0, true)
	_tocar(&"coracao_loop", -6.0, true)
	_tocar(&"respiracao_susto", -3.0, false)
	# A outra respiracao entra depois, quando a dele ja espacou: e ai que se
	# percebe que sao duas.
	get_tree().create_timer(1.6).timeout.connect(func() -> void:
		if is_inside_tree():
			_tocar(&"respiracao_calma", -13.0, false, _bus_esquerda()))


## Solta o mundo de volta (o bus `Ambiente`). A estrada chama isto ao desmontar:
## a praca monta com o som dela, ainda debaixo do branco.
func devolver_mundo() -> void:
	_cortar_mundo(false)


## O branco esfria ate o ceu e some; o corpo vai baixando junto.
func dissolver(duracao: float) -> void:
	_cortar_mundo(false)
	var t := create_tween().set_parallel(true)
	t.tween_property(_tela, "color", Color(COR_CEU, 0.85), duracao * 0.45) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_property(_tela, "color:a", 0.0, duracao * 0.55).set_delay(duracao * 0.45) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	for p: AudioStreamPlayer in _tocadores:
		if is_instance_valid(p):
			t.tween_property(p, "volume_db", -60.0, duracao * 1.3)
	_foto_de_bancada("12_branco_esfria", duracao * 0.4)
	_foto_de_bancada("13_ceu", duracao * 1.05)
	await t.finished
	queue_free()


## Bancada (`--susto-fotos=`): grava a passagem do branco para o ceu.
func _foto_de_bancada(nome: String, depois: float) -> void:
	var pasta := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--susto-fotos="):
			pasta = a.trim_prefix("--susto-fotos=")
	if pasta.is_empty():
		return
	var arvore := get_tree()
	await arvore.create_timer(depois).timeout
	await RenderingServer.frame_post_draw
	arvore.root.get_texture().get_image().save_png(pasta.path_join(nome + ".png"))


## Um som solto que atravessa a troca de cena junto com o branco.
func tocar(nome: StringName, volume_db: float) -> void:
	_tocar(nome, volume_db, false)


func _exit_tree() -> void:
	# Nunca deixar o jogo sem chuva e sem vento por causa de uma cena abortada.
	_cortar_mundo(false)


func _cortar_mundo(cortar: bool) -> void:
	if cortar == _mudo_ambiente:
		return
	var i := AudioServer.get_bus_index(&"Ambiente")
	if i >= 0:
		AudioServer.set_bus_mute(i, cortar)
	_mudo_ambiente = cortar


func _tocar(nome: StringName, volume_db: float, laco: bool,
		bus: StringName = &"SFX") -> void:
	var s: AudioStream = AudioDirector.em_loop(nome) if laco else AudioDirector.stream(nome)
	if s == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = volume_db
	p.bus = bus if AudioServer.get_bus_index(bus) >= 0 else &"Master"
	add_child(p)
	p.play()
	_tocadores.append(p)


## Um bus que joga o som para a esquerda e segue o volume de efeitos.
static func _bus_esquerda() -> StringName:
	if AudioServer.get_bus_index(BUS_ESQUERDA) >= 0:
		return BUS_ESQUERDA
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, BUS_ESQUERDA)
	AudioServer.set_bus_send(i, &"SFX")
	var pan := AudioEffectPanner.new()
	pan.pan = -0.75
	AudioServer.add_bus_effect(i, pan)
	return BUS_ESQUERDA
