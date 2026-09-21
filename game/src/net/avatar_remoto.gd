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
## (31 lugares, plano 06). Um segundo `Player` no grupo seria pego por metade
## deles — o GPS apontaria do corpo do amigo, a multidao seguiria o amigo, o save
## gravaria a posicao do amigo. O boneco fica fora do grupo, e nenhum desses 31
## lugares precisa mudar para o amigo aparecer na rua. E o papel que o Unreal
## chama de "simulated proxy": quem manda no corpo e a outra maquina; aqui ele so
## e desenhado.
##
## O boneco e o mesmo tanto para jogador a pe quanto ao volante: dentro de um
## carro o `Corpo` some e aparece a lataria do mesmo modelo, com a mesma tinta,
## sem fisica nenhuma.
class_name AvatarRemoto
extends Node3D

## Ate onde o nome aparece sobre a cabeca, em metros. Alem disso a nevoa ja
## engoliu o corpo; nome flutuando no escuro seria o unico HUD de horror que
## mostra onde esta a pessoa.
const ALCANCE_NOME := 22.0
## Altura do olho, para a lanterna. A mesma do `Player`.
const OLHO := 1.62

const MODELOS: Array[Carroceria.Modelo] = [
	Carroceria.Modelo.SEDA, Carroceria.Modelo.HATCH, Carroceria.Modelo.PERUA,
	Carroceria.Modelo.PICAPE, Carroceria.Modelo.TAXI, Carroceria.Modelo.MAREA,
	Carroceria.Modelo.FUSCA,
]

## Malhas de carro ja montadas, por "modelo:semente". Montar uma carroceria
## custa milissegundos, e o amigo que desce e sobe no mesmo carro nao deveria
## pagar de novo.
static var _carrocerias: Dictionary = {}

var id: int = 0
var nome: String = ""
var buffer := BufferInterpolacao.new()
## O ultimo estado desenhado. {} = nao desenhado.
var estado: Dictionary = {}
## A hora do servidor que o ultimo desenho representa. Quem mede (bot, teste)
## compara a posicao desenhada com a verdade NESTA hora.
var t_desenho: float = 0.0

var _suporte: Node3D
var _figura: Corpo
var _assinatura_aparencia: int = 0
var _rotulo: Label3D
var _lanterna: SpotLight3D
var _veiculo: Node3D
var _chave_veiculo: String = ""


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
	# O pitch da cabeca nao viaja (plano 04: e do olhar interno). A luz sai um
	# pouco para baixo, que e onde lanterna de quem anda aponta.
	_lanterna.rotation.x = deg_to_rad(-8.0)
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
	_rotulo.position = Vector3(0.0, _figura.altura() + 0.32, 0.0)


## Desenha o estado `e`. `espaco_local` e onde o jogador desta maquina esta; so
## se desenha quem esta no mesmo espaco. `camera` e so para o nome.
func desenhar(e: Dictionary, delta: float, espaco_local: int, camera: Camera3D) -> void:
	estado = e
	if e.is_empty() or (espaco_local >= 0 and int(e.get("espaco", 0)) != espaco_local):
		visible = false
		return
	visible = true
	var flags := int(e.get("flags", 0))
	var no_carro := (flags & ProtocoloRede.F_CARRO) != 0
	global_position = e["pos"]
	rotation = Vector3(0.0, float(e.get("yaw", 0.0)), 0.0)

	_suporte.visible = not no_carro
	if no_carro:
		_mostrar_veiculo(int(e.get("modelo", 0)), int(e.get("semente", 0)))
	else:
		if _veiculo != null:
			_veiculo.visible = false
		var agachado := (flags & ProtocoloRede.F_AGACHADO) != 0
		_suporte.scale.y = (Player.ALTURA_AGACHADO / Player.ALTURA) if agachado else 1.0
		_figura.animar(float(e.get("rapidez", 0.0)), delta,
			(flags & ProtocoloRede.F_NO_CHAO) != 0)
	_lanterna.visible = (flags & ProtocoloRede.F_LANTERNA) != 0 and not no_carro

	var altura_nome := (1.9 if no_carro else _figura.altura() * _suporte.scale.y) + 0.32
	_rotulo.position.y = altura_nome
	if camera == null:
		_rotulo.visible = true
		return
	var d := camera.global_position.distance_to(global_position)
	_rotulo.visible = d < ALCANCE_NOME
	# Esmaece no ultimo terco do alcance, em vez de apagar num degrau.
	_rotulo.modulate.a = clampf((ALCANCE_NOME - d) / (ALCANCE_NOME * 0.33), 0.0, 1.0)


func _mostrar_veiculo(modelo: int, semente: int) -> void:
	var chave := "%d:%d" % [modelo, semente]
	if chave != _chave_veiculo:
		if _veiculo != null:
			_veiculo.queue_free()
		_veiculo = _montar_veiculo(modelo, semente)
		add_child(_veiculo)
		_chave_veiculo = chave
	_veiculo.visible = true


## A lataria de um `Carro` sem o carro: mesma malha, mesma tinta, mesmo lugar das
## rodas (carro.gd, _montar_lataria e _montar_eixos). O referencial e o do
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
	var medidas: Dictionary = _carrocerias[chave]
	var material := load(Carroceria.MATERIAL) as ShaderMaterial

	var raiz := Node3D.new()
	raiz.name = "Veiculo"
	var lataria := MeshInstance3D.new()
	lataria.mesh = medidas["corpo"]
	lataria.material_override = material
	lataria.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(lataria)
	var luzes := MeshInstance3D.new()
	luzes.mesh = medidas["luzes"]
	luzes.material_override = load(Carroceria.MATERIAL_LUZ) as ShaderMaterial
	luzes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(luzes)

	var eixo := float(medidas.get("entre_eixos", 2.5)) * 0.5
	var meia_bitola := float(medidas.get("bitola", 1.42)) * 0.5
	for lado: float in [-1.0, 1.0]:
		var roda := MeshInstance3D.new()
		roda.mesh = medidas["roda_dir"] if lado > 0.0 else medidas["roda_esq"]
		roda.material_override = material
		roda.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		roda.position = Vector3(lado * meia_bitola, Carroceria.RAIO_RODA, -eixo)
		raiz.add_child(roda)
	var tras := MeshInstance3D.new()
	tras.mesh = medidas["eixo_tras"]
	tras.material_override = material
	tras.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tras.position = Vector3(0.0, Carroceria.RAIO_RODA, eixo)
	raiz.add_child(tras)
	return raiz


## Onde o boneco esta desenhado agora. Para teste e para o minimapa.
func posicao_desenhada() -> Vector3:
	return global_position
