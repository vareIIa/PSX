## A cabine do carro que o JOGADOR dirige — e so dele.
##
## Por que isto existe
## -------------------
## Ate aqui so o carro da cutscene tinha interior. O `Carro` da cidade e um
## casco fechado com as faces viradas para fora, e a camera de dirigir foi
## forcada para fora dele por um motivo registrado em `CameraRig`: com o braco em
## zero, a primeira pessoa ficava DENTRO de um casco sem interior e o carro
## sumia da propria imagem. Primeira pessoa ao volante nao era um modo, era um
## buraco.
##
## Este no monta, no carro que o jogador assumiu, a mesma cabine da cutscene —
## casca, porta, painel, vidro com o mapa de agua, corredoras, limpador e o teto
## que tira a chuva de dentro — e desmonta quando ele desce. So o carro do
## jogador paga isso: os carros do transito continuam sendo o casco barato.
##
## Por que um no a parte, e nao linhas no `Carro`
## ----------------------------------------------
## `carro.gd` e `camera_rig.gd` estavam, em 16/09/2026, com centenas de linhas
## nao commitadas de outra sessao. O `Carro` so chama `montar` e `desmontar`;
## todo o resto mora aqui. A vista de dentro e uma camera PROPRIA, e nao o braco
## do `CameraRig` em zero: assim a camera de fora continua sendo a de fora, com
## as duas distancias que ela ja tem, e a de dentro nao depende de o braco saber
## que existe cabine.
##
## A tecla de camera
## -----------------
## Ao volante ela passa a girar entre TRES: longe, perto e dentro. O braco so
## conhece duas (ele alterna a cada toque), entao este no ouve o mesmo sinal que
## o jogador emite (`camera_alternada`), guarda em que estado o braco ficou e,
## quando o ciclo de tres pede outra coisa, alterna o braco mais uma vez. O braco
## e achado pelo TIPO e nao pelo nome — ver a memoria "get_node por nome falha".
class_name CabineDoJogador
extends Node3D

enum Vista {LONGE, PERTO, DENTRO}

## Campo de visao de dentro, igual ao do plano de dentro da cutscene: e nele que
## a cabine e a agua do vidro foram calibradas.
const FOV_DENTRO := 74.0
## Inclinacao da cabeca quando nao ha pivo de jogador para copiar, em graus. E a
## do plano de dentro da cutscene.
const PITCH_DENTRO := -4.0

## Filtro da aceleracao que a agua do vidro sente, por segundo.
##
## A aceleracao sai da derivada da velocidade do corpo rigido, e a derivada de um
## `VehicleBody3D` e ruidosa: cada quique de suspensao e um pico de dezenas de
## m/s^2 num quadro. Sem filtro, a agua do vidro tremeria a cada lombada.
const FILTRO_ACEL := 6.0
## Teto da aceleracao, em m/s^2. Uma batida da centenas num quadro; a agua nao
## pode ser jogada para fora do vidro por isso.
const ACEL_MAX := 14.0

## `--camera-dentro`: comeca na vista de dentro. E como a captura fotografa a
## primeira pessoa sem apertar tecla.
const FLAG_DENTRO := "--camera-dentro"

## `--olhar=GUINADA,ARFAGEM`, em graus: segura o olhar livre (A24) nesse angulo
## a cada quadro. E como a captura fotografa a camera girada sem mouse — e sem
## a volta ao centro, que numa captura andando a traria de volta antes da foto.
const FLAG_OLHAR := "--olhar="

## `--sem-cabine-jogador`: o no existe, mas nao monta cabine nenhuma. E o lado B
## de qualquer comparacao — desempenho, ou um defeito que aparece dirigindo e
## precisa ser separado deste trabalho.
const FLAG_SEM_CABINE := "--sem-cabine-jogador"

## `--cacar-nan`: vigia, a cada passo de fisica, se algum carro ou o jogador
## deixou de ser finito, e imprime o PRIMEIRO quadro em que isso aconteceu.
##
## Existe porque em 16/09/2026 uma captura travou com o velocimetro marcando
## -9223372036854775808 (um NaN convertido para inteiro): a posicao do carro
## tinha virado NaN, a cidade descarregou inteira e a tela ficou preta. Os
## avisos de `Vector3 cannot be normalized` que vinham antes sao SINTOMA — quem
## normaliza (`Carro._arrastar`, a deriva da chuva) so recebe o NaN pronto.
const FLAG_NAN := "--cacar-nan"

## A luz do painel: onde ela fica em relacao ao olho, e quanto ela acende.
##
## Sem ela, a noite, a cabine do carro da cidade saiu PRETA na primeira captura —
## volante, porta e painel sumiam, e sobrava o vidro com agua flutuando no
## escuro. O carro da cutscene sempre teve esse preenchimento (`LuzCabine` em
## `CarroCena`); este e o mesmo papel, com a cor ambar de mostrador aceso e
## acesa so na vista de dentro, para nao pintar o banco visto de fora.
##
## Com 0,45 de energia e 1,7 m de alcance ela alcancava o forro do teto, que saia
## laranja no canto do quadro como se houvesse uma lampada ali: baixa e curta, ela
## pega volante, painel e porta e para antes do teto.
const LUZ_PAINEL_DO_OLHO := Vector3(0.05, -0.34, -0.42)
const LUZ_PAINEL_ENERGIA := 0.32
const LUZ_PAINEL_ALCANCE := 1.35
const LUZ_PAINEL_COR := Color(1.0, 0.80, 0.55)

## Luz de teto: acima da cabeca, um palmo para tras do olho, com a cor morna de
## lampada de 5 W. Acende em um quarto de segundo, fica o tempo de a porta
## fechar e de o motorista se ajeitar, e apaga em fade como a de verdade.
const LUZ_TETO_ALTURA := 0.22
const LUZ_TETO_RECUO := 0.28
const LUZ_TETO_ALCANCE := 1.7
const LUZ_TETO_ENERGIA := 0.9
const LUZ_TETO_COR := Color(1.0, 0.86, 0.62)
const LUZ_TETO_ACENDE := 0.25
const LUZ_TETO_FICA := 4.0
const LUZ_TETO_APAGA := 1.5

var carro: VehicleBody3D
var cabine: CarroCabine
var vista: Vista = Vista.LONGE

var _camera: Camera3D
var _camera_de_fora: Camera3D
var _luz_painel: OmniLight3D
var _luz_teto: OmniLight3D
var _jogador: Node
var _braco: SpringArm3D
var _braco_perto: bool = false
## A cabeca do jogador e a camera dele, para a de dentro sentir o mesmo carro.
var _pivo: Node3D
var _camera_do_jogador: Camera3D
var _fov_do_jogador_parado: float = 0.0
var _vel_antes := Vector3.INF
var _acel := Vector3.ZERO
## As maos no volante e o santinho do retrovisor, da cena da estrada
## (PLANO_CARROS_AAA, F11). So aparecem na vista de dentro: de fora, o jogador
## nao tem corpo sentado, e duas maos no aro sem ninguem atras delas assustam.
var _maos: MotoristaCena
var _cacar := false
## Olhar segurado por `--olhar=`, em graus. Infinito quando nao ha flag.
var _olhar_fixo := Vector2.INF
var _vistos := {}
var _quadro := 0
## O ultimo estado finito do carro do jogador, para o relatorio do NaN.
var _ultimo_ok := {}


## Monta a cabine no carro. `quem` e o jogador que assumiu.
static func montar(dono: VehicleBody3D, medidas: Dictionary, quem: Node) -> CabineDoJogador:
	# Antes de qualquer coisa: o carro tomado nao pode chegar podre. Ver `sanear`.
	sanear(dono)
	var c := CabineDoJogador.new()
	c.name = "CabineDoJogador"
	c.carro = dono
	c._jogador = quem
	dono.add_child(c)
	c._montar(medidas)
	return c


## Tira NaN do corpo de um carro que o jogador acabou de tomar. Devolve se
## havia o que tirar.
##
## O defeito que isto segura (medido em 16/09/2026)
## ------------------------------------------------
## Um carro do TRANSITO, congelado e movido pela IA, pode ficar com estado nao
## finito no servidor de fisica sem que nada na tela mostre: o no continua com
## a transformada certa, e o unico sinal sao avisos de `Vector3 cannot be
## normalized` (uns quatro por quadro) — que aparecem ate com o jogador a pe e
## sem cabine nenhuma montada. Quando o jogador toma esse carro e ele e
## destravado, o NaN entra na integracao: na captura, a velocidade angular ja era
## NaN no segundo passo de fisica, a posicao no sexagesimo, a cidade
## descarregou, o velocimetro marcou -9223372036854775808 e a janela travou.
##
## A origem esta no transito, e nao foi reproduzida numa bancada minima
## (`tests/spike_roda_sobre_congelado.gd`: bater num congelado, subir num
## congelado e andar cinematico ficam finitos). Ate ela ser achada, a tomada do
## carro nao pode herdar o estado: velocidades nao finitas viram zero e a
## transformada do servidor volta a ser a do no, que e a que a tela mostra.
static func sanear(corpo: RigidBody3D) -> bool:
	if corpo == null or not is_instance_valid(corpo):
		return false
	# Do SERVIDOR, e nao das propriedades do no: num corpo congelado o no guarda
	# o ultimo valor que o script escreveu, e o NaN mora no servidor. Lido pelo
	# no, o carro podre passava por sao.
	var e := estado(corpo)
	var x_no := corpo.global_transform
	var sujo: bool = not ((e["vel"] as Vector3).is_finite() and (e["giro"] as Vector3).is_finite()
		and _finita(e["x"]) and corpo.linear_velocity.is_finite()
		and corpo.angular_velocity.is_finite())
	if not sujo:
		return false
	print("[cabine] carro tomado com estado nao finito: vel=%s giro=%s servidor=%s no=%s"
		% [e["vel"], e["giro"], (e["x"] as Transform3D).origin, x_no.origin])
	for no: Node in corpo.get_children():
		var r := no as VehicleWheel3D
		if r != null:
			print("[cabine]   roda %s: pos=%s rpm=%s escorrega=%s contato=%s"
				% [r.name, r.global_position, r.get_rpm(), r.get_skidinfo(),
					r.is_in_contact()])
	var rid := corpo.get_rid()
	if _finita(x_no):
		PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, x_no)
	var vel: Vector3 = e["vel"]
	if not (vel.is_finite() and corpo.linear_velocity.is_finite()):
		vel = Vector3.ZERO
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, vel)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY,
		Vector3.ZERO)
	corpo.linear_velocity = vel
	corpo.angular_velocity = Vector3.ZERO
	return true


## Transformada e velocidades do corpo, lidas no servidor de fisica.
static func estado(corpo: RigidBody3D) -> Dictionary:
	var rid := corpo.get_rid()
	return {
		"x": PhysicsServer3D.body_get_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM),
		"vel": PhysicsServer3D.body_get_state(rid,
			PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY),
		"giro": PhysicsServer3D.body_get_state(rid,
			PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY),
	}


static func _finita(x: Transform3D) -> bool:
	return x.origin.is_finite() and x.basis.x.is_finite() 		and x.basis.y.is_finite() and x.basis.z.is_finite()


## Desmonta. Aceita nulo: quem chama nao precisa saber se havia cabine.
static func desmontar(c: CabineDoJogador) -> void:
	if c == null or not is_instance_valid(c):
		return
	c._devolver_camera()
	c.queue_free()


func _montar(medidas: Dictionary) -> void:
	var args := OS.get_cmdline_user_args()
	_cacar = args.has(FLAG_NAN)
	if args.has(FLAG_SEM_CABINE):
		print("[cabine] %s: sem cabine neste carro" % FLAG_SEM_CABINE)
		return
	# No espaco do CARRO: a lataria do `Carro` tambem mora na origem dele, com a
	# frente em -Z, que e o espaco da cabine.
	cabine = CarroCabine.new()
	cabine.name = "Cabine"
	# O interior nasce fora da thread principal: o jogador entra com a camera de
	# fora, e a primeira construcao do painel custava um tranco de ~100 ms.
	cabine.interior_assincrono = true
	add_child(cabine)
	cabine.montar(medidas)
	var it := cabine.interior()
	if it != null:
		it.montado.connect(_ao_montar_interior, CONNECT_ONE_SHOT)
		if it.pronto():
			_ao_montar_interior()

	_camera = Camera3D.new()
	_camera.name = "CameraDeDentro"
	_camera.fov = FOV_DENTRO
	_camera.near = 0.02
	# Pendurada na cabine: a cabeca balanca com a suspensao, porque o corpo
	# rigido inteiro balanca.
	_camera.position = cabine.olho()
	cabine.add_child(_camera)

	_luz_painel = OmniLight3D.new()
	_luz_painel.name = "LuzDoPainel"
	_luz_painel.position = cabine.olho() + LUZ_PAINEL_DO_OLHO
	_luz_painel.omni_range = LUZ_PAINEL_ALCANCE
	_luz_painel.light_energy = LUZ_PAINEL_ENERGIA
	_luz_painel.light_color = LUZ_PAINEL_COR
	_luz_painel.shadow_enabled = false
	_luz_painel.visible = false
	cabine.add_child(_luz_painel)

	_montar_luz_de_teto()

	_maos = MotoristaCena.new()
	_maos.name = "Maos"
	cabine.add_child(_maos)
	_maos.montar_na_cabine(cabine)
	_maos.visible = false

	_camera.rotation_degrees.x = PITCH_DENTRO
	_braco = _achar_braco(_jogador)
	if _braco != null:
		# O braco mora no pivo da cabeca (ver `CameraRig._ready`), e a camera
		# do jogador mora no braco.
		_pivo = _braco.get_parent() as Node3D
		for no: Node in _braco.find_children("*", "Camera3D", true, false):
			_camera_do_jogador = no as Camera3D
		if _camera_do_jogador != null:
			_fov_do_jogador_parado = _camera_do_jogador.fov
	if _jogador != null and _jogador.has_signal(&"camera_alternada"):
		_jogador.connect(&"camera_alternada", _ao_alternar_camera)
	if OS.get_cmdline_user_args().has(FLAG_DENTRO):
		_ir_para(Vista.DENTRO)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(FLAG_OLHAR):
			var partes := arg.trim_prefix(FLAG_OLHAR).split(",")
			if partes.size() == 2:
				_olhar_fixo = Vector2(partes[0].to_float(), partes[1].to_float())


## A luz de teto acende quando se entra e apaga devagar depois (A22).
##
## E a lampada que qualquer carro tem e este nao tinha: a porta abre, o teto
## acende, e ela se apaga em fade alguns segundos depois de a porta fechar. A
## noite e o unico momento em que o jogador ve o proprio interior inteiro antes
## de a rua voltar a ser so o que o farol alcanca.
##
## Pendurada na cabine, no teto entre os dois bancos. Sem sombra: a cabine e uma
## casca fina, e sombra de lampada a vinte centimetros do forro so marcaria as
## costuras da malha.
func _montar_luz_de_teto() -> void:
	_luz_teto = OmniLight3D.new()
	_luz_teto.name = "LuzDeTeto"
	var olho := cabine.olho()
	_luz_teto.position = Vector3(0.0, olho.y + LUZ_TETO_ALTURA, olho.z + LUZ_TETO_RECUO)
	_luz_teto.omni_range = LUZ_TETO_ALCANCE
	_luz_teto.light_color = LUZ_TETO_COR
	_luz_teto.light_energy = 0.0
	_luz_teto.shadow_enabled = false
	cabine.add_child(_luz_teto)
	var t := create_tween()
	t.tween_property(_luz_teto, "light_energy", LUZ_TETO_ENERGIA, LUZ_TETO_ACENDE)
	t.tween_interval(LUZ_TETO_FICA)
	t.tween_property(_luz_teto, "light_energy", 0.0, LUZ_TETO_APAGA)
	t.tween_callback(func() -> void: _luz_teto.visible = false)


## Brilho atual da luz de teto. Zero quando apagada.
func luz_de_teto() -> float:
	if _luz_teto == null or not _luz_teto.visible:
		return 0.0
	return _luz_teto.light_energy


func _exit_tree() -> void:
	if _camera == null:
		return
	_devolver_camera()
	if _jogador != null and is_instance_valid(_jogador) \
			and _jogador.has_signal(&"camera_alternada") \
			and _jogador.is_connected(&"camera_alternada", _ao_alternar_camera):
		_jogador.disconnect(&"camera_alternada", _ao_alternar_camera)


func _physics_process(delta: float) -> void:
	_quadro += 1
	if _olhar_fixo.is_finite():
		var o := _olhar()
		if o != null:
			o.set(&"guinada", deg_to_rad(_olhar_fixo.x))
			o.set(&"arfagem", deg_to_rad(_olhar_fixo.y))
			# Um movimento nulo zera o relogio da volta ao centro.
			o.call(&"mover", Vector2.ZERO, 0.0)
	if _cacar:
		_vigiar_nan()
	if carro == null or not is_instance_valid(carro) or cabine == null:
		return
	var v_mundo := carro.linear_velocity
	# Carro nao finito: nada entra na agua do vidro. O NaN nao nasce aqui, mas
	# tambem nao pode passar por aqui — no mapa de agua ele viraria um vidro
	# inteiro preto ate a cabine ser remontada.
	if not (carro.global_transform.origin.is_finite() and v_mundo.is_finite()
			and carro.global_transform.basis.x.is_finite()):
		return
	var base := carro.global_transform.basis.orthonormalized()
	# A aceleracao PROPRIA no referencial do carro: derivada no mundo, girada
	# depois. Derivar a velocidade ja girada perderia a centripeta, e e ela que
	# joga a agua para o lado na curva.
	if not _vel_antes.is_finite():
		_vel_antes = v_mundo
	var a_mundo := (v_mundo - _vel_antes) / maxf(delta, 1e-4)
	_vel_antes = v_mundo
	var a_local := (base.inverse() * a_mundo).limit_length(ACEL_MAX)
	_acel = _acel.lerp(a_local, 1.0 - exp(-FILTRO_ACEL * delta))
	var v_local := base.inverse() * v_mundo

	cabine.atualizar_clima(_chuva_agora(), v_local, _acel, delta)
	cabine.marcar(v_local.length() * 3.6)
	cabine.estercar(clampf(carro.steering / 0.52, -1.0, 1.0))
	_alimentar_painel()
	if _maos != null:
		# Arfar e rolar do corpo rigido, no sentido que o pendulo espera: a
		# componente da gravidade no referencial do carro e G vezes o seno deles.
		var incl := Vector2(asin(clampf(-base.z.y, -1.0, 1.0)),
			asin(clampf(-base.x.y, -1.0, 1.0)))
		_maos.atualizar(_acel, incl, delta)


## Os instrumentos do interior: giro, marcha, freio de mao, setas, a luz do
## painel com o farol, e o visor do toca-fitas — a estacao do `RadioCarro`, ou a
## hora com o radio desligado. Tudo o que o carro ja expoe para o painel da HUD.
##
## Pelo nome dos metodos, e nao pelo tipo: tipar `Carro` aqui faria esta classe
## puxar o `Carro` e os autoloads dele, e ela deixaria de compilar em `--script`
## (`checar_cabine_jogador` monta a cabine num carro dublê).
func _alimentar_painel() -> void:
	var it := cabine.interior()
	if it == null or not carro.has_method(&"rotulo_marcha"):
		return
	var ligado := bool(carro.get(&"ligado"))
	it.giro(float(carro.call(&"giro")) if ligado else 0.0)
	it.marcha(String(carro.call(&"rotulo_marcha")) if ligado else "N")
	it.motor_ligado(ligado)
	it.freio_de_mao(bool(carro.call(&"freio_de_mao")))
	it.seta(int(carro.call(&"seta")), bool(carro.call(&"seta_acesa")))
	it.acender_painel(1.0 if int(carro.call(&"fachos_acesos")) > 0 else 0.0)
	var radio := get_node_or_null(^"/root/RadioCarro")
	var indice := int(radio.call(&"estacao")) if radio != null else -1
	if indice >= 0:
		var estacoes: Array = radio.get_script().get_script_constant_map().get(
			"ESTACOES", [])
		if indice < estacoes.size():
			it.visor_estacao(String((estacoes[indice] as Dictionary)["dial"]))
			return
	var ws := get_node_or_null(^"/root/WorldState")
	var rel := ws.get(&"relogio") as Relogio if ws != null else null
	if rel != null:
		var m := rel.minutos()
		it.visor_relogio(m / 60, m % 60)


## O interior terminou de nascer (ver `CabineInterior.montar`): as batidas que
## a lataria ja levou entram nos forros de porta. O `Carro` reaplica as dele na
## hora de assumir, mas nessa hora as portas ainda nao existiam.
##
## Pelo nome do metodo, como `_alimentar_painel`: tipar `Carro` quebraria esta
## classe em `--script`.
func _ao_montar_interior() -> void:
	if carro == null or not is_instance_valid(carro) or cabine == null:
		return
	if not carro.has_method(&"amassado"):
		return
	var am: Object = carro.call(&"amassado")
	var pecas := cabine.interior().portas()
	if am != null and not pecas.is_empty():
		am.call(&"reaplicar", carro, pecas)


## A cabeca de dentro sente o mesmo carro que a de fora.
##
## `Player._camera_de_volante` ja faz a cabeca inclinar na curva, tremer em alta
## velocidade e dar tranco na batida, tudo no PIVO — e abre o campo de visao com
## a velocidade. A camera de dentro copia a orientacao desse pivo e o GANHO de
## campo de visao, em vez de repetir as contas: com contas repetidas as duas
## cameras divergiriam no primeiro ajuste. A posicao continua sendo o olho da
## cabine, que e o que o pivo nao sabe.
func _process(_delta: float) -> void:
	if _maos != null:
		_maos.visible = vista == Vista.DENTRO
	if vista != Vista.DENTRO or _camera == null or not _camera.current:
		return
	if _pivo != null and is_instance_valid(_pivo):
		# O giro da cabeca (A24) entra ENTRE o rumo do corpo e a inclinacao do
		# pivo: girar depois da inclinacao faria a cabeca virar em torno de um
		# eixo torto, e olhar para o lado numa curva sairia torto.
		var g := 0.0
		var a := 0.0
		var o := _olhar()
		if o != null:
			g = float(o.get(&"guinada"))
			a = float(o.get(&"arfagem"))
		# Pelas bases INTERPOLADAS (`Suavidade`): o carro e o jogador ao volante
		# andam a cada quadro desenhado, e a camera, presa ao carro, e posta em
		# relacao ao pai como ele sai na tela. Pela base do passo de fisica o giro
		# da cabeca tremia nas curvas. Sem interpolacao, e a mesma conta de antes.
		var corpo := Suavidade.global(_pivo.get_parent() as Node3D).basis
		var desejada := corpo * Basis.from_euler(
			Vector3(_pivo.rotation.x + a, g, _pivo.rotation.z))
		var pai := Suavidade.global(_camera.get_parent_node_3d()).basis
		_camera.basis = pai.inverse() * desejada
	if _camera_do_jogador != null and is_instance_valid(_camera_do_jogador):
		_camera.fov = FOV_DENTRO + maxf(0.0,
			_camera_do_jogador.fov - _fov_do_jogador_parado)


## O primeiro quadro em que algum carro, ou o jogador, deixa de ser finito.
func _vigiar_nan() -> void:
	if carro != null and is_instance_valid(carro):
		var x := carro.global_transform
		if x.origin.is_finite() and carro.linear_velocity.is_finite():
			_ultimo_ok = {
				"quadro": _quadro, "pos": x.origin, "vel": carro.linear_velocity,
				"giro": carro.angular_velocity, "forca": carro.engine_force,
				"freio": carro.brake, "esterco": carro.steering,
			}
	for no: Node in get_tree().get_nodes_in_group(&"carro"):
		var c := no as RigidBody3D
		if c == null or _vistos.has(c.get_instance_id()):
			continue
		var e := estado(c)
		var p := c.global_transform.origin
		var v := c.linear_velocity
		if p.is_finite() and v.is_finite() and c.angular_velocity.is_finite() 				and _finita(e["x"]) and (e["vel"] as Vector3).is_finite() 				and (e["giro"] as Vector3).is_finite():
			continue
		_vistos[c.get_instance_id()] = true
		print("[nan] quadro=%d carro=%s do_jogador=%s congelado=%s no: pos=%s vel=%s giro=%s | servidor: pos=%s vel=%s giro=%s | motorista=%s"
			% [_quadro, c.name, c == carro, c.freeze, p, v, c.angular_velocity,
				(e["x"] as Transform3D).origin, e["vel"], e["giro"],
				c.get(&"motorista")])
		if c == carro:
			print("[nan] ultimo estado finito do carro do jogador: %s" % _ultimo_ok)
			for r: Node in c.get_children():
				if r is VehicleWheel3D:
					print("[nan]   roda %s: pos=%s rpm=%s escorrega=%s contato=%s"
						% [r.name, (r as VehicleWheel3D).global_position,
							(r as VehicleWheel3D).get_rpm(),
							(r as VehicleWheel3D).get_skidinfo(),
							(r as VehicleWheel3D).is_in_contact()])
	if _jogador != null and is_instance_valid(_jogador) and _jogador is Node3D 			and not _vistos.has(-1):
		var pj := (_jogador as Node3D).global_position
		if not pj.is_finite():
			_vistos[-1] = true
			print("[nan] quadro=%d jogador pos=%s" % [_quadro, pj])


## Esta chovendo agora? Lido pelo caminho longo: `Clima` e autoload, e uma
## referencia direta impediria esta classe de compilar em `--script`.
func _chuva_agora() -> float:
	var clima := get_node_or_null(^"/root/Clima")
	if clima == null:
		return 0.0
	return clampf(float(clima.get(&"chuva")), 0.0, 1.0)


## A tecla de camera foi apertada. O braco ja alternou; aqui se decide o resto.
func _ao_alternar_camera(_terceira: bool) -> void:
	_braco_perto = not _braco_perto
	# `match`, e nao `(int(vista) + 1) % 3 as Vista`: `as` para enum devolve
	# nulo em silencio. Ver a memoria "armadilhas mudas do Godot".
	var proxima := Vista.LONGE
	match vista:
		Vista.LONGE:
			proxima = Vista.PERTO
		Vista.PERTO:
			proxima = Vista.DENTRO
	_ir_para(proxima)


func _ir_para(nova: Vista) -> void:
	vista = nova
	# O olhar livre troca de limite com a vista, e volta para a frente.
	var o := _olhar()
	if o != null:
		o.call(&"definir_dentro", nova == Vista.DENTRO)
	# O braco segue o ciclo de tres: perto na vista PERTO, longe na LONGE. Na de
	# dentro ele pode ficar como estiver — nao e ele que se ve.
	if nova != Vista.DENTRO and _braco != null and _braco.has_method(&"alternar"):
		var quer_perto := nova == Vista.PERTO
		if quer_perto != _braco_perto:
			_braco.call(&"alternar")
			_braco_perto = quer_perto
	if nova == Vista.DENTRO:
		_usar_camera_de_dentro()
	else:
		_devolver_camera()
	_abafar_chuva(nova == Vista.DENTRO)


func _usar_camera_de_dentro() -> void:
	if _camera == null or not _camera.is_inside_tree():
		return
	var atual := get_viewport().get_camera_3d()
	if atual != _camera:
		_camera_de_fora = atual
	_camera.make_current()
	_luz_painel.visible = true


func _devolver_camera() -> void:
	if _luz_painel != null:
		_luz_painel.visible = false
	if _camera == null or not _camera.current:
		return
	_camera.clear_current(false)
	if _camera_de_fora != null and is_instance_valid(_camera_de_fora) \
			and _camera_de_fora.is_inside_tree():
		_camera_de_fora.make_current()
	_abafar_chuva(false)


## Dentro do carro a chuva e ouvida atraves da lataria. `abrigo` e da `Chuva`;
## escrito pelo nome da propriedade para nao amarrar esta classe a ela.
func _abafar_chuva(dentro: bool) -> void:
	if not is_inside_tree():
		return
	for no: Node in get_tree().get_nodes_in_group(&"chuva"):
		if &"abrigo" in no:
			no.set(&"abrigo", 1.0 if dentro else 0.0)


## O olhar livre do jogador (`OlharAoVolante`), lido pelo nome da propriedade
## para esta classe nao depender de `Player`.
func _olhar() -> RefCounted:
	if _jogador == null or not is_instance_valid(_jogador) or not (&"olhar" in _jogador):
		return null
	return _jogador.get(&"olhar") as RefCounted


## O `CameraRig` do jogador, achado pelo tipo.
static func _achar_braco(quem: Node) -> SpringArm3D:
	if quem == null:
		return null
	for no: Node in quem.find_children("*", "SpringArm3D", true, false):
		if no.has_method(&"seguir_veiculo"):
			return no as SpringArm3D
	return null
