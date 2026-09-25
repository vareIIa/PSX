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
## A leva planejada pela ultima passada de `_povoar`, que nasce um carro por
## quadro (ver `_nascer_um_da_fila`).
var _fila: Array[Dictionary] = []
var _faltam: int = 0
## Carros ja escolhidos (trecho, semente, ficha) cuja lataria e motorista estao
## sendo montados no WorkerThreadPool (`Carro.encomendar`). Nascem na ordem,
## um por quadro, quando a encomenda fica pronta.
var _encomendados: Array[Dictionary] = []
## Quantos carros encomendados a frente, no maximo.
const ENCOMENDAS_A_FRENTE := 2
## Quadros que um encomendado espera a thread antes de nascer mesmo assim (o
## `_ready` entao monta no fio o que faltar, como antes). Com 8, um em cada
## nove carros vencia a espera com a fila da thread cheia de chunk.
const ESPERA_ENCOMENDA := 30


## `--medir-povoamento`: o pior tempo de cada etapa, em ms, lido pela bancada
## de direcao (tests/bancada_fps_dirigir.gd). Desligado nao custa nada.
static var medir := OS.get_cmdline_user_args().has("--medir-povoamento")
var pior_ms := {}
## `--medir-povoamento`: cada nascimento pela fila acima de 2 ms, com a
## encomenda (pronta ou nao, quadros de espera, se a lataria foi aceita).
var lentos: Array = []
var nascidos_pela_fila := 0


func _medir(etapa: StringName, desde: int) -> void:
	var ms := (Time.get_ticks_usec() - desde) / 1000.0
	if ms > float(pior_ms.get(etapa, 0.0)):
		pior_ms[etapa] = ms


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
	_fila.clear()
	_encomendados.clear()
	_faltam = 0
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
	# A leva da passada sai um carro por quadro, fora do relogio da passada.
	var t := Time.get_ticks_usec()
	if _faltam > 0 and not Interiores.isolado():
		_nascer_um_da_fila()
		if medir:
			_medir(&"fila", t)
	if _relogio < INTERVALO:
		return
	_relogio = 0.0

	# Dentro de um interior a rua nao existe. Manter seis carros com fisica e
	# som circulando por uma cidade que ninguem esta vendo e pagar duas vezes.
	if Interiores.isolado():
		limpar()
		return

	t = Time.get_ticks_usec()
	_recolher()
	if medir:
		_medir(&"recolher", t)
		t = Time.get_ticks_usec()
	_povoar()
	if medir:
		_medir(&"povoar", t)


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
	# A leva anterior ainda esta nascendo: a passada nova espera ela acabar.
	if _faltam > 0:
		return
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

	_faltam = (teto - _vivos.size()) if semeando else mini(2, teto - _vivos.size())
	_fila = trechos
	_semear = false
	_nascer_um_da_fila()


## Faz nascer o proximo carro da leva planejada por `_povoar`: no maximo UM por
## quadro. Cada carro custa 6 a 12 ms para montar (tests/bancada_custo_nascer.gd)
## e a passada punha dois de uma vez em regime e ate seis na semeadura, o que dava
## os quadros de 20 a 27 ms medidos dirigindo. Os criterios sao os de antes,
## tentados na hora de nascer.
##
## Cada carro e escolhido (trecho, semente e ficha) alguns quadros antes de
## nascer, e a lataria e o motorista dele sao encomendados ao WorkerThreadPool
## (`Carro.encomendar`): quando nasce, o `_ready` so pendura o que ja existe.
func _nascer_um_da_fila() -> void:
	if not _encomendados.is_empty():
		var e: Dictionary = _encomendados[0]
		e["quadros"] = int(e["quadros"]) + 1
		var pronta := Carro.encomenda_pronta(e["semente"], e["ficha"])
		if pronta or int(e["quadros"]) > ESPERA_ENCOMENDA:
			_encomendados.pop_front()
			var t: Dictionary = e["trecho"]
			var ponto: Vector3 = t["ponto"]
			# O lugar pode ter mudado nos quadros de espera.
			var t0 := Time.get_ticks_usec()
			if ChunkManager.esta_carregado(ChunkManager.coord_de(ponto)) 					and not _ocupado(ponto, t) and _criar(t, e["semente"], e["ficha"]):
				_faltam -= 1
				if medir:
					nascidos_pela_fila += 1
					var ms := (Time.get_ticks_usec() - t0) / 1000.0
					if ms > 2.0 and lentos.size() < 30:
						lentos.append({"ms": snappedf(ms, 0.1), "pronta": pronta,
							"quadros": e["quadros"], "aceita": e.get("aceita", "?"),
							"modelo": Carro._sortear_modelo(int(e["semente"]))})
	# Encomenda os proximos enquanto faltar carro.
	while _encomendados.size() < mini(_faltam, ENCOMENDAS_A_FRENTE) and not _fila.is_empty():
		var t: Dictionary = _fila.pop_back()
		var ponto: Vector3 = t["ponto"]
		if not ChunkManager.esta_carregado(ChunkManager.coord_de(ponto)):
			continue
		if _ocupado(ponto, t):
			continue
		var escolha := _escolher(t)
		if escolha.is_empty():
			continue
		var aceita := Carro.encomendar(escolha["semente"], escolha["ficha"])
		_encomendados.append({"trecho": t, "semente": escolha["semente"],
			"ficha": escolha["ficha"], "quadros": 0, "aceita": aceita})
	if _encomendados.is_empty() and (_faltam <= 0 or _fila.is_empty()):
		_faltam = 0
		_fila.clear()


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
	# O que ja foi encomendado para nascer ali tambem ocupa a vaga.
	for e: Dictionary in _encomendados:
		var outro: Vector3 = (e["trecho"] as Dictionary)["ponto"]
		if outro != ponto and outro.distance_to(ponto) < RAIO_LISTA:
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
	var escolha := _escolher(t)
	return not escolha.is_empty() and _criar(t, escolha["semente"], escolha["ficha"])


## A semente e o motorista do carro que nasceria neste trecho, ou vazio.
func _escolher(t: Dictionary) -> Dictionary:
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
		return {}
	return {"semente": semente, "ficha": ficha}


func _criar(t: Dictionary, semente: int, ficha: Dictionary) -> bool:
	var de: Vector2i = t["de"]
	var trecho: Vector4i = t["trecho"]
	var t0 := Time.get_ticks_usec()
	var c := Carro.new()
	c.name = "carro_%d" % semente
	c.preparar(ficha, de, trecho, semente)
	# A posicao entra ANTES da arvore (ver o mesmo em `Multidao._criar`): posta
	# depois, o corpo nascia na origem do mundo e o primeiro passo de fisica
	# pagava a viagem. O `_ready` do carro nao le a posicao (a faixa e a rota vem
	# do trecho), e o congelamento dele passa a acontecer ja no lugar certo.
	c.position = raiz.to_local(ponto_de_nascimento(t))
	raiz.add_child(c)
	if medir:
		_medir(&"nascer.add_child", t0)
	c.global_position = ponto_de_nascimento(t)
	_vivos.append(c)
	nascimentos += 1
	_desde_nascimento = 0.0
	t0 = Time.get_ticks_usec()
	carro_chegou.emit(c)
	if medir:
		_medir(&"nascer.sinal", t0)
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
