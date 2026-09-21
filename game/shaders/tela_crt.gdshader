// A imagem de um tubo de 29 polegadas: a partida (SubViewport de 320 x 240)
// vista atraves do vidro curvo, das linhas de varredura e da mascara de fosforo.
//
// O que cada termo faz, e por que ele existe
// -------------------------------------------
// curvatura   o vidro de tubo abaula: a borda da imagem encurva e escurece. Sem
//             isso a tela le como monitor de LCD colado num gabinete antigo.
// sangria     o sinal composto espalha a cor na horizontal; o texto do placar
//             ganha a franja que todo mundo lembra.
// linhas      as 240 linhas do sinal, com o vao escuro entre elas. De perto e o
//             que diz "tubo"; de longe some no mipmap, como devia.
// mascara     as tres faixas de fosforo por pixel. Fraca: forte, vira tecido.
// brilho      acima de 1 no MODERNO, para o glow morder e a tela ser a fonte de
//             luz que ela e na sala. No PS1 STYLE fica em 1.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, depth_draw_opaque;

uniform sampler2D tela : source_color, filter_linear, repeat_disable;
uniform float brilho = 1.75;
uniform float curvatura : hint_range(0.0, 0.3) = 0.09;
uniform float sangria : hint_range(0.0, 1.0) = 0.35;
uniform float linhas = 240.0;
uniform float forca_linhas : hint_range(0.0, 1.0) = 0.32;
uniform float mascara : hint_range(0.0, 1.0) = 0.16;
uniform float largura_px = 320.0;

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	c *= 1.0 + curvatura * vec2(c.y * c.y, c.x * c.x);
	vec2 uv = c * 0.5 + 0.5;
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		ALBEDO = vec3(0.0);
	} else {
		float dx = 1.0 / largura_px;
		vec3 cor = texture(tela, uv).rgb;
		vec3 lado = (texture(tela, uv + vec2(dx, 0.0)).rgb + texture(tela, uv - vec2(dx, 0.0)).rgb) * 0.5;
		cor = mix(cor, lado, sangria);
		// Linha de varredura: o meio da linha acende, o vao escurece.
		float s = 0.5 + 0.5 * cos(uv.y * linhas * 6.2831853);
		cor *= 1.0 - forca_linhas * (1.0 - s);
		// Triades de fosforo.
		float m = mod(floor(uv.x * largura_px * 3.0), 3.0);
		vec3 triade = vec3(m < 0.5 ? 1.0 : 1.0 - mascara,
			(m > 0.5 && m < 1.5) ? 1.0 : 1.0 - mascara,
			m > 1.5 ? 1.0 : 1.0 - mascara);
		cor *= triade;
		// Borda do vidro mais escura.
		float borda = smoothstep(1.55, 0.75, length(c * vec2(0.9, 1.0)));
		ALBEDO = cor * borda * brilho;
	}
}
