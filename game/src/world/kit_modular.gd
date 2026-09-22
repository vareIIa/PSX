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
## Quanto a face do meio-fio desce abaixo do asfalto (ver `calcada`).
const SAIA_MEIO_FIO := 0.06
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


static func _quad(largura: float, altura: float,
		max_quad: float = PSXMesh.MAX_QUAD_M) -> Dictionary:
	var chave := "q%.2fx%.2f_%.1f" % [largura, altura, max_quad]
	if _cache.has(chave):
		return _cache[chave]
	var d := PSXMesh.plane_dados(Vector2(largura, altura),
		PSXMesh.DEFAULT_UV_PER_M, max_quad)
	# Fora da lista pre-aquecida nao guarda: escrever no cache de dentro de uma
	# thread criaria corrida. Gerar de novo custa pouco e nunca corrompe.
	if not _pronto:
		_cache[chave] = d
	return d


static func _caixa(tamanho: Vector3, faces: int = PSXMesh.FACE_TODAS,
		max_quad: float = PSXMesh.MAX_QUAD_M) -> Dictionary:
	var chave := "b%.2f_%.2f_%.2f_%d_%.1f" % [tamanho.x, tamanho.y, tamanho.z,
		faces, max_quad]
	if _cache.has(chave):
		return _cache[chave]
	var d := PSXMesh.box_dados(tamanho, 0.8, max_quad, Color.WHITE, faces)
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
##
## `max_quad` folgado serve a superficie que ninguem chega perto — o patio
## fechado no meio da quadra e um plano de 26 m que so aparece por uma fresta, e
## subdividi-lo na grade padrao custaria 338 triangulos para nada.
static func chao(saida: Dictionary, material: StringName,
		canto: Vector3, tamanho: Vector2,
		max_quad: float = PSXMesh.MAX_QUAD_M,
		cor: Color = Color.WHITE) -> void:
	if not saida.has(material):
		saida[material] = PSXMesh.dados_vazios()
	var centro := canto + Vector3(tamanho.x * 0.5, 0.0, tamanho.y * 0.5)
	PSXMesh.acumular_tingido(saida[material], _quad(tamanho.x, tamanho.y, max_quad),
		Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), centro), cor)


## Parede vertical. `direcao` e para onde a face olha: 0 = +Z, 1 = +X, 2 = -Z,
## 3 = -X — o mesmo de `_normal`. (Este comentario dizia 0 = -Z, e o meio-fio de
## calcada acreditou nele.)
static func parede(saida: Dictionary, material: StringName,
		centro: Vector3, tamanho: Vector2, direcao: int,
		cor: Color = Color.WHITE) -> void:
	parede_livre(saida, material, centro, tamanho, PI * 0.5 * float(direcao), cor)


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
		faces: int = PSXMesh.FACE_TODAS,
		max_quad: float = PSXMesh.MAX_QUAD_M) -> void:
	por(saida, material, _caixa(tamanho, faces, max_quad),
		Transform3D(Basis(Vector3.UP, giro), centro))


## Caixa com orientacao livre, e nao so giro em Y.
##
## O giro em Y sozinho nao inclina nada, e meia duzia de pecas precisam disso:
## a perna em A do balanco, a rampa do escorregador, o beiral de telhado. Sem
## isto elas sairiam em pe, o que le como erro de montagem.
static func caixa_livre(saida: Dictionary, material: StringName,
		centro: Vector3, tamanho: Vector3, base: Basis,
		cor: Color = Color.WHITE,
		max_quad: float = PSXMesh.MAX_QUAD_M) -> void:
	if not saida.has(material):
		saida[material] = PSXMesh.dados_vazios()
	PSXMesh.acumular_tingido(saida[material],
		_caixa(tamanho, PSXMesh.FACE_TODAS, max_quad),
		Transform3D(base, centro), cor)


## Registra a caixa de colisao que cobre um movel girado.
##
## As formas de colisao de interior nao guardam rotacao: quem materializa cria
## BoxShape3D com posicao e mais nada. Entao um movel girado precisa da caixa
## envolvente alinhada aos eixos, calculada aqui.
##
## Sem isso a estante virada de lado ganha um bloco invisivel de um metro
## atravessado na sala, e o jogador esbarra no nada a meio metro do movel.
static func solido(colisao: Array[Dictionary], centro: Vector3,
		tamanho: Vector3, giro: float = 0.0) -> void:
	var c := absf(cos(giro))
	var s := absf(sin(giro))
	colisao.append({
		"tamanho": Vector3(tamanho.x * c + tamanho.z * s, tamanho.y,
			tamanho.x * s + tamanho.z * c),
		"pos": centro,
	})


## Placa vertical em angulo livre: a imagem cabe inteira, sem repetir.
##
## Mesma orientacao de `parede_livre`. Usa PSXMesh.placa_dados, entao serve para
## letreiro, cartaz e fachada de prateleira, onde a textura e uma imagem e nao
## uma superficie que se repete.
## `max_quad` menor subdivide mais. Importa aqui mais do que em parede: a UV
## afim empena a imagem dentro de cada quad, e num painel de tres metros e meio
## com dois quads a fileira de prateleira sai visivelmente torta, como se o
## movel estivesse derretendo. Subdividir e como o PS1 resolvia isso.
static func placa(saida: Dictionary, material: StringName,
		centro: Vector3, tamanho: Vector2, giro: float,
		cor: Color = Color.WHITE, max_quad: float = PSXMesh.MAX_QUAD_M) -> void:
	if not saida.has(material):
		saida[material] = PSXMesh.dados_vazios()
	PSXMesh.acumular_tingido(saida[material],
		PSXMesh.placa_dados(tamanho, max_quad),
		Transform3D(Basis(Vector3.UP, giro), centro), cor)


## Caixa tingida por vertice. O shader multiplica ALBEDO pela cor, entao a mesma
## tabua vira sofa marrom, tapete vermelho e lombada de livro sem custar uma
## textura nova. Numa tela de 480x270 a cor faz quase todo o trabalho que a
## textura faria, e cada material a mais e um lote de desenho a mais.
static func caixa_cor(saida: Dictionary, material: StringName,
		centro: Vector3, tamanho: Vector3, cor: Color, giro: float = 0.0,
		faces: int = PSXMesh.FACE_TODAS,
		max_quad: float = PSXMesh.MAX_QUAD_M) -> void:
	if not saida.has(material):
		saida[material] = PSXMesh.dados_vazios()
	PSXMesh.acumular_tingido(saida[material], _caixa(tamanho, faces, max_quad),
		Transform3D(Basis(Vector3.UP, giro), centro), cor)


## Caixa que balanca ao vento, com a base mais presa que o topo.
##
## `max_quad` grande de proposito nos chamadores de vegetacao: uma copa de 2,5 m
## subdividida na grade padrao custa quatro vezes mais triangulos e a subdivisao
## nao aparece, porque a textura de folha ja e ruido. Vinte arvores por chunk so
## cabem no orcamento assim.
static func caixa_flex(saida: Dictionary, material: StringName,
		centro: Vector3, tamanho: Vector3, cor: Color, giro: float,
		y_base: float, y_topo: float,
		rigidez_base: float = 0.0, rigidez_topo: float = 1.0,
		faces: int = PSXMesh.FACE_TODAS,
		max_quad: float = 4.0) -> void:
	if not saida.has(material):
		saida[material] = PSXMesh.dados_vazios()
	PSXMesh.acumular_flexivel(saida[material], _caixa(tamanho, faces, max_quad),
		Transform3D(Basis(Vector3.UP, giro), centro), cor,
		y_base, y_topo, rigidez_base, rigidez_topo)


## Caixa inclinada, com a rigidez ao vento variando na altura. E o galho: sai do
## tronco torto e a ponta e a parte que anda.
static func caixa_flex_inclinada(saida: Dictionary, material: StringName,
		centro: Vector3, tamanho: Vector3, cor: Color, base: Basis,
		y_base: float, y_topo: float,
		rigidez_base: float = 0.0, rigidez_topo: float = 1.0,
		max_quad: float = 4.0) -> void:
	if not saida.has(material):
		saida[material] = PSXMesh.dados_vazios()
	PSXMesh.acumular_flexivel(saida[material],
		_caixa(tamanho, PSXMesh.FACE_TODAS, max_quad),
		Transform3D(base, centro), cor, y_base, y_topo,
		rigidez_base, rigidez_topo)


# --- pecas ------------------------------------------------------------------

## Faixa de asfalto.
static func rua(saida: Dictionary, canto: Vector3, tamanho: Vector2,
		remendo: bool = false, material: StringName = &"asfalto") -> void:
	if material != &"asfalto":
		# Pedra nao leva remendo de asfalto: o remendo e da rua asfaltada.
		chao(saida, material, canto, tamanho)
		return
	chao(saida, &"asfalto_remendo" if remendo else &"asfalto", canto, tamanho)


## Calcada elevada mais a face vertical do meio-fio.
## `dir_meio_fio` diz em que BORDA fica a rua: 3 = x minimo, 1 = x maximo,
## 0 = z minimo, 2 = z maximo.
##
## Nao e o esquema de `parede`, que em Z e o contrario (0 olha para +Z). O numero
## ia direto para `parede`, e todo meio-fio de calcada do eixo Z saia virado para
## dentro da calcada: visto da rua ele era descartado pelo cull_back e a borda
## inteira abria para o vao debaixo da laje, onde nao ha chao nenhum.
static func calcada(saida: Dictionary, canto: Vector3, tamanho: Vector2,
		dir_meio_fio: int, comprimento_meio_fio: float,
		material: StringName = &"calcada", saia: float = SAIA_MEIO_FIO) -> void:
	chao(saida, material, canto + Vector3(0.0, ALTURA_MEIO_FIO, 0.0), tamanho)

	# A face do meio-fio fica na borda voltada para a rua, e olha para ela. Ela
	# desce SAIA_MEIO_FIO abaixo do asfalto: na ladeira (Relevo) as duas
	# superficies dividem a linha mas nao os vertices, e com altura quebrada a
	# emenda abria fresta de um pixel para o fundo. No plano a saia fica
	# escondida debaixo da rua.
	var meio := canto + Vector3(tamanho.x * 0.5, (ALTURA_MEIO_FIO - saia) * 0.5,
		tamanho.y * 0.5)
	var olha := dir_meio_fio
	match dir_meio_fio:
		3: meio.x = canto.x
		1: meio.x = canto.x + tamanho.x
		0:
			meio.z = canto.z
			olha = 2
		_:
			meio.z = canto.z + tamanho.y
			olha = 0
	parede(saida, &"meio_fio", meio,
		Vector2(comprimento_meio_fio, ALTURA_MEIO_FIO + saia), olha)


## Fachada de um predio, com terreo, janelas e letreiro.
##
## `centro` fica na base, no meio da largura. `direcao` e para onde a fachada
## olha. A massa do predio nao vem daqui: quem monta a quadra fecha o volume.
##
## `cor` e a tinta da quadra, aplicada por vertice. Devolve se o terreo virou
## vitrine, porque quem monta a quadra precisa saber para pendurar o toldo — e
## toldo sobre porta de aco fechada le como erro.
## `porta_local` e a distancia da porta de entrada ao centro do trecho, ao longo
## da fachada, ou NAN quando este trecho nao tem porta. O vao dela fica vazio: um
## painel de terreo sobre a porta a esconde por inteiro, e o jogador passa na
## frente da unica entrada da quadra sem ver que ela existe.
static func fachada(saida: Dictionary, centro: Vector3, largura: float,
		andares: int, direcao: int, material: StringName,
		rng: RandomNumberGenerator, prob_loja: float = 0.55,
		prob_janela_acesa: float = 0.32, cor: Color = Color.WHITE,
		porta_local: float = NAN) -> bool:
	var altura := andares * ALTURA_ANDAR
	var normal := _normal(direcao)
	var lateral := _lateral(direcao)

	parede(saida, material, centro + Vector3(0.0, altura * 0.5, 0.0),
		Vector2(largura, altura), direcao, cor)

	# Terreo em vaos, nao numa chapa unica. Uma vitrine de 12 m de largura vira um
	# retangulo branco aceso do tamanho do predio, que le como erro de material e
	# nao como loja. Vao de 2,5 m com pilar entre eles e o que uma rua comercial
	# tem de verdade, e ainda deixa a fachada aparecer entre um e outro.
	var tem_loja := rng.randf() < prob_loja
	var frente := centro + normal * 0.06
	# Sem loja a rua brasileira NAO e porta de aco. Azulejo e reboco de terreo
	# sao sobrado comercial / sala / deposito de esquina; metal ondulado fica
	# como excecao, senao o comercio inteiro le como galpao.
	var seco := rng.randi_range(0, 2)
	var mat_terreo: StringName = &"vitrine"
	if not tem_loja:
		# Galpao industrial continua de porta de aco. Comercio sem vitrine vira
		# sobrado de azulejo/reboco — senao a rua comercial e um deposito.
		var galpao := material == &"metal_ondulado" or material == &"metal_enferrujado" \
			or material == &"concreto_sujo"
		mat_terreo = &"metal_ondulado" if galpao \
			else [&"azulejo", &"reboco", &"metal_ondulado"][seco]
	var vaos := maxi(1, int(largura / 3.2))
	var passo := largura / float(vaos)
	for k in vaos:
		var deslocamento := (float(k) - float(vaos - 1) * 0.5) * passo
		if is_finite(porta_local) and absf(deslocamento - porta_local) < passo * 0.5 + 0.95:
			continue
		# Loja: um vao em tres vira porta de enrolar (metal), o resto vitrine.
		# E o ritmo de padaria/farmacia, nao de shopping de vidro continuo.
		var mat := mat_terreo
		if tem_loja and k == 0 and vaos >= 2:
			mat = &"metal_ondulado"
		# Vitrine e porta de enrolar ocupam o vao inteiro. Azulejo/reboco no
		# mesmo retangulo de 2,1 m leem como a MESMA porta de aco, so que de
		# tijolo — foi o que a captura da rua comercial mostrou. Sobrado leva
		# janela na altura do olho.
		var eh_vao := mat == &"vitrine" or mat == &"metal_ondulado"
		var tam := Vector2(passo * 0.7, 2.1) if eh_vao else Vector2(passo * 0.42, 1.3)
		var y_vao := 1.25 if eh_vao else 1.45
		parede(saida, mat,
			frente + Vector3(0.0, y_vao, 0.0) + lateral * deslocamento,
			tam, direcao)

	if tem_loja:
		parede(saida, &"letreiro", frente + Vector3(0.0, 3.4, 0.0) + lateral * (largura * 0.32),
			Vector2(0.55, 2.4), direcao)
		# Letreiro deitado, o de rua brasileira. O vertical sozinho some na nevoa
		# como poste; a faixa horizontal e a mancha de cor.
		caixa_cor(saida, &"metal",
			frente + Vector3(0.0, 2.72, 0.0) + lateral * (largura * 0.08),
			Vector3(minf(largura * 0.55, 3.4), 0.42, 0.12),
			Color("c45a3a") if seco == 0 else Color("3a6e54"),
			atan2(normal.x, normal.z))

	var giro_fachada := atan2(normal.x, normal.z)
	# Pingadeira: a aba de 7 cm na altura de cada laje.
	#
	# Ela existe na rua de verdade porque e o que impede a agua de escorrer pela
	# parede inteira e sujar o reboco de cima a baixo — e, de quebra, e ela que
	# quebra o paredao: uma sombra horizontal a cada tres metros, por dois
	# triangulos por andar. Sem isso, predio de quatro andares le como caixa
	# lisa, que foi o que o usuario apontou como "falta de detalhamento".
	for andar in range(1, andares):
		caixa_cor(saida, material,
			frente + Vector3(0.0, float(andar) * ALTURA_ANDAR, 0.0) + normal * 0.03,
			Vector3(largura, 0.07, 0.14), cor.lerp(Color.WHITE, 0.18), giro_fachada,
			PSXMesh.FACE_TODAS, 4.0)

	# Medidor de luz com conduite descendo. Detalhe de dois palmos que nenhuma
	# fachada brasileira deixa de ter, e que nenhuma fachada de jogo tem.
	var lado_medidor := lateral * (largura * 0.5 - 0.55)
	caixa_cor(saida, &"metal", frente + lado_medidor + Vector3(0.0, 1.62, 0.0) + normal * 0.07,
		Vector3(0.26, 0.34, 0.14), Color("b9bcb6"), giro_fachada, PSXMesh.FACE_TODAS, 8.0)
	caixa_cor(saida, &"metal", frente + lado_medidor + Vector3(0.0, 0.72, 0.0) + normal * 0.04,
		Vector3(0.05, 1.45, 0.05), Color("8d8f8a"), giro_fachada, PSXMesh.FACE_TODAS, 8.0)

	var ar_ja := false
	for andar in range(1, andares):
		var y := andar * ALTURA_ANDAR + 1.5
		var n := maxi(1, int(largura / 2.6))
		var passo_and := largura / float(n)
		for j in n:
			var off := (float(j) - float(n - 1) * 0.5) * passo_and
			var larg_j := 1.1 if (j % 2) == 0 else 0.85
			parede(saida,
				&"janela_acesa" if rng.randf() < prob_janela_acesa else &"janela_apagada",
				frente + Vector3(0.0, y, 0.0) + lateral * off,
				Vector2(larg_j, 1.3), direcao)
			if not ar_ja and rng.randf() < 0.22:
				var giro := atan2(normal.x, normal.z)
				caixa_cor(saida, &"metal",
					frente + Vector3(0.0, y - 0.85, 0.0) + lateral * off + normal * 0.22,
					Vector3(0.7, 0.28, 0.38), Color("c5c8c4"), giro)
				ar_ja = true

	return tem_loja


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


## Mastro, cabeca e as tres lentes APAGADAS de um semaforo.
##
## Entra na superficie do chunk, e nao num no proprio, pela mesma razao do poste
## de luz: fundido no mesh do chunk custa zero chamada de desenho, e um
## cruzamento tem dois semaforos. Como no proprio, seriam quatro chamadas por
## cruzamento e, com tres cruzamentos a vista, doze — mais do que a cidade
## inteira gasta com fachada.
##
## O que sobra para o no e so a lente ACESA, que precisa mudar de lugar e de cor
## a cada fase. Uma chamada por poste, e nao tres.
static func semaforo(saida: Dictionary, base: Vector3, giro: float) -> void:
	# Cabeca maior do que a primeira versao (era 0,30 x 0,78 e lente de 0,17).
	# Numa tela de 480x270 aquele tamanho virava um borrao de dois pixels a
	# vinte metros: o poste existia mas nao dava para dizer o que ele mostrava,
	# que e a unica coisa que um semaforo precisa comunicar. Isto e uma cabeca
	# de tres lentes de tamanho de rua, e nao custa triangulo nenhum a mais.
	const ALTURA := 3.35
	caixa(saida, &"metal", base + Vector3(0.0, ALTURA * 0.5, 0.0),
		Vector3(0.14, ALTURA, 0.14), giro)
	caixa(saida, &"metal", base + Vector3(0.0, ALTURA - 0.52, 0.0),
		Vector3(0.42, 1.02, 0.30), giro)
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	# Pala. Doze triangulos que fazem a silhueta ler como semaforo contra o ceu
	# em vez de caixa em cima de pau, e que dizem para que lado a cabeca olha.
	caixa(saida, &"metal", base + Vector3(0.0, ALTURA + 0.06, 0.0) + frente * 0.06,
		Vector3(0.50, 0.07, 0.36), giro)
	# As lentes apagadas, dos dois lados da cabeca. Ficam escuras e ali ficam: a
	# lente acesa e outro objeto, que passa na frente desta.
	for k in 3:
		var y := ALTURA - 0.22 - float(k) * 0.30
		for lado: float in [1.0, -1.0]:
			parede_livre(saida, &"metal",
				base + Vector3(0.0, y, 0.0) + frente * (0.161 * lado),
				Vector2(0.24, 0.24),
				giro + (0.0 if lado > 0.0 else PI),
				Color(0.22, 0.2, 0.2))


## Mastro e cabeca APAGADA de um sinal de pedestre.
##
## Mais baixo e mais fino que o semaforo de carro: ele e para quem esta na
## calcada, a um metro. A face que acende — o bonequinho anda/pare — e um no
## proprio, SinalPedestre, pela mesma razao da lente do semaforo. A altura da
## caixa casa com SinalPedestre.ALTURA.
static func sinal_pedestre(saida: Dictionary, base: Vector3, giro: float) -> void:
	const ALTURA := 2.3
	caixa(saida, &"metal", base + Vector3(0.0, ALTURA * 0.5, 0.0),
		Vector3(0.10, ALTURA, 0.10), giro)
	caixa(saida, &"metal", base + Vector3(0.0, ALTURA - 0.12, 0.0),
		Vector3(0.34, 0.40, 0.20), giro)
	# A janela apagada dos dois lados. O icone aceso passa na frente dela.
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	for lado: float in [1.0, -1.0]:
		parede_livre(saida, &"metal",
			base + Vector3(0.0, ALTURA - 0.12, 0.0) + frente * (0.11 * lado),
			Vector2(0.26, 0.30),
			giro + (0.0 if lado > 0.0 else PI),
			Color(0.16, 0.15, 0.14))


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
	# Quatro faces compridas e so: fio de 6 cm nao tem textura que entorte, e a
	# ponta dele nunca aparece. Subdividido de 2 em 2 m e com as pontas, cada
	# trecho custava 44 triangulos, e o vao de 32 m entre dois postes, 528 — mais
	# que os quatro semaforos do cruzamento juntos. Agora sao 8 por trecho.
	var faces := PSXMesh.FACE_TODAS & ~(PSXMesh.FACE_DIR | PSXMesh.FACE_ESQ)
	por(saida, &"metal", _caixa(Vector3(comp, 0.06, 0.06), faces, 64.0),
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
