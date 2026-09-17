## Chuva. Caixa de particulas que acompanha a camera.
##
## A chuva nao e simulada no mundo, e um volume pequeno colado na camera. E o que
## todo jogo faz, e o que o PS1 fazia: simular chuva num raio de 500 m para ver
## 20 m dela seria pagar caro por nada.
##
## A intensidade cai com a nevoa. Em nevoa densa a visibilidade e de 18 m e o
## risco de chuva simplesmente nao aparece; insistir nele so custa preenchimento.
class_name Chuva
extends GPUParticles3D

const SHADER := "res://shaders/psx_chuva.gdshader"

## Metade da caixa de emissao, em metros.
const CAIXA := Vector3(11.0, 1.0, 11.0)
## Altura da caixa acima da camera.
const ALTURA := 9.0

## Velocidade de queda da gota, em m/s. E o numero contra o qual a
## velocidade de quem olha e comparada: a 15 m/s de queda, alguem andando a
## 19 m/s (68 km/h) ve a chuva vindo a 52 graus da vertical.
const QUEDA := 15.0

## Teto da deriva, em m/s. Acima disto o risco deita quase na horizontal e a
## caixa de emissao — que tem 11 m de lado — nao alcanca mais a frente da
## camera: a chuva passaria a nascer atras de quem olha.
const DERIVA_MAX := 26.0

## Quanto a deriva medida alcanca a real por segundo. A camera desta cena
## acelera e desacelera junto com o carro, e o risco nao pode ir junto quadro
## a quadro — gota tem inercia, e chuva que muda de angulo instantaneamente
## le como troca de textura.
const DERIVA_SUAVE := 3.5

## Deslocamento num unico quadro que ja e CORTE, e nao movimento, em metros.
##
## A abertura da Estrada Velha troca de plano sete vezes, e em cada troca a
## camera pula dezenas de metros num quadro. Medida como velocidade, essa
## teleportacao daria mil metros por segundo de deriva e a chuva sairia
## deitada por meio segundo depois de todo corte. Meio metro por quadro sao
## 30 m/s, acima de qualquer coisa que ande nesta cena.
const CORTE := 0.5

@export_range(0, 3000, 50) var quantidade: int = 950
@export_range(0.0, 3.0, 0.05) var forca: float = 0.55
## Node3D seguido. Vazio faz a chuva procurar a camera ativa.
@export var alvo: Node3D

## Altura do CHAO onde o respingo bate, em metros de mundo.
##
## Existe porque o respingo era fixado em `y = 0,03`, que e o chao da cidade e
## de mais nada. A Estrada Velha e montada quatro mil metros acima da cidade
## (ver `AberturaEstrada.ALTURA`) — com a altura chumbada, a gota batia no
## asfalto da cidade, quatro quilometros abaixo do carro, e a chuva da estrada
## atravessava o leito sem tocar em nada. Nao dava erro nenhum: so nao havia
## respingo, e o olho registra que chuva e chao nao se encontram sem saber
## dizer por que.
##
## Quem monta a cena escreve aqui a altura do chao sob a camera, e reescreve
## quando ela muda — a estrada tem lombada, entao o numero anda.
@export var chao_y: float = 0.0

## Quanto quem ouve esta abrigado, de 0 a 1.
##
## Nao e `Interiores.dentro`: aquilo e sobre estar num COMODO, e apaga a chuva
## inteira. Isto e sobre ter alguma coisa entre a cabeca e o ceu — uma lataria,
## uma marquise — onde a chuva continua caindo e continua sendo ouvida, so que
## atraves de uma parede. A diferenca entre as duas e um dos sons mais
## reconheciveis que existem, e a abertura da Estrada Velha passa treze
## segundos dentro de um carro.
@export_range(0.0, 1.0, 0.05) var abrigo: float = 0.0

var _mat: ShaderMaterial
## O material de processo do risco. Guardado porque a direcao dele muda com
## a velocidade de quem olha, e busca-lo por `process_material` a cada
## quadro custa uma conversao de tipo para nada.
var _proc: ParticleProcessMaterial
## O salto da gota no chao. Ver `_montar_respingo`.
var _respingo: GPUParticles3D
var _mat_respingo: ShaderMaterial


## Som da chuva. Quem manda nele e este no, e nao a cena.
##
## Antes a cidade ligava o loop no _ready com volume fixo, e ele nunca mais era
## consultado: chovia no ouvido em preset de sol, e nao mudava de forca quando a
## chuva apertava. Duas verdades sobre o mesmo clima em dois arquivos, e so uma
## delas olhava o preset.
const SOM := &"chuva_loop"
## O mesmo aguaceiro ouvido de DENTRO de um carro: sem agudo, e com a batida
## no teto que so existe para quem esta debaixo dele.
const SOM_ABRIGADO := &"chuva_cabine_loop"
## Volume do aguaceiro cheio, em dB.
const VOL_CHEIO := -13.0
## Praticamente mudo. Nao e `parar_ambiente` porque o loop fica sempre no ar: um
## tocador que para e volta reabre o som do comeco, e o corte se ouve.
const VOL_MUDO := -60.0
## Quanto o volume anda por segundo, em dB. Chuva que entra e sai por corte le
## como bug; por rampa le como porta fechando.
const FADE := 16.0

## Ondas lentas de intensidade, em segundos.
##
## E aqui que a chuva deixa de soar como amostra em ciclo. O arquivo e ruido sem
## nenhum evento reconhecivel — nao ha estalo nem gota que se possa reconhecer
## voltando —, mas ruido de volume constante o ouvido tambem cansa em meio
## minuto e passa a ouvir "o loop". Duas ondas de periodo primo entre si sobre o
## volume dao um aguaceiro que aperta e afrouxa e que so se repete de verdade a
## cada onze minutos, que e mais tempo do que qualquer um passa parado na chuva.
const ONDA_LONGA := 41.0
const ONDA_CURTA := 17.0
## Amplitude da onda longa, em dB. A curta vale metade disto.
const ONDA_DB := 3.2

const FOG_GROUP := &"fog_controller"

## FogController da cena. E ele, nao Settings, que sabe o clima em vigor:
## dentro de um interior o controller impoe um preset proprio e a escolha de rua
## do jogador nao vale mais.
var _fog: FogController

## Forca da chuva em vigor, de 0 a 1. Sai do preset e alimenta som e particula.
var _intensidade: float = 0.0

## Velocidade horizontal de quem olha, em m/s, medida pela propria Chuva.
##
## Medida aqui, e nao recebida de fora, de proposito: quem se move nao e
## sempre a mesma coisa. Na cidade e o jogador correndo; na Estrada Velha e a
## camera de cinema, que ora esta presa ao carro a 68 km/h e ora esta fincada
## na beira da estrada sem se mexer. A Chuva ja segue essa camera — basta
## olhar quanto ela mesma andou.
var _deriva := Vector3.ZERO
var _pos_anterior := Vector3.INF
## Ultimo angulo escrito no material, para nao reescrever por nada.
var _deriva_escrita := Vector3.INF
var _volume: float = VOL_MUDO
var _volume_abrigado: float = VOL_MUDO
var _relogio: float = 0.0


## Liga este no ao preset em vigor. Sem controller na cena (cena de teste solta)
## cai em Settings, que ao menos reflete a escolha do jogador.
func _seguir_fog() -> void:
	_fog = get_tree().get_first_node_in_group(FOG_GROUP) as FogController
	if _fog != null:
		_fog.preset_applied.connect(_aplicar_preset)
	else:
		Settings.changed.connect(_aplicar_preset_de_settings)


## Leva o loop embora junto com a cena. Sem isto a chuva continua tocando na
## proxima cena, onde nao ha nem particula nem quem baixe o volume dela.
func _exit_tree() -> void:
	AudioDirector.parar_ambiente(SOM)
	AudioDirector.parar_ambiente(SOM_ABRIGADO)


func _aplicar_preset_de_settings() -> void:
	_aplicar_preset(Settings.fog_preset())


func _preset_ativo() -> FogPreset:
	return _fog.preset_atual() if _fog != null else Settings.fog_preset()

func _ready() -> void:
	# Achavel por grupo, e nao so pelo nome do no. Quem precisa dela e cena que
	# nao a criou (a abertura da Estrada Velha, que roda por cima da cidade), e
	# procurar por nome ja custou defeito mudo neste projeto: irmao homonimo e
	# renomeado em silencio pelo Godot e a busca devolve null sem erro nenhum.
	add_to_group(&"chuva")
	_montar()
	_seguir_fog()
	_aplicar_preset(_preset_ativo())
	# Entra mudo e sobe pela rampa do _process. Ligar aqui no volume final faria
	# a chuva estourar no primeiro quadro da cena, antes de a cidade aparecer.
	AudioDirector.ambiente(SOM, VOL_MUDO)
	AudioDirector.ambiente(SOM_ABRIGADO, VOL_MUDO)


func _montar() -> void:
	amount = quantidade
	lifetime = 0.9
	preprocess = 0.9        # ja comeca chovendo, sem meio segundo de ceu limpo
	explosiveness = 0.0
	randomness = 1.0
	fixed_fps = 30          # ART-BIBLE secao 10: nada anima a 60 aqui
	interpolate = false
	local_coords = false
	visibility_aabb = AABB(-CAIXA - Vector3(0, ALTURA, 0), (CAIXA + Vector3(0, ALTURA, 0)) * 2.0)
	draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH

	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc.emission_box_extents = CAIXA
	proc.direction = Vector3(0.0, -1.0, 0.0)
	proc.spread = 2.0
	proc.initial_velocity_min = QUEDA * 0.87
	proc.initial_velocity_max = QUEDA * 1.13
	proc.gravity = Vector3(0.0, -6.0, 0.0)
	# Vento leve e constante. Chuva perfeitamente vertical parece cenario de
	# tutorial; um angulo pequeno ja da a sensacao de tempo ruim.
	proc.linear_accel_min = 0.4
	proc.linear_accel_max = 0.9
	_proc = proc
	proc.color = Color(1.0, 1.0, 1.0, 1.0)
	proc.scale_min = 0.7
	proc.scale_max = 1.25
	process_material = proc

	# Quad alto e fino: o risco vem da forma, nao de motion blur.
	var quad := QuadMesh.new()
	quad.size = Vector2(0.028, 0.42)
	quad.orientation = PlaneMesh.FACE_Z
	draw_pass_1 = quad

	_mat = ShaderMaterial.new()
	_mat.shader = load(SHADER)
	material_override = _mat

	# Alinhado ao movimento: o risco aponta para onde a gota cai, e nunca deita,
	# porque chuva deitada nao existe.
	proc.particle_flag_align_y = true

	_montar_respingo()


## O que acontece quando a gota CHEGA.
##
## Sem isto a chuva atravessa o chao e desaparece, e o olho registra que os dois
## nao se tocam mesmo sem saber dizer por que. O anel de impacto no shader ja
## resolve a agua parada; o respingo e a parte que salta, e ele precisa ser
## geometria porque acontece ACIMA da superficie.
##
## Vive dentro da Chuva, e nao num no proprio, porque e a mesma chuva: quem sabe
## a forca do aguaceiro ja esta aqui, e dois nos disputando esse numero
## divergiriam no primeiro ajuste.
func _montar_respingo() -> void:
	_respingo = GPUParticles3D.new()
	_respingo.name = "Respingo"
	_respingo.lifetime = 0.32
	_respingo.preprocess = 0.3
	_respingo.randomness = 1.0
	_respingo.fixed_fps = 30
	_respingo.interpolate = false
	_respingo.local_coords = false
	_respingo.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	# A caixa de visibilidade e medida a partir do PROPRIO no, e o respingo se
	# coloca no chao — entao ela comeca meio metro abaixo dele e sobe dois.
	#
	# Ela descontava `ALTURA` aqui, o que so faria sentido se o respingo morasse
	# na origem da Chuva (nove metros acima da camera). Como ele tem posicao
	# propria, a caixa ficava nove metros e meio ABAIXO das particulas: o Godot
	# corta o emissor pela caixa, entao o salto da gota sumia sempre que esse
	# volume enterrado saia do tronco de visao — que e o caso em qualquer plano
	# olhando para o horizonte.
	_respingo.visibility_aabb = AABB(
		Vector3(-CAIXA.x, -0.5, -CAIXA.z),
		Vector3(CAIXA.x * 2.0, 2.0, CAIXA.z * 2.0))

	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	# Caixa achatada: o respingo nasce no plano do chao, nao num volume.
	proc.emission_box_extents = Vector3(CAIXA.x * 0.75, 0.02, CAIXA.z * 0.75)
	proc.direction = Vector3(0.0, 1.0, 0.0)
	# Espalhamento largo: a gota bate e abre em leque, nao sobe em coluna.
	proc.spread = 55.0
	proc.initial_velocity_min = 0.7
	proc.initial_velocity_max = 1.6
	proc.gravity = Vector3(0.0, -7.0, 0.0)
	proc.scale_min = 0.5
	proc.scale_max = 1.0
	_respingo.process_material = proc

	var quad := QuadMesh.new()
	quad.size = Vector2(0.022, 0.05)
	quad.orientation = PlaneMesh.FACE_Z
	_respingo.draw_pass_1 = quad

	_mat_respingo = ShaderMaterial.new()
	_mat_respingo.shader = load(SHADER)
	# Mais perto e mais curto que o risco de chuva: o respingo so existe no chao
	# em volta do jogador, e alem de oito metros vira sujeira na imagem.
	_mat_respingo.set_shader_parameter(&"perto", 0.4)
	_mat_respingo.set_shader_parameter(&"longe", 9.0)
	_mat_respingo.set_shader_parameter(&"cor", Color(0.78, 0.83, 0.88, 1.0))
	_respingo.material_override = _mat_respingo
	add_child(_respingo)


func _aplicar_preset(preset: FogPreset) -> void:
	if preset == null:
		return
	# Clima sem chuva: desliga tudo imediatamente.
	if not preset.tem_chuva:
		_intensidade = 0.0
		emitting = false
		amount = 50
		if _mat != null:
			_mat.set_shader_parameter(&"intensidade", 0.0)
		_ajustar_respingo(0.0)
		return
	# Com chuva: a intensidade ainda cai com a nevoa. Em nevoa densa a
	# visibilidade e de 18 m e o risco de chuva simplesmente nao aparece;
	# insistir nele so custa preenchimento.
	var f := 1.0
	if preset.fog_enabled:
		f = clampf(remap(preset.fog_end, 18.0, 45.0, 0.25, 0.8), 0.2, 1.0)
	_intensidade = f
	emitting = f > 0.05
	amount = maxi(50, int(quantidade * f))
	if _mat != null:
		_mat.set_shader_parameter(&"intensidade", forca * f)
	_ajustar_respingo(f)


## Liga o salto da gota a forca do aguaceiro.
##
## Desligado no PS1 STYLE pela mesma regra das pocas: la o preset e a build de
## antes, e conteudo novo de chuva nao entra. Nao e limitacao tecnica — e a
## promessa de que escolher PS1 STYLE devolve o jogo que existia.
func _ajustar_respingo(f: float) -> void:
	if _respingo == null:
		return
	var ligado := f > 0.05 and Settings.luz_por_pixel
	_respingo.emitting = ligado
	_respingo.amount = maxi(24, int(420.0 * f))
	if _mat_respingo != null:
		_mat_respingo.set_shader_parameter(&"intensidade", forca * f * 0.8)


func _process(delta: float) -> void:
	_atualizar_som(delta)
	var seguido := alvo
	if seguido == null:
		seguido = get_viewport().get_camera_3d()
	if seguido == null:
		return
	_medir_deriva(seguido.global_position, delta)
	# So a posicao, nunca a rotacao: a caixa girando junto com a cabeca faz a
	# chuva parecer presa ao olhar.
	global_position = seguido.global_position + Vector3(0.0, ALTURA, 0.0)
	if _respingo != null:
		# A caixa da chuva fica 9 m acima da camera; o respingo tem de ficar no
		# CHAO. Descer a altura inteira poe ele na altura dos pes, que e onde a
		# gota bate.
		_respingo.global_position = Vector3(
			seguido.global_position.x, chao_y + 0.03, seguido.global_position.z)


## Volume do loop de chuva neste quadro.
##
## O preset da o teto e as duas ondas dizem onde ele esta dentro dele. Sem chuva
## no preset o alvo e o silencio, e a rampa cuida da transicao — inclusive a de
## entrar num interior, onde o FogController impoe o preset do comodo e a chuva
## some do lado de fora da porta em pouco mais de tres segundos.
## Quanto quem olha andou, e o que isso faz com o angulo do risco.
##
## Chuva cai reta no referencial do CHAO. Quem se move ve ela vindo de
## frente, e o angulo sai da soma de dois vetores: a queda, para baixo, e a
## propria velocidade, ao contrario. A 68 km/h contra 15 m/s de queda isso
## da 52 graus — a chuva entra quase deitada no para-brisa, que e como ela
## de fato entra, e e a coisa que mais denuncia quando falta.
##
## Enquanto a chuva caia reta em cima de um carro a 68 km/h, os dois
## sistemas estavam ligados lado a lado sem se falar: um temporal correto e
## um carro correto, no mesmo quadro, contando historias diferentes.
func _medir_deriva(onde: Vector3, delta: float) -> void:
	var anterior := _pos_anterior
	_pos_anterior = onde
	if delta <= 0.0 or not anterior.is_finite():
		return
	var andou := onde - anterior
	andou.y = 0.0
	if andou.length() > CORTE:
		# Corte de plano, e nao movimento. Zera em vez de suavizar: suavizado,
		# o pico da teleportacao ainda sangraria por meio segundo no plano
		# seguinte, e o primeiro quadro depois do corte e justamente o que o
		# olho usa para ler o enquadramento novo.
		_deriva = Vector3.ZERO
		return
	var agora := andou / delta
	if agora.length() > DERIVA_MAX:
		agora = agora.normalized() * DERIVA_MAX
	_deriva = _deriva.lerp(agora, clampf(delta * DERIVA_SUAVE, 0.0, 1.0))
	_aplicar_deriva()


## Escreve o angulo e a velocidade do risco no material de processo.
##
## So quando anda de verdade: escrever num `ParticleProcessMaterial` invalida
## o estado do emissor no servidor de render, e fazer isso sessenta vezes por
## segundo para mover a terceira casa decimal de um angulo e o tipo de custo
## que nao aparece em captura nenhuma e aparece no fps de quem joga.
func _aplicar_deriva() -> void:
	if _proc == null:
		return
	if _deriva.distance_to(_deriva_escrita) < 0.35:
		return
	_deriva_escrita = _deriva
	# A gota vem DE onde quem olha esta indo: velocidade ao contrario, somada
	# a queda. O `align_y` do emissor deita o quad na direcao do movimento,
	# entao inclinar a direcao ja inclina o risco desenhado.
	var v := Vector3(0.0, -QUEDA, 0.0) - _deriva
	var rapidez := v.length()
	_proc.direction = v / maxf(rapidez, 0.001)
	_proc.initial_velocity_min = rapidez * 0.87
	_proc.initial_velocity_max = rapidez * 1.13


func _atualizar_som(delta: float) -> void:
	_relogio += delta
	var alvo_db := VOL_MUDO
	if _intensidade > 0.05:
		# A onda curta entra com metade da amplitude e fora de fase: e o que
		# impede as duas de baterem sempre no mesmo pico.
		var onda := sin(TAU * _relogio / ONDA_LONGA) * ONDA_DB
		onda += sin(TAU * _relogio / ONDA_CURTA + 1.3) * ONDA_DB * 0.5
		alvo_db = VOL_CHEIO + linear_to_db(_intensidade) * 0.6 + onda
	# Os dois loops andam JUNTOS e em sentidos opostos, e nunca um substitui o
	# outro por corte. Entrar num carro nao apaga a chuva la fora: ela fica mais
	# surda e mais longe, e a que aparece no lugar dela e a batida no teto. Um
	# corte entre as duas amostras le como troca de cena, que e o oposto do que
	# a costura precisa dizer.
	#
	# O teto de -9 dB no abrigo e a chuva la fora continuando a existir: mesmo
	# com a janela fechada ela nunca some, e apagar de vez deixa a cabine com um
	# silencio que so existe em estudio.
	var de_fora := alvo_db + lerpf(0.0, -9.0, abrigo)
	var de_dentro := alvo_db + lerpf(-40.0, 1.5, abrigo)
	_volume = move_toward(_volume, de_fora, FADE * delta)
	_volume_abrigado = move_toward(_volume_abrigado, de_dentro, FADE * delta)
	AudioDirector.volume_ambiente(SOM, _volume)
	AudioDirector.volume_ambiente(SOM_ABRIGADO, _volume_abrigado)
