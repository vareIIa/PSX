// Vaga-lume. Um ponto que acende, apaga e anda devagar.
//
// Irmao do psx_estrelas: mesmo blend_add, mesmo dither de Bayer, mesma recusa a
// antialiasing. O que muda e que estrela fica no lugar e vaga-lume nao — e que
// estrela brilha o tempo todo e vaga-lume PISCA, com intervalo longo entre uma
// piscada e a outra.
//
// O intervalo e a coisa toda. Um ponto que pisca em onda senoidal le como LED
// de aparelho; o bicho acende forte, apaga e some por um tempo. Por isso a
// curva e `pow(max(sen, 0), DUREZA)`: o pico fica estreito e o vale, longo.
//
// Cada instancia carrega a propria fase em INSTANCE_CUSTOM, senao o enxame
// inteiro pisca junto e vira pisca-pisca de Natal.
//
//   INSTANCE_CUSTOM.x  fase (0..TAU)
//   INSTANCE_CUSTOM.y  ritmo, em piscadas por segundo
//   INSTANCE_CUSTOM.z  amplitude da deriva, em metros
//   INSTANCE_CUSTOM.w  brilho relativo (0..1)

shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never,
	shadows_disabled, vertex_lighting;

uniform float brilho : hint_range(0.0, 6.0) = 2.6;
uniform float dureza : hint_range(1.0, 16.0) = 4.0;
uniform vec4 cor : source_color = vec4(0.78, 1.0, 0.42, 1.0);
// Quanto do enxame esta aceso. A cena baixa isto na garoa e na cerracao em vez
// de tirar o no da arvore: ligar e desligar o enxame inteiro num corte le como
// bug de streaming.
uniform float densidade : hint_range(0.0, 1.0) = 1.0;

const float BAYER[16] = float[](
	 0.0,  8.0,  2.0, 10.0,
	12.0,  4.0, 14.0,  6.0,
	 3.0, 11.0,  1.0,  9.0,
	15.0,  7.0, 13.0,  5.0
);

varying float v_aceso;

void vertex() {
	float fase = INSTANCE_CUSTOM.x;
	float ritmo = max(INSTANCE_CUSTOM.y, 0.01);
	float deriva = INSTANCE_CUSTOM.z;

	// Deriva em tres frequencias primas entre si: o bicho nao volta ao ponto de
	// partida, que e o que denuncia movimento em loop.
	vec3 anda = vec3(
		sin(TIME * 0.31 + fase) * deriva,
		sin(TIME * 0.23 + fase * 1.7) * deriva * 0.6,
		cos(TIME * 0.19 + fase * 2.3) * deriva);

	float onda = sin(TIME * ritmo * 6.2831853 + fase);
	v_aceso = pow(max(onda, 0.0), dureza) * INSTANCE_CUSTOM.w;

	// Billboard: o quad sempre de frente, como o PS1 fazia com sprite.
	//
	// Pela MODELVIEW_MATRIX, e nao escrevendo em VERTEX. A primeira versao
	// fazia `VERTEX = (MODELVIEW_MATRIX * ...)` e depois o motor multiplicava
	// pela MODELVIEW de novo: o enxame inteiro ia parar num lugar que nao
	// existe, e a captura saia sem vaga-lume nenhum sem erro nenhum no log.
	mat4 m = MODEL_MATRIX;
	m[3].xyz += anda;
	// Trocar a MODELVIEW joga fora a base da instancia, e com ela a escala. Quem
	// quiser bicho menor tem de multiplicar o VERTEX na mao — senao a escala
	// posta em `set_instance_transform` some sem aviso e os de perto viram bolas
	// brancas de doze pixels.
	float esc = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], m[3]);
	// O ponto encolhe quando apaga em vez de so escurecer. E o que faz o olho
	// ler "acendeu" e nao "clareou".
	VERTEX *= esc * mix(0.35, 1.0, v_aceso);
}

void fragment() {
	// Disco, nao quadrado. Quadrado de 2 px em blend_add le como poeira de
	// sensor.
	float r = length(UV - vec2(0.5)) * 2.0;
	float disco = 1.0 - smoothstep(0.55, 1.0, r);

	int ix = int(mod(FRAGCOORD.x, 4.0));
	int iy = int(mod(FRAGCOORD.y, 4.0));
	float limiar = BAYER[iy * 4 + ix] / 16.0;

	float forca = v_aceso * disco * densidade;
	if (forca < limiar * 0.35) {
		discard;
	}
	ALBEDO = cor.rgb * brilho * forca;
	ALPHA = 1.0;
}
