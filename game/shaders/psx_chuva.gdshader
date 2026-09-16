// Risco de chuva. Quad esticado na vertical, com alfa em dither.
//
// A chuva da referencia noturna aparece como risco claro contra o escuro, nao
// como gota redonda. O quad e alto e fino de proposito, e o alfa cai para as
// pontas para o risco ter cabeca e cauda em vez de ser um retangulo.
//
// Alfa em dither ordenado pela mesma razao do facho de luz: o PS1 nao tinha
// transparencia por pixel, ele alternava pixels num padrao fixo. Sem isso a
// chuva fica lisa demais e destoa do resto da imagem.

shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never,
	shadows_disabled, vertex_lighting;

uniform vec4 cor : source_color = vec4(0.72, 0.78, 0.85, 1.0);
uniform float intensidade : hint_range(0.0, 3.0) = 1.0;

// Cai perto da camera para o risco nao virar uma parede de linhas na cara, e
// longe dela porque a nevoa ja engoliu tudo la atras.
uniform float perto = 0.6;
uniform float longe = 22.0;

// TETO: o volume de uma cabine, onde nao chove.
//
// A chuva e uma caixa de 22 m que segue a camera, e a camera do plano de dentro
// esta DENTRO de um carro. Sem isto, os riscos atravessam o painel e caem no
// colo do motorista: a lataria so tapa o que esta atras dela, e a gota que
// nasceu entre o olho e o para-brisa e desenhada na cara. `TetoChuva` escreve
// aqui, a cada quadro, a caixa da cabine e os planos dos vidros.
//
// Caixa E planos, e nao so caixa: o para-brisa e inclinado, entao a caixa que
// vai do corta-fogo ao fundo engloba, na frente, uma cunha de ar que esta FORA
// do carro — em cima do capo, bem onde o motorista mais olha a chuva. O plano
// do vidro corta essa cunha fora.
uniform bool teto_ativo = false;
// Mundo -> espaco do carro.
uniform mat4 teto_do_mundo = mat4(1.0);
uniform vec3 teto_min = vec3(0.0);
uniform vec3 teto_max = vec3(0.0);
// Ate seis planos (normal para FORA, d): o ponto esta dentro se
// dot(normal, p) - d < 0 em todos.
uniform int teto_n_planos = 0;
uniform vec4 teto_planos[6];

const float BAYER[16] = float[](
	 0.0,  8.0,  2.0, 10.0,
	12.0,  4.0, 14.0,  6.0,
	 3.0, 11.0,  1.0,  9.0,
	15.0,  7.0, 13.0,  5.0
);

varying float v_dist;
varying vec3 v_mundo;

void vertex() {
	v_dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	v_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


bool dentro_do_teto(vec3 mundo) {
	if (!teto_ativo) {
		return false;
	}
	vec3 p = (teto_do_mundo * vec4(mundo, 1.0)).xyz;
	if (any(lessThan(p, teto_min)) || any(greaterThan(p, teto_max))) {
		return false;
	}
	for (int i = 0; i < 6; i++) {
		if (i >= teto_n_planos) {
			break;
		}
		if (dot(teto_planos[i].xyz, p) - teto_planos[i].w > 0.0) {
			return false;
		}
	}
	return true;
}

void fragment() {
	// Por fragmento, e nao por particula: o risco tem 42 cm, e um risco que
	// atravessa o vidro tem de ser cortado NO vidro, com a metade de fora
	// continuando a cair.
	if (dentro_do_teto(v_mundo)) {
		discard;
	}
	// Cabeca e cauda do risco. UV.y vai de 0 no topo a 1 na base.
	float ao_longo = 1.0 - abs(UV.y * 2.0 - 1.0);
	float atravessado = 1.0 - abs(UV.x * 2.0 - 1.0);

	float a = ao_longo * atravessado * intensidade * COLOR.a;
	a *= smoothstep(0.0, perto, v_dist);
	a *= 1.0 - smoothstep(longe * 0.6, longe, v_dist);

	int idx = int(mod(FRAGCOORD.y, 4.0)) * 4 + int(mod(FRAGCOORD.x, 4.0));
	a += (BAYER[idx] / 16.0 - 0.5) * 0.16;

	ALBEDO = cor.rgb;
	ALPHA = clamp(a, 0.0, 1.0);
}
