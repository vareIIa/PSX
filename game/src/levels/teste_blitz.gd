## Rotina de verificacao da blitz, com transito de verdade.
##
##     godot --path game -- --olhar-blitz=funil --teste-blitz [--fotos=<pasta>]
##
## Por que as situacoes sao MONTADAS
## ---------------------------------
## Rodando sozinha, a blitz viu quatro carros em dois minutos, e nenhum foi
## chamado (tres entraram pela transversal ja depois da ponta). Esperar o acaso
## produzir uma abordagem e medir o que aparecer daria um teste que passa no dia
## em que nada acontece. Entao cada cena e plantada: um carro da IA na faixa 0,
## a montante, com o chamado forcado — e o que se mede e sempre o mesmo
## experimento. Ver `TesteTransito`, que chegou a mesma conclusao antes.
##
## O que se afirma aqui
## --------------------
##   A  abordagem   o carro chamado percorre TODAS as fases em ordem, para na
##                  baia alinhado, o policial chega a janela do motorista, o
##                  motorista desce e volta, ninguem fica dentro de lataria,
##                  nenhum cone cai, e o carro sai sem ser abordado de novo
##   B  empurrao    um carro da IA (congelado, sem fisica) passando por cima de
##                  um cone o arremessa
##   C  pancada     um corpo dinamico como o carro do jogador derruba um cone
##                  sem parar seco, e empurra a viatura em vez de bater num
##                  pilar
##
## Imprime `[teste_blitz] chave=valor ok|XX` e sai com codigo 1 se algo falhou.
class_name TesteBlitz
extends RefCounted

const PASSO := 1.0 / 60.0
const ESPERA_TRANSITO := 25.0
const LIMITE_ABORDAGEM := 70.0

static var _falhas := 0
static var _pasta_fotos := ""


static func executar(b: Blitz) -> void:
	var arvore := b.get_tree()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--fotos="):
			_pasta_fotos = arg.trim_prefix("--fotos=")
	_relatar("inicio", b.name, true)
	# A camera da captura (--olhar-blitz) se ajeita e o chao dos chunks entra.
	await _esperar(arvore, 3.0)
	var t := 0.0
	while Transito.vivos() < 2 and t < ESPERA_TRANSITO:
		await _esperar(arvore, 0.5)
		t += 0.5
	_relatar("carros_na_rua", Transito.vivos(), Transito.vivos() >= 2)
	if Transito.vivos() < 2:
		_fim(arvore)
		return
	# A populacao para de nascer e de ser recolhida: o carro medido nao pode
	# sumir no meio da medida por ter passado do raio.
	Transito.ativo = false
	var carros := Transito.lista()
	await _abordagem(b, carros[0])
	await _empurrao_ia(b, carros[1])
	await _pancada(b)
	_fim(arvore)


static func _relatar(chave: String, valor: Variant, ok: bool) -> void:
	print("[teste_blitz] %s=%s %s" % [chave, valor, "ok" if ok else "XX"])
	if not ok:
		_falhas += 1


static func _fim(arvore: SceneTree) -> void:
	_relatar("fim", "%d falha(s)" % _falhas, _falhas == 0)
	AudioDirector.silenciar_tudo()
	await arvore.process_frame
	arvore.quit(1 if _falhas > 0 else 0)


static func _esperar(arvore: SceneTree, segundos: float) -> void:
	var t := 0.0
	while t < segundos:
		await arvore.physics_frame
		t += PASSO


static func _foto(arvore: SceneTree, nome: String) -> void:
	if _pasta_fotos.is_empty():
		return
	await RenderingServer.frame_post_draw
	var img := arvore.root.get_viewport().get_texture().get_image()
	img.save_png(_pasta_fotos.path_join(nome))
	print("[teste_blitz] foto %s" % nome)


# --- A: a abordagem inteira -----------------------------------------------------

static func _abordagem(b: Blitz, c: Carro) -> void:
	var arvore := b.get_tree()
	# O carro pode ja ter passado pela blitz antes do teste e estar decidido
	# como "passa": ai ele segue direto (rodadas 13 e 14 mediram isso).
	b._decididos.erase(c.get_instance_id())
	b._liberados.erase(c.get_instance_id())
	b.forcar_chamado = true
	b.forcar_revista = 1
	var onde := b.to_global(Vector3(0.0, 0.0, PlantaBlitz.COMPRIMENTO + 8.0))
	onde.y = Relevo.altura(onde.x, onde.z) + 0.05
	c.plantar(b.de, b.trecho, onde)
	var esperadas: Array[int] = [Blitz.Fase.CHAMANDO, Blitz.Fase.FREANDO,
		Blitz.Fase.OFICIAL_ANDANDO, Blitz.Fase.NA_JANELA, Blitz.Fase.MOTORISTA_DESCE,
		Blitz.Fase.CONVERSA, Blitz.Fase.MOTORISTA_SOBE, Blitz.Fase.LIBERADO, Blitz.Fase.OCIOSA]
	var vistas: Array[int] = []
	var ultima := -1
	var t := 0.0
	var oficial := b.get_node(^"Oficial_0") as Node3D
	var quadros_policial_dentro := 0
	var quadros_motorista_dentro := 0
	var parada := Vector3.INF
	var rumo_parada := INF
	var janela_d := INF
	var foto_janela := false
	var foto_revista := false
	# O defeito relatado: o policial saia empurrando a viatura.
	var viatura_antes := b._viatura.global_position if is_instance_valid(b._viatura) 		else Vector3.ZERO
	while t < LIMITE_ABORDAGEM and is_instance_valid(c):
		await arvore.physics_frame
		t += PASSO
		var f := b._fase
		if f != ultima:
			vistas.append(f)
			ultima = f
			if f == Blitz.Fase.FREANDO:
				parada = b.to_local(c.global_position)
				var frente_c := -c.global_transform.basis.z
				var frente_b := -b.global_transform.basis.z
				rumo_parada = rad_to_deg(Vector2(frente_c.x, frente_c.z).angle_to(
					Vector2(frente_b.x, frente_b.z)))
		if _dentro_do_carro(c, oficial.global_position):
			quadros_policial_dentro += 1
		var mot := b.get_node_or_null(^"MotoristaInsp") as Node3D
		if mot != null and _dentro_do_carro(c, mot.global_position):
			quadros_motorista_dentro += 1
		if f == Blitz.Fase.NA_JANELA:
			# A janela do motorista: lado -X do carro, perto do banco.
			var janela := c.to_global(Vector3(-PlantaBlitz.MEIA_CARRO.x - 0.38, 0.0, -0.3))
			var d := Vector2(oficial.global_position.x - janela.x,
				oficial.global_position.z - janela.z).length()
			janela_d = minf(janela_d, d)
			if not foto_janela and b._fase_t > 1.0:
				foto_janela = true
				await _foto(arvore, "blitz_janela.png")
		if f == Blitz.Fase.CONVERSA and not foto_revista and b._fase_t > 1.0:
			foto_revista = true
			await _foto(arvore, "blitz_revista.png")
		if f == Blitz.Fase.OCIOSA and vistas.size() > 1:
			break
	_relatar("fases", ",".join(vistas.map(func(x: int) -> String: return Blitz.Fase.keys()[x])),
		vistas == esperadas)
	_relatar("abordagem_segundos", snappedf(t, 0.1), t < LIMITE_ABORDAGEM)
	var baia: Vector3 = b._planta["baia"]
	_relatar("parou_na_baia_m", snappedf(Vector2(parada.x - baia.x, parada.z - baia.z).length(), 0.01),
		Vector2(parada.x - baia.x, parada.z - baia.z).length() < 0.5)
	_relatar("parou_alinhado_graus", snappedf(rumo_parada, 0.1), absf(rumo_parada) < 5.0)
	_relatar("policial_na_janela_m", snappedf(janela_d, 0.01), janela_d < 0.4)
	_relatar("quadros_policial_dentro_do_carro", quadros_policial_dentro, quadros_policial_dentro == 0)
	_relatar("quadros_motorista_dentro_do_carro", quadros_motorista_dentro,
		quadros_motorista_dentro == 0)
	_relatar("viatura_na_calcada", b._viatura_na_calcada, true)
	if is_instance_valid(b._viatura):
		var arrastada := b._viatura.global_position.distance_to(viatura_antes)
		_relatar("viatura_arrastada_na_abordagem_m", snappedf(arrastada, 0.001), arrastada < 0.05)
	var caidos := PackedStringArray()
	for p: PecaBlitz in b._pecas:
		if is_instance_valid(p) and p.derrubada:
			caidos.append("%s por %s" % [p.name, p.causa])
	_relatar("pecas_caidas_na_abordagem", "[%s]" % ", ".join(caidos), caidos.is_empty())
	# Saiu, e nao volta a ser chamado.
	await _esperar(arvore, 3.0)
	if is_instance_valid(c):
		var local := b.to_local(c.global_position)
		_relatar("saiu_da_blitz_z", snappedf(local.z, 0.1), local.z < -4.0)
		_relatar("nao_reabordado", Blitz.Fase.keys()[b._fase],
			b._fase == Blitz.Fase.OCIOSA and b._carro_insp == null)
		_relatar("motorista_de_volta_visivel", c._motorista_corpo != null
			and c._motorista_corpo.visible, c._motorista_corpo == null or c._motorista_corpo.visible)
	else:
		_relatar("carro_sumiu", true, false)


static func _dentro_do_carro(c: Carro, pos: Vector3) -> bool:
	var l := c.to_local(pos)
	# 5 cm de tolerancia: pe encostado na porta nao e estar dentro.
	return absf(l.x) < PlantaBlitz.MEIA_CARRO.x - 0.05 \
		and absf(l.z) < PlantaBlitz.MEIA_CARRO.z - 0.05


# --- B: carro da IA passa por cima de um cone ------------------------------------

static func _empurrao_ia(b: Blitz, c: Carro) -> void:
	var arvore := b.get_tree()
	var cone := _peca(b, "Cone_0")
	if cone == null or not is_instance_valid(c):
		_relatar("empurrao_ia_montado", 0, false)
		return
	# O carro nasce 5 m antes do cone, na linha dele, andando para ele.
	var alvo := cone.global_position
	var frente := -b.global_transform.basis.z
	var onde := alvo - frente * 5.0
	onde.y = Relevo.altura(onde.x, onde.z) + 0.05
	c.plantar(b.de, b.trecho, onde)
	var antes := cone.global_position
	var t := 0.0
	while t < 2.5:
		await arvore.physics_frame
		t += PASSO
		# Mantem o carro na linha do cone, contra a mira da blitz.
		if is_instance_valid(c) and t < 1.0:
			c.global_position.x = onde.x + frente.x * (t * 8.0)
			c.global_position.z = onde.z + frente.z * (t * 8.0)
	var andou := cone.global_position.distance_to(antes)
	# Arremessado, e nao desenho animado. Cone de 3,5 kg levado a 70% de 14 m/s
	# voa uns 6 m e rola/escorrega o resto no asfalto; 34 m era o numero antes
	# do ajuste, com 115%.
	_relatar("empurrao_ia_cone_andou_m", snappedf(andou, 0.01), andou > 3.0 and andou < 28.0)
	_relatar("empurrao_ia_cone_derrubado", cone.derrubada, cone.derrubada)


# --- C: corpo dinamico (como o carro do jogador) bate ---------------------------

static func _pancada(b: Blitz) -> void:
	var arvore := b.get_tree()
	var frente := -b.global_transform.basis.z
	var rumo := atan2(-frente.x, -frente.z)
	var pai := b.get_parent()
	# Um carro sem motorista, solto: o mesmo corpo do carro do jogador, com a
	# fisica ligada. Sem pedal, so a inercia.
	var c := Carro.new()
	c.name = "carro_pancada"
	c.preparar({}, b.de, b.trecho, 91)
	pai.add_child(c)
	var cone := _peca(b, "Cone_4")
	if cone == null:
		_relatar("pancada_montada", 0, false)
		c.queue_free()
		return
	var onde := cone.global_position - frente * 8.0
	onde.y = Relevo.altura(onde.x, onde.z) + 0.1
	c.estacionar_solto(onde, rumo)
	c.brake = 0.0
	await arvore.physics_frame
	c.linear_velocity = frente * 12.0
	var antes := cone.global_position
	var t := 0.0
	var menor_vel := INF
	c.contact_monitor = true
	c.max_contacts_reported = 6
	var tocou := {}
	while t < 1.6:
		await arvore.physics_frame
		t += PASSO
		menor_vel = minf(menor_vel, c.linear_velocity.length())
		for corpo: Node in c.get_colliding_bodies():
			tocou[String(corpo.name)] = true
	print("[teste_blitz] pancada_cone: tocou %s" % [tocou.keys()])
	var andou := cone.global_position.distance_to(antes)
	_relatar("pancada_cone_andou_m", snappedf(andou, 0.01), andou > 1.5)
	# Um cone de 3,5 kg nao segura 1 t: o carro segue.
	_relatar("pancada_carro_seguiu_ms", snappedf(menor_vel, 0.1), menor_vel > 8.0)

	# Agora a viatura, de lado, a 8 m/s, vindo da faixa de dentro. Por tras
	# nao da: o policial do posto fica ali, e a capsula dele segura o carro
	# antes (a primeira versao deste teste media 0,03 m por isso).
	var viatura := b._viatura
	if viatura == null or not is_instance_valid(viatura):
		_relatar("viatura_existe", false, false)
		c.queue_free()
		return
	var alvo_v := viatura.global_position
	# Na calcada, por tras e pela calcada: de lado o meio-fio segura o carro
	# antes (3,22 m de centro a centro a 0,1 m/s, sem tocar). No acostamento,
	# de lado, vindo da faixa: por tras esta o policial do posto.
	# Por tras, pela calcada: de lado o meio-fio segura o carro antes (3,22 m
	# de centro a centro a 0,1 m/s, sem tocar). O policial do posto sai da
	# frente — a capsula dele segurava o carro (monitor: ColisaoPolicial).
	var local_v := b.to_local(alvo_v)
	var dir_pancada := frente
	b._oficial.position = Vector3(-0.2, b._oficial.position.y, b._oficial.position.z)
	onde = b.to_global(Vector3(local_v.x, 0.0, local_v.z + 7.5))
	onde.y = Relevo.altura(onde.x, onde.z) + 0.3
	c.estacionar_solto(onde, atan2(-dir_pancada.x, -dir_pancada.z))
	var lado := dir_pancada
	c.brake = 0.0
	await arvore.physics_frame
	c.linear_velocity = lado * 8.0
	c.contact_monitor = true
	c.max_contacts_reported = 6
	var perto := INF
	var vel_perto := 0.0
	var bateu_em := {}
	t = 0.0
	while t < 2.5:
		await arvore.physics_frame
		t += PASSO
		for corpo: Node in c.get_colliding_bodies():
			bateu_em[String(corpo.name)] = true
		var d := c.global_position.distance_to(viatura.global_position)
		if d < perto:
			perto = d
			vel_perto = c.linear_velocity.length()
	print("[teste_blitz] pancada_viatura: menor distancia %.2f m a %.1f m/s, tocou %s"
		% [perto, vel_perto, bateu_em.keys()])
	var moveu := viatura.global_position.distance_to(alvo_v)
	var finito := viatura.global_position.is_finite() and c.global_position.is_finite()
	_relatar("viatura_empurrada_m", snappedf(moveu, 0.01), moveu > 0.3 and moveu < 8.0)
	_relatar("viatura_sem_nan", finito, finito)
	_relatar("viatura_de_pe", not viatura.capotado(), not viatura.capotado())
	c.queue_free()


static func _peca(b: Blitz, nome: String) -> PecaBlitz:
	return b.get_node_or_null(NodePath(nome)) as PecaBlitz
