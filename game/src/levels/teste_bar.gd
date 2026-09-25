## Rotina de verificacao do Bar do Seu Ze.
##
## Imprime linhas `[bar] chave=valor` que tools/verificar_bar.py confere.
##
## O que este teste existe para provar, e que a versao anterior nao provava: o
## bar NAO e um interior. Nao ha porta, nao ha acionamento, nao ha carga. A
## rotina planta o jogador na calcada e o empurra para dentro de 15 em 15 cm,
## conferindo a cada parada que cabe uma pessoa em pe — se chegou ao fundo do
## salao sem atravessar nada, o lugar e o que se prometeu.
class_name TesteBar
extends RefCounted

const ESPERA_LONGA := 3.0

## Materiais que TEM de aparecer no chunk do bar. Sao o salao inteiro: piso,
## forro, azulejo de meia altura, formica do balcao, porta de cervejeira e pano
## de sinuca. Se um sumir numa refatoracao, o bar virou fachada pintada.
const SUPERFICIES_EXIGIDAS: Array[StringName] = [
	&"bar_piso", &"bar_teto", &"bar_parede", &"bar_azulejo", &"bar_formica",
	# A cadeira pelo balde de perto: o de longe e a troca dela, e o balde sem
	# nivel so tem o guarda-sol, que nem todo bar poe.
	MoveisDoBar.MAT_CADEIRA_PERTO, MoveisDoBar.MAT_CADEIRA_LONGE,
	&"bar_monobloco_mesa", &"bar_feltro", &"bar_letreiro", &"bar_ladrilho",
]

## Caminhada de entrada, em z local do bar: negativo e calcada, positivo e
## dentro do salao.
const CAMINHO_DE := -2.10
const CAMINHO_ATE := 4.60
const PASSO := 0.15
## Altura em que se mede se cabe gente em pe.
const PEITO := 0.95


static func executar(cena: Node, jogador: Node3D) -> void:
	var arvore := cena.get_tree()
	await arvore.create_timer(1.5).timeout

	_relatar("inicio", 1)
	_medir_cidade()

	# `--bar-vivo`: o mesmo teste num dos outros bares da cidade (BarVivo), e nao
	# no Seu Ze.
	var bar := _achar_bar_vivo() if OS.get_cmdline_user_args().has("--bar-vivo") 		else _achar_bar()
	if bar.is_empty():
		_relatar("bar_na_cidade", 0)
		_relatar("fim", 1)
		_encerrar(arvore)
		return
	_relatar("bar_na_cidade", 1)

	Multidao.parar()
	await _medir_no_lugar(arvore, jogador, bar)

	_relatar("fim", 1)
	_encerrar(arvore)


static func _encerrar(arvore: SceneTree) -> void:
	AudioDirector.silenciar_tudo()
	await arvore.process_frame
	arvore.quit(0)


static func _relatar(chave: String, valor: Variant) -> void:
	print("[bar] %s=%s" % [chave, valor])


# --- a cidade ---------------------------------------------------------------

## Quantos bares, mercados e casas a cidade produz, e o que o chunk do bar tem
## desenhado dentro dele. Tudo sem montar cena: `construir` e estatica.
static func _medir_cidade() -> void:
	var por_tipo: Dictionary[StringName, int] = {}
	var tris_bar := 0
	# As duas vistas do pior chunk de bar (ChunkManager.triangulos_por_vista).
	var vista_bar := Vector2i.ZERO
	var faltando: Array[String] = []
	var mesas := 0
	var portas_no_chunk_do_bar := 0
	# O pior tempo de `construir` entre os chunks de bar. Na thread, mas um chunk
	# que demora trava a fila do streaming inteira.
	var ms_construir := 0.0

	# Doze chunks, e nao seis: com a malha do Tracado o bar mais perto da origem
	# caiu no nono anel. O bar continua raro de proposito (ChunkBuilder), e a
	# janela do teste e que tinha de caber a cidade que o gerador produz.
	for cx in range(-12, 12):
		for cz in range(-12, 12):
			var tem_bar := false
			for ponto: Dictionary in ChunkBuilder.pontos_de_interesse(cx, cz):
				var tipo: StringName = ponto["tipo"]
				if tipo == &"porta":
					tipo = ponto["interior"]
				por_tipo[tipo] = int(por_tipo.get(tipo, 0)) + 1
				if ponto["tipo"] == &"bar":
					tem_bar = true
			if not tem_bar:
				continue

			var t0 := Time.get_ticks_usec()
			var dados := ChunkBuilder.construir(cx, cz)
			ms_construir = maxf(ms_construir, float(Time.get_ticks_usec() - t0) / 1000.0)
			var sup: Dictionary = dados["superficies"]
			for exigida: StringName in SUPERFICIES_EXIGIDAS:
				if not sup.has(exigida) or PSXMesh.dados_vazio(sup[exigida]):
					if not faltando.has(String(exigida)):
						faltando.append(String(exigida))
			var por_mat: Array[Array] = []
			var tris_deste := 0
			for mat: StringName in sup:
				var n := PSXMesh.dados_triangulos(sup[mat])
				tris_deste += n
				por_mat.append([n, String(mat)])
			# O teto e POR CHUNK: o pior bar, e nao a soma deles. A soma so valia
			# enquanto a janela tinha um bar so.
			tris_bar = maxi(tris_bar, tris_deste)
			var vista := ChunkManager.triangulos_por_vista(sup)
			vista_bar = Vector2i(maxi(vista_bar.x, vista.x), maxi(vista_bar.y, vista.y))
			# Quem esta pesando. Sem esta linha, "acima do teto" nao diz onde
			# cortar e a resposta vira trocar numero ate passar.
			por_mat.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
			var top: Array[String] = []
			for k in mini(8, por_mat.size()):
				top.append("%s:%d" % [por_mat[k][1], por_mat[k][0]])
			_relatar("peso", ",".join(top))
			# Mesa inteira (tampo e pernas) e o unico molde no balde da mesa: o numero
			# de mesas e o total do balde dividido pelo de uma (MoveisDoBar.mesa).
			# Conta as da calcada e as do salao juntas.
			if sup.has(MoveisDoBar.MAT_MESA):
				var uma := PSXMesh.dados_triangulos(MoveisDoBar.mesa()[MoveisDoBar.MAT_MESA])
				mesas = maxi(1, PSXMesh.dados_triangulos(sup[MoveisDoBar.MAT_MESA]) / uma)
			for prop: Dictionary in dados["props"]:
				if prop.get("tipo", "") == "porta":
					portas_no_chunk_do_bar += 1

	_relatar("bares", int(por_tipo.get(&"bar", 0)))
	_relatar("portas_mercado", int(por_tipo.get(&"mercado", 0)))
	_relatar("portas_casa", int(por_tipo.get(&"casa", 0)))
	_relatar("tris_do_chunk_do_bar", tris_bar)
	_relatar("tris_longe_do_chunk_do_bar", vista_bar.x)
	_relatar("tris_perto_do_chunk_do_bar", vista_bar.y)
	_relatar("ms_construir_bar", "%.1f" % ms_construir)
	_relatar("ms_salao", "%.2f" % _custo_do_salao())
	_relatar("superficies_faltando", faltando.size())
	if not faltando.is_empty():
		_relatar("faltou", ",".join(faltando))
	_relatar("mesas", mesas)
	_relatar("portas_no_chunk_do_bar", portas_no_chunk_do_bar)


## Primeiro bar da cidade, em coordenada de mundo.
static func _achar_bar() -> Dictionary:
	for raio in range(0, 13):
		for cx in range(-raio, raio + 1):
			for cz in range(-raio, raio + 1):
				if maxi(absi(cx), absi(cz)) != raio:
					continue
				for ponto: Dictionary in ChunkBuilder.pontos_de_interesse(cx, cz):
					if ponto.get("tipo", &"") != &"bar":
						continue
					var origem := Vector3(float(cx) * KitModular.CHUNK, 0.0,
						float(cz) * KitModular.CHUNK)
					return {
						"boca": origem + Vector3(ponto["pos"]),
						"giro": float(ponto["giro"]),
					}
	return {}


## O bar da BarVivo mais perto da origem. O lote dele sai do sorteio da fileira,
## entao so montando o chunk se sabe onde fica: o prop `ponto_bar` diz.
static func _achar_bar_vivo() -> Dictionary:
	for raio in range(0, 13):
		for cx in range(-raio, raio + 1):
			for cz in range(-raio, raio + 1):
				if maxi(absi(cx), absi(cz)) != raio:
					continue
				var porta := {}
				for ponto: Dictionary in ChunkBuilder.pontos_de_interesse(cx, cz):
					if ponto.get("tipo", &"") in [&"porta", &"bar"]:
						porta = ponto
				if not BarVivo.tem_bar(cx, cz, MalhaUrbana.quadra_de(cx, cz), porta):
					continue
				var dados := ChunkBuilder.construir(cx, cz)
				for prop: Dictionary in dados["props"]:
					if prop.get("tipo", "") != "ponto_bar":
						continue
					var origem := Vector3(float(cx) * KitModular.CHUNK, 0.0,
						float(cz) * KitModular.CHUNK)
					_relatar("bar_vivo", "\"%s\" em %d,%d" % [prop["nome"], cx, cz])
					return {"boca": origem + Vector3(prop["pos"]), "giro": float(prop["giro"])}
	return {}


## Quanto custa montar SO o bar (calcada e salao), sem o resto do chunk: a media
## de cinco montagens depois da primeira, que e a que monta os moldes.
static func _custo_do_salao() -> float:
	var total := 0.0
	for k in 6:
		var sup := {}
		var colisao: Array[Dictionary] = []
		var props: Array[Dictionary] = []
		var t0 := Time.get_ticks_usec()
		KitBar.frente(sup, colisao, Vector3.ZERO, 0.0, 10.0)
		KitBar.mesas_da_calcada(sup, colisao, Vector3.ZERO, 0.0, 10.0, {}, props)
		KitBar.salao(sup, colisao, props, Vector3.ZERO, 0.0, 10.0, 77)
		if k > 0:
			total += float(Time.get_ticks_usec() - t0) / 1000.0
	return total / 5.0


# --- o lugar ----------------------------------------------------------------

static func _medir_no_lugar(arvore: SceneTree, jogador: Node3D,
		bar: Dictionary) -> void:
	var boca: Vector3 = bar["boca"]
	var giro: float = bar["giro"]
	var b := Basis(Vector3.UP, giro)

	# Planta o jogador na calcada, de frente para o bar, e espera o chunk.
	jogador.global_position = _p(boca, b, 0.0, 0.0, CAMINHO_DE)
	if jogador.has_method("olhar_para"):
		jogador.call("olhar_para", _p(boca, b, 0.0, 1.4, 3.0))
	if jogador.has_method("zerar_velocidade"):
		jogador.call("zerar_velocidade")
	await arvore.create_timer(ESPERA_LONGA).timeout
	await _fotos_da_frente(arvore, jogador, boca, b)

	_medir_cena(arvore, boca)
	await _caminhar_para_dentro(arvore, jogador, boca, b)
	await _medir_vida(arvore, jogador, boca, b)


## O que existe de verdade montado no lugar. Conta nos, e nao dados: prop que o
## ChunkManager nao sabe criar aparece aqui como zero.
static func _medir_cena(arvore: SceneTree, boca: Vector3) -> void:
	var gente := 0
	var luzes := 0
	var tvs := 0
	var saves := 0
	var portas := 0
	for no: Node in _todos(arvore.current_scene):
		var n3 := no as Node3D
		if n3 == null or not n3.is_inside_tree():
			continue
		if n3.global_position.distance_to(boca) > 14.0:
			continue
		if no is Convidado:
			gente += 1
		elif no is Televisao:
			tvs += 1
		elif no is PontoDeSave:
			saves += 1
		elif no is Porta:
			portas += 1
		elif no is OmniLight3D or no is SpotLight3D:
			luzes += 1

	_relatar("gente_no_bar", gente)
	_relatar("tv", tvs)
	_relatar("ponto_de_save", saves)
	_relatar("luzes_no_bar", luzes)
	# A medida que resume a sessao inteira: nao ha porta nenhuma no bar.
	_relatar("portas_no_bar", portas)

	var fog := arvore.get_first_node_in_group(&"fog_controller") as FogController
	if fog != null:
		# O bar e rua: o clima nao pode trocar ao entrar. Se trocar, o lugar
		# voltou a ser interior sem ninguem perceber.
		_relatar("ambiente", String(fog.preset_ativo()))
	_relatar("dentro_de_interior", 1 if Interiores.dentro else 0)


static func _todos(no: Node) -> Array[Node]:
	var saida: Array[Node] = [no]
	for filho: Node in no.get_children():
		saida.append_array(_todos(filho))
	return saida


## A caminhada. Da calcada ate o fundo do salao, parando de 15 em 15 cm e
## medindo se cabe uma pessoa em pe naquele ponto.
static func _caminhar_para_dentro(arvore: SceneTree, jogador: Node3D,
		boca: Vector3, b: Basis) -> void:
	var espaco := jogador.get_world_3d().direct_space_state
	var forma := SphereShape3D.new()
	forma.radius = 0.35
	var bloqueado := 0
	var passos := 0
	var chegou := CAMINHO_DE
	var z := CAMINHO_DE
	while z <= CAMINHO_ATE:
		var onde := _p(boca, b, 0.0, 0.0, z)
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = forma
		q.transform = Transform3D(Basis.IDENTITY, onde + Vector3(0.0, PEITO, 0.0))
		q.collision_mask = 1
		q.exclude = [jogador.get_rid()]
		if not espaco.intersect_shape(q, 1).is_empty():
			bloqueado += 1
		else:
			chegou = z
		jogador.global_position = onde
		passos += 1
		await arvore.physics_frame
		z += PASSO

	_relatar("passos", passos)
	_relatar("caminho_bloqueado", bloqueado)
	_relatar("chegou_ate", snappedf(chegou, 0.01))
	_relatar("dentro_apos_caminhar", 1 if Interiores.dentro else 0)
	# Se andar para dentro tivesse disparado carga de interior, o jogador teria
	# sido teleportado para longe. Isto mede que ele continua no bar.
	_relatar("distancia_da_boca",
		snappedf(jogador.global_position.distance_to(boca), 0.01))


## Com `--bar-fotos=DIR`: a fachada da rua (letreiro, toldo, guarda-sol, a luz
## que vaza) e a calcada, com os enquadramentos do `--ver-bar` (cidade.gd).
static func _fotos_da_frente(arvore: SceneTree, jogador: Node3D, boca: Vector3,
		b: Basis) -> void:
	var fotos := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--bar-fotos="):
			fotos = a.trim_prefix("--bar-fotos=").path_join("")
	if fotos.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(fotos)
	var cenas := {"frente_rua": [Vector3(0.0, 0.0, -8.6), Vector3(0.0, 2.7, 0.0)],
		"frente_calcada": [Vector3(5.2, 0.0, -1.2), Vector3(0.0, 1.3, -1.2)],
		# O predio inteiro, da calcada do outro lado (Fase 4: o sobrado em cima).
		"predio": [Vector3(-2.5, 0.0, -13.0), Vector3(0.0, 5.2, 0.0)],
		"predio_quina": [Vector3(-9.0, 0.0, -10.0), Vector3(0.0, 4.6, 0.0)]}
	for nome: String in cenas:
		var par: Array = cenas[nome]
		var onde: Vector3 = par[0]
		var alvo: Vector3 = par[1]
		jogador.global_position = _p(boca, b, onde.x, onde.y, onde.z)
		if jogador.has_method("olhar_para"):
			jogador.call("olhar_para", _p(boca, b, alvo.x, alvo.y, alvo.z)
				- Vector3(0.0, Player.ALTURA_OLHO, 0.0))
		if jogador.has_method("zerar_velocidade"):
			jogador.call("zerar_velocidade")
		await arvore.create_timer(1.2).timeout
		await _foto(arvore, fotos + nome + ".png")
	# Rajada andando de lado, olhando sempre o mesmo ponto da fachada: face
	# coplanar pisca de uma posicao da camera para a outra (tests/bancada_coplanar).
	# `r_<t>.png` e o formato do tools/mosaico_rajada.py.
	var pasta := fotos.path_join("rajada")
	DirAccess.make_dir_recursive_absolute(pasta)
	var alvo_r := _p(boca, b, 0.0, 4.8, 0.0) - Vector3(0.0, Player.ALTURA_OLHO, 0.0)
	for k in 30:
		jogador.global_position = _p(boca, b, -1.5 + 0.1 * k, 0.0, -11.0)
		if jogador.has_method("olhar_para"):
			jogador.call("olhar_para", alvo_r)
		if jogador.has_method("zerar_velocidade"):
			jogador.call("zerar_velocidade")
		await arvore.process_frame
		await arvore.process_frame
		await _foto(arvore, pasta.path_join("r_%05.2f.png" % (0.1 * k)))
	jogador.global_position = _p(boca, b, 0.0, 0.0, CAMINHO_DE)


# --- a vida do bar (Fase 3) -----------------------------------------------------

## Quem bebe tem copo e gole, a mesa brinda, e o pedido do balcao sai da
## conversa, anda com quem atende e pousa na formica, onde o jogador pega.
##
## O pedido vai pelo caminho de verdade: abordar, avancar ate a lista, escolher
## a opcao, fechar a conversa. `--bar-fotos=DIR` fotografa cada momento.
static func _medir_vida(arvore: SceneTree, jogador: Node3D, boca: Vector3,
		b: Basis) -> void:
	var fotos := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--bar-fotos="):
			fotos = a.trim_prefix("--bar-fotos=").path_join("")
			DirAccess.make_dir_recursive_absolute(fotos)
	var vidas: Array[VidaDoBar] = []
	for no: Node in _todos(arvore.current_scene):
		if no is VidaDoBar and (no as Node3D).global_position.distance_to(boca) < 14.0:
			vidas.append(no as VidaDoBar)
	_relatar("vida_bares", vidas.size())
	if vidas.is_empty():
		return
	var salao: VidaDoBar = null
	for v: VidaDoBar in vidas:
		if v.atendente() != null:
			salao = v
	# Os copos esperam a pessoa estar sentada (primeiro quadro de pose).
	await arvore.create_timer(1.5).timeout
	var copos := 0
	var grupos := 0
	var tv := 0
	for v: VidaDoBar in vidas:
		var c := v.censo()
		copos += int(c["copos"])
		grupos += int(c["grupos"])
		tv += 1 if bool(c["tv"]) else 0
	_relatar("vida_copos", copos)
	_relatar("vida_grupos", grupos)
	_relatar("vida_atendente", 1 if salao != null else 0)
	_relatar("vida_tv", tv)

	# Um bebedor de perto: o copo na mao, e a mao na boca num gole.
	var bebedores: Array[Convidado] = []
	for v: VidaDoBar in vidas:
		bebedores.append_array(v.bebedores())
	var copos_na_mao := 0
	for no: Node in _todos(arvore.current_scene):
		if no is Node3D and no.name == &"CopoNaMao" and (no as Node3D).visible:
			copos_na_mao += 1
	_relatar("vida_copos_na_mao", copos_na_mao)
	var goles := 0
	var na_boca := 0.0
	# O bebedor fotografado e quem assiste a TV: sozinho na mesa, sem ninguem
	# na frente da camera. Fotos de lado, pela direita dele, ao longo do gole.
	# (KitBar._gente anota as mesas assim: o balcao, o par da parede, a TV.)
	var alvo: Convidado = null
	if salao != null and not salao.bebedores().is_empty():
		alvo = salao.bebedores().back()
	var fases_fotografadas := {}
	if alvo != null and not fotos.is_empty():
		# O Convidado olha para -Z: a camera fica na frente dele, meio de lado
		# (o copo e da mao direita, +X).
		_enquadrar(jogador, alvo.global_position,
			(alvo.global_basis.x - alvo.global_basis.z).normalized(), 1.0)
		await arvore.create_timer(0.5).timeout
		await _foto(arvore, fotos + "vida_gole_0_repouso.png")
		# Quem senta na banqueta, com o braco na formica (o primeiro do salao):
		# o antebraco nao pode atravessar a borda do balcao.
		var no_balcao: Convidado = salao.bebedores().front()
		for lado: Array in [["balcao_braco_dir", no_balcao.global_basis.x],
				["balcao_braco_tras", (no_balcao.global_basis.z * 1.2
					+ no_balcao.global_basis.x).normalized()]]:
			_enquadrar(jogador, no_balcao.global_position, lado[1], 1.1)
			await arvore.create_timer(0.5).timeout
			await _foto(arvore, fotos + String(lado[0]) + ".png")
		_enquadrar(jogador, alvo.global_position,
			(alvo.global_basis.x - alvo.global_basis.z).normalized(), 1.0)
		await arvore.create_timer(0.3).timeout
	for k in 320:
		await arvore.create_timer(0.05).timeout
		for c: Convidado in bebedores:
			var g := c.corpo().fumo as Gole
			if g != null:
				na_boca = maxf(na_boca, g.alcance())
		if alvo != null and not fotos.is_empty():
			var ga := alvo.corpo().fumo as Gole
			if ga != null and ga.ativo():
				var f := int(ga.fase())
				if not fases_fotografadas.has(f) and ga.progresso() > 0.5:
					fases_fotografadas[f] = true
					await _foto(arvore, fotos + "vida_gole_%d_%s.png" % [f,
						String(Tragada.Fase.keys()[f]).to_lower()])
		if k >= 160 and fases_fotografadas.size() >= 3:
			break
	var us_quadro := 0.0
	var us_tique := 0.0
	for v: VidaDoBar in vidas:
		var c := v.censo()
		goles += int(c["goles"])
		us_quadro += float(c["us_por_quadro"])
		us_tique += float(c["us_por_tique"])
	_relatar("vida_goles_16s", goles)
	# Custo dos dois diretores do bar somados (salao e calcada), com o jogador
	# dentro: o `_process` (copos e maos) por quadro e o tique de 0,2 s.
	_relatar("vida_us_por_quadro", snappedf(us_quadro, 0.1))
	_relatar("vida_us_por_tique", snappedf(us_tique, 0.1))
	_relatar("vida_mao_na_boca", snappedf(na_boca, 0.01))

	# O brinde, forcado (o sorteio e de meio minuto a um minuto).
	var par: Array[Convidado] = []
	for k in 60:
		for v: VidaDoBar in vidas:
			par = v.forcar_brinde()
			if not par.is_empty():
				break
		if not par.is_empty():
			break
		await arvore.create_timer(0.2).timeout
	var brindou := not par.is_empty()
	_relatar("vida_brinde", 1 if brindou else 0)
	if brindou and not fotos.is_empty():
		var meio := Vector3.ZERO
		for c: Convidado in par:
			meio += c.global_position
		meio /= maxf(1.0, float(par.size()))
		var lado := (par[0].global_position - meio).cross(Vector3.UP).normalized()
		_enquadrar(jogador, meio, lado, 1.5)
		await arvore.create_timer(0.45).timeout
		await _foto(arvore, fotos + "vida_brinde_sobe.png")
		await arvore.create_timer(0.3).timeout
		await _foto(arvore, fotos + "vida_brinde_bate.png")
	if brindou:
		# Onde esta a mao, o alvo dela e o copo de cada um no meio do brinde.
		for c: Convidado in par:
			var corpo := c.corpo()
			var copo := c.get_node_or_null("CopoNaMao") as Node3D
			var pega := corpo.pega_no_mundo().origin
			_relatar("vida_brinde_mao_%s" % c.name, "alvo=%s pega=%s copo=%s quadril=%s" % [
				str(corpo.agarrar), str(pega),
				str(copo.global_position) if copo != null else "-", str(c.global_position)])

	if salao != null:
		# A cerveja no meio do balcao (quem atende abaixa no freezer ali mesmo) e
		# a coxinha do fundo (anda ate a estufa, na outra ponta, e volta).
		await _pedir_no_balcao(arvore, jogador, salao, fotos, &"cerveja", 0.5, "bar")
		await _pedir_no_balcao(arvore, jogador, salao, fotos, &"coxinha", 1.0, "bar2")


## Pede `item` a quem atende, do ponto `t` do balcao, e segue o servico ate o
## pedido na formica. As chaves saem com o prefixo `px`.
static func _pedir_no_balcao(arvore: SceneTree, jogador: Node3D, salao: VidaDoBar,
		fotos: String, item: StringName, t: float, px: String) -> void:
	var at := salao.atendente()
	jogador.global_position = salao.lugar_do_cliente(t)
	if jogador.has_method("olhar_para"):
		jogador.call("olhar_para", at.global_position + Vector3(0.0, 0.2, 0.0))
	if jogador.has_method("zerar_velocidade"):
		jogador.call("zerar_velocidade")
	await arvore.create_timer(0.4).timeout
	Dinheiro.receber(20, "TESTE DO BAR")
	var saldo0 := Dinheiro.saldo()
	var antes := Inventario.quantidade(item)
	var opcao := StringName("bar_pedir_" + String(item))
	at.abordar(jogador)
	await arvore.create_timer(0.6).timeout
	for k in 12:
		Conversa.avancar()
		await arvore.process_frame
	var chaves := Conversa.chaves()
	if px == "bar":
		_relatar("bar_opcoes", ",".join(chaves))
	_relatar(px + "_opcao", 1 if chaves.has(opcao) else 0)
	Conversa.escolher(opcao)
	await arvore.create_timer(0.5).timeout
	_relatar(px + "_pagou", saldo0 - Dinheiro.saldo())
	# Pago nao e entregue: ainda nao esta na mochila.
	_relatar(px + "_na_mochila_antes", Inventario.quantidade(item) - antes)
	Conversa.fechar_a_forca()
	var p0 := at.global_position
	var andou := 0.0
	var agachou := false
	var pedido: PedidoNoBalcao = null
	var foto_agachado := false
	var t0 := Time.get_ticks_msec()
	for k in 200:
		await arvore.create_timer(0.1).timeout
		andou = maxf(andou, Vector2(at.global_position.x - p0.x,
			at.global_position.z - p0.z).length())
		if at.corpo() != null and at.corpo().agachado:
			agachou = true
			if not foto_agachado and not fotos.is_empty():
				await _foto(arvore, fotos + px + "_freezer.png")
				foto_agachado = true
		for no: Node in arvore.get_nodes_in_group(&"pedido_no_balcao"):
			pedido = no as PedidoNoBalcao
		if pedido != null:
			break
	_relatar(px + "_serviu", 1 if pedido != null else 0)
	_relatar(px + "_segundos_ate_servir", snappedf(float(Time.get_ticks_msec() - t0) / 1000.0, 0.1))
	_relatar(px + "_atendente_andou", snappedf(andou, 0.01))
	_relatar(px + "_agachou", 1 if agachou else 0)
	if pedido == null:
		return
	# Pousou no tampo: a altura sobre o piso onde o cliente pisa e a do tampo
	# visivel (KitBar.ALTURA_BALCAO + 5 cm do tampo). A colisao do balcao e mais
	# alta que a formica, e um raio mediria ela, e nao o que se ve.
	var espaco := jogador.get_world_3d().direct_space_state
	var de := jogador.global_position + Vector3(0.0, 0.5, 0.0)
	var q := PhysicsRayQueryParameters3D.create(de, de + Vector3(0.0, -2.0, 0.0), 1)
	q.exclude = [jogador.get_rid()]
	var hit := espaco.intersect_ray(q)
	var piso := float(hit["position"].y) if not hit.is_empty() else jogador.global_position.y
	_relatar(px + "_pedido_altura", snappedf(pedido.global_position.y - piso, 0.01))
	_relatar(px + "_tampo_altura", snappedf(KitBar.ALTURA_BALCAO + 0.05, 0.01))
	_relatar(px + "_pedido_ate_o_cliente", snappedf(Vector2(pedido.global_position.x
		- jogador.global_position.x, pedido.global_position.z - jogador.global_position.z)
		.length(), 0.01))
	if not fotos.is_empty():
		await arvore.create_timer(0.8).timeout
		await _foto(arvore, fotos + px + "_pedido.png")
	pedido.interagir(jogador)
	await arvore.create_timer(0.2).timeout
	_relatar(px + "_pegou", Inventario.quantidade(item) - antes)
	_relatar(px + "_pedido_sumiu", 1 if not is_instance_valid(pedido) else 0)


## Poe a camera do jogador a `dist` do alvo, pelo lado `de`, na altura de quem
## esta sentado, olhando para ele.
static func _enquadrar(jogador: Node3D, alvo: Vector3, de: Vector3, dist: float) -> void:
	var d := de
	d.y = 0.0
	d = d.normalized() if d.length() > 0.01 else Vector3.BACK
	jogador.global_position = Vector3(alvo.x, alvo.y, alvo.z) + d * dist
	if jogador.has_method("olhar_para"):
		jogador.call("olhar_para", alvo + Vector3(0.0, 0.55, 0.0))
	if jogador.has_method("zerar_velocidade"):
		jogador.call("zerar_velocidade")


static func _foto(arvore: SceneTree, caminho: String) -> void:
	await RenderingServer.frame_post_draw
	arvore.root.get_viewport().get_texture().get_image().save_png(caminho)
	print("[bar] foto ", caminho)


## Coordenada local do bar para mundo. x pela frente, z para dentro.
static func _p(boca: Vector3, b: Basis, x: float, y: float, z: float) -> Vector3:
	return boca + b * Vector3(x, y, -z)
