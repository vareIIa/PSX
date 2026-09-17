## O poente da estrada. Uma cupula presa na camera, com o degrade no shader.
##
## Segue a camera, e nao o carro
## -----------------------------
## Porque a cena tem tres cameras: a de dentro do carro, a que voa acima da
## copa e a que fica parada na beira vendo o carro passar. Um ceu preso ao carro
## sairia de quadro nas duas ultimas — a cupula tem 150 m e a camera alta esta a
## trinta metros do capo, o que basta para a borda de baixo entrar na imagem.
## Preso a camera corrente, nunca entra.
##
## O horizonte NAO e escolhido aqui
## --------------------------------
## Ele vem do preset de nevoa em vigor, sempre. E a regra do ART-BIBLE secao 8:
## na altura do olho a cor do ceu tem de ser exatamente a da nevoa, senao a
## juncao vira uma linha reta atravessada no fundo do quadro e o corte de
## desenho fica anunciado. O degrade so existe ACIMA dessa altura, que e onde
## nao ha mais mata para casar com nada.
class_name CeuEstrada
extends Node3D

const SHADER := "res://shaders/psx_ceu_estrada.gdshader"

## Raio da cupula. Tem de caber dentro do `far` de toda camera da cena — o
## `near`/`far` da camera cinematica e 0,05/600, e a de dentro do carro fica em
## 260. Cento e cinquenta passa folgado nas duas e nao chega perto do plano de
## corte, onde o quad seria fatiado no meio.
const RAIO := 420.0
## Vinte e quatro lados. O degrade e calculado por pixel, entao a malha so
## precisa ser redonda o bastante para a interpolacao da direcao nao facetar —
## e nao para desenhar a forma do ceu.
const LADOS := 24
const ANEIS := 12

## Tons do poente. O horizonte fica de fora de proposito: ver o cabecalho.
const BRASA := Color(0.94, 0.53, 0.26)
const ZENITE := Color(0.19, 0.18, 0.31)
const NUVEM := Color(0.35, 0.30, 0.37)

## Controller de nevoa a usar. Nulo = procura o global pelo grupo.
##
## Existe por causa do mundo proprio: num SubViewport com `own_world_3d` o
## controller local nao esta no grupo (ver `FogController.registrar_global`), e
## sem esta injecao a cupula ia buscar o horizonte no clima da CIDADE — o ceu
## de um lugar em cima da mata de outro, com a linha do horizonte na cor errada.
var fog: FogController

var _malha: MeshInstance3D
var _mat: ShaderMaterial
var _fog: FogController


func _ready() -> void:
	_montar()
	_montar_serra()
	_fog = fog
	if _fog == null:
		_fog = get_tree().get_first_node_in_group(&"fog_controller") as FogController
	if _fog != null:
		_fog.preset_applied.connect(_aplicar_preset)
		_aplicar_preset(_fog.preset_atual())
	else:
		_aplicar_preset(Settings.fog_preset())
	set_process(true)


## O material da cupula. Quem precisa dele e o `Relampago`: o clarao tem de
## acender o CEU tambem, e nao so a mata — no plano de cima o ceu e metade do
## quadro, e um raio que ilumina a floresta e deixa o fundo intacto le como
## holofote ligando, nao como descarga.
func material() -> ShaderMaterial:
	return _mat


func _montar() -> void:
	_malha = MeshInstance3D.new()
	_malha.name = "Cupula"
	var esfera := SphereMesh.new()
	esfera.radius = RAIO
	esfera.height = RAIO * 2.0
	esfera.radial_segments = LADOS
	esfera.rings = ANEIS
	_malha.mesh = esfera
	_mat = ShaderMaterial.new()
	if ResourceLoader.exists(SHADER):
		_mat.shader = load(SHADER)
	else:
		push_error("CeuEstrada: shader ausente em %s" % SHADER)
	_malha.material_override = _mat
	_malha.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Sem isto a cupula some assim que o centro dela sai do tronco de visao, que
	# acontece toda vez que a camera olha para o lado: o centro esta na propria
	# camera e a caixa que o Godot calcula para a esfera nao ajuda.
	_malha.extra_cull_margin = RAIO
	add_child(_malha)
	# `--sem-ceu`: esconde a cupula para ver se um vazio e vazio mesmo.
	#
	# A cupula e centrada na camera, entao ela e o FUNDO de qualquer buraco na
	# geometria — e como ela pinta com a cor da nevoa, buraco nao parece buraco:
	# parece uma superficie chapada sem textura. Esta cena ja perdeu o chao
	# inteiro assim, e depois uma fresta de dois pixels na beira da pista.
	# Escondendo a cupula, buraco volta a ser preto e o olho acha na hora.
	if OS.get_cmdline_user_args().has("--sem-ceu"):
		_malha.visible = false


## A serra do fundo: duas cristas de silhueta em volta do horizonte.
##
## Por que ela existe
## ------------------
## A mata e desenhada ate trinta e dois metros do eixo e a nevoa fecha em
## cinquenta e quatro. Da para dentro do carro isso basta — nao ha para onde
## olhar alem do corredor. Mas o plano de cima sobe acima da copa, e ali o fundo
## do quadro e o horizonte inteiro: sem nada, a mata simplesmente acaba numa
## linha reta de nevoa. Na print aerea o que fecha o fundo sao morros, e e o que
## diz que aquilo e o interior de Minas e nao um corredor de arvores qualquer.
##
## Presa a camera, como a cupula
## -----------------------------
## Morro a esta distancia nao muda de tamanho enquanto o carro anda um
## quilometro. Seguindo a POSICAO da camera (e nao a rotacao), a serra fica
## sempre no fundo e nunca e alcancada, que e o que faz ela ler como longe.
##
## Sem nevoa, mas pintada COMO se tivesse
## --------------------------------------
## Ela esta a cento e vinte metros, muito alem dos cinquenta e quatro em que a
## nevoa fecha: com nevoa de profundidade ela sairia exatamente da cor da nevoa,
## ou seja, invisivel. Entao ela e `fog_disabled` e a nevoa entra na COR — as
## cristas nascem de `fog_color`, so um pouco mais escuras. E o que a print
## mostra: morro que mal se separa da bruma.
const SERRA_RAIO := Vector2(300.0, 355.0)
const SERRA_LADOS := 48
## Elevacao maxima do cume, em graus acima do horizonte, por crista.
##
## Baixa de proposito. O plano aereo olha para BAIXO uns trinta graus, entao o
## horizonte ja fica no terco de cima do quadro e tudo que passa de uns seis
## graus acima dele sai pela borda de cima sem aparecer. Na print os morros
## encostam no ponto de fuga da estrada, e nao no topo do quadro.
const SERRA_ELEVACAO := Vector2(3.5, 6.0)
## Quanto a crista desce abaixo do horizonte. Fundo o bastante para nao existir
## fresta entre o pe da serra e a mata, que apareceria como um rasgo de ceu no
## meio do quadro aereo.
const SERRA_BASE := 120.0

var _serra: MeshInstance3D
var _mat_serra: StandardMaterial3D
## Por vertice: x = qual crista (0 perto, 1 longe), y = 0 no pe e 1 no cume.
## A cor sai destas marcas toda vez que o preset muda; a malha nunca muda.
var _serra_marcas: PackedVector2Array
var _serra_arrays: Array


func _montar_serra() -> void:
	var v := PackedVector3Array()
	var c := PackedColorArray()
	var i := PackedInt32Array()
	for crista in 2:
		var raio: float = SERRA_RAIO[crista]
		var elev: float = tan(deg_to_rad(SERRA_ELEVACAO[crista])) * raio
		# Fase diferente por crista, senao os dois morros tem o mesmo cume e a
		# serra vira uma silhueta so, com o dobro da espessura.
		var fase := 0.0 if crista == 0 else 2.3
		for k in SERRA_LADOS:
			var base := v.size()
			for lado in 2:
				var ang := TAU * float(k + lado) / float(SERRA_LADOS)
				var p := Vector3(sin(ang), 0.0, cos(ang)) * raio
				v.append(p + Vector3(0.0, -SERRA_BASE, 0.0))
				v.append(p + Vector3(0.0, _perfil(ang + fase) * elev, 0.0))
				# Marca a crista: 0 = pe, 1 = cume. O degrade sai no vertice.
				c.append(Color.WHITE)
				c.append(Color.WHITE)
				_serra_marcas.append(Vector2(float(crista), 0.0))
				_serra_marcas.append(Vector2(float(crista), 1.0))
			# Duas faces por segmento. A ordem do indice segue a regra do
			# KitEstrada.quad: e o INVERSO do produto vetorial que aparece.
			i.append_array([base, base + 2, base + 1,
				base + 1, base + 2, base + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_COLOR] = c
	arrays[Mesh.ARRAY_INDEX] = i
	_serra_arrays = arrays
	var malha := ArrayMesh.new()
	malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	_mat_serra = StandardMaterial3D.new()
	_mat_serra.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_serra.vertex_color_use_as_albedo = true
	_mat_serra.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_serra.disable_fog = true

	_serra = MeshInstance3D.new()
	_serra.name = "Serra"
	_serra.mesh = malha
	_serra.material_override = _mat_serra
	_serra.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_serra.extra_cull_margin = SERRA_RAIO.y
	# `--sem-ceu` esconde a serra TAMBEM. Ela e `fog_disabled` e pintada com a
	# cor da nevoa, entao ela tapa buraco exatamente como a cupula tapa — e por
	# um tempo o diagnostico apontou para o lugar errado porque so a cupula
	# sumia e o vazio continuava com cor.
	_serra.visible = not OS.get_cmdline_user_args().has("--sem-ceu")
	add_child(_serra)


## Repinta a serra a partir da nevoa em vigor.
##
## A crista de perto e mais escura que a de longe, e as duas escurecem do cume
## para o pe: e assim que serra empilhada na bruma se separa em camadas. Nenhuma
## delas se afasta muito de `fog_color`, senao vira recorte de papel preto colado
## no fundo — na print a serra mal se descola da bruma.
func _pintar_serra(preset: FogPreset) -> void:
	if _serra == null or _serra_arrays.is_empty():
		return
	var n := preset.fog_color
	var cores := PackedColorArray()
	cores.resize(_serra_marcas.size())
	for k in _serra_marcas.size():
		var m := _serra_marcas[k]
		# So o CUME e mais escuro que a nevoa; o pe e exatamente a cor dela.
		#
		# Isto nao e enfeite, e o que impede a serra de virar paredao. A malha
		# desce cento e vinte metros abaixo do horizonte para nao deixar fresta,
		# e como ela e `fog_disabled` esse saiote inteiro pinta por cima da nevoa
		# que deveria estar ali. Com o pe em qualquer tom mais escuro que a
		# nevoa, o que aparece no plano de cima e uma tarja escura atravessada no
		# fundo — foi exatamente o que aconteceu quando o raio subiu para 300 m.
		#
		# Com o pe em 1.0 o saiote e invisivel por construcao: ele existe, tapa a
		# fresta, e ninguem consegue dizer onde ele comeca.
		var cume := lerpf(0.55, 0.86, m.x)
		var f := lerpf(1.0, cume, m.y)
		cores[k] = Color(n.r * f, n.g * f, n.b * f)
	var arrays := _serra_arrays.duplicate()
	arrays[Mesh.ARRAY_COLOR] = cores
	var malha := _serra.mesh as ArrayMesh
	malha.clear_surfaces()
	malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


## O recorte da crista, entre 0 e 1, em funcao do angulo.
##
## Tres senos em razao nao inteira, pelo mesmo motivo da curva da estrada: com
## razao inteira o mesmo morro volta a cada volta e o horizonte vira papel de
## parede. Aqui o padrao so fecha depois de dar a volta inteira uma vez.
static func _perfil(ang: float) -> float:
	# Frequencias INTEIRAS, e coprimas entre si. Inteiras porque a crista da a
	# volta: com 7,3 o ultimo segmento nao encontra o primeiro e fica um degrau
	# na emenda do anel. Coprimas (3, 7, 17) porque o padrao ainda assim so
	# fecha depois da volta inteira, que e o que evita morro repetido.
	var h := 0.55 + 0.28 * sin(ang * 3.0)
	h += 0.17 * sin(ang * 7.0 + 1.1)
	h += 0.09 * sin(ang * 17.0 + 0.4)
	return clampf(h, 0.06, 1.0)


func _aplicar_preset(preset: FogPreset) -> void:
	if _mat == null or preset == null:
		return
	_mat.set_shader_parameter(&"cor_horizonte", preset.fog_color)
	# A noite nao tem poente, e o degrade de baixo do shader mistura `cor_brasa`
	# pela ALTURA, sem consultar o sol — `sol_forca` so apaga o borrao em volta
	# do azimute, nao a faixa. Com a brasa fixa, as 22:43 nascia uma faixa
	# laranja de vinte graus logo acima da mata, que e o oposto das prints: nelas
	# o que ha acima das copas e a propria nevoa, clara e fria.
	#
	# Entao no escuro a paleta sai da nevoa: um pouco mais clara logo acima do
	# horizonte (a nevoa e o que brilha) e bem mais escura no zenite.
	if not _tem_poente(preset):
		var n := preset.fog_color
		_mat.set_shader_parameter(&"cor_brasa",
			Color(n.r * 1.30, n.g * 1.30, n.b * 1.26))
		_mat.set_shader_parameter(&"cor_zenite",
			Color(n.r * 0.34, n.g * 0.36, n.b * 0.42))
		_mat.set_shader_parameter(&"cor_nuvem",
			Color(n.r * 0.62, n.g * 0.64, n.b * 0.70))
	else:
		_mat.set_shader_parameter(&"cor_brasa", BRASA)
		_mat.set_shader_parameter(&"cor_zenite", ZENITE)
		_mat.set_shader_parameter(&"cor_nuvem", NUVEM)
	_pintar_serra(preset)
	_mat.set_shader_parameter(&"nuvens", preset.nuvens)
	_mat.set_shader_parameter(&"sol_dir", _azimute_do_sol(preset))
	# Sol apagado e ceu sem poente. Vale para quando alguem apontar esta cupula
	# para um preset noturno por engano: o degrade continua, a brasa nao.
	_mat.set_shader_parameter(&"sol_forca",
		clampf(preset.sol_energia * 0.5, 0.0, 1.4))
## Ha poente para pintar neste ceu?
##
## A pergunta nao e "o sol esta aceso", e sim "o sol esta QUENTE". A brasa,
## o zenite roxo e a nuvem lilas sao as cores de um fim de tarde limpo; num
## temporal o sol continua aceso — a luz vem de um ceu coberto e ainda precisa
## dar forma a mata — mas ele e cinza-azulado, e nao ha brasa nenhuma no
## horizonte. So a energia como criterio punha uma faixa laranja de vinte graus
## acima das copas no meio da chuva, que e o mesmo defeito que a noite ja teve.
##
## Nenhum preset antigo muda de comportamento: `fog_estrada` tem sol
## (1, 0,69, 0,44) e continua com poente; os noturnos tem energia zero e
## continuam derivando da nevoa.
static func _tem_poente(preset: FogPreset) -> bool:
	return preset.sol_energia > 0.01 and preset.sol_cor.r > preset.sol_cor.b + 0.05



## Para que lado do horizonte o sol esta, no plano XZ.
##
## O preset guarda a rotacao da LUZ, que aponta para onde a luz VAI. O sol esta
## do lado oposto — e essa inversao e a diferenca entre a mata sair em contraluz
## e o poente nascer atras da camera, onde ninguem o ve.
static func _azimute_do_sol(preset: FogPreset) -> Vector2:
	var base := Basis.from_euler(Vector3(deg_to_rad(preset.sol_rotacao.x),
		deg_to_rad(preset.sol_rotacao.y), 0.0))
	var frente := base * Vector3(0.0, 0.0, -1.0)
	var plano := Vector2(-frente.x, -frente.z)
	if plano.length_squared() < 0.0001:
		return Vector2(0.0, -1.0)
	return plano.normalized()


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		global_position = cam.global_position
