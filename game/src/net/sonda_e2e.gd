## Sonda de ponta a ponta no jogo de verdade: cidade, `Player`, porta e item do
## chunk. O bot (`bot_rede.gd`) prova o protocolo sem cidade; esta sonda prova o
## que o bot nao alcanca: que a porta de uma casa da rua abre nas duas maquinas,
## que o item largado no chao vai para uma mochila so, e que quem sai volta ao
## proprio mundo sem perder o que carrega (plano 02, P11).
##
##     --mp-sonda=anfitriao|convidado  --sonda-t0=40  --sonda-ponto=270,-40
##
## Tudo acontece em horarios da hora do SERVIDOR a partir de `t0`, entao as duas
## maquinas agem no mesmo instante sem conversar alem do que o jogo ja conversa.
## A porta e escolhida pelas duas pela mesma regra (a de rua mais perto do
## `ponto`), e o item nasce nas duas com a mesma chave.
##
## Alem da porta e do item, as familias da `PoliticaDeMundo`:
## - MUNDO: o anfitriao contrata alguem (profissao) e o convidado ve; os dois
##   mexem em vagas diferentes da MESMA prateleira no mesmo instante e as duas
##   mudancas ficam (fusao por diferenca);
## - PESSOA: a carteira e a conversa do anfitriao nao chegam ao convidado;
## - COMODO pela rua: o convidado pega um item de dentro da casa que existe na
##   rua, parado na calcada (o servidor acha a casa pelo mapa).
##
## O item disputado e pego pela TECLA: o jogador mira (`olhar_para`), o raio da
## camera tem de escolher o item como alvo, e a acao `interagir` entra pelo
## viewport, o mesmo caminho do [E] (memoria: teste que chama o metodo nao aperta
## a tecla). A porta ainda e por metodo: a primeira vez e o dono que abre.
##
## O convidado ainda entra num comodo teleportado e sai, com o anfitriao em
## `--mp-validacao=corrigir`: a rota honesta nao pode levar correcao nenhuma.
##
## Caido e levantar: a vida do anfitriao zera; o convidado chega perto, mira o
## corpo e SEGURA o [E] por 3 s (a acao entra pelo `Input`, que e o que o
## segurar le). O anfitriao tem de levantar com 25 de vida, na mesma hora.
##
## No fim imprime `[sonda] RESULTADO {json}` e fecha o jogo. `tools/mp_e2e.sh`
## le essa linha.
class_name SondaE2E
extends Node

const ITEM := &"bandagem"
const INDICE_ITEM := 990
const CHAT := "oi-da-sonda"
## A casa da rua: item dela e a prateleira de teste.
const ITEM_CASA := &"remedio"
const INDICE_CASA := 991
const LOJA := Vector2i(-10, 424245)
const CHAVE_LOJA := &"loja_990"
## Uma pessoa qualquer da cidade, para a profissao e para a conversa.
const PESSOA := Vector2i(4242, 424243)
const SALDO_DO_ANFITRIAO := 7777
## A porta montada tem de estar aqui do ponto que o mapa deu.
const RAIO_PORTA := 12.0

var anfitriao := true
var t0 := 40.0
var ponto := Vector3(270.0, 0.0, -40.0)

var _feito: Dictionary = {}
var _porta: Node3D
var _item: Node3D
var _coord := Vector2i.ZERO
var _chave: StringName = &""
var _res: Dictionary = {"papel": "", "registros": {}}
var _inv_antes := 0
var _inv_casa_antes := 0
var _item_casa: Node3D
var _ouvido: PackedStringArray = []
var _prazo_final := 0.0


static func configurar(args: PackedStringArray) -> SondaE2E:
	var s: SondaE2E = null
	for a: String in args:
		if a.begins_with("--mp-sonda="):
			s = SondaE2E.new()
			s.anfitriao = a.trim_prefix("--mp-sonda=") == "anfitriao"
	if s == null:
		return null
	for a: String in args:
		if a.begins_with("--sonda-t0="):
			s.t0 = a.trim_prefix("--sonda-t0=").to_float()
		elif a.begins_with("--sonda-ponto="):
			var p := a.trim_prefix("--sonda-ponto=").split(",")
			if p.size() == 2:
				s.ponto = Vector3(p[0].to_float(), 0.0, p[1].to_float())
	return s


func _ready() -> void:
	name = "SondaE2E"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_res["papel"] = "anfitriao" if anfitriao else "convidado"
	Sessao.recado.connect(func(t: String) -> void: _ouvido.append(t))
	# Relogio de parede para desistir: se a sessao nunca subir, a hora do
	# servidor nunca chega a t0 e o teste ficaria aberto para sempre.
	_prazo_final = Time.get_ticks_msec() / 1000.0 + t0 + 90.0


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() / 1000.0 > _prazo_final:
		_res["erro"] = "prazo estourado (modo %d, mundo_pronto %s)" % [
			Sessao.modo, Sessao.mundo_pronto()]
		_terminar()
		return
	if not Sessao.em_rede() and not _feito.has("saiu"):
		return
	var t := Sessao.tempo_servidor() - t0 if Sessao.em_rede() else INF
	if t < -20.0:
		return
	if anfitriao:
		_roteiro_anfitriao(t)
	else:
		_roteiro_convidado(t)


func _roteiro_anfitriao(t: float) -> void:
	_uma_vez("ir", t >= -20.0, _ir_para_a_porta)
	_uma_vez("preparar", t >= 0.0, _preparar)
	_uma_vez("pessoais", t >= 0.2, _gravar_pessoais_do_anfitriao)
	_uma_vez("prateleira", t >= 0.5, _montar_prateleira)
	_uma_vez("mirar", t >= 0.7, _mirar)
	_uma_vez("pegar", t >= 1.0, _pegar)
	_uma_vez("abrir", t >= 3.0, _mexer_na_porta)
	_uma_vez("vaga", t >= 4.0, _tirar_da_vaga.bind("1"))
	_uma_vez("r1", t >= 6.0, _registrar.bind("r1"))
	_uma_vez("r2", t >= 9.5, _registrar.bind("r2"))
	_uma_vez("abrir2", t >= 10.0, _mexer_na_porta)
	_uma_vez("r3", t >= 13.0, _registrar.bind("r3"))
	_uma_vez("carregar", t >= 14.0, _carregar_save_fingido)
	_uma_vez("r5", t >= 19.5, _registrar.bind("r5"))
	_uma_vez("cai", t >= 20.5, _cair)
	_uma_vez("r_caido", t >= 21.5, _registrar_socorro.bind("r_caido"))
	_uma_vez("r_levantado", t >= 28.0, _registrar_socorro.bind("r_levantado"))
	_uma_vez("fim", t >= 34.0, _terminar)


func _roteiro_convidado(t: float) -> void:
	if _feito.has("saiu"):
		# Em SOLO a hora do servidor para: conta pelo relogio da maquina.
		_uma_vez("r4", Time.get_ticks_msec() / 1000.0 >= float(_feito["saiu"]) + 1.0,
			_registrar.bind("r4"))
		_uma_vez("fim", _feito.has("r4"), _terminar)
		return
	_uma_vez("ir", t >= -20.0, _ir_para_a_porta)
	_uma_vez("preparar", t >= 0.0, _preparar)
	_uma_vez("mirar", t >= 0.7, _mirar)
	_uma_vez("pegar", t >= 1.0, _pegar)
	_uma_vez("casa", t >= 2.0, _pegar_da_casa)
	_uma_vez("entrar", t >= 13.6, _entrar_num_comodo)
	_uma_vez("r_dentro", t >= 16.0, _registrar.bind("r_dentro"))
	_uma_vez("sair_comodo", t >= 16.5, func() -> void: Interiores.sair())
	_uma_vez("vaga", t >= 4.0, _tirar_da_vaga.bind("2"))
	_uma_vez("r1", t >= 6.0, _registrar.bind("r1"))
	_uma_vez("fechar", t >= 6.5, _mexer_na_porta)
	_uma_vez("r2", t >= 9.5, _registrar.bind("r2"))
	_uma_vez("r3", t >= 13.0, _registrar.bind("r3"))
	_uma_vez("falar", t >= 13.5, func() -> void: Sessao.falar(CHAT))
	_uma_vez("r5", t >= 19.5, _registrar.bind("r5"))
	_uma_vez("socorrer", t >= 21.5, _chegar_no_caido)
	_uma_vez("r_prompt", t >= 22.3, _registrar_prompt.bind("prompt_antes"))
	_uma_vez("segurar", t >= 22.5, _tecla.bind(true))
	_uma_vez("r_segurando", t >= 24.0, _registrar_prompt.bind("prompt_segurando"))
	_uma_vez("soltar", t >= 26.2, _tecla.bind(false))
	_uma_vez("sair", t >= 29.0, _sair)


func _uma_vez(nome: String, quando: bool, f: Callable) -> void:
	if quando and not _feito.has(nome):
		_feito[nome] = true
		f.call()


func _preparar() -> void:
	# Um chunk que so esta maquina "pisou" (longe de tudo): o mapa do grupo tem de
	# leva-lo ao outro no lote de visitados.
	WorldState.visitar(Vector2i(-777, 555) if not anfitriao else Vector2i(-778, 556))
	_res["viu"] = Sessao.avatares().size()
	_res["mundo_pronto"] = Sessao.mundo_pronto()
	_res["tem_jogador"] = Sessao.jogador_local() != null
	_porta = _achar_porta()
	if _porta != null:
		var id: Array = _porta.call("_identidade")
		_coord = id[0]
		_chave = id[1]
		_res["porta"] = "%d,%d|%s" % [_coord.x, _coord.y, _chave]
		_res["porta_compartilhada"] = _porta.call("_compartilhada")
	else:
		_res["porta"] = ""
	_inv_antes = Inventario.quantidade(ITEM)
	_inv_casa_antes = Inventario.quantidade(ITEM_CASA)
	# O item nasce igual nas duas maquinas: mesma chave, perto do jogador.
	var cena := get_tree().current_scene
	var jogador := Sessao.jogador_local()
	if cena == null or jogador == null:
		return
	var it := ItemNoChao.new()
	it.item_id = ITEM
	it.quantidade = 1
	it.chunk = _coord if _porta != null else ChaveMundo.coord_da_rua(jogador.global_position)
	it.indice = INDICE_ITEM
	# A posicao ANTES de entrar na arvore, como o chunk faz: o `_ready` do item
	# guarda a altura da flutuacao, e depois dele o item voltaria para ela.
	it.position = cena.to_local(_lugar_livre(jogador))
	cena.add_child(it)
	_item = it
	# O item de DENTRO da casa que existe na rua: chave pela semente da casa,
	# como `InteriorNoMundo` registra.
	if _porta != null:
		var casa := ItemNoChao.new()
		casa.item_id = ITEM_CASA
		casa.quantidade = 1
		casa.chunk = Vector2i(int(_porta.get("semente")), WorldState.INTERIOR)
		casa.indice = INDICE_CASA
		casa.position = cena.to_local(jogador.global_position + Vector3(0.0, 0.3, 0.0))
		cena.add_child(casa)
		_item_casa = casa
		_res["semente_casa"] = int(_porta.get("semente"))


## Um ponto a 1,3 m do jogador, na altura do peito, com a vista do olho ate ele
## livre (degrau, parede e gatilho de area tapariam o raio da camera). A cena em
## volta da porta muda com a cidade; a sonda procura em oito direcoes.
func _lugar_livre(j: Node3D) -> Vector3:
	var olho := j.global_position + Vector3.UP * 1.6
	var espaco := j.get_world_3d().direct_space_state
	for i in 8:
		var giro := TAU * float(i) / 8.0
		var alvo := j.global_position + Vector3(sin(giro), 0.0, cos(giro)) * 1.3 + Vector3.UP * 1.1
		var q := PhysicsRayQueryParameters3D.create(olho, alvo + (alvo - olho).normalized() * 0.5)
		q.collide_with_areas = true
		q.collision_mask = 1 | Interativo.CAMADA
		q.exclude = [(j as CollisionObject3D).get_rid()]
		if espaco.intersect_ray(q).is_empty():
			return alvo
	return j.global_position + Vector3(0.0, 1.1, 1.3)


func _pegar_da_casa() -> void:
	if is_instance_valid(_item_casa):
		_item_casa.call("interagir", Sessao.jogador_local())


## Da pessoa: a carteira e a conversa do anfitriao. Ficam na maquina dele.
## Do mundo: a profissao de alguem da cidade. Chega no convidado.
func _gravar_pessoais_do_anfitriao() -> void:
	WorldState.definir(Dinheiro.COORD, &"saldo", SALDO_DO_ANFITRIAO)
	FalasNpc.marcar(PESSOA.x, &"sonda")
	WorldState.definir(PESSOA, &"profissao", &"fazendeiro")


func _montar_prateleira() -> void:
	WorldState.definir(LOJA, CHAVE_LOJA, {"vagas": {"1": {"n": 5}, "2": {"n": 5}}})


## Cada um tira um da SUA vaga, no mesmo instante, a partir do que tem na tela:
## o jogo grava a prateleira inteira, e sem a fusao o segundo a chegar
## devolveria o produto do primeiro.
func _tirar_da_vaga(vaga: String) -> void:
	var d: Variant = WorldState.obter(LOJA, CHAVE_LOJA, null)
	if not (d is Dictionary):
		_res["prateleira_ausente"] = true
		return
	var novo: Dictionary = (d as Dictionary).duplicate(true)
	var v: Dictionary = novo["vagas"][vaga]
	v["n"] = int(v["n"]) - (1 if vaga == "1" else 2)
	WorldState.definir(LOJA, CHAVE_LOJA, novo)


func _mirar() -> void:
	var j := Sessao.jogador_local()
	if j != null and is_instance_valid(_item):
		j.olhar_para(_item.global_position)


## O [E] de verdade: a acao entra pelo viewport e o `Player` decide pelo alvo que
## o raio da camera escolheu.
func _pegar() -> void:
	var j := Sessao.jogador_local()
	if j == null or not is_instance_valid(_item):
		return
	_res["mirou_item"] = j.get("_alvo") == _item
	var raio := j.get_node_or_null("MiraInteracao") as RayCast3D
	var cam := j.get_viewport().get_camera_3d()
	_res["mira"] = {
		"cam": str(cam.global_position) if cam != null else "",
		"item": str(_item.global_position),
		"dist": cam.global_position.distance_to(_item.global_position) if cam != null else -1.0,
		"colide": raio.is_colliding() if raio != null else null,
		"com": str(raio.get_collider()) if raio != null and raio.is_colliding() else "",
		"raio_z": str(-raio.global_basis.z) if raio != null else "",
		"alvo": str(j.get("_alvo")),
	}
	var e := InputEventAction.new()
	e.action = &"interagir"
	e.pressed = true
	get_viewport().push_input(e)
	var solta := InputEventAction.new()
	solta.action = &"interagir"
	solta.pressed = false
	get_viewport().push_input(solta)


func _entrar_num_comodo() -> void:
	var j := Sessao.jogador_local()
	if j != null:
		_res["correcoes_antes"] = Sessao.correcoes
		Interiores.entrar(77123, j.global_transform, &"casa")


## A porta desta chave, viva. Quem entra num comodo teleportado descarrega a
## cidade, e na volta a porta e outro no, nascido com o estado do mundo.
func _porta_viva() -> Node3D:
	if is_instance_valid(_porta) or _chave == &"":
		return _porta if is_instance_valid(_porta) else null
	for n: Node in get_tree().get_nodes_in_group(&"porta"):
		if n.has_method("_identidade") and bool(n.get("mundo")):
			var id: Array = n.call("_identidade")
			if id[0] == _coord and id[1] == _chave:
				_porta = n as Node3D
				return _porta
	return null


func _mexer_na_porta() -> void:
	if _porta_viva() == null:
		return
	# Porta de casa com gente: [E] bate, e quem abre e o dono (`CasaViva`, ou a
	# paciencia de 16 s). A sonda faz o papel do dono na primeira vez; depois de
	# aberta a porta fica liberada — nas DUAS maquinas, pelo `_sincronizar` — e
	# o [E] passa a abrir e fechar.
	if bool(_porta.get("espera_dono")) and not bool(_porta.get("_liberada")) \
			and not bool(_porta.call("esta_aberta")):
		_porta.call("abrir_por_dentro")
		return
	_porta.call("interagir", Sessao.jogador_local())


func _registrar(nome: String) -> void:
	var r := {
		"modo": Sessao.modo,
		"aberta": _porta.call("esta_aberta") if _porta_viva() != null else null,
		"mundo_porta": WorldState.obter(_coord, _chave, null) if _chave != &"" else null,
		"mundo_item": WorldState.obter(_coord, StringName("item_%d" % INDICE_ITEM), null),
		"mochila": Inventario.quantidade(ITEM) - _inv_antes,
		"item_vivo": is_instance_valid(_item) and not bool(_item.get("_sumindo")),
		"viu": Sessao.avatares().size(),
		"correcoes": Sessao.correcoes,
		"visitou_marca": WorldState.visitado(Vector2i(-777, 555)),
		"visitou_marca_anf": WorldState.visitado(Vector2i(-778, 556)),
		"suspeitas": Sessao.suspeitas_total(),
		"espaco": Sessao.espaco_do_corpo(Sessao.jogador_local()) if Sessao.jogador_local() != null else -1,
		"mochila_casa": Inventario.quantidade(ITEM_CASA) - _inv_casa_antes,
		"mundo_casa": WorldState.obter(Vector2i(int(_res.get("semente_casa", 0)), WorldState.INTERIOR),
			StringName("item_%d" % INDICE_CASA), null),
		"saldo": WorldState.obter(Dinheiro.COORD, &"saldo", null),
		"falou_sonda": FalasNpc.ja_falou(PESSOA.x, &"sonda"),
		"profissao": String(WorldState.obter(PESSOA, &"profissao", "")),
		"prateleira": WorldState.obter(LOJA, CHAVE_LOJA, null),
	}
	(_res["registros"] as Dictionary)[nome] = r


## O anfitriao "carrega um save" no meio da sessao: o mundo em que a porta esta
## fechada. Sem tocar em disco — os espacos de save sao os do jogador de verdade
## (user:// e um so), e `SaveGame.carregar` so faz isto e mais o jogador.
func _carregar_save_fingido() -> void:
	var mundo := WorldState.para_dicionario().duplicate(true)
	var k := "%d,%d" % [_coord.x, _coord.y]
	if mundo.has(k):
		var d: Dictionary = mundo[k]
		# A chave do dicionario pode ser String ou StringName; troca a que existe.
		for c: Variant in d.keys():
			if String(c) == String(_chave):
				d[c] = false
	WorldState.de_dicionario(mundo)
	SaveGame.carregou.emit(0)


func _sair() -> void:
	_feito["saiu"] = Time.get_ticks_msec() / 1000.0
	Sessao.sair()


## Vai ate a porta de rua compartilhada mais perto do `ponto`, achada no MAPA
## (`ChunkBuilder.pontos_de_interesse`, funcao pura), e nao nos nos: perto da
## praca nao ha nenhuma, e as duas maquinas tem de escolher a mesma sem montar
## chunk. Vinte segundos antes de t0, para o streaming montar a casa em volta.
## O servidor so aceita porta a um chunk de quem pede (plano 04 secao 6).
func _ir_para_a_porta() -> void:
	var c0 := ChaveMundo.coord_da_rua(ponto)
	var alvo := Vector3.INF
	var d_melhor := INF
	for cx in range(c0.x - 8, c0.x + 9):
		for cz in range(c0.y - 8, c0.y + 9):
			for p: Dictionary in ChunkBuilder.pontos_de_interesse(cx, cz):
				if p.get("tipo") != &"porta" or not bool(p.get("mundo", false)) \
						or bool(p.get("deslizante", false)):
					continue
				var g := ChaveMundo.origem_da_rua(Vector2i(cx, cz)) + Vector3(p["pos"])
				var d := Vector2(g.x - ponto.x, g.z - ponto.z).length()
				if d < d_melhor:
					d_melhor = d
					alvo = g
	_res["alvo_mapa"] = [snappedf(alvo.x, 0.01), snappedf(alvo.z, 0.01)] if alvo != Vector3.INF else []
	var j := Sessao.jogador_local()
	if alvo == Vector3.INF or j == null:
		return
	ponto = alvo
	Sessao.anunciar_teletransporte()
	# Um do lado do outro, na calcada, a dois e a tres metros da porta.
	var lado := Vector3(2.0 if anfitriao else 3.0, 0.0, 0.0)
	j.global_position = alvo + lado + Vector3.UP * 1.0
	j.zerar_velocidade()


## A porta de rua que o mundo compartilha mais perto do `ponto` (depois de
## `_ir_para_a_porta`, a do mapa).
func _achar_porta() -> Node3D:
	var melhor: Node3D = null
	var d_melhor := RAIO_PORTA
	var contagem := {"todas": 0, "de_rua": 0}
	for n: Node in get_tree().get_nodes_in_group(&"porta"):
		var p := n as Node3D
		contagem["todas"] += 1
		# Hoje toda porta de rua compartilhada e a da casa da fumaca, que espera o
		# dono (`espera_dono`): o mercado e deslizante e a de fachada teleporta.
		if p == null or not bool(p.get("mundo")) or bool(p.get("deslizante")) \
				or bool(p.get("trancada")):
			continue
		if not bool(p.call("_compartilhada")):
			continue
		contagem["de_rua"] += 1
		var d := Vector2(p.global_position.x - ponto.x, p.global_position.z - ponto.z).length()
		if d < d_melhor:
			d_melhor = d
			melhor = p
	_res["portas"] = contagem
	_res["porta_distancia"] = snappedf(d_melhor, 0.01) if melhor != null else -1.0
	return melhor


## Anfitriao: a vida zera de uma vez, sem origem (queda, nao pancada).
func _cair() -> void:
	_res["relogio_antes"] = WorldState.relogio.minutos()
	Sessao.socorro.levantado.connect(func(por: String) -> void: _res["levantado_por"] = por)
	Inventario.ferir(Inventario.vida)


func _registrar_socorro(nome: String) -> void:
	var d := get_tree().get_first_node_in_group(&"desmaio") as Desmaio
	(_res["registros"] as Dictionary)[nome] = {
		"no_chao": d.no_chao() if d != null else null,
		"caido": Sessao.socorro.caido,
		"vida": Inventario.vida,
		"relogio": WorldState.relogio.minutos(),
		"travado": bool(Sessao.jogador_local().travado) if Sessao.jogador_local() != null else null,
	}


## Convidado: ao lado do amigo caido, a um metro, olhando para o corpo. Salto
## declarado, como qualquer teletransporte.
func _chegar_no_caido() -> void:
	var j := Sessao.jogador_local()
	var av: AvatarRemoto = null
	for id: int in Sessao.avatares():
		av = Sessao.avatares()[id]
	if j == null or av == null:
		_res["socorro_sem_alvo"] = true
		return
	var de_la := j.global_position - av.global_position
	de_la.y = 0.0
	de_la = de_la.normalized() if de_la.length() > 0.1 else Vector3.BACK
	j.global_position = av.global_position + de_la * 1.0 + Vector3.UP * 0.05
	j.velocity = Vector3.ZERO
	Sessao.anunciar_teletransporte()
	j.olhar_para(av.global_position + Vector3.UP * 0.3)
	_res["caidos_vistos"] = Sessao.socorro.caidos.keys()


func _registrar_prompt(nome: String) -> void:
	var j := Sessao.jogador_local()
	_res[nome] = String(j.get("_rotulo_alvo")) if j != null else ""
	# O que a mira ve, para quando o prompt nao aparece.
	var raio := j.get_node_or_null("MiraInteracao") as RayCast3D if j != null else null
	for id: int in Sessao.avatares():
		var av: AvatarRemoto = Sessao.avatares()[id]
		var alca := av.get_node_or_null(^"Socorro") as AlcaDeSocorro
		_res[nome + "_mira"] = {
			"com": str(raio.get_collider()) if raio != null and raio.is_colliding() else "",
			"ponto": str(raio.get_collision_point()) if raio != null and raio.is_colliding() else "",
			"av": str(av.global_position), "av_visivel": av.visible,
			"flags": int(av.estado.get("flags", 0)),
			"alca": alca.habilitado if alca != null else null,
			"camada": alca.collision_layer if alca != null else -1,
			"eu": str(j.global_position) if j != null else "",
			"travado": j.travado if j != null else null,
		}


## Aperta ou solta o [E] pelo `Input`: o `Player` recebe o aperto (e aciona o
## alvo) e o `Input.is_action_pressed` do segurar enxerga a tecla descendo.
func _tecla(apertar: bool) -> void:
	var e := InputEventAction.new()
	e.action = &"interagir"
	e.pressed = apertar
	Input.parse_input_event(e)


func _terminar() -> void:
	if _feito.has("impresso"):
		return
	_feito["impresso"] = true
	_res["ouvido"] = _ouvido
	print("[sonda] RESULTADO %s" % JSON.stringify(_res))
	get_tree().quit(0)
