## Controle de videogame, do boot ao volante.
##
## O achado
## --------
## O mapa de entrada do projeto tinha dezoito acoes e NENHUMA ligacao de
## joypad. Fora o START do boot, que `menu.gd` lia cravado, um jogo de estetica
## PlayStation nao se jogava com controle: nao andava, nao abria menu, nao
## voltava de tela nenhuma. O `PLANO_UI_AAA` pedia "navegacao de controle em
## todas as telas" na Fase 7, e o `PLANO_MENU_AAA` registrou que ninguem tinha
## apertado um botao nesta frente — e nao tinha como.
##
## Por que as ligacoes nascem em codigo e nao no `project.godot`
## -------------------------------------------------------------
## Porque `project.godot` e o arquivo que mais sofre com sessoes paralelas
## (`relogio.gd` ja registra isso para autoload), e a secao `[input]` e um bloco
## de texto serializado onde dois editores simultaneos produzem conflito de
## merge ilegivel. Registrar em tempo de execucao e aditivo: nao apaga a tecla
## de ninguem, e quem mexer nas teclas do arquivo nao esbarra aqui.
##
## Por que o analogico direito vira MOUSE
## --------------------------------------
## Porque o olhar do jogador — e a roleta do radio do carro, que usa o mesmo
## caminho — ja existe inteiro em `Player._unhandled_input`, lendo
## `InputEventMouseMotion.relative`. Um segundo caminho so para o analogico
## teria de repetir a sensibilidade, o limite de pitch, a excecao da roleta e o
## travamento das cenas cortadas, e divergiria no primeiro ajuste. Convertendo o
## eixo em movimento de mouse sintetico, o controle herda tudo isso sem uma linha
## nova no jogador.
##
## O layout
## --------
## Nomes de botao do Godot (posicao, nao simbolo): A embaixo, B a direita, X a
## esquerda, Y em cima — cruz, circulo, quadrado e triangulo no controle de PS.
##
##     A      interagir        confirma em todo menu, como o E
##     B      pausa            volta em todo menu, como o ESC; abre a prancha em jogo
##     X      lanterna
##     Y      examinar
##     LB     celular          o GPS e um app dele, a um toque
##     RB     radio
##     LT     agachar          e a buzina no carro e a campainha na bicicleta
##     RT     veiculo          entrar e sair do carro
##     L3     correr           R3  alternar camera
##     SELECT inventario       START pausa
##     analogico esquerdo e direcional: andar, e navegar qualquer lista
##     analogico direito: olhar
##
## Duas acoes ficaram sem botao proprio, e as duas de proposito: `gps` mora
## dentro do celular (`Celular._abrir_app` abre o aparelho deitado), e os dois
## `debug_*` sao ferramenta de desenvolvimento.
class_name Controle
extends Node

## Zona morta do analogico. Abaixo disto o eixo le zero.
##
## 0,2 e o valor que o proprio Godot usa como padrao de acao. Menos que isso, um
## controle usado de segunda mao faz a camera escorregar sozinha no menu — e num
## jogo de horror parado, uma camera que anda sozinha le como bug de medo.
const ZONA_MORTA := 0.2

## Velocidade do olhar no analogico, em "pixels de mouse" por segundo com o
## analogico no fim do curso.
##
## A conta: `Player.SENSIBILIDADE` e 0,0024 rad por pixel. 1100 px/s da 2,64
## rad/s, ou seja meia volta em 1,2 s — o ritmo de terceira pessoa de survival
## horror da epoca, que gira devagar de proposito. Mais rapido que isso e shooter.
const OLHAR_PX_S := 1100.0

## Curva do analogico. Expoente sobre o valor ja sem a zona morta: 2,0 faz o
## meio do curso ser fino para mirar e o fim do curso ser rapido para virar.
const CURVA := 2.0

## Cada acao e a lista de entradas de joypad que ela ganha.
##
## `b:N` e botao; `a:N+` e `a:N-` sao eixo com sentido. O direcional entra junto
## do analogico esquerdo nas quatro direcoes: e ele que navega lista em toda
## tela, e `Player` le o movimento por `Input.get_vector`, entao o analogico
## chega com intensidade e o direcional chega cheio — os dois sem codigo novo.
const LIGACOES := {
	&"mover_frente": ["a:1-", "b:11"],
	&"mover_tras": ["a:1+", "b:12"],
	&"mover_esq": ["a:0-", "b:13"],
	&"mover_dir": ["a:0+", "b:14"],
	&"interagir": ["b:0"],
	&"pausa": ["b:1", "b:6"],
	&"lanterna": ["b:2"],
	&"examinar": ["b:3"],
	&"celular": ["b:9"],
	&"radio": ["b:10"],
	&"agachar": ["a:4+"],
	&"veiculo": ["a:5+"],
	&"correr": ["b:7"],
	&"alternar_camera": ["b:8"],
	&"inventario": ["b:4"],
}

## Quem esta no comando agora. Muda com a ultima entrada recebida, e e o que a
## interface le para escrever "[A]" ou "[E]" na dica certa.
enum Dispositivo { TECLADO, CONTROLE }

signal dispositivo_mudou(qual: Dispositivo)

var dispositivo: Dispositivo = Dispositivo.TECLADO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	registrar_acoes()


## Acrescenta as ligacoes de joypad ao `InputMap`. Idempotente: rodar duas vezes
## nao duplica evento, porque `action_has_event` compara pelo conteudo.
static func registrar_acoes() -> int:
	var novas := 0
	for acao: StringName in LIGACOES:
		if not InputMap.has_action(acao):
			continue
		for codigo: String in LIGACOES[acao]:
			var ev := evento_de(codigo)
			if ev == null or InputMap.action_has_event(acao, ev):
				continue
			InputMap.action_add_event(acao, ev)
			novas += 1
	return novas


## Traduz "b:0" / "a:1-" num evento de joypad.
static func evento_de(codigo: String) -> InputEvent:
	var partes := codigo.split(":")
	if partes.size() != 2:
		return null
	if partes[0] == "b":
		var b := InputEventJoypadButton.new()
		b.button_index = partes[1].to_int() as JoyButton
		b.device = -1
		return b
	if partes[0] == "a":
		var corpo := partes[1]
		var m := InputEventJoypadMotion.new()
		m.axis = corpo.substr(0, corpo.length() - 1).to_int() as JoyAxis
		m.axis_value = -1.0 if corpo.ends_with("-") else 1.0
		m.device = -1
		return m
	return null


## O eixo depois da zona morta e da curva, de -1 a 1.
static func tratar_eixo(v: float) -> float:
	var a := absf(v)
	if a <= ZONA_MORTA:
		return 0.0
	var t := (a - ZONA_MORTA) / (1.0 - ZONA_MORTA)
	return signf(v) * pow(clampf(t, 0.0, 1.0), CURVA)


func _input(evento: InputEvent) -> void:
	var qual := dispositivo
	if evento is InputEventJoypadButton:
		qual = Dispositivo.CONTROLE
	elif evento is InputEventJoypadMotion:
		if absf((evento as InputEventJoypadMotion).axis_value) > ZONA_MORTA:
			qual = Dispositivo.CONTROLE
	elif evento is InputEventKey:
		qual = Dispositivo.TECLADO
	elif evento is InputEventMouseButton:
		qual = Dispositivo.TECLADO
	if qual != dispositivo:
		dispositivo = qual
		dispositivo_mudou.emit(qual)


func _process(delta: float) -> void:
	# So vira olhar quando o mouse esta preso — ou seja, em jogo. Nos menus o
	# cursor esta solto, e ali o analogico direito nao tem o que fazer: quem
	# navega e o esquerdo e o direcional, pelas acoes.
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var eixo := Vector2(
		tratar_eixo(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)),
		tratar_eixo(Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)))
	if eixo == Vector2.ZERO:
		return
	var mm := InputEventMouseMotion.new()
	mm.relative = eixo * OLHAR_PX_S * delta
	Input.parse_input_event(mm)
