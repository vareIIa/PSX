## Densidade de textura da cidade: o criterio A8 do PLANO_AAA_4K.
##
##     godot --headless --path game --script res://tests/medir_texel.gd
##
## Quanto detalhe de textura ha em cada metro de superficie. E o numero que a
## Fase 3 persegue: em 4K, uma parede a dois metros do olho ocupa centenas de
## pixels de tela, e se ela tem 200 px por metro o jogador ve o texel, nao o
## tijolo.
##
## Como se mede, e por que assim
## -----------------------------
## Nao da para ler a resposta da tabela de materiais: `uv_tile` sozinho nao diz
## nada sem saber quantos metros aquele quad cobre, e cada superficie da cidade
## e montada por uma funcao diferente do `KitModular`. Entao a medida sai da
## MALHA pronta: para cada triangulo, a area em METROS e a area em UV. A raiz da
## razao entre as duas, vezes o lado da textura, e quantos texels cabem num
## metro daquela superficie.
##
##     px/m = lado_da_textura * sqrt(area_uv / area_mundo)
##
## A media e ponderada pela area em metros: uma parede inteira pesa mais que um
## batente de porta, e e a parede que o jogador encosta o nariz.
extends SceneTree

## Chunks medidos. Tres bastam: a malha urbana e deterministica e o kit e o
## mesmo em toda a cidade — o que muda de um quarteirao para outro e quanto de
## cada superficie aparece, nao a densidade dela.
const CHUNKS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 2)]
## O alvo do criterio A8, em texels por metro.
const ALVO := 512.0


func _init() -> void:
	KitModular.preparar()
	var area: Dictionary = {}      # material -> m2
	var uv: Dictionary = {}        # material -> area em UV
	for coord: Vector2i in CHUNKS:
		var dados: Dictionary = ChunkBuilder.construir(coord.x, coord.y)
		var superficies: Dictionary = dados["superficies"]
		for nome: StringName in superficies:
			var d: Dictionary = superficies[nome]
			if PSXMesh.dados_vazio(d):
				continue
			var m := PSXMesh.dados_para_mesh(d)
			for s in m.get_surface_count():
				var arr := m.surface_get_arrays(s)
				_somar(arr, nome, area, uv)

	var nomes: Array[StringName] = []
	nomes.assign(area.keys())
	nomes.sort_custom(func(a: StringName, b: StringName) -> bool:
		return float(area[a]) > float(area[b]))

	print("[texel] superficie          m2   lado hoje   px/m   com HD   px/m HD")
	var soma_area := 0.0
	var soma_px := 0.0
	var abaixo := 0
	for nome: StringName in nomes:
		var m2 := float(area[nome])
		if m2 < 1.0:
			continue
		var lado := _lado_da_textura(nome)
		var razao := sqrt(float(uv[nome]) / m2)
		var px := lado * razao
		soma_area += m2
		soma_px += (1024.0 * razao if TexturasHD.tem(nome) else px) * m2
		if (1024.0 * razao if TexturasHD.tem(nome) else px) < ALVO:
			abaixo += 1
		var hd := TexturasHD.tem(nome)
		print("[texel] %-16s %7.0f %6d %9.0f %8s %9.0f"
			% [nome, m2, lado, px, "sim" if hd else "-",
				(1024.0 * razao) if hd else px])
	print("[texel] media ponderada por area, ja com o conjunto HD: %.0f px/m (alvo %.0f)"
		% [soma_px / maxf(soma_area, 0.001), ALVO])
	print("[texel] %d superficies abaixo do alvo" % abaixo)
	quit(0)


func _somar(arr: Array, nome: StringName, area: Dictionary, uv: Dictionary) -> void:
	var vert: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	if vert.is_empty() or uvs.is_empty():
		return
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null \
		else PackedInt32Array()
	var n := idx.size() if not idx.is_empty() else vert.size()
	var i := 0
	while i + 2 < n:
		var a := idx[i] if not idx.is_empty() else i
		var b := idx[i + 1] if not idx.is_empty() else i + 1
		var c := idx[i + 2] if not idx.is_empty() else i + 2
		var am := (vert[b] - vert[a]).cross(vert[c] - vert[a]).length() * 0.5
		var au := absf((uvs[b] - uvs[a]).cross(uvs[c] - uvs[a])) * 0.5
		if am > 0.0001 and au > 0.0000001:
			area[nome] = float(area.get(nome, 0.0)) + am
			uv[nome] = float(uv.get(nome, 0.0)) + au
		i += 3


## O lado da textura do material, em pixels. Quadrada em todas as do projeto.
func _lado_da_textura(nome: StringName) -> int:
	var caminho := "res://resources/materials/mat_%s.tres" % nome
	if not ResourceLoader.exists(caminho):
		return 0
	var mat := load(caminho) as ShaderMaterial
	if mat == null:
		return 0
	var tex := mat.get_shader_parameter(&"albedo_tex") as Texture2D
	return tex.get_width() if tex != null else 0
