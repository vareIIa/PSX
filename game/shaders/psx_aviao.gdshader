// Aviao de longe (CeuVivo): o teco-teco que passa baixo e o jato la no alto.
//
// Tipo por vertice (UV.x):
//   0  corpo     cor de vertice, afogada no ar pela distancia (`ar`). A noite
//                o corpo some: o que se ve de aviao a noite sao as luzes.
//   1  navegacao vermelha e verde nas pontas da asa. So a noite.
//   2  estrobo   o branco que pisca. Dia e noite (de dia, fraco).
// UV.y = fase do pisca.
//
// Sem nevoa da cena: o jato mora preso a camera a 360 m, alem de onde toda
// nevoa ja fechou; o teco-teco a centenas de metros. O ar entra pela `ar`.
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;

uniform vec3 fundo : source_color = vec3(0.53, 0.72, 0.92);
uniform float ar = 0.0;
uniform float noite = 0.0;

varying float v_tipo;
varying float v_fase;

void vertex() {
	v_tipo = UV.x;
	v_fase = UV.y;
}

void fragment() {
	if (v_tipo < 0.5) {
		if (noite > 0.5) {
			discard;
		}
		ALBEDO = mix(COLOR.rgb, fundo, ar);
	} else if (v_tipo < 1.5) {
		if (noite < 0.5) {
			discard;
		}
		ALBEDO = COLOR.rgb;
	} else {
		// Estrobo: um lampejo curto a cada 1,2 s.
		float k = fract(TIME / 1.2 + v_fase);
		if (k > 0.07 || (noite < 0.5 && ar > 0.5)) {
			discard;
		}
		ALBEDO = COLOR.rgb;
	}
}
