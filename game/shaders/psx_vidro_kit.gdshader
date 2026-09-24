// Vidro do kit da estufa: o pote de erva e o saquinho zip (KitEstufa).
//
// O psx_surface so sabe recortar (alpha scissor), e vidro recortado ou some
// inteiro ou vira chapa: o pote antigo era um cubo de celula de vidro com uma
// caixa verde dentro, e ninguem lia aquilo como pote. Vidro de verdade e quase
// invisivel de frente e quase espelho de raspao (Fresnel) — e a BORDA clara do
// cilindro, mais a faixa de reflexo de cima a baixo, que diz "pote de vidro" a
// um metro. A erva dentro aparece porque o miolo deixa passar.
//
// Um arquivo so para os dois estilos. O EstiloVisual so troca o shader de quem
// usa psx_surface, e este nao usa: o que muda entre PS1 STYLE e MODERNO e lido
// dos globais que ele ja escreve —
//   psx_snap / psx_snap_escala   o tremor de vertice, igual ao psx_surface
//   psx_facho_suave              verdadeiro no MODERNO: brilho especular das
//                                lampadas. No PS1 fica so a faixa desenhada, que
//                                e o que o console fazia (reflexo pintado, sem
//                                luz por pixel).
//
// A cor de vertice e o tom do vidro (rgb) e quanto ele fecha (a): o fundo grosso
// do pote vem com alfa maior, e o plastico do saquinho com menor.
//
// Ordem de desenho: a face de DENTRO (a parede de tras, vista pelo lado de
// dentro) vem antes na malha, e o motor desenha na ordem do indice dentro de uma
// superficie. Com mistura por alfa essa ordem e a que da certo.

shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_never, diffuse_lambert, specular_schlick_ggx;

uniform vec4 tint : source_color = vec4(0.86, 0.94, 0.9, 1.0);
uniform float alfa_frente : hint_range(0.0, 1.0) = 0.08;
uniform float alfa_borda : hint_range(0.0, 1.0) = 0.62;
uniform float faixa_forca : hint_range(0.0, 2.0) = 0.55;
uniform float rugosidade : hint_range(0.0, 1.0) = 0.08;

uniform vec2 snap_resolution = vec2(240.0, 135.0);
uniform bool use_snap = true;

global uniform bool psx_snap;
global uniform float psx_snap_escala;
global uniform bool psx_facho_suave;

void vertex() {
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
	vec3 n = normalize(NORMAL);
	float de_frente = clamp(dot(n, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - de_frente, 3.0);

	// A faixa de reflexo: a janela da sala (ou a lampada) refletida num
	// cilindro sai como uma tira vertical fina, um pouco fora do centro. Pintada
	// em espaco de vista, ela acompanha o olho como o reflexo de verdade.
	float faixa = smoothstep(0.10, 0.0, abs(n.x - 0.42)) * step(0.0, n.z)
		+ 0.45 * smoothstep(0.06, 0.0, abs(n.x + 0.62)) * step(0.0, n.z);

	float alfa = mix(alfa_frente, alfa_borda, fresnel) * mix(0.6, 1.6, COLOR.a);
	alfa = clamp(alfa + faixa * faixa_forca * 0.5, 0.0, 0.95);

	ALBEDO = tint.rgb * COLOR.rgb;
	ALPHA = alfa;
	EMISSION = vec3(1.0, 0.99, 0.96) * faixa * faixa_forca * 0.6;
	ROUGHNESS = rugosidade;
	METALLIC = 0.0;
	SPECULAR = psx_facho_suave ? 0.7 : 0.0;
}
