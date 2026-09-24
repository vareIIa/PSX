## O Trampo e o iWeed no dedo: cada toque passa pelo caminho de verdade do mouse
## (`Celular._mouse` com o botao e o movimento na posicao em pixels do ponto da
## tela), e a foto de cada passo sai recortada no aparelho.
##
##     godot --path game --resolution 1920x1080 res://tests/bancada_toque_apps.tscn -- --saida=<DIR ABSOLUTO>
##
## Os dados (pessoas conhecidas, a dupla da estufa, seis pedidos, a carteira de
## clientes) sao semeados aqui: sem cidade nenhum deles nasceria.
extends Node

const TELA := Vector2(146.0, 219.0)

var SP := ""
var jogador: Node3D
var _rig: CelularNaMao
var _n_foto := 0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--saida="):
			SP = a.trim_prefix("--saida=").path_join("")
	_rodar()


# --- mundo e dados ------------------------------------------------------------------

func _caixa(pai: Node3D, tam: Vector3, centro: Vector3, cor: Color) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = tam
	mi.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mi.material_override = mat
	pai.add_child(mi)
	mi.position = centro
	var corpo := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = tam
	col.shape = forma
	corpo.add_child(col)
	mi.add_child(corpo)


func _montar_mundo() -> void:
	var mundo := Node3D.new()
	mundo.name = "Mundo"
	add_child(mundo)
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0d1118")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("3a4a66")
	env.ambient_light_energy = 0.6
	amb.environment = env
	mundo.add_child(amb)
	_caixa(mundo, Vector3(20.0, 0.2, 20.0), Vector3(0.0, -0.1, 0.0), Color("3a3833"))
	_caixa(mundo, Vector3(6.0, 3.0, 0.3), Vector3(0.0, 1.5, -3.5), Color("6b5a4a"))
	var luz := DirectionalLight3D.new()
	luz.light_energy = 0.6
	mundo.add_child(luz)
	luz.rotation = Vector3(-0.8, 0.6, 0.0)


func _semear() -> Array[int]:
	# Gente conhecida para a rede do Trampo.
	var conhecidos: Array[int] = []
	for i in 40:
		var id := RegistroCivil.id_de_faixa(61000 + i * 37, 19, 64)
		if id < 0 or conhecidos.has(id):
			continue
		RegistroCivil.conhecer(id)
		conhecidos.append(id)
	# A dupla da estufa, como o teste do iWeed faz.
	for papel: StringName in [&"jota", &"helmer"]:
		var id := int(WorldState.obter(EntregasDaSuper.COORD, papel, -1))
		if id < 0:
			id = RegistroCivil.id_de_faixa(913000 + (7 if papel == &"jota" else 14), 22, 48)
			RegistroCivil.marcar_personagem(id, papel)
			WorldState.definir(EntregasDaSuper.COORD, papel, id)
		Profissoes.contratar(id, &"fazendeiro")
		Profissoes.contratar(id, &"entregador")
	# A carteira e seis pedidos novos. O iWeed fica inativo: o laco dele nao
	# expira nem gera nada enquanto a bancada toca.
	var clientes: Array = []
	for i in 10:
		var id := RegistroCivil.id_de_faixa(71000 + i * 53, 19, 64)
		clientes.append({"id": id, "desde": 0.0, "pedidos": i % 4, "satisfacao": 30.0 + float(i) * 7.0,
			"gosto": "super" if i % 3 == 0 else "maconha", "estado": "ativo", "olho": i == 2,
			"indicado_por": -1, "x9": false})
	WorldState.definir(IWeed.COORD, &"clientes", clientes)
	var agora := IWeed.agora()
	var pedidos: Array = []
	for i in 6:
		var c: Dictionary = clientes[i]
		pedidos.append({"n": i + 1, "cliente": int(c["id"]), "produto": "maconha", "qtd": 1 + i % 3,
			"preco": 30 + i * 11, "criado": agora, "inicio": agora + 3.0 + float(i),
			"fim": agora + 12.0 + float(i), "expira": agora + 2.4, "x": 20.0 + float(i) * 9.0, "y": 0.0,
			"z": -30.0, "lugar": "ORELHAO", "rua": "RUA %d" % (i + 1), "estado": "novo", "quem": "",
			"entregador": -1,
			"msgs": [["c", "Opa, tem %d de maconha? Pago %d." % [1 + i % 3, 30 + i * 11], 600]]})
	WorldState.definir(IWeed.COORD, &"pedidos", pedidos)
	WorldState.definir(IWeed.COORD, &"online", true)
	return conhecidos


# --- tempo e foto -------------------------------------------------------------------

func _passar(segundos: float) -> void:
	var fim := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < fim:
		await get_tree().process_frame


## A foto recortada no aparelho (os quatro cantos do vidro projetados, com folga).
func _foto(nome: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var caixa := Rect2(_rig.na_tela(Vector2.ZERO), Vector2.ZERO)
	for uv: Vector2 in [Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		caixa = caixa.expand(_rig.na_tela(uv))
	# `na_tela` fala nas coordenadas do viewport (as do evento do mouse); a
	# imagem sai no tamanho da janela.
	var escala := Vector2(img.get_size()) / get_viewport().get_visible_rect().size
	caixa = Rect2(caixa.position * escala, caixa.size * escala)
	caixa = caixa.grow(12.0).intersection(Rect2(Vector2.ZERO, Vector2(img.get_size())))
	var recorte := img.get_region(Rect2i(caixa))
	if _n_foto == 0:
		img.save_png(SP + "00_quadro_inteiro.png")
		print("[toque] tela %s, recorte %s" % [img.get_size(), caixa])
	_n_foto += 1
	recorte.save_png(SP + "%02d_%s.png" % [_n_foto, nome])
	print("[foto] %02d_%s" % [_n_foto, nome])


# --- o dedo -------------------------------------------------------------------------

func _px(p: Vector2) -> Vector2:
	return _rig.na_tela(p / TELA)


func _botao(p: Vector2, baixo: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = baixo
	ev.position = _px(p)
	ev.global_position = ev.position
	Celular.call("_mouse", ev)


func _mover(p: Vector2, de: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = _px(p)
	ev.global_position = ev.position
	ev.relative = _px(p) - _px(de)
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	Celular.call("_mouse", ev)


## Toque curto em `p`, como o mouse: chega, aperta, solta.
func _tocar(p: Vector2, espera: float = 0.3) -> void:
	_mover(p, p + Vector2(2.0, 0.0))
	await get_tree().process_frame
	_botao(p, true)
	await _passar(0.08)
	_botao(p, false)
	await _passar(espera)


## Aperta `p` e fotografa com o dedo embaixo; solta depois.
func _apertar_e_foto(p: Vector2, nome: String, soltar: bool = true) -> void:
	_mover(p, p + Vector2(2.0, 0.0))
	await get_tree().process_frame
	_botao(p, true)
	await _passar(0.15)
	await _foto(nome)
	if soltar:
		_botao(p, false)
		await _passar(0.3)


## Arrasto de `de` a `ate` em `passos` movimentos ao longo de `segundos`. Com
## `foto` nao vazio, fotografa no meio, com o dedo ainda embaixo.
func _arrastar(de: Vector2, ate: Vector2, segundos: float = 0.25, passos: int = 10,
		foto: String = "") -> void:
	_mover(de, de + Vector2(2.0, 0.0))
	await get_tree().process_frame
	_botao(de, true)
	await get_tree().process_frame
	var antes := de
	for i in passos:
		var q := de.lerp(ate, float(i + 1) / float(passos))
		_mover(q, antes)
		antes = q
		await _passar(segundos / float(passos))
		if not foto.is_empty() and i == passos / 2:
			await _foto(foto)
	_botao(ate, false)


func _app() -> AppCelular:
	return Celular.get("_app") as AppCelular


## O centro do alvo `id` que o app registrou no ultimo desenho (so para saber
## onde tocar: o toque em si vai pelo mouse).
func _onde(id: Array) -> Vector2:
	var alvos: Array = _app().get("_alvos")
	for a: Array in alvos:
		if a[1] is Array and (a[1] as Array) == id:
			return (a[0] as Rect2).get_center()
	push_error("[toque] alvo %s nao desenhado" % [id])
	print("[toque] FALTA alvo %s" % [id])
	return Vector2(-100.0, -100.0)


func _tem(id: Array) -> bool:
	for a: Array in _app().get("_alvos"):
		if a[1] is Array and (a[1] as Array) == id:
			return true
	return false


func _relatar(chave: String, valor: Variant, ok: bool) -> void:
	print("[toque] %s=%s%s" % [chave, str(valor), "" if ok else "  <-- FALHOU"])


func _tecla(codigo: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = codigo
	ev.physical_keycode = codigo
	ev.pressed = true
	if codigo >= KEY_A and codigo <= KEY_Z:
		ev.unicode = int(codigo) + 32
	Celular.call("_input", ev)
	await get_tree().process_frame
	var solta := ev.duplicate() as InputEventKey
	solta.pressed = false
	Celular.call("_input", solta)
	await get_tree().process_frame


# --- roteiro ------------------------------------------------------------------------

func _rodar() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(SP)
	_montar_mundo()
	jogador = (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Node3D
	add_child(jogador)
	jogador.global_position = Vector3(0.0, 0.05, 0.0)
	var conhecidos := _semear()
	# O motor do iWeed (a cidade o cria): sem ele a contraproposta nao responde.
	# Inativo, o laco dele nao gera nem expira pedido.
	add_child(IWeed.new())
	await _passar(0.8)
	Celular.abrir()
	await _passar(1.4)
	Celular.call("_acionar")
	await _passar(0.8)
	_rig = Celular.get("_rig") as CelularNaMao
	await _trampo(conhecidos)
	await _iweed()
	print("[toque] fim")
	get_tree().quit(0)


func _trampo(conhecidos: Array[int]) -> void:
	Celular.call("_lancar_sem_zoom", &"trampo")
	await _passar(0.4)
	var tr := _app() as AppTrampo
	_relatar("trampo_linhas", (tr.get("_lista") as Array).size(), (tr.get("_lista") as Array).size() > 8)
	# O primeiro toque do mouse tira a moldura da tecla.
	_mover(Vector2(73.0, 150.0), Vector2(70.0, 150.0))
	await _passar(0.2)
	await _foto("trampo_rede")

	# Linha apertada (realce) e solta: abre o perfil dela.
	var linha2 := _onde([&"linha", 0])
	await _apertar_e_foto(linha2, "trampo_linha_apertada", false)
	_botao(linha2, false)
	await _passar(0.4)
	var ficha: Dictionary = tr.ficha_aberta()
	_relatar("trampo_toque_abre_perfil", ficha.get("id", -1),
		int(ficha.get("id", -1)) == int((tr.get("_lista") as Array)[0]))
	await _foto("trampo_perfil")

	# O perfil rola com o dedo.
	await _arrastar(Vector2(73.0, 170.0), Vector2(73.0, 110.0), 0.35, 10)
	await _passar(0.6)
	var rp: Variant = tr.get("_rp")
	_relatar("trampo_perfil_rolou", rp.px, float(rp.px) > 10.0)
	await _foto("trampo_perfil_rolado")

	# ESC do rodape, apertado e solto: volta para a rede.
	var esc := _onde([&"rodape", "ESC"])
	await _apertar_e_foto(esc, "trampo_esc_apertado")
	_relatar("trampo_esc_volta", tr.ficha_aberta().is_empty(), tr.ficha_aberta().is_empty())
	await _foto("trampo_voltou")

	# Arrasto na lista: a foto no meio, com o dedo embaixo (nenhuma linha
	# realcada), e o embalo depois de soltar rapido.
	var rl: Variant = tr.get("_rl")
	await _arrastar(Vector2(73.0, 180.0), Vector2(73.0, 120.0), 0.3, 12, "trampo_arrastando")
	var logo := float(rl.px)
	await _passar(0.7)
	_relatar("trampo_lista_rolou", "%.1f -> %.1f" % [logo, float(rl.px)], float(rl.px) > 30.0)
	_relatar("trampo_embalo", float(rl.px) - logo, float(rl.px) - logo > 3.0)
	_relatar("trampo_arrasto_nao_abre", tr.ficha_aberta().is_empty(), tr.ficha_aberta().is_empty())
	await _foto("trampo_rolada")

	# Arrasto lento que para antes de soltar: sem embalo.
	var antes := float(rl.px)
	await _arrastar(Vector2(73.0, 110.0), Vector2(73.0, 150.0), 0.4, 8)
	var solto := float(rl.px)
	await _passar(0.5)
	_relatar("trampo_volta_com_dedo", "%.1f -> %.1f" % [antes, solto], solto < antes - 20.0)

	# A roda tambem rola.
	var r0 := float(rl.px)
	var roda := InputEventMouseButton.new()
	roda.button_index = MOUSE_BUTTON_WHEEL_DOWN
	roda.pressed = true
	roda.position = _px(Vector2(73.0, 140.0))
	Celular.call("_mouse", roda)
	await _passar(0.4)
	_relatar("trampo_roda", "%.1f -> %.1f" % [r0, float(rl.px)], float(rl.px) > r0 + 10.0)

	# O campo de busca tocado ganha o cursor; as letras vem do teclado.
	await _tocar(_onde([&"busca"]))
	_relatar("trampo_busca_foco", tr.digitando(), tr.digitando())
	var nome := String(RegistroCivil.identidade(conhecidos[3]).get("nome", "")).split(" ")
	var pedaco := nome[nome.size() - 1].substr(0, 4)
	for letra in pedaco:
		await _tecla(OS.find_keycode_from_string(letra))
	await _passar(0.2)
	await _foto("trampo_busca_digitada")
	await _tocar(_onde([&"rodape", "ENTER"]))
	_relatar("trampo_buscou", "%s: %d" % [pedaco, (tr.get("_lista") as Array).size()],
		bool(tr.get("_resultado")))
	await _foto("trampo_resultado")

	# ESC limpa a busca; ESC de novo sai do app para o inicio.
	await _tocar(_onde([&"rodape", "ESC"]))
	_relatar("trampo_esc_limpa", not bool(tr.get("_resultado")), not bool(tr.get("_resultado")))

	# Tecla: a moldura volta, e a seta anda como sempre.
	await _tecla(KEY_DOWN)
	await _tecla(KEY_DOWN)
	await _passar(0.2)
	_relatar("trampo_tecla_sel", tr.get("_sel"), int(tr.get("_sel")) == 2)
	await _foto("trampo_tecla")
	_mover(Vector2(73.0, 150.0), Vector2(70.0, 150.0))
	await _passar(0.1)
	await _tocar(_onde([&"rodape", "ESC"]), 0.6)
	_relatar("trampo_esc_sai", Celular.get("_modo"), int(Celular.get("_modo")) != 2)
	await _foto("trampo_saiu")


func _iweed() -> void:
	Celular.call("_lancar_sem_zoom", &"iweed")
	await _passar(0.4)
	var iw := _app() as AppIWeed
	_mover(Vector2(73.0, 150.0), Vector2(70.0, 150.0))
	await _passar(0.2)
	await _foto("iweed_pedidos")

	# Arrasto na lista de pedidos.
	var r: Variant = iw.get("_r")
	await _arrastar(Vector2(73.0, 185.0), Vector2(73.0, 125.0), 0.3, 12, "iweed_arrastando")
	await _passar(0.7)
	_relatar("iweed_rolou", "%.1f" % float(r.px), float(r.px) > 30.0)
	_relatar("iweed_arrasto_nao_aceita", IWeed.abertos().size(), IWeed.abertos().size() == 6)
	await _foto("iweed_rolado")

	# Lista correndo no embalo: o toque so a segura, e nao aceita o cartao.
	await _arrastar(Vector2(73.0, 110.0), Vector2(73.0, 130.0), 0.1, 5)
	await _passar(0.05)
	var correndo := float(r.vel)
	await _tocar(Vector2(73.0, 120.0), 0.1)
	var parado := float(r.px)
	await _passar(0.3)
	_relatar("iweed_toque_segura_embalo", "vel %.0f, %d abertos, px %.1f -> %.1f" % [correndo,
		IWeed.abertos().size(), parado, float(r.px)], absf(correndo) > 40.0
		and IWeed.abertos().size() == 6 and absf(float(r.px) - parado) < 1.0)
	await _arrastar(Vector2(73.0, 185.0), Vector2(73.0, 125.0), 0.3, 12)
	await _passar(0.7)

	# Toque longo escolhe sem aceitar; o M do rodape abre a conversa dele.
	var k := int(float(r.px) / 41.0) + 1
	var p_card := _onde([&"item", k])
	_mover(p_card, p_card + Vector2(2.0, 0.0))
	_botao(p_card, true)
	await _passar(0.75)
	_botao(p_card, false)
	await _passar(0.3)
	_relatar("iweed_segurar_escolhe", iw.get("_sel"), int(iw.get("_sel")) == k
		and IWeed.abertos().size() == 6)
	await _foto("iweed_segurou")
	await _tocar(_onde([&"rodape", "M"]))
	_relatar("iweed_m_abre_chat", iw.chat_aberto(), iw.chat_aberto() == int(IWeed.abertos()[k]["n"]))
	await _foto("iweed_chat")
	await _apertar_e_foto(_onde([&"resposta", 1]), "iweed_resposta_apertada")
	await _foto("iweed_chat_respondido")
	await _apertar_e_foto(_onde([&"chat_voltar"]), "iweed_chat_voltar_apertado")
	_relatar("iweed_chat_fecha", iw.chat_aberto(), iw.chat_aberto() < 0)

	# Toque no primeiro cartao visivel aceita (E).
	var abertos_antes := IWeed.abertos().size()
	var alvo_k := int(float(r.px) / 41.0) + 1
	var n_alvo := int(IWeed.abertos()[alvo_k]["n"])
	await _apertar_e_foto(_onde([&"item", alvo_k]), "iweed_cartao_apertado")
	_relatar("iweed_toque_aceita", "%d -> %d" % [abertos_antes, IWeed.abertos().size()],
		String(IWeed.pedido(n_alvo).get("estado", "")) == "aceito")
	await _foto("iweed_aceito")

	# Mais dois na agenda, para a janela de dois cartoes dela ter o que rolar.
	for p: Dictionary in IWeed.abertos().slice(0, 2):
		IWeed.aceitar(int(p["n"]))

	# As abas, uma por uma, pelo toque.
	for aba in [1, 2, 3, 4, 5]:
		if aba == 2:
			await _apertar_e_foto(_onde([&"aba", aba]), "iweed_aba_apertada")
		else:
			await _tocar(_onde([&"aba", aba]))
		_relatar("iweed_aba_%d" % aba, iw.aba(), iw.aba() == aba)
		await _foto("iweed_aba_%s" % String(AppIWeed.NOMES_ABA[aba]).to_lower())
		if aba == 1:
			# A agenda rola dentro da janela dela; o que sai passa sob o
			# cabecalho e sob os recentes.
			await _arrastar(Vector2(73.0, 110.0), Vector2(73.0, 88.0), 0.5, 8, "iweed_agenda_arrastando")
			await _passar(0.5)
			_relatar("iweed_agenda_rolou", "%.1f de %.1f" % [float(r.px), float(r.maximo)],
				float(r.px) > 10.0)
			await _foto("iweed_agenda_rolada")
		if aba == 2:
			await _arrastar(Vector2(73.0, 180.0), Vector2(73.0, 110.0), 0.3, 10)
			await _passar(0.7)
			_relatar("iweed_clientes_rolou", "%.1f" % float(r.px), float(r.px) > 20.0)
			await _foto("iweed_clientes_rolado")
			# Cliente tocado abre o perfil no Trampo; o ESC tocado volta.
			var kc := int(float(r.px) / 27.0) + 1
			await _tocar(_onde([&"item", kc]), 0.5)
			_relatar("iweed_cliente_perfil", Celular.get("_app_id"), Celular.get("_app_id") == &"trampo")
			await _foto("iweed_cliente_no_trampo")
			await _tocar(_onde([&"rodape", "ESC"]), 0.5)
			_relatar("iweed_volta_do_perfil", Celular.get("_app_id"), Celular.get("_app_id") == &"iweed")
			iw = _app() as AppIWeed

	# A pilula: offline, e o botao da aba de pedidos poe online de novo.
	await _tocar(_onde([&"online"]))
	_relatar("iweed_pilula_offline", IWeed.online(), not IWeed.online())
	await _tocar(_onde([&"aba", 0]))
	var so_abertos := IWeed.abertos()
	for p: Dictionary in so_abertos:
		IWeed.recusar(int(p["n"]))
	await _passar(0.3)
	await _foto("iweed_offline")
	await _apertar_e_foto(_onde([&"ficar_online"]), "iweed_ficar_online_apertado")
	_relatar("iweed_ficar_online", IWeed.online(), IWeed.online())
	await _foto("iweed_online_de_novo")
	# O rodape A D anda uma aba.
	await _tocar(_onde([&"rodape", "A D"]))
	_relatar("iweed_rodape_ad", iw.aba(), iw.aba() == 1)
	await _tocar(_onde([&"aba", 4]))
	await _tocar(_onde([&"rodape", "ESC"]), 0.6)
	_relatar("iweed_esc_sai", Celular.get("_modo"), int(Celular.get("_modo")) != 2)
	await _foto("iweed_saiu")
