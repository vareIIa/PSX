// Grama de verdade perto do jogador (PLANO_FLORA_AAA, etapa 4). So MODERNO.
//
// Um tufo de laminas instanciado sobre o gramado (GramaViva). A textura HD da
// grama continua sendo o chao; o tufo e o que a textura nao faz: a borda do
// gramado com volume contra o passeio, a lamina contra o sol, o vento passando.
//
// Longe, a lamina ENCOLHE ate o chao antes do fim do alcance, e a troca para a
// textura nao se ve. A cor vem da mesma paleta da textura (tools/gerar_flora_hd,
// `grama`) com variacao por instancia no INSTANCE_CUSTOM.

shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec3 cor_pe : source_color = vec3(0.16, 0.22, 0.09);
uniform vec3 cor_ponta : source_color = vec3(0.42, 0.52, 0.22);
uniform vec3 cor_seca : source_color = vec3(0.56, 0.5, 0.3);
uniform float vento_forca : hint_range(0.0, 1.0) = 0.22;
uniform float encolhe_de = 10.0;
uniform float encolhe_ate = 16.0;
uniform float translucidez : hint_range(0.0, 2.0) = 0.6;
const vec2 VENTO_DIR = vec2(0.82, 0.57);

global uniform float psx_molhado;

varying float altura_rel;
varying float seca;
varying float tinta_i;

void vertex() {
	// UV.y: 0 no pe, 1 na ponta da lamina.
	altura_rel = UV.y;
	seca = INSTANCE_CUSTOM.g;
	tinta_i = INSTANCE_CUSTOM.r;
	vec3 mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist = length(mundo - CAMERA_POSITION_WORLD);
	float some = 1.0 - smoothstep(encolhe_de, encolhe_ate, dist);
	VERTEX.y *= some;
	VERTEX.xz *= mix(0.4, 1.0, some);
	// Vento: a mesma frente que anda pela cidade (psx_folha_pixel), mais uma
	// ondulacao curta que atravessa o gramado.
	float frente = 0.5 + 0.5 * sin(dot(mundo.xz, VENTO_DIR) * 0.045 - TIME * 1.1);
	float onda = sin(dot(mundo.xz, VENTO_DIR) * 0.9 - TIME * 2.6 + INSTANCE_CUSTOM.b * 6.28);
	float dobra = altura_rel * altura_rel * vento_forca * (0.35 + 0.65 * frente) * (0.6 + 0.4 * onda);
	VERTEX.xz += (inverse(mat3(MODEL_MATRIX)) * vec3(VENTO_DIR.x, 0.0, VENTO_DIR.y)).xz * dobra * 0.18;
	// A normal da lamina puxada para cima: grama e iluminada como um tapete,
	// e a lamina de costas para o sol nao fica preta.
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.65));
}

void fragment() {
	vec3 c = mix(cor_pe, cor_ponta, smoothstep(0.0, 1.0, altura_rel));
	c = mix(c, cor_seca, seca * smoothstep(0.3, 1.0, altura_rel));
	c *= COLOR.rgb * tinta_i;
	ALBEDO = c * mix(1.0, 0.7, psx_molhado);
	// Oclusao do pe: a base do tufo fica no escuro do proprio tufo.
	AO = mix(0.45, 1.0, altura_rel);
	AO_LIGHT_AFFECT = 0.3;
	ROUGHNESS = mix(0.75, 0.2, psx_molhado);
	SPECULAR = 0.25;
	BACKLIGHT = c * translucidez;
}
