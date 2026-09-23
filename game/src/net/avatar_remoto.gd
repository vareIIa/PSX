## O outro jogador, do jeito que este processo o ve.
##
## Nao e um `Player`. E um boneco: o mesmo `Corpo` que o jogador e os pedestres
## usam, montado com a aparencia que ele escolheu na carteira, andando pela trilha
## que a rede entrega (`BufferInterpolacao`). Sem camera, sem colisao, sem
## input, sem inventario, fora do grupo `player`.
##
## Por que um boneco e nao outra instancia de player.tscn
## -------------------------------------------------------
## O jogo inteiro descobre "o jogador" por `get_first_node_in_group(&"player")`
## (43 lugares em 21/09/2026, plano 06). Um segundo `Player` no grupo seria pego
## por metade deles — o GPS apontaria do corpo do amigo, a multidao seguiria o
## amigo, o save gravaria a posicao do amigo. O boneco fica fora do grupo, e
## nenhum desses lugares precisa mudar para o amigo aparecer na rua. E o papel
## que o Unreal chama de "simulated proxy": quem manda no corpo e a outra
## maquina; aqui ele so e desenhado.
##
## A regua do que o boneco mostra
## ------------------------------
## Um amigo olhando para voce deve entender o que voce esta fazendo sem ler o
## chat (plano 06 secao 4). Entao o boneco mostra: para onde a lanterna aponta
## (a arfagem da cabeca), o passo com som, o agachar, o sentar, o "esta no menu",
## e, no carro, o motorista atras do vidro, o farol, a luz de freio e as rodas
## rodando. Cada um desses sai do estado de 23 bytes, sem pacote a mais.
class_name AvatarRemoto
extends Node3D

## Ate onde o nome aparece sobre a cabeca, em metros. Alem disso a nevoa ja
## engoliu o corpo; nome flutuando no escuro seria o unico HUD de horror que
## mostra onde esta a pessoa.
const ALCANCE_NOME := 22.0
## Altura do olho, para a lanterna. A mesma do `Player`.
const OLHO := 1.62
## Olho de quem esta sentado no sofa (interiores.gd, `olho` do assento).
const OLHO_SENTADO := 0.86
## Quanto o boneco sentado recua para tras do ponto do jogador (ver `desenhar`).
const RECUO_SENTADO := 0.5
## Um passo a cada meio ciclo do balanco da camera, a mesma conta do
## `Player._atualizar_bob`: o amigo pisa no ritmo em que ele mesmo se ouve.
const PASSADA := PI / Player.BOB_FREQ
## Alem disso o passo do amigo nao toca. O `AudioDirector` ja atenua, e dezesseis
## pessoas andando longe viram chiado.
const ALCANCE_PASSO := 25.0
## Esterco maximo desenhado nas rodas da frente, em radianos.
const ESTERCO_MAX := 0.6

const MODELOS: Array[Carroceria.Modelo] = [
	Carroceria.Modelo.SEDA, Carroceria.Modelo.HATCH, Carroceria.Modelo.PERUA,
	Carroceria.Modelo.PICAPE, Carroceria.Modelo.TAXI, Carroceria.Modelo.MAREA,
	Carroceria.Modelo.FUSCA,
]

## Malhas de carro ja montadas, por "modelo:semente". Montar uma carroceria
## custa milissegundos, e o amigo que desce e sobe no mesmo carro nao deveria
## pagar de novo.
static var _carrocerias: Dictionary = {}
## As malhas da bicicleta, uma vez para todos os bonecos.
static var _quadro: Dictionary = {}

var id: int = 0
var nome: String = ""
var buffer := BufferInterpolacao.new()
## O ultimo estado desenhado. {} = nao desenhado.
var estado: Dictionary = {}
## A hora do servidor que o ultimo desenho representa. Quem mede (bot, teste)
## compara a posicao desenhada com a verdade NESTA hora.
var t_desenho: float = 0.0
## Passos tocados desde que o boneco nasceu. Para teste.
var passos_tocados: int = 0

var _suporte: Node3D
var _figura: Corpo
var _assinatura_aparencia: int = 0
var _rotulo: Label3D
var _lanterna: SpotLight3D
var _postura: int = -1

# --- carro ---
var _veiculo: Node3D
var _chave_veiculo: String = ""
var _medidas: Dictionary = {}
var _farol: SpotLight3D
var _fachos: Array[MeshInstance3D] = []
var _brasa: OmniLight3D
var _mat_luzes: ShaderMaterial
var _pinos_frente: Array[Node3D] = []
var _rodas_frente: Array[Node3D] = []
var _eixo_tras: Node3D
var _rolo: float = 0.0
var _esterco: float = 0.0
var _yaw_anterior: float = NAN

# --- bicicleta ---
var _bike: Node3D
var _bike_rodas: Array[Node3D] = []

# --- passos ---
var _andado: float = 0.0
var _pos_anterior := Vector3.INF


func configurar(novo_id: int, perfil: Dictionary) -> void:
	id = novo_id
	name = "p_%d" % novo_id

	# O mesmo arranjo do player.tscn: um no "Corpo" na origem (os pes), que
	# encolhe em Y quando agacha, e a figura dentro dele.
	_suporte = Node3D.new()
	_suporte.name = "Corpo"
	add_child(_suporte)

	_rotulo = Label3D.new()
	_rotulo.name = "Nome"
	var fonte := load(UiEstilo.FONTE_P) as Font
	_rotulo.font = fonte
	_rotulo.font_size = UiEstilo.tamanho_nativo(fonte)
	# Pixel grande o bastante para ler a dez metros na tela de 480x270.
	_rotulo.pixel_size = 0.011
	_rotulo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_rotulo.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_rotulo.shaded = false
	_rotulo.double_sided = true
	# Parede tapa o nome. Nome atravessando parede e parede de vidro.
	_rotulo.no_depth_test = false
	_rotulo.modulate = UiEstilo.PAPEL_ABERTO
	_rotulo.outline_size = 0
	add_child(_rotulo)

	# A lanterna do amigo e o que se ve dele na nevoa antes do corpo. Mesmos
	# numeros da `Player._montar_lanterna`, sem sombra (ART-BIBLE secao 7).
	_lanterna = SpotLight3D.new()
	_lanterna.name = "Lanterna"
	_lanterna.light_color = Color("fff0d0")
	_lanterna.light_energy = 4.2
	_lanterna.spot_range = 17.0
	_lanterna.spot_angle = 26.0
	_lanterna.spot_angle_attenuation = 0.9
	_lanterna.spot_attenuation = 1.1
	_lanterna.shadow_enabled = false
	_lanterna.visible = false
	_lanterna.position = Vector3(0.0, OLHO, 0.0)
	add_child(_lanterna)

	aplicar_perfil(perfil)


## Nome e aparencia. Remonta o corpo so se a aparencia mudou de verdade.
func aplicar_perfil(perfil: Dictionary) -> void:
	nome = String(perfil.get("nome", "VIAJANTE"))
	_rotulo.text = nome
	var aparencia: Dictionary = perfil.get("aparencia", {})
	var assinatura := hash(aparencia)
	if _figura != null and assinatura == _assinatura_aparencia:
		return
	if _figura != null:
		_figura.queue_free()
	_figura = Corpo.new()
	_figura.name = "Figura"
	_suporte.add_child(_figura)
	_figura.montar(aparencia)
	_assinatura_aparencia = assinatura
	_postura = -1
	_rotulo.position = Vector3(0.0, _figura.altura() + 0.32, 0.0)


## Desenha o estado `e`. `espaco_local` e onde o jogador desta maquina esta; so
## se desenha quem esta no mesmo espaco. `camera` e so para o nome e o passo.
func desenhar(e: Dictionary, delta: float, espaco_local: int, camera: Camera3D) -> void:
	estado = e
	if e.is_empty() or (espaco_local >= 0 and int(e.get("espaco", 0)) != espaco_local):
		_esconder()
		return
	var pos: Vector3 = e["pos"]
	# Na rua, so onde ESTA maquina tem chao (plano 07 secao 3.1). O interesse e
	# de 160 m e o raio de carga pode ser de 64: sem isto, o amigo a 120 m anda
	# sobre o nada e a lanterna dele acende uma nevoa sem chao. Sem chunk nenhum
	# (bot de teste, dedicado), nao ha o que conferir.
	if int(e.get("espaco", 0)) == ProtocoloRede.ESPACO_RUA \
			and ChunkManager.chunks_carregados() > 0 \
			and not ChunkManager.esta_carregado(ChunkManager.coord_de(pos)):
		_esconder()
		return
	visible = true
	var flags := int(e.get("flags", 0))
	var no_carro := (flags & ProtocoloRede.F_CARRO) != 0
	var na_bike := (flags & ProtocoloRede.F_BICICLETA) != 0 and not no_carro
	var sentado := (flags & ProtocoloRede.F_SENTADO) != 0 and not no_carro
	var agachado := (flags & ProtocoloRede.F_AGACHADO) != 0 and not no_carro
	var rapidez := float(e.get("rapidez", 0.0))
	var yaw := float(e.get("yaw", 0.0))
	global_position = pos
	rotation = Vector3(0.0, yaw, 0.0)

	if no_carro:
		_mostrar_veiculo(int(e.get("modelo", 0)), int(e.get("semente", 0)))
		_desenhar_carro(flags, rapidez, yaw, delta)
		# O amigo ao volante e um motorista como os do transito: o mesmo Corpo,
		# afundado no banco ate a cintura (carro.gd, _montar_motorista). O jogo nao
		# tem pose de volante, e atras do vidro o que se ve e tronco e cabeca.
		_suporte.position = Vector3(-float(_medidas["largura"]) * 0.24, -0.36,
			-float(_medidas["comprimento"]) * 0.04)
		_suporte.scale.y = 1.0
		_posar(Corpo.Postura.LIVRE)
		_figura.animar(0.0, delta, true)
	else:
		if _veiculo != null:
			_veiculo.visible = false
		_yaw_anterior = NAN
		# Sentado, o `Player` nao desce: o corpo fica no chao, na frente do movel,
		# e so a lente baixa (interiores.gd, `_assento`; o "onde" do sofa fica a
		# ~0,6 m do centro dele, na direcao da TV). O boneco senta DE VERDADE, entao
		# recua meio metro para o quadril cair no assento e o joelho ficar onde o
		# jogador esta.
		_suporte.position = Vector3(0.0, 0.0, RECUO_SENTADO if sentado else 0.0)
		_suporte.scale.y = (Player.ALTURA_AGACHADO / Player.ALTURA) if agachado else 1.0
		_posar(Corpo.Postura.ASSENTO if sentado else Corpo.Postura.LIVRE)
		# Quem pedala e animado parado, como o proprio Player (player.gd,
		# _na_bicicleta): o corpo vai de pe sobre o quadro.
		_figura.animar(0.0 if (sentado or na_bike) else rapidez, delta,
			(flags & ProtocoloRede.F_NO_CHAO) != 0 or na_bike)
	_mostrar_bicicleta(na_bike, rapidez, delta)

	# A lanterna vai presa a cabeca: altura do olho de quem esta agachado,
	# sentado ou pedalando, e apontada pela arfagem que o dono mandou.
	_lanterna.visible = (flags & ProtocoloRede.F_LANTERNA) != 0 and not no_carro
	var olho := OLHO
	if agachado:
		olho = OLHO * Player.ALTURA_AGACHADO / Player.ALTURA
	elif sentado:
		olho = OLHO_SENTADO
	elif na_bike:
		olho = Player.OLHO_NA_BICICLETA
	_lanterna.position.y = olho
	_lanterna.rotation.x = float(e.get("arfagem", 0.0))

	_passos(e, flags, rapidez, delta, camera)
	_desenhar_nome(flags, no_carro, camera)


func _esconder() -> void:
	visible = false
	_pos_anterior = Vector3.INF
	_yaw_anterior = NAN


func _posar(p: Corpo.Postura) -> void:
	if _postura == int(p):
		return
	_postura = int(p)
	_figura.postura(p)


## O nome sobre a cabeca. Esmaece com a distancia; com o dono no menu, fica meio
## apagado e ganha reticencias — o corpo parado no meio da rua tem motivo.
func _desenhar_nome(flags: int, no_carro: bool, camera: Camera3D) -> void:
	var ausente := (flags & ProtocoloRede.F_AUSENTE) != 0
	_rotulo.text = (nome + " ...") if ausente else nome
	var altura_nome := (1.9 if no_carro else _figura.altura() * _suporte.scale.y) + 0.32
	if (flags & ProtocoloRede.F_SENTADO) != 0 and not no_carro:
		altura_nome = OLHO_SENTADO + 0.5
	_rotulo.position.y = altura_nome
	if camera == null:
		_rotulo.visible = true
		return
	var d := camera.global_position.distance_to(global_position)
	_rotulo.visible = d < ALCANCE_NOME
	# Esmaece no ultimo terco do alcance, em vez de apagar num degrau.
	var a := clampf((ALCANCE_NOME - d) / (ALCANCE_NOME * 0.33), 0.0, 1.0)
	_rotulo.modulate.a = a * (0.5 if ausente else 1.0)


## O passo do amigo, no ritmo e na forca do passo do proprio jogador
## (`Player._ao_dar_passo`): madeira dentro de interior, concreto fora, nada
## agachado. A distancia conta so o que o boneco andou no chao, e um salto maior
## que dois metros e teletransporte, e nao passo.
func _passos(e: Dictionary, flags: int, rapidez: float, _delta: float, camera: Camera3D) -> void:
	var pos := global_position
	var anterior := _pos_anterior
	_pos_anterior = pos
	if anterior == Vector3.INF:
		return
	var anda_a_pe := (flags & (ProtocoloRede.F_CARRO | ProtocoloRede.F_BICICLETA
		| ProtocoloRede.F_SENTADO | ProtocoloRede.F_AGACHADO)) == 0 \
		and (flags & ProtocoloRede.F_NO_CHAO) != 0
	var passo := Vector2(pos.x - anterior.x, pos.z - anterior.z).length()
	if not anda_a_pe or passo > 2.0 or rapidez < 0.15:
		return
	_andado += passo
	if _andado < PASSADA:
		return
	_andado = fmod(_andado, PASSADA)
	passos_tocados += 1
	if camera == null or camera.global_position.distance_to(pos) > ALCANCE_PASSO:
		return
	var interior := int(e.get("espaco", 0)) >= ProtocoloRede.ESPACO_INTERIOR_BASE
	AudioDirector.passo(&"madeira" if interior else &"concreto", pos,
		clampf(rapidez / Player.VEL_CORRER, 0.25, 1.0))


# --- carro ------------------------------------------------------------------------

func _mostrar_veiculo(modelo: int, semente: int) -> void:
	var chave := "%d:%d" % [modelo, semente]
	if chave != _chave_veiculo:
		if _veiculo != null:
			_veiculo.queue_free()
		_veiculo = _montar_veiculo(modelo, semente)
		add_child(_veiculo)
		_chave_veiculo = chave
		_yaw_anterior = NAN
	_veiculo.visible = true


## Luzes e rodas do carro do amigo, pelo que o estado diz.
##
## Farol e lanterna acesos com o motor ligado, e a lanterna traseira mais forte
## freando: a mesma regra de `Carro._atualizar_luzes`, com os mesmos numeros.
## O esterco sai da taxa de giro: numa curva de raio R a roda da frente esterca
## atan(entre_eixos / R), e 1/R = taxa de giro / velocidade.
func _desenhar_carro(flags: int, rapidez: float, yaw: float, delta: float) -> void:
	var acesa := (flags & ProtocoloRede.F_FAROL) != 0
	var freando := acesa and (flags & ProtocoloRede.F_FREANDO) != 0
	_farol.visible = acesa
	for f: MeshInstance3D in _fachos:
		f.visible = acesa
		f.set_instance_shader_parameter(&"piscar", 1.0 if acesa else 0.0)
	_brasa.visible = acesa
	_brasa.light_energy = 1.5 if freando else 0.55
	if _mat_luzes != null:
		_mat_luzes.set_shader_parameter("emission_energy",
			(3.4 if freando else 2.4) if acesa else 0.08)

	var alvo := 0.0
	if not is_nan(_yaw_anterior) and delta > 0.0001 and rapidez > 0.5:
		var taxa := wrapf(yaw - _yaw_anterior, -PI, PI) / delta
		alvo = clampf(atan(float(_medidas.get("entre_eixos", 2.5)) * taxa / rapidez),
			-ESTERCO_MAX, ESTERCO_MAX)
	_yaw_anterior = yaw
	# Suaviza: a taxa de giro de duas amostras interpoladas treme, a roda nao.
	_esterco = lerpf(_esterco, alvo, minf(1.0, 10.0 * delta))
	# Frente em -Z: rolar para a frente gira a roda em -X.
	_rolo = fposmod(_rolo - rapidez / Carroceria.RAIO_RODA * delta, TAU)
	for pino: Node3D in _pinos_frente:
		pino.rotation.y = _esterco
	for r: Node3D in _rodas_frente:
		r.rotation.x = _rolo
	if _eixo_tras != null:
		_eixo_tras.rotation.x = _rolo


## A lataria de um `Carro` sem o carro: mesma malha, mesma tinta, mesmo lugar das
## rodas (carro.gd, _montar_lataria e _montar_eixos), mesmo farol, mesmos fachos
## e mesma brasa (carro.gd, _montar_luzes e _montar_fachos). O referencial e o do
## `Carro` — frente em -Z, farol em -comprimento/2 —, entao o giro que chega da
## rede se aplica direto.
func _montar_veiculo(modelo: int, semente: int) -> Node3D:
	var m := MODELOS[clampi(modelo, 0, MODELOS.size() - 1)]
	var chave := "%d:%d" % [int(m), semente]
	if not _carrocerias.has(chave):
		# A tinta sai da semente como no Carro (carro.gd, _montar). Se a regra de
		# la mudar, o amigo ve o carro de outra cor — o plano 20 lista isto.
		var tinta: Color = Carroceria.TINTAS[absi(semente * 7919) % Carroceria.TINTAS.size()]
		_carrocerias[chave] = Carroceria.montar(m, tinta, semente)
	_medidas = _carrocerias[chave]
	var material := load(Carroceria.MATERIAL) as ShaderMaterial

	var raiz := Node3D.new()
	raiz.name = "Veiculo"
	var lataria := MeshInstance3D.new()
	lataria.mesh = _medidas["corpo"]
	lataria.material_override = material
	lataria.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(lataria)
	var luzes := MeshInstance3D.new()
	luzes.mesh = _medidas["luzes"]
	# Um material de luz por carro: o brilho do freio e deste carro, e nao de
	# todos os carros que usam o mesmo recurso.
	var base_luz := load(Carroceria.MATERIAL_LUZ) as ShaderMaterial
	_mat_luzes = base_luz.duplicate() as ShaderMaterial if base_luz != null else null
	luzes.material_override = _mat_luzes
	luzes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(luzes)

	var eixo := float(_medidas.get("entre_eixos", 2.5)) * 0.5
	var meia_bitola := float(_medidas.get("bitola", 1.42)) * 0.5
	var comprimento := float(_medidas.get("comprimento", 4.2))
	_pinos_frente.clear()
	_rodas_frente.clear()
	for lado: float in [-1.0, 1.0]:
		# Um pino por roda, no centro dela: esterco em Y no pino, rolo em X na roda.
		# Esterco num eixo so leva as duas rodas num arco (memoria do projeto:
		# "eixo num no so esterca em arco").
		var pino := Node3D.new()
		pino.name = "RodaFrente%s" % ("E" if lado < 0.0 else "D")
		pino.position = Vector3(lado * meia_bitola, Carroceria.RAIO_RODA, -eixo)
		raiz.add_child(pino)
		var roda := MeshInstance3D.new()
		roda.mesh = _medidas["roda_dir"] if lado > 0.0 else _medidas["roda_esq"]
		roda.material_override = material
		roda.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pino.add_child(roda)
		_pinos_frente.append(pino)
		_rodas_frente.append(roda)
	var tras := MeshInstance3D.new()
	tras.mesh = _medidas["eixo_tras"]
	tras.material_override = material
	tras.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tras.position = Vector3(0.0, Carroceria.RAIO_RODA, eixo)
	raiz.add_child(tras)
	_eixo_tras = tras

	# Farol: um cone largo do meio do capo, como o Carro faz para caber no
	# orcamento de luz da cidade.
	_farol = SpotLight3D.new()
	_farol.name = "Farol"
	_farol.position = Vector3(0.0, 0.62, -comprimento * 0.5 + 0.1)
	_farol.rotation.x = deg_to_rad(Carro.FAROL_INCLINACAO)
	_farol.spot_range = 26.0
	_farol.spot_angle = 34.0
	_farol.spot_angle_attenuation = 0.9
	_farol.light_energy = 3.2
	_farol.light_color = Color(1.0, 0.95, 0.86)
	_farol.shadow_enabled = false
	_farol.visible = false
	raiz.add_child(_farol)
	_montar_fachos(raiz, luzes)

	_brasa = OmniLight3D.new()
	_brasa.name = "Brasa"
	_brasa.position = Vector3(0.0, 0.55, comprimento * 0.5)
	_brasa.omni_range = 3.0
	_brasa.light_energy = 0.55
	_brasa.light_color = Color(1.0, 0.22, 0.16)
	_brasa.shadow_enabled = false
	_brasa.visible = false
	raiz.add_child(_brasa)
	return raiz


## Os dois fachos na nevoa, no lugar dos farois da propria malha — exatamente a
## busca do `Carro._montar_fachos`, que pergunta a lataria onde estao os farois
## em vez de guardar uma tabela por modelo.
func _montar_fachos(raiz: Node3D, luzes: MeshInstance3D) -> void:
	_fachos.clear()
	var mesh := luzes.mesh as ArrayMesh
	var onde: Array[Vector3] = []
	if mesh != null and mesh.get_surface_count() > 0:
		var arrays := mesh.surface_get_arrays(0)
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		onde = Carroceria.farois(arrays, uvs)
	if onde.is_empty():
		onde = [_farol.position]
	var cor_f := Color(1.0, 0.95, 0.86, 0.55)
	var raio_fim := 1.55 if onde.size() > 1 else 2.4
	var mat_cone: Material = load(Carro.MAT_CONE) if ResourceLoader.exists(Carro.MAT_CONE) else null
	for k in onde.size():
		var f := MeshInstance3D.new()
		f.name = "Facho%d" % k
		f.mesh = PSXMesh.cone(0.09, raio_fim, Carro.FACHO_COMPRIMENTO, 8, 3,
			cor_f, Color(cor_f.r, cor_f.g, cor_f.b, 0.0))
		f.material_override = mat_cone
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f.sorting_offset = -1.0
		f.position = onde[k]
		f.rotation.x = PI * 0.5 + deg_to_rad(Carro.FAROL_INCLINACAO)
		f.visible = false
		raiz.add_child(f)
		_fachos.append(f)


# --- bicicleta --------------------------------------------------------------------

## A bicicleta debaixo do amigo, montada com as mesmas malhas da `Bicicleta`
## (`Quadro.montar`) e no mesmo arranjo, mas sem ser uma: nao entra no grupo
## `bicicleta`, entao o jogador local nao consegue subir nela.
func _mostrar_bicicleta(mostrar: bool, rapidez: float, delta: float) -> void:
	if not mostrar:
		if _bike != null:
			_bike.visible = false
		return
	if _bike == null:
		_bike = _montar_bicicleta()
		add_child(_bike)
	_bike.visible = true
	var giro := -rapidez / Quadro.RAIO_RODA * delta
	for r: Node3D in _bike_rodas:
		r.rotation.x = fposmod(r.rotation.x + giro, TAU)


func _montar_bicicleta() -> Node3D:
	if _quadro.is_empty():
		_quadro = Quadro.montar(Quadro.TINTAS[0])
	var material := load(Quadro.MATERIAL) as ShaderMaterial
	var raiz := Node3D.new()
	raiz.name = "Bicicleta"
	var quadro := MeshInstance3D.new()
	quadro.mesh = _quadro["quadro"]
	quadro.material_override = material
	quadro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(quadro)
	var guidao := Node3D.new()
	guidao.position = Vector3(0.0, 0.0, Quadro.EIXO_FRENTE)
	raiz.add_child(guidao)
	var mg := MeshInstance3D.new()
	mg.mesh = _quadro["guidao"]
	mg.material_override = material
	mg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	guidao.add_child(mg)
	var pedivela := MeshInstance3D.new()
	pedivela.mesh = _quadro["pedivela"]
	pedivela.material_override = material
	pedivela.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pedivela.position = Quadro.PEDALEIRA
	raiz.add_child(pedivela)
	_bike_rodas.clear()
	for par: Array in [[guidao, Vector3(0.0, Quadro.RAIO_RODA, 0.0)],
			[raiz, Vector3(0.0, Quadro.RAIO_RODA, Quadro.EIXO_TRAS)]]:
		var pivo := Node3D.new()
		pivo.position = par[1]
		(par[0] as Node3D).add_child(pivo)
		var m := MeshInstance3D.new()
		m.mesh = _quadro["roda"]
		m.material_override = material
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivo.add_child(m)
		_bike_rodas.append(pivo)
	return raiz


## Onde o boneco esta desenhado agora. Para teste e para o minimapa.
func posicao_desenhada() -> Vector3:
	return global_position
