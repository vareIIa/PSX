## Kit modular da cidade. Pecas na grade de 2 m, em dados brutos.
##
## Nenhuma funcao aqui toca no servidor de renderizacao: tudo devolve ou preenche
## dicionario de arrays. Isso e o que permite montar um chunk inteiro dentro de
## uma thread de trabalho e deixar so a criacao da malha na thread principal.
##
## As pecas escrevem num acumulador indexado por material, e nao devolvem malha
## solta. Um chunk com sessenta pecas vira meia duzia de malhas em vez de sessenta
## MeshInstance3D, que e a diferenca entre caber e nao caber no teto de draw calls
## do ART-BIBLE secao 10.
##
## Regras do kit, da skill psx-city: tudo em multiplos de 2 m, chao e parede
## subdivididos por causa da UV afim, e nenhuma peca fora desta lista antes da
## Fase 4 fechar.
class_name KitModular
extends RefCounted

# --- medidas canonicas ------------------------------------------------------

## Lado do chunk. ART-BIBLE e skill psx-city.
const CHUNK := 32.0
## Meia largura da rua. A outra metade e do chunk vizinho.
const MEIA_RUA := 3.0
const CALCADA := 2.5
const ALTURA_MEIO_FIO := 0.16
const ALTURA_ANDAR := 3.0
## Onde a fachada comeca, medido da borda do chunk.
const RECUO := MEIA_RUA + CALCADA

# Cache de primitivas. Preenchido em preparar(), so lido depois disso, o que
# dispensa mutex nas threads de trabalho.
static var _cache: Dictionary = {}
static var _pronto: bool = false


## Gera as primitivas mais usadas antes de qualquer thread comecar.
## Chame uma vez, na thread principal.
static func preparar() -> void:
	if _pronto:
		return
	for l: float in [2.0, 2.5, 3.0, 4.0, 6.0, 8.0, 10.0, 12.0, 26.5, 32.0]:
		for a: float in [1.3, 2.2, 2.5, 3.0, 6.0, 9.0, 12.0, 26.5, 32.0]:
			_quad(l, a)
	_caixa(Vector3(0.22, 7.0, 0.22))
	_caixa(Vector3(1.1, 1.9, 0.7))
	_caixa(Vector3(1.5, 0.1, 0.1))
	_pronto = true


static func _quad(largura: float, altura: float) -> Dictionary:
	var chave := "q%.2fx%.2f" % [largura, altura]
	if _cache.has(chave):
		return _cache[chave]
	var d := PSXMesh.plane_dados(Vector2(largura, altura))
	# Fora da lista pre-aquecida nao guarda: escrever no cache de dentro de uma
	# thread criaria corrida. Gerar de novo custa pouco e nunca corrompe.
	if not _pronto:
		_cache[chave] = d
	return d


static func _caixa(tamanho: Vector3, faces: int = PSXMesh.FACE_TODAS) -> Dictionary:
	var chave := "b%.2f_%.2f_%.2f_%d" % [tamanho.x, tamanho.y, tamanho.z, faces]
	if _cache.has(chave):
		return _cache[chave]
	var d := PSXMesh.box_dados(tamanho, 0.8, PSXMesh.MAX_QUAD_M, Color.WHITE, faces)
	if not _pronto:
		_cache[chave] = d
	return d


# --- acumulador por material ------------------------------------------------

## Adiciona geometria ao balde do material dado.
static func por(saida: Dictionary, material: StringName,
		dados: Dictionary, xform: Transform3D) -> void:
	if not saida.has(material):
		saida[material] = PSXMesh.dados_vazios()
	PSXMesh.acumular(saida[material], dados, xform)


## Plano deitado no chao, virado para cima, com canto em `canto`.
static func chao(saida: Dictionary, material: StringName,
		canto: Vector3, tamanho: Vector2) -> void:
	var centro := canto + Vector3(tamanho.x * 0.5, 0.0, tamanho.y * 0.5)
	por(saida, material, _quad(tamanho.x, tamanho.y),
		Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), centro))


## Parede vertical. `direcao` e para onde a face olha: 0 = -Z, 1 = +X, 2 = +Z, 3 = -X.
static func parede(saida: Dictionary, material: StringName,
		centro: Vector3, tamanho: Vector2, direcao: int) -> void:
	por(saida, material, _quad(tamanho.x, tamanho.y),
		Transform3D(Basis(Vector3.UP, PI * 0.5 * float(direcao)), centro))


## Parede em angulo livre. `giro` e a rotacao em Y que leva o +Z do plano para a
## normal desejada. As quatro direcoes cardeais tem `parede`; isto e para o
## interior, onde a planta nao precisa ser ortogonal.
static func parede_livre(saida: Dictionary, material: StringName,
		centro: Vector3, tamanho: Vector2, giro: float,
		cor: Color = Color.WHITE) -> void:
	if not saida.has(material):
		saida[material] = PSXMesh.dados_vazios()
	PSXMesh.acumular_tingido(saida[material], _quad(tamanho.x, tamanho.y),
		Transform3D(Basis(Vector3.UP, giro), centro), cor)


## Trecho de parede entre dois pontos no plano XZ, pulando vaos de porta.
##
## `vaos` sao pares de distancia ao longo do segmento, medidos a partir de `a`.
## Acima de cada vao entra uma verga, senao a porta vira um rasgo ate o teto.
static func parede_com_vaos(saida: Dictionary, material: StringName,
		a: Vector2, b: Vector2, altura: float,
		vaos: Array = [], altura_vao: float = 2.05,
		cor: Color = Color.WHITE, rodape: float = 0.0) -> void:
	var delta := b - a
	var comprimento := delta.length()
	if comprimento < 0.01:
		return
	var dir := delta / comprimento
	# Normal a esquerda do sentido de caminhada, ou seja dir girado -90 graus no
	# plano XZ: normal = (-dir.z, dir.x). Percorrer o comodo no sentido anti
	# horario visto de cima deixa todas as normais apontando para dentro.
	#
	# O giro que leva o +Z do plano ate essa normal e atan2(-dir.z, dir.x).
	var giro := atan2(-dir.y, dir.x)

	var cortes: Array = []
	for v: Vector2 in vaos:
		cortes.append(Vector2(clampf(v.x, 0.0, comprimento), clampf(v.y, 0.0, comprimento)))
	cortes.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)

	# O rodape come a base da parede e entra como faixa escura por cima. E um
	# detalhe barato de altissimo retorno: sem ele a parede encontra o chao numa
	# aresta limpa que nenhum comodo real tem.
	var base := rodape

	var cursor := 0.0
	for corte: Vector2 in cortes:
		if corte.x > cursor:
			_trecho(saida, material, a, dir, cursor, corte.x, base, altura - base, giro, cor)
			if rodape > 0.0:
				_trecho(saida, &"tabua", a, dir, cursor, corte.x, 0.0, rodape, giro,
					Color(0.55, 0.5, 0.44))
		if altura > altura_vao:
			_trecho(saida, material, a, dir, corte.x, corte.y,
				altura_vao, altura - altura_vao, giro, cor)
		cursor = maxf(cursor, corte.y)

	if cursor < comprimento:
		_trecho(saida, material, a, dir, cursor, comprimento, base, altura - base, giro, cor)
		if rodape > 0.0:
			_trecho(saida, &"tabua", a, dir, cursor, comprimento, 0.0, rodape, giro,
				Color(0.55, 0.5, 0.44))


static func _trecho(saida: Dictionary, material: StringName, a: Vector2, dir: Vector2,
		de: float, ate: float, base: float, altura: float, giro: float,
		cor: Color = Color.WHITE) -> void:
	var comp := ate - de
	if comp < 0.02 or altura < 0.02:
		return
	var meio := a + dir * (de + comp * 0.5)
	parede_livre(saida, material, Vector3(meio.x, base + altura * 0.5, meio.y),
		Vector2(comp, altura), giro, cor)


static func caixa(saida: Dictionary, material: StringName,
		centro: Vector3, tamanho: Vector3, giro: float = 0.0,
		faces: int = PSXMesh.FACE_TODAS) -> void:
	por(saida, material, _caixa(tamanho, faces),
		Transform3D(Basis(Vector3.UP, giro), centro))


## Caixa tingida por vertice. O shader multiplica ALBEDO pela cor, entao a mesma
## tabua vira sofa marrom, tapete vermelho e lombada de livro sem custar uma
## textura nova. Numa tela de 480x270 a cor faz quase todo o trabalho que a
## textura faria, e cada material a mais e um lote de desenho a mais.
static func caixa_cor(saida: Dictionary, material: StringName,
		centro: Vector3, tamanho: Vector3, cor: Color, giro: float = 0.0,
		faces: int = PSXMesh.FACE_TODAS) -> void:
	if not saida.has(material):
		saida[material] = PSXMesh.dados_vazios()
	PSXMesh.acumular_tingido(saida[material], _caixa(tamanho, faces),
		Transform3D(Basis(Vector3.UP, giro), centro), cor)


# --- pecas ------------------------------------------------------------------

## Faixa de asfalto.
static func rua(saida: Dictionary, canto: Vector3, tamanho: Vector2,
		remendo: bool = false) -> void:
	chao(saida, &"asfalto_remendo" if remendo else &"asfalto", canto, tamanho)


## Calcada elevada mais a face vertical do meio-fio.
## `dir_meio_fio` aponta para a rua, no mesmo esquema de `parede`.
static func calcada(saida: Dictionary, canto: Vector3, tamanho: Vector2,
		dir_meio_fio: int, comprimento_meio_fio: float) -> void:
	chao(saida, &"calcada", canto + Vector3(0.0, ALTURA_MEIO_FIO, 0.0), tamanho)

	# A face do meio-fio fica na borda voltada para a rua.
	var meio := canto + Vector3(tamanho.x * 0.5, ALTURA_MEIO_FIO * 0.5, tamanho.y * 0.5)
	match dir_meio_fio:
		3: meio.x = canto.x
		1: meio.x = canto.x + tamanho.x
		0: meio.z = canto.z
		_: meio.z = canto.z + tamanho.y
	parede(saida, &"meio_fio", meio,
		Vector2(comprimento_meio_fio, ALTURA_MEIO_FIO), dir_meio_fio)


## Fachada de um predio, com terreo, janelas e letreiro.
##
## `centro` fica na base, no meio da largura. `direcao` e para onde a fachada
## olha. A massa do predio nao vem daqui: quem monta a quadra fecha o volume.
static func fachada(saida: Dictionary, centro: Vector3, largura: float,
		andares: int, direcao: int, material: StringName,
		rng: RandomNumberGenerator, prob_loja: float = 0.55,
		prob_janela_acesa: float = 0.32) -> void:
	var altura := andares * ALTURA_ANDAR
	var normal := _normal(direcao)
	var lateral := _lateral(direcao)

	parede(saida, material, centro + Vector3(0.0, altura * 0.5, 0.0),
		Vector2(largura, altura), direcao)

	# Terreo em vaos, nao numa chapa unica. Uma vitrine de 12 m de largura vira um
	# retangulo branco aceso do tamanho do predio, que le como erro de material e
	# nao como loja. Vao de 2,5 m com pilar entre eles e o que uma rua comercial
	# tem de verdade, e ainda deixa a fachada aparecer entre um e outro.
	var tem_loja := rng.randf() < prob_loja
	var frente := centro + normal * 0.06
	var mat_terreo: StringName = &"vitrine" if tem_loja else &"metal_ondulado"
	var vaos := maxi(1, int(largura / 3.2))
	var passo := largura / float(vaos)
	for k in vaos:
		var deslocamento := (float(k) - float(vaos - 1) * 0.5) * passo
		parede(saida, mat_terreo,
			frente + Vector3(0.0, 1.25, 0.0) + lateral * deslocamento,
			Vector2(passo * 0.7, 2.1), direcao)

	if tem_loja:
		parede(saida, &"letreiro", frente + Vector3(0.0, 3.4, 0.0) + lateral * (largura * 0.32),
			Vector2(0.55, 2.4), direcao)

	for andar in range(1, andares):
		var y := andar * ALTURA_ANDAR + 1.5
		var n := maxi(1, int(largura / 2.6))
		for j in n:
			var off := (float(j) - float(n - 1) * 0.5) * 2.6
			parede(saida,
				&"janela_acesa" if rng.randf() < prob_janela_acesa else &"janela_apagada",
				frente + Vector3(0.0, y, 0.0) + lateral * off,
				Vector2(1.1, 1.3), direcao)


## Muro baixo fechando um terreno baldio.
static func muro(saida: Dictionary, canto: Vector3, comprimento: float,
		direcao: int, altura: float = 1.8) -> void:
	var lateral := _lateral(direcao)
	parede(saida, &"concreto_sujo",
		canto + lateral * (comprimento * 0.5) + Vector3(0.0, altura * 0.5, 0.0),
		Vector2(comprimento, altura), direcao)


## Corpo do poste. A lampada em si e um no, nao geometria fundida.
static func poste(saida: Dictionary, base: Vector3, dir_braco: Vector3) -> void:
	caixa(saida, &"meio_fio", base + Vector3(0.0, 3.5, 0.0), Vector3(0.22, 7.0, 0.22))
	var giro := atan2(dir_braco.x, dir_braco.z)
	caixa(saida, &"metal", base + Vector3(0.0, 6.6, 0.0) + dir_braco * 0.75,
		Vector3(1.5, 0.1, 0.1), giro + PI * 0.5)


## Corpo e vitrine da maquina de venda.
static func maquina_venda(saida: Dictionary, base: Vector3, direcao: int) -> void:
	var normal := _normal(direcao)
	caixa(saida, &"metal", base + Vector3(0.0, 0.95, 0.0), Vector3(1.1, 1.9, 0.7),
		PI * 0.5 * float(direcao))
	parede(saida, &"maquina_venda", base + Vector3(0.0, 1.05, 0.0) + normal * 0.37,
		Vector2(0.92, 1.5), direcao)


## Trecho reto de cabo entre dois pontos.
static func cabo(saida: Dictionary, de: Vector3, para: Vector3) -> void:
	var vetor := para - de
	var comp := vetor.length()
	if comp < 0.02:
		return
	var direcao := vetor / comp
	var eixo := Vector3.RIGHT.cross(direcao)
	var base := Basis()
	if eixo.length_squared() > 0.000001:
		base = Basis(eixo.normalized(), Vector3.RIGHT.angle_to(direcao))
	por(saida, &"metal", _caixa(Vector3(comp, 0.06, 0.06)),
		Transform3D(base, de + vetor * 0.5))


## Vao entre dois postes, com tres cabos em parabola.
##
## A curva exata de uma catenaria nao importa numa tela de 480x270: quatro
## segmentos de parabola ja dao a barriga que o olho espera, por um sexto dos
## triangulos.
static func fiacao(saida: Dictionary, a: Vector3, b: Vector3) -> void:
	const SEGMENTOS := 4
	const BARRIGA := 0.9
	for nivel: float in [0.0, -0.35, -0.7]:
		var desloc := Vector3(0.0, nivel, 0.0)
		var anterior := a + desloc
		for seg in range(1, SEGMENTOS + 1):
			var t := float(seg) / float(SEGMENTOS)
			var ponto := (a + desloc).lerp(b + desloc, t)
			ponto.y -= BARRIGA * 4.0 * t * (1.0 - t)
			cabo(saida, anterior, ponto)
			anterior = ponto


# --- utilitarios ------------------------------------------------------------

## Vetor normal de uma direcao de parede.
static func _normal(direcao: int) -> Vector3:
	match posmod(direcao, 4):
		0: return Vector3.BACK
		1: return Vector3.RIGHT
		2: return Vector3.FORWARD
		_: return Vector3.LEFT


## Vetor lateral, ao longo da largura da parede.
static func _lateral(direcao: int) -> Vector3:
	match posmod(direcao, 4):
		0: return Vector3.RIGHT
		1: return Vector3.FORWARD
		2: return Vector3.LEFT
		_: return Vector3.BACK
