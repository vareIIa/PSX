## Missao 1, tarefa E: os dois ramos de ponta a ponta, na cidade, sem tela.
##
##   godot --headless --path game --fixed-fps 60 -- --teste-m1=aceita
##   godot --headless --path game --fixed-fps 60 -- --teste-m1=recusa
##
## Roda no jogo de verdade (`cidade.gd` liga pela bandeira): a casa da fumaca
## monta na rua, o dono atende a porta, o Marea anda pela malha e a cidade vai
## carregando em volta dele. As falas avancam sozinhas e as escolhas saem do
## piloto (`DiretorMissao1.piloto`); o jogador e movido por codigo onde o
## roteiro espera que ele ande (descer ao porao, sair pela porta, seguir o
## Berg, ir ate a praca).
##
## Imprime `[m1_e] ok/FALHOU ...` e sai com 1 se algo falhou.
extends Node

const PILOTO := {
	"aceita": [&"e1_contar", &"e2_aceitar", &"e3_entrar", &"e5_padre", &"e6_bonde"],
	"recusa": [&"e1_passagem", &"e2_recusar", &"e3_recusar"],
	# Atalho do fim da recusa (o mesmo do `--m1-igreja`): so 6B e 7.
	"igreja": [&"so_falas"],
}

var _falhas := 0
var _ramo := ""
var _j: Player
var _inicio := 0


func rodar(cena: Node, j: Player, ramo: String) -> void:
	_j = j
	_ramo = ramo
	name = "TesteM1"
	cena.add_child(self)
	_executar()


func _conferir(cond: bool, o_que: String) -> void:
	if cond:
		print("[m1_e] ok      %s" % o_que)
	else:
		_falhas += 1
		print("[m1_e] FALHOU  %s" % o_que)


func _esperar(s: float) -> void:
	await get_tree().create_timer(s).timeout


## Espera ate `cond` virar verdade ou o tempo (de jogo) acabar.
func _ate(cond: Callable, maximo: float) -> bool:
	var t := 0.0
	while t < maximo:
		if cond.call():
			return true
		await _esperar(0.25)
		t += 0.25
	return bool(cond.call())


func _etapa() -> String:
	return String(Missoes.etapa_atual().get("texto", ""))


func _flag(k: StringName) -> Variant:
	return Borboleta.valor(k, null)


func _executar() -> void:
	_inicio = Time.get_ticks_msec()
	print("\n=== M1-E: missao 1, ramo %s ===\n" % _ramo)
	if not PILOTO.has(_ramo):
		_conferir(false, "ramo conhecido (aceita|recusa): %s" % _ramo)
		_fim()
		return
	await _esperar(1.0)
	Borboleta.limpar()
	var piloto := {}
	for k: StringName in PILOTO[_ramo]:
		piloto[k] = true
	Missao1.piloto = piloto
	var aceita := _ramo == "aceita"
	if _ramo == "igreja":
		await AtalhosM1.ir_para_a_igreja(_j)
		await _berg_na_igreja()
		await _conferir_fim()
		return

	# --- Cena 1 --------------------------------------------------------------
	var casa := await AtalhosM1.ir_para_a_casa(_j)
	_conferir(not casa.is_empty(), "a casa da fumaca da missao montou")
	if casa.is_empty():
		_fim()
		return
	var porta := casa["porta"] as Porta
	_conferir(porta != null, "a porta da rua existe")
	_conferir(casa["dono"] != null, "o dono esta na casa")
	_conferir(Missao1.armada(), "a missao esta armada com a da casa aberta")
	if porta != null:
		porta.interagir(_j)
	var comecou := await _ate(func() -> bool: return Missao1.estado == DiretorMissao1.Estado.DONO, 30.0)
	_conferir(comecou, "bater na porta: o dono atende e a Cena 1 comeca na soleira")
	if not comecou and casa["dono"] != null:
		(casa["dono"] as Convidado).abordar(_j)
	var c1 := await _ate(func() -> bool: return Missao1.estado == DiretorMissao1.Estado.NA_CASA, 240.0)
	_conferir(c1, "Cena 1 terminou e a Missao 1 comecou")
	_conferir(_flag(&"m1_contou_ao_dono") == aceita, "E1 gravada (m1_contou_ao_dono = %s)" % aceita)
	_conferir(StringName(Missoes.atual.get("id", &"")) == &"missao1"
		and String(Missoes.atual.get("titulo", "")) == DiretorMissao1.TITULO,
		"HUD: VOCE NAO VAI LONGE")
	_conferir(_etapa() == "Saia da casa da fumaça.", "etapa 2: %s" % _etapa())
	_conferir(String(Missoes.etapa_atual().get("dica", "")).contains("porão"), "a opcional do porao na HUD")
	_conferir(Inventario.tem(&"bilhete"), "o dono pagou (bilhete na bolsa)")
	_conferir(is_instance_valid(Missao1.carro) and is_instance_valid(Missao1.berg),
		"o Marea e o Berg esperam na calcada")
	if is_instance_valid(Missao1.carro):
		var d := Missao1.carro.global_position.distance_to(Missao1.casa_porta.origin)
		_conferir(d < 12.0, "o carro esta na porta da casa (%.1f m)" % d)
	_conferir(not Cinema.ativa, "o controle voltou ao jogador")
	var salvo := Missao1.para_dicionario()
	_conferir(int(salvo.get("estado", -1)) == DiretorMissao1.Estado.NA_CASA, "save no meio guarda a etapa")

	# --- Cena 2 (opcional) ------------------------------------------------------
	var estufa := Missao1.estufa_da_casa()
	_conferir(estufa != null, "a estufa (porao) da casa existe")
	if estufa != null:
		var degrau := estufa.to_global(EstufaBuilder.PORAO_ENTRADA)
		var meio := estufa.to_global(Vector3(2.0, 0.0, 1.6))
		Missao1.por_jogador(degrau, meio)
		var c2 := await _ate(func() -> bool: return Missao1.estado == DiretorMissao1.Estado.PORAO, 6.0)
		_conferir(c2, "pisar no ultimo degrau dispara a Cena 2")
		var c2_fim := await _ate(func() -> bool: return Missao1.estado == DiretorMissao1.Estado.NA_CASA, 180.0)
		_conferir(c2_fim, "Cena 2 terminou")
		_conferir(_flag(&"m1_desceu_ao_porao") == true, "m1_desceu_ao_porao")
		_conferir(_flag(&"m1_fumou_com_a_dupla") == aceita, "E2 gravada (m1_fumou_com_a_dupla = %s)" % aceita)
		_conferir(String(Missoes.etapa_atual().get("dica", "")).is_empty(), "a opcional saiu da HUD")
		if aceita:
			_conferir(get_tree().root.get_node_or_null(^"BaratoM1") != null, "o barato de 45 s ligou")

	# --- Cena 3 ------------------------------------------------------------------
	var vao: Vector3 = casa["vao"]
	var rua: Vector3 = casa["rua"]
	# Andando ate a calcada, como quem sobe do porao: a soleira fecha o buraco
	# do chao da estufa antes do pe chegar a calcada.
	Missao1.por_jogador(vao - rua * 2.5, vao)
	await _esperar(1.0)
	for i: int in 14:
		Missao1.por_jogador(vao - rua * (2.5 - 0.3 * float(i + 1)), vao + rua * 6.0)
		await _esperar(0.12)
	var c3 := await _ate(func() -> bool: return Missao1.estado == DiretorMissao1.Estado.BERG, 8.0)
	_conferir(c3, "sair pela porta da rua dispara a Cena 3")
	if not c3:
		var jj := Missao1.jogador()
		print("[m1_e] diag estado=%d em_cena=%s dentro=%s no_mundo=%s dist=%.2f carro=%s berg=%s cinema=%s pos=%s vao=%s" % [
			Missao1.estado, Missao1.em_cena, Interiores.dentro, Interiores.no_mundo,
			jj.global_position.distance_to(Missao1.casa_porta.origin), Missao1.carro != null,
			Missao1.berg != null, Cinema.ativa, jj.global_position, vao])

	if aceita:
		await _ramo_aceita()
	else:
		await _ramo_recusa()

	await _conferir_fim()


func _ramo_aceita() -> void:
	var seguir := await _ate(func() -> bool: return Missao1.estado == DiretorMissao1.Estado.SEGUIR_BERG, 900.0)
	_conferir(seguir, "Cenas 4A, 5A e 6A: chegou na praca de carona")
	_conferir(_flag(&"m1_aceitou_carona_berg") == true, "E3 gravada (entrou no carro)")
	_conferir(_flag(&"m1_contou_do_padre_ao_berg") == true, "E5 gravada (contou do padre)")
	_conferir(_flag(&"m1_falou_do_bonde") == true, "E6 gravada (falou do bonde)")
	_conferir(_etapa() == "Siga o Berg.", "etapa 3A: %s" % _etapa())
	_conferir(_j.visible and _j.process_mode == Node.PROCESS_MODE_INHERIT and Missao1.duble == null,
		"o jogador voltou no lugar do duble")
	var vaga: Transform3D = Lugares.igreja()["vaga"]
	if is_instance_valid(Missao1.carro):
		var d := Vector2(Missao1.carro.global_position.x - vaga.origin.x,
			Missao1.carro.global_position.z - vaga.origin.z).length()
		_conferir(d < 4.0, "o Marea estacionou na vaga da igreja (%.1f m)" % d)
	# Segue o Berg a dois metros e meio.
	var igreja := await _ate(func() -> bool:
		if Missao1.estado == DiretorMissao1.Estado.SEGUIR_BERG and is_instance_valid(Missao1.berg):
			var b := Missao1.berg
			var atras := b.global_position + b.global_transform.basis.z * 2.5
			_j.global_position = Missao1.no_chao(atras) + Vector3.UP * 0.05
		return Missao1.estado == DiretorMissao1.Estado.IGREJA, 180.0)
	_conferir(igreja, "seguir o Berg ate a escadaria dispara a Cena 7")


func _ramo_recusa() -> void:
	var praca := await _ate(func() -> bool: return Missao1.estado == DiretorMissao1.Estado.VOLTAR_PRACA, 300.0)
	_conferir(praca, "Cena 4B terminou")
	_conferir(_flag(&"m1_aceitou_carona_berg") == false, "E3 gravada (recusou)")
	_conferir(_etapa() == "Volte para a praça onde você acordou.", "etapa 3B: %s" % _etapa())
	var papel := Missao1.papel
	_conferir(papel != null and is_instance_valid(papel) and papel.no_chao(), "o papel do Berg esta na calcada")
	_conferir(Missao1.passeio == DiretorMissao1.Passeio.DIRIGINDO, "o Marea saiu passeando (NPC)")
	if papel != null and is_instance_valid(papel) and papel.item() != null:
		papel.item().interagir(_j)
		await _ate(func() -> bool: return _flag(&"m1_pegou_numero_berg") == true, 5.0)
	_conferir(_flag(&"m1_pegou_numero_berg") == true, "E4: pegou o papel")
	_conferir(RegistroCivil.conhecidos().has(Elenco.id(Elenco.BERG)), "BERG na agenda do celular")
	_conferir(_etapa() == "Ligue para o Berg.", "etapa 3B': %s" % _etapa())
	# A ligacao (tarefa D, conferida no m1_d) termina marcando esta flag.
	Borboleta.marcar(&"m1_ligou_pro_berg", true, false)
	await _esperar(0.3)
	_conferir(_etapa() == "Encontre o Berg na igreja.", "depois da ligacao: %s" % _etapa())
	_conferir(Missoes.posicao_do_alvo() != Vector3.INF, "alfinete verde na igreja")
	# Dois minutos de passeio e o sumico longe da vista.
	var sumiu := await _ate(func() -> bool: return Missao1.passeio != DiretorMissao1.Passeio.DIRIGINDO, 260.0)
	_conferir(sumiu, "o Marea passeou e saiu de cena (%s)" % DiretorMissao1.Passeio.keys()[Missao1.passeio])
	var ig := Lugares.igreja()
	await AtalhosM1.teleportar(_j, (ig["frente"] as Vector3) + Vector3(0.0, 0.0, 18.0), ig["frente"])
	await _berg_na_igreja()


func _berg_na_igreja() -> void:
	var ig := Lugares.igreja()
	var la := await _ate(func() -> bool:
		return Missao1.passeio == DiretorMissao1.Passeio.NA_IGREJA and is_instance_valid(Missao1.berg) \
			and Missao1.berg.vagando(), 60.0)
	_conferir(la, "o Berg reapareceu na igreja, andando pela area")
	var vaga: Transform3D = ig["vaga"]
	if is_instance_valid(Missao1.carro):
		var d := Vector2(Missao1.carro.global_position.x - vaga.origin.x,
			Missao1.carro.global_position.z - vaga.origin.z).length()
		_conferir(d < 4.0, "o Marea esta na vaga da igreja (%.1f m)" % d)
	if is_instance_valid(Missao1.berg):
		Missao1.berg.interagido.emit(_j)
	var c6 := await _ate(func() -> bool: return Missao1.estado == DiretorMissao1.Estado.IGREJA, 5.0)
	_conferir(c6, "falar com o Berg na igreja dispara a Cena 6B")


## Cena 7 e o depois, nos dois ramos.
func _conferir_fim() -> void:
	var fim := await _ate(func() -> bool: return Missao1.estado == DiretorMissao1.Estado.CONCLUIDA, 240.0)
	_conferir(fim, "Cena 7 terminou: missao concluida")
	_conferir(_flag(&"m1_concluida") == true, "m1_concluida")
	_conferir(StringName(Missoes.atual.get("id", &"")) != &"missao1", "a missao saiu da HUD")
	_conferir(not Elenco.dupla_no_porao, "Jota e Helmer voltaram para a estufa")
	_conferir(not Cinema.ativa and _j.process_mode == Node.PROCESS_MODE_INHERIT and _j.visible,
		"o jogador esta de volta, livre")
	_conferir(is_instance_valid(Missao1.berg) and Missao1.berg.rotulo == "Falar com Berg",
		"o Berg fica na praca, interativo")
	_fim()


func _fim() -> void:
	Missao1.piloto = {}
	print("[m1_e] tempo de jogo %.0f s" % ((Time.get_ticks_msec() - _inicio) / 1000.0))
	print("[m1_e] %s (%d falha(s))" % ["OK" if _falhas == 0 else "FALHOU", _falhas])
	AudioDirector.silenciar_tudo()
	await get_tree().process_frame
	get_tree().quit(1 if _falhas > 0 else 0)
