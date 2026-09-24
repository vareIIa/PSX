## As plantas que existem NA RUA, atras da propria fachada, e as medidas delas.
##
## Por que existe
## --------------
## O `InteriorNoMundo` nasceu para a casa da fumaca e tinha a casa cravada em dez
## lugares: o centro do vao, a largura, o fundo e a altura da sala, a espessura
## da parede, o teste de "o jogador esta dentro do lote". O mercado e a segunda
## planta a sair do teleporte (PLANO_MERCADO_AAA, F1), e com duas plantas a
## pergunta "qual e o tamanho da sala" deixa de ter uma resposta so.
##
## Aqui mora a unica resposta por planta. Quem monta (o `InteriorNoMundo`), quem
## reserva o lote (`ChunkBuilder._fileira`) e quem acha a porta sem montar o chunk
## (`ChunkBuilder._porta_do_chunk`, o mapa, o GPS) leem os mesmos numeros.
##
## A casa da fumaca continua respondendo pelas funcoes da `KitFumaca`, sem uma
## linha de diferenca: esta classe so encaminha. Mudar o comportamento dela aqui
## mudaria onde cai a porta de todas as casas da cidade.
##
## Eixos da PLANTA no chunk (os mesmos da KitFumaca): +Z entra no lote, contra a
## normal da fachada; +Y sobe; origem no canto interno da parede da frente, na
## altura do piso. O +X da planta corre AO CONTRARIO do +X local da porta.
class_name LoteNoMundo
extends RefCounted

## Plantas que sabem existir na rua.
const PLANTAS: Array[StringName] = [&"casa_fumaca", &"mercado"]


static func conhece(planta: StringName) -> bool:
	return PLANTAS.has(planta)


## Largura (ao longo da face) e fundo do lote, com as paredes de fora.
static func lote(planta: StringName) -> Vector2:
	match planta:
		&"mercado":
			return Vector2(MercadoBuilder.LARGURA + MercadoBuilder.PAREDE * 2.0,
				MercadoBuilder.FUNDO + MercadoBuilder.PAREDE * 2.0)
	return KitFumaca.LOTE


## Quanto o lote ocupa do quintal, da linha da face para dentro: o `lote` e,
## na casa da fumaca, o puxadinho da escada do porao atras dela. E a pegada que
## muro de fundo, quintal e arvore do miolo contornam (FundosBuilder).
static func fundo_da_pegada(planta: StringName) -> float:
	if planta == &"casa_fumaca":
		return CasaFumacaBuilder.PUXADINHO_FUNDO + 0.2 + KitFumaca.PAREDE
	return lote(planta).y


## O buraco do porao no chao da quadra, em coordenada do chunk: a planta do
## puxadinho da escada, com o fundo dele. Nula quando a planta nao tem porao.
##
## A escada desce 3,4 m atras da casa, e o chao do quintal (grama, terra) passava
## no meio dela na altura do patamar: quem descia via a grama cortando o vao e
## atravessava ela. RebaixoDoLote afunda o chao ali ate abaixo do corredor da
## estufa. Sem a parede de emenda na borda (RebaixoDoLote): do lado da casa ela
## cruzava a boca da estufa no pe da escada; as bordas caem dentro das paredes do
## puxadinho. `em_planta` e a planta_no_chunk; `dy`, o que a ladeira ergueu o lote.
static func pegada_do_porao(planta: StringName, em_planta: Transform3D,
		dy: float = 0.0) -> Dictionary:
	if planta != &"casa_fumaca":
		return {}
	var x := CasaFumacaBuilder.PUXADINHO_X
	var a := em_planta * Vector3(x.x - 0.1, 0.0, CasaFumacaBuilder.FUNDO + 0.1)
	var b := em_planta * Vector3(x.y + 0.1, 0.0, CasaFumacaBuilder.PUXADINHO_FUNDO + 0.1)
	return {
		"rebaixo": Rect2(Vector2(minf(a.x, b.x), minf(a.z, b.z)),
			Vector2(absf(b.x - a.x), absf(b.z - a.z))),
		"rebaixo_y": (em_planta * Vector3(0.0, -CasaFumacaBuilder.DESCIDA - 0.4, 0.0)).y + dy,
		"rebaixo_emenda": false,
	}


## A sala por dentro: largura, fundo e altura do forro, em metros de planta.
static func sala(planta: StringName) -> Vector3:
	match planta:
		&"mercado":
			return Vector3(MercadoBuilder.LARGURA, MercadoBuilder.ALTURA_MAXIMA,
				MercadoBuilder.FUNDO)
	return Vector3(CasaFumacaBuilder.LARGURA, CasaFumacaBuilder.ALTURA,
		CasaFumacaBuilder.FUNDO)


static func parede(planta: StringName) -> float:
	match planta:
		&"mercado":
			return MercadoBuilder.PAREDE
	return KitFumaca.PAREDE


## O centro do vao de entrada, em coordenada de planta, no plano da fachada.
static func centro_do_vao(planta: StringName) -> Vector3:
	match planta:
		&"mercado":
			return Vector3(MercadoBuilder.CENTRO_PORTA, 0.0, -MercadoBuilder.PAREDE * 0.5)
	return KitFumaca.centro_do_vao()


## A que distancia da porta os fregueses e a gente de dentro ganham vida.
##
## A casa da fumaca tem porta de madeira: da calcada nao se ve ninguem la dentro
## antes de a porta abrir, e 9 m bastam. O mercado e vitrine de vidro de ponta a
## ponta — quem passa do outro lado da rua ve a fila no caixa. Gente parada em
## pose atras de um vidro aceso le como manequim, entao ali a vida liga longe.
static func ativar(planta: StringName) -> float:
	match planta:
		&"mercado":
			return 26.0
	return 9.0


## A que distancia da porta a planta comeca a ser montada.
##
## O mercado se ve de longe pelo vidro, e o vidro so fica transparente perto
## (psx_vitrine: opaco e aceso alem de 36 m). A montagem tem de terminar
## antes de o vidro abrir: a 40 m, andando, sao quase dez segundos de folga; de
## carro a 50 km/h, dois e meio — mais que os props nascendo um por quadro.
static func preaquecer(planta: StringName) -> float:
	match planta:
		&"mercado":
			return 40.0
	return 32.0


## A planta em dados, na versao que existe na rua. Roda na thread.
##
## Chama os construtores direto, e nao `Interiores.planta_de`: esta classe entra
## na compilacao do ChunkBuilder, e citar um autoload pelo nome quebrava os
## testes de `--script`, que compilam a cadeia antes de o autoload existir
## (aviso da sessao dos morros, varrer_patio).
static func planta_de(planta: StringName, semente: int) -> Dictionary:
	match planta:
		&"mercado":
			return MercadoBuilder.construir(semente, true)
	return CasaFumacaBuilder.construir(semente)


## Onde o lote cai ao longo de uma face. Vazio quando nao cabe.
##
## Sem rng: o mapa precisa achar a porta sem montar o chunk.
##
## A regra da esquina vale para qualquer lote mais fundo que a fileira. Numa face
## do eixo Z (direcao 1 ou 3) com rua perpendicular, a fileira do OUTRO eixo
## ocupa os PROF_PREDIO metros da ponta daquela rua, com a profundidade toda dela
## entrando no patio. Um lote que passe de PROF_PREDIO de fundo e comece ali
## atravessa aquele predio. A casa da fumaca nunca esbarrou nisso porque 12,1 m
## mais 8 cabem na menor face da cidade (20,2 m); o mercado, com 17,5, nao cabe
## em toda esquina — e onde nao cabe, nao nasce (`ChunkBuilder._porta_do_chunk`).
##
## `fundo_livre` e quanto a area util do chunk tem de fundo atras da face. O lote
## do mercado entra 8,5 m no patio, e numa quadra rasa ele atravessaria o muro
## de tras e o miolo; ali tambem nao nasce. Meio metro de folga fica para o muro.
static func lote_na_face(planta: StringName, face: Dictionary,
		bordas: Dictionary, fundo_livre: float = INF) -> Dictionary:
	if planta == &"casa_fumaca":
		return KitFumaca.lote_na_face(face, bordas)
	if face.is_empty():
		return {}
	var tam := lote(planta)
	var comp := float(face["comprimento"])
	if comp < tam.x + 1.0 or tam.y > fundo_livre - 0.5:
		return {}
	var inicio := 0.0
	var direcao := int(face["direcao"])
	var fundo_demais := tam.y > ChunkBuilder.PROF_PREDIO + 0.01
	if direcao == 1 or direcao == 3:
		if int(bordas["z0"]) != MalhaUrbana.Via.NENHUMA:
			inicio = comp - tam.x
			if fundo_demais and inicio < ChunkBuilder.PROF_PREDIO:
				return {}
		elif int(bordas["z1"]) != MalhaUrbana.Via.NENHUMA:
			if fundo_demais and tam.x > comp - ChunkBuilder.PROF_PREDIO:
				return {}
	return {"inicio": inicio}


## A transformada planta -> chunk. `inicio` e o de `lote_na_face`.
static func planta_no_chunk(planta: StringName, face: Dictionary,
		inicio: float) -> Transform3D:
	if planta == &"casa_fumaca":
		return KitFumaca.planta_no_chunk(face, inicio)
	var tam := lote(planta)
	var larg := sala(planta).x
	var normal := KitModular._normal(int(face["direcao"]))
	var giro := atan2(normal.x, normal.z)
	var b := Basis(Vector3.UP, giro + PI)
	var frente: Vector3 = Vector3(face["canto"]) \
		+ Vector3(face["eixo"]) * (inicio + tam.x * 0.5)
	# A fachada fica 6 cm a frente da linha da face (ChunkBuilder._fileira); o
	# lado de dentro dela, uma parede atras.
	var origem := frente + normal * (0.06 - parede(planta)) \
		- b * Vector3(larg * 0.5, 0.0, 0.0)
	origem.y = KitFumaca.PISO_Y
	return Transform3D(b, origem)


## O ponto da planta em que o jogador esta dentro da caixa do lote.
##
## Oitenta centimetros acima do forro: e o 3,5 m que a casa da fumaca sempre
## usou (2,7 de pe direito), e continua sendo.
static func no_lote(planta: StringName, p: Vector3, folga_frente: float = 0.0) -> bool:
	var s := sala(planta)
	if embaixo(planta, p):
		return true
	return p.x > -0.3 and p.x < s.x + 0.3 and p.z > -folga_frente \
		and p.z < s.z + 0.3 and p.y > -1.5 and p.y < s.y + 0.8


## O ponto esta no porao da casa da fumaca: no puxadinho da escada (qualquer
## altura) ou dentro da estufa, debaixo da casa. Coordenada de planta.
##
## E a pergunta de quem cuida da travessia do chao (InteriorNoMundo): quem esta
## aqui atravessa a laje da quadra e respira o ar da estufa, e nao o da sala.
static func embaixo(planta: StringName, p: Vector3) -> bool:
	if planta != &"casa_fumaca":
		return false
	var x := CasaFumacaBuilder.PUXADINHO_X
	var z0 := CasaFumacaBuilder.FUNDO + 0.2
	if p.x > x.x - 0.05 and p.x < x.y + 0.05 and p.z > z0 \
			and p.z < CasaFumacaBuilder.PUXADINHO_FUNDO + 0.1 \
			and p.y > -CasaFumacaBuilder.DESCIDA - 1.0 and p.y < 2.8:
		return true
	return _na_estufa(p)


## Dentro da caixa da estufa, em coordenada de planta da casa.
static func _na_estufa(p: Vector3) -> bool:
	var e := CasaFumacaBuilder.ESTUFA_NA_CASA.affine_inverse() * p
	return e.x > -0.3 and e.x < EstufaBuilder.LARGURA + 0.3 \
		and e.z > -0.2 and e.z < EstufaBuilder.FUNDO + 0.3 \
		and e.y > EstufaBuilder.PISO_10 - 1.0 and e.y < EstufaBuilder.NICHO + 0.1


## A caixa inteira do que a planta ocupa, em coordenada de planta: a sala, e na
## casa da fumaca o puxadinho e a estufa embaixo. Serve ao teto de chuva.
static func caixa(planta: StringName) -> AABB:
	var s := sala(planta)
	var e := parede(planta)
	var box := AABB(Vector3(-e, -1.0, -e), Vector3(s.x + e * 2.0, 61.0, s.z + e * 2.0))
	if planta == &"casa_fumaca":
		var t := CasaFumacaBuilder.ESTUFA_NA_CASA
		var cantos := AABB(Vector3(0.0, EstufaBuilder.PISO_10, 0.0),
			Vector3(EstufaBuilder.LARGURA, EstufaBuilder.NICHO - EstufaBuilder.PISO_10,
				EstufaBuilder.FUNDO))
		box = box.merge(t * cantos)
		box = box.expand(Vector3(s.x * 0.5, 0.0, CasaFumacaBuilder.PUXADINHO_FUNDO + 0.2))
	return box
