## Autoload. O banco de dados civil da cidade inteira.
##
## Cem milhoes de pessoas sem um byte guardado
## -------------------------------------------
## O pedido tem um requisito que parece exigir banco de dados: digitar o CPF de
## alguem no aplicativo do governo e ver a ficha completa daquela pessoa, mesmo
## de alguem que o jogador cruzou uma vez numa esquina e nunca mais viu.
##
## Guardar isso seria um save que cresce para sempre e um registro que nasce
## vazio: o CPF de quem o jogador ainda nao encontrou nao existiria em lugar
## nenhum. A saida e nao guardar nada e fazer o CPF ser o proprio endereco do
## registro.
##
## Cada pessoa tem um `id` de 0 a 99.999.999. O CPF e uma funcao INVERTIVEL desse
## id: multiplica, soma, tira o resto por 10^9 e acrescenta os dois digitos
## verificadores de sempre. Como a funcao e invertivel, o caminho de volta existe:
##
##     CPF digitado -> confere os verificadores -> desembaralha -> id -> ficha
##
## E o registro fica completo por construcao. Todo CPF valido cujo id caia dentro
## da populacao devolve uma pessoa coerente, com pais, endereco e familia; os
## outros 90% devolvem REGISTRO NAO ENCONTRADO, que e o que um numero inventado
## tem que devolver.
##
## A familia sai do mesmo numero
## -----------------------------
## Os tres bits de baixo do id sao a vaga na casa e o resto e a casa. Oito vagas
## por domicilio, com papeis sorteados pela casa: chefe, conjuge, filhos, avo,
## irmao, inquilino. Duas pessoas com id vizinho moram juntas, tem o mesmo
## sobrenome e o mesmo endereco, e uma aparece na filiacao da outra.
##
## Isso da o que o pedido pede sem tabela nenhuma: consultar o CPF de um
## desconhecido na rua e chegar na mae dele, e no endereco onde os dois moram.
##
## O ano e 1998 (ver DATA). Nao e enfeite: idade, validade do documento e ano de
## emissao saem dai, e uma cidade de PS1 com documento vencendo em 2031 quebra a
## unica coisa que a interface toda esta tentando dizer.
extends Node

## Tamanho da populacao registrada. Oito digitos: e o que cabe no RG.
const POPULACAO := 100000000

## Modulo do CPF sem os verificadores.
const BASE_CPF := 1000000000
## Multiplicador do embaralhamento do CPF. Impar e nao divisivel por 5, que e a
## condicao para ser invertivel modulo 10^9.
const MULT_CPF := 512347913
const SOMA_CPF := 137894621

const BASE_RG := 100000000
const MULT_RG := 37554319
const SOMA_RG := 12345677

## Dia de hoje no mundo do jogo.
const DATA := {"dia": 14, "mes": 11, "ano": 1998}

## Papel de uma pessoa dentro do domicilio.
enum Papel { CHEFE, CONJUGE, FILHO, AVO, IRMAO, INQUILINO }

## Situacao cadastral. O aplicativo mostra, e e por ela que uma consulta comum
## vira um susto: procurar a avo de alguem e achar a ficha baixada.
enum Situacao { REGULAR, SUSPENSO, FALECIDO }

const PRENOMES_M: Array[String] = [
	"ANTONIO", "JOSE", "CARLOS", "PAULO", "MARCOS", "LUIS", "PEDRO", "SERGIO",
	"RICARDO", "EDUARDO", "ROBERTO", "FERNANDO", "RAIMUNDO", "GERALDO",
	"BENEDITO", "JOAO", "FRANCISCO", "MANOEL", "SEBASTIAO", "OSVALDO",
	"WILSON", "ADEMIR", "CLAUDIO", "DIRCEU", "HELIO", "IVAN", "JAIME",
	"LOURIVAL", "MARIO", "NELSON", "ORLANDO", "PERCIVAL", "RUBENS",
	"SALVADOR", "TARCISIO", "VALDIR", "WALDEMAR", "ZACARIAS", "ARLINDO",
	"CELSO",
]

const PRENOMES_F: Array[String] = [
	"MARIA", "ANA", "TEREZA", "FRANCISCA", "ANTONIA", "ADRIANA", "JULIANA",
	"MARCIA", "FERNANDA", "PATRICIA", "ALDA", "BENEDITA", "CLEUSA", "DALVA",
	"EDNA", "ELZA", "GERALDA", "HELENA", "IRACEMA", "JANDIRA", "LOURDES",
	"MARLENE", "NEUSA", "ODETE", "ROSANGELA", "SONIA", "VERA", "ZILDA",
	"CONCEICAO", "DIRCE", "EUNICE", "GLORIA", "IVONE", "LUZIA", "NILZA",
	"RAIMUNDA", "SEVERINA", "TEREZINHA", "VANDA", "YARA",
]

const SOBRENOMES: Array[String] = [
	"SILVA", "SANTOS", "OLIVEIRA", "SOUZA", "RODRIGUES", "FERREIRA", "ALVES",
	"PEREIRA", "LIMA", "GOMES", "COSTA", "RIBEIRO", "MARTINS", "CARVALHO",
	"ALMEIDA", "LOPES", "SOARES", "FERNANDES", "VIEIRA", "BARBOSA", "ROCHA",
	"DIAS", "NASCIMENTO", "ANDRADE", "MOREIRA", "NUNES", "MARQUES", "MACHADO",
	"MENDES", "FREITAS", "CARDOSO", "RAMOS", "GONCALVES", "SANTANA", "TEIXEIRA",
	"ARAUJO", "CAVALCANTE", "MONTEIRO", "MOURA", "BATISTA",
]

## Naturalidade. Cidade e UF, escritas como o documento escreve.
const NATURALIDADES: Array[Array] = [
	["SAO PAULO", "SP"], ["SANTO ANDRE", "SP"], ["CAMPINAS", "SP"],
	["SANTOS", "SP"], ["SOROCABA", "SP"], ["RIO DE JANEIRO", "RJ"],
	["NITEROI", "RJ"], ["BELO HORIZONTE", "MG"], ["JUIZ DE FORA", "MG"],
	["UBERLANDIA", "MG"], ["CURITIBA", "PR"], ["LONDRINA", "PR"],
	["PORTO ALEGRE", "RS"], ["PELOTAS", "RS"], ["FLORIANOPOLIS", "SC"],
	["JOINVILLE", "SC"], ["SALVADOR", "BA"], ["FEIRA DE SANTANA", "BA"],
	["RECIFE", "PE"], ["FORTALEZA", "CE"], ["BELEM", "PA"], ["MANAUS", "AM"],
	["GOIANIA", "GO"], ["BRASILIA", "DF"], ["CUIABA", "MT"], ["MACEIO", "AL"],
	["SAO LUIS", "MA"], ["TERESINA", "PI"], ["NATAL", "RN"], ["VITORIA", "ES"],
]

## Profissao. Entra na ficha do aplicativo e nas falas: a pessoa fala do que faz,
## e e isso que faz duas conversas com a mesma personalidade nao serem iguais.
const PROFISSOES: Array[String] = [
	"COMERCIARIO", "OPERARIO", "MOTORISTA", "COSTUREIRA", "PEDREIRO",
	"ENFERMEIRA", "PROFESSOR", "CONTADOR", "VIGILANTE", "COZINHEIRO",
	"MECANICO", "ELETRICISTA", "BANCARIO", "FEIRANTE", "PORTEIRO",
	"CABELEIREIRA", "MARCENEIRO", "FARMACEUTICO", "TELEFONISTA", "PADEIRO",
	"AUXILIAR DE LIMPEZA", "DESPACHANTE", "SAPATEIRO", "RELOJOEIRO",
	"MOTOBOY", "GARCOM", "APOSENTADO", "DO LAR", "ESTUDANTE", "DESEMPREGADO",
]

const ORGAOS: Array[String] = ["SSP", "IFP", "IIRGD", "DETRAN"]

## Emitido quando a ficha do jogador troca — partida nova ou save carregado.
## O corpo em terceira pessoa escuta: o sujeito que aparece quando se aperta V
## tem de ser a pessoa da foto da carteira, e nao um boneco generico.
signal jogador_mudou()

## Identidade do jogador. Nasce no comeco de partida nova e vai para o save.
var jogador: Dictionary = {}

## Ids que o jogador ja abordou. E a agenda do celular, e a unica coisa deste
## registro inteiro que precisa ser guardada, porque nao da para deduzir da
## coordenada de ninguem quem foi que parou para conversar.
var _conhecidos: Array[int] = []

## Cache de fichas montadas. Uma ficha custa umas trinta operacoes de hash, o que
## e barato uma vez e caro se o aplicativo remontar a cada quadro que redesenha.
var _cache: Dictionary[int, Dictionary] = {}
var _cache_lar: Dictionary[int, Dictionary] = {}

var _inv_cpf: int = 0
var _inv_rg: int = 0


func _ready() -> void:
	_inv_cpf = _inverso_modular(MULT_CPF, BASE_CPF)
	_inv_rg = _inverso_modular(MULT_RG, BASE_RG)


# --- numeros ----------------------------------------------------------------

## Inverso multiplicativo por Euclides estendido. Existe porque `mult` e impar e
## nao e multiplo de 5, entao e primo com 10^n.
static func _inverso_modular(a: int, m: int) -> int:
	var t := 0
	var novo_t := 1
	var r := m
	var novo_r := a
	while novo_r != 0:
		var q := r / novo_r
		var tmp := t - q * novo_t
		t = novo_t
		novo_t = tmp
		tmp = r - q * novo_r
		r = novo_r
		novo_r = tmp
	return posmod(t, m)


## Os nove primeiros digitos do CPF de uma pessoa.
func _base_do_cpf(id: int) -> int:
	return posmod(id * MULT_CPF + SOMA_CPF, BASE_CPF)


## Digito verificador de CPF. E o algoritmo de verdade, com peso decrescente e
## resto por onze — sem ele o jogador digitaria qualquer numero e o aplicativo
## aceitaria, e a consulta perderia o unico atrito que ela tem.
static func _verificador(digitos: Array[int], peso_inicial: int) -> int:
	var soma := 0
	for i in digitos.size():
		soma += digitos[i] * (peso_inicial - i)
	var r := (soma * 10) % 11
	return 0 if r >= 10 else r


static func _digitos(valor: int, quantos: int) -> Array[int]:
	var saida: Array[int] = []
	saida.resize(quantos)
	var v := valor
	for i in range(quantos - 1, -1, -1):
		saida[i] = v % 10
		v /= 10
	return saida


## CPF completo, so digitos.
func cpf_de(id: int) -> String:
	var d := _digitos(_base_do_cpf(id), 9)
	d.append(_verificador(d, 10))
	d.append(_verificador(d, 11))
	var s := ""
	for n: int in d:
		s += str(n)
	return s


## CPF na forma que se escreve num balcao.
func cpf_formatado(id: int) -> String:
	var s := cpf_de(id)
	return "%s.%s.%s-%s" % [s.substr(0, 3), s.substr(3, 3), s.substr(6, 3),
		s.substr(9, 2)]


## Id de quem tem este CPF, ou -1. Aceita com ou sem pontuacao.
##
## Tres portas em serie, e as tres precisam existir: formato, verificador e
## faixa. Sem a ultima, qualquer numero com digito certo devolveria uma pessoa e
## o aplicativo nunca diria "nao encontrado", que e metade da graca dele.
func id_de_cpf(texto: String) -> int:
	var so_numero := _so_digitos(texto)
	if so_numero.length() != 11:
		return -1
	var d: Array[int] = []
	for i in 11:
		d.append(so_numero.unicode_at(i) - 48)
	var base: Array[int] = d.slice(0, 9)
	if _verificador(base, 10) != d[9]:
		return -1
	base.append(d[9])
	if _verificador(base, 11) != d[10]:
		return -1

	var valor := 0
	for i in 9:
		valor = valor * 10 + d[i]
	var id := posmod((valor - SOMA_CPF) * _inv_cpf, BASE_CPF)
	return id if id < POPULACAO else -1


func rg_de(id: int) -> String:
	var base := posmod(id * MULT_RG + SOMA_RG, BASE_RG)
	var d := _digitos(base, 8)
	# Verificador do RG: peso de 2 a 9 e resto por onze, com X para dez. E o
	# formato que a maioria dos estados usava, e o X e o detalhe que denuncia
	# documento de verdade para quem ja teve um na mao.
	var soma := 0
	for i in 8:
		soma += d[i] * (i + 2)
	var r := soma % 11
	var dv := "X" if r == 10 else str(r)
	var s := ""
	for n: int in d:
		s += str(n)
	return "%s.%s.%s-%s" % [s.substr(0, 2), s.substr(2, 3), s.substr(5, 3), dv]


func id_de_rg(texto: String) -> int:
	var so_numero := _so_digitos(texto.to_upper().replace("X", ""))
	if so_numero.length() < 8:
		return -1
	var base := int(so_numero.substr(0, 8))
	var id := posmod((base - SOMA_RG) * _inv_rg, BASE_RG)
	return id if id < POPULACAO else -1


static func _so_digitos(texto: String) -> String:
	var s := ""
	for i in texto.length():
		var c := texto.unicode_at(i)
		if c >= 48 and c <= 57:
			s += texto[i]
	return s


# --- hash -------------------------------------------------------------------

## Sorteio por canal. Mesma regra do gerador de parque: nada sai de fluxo
## compartilhado, tudo e funcao pura da chave, para a ficha de uma pessoa ser a
## mesma seja qual for a ordem em que o jogo perguntou.
static func _h(chave: int, canal: int) -> int:
	var x := (chave * 2654435761) ^ (canal * 40503) ^ 0x9E3779B9
	x = (x ^ (x >> 15)) * 1274126177
	x = x ^ (x >> 13)
	return absi(x) if x != -9223372036854775808 else 7


static func _escolher(lista: Array, chave: int, canal: int) -> Variant:
	return lista[_h(chave, canal) % lista.size()]


# --- domicilio --------------------------------------------------------------

## Casa de oito vagas. Todo id cai numa; os tres bits de baixo dizem qual.
func lar(lar_id: int) -> Dictionary:
	if _cache_lar.has(lar_id):
		return _cache_lar[lar_id]

	var sobrenome := "%s %s" % [_escolher(SOBRENOMES, lar_id, 11),
		_escolher(SOBRENOMES, lar_id, 12)]
	var idade_chefe := 29 + _h(lar_id, 13) % 34
	var casado := _h(lar_id, 14) % 4 != 0
	var filhos := _h(lar_id, 15) % 4
	var tem_avo := _h(lar_id, 16) % 5 == 0

	var papeis: Array[int] = []
	papeis.append(Papel.CHEFE)
	papeis.append(Papel.CONJUGE if casado else Papel.IRMAO)
	for i in filhos:
		papeis.append(Papel.FILHO)
	if tem_avo:
		papeis.append(Papel.AVO)
	while papeis.size() < 8:
		# O resto da casa e gente sem laco de sangue: pensao, quarto alugado,
		# primo que ficou. Numa cidade assim isso e mais comum que familia
		# nuclear, e de quebra da ao registro nomes que nao repetem o sobrenome.
		papeis.append(Papel.INQUILINO)

	# Endereco em coordenada de chunk de verdade. E o que permite ao jogador ler
	# um endereco no celular e ANDAR ate la: a cidade e infinita e deterministica,
	# entao qualquer par de coordenadas ja e um lugar montado.
	var cx := -14 + _h(lar_id, 17) % 29
	var cz := -14 + _h(lar_id, 18) % 29

	var d := {
		"id": lar_id,
		"sobrenome": sobrenome,
		"idade_chefe": idade_chefe,
		"sexo_chefe": &"M" if _h(lar_id, 19) % 2 == 0 else &"F",
		"casado": casado,
		"papeis": papeis,
		"cx": cx, "cz": cz,
		"numero": 12 + _h(lar_id, 20) % 880,
	}
	if _cache_lar.size() > 512:
		_cache_lar.clear()
	_cache_lar[lar_id] = d
	return d


## Nome de um morador sem montar a ficha inteira.
##
## Existe para cortar recursao: a ficha de um filho precisa do nome do pai, e a
## ficha do pai nao pode precisar da do filho para nao girar em circulo.
func _nome_do_slot(l: Dictionary, slot: int) -> String:
	var papeis: Array = l["papeis"]
	var papel: int = papeis[slot] if slot < papeis.size() else Papel.INQUILINO
	var id := (int(l["id"]) << 3) | slot
	var sexo := _sexo_do_slot(l, slot, papel)
	var pilha: Array = PRENOMES_M if sexo == &"M" else PRENOMES_F
	var prenome: String = _escolher(pilha, id, 31)
	if papel == Papel.INQUILINO:
		return "%s %s %s" % [prenome, _escolher(SOBRENOMES, id, 32),
			_escolher(SOBRENOMES, id, 33)]
	return "%s %s" % [prenome, l["sobrenome"]]


func _sexo_do_slot(l: Dictionary, slot: int, papel: int) -> StringName:
	if papel == Papel.CHEFE:
		return l["sexo_chefe"]
	if papel == Papel.CONJUGE:
		return &"F" if StringName(l["sexo_chefe"]) == &"M" else &"M"
	var id := (int(l["id"]) << 3) | slot
	return &"M" if _h(id, 34) % 2 == 0 else &"F"


func _idade_do_slot(l: Dictionary, slot: int, papel: int) -> int:
	var id := (int(l["id"]) << 3) | slot
	var chefe := int(l["idade_chefe"])
	match papel:
		Papel.CHEFE:
			return chefe
		Papel.CONJUGE:
			return clampi(chefe - 4 + _h(id, 35) % 9, 19, 88)
		Papel.FILHO:
			# Filho nasce quando o chefe tinha de 19 a 34 anos. Sem esse limite
			# saia gente de sessenta anos como filha de gente de sessenta e dois.
			return clampi(chefe - (19 + _h(id, 36) % 16), 0, 60)
		Papel.AVO:
			return clampi(chefe + 22 + _h(id, 37) % 12, 60, 97)
		Papel.IRMAO:
			return clampi(chefe - 8 + _h(id, 38) % 17, 18, 88)
		_:
			return 19 + _h(id, 39) % 44


# --- ficha ------------------------------------------------------------------

## Ficha completa de uma pessoa. E a unica porta: rua, celular e documento leem
## daqui, entao nao ha como o RG na mao do NPC discordar do que o aplicativo diz.
func identidade(id: int) -> Dictionary:
	if id < 0 or id >= POPULACAO:
		return {}
	if _cache.has(id):
		return _cache[id]

	var l := lar(id >> 3)
	var slot := id & 7
	var papeis: Array = l["papeis"]
	var papel: int = papeis[slot]
	var sexo := _sexo_do_slot(l, slot, papel)
	var idade := _idade_do_slot(l, slot, papel)
	var nome := _nome_do_slot(l, slot)

	# Filiacao. Filho e neto tem pais que EXISTEM no registro, com CPF proprio;
	# os demais tem pais de fora da cidade, que e o caso comum de quem alugou um
	# quarto aqui. E a diferenca entre uma familia e uma lista de nomes.
	var mae := ""
	var pai := ""
	if papel == Papel.FILHO:
		if StringName(l["sexo_chefe"]) == &"F":
			mae = _nome_do_slot(l, 0)
			pai = _nome_do_slot(l, 1) if bool(l["casado"]) else ""
		else:
			pai = _nome_do_slot(l, 0)
			mae = _nome_do_slot(l, 1) if bool(l["casado"]) else ""
	if mae == "":
		mae = "%s %s" % [_escolher(PRENOMES_F, id, 41),
			l["sobrenome"] if papel != Papel.INQUILINO
			else _escolher(SOBRENOMES, id, 42)]
	if pai == "":
		pai = "%s %s" % [_escolher(PRENOMES_M, id, 43),
			l["sobrenome"] if papel != Papel.INQUILINO
			else _escolher(SOBRENOMES, id, 44)]

	var nasc_ano := int(DATA["ano"]) - idade
	var nasc_mes := 1 + _h(id, 45) % 12
	var nasc_dia := 1 + _h(id, 46) % 28
	var natural: Array = _escolher(NATURALIDADES, id, 47)

	var profissao := "ESTUDANTE" if idade < 18 else (
		"APOSENTADO" if idade > 66 else String(_escolher(PROFISSOES, id, 48)))

	# Situacao. Quase todo mundo esta regular; o registro so fica interessante
	# porque uma minoria nao esta.
	var situacao := Situacao.REGULAR
	var sorte := _h(id, 49) % 100
	if idade > 74 and sorte < 34:
		situacao = Situacao.FALECIDO
	elif sorte < 4:
		situacao = Situacao.SUSPENSO

	# Emissao entre os 16 e hoje; validade dez anos depois.
	var ano_emissao := clampi(nasc_ano + 16 + _h(id, 50) % 12,
		nasc_ano + 16, int(DATA["ano"]))
	var ficha := {
		"id": id,
		"nome": nome,
		"primeiro": nome.split(" ")[0],
		"sobrenome": l["sobrenome"],
		"sexo": sexo,
		"idade": idade,
		"nascimento": "%02d/%02d/%04d" % [nasc_dia, nasc_mes, nasc_ano],
		"naturalidade": "%s - %s" % [natural[0], natural[1]],
		"uf": natural[1],
		"nacionalidade": "BRASILEIRA",
		"mae": mae,
		"pai": pai,
		"cpf": cpf_formatado(id),
		"rg": rg_de(id),
		"orgao": "%s/%s" % [_escolher(ORGAOS, id, 51), natural[1]],
		"expedicao": "%02d/%02d/%04d" % [1 + _h(id, 52) % 28,
			1 + _h(id, 53) % 12, ano_emissao],
		"validade": "%02d/%02d/%04d" % [1 + _h(id, 52) % 28,
			1 + _h(id, 53) % 12, ano_emissao + 10],
		"profissao": profissao,
		"papel": papel,
		"lar": int(l["id"]),
		"slot": slot,
		"situacao": situacao,
		"endereco": endereco_de(l),
		"cx": int(l["cx"]), "cz": int(l["cz"]),
		"personalidade": _h(id, 54) % Personalidade.QUANTAS,
	}
	ficha["aparencia"] = Aparencia.de_ficha(ficha)

	if _cache.size() > 768:
		_cache.clear()
	_cache[id] = ficha
	return ficha


## Endereco escrito. O nome da rua sai do distrito e da coordenada, exatamente
## como o mapa de pausa escreve, entao ler o endereco no celular e achar a placa
## no mapa dao a mesma resposta.
func endereco_de(l: Dictionary) -> String:
	var cx := int(l["cx"])
	var cz := int(l["cz"])
	var distrito := MalhaUrbana.distrito_de(cx, cz)
	return "%s, QD %d-%d, N %d" % [MalhaUrbana.nome_do_distrito(distrito),
		absi(cx), absi(cz), int(l["numero"])]


## Um id qualquer, derivado de uma semente. Publico porque o desfile de captura
## e a multidao precisam do mesmo espalhamento.
func id_sorteado(semente: int) -> int:
	return posmod(_h(semente, 71), POPULACAO)


## Alguem que pode estar andando na rua as duas da manha.
##
## A regra mora aqui, e nao em quem sorteia, porque ela e sobre o REGISTRO e nao
## sobre a rua: o banco cobre a cidade inteira, inclusive quem morreu e quem tem
## nove anos, e essas duas exclusoes valeriam iguais para qualquer outro sistema
## que fosse povoar alguma coisa.
func id_de_transeunte(semente: int) -> int:
	var id := id_sorteado(semente)
	for tentativa in 16:
		var f := identidade(id)
		if (not f.is_empty() and int(f["situacao"]) != Situacao.FALECIDO
				and int(f["idade"]) >= 17):
			return id
		id = id_sorteado(semente + (tentativa + 1) * 7919)
	return id


## Um transeunte dentro de uma faixa de idade.
##
## A casa da fumaca precisa de gente de dezoito a vinte e seis, e nao da
## populacao inteira: uma sala de amigos com um senhor de setenta anos sentado
## no chao jogando video game conta outra historia, e nao e a que o comodo quer
## contar. O sorteio e o mesmo; o que muda e quantas vezes ele insiste.
func id_de_faixa(semente: int, minima: int, maxima: int) -> int:
	var id := id_sorteado(semente)
	for tentativa in 24:
		var f := identidade(id)
		if (not f.is_empty() and int(f["situacao"]) != Situacao.FALECIDO
				and int(f["idade"]) >= minima and int(f["idade"]) <= maxima):
			return id
		id = id_sorteado(semente + (tentativa + 1) * 7919)
	# Depois de vinte e quatro tentativas, qualquer adulto serve. Devolver -1
	# deixaria um lugar vazio no comodo, que e pior que uma idade fora da faixa.
	return id_de_transeunte(semente)


func esta_vivo(id: int) -> bool:
	var f := identidade(id)
	return not f.is_empty() and int(f["situacao"]) != Situacao.FALECIDO


func nome_da_situacao(s: int) -> String:
	match s:
		Situacao.SUSPENSO:
			return "SUSPENSO"
		Situacao.FALECIDO:
			return "BAIXADO POR OBITO"
		_:
			return "REGULAR"


func nome_do_papel(p: int, sexo: StringName) -> String:
	match p:
		Papel.CHEFE:
			return "TITULAR"
		Papel.CONJUGE:
			return "CONJUGE"
		Papel.FILHO:
			return "FILHA" if sexo == &"F" else "FILHO"
		Papel.AVO:
			return "AVO"
		Papel.IRMAO:
			return "IRMA" if sexo == &"F" else "IRMAO"
		_:
			return "COABITANTE"


## Quem mais mora no mesmo endereco. E a tela de VINCULOS do aplicativo.
func vinculos(id: int) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	var base := (id >> 3) << 3
	for slot in 8:
		var outro := base | slot
		if outro == id:
			continue
		var f := identidade(outro)
		if f.is_empty():
			continue
		saida.append({
			"id": outro,
			"nome": f["nome"],
			"relacao": nome_do_papel(int(f["papel"]), f["sexo"]),
			"idade": int(f["idade"]),
			"situacao": int(f["situacao"]),
			"cpf": f["cpf"],
		})
	return saida


# --- busca por nome ---------------------------------------------------------

## Quantos nomes uma busca devolve, no maximo. Doze e o que cabe na tela do
## terminal sem rolagem de segunda pagina.
const MAX_BUSCA := 12

## Menor pedaco de nome que a busca aceita. Com duas letras "AN" casa com metade
## da cidade e a lista deixa de ser uma resposta.
const MINIMO_BUSCA := 3

## Teto do indice que a busca por nome percorre.
##
## A agenda cresce a partida inteira: cada pessoa abordada na rua e cada CPF
## consultado entram nela, e a casa de cada uma multiplica por oito. Sem teto,
## uma partida longa faria a tecla Enter parar o jogo por um tranco enquanto
## algumas milhares de fichas sao remontadas — e o custo cresceria justamente
## para quem mais usou o sistema, que e o pior lugar para pousar uma penalidade.
##
## Quinhentos e doze cobre com folga o que um jogador acumula, e o corte comeca
## pelas fontes mais distantes: primeiro quem esta no comodo, depois a agenda,
## e so no fim as casas. Quem esta no balcao na sua frente nunca cai fora.
const TETO_DO_INDICE := 512


## Procura pessoas cujo nome contenha `texto`. Devolve ids.
##
## Por que ela nao varre o registro inteiro
## ----------------------------------------
## O CPF e o ENDERECO da ficha: `id_de_cpf` desembaralha o numero e chega na
## pessoa em trinta operacoes, sem tabela nenhuma. E o que faz um registro de
## cem milhoes de pessoas caber em zero byte de save.
##
## O nome nao tem essa volta. Ele sai de `_escolher(PRENOMES, id, 31)`, que e uma
## funcao de hash — e hash nao se inverte. Para achar "BONNIE" pelo nome seria
## preciso montar as cem milhoes de fichas e olhar uma por uma, e isso nao e uma
## consulta lenta: e uma consulta impossivel dentro de um quadro.
##
## Entao a busca por nome procura em outro lugar: no que este terminal JA VIU.
## Quem o jogador abordou na rua, quem ele consultou por CPF, quem esta no comodo
## agora, e a casa de cada um deles. Que e, por acaso, exatamente o que um
## sistema de balcao de loja teria — o registro nacional responde por numero, e o
## que a maquina da loja guarda e o log de quem passou por ali.
##
## Na pratica o caso que importa sempre funciona: o cliente que largou a
## identidade no balcao esta no comodo, entao o nome dele acha.
func buscar_por_nome(texto: String) -> Array[int]:
	var alvo := texto.strip_edges().to_upper()
	if alvo.length() < MINIMO_BUSCA:
		return []

	var saida: Array[int] = []
	for id: int in indice_local():
		var f := identidade(id)
		if f.is_empty():
			continue
		if String(f["nome"]).contains(alvo):
			saida.append(id)
			if saida.size() >= MAX_BUSCA:
				break
	return saida


## Todo mundo que este terminal pode achar pelo nome, sem repetir.
##
## Tres fontes, da mais proxima para a mais distante: quem esta no comodo agora,
## quem o jogador ja conhece, e a casa de cada um dos dois. A casa entra porque e
## por ela que a consulta vira investigacao — ler o nome da mae numa ficha e
## conseguir procurar por ele e o laco inteiro que o registro existe para dar.
func indice_local() -> Array[int]:
	var vistos: Dictionary[int, bool] = {}
	var ordem: Array[int] = []

	var acrescentar := func(id: int) -> void:
		if id < 0 or id >= POPULACAO or vistos.has(id):
			return
		if ordem.size() >= TETO_DO_INDICE:
			return
		vistos[id] = true
		ordem.append(id)

	# Quem esta no comodo. Npc e Convidado entram os dois no grupo `npc`.
	var arvore := get_tree()
	if arvore != null:
		for no: Node in arvore.get_nodes_in_group(&"npc"):
			var f: Variant = no.get("ficha")
			if f is Dictionary and not (f as Dictionary).is_empty():
				acrescentar.call(int((f as Dictionary).get("id", -1)))

	acrescentar.call(id_do_jogador())
	for id: int in _conhecidos:
		acrescentar.call(id)

	# A casa de cada um. Iterado sobre uma COPIA: `vinculos` acrescenta na lista
	# de tras para frente e percorrer o array que cresce nao termina nunca.
	for id: int in ordem.duplicate():
		if ordem.size() >= TETO_DO_INDICE:
			break
		for v: Dictionary in vinculos(id):
			acrescentar.call(int(v["id"]))
	return ordem


# --- jogador ----------------------------------------------------------------

## Sorteia a identidade do jogador. So o nome vem de fora; o resto e do mundo.
##
## O jogador nao escolhe CPF nem data de nascimento pela mesma razao que nao
## escolhe onde a rua vira: a ficha dele tem que ser um registro do mesmo banco
## que o dos outros, senao consultar o proprio CPF no aplicativo nao provaria
## nada.
func criar_jogador(nome_escolhido: String = "") -> Dictionary:
	# Partida nova e agenda nova: quem o jogador anterior conheceu nao e
	# conhecido deste. E aqui, e nao no `limpar`, porque emitir uma ficha JA E
	# comecar de novo — nao ha outro caminho para uma pessoa nova existir.
	_conhecidos.clear()
	var semente := int(Time.get_unix_time_from_system()) ^ (randi() & 0xFFFF)
	var id := posmod(_h(semente, 61), POPULACAO)
	# Ninguem comeca o jogo com a propria certidao de obito no bolso.
	var tentativa := 0
	while not esta_vivo(id) and tentativa < 16:
		id = posmod(_h(id + tentativa, 62), POPULACAO)
		tentativa += 1

	jogador = identidade(id).duplicate(true)
	var limpo := nome_escolhido.strip_edges().to_upper()
	if limpo != "":
		# So o primeiro nome vem do jogador; o sobrenome continua sendo o da casa
		# em que ele nasceu no registro, porque e por ele que a familia dele
		# existe no aplicativo.
		jogador["nome"] = "%s %s" % [limpo.split(" ")[0], jogador["sobrenome"]]
		jogador["primeiro"] = limpo.split(" ")[0]
	jogador["e_jogador"] = true
	conhecer(id)
	jogador_mudou.emit()
	return jogador


func id_do_jogador() -> int:
	return int(jogador.get("id", -1))


## Guarda as escolhas da tela de criacao e refaz a aparencia do jogador.
##
## Sao guardados os AJUSTES, e nao a aparencia pronta. A aparencia se deduz da
## ficha mais os ajustes; guardar o resultado seria guardar uma copia que
## envelhece no dia em que o gerador mudar de paleta.
func ajustar_jogador(ajustes: Dictionary) -> void:
	if jogador.is_empty():
		return
	jogador["ajustes"] = ajustes.duplicate(true)
	jogador["aparencia"] = Aparencia.com_ajustes(
		Aparencia.de_ficha(jogador), jogador["ajustes"])
	jogador_mudou.emit()


## Os ajustes atuais, ou os da pessoa sorteada se ele ainda nao mexeu em nada.
func ajustes_do_jogador() -> Dictionary:
	if jogador.is_empty():
		return {}
	if jogador.has("ajustes"):
		return (jogador["ajustes"] as Dictionary).duplicate(true)
	return Aparencia.ajustes_de(jogador["aparencia"])


# --- agenda -----------------------------------------------------------------

func conhecer(id: int) -> void:
	if id < 0 or _conhecidos.has(id):
		return
	_conhecidos.append(id)

func ja_conhece(id: int) -> bool:
	return _conhecidos.has(id)

func conhecidos() -> Array[int]:
	return _conhecidos.duplicate()


# --- persistencia -----------------------------------------------------------

func para_dicionario() -> Dictionary:
	# Os ajustes viram texto: o save e JSON e Color nao sobrevive a ele.
	var ajustes: Dictionary = {}
	for chave: Variant in jogador.get("ajustes", {}):
		var valor: Variant = jogador["ajustes"][chave]
		ajustes[String(chave)] = (Color(valor).to_html(false)
			if typeof(valor) == TYPE_COLOR else valor)
	return {
		"jogador": id_do_jogador(),
		"nome": jogador.get("nome", ""),
		"ajustes": ajustes,
		"conhecidos": _conhecidos.duplicate(),
	}


func de_dicionario(dados: Dictionary) -> void:
	_conhecidos.clear()
	for v: Variant in dados.get("conhecidos", []):
		_conhecidos.append(int(v))
	var id := int(dados.get("jogador", -1))
	if id < 0:
		jogador = {}
		return
	jogador = identidade(id).duplicate(true)
	jogador["e_jogador"] = true
	var nome := String(dados.get("nome", ""))
	if nome != "":
		jogador["nome"] = nome
		jogador["primeiro"] = nome.split(" ")[0]

	var brutos: Dictionary = dados.get("ajustes", {})
	if not brutos.is_empty():
		var ajustes: Dictionary = {}
		for chave: String in brutos:
			var valor: Variant = brutos[chave]
			# Cor voltou como texto; o resto voltou como numero.
			ajustes[StringName(chave)] = (Color(String(valor))
				if typeof(valor) == TYPE_STRING else valor)
		jogador["ajustes"] = ajustes
		jogador["aparencia"] = Aparencia.com_ajustes(
			Aparencia.de_ficha(jogador), ajustes)
	jogador_mudou.emit()


## Esvazia so o cache de fichas. Serve a verificacao de determinismo: montar a
## mesma ficha duas vezes com o cache frio prova que ela sai da funcao, e nao da
## memoria — que e a afirmacao que sustenta o registro inteiro.
func esquecer_cache() -> void:
	_cache.clear()
	_cache_lar.clear()


func limpar() -> void:
	_conhecidos.clear()
	esquecer_cache()
	jogador = {}
