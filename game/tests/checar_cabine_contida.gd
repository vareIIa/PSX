## A cabine cabe dentro da lataria?
##
##     godot --headless --path game --script res://tests/checar_cabine_contida.gd
##
## Criterio C4 do PLANO_CHUVA_CABINE_AAA. O interior e desenhado por dentro de
## uma casca que a camera de fora tambem enxerga: qualquer peca que passe da
## chapa aparece em terceira pessoa como um pedaco de forro brotando do teto.
##
## Medido em 16/09/2026, antes da Fase 2, o forro do teto do Marea era uma face
## plana na altura maxima do carro e atravessava a lataria na frente da cabine:
## 20% do que se via de dentro era peca ALEM da chapa.
##
## O teste nao usa a malha da lataria — usa o PERFIL que a desenhou
## (`CarroceriaVarrida.x_casco`), que responde "qual a meia largura do carro
## nesta altura e neste Z". Cada vertice da cabine e comparado com esse numero.
extends SceneTree

## Folga aceita, em metros. O vidro e colado ate 1,2 cm por fora da chapa e as
## revelacoes de vao vao ate ele: elas TEM de chegar la, senao sobra fresta.
const FOLGA := 0.020


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var falhas := 0
	falhas += _auto_controle()
	for modelo: int in Carroceria.Modelo.values():
		falhas += _checar(modelo)
	print("")
	if falhas == 0:
		print("=== OK: nenhuma peca da cabine passa da lataria ===")
	else:
		print("=== FALHOU: %d modelo(s) com peca fora da lataria ===" % falhas)
	quit(1 if falhas > 0 else 0)


func _checar(modelo: int) -> int:
	var medidas := Carroceria.montar(modelo, CarroCena.TINTA, CarroCena.SEMENTE)
	var cab := CarroCabine.new()
	root.add_child(cab)
	cab.montar(medidas)
	var info: Dictionary = medidas["perfil_cabine"]
	var fora := 0
	var pior := 0.0
	var onde := Vector3.ZERO
	var total := 0
	var agua := 0
	for mi: MeshInstance3D in _malhas(cab):
		var xf := _ate(mi, cab)
		# A placa de agua presa a lente e as janelas chutadas da cabine antiga
		# sao MAIORES que o carro por construcao — a placa tem 1,78 m e fica
		# pendurada na camera. Elas saem na Fase 3, quando a agua passa a morar
		# no vidro de verdade; ate la, contam a parte.
		# O limpador mora do lado de FORA, no cowl: ele nao e peca de interior e
		# nao entra nesta conta.
		if _sob_limpador(mi, cab):
			continue
		var provisorio := mi.name == "AguaNoVidro" or mi.name.begins_with("Janela")
		for p: Vector3 in _vertices(mi.mesh):
			var d := _sobra(xf * p, info)
			if provisorio:
				if d > FOLGA:
					agua += 1
				continue
			total += 1
			if d > pior:
				pior = d
				onde = xf * p
			if d > FOLGA:
				fora += 1
	cab.queue_free()
	print("modelo %d: %d vertices de interior, %d fora da chapa; pior sobra %.3f m em %s (%d vertices da agua provisoria fora) -> %s" % [
		modelo, total, fora, pior, onde, agua, "OK" if fora == 0 else "FALHOU"])
	return 1 if fora > 0 else 0


## Quanto este ponto passa da chapa, em metros. Zero ou negativo = esta dentro.
func _sobra(p: Vector3, info: Dictionary) -> float:
	var perfil: Array = info["perfil"]
	var ombro: Vector2 = info["ombro"]
	var escala: Vector3 = info["escala"]
	# De volta ao espaco do modulo: desfaz a meia volta e a escala.
	var m := Vector3(-p.x / escala.x, p.y / escala.y, -p.z / escala.z)
	var meia := CarroceriaVarrida.x_casco_fino(perfil, ombro, m.z, m.y)
	var e := CarroceriaVarrida.estacao(perfil, m.z)
	var por_cima: float = m.y - e[CarroceriaVarrida.TOPO]
	var por_baixo: float = e[CarroceriaVarrida.BOT] - m.y
	return maxf(absf(m.x) - meia, maxf(por_cima, por_baixo)) * escala.x


## Meia largura do casco numa altura, achada por bisseccao.
##
## `CarroceriaVarrida.x_casco` responde a mesma pergunta amostrando treze `t` e
## ficando com o mais proximo — o bastante para posicionar friso, e nao para
## JULGAR contencao: nas partes curvas o erro chega a alguns centimetros, e o
## teste acusava a propria imprecisao como peca fora da chapa.
func _meia_no_y(e: Array, ombro: Vector2, y: float) -> float:
	var a := -1.0
	var b := 1.0
	if y <= CarroceriaVarrida.secao(e, a, ombro).y:
		return CarroceriaVarrida.secao(e, a, ombro).x
	if y >= CarroceriaVarrida.secao(e, b, ombro).y:
		return CarroceriaVarrida.secao(e, b, ombro).x
	for i in 28:
		var meio := (a + b) * 0.5
		if CarroceriaVarrida.secao(e, meio, ombro).y < y:
			a = meio
		else:
			b = meio
	return CarroceriaVarrida.secao(e, (a + b) * 0.5, ombro).x


## O teste sabe falhar? Um ponto meio metro fora da lateral tem de ser acusado.
func _auto_controle() -> int:
	var medidas := Carroceria.montar(Carroceria.Modelo.MAREA, Color.WHITE, 3)
	var info: Dictionary = medidas["perfil_cabine"]
	var dentro := _sobra(Vector3(0.0, 1.0, 0.0), info)
	var longe := _sobra(Vector3(-1.4, 1.0, 0.0), info)
	var ok := dentro <= 0.0 and longe > 0.4
	print("auto-controle: centro sobra %.3f, ponto a 1,4 m sobra %.3f -> %s" % [
		dentro, longe, "OK" if ok else "FALHOU (o teste nao sabe falhar)"])
	return 0 if ok else 1


## Esta malha esta pendurada num pivo de limpador?
func _sob_limpador(mi: Node, cab: Node) -> bool:
	var no: Node = mi
	while no != null and no != cab:
		if String(no.name).begins_with("Limpador"):
			return true
		no = no.get_parent()
	return false


func _malhas(no: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for f: Node in no.get_children():
		if f is MeshInstance3D and (f as MeshInstance3D).mesh != null:
			out.append(f)
		out.append_array(_malhas(f))
	return out


func _ate(mi: Node3D, cab: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var no: Node = mi
	while no != null and no != cab:
		if no is Node3D:
			xf = (no as Node3D).transform * xf
		no = no.get_parent()
	return xf


func _vertices(malha: Mesh) -> PackedVector3Array:
	var out := PackedVector3Array()
	for s in malha.get_surface_count():
		out.append_array(malha.surface_get_arrays(s)[Mesh.ARRAY_VERTEX])
	return out
