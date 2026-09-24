## Autoload. Quem poe carro na rua, e quem tira.
##
## Mesmo desenho da Multidao, e de proposito: dois sistemas de povoamento com
## regras diferentes seriam dois lugares para o mesmo defeito aparecer. Nasce
## numa coroa em volta do jogador, morre longe ou fora de chunk montado, e nada
## disso entra no save.
##
## O teto e menor que o de gente e a razao e chamada de desenho, nao memoria:
## uma pessoa custa uma malha e um carro custa SEIS — lataria, luzes, os dois
## eixos e os dois fachos de farol. Seis carros sao trinta e seis chamadas, que
## somadas as quatorze pessoas e a cidade cabem no teto de 120 do ART-BIBLE
## secao 10 com folga para interiores.
##
## Eram cinco ate o farol virar dois cones. A conta escrita aqui dizia quatro e
## ja estava errada antes disso — nao contava o facho —, entao vale a regra: quem
## acrescentar malha ao Carro atualiza esta linha, porque ela e o unico lugar em
## que o custo do transito esta somado.
##
## O carro que o jogador esta dirigindo nunca e recolhido, por longe que ele
## dirija: ele sai da lista de vivos e passa a ser problema de quem esta ao
## volante.
extends Node

const POPULACAO_BASE := 6

const RAIO_NASCER_MIN := 34.0
const RAIO_NASCER_MAX := 58.0
## Alem disso o carro e liberado. Mais longe que o do pedestre porque um carro
## cobre a coroa inteira em cinco segundos, e reciclar a essa taxa faz o
## transito piscar no retrovisor.
const RAIO_SUMIR := 74.0
## Na semeadura pode nascer perto: ninguem viu a rua antes de ela existir.
const RAIO_SEMEAR_MIN := 16.0

const INTERVALO := 0.5
const ESPERA_NASCIMENTO := 0.35

signal carro_chegou(quem: Node3D)

var raiz: Node3D
var alvo: Node3D
var ativo: bool = false

var nascimentos: int = 0
var retirados: int = 0

var _vivos: Array[Carro] = []
## O carro nas maos do jogador. Fica fora da lista para nunca ser recolhido.
var _do_jogador: Carro
## Carros parados que nao sao do transito: a viatura da blitz e quem mais for
## estacionado por outro sistema. Ficam fora de `_vivos` para nao comer a cota
## de populacao nem serem recolhidos por aqui — o dono cuida deles —, mas o
## jogador precisa acha-los para entrar. Ver `mais_perto`.
var _estacionados: Array[Carro] = []
var _semear: bool = true
var _relogio: float = 0.0
var _desde_nascimento: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	set_process(false)
	ChunkManager.chunk_descarregado.connect(_ao_descarregar)


func iniciar(nova_raiz: Node3D, novo_alvo: Node3D = null) -> void:
	raiz = nova_raiz
	alvo = novo_alvo
	ativo = true
	# Os cascos de todos os modelos, agora, com a cidade ainda carregando: sem
	# isto a primeira aparicao de cada modelo custava 35 a 70 ms no meio da rua.
	# Ver `Carroceria.aquecer`.
	print("[transito] cascos aquecidos em %.0f ms" % Carroceria.aquecer())
	_semear = true
	set_process(true)


func parar() -> void:
	ativo = false
	set_process(false)
	limpar()


func limpar() -> void:
	for c: Carro in _vivos:
		if is_instance_valid(c):
			c.free()
	_vivos.clear()
	_semear = true


func semear() -> void:
	_semear = true


func vivos() -> int:
	return _vivos.size()


func lista() -> Array[Carro]:
	return _vivos.duplicate()


## O carro que o jogador assumiu sai da contabilidade do transito.
func entregar_ao_jogador(c: Carro) -> void:
	_do_jogador = c
	_vivos.erase(c)
	_estacionados.erase(c)


## Um carro parado que o jogador pode tomar, com dono de fora do transito.
func registrar_estacionado(c: Carro) -> void:
	if c != null and not _estacionados.has(c):
		_estacionados.append(c)


func esquecer_estacionado(c: Carro) -> void:
	_estacionados.erase(c)


## Ainda e do dono de fora? Deixa de ser quando o jogador o toma.
func estacionado(c: Carro) -> bool:
	return _estacionados.has(c)


func devolver_do_jogador() -> void:
	var c := _do_jogador
	_do_jogador = null
	if c == null or not is_instance_valid(c):
		return
	# Volta para a lista de vivos, e com isso volta a poder ser recolhido quando
	# o jogador se afastar. Sem esta linha todo carro que o jogador estacionasse
	# ficaria na cidade para sempre — vinte partidas depois, vinte carros
	# parados, cada um com quatro chamadas de desenho e um raio de assentamento.
	#
	# Nao volta a andar: um carro estacionado com o motor desligado e um lugar
	# da cidade, e nao um defeito.
	if not _vivos.has(c):
		_vivos.append(c)


func do_jogador() -> Carro:
	return _do_jogador


func _exit_tree() -> void:
	parar()


func _ao_descarregar(coord: Vector2i) -> void:
	for i in range(_vivos.size() - 1, -1, -1):
		var c := _vivos[i]
		if not is_instance_valid(c):
			_vivos.remove_at(i)
			continue
		if c == _do_jogador or c.motorista == Carro.Motorista.JOGADOR:
			continue
		if ChunkManager.coord_de(c.global_position) == coord:
			_vivos.remove_at(i)
			c.queue_free()


func _process(delta: float) -> void:
	# Relogio do sinal: avanca mesmo sem poste montado neste chunk. Congela com
	# tree.paused porque este _process para junto.
	Semaforo.avancar(delta)
	if not ativo or raiz == null:
		return
	if alvo == null:
		alvo = get_tree().get_first_node_in_group(&"player") as Node3D
		if alvo == null:
			return

	_desde_nascimento += delta
	_relogio += delta
	if _relogio < INTERVALO:
		return
	_relogio = 0.0

	# Dentro de um interior a rua nao existe. Manter seis carros com fisica e
	# som circulando por uma cidade que ninguem esta vendo e pagar duas vezes.
	if Interiores.isolado():
		limpar()
		return

	_recolher()
	_povoar()


func _recolher() -> void:
	var centro := alvo.global_position
	for i in range(_vivos.size() - 1, -1, -1):
		var c := _vivos[i]
		if not is_instance_valid(c):
			_vivos.remove_at(i)
			continue
		if c == _do_jogador or c.motorista == Carro.Motorista.JOGADOR:
			continue
		# O jogador esta conversando com este motorista? Recolher agora deixaria
		# a caixa de fala aberta com ninguem do outro lado.
		if Conversa.ativo and Conversa.quem() == c:
			continue
		var fora := c.global_position.distance_to(centro) > RAIO_SUMIR
		if not fora and not ChunkManager.esta_carregado(
				ChunkManager.coord_de(c.global_position)):
			fora = true
		if fora:
			_vivos.remove_at(i)
			c.queue_free()
			retirados += 1


func _povoar() -> void:
	var semeando := _semear
	if not semeando and _desde_nascimento < ESPERA_NASCIMENTO:
		return
	var centro := alvo.global_position
	var cruz := Vias.cruzamento_mais_proximo(centro)
	var teto := maxi(1, roundi(POPULACAO_BASE * Vias.movimento(cruz.x, cruz.y)))
	if _vivos.size() >= teto:
		_semear = false
		return

	var minimo := RAIO_SEMEAR_MIN if semeando else RAIO_NASCER_MIN
	var trechos := Vias.trechos_perto(centro, minimo, RAIO_NASCER_MAX)
	if trechos.is_empty():
		_semear = false
		return
	trechos.shuffle()

	var faltam := (teto - _vivos.size()) if semeando else mini(2, teto - _vivos.size())
	for t: Dictionary in trechos:
		if faltam <= 0:
			break
		var ponto: Vector3 = t["ponto"]
		if not ChunkManager.esta_carregado(ChunkManager.coord_de(ponto)):
			continue
		if _ocupado(ponto, t):
			continue
		if _nascer(t):
			faltam -= 1
	_semear = false


## Ha algum carro na faixa onde nasceria outro?
##
## A caixa alinha com a faixa (nao com o mundo) e fica curta e levantada: a
## versao axis-aligned de 6 m atravessava o meio-fio e a calcada do chunk, e o
## nascimento nunca saia do falso-positivo.
##
## Contam carro, pedestre e o jogador; calcada e predio nao bloqueiam vaga.
## Deixar so o carro na conta e o extremo oposto do defeito antigo: o transito
## volta a existir, mas nasce POR CIMA de quem esta parado na pista — e quem
## acaba de sair de uma porta esta parado na pista. O corpo entrando dentro do
## jogador empurra ele varios metros, e a viagem de ida e volta ao interior
## deixa de terminar onde comecou.
func _ocupado(ponto: Vector3, t: Dictionary) -> bool:
	if raiz == null or not raiz.is_inside_tree():
		return false
	# Atalho barato pela lista conhecida (inclui o carro do jogador).
	const RAIO_LISTA := 4.2
	for c: Carro in _vivos:
		if is_instance_valid(c) and c.global_position.distance_to(ponto) < RAIO_LISTA:
			return true
	if _do_jogador != null and is_instance_valid(_do_jogador):
		if _do_jogador.global_position.distance_to(ponto) < RAIO_LISTA:
			return true

	var trecho: Vector4i = t["trecho"]
	var dir := Vias.direcao(trecho.z, trecho.w)
	var espaco := raiz.get_world_3d().direct_space_state
	var forma := BoxShape3D.new()
	# Largura cabe na faixa; comprimento curto ao longo da pista; altura acima do meio-fio.
	forma.size = Vector3(1.8, 1.0, 3.2)
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma
	consulta.collision_mask = 1
	# Basis.looking_at: -Z aponta na direcao da faixa.
	var basis := Basis.looking_at(dir, Vector3.UP)
	consulta.transform = Transform3D(basis, ponto + Vector3(0.0, 1.1, 0.0))
	for hit: Dictionary in espaco.intersect_shape(consulta, 8):
		var col: Object = hit.get("collider")
		if col is Carro or col is Pedestre or (col is Node
				and (col as Node).is_in_group(&"player")):
			return true
	return false


func _nascer(t: Dictionary) -> bool:
	var de: Vector2i = t["de"]
	var trecho: Vector4i = t["trecho"]
	var semente := absi(de.x * 73856093 + de.y * 19349663
		+ trecho.z * 83492791 + trecho.w * 2654435761 + _rng.randi_range(0, 999) * 40503)

	# Todo carro tem um motorista de verdade, tirado do registro. E o que faz
	# "peca ele para sair do carro" terminar numa pessoa com nome, CPF e
	# familia, em vez de num boneco descartavel.
	var id := RegistroCivil.id_de_transeunte(semente)
	var ficha := RegistroCivil.identidade(id)
	if ficha.is_empty():
		return false

	var c := Carro.new()
	c.name = "carro_%d" % semente
	c.preparar(ficha, de, trecho, semente)
	raiz.add_child(c)
	c.global_position = ponto_de_nascimento(t)
	_vivos.append(c)
	nascimentos += 1
	_desde_nascimento = 0.0
	carro_chegou.emit(c)
	return true


## Onde o carro encosta no chao.
##
## A origem do Carro E o plano de contato do pneu: a roda tem centro em
## RAIO_RODA e raio RAIO_RODA, entao a banda toca exatamente em y = 0 do no. Por
## isso o nascimento nao soma a altura da roda — somar poria o carro flutuando
## trinta centimetros ate o primeiro quadro corrigir, e a correcao apareceria
## como um tranco.
static func ponto_de_nascimento(t: Dictionary) -> Vector3:
	var p: Vector3 = t["ponto"]
	return p + Vector3(0.0, 0.05, 0.0)


## O carro mais proximo de um ponto, dentro de um raio. E o que a tecla de
## entrar no veiculo consulta.
func mais_perto(pos: Vector3, raio: float) -> Carro:
	var melhor: Carro = null
	var melhor_d := raio
	for grupo: Array[Carro] in [_vivos, _estacionados]:
		for c: Carro in grupo:
			if not is_instance_valid(c):
				continue
			var d := c.global_position.distance_to(pos)
			if d < melhor_d:
				melhor_d = d
				melhor = c
	if _do_jogador != null and is_instance_valid(_do_jogador):
		var d := _do_jogador.global_position.distance_to(pos)
		if d < melhor_d:
			melhor = _do_jogador
	return melhor
