## Bancada de inspecao do parque. So captura, nunca entra no jogo.
##
## Existe porque julgar o parquinho de dentro da cidade e caro e fragil: e
## preciso atravessar o menu de titulo, a abertura e cento e vinte metros de
## caminhada ate a quadra certa, e qualquer coisa quebrada em outro canto da
## cena leva a inspecao junto. Aqui a cena tem o ChunkManager, a nevoa e o
## pos-processamento — que sao o que faz a imagem ser a imagem do jogo — e mais
## nada.
##
##     godot --path game res://scenes/test/parque_teste.tscn -- \
##         --em=-80,112 --de-cima=26,38,-35 --shot=fora.png --shot-quit
##     godot --path game res://scenes/test/parque_teste.tscn -- \
##         --em=-80,112 --olhar=-88,112,1.6,90 --shot=perto.png --shot-quit
##
## `--em` diz onde o streaming carrega, e e sempre a coordenada do parque.
## `--de-cima=tamanho,inclinacao,giro` fotografa a planta em projecao ortogonal.
## `--olhar=x,z,altura,giro` planta uma camera em perspectiva no chao, que e a
## unica vista que julga brinquedo: de cima nao da para ver se o travessao do
## balanco esta virado para o lado errado.
extends Node3D

@onready var _chunks: Node3D = $Chunks
@onready var _player: Node3D = $Player

const ALTURA_PADRAO := 1.62


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var em := Vector2(-80.0, 112.0)
	for a: String in args:
		if a.begins_with("--em="):
			var p := a.trim_prefix("--em=").split(",")
			if p.size() >= 2:
				em = Vector2(float(p[0]), float(p[1]))
	_player.global_position = Vector3(em.x, 1.0, em.y)
	# Travado e sem colisao: o corpo aqui e so a antena do streaming, e um
	# jogador que cai pelo chao enquanto os chunks montam sai da foto e leva a
	# carga junto.
	if _player.has_method("travar"):
		_player.call("travar", true)
	if _player is CharacterBody3D:
		var corpo := _player as CharacterBody3D
		corpo.set_collision_mask_value(1, false)
		corpo.set_physics_process(false)
	# Dia claro e sem nevoa, e nao o clima do jogador. A cidade e noturna e com
	# 45 m de nevoa: a planta do parque sai cinza uniforme e o brinquedo a dez
	# metros some. Julgar forma pede luz; o clima e julgado em outra captura.
	var clima := "res://resources/fog/fog_dia_sol.tres"
	for a: String in args:
		if a.begins_with("--clima="):
			clima = "res://resources/fog/fog_%s.tres" % a.trim_prefix("--clima=")
	($Ambiente as FogController).forcar(clima)

	ChunkManager.iniciar(_chunks, _player)
	ChunkManager.alcance_infinito = true
	ChunkManager.raio_extra = 1
	ChunkManager.recarregar_preset()

	# A prova de que o parque sai igual venha de onde vier. Ver a nota de
	# determinismo no topo do ParqueBuilder: os chunks sao montados em threads e
	# em ordem imprevisivel, e um sorteio que dependa de estado compartilhado faz
	# a mesma arvore nascer de dois tamanhos conforme quem a desenha.
	if args.has("--ordem"):
		_medir_ordem(em)

	for a: String in args:
		if a.begins_with("--de-cima="):
			var p := a.trim_prefix("--de-cima=").split(",")
			_camera_de_cima(em, float(p[0]),
				deg_to_rad(float(p[1]) if p.size() >= 2 else 90.0),
				deg_to_rad(float(p[2]) if p.size() >= 3 else 0.0))
		elif a.begins_with("--olhar="):
			var p := a.trim_prefix("--olhar=").split(",")
			if p.size() >= 4:
				_camera_no_chao(Vector3(float(p[0]),
					float(p[2]) if p.size() >= 3 else ALTURA_PADRAO, float(p[1])),
					deg_to_rad(float(p[3])))


func _camera_de_cima(em: Vector2, tamanho: float, inclinacao: float,
		giro: float) -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = tamanho
	# Perto, e ainda assim NAO se julga piso daqui.
	#
	# O snap de vertice do psx_surface quantiza a posicao na tela. Visto de cima,
	# um triangulo de grama cobre meia quadra, e meio pixel de snap nessa escala
	# vale mais de dez centimetros de mundo — mais que os quatro que separam a
	# grama da areia. O resultado e grama piscando por cima da caixa de areia
	# numa captura de planta, num pedaco de chao que no nivel do olho esta
	# inteiro. Ja custou uma investigacao; a planta serve para layout, e piso se
	# confere com `--olhar`.
	cam.near = 1.0
	cam.far = 260.0
	add_child(cam)
	var direcao := Vector3(cos(inclinacao) * sin(giro), sin(inclinacao),
		cos(inclinacao) * cos(giro))
	cam.global_position = Vector3(em.x, 0.0, em.y) + direcao * 110.0
	# De cima em pe, UP e paralelo ao olhar e `look_at` recusa. O norte da foto
	# passa a ser -Z, que e o que a planta do mapa ja usa.
	var acima := absf(sin(inclinacao)) > 0.999
	cam.look_at(Vector3(em.x, 0.0, em.y),
		Vector3.FORWARD if acima else Vector3.UP)
	cam.current = true


func _camera_no_chao(onde: Vector3, giro: float) -> void:
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.05
	cam.far = 260.0
	add_child(cam)
	cam.global_position = onde
	cam.rotation = Vector3(deg_to_rad(-8.0), giro, 0.0)
	cam.current = true


## Monta a quadra inteira nos dois sentidos e compara chunk a chunk.
func _medir_ordem(em: Vector2) -> void:
	var q := MalhaUrbana.quadra_de(floori(em.x / ChunkManager.TAM),
		floori(em.y / ChunkManager.TAM))
	var chunks: Array[Vector2i] = []
	for cz in range(int(q["z0"]), int(q["z1"])):
		for cx in range(int(q["x0"]), int(q["x1"])):
			chunks.append(Vector2i(cx, cz))

	var direta: Array[int] = []
	for c: Vector2i in chunks:
		direta.append(int(ChunkBuilder.construir(c.x, c.y)["triangulos"]))
	chunks.reverse()
	var inversa: Dictionary[Vector2i, int] = {}
	for c: Vector2i in chunks:
		inversa[c] = int(ChunkBuilder.construir(c.x, c.y)["triangulos"])
	chunks.reverse()

	var divergentes := 0
	var total := 0
	for i in chunks.size():
		total += direta[i]
		if inversa[chunks[i]] != direta[i]:
			divergentes += 1
	print("[ordem] chunks=%d divergentes=%d triangulos=%d"
		% [chunks.size(), divergentes, total])
