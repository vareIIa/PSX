## O retrovisor interno: carcaca, haste, e um vidro que reflete de verdade.
##
## Como o reflexo e feito
## ----------------------
## Espelho plano e o caso em que a solucao exata e barata, e e a mesma dos
## jogos de corrida: uma segunda camera no REFLEXO do olho, do outro lado do
## plano do vidro, olhando pela moldura do espelho. Nada de camera fixa virada
## para tras com a imagem invertida — essa so acerta para um olho parado num
## ponto, e aqui a cabeca balanca, vira para a curva e desce ao celular.
##
##   olho E, plano do vidro com centro P e normal n (para o motorista):
##   E' = E - 2 (E-P).n n
##   a camera fica em E' olhando ao longo de +n, com a base (-x, y, -n) do
##   vidro, e a projecao e um FRUSTUM FORA DO EIXO cujo plano perto e o proprio
##   vidro: `size` e a altura do vidro, `frustum_offset` e onde o centro do
##   vidro cai na frente de E'. Tudo o que esta atras do espelho (para-brisa,
##   capo, a estrada da frente) fica aquem do plano perto e nao entra.
##
## O vidro mapeia cada ponto dele no texel que a camera projetou ali, com o u
## invertido (u = 0,5 - x/w): e isso que troca a mao da imagem, e so isso — a
## camera tem base de rotacao pura, sem escala negativa, entao nada de face
## trocada ou sombra invertida.
##
## Luz: HDR linear, uma vez so
## ---------------------------
## A imagem do espelho e RADIANCIA, e e a tela principal que decide exposicao e
## curva. A camera do espelho tem ambiente proprio: o do mundo copiado a cada
## quadro (nevoa, ceu, luz ambiente — a transicao de nevoa anima o Environment,
## ver a memoria), com tonemap LINEAR e sem glow/SSR/SSAO/SSIL/SDFGI/ajuste, e
## atributos de camera com exposicao manual. O SubViewport e `use_hdr_2d`, o
## vidro devolve o texel como emissao, e a exposicao automatica e o AgX da
## tela principal passam por cima dele como por qualquer outra superficie. Sem
## isso o farol do carro de tras saia tonemapeado duas vezes: cinza e chapado.
##
## Custo
## -----
## A resolucao do espelho e a que ele ocupa NA TELA (altura projetada vezes a
## escala 3D da janela), com folga de 15% antes de realocar. No PS1 STYLE, que
## desenha em 480x270, isso da um espelho de 60 px — o espelho granulado de um
## jogo de 1999 sai de graca. Quando o vidro esta de costas, fora do quadro ou
## menor que `MIN_PX`, o SubViewport para (`UPDATE_DISABLED`) e o vidro fica
## com o ultimo quadro. `--sem-retrovisor` desliga o reflexo (lado B das
## medidas de custo).
class_name EspelhoRetrovisor
extends Node3D

## Camada so do vidro. A camera do espelho nao a desenha (nem precisaria: o
## plano perto ja o corta — ver `FOLGA_PERTO`).
const CAMADA_VIDRO := 1 << 19
## Camadas de primeira pessoa que o espelho nao ve: braco e aparelho do
## celular vivem colados na lente principal, e no espelho sairiam soltos.
const CAMADAS_DA_LENTE := (1 << 17) | (1 << 18)

## Medidas de um retrovisor de sedan do fim dos anos 90 (Marea, Vectra, Astra):
## carcaca 25 x 7,8 cm, 3,8 de fundo; vidro 23,6 x 6,4 com canto de 2,4 cm.
const CARCACA := Vector3(0.250, 0.078, 0.038)
const CARCACA_RAIO := 0.030
const VIDRO := Vector2(0.236, 0.064)
const VIDRO_RAIO := 0.024
## O vidro fica dois milimetros para dentro da moldura.
const VIDRO_FUNDO := 0.002
const HASTE_RAIO := 0.0065
const BOLA_RAIO := 0.011

## Folga do plano perto alem do vidro, em metros: corta o proprio vidro sem
## depender de camada e nao come nada que se veja.
const FOLGA_PERTO := 0.001
## Ate onde, do centro do vidro, uma camera conta como cabeca de quem esta no
## banco da frente.
const DENTRO_ATE := 1.1
## Distancia de desenho do espelho, em metros. A cidade chegou a 2034
## chamadas de desenho com o espelho contra 1311 sem (tests/bancada_fps_dirigir,
## sedan, dentro, 1080p): o cone de tras ia ate o fim da nevoa e a sombra do sol
## era refeita para ele inteiro. Oitenta metros e mais que o que um espelho de
## 23 cm resolve — um carro a 80 m ocupa dois pixels nele.
const ALCANCE := 80.0
## Menor altura do vidro na tela, em pixels, para valer um desenho.
const MIN_PX := 5.0
## Teto de altura da imagem, em pixels. 360 de altura com 23,6 x 6,4 da
## 1328 x 360: mais que o espelho ocupa em 4K com a cabeca encostada nele.
const MAX_PX := 360
## Quanto a altura projetada pode variar antes de realocar a imagem.
const FOLGA_TAMANHO := 0.15

## Refletancia de um espelho de prata com vidro na frente: ~0,86 no visivel,
## um pouco mais no azul. O vidro de verdade e um pouco verde na borda, mas a
## borda aqui fica debaixo da moldura.
const REFLETANCIA := Color(0.84, 0.86, 0.88)
## A cor da carcaca: plastico injetado grafite, granulado fosco.
const COR_CARCACA := Color(0.075, 0.075, 0.080, 0.75)

const CODIGO_VIDRO := """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D reflexo : hint_default_black, filter_linear, repeat_disable;
uniform vec3 refletancia = vec3(0.84, 0.86, 0.88);
uniform vec2 meio = vec2(0.118, 0.032);
// Correcao de aspecto: a imagem tem pixel inteiro, o vidro nao.
uniform float escala_u = 1.0;
// 1 no PS1 STYLE: amostra o texel cru, como o resto do jogo.
uniform float cru = 0.0;
// 0 enquanto nenhum quadro foi desenhado: vidro escuro, sem lixo de memoria.
uniform float ligado = 0.0;

varying vec3 p_loc;

float h12(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float ruido(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h12(i), h12(i + vec2(1, 0)), f.x),
		mix(h12(i + vec2(0, 1)), h12(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	p_loc = VERTEX;
}

void fragment() {
	vec2 uv = vec2(0.5 - p_loc.x / (2.0 * meio.x), 0.5 - p_loc.y / (2.0 * meio.y));
	uv.x = 0.5 + (uv.x - 0.5) * escala_u;
	vec3 r;
	if (cru > 0.5) {
		ivec2 t = textureSize(reflexo, 0);
		r = texelFetch(reflexo, clamp(ivec2(uv * vec2(t)), ivec2(0), t - 1), 0).rgb;
	} else {
		r = texture(reflexo, uv).rgb;
	}
	// Po e gordura: ninguem limpa o retrovisor. Pouco — a imagem e o assunto.
	vec2 q = p_loc.xy * vec2(1.0, 1.0);
	float po = smoothstep(0.35, 0.95, ruido(q * 90.0) * 0.6 + ruido(q * 23.0) * 0.4);
	// O dedo que ajusta pega na carcaca, mas a ponta encosta na borda do vidro.
	float dedo = smoothstep(0.022, 0.0, length((p_loc.xy - vec2(-meio.x * 0.82, meio.y * 0.35)) * vec2(0.8, 1.2)));
	float sujo = clamp(po * 0.5 + dedo * 0.8, 0.0, 1.0);
	// Canto: a prata escurece nos ultimos milimetros, onde a moldura aperta.
	vec2 d = abs(p_loc.xy) - (meio - vec2(0.003));
	float borda = smoothstep(-0.004, 0.0, max(d.x, d.y));
	vec3 imagem = r * refletancia * ligado * (1.0 - 0.10 * sujo) * (1.0 - 0.35 * borda);
	// A superficie da frente e vidro comum: um reflexo fraco e a sujeira pegam
	// a luz da cabine por conta propria. A imagem vem inteira da prata.
	ALBEDO = vec3(0.004) + vec3(0.020, 0.019, 0.017) * sujo;
	ROUGHNESS = mix(0.06, 0.45, sujo);
	SPECULAR = 0.25;
	EMISSION = imagem;
}
"""

static var _shader_vidro: Shader

## Liga e desliga o reflexo. Desligado, o vidro fica com o ultimo quadro.
var ativo := true

var _vidro: MeshInstance3D
var _carcaca: MeshInstance3D
var _centro := Vector3.ZERO
var _dir_alvo := Vector3.BACK
var _ancora := Vector3.ZERO
## A normal do para-brisa para dentro da cabine, no espaco do pai. Zero: a base
## da haste se orienta pela propria haste.
var _normal_vidro := Vector3.ZERO
## A camera para a qual o espelho ja foi regulado.
var _regulado: Camera3D
var _mat_vidro: ShaderMaterial
var _vp: SubViewport
var _cam: Camera3D
var _env: Environment
var _env_origem: Environment
var _props_env: Array[StringName] = []
var _atrib: CameraAttributesPractical
var _alt_px := 0
var _desenhou := false
var _cru := false
## `--debug-retrovisor`: imprime a conta de resolucao a cada 30 quadros.
var _depurar := false
## `--retrovisor-foto=<pasta>`.
var _pasta_foto := ""
## Para bancada: quantos quadros o espelho desenhou e o tamanho atual.
var quadros := 0


## Monta o retrovisor. `centro` e o meio do vidro; `olho` e o olho de quem
## dirige e `alvo` o ponto que esse olho ve no meio do espelho — o espelho vem
## regulado. `ancora` e o ponto do para-brisa onde a haste cola. Tudo no espaco
## do pai.
func montar(centro: Vector3, olho: Vector3, alvo: Vector3, ancora: Vector3,
		normal_do_vidro := Vector3.ZERO) -> void:
	_normal_vidro = normal_do_vidro
	_centro = centro
	_dir_alvo = (alvo - centro).normalized()
	_ancora = ancora
	_carcaca = MeshInstance3D.new()
	_carcaca.name = "Carcaca"
	_carcaca.material_override = CabineMateriais.plastico()
	add_child(_carcaca)
	regular(olho)

	_vidro = MeshInstance3D.new()
	_vidro.name = "Vidro"
	_vidro.mesh = _malha_vidro()
	_vidro.position = Vector3(0.0, 0.0, -VIDRO_FUNDO)
	_vidro.layers = CAMADA_VIDRO
	_vidro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat_vidro = ShaderMaterial.new()
	_mat_vidro.shader = _shader()
	_mat_vidro.set_shader_parameter(&"refletancia",
		Vector3(REFLETANCIA.r, REFLETANCIA.g, REFLETANCIA.b))
	_mat_vidro.set_shader_parameter(&"meio", VIDRO * 0.5)
	_vidro.material_override = _mat_vidro
	add_child(_vidro)

	if OS.get_cmdline_user_args().has("--sem-retrovisor") \
			or DisplayServer.get_name() == "headless":
		ativo = false
		return
	_montar_camera()


## Aponta o espelho para que `olho` (espaco do pai) veja no meio dele a mesma
## direcao de sempre. E o motorista regulando o retrovisor quando senta: a
## cabine monta com o olho de `CarroCabine.olho()`, e a primeira camera de
## dentro que olha o espelho o regula para a propria cabeca (`_regular_para`).
func regular(olho: Vector3) -> void:
	var n := ((olho - _centro).normalized() + _dir_alvo).normalized()
	var x := Vector3.UP.cross(n).normalized()
	var y := n.cross(x).normalized()
	transform = Transform3D(Basis(x, y, n), _centro)
	_carcaca.mesh = _malha_carcaca(transform.affine_inverse() * _ancora)


## O centro do vidro e a normal dele, no espaco global. Para bancada.
func plano() -> Transform3D:
	return Suavidade.global(_vidro) if _vidro != null else global_transform


## A textura que o vidro mostra. Para bancada.
func imagem() -> Texture2D:
	return _vp.get_texture() if _vp != null else null


static func _shader() -> Shader:
	if _shader_vidro == null:
		_shader_vidro = Shader.new()
		_shader_vidro.code = CODIGO_VIDRO
	return _shader_vidro


func _montar_camera() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a == "--debug-retrovisor":
			_depurar = true
		elif a.begins_with("--retrovisor-foto="):
			_pasta_foto = a.trim_prefix("--retrovisor-foto=")
	_vp = SubViewport.new()
	_vp.name = "Reflexo"
	_vp.size = Vector2i(64, 18)
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.use_hdr_2d = true
	_vp.transparent_bg = false
	# Sem sombra de luz pontual (poste, lampada de bar): e um atlas inteiro
	# redesenhado por quadro para um espelho de 6 cm de altura. A sombra do sol
	# fica — ela diz a hora do dia na pista de tras.
	_vp.positional_shadow_atlas_size = 0
	# LOD mais grosso: o espelho mostra a rua de tras a 1/4 da tela.
	_vp.mesh_lod_threshold = 4.0
	add_child(_vp)
	_cam = Camera3D.new()
	_cam.name = "Olho"
	_cam.projection = Camera3D.PROJECTION_FRUSTUM
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	_cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	# Sem o desfoque de movimento do mundo: ele vive no compositor do ambiente,
	# e o espelho ja e pequeno demais para rastro.
	_cam.compositor = Compositor.new()
	_env = Environment.new()
	_cam.environment = _env
	_atrib = CameraAttributesPractical.new()
	_atrib.auto_exposure_enabled = false
	_atrib.dof_blur_far_enabled = false
	_atrib.dof_blur_near_enabled = false
	_cam.attributes = _atrib
	_vp.add_child(_cam)
	_cam.current = true
	_mat_vidro.set_shader_parameter(&"reflexo", _vp.get_texture())
	process_priority = 1000
	var ajustes := _ajustes()
	if ajustes != null and ajustes.has_signal(&"changed"):
		ajustes.connect(&"changed", _estilo)
	_estilo()


## O autoload `Settings` pelo no, e nao pelo nome: citado direto, a classe nao
## compila em `--script` (testes de nivel 2 sem autoload) e derruba a cabine
## inteira junto.
func _ajustes() -> Node:
	var arvore := Engine.get_main_loop() as SceneTree
	return arvore.root.get_node_or_null(^"Settings") if arvore != null else null


func _estilo() -> void:
	var ajustes := _ajustes()
	_cru = ajustes != null and not bool(ajustes.get(&"luz_por_pixel"))
	_mat_vidro.set_shader_parameter(&"cru", 1.0 if _cru else 0.0)


func _exit_tree() -> void:
	var ajustes := _ajustes()
	if ajustes != null and ajustes.is_connected(&"changed", _estilo):
		ajustes.disconnect(&"changed", _estilo)


func _process(_delta: float) -> void:
	if _vp == null:
		return
	if not _desenhar():
		_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED


## Poe a camera do espelho no reflexo do olho deste quadro. Devolve falso se
## nao vale desenhar.
func _desenhar() -> bool:
	if not ativo or not is_visible_in_tree():
		return false
	var principal := get_viewport().get_camera_3d()
	if principal == null or principal == _cam:
		return false
	_regular_para(principal)
	var m := Suavidade.global(_vidro)
	var xm := m.basis.x.normalized()
	var ym := m.basis.y.normalized()
	var n := m.basis.z.normalized()
	var p := m.origin
	var olho := Suavidade.lente(principal).origin
	var d := (olho - p).dot(n)
	if d < 0.02:
		return false

	var alt := _altura_na_tela(principal, p, xm, ym)
	if alt < MIN_PX:
		return false
	_dimensionar(alt)

	var k := (d + FOLGA_PERTO) / d
	_cam.global_transform = Transform3D(Basis(-xm, ym, -n), olho - n * (2.0 * d))
	_cam.near = d + FOLGA_PERTO
	_cam.far = clampf(principal.far, d + 1.0, ALCANCE)
	_cam.size = VIDRO.y * k
	_cam.frustum_offset = Vector2((olho - p).dot(xm), -(olho - p).dot(ym)) * k
	_cam.cull_mask = principal.cull_mask & ~(CAMADA_VIDRO | CAMADAS_DA_LENTE)
	_sincronizar_ambiente()

	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if not _desenhou:
		_desenhou = true
		_mat_vidro.set_shader_parameter(&"ligado", 1.0)
	quadros += 1
	if not _pasta_foto.is_empty() and quadros % 150 == 0:
		_foto_de_bancada()
	return true


## `--retrovisor-foto=<pasta>`: grava a imagem do espelho (HDR, em EXR) a cada
## 150 quadros desenhados. Bancada.
func _foto_de_bancada() -> void:
	DirAccess.make_dir_recursive_absolute(_pasta_foto)
	var n := quadros
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_exr(_pasta_foto.path_join("espelho_%05d.exr" % n))
	print("[retrovisor] foto %d %s" % [n, _vp.size])


## Regula o espelho para a cabeca de uma camera de dentro, uma vez por
## camera. Camera de fora (plano de rua, de mata) nao mexe nele: ninguem regula
## o retrovisor de outro carro.
func _regular_para(principal: Camera3D) -> void:
	if principal == _regulado or not is_inside_tree():
		return
	var pai := get_parent() as Node3D
	if pai == null:
		return
	var olho := Suavidade.global(pai).affine_inverse() * Suavidade.lente(principal).origin
	if olho.distance_to(_centro) > DENTRO_ATE:
		return
	_regulado = principal
	regular(olho)


## Altura do vidro na imagem 3D da tela principal, em pixels; zero se ele esta
## inteiro fora do quadro.
func _altura_na_tela(principal: Camera3D, p: Vector3, xm: Vector3, ym: Vector3) -> float:
	var hx := xm * VIDRO.x * 0.5
	var hy := ym * VIDRO.y * 0.5
	var cantos: Array[Vector3] = [p - hx - hy, p + hx - hy, p + hx + hy, p - hx + hy]
	var tela := principal.get_viewport().get_visible_rect().size
	var r := Rect2()
	var algum := false
	for c: Vector3 in cantos:
		if Suavidade.atras(principal, c):
			continue
		var s := Suavidade.projetar(principal, c)
		if not algum:
			r = Rect2(s, Vector2.ZERO)
			algum = true
		else:
			r = r.expand(s)
	if not algum or not r.intersects(Rect2(Vector2.ZERO, tela)):
		return 0.0
	# A altura do vidro, e nao da caixa: de lado o espelho encurta em x, e a
	# imagem so precisa de tantos pixels quanto o lado mais curto pede. A
	# altura vem pelo lado de x corrigido pelo aspecto, que e o eixo que o olho
	# ve mais inteiro.
	var alt := maxf(r.size.y, r.size.x * VIDRO.y / VIDRO.x)
	# `projetar` mede no retangulo visivel, que no CANVAS_ITEMS e a base de
	# 480x270; o 3D desenha no tamanho da janela. A razao das duas e o que vale.
	var vp := principal.get_viewport()
	# (`get_texture().get_size()` da janela nao serve: devolveu 5334x3000 numa
	# janela de 1600x900.)
	# No modo VIEWPORT (PS1 STYLE) o 3D desenha na propria base, e a razao e 1.
	var real := tela
	if vp is SubViewport:
		real = Vector2((vp as SubViewport).size)
	elif vp is Window and (vp as Window).content_scale_mode != Window.CONTENT_SCALE_MODE_VIEWPORT:
		real = Vector2((vp as Window).size)
	var escala := vp.scaling_3d_scale * (real.y / maxf(1.0, tela.y))
	if _depurar and Engine.get_process_frames() % 30 == 0:
		print("[retrovisor] tela=%s real=%s 3d=%.2f alt=%.1f -> %.1f" % [tela, real,
			vp.scaling_3d_scale, alt, alt * escala])
	return alt * escala


func _dimensionar(alt: float) -> void:
	var quer := clampi(int(ceil(alt)), 8, MAX_PX)
	if _alt_px > 0 and absf(float(quer - _alt_px)) <= float(_alt_px) * FOLGA_TAMANHO:
		return
	_alt_px = quer
	var larg := maxi(8, int(round(float(quer) * VIDRO.x / VIDRO.y)))
	_vp.size = Vector2i(larg, quer)
	# A imagem cobre VIDRO.y de altura e larg/quer * VIDRO.y de largura.
	var cobre := float(larg) / float(quer) * VIDRO.y
	_mat_vidro.set_shader_parameter(&"escala_u", VIDRO.x / cobre)
	var principal := get_viewport()
	_vp.msaa_3d = principal.msaa_3d
	_vp.use_debanding = principal.use_debanding


## O ambiente do mundo, menos o que e da tela: curva, exposicao, glow, efeitos
## de espaco de tela e GI. Copia so o que mudou — a transicao de nevoa anima
## o Environment do mundo a cada quadro.
func _sincronizar_ambiente() -> void:
	var w := get_viewport().find_world_3d()
	if w == null:
		return
	var origem := w.environment if w.environment != null else w.fallback_environment
	if origem == null:
		return
	if origem != _env_origem:
		_env_origem = origem
		_props_env.clear()
		for p: Dictionary in origem.get_property_list():
			if not (int(p["usage"]) & PROPERTY_USAGE_STORAGE):
				continue
			var nome := String(p["name"])
			if nome in ["resource_local_to_scene", "resource_path", "resource_name",
					"script", "resource_scene_unique_id"]:
				continue
			var fora := false
			for prefixo: String in ["tonemap_", "glow_", "ssr_", "ssao_", "ssil_",
					"sdfgi_", "adjustment_", "volumetric_fog_"]:
				if nome.begins_with(prefixo):
					fora = true
					break
			if not fora:
				_props_env.append(StringName(nome))
		_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		_env.tonemap_exposure = 1.0
		_env.tonemap_white = 1.0
		_env.glow_enabled = false
		_env.ssr_enabled = false
		_env.ssao_enabled = false
		_env.ssil_enabled = false
		_env.sdfgi_enabled = false
		_env.adjustment_enabled = false
		_env.volumetric_fog_enabled = false
	for nome: StringName in _props_env:
		var v: Variant = origem.get(nome)
		if _env.get(nome) != v:
			_env.set(nome, v)
	var a := w.camera_attributes
	if a != null:
		_atrib.exposure_multiplier = a.exposure_multiplier
		_atrib.exposure_sensitivity = a.exposure_sensitivity


# --- malhas -----------------------------------------------------------------

## Um retangulo de cantos redondos, em sentido anti-horario, centrado na
## origem.
static func _perfil(tam: Vector2, raio: float, passos: int = 5) -> PackedVector2Array:
	var r := minf(raio, minf(tam.x, tam.y) * 0.5)
	var h := tam * 0.5 - Vector2(r, r)
	var pts := PackedVector2Array()
	var centros := [Vector2(h.x, h.y), Vector2(-h.x, h.y), Vector2(-h.x, -h.y), Vector2(h.x, -h.y)]
	for q in 4:
		for i in passos + 1:
			var a := (float(q) + float(i) / float(passos)) * PI * 0.5
			pts.append(centros[q] + Vector2(cos(a), sin(a)) * r)
	return pts


## Triangulo com a frente para `lado`. O Godot desenha a frente em sentido
## HORARIO (ver a memoria "armadilhas mudas do Godot"); a conta aqui decide a
## ordem pelo produto vetorial em vez de confiar no chute de cada chamada.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, lado: Vector3,
		na := Vector3.ZERO, nb := Vector3.ZERO, nc := Vector3.ZERO) -> void:
	var n := (b - a).cross(c - a)
	if na == Vector3.ZERO:
		var f := lado.normalized()
		na = f
		nb = f
		nc = f
	if n.dot(lado) > 0.0:
		var t := b
		b = c
		c = t
		var tn := nb
		nb = nc
		nc = tn
	st.set_normal(na)
	st.add_vertex(a)
	st.set_normal(nb)
	st.add_vertex(b)
	st.set_normal(nc)
	st.add_vertex(c)


## Liga dois aneis do mesmo numero de pontos com faixas voltadas para fora.
## `na` e `nb` sao as normais 2D do contorno em cada anel (ver `_normais`); a
## normal 3D inclina para tras na medida em que o anel de tras e menor, o que
## da o volume de travesseiro da carcaca sem mais anel.
static func _faixa(st: SurfaceTool, a: PackedVector3Array, b: PackedVector3Array,
		na: PackedVector2Array, nb: PackedVector2Array) -> void:
	var n := a.size()
	var ma := PackedVector3Array()
	var mb := PackedVector3Array()
	for i in n:
		var dz := a[i].z - b[i].z
		var dr := Vector2(a[i].x - b[i].x, a[i].y - b[i].y).dot(na[i])
		ma.append((Vector3(na[i].x, na[i].y, 0.0) * dz - Vector3(0, 0, dr)).normalized())
		dr = Vector2(a[i].x - b[i].x, a[i].y - b[i].y).dot(nb[i])
		mb.append((Vector3(nb[i].x, nb[i].y, 0.0) * dz - Vector3(0, 0, dr)).normalized())
	for i in n:
		var j := (i + 1) % n
		var fora := ma[i] + ma[j] + mb[i] + mb[j]
		_tri(st, a[i], b[i], b[j], fora, ma[i], mb[i], mb[j])
		_tri(st, a[i], b[j], a[j], fora, ma[i], mb[j], ma[j])


## As normais para fora do contorno de `_perfil`, ja com a escala do anel.
static func _normais(passos: int, escala := Vector2.ONE) -> PackedVector2Array:
	var r := PackedVector2Array()
	for q in 4:
		for i in passos + 1:
			var a := (float(q) + float(i) / float(passos)) * PI * 0.5
			r.append((Vector2(cos(a) / escala.x, sin(a) / escala.y)).normalized())
	return r


static func _anel(perfil: PackedVector2Array, z: float, escala := Vector2.ONE) -> PackedVector3Array:
	var r := PackedVector3Array()
	for p: Vector2 in perfil:
		r.append(Vector3(p.x * escala.x, p.y * escala.y, z))
	return r


## Carcaca, moldura, bola, haste e base. `ancora` e o ponto do para-brisa, no
## espaco deste no.
func _malha_carcaca(ancora: Vector3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(COR_CARCACA)
	var fora := _perfil(Vector2(CARCACA.x, CARCACA.y), CARCACA_RAIO, 6)
	var boca := _perfil(VIDRO, VIDRO_RAIO, 6)
	# A boca tem de ter o mesmo numero de pontos do contorno: a moldura e uma
	# faixa ligando os dois.
	var d := CARCACA.z
	var escalas: Array[Vector2] = [Vector2.ONE, Vector2(1.012, 1.03),
		Vector2(0.94, 0.80), Vector2(0.78, 0.52)]
	var fundos: Array[float] = [0.0, -d * 0.30, -d * 0.70, -d * 0.95]
	var aneis: Array[PackedVector3Array] = []
	for i in escalas.size():
		aneis.append(_anel(fora, fundos[i], escalas[i]))
	for i in aneis.size() - 1:
		_faixa(st, aneis[i], aneis[i + 1], _normais(6, escalas[i]),
			_normais(6, escalas[i + 1]))
	# Fundo: leque ate o meio, levemente abaulado.
	var tras := aneis[aneis.size() - 1]
	var polo := Vector3(0.0, 0.0, -d)
	for i in tras.size():
		var j := (i + 1) % tras.size()
		_tri(st, polo, tras[i], tras[j], Vector3.FORWARD)
	# Moldura: do contorno de fora ate a boca, na face da frente.
	var anel_f := aneis[0]
	var anel_b := _anel(boca, 0.0)
	for i in anel_f.size():
		var j := (i + 1) % anel_f.size()
		_tri(st, anel_f[i], anel_b[i], anel_b[j], Vector3.BACK)
		_tri(st, anel_f[i], anel_b[j], anel_f[j], Vector3.BACK)
	# Parede da boca: da frente ate o vidro, virada para dentro.
	var anel_v := _anel(boca, -VIDRO_FUNDO)
	for i in anel_b.size():
		var j := (i + 1) % anel_b.size()
		var dentro := -Vector3(anel_b[i].x + anel_b[j].x, anel_b[i].y + anel_b[j].y, 0.0)
		_tri(st, anel_b[i], anel_v[i], anel_v[j], dentro)
		_tri(st, anel_b[i], anel_v[j], anel_b[j], dentro)
	# A lingueta dia/noite, embaixo no meio.
	_caixa(st, Vector3(0.0, -CARCACA.y * 0.5 - 0.004, -d * 0.35), Vector3(0.030, 0.008, 0.012))

	# Bola da articulacao nas costas, a haste ate o para-brisa e a base colada.
	var bola := Vector3(0.0, CARCACA.y * 0.18, -d * 0.92)
	_esfera(st, bola, BOLA_RAIO)
	var dir := (ancora - bola)
	# A base e uma pastilha colada NO vidro: orientada pelo plano dele, e nao
	# pela haste. Pela haste ela entrava quatro centimetros no para-brisa
	# (`checar_cabine_contida`, nos sete modelos).
	var base_n := dir.normalized()
	if _normal_vidro != Vector3.ZERO:
		base_n = -(transform.basis.inverse() * _normal_vidro).normalized()
	# A haste termina na face de dentro da pastilha, com a bolinha inteira do
	# lado da cabine.
	var fim := ancora - base_n * (0.0065 + HASTE_RAIO * 1.35)
	_cilindro(st, bola, fim, HASTE_RAIO)
	_esfera(st, fim, HASTE_RAIO * 1.35)
	var bx := Vector3.UP.cross(base_n)
	if bx.length() < 0.1:
		bx = Vector3.RIGHT
	bx = bx.normalized()
	var by := base_n.cross(bx).normalized()
	_caixa_livre(st, ancora - base_n * 0.0035, Basis(bx, by, base_n), Vector3(0.030, 0.042, 0.006))
	return st.commit()


func _malha_vidro() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var boca := _anel(_perfil(VIDRO, VIDRO_RAIO, 6), 0.0)
	var meio := Vector3.ZERO
	for i in boca.size():
		var j := (i + 1) % boca.size()
		_tri(st, meio, boca[i], boca[j], Vector3.BACK)
	# O vidro fica no plano z = 0 do NO do vidro, e o no fica `VIDRO_FUNDO`
	# para dentro: o reflexo e calculado da origem dele.
	return st.commit()


static func _caixa(st: SurfaceTool, c: Vector3, t: Vector3) -> void:
	_caixa_livre(st, c, Basis(), t)


static func _caixa_livre(st: SurfaceTool, c: Vector3, b: Basis, t: Vector3) -> void:
	var h := t * 0.5
	for eixo in 3:
		for s: float in [-1.0, 1.0]:
			var n := b[eixo] * s
			var u := b[(eixo + 1) % 3] * h[(eixo + 1) % 3]
			var v := b[(eixo + 2) % 3] * h[(eixo + 2) % 3]
			var o := c + n * h[eixo]
			_tri(st, o - u - v, o + u - v, o + u + v, n)
			_tri(st, o - u - v, o + u + v, o - u + v, n)


static func _esfera(st: SurfaceTool, c: Vector3, r: float, aneis := 6, gomos := 10) -> void:
	for i in aneis:
		var a0 := PI * float(i) / float(aneis) - PI * 0.5
		var a1 := PI * float(i + 1) / float(aneis) - PI * 0.5
		for j in gomos:
			var b0 := TAU * float(j) / float(gomos)
			var b1 := TAU * float(j + 1) / float(gomos)
			var p00 := Vector3(cos(a0) * cos(b0), sin(a0), cos(a0) * sin(b0))
			var p01 := Vector3(cos(a0) * cos(b1), sin(a0), cos(a0) * sin(b1))
			var p10 := Vector3(cos(a1) * cos(b0), sin(a1), cos(a1) * sin(b0))
			var p11 := Vector3(cos(a1) * cos(b1), sin(a1), cos(a1) * sin(b1))
			var f := (p00 + p01 + p10 + p11)
			if i > 0:
				_tri(st, c + p00 * r, c + p01 * r, c + p11 * r, f, p00, p01, p11)
			if i < aneis - 1:
				_tri(st, c + p00 * r, c + p11 * r, c + p10 * r, f, p00, p11, p10)


static func _cilindro(st: SurfaceTool, a: Vector3, b: Vector3, r: float, gomos := 10) -> void:
	var eixo := (b - a).normalized()
	var u := eixo.cross(Vector3.UP)
	if u.length() < 0.1:
		u = eixo.cross(Vector3.RIGHT)
	u = u.normalized()
	var v := eixo.cross(u).normalized()
	for j in gomos:
		var t0 := TAU * float(j) / float(gomos)
		var t1 := TAU * float(j + 1) / float(gomos)
		var n0 := u * cos(t0) + v * sin(t0)
		var n1 := u * cos(t1) + v * sin(t1)
		_tri(st, a + n0 * r, b + n0 * r, b + n1 * r, n0 + n1, n0, n0, n1)
		_tri(st, a + n0 * r, b + n1 * r, a + n1 * r, n0 + n1, n0, n1, n1)
