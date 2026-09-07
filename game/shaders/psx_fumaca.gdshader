// Fumaca como geometria translucida. O jeito que o PS1 fazia.
//
// Irmao do psx_light_cone e pelo mesmo motivo: o ART-BIBLE secao 8 proibe nevoa
// volumetrica com raymarch, e a proibicao segue valendo. O que muda e o modo de
// mistura, e a diferenca importa mais do que parece.
//
//   facho de luz   blend_add    soma brilho — e luz, e luz nao esconde nada
//   fumaca         blend_mix    VELA o que esta atras — e materia, e materia
//                               esconde
//
// Com blend_add a fumaca vira um brilho branco e a sala parece cheia de neblina
// iluminada. Com blend_mix ela come o contorno de quem esta do outro lado, que
// e o efeito de sauna que este comodo pede.
//
// A camada nao fica parada. `deriva` desloca a UV com o tempo, devagar: fumaca
// parada le como decalque colado no teto, e bastam dois centimetros por segundo
// para o olho aceitar que aquilo esta se mexendo.
shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never,
	shadows_disabled, vertex_lighting;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;

uniform vec4 cor : source_color = vec4(0.82, 0.80, 0.78, 1.0);
uniform float densidade : hint_range(0.0, 2.0) = 1.0;

// Deriva da UV por segundo. X e Y separados: a camada do teto anda de lado e a
// coluna que sobe de um cigarro anda para cima.
uniform vec2 deriva = vec2(0.012, 0.006);

// A celula do atlas que esta fumaca usa, em UV: xy e o canto, zw o tamanho.
//
// Existe porque a textura e um ATLAS e a camada precisa REPETIR. Deixar a UV
// passar de 1 num atlas mostra a celula vizinha — e a vizinha aqui e uma
// mochila. O `fract` acontece antes de entrar na celula, entao a repeticao fica
// presa nos 32 pixels certos por mais que a UV corra.
uniform vec4 celula = vec4(0.0, 0.0, 1.0, 1.0);

// Quanto a placa some quando vista de raspao, de 0 a 1.
//
// Serve a coluna que sobe do cigarro, que e uma placa VERTICAL e tem de sumir
// quando o jogador contorna ela. Nao serve a camada do teto, que e horizontal:
// o jogador olha para a frente, a normal dela aponta para baixo, e o produto
// escalar entre as duas e sempre proximo de zero — com o fade ligado a camada
// simplesmente nao aparece nunca, que foi o primeiro resultado aqui.
uniform float fade_de_raspao : hint_range(0.0, 1.0) = 1.0;

// Some de longe, como o facho. Uma placa translucida no fundo do comodo entrega
// que e uma placa.
uniform float fade_inicio = 7.0;
uniform float fade_fim = 13.0;
// E some de perto, para a camera nao atravessar um vidro leitoso.
uniform float fade_perto = 0.55;

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
varying vec3 v_cor;
varying vec3 v_normal_view;
varying vec3 v_pos_view;
varying vec2 v_uv;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (use_snap && clip.w > 0.0) {
		vec3 ndc = clip.xyz / clip.w;
		ndc.xy = floor(ndc.xy * snap_resolution) / snap_resolution;
		clip = vec4(ndc * clip.w, clip.w);
	}
	POSITION = clip;

	v_alpha = COLOR.a;
	v_cor = COLOR.rgb;
	vec3 pv = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_pos_view = pv;
	v_dist = length(pv);
	v_normal_view = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);

	v_uv = UV;
}

void fragment() {
	vec2 uvt = celula.xy + fract(v_uv + deriva * TIME) * celula.zw;
	vec4 texel = texture(albedo_tex, uvt);
	float a = texel.a * v_alpha * densidade;

	// De raspao a placa some, de frente ela aparece inteira. Sem isto, olhar a
	// camada do teto quase de perfil mostra uma linha fina e dura, que e a
	// borda da geometria.
	float encaramento = abs(dot(normalize(v_normal_view), normalize(-v_pos_view)));
	a *= mix(1.0, smoothstep(0.0, 0.45, encaramento), fade_de_raspao);

	a *= 1.0 - smoothstep(fade_inicio, fade_fim, v_dist);
	a *= smoothstep(0.0, fade_perto, v_dist);

	// Dither na transparencia, como no facho. O PS1 nao tinha alfa por pixel de
	// verdade: alternava pixels num padrao ordenado, e e isso que da a fumaca
	// granulada em vez de um degrade limpo de motor moderno.
	int idx = int(mod(FRAGCOORD.y, 4.0)) * 4 + int(mod(FRAGCOORD.x, 4.0));
	a += (BAYER[idx] / 16.0 - 0.5) * 0.14;

	ALBEDO = cor.rgb * v_cor * texel.rgb;
	ALPHA = clamp(a, 0.0, 1.0);
}
