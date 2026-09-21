## Corpo humano de PS1: caixas rigidas penduradas num esqueleto de onze ossos.
##
## Por que esqueleto, se as pecas sao rigidas
## ------------------------------------------
## Nao e por deformacao — cada vertice tem UM osso e peso 1, entao o ombro abre
## uma fresta quando o braco sobe, exatamente como abria em 1998. E por draw
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
	ASSENTO, DANCANDO }

enum Osso {
	QUADRIL, TORSO, CABECA,
	BRACO_E, ANTEBRACO_E, BRACO_D, ANTEBRACO_D,
	COXA_E, CANELA_E, COXA_D, CANELA_D,
}

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

	_aplicar_pose()


func _y(v: float) -> float:
	return v * _escala


func _criar_ossos() -> void:
	var meio_ombro := float(_aparencia.get("ombro", 0.42)) * 0.5 + 0.015
	var meio_quadril := float(_aparencia.get("quadril", 0.30)) * 0.32

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

	# --- quadril e tronco ---
	_caixa(d, Vector3(quadril * c_tronco, _y(0.17), 0.23 * c_tronco),
		Vector3(0.0, _y(0.945), 0.0), a["calca_cor"], cel_calca, Osso.QUADRIL)
	if saia:
		# A saia e uma peca so, presa ao quadril. Cortada em duas metades ela
		# rasgaria no meio a cada passo, e o PS1 resolvia isso do mesmo jeito.
		_caixa(d, Vector3(quadril * c_tronco * 1.34, _y(0.30), 0.29 * c_tronco),
			Vector3(0.0, _y(0.79), 0.0), a["calca_cor"], cel_calca, Osso.QUADRIL)

	_caixa(d, Vector3(ombro * c_tronco, _y(0.34), 0.225 * c_tronco),
		Vector3(0.0, _y(1.21), 0.0), cor_camisa, cel_costas, Osso.TORSO,
		{PSXMesh.FACE_TRAS: cel_frente})
	# Barriga: uma caixa a mais na frente do tronco, que so aparece de verdade
	# quando o controle passa da metade. E a silhueta, e nao a largura do peito,
	# que diz de longe que a pessoa e gorda.
	if gordura > 0.42:
		var barriga := (gordura - 0.42) * 0.62
		_caixa(d, Vector3(ombro * c_tronco * 0.92, _y(0.26),
			(0.225 * c_tronco) * (1.0 + barriga * 2.2)),
			Vector3(0.0, _y(1.10), 0.0), cor_camisa, cel_frente, Osso.TORSO,
			{PSXMesh.FACE_TRAS: cel_frente})

	# --- cabeca ---
	_caixa(d, Vector3(0.10 * c, _y(0.08), 0.10 * c),
		Vector3(0.0, _y(1.465), 0.0), pele, cel_pescoco, Osso.CABECA,
		{}, PSXMesh.FACE_TODAS & ~PSXMesh.FACE_TOPO & ~PSXMesh.FACE_BASE)
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

	# --- bracos ---
	var manga_longa := bool(a.get("casaco", false)) or int(a["camisa"]) % 2 == 0
	var meio_ombro := ombro * 0.5 + 0.015
	for lado in [-1, 1]:
		var braco := Osso.BRACO_E if lado < 0 else Osso.BRACO_D
		var antebraco := Osso.ANTEBRACO_E if lado < 0 else Osso.ANTEBRACO_D
		var x := meio_ombro * float(lado)
		_caixa(d, Vector3(0.105 * c, _y(0.27), 0.115 * c),
			Vector3(x, _y(1.225), 0.0), cor_camisa, cel_manga, braco)
		_caixa(d, Vector3(0.095 * c, _y(0.24), 0.105 * c),
			Vector3(x, _y(0.97), 0.0),
			cor_camisa if manga_longa else pele,
			cel_manga if manga_longa else cel_pele, antebraco)
		# A mao tatuada usa a celula de espinhos e nao a de dedos: a tatuagem
		# de Jota cobre o dorso inteiro, e nessa escala a linha dos dedos e a
		# linha do espinho brigam pelos mesmos pixels. Ganha a que identifica.
		_caixa(d, Vector3(0.088, _y(0.10), 0.092),
			Vector3(x, _y(0.80), 0.0), pele,
			cel_pele if tatuado else cel_mao, antebraco)

	# --- pernas ---
	var meio_quadril := quadril * 0.32
	for lado in [-1, 1]:
		var coxa := Osso.COXA_E if lado < 0 else Osso.COXA_D
		var canela := Osso.CANELA_E if lado < 0 else Osso.CANELA_D
		var x := meio_quadril * float(lado)
		_caixa(d, Vector3(0.132 * c, _y(0.44), 0.165 * c),
			Vector3(x, _y(0.68), 0.0),
			pele if saia else a["calca_cor"],
			cel_nuca if saia else cel_calca, coxa)
		_caixa(d, Vector3(0.118 * c, _y(0.39), 0.14 * c),
			Vector3(x, _y(0.265), 0.0),
			pele if saia else a["calca_cor"],
			cel_nuca if saia else cel_calca, canela)
		# O pe aponta para -Z, que e a frente. Sem ele a perna acaba num toco e a
		# pessoa parece flutuar meio centimetro acima da calcada.
		_caixa(d, Vector3(0.128, _y(0.075), 0.25),
			Vector3(x, _y(0.037), -0.045), a["sapato_cor"], cel_sapato, canela)

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


## Altura da boca, para o som da voz sair da cabeca e nao dos pes.
func altura_da_boca() -> float:
	return _y(1.58)


# --- animacao ---------------------------------------------------------------

## Avanca o ciclo. `rapidez` em m/s.
func animar(rapidez: float, delta: float, no_chao: bool = true) -> void:
	_rapidez = rapidez
	var cadencia := float(_aparencia.get("cadencia", 1.0))
	if rapidez > 0.15 and no_chao:
		_fase += rapidez * delta * CICLOS_POR_METRO * TAU * cadencia
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
	_aplicar_pose()


## Vira a cabeca para o lado, em passos. Quantizado como o resto: cabeca seguindo
## o jogador continuamente le como camera de vigilancia.
func olhar_lateral(angulo: float) -> void:
	var preso := clampf(angulo, -LIMITE_PESCOCO, LIMITE_PESCOCO)
	var passo := LIMITE_PESCOCO / PASSOS_PESCOCO
	_giro_cabeca = roundf(preso / passo) * passo


func falar(ativo: bool) -> void:
	_falando = ativo


## Troca a postura fixa. LIVRE devolve o corpo ao ciclo de andar e parar.
func postura(nova: Postura) -> void:
	if nova == _postura:
		return
	_postura = nova
	_t_postura = 0.0
	# A assinatura e invalidada a mao: a pose nova pode calhar de dar a mesma
	# chave da anterior e o esqueleto ficaria com o corpo velho.
	_assinatura = -1


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


func _aplicar_pose() -> void:
	if _esqueleto == null:
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
	var f := _travar(_fase) if andando else _travar(
		(_t_postura if fixa else _t_parado) * 1.1)
	# Assinatura: pose travada, estado e angulo de cabeca. Enquanto os tres nao
	# mudam nao ha o que escrever, e escrever pose em onze ossos por quadro para
	# dez pedestres e custo puro sem imagem nova nenhuma.
	var chave := int(f * 1000.0) * 8 + (4 if andando else 0) + (2 if _falando else 0)
	chave = chave * 31 + int(_giro_cabeca * 100.0) + int(_gesto * 4.0) * 7
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
	if chave == _assinatura:
		return
	_assinatura = chave

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
		_:
			if andando:
				_pose_andando(f)
			else:
				_pose_parado(f)

	# A cabeca fica por ultimo: ela sobrescreve o que a pose escreveu, porque
	# olhar para o jogador vale mais que qualquer balanco de caminhada.
	var inclina := 0.0
	var tombo := 0.0
	if _falando:
		inclina = sin(_gesto * 1.7) * 0.05
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
	_girar(Osso.CABECA, inclina, _giro_cabeca, tombo)


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
	_girar(Osso.CABECA, lerp(lerp(0.0, 0.34, empurra), 0.0, de_pe), _giro_cabeca)


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
	var escala := clampf(_rapidez / 2.2, 0.5, 1.3) * float(_aparencia.get("passo", 1.0))
	var esq := sin(f)
	var dir := sin(f + PI)

	_girar(Osso.COXA_E, esq * AMPLITUDE_PERNA * escala)
	_girar(Osso.COXA_D, dir * AMPLITUDE_PERNA * escala)
	# O joelho so dobra para tras, e dobra mais quando a perna esta atras do
	# corpo: e o calcanhar subindo no fim da passada. Dobrar nos dois sentidos
	# faz a perna quebrar para a frente, que foi o primeiro resultado aqui.
	_girar(Osso.CANELA_E, -(0.10 + 0.62 * maxf(0.0, -sin(f + 0.55))) * escala)
	_girar(Osso.CANELA_D, -(0.10 + 0.62 * maxf(0.0, -sin(f + PI + 0.55))) * escala)

	# Braco oposto a perna do mesmo lado. E o detalhe que separa "anda" de
	# "desliza com as pernas mexendo".
	_girar(Osso.BRACO_E, dir * AMPLITUDE_BRACO * escala, 0.0, 0.06)
	_girar(Osso.BRACO_D, esq * AMPLITUDE_BRACO * escala, 0.0, -0.06)
	_girar(Osso.ANTEBRACO_E, 0.22 + 0.30 * maxf(0.0, dir) * escala)
	_girar(Osso.ANTEBRACO_D, 0.22 + 0.30 * maxf(0.0, esq) * escala)

	# O tronco torce contra as pernas e o quadril sobe duas vezes por ciclo, uma
	# a cada passo. Sem a torcao o corpo anda como armario empurrado.
	_girar(Osso.TORSO, -0.03, -sin(f) * 0.07, 0.0)
	var rest: Vector3 = _esqueleto.get_bone_rest(Osso.QUADRIL).origin
	_esqueleto.set_bone_pose_position(Osso.QUADRIL,
		rest + Vector3(0.0, absf(sin(f)) * _y(0.022), 0.0))
	_girar(Osso.QUADRIL, 0.0, sin(f) * 0.05, cos(f) * 0.03)


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
	_girar(Osso.BRACO_E, 0.02 + r * 0.02, 0.0, 0.07)
	_girar(Osso.BRACO_D, 0.02 + r * 0.02 - gesticula * 0.35, 0.0, -0.07)
	_girar(Osso.ANTEBRACO_E, 0.16)
	_girar(Osso.ANTEBRACO_D, 0.16 + gesticula)
	_girar(Osso.TORSO, -0.01 + r * 0.012, 0.0, 0.0)
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
