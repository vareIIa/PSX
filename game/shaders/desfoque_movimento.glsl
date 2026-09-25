// Desfoque de movimento por REPROJECAO. Criterio A15 do PLANO_AAA_4K.
//
// Por que reconstruir o movimento em vez de ler o buffer do motor
// ---------------------------------------------------------------
// O buffer de vetores de movimento do Godot so existe quando o TAA ou o FSR 2
// o pedem, e o degrau CRU da escada de qualidade nao tem nenhum dos dois. Aqui
// o rastro sai da profundidade: dela vem o ponto no mundo, dele vem onde o
// ponto estava na tela no quadro passado, e a diferenca e o rastro. Uma matriz
// resolve tudo — `vp_anterior * inverso(vp_atual)` —, e o efeito vale em todo
// degrau.
//
// E a conta se prova pixel a pixel: um poste a 5 m, com a camera andando
// 0,267 m por quadro, desloca 29,6 px na conta feita na CPU contra
// `unproject_position`, e a bancada le 30,2 px pintados por este shader.
//
// O que a reprojecao NAO sabe: o que anda JUNTO com a camera. Ela supoe o
// mundo parado, e a cabine do carro — painel, ponteiros, volante, maos, a
// coluna da porta, a meio metro da lente — recebia o MAIOR rastro da tela,
// quando devia receber zero (foto de 24/09/2026 a 70 km/h: os ponteiros
// viravam riscos). Por isso, onde o motor tem vetores de movimento por objeto
// (`vetores == 1`: o efeito os pede com `needs_motion_vectors`), o rastro sai
// deles: a cabine fica nitida, a rua borra, e o carro que cruza a rua borra
// pelo movimento dele. A reprojecao continua valendo onde nao ha vetor: no
// ceu (que nao grava vetor, e onde ja nao havia rastro) e sem o buffer.
//
// O sinal do vetor nao importa aqui: a amostragem e centrada no pixel.
//
// Leitura da COR por `imageLoad` e nao por amostrador: a amostragem e ao longo
// de uma reta de poucos pixels, e interpolacao bilinear ali custa um binding
// para suavizar um degrau que o proprio borrao apaga. A profundidade vem por
// amostrador porque textura de profundidade nao se liga como imagem.

#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform restrict readonly image2D entrada;
layout(rgba16f, set = 0, binding = 1) uniform restrict writeonly image2D saida;
layout(set = 0, binding = 2) uniform sampler2D profundidade;
// Vetores de movimento do motor, em unidades de UV (metade do recorte). So lido
// com `vetores == 1`; sem o buffer, a profundidade vai amarrada aqui so para o
// conjunto de uniformes fechar.
layout(set = 0, binding = 3) uniform sampler2D velocidade;

layout(push_constant, std430) uniform Ajustes {
	// `vp_anterior * inverso(vp_atual)`: leva um ponto do espaco de recorte
	// DESTE quadro direto para o do quadro passado, sem passar pelo mundo.
	mat4 reprojecao;
	ivec2 tamanho;
	// Fracao do deslocamento do quadro que vira rastro. Meio quadro e o
	// obturador de 180 graus do cinema; zero apaga o efeito.
	float forca;
	// Teto do rastro, em pixels. Sem teto, um giro brusco espalha a tela
	// inteira e o quadro vira sopa.
	float teto_px;
	int amostras;
	// 0 borra da cor para o alvo; 1 devolve o alvo para a cor.
	//
	// Ha dois passes e nao um porque o buffer de cor da cena NAO aceita ser
	// destino de `texture_copy` (nasce sem `CAN_COPY_TO`), e porque ler e
	// escrever a mesma imagem no mesmo dispatch e corrida: o vizinho que este
	// pixel precisa pode ja ter virado o borrao dele.
	int modo;
	// Diagnostico: 1 borra um rastro fixo de `teto_px` na horizontal, 2 pinta a
	// tela de vermelho, 3 pinta o rastro reconstruido (x no vermelho, y no
	// verde, 50 px = 1,0). Sao eles que separam "o efeito nao esta rodando" de
	// "o rastro esta saindo errado" — duas causas com o mesmo sintoma, que por
	// fora nao se distinguem.
	int depurar;
	// Muda a cada quadro, para o ruido das amostras nao ficar parado na tela:
	// ruido fixo vira textura, ruido que anda o TAA resolve.
	float semente;
	// 1: rastro pelos vetores de movimento do motor; 0: pela reprojecao.
	int vetores;
	int folga0;
	int folga1;
	int folga2;
} ajustes;

// O rastro deste pixel, em pixels de tela.
vec2 rastro_em(vec2 uv) {
	// Profundidade REVERSA: 1,0 e o plano de perto e 0,0 e o infinito. No ceu
	// nao ha ponto no mundo para reprojetar e a divisao por w explodiria.
	float z = texture(profundidade, uv).r;
	if (z <= 0.000001) {
		return vec2(0.0);
	}
	if (ajustes.vetores == 1) {
		return texture(velocidade, uv).xy * vec2(ajustes.tamanho);
	}
	// A UV cresce para BAIXO e o recorte do Vulkan tambem: y = -1 em cima.
	vec3 ndc = vec3(uv * 2.0 - 1.0, z);
	vec4 antes = ajustes.reprojecao * vec4(ndc, 1.0);
	if (abs(antes.w) < 0.000001) {
		return vec2(0.0);
	}
	vec2 uv_antes = (antes.xy / antes.w) * 0.5 + 0.5;
	return (uv - uv_antes) * vec2(ajustes.tamanho);
}

void main() {
	ivec2 p = ivec2(gl_GlobalInvocationID.xy);
	if (p.x >= ajustes.tamanho.x || p.y >= ajustes.tamanho.y) {
		return;
	}
	vec2 uv = (vec2(p) + 0.5) / vec2(ajustes.tamanho);

	vec4 centro = imageLoad(entrada, p);
	if (ajustes.modo == 1) {
		imageStore(saida, p, centro);
		return;
	}
	if (ajustes.depurar == 2) {
		imageStore(saida, p, vec4(1.0, 0.0, 0.0, 1.0));
		return;
	}
	if (ajustes.depurar == 3) {
		vec2 v = rastro_em(uv);
		imageStore(saida, p, vec4(abs(v.x) * 0.02, abs(v.y) * 0.02, 0.0, 1.0));
		return;
	}

	vec2 rastro;
	if (ajustes.depurar == 1) {
		rastro = vec2(ajustes.teto_px, 0.0);
	} else {
		rastro = rastro_em(uv) * ajustes.forca;
	}

	float comprimento = length(rastro);
	if (comprimento < 1.0 || ajustes.amostras <= 1) {
		imageStore(saida, p, centro);
		return;
	}
	if (comprimento > ajustes.teto_px) {
		rastro *= ajustes.teto_px / comprimento;
	}

	// Amostragem CENTRADA no pixel: metade do rastro para tras, metade para a
	// frente. Amostrar so para tras arrasta a imagem inteira no sentido do
	// movimento, e o mundo passa a parecer meio quadro atrasado.
	//
	// E com as amostras DESLOCADAS por pixel. Nove amostras fixas sobre quinze
	// pixels de rastro desenham nove copias do poste, cada uma com a borda dura
	// — medido, o desfoque ficava em 1,41x porque a borda continuava la, so que
	// repetida. O ruido de gradiente intercalado (Jimenez, 2014) espalha as
	// copias de um pixel para o outro, e o TAA as funde no quadro seguinte.
	float ruido = fract(52.9829189 * fract(dot(vec2(p) + ajustes.semente,
		vec2(0.06711056, 0.00583715))));
	vec4 soma = vec4(0.0);
	for (int i = 0; i < ajustes.amostras; ++i) {
		float t = (float(i) + ruido) / float(ajustes.amostras) - 0.5;
		ivec2 q = p + ivec2(rastro * t);
		q = clamp(q, ivec2(0), ajustes.tamanho - 1);
		soma += imageLoad(entrada, q);
	}

	// Peso IGUAL para toda amostra, porque e isso que um obturador faz: ele fica
	// aberto um intervalo e soma a luz de cada instante por igual. A primeira
	// versao pesava o centro quatro vezes mais que as pontas, por gosto — e o
	// borrao efetivo virava sessenta por cento do rastro. Medido na bancada: a
	// fileira de postes de 3 px, a 11 m, continuava com a borda quase inteira.
	imageStore(saida, p, soma / float(ajustes.amostras));
}
