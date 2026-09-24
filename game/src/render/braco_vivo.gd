## Um braco de primeira pessoa inteiro — mao, antebraco e braco ate o ombro —
## refeito a cada quadro a partir de onde a mao esta e de onde o ombro esta.
##
## Por que existe
## --------------
## As maos do susto eram malhas paradas empurradas por tween: a garra sobre o
## banco, a mao na borda do assento. Chegavam em linha reta, sem arco, com os
## dedos na mesma pose do comeco ao fim, e a peca de cima (o braco ate o ombro)
## era montada para UM lugar — no meio do caminho o cotovelo nao dobrava, o
## braco atravessava o proprio antebraco, e no chao a garra virou uma luva
## parada na frente da lente. E o material era o do `Corpo`, feito para gente de
## caixa a dez metros: luz por vertice e uma emissao cinza que acendia a mao no
## escuro como massa de modelar.
##
## Como funciona
## -------------
## A mao e uma `MaoPosada`: um referencial de palma (a "pegada": onde a palma
## esta, para onde os dedos apontam, para onde o dorso olha) e uma pose de dedos
## — espalmada no assento, esticada indo buscar, em pinca no aparelho, com o
## polegar no vidro na leitura. A primeira versao era a `MaoModelada` fechando
## num tubo, e toda mao virava punho num cabo: o celular era segurado como um
## bastao e a mao no chao, uma luva. A pegada se mexe (`ir`), e o braco segue: o
## cotovelo e resolvido de
## novo entre o punho de verdade (o que a mao montou) e o ombro, e o braco de
## cima nasce exatamente onde o antebraco acabou — nunca ha fresta no cotovelo.
## Entre duas pegadas a mao faz arco e abre os dedos no meio do caminho, que e
## o que uma mao faz quando vai pegar alguma coisa.
##
## O material e proprio (`material`): pele por pixel com espalhamento
## subsuperficial, a cor de vertice lida como sRGB (lida como linear, a pele
## da ficha saia quase branca), e pano fosco na manga.
class_name BracoVivo
extends MeshInstance3D

const PELE_SHADER := """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform vec2 uv_pele = vec2(0.0);
uniform float espalha = 0.6;
// Altura do relevo fino (m por unidade do ruido): poro, ruga e veia.
uniform float relevo = 0.00014;
uniform float veias = 1.0;
// O aparelho na mao (ver `BracoVivo.encostar_no_fone`): a caixa dele, do mundo
// para o espaco dele. A pele perto dele escurece — a sombra de contato que a
// luz do jogo nao faz entre duas pecas que se tocam —, e a polpa que olha para
// a tela acesa, de perto, pega a luz dela.
uniform mat4 fone_inv = mat4(1.0);
uniform vec3 fone_meia = vec3(0.0293, 0.0576, 0.00465);
uniform float fone_canto = 0.0088;
uniform vec2 tela_meia = vec2(0.0247, 0.03705);
uniform float contato = 0.0;
uniform vec3 tela_luz = vec3(0.0);

// A pele presa na malha (ver `MaoModelada._tubo`): volta em UV2.x, metros ao
// longo em UV2.y, raio local no alfa da cor. Dai um ponto 3D sem costura.
varying vec3 pele3;
varying float dorso;
varying float raio;
// A unha (ver `MaoModelada._unha`): UV2.x a partir de 2 e a fracao da largura
// dela, UV2.y a do comprimento (0 na cuticula, 1 na borda livre).
varying float unha;
varying vec2 unha_st;

void vertex() {
	float phi = UV2.x * TAU;
	raio = COLOR.a * 0.07;
	pele3 = vec3(cos(phi) * raio, sin(phi) * raio, UV2.y);
	dorso = sin(phi);
	unha = step(1.5, UV2.x);
	unha_st = vec2(UV2.x - 2.0, UV2.y);
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

float caixa(vec3 p) {
	vec2 q = abs(p.xy) - (fone_meia.xy - fone_canto);
	float d2 = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - fone_canto;
	float wz = abs(p.z) - fone_meia.z;
	return length(max(vec2(d2, wz), 0.0)) + min(max(d2, wz), 0.0);
}

float fbm3(vec3 p) {
	return ruido(p) * 0.55 + ruido(p * 2.03 + 3.1) * 0.3 + ruido(p * 4.1 - 1.7) * 0.15;
}

vec3 para_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

void fragment() {
	vec3 texel = texture(atlas, UV).rgb;
	// A cor de vertice e a pele da ficha, escrita em sRGB.
	vec3 base = texel * para_linear(COLOR.rgb);
	bool pele = distance(UV, uv_pele) < 0.004;
	vec3 n = NORMAL;
	float h = 0.0;
	// Metros de pele por pixel: o detalhe menor que isso some, e nao cintila.
	float px = length(fwidth(pele3));
	if (unha > 0.5) {
		// A placa e translucida: o leito rosado aparece por baixo, a lunula
		// esbranquicada perto da cuticula e a borda livre, que ja nao tem carne
		// embaixo, sai clara e amarelada.
		float s = unha_st.x;
		float t = unha_st.y;
		// Tons medidos contra a pele da ficha: a cor de vertice e a pele do
		// dedo, e o leito e ela com o mesmo aquecimento da pele, puxada para o
		// rosa e so um pouco mais clara. Partindo do tom claro de antes, e sem
		// o aquecimento, a unha saia porcelana lilas na luz da tela do celular.
		float lum = dot(base, vec3(0.3, 0.59, 0.11));
		base = mix(vec3(lum), base, 1.3) * vec3(1.04, 0.96, 0.93);
		vec3 leito = base * vec3(1.12, 0.9, 0.9);
		vec3 placa = mix(leito, vec3(lum) * vec3(1.04, 0.96, 0.94), 0.12);
		float lunula = 1.0 - smoothstep(0.7, 1.0, length(vec2((s - 0.5) / 0.3, t / 0.22)));
		placa = mix(placa, vec3(lum) * vec3(1.06, 1.0, 0.98) * 1.12, lunula * 0.3);
		float recorte = (ruido(vec3(s * 26.0, 3.0, 1.0)) - 0.5) * 0.04;
		float livre = smoothstep(0.9, 0.95, t + recorte);
		placa = mix(placa, vec3(lum) * vec3(1.08, 1.02, 0.9) * 1.15, livre * 0.5);
		// O sulco de cada lado e a cuticula escurecem: a pele dobra por cima, e
		// e esse contorno que desenha a unha no dedo.
		float sx = abs(s - 0.5) * 2.0;
		float canto = clamp(smoothstep(0.66, 1.0, sx) + 1.0 - smoothstep(0.0, 0.16, t), 0.0, 1.0);
		placa *= 1.0 - canto * 0.42;
		// Estrias ao longo da unha, bem de leve.
		float estria = ruido(vec3(s * 70.0, t * 2.0, 2.0));
		h += (estria - 0.5) * 0.5 * clamp(1.0 - px * 900.0, 0.0, 1.0);
		base = placa;
		ROUGHNESS = mix(0.34, 0.45, livre) + canto * 0.2;
		SPECULAR = 0.38;
		SSS_STRENGTH = espalha * 0.35;
	} else if (pele) {
		// Carne, e nao cera: a pele da ficha um pouco mais saturada e quente.
		float lum = dot(base, vec3(0.3, 0.59, 0.11));
		base = mix(vec3(lum), base, 1.3) * vec3(1.04, 0.96, 0.93);
		// Manchas: onde o sangue chega mais (vermelho) e onde falta (palido).
		float mancha = fbm3(pele3 * 45.0);
		base = mix(base, base * vec3(1.14, 0.86, 0.84), smoothstep(0.45, 0.8, mancha) * 0.6);
		base = mix(base, base * vec3(0.96, 0.98, 1.03), (1.0 - smoothstep(0.2, 0.5, mancha)) * 0.35);
		// Veias no dorso da mao e do antebraco: so onde o tubo e grosso.
		float grosso = smoothstep(0.017, 0.027, raio);
		float fio = 1.0 - abs(ruido(pele3 * vec3(70.0, 70.0, 16.0)) * 2.0 - 1.0);
		float veia = pow(fio, 9.0) * grosso * smoothstep(0.1, 0.7, dorso) * veias;
		base = mix(base, base * vec3(0.76, 0.85, 1.1), veia * 0.55);
		h += veia * 0.9;
		// Rugas: linhas finas atravessadas no dorso dos dedos, em manchas.
		float dedo = 1.0 - smoothstep(0.012, 0.02, raio);
		float onda = sin(pele3.z * 1150.0 + ruido(pele3 * 220.0) * 5.0);
		float ruga = pow(1.0 - abs(onda), 5.0) * dedo * smoothstep(-0.2, 0.6, dorso)
			* smoothstep(0.35, 0.7, ruido(pele3 * vec3(60.0, 60.0, 90.0)));
		ruga *= clamp(1.0 - px * 1100.0, 0.0, 1.0);
		h -= ruga * 0.7;
		base *= 1.0 - ruga * 0.12;
		// Poros e o grao da pele.
		float poro = ruido(pele3 * 1500.0) * 0.6 + ruido(pele3 * 3300.0 + 7.0) * 0.4;
		float some = clamp(1.0 - px * 900.0, 0.0, 1.0);
		h += (poro - 0.5) * 0.6 * some;
		base *= 1.0 - (1.0 - poro) * 0.07 * some;
		ROUGHNESS = clamp(0.48 + (poro - 0.5) * 0.3 * some + ruga * 0.1, 0.3, 0.8);
		SPECULAR = 0.45;
		SSS_STRENGTH = espalha;
		// A borda contra a luz esquenta: e sangue por baixo da pele.
		float borda = pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), 3.0);
		base = mix(base, base * vec3(1.2, 0.84, 0.78), borda * 0.45);
	} else {
		// Pano: a trama do algodao e o fio irregular. Sem brilho de borda: com
		// ele a manga clara virava um tubo de neon na frente da lente.
		float trama = sin(pele3.z * 2600.0) * sin((pele3.x + pele3.y) * 1900.0);
		float some = clamp(1.0 - px * 1500.0, 0.0, 1.0);
		h += trama * 0.25 * some;
		base *= (1.0 - (0.5 + 0.5 * trama) * 0.06 * some) * (0.92 + 0.16 * ruido(pele3 * 80.0));
		ROUGHNESS = 0.95;
		SPECULAR = 0.12;
	}
	// O contato com o aparelho. A sombra e mais funda do lado que olha para
	// ele: a unha de um dedo encostado na lateral nao escurece como a polpa.
	if (contato > 0.0) {
		vec3 mundo = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec3 p = (fone_inv * vec4(mundo, 1.0)).xyz;
		float sd = caixa(p);
		vec2 e = vec2(0.0015, 0.0);
		vec3 grad = normalize(vec3(caixa(p + e.xyy) - caixa(p - e.xyy),
			caixa(p + e.yxy) - caixa(p - e.yxy), caixa(p + e.yyx) - caixa(p - e.yyx)) + 1e-6);
		vec3 n_fone = normalize((fone_inv * vec4((INV_VIEW_MATRIX * vec4(n, 0.0)).xyz, 0.0)).xyz);
		float olha = clamp(-dot(n_fone, grad), 0.0, 1.0);
		float perto = 1.0 - smoothstep(0.0, 0.014, max(sd, 0.0));
		float sombra = perto * mix(0.3, 1.0, olha) * 0.6 * contato;
		base *= 1.0 - sombra;
		SPECULAR *= 1.0 - sombra;
		// A tela acesa, na pele que esta na frente dela e olha para ela.
		float frente = p.z - fone_meia.z;
		float na_tela = step(abs(p.x), tela_meia.x + 0.006) * step(abs(p.y), tela_meia.y + 0.006);
		float de_frente = clamp(-n_fone.z, 0.0, 1.0);
		float luz = (1.0 - smoothstep(0.0, 0.025, frente)) * step(0.0, frente);
		EMISSION = base * tela_luz * de_frente * luz * na_tela * contato;
	}
	// O relevo pelo gradiente de tela (Mikkelsen): sem mapa de normal, sem
	// tangente, e firme na malha que muda a cada quadro.
	float alt = h * relevo;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, n);
	vec3 r2 = cross(n, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(alt) * r1 + dFdy(alt) * r2);
	NORMAL = normalize(abs(det) * n - grad);
	ALBEDO = base;
}
"""

## A camada de render dos bracos. A luz da tela do celular nao os alcanca por
## ela: eles tem a luz propria (`Iphone4S.luz_da_mao`), de queda suave. A da
## tela cai com o quadrado da distancia e, a dois dedos do antebraco que passa
## na frente dela, estourava a manga num borrao branco.
const CAMADA := 1 << 17
## O braco de cima, do cotovelo ao ombro (m).
const BRACO_DE_CIMA := 0.29
## Tremor do braco esticado: amplitude (m) na mao.
const TREMOR := 0.0028
## Quanto os dedos mexem sozinhos (graus), parado e com medo.
const DEDOS_VIVOS := 1.6
const DEDOS_COM_MEDO := 5.0

## A pegada de agora, uma mao em pose (ver `MaoPosada`): `o` o meio da palma na
## linha dos nos, `d` do punho para os nos, `dorso` a normal das costas, `pose`
## a dobra dos dedos.
var pegada: Dictionary = {}
var ombro := Vector3.ZERO
## Para onde o cotovelo dobra.
var polo := Vector3.DOWN
var direita: bool = true
## 0 parado, 1 tremendo de medo e de forca.
var tremor: float = 0.0
## Quanto os dedos mexem sozinhos (0 a 1). Zero quando eles seguram alguma
## coisa: dedo que mexe em cima do que segura parece que o solta.
var dedos_vivos: float = 1.0
## O ultimo punho e cotovelo montados (para quem mede).
var punho_montado := Vector3.ZERO
var cotovelo_montado := Vector3.ZERO

var _pele: Color
var _manga: Color
var _longa: bool
var _t: float = 0.0
var _de: Dictionary = {}
var _para: Dictionary = {}
var _k: float = 1.0
var _dur: float = 1.0
var _arco := Vector3.ZERO
var _abre: float = 0.0
var _semente: float = 0.0

static var _material: ShaderMaterial


static func criar(nome: String, e_direita: bool, pele: Color, manga: Color,
		longa: bool) -> BracoVivo:
	var b := BracoVivo.new()
	b.name = nome
	b.direita = e_direita
	b._pele = pele
	b._manga = manga
	b._longa = longa
	b._semente = 3.7 if e_direita else 0.0
	b.material_override = material()
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	b.layers = CAMADA
	b.visible = false
	return b


## Diz ao material onde o aparelho esta (global) e o quanto a tela acende a
## pele de perto: a sombra de contato e a luz da tela nas polpas. `forca` zero
## desliga.
static func encostar_no_fone(fone: Transform3D, forca: float, tela_luz: Color) -> void:
	var mat := material()
	mat.set_shader_parameter(&"fone_inv", Projection(fone.affine_inverse()))
	mat.set_shader_parameter(&"contato", forca)
	mat.set_shader_parameter(&"tela_luz", Vector3(tela_luz.r, tela_luz.g, tela_luz.b))


## A pele e o pano das maos de primeira pessoa.
static func material() -> ShaderMaterial:
	if _material != null:
		return _material
	var sh := Shader.new()
	sh.code = PELE_SHADER
	_material = ShaderMaterial.new()
	_material.shader = sh
	var mat_npc := load(Corpo.MATERIAL) as ShaderMaterial
	if mat_npc != null:
		_material.set_shader_parameter(&"atlas", mat_npc.get_shader_parameter(&"albedo_tex"))
	var cel := Aparencia.uv_da_celula(Aparencia.PECA_MAO, Aparencia.LINHA_PECAS)
	_material.set_shader_parameter(&"uv_pele", cel.position + Vector2(0.5, 0.14) * cel.size)
	return _material


## Uma pegada: a mao em `o` (o meio da palma na linha dos nos), os dedos para
## `d`, o dorso para `dorso`, na pose dada (nome de `MaoPosada.POSES` ou a
## propria pose).
static func pega(o: Vector3, d: Vector3, dorso: Vector3, pose_: Variant) -> Dictionary:
	var p: Dictionary = MaoPosada.pose(pose_) if pose_ is StringName or pose_ is String \
		else pose_
	var dd := d.normalized()
	return {"o": o, "d": dd, "dorso": (dorso - dd * dorso.dot(dd)).normalized(), "pose": p}


## A pegada levada por uma transformacao (da mao no espaco de um objeto para o
## espaco do carro, por exemplo).
static func levar(xf: Transform3D, p: Dictionary) -> Dictionary:
	var q := p.duplicate()
	q["o"] = xf * (p["o"] as Vector3)
	q["d"] = (xf.basis * (p["d"] as Vector3)).normalized()
	q["dorso"] = (xf.basis * (p["dorso"] as Vector3)).normalized()
	return q


## Vai para a pegada `para` em `duracao` segundos, fazendo arco (`arco` e o
## deslocamento no meio do caminho) e abrindo a mao no meio (`abre`: de 0 a 1,
## quanto passa pela mao aberta).
func ir(para: Dictionary, duracao: float, arco := Vector3.ZERO, abre: float = 0.0) -> void:
	_de = pegada.duplicate() if not pegada.is_empty() else para
	_para = para
	_k = 0.0
	_dur = maxf(duracao, 0.01)
	_arco = arco
	_abre = abre


## Troca o destino sem recomecar a ida: a pegada que anda (a mao no chao
## agarrando o ar) continua sendo perseguida de onde a mao esta.
func alvo(para: Dictionary) -> void:
	if _k >= 1.0:
		pegada = para
	_para = para


## Ja chegou na pegada pedida.
func chegou() -> bool:
	return _k >= 1.0


func pular(para: Dictionary) -> void:
	pegada = para
	_para = para
	_k = 1.0


## Avanca a ida e remonta a malha. Quem anima chama uma vez por quadro.
func passo(delta: float) -> void:
	_t += delta
	if _k < 1.0 and not _para.is_empty():
		_k = minf(1.0, _k + delta / _dur)
		# Sai devagar, acelera e freia chegando: o gesto de quem vai buscar.
		var e := _k * _k * (3.0 - 2.0 * _k)
		pegada = _misturar(_de, _para, e)
		var meio := sin(e * PI)
		pegada["o"] = (pegada["o"] as Vector3) + _arco * meio
		if _abre > 0.0:
			pegada["pose"] = MaoPosada.misturar(pegada["pose"], MaoPosada.pose(&"aberta"),
				_abre * meio)
	elif not _para.is_empty():
		pegada = _para.duplicate()
	if visible:
		refazer()


func refazer() -> void:
	if pegada.is_empty():
		return
	var d: Vector3 = pegada["d"]
	var dorso: Vector3 = pegada["dorso"]
	var treme := Vector3(sin(_t * 83.0) + 0.5 * sin(_t * 37.0),
		sin(_t * 71.0 + 1.3) + 0.5 * sin(_t * 29.0),
		sin(_t * 97.0 + 2.1)) * TREMOR * tremor
	var o: Vector3 = (pegada["o"] as Vector3) + treme
	var p := MaoPosada.viva(pegada["pose"], _t,
		(DEDOS_VIVOS + DEDOS_COM_MEDO * clampf(tremor, 0.0, 1.5)) * dedos_vivos, _semente)
	var punho := MaoPosada.punho_de(o, d, dorso)
	var cotovelo := cotovelo_entre(punho, ombro, polo)
	var dados := PSXMesh.dados_vazios()
	var b := MaoPosada.montar(dados, o, d, dorso, p, direita, cotovelo, _pele, _manga,
		_longa)
	# O braco de cima nasce onde o antebraco acabou, e nao no cotovelo pedido:
	# o antebraco nao estica alem do comprimento dele, e a diferenca abria uma
	# fresta no cotovelo.
	var pu: Vector3 = b["punho"]
	var fim := pu + (b["eixo"] as Vector3) * clampf(cotovelo.distance_to(pu), 0.10,
		MaoModelada.ANTEBRACO)
	MaoModelada.braco_de_cima(dados, fim, ombro, _pele, _manga, _longa)
	mesh = PSXMesh.dados_para_mesh(dados)
	punho_montado = pu
	cotovelo_montado = fim


## O cotovelo de um braco de dois ossos (antebraco da `MaoModelada`, braco de
## cima `BRACO_DE_CIMA`) entre o punho e o ombro, dobrando para `polo`. Longe
## demais, o braco estica reto.
static func cotovelo_entre(punho: Vector3, ombro_: Vector3, polo_: Vector3) -> Vector3:
	var a := MaoModelada.ANTEBRACO
	var b := BRACO_DE_CIMA
	var para := ombro_ - punho
	var d := para.length()
	if d < 0.001:
		return punho + Vector3.UP * a
	var eixo := para / d
	d = clampf(d, absf(a - b) + 0.01, a + b - 0.001)
	var x := (a * a - b * b + d * d) / (2.0 * d)
	var h := sqrt(maxf(a * a - x * x, 0.0))
	var p := polo_ - eixo * polo_.dot(eixo)
	if p.length_squared() < 1e-6:
		p = Vector3.DOWN - eixo * Vector3.DOWN.dot(eixo)
	return punho + eixo * x + p.normalized() * h


static func _misturar(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var da: Vector3 = a["d"]
	var db: Vector3 = b["d"]
	var sa: Vector3 = a["dorso"]
	var sb: Vector3 = b["dorso"]
	# A base inteira gira junto (quaternio), e nao cada eixo sozinho: com os dois
	# eixos misturados em separado a mao torcia no meio do caminho.
	var qa := Basis(sa.cross(da).normalized(), sa, da).orthonormalized().get_rotation_quaternion()
	var qb := Basis(sb.cross(db).normalized(), sb, db).orthonormalized().get_rotation_quaternion()
	var bq := Basis(qa.slerp(qb, k))
	return {"o": (a["o"] as Vector3).lerp(b["o"], k), "d": bq.z, "dorso": bq.y,
		"pose": MaoPosada.misturar(a["pose"], b["pose"], k)}
