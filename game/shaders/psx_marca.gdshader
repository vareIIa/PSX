// A marca que o pneu deixa no asfalto.
//
// Por que um shader proprio
// -------------------------
// Uma marca de pneu nao e superficie: e uma SUJEIRA sobre outra superficie. O
// `psx_surface` ilumina, recebe nevoa e escreve profundidade — tres coisas que
// uma mancha colada no chao nao pode fazer. Escrevendo profundidade ela briga
// com o asfalto que esta um centimetro abaixo e o resultado e o z-fighting
// classico: a marca pisca em faixas conforme a camera anda.
//
// O parente mais proximo e o `psx_fumaca`, e pelo mesmo motivo — os dois sao
// materia translucida desenhada DEPOIS do mundo. A diferenca e que a fumaca
// clareia o que esta atras e a marca escurece o que esta embaixo.
//
// Multiplicar em vez de cobrir
// ----------------------------
// A borracha nao pinta o asfalto de preto: ela tira luz dele. Com `blend_mix` e
// uma cor escura, a marca fica igual em cima do asfalto novo, do remendo e da
// faixa branca — uma tarja chapada, que e o erro que denuncia decalque. Com
// `blend_mul` ela multiplica o que ja estava ali, entao a faixa branca fica
// cinza e o asfalto fica quase preto, com a textura do chao ATRAVESSANDO a
// marca. E o que borracha faz.
//
// Grau de escuridao vem do vertice
// --------------------------------
// `COLOR.a` chega do `RastroPneu` com duas informacoes multiplicadas: quanto o
// pneu estava escorregando quando passou ali e quanto tempo faz. Aqui isso vira
// o quanto a cor se afasta do branco — alfa 0 e branco puro, que em
// multiplicacao e "nao mexe em nada", e por isso a marca velha some sem precisar
// ser apagada da malha.
shader_type spatial;
render_mode blend_mul, unshaded, cull_disabled, depth_draw_never,
	shadows_disabled, vertex_lighting;

// A cor da borracha no escuro maximo. Nao e preto puro: asfalto multiplicado
// por zero vira um buraco e le como falha de desenho, nao como marca.
//
// 0,22 e nao 0,30, e o numero saiu de uma captura que nao mostrou nada. A
// primeira versao deste shader desenhava certo — geometria no lugar, largura
// certa, o arco inteiro da derrapagem — e era INVISIVEL, porque a conta do
// alfa chegava em 0,25 e multiplicar o asfalto por mix(1; 0,30; 0,25) = 0,82 e
// escurecer 17%, que a 480x270 com dither some no grao. So se soube disso
// trocando o material por vermelho chapado e vendo o arco aparecer.
uniform vec4 cor : source_color = vec4(0.22, 0.20, 0.19, 1.0);
// Teto de escuridao da marca mais nova. Abaixo de 1 a marca nunca chega na cor
// cheia, que e o que impede a derrapagem longa de virar uma tarja solida.
uniform float forca : hint_range(0.0, 1.0) = 0.9;

// Some de longe, como o facho e a fumaca. Uma tira de 19 cm a quarenta metros
// tem menos de um pixel de largura, e o que ela produz ali nao e marca, e
// cintilacao — a borda entra e sai do pixel a cada quadro em que o carro anda.
uniform float fade_inicio = 26.0;
uniform float fade_fim = 40.0;

// O mesmo travamento de vertice do resto do mundo.
//
// Ligado, e nao desligado, e a escolha custou uma captura. A marca esta no
// mesmo plano do asfalto e o asfalto trava; com ela livre, os dois deslizam um
// sobre o outro quando a camera anda e a marca parece flutuar meio pixel acima
// do chao. Travada junto, ela treme com a rua — que e o que uma coisa pintada
// na rua faz neste jogo.
uniform vec2 snap_resolution = vec2(240.0, 135.0);
uniform bool use_snap = true;

const float BAYER[16] = float[](
	 0.0,  8.0,  2.0, 10.0,
	12.0,  4.0, 14.0,  6.0,
	 3.0, 11.0,  1.0,  9.0,
	15.0,  7.0, 13.0,  5.0
);

varying float v_alpha;
varying float v_dist;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (use_snap && clip.w > 0.0) {
		vec3 ndc = clip.xyz / clip.w;
		ndc.xy = floor(ndc.xy * snap_resolution) / snap_resolution;
		clip = vec4(ndc * clip.w, clip.w);
	}
	POSITION = clip;

	v_alpha = COLOR.a;
	v_dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
	float a = v_alpha * forca;
	a *= 1.0 - smoothstep(fade_inicio, fade_fim, v_dist);

	// Dither, como na fumaca e no facho. O PS1 nao tinha alfa por pixel: o
	// degrade limpo de uma marca apagando e a coisa que mais entrega motor
	// moderno, e o padrao ordenado e o que o hardware da epoca deixava no lugar.
	int idx = int(mod(FRAGCOORD.y, 4.0)) * 4 + int(mod(FRAGCOORD.x, 4.0));
	a = clamp(a + (BAYER[idx] / 16.0 - 0.5) * 0.10, 0.0, 1.0);

	// Em multiplicacao, 1 e "nao mexe". A marca anda do branco ate `cor`
	// conforme ela e forte, e nao do transparente ate o preto.
	ALBEDO = mix(vec3(1.0), cor.rgb, a);
	ALPHA = 1.0;
}
