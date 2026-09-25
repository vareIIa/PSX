## A barra de "carregando shaders" no canto do titulo. Ver `AquecimentoDeShaders`.
##
## Quem monta e o `Menu`, que empresta o proprio rotulo (`_rotulo`) para a letra
## sair igual ao resto do titulo. Some sozinha um pouco depois de terminar.
class_name PainelAquecimento
extends Control

## Caixa no espaco de 480 x 270 do menu: canto de baixo, a esquerda, fora da
## lista, da nota e da dica, que sao centradas.
const CAIXA := Rect2(12.0, 230.0, 124.0, 26.0)
const FUNDO := Color(0.0, 0.0, 0.0, 0.55)
const CHEIO := Color(0.74, 0.72, 0.68)

var _rotulo: Label
var _pct: Label
var _barra: ColorRect
var _ao_terminar: Callable
var _some_em := -1.0
## O aquecimento chegou a rodar com este painel na tela? Sem ele, "prontos" nao
## tem o que anunciar (teste, `--pular-menu`) e o painel nem aparece.
var _viu := false


## `rotular(pai, texto, pos, tamanho, alinhamento) -> Label` e o rotulo do menu.
## `ao_terminar` repinta a lista quando os itens voltam a valer.
func _init(rotular: Callable, ao_terminar: Callable) -> void:
	name = "PainelAquecimento"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = CAIXA.position
	size = CAIXA.size
	_ao_terminar = ao_terminar
	_rotulo = rotular.call(self, "CARREGANDO SHADERS", Vector2.ZERO,
		Vector2(CAIXA.size.x - 30.0, 12.0), HORIZONTAL_ALIGNMENT_LEFT) as Label
	_pct = rotular.call(self, "0%", Vector2(CAIXA.size.x - 30.0, 0.0),
		Vector2(30.0, 12.0), HORIZONTAL_ALIGNMENT_RIGHT) as Label
	var fundo := ColorRect.new()
	fundo.color = FUNDO
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fundo.position = Vector2(0.0, 15.0)
	fundo.size = Vector2(CAIXA.size.x, 4.0)
	add_child(fundo)
	_barra = ColorRect.new()
	_barra.color = CHEIO
	_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barra.position = fundo.position
	_barra.size = Vector2(0.0, 4.0)
	add_child(_barra)
	visible = not AquecimentoDeShaders.pronto()


func _process(delta: float) -> void:
	if _some_em >= 0.0:
		_some_em -= delta
		modulate.a = clampf(_some_em / 0.6, 0.0, 1.0)
		if _some_em <= 0.0:
			visible = false
			set_process(false)
		return
	if AquecimentoDeShaders.pronto():
		if not _viu:
			visible = false
			return
		_rotulo.text = "SHADERS PRONTOS"
		_barra.size.x = CAIXA.size.x
		_pct.text = "100%"
		_some_em = 1.8
		if _ao_terminar.is_valid():
			_ao_terminar.call()
		return
	var a := AquecimentoDeShaders.instancia()
	if a == null:
		return
	_viu = true
	visible = true
	_barra.size.x = CAIXA.size.x * a.fracao
	_pct.text = "%d%%" % roundi(a.fracao * 100.0)
