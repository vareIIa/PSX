## Fotos de fachada para julgar predios e casas (Fase 4 do PLANO_BAR_E_CIDADE_AAA).
##
##     godot --path game --resolution 1600x900 -- --pular-menu --teste-fachadas \
##         --fachadas-fotos=DIR [--raio=4] [--por-tipo=6] [--janelas-abertas]
##         [--so-ladeira]
##
## Para cada chunk edificado em volta da praca, a face de rua mais comprida:
## uma foto de frente, do outro lado da rua, e uma de vies, da calcada. As
## comerciais e as de casa se alternam ate `--por-tipo` de cada. O nome do
## arquivo diz o chunk e o tipo, para achar o lote na regua de coplanares
## (tests/bancada_coplanar.gd --coords=cx,cz).
##
## O jogador e posto na calcada na altura do relevo; a multidao para, senao o
## pedestre empurra o jogador e a foto sai de outro lugar (memoria "ir-para nao
## e regua").
class_name TesteFachadas
extends RefCounted

const ESPERA := 1.6
## De frente: do outro lado da rua. De vies: da calcada, 35 graus.
const DIST_FRENTE := 13.0
const DIST_VIES := 7.0
const ALVO_Y := 3.6


static func executar(cena: Node, jogador: Node3D) -> void:
	var arvore := cena.get_tree()
	var fotos := ""
	var raio := 4
	var por_tipo := 6
	var so_ladeira := OS.get_cmdline_user_args().has("--so-ladeira")
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--fachadas-fotos="):
			fotos = a.trim_prefix("--fachadas-fotos=")
		elif a.begins_with("--raio="):
			raio = a.trim_prefix("--raio=").to_int()
		elif a.begins_with("--por-tipo="):
			por_tipo = a.trim_prefix("--por-tipo=").to_int()
	if fotos.is_empty():
		print("[fachadas] falta --fachadas-fotos=DIR")
		arvore.quit(1)
		return
	DirAccess.make_dir_recursive_absolute(fotos)
	await arvore.create_timer(1.5).timeout
	Multidao.parar()

	# `--fachadas-poses=nome:x,z,ox,oz,alto;...`: pontos fixos do mundo, para o par
	# antes x depois do mesmo balcao a 20 e a 110 m. O jogador e reposto antes da
	# foto (o `--ir-para` sozinho deixa pedestre empurrar e a foto sai de outro
	# lugar).
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--fachadas-poses="):
			for pose: String in a.trim_prefix("--fachadas-poses=").split(";", false):
				var nome := pose.get_slice(":", 0)
				var n := pose.get_slice(":", 1).split_floats(",")
				var p := Vector3(n[0], 0.0, n[1])
				var olho := Vector3(n[2], n[4] + Relevo.altura(n[2], n[3]), n[3])
				await _fotografar(arvore, jogador, p, olho, fotos.path_join(nome + ".png"))
			AudioDirector.silenciar_tudo()
			await arvore.process_frame
			arvore.quit(0)
			return

	var alvos := _alvos(raio, por_tipo, so_ladeira)
	print("[fachadas] alvos=", alvos.size())
	for alvo: Dictionary in alvos:
		var c: Vector2i = alvo["chunk"]
		var meio: Vector3 = alvo["meio"]
		var normal: Vector3 = alvo["normal"]
		var eixo: Vector3 = alvo["eixo"]
		var nome := "%s_%d_%d" % [alvo["tipo"], c.x, c.y]
		var poses := {
			"frente": meio + normal * DIST_FRENTE,
			"vies": meio + normal * (DIST_VIES * 0.82) + eixo * (DIST_VIES * 0.57),
		}
		for pose: String in poses:
			var olho := meio + Vector3(0.0, Relevo.altura(meio.x, meio.z) + ALVO_Y, 0.0)
			await _fotografar(arvore, jogador, poses[pose], olho,
				fotos.path_join("%s_%s.png" % [nome, pose]))
	AudioDirector.silenciar_tudo()
	await arvore.process_frame
	arvore.quit(0)


## Poe o jogador no chao em `p` olhando `olho`, espera o chunk assentar e
## fotografa. Repoe a pose logo antes da foto: se algo o empurrou na espera, a
## foto sai do mesmo lugar mesmo assim.
static func _fotografar(arvore: SceneTree, jogador: Node3D, p: Vector3, olho: Vector3,
		caminho: String) -> void:
	for vez in 2:
		p.y = Relevo.altura(p.x, p.z) + 0.2
		jogador.global_position = p
		if jogador.has_method("olhar_para"):
			jogador.call("olhar_para", olho - Vector3(0.0, Player.ALTURA_OLHO, 0.0))
		if jogador.has_method("zerar_velocidade"):
			jogador.call("zerar_velocidade")
		await arvore.create_timer(ESPERA if vez == 0 else 0.25).timeout
	await RenderingServer.frame_post_draw
	arvore.root.get_viewport().get_texture().get_image().save_png(caminho)
	print("[fachadas] foto ", caminho)


## A face mais comprida de cada chunk edificado, alternando comercio e casa, do
## centro para fora.
static func _alvos(raio: int, por_tipo: int, so_ladeira: bool = false) -> Array[Dictionary]:
	var coords: Array[Vector2i] = []
	for cz in range(-raio, raio + 1):
		for cx in range(-raio, raio + 1):
			coords.append(Vector2i(cx, cz))
	coords.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.length_squared() < b.length_squared())
	var contagem := {"comercio": 0, "casa": 0}
	var saida: Array[Dictionary] = []
	for c: Vector2i in coords:
		var quadra := MalhaUrbana.quadra_de(c.x, c.y)
		var tipo := ""
		if bool(quadra.get("casa", false)):
			tipo = "casa"
		elif int(quadra["distrito"]) == MalhaUrbana.Distrito.COMERCIAL:
			tipo = "comercio"
		if tipo.is_empty() or int(contagem[tipo]) >= por_tipo:
			continue
		# `--so-ladeira`: so chunk fora do plano (porao, escada, embasamento).
		if so_ladeira and Relevo.plano(c.x, c.y):
			continue
		var faces := ChunkBuilder.faces_de_rua(MalhaUrbana.bordas(c.x, c.y),
			ChunkBuilder.area_util(c.x, c.y))
		if faces.is_empty():
			continue
		faces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["comprimento"]) > float(b["comprimento"]))
		var f: Dictionary = faces[0]
		if float(f["comprimento"]) < 12.0:
			continue
		var origem := Vector3(c.x * KitModular.CHUNK, 0.0, c.y * KitModular.CHUNK)
		var eixo: Vector3 = f["eixo"]
		var meio: Vector3 = origem + Vector3(f["canto"]) + eixo * (float(f["comprimento"]) * 0.5)
		saida.append({"chunk": c, "tipo": tipo, "meio": meio,
			"normal": KitModular._normal(int(f["direcao"])), "eixo": eixo})
		contagem[tipo] = int(contagem[tipo]) + 1
	return saida
