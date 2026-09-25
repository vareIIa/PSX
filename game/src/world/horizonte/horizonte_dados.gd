## A planta 2,5D de um chunk para o anel distante (Horizonte, passo 2).
##
## De onde sai
## -----------
## Do proprio chunk: `ChunkBuilder.construir` roda numa thread e a planta e lida
## das superficies que ele devolveu. Nao existe um "plano" barato do predio —
## altura, telhado e cor sao decididos dentro da geometria, no mesmo sorteio —,
## e copiar essa logica faria o anel distante descasar do chunk de verdade na
## transicao. E o HLOD de mundo aberto: a versao de longe e feita da de perto.
##
## O que guarda
## ------------
## Uma grade de PASSO m (16 x 16 por chunk), vista de cima. Em cada ponto:
##
##   topo        altura da superficie mais alta virada para cima (telhado, laje,
##               copa, chao), em decimetros
##   chao        altura do chao ali (rua, calcada, grama); onde o predio tapa o
##               chao, o Relevo
##   cor_topo    a cor da superficie do topo: media da textura (cores_materiais,
##               tools/gerar_cores_horizonte.py) x cor do vertice, linear
##   cor_parede  a cor da maior parede que passa pelo ponto (fachada)
##   classe      CHAO, PREDIO ou COPA; o bit TEM_PAREDE diz se cor_parede vale
##
## Fica de fora o que e fino ou pequeno demais para existir a 300 m e so faria
## espinho na planta: fio, poste, placa, letreiro, vidro, o balde @perto e todo
## triangulo virado para cima com menos de AREA_MIN de projecao (peitoril,
## tampa de poste).
class_name HorizonteDados
extends RefCounted

const TAM := 32.0
const PASSO := 2.0
const LADO := 16
const BYTES := 11
const TOTAL := LADO * LADO * BYTES

enum Classe { NADA, CHAO, PREDIO, COPA }
const TEM_PAREDE := 0x80

## Triangulo virado para cima com menos que isto de area (m2) e detalhe.
const AREA_MIN := 0.25
## Parede com menos que isto nao pinta fachada (m2).
const AREA_PAREDE_MIN := 1.0
## |normal.y| abaixo disto e parede; acima de CIMA_MIN e topo.
const PAREDE_MAX := 0.35
const CIMA_MIN := 0.35

const CHAO: Array[StringName] = [
	&"asfalto", &"asfalto_faixa", &"asfalto_remendo", &"marca_via", &"paralelepipedo",
	&"calcada", &"calcada_ladrilho", &"meio_fio", &"grama", &"terra", &"areia",
	&"leito", &"piso", &"mato", &"agua", &"agua_lago", &"pedra_parque",
]
const COPA: Array[StringName] = [
	&"vegetacao", &"arbusto", &"folhagem", &"folhagem_recorte", &"plantas",
]
## Pedaco do nome que tira o material da planta.
const FORA: Array[String] = [
	"cabo", "corrente", "cone_luz", "lampada", "_luz", "sinal_", "semaforo",
	"marca_pneu", "fumaca", "npc", "personagem", "olhos", "cigarro", "celular",
	"bicicleta", "carro", "espuma", "janela", "vitrine", "vidro", "letreiro",
	"anuncio", "pichacao", "painel", "placa", "maquina", "cortina", "flor",
	"caule", "casca", "interior", "estufa_kit",
]
const CINZA := Color(0.3, 0.3, 0.3)
## Copa de longe: verde de folha, vezes a cor do vertice da especie. A media do
## atlas de vegetacao mistura tronco, flor e fundo e da oliva-amarelado.
const COR_COPA := Color(0.034, 0.062, 0.02)
const COR_CHAO := Color(0.12, 0.11, 0.09)
const CORES := "res://resources/horizonte/cores_materiais.json"
## A cor de parede e de telhado de verdade, por distrito: amostras das plantas
## exatas na frequencia em que aparecem (tests/bancada_horizonte.gd --paleta).
## A aproximada sorteia uma por lote: de longe, a mesma cidade.
const PALETA := "res://resources/horizonte/paleta_aproximada.json"

static var _cores: Dictionary = {}
## distrito -> {"paredes": PackedColorArray, "telhados": PackedColorArray} (linear)
static var _paleta: Dictionary = {}
static var _sem_cor: Dictionary = {}
static var _pronto := false
static var _trava := Mutex.new()


## Le a tabela de cores. Fio principal, uma vez, antes da primeira tarefa.
static func preparar() -> void:
	if _pronto:
		return
	var texto := FileAccess.get_file_as_string(CORES)
	var tabela: Variant = JSON.parse_string(texto)
	if tabela is Dictionary:
		for nome: String in tabela:
			var c: Array = tabela[nome]
			_cores[StringName(nome)] = Color(float(c[0]), float(c[1]), float(c[2]))
	else:
		push_warning("Horizonte: sem %s, o anel distante sai cinza" % CORES)
	var paleta: Variant = JSON.parse_string(FileAccess.get_file_as_string(PALETA))
	if paleta is Dictionary:
		for d: String in paleta:
			var e: Dictionary = paleta[d]
			var saida := {}
			for chave: String in ["paredes", "telhados"]:
				var cores := PackedColorArray()
				for c: Array in e[chave]:
					cores.append(Color(float(c[0]), float(c[1]), float(c[2])).srgb_to_linear())
				saida[chave] = cores
			_paleta[int(d)] = saida
	else:
		push_warning("Horizonte: sem %s, a cidade de longe sai na cor da quadra" % PALETA)
	_pronto = true


static func _fora(nome: String) -> bool:
	for pedaco: String in FORA:
		if nome.contains(pedaco):
			return true
	return false


static func _cor_do_material(material: StringName) -> Color:
	var c: Variant = _cores.get(material)
	if c != null:
		return c
	_trava.lock()
	if not _sem_cor.has(material):
		_sem_cor[material] = true
		push_warning("Horizonte: material '%s' sem cor media; rode tools/gerar_cores_horizonte.py" % material)
	_trava.unlock()
	return CINZA


## Constroi o chunk e le a planta. Roda fora do fio principal.
static func amostrar(cx: int, cz: int) -> PackedByteArray:
	var dados := ChunkBuilder.construir(cx, cz)
	return planta_de(dados["superficies"], cx, cz)


static func planta_de(sup: Dictionary, cx: int, cz: int) -> PackedByteArray:
	var n := LADO * LADO
	var topo := PackedFloat32Array()
	topo.resize(n)
	topo.fill(-INF)
	var chao := PackedFloat32Array()
	chao.resize(n)
	chao.fill(-INF)
	var cor_topo := PackedColorArray()
	cor_topo.resize(n)
	var cor_parede := PackedColorArray()
	cor_parede.resize(n)
	var area_parede := PackedFloat32Array()
	area_parede.resize(n)
	var classe := PackedByteArray()
	classe.resize(n)

	for material: StringName in sup:
		var nome := String(material)
		if nome.contains("@") or _fora(nome):
			continue
		var cls := Classe.PREDIO
		if CHAO.has(material):
			cls = Classe.CHAO
		elif COPA.has(material):
			cls = Classe.COPA
		var cor_mat := COR_COPA if cls == Classe.COPA else _cor_do_material(material)
		var d: Dictionary = sup[material]
		var v: PackedVector3Array = d["v"]
		var nn: PackedVector3Array = d["n"]
		var cc: PackedColorArray = d["c"]
		var idx: PackedInt32Array = d["i"]
		var com_cor := cc.size() == v.size()
		var com_normal := nn.size() == v.size()
		for t in range(0, idx.size() - 2, 3):
			var ia := idx[t]
			var ib := idx[t + 1]
			var ic := idx[t + 2]
			var a := v[ia]
			var b := v[ib]
			var c := v[ic]
			var ny := 0.0
			if com_normal:
				ny = (nn[ia].y + nn[ib].y + nn[ic].y) / 3.0
			else:
				var cruz := (b - a).cross(c - a)
				ny = absf(cruz.normalized().y)
			var cor := cor_mat
			if com_cor:
				var m := (cc[ia] + cc[ib] + cc[ic]) / 3.0
				cor = Color(cor_mat.r * m.r, cor_mat.g * m.g, cor_mat.b * m.b)
			if absf(ny) < PAREDE_MAX:
				if cls != Classe.PREDIO:
					continue
				var area := (b - a).cross(c - a).length() * 0.5
				if area < AREA_PAREDE_MIN:
					continue
				var centro := (a + b + c) / 3.0
				var px := clampi(floori(centro.x / PASSO), 0, LADO - 1)
				var pz := clampi(floori(centro.z / PASSO), 0, LADO - 1)
				var p := pz * LADO + px
				if area > area_parede[p]:
					area_parede[p] = area
					cor_parede[p] = cor
				continue
			if ny < CIMA_MIN:
				continue
			_raster(a, b, c, cls, cor, topo, chao, cor_topo, classe)

	var saida := PackedByteArray()
	saida.resize(TOTAL)
	for pz in LADO:
		for px in LADO:
			var p := pz * LADO + px
			var h_chao := chao[p]
			if h_chao == -INF:
				h_chao = Relevo.altura(cx * TAM + (px + 0.5) * PASSO,
					cz * TAM + (pz + 0.5) * PASSO)
			var h_topo := maxf(topo[p], h_chao)
			var cls: int = classe[p]
			var ct := cor_topo[p]
			if topo[p] == -INF:
				cls = Classe.CHAO
				ct = COR_CHAO
			if area_parede[p] > 0.0:
				cls |= TEM_PAREDE
			var o := p * BYTES
			saida.encode_s16(o, clampi(roundi(h_topo * 10.0), -32767, 32767))
			saida.encode_s16(o + 2, clampi(roundi(h_chao * 10.0), -32767, 32767))
			_por_cor(saida, o + 4, ct)
			_por_cor(saida, o + 7, cor_parede[p])
			saida[o + 10] = cls
	return saida


## Cada centro de ponto da grade dentro do triangulo (projetado no chao) fica
## com a altura dele, se for mais alta que a que ja estava.
static func _raster(a: Vector3, b: Vector3, c: Vector3, cls: int, cor: Color,
		topo: PackedFloat32Array, chao: PackedFloat32Array, cor_topo: PackedColorArray,
		classe: PackedByteArray) -> void:
	var den := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
	if absf(den) * 0.5 < AREA_MIN and cls != Classe.COPA:
		return
	if absf(den) < 1e-6:
		return
	var x0 := maxi(0, floori(minf(a.x, minf(b.x, c.x)) / PASSO - 0.5))
	var x1 := mini(LADO - 1, ceili(maxf(a.x, maxf(b.x, c.x)) / PASSO - 0.5))
	var z0 := maxi(0, floori(minf(a.z, minf(b.z, c.z)) / PASSO - 0.5))
	var z1 := mini(LADO - 1, ceili(maxf(a.z, maxf(b.z, c.z)) / PASSO - 0.5))
	for pz in range(z0, z1 + 1):
		var z := (pz + 0.5) * PASSO
		for px in range(x0, x1 + 1):
			var x := (px + 0.5) * PASSO
			var l1 := ((b.z - c.z) * (x - c.x) + (c.x - b.x) * (z - c.z)) / den
			var l2 := ((c.z - a.z) * (x - c.x) + (a.x - c.x) * (z - c.z)) / den
			var l3 := 1.0 - l1 - l2
			if l1 < -0.001 or l2 < -0.001 or l3 < -0.001:
				continue
			var h := l1 * a.y + l2 * b.y + l3 * c.y
			var p := pz * LADO + px
			if cls == Classe.CHAO and h > chao[p]:
				chao[p] = h
			if h > topo[p]:
				topo[p] = h
				cor_topo[p] = cor
				classe[p] = cls


static func _por_cor(saida: PackedByteArray, o: int, c: Color) -> void:
	var s := c.linear_to_srgb()
	saida[o] = clampi(roundi(s.r * 255.0), 0, 255)
	saida[o + 1] = clampi(roundi(s.g * 255.0), 0, 255)
	saida[o + 2] = clampi(roundi(s.b * 255.0), 0, 255)


## A planta tem lado variavel (16, 8, 4 ou 2 pontos por chunk): o anel de longe
## usa menos pontos. O lado sai do tamanho.
static func lado_de(planta: PackedByteArray) -> int:
	return int(round(sqrt(planta.size() / float(BYTES))))


## Leitura do ponto de indice `p` (pz * lado + px).
static func topo_de(planta: PackedByteArray, p: int) -> float:
	return planta.decode_s16(p * BYTES) / 10.0


static func chao_de(planta: PackedByteArray, p: int) -> float:
	return planta.decode_s16(p * BYTES + 2) / 10.0


static func cor_topo_de(planta: PackedByteArray, p: int) -> Color:
	var o := p * BYTES + 4
	return Color8(planta[o], planta[o + 1], planta[o + 2]).srgb_to_linear()


static func cor_parede_de(planta: PackedByteArray, p: int) -> Color:
	var o := p * BYTES + 7
	return Color8(planta[o], planta[o + 1], planta[o + 2]).srgb_to_linear()


static func classe_de(planta: PackedByteArray, p: int) -> int:
	return planta[p * BYTES + 10]


## A mesma planta com menos pontos: cada bloco fica com o ponto de topo mais
## alto (o telhado manda de longe), o chao medio e a primeira parede que houver.
##
## `media`, para o ponto de 16 m ou mais: o bloco mais alto fazia de cada
## quarteirao um cubo cheio. O bloco vira predio se predio cobre ao menos um
## quarto dele (MEDIA_PREDIO), na altura media dos predios e na cor media dos
## telhados; senao e chao com a cor media de tudo (rua, telhado e copa juntos,
## a textura que o olho ve a 2 km). A malha recua o bloco da borda do ponto: a
## rua volta a ser o vao entre eles (HorizonteMalha, `recuo`).
static func reduzir(planta: PackedByteArray, lado: int, media := false) -> PackedByteArray:
	var de := lado_de(planta)
	if lado >= de:
		return planta
	var k := de / lado
	if media:
		return _reduzir_media(planta, de, lado, k)
	var saida := PackedByteArray()
	saida.resize(lado * lado * BYTES)
	for qz in lado:
		for qx in lado:
			var melhor := -1
			var h_melhor := -INF
			var chao := 0.0
			var parede := -1
			for dz in k:
				for dx in k:
					var p := (qz * k + dz) * de + qx * k + dx
					var h := topo_de(planta, p)
					chao += chao_de(planta, p)
					if h > h_melhor:
						h_melhor = h
						melhor = p
					if parede < 0 and classe_de(planta, p) & TEM_PAREDE:
						parede = p
			var o := (qz * lado + qx) * BYTES
			var om := melhor * BYTES
			for b in BYTES:
				saida[o + b] = planta[om + b]
			saida.encode_s16(o + 2, clampi(roundi(chao / (k * k) * 10.0), -32767, 32767))
			if parede >= 0:
				for b in 3:
					saida[o + 7 + b] = planta[parede * BYTES + 7 + b]
				saida[o + 10] = planta[om + 10] | TEM_PAREDE
	return saida


const MEDIA_PREDIO := 0.25
const MEDIA_COPA := 0.5


static func _reduzir_media(planta: PackedByteArray, de: int, lado: int, k: int) -> PackedByteArray:
	var saida := PackedByteArray()
	saida.resize(lado * lado * BYTES)
	var n := float(k * k)
	for qz in lado:
		for qx in lado:
			var conta := [0, 0, 0, 0]
			var soma_topo := [0.0, 0.0, 0.0, 0.0]
			var soma_cor := [Color(0, 0, 0), Color(0, 0, 0), Color(0, 0, 0), Color(0, 0, 0)]
			var chao := 0.0
			var cor_tudo := Color(0, 0, 0)
			var parede := Color(0, 0, 0)
			var paredes := 0
			for dz in k:
				for dx in k:
					var p := (qz * k + dz) * de + qx * k + dx
					var cls := classe_de(planta, p)
					var c := cls & 0x7F
					var ct := cor_topo_de(planta, p)
					conta[c] += 1
					soma_topo[c] += topo_de(planta, p)
					soma_cor[c] += ct
					chao += chao_de(planta, p)
					cor_tudo += ct
					if cls & TEM_PAREDE:
						parede += cor_parede_de(planta, p)
						paredes += 1
			chao /= n
			var cls_saida := Classe.CHAO
			var topo := chao
			var cor := cor_tudo / n
			if conta[Classe.PREDIO] >= MEDIA_PREDIO * n:
				cls_saida = Classe.PREDIO
				topo = soma_topo[Classe.PREDIO] / conta[Classe.PREDIO]
				cor = soma_cor[Classe.PREDIO] / conta[Classe.PREDIO]
			elif conta[Classe.COPA] >= MEDIA_COPA * n:
				cls_saida = Classe.COPA
				topo = soma_topo[Classe.COPA] / conta[Classe.COPA]
				cor = soma_cor[Classe.COPA] / conta[Classe.COPA]
			var o := (qz * lado + qx) * BYTES
			saida.encode_s16(o, clampi(roundi(topo * 10.0), -32767, 32767))
			saida.encode_s16(o + 2, clampi(roundi(chao * 10.0), -32767, 32767))
			_por_cor(saida, o + 4, cor)
			if paredes > 0:
				_por_cor(saida, o + 7, parede / paredes)
				cls_saida |= TEM_PAREDE
			saida[o + 10] = cls_saida
	return saida


## A lampada do poste de luz do chunk, no mundo (Vector3.INF se nao ha): a
## mesma conta da RedeEletrica (a borda acesa do chunk, no ponto de
## ChunkBuilder._poste_local), sem passar pelo cache dela — o anel distante
## pergunta por milhares de chunks e o esvaziaria, e o streaming de perto
## pagaria para refazer. As de esquina (viradas) ficam de fora: de longe e o
## mesmo ponto de luz na mesma quadra.
static func lampada(cx: int, cz: int) -> Vector3:
	var b := MalhaUrbana.bordas(cx, cz)
	var chave := RedeEletrica.borda_da_luz(b)
	if chave.is_empty():
		return Vector3.INF
	var eixo := 0 if chave.begins_with("x") else 1
	var lado := 1 if chave.ends_with("0") else -1
	var linha := (cx if eixo == 0 else cz) + (0 if lado > 0 else 1)
	var k := cz if eixo == 0 else cx
	var local := ChunkBuilder._poste_local(b)
	var ao_longo := local.z if eixo == 0 else local.x
	var afast := MalhaUrbana.meia_asfalto(int(b[chave])) + RedeEletrica.DA_GUIA
	var pe := RedeEletrica.ponto(eixo, linha, k, lado, ao_longo, afast)
	return pe + RedeEletrica.para_rua(eixo, lado) * KitRede.LAMPADA_FORA 		+ Vector3(0.0, KitRede.LAMPADA_ALTURA, 0.0)


## A planta de longe, sem construir o chunk: do quarteirao (MalhaUrbana.quadra_de),
## das ruas em volta (bordas) e do Relevo. Um anel de predios de PROF_PREDIO m de
## fundo nas faces de rua, na altura de andares da quadra (um a mais ou a menos
## por lote de LOTE m, sorteado), na cor da fachada da quadra; o miolo e quintal;
## parque e grama com copa; baldio e mato. A 1 km o lote nao se le, o quarteirao
## sim. Mesmo formato da exata, para a malha nao saber a diferenca.
const LOTE := 8.0
const COR_ASFALTO := Color(0.047, 0.046, 0.041)
const COR_QUINTAL := Color(0.08, 0.09, 0.05)
const COR_TELHA := Color(0.2, 0.035, 0.008)
const COR_LAJE := Color(0.14, 0.13, 0.12)
const COR_LAJE_CLARA := Color(0.42, 0.4, 0.37)


static func aproximar(cx: int, cz: int, lado: int) -> PackedByteArray:
	var b := MalhaUrbana.bordas(cx, cz)
	var quadra := MalhaUrbana.quadra_de(cx, cz)
	var lim := ChunkBuilder.area_util(cx, cz)
	var faces := ChunkBuilder.faces_de_rua(b, lim)
	var uso := int(quadra["uso"])
	var andares := int(quadra["andares"])
	var casa := bool(quadra["casa"])
	var tinta: Color = quadra["tinta"]
	var da_paleta: Dictionary = _paleta.get(int(quadra["distrito"]), {})
	var paredes: PackedColorArray = da_paleta.get("paredes", PackedColorArray())
	var telhados: PackedColorArray = da_paleta.get("telhados", PackedColorArray())
	var cor_fachada := _cor_do_material(StringName(quadra["fachada"]))
	cor_fachada = Color(cor_fachada.r * tinta.r, cor_fachada.g * tinta.g, cor_fachada.b * tinta.b)
	var cor_calcada := _cor_do_material(&"calcada")
	var cor_grama := _cor_do_material(&"grama")
	var cor_copa := COR_COPA
	var passo := TAM / lado
	var saida := PackedByteArray()
	saida.resize(lado * lado * BYTES)
	for pz in lado:
		for px in lado:
			var x := (px + 0.5) * passo
			var z := (pz + 0.5) * passo
			var chao := Relevo.altura(cx * TAM + x, cz * TAM + z)
			var topo := chao
			var cor := COR_QUINTAL
			var parede := Color.BLACK
			var cls := Classe.CHAO
			if not lim.has_point(Vector2(x, z)):
				# Rua ou calcada: asfalto ate a meia pista de cada lado.
				cor = cor_calcada
				if _no_asfalto(b, x, z):
					cor = COR_ASFALTO
				else:
					topo += 0.15
			elif uso == MalhaUrbana.Uso.EDIFICADO:
				var lote := _lote_de(faces, lim, x, z)
				if lote >= 0:
					var h := _sorteio(cx, cz, lote)
					var n := clampi(andares + (h % 3) - 1, 1, 12)
					topo = chao + n * KitModular.ALTURA_ANDAR + 0.6
					# Telhado por lote: a cidade mistura telha, laje pintada e
					# laje crua (na casa, mais telha).
					var t := (h / 11) % 10
					var telha := 6 if casa else 3
					cor = COR_TELHA if t < telha else (COR_LAJE_CLARA if t < 8 else COR_LAJE)
					parede = cor_fachada.lerp(cor_fachada * 0.85, float((h / 7) % 3) / 2.0)
					if not paredes.is_empty():
						parede = paredes[h % paredes.size()]
					if not telhados.is_empty():
						cor = telhados[(h / 13) % telhados.size()]
					cls = Classe.PREDIO | TEM_PAREDE
			elif uso == MalhaUrbana.Uso.PARQUE:
				cor = cor_grama
				if _sorteio(cx, cz, pz * lado + px) % 4 == 0:
					topo = chao + 7.0
					cor = cor_copa
					cls = Classe.COPA
			else:
				cor = cor_grama.lerp(COR_QUINTAL, 0.5)
				if _sorteio(cx, cz, pz * lado + px) % 11 == 0:
					topo = chao + 5.0
					cor = cor_copa
					cls = Classe.COPA
			var o := (pz * lado + px) * BYTES
			saida.encode_s16(o, clampi(roundi(topo * 10.0), -32767, 32767))
			saida.encode_s16(o + 2, clampi(roundi(chao * 10.0), -32767, 32767))
			_por_cor(saida, o + 4, cor)
			_por_cor(saida, o + 7, parede)
			saida[o + 10] = cls
	return saida


## O ponto esta na pista de alguma rua da borda do chunk?
static func _no_asfalto(b: Dictionary, x: float, z: float) -> bool:
	if b["x0"] != MalhaUrbana.Via.NENHUMA and x < MalhaUrbana.meia_asfalto(b["x0"]):
		return true
	if b["x1"] != MalhaUrbana.Via.NENHUMA and x > TAM - MalhaUrbana.meia_asfalto(b["x1"]):
		return true
	if b["z0"] != MalhaUrbana.Via.NENHUMA and z < MalhaUrbana.meia_asfalto(b["z0"]):
		return true
	if b["z1"] != MalhaUrbana.Via.NENHUMA and z > TAM - MalhaUrbana.meia_asfalto(b["z1"]):
		return true
	return false


## Indice do lote da fileira sob o ponto (faixa de PROF_PREDIO m atras de cada
## face de rua, lotes de LOTE m ao longo dela), ou -1 no miolo.
static func _lote_de(faces: Array[Dictionary], lim: Rect2, x: float, z: float) -> int:
	for i in faces.size():
		var f: Dictionary = faces[i]
		var canto: Vector3 = f["canto"]
		var eixo: Vector3 = f["eixo"]
		var ao_longo := (x - canto.x) * eixo.x + (z - canto.z) * eixo.z
		if ao_longo < 0.0 or ao_longo > float(f["comprimento"]):
			continue
		var fundo := 0.0
		match int(f["direcao"]):
			0: fundo = lim.end.y - z
			1: fundo = lim.end.x - x
			2: fundo = z - lim.position.y
			3: fundo = x - lim.position.x
		if fundo >= 0.0 and fundo < ChunkBuilder.PROF_PREDIO:
			return i * 16 + floori(ao_longo / LOTE)
	return -1


static func _sorteio(cx: int, cz: int, k: int) -> int:
	return absi(hash(Vector3i(cx, cz, k)))
