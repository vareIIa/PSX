// Superficie MODERNA — a variante por pixel do psx_surface.
//
// Por que existe um segundo arquivo em vez de um uniform
// ------------------------------------------------------
// `vertex_lighting` e `shadows_disabled` sao `render_mode`: o compilador resolve
// os dois e nao ha como virar nenhum deles com uniform. Entao o preset de estilo
// troca `material.shader` entre este arquivo e o psx_surface.
//
// TODO uniform daqui tem nome identico ao do psx_surface, de proposito. E isso
// que faz a troca preservar os 106 materiais sem reconfigurar nenhum: o Godot
// reaproveita por nome o que ja estava setado. Se um nome divergir, aquele
// material perde o valor e volta ao padrao na hora de trocar de estilo.
//
// O que muda em relacao ao psx_surface:
//   - luz por PIXEL, nao por vertice
//   - recebe sombra projetada (sem `shadows_disabled`)
//   - tem specular, com rugosidade controlavel — e o que da para onde ir quando
//     a superficie molhar
//
// O que NAO muda, e nao deve mudar: filtro de textura ponto, geometria low-poly,
// snap e UV afim disponiveis. E o mesmo jogo com luz melhor, nao outro jogo.

shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec2 uv_tile = vec2(1.0, 1.0);

uniform vec2 snap_resolution = vec2(240.0, 135.0);
uniform bool use_snap = true;
uniform bool use_affine = true;
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.0;

// Ver psx_surface: o global so sabe DESLIGAR, quem liga e o material.
global uniform bool psx_snap;
global uniform bool psx_affine;
global uniform float psx_snap_escala;

uniform float vento_forca : hint_range(0.0, 1.0) = 0.0;
uniform float vento_velocidade : hint_range(0.0, 6.0) = 1.0;
const vec2 VENTO_DIR = vec2(0.82, 0.57);

uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy : hint_range(0.0, 8.0) = 0.0;

// Exclusivos desta variante. Nao existem no psx_surface porque la o specular e
// desligado por render_mode; ao voltar para PS1 STYLE eles sao simplesmente
// ignorados, e ao voltar para MODERNO reaparecem com estes padroes.
//
// 0.88 e fosco de rua: reboco, asfalto seco, concreto. Quem precisa brilhar
// (vidro, metal, carroceria, e mais tarde tudo que estiver molhado) baixa isto
// no proprio material.
uniform float rugosidade : hint_range(0.0, 1.0) = 0.88;
uniform float brilho : hint_range(0.0, 1.0) = 0.12;

// --- conjunto HD (PLANO_AAA_4K, Fase 3) --------------------------------------
// Cor, relevo e rugosidade de 1024 px vindos do ambientCG, para o MODERNO. Quem
// liga e o EstiloVisual, escrevendo `usa_hd` e as tres texturas; sem isso este
// bloco nao custa nada e o material se comporta como antes.
//
// Os samplers pedem `filter_linear_mipmap_anisotropic` porque o alvo aqui e o
// oposto do PS1: sem mipmap e sem anisotropico, uma parede de 1024 px vista de
// esguelha em 4K cintila a cada passo. O `albedo_tex` de cima continua
// `filter_nearest` e continua sendo o que o PS1 STYLE usa.
uniform sampler2D albedo_hd : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_hd : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// R = rugosidade, G = oclusao de ambiente. Ver tools/texturas_hd.py.
uniform sampler2D rugosidade_hd : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool usa_hd = false;
// Pinta a normal em vez de iluminar. So para bancada (tests/bancada_relevo.gd):
// sem isso, "o relevo nao aparece" nao distingue mapa que nao chega de mapa que
// chega e nao ilumina.
uniform bool depurar_relevo = false;
// Forca do relevo. 1,0 e o mapa como veio da foto.
uniform float relevo : hint_range(0.0, 3.0) = 1.0;

// --- molhado -----------------------------------------------------------------
// Quanto o mundo esta molhado, escrito pelo Clima. Global porque toda superficie
// de rua responde, inclusive a que o streaming ainda nem carregou.
//
// So existe nesta variante. O psx_surface tem `specular_disabled`: la nao havia
// para onde o reflexo ir, e o PS1 STYLE continua sendo a build de antes.
global uniform float psx_molhado;

// Quanto ESTE material responde. Marquise, teto e interior marcam 0 — a chuva
// nao alcanca. O padrao e 1 porque a maioria esmagadora das superficies do jogo
// e rua a ceu aberto.
uniform float molha : hint_range(0.0, 1.0) = 1.0;

// Por INSTANCIA, e nao por material: o piso da casa da fumaca e o mesmo
// `mat_piso` de qualquer comodo, mas ela existe na rua (InteriorNoMundo) e
// continua debaixo do telhado enquanto a cidade encharca. 1 = abrigado.
instance uniform float abrigo : hint_range(0.0, 1.0) = 0.0;

// Quao espelhada ESTA superficie fica encharcada.
//
// Asfalto e calcada viram lamina e refletem quase limpo; grama, terra e areia
// ABSORVEM — escurecem bastante e refletem pouco. Sem esta separacao o gramado
// vira um lago de mercurio, que foi exatamente o que a primeira captura mostrou.
uniform float rugosidade_molhada : hint_range(0.0, 1.0) = 0.12;

// Esta caindo chuva agora. Separado do molhado de proposito: a rua continua
// molhada minutos depois que a chuva para, mas o anel de impacto tem de parar
// junto com a ultima gota. Confundir os dois deixa a poca fervendo no dia
// seguinte.
global uniform float psx_chuva;

// --- chuva fora do carro (Fase 6 do PLANO_AAA_4K) -----------------------------
// Gota parada na lataria e respingo no teto. Material que marca 1 e chapa
// pintada (a `EstiloVisual` escreve pela tabela); o resto fica em 0 e nao paga
// nada. A gota vive no espaco do OBJETO: presa ao mundo, ela escorregaria pela
// lataria enquanto o carro anda.
uniform float gotas : hint_range(0.0, 1.0) = 0.0;
// Tecido. Roupa molhada escurece INTEIRA, e nao so o que olha para cima: a agua
// entra na trama e desce. O quanto vem de `encharcado` quando o material e de
// uma pessoa so (o jogador), e do molhado do mundo quando e de todo mundo.
uniform float roupa : hint_range(0.0, 1.0) = 0.0;
uniform float encharcado : hint_range(-1.0, 1.0) = -1.0;

varying vec2 uv_affine;
varying float w_affine;
/// Componente Y da normal em MUNDO. Sai do vertice porque no fragmento a NORMAL
/// ja esta em espaco de visao, e "para cima" ali muda quando a camera gira.
varying float face_cima;
/// Posicao em mundo. O anel de impacto e ancorado no MUNDO, e nao na UV: preso a
/// UV ele escorregaria junto com a textura e nasceria repetido em cada peca da
/// malha, delatando a grade do chunk.
varying vec3 pos_mundo;
/// Posicao e normal no espaco do objeto, para a gota que anda junto com ele.
varying vec3 pos_local;
varying vec3 normal_local;


float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

/// Aneis de impacto de gota, em espaco de mundo.
///
/// Uma celula, uma gota. Cada celula dispara na sua propria fase, entao as gotas
/// nao caem todas no mesmo instante — que e o defeito que faz chuva procedural
/// parecer um pulso de radar.
///
/// Quatro celulas vizinhas, e nao nove: o anel morre bem antes de alcancar a
/// borda da celula, entao as cinco de fora nao contribuem com nada e custariam
/// mais da metade do orcamento do efeito.
///
/// A escala de entrada importa mais que qualquer constante daqui. Em 1,35 a
/// celula tinha 74 cm e o anel chegava a 68 cm de diametro — uma pedra caindo
/// no lago, nao chuva. Em 4,2 a celula tem 24 cm e o anel para em 11 cm, que e
/// o tamanho de uma gota batendo em poca.
vec2 aneis_de_chuva(vec2 p, float t) {
	vec2 soma = vec2(0.0);
	vec2 base = floor(p);
	for (int i = 0; i < 4; i++) {
		vec2 c = base + vec2(float(i & 1), float(i >> 1));
		float h = hash21(c);
		// Fase propria por celula. O `h` entra somado ao tempo, entao a gota
		// desta celula cai num momento que nenhuma vizinha repete.
		float fase = fract(t * 1.1 + h);
		vec2 centro = c + vec2(hash21(c + 17.3), hash21(c + 31.7));
		vec2 d = p - centro;
		float dist = length(d) + 1e-5;
		// O anel expande e desaparece. `vida` ao quadrado faz ele sumir
		// rapido no fim, como agua de verdade: o ultimo terco do raio quase
		// nao se ve.
		float raio = fase * 0.46;
		float anel = smoothstep(0.055, 0.0, abs(dist - raio));
		float vida = 1.0 - fase;
		soma += (d / dist) * anel * vida * vida;
	}
	return soma;
}

/// Uma camada de gotas paradas numa chapa, em celulas.
///
/// Cada celula tem no maximo uma gota, presente se o hash dela ficar abaixo da
/// `cobertura` — entao a chapa vai ganhando gota por gota conforme a chuva
/// engrossa, em vez de acender todas de uma vez. `escorre` estica a gota para
/// baixo na face vertical, que e o formato de gota em porta de carro.
///
/// Devolve em xy o desvio da normal (a gota e uma cupula: o desvio cresce para
/// a borda) e em z a mascara da gota.
vec3 camada_de_gotas(vec2 p, float cobertura, float escorre) {
	vec2 c = floor(p);
	vec2 f = fract(p);
	float h = hash21(c + 5.31);
	if (h > cobertura) {
		return vec3(0.0);
	}
	vec2 centro = vec2(0.3) + 0.4 * vec2(hash21(c + 7.1), hash21(c + 3.3));
	float raio = mix(0.16, 0.36, hash21(c + 11.7));
	vec2 d = (f - centro) / raio;
	// Achata por cima e alonga por baixo: o peso puxa a agua.
	d.y *= mix(1.0, d.y > 0.0 ? 0.55 : 1.35, escorre);
	float r2 = dot(d, d);
	if (r2 >= 1.0) {
		return vec3(0.0);
	}
	float borda = smoothstep(1.0, 0.7, r2);
	return vec3(d * (0.35 + 0.65 * r2), borda);
}

void vertex() {
	if (vento_forca > 0.0) {
		vec3 mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float fase = mundo.x * 0.31 + mundo.z * 0.23;
		float balanco = sin(TIME * vento_velocidade + fase)
			+ 0.45 * sin(TIME * vento_velocidade * 1.73 + fase * 1.31);
		float rajada = 0.65 + 0.35 * sin(TIME * 0.21 + mundo.x * 0.02);
		vec2 desvio = VENTO_DIR * (balanco * rajada * vento_forca * COLOR.a);
		VERTEX.x += desvio.x;
		VERTEX.z += desvio.y;
		VERTEX.y -= length(desvio) * 0.25;
	}

	face_cima = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
	pos_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	pos_local = VERTEX;
	normal_local = NORMAL;

	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);

	if (use_snap && psx_snap && clip.w > 0.0) {
		vec3 ndc = clip.xyz / clip.w;
		vec2 grade = snap_resolution * psx_snap_escala;
		ndc.xy = floor(ndc.xy * grade) / grade;
		clip = vec4(ndc * clip.w, clip.w);
	}
	POSITION = clip;

	w_affine = clip.w;
	uv_affine = UV * uv_tile * clip.w;
}

// Base tangente montada das DERIVADAS da tela, e nao dos vertices.
//
// A cidade e procedural e as malhas saem do PSXMesh sem tangente nenhuma; com
// `TANGENT` indefinido, `NORMAL_MAP` do Godot produz relevo girando junto com a
// camera. Esta e a base cotangente (Schuler): a partir da posicao e da UV do
// proprio fragmento, sai um referencial correto sem tocar na geracao de malha e
// sem 30% a mais de vertice em memoria.
mat3 base_tangente(vec3 n, vec3 p, vec2 uv) {
	vec3 dp1 = dFdx(p);
	vec3 dp2 = dFdy(p);
	vec2 duv1 = dFdx(uv);
	vec2 duv2 = dFdy(uv);
	vec3 dp2perp = cross(dp2, n);
	vec3 dp1perp = cross(n, dp1);
	vec3 t = dp2perp * duv1.x + dp1perp * duv2.x;
	vec3 b = dp2perp * duv1.y + dp1perp * duv2.y;
	float inv = inversesqrt(max(dot(t, t), dot(b, b)));
	return mat3(t * inv, b * inv, n);
}

void fragment() {
	vec2 uv = (use_affine && psx_affine) ? (uv_affine / w_affine) : (UV * uv_tile);
	vec4 texel = usa_hd ? (texture(albedo_hd, uv) * tint) : (texture(albedo_tex, uv) * tint);
	ALBEDO = texel.rgb * COLOR.rgb;

	if (alpha_cutoff > 0.0) {
		ALPHA = texel.a;
		ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;
	}

	if (emission_energy > 0.0) {
		EMISSION = emission_color.rgb * texel.rgb * COLOR.rgb * emission_energy;
	}

	// Molhado. So o que aponta para cima: agua escorre da parede e fica no chao,
	// entao a face vertical continua fosca enquanto a horizontal espelha. Sai de
	// graca da normal, sem mascara pintada e sem segunda textura.
	//
	// O degrau comeca em 0,30 e nao em 0: uma rampa a partir do zero deixaria a
	// parede levemente brilhante, e "tudo um pouco molhado" le como verniz, nao
	// como chuva.
	// O relevo entra ANTES do molhado, porque o molhado le a normal: a poca
	// acompanha a cova do paralelepipedo em vez de ficar plana por cima dele.
	float rug_seca = rugosidade;
	if (usa_hd) {
		// O Z e RECONSTRUIDO, e nao lido. O mapa de normal e importado com
		// compressao propria (RGTC/BC5), que guarda so dois canais e devolve o
		// terceiro sem significado; lendo `.z` direto, a normal aponta para
		// qualquer lado e a cidade inteira fica preta — foi exatamente o que a
		// primeira captura desta fase mostrou.
		vec3 n_tan;
		n_tan.xy = (texture(normal_hd, uv).xy * 2.0 - 1.0) * relevo;
		n_tan.z = sqrt(max(1.0 - dot(n_tan.xy, n_tan.xy), 0.0));
		NORMAL = normalize(base_tangente(normalize(NORMAL), VERTEX, uv) * normalize(n_tan));
		vec2 ru = texture(rugosidade_hd, uv).rg;
		rug_seca = ru.r;
		AO = ru.g;
		// A oclusao do mapa vale para a luz direta tambem: e cova de verdade na
		// superficie, e nao so escurecimento de ambiente.
		AO_LIGHT_AFFECT = 1.0;
	}

	float molhado = psx_molhado * molha * (1.0 - abrigo) * smoothstep(0.30, 0.75, face_cima);

	// Escurecer e o efeito mais barato e o mais convincente, e e fisica de
	// verdade: a lamina de agua prende a luz em reflexoes internas e devolve
	// menos ao olho. Asfalto molhado nao brilha mais que o seco — ele fica mais
	// ESCURO, e e o reflexo que aparece por cima.
	ALBEDO *= mix(1.0, 0.52, molhado);

	// A rugosidade e quem acende o reflexo: com 0,88 o asfalto seco espalha a
	// luz e engole qualquer reflexo; com 0,12 a lamina devolve o poste inteiro.
	// E o mesmo numero que faz o SSR ter o que mostrar.
	// Anel de impacto. So na lamina molhada e so enquanto cai chuva; a
	// perturbacao entra na NORMAL, e nao no albedo, porque o que se ve de um anel
	// de agua nao e uma marca clara, e o reflexo TORTO. Escrito no albedo ele
	// viraria um desenho de giz.
	//
	// A onda e montada em MUNDO e convertida para espaco de visao pela VIEW_MATRIX,
	// que e onde a NORMAL vive no fragmento.
	float bate = psx_chuva * molhado;
	if (bate > 0.01) {
		vec2 onda = aneis_de_chuva(pos_mundo.xz * 4.2, TIME);
		vec3 desvio = (VIEW_MATRIX * vec4(onda.x, 0.0, onda.y, 0.0)).xyz;
		NORMAL = normalize(NORMAL + desvio * bate * 0.85);
	}

	// Roupa molhada. O escuro vale para a emissao tambem: o `mat_npc` acende o
	// rosto a noite com emissao, e sem esta linha a roupa encharcada continuava
	// clara exatamente onde a luz da rua nao chega.
	if (roupa > 0.0) {
		float e = clamp(encharcado >= 0.0 ? encharcado : psx_molhado, 0.0, 1.0) * roupa;
		// Metade da luz, em linear: algodao encharcado. Na tela (sRGB) isso e
		// uns 27% mais escuro, que e o que o olho le como "molhado" e nao como
		// "na sombra".
		ALBEDO *= mix(1.0, 0.5, e);
		EMISSION *= mix(1.0, 0.5, e);
		rug_seca = mix(rug_seca, 0.62, e);
	}

	float rug_final = mix(rug_seca, rugosidade_molhada, molhado);

	// Gota parada na chapa. Chega antes do molhado do mundo — a lataria junta
	// gota no primeiro segundo de chuva, e o asfalto leva minuto e meio para
	// encharcar —, e fica depois dela parar, enquanto ainda ha agua no mundo.
	if (gotas > 0.0) {
		float cobertura = gotas * (1.0 - abrigo) * clamp(max(psx_chuva * 3.0, psx_molhado * 1.15), 0.0, 1.0);
		vec3 nl = normalize(normal_local);
		if (cobertura > 0.01) {
			vec3 an = abs(nl);
			vec2 plano;
			vec3 eixo_u;
			vec3 eixo_v;
			// Projecao pela face dominante. Na face vertical o eixo v aponta
			// para BAIXO, que e para onde a gota escorre.
			if (an.y >= an.x && an.y >= an.z) {
				plano = pos_local.xz;
				eixo_u = vec3(1.0, 0.0, 0.0);
				eixo_v = vec3(0.0, 0.0, 1.0);
			} else if (an.x >= an.z) {
				plano = vec2(pos_local.z, -pos_local.y);
				eixo_u = vec3(0.0, 0.0, 1.0);
				eixo_v = vec3(0.0, -1.0, 0.0);
			} else {
				plano = vec2(pos_local.x, -pos_local.y);
				eixo_u = vec3(1.0, 0.0, 0.0);
				eixo_v = vec3(0.0, -1.0, 0.0);
			}
			float escorre = 1.0 - smoothstep(0.5, 0.9, an.y);
			// Duas camadas: gota de 4 a 9 mm e gotinha de 2 a 5 mm.
			vec2 p1 = plano * 38.0;
			vec2 p2 = plano * 71.0 + 13.7;
			// Longe, a celula cabe em poucos pixels e a gota vira chiado que
			// pisca a cada quadro. Ali ela sai do desenho e fica so a media:
			// chapa com agua reflete mais limpo.
			float px = length(fwidth(p1));
			float nitido1 = 1.0 - smoothstep(0.22, 0.45, px);
			float nitido2 = 1.0 - smoothstep(0.22, 0.45, px * 1.87);
			vec3 g1 = camada_de_gotas(p1, cobertura * 0.5, escorre);
			vec3 g2 = camada_de_gotas(p2, cobertura * 0.7, escorre);
			g1.z *= nitido1;
			g2.z *= nitido2;
			vec3 g = g1.z >= g2.z ? g1 : g2;
			if (g.z > 0.0) {
				vec3 desvio_local = eixo_u * g.x + eixo_v * g.y;
				vec3 desvio = (VIEW_MATRIX * (MODEL_MATRIX * vec4(desvio_local, 0.0))).xyz;
				NORMAL = normalize(NORMAL + desvio * g.z * 1.6);
				ALBEDO *= mix(1.0, 0.82, g.z);
				rug_final = mix(rug_final, 0.03, g.z);
			}
			rug_final = mix(rug_final, rug_final * 0.6, cobertura * (1.0 - nitido2) * 0.5);
		}
		// Respingo: a gota que bate no teto e no capo abre um anel curto.
		float bate_chapa = psx_chuva * gotas * smoothstep(0.6, 0.9, nl.y);
		if (bate_chapa > 0.01) {
			vec2 onda = aneis_de_chuva(pos_local.xz * 7.0, TIME * 1.6);
			vec3 d2 = (VIEW_MATRIX * (MODEL_MATRIX * vec4(onda.x, 0.0, onda.y, 0.0))).xyz;
			NORMAL = normalize(NORMAL + d2 * bate_chapa * 0.7);
		}
	}

	if (depurar_relevo) {
		ALBEDO = NORMAL * 0.5 + 0.5;
		EMISSION = ALBEDO;
	}

	ROUGHNESS = rug_final;
	METALLIC = 0.0;
	// O realce acompanha a rugosidade: superficie que nao espelha tambem nao
	// ganha specular, senao a grama molhada fica com brilho de plastico.
	SPECULAR = mix(brilho, mix(0.55, brilho, rugosidade_molhada), molhado);
}
