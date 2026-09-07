## Autoload. Quem poe carro na rua, e quem tira.
##
## Mesmo desenho da Multidao, e de proposito: dois sistemas de povoamento com
## regras diferentes seriam dois lugares para o mesmo defeito aparecer. Nasce
## numa coroa em volta do jogador, morre longe ou fora de chunk montado, e nada
## disso entra no save.
##
## O teto e menor que o de gente e a razao e chamada de desenho, nao memoria:
## uma pessoa custa uma malha e um carro custa quatro — lataria, luzes e os dois
## eixos. Seis carros sao vinte e quatro chamadas, que somadas as quatorze
## pessoas e a cidade cabem no teto de 120 do ART-BIBLE secao 10 com folga para
## interiores.
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
const ESPERA_NASCIMENTO := 1.1

signal carro_chegou(quem: Node3D)

var raiz: Node3D
var alvo: Node3D
var ativo: bool = false

var nascimentos: int = 0
var retirados: int = 0

var _vivos: Array[Carro] = []
## O carro nas maos do jogador. Fica fora da lista para nunca ser recolhido.
var _do_jogador: Carro
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
	if Interiores.dentro:
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

	var faltam := (teto - _vivos.size()) if semeando else 1
	for t: Dictionary in trechos:
		if faltam <= 0:
			break
		var ponto: Vector3 = t["ponto"]
		if not ChunkManager.esta_carregado(ChunkManager.coord_de(ponto)):
			continue
		if _ocupado(ponto):
			continue
		if _nascer(t):
			faltam -= 1
	_semear = false


## Ha alguma coisa na faixa onde o carro nasceria?
##
## A caixa e do tamanho de um carro e um pouco mais: nascer meio metro dentro de
## outro carro poe os dois em contato, e um corpo cinematico sobreposto a outro
## nao se resolve sozinho — ficam os dois ali, atravessados, no meio da rua.
func _ocupado(ponto: Vector3) -> bool:
	if raiz == null or not raiz.is_inside_tree():
		return false
	var espaco := raiz.get_world_3d().direct_space_state
	var forma := BoxShape3D.new()
	forma.size = Vector3(2.6, 1.6, 6.0)
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma
	consulta.collision_mask = 1
	consulta.transform = Transform3D(Basis(), ponto + Vector3(0.0, 0.9, 0.0))
	return not espaco.intersect_shape(consulta, 1).is_empty()


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
	for c: Carro in _vivos:
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
