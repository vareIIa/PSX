// Farol e lanterna do MODERNO (PLANO_CARROS_AAA, F4).
//
// No psx_surface_pixel a lente era a celula do atlas acesa: um retangulo de
// cor chapada que brilhava igual de ponta a ponta, e apagado era um adesivo.
// Farol de verdade e um vidro por cima de um refletor: apagado ele devolve o
// ceu e mostra os aneis da lente de Fresnel; aceso tem um ponto quente na
// lampada e o resto do refletor iluminado por ela. Lanterna e plastico
// vermelho facetado: as facetas acendem desiguais, e e isso que a faz ler como
// lanterna e nao como LED de brinquedo.
//
// A celula do atlas diz o que e cada lente (farol, lanterna, freio, re, pisca),
// e a posicao dentro da celula da o desenho: aneis em volta do centro no farol
// e na re, grade de prismas na lanterna e no pisca. O `emission_energy` que o
// `Carro` escreve por carro (apagado, aceso, freio) e o mesmo de antes.
//
// O PS1 STYLE nao passa por aqui: la o mat_carro_luz continua no psx_surface.
// Os nomes de uniform repetem os do psx_surface para a troca de shader da
// EstiloVisual preservar o que o material ja tinha.

shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

uniform sampler2D albedo_tex : source_color, filter_linear, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 uv_tile = vec2(1.0, 1.0);
uniform vec2 snap_resolution = vec2(240.0, 135.0);
uniform bool use_snap = true;
uniform bool use_affine = true;
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.0;
uniform float vento_forca : hint_range(0.0, 1.0) = 0.0;
uniform float vento_velocidade : hint_range(0.0, 6.0) = 1.0;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy : hint_range(0.0, 8.0) = 0.0;
uniform float rugosidade : hint_range(0.0, 1.0) = 0.88;
uniform float brilho : hint_range(0.0, 1.0) = 0.12;
uniform float molha : hint_range(0.0, 1.0) = 1.0;
uniform float rugosidade_molhada : hint_range(0.0, 1.0) = 0.12;
uniform float gotas : hint_range(0.0, 1.0) = 0.0;
uniform float roupa : hint_range(0.0, 1.0) = 0.0;
instance uniform float abrigo : hint_range(0.0, 1.0) = 0.0;

global uniform bool psx_snap;
global uniform float psx_snap_escala;
global uniform float psx_molhado;

// Celulas por lado no atlas do carro (256 px em celulas de 32).
const float CELULAS = 8.0;
// Quanto a emissao sobe acima do que o psx_surface dava: o Forward+ tem bloom,
// e a lente precisa passar do branco para o farol de frente virar estrela.
const float EMISSAO_HDR = 1.8;

varying float face_cima;


void vertex() {
	face_cima = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (use_snap && psx_snap && clip.w > 0.0) {
		vec3 ndc = clip.xyz / clip.w;
		vec2 grade = snap_resolution * psx_snap_escala;
		ndc.xy = floor(ndc.xy * grade) / grade;
		clip = vec4(ndc * clip.w, clip.w);
	}
	POSITION = clip;
}


void fragment() {
	vec2 uv = UV * uv_tile;
	vec2 cel = floor(uv * CELULAS);
	vec2 q = fract(uv * CELULAS);
	vec3 texel = texture(albedo_tex, uv).rgb * tint.rgb;
	vec3 cor = pow(max(COLOR.rgb, vec3(0.0)), vec3(2.2));

	// Farol (0,3) e re (3,3) tem refletor redondo; o resto e prisma.
	bool redondo = cel.y > 2.5 && cel.y < 3.5 && (cel.x < 0.5 || (cel.x > 2.5 && cel.x < 3.5));
	bool farol = cel.y > 2.5 && cel.y < 3.5 && cel.x < 0.5;
	vec2 c = (q - 0.5) * vec2(1.0, 1.7);
	float r = length(c);

	// A lente: aneis de Fresnel no refletor, prismas na lanterna.
	float aneis = 0.5 + 0.5 * cos(r * 62.0);
	vec2 p = q * vec2(9.0, 7.0);
	float prisma = abs(fract(p.x) - 0.5) + abs(fract(p.y) - 0.5);
	float desenho = redondo ? mix(0.82, 1.08, aneis) : mix(0.70, 1.15, prisma);

	// Apagado. O farol e prata: o refletor atras do vidro. A lanterna e o
	// plastico da cor dela, fundo e escuro.
	vec3 base;
	float metal;
	if (farol) {
		base = mix(vec3(0.62, 0.63, 0.65), texel, 0.25);
		metal = 0.75;
	} else {
		base = texel * cor * 0.55;
		metal = 0.0;
	}
	ALBEDO = base * desenho;
	METALLIC = metal;
	ROUGHNESS = mix(0.10, 0.22, aneis * float(redondo));
	SPECULAR = 0.7;
	// O vidro por cima de tudo.
	CLEARCOAT = 1.0;
	CLEARCOAT_ROUGHNESS = 0.03;

	// Aceso: a lampada no centro do refletor e a luz dela no resto.
	float lampada = redondo ? exp(-r * r * 22.0) : 0.0;
	if (emission_energy > 0.0) {
		EMISSION = emission_color.rgb * texel * cor * emission_energy * EMISSAO_HDR
			* desenho * (1.0 + lampada * 2.2);
	}

	// Chuva: a lente molhada escurece e espelha mais, como o resto do carro.
	float molhado = psx_molhado * molha * (1.0 - abrigo) * smoothstep(0.30, 0.75, face_cima);
	ALBEDO *= mix(1.0, 0.8, molhado);
	CLEARCOAT_ROUGHNESS = mix(CLEARCOAT_ROUGHNESS, 0.01, molhado);
}
