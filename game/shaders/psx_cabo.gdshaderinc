// O cabo de rua ao vento (KitRede). Incluido pelo psx_surface e pelo
// psx_surface_pixel, e ligado so no material que tem `modo_cabo`.
//
// A fisica
// --------
// Cabo pendurado balanca como pendulo em volta da corda entre os dois postes, e
// o vao inteiro vai junto: o primeiro modo e o que o olho ve. O periodo e o de
// um pendulo com o comprimento equivalente da flecha (~0,83 f), entao o vao
// esticado da media treme rapido e o ramal barrigudo de casa vai devagar, sem
// ninguem calibrar cada um.
//
// O vento empurra o cabo para o lado de uma media (a flecha fica deitada, o
// "blowout") e a rajada oscila em volta dela. Girar em volta da corda por um
// angulo `a` leva o ponto de profundidade `p` a `p sin a` para o lado e o sobe
// `p (1 - cos a)`. Um segundo modo, pequeno e mais rapido, com no no meio do
// vao, tira o cabo de parecer uma barra dura.
//
// O empurrao vai na direcao do vento, e nao na perpendicular do cabo: a parte
// ao longo do cabo desliza o tubo por dentro dele mesmo e nao aparece, e o que
// sobra e exatamente a componente perpendicular — a que o vento faz de verdade.
//
// A chuva (psx_chuva) e temporal: o vento sobe junto.
//
// O que cada vertice traz (KitRede._uv2)
//   UV2.x = t (0..1 no vao) + floor(profundidade abaixo da corda, mm)
//   UV2.y = fase (0..1)     + floor(flecha do vao, mm)
//   COLOR.a = raio do cabo / 5 cm
// Profundidade zero e ponta de vao ou peca rigida (jumper, estai): nao anda.

vec3 cabo_ao_vento(vec3 vertice, vec2 uv2, vec3 mundo, float forca, float chuva,
		float tempo, vec2 vento_dir) {
	float t = fract(uv2.x);
	float prof = floor(uv2.x) * 0.001;
	if (prof <= 0.0) {
		return vertice;
	}
	float flecha = max(floor(uv2.y) * 0.001, 0.04);
	float fase = fract(uv2.y) * 6.2831853;
	float omega = sqrt(9.81 / (0.83 * flecha));
	float temporal = 1.0 + 1.8 * clamp(chuva, 0.0, 1.0);
	// A frente de rajada que atravessa a cidade (a mesma da copa), em escala
	// larga: dentro de um vao ela quase nao muda, e o vao anda em bloco.
	float frente = 0.5 + 0.5 * sin(dot(mundo.xz, vento_dir) * 0.02 - tempo * 1.1);
	float rajada = (0.55 + 0.45 * sin(tempo * 0.21 + fase * 0.37))
		* (0.75 + 0.5 * frente * frente);
	float ang = forca * temporal * rajada * (0.6 + 0.4 * sin(tempo * omega + fase));
	float lateral = prof * sin(ang);
	lateral += flecha * 0.05 * forca * temporal
		* sin(tempo * omega * 2.3 + fase * 1.7) * sin(6.2831853 * t);
	vertice.xz += vento_dir * lateral;
	vertice.y += prof * (1.0 - cos(ang));
	return vertice;
}

// Fio de 1 cm a 30 m e menos que um pixel: some e volta a cada passo, e o cabo
// vira tracejado. Aqui o tubo engorda o bastante para nunca ficar mais fino que
// ~0,6 px. De perto nada muda (o raio real ja e maior que isso).
vec3 cabo_espessura_minima(vec3 vertice, vec3 normal, float raio, mat4 modelview,
		mat4 projecao, vec2 tela) {
	vec4 clip = projecao * modelview * vec4(vertice, 1.0);
	float px = 2.0 * max(clip.w, 0.01) / (projecao[1][1] * max(tela.y, 1.0));
	float extra = max(0.6 * px - raio, 0.0);
	return vertice + normal * extra;
}
