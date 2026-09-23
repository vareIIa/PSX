// Superficie PSX — vertex snapping, UV afim e luz por vertice.
// Contrato em docs/ART-BIBLE.md secoes 3, 4 e 7. Guia em .claude/skills/psx-render.
//
// O dither NAO mora aqui. fragment() roda antes da luz ser aplicada, entao o padrao
// sairia multiplicado pela iluminacao. Ele vive em post_psx.gdshader, que e onde o
// PS1 o aplicava: na escrita do framebuffer.

shader_type spatial;
render_mode vertex_lighting, specular_disabled, shadows_disabled, diffuse_lambert, cull_back;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec2 uv_tile = vec2(1.0, 1.0);

// ART-BIBLE secao 3 — metade da resolucao interna de 480x270
uniform vec2 snap_resolution = vec2(240.0, 135.0);
uniform bool use_snap = true;

// ART-BIBLE secao 4 — desligar em malha muito subdividida ou colada na camera
uniform bool use_affine = true;

// --- interruptor de estilo ---------------------------------------------------
// O preset de estilo (Opcoes > Video) manda nestes tres. Sao `global uniform`:
// uma chamada de RenderingServer alcanca TODO material de uma vez, sem varrer o
// disco nem guardar registro de materiais.
//
// Eles multiplicam a decisao local em vez de substitui-la. Isso importa: a mao
// em primeira pessoa e a arma tem `use_snap = false` por motivo proprio, e um
// global que sobrescrevesse ligaria o tremor justamente onde ele da enjoo. O
// global so sabe DESLIGAR; quem liga continua sendo o material.
global uniform bool psx_snap;
global uniform bool psx_affine;
// Escala a grade de snap junto com a resolucao interna. Sem isto, subir a
// resolucao mantendo a grade em 240x135 faz o tremor sumir sozinho, porque o
// vertice passa a cair em pixels cada vez menores.
global uniform float psx_snap_escala;

uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.0;

// Vento. Zero em tudo que nao e folha, e por isso a cidade inteira continua
// imovel: o custo e uma comparacao por vertice num shader que ja roda.
//
// O balanco vem da posicao em MUNDO, e nao do vertice local. As folhagens de um
// chunk sao fundidas numa malha so, entao a origem do objeto nao diz nada sobre
// onde cada arvore esta; usando a posicao de mundo, duas arvores vizinhas
// entram fora de fase sozinhas e a copa nao pulsa em bloco.
//
// COLOR.a carrega a rigidez: 0 no tronco, 1 na ponta do galho. E por isso que
// ALPHA nao le COLOR.a — quem precisa de recorte usa o alfa da textura.
uniform float vento_forca : hint_range(0.0, 1.0) = 0.0;
uniform float vento_velocidade : hint_range(0.0, 6.0) = 1.0;

// Direcao do vento no plano, a mesma para todo material que balanca. Sem uma
// direcao comum, a arvore vai para um lado e o balanco do parquinho para outro,
// e o jogador le dois efeitos em vez de um vento.
const vec2 VENTO_DIR = vec2(0.82, 0.57);

// Vitrine, maquina de venda e janela acesa. Sao a assinatura da rua japonesa
// noturna da referencia: fonte quente pontual contra fundo verde escuro.
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy : hint_range(0.0, 8.0) = 0.0;

// Celula de atlas por INSTANCIA (PLANO_MERCADO_AAA, F2). O produto da loja e uma
// MultiMesh por forma com o rotulo de cada unidade num atlas; a instancia manda
// (canto u, canto v, largura, altura) da celula em INSTANCE_CUSTOM. Desligado,
// o material se comporta como sempre — e fora de MultiMesh INSTANCE_CUSTOM e
// zero, entao so quem liga paga. Nome identico nas duas variantes.
uniform bool usa_celula = false;

varying vec2 uv_affine;
varying float w_affine;

void vertex() {
	if (usa_celula) {
		UV = INSTANCE_CUSTOM.xy + UV * INSTANCE_CUSTOM.zw;
	}
	if (vento_forca > 0.0) {
		vec3 mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float fase = mundo.x * 0.31 + mundo.z * 0.23;
		// Duas ondas em razao irracional. Uma so tem periodo audivel: em dez
		// segundos o olho aprende o ritmo e a arvore vira metronomo.
		float balanco = sin(TIME * vento_velocidade + fase)
			+ 0.45 * sin(TIME * vento_velocidade * 1.73 + fase * 1.31);
		// Rajada lenta por cima, para o vento ter momentos de calmaria. E o que
		// separa "arvore animada" de "arvore com vento".
		float rajada = 0.65 + 0.35 * sin(TIME * 0.21 + mundo.x * 0.02);
		// O desvio sai em eixos de MUNDO e entra em VERTEX, que e local. Vale
		// porque a malha da cidade so e transladada, nunca girada: o no do chunk
		// tem posicao e mais nada. Uma folhagem dentro de um no girado precisaria
		// converter, e por isso arvore so existe em chunk.
		vec2 desvio = VENTO_DIR * (balanco * rajada * vento_forca * COLOR.a);
		VERTEX.x += desvio.x;
		VERTEX.z += desvio.y;
		// A copa desce um pouco quando e empurrada, senao o galho estica.
		VERTEX.y -= length(desvio) * 0.25;
	}

	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);

	// Snap so vale a pena a frente do plano proximo. Atras dele a divisao por w
	// inverte o sinal e a geometria explode em NaN.
	if (use_snap && psx_snap && clip.w > 0.0) {
		vec3 ndc = clip.xyz / clip.w;
		vec2 grade = snap_resolution * psx_snap_escala;
		ndc.xy = floor(ndc.xy * grade) / grade;
		clip = vec4(ndc * clip.w, clip.w);
	}
	POSITION = clip;

	// Pre-multiplicar por w cancela a correcao de perspectiva do rasterizador.
	// O hardware entrega toda varying como linear(V/w) / linear(1/w); passando
	// V = UV*w o numerador vira linear(UV), e dividir pela varying w reconstroi
	// interpolacao linear em espaco de tela, que e o que o PS1 fazia por nao ter
	// divisor por pixel.
	w_affine = clip.w;
	uv_affine = UV * uv_tile * clip.w;
}

void fragment() {
	vec2 uv = (use_affine && psx_affine) ? (uv_affine / w_affine) : (UV * uv_tile);
	vec4 texel = texture(albedo_tex, uv) * tint;

	// COLOR carrega o tint por vertice. E o que multiplica variantes de material
	// sem multiplicar arquivos de textura. Ver skill psx-assets.
	ALBEDO = texel.rgb * COLOR.rgb;

	if (alpha_cutoff > 0.0) {
		// So o alfa da textura. COLOR.a e a rigidez ao vento, nao transparencia:
		// multiplicar aqui faria a ponta da folha recortada sumir junto.
		ALPHA = texel.a;
		// O limiar AFROUXA com a distancia, e isso conserta a mata que se
		// desmancha.
		//
		// Recorte por alfa e minificacao nao se dao: longe, um texel na tela
		// cobre dezenas de texels da textura, e o mipmap entrega a MEDIA deles.
		// Numa folha recortada essa media fica em torno de 0,4 -- logo abaixo
		// do limiar de 0,45 -- entao quase toda a folha e descartada e sobram
		// so os pontos mais densos. O que aparece na tela nao e mata rala: sao
		// lascas de verde soltas no ar, sem tronco e sem pe, porque o que
		// segurava elas foi descartado junto. Na abertura da Estrada Velha isso
		// lia como "matos voando" no primeiro plano da cena.
		//
		// Perto o limiar continua inteiro: e la que o recorte e o trabalho todo
		// -- e ele que tira a silhueta de caixa da copa. Longe, a silhueta ja e
		// dada pela forma da massa, e recortar so subtrai.
		ALPHA_SCISSOR_THRESHOLD = alpha_cutoff
			* mix(1.0, 0.34, smoothstep(14.0, 52.0, w_affine));
	}

	if (emission_energy > 0.0) {
		// A emissao multiplica a textura em vez de somar chapado, senao a
		// superficie vira um retangulo de cor solida e perde o detalhe.
		//
		// E multiplica tambem COLOR, pelo mesmo motivo: sem isso a emissao passa
		// por cima do tint por vertice e todas as pecas de uma malha tingida
		// recebem o mesmo brilho. Numa figura humana isso apagava a diferenca
		// entre cabeca, tronco e calca e o corpo virava uma massa unica.
		EMISSION = emission_color.rgb * texel.rgb * COLOR.rgb * emission_energy;
	}

	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}
