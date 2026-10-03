## O sangue (e a lama) na lente: o que o padre cospe na fala, a lama com sangue
## do impacto no chao e o que pinga da cara dele no ultimo olhar (Parte 2 de
## `INTRO-PADRE/PLANO_BOCA_SANGUE.md`, nos tempos de
## `INTRO-PADRE/PLANO_JOGADO_PARA_FORA.md`).
##
## Por que existe
## --------------
## O pedido e o sangue cuspido "respingando na tela", AAA. O `SANGUE_NA_VISTA`
## do agarrao era um desenho radial que abria e fechava; aqui o sangue fica: cai
## em respingo com espinhos e gotas satelite, escorre com a gravidade quando e
## grosso, deixa a mancha fina parada, coagula (de vermelho vivo a vinho
## escuro) e refrata o que esta atras, como liquido numa lente. A lama do chao
## e outro canal: gruda, quase nao escorre, e suja por cima.
##
## Como funciona
## -------------
## Um acumulador de tela: um `SubViewport` que nunca limpa, em HDR (`RGBA16F`),
## com o estado por pixel:
##   R  espessura do sangue (0 nada, ~0,3 mancha, 1+ gota grossa que escorre)
##   G  espessura da lama
##   B  frescor (1 recem-caido, cai a 0 em ~15 s: o sangue escurece)
## Todo quadro um retangulo cheio (`SIMULA`) le o quadro anterior do proprio
## viewport (a copia de tela) e anda um passo: a parte grossa desce, torta; a
## fina fica; o frescor cai. Por cima, os respingos novos somam (`blend_add`),
## cada um por um quadro so.
## Na tela, uma camada (`CAMADA`, abaixo do pos, das faixas do cinema e do
## branco) le o acumulador e a imagem pronta: refrata pela inclinacao da
## espessura, absorve (o sangue fino tinge, o grosso quase apaga), pinta a cor
## propria dele acesa pela luz da cena, a lama por cima, o brilho de molhado e a
## borda escura do menisco. Onde nao ha nada, descarta: a imagem passa intacta.
##
## Fica na cena (`de(cena)`), e nao no carro: sobrevive a lente saindo pela
## janela e rolando no chao.
class_name SangueNaLente
extends CanvasLayer

## Abaixo do pos (150), das faixas do cinema (145) e do branco (200): o sangue
## esta no vidro da lente, e o grao e a vinheta passam por cima dele.
const CAMADA := 135
## A altura do acumulador (px); a largura segue o aspecto da tela.
const ALTURA := 1080
## Respingos que cabem num quadro (os filetes somam um por quadro cada).
const POR_QUADRO := 64
## O escorrer do acumulador (por grade) fica desligado: colunas vizinhas andando
## diferente cortavam a mancha em retas. Quem escorre sao os filetes.
const ESCORRE := 0.0
const ESCORRE_DE := 0.42
## Os filetes: quantos no maximo, a velocidade de saida (alturas de tela por
## segundo), quanto freiam por segundo, a largura (fracao da altura) e a
## espessura do rastro.
const FILETES_MAX := 16
const FILETE_VEL := Vector2(0.05, 0.13)
const FILETE_FREIA := 0.55
const FILETE_LARGURA := Vector2(0.0028, 0.006)
const FILETE_RASTRO := 0.14
## Em quantos segundos o sangue perde o frescor.
const COAGULA := 15.0
## O retangulo do respingo e maior que ele (o shader escala igual).
const FOLGA := 1.6

const SIMULA := """
shader_type canvas_item;
render_mode blend_disabled, unshaded;

uniform sampler2D anterior : hint_screen_texture, filter_linear;
uniform float dt = 0.016;
uniform float tempo = 0.0;
uniform vec2 px = vec2(0.00052, 0.00093);
uniform float escorre = 0.07;
uniform float escorre_de = 0.32;
uniform float coagula = 15.0;
uniform float limpa = 0.0;

float h(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y);
}

// A parte que anda: o que passa da mancha que fica.
float anda(float t, float de) {
	return max(t - de, 0.0);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 a = texture(anterior, uv).rgb;
	// O que esta acima desce ate aqui: o fio grosso anda mais depressa, e
	// serpenteia um nada (a lente nao e lisa).
	// So escorre em filetes: colunas finas de acaso; entre elas a mancha fica.
	// Com a gota inteira andando ela descia como um bloco de lados retos.
	float filete = smoothstep(0.5, 0.78, ruido(vec2(uv.x / px.x / 9.0, 3.3)))
		* (0.6 + 0.4 * ruido(vec2(uv.x / px.x / 3.0, 7.1)));
	float v = escorre * clamp(anda(a.r, escorre_de) * 1.4 + 0.25, 0.0, 1.5) * filete;
	float torto = (ruido(vec2(uv.x * 55.0, uv.y * 7.0 + tempo * 0.15)) - 0.5) * px.x * 2.0;
	// No acumulador o y do SCREEN_UV cresce para cima: o que esta acima e +y.
	vec2 de_cima = uv + vec2(torto, v * dt);
	vec3 c = texture(anterior, de_cima).rgb;
	float r = a.r - anda(a.r, escorre_de) * clamp(v * dt / px.y, 0.0, 1.0)
		+ anda(c.r, escorre_de) * clamp(v * dt / px.y, 0.0, 1.0);
	// A lama gruda: so a muito grossa desce, devagar.
	float vg = escorre * 0.25;
	vec3 cg = texture(anterior, uv + vec2(0.0, vg * dt)).rgb;
	float g = a.g - anda(a.g, 0.8) * clamp(vg * dt / px.y, 0.0, 1.0)
		+ anda(cg.g, 0.8) * clamp(vg * dt / px.y, 0.0, 1.0);
	// O frescor anda com o sangue que escorre e cai com o tempo.
	float b = mix(a.b, c.b, clamp(anda(c.r, escorre_de) * 2.0, 0.0, 1.0) * 0.5);
	b = clamp(b - dt / coagula, 0.0, 1.0);
	// A mancha fina seca um nada (so para nao ficar eterna a meia tinta).
	r = max(r - dt * 0.004, 0.0);
	vec3 s = vec3(r, g, b) * (1.0 - limpa);
	COLOR = vec4(s, 1.0);
}
"""

const RESPINGO := """
shader_type canvas_item;
render_mode blend_add, unshaded;

// 0 sangue, 1 lama, 2 nevoa (gotinhas), 3 gota (redonda, grossa)
uniform float tipo = 0.0;
uniform float forca = 1.0;
uniform float semente = 0.0;
uniform vec2 dir = vec2(0.0, 0.0);
uniform float com_sangue = 0.0;

float h(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + semente * 13.7) * 43758.5453);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	// O retangulo tem folga (`FOLGA`): o respingo cabe inteiro, e a borda some
	// antes da beira (antes, espinho e gota saiam cortados em reta).
	vec2 p = (UV * 2.0 - 1.0) * 1.6;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float m = 0.0;
	float grosso = 0.0;
	float beira = smoothstep(1.58, 1.3, max(abs(p.x), abs(p.y)));
	if (tipo > 0.5 && tipo < 1.5) {
		// Lama: um borrao organico de torroes, sem espinho; a borda come em
		// ondas, e torroes soltos em volta, do lado de baixo (o chao).
		float f = ruido(p * 3.0 + semente) * 0.6 + ruido(p * 7.0 - semente) * 0.3 + ruido(p * 17.0) * 0.1;
		float borda = 0.55 + (f - 0.5) * 0.5;
		float corpo = smoothstep(borda, borda - 0.06, r);
		vec2 q = p * 5.0 + semente;
		vec2 qi = floor(q);
		vec2 qf = fract(q) - 0.5 - (vec2(h(qi + 3.1), h(qi + 7.7)) - 0.5) * 0.4;
		float torrao = step(0.72, h(qi)) * smoothstep(0.3 + 0.15 * h(qi + 1.1), 0.12, length(qf))
			* smoothstep(1.0, 0.6, r) * smoothstep(-0.6, 0.2, p.y);
		m = max(corpo, torrao);
		grosso = corpo * (0.7 + 0.5 * f) + torrao * 0.8;
	} else if (tipo < 1.5) {
		// O corpo do respingo: um borrao de borda irregular, grosso no meio,
		// alongado para onde a gota ia (bateu de raspao, espicha).
		vec2 dd = length(dir) > 0.01 ? normalize(dir) : vec2(0.0);
		float estica = clamp(length(dir) * 0.25, 0.0, 0.45);
		vec2 pe = p - dd * dot(p, dd) * estica;
		r = length(pe);
		ang = atan(pe.y, pe.x);
		float borda = 0.42 + 0.10 * ruido(vec2(ang * 2.6 + semente, 1.7)) + 0.05 * ruido(vec2(ang * 9.0, 4.1));
		float corpo = smoothstep(borda, borda - 0.05, r);
		// Espinhos: raios de alcance desigual, mais longos para onde ele ia.
		vec2 d = length(dir) > 0.01 ? normalize(dir) : vec2(0.0);
		float pra_la = max(dot(p / max(r, 1e-4), d), 0.0);
		float raio_k = pow(ruido(vec2(ang * 6.5 + semente * 3.1, 2.3)), 3.0);
		float alcance = borda + (0.2 + 0.35 * pra_la) * raio_k * 1.6;
		float largura = 0.05 + 0.08 * (1.0 - raio_k);
		float espinho = smoothstep(alcance, alcance - 0.08, r)
			* smoothstep(largura, 0.0, abs(fract(ang * 6.5 / 6.2832 + semente) - 0.5) * r * 0.8)
			* step(0.25, raio_k);
		// Gotas satelite em volta, puxadas para onde ele ia.
		vec2 q = (p - d * 0.25) * 7.0;
		vec2 qi = floor(q);
		vec2 qf = fract(q) - 0.5 - (vec2(h(qi + 3.1), h(qi + 7.7)) - 0.5) * 0.5;
		float sat = step(0.8, h(qi)) * smoothstep(0.22, 0.08, length(qf)) * smoothstep(1.0, 0.55, r);
		m = max(corpo, max(espinho * 0.6, sat));
		// O espinho e filme fino (sem relevo): grosso ele virava fatia de pizza.
		// A cupula so pelo raio: pela borda (que varia com o angulo) ela fazia
		// dobras radiais, uma agua-viva.
		grosso = corpo * (0.5 + 0.65 * smoothstep(0.5, 0.0, r)) + espinho * 0.12 + sat * 0.55;
	} else if (tipo < 2.5) {
		// (a nevoa, abaixo)
		// Nevoa: gotinhas finas espalhadas, mais densas no meio.
		for (int camada = 0; camada < 2; camada++) {
			float esc = camada == 0 ? 26.0 : 11.0;
			vec2 q = p * esc + float(camada) * 17.0;
			vec2 qi = floor(q);
			vec2 qf = fract(q) - 0.5 - (vec2(h(qi + 1.3), h(qi + 5.9)) - 0.5) * 0.6;
			float tem = step((camada == 0 ? 0.55 : 0.8) + 0.3 * r, h(qi));
			float gota = tem * smoothstep(0.18 + 0.2 * h(qi + 2.2), 0.04, length(qf)) * smoothstep(1.0, 0.25, r);
			m = max(m, gota);
			grosso = max(grosso, gota * (camada == 0 ? 0.26 : 0.45));
		}
	} else if (tipo > 3.5) {
		// O rastro do filete: uma capsula mole, mais grossa no meio.
		float cap = length(vec2(p.x, max(abs(p.y) - 0.6, 0.0)));
		m = smoothstep(0.55, 0.25, cap);
		grosso = m * (0.8 + 0.2 * ruido(p * 3.0 + semente));
	} else {
		// Uma gota redonda e grossa, que escorre.
		m = smoothstep(0.9, 0.7, r + (ruido(vec2(ang * 3.0, semente)) - 0.5) * 0.12);
		grosso = m * (0.9 + 0.5 * smoothstep(0.8, 0.0, r));
	}
	m *= beira;
	float t = grosso * forca * beira;
	if (tipo > 0.5 && tipo < 1.5) {
		COLOR = vec4(t * com_sangue, t, m * com_sangue, 1.0);
	} else {
		COLOR = vec4(t, 0.0, m, 1.0);
	}
}
"""

const TELA := """
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D acumulado : filter_linear;
uniform sampler2D tela : hint_screen_texture, filter_linear_mipmap;
uniform vec2 px = vec2(0.00052, 0.00093);
uniform float tempo = 0.0;

float altura(vec2 uv) {
	vec3 s = texture(acumulado, uv).rgb;
	return s.r + s.g * 0.8;
}

float h(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 s = texture(acumulado, uv).rgb;
	float t = s.r;
	float g = s.g;
	if (t + g < 0.004) {
		discard;
	}
	float fresco = clamp(s.b, 0.0, 1.0);
	vec2 e = px * 3.5;
	vec2 grad = vec2(altura(uv + vec2(e.x, 0.0)) - altura(uv - vec2(e.x, 0.0)),
		altura(uv + vec2(0.0, e.y)) - altura(uv - vec2(0.0, e.y)));
	vec3 n = normalize(vec3(-grad * 1.6, 1.0));
	// A lente com sangue: o de tras entorta pela inclinacao e borra onde e grosso.
	float k = clamp(t + g, 0.0, 1.5);
	vec3 fundo = textureLod(tela, uv + n.xy * 0.02 * k, 2.0 * clamp(k, 0.0, 1.0)).rgb;
	float lum = dot(fundo, vec3(0.3, 0.59, 0.11));
	// Sangue: tinge o que esta atras (absorve verde e azul) e tem cor propria,
	// viva quando fresco, vinho quando coagula.
	vec3 absorve = exp(-t * vec3(0.45, 3.4, 4.0) * mix(1.6, 1.0, fresco));
	vec3 cor = fundo * absorve;
	// A cor propria acesa pela cena, com um piso: no escuro da estrada o sangue
	// na lente sumia em preto. Fino, e vermelho translucido; grosso, vinho.
	vec3 propria = mix(vec3(0.12, 0.006, 0.005), vec3(0.42, 0.02, 0.014), fresco);
	propria = mix(propria * 1.6, propria * 0.55, smoothstep(0.25, 1.4, t));
	cor = mix(cor, propria * (0.75 + lum * 1.4), clamp(t * 0.7, 0.0, 0.85));
	// Lama: barro que tampa, com grao.
	float grao = h(floor(uv / px * 0.5));
	vec3 barro = mix(vec3(0.11, 0.08, 0.05), vec3(0.2, 0.15, 0.1), grao) * (0.45 + lum * 1.3);
	barro = mix(barro, barro * vec3(1.2, 0.5, 0.45), clamp(t, 0.0, 1.0) * 0.6);
	cor = mix(cor, barro, 1.0 - exp(-g * 3.5));
	// O brilho de molhado (uma luz de cima a esquerda) e o menisco escuro na borda.
	vec3 l = normalize(vec3(-0.35, 0.55, 0.75));
	vec3 hv = normalize(l + vec3(0.0, 0.0, 1.0));
	float brilho = pow(max(dot(n, hv), 0.0), 70.0) * smoothstep(0.03, 0.25, t + g * 0.3) * (0.35 + 0.65 * fresco);
	cor += vec3(1.0, 0.88, 0.85) * brilho * (0.35 + lum * 1.5);
	cor *= 1.0 - clamp(length(grad) * 5.0, 0.0, 0.45) * smoothstep(0.02, 0.12, t);
	float cobre = smoothstep(0.004, 0.05, t + g);
	COLOR = vec4(mix(texture(tela, uv).rgb, cor, cobre), 1.0);
}
"""

static var _atual: SangueNaLente

var _vp: SubViewport
var _sim: ColorRect
var _mat_sim: ShaderMaterial
var _tela: ColorRect
var _mat_tela: ShaderMaterial
var _pool: Array[ColorRect] = []
var _mostrados: Array[ColorRect] = []
var _tempo := 0.0
var _filetes: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


## O sangue na lente desta cena: acha o que ja existe ou cria.
## Um so por cena, mesmo que perguntem de outro no: o cuspe (da cabeca) e o
## impacto (da cena) somam no mesmo acumulador.
static func de(cena: Node) -> SangueNaLente:
	if _atual != null and is_instance_valid(_atual) and _atual.is_inside_tree():
		return _atual
	var s := SangueNaLente.new()
	cena.add_child(s)
	_atual = s
	return s


func _ready() -> void:
	name = "SangueNaLente"
	layer = CAMADA
	_rng.seed = 1789
	var tam := get_viewport().get_visible_rect().size
	var aspecto := tam.x / maxf(tam.y, 1.0)
	_vp = SubViewport.new()
	_vp.name = "Acumulador"
	_vp.size = Vector2i(int(ALTURA * aspecto), ALTURA)
	_vp.transparent_bg = true
	_vp.use_hdr_2d = true
	_vp.disable_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	add_child(_vp)
	_mat_sim = ShaderMaterial.new()
	_mat_sim.shader = _shader(SIMULA)
	_mat_sim.set_shader_parameter(&"px", Vector2(1.0 / _vp.size.x, 1.0 / _vp.size.y))
	_mat_sim.set_shader_parameter(&"escorre", ESCORRE)
	_mat_sim.set_shader_parameter(&"escorre_de", ESCORRE_DE)
	_mat_sim.set_shader_parameter(&"coagula", COAGULA)
	_sim = ColorRect.new()
	_sim.name = "Simula"
	_sim.size = Vector2(_vp.size)
	_sim.material = _mat_sim
	_vp.add_child(_sim)
	var mat_resp := _shader(RESPINGO)
	for i in POR_QUADRO:
		var r := ColorRect.new()
		r.name = "Respingo%d" % i
		r.visible = false
		var m := ShaderMaterial.new()
		m.shader = mat_resp
		r.material = m
		_vp.add_child(r)
		_pool.append(r)
	_mat_tela = ShaderMaterial.new()
	_mat_tela.shader = _shader(TELA)
	_mat_tela.set_shader_parameter(&"acumulado", _vp.get_texture())
	_mat_tela.set_shader_parameter(&"px", Vector2(1.0 / _vp.size.x, 1.0 / _vp.size.y))
	_tela = ColorRect.new()
	_tela.name = "Tela"
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Tamanho explicito: FULL_RECT sob CanvasLayer mede 0x0.
	_tela.size = tam
	_tela.material = _mat_tela
	add_child(_tela)
	# Depois do primeiro quadro limpo, nunca mais limpa: o estado e o quadro.
	await RenderingServer.frame_post_draw
	if is_instance_valid(_vp):
		_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	# Um respingo nulo: o shader dele compila agora, e nao no primeiro cuspe.
	_mostrar(Vector2(0.5, 0.5), 0.01, 0.0, Vector2.ZERO, 0.0)


static func _shader(codigo: String) -> Shader:
	var s := Shader.new()
	s.code = codigo
	return s


## Um respingo de sangue em `uv` (0..1 da tela, y para baixo), `raio` em fracao
## da altura da tela, `forca` a espessura no meio (1 escorre), `dir` para onde o
## sangue ia na tela (os espinhos e as satelites vao para la).
func respingo(uv: Vector2, raio: float, forca: float = 1.0, dir: Vector2 = Vector2.ZERO) -> void:
	_mostrar(uv, raio, forca, dir, 0.0)
	# O respingo grosso solta filetes do pe dele.
	if forca > 0.7 and raio > 0.02:
		var n := 1 + int(_rng.randf() < 0.5) + int(forca > 1.3)
		for i in n:
			_filete(uv + Vector2(_rng.randf_range(-0.5, 0.5) * raio / _aspecto(), raio * 0.55),
				forca * _rng.randf_range(0.7, 1.1))


## Nevoa de gotinhas em volta de `uv` (o cuspe fino): `n` so muda a densidade.
func nevoa(uv: Vector2, raio: float, n: int = 40) -> void:
	_mostrar(uv, raio, clampf(float(n) / 40.0, 0.2, 3.0), Vector2.ZERO, 2.0)


## Uma gota redonda e grossa, que escorre.
func gota(uv: Vector2, raio: float, forca: float = 1.2) -> void:
	_mostrar(uv, raio, forca, Vector2.ZERO, 3.0)
	_filete(uv + Vector2(0.0, raio * 0.5), forca)


func _aspecto() -> float:
	return float(_vp.size.x) / float(_vp.size.y) if _vp != null else 1.7778


## Um filete escorrendo de `uv` (0..1 da tela, y para baixo).
func _filete(uv: Vector2, forca: float) -> void:
	if _filetes.size() >= FILETES_MAX:
		return
	_filetes.append({"p": uv, "v": _rng.randf_range(FILETE_VEL.x, FILETE_VEL.y) * clampf(forca, 0.5, 1.5),
		"l": _rng.randf_range(FILETE_LARGURA.x, FILETE_LARGURA.y) * clampf(forca, 0.7, 1.3),
		"fase": _rng.randf_range(0.0, TAU), "ate": _rng.randf_range(0.18, 0.55)})


## Lama do chao (o impacto), com `com_sangue` (0..1) de sangue misturado.
func lama(uv: Vector2, raio: float, com_sangue: float = 0.3) -> void:
	_mostrar(uv, raio, 1.0, Vector2(0.0, -1.0), 1.0, com_sangue)


## Limpa tudo (bancada, ou uma cena nova).
func limpar() -> void:
	if _vp != null:
		_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
		await RenderingServer.frame_post_draw
		if is_instance_valid(_vp):
			_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER


func _mostrar(uv: Vector2, raio: float, forca: float, dir: Vector2, tipo: float,
		com_sangue: float = 0.0) -> void:
	if _pool.is_empty() or _vp == null:
		return
	var r: ColorRect = _pool.pop_back()
	var lado := raio * float(_vp.size.y) * 2.0 * FOLGA
	r.size = Vector2(lado, lado)
	r.position = Vector2(uv.x * _vp.size.x, uv.y * _vp.size.y) - r.size * 0.5
	var m := r.material as ShaderMaterial
	m.set_shader_parameter(&"tipo", tipo)
	m.set_shader_parameter(&"forca", forca)
	m.set_shader_parameter(&"semente", _rng.randf_range(0.0, 100.0))
	m.set_shader_parameter(&"dir", dir)
	m.set_shader_parameter(&"com_sangue", com_sangue)
	r.visible = true
	r.set_meta(&"quadro", Engine.get_process_frames())
	_mostrados.append(r)


func _process(delta: float) -> void:
	# Cada respingo soma um quadro so: o que apareceu num quadro que ja foi
	# desenhado sai (quem chamou antes ou depois deste _process tanto faz).
	var agora := Engine.get_process_frames()
	var ja: Array[ColorRect] = []
	for r: ColorRect in _mostrados:
		if int(r.get_meta(&"quadro", agora)) < agora:
			r.visible = false
			_pool.append(r)
		else:
			ja.append(r)
	_mostrados = ja
	_tempo += delta
	# Os filetes: descem freando e serpenteando, e deixam rastro; parados, uma
	# gota na ponta.
	var fim: Array[Dictionary] = []
	for f: Dictionary in _filetes:
		var v: float = f["v"]
		var dy := v * delta
		var pu: Vector2 = f["p"]
		var l: float = f["l"]
		pu.y += dy
		pu.x += sin(_tempo * 2.3 + float(f["fase"])) * dy * 0.25 / _aspecto()
		f["p"] = pu
		f["ate"] = float(f["ate"]) - dy
		v *= exp(-FILETE_FREIA * delta)
		f["v"] = v
		if dy > 0.0:
			_mostrar(pu, maxf(l, dy * 0.6), FILETE_RASTRO, Vector2.ZERO, 4.0)
		if v < 0.012 or float(f["ate"]) <= 0.0 or pu.y > 1.05:
			_mostrar(pu, l * 1.8, 1.0, Vector2.ZERO, 3.0)
			fim.append(f)
	for f: Dictionary in fim:
		_filetes.erase(f)
	if _mat_sim != null:
		_mat_sim.set_shader_parameter(&"dt", clampf(delta, 0.0, 1.0 / 20.0))
		_mat_sim.set_shader_parameter(&"tempo", _tempo)
