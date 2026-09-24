## A tela de bloqueio do iOS 4: a hora grande, a data, os avisos que chegaram e
## o "deslize para desbloquear" com o brilho correndo pelas letras.
##
## Destrava de tres jeitos, que sao os tres que o jogo tem: arrastar a trava
## com o mouse ate o fim, tocar no trilho (a trava corre sozinha), ou a tecla de
## usar / o botao A.
class_name SoBloqueio
extends AppCelular

## O trilho da trava, e a trava.
const TRILHO := Rect2(9.0, 196.0, 128.0, 16.0)
const TRAVA := 26.0
## Quanto tempo a trava leva para correr sozinha (s).
const CORRE := 0.22

signal destravou()

## De 0 (trava no comeco) a 1 (no fim).
var trava: float = 0.0
var _correndo: bool = false
var _arrastando: bool = false


func abrir() -> void:
	trava = 0.0
	_correndo = false
	_arrastando = false


func processar(delta: float) -> void:
	super.processar(delta)
	if _correndo:
		trava = minf(1.0, trava + delta / CORRE)
		if trava >= 1.0:
			_correndo = false
			destravou.emit()
	elif not _arrastando and trava > 0.0:
		# Soltou no meio: a trava volta.
		trava = maxf(0.0, trava - delta * 4.0)


func destravar() -> void:
	if _correndo or trava >= 1.0:
		return
	_correndo = true
	AudioDirector.tocar_ui(&"clique", -10.0, 1.2)


func acao(nome: StringName) -> bool:
	if nome == &"ok" or nome == &"dir":
		destravar()
		return true
	return nome != &"voltar"


func toque(p: Vector2) -> bool:
	if TRILHO.grow(4.0).has_point(p):
		destravar()
		return true
	return false


func arrastar(desde: Vector2, delta: Vector2, fim: bool) -> bool:
	if _correndo:
		return true
	if not TRILHO.grow(6.0).has_point(desde):
		return false
	_arrastando = not fim
	trava = clampf(trava + delta.x / (TRILHO.size.x - TRAVA - 4.0), 0.0, 1.0)
	if fim and trava > 0.8:
		destravar()
	return true


func desenhar(visor: Control) -> void:
	v = visor
	SoFundo.desenhar(v, Celular.fundo_de_tela, piscar, alto_tela)
	# A faixa de cima: preta translucida com o brilho de vidro, a hora e a data.
	var topo := Rect2(0.0, SoFundo.BARRA, L, 40.0)
	grad_v(topo, Color(0.0, 0.0, 0.0, 0.62), Color(0.0, 0.0, 0.0, 0.5))
	ret(Rect2(0.0, topo.position.y, L, 0.5), Color(1, 1, 1, 0.12))
	ret(Rect2(0.0, topo.end.y - 0.5, L, 0.5), Color(1, 1, 1, 0.18))
	var hora := SoFundo.hora()
	t(Vector2(0.0, topo.position.y + 26.0), hora, 25, Color(0, 0, 0, 0.5), f_reg, L,
		HORIZONTAL_ALIGNMENT_CENTER)
	t(Vector2(0.0, topo.position.y + 25.4), hora, 25, Color.WHITE, f_reg, L,
		HORIZONTAL_ALIGNMENT_CENTER)
	t(Vector2(0.0, topo.position.y + 35.0), SoFundo.data_por_extenso(), 6, Color(1, 1, 1, 0.9),
		f_semi, L, HORIZONTAL_ALIGNMENT_CENTER)
	_avisos(topo.end.y + 8.0)
	_trava()


## Os avisos que chegaram com o aparelho no bolso: o balao do app, como no iOS.
func _avisos(y: float) -> void:
	var lista: Array = Celular.avisos_da_trava()
	for i in mini(lista.size(), 3):
		var a: Dictionary = lista[i]
		var r := Rect2(6.0, y + float(i) * 25.0, L - 12.0, 22.0)
		arred(r, 4.0, Color(0.0, 0.0, 0.0, 0.55))
		arred(r, 4.0, Color(1, 1, 1, 0.16), false, 0.5)
		CatalogoDeApps.icone(v, StringName(a["app"]), Rect2(r.position + Vector2(4.0, 4.0),
			Vector2(14.0, 14.0)))
		t(r.position + Vector2(22.0, 9.0), cortar(String(a["titulo"]), 6, r.size.x - 50.0, f_bold),
			6, Color.WHITE, f_bold)
		t(Vector2(r.end.x - 30.0, r.position.y + 9.0), String(a.get("hora", "")), 5,
			Color(1, 1, 1, 0.6), f_semi, 26.0, HORIZONTAL_ALIGNMENT_RIGHT)
		t(r.position + Vector2(22.0, 17.0), cortar(String(a["texto"]), 6, r.size.x - 26.0), 6,
			Color(1, 1, 1, 0.85))


func _trava() -> void:
	var faixa := Rect2(0.0, TRILHO.position.y - 9.0, L, alto_tela - TRILHO.position.y + 9.0)
	grad_v(faixa, Color(0.0, 0.0, 0.0, 0.5), Color(0.0, 0.0, 0.0, 0.66))
	ret(Rect2(0.0, faixa.position.y, L, 0.5), Color(1, 1, 1, 0.15))
	# O trilho: fundo, sombra de dentro e o fio claro embaixo.
	arred(TRILHO, 4.5, Color(0.0, 0.0, 0.0, 0.62))
	arred(Rect2(TRILHO.position + Vector2(0.0, 0.6), TRILHO.size), 4.5, Color(1, 1, 1, 0.12),
		false, 0.5)
	# O texto com o brilho correndo: tres passadas, a do meio mais clara, uma
	# faixa estreita que anda da esquerda para a direita.
	var texto := "deslize para desbloquear"
	var x0 := TRILHO.position.x + TRAVA + 4.0
	var largura := TRILHO.size.x - TRAVA - 6.0
	var y := TRILHO.position.y + 10.4
	var some := clampf(1.0 - trava * 2.2, 0.0, 1.0)
	# Letra por letra, com o brilho de cada uma pela distancia ate a faixa que
	# corre: o texto e o brilho saem do MESMO calculo de posicao. Com o texto
	# inteiro de um jeito e o brilho letra a letra, o espacamento nao batia e a
	# frase aparecia dobrada.
	var onda := fmod(piscar * 0.55, 1.4) - 0.2
	var tw := 0.0
	for letra: String in texto:
		tw += w(letra, 7, f_reg)
	var xt := x0 + (largura - tw) * 0.5
	var xc := xt + onda * tw
	var fatia := tw * 0.12
	var xs := xt
	for letra: String in texto:
		var lw := w(letra, 7, f_reg)
		var perto := 1.0 - smoothstep(0.0, fatia, absf(xs + lw * 0.5 - xc))
		t(Vector2(xs, y), letra, 7, Color(1, 1, 1, (0.42 + 0.5 * perto) * some), f_reg)
		xs += lw
	# A trava: botao cinza de vidro com a seta.
	var tx := TRILHO.position.x + 1.5 + trava * (TRILHO.size.x - TRAVA - 3.0)
	var botao := Rect2(tx, TRILHO.position.y + 1.5, TRAVA, TRILHO.size.y - 3.0)
	var pts := AppCelular.cantos(botao, 3.5)
	var cores := PackedColorArray()
	for p: Vector2 in pts:
		var k := (p.y - botao.position.y) / botao.size.y
		cores.append(Color("f4f5f7").lerp(Color("a3a8b0"), k))
	v.draw_polygon(pts, cores)
	arred(botao, 3.5, Color(0, 0, 0, 0.35), false, 0.5)
	var c := botao.get_center()
	var seta := Color("7d838c")
	v.draw_colored_polygon(PackedVector2Array([c + Vector2(-5.0, -1.4), c + Vector2(1.0, -1.4),
		c + Vector2(1.0, -3.8), c + Vector2(5.5, 0.0), c + Vector2(1.0, 3.8), c + Vector2(1.0, 1.4),
		c + Vector2(-5.0, 1.4)]), seta)
	alvo(TRILHO.grow(4.0), &"trava")
