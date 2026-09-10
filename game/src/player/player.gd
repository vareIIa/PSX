## Jogador. Primeira pessoa por padrao, `V` alterna para terceira pessoa.
##
## O yaw fica no corpo e o pitch no pivo da cabeca. Nos dois modos o corpo aponta
## para onde a camera olha, que e o esquema das referencias de terceira pessoa: a
## camera nao orbita livre em volta de um personagem parado.
##
## Velocidade deliberadamente baixa. Survival horror anda devagar porque a tensao
## vem de nao poder simplesmente sair correndo, e correr custa folego.
class_name Player
extends CharacterBody3D

# --- medidas, em metros e m/s -----------------------------------------------
const ALTURA := 1.75
const ALTURA_AGACHADO := 1.05
const RAIO := 0.32
const ALTURA_OLHO := 1.62
const ALTURA_OLHO_AGACHADO := 0.92

const VEL_ANDAR := 2.4
const VEL_CORRER := 4.6
const VEL_AGACHADO := 1.2
const ACELERACAO := 11.0
const DESACELERACAO := 15.0

## Folego em segundos de corrida contínua, e o tempo para recuperar tudo.
const FOLEGO_MAX := 6.0
const FOLEGO_RECUPERA := 4.0

const SENSIBILIDADE := 0.0024
const PITCH_MIN := -1.45
const PITCH_MAX := 1.35

# Bob preso a distancia percorrida, nao a tempo. Preso a tempo ele continua
# balancando quando o jogador anda contra a parede.
const BOB_FREQ := 2.05
const BOB_AMP := 0.035
const BOB_ROLL := 0.011

# --- resposta de camera -----------------------------------------------------
## Quanto a cabeca afunda ao aterrissar, por m/s de queda. Curto e forte le como
## peso; longo e suave le como elevador.
const IMPACTO_POR_VELOCIDADE := 0.022
const IMPACTO_MAXIMO := 0.16
const IMPACTO_RECUPERA := 7.0

## Inclinacao lateral ao andar de lado. Poucos graus: muito vira enjoo.
const INCLINACAO_LATERAL := 0.035
## Campo de visao parado e correndo. A diferenca sozinha ja comunica pressa.
const FOV_BASE := 66.0
const FOV_CORRIDA := 72.0

@onready var _pivo: Node3D = $Pivo
@onready var _braco: CameraRig = $Pivo/Braco
@onready var _corpo: Node3D = $Corpo
@onready var _colisao: CollisionShape3D = $Colisao

var _figura: Corpo
var _impacto: float = 0.0
var _inclinacao: float = 0.0
var _estava_no_chao: bool = true
var _camera: Camera3D

## Emitido a cada passo completo. A Fase 5 pendura o som de passo aqui.
signal passo_dado(velocidade: float)
## Emitido quando o jogador troca de camera.
signal camera_alternada(terceira_pessoa: bool)
## Emitido quando o alvo de interacao muda. Rotulo vazio significa nenhum alvo.
signal alvo_de_interacao(rotulo: String)

var folego: float = FOLEGO_MAX
var _pitch: float = 0.0
var _distancia: float = 0.0
var _fase_bob: int = 0
var _agachado: bool = false
var _gravidade: float = 9.8
## Entrada simulada. Usada so pela verificacao automatizada de movimento.
var _auto: Vector2 = Vector2.ZERO

## Alcance da interacao, em metros. Braco esticado, nao teleporte.
const ALCANCE_INTERACAO := 2.4

var _alvo: Interativo
var _rotulo_alvo: String = ""
var _raio: RayCast3D

## Travado nao anda, nao olha e nao aciona nada. Serve a caixa de fala, que
## precisa prender o jogador sem pausar a arvore: pausar congelaria o personagem
## com quem ele esta falando no meio da propria fala.
var travado: bool = false
## FOV travado pela abertura CRT. Negativo libera o lerp normal.
var fov_override: float = -1.0

# --- lanterna ---------------------------------------------------------------
## Autonomia da bateria cheia, em segundos de uso continuo. Curta de proposito:
## e o recurso que faz o jogador escolher entre enxergar e economizar.
const BATERIA_SEGUNDOS := 330.0
## Abaixo disso a luz comeca a falhar, avisando antes de acabar.
const BATERIA_FRACA := 0.16

var lanterna_ligada: bool = false
var bateria: float = 1.0
var _lanterna: SpotLight3D

## Radio de chiado. Filho do jogador porque a proximidade e medida dele.
var radio: Radio
var _auto_correr: bool = false
## Ver `--atravessar` em _ready. So execucao automatizada liga.
var _atravessar: bool = false

# --- volante ----------------------------------------------------------------
## A que distancia da lataria a tecla de entrar responde.
const ALCANCE_VEICULO := 3.2

## O carro em que o jogador esta. Nulo significa a pe, e e o unico teste que o
## resto do arquivo precisa fazer.
var _carro: Carro
## Onde a camera fica ao dirigir, contado do centro do carro.
const CAMERA_NO_CARRO := Vector3(0.0, 0.62, 0.14)

## A bicicleta em que o jogador esta, pelo mesmo desenho do carro: nulo
## significa que ele nao esta em cima de nenhuma.
##
## Sao duas variaveis e nao uma porque os dois veiculos nao tem nada em comum
## alem da tecla. Um e corpo rigido com motor e radio, o outro e cinematico, tem
## campainha e nao tem porta. Uma variavel `veiculo` generica obrigaria todo uso
## a perguntar de que tipo ela e — que e o mesmo `if` de agora, escondido.
var _bike: Bicicleta
## A que distancia da bicicleta a tecla de subir responde. Menor que a do carro:
## a bicicleta e menor e fica encostada em parede, onde ha coisa perto.
const ALCANCE_BICICLETA := 2.3
## Altura do olho de quem esta sentado no selim. Mais baixa que a de pe, porque
## e disso que a bicicleta muda a rua.
const OLHO_NA_BICICLETA := 1.34


func _ready() -> void:
	add_to_group(&"player")
	_gravidade = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	_montar_colisao()
	_montar_corpo()
	_montar_raio()
	_camera = _braco.get_node_or_null("Camera") as Camera3D
	_montar_lanterna()
	_montar_radio()
	passo_dado.connect(_ao_dar_passo)
	# Numa execucao de captura a janela vive 40 frames; sequestrar o mouse ali
	# so atrapalha quem esta usando a maquina.
	if not _em_captura():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Permite a captura automatizada verificar a terceira pessoa sem simular tecla.
	if OS.get_cmdline_user_args().has("--tp"):
		_alternar_camera()

	# Anda sozinho para a frente. E como a captura verifica que o controlador
	# move de verdade, em vez de so compilar.
	if OS.get_cmdline_user_args().has("--auto-walk"):
		_auto = Vector2(0.0, -1.0)
	# Correndo o jogador cobre o dobro do chao no mesmo tempo, o que e um teste
	# mais duro para o streaming, nao mais facil.
	if OS.get_cmdline_user_args().has("--auto-run"):
		_auto = Vector2(0.0, -1.0)
		_auto_correr = true
	# Corredor fantasma: nao e empurrado nem prensado por carro, pedestre ou
	# mobiliario. Existe para a medicao de streaming e para nada mais.
	#
	# A cidade continua inteira em volta — multidao, transito e blitz seguem
	# nascendo e desenhando, que e a carga que aquele teste precisa medir. O que
	# sai e so a colisao com eles, porque um corredor prensado contra uma lataria
	# para de andar, e quem nao anda nao carrega chunk nenhum: a medida virava
	# "62 m em 50 s" e acusava engasgo de carga num percurso que nunca aconteceu.
	# Ser atropelado e comportamento certo do jogo; so nao e o que se mede ali.
	_atravessar = OS.get_cmdline_user_args().has("--atravessar")


## Esta execucao e automatizada?
##
## Sequestrar o mouse numa execucao dessas e um defeito de medida, nao um
## detalhe: com o ponteiro preso, qualquer movimento do mouse da maquina gira o
## jogador. Foi o que aconteceu com a verificacao de streaming — o corredor
## automatico saiu da rua no meio do percurso e o relatorio acusou "percorreu so
## 175 m" como se fosse engasgo de carga. A distancia estava certa; a direcao e
## que nao era mais a que o teste mandou.
func _em_captura() -> bool:
	for arg: String in OS.get_cmdline_user_args():
		var automatico := (arg.begins_with("--shot=")
				or arg.begins_with("--shot-frame=")
				or arg.begins_with("--stats=")
				or arg.begins_with("--desfile=")
				or arg.begins_with("--teste-")
				or arg in ["--auto-run", "--auto-walk", "--atravessar",
					"--shot-quit"])
		if automatico:
			return true
	return false


func travar(preso: bool) -> void:
	travado = preso
	if preso:
		velocity.x = 0.0
		velocity.z = 0.0


func _unhandled_input(evento: InputEvent) -> void:
	if travado:
		return
	if evento is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := evento as InputEventMouseMotion
		if RadioCarro.aberta():
			# Com a roleta aberta o mouse aponta a estacao e nao gira a cabeca,
			# senao escolher a radio faz o carro sair da faixa.
			_apontar_roleta(mm.relative)
			return
		rotate_y(-mm.relative.x * SENSIBILIDADE)
		_pitch = clampf(_pitch - mm.relative.y * SENSIBILIDADE, PITCH_MIN, PITCH_MAX)
		_pivo.rotation.x = _pitch
		return

	if evento.is_action_pressed("alternar_camera"):
		_alternar_camera()
	# ESC/PAUSE e da prancha de inventario (ver prancha_inventario.gd). Aqui
	# nao se mexe no mouse: a prancha captura e devolve o cursor ao abrir/fechar.
	elif evento.is_action_pressed("lanterna"):
		# So chega aqui se a lanterna tiver sido reconfigurada para outra tecla;
		# no mapa de fabrica ela divide o F com o veiculo e o ramo acima resolve.
		alternar_lanterna()
	elif evento.is_action_pressed("agachar") and _carro != null:
		_carro.buzinar()
	elif evento.is_action_pressed("agachar") and _bike != null:
		# Mesma tecla da buzina, pelo mesmo motivo: e a tecla de "avisar que
		# estou aqui", e na bicicleta quem avisa e a campainha.
		_bike.tocar_sino()
	elif evento.is_action_pressed("radio"):
		# Mesma tecla, dois radios. A pe e o radio de mao que capta o inimigo;
		# ao volante e a roleta de estacoes, que se aponta segurando a tecla.
		if _carro != null:
			_giro_roleta = Vector2.ZERO
			RadioCarro.abrir()
		else:
			radio.alternar()
			AudioDirector.tocar_ui(&"interruptor", -6.0)
	elif evento.is_action_released("radio") and RadioCarro.aberta():
		RadioCarro.fechar(true)
	elif evento.is_action_pressed("veiculo"):
		# F e a mesma tecla da lanterna, e isso e deliberado.
		#
		# Entrar e sair do carro em F foi pedido, e a lanterna ja morava ali. Em
		# vez de mudar uma das duas, a tecla decide pelo contexto: havendo carro
		# ao alcance — ou estando dentro de um — ela e a porta; nao havendo, ela
		# e a lanterna, como sempre foi. Os dois casos nunca se sobrepoem, porque
		# quem esta ao volante nao tem lanterna na mao.
		if not _alternar_veiculo():
			alternar_lanterna()
	elif evento.is_action_pressed("interagir"):
		# Dentro do carro a tecla de interagir e a ignicao. E a mesma decisao de
		# sempre: acionar o que esta na frente do jogador, e o que esta na frente
		# de quem esta sentado ao volante e a chave.
		if _carro != null:
			_carro.alternar_ignicao()
		elif _alvo != null:
			_alvo.interagir(self)
	elif evento.is_action_pressed("debug_nevoa"):
		Settings.cycle_fog_preset()


func _alternar_camera() -> void:
	var tp := _braco.alternar()
	_corpo.visible = tp
	camera_alternada.emit(tp)


func _physics_process(delta: float) -> void:
	if _carro != null:
		_ao_volante(delta)
		return
	if _bike != null:
		_na_bicicleta(delta)
		return
	var caindo := velocity.y
	if not is_on_floor():
		velocity.y -= _gravidade * delta

	_atualizar_agachar()

	var eixo := _auto if _auto != Vector2.ZERO 		else Input.get_vector("mover_esq", "mover_dir", "mover_frente", "mover_tras")
	# O fantasma tambem ignora a trava de roteiro. A blitz aborda quem passa pelo
	# funil e prende o jogador para a conversa — comportamento certo do jogo, e
	# mais uma forma de a medicao de streaming virar "parou no metro 101".
	if travado and not _atravessar:
		eixo = Vector2.ZERO
	var v := transform.basis * Vector3(eixo.x, 0.0, eixo.y)
	var direcao := v.normalized() if v.length_squared() > 0.001 else Vector3.ZERO

	var quer_correr := (_auto_correr or Input.is_action_pressed("correr")) 		and not _agachado and eixo.length() > 0.1
	var alvo := _velocidade_alvo(quer_correr)
	_atualizar_folego(quer_correr and folego > 0.0, delta)

	var plano := Vector3(velocity.x, 0.0, velocity.z)
	if direcao.length_squared() > 0.01:
		plano = plano.move_toward(direcao * alvo, ACELERACAO * delta)
	else:
		plano = plano.move_toward(Vector3.ZERO, DESACELERACAO * delta)

	velocity.x = plano.x
	velocity.z = plano.z
	if _atravessar:
		# Sem move_and_slide nao ha nada para empurrar o corredor de volta. A
		# altura fica na do nascimento: sem chao para pisar, a gravidade acumulada
		# levaria o fantasma para baixo do mundo em poucos segundos.
		var y := global_position.y
		global_position += Vector3(plano.x, 0.0, plano.z) * delta
		global_position.y = y
		velocity.y = 0.0
	else:
		move_and_slide()

	# Aterrissagem: a cabeca afunda proporcional a queda. E o unico retorno de
	# peso que o jogo tem, ja que nao ha animacao de aterrissar.
	if is_on_floor() and not _estava_no_chao:
		_impacto = minf(IMPACTO_MAXIMO, absf(caindo) * IMPACTO_POR_VELOCIDADE)
		if _impacto > 0.03:
			AudioDirector.passo(superficie(), global_position, 0.9)
	_estava_no_chao = is_on_floor()
	_impacto = move_toward(_impacto, 0.0, IMPACTO_RECUPERA * delta * maxf(_impacto, 0.05))

	_atualizar_camera(eixo, delta)

	_atualizar_bob(delta)
	_atualizar_alvo()
	_atualizar_lanterna(delta)
	# A figura anima sempre, nao so quando visivel: em terceira pessoa a troca de
	# camera e instantanea e um corpo que comeca o ciclo do zero entrega o corte.
	if _figura != null:
		_figura.animar(Vector2(velocity.x, velocity.z).length(), delta, is_on_floor())


func _velocidade_alvo(correndo: bool) -> float:
	if _agachado:
		return VEL_AGACHADO
	if correndo and folego > 0.0:
		return VEL_CORRER
	return VEL_ANDAR


func _atualizar_folego(gastando: bool, delta: float) -> void:
	if _auto_correr:
		return
	if gastando:
		folego = maxf(0.0, folego - delta)
	else:
		folego = minf(FOLEGO_MAX, folego + delta * (FOLEGO_MAX / FOLEGO_RECUPERA))


func _atualizar_agachar() -> void:
	var quer := Input.is_action_pressed("agachar")
	if quer == _agachado:
		return
	# Levantar so vale se houver espaco. Sem isso o jogador atravessa o teto.
	if not quer and _tem_teto():
		return
	_agachado = quer
	var capsula := _colisao.shape as CapsuleShape3D
	capsula.height = ALTURA_AGACHADO if _agachado else ALTURA
	_colisao.position.y = capsula.height * 0.5
	_corpo.scale.y = (ALTURA_AGACHADO / ALTURA) if _agachado else 1.0


func _tem_teto() -> bool:
	var espaco := get_world_3d().direct_space_state
	var de := global_position + Vector3.UP * ALTURA_AGACHADO
	var para := global_position + Vector3.UP * (ALTURA + 0.05)
	var consulta := PhysicsRayQueryParameters3D.create(de, para)
	consulta.exclude = [get_rid()]
	return not espaco.intersect_ray(consulta).is_empty()


func _atualizar_bob(delta: float) -> void:
	var altura_olho := ALTURA_OLHO_AGACHADO if _agachado else ALTURA_OLHO
	var rapidez := Vector2(velocity.x, velocity.z).length()

	if rapidez < 0.15 or not is_on_floor():
		_pivo.position.y = lerpf(_pivo.position.y, altura_olho - _impacto, 8.0 * delta)
		_pivo.rotation.z = lerpf(_pivo.rotation.z, _inclinacao, 8.0 * delta)
		return

	_distancia += rapidez * delta
	var t := _distancia * BOB_FREQ
	var escala := rapidez / VEL_ANDAR

	_pivo.position.y = altura_olho - _impacto + sin(t * 2.0) * BOB_AMP * escala
	_pivo.rotation.z = _inclinacao + sin(t) * BOB_ROLL * escala

	# Um passo por meio ciclo do bob vertical.
	var fase := int(t / PI)
	if fase != _fase_bob:
		_fase_bob = fase
		passo_dado.emit(rapidez)


## Procura o que esta na mira. O raio parte da camera e nao do corpo, senao o
## jogador aponta para uma coisa e aciona outra.
func _atualizar_alvo() -> void:
	var camera := _braco.get_node_or_null("Camera") as Camera3D
	if camera == null:
		return

	_raio.global_transform = camera.global_transform
	_raio.force_raycast_update()

	var achado: Interativo = null
	if _raio.is_colliding():
		var col := _raio.get_collider()
		if col is Interativo and (col as Interativo).habilitado:
			achado = col

	# Compara tambem o texto, nao so o alvo: a porta troca de "Entrar" para
	# "Entrando..." sem deixar de ser a mesma porta, e o prompt tem que
	# acompanhar. So comparar o no deixava o texto velho na tela.
	var texto := achado.rotulo_atual() if achado != null else ""
	# Sem nada mirado, ainda pode haver um carro vazio ao lado. O convite para
	# entrar nao depende de estar olhando para a lataria: quem chega perto de um
	# carro sabe que ele esta ali, e mirar a porta com um raio de camera para
	# poder apertar F seria uma exigencia que nenhum jogo de carro faz.
	if texto.is_empty():
		texto = _prompt_de_veiculo()
	if achado == _alvo and texto == _rotulo_alvo:
		return
	_alvo = achado
	_rotulo_alvo = texto
	alvo_de_interacao.emit(texto)


## "Entrar no carro [F]", quando ha um carro sem motorista ao alcance.
func _prompt_de_veiculo() -> String:
	if _em_captura():
		return ""
	if _carro != null or _bike != null or travado or Conversa.ativo:
		return ""
	if Bicicleta.mais_perto(get_tree(), global_position, ALCANCE_BICICLETA) != null:
		return "Subir na bicicleta  [F]"
	var perto := Transito.mais_perto(global_position, ALCANCE_VEICULO)
	if perto == null or perto.motorista != Carro.Motorista.NINGUEM:
		return ""
	return "Entrar no carro  [F]"


## Devolve o alvo atual, ou null. O HUD usa para nao precisar guardar estado.
func alvo_atual() -> Interativo:
	return _alvo


## Inclinacao lateral e campo de visao. Duas coisas pequenas que, juntas, fazem
## a diferenca entre andar e deslizar.
func _atualizar_camera(eixo: Vector2, delta: float) -> void:
	if _camera == null:
		return

	var alvo_inclinacao := -eixo.x * INCLINACAO_LATERAL
	if _agachado or not is_on_floor():
		alvo_inclinacao = 0.0
	_inclinacao = lerpf(_inclinacao, alvo_inclinacao, minf(1.0, 8.0 * delta))

	var rapidez := Vector2(velocity.x, velocity.z).length()
	var f := clampf((rapidez - VEL_ANDAR) / maxf(0.01, VEL_CORRER - VEL_ANDAR), 0.0, 1.0)
	if fov_override > 0.0:
		_camera.fov = fov_override
	else:
		_camera.fov = lerpf(_camera.fov, lerpf(FOV_BASE, FOV_CORRIDA, f), minf(1.0, 5.0 * delta))


## Quanto barulho o jogador esta fazendo, de 0 a 1.
##
## E o que o inimigo escuta. Correr denuncia, andar quase nao, agachar nunca.
## Isso transforma a velocidade numa decisao em vez de um botao sempre apertado.
func nivel_de_ruido() -> float:
	if not is_on_floor():
		return 0.0
	var rapidez := Vector2(velocity.x, velocity.z).length()
	if _agachado or rapidez < 0.2:
		return 0.0
	if rapidez > VEL_ANDAR + 0.4:
		return 1.0
	return 0.34 * (rapidez / VEL_ANDAR)


## Superficie sob os pes. Por enquanto sai do contexto, nao do material: dentro
## de casa e madeira, na rua e concreto. A Fase 6 pode ler o material de verdade.
func superficie() -> StringName:
	return &"madeira" if Interiores.dentro else &"concreto"


func _ao_dar_passo(rapidez: float) -> void:
	if _agachado:
		return
	AudioDirector.passo(superficie(), global_position,
		clampf(rapidez / VEL_CORRER, 0.25, 1.0))


# --- lanterna ---------------------------------------------------------------

func _montar_lanterna() -> void:
	_lanterna = SpotLight3D.new()
	_lanterna.name = "Lanterna"
	_lanterna.light_color = Color("fff0d0")
	_lanterna.light_energy = 4.2
	_lanterna.spot_range = 17.0
	_lanterna.spot_angle = 26.0
	_lanterna.spot_angle_attenuation = 0.9
	_lanterna.spot_attenuation = 1.1
	# ART-BIBLE secao 7 — o PS1 nao tinha sombra dinamica
	_lanterna.shadow_enabled = false
	_lanterna.visible = false
	# Presa ao pivo da cabeca, nao ao braco: em terceira pessoa a lanterna
	# continua saindo do personagem, e nao da camera flutuando atras dele.
	_pivo.add_child(_lanterna)


func alternar_lanterna() -> void:
	if not Inventario.tem(&"lanterna"):
		return
	if not lanterna_ligada and bateria <= 0.0:
		AudioDirector.tocar_ui(&"interruptor", -10.0)
		return
	lanterna_ligada = not lanterna_ligada
	_lanterna.visible = lanterna_ligada
	AudioDirector.tocar_ui(&"interruptor", -4.0)


func _atualizar_lanterna(delta: float) -> void:
	if not lanterna_ligada:
		return

	bateria = maxf(0.0, bateria - delta / BATERIA_SEGUNDOS)
	if bateria <= 0.0:
		lanterna_ligada = false
		_lanterna.visible = false
		AudioDirector.tocar_ui(&"interruptor", -12.0)
		return

	# Perto do fim a luz fraqueja. O aviso e a mecanica: sem ele o escuro chega
	# de surpresa e le como punicao arbitraria.
	var base := 4.2
	if bateria < BATERIA_FRACA:
		var f := bateria / BATERIA_FRACA
		base *= 0.35 + 0.65 * f
		base *= 1.0 - 0.4 * maxf(0.0, sin(Time.get_ticks_msec() * 0.011)) * (1.0 - f)
	_lanterna.light_energy = base


## Repoe a bateria. Devolve false quando ja estava cheia.
func trocar_bateria() -> bool:
	if bateria > 0.98:
		return false
	bateria = 1.0
	return true


func _montar_radio() -> void:
	radio = Radio.new()
	radio.name = "Radio"
	add_child(radio)


## Zera a inercia. Teleportar mantendo velocidade faz o jogador sair andando
## sozinho para dentro da parede assim que chega.
func zerar_velocidade() -> void:
	velocity = Vector3.ZERO


## Vira o corpo para um ponto, mantendo o pitch. Usado ao entrar num interior:
## aparecer olhando para a parede e desorientador.


## O corpo visivel do jogador, para quem precisa posar ele.
##
## A abertura precisa disto. Ela mostra o sujeito de fora, encostado na parede,
## e o corpo que aparece ali tem de ser o MESMO que a carteira de identidade
## retrata — nao um figurante montado so para a cena. Sem este acesso a
## alternativa seria instanciar um segundo Corpo com a mesma ficha, e ai
## existiriam duas pessoas iguais no mesmo lugar, o que o jogo ja aprendeu a nao
## fazer (ver Corpo.montar).
func figura() -> Corpo:
	return _figura


## Mostra ou esconde o corpo de terceira pessoa sem trocar de camera.
##
## Nao e o mesmo que `alternar_camera`: a abertura precisa do corpo visivel com
## a camera em outro lugar do mundo, e a alternancia normal amarra as duas
## coisas porque em jogo elas andam sempre juntas.
func mostrar_corpo(visivel: bool) -> void:
	_corpo.visible = visivel


## A camera de gameplay. Quem assume o quadro precisa saber para onde devolver.
func camera() -> Camera3D:
	return _camera


## O pivo da cabeca, que e onde mora o pitch. Quem pendura alguma coisa no campo
## de visao — a bituca do cigarro no ultimo plano da abertura — pendura aqui, e
## nao na camera: a camera vai e volta da terceira pessoa no braco, e o que
## estiver preso nela viaja junto.
func pivo() -> Node3D:
	return _pivo


func definir_fov(v: float) -> void:
	fov_override = v
	if _camera != null:
		_camera.fov = v


func liberar_fov() -> void:
	fov_override = -1.0
	if _camera != null:
		_camera.fov = FOV_BASE


## Pitch da cabeca em radianos. Usado pela abertura CRT ao olhar esq/dir.
func definir_pitch(rad: float) -> void:
	_pitch = clampf(rad, PITCH_MIN, PITCH_MAX)
	_pivo.rotation.x = _pitch


func pitch_atual() -> float:
	return _pitch

func olhar_para(ponto: Vector3) -> void:
	var d := ponto - global_position
	var horiz := Vector2(d.x, d.z).length()
	if horiz < 0.001 and absf(d.y) < 0.001:
		return
	if horiz >= 0.001:
		rotation.y = atan2(-d.x, -d.z)
	# Pitch acompanha o ponto (capturas de blitz).
	definir_pitch(atan2(d.y, maxf(horiz, 0.001)))


# --- construcao -------------------------------------------------------------

## Raio de mira na camada de interacao. Separado da colisao do mundo: o raio
## precisa atravessar o cenario ate a area do objeto, e nao parar na parede
## antes dela.
func _montar_raio() -> void:
	_raio = RayCast3D.new()
	_raio.name = "MiraInteracao"
	_raio.enabled = true
	_raio.target_position = Vector3(0.0, 0.0, -ALCANCE_INTERACAO)
	_raio.collide_with_areas = true
	_raio.collide_with_bodies = true
	# Mundo solido mais interacao: uma porta atras de uma parede nao pode ser
	# acionada, entao o raio precisa enxergar as duas camadas e parar na primeira.
	_raio.collision_mask = 1 | Interativo.CAMADA
	add_child(_raio)


func _montar_colisao() -> void:
	var capsula := CapsuleShape3D.new()
	capsula.height = ALTURA
	capsula.radius = RAIO
	_colisao.shape = capsula
	_colisao.position.y = ALTURA * 0.5
	_pivo.position.y = ALTURA_OLHO


## Corpo visivel em terceira pessoa.
##
## E o MESMO Corpo dos pedestres, montado a partir da ficha do jogador. Isso nao
## e reaproveitamento por economia: e o que faz o sujeito que aparece ao apertar
## V ser a pessoa da foto da carteira que esta no inventario. Um boneco generico
## aqui abriria um buraco no meio do sistema — o jogo inteiro depois disso e
## sobre documento bater com pessoa.
##
## Remontado quando a ficha troca. A ordem do motor e contra: o _ready do jogador
## roda antes do da cena, e e a cena que cria a identidade, entao no primeiro
## quadro nao ha ficha nenhuma para ler.
## ART-BIBLE secao 10 permite 900 triangulos no personagem.
func _montar_corpo() -> void:
	_refazer_corpo()
	RegistroCivil.jogador_mudou.connect(_refazer_corpo)
	_corpo.visible = false


func _refazer_corpo() -> void:
	if _figura != null:
		_figura.queue_free()
	_figura = Corpo.new()
	_figura.name = "Corpo"
	_corpo.add_child(_figura)
	var ficha := RegistroCivil.jogador
	_figura.montar(ficha["aparencia"] if ficha.has("aparencia")
		else Aparencia.de_ficha({"id": 7, "sexo": &"M", "idade": 31}))


# --- volante ----------------------------------------------------------------

## Entrar e sair do carro, na mesma tecla.
##
## Nao ha animacao de porta e nao vai haver: o jogo e de 1998 e o corte seco com
## a cortina de escurecimento e o vocabulario dele. O que precisa existir e a
## continuidade — o jogador sai do lado do motorista, no chao, olhando para onde
## estava olhando.
## Resolve a tecla do veiculo. Devolve falso quando nao havia veiculo nenhum
## para resolver, e ai quem chamou usa a tecla para a lanterna.
func _alternar_veiculo() -> bool:
	if travado or Conversa.ativo:
		return false
	if _carro != null:
		_sair_do_carro()
		return true
	if _bike != null:
		_descer_da_bicicleta()
		return true
	# A bicicleta responde ANTES do carro. Ela e menor, entao o alcance dela e
	# menor, entao ela so ganha a disputa quando esta realmente mais perto — e
	# uma bicicleta encostada na lataria de um carro e um caso que acontece.
	var bike := Bicicleta.mais_perto(get_tree(), global_position, ALCANCE_BICICLETA)
	if bike != null:
		_subir_na_bicicleta(bike)
		return true
	var perto := Transito.mais_perto(global_position, ALCANCE_VEICULO)
	if perto == null:
		return false
	# Com motorista dentro nao se entra: pede-se. E o que a tecla de interagir
	# faz, pela Conversa, e e o que separa investigador de ladrao.
	if perto.motorista == Carro.Motorista.IA:
		alvo_de_interacao.emit("Ha alguem ao volante  [E]")
		return true
	_entrar_no_carro(perto)
	return true


func _entrar_no_carro(c: Carro) -> void:
	_carro = c
	c.assumir(self)
	Transito.entregar_ao_jogador(c)
	# O corpo do jogador some de cena mas continua existindo: a lanterna, o
	# radio e o inventario penduram nele, e destrui-lo para dirigir seria
	# reconstruir tudo isso na saida.
	visible = false
	_colisao.disabled = true
	velocity = Vector3.ZERO
	AudioDirector.tocar_ui(&"porta_carro", -8.0)
	alvo_de_interacao.emit("")


func _sair_do_carro() -> void:
	if _carro == null:
		return
	var onde := _carro.ponto_de_saida()
	_carro.devolver()
	Transito.devolver_do_jogador()
	_carro = null
	visible = true
	_colisao.disabled = false
	global_position = onde
	velocity = Vector3.ZERO
	if RadioCarro.aberta():
		RadioCarro.fechar(false)
	AudioDirector.tocar_ui(&"porta_carro", -8.0)


# --- selim ------------------------------------------------------------------

## Subir na bicicleta. Diferente do carro em uma coisa que importa: o corpo NAO
## some.
##
## No carro ele some porque um corpo em pe dentro da lataria atravessaria o
## teto. Aqui nao ha teto: o jogador fica a cavalo do quadro, e em terceira
## pessoa se ve a propria figura em cima da bicicleta — que e a metade da graca
## de ter uma. Some so a colisao, porque quem empurra o mundo agora e ela.
func _subir_na_bicicleta(b: Bicicleta) -> void:
	_bike = b
	b.assumir(self)
	_colisao.disabled = true
	velocity = Vector3.ZERO
	_agachado = false
	AudioDirector.tocar_ui(&"interruptor", -14.0)
	alvo_de_interacao.emit("")


func _descer_da_bicicleta() -> void:
	if _bike == null:
		return
	var onde := _bike.ponto_de_saida()
	_bike.devolver()
	_bike = null
	_colisao.disabled = false
	global_position = onde
	velocity = Vector3.ZERO
	_pivo.position.y = ALTURA_OLHO


## Pedalando. O corpo acompanha a bicicleta, como acompanha o carro, e pelo
## mesmo motivo: ser filho dela faria a lanterna e o raio de interacao girarem
## junto com a inclinacao da curva.
func _na_bicicleta(delta: float) -> void:
	if not is_instance_valid(_bike):
		_bike = null
		_colisao.disabled = false
		return

	global_position = _bike.assento()
	# A cabeca segue o rumo da bicicleta, com folga para olhar de lado. Mais
	# solta que no carro: quem pedala vira a cabeca, e nao ha para-brisa
	# obrigando a olhar para a frente.
	rotation.y = lerp_angle(rotation.y, _bike.global_rotation.y,
		minf(1.0, 6.0 * delta))
	_pivo.position.y = lerpf(_pivo.position.y, OLHO_NA_BICICLETA,
		minf(1.0, 8.0 * delta))
	# A camera deita junto com a bicicleta na curva. Sem isso a inclinacao
	# existe so para quem esta olhando de fora, e ela e o principal sinal de que
	# aquilo tem duas rodas.
	_pivo.rotation.z = lerpf(_pivo.rotation.z, _bike.rotation.z * 0.55,
		minf(1.0, 8.0 * delta))
	if _camera != null:
		_camera.fov = lerpf(_camera.fov, FOV_BASE + clampf(
			absf(_bike.velocidade()) * 1.1, 0.0, 7.0), minf(1.0, 4.0 * delta))

	if _figura != null:
		_figura.animar(0.0, delta, true)
	_atualizar_lanterna(delta)
	_mostrar_guidao()


func _mostrar_guidao() -> void:
	if _bike == null:
		return
	var kmh := absf(_bike.velocidade()) * 3.6
	alvo_de_interacao.emit("%2d km/h     [Ctrl] campainha     Descer  [F]" % int(kmh))


## O que o jogador faz enquanto dirige: nada com o proprio corpo.
##
## O corpo acompanha o carro em vez de ser preso a ele por no. Ficar filho do
## VehicleBody3D parecia mais limpo e nao e: a cada quadro o motor recalcularia
## a transformada de um corpo cinematico dentro de um corpo rigido, e a lanterna
## e o raio de interacao passariam a girar com a suspensao.
func _ao_volante(delta: float) -> void:
	if not is_instance_valid(_carro):
		_carro = null
		visible = true
		_colisao.disabled = false
		return

	global_position = _carro.assento()
	# A camera olha para onde o carro aponta, com um resto de liberdade para o
	# jogador olhar de lado sem o carro virar junto.
	var alvo_giro := _carro.global_rotation.y
	rotation.y = lerp_angle(rotation.y, alvo_giro, minf(1.0, 9.0 * delta))
	_pitch = lerpf(_pitch, -0.06, minf(1.0, 5.0 * delta))
	_pivo.rotation.x = _pitch
	if _camera != null:
		_camera.fov = lerpf(_camera.fov, FOV_BASE + clampf(
			absf(_carro.velocidade()) * 0.5, 0.0, 9.0), minf(1.0, 4.0 * delta))

	_atualizar_lanterna(delta)
	_mostrar_painel()


## O prompt vira painel enquanto se dirige: marcha, velocidade e estacao. E a
## unica instrumentacao do carro, e cabe numa linha porque a tela tem 480 px.
func _mostrar_painel() -> void:
	if _carro == null:
		return
	if not _carro.ligado:
		alvo_de_interacao.emit("Ligar o motor  [E]     Sair  [F]")
		return
	var kmh := absf(_carro.velocidade()) * 3.6
	alvo_de_interacao.emit("%dª  %3d km/h   %s   [Ctrl] buzina  [R] radio" % [
		_carro.marcha(), int(kmh), RadioCarro.nome_da_estacao()])


func _apontar_roleta(relativo: Vector2) -> void:
	_giro_roleta += relativo * 0.9
	if _giro_roleta.length() > 60.0:
		_giro_roleta = _giro_roleta.normalized() * 60.0
	RadioCarro.apontar(_giro_roleta)


## Acumulador do gesto da roleta. O mouse da deslocamento, e nao posicao; a
## roleta precisa de direcao, entao o deslocamento e somado enquanto ela esta
## aberta e zerado quando ela abre.
var _giro_roleta := Vector2.ZERO


## Poe o jogador no chao, venha de onde vier a ordem.
##
## Existe para quem TELEPORTA o jogador: carregar um save com ele ao volante
## deixaria o corpo invisivel, sem colisao e grudado num carro que ficou no
## mundo antigo. Quem move o jogador chama isto antes.
func desembarcar() -> void:
	if _carro != null:
		_sair_do_carro()
		return
	if _bike != null:
		_descer_da_bicicleta()
		return
	# Cinto e suspensorio: se por qualquer caminho o corpo ficou escondido sem
	# carro, devolve o estado de andar a pe.
	visible = true
	if _colisao != null:
		_colisao.disabled = false


func dirigindo() -> bool:
	return _carro != null or _bike != null


func carro() -> Carro:
	return _carro
