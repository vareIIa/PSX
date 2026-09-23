## A blitz no caminho de quem anda com mercadoria.
##
## A blitz da avenida ja existia e parava so os carros da IA; o jogador passava
## pelo funil como turista. Agora, a pe e com maconha, Super ou semente no bolso,
## entrar no funil pode render abordagem: o policial chama, a conversa abre (a
## mesma caixa das pessoas da rua, com um contexto proprio) e ha tres saidas —
## colaborar e perder a mercadoria, oferecer um "cafe" e torcer, ou correr.
##
## E o X9: um cliente em cada tantos entrega o jogador. Depois de receber, a
## policia sabe — uma blitz nasce por perto e, por alguns minutos, toda blitz para
## quem estiver com mercadoria. Se quem entregou foi a equipe, ela e que e
## abordada e some por um tempo.
##
## So le a blitz pela API publica (`BlitzManager.lista`, `Blitz.to_local`); nada
## no arquivo da blitz foi mexido.
class_name BlitzNoCaminho
extends Node

## O que a policia leva, e quanto vale na conta do cafe.
const MERCADORIA := {&"maconha": 15, &"super_maconha": 60, &"semente_maconha": 5}
## Chance de ser abordado ao entrar no funil com mercadoria. Procurado, sempre.
const CHANCE := 0.4
## Minutos de jogo em que o jogador fica marcado depois de um X9.
const PROCURADO_MIN := 4.0
const CAFE_BASE := 30

static var procurado_ate := -1.0

var _testadas: Dictionary = {}
var _tique := 0.0
var _rng := RandomNumberGenerator.new()
var _blitz_atual: Node3D
var _oficial: Node3D


func _ready() -> void:
	add_to_group(&"blitz_no_caminho")
	_rng.randomize()


static func instancia() -> BlitzNoCaminho:
	var arvore := Engine.get_main_loop() as SceneTree
	return arvore.get_first_node_in_group(&"blitz_no_caminho") as BlitzNoCaminho \
		if arvore != null else null


static func procurado() -> bool:
	return IWeed.agora() < procurado_ate


static func marcar_procurado() -> void:
	procurado_ate = IWeed.agora() + PROCURADO_MIN


## O que o jogador tem que a policia levaria, e quanto vale.
static func mercadoria_no_bolso() -> int:
	var valor := 0
	for id: StringName in MERCADORIA:
		valor += Inventario.quantidade(id) * int(MERCADORIA[id])
	return valor


static func preco_do_cafe() -> int:
	return CAFE_BASE + int(roundf(float(mercadoria_no_bolso()) * 0.2))


func _process(delta: float) -> void:
	_tique -= delta
	if _tique > 0.0:
		return
	_tique = 0.3
	if Interiores.dentro or Conversa.ativo or Celular.ativo or Cinema.ativa:
		return
	var jogador := get_tree().get_first_node_in_group(&"player") as Node3D
	if jogador == null or mercadoria_no_bolso() <= 0:
		return
	if jogador.has_method("dirigindo") and bool(jogador.call("dirigindo")):
		return
	for b: Blitz in BlitzManager.lista():
		if not is_instance_valid(b):
			continue
		var local := b.to_local(jogador.global_position)
		var no_funil := local.z >= -4.0 and local.z <= 26.0 and absf(local.x) <= 7.5
		if not no_funil:
			continue
		var chave := b.get_instance_id()
		if _testadas.has(chave):
			continue
		_testadas[chave] = true
		if procurado() or _rng.randf() < CHANCE:
			abordar(b, jogador)
		return


## A abordagem. Publica para o teste forcar uma.
func abordar(b: Node3D, jogador: Node3D) -> void:
	_blitz_atual = b
	_oficial = b.get_node_or_null(^"Oficial_0") as Node3D
	var perto := b.to_global(Vector3(0.0, 0.0, 9.9))
	var alvo: Node3D = _oficial if _oficial != null else b
	# O policial olha para o jogador e o jogador para ele: e ai que a conversa abre.
	if _oficial != null:
		var d := jogador.global_position - _oficial.global_position
		_oficial.global_rotation.y = atan2(-d.x, -d.z)
		perto = _oficial.global_position
	jogador.call("olhar_para", perto + Vector3(0.0, 1.55, 0.0))
	AudioDirector.tocar(&"buzina_curta", perto, -8.0, 1.6)
	var semente := int(b.get(&"id_blitz")) if b.get(&"id_blitz") != null else 7
	var ficha := RegistroCivil.identidade(RegistroCivil.id_de_faixa(semente * 131 + 17, 24, 50))
	ficha = ficha.duplicate()
	ficha["apelido"] = "SOLDADO %s" % String(ficha.get("sobrenome", "SILVA")).get_slice(" ", 0)
	ficha["blitz"] = true
	# O retrato da conversa com a mesma farda do policial da blitz: colete
	# refletivo e quepe branco, e nao a roupa civil da ficha.
	ficha["aparencia"] = Blitz._aparencia_pm(semente * 7 + 1)
	# Melhor ainda: a aparencia do proprio policial em cena, rosto e tudo.
	if _oficial != null and _oficial.get(&"_aparencia") is Dictionary \
			and not (_oficial.get(&"_aparencia") as Dictionary).is_empty():
		ficha["aparencia"] = _oficial.get(&"_aparencia")
	Conversa.abrir(alvo, ficha, &"blitz")


## As tres saidas. Devolve o que o policial diz. Chamado por FalasNpc.responder.
static func responder(chave: StringName) -> Array[String]:
	var inst := instancia()
	var rng := inst._rng if inst != null else RandomNumberGenerator.new()
	var valor := mercadoria_no_bolso()
	match chave:
		&"blitz_colaborar":
			_confiscar()
			return ["Vou ficar com isso aqui.", "Circulando. E some da minha avenida."]
		&"blitz_cafe":
			var cafe := preco_do_cafe()
			if Dinheiro.saldo() < cafe:
				_confiscar()
				return ["Cafe com que dinheiro? Abre a mochila.", "Isso aqui fica comigo."]
			var aceita := rng.randf() < (0.3 if procurado() else 0.65)
			if aceita:
				Dinheiro.pagar(cafe, "CAFEZINHO NA BLITZ")
				return ["...Nao vi nada.", "Some daqui antes que eu mude de ideia."]
			_confiscar()
			var multa := mini(Dinheiro.saldo(), 50)
			if multa > 0:
				Dinheiro.pagar(multa, "MULTA NA BLITZ")
			return ["Suborno, e? Na minha blitz?", "Vai sem a mercadoria e com multa. Agradece."]
		&"blitz_correr":
			if rng.randf() < 0.5:
				marcar_procurado()
				var jogador := (Engine.get_main_loop() as SceneTree).get_first_node_in_group(&"player") as Node3D
				if jogador != null:
					_empurrar_para_longe(jogador)
				return ["EI! PARADO!"]
			_confiscar()
			var multa := mini(Dinheiro.saldo(), 80)
			if multa > 0:
				Dinheiro.pagar(multa, "MULTA NA BLITZ")
			return ["Correr de mim? Com essa perna?", "Mercadoria apreendida. E multa."]
	return ["Circulando."] if valor >= 0 else []


static func _confiscar() -> void:
	for id: StringName in MERCADORIA:
		var n := Inventario.quantidade(id)
		if n > 0:
			Inventario.remover(id, n)


## Quem conseguiu correr sai do funil de uma vez: sem isto, a proxima checagem
## pegava o mesmo jogador parado no mesmo lugar.
static func _empurrar_para_longe(jogador: Node3D) -> void:
	var inst := instancia()
	if inst == null or inst._blitz_atual == null or not is_instance_valid(inst._blitz_atual):
		return
	var b := inst._blitz_atual
	var fora := b.to_global(Vector3(0.0, 0.0, -9.0))
	var v := fora - jogador.global_position
	v.y = 0.0
	if v.length() > 0.1:
		jogador.call("olhar_para", fora + Vector3(0.0, 1.5, 0.0))


## Um X9 recebeu do jogador: marca e chama uma blitz para perto.
static func x9_do_jogador() -> void:
	marcar_procurado()
	BlitzManager.semear()
