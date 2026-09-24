## Uma blitz montada na avenida: bolsao de cones na faixa de fora, viatura no
## acostamento, tres policiais, e a coreografia de uma abordagem por vez —
## chamar, encostar na baia, janela, revista (as vezes), liberar.
##
## A planta (onde cada coisa fica, e a lei de mira dos carros) mora em
## `PlantaBlitz`, que a regua `tests/checar_blitz.gd` mede sem janela. Aqui
## mora so o que precisa de arvore: montar, andar com as pessoas, conversar com
## o `Carro` da IA e empurrar peca.
##
## O que mudou da primeira blitz, e por que
## ----------------------------------------
## - Viatura e um `Carro` de verdade, solto e freado: amassa, anda no empurrao e
##   da para roubar. Era malha com caixa estatica — parede para o jogador.
## - Cone, placa e boneco sao `PecaBlitz`: corpo rigido que dorme ate levar
##   pancada. Eram caixa estatica (cone) ou nada (placa e boneco).
## - O carro abordado encosta na baia vindo pela FRENTE. Antes o destino do
##   estacionamento ficava 4 m ATRAS do ponto de parada, e a IA nao anda de re:
##   o carro girava no lugar e a fase vencia por tempo com ele atravessado.
## - Cada carro e decidido uma vez. A selecao era um hash fixo da semente, sem
##   memoria: o carro liberado continuava "selecionado", o teto voltava a zero
##   dentro do funil e a abordagem recomecava para sempre.
## - O policial vai a janela do MOTORISTA (-X do carro). Ia a do passageiro.
class_name Blitz
extends Node3D

## Chance percentual de um carro da IA ser chamado, com a baia livre.
const CHANCE_PARAR := 35
## Chance percentual de a abordagem virar revista (motorista desce).
const CHANCE_REVISTA := 45
const TEMPO_FREANDO := 0.6
const TEMPO_JANELA := 3.2
const TEMPO_REVISTA := 4.5
## Espera o motorista "por o cinto" antes de sair.
const TEMPO_ARRANCAR := 0.8
## Teto da espera pelo policial sair de perto da janela.
const ESPERA_POLICIAL_SAIR := 4.0
## Carro chamado que nao chega (virou na esquina, foi roubado) solta a baia.
const ESPERA_CHAMADO := 25.0
const ESPERA_SAIDA := 15.0
const VEL_ANDAR := 1.45
## Raio em que um carro da IA pode empurrar peca.
const ALCANCE_EMPURRAO := 30.0
## `--blitz-log`: cada troca de fase no console. E como se mede a coreografia
## ao vivo, com transito de verdade, sem encenar nada.
static var LOG := OS.get_cmdline_user_args().has("--blitz-log")

## Fases da abordagem (um carro por vez). Os nomes antigos continuam valendo
## para quem os usa de fora (captura, abertura).
enum Fase {
	OCIOSA,
	FREANDO,
	OFICIAL_ANDANDO,
	NA_JANELA,
	MOTORISTA_DESCE,
	CONVERSA,
	MOTORISTA_SOBE,
	LIBERADO,
	## O carro foi escolhido e vem pela faixa 0 ate a baia.
	CHAMANDO,
}

## Identidade estavel desta blitz (semente de spawn).
var id_blitz: int = 0
## Trecho de via onde esta plantada.
var trecho := Vector4i.ZERO
var de := Vector2i.ZERO
var para := Vector2i.ZERO
var via: int = MalhaUrbana.Via.AVENIDA
## Centro do acostamento em x local. Lido pela captura de cima.
var _x_acost: float = 2.2

var _planta: Dictionary = {}
var _fase: int = Fase.OCIOSA
var _fase_t: float = 0.0
var _carro_insp: Carro = null
var _revista := false
## instance_id -> true (chamado) / false (passa direto). Um carro, uma decisao.
var _decididos: Dictionary = {}
## instance_id de quem ja foi abordado e esta saindo.
var _liberados: Dictionary = {}
var _faxina: float = 0.0

var _oficial: Corpo = null
var _oficiais: Array[Corpo] = []
var _motorista: Corpo = null
var _viatura: Carro = null
## A viatura achou lugar na calcada (sem ele a blitz nao nasce).
var _viatura_na_calcada := true
var _viatura_presa := false
## Ha quanto tempo nada com fisica passa perto da viatura solta.
var _viatura_solta_t := 0.0
var _pecas: Array[PecaBlitz] = []
## Corpo -> {"caminho": Array[Vector3] local, "olhar": Vector3 local}
var _andando: Dictionary = {}
## Corpo -> ponto local para onde olha parado.
var _olhar: Dictionary = {}
## True enquanto --blitz-demo congela a cena para captura.
var _demo_captura: bool = false
## Ganchos do teste montado (TesteBlitz): o proximo carro que chegar a montante
## e chamado, e a abordagem vira revista (1), so janela (0) ou sorteio (-1).
var forcar_chamado := false
var forcar_revista := -1


## Consulta usada pela IA do Carro. Devolve {} ou:
##   blitz  Blitz
##   parar  bool    — este carro foi chamado
##   teto   float   — teto de velocidade, m/s
##   faixa  int     — faixa sugerida (-1 = nao muda)
##   eixo   int     — eixo da via da blitz
##   mira   Vector3 — ponto de mira no mundo
##   fase   int     — Fase da abordagem se este carro e o abordado
##   ocultar_motorista bool — o motorista esta a pe
static func efeito(carro: Carro) -> Dictionary:
	if carro == null or not is_instance_valid(carro):
		return {}
	var b := BlitzManager.blitz_para(carro.global_position, carro.trecho)
	if b == null:
		return {}
	return b._efeito_para(carro)


## Monta tudo. Chamado DEPOIS de o no estar na arvore e posicionado: as pecas
## sao corpos rigidos e nascem no lugar certo do mundo, e a viatura vai para o
## pai da blitz (sobrevive a ela se o jogador a levar).
##
## Devolve false, sem montar nada, se a viatura nao cabe na calcada ali
## (arvore, banco, maquina). Nao ha plano B: a viatura no acostamento fica no
## caminho do carro abordado, que a atravessava — o jogador viu. O
## BlitzManager descarta este lugar e procura outro.
func montar(semente: int, t: Dictionary, nova_via: int) -> bool:
	id_blitz = semente
	trecho = t["trecho"]
	de = t["de"]
	para = t.get("para", de)
	via = nova_via
	_planta = PlantaBlitz.planta(via)
	_x_acost = float((_planta["geo"] as Dictionary)["x_acost"])
	var vaga := _lugar_da_viatura()
	if not vaga.is_finite():
		return false
	_montar_pecas()
	_montar_viatura(semente, vaga)
	_montar_oficiais(semente)
	# Policial andando nao empurra a viatura: ela e corpo solto, e a capsula
	# dele e cinematica — passando rente, arrastava o carro pelo asfalto.
	if _viatura != null:
		for o: Corpo in _oficiais:
			var col := o.get_node_or_null(^"ColisaoPolicial") as PhysicsBody3D
			if col != null:
				col.add_collision_exception_with(_viatura)
	set_process(true)
	set_physics_process(true)
	return true


func _exit_tree() -> void:
	_limpar_motorista()
	if _carro_insp != null and is_instance_valid(_carro_insp):
		_carro_insp.call("_ocultar_motorista_visual", false)
	# A viatura mora no pai. Some junto, a menos que o jogador a tenha tomado —
	# ai ela deixou de ser da blitz (Transito.entregar_ao_jogador a tira da
	# lista de estacionados).
	if _viatura != null and is_instance_valid(_viatura) and Transito.estacionado(_viatura):
		Transito.esquecer_estacionado(_viatura)
		_viatura.queue_free()
	_viatura = null


## Ponto mundial onde o abordado para (a baia). A camera da abertura mira aqui.
func ponto_de_parada() -> Vector3:
	return to_global(_planta.get("baia", Vector3.ZERO))


## O carro nesta posicao/trecho esta na zona da blitz?
func influencia(pos_mundo: Vector3, trecho_carro: Vector4i) -> bool:
	if trecho_carro.z != trecho.z or trecho_carro.w != trecho.w:
		return false
	return PlantaBlitz.na_zona(via, to_local(pos_mundo))


## O jogador a pe esta no bolsao, na baia ou na calcada da blitz?
func na_zona_a_pe(pos_mundo: Vector3) -> bool:
	var local := to_local(pos_mundo)
	var g: Dictionary = _planta["geo"]
	return (local.z > -1.0 and local.z < PlantaBlitz.COMPRIMENTO + 1.0
		and local.x > float(g["x_divisa"]) - 0.4 and local.x < float(g["x_calcada_fim"]))


## O jogador ao volante esta chegando na blitz, pela mao dela?
func chegando_de_carro(pos_mundo: Vector3, rumo: Vector3) -> bool:
	var local := to_local(pos_mundo)
	var g: Dictionary = _planta["geo"]
	if local.x < float(g["x_eixo"]) or local.x > float(g["x_meio_fio"]):
		return false
	# Mesmo sentido do fluxo (-Z local).
	if rumo.dot(-global_transform.basis.z) < 0.5:
		return false
	return local.z > PlantaBlitz.COMPRIMENTO - 2.0 and local.z < PlantaBlitz.COMPRIMENTO + 16.0


func _process(delta: float) -> void:
	if _demo_captura:
		for o: Corpo in _oficiais:
			o.animar(0.0, delta)
		if _motorista != null:
			_motorista.animar(0.0, delta)
		return
	_tick_abordagem(delta)
	_tick_gente(delta)
	_faxina += delta
	if _faxina > 5.0:
		_faxina = 0.0
		_esquecer_mortos()


func _physics_process(delta: float) -> void:
	_empurrar_pecas()
	_cuidar_da_viatura(delta)


## Presa quando nada chega perto, solta quando um carro com fisica (o do
## jogador, ou outro corpo solto) se aproxima. Ver `Carro.prender_estacionado`.
const PERTO_DA_VIATURA := 12.0
const PARADA_PARA_PRENDER := 2.0


func _cuidar_da_viatura(delta: float) -> void:
	var v := _viatura
	if v == null or not is_instance_valid(v) or v.motorista != Carro.Motorista.NINGUEM:
		return
	var ameaca := false
	for no: Node in get_tree().get_nodes_in_group(&"carro"):
		var c := no as Carro
		if c == null or c == v or c.freeze:
			continue
		if c.global_position.distance_squared_to(v.global_position) \
				< PERTO_DA_VIATURA * PERTO_DA_VIATURA:
			ameaca = true
			break
	if ameaca:
		_viatura_solta_t = 0.0
		if _viatura_presa:
			v.prender_estacionado(false)
			_viatura_presa = false
		return
	if _viatura_presa:
		return
	_viatura_solta_t += delta
	if _viatura_solta_t > PARADA_PARA_PRENDER and v.linear_velocity.length() < 0.05:
		v.prender_estacionado(true)
		_viatura_presa = true


# --- conversa com a IA ----------------------------------------------------------

func _efeito_para(carro: Carro) -> Dictionary:
	var local := to_local(carro.global_position)
	var id := carro.get_instance_id()
	var out := {
		"blitz": self,
		"parar": false,
		"teto": INF,
		"faixa": -1,
		"eixo": trecho.z,
		"mira": carro.global_position - global_transform.basis.z * 8.0,
		"fase": -1,
		"ocultar_motorista": false,
	}
	if _liberados.has(id):
		var segura := carro == _carro_insp and _segurando_saida()
		out["teto"] = 0.0 if segura else PlantaBlitz.TETO_SAIDA
		out["mira"] = to_global(PlantaBlitz.mira_saida(via, local))
		out["fase"] = Fase.LIBERADO if carro == _carro_insp else -1
		return out
	if not _decididos.has(id):
		_decidir(carro, local)
	if carro == _carro_insp:
		out["parar"] = true
		out["fase"] = _fase
		if _fase == Fase.CHAMANDO:
			out["teto"] = PlantaBlitz.teto_entrada(local.z)
			out["mira"] = to_global(PlantaBlitz.mira_entrada(via, local))
		else:
			out["teto"] = 0.0
		out["ocultar_motorista"] = _fase in [Fase.MOTORISTA_DESCE, Fase.CONVERSA,
			Fase.MOTORISTA_SOBE]
		return out
	# Passa direto: faixa de dentro, devagar no bolsao.
	if Vias.faixas(via) > 1:
		out["faixa"] = 1
	out["teto"] = PlantaBlitz.teto_desvio(via, local)
	out["mira"] = to_global(PlantaBlitz.mira_desvio(via, local))
	return out


## Chamado ou nao, de uma vez so. So e chamado quem ainda esta a montante do
## bolsao, na faixa 0, com a baia livre — o resto passa.
func _decidir(carro: Carro, local: Vector3) -> void:
	var g: Dictionary = _planta["geo"]
	var h := absi(id_blitz * 2654435761 ^ carro.semente * 40503) % 100
	var chamar := ((h < CHANCE_PARAR or forcar_chamado) and _fase == Fase.OCIOSA
		and _carro_insp == null
		and carro.motorista == Carro.Motorista.IA
		and local.z > PlantaBlitz.COMPRIMENTO - 1.0
		and local.x > float(g["x_divisa"]) - 0.2)
	_decididos[carro.get_instance_id()] = chamar
	if LOG:
		print("[blitz] %s  %s em z %.1f x %.1f: %s" % [name, carro.name, local.z, local.x,
			"CHAMADO" if chamar else "passa (h=%d, fase %s)" % [h, Fase.keys()[_fase]]])
	if chamar:
		_carro_insp = carro
		_fase = Fase.CHAMANDO
		_fase_t = 0.0
		_revista = absi(carro.semente * 7 + id_blitz) % 100 < CHANCE_REVISTA
		if forcar_revista >= 0:
			_revista = forcar_revista == 1
		forcar_chamado = false


func _esquecer_mortos() -> void:
	for tabela: Dictionary in [_decididos, _liberados]:
		for id: int in tabela.keys():
			if not is_instance_id_valid(id):
				tabela.erase(id)


# --- a abordagem -------------------------------------------------------------------

func _tick_abordagem(delta: float) -> void:
	if _fase == Fase.OCIOSA:
		return
	_fase_t += delta
	if _carro_insp == null or not is_instance_valid(_carro_insp) \
			or _carro_insp.motorista != Carro.Motorista.IA:
		# Recolhido pelo transito, ou o jogador tirou o motorista.
		_abortar()
		return
	var local := to_local(_carro_insp.global_position)
	match _fase:
		Fase.CHAMANDO:
			if not _andando.has(_oficial) and _oficial.postura_atual() != Corpo.Postura.CONTROLE:
				_oficial.postura(Corpo.Postura.CONTROLE)
			_olhar[_oficial] = local
			var na_baia := absf(local.z - PlantaBlitz.Z_BAIA) < 1.2
			if na_baia and _carro_insp.velocidade() < 0.15:
				_mudar(Fase.FREANDO)
			elif _fase_t > ESPERA_CHAMADO or not influencia(_carro_insp.global_position,
					_carro_insp.trecho):
				_abortar()
		Fase.FREANDO:
			if _fase_t > TEMPO_FREANDO:
				_oficial.postura(Corpo.Postura.LIVRE)
				_andar(_oficial, _planta["caminho_ida"], local)
				_mudar(Fase.OFICIAL_ANDANDO)
		Fase.OFICIAL_ANDANDO:
			if not _andando.has(_oficial):
				_oficial.falar(true)
				# Na janela: explica com a mao, de cara fechada.
				_oficial.reagir(ReacaoCorpo.GESTO_EXPLICA)
				if _oficial.rosto != null:
					_oficial.rosto.reagir(Rosto.Expressao.DESCONFIANCA, TEMPO_JANELA)
				_mudar(Fase.NA_JANELA)
		Fase.NA_JANELA:
			_olhar[_oficial] = local
			if _fase_t > TEMPO_JANELA:
				_oficial.falar(false)
				if _revista:
					_andar(_oficial, _planta["caminho_revista"], _planta["revista_motorista"])
					_mudar(Fase.MOTORISTA_DESCE)
				else:
					_liberar()
		Fase.MOTORISTA_DESCE:
			# A porta so abre com o policial ja atras dela: os dois usam o
			# mesmo corredor entre a lataria e os cones.
			var porta: Vector3 = _planta["porta"]
			if _motorista == null and _oficial.position.z > porta.z + 0.9:
				_spawn_motorista()
			if _motorista != null and not _andando.has(_motorista) \
					and not _andando.has(_oficial):
				_oficial.falar(true)
				_motorista.falar(true)
				# "Mao na cabeca!": o motorista obedece com medo, o PM aponta.
				_motorista.reagir(ReacaoCorpo.REACAO_MAO_NA_CABECA)
				if _motorista.rosto != null:
					_motorista.rosto.reagir(Rosto.Expressao.MEDO, TEMPO_REVISTA)
				_oficial.reagir(ReacaoCorpo.GESTO_APONTA)
				if _oficial.rosto != null:
					_oficial.rosto.reagir(Rosto.Expressao.RAIVA, TEMPO_REVISTA * 0.5)
				_mudar(Fase.CONVERSA)
		Fase.CONVERSA:
			if _fase_t > TEMPO_REVISTA:
				_oficial.falar(false)
				_motorista.falar(false)
				_andar(_motorista, _planta["caminho_motorista_volta"], local)
				_mudar(Fase.MOTORISTA_SOBE)
		Fase.MOTORISTA_SOBE:
			if _motorista == null or not _andando.has(_motorista):
				_limpar_motorista()
				_liberar()
		Fase.LIBERADO:
			if local.z < -4.0 or _fase_t > ESPERA_SAIDA:
				_carro_insp = null
				_mudar(Fase.OCIOSA)


func _mudar(nova: int) -> void:
	if LOG:
		print("[blitz] %s  %s -> %s  (%.1f s)" % [name, Fase.keys()[_fase],
			Fase.keys()[nova], _fase_t])
	_fase = nova
	_fase_t = 0.0


## Libera o carro e manda o policial de volta ao posto.
func _liberar() -> void:
	_liberados[_carro_insp.get_instance_id()] = true
	_voltar_ao_posto()
	_mudar(Fase.LIBERADO)


## Pelo corredor ao lado do carro parado: da janela sobe por ele; da revista
## (atras da traseira) entra nele e sobe.
func _voltar_ao_posto() -> void:
	if _oficial == null:
		return
	var posto: Vector3 = _planta["posto_0"]
	if _oficial.position.distance_to(posto) < 0.3:
		return
	var da_revista := _oficial.position.z > PlantaBlitz.Z_BAIA + PlantaBlitz.MEIA_CARRO.z
	_andar(_oficial, _planta["caminho_volta_revista" if da_revista else "caminho_volta"],
		_montante())


## O liberado espera o cinto e espera o policial da janela passar da traseira.
## A regua mediu 7 cm entre o retrovisor e o colete com o policial parado ali.
func _segurando_saida() -> bool:
	if _fase_t < TEMPO_ARRANCAR:
		return true
	if _oficial == null or _fase_t > ESPERA_POLICIAL_SAIR:
		return false
	return _oficial.position.z < PlantaBlitz.Z_BAIA + PlantaBlitz.MEIA_CARRO.z + 0.8


func _abortar() -> void:
	_limpar_motorista()
	if _carro_insp != null and is_instance_valid(_carro_insp):
		_carro_insp.call("_ocultar_motorista_visual", false)
		# Sai andando: sem isto um carro abortado no meio do bolsao ficava com
		# teto zero ate o transito recolhe-lo.
		_liberados[_carro_insp.get_instance_id()] = true
	_carro_insp = null
	if _oficial != null:
		_oficial.falar(false)
		_oficial.postura(Corpo.Postura.LIVRE)
		_voltar_ao_posto()
	_mudar(Fase.OCIOSA)


## Ponto a montante, para onde o policial do posto olha.
func _montante() -> Vector3:
	return Vector3(0.0, 0.0, PlantaBlitz.COMPRIMENTO + 12.0)


# --- gente -----------------------------------------------------------------------------

func _andar(quem: Corpo, caminho: Array, olhar_no_fim: Vector3) -> void:
	if quem == null:
		return
	var pontos: Array[Vector3] = []
	for p: Vector3 in caminho:
		pontos.append(p)
	_andando[quem] = pontos
	_olhar[quem] = olhar_no_fim


## Anda quem tem caminho, vira para o olhar quem esta parado. Sempre no chao
## do Relevo: a blitz inteira segue a ladeira, mas a pessoa pisa no chao dela.
func _tick_gente(delta: float) -> void:
	var todos: Array[Corpo] = _oficiais.duplicate()
	if _motorista != null:
		todos.append(_motorista)
	for quem: Corpo in todos:
		if not is_instance_valid(quem):
			continue
		var tombo := TomboDeCorpo.de(quem)
		if tombo != null and tombo.ocupado():
			quem.animar(tombo.rapidez(), delta)
			continue
		if _andando.has(quem):
			var pontos: Array[Vector3] = _andando[quem]
			var alvo := pontos[0]
			var v := alvo - quem.position
			v.y = 0.0
			var passo := VEL_ANDAR * delta
			if v.length() <= passo:
				quem.position = _no_chao(alvo)
				pontos.remove_at(0)
				if pontos.is_empty():
					_andando.erase(quem)
			else:
				quem.position = _no_chao(quem.position + v.normalized() * passo)
				quem.rotation.y = atan2(-v.x, -v.z)
			quem.animar(VEL_ANDAR, delta)
			continue
		if _olhar.has(quem):
			var o: Vector3 = _olhar[quem]
			var d := o - quem.position
			d.y = 0.0
			if d.length() > 0.1:
				quem.rotation.y = atan2(-d.x, -d.z)
		quem.animar(0.0, delta)


## A posicao local com a altura do chao de verdade naquele ponto.
func _no_chao(local: Vector3) -> Vector3:
	var g := to_global(Vector3(local.x, 0.0, local.z))
	g.y = Relevo.altura(g.x, g.z)
	var l := to_local(g)
	return Vector3(local.x, l.y, local.z)


func _spawn_motorista() -> void:
	_limpar_motorista()
	if _carro_insp == null:
		return
	_motorista = Corpo.new()
	_motorista.name = "MotoristaInsp"
	_motorista.com_rosto = true
	var ficha := _carro_insp.ficha
	if ficha.is_empty():
		ficha = {"id": absi(_carro_insp.semente * 17), "sexo": &"M", "idade": 35}
	_motorista.montar(Aparencia.de_ficha(ficha))
	_motorista.position = _no_chao(_planta["porta"])
	_motorista.rotation.y = PI * 0.5
	_motorista.postura(Corpo.Postura.LIVRE)
	add_child(_motorista)
	_andar(_motorista, _planta["caminho_motorista"], _planta["revista_oficial"])


func _limpar_motorista() -> void:
	if _motorista != null and is_instance_valid(_motorista):
		_andando.erase(_motorista)
		_olhar.erase(_motorista)
		_motorista.queue_free()
	_motorista = null


func _montar_oficiais(semente: int) -> void:
	for i in 3:
		var corp := Corpo.new()
		corp.name = "Oficial_%d" % i
		# Cara que mexe (desconfianca na janela), como quem se ve de perto.
		corp.com_rosto = true
		corp.montar(_aparencia_pm(semente + i * 97))
		add_child(corp)
		corp.position = _no_chao(_planta["posto_%d" % i])
		_colisao_de_pessoa(corp)
		# O PM tambem cai: carro que fura a blitz derruba, esbarrao balanca. O
		# carro abordado e a viatura, devagar, so encostam.
		var tombo := TomboDeCorpo.ligar(corp)
		tombo.poupar = func(carro: Node3D) -> bool:
			return carro == _carro_insp or carro == _viatura
		_oficiais.append(corp)
		# O do posto olha quem chega; os da calcada olham a pista.
		_olhar[corp] = _montante() if i == 0 else Vector3(0.0, 0.0, corp.position.z)
	_oficial = _oficiais[0]


## Capsula que acompanha o corpo. Sem ela o jogador atravessava o policial a pe
## e de carro. Camada 1 como a de qualquer pessoa; a IA do transito nao a ve
## (so enxerga Carro, Pedestre e o jogador) e nao precisa: nenhum carro da IA
## passa por onde os policiais ficam.
func _colisao_de_pessoa(quem: Corpo) -> void:
	var corpo := AnimatableBody3D.new()
	corpo.name = "ColisaoPolicial"
	corpo.sync_to_physics = false
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.28
	capsula.height = 1.75
	forma.shape = capsula
	forma.position = Vector3(0.0, 0.875, 0.0)
	corpo.add_child(forma)
	quem.add_child(corpo)


# --- pecas e viatura -------------------------------------------------------------------

func _montar_pecas() -> void:
	var i := 0
	for c: Vector3 in _planta["cones"]:
		_por_peca(PecaBlitz.criar("Cone_%d" % i, KitBlitz.cone_transito(),
			Vector3(0.4, 0.7, 0.4), 3.5, 0.15), c)
		i += 1
	i = 0
	for c: Vector3 in _planta["placas"]:
		var placa := PecaBlitz.criar("Placa_%d" % i, KitBlitz.placa(),
			Vector3(0.55, 1.3, 0.12), 7.0, 0.2)
		_por_peca(placa, c)
		# A face da placa olha para quem chega (+Z local).
		placa.rotation.y = PI
		i += 1
	_por_peca(PecaBlitz.criar("Bollard", KitBlitz.bollard(),
		Vector3(0.55, 1.6, 0.35), 4.0, 0.3), _planta["bollard"])


## Poe a peca no chao de verdade: raio de cima para baixo na camada 1 (o chao
## do chunk), ignorando carro e gente que estejam passando por cima.
## Assenta pelo canto mais alto da base, 2 cm acima, e deixa a peca cair
## acordada. Pelo raio do centro so, numa emenda de chunk ou num chao inclinado
## um canto nascia enterrado; a peca dormia assim e, acordada por qualquer
## coisa, a fisica a cuspia do chao (teste_blitz: o Cone_2 da mesma blitz caia
## em toda rodada tocando so o chao).
func _por_peca(p: PecaBlitz, local: Vector3) -> void:
	add_child(p)
	var g := to_global(Vector3(local.x, 0.0, local.z))
	var r := p.raio
	var topo := -INF
	for canto: Vector3 in [Vector3(-r, 0, -r), Vector3(r, 0, -r), Vector3(r, 0, r),
			Vector3(-r, 0, r), Vector3.ZERO]:
		topo = maxf(topo, _chao_em(g + global_transform.basis * canto))
	g.y = topo
	p.global_position = g + Vector3(0.0, 0.02, 0.0)
	p.assentar()
	_pecas.append(p)


func _chao_em(g: Vector3) -> float:
	var espaco := get_world_3d().direct_space_state
	var de_cima := g + Vector3.UP * 3.0
	var excluir: Array[RID] = []
	for _k in 4:
		var q := PhysicsRayQueryParameters3D.create(de_cima, g + Vector3.DOWN * 3.0, 1)
		q.exclude = excluir
		var achado := espaco.intersect_ray(q)
		if achado.is_empty():
			break
		var col: Object = achado.get("collider")
		if col is Carro or col is CharacterBody3D or col is PecaBlitz \
				or col is AnimatableBody3D:
			excluir.append(achado["rid"] as RID)
			continue
		return (achado["position"] as Vector3).y
	return Relevo.altura(g.x, g.z)


func _montar_viatura(semente: int, onde: Vector3) -> void:
	var pai := get_parent() as Node3D
	if pai == null:
		return
	var c := Carro.new()
	c.name = "Viatura_%d" % semente
	c.preparar({}, de, trecho, semente)
	c.modelo = Carroceria.Modelo.SEDA
	c.tinta_fixa = Color(0.93, 0.93, 0.95)
	pai.add_child(c)
	var frente := -global_transform.basis.z
	c.estacionar_solto(onde, atan2(-frente.x, -frente.z))
	var medidas: Dictionary = c.get("_medidas")
	c.add_child(KitBlitz.adesivo_viatura(medidas))
	var giro := KitBlitz.giroflex()
	giro.position = Vector3(0.0, float(medidas["altura"]) + 0.02, 0.1)
	c.add_child(giro)
	Transito.registrar_estacionado(c)
	c.set_meta(&"ignorar_ia", true)
	_viatura = c
	# Assenta solta nas rodas (duas no meio-fio) e depois fica presa.
	_viatura_solta_t = 0.0
	_viatura_presa = false


## Onde a viatura estaciona, no mundo, ja na altura de cair nas rodas, ou
## Vector3.INF se a calcada ali tem alguma coisa em pe.
##
## Duas rodas na calcada (planta) e so ali: a regua validou a manobra do carro
## abordado com a viatura exatamente nesse lugar. A calcada tem arvore da guia,
## banco e maquina, que a malha do chunk nao conta a ninguem; a sonda sao raios
## de cima ao longo da pegada.
func _lugar_da_viatura() -> Vector3:
	var na_calcada: Vector3 = _planta["viatura"]
	var alto := _pegada_livre(na_calcada)
	_viatura_na_calcada = alto > -INF
	if not _viatura_na_calcada:
		return Vector3.INF
	var g := to_global(Vector3(na_calcada.x, 0.0, na_calcada.z))
	return Vector3(g.x, alto + 0.08, g.z)


## Altura do chao mais alto sob a pegada da viatura, ou -INF se ha algo em pe
## ali (mais de 35 cm acima do asfalto da blitz).
func _pegada_livre(centro_local: Vector3) -> float:
	var asfalto := _chao_em(to_global(Vector3(0.0, 0.0, centro_local.z)))
	var mais_alto := -INF
	var m := PlantaBlitz.MEIA_CARRO
	for ix in 5:
		for iz in 11:
			var l := centro_local + Vector3(lerpf(-m.x, m.x, ix / 4.0), 0.0,
				lerpf(-m.z, m.z, iz / 10.0))
			var h := _chao_em(to_global(Vector3(l.x, 0.0, l.z)))
			if h - asfalto > 0.35:
				return -INF
			mais_alto = maxf(mais_alto, h)
	return mais_alto


## O carro da IA e congelado e movido por transformada: nao passa velocidade a
## corpo nenhum. Quem ele atravessa leva o empurrao daqui, na velocidade dele.
func _empurrar_pecas() -> void:
	if _pecas.is_empty():
		return
	for no: Node in get_tree().get_nodes_in_group(&"carro"):
		var c := no as Carro
		if c == null or c.motorista != Carro.Motorista.IA:
			continue
		var v := c.velocidade()
		if v < 0.3:
			continue
		if c.global_position.distance_squared_to(global_position) \
				> ALCANCE_EMPURRAO * ALCANCE_EMPURRAO:
			continue
		var medidas: Dictionary = c.get("_medidas")
		var meia_x := float(medidas.get("largura", 1.7)) * 0.5
		var meia_z := float(medidas.get("comprimento", 4.3)) * 0.5
		var inv := c.global_transform.affine_inverse()
		var vel := -c.global_transform.basis.z * v
		for p: PecaBlitz in _pecas:
			if not is_instance_valid(p):
				continue
			var l := inv * p.global_position
			if absf(l.x) < meia_x + p.raio and absf(l.z) < meia_z + p.raio \
					and l.y > -0.6 and l.y < 1.8:
				p.empurrar(vel, c.global_position, String(c.name))


# --- captura -------------------------------------------------------------------------

## Monta uma cena parada de uma fase, para captura (--blitz-demo).
##
## E ENCENACAO, e nao prova de nada: carro de malha, gente posta a mao, IA
## ignorada. A blitz de antes passou por pronta com fotos assim e nada
## funcionava na rua. Para ver a blitz de verdade, capture SEM --blitz-demo.
func preparar_captura(fase: int, semente: int = 0) -> void:
	_limpar_demo_captura()
	_demo_captura = true
	var s := semente if semente != 0 else id_blitz
	if fase in [Fase.NA_JANELA, Fase.OFICIAL_ANDANDO, Fase.FREANDO,
			Fase.MOTORISTA_DESCE, Fase.CONVERSA, Fase.MOTORISTA_SOBE]:
		var demo := _spawn_carro_demo(_planta["baia"], s, Color(0.55, 0.22, 0.16))
		demo.name = "CarroDemo"
		if fase == Fase.CONVERSA or fase == Fase.MOTORISTA_DESCE or fase == Fase.MOTORISTA_SOBE:
			_oficial.position = _no_chao(_planta["revista_oficial"])
			_motorista = Corpo.new()
			_motorista.name = "MotoristaInsp"
			_motorista.montar(Aparencia.de_ficha({"id": absi(s * 17), "sexo": &"M", "idade": 34}))
			add_child(_motorista)
			_motorista.position = _no_chao(_planta["revista_motorista"])
			_virar_um_para_o_outro(_oficial, _motorista)
			_oficial.falar(true)
			_motorista.falar(true)
		else:
			_oficial.position = _no_chao(_planta["janela"])
			_oficial.rotation.y = -PI * 0.5
			_oficial.falar(true)


func _virar_um_para_o_outro(a: Corpo, b: Corpo) -> void:
	var d := b.position - a.position
	d.y = 0.0
	a.rotation.y = atan2(-d.x, -d.z)
	b.rotation.y = atan2(d.x, d.z)


func _limpar_demo_captura() -> void:
	_demo_captura = false
	_limpar_motorista()
	var demo := get_node_or_null(^"CarroDemo")
	if demo != null:
		demo.queue_free()
	if _oficial != null:
		_oficial.position = _no_chao(_planta["posto_0"])
		_oficial.falar(false)


func _spawn_carro_demo(pos_local: Vector3, semente: int, tinta: Color) -> Node3D:
	var no := Node3D.new()
	var medidas := Carroceria.montar(Carroceria.Modelo.SEDA, tinta, semente)
	var lataria := MeshInstance3D.new()
	lataria.mesh = medidas["corpo"]
	lataria.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	no.add_child(lataria)
	var eixo: float = float(medidas["entre_eixos"]) * 0.5
	for z: float in [-eixo, eixo]:
		var mi := MeshInstance3D.new()
		mi.mesh = medidas["eixo_frente"]
		mi.material_override = load(Carroceria.MATERIAL)
		mi.position = Vector3(0.0, Carroceria.RAIO_RODA, z)
		no.add_child(mi)
	no.position = _no_chao(pos_local)
	add_child(no)
	return no


## Uniforme PM legivel em escala PSX: calca cinza, colete neon, bone branco.
static func _aparencia_pm(semente: int) -> Dictionary:
	var base := Aparencia.de_ficha({
		"id": absi(semente),
		"sexo": &"M",
		"idade": 28 + absi(semente) % 20,
	})
	base["casaco"] = true
	base["casaco_cor"] = Color(0.78, 0.92, 0.12)
	base["casaco_cel"] = 0
	base["camisa_cor"] = Color(0.45, 0.48, 0.5)
	base["calca_cor"] = Color(0.4, 0.42, 0.45)
	base["chapeu"] = true
	base["chapeu_cor"] = Color(0.95, 0.95, 0.93)
	base["chapeu_tipo"] = 1
	base["sapato_cor"] = Color(0.12, 0.12, 0.12)
	return base
