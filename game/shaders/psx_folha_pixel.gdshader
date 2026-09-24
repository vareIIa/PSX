// Folha MODERNA — o psx_surface_pixel para vegetacao (PLANO_FLORA_AAA, etapa 1).
//
// Quem troca e o EstiloVisual, pelos nomes de `Vegetacao.MATERIAIS_FOLHA`, so no
// MODERNO. O PS1 STYLE continua no psx_surface. Todo uniform do psx_surface
// existe aqui com o mesmo nome: a troca de estilo preserva o material.
//
// O que a folha tem que a parede nao tem
// --------------------------------------
// 1. Luz ATRAVES dela. Folha e fina: contra o sol ela acende em verde-amarelo, e
//    essa borda acesa em volta da copa escura e o que o olho usa para dizer
//    "arvore de verdade". Sem isso, contra o sol a copa e uma mancha preta
//    (bancada_flora, foto `contraluz` da linha de base).
// 2. Recorte ESTAVEL. O mipmap faz a media do alfa, e a media de uma folha
//    recortada cai abaixo do limiar: de longe a copa se desmancha em lascas
//    ("matos voando"). Aqui o alfa e compensado pelo nivel de mip que o pixel
//    usa, e o limiar ainda afrouxa com a distancia, como no psx_surface.
// 3. Vento em tres escalas. A arvore inteira balanca devagar (a mesma formula
//    do psx_surface, que o som do parque tambem segue); o cacho de folha anda
//    mais rapido e fora de fase com o vizinho; a folha treme, e o tremor gira
//    a normal um pouco, que e o cintilar de copa ao sol.
// 4. Cera. Mangueira, jaqueira e oiti tem folha lustrosa: um realce largo e
//    fraco, e nao o fosco 0,88 de reboco.

shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec2 uv_tile = vec2(1.0, 1.0);

uniform vec2 snap_resolution = vec2(240.0, 135.0);
uniform bool use_snap = true;
uniform bool use_affine = true;
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.0;

global uniform bool psx_snap;
global uniform bool psx_affine;
global uniform float psx_snap_escala;

uniform float vento_forca : hint_range(0.0, 1.0) = 0.0;
uniform float vento_velocidade : hint_range(0.0, 6.0) = 1.0;
const vec2 VENTO_DIR = vec2(0.82, 0.57);

uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy : hint_range(0.0, 8.0) = 0.0;

// Folha fosca-acetinada por padrao; o mapa de rugosidade do atlas manda quando
// existe (a mangueira brilha mais que o capim).
uniform float rugosidade : hint_range(0.0, 1.0) = 0.62;
// Baixo de proposito: com a normal de cada folha inclinada, o reflexo do ceu
// azul cobria a copa inteira de cinza-azulado (bancada_flora, A/B de brilho:
// 0,3 azul, 0,12 ainda azul na sombra, 0,06 verde). A cera aparece no sol.
uniform float brilho : hint_range(0.0, 1.0) = 0.08;

uniform sampler2D albedo_hd : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_hd : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// R = rugosidade, G = oclusao, B = espessura (quanto de luz a folha deixa passar).
uniform sampler2D rugosidade_hd : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool usa_hd = false;
uniform bool depurar_relevo = false;
uniform float relevo : hint_range(0.0, 3.0) = 1.0;

global uniform float psx_molhado;
uniform float molha : hint_range(0.0, 1.0) = 1.0;
instance uniform float abrigo : hint_range(0.0, 1.0) = 0.0;
uniform float rugosidade_molhada : hint_range(0.0, 1.0) = 0.12;
global uniform float psx_chuva;
uniform float gotas : hint_range(0.0, 1.0) = 0.0;
uniform float roupa : hint_range(0.0, 1.0) = 0.0;
uniform float encharcado : hint_range(-1.0, 1.0) = -1.0;
uniform bool usa_celula = false;

// --- so da folha ----------------------------------------------------------------
// Quanto da luz de tras atravessa. 0 = placa opaca (o psx_surface_pixel).
uniform float translucidez : hint_range(0.0, 2.0) = 0.75;
// Cor que a folha deixa passar: a clorofila filtra o azul, sai verde-amarelo.
uniform vec3 cor_translucida : source_color = vec3(0.92, 1.0, 0.42);
// Quanto o alfa cresce por nivel de mip. 0 desliga a compensacao.
uniform float alfa_por_mip : hint_range(0.0, 1.0) = 0.22;
// Amplitude do cacho (m) e da folha (m), antes da rajada e da rigidez.
uniform float balanco_cacho : hint_range(0.0, 0.3) = 0.06;
uniform float tremor_folha : hint_range(0.0, 0.1) = 0.018;
// Cartao de perfil. A copa e feita de cartoes que olham para FORA, e na borda da
// silhueta eles ficam de lado para o olho: a mancha inteira da celula espremida
// num remo verde saindo da copa (bancada_flora, `contraluz`). Folha de verdade de
// perfil e fina; aqui o alfa cai com o angulo e o cartao de lado se desfaz no
// miolo denso da celula. 0 desliga.
// 0 por padrao: quem liga e o EstiloVisual, so na copa (`vegetacao`). Chao de
// mato e vitoria-regia deitados sao vistos de raspao e sumiriam.
uniform float fade_perfil : hint_range(0.0, 1.0) = 0.0;
// O relevo da folha sobre a normal esferica da copa. Inteiro, cada folha acende
// e apaga sozinha e a copa perde o volume redondo; 0,7 guarda os dois.
uniform float relevo_folha : hint_range(0.0, 1.0) = 0.7;
// Luz que ENVOLVE a copa (rodada 2). Com Lambert a normal esferica do lado de
// sombra da copa chega a zero de sol e o cartao dali vira recorte preto chapado
// contra o ceu — o "remo escuro" da rua residencial. Copa de verdade e um volume
// de folhas soltas: o sol vaza por entre elas, e o lado de sombra fica verde
// fechado, nao preto. `envolve` e o quanto o terminador anda para tras (0 =
// Lambert). O lado do sol fica como estava (ndl = 1 da 1); a versao que
// conserva energia escurecia o lado do sol um terco e nao abria a sombra.
uniform float envolve : hint_range(0.0, 1.0) = 0.55;
// Luz de tras vista de frente para o sol (o cacho aceso em volta da copa).
uniform float contraluz : hint_range(0.0, 3.0) = 1.0;
// Sol que atravessa a copa. A sombra do mapa de sombra e de corpo opaco; a copa
// e folha solta, e o lado dela que a propria copa sombreia ainda recebe o sol
// que vaza entre as folhas. Sem isto a metade de tras de toda copa era preta
// (bancada `mangueira_perto`). So para a luz direcional: nas luzes de poste a
// ATTENUATION tambem traz a queda com a distancia.
uniform float sol_vazado : hint_range(0.0, 1.0) = 0.3;
// A oclusao de copa vem pintada no vertice (Vegetacao._cartao, 0,42 a 0,92),
// feita para a luz por vertice do PS1. Com sombra de verdade por cima ela
// escurecia duas vezes; aqui o expoente a abre (0,48 vira 0,6). 1 = como veio.
uniform float ao_vertice : hint_range(0.3, 1.0) = 0.7;

varying vec2 uv_affine;
varying float w_affine;
varying float face_cima;
varying float tremor_n;
// F0 do realce, do fragmento para a luz (SPECULAR_AMOUNT na luz e da LUZ).
varying float f0_folha;
varying float brilho_folha;

float hash31(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void vertex() {
	if (usa_celula) {
		UV = INSTANCE_CUSTOM.xy + UV * INSTANCE_CUSTOM.zw;
	}
	tremor_n = 0.0;
	if (vento_forca > 0.0) {
		vec3 mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float rigidez = COLOR.a;
		// Camada 1: a planta inteira. Igual ao psx_surface (e ao Folhagem, o som).
		float fase = mundo.x * 0.31 + mundo.z * 0.23;
		float balanco = sin(TIME * vento_velocidade + fase)
			+ 0.45 * sin(TIME * vento_velocidade * 1.73 + fase * 1.31);
		float rajada = 0.65 + 0.35 * sin(TIME * 0.21 + mundo.x * 0.02);
		// A rajada que ATRAVESSA a cidade: uma frente de vento andando na direcao
		// dele, que dobra uma arvore depois da outra em vez de todas juntas.
		float frente = 0.5 + 0.5 * sin(dot(mundo.xz, VENTO_DIR) * 0.045 - TIME * 1.1);
		rajada *= 0.8 + 0.45 * frente * frente;
		vec2 desvio = VENTO_DIR * (balanco * rajada * vento_forca * rigidez);
		VERTEX.x += desvio.x;
		VERTEX.z += desvio.y;
		VERTEX.y -= length(desvio) * 0.25;

		// Camada 2: o cacho. Mais rapido, fase pela posicao grossa (um cacho de
		// um metro anda quase junto), e para os lados tambem.
		float r2 = rigidez * rigidez;
		float fc = mundo.x * 1.3 + mundo.y * 0.9 + mundo.z * 1.7;
		vec3 cacho = vec3(sin(TIME * 2.3 + fc), 0.35 * sin(TIME * 1.9 + fc * 1.3),
			cos(TIME * 2.1 + fc * 0.8));
		VERTEX += cacho * balanco_cacho * r2 * rajada * (vento_forca / 0.22);

		// Camada 3: a folha. Rapido, fase por vertice, ao longo da normal.
		float h = hash31(floor(mundo * 7.0));
		float tr = sin(TIME * (7.0 + 5.0 * h) + h * 40.0);
		VERTEX += NORMAL * tr * tremor_folha * r2 * rajada * (vento_forca / 0.22);
		tremor_n = tr * r2 * rajada;
	}

	face_cima = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;

	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (use_snap && psx_snap && clip.w > 0.0) {
		vec3 ndc = clip.xyz / clip.w;
		vec2 grade = snap_resolution * psx_snap_escala;
		ndc.xy = floor(ndc.xy * grade) / grade;
		clip = vec4(ndc * clip.w, clip.w);
	}
	POSITION = clip;
	w_affine = clip.w;
	uv_affine = UV * uv_tile * clip.w;
}

mat3 base_tangente(vec3 n, vec3 p, vec2 uv) {
	vec3 dp1 = dFdx(p);
	vec3 dp2 = dFdy(p);
	vec2 duv1 = dFdx(uv);
	vec2 duv2 = dFdy(uv);
	vec3 dp2perp = cross(dp2, n);
	vec3 dp1perp = cross(n, dp1);
	vec3 t = dp2perp * duv1.x + dp1perp * duv2.x;
	vec3 b = dp2perp * duv1.y + dp1perp * duv2.y;
	float inv = inversesqrt(max(max(dot(t, t), dot(b, b)), 1e-12));
	return mat3(t * inv, b * inv, n);
}

void fragment() {
	vec2 uv = (use_affine && psx_affine) ? (uv_affine / w_affine) : (UV * uv_tile);
	vec4 texel = usa_hd ? (texture(albedo_hd, uv) * tint) : (texture(albedo_tex, uv) * tint);
	ALBEDO = texel.rgb * pow(COLOR.rgb, vec3(ao_vertice));

	float espessura = 1.0;
	if (alpha_cutoff > 0.0) {
		float a = texel.a;
		if (usa_hd) {
			// Nivel de mip deste pixel. Cada nivel e uma media de 4 texels, e a
			// cobertura da folha cai com ele; o alfa sobe na mesma medida.
			vec2 tam = vec2(textureSize(albedo_hd, 0));
			vec2 dx = dFdx(uv * tam);
			vec2 dy = dFdy(uv * tam);
			float mip = max(0.0, 0.5 * log2(max(dot(dx, dx), dot(dy, dy))));
			a *= 1.0 + mip * alfa_por_mip;
		}
		if (fade_perfil > 0.0) {
			// A normal da FACE, e nao a da copa (que e esferica e nunca fica de lado).
			vec3 nf = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
			float perfil = abs(dot(nf, normalize(-VERTEX)));
			a *= mix(1.0, smoothstep(0.12, 0.55, perfil), fade_perfil);
		}
		ALPHA = a;
		float dist = length(VERTEX);
		ALPHA_SCISSOR_THRESHOLD = alpha_cutoff * mix(1.0, 0.6, smoothstep(25.0, 90.0, dist));
	}

	if (emission_energy > 0.0) {
		EMISSION = emission_color.rgb * texel.rgb * COLOR.rgb * emission_energy;
	}

	float rug_seca = rugosidade;
	vec3 n_copa = normalize(NORMAL);
	if (usa_hd) {
		vec3 n_tan;
		n_tan.xy = (texture(normal_hd, uv).xy * 2.0 - 1.0) * relevo * relevo_folha;
		n_tan.z = sqrt(max(1.0 - dot(n_tan.xy, n_tan.xy), 0.0));
		NORMAL = normalize(base_tangente(n_copa, VERTEX, uv) * normalize(n_tan));
		vec3 ru = texture(rugosidade_hd, uv).rgb;
		rug_seca = ru.r;
		AO = ru.g;
		AO_LIGHT_AFFECT = 0.35;
		espessura = ru.b;
	}
	// O tremor da folha gira a normal: a copa ao sol cintila.
	vec3 lado = normalize(cross(n_copa, vec3(0.0, 1.0, 0.001)));
	NORMAL = normalize(NORMAL + lado * tremor_n * 0.22);

	float molhado = psx_molhado * molha * (1.0 - abrigo) * smoothstep(-0.2, 0.6, face_cima);
	ALBEDO *= mix(1.0, 0.62, molhado);
	float rug_final = mix(rug_seca, rugosidade_molhada, molhado);

	// Luz atraves. `espessura` e 1 onde a folha e fina e cai no galho e no
	// miolo; a cor e a da propria folha filtrada pela clorofila.
	BACKLIGHT = ALBEDO * cor_translucida * translucidez * espessura;

	if (depurar_relevo) {
		ALBEDO = NORMAL * 0.5 + 0.5;
		EMISSION = ALBEDO;
	}

	ROUGHNESS = rug_final;
	METALLIC = 0.0;
	SPECULAR = mix(brilho, 0.5, molhado);
	f0_folha = 0.16 * SPECULAR * SPECULAR;
	brilho_folha = SPECULAR;
}

// Luz da folha: difusa que envolve, luz atraves e um realce GGX fraco. O
// ambiente (ceu, reflexo) continua do motor; aqui so as luzes.
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float w = envolve;
	float dif = clamp((ndl + w) / (1.0 + w), 0.0, 1.0);
	float att = ATTENUATION;
	if (LIGHT_IS_DIRECTIONAL) {
		att = max(att, sol_vazado);
	}
	vec3 luz = LIGHT_COLOR * att / PI;
	DIFFUSE_LIGHT += dif * luz;
	// Atraves: a face de costas para a luz acende pela espessura, e mais ainda
	// quando o olho esta contra o sol.
	float atras = clamp(-ndl, 0.0, 1.0);
	float contra = pow(clamp(dot(VIEW, -LIGHT), 0.0, 1.0), 4.0);
	DIFFUSE_LIGHT += BACKLIGHT * (0.45 * atras + contraluz * contra) * luz;
	// Cera: GGX com Fresnel de Schlick, pesado pelo SPECULAR do fragmento.
	if (ndl > 0.0) {
		vec3 h = normalize(VIEW + LIGHT);
		float ndh = clamp(dot(NORMAL, h), 0.0, 1.0);
		float a = max(ROUGHNESS * ROUGHNESS, 0.02);
		float a2 = a * a;
		float dd = ndh * ndh * (a2 - 1.0) + 1.0;
		float d = a2 / (PI * dd * dd);
		float ndv = clamp(dot(NORMAL, VIEW), 0.001, 1.0);
		float k = a * 0.5;
		float vis = 0.25 / ((ndl * (1.0 - k) + k) * (ndv * (1.0 - k) + k));
		float f0 = f0_folha;
		// O Fresnel inteiro de raspao, contra o sol, deixava a borda da copa
		// branca (bancada `contraluz`): a folha fosca so ganha a fracao do brilho.
		float fr = f0 + (1.0 - f0) * pow(1.0 - clamp(dot(LIGHT, h), 0.0, 1.0), 5.0)
			* brilho_folha * 0.5;
		SPECULAR_LIGHT += d * vis * fr * ndl * LIGHT_COLOR * ATTENUATION * SPECULAR_AMOUNT;
	}
}
