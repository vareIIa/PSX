// Overlay RE7 — world behind menu (SPEC_VISUAL_RE7 s4 + EPICO Onda 1).
// Mild DoF blur, sat -0.4, edge CA, grain, vignette, scrim, lens dirt.
// No heavy CRT scanlines, no dither/quantize, no iOS frosted glass.
shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D dirt_tex : hint_default_white, filter_linear, repeat_enable;

uniform float blur_px : hint_range(0.0, 4.0) = 1.15;
uniform float saturation : hint_range(0.0, 2.0) = 0.6;
uniform float ca_px : hint_range(0.0, 2.0) = 0.6;
uniform float grain_amt : hint_range(0.0, 0.2) = 0.045;
uniform float vignette_amt : hint_range(0.0, 1.0) = 0.30;
uniform float scrim_amt : hint_range(0.0, 1.0) = 0.62;
uniform vec4 scrim_color : source_color = vec4(0.02745, 0.03137, 0.03529, 1.0);
uniform float dirt_amt : hint_range(0.0, 1.0) = 0.20;
uniform float warp_amt : hint_range(0.0, 0.01) = 0.0015;
uniform float warp_hz : hint_range(0.0, 0.2) = 0.06;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;
uniform vec2 internal_res = vec2(480.0, 270.0);

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 sample_blur(vec2 uv, float px) {
	vec2 texel = px / internal_res;
	vec3 acc = texture(screen_texture, uv).rgb * 0.227027;
	acc += texture(screen_texture, uv + vec2(texel.x * 1.384615, 0.0)).rgb * 0.316216;
	acc += texture(screen_texture, uv - vec2(texel.x * 1.384615, 0.0)).rgb * 0.316216;
	acc += texture(screen_texture, uv + vec2(0.0, texel.y * 1.384615)).rgb * 0.070270;
	acc += texture(screen_texture, uv - vec2(0.0, texel.y * 1.384615)).rgb * 0.070270;
	return acc;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 off = uv - vec2(0.5);
	float radial = length(off) * 2.0;

	float breath = sin(TIME * 6.2831853 * warp_hz) * warp_amt;
	uv += off * breath;

	float ca = ca_px * smoothstep(0.25, 1.0, radial);
	vec2 shift = off * (ca / internal_res.x);
	vec3 col;
	if (blur_px > 0.001) {
		col.r = sample_blur(uv + shift, blur_px).r;
		col.g = sample_blur(uv, blur_px).g;
		col.b = sample_blur(uv - shift, blur_px).b;
	} else {
		col.r = texture(screen_texture, uv + shift).r;
		col.g = texture(screen_texture, uv).g;
		col.b = texture(screen_texture, uv - shift).b;
	}

	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, saturation);

	col = mix(col, scrim_color.rgb, scrim_amt);

	float n = hash12(floor(uv * internal_res) + vec2(17.0, 9.0));
	float dirt_noise = smoothstep(0.72, 0.95, n) * 0.55
		+ smoothstep(0.55, 0.85, hash12(uv * 6.0 + 2.3)) * 0.25;
	vec3 dirt_sample = texture(dirt_tex, uv * 2.3).rgb;
	float dirt_mask = dirt_noise * (0.65 + 0.35 * dirt_sample.r);
	dirt_mask *= mix(0.35, 1.0, smoothstep(0.35, 1.15, radial));
	col *= 1.0 - dirt_mask * dirt_amt;

	float g = (hash12(uv * internal_res + fract(TIME) * 64.0) - 0.5) * 2.0;
	col += g * grain_amt;

	float vig = smoothstep(0.55, 1.35, radial);
	col *= 1.0 - vig * vignette_amt;

	COLOR = vec4(col, intensity);
}