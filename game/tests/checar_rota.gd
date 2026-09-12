## Verificacao da rota por rua. Nivel 2.
##
##     godot --headless --path game --script res://tests/checar_rota.gd
##
## Roda so em cima da malha, sem montar um chunk: `Rota` e funcao pura da
## coordenada, e essa e exatamente a promessa que precisa ser provada — tracar
## caminho ate um endereco em rua onde ninguem pisou, do outro lado do bairro,
## com a cidade carregada num raio de 64 m.
##
## Mede o custo junto. Uma rota correta que come um quadro nao serve, e estimar
## custo e como este projeto ja perdeu tempo antes: `tests/custo_gps.gd` mediu
## 7,3 ms e so entao o raio do GPS foi escolhido.
extends SceneTree

## Pares origem/destino, em metros de mundo. Escolhidos para cair em situacoes
## diferentes da malha, e nao no caso facil.
const CASOS: Array[Dictionary] = [
	{"nome": "curta, mesma quadra", "de": Vector3(10, 0, 10), "para": Vector3(90, 0, 70)},
	{"nome": "media, atravessa avenida", "de": Vector3(20, 0, 20), "para": Vector3(330, 0, 190)},
	{"nome": "longa, 12 chunks", "de": Vector3(0, 0, 0), "para": Vector3(384, 0, 384)},
	{"nome": "coordenada negativa", "de": Vector3(-160, 0, -96), "para": Vector3(-420, 0, 130)},
	{"nome": "so no eixo X", "de": Vector3(0, 0, 0), "para": Vector3(320, 0, 0)},
	{"nome": "so no eixo Z", "de": Vector3(64, 0, -64), "para": Vector3(64, 0, 288)},
	{"nome": "atras, sentido invertido", "de": Vector3(500, 0, 500), "para": Vector3(120, 0, 60)},
]

var _falhas: PackedStringArray = []
var _total: int = 0


func _initialize() -> void:
	print("\n=== rota por rua ===\n")
	for caso: Dictionary in CASOS:
		_checar(caso)
	_medir_custo()
	_terminar()


func _checar(caso: Dictionary) -> void:
	var de: Vector3 = caso["de"]
	var para: Vector3 = caso["para"]
	var linha := Rota.tracar(de, para)
	var nome: String = caso["nome"]

	# 1. Existe rota. A malha e conexa por construcao — avenida a cada 160 m —
	#    entao nao achar caminho e bug, e nao geografia.
	_afirmar("%s: ha rota" % nome, linha.size() >= 2)
	if linha.size() < 2:
		return

	# 2. Comeca em quem pediu e termina no destino. Sem isto o desenho sairia
	#    comecando na esquina, a vinte metros de onde a pessoa esta.
	_afirmar("%s: comeca na origem" % nome,
		linha[0].is_equal_approx(Vector2(de.x, de.z)))
	_afirmar("%s: termina no destino" % nome,
		linha[linha.size() - 1].is_equal_approx(Vector2(para.x, para.z)))

	# 3. Cada trecho do meio anda SOBRE UMA RUA QUE EXISTE.
	#
	#    Esta e a assercao que conta, e a primeira versao dela estava errada:
	#    media o tamanho do trecho e reclamava de qualquer salto acima de cinco
	#    chunks. Mas `_simplificar` funde os pontos colineares de proposito —
	#    quatro esquinas seguidas em linha reta viram um trecho de 320 m, e isso
	#    e a rota descendo a avenida, nao um buraco.
	#
	#    O que precisa ser verdade nao e o comprimento: e que a linha por onde
	#    ela anda seja rua. Um trecho leste-oeste em z = j*32 so vale se
	#    `via_z(j)` existir; um norte-sul em x = i*32, se `via_x(i)` existir.
	for i in range(2, linha.size() - 1):
		var a := linha[i - 1]
		var b := linha[i]
		if is_zero_approx(b.y - a.y):
			var j := roundi(a.y / MalhaUrbana.TAM)
			_afirmar("%s: trecho %d corre sobre rua em z=%d" % [nome, i, j],
				MalhaUrbana.via_z(j) != MalhaUrbana.Via.NENHUMA)
		elif is_zero_approx(b.x - a.x):
			var gi := roundi(a.x / MalhaUrbana.TAM)
			_afirmar("%s: trecho %d corre sobre rua em x=%d" % [nome, i, gi],
				MalhaUrbana.via_x(gi) != MalhaUrbana.Via.NENHUMA)

	#    As duas pontas sao outra historia. Elas ligam em reta a posicao real ate
	#    a esquina mais perto, e essa reta nao e rua — mas quando o jogador ja
	#    esta EM CIMA de uma rua, `_simplificar` funde a ponta com o primeiro
	#    trecho e ela deixa de existir como ponta. Entao valem as duas formas: ou
	#    o trecho corre sobre rua, ou ele e curto o bastante para ser so a
	#    ligacao ate a esquina. A primeira versao desta assercao so aceitava a
	#    segunda e reprovava rota correta.
	var u := linha.size() - 1
	_afirmar("%s: ponta inicial e rua ou ligacao curta" % nome,
		_ponta_valida(linha[0], linha[1]))
	_afirmar("%s: ponta final e rua ou ligacao curta" % nome,
		_ponta_valida(linha[u], linha[u - 1]))

	# 4. Todo ponto do meio e cruzamento de verdade: cai em linha de grade nos
	#    dois eixos e as duas vias existem ali. E o que impede a rota de cortar
	#    quarteirao por dentro.
	for i in range(1, linha.size() - 1):
		var p := linha[i]
		var gi := roundi(p.x / MalhaUrbana.TAM)
		var gj := roundi(p.y / MalhaUrbana.TAM)
		var na_grade := is_equal_approx(p.x, float(gi) * MalhaUrbana.TAM) \
			and is_equal_approx(p.y, float(gj) * MalhaUrbana.TAM)
		_afirmar("%s: ponto %d esta na grade" % [nome, i], na_grade)
		if not na_grade:
			continue
		_afirmar("%s: ponto %d e cruzamento (%d,%d)" % [nome, i, gi, gj],
			MalhaUrbana.via_x(gi) != MalhaUrbana.Via.NENHUMA
			and MalhaUrbana.via_z(gj) != MalhaUrbana.Via.NENHUMA)

	# 5. Cada trecho do meio anda por UM eixo so. Diagonal nao existe nesta
	#    cidade, e uma rota em diagonal seria a rota atravessando predio.
	for i in range(2, linha.size() - 1):
		var d := linha[i] - linha[i - 1]
		_afirmar("%s: trecho %d anda num eixo so" % [nome, i],
			is_zero_approx(d.x) or is_zero_approx(d.y))

	# 6. Nao e absurdamente mais longa que a linha reta. Rua nao e reta, mas tres
	#    vezes a reta quer dizer que o A* deu a volta no bairro.
	var reta := Vector2(de.x, de.z).distance_to(Vector2(para.x, para.z))
	var anda := Rota.comprimento(linha)
	_afirmar("%s: %.0f m andando para %.0f m em reta (fator %.2f <= 3)"
		% [nome, anda, reta, anda / maxf(reta, 1.0)], anda <= reta * 3.0 + 64.0)

	# 7. Nao repete ponto. Rota que volta no proprio no desenha um no no mapa.
	for i in range(1, linha.size()):
		_afirmar("%s: ponto %d nao repete o anterior" % [nome, i],
			not linha[i].is_equal_approx(linha[i - 1]))

	# 8. `desvio` responde zero em cima da propria rota. E o numero que decide
	#    quando refazer o caminho; se ele mentir, a rota se refaz sozinha sem
	#    parar ou nunca se refaz.
	_afirmar("%s: desvio zero sobre a rota" % nome,
		Rota.desvio(linha, linha[linha.size() / 2]) < 0.01)

	print("-- %-28s %2d pontos, %5.0f m (reta %5.0f m)"
		% [nome, linha.size(), anda, reta])


## Ponta aceitavel: ou corre sobre uma rua de verdade, ou e curta o bastante
## para ser apenas a ligacao entre a pessoa e a esquina mais perto.
func _ponta_valida(a: Vector2, b: Vector2) -> bool:
	if a.distance_to(b) <= float(MalhaUrbana.PERIODO) * MalhaUrbana.TAM:
		return true
	if is_zero_approx(b.y - a.y):
		return MalhaUrbana.via_z(roundi(a.y / MalhaUrbana.TAM)) 			!= MalhaUrbana.Via.NENHUMA
	if is_zero_approx(b.x - a.x):
		return MalhaUrbana.via_x(roundi(a.x / MalhaUrbana.TAM)) 			!= MalhaUrbana.Via.NENHUMA
	return false


## Custo medido, e nao estimado. O numero que sai daqui entra no cabecalho de
## quem chamar a rota por quadro.
func _medir_custo() -> void:
	print("\n-- custo")
	for dist: float in [128.0, 384.0, 768.0]:
		var t0 := Time.get_ticks_usec()
		var voltas := 20
		for i in voltas:
			# Origem diferente a cada volta: medir a mesma consulta vinte vezes
			# mediria o cache do processador, e nao o algoritmo.
			var o := Vector3(float(i) * 7.0, 0.0, float(i) * 3.0)
			Rota.tracar(o, o + Vector3(dist, 0.0, dist * 0.6))
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / float(voltas)
		print("   %4.0f m -> %.2f ms por consulta" % [dist, ms])
		# Um quadro a 60 Hz tem 16,6 ms. A rota e tracada quando o jogador
		# escolhe destino, e nao por quadro — mas mesmo assim um engasgo visivel
		# no momento do toque e um engasgo.
		_afirmar("rota de %.0f m custa menos de 8 ms (%.2f)" % [dist, ms], ms < 8.0)


func _afirmar(msg: String, cond: bool) -> void:
	_total += 1
	if not cond:
		_falhas.append(msg)


func _terminar() -> void:
	print("")
	if _falhas.is_empty():
		print("OK — %d assercoes" % _total)
		quit(0)
		return
	print("FALHOU — %d de %d assercoes" % [_falhas.size(), _total])
	for f: String in _falhas:
		print("  x %s" % f)
	quit(1)
