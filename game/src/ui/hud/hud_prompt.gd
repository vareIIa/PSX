## O aviso de acao: "[E] Abrir a porta", centrado no terco de baixo.
##
## Sucessor do segundo papel da `FaixaLayout`. Tres mudancas:
## - a tecla e desenhada (e vira "A" no controle);
## - a tecla vem sempre ANTES do verbo, venha a frase como vier (`HudLayout.acao`);
## - sobe dois pixels ao entrar e troca de texto sem piscar: o prompt muda o tempo
##   todo quando o jogador passa por varias portas, e cada troca com fade inteiro
##   viraria uma luz de natal no meio da tela.
class_name HudPrompt
extends Control

var _texto := ""
## O ultimo texto nao vazio: e ele que se apaga no fade de saida.
var _desenho := ""
var _a := 0.0
var _quer := 0.0
## Escala do HUD. O prompt mantem a largura maxima NA TELA.
var escala := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var ctl := Settings.get(&"controle") as Controle
	if ctl != null:
		ctl.dispositivo_mudou.connect(func(_q: int) -> void: queue_redraw())


func definir(texto: String) -> void:
	if texto == _texto:
		return
	_texto = texto
	_quer = 0.0 if texto.is_empty() else 1.0
	if not texto.is_empty():
		_desenho = texto
	queue_redraw()


func texto() -> String:
	return _texto


func _process(delta: float) -> void:
	var antes := _a
	_a = move_toward(_a, _quer, delta / 0.12)
	if not is_equal_approx(antes, _a):
		queue_redraw()


func _draw() -> void:
	if _a <= 0.0 or _desenho.is_empty():
		return
	var ctl := Settings.get(&"controle") as Controle
	var pad := ctl != null and ctl.dispositivo == Controle.Dispositivo.CONTROLE
	var cabe := HudLayout.prompt_que_cabe(_desenho, pad, escala)
	var pp: Array[Dictionary] = cabe["pedacos"]
	var tam: int = cabe["tam"]
	var w := HudLayout.largura_pedacos(pp, tam, pad)
	var h := HudTema.altura(HudTema.semi(), tam) + 2.0
	var y := HudLayout.PROMPT_Y + (1.0 - _a) * 2.0
	var x := roundf((HudLayout.TELA.x - w) * 0.5)
	HudTema.painel(self, Rect2(x - 6.0, y - 3.0, w + 12.0, h + 6.0), _a * 0.85, 3.0)
	HudObjetivo.desenhar_pedacos(self, Vector2(x, y), pp, tam, _a, HudTema.TEXTO)
