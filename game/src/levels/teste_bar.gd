## Rotina de verificacao do Bar do Ze.
##
## Imprime linhas `[bar] chave=valor` que tools/verificar_bar.py confere.
class_name TesteBar
extends RefCounted

const SEMENTE := 88051
const ESPERA_LONGA := 3.5
const ESPERA_CURTA := 0.4

const SUPERFICIES_EXIGIDAS: Array[StringName] = [
	&"bar_piso", &"bar_teto", &"bar_formica", &"bar_cervejeira", &"bar_parede",
]


static func executar(cena: Node, jogador: Node3D) -> void:
	var arvore := cena.get_tree()
	await arvore.create_timer(1.0).timeout

	_relatar("inicio", 1)
	var retorno := jogador.global_transform

	Interiores.entrar(SEMENTE, retorno, &"bar")
	await arvore.create_timer(ESPERA_LONGA).timeout
	_relatar("entrou", 1 if Interiores.dentro else 0)

	_medir_cidade()

	var interior := arvore.current_scene.get_node_or_null("Interior")
	if interior == null:
		_relatar("interior_ausente", 1)
		_encerrar(arvore)
		return

	_medir_salao(interior)
	_medir_planta(jogador)
	_medir_ambiente(arvore)
	await _testar_saida(arvore, interior, jogador, retorno)

	_relatar("fim", 1)
	_encerrar(arvore)


static func _encerrar(arvore: SceneTree) -> void:
	AudioDirector.silenciar_tudo()
	await arvore.process_frame
	arvore.quit(0)


static func _relatar(chave: String, valor: Variant) -> void:
	print("[bar] %s=%s" % [chave, valor])


# --- cidade -----------------------------------------------------------------

static func _medir_cidade() -> void:
	var por_tipo: Dictionary[StringName, int] = {}
	var chunks_com_fachada := 0
	var chunks_com_vao := 0
	var chunks_com_mesa := 0
	var mesas_calcada := 0
	var deslizantes_bar := 0

	for cx in range(-6, 6):
		for cz in range(-6, 6):
			var dados := ChunkBuilder.construir(cx, cz)
			var tem_bar := false
			for prop: Dictionary in dados["props"]:
				if prop.get("tipo", "") != "porta":
					continue
				var tipo: StringName = prop.get("interior", &"apartamento")
				por_tipo[tipo] = int(por_tipo.get(tipo, 0)) + 1
				if tipo == &"bar":
					tem_bar = true
					if bool(prop.get("deslizante", false)):
						deslizantes_bar += 1
			if tem_bar:
				var sup: Dictionary = dados["superficies"]
				if sup.has(&"bar_letreiro") and not PSXMesh.dados_vazio(sup[&"bar_letreiro"]):
					chunks_com_fachada += 1
				if sup.has(&"bar_vao") and not PSXMesh.dados_vazio(sup[&"bar_vao"]):
					chunks_com_vao += 1
				if sup.has(&"bar_mesa") and not PSXMesh.dados_vazio(sup[&"bar_mesa"]):
					chunks_com_mesa += 1
					# O tampo e a unica peca em bar_mesa (pe e base sao metal).
					# Uma caixa = 12 tris.
					mesas_calcada += maxi(1, PSXMesh.dados_triangulos(sup[&"bar_mesa"]) / 12)

	_relatar("portas_bar", int(por_tipo.get(&"bar", 0)))
	_relatar("portas_mercado", int(por_tipo.get(&"mercado", 0)))
	_relatar("portas_casa", int(por_tipo.get(&"casa", 0)))
	_relatar("portas_apartamento", int(por_tipo.get(&"apartamento", 0)))
	_relatar("chunks_com_fachada", chunks_com_fachada)
	_relatar("chunks_com_vao", chunks_com_vao)
	_relatar("chunks_com_mesa", chunks_com_mesa)
	_relatar("mesas_calcada", mesas_calcada)
	_relatar("deslizantes_bar", deslizantes_bar)


# --- salao ------------------------------------------------------------------

static func _medir_salao(interior: Node) -> void:
	var tris := 0
	var superficies: Array[String] = []
	var luzes := 0
	var tvs := 0
	var saves := 0
	var gente := 0

	for filho: Node in interior.get_children():
		if filho is MeshInstance3D:
			superficies.append(filho.name)
			tris += PSXMesh.triangle_count((filho as MeshInstance3D).mesh)
		elif filho is Lampada:
			luzes += 1
		elif filho is Televisao:
			tvs += 1
		elif filho is PontoDeSave:
			saves += 1
		elif filho is Convidado:
			gente += 1

	_relatar("tris", tris)
	_relatar("luzes", luzes)
	_relatar("luzes_totais", _contar_luzes(interior))
	_relatar("tv", tvs)
	_relatar("ponto_de_save", saves)
	_relatar("gente", gente)

	var corpo := interior.get_node_or_null("Colisao")
	_relatar("colisores", corpo.get_child_count() if corpo != null else 0)

	var faltando: Array[String] = []
	for exigida: StringName in SUPERFICIES_EXIGIDAS:
		if not superficies.has(String(exigida)):
			faltando.append(String(exigida))
	_relatar("superficies_faltando", faltando.size())
	if not faltando.is_empty():
		_relatar("faltou", ",".join(faltando))

	var planta := BarBuilder.construir(SEMENTE)
	_relatar("mesas_dentro", int(planta.get("mesas", 0)))
	_relatar("cadeiras_dentro", int(planta.get("cadeiras", 0)))
	_relatar("tem_bar_mesa", 1 if superficies.has("bar_mesa") else 0)
	_relatar("tem_bar_cadeira", 1 if superficies.has("bar_cadeira") else 0)


static func _contar_luzes(no: Node) -> int:
	var total := 0
	for filho: Node in no.get_children():
		if filho is OmniLight3D or filho is SpotLight3D:
			total += 1
		total += _contar_luzes(filho)
	return total


static func _medir_ambiente(arvore: SceneTree) -> void:
	var fog := arvore.get_first_node_in_group(&"fog_controller") as FogController
	if fog == null:
		_relatar("fog_ausente", 1)
		return
	_relatar("ambiente", String(fog.preset_ativo()))


# --- planta caminhavel ------------------------------------------------------

const POUSOS: Array[Dictionary] = [
	{"nome": "vao", "pos": Vector3(5.0, 0.95, 0.70)},
	{"nome": "salao", "pos": Vector3(5.0, 0.95, 3.40)},
	{"nome": "frente_balcao", "pos": Vector3(6.4, 0.95, 4.50)},
]


static func _medir_planta(jogador: Node3D) -> void:
	var espaco := jogador.get_world_3d().direct_space_state
	var desloc := Interiores.DESLOCAMENTO
	var forma := SphereShape3D.new()
	forma.radius = 0.35
	var ocupados: Array[String] = []
	for pouso: Dictionary in POUSOS:
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = forma
		q.transform = Transform3D(Basis.IDENTITY, desloc + Vector3(pouso["pos"]))
		q.collision_mask = 1
		q.exclude = [jogador.get_rid()]
		if not espaco.intersect_shape(q, 1).is_empty():
			ocupados.append(String(pouso["nome"]))
	_relatar("pousos_ocupados", ocupados.size())
	if not ocupados.is_empty():
		_relatar("ocupado", ",".join(ocupados))


# --- saida ------------------------------------------------------------------

static func _testar_saida(arvore: SceneTree, interior: Node, jogador: Node3D,
		retorno: Transform3D) -> void:
	var saida := interior.get_node_or_null("Saida") as Interativo
	if saida == null:
		_relatar("saida_ausente", 1)
		return
	_relatar("saida_sem_folha", 0 if saida.get_node_or_null("PortaAutomatica") != null
		or saida.get_node_or_null("FolhaSaida") != null else 1)

	Multidao.parar()
	saida.interagir(jogador)
	await arvore.create_timer(ESPERA_LONGA).timeout
	_relatar("saiu", 0 if Interiores.dentro else 1)
	var plano := Vector2(jogador.global_position.x - retorno.origin.x,
		jogador.global_position.z - retorno.origin.z)
	_relatar("desvio_no_plano", snappedf(plano.length(), 0.01))
	_relatar("queda", snappedf(retorno.origin.y - jogador.global_position.y, 0.01))

	var fog := arvore.get_first_node_in_group(&"fog_controller") as FogController
	if fog != null:
		_relatar("ambiente_apos_sair", String(fog.preset_ativo()))
