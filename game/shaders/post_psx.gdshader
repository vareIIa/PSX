// Pos-processamento PSX — dither de 15 bits, grao, aberracao cromatica, scanline,
// vinheta e grade de cor. Contrato em docs/ART-BIBLE.md secao 9.
//
// A ordem dos passos e fixa e importa. Grao antes do corte de bits some dentro da
// quantizacao; dither depois do upscale vira moire. Nao reordene.

shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;

// ART-BIBLE secao 2
uniform vec2 internal_res = vec2(480.0, 270.0);

// ART-BIBLE secao 5 — 32 niveis por canal = 5 bits = os 15 bits do framebuffer
uniform float color_levels : hint_range(2.0, 256.0) = 32.0;
uniform bool use_dither = true;

// ART-BIBLE secao 9 — intensidades padrao
uniform float chromatic : hint_range(0.0, 2.0) = 0.6;
uniform float grain : hint_range(0.0, 0.2) = 0.08;
uniform float scanline : hint_range(0.0, 0.5) = 0.12;
uniform float vignette : hint_range(0.0, 1.0) = 0.45;

// Grade de cor sem asset de LUT: saturacao mais um tint multiplicativo.
uniform float saturation : hint_range(0.0, 2.0) = 0.88;
uniform vec4 grade_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

const float BAYER[16] = float[](
	 0.0,  8.0,  2.0, 10.0,
	12.0,  4.0, 14.0,  6.0,
	 3.0, 11.0,  1.0,  9.0,
	15.0,  7.0, 13.0,  5.0
);

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 off = uv - vec2(0.5);
	vec2 px = uv * internal_res;

	// 1. Aberracao cromatica, crescendo radialmente. A referencia de inventario
	//    mostra o efeito isolado: nulo no centro, visivel na borda.
	vec3 col;
	if (chromatic > 0.0) {
		vec2 shift = off * (chromatic / internal_res.x);
		col.r = texture(screen_tex, uv + shift).r;
		col.g = texture(screen_tex, uv).g;
		col.b = texture(screen_tex, uv - shift).b;
	} else {
		col = texture(screen_tex, uv).rgb;
	}

	// 2. Grade de cor
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, saturation) * grade_tint.rgb;

	// 3. Dither ordenado e corte para 15 bits. E o passo que produz o xadrez
	//    visivel nos gradientes da referencia do quarto ambar.
	if (use_dither) {
		int idx = int(mod(px.y, 4.0)) * 4 + int(mod(px.x, 4.0));
		col += (BAYER[idx] / 16.0 - 0.5) / color_levels;
	}
	col = floor(clamp(col, 0.0, 1.0) * color_levels) / color_levels;

	// 4. Grao animado. Depois do corte, senao a quantizacao o engole.
	if (grain > 0.0) {
		col += (hash12(px + fract(TIME) * 137.0) - 0.5) * grain;
	}

	// 5. Scanline em linha alternada
	if (scanline > 0.0) {
		col *= 1.0 - scanline * step(1.0, mod(px.y, 2.0));
	}

	// 6. Vinheta
	if (vignette > 0.0) {
		col *= smoothstep(0.95, 0.95 - vignette, length(off) * 1.35);
	}

	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
