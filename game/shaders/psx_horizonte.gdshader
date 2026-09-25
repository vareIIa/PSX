// O anel distante da cidade (Horizonte, passo 2). Uma malha por celula,
// feita da grade 2,5D dos chunks dela (HorizonteMalha).
//
// - A cor e chapada (varying flat): o chao da celula e uma grade de vertices
//   compartilhados, e cada ponto da planta pinta o triangulo pelo vertice que
//   o provoca (HorizonteMalha.provoca_no_fim).
// - Some onde o chunk de verdade ja desenha: a mascara tem um texel por chunk
//   em volta do jogador (0 = so o horizonte, 1 = o ChunkManager desenha ali,
//   no meio = o chunk acabou de chegar e o horizonte sai em pontilhado). O
//   teste e por pixel, no ponto do mundo um pouco para dentro da superficie:
//   parede em cima da divisa de dois chunks e do chunk do predio dela.
// - Parede de predio ganha janela na grade da cidade (modulo de 3 m, andar de
//   3 m, e um vao em cada tres sem janela: casa mineira nao e fachada de
//   escritorio), medida no mundo: a mesma parede em dois niveis da arvore tem
//   a mesma janela. O padrao e filtrado pela derivada da tela: quando a janela
//   fica menor que o pixel, sobra a media, sem moire a 4K.
// - A noite, janela acesa por sorteio, em tres luzes (lampada amarela, branca
//   e o azul da televisao); menor que o pixel, o valor esperado.
// - Poste (COLOR.a = 0,25): ponto de sodio virado para a camera, so a noite.
//   COLOR.r diz quantos postes o ponto representa (nivel de longe amostra um
//   chunk em cada quadrado).
// - O ar e o do Environment (FogController: nevoa exponencial no MODERNO), o
//   mesmo que cobre os chunks de verdade: perto e longe casam na borda.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_back, shadows_disabled;

uniform sampler2D mascara : filter_nearest;
uniform vec2 mascara_origem = vec2(0.0);
uniform float mascara_lado = 0.0;

uniform float noite = 0.0;
uniform float janelas_acesas = 0.0;
uniform vec3 cor_janela : source_color = vec3(1.0, 0.72, 0.42);
uniform vec3 cor_janela_branca : source_color = vec3(1.0, 0.93, 0.8);
uniform vec3 cor_tv : source_color = vec3(0.55, 0.68, 1.0);
uniform float energia_janela = 2.0;
// Vidro de dia: escuro, um pouco do ceu.
uniform vec3 cor_vidro : source_color = vec3(0.1, 0.12, 0.15);
uniform vec3 cor_poste : source_color = vec3(1.0, 0.72, 0.39);
uniform float energia_poste = 6.0;

varying flat vec4 v_cor;
varying float v_altura;

const float CHUNK = 32.0;
const vec2 CELULA = vec2(3.0, 3.0);
// Janela: 1,1 m de largura no meio do modulo, de 1,0 a 2,4 m do andar.
const vec2 JANELA_X = vec2(0.317, 0.683);
const vec2 JANELA_Y = vec2(0.333, 0.8);
// Fracao dos vaos com janela.
const float COM_JANELA = 0.68;
// Quanto o ponto da mascara entra na superficie (m).
const float PARA_DENTRO = 0.1;

void vertex() {
	v_cor = COLOR;
	v_altura = UV.y;
	if (COLOR.a > 0.2 && COLOR.a < 0.3) {
		// Poste: os tres vertices estao no ponto da lampada; o canto sai em
		// UV no plano da camera. De dia some.
		if (noite < 0.5) {
			VERTEX = vec3(0.0);
		} else {
			vec3 mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
			float d = distance(mundo, CAMERA_POSITION_WORLD);
			float tam = max(0.7, d * 0.0014) * (1.0 + COLOR.r * 7.0);
			VERTEX += (INV_VIEW_MATRIX[0].xyz * UV.x + INV_VIEW_MATRIX[1].xyz * UV.y) * tam;
		}
	}
}

// Integral de um trem de pulsos (1 entre a e b, em cada periodo de 1).
float integral(float x, float a, float b) {
	return floor(x) * (b - a) + clamp(fract(x), a, b) - a;
}

// O pulso filtrado por uma caixa de largura w (em periodos).
float pulso(float x, float w, float a, float b) {
	w = max(w, 1e-4);
	return (integral(x + 0.5 * w, a, b) - integral(x - 0.5 * w, a, b)) / w;
}

float sorteio(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

// Limiar de pontilhado 4 x 4 (Bayer), em (0, 1).
float bayer4(vec2 p) {
	ivec2 i = ivec2(mod(floor(p), 4.0));
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[i.y * 4 + i.x]) + 0.5) / 16.0;
}

void fragment() {
	float classe = v_cor.a;
	// Telhado e parede: a normal chapada do triangulo, da derivada da tela,
	// virada para a camera (a face de tras nao desenha). Chao e copa: a do
	// vertice, suave.
	vec3 n = NORMAL;
	bool suave = (classe > 0.1 && classe < 0.15) || (classe > 0.45 && classe < 0.55);
	if (!suave) {
		n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
		if (dot(n, VERTEX) > 0.0) {
			n = -n;
		}
		NORMAL = n;
	}
	vec3 n_mundo = (INV_VIEW_MATRIX * vec4(n, 0.0)).xyz;
	vec3 mundo = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 amostra = mundo - vec3(n_mundo.x, 0.0, n_mundo.z) * PARA_DENTRO;
	vec2 t = floor(amostra.xz / CHUNK) - mascara_origem;
	if (t.x >= 0.0 && t.y >= 0.0 && t.x < mascara_lado && t.y < mascara_lado) {
		float m = texelFetch(mascara, ivec2(t), 0).r;
		if (m > bayer4(FRAGCOORD.xy)) {
			discard;
		}
	}
	vec3 cor = v_cor.rgb;
	vec3 luz = vec3(0.0);
	if (classe > 0.2 && classe < 0.3) {
		vec2 uv = UV;
		float r = length(uv);
		if (r > 1.0) {
			discard;
		}
		cor = vec3(0.0);
		luz = cor_poste * energia_poste * (1.0 - r * r) * noite;
	} else if (classe > 0.9) {
		// Metros ao longo da parede, no mundo, e metros acima do chao.
		vec2 ao_longo = normalize(vec2(-n_mundo.z, n_mundo.x));
		vec2 g = vec2(dot(amostra.xz, ao_longo), v_altura) / CELULA;
		vec2 w = fwidth(g);
		vec2 cel = floor(g);
		// Paredes paralelas nao repetem o sorteio: entra o plano da parede.
		float semente = floor(dot(amostra.xz, normalize(n_mundo.xz)) * 0.5) * 17.0;
		// Menor que o pixel, o sorteio por vao vira ruido: vale a media.
		float longe = smoothstep(0.35, 0.9, max(w.x, w.y));
		float tem = mix(step(sorteio(vec3(cel, semente + 7.0)), COM_JANELA), COM_JANELA, longe);
		float j = pulso(g.x, w.x, JANELA_X.x, JANELA_X.y) * pulso(g.y, w.y, JANELA_Y.x, JANELA_Y.y) * tem;
		cor = mix(cor, cor_vidro, j);
		if (noite > 0.0) {
			float s = sorteio(vec3(cel, semente));
			float acesa = mix(step(s, janelas_acesas), janelas_acesas, longe);
			// A cor da luz: amarela, branca ou tv, pelo mesmo sorteio.
			float qual = sorteio(vec3(cel, semente + 3.0));
			vec3 tom = qual < 0.6 ? cor_janela : (qual < 0.85 ? cor_janela_branca : cor_tv);
			tom = mix(tom, cor_janela * 0.6 + cor_janela_branca * 0.25 + cor_tv * 0.15, longe);
			luz = tom * energia_janela * j * acesa * noite;
		}
	}
	ALBEDO = cor;
	EMISSION = luz;
}
