## O crucifixo dos padres da estrada, numa corrente de ferro em volta do
## pescoco, com fisica propria: a cruz pesa, a corrente cede, as duas balancam
## e batem no peito por cima da murca.
##
## Por que existe
## --------------
## A batina do gerador trazia a cruz fundida no pano: uma haste dura saindo do
## pescoco e uma cruz de espada, parada no ar quando o padre se curvava. O
## pedido e a cruz de Jesus (crucifixo latino, com o Cristo), numa corrente de
## verdade, com peso, que cai para a frente quando ele se debruca no carro e
## volta a bater no peito quando ele se ergue. A cruz de madeira de caixa que o
## `CapuzMacabro` punha no osso do torso sai junto.
##
## A corrente ficava presa na borda da murca, 26 a 28 cm do pescoco, e solta no
## mundo: na cabecada e no estouro do vidro o tronco anda ate 19 cm num quadro, a
## cruz dava 24 cm de chicote, ia parar do lado da cara (180 quadros na frente
## dela, 120 dentro do cranio, de 42,5 a 54,6 s) e a corrente corria dentro do
## capuz e da murca: so 24 a 39% dos elos saiam na imagem, picotados. O pedido e
## a corrente em volta do pescoco, como um crucifixo de verdade, nunca na cara e
## sem piscar.
##
## Como funciona
## -------------
## Tudo em espaco de mundo (o no e `top_level`), em passos fixos de `PASSO`:
##   - a corrente da a volta na nuca por baixo do capuz (atras e dos lados ela
##     nao aparece e nao se simula) e sai dos lados do pescoco, rente a pele,
##     logo abaixo da queixada. Dali ela vai esticada pelo peso da cruz ate a
##     gola, no fundo do decote logo abaixo do queixo (as ancoras, no osso do
##     torso: `BatinaAAA.peito`), e da gola para baixo desce solta em V ate a
##     argola da cruz, por cima da roupa: `PONTOS` particulas por lado, que so
##     resistem a esticar (corrente nao empurra, amontoa);
##   - a cruz e um corpo rigido de quatro particulas (argola, pe e as pontas dos
##     bracos), mais pesadas que a corrente, com as seis distancias entre elas
##     exatas: gira, tomba e deita no peito;
##   - a corrente vai com o tronco (`SEGUE`): a cada quadro ela anda `SEGUE` do
##     que o tronco andou, e so o resto vira balanco. E a corrente curta presa
##     no pescoco: pesa, balanca e bate no peito, mas o golpe nao a arremessa;
##   - as duas deitam na frente da roupa DESENHADA (a malha do capuz, da murca
##     e da batina no repouso, adiantada da folga do pano: `BatinaAAA.peito`,
##     `frente`), e nunca ficam atras dela: por cima da roupa, sempre. Batem no
##     pescoco, na cabeca (o cranio e a queixada, um elipsoide no osso da
##     cabeca, `LONGE_DA_CARA`: a cabeca empurra a corrente para baixo, pelo
##     peito, e nunca para a frente da cara), no tronco (`PanoGPU.colisores`) e
##     no chao, todos na pose do fim do quadro (a corrente ja foi levada ate ela
##     por `SEGUE`);
##   - os elos sao uma MultiMesh (`CruzNoPeito.ELO`), um a cada `PASSO_ELO` ao
##     longo da corrente, girando 90 graus de um para o outro. Elos e cruz
##     desenham `AVANCO` mais perto da lente (so a profundidade: na tela nada
##     muda): o capuz que desce com a cabeca e o pano que balanca alem do
##     repouso tapavam um elo aqui e outro ali, e a corrente saia picotada. Do
##     pescoco a gola a corrente fica ate 18 cm atras da frente da gola: la o
##     avanco nao a tira de baixo do capuz, so junta o elo que raspava na beira
##     do pano com os vizinhos.
## Longe da camera (`LONGE`) nao simula: corrente e cruz seguem o torso no
## repouso.
class_name CruzNoPeito
extends Node3D

const PASTA := "res://assets/monstros/padre/cruz/"
const CRUCIFIXO := PASTA + "crucifixo.glb"
const ELO := PASTA + "elo.glb"
## Distancia entre os centros de dois elos enganchados (m): o comprimento de
## fora do elo menos duas vezes o fio (0,016 - 2 x 0,0026).
const PASSO_ELO := 0.0108
## Corrente solta de cada lado, da saida da gola a argola: a distancia no
## repouso mais esta sobra (a corrente pende, nao estica).
const SOBRA := 1.06
const PONTOS := 8
## A cruz no espaco dela (origem no furo da argola, +Y para cima, o Cristo
## olhando -Z; `tools/blender_cruz`): o pe da haste (a haste vai de -0,0069 a
## -0,1669) e as pontas dos bracos (a trave a 28% da haste, de +-0,0475).
const CRUZ_PE := Vector3(0.0, -0.165, 0.0)
const CRUZ_BRACO := Vector3(0.0465, -0.0517, 0.0)
## Massas (kg): cada ponto da corrente e cada um dos quatro da cruz. Ferro e
## bronze: a cruz (140 g) sete vezes cada ponto da corrente, que pende esticada
## pelo peso dela.
const MASSA_ELO := 0.005
const MASSA_CRUZ := 0.035
## Raios de colisao: o fio da corrente e a espessura da cruz com o Cristo.
const RAIO_ELO := 0.004
const RAIO_CRUZ := 0.007
## Quanto o pano fica por cima do corpo nos colisores do tronco (a murca
## deitada no peito) e nos outros.
const SOBRE_O_PANO := 0.045
const SOBRE_O_RESTO := 0.015
const GRAVIDADE := Vector3(0.0, -9.8, 0.0)
## Passo fixo e iteracoes: 120 Hz e quatro voltas (a amarra de alcance segura
## o esticar). Os colisores do quadro vao em arrays empacotados, so os perto da
## corrente, e a colisao e em linha: o passo custava 140 us por padre com uma
## chamada de funcao por teste e os ossos relidos a cada passo.
const PASSO := 1.0 / 120.0
## Longe da lente (alem de `PERTO`) o passo dobra: 60 Hz, um por quadro.
const PASSO_LONGE := 1.0 / 60.0
const PERTO := 4.0
const PASSOS_MAX := 6
const ITERACOES := 4
## Arrasto (1/s) do movimento da corrente em relacao ao tronco: balanca devagar
## e para em menos de um segundo, como corrente pesada no pescoco.
const ARRASTO := 2.0
## Encostado no pano, quanto do movimento de lado se perde por passo.
const ATRITO := 0.35
## Quanto do caminho do tronco a corrente anda junto a cada quadro (0 solta no
## mundo, 1 presa nele). Solta (a de antes), a cabecada e o estouro davam 24 cm
## de chicote num quadro. O tronco que salta mais que `CORTE_M`/`CORTE_ANG` num
## quadro e corte de pose: a corrente vai inteira com ele (sem chicote e sem
## reassentar, que dava um salto na imagem).
const SEGUE := 0.8
const CORTE_M := 0.2
const CORTE_ANG := 0.6
## O quanto a haste da cruz chega perto da corrente, girando na argola: o
## cosseno do menor angulo entre as duas (100 graus).
const GIRO_MAX_COS := -0.17
## Nenhum elo passa desta velocidade em relacao ao tronco (m/s).
const VEL_MAX := 2.5
## O quanto a corrente fica atras do vidro da janela (m): menos que a espessura
## do pano (1 cm, que fica prensado no vidro atras dela). Perto do vidro o
## `AVANCO` encolhe para a corrente nao passar dele (o sangue e a chuva do
## vidro continuam na frente).
const VIDRO_FOLGA := 0.006
## Alem disto (m, na pessoa de 1,72) nao simula: corrente e cruz seguem o
## torso no repouso. Alem de `ELOS_ATE` os elos nem desenham (o elo de 1,6 cm
## ja e menor que um pixel a 4K) e alem de `CRUZ_ATE` a cruz some.
const LONGE := 10.0
const ELOS_ATE := 16.0
const CRUZ_ATE := 40.0
## Ao (re)nascer, passos de assentar com arrasto forte antes de aparecer: posta
## no repouso, a cruz comecava com o pe dentro da murca, era chutada para fora e
## virava de ponta-cabeca.
const ASSENTA := 40
const ASSENTA_ARRASTO := 25.0
const TELEPORTE := 1.5
## A cabeca (pessoa de 1,72): o elipsoide do cranio (`CapuzMacabro`, o da
## `CabecaDoPadre`) descido `QUEIXADA` para a queixada aberta, e a folga que a
## corrente guarda dele (a cruz guarda `LONGE_DA_CARA_CRUZ`).
const QUEIXADA := 0.012
const LONGE_DA_CARA := 0.004
const LONGE_DA_CARA_CRUZ := 0.02
## O pescoco no osso da cabeca (pessoa de 1,72): o eixo da base ao queixo e o
## raio. A malha da cabeca (`cabeca.glb`) tem |x| <= 0,044 e z de -0,03 a 0,07.
const PESCOCO_A := Vector3(0.0, -0.03, 0.02)
const PESCOCO_B := Vector3(0.0, 0.07, 0.01)
const PESCOCO_R := 0.043
## Elos de sobra na MultiMesh: esticada (a cabeca e o capuz empurram a corrente
## em volta deles, e ela chega a 1,5 vez o repouso), a corrente ganha elos no
## passo certo em vez de acabar antes da argola.
const ELOS_SOBRA := 2.0
## O quanto a corrente solta e a cruz desenham mais perto da lente (m): a folga
## que o pano desenhado pode passar do repouso (a cabeca leva o capuz e a murca
## balanca) sem cobrir a corrente. Menos que a distancia do queixo e da mao a
## ela, que continuam na frente.
const AVANCO := 0.02
## O shader da corrente e da cruz: o material do glTF (cor, ORM e normal) com o
## vertice avancado pela reta da lente. `%s` e o modo de desenho.
const SHADER := """
shader_type spatial;
render_mode %s;
uniform sampler2D cor : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mapa_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 cor_mult : source_color = vec4(1.0);
uniform float metal = 1.0;
uniform float rugas = 1.0;
uniform int canal_metal = 2;
uniform int canal_rugas = 1;
uniform bool com_normal = false;
uniform bool magenta = false;
instance uniform float avanco = 0.0;

void vertex() {
	// Pela reta da lente: o pixel fica onde estava, so a profundidade muda.
	vec4 v = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float l = length(v.xyz);
	v.xyz *= max(l - avanco, l * 0.5) / max(l, 1e-4);
	POSITION = PROJECTION_MATRIX * v;
}

void fragment() {
	if (magenta) {
		ALBEDO = vec3(1.0, 0.0, 1.0);
	} else {
		ALBEDO = (texture(cor, UV) * cor_mult).rgb;
		vec4 m = texture(orm, UV);
		METALLIC = m[canal_metal] * metal;
		ROUGHNESS = m[canal_rugas] * rugas;
		if (com_normal) {
			NORMAL_MAP = texture(mapa_n, UV).rgb;
		}
	}
}
"""

## `--cruz-depurar`: imprime o custo medio por padre por quadro e o de um passo
## de fisica (us).
static var _depurar := OS.get_cmdline_user_args().has("--cruz-depurar")
static var _us := 0
static var _medidas := 0
static var _us_passo := 0
static var _passos := 0
static var _malha_cruz: Mesh
static var _malha_elo: Mesh
static var _tentou := false
## Os materiais que avancam (`SHADER`): o do elo e o da cruz.
static var _mat_elo: ShaderMaterial
static var _mat_cruz: ShaderMaterial
## `--cruz-sonda=ARQ`: a regua da cruz. Por quadro e por padre perto da lente,
## uma linha em ARQ (relogio da cena, reinicio e motivo, visivel, saltos, a
## cara vista da lente, dentro do cranio, a ancora ao pescoco, o esticar e a
## cruz de ponta-cabeca) e, do principal (`Padre`), a tela de cada elo e da
## cruz em ARQ.elos: com `--cruz-magenta` a rajada diz, elo por elo, se ele
## saiu no quadro (e com `--cruz-esconder=BatinaAAA`, se a roupa o cobria).
static var _sonda: FileAccess
static var _sonda_elos: FileAccess
static var _sonda_tentou := false
## A sonda do atraso: no `frame_pre_draw`, o quanto o tronco andou depois que a
## cruz simulou (a corrente simulada contra a pose do quadro anterior).
static var _sonda_atraso: FileAccess
static var _sondadas: Array = []
static var _cena: Node
## `--cruz-magenta`: corrente e cruz em magenta chapado (sem luz nem nevoa);
## `--cruz-sobre` ainda por cima de tudo (sem teste de fundo): o caminho inteiro.
static var _magenta := OS.get_cmdline_user_args().has("--cruz-magenta")
## `--cruz-esconder=A,B`: some com os nos de nome A e B debaixo de cada padre
## (so para achar quem cobre a corrente na rajada).
static var _esconder: PackedStringArray = []
static var _esconder_lido := false
static var _sobre := OS.get_cmdline_user_args().has("--cruz-sobre")

var _corpo: Corpo
## No osso do torso: os lados do pescoco, as ancoras (a saida de baixo da gola:
## dali a corrente e solta), a argola no repouso e o comprimento de um lado.
var _pescoco_e := Vector3.ZERO
var _pescoco_d := Vector3.ZERO
var _ancora_e := Vector3.ZERO
var _ancora_d := Vector3.ZERO
var _argola := Vector3.ZERO
var _lado_comp := 0.0
## Elos de cada lado na MultiMesh (o comprimento de repouso com `ELOS_SOBRA`).
var _elos_lado := 0
## Os transforms dos elos, escritos de uma vez no buffer da MultiMesh.
var _buf := PackedFloat32Array()
var _longe_da_camera := 0.0
## O passo de agora (`PASSO` perto, `PASSO_LONGE` longe).
var _h := PASSO
var _esq: Skeleton3D
var _escala := 1.0
## [osso, a, b, raio, sobre] no espaco do osso: o pescoco (na cabeca) e as
## capsulas que `BatinaAAA.peito` der (hoje nenhuma: a frente da roupa e a grade
## `_frente`).
var _colisores: Array = []
## A frente da roupa (`BatinaAAA.peito`, `frente`) no espaco do esqueleto, e o
## osso do torso no repouso (o espaco dele para o do esqueleto).
var _frente: Dictionary = {}
var _torso_rest := Transform3D()
## A grade da frente em variaveis soltas (o dicionario custava uma busca por
## chave em cada ponto de cada passo).
var _f_x0 := 0.0
var _f_y0 := 0.0
var _f_inv := 0.0
var _f_nx := 0
var _f_ny := 0
var _f_z := PackedFloat32Array()
## A frente do capuz que vai com a cabeca (`BatinaAAA.peito`, `frente_cabeca`),
## no espaco do osso da cabeca.
var _fc_x0 := 0.0
var _fc_y0 := 0.0
var _fc_inv := 0.0
var _fc_nx := 0
var _fc_ny := 0
var _fc_z := PackedFloat32Array()
## Os colisores do pano (`PanoGPU.colisores`, [osso, a, b, raio]), lidos vivos
## a cada quadro: o vidro da janela e do capo entra depois de vestir e anda
## (`mover_colisor`). Com a copia feita ao vestir, a cruz do carona atravessava
## a janela e ficava pendurada dentro do carro. Os da cabeca ficam de fora: sao
## do capuz (um palmo em volta do pescoco) e a corrente usa os dela.
var _colisores_pano: Array = []
var _p := PackedVector3Array()
var _pv := PackedVector3Array()
var _w := PackedFloat32Array()
var _raio := PackedFloat32Array()
## Comprimento de repouso entre pontos seguidos da corrente.
var _l_elo := 0.0
## As seis distancias da cruz: pares de indices e comprimentos.
var _rig: Array = []
## Os colisores do quadro perto da corrente, em duas listas: os do tronco (no
## espaco dele, filtrados ali, e levados ao mundo em `_pa`/`_pab`) e os outros
## no mundo, todos na pose do fim do quadro. Ponta a, eixo ab, 1/|ab|^2 e raio
## (com o pano; o raio da particula soma na hora).
var _tl_a := PackedVector3Array()
var _tl_ab := PackedVector3Array()
var _tl_inv := PackedFloat32Array()
var _tl_r := PackedFloat32Array()
var _col_a := PackedVector3Array()
var _col_ab := PackedVector3Array()
var _col_inv := PackedFloat32Array()
var _col_r := PackedFloat32Array()
## O vidro da janela (`CabecadaDoPadre`: uma esfera de 14 m do lado de dentro,
## que o `PanoGPU` le como colisor): centro e raio (ja com `VIDRO_FOLGA`), no
## mundo. Vai depois da roupa: prensado no vidro, o pano fica na superficie
## dele e a corrente entre os dois. Com a folga do tronco (4,5 cm) e antes da
## roupa, as duas brigavam pela corrente na cabecada e a cruz virava de
## ponta-cabeca.
var _vid_c := PackedVector3Array()
var _vid_r := PackedFloat32Array()
## A cabeca do quadro: o osso (mundo) e o elipsoide no espaco dele (centro e
## semieixos, sem a folga).
var _cab := Transform3D()
var _cab_c := Vector3.ZERO
var _cab_e := Vector3.ZERO
var _cab_ok := false
## Os colisores do tronco no mundo, na pose do fim do quadro.
var _pa := PackedVector3Array()
var _pab := PackedVector3Array()
var _cruz: MeshInstance3D
var _elos: MultiMeshInstance3D
## Os elos do pescoco a gola, fixos no torso (`_montar_gola`).
var _elos_gola: MultiMeshInstance3D
var _buf_g := PackedFloat32Array()
var _elos_gola_lado := 0
var _acumulado := 0.0
var _torso_antes := Transform3D()
var _ultima := Vector3.INF
var _reiniciar := true
## Sonda: o motivo do ultimo reinicio (0 nenhum, 1 sumiu, 2 teleporte, 5
## primeiro), se o quadro foi corte de pose (3) e a cruz do quadro anterior.
var _motivo := 5
var _corte := false
var _sonda_argola := Vector3.INF
var _sonda_local := PackedVector3Array()
var _sonda_rein := false
var _sonda_torso := Transform3D()
var _sonda_t := 0.0
var _sonda_longe := false


## Os indices: o lado da ancora direita (`_ancora(t, 1.0)`) 0..PONTOS-1, o da
## esquerda PONTOS..2*PONTOS-1, e a cruz (argola, pe, braco direito, braco
## esquerdo) no fim. A ancora nao e ponto: e o osso.
func _i_cruz(k: int) -> int:
	return 2 * PONTOS + k


static func _carregar() -> bool:
	if _malha_cruz != null:
		return true
	if _tentou:
		return false
	_tentou = true
	if not ResourceLoader.exists(CRUCIFIXO) or not ResourceLoader.exists(ELO):
		push_warning("CruzNoPeito: sem %s ou %s" % [CRUCIFIXO, ELO])
		return false
	_malha_cruz = _primeira_malha(load(CRUCIFIXO) as PackedScene)
	_malha_elo = _primeira_malha(load(ELO) as PackedScene)
	if _malha_cruz == null or _malha_elo == null:
		return false
	var modo := "unshaded, fog_disabled" if _magenta else "cull_back"
	if _sobre:
		modo += ", depth_test_disabled"
	var sh := Shader.new()
	sh.code = SHADER % modo
	_mat_elo = _material(sh, _malha_elo)
	_mat_cruz = _material(sh, _malha_cruz)
	return true


## O material que avanca, com as texturas e os numeros do material do glTF.
static func _material(sh: Shader, m: Mesh) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter(&"magenta", _magenta)
	var sm := m.surface_get_material(0) as StandardMaterial3D
	if sm == null:
		return mat
	mat.set_shader_parameter(&"cor", sm.albedo_texture)
	mat.set_shader_parameter(&"cor_mult", sm.albedo_color)
	mat.set_shader_parameter(&"orm", sm.metallic_texture)
	mat.set_shader_parameter(&"metal", sm.metallic)
	mat.set_shader_parameter(&"rugas", sm.roughness)
	mat.set_shader_parameter(&"canal_metal", _canal(sm.metallic_texture_channel))
	mat.set_shader_parameter(&"canal_rugas", _canal(sm.roughness_texture_channel))
	mat.set_shader_parameter(&"com_normal", sm.normal_enabled and sm.normal_texture != null)
	mat.set_shader_parameter(&"mapa_n", sm.normal_texture)
	return mat


static func _canal(c: BaseMaterial3D.TextureChannel) -> int:
	match c:
		BaseMaterial3D.TEXTURE_CHANNEL_RED:
			return 0
		BaseMaterial3D.TEXTURE_CHANNEL_GREEN:
			return 1
		BaseMaterial3D.TEXTURE_CHANNEL_BLUE:
			return 2
		BaseMaterial3D.TEXTURE_CHANNEL_ALPHA:
			return 3
	return 0


static func _primeira_malha(ps: PackedScene) -> Mesh:
	if ps == null:
		return null
	var r := ps.instantiate()
	var mis := r.find_children("*", "MeshInstance3D", true, false)
	var m: Mesh = (mis[0] as MeshInstance3D).mesh if not mis.is_empty() else null
	r.free()
	return m


## Pendura o crucifixo em `c`, na escala `s` da pessoa, no pescoco e na frente
## da murca (`peito`, de `BatinaAAA.peito`), batendo tambem em `colisores`
## ([osso, a, b, raio] de `PanoGPU.colisores`). Null se o modelo nao carregou.
static func vestir(c: Corpo, s: float, colisores: Array, peito: Dictionary) -> CruzNoPeito:
	if not _carregar() or peito.is_empty():
		return null
	var cr := CruzNoPeito.new()
	cr.name = "CruzNoPeito"
	cr._corpo = c
	cr._esq = c.esqueleto()
	cr._escala = s
	var no_torso := cr._esq.get_bone_global_rest(Corpo.Osso.TORSO).affine_inverse()
	cr._ancora_e = no_torso * (peito["ancora_e"] as Vector3)
	cr._ancora_d = no_torso * (peito["ancora_d"] as Vector3)
	cr._pescoco_e = no_torso * (peito.get("pescoco_e", peito["ancora_e"]) as Vector3)
	cr._pescoco_d = no_torso * (peito.get("pescoco_d", peito["ancora_d"]) as Vector3)
	cr._argola = no_torso * (peito["argola"] as Vector3)
	cr._frente = peito.get("frente", {})
	cr._torso_rest = no_torso.affine_inverse()
	if not cr._frente.is_empty():
		cr._f_x0 = float(cr._frente["x0"])
		cr._f_y0 = float(cr._frente["y0"])
		cr._f_inv = 1.0 / float(cr._frente["passo"])
		cr._f_nx = int(cr._frente["nx"])
		cr._f_ny = int(cr._frente["ny"])
		cr._f_z = cr._frente["z"]
	var fc: Dictionary = peito.get("frente_cabeca", {})
	if not fc.is_empty():
		cr._fc_x0 = float(fc["x0"])
		cr._fc_y0 = float(fc["y0"])
		cr._fc_inv = 1.0 / float(fc["passo"])
		cr._fc_nx = int(fc["nx"])
		cr._fc_ny = int(fc["ny"])
		cr._fc_z = fc["z"]
	# O comprimento: o caminho da gola a argola por cima da roupa, e a sobra.
	cr._lado_comp = cr._caminho(cr._ancora_d, cr._argola, 16, RAIO_ELO * s) * SOBRA
	for cap: Array in peito.get("capsulas", []):
		cr._colisores.append([Corpo.Osso.TORSO, no_torso * (cap[0] as Vector3),
			no_torso * (cap[1] as Vector3), float(cap[2]), 0.0])
	cr._colisores.append([Corpo.Osso.CABECA, PESCOCO_A * s, PESCOCO_B * s, PESCOCO_R * s, 0.0])
	cr._colisores_pano = colisores
	c.add_child(cr)
	return cr


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	var n := 2 * PONTOS + 4
	_p.resize(n)
	_pv.resize(n)
	_w.resize(n)
	_raio.resize(n)
	for i in n:
		var cruz := i >= 2 * PONTOS
		_w[i] = 1.0 / (MASSA_CRUZ if cruz else MASSA_ELO)
		_raio[i] = (RAIO_CRUZ if cruz else RAIO_ELO) * _escala
	# PONTOS + 1 trechos de cada lado: da ancora ao primeiro ponto, entre os
	# pontos e do ultimo a argola.
	_l_elo = _lado_comp / float(PONTOS + 1)
	var pontos := [Vector3.ZERO, CRUZ_PE, CRUZ_BRACO, Vector3(-CRUZ_BRACO.x, CRUZ_BRACO.y, 0.0)]
	for a in 4:
		for b in range(a + 1, 4):
			_rig.append([_i_cruz(a), _i_cruz(b), ((pontos[a] as Vector3) - (pontos[b] as Vector3)).length() * _escala])
	_cruz = MeshInstance3D.new()
	_cruz.name = "Crucifixo"
	_cruz.mesh = _malha_cruz
	_cruz.top_level = true
	_cruz.visibility_range_end = CRUZ_ATE * _escala
	add_child(_cruz)
	_cruz.material_override = _mat_cruz
	_elos_lado = int(ceil(_lado_comp * ELOS_SOBRA / (PASSO_ELO * _escala)))
	_elos_gola_lado = int(ceil(_pescoco_d.distance_to(_ancora_d) / (PASSO_ELO * _escala))) + 1
	_elos = _multimesh("Corrente", 2 * _elos_lado, _mat_elo)
	_elos_gola = _multimesh("CorrenteNaGola", 2 * _elos_gola_lado, _mat_elo)
	_buf.resize(_elos.multimesh.instance_count * 12)
	_buf_g.resize(_elos_gola.multimesh.instance_count * 12)
	_montar_gola()


func _multimesh(nome: String, n: int, mat: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _malha_elo
	mm.instance_count = n
	var mi := MultiMeshInstance3D.new()
	mi.name = nome
	mi.multimesh = mm
	mi.top_level = true
	mi.visibility_range_end = ELOS_ATE * _escala
	mi.material_override = mat
	add_child(mi)
	return mi


func _torso() -> Transform3D:
	var t := _esq.global_transform * _esq.get_bone_global_pose(Corpo.Osso.TORSO)
	return Transform3D(t.basis.orthonormalized(), t.origin)


func _osso_cabeca() -> Transform3D:
	var t := _esq.global_transform * _esq.get_bone_global_pose(Corpo.Osso.CABECA)
	return Transform3D(t.basis.orthonormalized(), t.origin)


func _ancora(t: Transform3D, lado: float) -> Vector3:
	return t * (_ancora_d if lado > 0.0 else _ancora_e)


func _pescoco(t: Transform3D, lado: float) -> Vector3:
	return t * (_pescoco_d if lado > 0.0 else _pescoco_e)


## O ponto `q` (no espaco do torso) por cima da frente da roupa, com o raio `r`:
## se ele esta atras dela, vai para a frente (-Z) ate ela.
func _por_cima(q: Vector3, r: float) -> Vector3:
	if _frente.is_empty():
		return q
	var m := _torso_rest * q
	var zf := _frente_z(m.x, m.y)
	if is_finite(zf) and m.z > zf - r:
		m.z = zf - r
		return _torso_rest.affine_inverse() * m
	return q


## O caminho de `a` a `b` (espaco do torso) por cima da roupa, em `n` trechos.
func _caminho(a: Vector3, b: Vector3, n: int, r: float) -> float:
	var comp := 0.0
	var ant := _por_cima(a, r)
	for k in range(1, n + 1):
		var q := _por_cima(a.lerp(b, float(k) / float(n)), r)
		comp += ant.distance_to(q)
		ant = q
	return comp


## O elipsoide da cabeca, lido do capuz uma vez (o rosto entra depois de
## vestir). Sem capuz (ou sem rosto), o do `Corpo`.
func _ler_cabeca() -> void:
	if _cab_ok:
		return
	var cap: Object = _corpo.get_meta(&"capuz", null)
	if cap == null or not cap.has_method(&"_elipsoide_da_cabeca"):
		return
	var el: AABB = cap.call(&"_elipsoide_da_cabeca", _corpo)
	var q := QUEIXADA * _escala
	_cab_c = el.get_center() + Vector3(0.0, -q * 0.5, 0.0)
	_cab_e = el.size * 0.5 + Vector3(0.0, q * 0.5, 0.0)
	_cab_ok = true


## O repouso: a cruz pendurada na frente do peito, os dois lados da corrente da
## gola ate a argola por cima da roupa.
func _por_no_repouso(t: Transform3D) -> void:
	for lado_i in 2:
		# O lado 0 e o da ancora direita (`_ancora(t, 1.0)`), como no passo e no
		# desenho: trocados, os dois lados nasciam cruzados em X.
		var a := _ancora_d if lado_i == 0 else _ancora_e
		for k in PONTOS:
			var f := float(k + 1) / float(PONTOS + 1)
			_p[lado_i * PONTOS + k] = t * _por_cima(a.lerp(_argola, f), _raio[0])
	# A cruz deitada na frente da murca: o pe por cima da roupa, abaixo da
	# argola. Pendurada reta no osso do torso, o pe ficava dentro da murca
	# (ela desce para a frente), a roupa empurrava o pe para fora e a cruz
	# virava de ponta-cabeca.
	var rc := RAIO_CRUZ * _escala
	var pe := _por_cima(_argola + Vector3(0.0, CRUZ_PE.y * _escala, 0.0), rc)
	var y := (_argola - pe).normalized()
	var z := Vector3.RIGHT.cross(y).normalized()
	var base := Basis(y.cross(z).normalized(), y, z)
	var pontos := [Vector3.ZERO, CRUZ_PE, CRUZ_BRACO, Vector3(-CRUZ_BRACO.x, CRUZ_BRACO.y, 0.0)]
	for k in 4:
		_p[_i_cruz(k)] = t * (_argola + base * ((pontos[k] as Vector3) * _escala))
	for i in _p.size():
		_pv[i] = _p[i]


func _process(delta: float) -> void:
	if _esq == null or _malha_cruz == null:
		return
	var t0 := Time.get_ticks_usec()
	_simular(delta)
	var gasto := Time.get_ticks_usec() - t0
	if _sonda_ligada() and visible:
		_sondar()
	if _depurar:
		_us += gasto
		_medidas += 1
		if _medidas % 600 == 0:
			print("[cruz] custo medio %.1f us por padre por quadro; um passo de fisica %.1f us" % [
				float(_us) / float(_medidas), float(_us_passo) / float(maxi(_passos, 1))])


func _simular(delta: float) -> void:
	if not _corpo.is_visible_in_tree():
		_reiniciar = true
		_motivo = 1
		visible = false
		return
	visible = true
	_esconder_nos()
	var t := _torso()
	var cam := get_viewport().get_camera_3d()
	_longe_da_camera = cam.global_position.distance_to(t.origin) if cam != null else 0.0
	var longe := _longe_da_camera > LONGE * _escala
	if _ultima != Vector3.INF and t.origin.distance_to(_ultima) > TELEPORTE:
		_reiniciar = true
		_motivo = 2
	_corte = false
	if not _reiniciar and _torso_antes != Transform3D():
		_corte = t.origin.distance_to(_torso_antes.origin) > CORTE_M * _escala \
			or (_torso_antes.basis.inverse() * t.basis).get_rotation_quaternion().get_angle() > CORTE_ANG
	_ultima = t.origin
	_sonda_rein = _reiniciar
	_sonda_longe = longe
	_ler_cabeca()
	_cab = _osso_cabeca()
	if _reiniciar or longe:
		_por_no_repouso(t)
		if _reiniciar:
			_colisores_do_quadro()
			for _k in ASSENTA:
				_passo(t, ASSENTA_ARRASTO)
			for i in _p.size():
				_pv[i] = _p[i]
		_torso_antes = t
		_reiniciar = false
		_acumulado = 0.0
		_desenhar()
		return
	var h := PASSO if _longe_da_camera < PERTO * _escala else PASSO_LONGE
	if h != _h:
		# Verlet guarda a velocidade como deslocamento por passo: troca de passo
		# reescala o deslocamento, senao a corrente da um tranco.
		for i in _p.size():
			_pv[i] = _p[i] - (_p[i] - _pv[i]) * (h / _h)
		_h = h
	_acumulado = minf(_acumulado + delta, _h * PASSOS_MAX)
	var passos := int(_acumulado / _h)
	_acumulado -= float(passos) * _h
	if passos > 0:
		# O tronco andou do quadro anterior para este: a corrente anda junto
		# `SEGUE` do caminho (inteira no corte de pose), uma vez, e os passos
		# correm na pose do fim do quadro.
		_levar(_torso_antes, t, 1.0 if _corte else SEGUE)
		_colisores_do_quadro()
		for k in passos:
			var tp := Time.get_ticks_usec()
			_passo(t, ARRASTO)
			if _depurar:
				_us_passo += Time.get_ticks_usec() - tp
				_passos += 1
		_torso_antes = t
	_desenhar()


## O tronco andou de `t0` para `t1`: posicao e posicao anterior de cada ponto
## andam juntas (a velocidade em relacao a ele fica), `segue` do caminho.
func _levar(t0: Transform3D, t1: Transform3D, segue: float) -> void:
	if segue <= 0.0 or t0 == t1 or t0 == Transform3D():
		return
	var d := t1 * t0.affine_inverse()
	for i in _p.size():
		_p[i] = _p[i].lerp(d * _p[i], segue)
		_pv[i] = _pv[i].lerp(d * _pv[i], segue)


## Um passo, com o tronco `t1` (a pose do fim do quadro).
func _passo(t1: Transform3D, arrasto: float) -> void:
	var h := _h
	var n := _p.size()
	var solta := maxf(0.0, 1.0 - arrasto * h)
	var v_max := VEL_MAX * h
	for i in n:
		var v := (_p[i] - _pv[i]) * solta
		var lv := v.length()
		if lv > v_max:
			v *= v_max / lv
		_pv[i] = _p[i]
		_p[i] += v + GRAVIDADE * h * h
	var a_e := _ancora(t1, 1.0)
	var a_d := _ancora(t1, -1.0)
	var argola := _i_cruz(0)
	var l_elo := _l_elo
	for _it in ITERACOES:
		# A corrente: so estica ate o comprimento (amontoa livre). A primeira
		# de cada lado nao sai de um elo da ancora.
		for lado_i in 2:
			var base := lado_i * PONTOS
			var ancora := a_e if lado_i == 0 else a_d
			var d0 := _p[base] - ancora
			var l0 := d0.length()
			if l0 > l_elo:
				_p[base] = ancora + d0 * (l_elo / l0)
			for k in PONTOS:
				var i := base + k
				var j := base + k + 1 if k < PONTOS - 1 else argola
				var d := _p[j] - _p[i]
				var l := d.length()
				if l > l_elo:
					var wi := _w[i]
					var wj := _w[j]
					var c := d * ((l - l_elo) / (l * (wi + wj)))
					_p[i] += c * wi
					_p[j] -= c * wj
		# A cruz: rigida.
		for r: Array in _rig:
			var i := int(r[0])
			var j := int(r[1])
			var d := _p[j] - _p[i]
			var l := d.length()
			if l > 1e-7:
				var c := d * ((l - float(r[2])) / (l * 2.0))
				_p[i] += c
				_p[j] -= c
	_limitar_giro()
	# Amarra de alcance (LRA): nenhum ponto passa da ancora mais que a corrente
	# entre os dois. Sem ela a corrente de onze trechos esticava sob o peso da
	# cruz (Gauss-Seidel em seis voltas nao segura), os elos se abriam e a cruz
	# descia ate a cintura.
	for lado_i in 2:
		var base := lado_i * PONTOS
		var ancora := a_e if lado_i == 0 else a_d
		for k in PONTOS:
			_amarra(base + k, ancora, float(k + 1) * l_elo)
		_amarra(argola, ancora, float(PONTOS + 1) * l_elo)
	var nt := _tl_a.size()
	var nc := _col_a.size()
	var chao := _corpo.global_position.y
	for i in n:
		var p := _p[i]
		var ri := _raio[i]
		for c in nt + nc:
			var a: Vector3
			var ab: Vector3
			var inv: float
			var rc: float
			if c < nt:
				a = _pa[c]
				ab = _pab[c]
				inv = _tl_inv[c]
				rc = _tl_r[c]
			else:
				a = _col_a[c - nt]
				ab = _col_ab[c - nt]
				inv = _col_inv[c - nt]
				rc = _col_r[c - nt]
			var tt := clampf((p - a).dot(ab) * inv, 0.0, 1.0)
			var q := a + ab * tt
			var d := p - q
			var l2 := d.length_squared()
			var r := rc + ri
			if l2 < r * r:
				var l := sqrt(l2)
				var nrm := d / l if l > 1e-6 else Vector3.UP
				var np := q + nrm * r
				# Atrito: encostado no pano, o elo nao escorrega livre.
				var mov := np - _pv[i]
				_pv[i] += (mov - nrm * mov.dot(nrm)) * ATRITO
				p = np
		if p.y < chao + ri:
			p.y = chao + ri
		_p[i] = p
	_por_cima_da_roupa(t1)
	for v in _vid_c.size():
		var cv := _vid_c[v]
		var rv := _vid_r[v]
		for i in n:
			var d := _p[i] - cv
			var l2 := d.length_squared()
			if l2 < rv * rv:
				var np := cv + d * (rv / sqrt(l2))
				_pv[i] += np - _p[i]
				_p[i] = np
	if not _fc_z.is_empty():
		_por_cima_do_capuz(_cab)
	_fora_da_cabeca(t1)


## A frente da roupa em (x, y) do esqueleto: `BatinaAAA.frente_em` sem o
## dicionario.
func _frente_z(x: float, y: float) -> float:
	return _grade_z(_f_z, _f_x0, _f_y0, _f_inv, _f_nx, _f_ny, x, y)


static func _grade_z(zz: PackedFloat32Array, x0: float, y0: float, inv: float, nx: int, ny: int,
		x: float, y: float) -> float:
	var gx := (x - x0) * inv - 0.5
	var gy := (y - y0) * inv - 0.5
	var ix := int(floor(gx))
	var iy := int(floor(gy))
	if ix < 0 or iy < 0 or ix >= nx - 1 or iy >= ny - 1:
		return INF
	var o := iy * nx + ix
	var a := zz[o]
	var b := zz[o + 1]
	var c := zz[o + nx]
	var d := zz[o + nx + 1]
	if not (is_finite(a) and is_finite(b) and is_finite(c) and is_finite(d)):
		return minf(minf(a, b), minf(c, d))
	var fx := gx - float(ix)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), gy - float(iy))


## Nenhum ponto atras da frente da roupa desenhada: vai para a frente ate ela,
## e o que se mexia de lado encostado nela perde `ATRITO`.
func _por_cima_da_roupa(t: Transform3D) -> void:
	if _f_z.is_empty():
		return
	var para_esq := t.affine_inverse()
	para_esq = _torso_rest * para_esq
	var para_mundo := t * _torso_rest.affine_inverse()
	var frente_mundo := -t.basis.z
	for i in _p.size():
		var m := para_esq * _p[i]
		var zf := _frente_z(m.x, m.y)
		var r := _raio[i]
		if not is_finite(zf) or m.z <= zf - r:
			continue
		m.z = zf - r
		var np := para_mundo * m
		if _no_vidro(np):
			# Prensado no vidro, o pano desenhado tambem sai do repouso (o vidro
			# o empurra): a roupa nao leva a corrente para dentro do vidro. As
			# duas brigando faziam a cruz escorregar vidro acima e virar.
			continue
		var mov := np - _pv[i]
		_pv[i] += (mov - frente_mundo * mov.dot(frente_mundo)) * ATRITO
		_p[i] = np


func _no_vidro(q: Vector3) -> bool:
	for v in _vid_c.size():
		if q.distance_squared_to(_vid_c[v]) < _vid_r[v] * _vid_r[v]:
			return true
	return false


## O mesmo contra o capuz que vai com a cabeca, na pose `tc` do osso dela.
func _por_cima_do_capuz(tc: Transform3D) -> void:
	if _fc_z.is_empty():
		return
	var inv := tc.affine_inverse()
	var frente_mundo := -tc.basis.z
	for i in _p.size():
		var m := inv * _p[i]
		var zf := _grade_z(_fc_z, _fc_x0, _fc_y0, _fc_inv, _fc_nx, _fc_ny, m.x, m.y)
		var r := _raio[i]
		if not is_finite(zf) or m.z <= zf - r:
			continue
		m.z = zf - r
		var np := tc * m
		if _no_vidro(np):
			continue
		var mov := np - _pv[i]
		_pv[i] += (mov - frente_mundo * mov.dot(frente_mundo)) * ATRITO
		_p[i] = np


## Nenhum ponto dentro da cabeca: o elipsoide (com a queixada e a folga) na pose
## do passo. A cabeca empurra o ponto para baixo, pelo tronco (o queixo que
## recolhe prende a corrente no peito), e nunca para fora pelo raio: pelo raio,
## a cabecada levava a corrente para a frente da cara. E o ultimo a mexer.
func _fora_da_cabeca(t: Transform3D) -> void:
	if not _cab_ok:
		return
	var tc := _cab
	var inv := tc.affine_inverse()
	var centro := tc * _cab_c
	var alcance := maxf(_cab_e.x, maxf(_cab_e.y, _cab_e.z)) + (LONGE_DA_CARA_CRUZ + RAIO_CRUZ) * _escala
	var alcance2 := alcance * alcance
	# Para baixo pelo tronco, no espaco da cabeca.
	var baixo := inv.basis * (-t.basis.y)
	for i in _p.size():
		if _p[i].distance_squared_to(centro) > alcance2:
			continue
		var cruz := i >= 2 * PONTOS
		var folga := ((LONGE_DA_CARA_CRUZ if cruz else LONGE_DA_CARA) * _escala) + _raio[i]
		var e := _cab_e + Vector3.ONE * folga
		var q := (inv * _p[i] - _cab_c) / e
		if q.length_squared() >= 1.0:
			continue
		# Sai pela reta q + s * d (no espaco escalado): |q + s d| = 1, s > 0.
		var d := baixo / e
		var aa := d.dot(d)
		var bb := q.dot(d)
		var cc := q.dot(q) - 1.0
		var sd := (-bb + sqrt(maxf(bb * bb - aa * cc, 0.0))) / maxf(aa, 1e-9)
		var np := tc * (_cab_c + (q + d * sd) * e)
		# Sai sem ganhar velocidade: a cabeca empurra, nao chuta.
		_pv[i] += np - _p[i]
		_p[i] = np


## A argola e um anel na corrente: a cruz gira nele, mas a haste nao passa por
## cima dela (do lado de onde a corrente chega). Sem o limite, o padre curvado
## sobre o carro balancava a cruz ate ela dar a volta por cima e ficar de
## ponta-cabeca (Romeiro7: 228 quadros).
func _limitar_giro() -> void:
	var ia := _i_cruz(0)
	var a := _p[ia]
	var u := (_p[PONTOS - 1] - a) + (_p[2 * PONTOS - 1] - a)
	var d := _p[_i_cruz(1)] - a
	if u.length_squared() < 1e-10 or d.length_squared() < 1e-10:
		return
	u = u.normalized()
	var dn := d.normalized()
	var c := dn.dot(u)
	if c <= GIRO_MAX_COS:
		return
	var eixo := u.cross(dn)
	if eixo.length_squared() < 1e-10:
		eixo = u.cross(Vector3.RIGHT if absf(u.x) < 0.9 else Vector3.UP)
	eixo = eixo.normalized()
	# Girar em volta de u x d afasta d de u: o angulo que falta ate o limite.
	var giro := Basis(eixo, acos(GIRO_MAX_COS) - acos(clampf(c, -1.0, 1.0)))
	for k in range(1, 4):
		var i := _i_cruz(k)
		var np := a + giro * (_p[i] - a)
		_pv[i] += np - _p[i]
		_p[i] = np


func _amarra(i: int, ancora: Vector3, alcance: float) -> void:
	var d := _p[i] - ancora
	var l := d.length()
	if l > alcance:
		var novo := ancora + d * (alcance / l)
		# A argola leva a cruz junto: o corpo rigido nao fica para tras.
		if i == _i_cruz(0):
			var mov := novo - _p[i]
			for k in range(1, 4):
				_p[_i_cruz(k)] += mov
		_p[i] = novo


## Os colisores, uma vez por quadro, so os que alcancam a corrente (a esfera em
## volta dela, com folga para o quadro): os do tronco no espaco dele, os outros
## no mundo.
func _colisores_do_quadro() -> void:
	var t := _torso()
	var inv_t := t.affine_inverse()
	var centro := Vector3.ZERO
	for p in _p:
		centro += p
	centro /= float(_p.size())
	var alcance := 0.0
	for p in _p:
		alcance = maxf(alcance, p.distance_to(centro))
	alcance += 0.15 * _escala
	var centro_t := inv_t * centro
	_tl_a.clear()
	_tl_ab.clear()
	_tl_inv.clear()
	_tl_r.clear()
	_col_a.clear()
	_col_ab.clear()
	_col_inv.clear()
	_col_r.clear()
	_vid_c.clear()
	_vid_r.clear()
	var todos: Array = _colisores.duplicate()
	for col: Array in _colisores_pano:
		var o := int(col[0])
		# So o tronco e o quadril (com o vidro): a cabeca e o pescoco sao os da
		# corrente, e bracos e pernas ficam de fora. O braco do padre da janela
		# e trocado pelo braco vivo (o osso encolhe, mas a capsula dele fica), e
		# no estouro ele varria a corrente: a cruz ia parar no ombro, pendurada.
		if o != Corpo.Osso.TORSO and o != Corpo.Osso.QUADRIL:
			continue
		var tronco := o == Corpo.Osso.TORSO or o == Corpo.Osso.QUADRIL
		todos.append([o, col[1], col[2], float(col[3]),
			(SOBRE_O_PANO if tronco else SOBRE_O_RESTO) * _escala])
	var poses := {}
	for c: Array in todos:
		var o := int(c[0])
		var r := float(c[3]) + float(c[4])
		if o == Corpo.Osso.TORSO:
			# No espaco do tronco (a pose de repouso do osso e a de agora sao o
			# mesmo espaco: `_torso` e o osso na pose).
			var a_l: Vector3 = c[1]
			var ab_l: Vector3 = (c[2] as Vector3) - a_l
			var tl := clampf((centro_t - a_l).dot(ab_l) / maxf(ab_l.dot(ab_l), 1e-9), 0.0, 1.0)
			if (a_l + ab_l * tl).distance_to(centro_t) > alcance + r:
				continue
			_tl_a.append(a_l)
			_tl_ab.append(ab_l)
			_tl_inv.append(1.0 / maxf(ab_l.dot(ab_l), 1e-9))
			_tl_r.append(r)
			continue
		if not poses.has(o):
			var tb := _esq.global_transform * _esq.get_bone_global_pose(o)
			poses[o] = Transform3D(tb.basis.orthonormalized(), tb.origin)
		var tb: Transform3D = poses[o]
		var a := tb * (c[1] as Vector3)
		var b := tb * (c[2] as Vector3)
		if float(c[3]) > 1.0:
			_vid_c.append((a + b) * 0.5)
			_vid_r.append(float(c[3]) + VIDRO_FOLGA * _escala)
			continue
		var ab := b - a
		var tt := clampf((centro - a).dot(ab) / maxf(ab.dot(ab), 1e-9), 0.0, 1.0)
		if (a + ab * tt).distance_to(centro) > alcance + r:
			continue
		_col_a.append(a)
		_col_ab.append(ab)
		_col_inv.append(1.0 / maxf(ab.dot(ab), 1e-9))
		_col_r.append(r)
	_pa.resize(_tl_a.size())
	_pab.resize(_tl_a.size())
	for c in _tl_a.size():
		_pa[c] = t * _tl_a[c]
		_pab[c] = t.basis * _tl_ab[c]


func _desenhar() -> void:
	# A cruz pelas quatro particulas.
	var argola := _p[_i_cruz(0)]
	var y := (argola - _p[_i_cruz(1)]).normalized()
	var x := _p[_i_cruz(2)] - _p[_i_cruz(3)]
	x = (x - y * x.dot(y)).normalized()
	var z := x.cross(y)
	_cruz.global_transform = Transform3D(Basis(x, y, z).scaled(Vector3.ONE * _escala), argola)
	if _longe_da_camera > ELOS_ATE * _escala:
		return
	var t := _torso()
	# Do pescoco a gola a corrente e fixa no torso (`_montar_gola`): so o no anda.
	_elos_gola.global_transform = t
	# Da gola para baixo, os elos ao longo dos dois lados, um a cada `PASSO_ELO`
	# (esticada, a corrente ganha elos; frouxa, os do fim ficam na argola).
	var passo := PASSO_ELO * _escala
	var n := 0
	var linha := PackedVector3Array()
	linha.resize(PONTOS + 2)
	var fundo := -t.basis.z
	var e := _escala
	var lo := argola
	var hi := argola
	for lado_i in 2:
		linha[0] = _ancora(t, 1.0 if lado_i == 0 else -1.0)
		for k in PONTOS:
			linha[k + 1] = _p[lado_i * PONTOS + k]
		linha[PONTOS + 1] = argola
		for q in linha:
			lo = lo.min(q)
			hi = hi.max(q)
		var s := passo * 0.5
		var seg := 0
		var ini := 0.0
		var k_elo := 0
		while seg < linha.size() - 1 and k_elo < _elos_lado:
			var a := linha[seg]
			var b := linha[seg + 1]
			var lseg := a.distance_to(b)
			if s > ini + lseg:
				ini += lseg
				seg += 1
				continue
			var p := a.lerp(b, (s - ini) / maxf(lseg, 1e-6))
			var eixo := (b - a).normalized() if lseg > 1e-6 else -t.basis.y
			var lado_v := fundo.cross(eixo)
			if lado_v.length_squared() < 1e-8:
				lado_v = t.basis.x
			lado_v = lado_v.normalized()
			if k_elo % 2 == 1:
				lado_v = eixo.cross(lado_v).normalized()
			var bx := lado_v * e
			var by := eixo * e
			var bz := lado_v.cross(eixo) * e
			var o := n * 12
			_buf[o] = bx.x
			_buf[o + 1] = by.x
			_buf[o + 2] = bz.x
			_buf[o + 3] = p.x
			_buf[o + 4] = bx.y
			_buf[o + 5] = by.y
			_buf[o + 6] = bz.y
			_buf[o + 7] = p.y
			_buf[o + 8] = bx.z
			_buf[o + 9] = by.z
			_buf[o + 10] = bz.z
			_buf[o + 11] = p.z
			n += 1
			k_elo += 1
			s += passo
	_enviar(n, lo, hi)


## Os elos do pescoco a gola, uma vez, no espaco do torso (`_elos_gola` anda
## com ele): a volta ali e fixa (esticada pelo peso da cruz), e refazer os
## elos dela a cada quadro dobrava o custo de desenhar a corrente.
func _montar_gola() -> void:
	var passo := PASSO_ELO * _escala
	var fundo := Vector3(0.0, 0.0, -1.0)
	var n := 0
	var lo := _pescoco_d
	var hi := _pescoco_d
	for lado in [1.0, -1.0]:
		var a: Vector3 = _pescoco_d if lado > 0.0 else _pescoco_e
		var b: Vector3 = _ancora_d if lado > 0.0 else _ancora_e
		lo = lo.min(a).min(b)
		hi = hi.max(a).max(b)
		var eixo := (b - a).normalized()
		var lado_v := fundo.cross(eixo).normalized()
		var comp := a.distance_to(b)
		var s := passo * 0.5
		var k := 0
		while s < comp and n < _elos_gola.multimesh.instance_count:
			var lv := lado_v if k % 2 == 0 else eixo.cross(lado_v).normalized()
			var base := Basis(lv, eixo, lv.cross(eixo)).scaled(Vector3.ONE * _escala)
			var o := n * 12
			var p := a.lerp(b, s / comp)
			# Linha a linha (a MultiMesh guarda a matriz 3x4 por linha).
			_buf_g[o] = base.x.x
			_buf_g[o + 1] = base.y.x
			_buf_g[o + 2] = base.z.x
			_buf_g[o + 3] = p.x
			_buf_g[o + 4] = base.x.y
			_buf_g[o + 5] = base.y.y
			_buf_g[o + 6] = base.z.y
			_buf_g[o + 7] = p.y
			_buf_g[o + 8] = base.x.z
			_buf_g[o + 9] = base.y.z
			_buf_g[o + 10] = base.z.z
			_buf_g[o + 11] = p.z
			n += 1
			k += 1
			s += passo
	var folga := Vector3.ONE * 0.03 * _escala
	_elos_gola.custom_aabb = AABB(lo - folga, hi - lo + folga * 2.0)
	_elos_gola.multimesh.buffer = _buf_g
	_elos_gola.multimesh.visible_instance_count = n


## Manda o buffer da corrente solta para a MultiMesh, com a caixa de corte dela
## (`lo`, `hi`) posta a mao: a caixa que a MultiMesh calcula e de TODAS as
## instancias, e as de sobra (a corrente frouxa usa menos elos que tem) ficam
## zeradas na origem do mundo, a 4 km da estrada. Com ela, a corrente sumia
## pela distancia de corte.
func _enviar(n: int, lo: Vector3, hi: Vector3) -> void:
	var av := AVANCO
	for v in _vid_c.size():
		# A distancia do ponto da corrente mais perto do vidro ate ele.
		var perto := INF
		for i in _p.size():
			perto = minf(perto, _p[i].distance_to(_vid_c[v]) - (_vid_r[v] - VIDRO_FOLGA * _escala))
		av = clampf(perto - 0.002, 0.0, av)
	_elos.set_instance_shader_parameter(&"avanco", av)
	_elos_gola.set_instance_shader_parameter(&"avanco", av)
	_cruz.set_instance_shader_parameter(&"avanco", av)
	var folga := Vector3.ONE * 0.03 * _escala
	_elos.custom_aabb = AABB(lo - folga, hi - lo + folga * 2.0)
	_elos.multimesh.buffer = _buf
	_elos.multimesh.visible_instance_count = n


# --- sonda (`--cruz-sonda=ARQ`) ----------------------------------------------

func _esconder_nos() -> void:
	if not _esconder_lido:
		_esconder_lido = true
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with("--cruz-esconder="):
				_esconder = arg.trim_prefix("--cruz-esconder=").split(",")
	if _esconder.is_empty() or Engine.get_process_frames() % 30 != 0:
		return
	for nome in _esconder:
		for n: Node in _corpo.find_children(nome, "", true, false):
			if n is Node3D:
				(n as Node3D).visible = false


static func _sonda_ligada() -> bool:
	if _sonda != null:
		return true
	if _sonda_tentou:
		return false
	_sonda_tentou = true
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--cruz-sonda="):
			var arq := arg.trim_prefix("--cruz-sonda=")
			_sonda = FileAccess.open(arq, FileAccess.WRITE)
			_sonda_elos = FileAccess.open(arq + ".elos", FileAccess.WRITE)
			_sonda_atraso = FileAccess.open(arq + ".atraso", FileAccess.WRITE)
			RenderingServer.frame_pre_draw.connect(_sondar_atraso)
			if _sonda != null:
				_sonda.store_line("t;quadro;corpo;escala;vis;rein;motivo;longe;dcam;salto_m;salto_t;salto_ponto_t;d_cara;n_cara;n_dentro;anc_pesc_e;anc_pesc_d;argola_t;pe_t;n_elos;corte;estica;dentro_solto;invertida")
	return _sonda != null


func _relogio() -> float:
	if _cena == null or not is_instance_valid(_cena):
		_cena = null
		var cs := get_tree().current_scene
		if cs != null and cs.get("_relogio_cena") != null:
			_cena = cs
		else:
			for n: Node in get_tree().root.find_children("*", "", true, false):
				if n.get("_relogio_cena") != null:
					_cena = n
					break
	return float(_cena.get("_relogio_cena")) if _cena != null else -1.0


func _elipsoide() -> AABB:
	var cap: Object = _corpo.get_meta(&"capuz", null)
	if cap != null and cap.has_method(&"_elipsoide_da_cabeca"):
		return cap.call(&"_elipsoide_da_cabeca", _corpo)
	return AABB(Vector3(-0.1, 0.05, -0.11) * _escala, Vector3(0.2, 0.25, 0.22) * _escala)


## Os pontos que o olho ve: os elos desenhados e a cruz (argola, haste e trave).
## `_sonda_tipos`: 0 elo solto, 1 elo do pescoco a gola, 2 cruz.
var _sonda_tipos := PackedByteArray()


func _pontos_vistos() -> PackedVector3Array:
	var pts := PackedVector3Array()
	_sonda_tipos.clear()
	if _longe_da_camera <= ELOS_ATE * _escala:
		for k in _elos.multimesh.visible_instance_count:
			var o := k * 12
			pts.append(Vector3(_buf[o + 3], _buf[o + 7], _buf[o + 11]))
			_sonda_tipos.append(0)
		var tg := _elos_gola.global_transform
		for k in _elos_gola.multimesh.visible_instance_count:
			var o := k * 12
			pts.append(tg * Vector3(_buf_g[o + 3], _buf_g[o + 7], _buf_g[o + 11]))
			_sonda_tipos.append(1)
	var a := _p[_i_cruz(0)]
	var pe := _p[_i_cruz(1)]
	for f in [0.0, 0.25, 0.5, 0.75, 1.0]:
		pts.append(a.lerp(pe, f))
	for f in [0.0, 0.5, 1.0]:
		pts.append(_p[_i_cruz(2)].lerp(_p[_i_cruz(3)], f))
	while _sonda_tipos.size() < pts.size():
		_sonda_tipos.append(2)
	return pts


func _sondar() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _longe_da_camera > ELOS_ATE * _escala:
		return
	var t := _torso()
	var inv := t.affine_inverse()
	var n := _p.size()
	var loc := PackedVector3Array()
	loc.resize(n)
	for i in n:
		loc[i] = inv * _p[i]
	var argola := _p[_i_cruz(0)]
	var salto_m := argola.distance_to(_sonda_argola) if _sonda_argola != Vector3.INF else 0.0
	var salto_t := 0.0
	var salto_ponto := 0.0
	if _sonda_local.size() == n:
		salto_t = loc[_i_cruz(0)].distance_to(_sonda_local[_i_cruz(0)])
		for i in n:
			salto_ponto = maxf(salto_ponto, loc[i].distance_to(_sonda_local[i]))
	_sonda_local = loc
	_sonda_argola = argola
	_sonda_torso = t
	if not _sondadas.has(self):
		_sondadas.append(self)
	# A cara: o elipsoide do cranio no osso da cabeca (a frente e -Z).
	var tc := _osso_cabeca()
	var inv_c := tc.affine_inverse()
	var el := _elipsoide()
	var cc := el.get_center()
	var ce := el.size * 0.5
	var d_cara := INF
	var n_cara := 0
	var n_dentro := 0
	var n_dentro_solto := 0
	var pts := _pontos_vistos()
	var rhos := PackedFloat32Array()
	# A lente no espaco da cabeca, escalado para o elipsoide virar esfera.
	var olho := (inv_c * cam.global_position - cc) / ce
	for p in pts:
		var q := inv_c * p - cc
		var rho := (q / ce).length()
		rhos.append(rho)
		var d := q.length() * (1.0 - 1.0 / maxf(rho, 1e-6))
		d_cara = minf(d_cara, d)
		if rho < 1.0:
			n_dentro += 1
			if _sonda_tipos[rhos.size() - 1] != 1:
				n_dentro_solto += 1
			continue
		# Na frente da cara: o raio da lente ao ponto cruza a cabeca depois
		# dele (o ponto tapa a cara). Raio o + u (q' - o), o ponto em u = 1.
		var dq := q / ce - olho
		var aa := dq.dot(dq)
		var bb := olho.dot(dq)
		var disc := bb * bb - aa * (olho.dot(olho) - 1.0)
		if disc > 0.0 and (-bb - sqrt(disc)) / aa > 1.0:
			n_cara += 1
	# A ancora ao eixo do pescoco (do osso da cabeca ao queixo).
	var pa := Vector3(0.0, -0.04 * _escala, 0.0)
	var pb := Vector3(0.0, cc.y - ce.y * 0.8, cc.z * 0.5)
	var anc := []
	for lado in [1.0, -1.0]:
		var q := inv_c * _pescoco(t, lado)
		var ab := pb - pa
		var tt := clampf((q - pa).dot(ab) / ab.dot(ab), 0.0, 1.0)
		anc.append(q.distance_to(pa + ab * tt))
	# O quanto o lado mais esticado passa do comprimento de repouso.
	var estica := 0.0
	for lado_i in 2:
		var ant := _ancora(t, 1.0 if lado_i == 0 else -1.0)
		var comp := 0.0
		for k in PONTOS:
			comp += ant.distance_to(_p[lado_i * PONTOS + k])
			ant = _p[lado_i * PONTOS + k]
		comp += ant.distance_to(argola)
		estica = maxf(estica, comp / maxf(_lado_comp, 1e-6))
	var vis := 1 if (visible and _cruz.is_visible_in_tree() and _elos.is_visible_in_tree()) else 0
	var rel := _relogio()
	_sonda_t = rel
	if _corpo.name == "Padre" and OS.get_cmdline_user_args().has("--cruz-dbg") and (rel > 46.2 and rel < 46.7 or rel > 49.8 and rel < 50.0):
		var tx := "[cruz-dbg] %s t=%.3f" % [_corpo.name, rel]
		for i in n:
			var m := _torso_rest * loc[i]
			tx += " %d:(%.3f,%.3f,%.3f|%.3f)" % [i, m.x / _escala, m.y / _escala, m.z / _escala,
				_frente_z(m.x, m.y) / _escala]
		print(tx)
	var at := loc[_i_cruz(0)]
	var pt := loc[_i_cruz(1)]
	_sonda.store_line("%.3f;%d;%s;%.3f;%d;%d;%d;%d;%.3f;%.4f;%.4f;%.4f;%.4f;%d;%d;%.4f;%.4f;%.3f,%.3f,%.3f;%.3f,%.3f,%.3f;%d;%d;%.3f;%d;%d" % [
		rel, Engine.get_process_frames(), _corpo.name, _escala, vis, 1 if _sonda_rein else 0,
		_motivo if _sonda_rein else 0, 1 if _sonda_longe else 0, _longe_da_camera, salto_m, salto_t,
		salto_ponto, d_cara, n_cara, n_dentro, anc[0], anc[1], at.x, at.y, at.z, pt.x, pt.y, pt.z,
		_elos.multimesh.visible_instance_count, 1 if _corte else 0, estica, n_dentro_solto,
		1 if _p[_i_cruz(1)].y > _p[_i_cruz(0)].y + 0.02 * _escala else 0])
	if _sonda_elos == null or _corpo.name != "Padre" or _longe_da_camera > 3.0:
		return
	var ct := cam.global_transform.affine_inverse()
	var tam := get_viewport().get_visible_rect().size
	var linhas := PackedStringArray()
	for k in pts.size():
		var p := pts[k]
		if cam.is_position_behind(p):
			continue
		var s := cam.unproject_position(p)
		var tipo: String = ["e", "g", "c"][_sonda_tipos[k]]
		linhas.append("%.3f;%s;%d;%.1f;%.1f;%.4f;%d;%d;%.3f" % [rel, tipo, k, s.x, s.y, -(ct * p).z, tam.x, tam.y, rhos[k]])
	_sonda_elos.store_string("\n".join(linhas) + "\n")


static func _sondar_atraso() -> void:
	for cr: Variant in _sondadas:
		if not is_instance_valid(cr):
			continue
		var c := cr as CruzNoPeito
		if not c.visible or c._longe_da_camera > ELOS_ATE * c._escala:
			continue
		var t := c._torso()
		var ang := (c._sonda_torso.basis.inverse() * t.basis).get_rotation_quaternion().get_angle()
		_sonda_atraso.store_line("%.3f;%s;%.4f;%.4f" % [c._sonda_t, c._corpo.name,
			t.origin.distance_to(c._sonda_torso.origin), ang])
