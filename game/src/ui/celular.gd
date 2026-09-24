## Autoload. O iPhone no bolso do jogador: o sistema dele (tela de bloqueio,
## tela de inicio, App Store, apps) e o gesto de tirar, usar e guardar.
##
## O que mudou do aparelho de 1998
## -------------------------------
## Ate aqui o celular era uma moldura desenhada por cima da imagem, um tijolo de
## LCD verde. Agora ele e o iPhone modelado da abertura, NA MAO do personagem
## (`CelularNaMao`): o jogador aperta a tecla, o personagem baixa os olhos, tira
## o aparelho do bolso e o ergue ate o rosto, e o sistema acende no vidro. Nada
## fica por cima da imagem alem da dica de teclas.
##
## A tela e desenhada num `SubViewport` do tamanho que a janela pede (`_escala`)
## e vai para o vidro como textura. A grade logica e a do vidro do iPhone 4, 2:3:
## 146 x 219 unidades. Tudo que desenha aqui (este arquivo, o `SoInicio`, os
## apps) fala em unidades.
##
## Como se mexe nele
## -----------------
## Tres jeitos, os tres de uma vez:
##   - mouse: o cursor e o dedo. Tocar, segurar (o toque longo do iOS), arrastar
##     (paginas, listas, a trava), a roda rola, o botao direito volta;
##   - teclado: setas/WASD andam, E usa, ESC volta (o botao de inicio), Q edita
##     a tela de inicio, C guarda;
##   - controle: direcional/analogico andam, A usa, B volta, Y edita, LB guarda.
## O foco (a moldura em volta do que as setas escolheram) so aparece quando o
## ultimo comando veio de tecla ou controle.
##
## Onde mora o estado
## ------------------
## O que esta instalado, o que foi comprado, o fundo de tela e o que cada app
## guarda moram no `WorldState`, na faixa do jogador (`COORD`): vao no save e
## nunca saem da maquina em rede, como a carteira e o iWeed.
extends CanvasLayer

const L := AppCelular.L
## A altura da tela do iPhone na grade do app: a largura do aparelho de 1998 e a
## proporcao 2:3 do vidro (`IphoneDeJogo.TELA`).
const ALTO := AppCelular.L * 1.5
const COORD := Vector2i(-11, 424243)

## Tempo com o aparelho guardado que o faz bloquear de novo (s).
const BLOQUEIA_DEPOIS := 25.0
## O toque longo (s) e o arrasto minimo (unidades) que deixa de ser toque.
const SEGURAR := 0.5
const ARRASTO := 3.0
## A abertura de um app: o zoom do icone ate a tela cheia (s).
const ZOOM := 0.3
## A bateria, acelerada para o jogo (a escolha do jogador): a tela acesa zera
## em uns 45 min reais, em espera em umas 5 h; o Mapas (GPS e tela cheia) e a
## lanterna gastam alem da tela. Fracao por segundo.
const GASTO_ESPERA := 1.0 / 18000.0
const GASTO_TELA := 1.0 / 2700.0
const GASTO_MAPAS := 1.0 / 3000.0
const GASTO_FLASH := 1.0 / 1500.0
## Carregando (tomada ou carro): de 0 a 80% em uns 5 min, e dali devagar, como
## a de litio.
const CARGA := 1.0 / 380.0
const CARGA_LENTA_DESDE := 0.8
const CARGA_LENTA := 0.35
## Os dois avisos de bateria fraca do iOS.
const AVISOS_DE_BATERIA: Array[float] = [0.2, 0.1]
## Morto e plugado, ele liga sozinho quando a carga passa disto; a maca fica na
## tela este tempo (s). Desligando, o spinner fica este.
const LIGA_COM := 0.02
const LIGANDO_S := 4.5
const DESLIGANDO_S := 1.6

## Quanto dura o aparelho girar na mao, de pe para deitado e de volta (s).
const GIRO := 0.5

signal abriu()
signal fechou()
signal instalou(id: StringName)
signal apagou(id: StringName)
## O app na tela mudou (abriu, trocou, voltou para o inicio).
signal app_trocou()

var ativo: bool = false
## Bateria, de 0 a 1.
var bateria: float = 0.87
var fundo_de_tela: int:
	get:
		return int(WorldState.obter(COORD, &"fundo", 0))
	set(v):
		WorldState.definir(COORD, &"fundo", v)

enum Modo { BLOQUEIO, INICIO, APP }
enum Energia { LIGADO, DESLIGANDO, DESLIGADO, LIGANDO }

var _energia: Energia = Energia.LIGADO
var _energia_t: float = 0.0
## A pilha vazia na tela preta (s): o que o aparelho morto mostra quando se
## aperta alguma coisa.
var _vazio_t: float = 0.0
## O ultimo aviso de bateria fraca dado (volta a 1 quando carrega).
var _avisou: float = 1.0
## Quem esta dando carga agora (a tomada, o carro): o aparelho carrega com
## qualquer um.
var _fontes_de_carga: Dictionary = {}

var _modo: Modo = Modo.INICIO
var _vp: SubViewport
var _raiz: Control
var _c_inicio: Control
var _c_app: Control
var _c_topo: Control
## O app e a barra de status moram aqui dentro: quando o aparelho deita na mao,
## este no gira o desenho ao contrario, e o que esta na tela fica de pe para
## quem olha.
var _giro: Control
## 0 em pe, 1 deitado (animado); `_deitado` e o desenho ja na medida deitada.
var _giro_k: float = 0.0
var _deitado: bool = false
## Saindo de um app deitado: primeiro o aparelho volta a ficar em pe, depois o
## app fecha. O que fazer quando ele terminar de endireitar.
var _ao_endireitar := Callable()
var _dica: Control
var _plano: TextureRect
var _escala: float = 4.0

var _inicio := SoInicio.new()
var _bloqueio := SoBloqueio.new()
var _apps: Dictionary = {}
var _app: AppCelular
var _app_id: StringName = &""
var _rig: CelularNaMao
var _fontes: Array[Font] = []

## Downloads: id -> {"t": segundos passados, "dur": duracao}.
var _baixando: Dictionary = {}
var _desde_fechou: float = 999.0
## A transicao de abrir/fechar app: 0 a 1, e para onde vai.
var _zoom: float = 1.0
var _zoom_abrindo: bool = true
var _zoom_de := Rect2()
## O alerta do sistema por cima de tudo: {titulo, texto, botoes, sel, ao}.
var _alerta: Dictionary = {}
var _alerta_k: float = 0.0

## O dedo: apertado, onde apertou, ha quanto tempo, se virou arrasto ou toque
## longo, e onde estava no ultimo quadro.
var _dedo_baixo: bool = false
var _dedo_de := Vector2.ZERO
var _dedo_t: float = 0.0
var _dedo_arrastou: bool = false
var _dedo_segurou: bool = false
var _dedo_ultimo := Vector2.ZERO
var _ponteiro := Vector2(-1.0, -1.0)
var _foco_visivel: bool = true
var _mouse_antes: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _mexeu_no_mouse: bool = false

## Aberto pela conversa (opcao TRABALHO): quem trava e destrava o jogador e a
## conversa, e fechar o aparelho devolve a lista de assuntos.
var _da_conversa := false
## Aberto por uma cena cortada: o personagem esta com o telefone, e nao o
## jogador. Nada trava nem destrava ninguem, e o aparelho ignora tecla.
var _de_cena := false

var _trampo := AppTrampo.new()
var _iweed := AppIWeed.new()
var _mensagens_cena := AppMensagens.new()


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fontes = _fontes_nitidas()
	_montar()
	_preparar(_inicio)
	_preparar(_bloqueio)
	_inicio.pediu_abrir.connect(_lancar)
	_inicio.pediu_apagar.connect(pedir_apagar)
	_bloqueio.destravou.connect(_ao_destravar)
	_apps[&"trampo"] = _preparar(_trampo)
	_apps[&"iweed"] = _preparar(_iweed)
	_preparar(_mensagens_cena)
	_mensagens_cena.altura_tela = ALTO


## Letra vetorial (MSDF): a tela e desenhada em unidades e escalada ate o
## tamanho que a janela pede, e a letra rasterizada no tamanho da unidade saia
## borrada no vidro em 4K.
static func _fontes_nitidas() -> Array[Font]:
	var saida: Array[Font] = []
	for peso: int in [400, 600, 700]:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(["Helvetica Neue", "Segoe UI", "Inter", "Arial"])
		sf.font_weight = peso
		sf.multichannel_signed_distance_field = true
		sf.msdf_pixel_range = 12
		sf.msdf_size = 56
		sf.generate_mipmaps = true
		saida.append(sf)
	return saida


func _preparar(app: AppCelular) -> AppCelular:
	app.f_reg = _fontes[0]
	app.f_semi = _fontes[1]
	app.f_bold = _fontes[2]
	app.alto_tela = ALTO
	_medir_app(app)
	return app


# --- montagem -----------------------------------------------------------------

func _montar() -> void:
	_vp = SubViewport.new()
	_vp.name = "Tela"
	_vp.transparent_bg = false
	_vp.disable_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	_raiz = Control.new()
	_raiz.name = "Raiz"
	_raiz.size = Vector2(L, ALTO)
	_vp.add_child(_raiz)
	# Preto por baixo de tudo: no meio do giro, os cantos do vidro que o desenho
	# deitado nao cobre ficam apagados, como no aparelho.
	var preto := ColorRect.new()
	preto.color = Color.BLACK
	preto.size = Vector2(L, ALTO)
	preto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(preto)
	_c_inicio = _camada("Inicio", _desenhar_inicio)
	_giro = Control.new()
	_giro.name = "Giro"
	_giro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_giro.position = Vector2(L, ALTO) * 0.5
	_raiz.add_child(_giro)
	_c_app = _camada("App", _desenhar_app, _giro)
	_c_topo = _camada("Topo", _desenhar_topo, _giro)
	_medir_camadas()
	_aplicar_escala()

	# A dica de teclas, na tela do jogo, ao lado do aparelho.
	_dica = Control.new()
	_dica.name = "Dica"
	_dica.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dica)
	_dica.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dica.draw.connect(_desenhar_dica)
	_dica.visible = false

	# Sem jogador (o menu, uma bancada), o aparelho aparece chapado na tela.
	_plano = TextureRect.new()
	_plano.name = "SemMao"
	_plano.texture = _vp.get_texture()
	_plano.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_plano.stretch_mode = TextureRect.STRETCH_SCALE
	_plano.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plano)
	_plano.size = Vector2(110.0, 165.0)
	_plano.position = Vector2(480.0 - 110.0 - 30.0, 270.0 - 165.0 - 40.0)
	_plano.draw.connect(func() -> void:
		_plano.draw_rect(Rect2(Vector2(-3, -3), _plano.size + Vector2(6, 6)), Color("0c0d0f"), false, 3.0))
	_plano.visible = false


func _camada(nome: String, desenho: Callable, pai: Control = null) -> Control:
	var c := Control.new()
	c.name = nome
	c.size = Vector2(L, ALTO)
	c.clip_contents = true
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(pai if pai != null else _raiz).add_child(c)
	c.draw.connect(desenho)
	return c


## O app e a barra na medida de agora (em pe 146 x 219, deitado 219 x 146),
## centrados no no que gira.
func _medir_camadas() -> void:
	var tam := Vector2(ALTO, L) if _deitado else Vector2(L, ALTO)
	for c: Control in [_c_app, _c_topo]:
		c.size = tam
		c.position = -tam * 0.5
	for a: AppCelular in _apps.values():
		_medir_app(a)


func _medir_app(a: AppCelular) -> void:
	if a == null:
		return
	a.alto_tela = L if _deitado else ALTO
	if &"largura" in a:
		a.set(&"largura", ALTO if _deitado else L)


## Pixels da textura por unidade. Em 4K a tela ocupa perto de mil pixels de
## altura no quadro, e a textura acompanha: menos que isso e o vidro borra.
func _aplicar_escala() -> void:
	var alto_janela := 720.0
	if get_tree() != null and get_tree().root != null:
		alto_janela = float(get_tree().root.size.y)
	_escala = clampf(ceilf(alto_janela * 0.55 / ALTO), 3.0, 7.0)
	_vp.size = Vector2i(int(L * _escala), int(ALTO * _escala))
	_raiz.scale = Vector2(_escala, _escala)


# --- abrir e fechar -----------------------------------------------------------

func abrir() -> void:
	if ativo:
		return
	if longe:
		# Deitado carregando na tomada: nao ha o que tirar do bolso.
		_avisar_hud("iPhone", "Esta carregando na tomada")
		return
	ativo = true
	_aplicar_escala()
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	set_process(true)
	_alerta = {}
	if _de_cena or _da_conversa or _desde_fechou < BLOQUEIA_DEPOIS:
		_modo = Modo.INICIO if _app == null else Modo.APP
	else:
		_modo = Modo.BLOQUEIO
		_bloqueio.abrir()
		_app = null
		_app_id = &""
	if _modo == Modo.INICIO:
		_inicio.chegada = 1.0
	if not _da_conversa and not _de_cena:
		_travar_jogador(true)
	if _energia == Energia.DESLIGADO:
		_vazio_t = 2.2
	_erguer()
	AudioDirector.tocar_ui(&"celular_abre", -8.0)
	abriu.emit()


func fechar() -> void:
	if not ativo:
		return
	ativo = false
	_desde_fechou = 0.0
	if not _da_conversa and not _de_cena:
		_travar_jogador(false)
	_da_conversa = false
	_de_cena = false
	_alerta = {}
	_dedo_baixo = false
	_guardar()
	AudioDirector.tocar_ui(&"clique", -14.0)
	fechou.emit()


## Fecha sem som e sem o gesto. Para a cena cortada.
func fechar_em_silencio() -> void:
	if not ativo:
		return
	ativo = false
	_da_conversa = false
	_de_cena = false
	_app = null
	_app_id = &""
	if _rig != null and is_instance_valid(_rig):
		_rig.guardar()
	_plano.visible = false
	_dica.visible = false
	_devolver_mouse()
	fechou.emit()


## Abre direto no perfil de trabalho de alguem, no Trampo. E o que a opcao
## TRABALHO da conversa chama. Sem o Trampo instalado, abre a pagina dele na
## loja: e o que o aparelho de verdade faria.
func abrir_perfil(ficha: Dictionary) -> void:
	if ativo or ficha.is_empty():
		return
	_da_conversa = Conversa.ativo
	abrir()
	if not instalado(&"trampo"):
		_lancar_sem_zoom(&"loja")
		(_app as AppLoja).call("_abrir_detalhe", &"trampo")
		return
	_lancar_sem_zoom(&"trampo")
	_trampo.mostrar_perfil(ficha, &"fechar" if _da_conversa else &"rede")


## Abre o aparelho numa conversa de Mensagens, para cena cortada.
func abrir_conversa_em_cena(contato: String, mensagens: Array, hora: String,
		rascunho: String) -> AppMensagens:
	if ativo:
		fechar_em_silencio()
	_de_cena = true
	abrir()
	_mensagens_cena.preparar(contato, mensagens, hora, rascunho)
	_mensagens_cena.abrir()
	_app = _mensagens_cena
	_app_id = &"mensagens"
	_modo = Modo.APP
	_zoom = 1.0
	return _mensagens_cena


## Publica: testes e capturas abrem um app sem navegar a grade.
func abrir_app(id: StringName) -> void:
	if not ativo:
		_desde_fechou = 0.0
		abrir()
	_lancar_sem_zoom(id)


## O atalho do mapa (`M`, e o `Gps.abrir` das cenas): tira o aparelho ja no
## Mapas, sem a trava — o polegar desliza a trava no caminho do bolso —, e ele
## ja sobe girando para deitar nas duas maos.
func abrir_mapas() -> void:
	if not ativo:
		_desde_fechou = 0.0
		abrir()
	if app_atual() != &"mapas":
		_lancar_sem_zoom(&"mapas")


## A busca do Mapas mudou por fora (`Gps.filtrar_por`): os alfinetes caem.
func mapas_mudou_busca() -> void:
	var m := _apps.get(&"mapas") as AppMapas
	if m != null:
		m.mudou_busca()


func app_atual() -> StringName:
	if _modo != Modo.APP or _app == null:
		return &""
	if _app == _mensagens_cena:
		return &"mensagens"
	return _app_id


func trampo() -> AppTrampo:
	return _trampo


func iweed() -> AppIWeed:
	return _iweed


## Publica: a verificacao automatizada abre uma ficha sem digitar.
func consultar_cpf(cpf: String) -> bool:
	if RegistroCivil.id_de_cpf(cpf) < 0:
		return false
	if not ativo:
		_desde_fechou = 0.0
		abrir()
	_lancar_sem_zoom(&"portal")
	return (_app as AppPortal).consultar(cpf)


func _travar_jogador(preso: bool) -> void:
	var jogador := get_tree().get_first_node_in_group(&"player")
	if jogador != null and jogador.has_method("travar"):
		jogador.call("travar", preso)


func _jogador() -> Node:
	return get_tree().get_first_node_in_group(&"player")


## Tira do bolso: na mao, quando ha jogador com camera; chapado na tela, quando
## nao ha.
func _erguer() -> void:
	var jogador := _jogador()
	if (_rig == null or not is_instance_valid(_rig)) and jogador != null:
		_rig = CelularNaMao.new()
		if not _rig.montar(jogador):
			_rig.free()
			_rig = null
		else:
			_rig.guardado.connect(_ao_guardar)
	if _rig != null:
		_rig.ligar_tela(_vp.get_texture())
		_rig.erguer()
		_plano.visible = false
	else:
		_plano.visible = true
	_dica.visible = not _de_cena
	# O cursor so e solto quando o jogo o tinha preso (o olhar): numa bancada ou
	# captura ele ja esta livre, e prender a janela ali sequestra o mouse de quem
	# esta usando a maquina.
	_mouse_antes = Input.mouse_mode
	_mexeu_no_mouse = not _de_cena and _mouse_antes == Input.MOUSE_MODE_CAPTURED
	if _mexeu_no_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED


func _guardar() -> void:
	if _rig != null and is_instance_valid(_rig):
		_rig.guardar()
	_plano.visible = false
	_dica.visible = false
	_devolver_mouse()


func _ao_guardar() -> void:
	if not ativo:
		_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _devolver_mouse() -> void:
	if _mexeu_no_mouse:
		Input.mouse_mode = _mouse_antes
	_mexeu_no_mouse = false


# --- apps: o que esta instalado ----------------------------------------------

## Os apps da tela de inicio fora do dock, na ordem do jogador. Os baixando
## entram: eles aparecem cinza, com a barra.
func apps_da_tela() -> Array[StringName]:
	var saida: Array[StringName] = []
	for id: StringName in _instalados():
		if not CatalogoDeApps.DOCK.has(id):
			saida.append(id)
	return saida


func _instalados() -> Array[StringName]:
	var bruto: Variant = WorldState.obter(COORD, &"instalados", null)
	var saida: Array[StringName] = []
	if bruto is Array:
		for s: Variant in bruto:
			if CatalogoDeApps.existe(StringName(s)):
				saida.append(StringName(s))
	else:
		saida = CatalogoDeApps.INICIAIS.duplicate()
	# O sistema esta sempre: um save de antes da loja nao tinha a lista.
	for id: StringName in CatalogoDeApps.APPS:
		if CatalogoDeApps.do_sistema(id) and not saida.has(id) and not CatalogoDeApps.DOCK.has(id):
			saida.append(id)
	for id: StringName in CatalogoDeApps.DOCK:
		if not saida.has(id):
			saida.append(id)
	return saida


func _gravar_instalados(lista: Array[StringName]) -> void:
	var s: Array = []
	for id: StringName in lista:
		s.append(String(id))
	WorldState.definir(COORD, &"instalados", s)


func instalado(id: StringName) -> bool:
	return _instalados().has(id) and not _baixando.has(id)


## Os apps que ja passaram pelo aparelho (os que vieram nele e os baixados).
func comprados() -> Array[StringName]:
	var saida: Array[StringName] = []
	var bruto: Variant = WorldState.obter(COORD, &"comprados", [])
	for s: Variant in (bruto as Array if bruto is Array else []):
		saida.append(StringName(s))
	for id: StringName in CatalogoDeApps.INICIAIS:
		if not CatalogoDeApps.do_sistema(id) and not saida.has(id):
			saida.append(id)
	return saida


## 0 a 1 enquanto baixa; -1 quando nao esta baixando.
func progresso_de(id: StringName) -> float:
	if not _baixando.has(id):
		return -1.0
	var b: Dictionary = _baixando[id]
	return clampf(float(b["t"]) / float(b["dur"]), 0.0, 1.0)


func espaco_usado() -> float:
	var mb := CatalogoDeApps.SISTEMA_MB + CatalogoDeApps.FOTOS_MB + CatalogoDeApps.MUSICAS_MB
	for id: StringName in _instalados():
		mb += CatalogoDeApps.tamanho(id)
	return mb


func espaco_livre() -> float:
	return CatalogoDeApps.CAPACIDADE_MB - espaco_usado()


## Numero vermelho no icone.
func emblema(id: StringName) -> int:
	if id == &"iweed" and instalado(id):
		return IWeed.abertos().size()
	return 0


## O que aparece na tela de bloqueio.
func avisos_da_trava() -> Array:
	var saida: Array = []
	var novos := emblema(&"iweed")
	if novos > 0:
		saida.append({"app": &"iweed", "titulo": "iWeed",
			"texto": "%d pedido%s esperando resposta" % [novos, "" if novos == 1 else "s"],
			"hora": "agora"})
	if bateria < 0.2:
		saida.append({"app": &"ajustes", "titulo": "Bateria Fraca",
			"texto": "%d%% de bateria restante" % roundi(bateria * 100.0), "hora": ""})
	return saida


## Comeca a baixar `id`: confere dinheiro e espaco, cobra, poe o icone na tela
## de inicio e volta para ela, como o iOS 4 faz.
func instalar(id: StringName) -> bool:
	if not CatalogoDeApps.existe(id) or instalado(id) or _baixando.has(id):
		return false
	var mb := CatalogoDeApps.tamanho(id)
	if mb > espaco_livre():
		alerta("Nao ha Espaco Suficiente",
			"Faltam %s para instalar \"%s\". Apague apps em Ajustes ou na tela de inicio." % [
			CatalogoDeApps.formatar_mb(mb - espaco_livre()), CatalogoDeApps.nome(id)],
			["OK", "Ajustes"], func(i: int) -> void:
				if i == 1:
					_trocar_para(&"ajustes")
					(_app as AppAjustes).mostrar_uso())
		AudioDirector.tocar_ui(&"celular_erro", -10.0)
		return false
	var preco := CatalogoDeApps.preco(id)
	if preco > 0 and not comprados().has(id):
		if not Dinheiro.pagar(preco, "App Store: %s" % CatalogoDeApps.nome(id)):
			alerta("Saldo Insuficiente", "\"%s\" custa %s. Seu saldo e %s." % [
				CatalogoDeApps.nome(id), Dinheiro.formatar(preco), Dinheiro.formatar(Dinheiro.saldo())],
				["OK"], Callable())
			AudioDirector.tocar_ui(&"celular_erro", -10.0)
			return false
	var lista := _instalados()
	lista.append(id)
	_gravar_instalados(lista)
	var c: Array = (WorldState.obter(COORD, &"comprados", []) as Array).duplicate()
	if not c.has(String(id)):
		c.append(String(id))
		WorldState.definir(COORD, &"comprados", c)
	_baixando[id] = {"t": 0.0, "dur": maxf(CatalogoDeApps.INSTALA_MIN_S,
		CatalogoDeApps.INSTALA_MIN_S + mb / CatalogoDeApps.REDE_MB_S)}
	AudioDirector.tocar_ui(&"celular_ok", -10.0)
	# Volta ao inicio, na pagina do icone novo.
	_fechar_app(false)
	var i := apps_da_tela().find(id)
	if i >= 0:
		_inicio.pagina = i / SoInicio.POR_PAGINA
		_inicio.foco = i % SoInicio.POR_PAGINA
	return true


## Pergunta antes de apagar, com as palavras do iOS.
func pedir_apagar(id: StringName) -> void:
	if CatalogoDeApps.do_sistema(id) or not instalado(id):
		return
	var nome := CatalogoDeApps.nome(id)
	alerta("Apagar \"%s\"?" % nome,
		"Apagar este app tambem libera %s. Os dados dele ficam guardados." % CatalogoDeApps.formatar_mb(
			CatalogoDeApps.tamanho(id)), ["Cancelar", "Apagar"], func(i: int) -> void:
			if i == 1:
				apagar(id))


func apagar(id: StringName) -> void:
	if CatalogoDeApps.do_sistema(id):
		return
	var lista := _instalados()
	lista.erase(id)
	_gravar_instalados(lista)
	_baixando.erase(id)
	if _app_id == id:
		_app = null
		_app_id = &""
		_modo = Modo.INICIO
	if id == &"lanterna" and _rig != null:
		_rig.lanterna(false)
	AudioDirector.tocar_ui(&"clique", -8.0, 0.8)
	apagou.emit(id)


## Plugado em alguma coisa (`Tomada`, a 12 V do carro).
var plugado: bool:
	get:
		return not _fontes_de_carga.is_empty()


func carregando() -> bool:
	return plugado and bateria < 1.0


## Uma fonte de carga pluga (`fonte` e qualquer chave: a tomada, &"carro").
## Como no iPhone: o som, a vibracao e o raio na barra.
func conectar(fonte: Variant) -> void:
	if _fontes_de_carga.has(fonte):
		return
	var antes := plugado
	_fontes_de_carga[fonte] = true
	if not antes:
		AudioDirector.tocar_ui(&"celular_ok", -12.0, 1.4)
		vibrar(0.15)
		if not ativo:
			_avisar_hud("iPhone", "Carregando - %d%%" % roundi(bateria * 100.0))


func desconectar(fonte: Variant) -> void:
	if not _fontes_de_carga.has(fonte):
		return
	_fontes_de_carga.erase(fonte)
	if not plugado:
		AudioDirector.tocar_ui(&"clique", -14.0, 0.8)


## O aparelho nao esta com o jogador (deitado carregando, `Tomada`).
var longe: bool = false


## O aparelho na mao, quando ele esta la (para o fio do carregador sair do
## conector dele); nulo no bolso.
func fone_na_mao() -> Node3D:
	if _rig == null or not is_instance_valid(_rig) or not _rig.visible or _rig.fone == null:
		return null
	return _rig.fone


func ligado() -> bool:
	return _energia == Energia.LIGADO


## Um aviso curto no canto da tela do jogo, para o que acontece com o aparelho
## no bolso.
func _avisar_hud(titulo: String, sub: String) -> void:
	for no: Node in get_tree().get_nodes_in_group(&"hud"):
		if no.has_method(&"aviso"):
			no.call(&"aviso", titulo, sub)
			return


func lanterna_ligada() -> bool:
	return _rig != null and is_instance_valid(_rig) and _rig.lanterna_ligada()


func lanterna(ligada: bool) -> void:
	if _rig != null and is_instance_valid(_rig):
		_rig.lanterna(ligada)
		AudioDirector.tocar_ui(&"interruptor", -8.0)


## O aparelho treme na mao (o app pediu: um recorde, um pedido novo).
func vibrar(duracao: float = 0.4) -> void:
	if _rig != null and is_instance_valid(_rig):
		_rig.vibrar(duracao)


## Para o botao ABRIR da loja.
func abrir_da_loja(id: StringName) -> void:
	_trocar_para(id)


# --- apps: abrir, trocar, fechar -----------------------------------------------

func _app_de(id: StringName) -> AppCelular:
	if _apps.has(id):
		return _apps[id]
	var app: AppCelular = null
	match id:
		&"loja": app = AppLoja.new()
		&"ajustes": app = AppAjustes.new()
		&"portal": app = AppPortal.new()
		&"contatos": app = AppContatos.new()
		&"telefone": app = AppTelefone.new()
		&"mensagens": app = AppConversas.new()
		&"radio": app = AppRadio.new()
		&"calculadora": app = AppCalculadora.new()
		&"notas": app = AppNotas.new()
		&"lanterna": app = AppLanterna.new()
		&"bussola": app = AppBussola.new()
		&"tempo": app = AppTempo.new()
		&"cobrinha": app = AppCobrinha.new()
		&"mapas": app = AppMapas.new()
	if app != null:
		_apps[id] = _preparar(app)
	return app


## O toque no icone: o app cresce a partir dele.
func _lancar(id: StringName, de: Rect2) -> void:
	if progresso_de(id) >= 0.0:
		return
	var app := _app_de(id)
	if app == null:
		return
	AudioDirector.tocar_ui(&"celular_ok", -14.0)
	_app = app
	_app_id = id
	_modo = Modo.APP
	app.abrir()
	_zoom = 0.0
	_zoom_abrindo = true
	_zoom_de = de
	app_trocou.emit()


func _lancar_sem_zoom(id: StringName) -> void:
	if id == &"trampo" or id == &"iweed":
		_app = _apps[id]
	else:
		_app = _app_de(id)
	if _app == null:
		return
	_app_id = id
	_modo = Modo.APP
	_ao_endireitar = Callable()
	_app.abrir()
	_zoom = 1.0
	_zoom_abrindo = true
	app_trocou.emit()


## Troca de um app para outro sem passar pela tela de inicio.
func _trocar_para(id: StringName) -> void:
	_lancar_sem_zoom(id)


## Publica: um app abre outro (Contatos liga pelo Telefone, consulta no
## Portal). Devolve o app aberto, ou null se ele nao esta instalado.
func trocar_para(id: StringName) -> AppCelular:
	if not instalado(id):
		alerta("\"%s\" nao esta instalado" % CatalogoDeApps.nome(id),
			"Baixe na App Store para usar.", ["OK", "App Store"], func(i: int) -> void:
				if i == 1:
					_trocar_para(&"loja")
					(_app as AppLoja).call("_abrir_detalhe", id))
		return null
	_trocar_para(id)
	return _app


## Volta para a tela de inicio: o app encolhe de volta para o icone.
func _fechar_app(animar: bool = true) -> void:
	if _modo != Modo.APP:
		return
	# Deitado, o aparelho primeiro volta a ficar em pe na mao; o app encolhe
	# para o icone depois, na tela de inicio que e sempre em pe.
	if _giro_k > 0.0 or _deitado:
		_ao_endireitar = _fechar_app.bind(animar)
		return
	var i := apps_da_tela().find(_app_id)
	var de := Rect2(L * 0.5 - 13.0, ALTO * 0.45 - 13.0, 26.0, 26.0)
	if i >= 0 and i / SoInicio.POR_PAGINA == _inicio.pagina:
		de = _inicio.rect_do_icone(i % SoInicio.POR_PAGINA)
	elif CatalogoDeApps.DOCK.has(_app_id):
		de = _inicio.rect_do_icone(100 + CatalogoDeApps.DOCK.find(_app_id))
	_zoom_de = de
	_zoom_abrindo = false
	_zoom = 0.0 if animar else 1.0
	_modo = Modo.INICIO
	_inicio.abrir()
	if not animar:
		_app = null
		_app_id = &""
	app_trocou.emit()


func _ao_destravar() -> void:
	_modo = Modo.INICIO
	_inicio.chegada = 0.0
	_inicio.abrir()
	AudioDirector.tocar_ui(&"celular_ok", -16.0, 1.3)


## Um alerta azul do iOS por cima de tudo. `ao` recebe o indice do botao.
func alerta(titulo: String, texto: String, botoes: Array, ao: Callable) -> void:
	_alerta = {"titulo": titulo, "texto": texto, "botoes": botoes,
		"sel": botoes.size() - 1, "ao": ao}
	_alerta_k = 0.0


func _responder_alerta(i: int) -> void:
	var ao: Callable = _alerta.get("ao", Callable())
	_alerta = {}
	AudioDirector.tocar_ui(&"clique", -16.0)
	if ao.is_valid():
		ao.call(i)


# --- tempo --------------------------------------------------------------------

func _process(delta: float) -> void:
	_desde_fechou += delta
	_plugar_no_carro()
	_energia_passo(delta)
	_baixar(delta)
	_girar(delta)
	# O processo fica sempre ligado: a bateria gasta no bolso e carrega na
	# tomada com o aparelho guardado.
	if not ativo:
		return
	if _rig != null and not is_instance_valid(_rig):
		# O rig morava na cabine de um carro que sumiu (o jogador foi tirado dele
		# por fora): o aparelho volta para o bolso sem cerimonia.
		_rig = null
		fechar_em_silencio()
		return
	if _rig != null and is_instance_valid(_rig):
		_rig.brilho_max = AppAjustes.brilho()
	if _rig != null and is_instance_valid(_rig):
		# Apagada, a tela nao ilumina a mao.
		_rig.luz_da_tela = 1.0 if _energia == Energia.LIGADO else (0.25 if _vazio_t > 0.0
			or _energia == Energia.LIGANDO else 0.0)
	_segurar_dedo(delta)
	if _ao_volante():
		_dedo_do_controle(delta)
	else:
		_analogico_direito(delta)
	_alerta_k = minf(1.0, _alerta_k + delta / 0.18) if not _alerta.is_empty() else 0.0
	if _zoom < 1.0:
		_zoom = minf(1.0, _zoom + delta / ZOOM)
		if _zoom >= 1.0 and not _zoom_abrindo:
			_app = null
			_app_id = &""
	var tela := _tela_ativa()
	for a: AppCelular in [_inicio, _bloqueio, _app]:
		if a != null:
			a.foco_visivel = _foco_visivel
			a.ponteiro = _ponteiro
			a.apertando = _dedo_baixo
	_bloqueio.processar(delta)
	_inicio.processar(delta)
	if _app != null:
		_app.processar(delta)
	if tela == null:
		pass
	_arrumar_camadas()
	_c_inicio.queue_redraw()
	_c_app.queue_redraw()
	_c_topo.queue_redraw()
	_dica.queue_redraw()


## O aparelho deita na mao quando o app pede (o Mapas), e volta a ficar em pe
## para sair dele. O desenho gira ao contrario do aparelho, o mesmo angulo no
## mesmo quadro: para quem olha, o mapa fica parado e o telefone vira em volta.
func _girar(delta: float) -> void:
	var quer := ativo and _quer_deitar()
	_giro_k = move_toward(_giro_k, 1.0 if quer else 0.0, delta / GIRO)
	var deitado := quer or _giro_k > 0.0
	if deitado != _deitado:
		_deitado = deitado
		_medir_camadas()
	var e := _giro_k * _giro_k * (3.0 - 2.0 * _giro_k)
	_giro.rotation = e * PI * 0.5
	if _rig != null and is_instance_valid(_rig):
		_rig.giro = e
	if not quer and _giro_k <= 0.0 and _ao_endireitar.is_valid():
		var f := _ao_endireitar
		_ao_endireitar = Callable()
		f.call()


func _quer_deitar() -> bool:
	if _modo != Modo.APP or _app == null or _zoom < 1.0 or _ao_endireitar.is_valid():
		return false
	if not _app.has_method(&"quer_deitar") or not bool(_app.call(&"quer_deitar")):
		return false
	return not _dirigindo()


func _dirigindo() -> bool:
	var j := _jogador()
	return j != null and j.has_method(&"dirigindo") and bool(j.call(&"dirigindo"))


## O analogico direito, para o app que o quer (o Mapas arrasta o mapa). Com o
## aparelho aberto o cursor esta solto, e o `Controle` nao o transforma em olhar.
func _analogico_direito(delta: float) -> void:
	if _app == null or _modo != Modo.APP or not _app.has_method(&"analogico"):
		return
	var eixo := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	var n := eixo.length()
	if n < Controle.ZONA_MORTA:
		return
	eixo = eixo / n * pow((n - Controle.ZONA_MORTA) / (1.0 - Controle.ZONA_MORTA), 1.6)
	_foco_visivel = true
	_app.call(&"analogico", eixo, delta)


## A 12 V do carro: dirigindo um carro (e nao a bicicleta), o aparelho esta no
## carregador do isqueiro.
func _plugar_no_carro() -> void:
	var j := _jogador()
	var no_carro := j != null and j.has_method(&"carro") and j.call(&"carro") != null
	if no_carro:
		conectar(&"carro")
	elif _fontes_de_carga.has(&"carro"):
		desconectar(&"carro")


## Gasta ou carrega, e liga, desliga e avisa conforme a carga.
func _energia_passo(delta: float) -> void:
	if plugado:
		var taxa := CARGA * (CARGA_LENTA if bateria > CARGA_LENTA_DESDE else 1.0)
		bateria = minf(1.0, bateria + taxa * delta)
	else:
		var gasto := GASTO_ESPERA
		if _energia == Energia.LIGADO and ativo:
			gasto += GASTO_TELA
			if app_atual() == &"mapas":
				gasto += GASTO_MAPAS
		if lanterna_ligada():
			gasto += GASTO_FLASH
		bateria = maxf(0.0, bateria - gasto * delta)
	_vazio_t = maxf(0.0, _vazio_t - delta)
	match _energia:
		Energia.LIGADO:
			if bateria <= 0.0:
				_desligar()
				return
			if bateria > AVISOS_DE_BATERIA[0] + 0.05:
				_avisou = 1.0
			for limite: float in AVISOS_DE_BATERIA:
				if bateria <= limite and _avisou > limite:
					_avisou = limite
					_avisar_bateria(limite)
					break
		Energia.DESLIGANDO:
			_energia_t -= delta
			if _energia_t <= 0.0:
				_energia = Energia.DESLIGADO
		Energia.DESLIGADO:
			if plugado and bateria >= LIGA_COM:
				_energia = Energia.LIGANDO
				_energia_t = LIGANDO_S
		Energia.LIGANDO:
			_energia_t -= delta
			if _energia_t <= 0.0:
				# Ligou de novo: da trava, como todo iPhone que acaba de ligar.
				_energia = Energia.LIGADO
				_modo = Modo.BLOQUEIO
				_bloqueio.abrir()
				_app = null
				_app_id = &""
				_ao_endireitar = Callable()
				_alerta = {}
				app_trocou.emit()
				AudioDirector.tocar_ui(&"celular_ok", -16.0, 0.9)


## Zerou: o spinner de desligando, a lanterna apaga, e a tela fica preta.
func _desligar() -> void:
	_energia = Energia.DESLIGANDO
	_energia_t = DESLIGANDO_S
	_alerta = {}
	_dedo_baixo = false
	lanterna(false)
	if not ativo:
		_avisar_hud("iPhone", "Bateria esgotada")


func _avisar_bateria(limite: float) -> void:
	var texto := "%d%% de bateria restante" % roundi(limite * 100.0)
	vibrar(0.35)
	if ativo:
		alerta("Bateria Fraca", texto, ["OK"], Callable())
		AudioDirector.tocar_ui(&"celular_erro", -14.0, 1.2)
	else:
		_avisar_hud("iPhone", "Bateria fraca - " + texto)


func _baixar(delta: float) -> void:
	if _baixando.is_empty():
		return
	for id: StringName in _baixando.keys():
		var b: Dictionary = _baixando[id]
		b["t"] = float(b["t"]) + delta
		if float(b["t"]) >= float(b["dur"]):
			_baixando.erase(id)
			instalou.emit(id)
			if ativo:
				AudioDirector.tocar_ui(&"celular_ok", -18.0, 1.2)
			elif _rig != null:
				_rig.vibrar(0.3)


## A tela que recebe o dedo e as teclas agora.
func _tela_ativa() -> AppCelular:
	match _modo:
		Modo.BLOQUEIO:
			return _bloqueio
		Modo.APP:
			return _app
	return _inicio


## Escala e transparencia das camadas durante o zoom de abrir e fechar app.
func _arrumar_camadas() -> void:
	var k := 1.0 - pow(1.0 - _zoom, 3.0)
	var app_visivel := _app != null and (_modo == Modo.APP or _zoom < 1.0)
	_c_app.visible = app_visivel
	_c_inicio.visible = _modo != Modo.APP or _zoom < 1.0
	if not app_visivel or _zoom >= 1.0:
		_c_app.scale = Vector2.ONE
		_c_app.modulate = Color.WHITE
		_c_inicio.scale = Vector2.ONE
		_c_inicio.modulate = Color.WHITE
		_c_app.visible = _modo == Modo.APP
		return
	var f := k if _zoom_abrindo else 1.0 - k
	var centro := _zoom_de.get_center()
	var menor := _zoom_de.size.x / L
	_c_app.pivot_offset = centro
	_c_app.scale = Vector2.ONE * lerpf(menor, 1.0, f)
	_c_app.modulate = Color(1, 1, 1, clampf(f * 1.6, 0.0, 1.0))
	# A tela de inicio afunda para tras enquanto o app cresce por cima.
	_c_inicio.pivot_offset = centro
	_c_inicio.scale = Vector2.ONE * lerpf(1.0, 1.5, f)
	_c_inicio.modulate = Color(1, 1, 1, 1.0 - f)


# --- desenho ------------------------------------------------------------------

func _desenhar_inicio() -> void:
	var tela: AppCelular = _bloqueio if _modo == Modo.BLOQUEIO else _inicio
	if _modo == Modo.APP and _zoom >= 1.0:
		return
	tela.limpar_alvos()
	tela.desenhar(_c_inicio)


func _desenhar_app() -> void:
	if _app == null:
		return
	_app.limpar_alvos()
	_app.desenhar(_c_app)


func _desenhar_topo() -> void:
	var c := _c_topo
	var escura := _modo != Modo.APP or _barra_escura(_app_id)
	SoFundo.barra(c, _fontes[1], _fontes[2], escura, bateria, carregando(), c.size.x)
	# A marca do dedo: uma bolha clara sob o cursor, como a do simulador do
	# iPhone. So com o mouse, e mais forte com o botao apertado.
	if _ponteiro.x >= 0.0 and not _foco_visivel:
		var a := 0.5 if _dedo_baixo else 0.22
		c.draw_circle(_ponteiro, 5.5 if _dedo_baixo else 4.5, Color(1, 1, 1, a * 0.45))
		c.draw_arc(_ponteiro, 5.5 if _dedo_baixo else 4.5, 0.0, TAU, 24, Color(0.2, 0.2, 0.25, a), 0.5, true)
	if not _alerta.is_empty():
		_desenhar_alerta(c)
	_desenhar_energia(c)


## A tela quando o aparelho nao esta ligado: o spinner de desligando, o preto,
## a pilha vazia (com o plugue pedindo tomada, ou o raio de quem ja esta
## carregando) e a maca de quem esta ligando.
func _desenhar_energia(c: Control) -> void:
	if _energia == Energia.LIGADO:
		return
	var tam := c.size
	var meio := tam * 0.5
	if _energia == Energia.DESLIGANDO:
		var k := clampf(1.0 - _energia_t / DESLIGANDO_S, 0.0, 1.0)
		c.draw_rect(Rect2(Vector2.ZERO, tam), Color(0, 0, 0, minf(1.0, k * 1.6)))
		var passo := int(Time.get_ticks_msec() / 90) % 12
		for i in 12:
			var ang := TAU * float(i) / 12.0
			var a := 0.15 + 0.85 * float(posmod(i - passo, 12)) / 11.0
			var d := Vector2(cos(ang), sin(ang))
			c.draw_line(meio + d * 4.5, meio + d * 8.0, Color(1, 1, 1, a * (1.0 - k * 0.6)), 1.4, true)
		return
	c.draw_rect(Rect2(Vector2.ZERO, tam), Color.BLACK)
	if _energia == Energia.LIGANDO:
		_maca(c, meio + Vector2(0.0, -4.0), clampf((LIGANDO_S - _energia_t) / 0.6, 0.0, 1.0))
		return
	if _vazio_t <= 0.0 and not plugado:
		return
	# A pilha grande do iOS com o fiapo vermelho de carga.
	var p := Rect2(meio.x - 24.0, meio.y - 16.0, 44.0, 22.0)
	c.draw_rect(p, Color(1, 1, 1, 0.85), false, 1.4)
	c.draw_rect(Rect2(p.end.x + 0.8, p.position.y + 7.0, 3.0, 8.0), Color(1, 1, 1, 0.85))
	c.draw_rect(Rect2(p.position.x + 2.5, p.position.y + 2.5, maxf(2.5, (p.size.x - 5.0) * bateria),
		p.size.y - 5.0), Color("ff3b30"))
	if plugado:
		var o := Vector2(meio.x - 2.0, meio.y + 16.0)
		c.draw_colored_polygon(PackedVector2Array([o + Vector2(3.0, -6.0), o + Vector2(-3.0, 1.0),
			o + Vector2(0.0, 1.0), o + Vector2(-1.5, 7.0), o + Vector2(4.5, -0.5), o + Vector2(1.5, -0.5),
			o + Vector2(3.5, -6.0)]), Color("4cd964"))
	else:
		# O plugue com o fio subindo para a pilha: "me ponha na tomada".
		var o := Vector2(meio.x - 2.0, meio.y + 22.0)
		c.draw_line(o + Vector2(0.0, -12.0), o + Vector2(0.0, -2.0), Color(1, 1, 1, 0.8), 1.0, true)
		c.draw_rect(Rect2(o + Vector2(-3.5, -2.0), Vector2(7.0, 6.0)), Color(1, 1, 1, 0.85))
		c.draw_rect(Rect2(o + Vector2(-2.5, 4.0), Vector2(5.0, 2.5)), Color(0.7, 0.7, 0.72))


## A maca da Apple, branca no preto, entrando em `k`.
static func _maca(c: Control, centro: Vector2, k: float) -> void:
	var cor := Color(1, 1, 1, k)
	c.draw_circle(centro + Vector2(-4.2, -1.0), 7.2, cor)
	c.draw_circle(centro + Vector2(4.2, -1.0), 7.2, cor)
	c.draw_circle(centro + Vector2(0.0, 3.5), 8.0, cor)
	c.draw_circle(centro + Vector2(-3.4, 8.2), 4.5, cor)
	c.draw_circle(centro + Vector2(3.4, 8.2), 4.5, cor)
	# A mordida, o vinco de cima e o de baixo.
	c.draw_circle(centro + Vector2(11.8, 0.2), 4.4, Color.BLACK)
	c.draw_circle(centro + Vector2(0.0, -8.4), 2.2, Color.BLACK)
	c.draw_circle(centro + Vector2(0.0, 13.6), 1.8, Color.BLACK)
	# A folha.
	var f := PackedVector2Array()
	for i in 12:
		var t := float(i) / 11.0 * PI
		f.append(centro + Vector2(1.2, -11.8) + Vector2(sin(t) * 2.2, -cos(t) * 4.2).rotated(0.7))
	c.draw_colored_polygon(f, cor)


func _barra_escura(id: StringName) -> bool:
	return id in [&"iweed", &"cobrinha", &"lanterna", &"bussola", &"calculadora", &"tempo"]


## O alerta do iOS 4: caixa azul-marinho translucida com o brilho de vidro em
## cima, borda clara, e os botoes de vidro lado a lado.
func _desenhar_alerta(c: Control) -> void:
	var k := 1.0 - pow(1.0 - _alerta_k, 3.0)
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0, 0, 0, 0.45 * k))
	var f_reg := _fontes[0]
	var f_bold := _fontes[2]
	var texto := String(_alerta["texto"])
	# A caixa tem a largura da tela em pe, tambem com o aparelho deitado.
	var caixa_l := minf(L, c.size.x) - 28.0
	var linhas := f_reg.get_multiline_string_size(texto, HORIZONTAL_ALIGNMENT_CENTER, caixa_l - 16.0, 6).y
	var r := Rect2((c.size.x - caixa_l) * 0.5, 0.0, caixa_l, 44.0 + linhas)
	r.position.y = (c.size.y - r.size.y) * 0.5
	# Salta ao abrir: cresce um nada alem e volta.
	var s := lerpf(0.85, 1.0, k) + sin(k * PI) * 0.06
	c.draw_set_transform(r.get_center(), 0.0, Vector2(s, s))
	var local := Rect2(-r.size * 0.5, r.size)
	var pts := AppCelular.cantos(local, 5.0)
	var cores := PackedColorArray()
	for p: Vector2 in pts:
		var t := (p.y - local.position.y) / local.size.y
		cores.append(Color(Color("22345a").lerp(Color("0d1a36"), t), 0.93 * k))
	c.draw_polygon(pts, cores)
	pts.append(pts[0])
	c.draw_polyline(pts, Color(1, 1, 1, 0.75 * k), 0.8, true)
	c.draw_colored_polygon(AppCelular.cantos(Rect2(local.position + Vector2(1.0, 1.0),
		Vector2(local.size.x - 2.0, 12.0)), 4.0), Color(1, 1, 1, 0.14 * k))
	c.draw_string(f_bold, local.position + Vector2(0.0, 12.0), String(_alerta["titulo"]),
		HORIZONTAL_ALIGNMENT_CENTER, local.size.x, 7, Color(1, 1, 1, k))
	c.draw_multiline_string(f_reg, local.position + Vector2(8.0, 22.0), texto,
		HORIZONTAL_ALIGNMENT_CENTER, local.size.x - 16.0, 6, -1, Color(1, 1, 1, 0.92 * k))
	var botoes: Array = _alerta["botoes"]
	var n := botoes.size()
	var larg := (local.size.x - 12.0 - 4.0 * float(n - 1)) / float(n)
	for i in n:
		var b := Rect2(local.position.x + 6.0 + float(i) * (larg + 4.0), local.end.y - 16.0, larg, 11.0)
		var sel := i == int(_alerta["sel"])
		var ultimo := i == n - 1 and n > 1
		var cima := Color("7f8ba6") if ultimo else Color("5d6b8a")
		var baixo := Color("39476a") if ultimo else Color("2b3858")
		if sel and _foco_visivel:
			cima = cima.lightened(0.25)
			baixo = baixo.lightened(0.2)
		var bp := AppCelular.cantos(b, 2.5)
		var bc := PackedColorArray()
		for p: Vector2 in bp:
			bc.append(Color(cima.lerp(baixo, (p.y - b.position.y) / b.size.y), k))
		c.draw_polygon(bp, bc)
		bp.append(bp[0])
		c.draw_polyline(bp, Color(0, 0, 0, 0.5 * k), 0.5, true)
		c.draw_string(f_bold, Vector2(b.position.x, b.position.y + 7.8), String(botoes[i]),
			HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 6, Color(1, 1, 1, k))
		_alerta["r%d" % i] = Rect2(r.get_center() + b.position * s, b.size * s)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## As teclas do que se pode fazer agora, na tela do jogo, embaixo.
func _desenhar_dica() -> void:
	if not ativo or _de_cena:
		return
	var ctl := Settings.get(&"controle") as Controle
	var pad := ctl != null and ctl.dispositivo == Controle.Dispositivo.CONTROLE
	var partes: Array[String] = []
	if _ao_volante():
		# Ao volante: o dedo, e lembrar que o carro continua andando.
		if pad:
			partes = ["[@RS] Dedo", "[@A] Tocar", "[@B] Voltar", "[@LS] Dirigir", "[@LB] Olhar a rua"]
		else:
			partes = ["[MOUSE] Tocar", "[ESC] Voltar", "[WASD] Dirigir", "[C] Olhar a rua"]
		var frase_v := "   ".join(partes)
		var tam_v := HudTema.T_ROTULO
		var w_v := HudLayout.largura_pedacos(HudLayout.pedacos(frase_v), tam_v, pad)
		var h_v := HudTema.altura(HudTema.semi(), tam_v) + 2.0
		var p_v := Vector2(14.0, HudLayout.TELA.y - h_v - 10.0)
		HudTema.painel(_dica, Rect2(p_v.x - 6.0, p_v.y - 3.0, w_v + 12.0, h_v + 6.0), 0.7, 3.0)
		HudObjetivo.desenhar_frase(_dica, p_v, frase_v, tam_v, 1.0, HudTema.TEXTO)
		return
	if not _alerta.is_empty():
		partes = ["[E] Confirmar", "[ESC] Cancelar"]
	elif _modo == Modo.BLOQUEIO:
		partes = ["[E] Desbloquear"]
	elif _modo == Modo.INICIO:
		if _inicio.editando:
			partes = ["[E] Apagar", "[Q] Pronto"]
		else:
			partes = ["[E] Abrir", "[Q] Editar"]
	elif _app != null and _app.has_method(&"dicas"):
		for d: String in _app.call(&"dicas"):
			partes.append(d)
		if pad and _app.has_method(&"analogico"):
			partes.append("[@RS] Mover")
		partes.append("[ESC] Voltar")
	else:
		partes = ["[E] Usar", "[ESC] Voltar"]
	partes.append(("[@LB]" if pad else "[C]") + " Guardar")
	var frase := "   ".join(partes)
	var tam := HudTema.T_ROTULO
	var w := HudLayout.largura_pedacos(HudLayout.pedacos(frase), tam, pad)
	var h := HudTema.altura(HudTema.semi(), tam) + 2.0
	# No canto de baixo a esquerda: no meio ela tampava o botao de inicio.
	var tela := HudLayout.TELA
	var p := Vector2(14.0, tela.y - h - 10.0)
	HudTema.painel(_dica, Rect2(p.x - 6.0, p.y - 3.0, w + 12.0, h + 6.0), 0.7, 3.0)
	HudObjetivo.desenhar_frase(_dica, p, frase, tam, 1.0, HudTema.TEXTO)


# --- entrada ------------------------------------------------------------------

func _pode_abrir() -> bool:
	return not (Conversa.ativo or Dialogo.ativo or Documento.ativo
		or Gps.ativo or Terminal.ativo or get_tree().paused)


func _input(evento: InputEvent) -> void:
	if _de_cena:
		return
	if not ativo:
		if evento.is_action_pressed("celular") and _pode_abrir():
			abrir()
			get_viewport().set_input_as_handled()
		return
	if Documento.ativo:
		return
	if _energia != Energia.LIGADO:
		# Desligado nada responde: qualquer botao so mostra a pilha vazia.
		if evento.is_action_pressed("celular"):
			fechar()
		elif evento.is_pressed() and not evento.is_echo() and not (evento is InputEventMouseMotion):
			_vazio_t = 2.2
		get_viewport().set_input_as_handled()
		return

	if evento is InputEventMouse:
		_mouse(evento as InputEventMouse)
		get_viewport().set_input_as_handled()
		return
	if evento is InputEventKey or evento is InputEventJoypadButton:
		if evento.is_pressed():
			_foco_visivel = true
	elif evento is InputEventJoypadMotion and absf((evento as InputEventJoypadMotion).axis_value) > 0.5:
		_foco_visivel = true

	if not _alerta.is_empty():
		_teclas_do_alerta(evento)
		get_viewport().set_input_as_handled()
		return

	var tela := _tela_ativa()
	# Campo de texto de app em foco: a letra e letra, inclusive C, E e Q.
	var digitada := evento as InputEventKey
	if tela != null and tela.digitando() and digitada != null and digitada.pressed \
			and tela.tecla(digitada):
		get_viewport().set_input_as_handled()
		return

	if evento.is_action_pressed("celular"):
		fechar()
		get_viewport().set_input_as_handled()
		return

	if _ao_volante():
		if _tecla_de_tocar(evento):
			pass
		elif evento.is_action_pressed("pausa") or evento.is_action_pressed("ui_cancel"):
			_voltar()
		elif not (evento is InputEventKey or evento is InputEventJoypadButton):
			return
		# O resto (setas, WASD, direcional) e do carro: nao navega o aparelho, e
		# o carro le o teclado direto, sem passar por aqui.
		get_viewport().set_input_as_handled()
		return

	if digitada != null and digitada.pressed and tela != null:
		if digitada.keycode == KEY_DELETE and _modo == Modo.INICIO:
			_inicio.acao(&"editar")
			get_viewport().set_input_as_handled()
			return
		if tela.tecla(digitada):
			get_viewport().set_input_as_handled()
			return

	if _modo == Modo.APP and _app != null and _app.has_method(&"acao_extra") and _extra(evento):
		get_viewport().set_input_as_handled()
		return
	if evento.is_action_pressed("pausa") or evento.is_action_pressed("ui_cancel"):
		_voltar()
	elif evento.is_action_pressed("interagir") or evento.is_action_pressed("ui_accept"):
		_acionar()
	elif evento.is_action_pressed("examinar") and _modo == Modo.INICIO:
		_inicio.acao(&"editar")
	elif _direcao(evento, "mover_tras", "ui_down"):
		_mover(&"baixo")
	elif _direcao(evento, "mover_frente", "ui_up"):
		_mover(&"cima")
	elif _direcao(evento, "mover_dir", "ui_right"):
		_mover(&"dir")
	elif _direcao(evento, "mover_esq", "ui_left"):
		_mover(&"esq")
	elif evento is InputEventKey or evento is InputEventJoypadButton:
		# O resto das teclas nao vaza para o jogo: o jogador esta no telefone.
		pass
	else:
		return
	get_viewport().set_input_as_handled()


## Os comandos de app alem da navegacao: Q/Y (examinar), e no controle os
## gatilhos (zoom) e o RB (opcoes). No teclado o zoom e as opcoes sao letras, e o
## app as le em `tecla`.
func _extra(evento: InputEvent) -> bool:
	var nome := &""
	if evento.is_action_pressed("examinar"):
		nome = &"examinar"
	elif evento is InputEventJoypadMotion or evento is InputEventJoypadButton:
		if evento.is_action_pressed("agachar"):
			nome = &"zoom_menos"
		elif evento.is_action_pressed("veiculo"):
			nome = &"zoom_mais"
		elif evento.is_action_pressed("radio"):
			nome = &"opcoes"
	if nome == &"":
		return false
	return bool(_app.call(&"acao_extra", nome))


## Tecla e analogico, com repeticao: o analogico empurrado anda uma casa, e nao
## vinte por segundo.
func _direcao(evento: InputEvent, a: String, b: String) -> bool:
	return evento.is_action_pressed(a, true) or evento.is_action_pressed(b, true)


func _teclas_do_alerta(evento: InputEvent) -> void:
	var n := (_alerta["botoes"] as Array).size()
	if _direcao(evento, "mover_esq", "ui_left"):
		_alerta["sel"] = posmod(int(_alerta["sel"]) - 1, n)
	elif _direcao(evento, "mover_dir", "ui_right"):
		_alerta["sel"] = posmod(int(_alerta["sel"]) + 1, n)
	elif evento.is_action_pressed("interagir") or evento.is_action_pressed("ui_accept"):
		_responder_alerta(int(_alerta["sel"]))
	elif evento.is_action_pressed("pausa") or evento.is_action_pressed("ui_cancel"):
		_responder_alerta(0)


func _mover(nome: StringName) -> void:
	var tela := _tela_ativa()
	if tela == null:
		return
	AudioDirector.tocar_ui(&"clique", -26.0)
	tela.acao(nome)


func _acionar() -> void:
	var tela := _tela_ativa()
	if tela == null:
		return
	tela.acao(&"ok")
	_depois_do_app()


## O botao de inicio: volta dentro do app; na raiz dele, vai para o inicio; no
## inicio, guarda o aparelho.
func _voltar() -> void:
	match _modo:
		Modo.BLOQUEIO:
			fechar()
		Modo.INICIO:
			if not _inicio.acao(&"voltar"):
				fechar()
		Modo.APP:
			if _app == null or not _app.acao(&"voltar"):
				_sair_do_app()


## Saiu do app pela raiz. O Trampo diz para onde: a grade, o iWeed (quando o
## perfil foi aberto de la) ou fechar o aparelho (quando veio da conversa).
func _sair_do_app() -> void:
	if _app == _trampo:
		var saida := _trampo.saida
		_trampo.saida = &"inicio"
		if saida == &"fechar":
			fechar()
			return
		if saida == &"iweed":
			_trocar_para(&"iweed")
			return
	_fechar_app(true)
	AudioDirector.tocar_ui(&"clique", -18.0, 0.9)


## Depois de uma acao no app: o iWeed pode pedir o perfil de alguem (vai ao
## Trampo), e qualquer app pode pedir para voltar ao inicio.
func _depois_do_app() -> void:
	if _app is AppIos and (_app as AppIos).quer_sair:
		(_app as AppIos).quer_sair = false
		_sair_do_app()
		return
	if _app == _iweed and not _iweed.abrir_perfil_de.is_empty():
		var f := _iweed.abrir_perfil_de
		_iweed.abrir_perfil_de = {}
		_trocar_para(&"trampo")
		_trampo.mostrar_perfil(f, &"iweed")


# --- o dedo -------------------------------------------------------------------

func _mouse(evento: InputEventMouse) -> void:
	# `pv` no vidro em pe (para o aparelho ceder no ponto certo); `p` na tela de
	# agora, que deitada gira junto com o desenho.
	var pv := _no_vidro(evento.position)
	var p := _para_tela_ativa(pv) if pv.x >= 0.0 else pv
	_ponteiro = p
	if evento is InputEventMouseMotion:
		if (evento as InputEventMouseMotion).relative.length() > 0.5:
			_foco_visivel = false
		# Sobre o vidro a seta do sistema some e fica a marca do dedo; fora dele
		# ela volta, para o jogador achar o aparelho.
		if _mexeu_no_mouse:
			var quer := Input.MOUSE_MODE_CONFINED_HIDDEN if p.x >= 0.0 else Input.MOUSE_MODE_CONFINED
			if Input.mouse_mode != quer:
				Input.mouse_mode = quer
		_arrastar_dedo(p)
		return
	var b := evento as InputEventMouseButton
	if b == null:
		return
	_foco_visivel = false
	if not b.pressed:
		if b.button_index == MOUSE_BUTTON_LEFT and _dedo_baixo:
			_soltar_dedo(p)
		return
	match b.button_index:
		MOUSE_BUTTON_LEFT:
			_descer_dedo(p, pv)
		MOUSE_BUTTON_RIGHT:
			if not _alerta.is_empty():
				_responder_alerta(0)
			else:
				_voltar()
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			var tela := _tela_ativa()
			if tela != null and _alerta.is_empty() and p.x >= 0.0:
				tela.rolar(1.0 if b.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1.0)


## O dedo encosta em `p` (na tela de agora; `pv` e o mesmo ponto no vidro em pe).
func _descer_dedo(p: Vector2, pv: Vector2) -> void:
	if p.x < 0.0:
		return
	_dedo_baixo = true
	_dedo_de = p
	_dedo_ultimo = p
	_dedo_t = 0.0
	_dedo_arrastou = false
	_dedo_segurou = false
	if _rig != null:
		_rig.tocou(pv / Vector2(L, ALTO))


## O dedo encostado anda ate `p`: passou do arrasto minimo, vira arrasto.
func _arrastar_dedo(p: Vector2) -> void:
	if not _dedo_baixo or p.x < 0.0:
		return
	var delta := p - _dedo_ultimo
	if not _dedo_arrastou and p.distance_to(_dedo_de) > ARRASTO and not _dedo_segurou:
		_dedo_arrastou = true
	if _dedo_arrastou:
		var tela := _tela_ativa()
		if tela != null and _alerta.is_empty():
			tela.arrastar(_dedo_de, delta, false)
	_dedo_ultimo = p


# --- ao volante -----------------------------------------------------------------
# Dirigindo, as setas e o WASD (e o analogico esquerdo) continuam sendo o carro:
# o pe e a mao esquerda nao param porque a direita esta no telefone. O aparelho
# se usa pelo dedo — o mouse, ou no controle o analogico direito movendo um dedo
# pela tela —, e E / A tocam onde o dedo esta.

## Velocidade do dedo do analogico direito (unidades por segundo).
const DEDO_VEL := 150.0


func _ao_volante() -> bool:
	return _rig != null and is_instance_valid(_rig) and _rig.ao_volante()


func _dedo_do_controle(delta: float) -> void:
	var eixo := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	var n := eixo.length()
	if n < Controle.ZONA_MORTA:
		return
	eixo = eixo / n * pow((n - Controle.ZONA_MORTA) / (1.0 - Controle.ZONA_MORTA), 1.6)
	if _ponteiro.x < 0.0:
		_ponteiro = Vector2(L * 0.5, ALTO * 0.55)
	_foco_visivel = false
	var p := (_ponteiro + eixo * DEDO_VEL * delta).clamp(Vector2.ZERO, Vector2(L, ALTO))
	_ponteiro = p
	_arrastar_dedo(p)


## A tecla de usar ao volante: o dedo encosta e solta onde esta (segurar a tecla
## e o toque longo). Sem o dedo na tela, usa o que estiver em foco.
func _tecla_de_tocar(evento: InputEvent) -> bool:
	var usar := evento.is_action("interagir") or evento.is_action("ui_accept")
	if not usar or (evento is InputEventKey and (evento as InputEventKey).echo):
		return false
	if evento.is_pressed():
		if _ponteiro.x < 0.0:
			_acionar()
			return true
		_descer_dedo(_ponteiro, _ponteiro)
	elif _dedo_baixo:
		_soltar_dedo(_ponteiro)
	return true


func _soltar_dedo(p: Vector2) -> void:
	_dedo_baixo = false
	if _rig != null:
		_rig.soltou()
	if not _alerta.is_empty():
		for i in (_alerta["botoes"] as Array).size():
			var r: Rect2 = _alerta.get("r%d" % i, Rect2())
			if r.has_point(p):
				_responder_alerta(i)
				return
		return
	var tela := _tela_ativa()
	if tela == null:
		return
	if _dedo_arrastou:
		tela.arrastar(_dedo_de, Vector2.ZERO, true)
	elif not _dedo_segurou and p.x >= 0.0:
		if tela.toque(p):
			AudioDirector.tocar_ui(&"clique", -26.0)
		_depois_do_app()


func _segurar_dedo(delta: float) -> void:
	if not _dedo_baixo or _dedo_arrastou or _dedo_segurou:
		return
	_dedo_t += delta
	if _dedo_t >= SEGURAR:
		var tela := _tela_ativa()
		_dedo_segurou = tela != null and _alerta.is_empty() and tela.segurar(_dedo_de)


## Do vidro em pe para a tela de agora: a trava e o inicio sao sempre em pe; o
## app e a barra moram no no que gira.
func _para_tela_ativa(p: Vector2) -> Vector2:
	if _modo != Modo.APP:
		return p
	return (_giro.get_transform() * _c_topo.get_transform()).affine_inverse() * p


## Onde o ponteiro cai no vidro, em unidades da tela; fora dele, (-1, -1).
func _no_vidro(pos: Vector2) -> Vector2:
	var uv := Vector2(-1.0, -1.0)
	if _rig != null and is_instance_valid(_rig) and _rig.visible:
		uv = _rig.uv_da_tela(pos)
	elif _plano.visible:
		var r := Rect2(_plano.global_position, _plano.size)
		if r.has_point(pos):
			uv = (pos - r.position) / r.size
	if uv.x < 0.0:
		return Vector2(-1.0, -1.0)
	return uv * Vector2(L, ALTO)


# --- save ---------------------------------------------------------------------

## A bateria vai no save junto com o resto do jogador (`SaveGame`); o que esta
## instalado ja esta no WorldState.
func para_dicionario() -> Dictionary:
	return {"bateria": bateria}


func de_dicionario(d: Dictionary) -> void:
	bateria = clampf(float(d.get("bateria", bateria)), 0.0, 1.0)
	_baixando.clear()
	_app = null
	_app_id = &""
