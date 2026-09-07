## Autoload. A carteira de identidade na mao, em tela cheia.
##
## E o unico lugar do jogo onde a interface NAO finge ser papel de bloco: aqui
## ela finge ser um documento plastificado, com trama de fundo, foto colada,
## digital e zona de leitura no rodape. A troca de vocabulario e proposital — o
## documento tem de parecer uma coisa que existe no mundo e que a pessoa da
## frente acabou de tirar do bolso, nao mais uma janela do jogo.
##
## Tudo que aparece aqui sai do RegistroCivil pelo id. Nao ha nenhum campo
## digitado, nenhum texto de exemplo: o nome do pai que esta escrito e o nome de
## uma pessoa que existe no mesmo registro, com CPF proprio, e que pode ser
## consultada no aplicativo do celular. E isso que faz a carteira valer alguma
## coisa em vez de ser um cartaz bonito.
##
## Sobre o desenho: o brasao e um escudo generico gerado por tools/gerar_npc.py,
## e nao a insignia da Republica. O documento e adereco de ficcao dentro de um
## jogo de 480x270 com dither — nao tenta ser, nem pode ser, reproducao de
## documento oficial.
extends CanvasLayer

const UI := "res://assets/ui/%s.png"
const FONTE_P := "res://assets/fontes/psx_pequena.fnt"
const FONTE_M := "res://assets/fontes/psx_media.fnt"
const FONTE_MONO := "res://assets/fontes/psx_mono.fnt"

const TELA := Vector2(480.0, 270.0)
const CARTAO := Rect2(48.0, 24.0, 384.0, 228.0)

## Distancia entre a etiqueta miuda e o valor dela.
##
## Treze, e nao dez. A fonte pequena tem treze pixels de altura de linha e a
## etiqueta desenha a partir do topo da caixa: com dez, o rabo do P de CPF batia
## no numero embaixo e a ficha inteira lia como texto empilhado errado.
const VAO_CAMPO := 13.0

const TINTA := Color("22301f")
const TINTA_FRACA := Color("5c6b52")
const PAPEL := Color("dfe6d2")
const FAIXA := Color("2f4a33")
const CARIMBO := Color("8e2c22")

signal abriu()
signal fechou()

var ativo: bool = false

var _raiz: Control
var _foto: TextureRect
var _campos: Dictionary[StringName, Label] = {}
var _carimbo: Label
var _ficha: Dictionary = {}


func _ready() -> void:
	layer = 130
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar()
	_raiz.visible = false


# --- montagem ---------------------------------------------------------------

func _tex(nome: String) -> Texture2D:
	var caminho := UI % nome
	if not ResourceLoader.exists(caminho):
		push_warning("Documento: textura ausente %s" % caminho)
		return null
	return load(caminho) as Texture2D


func _imagem(nome: String, r: Rect2, estica: int = TextureRect.STRETCH_SCALE,
		modulacao: Color = Color.WHITE) -> TextureRect:
	var t := TextureRect.new()
	t.texture = _tex(nome)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = estica
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.modulate = modulacao
	_raiz.add_child(t)
	t.position = r.position
	t.size = r.size
	return t


func _rotulo(texto: String, r: Rect2, fonte: String, cor: Color,
		alinhamento: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_color_override(&"font_color", cor)
	l.horizontal_alignment = alinhamento
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	l.clip_text = true
	if ResourceLoader.exists(fonte):
		l.add_theme_font_override(&"font", load(fonte))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(l)
	l.position = r.position
	l.size = r.size
	return l


## Um campo do documento: etiqueta miuda em cima, valor embaixo. E o arranjo de
## qualquer documento de identificacao, e e o que faz o olho achar o CPF sem ler
## a carteira inteira.
func _campo(chave: StringName, etiqueta: String, x: float, y: float,
		largura: float, fonte_valor: String = FONTE_M) -> void:
	_rotulo(etiqueta, Rect2(x, y, largura, 13.0), FONTE_P, TINTA_FRACA)
	_campos[chave] = _rotulo("", Rect2(x, y + VAO_CAMPO, largura, 16.0),
		fonte_valor, TINTA)


func _linha(x: float, y: float, largura: float, cor: Color,
		grossura: float = 1.0) -> ColorRect:
	var c := ColorRect.new()
	c.color = cor
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(c)
	c.position = Vector2(x, y)
	c.size = Vector2(largura, grossura)
	return c


func _montar() -> void:
	_raiz = Control.new()
	_raiz.name = "Documento"
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Escurece a cena atras. O documento e uma coisa que se traz para perto do
	# rosto; o mundo tem de sair de foco por tras dele.
	var veu := ColorRect.new()
	veu.color = Color(0.02, 0.03, 0.02, 0.72)
	veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(veu)
	veu.set_anchors_preset(Control.PRESET_FULL_RECT)

	var sombra := ColorRect.new()
	sombra.color = Color(0, 0, 0, 0.5)
	sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(sombra)
	sombra.position = CARTAO.position + Vector2(3.0, 4.0)
	sombra.size = CARTAO.size

	# A trama de fundo e ladrilhada, nunca esticada: esticar uma textura de
	# 128 px para 384 triplica o grao e a trama vira mancha.
	_imagem("doc_guilhoche", CARTAO, TextureRect.STRETCH_TILE, PAPEL)

	_moldura()

	_montar_cabecalho()
	_montar_esquerda()
	_montar_direita()
	_montar_rodape()

	_carimbo = _rotulo("", Rect2(120.0, 124.0, 240.0, 24.0), FONTE_M,
		Color(CARIMBO.r, CARIMBO.g, CARIMBO.b, 0.86), HORIZONTAL_ALIGNMENT_CENTER)
	_carimbo.pivot_offset = Vector2(120.0, 12.0)
	_carimbo.rotation = deg_to_rad(-9.0)
	_carimbo.visible = false

	_rotulo("[E] GUARDAR", Rect2(0.0, 256.0, TELA.x, 13.0), FONTE_P,
		Color(0.72, 0.72, 0.66), HORIZONTAL_ALIGNMENT_CENTER)


## Quatro tiras de um pixel. Um NinePatch daria o mesmo com mais peca movel, e
## a borda do cartao nunca muda de tamanho.
func _moldura() -> void:
	var e := CARTAO.end
	_linha(CARTAO.position.x, CARTAO.position.y, CARTAO.size.x, FAIXA)
	_linha(CARTAO.position.x, e.y - 1.0, CARTAO.size.x, FAIXA)
	var esq := _linha(CARTAO.position.x, CARTAO.position.y, 1.0, FAIXA)
	esq.size.y = CARTAO.size.y
	var dir := _linha(e.x - 1.0, CARTAO.position.y, 1.0, FAIXA)
	dir.size.y = CARTAO.size.y


## Cabecalho: so o selo e as duas linhas de titulo.
##
## O numero do registro geral saiu daqui e virou um campo do corpo, ao lado do
## CPF. Na primeira versao ele ficava no canto direito do cabecalho, como na
## carteira de verdade, e batia de frente com "REPUBLICA FEDERATIVA DO BRASIL":
## a fonte pequena rende nove pixels por caractere e trinta caracteres ja tomam
## 270 dos 368 px uteis. Documento de papel tem espaco para as duas coisas na
## mesma linha; uma tela de 480x270, nao.
func _montar_cabecalho() -> void:
	_imagem("doc_brasao", Rect2(56.0, 29.0, 26.0, 26.0))
	_rotulo("REPUBLICA FEDERATIVA DO BRASIL", Rect2(88.0, 28.0, 300.0, 13.0),
		FONTE_P, TINTA_FRACA)
	_rotulo("CARTEIRA DE IDENTIDADE", Rect2(88.0, 41.0, 300.0, 16.0),
		FONTE_M, TINTA)
	_linha(56.0, 60.0, 368.0, TINTA_FRACA)


func _montar_esquerda() -> void:
	# A foto tem moldura escura e um pixel de folga: sem a moldura ela flutua
	# sobre a trama e parece um adesivo, e adesivo nao le como documento.
	var moldura := ColorRect.new()
	moldura.color = TINTA
	moldura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(moldura)
	moldura.position = Vector2(55.0, 67.0)
	moldura.size = Vector2(Retrato.LARGURA + 2, Retrato.ALTURA + 2)

	_foto = TextureRect.new()
	_foto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_foto.stretch_mode = TextureRect.STRETCH_SCALE
	_foto.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_foto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_foto)
	_foto.position = Vector2(56.0, 68.0)
	_foto.size = Vector2(Retrato.LARGURA, Retrato.ALTURA)

	# Sem etiqueta embaixo da digital nem da assinatura. A coluna da esquerda tem
	# 48 px uteis e "POLEGAR DIREITO" precisa de 135: o texto era cortado no meio
	# e sobrava "GAR DII" no meio do documento, que e pior que nao ter legenda.
	# Digital e rabisco se explicam sozinhos.
	_imagem("doc_digital", Rect2(58.0, 130.0, 36.0, 36.0),
		TextureRect.STRETCH_SCALE, Color(0.25, 0.28, 0.24, 0.85))

	# Assinatura: uma linha e um rabisco. O rabisco e a mesma digital girada e
	# achatada — nao vale um asset novo, e a 480x270 le como caneta.
	_imagem("doc_digital", Rect2(55.0, 180.0, 44.0, 14.0),
		TextureRect.STRETCH_SCALE, Color(0.18, 0.2, 0.3, 0.6))
	_linha(54.0, 196.0, 46.0, TINTA_FRACA)


func _montar_direita() -> void:
	var x := 110.0
	var meio := 300.0
	var larg_a := 182.0
	var larg_b := 124.0

	_campo(&"nome", "NOME", x, 64.0, 314.0)
	_rotulo("FILIACAO", Rect2(x, 98.0, 314.0, 13.0), FONTE_P, TINTA_FRACA)
	_campos[&"mae"] = _rotulo("", Rect2(x, 111.0, 314.0, 13.0), FONTE_P, TINTA)
	_campos[&"pai"] = _rotulo("", Rect2(x, 124.0, 314.0, 13.0), FONTE_P, TINTA)

	_campo(&"rg", "REGISTRO GERAL", x, 146.0, larg_a, FONTE_MONO)
	_campo(&"cpf", "CPF", meio, 146.0, larg_b, FONTE_MONO)
	_campo(&"naturalidade", "NATURALIDADE", x, 180.0, larg_a)
	_campo(&"nascimento", "NASCIMENTO", meio, 180.0, larg_b, FONTE_MONO)


func _montar_rodape() -> void:
	_linha(56.0, 212.0, 368.0, TINTA_FRACA)
	_campos[&"sexo"] = _rotulo("", Rect2(56.0, 214.0, 200.0, 13.0), FONTE_P,
		TINTA_FRACA)
	_campos[&"expedicao"] = _rotulo("", Rect2(224.0, 214.0, 200.0, 13.0),
		FONTE_P, TINTA_FRACA, HORIZONTAL_ALIGNMENT_RIGHT)
	_campos[&"orgao"] = _rotulo("", Rect2(56.0, 227.0, 200.0, 13.0), FONTE_P,
		TINTA_FRACA)
	_campos[&"validade"] = _rotulo("", Rect2(224.0, 227.0, 200.0, 13.0),
		FONTE_P, TINTA_FRACA, HORIZONTAL_ALIGNMENT_RIGHT)
	# Zona de leitura mecanica. Nao codifica nada de verdade: e a faixa de
	# caracteres que todo documento tem no rodape, e a ausencia dela e das
	# primeiras coisas que fazem um documento falso parecer falso.
	_campos[&"zona"] = _rotulo("", Rect2(56.0, 240.0, 368.0, 13.0), FONTE_MONO,
		Color(0.28, 0.33, 0.26))


# --- conteudo ---------------------------------------------------------------

func abrir(ficha: Dictionary) -> void:
	if ativo or ficha.is_empty():
		return
	ativo = true
	_ficha = ficha
	_preencher(ficha)
	_raiz.visible = true
	_travar_jogador(true)
	AudioDirector.tocar_ui(&"papel", -6.0)
	_animar_entrada()
	abriu.emit()


func fechar() -> void:
	if not ativo:
		return
	ativo = false
	_raiz.visible = false
	_travar_jogador(false)
	AudioDirector.tocar_ui(&"clique", -14.0)
	fechou.emit()


func _preencher(f: Dictionary) -> void:
	_foto.texture = Retrato.gerar_textura(f.get("aparencia", {}))
	_campos[&"rg"].text = String(f["rg"])
	_campos[&"nome"].text = String(f["nome"])
	_campos[&"mae"].text = "MAE: %s" % f["mae"]
	_campos[&"pai"].text = "PAI: %s" % f["pai"]
	_campos[&"naturalidade"].text = String(f["naturalidade"])
	_campos[&"nascimento"].text = String(f["nascimento"])
	_campos[&"cpf"].text = String(f["cpf"])
	_campos[&"sexo"].text = ("SEXO: MASCULINO" if StringName(f["sexo"]) == &"M"
		else "SEXO: FEMININO")
	_campos[&"validade"].text = "VALIDA ATE %s" % f["validade"]
	_campos[&"orgao"].text = "ORGAO: %s" % f["orgao"]
	_campos[&"expedicao"].text = "EXPEDIDA EM %s" % f["expedicao"]

	var so_numero := String(f["cpf"]).replace(".", "").replace("-", "")
	# A zona tem 368 px e a fonte mono rende sete por caractere: cabem 52. Um
	# sobrenome composto longo estourava a borda direita do cartao.
	var sobrenome := String(f["sobrenome"]).replace(" ", "<")
	var zona := "IDBRA%s<<%s<<%s" % [so_numero, sobrenome, String(f["primeiro"])]
	_campos[&"zona"].text = zona.substr(0, 52)

	var situacao := int(f.get("situacao", RegistroCivil.Situacao.REGULAR))
	_carimbo.visible = situacao != RegistroCivil.Situacao.REGULAR
	if _carimbo.visible:
		_carimbo.text = RegistroCivil.nome_da_situacao(situacao)


func _travar_jogador(preso: bool) -> void:
	var jogador := get_tree().get_first_node_in_group(&"player")
	if jogador != null and jogador.has_method("travar"):
		jogador.call("travar", preso)


## Entra crescendo um pouco, como uma coisa que foi levantada ate o rosto.
func _animar_entrada() -> void:
	_raiz.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_raiz.scale = Vector2(0.97, 0.97)
	_raiz.pivot_offset = TELA * 0.5
	var t := create_tween().set_parallel(true)
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(_raiz, "modulate", Color.WHITE, 0.14)
	t.tween_property(_raiz, "scale", Vector2.ONE, 0.18)


func _input(evento: InputEvent) -> void:
	if not ativo:
		return
	if (evento.is_action_pressed("interagir") or evento.is_action_pressed("pausa")
			or evento.is_action_pressed("ui_accept")
			or evento.is_action_pressed("examinar")):
		fechar()
		get_viewport().set_input_as_handled()
