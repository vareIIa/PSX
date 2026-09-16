## A mancha escura debaixo do carro: o que faz ele POUSAR na estrada.
##
## O que ela conserta
## ------------------
## Nenhuma malha do carro projeta sombra (`cast_shadow` desligado em todas, por
## custo), e a direcional do clima e fraca nos presets encobertos. O resultado e
## um carro que nao tem nada embaixo: em qualquer plano rente ao chao ele parece
## recortado e colado sobre a estrada, e o vao sob a lataria mostra a roda do
## lado oposto contra o barro claro — geometria correta que le como defeito,
## porque debaixo de um carro de verdade nao ha barro claro nenhum, ha escuro.
##
## Uma mancha, e nao uma sombra
## ----------------------------
## Isto nao tenta ser a projecao do sol. E a oclusao de ambiente do proprio
## corpo do carro: a fresta entre a lataria e o chao nao recebe ceu, e por isso
## fica escura mesmo num dia sem sol — o que a torna certa em todo clima, e nao
## so quando ha uma direcional para justificar. Por isso ela nao se alonga, nao
## gira com a hora e nao depende do azimute.
##
## Decal e recurso de Forward+: no perfil de Compatibility ele e aceito sem aviso
## e nao desenha nada. Por isso este no se desliga sozinho no PS1 STYLE em vez de
## ficar invisivel sem explicacao — mesma regra da `Pocas`.
class_name SombraContato
extends Decal

## Quanto a mancha passa da silhueta do carro, em metros. Sombra rente a
## carroceria le como adesivo; um palmo de sobra le como penumbra.
const SOBRA := 0.5
## Altura da caixa do decal. So precisa alcancar o chao a partir do assoalho.
const ALTURA := 0.9
## Opacidade cheia. Acima disto vira um buraco no asfalto.
const FORCA := 0.58
## Lado da textura, em pixels. A mancha e um degrade radial: nao ha detalhe em
## 128 que se perca em 64.
const N_TEX := 64

static var _cache: ImageTexture


## Dimensiona a mancha para um carro de `comprimento` x `largura`.
func ajustar(comprimento: float, largura: float) -> void:
	size = Vector3(largura + SOBRA * 2.0, ALTURA, comprimento + SOBRA * 2.0)


func _ready() -> void:
	texture_albedo = _textura()
	# Mistura cheia: a mancha SUBSTITUI a cor do chao onde ela e opaca. Com
	# mistura parcial ela clareava junto com o barro no meio do dia e sumia.
	albedo_mix = 1.0
	modulate = Color(0.0, 0.0, 0.0, FORCA)
	# A borda de cima some antes de alcancar a lataria e a de baixo acompanha o
	# desnivel do leito, que tem sulco e abaulamento: sem os dois, a mancha corta
	# reto no limite da caixa e a quina aparece na beira da trilha.
	upper_fade = 0.5
	lower_fade = 0.3
	distance_fade_enabled = true
	distance_fade_begin = 38.0
	distance_fade_length = 16.0
	set_process(true)


func _process(_delta: float) -> void:
	# Some junto com a poca no PS1 STYLE, e pelo mesmo motivo: la o decal nao
	# desenha e o preset e a build de antes.
	# `--sem-sombra` desliga a mancha para isolar o que e ela e o que e o resto.
	#
	# Mesma razao do `--sem-ceu`: uma camada escura larga e difusa embaixo do
	# carro e exatamente o tipo de coisa que se confunde com iluminacao ruim, e
	# a unica forma de saber o quanto ela esta fazendo e tirar e comparar. Foi
	# assim que ela foi medida: 4,68% dos pixels, diferenca maxima de 167.
	visible = (Settings.luz_por_pixel
		and not OS.get_cmdline_user_args().has("--sem-sombra"))


## Degrade radial numa elipse, com o miolo cheio.
##
## O miolo e CHEIO e nao um degrade do centro: debaixo do carro a fresta e
## igualmente escura de ponta a ponta, e so na borda e que entra luz de lado.
## Um degrade a partir do centro deixa a mancha com cara de aerografia.
static func _textura() -> ImageTexture:
	if _cache != null:
		return _cache
	var buf := PackedByteArray()
	buf.resize(N_TEX * N_TEX * 4)
	var i := 0
	for y in N_TEX:
		var v := (float(y) / float(N_TEX - 1) - 0.5) * 2.0
		for x in N_TEX:
			var u := (float(x) / float(N_TEX - 1) - 0.5) * 2.0
			var r := sqrt(u * u + v * v)
			var a := 1.0 - smoothstep(0.46, 1.0, r)
			buf[i] = 0
			buf[i + 1] = 0
			buf[i + 2] = 0
			buf[i + 3] = int(clampf(a, 0.0, 1.0) * 255.0)
			i += 4
	_cache = ImageTexture.create_from_image(
		Image.create_from_data(N_TEX, N_TEX, false, Image.FORMAT_RGBA8, buf))
	return _cache
