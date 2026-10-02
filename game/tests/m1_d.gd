## Missao 1, tarefa D: lugares, elenco e o telefone do Berg.
##
##   godot --headless --path game res://tests/m1_d.tscn
##
## Confere, sem abrir janela:
##   1. `Lugares.igreja()` bate na geometria: o chunk da capela montado com
##      colisao, raio de cima acha o plinto na porta e os degraus descendo ate
##      o pe; e a ancora medida a mao (cidade.gd) concorda com a planta.
##   2. A vaga do Berg: o chunk da calcada montado, raio nas quatro rodas — as
##      duas de dentro em cima do meio-fio, as duas de fora no asfalto.
##   3. O elenco: o id do Berg e um homem vivo de 40 a 50 anos, a ficha sai com
##      oculos escuro e apelido; Jota, Helmer e o dono nascem marcados e
##      `Elenco.no` acha os tres; com a dupla no porao, os dois nascem la.
##   4. A ligacao: papel pego, contato BERG na agenda, dois toques, as tres
##      falas fixas do roteiro na ordem, ele desliga e marca `m1_ligou_pro_berg`.
##
## Imprime `[m1_d] ok/FALHOU ...` e sai com 1 se algo falhou.
extends Node3D

var _falhas := 0


func _ready() -> void:
	await get_tree().process_frame
	await _igreja()
	await _vaga()
	await _elenco()
	await _ligacao()
	print("[m1_d] %s (%d falha(s))" % ["OK" if _falhas == 0 else "FALHOU", _falhas])
	get_tree().quit(1 if _falhas > 0 else 0)


func _conferir(cond: bool, o_que: String) -> void:
	if cond:
		print("[m1_d] ok      %s" % o_que)
	else:
		_falhas += 1
		print("[m1_d] FALHOU  %s" % o_que)


## O chunk montado com colisao, na posicao do mundo.
func _chunk(c: Vector2i) -> Node3D:
	var no := Node3D.new()
	no.position = Vector3(c.x * MalhaUrbana.TAM, 0.0, c.y * MalhaUrbana.TAM)
	add_child(no)
	var cm: Node = load("res://src/world/chunk_manager.gd").new()
	cm.montar_colisao(no, ChunkBuilder.construir(c.x, c.y), true, false)
	cm.free()
	return no


func _chao(x: float, z: float) -> float:
	var espaco := get_viewport().world_3d.direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 20.0, z), Vector3(x, -5.0, z))
	var achado := espaco.intersect_ray(q)
	return (achado["position"] as Vector3).y if not achado.is_empty() else -INF


func _no_chunk(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / MalhaUrbana.TAM), floori(p.z / MalhaUrbana.TAM))


func _igreja() -> void:
	var ig := Lugares.igreja()
	var centro: Vector3 = ig["centro"]
	var porta: Vector3 = ig["mundo"]
	var pe: Vector3 = ig["frente"]
	_conferir(Vector2(centro.x - Lugares.IGREJA_ANCORA.x, centro.z - Lugares.IGREJA_ANCORA.z)
		.length() < 0.6, "centro da capela da planta %s perto da ancora medida %s"
		% [centro, Lugares.IGREJA_ANCORA])
	var chunks := {}
	for p: Vector3 in [centro, porta, pe]:
		chunks[_no_chunk(p)] = true
	for c: Vector2i in chunks:
		_chunk(c)
	await get_tree().physics_frame
	await get_tree().physics_frame
	# Na soleira: o plinto, 55 cm acima do calcamento.
	var y_porta := _chao(porta.x, porta.z + 0.15)
	_conferir(absf(y_porta - porta.y) < 0.12, "raio no patamar da porta acha o topo da escadaria (%.2f, esperado %.2f)"
		% [y_porta, porta.y])
	# A escadaria desce da porta ate o pe: alturas nao crescentes e o fim no chao.
	var anterior := y_porta + 0.01
	var desce := true
	var perfil: Array[String] = []
	var z := porta.z + 0.15
	while z < centro.z + Lugares.PE_DA_ESCADA:
		var h := _chao(porta.x, z)
		desce = desce and h <= anterior + 0.02 and h > -INF
		anterior = h
		perfil.append("%.2f" % h)
		z += 0.2
	_conferir(desce and anterior < y_porta - 0.3, "a escadaria desce da porta ate o pe %s" % [perfil])
	var y_pe := _chao(pe.x, pe.z)
	_conferir(absf(y_pe - pe.y) < 0.15, "o pe da escada e chao da praca (%.2f, esperado %.2f)"
		% [y_pe, pe.y])
	_conferir((ig["area"] as Rect2).has_point(Vector2(pe.x, pe.z)), "o pe da escada esta na area do Berg")


func _vaga() -> void:
	var ig := Lugares.igreja()
	var vaga: Transform3D = ig["vaga"]
	var porta: Vector3 = ig["mundo"]
	_chunk(_no_chunk(vaga.origin))
	await get_tree().physics_frame
	await get_tree().physics_frame
	# Rodas a 70 cm do eixo e 1,3 m para frente e para tras (pegada do Marea).
	var altas := 0
	var baixas := 0
	var asfalto := INF
	var meio_fio := -INF
	for lado: float in [-0.7, 0.7]:
		for eixo: float in [-1.3, 1.3]:
			var r := vaga * Vector3(lado, 0.0, eixo)
			var h := _chao(r.x, r.z)
			asfalto = minf(asfalto, h)
			meio_fio = maxf(meio_fio, h)
	for lado: float in [-0.7, 0.7]:
		for eixo: float in [-1.3, 1.3]:
			var r := vaga * Vector3(lado, 0.0, eixo)
			var h := _chao(r.x, r.z)
			if h > asfalto + KitModular.ALTURA_MEIO_FIO * 0.6:
				altas += 1
			else:
				baixas += 1
	_conferir(altas == 2 and baixas == 2, "vaga com duas rodas no meio-fio (%d em cima, %d no asfalto, desnivel %.2f)"
		% [altas, baixas, meio_fio - asfalto])
	var frente := -vaga.basis.z
	var para_porta := (porta - vaga.origin) * Vector3(1, 0, 1)
	_conferir(frente.dot(para_porta.normalized()) > 0.1, "bico do carro virado para a capela")
	_conferir(para_porta.length() < 60.0, "vaga a %.0f m da porta" % para_porta.length())


func _elenco() -> void:
	var id_berg := Elenco.id(Elenco.BERG)
	var f := RegistroCivil.identidade(id_berg)
	_conferir(not f.is_empty() and int(f["idade"]) >= 40 and int(f["idade"]) <= 50
		and String(f["sexo"]) == "M" and RegistroCivil.esta_vivo(id_berg),
		"id do Berg %d e homem vivo de 40-50 (%s, %s)" % [id_berg, f.get("sexo", "?"), f.get("idade", "?")])
	var fb := Elenco.ficha(Elenco.BERG)
	var a: Dictionary = fb.get("aparencia", {})
	_conferir(int(a.get("oculos", 0)) == Aparencia.OCULOS_ESCURO and int(a.get("rosto", -1))
		== Aparencia.ELENCO_ROSTO_BERG and String(fb.get("apelido", "")) == "BERG",
		"ficha do Berg com oculos escuro, cara do elenco e apelido")
	_conferir(String(RegistroCivil.identidade(id_berg).get("apelido", "")) == "BERG",
		"o registro civil devolve o Berg pelo id")

	# A casa: dono, Jota e Helmer nascendo como a planta os descreve.
	Elenco.dupla_no_porao = true
	var estufa := Node3D.new()
	estufa.name = "Estufa"
	estufa.transform = Transform3D(Basis(Vector3.UP, 0.7), Vector3(500.0, -3.4, 500.0))
	add_child(estufa)
	for quem: StringName in [Elenco.JOTA, Elenco.HELMER]:
		var no := Interiores.criar_prop({
			"tipo": "fazendeiro", "vaga": 0 if quem == Elenco.JOTA else 1, "personagem": quem,
			"pos": EstufaBuilder.ENTRADA, "semente": 9911 + (0 if quem == Elenco.JOTA else 97),
			"pontos": [EstufaBuilder.ENTRADA] as Array[Vector3], "foco": Vector3(6.0, 0.0, 17.0),
		})
		if no != null:
			estufa.add_child(no)
	var sala := Node3D.new()
	sala.position = Vector3(500.0, 0.0, 500.0)
	add_child(sala)
	var dono := Interiores.criar_prop({"tipo": "convidado", "dono": true, "pos": Vector3(1.0, 0.0, 1.0),
		"semente": 4321, "pontos": [Vector3(1.0, 0.0, 1.0)] as Array[Vector3]})
	if dono != null:
		sala.add_child(dono)
	await get_tree().process_frame
	for quem: StringName in [Elenco.DONO, Elenco.JOTA, Elenco.HELMER]:
		_conferir(Elenco.no(get_tree(), quem) != null, "Elenco.no acha %s" % quem)
	for quem: StringName in [Elenco.JOTA, Elenco.HELMER]:
		var no := Elenco.no(get_tree(), quem)
		if no == null:
			continue
		var lugar := Elenco.lugar_no_porao(quem)
		var esperado := estufa.to_global(lugar["pos"])
		_conferir(no.global_position.distance_to(esperado) < 0.3,
			"%s nasce no porao (%.2f m do lugar)" % [quem, no.global_position.distance_to(esperado)])
	Elenco.levar_dupla_ao_porao(get_tree(), false)
	estufa.queue_free()
	sala.queue_free()


func _ligacao() -> void:
	var contatos := AppContatos.new()
	var id_berg := Elenco.id(Elenco.BERG)
	contatos.abrir()
	_conferir(not RegistroCivil.ja_conhece(id_berg), "sem o papel o Berg nao e contato")
	Borboleta.marcar(&"m1_pegou_numero_berg", true, false)
	contatos.abrir()
	_conferir(RegistroCivil.ja_conhece(id_berg) and contatos._lista.has(id_berg), "papel pego: BERG na agenda")
	_conferir(AppContatos._rotulo(RegistroCivil.identidade(id_berg)) == "BERG", "a agenda mostra BERG")

	var tel := AppTelefone.new()
	tel.ligar(id_berg)
	_conferir(tel._numero == Elenco.TELEFONE_BERG, "o numero e o do papel (%s)" % tel._numero)
	var falas: Array[String] = []
	var t := 0.0
	var atendeu_em := -1.0
	while t < 40.0 and tel._estado != AppTelefone.Estado.NADA:
		tel.processar(0.05)
		t += 0.05
		if tel._estado == AppTelefone.Estado.FALANDO and atendeu_em < 0.0:
			atendeu_em = t
		if not tel._fala.is_empty() and (falas.is_empty() or falas[-1] != tel._fala):
			falas.append(tel._fala)
	var esperadas: Array[String] = []
	for linha: Array in AppTelefone.FALAS_BERG:
		esperadas.append(String(linha[0]))
	_conferir(falas == esperadas, "as tres falas do roteiro, na ordem: %s" % [falas])
	_conferir(atendeu_em > 3.0 and atendeu_em < 4.5, "atende depois de dois toques (%.1f s)" % atendeu_em)
	_conferir(bool(Borboleta.valor(&"m1_ligou_pro_berg", false)), "ele desliga e marca m1_ligou_pro_berg")
	Borboleta.limpar()
