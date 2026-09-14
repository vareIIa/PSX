## A estrada de terra e a mata dos dois lados, montadas em trechos conforme o
## carro anda.
##
## Uma esteira, e nao um mapa
## --------------------------
## A cena dura pouco mais de um minuto a 65 km/h, o que da uns mil e duzentos
## metros de estrada. Montar isso de uma vez seriam oitenta mil triangulos para
## mostrar sessenta metros por vez, que e o que a nevoa deixa ver. Entao a
## estrada e uma esteira: existem cinco trechos de 28,8 m por vez — um atras e
## tres a frente — e cada vez que o carro entra num trecho novo, o de tras morre
## e outro nasce la na frente.
##
## O caminho e uma FUNCAO, e nao uma lista
## ---------------------------------------
## A linha do meio da estrada e uma soma de senos de `s`, a distancia percorrida.
## Isso da tres coisas de graca: a tangente sai da derivada (nao ha diferenca
## finita entre pontos, que e o que faz a camera tremer em curva), qualquer
## trecho pode ser montado em qualquer ordem sem depender do anterior, e o
## minimapa consegue desenhar cem metros a frente sem que nada esteja montado.
##
## `s` cresce para -Z. E a convencao do resto do jogo: a rua principal da cidade
## corre em -Z e e para la que o jogador nasce olhando.
##
## Sem colisao, sem chunk, sem streaming
## -------------------------------------
## Nao passa pelo ChunkManager de proposito. O ChunkManager e sobre uma cidade
## em grade de 32 m que se percorre em qualquer direcao; isto e um corredor de
## sentido unico que existe por oitenta segundos e some. Emprestar a maquinaria
## de streaming aqui custaria mais linhas do que a esteira inteira.
class_name EstradaBuilder
extends Node3D

const MAT_DIR := "res://resources/materials/mat_%s.tres"

const PASSO := KitEstrada.PASSO
## Passos por trecho. Dezesseis dao 28,8 m, que e perto do chunk de 32 m do
## resto do jogo — nao por acaso: e a escala em que um pedaco de mundo custa uns
## dois mil triangulos, e essa e a conta que ja esta calibrada.
const PASSOS_POR_TRECHO := 16
const TRECHO := PASSO * float(PASSOS_POR_TRECHO)

## Quantos trechos ficam de pe atras e a frente do carro.
##
## Tres a frente sao 86 m, bem alem dos 62 m em que a nevoa fecha. A folga
## existe para o plano de cima: a camera que sobe acima da copa ve muito mais
## estrada do que a de dentro do carro, e um trecho faltando ali aparece como um
## fim de mundo no meio do quadro.
const ATRAS := 1
const ADIANTE := 3

# --- forma do caminho -------------------------------------------------------
# Tres senos em comprimentos de onda sem razao inteira entre si. Com dois, a
# estrada repete o mesmo S a cada volta do maior; com razao inteira, repete
# ainda mais cedo. Aqui o padrao so voltaria a se repetir depois de vinte
# quilometros, e a cena tem um.

const CURVA := [
	{"amp": 14.0, "onda": 95.0, "fase": 0.0},
	{"amp": 5.0, "onda": 38.0, "fase": 1.7},
	{"amp": 2.2, "onda": 17.0, "fase": 0.4},
]
## As lombadas. Amplitude pequena de proposito: a estrada tem de subir e descer
## o bastante para o fundo do quadro mudar de altura — que e o que faz a curva
## parecer ter relevo — e pouco o bastante para o capo nunca tapar a estrada.
const RELEVO := [
	{"amp": 1.7, "onda": 120.0, "fase": 0.9},
	{"amp": 0.9, "onda": 47.0, "fase": 2.3},
]

# --- corte da estrada na mata -----------------------------------------------

## Ate onde a mata e desenhada, medido do eixo. Alem disso a nevoa fecha e o que
## houvesse la seria pintado da cor dela.
const ALCANCE_MATA := 32.0
## Onde as arvores comecam. Menos que isto e galho dentro da pista.
const RECUO_ARVORE := 3.8

## Colunas do chao da mata, em metros a partir da borda do leito.
##
## Cinco colunas, e nao um plano so. A UV afim empena dentro de cada quad em
## proporcao ao tamanho dele (ART-BIBLE secao 4), e um plano de 29 m de largura
## visto rasante — que e exatamente como se ve o chao de uma mata — sai com a
## textura escorrendo. As colunas ficam mais largas conforme se afastam porque
## a distorcao que importa e a do que esta perto.
const COLUNAS_CHAO := [3.1, 5.5, 8.5, 12.5, 18.0, ALCANCE_MATA]

## Quanto o terreno sobe por metro afastado do leito. E o barranco do corte: uma
## estrada de terra na mata quase nunca esta no nivel dela, e sim uns palmos
## abaixo. Sem isso a mata parece flutuar ao lado da pista.
const BARRANCO := 0.085
## Teto do barranco. Sem ele a mata a trinta metros estaria tres metros acima da
## pista e o corredor viraria um desfiladeiro.
const BARRANCO_MAX := 1.35

var semente: int = 20260908
## Clima ativo da cena (noite/amanhecer/dia/entardecer).
var clima_id: String = "entardecer"

var _trechos: Dictionary[int, Node3D] = {}
var _materiais: Dictionary[StringName, ShaderMaterial] = {}
## Ultimo indice de trecho em que o carro estava. -9999 forca a primeira carga.
var _indice: int = -9999

## Quantos triangulos existem de pe agora. So diagnostico.
var triangulos: int = 0


# --- caminho ----------------------------------------------------------------

## Onde a linha do meio da estrada esta, a `s` metros do comeco.
static func ponto_em(s: float) -> Vector3:
	var x := 0.0
	for c: Dictionary in CURVA:
		x += float(c["amp"]) * sin(s / float(c["onda"]) + float(c["fase"]))
	var y := 0.0
	for r: Dictionary in RELEVO:
		y += float(r["amp"]) * sin(s / float(r["onda"]) + float(r["fase"]))
	return Vector3(x, y, -s)


## Para onde a estrada aponta em `s`. Sai da derivada da propria funcao do
## caminho, e nao da diferenca entre dois pontos: com diferenca finita, o passo
## de amostragem entra na conta e a camera de dentro do carro treme junto com
## ele em toda curva.
static func direcao_em(s: float) -> Vector3:
	var dx := 0.0
	for c: Dictionary in CURVA:
		var onda := float(c["onda"])
		dx += float(c["amp"]) / onda * cos(s / onda + float(c["fase"]))
	var dy := 0.0
	for r: Dictionary in RELEVO:
		var onda := float(r["onda"])
		dy += float(r["amp"]) / onda * cos(s / onda + float(r["fase"]))
	return Vector3(dx, dy, -1.0).normalized()


## O vetor unitario que aponta para a DIREITA de quem dirige, no plano.
##
## No plano, e nao no espaco: se o lado acompanhasse a subida da lombada, a
## secao transversal da estrada sairia inclinada e o leito viraria uma rampa
## lateral em toda ladeira.
static func lado_em(s: float) -> Vector3:
	var d := direcao_em(s)
	var plano := Vector3(d.x, 0.0, d.z)
	if plano.length_squared() < 0.000001:
		return Vector3.RIGHT
	return plano.normalized().cross(Vector3.UP).normalized()


## Uma amostra do caminho, para quem precisa da linha inteira — o minimapa.
static func caminho(de: float, ate: float, passo: float) -> PackedVector3Array:
	var saida := PackedVector3Array()
	var s := de
	while s <= ate:
		saida.append(ponto_em(s))
		s += passo
	return saida


# --- esteira ----------------------------------------------------------------

## Poe de pe os trechos em volta de `s` e derruba os que ficaram para tras.
##
## Chamada todo quadro pelo carro. Sai barata quando nao ha o que fazer: o unico
## trabalho no caso comum e uma divisao e uma comparacao de inteiro.
func atualizar(s: float) -> void:
	var i := floori(s / TRECHO)
	if i == _indice:
		return
	_indice = i
	for k in range(i - ATRAS, i + ADIANTE + 1):
		if not _trechos.has(k):
			_trechos[k] = _montar_trecho(k)
	for k: int in _trechos.keys():
		if k < i - ATRAS or k > i + ADIANTE:
			var no := _trechos[k]
			_trechos.erase(k)
			if is_instance_valid(no):
				triangulos -= int(no.get_meta(&"triangulos", 0))
				no.queue_free()


## Monta tudo de uma vez, do trecho 0 ate `ate` metros. Serve a inspecao, que
## precisa da estrada inteira parada para fotografar de cima.
func montar_tudo(ate: float) -> void:
	for k in range(0, ceili(ate / TRECHO) + 1):
		if not _trechos.has(k):
			_trechos[k] = _montar_trecho(k)


func _montar_trecho(indice: int) -> Node3D:
	var rng := RandomNumberGenerator.new()
	# A semente sai do indice, e nao de um contador. E o que faz o trecho 7 ser
	# sempre o mesmo trecho 7, montado na ida, na volta ou numa captura solta —
	# sem isso a mesma cena sairia diferente em duas gravacoes e nao daria para
	# comparar captura com captura.
	rng.seed = absi(semente * 2654435761 + indice * 83492791)

	var sup: Dictionary = {}
	var s0 := float(indice) * TRECHO
	_leito_e_chao(sup, s0, rng)
	_mata(sup, s0, rng)
	_detalhes(sup, s0, rng)

	var no := Node3D.new()
	no.name = "trecho_%03d" % indice
	var tris := 0
	for material: StringName in sup:
		var d: Dictionary = sup[material]
		if PSXMesh.dados_vazio(d):
			continue
		var mi := MeshInstance3D.new()
		mi.name = String(material)
		mi.mesh = PSXMesh.dados_para_mesh(d)
		mi.material_override = _material(material)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		no.add_child(mi)
		tris += PSXMesh.dados_triangulos(d)
	no.set_meta(&"triangulos", tris)
	triangulos += tris
	add_child(no)
	return no


func _material(nome: StringName) -> ShaderMaterial:
	if _materiais.has(nome):
		return _materiais[nome]
	var caminho_mat := MAT_DIR % nome
	if not ResourceLoader.exists(caminho_mat):
		push_error("EstradaBuilder: material ausente em %s" % caminho_mat)
		return null
	var m := load(caminho_mat) as ShaderMaterial
	_materiais[nome] = m
	return m


# --- conteudo do trecho -----------------------------------------------------

## Quanto o chao da mata esta acima do leito, a `d` metros do eixo.
static func altura_lateral(d: float) -> float:
	return minf(absf(d) * BARRANCO, BARRANCO_MAX)


func _leito_e_chao(sup: Dictionary, s0: float, rng: RandomNumberGenerator) -> void:
	for i in PASSOS_POR_TRECHO:
		var sa := s0 + float(i) * PASSO
		var sb := sa + PASSO
		var pa := ponto_em(sa)
		var pb := ponto_em(sb)
		var la := lado_em(sa)
		var lb := lado_em(sb)

		# O desgaste do leito anda em onda longa: trechos de barro fundo e
		# trechos secos se alternando a cada quinze metros. Sem isso a estrada
		# inteira tem exatamente o mesmo tom do comeco ao fim, e o olho le a
		# repeticao antes de ler a estrada.
		var desgaste := 0.5 + 0.5 * sin(sa / 15.0 + 0.7)
		KitEstrada.leito(sup, pa, la, pb, lb, desgaste)

		# O chao da mata dos dois lados, em colunas que sobem o barranco.
		for s: float in [-1.0, 1.0]:
			for k in COLUNAS_CHAO.size() - 1:
				var d0: float = COLUNAS_CHAO[k] * s
				var d1: float = COLUNAS_CHAO[k + 1] * s
				var y0 := Vector3(0.0, altura_lateral(d0), 0.0)
				var y1 := Vector3(0.0, altura_lateral(d1), 0.0)
				# A ordem dos cantos inverte junto com o lado, senao a metade
				# esquerda da mata nasce com a face virada para o chao e some.
				var a := pa + la * d0 + y0
				var b := pa + la * d1 + y1
				var c := pb + lb * d1 + y1
				var e := pb + lb * d0 + y0
				var tom := 0.86 - float(k) * 0.06 + rng.randf_range(-0.04, 0.04)
				var cor := Color(tom, tom * 0.98, tom * 0.9)
				if s > 0.0:
					KitEstrada.quad(sup, KitEstrada.M_LEITO, a, b, c, e,
						KitEstrada.C_FOLHICO, cor)
				else:
					KitEstrada.quad(sup, KitEstrada.M_LEITO, b, a, e, c,
						KitEstrada.C_FOLHICO, cor)

		KitEstrada.beira(sup, pa, la, rng, 12)

	# Uma ou duas pocas de barro por trecho, sempre dentro de uma trilha: e la
	# que a agua fica, porque e o unico lugar que o pneu cavou.
	for _i in rng.randi_range(1, 2):
		var s := s0 + rng.randf_range(0.0, TRECHO)
		var lado := KitEstrada.TRILHA * (1.0 if rng.randf() < 0.5 else -1.0)
		KitEstrada.poca(sup, ponto_em(s) + lado_em(s) * lado, lado_em(s),
			direcao_em(s), Vector2(rng.randf_range(0.7, 1.1),
				rng.randf_range(1.4, 2.6)))


## A mata dos dois lados: arvores perto, massa de folha longe.
func _mata(sup: Dictionary, s0: float, rng: RandomNumberGenerator) -> void:
	# Onde ja ha copa, para nao plantar duas arvores no mesmo lugar. Guardar so
	# o que foi plantado NESTE trecho basta: duas arvores de trechos vizinhos
	# ficam a 28 m uma da outra na pior das hipoteses.
	var ocupado: Array[Vector3] = []
	var raios: Array[float] = []

	for _i in 48:
		var s := s0 + rng.randf_range(-1.0, TRECHO + 1.0)
		var lado := 1.0 if rng.randf() < 0.5 else -1.0
		# Distribuicao puxada para perto: `d` sai de um sorteio elevado ao
		# quadrado, o que poe mais arvore na primeira dezena de metros. E onde
		# elas aparecem inteiras e onde a parede do corredor se forma; longe, a
		# nevoa ja resolve com a massa.
		var t := rng.randf()
		var d := lerpf(RECUO_ARVORE, 26.0, t * t)
		var base := ponto_em(s) + lado_em(s) * (d * lado)
		base.y += altura_lateral(d)

		var raio := lerpf(1.6, 2.8, rng.randf())
		var livre := true
		for k in ocupado.size():
			if base.distance_to(ocupado[k]) < (raio + raios[k]) * 0.62:
				livre = false
				break
		if not livre:
			continue

		var porte := clampf(rng.randf_range(0.2, 1.0) + d * 0.012, 0.0, 1.0)
		var r: float
		if rng.randf() < 0.55:
			r = KitEstrada.conifera(sup, base, porte, rng)
		else:
			r = KitEstrada.arvore(sup, base, porte, rng, rng.randf() < 0.16)
		ocupado.append(base)
		raios.append(r)

		# Arbusto no pe de uma arvore em cada tres. E o que tapa a juncao entre
		# o tronco e o chao, que e por onde se ve o vazio de uma mata gerada.
		if rng.randf() < 0.62:
			KitParque.arbusto(sup, base + Vector3(rng.randf_range(-1.2, 1.2),
				0.0, rng.randf_range(-1.2, 1.2)), rng.randf_range(0.7, 1.3), rng)

	# A parede do fundo: massa de folha a partir de vinte metros, os dois lados.
	for _i in 20:
		var s := s0 + rng.randf_range(0.0, TRECHO)
		var lado := 1.0 if rng.randf() < 0.5 else -1.0
		var d := rng.randf_range(19.0, ALCANCE_MATA - 2.0)
		var base := ponto_em(s) + lado_em(s) * (d * lado)
		base.y += altura_lateral(d)
		KitEstrada.massa(sup, base, rng.randf_range(4.0, 7.5),
			rng.randf_range(7.0, 13.0), rng)


## O que nao e mata nem estrada: o tronco caido, o marco, a cerca.
##
## Nada disto aparece em todo trecho. A conta e a mesma da blitz na abertura da
## cidade: um detalhe que aparece sempre para de ser detalhe e vira parte do
## piso, e o jogador deixa de ver.
func _detalhes(sup: Dictionary, s0: float, rng: RandomNumberGenerator) -> void:
	var indice := int(round(s0 / TRECHO))
	# Trechos da captura (~120 m => indice 4) sempre ganham sujeito no facho.
	var ancora_captura := indice in [3, 4, 5]

	if rng.randf() < 0.40:
		var s := s0 + rng.randf_range(2.0, TRECHO - 2.0)
		var lado := 1.0 if rng.randf() < 0.5 else -1.0
		var d := rng.randf_range(4.5, 8.0)
		var base := ponto_em(s) + lado_em(s) * (d * lado)
		base.y += altura_lateral(d)
		KitEstrada.tronco_caido(sup, base, rng.randf_range(3.5, 6.5),
			rng.randf_range(0.0, TAU), rng)

	if rng.randf() < 0.32:
		var s := s0 + rng.randf_range(2.0, TRECHO - 2.0)
		var lado := 1.0 if rng.randf() < 0.5 else -1.0
		var base := ponto_em(s) + lado_em(s) * (KitEstrada.MEIA_PISTA + 0.6) * lado
		base.y += altura_lateral(KitEstrada.MEIA_PISTA + 0.6)
		KitEstrada.marco(sup, base, atan2(direcao_em(s).x, direcao_em(s).z))

	# Cerca + muro: mais frequentes; forçados na ancora da captura.
	if ancora_captura or rng.randf() < 0.42:
		var s := s0 + rng.randf_range(0.0, TRECHO * 0.45)
		var lado_c := 1.0 if (ancora_captura or rng.randf() < 0.55) else -1.0
		var d := (KitEstrada.MEIA_PISTA + 1.05) * lado_c
		var a := ponto_em(s) + lado_em(s) * d
		var b := ponto_em(s + 14.0) + lado_em(s + 14.0) * d
		a.y += altura_lateral(d)
		b.y += altura_lateral(d)
		KitEstrada.cerca(sup, a, b, rng)
		if lado_c < 0.0 or rng.randf() < 0.5:
			var m0 := ponto_em(s + 1.0) + lado_em(s + 1.0) * (KitEstrada.MEIA_PISTA + 0.9) * -1.0
			var m1 := ponto_em(s + 8.0) + lado_em(s + 8.0) * (KitEstrada.MEIA_PISTA + 0.9) * -1.0
			m0.y += altura_lateral(KitEstrada.MEIA_PISTA + 0.9)
			m1.y += altura_lateral(KitEstrada.MEIA_PISTA + 0.9)
			KitEstrada.muro_baixo(sup, m0, m1, rng)

	# Casinha no facho (direita), ancora da captura ou ocasional.
	if ancora_captura or rng.randf() < 0.28:
		var s := s0 + (10.0 if ancora_captura else rng.randf_range(4.0, TRECHO - 6.0))
		var d := KitEstrada.MEIA_PISTA + 1.15
		var base := ponto_em(s) + lado_em(s) * d
		base.y += altura_lateral(d)
		var giro := atan2(direcao_em(s).x, direcao_em(s).z) + PI * 0.5
		KitEstrada.casa_beira(sup, base, giro, rng)

	# Cipós / galhos pendurados cruzando a pista — densidade da ref 04.
	var n_cipo := 5 if ancora_captura else (3 if rng.randf() < 0.75 else 1)
	for _i in n_cipo:
		var s := s0 + rng.randf_range(0.5, TRECHO - 0.5)
		var lado := 1.0 if rng.randf() < 0.5 else -1.0
		var ancora := ponto_em(s) + lado_em(s) * (lado * rng.randf_range(3.0, 5.5))
		ancora.y += altura_lateral(4.0) + rng.randf_range(2.8, 5.2)
		var sobre := ponto_em(s + rng.randf_range(-1.2, 1.2)) + lado_em(s) * (lado * rng.randf_range(-1.0, 0.6))
		sobre.y += rng.randf_range(1.9, 3.4)
		KitEstrada.cipo(sup, ancora, sobre, rng)


## Olhos vermelhos na nevoa a frente do carro (beat de horror da ref 04).
## Chamado pela AberturaEstrada na captura / noite.
func spawn_olhos_nevoa(s_carro: float, frente: float = 28.0) -> void:
	var velho := get_node_or_null("OlhosNevoa")
	if velho != null:
		velho.queue_free()
	var raiz := Node3D.new()
	raiz.name = "OlhosNevoa"
	# Um pouco mais perto + levemente a direita da pista: legivel no FP e
	# ainda um ponto vermelho no TP atras do carro.
	var s := s_carro + maxf(18.0, frente * 0.85)
	var p := ponto_em(s) + lado_em(s) * 0.25
	var dir := direcao_em(s)
	p += Vector3(0.0, 1.25, 0.0)
	raiz.position = p
	add_child(raiz)
	for sx: float in [-0.2, 0.2]:
		# Sem OmniLight forte: bloom do emission ja basta e Omni alto
		# virava bolhao vermelho no FP (lavava a casinha do facho).
		var mi := MeshInstance3D.new()
		var esfera := SphereMesh.new()
		esfera.radius = 0.09
		esfera.height = 0.18
		esfera.radial_segments = 6
		esfera.rings = 3
		mi.mesh = esfera
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.08, 0.02)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.04, 0.0)
		mat.emission_energy_multiplier = 3.8
		mi.material_override = mat
		mi.position = Vector3(sx, 0.0, 0.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		raiz.add_child(mi)
	# Face o carro (olhos olhando de frente).
	raiz.basis = Basis.looking_at(-dir, Vector3.UP)


## Garante casa + cerca + muro no cone do farol na distancia de captura.
## Nao depende de RNG do trecho: o facho sempre tem sujeito (ref 04).
func garantir_props_facho(s_carro: float) -> void:
	var velho := get_node_or_null("PropsFacho")
	if velho != null:
		velho.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(semente * 17 + int(s_carro) * 31)
	var sup: Dictionary = {}
	# Casa DENTRO do cone: ~7–9 m a frente, rente a beira direita.
	var s := s_carro + 9.5
	var d_casa := KitEstrada.MEIA_PISTA + 1.25
	var base := ponto_em(s) + lado_em(s) * d_casa
	base.y += altura_lateral(d_casa)
	# Fachada olhando a pista (nao o mato).
	var giro := atan2(direcao_em(s).x, direcao_em(s).z) + PI * 0.5
	KitEstrada.casa_beira(sup, base, giro, rng)
	# Cerca a direita, entre o carro e a casa — no facho.
	var d_c := KitEstrada.MEIA_PISTA + 0.85
	var a := ponto_em(s - 3.5) + lado_em(s - 3.5) * d_c
	var b := ponto_em(s + 7.0) + lado_em(s + 7.0) * d_c
	a.y += altura_lateral(d_c)
	b.y += altura_lateral(d_c)
	KitEstrada.cerca(sup, a, b, rng)
	# Segundo tramo curto colado na casa (ref 04: cerca + casinha).
	var a2 := ponto_em(s - 0.5) + lado_em(s - 0.5) * (d_casa - 0.35)
	var b2 := ponto_em(s + 4.5) + lado_em(s + 4.5) * (d_casa - 0.35)
	a2.y += altura_lateral(d_casa - 0.35)
	b2.y += altura_lateral(d_casa - 0.35)
	KitEstrada.cerca(sup, a2, b2, rng)
	# Muro baixo a esquerda (contraste no facho esquerdo).
	var d_m := -(KitEstrada.MEIA_PISTA + 0.85)
	var m0 := ponto_em(s - 2.0) + lado_em(s - 2.0) * d_m
	var m1 := ponto_em(s + 6.0) + lado_em(s + 6.0) * d_m
	m0.y += altura_lateral(absf(d_m))
	m1.y += altura_lateral(absf(d_m))
	KitEstrada.muro_baixo(sup, m0, m1, rng)
	# Cipós baixos cruzando o para-brisa (y ~2.0–2.8 no eixo).
	for i in 6:
		var sc := s_carro + 2.5 + float(i) * 2.2
		var lado := 1.0 if i % 2 == 0 else -1.0
		var ancora := ponto_em(sc) + lado_em(sc) * (lado * rng.randf_range(3.2, 4.8))
		ancora.y += altura_lateral(4.0) + rng.randf_range(2.6, 4.2)
		var sobre := ponto_em(sc + rng.randf_range(-0.8, 0.8)) + lado_em(sc) * (lado * rng.randf_range(-1.2, 0.4))
		sobre.y += rng.randf_range(1.85, 2.85)
		KitEstrada.cipo(sup, ancora, sobre, rng)
	# Brush densificado na beira — mesma densidade FP/TP no cone.
	for i in 18:
		var sb := s_carro + rng.randf_range(2.0, 14.0)
		var lado := 1.0 if rng.randf() < 0.58 else -1.0
		var d := rng.randf_range(KitEstrada.MEIA_PISTA - 0.35, KitEstrada.MEIA_PISTA + 1.8)
		var pp := ponto_em(sb) + lado_em(sb) * (d * lado)
		pp.y += altura_lateral(d)
		KitEstrada.tufo(sup, pp,
			[KitEstrada.C_CAPIM, KitEstrada.C_SAMAMBAIA, KitEstrada.C_MOITA_BAIXA,
				KitEstrada.C_FOLHA_LARGA, KitEstrada.C_GALHO_SECO][rng.randi() % 5],
			rng.randf_range(0.8, 1.6), rng.randf_range(0.0, TAU),
			Color(0.82, 0.88, 0.68))
	# Arbustos extras no pe da casa (direita).
	for i in 4:
		var ang := rng.randf_range(-0.9, 0.9)
		var d := rng.randf_range(1.5, 2.6)
		var off := lado_em(s) * (d_casa + 0.2) + direcao_em(s) * (rng.randf_range(-1.5, 2.0))
		var bp := ponto_em(s) + off
		bp.y += altura_lateral(d_casa)
		KitParque.arbusto(sup, bp, rng.randf_range(0.85, 1.35), rng)
	var no := Node3D.new()
	no.name = "PropsFacho"
	var tris := 0
	for material: StringName in sup:
		var d: Dictionary = sup[material]
		if PSXMesh.dados_vazio(d):
			continue
		var mi := MeshInstance3D.new()
		mi.name = String(material)
		mi.mesh = PSXMesh.dados_para_mesh(d)
		mi.material_override = _material(material)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		no.add_child(mi)
		tris += PSXMesh.dados_triangulos(d)
	no.set_meta(&"triangulos", tris)
	triangulos += tris
	add_child(no)
