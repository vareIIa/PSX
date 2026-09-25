## Autoload. O GPS do jogo: os lugares da cidade, o destino escolhido e o
## caminho por rua ate ele.
##
## O que ele e agora
## -----------------
## Ate aqui este arquivo era tambem o DESENHO: o telefone de 1998 deitado na
## frente do rosto, uma moldura de LCD verde pintada por cima da imagem. O
## aparelho do jogo virou o iPhone modelado, na mao do personagem, e o mapa
## virou o app Mapas dele (`AppMapas`), com o aparelho girado nas duas maos.
## O que sobrou aqui e o que nunca foi desenho: onde ficam os lugares, qual
## deles o jogador escolheu e por onde se chega la. O minimapa, a bussola do
## HUD, as missoes e o app leem daqui — o mesmo destino para todos.
##
## `M` continua sendo o atalho: tira o aparelho do bolso ja no Mapas, porque
## olhar o mapa e a coisa que o jogador mais vai querer fazer com ele, e um
## menu no caminho de uma coisa frequente e pedagio.
##
## O mundo continua rodando
## ------------------------
## Nao ha `get_tree().paused`. O jogador para de andar — o aparelho ocupa as
## duas maos — mas a chuva cai, o transito passa e o pedestre atravessa atras
## do telefone. O GPS e um objeto que a pessoa levanta no meio da rua, e nao
## uma tela de menu que congela o jogo.
extends Node

## Categorias da busca, na ordem em que o app as oferece.
##
## A casa da fumaca tem categoria propria, e e a unica planta do jogo que tem.
## Pelo mesmo motivo de ela ter icone proprio no mapa: e o unico endereco da
## cidade que o jogador vai querer reencontrar depois de sair, e procurar uma
## porta verde em vinte quadras iguais e sorte, nao exploracao.
const FILTROS: Array[Dictionary] = [
	{"id": &"tudo", "nome": "TUDO", "icone": &"porta"},
	{"id": &"casa_fumaca", "nome": "CASA VERDE", "icone": &"casa_verde"},
	{"id": &"mercado", "nome": "MERCADO", "icone": &"mercado"},
	{"id": &"bar", "nome": "BAR", "icone": &"bar"},
	{"id": &"casa", "nome": "CASAS", "icone": &"casa"},
	{"id": &"apartamento", "nome": "PORTARIAS", "icone": &"predio"},
	{"id": &"parque", "nome": "PARQUES", "icone": &"parque"},
	{"id": &"telefone", "nome": "ORELHOES", "icone": &"telefone"},
]

## Nome que cada categoria recebe na lista e no balao do alfinete.
const NOMES := {
	&"casa_fumaca": "CASA DA FUMACA",
	&"mercado": "MERCADO",
	&"bar": "BAR DO SEU ZE",
	&"casa": "CASA",
	&"apartamento": "PORTARIA",
	&"telefone": "ORELHAO",
}

const ROSA_DOS_VENTOS: Array[String] = ["N", "NE", "L", "SE", "S", "SO", "O", "NO"]

## Raio da varredura de lugares, em chunks. Nao e o mapa inteiro porque o mapa e
## infinito: um GPS que promete listar tudo esta prometendo uma varredura que
## nunca termina.
##
## Doze e o numero que `tests/custo_gps.gd` mediu: 384 m em volta, 625 chunks,
## 7,3 ms e 213 lugares. Oito chunks ja deixavam o filtro de mercado com dois
## itens; dezesseis custavam 12,4 ms para acrescentar quase so portaria. Os 7 ms
## caem enquanto o aparelho ainda esta subindo do bolso, que e o instante menos
## visivel que existe. Reabrir perto nao paga nada: a varredura fica guardada
## ate o jogador andar REVARRER chunks.
const RAIO_CHUNKS := 12

## Quantos chunks o jogador precisa andar para a varredura valer a pena de novo.
const REVARRER := 4

## Teto de alfinetes de uma busca. Quarenta ja cobrem o quadro inteiro na
## escala fechada; alem disso e mancha, nao informacao.
const MAX_PINOS := 40

signal abriu()
signal fechou()
## Emitido quando o jogador traca ou apaga uma rota. O minimapa ouve: escolher
## um destino no mapa e guardar o aparelho tem de deixar alguma coisa na tela, ou
## a escolha nao serviu para nada.
signal destino_mudou()

## O Mapas esta na tela do aparelho, na mao.
var ativo: bool:
	get:
		return Celular.ativo and Celular.app_atual() == &"mapas"

## Destino tracado, ou vazio. Mesma forma dos itens de `resultados()`.
var destino: Dictionary = {}

## Caminho por rua ate o destino, tracado uma vez na escolha. Vazio sem destino.
##
## Guardado aqui, e nao recalculado por quem desenha, porque quem desenha sao
## varias telas: o cartao do canto, a pagina do pause e o app. Calculos
## separados do mesmo caminho poderiam divergir num quadro em que o jogador anda
## entre um e outro, e o mapa mostraria dois caminhos para o mesmo lugar.
var rota: PackedVector2Array = PackedVector2Array()

## A que distancia da rota o jogador pode andar antes de ela ser refeita.
##
## Meia quadra. Menos que isto e a rota se refaz ao atravessar a rua para pegar
## sombra; muito mais e ela continua apontando uma esquina que ficou para tras.
const DESVIO_MAX := 34.0

## A categoria buscada agora (indice de `FILTROS`) e o resultado escolhido nela.
var filtro: int = 0
var sel: int = 0

var _lugares: Array[Dictionary] = []
var _resultados: Array[Dictionary] = []
var _varrido_em := Vector2i(1 << 20, 1 << 20)
var _estava_ativo: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Celular.abriu.connect(_conferir_ativo)
	Celular.fechou.connect(_conferir_ativo)
	Celular.app_trocou.connect(_conferir_ativo)


## Os sinais `abriu` e `fechou` seguem o app na tela do aparelho: quem ouvia o
## GPS de antes continua ouvindo o Mapas.
func _conferir_ativo() -> void:
	var agora := ativo
	if agora == _estava_ativo:
		return
	_estava_ativo = agora
	if agora:
		abriu.emit()
	else:
		fechou.emit()


# --- abrir e fechar -----------------------------------------------------------

## Tira o aparelho do bolso ja no Mapas. `do_celular` ficou pela assinatura de
## antes: hoje o Mapas e sempre um app do aparelho, e sair dele volta para a
## tela de inicio.
func abrir(_do_celular: bool = false) -> void:
	preparar()
	Celular.abrir_mapas()


## Guarda o aparelho, se o Mapas estiver nele.
func fechar() -> void:
	if ativo:
		Celular.fechar()


## Refaz a lista de lugares em volta de quem esta com o aparelho. O app chama ao
## abrir; a varredura so custa quando o jogador andou.
func preparar() -> void:
	_varrer(posicao())
	_filtrar()


# --- onde esta a pessoa ---------------------------------------------------------

## Onde o GPS acha que a pessoa esta.
##
## Dentro de casa o corpo do jogador esta dois mil metros acima da cidade, num
## comodo que nao tem endereco nenhum — o mapa da rua ali seria ruido puro. O
## aparelho usa entao o ponto de retorno, que e a calcada da porta por onde ele
## entrou, e o app diz que perdeu o sinal. E o que um GPS faz de verdade quando
## perde o ceu: mostra o ultimo lugar em que ele sabia onde estava.
func posicao() -> Vector3:
	if Interiores.dentro:
		return Interiores.posicao_de_retorno()
	var jogador := get_tree().get_first_node_in_group(&"player") as Node3D
	if jogador == null:
		return Vector3.ZERO
	var c: Node = jogador.call(&"carro") if jogador.has_method(&"carro") else null
	if c is Node3D and is_instance_valid(c):
		return (c as Node3D).global_position
	return jogador.global_position


## Para onde a pessoa esta virada, em radianos no `rotation.y` do mundo (0 e o
## norte, -Z).
func rumo() -> float:
	if Interiores.dentro:
		return 0.0
	var jogador := get_tree().get_first_node_in_group(&"player") as Node3D
	return 0.0 if jogador == null else jogador.rotation.y


func sem_sinal() -> bool:
	return Interiores.dentro


# --- varredura de lugares -------------------------------------------------------

## Le a cidade sem construir nada. `pontos_de_interesse` e estatica e devolve o
## mesmo resultado para a mesma coordenada, entao o GPS enxerga vinte quadras
## alem do que o ChunkManager carregou — e por isso que ele consegue apontar uma
## casa da fumaca em rua onde o jogador nunca pisou.
func _varrer(centro: Vector3) -> void:
	var aqui := Vector2i(floori(centro.x / Mapa.TAM), floori(centro.z / Mapa.TAM))
	var perto := absi(aqui.x - _varrido_em.x) < REVARRER \
		and absi(aqui.y - _varrido_em.y) < REVARRER
	if perto and not _lugares.is_empty():
		return
	_varrido_em = aqui
	_lugares.clear()
	for cz in range(aqui.y - RAIO_CHUNKS, aqui.y + RAIO_CHUNKS + 1):
		for cx in range(aqui.x - RAIO_CHUNKS, aqui.x + RAIO_CHUNKS + 1):
			# Com os bares da BarVivo ja vistos (BaresDaCidade).
			for ponto: Dictionary in BaresDaCidade.pontos(cx, cz):
				var lugar := _lugar_de(ponto, cx, cz)
				if not lugar.is_empty():
					_lugares.append(lugar)


func _lugar_de(ponto: Dictionary, cx: int, cz: int) -> Dictionary:
	var categoria: StringName = ponto["tipo"]
	if categoria == &"porta":
		categoria = ponto["interior"]
	var p: Vector3 = ponto["pos"]
	var mundo := Vector3(float(cx) * Mapa.TAM + p.x, p.y, float(cz) * Mapa.TAM + p.z)
	var chunk := Vector2i(cx, cz)
	return {
		"categoria": categoria,
		"nome": String(ponto.get("nome", NOMES.get(categoria, "PONTO"))),
		"mundo": mundo,
		"chunk": chunk,
		"icone": _icone_de(categoria),
		# O nome da rua em frente, e nao o indice do chunk (NomesDeRua).
		"endereco": _endereco(mundo, cx, cz),
	}


static func _endereco(mundo: Vector3, cx: int, cz: int) -> String:
	var rua := NomesDeRua.rua_perto(mundo)
	if rua.is_empty():
		return "%d-%d" % [absi(cx), absi(cz)]
	return rua


static func _icone_de(categoria: StringName) -> StringName:
	match categoria:
		&"casa_fumaca":
			return &"casa_verde"
		&"apartamento":
			return &"predio"
		_:
			return categoria


func _filtrar() -> void:
	var id: StringName = FILTROS[filtro]["id"]
	var de := posicao()
	_resultados.clear()
	for lugar: Dictionary in _lugares:
		if id != &"tudo" and lugar["categoria"] != id:
			continue
		var copia := lugar.duplicate()
		copia["distancia"] = _plano(de).distance_to(_plano(lugar["mundo"]))
		_resultados.append(copia)
	_resultados.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["distancia"]) < float(b["distancia"]))
	if _resultados.size() > MAX_PINOS:
		_resultados.resize(MAX_PINOS)
	sel = 0


## Os lugares da categoria buscada, do mais perto ao mais longe.
func resultados() -> Array[Dictionary]:
	return _resultados


## Troca a categoria da busca. Devolve quantos lugares ela achou.
func escolher_filtro(i: int) -> int:
	filtro = posmod(i, FILTROS.size())
	_varrer(posicao())
	_filtrar()
	return _resultados.size()


## Quantos lugares da categoria `i` ha na varredura (para a lista de busca).
func contagem(i: int) -> int:
	var id: StringName = FILTROS[posmod(i, FILTROS.size())]["id"]
	if id == &"tudo":
		return _lugares.size()
	var n := 0
	for lugar: Dictionary in _lugares:
		if lugar["categoria"] == id:
			n += 1
	return n


static func _plano(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


# --- destino e rota ---------------------------------------------------------------

## Traca a rota ate `lugar`; se ele ja era o destino, apaga. Devolve se ficou
## com rota.
func tracar_para(lugar: Dictionary) -> bool:
	if lugar.is_empty():
		return false
	if eh_destino(lugar):
		limpar_rota()
		return false
	destino = lugar.duplicate()
	_refazer_rota()
	destino_mudou.emit()
	return true


func limpar_rota() -> void:
	if destino.is_empty():
		return
	destino = {}
	rota = PackedVector2Array()
	destino_mudou.emit()


func eh_destino(lugar: Dictionary) -> bool:
	return not destino.is_empty() and not lugar.is_empty() \
		and (destino["mundo"] as Vector3).is_equal_approx(lugar["mundo"])


## Alfinete do destino para quem desenha outro mapa. Vazio quando nao ha rota.
func pinos_do_destino() -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	saida.append_array(Missoes.pinos())
	if not destino.is_empty():
		saida.append({"pos": _plano(destino["mundo"]), "destaque": true})
	return saida


## Recalcula o caminho a partir de onde o jogador esta agora.
func _refazer_rota() -> void:
	if destino.is_empty():
		rota = PackedVector2Array()
		return
	rota = Rota.tracar(posicao(), destino["mundo"])


## Mantem a rota valida enquanto o jogador anda. Chamado de fora, em intervalo
## folgado — quem pergunta e o minimapa, que ja acorda a cada 0,45 s.
##
## Refaz so quando a pessoa saiu do corredor da rota. Recalcular por quadro
## custaria 0,65 ms num caminho de 768 m (`tests/checar_rota.gd`) para redesenhar
## exatamente a mesma linha.
func manter_rota(de: Vector3) -> bool:
	if destino.is_empty() or rota.size() < 2:
		return false
	if Rota.desvio(rota, Vector2(de.x, de.z)) <= DESVIO_MAX:
		return false
	_refazer_rota()
	destino_mudou.emit()
	return true


## Caminho ate o destino, para quem desenha outro mapa. Vazio sem rota.
func rota_do_destino() -> PackedVector2Array:
	return rota


## Distancia e rumo ate a rota, ja formatados. Vazio quando nao ha rota.
func rotulo_do_destino(de: Vector3) -> String:
	if destino.is_empty():
		return ""
	return "%s %s" % [distancia_texto(_plano(de).distance_to(_plano(destino["mundo"]))),
		bussola_texto(de, destino["mundo"])]


## Comprimento do caminho tracado, em metros. Zero sem rota.
func comprimento_da_rota() -> float:
	return Rota.comprimento(rota) if rota.size() >= 2 else 0.0


static func distancia_texto(metros: float) -> String:
	return "%d m" % roundi(metros) if metros < 1000.0 else "%.1f km" % (metros / 1000.0)


## Rumo em ponto cardeal. O norte do mundo e o menos Z, que e o mesmo norte que a
## rosa do minimapa desenha — se as duas discordassem, o GPS mandaria o jogador
## para o lado contrario do que a bussola do canto mostra.
static func bussola_texto(de: Vector3, para: Vector3) -> String:
	var d := _plano(para) - _plano(de)
	if d.length_squared() < 1.0:
		return "AQUI"
	var setor := roundi(atan2(d.x, -d.y) / (PI / 4.0))
	return ROSA_DOS_VENTOS[posmod(setor, 8)]


# --- entrada ------------------------------------------------------------------------

func _pode_abrir() -> bool:
	return not (Conversa.ativo or Dialogo.ativo or Documento.ativo
		or Terminal.ativo or get_tree().paused)


## `M` tira o aparelho ja no Mapas; com o aparelho na mao, troca para ele; com o
## Mapas na tela, guarda — quem apertou M queria o mapa, nao o menu do aparelho.
func _input(evento: InputEvent) -> void:
	if not evento.is_action_pressed("gps"):
		return
	if ativo:
		Celular.fechar()
	elif Celular.ativo:
		preparar()
		Celular.abrir_mapas()
	elif _pode_abrir():
		abrir()
	else:
		return
	get_viewport().set_input_as_handled()


# --- consulta de fora ---------------------------------------------------------------

## Publica: a verificacao automatizada traca a rota do primeiro resultado sem
## depender de tecla.
func tracar_rota_no_primeiro() -> void:
	sel = 0
	if not _resultados.is_empty() and not eh_destino(_resultados[0]):
		tracar_para(_resultados[0])


## Publica: a verificacao automatizada escolhe uma categoria sem depender de
## tecla. Com o Mapas aberto, os alfinetes caem na hora.
func filtrar_por(id: StringName) -> int:
	for i in FILTROS.size():
		if StringName(FILTROS[i]["id"]) == id:
			var n := escolher_filtro(i)
			Celular.mapas_mudou_busca()
			return n
	return -1
