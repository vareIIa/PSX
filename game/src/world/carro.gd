## Um carro. O mesmo no serve para o transito e para o jogador.
##
## Por que nao sao duas classes
## ----------------------------
## Roubar um carro e a acao central do pedido, e todo desenho em que o carro da
## IA e um objeto e o carro dirigivel e outro paga a troca exatamente na hora em
## que o jogador esta olhando de perto: o modelo pisca, a inercia zera, a cor
## muda um tom porque o sorteio rodou de novo. Aqui nao ha troca. O carro e
## sempre um VehicleBody3D com as mesmas rodas e a mesma lataria; o que muda e
## quem esta ao volante.
##
##   IA        `freeze` ligado em modo cinematico. A posicao vem da faixa de
##             rolamento, entao o carro nao capota, nao entala em meio-fio e nao
##             deriva ao longo de dez minutos de simulacao. Ele ainda empurra
##             pedestre e ainda e solido para o jogador.
##   JOGADOR   `freeze` desligado. Dai em diante e fisica de verdade: forca no
##             eixo, esterco nas dianteiras, peso transferindo na freada.
##
## A troca e uma linha e nao tem costura, porque o corpo rigido ja estava ali
## parado no lugar certo com a velocidade certa.
##
## Por que a IA nao usa a fisica
## -----------------------------
## Porque nao ha ganho e ha risco. Um transito de seis corpos rigidos com
## suspensao e atrito de pneu diverge: dois carros se tocam num cruzamento, um
## sobe no outro, e vinte minutos depois ha um carro de pe em cima de um poste a
## duzentos metros de distancia, onde ninguem ve o defeito nascer. A faixa e uma
## reta conhecida; segui-la e mais barato e nao tem cauda.
class_name Carro
extends VehicleBody3D

enum Motorista { NINGUEM, IA, JOGADOR }

## Velocidade de cruzeiro da IA, em m/s. 11 m/s sao 40 km/h — velocidade de rua
## estreita a noite, e o bastante para o carro passar por um pedestre parado com
## a sensacao de perigo que o pedido descreve.
const VEL_CRUZEIRO := 11.0
const VEL_AVENIDA := 14.0
## Aceleracao e frenagem da IA, em m/s^2.
const ACELERA := 4.2
const FREIA := 8.0

## Quao perto do ponto de destino conta como chegou.
const CHEGOU := 2.4
## Quanto o carro olha a frente para decidir se freia.
const OLHAR_A_FRENTE := 9.0
## Meia largura do corredor em que um obstaculo a frente conta como obstaculo.
const CORREDOR := 1.5

## Distancia minima da zona de retencao ao centro do cruzamento.
## A distancia efetiva cresce com a velocidade (ver _sinal_manda_parar).
const RETENCAO := 5.0
## Antecipar escolha de curva antes de passar do pivo (meia avenida ~3.4 m).
const ANTECIPAR_CURVA := 8.5
## Segundos de seta antes do pivo. Distancia = velocidade * isto.
const PISCA_S := 1.5
## Periodo do pisca-pisca (aceso metade do ciclo).
const PISCA_PERIODO := 0.44

## Potencia do carro do jogador. Nao e um carro esportivo: e um sedan cansado
## de cidade, e a diversao esta em ele ser pesado, nao em ele ser rapido.
const FORCA_MOTOR := 240.0
const FORCA_RE := 130.0
const FREIO_MAX := 42.0
const ESTERCO_MAX := 0.52
## Quanto o esterco fecha com a velocidade. Sem isso, a 90 km/h um toque no A
## joga o carro de lado.
const ESTERCO_MIN := 0.16
const VEL_ESTERCO_FECHADO := 22.0

## Marchas do cambio simplificado. Cada faixa e a velocidade em que ela troca,
## em m/s. Existem para o SOM: o pedido pede que se ouca a troca conforme o
## carro anda, e e a troca que faz um motor soar como motor de carro e nao como
## secador de cabelo.
const MARCHAS: Array[float] = [4.0, 8.5, 14.0, 21.0, 30.0]

## Buzina: quanto tempo parado atras de alguem antes de reclamar.
const PACIENCIA := 2.6
const PACIENCIA_XINGO := 6.5

## A que distancia um pedestre se assusta com o carro passando, e a que
## velocidade minima isso conta como quase-atropelamento.
const RAIO_SUSTO := 3.2
const VEL_SUSTO := 5.0

signal motorista_saiu(quem: Node3D)


## Area de acionamento. Existe so para responder a tecla; a decisao fica no
## Carro, que e quem sabe se ha alguem dentro.
class Gatilho extends Interativo:
	var dono: Carro

	func rotulo_atual() -> String:
		if dono == null or Conversa.ativo:
			return ""
		return dono.rotulo_de_acao()

	func interagir(quem: Node) -> void:
		if dono != null:
			dono.acionar(quem)


var modelo: Carroceria.Modelo = Carroceria.Modelo.SEDA
var semente: int = 0
## Ficha do motorista, quando ha um. Vem do RegistroCivil como a de qualquer
## pedestre — e por isso da para tirar o sujeito do carro e conferir o RG dele.
var ficha: Dictionary = {}
var motorista: Motorista = Motorista.NINGUEM
var ligado: bool = false

## Estado de navegacao da IA.
var cruzamento := Vector2i.ZERO
var destino := Vector2i.ZERO
var trecho := Vector4i.ZERO

var _medidas: Dictionary = {}
var _corpo_malha: MeshInstance3D
var _luzes: MeshInstance3D
var _eixo_frente: Node3D
var _eixo_tras: Node3D
var _rodas: Array[VehicleWheel3D] = []
var _farol: SpotLight3D
var _brasa: OmniLight3D
var _motorista_corpo: Corpo
var _gatilho: Gatilho
var _som: MotorSom
var _buzina: AudioStreamPlayer3D
var _voz: Voz

var _alvo := Vector3.ZERO
## Ha rota? Nao da para perguntar isso ao _alvo: Vector3.ZERO e a origem do
## mundo, que e uma esquina como qualquer outra, e o carro que passasse por ela
## recalcularia a rota a cada quadro.
var _tem_rota: bool = false
## Verdadeiro enquanto o alvo e a QUINA dentro do cruzamento, e nao o cruzamento
## seguinte. Ver _escolher_destino.
var _curvando: bool = false
var _velocidade: float = 0.0
var _giro: float = 0.0
var _parado: float = 0.0
var _desde_buzina: float = 0.0
var _freando: bool = false
var _re: bool = false
var _vivo: float = 0.0
## Cruzamento cujo sinal ainda manda neste carro (sobrevive ao retarget de destino).
var _aproxima := Vector2i.ZERO
## Rolagem visual das rodas, separada do esterco para nao corromper Euler.
var _rolo_frente: float = 0.0
var _rolo_tras: float = 0.0

## Seta: -1 esquerda, +1 direita (+X), 0 apagada.
var _pisca_lado: int = 0
var _pisca_tempo: float = 0.0
## Saida escolhida antecipadamente para a seta nao divergir do sorteio.
var _saida_plana := Vector4i.ZERO
var _tem_plano: bool = false

## Cache da malha de lanternas para trocar celula UV (freio / re / seta).
var _luz_arrays: Array = []
var _luz_uv_base: PackedVector2Array = PackedVector2Array()
var _luz_i_esq: Array[int] = []
var _luz_i_dir: Array[int] = []
var _luz_chave: int = -1


func preparar(nova_ficha: Dictionary, de: Vector2i, t: Vector4i,
		nova_semente: int) -> void:
	ficha = nova_ficha
	cruzamento = de
	trecho = t
	semente = nova_semente
	modelo = _sortear_modelo(nova_semente)
	motorista = Motorista.IA if not nova_ficha.is_empty() else Motorista.NINGUEM


static func _sortear_modelo(s: int) -> Carroceria.Modelo:
	# O taxi e raro de proposito. Um em nove: frequente o bastante para o
	# jogador reparar que existe, raro o bastante para ainda ser um evento.
	var h := absi(s * 2654435761) % 100
	if h < 11:
		return Carroceria.Modelo.TAXI
	if h < 32:
		return Carroceria.Modelo.HATCH
	if h < 50:
		return Carroceria.Modelo.PERUA
	if h < 66:
		return Carroceria.Modelo.PICAPE
	return Carroceria.Modelo.SEDA


func _ready() -> void:
	add_to_group(&"carro")
	collision_layer = 1
	collision_mask = 1

	var tinta: Color = Carroceria.TINTAS[absi(semente * 7919) % Carroceria.TINTAS.size()]
	_medidas = Carroceria.montar(modelo, tinta, semente)

	mass = 980.0
	# Centro de massa no assoalho. Um carro cujo centro esta na altura do banco
	# capota na primeira curva forte, e essa e a falha mais visivel que fisica
	# de veiculo produz.
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, -0.18, 0.0)
	continuous_cd = true

	_montar_visual()
	_montar_colisao()
	_montar_rodas()
	_montar_luzes()
	_cachear_luzes()
	_montar_som()
	_montar_gatilho()
	if motorista == Motorista.IA:
		_montar_motorista()

	_congelar(motorista != Motorista.JOGADOR)
	_iniciar_rota()
	_alinhar_na_faixa()
	if motorista == Motorista.IA:
		_velocidade = _teto_de_velocidade()


# --- montagem ---------------------------------------------------------------

func _montar_visual() -> void:
	_corpo_malha = MeshInstance3D.new()
	_corpo_malha.name = "Lataria"
	_corpo_malha.mesh = _medidas["corpo"]
	_corpo_malha.material_override = load(Carroceria.MATERIAL) as ShaderMaterial
	_corpo_malha.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_corpo_malha)

	_luzes = MeshInstance3D.new()
	_luzes.name = "Luzes"
	_luzes.mesh = _medidas["luzes"]
	_luzes.material_override = (load(Carroceria.MATERIAL_LUZ)
		as ShaderMaterial).duplicate() as ShaderMaterial
	_luzes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_luzes)


func _montar_colisao() -> void:
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(float(_medidas["largura"]),
		float(_medidas["altura"]) - Carroceria.ASSOALHO,
		float(_medidas["comprimento"]))
	forma.shape = caixa
	forma.position = Vector3(0.0,
		Carroceria.ASSOALHO + (float(_medidas["altura"]) - Carroceria.ASSOALHO) * 0.5, 0.0)
	add_child(forma)


## As quatro rodas de fisica, e os dois eixos visuais em cima delas.
##
## A malha nao e filha da VehicleWheel3D. A roda de fisica sobe e desce com a
## suspensao e, com a malha pendurada nela, cada roda vira uma chamada de
## desenho. Aqui o eixo inteiro e uma malha so, colocada na media das duas
## rodas: perde-se o curso independente da suspensao, que a 480x270 e uma
## diferenca de menos de um pixel, e ganha-se metade das chamadas do carro.
func _montar_rodas() -> void:
	var eixo: float = _medidas["entre_eixos"] * 0.5
	var bitola: float = _medidas["bitola"] * 0.5
	for k in 4:
		var frente := k < 2
		var roda := VehicleWheel3D.new()
		roda.name = "Roda%d" % k
		roda.position = Vector3(bitola if k % 2 == 0 else -bitola,
			Carroceria.RAIO_RODA, eixo if frente else -eixo)
		roda.wheel_radius = Carroceria.RAIO_RODA
		roda.wheel_rest_length = 0.16
		roda.suspension_stiffness = 26.0
		roda.suspension_travel = 0.14
		roda.damping_compression = 0.62
		roda.damping_relaxation = 0.72
		roda.wheel_friction_slip = 3.4
		roda.use_as_steering = frente
		# Tracao dianteira, que e o que quase todo carro urbano tem. Tambem
		# perdoa mais: com tracao traseira, uma acelerada forte na chuva poe o
		# carro de lado e nao ha volante analogico para corrigir.
		roda.use_as_traction = frente
		add_child(roda)
		_rodas.append(roda)

	_eixo_frente = Node3D.new()
	_eixo_frente.name = "EixoFrente"
	_eixo_frente.position = Vector3(0.0, Carroceria.RAIO_RODA, eixo)
	add_child(_eixo_frente)
	var mf := MeshInstance3D.new()
	mf.mesh = _medidas["eixo_frente"]
	mf.material_override = load(Carroceria.MATERIAL) as ShaderMaterial
	mf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_eixo_frente.add_child(mf)

	_eixo_tras = Node3D.new()
	_eixo_tras.name = "EixoTras"
	_eixo_tras.position = Vector3(0.0, Carroceria.RAIO_RODA, -eixo)
	add_child(_eixo_tras)
	var mt := MeshInstance3D.new()
	mt.mesh = _medidas["eixo_tras"]
	mt.material_override = load(Carroceria.MATERIAL) as ShaderMaterial
	mt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_eixo_tras.add_child(mt)


## Um farol so, largo, e nao dois.
##
## Dois SpotLight3D por carro com seis carros na rua sao doze luzes dinamicas
## contra um orcamento que a cidade ja usa quase inteiro com os postes. Um cone
## largo a partir do meio do capo da o mesmo desenho no asfalto — a coisa que o
## jogador realmente ve — pela metade do preco.
func _montar_luzes() -> void:
	_farol = SpotLight3D.new()
	_farol.name = "Farol"
	# A frente do carro e -Z, e SpotLight3D ja aponta para -Z sem giro nenhum.
	_farol.position = Vector3(0.0, 0.62, -float(_medidas["comprimento"]) * 0.5 + 0.1)
	_farol.rotation.x = deg_to_rad(-9.0)
	_farol.spot_range = 26.0
	_farol.spot_angle = 34.0
	_farol.spot_angle_attenuation = 0.9
	_farol.light_energy = 3.2
	_farol.light_color = Color(1.0, 0.95, 0.86)
	_farol.shadow_enabled = false
	add_child(_farol)

	# A brasa vermelha atras. Nao ilumina nada: existe para o carro da frente
	# ter presenca na nevoa quando o jogador vem atras dele.
	_brasa = OmniLight3D.new()
	_brasa.name = "Brasa"
	_brasa.position = Vector3(0.0, 0.55, float(_medidas["comprimento"]) * 0.5)
	_brasa.omni_range = 3.0
	_brasa.light_energy = 0.55
	_brasa.light_color = Color(1.0, 0.22, 0.16)
	_brasa.shadow_enabled = false
	add_child(_brasa)


func _montar_som() -> void:
	_som = MotorSom.new()
	_som.name = "Motor"
	add_child(_som)

	_buzina = AudioStreamPlayer3D.new()
	_buzina.name = "Buzina"
	_buzina.bus = &"SFX"
	_buzina.max_distance = 60.0
	_buzina.unit_size = 8.0
	_buzina.volume_db = -6.0
	add_child(_buzina)

	# A voz do motorista sai de dentro do carro, abafada pela distancia curta.
	# E a mesma voz do pedestre: quem esta dirigindo e uma pessoa do registro.
	_voz = Voz.new()
	_voz.name = "Voz"
	_voz.max_distance = 11.0
	add_child(_voz)
	if not ficha.is_empty():
		_voz.configurar(ficha)


func _montar_gatilho() -> void:
	_gatilho = Gatilho.new()
	_gatilho.name = "Gatilho"
	_gatilho.dono = self
	add_child(_gatilho)
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(float(_medidas["largura"]) + 1.0, 2.0,
		float(_medidas["comprimento"]) + 0.6)
	forma.shape = caixa
	forma.position = Vector3(0.0, 0.9, 0.0)
	_gatilho.add_child(forma)


## O motorista visivel atras do vidro.
##
## E o mesmo Corpo do pedestre, afundado no banco ate a linha da cintura. Nao ha
## pose sentada: as pernas ficam abaixo do assoalho, fora de vista, e o que se
## ve pelo para-brisa e tronco, ombro e cabeca — que e tudo que se ve de um
## motorista de verdade a essa distancia.
func _montar_motorista() -> void:
	if _motorista_corpo != null or ficha.is_empty():
		return
	_motorista_corpo = Corpo.new()
	_motorista_corpo.name = "Motorista"
	add_child(_motorista_corpo)
	_motorista_corpo.montar(ficha.get("aparencia", {}))
	# Volante a esquerda: com a frente em -Z e Y para cima, a direita do carro e
	# +X, entao o banco do motorista fica em -X.
	_motorista_corpo.position = Vector3(
		-float(_medidas["largura"]) * 0.24, -0.36,
		-float(_medidas["comprimento"]) * 0.04)


func _tirar_motorista() -> void:
	if _motorista_corpo != null:
		_motorista_corpo.queue_free()
		_motorista_corpo = null


# --- quem dirige ------------------------------------------------------------

func _congelar(sim: bool) -> void:
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = sim


## O rotulo do gatilho de INTERACAO, que e a tecla E.
##
## Carro vazio devolve vazio de proposito: entrar e F, e um prompt escrito
## "[E]  Entrar no carro [F]" ensina a tecla errada. Quem avisa que da para
## entrar e o proprio jogador, ao chegar perto — ver Player._prompt_de_veiculo.
func rotulo_de_acao() -> String:
	if motorista == Motorista.IA:
		return "Abordar motorista"
	return ""


func acionar(quem: Node) -> void:
	if motorista == Motorista.IA:
		_abordar(quem)


## Investigacao, nao assalto. O jogador nao arromba nada: ele se identifica, e o
## motorista sai. Por isso a acao passa pela Conversa e nao por um botao — a
## ficha do sujeito fica na tela, e ele continua existindo na cidade depois.
func _abordar(quem: Node) -> void:
	if Conversa.ativo or ficha.is_empty():
		return
	Conversa.abrir_veicular(self, quem)


## O motorista desce e vira pedestre de verdade. Nao e um boneco descartado: sai
## do registro com o mesmo id, entao da para segui-lo, falar com ele de novo e
## consultar o CPF dele no celular depois.
func expulsar_motorista() -> void:
	if motorista != Motorista.IA:
		return
	var quem := ficha
	motorista = Motorista.NINGUEM
	ligado = false
	_tirar_motorista()
	_velocidade = 0.0

	var p := Pedestre.new()
	p.name = "ex_motorista_%d" % int(quem.get("id", 0))
	var no := Rotas.no_mais_proximo(global_position)
	var vizinhos := Rotas.vizinhos(no)
	p.preparar(quem, no, vizinhos[0] if not vizinhos.is_empty() else no)
	get_parent().add_child(p)
	# Do lado do motorista, meio metro para fora, ja fora da lataria.
	p.global_position = global_position - global_transform.basis.x * (
		float(_medidas["largura"]) * 0.5 + 0.55) + Vector3.UP * 0.1
	# Entra na contabilidade da multidao. Sem isto ele fica na rua para sempre:
	# ninguem o recolhe quando o jogador vai embora, porque ninguem sabe que ele
	# existe.
	Multidao.adotar(p)
	ficha = {}
	motorista_saiu.emit(p)


## O jogador assume. Nada e recriado: o corpo rigido ja esta aqui, com a
## velocidade que tinha, e so deixa de ser cinematico.
func assumir(_quem: Node) -> void:
	if motorista == Motorista.IA:
		return
	motorista = Motorista.JOGADOR
	_congelar(false)
	linear_velocity = -global_transform.basis.z * _velocidade
	_som.acordar()


func devolver() -> void:
	motorista = Motorista.NINGUEM
	_congelar(true)
	_velocidade = 0.0
	ligado = false
	_som.desligar()


func alternar_ignicao() -> void:
	ligado = not ligado
	if ligado:
		_som.partir()
	else:
		_som.desligar()


## Onde o jogador aparece ao sair. Do lado do motorista e, se ali houver parede,
## do outro lado — sair para dentro de um muro empurra o corpo para dentro do
## predio, e a recuperacao de penetracao o cospe no telhado.
func ponto_de_saida() -> Vector3:
	# Primeira tentativa pelo lado do motorista, que e -X.
	var lado := -global_transform.basis.x * (float(_medidas["largura"]) * 0.5 + 0.7)
	var espaco := get_world_3d().direct_space_state
	for tentativa: Vector3 in [lado, -lado]:
		var alvo := global_position + tentativa + Vector3.UP * 0.9
		var consulta := PhysicsRayQueryParameters3D.create(
			global_position + Vector3.UP * 0.9, alvo, 1)
		consulta.exclude = [get_rid()]
		if espaco.intersect_ray(consulta).is_empty():
			return global_position + tentativa
	return global_position + Vector3.UP * 1.2


func assento() -> Vector3:
	return global_position - global_transform.basis.x * (
		float(_medidas["largura"]) * 0.22) + Vector3.UP * 0.5


func velocidade() -> float:
	return _velocidade


func marcha() -> int:
	var v := absf(_velocidade)
	for k in MARCHAS.size():
		if v < MARCHAS[k]:
			return k + 1
	return MARCHAS.size()


# --- ciclo ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_vivo += delta
	_desde_buzina += delta
	match motorista:
		Motorista.JOGADOR:
			_dirigir_jogador(delta)
		Motorista.IA:
			_dirigir_ia(delta)
		_:
			_velocidade = lerpf(_velocidade, 0.0, minf(1.0, 3.0 * delta))
	_girar_rodas(delta)
	_atualizar_luzes()
	_som.atualizar(absf(_velocidade), marcha(), ligado or motorista == Motorista.IA, delta)
	_assustar_quem_esta_perto()


# --- direcao do jogador -----------------------------------------------------

func _dirigir_jogador(delta: float) -> void:
	_velocidade = linear_velocity.dot(-global_transform.basis.z)

	if not ligado:
		engine_force = 0.0
		brake = FREIO_MAX * 0.5
		steering = move_toward(steering, 0.0, delta * 2.0)
		return

	var acelera := Input.get_action_strength(&"mover_frente")
	var freia := Input.get_action_strength(&"mover_tras")
	var esq := Input.get_action_strength(&"mover_esq")
	var dir := Input.get_action_strength(&"mover_dir")

	# Re: quem esta quase parado e segura o freio passa a andar para tras. E o
	# cambio automatico de todo jogo de carro que nao tem alavanca dedicada.
	if freia > 0.1 and _velocidade < 0.6:
		_re = true
	elif acelera > 0.1:
		_re = false

	if _re:
		engine_force = -FORCA_RE * freia
		brake = FREIO_MAX * acelera
	else:
		engine_force = FORCA_MOTOR * acelera
		# Freio de verdade em cima, freio motor embaixo. Sem o segundo, soltar o
		# acelerador deixa o carro navegando por vinte segundos.
		brake = FREIO_MAX * freia + (2.5 if acelera < 0.05 else 0.0)
	_freando = freia > 0.1 and not _re

	var limite := lerpf(ESTERCO_MAX, ESTERCO_MIN,
		clampf(absf(_velocidade) / VEL_ESTERCO_FECHADO, 0.0, 1.0))
	steering = move_toward(steering, (esq - dir) * limite, delta * 2.6)


# --- direcao da IA ----------------------------------------------------------

func _dirigir_ia(delta: float) -> void:
	if not _tem_rota:
		_iniciar_rota()

	_atualizar_aproximacao()
	_atualizar_pisca(delta)

	var sinal := _sinal_manda_parar()
	var para_alvo := _mira_ia() - global_position
	para_alvo.y = 0.0

	# Avancar rota: nao retarget com sinal vermelho (senao destino pula ~125 m e
	# o freio solta). Antecipa so UMA vez por cruzamento (destino == _aproxima).
	if _curvando:
		if para_alvo.length() < CHEGOU:
			_escolher_destino()
			para_alvo = _mira_ia() - global_position
			para_alvo.y = 0.0
	elif not sinal:
		var d_centro := _dist_ao_centro(destino)
		var chegar := para_alvo.length() < CHEGOU
		# Antecipar curva/reto enquanto ainda nao consumimos este cruzamento.
		var antecipar := (destino == _aproxima and d_centro < ANTECIPAR_CURVA
			and d_centro > 0.8)
		if chegar or antecipar:
			_escolher_destino()
			para_alvo = _mira_ia() - global_position
			para_alvo.y = 0.0

	var teto := _teto_de_velocidade()
	var obstaculo := _obstaculo_a_frente()
	var alvo_vel := teto
	if sinal or obstaculo:
		alvo_vel = 0.0

	if alvo_vel > _velocidade:
		_velocidade = minf(alvo_vel, _velocidade + ACELERA * delta)
		_parado = 0.0
	else:
		_velocidade = maxf(alvo_vel, _velocidade - FREIA * delta)
	_freando = alvo_vel < _velocidade - 0.5

	if _velocidade < 0.4:
		_parado += delta
		_reclamar(obstaculo and not sinal)
	else:
		_parado = 0.0

	# Rumo. Mira na faixa a frente (termo lateral) ou no pivo da curva.
	if para_alvo.length() > 0.05:
		var quero := atan2(-para_alvo.x, -para_alvo.z)
		_giro = _aproximar_angulo(_giro, quero, 2.3 * delta)

	var frente := Vector3(-sin(_giro), 0.0, -cos(_giro))
	var nova := global_position + frente * _velocidade * delta
	nova.y = _altura_do_chao(nova)
	global_transform = Transform3D(Basis(Vector3.UP, _giro), nova)


## Velocidade permitida aqui. A avenida corre; a rua nao.
func _teto_de_velocidade() -> float:
	var v := (MalhaUrbana.via_x(cruzamento.x) if trecho.z == 0
		else MalhaUrbana.via_z(cruzamento.y))
	return VEL_AVENIDA if v == MalhaUrbana.Via.AVENIDA else VEL_CRUZEIRO


static func _aproximar_angulo(de: float, para: float, passo: float) -> float:
	var d := wrapf(para - de, -PI, PI)
	return de + clampf(d, -passo, passo)


func _altura_do_chao(onde: Vector3) -> float:
	var espaco := get_world_3d().direct_space_state
	var de := onde + Vector3.UP * 2.0
	var ate := onde + Vector3.DOWN * 2.0
	var excluir: Array[RID] = [get_rid()]
	# Teto de outro carro nao e chao: ignora Carro/Pedestre/player e tenta de novo.
	for _i in 4:
		var consulta := PhysicsRayQueryParameters3D.create(de, ate, 1)
		consulta.exclude = excluir
		var achado := espaco.intersect_ray(consulta)
		if achado.is_empty():
			return global_position.y
		var col: Object = achado.get("collider")
		if col is Carro or col is Pedestre or (col is Node
				and (col as Node).is_in_group(&"player")):
			if col is CollisionObject3D:
				excluir.append((col as CollisionObject3D).get_rid())
			continue
		return (achado["position"] as Vector3).y
	return global_position.y


## A rota inicial: o carro nasceu no meio de um quarteirao e ja tem faixa.
func _iniciar_rota() -> void:
	destino = Vias.proximo_cruzamento(cruzamento.x, cruzamento.y, trecho)
	_alvo = Vias.ponto_de_curva(destino.x, destino.y, trecho, trecho)
	_aproxima = destino
	_curvando = false
	_tem_rota = true
	_tem_plano = false
	_pisca_lado = 0


## O proximo ponto de mira. Chamada quando o carro chega no anterior.
##
## Sao dois tempos, e nao um. Ao chegar num cruzamento o carro escolhe a saida e
## mira na QUINA — o cruzamento das duas linhas de faixa dentro do cruzamento —
## e so depois de passar por ela e que mira no cruzamento seguinte. Sem esses
## dois tempos a curva e uma diagonal: o carro corta do meio de uma rua para o
## meio da outra, passando por cima da contramao e da calcada da esquina.
##
## Seguindo reto os dois tempos colapsam num so, e o metodo sai pelo caminho
## curto.
func _escolher_destino() -> void:
	if _curvando:
		# Ja passou pela quina. Daqui em diante e reta ate o proximo cruzamento.
		_curvando = false
		_pisca_lado = 0
		cruzamento = destino
		destino = Vias.proximo_cruzamento(cruzamento.x, cruzamento.y, trecho)
		_alvo = Vias.ponto_de_curva(destino.x, destino.y, trecho, trecho)
		# So obedece o sinal novo depois de limpar o cruzamento atual.
		return

	var cruz_atual := destino
	cruzamento = cruz_atual
	var anterior := trecho
	var saidas := Vias.saidas(cruzamento.x, cruzamento.y, anterior)
	if saidas.is_empty():
		# Fim de linha: a unica saida legal e voltar por onde veio. Acontece na
		# beira de uma faixa sem secundaria, e e raro.
		trecho = Vias.trecho(anterior.z, -anterior.w, anterior.x)
		_iniciar_rota()
		return

	# Pesa seguir reto. Sem isso o carro vira em toda esquina e o transito da a
	# impressao de que todo mundo esta perdido — que e o defeito mais visivel de
	# trafego procedural, e o mais facil de evitar.
	# Se a seta ja travou a saida (~1.5 s antes), respeita o plano.
	var escolha: Vector4i
	if _tem_plano and saidas.has(_saida_plana):
		escolha = _saida_plana
	else:
		escolha = saidas[0]
		if saidas.size() > 1 and randf() > 0.62:
			escolha = saidas[1 + randi() % (saidas.size() - 1)]
	_tem_plano = false

	trecho = escolha
	if escolha.z == anterior.z and escolha.w == anterior.w:
		# Reto (mesma direcao; pode ter mudado so a faixa na avenida).
		_pisca_lado = 0
		destino = Vias.proximo_cruzamento(cruzamento.x, cruzamento.y, trecho)
		_alvo = Vias.ponto_de_curva(destino.x, destino.y, trecho, trecho)
		# _aproxima continua no cruzamento que ainda estamos atravessando.
		return
	_curvando = true
	_pisca_lado = _lado_da_curva(anterior, escolha)
	_alvo = Vias.ponto_de_curva(cruzamento.x, cruzamento.y, anterior, escolha)
	# Se o pivo ja ficou para tras (decisao tarde), mira a frente na faixa de saida.
	var para_pivo := _alvo - global_position
	para_pivo.y = 0.0
	var dir_ant := Vias.direcao(anterior.z, anterior.w)
	if para_pivo.dot(dir_ant) < 1.0:
		var dir_sai := Vias.direcao(escolha.z, escolha.w)
		_alvo = global_position + dir_sai * 6.0
		if escolha.z == 0:
			_alvo.x = Vias.linha_x(cruzamento.x, escolha.w, escolha.x)
		else:
			_alvo.z = Vias.linha_z(cruzamento.y, escolha.w, escolha.x)


func _alinhar_na_faixa() -> void:
	var frente := Vias.direcao(trecho.z, trecho.w)
	_giro = atan2(-frente.x, -frente.z)
	global_rotation = Vector3(0.0, _giro, 0.0)


## Distancia horizontal ao centro de grade (i, j).
func _dist_ao_centro(ij: Vector2i) -> float:
	var centro := Vector3(float(ij.x) * Vias.TAM, global_position.y,
		float(ij.y) * Vias.TAM)
	return Vector2(centro.x - global_position.x, centro.z - global_position.z).length()


## Quando o carro passa do centro de _aproxima, passa a obedecer o destino novo.
func _atualizar_aproximacao() -> void:
	if _aproxima == Vector2i.ZERO:
		_aproxima = destino
		return
	if _aproxima == destino and not _curvando:
		return
	var centro := Vector3(float(_aproxima.x) * Vias.TAM, global_position.y,
		float(_aproxima.y) * Vias.TAM)
	var para := centro - global_position
	para.y = 0.0
	var frente := Vector3(-sin(_giro), 0.0, -cos(_giro))
	# Passou do centro e ainda perto o bastante para ser este cruzamento.
	if para.dot(frente) < 0.0 and para.length() < Vias.TAM * 0.5:
		_aproxima = destino


## Ponto de mira da IA: na curva o pivo; na reta, um ponto a frente NA FAIXA
## (corrige erro lateral residual que empurraria o carro para a calcada).
func _mira_ia() -> Vector3:
	if _curvando:
		return _alvo
	var dir := Vias.direcao(trecho.z, trecho.w)
	var olhada := 8.0
	var ate := _alvo - global_position
	ate.y = 0.0
	var dist := ate.length()
	var mira: Vector3
	if dist < olhada:
		mira = _alvo
	else:
		mira = global_position + dir * olhada
	# Trava a coordenada transversal na linha da faixa.
	# Eixo 0 (anda em Z): a via e a linha x = i; i e o mesmo em cruzamento e destino.
	if trecho.z == 0:
		mira.x = Vias.linha_x(cruzamento.x, trecho.w, trecho.x)
	else:
		mira.z = Vias.linha_z(cruzamento.y, trecho.w, trecho.x)
	return mira


# --- seta -------------------------------------------------------------------

## Lado da curva: +1 direita do carro (+X), -1 esquerda. 0 se nao e curva.
func _lado_da_curva(de: Vector4i, para: Vector4i) -> int:
	var a := Vias.direcao(de.z, de.w)
	var b := Vias.direcao(para.z, para.w)
	var cruz := a.cross(b).y
	if absf(cruz) < 0.05:
		return 0
	# Sistema destro, Y pra cima: cross.y > 0 vira a direita (mao brasileira).
	return 1 if cruz > 0.0 else -1


## Trava a proxima saida cedo o bastante para a seta piscar ~PISCA_S antes do pivo.
func _travar_saida() -> void:
	var saidas := Vias.saidas(destino.x, destino.y, trecho)
	if saidas.is_empty():
		return
	var escolha: Vector4i = saidas[0]
	if saidas.size() > 1 and randf() > 0.62:
		escolha = saidas[1 + randi() % (saidas.size() - 1)]
	_saida_plana = escolha
	_tem_plano = true
	if escolha.z != trecho.z or escolha.w != trecho.w:
		_pisca_lado = _lado_da_curva(trecho, escolha)
	else:
		_pisca_lado = 0


func _atualizar_pisca(delta: float) -> void:
	_pisca_tempo += delta
	if _curvando:
		return
	if not _tem_rota or _aproxima == Vector2i.ZERO:
		return
	# So planeja seta para o cruzamento que ainda vamos atravessar.
	if destino != _aproxima:
		return
	var d := _dist_ao_centro(destino)
	var alcance := maxf(_teto_de_velocidade() * PISCA_S, ANTECIPAR_CURVA + 4.0)
	if not _tem_plano and d < alcance and d > 1.0:
		_travar_saida()


# --- o que faz o carro parar ------------------------------------------------

## O sinal do proximo cruzamento manda parar?
##
## So conta dentro da faixa de retencao e so quando o carro ainda esta ANTES do
## cruzamento. Sem essa segunda condicao, um carro que entrou no verde e ficou
## no meio do cruzamento quando fechou trava ali para sempre, e a rua inteira
## para atras dele.
func _sinal_manda_parar() -> bool:
	var ij := _aproxima if _aproxima != Vector2i.ZERO else destino
	if not Semaforo.tem_sinal(ij.x, ij.y):
		return false
	var centro := Vector3(float(ij.x) * Vias.TAM, global_position.y,
		float(ij.y) * Vias.TAM)
	var para_centro := centro - global_position
	para_centro.y = 0.0
	var d := para_centro.length()
	var meia_cruz := (Vias.meia_z(ij.y) if trecho.z == 0 else Vias.meia_x(ij.x))
	var linha := meia_cruz + Vias.FOLGA_RETENCAO
	# Distancia de freio a partir da velocidade atual + folga de para-choque.
	var freio := (_velocidade * _velocidade) / (2.0 * FREIA) + Vias.FOLGA_RETENCAO
	var zona := maxf(RETENCAO, maxf(linha + 1.0, freio))
	if d > zona:
		return false
	# Ja passou da linha de retencao (centro atras da frente)?
	var frente := Vector3(-sin(_giro), 0.0, -cos(_giro))
	if para_centro.dot(frente) < 0.0:
		return false
	var eixo_sinal := trecho.z
	# Durante a curva o trecho ja virou: o sinal que importa e o do eixo de chegada.
	if _curvando:
		eixo_sinal = 1 - trecho.z
	var luz := Semaforo.estado(ij.x, ij.y, eixo_sinal, Semaforo.agora())
	if luz == Semaforo.Luz.VERDE:
		return false
	# No amarelo, quem nao consegue parar antes da linha passa.
	if luz == Semaforo.Luz.AMARELO and d < freio:
		return false
	return true


## Ha alguem a frente, dentro do corredor?
##
## Uma consulta de forma varrendo o corredor seria mais fiel e custaria uma por
## carro por quadro. Tres raios em leque custam um terco disso e erram so o caso
## de um obstaculo mais estreito que meio metro atravessado na faixa, que na
## pratica e um poste — e poste nao fica no meio da rua.
func _obstaculo_a_frente() -> bool:
	var espaco := get_world_3d().direct_space_state
	var frente := Vector3(-sin(_giro), 0.0, -cos(_giro))
	var direita := frente.cross(Vector3.UP)
	var origem := global_position + Vector3.UP * 0.6 + frente * (
		float(_medidas["comprimento"]) * 0.5 + 0.1)
	var alcance := OLHAR_A_FRENTE * clampf(_velocidade / VEL_CRUZEIRO, 0.35, 1.4)
	for lado: float in [0.0, CORREDOR * 0.7, -CORREDOR * 0.7]:
		var de := origem + direita * lado
		var consulta := PhysicsRayQueryParameters3D.create(de, de + frente * alcance, 1)
		consulta.exclude = [get_rid()]
		var achado := espaco.intersect_ray(consulta)
		if achado.is_empty():
			continue
		# Tipado a mao: Dictionary.get devolve Variant e o projeto trata
		# declaracao sem tipo como erro. Object aceita null, que e o que vem
		# quando o raio pegou algo sem no.
		var col: Object = achado.get("collider")
		# Predio nao conta: se um raio pegou parede, o carro esta fazendo curva e
		# a parede sai do caminho sozinha. Contam pessoa e carro.
		if col is Carro or col is Pedestre or (col is Node
				and (col as Node).is_in_group(&"player")):
			return true
	return false


# --- buzina e xingamento ----------------------------------------------------

## Buzina de quem esta preso, e nao de quem esta parado no sinal.
##
## A diferenca importa: uma cidade em que todo carro buzina no vermelho vira
## piada em trinta segundos. Aqui so reclama quem esta atras de alguem que nao
## anda — que e quando uma pessoa de verdade buzina.
func _reclamar(preso: bool) -> void:
	if not preso or ficha.is_empty():
		return
	if _parado > PACIENCIA and _desde_buzina > 3.4:
		_desde_buzina = 0.0
		_buzinar(_parado > PACIENCIA_XINGO)
	if _parado > PACIENCIA_XINGO and not _voz.playing:
		# Xingar e falar sem palavra, como toda voz deste jogo. O que identifica
		# o xingamento e a cadencia curta e a altura subindo, nao o conteudo.
		_voz.dizer(FalasNpc.xingamento(ficha))


func _buzinar(longa: bool) -> void:
	var nome := &"buzina_longa" if longa else &"buzina_curta"
	if not AudioDirector.tem(nome):
		return
	_buzina.stream = AudioDirector.stream(nome)
	_buzina.pitch_scale = 0.88 + float(absi(semente) % 40) / 100.0
	_buzina.play()


func buzinar() -> void:
	_buzinar(false)


# --- pedestres ---------------------------------------------------------------

## Quem passa perto demais leva um susto.
##
## A consulta so roda acima da velocidade de susto, porque um carro em fila
## andando a dois metros por segundo nao assusta ninguem — e assustar todo mundo
## que esta na calcada transformaria a rua num festival de gente pulando.
func _assustar_quem_esta_perto() -> void:
	if absf(_velocidade) < VEL_SUSTO:
		return
	if Engine.get_physics_frames() % 6 != 0:
		return
	for p: Node in get_tree().get_nodes_in_group(&"pedestre"):
		var ped := p as Pedestre
		if ped == null or not is_instance_valid(ped):
			continue
		var d := ped.global_position.distance_to(global_position)
		if d > RAIO_SUSTO:
			continue
		# So quem esta no asfalto: pedestre na calcada nao e "quase atropelado".
		if not Vias.no_asfalto(ped.global_position):
			continue
		ped.assustar(global_position, clampf(absf(_velocidade) / 14.0, 0.4, 1.0))
		# A buzina do susto e da IA. O carro do jogador nao buzina sozinho: a
		# buzina e uma coisa que ELE aperta, e um carro que toca a propria buzina
		# a cada pedestre que passa e um carro com defeito, nao com personagem.
		if motorista == Motorista.IA and _desde_buzina > 1.2:
			_desde_buzina = 0.0
			_buzinar(false)


# --- aparencia --------------------------------------------------------------

func _girar_rodas(delta: float) -> void:
	var giro := _velocidade / Carroceria.RAIO_RODA * delta
	_rolo_frente = wrapf(_rolo_frente - giro, -PI, PI)
	_rolo_tras = wrapf(_rolo_tras - giro, -PI, PI)
	var ang := 0.0
	if motorista == Motorista.JOGADOR:
		ang = steering
	elif motorista == Motorista.IA:
		# Esterco visual = desvio entre rumo e mira.
		var para := _mira_ia() - global_position
		para.y = 0.0
		if para.length() > 0.1:
			var quero := atan2(-para.x, -para.z)
			ang = clampf(wrapf(quero - _giro, -PI, PI), -ESTERCO_MAX, ESTERCO_MAX)
	# Basis composta: yaw do esterco * pitch da rolagem. Evita corromper Euler
	# ao escrever rotation.y depois de rotate_x.
	if _eixo_frente != null:
		_eixo_frente.transform.basis = (
			Basis(Vector3.UP, ang) * Basis(Vector3.RIGHT, _rolo_frente))
	if _eixo_tras != null:
		_eixo_tras.transform.basis = Basis(Vector3.RIGHT, _rolo_tras)


func _cachear_luzes() -> void:
	if _luzes == null or _luzes.mesh == null:
		return
	var mesh := _luzes.mesh as ArrayMesh
	if mesh == null or mesh.get_surface_count() < 1:
		return
	_luz_arrays = mesh.surface_get_arrays(0)
	_luz_uv_base = (_luz_arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array).duplicate()
	_luz_i_esq.clear()
	_luz_i_dir.clear()
	# Depois da meia volta da carroceria, lanterna traseira fica em +Z; farol em -Z.
	var verts: PackedVector3Array = _luz_arrays[Mesh.ARRAY_VERTEX]
	for k in verts.size():
		if verts[k].z <= 0.05:
			continue
		if verts[k].x >= 0.0:
			_luz_i_dir.append(k)
		else:
			_luz_i_esq.append(k)


func _atualizar_luzes() -> void:
	var acesa := ligado or motorista == Motorista.IA
	if _farol != null:
		_farol.visible = acesa
	if _brasa != null:
		_brasa.visible = acesa
		_brasa.light_energy = 1.5 if _freando else 0.55
	var mat := _luzes.material_override as ShaderMaterial
	if mat != null:
		var energia := 0.08
		if acesa:
			energia = 3.4 if (_freando or _re) else 2.4
			if _pisca_lado != 0:
				energia = maxf(energia, 2.8)
		mat.set_shader_parameter("emission_energy", energia)
	_aplicar_atlas_lanternas()


## Troca a celula do atlas nas lanternas traseiras: freio, re e seta amarela.
## Sem draw call extra - mesma malha, so UV.
func _aplicar_atlas_lanternas() -> void:
	if _luz_uv_base.is_empty() or _luzes == null:
		return
	var celula := Carroceria.C_LANTERNA
	if _re:
		celula = Carroceria.C_RE
	elif _freando:
		celula = Carroceria.C_FREIO
	var pisca_aceso := (_pisca_lado != 0
		and fposmod(_pisca_tempo, PISCA_PERIODO) < PISCA_PERIODO * 0.5)
	var chave := (int(celula.x) | (int(celula.y) << 4)
		| ((_pisca_lado & 3) << 8) | ((1 if pisca_aceso else 0) << 10))
	if chave == _luz_chave:
		return
	_luz_chave = chave
	var uvs := _luz_uv_base.duplicate()
	var base := Carroceria.uv(Carroceria.C_LANTERNA).position
	var delta := Carroceria.uv(celula).position - base
	var delta_pisca := Carroceria.uv(Carroceria.C_PISCA).position - base
	for k in _luz_i_esq:
		uvs[k] = _luz_uv_base[k] + (
			delta_pisca if (pisca_aceso and _pisca_lado < 0) else delta)
	for k in _luz_i_dir:
		uvs[k] = _luz_uv_base[k] + (
			delta_pisca if (pisca_aceso and _pisca_lado > 0) else delta)
	_luz_arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := _luzes.mesh as ArrayMesh
	if mesh == null:
		return
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _luz_arrays)


func triangulos() -> int:
	return int(_medidas.get("triangulos", 0))
