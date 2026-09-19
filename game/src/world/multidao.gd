## Autoload. Quem povoa a rua, e quem tira as pessoas dela.
##
## A cidade e infinita e as pessoas nao podem ser. Entao a multidao funciona como
## o streaming de chunk: mantem um punhado de gente viva perto do jogador e
## solta quem ficou para tras. A diferenca e que chunk e deterministico pela
## coordenada e pessoa nao pode ser — se fosse, a mesma senhora estaria parada na
## mesma esquina toda vez que o jogador voltasse, e a rua viraria um museu.
##
## O meio termo: QUEM aparece e deterministico pela esquina, mas quando e quantos
## nao sao. A esquina da avenida com a rua do mercado tende a produzir as mesmas
## poucas pessoas, entao o bairro tem caras conhecidas; a hora em que elas estao
## la, nao.
##
## Nada disto entra no save. O que precisa sobreviver e so quem o jogador
## abordou, e isso mora no RegistroCivil, indexado por id.
extends Node

## Teto de gente viva. Cada pessoa e uma malha e meia chamada de desenho medida;
## quatorze cabem no orcamento do ART-BIBLE secao 10 com folga para a cidade, e
## abaixo disso a rua le como deserta — que e o defeito que isto conserta.
const POPULACAO_BASE := 14

## Coroa de nascimento em regime. Vinte e quatro metros e o comeco: dentro da
## nevoa leve, que enxerga 45 m, mas longe o bastante para ninguem ver alguem
## surgir do nada.
const RAIO_NASCER_MIN := 24.0
const RAIO_NASCER_MAX := 42.0
## Coroa da SEMEADURA, que e outra coisa. Quando a rua acabou de aparecer — no
## comeco da partida, ao sair de um interior, ao carregar um save — ninguem viu
## o que havia antes, entao nao ha pop-in a esconder e a gente pode nascer perto.
## Sem isto o jogador passa os primeiros seis segundos numa cidade morta e as
## pessoas ficam todas no limite da visibilidade, que era a queixa.
const RAIO_SEMEAR_MIN := 9.0
## Alem disso a pessoa e liberada. Bem depois do raio de nascimento, senao ela
## nasce e morre em ciclo enquanto o jogador anda de um lado para o outro.
##
## E abaixo do raio de chunk carregado, que no preset leve da 64 m em cruz e
## menos na diagonal. Fora dele nao ha calcada montada: o raio de assentamento
## nao acha chao, a pessoa congela na ultima altura e fica flutuando sobre o
## nada. Ninguem ve, porque a nevoa cobre 45 m — e por isso mesmo era preciso
## que o teste visse.
const RAIO_SUMIR := 52.0

const INTERVALO := 0.4
## Espaco minimo entre dois nascimentos, para a rua nao encher de uma vez.
const ESPERA_NASCIMENTO := 0.7

## Conversa de rua: distancia maxima entre dois e quanto tempo ela dura.
const DISTANCIA_CONVERSA := 4.2
const DURACAO_CONVERSA := Vector2(7.0, 16.0)

signal alguem_chegou(quem: Node3D)

var raiz: Node3D
var alvo: Node3D
var ativo: bool = false
## Liga e desliga a formacao de novas conversas entre pedestres. Existe para a
## verificacao poder medir UMA conversa do comeco ao fim sem que a multidao
## forme outra por cima dela no meio da medida.
var convivio: bool = true

## Estatisticas lidas pelo overlay e pela verificacao.
var nascimentos: int = 0
## Quantas pessoas foram recolhidas por terem desistido de andar. Um punhado por
## partida e normal numa cidade gerada; muitos quer dizer que a calcada virou
## armadilha e o numero denuncia isso sem ninguem precisar ver.
var retirados: int = 0

var _vivos: Array[Pedestre] = []
## Enquanto verdadeiro, a proxima passada enche a rua de uma vez e de perto, em
## vez de pingar uma pessoa a cada ESPERA_NASCIMENTO.
var _semear: bool = true
var _relogio: float = 0.0
var _desde_nascimento: float = 0.0
var _desde_conversa: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	set_process(false)
	# Recolher na hora em que o chao some, e nao no proximo ciclo de 0,4 s. A
	# janela entre as duas coisas e curta e mesmo assim aparecia: o jogador
	# atravessa uma fronteira, o chunk sai, e por uma fracao de segundo ha gente
	# em pe sobre o nada — que o raio de assentamento nao acha e que congela na
	# ultima altura conhecida.
	ChunkManager.chunk_descarregado.connect(_ao_descarregar)


func _ao_descarregar(coord: Vector2i) -> void:
	for i in range(_vivos.size() - 1, -1, -1):
		var p := _vivos[i]
		if not is_instance_valid(p):
			_vivos.remove_at(i)
			continue
		# Quem esta conversando com o jogador nunca e recolhido, nem quando o chao
		# some: a caixa de fala ficaria aberta com ninguem do outro lado.
		if Conversa.ativo and Conversa.quem() == p:
			continue
		if ChunkManager.coord_de(p.global_position) == coord:
			_vivos.remove_at(i)
			p.queue_free()


func iniciar(nova_raiz: Node3D, novo_alvo: Node3D = null) -> void:
	raiz = nova_raiz
	alvo = novo_alvo
	ativo = true
	_semear = true
	set_process(true)


## Pede uma rua cheia na proxima passada. Quem trocou o mundo debaixo do jogador
## chama isto: sair de um interior, carregar um save, teleportar.
func semear() -> void:
	_semear = true


func parar() -> void:
	ativo = false
	set_process(false)
	limpar()


func limpar() -> void:
	for p: Pedestre in _vivos:
		if is_instance_valid(p):
			p.free()
	_vivos.clear()
	# Quem esvaziou a rua vai querer ela cheia de novo, e nao pingando.
	_semear = true


## Assume uma pessoa que nasceu fora daqui.
##
## Quem desce de um carro vira pedestre como qualquer outro, e precisa entrar na
## contabilidade da multidao — senao ele nunca e recolhido e a cidade acumula um
## morador extra a cada carro abordado.
func adotar(p: Pedestre) -> void:
	if p == null or not is_instance_valid(p) or _vivos.has(p):
		return
	_vivos.append(p)


func vivos() -> int:
	return _vivos.size()


func lista() -> Array[Pedestre]:
	return _vivos.duplicate()


func _exit_tree() -> void:
	parar()


func _process(delta: float) -> void:
	if not ativo or raiz == null:
		return
	if alvo == null:
		alvo = get_tree().get_first_node_in_group(&"player") as Node3D
		if alvo == null:
			return

	_desde_nascimento += delta
	_desde_conversa += delta
	_relogio += delta
	if _relogio < INTERVALO:
		return
	_relogio = 0.0

	# Dentro de um interior a rua nao existe: o chunk continua carregado mas o
	# jogador nao ve nada dela. Manter dez pessoas andando la fora seria pagar
	# fisica e animacao por uma cena que ninguem esta vendo.
	if Interiores.isolado():
		limpar()
		return

	_recolher()
	_povoar()
	_casar_conversas()


func _recolher() -> void:
	var centro := alvo.global_position
	for i in range(_vivos.size() - 1, -1, -1):
		var p := _vivos[i]
		if not is_instance_valid(p):
			_vivos.remove_at(i)
			continue
		# Quem esta conversando com o jogador nunca e recolhido, por longe que o
		# jogador ande: a caixa de fala ficaria aberta com ninguem do outro lado.
		if Conversa.ativo and Conversa.quem() == p:
			continue
		# Duas razoes para recolher, e a segunda importa mais que a primeira:
		# longe demais, ou fora do bairro montado. Sem chunk embaixo nao ha
		# calcada, o raio de assentamento nao acha chao e a pessoa congela
		# flutuando sobre o nada. Distancia sozinha nao pega isso: o raio de
		# carga e uma cruz de chunks, e a diagonal dela e mais curta.
		var fora := p.global_position.distance_to(centro) > RAIO_SUMIR
		if not fora and not ChunkManager.esta_carregado(
				ChunkManager.coord_de(p.global_position)):
			fora = true
		# Terceira razao para recolher: desistiu de andar. Uma pessoa que passou
		# metade da vida empurrando alguma coisa nao vai destravar sozinha — o
		# lugar onde ela esta e que e ruim. Some com ela e deixa a multidao pôr
		# outra em outro canto; ninguem ve, porque isso acontece a mais de vinte
		# metros dentro da nevoa.
		if not fora and p.vivo_ha() > 6.0 and p.fracao_travada() > 0.55:
			fora = true
			retirados += 1
		if fora:
			_vivos.remove_at(i)
			p.queue_free()


func _povoar() -> void:
	var semeando := _semear
	if not semeando and _desde_nascimento < ESPERA_NASCIMENTO:
		return
	var centro := alvo.global_position
	var no_perto := Rotas.no_mais_proximo(centro)
	# O tamanho da multidao segue o distrito onde o jogador esta. Sair do
	# comercio para o galpao industrial e ver a rua esvaziar sozinha.
	var teto := maxi(1, roundi(POPULACAO_BASE * Rotas.movimento(no_perto)))
	if _vivos.size() >= teto:
		_semear = false
		return

	var minimo := RAIO_SEMEAR_MIN if semeando else RAIO_NASCER_MIN
	var trechos := Rotas.trechos_perto(centro, minimo, RAIO_NASCER_MAX)
	if trechos.is_empty():
		_semear = false
		return
	trechos.shuffle()

	# Semeando, a rua enche de uma vez; em regime, uma pessoa por passada, para
	# ninguem ver tres surgirem no mesmo quarteirao.
	var faltam := (teto - _vivos.size()) if semeando else 1
	for trecho: Dictionary in trechos:
		if faltam <= 0:
			break
		var ponto: Vector3 = trecho["ponto"]
		# Sem chunk montado nao ha calcada: a pessoa nasceria no ar e o raio de
		# assentamento nao acharia chao nenhum embaixo dela.
		if not ChunkManager.esta_carregado(ChunkManager.coord_de(ponto)):
			continue
		if not semeando and Rotas.movimento(trecho["de"]) < _rng.randf():
			continue
		if _ocupado(ponto):
			continue
		if _nascer(trecho):
			faltam -= 1
	_semear = false


## Ha alguma coisa solida onde a pessoa nasceria?
##
## A linha de marcha corre no meio da calcada, mas a calcada tem poste, arvore,
## orelhao, maquina de venda e banco — e a amostragem do trecho nao sabe disso.
## Nascer dentro de um poste prende a pessoa para sempre: ela empurra o cilindro,
## nao sai do lugar, e nenhuma troca de destino resolve, porque o problema nao e
## para onde ela vai e sim onde ela esta. Uma consulta de forma antes de nascer
## custa quase nada e elimina a classe inteira.
func _ocupado(ponto: Vector3) -> bool:
	if raiz == null or not raiz.is_inside_tree():
		return false
	var espaco := raiz.get_world_3d().direct_space_state
	var forma := CapsuleShape3D.new()
	forma.radius = 0.3
	forma.height = 1.3
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma
	consulta.collision_mask = 1
	consulta.transform = Transform3D(Basis(), ponto + Vector3(0.0, 0.95, 0.0))
	return not espaco.intersect_shape(consulta, 1).is_empty()


func _nascer(trecho: Dictionary) -> bool:
	var de: Vector4i = trecho["de"]
	var id := _sortear_id(de)
	if id < 0:
		return false
	var ficha := RegistroCivil.identidade(id)
	if ficha.is_empty():
		return false

	var p := Pedestre.new()
	p.name = "pedestre_%d" % id
	p.preparar(ficha, de, trecho["para"])
	raiz.add_child(p)
	# A posicao vem depois de entrar na arvore: antes dela global_position ainda
	# nao existe e o pedestre nasce na origem do mundo.
	p.global_position = (trecho["ponto"] as Vector3) + Vector3(0.0, 0.1, 0.0)
	_vivos.append(p)
	nascimentos += 1
	_desde_nascimento = 0.0
	alguem_chegou.emit(p)
	return true


## Quem anda por este trecho. A esquina de origem da a familia de candidatos e o
## sorteio escolhe um deles, entao o bairro tem caras conhecidas sem elenco fixo.
func _sortear_id(esquina: Vector4i) -> int:
	for tentativa in 12:
		var chave := (esquina.x * 73856093 + esquina.y * 19349663
			+ esquina.z * 83492791 + esquina.w * 2654435761
			+ _rng.randi_range(0, 5) * 40503)
		# Quem pode estar na rua e decisao do registro, nao daqui: ver
		# RegistroCivil.id_de_transeunte.
		var id := RegistroCivil.id_de_transeunte(_espalhar(chave))
		if RegistroCivil.identidade(id).is_empty():
			continue
		if _ja_esta_na_rua(id):
			continue
		return id
	return -1


func _ja_esta_na_rua(id: int) -> bool:
	for p: Pedestre in _vivos:
		if is_instance_valid(p) and int(p.ficha.get("id", -1)) == id:
			return true
	return false


static func _espalhar(x: int) -> int:
	var h := (x ^ (x >> 27)) * 1274126177
	h = (h ^ (h >> 31)) * 668265263
	h = h ^ (h >> 29)
	return absi(h) if h != -9223372036854775808 else 11


## Junta dois que estao perto e livres. A conversa entre NPCs e a coisa que mais
## barato transforma "bonecos andando" em "rua com gente": duas pessoas paradas
## de frente uma para a outra ja contam uma historia que ninguem escreveu.
func _casar_conversas() -> void:
	if not convivio or _desde_conversa < 4.0 or _vivos.size() < 2:
		return
	for i in _vivos.size():
		var a := _vivos[i]
		if not is_instance_valid(a) or not a.esta_livre():
			continue
		for j in range(i + 1, _vivos.size()):
			var b := _vivos[j]
			if not is_instance_valid(b) or not b.esta_livre():
				continue
			if a.global_position.distance_to(b.global_position) > DISTANCIA_CONVERSA:
				continue
			var duracao := _rng.randf_range(DURACAO_CONVERSA.x, DURACAO_CONVERSA.y)
			a.iniciar_conversa(b, duracao)
			b.iniciar_conversa(a, duracao)
			_desde_conversa = 0.0
			return
