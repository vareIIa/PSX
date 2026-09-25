// Ceu de fim de tarde da estrada. Cupula com degrade, sol baixo e faixa de
// nuvem, tudo calculado por direcao — sem textura nenhuma.
//
// Por que existe uma cupula, se o jogo pinta o ceu de cor solida
// -------------------------------------------------------------
// Porque o contrato do ART-BIBLE secao 8 ("cor do ceu igual a cor da nevoa")
// resolve o problema de a linha do horizonte denunciar o corte de desenho, e o
// preco e um ceu chapado. Numa rua noturna de nevoa isso nao custa nada: o ceu
// e um retangulo cinza atras dos predios e ninguem olha para ele.
//
// Aqui ele e o assunto do plano. A estrada corre num corredor de mata que abre
// exatamente uma fresta, no fundo, e o que se ve nessa fresta e o poente. Um
// retangulo laranja liso ali le como tela de carregamento.
//
// O contrato continua valendo, e e por isso que `cor_horizonte` DEVE ser a cor
// da nevoa do preset: na altura zero a cupula e a nevoa tem a mesma cor, e a
// juncao nao existe. O degrade so comeca acima da linha dos olhos, que e onde
// nao ha mais geometria para casar.
//
// fog_disabled
// ------------
// Sem isto a cupula, que esta a 150 m, recebe nevoa de profundidade e volta a
// ser exatamente o cinza chapado que ela veio evitar. E a unica coisa da cena
// que sai da nevoa, e sai porque ceu nao tem distancia.

shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, shadows_disabled,
	depth_draw_opaque, vertex_lighting;

// Na altura do olho. E a cor da nevoa do preset, sempre — ver o cabecalho.
uniform vec4 cor_horizonte : source_color = vec4(0.545, 0.498, 0.573, 1.0);
// A faixa quente logo acima da mata, que e de onde vem a luz da cena.
uniform vec4 cor_brasa : source_color = vec4(0.93, 0.52, 0.26, 1.0);
// O alto: azul que ja virou noite de um lado enquanto o outro ainda queima.
uniform vec4 cor_zenite : source_color = vec4(0.20, 0.19, 0.32, 1.0);
uniform vec4 cor_nuvem : source_color = vec4(0.36, 0.30, 0.36, 1.0);

// Para onde o sol esta, no plano. Normalizado, em coordenada de mundo.
uniform vec2 sol_dir = vec2(0.0, -1.0);
// Quanto a brasa se espalha em volta do sol, de 0 (so um ponto) a 1 (ceu todo).
uniform float sol_abertura : hint_range(0.05, 1.0) = 0.42;
uniform float sol_forca : hint_range(0.0, 2.0) = 1.0;
// Cobertura de nuvem, no mesmo sentido do campo do FogPreset.
// Clarao de relampago, de 0 a 1. Escrito pelo `Relampago`.
//
// Entra no FIM, depois da nuvem e antes do dither, e clareia o ceu inteiro em
// vez de so o lado de onde o raio veio: a nuvem que acende num temporal e a
// camada toda, e e por isso que um relampago atras do morro ilumina o ceu
// inteiro sem que se veja o raio. Quem recorta a mata contra esse fundo e a
// direcional do proprio Relampago, que e outra coisa.
uniform float flash : hint_range(0.0, 1.0) = 0.0;

uniform float nuvens : hint_range(0.0, 1.0) = 0.3;
uniform float tempo_nuvem = 0.006;

// O veu da nevoa no ceu baixo, de 0 a 1. Escrito pela CeuEstrada pela altura da
// camera: 1 rente ao chao, 0 acima da copa (plano aereo). De dentro de uma
// nevoa que fecha em 54 m nao se ve nuvem a dez graus do horizonte, se ve
// nevoa. Sem isto a nuvem baixa (0,62 da nevoa) aparecia pelos vaos da mata
// entre os troncos, embaixo das copas: retangulos escuros boiando a meia altura.
uniform float veu_baixo : hint_range(0.0, 1.0) = 0.0;

varying vec3 dir;

const float BAYER[16] = float[](
	 0.0,  8.0,  2.0, 10.0,
	12.0,  4.0, 14.0,  6.0,
	 3.0, 11.0,  1.0,  9.0,
	15.0,  7.0, 13.0,  5.0
);

void vertex() {
	// A cupula e centrada na camera pelo script, entao a posicao do vertice no
	// espaco do objeto JA e a direcao de visada. Nao ha nada a projetar.
	dir = normalize(VERTEX);
}

void fragment() {
	float altura = clamp(dir.y, -1.0, 1.0);

	// Degrade em dois trechos. O de baixo e curto e quente — os primeiros vinte
	// graus acima do horizonte, que e a faixa que a fresta da mata mostra. O de
	// cima e longo e frio. Um degrade unico do laranja ao azul poria o meio do
	// caminho num rosa de papel de parede.
	float t_baixo = clamp(altura / 0.22, 0.0, 1.0);
	float t_alto = clamp((altura - 0.22) / 0.78, 0.0, 1.0);
	// Curva no trecho alto: o azul fecha rapido perto do zenite e demora perto
	// do horizonte, que e como o ceu real escurece.
	t_alto = t_alto * t_alto;
	vec3 cor = mix(cor_horizonte.rgb, cor_brasa.rgb, t_baixo);
	cor = mix(cor, cor_zenite.rgb, t_alto);

	// A brasa do poente: um borrao quente em volta do azimute do sol, forte no
	// horizonte e morrendo antes do meio do ceu. E o que faz a mata do fundo
	// sair recortada em contraluz, que e o assunto da imagem.
	vec2 plano = normalize(vec2(dir.x, dir.z) + vec2(0.0001));
	float perto_do_sol = max(0.0, dot(plano, normalize(sol_dir)));
	perto_do_sol = pow(perto_do_sol, mix(14.0, 1.5, sol_abertura));
	float baixo = 1.0 - smoothstep(0.0, 0.42, altura);
	cor += cor_brasa.rgb * perto_do_sol * baixo * sol_forca;

	// Nuvem: faixas horizontais compridas, que e o que nuvem de fim de tarde e
	// vista de baixo. Duas ondas em razao irracional pelo motivo de sempre — uma
	// so tem periodo audivel e o ceu vira papel de parede listrado.
	float fase = dir.x * 3.1 + dir.z * 2.3 + TIME * tempo_nuvem;
	float banda = sin(fase) + 0.6 * sin(fase * 1.71 + altura * 9.0);
	banda *= smoothstep(0.02, 0.30, altura) * (1.0 - smoothstep(0.45, 0.95, altura));
	float massa = smoothstep(1.05 - nuvens, 1.6 - nuvens, banda + 1.0);
	// A nuvem tambem pega o poente pela borda de baixo, e nao e uma mancha
	// cinza colada: sem isto ela le como sujeira na lente.
	vec3 tom_nuvem = mix(cor_nuvem.rgb, cor_brasa.rgb * 0.9, perto_do_sol * baixo);
	cor = mix(cor, tom_nuvem, massa * 0.85);

	// Dither antes de sair. O pos-processamento ainda vai ditherar a imagem
	// inteira, mas ele trabalha sobre 32 niveis por canal: um degrade que cobre
	// meia tela chega la ja em bandas, e dither depois da banda nao desfaz
	// banda. Este e no gradiente, antes de ele existir.
	// O clarao. Multiplicado E somado: multiplicar sozinho nao tira o ceu do
	// cinza (o cinza vezes tres continua cinza, so mais claro), e somar sozinho
	// lava o degrade inteiro para branco chapado. Juntos, o ceu ACENDE mantendo
	// a forma da nuvem, que e o que se ve.
	cor = mix(cor, cor_horizonte.rgb, veu_baixo * (1.0 - smoothstep(0.0, 0.35, altura)));
	if (flash > 0.001) {
		cor = cor * (1.0 + flash * 1.25) + vec3(0.17, 0.19, 0.24) * flash;
	}

	int idx = int(mod(FRAGCOORD.y, 4.0)) * 4 + int(mod(FRAGCOORD.x, 4.0));
	cor += (BAYER[idx] / 16.0 - 0.5) * 0.02;

	ALBEDO = cor;
}
