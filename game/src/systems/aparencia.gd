## Como uma ficha do registro civil vira um corpo.
##
## O gerador de gente nao sorteia nada por conta propria: le a ficha e deriva.
## Isso importa mais do que parece. A foto do documento, o retrato na agenda do
## celular e o sujeito de casaco marrom parado na esquina precisam ser a MESMA
## pessoa, e a unica forma de garantir isso sem guardar nada e todos os tres
## saírem da mesma funcao pura do id.
##
## Onde a variacao mora
## --------------------
## Duas fontes, e nenhuma delas custa arquivo:
##
##   celula do atlas   rosto, cabelo, padrao de camisa, corte de calca
##   cor de vertice    tom de pele, cor de cabelo, cor de cada peca de roupa
##
## Oito rostos vezes oito cabelos vezes oito camisas vezes oito calcas ja da 4096
## silhuetas; com as paletas de cor a conta passa de um milhao de combinacoes
## visiveis. E ainda assim tudo isso e UMA textura de 256x256 e UM material, que
## e o que permite dez pedestres na tela sem estourar o teto de draw call.
##
## A paleta e suja de proposito. A cidade e noturna, iluminada a sodio e coberta
## de nevoa; roupa saturada vira mancha de cor flutuando na neblina e denuncia
## que aquilo e um personagem colado por cima do cenario.
class_name Aparencia
extends RefCounted

## Espelho de tools/gerar_npc.py. Celulas de 32 px numa grade de 8 por 8.
const CELULA := 32
const GRADE := 8
const ATLAS := 256.0

const LINHA_ROSTO_M := 0
const LINHA_ROSTO_F := 1
const LINHA_PECAS := 2
const LINHA_CABELO := 3
const LINHA_CAMISA := 4
const LINHA_COSTAS := 5
const LINHA_CALCA := 6
const LINHA_CASACO := 7

const VARIANTES := 8

## Colunas da linha de pecas soltas.
const PECA_PERFIL_M := 0
const PECA_PERFIL_F := 1
const PECA_NUCA := 2
const PECA_MAO := 3
const PECA_MANGA := 4
const PECA_SAPATO := 5   ## 5, 6 e 7

## Tons de pele. Sao TINTS: multiplicam uma celula desenhada em bege quase
## branco, entao o valor aqui e mais claro do que o tom final na tela.
const PELES: Array[Color] = [
	Color("fff0e2"), Color("f2d9bd"), Color("e0bb95"), Color("c69468"),
	Color("a06f45"), Color("7d5233"), Color("5d3b25"),
]

const CABELOS: Array[Color] = [
	Color("221c18"), Color("2e2119"), Color("4a3320"), Color("6b4526"),
	Color("8a5a2c"), Color("a8702f"), Color("c9a05a"), Color("6a5f56"),
]

## Cabelo de quem passou dos cinquenta. Entra por cima da paleta normal, com
## chance crescente: sem isso a cidade fica cheia de senhores de cabelo preto.
const CABELOS_GRISALHOS: Array[Color] = [
	Color("9a948c"), Color("b8b2aa"), Color("d2cec8"), Color("7c766f"),
]

## Roupa. Tudo dessaturado e escuro: e o que sobrevive a nevoa sem virar mancha.
## A faixa de VALOR importa mais que a de matiz. Numa rua de nevoa, o que
## distingue duas pessoas a vinte metros e uma ser clara e a outra escura; duas
## cores diferentes com o mesmo brilho viram a mesma mancha cinza. Por isso a
## paleta vai do quase preto ao quase branco de proposito, com poucos tons no
## meio — a primeira versao ficou toda entre 0,3 e 0,6 e a captura mostrou cinco
## pessoas indistinguiveis lado a lado.
const ROUPAS: Array[Color] = [
	Color("26282b"), Color("2f3a33"), Color("3a3330"), Color("4c5158"),
	Color("5a3f38"), Color("6f6a60"), Color("7a6a58"), Color("5a5f52"),
	Color("8a7c6c"), Color("3f4750"), Color("9c9384"), Color("5c6470"),
	Color("b3ab99"), Color("63524a"), Color("c8c2b0"), Color("2b3138"),
]

const CALCAS: Array[Color] = [
	Color("3c4048"), Color("4a443c"), Color("22262b"), Color("6b6154"),
	Color("434c56"), Color("8a8071"), Color("38352f"), Color("515b62"),
]

const SAPATOS: Array[Color] = [
	Color("2b2724"), Color("3a3330"), Color("4a4038"), Color("232629"),
]


## Retangulo de UV de uma celula, em 0 a 1.
##
## Encolhido meio texel de cada lado. Sem essa margem a interpolacao afim leva a
## coordenada da borda para dentro da celula vizinha e aparece uma linha de
## cabelo em volta do rosto — o mesmo problema de sangramento de atlas de sempre,
## que num atlas de gente da em costura na cara.
static func uv_da_celula(coluna: int, linha: int) -> Rect2:
	var x := (float(coluna) * CELULA + 0.5) / ATLAS
	var y := (float(linha) * CELULA + 0.5) / ATLAS
	var lado := (float(CELULA) - 1.0) / ATLAS
	return Rect2(x, y, lado, lado)


static func _h(id: int, canal: int) -> int:
	var x := (id * 2246822519) ^ (canal * 3266489917) ^ 0x85EBCA6B
	x = (x ^ (x >> 13)) * 668265263
	x = x ^ (x >> 16)
	return absi(x) if x != -9223372036854775808 else 3


static func _escolher(lista: Array, id: int, canal: int) -> Variant:
	return lista[_h(id, canal) % lista.size()]


## Corpo de uma ficha do registro. Funcao pura: mesma ficha, mesma pessoa.
static func de_ficha(ficha: Dictionary) -> Dictionary:
	var id := int(ficha["id"])
	var feminino := StringName(ficha["sexo"]) == &"F"
	var idade := int(ficha["idade"])

	# Altura. A faixa e estreita de proposito: gente de dois metros ao lado de
	# gente de um e meio le como erro de escala, nao como variedade.
	var base := 1.60 if feminino else 1.72
	var altura := base + float(_h(id, 1) % 13 - 6) * 0.012
	if idade < 17:
		# Crianca e adolescente so aparecem em ficha, nao na calcada, mas a foto
		# do documento precisa sair certa.
		altura *= clampf(0.56 + float(idade) * 0.026, 0.56, 1.0)
	if idade > 68:
		altura -= 0.035

	# Grisalho depois dos cinquenta e dois, e crescendo devagar. A primeira
	# versao usava quarenta e seis e crescia a 3% ao ano: metade da rua saia de
	# cabelo branco, porque a faixa etaria do registro concentra gente de
	# cinquenta e poucos. O que se ve na captura e uma cidade de idosos.
	var grisalho := idade > 52 and _h(id, 2) % 100 < mini(72, (idade - 50) * 2)
	var cabelo_cor: Color = (_escolher(CABELOS_GRISALHOS, id, 3) if grisalho
		else _escolher(CABELOS, id, 4))

	# Calvicie: so homem, so depois dos trinta, e crescendo com a idade.
	var calvo := (not feminino) and idade > 32 and _h(id, 5) % 100 < (idade - 28)

	var comprimento := 0
	if feminino:
		comprimento = [0, 1, 1, 2, 2][_h(id, 6) % 5]
	else:
		comprimento = [0, 0, 0, 1][_h(id, 6) % 4]

	var usa_casaco := _h(id, 7) % 100 < 42
	var saia := feminino and _h(id, 8) % 100 < 28

	return {
		"altura": altura,
		# Largura de ombro e de quadril. E o que separa a silhueta masculina da
		# feminina a quinze metros, onde nao ha rosto nem cabelo que se leia.
		"ombro": (0.36 if feminino else 0.42) * (0.94 + float(_h(id, 9) % 7) * 0.02),
		"quadril": (0.34 if feminino else 0.30) * (0.96 + float(_h(id, 10) % 5) * 0.02),
		"corpulencia": 0.90 + float(_h(id, 11) % 9) * 0.035,
		# Porte, de 0 (magro) a 1 (gordo). Deriva da corpulencia sorteada para
		# que NPC e jogador leiam a mesma chave; a tela de criacao mexe nela
		# diretamente.
		"gordura": clampf(float(_h(id, 11) % 9) / 8.0, 0.0, 1.0),
		"chapeu_tipo": 1 + _h(id, 28) % 4,
		"pele": _escolher(PELES, id, 12),
		"rosto": _h(id, 13) % VARIANTES,
		"linha_rosto": LINHA_ROSTO_F if feminino else LINHA_ROSTO_M,
		"perfil": PECA_PERFIL_F if feminino else PECA_PERFIL_M,
		"cabelo": _h(id, 14) % VARIANTES,
		"cabelo_cor": cabelo_cor,
		"cabelo_comprimento": comprimento,
		"calvo": calvo,
		"camisa": _h(id, 15) % VARIANTES,
		"camisa_cor": _escolher(ROUPAS, id, 16),
		"casaco": usa_casaco,
		"casaco_cel": _h(id, 17) % VARIANTES,
		"casaco_cor": _escolher(ROUPAS, id, 18),
		"calca": _h(id, 19) % VARIANTES,
		"calca_cor": _escolher(CALCAS, id, 20),
		"saia": saia,
		"sapato": PECA_SAPATO + _h(id, 21) % 3,
		"sapato_cor": _escolher(SAPATOS, id, 22),
		"chapeu": (not feminino) and _h(id, 23) % 100 < 16,
		"chapeu_cor": _escolher(ROUPAS, id, 24),
		# Cadencia e passada. Gente que anda toda no mesmo ritmo le como fila de
		# clones mesmo com roupa diferente; o passo e o que quebra isso de longe.
		"passo": 0.78 + float(_h(id, 25) % 11) * 0.045,
		"cadencia": 0.86 + float(_h(id, 26) % 9) * 0.05,
		# Altura da voz. Grave para corpo grande, agudo para corpo pequeno, com
		# folga: e o que faz a fala sair da pessoa e nao do sistema de audio.
		"voz": (1.28 if feminino else 0.92) - (altura - base) * 0.9
			+ float(_h(id, 27) % 9 - 4) * 0.018,
	}


# --- ajustes do jogador -----------------------------------------------------

## O que a tela de criacao deixa mexer, e a faixa de cada coisa.
##
## O NPC nao usa nada disto: a ficha dele decide tudo. Isto e so para o jogador,
## que e a unica pessoa da cidade que escolhe a propria cara — e mesmo ele nao
## escolhe o numero, a data nem a filiacao, que continuam saindo do registro.
const AJUSTES: Array[Dictionary] = [
	{"chave": &"rosto", "rotulo": "ROSTO", "tipo": "celula", "quantos": VARIANTES},
	{"chave": &"pele", "rotulo": "PELE", "tipo": "cor", "paleta": "PELES"},
	{"chave": &"cabelo", "rotulo": "CABELO", "tipo": "celula", "quantos": VARIANTES},
	{"chave": &"cabelo_cor", "rotulo": "COR DO CABELO", "tipo": "cor",
		"paleta": "CABELOS"},
	{"chave": &"camisa", "rotulo": "ROUPA", "tipo": "celula", "quantos": VARIANTES},
	{"chave": &"camisa_cor", "rotulo": "COR DA ROUPA", "tipo": "cor",
		"paleta": "ROUPAS"},
	{"chave": &"casaco_usa", "rotulo": "AGASALHO", "tipo": "lista",
		"itens": ["SEM", "COM"]},
	{"chave": &"casaco_cel", "rotulo": "MODELO", "tipo": "celula",
		"quantos": VARIANTES},
	{"chave": &"casaco_cor", "rotulo": "COR DO AGASALHO", "tipo": "cor",
		"paleta": "ROUPAS"},
	{"chave": &"calca", "rotulo": "CALCA", "tipo": "celula", "quantos": VARIANTES},
	{"chave": &"calca_cor", "rotulo": "COR DA CALCA", "tipo": "cor",
		"paleta": "CALCAS"},
	{"chave": &"chapeu_tipo", "rotulo": "CHAPEU", "tipo": "lista",
		"itens": ["NENHUM", "BONE", "TOUCA", "CHAPEU", "GORRO"]},
	{"chave": &"altura", "rotulo": "ALTURA", "tipo": "faixa",
		"minimo": 1.50, "maximo": 1.94},
	{"chave": &"gordura", "rotulo": "PORTE", "tipo": "faixa",
		"minimo": 0.0, "maximo": 1.0},
]


static func paleta(nome: String) -> Array[Color]:
	match nome:
		"PELES":
			return PELES
		"CABELOS":
			return CABELOS + CABELOS_GRISALHOS
		"CALCAS":
			return CALCAS
		_:
			return ROUPAS


## Aplica as escolhas do jogador por cima da aparencia sorteada.
##
## Por cima, e nao no lugar: o que o jogador nao mexeu continua vindo da ficha.
## Assim a tela de criacao abre com uma pessoa PRONTA — sorteada pelo registro,
## como todas as outras — e nao com um manequim cinza que obriga a escolher onze
## coisas antes de comecar a jogar.
static func com_ajustes(base: Dictionary, ajustes: Dictionary) -> Dictionary:
	var saida := base.duplicate(true)
	for chave: StringName in ajustes:
		saida[chave] = ajustes[chave]
	# Quem manda no agasalho e o interruptor da aba de agasalho.
	#
	# Antes daqui a regra era: mexeu na camisa, tira o casaco. Ela existia porque
	# o jogador nao TINHA como escolher casaco — a linha de casacos do atlas
	# estava pronta e nenhuma tela oferecia — entao mexer na camisa por baixo de
	# um casaco sorteado nao mudava nada na tela e parecia bug. Com a aba de
	# agasalho no ar, a escolha explicita ganha: sem ela, ligar um casaco e
	# depois trocar de camisa apagaria o casaco que o jogador acabou de vestir.
	if ajustes.has(&"casaco_usa"):
		saida["casaco"] = int(ajustes[&"casaco_usa"]) > 0
	elif ajustes.has(&"camisa"):
		saida["casaco"] = false
	if ajustes.has(&"chapeu_tipo"):
		saida["chapeu"] = int(ajustes[&"chapeu_tipo"]) > 0
	return saida


## Ajustes iniciais: o que a pessoa sorteada ja e. E o que a tela mostra quando
## abre, para o jogador ajustar em vez de montar do zero.
static func ajustes_de(a: Dictionary) -> Dictionary:
	return {
		&"rosto": int(a["rosto"]),
		&"pele": a["pele"],
		&"cabelo": int(a["cabelo"]),
		&"cabelo_cor": a["cabelo_cor"],
		&"camisa": int(a["camisa"]),
		# A camisa e a camisa. Antes ela vinha com a cor do CASACO quando a pessoa
		# sorteada usava um, e o jogador mexia em "COR DA ROUPA" para ver a cor do
		# casaco mudar — dois campos escrevendo na mesma coisa.
		&"camisa_cor": a["camisa_cor"],
		&"casaco_usa": 1 if bool(a["casaco"]) else 0,
		&"casaco_cel": int(a.get("casaco_cel", 0)),
		&"casaco_cor": a["casaco_cor"],
		&"calca": int(a["calca"]),
		&"calca_cor": a["calca_cor"],
		&"chapeu_tipo": 1 if bool(a.get("chapeu", false)) else 0,
		&"altura": float(a["altura"]),
		&"gordura": float(a.get("gordura", 0.5)),
	}


## Cor final da pele na tela, para o retrato do documento. O 3D chega nela pelo
## shader; o retrato e desenhado em CPU e precisa do resultado ja pronto.
const BEGE_DA_CELULA := Color(0.933, 0.871, 0.808)

static func pele_na_tela(a: Dictionary) -> Color:
	var t: Color = a["pele"]
	return Color(t.r * BEGE_DA_CELULA.r, t.g * BEGE_DA_CELULA.g,
		t.b * BEGE_DA_CELULA.b)
