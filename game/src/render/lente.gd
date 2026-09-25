## Autoload. A LENTE do preset MODERNO: exposicao, obturador e foco.
##
##     godot --path game -- --sem-exposicao --sem-desfoque --sem-agx
##     godot --path game -- --desfoque-por-quadro   (o obturador de antes, par da bancada)
##
## Por que um no so para as tres coisas
## ------------------------------------
## Porque as tres sao a mesma coisa: propriedades de uma camera de verdade, e
## nao do mundo. O `Environment` responde a "como e o ar daqui"; o
## `FogController` responde a "que clima esta em vigor"; a `QualidadeGrafica`
## responde a "quanto esta maquina aguenta". Nenhum deles sabe dizer se o
## diafragma esta aberto ou quanto tempo o obturador ficou aberto — e essas duas
## perguntas tem a MESMA resposta fisica (a quantidade de luz que entrou), entao
## separa-las em dois donos seria garantir que um dia elas divergissem.
##
## O que ela escreve
## -----------------
## - **Exposicao automatica** (`CameraAttributesPractical`): o quarto escuro
##   abre, a rua clara fecha, e a passagem de um para o outro leva um tempo
##   medido (criterio A15).
## - **Tonemap AgX**: a curva que separa a lente do farol do letreiro atras dele
##   em vez de chapar os dois em branco.
## - **Sujeira de lente** (`glow_map`): o halo do poste nao e um circulo limpo;
##   ele passa pelo que tem no vidro.
## - **Desfoque de movimento**: so dirigindo, por `DesfoqueMovimento`.
## - **Profundidade de campo**: DESLIGADA no jogo, ligada so por quem pede
##   (cutscene e modo foto). E por isso que a API esta aqui e nao na cutscene:
##   quem garante que o jogo nao tem foco raso e o dono do estado, nao a boa
##   vontade de cada chamador.
##
## No PS1 STYLE tudo isto sai de cena. O console nao tinha exposicao nenhuma: o
## que passava do branco virava branco e pronto.
class_name LenteDaCamera
extends Node

## Os dois limites da exposicao automatica, em ISO.
##
## A semantica e a CONTRARIA da intuicao de fotografo, e custou uma rodada de
## medida: no Godot, a sensibilidade MINIMA e o piso da luminancia media que o
## medidor enxerga. Cena mais escura que o piso e tratada como se fosse o piso —
## e portanto o piso e o que LIMITA quanto uma cena escura clareia. A maxima e o
## teto da mesma luminancia, e limita quanto uma cena clara escurece.
##
## Medido na avenida a noite (mediana calibrada em 7 de 255 na Fase 4): com o
## piso em 40, a exposicao automatica levou a mediana a 31; baixar o TETO de 800
## para 125 nao mudou nada (31 de novo), porque o teto nao age em cena escura.
const ISO_TETO := 3200.0

## O piso, conforme o lugar: quanto o olho PODE abrir.
##
## E o que qualquer jogo com noite faz: o olho se acostuma a um comodo, mas a
## noite na rua continua noite. Calibrado pela rota de captura, contra as fotos
## da Fase 4 (sem exposicao automatica, tonemap filmico):
##
##   piso | avenida  viela  praca | apartamento
##   -----+-----------------------+------------
##    100 |  14/62   1/25  25/145 |   145/190
##    140 |   8/52   0/17  17/130 |   129/174
##    200 |   2/41   0/15  14/113 |   110/153
##   F4   |   7/42   1/17  16/112 |    94/140     (mediana/p95, de 0 a 255)
##
## A noite fica em 170: entre as duas linhas que cercam a Fase 4. O interior e o
## dia ficam em 100, e o que decide o interior e o quarto escuro da bancada: com
## piso 100 ele abre 1,95x (o criterio pede 1,6); com 170, so 1,36. De dia o piso
## quase nao age — cena clara fica acima dele —, e a exposicao faz o que devia:
## a viela abre (65 para 92) e a praca ao sol fecha (119 para 88).
const ISO_PISO_INTERIOR := 100.0
const ISO_PISO_DIA := 100.0
const ISO_PISO_NOITE := 170.0
## Segundos para o piso mudar de um lugar para o outro. Sem a rampa, sair de um
## interior para a rua a noite cortaria a exposicao no mesmo quadro.
const TEMPO_DO_PISO := 1.5

## Onde a exposicao mira, em luminancia linear. Abaixo do cinza medio de
## proposito: este jogo e noturno, e mirar no cinza de fotografo levanta a noite
## inteira ate o meio-tom.
const ALVO := 0.32

## Quanto a exposicao corre atras do alvo. A unidade do Godot e "por segundo".
##
## 1,4 poe o assentamento em torno de um segundo e meio, dentro do teto de 2 s do
## criterio A15 e acima do chao de 0,25 s — abaixo dele nao ha adaptacao, ha
## corte, que e exatamente o que o jogo fazia antes desta fase.
const VELOCIDADE := 1.4

## Multiplicador fixo da exposicao, aplicado depois da automatica.
const MULTIPLICADOR := 1.0

## Acima desta velocidade o desfoque de movimento comeca. Em metros por segundo.
##
## Seis, e nao dois: o jogador corre a 4,6 m/s (`Player.VEL_CORRER`), e correr na
## calcada nao pode borrar a rua. O criterio A15 diz "so dirigindo", e este
## numero e o que separa as duas coisas.
const VEL_MINIMA := 6.0
## Velocidade em que o obturador chega ao valor cheio. 16 m/s sao 58 km/h.
const VEL_CHEIA := 16.0
## Obturador de 180 graus: o rastro e metade do que o pixel andou no quadro.
const OBTURADOR := 0.5

## Forca da sujeira de lente sobre o glow.
##
## Baixa. A sujeira e um vidro sujo, nao um filtro: em 1,0 o halo do poste vira
## uma estrela de sete pontas e a cidade inteira ganha uma textura fixa colada na
## tela, que e o efeito mais barato de denunciar como truque. Em 0,28 a textura
## ja aparecia no ceu noturno; em 0,16 ela so se ve em volta de luz forte.
const SUJEIRA := 0.16
const SUJEIRA_ARQUIVO := "res://assets/textures_hd/lente_sujeira.hdr"

## A correcao de profundidade que o motor poe na frente de toda projecao antes
## de mandar para a GPU. Ver `_escrever_reprojecao`.
const CORRECAO := Projection(
	Vector4(1.0, 0.0, 0.0, 0.0),
	Vector4(0.0, -1.0, 0.0, 0.0),
	Vector4(0.0, 0.0, -0.5, 0.0),
	Vector4(0.0, 0.0, 0.5, 1.0))

signal exposicao_mudou(sensibilidade: float)

var _atrib: CameraAttributesPractical
var _desfoque: DesfoqueMovimento
var _compositor: Compositor
var _sujeira: Texture2D
var _env: Environment
var _fog: WorldEnvironment

var _sem_exposicao := false
var _sem_desfoque := false
var _sem_agx := false

## A vista-e-projecao do quadro passado, para o desfoque reprojetar.
var _vp_anterior := Projection()
var _tem_vp := false
## Onde a camera estava no quadro passado, para saber a que velocidade ela anda.
var _onde := Vector3.ZERO
var _tinha_onde := false
var _velocidade := 0.0
## Quanto tempo o valor da exposicao esta parado. E o que `assentada()` responde.
var _parada_ha := 0.0
var _ultima_forca := 0.0
## Obturador travado pela bancada. -1 devolve ao automatico. Existe pelo mesmo
## motivo que `--molhado=` existe no Clima: a medida de um par precisa mudar UMA
## coisa, e "a mesma velocidade, com e sem obturador" e o unico par que responde
## se o desfoque faz alguma coisa.
var _travado := -1.0
## Piso de sensibilidade fixado por bancada ou por `--iso-piso=`. -1 deixa o
## lugar decidir.
var _piso_forcado := -1.0
var _pior_caso := false
## A duracao de um quadro tipico, em segundos. Ver `_medir_velocidade`.
var _quadro_tipico := 0.0
## `--desfoque-por-quadro`: o obturador volta a durar o ultimo quadro. So e o par
## da bancada.
var _por_quadro := false


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--sem-exposicao":
			_sem_exposicao = true
		elif arg == "--sem-desfoque":
			_sem_desfoque = true
		elif arg == "--sem-agx":
			_sem_agx = true
		elif arg == "--desfoque-por-quadro":
			_por_quadro = true
		elif arg == "--obturador-pior":
			# Custo: o obturador aberto o tempo todo, com rastro fixo em toda a
			# tela. Parado, o rastro reconstruido e zero e o shader sai cedo —
			# e medir so isso seria medir o caso barato.
			_pior_caso = true
		elif arg.begins_with("--iso-piso="):
			# Calibracao: fixa o piso em qualquer lugar.
			_piso_forcado = arg.trim_prefix("--iso-piso=").to_float()
	_atrib = CameraAttributesPractical.new()
	_atrib.auto_exposure_min_sensitivity = ISO_PISO_NOITE
	_atrib.auto_exposure_max_sensitivity = ISO_TETO
	_atrib.auto_exposure_scale = ALVO
	_atrib.auto_exposure_speed = VELOCIDADE
	_atrib.exposure_multiplier = MULTIPLICADOR
	sem_foco()
	Settings.changed.connect(aplicar)
	get_tree().process_frame.connect(aplicar, CONNECT_ONE_SHOT)


## Reescreve a lente no ambiente da cena atual.
##
## Chamado pela troca de estilo e uma vez no primeiro quadro. Tambem vale ser
## chamado de fora quando alguem troca de cena: o `WorldEnvironment` e outro, e
## os atributos de camera vivem NELE.
func aplicar() -> void:
	_fog = get_tree().get_first_node_in_group(&"fog_controller") as WorldEnvironment
	if _fog == null:
		return
	_env = _fog.environment
	var moderno := Settings.luz_por_pixel

	# PS1 STYLE: nenhuma camera, nenhum diafragma, nenhum obturador.
	if not moderno:
		_fog.camera_attributes = null
		_fog.compositor = null
		if _env != null:
			_env.glow_map = null
		if _desfoque != null:
			_desfoque.enabled = false
		return

	_atrib.auto_exposure_enabled = not _sem_exposicao
	_fog.camera_attributes = _atrib

	if _env != null:
		# AgX, e nao filmico.
		#
		# O filmico do Godot e uma curva de contraste: ele levanta o meio-tom e
		# satura o que ja estava saturado. Numa rua noturna isso vira letreiro
		# vermelho fluorescente e farol branco chapado, os dois sem forma por
		# dentro. O AgX faz o contrario onde importa: ele DESSATURA o que estoura,
		# entao o miolo do farol vai para o branco por um caminho que tem
		# amarelo no meio — que e o que uma lente faz e o que da volume a fonte
		# de luz.
		if not _sem_agx:
			_env.tonemap_mode = Environment.TONE_MAPPER_AGX
		_env.glow_map = _textura_de_sujeira()
		_env.glow_map_strength = SUJEIRA

	_montar_desfoque()


func _montar_desfoque() -> void:
	if _sem_desfoque or _fog == null:
		return
	if _desfoque == null:
		_desfoque = DesfoqueMovimento.new()
		if _pior_caso:
			_desfoque.depurar = 1
			_travado = OBTURADOR
	if _compositor == null:
		_compositor = Compositor.new()
		_compositor.compositor_effects = [_desfoque]
	_fog.compositor = _compositor


func _process(delta: float) -> void:
	_medir_velocidade(delta)
	_acompanhar_exposicao(delta)
	_ajustar_piso(delta)


## Leva o piso de sensibilidade para o do lugar em que o jogador esta.
func _ajustar_piso(delta: float) -> void:
	var alvo := _piso_do_lugar()
	var atual := _atrib.auto_exposure_min_sensitivity
	if is_equal_approx(atual, alvo):
		return
	# A rampa e em PARADAS (escala logaritmica), e nao em ISO: de 40 para 800
	# sao quatro paradas e um terco, e andar isso em linha reta de ISO gastaria
	# quase todo o tempo no fim de cima, onde a diferenca nao se ve.
	var paradas := log(alvo / atual) / log(2.0)
	var passo := delta / TEMPO_DO_PISO * 4.3
	var andar := clampf(paradas, -passo, passo)
	_atrib.auto_exposure_min_sensitivity = atual * pow(2.0, andar)
	if absf(paradas) <= passo:
		_atrib.auto_exposure_min_sensitivity = alvo


## O piso que o lugar pede. Ver `ISO_PISO_INTERIOR`.
func _piso_do_lugar() -> float:
	if _piso_forcado > 0.0:
		return _piso_forcado
	if Interiores.dentro:
		return ISO_PISO_INTERIOR
	var preset: FogPreset = null
	if _fog is FogController:
		preset = (_fog as FogController).preset_atual()
	if preset != null and preset.hora_do_dia == FogPreset.HoraDoDia.DIA:
		return ISO_PISO_DIA
	return ISO_PISO_NOITE


## Fixa o piso de sensibilidade, para bancada e calibracao. -1 devolve ao lugar.
func forcar_piso(iso: float) -> void:
	_piso_forcado = iso
	if iso > 0.0:
		_atrib.auto_exposure_min_sensitivity = iso


## A velocidade da CAMERA, e nao a do jogador.
##
## De proposito: o que borra a imagem e o movimento da lente, e a lente e a
## mesma a pe, no carro e numa cutscene em trilho. Perguntar ao carro criaria
## dependencia de um sistema com trabalho de outra sessao e deixaria a cutscene
## de fora sem motivo.
##
## Giro NAO conta. Uma camera que so gira tem vetor de movimento cheio, e borrar
## ali e o defeito classico de desfoque de jogo: olhar em volta a pe faz o mundo
## derreter. O criterio A15 diz "so dirigindo", e dirigir e andar.
func _medir_velocidade(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or delta <= 0.0:
		_tinha_onde = false
		return
	# A lente como ela sai NA TELA (`Suavidade`): com o carro interpolado, a
	# posicao do passo de fisica anda aos saltos e o obturador piscaria junto.
	var agora := Suavidade.lente(camera).origin
	if not _tinha_onde:
		_onde = agora
		_tinha_onde = true
		return
	# Teleporte nao e velocidade. A rota de captura pula de parada em parada, e
	# entrar num interior tambem e um salto: sem este corte, o primeiro quadro
	# depois de cada salto sairia borrado de ponta a ponta.
	var passo := agora.distance_to(_onde) / delta
	_onde = agora
	if passo > 120.0:
		passo = 0.0
		_tem_vp = false
		# Salto e cena nova para o olho: a exposicao conta de novo daqui.
		_parada_ha = 0.0
	# Suaviza: o quique da caminhada e a fisica do carro fazem a velocidade
	# instantanea pular, e o obturador nao pode piscar junto.
	_velocidade = lerpf(_velocidade, passo, minf(1.0, delta * 6.0))

	if _desfoque == null:
		return
	_escrever_reprojecao(camera)
	var f := 0.0
	if Settings.luz_por_pixel and not _sem_desfoque:
		f = clampf(inverse_lerp(VEL_MINIMA, VEL_CHEIA, _velocidade), 0.0, 1.0) \
				* OBTURADOR
	if _travado >= 0.0:
		f = _travado
	_desfoque.forca = f * _obturador_estavel(delta)
	_desfoque.enabled = f > 0.0
	_ultima_forca = f


## Quanto o rastro deste quadro tem de encolher (ou esticar) para durar um
## quadro TIPICO.
##
## O vetor de movimento e o quanto o pixel andou NESTE quadro, entao o rastro
## crescia com a duracao do quadro: um quadro de 40 ms no meio de quadros de 7 ms
## borrava seis vezes mais, e cada engasgo acendia um clarao de rastro — que se
## le como "o desfoque travando" (24/09/2026). Com o obturador preso a duracao
## tipica, o regime borra o mesmo de sempre e o engasgo nao acende nada.
##
## A media anda em cerca de um segundo e cada quadro entra nela limitado ao
## dobro da media: um engasgo de 145 ms nao pode ensinar a ela que o quadro
## tipico e longo.
func _obturador_estavel(delta: float) -> float:
	if _quadro_tipico <= 0.0:
		_quadro_tipico = delta
	_quadro_tipico = lerpf(_quadro_tipico, minf(delta, _quadro_tipico * 2.0),
		minf(1.0, delta))
	if _por_quadro or _travado >= 0.0:
		return 1.0
	return clampf(_quadro_tipico / delta, 0.2, 1.5)


## A matriz que leva um ponto da tela DESTE quadro para a tela do anterior.
##
## Montada aqui, na linha principal, a partir da `Camera3D`: e uma convencao que
## se pode PROVAR. Conferida contra `unproject_position` e contra uma conta de
## reprojecao feita a mao — um poste a 5 m, com a camera andando 0,267 m por
## quadro, desloca 29,6 px, e o shader pinta 30,2.
##
## `CORRECAO` e o que o motor poe na frente de toda projecao antes de mandar
## para a GPU: vira o y (no Vulkan, y = -1 e em cima) e remapeia o z para a faixa
## de 0 a 1 invertida, a profundidade reversa com 1,0 no plano de perto. Sem o
## giro do y, o ponto projetado cai espelhado na vertical.
func _escrever_reprojecao(camera: Camera3D) -> void:
	# Pela lente INTERPOLADA (`Suavidade`): e com ela que o motor desenha o
	# quadro. Pela do passo de fisica, o rastro saia zero num quadro e dobrado
	# no seguinte.
	var vp: Projection = CORRECAO * camera.get_camera_projection() \
			* Projection(Suavidade.lente(camera).affine_inverse())
	# Sem quadro anterior (corte) o vetor de movimento do motor mede o salto
	# inteiro: o desfoque sai deste quadro.
	_desfoque.corte = not _tem_vp
	if _tem_vp:
		_desfoque.reprojecao = _vp_anterior * vp.inverse()
	else:
		# Sem quadro anterior nao ha de onde reprojetar. Identidade nao borra
		# nada, que e o certo para o primeiro quadro depois de um corte.
		_desfoque.reprojecao = Projection()
	_vp_anterior = vp
	_tem_vp = true


## Quanto tempo a exposicao esta parada, para quem precisa esperar por ela.
func _acompanhar_exposicao(delta: float) -> void:
	_parada_ha += delta


## A exposicao ja assentou? A rota de captura espera por isto antes de
## fotografar: sem a espera, duas execucoes da mesma parada pegam a lente em
## pontos diferentes da rampa e a regressao visual acusa diferenca que nao
## existe.
##
## A resposta e por TEMPO e nao por valor porque a sensibilidade em uso vive na
## GPU: o `CameraAttributes` guarda os limites, nao o ponto atual. Tres segundos
## sao o dobro do que a rampa medida leva (1,2 s).
func assentada() -> bool:
	if not Settings.luz_por_pixel or _sem_exposicao:
		return true
	return _parada_ha >= 3.0


## Diz que a camera saltou: a exposicao conta de novo daqui.
func recomecar() -> void:
	_parada_ha = 0.0
	_tinha_onde = false
	_velocidade = 0.0
	_tem_vp = false


## O valor cheio do obturador.
##
## Existe como METODO, e nao so como constante, por causa de uma armadilha do
## `--script`: uma bancada que escreva `LenteDaCamera.OBTURADOR` forca o motor a
## recompilar este arquivo num contexto onde os autoloads ainda nao sao
## identificadores, e a linha `Settings.changed.connect` deixa de compilar. O
## resultado e a lente inteira virar um `Node` pelado, sem mensagem que aponte
## para a causa. Perguntar a INSTANCIA nao recompila nada.
func obturador() -> float:
	return OBTURADOR


## Trava o obturador num valor. -1 devolve ao automatico. So bancada usa.
func travar_desfoque(valor: float) -> void:
	_travado = valor


## Liga um dos modos de diagnostico do `DesfoqueMovimento`: 0 nenhum, 1 rastro
## fixo, 2 tela vermelha, 3 rastro pintado. So bancada usa.
func depurar(modo: int) -> void:
	if _desfoque != null:
		_desfoque.depurar = modo


func chamadas_do_desfoque() -> int:
	return _desfoque.chamadas() if _desfoque != null else -1


## A forca do obturador agora, de 0 a `OBTURADOR`. Para teste e relatorio.
func forca_do_desfoque() -> float:
	return _ultima_forca


## A forca que o desfoque recebeu NESTE quadro, ja com `_obturador_estavel`.
## Para bancada: vezes a duracao do quadro, e o tempo de movimento no rastro.
func forca_aplicada() -> float:
	return _desfoque.forca if _desfoque != null and _desfoque.enabled else 0.0


## A velocidade da camera agora, em m/s. Para teste e relatorio.
func velocidade() -> float:
	return _velocidade


## Liga a profundidade de campo. SO cutscene e modo foto chamam isto.
##
## `distancia` e onde o foco cai, em metros; `forca` e o tamanho do circulo de
## confusao. O perto tambem desfoca, e a transicao e curta: foco raso que so
## borra o fundo le como filtro, nao como lente.
func focar(distancia: float, forca: float = 0.12) -> void:
	_atrib.dof_blur_far_enabled = true
	_atrib.dof_blur_far_distance = distancia
	_atrib.dof_blur_far_transition = maxf(distancia * 0.35, 1.0)
	_atrib.dof_blur_near_enabled = true
	_atrib.dof_blur_near_distance = maxf(distancia * 0.45, 0.4)
	_atrib.dof_blur_near_transition = maxf(distancia * 0.25, 0.6)
	_atrib.dof_blur_amount = forca


## Devolve a lente ao foco infinito do jogo.
func sem_foco() -> void:
	_atrib.dof_blur_far_enabled = false
	_atrib.dof_blur_near_enabled = false


## Ha profundidade de campo ligada agora? O criterio A15 cobra que a resposta
## seja NAO durante o jogo.
func profundidade_ligada() -> bool:
	return _atrib.dof_blur_far_enabled or _atrib.dof_blur_near_enabled


## Os atributos em uso, para bancada e para quem monta uma camera propria.
func atributos() -> CameraAttributesPractical:
	return _atrib


## A sujeira do vidro. Desenhada por `tools/gerar_decalques.py`.
##
## Em HDR, com neutro 1,0: o mapa MULTIPLICA o glow e a sujeira desvia para os
## dois lados — veu que come luz e poeira que a espalha, passando de 1.
##
## Era gerada aqui, com `set_pixel` — quase trezentas mil chamadas de GDScript
## no primeiro quadro. Em disco ela custa zero.
func _textura_de_sujeira() -> Texture2D:
	if _sujeira == null:
		_sujeira = load(SUJEIRA_ARQUIVO) as Texture2D
	return _sujeira
