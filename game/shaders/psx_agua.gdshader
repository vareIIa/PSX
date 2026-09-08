// Agua do lago — onda por vertice, duas camadas rolando e transparencia.
//
// Por que nao e o psx_surface com uma textura de agua
// ----------------------------------------------------
// Porque agua parada nao existe. O chafariz da praca usa o psx_surface e esta
// certo: e um tanque de um metro e meio que o jogador olha de cima. Um lago de
// trinta metros com a mesma superficie le como piso de vidro verde — a falta de
// movimento aparece na hora, e nenhuma quantidade de textura conserta.
//
// O movimento vem de tres coisas somadas, e as tres sao necessarias:
//
//   1. A onda de VERTICE, que levanta e abaixa a lamina. E ela que faz o
//      nenufar subir e descer e a margem molhar e secar.
//   2. Duas copias da textura rolando em direcoes e velocidades diferentes. O
//      batimento entre elas nunca repete de forma audivel ao olho; uma copia so
//      le como esteira rolante.
//   3. A NORMAL recalculada a partir da derivada da onda. Sem isso a luz do
//      poste bate igual na crista e no vale, e o relevo que o vertice criou nao
//      aparece na iluminacao.
//
// Continua PSX: snap de vertice, UV afim, luz por vertice, sem specular e sem
// sombra. A agua e do jogo, nao de outro jogo.

shader_type spatial;
render_mode vertex_lighting, specular_disabled, shadows_disabled, diffuse_lambert, cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec2 uv_tile = vec2(0.35, 0.35);
uniform vec2 snap_resolution = vec2(240.0, 135.0);
uniform bool use_snap = true;
uniform bool use_affine = true;

// Quanto a lamina sobe e desce, em metros. Oito centimetros: acima disso a
// borda descola do barranco e aparece a fresta entre a agua e a areia.
uniform float onda_altura : hint_range(0.0, 0.5) = 0.075;
uniform float onda_escala : hint_range(0.05, 2.0) = 0.42;
uniform float onda_velocidade : hint_range(0.0, 4.0) = 0.85;

// Deslocamento das duas camadas, em UV por segundo. Direcoes diferentes de
// proposito — ver o cabecalho.
uniform vec2 correnteA = vec2(0.021, 0.013);
uniform vec2 correnteB = vec2(-0.014, 0.026);

uniform vec4 fundo_cor : source_color = vec4(0.09, 0.16, 0.16, 1.0);
uniform vec4 brilho_cor : source_color = vec4(0.52, 0.68, 0.70, 1.0);
uniform float brilho_energia : hint_range(0.0, 4.0) = 0.55;
uniform float opacidade : hint_range(0.0, 1.0) = 0.82;

varying vec2 uv_affine;
varying float w_affine;
varying float crista;

// A onda: duas senoides cruzadas em razao irracional, como no vento das folhas.
// Periodo audivel e o defeito de sempre — com uma so, em dez segundos o olho
// aprende o ritmo e o lago vira uma cortina balancando.
float lamina(vec2 p, float t) {
	return sin(p.x * 0.9 + t) * 0.6
		+ sin(p.y * 1.31 - t * 0.83) * 0.4
		+ sin((p.x + p.y) * 0.47 + t * 1.29) * 0.35;
}

void vertex() {
	vec3 mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * onda_velocidade;
	vec2 p = mundo.xz * onda_escala;

	float h = lamina(p, t);
	VERTEX.y += h * onda_altura;

	// Derivada por diferenca finita. Um passo de 0,35 m e grosseiro para
	// calculo e certo para imagem: passo menor devolve a normal exata de uma
	// onda que a malha nem chega a representar, e o brilho fica nervoso.
	const float e = 0.35;
	float dx = (lamina(p + vec2(e, 0.0) * onda_escala, t) - h) * onda_altura;
	float dz = (lamina(p + vec2(0.0, e) * onda_escala, t) - h) * onda_altura;
	NORMAL = normalize(vec3(-dx, e, -dz));

	// A crista alimenta o brilho no fragmento. Sai daqui, e nao de la, porque a
	// altura da onda so existe no vertice.
	crista = clamp(h * 0.5 + 0.5, 0.0, 1.0);

	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (use_snap && clip.w > 0.0) {
		vec3 ndc = clip.xyz / clip.w;
		ndc.xy = floor(ndc.xy * snap_resolution) / snap_resolution;
		clip = vec4(ndc * clip.w, clip.w);
	}
	POSITION = clip;

	w_affine = clip.w;
	// A UV sai da posicao de MUNDO, e nao da UV da malha. O lago e cortado em
	// pedacos por chunk e cada pedaco tem a propria UV ancorada no canto; sem
	// isto a emenda entre dois chunks aparece como um degrau na correnteza.
	uv_affine = mundo.xz * uv_tile * clip.w;
}

void fragment() {
	vec2 uv = use_affine ? (uv_affine / w_affine) : (UV * uv_tile);
	vec3 a = texture(albedo_tex, uv + correnteA * TIME).rgb;
	vec3 b = texture(albedo_tex, uv * 0.63 + correnteB * TIME).rgb;

	// Multiplicar, e nao somar. Somadas, as duas camadas clareiam a agua toda e
	// o lago fica leitoso; multiplicadas, so o que e claro nas DUAS vira brilho,
	// e o que aparece e o reflexo quebrado.
	vec3 mistura = a * b * 2.1;
	mistura = mix(fundo_cor.rgb, mistura, 0.78);

	ALBEDO = mistura * tint.rgb * COLOR.rgb;
	ALPHA = opacidade * tint.a;

	// Brilho so na crista. Chapado em toda a superficie ele apaga a onda em vez
	// de mostra-la.
	float f = smoothstep(0.62, 0.95, crista);
	EMISSION = brilho_cor.rgb * brilho_energia * f * (0.4 + mistura);

	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}
