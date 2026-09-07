## As doze pessoas possiveis, e o que cada uma responde.
##
## Por que personalidade e nao fala por NPC
## ----------------------------------------
## Escrever fala por pessoa nao escala: uma cidade infinita teria de ter texto
## infinito. E sortear frase solta de um saco comum tambem nao funciona — sai um
## bairro de gente esquizofrenica, cada linha de um humor diferente.
##
## O meio termo e este: doze temperamentos com voz propria, cada um com resposta
## sua para os mesmos tres assuntos que qualquer um responderia na rua, mais um
## assunto que so ele tem. O que faz duas conversas com o mesmo temperamento nao
## serem iguais e a FICHA entrar no texto: profissao, idade, sobrenome, endereco
## e a familia saem do registro civil e sao costurados na fala.
##
## Entao o desconfiado do quarteirao norte e o desconfiado da praca dizem as
## mesmas coisas sobre a nevoa e coisas diferentes sobre a propria vida — que e
## exatamente como gente de verdade conversa com estranho.
##
## Marcadores
## ----------
## O texto aceita {chave} e FalasNpc troca pelo dado da ficha:
##
##   {nome} {primeiro} {sobrenome} {profissao} {idade} {mae} {bairro}
##   {parente} {relacao} {natural}
class_name Personalidade
extends RefCounted

## Assuntos que qualquer pessoa na rua responde.
const ASSUNTOS_COMUNS: Array[StringName] = [&"nevoa", &"bairro", &"voce"]

## Cada entrada e um temperamento. `andar` multiplica a velocidade de caminhada
## e `voz` a afinacao: e o que faz o apressado passar por voce sem parar e o
## bebado arrastar a frase, sem uma linha de codigo especifica para nenhum dos
## dois.
const LISTA: Array[Dictionary] = [
	{
		"nome": "DESCONFIADO", "andar": 1.05, "voz": -0.06, "cadencia": 1.1,
		"saudacao": [
			"O que voce quer?",
			"Nao te conheco.",
			"Fala logo. Estou de saida.",
		],
		"documento": "Voce e da fiscalizacao? ...Tome. Devolve.",
		"despedida": ["Ja falei demais.", "Some daqui."],
		"nevoa": [
			"Nao pergunta pra mim. Pergunta pra quem trouxe isso.",
			"Alguem sabe. Alguem sempre sabe e nao fala.",
		],
		"bairro": [
			"Aqui era bom antes. Nao vou dizer antes de que.",
			"Tranca a porta. So isso.",
		],
		"voce": [
			"{profissao}. Ha {idade} anos aguentando o que aparece.",
			"Meu nome esta na minha carteira. Nao preciso repetir.",
		],
		"proprio": {
			"titulo": "VOCE VIU ALGUEM?",
			"linhas": [
				"Vi. Nao era gente.",
				"Estava parado onde o poste queimou.",
				"Quando eu olhei de novo, tinha andado tres metros. Sem passo.",
			],
		},
	},
	{
		"nome": "TAGARELA", "andar": 0.88, "voz": 0.05, "cadencia": 1.25,
		"saudacao": [
			"Ah, gracas a Deus, alguem! Voce tem um minuto?",
			"Oi! Oi. Voce tambem nao consegue dormir com isso la fora?",
		],
		"documento": "Claro, claro, olha so, ate a foto ficou horrivel, olha:",
		"despedida": ["Depois a gente continua!", "Apareca, viu?"],
		"nevoa": [
			"Comecou terca. Ou segunda. A dona {parente} diz que foi domingo.",
			"O fato e que ela nao molha. Ja passei a mao. Nao molha!",
			"E cheira a moeda velha. Ninguem mais sente isso? So eu?",
		],
		"bairro": [
			"Aqui todo mundo se conhece. Eu conheco, pelo menos.",
			"O do sobrado saiu com mala as tres da manha. Mala grande.",
			"Voltou sem a mala. Isso eu vi.",
		],
		"voce": [
			"Sou {profissao}, mas isso e o de menos, eu faco de tudo.",
			"{idade} anos, nascido em {natural}, familia toda de {sobrenome}.",
		],
		"proprio": {
			"titulo": "O QUE MAIS VOCE VIU?",
			"linhas": [
				"O radio. O radio pega uma voz as vezes.",
				"Ela repete numero. Sempre os mesmos, na mesma ordem.",
				"Anotei. Depois perdi o papel. Ou alguem levou.",
			],
		},
	},
	{
		"nome": "APRESSADO", "andar": 1.35, "voz": 0.02, "cadencia": 1.3,
		"saudacao": [
			"Rapido, por favor.",
			"Estou atrasado. Fala.",
		],
		"documento": "Toma. Rapido. Ja anotou?",
		"despedida": ["Tenho que ir.", "Chega. Licenca."],
		"nevoa": ["Nao tenho tempo pra nevoa.", "Se atrapalhasse eu tinha parado."],
		"bairro": [
			"Duas quadras. Trabalho, casa, trabalho.",
			"Nao olho pros lados faz uns dez anos.",
		],
		"voce": [
			"{profissao}. Turno da noite. Desde os dezenove.",
			"Todo dia o mesmo caminho. Se parar, atraso.",
		],
		"proprio": {
			"titulo": "PARA ONDE VOCE VAI?",
			"linhas": [
				"Trabalhar.",
				"...Nao lembro se hoje eu ja fui. Isso ta acontecendo.",
				"Deixa. Ja vou.",
			],
		},
	},
	{
		"nome": "MELANCOLICO", "andar": 0.78, "voz": -0.1, "cadencia": 0.82,
		"saudacao": [
			"...Ah. Oi.",
			"Desculpa, eu estava longe.",
		],
		"documento": "Se voce quiser ver. Nao serve mais pra muita coisa.",
		"despedida": ["Vai com cuidado.", "Ate."],
		"nevoa": [
			"Chegou junto com o resto.",
			"Nem foi a pior coisa dessa semana, pra ser sincero.",
		],
		"bairro": [
			"Morei nessa quadra a vida inteira. Nunca gostei.",
			"Agora que esvaziou, sinto falta do barulho.",
		],
		"voce": [
			"{profissao}. Fui, pelo menos. Faz tempo que nao chamam.",
			"{idade} anos. Minha mae, {mae}, ainda mora comigo. Acho.",
		],
		"proprio": {
			"titulo": "VOCE PRECISA DE AJUDA?",
			"linhas": [
				"Nao precisa. Obrigado.",
				"So nao apaga a luz da sua janela. E o que me faz continuar andando.",
			],
		},
	},
	{
		"nome": "GENTIL", "andar": 0.92, "voz": 0.04, "cadencia": 0.98,
		"saudacao": [
			"Boa noite, meu filho. Voce esta bem?",
			"Ai, que susto. Voce esta gelado, criatura.",
		],
		"documento": "Claro. Olha, a foto e antiga, ta?",
		"despedida": ["Deus te acompanhe.", "Se cuida, viu?"],
		"nevoa": [
			"Nao encosta nela mais que o necessario.",
			"Meu marido dizia que nevoa de rua vem do rio. Essa nao vem.",
		],
		"bairro": [
			"Tem gente boa aqui. Tinha, pelo menos.",
			"Se precisar de agua quente, bate na porta {parente}. Diz que fui eu.",
		],
		"voce": [
			"Sou {profissao} ha muitos anos. {idade}, se quer saber.",
			"Vim de {natural} com dezesseis. Nunca mais voltei.",
		],
		"proprio": {
			"titulo": "POSSO PEDIR UMA COISA?",
			"linhas": [
				"Pode, meu bem.",
				"Se voce passar na quadra do mercado, ve se a luz do fundo esta acesa.",
				"So isso. Se estiver acesa, esta tudo bem.",
			],
		},
	},
	{
		"nome": "BEBADO", "andar": 0.62, "voz": -0.14, "cadencia": 0.7,
		"saudacao": [
			"Ei... ei. Voce e real?",
			"Senta aqui. Nao, nao tem cadeira. Fica de pe mesmo.",
		],
		"documento": "Ta aqui... ta aqui... olha a minha cara nova. Bonito, ne.",
		"despedida": ["Vai... vai indo.", "Depois a gente bebe."],
		"nevoa": [
			"Eu gosto dela. Serio.",
			"Ela cobre as coisa feia. Cobre voce tambem, se ficar quieto.",
		],
		"bairro": [
			"Esse bairro me deve. Ninguem paga.",
			"Antes tinha um bar na esquina. Agora tem... isso ai.",
		],
		"voce": [
			"{profissao}, eu. Fui. Fui muita coisa.",
			"{idade} anos e uma cabeca que nao ajuda.",
		],
		"proprio": {
			"titulo": "VOCE ESTA BEM?",
			"linhas": [
				"Nunca estive.",
				"Mas escuta uma coisa, serio agora.",
				"Quando ela passa perto, o cachorro para de latir ANTES. Antes, entendeu?",
			],
		},
	},
	{
		"nome": "DEVOTO", "andar": 0.86, "voz": -0.02, "cadencia": 0.9,
		"saudacao": [
			"A paz. Voce esta protegido?",
			"Fica na luz, meu irmao. Fica na luz.",
		],
		"documento": "O documento e do mundo. Mas tome, se e o que voce precisa.",
		"despedida": ["Va em paz.", "Reza. Nem que seja baixinho."],
		"nevoa": [
			"Nao e castigo. Castigo tem motivo.",
			"Isso ai e outra coisa. Isso ai nao quer nada da gente. So esta.",
		],
		"bairro": [
			"A capela da quadra ficou aberta. Nao entra depois das nove.",
			"Nao pelo que tem dentro. Pelo que entra junto com voce.",
		],
		"voce": [
			"{profissao} de dia, vigia de alma de noite.",
			"Minha mae, {mae}, me ensinou a contar as luzes. Eu ainda conto.",
		],
		"proprio": {
			"titulo": "CONTAR AS LUZES?",
			"linhas": [
				"Todo poste da rua. Toda noite, o mesmo numero.",
				"Ontem tinha um a mais.",
				"Nao adianta procurar. Ele so aparece pra quem ja contou os outros.",
			],
		},
	},
	{
		"nome": "CINICO", "andar": 1.0, "voz": -0.04, "cadencia": 1.05,
		"saudacao": [
			"Deixa eu adivinhar: voce tambem nao sabe de nada.",
			"Otimo. Mais um perdido.",
		],
		"documento": "Ta. Confere. Todo mundo adora conferir documento agora.",
		"despedida": ["Boa sorte com isso.", "Ja perdi tempo demais."],
		"nevoa": [
			"Vao dizer que e vazamento. Sempre e vazamento.",
			"Semana que vem tem carro de som pedindo calma.",
		],
		"bairro": [
			"Trinta anos de imposto pra rua ficar assim.",
			"Reclamei na sub-prefeitura. Adivinha.",
		],
		"voce": [
			"{profissao}. Escrito na carteira, pelo menos.",
			"{idade} anos, e o unico documento que vale e o que te tiram na hora certa.",
		],
		"proprio": {
			"titulo": "VOCE NAO TEM MEDO?",
			"linhas": [
				"Tenho. So nao gosto de fazer cara de quem tem.",
				"Ontem eu vi uma coisa na esquina da avenida.",
				"E eu atravessei a rua pro outro lado, igual todo mundo. Igual voce faria.",
			],
		},
	},
	{
		"nome": "ASSUSTADO", "andar": 1.18, "voz": 0.09, "cadencia": 1.2,
		"saudacao": [
			"Nao chega perto! ...Desculpa. Desculpa.",
			"Voce e de verdade? Fala outra coisa. Fala.",
		],
		"documento": "Pega. Pega logo. Olha, sou eu, e o meu nome, ta vendo?",
		"despedida": ["Eu tenho que entrar.", "Nao me segue, por favor."],
		"nevoa": [
			"Ela chega mais perto quando voce olha pra ela.",
			"Nao. Serio. Testa. Nao, nao testa.",
		],
		"bairro": [
			"Tem uma porta no fim da quadra que nao era daquela cor.",
			"Ninguem lembra da porta. So eu.",
		],
		"voce": [
			"{primeiro}. {primeiro} {sobrenome}. Guarda esse nome, por favor.",
			"Se eu sumir, alguem tem que saber que eu existi.",
		],
		"proprio": {
			"titulo": "VOCE NAO VAI SUMIR",
			"linhas": [
				"O {parente} sumiu.",
				"E quando eu falo o nome dele, as pessoas fazem cara de quem nao entendeu a pergunta.",
				"Voce entendeu, ne? Voce entendeu.",
			],
		},
	},
	{
		"nome": "MANDAO", "andar": 0.95, "voz": -0.08, "cadencia": 0.95,
		"saudacao": [
			"Identifique-se.",
			"Circulando. Nao e hora de ficar parado na calcada.",
		],
		"documento": "Olha e devolve. Documento nao se empresta.",
		"despedida": ["Pode seguir.", "Nao quero ver voce aqui de novo."],
		"nevoa": [
			"E uma ocorrencia. Ocorrencia tem protocolo.",
			"O protocolo diz pra manter as pessoas em casa. Voce nao esta em casa.",
		],
		"bairro": [
			"Essa quadra e minha responsabilidade. Foi, por vinte e dois anos.",
			"Ninguem me tirou do posto. O posto e que fechou.",
		],
		"voce": [
			"{profissao}. Aposentado, se voce quiser ser tecnico.",
			"{idade} anos e nenhuma anotacao na ficha. Pode consultar.",
		],
		"proprio": {
			"titulo": "TEM REGISTRO DISSO?",
			"linhas": [
				"Tinha. Livro de ocorrencia, capa preta, na guarita.",
				"Fui buscar terca. A guarita estava la. O livro nao.",
				"E a pagina que eu escrevi na segunda... eu lembro dela. Lembro por fora.",
			],
		},
	},
	{
		"nome": "SONHADOR", "andar": 0.84, "voz": 0.06, "cadencia": 0.88,
		"saudacao": [
			"Voce tambem parou pra ver? A luz nela e bonita.",
			"Oi. Estava esperando alguem passar.",
		],
		"documento": "Ah, o retrato. Eu era outra pessoa nesse dia.",
		"despedida": ["Boa caminhada.", "Ate qualquer hora."],
		"nevoa": [
			"Ninguem fala do som que ela faz. Tem um som. Baixinho.",
			"Parece o mar, se o mar fosse do outro lado de uma parede.",
		],
		"bairro": [
			"Do alto do predio da esquina da pra ver onde ela acaba.",
			"Ou onde ela comeca. Nao da pra saber de que lado a gente esta.",
		],
		"voce": [
			"{profissao} por enquanto. Nao pra sempre.",
			"Vim de {natural}. Um dia eu volto, quando isso aqui resolver.",
		],
		"proprio": {
			"titulo": "O QUE VOCE QUERIA SER?",
			"linhas": [
				"Ninguem pergunta isso faz uns quinze anos.",
				"Eu desenhava predio. Predio que nao existia ainda.",
				"Sabe o mais engracado? Um deles apareceu. Na quadra da praca. Igualzinho.",
			],
		},
	},
	{
		"nome": "VIGARISTA", "andar": 1.08, "voz": 0.0, "cadencia": 1.15,
		"saudacao": [
			"Amigo! Amigo, chega aqui. Tenho uma coisa pra voce.",
			"Voce tem cara de quem entende de negocio.",
		],
		"documento": "O meu? ...O meu ta aqui. Ta. E o meu mesmo, olha a foto.",
		"despedida": ["Pensa no que eu falei.", "Depois voce me acha."],
		"nevoa": [
			"Isso ai e oportunidade, meu amigo. Casa vazia e oportunidade.",
			"Nao me olha assim. Eu so pego o que ia se perder.",
		],
		"bairro": [
			"Conheco cada porta dessa quadra. Cada uma.",
			"Qual delas voce quer? Faco preco.",
		],
		"voce": [
			"Oficialmente? {profissao}. Ta escrito, ta valendo.",
			"{idade} anos, nenhum patrao. Isso ninguem me tira.",
		],
		"proprio": {
			"titulo": "QUE NEGOCIO?",
			"linhas": [
				"Documento. Sabe como e, nesse tempo todo mundo precisa provar quem e.",
				"E tem gente aparecendo sem nada no bolso. Sem NADA, entendeu?",
				"Sem nome, sem numero, sem mae. Ai eu arrumo. Por um precinho.",
			],
		},
	},
]

const QUANTAS := 12


static func de(indice: int) -> Dictionary:
	return LISTA[posmod(indice, LISTA.size())]


static func nome(indice: int) -> String:
	return String(de(indice)["nome"])
