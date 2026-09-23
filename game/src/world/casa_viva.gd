## O que faz a casa da fumaca ter gente morando dentro, e nao bonecos soltos.
##
## PLANO_CASA_FUMACA_V2, F5. Antes, cada Convidado sorteava um ponto e andava em
## linha reta ate ele: atravessava sofa, empacava na mesa para sempre, parava a
## dois metros de quem conversava e ignorava quem entrava. Este no e o diretor da
## casa, e da tres coisas aos convidados que moram nela:
##
##   caminho   uma malha de navegacao assada da colisao do lote, num MAPA
##             proprio (celula de 8 cm: a porta de 90 cm continua passando
##             gente de 28 cm de raio, e na celula de 25 cm do mapa padrao ela
##             fechava). Cada convidado ganha um NavigationAgent3D com desvio.
##   usos      lugares com uso — sofa, banqueta, cadeira da cozinha, pista de
##             danca na frente do som, janela para fumar, geladeira, estante de
##             CD — com reserva: dois nao sentam no mesmo lugar.
##   porta     quem bate na porta da rua chama o dono, que atravessa a casa e
##             abre por dentro.
##
## Tudo e opcional para o Convidado: fora de uma CasaViva (bar, estufa, mercado)
## ele continua exatamente como era.
class_name CasaViva
extends Node3D

## Celula da malha. Precisa ser igual a do mapa, e e por isso que o mapa e nosso.
const CELULA := 0.08
const RAIO_AGENTE := 0.28
## Raio que a malha desconta das paredes. Multiplo da celula (3 x 8 cm): fora da
## grade o motor arredonda para cima e avisa. A colisao da capsula (26 cm) cuida
## do resto.
const RAIO_MALHA := 0.24
## Cumprimento: no maximo um a cada tanto, senao a sala inteira diz "e ai" junta.
const INTERVALO_CUMPRIMENTO := 4.5

var _dados: Dictionary = {}
var _interior: InteriorNoMundo
var _mapa: RID
var _regiao: NavigationRegion3D
var _pronta := false
var _fila: Array[Convidado] = []
var _todos: Array[Convidado] = []
var _usos: Array[Dictionary] = []
var _ocupante: Array = []
var _ultimo_cumprimento := -99.0
var _obstaculo: NavigationObstacle3D
var _porta: Porta
var _relatar := false
var _relogio := 0.0
var presos := 0


func montar(dados: Dictionary, interior: InteriorNoMundo) -> void:
	_dados = dados
	_interior = interior
	_relatar = OS.get_cmdline_user_args().has("--relatar-casa")
	for u: Variant in dados.get("usos", []):
		_usos.append(u)
		_ocupante.append(null)

	_mapa = NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(_mapa, CELULA)
	NavigationServer3D.map_set_cell_height(_mapa, 0.05)
	NavigationServer3D.map_set_active(_mapa, true)

	var malha := NavigationMesh.new()
	malha.cell_size = CELULA
	malha.cell_height = 0.05
	malha.agent_radius = RAIO_MALHA
	malha.agent_height = 1.6
	malha.agent_max_climb = 0.10
	malha.agent_max_slope = 30.0
	malha.region_min_size = 1.0
	malha.edge_max_error = 1.0
	var fonte := NavigationMeshSourceGeometryData3D.new()
	var caixa := BoxMesh.new()
	# `so_caminho`: o que o caminho precisa saber e o corpo nao pode ter. Na loja
	# da rua, a vitrine e o portao sao do predio, com colisao propria, e a
	# calcada na frente da porta e do chunk (MercadoBuilder._so_caminho).
	var todas: Array = dados["colisao"].duplicate()
	todas.append_array(dados.get("so_caminho", []))
	for c: Dictionary in todas:
		caixa.size = c["tamanho"]
		fonte.add_faces(caixa.get_faces(), Transform3D(Basis(), c["pos"]))
	# Assada numa thread do motor. O retorno pode chegar de outra thread: o
	# resto acontece no quadro seguinte, na principal.
	NavigationServer3D.bake_from_source_geometry_data_async(malha, fonte,
		func() -> void: _assada.call_deferred(malha))


func _assada(malha: NavigationMesh) -> void:
	if not is_inside_tree():
		return
	_regiao = NavigationRegion3D.new()
	_regiao.name = "Caminho"
	_regiao.navigation_mesh = malha
	add_child(_regiao)
	_regiao.set_navigation_map(_mapa)
	_pronta = true
	var jogador := get_tree().get_first_node_in_group(&"player") as Node3D
	if jogador != null:
		# O jogador e um obstaculo para quem desvia: a roda abre espaco para ele
		# passar em vez de trombar e empurrar.
		_obstaculo = NavigationObstacle3D.new()
		_obstaculo.name = "ObstaculoCasa%d" % get_instance_id()
		_obstaculo.radius = 0.4
		_obstaculo.avoidance_enabled = true
		jogador.add_child(_obstaculo)
		_obstaculo.set_navigation_map(_mapa)
	for c: Convidado in _fila:
		if is_instance_valid(c):
			c.entrar_na_casa(self)
	_fila.clear()
	if OS.get_cmdline_user_args().has("--usos-cheios"):
		for c: Convidado in _todos:
			_encher(c)


## Captura (`--usos-cheios`): cada convidado livre vai direto para o proximo uso
## vago e fica. E o jeito de fotografar todas as posturas de uma vez, sem esperar
## o sorteio. Vale para quem ja estava e para quem nasce depois da malha.
func _encher(c: Convidado) -> void:
	if not is_instance_valid(c) or c.papel != Convidado.Papel.LIVRE or c.dono_da_casa:
		return
	for i in _usos.size():
		if _ocupante[i] == null:
			_ocupante[i] = c
			c.forcar_uso(i)
			return


func _exit_tree() -> void:
	if is_instance_valid(_obstaculo):
		_obstaculo.queue_free()
	if _mapa.is_valid():
		NavigationServer3D.free_rid.call_deferred(_mapa)


## O Convidado se apresenta quando nasce. Se o caminho ja esta pronto ele entra
## na hora; senao espera na fila.
func registrar(c: Convidado) -> void:
	_todos.append(c)
	c.adotar(self)
	if _pronta:
		c.entrar_na_casa(self)
		if OS.get_cmdline_user_args().has("--usos-cheios"):
			_encher(c)
	else:
		_fila.append(c)


func mapa() -> RID:
	return _mapa


func global_de(local: Vector3) -> Vector3:
	return to_global(local)


# --- usos ---------------------------------------------------------------------

## Reserva um uso livre para `c`, sorteado pelo peso. -1 se nao ha.
func reservar(c: Convidado, rng: RandomNumberGenerator) -> int:
	var total := 0.0
	var livres: Array[int] = []
	for i in _usos.size():
		if _ocupante[i] != null and is_instance_valid(_ocupante[i]):
			continue
		var u := _usos[i]
		if bool(u.get("so_fumante", false)) and not c.fumando:
			continue
		if int(u.get("ultimo", -1)) == c.get_instance_id():
			continue
		livres.append(i)
		total += float(u.get("peso", 1.0))
	if livres.is_empty():
		return -1
	var sorteio := rng.randf() * total
	for i in livres:
		sorteio -= float(_usos[i].get("peso", 1.0))
		if sorteio <= 0.0:
			_ocupante[i] = c
			return i
	_ocupante[livres[-1]] = c
	return livres[-1]


func liberar(i: int, c: Convidado) -> void:
	if i < 0 or i >= _usos.size():
		return
	if _ocupante[i] == c:
		_ocupante[i] = null
		_usos[i]["ultimo"] = c.get_instance_id()


func uso(i: int) -> Dictionary:
	return _usos[i]


func pode_cumprimentar() -> bool:
	var agora := Time.get_ticks_msec() / 1000.0
	if agora - _ultimo_cumprimento < INTERVALO_CUMPRIMENTO:
		return false
	_ultimo_cumprimento = agora
	return true


func jogador_dentro() -> bool:
	return _interior != null and _interior.jogador_dentro()


# --- a porta ------------------------------------------------------------------

## Liga a porta da rua. Quem bate chama o dono.
func ligar_porta(porta: Porta) -> void:
	_porta = porta
	if not porta.bateram.is_connected(_ao_bater):
		porta.bateram.connect(_ao_bater)


func _ao_bater() -> void:
	for c: Convidado in _todos:
		if is_instance_valid(c) and c.dono_da_casa:
			if c.atender_porta(global_de(_dados.get("porta_dentro", Vector3(3.4, 0.0, 0.9))),
					_porta):
				return
	# Sem dono em condicao de vir, a porta abre sozinha pelo tempo dela.


# --- medida -------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _relatar:
		return
	_relogio += delta
	if _relogio < 10.0:
		return
	_relogio = 0.0
	var contagem: Dictionary = {}
	for c: Convidado in _todos:
		if not is_instance_valid(c):
			continue
		var r := c.resumo()
		contagem[r] = int(contagem.get(r, 0)) + 1
	var ocupados := 0
	for o: Variant in _ocupante:
		if o != null and is_instance_valid(o):
			ocupados += 1
	print("[casa] pronta=%s %s usos_ocupados=%d/%d presos=%d" % [_pronta,
		str(contagem), ocupados, _usos.size(), presos])
