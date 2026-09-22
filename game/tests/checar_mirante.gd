## O mirante: onde ele nasce, o terraco que ele ganha e o ar que se abre.
##
##     godot --headless --path game --script res://tests/checar_mirante.gd -- --fog=leve
##
## O que ele prova
## ---------------
##   onde       ha mirante e terraco no raio, e a Praca da Matriz nao e um
##   terraco    dentro do parque, fora dos caminhos e do portao, com lugar para o
##              cruzeiro, a luneta e a escada; o mesmo visto de qualquer chunk
##   chunk      uma luneta e uma placa por terraco; a rampa da escada vai do piso
##              do bastiao ao chao do parque (o CharacterBody3D sobe); orcamento
##              de triangulos do chunk
##   ar         num FogController de verdade, o Mirante abre a nevoa ate o preset
##              derivado, larga quando outro forca a nevoa, volta quando ela e
##              devolvida e fecha na saida, sem deixar preset forcado para tras
##   luneta     com um jogador de mentira (a interface do Player): pegar prende,
##              fecha a lente e corta a cabeca da luneta da camera; a roda
##              aproxima; a mira fica no arco; Esc devolve corpo, lente e camera
##
## `--fog=leve` escolhe o clima sem gravar no settings.cfg (Settings). Sai com 1
## se algum criterio falhar.
extends SceneTree

const RAIO := 40
const MIRANTES_MIN := 8
const TERRACOS_MIN := 5
const TETO_TRIANGULOS := 6000
## Folga da rampa de colisao contra o piso do bastiao e contra o chao, em metros.
const FOLGA_RAMPA := 0.05

var _falhas: PackedStringArray = []
var _total := 0
var MB: GDScript
var PB: GDScript
var CB: GDScript


func _initialize() -> void:
	_rodar.call_deferred()


func _afirmar(msg: String, cond: bool) -> void:
	_total += 1
	if not cond:
		_falhas.append(msg)


func _rodar() -> void:
	# Por carga tardia: citados pelo nome, eles puxam a cadeia de autoload para a
	# compilacao deste script, antes de o autoload existir (ver Relevo).
	MB = load("res://src/world/mirante_builder.gd")
	PB = load("res://src/world/parque_builder.gd")
	CB = load("res://src/world/chunk_builder.gd")

	var praca := MalhaUrbana.quadra_de(Relevo.CHUNK_PRACA.x, Relevo.CHUNK_PRACA.y)
	_afirmar("a Praca da Matriz nao e mirante", not bool(MB.e_mirante(praca)))

	var vistos := {}
	var mirantes := 0
	var terracos: Array[Dictionary] = []
	for cz in range(-RAIO, RAIO + 1):
		for cx in range(-RAIO, RAIO + 1):
			var q := MalhaUrbana.quadra_de(cx, cz)
			if vistos.has(q["id"]):
				continue
			vistos[q["id"]] = true
			if not bool(MB.e_mirante(q)):
				continue
			mirantes += 1
			var plano: Dictionary = PB.planta(q)
			if not (plano["terraco"] as Dictionary).is_empty():
				terracos.append({"quadra": q, "plano": plano})
	print("-- %d mirantes, %d com terraco em %dx%d chunks" % [mirantes, terracos.size(),
		RAIO * 2 + 1, RAIO * 2 + 1])
	_afirmar("ha mirante no raio (%d >= %d)" % [mirantes, MIRANTES_MIN], mirantes >= MIRANTES_MIN)
	_afirmar("ha terraco no raio (%d >= %d)" % [terracos.size(), TERRACOS_MIN],
		terracos.size() >= TERRACOS_MIN)

	for m: Dictionary in terracos:
		_conferir_terraco(m["quadra"], m["plano"])
	if not terracos.is_empty():
		await _conferir_ar(terracos[0]["quadra"], terracos[0]["plano"])
	await _conferir_luneta()

	print("")
	if _falhas.is_empty():
		print("OK — %d assercoes" % _total)
		quit(0)
		return
	print("FALHOU — %d de %d assercoes" % [_falhas.size(), _total])
	for f: String in _falhas:
		print("  x %s" % f)
	quit(1)


func _conferir_terraco(q: Dictionary, plano: Dictionary) -> void:
	var t: Dictionary = plano["terraco"]
	var id := str(q["id"])
	var area: Rect2 = plano["area"]
	var r: Rect2 = t["rect"]
	_afirmar("%s: terraco dentro do parque" % id, area.grow(0.01).encloses(r))
	for faixa: Rect2 in PB.faixas_de_caminho(plano):
		if faixa.size.x > 0.0 and faixa.size.y > 0.0:
			_afirmar("%s: terraco fora do caminho %s" % [id, faixa], not r.intersects(faixa))
	var L := ((t["longe"] as Vector2) - (t["ponta"] as Vector2)).length()
	var degraus := ceili(MB.ALTURA / MB.ESPELHO)
	var s_topo: float = L - MB.PATAMAR_BAIXO - float(degraus) * MB.PISADA
	_afirmar("%s: bastiao com lugar para cruzeiro e luneta (%.1f m)" % [id, s_topo],
		s_topo >= 6.0)

	# O mesmo terraco, perguntado de novo depois de esvaziar o cache: nao depende
	# de quem perguntou primeiro.
	var cache: Dictionary = MB._terracos
	cache.clear()
	var de_novo: Dictionary = MB.terraco(q, plano)
	_afirmar("%s: terraco deterministico" % id,
		de_novo.get("ponta") == t["ponta"] and de_novo.get("longe") == t["longe"])

	# Os chunks do terraco: props, rampa e orcamento.
	var o := Vector2(float(int(q["x0"])), float(int(q["z0"]))) * MalhaUrbana.TAM
	var mundo := Rect2(r.position + o, r.size)
	var nivel := Relevo.no(int(q["x0"]), int(q["z0"]))
	var lunetas := 0
	var placas := 0
	var rampas := 0
	var rampa_boa := false
	for cz in range(floori(mundo.position.y / 32.0), floori(mundo.end.y / 32.0) + 1):
		for cx in range(floori(mundo.position.x / 32.0), floori(mundo.end.x / 32.0) + 1):
			var d: Dictionary = CB.construir(cx, cz)
			var tris := int(d["triangulos"])
			_afirmar("%s: chunk (%d,%d) com %d triangulos (teto %d)" % [id, cx, cz, tris,
				TETO_TRIANGULOS], tris <= TETO_TRIANGULOS)
			for p: Dictionary in d["props"]:
				if p.get("tipo", "") == "luneta":
					lunetas += 1
				elif p.get("tipo", "") == "placa_rua" and str(p.get("texto", "")).begins_with(MB.nome(q)):
					placas += 1
			for c: Dictionary in d["colisao"]:
				if not c.has("giro") or absf((c["giro"] as Vector3).x) < 0.2:
					continue
				# A rampa da escada, e nao a do meio-fio (que tambem e caixa inclinada
				# de 30 cm): a da escada tem a largura dela e passa de tres metros.
				var tam: Vector3 = c["tamanho"]
				if tam.y > 0.35 or tam.z < 3.0 \
						or absf(tam.x - (MB.FUNDO - 2.0 * MB.MURO)) > 0.01:
					continue
				rampas += 1
				# O topo da caixa inclinada, nas duas pontas do comprimento.
				var base := Basis.from_euler(c["giro"])
				var topo_meio: Vector3 = (c["pos"] as Vector3) + base.y * (tam.y * 0.5)
				var y1 := (topo_meio + base.z * (tam.z * 0.5)).y - nivel
				var y2 := (topo_meio - base.z * (tam.z * 0.5)).y - nivel
				var alto := maxf(y1, y2)
				var baixo := minf(y1, y2)
				rampa_boa = rampa_boa or (absf(alto - (MB.BASE + MB.ALTURA)) < FOLGA_RAMPA
					and absf(baixo - MB.BASE) < FOLGA_RAMPA)
	_afirmar("%s: uma luneta (%d)" % [id, lunetas], lunetas == 1)
	_afirmar("%s: uma placa com o nome (%d)" % [id, placas], placas == 1)
	_afirmar("%s: a escada tem uma rampa de colisao (%d)" % [id, rampas], rampas == 1)
	_afirmar("%s: a rampa vai do piso do bastiao ao chao" % id, rampa_boa)


## A nevoa num FogController de verdade, com o Mirante e um jogador de mentira.
func _conferir_ar(q: Dictionary, plano: Dictionary) -> void:
	# O autoload pela arvore: citado pelo nome, ele nao existe ainda quando este
	# script compila.
	var ajustes: Node = root.get_node("Settings")
	var base: FogPreset = ajustes.call("fog_preset")
	_afirmar("o clima do teste tem nevoa (rode com --fog=leve)", base != null and base.fog_enabled)
	if base == null or not base.fog_enabled:
		return
	var FC: GDScript = load("res://src/world/fog_controller.gd")
	var MI: GDScript = load("res://src/world/mirante.gd")
	var fog: WorldEnvironment = FC.new()
	root.add_child(fog)
	var jogador := Node3D.new()
	jogador.add_to_group(&"player")
	root.add_child(jogador)
	var t: Dictionary = plano["terraco"]
	var o := Vector2(float(int(q["x0"])), float(int(q["z0"]))) * MalhaUrbana.TAM
	var dentro: Vector2 = o + (t["rect"] as Rect2).get_center()
	jogador.global_position = Vector3(dentro.x, Relevo.altura(dentro.x, dentro.y), dentro.y)
	var mirante: Node = MI.new()
	root.add_child(mirante)
	var env: Environment = fog.environment
	var fim_base := env.fog_depth_end
	var esperado: float = MI._abrir(base).fog_end

	await create_timer(MI.ABRIR + MI.PERIODO * 2.0 + 0.3).timeout
	_afirmar("no mirante a nevoa abre (%.0f -> %.0f m, esperado %.0f)" % [fim_base,
		env.fog_depth_end, esperado], absf(env.fog_depth_end - esperado) < 0.5)
	_afirmar("o streaming acompanha (raio %.0f m)" % float(fog.get("stream_radius")),
		float(fog.get("stream_radius")) >= esperado)

	# Outro forca a nevoa (o interior): o mirante larga e nao devolve nada.
	fog.call("forcar", "res://resources/fog/fog_interior.tres")
	await create_timer(MI.PERIODO * 2.0 + 0.1).timeout
	_afirmar("com a nevoa forcada por outro, o mirante nao mexe",
		fog.call("preset_ativo") == &"interior" or not env.fog_enabled)
	fog.call("liberar")
	await create_timer(MI.ABRIR + MI.PERIODO * 2.0 + 0.3).timeout
	_afirmar("devolvida a nevoa, o mirante abre de novo (%.0f m)" % env.fog_depth_end,
		absf(env.fog_depth_end - esperado) < 0.5)

	# Saindo: fecha devagar e devolve o clima do jogador.
	jogador.global_position += Vector3(600.0, 0.0, 0.0)
	await create_timer(MI.PERIODO * 2.0 + 0.2).timeout
	var no_meio := env.fog_depth_end
	await create_timer(MI.FECHAR + 0.3).timeout
	_afirmar("fechando, a nevoa passa pelo meio (%.0f m)" % no_meio,
		no_meio < esperado - 0.5 and no_meio > fim_base + 0.5)
	_afirmar("fora do mirante a nevoa volta (%.0f m)" % env.fog_depth_end,
		absf(env.fog_depth_end - fim_base) < 0.5)
	_afirmar("fora do mirante nao sobra preset forcado",
		fog.call("preset_atual") == ajustes.call("fog_preset"))
	# O FogController fica ate o fim: a LenteDaCamera guarda o do grupo e testa
	# `is` nele a cada quadro, e liberado no meio ela acusa instancia morta.
	mirante.queue_free()
	jogador.queue_free()


## O jogador de mentira da luneta: a mesma interface do Player que ela usa.
const JOGADOR_FALSO := """
extends Node3D
var travado := false
var olho := -1.0
var fov := -1.0
var pitch := 0.0
var ocupado := ""
var cam: Camera3D
func _ready() -> void:
	cam = Camera3D.new()
	cam.near = 0.05
	add_child(cam)
func travar(p: bool) -> void: travado = p
func definir_olho(v: float) -> void: olho = v
func liberar_olho() -> void: olho = -1.0
func definir_fov(v: float) -> void: fov = v
func liberar_fov() -> void: fov = -1.0
func definir_pitch(v: float) -> void: pitch = v
func pitch_atual() -> float: return pitch
func camera() -> Camera3D: return cam
func ocupar(r: String, _c: Callable) -> void: ocupado = r
func desocupar() -> void: ocupado = ""
func dirigindo() -> bool: return false
"""


func _conferir_luneta() -> void:
	var codigo := GDScript.new()
	codigo.source_code = JOGADOR_FALSO
	codigo.reload()
	var j: Node3D = codigo.new()
	root.add_child(j)
	var antes := Transform3D(Basis(Vector3.UP, 0.7), Vector3(3.0, 10.0, -4.0))
	j.global_transform = antes
	var LU: GDScript = load("res://src/world/luneta.gd")
	var luneta: Node3D = LU.new()
	luneta.set("giro", PI * 0.5)
	root.add_child(luneta)
	luneta.global_position = Vector3(0.0, 10.0, 0.0)
	await process_frame

	luneta.call("interagir", j)
	_afirmar("pegar a luneta prende o jogador", bool(j.get("travado")))
	_afirmar("a lente fecha (fov %.0f)" % float(j.get("fov")),
		absf(float(j.get("fov")) - LU.ZOOM_INICIAL) < 0.01)
	_afirmar("a camera corta a cabeca da luneta (near %.2f)" % (j.get("cam") as Camera3D).near,
		absf((j.get("cam") as Camera3D).near - LU.CORTE_PERTO) < 0.01)
	var atras: Vector3 = Vector3(sin(PI * 0.5), 0.0, cos(PI * 0.5)) * -float(LU.ATRAS)
	_afirmar("o corpo fica atras da ocular",
		j.global_position.distance_to(Vector3(atras.x, 10.0, atras.z)) < 0.01)
	_afirmar("a vista aponta para onde a luneta aponta",
		absf(wrapf(j.rotation.y - (PI * 0.5 + PI), -PI, PI)) < 0.01)
	_afirmar("o prompt vira a dica da lente", str(j.get("ocupado")) == LU.DICA)

	# A roda aproxima; a mira nao sai do arco.
	var roda := InputEventMouseButton.new()
	roda.button_index = MOUSE_BUTTON_WHEEL_UP
	roda.pressed = true
	luneta.call("_input", roda)
	_afirmar("a roda aproxima (fov %.1f)" % float(j.get("fov")),
		float(j.get("fov")) < LU.ZOOM_INICIAL)
	luneta.set("_yaw", 99.0)
	luneta.call("_aplicar_mira")
	var desvio := absf(wrapf(j.rotation.y - (PI * 0.5 + PI), -PI, PI))
	_afirmar("a mira fica no arco (%.0f graus)" % rad_to_deg(desvio),
		desvio <= LU.ARCO * 0.5 + 0.001)

	# Esc larga e devolve tudo como estava.
	var esc := InputEventAction.new()
	esc.action = &"pausa"
	esc.pressed = true
	luneta.call("_input", esc)
	_afirmar("largar solta o jogador", not bool(j.get("travado")))
	_afirmar("largar devolve a lente e o olho",
		float(j.get("fov")) < 0.0 and float(j.get("olho")) < 0.0)
	_afirmar("largar devolve o corte da camera",
		absf((j.get("cam") as Camera3D).near - 0.05) < 0.001)
	_afirmar("largar devolve o corpo onde estava",
		j.global_transform.is_equal_approx(antes))
	_afirmar("a luneta volta a atender", bool(luneta.get("habilitado")))
	luneta.queue_free()
	j.queue_free()
	await process_frame
