## Atalhos da Missao 1 para jogar e conferir sem refazer a abertura.
##
##   --m1-casa     na calcada da casa da fumaca da primeira missao, de frente
##                 para a porta: [E] bate e a Cena 1 comeca.
##   --m1-saida    a Cena 1 ja feita: dentro da casa, perto da porta da rua.
##                 Descer a escada dos fundos e o porao; sair e o Berg.
##   --m1-igreja   ramo da recusa: o Berg ja esta na praca da igreja.
##
## A bancada automatica (`tests/m1_e.gd`) usa as mesmas funcoes.
class_name AtalhosM1
extends RefCounted

## Ate quanto esperar a cidade montar em volta de um ponto teleportado.
const ESPERA_CHUNK := 25.0


static func rodar(cena: Node, j: Player, modo: StringName) -> void:
	await cena.get_tree().create_timer(1.0).timeout
	match modo:
		&"casa":
			await ir_para_a_casa(j)
		&"saida":
			var casa := await ir_para_a_casa(j)
			if not casa.is_empty():
				await pular_cena_dono(j, casa)
		&"igreja":
			await ir_para_a_igreja(j)


## Comeca a missao da casa da fumaca, leva o jogador a porta e espera a casa
## montar. Devolve {interior, porta (Porta), dono, rua, vao} ou vazio.
static func ir_para_a_casa(j: Player) -> Dictionary:
	var arvore := j.get_tree()
	Missoes.limpar()
	var m := Missoes.comecar_primeira(j.global_position)
	if m.is_empty():
		push_warning("AtalhosM1: nenhuma casa da fumaca perto")
		return {}
	# Etapa 1 (o GPS ja marcado): falta chegar.
	Missoes.atual["etapa"] = 1
	Missoes.avancou.emit(Missoes.atual)
	var alvo: Vector3 = (m["alvo"] as Dictionary)["mundo"]
	await teleportar(j, alvo + Vector3(0.0, 0.0, 0.0), alvo)
	var interior: InteriorNoMundo = null
	var t := 0.0
	while t < ESPERA_CHUNK:
		interior = _interior_perto(arvore.current_scene, alvo)
		if interior != null and interior.pronta():
			break
		await arvore.create_timer(0.25).timeout
		t += 0.25
	if interior == null:
		push_warning("AtalhosM1: a casa nao montou")
		return {}
	var vao := interior.to_global(LoteNoMundo.centro_do_vao(interior.planta))
	var rua := -interior.global_transform.basis.z
	rua.y = 0.0
	rua = rua.normalized()
	await teleportar(j, vao + rua * 2.2, vao)
	# Ativa (IA, soleira) com o jogador a menos de 9 m: um respiro para nascer.
	await arvore.create_timer(1.5).timeout
	var porta: Porta = null
	for n: Node in arvore.get_nodes_in_group(&"porta"):
		var p := n as Porta
		if p != null and p.mundo and p.global_position.distance_to(vao) < 2.0:
			porta = p
	var dono: Convidado = null
	for n: Node in arvore.get_nodes_in_group(&"convidado"):
		var c := n as Convidado
		if c != null and c.dono_da_casa and DiretorMissao1._interior_de(c) == interior:
			dono = c
	return {"interior": interior, "porta": porta, "dono": dono, "rua": rua, "vao": vao}


## A Cena 1 pulada: a missao comeca com o jogador dentro, perto da porta.
static func pular_cena_dono(j: Player, casa: Dictionary) -> void:
	var dono := casa.get("dono") as Convidado
	if dono == null:
		push_warning("AtalhosM1: sem dono na casa")
		return
	Missao1.pular_cena_dono(dono)
	var vao: Vector3 = casa["vao"]
	var rua: Vector3 = casa["rua"]
	Missao1.por_jogador(vao - rua * 2.0, vao - rua * 6.0)


## Ramo da recusa, o Berg ja na praca: o jogador do outro lado do largo.
static func ir_para_a_igreja(j: Player) -> void:
	Missoes.limpar()
	Missao1.retomar_na_igreja()
	var ig := Lugares.igreja()
	var pe: Vector3 = ig["frente"]
	await teleportar(j, pe + Vector3(0.0, 0.0, 18.0), pe)


## Leva o jogador para longe sem ele cair no vazio: parado ate a cidade montar
## o chunk de destino com colisao, e so entao assentado no chao.
static func teleportar(j: Player, onde: Vector3, olhando: Vector3) -> void:
	var arvore := j.get_tree()
	j.process_mode = Node.PROCESS_MODE_DISABLED
	j.global_position = onde + Vector3.UP * 0.5
	var t := 0.0
	while t < ESPERA_CHUNK and not ChunkManager.esta_carregado(ChunkManager.coord_de(onde)):
		await arvore.create_timer(0.25).timeout
		t += 0.25
	# Um respiro para a colisao do chunk entrar no espaco de fisica.
	await arvore.create_timer(0.6).timeout
	j.process_mode = Node.PROCESS_MODE_INHERIT
	Missao1.por_jogador(onde, olhando)


static func _interior_perto(raiz: Node, alvo: Vector3) -> InteriorNoMundo:
	if raiz is InteriorNoMundo:
		var i := raiz as InteriorNoMundo
		if i.planta == &"casa_fumaca" and i.global_position.distance_to(alvo) < 30.0:
			return i
	for f: Node in raiz.get_children():
		var achado := _interior_perto(f, alvo)
		if achado != null:
			return achado
	return null
