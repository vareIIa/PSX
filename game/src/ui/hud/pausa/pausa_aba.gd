## Base de uma aba do hub de pausa. Cada aba desenha dentro de `area` e trata a
## propria navegacao; o hub so troca de aba, abre, fecha e desenha a moldura.
##
## Contrato com o hub:
##   ao_entrar()           a aba ficou visivel (reler estado do jogo)
##   tratar(evento)->bool  consumiu a entrada?
##   dicas()->Array        pares [tecla, verbo] para o rodape
##   ocupada()->bool       ha um submodo aberto (ESC volta a ele, e nao fecha)
class_name PausaAba
extends Control

## Retangulo do conteudo, em coordenada logica (480x270). Posto pelo hub.
var area := Rect2()
var hub: Node


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	position = Vector2.ZERO
	size = HudTema.TELA


func ao_entrar() -> void:
	queue_redraw()


func tratar(_evento: InputEvent) -> bool:
	return false


func dicas() -> Array:
	return []


func ocupada() -> bool:
	return false


## ESC com a aba ocupada: fecha o submodo. Devolve true se havia o que fechar.
func voltar() -> bool:
	return false


# --- utilitarios de desenho comuns as abas ----------------------------------------

## Cabecalho de secao: rotulo espacado em acento com um fio embaixo.
func secao(p: Vector2, texto: String, largura: float) -> float:
	var f := HudTema.rotulo()
	HudTema.texto(self, f, p, texto, HudTema.T_ROTULO, HudTema.acento())
	var h := HudTema.altura(f, HudTema.T_ROTULO)
	draw_rect(Rect2(p + Vector2(0.0, h + 1.5), Vector2(largura, 0.5)),
		HudTema.alfa(HudTema.TEXTO, 0.18))
	return h + 5.0


## Linha selecionavel: faixa de foco com barra de acento, texto e valor.
func linha(r: Rect2, rotulo: String, valor: String, focada: bool, viva: bool = true) -> void:
	var f := HudTema.regular()
	var fs := HudTema.semi()
	if focada:
		draw_rect(r, Color(1.0, 1.0, 1.0, 0.07))
		draw_rect(Rect2(r.position, Vector2(1.5, r.size.y)), HudTema.acento())
	var cor := HudTema.TEXTO if viva else HudTema.TEXTO_APAGADO
	var h := HudTema.altura(f, HudTema.T_CORPO)
	var y := r.position.y + (r.size.y - h) * 0.5
	HudTema.texto(self, fs if focada else f, Vector2(r.position.x + 7.0, y), rotulo,
		HudTema.T_CORPO, cor)
	if not valor.is_empty():
		var w := HudTema.largura(fs, valor, HudTema.T_CORPO)
		var cv := HudTema.acento() if focada else HudTema.fraco()
		HudTema.texto(self, fs, Vector2(r.end.x - 7.0 - w, y), valor, HudTema.T_CORPO, cv)
