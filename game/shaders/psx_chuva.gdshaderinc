// Gota e anel de chuva, para os shaders de carro do MODERNO.
//
// Copia fiel das funcoes do psx_surface_pixel (Fase 6 do PLANO_AAA_4K), que
// continua com as dele: aquele arquivo e de todo o mundo e tem trabalho de
// outras frentes, e o carro nao pode depender de uma edicao la para ter chuva.
// Se a receita da gota mudar num, mude no outro.

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Aneis de impacto, uma gota por celula, cada celula na propria fase.
vec2 aneis_de_chuva(vec2 p, float t) {
	vec2 soma = vec2(0.0);
	vec2 base = floor(p);
	for (int i = 0; i < 4; i++) {
		vec2 c = base + vec2(float(i & 1), float(i >> 1));
		float h = hash21(c);
		float fase = fract(t * 1.1 + h);
		vec2 centro = c + vec2(hash21(c + 17.3), hash21(c + 31.7));
		vec2 d = p - centro;
		float dist = length(d) + 1e-5;
		float raio = fase * 0.46;
		float anel = smoothstep(0.055, 0.0, abs(dist - raio));
		float vida = 1.0 - fase;
		soma += (d / dist) * anel * vida * vida;
	}
	return soma;
}

// Uma camada de gotas paradas: xy = desvio da normal, z = mascara da gota.
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
	d.y *= mix(1.0, d.y > 0.0 ? 0.55 : 1.35, escorre);
	float r2 = dot(d, d);
	if (r2 >= 1.0) {
		return vec3(0.0);
	}
	float borda = smoothstep(1.0, 0.7, r2);
	return vec3(d * (0.35 + 0.65 * r2), borda);
}

// Gotas paradas numa chapa, projetadas pela face dominante no espaco do objeto.
// Devolve em xyz o desvio da normal em espaco LOCAL, e em w a mascara.
// `px_escala` corta o desenho quando a celula fica menor que um pixel.
vec4 gotas_na_chapa(vec3 pos_local, vec3 normal_local, float cobertura) {
	vec3 nl = normalize(normal_local);
	vec3 an = abs(nl);
	vec2 plano;
	vec3 eixo_u;
	vec3 eixo_v;
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
	vec2 p1 = plano * 38.0;
	vec2 p2 = plano * 71.0 + 13.7;
	float px = length(fwidth(p1));
	float nitido1 = 1.0 - smoothstep(0.22, 0.45, px);
	float nitido2 = 1.0 - smoothstep(0.22, 0.45, px * 1.87);
	vec3 g1 = camada_de_gotas(p1, cobertura * 0.5, escorre);
	vec3 g2 = camada_de_gotas(p2, cobertura * 0.7, escorre);
	g1.z *= nitido1;
	g2.z *= nitido2;
	vec3 g = g1.z >= g2.z ? g1 : g2;
	return vec4(eixo_u * g.x + eixo_v * g.y, g.z);
}
