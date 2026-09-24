## A blitz no caminho de quem anda com mercadoria.
##
## A blitz da avenida ja existia e parava so os carros da IA; o jogador passava
## pelo funil como turista. Agora, a pe e com maconha, Super ou semente no bolso,
## entrar no funil pode render abordagem: o policial chama, a conversa abre (a
## mesma caixa das pessoas da rua, com um contexto proprio) e ha tres saidas —
## colaborar e perder a mercadoria, oferecer um "cafe" e torcer, ou correr.
##
## Ao volante tambem. A primeira versao desligava tudo com o jogador dirigindo:
## ele atravessava a blitz de carro com a mala cheia e ninguem olhava. Agora o
## policial do posto manda encostar; parar no bolsao abre a mesma abordagem, e
## seguir em frente e furar a blitz — o jogador fica procurado.
##
## E o X9: um cliente em cada tantos entrega o jogador. Depois de receber, a
## policia sabe — uma blitz nasce por perto e, por alguns minutos, toda blitz para
## quem estiver com mercadoria. Se quem entregou foi a equipe, ela e que e
## abordada e some por um tempo.
##
## So le a blitz pela API publica (`BlitzManager.lista`, `Blitz.na_zona_a_pe`,
## `Blitz.chegando_de_carro`).
class_name BlitzNoCaminho
extends Node

## O que a policia leva, e quanto vale na conta do cafe.
## As variedades da estufa valem o meio da faixa de preco delas no iWeed.
const MERCADORIA := {&"maconha": 15, &"super_maconha": 60, &"semente_maconha": 5,
	&"erva_morcega": 31, &"erva_bonsai": 85, &"erva_saca_rolha": 24, &"erva_girafa": 17,
	&"erva_pompom": 27, &"erva_chorona": 36, &"erva_gambazona": 46, &"erva_vagalume": 80}
## Chance de ser abordado ao entrar no funil com mercadoria. Procurado, sempre.
const CHANCE := 0.4
## Minutos de jogo em que o jogador fica marcado depois de um X9.
const PROCURADO_MIN := 4.0
const CAFE_BASE := 30
## Chance de o policial mandar o jogador encostar, ao volante, com mercadoria.
const CHANCE_VOLANTE := 0.5
## Abaixo disto, em m/s, o carro do jogador conta como encostado.
const PARADO := 1.2
## Tempo para o jogador obedecer antes de a ordem caducar.
const ESPERA_ENCOSTAR := 20.0

static var procurado_ate := -1.0

var _testadas: Dictionary = {}
var _tique := 0.0
var _rng := RandomNumberGenerator.new()
var _blitz_atual: Node3D
var _oficial: Node3D
## A blitz que mandou o jogador encostar, e ha quanto tempo.
var _chamado_por: Blitz = null
var _chamado_t := 0.0


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
	if jogador == null:
		return
	if jogador.has_method("carro") and jogador.call("carro") != null:
		_tick_volante(jogador, jogador.call("carro") as Carro, 0.3)
		return
	_chamado_por = null
	if mercadoria_no_bolso() <= 0:
		return
	for b: Blitz in BlitzManager.lista():
		if not is_instance_valid(b):
			continue
		if not b.na_zona_a_pe(jogador.global_position):
			continue
		var chave := b.get_instance_id()
		if _testadas.has(chave):
			continue
		_testadas[chave] = true
		if procurado() or _rng.randf() < CHANCE:
			abordar(b, jogador)
		return


## O jogador ao volante. Chegando pela mao da blitz, com mercadoria (ou
## procurado), o policial manda encostar. Parou no bolsao: abordagem. Passou
## da ponta sem parar: furou.
func _tick_volante(jogador: Node3D, carro: Carro, passo: float) -> void:
	if _chamado_por != null:
		if not is_instance_valid(_chamado_por):
			_chamado_por = null
			return
		_chamado_t += passo
		var b := _chamado_por
		var local := b.to_local(carro.global_position)
		var rapidez := carro.linear_velocity.length()
		if rapidez < PARADO and b.na_zona_a_pe(carro.global_position):
			_chamado_por = null
			abordar(b, jogador)
		elif local.z < -3.0:
			_chamado_por = null
			_furou(b)
		elif _chamado_t > ESPERA_ENCOSTAR or local.z > PlantaBlitz.COMPRIMENTO + 30.0:
			# Parou longe, deu a volta: a ordem caduca.
			_chamado_por = null
		return
	if mercadoria_no_bolso() <= 0 and not procurado():
		return
	var frente := -carro.global_transform.basis.z
	for b: Blitz in BlitzManager.lista():
		if not is_instance_valid(b) or not b.chegando_de_carro(carro.global_position, frente):
			continue
		var chave := b.get_instance_id()
		if _testadas.has(chave):
			return
		_testadas[chave] = true
		if procurado() or _rng.randf() < CHANCE_VOLANTE:
			_mandar_encostar(b, carro)
		return


func _mandar_encostar(b: Blitz, carro: Carro) -> void:
	_chamado_por = b
	_chamado_t = 0.0
	var oficial := b.get_node_or_null(^"Oficial_0") as Corpo
	if oficial != null:
		oficial.postura(Corpo.Postura.CONTROLE)
		var d := carro.global_position - oficial.global_position
		oficial.global_rotation.y = atan2(-d.x, -d.z)
	AudioDirector.tocar(&"buzina_curta", b.ponto_de_parada(), -6.0, 1.9)
	Cinema.fala("POLICIAL: Encosta ai, motorista! Na faixa da direita.")


## Furou a blitz: procurado, e a proxima blitz para o jogador com certeza.
func _furou(b: Blitz) -> void:
	marcar_procurado()
	var oficial := b.get_node_or_null(^"Oficial_0") as Corpo
	if oficial != null:
		oficial.postura(Corpo.Postura.LIVRE)
	AudioDirector.tocar(&"buzina_curta", b.ponto_de_parada(), -3.0, 2.2)
	Cinema.fala("POLICIAL: EI! PARA ESSE CARRO! ... Anotei a placa.")


## A abordagem. Publica para o teste forcar uma.
func abordar(b: Node3D, jogador: Node3D) -> void:
	_blitz_atual = b
	_oficial = b.get_node_or_null(^"Oficial_0") as Node3D
	var perto := (b as Blitz).ponto_de_parada() if b is Blitz else b.global_position
	var alvo: Node3D = _oficial if _oficial != null else b
	# O policial olha para o jogador e o jogador para ele: e ai que a conversa abre.
	if _oficial != null:
		var d := jogador.global_position - _oficial.global_position
		_oficial.global_rotation.y = atan2(-d.x, -d.z)
		perto = _oficial.global_position
	# Ao volante quem manda na camera e o carro.
	var no_carro := jogador.has_method("carro") and jogador.call("carro") != null
	if not no_carro:
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
