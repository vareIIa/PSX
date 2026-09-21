## A serra que fecha o horizonte da cidade: tres cristas de morro em volta de
## tudo, clareando com a distancia.
##
## Por que existe
## -------------
## Cidade de Minas e cidade no vale, e o que diz isso de longe e a serra em
## camadas atras do casario — a crista de perto mais escura, a de longe quase da
## cor do ceu. Sem ela a cidade acabava numa linha reta de nevoa, e a nevoa era o
## unico horizonte do jogo inteiro.
##
## Presa a camera, como a serra da Estrada Velha
## ---------------------------------------------
## Morro a esta distancia nao muda de tamanho enquanto se anda um quilometro.
## Seguindo a POSICAO da camera (e nao a rotacao) a serra fica sempre no fundo,
## nunca e alcancada, e cada direcao tem sempre a mesma crista: quem sobe a rua
## olhando para o norte ve sempre o mesmo morro, e isso orienta.
##
## Sem nevoa, pintada COMO se tivesse
## ----------------------------------
## Ela fica a mais de 240 m, alem de onde qualquer nevoa ja fechou: com nevoa de
## profundidade sairia exatamente da cor do fundo, invisivel. Entao ela e
## `disable_fog` e a nevoa entra na COR (`pintar`): na nevoa densa ela e da cor
## do fundo e some; no dia aberto as tres cristas se separam. Abaixo do
## horizonte ela e bruma de vale (`BRUMA_DIA`), e o saiote desce o bastante para
## nao haver fresta entre a cidade e ela.
##
## Nao escreve profundidade
## ------------------------
## Tudo o que a cidade desenha fica na frente dela, mesmo o que esta mais longe
## que o anel. E o borrao de movimento, que pula o pixel sem profundidade, a
## trata como ceu. As tres cristas saem numa malha so, da mais longe para a mais
## perto, e a ordem dos triangulos faz o papel da profundidade entre elas.
##
## Distancias
## ----------
## A cidade e desenhada ate ~215 m (dia de sol); as estrelas ficam a 320 m
## (CeuNoturno, `far * 0.88` limitado a 320). A serra mora entre as duas, e a
## camera do jogador corta em 420 m (player.tscn) para ela caber.
class_name SerraDaCidade
extends MeshInstance3D

const GRUPO := &"serra_da_cidade"
## Raio de cada crista, da de perto para a de longe.
const RAIOS: Array[float] = [248.0, 272.0, 296.0]
## Elevacao do cume de cada crista acima do horizonte, em graus. A de longe e
## mais alta: e a serra de verdade espiando por cima dos morros de perto.
const ELEVACAO: Array[float] = [3.0, 5.5, 8.5]
## Quanto cada crista escurece o fundo no cume, com a vista aberta.
const ESCURO: Array[float] = [0.5, 0.64, 0.8]
## Puxao para verde-musgo da crista de perto, de dia: mata na encosta.
const MATA := Color(0.36, 0.44, 0.36)
const MATA_DIA: Array[float] = [0.22, 0.12, 0.04]
const LADOS := 96
## Quanto a crista desce abaixo do horizonte. Do alto do morro da matriz o vale
## esta abaixo da linha do olho, e o fundo alem da cidade tem de ser serra.
const SAIOTE := 300.0
## O vale entre a cidade e a serra, de dia: terra na bruma, cinza-esverdeada.
## Com o pe na cor do ceu, do alto do morro da matriz a faixa abaixo do
## horizonte saia azul e lia como mar. A noite ele so escurece um pouco o fundo.
const BRUMA_DIA := Color(0.56, 0.6, 0.55)
const BRUMA := 0.6
const BRUMA_NOITE := 0.85
## Alcance da nevoa em que a serra comeca e termina de aparecer.
const VISTA := Vector2(40.0, 150.0)
## Acima disto a camera esta num interior (Interiores.DESLOCAMENTO, 2000 m).
const TETO_INTERIOR := 1000.0

## Quanto da cor da crista chega na linha do horizonte. Abaixo dela a serra e
## bruma (o vale entre a cidade e o morro); acima, silhueta. Com a crista em
## degrade direto do pe ao cume, do alto do morro da matriz a faixa abaixo do
## horizonte saia escura e reta, e lia como mar.
const NO_HORIZONTE := 0.65

## Por vertice: x = crista (0, 1, 2), y = 0 no pe, NO_HORIZONTE na linha do
## horizonte e 1 no cume.
var _marcas := PackedVector2Array()
var _arrays: Array = []
var _fog: FogController
var _preset: FogPreset
## `--sem-serra`: a mesma foto sem ela, para comparar em par.
var _sem_serra := OS.get_cmdline_user_args().has("--sem-serra")


func _ready() -> void:
	add_to_group(GRUPO)
	name = "SerraDaCidade"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = RAIOS[RAIOS.size() - 1] + SAIOTE
	_montar()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	# A cor sai do `sky_color` do preset, que e sRGB. Lida como linear, o pe da
	# crista nao batia com o fundo e a serra saia cinza lavado, mais clara que o
	# ceu — medido em par com `--sem-serra`: 147,168,175 contra 119,161,203.
	mat.vertex_color_is_srgb = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_fog = true
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material_override = mat
	visible = false


func _process(_delta: float) -> void:
	if _fog == null or not is_instance_valid(_fog):
		_fog = get_tree().get_first_node_in_group(&"fog_controller") as FogController
		if _fog == null:
			visible = false
			return
	var preset := _fog.preset_atual()
	if preset != _preset:
		_preset = preset
		if preset != null:
			pintar(preset)
	var cam := get_viewport().get_camera_3d()
	if cam == null or preset == null or _sem_serra:
		visible = false
		return
	global_position = cam.global_position
	visible = not preset.ceu_proprio and cam.global_position.y < TETO_INTERIOR


## Repinta as cristas a partir do fundo e da nevoa em vigor.
func pintar(preset: FogPreset) -> void:
	if _arrays.is_empty():
		return
	var fundo := preset.sky_color
	var vista := 1.0 if not preset.fog_enabled \
		else smoothstep(VISTA.x, VISTA.y, preset.fog_end)
	var dia := preset.hora_do_dia == FogPreset.HoraDoDia.DIA
	var bruma := fundo.lerp(BRUMA_DIA, BRUMA * vista) if dia \
		else fundo * lerpf(1.0, BRUMA_NOITE, vista)
	bruma.a = 1.0
	var cores := PackedColorArray()
	cores.resize(_marcas.size())
	for k in _marcas.size():
		var crista := int(_marcas[k].x)
		var cume := _marcas[k].y
		var cor := fundo
		if dia:
			cor = cor.lerp(MATA, MATA_DIA[crista] * vista)
		var f := lerpf(1.0, ESCURO[crista], vista)
		cor = Color(cor.r * f, cor.g * f, cor.b * f)
		cores[k] = bruma.lerp(cor, cume)
	var arrays := _arrays.duplicate()
	arrays[Mesh.ARRAY_COLOR] = cores
	var malha := mesh as ArrayMesh
	malha.clear_surfaces()
	malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func _montar() -> void:
	var v := PackedVector3Array()
	var c := PackedColorArray()
	var ix := PackedInt32Array()
	# Da crista de longe para a de perto: a ordem dos triangulos e a ordem de
	# desenho, e a de perto tem de cobrir a de longe.
	for crista in range(RAIOS.size() - 1, -1, -1):
		var raio: float = RAIOS[crista]
		var elev := tan(deg_to_rad(ELEVACAO[crista])) * raio
		for k in LADOS:
			var base := v.size()
			# Tres vertices por coluna: pe, horizonte e cume.
			for lado in 2:
				var ang := TAU * float(k + lado) / float(LADOS)
				var p := Vector3(sin(ang), 0.0, cos(ang)) * raio
				v.append(p + Vector3(0.0, -SAIOTE, 0.0))
				v.append(p)
				v.append(p + Vector3(0.0, perfil(ang, crista) * elev, 0.0))
				for marca: float in [0.0, NO_HORIZONTE, 1.0]:
					c.append(Color.WHITE)
					_marcas.append(Vector2(float(crista), marca))
			for faixa in 2:
				var a := base + faixa
				ix.append_array([a, a + 3, a + 1, a + 1, a + 3, a + 4])
	_arrays.resize(Mesh.ARRAY_MAX)
	_arrays[Mesh.ARRAY_VERTEX] = v
	_arrays[Mesh.ARRAY_COLOR] = c
	_arrays[Mesh.ARRAY_INDEX] = ix
	var malha := ArrayMesh.new()
	malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrays)
	mesh = malha


## O recorte da crista, entre 0 e 1, pelo angulo.
##
## Frequencias inteiras (a crista da a volta sem degrau na emenda) e coprimas
## entre si (o mesmo morro so volta depois da volta inteira), com fase propria
## por crista: tres serras, e nao a mesma silhueta repetida.
static func perfil(ang: float, crista: int) -> float:
	var fase := float(crista) * 2.1
	# Somas de meia-onda: cada seno vira uma fila de morros de topo redondo.
	var h := 0.22
	h += 0.42 * (0.5 + 0.5 * sin(ang * 3.0 + fase))
	h += 0.22 * (0.5 + 0.5 * sin(ang * 7.0 + 1.3 + fase * 0.7))
	h += 0.1 * (0.5 + 0.5 * sin(ang * 13.0 + 0.4 + fase * 1.9))
	h += 0.04 * (0.5 + 0.5 * sin(ang * 29.0 + 2.2 + fase * 0.3))
	return clampf(h, 0.05, 1.0)
