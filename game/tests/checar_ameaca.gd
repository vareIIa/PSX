## Verificacao da primeira ameaca, sem montar a cidade.
##
##     godot --headless --path game --script res://tests/checar_ameaca.gd
##
## O que ele prova
## ---------------
## Que o golpe, no papel, alcança as duas capsulas; que o dano mata em tres
## pancadas quem acordou e em cinco quem esta cheio; que o sorteio planta
## inimigo no baldio/industrial e nenhum nos 96 m da abertura.
##
## Por que le o fonte em vez de `Inimigo.DANO`
## ------------------------------------------
## `Inimigo` e `Desmaio` falam com autoload (`Inventario`, `AudioDirector`).
## Em `--script` o autoload existe na arvore e nao como identificador, entao
## carregar essas classes quebra o teste. A constante e o contrato; le-la no
## arquivo e o mesmo gesto de `run_tests.gd` conferir `vertex_lighting` no
## shader.
extends SceneTree

var _falhas: PackedStringArray = []
var _total: int = 0


func _initialize() -> void:
	print("\n=== primeira ameaca ===\n")
	_contrato()
	_sorteio()
	print("")
	if _falhas.is_empty():
		print("OK — %d assercoes" % _total)
		quit(0)
		return
	print("FALHOU — %d de %d assercoes" % [_falhas.size(), _total])
	for f: String in _falhas:
		print("  x %s" % f)
	quit(1)


func _afirmar(msg: String, cond: bool) -> void:
	_total += 1
	if not cond:
		_falhas.append(msg)


func _contrato() -> void:
	var inimigo := FileAccess.get_file_as_string("res://src/world/inimigo.gd")
	var player := FileAccess.get_file_as_string("res://src/player/player.gd")
	var desmaio := FileAccess.get_file_as_string("res://src/systems/desmaio.gd")
	var estilo := FileAccess.get_file_as_string("res://src/ui/ui_estilo.gd")

	_afirmar("inimigo declara DANO 22", inimigo.contains("const DANO := 22"))
	_afirmar("inimigo declara ALCANCE_GOLPE 1.65",
		inimigo.contains("const ALCANCE_GOLPE := 1.65"))
	_afirmar("inimigo declara RAIO 0.36", inimigo.contains("const RAIO := 0.36"))
	_afirmar("jogador declara RAIO 0.32", player.contains("const RAIO := 0.32"))
	_afirmar("golpe alcança as duas capsulas (1.65 > 0.36+0.32)",
		1.65 > 0.36 + 0.32)
	_afirmar("tres pancadas derrubam quem acordou (22*2 < 45 <= 22*3)",
		22 * 2 < 45 and 22 * 3 >= 45)
	_afirmar("cinco pancadas derrubam vida cheia",
		22 * 4 < 100 and 22 * 5 >= 100)
	_afirmar("desmaio acorda com 45",
		desmaio.contains("const VIDA_AO_ACORDAR := 45"))
	_afirmar("desmaio perde 3 a 5 horas",
		desmaio.contains("const HORAS_PERDIDAS := Vector2(3.0, 5.0)"))
	_afirmar("desmaio na camada 200",
		desmaio.contains("const CAMADA := UiEstilo.CAMADA_APAGAO")
		and estilo.contains("const CAMADA_APAGAO := 200"))
	_afirmar("cidade monta o apagao",
		FileAccess.get_file_as_string("res://src/levels/cidade.gd")
			.contains("add_child(Desmaio.new())"))
	_afirmar("inimigo chama ferir", inimigo.contains("Inventario.ferir(DANO"))


func _sorteio() -> void:
	var total := 0
	var perto := 0
	var fora := 0
	const RAIO := 10
	for cz in range(-RAIO, RAIO + 1):
		for cx in range(-RAIO, RAIO + 1):
			var dados: Dictionary = ChunkBuilder.construir(cx, cz)
			var n := 0
			for bruto: Variant in dados["props"]:
				var p: Dictionary = bruto
				if str(p.get("tipo", "")) == "inimigo":
					n += 1
			total += n
			if maxi(absi(cx), absi(cz)) < 3:
				perto += n
			var quadra := MalhaUrbana.quadra_de(cx, cz)
			var d: int = int(quadra["distrito"])
			if d != MalhaUrbana.Distrito.BALDIO \
					and d != MalhaUrbana.Distrito.INDUSTRIAL:
				fora += n
	print("-- inimigos em %dx%d chunks: %d (abertura: %d, distrito errado: %d)"
			% [RAIO * 2 + 1, RAIO * 2 + 1, total, perto, fora])
	# O inimigo solto na rua esta desligado (ChunkBuilder.INIMIGO_NA_RUA): lia
	# como resto de teste. Ligado, o sorteio tem de plantar alguns.
	if ChunkBuilder.INIMIGO_NA_RUA:
		_afirmar("tem inimigo no mapa", total >= 4)
	else:
		_afirmar("nenhum inimigo solto na rua (desligado)", total == 0)
	_afirmar("nao lotou a cidade (%d <= 40)" % total, total <= 40)
	_afirmar("nenhum inimigo nos 96 m da abertura", perto == 0)
	_afirmar("nenhum inimigo fora de baldio/industrial", fora == 0)
