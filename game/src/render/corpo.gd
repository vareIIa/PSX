## Corpo humano: tubos de secao redonda e maos modeladas num esqueleto de onze
## ossos (a forma mora em `Anatomia`; a roupa, em `Vestuario`).
##
## Por que esqueleto
## -----------------
## Deformacao, pouca: so os aneis de junta (cotovelo, joelho, cintura, alto do
## ombro) dividem o peso entre dois ossos, para a dobra esticar em vez de abrir
## fresta. O resto de cada peca e rigido no seu osso. E sobretudo por draw
## call. Um pedestre feito de dez MeshInstance3D custa dez chamadas de desenho;
## dez pedestres na tela custariam cem, contra um teto de 120 para o jogo inteiro
## (ART-BIBLE secao 10). Com pele, cada pessoa e UMA malha e UMA chamada.
##
## Sao onze ossos num orcamento de 24. Sobra folga e nao vale gastar: joelho e
## cotovelo ja e mais articulacao do que a maioria dos personagens de PS1 tinha.
##
## Por que uma textura so
## ----------------------
## Rosto, cabelo, camisa, calca e sapato saem todos do mesmo atlas de 256x256, e
## a pessoa se distingue pela CELULA que cada face usa e pela cor de vertice que
## a multiplica. Textura por pessoa seria uma imagem nova por pedestre em tempo
## de execucao, e o custo apareceria como engasgo na hora em que alguem dobra a
## esquina — que e a pior hora possivel.
##
## A pose e travada em quinze posicoes por ciclo, como em Figura. E a quantizacao
## que da o passo duro da epoca: o mesmo ciclo interpolado le como motor moderno.
class_name Corpo
extends Node3D

const MATERIAL := "res://resources/materials/mat_npc.tres"

## ART-BIBLE secao 10 — poses distintas por ciclo de caminhada.
const POSES_POR_CICLO := 15.0
## Ciclos de perna por metro andado.
const CICLOS_POR_METRO := 0.62

## Altura de referencia. Todas as medidas abaixo sao para este corpo e escalam
## juntas; assim mudar a altura de uma pessoa nao desmonta a proporcao.
const ALTURA_REF := 1.72

# Alturas de junta no corpo de referencia.
const Y_QUADRIL := 0.90
const Y_OMBRO := 1.36
const Y_PESCOCO := 1.44
const Y_COTOVELO := 1.09
const Y_PUNHO := 0.85
const Y_JOELHO := 0.46
const Y_TORNOZELO := 0.07

const AMPLITUDE_PERNA := 0.58
const AMPLITUDE_BRACO := 0.42
const LIMITE_PESCOCO := 1.05
const PASSOS_PESCOCO := 7.0
## Alem do pescoco, o tronco gira junto (ate isto, em radianos): quem olha para
## tras vira os ombros, nao so a cabeca. E o pitch do olhar: para baixo (o chao,
## alguem caido) e para cima (o predio, o aviao), em passos do mesmo tamanho.
const TORCAO_TRONCO := 0.6
const PITCH_BAIXO := 0.62
const PITCH_CIMA := 0.45
const PASSO_PITCH := 0.1

## Posturas fixas, para quem nao esta andando nem parado de pe.
##
## Existem porque a casa da fumaca pede corpos que o ciclo de caminhada nao
## sabe fazer: alguem sentado no chao de frente para a TV, alguem segurando um
## controle, alguem levando um baseado a boca. Nenhuma delas anima no tempo por
## deslocamento — sao poses de estado, e e o estado que troca.
##
## LEVANTANDO e diferente das outras quatro: e a unica de PASSAGEM. Nao descreve
## um jeito de ficar parado, descreve o meio segundo entre dois deles — do chao
## para de pe — e por isso e a unica cuja pose depende de HA QUANTO TEMPO o
## estado comecou, e nao de um ciclo que se repete. Ver `levantar()`.
enum Postura { LIVRE, SENTADO, CONTROLE, FUMANDO, ENCOSTADO, LEVANTANDO, DEITADO_ACORDAR, TRABALHANDO,
	ASSENTO, DANCANDO, DIRIGINDO, PEDALANDO }

## A partir desta rapidez (m/s) o corpo corre: tronco inclinado, cotovelo em
## noventa graus bombeando, passada mais longa. O jogador corre a 4,6; o
## pedestre fugindo de susto passa de 3.
const LIMIAR_CORRIDA := 3.1
## Quanto dura a passagem de uma pose para outra (postura nova, comecar e parar
## de andar ou de correr). Tres a quatro passos de 15 Hz: sem ela a pessoa
## sentada aparecia de pe no quadro seguinte.
const MISTURA := 0.25

enum Osso {
	QUADRIL, TORSO, CABECA,
	BRACO_E, ANTEBRACO_E, BRACO_D, ANTEBRACO_D,
	COXA_E, CANELA_E, COXA_D, CANELA_D,
	# Ossos de pano e de carne: nenhuma pose escreve neles, so `_fisica`. Ficam
	# no fim para os onze de cima manterem os indices que o resto do jogo usa.
	SAIA_F, SAIA_T, BARRIGA,
}

## Mola da saia e da barriga (ver `_fisica`). Rigidez em 1/s^2 e amortecimento
## em 1/s: a saia volta em meio segundo com um balanco; a barriga e mais mole e
## sacode duas ou tres vezes.
const MOLA_PANO := Vector2(90.0, 9.0)
const MOLA_BARRIGA := Vector2(260.0, 10.0)
## Quanto a frente da saia segue a coxa que avanca (1 = o angulo inteiro).
const PANO_SEGUE_COXA := 0.85
const PANO_INERCIA := 0.012
const BARRIGA_MAX := 0.009

var _esqueleto: Skeleton3D
var _malha: MeshInstance3D
var _aparencia: Dictionary = {}
var _altura: float = ALTURA_REF
var _escala: float = 1.0
var _triangulos: int = 0

var _fase: float = 0.0
var _t_parado: float = 0.0
var _rapidez: float = 0.0
var _giro_cabeca: float = 0.0
var _falando: bool = false
var _gesto: float = 0.0
var _postura: Postura = Postura.LIVRE
## Corpo mole: balanco lento no pescoco e ombro caido. Nao e uma postura, e um
## modificador — vale andando, parado, sentado ou de controle na mao.
var chapado: bool = false
## Altura do assento em ASSENTO, em metros do chao: sofa 0,47, cadeira de
## plastico 0,47, banqueta de balcao 0,75. A pelve pousa nela e as pernas se
## acomodam; o no do corpo continua no chao.
var altura_assento: float = 0.47
## Sentado ou dancando com o baseado na mao: o braco direito leva a mao a boca
## no ciclo da tragada, como em FUMANDO.
var tragando: bool = false
var _t_chapado: float = 0.0
## Quanto ainda dura a risada, em segundos.
var _riso: float = 0.0
## Relogio proprio das posturas fixas. Nao e o de caminhada: quem esta sentado
## nao anda, e o ciclo dele e o do polegar no controle ou o da tragada.
var _t_postura: float = 0.0
## Quanto dura o levantar em curso. So importa com `_postura == LEVANTANDO`.
var _duracao_levantar: float = 1.0
## Assinatura da ultima pose aplicada. Enquanto ela nao muda, nao ha o que
## escrever no esqueleto — e o que faz dez pedestres custarem quase nada de CPU.
var _assinatura: int = -1
## Reacao em curso (ver `ReacaoCorpo`) e ha quanto tempo comecou.
var _reacao: int = 0
var _t_reacao: float = 0.0
## Pisca. Desligado por padrao: a dez metros na nevoa ninguem ve piscada, e o
## quad dos olhos fechados e uma malha a mais por pessoa. Quem liga e o retrato
## da criacao, onde a cara ocupa a foto inteira e um rosto que nunca pisca le
## como boneco de cera. Tem de ser ligado ANTES de `montar`.
var piscar: bool = false
## Nivel de detalhe da anatomia (ver `Anatomia`): doze lados no tronco e cinco
## dedos para quem aparece de perto, oito lados e mao em luva para a rua. Quem
## liga e o jogador, o avatar de rede e os retratos. Tem de ser ligado ANTES de
## `montar`.
var detalhado: bool = false
## Os aneis do tronco desta pessoa (ver `Anatomia.perfil_tronco`). A roupa le
## daqui onde fica a frente da barriga numa altura qualquer.
var _perfil: Array = []
## Quanto o braco abre para fora em pe e andando, em radianos. Sai da medida da
## barriga, e nao de um palpite: ver `_medir_abducao`.
var _abducao: float = 0.0
## Tem saia ou aba presa nos ossos de pano. Quem liga e `Anatomia.saia`, na
## montagem; sem pano e sem barriga a fisica nao roda.
var tem_pano: bool = false
var _tem_barriga: bool = false
## Estado das molas: angulo e velocidade da frente e das costas da saia; desvio
## e velocidade da barriga em y e em z.
var _pano := Vector4.ZERO
var _carne := Vector4.ZERO
var _pos_ant := Vector3.INF
var _vel_ant := Vector3.ZERO
var _quadril_ant := Vector2(INF, 0.0)
var _passo_fisica: int = -1
var _palpebra: MeshInstance3D
var _t_piscar: float = 2.4
var _fechado: float = 0.0
## Outro escreve o esqueleto (o `BonecoDePano`, caindo e levantando). A pose
## de sempre para de ser escrita; saia e barriga continuam na mola delas. Ao
## soltar, a assinatura cai e a proxima pose e escrita inteira.
var dominado: bool = false:
	set(v):
		dominado = v
		_assinatura = -1
## Desequilibrio (ver `Equilibrio`), escrito por cima de qualquer pose de pe:
## `inclinacao` e o corpo todo inclinado sobre os pes, em radianos (x para a
## direita, y para a frente); `debater` sao os bracos em moinho, de 0 a 1;
## `rumo_passo` e para que lado as pernas dao o passo (0 = frente, pi/2 =
## direita), que no tropeco raramente e para a frente.
## A cara que mexe (boca, sobrancelha, olho, piscada). Montada para quem e
## visto de perto (`detalhado`) ou pede (`com_rosto`, ligado ANTES de montar);
## a multidao a dez metros nao paga os recortes. Ver `Rosto`.
var rosto: Rosto
var com_rosto: bool = false
## LOD do rosto: quem nao e `detalhado` nem `com_rosto` (a multidao, o
## convidado, o morador) ganha a cara que mexe quando a camera chega a
## PERTO_ROSTO e a perde alem de LONGE_ROSTO. A folga entre os dois e para
## ninguem piscar o rosto na borda.
const PERTO_ROSTO := 9.0
const LONGE_ROSTO := 13.0
var _t_lod_rosto := 0.0
## O jeito da pessoa (ver `Jeito`): curvatura, cabeca, braco, maos, quique,
## ocios. Vazio anda como antes. Quem tem ficha poe aqui.
var jeito: Dictionary = {}:
	set(v):
		jeito = v
		_fase = float(v.get("fase", _fase))
		_assinatura = -1
var _t_ocio: float = 0.0
var _i_ocio: int = 0
## Agachado: quadril baixo, joelho dobrado, pes no lugar (IK). O jogador liga.
var agachado: bool = false:
	set(v):
		if v != agachado:
			agachado = v
			_comecar_mistura()
## Fase da pedivela, em radianos (a da bicicleta), para PEDALANDO.
var pedal_fase: float = 0.0
## Mancando, de 0 a 1, e de qual perna (-1 esquerda, 1 direita): a perna ruim
## passa menos, dobra menos o joelho, e o corpo afunda e pende para ela quando
## ela aguenta o peso. Quem levanta de um atropelo com a canela batida.
var mancando: float = 0.0
var perna_ruim: int = 1
## Agarrar (o "grab" do Euphoria): ponto do MUNDO onde uma mao se segura —
## o ombro de quem esta do lado, quando a pessoa tropeca. INF solta.
var agarrar: Vector3 = Vector3.INF
## Mistura de passagem: a pose de onde se sai e quanto falta.
var _mistura_de: Dictionary = {}
var _t_mistura: float = 0.0
var _mov_antes: int = -1
var _animado_quadro: int = -1
var inclinacao := Vector2.ZERO
var debater: float = 0.0
var rumo_passo: float = 0.0
var _t_debater: float = 0.0


# --- montagem ---------------------------------------------------------------

## Monta o corpo. Chamar de novo REFAZ, e nao acrescenta.
##
## Isto ja custou caro. A primeira versao montava um corpo padrao no _ready, por
## seguranca, e o chamador montava o corpo de verdade logo depois — entao todo
## pedestre nascia com duas pessoas dentro, uma generica e uma certa, ocupando o
## mesmo lugar. Nao da para ver: as duas se atravessam e o resultado le como uma
## pessoa so, com a cor errada e o dobro do custo. So apareceu quando o teste
## contou as malhas e achou duas onde o projeto inteiro depende de haver uma.
func montar(aparencia: Dictionary) -> void:
	if _esqueleto != null:
		_esqueleto.queue_free()
		_esqueleto = null
		_malha = null
	_aparencia = aparencia
	_altura = float(aparencia.get("altura", ALTURA_REF))
	_escala = _altura / ALTURA_REF
	_perfil = Anatomia.perfil_tronco(aparencia)
	_abducao = _medir_abducao()
	tem_pano = false
	_tem_barriga = Anatomia.fator_barriga(aparencia, 1.11) > 0.0
	_pano = Vector4.ZERO
	_carne = Vector4.ZERO
	_pos_ant = Vector3.INF
	_quadril_ant = Vector2(INF, 0.0)

	_esqueleto = Skeleton3D.new()
	_esqueleto.name = "Esqueleto"
	add_child(_esqueleto)
	_criar_ossos()

	var dados := _construir()
	_malha = MeshInstance3D.new()
	_malha.name = "Pele"
	_malha.mesh = PSXMesh.dados_para_mesh(dados)
	_malha.material_override = load(MATERIAL) as ShaderMaterial
	# ART-BIBLE secao 7 — o PS1 nao tinha sombra dinamica.
	_malha.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_triangulos = PSXMesh.dados_triangulos(dados)
	_esqueleto.add_child(_malha)
	_malha.skeleton = NodePath("..")
	_malha.skin = _esqueleto.create_skin_from_rest_transforms()

	# Barba em recorte: segunda malha, no mesmo esqueleto, so para quem usa.
	var recorte := Vestuario.dados_recorte(self, aparencia)
	if not PSXMesh.dados_vazio(recorte):
		var barba := MeshInstance3D.new()
		barba.name = "Recorte"
		barba.mesh = PSXMesh.dados_para_mesh(recorte)
		barba.material_override = Vestuario.material_recorte(_malha.material_override)
		barba.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_esqueleto.add_child(barba)
		barba.skeleton = NodePath("..")
		barba.skin = _malha.skin
		_triangulos += PSXMesh.dados_triangulos(recorte)

	_palpebra = null
	if piscar:
		_palpebra = MeshInstance3D.new()
		_palpebra.name = "Palpebra"
		_palpebra.mesh = PSXMesh.dados_para_mesh(Vestuario.dados_palpebra(self, aparencia))
		_palpebra.material_override = Vestuario.material_recorte(_malha.material_override)
		_palpebra.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_palpebra.visible = false
		_esqueleto.add_child(_palpebra)
		_palpebra.skeleton = NodePath("..")
		_palpebra.skin = _malha.skin

	rosto = null
	if (detalhado or com_rosto) and Rosto.tem_rosto(aparencia):
		rosto = Rosto.new(self)
		# A palpebra da criacao ja pisca; os dois piscando fariam piscada dupla.
		rosto.pisca = _palpebra == null
		rosto.expressao(Rosto.Expressao.NEUTRA)

	_aplicar_pose()
	# Recem-montado nao tem de onde vir: a primeira passada nao e "parou e
	# comecou a andar", e misturar ali acrescentava seis poses ao ciclo que a
	# verificacao da multidao conta (quinze, nem uma a mais).
	_mov_antes = -1
	_ja_posou = false


func _y(v: float) -> float:
	return v * _escala


## Os aneis do tronco, para a roupa encostar nele.
func perfil() -> Array:
	return _perfil


## Quanto o braco tem de abrir para passar por fora da barriga.
##
## O braco pende do ombro; a barriga esta mais abaixo e, no gordo, mais larga
## que o ombro. Para cada anel da barriga, o angulo que leva a face de dentro do
## braco ate a face de fora do tronco naquela altura; fica o maior. Soma o
## recolhimento que a pose de pe ja faz (0,07 rad para dentro), senao o braco
## volta para dentro da barriga pela propria pose. Um centimetro de contato e
## permitido: braco de gordo encosta, nao flutua.
##
## Nao passa do peito (y 1,16): ali o que o braco toca e a axila, e abrir o
## braco por causa dela e a pose de caubói.
func _medir_abducao() -> float:
	var mo := Anatomia.meio_ombro(_aparencia)
	var est := Anatomia.estacoes_braco(_aparencia, true)
	var maior := -1.0
	for anel: Array in _perfil:
		var y := float(anel[0])
		if y < 0.98 or y > 1.16:
			continue
		var r := Anatomia.raio_em(est, y).x + Anatomia.FOLGA_MANGA
		var falta := float(anel[1]) + r - 0.01 - mo
		maior = maxf(maior, atan2(falta, Y_OMBRO - y))
	return maxf(0.0, maior + 0.07)


func _criar_ossos() -> void:
	var meio_ombro := Anatomia.meio_ombro(_aparencia)
	var meio_quadril := Anatomia.meio_quadril(_aparencia)

	# nome, pai, origem no repouso (em espaco do modelo)
	var lista: Array = [
		["quadril", -1, Vector3(0.0, _y(Y_QUADRIL), 0.0)],
		["torso", Osso.QUADRIL, Vector3(0.0, _y(Y_QUADRIL + 0.06), 0.0)],
		["cabeca", Osso.TORSO, Vector3(0.0, _y(Y_PESCOCO), 0.0)],
		["braco_e", Osso.TORSO, Vector3(-meio_ombro, _y(Y_OMBRO), 0.0)],
		["antebraco_e", Osso.BRACO_E, Vector3(-meio_ombro, _y(Y_COTOVELO), 0.0)],
		["braco_d", Osso.TORSO, Vector3(meio_ombro, _y(Y_OMBRO), 0.0)],
		["antebraco_d", Osso.BRACO_D, Vector3(meio_ombro, _y(Y_COTOVELO), 0.0)],
		["coxa_e", Osso.QUADRIL, Vector3(-meio_quadril, _y(Y_QUADRIL), 0.0)],
		["canela_e", Osso.COXA_E, Vector3(-meio_quadril, _y(Y_JOELHO), 0.0)],
		["coxa_d", Osso.QUADRIL, Vector3(meio_quadril, _y(Y_QUADRIL), 0.0)],
		["canela_d", Osso.COXA_D, Vector3(meio_quadril, _y(Y_JOELHO), 0.0)],
		["saia_f", Osso.QUADRIL, Vector3(0.0, _y(0.96), 0.0)],
		["saia_t", Osso.QUADRIL, Vector3(0.0, _y(0.96), 0.0)],
		["barriga", Osso.TORSO, Vector3(0.0, _y(1.11), 0.0)],
	]

	var globais: Array[Vector3] = []
	for item: Array in lista:
		var idx := _esqueleto.add_bone(String(item[0]))
		var pai := int(item[1])
		var origem: Vector3 = item[2]
		globais.append(origem)
		if pai >= 0:
			_esqueleto.set_bone_parent(idx, pai)
		# O repouso e local ao pai. Guardar o global e converter aqui e mais
		# facil de ler e de conferir do que escrever deslocamentos relativos na
		# tabela, onde um erro de dois centimetros no quadril desloca a perna
		# inteira sem que de para ver de onde veio.
		var local := origem - (globais[pai] if pai >= 0 else Vector3.ZERO)
		_esqueleto.set_bone_rest(idx, Transform3D(Basis(), local))
	_esqueleto.reset_bone_poses()


# --- geometria --------------------------------------------------------------

## As seis faces de uma caixa, na convencao de PSXMesh.box_dados.
const FACES: Array = [
	[PSXMesh.FACE_FRENTE, Vector3(0, 0, 1)],
	[PSXMesh.FACE_TRAS, Vector3(0, 0, -1)],
	[PSXMesh.FACE_DIR, Vector3(1, 0, 0)],
	[PSXMesh.FACE_ESQ, Vector3(-1, 0, 0)],
	[PSXMesh.FACE_TOPO, Vector3(0, 1, 0)],
	[PSXMesh.FACE_BASE, Vector3(0, -1, 0)],
]


## Uma face texturizada com uma celula do atlas.
##
## Nao da para usar box_dados: ela aplica a mesma UV em metros nas seis faces, e
## aqui cada face precisa cair numa celula diferente — o rosto na frente, a nuca
## atras, a orelha nos lados. E o que transforma uma caixa em cabeca.
func _face(dados: Dictionary, tamanho: Vector2, xform: Transform3D, cor: Color,
		celula: Rect2, osso: int) -> void:
	var d := PSXMesh.placa_dados(tamanho, 100.0, Color.WHITE)
	var uvs: PackedVector2Array = d["uv"]
	for k in uvs.size():
		uvs[k] = celula.position + uvs[k] * celula.size
	d["uv"] = uvs
	PSXMesh.acumular_osso(dados, d, xform, cor, osso)


## Caixa com celula por face. `celulas` mapeia bit de face para Rect2 de UV; o
## que faltar usa `padrao`. `faces` corta o que nunca e visto.
func _caixa(dados: Dictionary, tamanho: Vector3, centro: Vector3, cor: Color,
		padrao: Rect2, osso: int, celulas: Dictionary = {},
		faces: int = PSXMesh.FACE_TODAS) -> void:
	var meio := tamanho * 0.5
	for item: Array in FACES:
		var bit := int(item[0])
		if faces & bit == 0:
			continue
		var normal: Vector3 = item[1]
		var tam2 := Vector2.ZERO
		var base := Basis()
		if absf(normal.z) > 0.5:
			tam2 = Vector2(tamanho.x, tamanho.y)
			base = Basis() if normal.z > 0.0 else Basis(Vector3.UP, PI)
		elif absf(normal.x) > 0.5:
			tam2 = Vector2(tamanho.z, tamanho.y)
			base = Basis(Vector3.UP, PI * 0.5 * signf(normal.x))
		else:
			tam2 = Vector2(tamanho.x, tamanho.z)
			base = Basis(Vector3.RIGHT, -PI * 0.5 * signf(normal.y))
		var xform := Transform3D(base, centro + normal * meio)
		_face(dados, tam2, xform, cor, celulas.get(bit, padrao), osso)


func _construir() -> Dictionary:
	var d := PSXMesh.dados_com_ossos()
	var a := _aparencia
	# Duas corpulencias, e nao uma.
	#
	# Engordar uma pessoa nao engrossa o braco e a barriga na mesma proporcao: a
	# barriga triplica de volume antes de o punho mudar de tamanho. Com um fator
	# so, o magro virava um palito de pernas finas e o gordo um armario de bracos
	# de lutador — nenhum dos dois le como o que e. O tronco vai de 0,82 a 1,37 e
	# os membros de 0,88 a 1,18 no mesmo intervalo do controle.
	var gordura := clampf(float(a.get("gordura", 0.5)), 0.0, 1.0)
	var c := 0.88 + gordura * 0.30
	var c_tronco := 0.82 + gordura * 0.55

	var pele: Color = a.get("pele", Color.WHITE)
	var cor_camisa: Color = a["casaco_cor"] if bool(a.get("casaco", false)) else a["camisa_cor"]
	var cel_frente := Aparencia.uv_da_celula(
		int(a["casaco_cel"]) if bool(a.get("casaco", false)) else int(a["camisa"]),
		Aparencia.LINHA_CASACO if bool(a.get("casaco", false)) else Aparencia.LINHA_CAMISA)
	var cel_costas := Aparencia.uv_da_celula(int(a["camisa"]), Aparencia.LINHA_COSTAS)
	var cel_calca := Aparencia.uv_da_celula(int(a["calca"]), Aparencia.LINHA_CALCA)
	var cel_nuca := Aparencia.uv_da_celula(Aparencia.PECA_NUCA, Aparencia.LINHA_PECAS)
	var cel_manga := Aparencia.uv_da_celula(Aparencia.PECA_MANGA, Aparencia.LINHA_PECAS)
	var cel_mao := Aparencia.uv_da_celula(Aparencia.PECA_MAO, Aparencia.LINHA_PECAS)
	var cel_rosto := Aparencia.uv_da_celula(int(a["rosto"]), int(a["linha_rosto"]))
	var cel_perfil := Aparencia.uv_da_celula(int(a["perfil"]),
		int(a.get("linha_perfil", Aparencia.LINHA_PECAS)))
	# Pele tatuada. Entra no pescoco, no antebraco e na mao, que sao as tres
	# partes de pele a mostra — e sao exatamente por onde a tatuagem de Jota
	# sobe. Sem tatuagem, as tres continuam usando a celula de nuca lisa de
	# sempre e nao ha nem um triangulo a mais no corpo de ninguem.
	var tatuado := bool(a.get("tatuagem", false))
	var cel_pele := Aparencia.uv_da_celula(Aparencia.ELENCO_PELE_ESPINHOS,
		Aparencia.LINHA_ELENCO) if tatuado else cel_nuca
	var cel_pescoco := Aparencia.uv_da_celula(Aparencia.ELENCO_NUCA_ESPINHOS,
		Aparencia.LINHA_ELENCO) if tatuado else cel_nuca
	var cel_cabelo := Aparencia.uv_da_celula(int(a["cabelo"]),
		int(a.get("linha_cabelo", Aparencia.LINHA_CABELO)))
	var cel_sapato := Aparencia.uv_da_celula(int(a["sapato"]), Aparencia.LINHA_PECAS)

	var ombro := float(a.get("ombro", 0.42))
	var quadril := float(a.get("quadril", 0.30))
	var saia := bool(a.get("saia", false))
	# A forma de cada peca mora em `Vestuario`; aqui so o que muda a base.
	var cor_manga := Aparencia.cor_da_manga(a)
	var canela_nua := Vestuario.canela_a_mostra(a)
	var saia_longa := int(a.get("calca_estilo", 0)) == Aparencia.CALCA_SAIA_LONGA

	# --- quadril e tronco ---
	# Tubos de secao redonda, anel por anel (ver `Anatomia`). A barriga, o peito
	# e o quadril sao medidas do mesmo tubo, e nao caixas grudadas.
	Anatomia.tronco(self, d, detalhado, cor_camisa, cel_frente, cel_costas,
		a["calca_cor"], cel_calca, Vestuario.camisa_por_dentro(a))
	if saia and not saia_longa:
		# A saia e uma peca so, presa ao quadril. Cortada em duas metades ela
		# rasgaria no meio a cada passo, e o PS1 resolvia isso do mesmo jeito.
		Anatomia.saia(self, d, a, 0.97, 0.64, a["calca_cor"], Anatomia.tecido(cel_calca),
			Osso.QUADRIL)

	# --- cabeca ---
	Anatomia.pescoco(self, d, a, detalhado, pele, cel_pescoco)
	# O rosto vai na face -Z porque a frente do personagem e -Z, que e a
	# convencao do motor. Ja saiu invertido uma vez: a pessoa andava de costas
	# com a cara nas costas e ninguem via, porque de frente parecia so um nuca.
	# A cabeca e um tico maior que a proporcao real. Sete cabecas e meia de
	# altura e o correto anatomico e o errado aqui: a 480x270 a cabeca some, e e
	# nela que estao o rosto e o cabelo, ou seja tudo que identifica a pessoa.
	_caixa(d, Vector3(0.214, _y(0.245), 0.222),
		Vector3(0.0, _y(1.595), 0.0), pele, cel_nuca, Osso.CABECA,
		{
			PSXMesh.FACE_TRAS: cel_rosto,
			PSXMesh.FACE_DIR: cel_perfil,
			PSXMesh.FACE_ESQ: cel_perfil,
		})
	_montar_cabelo(d, cel_cabelo)

	_montar_chapeu(d, cel_costas)
	Vestuario.oculos(self, d, a)
	Vestuario.barba_volume(self, d, a, cel_cabelo)

	# --- bracos ---
	var manga_longa := Aparencia.manga_longa(a)
	# Regata sem agasalho por cima: o braco inteiro sai de pele.
	var braco_nu := int(a.get("camisa_estilo", 0)) == Aparencia.CAMISA_REGATA \
		and not manga_longa
	var manga := Anatomia.Manga.SEM if braco_nu else (Anatomia.Manga.LONGA
		if manga_longa else Anatomia.Manga.CURTA)
	for lado: float in [-1.0, 1.0]:
		Anatomia.braco(self, d, a, lado, detalhado, manga, cor_manga, cel_manga,
			pele, cel_pele)
		# A mao e modelada (dedos e polegar), entao usa a pele lisa, e nao a
		# celula de dedos pintados; a tatuada continua com os espinhos de Jota.
		Anatomia.mao(self, d, a, lado, detalhado, pele, cel_pele)

	# --- pernas ---
	var meio_quadril := Anatomia.meio_quadril(a)
	var calca := 0 if saia else (2 if canela_nua else 1)
	for lado in [-1, 1]:
		var canela := Osso.CANELA_E if lado < 0 else Osso.CANELA_D
		var x := meio_quadril * float(lado)
		Anatomia.perna(self, d, a, float(lado), detalhado, calca, a["calca_cor"],
			cel_calca, pele, cel_nuca)
		# O pe aponta para -Z, que e a frente. Sem ele a perna acaba num toco e a
		# pessoa parece flutuar meio centimetro acima da calcada.
		if not Vestuario.sapato(self, d, a, x, canela, cel_sapato):
			Anatomia.sapato(self, d, x, canela, a["sapato_cor"], cel_sapato)

	Vestuario.camisa(self, d, a, c, c_tronco)
	Vestuario.casaco(self, d, a, c, c_tronco)
	Vestuario.calca(self, d, a, c, c_tronco)
	return d


## Cabelo em duas pecas: a calota por cima da cabeca e a parte de tras, que e a
## que muda de comprimento. Cabelo pintado na testa nao muda silhueta nenhuma, e
## e a silhueta que distingue as pessoas a quinze metros de nevoa.
func _montar_cabelo(d: Dictionary, celula: Rect2) -> void:
	var a := _aparencia
	if bool(a.get("calvo", false)):
		return
	var cor: Color = a["cabelo_cor"]
	var comprimento := int(a.get("cabelo_comprimento", 0))
	var estilo := int(a.get("cabelo", 0))

	# A calota e ancorada pelo TOPO, um centimetro acima do craneo, e cresce para
	# BAIXO. Ancorando pelo centro, como estava, um cabelo mais cheio subia seis
	# centimetros acima da cabeca e lia como chapeu apoiado — foi o primeiro
	# resultado, e levou um tempo para eu perceber que o problema nao era cor.
	#
	# O limite de baixo e a sobrancelha da textura, em 1,615. A franja mais cheia
	# para em 1,632; um centimetro a mais e ela come os olhos.
	var alto: float = [0.070, 0.085, 0.100][clampi(estilo % 3, 0, 2)]
	var topo := 1.7175 + 0.012
	# Cabelo cacheado ocupa MAIS ESPACO que cabelo liso, e e so isso que o olho
	# usa para separar os dois de longe: cacho nao e uma cor nem um desenho, e
	# um volume. A calota cresce dois centimetros e meio e abre tres para cada
	# lado; os tufos que quebram o contorno vem logo abaixo.
	var cacheado := bool(a.get("cacheado", false))
	var largura := 0.228
	if cacheado:
		alto += 0.030
		largura = 0.248
	_caixa(d, Vector3(largura, _y(alto), largura * 1.043),
		Vector3(0.0, _y(topo - alto * 0.5), 0.0), cor, celula, Osso.CABECA)
	if cacheado:
		_tufos(d, cor, celula, topo, alto, largura)

	# Costeleta: uma tira fina descendo pelos lados da testa. E o que impede a
	# calota de ler como boina apoiada na cabeca.
	for lado in [-1, 1]:
		_caixa(d, Vector3(0.026, _y(0.08), 0.13),
			Vector3(0.110 * float(lado), _y(1.652), -0.02), cor, celula,
			Osso.CABECA)

	var comp: float = [0.09, 0.26, 0.40][clampi(comprimento, 0, 2)]
	_caixa(d, Vector3(0.216, _y(comp), 0.06),
		Vector3(0.0, _y(1.700 - comp * 0.5), 0.096), cor, celula, Osso.CABECA)
	if comprimento >= 1:
		# Cabelo comprido tambem cai dos lados, senao a cabeca fica com uma placa
		# atras e nada em volta.
		#
		# Cai ATRAS da orelha, e nao por cima dela. A primeira versao cobria a
		# lateral inteira da cabeca — z de -0,08 a 0,12 num craneo que vai de
		# -0,11 a 0,11 — e engolia a orelha junto. Isso nunca tinha aparecido
		# porque a orelha era so uma sombra na textura; com o alargador de Jota
		# e o de Helmer desenhados nela, a peca que identifica os dois de perfil
		# simplesmente nao existia na tela.
		for lado in [-1, 1]:
			_caixa(d, Vector3(0.046, _y(comp * 0.85), 0.13),
				Vector3(0.112 * float(lado), _y(1.700 - comp * 0.42), 0.075),
				cor, celula, Osso.CABECA)

	if bool(a.get("coque", false)):
		_coque(d, cor, celula)


## Os tufos que fazem o cacho.
##
## Seis caixas pequenas encavaladas na borda da calota, cada uma com tamanho e
## deslocamento proprios. O que importa nao e cada uma: e o CONTORNO irregular
## que as seis juntas deixam. Uma calota lisa recortada contra a parede le como
## capacete por mais cacheada que seja a textura dentro dela, e a silhueta e o
## que se ve a quinze metros na nevoa — o resto do arquivo diz isso o tempo todo.
##
## Sao sessenta triangulos, e so em quem tem a marca. Ninguem na rua tem.
func _tufos(d: Dictionary, cor: Color, celula: Rect2, topo: float,
		alto: float, largura: float) -> void:
	# Os tufos coroam a calota, e nao a emolduram por baixo.
	#
	# Na primeira versao eles ficavam na metade de baixo dela e chegavam a linha
	# da sobrancelha: o cacho ficava certo e a cara sumia dentro dele. Um rosto
	# de 32 px nao sobrevive a nada por cima, e sao os oculos e o bigode que
	# dizem que aquele e o Helmer.
	var meio := topo - alto * 0.28
	var r := largura * 0.5
	# Angulo, raio, tamanho e altura de cada tufo. Escritos e nao sorteados: o
	# corpo se remonta a cada troca de roupa, e um cacho sorteado mudaria de
	# forma toda vez que isso acontecesse.
	var onde: Array = [
		[0.0, 0.94, 0.088, 0.010], [1.05, 0.90, 0.076, -0.014],
		[2.10, 0.96, 0.092, 0.018], [3.14, 0.92, 0.084, -0.008],
		[4.19, 0.95, 0.080, 0.022], [5.24, 0.89, 0.090, -0.018],
	]
	for t: Array in onde:
		var ang: float = t[0]
		var dist: float = r * float(t[1])
		var lado: float = float(t[2])
		_caixa(d, Vector3(lado, _y(lado * 0.92), lado),
			Vector3(cos(ang) * dist, _y(meio + float(t[3])),
				sin(ang) * dist), cor, celula, Osso.CABECA)


## O coque: cabelo longo preso atras da cabeca.
##
## Fica na altura da nuca e nao no alto do craneo. As duas alturas existem no
## mundo, e a da nuca e a da foto: e a que aparece de PERFIL, que e como o
## jogador mais ve quem esta trabalhando de lado para o corredor. No alto, o
## coque so aparece de tras e de longe le como chapeu.
##
## Duas pecas: o novelo e a mecha que sobe ate ele. Sem a mecha, o novelo
## flutua atras da cabeca como uma bola presa por nada.
func _coque(d: Dictionary, cor: Color, celula: Rect2) -> void:
	_caixa(d, Vector3(0.052, _y(0.09), 0.055),
		Vector3(0.0, _y(1.674), 0.110), cor, celula, Osso.CABECA)
	_caixa(d, Vector3(0.108, _y(0.105), 0.098),
		Vector3(0.0, _y(1.616), 0.160), cor, celula, Osso.CABECA)


## Quatro chapeus de geometria, e nenhum de textura.
##
## Chapeu e a peca que mais muda a silhueta pelo menor custo: sao doze
## triangulos e a pessoa passa a ser reconhecivel a vinte metros na nevoa, onde
## nao ha rosto nem cor de camisa que se leiam. Por isso ele e forma, e nao
## desenho — desenhar um bone numa celula de 32 px gastaria uma celula do atlas
## e nao mudaria a linha do corpo em nada.
func _montar_chapeu(d: Dictionary, celula: Rect2) -> void:
	var a := _aparencia
	var tipo := int(a.get("chapeu_tipo", 0))
	if tipo <= 0 or not bool(a.get("chapeu", false)):
		return
	if Vestuario.chapeu(self, d, a, celula):
		return
	var cor: Color = a.get("chapeu_cor", Color("6f6a60"))
	var topo := 1.7175

	match tipo:
		1:
			# Bone: copa baixa e aba so na frente.
			_caixa(d, Vector3(0.222, _y(0.07), 0.232),
				Vector3(0.0, _y(topo + 0.03), 0.0), cor, celula, Osso.CABECA)
			_caixa(d, Vector3(0.216, _y(0.016), 0.11),
				Vector3(0.0, _y(topo + 0.002), -0.16), cor, celula, Osso.CABECA)
		2:
			# Touca: copa alta, sem aba, dobra na barra.
			_caixa(d, Vector3(0.224, _y(0.13), 0.234),
				Vector3(0.0, _y(topo + 0.05), 0.0), cor, celula, Osso.CABECA)
			_caixa(d, Vector3(0.234, _y(0.035), 0.244),
				Vector3(0.0, _y(topo - 0.005), 0.0), cor, celula, Osso.CABECA)
		3:
			# Chapeu de aba inteira. E a silhueta mais forte das quatro.
			_caixa(d, Vector3(0.216, _y(0.10), 0.226),
				Vector3(0.0, _y(topo + 0.045), 0.0), cor, celula, Osso.CABECA)
			_caixa(d, Vector3(0.34, _y(0.016), 0.36),
				Vector3(0.0, _y(topo - 0.004), 0.0), cor, celula, Osso.CABECA)
		_:
			# Gorro: baixo e colado no craneo.
			_caixa(d, Vector3(0.228, _y(0.055), 0.238),
				Vector3(0.0, _y(topo + 0.012), 0.0), cor, celula, Osso.CABECA)


func triangulos() -> int:
	return _triangulos


## Publica para a verificacao: a assinatura muda uma vez por pose travada, entao
## contar assinaturas distintas ao longo de um ciclo mede a quantizacao sem
## precisar ler osso por osso.
func assinatura() -> int:
	return _assinatura


func ossos() -> int:
	return _esqueleto.get_bone_count() if _esqueleto != null else 0


func altura() -> float:
	return _altura


func aparencia() -> Dictionary:
	return _aparencia


## Quanto o braco abre para passar pela barriga (ver `_medir_abducao`).
func abducao() -> float:
	return _abducao


## Altura da boca, para o som da voz sair da cabeca e nao dos pes.
func altura_da_boca() -> float:
	return _y(1.58)


# --- animacao ---------------------------------------------------------------

## Avanca o ciclo. `rapidez` em m/s.
func animar(rapidez: float, delta: float, no_chao: bool = true) -> void:
	_rapidez = rapidez
	_animado_quadro = Engine.get_process_frames()
	if _t_mistura > 0.0:
		_t_mistura = maxf(0.0, _t_mistura - delta)
	var cadencia := float(_aparencia.get("cadencia", 1.0))
	# Correndo, a passada e mais longa: menos ciclos de perna por metro.
	var ciclos := CICLOS_POR_METRO * lerpf(1.0, 0.55, smoothstep(2.6, 4.6, rapidez))
	if rapidez > 0.15 and no_chao:
		_fase += rapidez * delta * ciclos * TAU * cadencia
		_t_parado = 0.0
	else:
		_t_parado += delta
	if _falando:
		_gesto += delta * 2.6
	if _postura != Postura.LIVRE:
		_t_postura += delta
	if chapado:
		_t_chapado += delta
	if _riso > 0.0:
		_riso = maxf(0.0, _riso - delta)
	if _reacao != 0:
		_t_reacao += delta
		if _t_reacao >= ReacaoCorpo.duracao(_reacao):
			_reacao = 0
			_assinatura = -1
	if _palpebra != null:
		_piscar(delta)
	_lod_do_rosto(delta)
	if rosto != null:
		rosto.passo(delta)
		_atualizar_olhar(delta)
	_ocio(delta)
	if debater > 0.0:
		_t_debater += delta
	_aplicar_pose()
	_fisica(delta)


func _lod_do_rosto(delta: float) -> void:
	if detalhado or com_rosto or _esqueleto == null:
		return
	_t_lod_rosto -= delta
	if _t_lod_rosto > 0.0:
		return
	# Cada um confere num instante diferente: a multidao nao monta rosto toda
	# no mesmo quadro.
	_t_lod_rosto = 0.35 + float(get_instance_id() % 7) * 0.02
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return
	var d := cam.global_position.distance_to(global_position)
	if rosto == null and d < PERTO_ROSTO and Rosto.tem_rosto(_aparencia):
		rosto = Rosto.new(self)
		rosto.pisca = _palpebra == null
		rosto.expressao(Rosto.Expressao.NEUTRA)
	elif rosto != null and d > LONGE_ROSTO:
		rosto.desmontar()
		rosto = null


## Ocio de quem esta parado: de tanto em tanto tempo, um dos tres ocios da
## pessoa (`Jeito`), em rodizio. Nao interrompe nada — so dispara parado, de pe,
## calado e sem outra reacao em curso.
func _ocio(delta: float) -> void:
	var lista: Array = jeito.get("ocios", [])
	if lista.is_empty() or dominado or _postura != Postura.LIVRE or _rapidez > 0.15 \
			or _falando or _reacao != 0 or inclinacao != Vector2.ZERO:
		_t_ocio = 0.0
		return
	_t_ocio += delta
	if _t_ocio < float(jeito.get("intervalo", 8.0)):
		return
	_t_ocio = 0.0
	var tipo: int = lista[_i_ocio % lista.size()]
	# O primeiro da lista e o preferido: volta a ele a cada dois.
	_i_ocio += 1 if _i_ocio % 2 == 0 else 2
	reagir(tipo)


## Pano e carne que andam atrasados do corpo: a saia e a barriga.
##
## Duas molas amortecidas por osso, e nada de simulacao de tecido: o pano da
## saia e dois paineis (frente e costas) presos no quadril, e a barriga e um
## ponto preso no tronco. O que move cada um:
##
## - a coxa: a frente da saia segue a coxa que avanca e as costas seguem a que
##   recua. E o que tira a perna de dentro do pano ao andar — no corpo rigido a
##   coxa atravessava a saia a cada passo.
## - a inercia: arrancar joga o pano para tras, frear joga para a frente.
## - o quadril: ele sobe e desce duas vezes por passo, e a barriga do gordo
##   chega atrasada e sacode.
##
## No PS1 STYLE (luz por vertice) o resultado e escrito a quinze passos por
## segundo, como as poses: pano liso ao lado de um andar travado le como dois
## jogos diferentes. No MODERNO, a cada quadro.
func _fisica(delta: float) -> void:
	if (not tem_pano and not _tem_barriga) or _esqueleto == null or delta <= 0.0:
		return
	delta = minf(delta, 0.1)
	var pos := global_position if is_inside_tree() else position
	if _pos_ant == Vector3.INF:
		_pos_ant = pos
	var vel := ((pos - _pos_ant) / delta).limit_length(9.0)
	_pos_ant = pos
	var acc := ((vel - _vel_ant) / delta).limit_length(30.0)
	_vel_ant = vel
	var base := global_basis if is_inside_tree() else basis
	var local := base.inverse() * acc
	# O sobe e desce do quadril, em aceleracao, pelo que a pose escreveu.
	var qy := _esqueleto.get_bone_pose_position(Osso.QUADRIL).y
	var vq := 0.0
	if _quadril_ant.x != INF:
		vq = (qy - _quadril_ant.x) / delta
	var aq := clampf((vq - _quadril_ant.y) / delta, -30.0, 30.0)
	_quadril_ant = Vector2(qy, vq)

	var passos := maxi(1, ceili(delta * 120.0))
	var h := delta / float(passos)
	if tem_pano:
		var ce := _esqueleto.get_bone_pose_rotation(Osso.COXA_E).get_euler().x
		var cd := _esqueleto.get_bone_pose_rotation(Osso.COXA_D).get_euler().x
		# Frente de aceleracao e -Z: arrancar da `local.z` negativo e o pano
		# fica para tras (angulo negativo).
		# A mola so leva o pano de volta ao repouso (mais a inercia). A coxa e
		# CONTATO, nao alvo: ela empurra o pano na hora, e o pano nunca fica
		# atras dela. Como alvo de mola ele chegava um quarto de passo atrasado,
		# e era nesse atraso que a perna atravessava a saia.
		var inercia := local.z * PANO_INERCIA
		var empurra_f := maxf(0.0, maxf(ce, cd)) * PANO_SEGUE_COXA
		var empurra_t := minf(0.0, minf(ce, cd)) * PANO_SEGUE_COXA
		for i in passos:
			var af := MOLA_PANO.x * (inercia - _pano.x) - MOLA_PANO.y * _pano.y
			var at := MOLA_PANO.x * (inercia - _pano.z) - MOLA_PANO.y * _pano.w
			_pano.y += af * h
			_pano.x = clampf(_pano.x + _pano.y * h, -1.2, 1.7)
			_pano.w += at * h
			_pano.z = clampf(_pano.z + _pano.w * h, -1.7, 1.2)
			if _pano.x < empurra_f:
				_pano.x = empurra_f
				_pano.y = maxf(_pano.y, 0.0)
			if _pano.z > empurra_t:
				_pano.z = empurra_t
				_pano.w = minf(_pano.w, 0.0)
	if _tem_barriga:
		var massa := smoothstep(0.35, 1.0, Anatomia.gordura(_aparencia))
		var forca := Vector2(-(aq + acc.y), local.z) * 0.02 * massa
		var lim := BARRIGA_MAX * massa * _escala
		for i in passos:
			var ay := MOLA_BARRIGA.x * -_carne.x - MOLA_BARRIGA.y * _carne.y + forca.x * 60.0
			var az := MOLA_BARRIGA.x * -_carne.z - MOLA_BARRIGA.y * _carne.w + forca.y * 60.0
			_carne.y += ay * h
			_carne.x = clampf(_carne.x + _carne.y * h, -lim, lim)
			_carne.w += az * h
			_carne.z = clampf(_carne.z + _carne.w * h, -lim, lim)

	if not _luz_por_pixel():
		var passo := int(Time.get_ticks_msec() * POSES_POR_CICLO / 1000.0)
		if passo == _passo_fisica:
			return
		_passo_fisica = passo
	if tem_pano:
		_esqueleto.set_bone_pose_rotation(Osso.SAIA_F, Quaternion(Vector3.RIGHT, _pano.x))
		_esqueleto.set_bone_pose_rotation(Osso.SAIA_T, Quaternion(Vector3.RIGHT, _pano.z))
	if _tem_barriga:
		_esqueleto.set_bone_pose_position(Osso.BARRIGA,
			_esqueleto.get_bone_rest(Osso.BARRIGA).origin + Vector3(0.0, _carne.x, _carne.z))


## Publica para a verificacao: angulo da frente e das costas da saia, e desvio
## da barriga (y, z).
func estado_da_fisica() -> Vector4:
	return Vector4(_pano.x, _pano.z, _carne.x, _carne.z)


static func _luz_por_pixel() -> bool:
	var arvore := Engine.get_main_loop() as SceneTree
	if arvore == null:
		return true
	var ajustes := arvore.root.get_node_or_null(^"Settings")
	return ajustes == null or bool(ajustes.get(&"luz_por_pixel"))


## A piscada: um decimo de segundo de olho fechado a cada dois a cinco segundos,
## as vezes dupla. Intervalo sorteado, porque piscar em compasso e a primeira
## coisa que denuncia animacao em loop.
func _piscar(delta: float) -> void:
	if _fechado > 0.0:
		_fechado -= delta
		if _fechado <= 0.0:
			_palpebra.visible = false
		return
	_t_piscar -= delta
	if _t_piscar > 0.0:
		return
	_palpebra.visible = true
	_fechado = 0.11
	_t_piscar = 0.22 if randf() < 0.18 else randf_range(2.2, 5.2)


## Vira a cabeca para o lado, em passos. Quantizado como o resto: cabeca seguindo
## o jogador continuamente le como camera de vigilancia.
##
## O OLHO vai primeiro, a cabeca depois (`_atualizar_olhar`): quem vira a cara
## de uma vez para o alvo e camera; gente move o olho, e a cabeca vem atras, um
## passo de pescoco a cada dois passos do relogio.
## Para onde a pessoa olha: `angulo` e o giro em relacao a frente do corpo
## (positivo para a esquerda dela), `pitch` o quanto baixa a cabeca (positivo
## para baixo). O que passa do pescoco vai para o tronco, ate TORCAO_TRONCO.
func olhar_lateral(angulo: float, pitch: float = 0.0) -> void:
	var passo := LIMITE_PESCOCO / PASSOS_PESCOCO
	var total := clampf(angulo, -LIMITE_PESCOCO - TORCAO_TRONCO, LIMITE_PESCOCO + TORCAO_TRONCO)
	var preso := clampf(total, -LIMITE_PESCOCO, LIMITE_PESCOCO)
	_giro_alvo = roundf(preso / passo) * passo
	_torcao_alvo = roundf((total - preso) / passo) * passo
	_pitch_alvo = roundf(clampf(pitch, -PITCH_CIMA, PITCH_BAIXO) / PASSO_PITCH) * PASSO_PITCH
	if rosto == null:
		# Sem olho para ir na frente, a cabeca vai direto, como antes.
		if _giro_cabeca != _giro_alvo or _torcao != _torcao_alvo or _pitch != _pitch_alvo:
			_assinatura = -1
		_giro_cabeca = _giro_alvo
		_torcao = _torcao_alvo
		_pitch = _pitch_alvo


## Olha para um ponto do mundo: giro e pitch saem da posicao dos olhos.
func olhar_para(ponto: Vector3) -> void:
	var olhos := global_position + Vector3.UP * altura_da_boca()
	var d := ponto - olhos
	var plano := Vector2(d.x, d.z).length()
	var local := global_basis.inverse() * d
	olhar_lateral(atan2(-local.x, -local.z), atan2(-d.y, maxf(plano, 0.05)))


var _torcao_alvo := 0.0
var _torcao := 0.0
var _pitch_alvo := 0.0
var _pitch := 0.0
var _giro_alvo := 0.0
var _t_giro := 0.0
var _t_encarando := 0.0
var _desviando := 0.0


func _atualizar_olhar(delta: float) -> void:
	var passo := LIMITE_PESCOCO / PASSOS_PESCOCO
	var alvo := _giro_alvo
	# Quem nao sustenta o olhar (assustado, vigarista) encara um tanto e desvia.
	if int(jeito.get("contato", 0)) < 0 and absf(_giro_alvo) < 0.9:
		if _desviando > 0.0:
			_desviando -= delta
			alvo = _giro_alvo + (passo * 3.0 if _giro_alvo <= 0.0 else -passo * 3.0)
		else:
			_t_encarando += delta
			if _t_encarando > 1.4:
				_t_encarando = 0.0
				_desviando = 0.8
	var falta := alvo - _giro_cabeca
	# O olho: ja no lado do alvo enquanto a cabeca nao chegou.
	rosto.olhar(0 if absf(falta) < passo * 0.6 else (1 if falta > 0.0 else -1))
	_t_giro += delta
	if _t_giro < 2.0 / POSES_POR_CICLO:
		return
	_t_giro = 0.0
	if absf(falta) >= passo * 0.5:
		_giro_cabeca += passo * signf(falta)
		_assinatura = -1
	# O tronco so vem depois que a cabeca chegou no limite; o pitch anda junto.
	elif absf(_torcao_alvo - _torcao) >= passo * 0.5:
		_torcao += passo * signf(_torcao_alvo - _torcao)
		_assinatura = -1
	if absf(_pitch_alvo - _pitch) >= PASSO_PITCH * 0.5:
		_pitch += PASSO_PITCH * signf(_pitch_alvo - _pitch)
		_assinatura = -1


func falar(ativo: bool) -> void:
	_falando = ativo


## Troca a postura fixa. LIVRE devolve o corpo ao ciclo de andar e parar.
func postura(nova: Postura) -> void:
	if nova == _postura:
		return
	if nova != Postura.LEVANTANDO and _postura != Postura.LEVANTANDO:
		_comecar_mistura()
	# Ninguem anima o motorista da IA (so o monta sentado): ao volante o Corpo
	# se anima sozinho quando ninguem o anima (ver `_process`).
	set_process(nova == Postura.DIRIGINDO)
	_postura = nova
	_t_postura = 0.0
	# A assinatura e invalidada a mao: a pose nova pode calhar de dar a mesma
	# chave da anterior e o esqueleto ficaria com o corpo velho.
	_assinatura = -1


## Definir `_process` liga o processamento de TODO Corpo por padrao; so o
## motorista precisa dele (ver `postura`).
func _ready() -> void:
	set_process(_postura == Postura.DIRIGINDO)


func _process(delta: float) -> void:
	if _postura != Postura.DIRIGINDO or dominado:
		return
	if Engine.get_process_frames() - _animado_quadro > 1 and is_visible_in_tree():
		animar(0.0, delta)


## Ja escreveu alguma pose desde a montagem. Antes disso nao ha de onde
## misturar: o motorista do transito nasce, senta e so entao e animado, e a
## passagem partia do repouso de pe que ninguem viu — a cabeca furava o teto
## do carro durante o primeiro quarto de segundo, e no headless ate o fim.
var _ja_posou := false


## Guarda a pose de agora para a proxima nascer dela, e nao do nada.
func _comecar_mistura() -> void:
	if _esqueleto == null or dominado or not _ja_posou:
		return
	_mistura_de = {-1: _esqueleto.get_bone_pose_position(Osso.QUADRIL)}
	for osso in 11:
		_mistura_de[osso] = _esqueleto.get_bone_pose_rotation(osso)
	_t_mistura = MISTURA
	_assinatura = -1


func _aplicar_mistura() -> void:
	if _t_mistura <= 0.0 or _mistura_de.is_empty():
		return
	var k := 1.0 - _t_mistura / MISTURA
	k = floorf(k * 4.0) / 4.0
	k = smoothstep(0.0, 1.0, k)
	for osso in 11:
		var de: Quaternion = _mistura_de[osso]
		_esqueleto.set_bone_pose_rotation(osso, de.slerp(_esqueleto.get_bone_pose_rotation(osso), k))
	var p0: Vector3 = _mistura_de[-1]
	_esqueleto.set_bone_pose_position(Osso.QUADRIL,
		p0.lerp(_esqueleto.get_bone_pose_position(Osso.QUADRIL), k))


func postura_atual() -> Postura:
	return _postura


## Comeca a passagem do chao para de pe, e diz quanto tempo ela leva.
##
## O tempo entra AQUI, e nao so no tween externo que gira o `Node3D` inteiro de
## deitado a de pe. Os dois precisam do mesmo relogio: se o corpo levanta em
## dois segundos e o braco de apoio empurra em tres, a mao larga o chao antes de
## o tronco terminar de subir e atravessa a perna no meio do caminho.
func levantar(duracao: float) -> void:
	postura(Postura.LEVANTANDO)
	_duracao_levantar = maxf(duracao, 0.05)


## Comeca uma risada. So o gesto: o som e de quem chamou, porque o banco de voz
## depende do sexo e da altura da pessoa e isso mora na ficha, nao no corpo.
func rir(duracao: float = 1.3) -> void:
	_riso = duracao
	_assinatura = -1


func rindo() -> bool:
	return _riso > 0.0


## Comeca uma reacao da criacao de personagem. `desde` deixa quem remonta o
## corpo no meio de uma reacao continuar de onde ela estava, em vez de recomecar
## o gesto a cada clique.
func reagir(tipo: int, desde: float = 0.0) -> void:
	_reacao = tipo
	_t_reacao = maxf(0.0, desde)
	_assinatura = -1
	if rosto != null and tipo == ReacaoCorpo.OCIO_BOCEJO:
		rosto.reagir(Rosto.Expressao.RISO, ReacaoCorpo.duracao(tipo) * 0.7)
		rosto.micro(&"", &"FECHADO", ReacaoCorpo.duracao(tipo) * 0.6)
	elif rosto != null and tipo == ReacaoCorpo.REACAO_PROTEGE:
		rosto.reagir(Rosto.Expressao.MEDO, ReacaoCorpo.duracao(tipo))
	elif rosto != null and tipo == ReacaoCorpo.REACAO_XINGA:
		rosto.reagir(Rosto.Expressao.RAIVA, ReacaoCorpo.duracao(tipo) + 1.0)
	elif rosto != null and tipo >= ReacaoCorpo.REACAO_DOR_CABECA 			and tipo <= ReacaoCorpo.REACAO_DOR_BRACO:
		rosto.reagir(Rosto.Expressao.DOR, ReacaoCorpo.duracao(tipo) * 0.8)


func reacao() -> int:
	return _reacao


func tempo_da_reacao() -> float:
	return _t_reacao


## Onde fica o plano do rosto, em coordenada do osso da cabeca.
##
## Quem quiser colar alguma coisa na cara — uma mascara, um par de olhos
## vermelhos, um curativo — pendura no osso da cabeca e usa isto. A conta e do
## Corpo porque as medidas sao dele: a caixa da cabeca tem 21,4 cm de largura,
## fica 15,5 cm acima do pescoco e o rosto esta na face -Z, e nada disso e
## visivel de fora.
func plano_do_rosto() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, PI),
		Vector3(0.0, _y(1.595) - _y(Y_PESCOCO), -0.1125))


## Tamanho do rosto, para o quad colado nele bater com a celula do atlas.
func tamanho_do_rosto() -> Vector2:
	return Vector2(0.214, _y(0.245))


func osso_da_cabeca() -> int:
	return Osso.CABECA


## Trava um angulo na grade de POSES_POR_CICLO passos por volta.
##
## Dobra a fase para dentro de uma volta antes de travar. Sem o resto, a fase
## cresce para sempre e a pose travada nunca se repete: o seno sai igual, mas a
## assinatura muda a cada volta e o esqueleto e reescrito sem imagem nova
## nenhuma. Com o resto, um ciclo de caminhada usa exatamente quinze poses e as
## reusa para sempre.
static func _travar(fase: float) -> float:
	return floor(fmod(fase, TAU) / TAU * POSES_POR_CICLO) / POSES_POR_CICLO * TAU


func _girar(osso: int, x: float, y: float = 0.0, z: float = 0.0) -> void:
	var b := Basis.from_euler(Vector3(x, y, z))
	_esqueleto.set_bone_pose_rotation(osso, b.get_rotation_quaternion())


## A cabeca: `inclina` positivo olha para BAIXO, que e como todo o arquivo, o
## `Jeito` e o `ReacaoCorpo` escrevem ("celular 0,40, olhando para baixo", "ceu
## -0,45, olha para o alto"). O osso gira ao contrario — x positivo leva a cara
## para cima e para tras, como o tronco (ver `BonecoDePano.LIMITES`) — e por
## isso o sinal troca aqui, num lugar so. Antes desta troca a pessoa mexia no
## celular olhando para o ceu e o sonhador olhava para o chao.
func _girar_cabeca(inclina: float, giro: float, tombo: float = 0.0) -> void:
	_girar(Osso.CABECA, -inclina, giro, tombo)


func _aplicar_pose() -> void:
	if _esqueleto == null or dominado:
		return
	# LEVANTANDO sai por conta propria, antes de tudo o resto. As outras posturas
	# sao cicladas — `_travar` dobra a fase numa volta que se repete para sempre
	# — e esta e o oposto: comeca no chao e acaba de pe, uma vez so, e o "onde
	# estou" dela e HA QUANTO TEMPO comecou, nao onde caiu numa volta de ciclo.
	# Encaixar isso na maquina de cima exigiria fingir um ciclo que nunca se
	# repete, o que so complicaria a leitura sem ganhar nada.
	if _postura == Postura.LEVANTANDO:
		_aplicar_levantar()
		return
	var fixa := _postura != Postura.LIVRE
	var andando := _rapidez > 0.15 and not fixa
	var correndo := andando and _rapidez > LIMIAR_CORRIDA
	var f := _travar(_fase) if andando else _travar(
		(_t_postura if fixa else _t_parado) * 1.1)
	# Comecar a andar, parar, comecar a correr: passagem, e nao salto.
	var mov := (2 if correndo else 1) if andando else 0
	if _mov_antes >= 0 and mov != _mov_antes and not fixa:
		_comecar_mistura()
	_mov_antes = mov
	# Assinatura: pose travada, estado e angulo de cabeca. Enquanto os tres nao
	# mudam nao ha o que escrever, e escrever pose em onze ossos por quadro para
	# dez pedestres e custo puro sem imagem nova nenhuma.
	var chave := int(f * 1000.0) * 8 + (4 if andando else 0) + (2 if _falando else 0)
	chave = chave * 31 + int(_giro_cabeca * 100.0) + int(_gesto * 4.0) * 7
	chave = chave * 59 + int(_torcao * 100.0) * 3 + int(_pitch * 100.0)
	chave = chave * 7 + int(_postura)
	# A tragada tem ciclo proprio — 6,5 s contra os 5,7 s da respiracao — e sem
	# ela na chave o braco congela no meio do gesto: a pose travada nao muda, a
	# subida muda, e o cache devolve a de antes. Quinze passos por ciclo, que e
	# a mesma grade de POSES_POR_CICLO do resto do arquivo.
	# Danca tem relogio proprio: a batida anda a cada quadro.
	if _postura == Postura.DANCANDO:
		chave = chave * 23 + int(_t_postura * 14.0)
	if _postura == Postura.FUMANDO or _postura == Postura.ENCOSTADO \
			or (_postura == Postura.ASSENTO and tragando):
		chave = chave * 19 + int(fmod(_t_postura, CICLO_TRAGADA)
			/ CICLO_TRAGADA * POSES_POR_CICLO)
	# O balanco de chapado e o riso entram na assinatura, senao a pose fica
	# presa no cache e nenhum dos dois se ve.
	if chapado:
		chave = chave * 13 + int(_t_chapado * 3.4)
	if _riso > 0.0:
		chave = chave * 17 + int(_riso * 22.0)
	if _reacao != 0:
		chave = chave * 29 + _reacao * 1000 \
			+ int(_t_reacao * ReacaoCorpo.PASSOS_POR_SEGUNDO)
	if inclinacao != Vector2.ZERO or debater > 0.0:
		chave = chave * 37 + int(inclinacao.x * 50.0) * 101 + int(inclinacao.y * 50.0) \
			+ int(debater * 10.0) * 7919 + int(_t_debater * POSES_POR_CICLO) * 31 \
			+ int(rumo_passo * 5.0) * 17
	chave = chave * 43 + (1 if correndo else 0) + (2 if agachado else 0) \
		+ int(ceilf(_t_mistura * POSES_POR_CICLO)) * 5
	if _postura == Postura.PEDALANDO:
		chave = chave * 47 + int(_travar(pedal_fase) * 1000.0)
	if agarrar != Vector3.INF:
		var a := global_transform.affine_inverse() * agarrar
		chave = chave * 61 + int(a.x * 20.0) * 4099 + int(a.y * 20.0) * 67 + int(a.z * 20.0)
	if mancando > 0.0:
		chave = chave * 53 + int(mancando * 10.0) + perna_ruim * 17
	if _postura == Postura.DIRIGINDO:
		chave = chave * 41 + int(_t_postura * 3.0)
	if chave == _assinatura:
		return
	_assinatura = chave
	_ja_posou = true

	match _postura:
		Postura.SENTADO:
			_pose_sentado(f)
		Postura.CONTROLE:
			_pose_controle(f)
		Postura.FUMANDO:
			_pose_fumando(f)
		Postura.ENCOSTADO:
			_pose_encostado(f)
		Postura.DEITADO_ACORDAR:
			_pose_deitado_acordar()
		Postura.TRABALHANDO:
			_pose_trabalhando(f)
		Postura.ASSENTO:
			_pose_assento(f)
		Postura.DANCANDO:
			_pose_dancando()
		Postura.DIRIGINDO:
			_pose_dirigindo(f)
		Postura.PEDALANDO:
			_pose_pedalando()
		_:
			if correndo and not agachado:
				_pose_correndo(f)
			elif andando:
				_pose_andando(f)
			else:
				_pose_parado(f)
			if agachado:
				_agachar(f, andando)
	if debater > 0.0:
		_bracos_em_moinho()
	if inclinacao != Vector2.ZERO:
		_inclinar_sobre_os_pes()
	if agarrar != Vector3.INF:
		_agarrar()

	# A cabeca fica por ultimo: ela sobrescreve o que a pose escreveu, porque
	# olhar para o jogador vale mais que qualquer balanco de caminhada.
	var inclina := float(jeito.get("cabeca", 0.0))
	if andando and int(jeito.get("maos", 0)) == Jeito.Maos.CELULAR:
		# Quem anda com o celular na mao anda olhando para ele.
		inclina += 0.32
	var tombo := 0.0
	if float(jeito.get("zigue", 0.0)) > 0.0:
		tombo += sin(_fase * 0.5 + _t_parado * 0.8) * 0.06
	if _falando:
		inclina += sin(_gesto * 1.7) * 0.05
	if _postura == Postura.PEDALANDO:
		# Curvado sobre o guidao, a cabeca levanta para olhar a rua.
		inclina -= 0.30
	if correndo:
		inclina -= 0.08
	if chapado:
		# Pescoco mole. O balanco e lento de proposito — a um hertz vira
		# cabeceio de quem esta dormindo, e a um quarto de hertz vira o corpo
		# pesado de quem nao tem pressa de sustentar a propria cabeca.
		var b := _t_chapado * 0.9
		inclina += 0.07 + sin(b) * 0.05
		tombo = cos(b * 0.61) * 0.09
	if _postura == Postura.ENCOSTADO:
		# Cabeca baixa, lendo a tela. E o que separa "encostado na parede" de
		# "encostado na parede mexendo no celular": sem o queixo caido, o
		# aparelho na mao vira um objeto qualquer que o sujeito esta segurando.
		# Sobe na tragada, porque ninguem leva o cigarro a boca de cabeca baixa.
		inclina += 0.36 - _subida_da_tragada() * 0.22
	if _riso > 0.0:
		# Rir joga a cabeca para tras em solavanco. E o gesto inteiro: a
		# cadencia rapida contra o balanco lento do resto do corpo e o que faz
		# a risada aparecer sem uma animacao nova.
		inclina -= (0.10 + sin(_riso * 26.0) * 0.06)
	var giro := _giro_cabeca
	inclina += _pitch
	if _torcao != 0.0:
		# O tronco gira sobre o quadril, e a cabeca vai com ele.
		_esqueleto.set_bone_pose_rotation(Osso.TORSO,
			Quaternion(Vector3.UP, _torcao) * _esqueleto.get_bone_pose_rotation(Osso.TORSO))
	if _postura == Postura.DIRIGINDO:
		giro += _olhada_do_motorista()
	if _reacao != 0:
		var extra := ReacaoCorpo.aplicar(self, _reacao, _t_reacao)
		inclina += extra.x
		giro += extra.y
		tombo += extra.z
	_girar_cabeca(inclina, giro, tombo)
	_aplicar_mistura()


## O motorista confere os retrovisores: o da esquerda com mais frequencia, o de
## dentro de vez em quando. Periodo e fase da pessoa, para dois carros parados
## no sinal nao olharem juntos.
func _olhada_do_motorista() -> float:
	var t := fmod(_t_postura + float(jeito.get("fase", 0.0)) * 1.7, 9.0)
	if t < 0.8:
		return 0.55
	if t > 5.0 and t < 5.6:
		return -0.35
	return 0.0


## O relogio e a assinatura do levantar, separados do resto porque nao repetem.
##
## Travado nos mesmos passos por segundo do ciclo de caminhada — nao suave. Um
## levantar liso ao lado de um andar de quinze poses por ciclo leria como um
## corpo emprestado de outro jogo no meio deste.
const PASSOS_LEVANTAR := 24.0

func _aplicar_levantar() -> void:
	var p := clampf(_t_postura / _duracao_levantar, 0.0, 1.0)
	p = floor(p * PASSOS_LEVANTAR) / PASSOS_LEVANTAR
	var chave := 9_000_000 + int(p * PASSOS_LEVANTAR)
	if chave != _assinatura:
		_assinatura = chave
		_pose_levantando(p)
	# A cabeca por ultimo, do mesmo jeito que as posturas ciclicas fazem la
	# embaixo — so que calculada a partir do MESMO p travado, e nao suave: sem
	# isso ela deslizaria continua enquanto o resto do corpo pula de pose em
	# pose, e a costura ficaria visivel.
	var e := 1.0 - pow(1.0 - p, 3.0)
	var empurra := clampf(e / 0.55, 0.0, 1.0)
	var de_pe := clampf((e - 0.55) / 0.45, 0.0, 1.0)
	_girar_cabeca(lerp(lerp(0.0, 0.34, empurra), 0.0, de_pe), _giro_cabeca)


## O levantar em duas fases: empurra contra o chao, depois fica de pe.
##
## Fase 1 — empurra (e de 0,0 a 0,55): a mao direita desce e planta a palma no
## chao ao lado do quadril, cotovelo dobrado; a esquerda apoia mais leve do
## outro lado. A perna esquerda dobra e planta o pe, a direita dobra menos e so
## acompanha. O tronco curva para a frente, puxado pelo proprio peso subindo.
##
## Fase 2 — fica de pe (e de 0,55 a 1,0): tudo isso desfaz na ordem inversa —
## os bracos soltam o chao e caem ao lado do corpo, as pernas esticam, o tronco
## endireita. Termina no MESMO angulo de repouso que `_pose_parado` usa parada,
## de proposito: e para onde a postura troca assim que o corpo fica de pe.
##
## O quadril sobe do chao para a altura de pe ao longo da animacao inteira, e
## nao so numa das duas fases — e o "peso subindo" que as duas fases empurram
## contra.
func _pose_levantando(p: float) -> void:
	var e := 1.0 - pow(1.0 - p, 3.0)
	var empurra := clampf(e / 0.55, 0.0, 1.0)
	var de_pe := clampf((e - 0.55) / 0.45, 0.0, 1.0)

	var rest: Vector3 = _esqueleto.get_bone_rest(Osso.QUADRIL).origin
	_esqueleto.set_bone_pose_position(Osso.QUADRIL,
		rest + Vector3(0.0, -_y(0.30) * (1.0 - e), 0.0))

	# Braco direito: da lateral do corpo ate plantado no chao, e de volta.
	_girar(Osso.BRACO_D, lerp(lerp(0.05, 1.30, empurra), 0.03, de_pe),
		0.0, lerp(lerp(-0.05, -0.55, empurra), -0.07, de_pe))
	_girar(Osso.ANTEBRACO_D, lerp(lerp(0.15, 1.40, empurra), 0.16, de_pe))

	# Braco esquerdo: o mesmo apoio, mais leve — o peso real esta no direito.
	_girar(Osso.BRACO_E, lerp(lerp(0.05, 0.60, empurra), 0.03, de_pe),
		0.0, lerp(lerp(0.10, 0.32, empurra), 0.07, de_pe))
	_girar(Osso.ANTEBRACO_E, lerp(lerp(0.15, 0.95, empurra), 0.16, de_pe))

	# Perna esquerda: planta o pe cedo e empurra; a direita acompanha mais
	# solta e so estica de verdade na segunda fase.
	_girar(Osso.COXA_E, lerp(lerp(0.0, -1.50, empurra), 0.0, de_pe), 0.0, 0.05)
	_girar(Osso.CANELA_E, lerp(lerp(0.0, 1.65, empurra), -0.04, de_pe))
	_girar(Osso.COXA_D, lerp(lerp(0.0, -0.45, empurra), 0.0, de_pe), 0.0, -0.06)
	_girar(Osso.CANELA_D, lerp(lerp(0.0, 1.20, empurra), -0.02, de_pe))

	# Tronco: curva empurrando, endireita ficando de pe.
	_girar(Osso.TORSO, lerp(lerp(0.0, 0.60, empurra), -0.01, de_pe), 0.0, 0.0)



## Deitado acordando: articula o esqueleto COM o Basis de `_deitar`.
##
## Nao e double-transform do tronco — o Node3D ja esta de costas no chao; aqui
## so joelhos/bracos. Angulos antigos (~1,1 / 1,5) liam "perna quebrada" nos
## takes externos a 7–12 m. Agora: dobra leve (silhueta humana no lower-third,
## legivel a 480×270 na nevoa). FP de pernas nao roda nesta abertura (corpo
## oculto no POV).
func _pose_deitado_acordar() -> void:
	# Coxa/canela: dobra suave, assimetria leve — nao caixa reta, nao joelho
	# invertido. Valores em radianos, pensados pra leitura em silhueta.
	_girar(Osso.COXA_E, -0.42, 0.0, 0.10)
	_girar(Osso.CANELA_E, 0.55)
	_girar(Osso.COXA_D, -0.36, 0.0, -0.10)
	_girar(Osso.CANELA_D, 0.48)
	_girar(Osso.TORSO, 0.08)
	# Bracos ao lado do tronco, antebraco levemente dobrado (repouso no calcamento).
	_girar(Osso.BRACO_E, 0.12, 0.0, 0.28)
	_girar(Osso.ANTEBRACO_E, 0.28)
	_girar(Osso.BRACO_D, 0.12, 0.0, -0.28)
	_girar(Osso.ANTEBRACO_D, 0.28)


func _pose_andando(f: float) -> void:
	# Mancando, o tempo em cima da perna ruim encurta: a fase corre mais depressa
	# enquanto ela aguenta o peso (f + a sen f acelera perto de f = 0, que e o
	# apoio da direita; o sinal troca para a esquerda). E o "tum-ta, tum-ta" do
	# mancar, que de longe se le antes de qualquer angulo.
	f += 0.45 * mancando * sin(f) * float(perna_ruim)
	var escala := clampf(_rapidez / 2.2, 0.5, 1.3) * float(_aparencia.get("passo", 1.0))
	var esq := sin(f)
	var dir := sin(f + PI)

	# O passo sai na direcao de `rumo_passo`: a coxa balanca em x para a frente
	# e em z para o lado (z positivo leva o pe para +x). Andando normal o rumo
	# e zero e isto e o balanco de sempre.
	var frente := cos(rumo_passo)
	var lado := sin(rumo_passo)
	var a_e := esq * AMPLITUDE_PERNA * escala
	var a_d := dir * AMPLITUDE_PERNA * escala
	var ruim_e := mancando if perna_ruim < 0 else 0.0
	var ruim_d := mancando if perna_ruim > 0 else 0.0
	a_e *= 1.0 - 0.35 * ruim_e
	a_d *= 1.0 - 0.35 * ruim_d
	# A perna esta de apoio quando vai para tras (a coxa diminuindo): -cos na
	# esquerda, cos na direita.
	var apoio_ruim := maxf(0.0, -cos(f)) * ruim_e + maxf(0.0, cos(f)) * ruim_d
	# Pe mais aberto (gordura, bebado): a coxa esquerda abre com z negativo.
	var abre := float(jeito.get("largura", 0.0)) * 1.2
	_girar(Osso.COXA_E, a_e * frente, 0.0, a_e * lado - abre)
	_girar(Osso.COXA_D, a_d * frente, 0.0, a_d * lado + abre)
	# O joelho so dobra para tras, e dobra mais quando a perna esta atras do
	# corpo: e o calcanhar subindo no fim da passada. Dobrar nos dois sentidos
	# faz a perna quebrar para a frente, que foi o primeiro resultado aqui.
	_girar(Osso.CANELA_E, -(0.10 + 0.62 * maxf(0.0, -sin(f + 0.55))) * escala
		* (1.0 - 0.6 * ruim_e))
	_girar(Osso.CANELA_D, -(0.10 + 0.62 * maxf(0.0, -sin(f + PI + 0.55))) * escala
		* (1.0 - 0.6 * ruim_d))

	# Braco oposto a perna do mesmo lado. E o detalhe que separa "anda" de
	# "desliza com as pernas mexendo".
	# O balanco do braco e da pessoa: maior no apressado, curto no cinico, e um
	# lado sempre balanca um pouco mais que o outro.
	var jb := float(jeito.get("braco", 1.0))
	var ja := float(jeito.get("assimetria", 0.0))
	_girar(Osso.BRACO_E, dir * AMPLITUDE_BRACO * escala * jb * (1.0 + ja), 0.0, 0.06 - _abducao)
	_girar(Osso.BRACO_D, esq * AMPLITUDE_BRACO * escala * jb * (1.0 - ja), 0.0, -0.06 + _abducao)
	_girar(Osso.ANTEBRACO_E, 0.22 + 0.30 * maxf(0.0, dir) * escala)
	_girar(Osso.ANTEBRACO_D, 0.22 + 0.30 * maxf(0.0, esq) * escala)
	_maos_do_jeito(esq)

	# O tronco torce contra as pernas e o quadril sobe duas vezes por ciclo, uma
	# a cada passo. Sem a torcao o corpo anda como armario empurrado.
	var zigue := float(jeito.get("zigue", 0.0))
	var bambo := 1.0 + 2.0 * float(jeito.get("bamboleio", 0.0))
	var cambaleia := sin(f * 0.5) * 0.07 * zigue
	_girar(Osso.TORSO, -0.03 + float(jeito.get("curvatura", 0.0)) - 0.08 * mancando
		- apoio_ruim * 0.10, -sin(f) * 0.07,
		-cambaleia * 0.6 - apoio_ruim * 0.2 * float(perna_ruim))
	var rest: Vector3 = _esqueleto.get_bone_rest(Osso.QUADRIL).origin
	_esqueleto.set_bone_pose_position(Osso.QUADRIL,
		rest + Vector3(0.0, absf(sin(f)) * _y(0.022) * float(jeito.get("quique", 1.0))
			- apoio_ruim * _y(0.065), 0.0))
	_girar(Osso.QUADRIL, 0.0, sin(f) * 0.05, cos(f) * 0.03 * bambo + cambaleia)


## Correndo: tronco para a frente, cotovelos em noventa graus bombeando, perna
## que vai mais longe e o joelho de tras dobrando mais, quique maior. E o que o
## jogador ve em terceira pessoa quando segura o correr, e o pedestre fugindo.
func _pose_correndo(f: float) -> void:
	var esq := sin(f)
	var dir := sin(f + PI)
	var passo := float(_aparencia.get("passo", 1.0))
	_girar(Osso.COXA_E, esq * 0.82 * passo + 0.12)
	_girar(Osso.COXA_D, dir * 0.82 * passo + 0.12)
	# Corredor apoia de joelho dobrado: com a perna de apoio esticada o pe
	# entrava 6 cm no piso no meio da passada.
	_girar(Osso.CANELA_E, -(0.45 + 1.1 * maxf(0.0, -sin(f + 0.6))))
	_girar(Osso.CANELA_D, -(0.45 + 1.1 * maxf(0.0, -sin(f + PI + 0.6))))
	var jb := float(jeito.get("braco", 1.0))
	_girar(Osso.BRACO_E, dir * 0.75 * jb, 0.0, 0.10 - _abducao)
	_girar(Osso.BRACO_D, esq * 0.75 * jb, 0.0, -0.10 + _abducao)
	_girar(Osso.ANTEBRACO_E, 1.45 + 0.15 * dir)
	_girar(Osso.ANTEBRACO_D, 1.45 + 0.15 * esq)
	_girar(Osso.TORSO, -0.20 + float(jeito.get("curvatura", 0.0)), -sin(f) * 0.12, 0.0)
	var rest: Vector3 = _esqueleto.get_bone_rest(Osso.QUADRIL).origin
	_esqueleto.set_bone_pose_position(Osso.QUADRIL,
		rest + Vector3(0.0, absf(sin(f)) * _y(0.05), 0.0))
	_girar(Osso.QUADRIL, -0.06, sin(f) * 0.08, cos(f) * 0.03)


## Agachado: o quadril desce, o tronco inclina, e as pernas saem de IK com o
## tornozelo no lugar do pe em pe — o pe fica plantado no chao, e nao boiando
## como na escala de antes (a capsula encolhia e o boneco virava anao). Andando
## agachado o pe vai e volta um pouco pela fase do passo.
func _agachar(f: float, andando: bool) -> void:
	var s := _escala
	var rest: Vector3 = _esqueleto.get_bone_rest(Osso.QUADRIL).origin
	var quadril := Transform3D(Basis.from_euler(Vector3(-0.35, 0.0, 0.0)),
		rest + Vector3(0.0, -0.36 * s, 0.10 * s))
	_esqueleto.set_bone_pose_position(Osso.QUADRIL, quadril.origin)
	_esqueleto.set_bone_pose_rotation(Osso.QUADRIL, quadril.basis.get_rotation_quaternion())
	_girar(Osso.TORSO, 0.05, 0.0, 0.0)
	for lado: float in [-1.0, 1.0]:
		var coxa := Osso.COXA_E if lado < 0.0 else Osso.COXA_D
		var x := _esqueleto.get_bone_global_rest(coxa).origin.x
		var vai := sin(f + (0.0 if lado < 0.0 else PI)) * 0.16 * s if andando else 0.0
		var alvo := Vector3(x, Y_TORNOZELO * s, -vai)
		# O IK que protege a ponta: sem tornozelo, o bico do sapato cravava 11 cm
		# no chao com a canela inclinada; assim a pessoa agacha na ponta do pe.
		var r := LevantarDoChao._ik_no_chao(self, quadril, coxa, alvo,
			Vector3(lado * 0.3, 0.0, -1.0), -1.0)
		_esqueleto.set_bone_pose_rotation(coxa, r[0])
		_esqueleto.set_bone_pose_rotation(coxa + 1, r[1])
	_girar(Osso.BRACO_E, 0.45, 0.0, 0.10 - _abducao)
	_girar(Osso.BRACO_D, 0.45, 0.0, -0.10 + _abducao)
	_girar(Osso.ANTEBRACO_E, 0.55)
	_girar(Osso.ANTEBRACO_D, 0.55)


## Pedalando: a cavalo no selim, curvado para o guidao, mao no punho e pe no
## pedal pela fase de verdade da pedivela (`pedal_fase`, a da bicicleta). Tudo
## em metros da bicicleta (`Quadro`): o no do Corpo fica na origem dela.
func _pose_pedalando() -> void:
	var quadril := Transform3D(Basis.from_euler(Vector3(-0.30, 0.0, 0.0)),
		Vector3(0.0, Quadro.ALTURA_SELIM - 0.01, Quadro.PEDALEIRA.z + 0.06))
	_esqueleto.set_bone_pose_position(Osso.QUADRIL, quadril.origin)
	_esqueleto.set_bone_pose_rotation(Osso.QUADRIL, quadril.basis.get_rotation_quaternion())
	_girar(Osso.TORSO, -0.22, 0.0, 0.0)
	var r := Quadro.BRACO_PEDAL
	for lado: float in [-1.0, 1.0]:
		var coxa := Osso.COXA_E if lado < 0.0 else Osso.COXA_D
		var x := _esqueleto.get_bone_global_rest(coxa).origin.x
		var p := pedal_fase + (0.0 if lado < 0.0 else PI)
		var pe := Quadro.PEDALEIRA + Vector3(x, -r * cos(p), r * sin(p))
		var ik := LevantarDoChao._ik(self, quadril, coxa, pe + Vector3(0.0, 0.07, 0.0),
			Vector3(0.0, 0.4, -1.0), -1.0)
		_esqueleto.set_bone_pose_rotation(coxa, ik[0])
		_esqueleto.set_bone_pose_rotation(coxa + 1, ik[1])
	var tronco := quadril * Transform3D(
		Basis(_esqueleto.get_bone_pose_rotation(Osso.TORSO)), _esqueleto.get_bone_rest(Osso.TORSO).origin)
	for lado: float in [-1.0, 1.0]:
		var braco := Osso.BRACO_E if lado < 0.0 else Osso.BRACO_D
		var mao := Vector3(lado * Quadro.LARGURA_GUIDAO * 0.45, Quadro.ALTURA_GUIDAO - 0.03,
			Quadro.EIXO_FRENTE + 0.16)
		var ik := LevantarDoChao._ik(self, tronco, braco, mao, Vector3(lado * 0.6, -0.2, 1.0), 1.0)
		_esqueleto.set_bone_pose_rotation(braco, ik[0])
		_esqueleto.set_bone_pose_rotation(braco + 1, ik[1])


## O corpo inteiro inclinado sobre os pes: gira o quadril (raiz) em volta do
## ponto do chao entre os pes, e o tronco dobra um pouco mais na mesma direcao
## — quem perde o equilibrio quebra na cintura, nao cai duro como tabua.
func _inclinar_sobre_os_pes() -> void:
	var giro := Basis.from_euler(Vector3(-inclinacao.y, 0.0, -inclinacao.x))
	var q := Basis(_esqueleto.get_bone_pose_rotation(Osso.QUADRIL))
	var p := _esqueleto.get_bone_pose_position(Osso.QUADRIL)
	_esqueleto.set_bone_pose_rotation(Osso.QUADRIL, (giro * q).get_rotation_quaternion())
	_esqueleto.set_bone_pose_position(Osso.QUADRIL, giro * p)
	var t := Basis(_esqueleto.get_bone_pose_rotation(Osso.TORSO))
	var dobra := Basis.from_euler(Vector3(-inclinacao.y * 0.45, 0.0, -inclinacao.x * 0.3))
	_esqueleto.set_bone_pose_rotation(Osso.TORSO, (dobra * t).get_rotation_quaternion())


## Bracos em moinho (o "armsWindmill" do Euphoria): abertos para o lado e
## girando em circulo, cada um num tempo, misturados por cima da pose pelo
## quanto a pessoa esta perdendo o equilibrio.
func _bracos_em_moinho() -> void:
	var t := floorf(_t_debater * POSES_POR_CICLO) / POSES_POR_CICLO * 11.0
	var k := clampf(debater, 0.0, 1.0)
	for lado: float in [-1.0, 1.0]:
		var braco := Osso.BRACO_E if lado < 0.0 else Osso.BRACO_D
		var ante := Osso.ANTEBRACO_E if lado < 0.0 else Osso.ANTEBRACO_D
		var fase := t + (0.0 if lado < 0.0 else 1.9)
		var alvo := Basis.from_euler(Vector3(sin(fase) * 1.1, 0.0,
			lado * (0.9 + 0.5 * cos(fase))))
		var agora := _esqueleto.get_bone_pose_rotation(braco)
		_esqueleto.set_bone_pose_rotation(braco, agora.slerp(alvo.get_rotation_quaternion(), k))
		var cotovelo := Quaternion(Vector3.RIGHT, 0.35 + 0.35 * sin(fase + 1.0))
		_esqueleto.set_bone_pose_rotation(ante,
			_esqueleto.get_bone_pose_rotation(ante).slerp(cotovelo, k))


## A mao do lado do alvo vai ate `agarrar`, pelo IK de dois ossos do levantar,
## com o cotovelo para baixo e para fora. Alvo fora do alcance: o braco estica
## na direcao dele, que e o que se ve de quem se segura em alguem e nao chega.
func _agarrar() -> void:
	var local := _esqueleto.global_transform.affine_inverse() * agarrar
	var lado := 1.0 if local.x > 0.0 else -1.0
	var braco := Osso.BRACO_D if lado > 0.0 else Osso.BRACO_E
	var q_quadril := _esqueleto.get_bone_pose_rotation(Osso.QUADRIL)
	var quadril := Transform3D(Basis(q_quadril), _esqueleto.get_bone_pose_position(Osso.QUADRIL))
	var tronco := quadril * Transform3D(Basis(_esqueleto.get_bone_pose_rotation(Osso.TORSO)),
		_esqueleto.get_bone_rest(Osso.TORSO).origin)
	var polo := tronco * Vector3(lado * 0.6, -0.8, 0.2) - tronco.origin
	var r := LevantarDoChao._ik(self, tronco, braco, local, polo, 1.0)
	_esqueleto.set_bone_pose_rotation(braco, r[0])
	_esqueleto.set_bone_pose_rotation(braco + 1, r[1])


## As maos do jeito, por cima do balanco: no bolso, atras das costas ou no
## celular, com um resto de balanco do passo (`fase` e o seno do passo).
func _maos_do_jeito(fase: float) -> void:
	var m := int(jeito.get("maos", Jeito.Maos.LIVRES))
	var pose := ReacaoCorpo.OCIO_BOLSO
	match m:
		Jeito.Maos.BOLSO:
			pose = ReacaoCorpo.OCIO_BOLSO
		Jeito.Maos.ATRAS:
			pose = ReacaoCorpo.OCIO_ATRAS
		Jeito.Maos.CELULAR:
			pose = ReacaoCorpo.OCIO_CELULAR
		_:
			return
	var ossos: Dictionary = ReacaoCorpo.POSES[pose]["ossos"]
	for osso: int in [Osso.BRACO_E, Osso.ANTEBRACO_E, Osso.BRACO_D, Osso.ANTEBRACO_D]:
		if not ossos.has(osso):
			continue
		var e: Vector3 = ossos[osso]
		if osso == Osso.BRACO_E or osso == Osso.BRACO_D:
			e.x += fase * 0.05 * (1.0 if osso == Osso.BRACO_D else -1.0)
		_girar(osso, e.x, e.y, e.z)


func _pose_parado(f: float) -> void:
	var r := sin(f) * 0.5 + 0.5
	var gesticula := 0.0
	if _falando:
		# Gesto de conversa: o antebraco sobe e desce devagar, so um lado. Duas
		# maos mexendo juntas le como robo dando aula.
		gesticula = maxf(0.0, sin(_gesto)) * 0.5

	_girar(Osso.COXA_E, 0.0)
	_girar(Osso.COXA_D, 0.0)
	_girar(Osso.CANELA_E, -0.04)
	_girar(Osso.CANELA_D, -0.02)
	# O braco abre o quanto a barriga pede (ver `_medir_abducao`).
	_girar(Osso.BRACO_E, 0.02 + r * 0.02, 0.0, 0.07 - _abducao)
	_girar(Osso.BRACO_D, 0.02 + r * 0.02 - gesticula * 0.35, 0.0, -0.07 + _abducao)
	_girar(Osso.ANTEBRACO_E, 0.16)
	_girar(Osso.ANTEBRACO_D, 0.16 + gesticula)
	if not _falando and int(jeito.get("maos", 0)) in [Jeito.Maos.BOLSO, Jeito.Maos.ATRAS]:
		_maos_do_jeito(0.0)
	_girar(Osso.TORSO, -0.01 + r * 0.012 + float(jeito.get("curvatura", 0.0)), 0.0, 0.0)
	var rest: Vector3 = _esqueleto.get_bone_rest(Osso.QUADRIL).origin
	_esqueleto.set_bone_pose_position(Osso.QUADRIL,
		rest + Vector3(0.0, r * _y(0.006), 0.0))
	_girar(Osso.QUADRIL, 0.0, 0.0, 0.0)


# --- posturas fixas ---------------------------------------------------------

## Sentado no chao, pernas cruzadas, de frente para a TV.
##
## Num corpo rigido nao ha como dobrar o quadril: as caixas se atravessam. O que
## resolve e a mesma coisa que resolvia em 1998 — baixar o quadril ate a altura
## de quem esta no chao, girar as coxas para a frente e para fora, e dobrar as
## canelas de volta por baixo. As frestas que abrem no quadril e no joelho sao
## as mesmas que o esqueleto rigido abre no ombro quando o braco sobe, e fazem
## parte da imagem.
## Os angulos daqui foram RESOLVIDOS a partir das posicoes, e nao tateados.
##
## A primeira versao girava as coxas em -1,42 rad com um comentario dizendo
## "para a frente". Na convencao do proprio arquivo — ver `_pose_andando`, onde
## coxa positiva e a perna que avanca — o sinal negativo joga a coxa para TRAS,
## e era isso que estava na tela: quadril flutuando a 37 cm, joelho 39 cm atras
## do corpo, pe 3 cm abaixo do piso e as duas pernas se atravessando (coxa_E com
## z positivo puxa para +x, que e o lado DIREITO). Lendo o codigo as quatro
## linhas pareciam certas; quem achou foi `tests/medir_sentado.gd`.
##
## Aqui o caminho foi o inverso: primeiro as posicoes que uma pessoa sentada de
## pernas cruzadas tem, em metros e contadas do quadril —
##
##   joelho   (+0.24, -0.10, -0.34)   a frente e aberto para fora
##   tornozelo do joelho  (-0.38, -0.04, +0.22)   recolhido por baixo da outra coxa
##
## — e depois os angulos que levam o osso ate la, com `Basis.from_euler` na
## ordem YXZ que o motor usa. O joelho fecha 149 graus, que e o que um joelho
## humano faz nessa posicao e o limite dele.
##
## Os pes se cruzam, e isso e a postura e nao um defeito: pernas cruzadas
## cruzam. O criterio de linha de centro em `medir_sentado.gd` so vale de pe.
func _pose_sentado(f: float) -> void:
	var r := sin(f) * 0.5 + 0.5
	var rest: Vector3 = _esqueleto.get_bone_rest(Osso.QUADRIL).origin
	# 24 cm do chao: e onde para o quadril de quem senta de pernas cruzadas. Os
	# 37 cm de antes nao eram sentar, eram agachar no ar.
	_esqueleto.set_bone_pose_position(Osso.QUADRIL,
		rest + Vector3(0.0, -_y(0.66), 0.0))

	# Coxa para a FRENTE e aberta para FORA. O z e positivo do lado direito
	# porque em Rz o vetor que aponta para baixo vai para +x.
	_girar(Osso.COXA_E, 1.28, 0.0, -0.60)
	_girar(Osso.COXA_D, 1.28, 0.0, 0.60)
	# Canela dobrada por baixo e recolhida para o meio. Os tres angulos saem
	# juntos: sem o giro em Y o pe desce em vez de recolher, e enterra oito
	# centimetros no piso. Nesta combinacao o joelho fecha 139 graus, o
	# tornozelo para a 7 cm do chao e a ponta do pe a 4,5 cm — debaixo da outra
	# coxa, que e onde ela fica.
	_girar(Osso.CANELA_E, 2.64, -0.96, 0.54)
	_girar(Osso.CANELA_D, 2.64, 0.96, -0.54)

	# Tronco levemente para tras, como quem esta apoiado. O balanco lento e o
	# unico movimento: sem ele o sujeito le como movel.
	_girar(Osso.TORSO, 0.11 - r * 0.03, 0.0, 0.0)
	_girar(Osso.QUADRIL, -0.10, 0.0, 0.0)
	_bracos_no_controle(r)


## Sentado num assento de verdade — sofa, cadeira, banqueta.
##
## SENTADO e no chao, de pernas cruzadas. Este e o outro sentar: a pelve pousa
## em `altura_assento`, a coxa vai quase na horizontal para a frente e a canela
## desce quase reta. A conta: com a pelve 5 cm acima do assento, coxa a 1,45 rad
## e canela a -1,30, o tornozelo para a 7,6 cm do chao — a mesma altura de quem
## esta de pe. Em banqueta (0,75 m) o pe fica pendurado, que e o que acontece.
##
## Assento baixo e sofa: o tronco recosta. Assento alto e banqueta de balcao: o
## tronco vem para a frente, cotovelo na formica.
func _pose_assento(f: float) -> void:
	var r := sin(f) * 0.5 + 0.5
	var rest: Vector3 = _esqueleto.get_bone_rest(Osso.QUADRIL).origin
	_esqueleto.set_bone_pose_position(Osso.QUADRIL,
		Vector3(rest.x, altura_assento + 0.05, rest.z))
	_girar(Osso.QUADRIL, 0.0, 0.0, 0.0)
	_girar(Osso.COXA_E, 1.45, 0.0, -0.10)
	_girar(Osso.COXA_D, 1.45, 0.0, 0.10)
	_girar(Osso.CANELA_E, -1.30, 0.0, 0.06)
	_girar(Osso.CANELA_D, -1.30, 0.0, -0.06)
	var alto := altura_assento > 0.6
	var recosto := -0.10 if alto else 0.16
	_girar(Osso.TORSO, recosto + r * 0.02, 0.0, 0.0)
	var gesticula := maxf(0.0, sin(_gesto)) * 0.5 if _falando else 0.0
	# Mao no colo; no alto, antebraco apoiado a frente.
	var braco := -0.55 if alto else -0.30
	var ante := 1.35 if alto else 0.95
	_girar(Osso.BRACO_E, braco, 0.0, 0.12)
	_girar(Osso.ANTEBRACO_E, ante)
	if tragando:
		var subida := _subida_da_tragada()
		_girar(Osso.BRACO_D, braco - 0.25 * subida, 0.0, -0.12 - 0.20 * subida)
		_girar(Osso.ANTEBRACO_D, ante + 0.65 * subida)
	else:
		_girar(Osso.BRACO_D, braco - gesticula * 0.3, 0.0, -0.12)
		_girar(Osso.ANTEBRACO_D, ante + gesticula)


## Ao volante de um carro (PLANO_CARROS_AAA, F1).
##
## Nao e o ASSENTO: banco de carro fica a 20 cm do assoalho, e a canela que
## desce reta do ASSENTO atravessava o piso e aparecia pendurada debaixo do carro.
## Aqui a perna vai quase esticada para a frente, para os pedais, e fica inteira
## dentro do vao do painel. Os bracos vao ao aro do volante.
func _pose_dirigindo(f: float) -> void:
	var r := sin(f) * 0.5 + 0.5
	var rest: Vector3 = _esqueleto.get_bone_rest(Osso.QUADRIL).origin
	_esqueleto.set_bone_pose_position(Osso.QUADRIL,
		Vector3(rest.x, altura_assento + 0.05, rest.z))
	_girar(Osso.QUADRIL, 0.0, 0.0, 0.0)
	# Coxa quase na horizontal e canela so 17 graus abaixo dela: com o quadril a
	# 7 cm sobre a almofada, o pe fica 8 cm acima do assoalho. Mais dobrada, a
	# canela furava o piso.
	_girar(Osso.COXA_E, 1.50, 0.0, -0.08)
	_girar(Osso.COXA_D, 1.50, 0.0, 0.08)
	_girar(Osso.CANELA_E, -0.30, 0.0, 0.04)
	_girar(Osso.CANELA_D, -0.30, 0.0, -0.04)
	_girar(Osso.TORSO, 0.18 + r * 0.015, 0.0, 0.0)
	# O volante nunca esta parado: as duas maos corrigem de leve, juntas.
	var corrige := sin(_t_postura * 0.9 + float(jeito.get("fase", 0.0))) * 0.05
	_girar(Osso.BRACO_E, 1.05, 0.0, 0.22 + corrige)
	_girar(Osso.ANTEBRACO_E, 0.45)
	# E de vez em quando a mao direita desce ao cambio.
	var cambio := fmod(_t_postura + float(jeito.get("fase", 0.0)) * 3.1, 11.0)
	if cambio > 7.0 and cambio < 8.2:
		_girar(Osso.BRACO_D, 0.55, 0.0, -0.05)
		_girar(Osso.ANTEBRACO_D, 1.1)
	else:
		_girar(Osso.BRACO_D, 1.05, 0.0, -0.22 + corrige)
		_girar(Osso.ANTEBRACO_D, 0.45)


## Dancando perto da caixa de som, na batida do funk (~130 bpm).
##
## Tres coisas fazem a danca ler como danca a dez metros, e nenhuma e o braco: o
## quique (joelho dobrando no tempo, o corpo inteiro descendo), o quadril
## balancando de lado a cada dois tempos, e o tronco girando contra o quadril.
## Os bracos acompanham soltos. Joelho e coxa dobram juntos para o pe nao
## atravessar o piso quando o quadril desce.
const BATIDA_HZ := 2.15


func _pose_dancando() -> void:
	var t := _t_postura * TAU * BATIDA_HZ + float(_aparencia.get("cadencia", 1.0)) * 3.0
	var quique := absf(sin(t))
	var lado := sin(t * 0.5)
	var rest: Vector3 = _esqueleto.get_bone_rest(Osso.QUADRIL).origin
	_esqueleto.set_bone_pose_position(Osso.QUADRIL,
		rest + Vector3(lado * _y(0.035), -quique * _y(0.05), 0.0))
	_girar(Osso.QUADRIL, 0.0, -lado * 0.18, lado * 0.07)
	var dobra_e := quique * (1.0 if lado > 0.0 else 0.6)
	var dobra_d := quique * (0.6 if lado > 0.0 else 1.0)
	_girar(Osso.COXA_E, 0.35 * dobra_e, 0.0, 0.05)
	_girar(Osso.COXA_D, 0.35 * dobra_d, 0.0, -0.05)
	_girar(Osso.CANELA_E, -0.70 * dobra_e)
	_girar(Osso.CANELA_D, -0.70 * dobra_d)
	_girar(Osso.TORSO, 0.06, lado * 0.30, -lado * 0.05)
	var sobe := tragando and _subida_da_tragada() > 0.0
	_girar(Osso.BRACO_E, -0.55 - 0.30 * sin(t), 0.0, 0.25)
	_girar(Osso.ANTEBRACO_E, 1.25 + 0.35 * sin(t + 1.0))
	if sobe:
		var subida := _subida_da_tragada()
		_girar(Osso.BRACO_D, -0.30 * subida, 0.0, -0.07 - 0.22 * subida)
		_girar(Osso.ANTEBRACO_D, 0.30 + 1.62 * subida)
	else:
		_girar(Osso.BRACO_D, -0.55 + 0.30 * sin(t), 0.0, -0.25)
		_girar(Osso.ANTEBRACO_D, 1.25 + 0.35 * sin(t))


## De pe, segurando o controle. O corpo pesa numa perna so.
func _pose_controle(f: float) -> void:
	var r := sin(f) * 0.5 + 0.5
	var rest: Vector3 = _esqueleto.get_bone_rest(Osso.QUADRIL).origin
	_esqueleto.set_bone_pose_position(Osso.QUADRIL,
		rest + Vector3(0.0, r * _y(0.008), 0.0))
	# Uma perna reta e a outra relaxada, e o quadril caido para o lado dela. E o
	# que separa "de pe esperando" de "de pe em posicao de sentido".
	#
	# O z da coxa direita era -0,14, e 0,14 rad aplicados sobre uma perna de
	# noventa centimetros levam o pe 12 cm para dentro: o sujeito ficava de
	# joelho batendo no outro, com o pe direito do lado ESQUERDO da linha de
	# centro (medido: x=-0,078 contra os +0,094 da junta do quadril). Perna
	# relaxada cai um pouco para dentro no JOELHO e devolve no tornozelo; nao
	# atravessa a outra.
	# O tombo do quadril (-0,06 em Z, la embaixo) ja leva o pe direito 5 cm para
	# dentro sozinho: e ele que faz o peso cair numa perna so. A coxa nao
	# acrescenta mais nada nesse eixo, senao os dois pes se encostam.
	_girar(Osso.COXA_E, 0.0, 0.0, 0.04)
	_girar(Osso.COXA_D, -0.14, 0.0, 0.0)
	_girar(Osso.CANELA_E, -0.03)
	_girar(Osso.CANELA_D, -0.26)
	_girar(Osso.TORSO, 0.04, 0.0, 0.05)
	_girar(Osso.QUADRIL, 0.0, 0.0, -0.06)
	_bracos_no_controle(r)


## Os dois antebracos para a frente, na altura da cintura, com o polegar
## trabalhando. O tranco curto no ombro e a jogada: quem joga futebol de video
## game nao fica parado, se inclina junto com o passe.
##
## O braco era -0,62 e o antebraco +0,86, o que nao chegava a compensar: os dois
## punhos paravam 14 cm ATRAS do tronco (medido em `medir_sentado.gd`), ou seja
## o sujeito segurava o controle nas costas. Ombro quase solto e cotovelo
## fechado a 94 graus poem as duas maos a 18 cm de distancia uma da outra e
## 18 cm a frente do corpo, que e onde cabe um controle segurado com as duas.
func _bracos_no_controle(r: float) -> void:
	var tranco := sin(_t_postura * 5.3) * 0.05 + sin(_t_postura * 1.7) * 0.03
	_girar(Osso.BRACO_E, -0.19 + tranco, 0.0, 0.30)
	_girar(Osso.BRACO_D, -0.19 + tranco, 0.0, -0.30)
	_girar(Osso.ANTEBRACO_E, 1.64 - tranco * 0.5 + r * 0.02)
	_girar(Osso.ANTEBRACO_D, 1.64 - tranco * 0.5 + r * 0.02)


const CICLO_TRAGADA := 6.5


## Quanto o braco direito ja subiu para a boca, de 0 a 1.
##
## O ciclo tem quatro tempos e nao dois: sobe, segura na boca, desce, espera. A
## espera e a mais longa das quatro, porque e o que faz o gesto parecer casual
## em vez de mecanico — alguem que leva a mao a boca em intervalo regular le
## como animacao em loop, que e o que ele e.
##
## Duas posturas usam isto: quem esta so fumando e quem esta encostado na parede
## com o telefone na outra mao. E a mesma tragada, e havia de ser a mesma conta.
func _subida_da_tragada() -> float:
	var t := fmod(_t_postura, CICLO_TRAGADA) / CICLO_TRAGADA
	if t < 0.16:
		return t / 0.16
	if t < 0.44:
		return 1.0
	if t < 0.60:
		return 1.0 - (t - 0.44) / 0.16
	return 0.0


## De pe, com o baseado na mao direita, que sobe ate a boca de tempos em tempos.
func _pose_fumando(f: float) -> void:
	var r := sin(f) * 0.5 + 0.5
	var subida := _subida_da_tragada()

	_girar(Osso.COXA_E, 0.0, 0.0, 0.04)
	_girar(Osso.COXA_D, -0.06, 0.0, -0.10)
	_girar(Osso.CANELA_E, -0.04)
	_girar(Osso.CANELA_D, -0.16)
	_girar(Osso.BRACO_E, 0.02 + r * 0.02, 0.0, 0.07)
	_girar(Osso.BRACO_D, -0.30 * subida, 0.0, -0.07 - 0.22 * subida)
	_girar(Osso.ANTEBRACO_E, 0.16)
	# O antebraco fecha ate quase dois radianos: e o que leva a mao a altura do
	# rosto sem o ombro precisar subir.
	_girar(Osso.ANTEBRACO_D, 0.30 + 1.62 * subida)
	_girar(Osso.TORSO, -0.01 + r * 0.012, 0.0, 0.0)
	var rest: Vector3 = _esqueleto.get_bone_rest(Osso.QUADRIL).origin
	_esqueleto.set_bone_pose_position(Osso.QUADRIL,
		rest + Vector3(0.0, r * _y(0.006), 0.0))
	_girar(Osso.QUADRIL, 0.0, 0.0, 0.0)


## Encostado na parede, telefone numa mao e cigarro na outra.
##
## E a unica postura do jogo que faz duas coisas ao mesmo tempo. As outras tem
## um assunto so — sentado, com o controle na mao, fumando — e por isso cabem
## num braco cada uma. Esta precisa dos dois: com o cigarro sozinho o sujeito e
## um fumante parado, com o telefone sozinho e alguem esperando onibus. E a soma
## que le como "chegou cedo e nao tem nada para fazer", e a soma e o plano.
##
## O peso esta na parede, e nao nos pes
## ------------------------------------
## Tres coisas desenham isso, e sao as tres que faltavam na primeira versao: o
## quadril desce e vai a frente, o tronco deita para tras, e uma perna dobra com
## o pe apoiado atras. Sem elas o corpo fica de pe AO LADO da parede, que e
## outra postura e le como pessoa esperando alguem.
func _pose_encostado(f: float) -> void:
	var r := sin(f) * 0.5 + 0.5
	var subida := _subida_da_tragada()

	# Quatro centimetros abaixo e tres a frente: e o escorregao de quem apoiou
	# as costas e deixou os pes ficarem para tras.
	var rest: Vector3 = _esqueleto.get_bone_rest(Osso.QUADRIL).origin
	_esqueleto.set_bone_pose_position(Osso.QUADRIL,
		rest + Vector3(0.0, -_y(0.045) + r * _y(0.005), -_y(0.03)))
	_girar(Osso.QUADRIL, -0.05, 0.0, 0.0)
	# Positivo e para tras — a mesma conta do sentado, onde 0,11 ja lia como
	# apoiado. O balanco lento em cima e a respiracao.
	_girar(Osso.TORSO, 0.13 - r * 0.02, 0.0, 0.02)

	# Perna da frente esticada, perna de tras dobrada com o pe na parede. A
	# canela so dobra para tras: dobrar para os dois lados quebra o joelho para
	# a frente, que foi o primeiro resultado da caminhada.
	_girar(Osso.COXA_D, -0.20, 0.0, -0.06)
	_girar(Osso.CANELA_D, -0.07)
	_girar(Osso.COXA_E, 0.16, 0.0, 0.05)
	_girar(Osso.CANELA_E, -0.72)

	# Braco esquerdo: o telefone a frente do peito, cotovelo colado no corpo. O
	# tremor curto no antebraco e o polegar trabalhando — de longe nao se ve
	# polegar nenhum, se ve o aparelho balancando um grau, e e o que basta.
	var polegar := sin(_t_postura * 6.1) * 0.014 + sin(_t_postura * 2.3) * 0.010
	_girar(Osso.BRACO_E, -0.52 + polegar * 0.5, 0.0, 0.34)
	_girar(Osso.ANTEBRACO_E, 1.28 + polegar)

	# Braco direito: o cigarro, no mesmo ciclo de quatro tempos do fumante da
	# casa. Ele desce ate o lado do corpo entre uma tragada e outra, e e essa
	# descida que faz o gesto parecer casual em vez de mecanico.
	_girar(Osso.BRACO_D, -0.34 * subida, 0.0, -0.09 - 0.24 * subida)
	_girar(Osso.ANTEBRACO_D, 0.34 + 1.58 * subida)


## Debrucado sobre alguma coisa na altura da cintura, mexendo com as maos.
##
## Se dobra na CINTURA, e nao se agacha. Nao e falta de ambicao: o vaso tem
## 46 cm e a planta em cima dele, entao o que se mexe esta na altura do quadril,
## e quem trabalha nessa altura se dobra — agachar poria a cabeca do fazendeiro
## abaixo da boca do vaso, olhando para o feltro.
##
## Tambem e a pose que este esqueleto sabe fazer sem mentir. Agachar exige
## resolver joelho e tornozelo juntos, que foi o que custou duas rodadas na pose
## de sentado e acabou com o pe 8 cm dentro do chao; aqui as pernas quase nao
## mexem e nada pode furar o piso. A verificacao confere isso mesmo assim
## (`pe_abaixo_do_piso` em tools/verificar_estufa.py): pose que nao foi medida
## nao vale, mesmo quando o argumento e bom.
##
## O que faz ler como TRABALHO e a mao mexendo. Um corpo dobrado e parado le
## como alguem que deixou cair alguma coisa; o mesmo corpo com as maos indo e
## voltando devagar le como alguem ocupado — e sao dois senos.
func _pose_trabalhando(f: float) -> void:
	var r := sin(f) * 0.5 + 0.5
	# Duas frequencias irracionais entre si. Em compasso, as maos batem como
	# metronomo e o gesto vira maquina.
	var mexe := sin(_t_postura * 2.35)
	var funga := sin(_t_postura * 0.77)

	# Dobra para a frente, que aqui e NEGATIVO — a mesma conta do encostado e do
	# sentado, onde positivo joga o tronco para tras.
	_girar(Osso.TORSO, -0.58 - funga * 0.06, 0.0, mexe * 0.05)
	_girar(Osso.QUADRIL, -0.12, 0.0, 0.0)
	# O quadril recua tres centimetros: quem se dobra para a frente joga o peso
	# para tras, senao cai. Sem isto o corpo inteiro parece pendurado no peito.
	var rest: Vector3 = _esqueleto.get_bone_rest(Osso.QUADRIL).origin
	_esqueleto.set_bone_pose_position(Osso.QUADRIL,
		rest + Vector3(0.0, -_y(0.035), _y(0.03)))

	# Joelho de leve. Perna reta com tronco dobrado le como alongamento.
	_girar(Osso.COXA_E, 0.20, 0.0, -0.04)
	_girar(Osso.COXA_D, 0.18, 0.0, 0.04)
	_girar(Osso.CANELA_E, -0.26)
	_girar(Osso.CANELA_D, -0.24)

	# Os bracos caem para a frente e os cotovelos dobram: as maos ficam na boca
	# do vaso. Os dois lados fora de fase, porque duas maos fazendo o mesmo
	# movimento ao mesmo tempo e o que denuncia animacao espelhada.
	_girar(Osso.BRACO_E, 0.46 + mexe * 0.10, 0.0, 0.12)
	_girar(Osso.BRACO_D, 0.44 - mexe * 0.12, 0.0, -0.14)
	_girar(Osso.ANTEBRACO_E, 0.72 - mexe * 0.16 + r * 0.03)
	_girar(Osso.ANTEBRACO_D, 0.78 + mexe * 0.20 + r * 0.03)


## Quanto o baseado esta perto da boca agora, de 0 a 1. Quem desenha a brasa usa
## isto para acender no tempo certo: a brasa so cresce quando alguem traga.
func intensidade_da_tragada() -> float:
	if _postura != Postura.FUMANDO and _postura != Postura.ENCOSTADO:
		return 0.0
	var t := fmod(_t_postura, CICLO_TRAGADA) / CICLO_TRAGADA
	if t < 0.20 or t > 0.44:
		return 0.0
	return sin((t - 0.20) / 0.24 * PI)


## O osso onde pendurar o que a mao direita segura.
func osso_da_mao() -> int:
	return Osso.ANTEBRACO_D


## O mesmo, para a mao esquerda.
##
## Existem os dois porque a postura encostada e a primeira do jogo em que as
## duas maos seguram coisas diferentes ao mesmo tempo — cigarro numa, telefone
## na outra. Ate ela, "a mao" queria dizer a direita e ponto.
func osso_da_mao_esquerda() -> int:
	return Osso.ANTEBRACO_E


func esqueleto() -> Skeleton3D:
	return _esqueleto
