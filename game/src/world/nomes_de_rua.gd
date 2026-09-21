## O nome de cada rua da cidade.
##
## Por que existe
## -------------
## O endereco era o indice do chunk — "3-4" — no GPS, no telefone de salvar e na
## ficha do morador. Cidade do interior se explica por nome de rua: a Tiradentes,
## a Sete de Setembro, o beco do Rosario, a avenida que vai para a estacao. O
## nome e o que o jogador repete para si mesmo quando aprende um caminho.
##
## Funcao pura da coordenada, como a malha: o mesmo trecho tem o mesmo nome hoje
## e na proxima execucao, e o GPS acha o nome de um lugar a 400 m sem montar
## nada. A avenida e nomeada pela LINHA (ela e linha inteira); rua e viela pelo
## CORTE do Tracado que as criou, entao a rua inteira tem um nome so, e a mesma
## linha pode ser a Tiradentes de um lado da avenida e outra rua do outro.
##
## Sem acento: a fonte de bitmap do PS1 nao tem os glifos.
class_name NomesDeRua
extends RefCounted

const AVENIDAS: Array[String] = [
	"GETULIO VARGAS", "BRASIL", "JK", "AFONSO PENA", "OLEGARIO MACIEL",
	"JOAO PINHEIRO", "MINAS GERAIS", "BIAS FORTES", "SANTOS DUMONT",
	"DA ESTACAO", "PRESIDENTE VARGAS", "SILVIANO BRANDAO",
]

const RUAS: Array[String] = [
	"TIRADENTES", "SETE DE SETEMBRO", "QUINZE DE NOVEMBRO", "TREZE DE MAIO",
	"BARAO DO RIO BRANCO", "PADRE ANCHIETA", "SAO JOSE", "SANTO ANTONIO",
	"DO ROSARIO", "DAS FLORES", "DA MATRIZ", "DO COMERCIO", "DOM PEDRO II",
	"RUI BARBOSA", "MARECHAL DEODORO", "FLORIANO PEIXOTO", "DUQUE DE CAXIAS",
	"BENJAMIN CONSTANT", "JOSE BONIFACIO", "VISCONDE DE MAUA", "PERNAMBUCO",
	"BAHIA", "GOIAS", "PARANA", "ESPIRITO SANTO", "PADRE EUSTAQUIO",
	"DAS PALMEIRAS", "DOS IPES", "DA SAUDADE", "DO CRUZEIRO", "DAS MERCES",
	"SAO SEBASTIAO", "SAO BENEDITO", "CHICO REI", "ALEIJADINHO",
	"TOMAS GONZAGA", "CLAUDIO MANUEL", "CORONEL JOSE DIAS", "DONA JOAQUINA",
	"MESTRE ATAIDE", "DOS OPERARIOS", "DA LIBERDADE", "DO CAMPO",
]

const VIELAS: Array[String] = [
	"DO ROSARIO", "DA CADEIA", "DO SAPO", "DAS LAVADEIRAS", "DO PADRE",
	"DA CARIDADE", "DO OURO", "DOS MILAGRES", "DA PONTE", "DO MOINHO",
]


## Nome da via na linha x = i, trecho da linha de chunks j. Vazio sem via.
static func nome_x(i: int, j: int) -> String:
	return _nome(MalhaUrbana.via_x_em(i, j), 0, i,
		floori(float(i) / MalhaUrbana.PERIODO), floori(float(j) / MalhaUrbana.PERIODO))


## Nome da via na linha z = j, trecho da coluna de chunks i. Vazio sem via.
static func nome_z(j: int, i: int) -> String:
	return _nome(MalhaUrbana.via_z_em(j, i), 1, j,
		floori(float(i) / MalhaUrbana.PERIODO), floori(float(j) / MalhaUrbana.PERIODO))


static func _nome(v: int, eixo: int, linha: int, ci: int, cj: int) -> String:
	match v:
		MalhaUrbana.Via.AVENIDA:
			var h := MalhaUrbana._ruido(linha, eixo, 2203)
			return "AV. " + AVENIDAS[h % AVENIDAS.size()]
		MalhaUrbana.Via.RUA:
			var h := MalhaUrbana._ruido(linha * 3 + eixo, ci * 7919 + cj, 2207)
			return "R. " + RUAS[h % RUAS.size()]
		MalhaUrbana.Via.VIELA:
			var h := MalhaUrbana._ruido(linha * 3 + eixo, ci * 7919 + cj, 2213)
			return ("BECO " if h % 2 == 0 else "TRAV. ") + VIELAS[(h / 2) % VIELAS.size()]
	return ""


## Largura de um caractere do rotulo da placa, em metros. Casa com o
## `pixel_size` e o `font_size` do Label3D que o ChunkManager cria.
const LETRA := 0.062
const AZUL := Color("24508a")


## O poste de placas da esquina (i, j) = (cx, cz): um poste com as duas placas
## azuis, uma para cada rua, paralelas a rua que nomeiam.
##
## O chunk dono do no (a mesma regra do cruzamento, ver
## cruzamento-inteiro-vem-do-chunk-dono) planta o poste num canto que tenha as
## duas ruas encostadas. A placa e malha do chunk; o nome e um no (Label3D),
## porque texto nao se funde.
static func placas(sup: Dictionary, props: Array[Dictionary], cx: int, cz: int) -> void:
	if not Rotas.existe_no(cx, cz):
		return
	var y0 := KitModular.ALTURA_MEIO_FIO
	for canto: Vector2i in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var linha_z := cz if canto.y > 0 else cz - 1
		var coluna_x := cx if canto.x > 0 else cx - 1
		var vx := MalhaUrbana.via_x_em(cx, linha_z)
		var vz := MalhaUrbana.via_z_em(cz, coluna_x)
		if vx == MalhaUrbana.Via.NENHUMA or vz == MalhaUrbana.Via.NENHUMA:
			continue
		var nome_x_ := nome_x(cx, linha_z)
		var nome_z_ := nome_z(cz, coluna_x)
		# Rente a quina do predio, a 35 cm da linha da fachada: o semaforo fica
		# no meio-fio e a esquina de quem anda (Rotas.ponto) em 62% da calcada —
		# o poste no meio dela seria um pedestre atravessando ferro.
		var ox := MalhaUrbana.meia_asfalto(vx) + MalhaUrbana.largura_calcada(vx) - 0.35
		var oz := MalhaUrbana.meia_asfalto(vz) + MalhaUrbana.largura_calcada(vz) - 0.35
		var base := Vector3(float(canto.x) * ox, y0, float(canto.y) * oz)
		base.y += Relevo.local(cx, cz, base)
		KitModular.caixa_cor(sup, &"metal", base + Vector3(0.0, 1.5, 0.0),
			Vector3(0.07, 3.0, 0.07), Color("5a5e60"), 0.0, PSXMesh.FACE_TODAS, 8.0)
		# A placa da rua do eixo X corre em Z (paralela a ela); a da rua do eixo Z
		# corre em X. Uma em cima da outra, as duas no topo do poste.
		_placa(sup, props, base + Vector3(0.0, 2.72, 0.0), nome_x_, true)
		_placa(sup, props, base + Vector3(0.0, 2.98, 0.0), nome_z_, false)
		return


static func _placa(sup: Dictionary, props: Array[Dictionary], centro: Vector3,
		texto: String, ao_longo_de_z: bool) -> void:
	if texto.is_empty():
		return
	var larg := LETRA * float(texto.length()) + 0.24
	var tam := Vector3(0.03, 0.22, larg) if ao_longo_de_z else Vector3(larg, 0.22, 0.03)
	KitModular.caixa_cor(sup, &"metal", centro, tam, AZUL, 0.0, PSXMesh.FACE_TODAS, 8.0)
	# Um rotulo de cada lado: a placa e lida das duas calcadas.
	var giro := PI * 0.5 if ao_longo_de_z else 0.0
	for lado: float in [1.0, -1.0]:
		var fora := Vector3(lado, 0.0, 0.0) if ao_longo_de_z else Vector3(0.0, 0.0, lado)
		props.append({
			"tipo": "placa_rua",
			"pos": centro + fora * 0.02,
			"giro": giro + (0.0 if lado > 0.0 else PI),
			"texto": texto,
		})


## A rua mais perto de um ponto do mundo, dentro de `alcance` metros do eixo
## dela. Vazio longe de qualquer rua (miolo de parque grande).
static func rua_perto(pos: Vector3, alcance: float = 24.0) -> String:
	var tam := MalhaUrbana.TAM
	var cx := floori(pos.x / tam)
	var cz := floori(pos.z / tam)
	var melhor := ""
	var melhor_d := alcance
	for di in range(0, 2):
		var i := cx + di
		var nome := nome_x(i, cz)
		var d := absf(pos.x - float(i) * tam)
		if not nome.is_empty() and d < melhor_d:
			melhor_d = d
			melhor = nome
	for dj in range(0, 2):
		var j := cz + dj
		var nome := nome_z(j, cx)
		var d := absf(pos.z - float(j) * tam)
		if not nome.is_empty() and d < melhor_d:
			melhor_d = d
			melhor = nome
	return melhor
