## O volante esportivo da cabine: aro de camurca preta com a faixa amarela no
## alto, tres raios de aluminio escovado grafite com fenda, prato fundo e a
## buzina preta no cubo parafusado.
##
## Por que existe
## --------------
## O volante era um aro de dez caixas e tres ripas, feito para 480x270. Em 4K
## ele e o objeto mais perto da lente na cena inteira depois das maos, e as
## quinas das dez caixas e o cubo de caixa liam como volante de brinquedo.
##
## Medidas
## -------
## Tudo em volta do centro do aro, no espaco do pivo da `CarroCabine`: x para a
## direita, y para cima e +z para o motorista. O aro e um toro de secao redonda
## (a mao fecha nele pela `MotoristaCena._no_aro`, que conta com o circulo). O
## cubo fica `PRATO` metros atras do plano do aro: e o prato fundo desse tipo de
## volante, e os raios descem do aro ate ele.
##
## Os materiais sao proprios (camurca, metal escovado, plastico da buzina), em
## shader por pixel: o painel de atlas nao tem como dar brilho de metal nem a
## fibra da camurca, e e isso que diz o que cada peca e.
class_name VolanteEsportivo
extends RefCounted

## Raio da secao do aro. Trinta e um milimetros de grossura, que e o aro de
## volante esportivo; a pegada da mao e este raio mais a folga da pele.
const TUBO := 0.0155
## Quanto o cubo fica atras do plano do aro.
const PRATO := 0.052
## Os raios, em graus (0 e as tres horas, 90 o alto). Os dois de lado descem
## um pouco abaixo da horizontal, como no volante de competicao: o polegar da
## mao nas "nove e quinze" apoia em cima deles sem cobrir o raio.
const RAIOS_GRAUS := [192.0, 348.0, 270.0]
## Espessura da chapa dos raios e a meia largura dela no cubo e no aro.
const RAIO_CHAPA := 0.0045
const RAIO_LARGO_CUBO := 0.025
const RAIO_LARGO_ARO := 0.017
## Onde a chapa nasce no cubo (raio em volta do eixo).
const RAIO_NASCE := 0.036
## A fenda de cada raio: meio do comprimento dela, contado do cubo, meia
## extensao e meia largura (m). O raio de baixo tem a fenda mais longa.
const FENDAS := [Vector3(0.072, 0.034, 0.0058), Vector3(0.072, 0.034, 0.0058),
	Vector3(0.078, 0.044, 0.0058)]
## Cubo: o disco de metal onde os raios chegam, a buzina e os seis parafusos.
const CUBO_RAIO := 0.052
const BUZINA_RAIO := 0.036
const BUZINA_ALTURA := 0.014
const PARAFUSO_ORBITA := 0.0445
const PARAFUSO_RAIO := 0.0042

## Voltas do aro e da secao. Noventa e seis em volta: a um palmo da lente, em
## 4K, com menos o contorno do aro ja mostra a quina entre dois trechos.
const VOLTAS := 96
const LADOS := 18
const LADOS_TORNO := 48

## A faixa amarela no alto do aro: duas tiras de couro amarelo separadas por
## um vao preto. Largura de cada tira e meio vao, em graus.
const FAIXA_GRAUS := 5.4
const FAIXA_VAO_GRAUS := 3.6

const CAMURCA_SHADER := """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 cor_couro : source_color = vec3(0.045, 0.045, 0.048);
// Mais escuro que o amarelo "de catalogo": na luz quente da cabine o claro
// estourava e lia creme.
uniform vec3 cor_faixa : source_color = vec3(0.82, 0.52, 0.0);
uniform vec3 cor_linha : source_color = vec3(0.07, 0.07, 0.075);
// Largura de cada tira amarela e meio vao entre elas, em fracao da volta.
uniform float faixa = 0.015;
uniform float vao = 0.01;
// Raio do aro e da secao (m), para medir a costura em metros.
uniform float raio_aro = 0.185;
uniform float raio_tubo = 0.0155;
// A luz de preenchimento que o painel inteiro tem (ver mat_painel).
uniform vec3 preenche = vec3(0.18, 0.16, 0.14);

varying vec3 p_obj;

void vertex() {
	p_obj = VERTEX;
}

float h13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float ruido(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h13(i), h13(i + vec3(1, 0, 0)), f.x),
			mix(h13(i + vec3(0, 1, 0)), h13(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h13(i + vec3(0, 0, 1)), h13(i + vec3(1, 0, 1)), f.x),
			mix(h13(i + vec3(0, 1, 1)), h13(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void fragment() {
	// UV.x: volta do aro (0 as tres horas, 0,25 o alto); UV.y: volta da secao
	// (0 por fora, 0,25 para o motorista, 0,5 por dentro, virado para o cubo).
	float du = abs(UV.x - 0.25);
	float w = max(fwidth(UV.x), 1e-5);
	float tira = smoothstep(vao - w, vao + w, du)
		* (1.0 - smoothstep(vao + faixa - w, vao + faixa + w, du));
	vec3 base = mix(cor_couro, cor_faixa, tira);
	float px = length(fwidth(p_obj));
	// Camurca: pelo curto e desencontrado. Some antes de cintilar.
	float fino = clamp(1.0 - px * 1400.0, 0.0, 1.0);
	float pelo = ruido(p_obj * 2600.0) * 0.6 + ruido(p_obj * 6100.0 + 3.7) * 0.4;
	float h = (pelo - 0.5) * fino;
	base *= 1.0 + (pelo - 0.5) * 0.5 * fino;
	// O pelo deitado pelas maos: manchas largas mais claras e mais lisas.
	float gasto = smoothstep(0.45, 0.85, ruido(p_obj * 55.0));
	base *= 1.0 + gasto * 0.35;
	// A costura corre na face de dentro do aro: um sulco e os pontos em V dos
	// dois lados, de 4,5 em 4,5 mm.
	float s = UV.x * TAU * raio_aro;
	float y = (UV.y - 0.5) * TAU * raio_tubo;
	float ay = abs(y);
	float sulco = 1.0 - smoothstep(0.0003, 0.0008, ay);
	float passo = 0.0045;
	float d_ponto = abs(fract((s + ay * 0.9) / passo) - 0.5) * passo;
	float ponto = (1.0 - smoothstep(0.00045, 0.00075, d_ponto))
		* smoothstep(0.0008, 0.0011, ay) * (1.0 - smoothstep(0.0029, 0.0033, ay));
	float nitido = clamp(1.0 - px * 600.0, 0.0, 1.0);
	ponto *= nitido;
	sulco *= nitido;
	base = mix(base, base * 0.45, sulco);
	base = mix(base, cor_linha, ponto);
	h += ponto * 1.4 - sulco * 1.6;
	ROUGHNESS = mix(mix(0.93, 0.8, gasto), 0.55, tira) - ponto * 0.25;
	SPECULAR = 0.32;
	// O brilho de raspao do pelo, que e o que le camurca de longe. A faixa e
	// couro liso: com o mesmo brilho o amarelo lavava para creme na cabine.
	RIM = mix(0.55, 0.1, tira);
	RIM_TINT = 0.35;
	float alt = h * 0.00012;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 n = NORMAL;
	vec3 r1 = cross(dpdy, n);
	vec3 r2 = cross(n, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(alt) * r1 + dFdy(alt) * r2);
	NORMAL = normalize(abs(det) * n - grad);
	ALBEDO = base;
	EMISSION = base * preenche;
}
"""

const METAL_SHADER := """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Aluminio anodizado grafite, escovado. A cor de vertice multiplica (o
// parafuso e mais escuro) e o alfa dela diz quanto e escovado: 0 e polido.
uniform vec3 cor : source_color = vec3(0.42, 0.43, 0.45);
uniform vec3 preenche = vec3(0.18, 0.16, 0.14);

float h13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float ruido(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h13(i), h13(i + vec3(1, 0, 0)), f.x),
			mix(h13(i + vec3(0, 1, 0)), h13(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h13(i + vec3(0, 0, 1)), h13(i + vec3(1, 0, 1)), f.x),
			mix(h13(i + vec3(0, 1, 1)), h13(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void fragment() {
	// A fenda do raio: UV em metros na chapa (x do cubo para o aro, y de lado);
	// UV2 = (meio da fenda, meia extensao). A meia largura e a de
	// `VolanteEsportivo.FENDAS`. Fora da chapa UV2.x e negativo.
	if (UV2.x > 0.0) {
		float rr = UV2.y;
		vec2 p = vec2(abs(UV.x - UV2.x) - rr, abs(UV.y));
		float meia = 0.0058;
		float d = length(vec2(max(p.x + meia, 0.0), p.y)) - meia;
		if (p.x + meia < 0.0) {
			d = p.y - meia;
		}
		if (d < 0.0) {
			discard;
		}
	}
	// Escovado: riscos que correm no sentido de UV.x e variam depressa de lado.
	float px = length(fwidth(UV));
	float fino = clamp(1.0 - px * 2500.0, 0.0, 1.0);
	float risco = ruido(vec3(UV.y * 5200.0, UV.x * 40.0, 0.0)) * 0.7
		+ ruido(vec3(UV.y * 13000.0, UV.x * 90.0, 5.0)) * 0.3;
	float esc = COLOR.a;
	vec3 base = cor * COLOR.rgb * (1.0 + (risco - 0.5) * 0.18 * fino * esc);
	ALBEDO = base;
	// Anodizado: a camada de oxido espalha um pouco de luz como tinta. Metal
	// puro so refletia a cabine escura e o raio sumia de preto no quadro.
	METALLIC = 0.6;
	ROUGHNESS = mix(0.07, 0.24 + (risco - 0.5) * 0.14 * fino, esc);
	SPECULAR = 0.5;
	EMISSION = base * preenche * 0.35;
}
"""

static var _camurca: ShaderMaterial
static var _metal: ShaderMaterial
static var _plastico: StandardMaterial3D


## Monta o volante inteiro dentro de `pai`, em volta da origem dele. `raio` e o
## raio do eixo do aro.
static func montar(pai: Node3D, raio: float) -> void:
	var aro := _malha()
	_aro(aro, raio)
	_poe(pai, "Aro", aro, camurca(raio))

	var metal := _malha()
	for k in RAIOS_GRAUS.size():
		_raio(metal, raio, deg_to_rad(RAIOS_GRAUS[k]), FENDAS[k])
	_cubo(metal)
	_poe(pai, "Raios", metal, metal_escovado())

	var buzina := _malha()
	_buzina(buzina)
	_poe(pai, "Buzina", buzina, plastico())


static func camurca(raio: float = 0.185) -> ShaderMaterial:
	if _camurca == null:
		var sh := Shader.new()
		sh.code = CAMURCA_SHADER
		_camurca = ShaderMaterial.new()
		_camurca.shader = sh
		_camurca.set_shader_parameter(&"faixa", FAIXA_GRAUS / 360.0)
		_camurca.set_shader_parameter(&"vao", FAIXA_VAO_GRAUS / 360.0)
		_camurca.set_shader_parameter(&"raio_tubo", TUBO)
	_camurca.set_shader_parameter(&"raio_aro", raio)
	return _camurca


static func metal_escovado() -> ShaderMaterial:
	if _metal == null:
		var sh := Shader.new()
		sh.code = METAL_SHADER
		_metal = ShaderMaterial.new()
		_metal.shader = sh
	return _metal


## O plastico da buzina e o emblema: cor de vertice, verniz fino.
static func plastico() -> StandardMaterial3D:
	if _plastico == null:
		_plastico = StandardMaterial3D.new()
		_plastico.vertex_color_use_as_albedo = true
		_plastico.vertex_color_is_srgb = true
		_plastico.roughness = 0.42
		_plastico.clearcoat_enabled = true
		_plastico.clearcoat = 0.4
		_plastico.clearcoat_roughness = 0.2
		_plastico.emission_enabled = true
		_plastico.emission = Color(0.03, 0.027, 0.024)
	return _plastico


# --- pecas ------------------------------------------------------------------

## O aro: toro de secao redonda. UV.x e a volta do aro e UV.y a da secao, que o
## shader usa para a faixa e para a costura.
static func _aro(m: Malha, raio: float) -> void:
	var z := Vector3(0.0, 0.0, 1.0)
	var linhas: Array = []
	for i in VOLTAS + 1:
		var th := TAU * float(i) / float(VOLTAS)
		var fora := Vector3(cos(th), sin(th), 0.0)
		var linha := PackedInt32Array()
		for j in LADOS + 1:
			var ps := TAU * float(j) / float(LADOS)
			var n := fora * cos(ps) + z * sin(ps)
			linha.append(_vertice(m, fora * raio + n * TUBO, n,
				Vector2(float(i) / float(VOLTAS), float(j) / float(LADOS)),
				Vector2(-1.0, 0.0), Color.WHITE))
		linhas.append(linha)
	_grade(m, linhas)


## Um raio: chapa reta do cubo (atras, no prato) ate a parte de tras do aro,
## com a fenda recortada pelo shader e a parede dela em malha.
static func _raio(m: Malha, raio: float, ang: float, fenda: Vector3) -> void:
	var dir := Vector3(cos(ang), sin(ang), 0.0)
	var lado := Vector3(-sin(ang), cos(ang), 0.0)
	var ini := dir * RAIO_NASCE + Vector3(0.0, 0.0, -PRATO)
	# Entra na metade de tras do tubo do aro, meio centimetro para dentro.
	var fim := dir * (raio - 0.005) + Vector3(0.0, 0.0, -0.007)
	var ao_longo := fim - ini
	var comp := ao_longo.length()
	ao_longo /= comp
	var normal := lado.cross(ao_longo).normalized()
	if normal.z < 0.0:
		normal = -normal
	var meia := RAIO_CHAPA * 0.5
	var passos := 12
	var cor := Color(1.0, 1.0, 1.0, 1.0)
	var uv2 := Vector2(fenda.x, fenda.y)
	for face: float in [1.0, -1.0]:
		var linhas: Array = []
		for k in passos + 1:
			var a := comp * float(k) / float(passos)
			var hw := lerpf(RAIO_LARGO_CUBO, RAIO_LARGO_ARO, a / comp)
			var c := ini + ao_longo * a + normal * meia * face
			var linha := PackedInt32Array()
			for b: float in [-hw, 0.0, hw]:
				linha.append(_vertice(m, c + lado * b, normal * face, Vector2(a, b),
					uv2, cor))
			linhas.append(linha)
		_grade(m, linhas, normal * face)
	# As bordas compridas da chapa.
	for s: float in [-1.0, 1.0]:
		var linhas: Array = []
		var borda := (lado * s * (RAIO_LARGO_ARO - RAIO_LARGO_CUBO) / comp
			+ ao_longo).normalized()
		var n_borda := normal.cross(borda).normalized()
		if n_borda.dot(lado * s) < 0.0:
			n_borda = -n_borda
		for k in passos + 1:
			var a := comp * float(k) / float(passos)
			var hw := lerpf(RAIO_LARGO_CUBO, RAIO_LARGO_ARO, a / comp)
			var p := ini + ao_longo * a + lado * hw * s
			var linha := PackedInt32Array()
			for f: float in [1.0, -1.0]:
				linha.append(_vertice(m, p + normal * meia * f, n_borda,
					Vector2(a, hw * s + f * meia), Vector2(-1.0, 0.0), cor))
			linhas.append(linha)
		_grade(m, linhas, n_borda)
	# A parede da fenda: um estadio atravessando a chapa, com a normal para o
	# vazio de dentro.
	var rr := fenda.z
	var reta := fenda.y - rr
	var volta: Array[Vector2] = []
	var n_volta: Array[Vector2] = []
	var pontos_meia := 10
	for lado_f: float in [1.0, -1.0]:
		var centro := Vector2(fenda.x + reta * lado_f, 0.0)
		for i in pontos_meia + 1:
			var t := -PI * 0.5 + PI * float(i) / float(pontos_meia)
			var d := Vector2(cos(t), sin(t)) * lado_f
			volta.append(centro + d * rr)
			n_volta.append(-d)
	volta.append(volta[0])
	n_volta.append(n_volta[0])
	var linhas: Array = []
	for i in volta.size():
		var q: Vector2 = volta[i]
		var p := ini + ao_longo * q.x + lado * q.y
		var nv: Vector2 = n_volta[i]
		var n3 := (ao_longo * nv.x + lado * nv.y).normalized()
		var linha := PackedInt32Array()
		for f: float in [1.0, -1.0]:
			linha.append(_vertice(m, p + normal * meia * f, n3,
				Vector2(float(i) * 0.002, f * meia), Vector2(-1.0, 0.0), cor))
		linhas.append(linha)
	_grade(m, linhas)


## O cubo: disco onde os raios chegam, o adaptador da coluna atras e os seis
## parafusos na frente, virados para o motorista.
static func _cubo(m: Malha) -> void:
	var z0 := -PRATO
	var meia := RAIO_CHAPA * 0.5
	var frente := _frente_do_cubo()
	var r := CUBO_RAIO
	# Disco por CIMA da raiz dos raios: eles saem de baixo da borda dele. Com o
	# disco no plano da chapa as duas faces brigavam pelo mesmo pixel.
	_torno(m, Vector3(0.0, 0.0, 0.0), [
		Vector2(0.0, frente), Vector2(r - 0.0025, frente),
		Vector2(r - 0.0007, frente - 0.0007), Vector2(r, frente - 0.0025),
		Vector2(r, z0 - meia + 0.0005), Vector2(r - 0.0015, z0 - meia - 0.001),
		Vector2(0.03, z0 - meia - 0.001), Vector2(0.03, z0 - 0.034),
		Vector2(0.0, z0 - 0.034)], Color(1, 1, 1, 1))
	# Os parafusos Allen, pretos, com o sextavado fundo.
	for k in 6:
		var a := deg_to_rad(30.0 + 60.0 * float(k))
		var c := Vector3(cos(a), sin(a), 0.0) * PARAFUSO_ORBITA
		var pr := PARAFUSO_RAIO
		var topo := frente + 0.0028
		_torno(m, c, [
			Vector2(0.0, topo - 0.0012), Vector2(pr * 0.5, topo - 0.0012),
			Vector2(pr * 0.52, topo), Vector2(pr * 0.86, topo),
			Vector2(pr, topo - 0.0006), Vector2(pr, frente - 0.0005)],
			Color(0.28, 0.28, 0.3, 0.4), 16)
	# O aro fino do emblema, polido, em cima da buzina.
	var t := frente + BUZINA_ALTURA
	_torno(m, Vector3.ZERO, [
		Vector2(0.0158, t - 0.0004), Vector2(0.0165, t + 0.0006),
		Vector2(0.0185, t + 0.0006), Vector2(0.0192, t - 0.0006)],
		Color(1.0, 1.0, 1.0, 0.0))


## A face do disco do cubo, onde assentam a buzina e os parafusos.
static func _frente_do_cubo() -> float:
	return -PRATO + 0.008


## A buzina: botao preto de borda redonda e o miolo amarelo do emblema.
static func _buzina(m: Malha) -> void:
	var z0 := _frente_do_cubo()
	var r := BUZINA_RAIO
	var h := BUZINA_ALTURA
	var perfil: Array = [Vector2(0.0, z0 + h)]
	# Topo levemente abaulado, e a borda em quarto de circulo de 5 mm.
	for i in 6:
		var t := float(i) / 5.0
		perfil.append(Vector2(lerpf(0.004, r - 0.005, t),
			z0 + h - 0.0012 * t * t))
	for i in range(1, 7):
		var t := PI * 0.5 * float(i) / 6.0
		perfil.append(Vector2(r - 0.005 + sin(t) * 0.005,
			z0 + h - 0.0012 - 0.005 + cos(t) * 0.005))
	perfil.append(Vector2(r, z0 - 0.001))
	_torno(m, Vector3.ZERO, perfil, Color(0.05, 0.05, 0.055))
	# O miolo amarelo do emblema, em relevo (o aro polido dele e de metal, em
	# `_cubo`).
	var topo := z0 + h
	_torno(m, Vector3.ZERO, [
		Vector2(0.0, topo + 0.0008), Vector2(0.0072, topo + 0.0008),
		Vector2(0.0078, topo), Vector2(0.0078, topo - 0.0005)],
		Color(0.95, 0.7, 0.05))


# --- malha ------------------------------------------------------------------

## Os arrays da malha em construcao. Numa classe, e nao num Dictionary: o
## Packed*Array dentro de dicionario e copiado a cada leitura, e o `append`
## caia na copia.
class Malha:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var c := PackedColorArray()
	var i := PackedInt32Array()


static func _malha() -> Malha:
	return Malha.new()


static func _vertice(m: Malha, p: Vector3, n: Vector3, uv: Vector2,
		uv2: Vector2, c: Color) -> int:
	m.v.append(p)
	m.n.append(n)
	m.uv.append(uv)
	m.uv2.append(uv2)
	m.c.append(c)
	return m.v.size() - 1


## Costura linhas de indices em quads. A face aparece do lado OPOSTO ao
## produto vetorial (a regra do projeto, ver `MaoModelada._tubo`): cada
## triangulo e virado para que o produto aponte contra a normal dos vertices.
static func _grade(m: Malha, linhas: Array, _dica := Vector3.ZERO) -> void:
	for k in linhas.size() - 1:
		var l0: PackedInt32Array = linhas[k]
		var l1: PackedInt32Array = linhas[k + 1]
		for j in l0.size() - 1:
			_tri(m, l0[j], l1[j], l0[j + 1])
			_tri(m, l0[j + 1], l1[j], l1[j + 1])


static func _tri(m: Malha, a: int, b: int, c: int) -> void:
	var fn := (m.v[b] - m.v[a]).cross(m.v[c] - m.v[a])
	if fn.length_squared() < 1e-16:
		return
	if fn.dot(m.n[a] + m.n[b] + m.n[c]) > 0.0:
		m.i.append_array([a, c, b])
	else:
		m.i.append_array([a, b, c])


## Superficie de revolucao em volta do eixo z que passa por `centro`. O perfil
## (raio, z) e percorrido de cima (o eixo, na face do motorista) para fora e
## para tras; a normal e a media das duas arestas vizinhas. Cor com alfa: o
## quanto o metal e escovado (so o shader de metal le).
static func _torno(m: Malha, centro: Vector3, perfil: Array, cor: Color,
		lados: int = LADOS_TORNO) -> void:
	var nperf := perfil.size()
	var normais: Array[Vector2] = []
	for k in nperf:
		var a: Vector2 = perfil[maxi(k - 1, 0)]
		var b: Vector2 = perfil[mini(k + 1, nperf - 1)]
		var t := b - a
		normais.append(Vector2(-t.y, t.x).normalized())
	var linhas: Array = []
	for i in lados + 1:
		var fi := TAU * float(i) / float(lados)
		var c := cos(fi)
		var s := sin(fi)
		var linha := PackedInt32Array()
		for k in nperf:
			var p: Vector2 = perfil[k]
			var nn: Vector2 = normais[k]
			var n3 := Vector3(nn.x * c, nn.x * s, nn.y).normalized()
			if p.x < 1e-5:
				n3 = Vector3(0.0, 0.0, signf(nn.y) if absf(nn.y) > 1e-4 else 1.0)
			linha.append(_vertice(m, centro + Vector3(p.x * c, p.x * s, p.y), n3,
				Vector2(fi * maxf(p.x, 0.001), p.x), Vector2(-1.0, 0.0), cor))
		linhas.append(linha)
	# O torno fecha em volta: cada fatia costura com a seguinte.
	_grade(m, linhas)


static func _poe(pai: Node3D, nome: String, m: Malha, mat: Material) -> void:
	if m.i.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = m.v
	arrays[Mesh.ARRAY_NORMAL] = m.n
	arrays[Mesh.ARRAY_TEX_UV] = m.uv
	arrays[Mesh.ARRAY_TEX_UV2] = m.uv2
	arrays[Mesh.ARRAY_COLOR] = m.c
	arrays[Mesh.ARRAY_INDEX] = m.i
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = nome
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(mi)
