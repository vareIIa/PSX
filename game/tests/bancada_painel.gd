## O painel do carro, fotografado e medido sem dirigir.
##
##     godot --path game --resolution 1280x720 res://tests/bancada_painel.tscn -- --teste-painel --estilo=moderno [--fundo=rua.png] [--saida=DIR]
##     godot --path game --resolution 1280x720 res://tests/bancada_painel.tscn -- --teste-painel --estilo=ps1 ...
##
## `--fundo` poe uma captura da rua atras do painel, para julgar a peca sobre a
## imagem em que ela vai viver; sem ele o fundo e um asfalto escuro chapado.
## `--saida` grava uma foto por estado.
##
## O que cada medida faz
## ---------------------
## P1  **Lugar.** A borda direita do mostrador na coluna do minimapa quando a
##     vinheta deixa, todo texto acima do piso de vinheta do estilo em uso, fora
##     da coluna da faixa de estado e abaixo do minimapa.
## P2  **O arco conta a rotacao.** Lido na FOTO: cada segmento e amostrado no
##     meio, e o numero de segmentos claros tem de ser o que o giro pede — nos
##     dois sentidos, porque um arco que nunca apaga tambem passaria num teste
##     que so contasse os acesos.
## P3  **A troca se ve.** Acima da faixa de troca os segmentos acesos sao ambar,
##     e a caixa da marcha acende.
## P4  **Seta.** Com a seta esquerda na metade acesa, a flecha esquerda e verde e
##     a direita nao.
## P5  **Freio de mao.** A lampada do freio e vermelha com o freio puxado, e
##     apagada sem ele.
## P6  **Motor desligado apaga o arco.** Nenhum segmento claro com o motor
##     desligado, mesmo com giro pedido.
## P7  **O texto cabe dentro do arco.** A palavra mais larga da linha de baixo e
##     o numero de tres algarismos, cada um na corda livre da sua altura. A
##     primeira foto tinha "CAPOTOU" encostado nos segmentos.
## P8  **Qualquer vinheta.** A barra de opcoes vai de 0 a 1, e P1 so mede a do
##     `settings.cfg` da maquina. De 0 a `VINHETA_GARANTIDA`, em passos de 0,05,
##     todo texto passa do piso e o mostrador nao sobe no minimapa; acima disso,
##     so nao sobe no minimapa. A primeira versao parava em 60 px de recuo, e com
##     a vinheta em 0,7 a marcha ficava em 0,29.
extends Node

## Ate que vinheta o texto tem de passar do piso. Acima dela nao ha lugar na
## coluna da direita em que ele passe: a quina clareia menos do que o piso pede.
const VINHETA_GARANTIDA := 0.80

const ESTADOS := {
	"cruzeiro": {"giro": 0.45, "kmh": 73.0, "marcha": "3", "farol": true},
	"troca": {"giro": 0.93, "kmh": 118.0, "marcha": "4", "farol": true},
	"seta_freio": {"giro": 0.12, "kmh": 0.0, "marcha": "1", "farol": true,
		"seta": -1, "seta_acesa": true, "freio_mao": true},
	"desligado": {"giro": 0.6, "kmh": 0.0, "marcha": "1", "ligado": false},
	"capotado": {"giro": 0.0, "kmh": 0.0, "marcha": "1", "ligado": false,
		"capotou": true},
}

var _passou := 0
var _total := 0
var _painel: PainelCarro
var _saida := ""


func _ready() -> void:
	_medir.call_deferred()


func _conta(nome: String, ok: bool, texto: String) -> void:
	_total += 1
	if ok:
		_passou += 1
	print("%s %s: %s" % ["[ok]" if ok else "[X ]", nome, texto])


func _medir() -> void:
	var fundo := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--fundo="):
			fundo = arg.trim_prefix("--fundo=")
		elif arg.begins_with("--saida="):
			_saida = arg.trim_prefix("--saida=")
	if not _saida.is_empty():
		DirAccess.make_dir_recursive_absolute(_saida)
	# O estilo e aplicado pelos autoloads no primeiro quadro.
	for _q in 4:
		await get_tree().process_frame
	var vinheta := float(get_node(^"/root/Settings").get(&"vignette"))
	print("\n=== painel do carro (vinheta %.2f) ===\n" % vinheta)

	var camada := CanvasLayer.new()
	camada.layer = 1
	add_child(camada)
	var tela := TextureRect.new()
	tela.size = UiEstilo.TELA
	tela.stretch_mode = TextureRect.STRETCH_SCALE
	tela.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var img := Image.new()
	if not fundo.is_empty() and img.load(fundo) == OK:
		tela.texture = ImageTexture.create_from_image(img)
		camada.add_child(tela)
	else:
		var chapado := ColorRect.new()
		chapado.size = UiEstilo.TELA
		chapado.color = Color("1c1b1d")
		camada.add_child(chapado)

	_painel = PainelCarro.new()
	add_child(_painel)
	await get_tree().process_frame

	_medir_lugar(vinheta)
	_medir_varredura()
	var fotos := {}
	for nome: String in ESTADOS:
		_painel.mostrar_fixo(ESTADOS[nome])
		for _q in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var foto := get_viewport().get_texture().get_image()
		fotos[nome] = foto
		if not _saida.is_empty():
			foto.save_png(_saida.path_join("painel_%s.png" % nome))
	_medir_arco(fotos)
	_medir_luzes(fotos)
	var folga_r := _painel.folga_do_rotulo()
	var folga_n := _painel.folga_do_numero()
	_conta("P7 o texto cabe dentro do arco", folga_r >= 0.0 and folga_n >= 0.0,
		"sobra %.1f px na palavra mais larga e %.1f px no numero de tres algarismos"
			% [folga_r, folga_n])
	print("\n%d de %d criterios" % [_passou, _total])
	get_tree().quit(0 if _passou == _total and _total > 0 else 1)


# --- P1 ----------------------------------------------------------------------

func _medir_lugar(vinheta: float) -> void:
	var c := _painel.centro()
	var caixa := PainelLayout.contorno(c)
	var texto := PainelLayout.vinheta_do_texto(c, vinheta)
	var faixa_dir := (UiEstilo.TELA.x + FaixaLayout.LARGURA_MAX) * 0.5
	var encostado := is_equal_approx(c.x + PainelLayout.RAIO, PainelLayout.DIREITA)
	# Com vinheta fraca ele tem de encostar; com forte, tem de ter andado so o
	# necessario — um pixel para o canto e o texto cai abaixo do piso.
	var um_para_o_canto := PainelLayout.vinheta_do_texto(c + Vector2(1.0, 1.0), vinheta)
	var justo := encostado or um_para_o_canto < UiEstilo.VINHETA_MIN \
		or c.x <= PainelLayout.x_minimo()
	var dentro := caixa.position.x >= UiEstilo.MARGEM \
		and caixa.end.x <= UiEstilo.TELA.x - UiEstilo.MARGEM + 2.0 \
		and caixa.end.y <= UiEstilo.TELA.y - UiEstilo.MARGEM + 2.0
	# O minimapa ocupa de 7 a 89, e o rotulo dele desce ate 102.
	var abaixo_do_mapa := caixa.position.y > 102.0
	var fora_da_faixa := c.x - PainelLayout.RAIO >= faixa_dir + PainelLayout.VAO_FAIXA - 0.01
	_conta("P1 lugar",
		texto >= UiEstilo.VINHETA_MIN and justo and dentro and abaixo_do_mapa
			and fora_da_faixa,
		"centro %s, borda direita %.0f (minimapa %.0f)%s; pior texto %.2f (piso %.2f); caixa %s"
			% [c, c.x + PainelLayout.RAIO, PainelLayout.DIREITA,
				" encostado" if encostado else " recuado pela vinheta",
				texto, UiEstilo.VINHETA_MIN, caixa])


# --- P8 ----------------------------------------------------------------------

func _medir_varredura() -> void:
	var falhas := PackedStringArray()
	var legivel_ate := -1.0
	for i in 21:
		var v := float(i) * 0.05
		var c := PainelLayout.centro(v)
		var texto := PainelLayout.vinheta_do_texto(c, v)
		if PainelLayout.contorno(c).position.y <= 102.0:
			falhas.append("%.2f sobe no minimapa" % v)
		if texto >= UiEstilo.VINHETA_MIN:
			if legivel_ate == float(i - 1) * 0.05 or i == 0:
				legivel_ate = v
		elif v <= VINHETA_GARANTIDA + 0.001:
			falhas.append("%.2f: texto a %.2f em %s" % [v, texto, c])
	_conta("P8 qualquer vinheta", falhas.is_empty(),
		"texto acima do piso de 0 a %.2f (garantido ate %.2f), vinheta 0,70 em %s%s"
			% [legivel_ate, VINHETA_GARANTIDA, PainelLayout.centro(0.7),
				"" if falhas.is_empty() else "; " + ", ".join(falhas)])


# --- P2, P3, P6 -------------------------------------------------------------

func _medir_arco(fotos: Dictionary) -> void:
	var cruzeiro := _segmentos(fotos["cruzeiro"])
	var pedido := PainelLayout.acesos(0.45)
	_conta("P2 o arco conta a rotacao", cruzeiro["claros"] == pedido
			and cruzeiro["primeiro_escuro"] == pedido,
		"giro 0,45: %d segmentos claros na foto, o primeiro escuro e o %d (pedido %d de %d)"
			% [cruzeiro["claros"], cruzeiro["primeiro_escuro"], pedido,
				PainelLayout.SEGMENTOS])

	var troca := _segmentos(fotos["troca"])
	var ambar := int(ceilf(PainelCarro.ACENDE_TROCA * PainelLayout.SEGMENTOS - 0.001))
	var foto: Image = fotos["troca"]
	var esc := float(foto.get_width()) / UiEstilo.TELA.x
	var c := _painel.centro()
	# A borda da caixa da marcha, no meio do lado de cima.
	var borda := c + PainelLayout.MARCHA - Vector2(0.0, PainelLayout.MARCHA_TAM.y * 0.5)
	var cor_borda := _pixel(foto, borda, esc)
	var borda_cruzeiro := _pixel(fotos["cruzeiro"], borda, esc)
	var seg_ambar: Color = troca["cores"][ambar]
	var seg_osso: Color = troca["cores"][2]
	_conta("P3 a troca se ve",
		_quente(seg_ambar) and not _quente(seg_osso) and _quente(cor_borda)
			and not _quente(borda_cruzeiro),
		"segmento %d %s (ambar), segmento 2 %s (osso); borda da marcha %s na troca e %s em cruzeiro"
			% [ambar, seg_ambar.to_html(false), seg_osso.to_html(false),
				cor_borda.to_html(false), borda_cruzeiro.to_html(false)])

	var desligado := _segmentos(fotos["desligado"])
	_conta("P6 motor desligado apaga o arco", desligado["claros"] == 0,
		"com o motor desligado e giro 0,6 pedido, %d segmentos claros" % desligado["claros"])


## Amostra o meio de cada segmento na foto.
func _segmentos(foto: Image) -> Dictionary:
	var esc := float(foto.get_width()) / UiEstilo.TELA.x
	var c := _painel.centro()
	var raio := (PainelLayout.ARCO_FORA + PainelLayout.ARCO_DENTRO) * 0.5
	var claros := 0
	var primeiro_escuro := -1
	var cores: Array[Color] = []
	for k in PainelLayout.SEGMENTOS:
		var t := (float(k) + 0.5) / float(PainelLayout.SEGMENTOS)
		var cor := _pixel(foto, c + PainelLayout.no_arco(t, raio), esc)
		cores.append(cor)
		if cor.get_luminance() > 0.35:
			claros += 1
		elif primeiro_escuro < 0:
			primeiro_escuro = k
	return {"claros": claros, "primeiro_escuro": primeiro_escuro, "cores": cores}


# --- P4, P5 -----------------------------------------------------------------

func _medir_luzes(fotos: Dictionary) -> void:
	var foto: Image = fotos["seta_freio"]
	var esc := float(foto.get_width()) / UiEstilo.TELA.x
	var c := _painel.centro()
	# O miolo da flecha: um pouco para dentro da ponta.
	var meio_esq := c + PainelLayout.SETA_ESQ + Vector2(-0.8, 0.0)
	var meio_dir := c + PainelLayout.SETA_DIR + Vector2(0.8, 0.0)
	var esq := _pixel(foto, meio_esq, esc)
	var dir := _pixel(foto, meio_dir, esc)
	_conta("P4 seta", _verde(esq) and not _verde(dir),
		"seta esquerda acesa: flecha esquerda %s, direita %s"
			% [esq.to_html(false), dir.to_html(false)])

	# O "P" do freio: amostra a maior luminancia vermelha na caixa da lampada.
	var com := _mais_vermelho(foto, c + PainelLayout.FREIO, esc)
	var sem := _mais_vermelho(fotos["cruzeiro"], c + PainelLayout.FREIO, esc)
	_conta("P5 freio de mao", com.r > 0.7 and com.r > com.g * 2.0 and sem.r < 0.5,
		"lampada do freio %s puxado e %s solto"
			% [com.to_html(false), sem.to_html(false)])


func _mais_vermelho(foto: Image, meio: Vector2, esc: float) -> Color:
	var melhor := Color.BLACK
	var m := PainelLayout.LAMPADA * 0.5
	for y in range(int((meio.y - m) * esc), int((meio.y + m) * esc) + 1):
		for x in range(int((meio.x - m) * esc), int((meio.x + m) * esc) + 1):
			var cor := foto.get_pixel(clampi(x, 0, foto.get_width() - 1),
				clampi(y, 0, foto.get_height() - 1))
			if cor.r - cor.g > melhor.r - melhor.g:
				melhor = cor
	return melhor


func _pixel(foto: Image, p: Vector2, esc: float) -> Color:
	var x := clampi(int(p.x * esc), 0, foto.get_width() - 1)
	var y := clampi(int(p.y * esc), 0, foto.get_height() - 1)
	return foto.get_pixel(x, y)


func _quente(c: Color) -> bool:
	return c.r > 0.75 and c.g > 0.35 and c.g < 0.75 and c.b < 0.4


func _verde(c: Color) -> bool:
	return c.g > 0.6 and c.g > c.r * 1.4 and c.g > c.b * 1.4
