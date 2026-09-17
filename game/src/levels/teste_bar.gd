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
	&"bar_cervejeira", &"bar_feltro", &"bar_letreiro", &"bar_ladrilho",
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

	var bar := _achar_bar()
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
	var faltando: Array[String] = []
	var mesas := 0
	var portas_no_chunk_do_bar := 0

	for cx in range(-6, 6):
		for cz in range(-6, 6):
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

			var dados := ChunkBuilder.construir(cx, cz)
			var sup: Dictionary = dados["superficies"]
			for exigida: StringName in SUPERFICIES_EXIGIDAS:
				if not sup.has(exigida) or PSXMesh.dados_vazio(sup[exigida]):
					if not faltando.has(String(exigida)):
						faltando.append(String(exigida))
			var por_mat: Array[Array] = []
			for mat: StringName in sup:
				var n := PSXMesh.dados_triangulos(sup[mat])
				tris_bar += n
				por_mat.append([n, String(mat)])
			# Quem esta pesando. Sem esta linha, "acima do teto" nao diz onde
			# cortar e a resposta vira trocar numero ate passar.
			por_mat.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
			var top: Array[String] = []
			for k in mini(8, por_mat.size()):
				top.append("%s:%d" % [por_mat[k][1], por_mat[k][0]])
			_relatar("peso", ",".join(top))
			# O tampo e a unica peca em bar_mesa (pe e base sao metal), e uma
			# caixa custa 12 tris. Conta as da calcada e as do salao juntas.
			if sup.has(&"bar_mesa"):
				mesas = maxi(1, PSXMesh.dados_triangulos(sup[&"bar_mesa"]) / 12)
			for prop: Dictionary in dados["props"]:
				if prop.get("tipo", "") == "porta":
					portas_no_chunk_do_bar += 1

	_relatar("bares", int(por_tipo.get(&"bar", 0)))
	_relatar("portas_mercado", int(por_tipo.get(&"mercado", 0)))
	_relatar("portas_casa", int(por_tipo.get(&"casa", 0)))
	_relatar("tris_do_chunk_do_bar", tris_bar)
	_relatar("superficies_faltando", faltando.size())
	if not faltando.is_empty():
		_relatar("faltou", ",".join(faltando))
	_relatar("mesas", mesas)
	_relatar("portas_no_chunk_do_bar", portas_no_chunk_do_bar)


## Primeiro bar da cidade, em coordenada de mundo.
static func _achar_bar() -> Dictionary:
	for raio in range(0, 7):
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

	_medir_cena(arvore, boca)
	await _caminhar_para_dentro(arvore, jogador, boca, b)


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


## Coordenada local do bar para mundo. x pela frente, z para dentro.
static func _p(boca: Vector3, b: Basis, x: float, y: float, z: float) -> Vector3:
	return boca + b * Vector3(x, y, -z)
