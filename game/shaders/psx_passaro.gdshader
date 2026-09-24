// Pássaro de longe (CeuVivo): urubu planando, maritaca, garça.
//
// Um MultiMesh so para todos. A malha e um passaro de meia envergadura 1 (o
// tamanho vem da escala da instancia) e a batida de asa e feita aqui: cada
// vertice de asa gira em torno do eixo do corpo pelo angulo da instancia
// (INSTANCE_CUSTOM.x), a ponta dobrando mais que a raiz. O CPU so escreve um
// numero por passaro por quadro.
//
// UV.x = distancia ao corpo (0 na raiz, 1 na ponta); UV.y = 1 na asa.
// A cor vem da instancia: de longe passaro e silhueta, e a cor ja traz o
// contraluz. Com nevoa: a propria nevoa da cena apaga o bando, como apagaria
// qualquer coisa a cem metros.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

void vertex() {
	if (UV.y > 0.5) {
		float s = UV.x;
		float a = INSTANCE_CUSTOM.x * (0.75 + 0.5 * s);
		float lado = sign(VERTEX.x);
		float r = abs(VERTEX.x);
		VERTEX.x = lado * r * cos(a);
		VERTEX.y += r * sin(a);
	}
}

void fragment() {
	ALBEDO = COLOR.rgb;
}
