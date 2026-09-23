## Verificacao do iWeed, do Trampo e da conversa nova, jogando de verdade.
##
## Dois roteiros:
##   rua     (--teste-iweed)                 pedido nasce, notificacao, app, aceitar,
##           GPS, cliente no ponto, entrega sem e com mercadoria, pagamento,
##           equipe entregando perto do jogador, abas do app, Trampo, conversa.
##   estufa  (--entrar-estufa --teste-equipe) Jota e Helmer contratados como as duas
##           coisas, tarefas contadas, perfil pela conversa, saida pela porta com
##           uma entrega e volta pela mesma porta.
##
## Cada criterio sai como `[iweed] nome=valor`; `--iw-saida=PASTA` grava as fotos
## e encerra o jogo no fim, com codigo 1 se algum criterio falhou.
class_name TesteIWeed
extends Node

var _saida := ""
var _player: Node3D
var _falhas := 0


func rodar(modo: String) -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--iw-saida="):
			_saida = a.trim_prefix("--iw-saida=")
	if not _saida.is_empty():
		DirAccess.make_dir_recursive_absolute(_saida)
	_player = get_tree().get_first_node_in_group(&"player") as Node3D
	if modo == "estufa":
		await _estufa()
	else:
		await get_tree().create_timer(8.0).timeout
		await _rua()
	print("[iweed] fim=1 falhas=%d" % _falhas)
	if not _saida.is_empty():
		get_tree().quit(0 if _falhas == 0 else 1)


func _relatar(chave: String, valor: Variant, ok: bool) -> void:
	print("[iweed] %s=%s%s" % [chave, str(valor), "" if ok else "  <-- FALHOU"])
	if not ok:
		_falhas += 1


func _foto(nome: String) -> void:
	for _i in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if _saida.is_empty():
		return
	get_viewport().get_texture().get_image().save_png(_saida.path_join(nome))
	print("[iweed] foto %s" % nome)


func _esperar(s: float) -> void:
	await get_tree().create_timer(s).timeout


## Jota e Helmer como a estufa faria na primeira visita, e uma prateleira com o
## que entregar. A rua nao passa pela estufa, e sem isto nao haveria equipe.
func _equipe_de_teste() -> Array[int]:
	var ids: Array[int] = []
	for papel: StringName in [&"jota", &"helmer"]:
		var id := int(WorldState.obter(EntregasDaSuper.COORD, papel, -1))
		if id < 0:
			id = RegistroCivil.id_de_faixa(913000 + (7 if papel == &"jota" else 14), 22, 48)
			RegistroCivil.marcar_personagem(id, papel)
			WorldState.definir(EntregasDaSuper.COORD, papel, id)
		Profissoes.contratar(id, &"fazendeiro")
		Profissoes.contratar(id, &"entregador")
		ids.append(id)
	var semente := 77551 + 4242
	IWeed.registrar_estufa(semente, Plantio.POTES)
	var e := Plantio.estado(semente, Plantio.POTES)
	e["colhido"] = 12
	Plantio.gravar(semente, e)
	WorldState.definir(EntregasDaSuper.COORD, &"pendentes", 4)
	return ids


func _novo_pedido(iw: IWeed) -> Dictionary:
	for _tentativa in 6:
		var antes := int(WorldState.obter(IWeed.COORD, &"serie", 0))
		WorldState.definir(IWeed.COORD, &"proximo", IWeed.agora() + 99.0)
		var t0 := Time.get_ticks_usec()
		var ok := iw._gerar_pedido(IWeed.agora())
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0
		# Um pedido por varios minutos, mas num quadro so: acima de 8 ms vira
		# engasgo que o jogador sente no meio da corrida.
		_relatar("pedido_custo_ms", "%.2f" % ms, ms < 8.0)
		if ok:
			return IWeed.pedido(antes + 1)
		await _esperar(0.5)
	return {}


## Leva o jogador para perto do ponto, do lado de onde ele veio (a rua), e vira
## para o ponto.
func _ir_ao_ponto(onde: Vector3, de: Vector3, metros: float) -> void:
	var dir := Vector3(de.x - onde.x, 0.0, de.z - onde.z)
	dir = dir.normalized() if dir.length() > 0.1 else Vector3.BACK
	var alvo := onde + dir * metros
	var espaco := _player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(alvo + Vector3(0, 30, 0), alvo - Vector3(0, 30, 0), 1)
	var hit := espaco.intersect_ray(q)
	if not hit.is_empty():
		alvo.y = (hit["position"] as Vector3).y + 0.1
	_player.global_position = alvo
	await get_tree().physics_frame
	_player.call("olhar_para", onde + Vector3(0.0, 1.2, 0.0))


func _rua() -> void:
	var iw := IWeed.instancia()
	_relatar("motor_existe", iw != null, iw != null)
	if iw == null:
		return
	var equipe := _equipe_de_teste()
	_relatar("equipe_entregadores", IWeed.equipe().size(), IWeed.equipe().size() >= 2)
	IWeed.definir_online(true)
	await _esperar(1.0)
	var inicio_rua := _player.global_position

	# 1. Pedido nasce, com ponto no raio e notificacao.
	var p := await _novo_pedido(iw)
	_relatar("pedido_nasce", not p.is_empty(), not p.is_empty())
	if p.is_empty():
		return
	var n := int(p["n"])
	var d := Vector2(float(p["x"]) - inicio_rua.x, float(p["z"]) - inicio_rua.z).length()
	_relatar("ponto_no_raio", "%.0f m %s %s" % [d, p["lugar"], p["rua"]],
		d >= IWeed.RAIO.x - 1.0 and d <= IWeed.RAIO.y + 1.0)
	await _esperar(0.45)
	var hud := get_tree().get_first_node_in_group(&"hud_iweed") as HudIWeed
	var toasts := hud.notificacoes_na_tela() if hud != null else 0
	_relatar("notificacao_na_tela", toasts, toasts > 0)
	if hud != null:
		var longa := "TEREZINHA RODRIGUES te entregou. Tem blitz por perto, some dai."
		var linhas := hud._quebrar(longa, 8, HudIWeed.TOAST.x - 34.0)
		_relatar("notificacao_quebra", linhas.size(), linhas.size() == 2)
	await _foto("iw_toast.png")

	# 2. O app.
	Celular.abrir_app(&"iweed")
	await _esperar(0.6)
	_relatar("app_abre", Celular.app_atual(), Celular.app_atual() == &"iweed")
	await _foto("iw_pedidos.png")

	# 3. Aceitar marca o GPS.
	_relatar("aceita", IWeed.aceitar(n), String(IWeed.pedido(n)["estado"]) == "aceito")
	_relatar("gps_marcado", int(Gps.destino.get("iweed", -1)), int(Gps.destino.get("iweed", -1)) == n)
	Celular.iweed().definir_aba(1)
	await _foto("iw_agenda_aceito.png")
	Celular.fechar()
	await _esperar(0.8)
	await _foto("iw_cartao.png")

	# 4. O cliente aparece no ponto na hora combinada.
	var onde := IWeed.ponto(IWeed.pedido(n))
	await _ir_ao_ponto(onde, inicio_rua, 4.5)
	IWeed.pedido(n)["inicio"] = IWeed.agora() - 0.05
	await _esperar(1.2)
	var cli: ClienteIWeed = null
	if iw._clientes_no_mundo.has(n) and is_instance_valid(iw._clientes_no_mundo[n]):
		cli = iw._clientes_no_mundo[n]
	_relatar("cliente_aparece", cli != null, cli != null)
	if cli == null:
		return
	_player.call("olhar_para", cli.global_position + Vector3(0.0, 1.3, 0.0))
	await _foto("iw_cliente.png")

	# 5. Sem mercadoria: reclama e o pedido continua aberto.
	var produto := String(IWeed.pedido(n)["produto"])
	var item: StringName = IWeed.PRODUTOS[produto]["item"]
	var qtd := int(IWeed.pedido(n)["qtd"])
	var tinha := Inventario.quantidade(item)
	if tinha > 0:
		Inventario.remover(item, tinha)
	cli._ao_acionar(_player)
	await _esperar(0.3)
	_relatar("sem_mercadoria_recusa", String(IWeed.pedido(n)["estado"]),
		String(IWeed.pedido(n)["estado"]) == "aceito")
	await _esperar(1.6)

	# 6. Com mercadoria: paga o preco inteiro.
	Inventario.adicionar(item, qtd)
	var saldo0 := Dinheiro.saldo()
	cli._ao_acionar(_player)
	await _esperar(0.5)
	await _foto("iw_entregue.png")
	var pago := Dinheiro.saldo() - saldo0
	_relatar("entrega_paga", "%d de %d" % [pago, int(IWeed.pedido(n)["preco"])],
		String(IWeed.pedido(n)["estado"]) == "entregue" and pago == int(IWeed.pedido(n)["preco"]))
	_relatar("mercadoria_saiu", Inventario.quantidade(item), Inventario.quantidade(item) == 0)
	await _esperar(4.5)
	await _foto("iw_depois.png")
	_relatar("gps_limpo", Gps.destino.is_empty(), Gps.destino.is_empty())

	# 7. A equipe: passa o pedido, sai do estoque, entrega perto do jogador.
	var p2 := await _novo_pedido(iw)
	if p2.is_empty():
		_relatar("equipe_pedido", false, false)
		return
	var n2 := int(p2["n"])
	var estoque0 := IWeed.estoque(String(p2["produto"]))
	var passou := IWeed.passar(n2)
	var q2 := IWeed.pedido(n2)
	_relatar("equipe_pegou", "%s %s" % [passou, IWeed.apelido(int(q2.get("entregador", -1)))],
		passou and String(q2["estado"]) == "a_caminho")
	_relatar("estoque_baixou", "%d -> %d" % [estoque0, IWeed.estoque(String(p2["produto"]))],
		IWeed.estoque(String(p2["produto"])) == estoque0 - int(p2["qtd"]))
	_relatar("entregador_fora", IWeed.fora_em_entrega(int(q2["entregador"])),
		IWeed.fora_em_entrega(int(q2["entregador"])))
	var onde2 := IWeed.ponto(q2)
	await _ir_ao_ponto(onde2, _player.global_position, 6.0)
	await _esperar(1.0)
	var saldo1 := Dinheiro.saldo()
	q2["chega"] = IWeed.agora()
	await _esperar(3.2)
	_player.call("olhar_para", onde2 + Vector3(0.0, 1.2, 0.0))
	await _foto("iw_equipe_chegando.png")
	await _esperar(4.8)
	_player.call("olhar_para", onde2 + Vector3(0.0, 1.2, 0.0))
	await _foto("iw_equipe_troca.png")
	var parte := Dinheiro.saldo() - saldo1
	var esperado := int(roundf(float(q2["preco"]) * (1.0 - IWeed.COMISSAO)))
	_relatar("equipe_paga", "%d de %d" % [parte, esperado], parte == esperado)
	_relatar("equipe_estatistica", IWeed.estatisticas(int(q2["entregador"]))["entregas"],
		int(IWeed.estatisticas(int(q2["entregador"]))["entregas"]) >= 1)
	await _esperar(5.0)

	# 8. As abas do app.
	Celular.abrir_app(&"iweed")
	for k: int in [1, 2, 3, 4]:
		Celular.iweed().definir_aba(k)
		await _esperar(0.3)
		await _foto("iw_aba_%s.png" % String(AppIWeed.NOMES_ABA[k]).to_lower())
	Celular.fechar()
	await _esperar(0.4)

	# 9. Trampo: rede, busca e perfil da equipe.
	Celular.abrir_app(&"trampo")
	await _esperar(0.4)
	await _foto("tr_rede.png")
	var jota := RegistroCivil.identidade(equipe[0])
	var busca := String(jota["primeiro"]).substr(0, 4)
	Celular.trampo()._foco_busca = true
	Celular.trampo()._busca = busca
	Celular.trampo()._buscar()
	await _esperar(0.3)
	_relatar("trampo_busca", "%s -> %d" % [busca, Celular.trampo()._lista.size()],
		Celular.trampo()._lista.has(equipe[0]))
	await _foto("tr_busca.png")
	Celular.trampo().mostrar_perfil(jota, &"rede")
	await _esperar(0.6)
	await _foto("tr_perfil_jota.png")
	Celular.fechar()
	await _esperar(0.4)

	# 10. Loja, chat, legenda, X9 e blitz.
	await _loja()
	await _chat(iw)
	await _legenda()
	await _x9(iw, inicio_rua)
	await _blitz()

	# 11. A conversa nova, com a opcao TRABALHO.
	await _conversa_na_rua()


func _conversa_na_rua() -> void:
	var alvo: Pedestre = null
	for _t in 60:
		var melhor := INF
		for pe: Pedestre in Multidao.lista():
			if not is_instance_valid(pe) or not pe.visible:
				continue
			if not FalasNpc.tem_trabalho(pe.ficha):
				continue
			var dist := pe.global_position.distance_to(_player.global_position)
			if dist < melhor and dist < 70.0:
				melhor = dist
				alvo = pe
		if alvo != null:
			break
		await _esperar(0.5)
	_relatar("pedestre_com_trabalho", alvo != null, alvo != null)
	if alvo == null:
		return
	alvo.set_physics_process(false)
	var frente := alvo.global_position + (-alvo.global_transform.basis.z) * 1.8
	_player.global_position = Vector3(frente.x, alvo.global_position.y + 0.1, frente.z)
	await get_tree().physics_frame
	_player.call("olhar_para", alvo.global_position + Vector3(0.0, 1.55, 0.0))
	Conversa.abrir(alvo, alvo.ficha)
	await _esperar(0.9)
	await _foto("conv_fala.png")
	for _k in 6:
		if Conversa._fase == Conversa.Fase.ESCOLHENDO:
			break
		Conversa.avancar()
		await _esperar(0.1)
	await _esperar(0.5)
	var chaves := Conversa.chaves()
	_relatar("conversa_trabalho_na_lista", chaves.has(&"trabalho"), chaves.has(&"trabalho"))
	_relatar("conversa_cabe", chaves.size(), chaves.size() <= Conversa.MAX_OPCOES)
	await _foto("conv_lista.png")
	Conversa.escolher(&"trabalho")
	await _esperar(2.0)
	_relatar("trabalho_abre_perfil", Celular.app_atual(), Celular.ativo and Celular.app_atual() == &"trampo")
	await _foto("conv_trampo.png")
	Celular.fechar()
	await _esperar(0.3)
	_relatar("fechar_volta_a_lista", Conversa.ativo and Conversa._fase == Conversa.Fase.ESCOLHENDO,
		Conversa.ativo and Conversa._fase == Conversa.Fase.ESCOLHENDO)
	Conversa.escolher(&"voce")
	for _k in 8:
		await _esperar(0.25)
		if Conversa._fase == Conversa.Fase.ESCOLHENDO:
			break
		Conversa.avancar()
	await _esperar(0.4)
	_relatar("identificado", Conversa._sub_mostrado, not Conversa._sub_mostrado.contains("NAO IDENTIFICADO"))
	await _foto("conv_identificado.png")
	Conversa.fechar_a_forca()
	alvo.set_physics_process(true)


# --- estufa -----------------------------------------------------------------------

func _dupla() -> Dictionary:
	var saida := {}
	for no: Node in get_tree().get_nodes_in_group(&"convidado"):
		var c := no as Convidado
		if c == null or c.ficha.is_empty():
			continue
		var papel := RegistroCivil.personagem_de(int(c.ficha["id"]))
		if papel == &"jota" or papel == &"helmer":
			saida[papel] = c
	return saida


func _estufa() -> void:
	await _esperar(2.0)
	var d := _dupla()
	_relatar("dupla_na_estufa", d.size(), d.size() == 2)
	if d.size() < 2:
		return
	var jota := d[&"jota"] as Convidado
	var id_jota := int(jota.ficha["id"])
	_relatar("dupla_entregadora", Profissoes.titulos(id_jota),
		Profissoes.e(id_jota, &"entregador") and Profissoes.e(id_jota, &"fazendeiro"))
	_relatar("jota_canonico", int(WorldState.obter(EntregasDaSuper.COORD, &"jota", -1)) == id_jota,
		int(WorldState.obter(EntregasDaSuper.COORD, &"jota", -1)) == id_jota)
	var tarefas0 := int(IWeed.estatisticas(id_jota)["tarefas"]) \
		+ int(IWeed.estatisticas(int((d[&"helmer"] as Convidado).ficha["id"]))["tarefas"])
	await _esperar(22.0)
	var tarefas1 := int(IWeed.estatisticas(id_jota)["tarefas"]) \
		+ int(IWeed.estatisticas(int((d[&"helmer"] as Convidado).ficha["id"]))["tarefas"])
	_relatar("tarefas_contadas", "%d -> %d" % [tarefas0, tarefas1], tarefas1 > tarefas0)
	_relatar("jota_descreve", "\"%s\"" % IWeed.situacao(id_jota)["texto"], true)
	_player.call("olhar_para", jota.global_position + Vector3(0.0, 1.2, 0.0))
	await _foto("eq_trabalhando.png")

	# Perfil pela conversa.
	jota.abordar(_player)
	await _esperar(0.6)
	for _k in 6:
		if Conversa._fase == Conversa.Fase.ESCOLHENDO:
			break
		Conversa.avancar()
		await _esperar(0.1)
	await _esperar(0.4)
	_relatar("estufa_lista", Conversa.chaves(), Conversa.chaves().has(&"trabalho")
		and Conversa.chaves().size() <= Conversa.MAX_OPCOES)
	await _foto("eq_conversa.png")
	Conversa.escolher(&"trabalho")
	await _esperar(2.0)
	var perfil := Celular.trampo()._perfil
	_relatar("perfil_jota_agora", "\"%s\"" % perfil.get("agora", ""), not String(perfil.get("agora", "")).is_empty())
	await _foto("eq_perfil_jota.png")
	Celular.fechar()
	await _esperar(0.3)
	Conversa.fechar_a_forca()
	await _esperar(0.5)

	# Saida pela porta com uma entrega, e volta.
	var iw := IWeed.instancia()
	IWeed.definir_online(true)
	var p := await _novo_pedido(iw)
	_relatar("estufa_pedido", not p.is_empty(), not p.is_empty())
	if p.is_empty():
		return
	var semente := int(WorldState.obter(IWeed.COORD, &"estufa", 0))
	var e := Plantio.estado(semente, int(WorldState.obter(IWeed.COORD, &"vasos", Plantio.POTES)))
	e["colhido"] = maxi(int(e["colhido"]), 8)
	Plantio.gravar(semente, e)
	WorldState.definir(EntregasDaSuper.COORD, &"pendentes", maxi(EntregasDaSuper.pendentes(), 2))
	var n := int(p["n"])
	var passou := IWeed.passar(n)
	var id_sai := int(IWeed.pedido(n).get("entregador", -1))
	var quem := IWeed._convidado_vivo(id_sai)
	_relatar("estufa_equipe_pegou", "%s %s" % [passou, IWeed.apelido(id_sai)], passou and quem != null)
	if quem == null:
		return
	await _esperar(1.2)
	_player.call("olhar_para", quem.global_position + Vector3(0.0, 1.2, 0.0))
	await _foto("eq_saindo.png")
	var sumiu := false
	for _k in 60:
		await _esperar(0.5)
		if not is_instance_valid(quem):
			sumiu = true
			break
	_relatar("saiu_pela_porta", sumiu, sumiu)
	_relatar("perfil_diz_fora", "\"%s\"" % IWeed.situacao(id_sai)["texto"], bool(IWeed.situacao(id_sai)["fora"]))
	# Volta: chega, entrega na conta (longe do jogador) e volta.
	IWeed.pedido(n)["chega"] = IWeed.agora()
	await _esperar(0.8)
	IWeed.pedido(n)["volta"] = IWeed.agora()
	await _esperar(1.2)
	var voltou := IWeed._convidado_vivo(id_sai)
	_relatar("voltou_pela_porta", voltou != null, voltou != null)
	if voltou != null:
		var entrada := (get_tree().get_first_node_in_group(&"plantacao") as Node3D).global_position \
			+ EstufaBuilder.ENTRADA
		_player.call("olhar_para", entrada + Vector3(0.0, 1.2, 0.8))
		await _foto("eq_voltou.png")


# --- loja, chat, legenda, X9, blitz ------------------------------------------------

func _loja() -> void:
	Dinheiro.receber(1000, "TESTE")
	var saldo0 := Dinheiro.saldo()
	var r := IWeed.comprar("lampada")
	_relatar("loja_lampada", "%s nivel=%d fator=%.2f" % [r["texto"], IWeed.nivel("lampada"),
		Plantio.fator_crescimento], bool(r["ok"]) and IWeed.nivel("lampada") == 1
		and is_equal_approx(Plantio.fator_crescimento, 1.25))
	_relatar("loja_cobrou", saldo0 - Dinheiro.saldo(), saldo0 - Dinheiro.saldo() == 120)
	var sementes0 := Inventario.quantidade(&"semente_maconha")
	IWeed.comprar("semente")
	_relatar("loja_sementes", Inventario.quantidade(&"semente_maconha") - sementes0,
		Inventario.quantidade(&"semente_maconha") - sementes0 == 4)
	Celular.abrir_app(&"iweed")
	Celular.iweed().definir_aba(5)
	await _esperar(0.4)
	await _foto("iw_aba_loja.png")
	Celular.fechar()
	await _esperar(0.3)


func _chat(iw: IWeed) -> void:
	var p := await _novo_pedido(iw)
	if p.is_empty():
		_relatar("chat_pedido", false, false)
		return
	var n := int(p["n"])
	_relatar("chat_cliente_escreveu", IWeed.mensagens(IWeed.pedido(n)).size(),
		IWeed.mensagens(IWeed.pedido(n)).size() >= 2)
	var preco0 := int(IWeed.pedido(n)["preco"])
	var r := IWeed.negociar(n, 1.25)
	var q := IWeed.pedido(n)
	var coerente := (int(q["preco"]) > preco0) == bool(r.get("aceitou", false))
	_relatar("chat_negociou", "%s %d -> %d" % ["topou" if r.get("aceitou", false) else "nao",
		preco0, int(q["preco"])], bool(r["ok"]) and coerente and bool(q.get("negociado", false)))
	_relatar("chat_uma_vez", IWeed.negociar(n, 1.25).get("ok", false),
		not bool(IWeed.negociar(n, 1.25).get("ok", false)))
	Celular.abrir_app(&"iweed")
	Celular.iweed().abrir_chat(n)
	await _esperar(0.5)
	await _foto("iw_chat.png")
	if String(IWeed.pedido(n)["estado"]) == "novo":
		IWeed.aceitar(n)
		var fim0 := float(IWeed.pedido(n)["fim"])
		IWeed.atrasar(n)
		_relatar("chat_atrasar", "%.1f" % (float(IWeed.pedido(n)["fim"]) - fim0),
			float(IWeed.pedido(n)["fim"]) > fim0 and not IWeed.atrasar(n))
		await _esperar(0.3)
		await _foto("iw_chat_aceito.png")
		IWeed.pedido(n)["estado"] = "expirado"
	Celular.fechar()
	await _esperar(0.3)


func _legenda() -> void:
	Cinema.fala("JOTA (celular): Entrega saindo. Olha ali na frente.")
	await _esperar(0.8)
	var falante: Label = Cinema.find_child("LegendaFalante", true, false) as Label
	var texto: Label = Cinema.find_child("Legenda", true, false) as Label
	_relatar("legenda_falante", "\"%s\" / \"%s\"" % [falante.text if falante else "?",
		texto.text if texto else "?"], falante != null and falante.text == "JOTA  ·  CELULAR"
		and texto != null and texto.text.begins_with("Entrega"))
	await _foto("legenda_nova.png")
	await _esperar(2.5)


func _x9(iw: IWeed, inicio_rua: Vector3) -> void:
	var p := await _novo_pedido(iw)
	if p.is_empty():
		_relatar("x9_pedido", false, false)
		return
	var n := int(p["n"])
	var id := int(p["cliente"])
	for c: Dictionary in IWeed.clientes():
		if int(c["id"]) == id:
			c["x9"] = true
	IWeed.aceitar(n)
	await _ir_ao_ponto(IWeed.ponto(IWeed.pedido(n)), inicio_rua, 4.5)
	IWeed.pedido(n)["inicio"] = IWeed.agora() - 0.05
	await _esperar(1.2)
	var cli: ClienteIWeed = iw._clientes_no_mundo.get(n) as ClienteIWeed
	if cli == null:
		_relatar("x9_cliente", false, false)
		return
	var item: StringName = IWeed.PRODUTOS[String(IWeed.pedido(n)["produto"])]["item"]
	Inventario.adicionar(item, int(IWeed.pedido(n)["qtd"]))
	cli._ao_acionar(_player)
	await _esperar(0.6)
	_relatar("x9_procurado", BlitzNoCaminho.procurado(), BlitzNoCaminho.procurado())
	_relatar("x9_marcado", String(IWeed.cliente(id).get("estado", "")),
		String(IWeed.cliente(id).get("estado", "")) == "x9")
	await _esperar(5.0)


func _blitz() -> void:
	var b: Blitz = null
	for _k in 8:
		if not BlitzManager.lista().is_empty():
			b = BlitzManager.lista()[0]
			break
		BlitzManager.semear()
		await _esperar(1.0)
	if b == null:
		# Sem avenida perto do ponto de nascimento nao ha blitz: nao e falha do
		# sistema, e so o lugar.
		_relatar("blitz_disponivel", false, true)
		return
	Inventario.adicionar(&"maconha", 3)
	BlitzNoCaminho.marcar_procurado()
	var alvo := b.to_global(Vector3(-1.5, 0.0, 8.0))
	var espaco := _player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(alvo + Vector3(0, 30, 0), alvo - Vector3(0, 30, 0), 1)
	var hit := espaco.intersect_ray(q)
	if not hit.is_empty():
		alvo.y = (hit["position"] as Vector3).y + 0.1
	_player.global_position = alvo
	for _k in 20:
		await _esperar(0.2)
		if Conversa.ativo:
			break
	_relatar("blitz_abordou", Conversa.ativo and Conversa._contexto == &"blitz",
		Conversa.ativo and Conversa._contexto == &"blitz")
	if not Conversa.ativo:
		return
	await _esperar(1.0)
	for _k in 6:
		if Conversa._fase == Conversa.Fase.ESCOLHENDO:
			break
		Conversa.avancar()
		await _esperar(0.1)
	await _esperar(0.5)
	await _foto("blitz_abordagem.png")
	Conversa.escolher(&"blitz_colaborar")
	await _esperar(0.8)
	await _foto("blitz_resultado.png")
	_relatar("blitz_confiscou", Inventario.quantidade(&"maconha"), Inventario.quantidade(&"maconha") == 0)
	for _k in 6:
		if not Conversa.ativo:
			break
		Conversa.avancar()
		await _esperar(0.2)
	Conversa.fechar_a_forca()
	BlitzNoCaminho.procurado_ate = -1.0

