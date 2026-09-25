// O assador de impostores (tests/assar_impostores.gd): desenha a arvore de
// verdade, sem luz, numa camera ortografica, para virar quadro do atlas.
//
// `modo` 0 = cor (a textura HD vezes a tinta e a oclusao do vertice, como o
// psx_folha_pixel faz no jogo); 1 = normal no espaco da arvore, codificada em
// cor. O viewport converte linear -> sRGB na saida; a normal entra ja
// "decodificada" para sair no PNG exatamente como n * 0,5 + 0,5.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform sampler2D textura : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 uv_tile = vec2(1.0, 1.0);
uniform float corte = 0.0;
uniform float alfa_por_mip = 0.22;
uniform float fade_perfil = 0.0;
// Expoente da oclusao pintada no vertice (0,7 na folha do MODERNO, 1 no resto).
uniform float ao_vertice = 1.0;
uniform int modo = 0;

vec3 srgb_para_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

void fragment() {
	vec2 uv = UV * uv_tile;
	vec4 t = texture(textura, uv) * tint;
	if (corte > 0.0) {
		float a = t.a;
		vec2 tam = vec2(textureSize(textura, 0));
		vec2 dx = dFdx(uv * tam);
		vec2 dy = dFdy(uv * tam);
		float mip = max(0.0, 0.5 * log2(max(dot(dx, dx), dot(dy, dy))));
		a *= 1.0 + mip * alfa_por_mip;
		if (fade_perfil > 0.0) {
			// Camera ortografica: o olho olha sempre ao longo de -Z da vista.
			vec3 nf = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
			a *= mix(1.0, smoothstep(0.12, 0.55, abs(nf.z)), fade_perfil);
		}
		if (a < corte) {
			discard;
		}
	}
	if (modo == 0) {
		ALBEDO = t.rgb * pow(max(COLOR.rgb, vec3(0.0)), vec3(ao_vertice));
	} else {
		vec3 n = normalize((INV_VIEW_MATRIX * vec4(normalize(NORMAL), 0.0)).xyz);
		ALBEDO = srgb_para_linear(clamp(n * 0.5 + 0.5, 0.0, 1.0));
	}
}
