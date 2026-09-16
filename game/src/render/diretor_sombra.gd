## Autoload. Decide QUAIS luzes projetam sombra.
##
## Por que isso e uma politica e nao um interruptor
## ------------------------------------------------
## Ligar `shadow_enabled` em toda luz da rua nao deixa a cena mais bonita: deixa
## mais cara e mais CHAPADA. Com dez postes projetando, cada sombra e cortada
## pela luz do poste vizinho e o chao vira uma poca cinzenta uniforme — o
## contrario do que a sombra deveria fazer, que e dar direcao e peso.
##
## O que os jogos que este projeto persegue faziam era o oposto: UMA luz heroi
## por ambiente projeta, e o resto so ilumina. A sombra vira evento, nao textura.
##
## Como funciona
## -------------
## Luz candidata entra no grupo `luz_sombra`. O diretor reavalia de tempos em
## tempos (nao por quadro), ordena por distancia da camera e liga a sombra nas
## `ORCAMENTO` mais proximas, desligando todas as outras. A direcional do clima e
## caso a parte: ela nao concorre por orcamento porque e uma so e porque e ela
## que da a sombra de sol, a mais visivel de todas.
extends Node

## Grupo em que uma luz se inscreve para concorrer a sombra.
const GRUPO := &"luz_sombra"

## Quantas luzes posicionais projetam ao mesmo tempo.
##
## Duas, e nao dez. Sombra de omni e um cubemap — seis faces por luz — e o custo
## nao e o unico motivo: ver o cabecalho. Duas dao direcao sem achatar.
const ORCAMENTO := 2

## Alem disto a luz nem entra na disputa, em metros. Uma sombra de poste a 40 m
## ocupa quatro pixels e custa o mesmo que a de perto.
const ALCANCE := 26.0

## Passo da reavaliacao, em segundos. A lista muda quando o jogador anda ou
## quando o streaming monta um chunk, e nenhuma das duas coisas acontece a 60 Hz.
const PASSO := 0.35

## Energia abaixo da qual a direcional nao vale sombra. Nos presets noturnos
## `sol_energia` fica em 0,05: a luz existe so para tingir, e uma sombra de lua
## a essa intensidade e uma mancha que ninguem ve e todo mundo paga.
const ENERGIA_MINIMA := 0.35

var _relogio: float = 0.0
## Ligadas no ultimo passo. Guardado para desligar sem varrer o grupo inteiro.
var _ligadas: Array[Light3D] = []
var _ativo: bool = false
## `_ativo` nasce `false`, que e o mesmo valor que `Settings.sombras` tem no PS1
## STYLE. Sem esta bandeira o `_ao_mudar_estilo` do `_ready` caia no atalho de
## "nada mudou" e nunca chamava `set_process(false)` — o diretor continuava
## rodando e acendia sombra nos dois postes mais proximos DENTRO do PS1 STYLE.
## Custou 5,59% de pixels no teste de identidade antes de aparecer.
var _iniciado: bool = false


## `--debug-sombra` na linha de comando imprime, a cada reavaliacao, quem esta
## projetando e por que. Sombra que nao aparece tem meia duzia de causas mudas
## (luz fora do grupo, malha com cast_shadow OFF, energia abaixo do minimo,
## camera ausente) e nenhuma delas da erro.
var _debug: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_debug = OS.get_cmdline_user_args().has("--debug-sombra")
	Settings.changed.connect(_ao_mudar_estilo)
	_ao_mudar_estilo()


func _ao_mudar_estilo() -> void:
	if _iniciado and _ativo == Settings.sombras:
		return
	_iniciado = true
	_ativo = Settings.sombras
	set_process(_ativo)
	if not _ativo:
		_apagar_tudo()
		return
	_relogio = PASSO  # reavalia no proximo quadro, sem esperar o passo inteiro


func _process(delta: float) -> void:
	_relogio += delta
	if _relogio < PASSO:
		return
	_relogio = 0.0
	_reavaliar()


## Desliga a sombra de tudo que este diretor havia ligado.
##
## So do que ELE ligou. Uma malha ou luz que tenha sombra por conta propria
## (cena de teste, cinematica) nao e assunto daqui, e apagar tudo por varredura
## quebraria essas em silencio.
func _apagar_tudo() -> void:
	for luz: Light3D in _ligadas:
		if is_instance_valid(luz):
			luz.shadow_enabled = false
	_ligadas.clear()
	# A direcional nunca entra em `_ligadas`, porque nao disputa orcamento. Sem
	# esta varredura ela ficaria projetando depois de o jogador desligar sombra
	# no menu — e justo a sombra mais visivel da cena.
	for no: Node in get_tree().get_nodes_in_group(GRUPO):
		if no is DirectionalLight3D:
			(no as DirectionalLight3D).shadow_enabled = false


func _reavaliar() -> void:
	# Guarda de seguranca. `set_process(false)` ja deveria bastar, mas este e o
	# unico ponto que ACENDE sombra: se ele rodar com o estilo errado, o PS1
	# STYLE deixa de ser identico e o defeito aparece como um numero estranho num
	# teste de imagem, longe daqui.
	if not _ativo:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var olho := camera.global_position

	var candidatas: Array[Light3D] = []
	for no: Node in get_tree().get_nodes_in_group(GRUPO):
		var luz := no as Light3D
		if luz == null or not luz.is_inside_tree() or not luz.visible:
			continue
		if luz is DirectionalLight3D:
			# Fora da disputa: decidida pela energia do clima, nao por distancia.
			_aplicar_direcional(luz as DirectionalLight3D)
			continue
		if luz.global_position.distance_to(olho) <= ALCANCE:
			candidatas.append(luz)

	candidatas.sort_custom(func(a: Light3D, b: Light3D) -> bool:
		return a.global_position.distance_squared_to(olho) \
			< b.global_position.distance_squared_to(olho))

	var novas: Array[Light3D] = candidatas.slice(0, ORCAMENTO)

	# Apaga quem saiu antes de acender quem entrou: invertendo a ordem, uma luz
	# que continua na lista seria apagada logo depois de ser reacesa.
	for luz: Light3D in _ligadas:
		if is_instance_valid(luz) and not novas.has(luz):
			luz.shadow_enabled = false
	for luz: Light3D in novas:
		if not luz.shadow_enabled:
			_aplicar_posicional(luz)
	_ligadas = novas

	if _debug:
		_relatar(candidatas, novas)


## Conta quantas malhas visiveis realmente projetam. Uma luz com sombra ligada
## sobre um mundo inteiro de `cast_shadow = OFF` nao desenha nada, e e o tipo de
## coisa que se perde uma tarde procurando no lugar errado.
func _relatar(candidatas: Array[Light3D], novas: Array[Light3D]) -> void:
	var total := 0
	var projetam := 0
	var multi := 0
	var multi_projetam := 0
	var pilha: Array[Node] = [get_tree().current_scene]
	while not pilha.is_empty():
		var n: Node = pilha.pop_back()
		if n == null:
			continue
		if n is GeometryInstance3D and (n as Node3D).is_visible_in_tree():
			var g := n as GeometryInstance3D
			var liga := g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if n is MultiMeshInstance3D:
				multi += 1
				if liga:
					multi_projetam += 1
			else:
				total += 1
				if liga:
					projetam += 1
		for f: Node in n.get_children():
			pilha.append(f)
	if multi > 0:
		print("[sombra] multimesh %d/%d projetam" % [multi_projetam, multi])
	var dir_on := 0
	var dir_total := 0
	for no: Node in get_tree().get_nodes_in_group(GRUPO):
		if no is DirectionalLight3D:
			dir_total += 1
			if (no as DirectionalLight3D).shadow_enabled:
				dir_on += 1
	print("[sombra] grupo=%d candidatas=%d ligadas=%d | direcional %d/%d | malhas %d/%d projetam"
		% [get_tree().get_nodes_in_group(GRUPO).size(), candidatas.size(),
			novas.size(), dir_on, dir_total, projetam, total])


## Sombra DURA, de propósito.
##
## `shadow_blur = 0` e o que mantem a borda recortada. Uma penumbra suave
## modernizaria a imagem na hora e brigaria com a textura de filtro ponto do
## resto da cena; a borda dura, rasterizada num mapa de sombra pequeno, e o que
## combina com o jogo — e o downres faz o trabalho de estilo de graca.
func _aplicar_posicional(luz: Light3D) -> void:
	luz.shadow_enabled = true
	# A penumbra vem da escada de qualidade (Fase 4 do PLANO_AAA_4K), e nao
	# daqui: quem acende sombra e este diretor, mas quanto ela borra depende do
	# degrau em que o jogador esta. O argumento de borda dura abaixo valeu ate a
	# Fase 3 — com textura de 1024 px, relevo e TAA, a borda serrilhada passou a
	# ser a unica coisa recortada da cena. Sem o autoload (bancada, teste), fica
	# zero, que e o comportamento antigo.
	var q := get_node_or_null(^"/root/Qualidade")
	luz.shadow_blur = float(q.call("blur_de_sombra")) if q != null else 0.0
	# Poste ilumina de cima e o chao e quase perpendicular a ele: o normal_bias
	# alto e o que tira o listrado de auto-sombra no asfalto sem descolar a
	# sombra do pe do objeto.
	luz.shadow_bias = 0.035
	luz.shadow_normal_bias = 1.6


func _aplicar_direcional(luz: DirectionalLight3D) -> void:
	var quer := luz.light_energy >= ENERGIA_MINIMA
	if luz.shadow_enabled == quer:
		return
	luz.shadow_enabled = quer
	if not quer:
		return
	# Um split so: a cascata existe para suavizar a transicao em mundo aberto, e
	# aqui o alcance de desenho ja e cortado pela nevoa muito antes de a cascata
	# fazer diferenca. Um split e mais barato e tem borda mais dura.
	luz.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	luz.directional_shadow_max_distance = 48.0
	luz.shadow_blur = 0.0
	luz.shadow_bias = 0.03
	luz.shadow_normal_bias = 1.4
	# Sol de disco zero: sem penumbra, como o resto da direcao de arte pede.
	luz.light_angular_distance = 0.0
