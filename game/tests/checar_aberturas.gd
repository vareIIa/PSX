## As aberturas de vidro sao o MESMO vidro que a lataria desenha?
##
##     godot --headless --path game --script res://tests/checar_aberturas.gd
##
## Fase 1 do PLANO_CHUVA_CABINE_AAA. `Carroceria.montar` passou a devolver
## `"aberturas"`, e a cabine vai construir o interior em cima disso. Se a
## abertura sair de uma conta parecida — e nao da MESMA conta — o interior volta
## a ter vidro sobre chapa, que e o defeito que a Fase 1 existe para matar.
##
## O teste nao confia na leitura do codigo: pega a malha pronta do corpo, separa
## os triangulos que usam celula de vidro no atlas e cobra que cada canto de cada
## abertura caia em cima de um VERTICE desses triangulos, com folga de 1 mm.
extends SceneTree

## Folga em metros. Um milimetro: a conta e a mesma, entao o unico erro possivel
## e o de ponto flutuante.
const FOLGA := 0.001


func _initialize() -> void:
	var falhas := 0
	falhas += _auto_controle()
	for modelo: int in Carroceria.Modelo.values():
		falhas += _checar(modelo)
	print("")
	if falhas == 0:
		print("=== OK: toda abertura coincide com o vidro desenhado ===")
	else:
		print("=== FALHOU: %d abertura(s) fora do vidro desenhado ===" % falhas)
	quit(1 if falhas > 0 else 0)


## O teste sabe falhar?
##
## Um teste que so sabe passar nao vale nada — e este ja deu "OK" uma vez com o
## modulo do Marea sem carregar. Aqui um canto e deslocado 5 mm de proposito: se
## o comparador nao acusar, o resto da saida nao quer dizer nada.
func _auto_controle() -> int:
	var medidas := Carroceria.montar(Carroceria.Modelo.MAREA, Color.WHITE, 3)
	var vidros := _vertices_de_vidro(medidas["corpo"] as ArrayMesh)
	var a: Dictionary = (medidas["aberturas"] as Array)[0]
	var p: Vector3 = (a["pontos"] as PackedVector3Array)[0]
	var pegou_certo := _perto(p, vidros)
	var pegou_torto := _perto(p + Vector3(0.005, 0.0, 0.0), vidros)
	var ok := pegou_certo and not pegou_torto
	print("auto-controle: canto certo %s, canto 5 mm fora %s -> %s" % [
		"aceito" if pegou_certo else "RECUSADO",
		"recusado" if not pegou_torto else "ACEITO",
		"OK" if ok else "FALHOU (o teste nao sabe falhar)"])
	return 0 if ok else 1


func _checar(modelo: int) -> int:
	var medidas := Carroceria.montar(modelo, Color.WHITE, 3)
	var aberturas: Array = medidas["aberturas"]
	var vidros := _vertices_de_vidro(medidas["corpo"] as ArrayMesh)
	# Guarda contra o teste que nao sabe falhar: com a lista vazia dos dois
	# lados, o laco abaixo nao roda e o teste "passa". Foi o que aconteceu na
	# primeira execucao, com o modulo do Marea sem carregar.
	if aberturas.is_empty() or vidros.is_empty():
		print("modelo %d: SEM DADOS (%d aberturas, %d vertices de vidro) -> FALHOU"
			% [modelo, aberturas.size(), vidros.size()])
		return 1
	var fora := 0
	var area := 0.0
	var lados := {-1: 0, 0: 0, 1: 0}
	for a: Dictionary in aberturas:
		area += float(a["area"])
		lados[int(a["lado"])] = int(lados[int(a["lado"])]) + 1
		for p: Vector3 in (a["pontos"] as PackedVector3Array):
			if not _perto(p, vidros):
				fora += 1
		# A normal aponta para FORA: para a janela, para longe do eixo do carro;
		# para o para-brisa e o vigia, para cima da rampa.
		var n: Vector3 = a["normal"]
		var c: Vector3 = a["centro"]
		var esperado := Vector3(c.x, 0.0, 0.0).normalized() if int(a["lado"]) != 0 \
			else Vector3.UP
		if n.dot(esperado) <= 0.0:
			print("   normal para dentro em %s (lado %d)" % [a["tipo"], a["lado"]])
			fora += 1
	# Janela e coisa simetrica: o que houver de um lado tem de haver do outro.
	if lados[-1] != lados[1]:
		print("   lados desiguais: %d a esquerda, %d a direita" % [lados[-1], lados[1]])
		fora += 1
	var nomes := {}
	for a: Dictionary in aberturas:
		var t := String(a["tipo"])
		nomes[t] = int(nomes.get(t, 0)) + 1
	print("modelo %d: %d aberturas (%s), area %.2f m2, %d canto(s) fora do vidro desenhado -> %s" % [
		modelo, aberturas.size(), _resumo(nomes), area, fora,
		"OK" if fora == 0 else "FALHOU"])
	return fora


## Vertices dos triangulos que usam celula de vidro no atlas do carro.
func _vertices_de_vidro(malha: ArrayMesh) -> PackedVector3Array:
	var celulas := [
		Carroceria.uv(Carroceria.C_PARABRISA).grow(1.0 / Carroceria.ATLAS),
		Carroceria.uv(Carroceria.C_VIDRO_LADO).grow(1.0 / Carroceria.ATLAS),
		Carroceria.uv(Carroceria.C_VIDRO_TRAS).grow(1.0 / Carroceria.ATLAS),
	]
	var out := PackedVector3Array()
	for s in malha.get_surface_count():
		var arr := malha.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		for i in v.size():
			for c: Rect2 in celulas:
				if c.has_point(uv[i]):
					out.append(v[i])
					break
	return out


func _perto(p: Vector3, pontos: PackedVector3Array) -> bool:
	for q: Vector3 in pontos:
		if p.distance_to(q) <= FOLGA:
			return true
	return false


func _resumo(nomes: Dictionary) -> String:
	var partes: Array[String] = []
	for k: String in nomes:
		partes.append("%dx %s" % [nomes[k], k])
	partes.sort()
	return ", ".join(partes)
