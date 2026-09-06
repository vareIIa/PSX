// Superficie PSX — vertex snapping, UV afim e luz por vertice.
// Contrato em docs/ART-BIBLE.md secoes 3, 4 e 7. Guia em .claude/skills/psx-render.
//
// O dither NAO mora aqui. fragment() roda antes da luz ser aplicada, entao o padrao
// sairia multiplicado pela iluminacao. Ele vive em post_psx.gdshader, que e onde o
// PS1 o aplicava: na escrita do framebuffer.

shader_type spatial;
render_mode vertex_lighting, specular_disabled, shadows_disabled, diffuse_lambert, cull_back;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec2 uv_tile = vec2(1.0, 1.0);

// ART-BIBLE secao 3 — metade da resolucao interna de 480x270
uniform vec2 snap_resolution = vec2(240.0, 135.0);
uniform bool use_snap = true;

// ART-BIBLE secao 4 — desligar em malha muito subdividida ou colada na camera
uniform bool use_affine = true;

uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.0;

varying vec2 uv_affine;
varying float w_affine;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);

	// Snap so vale a pena a frente do plano proximo. Atras dele a divisao por w
	// inverte o sinal e a geometria explode em NaN.
	if (use_snap && clip.w > 0.0) {
		vec3 ndc = clip.xyz / clip.w;
		ndc.xy = floor(ndc.xy * snap_resolution) / snap_resolution;
		clip = vec4(ndc * clip.w, clip.w);
	}
	POSITION = clip;

	// Pre-multiplicar por w cancela a correcao de perspectiva do rasterizador.
	// O hardware entrega toda varying como linear(V/w) / linear(1/w); passando
	// V = UV*w o numerador vira linear(UV), e dividir pela varying w reconstroi
	// interpolacao linear em espaco de tela, que e o que o PS1 fazia por nao ter
	// divisor por pixel.
	w_affine = clip.w;
	uv_affine = UV * uv_tile * clip.w;
}

void fragment() {
	vec2 uv = use_affine ? (uv_affine / w_affine) : (UV * uv_tile);
	vec4 texel = texture(albedo_tex, uv) * tint;

	// COLOR carrega o tint por vertice. E o que multiplica variantes de material
	// sem multiplicar arquivos de textura. Ver skill psx-assets.
	ALBEDO = texel.rgb * COLOR.rgb;

	if (alpha_cutoff > 0.0) {
		ALPHA = texel.a * COLOR.a;
		ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;
	}

	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}
