## Pecas da estrada de terra e da mata em volta, em dados brutos.
##
## Mesmo contrato do resto do kit: funcao estatica que escreve num dicionario de
## superficies por material, sem tocar em no nenhum. Quem transforma isso em
## malha e o `EstradaBuilder`.
##
## Por que nao reusa o KitParque
## -----------------------------
## Porque parque e mata sao coisas diferentes, e a diferenca esta exatamente no
## que este arquivo faz. A arvore do parque e larga, isolada e baixa — ela existe
## para ter sombra embaixo e banco do lado, e a paleta dela e de folha noturna
## sob poste de sodio. A arvore de mata fechada e alta, estreita e encostada na
## vizinha: o que se ve dela nunca e a copa inteira, e sim a fatia de tronco
## entre duas outras. Plantar arvore de praca em fila daria uma alameda, e o
## plano pede um corredor.
##
## O `KitParque.arbusto` continua servindo e e usado como esta, porque arbusto e
## arbusto em qualquer lugar.
##
## Nada aqui tem colisao
## ---------------------
## A cena da estrada e sobre trilhos: o carro anda no caminho calculado, e nao
## num corpo de fisica com roda. Gerar caixa de colisao para oitocentos troncos
## que ninguem vai encostar custaria mais que a geometria toda e nao mudaria um
## pixel. Se um dia a estrada virar lugar que se dirige de verdade, e aqui que a
## colisao entra, no mesmo formato do resto do kit.
##
## Orcamento
## ---------
## Medido: 96 triangulos por arvore, 24 por moita de mata, 4 por tufo de capim,
## 224 pelos 32 m de leito. Um trecho de 32 m com dezoito arvores, oito moitas e
## setenta tufos fecha em 2400, e cinco trechos cabem dentro dos 25.000 que o
## ART-BIBLE secao 10 permite ter na tela dentro da nevoa.
class_name KitEstrada
extends RefCounted

# --- materiais --------------------------------------------------------------

const M_LEITO := &"leito"
const M_MATO := &"mato"
const M_CASCA := &"casca"
const M_FOLHA := &"folhagem"
const M_FOLHA_RECORTE := &"folhagem_recorte"
const M_METAL := &"metal"
const M_TABUA := &"tabua"

# --- celulas do mato_atlas --------------------------------------------------
# Linha 0 e planta de pe, recortada no alfa. Linha 1 e chao, opaca.

const C_CAPIM := Vector2i(0, 0)
const C_CAPIM_SECO := Vector2i(1, 0)
const C_SAMAMBAIA := Vector2i(2, 0)
const C_FOLHA_LARGA := Vector2i(3, 0)
const C_MOITA_BAIXA := Vector2i(4, 0)
const C_GALHO_SECO := Vector2i(5, 0)
const C_FLOR := Vector2i(6, 0)
const C_CAPIM_RALO := Vector2i(7, 0)

const C_FOLHICO := Vector2i(0, 1)
const C_BARRO := Vector2i(1, 1)
const C_CASCALHO := Vector2i(2, 1)
const C_POCA := Vector2i(3, 1)

# --- medidas da estrada -----------------------------------------------------

## Meia largura do leito de terra, do eixo ate onde comeca o mato.
const MEIA_PISTA := 3.1
## Onde fica o centro de cada trilha de pneu, medido do eixo. Um metro e dez e
## a bitola de carro de verdade, e e o que faz as duas trilhas da print lerem
## como rastro de roda em vez de duas faixas pintadas.
const TRILHA := 1.10
const MEIA_TRILHA := 0.52

## Passo ao longo da estrada. Nao e escolha de gosto: a UV afim empena dentro de
## cada quad proporcionalmente ao tamanho dele, e o ART-BIBLE secao 4 poe o teto
## em 2 m. Um leito passo 4 sairia com a terra derretendo a cada solavanco.
const PASSO := 1.8

## Cores do leito. Multiplicam a celula, que e quase neutra de proposito.
##
## A trilha e MAIS CLARA que o resto, e nao mais escura: terra pisada por pneu
## perde o folhico e a materia organica e fica mais clara e mais cinzenta que a
## beira. E o desenho que a print mostra e o unico que le como estrada de terra
## em vez de duas faixas de barro.
## Quem carrega o TOM do barro e o `tint` do mat_leito, e nao estas cores.
##
## Elas ja foram vermelhas (1.4, 0.55, 0.28) e multiplicavam um tint que tambem
## era vermelho, o que dava barro numa razao de 1:0.18:0.05 — vermelho de brasa,
## nao de terra. Nas tres prints de referencia a estrada no facho mede
## 1:0.70:0.49 sempre, e esse numero agora esta no tint, num lugar so. Aqui
## ficou o que estas cores deviam fazer desde o comeco: a variacao de CLARIDADE
## entre uma faixa e outra, quase sem cor propria.
const COR_TRILHA := Color(1.10, 1.08, 1.05)
const COR_MEIO := Color(0.88, 0.86, 0.84)
const COR_BEIRA := Color(0.78, 0.76, 0.74)
## O folhico e a unica que puxa cor: e folha seca na beira, nao terra pisada.
const COR_FOLHICO := Color(0.62, 0.64, 0.55)

# --- cerca de divisa --------------------------------------------------------

## Madeira de mourao lavada de sol e chuva. A print mede 1:0.96:0.76 no facho —
## cinza morno, quase sem cor propria.
const COR_MOURAO := Color(0.78, 0.75, 0.60)
const COR_MOURAO_VELHO := Color(0.56, 0.54, 0.44)
## Alturas dos fios, do chao. Quatro fios e cerca de gado graude; tres e o que
## a print mostra e o que basta para ler como divisa.
const FIOS_CERCA := [0.46, 0.80, 1.12]
## Quanto o fio cede no meio do vao.
const BARRIGA_FIO := 0.055

## A secao do leito, do lado esquerdo para o direito. Cada item e
## [inicio, fim, celula, cor] em metros a partir do eixo.
##
## Sete colunas, e nao tres. As duas trilhas precisam de uma faixa de barro de
## cada lado para nao encostarem direto no folhico — sem essa transicao a
## estrada vira um retangulo claro colado na mata, que e o defeito classico de
## estrada de terra em jogo.
const SECAO: Array = [
	[-MEIA_PISTA, -2.05, C_FOLHICO, COR_FOLHICO],
	[-2.05, -TRILHA - MEIA_TRILHA, C_BARRO, COR_BEIRA],
	[-TRILHA - MEIA_TRILHA, -TRILHA + MEIA_TRILHA, C_BARRO, COR_TRILHA],
	# Meio com C_POCA (mais escuro/vermelho) — C_CASCALHO cinza virava areia no facho.
	#
	# Partido no eixo de proposito. O perfil do leito e dado por `sulco(e)`, que
	# so pode dobrar onde existe VERTICE: sem o corte em zero, a faixa do meio e
	# um quad unico entre duas bordas simetricas, le o mesmo numero nas duas e
	# sai plana — a coroa da estrada some e o meio afunda ate o fundo do sulco.
	[-TRILHA + MEIA_TRILHA, 0.0, C_POCA, COR_MEIO],
	[0.0, TRILHA - MEIA_TRILHA, C_POCA, COR_MEIO],
	[TRILHA - MEIA_TRILHA, TRILHA + MEIA_TRILHA, C_BARRO, COR_TRILHA],
	[TRILHA + MEIA_TRILHA, 2.05, C_BARRO, COR_BEIRA],
	[2.05, MEIA_PISTA, C_FOLHICO, COR_FOLHICO],
]

# --- paleta da mata ---------------------------------------------------------

## Verdes de mata no fim da tarde. Escuros e puxados para o oliva, porque a luz
## que vale nesta cena e o sol raso vindo de frente: a folha que aparece e a que
## esta em contraluz, e ela e quase preta com a borda quente. Verde de meio-dia
## aqui apaga o poente inteiro.
const VERDES: Array[Color] = [
	Color("46583a"), Color("3d5034"), Color("50603c"), Color("3a4a30"),
]
## Uma copa em cada seis e de folha seca. Sem isto a mata e um tapete verde de
## uma cor so, que e o que denuncia floresta gerada.
const SECOS: Array[Color] = [
	Color("7a6740"), Color("6b5a38"), Color("857046"),
]
const CASCA_TOM := Color("6f6252")

## Subdivisao folgada em tudo que e vegetacao. A textura de folha ja e ruido: a
## grade padrao de 2 m quadruplicaria o custo da copa sem mudar a imagem.
const QUAD_FOLHA := 4.0
const CEDE_COPA := 1.0
const CEDE_TRONCO := 0.12


# --- primitiva --------------------------------------------------------------

## Um quadrilatero qualquer com uma celula do atlas. E o tijolo do leito.
##
## Existe porque nem `KitModular.chao` nem `AtlasKit.deitado` servem: os dois
## desenham retangulo alinhado, e uma estrada que curva e feita de trapezios —
## os dois lados de um trecho tem comprimentos diferentes sempre que a curva
## aperta.
##
## Ordem dos cantos: a e b sao a borda de tras (esquerda e direita), c e d a da
## frente (direita e esquerda). A normal sai do produto vetorial dos dois
## primeiros lados.
##
## O giro do indice e o INVERSO da ordem dos cantos, de proposito
## ---------------------------------------------------------------
## No Godot a face da frente e a de giro horario em tela, que e o lado OPOSTO ao
## que o produto vetorial aponta. Os quatro usos desta funcao — leito, poca e as
## duas colunas de chao da mata — dao normal +Y, para cima, que e o certo para
## chao. Emitindo o indice na ordem dos cantos, a face saia virada para BAIXO: a
## normal dizia "para cima" e o giro dizia "para baixo", e o `cull_back` do
## psx_surface descartava o chao inteiro. O buraco nao aparecia como buraco
## porque a cupula do ceu, que e centrada na camera, tapava com o hemisferio de
## baixo dela — uma laje chapada de topo reto atravessada no quadro.
##
## Entao o indice sai invertido, e ai normal e giro concordam. Quem chamar isto
## para uma superficie nova nao precisa saber do truque: passe os cantos no
## sentido em que a normal deve apontar e a face aparece desse lado.
static func quad(sup: Dictionary, material: StringName, a: Vector3, b: Vector3,
		c: Vector3, d: Vector3, celula: Vector2i, cor: Color) -> void:
	if not sup.has(material):
		sup[material] = PSXMesh.dados_vazios()
	var dados: Dictionary = sup[material]
	var r := Carroceria.uv(celula)
	var v: PackedVector3Array = dados["v"]
	var n: PackedVector3Array = dados["n"]
	var u: PackedVector2Array = dados["uv"]
	var cc: PackedColorArray = dados["c"]
	var i: PackedInt32Array = dados["i"]

	var base := v.size()
	var normal := (b - a).cross(d - a).normalized()
	for p: Vector3 in [a, b, c, d]:
		v.append(p)
		n.append(normal)
		# Alfa 0: a rigidez ao vento. Chao nao balanca, e o shader le COLOR.a
		# como "quanto este vertice cede" — alfa 1 num leito de estrada faria a
		# terra ondular junto com o capim.
		cc.append(Color(cor.r, cor.g, cor.b, 0.0))
	u.append(r.position + Vector2(0.0, r.size.y))
	u.append(r.position + r.size)
	u.append(r.position + Vector2(r.size.x, 0.0))
	u.append(r.position)
	i.append_array([base, base + 2, base + 1, base, base + 3, base + 2])

	dados["v"] = v
	dados["n"] = n
	dados["uv"] = u
	dados["c"] = cc
	dados["i"] = i


# --- leito ------------------------------------------------------------------

## Um trecho de leito entre duas secoes transversais.
##
## `p0`/`p1` sao os pontos no eixo e `lado0`/`lado1` os vetores unitarios que
## apontam para a direita da estrada em cada um deles. Vem de fora porque quem
## sabe a curva e o caminho, nao o kit.
##
## `desgaste` de 0 a 1 escurece o trecho inteiro. E o que faz a estrada ter
## trechos de barro mais fundo e trechos mais secos sem precisar de outra
## textura: a mesma celula com a cor variando ao longo do caminho.
## Quanto o leito e erguido acima da linha do caminho.
##
## Existe para o leito nao brigar por pixel com o capo do carro nem com o chao
## da mata. Quem desenhar qualquer coisa que precise ENCOSTAR no leito tem de
## somar isto tambem, senao fica um degrau — e degrau entre duas superficies
## sem parede lateral e buraco, nao degrau.
const LIFT := 0.045


## O micro-relevo do leito: onda longa, ondulacao e chacoalho fino.
##
## Publica, e nao embutida em `leito`, porque o chao da mata precisa do MESMO
## numero na borda em que os dois se encontram. Enquanto ela era local, a beira
## do leito subia ate 25 cm acima do chao vizinho e, como o leito e uma fita sem
## saia, de angulo raso dava para ver por baixo dele — ate a serra do horizonte.
## Era a "listra clara" que corria ao lado da pista.
## Quanto da ondulacao sobra a `e` metros do eixo. Um no meio, 0,7 na beira.
##
## E o abaulamento da pista: estrada de terra e mais alta no meio para a agua
## correr para as valetas. Tem de ser funcao SO da distancia ao eixo, e nao do
## indice da faixa, senao duas faixas vizinhas discordam na borda comum — ver o
## comentario dentro de `leito`.
static func abaulamento(e: float) -> float:
	return 1.0 - 0.3 * clampf(absf(e) / MEIA_PISTA, 0.0, 1.0)


## O perfil transversal do leito a `e` metros do eixo: coroa no meio, duas
## trilhas cavadas, beira subindo de volta ao nivel.
##
## Por que e funcao de `e` e nao um valor por faixa
## ------------------------------------------------
## Isto ja foi um deslocamento constante aplicado a faixa inteira: -9 cm na
## trilha, -4 cm no meio, zero no resto. Como a borda de fora de uma faixa E a
## borda de dentro da vizinha, e as duas liam numeros diferentes, cada troca de
## valor abria uma fenda VERTICAL de ate nove centimetros correndo a estrada
## inteira — e o leito e uma fita sem parede lateral, entao dentro da fenda
## aparecia o fundo da cena. Eram as listras claras na pista: nao eram uma
## textura nem um material, eram buraco com a nevoa atras.
##
## Sendo funcao so de `e`, duas faixas que compartilham uma borda leem o mesmo
## numero nela por construcao e a fenda nao tem como existir. E a mesma regra de
## `abaulamento` — quem mexer no perfil do leito tem de mexer AQUI, e nunca no
## corpo de `leito`.
##
## Os patamares tem de cair sobre bordas de `SECAO`, senao a dobra fica no meio
## de um quad e o perfil e reto justamente onde deveria dobrar.
static func sulco(e: float) -> float:
	const FUNDO := -0.09
	const COROA := -0.02
	var a := absf(e)
	if a >= 2.05:
		return 0.0
	if a >= TRILHA + MEIA_TRILHA:
		return lerpf(0.0, FUNDO, (2.05 - a) / (2.05 - TRILHA - MEIA_TRILHA))
	if a >= TRILHA - MEIA_TRILHA:
		return FUNDO
	return lerpf(COROA, FUNDO, a / (TRILHA - MEIA_TRILHA))


static func ondulacao(p: Vector3) -> float:
	return (0.11 * sin(p.z * 1.35 + p.x * 0.55)
		+ 0.06 * sin(p.z * 4.2 + p.x * 1.1)
		+ 0.03 * sin(p.x * 3.8)
		+ 0.025 * sin(p.z * 7.1 + p.x * 2.4))


## Quanto a SUPERFICIE do leito esta acima da linha do caminho, a `e` metros
## do eixo. Some ao `y` de `EstradaBuilder.ponto_em(s)` para obter o chao.
##
## Existe porque tres coisas precisam do mesmo numero e nenhuma delas pode
## discordar das outras: o quad que DESENHA o leito (logo abaixo), a poca
## que pousa nele e a roda que anda em cima. Enquanto a conta estava
## repetida, a poca ficava quinze centimetros no ar e o carro andava
## enterrado na crista do micro-relevo — dois defeitos com a mesma causa em
## dois arquivos diferentes.
##
## `ondulacao` e lida no EIXO, e nao no ponto deslocado: e assim que `leito`
## a le, e lida no ponto deslocado ela devolve outro numero e tudo que
## deveria encostar desencosta de novo.
static func altura_da_pista(eixo: Vector3, e: float) -> float:
	return ondulacao(eixo) * abaulamento(e) + sulco(e) + LIFT


static func leito(sup: Dictionary, p0: Vector3, lado0: Vector3, p1: Vector3,
		lado1: Vector3, desgaste: float) -> void:
	var tom := lerpf(1.0, 0.78, clampf(desgaste, 0.0, 1.0))
	var lift := Vector3(0.0, LIFT, 0.0)
	var und0 := Vector3(0.0, ondulacao(p0), 0.0)
	var und1 := Vector3(0.0, ondulacao(p1), 0.0)
	for faixa: Array in SECAO:
		var e0: float = faixa[0]
		var e1: float = faixa[1]
		var celula: Vector2i = faixa[2]
		var cor: Color = faixa[3]
		# Nao esmagar G/B — albedo preto era a causa do chao invisivel no FP.
		var tom_faixa := tom * (1.12 if celula == C_BARRO else (1.0 if celula == C_POCA else 1.05))
		var sulco0 := Vector3(0.0, sulco(e0), 0.0)
		var sulco1 := Vector3(0.0, sulco(e1), 0.0)
		# O abaulamento sai de `abaulamento(e)`, avaliado na POSICAO da borda.
		#
		# Antes cada faixa usava `und` na borda de dentro e `und * 0.7` na de
		# fora — e como a borda de fora de uma faixa e a borda de dentro da
		# vizinha, as duas discordavam em ate seis centimetros na MESMA linha.
		# O leito e uma fita sem parede lateral, entao cada uma dessas seis
		# juntas virava uma fenda de um pixel correndo a estrada inteira, com o
		# fundo da cena aparecendo dentro dela. Era a "listra clara" na pista.
		#
		# Sendo funcao so de `e`, duas faixas que compartilham uma borda leem o
		# mesmo numero nela por construcao, e a junta deixa de existir.
		var f0 := abaulamento(e0)
		var f1 := abaulamento(e1)
		quad(sup, M_LEITO,
			p0 + lado0 * e0 + und0 * f0 + sulco0 + lift,
			p0 + lado0 * e1 + und0 * f1 + sulco1 + lift,
			p1 + lado1 * e1 + und1 * f1 + sulco1 + lift,
			p1 + lado1 * e0 + und1 * f0 + sulco0 + lift,
			celula, Color(cor.r * tom_faixa, cor.g * tom_faixa, cor.b * tom_faixa))


## A saia do leito: a parede vertical que fecha a beira da pista.
##
## Por que ela precisa existir
## ---------------------------
## O leito e uma FITA erguida — `LIFT` mais o abaulamento poem a superficie dele
## acima do terreno vizinho — e uma fita nao tem espessura. De qualquer angulo
## raso da para enxergar POR BAIXO da borda, e o que aparece no vao e o fundo da
## cena: nevoa, serra, mata distante. Vira uma listra clara correndo ao lado da
## pista, e ela reaparece toda vez que alguem mexe na altura do leito ou do
## barranco, porque a causa nunca foi a altura — foi a fita nao ter lateral.
##
## Meio metro para baixo e mais do que o degrau jamais vai ser, entao a saia
## fica enterrada no terreno onde o terreno e mais alto e aparece como um talude
## de terra onde o leito e mais alto. As duas leituras estao certas: e assim que
## se ve a beira de uma estrada de terra aterrada.
static func saia(sup: Dictionary, p0: Vector3, lado0: Vector3, p1: Vector3,
		lado1: Vector3) -> void:
	const FUNDO := 0.5
	var lift := Vector3(0.0, LIFT, 0.0)
	var f := abaulamento(MEIA_PISTA)
	var u0 := Vector3(0.0, ondulacao(p0) * f, 0.0)
	var u1 := Vector3(0.0, ondulacao(p1) * f, 0.0)
	var baixo := Vector3(0.0, -FUNDO, 0.0)
	for s: float in [-1.0, 1.0]:
		var e := MEIA_PISTA * s
		var a := p0 + lado0 * e + u0 + lift
		var b := p1 + lado1 * e + u1 + lift
		# A ordem inverte com o lado, senao uma das duas saias nasce virada para
		# dentro do aterro e some — a mesma regra de giro do `quad`.
		if s > 0.0:
			quad(sup, M_LEITO, a + baixo, b + baixo, b, a,
				C_BARRO, COR_BEIRA)
		else:
			quad(sup, M_LEITO, b + baixo, a + baixo, a, b,
				C_BARRO, COR_BEIRA)


## Mancha de barro escuro solta no meio do leito: o que sobrou da ultima chuva.
##
## Fica meio centimetro acima do leito, e nao no mesmo plano. Coplanar de
## verdade briga com o leito pelo mesmo pixel e a mancha pisca a cada quadro —
## o mesmo defeito que o piso do parque teve, e a mesma correcao.
static func poca(sup: Dictionary, centro: Vector3, lado: Vector3,
		frente: Vector3, tamanho: Vector2) -> void:
	var e := lado * (tamanho.x * 0.5)
	var f := frente * (tamanho.y * 0.5)
	var c := centro + Vector3(0.0, 0.005, 0.0)
	quad(sup, M_LEITO, c - e - f, c + e - f, c + e + f, c - e + f,
		C_POCA, Color(0.42, 0.16, 0.10))


# --- mato de beira ----------------------------------------------------------

## Um tufo de planta em cruz, preso pelo pe.
##
## Dois planos cruzados, e nao um: um plano so desaparece de perfil, e o carro
## passa RENTE a beira — o tufo que some quando o capo chega nele e pior que
## tufo nenhum.
static func tufo(sup: Dictionary, base: Vector3, celula: Vector2i,
		tamanho: float, giro: float, cor: Color) -> void:
	for k in 2:
		var t := Transform3D(Basis(Vector3.UP, giro + PI * 0.5 * float(k)),
			base + Vector3(0.0, tamanho * 0.5, 0.0))
		AtlasKit.folha_ao_vento(sup, M_MATO, Vector2(tamanho, tamanho), t,
			celula, cor)


## A faixa de mato que forra a beira do leito, dos dois lados.
##
## Sorteia celula, tamanho e giro por tufo. O que faz a beira nao ler como
## fileira e o desvio lateral: cada tufo entra num ponto qualquer da faixa de
## um metro e meio entre o leito e a primeira arvore, e nao numa linha.
## `desenhar` a false consome os MESMOS sorteios e nao emite geometria.
##
## E o unico jeito honesto de apagar uma familia de vegetacao para descobrir
## de quem e um defeito: pular o laco inteiro desloca o fluxo do `rng`, que
## alimenta a mata toda em ordem, e o que se compara passa a ser outra
## floresta. Ja invalidou uma investigacao inteira deste arquivo.
static func beira(sup: Dictionary, p: Vector3, lado: Vector3,
		rng: RandomNumberGenerator, quantos: int = 8,
		desenhar: bool = true, chao: Callable = Callable()) -> void:
	const CELULAS: Array[Vector2i] = [C_CAPIM, C_CAPIM, C_CAPIM_RALO,
		C_CAPIM_SECO, C_SAMAMBAIA, C_FOLHA_LARGA, C_MOITA_BAIXA, C_FLOR,
		C_GALHO_SECO, C_MOITA_BAIXA]
	for _i in quantos:
		var s := 1.0 if rng.randf() < 0.5 else -1.0
		# P0: NUNCA plantar no leito — corredor visual (ref 04).
		var d := rng.randf_range(MEIA_PISTA + 0.55, MEIA_PISTA + 4.2)
		var onde := p + lado * (d * s) + lado.cross(Vector3.UP).normalized() * rng.randf_range(-0.55, 0.55)
		var celula: Vector2i = CELULAS[rng.randi() % CELULAS.size()]
		# Menor do que era, e o motivo e o conserto logo acima: enquanto o tufo
		# nascia enterrado, de 5 a 36 cm dele ficavam debaixo do chao e a beira foi
		# calibrada com essa perda embutida. Plantado na superficie, o mesmo numero
		# poe capim de 1,35 m na frente de uma lente que esta a 1,05 m do chao.
		var tam := rng.randf_range(0.45, 1.05)
		if celula == C_FOLHA_LARGA:
			tam *= 1.35
		if celula == C_MOITA_BAIXA:
			tam *= 1.15
		# O tom claro sobe com o tamanho. Planta alta pega o sol raso que o
		# rasteiro nao pega, e essa diferenca e o que da profundidade a beira.
		var cor := Color(1.0, 1.0, 1.0).lerp(Color(0.68, 0.74, 0.58),
			rng.randf_range(0.0, 0.6))
		# O tufo pousa no CHAO da beira, e nao na linha do eixo da estrada.
		#
		# `p` e o ponto do CAMINHO, que e o eixo da pista. O terreno da beira sobe
		# a partir da borda do leito (o barranco do corte), entao um tufo plantado
		# em `p.y` nasce enterrado: 4,7 cm a 3,65 m do eixo e 35,7 cm a 7,30 m.
		# Medido, nao estimado.
		#
		# Enterrado, o capim de 55 cm some quase inteiro e o que sobra dele e a
		# ponta. E como toda a fileira esta enterrada pela mesma quantidade, as
		# pontas formam uma LINHA horizontal continua correndo a beira da estrada:
		# de longe, com o pe escondido pelo proprio barranco, ela le como uma laje
		# verde flutuando no ar. Foi assim que o defeito foi relatado, e por isso
		# ele resistiu a tres conjeturas sobre copa de arvore — o problema nunca
		# esteve nas arvores.
		if chao.is_valid():
			onde.y += float(chao.call(d))
		var giro := rng.randf_range(0.0, TAU)
		if desenhar:
			tufo(sup, onde, celula, tam, giro, cor)


# --- arvores ----------------------------------------------------------------

## Conifera de mata fechada: alta, estreita e com a saia de baixo fechada.
##
## E a silhueta que domina a print — o pinheiro escuro recortado contra o
## laranja do poente. Cinco saias, e nao quatro: a quinta e a que fecha a ponta
## e faz a arvore terminar em bico em vez de em tronco cortado.
##
## Devolve o raio da base, que quem planta usa para nao encostar duas.
static func conifera(sup: Dictionary, base: Vector3, porte: float,
		rng: RandomNumberGenerator, saia: float = 0.26) -> float:
	var altura := lerpf(9.0, 16.0, porte)
	var raio := lerpf(1.5, 2.4, porte)
	var tronco := lerpf(0.26, 0.40, porte)

	# Fuste ate um terco da altura. Acima disso a saia comeca, e o tronco so
	# reaparece em pedacos entre uma saia e outra — que e como se ve tronco numa
	# mata de verdade.
	var fuste := altura * 0.34
	KitModular.caixa_flex(sup, M_CASCA, base + Vector3(0.0, fuste * 0.5, 0.0),
		Vector3(tronco, fuste, tronco), CASCA_TOM, rng.randf_range(0.0, TAU),
		base.y, base.y + altura, 0.0, CEDE_TRONCO,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)

	var cor := VERDES[rng.randi() % VERDES.size()]
	var camadas := 5
	for i in camadas:
		var t := float(i) / float(camadas - 1)
		# Afunilamento quadratico. Linear da um cone reto, que le como arvore de
		# natal; o quadratico deixa a saia de baixo larga e as de cima juntas,
		# que e o desenho de conifera adulta.
		var largura := raio * 2.0 * (1.0 - t * t * 0.82)
		# Onde a saia de baixo comeca, em fracao da altura. `saia` e parametro e
		# nao constante porque arvore de BEIRA nao e arvore de dentro da mata.
		#
		# No meio da mata a copa so abre em cima, procurando luz, e o que sobra
		# embaixo e tronco pelado — e o corredor de troncos que a mata fechada e.
		# Na borda de uma estrada a arvore pega luz de lado a vida inteira e
		# mantem os galhos de baixo ate o chao. Com 0,26 para todas, as arvores da
		# beira ficavam com a primeira saia a 2,3 m e o capim parando em 1,35: um
		# vao de um metro em que nao havia nada, e o que se via era a saia solta no
		# ar, porque o tronco atras dela e fino e some na nevoa.
		var y := altura * lerpf(saia, 0.99, t)
		var alta := altura * 0.16
		# A saia de baixo e opaca e as de cima recortam no alfa. Assim a base
		# fecha o tronco, que e onde a mata precisa ser parede, e o topo fica
		# rendilhado contra o ceu, que e onde ela precisa ser silhueta.
		KitModular.caixa_flex(sup,
			M_FOLHA if i == 0 else M_FOLHA_RECORTE,
			base + Vector3(0.0, y, 0.0),
			Vector3(largura, alta, largura * rng.randf_range(0.86, 1.1)),
			cor.lerp(Color.WHITE, t * 0.14), rng.randf_range(0.0, 0.9),
			base.y, base.y + altura, CEDE_COPA * 0.25, CEDE_COPA * 0.7,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
	return raio


## Arvore de folha larga da mata: fuste comprido e copa alta e curta.
##
## A diferenca para a do parque esta nas proporcoes, e ela e o assunto: aqui o
## fuste come 55% da altura, porque numa mata fechada a arvore sobe procurando
## luz e so abre copa em cima. E por isso que uma mata vista de dentro e um
## corredor de troncos com um teto verde longe, e nao um mar de copas.
static func arvore(sup: Dictionary, base: Vector3, porte: float,
		rng: RandomNumberGenerator, seca: bool = false) -> float:
	var altura := lerpf(8.5, 15.0, porte)
	var raio := lerpf(1.8, 3.0, porte)
	var tronco := lerpf(0.28, 0.46, porte)
	var fuste := altura * 0.55

	var giro := rng.randf_range(0.0, TAU)
	var inclina := rng.randf_range(-0.05, 0.05)
	var desvio := Vector3(sin(giro) * inclina, 0.0, cos(giro) * inclina) * fuste
	KitModular.caixa_flex(sup, M_CASCA, base + Vector3(0.0, fuste * 0.28, 0.0),
		Vector3(tronco, fuste * 0.56, tronco), CASCA_TOM, giro,
		base.y, base.y + altura, 0.0, CEDE_TRONCO,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_flex(sup, M_CASCA,
		base + desvio * 0.5 + Vector3(0.0, fuste * 0.78, 0.0),
		Vector3(tronco * 0.8, fuste * 0.56, tronco * 0.8), CASCA_TOM, giro + 0.5,
		base.y, base.y + altura, 0.0, CEDE_TRONCO,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)

	var topo := base + desvio + Vector3(0.0, fuste, 0.0)
	var paleta := SECOS if seca else VERDES
	var cor := paleta[rng.randi() % paleta.size()]
	var vao := altura - fuste

	# Nucleo opaco no meio da copa. Sem ele os blocos de fora ficam soltos em
	# volta do nada e, contra o ceu claro do poente, a copa aparece vazada — o
	# defeito e muito mais visivel aqui do que na cidade noturna, porque atras
	# dela ha luz em vez de preto.
	KitModular.caixa_flex(sup, M_FOLHA, topo + Vector3(0.0, vao * 0.45, 0.0),
		Vector3(raio * 1.2, vao * 0.62, raio * 1.2), cor,
		rng.randf_range(0.0, TAU), base.y, base.y + altura,
		CEDE_COPA * 0.4, CEDE_COPA * 0.8, PSXMesh.FACE_TODAS, QUAD_FOLHA)

	var n := rng.randi_range(4, 6)
	for i in n:
		var t := float(i) / float(n)
		var ang := t * TAU * 1.6 + rng.randf_range(-0.3, 0.3)
		var alto := lerpf(0.12, 0.94, t) + rng.randf_range(-0.06, 0.06)
		var afunila := clampf(1.0 - absf(alto - 0.5) * 1.3, 0.3, 1.0)
		var dist := raio * afunila * rng.randf_range(0.2, 0.5)
		var lado := raio * afunila * rng.randf_range(0.8, 1.15)
		var tom := cor.lerp(Color.WHITE, rng.randf_range(-0.1, 0.18))
		tom.a = 1.0
		KitModular.caixa_flex(sup, M_FOLHA_RECORTE,
			topo + Vector3(cos(ang) * dist, vao * alto, sin(ang) * dist),
			Vector3(lado, lado * rng.randf_range(0.62, 0.9),
				lado * rng.randf_range(0.85, 1.1)),
			tom, ang, base.y, base.y + altura,
			CEDE_COPA * 0.5, CEDE_COPA, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	return raio


## Massa de mata do fundo: dois ou tres blocos grandes de folha, sem tronco.
##
## E o que fecha o corredor a partir de vinte metros. Uma mata de verdade a essa
## distancia nao mostra arvore nenhuma — mostra uma parede de folha com buracos
## de luz — e desenhar arvore inteira ali custaria seis vezes mais para produzir
## exatamente esta imagem depois que a nevoa passa por cima.
## `recortar` desliga o corte por alfa e usa a folha OPACA.
##
## O recorte existe para dar silhueta: e ele que tira a cara de caixa da moita
## que esta a cinco metros da lente. A vinte e cinco metros ele nao da mais
## silhueta nenhuma — da BURACO. Longe, um texel de tela cobre dezenas de texels
## da textura e o mipmap entrega a media deles; numa folha recortada essa media
## cai perto do limiar, e o que sobra sao lascas com furos retangulares
## penduradas no ar, sem tronco e sem pe, porque o resto da caixa foi
## descartado. Foi assim que o defeito foi relatado: "matos voando".
##
## Opaca, a mesma caixa vira uma mancha escura — que e exatamente o que o
## cabecalho de `_mata_distante` diz que ela devia ser desde sempre.
static func massa(sup: Dictionary, base: Vector3, largura: float,
		altura: float, rng: RandomNumberGenerator, recortar: bool = true) -> void:
	var cor := VERDES[rng.randi() % VERDES.size()].lerp(Color("2f3d28"), 0.35)
	cor.a = 1.0
	for i in rng.randi_range(2, 3):
		var desvio := Vector3(rng.randf_range(-largura * 0.3, largura * 0.3),
			0.0, rng.randf_range(-1.5, 1.5))
		var h := altura * rng.randf_range(0.7, 1.05)
		KitModular.caixa_flex(sup,
			M_FOLHA_RECORTE if recortar else M_FOLHA,
			base + desvio + Vector3(0.0, h * 0.5, 0.0),
			Vector3(largura * rng.randf_range(0.8, 1.2), h,
				largura * rng.randf_range(0.5, 0.9)),
			cor.lerp(Color.WHITE, float(i) * 0.05), rng.randf_range(0.0, TAU),
			base.y, base.y + h, CEDE_COPA * 0.2, CEDE_COPA * 0.55,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)


# --- mobilia de beira de estrada --------------------------------------------

## Tronco caido, meio enterrado no mato. Um a cada tantos trechos.
##
## Existe pelo mesmo motivo que a copa seca: quebra a repeticao. Uma mata em que
## nada caiu nunca le como mata velha.
static func tronco_caido(sup: Dictionary, base: Vector3, comprimento: float,
		giro: float, rng: RandomNumberGenerator) -> void:
	var b := Basis(Vector3.UP, giro) * Basis(Vector3.FORWARD, PI * 0.5)
	KitModular.caixa_flex_inclinada(sup, M_CASCA,
		base + Vector3(0.0, 0.22, 0.0),
		Vector3(0.44, comprimento, 0.44), CASCA_TOM.lerp(Color("564a3c"), 0.4),
		b, base.y, base.y + 0.5, 0.0, 0.0, QUAD_FOLHA)
	# O mato que cresceu por cima. E o que enterra o tronco no chao em vez de
	# deixar ele pousado como um lapis em cima da mesa.
	for _i in rng.randi_range(2, 4):
		var t := rng.randf_range(-0.4, 0.4) * comprimento
		var onde := base + Vector3(sin(giro) * t, 0.0, cos(giro) * t)
		tufo(sup, onde, C_MOITA_BAIXA, rng.randf_range(0.5, 0.8),
			rng.randf_range(0.0, TAU), Color(0.9, 0.92, 0.86))


## Marco de quilometro: o pilarzinho branco de concreto da beira.
##
## E o unico objeto de mao humana que a estrada tem, e por isso ele importa
## mais do que o tamanho sugere: sem nada construido, a mata poderia ser
## qualquer mata. Com ele, aquilo e uma estrada que alguem mediu.
static func marco(sup: Dictionary, base: Vector3, giro: float) -> void:
	KitModular.caixa_cor(sup, M_TABUA, base + Vector3(0.0, 0.34, 0.0),
		Vector3(0.24, 0.68, 0.16), Color(0.86, 0.84, 0.78), giro,
		PSXMesh.FACE_TODAS, 4.0)
	KitModular.caixa_cor(sup, M_TABUA, base + Vector3(0.0, 0.62, 0.0),
		Vector3(0.25, 0.14, 0.17), Color(0.34, 0.31, 0.28), giro,
		PSXMesh.FACE_TODAS, 4.0)


## Cerca de arame farpado de divisa de pasto, do jeito de interior de Minas.
##
## O que ela NAO e
## ---------------
## Ela ja foi mourao de 22 cm com tres travessas de madeira clara correndo
## retas de ponta a ponta. Isso nao e cerca de divisa, e cercado de curral — e
## no plano de dentro do carro as travessas viravam uma barra creme atravessada
## na altura dos olhos, tapando a estrada. Na print de referencia o que existe
## e o oposto: pau fino, torto, e fio quase invisivel entre um e outro.
##
## Vao irregular
## -------------
## Vao fixo le como grade comprada por metro. Uma cerca de divisa e feita com o
## pau que tinha e enfiada onde o chao deixou, entao o vao anda entre 1,8 e 2,7
## e o mourao sai um palmo da linha. E a irregularidade que faz ela ler como
## rural em vez de industrial.
##
## Os fios tem barriga
## -------------------
## Arame esticado por gente afrouxa. Sem barriga, tres retas paralelas leem como
## trilho; com ela, o vao inteiro ganha a curva que o olho reconhece de longe.
## Dois segmentos por vao ja dao a curva na resolucao em que isto aparece — a
## mesma conta da `fiacao`, que resolve o mesmo problema com quatro.
##
## A altura do fio nao acompanha o mourao
## --------------------------------------
## O fio corre em altura quase constante e o mourao e que varia acima dele, que
## e o que acontece de verdade: quem esticou o arame mirou a mesma altura em
## todos. Amarrar o fio ao topo faria a cerca subir e descer junto com o pau e
## ela leria como serra de montanha deitada.
static func cerca(sup: Dictionary, a: Vector3, b: Vector3,
		rng: RandomNumberGenerator) -> void:
	var delta := b - a
	var comp := delta.length()
	if comp < 1.0:
		return
	var dir := delta / comp
	var giro := atan2(dir.x, dir.z)
	# Perpendicular no plano: joga o mourao para fora da linha reta.
	var fora := dir.cross(Vector3.UP).normalized()

	var bases: Array[Vector3] = []
	var alturas: Array[float] = []
	var s := 0.0
	while s < comp - 0.3:
		var p := a + dir * s + fora * rng.randf_range(-0.08, 0.08)
		var alt := rng.randf_range(1.02, 1.48)
		# Doze a vinte centimetros, e nao nove a catorze. Nao e capricho de
		# proporcao: a 480x270 um pau de 10 cm a vinte metros ocupa menos de um
		# pixel de largura, e o que nao cobre um pixel inteiro sai como ruido do
		# dither em vez de sair como pau. A cerca existia na cena e mesmo assim
		# nao aparecia na tela.
		var esp := rng.randf_range(0.12, 0.20)
		# Madeira lavada de tempo: a print mede 1:0.96:0.76 no facho, que e
		# cinza morno — e nao o creme alaranjado que estava aqui.
		KitModular.caixa_cor(sup, M_TABUA, p + Vector3(0.0, alt * 0.5, 0.0),
			Vector3(esp, alt, esp),
			COR_MOURAO.lerp(COR_MOURAO_VELHO, rng.randf()),
			giro + rng.randf_range(-0.18, 0.18), PSXMesh.FACE_TODAS, 0.30)
		# Subdividido a cada 30 cm, e nao a cada 4 m.
		#
		# Com `vertex_lighting` a luz e resolvida SO nos vertices. Um mourao de
		# 1,2 m com subdivisao de 4 m tem vertice apenas nos oito cantos, todos
		# eles fora do cone do farol — entao o facho podia atravessar o pau
		# inteiro no meio e ele continuava preto. A cerca aparecia na geometria e
		# nao aparecia na imagem. Quatro vertices ao longo da altura bastam para
		# o cone acender a parte dele que a luz de fato pega.
		bases.append(p)
		alturas.append(alt)
		s += rng.randf_range(1.8, 2.7)

	for i in maxi(0, bases.size() - 1):
		var p0: Vector3 = bases[i]
		var p1: Vector3 = bases[i + 1]
		var teto: float = minf(alturas[i], alturas[i + 1]) - 0.10
		for y: float in FIOS_CERCA:
			if y > teto:
				continue
			var de := p0 + Vector3(0.0, y, 0.0)
			var para := p1 + Vector3(0.0, y, 0.0)
			var meio := de.lerp(para, 0.5) - Vector3(0.0, BARRIGA_FIO, 0.0)
			_arame(sup, de, meio)
			_arame(sup, meio, para)



## Um lance de arame entre dois pontos.
##
## Existe em vez de `KitModular.cabo` porque aquele e cabo de POSTE: seis
## centimetros de `metal`, que e o certo para fiacao vista contra o ceu e errado
## aqui. Arame farpado tem dois milimetros e e escuro de ferrugem; com a secao e
## o material do cabo, o fio ficava mais grosso e mais claro que o mourao e a
## cerca lia como tres trilhos brancos deitados. Fino e escuro ele faz o que faz
## na print: some quase todo e so aparece o brilho onde o facho pega de raspao.
static func _arame(sup: Dictionary, de: Vector3, para: Vector3) -> void:
	var vetor := para - de
	var comp := vetor.length()
	if comp < 0.05:
		return
	var dir := vetor / comp
	KitModular.caixa_cor(sup, M_TABUA, de + vetor * 0.5,
		Vector3(0.022, 0.022, comp), Color("3b3630"),
		atan2(dir.x, dir.z), PSXMesh.FACE_TODAS, 2.0)


## Cipó / galho pendurado sobre a pista — fecha o corredor por cima.
##
## Dois planos cruzados pendurados de um ponto alto; o pe fica na beira e a
## ponta cai sobre o leito. Sem isto a mata e so parede lateral e o quadro
## perde o "teto" que a ref 04 mostra.
static func cipo(sup: Dictionary, ancora: Vector3, sobre_pista: Vector3,
		rng: RandomNumberGenerator) -> void:
	var meio := ancora.lerp(sobre_pista, 0.55) + Vector3(0.0, rng.randf_range(-0.15, 0.45), 0.0)
	var comp := ancora.distance_to(sobre_pista)
	var dir := (sobre_pista - ancora).normalized()
	var giro := atan2(dir.x, dir.z)
	var cor := Color(0.22, 0.32, 0.16).lerp(Color(0.40, 0.48, 0.26), rng.randf())
	# Cordao fino — NAO massa preta no para-brisa (P0 corredor).
	KitModular.caixa_cor(sup, M_CASCA, meio,
		Vector3(0.055, 0.055, comp * 0.95), Color("2a2218"), giro,
		PSXMesh.FACE_TODAS, 6.0)
	# Fios/cipos como FIOS distintos (GALHO_SECO), nao blobs de moita.
	for k in rng.randi_range(5, 8):
		var t := rng.randf_range(0.08, 0.95)
		var p := ancora.lerp(sobre_pista, t)
		var queda := rng.randf_range(1.6, 2.8)
		KitModular.caixa_cor(sup, M_CASCA,
			p - Vector3(0.0, queda * 0.5, 0.0),
			Vector3(0.035, queda, 0.035), Color("2e281c"),
			rng.randf_range(-0.2, 0.2), PSXMesh.FACE_TODAS, 5.0)
		tufo(sup, p - Vector3(0.0, queda * 0.75, 0.0),
			C_GALHO_SECO if rng.randf() < 0.65 else C_CAPIM_SECO,
			queda * 0.35, rng.randf_range(0.0, TAU), cor)
		if rng.randf() < 0.35:
			tufo(sup, p - Vector3(rng.randf_range(-0.2, 0.2), queda * 0.55, rng.randf_range(-0.15, 0.15)),
				C_SAMAMBAIA, queda * 0.28, rng.randf_range(0.0, TAU),
				cor.lerp(Color(0.35, 0.42, 0.22), 0.3))


## Casinha / oratório de beira — sujeito do facho (ref 04).
##
## `tipo` 0 e o oratorio claro da ref 04 e fica travado na ancora de captura.
## Os outros sao casa de alvenaria, varanda e casinha azul — a estrada nao pode
## repetir o mesmo volume branco a cada trecho. -1 sorteia, nunca 0 (0 e so a
## ancora).
static func casa_beira(sup: Dictionary, base: Vector3, giro: float,
		rng: RandomNumberGenerator, tipo: int = -1) -> void:
	if tipo < 0:
		tipo = 1 + rng.randi_range(0, 2)
	if tipo == 1:
		_casa_alvenaria(sup, base, giro, rng)
		return
	if tipo == 2:
		_casa_varanda(sup, base, giro, rng)
		return
	if tipo == 3:
		_casa_azul(sup, base, giro, rng)
		return
	var larg := rng.randf_range(3.6, 4.4)
	var fund := rng.randf_range(2.6, 3.2)
	var alt := rng.randf_range(2.35, 2.85)
	# Madeira gasta CLARA — precisa pegar o facho (ref 04 casinha).
	var parede := Color(1.0, 0.96, 0.88).lerp(Color(0.90, 0.84, 0.72), rng.randf() * 0.25)
	var telha := Color(0.62, 0.32, 0.18).lerp(Color(0.42, 0.22, 0.12), rng.randf())
	var pedra := Color(0.55, 0.50, 0.42).lerp(Color(0.40, 0.44, 0.34), 0.3)
	# Base de alvenaria / pedra (ref 04) — eleva e ancora a casinha.
	var h_base := 0.58
	KitModular.caixa_cor(sup, M_TABUA, base + Vector3(0.0, h_base * 0.5, 0.0),
		Vector3(larg + 0.45, h_base, fund + 0.4), pedra, giro,
		PSXMesh.FACE_TODAS, 3.0)
	var corpo_y := h_base
	# Corpo de madeira sobre a base.
	KitModular.caixa_cor(sup, M_TABUA, base + Vector3(0.0, corpo_y + alt * 0.5, 0.0),
		Vector3(larg, alt, fund), parede, giro, PSXMesh.FACE_TODAS, 3.0)
	# Tabuas horizontais — leitura de madeira gasta no facho.
	for yi in 4:
		var yy := corpo_y + 0.35 + float(yi) * (alt * 0.22)
		KitModular.caixa_cor(sup, M_TABUA, base + Vector3(0.0, yy, fund * 0.5 + 0.02),
			Vector3(larg * 0.96, 0.06, 0.05),
			parede.lerp(Color(0.55, 0.42, 0.28), 0.35 + float(yi) * 0.08), giro,
			PSXMesh.FACE_TODAS, 5.0)
	# Telhado gable alto — silhueta de oratorio (ref 04).
	var h_telha := 0.85
	KitModular.caixa_cor(sup, M_TABUA, base + Vector3(0.0, corpo_y + alt + h_telha * 0.45, 0.0),
		Vector3(larg + 0.55, h_telha, fund + 0.35), telha, giro,
		PSXMesh.FACE_TODAS, 3.0)
	KitModular.caixa_cor(sup, M_TABUA, base + Vector3(0.0, corpo_y + alt + h_telha + 0.12, 0.0),
		Vector3(larg * 0.18, 0.22, fund + 0.2), Color(0.28, 0.18, 0.12), giro,
		PSXMesh.FACE_TODAS, 4.0)
	# Porta escura + janela — legibilidade no facho.
	var frente := Basis(Vector3.UP, giro) * Vector3(0.0, 0.0, fund * 0.5 + 0.03)
	KitModular.caixa_cor(sup, M_TABUA, base + frente + Vector3(0.0, corpo_y + 0.65, 0.0),
		Vector3(0.62, 1.2, 0.07), Color(0.22, 0.16, 0.12), giro,
		PSXMesh.FACE_TODAS, 4.0)
	KitModular.caixa_cor(sup, M_TABUA, base + frente + Vector3(larg * 0.3, corpo_y + 1.25, 0.0),
		Vector3(0.5, 0.45, 0.06), Color(0.12, 0.16, 0.22), giro,
		PSXMesh.FACE_TODAS, 4.0)
	_pe_casa(sup, base, giro, rng)


## Casa de alvenaria pastel, telha, duas janelas. O sobrado pobre da beira.
static func _casa_alvenaria(sup: Dictionary, base: Vector3, giro: float,
		rng: RandomNumberGenerator) -> void:
	var larg := rng.randf_range(4.2, 5.2)
	var fund := rng.randf_range(3.0, 3.6)
	var alt := rng.randf_range(2.5, 2.9)
	var paleta: Array[Color] = [
		Color("e2c56a"), Color("d9a090"), Color("c5d4b8"), Color("e8d8b0"),
	]
	var parede: Color = paleta[rng.randi_range(0, paleta.size() - 1)]
	var telha := Color("8a3c28").lerp(Color("6a2e1c"), rng.randf())
	var b := Basis(Vector3.UP, giro)
	var frente := b * Vector3(0.0, 0.0, fund * 0.5 + 0.03)
	KitModular.caixa_cor(sup, M_TABUA, base + Vector3(0.0, 0.22, 0.0),
		Vector3(larg + 0.2, 0.44, fund + 0.2), Color("8a8174"), giro,
		PSXMesh.FACE_TODAS, 3.0)
	KitModular.caixa_cor(sup, M_TABUA, base + Vector3(0.0, 0.44 + alt * 0.5, 0.0),
		Vector3(larg, alt, fund), parede, giro, PSXMesh.FACE_TODAS, 3.0)
	KitModular.caixa_cor(sup, M_TABUA,
		base + Vector3(0.0, 0.44 + alt + 0.38, 0.0),
		Vector3(larg + 0.5, 0.72, fund + 0.4), telha, giro,
		PSXMesh.FACE_TODAS, 3.0)
	KitModular.caixa_cor(sup, M_TABUA, base + frente + Vector3(0.0, 1.05, 0.0),
		Vector3(0.7, 1.5, 0.08), Color("5a4030"), giro, PSXMesh.FACE_TODAS, 4.0)
	for lado: float in [-0.32, 0.32]:
		KitModular.caixa_cor(sup, M_TABUA,
			base + frente + b * Vector3(larg * lado, 1.55, 0.0),
			Vector3(0.55, 0.55, 0.07), Color("1a2830"), giro,
			PSXMesh.FACE_TODAS, 4.0)
	_pe_casa(sup, base, giro, rng)


## Casa com varanda rasa. A sombra do beiral e o que a distingue da caixa.
static func _casa_varanda(sup: Dictionary, base: Vector3, giro: float,
		rng: RandomNumberGenerator) -> void:
	var larg := rng.randf_range(3.8, 4.6)
	var fund := rng.randf_range(2.8, 3.3)
	var alt := 2.45
	var parede := Color("efe6d2").lerp(Color("d8cbb0"), rng.randf())
	var telha := Color("6e3a22")
	var b := Basis(Vector3.UP, giro)
	var frente := b * Vector3(0.0, 0.0, fund * 0.5)
	KitModular.caixa_cor(sup, M_TABUA, base + Vector3(0.0, alt * 0.5, 0.0),
		Vector3(larg, alt, fund), parede, giro, PSXMesh.FACE_TODAS, 3.0)
	# Beiral avancando: a varanda.
	KitModular.caixa_cor(sup, M_TABUA,
		base + frente + b * Vector3(0.0, alt + 0.28, 0.55),
		Vector3(larg + 0.4, 0.14, 1.3), telha, giro, PSXMesh.FACE_TODAS, 3.0)
	KitModular.caixa_cor(sup, M_TABUA,
		base + Vector3(0.0, alt + 0.55, 0.0),
		Vector3(larg + 0.35, 0.55, fund + 0.25), telha, giro,
		PSXMesh.FACE_TODAS, 3.0)
	for lado: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, M_TABUA,
			base + frente + b * Vector3(lado * larg * 0.42, 1.15, 0.55),
			Vector3(0.12, 2.3, 0.12), Color("6a5844"), giro,
			PSXMesh.FACE_TODAS, 4.0)
	KitModular.caixa_cor(sup, M_TABUA, base + frente + Vector3(0.0, 1.0, 0.04),
		Vector3(0.62, 1.35, 0.07), Color("3a2a20"), giro, PSXMesh.FACE_TODAS, 4.0)
	KitModular.caixa_cor(sup, M_TABUA,
		base + frente + b * Vector3(larg * 0.28, 1.55, 0.04),
		Vector3(0.5, 0.5, 0.06), Color("152028"), giro, PSXMesh.FACE_TODAS, 4.0)
	_pe_casa(sup, base, giro, rng)


## Casinha azul de cal. Janela unica, telha vermelha — o marco da curva.
static func _casa_azul(sup: Dictionary, base: Vector3, giro: float,
		rng: RandomNumberGenerator) -> void:
	var larg := rng.randf_range(3.4, 4.0)
	var fund := rng.randf_range(2.5, 3.0)
	var alt := 2.55
	var parede := Color("7aa0b8").lerp(Color("5e849c"), rng.randf())
	var telha := Color("a0442c")
	var b := Basis(Vector3.UP, giro)
	var frente := b * Vector3(0.0, 0.0, fund * 0.5 + 0.03)
	KitModular.caixa_cor(sup, M_TABUA, base + Vector3(0.0, alt * 0.5, 0.0),
		Vector3(larg, alt, fund), parede, giro, PSXMesh.FACE_TODAS, 3.0)
	KitModular.caixa_cor(sup, M_TABUA, base + Vector3(0.0, alt + 0.4, 0.0),
		Vector3(larg + 0.45, 0.7, fund + 0.35), telha, giro,
		PSXMesh.FACE_TODAS, 3.0)
	KitModular.caixa_cor(sup, M_TABUA, base + frente + Vector3(-larg * 0.18, 1.0, 0.0),
		Vector3(0.58, 1.4, 0.07), Color("3e2c20"), giro, PSXMesh.FACE_TODAS, 4.0)
	KitModular.caixa_cor(sup, M_TABUA, base + frente + Vector3(larg * 0.22, 1.5, 0.0),
		Vector3(0.7, 0.7, 0.07), Color("f2e6a0"), giro, PSXMesh.FACE_TODAS, 4.0)
	_pe_casa(sup, base, giro, rng)


static func _pe_casa(sup: Dictionary, base: Vector3, giro: float,
		rng: RandomNumberGenerator) -> void:
	for _i in rng.randi_range(3, 5):
		var ang := rng.randf_range(-1.2, 1.2) + (PI if rng.randf() < 0.35 else 0.0)
		var d := rng.randf_range(1.35, 2.4)
		var off := Basis(Vector3.UP, giro) * Vector3(sin(ang) * d, 0.0, cos(ang) * d)
		tufo(sup, base + off,
			C_MOITA_BAIXA if rng.randf() < 0.6 else C_SAMAMBAIA,
			rng.randf_range(0.75, 1.25), ang,
			Color(0.72, 0.80, 0.60))


## Muro baixo de pedra / tijolo musgoso na beira (ref 04, lado esquerdo).
static func muro_baixo(sup: Dictionary, a: Vector3, b: Vector3,
		rng: RandomNumberGenerator) -> void:
	var delta := b - a
	var comp := delta.length()
	if comp < 0.8:
		return
	var dir := delta / comp
	var giro := atan2(dir.x, dir.z)
	var n := maxi(1, int(comp / 1.4))
	for i in n:
		var p := a + dir * (comp * (float(i) + 0.5) / float(n))
		var h := rng.randf_range(0.45, 0.75)
		var w := comp / float(n) * 0.92
		KitModular.caixa_cor(sup, M_TABUA, p + Vector3(0.0, h * 0.5, 0.0),
			Vector3(0.28, h, w), Color(0.42, 0.40, 0.34).lerp(Color(0.3, 0.38, 0.26), 0.35),
			giro, PSXMesh.FACE_TODAS, 3.5)
