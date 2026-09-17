// Janela do MODERNO: vidro, esquadria e o comodo atras (criterio A34 do
// PLANO_AAA_4K).
//
// O que havia antes
// -----------------
// A janela era um retangulo com a textura de OUTRA superficie: a apagada usava
// `metal.png` e a acesa, `calcada_ladrilho`. Em 256 px isso passava; com o
// conjunto HD de 1024 px do MODERNO, a janela do predio virou chapa de metal
// suja e a acesa, piso de calcada. Foi o que o usuario viu de dentro da viela.
//
// As tres coisas que fazem uma janela
// -----------------------------------
//   1. **Vidro**: escuro por dentro e ESPELHO na borda. O reflexo nao e pintado:
//      e rugosidade baixa mais Fresnel, entao ele mostra o ceu e o predio da
//      frente que o motor ja tem (sonda de reflexo da Fase 4).
//   2. **Esquadria**: caixilho e montante. Vem da UV2, que vai de 0 a 1 dentro
//      da peca, seja ela de 85 cm ou de 2,1 m (ver `PSXMesh.dados_vazios`). A
//      UV de sempre e ancorada em METROS e nao serve para isso.
//   3. **Comodo**: o que se ve atras do vidro. Uma caixa virtual por SALA, em
//      espaco de mundo — nao uma por janela. Duas janelas do mesmo andar olham
//      para dentro da mesma sala, cada uma do seu angulo, que e o que faz a
//      ilusao sobreviver ao jogador andando na calcada.
//
// O PS1 STYLE nao usa este arquivo: la o material volta para `psx_surface` com
// a textura de antes, e a build de 1999 continua igual (contrato A2).

shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

// Mesma familia de uniforms do psx_surface, para a troca de estilo preservar o
// que ja estava no material.
uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 uv_tile = vec2(1.0, 1.0);
uniform bool use_snap = true;
uniform vec2 snap_resolution = vec2(240.0, 135.0);
global uniform bool psx_snap;
global uniform float psx_snap_escala;
global uniform float psx_molhado;
global uniform float psx_chuva;

// --- vidro --------------------------------------------------------------------
uniform vec4 cor_vidro : source_color = vec4(0.055, 0.065, 0.075, 1.0);
uniform float rugosidade_vidro : hint_range(0.0, 0.5) = 0.06;
uniform float brilho_vidro : hint_range(0.0, 1.0) = 0.6;

// --- esquadria ----------------------------------------------------------------
uniform vec4 cor_esquadria : source_color = vec4(0.30, 0.29, 0.27, 1.0);
/// Largura do caixilho e do montante, em metros.
uniform float caixilho_m : hint_range(0.01, 0.2) = 0.055;
uniform float montante_m : hint_range(0.0, 0.2) = 0.035;
/// Acima desta altura a janela ganha travessa e bandeira.
uniform float altura_bandeira : hint_range(0.0, 4.0) = 1.7;
/// Tamanho da peca quando as derivadas nao servem (vertice unico no quadro).
uniform vec2 tamanho_padrao = vec2(1.1, 1.3);

// --- comodo -------------------------------------------------------------------
uniform bool acesa = false;
uniform vec4 cor_parede_interna : source_color = vec4(0.34, 0.31, 0.28, 1.0);
uniform vec4 cor_chao_interno : source_color = vec4(0.18, 0.13, 0.10, 1.0);
uniform vec4 cor_teto_interno : source_color = vec4(0.40, 0.38, 0.35, 1.0);
uniform vec4 cor_luz : source_color = vec4(1.0, 0.76, 0.45, 1.0);
uniform vec4 cor_cortina : source_color = vec4(0.62, 0.58, 0.50, 1.0);
/// Profundidade da sala virtual, em metros.
uniform float sala_prof : hint_range(0.5, 8.0) = 3.2;
/// Largura da sala ao longo da parede, e altura do andar. Os dois numeros sao os
/// do `KitModular`: sala de 3,2 m e andar de 3,0 m.
uniform float sala_larg : hint_range(1.0, 8.0) = 3.2;
uniform float andar_alt : hint_range(2.0, 6.0) = 3.0;
uniform float cortina_prob : hint_range(0.0, 1.0) = 0.45;
uniform float emissao_acesa : hint_range(0.0, 8.0) = 0.8;

varying vec2 uv_afim;
varying vec3 pos_mundo;
varying vec3 normal_mundo;


float hash11(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}


void vertex() {
	uv_afim = UV * uv_tile;
	pos_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normal_mundo = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);

	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (use_snap && psx_snap && clip.w > 0.0) {
		vec3 ndc = clip.xyz / clip.w;
		vec2 grade = snap_resolution * psx_snap_escala;
		ndc.xy = floor(ndc.xy * grade) / grade;
		clip = vec4(ndc * clip.w, clip.w);
	}
	POSITION = clip;
}


/// Tamanho da peca em metros, deduzido da razao entre as duas UVs.
///
/// A UV anda em metros vezes uma escala fixa; a UV2 anda de 0 a 1 na peca
/// inteira. A razao entre as derivadas das duas da o tamanho sem precisar de
/// uniform por janela — e sao milhares de janelas com um material so.
vec2 tamanho_da_peca(vec2 uv1, vec2 uv2) {
	vec2 d1 = abs(vec2(dFdx(uv1.x), dFdy(uv1.y)));
	vec2 d2 = abs(vec2(dFdx(uv2.x), dFdy(uv2.y)));
	vec2 t = d1 / max(d2, vec2(1e-6)) * 2.0;
	// Fora de uma faixa plausivel, a derivada nao serve (peca de perfil, um
	// pixel so). Ali vale o padrao.
	bvec2 ok = greaterThan(t, vec2(0.15)) ;
	return vec2(ok.x && t.x < 12.0 ? t.x : tamanho_padrao.x,
		ok.y && t.y < 12.0 ? t.y : tamanho_padrao.y);
}


/// O que se ve atras do vidro: uma caixa por sala, em espaco de mundo.
///
/// Devolve a cor e, em `luz`, quanto daquilo e luz propria (lampada acesa).
vec3 comodo(vec3 p, vec3 olhar, vec3 n, out float luz, out float dentro) {
	luz = 0.0;
	dentro = 1.0;
	// Base da sala: para dentro e -n; o lado corre pela tangente horizontal.
	vec3 fundo = -n;
	vec3 lado = normalize(cross(vec3(0.0, 1.0, 0.0), n));
	if (length(cross(vec3(0.0, 1.0, 0.0), n)) < 0.001) {
		lado = vec3(1.0, 0.0, 0.0);
	}
	vec3 cima = vec3(0.0, 1.0, 0.0);

	float s = dot(p, lado);
	float y = p.y;
	float celula_s = floor(s / sala_larg);
	float celula_y = floor(y / andar_alt);
	float s0 = celula_s * sala_larg;
	float s1 = s0 + sala_larg;
	float y0 = celula_y * andar_alt + 0.05;
	float y1 = y0 + andar_alt * 0.9;

	float ds = dot(olhar, lado);
	float dy = dot(olhar, cima);
	float dz = dot(olhar, fundo);
	if (dz <= 0.001) {
		dentro = 0.0;
		return cor_parede_interna.rgb;
	}

	float t_fundo = sala_prof / dz;
	float t_s = 1e9;
	if (abs(ds) > 1e-4) {
		t_s = ((ds > 0.0 ? s1 : s0) - s) / ds;
	}
	float t_y = 1e9;
	if (abs(dy) > 1e-4) {
		t_y = ((dy > 0.0 ? y1 : y0) - y) / dy;
	}

	float semente = hash21(vec2(celula_s, celula_y));
	// Cortina: um pano a 20 cm do vidro, cobrindo de cima para baixo.
	float t_cortina = 0.2 / dz;
	bool tem_cortina = semente < cortina_prob;
	vec3 bate_cortina = p + olhar * t_cortina;
	float altura_cortina = mix(0.45, 0.95, hash11(semente * 7.7));
	bool na_cortina = tem_cortina
		&& bate_cortina.y > y1 - (y1 - y0) * altura_cortina;

	float t = min(t_fundo, min(t_s, t_y));
	vec3 bate = p + olhar * t;
	vec3 cor;
	if (na_cortina) {
		// Dobras verticais, e a luz do comodo passando pelo tecido.
		float dobra = 0.78 + 0.22 * sin(dot(bate_cortina, lado) * 24.0);
		cor = cor_cortina.rgb * dobra;
		if (acesa) {
			luz = 0.55 * dobra;
		}
		return cor;
	}
	if (t == t_y && dy < 0.0) {
		cor = cor_chao_interno.rgb;
	} else if (t == t_y) {
		cor = cor_teto_interno.rgb;
		// Lampada no meio do teto: e ela que acende a sala.
		vec2 no_teto = vec2(dot(bate, lado) - (s0 + s1) * 0.5,
			dot(bate, fundo) - sala_prof * 0.55);
		float lampada = 1.0 - smoothstep(0.1, 0.34, length(no_teto));
		if (acesa) {
			luz = lampada;
			cor = mix(cor, cor_luz.rgb, lampada);
		}
	} else if (t == t_s) {
		cor = cor_parede_interna.rgb * 0.72;
	} else {
		cor = cor_parede_interna.rgb;
		// Um movel escuro encostado no fundo, na metade de baixo.
		float altura_movel = mix(0.25, 0.5, hash11(semente * 3.1));
		if (bate.y < y0 + (y1 - y0) * altura_movel) {
			cor *= mix(0.35, 0.6, hash11(semente * 11.3));
		}
	}
	// Quanto mais fundo, mais escuro: a luz que entra pela janela nao chega la.
	float fundura = clamp(dot(bate - p, fundo) / sala_prof, 0.0, 1.0);
	cor *= mix(1.0, 0.35, fundura);
	if (acesa) {
		// A sala acesa nao e uma chapa laranja: e a MESMA sala, com a luz do
		// teto batendo mais no que esta perto dela.
		cor = mix(cor, cor * 1.8 + cor_luz.rgb * 0.12, 0.7);
		luz = max(luz, 0.18 * (1.0 - fundura));
	}
	return cor;
}


void fragment() {
	vec2 u = UV2;
	vec2 tam = tamanho_da_peca(uv_afim, UV2);
	// Caixilho em volta e montante no meio, medidos em METROS na peca.
	vec2 borda_uv = vec2(caixilho_m / max(tam.x, 0.05), caixilho_m / max(tam.y, 0.05));
	float esquadria = 0.0;
	esquadria = max(esquadria, 1.0 - smoothstep(borda_uv.x * 0.8, borda_uv.x, u.x));
	esquadria = max(esquadria, 1.0 - smoothstep(borda_uv.x * 0.8, borda_uv.x, 1.0 - u.x));
	esquadria = max(esquadria, 1.0 - smoothstep(borda_uv.y * 0.8, borda_uv.y, u.y));
	esquadria = max(esquadria, 1.0 - smoothstep(borda_uv.y * 0.8, borda_uv.y, 1.0 - u.y));
	float meio_uv = montante_m / max(tam.x, 0.05) * 0.5;
	esquadria = max(esquadria, 1.0 - smoothstep(meio_uv * 0.7, meio_uv, abs(u.x - 0.5)));
	if (tam.y >= altura_bandeira) {
		float trav = montante_m / max(tam.y, 0.05) * 0.5;
		esquadria = max(esquadria, 1.0 - smoothstep(trav * 0.7, trav, abs(u.y - 0.72)));
	}

	vec3 olhar = normalize(pos_mundo - CAMERA_POSITION_WORLD);
	vec3 n = normalize(normal_mundo);
	float luz = 0.0;
	float dentro = 1.0;
	vec3 sala = comodo(pos_mundo, olhar, n, luz, dentro);

	// O vidro TRANSMITE o que esta atras e devolve o ceu no reflexo.
	//
	// Um comodo sem luz, visto de dia pela rua, e quase preto: o que chega de la
	// e a luz que entrou pela propria janela e voltou. Com o comodo apagado
	// claro, o Fresnel nao tem contra o que aparecer e o vidro le como chapa
	// cinza — medido: rasante sobre frente dava 1,1x.
	vec3 tinta = cor_vidro.rgb / max(max(cor_vidro.r, cor_vidro.g), cor_vidro.b);
	float transmissao = acesa ? 0.85 : 0.26;
	vec3 cor = sala * tinta * transmissao * dentro
		+ cor_parede_interna.rgb * 0.2 * (1.0 - dentro);
	float rug = rugosidade_vidro;
	float spec = brilho_vidro;

	ALBEDO = mix(cor, cor_esquadria.rgb, esquadria);
	EMISSION = acesa ? cor_luz.rgb * luz * emissao_acesa * (1.0 - esquadria) : vec3(0.0);
	// A esquadria e pintada: fosca, e ela e que molha na chuva.
	float molhado = psx_molhado * esquadria;
	ROUGHNESS = mix(rug, mix(0.65, 0.2, molhado), esquadria);
	SPECULAR = mix(spec, mix(0.25, 0.5, molhado), esquadria);
	METALLIC = 0.0;
	// Poeira e escorrido no vidro: o que faz ele nao parecer plastico polido.
	float escorrido = 0.5 + 0.5 * sin(pos_mundo.y * 9.0 + hash11(floor(pos_mundo.x * 3.0)) * 6.28);
	ROUGHNESS += (1.0 - esquadria) * (0.05 + 0.05 * escorrido) * (1.0 - psx_chuva * 0.6);
}
