## Oleo no asfalto, pichacao e encardido na parede: o criterio A17 do
## PLANO_AAA_4K.
##
## Por que um diretor que segue o jogador
## --------------------------------------
## O mesmo desenho das pocas (`Pocas`) e das sondas (`SondasReflexo`): a cidade
## e montada por streaming, e pendurar decal no chunk faria o custo crescer com
## o tamanho do mapa e obrigaria a mexer no `ChunkManager`, que tem trabalho de
## outra sessao. Aqui ha um punhado de `Decal` por familia, REAPONTADOS para os
## lugares mais proximos da camera.
##
## Onde cada um nasce, e por que a resposta e sempre a mesma
## ---------------------------------------------------------
## Cada chunk tem VAGAS: duas de oleo, duas de pichacao, duas de encardido. Cada
## vaga sai de um hash de (chunk, familia, numero), entao a mancha de oleo da
## esquina fica na esquina em toda execucao e em toda maquina. E o teto por
## chunk e aritmetica, nao estatistica: seis vagas mais as pocas, que ja tem o
## proprio teto (ver `censo`).
##
## - **Oleo**: na faixa de estacionamento, onde o carro para e pinga. Viela nao
##   tem estacionamento, entao la nao pinga nada — e viela nao e onde se
##   estaciona.
## - **Pichacao e encardido**: na PAREDE. A parede nao e conta: a fachada tem
##   recuo, jardim, loja e parque, e a unica fonte honesta de "ha um muro aqui"
##   e um raio. Ele sai da calcada rumo a quadra e so aceita `StaticBody3D` com
##   a face voltada para a rua; carro, gente e poste nao sao muro.
##
## Ligados ao molhado
## ------------------
## Agua escurece o que esta em cima da parede e acende a pelicula do oleo. A
## pichacao e o encardido ESCURECEM com `Clima.molhado_visivel()`; o oleo fica
## mais visivel, porque e na rua molhada que a mancha de arco-iris aparece.
##
## Decal e recurso de Forward+: no perfil de Compatibility ele e aceito sem
## aviso e nao desenha nada. No PS1 STYLE este no nem existe — quem o cria e a
## `QualidadeGrafica`, so no MODERNO.
class_name DecalquesRua
extends Node3D

enum Tipo { OLEO, PICHACAO, SUJEIRA }

const TAM := 32.0
const DIR := "res://assets/textures_hd/"

## Vagas por chunk, por familia. Com as pocas, e o que mantem o chunk dentro do
## teto do criterio A17 (doze).
const VAGAS := 2
## Chance de a vaga estar ocupada, por familia. Nem todo muro tem pichacao e nem
## todo estacionamento tem mancha — a cidade inteira pichada vira papel de
## parede.
const CHANCE := {Tipo.OLEO: 0.55, Tipo.PICHACAO: 0.5, Tipo.SUJEIRA: 0.7}
## Decals no pool, por familia. O raio de 30 m pega nove chunks; com a chance
## acima sobra folga.
const POOL := {Tipo.OLEO: 12, Tipo.PICHACAO: 10, Tipo.SUJEIRA: 12}
## Alem disto o decal nao sobrevive a nevoa, nem a leve.
const RAIO := 30.0
## Segundos entre duas reavaliacoes.
const PASSO := 0.5
## Raios de parede por reavaliacao. A resposta de cada vaga fica guardada, entao
## o custo e so o da primeira vez que a vaga entra no raio.
const RAIOS_POR_PASSO := 8
## Altura do raio que procura parede, por familia: pichacao na altura da mao,
## encardido perto do chao.
const ALTURA_RAIO := {Tipo.PICHACAO: 1.5, Tipo.SUJEIRA: 0.9}
## Distancia maxima da calcada ate a fachada. Alem disto e jardim ou parque.
const ALCANCE := 5.0

const TEXTURAS := {
	Tipo.OLEO: ["decalque_oleo_a", "decalque_oleo_b"],
	Tipo.PICHACAO: ["decalque_pichacao_a", "decalque_pichacao_b",
		"decalque_pichacao_c", "decalque_pichacao_d"],
	Tipo.SUJEIRA: ["decalque_sujeira_a", "decalque_sujeira_b"],
}

var _pools := {}
## Cor e ORM carregados, por nome.
var _tex := {}
## Vaga ja respondida: chave -> Transform3D e tamanho, ou null (sem lugar).
var _vagas := {}
var _relogio := 0.0
var _ultimo_molhado := -1.0


func _ready() -> void:
	name = "DecalquesRua"
	for nome_lista: Array in TEXTURAS.values():
		for nome: String in nome_lista:
			_tex[nome] = [
				load(DIR + nome + ".png") as Texture2D,
				load(DIR + nome + "_orm.png") as Texture2D,
			]
			_ancorar(nome)
	for t: Tipo in POOL:
		var lista: Array[Decal] = []
		for i in int(POOL[t]):
			var d := Decal.new()
			d.name = "%s%d" % [_rotulo(t), i]
			d.set_meta(&"tipo", _rotulo(t))
			d.visible = false
			d.distance_fade_enabled = true
			d.distance_fade_begin = RAIO * 0.7
			d.distance_fade_length = RAIO * 0.3
			# A borda some por cima e por baixo em vez de cortar reto no limite
			# da caixa, que e o que denuncia decal como decal.
			d.upper_fade = 0.35
			d.lower_fade = 0.35
			# Na parede, a caixa do decal atravessa a quina e pega a calcada;
			# o fade por normal apaga o que nao olha para a mesma direcao.
			d.normal_fade = 0.5 if t != Tipo.OLEO else 0.0
			add_child(d)
			lista.append(d)
		_pools[t] = lista


func _process(delta: float) -> void:
	_relogio += delta
	if _relogio < PASSO:
		return
	_relogio = 0.0
	_reavaliar()


## Reavalia e avisa quando passa de 4 ms. Medido em 4K na rota noturna, nenhuma
## reavaliacao chegou la; o aviso fica para o dia em que chegar.
func _reavaliar() -> void:
	var t0 := Time.get_ticks_usec()
	_reavaliar_de_fato()
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	if ms > 4.0:
		print("[decalques] reavaliacao lenta: %.1f ms" % ms)


func _reavaliar_de_fato() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var centro := camera.global_position
	var molhado := Clima.molhado_visivel()
	var raios := RAIOS_POR_PASSO
	var c0 := Vector2i(floori((centro.x - RAIO) / TAM), floori((centro.z - RAIO) / TAM))
	var c1 := Vector2i(floori((centro.x + RAIO) / TAM), floori((centro.z + RAIO) / TAM))

	for t: Tipo in POOL:
		var achados: Array = []
		for cx in range(c0.x, c1.x + 1):
			for cz in range(c0.y, c1.y + 1):
				for k in VAGAS:
					var chave := Vector4i(cx, cz, int(t), k)
					if not _vagas.has(chave):
						if t != Tipo.OLEO and raios <= 0:
							continue
						var lugar = _achar(t, cx, cz, k)
						if t != Tipo.OLEO:
							raios -= 1
						# So guarda o que achou, e o "nao ha lugar" que nao
						# dependa de raio. Um raio que errou porque o chunk
						# ainda nao montou a colisao tem de tentar de novo.
						if lugar != null or t == Tipo.OLEO or _chunk_pronto(cx, cz):
							_vagas[chave] = lugar
					var v = _vagas.get(chave)
					if v == null:
						continue
					var onde: Vector3 = (v["xf"] as Transform3D).origin
					var dist := onde.distance_to(centro)
					if dist <= RAIO:
						achados.append([dist, v])
		achados.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		var pool: Array[Decal] = _pools[t]
		for i in pool.size():
			var d := pool[i]
			if i >= achados.size():
				d.visible = false
				continue
			_vestir(d, t, achados[i][1], molhado)
	_ultimo_molhado = molhado


## Um decal escondido que segura a textura no atlas para sempre.
##
## O Godot junta toda textura de decal num ATLAS e o refaz quando uma textura
## entra ou sai dele. O pool reaponta decals entre vagas, e cada troca de
## variante tirava uma textura do atlas e punha outra: medido em 4K, um quadro
## de 60 ms sem chunk novo nem pipeline novo, so no lado com decalques. Com cada
## variante presa num decal que nunca some, o atlas nasce completo na montagem e
## nao muda mais.
func _ancorar(nome: String) -> void:
	var d := Decal.new()
	d.name = "Ancora_" + nome
	d.texture_albedo = _tex[nome][0]
	d.texture_orm = _tex[nome][1]
	d.size = Vector3(0.01, 0.01, 0.01)
	# Longe e minusculo, e nao `visible = false`: o que conta para o atlas e a
	# textura presa no decal, e um no escondido pode ser tirado da conta.
	d.position = Vector3(0.0, -500.0, 0.0)
	d.cull_mask = 0
	add_child(d)


## Poe o decal numa vaga e aplica o molhado.
func _vestir(d: Decal, t: Tipo, v: Dictionary, molhado: float) -> void:
	var nome: String = v["tex"]
	var par: Array = _tex[nome]
	if d.texture_albedo != par[0]:
		d.texture_albedo = par[0]
		d.texture_orm = par[1]
	d.global_transform = v["xf"]
	d.size = v["tam"]
	match t:
		Tipo.OLEO:
			# Seco, a mancha e fosca e quase some no asfalto escuro. Molhada, a
			# pelicula acende — e o reflexo de tela passa a ter o que mostrar.
			d.albedo_mix = lerpf(0.55, 0.9, molhado)
			d.modulate = Color(1.0, 1.0, 1.0, lerpf(0.6, 1.0, molhado))
		Tipo.PICHACAO:
			# Tinta molhada escurece e ganha saturacao; parede molhada tambem, e
			# as duas juntas mantem o contraste.
			var escuro := lerpf(1.0, 0.72, molhado)
			d.albedo_mix = 0.92
			d.modulate = Color(escuro, escuro, escuro, 1.0)
		Tipo.SUJEIRA:
			# A agua que escorre e a mesma que suja: com a parede molhada, o
			# encardido aparece mais.
			d.albedo_mix = lerpf(0.55, 0.85, molhado)
			d.modulate = Color(1.0, 1.0, 1.0, lerpf(0.7, 1.0, molhado))
	d.visible = true


## A vaga `k` da familia `t` no chunk (cx, cz). Devolve null se nao ha lugar.
func _achar(t: Tipo, cx: int, cz: int, k: int):
	var h := _hash(cx * 4 + int(t), cz * 4 + k)
	if _frac(h) > float(CHANCE[t]):
		return null
	var b := MalhaUrbana.bordas(cx, cz)
	# O lado do chunk: um dos quatro, sorteado entre os que tem rua.
	var lados: Array[String] = []
	for chave: String in ["x0", "x1", "z0", "z1"]:
		if b[chave] != MalhaUrbana.Via.NENHUMA:
			lados.append(chave)
	if lados.is_empty():
		return null
	var lado: String = lados[int(_frac(h * 5.31) * lados.size()) % lados.size()]
	var via: MalhaUrbana.Via = b[lado]
	# Longe das esquinas: o cruzamento e do chunk dono e tem faixa, semaforo e
	# zebra (ver a memoria "cruzamento inteiro vem do chunk dono").
	var ao_longo := lerpf(7.0, TAM - 7.0, _frac(h * 9.77))
	var nomes: Array = TEXTURAS[t]
	var tex: String = nomes[int(_frac(h * 13.1) * nomes.size()) % nomes.size()]

	if t == Tipo.OLEO:
		var estac := MalhaUrbana.largura_estacionamento(via)
		if estac <= 0.0:
			return null
		# Centro da faixa de estacionamento, a partir da borda do chunk.
		var recuo := MalhaUrbana.meia_pista(via) + estac * 0.5
		var onde := _no_lado(cx, cz, lado, ao_longo, recuo, 0.02)
		var lado_m := lerpf(1.4, 2.4, _frac(h * 17.3))
		var giro := _frac(h * 21.7) * TAU
		var xf := Transform3D(Basis(Vector3.UP, giro), onde)
		return {"xf": xf, "tam": Vector3(lado_m, 1.0, lado_m), "tex": tex}

	# Parede: o raio sai da calcada, meio metro antes do fim dela, rumo a quadra.
	var dentro := _para_dentro(lado)
	var partida := _no_lado(cx, cz, lado, ao_longo,
		MalhaUrbana.recuo(via) - 0.5, float(ALTURA_RAIO[t]))
	var espaco := get_world_3d().direct_space_state
	var pergunta := PhysicsRayQueryParameters3D.create(partida,
		partida + dentro * ALCANCE)
	pergunta.collide_with_areas = false
	var bateu := espaco.intersect_ray(pergunta)
	if bateu.is_empty() or not (bateu["collider"] is StaticBody3D):
		return null
	var normal: Vector3 = bateu["normal"]
	# So face vertical voltada para a rua. Degrau, marquise e quina de janela
	# respondem ao raio e nao sao muro.
	if absf(normal.y) > 0.2 or normal.dot(-dentro) < 0.7:
		return null
	var ponto: Vector3 = bateu["position"]
	# Base do decal na parede: o eixo Y do decal aponta para FORA da parede (ele
	# projeta ao longo de -Y), o Z aponta para BAIXO (o v da textura cresce para
	# o chao) e o X e o que sobra, para a imagem nao sair espelhada.
	var y := normal.normalized()
	var z := Vector3.DOWN
	var x := y.cross(z).normalized()
	if t == Tipo.PICHACAO:
		var largura := lerpf(1.8, 3.2, _frac(h * 23.9))
		var centro := Vector3(ponto.x, lerpf(1.2, 1.9, _frac(h * 27.1)), ponto.z)
		return {"xf": Transform3D(Basis(x, y, z), centro),
			"tam": Vector3(largura, 0.6, largura * 0.5), "tex": tex}
	# Encardido: do chao ate 1,6 m, mais largo que alto.
	var largura_s := lerpf(2.4, 4.0, _frac(h * 29.3))
	var centro_s := Vector3(ponto.x, 0.8, ponto.z)
	return {"xf": Transform3D(Basis(x, y, z), centro_s),
		"tam": Vector3(largura_s, 0.6, 1.7), "tex": tex}


## A colisao do chunk ja existe? Um raio que erra num chunk que ainda nao montou
## nao pode virar "aqui nao ha muro" para sempre.
func _chunk_pronto(cx: int, cz: int) -> bool:
	var espaco := get_world_3d().direct_space_state
	var meio := Vector3((float(cx) + 0.5) * TAM, 20.0, (float(cz) + 0.5) * TAM)
	var p := PhysicsRayQueryParameters3D.create(meio, meio + Vector3.DOWN * 40.0)
	return not espaco.intersect_ray(p).is_empty()


## Um ponto no lado `lado` do chunk, `ao_longo` metros ao longo dele e `recuo`
## metros para dentro a partir da borda.
static func _no_lado(cx: int, cz: int, lado: String, ao_longo: float,
		recuo: float, altura: float) -> Vector3:
	var x0 := float(cx) * TAM
	var z0 := float(cz) * TAM
	match lado:
		"x0":
			return Vector3(x0 + recuo, altura, z0 + ao_longo)
		"x1":
			return Vector3(x0 + TAM - recuo, altura, z0 + ao_longo)
		"z0":
			return Vector3(x0 + ao_longo, altura, z0 + recuo)
		_:
			return Vector3(x0 + ao_longo, altura, z0 + TAM - recuo)


## Para que lado fica a quadra, visto da rua do lado `lado`.
static func _para_dentro(lado: String) -> Vector3:
	match lado:
		"x0":
			return Vector3.RIGHT
		"x1":
			return Vector3.LEFT
		"z0":
			return Vector3.BACK
		_:
			return Vector3.FORWARD


static func _rotulo(t: Tipo) -> String:
	match t:
		Tipo.OLEO:
			return "oleo"
		Tipo.PICHACAO:
			return "pichacao"
		_:
			return "sujeira"


## Quantos decalques de cada familia estao acesos agora, e o maior numero
## num chunk so — somando as pocas. E a medida do criterio A17.
##
## Devolve {"oleo": n, "pichacao": n, "sujeira": n, "poca": n,
## "max_por_chunk": n, "chunk_mais_cheio": Vector2i}.
func censo() -> Dictionary:
	var por_chunk := {}
	var soma := {"oleo": 0, "pichacao": 0, "sujeira": 0, "poca": 0}
	var decals: Array[Decal] = []
	for t: Tipo in _pools:
		decals.append_array(_pools[t])
	var pocas := get_parent().get_node_or_null(^"Pocas")
	if pocas != null:
		for filho: Node in pocas.get_children():
			if filho is Decal:
				decals.append(filho as Decal)
	for d: Decal in decals:
		if not d.visible:
			continue
		var tipo := String(d.get_meta(&"tipo", "poca"))
		soma[tipo] = int(soma[tipo]) + 1
		var p := d.global_position
		var c := Vector2i(floori(p.x / TAM), floori(p.z / TAM))
		por_chunk[c] = int(por_chunk.get(c, 0)) + 1
	var maior := 0
	var qual := Vector2i.ZERO
	for c: Vector2i in por_chunk:
		if int(por_chunk[c]) > maior:
			maior = int(por_chunk[c])
			qual = c
	soma["max_por_chunk"] = maior
	soma["chunk_mais_cheio"] = qual
	return soma


static func _hash(a: int, b: int) -> float:
	var n := a * 374761393 + b * 668265263 + 1013904223
	n = (n ^ (n >> 13)) * 1274126177
	return float(absi(n ^ (n >> 16)) % 1000003) / 1000003.0


static func _frac(v: float) -> float:
	return v - floorf(v)
