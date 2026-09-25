## Faixa na tela dizendo que a janela e uma bancada medindo e que ela fecha
## sozinha.
##
## Bancada sem cenario abre uma janela cinza, e o laco que monta uma planta
## inteira no fio principal a deixa parada por meio segundo de cada vez: quem
## olha acha que travou e fecha (24/09/2026, duas vezes). A faixa diz o que e.

extends RefCounted


static func mostrar(dono: Node, texto: String) -> void:
	# A tela do jogo pode ser 480x270 esticada ou 4K nativa: a letra segue a altura.
	var alto := dono.get_viewport().get_visible_rect().size.y
	var letra := maxi(8, int(alto / 22.0))
	var camada := CanvasLayer.new()
	camada.layer = 128
	var fundo := ColorRect.new()
	fundo.color = Color(0.0, 0.0, 0.0, 0.72)
	fundo.set_anchors_preset(Control.PRESET_TOP_WIDE)
	fundo.custom_minimum_size = Vector2(0.0, letra * 3.2)
	camada.add_child(fundo)
	var rotulo := Label.new()
	rotulo.text = "BANCADA MEDINDO - FECHA SOZINHA. NAO FECHE.\n%s" % texto
	rotulo.add_theme_font_size_override(&"font_size", letra)
	rotulo.add_theme_color_override(&"font_color", Color(1.0, 0.85, 0.3))
	rotulo.position = Vector2(letra, letra * 0.4)
	fundo.add_child(rotulo)
	dono.add_child(camada)
