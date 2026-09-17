// Overlay CRT da abertura e do menu de jogo. Grao animado, scanlines, vinheta
// e hotspot central — look da referencia PS2 survival-horror.
// scene_mix=0: base sintetica. scene_mix>0: mistura a cena/placa ja desenhada.
shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float grain : hint_range(0.0, 1.0) = 0.55;
uniform float scanline : hint_range(0.0, 1.0) = 0.42;
uniform float vignette : hint_range(0.0, 1.0) = 0.82;
uniform float glow : hint_range(0.0, 1.0) = 0.35;
uniform float bw : hint_range(0.0, 1.0) = 0.0;
uniform float burst : hint_range(0.0, 1.0) = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform float scene_mix : hint_range(0.0, 1.0) = 0.0;
uniform float soft_blur : hint_range(0.0, 1.0) = 0.0;

// A travessia do vidro. 0 = tubo parado; 1 = dentro dele.
//
// O menu inicial e uma televisao chiando, e apertar START tem de ser ENTRAR
// nela — nao cortar para outro lugar. Tres coisas acontecem juntas enquanto
// este valor sobe e volta, e e o conjunto que faz o gesto ler como travessia:
//
//   1. o vidro EMPENA mais (o barril dobra), como quem chega perto demais de um
//      tubo curvo;
//   2. a imagem AMPLIA a partir do centro — a tela vem para cima do rosto em
//      vez de o rosto ir ate ela;
//   3. o brilho do fosforo estoura no meio, que e o clarao do instante em que se
//      atravessa a superficie.
//
// Sobe e desce numa curva so (ver `Menu._avancar_lente`): passada a travessia,
// o valor volta a zero e o que fica na tela e o jogo, nao o tubo.
uniform float plunge : hint_range(0.0, 1.0) = 0.0;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec2 barrel(vec2 uv, float amt) {
	vec2 off = uv - 0.5;
	float r2 = dot(off, off);
	return 0.5 + off * (1.0 + amt * r2);
}

void fragment() {
	vec2 uv = UV;
	vec2 suv = barrel(SCREEN_UV, 0.08 + burst * 0.04 + plunge * 0.42);
	// Amplia a partir do centro: 1,0 -> 1,30 de escala no auge da travessia. Mais
	// que isso e a borda do quadro entra na tela e denuncia que o que se ve e uma
	// textura, e nao o fundo do tubo.
	suv = vec2(0.5) + (suv - vec2(0.5)) / (1.0 + plunge * 0.30);
	vec2 off = uv - vec2(0.5);
	vec2 px = floor(uv * vec2(320.0, 180.0));

	float n = hash12(px + vec2(floor(TIME * 24.0), floor(TIME * 17.0)));
	float n2 = hash12(px * 1.7 + vec2(floor(TIME * 31.0), 3.1));
	float n3 = hash12(px * 0.55 + vec2(floor(TIME * 9.0), 11.0));
	float static_v = mix(mix(n, n2, 0.45), n3, 0.25);

	float scan = 1.0 - scanline * step(0.48, fract(uv.y * 155.0 + TIME * 0.015));
	float scan2 = 1.0 - scanline * 0.35 * step(0.5, fract(uv.y * 77.0));
	scan *= scan2;

	float vig = smoothstep(1.08, 1.08 - vignette * 1.05, length(off * vec2(1.05, 1.15)) * 1.55);
	float spot = exp(-dot(off * vec2(1.05, 1.25), off * vec2(1.05, 1.25)) * 3.4) * glow;
	// O estouro de fosforo da travessia. Concentrico com o `spot` de sempre e
	// mais fechado que ele: e um clarao no miolo, e nao a tela inteira clareando.
	float flash = exp(-dot(off, off) * 5.0) * plunge;

	vec3 base = vec3(0.03, 0.032, 0.036) + vec3(spot * 0.72, spot * 0.68, spot * 0.62);
	// A chuva do BURST nao passa pelo `grain`, e isso e conserto e nao ajuste.
	//
	// As duas linhas multiplicavam `static_v * grain * (… + burst * …)`: a
	// estatica do evento era refem do grao de repouso. No preset MODERNO, com
	// grao 0,10, o pico da travessia entregava 0,12 de ruido — ou seja, o
	// momento em que o jogador atravessa o vidro nao tinha chuvisco nenhum, e o
	// unico jeito de ver o efeito era escolher PS1 STYLE. Grao e ambiente,
	// burst e acontecimento; somar um ao outro em vez de multiplicar mantem os
	// dois independentes.
	base += vec3(static_v * (grain * 0.62 + burst * 1.2));
	base += vec3(flash * 0.7);
	base *= scan;
	base *= mix(1.0, vig, 0.94);

	vec3 scene = textureLod(screen_texture, suv, 0.0).rgb;
	if (soft_blur > 0.001) {
		vec2 pxo = vec2(1.2, 1.2) / vec2(480.0, 270.0) * soft_blur;
		scene = (
			scene
			+ textureLod(screen_texture, suv + vec2(pxo.x, 0.0), 0.0).rgb
			+ textureLod(screen_texture, suv - vec2(pxo.x, 0.0), 0.0).rgb
			+ textureLod(screen_texture, suv + vec2(0.0, pxo.y), 0.0).rgb
			+ textureLod(screen_texture, suv - vec2(0.0, pxo.y), 0.0).rgb
		) * 0.2;
	}
	float luma_s = dot(scene, vec3(0.299, 0.587, 0.114));
	scene = mix(scene, vec3(luma_s), bw * 0.85);
	scene += vec3(spot * 0.22);
	scene *= scan;
	scene *= mix(1.0, vig, 0.88);
	scene += vec3(static_v * (grain * 0.22 + burst * 0.85));
	scene += vec3(flash * 0.55);

	vec3 outc = mix(base, scene, clamp(scene_mix, 0.0, 1.0));
	float luma = dot(outc, vec3(0.299, 0.587, 0.114));
	outc = mix(outc, vec3(luma), bw * (1.0 - scene_mix * 0.4));

	float a = opacity * mix(0.94, 1.0, burst);
	COLOR = vec4(clamp(outc, 0.0, 1.0), a);
}
