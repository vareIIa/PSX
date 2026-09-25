## Rajada de bancada para cena cortada: um quadro a cada `PASSO` segundos do
## relogio da cena, com o tempo no nome (`r_0012.30.png`), no formato que o
## `tools/mosaico_rajada.py` le. Com `cheio`, um a cada `CHEIO_A_CADA` sai
## tambem no tamanho da janela, em `<pasta>/cheio`: e em 4K que mao, dedo e
## dobra de joelho se julgam, e a rajada reduzida esconde os tres.
##
## E a rajada da estrada (`AberturaEstrada._rajada`) tirada de dentro do
## roteiro: a da estrada so grava o plano de dentro do carro, esta grava o que a
## tela mostrar, de qualquer cena que a pendurar.
##
## O relogio e o da cena (soma de `delta`), e nao o de parede: cada foto custa
## dezenas de milissegundos, e com relogio de parede a rajada pularia justamente
## os trechos mais caros.
class_name RajadaDeCena
extends Node

const PASSO := 0.1
const TAMANHO := Vector2i(640, 360)
const CHEIO_A_CADA := 10

var pasta: String = ""
var cheio: bool = false
## Segundos de cena desde que a rajada nasceu.
var t: float = 0.0

var _proximo: float = 0.0
var _n: int = 0
var _gravando: bool = false


## A rajada pedida na linha de comando por `--<prefixo>-rajada=<pasta>` (e
## `--<prefixo>-cheio`), ou null.
static func da_linha(prefixo: String) -> RajadaDeCena:
	var pasta_pedida := ""
	var com_cheio := false
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--%s-rajada=" % prefixo):
			pasta_pedida = a.trim_prefix("--%s-rajada=" % prefixo)
		elif a == "--%s-cheio" % prefixo:
			com_cheio = true
	if pasta_pedida.is_empty():
		return null
	var r := RajadaDeCena.new()
	r.name = "Rajada"
	r.pasta = pasta_pedida
	r.cheio = com_cheio
	DirAccess.make_dir_recursive_absolute(pasta_pedida)
	if com_cheio:
		DirAccess.make_dir_recursive_absolute(pasta_pedida.path_join("cheio"))
	return r


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	t += delta
	if _gravando or t < _proximo:
		return
	_proximo = t + PASSO
	_gravar(t)


func _gravar(quando: float) -> void:
	_gravando = true
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img != null:
		var nome := "r_%07.2f.png" % quando
		if cheio and _n % CHEIO_A_CADA == 0:
			img.save_png(pasta.path_join("cheio").path_join(nome))
		img.resize(TAMANHO.x, TAMANHO.y, Image.INTERPOLATE_BILINEAR)
		img.save_png(pasta.path_join(nome))
	_n += 1
	_gravando = false
