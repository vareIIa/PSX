## Gerado por tools/baixar_rotulos.py. Nao editar a mao.
##
## Onde cada rotulo e cada etiqueta de preco esta no atlas `rotulos`
## (textures/rotulos.png no PS1, textures_hd/rotulos.jpg no MODERNO). UV de 0
## a 1, origem no canto de cima. Produto que nao esta aqui cai na celula 0.
class_name RotulosAtlas
extends RefCounted

const LADO := 2048.0
const PASTICHE := false
const IDS: PackedStringArray = ["coca_lata", "coca_2l", "guarana_lata", "guarana_2l", "fanta_lata", "fanta_2l", "sprite_lata", "kuat_2l", "pepsi_lata", "pepsi_2l", "soda_lata", "sukita_2l", "dolly_2l", "brahma_lata", "skol_lata", "antarctica_lata", "kaiser_lata", "schin_lata", "bohemia_lata", "brahma_600", "agua_crystal", "agua_minalba", "gatorade", "maguary", "tang", "kisuco", "danone", "danoninho", "yakult", "catupiry", "qualy", "doriana", "parmalat", "arroz", "feijao", "acucar", "sal", "miojo", "espaguete", "pomarola", "elefante", "hellmanns", "oleo", "sardinha", "maizena", "cafe_pilao", "cafe_melitta", "nescau", "toddy", "ninho", "trakinas", "passatempo", "negresco", "bono", "club_social", "piraque", "wafer", "ruffles", "cheetos", "fandangos", "doritos", "amendoim", "diamante_negro", "laka", "lacta_ao_leite", "classic", "garoto_ao_leite", "bombons_garoto", "bis", "sonho_de_valsa", "baton", "prestigio", "chokito", "serenata", "halls", "trident", "bubbaloo", "mentos", "pao_pullman", "bisnaguinha", "panetone", "colgate", "sorriso", "lux", "protex", "seda", "neutrox", "rexona", "papel_neve", "prestobarba", "always", "pampers", "detergente", "omo", "qboa", "bombril", "veja", "pinho_sol", "sabao_barra", "baygon", "esponja", "fosforo", "isqueiro", "pilha_rayovac", "pilha_duracell", "bandaid", "aspirina", "engov", "sonrisal", "cachaca_51", "velho_barreiro", "catuaba", "dreher", "orloff", "hollywood", "free", "derby", "marlboro", "carlton", "minister", "charm"]

static var _indice: Dictionary = {}


static func _k(id: StringName) -> int:
	if _indice.is_empty():
		for i in IDS.size():
			_indice[StringName(IDS[i])] = i
	return int(_indice.get(id, 0))


static func celula(id: StringName) -> Rect2:
	var k := _k(id)
	var x := float(k % 16) * 128.0 + 2.0
	var y := float(k / 16) * 128.0 + 2.0
	return Rect2(x / LADO, y / LADO, 124.0 / LADO, 124.0 / LADO)


static func etiqueta(id: StringName) -> Rect2:
	var k := _k(id)
	var x := float(k % 16) * 128.0 + 2.0
	var y := 1024.0 + float(k / 16) * 56.0 + 2.0
	return Rect2(x / LADO, y / LADO, 124.0 / LADO, 52.0 / LADO)
