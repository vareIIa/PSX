## O papelzinho no canto que diz o que fazer agora.
##
## Por que e papel, e nao texto solto na tela
## ------------------------------------------
## Porque tudo que e interface neste jogo e papel: o inventario e uma prancha de
## recortes, o mapa do pause e uma pagina, o cartao do canto tem fita adesiva na
## quina. Um retangulo preto translucido com texto branco — que e o que a maioria
## dos jogos poe aqui — seria a unica coisa da tela que veio de outra decada.
##
## Entao o objetivo e um pedaco de papel colado no canto de cima da esquerda, do
## lado oposto ao minimapa, com fita na quina. Custa uma textura que ja existe.
##
## Por que ele some sozinho
## ------------------------
## Porque objetivo lido vira ruido. O cartao aparece quando a etapa muda, fica
## na tela o tempo de ser lido duas vezes e depois encolhe para uma tira sem a
## dica de tecla. Quem esqueceu abre o GPS, que e onde o alfinete verde continua.
##
## Quem decide onde cada coisa fica
## --------------------------------
## `CartaoLayout`, e nao este arquivo. Aqui so se aplica o que ele respondeu:
## cria o `Label`, poe no retangulo, escreve a linha. Essa separacao existe
## porque a versao anterior tinha o empilhamento escrito no meio da montagem,
## onde a unica forma de conferir era abrir o jogo e olhar — e olhar nao acha
## colisao de 3 px que so aparece com titulo comprido.
##
## O que estava errado, em uma frase: titulo e distancia nasciam no MESMO
## retangulo, as linhas andavam 10 px numa fonte de 13, e o `Label` nao prendia o
## TAMANHO da fonte, entao o TextServer esticava a bitmap de 11 para 16 e a linha
## real virava 18,9. `tests/checar_hud.gd` afirma que nada disso volta.
class_name HudMissao
extends CanvasLayer

const UI := "res://assets/ui/%s.png"

## Canto de cima da esquerda. O minimapa mora na direita, e as duas coisas nao
## podem disputar o mesmo olho.
const MARGEM := Vector2(UiEstilo.MARGEM, UiEstilo.MARGEM)

var _raiz: Control
var _sombra: ColorRect
var _papel: TextureRect
var _borda: Control
var _regua: ColorRect
var _bussola: Control
var _rotulos: Dictionary[String, Label] = {}
var _encolher: SceneTreeTimer
var _jogador: Node3D
var _fonte: Font
## Dados da etapa em cartaz. Guardados porque o rodape se remonta a cada passo
## do jogador e precisa reempilhar o cartao com os mesmos textos.
var _dados: Dictionary = {}
var _com_dica: bool = true
## Rumo ate o alvo relativo a frente do jogador, em radianos.
var _rumo_relativo: float = 0.0
## Distancia ja formatada, so para nao remontar o cartao quando ela nao mudou.
var _ultima_distancia: String = ""


func _ready() -> void:
	layer = UiEstilo.CAMADA_CARTAO
	# Mesmo grupo do minimapa: cena cortada esconde os dois de uma vez.
	add_to_group(&"hud")
	_montar()
	Missoes.iniciou.connect(_ao_mudar)
	Missoes.avancou.connect(_ao_mudar)
	Missoes.concluiu.connect(_ao_concluir)
	Interiores.entrou.connect(_ao_entrar_em_comodo)
	Interiores.saiu.connect(_ao_sair_de_comodo)
	_raiz.visible = false
	set_process(false)


func _montar() -> void:
	_fonte = load(UiEstilo.FONTE_P) as Font

	_raiz = Control.new()
	_raiz.name = "CartaoMissao"
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Sombra dois pixels abaixo e a direita, como a do cartao do minimapa. E o
	# que descola o papel do fundo sem precisar de moldura grossa.
	_sombra = ColorRect.new()
	_sombra.name = "Sombra"
	_sombra.color = UiEstilo.PAPEL_SOMBRA
	_sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_sombra)
	_sombra.position = MARGEM + Vector2(2.0, 2.0)

	_papel = TextureRect.new()
	_papel.name = "Papel"
	var caminho := UI % "ui_papel"
	if ResourceLoader.exists(caminho):
		_papel.texture = load(caminho)
	_papel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_papel.stretch_mode = TextureRect.STRETCH_SCALE
	_papel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_papel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_papel)
	_papel.position = MARGEM
	_papel.size = Vector2(CartaoLayout.LARGURA, 0.0)
	# Luz somada na textura. Sem ela o papel fica 29 niveis acima da parede em
	# nevoa densa e o cartao le como mancha; ver `UiEstilo.PAPEL_LUZ`.
	_papel.modulate = UiEstilo.PAPEL_LUZ

	# Contorno de 1 px, desenhado por cima do papel e por baixo do texto. E a
	# mesma peca que separa quadra de quadra no minimapa: num fundo claro o valor
	# do preenchimento nao basta, quem separa duas superficies e a borda.
	_borda = Control.new()
	_borda.name = "Borda"
	_borda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_borda.draw.connect(func() -> void:
		_borda.draw_rect(Rect2(Vector2.ZERO, _borda.size), UiEstilo.TINTA, false,
			UiEstilo.PAPEL_BORDA))
	_raiz.add_child(_borda)
	_borda.position = MARGEM

	# A sombra e a borda acompanham o papel quando ele encolhe.
	_papel.item_rect_changed.connect(func() -> void:
		_sombra.size = _papel.size
		_borda.size = _papel.size
		_borda.queue_redraw())

	var fita := TextureRect.new()
	fita.name = "Fita"
	var fita_tex := UI % "ui_fita"
	if ResourceLoader.exists(fita_tex):
		fita.texture = load(fita_tex)
	fita.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fita.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fita.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(fita)
	fita.position = MARGEM + Vector2(-6.0, -4.0)
	fita.size = Vector2(34.0, 11.0)
	fita.pivot_offset = Vector2(17.0, 5.5)
	# Torta para o lado contrario da fita do minimapa. Duas fitas com a mesma
	# inclinacao nos dois cantos leem como moldura, e nao como colagem.
	fita.rotation = deg_to_rad(6.0)

	# Seta do rodape. Desenhada, e nao textura: ela gira a cada quadro e uma
	# textura girada num cartao de 186 px vira mancha.
	# Regua do cabecalho. `ColorRect` de 1 px, e nao linha desenhada: ela muda de
	# largura junto com o cartao e um `_draw` proprio custaria um no a mais para
	# desenhar um retangulo.
	_regua = ColorRect.new()
	_regua.name = "Regua"
	_regua.color = UiEstilo.TINTA_FRACA
	_regua.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_regua.visible = false
	_raiz.add_child(_regua)

	_bussola = Control.new()
	_bussola.name = "Bussola"
	_bussola.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bussola.draw.connect(_desenhar_bussola)
	_raiz.add_child(_bussola)
	_bussola.size = Vector2(CartaoLayout.BUSSOLA, CartaoLayout.BUSSOLA)

	for nome: String in ["titulo", "etapa", "objetivo", "dica", "distancia"]:
		_rotulos[nome] = _rotulo(nome)


func _rotulo(nome: String) -> Label:
	var l := Label.new()
	l.name = nome
	l.add_theme_color_override(&"font_color", _cor_de(nome))
	# Fonte E tamanho. Sem o tamanho o Label desenha no padrao do tema, que
	# estica a fonte de bitmap e derruba toda a conta de layout de uma vez. Ver o
	# cabecalho de `ui_estilo.gd`.
	UiEstilo.aplicar(l, _fonte)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.visible = false
	_raiz.add_child(l)
	return l


func _cor_de(nome: String) -> Color:
	match nome:
		"titulo":
			return UiEstilo.TINTA_TITULO
		"etapa", "dica":
			return UiEstilo.TINTA_FRACA
		_:
			return UiEstilo.TINTA


# --- aplicacao do layout ----------------------------------------------------

## Pergunta ao `CartaoLayout` e obedece. Toda a decisao de posicao mora la; aqui
## so se escreve o resultado nos nos.
func _aplicar(com_dica: bool) -> float:
	_com_dica = com_dica
	var plano := CartaoLayout.montar(_fonte, _dados, com_dica)
	for l: Label in _rotulos.values():
		l.visible = false
	_bussola.visible = false
	_regua.visible = false
	var caixas: Array = plano["caixas"]
	for caixa: Dictionary in caixas:
		var nome := String(caixa["nome"])
		var r: Rect2 = caixa["rect"]
		if nome == "bussola":
			_bussola.visible = true
			_bussola.position = MARGEM + r.position
			continue
		if nome == "regua":
			_regua.visible = true
			_regua.position = MARGEM + r.position
			_regua.size = r.size
			continue
		var l: Label = _rotulos.get(nome)
		if l == null:
			continue
		l.visible = true
		l.text = "\n".join(caixa["linhas"] as PackedStringArray)
		l.horizontal_alignment = int(caixa["alinhamento"]) as HorizontalAlignment
		l.position = MARGEM + r.position
		l.size = r.size
	var papel: Rect2 = plano["papel"]
	return papel.size.y


# --- estado -----------------------------------------------------------------

func _ao_mudar(missao: Dictionary) -> void:
	var etapa := Missoes.etapa_atual()
	if etapa.is_empty():
		return
	# Quantas etapas a missao tem, e em qual o jogador esta. Sem isto o cartao
	# diz o que fazer e nao diz quanto falta — que e a diferenca entre uma tarefa
	# e uma lista.
	var etapas: Array = missao.get("etapas", [])
	var i := int(missao.get("etapa", 0))
	_dados = {
		"titulo": String(missao["titulo"]),
		"etapa": "%d/%d" % [i + 1, etapas.size()] if etapas.size() > 1 else "",
		"objetivo": String(etapa.get("texto", "")),
		"dica": String(etapa.get("dica", "")),
		"distancia": "",
	}
	_ultima_distancia = ""
	_abrir()


## O cartao entra encostado na borda e desliza para dentro.
##
## Entrar deslizando e nao piscando: o objetivo muda no meio da rua, com o
## jogador andando, e uma coisa que aparece do nada no canto do olho le como
## falha de desenho. Vindo de fora da tela, le como alguem colando um papel.
func _abrir() -> void:
	_raiz.visible = true
	set_process(true)
	_papel.size.y = _aplicar(true)
	AudioDirector.tocar_ui(&"papel", -16.0)

	_raiz.position.x = -CartaoLayout.LARGURA - MARGEM.x
	_raiz.modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(_raiz, "position:x", 0.0, UiEstilo.T_ENTRADA)
	t.tween_property(_raiz, "modulate:a", 1.0, 0.2)

	if _encolher != null and is_instance_valid(_encolher):
		# Etapa nova antes de a anterior encolher: o relogio velho nao pode
		# encolher o cartao novo dois segundos depois de ele abrir.
		_encolher.timeout.disconnect(_ao_encolher)
	_encolher = get_tree().create_timer(UiEstilo.T_LEITURA)
	_encolher.timeout.connect(_ao_encolher)


## Encolhe agora, sem esperar a leitura. So a captura automatizada usa: a tira e
## o estado em que o cartao passa a maior parte da partida, e esperar doze
## segundos por ela num `--shot-frame` nao e uma opcao.
func encolher_agora() -> void:
	if _encolher != null and is_instance_valid(_encolher) 			and _encolher.timeout.is_connected(_ao_encolher):
		_encolher.timeout.disconnect(_ao_encolher)
	_ao_encolher()


func _ao_encolher() -> void:
	if not _raiz.visible:
		return
	var alvo := _aplicar(false)
	# O papel encolhe animado ate a altura nova; o conteudo ja subiu. A dica sai
	# junto com a borda em vez de piscar antes dela.
	var t := create_tween()
	t.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_property(_papel, "size:y", alvo, UiEstilo.T_ENCOLHER)


func _ao_concluir(_missao: Dictionary) -> void:
	_dados = {"titulo": "", "etapa": "", "objetivo": "OBJETIVO CUMPRIDO",
		"dica": "", "distancia": ""}
	_papel.size.y = _aplicar(false)
	var cumprido: Label = _rotulos["objetivo"]
	cumprido.add_theme_color_override(&"font_color", UiEstilo.DESTAQUE)
	var t := create_tween()
	t.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	t.tween_interval(2.4)
	t.tween_property(_raiz, "modulate:a", 0.0, UiEstilo.T_SAIDA)
	t.tween_callback(func() -> void:
		_raiz.visible = false
		cumprido.add_theme_color_override(&"font_color", UiEstilo.TINTA)
		set_process(false))


## Dentro de casa o cartao sai da tela, como o minimapa. La ele nao teria o que
## dizer: a distancia ate um endereco de rua nao existe a dois mil metros de
## altura, dentro de um comodo sem coordenada.
func _ao_entrar_em_comodo() -> void:
	_raiz.visible = false


func _ao_sair_de_comodo() -> void:
	# Mesma regra do minimapa: durante Cinema o HUD inteiro fica fora.
	if Cinema.ativa:
		return
	_raiz.visible = not Missoes.atual.is_empty()


# --- distancia e rumo -------------------------------------------------------

func _process(_delta: float) -> void:
	if not _raiz.visible or Missoes.atual.is_empty():
		return
	var alvo := Missoes.posicao_do_alvo()
	if alvo == Vector3.INF:
		return
	if _jogador == null or not is_instance_valid(_jogador):
		_jogador = get_tree().get_first_node_in_group(&"player") as Node3D
		if _jogador == null:
			return
	var pos := _jogador.global_position
	var para := Vector2(alvo.x - pos.x, alvo.z - pos.z)
	var d := para.length()
	var texto := "%d M" % roundi(d) if d < 1000.0 else "%.1f KM" % (d / 1000.0)
	if texto != _ultima_distancia:
		# So reempilha quando o numero muda de verdade. Remontar o cartao a 60 Hz
		# para escrever o mesmo "270 M" e trabalho jogado fora, e a altura do
		# papel so muda quando a distancia aparece pela primeira vez.
		_ultima_distancia = texto
		_dados["distancia"] = texto
		var altura := _aplicar(_com_dica)
		if not is_equal_approx(_papel.size.y, altura):
			_papel.size.y = altura
	# Rumo RELATIVO ao olhar, e nao ao norte. Uma seta que aponta o norte obriga
	# o jogador a fazer a conta de cabeca; uma que aponta "atras de voce" nao.
	var frente := -_jogador.global_transform.basis.z
	_rumo_relativo = wrapf(atan2(para.x, para.y) - atan2(frente.x, frente.z),
		-PI, PI)
	_bussola.queue_redraw()


func _desenhar_bussola() -> void:
	var meio := Vector2(CartaoLayout.BUSSOLA, CartaoLayout.BUSSOLA) * 0.5
	var dir := Vector2(sin(_rumo_relativo), -cos(_rumo_relativo))
	var lado := Vector2(dir.y, -dir.x)
	var r := CartaoLayout.BUSSOLA * 0.5
	# Contorno escuro por baixo e miolo por cima, como a seta do mapa: tinta
	# sobre papel bege nao sobrevive ao grao sem borda.
	for passo: Array in [[r, UiEstilo.TINTA], [r - 1.2, UiEstilo.DESTAQUE]]:
		var e: float = passo[0]
		_bussola.draw_colored_polygon(PackedVector2Array([
			meio + dir * e,
			meio + lado * e * 0.72 - dir * e * 0.6,
			meio - dir * e * 0.28,
			meio - lado * e * 0.72 - dir * e * 0.6,
		]), passo[1])
