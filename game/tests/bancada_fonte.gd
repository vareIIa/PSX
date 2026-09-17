## Texto em qualquer escala: o criterio A28 do PLANO_AAA_4K.
##
##     godot --path game --resolution 1280x720 --script res://tests/bancada_fonte.gd
##     (SEM --headless: sem janela nao ha rasterizacao de glifo)
##     --saida=DIR grava as tiras medidas
##
## O que esta bancada mede, e por que assim
## ----------------------------------------
## A interface e desenhada numa caixa de 480x270 e multiplicada ate a janela
## (`EstiloVisual._aplicar_resolucao`). Quando o multiplicador nao e inteiro —
## 1280x720 da 2,667 — a fonte de bitmap e REAMOSTRADA: a mesma haste de 1 px
## cai ora sobre um pixel, ora entre dois, e sai com larguras diferentes na
## mesma palavra. O arquivo do EstiloVisual ja avisava disso em texto; aqui
## vira numero.
##
## A regua e a MESMA haste dez vezes (dez letras I). Glifo repetido isola o que
## se quer medir: se o avanco e inteiro em 480x270, as dez hastes so podem
## divergir por causa da escala. Com uma palavra de verdade, a diagonal do A e a
## barriga do R entrariam na conta e o numero diria menos.
##
## Sao TRES medidas por haste, e nenhuma sozinha serve:
##
##   pico   a tinta do pixel mais forte da haste. Abaixo de 1,0 quer dizer que
##          nenhum pixel da haste e a cor do texto: e borrao, nao letra.
##   borda  quantos pixels ficam no meio-tom (entre 0,15 e 0,85). Uma borda
##          resolvida tem um de cada lado; um borrao tem a haste inteira.
##   largura  cobertura somada de meio-vao a meio-vao, que e a largura
##          ANALOGICA da haste. As dez tem de dar o mesmo numero.
##
## A largura sozinha ja passa hoje, e esta aqui de proposito: ela e a armadilha
## do conserto barato. Trocar o filtro do atlas para ponto endureceria a borda
## e resolveria o pico — e ai a MESMA haste sairia com 2 px numa letra e 3 na
## seguinte em 2,667x, que e a queixa escrita no `estilo_visual.gd`. Uma medida
## que so olha a borda aprova esse conserto; as tres juntas, nao.
##
## A28b mede outra coisa igualmente importante: a fonte do MODERNO tem de ter a
## MESMA metrica da de bitmap. Todo painel deste jogo tem `Vector2` escrito a
## mao em cima de larguras medidas com `UiEstilo.largura`. Uma fonte nova, por
## melhor que seja, que ande 1 px por palavra, arruma o texto e desarruma a
## tela.
extends SceneTree

## Multiplicadores de interface que a janela produz de verdade. A escala da UI e
## a altura da janela sobre 270: 960x540 da 2x, 1280x720 da 2,667x, 1600x900 da
## 3,333x, 1080p da 4x, 1440p da 5,333x e 4K da 8x exato.
##
## 1,5x entra na lista para ficar medido, e NAO conta para o criterio: ele pede
## uma janela de 405 px de altura, que nao existe, e abaixo de 2x o numero e
## geometria e nao qualidade — uma haste de 1 px vira 1,5 px de tela, e 1,5 px de
## tinta nao cabem igual em fase par e em fase impar por nenhum metodo.
const ESCALAS: Array[float] = [1.5, 2.0, 8.0 / 3.0, 10.0 / 3.0, 4.0, 16.0 / 3.0, 8.0]
## Abaixo disto a medida e informacao, nao criterio.
const ESCALA_MINIMA := 2.0
const REGUA := "IIIIIIIIII"
## Quantas marcas uma linha da regua tem de ter para valer como linha de haste.
const ESPERADAS := 10
## Quanto as dez hastes podem divergir entre si, em pixels de tela.
const FOLGA := 0.35
## Tinta minima do pixel mais forte de uma haste.
const PICO := 0.95
## Quantos pixels de meio-tom uma haste pode ter: um de cada lado.
const BORDA := 2

const FONTES := {
	"psx_pequena": "res://assets/fontes/psx_pequena.fnt",
	"psx_media": "res://assets/fontes/psx_media.fnt",
	"psx_titulo": "res://assets/fontes/psx_titulo.fnt",
	"psx_mono": "res://assets/fontes/psx_mono.fnt",
}

## Frases que o HUD desenha mesmo. A metrica tem de bater nelas, nao no alfabeto.
const AMOSTRAS: Array[String] = [
	"A CASA DA FUMACA",
	"270 M",
	"1.2 KM",
	"Va ate a casa da fumaca.",
	"[M] abre o GPS   [E] traca a rota",
	"OBJETIVO CUMPRIDO",
	"ETAPA 1/2",
	"CONTINUAR",
	"OPCOES",
	"SAIR DO JOGO",
]

var _saida := ""
var _passou := 0
var _total := 0


func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--saida="):
			_saida = arg.trim_prefix("--saida=")
	_medir()


func _medir() -> void:
	await process_frame
	await process_frame
	print("\n=== A28: texto em qualquer escala ===\n")
	for nome: String in FONTES:
		await _medir_fonte(nome, FONTES[nome])
	_medir_metrica()
	print("\n%d de %d criterios" % [_passou, _total])
	quit(0 if _passou == _total else 1)


func _conta(nome: String, ok: bool, texto: String) -> void:
	_total += 1
	if ok:
		_passou += 1
	print("%s %s: %s" % ["[ok]" if ok else "[X ]", nome, texto])


## Uma linha por escala: dez hastes, tres numeros cada.
func _medir_fonte(nome: String, caminho: String) -> void:
	if not ResourceLoader.exists(caminho):
		_conta(nome, false, "fonte ausente em %s" % caminho)
		return
	# A fonte DO JOGO, e nao o .fnt: no MODERNO o `EstiloVisual` ja pos a
	# vetorial no lugar deste caminho, e e ela que tem de passar. O .fnt e medido
	# logo abaixo, como o antes.
	var fonte := load(caminho) as Font
	var ff := fonte as FontFile
	print("      fonte do jogo: %s, tamanho nativo %d"
		% ["vetorial (MSDF)" if ff.multichannel_signed_distance_field else "bitmap",
			UiEstilo.tamanho_nativo(fonte)])
	var pior_espalhamento := 0.0
	var pior_pico := 1.0
	var pior_borda := 0
	var linhas := PackedStringArray()
	for escala: float in ESCALAS:
		var img := await _foto(fonte, REGUA, escala)
		if img == null:
			_conta(nome, false, "nao consegui fotografar em %.3fx" % escala)
			return
		if _saida != "":
			img.save_png("%s/%s_%d.png" % [_saida, nome, int(escala * 1000.0)])
		var hastes := _hastes(img)
		if hastes.size() < ESPERADAS:
			_conta(nome, false, "so achei %d hastes de %d em %.3fx"
				% [hastes.size(), ESPERADAS, escala])
			return
		var menor: float = hastes[0]["largura"]
		var maior: float = menor
		var soma := 0.0
		var pico := 1.0
		var borda := 0
		for h: Dictionary in hastes:
			var l: float = h["largura"]
			menor = minf(menor, l)
			maior = maxf(maior, l)
			soma += l
			pico = minf(pico, float(h["pico"]))
			borda = maxi(borda, int(h["borda"]))
		if escala >= ESCALA_MINIMA:
			pior_espalhamento = maxf(pior_espalhamento, maior - menor)
			pior_pico = minf(pior_pico, pico)
			pior_borda = maxi(pior_borda, borda)
		linhas.append("      %.3fx: pico %.2f, borda %d px, largura %.2f px (espalhamento %.2f)"
			% [escala, pico, borda, soma / float(hastes.size()), maior - menor])
	var ok := pior_pico >= PICO and pior_borda <= BORDA and pior_espalhamento <= FOLGA
	_conta("A28 %s" % nome, ok,
		"pior pico %.2f (>= %.2f), pior borda %d px (<= %d), espalhamento %.2f px (<= %.2f)"
			% [pior_pico, PICO, pior_borda, BORDA, pior_espalhamento, FOLGA])
	for l: String in linhas:
		print(l)
	await _medir_antes(caminho, fonte)


## O mesmo numero com o .fnt de bitmap, para a linha do antes ficar na mesma
## saida. `CACHE_MODE_IGNORE` le do disco em vez de devolver o que o
## `EstiloVisual` pos no lugar.
func _medir_antes(caminho: String, atual: Font) -> void:
	var bitmap := ResourceLoader.load(caminho, "FontFile",
		ResourceLoader.CACHE_MODE_IGNORE) as Font
	if bitmap == null or bitmap == atual:
		return
	var partes := PackedStringArray()
	for escala: float in ESCALAS:
		var img := await _foto(bitmap, REGUA, escala)
		if img == null:
			return
		var hastes := _hastes(img)
		if hastes.size() < ESPERADAS:
			return
		var pico := 1.0
		var borda := 0
		for h: Dictionary in hastes:
			pico = minf(pico, float(h["pico"]))
			borda = maxi(borda, int(h["borda"]))
		partes.append("%.3fx pico %.2f borda %d" % [escala, pico, borda])
	print("      antes (bitmap): %s" % ", ".join(partes))


## A fonte do MODERNO nao pode mover nenhum painel: mesma largura de frase.
func _medir_metrica() -> void:
	var vetor_existe := false
	for nome: String in FONTES:
		if ResourceLoader.exists(_vetor(FONTES[nome])):
			vetor_existe = true
	if not vetor_existe:
		print("\n(A28b pulado: ainda nao ha fonte vetorial para comparar)")
		return
	print("")
	var pior := 0.0
	var onde := ""
	for nome: String in FONTES:
		var bitmap := ResourceLoader.load(FONTES[nome], "FontFile",
			ResourceLoader.CACHE_MODE_IGNORE) as Font
		var vetor := load(FONTES[nome]) as Font
		if bitmap == null or vetor == null or bitmap == vetor:
			_conta("A28b %s" % nome, false,
				"a fonte do jogo ainda e a de bitmap (MODERNO desligado?)")
			continue
		var tam := UiEstilo.tamanho_nativo(bitmap)
		var alt_b := bitmap.get_height(tam)
		var alt_v := vetor.get_height(tam)
		if absf(alt_b - alt_v) > 0.5:
			_conta("A28b %s" % nome, false,
				"altura de linha %.1f contra %.1f" % [alt_b, alt_v])
			continue
		var pior_fonte := 0.0
		for s: String in AMOSTRAS:
			var lb := bitmap.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, tam).x
			var lv := vetor.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, tam).x
			var d := absf(lb - lv)
			if d > pior_fonte:
				pior_fonte = d
			if d > pior:
				pior = d
				onde = "%s: %s, %.1f contra %.1f" % [nome, s, lb, lv]
		_conta("A28b %s" % nome, pior_fonte <= 0.5,
			"altura de linha igual (%.1f), frase mais fora por %.2f px"
				% [alt_b, pior_fonte])
	if onde != "":
		print("      pior caso: %s" % onde)


static func _vetor(caminho: String) -> String:
	return caminho.replace(".fnt", "_v.ttf")


## Fotografa a frase numa tela do tamanho que a janela teria, com a mesma
## transformada de canvas que o modo `canvas_items` aplica.
##
## SubViewport, e nao a janela de verdade, por dois motivos: a tela desta
## maquina limita a janela em 1055 px de altura (4x nao caberia) e o
## `canvas_transform` reproduz exatamente o que o modo de escala faz — o que o
## `EstiloVisual` chama de escala da UI e isto aqui.
func _foto(fonte: Font, texto: String, escala: float) -> Image:
	var base := Vector2(480.0, 270.0)
	var vp := SubViewport.new()
	vp.size = Vector2i(int(round(base.x * escala)), int(round(base.y * escala)))
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var fundo := ColorRect.new()
	fundo.color = Color.BLACK
	fundo.position = Vector2.ZERO
	fundo.size = base
	vp.add_child(fundo)
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.position = Vector2(20.0, 40.0)
	rotulo.add_theme_color_override(&"font_color", Color.WHITE)
	UiEstilo.aplicar(rotulo, fonte)
	vp.add_child(rotulo)
	root.add_child(vp)
	# Depois de entrar na arvore: antes disso o viewport ainda nao tem canvas e o
	# motor recusa a transformada em silencio, com o teste medindo 1x achando que
	# mediu 4x.
	vp.canvas_transform = Transform2D().scaled(Vector2(escala, escala))
	await process_frame
	await process_frame
	var tex := vp.get_texture()
	var img: Image = null
	if tex != null:
		img = tex.get_image()
	vp.queue_free()
	return img


## Os tres numeros de cada haste, na linha do meio da letra.
##
## A linha medida e a do MEIO, e nao a mais cheia nem a mais vazia. A mais cheia
## e o pe da letra, onde a serifa da `psx_mono` tem 6 px; a mais vazia e a
## franja de cima, que com filtro linear e meio-tom puro. Valem as linhas com
## exatamente uma marca por letra, e dessas, a do meio.
static func _hastes(img: Image) -> Array[Dictionary]:
	var largura := img.get_width()
	var altura := img.get_height()
	var candidatas := PackedInt32Array()
	for y in altura:
		if _marcas(img, y) == ESPERADAS:
			candidatas.append(y)
	var saida: Array[Dictionary] = []
	if candidatas.is_empty():
		return saida
	var linha: int = candidatas[candidatas.size() / 2]
	var cob := PackedFloat32Array()
	cob.resize(largura)
	for x in largura:
		cob[x] = _cob(img, x, linha)
	var blocos: Array[Vector2i] = []
	var i := 0
	while i < largura:
		if cob[i] > 0.5:
			var j := i
			while j < largura and cob[j] > 0.5:
				j += 1
			blocos.append(Vector2i(i, j - 1))
			i = j
		else:
			i += 1
	for k in blocos.size():
		var b := blocos[k]
		var esq := maxi(0, b.x - 3) if k == 0 			else int(floor((blocos[k - 1].y + b.x) * 0.5))
		var dir := mini(largura - 1, b.y + 3) if k == blocos.size() - 1 			else int(ceil((b.y + blocos[k + 1].x) * 0.5))
		var soma := 0.0
		var pico := 0.0
		var meio_tom := 0
		for x in range(esq, dir + 1):
			var c := cob[x]
			soma += c
			pico = maxf(pico, c)
			if c > 0.15 and c < 0.85:
				meio_tom += 1
		saida.append({"largura": soma, "pico": pico, "borda": meio_tom})
	return saida


## Quantos blocos acesos a linha tem.
static func _marcas(img: Image, y: int) -> int:
	var n := 0
	var dentro := false
	for x in img.get_width():
		var aceso := _cob(img, x, y) > 0.5
		if aceso and not dentro:
			n += 1
		dentro = aceso
	return n


static func _cob(img: Image, x: int, y: int) -> float:
	var c := img.get_pixel(x, y)
	return maxf(c.r, maxf(c.g, c.b))
