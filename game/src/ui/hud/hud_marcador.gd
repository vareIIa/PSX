## O alvo pregado no mundo: um losango com a distancia, onde a coisa esta.
##
## Bussola diz para que lado; radar diz onde no mapa; o marcador diz QUAL
## predio, que e o que a nevoa esconde. Ele so aparece com o alvo na frente da
## camera (atras, quem responde e a bussola, que ja prende a marca na ponta) e
## some nos ultimos metros, quando o proprio lugar ja e o marcador.
##
## Projecao por `Camera3D.unproject_position`, que devolve coordenada do
## retangulo visivel do viewport: os mesmos 480x270 logicos do resto do HUD,
## no `viewport` e no `canvas_items`.
class_name HudMarcador
extends Control

## Altura acima do chao do alvo: acima da cabeca de quem esta na porta.
const ALTURA := 2.6
## Abaixo disto o marcador se apaga; acima de PERTO_CHEIO esta inteiro.
const PERTO_ZERO := 6.0
const PERTO_CHEIO := 14.0
## Margem da tela onde o marcador comeca a sumir, para nao encostar na borda.
const BORDA := 18.0

var escala := 1.0

var _marcas: Array[Dictionary] = []
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	_marcas.clear()
	var cam := get_viewport().get_camera_3d()
	var jogador := get_tree().get_first_node_in_group(&"player") as Node3D
	if cam == null or jogador == null or Interiores.dentro or not HudConfig.ver_marcador():
		queue_redraw()
		return
	var alvos: Array[Dictionary] = []
	var m := Missoes.posicao_do_alvo()
	if m != Vector3.INF:
		alvos.append({"pos": m, "cor": HudTema.acento(), "missao": true})
	if not Gps.destino.is_empty():
		var d: Vector3 = Gps.destino["mundo"]
		if m == Vector3.INF or Vector2(d.x - m.x, d.z - m.z).length() > 4.0:
			alvos.append({"pos": d, "cor": Color("ffd27a"), "missao": false})
	var tela := get_viewport().get_visible_rect().size
	for a: Dictionary in alvos:
		var p: Vector3 = a["pos"]
		var no_ar := Vector3(p.x, maxf(p.y, jogador.global_position.y) + ALTURA, p.z)
		if cam.is_position_behind(no_ar):
			continue
		var s := cam.unproject_position(no_ar)
		# Coordenada do viewport para a do HUD (480x270), qualquer que seja a
		# janela: a proporcao e a mesma.
		s = s * HudTema.TELA / tela
		var dist := Vector2(p.x - jogador.global_position.x, p.z - jogador.global_position.z).length()
		var a_perto := clampf((dist - PERTO_ZERO) / (PERTO_CHEIO - PERTO_ZERO), 0.0, 1.0)
		var dx := minf(s.x, HudTema.TELA.x - s.x)
		var dy := minf(s.y, HudTema.TELA.y - s.y)
		var a_borda := clampf(minf(dx, dy) / BORDA, 0.0, 1.0)
		var alfa := a_perto * a_borda
		if alfa <= 0.0:
			continue
		a["tela"] = s
		a["dist"] = dist
		a["alfa"] = alfa
		_marcas.append(a)
	queue_redraw()


func _draw() -> void:
	for a: Dictionary in _marcas:
		var c: Vector2 = a["tela"]
		var al: float = a["alfa"]
		var cor: Color = a["cor"]
		draw_set_transform(c, 0.0, Vector2(escala, escala))
		# Anel que respira devagar: marca viva, e nao adesivo na tela.
		var pulso := 0.5 + 0.5 * sin(_t * 2.4)
		draw_arc(Vector2.ZERO, 6.5 + pulso * 1.5, 0.0, TAU, 32,
			HudTema.alfa(cor, al * (0.35 - 0.2 * pulso)), 0.8, true)
		if bool(a["missao"]):
			HudTema.losango(self, Vector2.ZERO, 4.0, cor, al)
		else:
			draw_circle(Vector2.ZERO, 4.2, Color(0.0, 0.0, 0.0, 0.7 * al), true, -1.0, true)
			draw_circle(Vector2.ZERO, 3.2, HudTema.alfa(cor, al), true, -1.0, true)
		var d := HudTema.distancia(float(a["dist"]))
		var f := HudTema.semi()
		var w := HudTema.largura(f, d, HudTema.T_ROTULO)
		HudTema.texto(self, f, Vector2(-w * 0.5, 7.5), d, HudTema.T_ROTULO,
			HudTema.alfa(HudTema.TEXTO, al))
	draw_set_transform(Vector2.ZERO)
