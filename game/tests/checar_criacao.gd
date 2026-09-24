## O caminho dos dados da criacao de personagem, sem abrir a tela.
##
##     godot --headless --path game --script res://tests/checar_criacao.gd
##
## A tela ganhou modelos de peca, barba, oculos, calcado, ombros e oito rostos
## novos. Cada um e uma chave a mais que tem de atravessar quatro portas sem se
## perder: ajuste -> aparencia montada -> save em JSON -> rede. Um elo que perde
## a chave nao da erro: o jogador escolhe o sobretudo, salva, carrega e esta de
## camiseta.
##
## E o que nao pode mudar: a rua. Modelo zero e a pessoa de antes, entao um
## pedestre sorteado tem de sair com os mesmos triangulos que o corpo sem
## nenhuma chave nova.
extends SceneTree

## Personagem de perto (jogador, retrato), com o conjunto mais pesado.
##
## Era 900 (psx-assets, personagem principal) com o corpo de caixas. O corpo de
## tubos com dedos custa 836 so de base, e o pedido foi explicito: o corpo do
## protagonista em AAA, sem forcar PSX. E uma pessoa na tela; a rua, que e onde
## o numero pesa, tem teto proprio abaixo.
const TETO_TRIANGULOS := 1500
## Pedestre sorteado (nivel de rua, modelos zero): 456 de corpo, e o cabelo
## comprido, o chapeu e a saia por cima. Quatorze na rua de uma vez
## (Multidao.POPULACAO_BASE) ficam abaixo de 8 mil, um terco do que o ART-BIBLE
## deixa visivel na nevoa.
const TETO_PEDESTRE := 560

var _passou := 0
var _total := 0


func _init() -> void:
	_rodar()


## Quantos vertices do braco (e da mao) ficam dentro do tronco, de pe.
##
## Pele feita a mao: posicao = soma dos pesos x (pose global x inversa do
## repouso). O tronco e a superelipse do perfil encolhida em um centimetro —
## braco de gordo encosta, o que nao pode e entrar.
func _braco_dentro_do_tronco(sexo: StringName, g: float, perto: bool,
		braco_reto: bool = false) -> int:
	var base := Aparencia.de_ficha({"id": 31, "sexo": sexo, "idade": 40})
	var aj := Aparencia.ajustes_de(base)
	aj[&"gordura"] = g
	aj[&"casaco_estilo"] = 0
	var a := Aparencia.com_ajustes(base, aj)
	var c := Corpo.new()
	c.detalhado = perto
	root.add_child(c)
	c.montar(a)
	if braco_reto:
		c.set("_abducao", 0.0)
		c.set("_assinatura", -1)
	c.animar(0.0, 0.016)
	var sk := c.esqueleto()
	var malha := sk.get_node("Pele") as MeshInstance3D
	var arr := malha.mesh.surface_get_arrays(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var os: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var ps: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var mat: Array[Transform3D] = []
	for i in sk.get_bone_count():
		mat.append(sk.get_bone_global_pose(i) * sk.get_bone_global_rest(i).affine_inverse())
	var bracos := [Corpo.Osso.BRACO_E, Corpo.Osso.BRACO_D, Corpo.Osso.ANTEBRACO_E,
		Corpo.Osso.ANTEBRACO_D]
	var escala := c.altura() / Corpo.ALTURA_REF
	var perfil := c.perfil()
	var dentro := 0
	for k in vs.size():
		if not (os[k * 4] in bracos) or ps[k * 4] < 0.99:
			continue
		var p := Vector3.ZERO
		for j in 4:
			var w := ps[k * 4 + j]
			if w > 0.0:
				p += (mat[os[k * 4 + j]] * vs[k]) * w
		var y := p.y / escala
		if y < 0.98 or y > 1.16:
			continue
		var m := Anatomia.medida(perfil, y) - Vector3.ONE * 0.01
		var fundo := m.y if p.z < 0.0 else m.z
		var e := Anatomia.FORMA_TRONCO
		if pow(absf(p.x) / m.x, e) + pow(absf(p.z) / fundo, e) < 1.0:
			dentro += 1
	c.queue_free()
	return dentro


## Anda tres segundos em linha reta e para, lendo as molas a cada quadro.
func _andar_e_parar(a: Dictionary) -> Dictionary:
	var c := Corpo.new()
	c.detalhado = true
	root.add_child(c)
	c.montar(a)
	var dt := 1.0 / 60.0
	var sobe := 0
	var coxa_a_frente := 0
	var maior_barriga := 0.0
	for i in 180:
		c.position.z -= 1.4 * dt
		c.animar(1.4, dt)
		var sk := c.esqueleto()
		var coxa := maxf(sk.get_bone_pose_rotation(Corpo.Osso.COXA_E).get_euler().x,
			sk.get_bone_pose_rotation(Corpo.Osso.COXA_D).get_euler().x)
		var f := c.estado_da_fisica()
		maior_barriga = maxf(maior_barriga, absf(f.z) + absf(f.w))
		if i > 30 and coxa > 0.2:
			coxa_a_frente += 1
			if f.x > 0.15:
				sobe += 1
	var mexeu_parado := 0.0
	for i in 120:
		c.animar(0.0, dt)
		if i < 30:
			mexeu_parado = maxf(mexeu_parado, absf(c.estado_da_fisica().x))
	var fim := c.estado_da_fisica()
	c.queue_free()
	return {"sobe": sobe, "coxa": coxa_a_frente, "barriga": maior_barriga,
		"fim": fim, "mexeu_parado": mexeu_parado}


## A saia tem de sair da frente da coxa que avanca, e assentar quando a pessoa
## para; a barriga do gordo sacode andando, a do magro nao.
func _medir_fisica() -> void:
	var base := Aparencia.de_ficha({"id": 44, "sexo": &"F", "idade": 30})
	var aj := Aparencia.ajustes_de(base)
	aj[&"calca_estilo"] = Aparencia.CALCA_SAIA
	aj[&"gordura"] = 0.2
	var saia := _andar_e_parar(Aparencia.com_ajustes(base, aj))
	var fracao := float(saia["sobe"]) / float(maxi(1, int(saia["coxa"])))
	_conta("saia_sai_da_frente_da_coxa", fracao > 0.8,
		"frente da saia levantada em %d de %d quadros de coxa a frente" % [saia["sobe"],
			saia["coxa"]])
	var fim: Vector4 = saia["fim"]
	_conta("saia_assenta_ao_parar", absf(fim.x) < 0.02 and absf(fim.y) < 0.02,
		"frente %.3f costas %.3f rad dois segundos depois" % [fim.x, fim.y])
	var gordo := Aparencia.ajustes_de(base)
	gordo[&"gordura"] = 1.0
	gordo[&"calca_estilo"] = 0
	var g := _andar_e_parar(Aparencia.com_ajustes(base, gordo))
	var magro := Aparencia.ajustes_de(base)
	magro[&"gordura"] = 0.0
	magro[&"calca_estilo"] = 0
	var m := _andar_e_parar(Aparencia.com_ajustes(base, magro))
	_conta("barriga_do_gordo_sacode", float(g["barriga"]) > 0.003
		and float(m["barriga"]) == 0.0,
		"gordo %.1f mm, magro %.1f mm" % [float(g["barriga"]) * 1000.0,
			float(m["barriga"]) * 1000.0])


func _conta(nome: String, ok: bool, texto: String = "") -> void:
	_total += 1
	if ok:
		_passou += 1
	print("[%s] %s  %s" % ["OK" if ok else "XX", nome, texto])


func _rodar() -> void:
	await process_frame
	print("\n=== criacao: dados ===\n")
	# Autoload por caminho: um script de SceneTree e compilado antes de os
	# autoloads existirem, e o nome deles nao resolve.
	var reg: Node = root.get_node("/root/RegistroCivil")
	reg.criar_jogador("TESTE DA SILVA")

	# --- ida e volta pelo save, com tudo o que e novo ---------------------------
	var ajustes := Aparencia.ajustes_de(reg.jogador["aparencia"])
	var escolhas := {
		&"rosto": 12, &"barba": 4, &"oculos": 2, &"camisa_estilo": 4,
		&"casaco_estilo": 3, &"calca_estilo": 1, &"sapato_estilo": 2,
		&"sapato_cor": Aparencia.SAPATOS_EXTRA[0], &"chapeu_tipo": 5,
		&"chapeu_cor": Aparencia.ROUPAS[9], &"ombro": 0.47,
		&"penteado": Aparencia.PENTEADO_COQUE,
	}
	for k: StringName in escolhas:
		ajustes[k] = escolhas[k]
	reg.ajustar_jogador(ajustes)
	var montada: Dictionary = reg.jogador["aparencia"]
	_conta("rosto_de_estudio_na_linha_certa",
		int(montada["linha_rosto"]) in [Aparencia.LINHA_ESTUDIO_M,
			Aparencia.LINHA_ESTUDIO_F] and int(montada["rosto"]) == 4,
		"linha %d coluna %d" % [int(montada["linha_rosto"]), int(montada["rosto"])])
	_conta("agasalho_ligado_pelo_modelo", bool(montada["casaco"])
		and int(montada["casaco_tipo"]) == Aparencia.CASACO_SOBRETUDO)
	_conta("chapeu_ligado_pelo_modelo", bool(montada["chapeu"]))

	var salvo: Dictionary = JSON.parse_string(JSON.stringify(reg.para_dicionario()))
	reg.esquecer_cache()
	reg.de_dicionario(salvo)
	var volta := Aparencia.ajustes_de(reg.jogador["aparencia"])
	var perdidos: PackedStringArray = []
	for k: StringName in escolhas:
		var a: Variant = escolhas[k]
		var b: Variant = volta.get(k)
		var igual := false
		if typeof(a) == TYPE_COLOR:
			igual = typeof(b) == TYPE_COLOR and (a as Color).is_equal_approx(b)
		elif typeof(a) == TYPE_FLOAT:
			igual = absf(float(a) - float(b)) < 0.001
		else:
			igual = int(a) == int(b)
		if not igual:
			perdidos.append("%s (%s -> %s)" % [k, a, b])
	_conta("tudo_sobrevive_ao_save_json", perdidos.is_empty(), ", ".join(perdidos))

	# --- save antigo: casaco_usa e rosto da cidade -------------------------------
	var velho := {&"casaco_usa": 1, &"camisa": 3, &"rosto": 2}
	var traduzido := Aparencia.ajustes_de(Aparencia.com_ajustes(
		Aparencia.de_ficha(reg.jogador), velho))
	_conta("save_antigo_vira_jaqueta",
		int(traduzido[&"casaco_estilo"]) == Aparencia.CASACO_JAQUETA,
		"casaco_estilo %d" % int(traduzido[&"casaco_estilo"]))
	_conta("save_antigo_mantem_rosto", int(traduzido[&"rosto"]) == 2)

	# --- rede: a aparencia nova atravessa a sanitizacao ---------------------------
	var saneada := ProtocoloRede.sanear_aparencia(montada)
	var cortados: PackedStringArray = []
	for k: String in ["camisa_estilo", "casaco_tipo", "calca_estilo", "sapato_estilo",
			"oculos", "barba", "linha_rosto", "chapeu_tipo"]:
		if str(saneada.get(k)) != str(montada.get(k)):
			cortados.append("%s (%s -> %s)" % [k, montada.get(k), saneada.get(k)])
	_conta("rede_leva_os_modelos", cortados.is_empty(), ", ".join(cortados))

	# --- a rua nao muda -------------------------------------------------------------
	var diferentes := 0
	for id in range(100, 160):
		var base := Aparencia.de_ficha({"id": id, "sexo": &"M" if id % 2 else &"F",
			"idade": 20 + id % 50})
		var sem := base.duplicate(true)
		for k: String in ["camisa_estilo", "casaco_tipo", "calca_estilo",
				"sapato_estilo", "oculos", "barba"]:
			sem.erase(k)
		var c1 := Corpo.new()
		c1.montar(base)
		var c2 := Corpo.new()
		c2.montar(sem)
		if c1.triangulos() != c2.triangulos():
			diferentes += 1
		c1.free()
		c2.free()
	_conta("pedestre_nao_ganha_triangulo", diferentes == 0,
		"%d de 60 diferentes" % diferentes)

	# --- orcamento: o conjunto mais pesado --------------------------------------
	var pior := 0
	var pior_nome := ""
	var base_j := Aparencia.de_ficha({"id": 7, "sexo": &"M", "idade": 31})
	for camisa in Aparencia.CAMISA_ESTILOS.size():
		for casaco in Aparencia.CASACO_ESTILOS.size():
			for calca in Aparencia.CALCA_ESTILOS.size():
				var aj := Aparencia.ajustes_de(base_j)
				aj[&"camisa_estilo"] = camisa
				aj[&"casaco_estilo"] = casaco
				aj[&"calca_estilo"] = calca
				aj[&"sapato_estilo"] = Aparencia.SAPATO_CANO_ALTO
				aj[&"oculos"] = Aparencia.OCULOS_GRAU
				aj[&"barba"] = Aparencia.BARBA_ESPESSA
				aj[&"chapeu_tipo"] = 5
				aj[&"gordura"] = 1.0
				var c := Corpo.new()
				c.detalhado = true
				c.montar(Aparencia.com_ajustes(base_j, aj))
				if c.triangulos() > pior:
					pior = c.triangulos()
					pior_nome = "%s + %s + %s" % [Aparencia.CAMISA_ESTILOS[camisa],
						Aparencia.CASACO_ESTILOS[casaco], Aparencia.CALCA_ESTILOS[calca]]
				c.free()
	_conta("pior_conjunto_no_orcamento", pior <= TETO_TRIANGULOS,
		"%d triangulos (%s), teto %d" % [pior, pior_nome, TETO_TRIANGULOS])

	# --- pedestre: o nivel de rua ---------------------------------------------------
	var pior_rua := 0
	for id in range(200, 260):
		var base_r := Aparencia.de_ficha({"id": id, "sexo": &"M" if id % 2 else &"F",
			"idade": 20 + id % 50})
		var cr := Corpo.new()
		cr.montar(base_r)
		pior_rua = maxi(pior_rua, cr.triangulos())
		cr.free()
	_conta("pedestre_no_orcamento", pior_rua <= TETO_PEDESTRE,
		"pior de 60: %d triangulos, teto %d" % [pior_rua, TETO_PEDESTRE])

	# --- braco por fora da barriga -------------------------------------------------
	# A queixa que abriu este trabalho: no gordo o braco atravessava a gordura.
	# Mede na malha JA deformada pela pose de pe, vertice por vertice: nenhum
	# vertice do braco pode estar dentro da secao do tronco na faixa da barriga.
	var furos: PackedStringArray = []
	for sexo: StringName in [&"M", &"F"]:
		for g: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
			for perto: bool in [false, true]:
				var dentro := _braco_dentro_do_tronco(sexo, g, perto)
				if dentro > 0:
					furos.append("%s g%.2f %s: %d" % [sexo, g, "perto" if perto else "rua",
						dentro])
	_conta("braco_por_fora_da_barriga", furos.is_empty(), ", ".join(furos))
	# Controle positivo: o mesmo gordo com o braco pendurado reto tem de furar.
	# Sem isto, uma regua que nunca acha nada passaria igual.
	var controle := _braco_dentro_do_tronco(&"M", 1.0, true, true)
	_conta("regua_do_braco_ve_o_furo", controle > 0,
		"%d vertices dentro com o braco reto" % controle)

	# --- fisica de pano e de carne ---------------------------------------------------
	await _medir_fisica()

	# --- piscar: so no retrato ---------------------------------------------------
	var base_p := Aparencia.de_ficha({"id": 7, "sexo": &"M", "idade": 31})
	var npc := Corpo.new()
	npc.montar(base_p)
	var tem_npc := npc.find_child("Palpebra", true, false) != null
	var tris_npc := npc.triangulos()
	npc.free()
	_conta("pedestre_nao_pisca", not tem_npc, "sem malha de palpebra na rua")
	var retrato := Corpo.new()
	retrato.piscar = true
	root.add_child(retrato)
	retrato.montar(base_p)
	var palpebra := retrato.find_child("Palpebra", true, false) as MeshInstance3D
	var fechados := 0
	var passos := 0
	var t := 0.0
	while t < 10.0 and palpebra != null:
		retrato.animar(0.0, 1.0 / 60.0)
		t += 1.0 / 60.0
		passos += 1
		if palpebra.visible:
			fechados += 1
	# Dois a cinco segundos entre piscadas, um decimo cada: em dez segundos,
	# de duas a seis piscadas, e o olho aberto quase o tempo todo.
	var fracao := float(fechados) / float(maxi(1, passos))
	_conta("retrato_pisca", palpebra != null and fechados > 0 and fracao < 0.10,
		"%d quadros fechados em %d (%.1f%%)" % [fechados, passos, fracao * 100.0])
	_conta("piscar_nao_mexe_no_corpo", retrato.triangulos() >= tris_npc)
	retrato.queue_free()

	# --- reacao por campo ---------------------------------------------------------
	var sem_reacao: PackedStringArray = []
	for campo: Dictionary in Aparencia.AJUSTES:
		if ReacaoCorpo.do_campo(campo["chave"]) == ReacaoCorpo.NENHUMA:
			sem_reacao.append(String(campo["chave"]))
	_conta("todo_campo_tem_reacao", sem_reacao.is_empty(), ", ".join(sem_reacao))

	# --- toda aba cabe em campos que existem ----------------------------------------
	var orfaos: PackedStringArray = []
	for aba: Dictionary in CarteiraLayout.ABAS:
		for chave: StringName in aba["campos"]:
			var achou := false
			for campo: Dictionary in Aparencia.AJUSTES:
				if StringName(campo["chave"]) == chave:
					achou = true
			if not achou:
				orfaos.append(String(chave))
	_conta("abas_so_com_campos_que_existem", orfaos.is_empty(), ", ".join(orfaos))

	print("\n%d de %d criterios" % [_passou, _total])
	quit(0 if _passou == _total else 1)
