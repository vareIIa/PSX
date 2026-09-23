// Vidro de vitrine: a frente da loja de conveniencia que existe na rua.
//
// PLANO_MERCADO_AAA, F1 (§3.4 e §9.2). O vidro de antes era um painel branco
// emissivo, porque atras dele nao havia loja nenhuma — ela vivia dois mil metros
// acima da cidade. Agora ha: pela vitrine se veem as gondolas, a fila no caixa
// e o atendente. Este shader e o que fica entre o jogador e isso.
//
// Tres estados, e nenhum e pintado a mao
// --------------------------------------
//   PERTO, de fora   quase transparente. O reflexo e a rua escura, e ele so
//                    aparece de esguelha (Fresnel): de frente se ve a loja, de
//                    lado se ve o vidro. E o que qualquer vitrine faz a noite.
//   PERTO, de dentro de noite o vidro devolve a propria loja acesa. Por cima da
//                    rua escura aparece um veu claro, mais forte de lado: e o
//                    que diz ao jogador, sem uma palavra, que ele esta num
//                    aquario iluminado e que la fora nao se ve quem olha.
//   LONGE            opaco e aceso, a mancha branca na nevoa. Nao e so o look da
//                    referencia: e o que esconde a loja que ainda nao foi
//                    montada (LoteNoMundo.preaquecer). A montagem comeca a 40 m e
//                    o vidro so abre de 36 para 28.
//
// O lado vem da face: a placa e desenhada virada para a RUA (KitMercado
// .vitrine_loja), entao FRONT_FACING e "quem olha esta na calcada". A normal ja
// chega virada para quem olha (cull_disabled), e o Fresnel serve aos dois lados.
//
// Unshaded e sem textura: nao ha UV afim a cancelar, e a luz que importa no
// vidro e a que ele reflete, nao a que ele recebe. O tremor de vertice fica.
shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec2 snap_resolution = vec2(240.0, 135.0);
uniform bool use_snap = true;
global uniform bool psx_snap;
global uniform float psx_snap_escala;
global uniform float psx_chuva;

// --- perto --------------------------------------------------------------------
/// A cor do proprio vidro temperado, vista de frente: um verde-agua palido.
uniform vec4 tinta_vidro : source_color = vec4(0.70, 0.80, 0.80, 1.0);
/// Quanto o vidro cobre olhando de frente, de fora. Pouco: e uma vitrine.
uniform float opacidade_frente : hint_range(0.0, 1.0) = 0.08;
/// O que o vidro reflete de fora: a rua a noite.
uniform vec4 reflexo_rua : source_color = vec4(0.13, 0.15, 0.17, 1.0);
uniform float reflexo_rua_forca : hint_range(0.0, 1.0) = 0.62;
/// O que o vidro reflete de dentro: a loja.
uniform vec4 reflexo_loja : source_color = vec4(0.80, 0.86, 0.86, 1.0);
uniform float reflexo_loja_base : hint_range(0.0, 1.0) = 0.16;
uniform float reflexo_loja_forca : hint_range(0.0, 1.0) = 0.5;

// --- longe --------------------------------------------------------------------
uniform vec4 cor_acesa : source_color = vec4(0.86, 0.93, 0.96, 1.0);
uniform float energia_acesa : hint_range(0.0, 4.0) = 1.25;
/// Onde o vidro comeca e termina de fechar, em metros da camera.
uniform float perto = 28.0;
uniform float longe = 36.0;

varying float dist_camera;


float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}


void vertex() {
	vec4 vista = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	dist_camera = length(vista.xyz);
	vec4 clip = PROJECTION_MATRIX * vista;
	if (use_snap && psx_snap && clip.w > 0.0) {
		vec3 ndc = clip.xyz / clip.w;
		vec2 grade = snap_resolution * psx_snap_escala;
		ndc.xy = floor(ndc.xy * grade) / grade;
		clip = vec4(ndc * clip.w, clip.w);
	}
	POSITION = clip;
}


void fragment() {
	float cosv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - cosv, 4.0);

	vec3 cor;
	float alfa;
	if (FRONT_FACING) {
		// De fora. Poeira na metade de baixo, que e onde a rua bate: a vitrine
		// de loja nunca esta limpa ate o chao.
		float poeira = smoothstep(0.55, 1.0, UV.y) * 0.05;
		alfa = opacidade_frente + poeira + fresnel * reflexo_rua_forca;
		// A cor do vertice tinge o vidro: branca na vitrine, ambar na estufa de
		// salgados, azulada na tampa do freezer (KitMercado).
		cor = mix(tinta_vidro.rgb * COLOR.rgb * 0.55, reflexo_rua.rgb,
			clamp(fresnel * 1.6, 0.0, 1.0));
		// Chovendo, o vidro de fora pega agua: um pouco mais de veu, frio.
		alfa += psx_chuva * 0.06;
		cor = mix(cor, reflexo_rua.rgb * 1.3, psx_chuva * 0.25);

		// Longe, fecha e acende. A faixa e larga de proposito: sem ela a loja
		// aparece de uma vez no meio do passo.
		float t = smoothstep(perto, longe, dist_camera);
		// O granulado sorteado por celula de tela quebra a borda da transicao em
		// pontos, como o dither do resto do jogo, em vez de um degrau liso.
		float grao = hash21(floor(FRAGCOORD.xy * 0.5)) * 0.18 - 0.09;
		t = clamp(t + grao * step(0.02, t) * step(t, 0.98), 0.0, 1.0);
		cor = mix(cor, cor_acesa.rgb * energia_acesa, t);
		alfa = mix(alfa, 1.0, t);
	} else {
		// De dentro: a loja volta do vidro, e mais de lado que de frente.
		alfa = reflexo_loja_base + fresnel * reflexo_loja_forca;
		cor = reflexo_loja.rgb * mix(vec3(1.0), COLOR.rgb, 0.6);
	}
	ALBEDO = cor;
	ALPHA = clamp(alfa, 0.0, 1.0);
}
