## Gota de chuva na lente da camera: a parte "lente" do criterio A18 do
## PLANO_AAA_4K.
##
## Quando existe
## -------------
## So quando ha uma LENTE ao ar livre: camera de fora (terceira pessoa, camera
## de perseguicao, camera de rota), chovendo, e com ceu aberto em cima. Na
## primeira pessoa quem leva a chuva e o olho, e olho pisca; dentro do carro
## quem leva e o para-brisa, que ja tem agua propria (`AguaVidro`). Debaixo de
## marquise nao nasce gota nova, e a que esta no vidro seca mais depressa.
##
## Por que 2D
## ----------
## A gota e desenhada por cima da imagem pronta, numa camada abaixo do HUD
## (`CAMADA`). Uma placa em 3D presa a camera entraria no TAA, que reprojeta
## pelo fundo e arrastaria a gota a cada giro. E cada gota e um retangulo do
## tamanho dela: o custo e a area molhada, nao a tela inteira.
##
## No PS1 STYLE este no nao existe (quem cria e o `DiretorChuvaFora`).
class_name GotasLente
extends CanvasLayer

const SHADER := "res://shaders/psx_gota_lente.gdshader"

## Abaixo do HUD (`UiEstilo.CAMADA_MAPA`, 100) e do pos (150): a gota esta no
## vidro da camera, e o mapa nao.
const CAMADA := 90
const MAXIMO := 14
## Gotas novas por segundo com chuva cheia e ceu aberto.
const TAXA := 1.4
const VIDA_MIN := 4.0
const VIDA_MAX := 9.0
## Segundos do fim da vida em que a gota evapora.
const SECA := 1.4
## Nascer: a gota bate e se espalha num instante.
const BATE := 0.08
## Diametro, em fracao da altura da tela.
const DIAMETRO_MIN := 0.03
const DIAMETRO_MAX := 0.085
## Retangulo mais alto que largo: a cauda da gota que escorre cabe dentro.
const ALONGA := 1.45
const CHANCE_ESCORRER := 0.35
## Velocidade de quem escorre, em alturas de tela por segundo.
const ESCORRE_MIN := 0.012
const ESCORRE_MAX := 0.05
## Sob cobertura a gota seca este tanto mais rapido.
const SECA_COBERTA := 2.5
## Raio para cima que decide se ha ceu aberto.
const ALTURA_TETO := 40.0
const PASSO_TETO := 0.25
## Correndo, o vento tira a gota do centro: velocidade da camera em m/s.
const VENTO_DE := 9.0
const VENTO_ATE := 26.0
## Braco mais curto que isto e primeira pessoa.
const BRACO_MINIMO := 0.8

## -1 automatico; 0 nunca; 1 sempre com ceu aberto (bancada).
var forcar: int = -1

var _gotas: Array[Dictionary] = []
var _pool: Array[ColorRect] = []
var _mat: ShaderMaterial
var _raiz: Control
var _aberto := false
var _lente := false
var _relogio := 0.0
var _acumulado := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "GotasLente"
	layer = CAMADA
	_rng.seed = 20260917
	_mat = ShaderMaterial.new()
	_mat.shader = load(SHADER) as Shader
	_raiz = Control.new()
	_raiz.name = "Vidro"
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_raiz)
	for i in MAXIMO:
		var r := ColorRect.new()
		r.name = "Gota%d" % i
		r.material = _mat
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.visible = false
		_raiz.add_child(r)
		_pool.append(r)


func _process(delta: float) -> void:
	_relogio -= delta
	if _relogio <= 0.0:
		_relogio = PASSO_TETO
		var camera := get_viewport().get_camera_3d()
		_lente = forcar == 1 or (forcar < 0 and camera != null and lente_ao_ar(camera))
		_aberto = _lente and camera != null and ceu_aberto(camera)
	if not _lente:
		# Trocou de camera: a outra lente esta seca.
		if not _gotas.is_empty():
			_gotas.clear()
			_esconder_sobras(0)
		return

	var chuva: float = Clima.chuva
	if _aberto:
		_acumulado += TAXA * chuva * delta
		while _acumulado >= 1.0:
			_acumulado -= 1.0
			_nascer()
	else:
		_acumulado = 0.0

	var tela := get_viewport().get_visible_rect().size
	var vento := smoothstep(VENTO_DE, VENTO_ATE, Lente.velocidade())
	var ritmo := 1.0 if _aberto else SECA_COBERTA
	var vivas := 0
	for g: Dictionary in _gotas:
		g["idade"] = float(g["idade"]) + delta * ritmo
		var centro: Vector2 = g["centro"]
		centro.y += float(g["escorre"]) * delta
		# O vento empurra para fora do centro da tela, e mais depressa que a
		# gota escorre.
		if vento > 0.0:
			var fora := (centro - Vector2(0.5, 0.5))
			if fora.length() < 0.01:
				fora = Vector2(1.0, 0.0)
			centro += fora.normalized() * vento * 0.35 * delta
			g["idade"] = float(g["idade"]) + delta * vento * 2.0
		g["centro"] = centro
	_gotas = _gotas.filter(func(g: Dictionary) -> bool:
		return float(g["idade"]) < float(g["vida"]) \
			and (g["centro"] as Vector2).y < 1.1)

	for g: Dictionary in _gotas:
		var r := _pool[vivas]
		vivas += 1
		var d := float(g["diametro"]) * tela.y
		var idade := float(g["idade"])
		var forca := minf(1.0, idade / BATE) \
			* clampf((float(g["vida"]) - idade) / SECA, 0.0, 1.0)
		# Secando, a gota encolhe: evaporacao tira agua pela borda.
		var escala := lerpf(0.55, 1.0, clampf((float(g["vida"]) - idade) / SECA, 0.0, 1.0))
		d *= escala
		var c: Vector2 = g["centro"]
		r.size = Vector2(d, d * ALONGA)
		r.position = Vector2(c.x * tela.x - d * 0.5, c.y * tela.y - d * 0.5)
		r.color = Color(float(g["semente"]),
			1.0 if float(g["escorre"]) > 0.0 else 0.0, 0.0, forca)
		r.visible = true
	_esconder_sobras(vivas)


func _esconder_sobras(de: int) -> void:
	for i in range(de, _pool.size()):
		_pool[i].visible = false


func _nascer() -> void:
	if _gotas.size() >= MAXIMO:
		# Sem vaga: a mais velha seca de vez.
		_gotas.pop_front()
	var escorre := 0.0
	if _rng.randf() < CHANCE_ESCORRER:
		escorre = _rng.randf_range(ESCORRE_MIN, ESCORRE_MAX)
	_gotas.append({
		"centro": Vector2(_rng.randf_range(0.04, 0.96), _rng.randf_range(0.04, 0.92)),
		"diametro": _rng.randf_range(DIAMETRO_MIN, DIAMETRO_MAX),
		"vida": _rng.randf_range(VIDA_MIN, VIDA_MAX),
		"idade": 0.0,
		"escorre": escorre,
		"semente": _rng.randf(),
	})


## Gotas no vidro agora. Para bancada e relatorio.
func quantas() -> int:
	return _gotas.size()


## Ha uma lente ao ar livre nesta camera?
##
## Fora: estilo PS1, interior, a camera de dentro do carro (o para-brisa leva a
## chuva) e o braco recolhido da primeira pessoa (o olho leva).
static func lente_ao_ar(camera: Camera3D) -> bool:
	if not Settings.luz_por_pixel or Interiores.dentro:
		return false
	if camera.name == &"CameraDeDentro":
		return false
	var no := camera.get_parent()
	while no != null:
		var braco := no as SpringArm3D
		if braco != null:
			return braco.spring_length >= BRACO_MINIMO
		if no is Window:
			break
		no = no.get_parent()
	return true


## Nada acima da camera ate `ALTURA_TETO`.
##
## Toldo nao tem colisao: quem sabe dele e o `DiretorChuvaFora`, pelas lajes do
## chunk. Sem o diretor (bancada), vale so a fisica.
static func ceu_aberto(camera: Camera3D) -> bool:
	var diretor := camera.get_node_or_null(^"/root/ChuvaFora")
	if diretor != null:
		return bool(diretor.call(&"ceu_aberto", camera.global_position))
	var espaco := camera.get_world_3d().direct_space_state
	if espaco == null:
		return true
	var de := camera.global_position
	var q := PhysicsRayQueryParameters3D.create(de, de + Vector3.UP * ALTURA_TETO, 1)
	return espaco.intersect_ray(q).is_empty()
