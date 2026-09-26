## O agarrao, o fim da abertura da estrada. A mao do padre na cara do
## motorista, a frase de boas-vindas com ela ali, e ela empurrando a cabeca
## para longe e puxando para a cabecada dele, que acaba no branco.
##
## Por que existe
## --------------
## O fim era as duas maos entrando pelo buraco e o branco 0,2 s depois: a lente
## escorregava para a janela e cortava. Ninguem via mao na cara, a frase ia no
## stare, e a cabecada que leva ao branco nao existia. O pedido (etapa 3 de
## `INTRO-PADRE/PLANO_RODADA3.md`), na ordem:
##   1. a mao no rosto, entrando na visao e tapando;
##   2. a frase de boas-vindas com ela ali;
##   3. a mao empurrando a cabeca para longe, para pegar impulso;
##   4. e puxando para a cabecada dele, ate o branco.
##
## Como funciona
## -------------
## A mao presa na cara vive no espaco da LENTE. Cada chave (`CHAVES`) diz onde
## a palma fica na frente do olho, para onde os dedos apontam na tela, quanto
## eles deitam para a lente e a pose. Ela e refeita depois da camera
## (`process_priority` alto), a cada quadro, levada da lente para a cabine.
## Presa, ela anda com a cabeca sem um quadro de atraso; refeita antes da
## camera, como as outras maos, ela escorregava centimetros no puxao. Na subida,
## do parapeito ate a cara, ela sai da cabine e termina na lente.
##
## A cabeca do motorista e uma mola (`cabeca`, chamada no fim de
## `AberturaEstrada._de_dentro`). A cena poe o alvo (encolher, prensada no
## encosto, empurrada, puxada), e a mola chega com atraso e passa um nada. A mao
## vai na frente: a diferenca entre o alvo e onde a cabeca esta aparece como a
## mao escorregando na cara (`FOLGA`).
##
## No puxao a testa dele persegue a lente. A distancia da `CabecadaDoPadre` e
## refeita a cada quadro para a testa ficar a `_vao` metros da lente na normal
## do vidro, e o vao fecha acelerando. O branco cai quando a testa chega a
## `BRANCO_A` da lente, no quadro do golpe.
class_name AgarraoDoPadre
extends Node

## As chaves da mao na lente. Cada uma:
## - o meio da palma na linha dos nos (m, espaco da lente: x para a direita, y
##   para cima, z para tras);
## - o giro dos dedos na tela (graus, + para a direita: o braco vem de baixo e
##   da esquerda, do ombro direito dele);
## - quanto a ponta dos dedos deita para a lente (graus);
## - a pose (`POSES`).
##
## A mao cobre o lado direito da cara, e a cabeca vai virada por ela: o rosto
## dele fica no terco esquerdo do quadro, pela beira da mao e pelo vao dos
## dedos. Do tapa ao golpe ela NAO sai do lugar na cara: quem anda e a cabeca.
## Com a mao mudando de chave no empurrao (as versoes de antes), ela saia do
## quadro, o dedo curvado cortava no plano de perto, e no golpe os dedos
## entravam na frente da cara dele.
##
## Em ordem:
##   chega    a garra na frente da cara dele, vindo rapido, os dedos curvados
##            para a lente e a palma de vies. De palma para a lente, parada,
##            ela lia como uma placa; de palma para baixo, ficava no pe do
##            quadro;
##   tapa     espalmada na cara: os dedos por cima do olho, o vao entre o medio
##            e o anelar;
##   aperta   os dedos fechando na cara;
##   empurra  a mao sobe para a testa e empurra por ela: a palma varre a vista
##            (um quadro escuro) e deita atravessada na testa, o punho na
##            tempora esquerda e os dedos para a direita, fora do quadro. O
##            antebraco dele fica fora, a esquerda, e so entra no puxao; a vista
##            abre por baixo e ele aparece armado, no meio. Com a beira da
##            palma no alto do quadro, ela entrava e saia com a cabeca e
##            escurecia a vista no golpe. Com os dedos para cima, o antebraco
##            saia da testa reto para ele e tapava o meio do quadro. Com os dedos atravessados no
##            empurrao (as versoes de antes), as barras tapavam o meio do
##            quadro e ele ficava atras delas;
##   puxa     os dedos cravam no couro e puxam.
const CHAVES := [
	[Vector3(-0.03, -0.035, -0.18), 26.0, 40.0, &"garra"],
	[Vector3(0.022, -0.032, -0.046), 20.0, 14.0, &"tapa"],
	[Vector3(0.022, -0.03, -0.043), 20.0, 18.0, &"aperta"],
	[Vector3(0.032, 0.055, 0.035), 75.0, 30.0, &"empurra"],
	[Vector3(0.03, 0.052, 0.032), 72.0, 34.0, &"garra"],
]
## As poses da mao dele na cara (ver `MaoPosada`: [mcp, pip, dip, abre] por
## dedo, do indicador ao minimo; o polegar [radial, palmar, giro, mcp, ip]).
## Indicador e medio juntos, anelar e minimo juntos, e um vao so entre eles.
## Os quatro abertos por igual liam como grade.
const POSES := {
	&"tapa": {"dedos": [[8, 30, 20, 2], [6, 32, 22, -3], [8, 32, 22, -16], [12, 30, 20, -22]],
		"polegar": [72, 22, 34, 8, 12]},
	&"aperta": {"dedos": [[18, 44, 28, 1], [16, 46, 30, -3], [18, 46, 30, -14], [22, 44, 26, -20]],
		"polegar": [62, 30, 40, 16, 20]},
	&"empurra": {"dedos": [[4, 24, 16, 2], [2, 26, 18, -3], [4, 26, 18, -16], [8, 24, 16, -22]],
		"polegar": [70, 20, 30, 6, 10]},
	&"garra": {"dedos": [[26, 62, 44, 6], [24, 66, 46, 0], [26, 66, 44, -8], [30, 62, 40, -16]],
		"polegar": [52, 36, 44, 22, 28]},
}
## Nenhuma junta da mao chega mais perto da lente que isto (m, no eixo dela):
## o dedo curvado cortado pelo plano de perto aparecia como uma folha escura
## aberta no meio do quadro. O raio do dedo mais uma folga acima do `PERTO`.
const JUNTA_LONGE := 0.014
## A mao dele: o sangue que pegou no vidro (0 a 1), e o escuro de colada na
## cara (`MaosPodres`).
const SANGUE_NA_MAO := 0.85
## O desfoque de perto enquanto a mao esta na cara: ate onde borra (m), a
## transicao (m) e a forca. O rosto dele, a 25 cm, fica nitido; os dedos a 4 cm
## borram como borra o que encosta no olho.
const DESFOCA_PERTO := Vector3(0.13, 0.08, 0.07)
## O quanto o queixo dele recolhe no golpe (fracao do `bote` da cabecada): no
## inteiro, a testa ia na frente com a cabeca baixa, e a lente via o capuz.
const BOTE_FINAL := 0.5
## A lente seguindo a cara dele no puxao (1/s): rapida, a cara vem no meio.
const PUXA_SEGUE := 14.0
## O meio da cara, na malha da cabeca (o mesmo do stare).
const CARA_MEIO := Vector3(0.0, -0.03, -0.09)
## Para onde a lente vai no puxao: a linha dos olhos. No meio da cara, o golpe
## congelava na boca, com os olhos fora do quadro.
const MIRA_GOLPE := Vector3(0.0, 0.02, -0.09)

## A mao que estava no vidro, quando ele estoura: cai no parapeito e agarra a
## borda. Quanto acima da linha de baixo da janela e quanto para dentro (m), e
## em quanto tempo (s).
const PARAPEITO_ACIMA := 0.018
const PARAPEITO_DENTRO := 0.02
const PARAPEITO_TEMPO := 0.14

## A subida do parapeito ate a frente da cara (s), o quanto ela fica ali,
## aberta, antes de vir (s), e o bote na cara (s).
const SOBE := 0.28
const PAIRA := 0.03
const BATE := 0.08
## O arco da subida (m, para cima no carro).
const SOBE_ARCO := 0.07
## Os dedos fechando depois do tapa (s).
const APERTA := 0.28
## Do tapa a primeira silaba (s), e o silencio depois da frase (s).
const ANTES_DA_FRASE := 0.2
const DEPOIS_DA_FRASE := 0.32
## A fala: `padre_que_bom.wav` dura isto (s).
const FRASE := 2.04
## O empurrao (s), o quanto a cabeca fica la, prensada no encosto, com ele
## armado para o golpe (s), e o puxao ate o golpe (s, no maximo).
const EMPURRA := 0.24
const SEGURA := 0.28
const PUXA := 0.18
## O quanto ele leva a cabeca para tras para pegar impulso (m, na normal do
## vidro).
const ARMA := 0.2
## E quanto da antecipacao da cabecada (`CabecadaDoPadre.recua`): o tronco para
## tras e o queixo para cima. Inteira, com a cabeca ja girada ate o limite do
## pescoco, a cara ficava de perfil para a lente.
const RECUO_ARMADO := 0.5
## Os dois apertos da mao durante a frase: quando (s depois da primeira silaba)
## e quanto os dedos fecham a mais (0 a 1).
const APERTOS := [[0.3, 0.7], [1.2, 1.0]]
## O campo da lente com ele armado (fechando enquanto a cabeca vai para longe)
## e no golpe (abrindo: a cara vem mais depressa).
const FOV_ARMADO := 44.0
const FOV_GOLPE := 52.0
## A testa a isto da lente (m): o golpe. A 20 cm a cara dele enche o quadro,
## da testa ao queixo, com os olhos. Mais perto a lente via so a carne aberta e
## o forro do capuz (16 cm), ou ja estava dentro dele (8 cm).
const BRANCO_A := 0.2
## Mais perto que isto (m), a lente vai direto na cara, sem atraso: com a cara
## vindo a 2,5 m/s, a mira atrasada deixava a cara fora do quadro no golpe.
const MIRA_DIRETA := 0.35
## Do golpe ao branco (s de relogio), com o tempo do jogo quase parado
## (fracao do normal): o sangue na vista e a cara dele em cima da lente.
const GOLPE_CONGELA := 0.075
const GOLPE_ESCALA := 0.03
## A mao esquerda do motorista na frase, no espaco da lente: agarra os dedos do
## padre por baixo e pela esquerda e puxa, aos trancos, sem tirar a mao do
## lugar. O meio da palma, para onde os dedos apontam e o dorso; de onde ela
## sobe (fora do quadro); quanto depois do tapa ela reage e em quanto tempo
## sobe (s); o tranco (m) e para onde ela e arrancada no empurrao (m).
const MOTORISTA_NA_MAO := [Vector3(-0.048, -0.062, -0.08), Vector3(0.32, 0.93, 0.18),
	Vector3(-1.0, 0.0, 0.3)]
const MOTORISTA_DE := Vector3(-0.16, -0.34, -0.12)
const MOTORISTA_REAGE := 0.35
const MOTORISTA_SOBE := 0.26
const MOTORISTA_TRANCO := Vector3(-0.007, -0.009, 0.0)
const MOTORISTA_ARRANCADA := Vector3(-0.09, -0.2, 0.02)
const POSE_MOTORISTA := {"dedos": [[30, 62, 34, 4], [28, 66, 36, 0], [30, 66, 34, -3],
	[34, 62, 30, -7]], "polegar": [30, 44, 62, 18, 16]}
## A outra mao do padre, na gola, no espaco do suporte da camera (x para longe
## da janela, y para cima, z para tras), a partir do olho sem a mola da cabeca:
## o meio da palma, os dedos e o dorso; de onde ela vem; em quanto tempo (s); e
## quanto da cabeca puxada o peito acompanha (fracao).
const GOLA := [Vector3(-0.01, -0.19, -0.14), Vector3(0.55, 0.15, 0.8), Vector3(0.0, 1.0, 0.0)]
const GOLA_DE := Vector3(-0.3, -0.45, -0.35)
const GOLA_VEM := 0.2
const GOLA_SEGUE := 0.6
## O tranco do peito quando ela fecha na gola (m/s, na cabeca).
const GOLA_TRANCO := Vector3(-0.06, -0.04, -0.1)
## O mundo com a mao na orelha: o corte do passa-baixa (Hz) fechado e aberto, o
## bus proprio dos lacos do fogo, e quanto o coracao sobe (dB).
const ABAFA_CORTE := 650.0
const ABAFA_ABERTO := 20000.0
const BUS_ABAFA := &"AgarraoAbafado"
const CORACAO_ABAFADO := 4.0
## O sangue na vista no golpe: o respingo do ponto do golpe para fora, em raios
## desiguais, e gotas soltas em volta; vermelho escuro, com o brilho de
## molhado. `abre` vai de 0 a 1 no tempo do golpe.
const SANGUE_NA_VISTA := """
shader_type canvas_item;
uniform float abre = 0.0;
uniform vec2 centro = vec2(0.5, 0.45);
uniform float semente = 3.1;

float h(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + semente) * 43758.5453);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x),
		mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float asp = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 p = (UV - centro) * vec2(asp, 1.0);
	float r = length(p);
	float ang = atan(p.y, p.x);
	float raios = pow(ruido(vec2(ang * 6.0 + 11.0, 1.3)), 2.5);
	float alcance = abre * (0.22 + 0.75 * raios);
	float borda = (ruido(p * 9.0) - 0.5) * 0.1 + (ruido(p * 31.0) - 0.5) * 0.03;
	float mancha = 1.0 - smoothstep(alcance - 0.06, alcance, r + borda);
	vec2 g = p * 11.0;
	vec2 gi = floor(g);
	vec2 gf = fract(g) - 0.5 - (vec2(h(gi + 3.1), h(gi + 7.7)) - 0.5) * 0.5;
	float tem = step(0.78, h(gi)) * step(length(gi) / 11.0, abre * 1.05);
	float gota = tem * (1.0 - smoothstep(0.1, 0.2 + 0.1 * h(gi + 1.7), length(gf)));
	float a = clamp(max(mancha * 0.94, gota * 0.9), 0.0, 1.0);
	// Escuro, quase preto nas poças: sobre a carne da cara dele o vermelho vivo
	// sumia. O brilho de molhado e o que diz que e liquido.
	vec3 cor = mix(vec3(0.2, 0.012, 0.01), vec3(0.045, 0.0, 0.0), ruido(p * 18.0));
	cor += vec3(0.35, 0.12, 0.1) * pow(ruido(p * 34.0 + 2.0), 9.0) * max(mancha, gota);
	COLOR = vec4(cor, a);
}
"""

## A cabeca do motorista, no espaco do suporte da camera (x para longe da
## janela, y para cima, z para tras), e o giro dela (rad: arfar, virar,
## deitar), em cada momento.
##   encolhe   a mao subindo: ele se encolhe para longe e baixa o queixo;
##   presa     prensada no encosto pela mao e virada para a direita, durante a
##             frase (o rosto dele no terco esquerdo);
##   empurrada jogada para longe, a nuca no encosto, e os olhos nele, com a
##             cara no meio do quadro. Virada e deitada de verdade (a primeira
##             versao), ele caia no canto de baixo e a lente via o teto, justo
##             no segundo em que ele arma o golpe;
##   puxada    arrancada para a janela, para a testa dele, desvirando: so deita,
##             sem arfar nem virar, para a cara dele chegar no meio do quadro.
const ENCOLHE := [Vector3(0.03, -0.012, 0.025), Vector3(-0.05, -0.09, -0.04)]
const PRESA := [Vector3(0.045, 0.0, 0.05), Vector3(0.03, -0.22, -0.06)]
const EMPURRADA := [Vector3(0.2, 0.0, 0.09), Vector3(-0.07, 0.08, -0.08)]
## A nuca batendo no encosto no fim do empurrao: o quique (m/s).
const ENCOSTO_QUIQUE := Vector3(-0.3, 0.05, -0.35)
const PUXADA := [Vector3(-0.3, -0.02, -0.07), Vector3(0.0, 0.0, 0.18)]
## O tranco do tapa na cabeca: velocidade (m/s) e giro (rad/s).
const TAPA_TRANCO := [Vector3(0.35, 0.02, 0.55), Vector3(0.4, -0.9, -0.6)]
## A mola da cabeca: rigidez (1/s2) e amortecimento (1/s). Solta, ela e a
## cabeca dele; na mao, e a mao que manda.
const MOLA_SOLTA := Vector2(170.0, 17.0)
const MOLA_NA_MAO := Vector2(650.0, 40.0)
const MOLA_PUXAO := Vector2(1400.0, 55.0)
## A cabeca brigando com a mao na frase: amplitude (m e rad).
const LUTA := Vector2(0.004, 0.02)
## Quanto da diferenca entre o alvo da cabeca e a cabeca aparece como a mao
## escorregando na cara, e o maximo (m; na direcao da lente, menos).
const FOLGA := 0.3
const FOLGA_MAX := Vector2(0.012, 0.004)
## O plano de perto da lente durante o agarrao (m): a mao fica a 4 cm do olho.
const PERTO := 0.005

signal golpeou

var _cena: AberturaEstrada
var _cam: Camera3D
var _cabine: Node3D
var _carro: Node3D
var _mao: BracoVivo
var _cab: CabecadaDoPadre
var _rosto: CabecaDoPadre
var _capuz: CapuzMacabro

var _ligado: bool = false
var _t: float = 0.0
## Da subida: a pegada de onde a mao saiu (cabine) e o quanto ja veio (0 a 1).
var _de: Dictionary = {}
var _vem: float = 0.0
## Em que chave a mao esta (0 a CHAVES.size() - 1, fracionario entre elas).
var _chave: float = 0.0
## A cabeca: o alvo, onde ela esta e a velocidade, em posicao e em giro.
var _alvo := [Vector3.ZERO, Vector3.ZERO]
var _pos := Vector3.ZERO
var _vel := Vector3.ZERO
var _giro := Vector3.ZERO
var _vgiro := Vector3.ZERO
var _mola := MOLA_SOLTA
var _luta: float = 0.0
## O aperto a mais dos dedos (0 a 1), por cima da chave.
var _aperto: float = 0.0
var _base_suporte := Basis.IDENTITY
## O puxao: a testa perseguindo a lente.
var _perseguindo: bool = false
var _vao: float = 0.0
var _t_puxa: float = 0.0
var _perto_antes: float = INF
## O que a lente tinha antes, para devolver no golpe: o plano de perto e o
## desfoque de perto.
var _near_antes: float = 0.08
var _dof_antes: Array = []
var _cull_janela: int = -1
## O sangue na vista, do golpe ao branco.
var _vista: CanvasLayer
## A pose da lente sem a mola da cabeca (o peito, para a gola).
var _lente_crua := Transform3D.IDENTITY
## A mao esquerda do motorista: o braco, de onde subiu (espaco do motorista), o
## quanto ja veio (-1 fora), a forca dos trancos e o quanto foi arrancada.
var _mot: BracoVivo
var _mot_de: Dictionary = {}
var _mot_vem: float = -1.0
var _mot_forca: float = 0.0
var _mot_solta: float = 0.0
## A outra mao do padre, na gola: o braco, de onde veio (cabine) e o quanto ja
## veio (-1 fora).
var _gola: BracoVivo
var _gola_de: Dictionary = {}
var _gola_vem: float = -1.0
## O mundo abafado pela mao na orelha: o filtro posto no bus Ambiente e o bus
## proprio por onde passam os lacos do fogo (`_abafar`).
var _filtro_ambiente: AudioEffectLowPassFilter
var _filtro_lacos: AudioEffectLowPassFilter
var _lacos_desviados: Array[AudioStreamPlayer] = []


## Monta o agarrao na cena (depois do laco dela, que mexe na camera).
static func montar(cena: AberturaEstrada, mao: BracoVivo, cab: CabecadaDoPadre) -> AgarraoDoPadre:
	var g := AgarraoDoPadre.new()
	g.name = "AgarraoDoPadre"
	g.process_priority = 200
	g._cena = cena
	g._cam = cena._cam
	g._carro = cena._carro
	g._cabine = cena._carro.cabine
	g._mao = mao
	g._cab = cab
	g._rosto = cena._padre.get_meta(&"rosto", null) as CabecaDoPadre
	g._capuz = cena._capuz_padre
	cena.add_child(g)
	return g


## A mao que estava espalmada no vidro, no estouro: cai no parapeito e agarra a
## borda de dentro, no mesmo ponto da janela. `a` e a abertura (espaco da
## cabine), `n` a normal dela para fora.
static func mao_ao_parapeito(b: BracoVivo, a: Dictionary, n: Vector3, cima: Vector3) -> void:
	if b == null or b.pegada.is_empty() or a.is_empty():
		return
	var pts: PackedVector3Array = a["pontos"]
	var baixo := INF
	for p: Vector3 in pts:
		baixo = minf(baixo, p.dot(cima))
	var o: Vector3 = b.pegada["o"]
	var sobre := o + cima * (baixo + PARAPEITO_ACIMA - o.dot(cima)) - n * PARAPEITO_DENTRO
	var d := (-n * 0.8 - cima * 0.2).normalized()
	b.ir(BracoVivo.pega(sobre, d, cima, &"garra"), PARAPEITO_TEMPO)
	b.dedos_vivos = 0.5
	b.remove_meta(&"no_vidro")
	# Ela desce pelos cacos com o sangue do vidro: dali ate a cara, a mesma mao
	# suja (antes, no stare, ela ainda estava branca na beira do quadro).
	b.set_instance_shader_parameter(&"sangue", SANGUE_NA_MAO)


## A cabeca do motorista por cima da pose da lente (`xf`, mundo). `suporte` e
## a base do suporte da camera, onde a mola mora. Fora do agarrao, `xf` passa.
func cabeca(xf: Transform3D, suporte: Basis) -> Transform3D:
	_base_suporte = suporte
	_lente_crua = xf
	if not _ligado:
		return xf
	return Transform3D(xf.basis * Basis.from_euler(_giro), xf.origin + suporte * _pos)


## O agarrao inteiro, do parapeito ao branco. Volta no golpe.
func rodar() -> void:
	_ligado = true
	_near_antes = _cam.near
	_cam.near = PERTO
	_mao.set_meta(&"na_lente", true)
	_mao.visible = true
	_mao.set_instance_shader_parameter(&"sangue", SANGUE_NA_MAO)
	_mao.set_instance_shader_parameter(&"perto_da_lente", 1.0)
	_de = _mao.pegada.duplicate()
	_vem = 0.0
	_chave = 0.0
	_mao.tremor = 0.35
	# A garra pairando na frente da cara dele: os dedos vivos, famintos.
	_mao.dedos_vivos = 1.6
	# O obturador abre do agarrao em diante: o bote da mao e o puxao borram.
	# O que anda com a lente (a mao presa) sai nitido pelos vetores de
	# movimento.
	Lente.travar_desfoque(Lente.obturador())
	_desfocar_perto(true)
	# A luz de baixo da janela e a da cara dele: a mao que passa rente a ela,
	# a um palmo da lente, estourava branca.
	if _cena._luz_janela != null:
		_cull_janela = _cena._luz_janela.light_cull_mask
		_cena._luz_janela.light_cull_mask = _cull_janela & ~BracoVivo.CAMADA
	_medir()

	# --- sobe do parapeito, acelerando: a garra entra no quadro na frente da
	# cara dele e ja vem.
	_cena._marca("mao_sobe")
	_tw().tween_property(self, "_vem", 1.0, SOBE) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_cena._som(&"rangido_osso", -12.0, 0.85)
	await _cena._esperar(SOBE * 0.45)
	# Ele ve a mao vindo e se encolhe, tarde.
	_alvo = ENCOLHE.duplicate()
	_cena._tremor = maxf(_cena._tremor, 0.35)
	await _cena._esperar(SOBE * 0.55)
	_cena._foto("10i_mao_sobe")
	await _cena._esperar(PAIRA)

	# --- o bote na cara.
	_tw().tween_property(self, "_chave", 1.0, BATE) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await _cena._esperar(BATE)
	_cena._marca("mao_na_cara")
	_mola = MOLA_NA_MAO
	_vel += TAPA_TRANCO[0]
	_vgiro += TAPA_TRANCO[1]
	_alvo = PRESA.duplicate()
	_cena._som(&"mao_na_cara", 0.0)
	# A palma tapa a orelha: o mundo abafa.
	_abafar(true, 0.06)
	_cena._tremor = maxf(_cena._tremor, 0.55)
	_cena._soco = 5.0
	_cena._animar(&"_soco", 0.0, 0.3, Tween.TRANS_SINE)
	_mao.dedos_vivos = 0.25
	_mao.tremor = 0.7
	_tw().tween_property(self, "_chave", 2.0, APERTA) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	get_tree().create_timer(0.1).timeout.connect(
		func() -> void: _cena._som(&"respira_abafado", -10.0))
	await _cena._esperar(0.06)
	_cena._foto("10j_mao_na_cara")
	_no_quadro("tapa")
	_cena._medir_rosto("mao_na_cara")
	# Ele reage: a mao esquerda sobe e agarra os dedos do padre.
	get_tree().create_timer(MOTORISTA_REAGE - 0.06).timeout.connect(_motorista_agarra)
	await _cena._esperar(ANTES_DA_FRASE - 0.06)

	# --- a frase, com a mao na cara. Ele chega mais perto para dizer.
	_cena._marca("frase")
	_luta = 1.0
	if _capuz != null:
		_tw().tween_property(_capuz, "sorriso", 0.35, 0.18)
	if _rosto != null:
		_rosto.falar(CabecaDoPadre.FALA_QUE_BOM)
	_cena._som(&"padre_que_bom", 1.0)
	var t_frase := _tw().set_parallel(true)
	t_frase.tween_property(_cab, "distancia", _cab.distancia - 0.05, FRASE) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	t_frase.tween_property(_cab, "tombo", _cab.tombo - 0.2, FRASE) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	# Dois apertos no meio da frase: os dedos cravam, a cabeca cede um nada.
	for ap: Array in APERTOS:
		get_tree().create_timer(float(ap[0])).timeout.connect(_apertar.bind(float(ap[1])))
	await _cena._esperar(FRASE * 0.5)
	_cena._foto("10k_frase")
	_no_quadro("frase")
	await _cena._esperar(FRASE * 0.5)
	# A boca arreganha de novo, e o silencio.
	if _capuz != null:
		_tw().tween_property(_capuz, "sorriso", 1.2, 0.3) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	await _cena._esperar(DEPOIS_DA_FRASE)

	# --- o empurrao: a palma joga a cabeca para longe, a nuca bate no encosto.
	# Ele leva a dele para tras, armado, e fica: o golpe vem dali.
	_cena._marca("empurra")
	_luta = 0.0
	_motorista_arrancado()
	_gola_agarra()
	_alvo = EMPURRADA.duplicate()
	_tw().tween_property(self, "_chave", 3.0, EMPURRA * 0.6) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	var t_rec := _tw().set_parallel(true)
	t_rec.tween_property(_cab, "recua", RECUO_ARMADO, EMPURRA + SEGURA * 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	t_rec.tween_property(_cab, "distancia", _cab.distancia + ARMA, EMPURRA + SEGURA * 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	t_rec.tween_property(_cab, "tombo", 0.0, EMPURRA + SEGURA)
	if _capuz != null:
		t_rec.tween_property(_capuz, "sorriso", 1.3, EMPURRA)
	get_tree().create_timer(EMPURRA * 0.8).timeout.connect(_bater_no_encosto)
	# A mao sai da orelha para a testa: o mundo volta inteiro, de uma vez, para o
	# golpe.
	_abafar(false, 0.14)
	_cena._som(&"cabeca_empurrada", 0.0)
	var suga := _cena._som(&"tensao_suga", -4.0)
	if suga != null:
		suga.seek(maxf(0.0, 0.55 - (EMPURRA + SEGURA + PUXA)))
	_cena._tremor = maxf(_cena._tremor, 0.6)
	# Empurrado para longe e a lente fechando: ele fica do mesmo tamanho e o
	# carro em volta foge (o "vertigo"). E o segundo do golpe armado.
	_cena._animar(&"_fov_cena", FOV_ARMADO, EMPURRA + SEGURA, Tween.TRANS_SINE)
	await _cena._esperar(EMPURRA)
	_cena._foto("10l_empurra")
	_no_quadro("empurra")
	await _cena._esperar(SEGURA * 0.6)
	_no_quadro("armado")
	await _cena._esperar(SEGURA * 0.4)

	# --- o puxao para a testa dele, e o branco no golpe.
	_cena._marca("puxa")
	_mola = MOLA_PUXAO
	var t_pux := _tw()
	t_pux.tween_method(func(k: float) -> void:
		_alvo = [EMPURRADA[0].lerp(PUXADA[0], k), EMPURRADA[1].lerp(PUXADA[1], k)],
		0.0, 1.0, PUXA).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_tw().tween_property(self, "_chave", 4.0, PUXA * 0.6)
	var t_bote := _tw().set_parallel(true)
	t_bote.tween_property(_cab, "recua", 0.0, PUXA * 0.8).set_ease(Tween.EASE_IN)
	t_bote.tween_property(_cab, "bote", BOTE_FINAL, PUXA * 0.8).set_ease(Tween.EASE_IN)
	# A lente pega a cara dele vindo, no meio do quadro, e nitida: a mao ja saiu
	# da vista, e o desfoque de perto borrava a cara no golpe.
	_mirar_rapido()
	_desfocar_perto(false)
	_vao = _testa_a_lente()
	_tw().tween_property(self, "_vao", -0.03, PUXA) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_t_puxa = 0.0
	_perseguindo = true
	var ar := _cena._som(&"puxao_ar", -2.0)
	if ar != null:
		ar.seek(maxf(0.0, 0.34 - PUXA))
	_cena._tremor = 1.0
	_cena._animar(&"_fov_cena", FOV_GOLPE, PUXA, Tween.TRANS_QUAD)
	get_tree().create_timer(PUXA * 0.5).timeout.connect(_cena._foto.bind("10m_puxa"))
	await golpeou


func _tw() -> Tween:
	return create_tween()


## Um aperto dos dedos na frase: cravam e soltam um nada, e a cabeca cede.
func _apertar(forca: float) -> void:
	if not _ligado:
		return
	var t := _tw()
	t.tween_property(self, "_aperto", forca, 0.12).set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_QUAD)
	t.tween_property(self, "_aperto", 0.0, 0.45).set_ease(Tween.EASE_IN_OUT) \
		.set_trans(Tween.TRANS_SINE)
	_vel += Vector3(0.05, -0.02, 0.08) * forca
	_vgiro += Vector3(0.1, -0.25, -0.15) * forca
	_cena._tremor = maxf(_cena._tremor, 0.3 * forca)
	_cena._som(&"mao_aperta", -7.0 - 2.0 * (1.0 - forca), 0.95 + 0.1 * forca)


## A nuca batendo no encosto no fim do empurrao.
func _bater_no_encosto() -> void:
	if not _ligado:
		return
	_vel += ENCOSTO_QUIQUE
	_cena._tremor = maxf(_cena._tremor, 0.7)
	_cena._soco = 3.0
	_cena._animar(&"_soco", 0.0, 0.22, Tween.TRANS_SINE)


## O desfoque de perto da `Lente`: liga com a mao na cara, e o golpe devolve o
## que era.
func _desfocar_perto(ligar: bool) -> void:
	var at := Lente.atributos()
	if at == null:
		return
	if ligar:
		if _dof_antes.is_empty():
			_dof_antes = [at.dof_blur_near_enabled, at.dof_blur_near_distance,
				at.dof_blur_near_transition, at.dof_blur_amount]
		at.dof_blur_near_enabled = true
		at.dof_blur_near_distance = DESFOCA_PERTO.x
		at.dof_blur_near_transition = DESFOCA_PERTO.y
		at.dof_blur_amount = DESFOCA_PERTO.z
	elif not _dof_antes.is_empty():
		at.dof_blur_near_enabled = _dof_antes[0]
		at.dof_blur_near_distance = _dof_antes[1]
		at.dof_blur_near_transition = _dof_antes[2]
		at.dof_blur_amount = _dof_antes[3]


## A lente passa a seguir o meio da cara dele depressa, saindo de onde a mira
## do stare estava (sem salto).
func _mirar_rapido() -> void:
	if _rosto == null or not _cena._foco_de.is_valid():
		return
	var mira := {"p": _cena._foco_de.call() as Vector3}
	_cena._foco_peso = 1.0
	var rosto := _rosto
	var cena := _cena
	_cena._foco_de = func() -> Vector3:
		if is_instance_valid(rosto):
			var r := rosto.global_transform * MIRA_GOLPE
			var k := 1.0 - exp(-cena.get_process_delta_time() * PUXA_SEGUE)
			if cena._cam.global_position.distance_to(r) < MIRA_DIRETA:
				k = 1.0
			mira.p = (mira.p as Vector3).lerp(r, k)
		return mira.p


## A cena esta gravando (`--susto-fotos` ou `--susto-rajada`): so entao as
## medidas vao para o log.
func _bancada() -> bool:
	return not _cena._pasta_fotos.is_empty() or not _cena._pasta_rajada.is_empty()


## Bancada: onde as coisas estao, no espaco da lente, no comeco do agarrao.
func _medir() -> void:
	if not _bancada():
		return
	var inv := _cam.global_transform.affine_inverse()
	var ombro := _cabine.global_transform * _mao.ombro
	print("[agarrao] lente: cara %s testa %s ombro %s mao %s" % [
		inv * (_rosto.global_transform * CARA_MEIO) if _rosto != null else Vector3.INF,
		inv * _cab.testa(), inv * ombro,
		inv * (_cabine.global_transform * (_mao.pegada["o"] as Vector3))])


## Bancada: onde o meio da cara dele cai na tela agora (-1 a 1, y para cima),
## e a distancia dele a lente.
func _no_quadro(marca: String) -> void:
	if _rosto == null or not _bancada():
		return
	var p := _rosto.global_transform * CARA_MEIO
	var px := _cam.unproject_position(p)
	var vp := get_viewport().get_visible_rect().size
	var frente := -_rosto.global_basis.z.normalized()
	var olha := rad_to_deg(frente.angle_to(_cam.global_position - p))
	for b: BracoVivo in [_mot, _gola]:
		if b != null and b.visible and not b.pegada.is_empty():
			var bp := (b.get_parent() as Node3D).global_transform * (b.pegada["o"] as Vector3)
			var bpx := _cam.unproject_position(bp)
			print("[agarrao] %s: %s na tela (%.2f, %.2f), atras=%s" % [marca, b.name,
				bpx.x / vp.x * 2.0 - 1.0, 1.0 - bpx.y / vp.y * 2.0, _cam.is_position_behind(bp)])
	print("[agarrao] %s: cara na tela (%.2f, %.2f), a %.2f m, campo %.1f, olhando %.0f graus fora da lente" % [
		marca, px.x / vp.x * 2.0 - 1.0, 1.0 - px.y / vp.y * 2.0,
		_cam.global_position.distance_to(p), _cam.fov, olha])


## O golpe: a lente volta ao que era debaixo do branco.
func _devolver_a_lente() -> void:
	_desfocar_perto(false)
	_cam.near = _near_antes
	Lente.travar_desfoque(0.0)
	if _cull_janela >= 0 and _cena._luz_janela != null:
		_cena._luz_janela.light_cull_mask = _cull_janela
	_desabafar()
	if _vista != null and is_instance_valid(_vista):
		_vista.queue_free()
	_vista = null


## A mao tapando a orelha: a chuva, o vento e o fogo passam por um passa-baixa
## que fecha em `tempo`; soltando (`fechar` falso), o mundo volta inteiro. O
## coracao e o drone ficam de fora: sao de dentro dele. Um filtro proprio no
## `Ambiente`, por cima do do menu (`AudioDirector`), e um bus proprio para os
## lacos do fogo, que moram no `SFX`: bus so envia para bus de antes dele, e o
## `Ambiente` nao pode passar pelo nosso.
func _abafar(fechar: bool, tempo: float) -> void:
	if fechar and _filtro_ambiente == null:
		var i := AudioServer.get_bus_index(&"Ambiente")
		if i >= 0:
			_filtro_ambiente = AudioEffectLowPassFilter.new()
			_filtro_ambiente.cutoff_hz = ABAFA_ABERTO
			AudioServer.add_bus_effect(i, _filtro_ambiente)
		if AudioServer.get_bus_index(BUS_ABAFA) < 0:
			var j := AudioServer.get_bus_count()
			AudioServer.add_bus(j)
			AudioServer.set_bus_name(j, BUS_ABAFA)
			AudioServer.set_bus_send(j, &"SFX")
			_filtro_lacos = AudioEffectLowPassFilter.new()
			_filtro_lacos.cutoff_hz = ABAFA_ABERTO
			AudioServer.add_bus_effect(j, _filtro_lacos)
		for p: AudioStreamPlayer in _cena._lacos:
			if is_instance_valid(p) and p != _cena._drone and p != _cena._coracao_tensao \
					and p.bus == &"SFX":
				p.bus = BUS_ABAFA
				_lacos_desviados.append(p)
	var alvo := ABAFA_CORTE if fechar else ABAFA_ABERTO
	if _bancada():
		print("[agarrao] %s: filtro no Ambiente=%s, %d lacos no bus %s" % [
		"abafa" if fechar else "desabafa", _filtro_ambiente != null, _lacos_desviados.size(),
		BUS_ABAFA])
	for f: AudioEffectLowPassFilter in [_filtro_ambiente, _filtro_lacos]:
		if f == null:
			continue
		var de := f.cutoff_hz
		# Em oitavas, e nao em Hz: linear em Hz o filtro so fechava no fim.
		create_tween().tween_method(func(k: float) -> void:
			f.cutoff_hz = exp(lerpf(log(de), log(alvo), k)), 0.0, 1.0, maxf(tempo, 0.01))
	# Com a orelha tapada o coracao se ouve mais (o som de dentro do corpo).
	if _cena._coracao_tensao != null and is_instance_valid(_cena._coracao_tensao):
		create_tween().tween_property(_cena._coracao_tensao, "volume_db",
			_cena._coracao_tensao.volume_db + (CORACAO_ABAFADO if fechar else -CORACAO_ABAFADO),
			maxf(tempo, 0.01))


## Tira o filtro do `Ambiente`, devolve os lacos ao `SFX` e desmonta o bus.
func _desabafar() -> void:
	var i := AudioServer.get_bus_index(&"Ambiente")
	if _filtro_ambiente != null and i >= 0:
		for e in range(AudioServer.get_bus_effect_count(i) - 1, -1, -1):
			if AudioServer.get_bus_effect(i, e) == _filtro_ambiente:
				AudioServer.remove_bus_effect(i, e)
	_filtro_ambiente = null
	for p: AudioStreamPlayer in _lacos_desviados:
		if is_instance_valid(p):
			p.bus = &"SFX"
	_lacos_desviados.clear()
	var j := AudioServer.get_bus_index(BUS_ABAFA)
	if j >= 0:
		AudioServer.remove_bus(j)
	_filtro_lacos = null


func _exit_tree() -> void:
	# Uma cena abortada no meio do agarrao nao pode deixar o mundo abafado nem o
	# tempo parado.
	_desabafar()
	if Engine.time_scale < 1.0:
		Engine.time_scale = 1.0


## A testa dele a lente, na normal do vidro (m, positivo: a testa ainda esta
## do lado de fora da lente).
func _testa_a_lente() -> float:
	var n := (_carro.global_basis * _cab.normal()).normalized()
	return (_cab.testa() - _cam.global_position).dot(n)


func _process(delta: float) -> void:
	if not _ligado or delta <= 0.0:
		return
	_t += delta
	_molejar(delta)
	_pousar_a_mao(delta)
	_pousar_o_motorista(delta)
	_pousar_a_gola(delta)
	if _perseguindo:
		_perseguir(delta)


## A mola da cabeca, em passos curtos (a do puxao e dura, e um quadro longo a
## faria explodir).
func _molejar(delta: float) -> void:
	var luta_p := Vector3(sin(_t * 5.3) + 0.5 * sin(_t * 11.7 + 1.0),
		sin(_t * 4.1 + 2.0) + 0.5 * sin(_t * 9.3), sin(_t * 6.7 + 0.5)) * LUTA.x * _luta
	var luta_g := Vector3(sin(_t * 4.7 + 3.0), sin(_t * 5.9 + 1.0) + 0.6 * sin(_t * 13.1),
		sin(_t * 3.9 + 2.0)) * LUTA.y * _luta
	var passos := maxi(1, ceili(delta * 480.0))
	var h := delta / float(passos)
	for _i in passos:
		var ap := ((_alvo[0] as Vector3) + luta_p - _pos) * _mola.x - _vel * _mola.y
		_vel += ap * h
		_pos += _vel * h
		var ag := ((_alvo[1] as Vector3) + luta_g - _giro) * _mola.x - _vgiro * _mola.y
		_vgiro += ag * h
		_giro += _vgiro * h


## A pegada da mao agora, no espaco da lente.
func _na_lente() -> Dictionary:
	var k := clampf(_chave, 0.0, float(CHAVES.size() - 1))
	var i := mini(int(floor(k)), CHAVES.size() - 2)
	var f := k - float(i)
	var a: Array = CHAVES[i]
	var b: Array = CHAVES[i + 1]
	var o := (a[0] as Vector3).lerp(b[0] as Vector3, f)
	var giro := deg_to_rad(lerpf(float(a[1]), float(b[1]), f))
	var deita := deg_to_rad(lerpf(float(a[2]), float(b[2]), f))
	var pose := MaoPosada.misturar(POSES[a[3]], POSES[b[3]], f)
	if _aperto > 0.0:
		pose = MaoPosada.misturar(pose, POSES[&"garra"], _aperto * 0.45)
	var d := Vector3(sin(giro), cos(giro), 0.0)
	var lateral := d.cross(Vector3.BACK).normalized()
	var dorso := Vector3.FORWARD.rotated(lateral, deita)
	d = d.rotated(lateral, deita)
	# A mao vai na frente da cabeca: a diferenca entre o alvo e a cabeca e a
	# mao escorregando na cara.
	if _chave >= 1.0:
		var falta := _base_suporte * ((_alvo[0] as Vector3) - _pos)
		var na_lente := _cam.global_basis.inverse() * falta * FOLGA
		var xy := Vector2(na_lente.x, na_lente.y).limit_length(FOLGA_MAX.x)
		o += Vector3(xy.x, xy.y, clampf(na_lente.z, -FOLGA_MAX.y, FOLGA_MAX.y))
	o.z -= _folga_do_plano_de_perto(o, d, dorso, pose)
	return {"o": o, "d": d, "dorso": dorso, "pose": pose}


## Quanto a mao tem de recuar (m) para nenhum dedo DENTRO do quadro chegar mais
## perto da lente que `JUNTA_LONGE`. So conta o que a lente ve: as pontas que
## passam por cima da testa, fora do quadro, podem ir ate o olho. Contando elas
## (a primeira trava), a mao recuava 6 cm e a palma voltava a aparecer.
func _folga_do_plano_de_perto(o: Vector3, d: Vector3, dorso: Vector3, pose: Dictionary) -> float:
	MaoModelada.forma = _mao.forma
	var e := MaoPosada.esqueleto(o, d, dorso, pose, _mao.direita)
	MaoModelada.forma = {}
	var tv := tan(deg_to_rad(_cam.fov) * 0.5)
	var th := tv * _cena._aspecto()
	var falta := 0.0
	var cadeias: Array = []
	for dedo: Dictionary in e["dedos"]:
		cadeias.append(dedo["juntas"])
	cadeias.append((e["polegar"] as Dictionary)["juntas"])
	for juntas: Array in cadeias:
		for k in juntas.size() - 1:
			for s: float in [0.0, 0.5, 1.0]:
				var p := (juntas[k] as Vector3).lerp(juntas[k + 1] as Vector3, s)
				var fundo := -p.z
				if fundo <= 0.0 or fundo >= JUNTA_LONGE:
					continue
				# O raio do dedo alarga o quadro: a pele encosta antes do eixo.
				if absf(p.x) < fundo * th + 0.008 and absf(p.y) < fundo * tv + 0.008:
					falta = maxf(falta, JUNTA_LONGE - fundo)
	return falta


func _pousar_a_mao(delta: float) -> void:
	var para_cabine := _cabine.global_transform.affine_inverse() * _cam.global_transform
	var alvo := BracoVivo.levar(para_cabine, _na_lente())
	var p := alvo
	if _vem < 1.0 and not _de.is_empty():
		p = BracoVivo._misturar(_de, alvo, _vem)
		var cima := (_cabine.global_basis.inverse() * Vector3.UP).normalized()
		p["o"] = (p["o"] as Vector3) + cima * SOBE_ARCO * sin(_vem * PI)
	_mao.pular(p)
	_mao.passo(delta)


## A mao esquerda do motorista sobe do colo e agarra os dedos do padre.
func _motorista_agarra() -> void:
	if not _ligado or _cena._motorista == null:
		return
	_mot = _cena._motorista.braco_esquerdo_para_a_cena(true)
	if _mot == null:
		return
	var m := _mot.get_parent() as Node3D
	var para_m := m.global_transform.affine_inverse() * _cam.global_transform
	_mot_de = BracoVivo.levar(para_m, _na_lente_motorista(MOTORISTA_DE,
		MaoPosada.pose(&"aberta")))
	_mot.pular(_mot_de)
	_mot.visible = true
	_mot.dedos_vivos = 0.35
	# O tremor do braco dele e o do `MotoristaCena` (o esforco): puxando com tudo.
	_cena._motorista.esforco = 1.0
	_mot_vem = 0.0
	var t := _tw()
	t.tween_property(self, "_mot_vem", 1.0, MOTORISTA_SOBE) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_property(self, "_mot_forca", 1.0, 0.2)


## No empurrao a mao dele e arrancada dos dedos do padre e cai, e some.
func _motorista_arrancado() -> void:
	if _mot == null or _mot_vem < 0.0:
		return
	_mot_forca = 0.0
	var t := _tw()
	t.tween_property(self, "_mot_solta", 1.0, 0.16).set_ease(Tween.EASE_IN) \
		.set_trans(Tween.TRANS_QUAD)
	t.tween_callback(func() -> void:
		_mot_vem = -1.0
		if _cena._motorista != null:
			_cena._motorista.esforco = 0.0
			_cena._motorista.braco_esquerdo_para_a_cena(false))


## A pegada da mao do motorista no espaco da lente, com `o` dado.
func _na_lente_motorista(o: Vector3, pose: Dictionary) -> Dictionary:
	var d := (MOTORISTA_NA_MAO[1] as Vector3).normalized()
	var dorso := MOTORISTA_NA_MAO[2] as Vector3
	dorso = (dorso - d * dorso.dot(d)).normalized()
	return {"o": o, "d": d, "dorso": dorso, "pose": pose}


func _pousar_o_motorista(delta: float) -> void:
	if _mot == null or _mot_vem < 0.0 or not is_instance_valid(_mot):
		return
	var m := _mot.get_parent() as Node3D
	var para_m := m.global_transform.affine_inverse() * _cam.global_transform
	# Os trancos: ele puxa com tudo, e a mao do padre nao sai do lugar.
	var tranco := MOTORISTA_TRANCO * pow(maxf(0.0, sin(_t * 8.7)), 3.0) * _mot_forca
	var o := (MOTORISTA_NA_MAO[0] as Vector3) + tranco + MOTORISTA_ARRANCADA * _mot_solta
	var alvo := BracoVivo.levar(para_m, _na_lente_motorista(o, POSE_MOTORISTA))
	var p := alvo if _mot_vem >= 1.0 else BracoVivo._misturar(_mot_de, alvo, _mot_vem)
	if _mot_solta > 0.0:
		p["pose"] = MaoPosada.misturar(p["pose"], MaoPosada.pose(&"aberta"), _mot_solta)
	_mot.pular(p)
	_mot.passo(delta)


## A outra mao do padre sobe da janela e fecha na gola da jaqueta: o puxao e
## das duas.
func _gola_agarra() -> void:
	if _cena._maos_padre.is_empty():
		return
	_gola = _cena._maos_padre[0]
	_gola.set_meta(&"na_lente", true)
	_gola.set_instance_shader_parameter(&"sangue", SANGUE_NA_MAO * 0.5)
	_gola.set_instance_shader_parameter(&"perto_da_lente", 1.0)
	_gola_de = _gola_na_cabine(GOLA_DE, MaoPosada.pose(&"aberta"))
	_gola.pular(_gola_de)
	_gola.visible = true
	_gola.tremor = 0.6
	_gola.dedos_vivos = 0.2
	_gola_vem = 0.0
	_tw().tween_property(self, "_gola_vem", 1.0, GOLA_VEM) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	# Ela fecha fora do quadro (a gola fica 50 graus abaixo do olhar): o que se
	# sente e o pano sendo agarrado e o peito dando um tranco para a janela.
	get_tree().create_timer(GOLA_VEM).timeout.connect(func() -> void:
		if not _ligado:
			return
		_cena._som(&"arrasto_corpo", -4.0, 1.2)
		_vel += GOLA_TRANCO)


## A pegada da gola, levada do suporte (a partir do olho sem a mola) para a
## cabine. No puxao o peito vai junto com a cabeca, um pouco menos.
func _gola_na_cabine(o: Vector3, pose: Dictionary) -> Dictionary:
	var d := (GOLA[1] as Vector3).normalized()
	var dorso := GOLA[2] as Vector3
	dorso = (dorso - d * dorso.dot(d)).normalized()
	var peito := Transform3D(_base_suporte, _lente_crua.origin + _base_suporte * (_pos * GOLA_SEGUE))
	var para_cabine := _cabine.global_transform.affine_inverse() * peito
	return BracoVivo.levar(para_cabine, {"o": o, "d": d, "dorso": dorso, "pose": pose})


func _pousar_a_gola(delta: float) -> void:
	if _gola == null or _gola_vem < 0.0:
		return
	var pose := MaoPosada.misturar(MaoPosada.pose(&"aberta"), MaoPosada.pose(&"punho"),
		smoothstep(0.55, 1.0, _gola_vem))
	var alvo := _gola_na_cabine(GOLA[0] as Vector3, pose)
	var p := alvo if _gola_vem >= 1.0 else BracoVivo._misturar(_gola_de, alvo, _gola_vem)
	_gola.pular(p)
	_gola.passo(delta)


## O puxao: a testa a `_vao` da lente, e o branco quando ela chega.
func _perseguir(delta: float) -> void:
	_t_puxa += delta
	var falta := _vao - _testa_a_lente()
	_cab.distancia += falta
	var perto := _cab.testa().distance_to(_cam.global_position)
	# No fim do puxao a testa anda uns 6 cm por quadro: o golpe e no quadro em
	# que o proximo ja passaria de `BRANCO_A`, e nao no primeiro que passou (ele
	# saia a 14 cm em vez de 20).
	var anda := clampf(_perto_antes - perto, 0.0, 0.1) if _perto_antes != INF else 0.0
	_perto_antes = perto
	if perto - anda <= BRANCO_A or _t_puxa >= PUXA + 0.08:
		_perseguindo = false
		print("[susto] golpe final: testa a %.3f m da lente, %.3f s de puxao" % [perto, _t_puxa])
		_golpear()


## O golpe: o som no quadro do contato, o sangue dele na vista e o tempo quase
## parado uns quadros (`GOLPE_CONGELA`), e so entao o branco. O branco no
## proprio quadro do contato (a primeira versao) cortava antes de o golpe
## chegar ao olho.
func _golpear() -> void:
	_no_quadro("golpe")
	if _rosto != null and _bancada():
		print("[agarrao] golpe: lente na cabeca dele em %s" % [
			_rosto.global_transform.affine_inverse() * _cam.global_position])
	_cena._som(&"cabecada_final", 0.0)
	_cena._tremor = 0.6
	_cena._soco = 6.0
	# O quadro congelado sai nitido: com o obturador aberto, a cara no golpe era
	# um borrao vermelho.
	Lente.travar_desfoque(0.0)
	_sangue_na_vista()
	Engine.time_scale = GOLPE_ESCALA
	await get_tree().create_timer(GOLPE_CONGELA, true, false, true).timeout
	Engine.time_scale = 1.0
	_cena._ao_branco(&"")
	# Debaixo do branco nada mais anda: a mao e a mola param aqui.
	_ligado = false
	_devolver_a_lente()
	golpeou.emit()


## O sangue da testa dele espirrando na vista, do ponto do golpe para fora, no
## tempo do relogio (o do jogo esta quase parado).
func _sangue_na_vista() -> void:
	var camada := CanvasLayer.new()
	camada.name = "SangueNaVista"
	# Abaixo das faixas do cinema (`Cinematica`, 145), que cobrem o respingo
	# como cobrem a imagem, e do branco (`BrancoDoSusto`, 200).
	camada.layer = 140
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Tamanho explicito: FULL_RECT sob CanvasLayer mede 0x0.
	r.size = get_viewport().get_visible_rect().size
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = SANGUE_NA_VISTA
	var onde := _cam.unproject_position(_cab.testa())
	mat.set_shader_parameter(&"centro", onde / r.size)
	r.material = mat
	camada.add_child(r)
	_cena.add_child(camada)
	_vista = camada
	get_tree().create_timer(GOLPE_CONGELA * 0.7, true, false, true).timeout.connect(
		_cena._foto.bind("10n_golpe"))
	mat.set_shader_parameter(&"abre", 0.0)
	# Pelo metodo, e nao pela propriedade: o `shader_parameter/abre` de um
	# material montado no mesmo quadro ainda nao existe para o tween.
	var t := create_tween().set_ignore_time_scale(true)
	t.tween_method(func(v: float) -> void: mat.set_shader_parameter(&"abre", v),
		0.0, 1.0, GOLPE_CONGELA).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
