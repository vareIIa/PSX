## Autoload. Sorteia e mantem blitzes perto do jogador.
##
## Mesmo desenho de Transito/Multidao: nasce numa coroa, morre longe, nao entra
## no save. No maximo uma blitz ativa — duas na mesma vista viram carnaval de
## giroflex e matam a leitura da cidade.
extends Node

const MAX_ATIVAS := 1
const RAIO_NASCER_MIN := 42.0
const RAIO_NASCER_MAX := 70.0
const RAIO_SEMEAR_MIN := 22.0
const RAIO_SUMIR := 95.0
const INTERVALO := 1.2
## Chance por tentativa de spawn (depois dos filtros de via).
const CHANCE_SPAWN := 0.35

var raiz: Node3D
var alvo: Node3D
var ativo: bool = false

var _vivas: Array[Blitz] = []
var _relogio: float = 0.0
var _semear: bool = true
var _rng := RandomNumberGenerator.new()
var _testando := false
## Lugares (linha/quadra/eixo/sentido) onde a viatura nao cabe na calcada. A
## sonda custa 55 raios; sem isto ela repetiria a cada tentativa de nascer.
var _recusados: Dictionary = {}


func _ready() -> void:
	_rng.randomize()
	set_process(false)


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
	for b: Blitz in _vivas:
		if is_instance_valid(b):
			b.free()
	_vivas.clear()
	_semear = true


func semear() -> void:
	_semear = true


func vivas() -> int:
	return _vivas.size()


## As blitz montadas agora. A cena de abertura precisa apontar a camera para uma
## delas, e nao ha como fazer isso contando quantas existem.
func lista() -> Array[Blitz]:
	var saida: Array[Blitz] = []
	for b: Blitz in _vivas:
		if is_instance_valid(b):
			saida.append(b)
	return saida


## A blitz que manda no carro nesta posicao, ou null.
func blitz_para(pos: Vector3, trecho_carro: Vector4i) -> Blitz:
	for b: Blitz in _vivas:
		if is_instance_valid(b) and b.influencia(pos, trecho_carro):
			return b
	return null


func _process(delta: float) -> void:
	if not ativo or raiz == null:
		return
	if alvo == null or not is_instance_valid(alvo):
		alvo = get_tree().get_first_node_in_group(&"player") as Node3D
		if alvo == null:
			return
	if Interiores.dentro:
		limpar()
		return
	_relogio += delta
	_recolher()
	if _relogio < INTERVALO and not _semear:
		return
	_relogio = 0.0
	_povoar()


func _recolher() -> void:
	var centro := alvo.global_position
	var i := _vivas.size() - 1
	while i >= 0:
		var b: Blitz = _vivas[i]
		if not is_instance_valid(b):
			_vivas.remove_at(i)
		elif b.global_position.distance_to(centro) > RAIO_SUMIR:
			b.queue_free()
			_vivas.remove_at(i)
		i -= 1


func _povoar() -> void:
	if _vivas.size() >= MAX_ATIVAS:
		_semear = false
		return
	var centro := alvo.global_position
	var minimo := RAIO_SEMEAR_MIN if _semear else RAIO_NASCER_MIN
	var trechos := Vias.trechos_perto(centro, minimo, RAIO_NASCER_MAX)
	if trechos.is_empty():
		_semear = false
		return
	trechos.shuffle()
	for t: Dictionary in trechos:
		var e := _candidato(t)
		if e.is_empty():
			continue
		var d := (e["origem"] as Vector3).distance_to(centro)
		if d < minimo or d > RAIO_NASCER_MAX:
			continue
		if not _semear and _rng.randf() > CHANCE_SPAWN:
			continue
		if _nascer(t, e):
			break
	_semear = false


## Onde a blitz nasce vem de `PlantaBlitz.encaixar`: uma posicao so por quadra
## e por sentido, com a ponta de jusante encostada na folga do cruzamento. A
## amostra do trecho so escolhe a quadra.
func _candidato(t: Dictionary) -> Dictionary:
	var tr: Vector4i = t["trecho"]
	# So a faixa de fora: e ela que vira o bolsao.
	if tr.x != 0:
		return {}
	var e := PlantaBlitz.encaixar(tr, t["de"], t["ponto"])
	if e.is_empty() or _recusados.has(_chave(tr, e)):
		return {}
	var origem: Vector3 = e["origem"]
	var dir: Vector3 = e["dir"]
	var montante := origem - dir * PlantaBlitz.COMPRIMENTO
	for ponta: Vector3 in [origem, montante]:
		if not ChunkManager.esta_carregado(ChunkManager.coord_de(ponta)):
			return {}
	for viva: Blitz in _vivas:
		if is_instance_valid(viva) and viva.global_position.distance_to(origem) < 40.0:
			return {}
	return e


func _nascer(t: Dictionary, e: Dictionary) -> bool:
	var tr: Vector4i = t["trecho"]
	var origem: Vector3 = e["origem"]
	var dir: Vector3 = e["dir"]
	var semente := absi(int(e["linha"]) * 73856093 + int(e["quadra"]) * 19349663
		+ tr.z * 83492791 + tr.w * 2654435761)
	origem.y = Relevo.altura(origem.x, origem.z)
	# Na ladeira (Relevo) a blitz acompanha a rua: reta, a ponta de baixo
	# flutuava e a de cima enterrava.
	var montante := origem - dir * PlantaBlitz.COMPRIMENTO
	var subida := (origem.y - Relevo.altura(montante.x, montante.z)) / PlantaBlitz.COMPRIMENTO
	# looking_at faz -Z apontar para dir: -Z local = fluxo.
	var base := Basis.looking_at(Vector3(dir.x, subida, dir.z).normalized(), Vector3.UP)
	var b := Blitz.new()
	b.name = "blitz_%d" % semente
	raiz.add_child(b)
	b.global_transform = Transform3D(base, origem + Vector3(0.0, 0.02, 0.0))
	# Depois de posicionada: as pecas sao corpos rigidos e nascem no mundo.
	if not b.montar(semente, t, int(e["via"])):
		_recusados[_chave(tr, e)] = true
		b.free()
		return false
	_vivas.append(b)
	# Teste montado da blitz: entra por aqui, e nao pela Cidade, porque precisa
	# da primeira blitz viva e so este autoload sabe quando ela nasce.
	if not _testando and OS.get_cmdline_user_args().has("--teste-blitz"):
		_testando = true
		TesteBlitz.executar(b)
	return true


func _chave(tr: Vector4i, e: Dictionary) -> String:
	return "%d/%d/%d/%d" % [tr.z, int(e["linha"]), int(e["quadra"]), tr.w]
