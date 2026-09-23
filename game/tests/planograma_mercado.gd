## A loja arrumada, conferida sem abrir a loja.
##
##     godot --headless --path game --script res://tests/planograma_mercado.gd
##
## PLANO_MERCADO_AAA, F2. O que se mede:
##   - toda vaga cabe na face dela, no comprimento e na altura livre do nivel,
##     e duas vagas do mesmo nivel nao se sobrepoem;
##   - a regra da loja: cigarro so atras do balcao, cerveja so na geladeira,
##     doce e chiclete no caixa, pesado embaixo (nenhum dois litros acima do
##     primeiro nivel da ilha, porque nao cabe);
##   - a mira: varrendo cada nivel de cada face a cada 2 cm, a coluna devolvida
##     e SEMPRE a mais proxima do ponto — 100% dos pontos, criterio F2;
##   - a conservacao: tirar e por pelo EstoqueMercado, com o que falta nas
##     prateleiras igual ao que esta nos destinos.
##   - todo produto do catalogo tem rotulo e etiqueta no atlas.
##
## Sai com codigo 1 em qualquer falha.
extends SceneTree

var _falhas: PackedStringArray = []
var _medidas: Dictionary = {}


func _initialize() -> void:
	# Um quadro: os autoloads (WorldState) terminam de nascer antes do _ready.
	process_frame.connect(_rodar, CONNECT_ONE_SHOT)


func _falha(texto: String) -> void:
	_falhas.append(texto)
	if _falhas.size() <= 25:
		printerr("FALHA  " + texto)


func _rodar() -> void:
	var PG: GDScript = load("res://src/world/mercado/planograma.gd")
	var CM: GDScript = load("res://src/world/mercado/catalogo_mercado.gd")
	var RA: GDScript = load("res://src/world/mercado/rotulos_atlas.gd")
	var EM: GDScript = load("res://src/world/mercado/estoque_mercado.gd")

	# --- catalogo e atlas ---
	var ids := {}
	for p: Dictionary in CM.PRODUTOS:
		if ids.has(p["id"]):
			_falha("id repetido no catalogo: %s" % p["id"])
		ids[p["id"]] = true
		if not RA.IDS.has(String(p["id"])):
			_falha("sem rotulo no atlas: %s" % p["id"])
		if int(p["preco"]) <= 0:
			_falha("sem preco: %s" % p["id"])
	_medidas["produtos"] = CM.PRODUTOS.size()
	if CM.reais(149) != "R$ 1,49" or CM.reais(123456) != "R$ 1.234,56" or CM.reais(5) != "R$ 0,05":
		_falha("reais() formata errado: %s %s %s" % [CM.reais(149), CM.reais(123456), CM.reais(5)])

	for semente: int in [77451, 1, 90210, 424242]:
		_conferir_loja(PG, CM, semente)
	_conferir_estoque(PG, EM, 77451)

	for k: String in _medidas:
		print("%s=%s" % [k, _medidas[k]])
	if _falhas.is_empty():
		print("OK: a loja tem lugar para cada coisa, e cada coisa no lugar.")
		quit(0)
	else:
		print("%d falhas" % _falhas.size())
		quit(1)


func _conferir_loja(PG: GDScript, CM: GDScript, semente: int) -> void:
	var plano: Dictionary = PG.montar(semente)
	var faces: Array = plano["faces"]
	var vagas: Array = plano["vagas"]
	var por_face := {}
	var frentes := 0
	var unidades := 0
	var skus := {}
	for vi in vagas.size():
		var v: Dictionary = vagas[vi]
		var f: Dictionary = faces[int(v["face"])]
		var p: Dictionary = CM.produto(v["sku"])
		var md: Vector3 = CM.medida(v["sku"])
		var niveis: Array = f["niveis"]
		var n := int(v["nivel"])
		skus[v["sku"]] = true
		frentes += int(v["frentes"])
		for q: int in v["colunas"]:
			unidades += q
		(por_face.get_or_add(int(v["face"]), []) as Array).append(vi)
		# comprimento
		var x1 := float(v["x0"]) + float(v["passo"]) * float(v["frentes"])
		if float(v["x0"]) < -0.001 or x1 > float(f["comprimento"]) + 0.001:
			_falha("[%d] vaga %d (%s) sai da face %s: %.3f..%.3f de %.3f" % [semente, vi,
				v["sku"], f["nome"], v["x0"], x1, f["comprimento"]])
		# altura livre
		var topo: float = (float(niveis[n + 1]) - PG.CHAPA) if n + 1 < niveis.size() else float(f["teto"])
		if float(niveis[n]) + md.y > topo + 0.001:
			_falha("[%d] %s nao cabe no nivel %d de %s (%.2f m em %.2f m)" % [semente,
				v["sku"], n, f["nome"], md.y, topo - float(niveis[n])])
		# fundo
		if float(v["fundo"]) * (md.z + PG.FOLGA) > float(f["prof"]) + 0.02 and int(v["fundo"]) > 1:
			_falha("[%d] %s: %d unidades nao cabem em %.2f m" % [semente, v["sku"], v["fundo"], f["prof"]])
		# regra da loja
		var onde := int(p["onde"])
		var tipo := int(f["tipo"])
		var cat: StringName = p["cat"]
		if cat == &"cigarro" and tipo != PG.Tipo.CIGARRO:
			_falha("[%d] cigarro fora do balcao: %s em %s" % [semente, v["sku"], f["nome"]])
		if cat == &"cerveja" and tipo != PG.Tipo.GELADEIRA:
			_falha("[%d] cerveja quente: %s em %s" % [semente, v["sku"], f["nome"]])
		if onde == CM.Onde.CAIXA and tipo != PG.Tipo.BALEIRO:
			_falha("[%d] impulso fora do caixa: %s em %s" % [semente, v["sku"], f["nome"]])
		if tipo == PG.Tipo.GELADEIRA and not CM.cabe_em(v["sku"], CM.Onde.GELADEIRA):
			_falha("[%d] %s nao vai na geladeira" % [semente, v["sku"]])
	# sobreposicao
	for fi: int in por_face:
		var lista: Array = por_face[fi]
		for a in lista.size():
			for b in range(a + 1, lista.size()):
				var va: Dictionary = vagas[lista[a]]
				var vb: Dictionary = vagas[lista[b]]
				if int(va["nivel"]) != int(vb["nivel"]):
					continue
				var a0 := float(va["x0"])
				var a1 := a0 + float(va["passo"]) * float(va["frentes"])
				var b0 := float(vb["x0"])
				var b1 := b0 + float(vb["passo"]) * float(vb["frentes"])
				if a0 < b1 - 0.001 and b0 < a1 - 0.001:
					_falha("[%d] vagas %d e %d se sobrepoem em %s" % [semente, lista[a],
						lista[b], faces[fi]["nome"]])
	# toda face de gondola tem produto
	for f: Dictionary in faces:
		if not por_face.has(int(f["id"])):
			_falha("[%d] face vazia: %s" % [semente, f["nome"]])

	# a mira: varredura de 2 cm
	var pontos := 0
	var certos := 0
	var aceita := func(_v: Dictionary, _c: int) -> bool: return true
	for f: Dictionary in faces:
		var lista: Array = por_face.get(int(f["id"]), [])
		var niveis: Array = f["niveis"]
		for n in niveis.size():
			var y := float(niveis[n]) + 0.03
			var x := 0.0
			while x <= float(f["comprimento"]):
				var alvo: Vector2i = PG.coluna_no_ponto(f, lista, vagas, Vector2(x, y), aceita, 99.0)
				# a resposta certa, pela forca bruta
				var melhor := Vector2i(-1, -1)
				var menor := 99.0
				for vi: int in lista:
					var v: Dictionary = vagas[vi]
					if int(v["nivel"]) != n:
						continue
					for c in int(v["frentes"]):
						var d := absf(float(v["x0"]) + float(v["passo"]) * (float(c) + 0.5) - x)
						if d < menor:
							menor = d
							melhor = Vector2i(vi, c)
				pontos += 1
				# Empate (o ponto no meio exato de duas colunas) vale as duas: o
				# Vector2 da mira e float32 e desempata diferente daqui.
				var d_alvo := 99.0
				if alvo.x >= 0:
					var va: Dictionary = vagas[alvo.x]
					d_alvo = absf(float(va["x0"]) + float(va["passo"]) * (float(alvo.y) + 0.5) - x)
				if alvo == melhor or absf(d_alvo - menor) < 0.001:
					certos += 1
				elif _falhas.size() < 25:
					_falha("[%d] mira em %s nivel %d x=%.2f deu %s, devia %s" % [semente,
						f["nome"], n, x, alvo, melhor])
				x += 0.02
	if semente == 77451:
		_medidas["faces"] = faces.size()
		_medidas["vagas"] = vagas.size()
		_medidas["frentes"] = frentes
		_medidas["unidades"] = unidades
		_medidas["skus_na_loja"] = skus.size()
		_medidas["mira_pontos"] = pontos
		_medidas["mira_certos_pct"] = snappedf(100.0 * float(certos) / maxf(1.0, float(pontos)), 0.01)


func _conferir_estoque(PG: GDScript, EM: GDScript, semente: int) -> void:
	var WS: Node = root.get_node_or_null(^"WorldState")
	if WS == null:
		_falha("WorldState nao carregou: a conservacao nao foi medida")
		return
	var plano: Dictionary = PG.montar(semente)
	var vagas: Array = plano["vagas"]
	var total_antes := 0
	for v: Dictionary in vagas:
		for q: int in v["colunas"]:
			total_antes += q
	# Pega dez unidades de colunas cheias, devolve quatro, e confere.
	var tiradas: Array[Vector2i] = []
	for vi in vagas.size():
		if tiradas.size() >= 10:
			break
		var cols: PackedInt32Array = vagas[vi]["colunas"]
		if cols[0] > 0 and EM.tirar(semente, vagas, vi, 0, EM.Destino.MAO):
			tiradas.append(Vector2i(vi, 0))
	for k in 4:
		if not EM.por(semente, vagas, tiradas[k].x, 0, EM.Destino.MAO):
			_falha("devolver %s falhou" % tiradas[k])
	var total_depois := 0
	for v: Dictionary in vagas:
		for q: int in v["colunas"]:
			total_depois += q
	var fora := 0
	var s: Dictionary = EM.saidas(semente)
	for d: int in s:
		fora += int(s[d])
	_medidas["conservacao_faltam"] = total_antes - total_depois
	_medidas["conservacao_nos_destinos"] = fora
	if total_antes - total_depois != fora or fora != 6:
		_falha("conservacao: faltam %d nas prateleiras e ha %d nos destinos (esperado 6)"
			% [total_antes - total_depois, fora])
	# Um save: a loja montada de novo e o estoque aplicado dao o mesmo numero.
	var de_novo: Dictionary = PG.montar(semente)
	var vagas2: Array = de_novo["vagas"]
	EM.aplicar(semente, vagas2)
	var total_recarga := 0
	for v: Dictionary in vagas2:
		for q: int in v["colunas"]:
			total_recarga += q
	if total_recarga != total_depois:
		_falha("recarga: %d unidades depois de aplicar o salvo, %d antes" % [total_recarga, total_depois])
	# Devolver numa coluna cheia nao cabe.
	for vi in vagas2.size():
		var v: Dictionary = vagas2[vi]
		var cols: PackedInt32Array = v["colunas"]
		if cols[0] == int(v["fundo"]):
			if EM.por(semente, vagas2, vi, 0, EM.Destino.MAO):
				_falha("coluna cheia aceitou mais uma")
			break
