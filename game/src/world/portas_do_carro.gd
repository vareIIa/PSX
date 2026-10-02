## As duas portas da frente que abrem de verdade, na dobradica (Missao 1).
##
## Por que recortar a lataria, e nao pendurar uma porta por cima
## ---------------------------------------------------------------
## A porta do carro da rua e chapa do casco: nao existe como peca. Uma porta
## nova colada por fora deixaria a velha no lugar quando ela abre — duas portas,
## uma aberta e uma fechada, no mesmo carro. Aqui a porta e o PROPRIO pedaco de
## chapa e de vidro entre as duas frestas que o casco ja recorta
## (`Carroceria.porta_dianteira`): fechada, ela e o mesmo triangulo no mesmo
## lugar, e nao ha costura nenhuma para achar.
##
## O que custa, e quando
## ---------------------
## Com as duas portas fechadas o carro usa a malha inteira de sempre e este no
## fica invisivel: zero chamada de desenho a mais com o carro parado. So quando
## uma porta comeca a abrir a lataria troca pela versao sem as duas portas, e
## as portas (chapa e vidro) e o forro de dentro aparecem. Quando a ultima
## fecha, volta tudo. O recorte e feito uma vez por carro, dos dados de CPU que
## a `Carroceria` ja devolve (`lataria_dados`), sem ler malha da GPU.
##
## O forro
## -------
## O casco tem as faces viradas para fora. Pelo vao da porta aberta se veria o
## lado de dentro da chapa do outro lado — que e cullado —, e o carro viraria um
## tubo oco com a rua atras. Por isso a versao aberta leva um forro escuro: as
## faces da cabine viradas para dentro, uns centimetros para dentro da chapa. A
## porta leva o verso dela do mesmo jeito. Com a cabine do jogador montada (ele
## e o carona) o forro some, porque a cabine tem o dela.
class_name PortasDoCarro
extends Node3D

## Quanto a porta abre, em graus. Porta de sedan da epoca para no limitador
## por volta de 60.
const ABRE_GRAUS := 62.0
## O forro e o verso da porta ficam isto para dentro da chapa.
const ESPESSURA := 0.03
## Cor do forro visto pelo vao: courvin escuro, mais escuro que a cabine porque
## e visto de fora, contra a rua.
const COR_FORRO := Color(0.10, 0.095, 0.09)
## Uma porta e de um lado so se o triangulo olha para fora daquele lado. 0,55
## pega a chapa e o vidro inclinado da estufa e deixa o teto de fora.
const NORMAL_DE_LADO := 0.55
## Friso, macaneta e retrovisor sao caixas: as faces de cima e de baixo nao
## olham para o lado, mas ficam na largura cheia. Ficam com a porta tambem.
const FOLGA_LARGURA := 0.04

var _lataria: MeshInstance3D
var _inteira: Mesh
var _sem_portas: ArrayMesh
var _forro: MeshInstance3D
## Por banco (0 motorista, 1 passageiro): o no da dobradica e a abertura de 0 a 1.
var _dobradicas: Array[Node3D] = [null, null]
var _abertura := PackedFloat32Array([0.0, 0.0])
var _lado := PackedFloat32Array([-1.0, 1.0])
var _vao: Dictionary = {}
var _pronta := false
var _invalida := false
var _cabine_montada := false


## Recorta a lataria do carro. Devolve se ha porta (carro sem dados de CPU, ou
## sem chapa no vao, fica sem).
func preparar(lataria: MeshInstance3D, medidas: Dictionary) -> bool:
	if _pronta:
		return true
	if _invalida:
		return false
	_lataria = lataria
	_inteira = lataria.mesh
	var dados: Dictionary = medidas.get("lataria_dados", {})
	var vidro: Dictionary = medidas.get("vidro_dados", {})
	var porta: Dictionary = medidas.get("porta", {})
	if dados.is_empty() or porta.is_empty():
		return false
	var meia := float(medidas["largura"]) * 0.5
	_vao = {
		"z0": float(porta["z0"]), "z1": float(porta["z1"]),
		"y0": float(porta["y0"]), "y1": float(medidas["altura"]) - 0.02,
		"meia": meia,
		# A cabine: da base do para-brisa a base do vigia, para o forro nao
		# pagar triangulo de capo e de porta-malas.
		"cab0": float(porta["z0"]) - 0.15,
		"cab1": float(porta["z1"]) + 1.4,
	}
	var chapa := repartir(dados, _vao)
	var vidros := repartir(vidro, _vao) if not vidro.is_empty() else [
		PSXMesh.dados_vazios(), PSXMesh.dados_vazios(), PSXMesh.dados_vazios()]
	if PSXMesh.dados_vazio(chapa[1]) and PSXMesh.dados_vazio(chapa[2]):
		return false

	_sem_portas = Carroceria.malha([[chapa[0], Carroceria.MATERIAL],
		[vidros[0], Carroceria.MATERIAL_VIDRO]])
	var forro := forro_de(chapa[0], _vao, ESPESSURA)
	if not PSXMesh.dados_vazio(forro):
		_forro = MeshInstance3D.new()
		_forro.name = "Forro"
		_forro.mesh = Carroceria.malha([[forro, Carroceria.MATERIAL]])
		_forro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_forro)

	for b in 2:
		var s := _lado[b]
		var dob := Node3D.new()
		dob.name = "Dobradica%s" % ("Motorista" if b == 0 else "Passageiro")
		# Na quina da frente da porta, rente a chapa: girando ali a borda da
		# frente fica no lugar e a de tras sai para fora, como a de verdade.
		var eixo := Vector3(s * meia, 0.0, float(_vao["z0"]))
		dob.position = eixo
		add_child(dob)
		var mi := MeshInstance3D.new()
		mi.name = "Porta"
		var verso := forro_de(chapa[b + 1], {}, ESPESSURA * 0.7)
		mi.mesh = Carroceria.malha([[chapa[b + 1], Carroceria.MATERIAL],
			[vidros[b + 1], Carroceria.MATERIAL_VIDRO],
			[verso, Carroceria.MATERIAL]])
		mi.position = -eixo
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dob.add_child(mi)
		_dobradicas[b] = dob
	visible = false
	_pronta = true
	return true


func pronta() -> bool:
	return _pronta


## 0 fechada, 1 aberta ate o limitador.
func abertura(banco: int) -> float:
	return _abertura[banco]


## Poe a porta numa abertura, de 0 a 1, e troca a lataria quando precisa.
func pousar(banco: int, f: float) -> void:
	if not _pronta:
		return
	_abertura[banco] = clampf(f, -0.05, 1.08)
	var dob := _dobradicas[banco]
	# Lado +X abre girando +Y (a borda de tras vai para +X); lado -X, o espelho.
	dob.rotation = Vector3(0.0, _lado[banco] * deg_to_rad(ABRE_GRAUS) * _abertura[banco], 0.0)
	_trocar()


## A cabine do jogador entrou ou saiu: ela tem forro proprio.
func cabine_montada(sim: bool) -> void:
	_cabine_montada = sim
	_trocar()


func _trocar() -> void:
	var aberta := absf(_abertura[0]) > 0.002 or absf(_abertura[1]) > 0.002
	visible = aberta
	if _forro != null:
		_forro.visible = not _cabine_montada
	if _lataria != null and is_instance_valid(_lataria):
		_lataria.mesh = _sem_portas if aberta else _inteira


## A lataria amassou (so o carro do jogador amassa). A porta recortada dos
## dados de fabrica nao bate mais com a chapa: as portas param de abrir neste
## carro, e o que estiver aberto fecha na hora.
func invalidar() -> void:
	_invalida = true
	if not _pronta:
		return
	if _lataria != null and is_instance_valid(_lataria) and _lataria.mesh == _sem_portas:
		_lataria.mesh = _inteira
	for f: Node in get_children():
		f.queue_free()
	_dobradicas = [null, null]
	_abertura = PackedFloat32Array([0.0, 0.0])
	_forro = null
	visible = false
	_pronta = false


## Onde fica a quina de tras da porta, no espaco do carro, com ela fechada.
func traseira_da_porta(banco: int) -> Vector3:
	return Vector3(_lado[banco] * float(_vao.get("meia", 0.85)), 0.0,
		float(_vao.get("z1", 0.4)))


## O meio do vao, no espaco do carro.
func meio_do_vao(banco: int) -> Vector3:
	return Vector3(_lado[banco] * float(_vao.get("meia", 0.85)),
		(float(_vao.get("y0", 0.35)) + float(_vao.get("y1", 1.3))) * 0.5,
		(float(_vao.get("z0", -0.8)) + float(_vao.get("z1", 0.4))) * 0.5)


# --- recorte -------------------------------------------------------------------

## Reparte os triangulos em [resto, porta do motorista (-X), porta do passageiro
## (+X)]. Pelo centro do triangulo: o casco ja e recortado nas frestas, entao
## nenhum triangulo atravessa a borda da porta.
static func repartir(d: Dictionary, vao: Dictionary) -> Array[Dictionary]:
	var v: PackedVector3Array = d["v"]
	var n: PackedVector3Array = d["n"]
	var uvs: PackedVector2Array = d["uv"]
	var uv2: PackedVector2Array = d.get("uv2", PackedVector2Array())
	var cores: PackedColorArray = d["c"]
	var idx: PackedInt32Array = d["i"]
	var meia := float(vao["meia"])
	# Tres saidas, cada uma com os arrays em variavel local: arrays empacotados
	# dentro de dicionario sao copiados na leitura, e `d["v"].append` escreveria
	# numa copia que ninguem ve.
	var sv: Array[PackedVector3Array] = [PackedVector3Array(), PackedVector3Array(), PackedVector3Array()]
	var sn: Array[PackedVector3Array] = [PackedVector3Array(), PackedVector3Array(), PackedVector3Array()]
	var su: Array[PackedVector2Array] = [PackedVector2Array(), PackedVector2Array(), PackedVector2Array()]
	var su2: Array[PackedVector2Array] = [PackedVector2Array(), PackedVector2Array(), PackedVector2Array()]
	var sc: Array[PackedColorArray] = [PackedColorArray(), PackedColorArray(), PackedColorArray()]
	var si: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array(), PackedInt32Array()]
	var mapas: Array[Dictionary] = [{}, {}, {}]
	for t in range(0, idx.size(), 3):
		var centro := (v[idx[t]] + v[idx[t + 1]] + v[idx[t + 2]]) / 3.0
		var normal := n[idx[t]] + n[idx[t + 1]] + n[idx[t + 2]]
		var k := 0
		if centro.z > float(vao["z0"]) and centro.z < float(vao["z1"]) \
				and centro.y > float(vao["y0"]) and centro.y < float(vao["y1"]) \
				and absf(centro.x) > meia * 0.45:
			var s := signf(centro.x)
			var de_lado := normal.length_squared() > 1e-8 \
				and normal.normalized().x * s > NORMAL_DE_LADO
			if de_lado or absf(centro.x) > meia - FOLGA_LARGURA:
				k = 1 if s < 0.0 else 2
		var mapa := mapas[k]
		for q in 3:
			var o := idx[t + q]
			if not mapa.has(o):
				mapa[o] = sv[k].size()
				sv[k].append(v[o])
				sn[k].append(n[o])
				su[k].append(uvs[o])
				su2[k].append(uv2[o] if o < uv2.size() else Vector2.ZERO)
				sc[k].append(cores[o])
			si[k].append(int(mapa[o]))
	var saidas: Array[Dictionary] = []
	for k in 3:
		saidas.append({"v": sv[k], "n": sn[k], "uv": su[k], "uv2": su2[k],
			"c": sc[k], "i": si[k]})
	return saidas


static func _vazio() -> Dictionary:
	return {"v": PackedVector3Array(), "n": PackedVector3Array(),
		"uv": PackedVector2Array(), "uv2": PackedVector2Array(),
		"c": PackedColorArray(), "i": PackedInt32Array()}


## O verso das faces, para dentro: forro da cabine (com `vao`, so os da cabine)
## ou verso da porta (sem `vao`, todos). Mesma posicao recuada pela normal,
## giro trocado, cor e classe de forro.
static func forro_de(d: Dictionary, vao: Dictionary, recuo: float) -> Dictionary:
	var out := _vazio()
	var v: PackedVector3Array = d["v"]
	var n: PackedVector3Array = d["n"]
	var idx: PackedInt32Array = d["i"]
	var celula := Carroceria.uv(Carroceria.C_FUNDO)
	var uv := celula.position + celula.size * 0.5
	var classe := Vector2(float(Carroceria.Classe.FORRO), 0.0)
	var ov: PackedVector3Array = out["v"]
	var on: PackedVector3Array = out["n"]
	var ouv: PackedVector2Array = out["uv"]
	var ouv2: PackedVector2Array = out["uv2"]
	var oc: PackedColorArray = out["c"]
	var oi: PackedInt32Array = out["i"]
	for t in range(0, idx.size(), 3):
		var tri := [idx[t], idx[t + 2], idx[t + 1]]
		if not vao.is_empty():
			var centro := (v[tri[0]] + v[tri[1]] + v[tri[2]]) / 3.0
			if centro.z < float(vao["cab0"]) or centro.z > float(vao["cab1"]):
				continue
		for o: int in tri:
			var nn := n[o].normalized() if n[o].length_squared() > 1e-8 else Vector3.UP
			oi.append(ov.size())
			ov.append(v[o] - nn * recuo)
			on.append(-nn)
			ouv.append(uv)
			ouv2.append(classe)
			oc.append(COR_FORRO)
	out["v"] = ov
	out["n"] = on
	out["uv"] = ouv
	out["uv2"] = ouv2
	out["c"] = oc
	out["i"] = oi
	return out
