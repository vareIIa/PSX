## Autoload. O que o jogador esta tentando fazer agora.
##
## Uma missao so por vez, de proposito
## -----------------------------------
## Nao ha lista de tarefas, nao ha diario e nao ha missao secundaria. O jogo tem
## um sujeito querendo sair de uma cidade, e o que a tela precisa dizer e a
## proxima coisa que ele faz — nada mais. Uma fila de objetivos abertos exigiria
## uma pagina para consultar, a pagina exigiria um botao, e no fim das contas o
## jogador estaria administrando uma agenda em vez de andar na rua.
##
## Quando existir a segunda missao, ela substitui esta. `atual` guarda uma so, e
## e isso que a HUD desenha.
##
## Missao e um Dictionary, e nao uma classe
## ----------------------------------------
## Pelo mesmo motivo que ponto de interesse e chunk sao: ela nasce de dado, viaja
## por sinal, e vai para o save inteira. Uma classe aqui daria uma conversao a
## mais em cada uma dessas tres passagens e nao daria nada em troca — nao ha
## comportamento nenhum dentro de uma missao, so o texto e o alvo.
##
## Quem decide que a etapa acabou
## ------------------------------
## Este arquivo, ouvindo os sistemas que ja existem. O GPS avisa quando o jogador
## traca uma rota, o Interiores avisa quando ele entra num comodo, e as duas
## etapas da primeira missao sao exatamente essas duas coisas. Nenhum dos dois
## sabe que ha missao acontecendo, e e assim que tem de ser: no dia em que a
## missao mudar, o GPS nao muda junto.
extends Node

## Cor do alfinete de missao no mapa de papel.
##
## Verde, e nao a cor de alvo do GPS. O mapa e sepia — papel bege, tinta marrom,
## parque verde-oliva — e o alfinete comum ja e o vermelho tijolo do `Mapa.ALVO`.
## Um verde forte e a unica cor que sobra que nao se confunde nem com o papel nem
## com o alfinete de rota, e casa com o icone de casa verde que a casa da fumaca
## ja tem no GPS desde sempre.
const VERDE := Color("2f6b2a")

## Ate onde procurar a casa da fumaca do comeco, em chunks. E o mesmo raio da
## varredura do GPS: se a primeira missao apontasse para um lugar que o aparelho
## do jogador nao lista, ela seria impossivel de marcar.
const RAIO_CHUNKS := 12

signal iniciou(missao: Dictionary)
## Uma etapa terminou e a seguinte comecou.
signal avancou(missao: Dictionary)
signal concluiu(missao: Dictionary)

## A missao em andamento, ou vazia. Ver o cabecalho para a forma.
var atual: Dictionary = {}


func _ready() -> void:
	Gps.destino_mudou.connect(_ao_mudar_destino)
	Interiores.entrou.connect(_ao_entrar)


# --- ciclo de vida ----------------------------------------------------------

func limpar() -> void:
	atual = {}


## Comeca uma missao. Substitui a que estiver em andamento.
func comecar(missao: Dictionary) -> void:
	atual = missao.duplicate(true)
	atual["etapa"] = 0
	iniciou.emit(atual)


## A primeira missao do jogo: chegar na casa da fumaca mais proxima de onde o
## jogador acordou.
##
## Duas etapas, e a primeira e so mexer no aparelho. Nao e enrolacao: o jogo tem
## um GPS com sete filtros, cinco escalas e uma lista rolavel, e ninguem descobre
## isso sozinho no meio de uma cidade infinita. Pedir para marcar um endereco e a
## unica aula de mapa que o jogo da, e ela cabe dentro da primeira missao em vez
## de virar um tutorial a parte.
##
## Devolve a missao criada, ou um dicionario vazio quando nao ha nenhuma casa da
## fumaca no raio de busca — o que nao acontece com o gerador que esta no jogo,
## mas depende dele e por isso nao pode ser tratado como certeza.
func comecar_primeira(perto_de: Vector3) -> Dictionary:
	var alvo := casa_mais_perto(perto_de)
	if alvo.is_empty():
		push_warning("Missoes: nenhuma casa da fumaca num raio de %d chunks"
			% RAIO_CHUNKS)
		return {}
	comecar({
		"id": &"casa_da_fumaca",
		"titulo": "A CASA DA FUMACA",
		"etapas": [
			{
				"texto": "Marque a casa da fumaca no mapa.",
				"dica": "[M] abre o GPS   [E] traca a rota",
			},
			{
				"texto": "Va ate a casa da fumaca.",
				"dica": "",
			},
		],
		"alvo": alvo,
	})
	return atual


## A casa da fumaca mais proxima de um ponto.
##
## Le a cidade sem construir nada: `pontos_de_interesse` e estatica e devolve o
## mesmo resultado para a mesma coordenada, entao da para achar um endereco em
## quadra onde o jogador nunca pisou e onde nao ha um unico triangulo carregado.
## E a mesma leitura que o GPS faz para montar a lista dele.
static func casa_mais_perto(de: Vector3) -> Dictionary:
	var aqui := Vector2i(floori(de.x / Mapa.TAM), floori(de.z / Mapa.TAM))
	var melhor: Dictionary = {}
	var melhor_d := INF
	for cz in range(aqui.y - RAIO_CHUNKS, aqui.y + RAIO_CHUNKS + 1):
		for cx in range(aqui.x - RAIO_CHUNKS, aqui.x + RAIO_CHUNKS + 1):
			for ponto: Dictionary in ChunkBuilder.pontos_de_interesse(cx, cz):
				if ponto.get("tipo") != &"porta":
					continue
				if ponto.get("interior") != &"casa_fumaca":
					continue
				var p: Vector3 = ponto["pos"]
				var mundo := Vector3(float(cx) * Mapa.TAM + p.x, p.y,
					float(cz) * Mapa.TAM + p.z)
				var d := Vector2(mundo.x - de.x, mundo.z - de.z).length()
				if d >= melhor_d:
					continue
				melhor_d = d
				melhor = {
					"mundo": mundo,
					"chunk": Vector2i(cx, cz),
					"semente": int(ponto.get("semente", 0)),
					"nome": String(ponto.get("nome", "CASA DA FUMACA")),
				}
	return melhor


# --- etapas -----------------------------------------------------------------

func etapa_atual() -> Dictionary:
	if atual.is_empty():
		return {}
	var etapas: Array = atual["etapas"]
	var i := int(atual["etapa"])
	return etapas[i] if i < etapas.size() else {}


## Fecha a etapa em andamento e abre a proxima. Na ultima, encerra a missao.
func avancar() -> void:
	if atual.is_empty():
		return
	var etapas: Array = atual["etapas"]
	atual["etapa"] = int(atual["etapa"]) + 1
	if int(atual["etapa"]) >= etapas.size():
		var terminada := atual
		atual = {}
		AudioDirector.tocar_ui(&"celular_ok", -6.0)
		concluiu.emit(terminada)
		return
	AudioDirector.tocar_ui(&"bipe_curto", -12.0)
	avancou.emit(atual)


## O jogador tracou ou apagou uma rota. Fecha a etapa de marcar o endereco.
##
## Aceita qualquer casa da fumaca, e nao so a que a missao escolheu. O objetivo
## desta etapa e o jogador aprender a usar o aparelho; mandar de volta quem
## marcou a casa da rua de tras, que fica mais perto, seria ensinar o contrario.
func _ao_mudar_destino() -> void:
	if atual.is_empty() or int(atual["etapa"]) != 0:
		return
	if Gps.destino.is_empty():
		return
	if Gps.destino.get("categoria") != &"casa_fumaca":
		return
	avancar()


## O jogador entrou num comodo. Fecha a missao quando o comodo e a casa.
func _ao_entrar() -> void:
	if atual.is_empty() or int(atual["etapa"]) != 1:
		return
	if Interiores.tipo_atual() != &"casa_fumaca":
		return
	avancar()


# --- para quem desenha ------------------------------------------------------

## O alfinete verde do alvo, para o mapa e para o minimapa. Vazio quando nao ha
## missao ou quando a missao nao aponta para lugar nenhum.
func pinos() -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	if atual.is_empty() or not atual.has("alvo"):
		return saida
	var alvo: Dictionary = atual["alvo"]
	var mundo: Vector3 = alvo["mundo"]
	saida.append({
		"pos": Vector2(mundo.x, mundo.z),
		"destaque": true,
		"cor": VERDE,
	})
	return saida


## Onde esta o alvo, ou Vector3.INF quando nao ha alvo. Quem quer distancia
## pergunta isto e faz a propria conta.
func posicao_do_alvo() -> Vector3:
	if atual.is_empty() or not atual.has("alvo"):
		return Vector3.INF
	var alvo: Dictionary = atual["alvo"]
	return alvo["mundo"]


# --- save -------------------------------------------------------------------

## A missao inteira cabe no save.
##
## Vector3 e Vector2i nao sobrevivem a ida e volta pelo JSON, entao o alvo sai
## em numero solto. A alternativa seria gravar so o id da missao e reconstruir o
## alvo na carga — o que daria certo hoje, porque o alvo vem do gerador e o
## gerador e deterministico, e daria errado no dia em que uma missao apontar para
## uma coisa que o jogador colocou no mundo.
func para_dicionario() -> Dictionary:
	if atual.is_empty():
		return {}
	var fora := atual.duplicate(true)
	if fora.has("alvo"):
		var alvo: Dictionary = fora["alvo"]
		var mundo: Vector3 = alvo["mundo"]
		var chunk: Vector2i = alvo["chunk"]
		alvo["mundo"] = [mundo.x, mundo.y, mundo.z]
		alvo["chunk"] = [chunk.x, chunk.y]
		fora["alvo"] = alvo
	return fora


func de_dicionario(dados: Dictionary) -> void:
	if dados.is_empty():
		atual = {}
		return
	atual = dados.duplicate(true)
	if not atual.has("alvo"):
		return
	var alvo: Dictionary = atual["alvo"]
	var mundo: Array = alvo["mundo"]
	var chunk: Array = alvo["chunk"]
	alvo["mundo"] = Vector3(float(mundo[0]), float(mundo[1]), float(mundo[2]))
	alvo["chunk"] = Vector2i(int(chunk[0]), int(chunk[1]))
	atual["alvo"] = alvo
