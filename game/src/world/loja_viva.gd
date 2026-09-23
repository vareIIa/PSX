## As lojas de verdade da rua comercial: onde nascem, de que ramo sao e o que
## se compra nelas.
##
## Por que existe
## -------------
## A rua comercial tinha 241 portas de loja abertas em 320 chunks (censo da
## janela 16 x 20 em volta da origem), e nenhuma se entrava: atras da porta de
## enrolar havia uma casca de 3 a 4 m com prateleira pintada, colada na parede
## do predio. Da calcada lia como loja; um passo depois, como cenario. Com o bar
## de verdade do lado (BarVivo), a diferenca ficou gritante.
##
## A troca e de quantidade por qualidade:
##   - a fachada comercial deixa de abrir loja de mentira (ComercioVivo): o vao
##     que sobra e porta de aco fechada, sem placa, ou janela da casa de cima;
##   - um chunk comercial em cada dois ganha UMA loja em que se entra andando,
##     no terreo vazado do predio, como o bar: o salao montado pelo que a placa
##     diz (KitLoja), atendente atras do balcao, cliente olhando prateleira, e
##     a conversa com quem atende vende o que o ramo vende.
##
## O ramo e a celula do atlas de letreiros (tools/gerar_letreiros.py, NOMES):
## a placa da testeira e o salao sao a mesma escolha, e por isso nunca
## discordam. Tudo aqui e deduzido de (cx, cz), sem rng: o mapa, o teste e o
## chunk perguntam a mesma coisa e ouvem a mesma resposta.
class_name LojaViva
extends RefCounted

## `--sem-loja-viva` volta a fachada comercial antiga (lojas de casca).
static var ativo := not OS.get_cmdline_user_args().has("--sem-loja-viva")

## Um chunk comercial em quantos ganha loja (os de bar, mercado, casa da fumaca
## e a celula da praca ficam de fora antes da conta). Um em um: na janela do
## censo sao ~50 chunks elegiveis contra 241 lojas de casca que havia.
const UMA_EM := 1
## Largura minima do lote: balcao, corredor e prateleira dos dois lados.
const LARGURA_MINIMA := 5.6
## Quanto o chao pode variar ao longo da frente do lote na ladeira. O piso da
## loja fica rente a calcada na boca, no meio da frente: cada ponta fica ate
## meio disto acima (o pe da parede entra no chao) ou abaixo (o embasamento de
## pedra aparece). Com 0,3 m a cidade de morro recusava 12 de 19 lotes.
const DESNIVEL_MAXIMO := 0.9

## Celulas do atlas loja_produtos.png (tools/gerar_lojas.py, PRODUTOS).
enum P {
	PAES, BOLOS, REMEDIOS, FRASCOS,
	CARRETEIS, TECIDOS, RACAO, LATAS,
	PACOTES, CIMENTO, TINTAS, COSMETICOS,
	CARNES, CADERNOS, CAIXAS_SAPATO, SAPATOS,
	BRINQUEDOS, UTENSILIOS, SALGADOS, GARRAFAS,
	OCULOS, RELOGIOS, PNEUS, FERRAMENTAS,
	LOTERIA, POTES, CACHACAS, BALAIOS,
	BIJUTERIAS, REVISTAS, SEMENTES, LINGUICA,
}

## Planta do salao (KitLoja):
##   BALCAO   balcao de atendimento atravessado; atras dele a parede cheia e
##            quem atende; na frente o cliente (padaria, farmacia, acougue...)
##   LIVRE    prateleira nas paredes, ilha no meio e o caixa perto da porta
##            (mercearia, bazar, racao, construcao, sapataria)
##   BELEZA   cadeiras com espelho numa parede, lavatorio no fundo
##   OFICINA  chao livre de borracharia: pneu empilhado, compressor, bancada
enum Planta { BALCAO, LIVRE, BELEZA, OFICINA }

## O que cada ramo vende. Preco em reais inteiros, como o resto do jogo (1998).
const ITENS := {
	&"pao_de_queijo": {"nome": "PAO DE QUEIJO", "preco": 1},
	&"cafe": {"nome": "CAFEZINHO", "preco": 1},
	&"coxinha": {"nome": "COXINHA", "preco": 2},
	&"guarana": {"nome": "GUARANA", "preco": 1},
	&"torresmo": {"nome": "TORRESMO", "preco": 3},
	&"rapadura": {"nome": "RAPADURA", "preco": 1},
	&"remedio": {"nome": "REMEDIO", "preco": 8},
	&"bandagem": {"nome": "BANDAGEM", "preco": 5},
	&"bateria": {"nome": "PILHA", "preco": 4},
	&"lanterna": {"nome": "LANTERNA", "preco": 20},
	&"pe_de_cabra": {"nome": "PE DE CABRA", "preco": 18},
	&"terra": {"nome": "SACO DE TERRA", "preco": 6},
	&"regador": {"nome": "REGADOR", "preco": 15},
	&"radio": {"nome": "RADINHO", "preco": 30},
}

## Na ordem do atlas de letreiros: a celula k da placa e o ramo k.
##
## fachada   &"enrolar" (porta de aco toda enrolada) ou &"vitrine" (vidro e
##           porta de vidro aberta)
## vitrine   celulas do balcao de vidro (planta BALCAO)
## fundo     celulas das prateleiras da parede de tras, de baixo para cima
## lados     celulas das prateleiras das paredes do lado
## equipe    funcao de cada um que trabalha ali (rotulo da conversa)
## clientes  quantos, no minimo e no maximo
## venda     ids de ITENS; servico: a opcao que nao e mercadoria
const RAMOS: Array[Dictionary] = [
	{"id": &"padaria", "titulo": "PADARIA PAO DE MINAS", "planta": Planta.BALCAO,
		"fachada": &"enrolar", "cartaz": 1, "luz": Color("ffe2b0"),
		"paredes": [Color("f2e6c8"), Color("f4ead6"), Color("e8dcc0")],
		"piso": &"bar_ladrilho", "azulejo": Color("f4f2ec"),
		"vitrine": [P.PAES, P.BOLOS, P.SALGADOS], "fundo": [P.PAES, P.PAES, P.POTES, P.BOLOS],
		"lados": [P.PACOTES, P.LATAS, P.GARRAFAS], "equipe": ["a balconista", "o padeiro"],
		"profissoes": ["BALCONISTA", "PADEIRO"], "clientes": Vector2i(1, 3),
		"venda": [&"pao_de_queijo", &"cafe"], "banquetas": false},
	{"id": &"farmacia", "titulo": "FARMACIA SAO JOSE", "planta": Planta.BALCAO,
		"fachada": &"vitrine", "cartaz": 0, "luz": Color("e8f2ff"),
		"paredes": [Color("f6f6f2"), Color("eef4f2")], "piso": &"piso_ceramico",
		"azulejo": Color("cfe2ec"),
		"vitrine": [P.FRASCOS, P.REMEDIOS], "fundo": [P.REMEDIOS, P.REMEDIOS, P.REMEDIOS, P.FRASCOS],
		"lados": [P.FRASCOS, P.COSMETICOS], "equipe": ["o farmaceutico", "a balconista"],
		"profissoes": ["FARMACEUTICO", "BALCONISTA"], "clientes": Vector2i(1, 2),
		"venda": [&"remedio", &"bandagem"], "servico": &"pressao"},
	{"id": &"armarinho", "titulo": "ARMARINHO DONA CIDA", "planta": Planta.BALCAO,
		"fachada": &"vitrine", "cartaz": 13, "luz": Color("ffe8c8"),
		"paredes": [Color("f2dcd8"), Color("f0e4d0")], "piso": &"tabua",
		"azulejo": Color("f2dcd8"),
		"vitrine": [P.BIJUTERIAS, P.CARRETEIS], "fundo": [P.TECIDOS, P.CARRETEIS, P.CARRETEIS, P.BIJUTERIAS],
		"lados": [P.TECIDOS, P.TECIDOS], "equipe": ["a dona do armarinho"],
		"profissoes": ["COMERCIANTE"], "clientes": Vector2i(1, 2),
		"venda": [], "servico": &"botao"},
	{"id": &"racao", "titulo": "CASA DE RACAO AGROPECUARIA", "planta": Planta.LIVRE,
		"fachada": &"enrolar", "cartaz": 11, "luz": Color("fff0d0"),
		"paredes": [Color("d8e4c8"), Color("e4dcc4")], "piso": &"concreto",
		"azulejo": Color("b8c8a8"),
		"fundo": [P.RACAO, P.SEMENTES, P.FERRAMENTAS], "lados": [P.RACAO, P.UTENSILIOS, P.BALAIOS],
		"ilha": [P.SEMENTES, P.UTENSILIOS], "pilhas": Color("c8452e"),
		"equipe": ["o balconista", "o carregador"], "profissoes": ["BALCONISTA", "CARREGADOR"],
		"clientes": Vector2i(1, 2), "venda": [&"terra", &"regador"]},
	{"id": &"loterica", "titulo": "LOTERICA BOA SORTE", "planta": Planta.BALCAO,
		"fachada": &"vitrine", "cartaz": 3, "luz": Color("eef4ff"),
		"paredes": [Color("f4f4f0"), Color("e8f0e8")], "piso": &"piso_ceramico",
		"azulejo": Color("7fb89a"),
		"vitrine": [P.LOTERIA], "fundo": [P.LOTERIA, P.REVISTAS, P.LOTERIA, P.REVISTAS],
		"lados": [P.LOTERIA, P.REVISTAS], "equipe": ["a moca do caixa", "o gerente"],
		"profissoes": ["CAIXA", "GERENTE"], "clientes": Vector2i(2, 3),
		"venda": [], "servico": &"fezinha", "guiche": true},
	{"id": &"mercearia", "titulo": "MERCEARIA BOA VISTA", "planta": Planta.LIVRE,
		"fachada": &"enrolar", "cartaz": 13, "luz": Color("ffe4b8"),
		"paredes": [Color("efe2b8"), Color("e8d8b0")], "piso": &"bar_ladrilho",
		"azulejo": Color("e2e8d8"),
		"fundo": [P.PACOTES, P.LATAS, P.GARRAFAS, P.CACHACAS], "lados": [P.PACOTES, P.POTES, P.BALAIOS, P.UTENSILIOS],
		"ilha": [P.LATAS, P.PACOTES], "equipe": ["o dono da mercearia"],
		"profissoes": ["COMERCIANTE"], "clientes": Vector2i(1, 3),
		"venda": [&"rapadura", &"guarana", &"bateria"]},
	{"id": &"construcao", "titulo": "MATERIAL DE CONSTRUCAO IRMAOS REZENDE",
		"planta": Planta.LIVRE, "fachada": &"enrolar", "cartaz": 12, "luz": Color("f4f4ee"),
		"paredes": [Color("d8d6d0"), Color("e0dcd0")], "piso": &"concreto",
		"azulejo": Color("b8b4aa"),
		"fundo": [P.TINTAS, P.FERRAMENTAS, P.TINTAS], "lados": [P.FERRAMENTAS, P.TINTAS, P.UTENSILIOS],
		"ilha": [P.FERRAMENTAS, P.TINTAS], "pilhas": Color("c9c2b2"),
		"equipe": ["o vendedor", "o ajudante"], "profissoes": ["VENDEDOR", "PEDREIRO"],
		"clientes": Vector2i(1, 2), "venda": [&"pe_de_cabra", &"lanterna"]},
	{"id": &"salao", "titulo": "SALAO BELEZA PURA", "planta": Planta.BELEZA,
		"fachada": &"vitrine", "cartaz": 4, "luz": Color("fff0f4"),
		"paredes": [Color("e8d4e4"), Color("f2dce0"), Color("dcd4ec")], "piso": &"piso_ceramico",
		"azulejo": Color("f4f0f2"),
		"fundo": [P.COSMETICOS, P.COSMETICOS], "lados": [P.COSMETICOS, P.FRASCOS],
		"equipe": ["a cabeleireira", "a manicure"], "profissoes": ["CABELEIREIRA", "MANICURE"],
		"clientes": Vector2i(1, 2), "venda": [], "servico": &"corte"},
	{"id": &"acougue", "titulo": "ACOUGUE SANTA RITA", "planta": Planta.BALCAO,
		"fachada": &"enrolar", "cartaz": 2, "luz": Color("f0f6ff"),
		"paredes": [Color("f6f6f4")], "piso": &"bar_ladrilho", "azulejo": Color("fafaf8"),
		"azulejo_inteiro": true, "vitrine": [P.CARNES, P.CARNES],
		"fundo": [P.PACOTES, P.GARRAFAS, P.LATAS], "lados": [P.PACOTES, P.GARRAFAS],
		"frigorifico": true,
		"equipe": ["o acougueiro", "a moca do caixa"], "profissoes": ["ACOUGUEIRO", "CAIXA"],
		"clientes": Vector2i(1, 2), "venda": [&"torresmo"]},
	{"id": &"papelaria", "titulo": "PAPELARIA ALFA", "planta": Planta.BALCAO,
		"fachada": &"vitrine", "cartaz": 5, "luz": Color("f2f6ff"),
		"paredes": [Color("d8e4f0"), Color("e8ecf0")], "piso": &"piso_ceramico",
		"azulejo": Color("d8e4f0"),
		"vitrine": [P.CADERNOS, P.REVISTAS], "fundo": [P.CADERNOS, P.REVISTAS, P.CADERNOS, P.BRINQUEDOS],
		"lados": [P.CADERNOS, P.REVISTAS], "xerox": true, "equipe": ["o rapaz da xerox"],
		"profissoes": ["VENDEDOR"], "clientes": Vector2i(1, 2),
		"venda": [&"bateria"], "servico": &"xerox"},
	{"id": &"sapataria", "titulo": "SAPATARIA CENTRAL", "planta": Planta.LIVRE,
		"fachada": &"vitrine", "cartaz": 6, "luz": Color("fff2dc"),
		"paredes": [Color("efe6d8"), Color("e6dccc")], "piso": &"tabua",
		"azulejo": Color("d8c8b0"),
		"fundo": [P.CAIXAS_SAPATO, P.CAIXAS_SAPATO, P.CAIXAS_SAPATO], "lados": [P.SAPATOS, P.SAPATOS, P.CAIXAS_SAPATO],
		"banco": true, "equipe": ["o vendedor"], "profissoes": ["VENDEDOR"],
		"clientes": Vector2i(1, 2), "venda": [], "servico": &"engraxar"},
	{"id": &"bazar", "titulo": "BAZAR TUDO 1,99", "planta": Planta.LIVRE,
		"fachada": &"enrolar", "cartaz": 7, "luz": Color("f4f4ff"),
		"paredes": [Color("f4e8a8"), Color("e8f0d0")], "piso": &"piso_ceramico",
		"azulejo": Color("f0e090"),
		"fundo": [P.BRINQUEDOS, P.UTENSILIOS, P.POTES], "lados": [P.BALAIOS, P.BRINQUEDOS, P.UTENSILIOS],
		"ilha": [P.BRINQUEDOS, P.POTES], "equipe": ["a moca do bazar"],
		"profissoes": ["VENDEDORA"], "clientes": Vector2i(2, 3),
		"venda": [&"lanterna", &"bateria", &"radio"]},
	{"id": &"lanchonete", "titulo": "LANCHONETE DO ZE", "planta": Planta.BALCAO,
		"fachada": &"enrolar", "cartaz": 8, "luz": Color("ffe0a8"),
		"paredes": [Color("f0d8b0"), Color("e8e0c8")], "piso": &"bar_ladrilho",
		"azulejo": Color("e89a4a"),
		"vitrine": [P.SALGADOS, P.SALGADOS], "fundo": [P.GARRAFAS, P.CACHACAS, P.POTES],
		"lados": [P.GARRAFAS], "banquetas": true, "chapa": true,
		"equipe": ["o chapeiro", "a atendente"], "profissoes": ["CHAPEIRO", "ATENDENTE"],
		"clientes": Vector2i(2, 3), "venda": [&"coxinha", &"guarana", &"cafe"]},
	{"id": &"otica", "titulo": "OTICA VISAO", "planta": Planta.BALCAO,
		"fachada": &"vitrine", "cartaz": 9, "luz": Color("f4f6ff"),
		"paredes": [Color("e4ecf2"), Color("f2f0ea")], "piso": &"piso_ceramico",
		"azulejo": Color("c8d4e0"),
		"vitrine": [P.OCULOS, P.RELOGIOS], "fundo": [P.OCULOS, P.OCULOS, P.OCULOS],
		"lados": [P.OCULOS, P.BIJUTERIAS], "espelho": true, "equipe": ["o otico"],
		"profissoes": ["OTICO"], "clientes": Vector2i(1, 1), "venda": [], "servico": &"oculos"},
	{"id": &"borracharia", "titulo": "BORRACHARIA 24 HORAS", "planta": Planta.OFICINA,
		"fachada": &"enrolar", "cartaz": 15, "luz": Color("fff4e0"),
		"paredes": [Color("c8c4b8"), Color("d4ccb8")], "piso": &"concreto_sujo",
		"azulejo": Color("8a8478"),
		"fundo": [P.PNEUS, P.FERRAMENTAS], "lados": [P.PNEUS, P.FERRAMENTAS],
		"equipe": ["o borracheiro", "o ajudante"], "profissoes": ["BORRACHEIRO", "AJUDANTE"],
		"clientes": Vector2i(0, 1), "venda": [], "servico": &"calibrar"},
	{"id": &"relojoaria", "titulo": "RELOJOARIA O TEMPO", "planta": Planta.BALCAO,
		"fachada": &"vitrine", "cartaz": 10, "luz": Color("fff0d8"),
		"paredes": [Color("e8dcc4"), Color("dcd0bc")], "piso": &"tabua",
		"azulejo": Color("c8b48c"),
		"vitrine": [P.RELOGIOS, P.BIJUTERIAS], "fundo": [P.RELOGIOS, P.RELOGIOS],
		"lados": [P.RELOGIOS, P.BIJUTERIAS], "relogios": true, "equipe": ["o relojoeiro"],
		"profissoes": ["RELOJOEIRO"], "clientes": Vector2i(1, 1),
		"venda": [&"bateria"], "servico": &"hora"},
]


## Este chunk tem loja? Quadra comercial, fora do bar, da loja de conveniencia,
## da casa da fumaca e da celula da praca (ancorada, BarVivo.tem_bar).
static func tem_loja(cx: int, cz: int, quadra: Dictionary, porta: Dictionary) -> bool:
	if not ativo or not FachadaViva.ativo or bool(quadra["casa"]):
		return false
	if int(quadra["distrito"]) != MalhaUrbana.Distrito.COMERCIAL:
		return false
	if not porta.is_empty() and StringName(porta.get("interior", &"")) in [&"bar", &"mercado",
			&"casa_fumaca"]:
		return false
	if Serpentina.celula_do_chunk(cx, cz) == Vector2i(1, -1):
		return false
	if BarVivo.tem_bar(cx, cz, quadra, porta):
		return false
	# Outro primo que BarVivo (53, 29): os dois sorteios nao andam juntos.
	return posmod(cx * 37 + cz * 71 + 5, UMA_EM) == 0


## O ramo da loja do chunk. Vizinhos saem de ramos diferentes: o passo em x e em
## z e primo com 16, e a padaria nao se repete na esquina seguinte.
static func ramo_de(cx: int, cz: int) -> int:
	return posmod(cx * 5 + cz * 11 + (cx * cz) % 3, RAMOS.size())


## O plano da loja: ramo, cor e as escolhas que a fachada (ComercioVivo) e o
## salao (KitLoja) tem de fazer IGUAL — o lado da porta de vidro, a largura da
## boca. Sem rng: sai de (cx, cz).
static func plano(cx: int, cz: int, larg: float) -> Dictionary:
	var k := ramo_de(cx, cz)
	var r: Dictionary = RAMOS[k]
	var h := posmod(cx * 7919 + cz * 104729, 1000003)
	var paredes: Array = r["paredes"]
	var boca := clampf(larg * 0.5, 2.6, 3.6)
	if r["fachada"] == &"vitrine":
		boca = clampf(larg - 2.4, 2.8, 4.2)
	return {
		"ramo": k,
		"id": r["id"],
		"titulo": r["titulo"],
		"boca": boca,
		"lado_porta": -1.0 if h % 2 == 0 else 1.0,
		"parede": paredes[h % paredes.size()],
		"porta_w": 1.1,
		"semente": 91000 + cx * 613 + cz * 1277,
	}


## A celula de produto no atlas (4 x 8, celulas 2:1).
static func uv_produto(celula: int) -> Rect2:
	return Rect2(float(celula % 4) * 0.25, float(celula / 4) * 0.125, 0.25, 0.125)


## A celula do cartaz de parede (4 x 4).
static func uv_cartaz(celula: int) -> Rect2:
	return Rect2(float(celula % 4) * 0.25, float(celula / 4) * 0.25, 0.25, 0.25)
