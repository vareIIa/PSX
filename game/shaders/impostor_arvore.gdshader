// Impostor de arvore: a mata de fundo da estrada (MataDaEstrada).
//
// Um quadrado por arvore, virado para a camera, que mostra a foto da arvore de
// verdade tirada do angulo mais proximo do olho (tests/assar_impostores). O
// atlas tem AZIMUTES colunas em volta e uma linha por elevacao (0, 25, 50 e 75
// graus); o pixel mistura os quatro quadros vizinhos do angulo exato, entao a
// arvore gira de verdade quando a camera passa por ela, sem trocar de foto num
// estalo. O segundo atlas guarda a normal de cada pixel no espaco da arvore: a
// luz do jogo (farol, relampago, lua) acende a copa pelo volume dela, como na
// arvore de perto, e nao como um cartaz chapado.
//
// A luz e a mesma da folha de perto (psx_folha_pixel): difusa que envolve, luz
// atraves da folha e sol vazado. So a luz do motor; nevoa e ambiente tambem.
shader_type spatial;
render_mode skip_vertex_transform, cull_disabled, depth_draw_opaque, diffuse_burley,
	specular_schlick_ggx;

uniform sampler2D atlas_cor : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D atlas_nrm : filter_linear_mipmap, repeat_disable;
uniform float colunas = 6.0;
uniform float linhas = 4.0;
// Graus entre uma linha de elevacao e a seguinte.
uniform float elev_passo = 25.0;
uniform float corte : hint_range(0.0, 1.0) = 0.5;
// Quanto o alfa cresce por nivel de mip (a copa nao afina de longe).
uniform float alfa_por_mip : hint_range(0.0, 1.0) = 0.18;

// Vento: a arvore inteira, a camada 1 do psx_folha_pixel (mesma fase no mundo).
uniform float vento_forca : hint_range(0.0, 1.0) = 0.22;
uniform float vento_velocidade : hint_range(0.0, 6.0) = 1.15;
const vec2 VENTO_DIR = vec2(0.82, 0.57);

uniform float translucidez : hint_range(0.0, 2.0) = 0.6;
uniform vec3 cor_translucida : source_color = vec3(0.92, 1.0, 0.42);
uniform float envolve : hint_range(0.0, 1.0) = 0.55;
uniform float contraluz : hint_range(0.0, 3.0) = 1.0;
uniform float sol_vazado : hint_range(0.0, 1.0) = 0.3;
uniform float rugosidade : hint_range(0.0, 1.0) = 0.72;
uniform float brilho : hint_range(0.0, 1.0) = 0.08;

global uniform float psx_molhado;

// coluna, linha, peso da coluna seguinte, peso da linha seguinte
varying vec4 quadro;
// A base da instancia (so o giro): leva a normal do atlas para o mundo.
varying vec3 eixo_x;
varying vec3 eixo_z;
varying vec3 tinta;
// F0 do realce, do fragmento para a luz (no light() SPECULAR nao existe).
varying float f0_copa;

void vertex() {
	vec2 canto = VERTEX.xy;
	vec3 centro = MODEL_MATRIX[3].xyz;
	vec3 ex = MODEL_MATRIX[0].xyz;
	float escala = length(ex);
	eixo_x = ex / escala;
	eixo_z = normalize(MODEL_MATRIX[2].xyz);
	tinta = INSTANCE_CUSTOM.rgb;

	vec3 v = INV_VIEW_MATRIX[3].xyz - centro;
	v /= max(length(v), 1e-4);
	// O olho no espaco da arvore: qual foto mostrar.
	vec3 d = vec3(dot(v, eixo_x), v.y, dot(v, eixo_z));
	float el = degrees(asin(clamp(d.y, -1.0, 1.0)));
	float az = atan(d.x, d.z);
	float fc = fract(az / TAU + 1.0) * colunas;
	float c0 = floor(fc);
	float fr = clamp(el / elev_passo, 0.0, linhas - 1.001);
	float r0 = floor(fr);
	quadro = vec4(c0, r0, fc - c0, fr - r0);

	// O quadrado olha para a camera, com o "cima" do mundo (como o assador).
	vec3 dir_x = cross(vec3(0.0, 1.0, 0.0), v);
	dir_x = length(dir_x) > 1e-3 ? normalize(dir_x) : eixo_x;
	vec3 dir_y = cross(v, dir_x);
	vec3 p = centro + (dir_x * canto.x + dir_y * canto.y) * escala;

	if (vento_forca > 0.0) {
		float fase = centro.x * 0.31 + centro.z * 0.23;
		float balanco = sin(TIME * vento_velocidade + fase)
			+ 0.45 * sin(TIME * vento_velocidade * 1.73 + fase * 1.31);
		float rajada = 0.65 + 0.35 * sin(TIME * 0.21 + centro.x * 0.02);
		float frente = 0.5 + 0.5 * sin(dot(centro.xz, VENTO_DIR) * 0.045 - TIME * 1.1);
		rajada *= 0.8 + 0.45 * frente * frente;
		// So a copa anda: zero no pe do quadrado, inteiro no topo.
		float k = clamp(canto.y * 0.5 + 0.5, 0.0, 1.0);
		vec2 desvio = VENTO_DIR * balanco * rajada * vento_forca * k * k;
		p.xz += desvio;
	}

	UV = vec2(0.5 + 0.5 * canto.x, 0.5 - 0.5 * canto.y);
	VERTEX = (VIEW_MATRIX * vec4(p, 1.0)).xyz;
	NORMAL = normalize((VIEW_MATRIX * vec4(v, 0.0)).xyz);
}

void fragment() {
	vec2 uv = clamp(UV, vec2(0.003), vec2(0.997));
	vec2 tam = vec2(1.0 / colunas, 1.0 / linhas);
	float c0 = floor(quadro.x + 0.5);
	float c1 = mod(c0 + 1.0, colunas);
	float r0 = floor(quadro.y + 0.5);
	float r1 = min(r0 + 1.0, linhas - 1.0);
	// Meio quadro de cada lado so com uma foto, e a mistura no meio: menos
	// fantasma de tronco duplo do que a mistura linear inteira.
	float fa = smoothstep(0.15, 0.85, quadro.z);
	float fe = smoothstep(0.15, 0.85, quadro.w);
	vec4 w = vec4((1.0 - fa) * (1.0 - fe), fa * (1.0 - fe), (1.0 - fa) * fe, fa * fe);
	vec2 u00 = (vec2(c0, r0) + uv) * tam;
	vec2 u10 = (vec2(c1, r0) + uv) * tam;
	vec2 u01 = (vec2(c0, r1) + uv) * tam;
	vec2 u11 = (vec2(c1, r1) + uv) * tam;
	// So as fotos com peso. Com o smoothstep, 70 % do angulo cai em uma ou duas
	// fotos: amostrar as quatro sempre era o dobro de textura por pixel, e o
	// impostor da mata sobrepoe muito (o peso e o mesmo no quadrado inteiro, o
	// desvio e coerente).
	vec4 cor = vec4(0.0);
	vec3 n = vec3(0.0);
	if (w.x > 0.001) {
		cor += texture(atlas_cor, u00) * w.x;
		n += texture(atlas_nrm, u00).rgb * w.x;
	}
	if (w.y > 0.001) {
		cor += texture(atlas_cor, u10) * w.y;
		n += texture(atlas_nrm, u10).rgb * w.y;
	}
	if (w.z > 0.001) {
		cor += texture(atlas_cor, u01) * w.z;
		n += texture(atlas_nrm, u01).rgb * w.z;
	}
	if (w.w > 0.001) {
		cor += texture(atlas_cor, u11) * w.w;
		n += texture(atlas_nrm, u11).rgb * w.w;
	}
	n = n * 2.0 - 1.0;

	float a = cor.a;
	vec2 px = vec2(textureSize(atlas_cor, 0));
	vec2 dx = dFdx(u00 * px);
	vec2 dy = dFdy(u00 * px);
	float mip = max(0.0, 0.5 * log2(max(dot(dx, dx), dot(dy, dy))));
	a *= 1.0 + mip * alfa_por_mip;
	ALPHA = a;
	ALPHA_SCISSOR_THRESHOLD = corte;

	vec3 nw = normalize(eixo_x * n.x + vec3(0.0, 1.0, 0.0) * n.y + eixo_z * n.z);
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);

	vec3 alb = cor.rgb * tinta;
	float molhado = psx_molhado * smoothstep(-0.2, 0.6, nw.y);
	alb *= mix(1.0, 0.7, molhado);
	ALBEDO = alb;
	ROUGHNESS = mix(rugosidade, 0.25, molhado);
	METALLIC = 0.0;
	SPECULAR = mix(brilho, 0.35, molhado);
	f0_copa = 0.16 * SPECULAR * SPECULAR;
	BACKLIGHT = alb * cor_translucida * translucidez;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float dif = clamp((ndl + envolve) / (1.0 + envolve), 0.0, 1.0);
	float att = ATTENUATION;
	if (LIGHT_IS_DIRECTIONAL) {
		att = max(att, sol_vazado);
	}
	vec3 luz = LIGHT_COLOR * att / PI;
	DIFFUSE_LIGHT += dif * luz;
	float atras = clamp(-ndl, 0.0, 1.0);
	float contra = pow(clamp(dot(VIEW, -LIGHT), 0.0, 1.0), 4.0);
	DIFFUSE_LIGHT += BACKLIGHT * (0.45 * atras + contraluz * contra) * luz;
	if (ndl > 0.0) {
		vec3 h = normalize(VIEW + LIGHT);
		float ndh = clamp(dot(NORMAL, h), 0.0, 1.0);
		float r = max(ROUGHNESS * ROUGHNESS, 0.02);
		float r2 = r * r;
		float dd = ndh * ndh * (r2 - 1.0) + 1.0;
		float dist = r2 / (PI * dd * dd);
		float ndv = clamp(dot(NORMAL, VIEW), 0.001, 1.0);
		float k = r * 0.5;
		float vis = 0.25 / ((ndl * (1.0 - k) + k) * (ndv * (1.0 - k) + k));
		SPECULAR_LIGHT += dist * vis * f0_copa * ndl * LIGHT_COLOR * ATTENUATION * SPECULAR_AMOUNT;
	}
}
