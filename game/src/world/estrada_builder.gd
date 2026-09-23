## A estrada de terra e a mata dos dois lados, montadas em trechos conforme o
## carro anda.
##
## Uma esteira, e nao um mapa
## --------------------------
## A cena dura pouco mais de um minuto a 65 km/h, o que da uns mil e duzentos
## metros de estrada. Montar isso de uma vez seriam oitenta mil triangulos para
## mostrar sessenta metros por vez, que e o que a nevoa deixa ver. Entao a
## estrada e uma esteira: existem cinco trechos de 28,8 m por vez — um atras e
## tres a frente — e cada vez que o carro entra num trecho novo, o de tras morre
## e outro nasce la na frente.
##
## O caminho e uma FUNCAO, e nao uma lista
## ---------------------------------------
## A linha do meio da estrada e uma soma de senos de `s`, a distancia percorrida.
## Isso da tres coisas de graca: a tangente sai da derivada (nao ha diferenca
## finita entre pontos, que e o que faz a camera tremer em curva), qualquer
## trecho pode ser montado em qualquer ordem sem depender do anterior, e o
## minimapa consegue desenhar cem metros a frente sem que nada esteja montado.
##
## `s` cresce para -Z. E a convencao do resto do jogo: a rua principal da cidade
## corre em -Z e e para la que o jogador nasce olhando.
##
## Sem colisao, sem chunk, sem streaming
## -------------------------------------
## Nao passa pelo ChunkManager de proposito. O ChunkManager e sobre uma cidade
## em grade de 32 m que se percorre em qualquer direcao; isto e um corredor de
## sentido unico que existe por oitenta segundos e some. Emprestar a maquinaria
## de streaming aqui custaria mais linhas do que a esteira inteira.
class_name EstradaBuilder
extends Node3D

const MAT_DIR := "res://resources/materials/mat_%s.tres"

const PASSO := KitEstrada.PASSO
## Passos por trecho. Dezesseis dao 28,8 m, que e perto do chunk de 32 m do
## resto do jogo — nao por acaso: e a escala em que um pedaco de mundo custa uns
## dois mil triangulos, e essa e a conta que ja esta calibrada.
const PASSOS_POR_TRECHO := 16
const TRECHO := PASSO * float(PASSOS_POR_TRECHO)

## Quantos trechos ficam de pe atras e a frente do carro.
##
## Nove a frente sao 259 m. Tres eram 86 m, o que bastava para a cabine — a
## nevoa fecha antes — mas nao para o plano de cima: dali se ve o vale inteiro,
## e a mata acabava numa borda reta no meio do quadro com nevoa depois. O que a
## print aerea mostra e floresta de ponta a ponta da tela, sem fim visivel.
##
## O custo disto e menor do que parece porque o que enche a distancia e a faixa
## barata de `_mata_distante` — massa de folha, sem tronco e sem galho. Detalhe
## fino continua so perto da pista, que e onde alguem chega perto o bastante
## para ver.
const ATRAS := 2
const ADIANTE := 9

# --- forma do caminho -------------------------------------------------------
# Tres senos em comprimentos de onda sem razao inteira entre si. Com dois, a
# estrada repete o mesmo S a cada volta do maior; com razao inteira, repete
# ainda mais cedo. Aqui o padrao so voltaria a se repetir depois de vinte
# quilometros, e a cena tem um.

const CURVA := [
	{"amp": 14.0, "onda": 95.0, "fase": 0.0},
	{"amp": 5.0, "onda": 38.0, "fase": 1.7},
	{"amp": 2.2, "onda": 17.0, "fase": 0.4},
]
## As lombadas. Amplitude pequena de proposito: a estrada tem de subir e descer
## o bastante para o fundo do quadro mudar de altura — que e o que faz a curva
## parecer ter relevo — e pouco o bastante para o capo nunca tapar a estrada.
const RELEVO := [
	{"amp": 1.7, "onda": 120.0, "fase": 0.9},
	{"amp": 0.9, "onda": 47.0, "fase": 2.3},
]

# --- corte da estrada na mata -----------------------------------------------

## Ate onde a mata e desenhada, medido do eixo.
##
## Eram 32 m, escolhidos para a nevoa da cabine, que fecha em 54. Da camera de
## cima 32 m e uma tira estreita de mata com vazio dos dois lados.
##
## O numero e escolhido contra o `fog_end` do plano aereo, que e 175: a borda da
## mata cai ALEM do ponto em que a nevoa ja fechou, entao ela nao termina — se
## dissolve. Com 95 a borda ficava DENTRO da nevoa e aparecia como um serrilhado
## de copas com cinza chapado em cima, que e o "fim de mundo" classico. A regra
## e essa, e nao o numero: a mata tem de acabar depois da nevoa, sempre.
const ALCANCE_MATA := 210.0
## Ate onde vai a mata DETALHADA, com tronco, galho e arbusto. Alem disso entra
## so massa de folha: a 30 m, na resolucao desta tela, tronco e galho ja nao se
## distinguem de mancha escura, e cobram caro para isso.
const ALCANCE_DETALHE := 30.0
## Onde as arvores comecam. Menos que isto e galho dentro da pista.
const RECUO_ARVORE := 6.2

## O CORREDOR: nenhuma copa pode chegar mais perto do eixo do que isto.
##
## `RECUO_ARVORE` diz onde o TRONCO pode nascer, e tronco nao e o que ocupa
## espaco: a saia de uma conifera adulta abre ate 2,2 m em volta dele. Com o
## tronco em 6,2 a folhagem chega a 4,0 m do eixo — dentro de onde toda camera
## rente ao chao desta cena e plantada.
##
## E o defeito nao aparece como "arvore perto demais": aparece como LAJES
## VERDES FLUTUANDO. A camera fica embaixo da saia, que e uma caixa achatada de
## um metro e meio de espessura; o que se ve dela por baixo e a face de baixo,
## um retangulo escuro e horizontal, sem tronco atras (o tronco esta ACIMA da
## linha do olho) e sem pe nenhum. Foi assim que o defeito foi relatado: "uns
## matos voando no inicio da cena".
##
## O conserto e alargar a viela, e nao desviar dela: as duas cameras baixas
## desta cena ficam em 5,0 m, e nada de folha desce abaixo de 5,4.
const CORREDOR_LIVRE := 5.4

## Colunas do chao da mata, em metros a partir da borda do leito.
##
## Cinco colunas, e nao um plano so. A UV afim empena dentro de cada quad em
## proporcao ao tamanho dele (ART-BIBLE secao 4), e um plano de 29 m de largura
## visto rasante — que e exatamente como se ve o chao de uma mata — sai com a
## textura escorrendo. As colunas ficam mais largas conforme se afastam porque
## a distorcao que importa e a do que esta perto.
## A primeira coluna encosta no leito EXATAMENTE, sem sobrepor.
##
## Sobrepor foi tentado e saiu pior: com a coluna comecando 30 cm dentro do
## leito e a borda dela erguida para casar a altura, os 30 cm de sobreposicao
## ficavam um fio ACIMA da pista e apareciam como uma listra clara na beira —
## trocar buraco por saliencia nao resolve, so muda o defeito de sinal.
##
## O que fecha a juncao e a combinacao de duas coisas: a borda de dentro da
## coluna nascer na mesma altura da borda do leito (`junta`, logo abaixo) e o
## leito ter parede lateral (`KitEstrada.saia`). Com as duas, encostar basta.
const COLUNAS_CHAO := [KitEstrada.MEIA_PISTA, 5.5, 8.5, 12.5, 18.0, 26.0, 38.0, 56.0, 85.0, 130.0, ALCANCE_MATA]

## Quanto o terreno sobe por metro afastado do leito. E o barranco do corte: uma
## estrada de terra na mata quase nunca esta no nivel dela, e sim uns palmos
## abaixo. Sem isso a mata parece flutuar ao lado da pista.
const BARRANCO := 0.085
## Teto do barranco. Sem ele a mata a trinta metros estaria tres metros acima da
## pista e o corredor viraria um desfiladeiro.
const BARRANCO_MAX := 1.35

var semente: int = 20260908
## Clima ativo da cena (noite/amanhecer/dia/entardecer).
var clima_id: String = "entardecer"

var _trechos: Dictionary[int, Node3D] = {}
var _materiais: Dictionary[StringName, ShaderMaterial] = {}
## Ultimo indice de trecho em que o carro estava. -9999 forca a primeira carga.
var _indice: int = -9999
## Ultimo indice de trecho debaixo da camera ativa. Ver `atualizar`.
var _indice_camera: int = -9999

## Quantos trechos a esteira pode manter de pe quando carro e camera se afastam.
##
## A esteira segura a UNIAO da janela do carro com a da camera, contigua — o
## chao entre os dois tambem tem de existir, porque e ali que o olho esta
## apontado. Sem teto, o plano da saida (o carro sumindo ao longe) iria montando
## trecho atras de trecho pelo minuto inteiro. Vinte e quatro trechos sao 691 m:
## o dobro do que a nevoa mais aberta da cena deixa ver.
const TRECHOS_MAX := 24

## Quantos triangulos existem de pe agora. So diagnostico.
var triangulos: int = 0


# --- caminho ----------------------------------------------------------------

## Onde a linha do meio da estrada esta, a `s` metros do comeco.
static func ponto_em(s: float) -> Vector3:
	var x := 0.0
	for c: Dictionary in CURVA:
		x += float(c["amp"]) * sin(s / float(c["onda"]) + float(c["fase"]))
	var y := 0.0
	for r: Dictionary in RELEVO:
		y += float(r["amp"]) * sin(s / float(r["onda"]) + float(r["fase"]))
	return Vector3(x, y, -s)


## Para onde a estrada aponta em `s`. Sai da derivada da propria funcao do
## caminho, e nao da diferenca entre dois pontos: com diferenca finita, o passo
## de amostragem entra na conta e a camera de dentro do carro treme junto com
## ele em toda curva.
static func direcao_em(s: float) -> Vector3:
	var dx := 0.0
	for c: Dictionary in CURVA:
		var onda := float(c["onda"])
		dx += float(c["amp"]) / onda * cos(s / onda + float(c["fase"]))
	var dy := 0.0
	for r: Dictionary in RELEVO:
		var onda := float(r["onda"])
		dy += float(r["amp"]) / onda * cos(s / onda + float(r["fase"]))
	return Vector3(dx, dy, -1.0).normalized()


## O vetor unitario que aponta para a DIREITA de quem dirige, no plano.
##
## No plano, e nao no espaco: se o lado acompanhasse a subida da lombada, a
## secao transversal da estrada sairia inclinada e o leito viraria uma rampa
## lateral em toda ladeira.
static func lado_em(s: float) -> Vector3:
	var d := direcao_em(s)
	var plano := Vector3(d.x, 0.0, d.z)
	if plano.length_squared() < 0.000001:
		return Vector3.RIGHT
	return plano.normalized().cross(Vector3.UP).normalized()


## Uma amostra do caminho, para quem precisa da linha inteira — o minimapa.
static func caminho(de: float, ate: float, passo: float) -> PackedVector3Array:
	var saida := PackedVector3Array()
	var s := de
	while s <= ate:
		saida.append(ponto_em(s))
		s += passo
	return saida


# --- esteira ----------------------------------------------------------------

## Poe de pe os trechos em volta de `s` e derruba os que ficaram para tras.
##
## Chamada todo quadro pelo carro. Sai barata quando nao ha o que fazer: o unico
## trabalho no caso comum e uma divisao e uma comparacao de inteiro.
##
## A janela segue o carro E a camera
## ---------------------------------
## Ela seguia so o carro, e isso sumia com o mundo nos planos de camera parada.
## Relatado pelo jogador como "quando o carro vai andando para longe, o mapa vai
## desaparecendo conforme a distancia do carro" — e era exatamente isso: na SAIDA
## (o carro indo embora), na PASSAGEM e na POCA a lente fica plantada na beira
## da pista, e todo trecho mais de `ATRAS` atras do CARRO era derrubado, inclusive
## o chao debaixo da camera. Cinquenta e oito metros depois de o carro passar,
## a estrada e a mata em volta da lente deixavam de existir.
##
## Agora a esteira mantem de pe o intervalo CONTIGUO que cobre as duas janelas:
## a do carro e a da camera ativa, e o chao entre elas, que e para onde a lente
## esta olhando. A camera e lida do proprio viewport, entao nenhum plano precisa
## lembrar de avisar — o plano que for escrito amanha ja nasce coberto.
func atualizar(s: float) -> void:
	var i := floori(s / TRECHO)
	var j := _trecho_da_camera(i)
	if i == _indice and j == _indice_camera:
		return
	_indice = i
	_indice_camera = j
	var de := mini(i, j) - ATRAS
	var ate := maxi(i, j) + ADIANTE
	# Carro longe demais da lente: a janela da camera manda, e o carro — que a
	# essa distancia ja esta dentro da nevoa — perde o excesso da frente.
	if ate - de + 1 > TRECHOS_MAX:
		de = j - ATRAS
		ate = de + TRECHOS_MAX - 1
	for k in range(de, ate + 1):
		if not _trechos.has(k):
			_trechos[k] = _montar_trecho(k)
	for k: int in _trechos.keys():
		if k < de or k > ate:
			var no := _trechos[k]
			_trechos.erase(k)
			if is_instance_valid(no):
				triangulos -= int(no.get_meta(&"triangulos", 0))
				no.queue_free()


## Em que trecho a camera ativa esta, medido ao longo da estrada.
##
## `ponto_em` devolve `z = -s` exato, entao o `s` da lente e so o `-z` dela no
## espaco desta esteira — a curva lateral nao entra na conta. Sem camera (a
## validacao headless) devolve o trecho do carro, e a janela volta a ser so a
## dele.
func _trecho_da_camera(padrao: int) -> int:
	if not is_inside_tree():
		return padrao
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return padrao
	return floori(-to_local(cam.global_position).z / TRECHO)


## Monta tudo de uma vez, do trecho 0 ate `ate` metros. Serve a inspecao, que
## precisa da estrada inteira parada para fotografar de cima.
func montar_tudo(ate: float) -> void:
	for k in range(0, ceili(ate / TRECHO) + 1):
		if not _trechos.has(k):
			_trechos[k] = _montar_trecho(k)


func _montar_trecho(indice: int) -> Node3D:
	var rng := RandomNumberGenerator.new()
	# A semente sai do indice, e nao de um contador. E o que faz o trecho 7 ser
	# sempre o mesmo trecho 7, montado na ida, na volta ou numa captura solta —
	# sem isso a mesma cena sairia diferente em duas gravacoes e nao daria para
	# comparar captura com captura.
	rng.seed = absi(semente * 2654435761 + indice * 83492791)

	var sup: Dictionary = {}
	var s0 := float(indice) * TRECHO
	_leito_e_chao(sup, s0, rng)
	if not _sem("mata"):
		_mata(sup, s0, rng)
	if not _sem("detalhes"):
		_detalhes(sup, s0, rng)

	var no := Node3D.new()
	no.name = "trecho_%03d" % indice
	var tris := 0
	for material: StringName in sup:
		var d: Dictionary = sup[material]
		if PSXMesh.dados_vazio(d):
			continue
		var mi := MeshInstance3D.new()
		mi.name = String(material)
		mi.mesh = PSXMesh.dados_para_mesh(d)
		mi.material_override = _material(material)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		no.add_child(mi)
		tris += PSXMesh.dados_triangulos(d)
	no.set_meta(&"triangulos", tris)
	triangulos += tris
	add_child(no)
	return no


## Cor chapada por material, para achar superficie sumida. `--mat-debug`.
##
## Fica no codigo, e nao num patch temporario, porque esta cena ja perdeu o
## chao inteiro uma vez (face virada), perdeu a beira da pista outra (degrau
## entre leito e barranco) e teve a cupula do ceu tapando os dois buracos com
## uma laje da cor da nevoa. Nos tres casos o sintoma foi o mesmo — uma
## superficie grande, chapada, sem textura — e nos tres o que nomeou o culpado
## foi pintar cada material de uma cor `unshaded` e ver o que sumia.
##
##     godot --path game -- --ver-estrada --estrada-plano=dentro --mat-debug
##
## O que aparecer PRETO nao tem material nenhum ali: e buraco.
const CORES_DEBUG := {
	"leito": Color(1, 0, 1), "tabua": Color(1, 0.5, 0),
	"metal": Color(0, 1, 1), "casca": Color(0, 0.35, 1),
	"folhagem": Color(0, 1, 0), "folhagem_recorte": Color(0.6, 1, 0),
	"mato": Color(1, 1, 0), "arbusto": Color(1, 0, 0),
}


## `--estrada-sem=beira,subbosque,mata,detalhes,massa,distante` desliga
## familias de vegetacao, uma a uma.
##
## Existe pelo mesmo motivo do `--mat-debug` e do `--sem-ceu`: quando uma coisa
## aparece onde nao devia, a pergunta barata e "de qual familia ela e", e a
## resposta mais rapida e apagar familias ate ela sumir. Sem isto a alternativa
## e comentar linha no builder a cada tentativa, que e o mesmo teste feito de
## um jeito que nao sobra para a proxima pessoa.
static var _familias_fora: PackedStringArray


static func _sem(familia: String) -> bool:
	if _familias_fora.is_empty():
		_familias_fora = PackedStringArray([" "])
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with("--estrada-sem="):
				_familias_fora = arg.trim_prefix("--estrada-sem=").split(",")
	return _familias_fora.has(familia)


func _material(nome: StringName) -> Material:
	if OS.get_cmdline_user_args().has("--mat-debug"):
		var dbg := StandardMaterial3D.new()
		dbg.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		# Sem nevoa: com ela, o que esta longe volta lavado para a cor da nevoa
		# e um material fica indistinguivel de um buraco que mostra o fundo.
		# Foi assim que este diagnostico apontou para o lugar errado uma vez.
		dbg.disable_fog = true
		dbg.albedo_color = CORES_DEBUG.get(String(nome), Color.WHITE)
		return dbg
	if _materiais.has(nome):
		return _materiais[nome]
	var caminho_mat := MAT_DIR % nome
	if not ResourceLoader.exists(caminho_mat):
		push_error("EstradaBuilder: material ausente em %s" % caminho_mat)
		return null
	var m := load(caminho_mat) as ShaderMaterial
	_materiais[nome] = m
	return m


# --- conteudo do trecho -----------------------------------------------------

## Quanto o chao da mata esta acima do leito, a `d` metros do eixo.
##
## Medido da BORDA DO LEITO, e nao do eixo
## ---------------------------------------
## Media do eixo, o barranco ja valia 26 cm exatamente em `MEIA_PISTA`, que e
## onde o leito acaba e o chao da mata comeca. Os dois se encontravam ali com um
## degrau de 26 cm entre eles, e degrau entre duas superficies vizinhas nao e
## degrau: e BURACO, porque nenhuma das duas tem parede lateral para fechar o
## vao. Da altura do olho de quem dirige aparecia como uma listra clara correndo
## ao lado da pista com preto dentro — o "limbo" na beira da estrada.
##
## Zerando na borda, as duas superficies se encontram na mesma altura e o
## barranco passa a subir a partir dali, que e o que ele sempre quis dizer.
static func altura_lateral(d: float) -> float:
	var fora := maxf(0.0, absf(d) - KitEstrada.MEIA_PISTA)
	return minf(fora * BARRANCO, BARRANCO_MAX)


## Uma cerca que ACOMPANHA a curva da estrada, de `s0` a `s1`, a `d` metros do
## eixo (negativo = lado esquerdo).
##
## `KitEstrada.cerca` liga dois pontos em linha reta, que e o certo para o que
## ela e — um lance de cerca. Mas a estrada curva ate quatorze metros em noventa
## e cinco, entao um lance unico de vinte metros amarrado nas duas pontas corta
## a pista no meio do arco. Aqui o lance e picado em pedacos curtos que seguem
## `ponto_em`, e a corda so precisa ser curta o bastante para a flecha do arco
## sumir: com quatro metros ela fica abaixo de um centimetro.
## Quanto a cerca fica ALEM da borda do leito.
##
## Eram 1,85 m — quase cinco metros do eixo. O facho do farol abre pouco e morre
## antes disso, entao a cerca inteira caia fora da luz e o que sobrava dela na
## tela era nevoa: ela estava construida na cena e mesmo assim nao existia na
## imagem. Um metro da beira e onde uma divisa de pasto fica de verdade, e e
## onde a luz ainda chega de raspao — que e como ela aparece na print, um lado
## do mourao aceso e o resto no escuro.
const DIVISA := 0.62


const PASSO_CERCA := 4.0


func _cerca_ao_longo(sup: Dictionary, s0: float, s1: float, d: float,
		rng: RandomNumberGenerator) -> void:
	var s := s0
	while s < s1 - 0.5:
		var f := minf(s + PASSO_CERCA, s1)
		var p0 := ponto_em(s) + lado_em(s) * d
		var p1 := ponto_em(f) + lado_em(f) * d
		p0.y += altura_lateral(d)
		p1.y += altura_lateral(d)
		KitEstrada.cerca(sup, p0, p1, rng)
		s = f


func _leito_e_chao(sup: Dictionary, s0: float, rng: RandomNumberGenerator) -> void:
	for i in PASSOS_POR_TRECHO:
		var sa := s0 + float(i) * PASSO
		var sb := sa + PASSO
		var pa := ponto_em(sa)
		var pb := ponto_em(sb)
		var la := lado_em(sa)
		var lb := lado_em(sb)

		# O desgaste do leito anda em onda longa: trechos de barro fundo e
		# trechos secos se alternando a cada quinze metros. Sem isso a estrada
		# inteira tem exatamente o mesmo tom do comeco ao fim, e o olho le a
		# repeticao antes de ler a estrada.
		var desgaste := 0.5 + 0.5 * sin(sa / 15.0 + 0.7)
		KitEstrada.leito(sup, pa, la, pb, lb, desgaste)
		# A parede que fecha a beira. Ver `KitEstrada.saia`.
		KitEstrada.saia(sup, pa, la, pb, lb)

		# O chao da mata dos dois lados, em colunas que sobem o barranco.
		for s: float in [-1.0, 1.0]:
			for k in COLUNAS_CHAO.size() - 1:
				var d0: float = COLUNAS_CHAO[k] * s
				var d1: float = COLUNAS_CHAO[k + 1] * s
				# Na coluna encostada no leito, a borda de dentro sobe junto com
				# ele — mesmo `lift`, mesma ondulacao. O leito e uma fita sem
				# saia lateral: se a beira dele fica 20 cm acima do chao vizinho,
				# de angulo raso se enxerga POR BAIXO da fita, e o que aparece no
				# vao e o fundo da cena. Era a listra clara ao lado da pista, e o
				# que se via nela era a serra do horizonte.
				#
				# O casamento vale so na coluna 0 e so na borda de dentro: da
				# borda de fora em diante o barranco assume e a ondulacao do
				# leito nao tem mais nada a ver com o terreno.
				#
				# A junta e por EXTREMO, e nao uma so para o segmento inteiro.
				# Ela ja foi `ondulacao(pa)` aplicada aos quatro cantos: no canto
				# de tras isso casa com o leito, no canto da frente o leito ja
				# esta em `ondulacao(pb)` e os dois discordam em ate vinte
				# centimetros. A fenda entao ABRE e FECHA uma vez por passo, e o
				# que aparecia na tela era uma fileira de listras claras em forma
				# de fuso correndo os dois lados da pista — cada uma com a nevoa
				# do fundo dentro. Nao era textura nem material: era buraco.
				var junta_a := KitEstrada.ondulacao(pa) * 0.7 + KitEstrada.LIFT
				var junta_b := KitEstrada.ondulacao(pb) * 0.7 + KitEstrada.LIFT
				var casa := 1.0 if k == 0 else 0.0
				var y0a := Vector3(0.0, altura_lateral(d0) + junta_a * casa, 0.0)
				var y0b := Vector3(0.0, altura_lateral(d0) + junta_b * casa, 0.0)
				var y1 := Vector3(0.0, altura_lateral(d1), 0.0)
				# A ordem dos cantos inverte junto com o lado, senao a metade
				# esquerda da mata nasce com a face virada para o chao e some.
				var a := pa + la * d0 + y0a
				var b := pa + la * d1 + y1
				var c := pb + lb * d1 + y1
				var e := pb + lb * d0 + y0b
				var tom := 0.92 - float(k) * 0.05 + rng.randf_range(-0.03, 0.03)
				# Coluna 0 (rente ao leito): barro quente, nao cinza.
				var cor := Color(tom * 1.05, tom * 0.72, tom * 0.48) if k == 0 else Color(tom * 0.85, tom * 0.78, tom * 0.62)
				if s > 0.0:
					KitEstrada.quad(sup, KitEstrada.M_LEITO, a, b, c, e,
						KitEstrada.C_FOLHICO, cor)
				else:
					KitEstrada.quad(sup, KitEstrada.M_LEITO, b, a, e, c,
						KitEstrada.C_FOLHICO, cor)

		KitEstrada.beira(sup, pa, la, rng, 10, not _sem("beira"),
			func(dd: float) -> float: return altura_lateral(dd))

	# Uma ou duas pocas de barro por trecho, sempre dentro de uma trilha: e la
	# que a agua fica, porque e o unico lugar que o pneu cavou.
	for _i in rng.randi_range(1, 2):
		var s := s0 + rng.randf_range(0.0, TRECHO)
		var lado := KitEstrada.TRILHA * (1.0 if rng.randf() < 0.5 else -1.0)
		# Assentada na superficie REAL do leito. Ela pousava no eixo cru, sem
		# `LIFT`, sem ondulacao e sem sulco — e como ela nasce dentro da trilha,
		# que e justamente o ponto mais fundo do perfil, ficava ate quinze
		# centimetros no ar. Poca voando sobre a pista.
		var eixo := ponto_em(s)
		var centro := eixo + lado_em(s) * lado
		# `ondulacao` e sempre lida no EIXO, como em `leito`: lida no ponto
		# deslocado ela devolve outro numero e a poca desencosta de novo.
		centro.y += (KitEstrada.ondulacao(eixo) * KitEstrada.abaulamento(lado)
			+ KitEstrada.sulco(lado) + KitEstrada.LIFT)
		KitEstrada.poca(sup, centro, lado_em(s),
			direcao_em(s), Vector2(rng.randf_range(0.7, 1.1),
				rng.randf_range(1.4, 2.6)))


## A mata dos dois lados: arvores perto, massa de folha longe.
func _mata(sup: Dictionary, s0: float, rng: RandomNumberGenerator) -> void:
	# Onde ja ha copa, para nao plantar duas arvores no mesmo lugar. Guardar so
	# o que foi plantado NESTE trecho basta: duas arvores de trechos vizinhos
	# ficam a 28 m uma da outra na pior das hipoteses.
	var ocupado: Array[Vector3] = []
	var raios: Array[float] = []

	# P0: corredor aberto — densidade media, longe da pista.
	for _i in 40:
		var s := s0 + rng.randf_range(-1.0, TRECHO + 1.0)
		var lado := 1.0 if rng.randf() < 0.5 else -1.0
		# Distribuicao EMPURRADA para longe (sqrt): corredor le o carro no TP.
		var t := rng.randf()
		var d := lerpf(RECUO_ARVORE, ALCANCE_DETALHE - 3.0, pow(t, 0.7))
		var base := ponto_em(s) + lado_em(s) * (d * lado)
		base.y += altura_lateral(d)

		var raio := lerpf(1.3, 2.2, rng.randf())
		# Empurra para fora quem invadiria o corredor, em vez de descartar.
		#
		# Empurrar e nao sortear de novo porque o sorteio ja aconteceu: o `rng`
		# desta funcao alimenta a mata inteira em ordem, e um `continue` aqui
		# deslocaria o fluxo e trocaria TODA a floresta a partir deste ponto. A
		# mesma semente tem de dar a mesma mata, senao duas capturas nunca
		# comparam — e foi exatamente esse deslocamento que invalidou a primeira
		# tentativa de achar este defeito apagando familias de vegetacao.
		if d - raio < CORREDOR_LIVRE:
			d = CORREDOR_LIVRE + raio
			base = ponto_em(s) + lado_em(s) * (d * lado)
			base.y += altura_lateral(d)
		var livre := true
		for k in ocupado.size():
			if base.distance_to(ocupado[k]) < (raio + raios[k]) * 0.78:
				livre = false
				break
		if not livre:
			continue

		var porte := clampf(rng.randf_range(0.15, 0.9) + d * 0.01, 0.0, 1.0)
		var r: float
		if rng.randf() < 0.55:
			# Quanto mais perto da estrada, mais baixo o galho comeca. Ver o
			# parametro `saia` em `KitEstrada.conifera`.
			var saia := lerpf(0.07, 0.26,
				clampf(inverse_lerp(CORREDOR_LIVRE, 22.0, d), 0.0, 1.0))
			r = KitEstrada.conifera(sup, base, porte, rng, saia)
		else:
			r = KitEstrada.arvore(sup, base, porte, rng, rng.randf() < 0.14)
		ocupado.append(base)
		raios.append(r)

		if rng.randf() < 0.4:
			# O arbusto anda em (s, d), e nao em (x, z) do mundo.
			#
			# Somando um deslocamento cru no mundo, o `y` continuava sendo o do
			# ponto ORIGINAL — e como o chao sobe com a lombada e com o
			# barranco, o arbusto ia parar acima ou abaixo do terreno. Era o
			# "arbusto verde flutuando". Andando na coordenada da estrada da
			# para perguntar de novo qual e a altura do chao ali.
			var s_ab := s + rng.randf_range(-1.0, 1.0)
			var d_ab := d + rng.randf_range(-1.0, 1.0)
			var p_ab := ponto_em(s_ab) + lado_em(s_ab) * (d_ab * lado)
			p_ab.y += altura_lateral(d_ab)
			KitParque.arbusto(sup, p_ab, rng.randf_range(0.6, 1.1), rng)

	# Parede de folha so no FUNDO (nevoa), nao na beira da pista.
	for _i in (0 if _sem("massa") else 16):
		var s := s0 + rng.randf_range(0.0, TRECHO)
		var lado := 1.0 if rng.randf() < 0.5 else -1.0
		var d := rng.randf_range(19.0, ALCANCE_DETALHE)
		var base := ponto_em(s) + lado_em(s) * (d * lado)
		base.y += altura_lateral(d)
		# Opaca: esta faixa comeca a 19 m, onde o recorte ja nao da silhueta.
		KitEstrada.massa(sup, base, rng.randf_range(4.0, 7.5),
			rng.randf_range(7.0, 13.0), rng, false)

	if not _sem("subbosque"):
		_sub_bosque(sup, s0, rng)
	if not _sem("distante"):
		_mata_distante(sup, s0, rng)


## O andar do meio da mata, de 7 a 19 metros do eixo.
##
## O buraco que isto tapa
## ----------------------
## `KitEstrada.beira` planta capim e samambaia de 3,6 a 7,3 m, e a parede de
## folha comeca em 19. Entre um e outro so havia tronco de arvore avulso — e
## essa e exatamente a faixa que o para-brisa enquadra, porque e onde a mata
## ainda esta dentro da nevoa e ja esta acima da linha do capo. O resultado era
## uma mata com pe e com teto, mas vazada no meio: dava para ver o vulto do
## fundo por entre os troncos, e nas prints nao se ve nada — a mata e opaca.
##
## Escala pela distancia
## ---------------------
## A moita perto e pequena e a de longe e grande, e nao o contrario. Nao e
## perspectiva: e que o que esta a oito metros ainda tem a beira da estrada
## roubando a luz, e o que esta a dezoito ja e mata fechada de verdade. Sem essa
## rampa, moita de dois metros a oito metros do eixo tapa o farol e o plano de
## dentro perde a estrada.
const SUB_BOSQUE := 34
const SUB_FAIXA := Vector2(7.0, 19.0)

## A mata de fundo, de `ALCANCE_DETALHE` ate `ALCANCE_MATA`.
##
## E o que enche a tela no plano de cima, e e feita so de massa de folha — sem
## tronco, sem galho, sem arbusto no pe. A 30 m e mais, nesta resolucao, arvore
## desenhada peca por peca entrega exatamente a mesma mancha escura que uma
## caixa de folha entrega, e cobra dez vezes mais triangulo por isso.
##
## A densidade cai com a distancia (`pow(t, 0.55)` puxa as amostras para perto)
## porque a area cresce com o quadrado do raio: espalhar uniformemente faria a
## borda de 95 m ter a mesma contagem por metro quadrado que a de 30 m, e o
## custo sairia quase todo na faixa que menos aparece.
const MATA_FUNDO := 120
## Copas altas soltas no fundo, para a silhueta do topo da mata nao virar uma
## linha reta de caixas todas da mesma altura.
const MATA_FUNDO_ALTAS := 22


## Copa, e nao torre.
##
## A primeira versao plantava caixas de 5 a 9 m de lado por 8 a 15 de altura, e
## as altas de 4 a 7 por 16 a 23. Vista de dentro do carro, no corredor, uma
## caixa dessas e uma mancha escura como qualquer outra. Vista do plano aereo,
## a quarenta metros de altura e com a nevoa aberta a cento e setenta, e um
## PREDIO: prisma estreito, mais alto que largo, topo chato — a captura do
## plano 2 mostrava a estrada de terra entrando numa cidade de arranha-ceus
## cinza, na cena cuja fala e "duas horas de terra depois que acaba o
## asfalto". Copa de arvore e mais larga que alta e nao tem topo plano; e o
## que estas duas proporcoes e a segunda caixa menor em cima fazem.
func _mata_distante(sup: Dictionary, s0: float, rng: RandomNumberGenerator) -> void:
	for _i in MATA_FUNDO:
		var s := s0 + rng.randf_range(-1.5, TRECHO + 1.5)
		var lado := 1.0 if rng.randf() < 0.5 else -1.0
		var t := pow(rng.randf(), 0.55)
		var d := lerpf(ALCANCE_DETALHE - 2.0, ALCANCE_MATA, t)
		var base := ponto_em(s) + lado_em(s) * (d * lado)
		base.y += altura_lateral(d)
		_copa_distante(sup, base, rng.randf_range(7.0, 12.0),
			rng.randf_range(6.0, 10.5), rng)

	for _i in MATA_FUNDO_ALTAS:
		var s := s0 + rng.randf_range(0.0, TRECHO)
		var lado := 1.0 if rng.randf() < 0.5 else -1.0
		var d := rng.randf_range(ALCANCE_DETALHE, ALCANCE_MATA - 6.0)
		var base := ponto_em(s) + lado_em(s) * (d * lado)
		base.y += altura_lateral(d)
		_copa_distante(sup, base, rng.randf_range(9.0, 13.0),
			rng.randf_range(11.0, 15.0), rng)


## Uma copa de fundo: a massa larga embaixo e uma segunda, menor e deslocada,
## em cima. As duas juntas dao a silhueta arredondada que uma caixa so nao
## tem, e de cima quebram o topo chato.
func _copa_distante(sup: Dictionary, base: Vector3, largura: float,
		altura: float, rng: RandomNumberGenerator) -> void:
	KitEstrada.massa(sup, base, largura, altura * 0.68, rng, false)
	var topo := base + Vector3(rng.randf_range(-largura * 0.2, largura * 0.2),
		altura * 0.42, rng.randf_range(-largura * 0.15, largura * 0.15))
	KitEstrada.massa(sup, topo, largura * rng.randf_range(0.42, 0.58),
		altura * 0.42, rng, false)
	# A ponta: uma terceira, pequena, deslocada de novo. Sem ela a silhueta do
	# topo da mata contra o ceu, vista do plano aereo, e uma fileira de topos
	# chatos e paredes verticais — uma cidade de predios cinza no fim da estrada
	# de terra. A ponta menor e o que arredonda o contorno.
	var ponta := topo + Vector3(rng.randf_range(-largura * 0.12, largura * 0.12),
		altura * 0.30, rng.randf_range(-largura * 0.1, largura * 0.1))
	KitEstrada.massa(sup, ponta, largura * rng.randf_range(0.22, 0.34),
		altura * 0.26, rng, false)


func _sub_bosque(sup: Dictionary, s0: float, rng: RandomNumberGenerator) -> void:
	for _i in SUB_BOSQUE:
		var s := s0 + rng.randf_range(-0.5, TRECHO + 0.5)
		var lado := 1.0 if rng.randf() < 0.5 else -1.0
		var t := rng.randf()
		var d := lerpf(SUB_FAIXA.x, SUB_FAIXA.y, t)
		var base := ponto_em(s) + lado_em(s) * (d * lado)
		base.y += altura_lateral(d)
		# `t` manda no porte: rasteiro na borda de dentro, cheio la no fundo.
		var larg := lerpf(1.6, 4.2, t) * rng.randf_range(0.8, 1.2)
		var alt := lerpf(1.5, 5.5, t) * rng.randf_range(0.8, 1.15)
		# Perto (7 a 19 m) o recorte ainda e o que da silhueta: fica.
		KitEstrada.massa(sup, base, larg, alt, rng, d < 15.0)
		# Um tufo no pe de parte delas: sem isso a moita flutua um palmo acima
		# do folhico, que aparece justamente quando o farol passa rente.
		if rng.randf() < 0.45:
			KitEstrada.tufo(sup, base + lado_em(s)
					* (rng.randf_range(-0.7, 0.7) * lado),
				[KitEstrada.C_SAMAMBAIA, KitEstrada.C_FOLHA_LARGA,
					KitEstrada.C_MOITA_BAIXA][rng.randi() % 3],
				rng.randf_range(0.7, 1.3), rng.randf_range(0.0, TAU),
				Color(0.80, 0.86, 0.68))


## O que nao e mata nem estrada: o tronco caido, o marco, a cerca.
##
## Nada disto aparece em todo trecho. A conta e a mesma da blitz na abertura da
## cidade: um detalhe que aparece sempre para de ser detalhe e vira parte do
## piso, e o jogador deixa de ver.
func _detalhes(sup: Dictionary, s0: float, rng: RandomNumberGenerator) -> void:
	var indice := int(round(s0 / TRECHO))
	# Trechos da captura (~120 m => indice 4) sempre ganham sujeito no facho.
	var ancora_captura := indice in [3, 4, 5]

	if rng.randf() < 0.40:
		var s := s0 + rng.randf_range(2.0, TRECHO - 2.0)
		var lado := 1.0 if rng.randf() < 0.5 else -1.0
		var d := rng.randf_range(4.5, 8.0)
		var base := ponto_em(s) + lado_em(s) * (d * lado)
		base.y += altura_lateral(d)
		KitEstrada.tronco_caido(sup, base, rng.randf_range(3.5, 6.5),
			rng.randf_range(0.0, TAU), rng)

	if rng.randf() < 0.32:
		var s := s0 + rng.randf_range(2.0, TRECHO - 2.0)
		var lado := 1.0 if rng.randf() < 0.5 else -1.0
		var base := ponto_em(s) + lado_em(s) * (KitEstrada.MEIA_PISTA + 0.6) * lado
		base.y += altura_lateral(KitEstrada.MEIA_PISTA + 0.6)
		KitEstrada.marco(sup, base, atan2(direcao_em(s).x, direcao_em(s).z))

	# Cerca de divisa. Na print ela e presenca CONSTANTE do lado direito — e o
	# que diz que aquela mata tem dono e que ali passa gado — entao ela nasce em
	# quase todo trecho e corre quase o trecho inteiro, em vez dos catorze metros
	# soltos de antes. O lado esquerdo continua sendo mata fechada.
	if ancora_captura or rng.randf() < 0.82:
		var s := s0 + rng.randf_range(0.0, TRECHO * 0.20)
		var lado_c := 1.0 if (ancora_captura or rng.randf() < 0.78) else -1.0
		var d := (KitEstrada.MEIA_PISTA + DIVISA) * lado_c
		_cerca_ao_longo(sup, s, s + rng.randf_range(18.0, TRECHO), d, rng)
		if lado_c < 0.0 or rng.randf() < 0.5:
			var m0 := ponto_em(s + 1.0) + lado_em(s + 1.0) * (KitEstrada.MEIA_PISTA + 0.9) * -1.0
			var m1 := ponto_em(s + 8.0) + lado_em(s + 8.0) * (KitEstrada.MEIA_PISTA + 0.9) * -1.0
			m0.y += altura_lateral(KitEstrada.MEIA_PISTA + 0.9)
			m1.y += altura_lateral(KitEstrada.MEIA_PISTA + 0.9)
			KitEstrada.muro_baixo(sup, m0, m1, rng)

	# Casinha na beira, RECUADA na mata.
	#
	# Ficava a 4,25 m do eixo — ou seja, a um metro e pouco da borda do leito.
	# Uma construcao de quatro metros de frente a essa distancia nao le como
	# "casa na beira da estrada": ela vira um paredao claro que ocupa um terco
	# do para-brisa e recebe o farol inteiro na fachada. Na print de referencia
	# a capela esta atras da cerca, meia dezena de metros para dentro, e o que
	# se ve dela e a silhueta do telhado e uma janela — nao a parede.
	#
	# Tambem deixou de nascer sempre na ancora da captura: uma casa a cada
	# trecho e uma rua, nao uma estrada no meio do mato.
	if rng.randf() < (0.55 if ancora_captura else 0.22):
		var s := s0 + (12.0 if ancora_captura else rng.randf_range(4.0, TRECHO - 6.0))
		var d := KitEstrada.MEIA_PISTA + rng.randf_range(4.5, 7.5)
		var base := ponto_em(s) + lado_em(s) * d
		base.y += altura_lateral(d)
		var giro := atan2(direcao_em(s).x, direcao_em(s).z) + PI * 0.5
		KitEstrada.casa_beira(sup, base, giro, rng, 0 if ancora_captura else -1)

	# Cipo pendurado, sempre do lado de FORA do leito.
	#
	# A ponta de baixo caia a menos de um metro do eixo, ou seja, no meio da
	# pista e a tres metros de altura — bem na linha dos olhos de quem dirige.
	# De dia isso e um cipo; a noite o cordao que segura a folha e escuro e fino
	# e some por completo, e o que sobra na tela e um tufo verde BOIANDO na
	# frente do carro. Nenhuma das prints tem isso, e nao ha como salvar com
	# cor: o problema e o cipo estar onde nao ha nada de onde ele possa pender.
	#
	# Mantendo as duas pontas fora do leito, ele volta a ser o que devia: mato
	# caindo da borda, emoldurando o corredor pelas laterais.
	var n_cipo := 3 if ancora_captura else (2 if rng.randf() < 0.55 else 0)
	for _i in n_cipo:
		var s := s0 + rng.randf_range(0.5, TRECHO - 0.5)
		var lado := 1.0 if rng.randf() < 0.5 else -1.0
		var d_alto := rng.randf_range(5.0, 7.5)
		var d_baixo := rng.randf_range(KitEstrada.MEIA_PISTA + 0.5, 5.0)
		var ancora := ponto_em(s) + lado_em(s) * (lado * d_alto)
		ancora.y += altura_lateral(d_alto) + rng.randf_range(4.0, 6.0)
		var s_b := s + rng.randf_range(-0.8, 0.8)
		var sobre := ponto_em(s_b) + lado_em(s_b) * (lado * d_baixo)
		sobre.y += altura_lateral(d_baixo) + rng.randf_range(2.2, 3.2)
		KitEstrada.cipo(sup, ancora, sobre, rng)


## O vulto parado na beira, no fundo da nevoa.
##
## Este lugar ja teve dois pontos vermelhos de olho, e eles foram removidos com
## razao: `unshaded` no meio da nevoa, os dois pontos ficavam mais brilhantes
## que o farol e o olho ia neles em vez de ir na estrada. O beat de horror que
## a print mostra e o contrario disso — nada acende, uma coisa apaga. O vulto e
## um recorte ESCURO contra a nevoa clara, e e a nevoa que o revela.
##
## Onde ele fica, e por que PERTO
## ------------------------------
## O instinto e por o vulto la no fundo da nevoa, e foi o que eu fiz primeiro:
## a vinte e cinco metros, longe do farol. Ele sumiu. Recorte escuro so existe
## se o que esta ATRAS dele for claro, e a vinte e cinco metros o fundo ainda e
## mata escura mal tocada pela nevoa — preto contra preto.
##
## Na print ele esta na BEIRA DO LEITO e perto: perto o bastante para a nevoa
## ainda nao ter comido o preto dele, e encostado no leito para o que aparece
## atras dele ser o corredor aberto da estrada, que e a unica coisa clara do
## quadro. A nevoa nao esconde o vulto — ela e o fundo que o revela.
##
## Onze metros, espremido entre dois limites
## -----------------------------------------
## A dezesseis ele cabia em trinta pixels numa tela de 270 e sumia atras de
## qualquer moita — nao e contraste, e tamanho. A seis e meio ele fica grande e
## sai do quadro: a 3,65 m do eixo, seis metros e meio a frente poem ele a
## vinte e nove graus da mira, e a ABERTURA do para-brisa desta cabine e mais
## estreita que isso. Ele existe, iluminado, do lado de fora do vidro.
##
## Onze e o ponto em que ele ainda cabe na abertura e ja tem altura para ler. A
## print consegue ele maior porque o para-brisa de la e mais largo que o nosso;
## enquanto a cabine for esta, onze e o teto.
##
## Na cutscene o carro anda, entao ele vem de longe e passa: o quadro em que
## ele le melhor e por volta destes onze metros, e e por isso que a captura
## parada usa exatamente essa distancia.
##
## O farol bate nele e nao adianta: a cor e 0x14161a. Iluminar quase preto da
## quase preto, e e por isso que a silhueta aguenta estar dentro do facho.
##
## De costas para a estrada de proposito. Uma figura encarando o carro anuncia
## intencao, e intencao explica o que esta acontecendo. De lado, ela so esta
## ali, e o plano nao explica nada — que e o tom desta cena inteira.
const VULTO_LADO := KitEstrada.MEIA_PISTA + 0.55
const VULTO_FRENTE := 11.0


func spawn_vulto_beira(s_carro: float, frente: float = VULTO_FRENTE) -> void:
	var velho := get_node_or_null("VultoBeira")
	if velho != null:
		velho.queue_free()

	var s := s_carro + frente
	var p := ponto_em(s) + lado_em(s) * VULTO_LADO
	p.y += altura_lateral(VULTO_LADO)

	var vulto := Figura.new()
	vulto.name = "VultoBeira"
	add_child(vulto)
	vulto.montar(Figura.VULTO)
	vulto.position = p
	# Um quarto de volta a partir da direcao da estrada: ele fica de perfil para
	# quem vem dirigindo, que e a pose da print.
	vulto.rotation.y = atan2(direcao_em(s).x, direcao_em(s).z) + PI * 0.5
	# Pose parada, sem andar. `animar` com rapidez zero cai no `_pose_parado`,
	# que tem a respiracao travada em quinze passos — parado de verdade leria
	# como poste, e a respiracao e o que diz que aquilo esta vivo.
	vulto.animar(0.0, 0.0)




# --- a toca -----------------------------------------------------------------

## Onde o bicho se esconde: a folhagem que fica ENTRE ele e a estrada.
##
## Por que a toca e montada, e nao encontrada
## ------------------------------------------
## A mata ja tem sub-bosque de sobra na faixa de 7 a 19 m, e a tentacao e so
## plantar a camera la e deixar o acaso enquadrar. Ja foi tentado no plano
## rasante e o resultado esta escrito no `RASANTE_LADO`: a camera atravessava
## moita e a imagem virava um retangulo preto com uma janela no meio, que e o
## interior de uma caixa de folha vista de dentro. Acaso nao enquadra.
##
## Entao a folha da frente e COLOCADA, e colocada em tres lugares que nao
## disputam o centro do quadro:
##
##   copa    — acima da linha do olho, pendurada no terco de cima
##   samambaia — abaixo dela, mordendo o terco de baixo
##   dois troncos — bem abertos, que so entram quando a cabeca vira de verdade
##
## O meio fica limpo de proposito. A cabeca do bicho gira uns setenta graus
## acompanhando o carro, e uma cortina fechada faria o plano inteiro ser folha;
## com a moldura so nas bordas, o que a rotacao produz e a folha ENTRANDO e
## saindo de quadro, que e o que denuncia que ha alguem atras dela.
##
## Determinista, como todo o resto desta cena: a semente sai de `s`, entao a
## mesma toca nasce em toda execucao e duas capturas comparam.
func spawn_toca(s: float, sinal: float, distancia: float,
		altura_olho: float) -> void:
	var velho := get_node_or_null("Toca")
	if velho != null:
		velho.queue_free()

	var rng := RandomNumberGenerator.new()
	rng.seed = absi(semente * 7919 + int(s * 100.0))

	var olho := ponto_em(s) + lado_em(s) * (distancia * sinal)
	olho.y += altura_lateral(distancia) + altura_olho
	# Para onde ele olha em repouso: o eixo da estrada, na altura do leito.
	var para_estrada := (ponto_em(s) - olho)
	para_estrada.y = 0.0
	if para_estrada.length_squared() < 0.001:
		para_estrada = Vector3.FORWARD
	var mira := para_estrada.normalized()
	var transversal := mira.cross(Vector3.UP).normalized()

	var sup: Dictionary = {}

	# As tres faixas ficam FORA do centro do quadro, e isso e o plano inteiro.
	#
	# A lente e de 44 graus na vertical, o que da uns 71 na horizontal em 16:9:
	# a metade util e de 35 graus para cada lado. Folha plantada em volta do
	# olho sem esse cuidado cai no meio da imagem — na primeira montagem uma
	# unica placa a 62 cm da lente ocupava quase metade da tela e o carro
	# aparecia por uma fresta. A moldura tem de morder as BORDAS: a copa desce
	# pelo alto, a samambaia sobe por baixo, e os troncos entram pelos lados.
	#
	# Cada peca e um `tufo`, que sao dois planos CRUZADOS. Placa unica com giro
	# sorteado some quando fica de perfil para a camera, e a cabeca gira setenta
	# graus durante o plano: metade da moldura piscaria no meio do movimento.

	# A copa, pendurada. `tufo` desenha para CIMA a partir do pe, entao o pe
	# desce meia altura para o centro da folha cair onde se quer.
	for i in 9:
		var ang := lerpf(-0.82, 0.82, float(i) / 8.0) + rng.randf_range(-0.08, 0.08)
		var dist := rng.randf_range(1.00, 1.60)
		var tam := rng.randf_range(0.44, 0.72)
		var onde := olho + (mira * cos(ang) + transversal * sin(ang)) * dist
		onde.y += rng.randf_range(0.34, 0.62) - tam * 0.5
		KitEstrada.tufo(sup, onde, KitEstrada.C_FOLHA_LARGA, tam,
			rng.randf_range(0.0, TAU),
			Color(0.46, 0.52, 0.38).lerp(Color(0.24, 0.29, 0.21),
				rng.randf_range(0.0, 0.7)))

	# A samambaia do pe, mais perto da lente que a copa: e o que da profundidade
	# a moldura — duas distancias diferentes na mesma borda do quadro.
	for i in 8:
		var ang := lerpf(-0.72, 0.72, float(i) / 7.0) + rng.randf_range(-0.1, 0.1)
		var dist := rng.randf_range(0.85, 1.35)
		var tam := rng.randf_range(0.40, 0.66)
		var onde := olho + (mira * cos(ang) + transversal * sin(ang)) * dist
		onde.y -= rng.randf_range(0.40, 0.72) + tam * 0.5
		KitEstrada.tufo(sup, onde,
			[KitEstrada.C_SAMAMBAIA, KitEstrada.C_MOITA_BAIXA][rng.randi() % 2],
			tam, rng.randf_range(0.0, TAU),
			Color(0.52, 0.58, 0.42).lerp(Color(0.22, 0.27, 0.19),
				rng.randf_range(0.0, 0.6)))

	# Os dois troncos. Nao sao arvore: sao a batente da janela. Ficam na beira
	# do campo de visao (33 a 43 graus), entao em repouso so uma aresta deles
	# aparece, e sao eles que varrem o quadro quando a cabeca vira.
	for lado_t: float in [-1.0, 1.0]:
		var ang := lado_t * rng.randf_range(0.58, 0.76)
		var dist := rng.randf_range(1.9, 2.7)
		var pe := olho + (mira * cos(ang) + transversal * sin(ang)) * dist
		pe.y -= altura_olho
		var alt := altura_olho + rng.randf_range(2.6, 3.8)
		KitModular.caixa_flex(sup, KitEstrada.M_CASCA,
			pe + Vector3(0.0, alt * 0.5, 0.0),
			Vector3(rng.randf_range(0.14, 0.21), alt, rng.randf_range(0.14, 0.21)),
			KitEstrada.CASCA_TOM, rng.randf_range(0.0, TAU),
			pe.y, pe.y + alt, 0.0, KitEstrada.CEDE_TRONCO,
			PSXMesh.FACE_TODAS, 2.0)
	var no := Node3D.new()
	no.name = "Toca"
	var tris := 0
	for material: StringName in sup:
		var d: Dictionary = sup[material]
		if PSXMesh.dados_vazio(d):
			continue
		var mi := MeshInstance3D.new()
		mi.name = String(material)
		mi.mesh = PSXMesh.dados_para_mesh(d)
		mi.material_override = _material(material)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# A folha fica a meio metro da lente e a cupula do ceu tem 420 m de raio:
		# sem margem de corte, a caixa da malha sai do tronco de visao assim que a
		# cabeca vira e a moldura inteira pisca. Um metro basta e nao custa nada.
		mi.extra_cull_margin = 4.0
		no.add_child(mi)
		tris += PSXMesh.dados_triangulos(d)
	no.set_meta(&"triangulos", tris)
	triangulos += tris
	add_child(no)

## Garante casa + cerca + muro no cone do farol na distancia de captura.
## Nao depende de RNG do trecho: o facho sempre tem sujeito (ref 04).
func garantir_props_facho(s_carro: float) -> void:
	var velho := get_node_or_null("PropsFacho")
	if velho != null:
		velho.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(semente * 17 + int(s_carro) * 31)
	var sup: Dictionary = {}
	# Casa EXPLICITA no cone direito, fora do leito (P0 + ref 04).
	# Longe da lente. A 6,5 m e 4,45 m do eixo, uma casa de quatro metros ocupava
	# um terco do para-brisa e virava um paredao claro coberto pelo farol. Na
	# print ela esta recuada na mata, pequena, e e a nevoa que a apresenta.
	var s := s_carro + 20.0
	var d_casa := KitEstrada.MEIA_PISTA + 5.2
	var base := ponto_em(s) + lado_em(s) * d_casa
	base.y += altura_lateral(d_casa)
	var giro := atan2(direcao_em(s).x, direcao_em(s).z) + PI * 0.5
	KitEstrada.casa_beira(sup, base, giro, rng, 0)
	# Uma linha de cerca so, no lado direito, longa e AFASTADA da pista.
	#
	# Eram duas, a 4,05 m e a 3,90 m — praticamente sobrepostas e quase dentro do
	# leito, o que punha mourao em cima de mourao no meio do para-brisa. Na print
	# a cerca e uma linha unica que corre paralela a estrada e se perde na nevoa:
	# ela precisa de COMPRIMENTO para convergir, e nao de proximidade.
	_cerca_ao_longo(sup, s_carro + 3.0, s_carro + 24.0,
		KitEstrada.MEIA_PISTA + DIVISA, rng)
	var d_m := -(KitEstrada.MEIA_PISTA + 1.0)
	var m0 := ponto_em(s - 2.0) + lado_em(s - 2.0) * d_m
	var m1 := ponto_em(s + 6.0) + lado_em(s + 6.0) * d_m
	m0.y += altura_lateral(absf(d_m))
	m1.y += altura_lateral(absf(d_m))
	KitEstrada.muro_baixo(sup, m0, m1, rng)
	# Cipos no TOPO do para-brisa — fios esparsos, corredor livre no centro.
	#
	# Eram nove comecando a 1,2 m: caiam em cima da lente e o para-brisa virava
	# uma cortina de cordao. Depois foram quatro a seis metros, e ainda assim
	# apareciam como tufos soltos no ar no meio da estrada: o cordao que os
	# prende e escuro e fino, some na noite, e o que sobra e a folha — sem nada
	# ligando ela a lugar nenhum. Tres, a partir de doze metros, ja dentro da
	# nevoa, onde o cordao nao precisa ser visto porque a folha tambem nao e.
	for i in 3:
		var sc := s_carro + 12.0 + float(i) * 3.4
		var lado := 1.0 if i % 2 == 0 else -1.0
		# Fora do leito nas duas pontas — mesma regra de `_detalhes`.
		var d_alto := rng.randf_range(5.0, 7.0)
		var d_baixo := rng.randf_range(KitEstrada.MEIA_PISTA + 0.6, 4.8)
		var ancora := ponto_em(sc) + lado_em(sc) * (lado * d_alto)
		ancora.y += altura_lateral(d_alto) + rng.randf_range(3.6, 5.2)
		var s_b := sc + rng.randf_range(-0.4, 0.4)
		var sobre := ponto_em(s_b) + lado_em(s_b) * (lado * d_baixo)
		sobre.y += altura_lateral(d_baixo) + rng.randf_range(2.1, 2.9)
		KitEstrada.cipo(sup, ancora, sobre, rng)
	# Brush FORA do leito — so beira.
	for i in 12:
		var sb := s_carro + rng.randf_range(2.0, 14.0)
		var lado := 1.0 if rng.randf() < 0.58 else -1.0
		var d := rng.randf_range(KitEstrada.MEIA_PISTA + 0.7, KitEstrada.MEIA_PISTA + 3.0)
		var pp := ponto_em(sb) + lado_em(sb) * (d * lado)
		pp.y += altura_lateral(d)
		KitEstrada.tufo(sup, pp,
			[KitEstrada.C_CAPIM, KitEstrada.C_SAMAMBAIA, KitEstrada.C_MOITA_BAIXA,
				KitEstrada.C_FOLHA_LARGA, KitEstrada.C_GALHO_SECO][rng.randi() % 5],
			rng.randf_range(0.7, 1.35), rng.randf_range(0.0, TAU),
			Color(0.78, 0.86, 0.62))
	for i in 3:
		var s_ab := s + rng.randf_range(-1.2, 1.8)
		var d_ab := d_casa + rng.randf_range(-0.2, 0.9)
		var bp := ponto_em(s_ab) + lado_em(s_ab) * d_ab
		bp.y += altura_lateral(d_ab)
		KitParque.arbusto(sup, bp, rng.randf_range(0.7, 1.15), rng)
	var no := Node3D.new()
	no.name = "PropsFacho"
	var tris := 0
	for material: StringName in sup:
		var d: Dictionary = sup[material]
		if PSXMesh.dados_vazio(d):
			continue
		var mi := MeshInstance3D.new()
		mi.name = String(material)
		mi.mesh = PSXMesh.dados_para_mesh(d)
		mi.material_override = _material(material)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		no.add_child(mi)
		tris += PSXMesh.dados_triangulos(d)
	no.set_meta(&"triangulos", tris)
	triangulos += tris
	add_child(no)
