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
## O atlas NAO e mais quadrado: 256 de largura por 288 de altura, nove linhas.
##
## A nona linha e de gente com nome, e enquanto as duas medidas eram a mesma
## constante `uv_da_celula` dividia o Y por 256 e toda a UV vertical saia 12,5%
## errada — a cara de cada pedestre pegava um pedaco da linha de baixo.
const ATLAS_X := 256.0
## Doze linhas desde a criacao de personagem: 9 e 10 sao os rostos de estudio,
## 11 as barbas em recorte. Ver tools/gerar_npc_criacao.py.
const ATLAS_Y := 384.0

const LINHA_ROSTO_M := 0
const LINHA_ROSTO_F := 1
const LINHA_PECAS := 2
const LINHA_CABELO := 3
const LINHA_CAMISA := 4
const LINHA_COSTAS := 5
const LINHA_CALCA := 6
const LINHA_CASACO := 7
## Linha 8: gente com NOME.
##
## Uma pessoa especifica nao cabe no sorteio. O rosto sorteado poe oculos em 22%
## dos casos e barba por fazer em 45%, e nenhum dos dois se escolhe; Helmer usa
## oculos redondos e bigode SEMPRE, e alguem que as vezes aparece sem oculos nao
## e a mesma pessoa. Ver tools/gerar_npc.py.
const LINHA_ELENCO := 8
## Rostos de estudio: desenhados a mao, LIMPOS de oculos e barba, com as
## feicoes sempre nas mesmas linhas de pixel. Sao os rostos 8 a 15 da criacao —
## os oito primeiros continuam sendo os da cidade.
const LINHA_ESTUDIO_M := 9
const LINHA_ESTUDIO_F := 10
## Barbas em recorte, tingidas pela cor do cabelo e coladas por cima da cara.
const LINHA_BARBA := 11

const ELENCO_ROSTO_HELMER := 0
const ELENCO_ROSTO_JOTA := 1
const ELENCO_PERFIL_HELMER := 2
const ELENCO_PERFIL_JOTA := 3
const ELENCO_PELE_ESPINHOS := 4
const ELENCO_NUCA_ESPINHOS := 5
const ELENCO_CABELO_CACHEADO := 6

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

## Calcado que so o jogador escolhe. O sorteio da rua continua nos quatro tons
## de cima; o tenis branco e a bota de couro claro sao escolha, nao estatistica.
const SAPATOS_EXTRA: Array[Color] = [
	Color("c8c2b0"), Color("9c9384"), Color("7a5a3a"), Color("5a3f38"),
	Color("6f2a24"), Color("3f4750"),
]

# --- modelos de peca --------------------------------------------------------
#
# A celula do atlas e o PADRAO do tecido; o modelo e a FORMA da peca, e forma e
# geometria (ver `Vestuario`). Zero e sempre o que a cidade ja usava, entao
# ninguem na rua muda por causa destas tabelas.
const CAMISA_ESTILOS: Array[String] = ["BASICA", "REGATA", "SOCIAL", "POLO",
	"MOLETOM", "GOLA ALTA"]
const CAMISA_REGATA := 1
const CAMISA_SOCIAL := 2
const CAMISA_POLO := 3
const CAMISA_MOLETOM := 4
const CAMISA_GOLA_ALTA := 5

## O zero e "sem agasalho". Na aparencia montada o modelo mora em `casaco_tipo`
## e a presenca em `casaco`, como a cidade ja lia.
const CASACO_ESTILOS: Array[String] = ["NENHUM", "JAQUETA", "COURO", "SOBRETUDO",
	"CORTA-VENTO", "COLETE", "BLAZER"]
const CASACO_JAQUETA := 1
const CASACO_COURO := 2
const CASACO_SOBRETUDO := 3
const CASACO_CORTA_VENTO := 4
const CASACO_COLETE := 5
const CASACO_BLAZER := 6

const CALCA_ESTILOS: Array[String] = ["CALCA", "CARGO", "JOGGER", "BERMUDA",
	"SAIA", "SAIA LONGA"]
const CALCA_CARGO := 1
const CALCA_JOGGER := 2
const CALCA_BERMUDA := 3
const CALCA_SAIA := 4
const CALCA_SAIA_LONGA := 5

const SAPATO_ESTILOS: Array[String] = ["TENIS", "CANO ALTO", "BOTA", "SOCIAL",
	"CHINELO"]
const SAPATO_CANO_ALTO := 1
const SAPATO_BOTA := 2
const SAPATO_SOCIAL := 3
const SAPATO_CHINELO := 4

const CHAPEU_ESTILOS: Array[String] = ["NENHUM", "BONE", "TOUCA", "CHAPEU",
	"GORRO", "BOINA", "BONE VIRADO", "FAIXA"]

const OCULOS_ESTILOS: Array[String] = ["NENHUM", "GRAU", "ESCURO", "ARO FINO",
	"ESPORTIVO"]
const OCULOS_GRAU := 1
const OCULOS_ESCURO := 2
const OCULOS_ARO_FINO := 3
const OCULOS_ESPORTIVO := 4

## O corte, que e SILHUETA: o Corpo ja sabia fazer os seis (comprimento de
## tras, coque, tufos de cacho, careca), e a tela so deixava trocar o desenho
## dos fios. Na aparencia montada ele vira as chaves que o Corpo le.
const PENTEADOS: Array[String] = ["CURTO", "MEDIO", "LONGO", "COQUE", "CACHEADO",
	"RASPADO"]
const PENTEADO_COQUE := 3
const PENTEADO_CACHEADO := 4
const PENTEADO_RASPADO := 5

## Zero e sem barba; o resto e a coluna da linha de barbas mais um.
const BARBA_ESTILOS: Array[String] = ["NENHUMA", "POR FAZER", "BIGODE",
	"CAVANHAQUE", "CHEIA", "ESPESSA"]
const BARBA_CHEIA := 4
const BARBA_ESPESSA := 5

## Rostos da criacao: os oito da cidade e os oito de estudio.
const ROSTOS_NA_CRIACAO := VARIANTES * 2


## Retangulo de UV de uma celula, em 0 a 1.
##
## Encolhido meio texel de cada lado. Sem essa margem a interpolacao afim leva a
## coordenada da borda para dentro da celula vizinha e aparece uma linha de
## cabelo em volta do rosto — o mesmo problema de sangramento de atlas de sempre,
## que num atlas de gente da em costura na cara.
static func uv_da_celula(coluna: int, linha: int) -> Rect2:
	var x := (float(coluna) * CELULA + 0.5) / ATLAS_X
	var y := (float(linha) * CELULA + 0.5) / ATLAS_Y
	return Rect2(x, y, (float(CELULA) - 1.0) / ATLAS_X,
		(float(CELULA) - 1.0) / ATLAS_Y)


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
		# A linha do perfil vem da ficha e nao mais fixa em LINHA_PECAS: e por
		# ela que o alargador de Helmer e o de Jota entram, sem geometria nova.
		"linha_perfil": LINHA_PECAS,
		"cabelo": _h(id, 14) % VARIANTES,
		# A linha do cabelo vem da ficha, como a do rosto e a do perfil: e por
		# ela que o cacho do Helmer entra sem gastar uma das oito celulas de
		# cabelo da cidade.
		"linha_cabelo": LINHA_CABELO,
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
		# Modelos de peca. Zero em tudo e a pessoa de sempre: a rua nao ganha
		# um triangulo por causa da criacao. O agasalho sorteado e a jaqueta.
		"camisa_estilo": 0,
		"casaco_tipo": CASACO_JAQUETA,
		"calca_estilo": 0,
		"sapato_estilo": 0,
		"oculos": 0,
		"barba": 0,
		# Cadencia e passada. Gente que anda toda no mesmo ritmo le como fila de
		# clones mesmo com roupa diferente; o passo e o que quebra isso de longe.
		"passo": 0.78 + float(_h(id, 25) % 11) * 0.045,
		"cadencia": 0.86 + float(_h(id, 26) % 9) * 0.05,
		# Altura da voz. Grave para corpo grande, agudo para corpo pequeno, com
		# folga: e o que faz a fala sair da pessoa e nao do sistema de audio.
		"voz": (1.28 if feminino else 0.92) - (altura - base) * 0.9
			+ float(_h(id, 27) % 9 - 4) * 0.018,
	}


# --- gente com nome ---------------------------------------------------------

## Os personagens fixos do jogo, e tudo que os faz serem eles.
##
## Por que isto existe em vez de uma ficha sorteada boa
## ----------------------------------------------------
## Todo o resto deste arquivo deriva a pessoa do id, e isso e o certo para uma
## cidade de cem milhoes de habitantes. Mas derivar quer dizer que ninguem
## escolheu: o rosto sai com oculos em 22% dos ids e com barba em 45%, e a
## combinacao "oculos redondo, bigode, cabelo armado" existe em algum id que
## ninguem sabe qual e.
##
## Helmer e Jota tem de ser as MESMAS pessoas em toda partida, em toda cidade e
## em todo save. Entao a ficha civil continua sendo sorteada — eles tem CPF,
## mae, endereco e identidade que confere, como qualquer um — e so a APARENCIA
## e escrita a mao por cima.
##
## O que cada chave faz aqui e o mesmo que faz em qualquer outra pessoa; a
## diferenca e que o valor foi escolhido e nao sorteado.
const ELENCO := {
	&"helmer": {
		"nome": "HELMER",
		# Cabelo preto CACHEADO. A celula e a do elenco, de tufos redondos, e o
		# cacho de verdade vem da geometria: seis tufos em volta da calota, que
		# sao o que quebra a silhueta. Ver Corpo._montar_cabelo.
		#
		# Tingir de preto uma das oito celulas de cabelo da cidade nao resolvia:
		# todas sao fio vertical, que e o desenho de cabelo liso, e liso escuro
		# continua lendo como liso.
		"cabelo": ELENCO_CABELO_CACHEADO,
		"linha_cabelo": LINHA_ELENCO,
		"cacheado": true,
		"cabelo_comprimento": 1,
		"cabelo_cor": Color("221c18"),
		"calvo": false,
		"pele": Color("e0bb95"),
		"rosto": ELENCO_ROSTO_HELMER,
		"linha_rosto": LINHA_ELENCO,
		"perfil": ELENCO_PERFIL_HELMER,
		"linha_perfil": LINHA_ELENCO,
		# Regata listrada clara. A camisa 3 e impar, entao o braco sai de manga
		# curta — que e o que a regata precisa.
		"camisa": 3,
		"camisa_cor": Color("b3ab99"),
		"casaco": false,
		"calca": 4,
		"calca_cor": Color("434c56"),
		"chapeu": false,
		"altura": 1.76,
		"gordura": 0.38,
		"voz": 0.96,
	},
	&"jota": {
		"nome": "JOTA",
		# Castanho puxado para tras. A celula 6 tem as linhas horizontais, que
		# leem como cabelo penteado e nao como franja.
		# Cabelo longo, preso em COQUE. A celula 6 e a de fio horizontal, que e
		# a que le como cabelo penteado para tras.
		"cabelo": 6,
		# Zero de comprimento solto, e o coque por cima. Cabelo longo preso nao
		# cai dos lados — se caisse nao estaria preso —, e e justamente o
		# contrario disso que deixa a orelha e o alargador vermelho a mostra.
		"cabelo_comprimento": 0,
		"coque": true,
		"cabelo_cor": Color("6b4526"),
		"calvo": false,
		"pele": Color("fff0e2"),
		"rosto": ELENCO_ROSTO_JOTA,
		"linha_rosto": LINHA_ELENCO,
		"perfil": ELENCO_PERFIL_JOTA,
		"linha_perfil": LINHA_ELENCO,
		"camisa": 1,
		"camisa_cor": Color("26282b"),
		"casaco": false,
		"calca": 2,
		"calca_cor": Color("22262b"),
		"chapeu": false,
		# Um e noventa. Fura de proposito a faixa estreita que `de_ficha` usa —
		# ali a regra existe para a rua nao virar um circo de escalas, e aqui a
		# altura E o tracо: Jota e o alto, e ele so e o alto ao lado de Helmer.
		"altura": 1.90,
		"gordura": 0.30,
		"voz": 0.88,
		# Espinhos pretos subindo do peito ate a mao. Ver Corpo._construir: a
		# celula tatuada entra no pescoco, no antebraco e na mao.
		"tatuagem": true,
	},
}


static func personagem(chave: StringName) -> Dictionary:
	return ELENCO.get(chave, {})


static func nome_do_personagem(chave: StringName) -> String:
	return String(personagem(chave).get("nome", ""))


## A aparencia sorteada, com o personagem escrito por cima.
##
## Por cima e nao no lugar, pela mesma razao dos ajustes do jogador: o que o
## elenco nao diz — passo, cadencia, sapato, largura de quadril — continua
## vindo da ficha, e continua sendo diferente de cidade para cidade. E so a
## CARA que e fixa.
static func de_personagem(base: Dictionary, chave: StringName) -> Dictionary:
	var quem := personagem(chave)
	if quem.is_empty():
		return base
	var saida := base.duplicate(true)
	for campo: String in quem:
		if campo == "nome":
			continue
		saida[campo] = quem[campo]
	return saida


# --- ajustes do jogador -----------------------------------------------------

## O que a tela de criacao deixa mexer, e a faixa de cada coisa.
##
## O NPC nao usa nada disto: a ficha dele decide tudo. Isto e so para o jogador,
## que e a unica pessoa da cidade que escolhe a propria cara — e mesmo ele nao
## escolhe o numero, a data nem a filiacao, que continuam saindo do registro.
const AJUSTES: Array[Dictionary] = [
	{"chave": &"rosto", "rotulo": "ROSTO", "tipo": "celula",
		"quantos": ROSTOS_NA_CRIACAO},
	{"chave": &"pele", "rotulo": "PELE", "tipo": "cor", "paleta": "PELES"},
	{"chave": &"barba", "rotulo": "BARBA", "tipo": "estilo",
		"itens": BARBA_ESTILOS},
	{"chave": &"penteado", "rotulo": "CORTE", "tipo": "estilo",
		"itens": PENTEADOS},
	{"chave": &"cabelo", "rotulo": "FIOS", "tipo": "celula", "quantos": VARIANTES},
	{"chave": &"cabelo_cor", "rotulo": "COR DO CABELO", "tipo": "cor",
		"paleta": "CABELOS"},
	{"chave": &"camisa_estilo", "rotulo": "ROUPA", "tipo": "estilo",
		"itens": CAMISA_ESTILOS},
	{"chave": &"camisa", "rotulo": "ESTAMPA", "tipo": "celula", "quantos": VARIANTES},
	{"chave": &"camisa_cor", "rotulo": "COR DA ROUPA", "tipo": "cor",
		"paleta": "ROUPAS"},
	# O modelo do agasalho e tambem o interruptor: NENHUM tira. Eram dois campos
	# (SEM/COM, e o modelo embaixo), e com a forma da peca a aba nao cabia.
	{"chave": &"casaco_estilo", "rotulo": "AGASALHO", "tipo": "estilo",
		"itens": CASACO_ESTILOS},
	{"chave": &"casaco_cel", "rotulo": "PADRAO", "tipo": "celula",
		"quantos": VARIANTES},
	{"chave": &"casaco_cor", "rotulo": "COR DO AGASALHO", "tipo": "cor",
		"paleta": "ROUPAS"},
	{"chave": &"calca_estilo", "rotulo": "CALCA", "tipo": "estilo",
		"itens": CALCA_ESTILOS},
	{"chave": &"calca", "rotulo": "TECIDO", "tipo": "celula", "quantos": VARIANTES},
	{"chave": &"calca_cor", "rotulo": "COR DA CALCA", "tipo": "cor",
		"paleta": "CALCAS"},
	{"chave": &"sapato_estilo", "rotulo": "CALCADO", "tipo": "estilo",
		"itens": SAPATO_ESTILOS},
	{"chave": &"sapato_cor", "rotulo": "COR DO CALCADO", "tipo": "cor",
		"paleta": "SAPATOS"},
	{"chave": &"chapeu_tipo", "rotulo": "CHAPEU", "tipo": "estilo",
		"itens": CHAPEU_ESTILOS},
	{"chave": &"chapeu_cor", "rotulo": "COR DO CHAPEU", "tipo": "cor",
		"paleta": "ROUPAS"},
	{"chave": &"oculos", "rotulo": "OCULOS", "tipo": "estilo",
		"itens": OCULOS_ESTILOS},
	{"chave": &"altura", "rotulo": "ALTURA", "tipo": "faixa",
		"minimo": 1.50, "maximo": 1.94},
	{"chave": &"gordura", "rotulo": "PORTE", "tipo": "faixa",
		"minimo": 0.0, "maximo": 1.0},
	{"chave": &"ombro", "rotulo": "OMBROS", "tipo": "faixa",
		"minimo": 0.32, "maximo": 0.50},
]


static func paleta(nome: String) -> Array[Color]:
	match nome:
		"PELES":
			return PELES
		"CABELOS":
			return CABELOS + CABELOS_GRISALHOS
		"CALCAS":
			return CALCAS
		"SAPATOS":
			return SAPATOS + SAPATOS_EXTRA
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
	#
	# `casaco_estilo` e o campo de hoje; `casaco_usa` e o dos saves antigos.
	if ajustes.has(&"casaco_estilo"):
		var estilo := int(ajustes[&"casaco_estilo"])
		saida["casaco"] = estilo > 0
		saida["casaco_tipo"] = maxi(CASACO_JAQUETA, estilo)
	elif ajustes.has(&"casaco_usa"):
		saida["casaco"] = int(ajustes[&"casaco_usa"]) > 0
	elif ajustes.has(&"camisa"):
		saida["casaco"] = false
	if ajustes.has(&"chapeu_tipo"):
		saida["chapeu"] = int(ajustes[&"chapeu_tipo"]) > 0
	if ajustes.has(&"penteado"):
		var p := int(ajustes[&"penteado"])
		saida["calvo"] = p == PENTEADO_RASPADO
		saida["coque"] = p == PENTEADO_COQUE
		saida["cacheado"] = p == PENTEADO_CACHEADO
		saida["cabelo_comprimento"] = (clampi(p, 0, 2) if p <= 2
			else (1 if p == PENTEADO_CACHEADO else 0))
	if ajustes.has(&"calca_estilo"):
		var calca := int(ajustes[&"calca_estilo"])
		saida["saia"] = calca == CALCA_SAIA or calca == CALCA_SAIA_LONGA
	# Rosto 8 a 15 e de estudio: a mesma coluna, na linha de estudio do sexo da
	# ficha. O sexo vem da linha que o sorteio escolheu, que e o que a base sabe.
	if ajustes.has(&"rosto"):
		var r := int(ajustes[&"rosto"])
		var linha_base := int(base.get("linha_rosto", LINHA_ROSTO_M))
		var feminino := linha_base == LINHA_ROSTO_F or linha_base == LINHA_ESTUDIO_F
		saida["rosto"] = posmod(r, VARIANTES)
		if r >= VARIANTES:
			saida["linha_rosto"] = LINHA_ESTUDIO_F if feminino else LINHA_ESTUDIO_M
		else:
			saida["linha_rosto"] = LINHA_ROSTO_F if feminino else LINHA_ROSTO_M
	return saida


## Ajustes iniciais: o que a pessoa sorteada ja e. E o que a tela mostra quando
## abre, para o jogador ajustar em vez de montar do zero.
static func ajustes_de(a: Dictionary) -> Dictionary:
	var linha_rosto := int(a.get("linha_rosto", LINHA_ROSTO_M))
	var estudio := linha_rosto == LINHA_ESTUDIO_M or linha_rosto == LINHA_ESTUDIO_F
	var calca_estilo := int(a.get("calca_estilo", 0))
	if calca_estilo == 0 and bool(a.get("saia", false)):
		calca_estilo = CALCA_SAIA
	var penteado := clampi(int(a.get("cabelo_comprimento", 0)), 0, 2)
	if bool(a.get("calvo", false)):
		penteado = PENTEADO_RASPADO
	elif bool(a.get("coque", false)):
		penteado = PENTEADO_COQUE
	elif bool(a.get("cacheado", false)):
		penteado = PENTEADO_CACHEADO
	return {
		&"rosto": int(a["rosto"]) + (VARIANTES if estudio else 0),
		&"penteado": penteado,
		&"pele": a["pele"],
		&"cabelo": int(a["cabelo"]),
		&"cabelo_cor": a["cabelo_cor"],
		&"camisa": int(a["camisa"]),
		# A camisa e a camisa. Antes ela vinha com a cor do CASACO quando a pessoa
		# sorteada usava um, e o jogador mexia em "COR DA ROUPA" para ver a cor do
		# casaco mudar — dois campos escrevendo na mesma coisa.
		&"camisa_cor": a["camisa_cor"],
		&"casaco_estilo": (maxi(CASACO_JAQUETA, int(a.get("casaco_tipo", 1)))
			if bool(a["casaco"]) else 0),
		&"casaco_cel": int(a.get("casaco_cel", 0)),
		&"casaco_cor": a["casaco_cor"],
		&"calca": int(a["calca"]),
		&"calca_cor": a["calca_cor"],
		&"chapeu_tipo": (int(a.get("chapeu_tipo", 1))
			if bool(a.get("chapeu", false)) else 0),
		&"chapeu_cor": a.get("chapeu_cor", ROUPAS[5]),
		&"camisa_estilo": int(a.get("camisa_estilo", 0)),
		&"calca_estilo": calca_estilo,
		&"sapato_estilo": int(a.get("sapato_estilo", 0)),
		&"sapato_cor": a.get("sapato_cor", SAPATOS[0]),
		&"oculos": int(a.get("oculos", 0)),
		&"barba": int(a.get("barba", 0)),
		&"altura": float(a["altura"]),
		&"gordura": float(a.get("gordura", 0.5)),
		&"ombro": float(a.get("ombro", 0.42)),
	}


## Se o braco sai coberto. Corpo e maos de primeira pessoa leem daqui, para as
## duas nao discordarem de manga.
##
## A regra antiga continua no modelo BASICA: celula par e manga comprida. Os
## outros modelos dizem por si — regata nao tem manga, polo e curta, social,
## moletom e gola alta sao compridas. Agasalho cobre o braco, menos o colete.
static func manga_longa(a: Dictionary) -> bool:
	if bool(a.get("casaco", false)) and int(a.get("casaco_tipo", 1)) != CASACO_COLETE:
		return true
	match int(a.get("camisa_estilo", 0)):
		CAMISA_REGATA, CAMISA_POLO:
			return false
		CAMISA_SOCIAL, CAMISA_MOLETOM, CAMISA_GOLA_ALTA:
			return true
	return int(a.get("camisa", 0)) % 2 == 0


## Cor do que cobre o braco: o agasalho, menos quando e colete.
static func cor_da_manga(a: Dictionary) -> Color:
	if bool(a.get("casaco", false)) and int(a.get("casaco_tipo", 1)) != CASACO_COLETE:
		return a["casaco_cor"]
	return a["camisa_cor"]


## Cor final da pele na tela, para o retrato do documento. O 3D chega nela pelo
## shader; o retrato e desenhado em CPU e precisa do resultado ja pronto.
const BEGE_DA_CELULA := Color(0.933, 0.871, 0.808)

static func pele_na_tela(a: Dictionary) -> Color:
	var t: Color = a["pele"]
	return Color(t.r * BEGE_DA_CELULA.r, t.g * BEGE_DA_CELULA.g,
		t.b * BEGE_DA_CELULA.b)
