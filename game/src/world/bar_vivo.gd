## Os outros bares da cidade: o mesmo salao do Bar do Seu Ze, com outro nome,
## outra cor e outra placa.
##
## Por que existe
## -------------
## So o Bar do Seu Ze (a porta de bar de `ChunkBuilder._porta_do_chunk`) tinha
## salao. Os outros "bares" eram loja da ComercioVivo que sorteava a placa BAR
## DO TIAO: porta de enrolar e, atras, a prateleira de mercearia — o usuario
## achou os bares vazios. Agora bar e bar: o lote comercial escolhido aqui vira
## `ChunkBuilder._predio_do_bar`, o terreo vazado inteiro do KitBar (balcao,
## cervejeira, sinuca, TV, gente, mesa na calcada), e so muda o que muda de um
## boteco para outro em Minas: o nome, a letra da placa, a cor da parede, o
## azulejo e o toldo.
##
## O nome
## ------
## `NOMES` e o contrato com o atlas `bares_nomes.png` (tools/gerar_bar_variantes.py):
## a ordem e a celula (2 colunas x 8 linhas). Nomes inventados, do jeito de bar
## de interior. O Bar do Seu Ze fica de fora: ele e um so.
class_name BarVivo
extends RefCounted

## A ordem e a das celulas do atlas `bares_nomes.png`.
const NOMES: Array[String] = [
	"Bar do Tião", "Boteco do João", "Bar São Jorge", "Bar do Geraldo",
	"Bar da Dona Cida", "Botequim Boa Vista", "Bar do Mineiro", "Bar do Bigode",
	"Bar Santa Luzia", "Bar do Luizinho", "Bar Ponto Certo", "Bar do Zequinha",
	"Cantinho do Torresmo", "Bar da Esquina", "Bar do Chicão", "Boteco do Tonho",
]

## Cor da parede e dos pilares: o verde-agua, o azul colonial, o vermelho oxido,
## o laranja, o rosa antigo, o verde-bandeira, o branco de cal e o creme. O
## amarelo-ovo (KitBar.AMARELO) e do Seu Ze: com ele e o toldo vermelho o outro
## bar saia a copia do Seu Ze com outro nome.
const PAREDES: Array[Color] = [
	Color("7fb3a0"), Color("4f79a8"), Color("a44a38"), Color("d0803a"),
	Color("c98c8c"), Color("4f8a52"), Color("e2ded2"), Color("e0cfa4"),
]
## Tinta do azulejo (a textura e branca com a cercadura verde).
const AZULEJOS: Array[Color] = [
	Color.WHITE, Color("cfe0ee"), Color("dcecd8"), Color("f0e4c8"), Color("e8d4d0"),
]
## O toldo: material de listra de cada variante (ver gerar_bar_variantes.py).
const TOLDOS: Array[StringName] = [
	&"bar_toldo", &"bar_toldo_verde", &"bar_toldo_azul", &"bar_toldo_laranja",
]

## A cadeira de plastico de cada bar: a amarela e a vermelha de cervejaria, a
## azul, a verde e a branca.
const PLASTICOS: Array[Color] = [
	Color("e2c64a"), Color("c8352e"), Color("2f5f9f"), Color("3f8a4a"), Color("e6e0d4"),
]

## Um em quantos chunks comerciais sem o Seu Ze tem um bar.
const UM_EM := 4


## O estilo do bar do chunk (cx, cz). O nome anda com a coordenada, e nao com o
## sorteio: dois bares perto um do outro nunca tem o mesmo nome. A cor e o toldo
## vem da semente.
static func estilo(cx: int, cz: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = MalhaUrbana._ruido(cx, cz, 8803)
	var nome := posmod(cx * 5 + cz * 3, NOMES.size())
	return {
		"nome": nome,
		"titulo": NOMES[nome],
		"parede": PAREDES[r.randi() % PAREDES.size()],
		"azulejo": AZULEJOS[r.randi() % AZULEJOS.size()],
		"toldo": TOLDOS[r.randi() % TOLDOS.size()],
		"plastico": PLASTICOS[r.randi() % PLASTICOS.size()],
	}


## Este chunk tem um bar novo? Quadra comercial, e nunca no chunk do Seu Ze (a
## porta de bar) nem no da loja de conveniencia ou da casa da fumaca.
static func tem_bar(cx: int, cz: int, quadra: Dictionary, porta: Dictionary) -> bool:
	if not FachadaViva.ativo or bool(quadra["casa"]):
		return false
	if int(quadra["distrito"]) != MalhaUrbana.Distrito.COMERCIAL:
		return false
	if not porta.is_empty() and StringName(porta.get("interior", &"")) in [&"bar", &"mercado",
			&"casa_fumaca"]:
		return false
	# A celula da Praca da Matriz e ancorada (Tracado._ancora): cenario da
	# cutscene e da frente da praca. Nada novo nela sem combinar.
	if Serpentina.celula_do_chunk(cx, cz) == Vector2i(1, -1):
		return false
	return posmod(cx * 53 + cz * 29, UM_EM) == 0


## Uma celula do atlas de nomes (2 x 8).
static func uv_do_nome(indice: int) -> Rect2:
	return Rect2(float(indice % 2) * 0.5, float(indice / 2) * 0.125, 0.5, 0.125)
