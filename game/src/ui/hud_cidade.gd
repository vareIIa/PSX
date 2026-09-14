## A faixa de estado da cidade: onde estou, que horas sao, lanterna e vida.
##
## O que ela nao e
## ---------------
## Nao e um segundo HUD. `HudEstrada` continua sendo o HUD da abertura, com o
## vocabulario da tarja preta e das linhas brancas que a cena dirigida pede.
## Esta aqui e a mesma informacao com o vocabulario do resto da interface do
## jogo a pe: papel, tinta, margem 7 — igual ao cartao de missao e ao minimapa.
##
## As duas leem a mesma coisa. O que impede as duas de discordarem nao e uma
## classe mae: e que nenhuma das duas GUARDA estado. `HudEstrada` recebe por
## `definir_*` de quem dirige a cena; esta aqui pergunta ao jogo a cada quadro
## lento. Nao ha copia para desencontrar.
##
## Por que na camada 100, e o que isso custou
## ------------------------------------------
## Porque `minimapa.gd:3` esta certo: interface nitida por cima de cena suja
## denuncia na hora. O preco de ficar embaixo do pos-processamento e a vinheta,
## que no canto da tela multiplica a cor por zero. `FaixaLayout` paga esse preco
## andando para o meio do rodape em vez de brigar por cor, e
## `tests/checar_hud.gd` reprova qualquer layout que volte para o canto.
##
## Por que a vida nao fica sempre na tela
## --------------------------------------
## Porque `cidade.gd:_montar_dano` decidiu, antes de mim, que o unico aviso de
## dano seria o clarao vermelho — e a decisao e boa: barra de vida cheia parada
## num canto o jogo inteiro e o oposto do que este jogo quer parecer. O que
## faltava nao era a barra: era o que vem DEPOIS do clarao. O clarao diz "voce
## levou"; nao diz "quanto sobrou", e o jogador ficava sem saber se estava perto
## de morrer.
##
## Entao a barra aparece quando muda, fica `T_LEITURA` segundos e some. Abaixo
## de `VIDA_GRAVE` ela nao some mais: a essa altura saber quanto falta deixou de
## ser informacao e virou a tensao.
class_name HudCidade
extends CanvasLayer

const FONTE := UiEstilo.FONTE_P

## Abaixo disso a barra fica na tela sem prazo.
const VIDA_GRAVE := 0.4

## De quanto em quanto tempo a faixa se refaz. A hora muda a cada 30 s reais e o
## distrito a cada quarteirao; refazer texto a 60 Hz seria medir a malha 60 vezes
## por segundo para escrever a mesma palavra.
const INTERVALO := 0.25

const COR_VIDA := Color("8a2f1f")
const COR_VIDA_VAZIA := Color(0.72, 0.68, 0.58, 0.55)
## O feixe e TINTA, nao ocre.
##
## Medido: ocre c9a227 no papel, depois da vinheta de 0,55 e da quantizacao PSX,
## sai em 0x42 contra um papel de 0x5a — dois niveis de separacao, invisivel. E
## nao e defeito de escolha de cor, e a regra do meio: em papel nao se desenha
## luz, se desenha tinta. O feixe aceso e uma marca escura; o apagado e a
## ausencia dela.
const COR_FEIXE := UiEstilo.TINTA

## O limiar em que `player.gd` comeca a fazer o facho tremer (BATERIA_FRACA vale
## 0,16). A faixa avisa um pouco antes: aviso que chega junto com o problema nao
## e aviso.
const FEIXE_ALERTA := 0.25

## Clarao de dano: cor, pico de opacidade e quanto tempo leva para sumir.
const COR_DANO := Color(0.62, 0.09, 0.06)
const DANO_PICO := 0.46
const DANO_SAIDA := 0.5

## Quanto do clarao e direcional. Em 0,0 ele e uma tela vermelha inteira, que
## diz "levou" e nao diz "de onde"; em 1,0 so o lado da pancada acende e uma
## pancada pelas costas nao apareceria. 0,62 acende a tela toda e acende o dobro
## do lado certo, que e o que o olho le sem procurar.
const DANO_DIRECAO := 0.62

## Quem seguir. Sem alvo a faixa mostra hora e nada mais — e o que acontece numa
## captura de menu, onde o jogador ainda nao existe.
var alvo: Node3D

var _raiz: Control
var _papel: TextureRect
var _sombra: ColorRect
var _tela: Control
var _fonte: Font
var _relogio: Relogio

var _lugar: String = ""
var _hora: String = ""
var _vida: float = 1.0
var _lanterna: bool = false
var _bateria: float = 1.0
var _mostrar_vida: float = 0.0
var _desde: float = 999.0
var _montado: Dictionary = {}
var _prompt: String = ""
var _prompt_montado: Dictionary = {}
var _prompt_papel: TextureRect
var _prompt_sombra: ColorRect
var _prompt_tinta: Control
var _prompt_tween: Tween
var _dano: TextureRect
var _dano_tween: Tween


func _ready() -> void:
	layer = UiEstilo.CAMADA_MAPA
	# Cena cortada esconde o grupo. A faixa e interface de jogo a pe: durante a
	# abertura quem manda e `HudEstrada`, e as duas na tela seriam duas.
	add_to_group(&"hud")
	if ResourceLoader.exists(FONTE):
		_fonte = load(FONTE)
	_relogio = _pegar_relogio()
	_montar()
	Inventario.vida_mudou.connect(_ao_mudar_vida)
	Inventario.feriu.connect(_ao_ferir)
	_vida = float(Inventario.vida) / float(maxi(1, Inventario.vida_maxima))
	set_process(true)


## O relogio mora no `WorldState` para atravessar troca de cena e entrar no
## save. Se alguem rodar esta faixa fora do jogo (captura de UI solta), ela cria
## o proprio e segue — interface nao pode depender de autoload para existir.
func _pegar_relogio() -> Relogio:
	var ws := get_node_or_null(^"/root/WorldState")
	if ws != null and ws.get(&"relogio") != null:
		return ws.get(&"relogio") as Relogio
	return Relogio.new()


func _process(delta: float) -> void:
	# `WorldState.limpar` troca a instancia. Guardar o ponteiro no `_ready`
	# deixava a faixa em 22:43 depois do desmaio adiantar o relogio.
	_relogio = _pegar_relogio()
	_relogio.avancar(delta)
	if _mostrar_vida > 0.0:
		_mostrar_vida -= delta
	if _prompt_tinta != null and _prompt_tinta.visible 			and _prompt_tween != null and _prompt_tween.is_valid():
		_prompt_tinta.queue_redraw()
	_desde += delta
	if _desde < INTERVALO:
		return
	_desde = 0.0
	_refazer()


func _ao_mudar_vida(atual: int, maximo: int) -> void:
	var antes := _vida
	_vida = float(atual) / float(maxi(1, maximo))
	# So dano chama a barra para a tela. `de_dicionario` emite `vida_mudou` ao
	# comecar a partida e ao carregar save; sem esta guarda o jogo abriria com
	# doze segundos de barra cheia, que e a unica coisa que a faixa nao devia
	# fazer — anunciar que nao ha nada para anunciar.
	if _vida < antes:
		_mostrar_vida = UiEstilo.T_LEITURA
	_desde = INTERVALO


## Hora de captura / de roteiro. Devolve false se o texto nao for "HH:MM".
func definir_hora(hhmm: String) -> bool:
	var ok := _relogio.definir_texto(hhmm)
	_desde = INTERVALO
	return ok


func hora() -> String:
	return _relogio.texto()


## O aviso de "[E] alguma coisa". String vazia esconde.
##
## Mora aqui, e nao num `Label` da cena de teste, porque a posicao dele depende
## da altura da faixa — e a faixa muda de altura com a fonte. Enquanto os dois
## viviam em arquivos diferentes, o prompt ocupava y 236..254 e a faixa 248..263,
## e ninguem soube porque ninguem tinha os dois numeros na mao ao mesmo tempo.
func definir_prompt(texto: String) -> void:
	if texto == _prompt:
		return
	_prompt = texto
	_prompt_montado = FaixaLayout.prompt(_fonte, texto) if _fonte != null else {}
	if _prompt_tween != null and _prompt_tween.is_valid():
		_prompt_tween.kill()
	if texto.is_empty():
		_prompt_papel.visible = false
		_prompt_sombra.visible = false
		_prompt_tinta.visible = false
		return
	var papel: Rect2 = _prompt_montado["papel"]
	_prompt_papel.position = papel.position
	_prompt_papel.size = papel.size
	_prompt_sombra.position = papel.position + Vector2(2.0, 2.0)
	_prompt_sombra.size = papel.size
	_prompt_papel.visible = true
	_prompt_sombra.visible = true
	_prompt_tinta.visible = true
	_prompt_tinta.queue_redraw()
	# Entra subindo dois pixels, como o Label antigo fazia. Aparecer de uma vez
	# puxa o olho com forca demais para o que e so um aviso de que da para
	# apertar E.
	for no: CanvasItem in [_prompt_papel, _prompt_sombra, _prompt_tinta]:
		no.modulate.a = 0.0
	_prompt_papel.position.y += 2.0
	_prompt_sombra.position.y += 2.0
	_prompt_tween = create_tween().set_parallel(true)
	_prompt_tween.set_ease(Tween.EASE_OUT)
	for no: CanvasItem in [_prompt_papel, _prompt_sombra, _prompt_tinta]:
		_prompt_tween.tween_property(no, "modulate:a", 1.0, 0.12)
	_prompt_tween.tween_property(_prompt_papel, "position:y", papel.position.y, 0.12)
	_prompt_tween.tween_property(_prompt_sombra, "position:y",
		papel.position.y + 2.0, 0.12)


func _montar() -> void:
	_raiz = Control.new()
	_raiz.name = "Faixa"
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)

	_sombra = ColorRect.new()
	_sombra.color = UiEstilo.PAPEL_SOMBRA
	_sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_sombra)

	_papel = TextureRect.new()
	_papel.name = "Papel"
	var caminho := "res://assets/ui/ui_papel.png"
	if ResourceLoader.exists(caminho):
		_papel.texture = load(caminho)
	_papel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_papel.stretch_mode = TextureRect.STRETCH_SCALE
	_papel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_papel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_papel.modulate = UiEstilo.PAPEL_LUZ
	_raiz.add_child(_papel)

	# Tudo o que e desenho (borda, icone, barra, regua, texto) sai de um Control
	# so: um `draw_string` por caixa e mais barato que cinco Labels que o
	# TextServer reposiciona a cada refazer, e e o mesmo caminho que
	# `menu_sistema.gd` ja usa.
	_tela = Control.new()
	_tela.name = "Tinta"
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.draw.connect(_desenhar)
	_raiz.add_child(_tela)
	_tela.set_anchors_preset(Control.PRESET_FULL_RECT)
	# CanvasItem desenha uma vez e congela. Nascer dentro de no invisivel ja
	# custou tres capturas neste projeto; aqui o redesenho volta junto com a
	# visibilidade.
	visibility_changed.connect(_tela.queue_redraw)

	_montar_prompt()
	_montar_dano()
	_refazer()


## O clarao de dano, com um lado mais forte que o outro.
##
## Por que ele mora na faixa e nao no nivel
## ----------------------------------------
## Porque e a segunda metade da mesma frase. O clarao diz "voce levou"; a barra
## diz "sobrou tanto"; a direcao diz "de la". Escrever as tres em dois arquivos
## e como estava antes: o nivel piscava vermelho e a tela nao dizia mais nada.
##
## A fonte de dano e `Inimigo._golpear`, que passa a propria posicao. O contrato
## daqui e so o clarao: quem bate nao desenha, quem desenha nao bate.
func _montar_dano() -> void:
	_dano = TextureRect.new()
	_dano.name = "Dano"
	_dano.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dano.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_dano.stretch_mode = TextureRect.STRETCH_SCALE
	# Gradiente de um lado ao outro. O no inteiro gira para o lado da pancada,
	# entao um unico eixo cobre as quatro direcoes.
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	g.set_color(1, Color(1.0, 1.0, 1.0, 1.0 - DANO_DIRECAO))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 64
	tex.height = 4
	tex.fill_from = Vector2(0.0, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	_dano.texture = tex
	_dano.modulate = Color(COR_DANO, 0.0)
	# Diagonal da tela como lado: girado em qualquer angulo, ainda cobre tudo.
	var lado := UiEstilo.TELA.length()
	_raiz.add_child(_dano)
	_dano.size = Vector2(lado, lado)
	_dano.pivot_offset = Vector2(lado, lado) * 0.5
	_dano.position = (UiEstilo.TELA - Vector2(lado, lado)) * 0.5
	# Atras do papel: o clarao e o mundo piscando, nao a interface piscando.
	_raiz.move_child(_dano, 0)


func _ao_ferir(_pontos: int, origem: Vector3) -> void:
	piscar_dano(origem)


## O clarao sozinho, sem tirar vida. Serve ao susto roteirizado (a coisa que
## passa raspando) e a captura, que precisa do clarao parado num quadro.
func piscar_dano(origem: Vector3 = Vector3.INF) -> void:
	if _dano == null:
		return
	# Onde a pancada esta na tela. A conta e feita no espaco DO JOGADOR, e nao
	# em angulo de mundo menos rumo: assim "veio da direita" continua sendo a
	# direita depois de ele se virar, e nao ha uma subtracao de yaw para errar de
	# sinal — que foi exatamente o que a primeira versao errou, e a captura
	# mostrou o clarao no lado oposto ao golpe.
	var giro := 0.0
	if alvo != null and origem.is_finite():
		var local := alvo.global_transform.basis.inverse() * (origem - alvo.global_position)
		var plano := Vector2(local.x, local.z)
		if plano.length() > 0.05:
			plano = plano.normalized()
			# Em rotacao zero o lado claro do gradiente aponta para (-1, 0), a
			# esquerda da tela. Girar por atan2(-z, -x) leva esse lado ate a
			# direcao do golpe; +z (atras do jogador) cai embaixo, que e onde o
			# olho procura quando algo bate pelas costas.
			giro = atan2(-plano.y, -plano.x)
	_dano.rotation = giro
	_dano.modulate.a = DANO_PICO
	# Uma pancada logo depois da outra e o caso comum, nao a excecao. Sem matar
	# o tween anterior, o antigo continua correndo em paralelo a partir do valor
	# que ELE guardou e apaga o clarao novo no quadro seguinte.
	if _dano_tween != null and _dano_tween.is_valid():
		_dano_tween.kill()
	_dano_tween = create_tween().set_ease(Tween.EASE_OUT)
	_dano_tween.tween_property(_dano, "modulate:a", 0.0, DANO_SAIDA)


func _montar_prompt() -> void:
	_prompt_sombra = ColorRect.new()
	_prompt_sombra.color = UiEstilo.PAPEL_SOMBRA
	_prompt_sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_sombra.visible = false
	_raiz.add_child(_prompt_sombra)

	_prompt_papel = TextureRect.new()
	_prompt_papel.name = "PromptPapel"
	var caminho := "res://assets/ui/ui_papel.png"
	if ResourceLoader.exists(caminho):
		_prompt_papel.texture = load(caminho)
	_prompt_papel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_prompt_papel.stretch_mode = TextureRect.STRETCH_SCALE
	_prompt_papel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_prompt_papel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_papel.modulate = UiEstilo.PAPEL_LUZ
	_prompt_papel.visible = false
	_raiz.add_child(_prompt_papel)

	_prompt_tinta = Control.new()
	_prompt_tinta.name = "PromptTinta"
	_prompt_tinta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_tinta.draw.connect(_desenhar_prompt)
	_prompt_tinta.visible = false
	_raiz.add_child(_prompt_tinta)
	_prompt_tinta.set_anchors_preset(Control.PRESET_FULL_RECT)


func _desenhar_prompt() -> void:
	if _prompt_montado.is_empty() or _fonte == null or _prompt.is_empty():
		return
	var papel: Rect2 = _prompt_montado["papel"]
	# Segue o papel enquanto o tween o levanta: desenhar na posicao final faria
	# a tinta descolar do papel durante os 0,12 s de entrada.
	var desvio := _prompt_papel.position - papel.position
	_prompt_tinta.draw_rect(Rect2(papel.position + desvio, papel.size),
		UiEstilo.TINTA, false, UiEstilo.PAPEL_BORDA)
	var tam := UiEstilo.tamanho_nativo(_fonte)
	var r: Rect2 = _prompt_montado["texto"]
	var base := r.position + desvio 		+ Vector2(0.0, UiEstilo.altura_da_linha(_fonte) - _fonte.get_descent(tam))
	_prompt_tinta.draw_string(_fonte, base, String(_prompt_montado["cortado"]),
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, tam, UiEstilo.TINTA)


func _refazer() -> void:
	if _fonte == null:
		return
	_lugar = _onde_estou()
	_hora = _relogio.texto()
	if alvo != null:
		_lanterna = bool(alvo.get(&"lanterna_ligada"))
		_bateria = float(alvo.get(&"bateria"))

	var com_vida := _mostrar_vida > 0.0 or _vida <= VIDA_GRAVE
	_montado = FaixaLayout.montar(_fonte, {
		"lugar": _lugar,
		"hora": _hora,
		"vida": _vida,
		"com_vida": com_vida,
		# Sem lanterna na mochila o icone nao existe: espaco de faixa gasto com
		# informacao que nao se aplica e espaco que o nome do lugar perde.
		"com_lanterna": alvo != null and Inventario.tem(&"lanterna"),
		"lanterna": _lanterna,
	})

	var papel: Rect2 = _montado["papel"]
	_papel.position = papel.position
	_papel.size = papel.size
	_sombra.position = papel.position + Vector2(2.0, 2.0)
	_sombra.size = papel.size
	_tela.queue_redraw()


## Nome do lugar sob o jogador. Mesma conta de `Mapa.onde_estou`, sem precisar de
## um `Mapa`: a malha e funcao pura da coordenada, entao a faixa pergunta direto.
func _onde_estou() -> String:
	var interiores := get_node_or_null(^"/root/Interiores")
	if interiores != null and bool(interiores.get(&"dentro")):
		return String(interiores.call(&"tipo_atual")).replace("_", " ").to_upper()
	if alvo == null:
		return ""
	var p := alvo.global_position
	var q := MalhaUrbana.quadra_de(floori(p.x / MalhaUrbana.TAM),
		floori(p.z / MalhaUrbana.TAM))
	if int(q["uso"]) == MalhaUrbana.Uso.PARQUE:
		return String(ParqueBuilder.planta(q)["nome"]).to_upper()
	return MalhaUrbana.nome_do_distrito(q["distrito"]).to_upper()


func _desenhar() -> void:
	if _montado.is_empty() or _fonte == null:
		return
	var papel: Rect2 = _montado["papel"]
	_tela.draw_rect(papel, UiEstilo.TINTA, false, UiEstilo.PAPEL_BORDA)

	var tam := UiEstilo.tamanho_nativo(_fonte)
	var linha := UiEstilo.altura_da_linha(_fonte)
	var caixas: Array = _montado["caixas"]
	for c: Dictionary in caixas:
		var r: Rect2 = c["rect"]
		match String(c["nome"]):
			"regua":
				_tela.draw_rect(r, UiEstilo.TINTA_FRACA, true)
			"lanterna":
				_desenhar_lanterna(r)
			"vida":
				_desenhar_vida(r)
			_:
				var texto := String(c["texto"])
				if texto.is_empty():
					continue
				var cor := UiEstilo.TINTA
				# `draw_string` ancora na base da linha, nao no topo da caixa.
				var base := r.position + Vector2(0.0, linha - _fonte.get_descent(tam))
				_tela.draw_string(_fonte, base, texto, HORIZONTAL_ALIGNMENT_LEFT,
					-1.0, tam, cor)


## Lanterna em blocos de 1 px, e a bateria dentro do proprio feixe.
##
## Por que a bateria nao ganhou barra propria
## ------------------------------------------
## Porque a faixa tem 15 px de altura, e cada widget novo empurra o canto para
## onde a vinheta come. E porque o feixe JA e a bateria: o jogo apaga a lanterna
## quando ela zera e faz o facho tremer quando esta acabando. Um feixe que
## encurta diz a mesma coisa sem inventar vocabulario novo, e diz com a mesma
## imagem que o jogador ve no chao.
##
## Tres degraus bastam: `Player.BATERIA_SEGUNDOS` e curta de proposito, entao o
## que o jogador precisa saber e "cheia / pela metade / acabando", nao a
## porcentagem. Abaixo de `FEIXE_ALERTA` o feixe fica vermelho — o aviso que
## faltava para a lanterna nunca mais morrer de surpresa.
func _desenhar_lanterna(r: Rect2) -> void:
	var o := r.position
	# Cabo (colunas 0..3, linhas 3..5) e cabeca (coluna 4, linhas 2..6).
	for y in range(3, 6):
		for x in range(0, 4):
			_tela.draw_rect(Rect2(o + Vector2(x, y), Vector2.ONE), UiEstilo.TINTA, true)
	for y in range(2, 7):
		_tela.draw_rect(Rect2(o + Vector2(4, y), Vector2.ONE), UiEstilo.TINTA, true)

	if not _lanterna or _bateria <= 0.0:
		return
	var cor := UiEstilo.DESTAQUE if _bateria < FEIXE_ALERTA else COR_FEIXE
	# Cunha: quanto mais bateria, mais colunas o feixe alcanca.
	var colunas := clampi(int(ceil(_bateria * 3.0)), 1, 3)
	for i in colunas:
		var col := 5 + i
		var alcance := 1 + i
		for y in range(4 - alcance, 4 + alcance + 1):
			_tela.draw_rect(Rect2(o + Vector2(col, y), Vector2.ONE), cor, true)


func _desenhar_vida(r: Rect2) -> void:
	_tela.draw_rect(r, COR_VIDA_VAZIA, true)
	var cheia := Rect2(r.position, Vector2(roundf(r.size.x * clampf(_vida, 0.0, 1.0)),
		r.size.y))
	if cheia.size.x >= 1.0:
		_tela.draw_rect(cheia, COR_VIDA, true)
	_tela.draw_rect(r, UiEstilo.TINTA, false, 1.0)
