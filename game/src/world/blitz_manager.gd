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
## Longe o bastante de qualquer cruzamento para cones nao entrarem na caixa.
const FOLGA_CRUZAMENTO := 14.0
## Chance por tentativa de spawn (depois dos filtros de via).
const CHANCE_SPAWN := 0.35

var raiz: Node3D
var alvo: Node3D
var ativo: bool = false

var _vivas: Array[Blitz] = []
var _relogio: float = 0.0
var _semear: bool = true
var _rng := RandomNumberGenerator.new()


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


## O que um carro da IA precisa saber sobre blitz na posicao atual.
##
## Devolve {} se nao ha blitz relevante. Campos:
##   blitz, parar, mira, teto
func consulta(pos: Vector3, trecho_carro: Vector4i, semente_carro: int) -> Dictionary:
	for b: Blitz in _vivas:
		if not is_instance_valid(b):
			continue
		if not b.influencia(pos, trecho_carro):
			continue
		var parar := b.selecionado_para_parar(semente_carro)
		# Mira estavel: quem para mira o ponto so ate frear; a FSM assume depois.
		var mira := b.ponto_de_parada() if parar else b.mira_desvio(pos)
		# Tenta puxar carro parado para a coreografia (no-op se ja tem um).
		# Carro e resolvido via grupo / instancia na consulta — quem chama e Carro.
		return {
			"blitz": b,
			"parar": parar,
			"mira": mira,
			"teto": b.teto_na_zona(pos, parar),
		}
	return {}


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
	# Prefere avenida.
	trechos.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _peso_via(a) > _peso_via(b)
	)
	for t: Dictionary in trechos:
		if not _candidato_valido(t):
			continue
		if not _semear and _rng.randf() > CHANCE_SPAWN:
			continue
		if _nascer(t):
			break
	_semear = false


func _peso_via(t: Dictionary) -> float:
	var tr: Vector4i = t["trecho"]
	var de: Vector2i = t["de"]
	var via := (MalhaUrbana.via_x(de.x) if tr.z == 0 else MalhaUrbana.via_z(de.y))
	return 2.0 if via == MalhaUrbana.Via.AVENIDA else 1.0


func _candidato_valido(t: Dictionary) -> bool:
	var ponto: Vector3 = t["ponto"]
	if not ChunkManager.esta_carregado(ChunkManager.coord_de(ponto)):
		return false
	# Longe de cruzamentos (extremos do trecho).
	var de: Vector2i = t["de"]
	var para: Vector2i = t["para"]
	var a := Vector3(float(de.x) * Vias.TAM, 0.0, float(de.y) * Vias.TAM)
	var b := Vector3(float(para.x) * Vias.TAM, 0.0, float(para.y) * Vias.TAM)
	if ponto.distance_to(a) < FOLGA_CRUZAMENTO:
		return false
	if ponto.distance_to(b) < FOLGA_CRUZAMENTO:
		return false
	# So faixa de fora (0): e ela que encosta no acostamento.
	var tr: Vector4i = t["trecho"]
	if tr.x != 0:
		return false
	# So avenida: acostamento largo e faixa interna para desvio limpo.
	var via := (MalhaUrbana.via_x(de.x) if tr.z == 0 else MalhaUrbana.via_z(de.y))
	if via != MalhaUrbana.Via.AVENIDA:
		return false
	# Nao sobrepor outra blitz.
	for viva: Blitz in _vivas:
		if is_instance_valid(viva) and viva.global_position.distance_to(ponto) < 40.0:
			return false
	return true


func _nascer(t: Dictionary) -> bool:
	var ponto: Vector3 = t["ponto"]
	var tr: Vector4i = t["trecho"]
	var de: Vector2i = t["de"]
	var semente := absi(de.x * 73856093 + de.y * 19349663
		+ tr.z * 83492791 + tr.w * 2654435761 + int(ponto.x * 10.0))
	var b := Blitz.new()
	b.name = "blitz_%d" % semente
	b.montar(semente, t)
	raiz.add_child(b)
	# Orientacao: -Z local = direcao do fluxo.
	var dir := Vias.direcao(tr.z, tr.w)
	# Na ladeira (Relevo) o funil acompanha a rua; reto, os cones da ponta de
	# baixo flutuavam e os da de cima enterravam.
	var adiante := ponto + dir * 9.0
	var atras := ponto - dir * 9.0
	var subida := (Relevo.altura(adiante.x, adiante.z) - Relevo.altura(atras.x, atras.z)) / 18.0
	var basis := Basis.looking_at(Vector3(dir.x, subida, dir.z).normalized(), Vector3.UP)
	# looking_at faz -Z apontar para dir — perfeito.
	b.global_transform = Transform3D(basis, ponto + Vector3(0.0, 0.02, 0.0))
	_vivas.append(b)
	return true
