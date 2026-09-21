## A TV de tubo, e a partida que esta passando nela.
##
## O gabinete nao esta aqui. Ele e feito de caixas e vai fundido na superficie
## do comodo, pelo mesmo motivo do poste de luz e do semaforo: caixa parada nao
## precisa de no, e no custa chamada de desenho. O que sobra para esta classe e
## o que MUDA — a imagem, a luz que ela joga na sala, e o chiado.
##
## Como a partida se move
## ----------------------
## E uma partida de verdade (PartidaPS2), desenhada em 2D num SubViewport de
## 320 x 240 e projetada no tubo pelo shader `tela_crt` — vidro curvo, linha de
## varredura, fosforo. Antes eram quatro celulas de atlas a oito quadros por
## segundo: de longe lia como futebol, sentado no sofa era um GIF. Na casa da
## fumaca a partida e de PS2 e da para jogar (ControlePS2); no bar e nas casas
## comuns ela e transmissao, com "AO VIVO" no canto.
##
## O SubViewport so desenha com a camera a menos de ALCANCE_IMAGEM: longe disso
## ninguem distingue a imagem, e a cidade tem uma TV em cada bar.
##
## A luz e a metade do trabalho
## ----------------------------
## Uma TV acesa num comodo escuro nao e um retangulo brilhante: e a coisa que
## pinta todo mundo de azul e faz a silhueta de quem esta sentado na frente. A
## luz aqui acompanha o quadro — muda de energia junto com a imagem — e e por
## isso que a sala parece ter uma televisao em vez de um cartaz iluminado.
##
## Modo estatica (abertura CRT)
## ----------------------------
## Na cinematic da abertura o tubo NAO mostra futebol: so neve/sopro de tubo.
## Quem liga isso e a cidade no boot; o gameplay da casa continua com a partida.
class_name Televisao
extends Node3D

const SHADER_TELA := "res://shaders/tela_crt.gdshader"
## O mesmo cone somado que o poste da rua usa. Ver `_montar_facho`.
const MATERIAL_CONE := "res://resources/materials/mat_cone_luz.tres"

## Distancia da camera ate a qual a partida e desenhada.
const ALCANCE_IMAGEM := 14.0
## Volume da torcida da TV do PS2, em dB, com a partida rolando.
const VOLUME_TORCIDA := -21.0

## Energia de referencia do facho. Tudo que mexe no brilho da TV — a troca de
## quadro, a neve da abertura — escala a partir DELA, e nao de numeros soltos.
## Sem isso, subir a luz da TV num lugar deixava os outros dois para tras e a
## mesma televisao brilhava diferente conforme o que estivesse passando nela.
const ENERGIA := 3.1

## Tamanho do tubo, em metros. Vinte e nove polegadas na diagonal, que era a TV
## grande de sala — o "tubao". A primeira versao tinha vinte polegadas e a
## captura mostrou o problema na hora: a TV virou um retangulo verde no fundo do
## comodo, e o comodo inteiro existe em funcao dela.
const TELA := Vector2(0.55, 0.42)

## A cor da luz que a partida joga na sala. Futebol e GRAMA: um tubo passando
## jogo pinta o comodo de verde-ciano, e nao do azul de filme que a TV tinha.
const COR_LUZ := Color(0.64, 0.90, 0.92)

## Brilho da imagem no MODERNO, acima de 1 de proposito: e o que o glow do
## Environment (corte em 1,25) le como fonte de luz. A 1,0 a tela era um
## retangulo verde chapado, igual a um cartaz.
const BRILHO_TELA := 1.75

## Quanto a luz da TV acende o volume de nevoa do MODERNO. E o feixe do tubo
## atravessando a fumaca, feito pela propria luz — no lugar do cone somado, que
## no MODERNO lavava a sala de cinza leitoso (captura 07_plano05 da v2).
const VOLUME := 2.2

@export var giro: float = 0.0
## PS2 (menu do Bomba Patch, radar, da para jogar) ou transmissao de TV.
@export var ps2: bool = false

var _tela: MeshInstance3D
var _malha_tela: ArrayMesh
var _vp: SubViewport
var _partida: PartidaPS2
var _desenhando: bool = true
var _luz: SpotLight3D
var _facho: MeshInstance3D
var _chiado: AudioStreamPlayer3D
## A torcida saindo do alto-falante do tubo. So na TV do PS2: o bar ja toca o
## mesmo loop de estadio pelo som ambiente dele.
var _torcida: AudioStreamPlayer3D
var _relogio: float = 0.0
var _conferir: float = 0.0
var _modo_estatica: bool = false
var _mat_partida: ShaderMaterial
var _mat_neve: StandardMaterial3D
var _malha_neve: ArrayMesh


func _ready() -> void:
	add_to_group(&"televisao")
	rotation.y = giro
	_montar_tela()
	_montar_luz()
	_montar_facho()
	_montar_chiado()
	if ps2:
		_montar_torcida()
	set_process(true)


func _montar_tela() -> void:
	_vp = SubViewport.new()
	_vp.name = "Imagem"
	_vp.size = Vector2i(PartidaPS2.LARGURA, PartidaPS2.ALTURA)
	_vp.disable_3d = true
	_vp.transparent_bg = false
	_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_partida = PartidaPS2.new()
	_partida.name = "Partida"
	_partida.transmissao = not ps2
	_vp.add_child(_partida)

	_mat_partida = ShaderMaterial.new()
	_mat_partida.shader = load(SHADER_TELA) as Shader
	_mat_partida.set_shader_parameter(&"tela", _vp.get_texture())
	_mat_partida.set_shader_parameter(&"brilho",
		BRILHO_TELA if Settings.luz_por_pixel else 1.0)
	_malha_tela = _malha_placa_cheia()
	_malha_neve = _malha_tela
	_mat_neve = StandardMaterial3D.new()
	_mat_neve.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_neve.albedo_color = Color(0.12, 0.13, 0.14)
	_mat_neve.emission_enabled = true
	_mat_neve.emission = Color(0.55, 0.58, 0.62)
	_mat_neve.emission_energy_multiplier = 1.35
	_tela = MeshInstance3D.new()
	_tela.name = "Tubo"
	_tela.mesh = _malha_tela
	_tela.material_override = _mat_partida
	_tela.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_tela)


## A partida desta TV. ControlePS2 pega por aqui.
func partida() -> PartidaPS2:
	return _partida


static func _malha_placa_cheia() -> ArrayMesh:
	var d := PSXMesh.placa_dados(TELA, 100.0, Color.WHITE)
	return PSXMesh.dados_para_mesh(d)


## A luz do tubo, em CONE e nao em esfera.
##
## Era uma Omni meio metro a frente da tela, e uma Omni ilumina para tras
## tambem: a moldura preta em volta do tubo, que esta dois centimetros e meio
## atras da imagem, ficava dentro do facho. Medido em captura, o "preto" do
## gabinete saia em (95, 92, 78) contra (70, 50, 30) da parede ao lado — ou
## seja, a moldura preta renderizava MAIS CLARA que o reboco, e a TV inteira
## virava um retangulo claro no fundo da sala.
##
## O cabecalho do CasaFumacaBuilder ja avisava contra exatamente esse resultado;
## na primeira vez o culpado foi a ordem em profundidade, e desta foi a luz. O
## mesmo defeito por dois caminhos diferentes.
##
## Um tubo joga luz PARA A FRENTE. Um cone de 78 graus apontado para a sala
## acende quem esta sentado, deixa a propria moldura no escuro e ainda alcanca a
## parede lateral — que e o que faz o azul da TV existir num comodo amber.
func _montar_luz() -> void:
	_luz = SpotLight3D.new()
	_luz.name = "Brilho"
	# Na boca do tubo. Como o no inteiro ja gira com `giro`, o cone acompanha
	# para onde a TV esta virada sem conta nenhuma aqui.
	_luz.position = Vector3(0.0, 0.0, 0.06)
	_luz.spot_range = 7.4
	_luz.spot_angle = 78.0
	# Queda suave: borda dura de spot num comodo pequeno le como lanterna, e o
	# que se quer e o derrame de uma tela.
	_luz.spot_angle_attenuation = 0.8
	_luz.spot_attenuation = 1.0
	_luz.light_energy = ENERGIA
	_luz.light_color = COR_LUZ
	_luz.shadow_enabled = false
	# Concorre a sombra como qualquer lampada: dentro de casa ela e a luz heroi,
	# e a sombra de quem joga cai no sofa e na parede de tras.
	_luz.add_to_group(DiretorSombra.GRUPO)
	_luz.light_volumetric_fog_energy = VOLUME
	add_child(_luz)
	# O cone aponta pelo -Z do PROPRIO no, e a tela olha para o +Z do no (e o
	# `giro` do prop que a vira para a sala). Sem esta meia volta o facho entra
	# na parede do fundo e a sala continua sem a luz da TV.
	_luz.rotation.y = PI


## O facho do tubo, em geometria somada.
##
## Por que a LUZ nao bastava
## -------------------------
## O cabecalho deste arquivo promete que a TV "pinta todo mundo de azul". Ela
## nao pintava, e a medida mostrou que nao ia pintar nunca: com a Omni trocada
## por cone e a energia em 3,1, os dois jogadores saiam 8,5 pontos mais frios
## que a parede atras deles — e subindo a energia para 14, de diagnostico, o
## chao ficou MAIS LARANJA, nao mais azul.
##
## A razao e albedo. `ALBEDO = texel * COLOR` e o piso desta sala e madeira em
## (164, 119, 78): o canal azul dela vale menos da metade do vermelho. Luz azul
## sobre superficie laranja da laranja mais claro, sempre — nao ha energia que
## inverta isso, e ainda ha o `grade_tint` quente do preset multiplicando a
## imagem inteira por cima.
##
## O que pinta de azul um comodo de albedo quente e o que sempre pintou em jogo
## de PS1: nao a superficie iluminada, e o AR entre a lente e ela. Este comodo e
## o melhor lugar do jogo para isso — ele tem quatro camadas de fumaca no teto e
## seis colunas subindo de cinzeiro, e um tubo de 29 polegadas jogando cone
## dentro daquilo e a imagem que a casa da fumaca existe para ter.
##
## E e o mesmo cone somado da Lampada, com o mesmo material e a mesma amarracao:
## `intensidade` vem de `facho_forca` do preset de nevoa, entao o facho so
## aparece onde ha ar para ele acender. Num comodo sem nevoa ele quase some, que
## e o contrato do efeito no projeto inteiro.
func _montar_facho() -> void:
	_facho = MeshInstance3D.new()
	_facho.name = "Facho"
	# A cor vai na MALHA e nao no material, porque o material e compartilhado com
	# todo poste da cidade. Mesma razao da Lampada.
	_facho.mesh = PSXMesh.cone(0.34, 1.70, 3.40, 8, 3,
		Color(0.58, 0.78, 1.0, 0.78), Color(0.58, 0.78, 1.0, 0.0))
	if not ResourceLoader.exists(MATERIAL_CONE):
		push_error("Televisao: material do facho ausente em %s" % MATERIAL_CONE)
		return
	_facho.material_override = load(MATERIAL_CONE)
	_facho.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Somado e translucido: entra depois de tudo que e opaco.
	_facho.sorting_offset = -1.0
	# O cone da PSXMesh nasce apontando para BAIXO, que e o que um poste quer.
	# Meia volta em X deita ele para o +Z do no, que e para onde a tela olha.
	_facho.rotation.x = -PI * 0.5
	_facho.position = Vector3(0.0, 0.0, 0.08)
	add_child(_facho)
	_facho.material_override.set_shader_parameter(
		&"intensidade", Settings.fog_preset().facho_forca)
	# No MODERNO o feixe e o volume de nevoa aceso pela propria luz (`VOLUME`).
	# O cone somado por cima dele e o que deixava a sala leitosa.
	_facho.visible = not Settings.luz_por_pixel


## O chiado do tubo.
##
## O arquivo tem dois segundos e o importador nao o marca como laco, porque o
## som e curto de proposito. Aqui ele tem de nao acabar, e quem repete e o
## servidor de audio — ver AudioDirector.em_loop para o porque de nao religar
## no sinal `finished`, que e como isto era antes e travava com o jogo em pausa.
func _montar_chiado() -> void:
	var s := AudioDirector.em_loop(&"tv_chiado")
	if s == null:
		return
	_chiado = AudioStreamPlayer3D.new()
	_chiado.name = "Chiado"
	_chiado.bus = &"SFX"
	_chiado.stream = s
	_chiado.max_distance = 6.0
	_chiado.unit_size = 1.4
	_chiado.volume_db = -24.0
	_chiado.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	add_child(_chiado)
	_chiado.play()


## Solta o tocador antes do no morrer. Sem isso o loop continuo fica pendurado
## segurando o stream quando o interior e descarregado, que e o mesmo "recurso
## ainda em uso na saida" que o AudioDirector evita nos ambientes.
func _exit_tree() -> void:
	if _chiado != null:
		_chiado.stop()
		_chiado.stream = null
	if _torcida != null:
		_torcida.stop()
		_torcida.stream = null


func _montar_torcida() -> void:
	var s := AudioDirector.em_loop(&"bar_estadio_loop")
	if s == null:
		return
	_torcida = AudioStreamPlayer3D.new()
	_torcida.name = "Torcida"
	_torcida.bus = &"SFX"
	_torcida.stream = s
	_torcida.max_distance = 7.0
	_torcida.unit_size = 1.2
	_torcida.volume_db = VOLUME_TORCIDA
	_torcida.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	# O alto-falante da TV e embaixo da tela.
	_torcida.position = Vector3(0.0, -0.3, 0.05)
	add_child(_torcida)
	_torcida.play()


## Neve/sopro de tubo — sem futebol. Usado na abertura CRT.
func mostrar_estatica(ligado: bool = true) -> void:
	_modo_estatica = ligado
	if _tela == null:
		return
	if ligado:
		# Sem partida por baixo da neve: o SubViewport para de desenhar.
		_desenhando = false
		_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_partida.process_mode = Node.PROCESS_MODE_DISABLED
		if _torcida != null:
			_torcida.stream_paused = true
		_tela.mesh = _malha_neve
		_tela.material_override = _mat_neve
		if _luz != null:
			_luz.light_color = Color(0.78, 0.8, 0.84)
			_luz.light_energy = ENERGIA * 0.71
		# CRT open: neve visual sim, chiado nao — cam colada no tubo
		# tornaria o loop finished->play ensurdecedor e eterno.
		if _chiado != null:
			_chiado.stop()
			_chiado.volume_db = -80.0
	else:
		_tela.mesh = _malha_tela
		_tela.material_override = _mat_partida
		if _luz != null:
			_luz.light_color = COR_LUZ
			_luz.light_energy = ENERGIA
		# Volta ao futebol: chiado de TV de sala (loop via finished).
		if _chiado != null:
			_chiado.volume_db = -24.0
			if not _chiado.playing:
				_chiado.play()


func _process(delta: float) -> void:
	_relogio += delta
	if _modo_estatica:
		# Neve: pisca a emissao e a luz, sem trocar UV de campo.
		var flicker := 0.55 + 0.45 * absf(sin(_relogio * 37.0)) + 0.15 * absf(sin(_relogio * 11.0))
		if _mat_neve != null:
			var g := 0.35 + 0.45 * flicker
			_mat_neve.emission = Color(g, g * 1.02, g * 1.05)
			_mat_neve.emission_energy_multiplier = 0.9 + flicker * 1.1
			_mat_neve.albedo_color = Color(0.08 + flicker * 0.1, 0.09 + flicker * 0.1, 0.1 + flicker * 0.1)
		if _luz != null:
			_luz.light_energy = ENERGIA * (0.50 + flicker * 0.58)
		return
	_conferir -= delta
	if _conferir <= 0.0:
		_conferir = 0.5
		_decidir_se_desenha()
	if _luz != null and _partida != null:
		# A luz segue a IMAGEM: campo joga verde-ciano, o menu joga azul, o gol
		# pisca. A cor da imagem vem misturada ao azul do fosforo — tubo nenhum
		# joga luz da cor exata do que mostra.
		var cor := _partida.cor_media()
		cor = Color(cor.r * 1.35, cor.g * 1.35, cor.b * 1.35 + 0.12)
		_luz.light_color = COR_LUZ.lerp(cor, 0.6)
		var pulso := _partida.brilho() * (0.94 + 0.06 * sin(_relogio * 23.0))
		_luz.light_energy = ENERGIA * pulso
		if _facho != null:
			_facho.scale = Vector3(pulso, 1.0, pulso)
	if _torcida != null and _partida != null:
		# O gol sobe a torcida, e o replay e o menu a baixam.
		var alvo := VOLUME_TORCIDA
		match _partida.estado:
			PartidaPS2.Estado.GOL:
				alvo = VOLUME_TORCIDA + 9.0
			PartidaPS2.Estado.MENU, PartidaPS2.Estado.FIM, PartidaPS2.Estado.INTERVALO:
				alvo = VOLUME_TORCIDA - 12.0
		_torcida.volume_db = move_toward(_torcida.volume_db, alvo, delta * 18.0)


## Longe da camera a imagem para de ser desenhada e a partida congela: nao ha
## quem veja, e sao 320 x 240 por TV de bar da cidade.
func _decidir_se_desenha() -> void:
	var cam := get_viewport().get_camera_3d()
	var perto := cam != null and cam.global_position.distance_to(global_position) < ALCANCE_IMAGEM
	if perto == _desenhando:
		return
	_desenhando = perto
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if perto 		else SubViewport.UPDATE_DISABLED
	_partida.process_mode = Node.PROCESS_MODE_INHERIT if perto 		else Node.PROCESS_MODE_DISABLED
	if _torcida != null:
		_torcida.stream_paused = not perto
