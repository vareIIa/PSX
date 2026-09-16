## Onde a palheta do limpador passa, de verdade, e quanto do vidro ela varre.
##
##     godot --headless --path game --script res://tests/medir_limpador.gd
##
## Por que existe
## --------------
## O criterio C7 do PLANO_CHUVA_CABINE_AAA, nas duas metades:
##
##   1. a ponta da palheta fica NO plano do vidro (<= 1 cm) no curso inteiro;
##   2. o leque cobre >= 70% da area do para-brisa VISTA PELO MOTORISTA.
##
## Medido em 16/09/2026, antes da Fase 3, a ponta ficava em (+/-0,30; 0,94;
## -1,355) no repouso, no meio e no fim do curso — parada, deitada no capo, 42 cm
## a frente da base do vidro. A palheta nascia ao longo de -Z e o pivo girava em
## Z, ou seja, em torno do proprio comprimento.
##
## Um angulo que muda nao prova movimento: o que prova e a PONTA. Ver a memoria
## do projeto "animacao se mede pela ponta".
##
## A segunda metade e medida no plano do vidro, em metros: uma grade sobre o
## retangulo do para-brisa, contando quantas celulas caem dentro de algum dos
## dois setores em algum ponto do curso.
extends SceneTree

## Passos de fase do limpador a medir, em fracao da passada de ida.
const PASSOS := [0.0, 0.25, 0.5, 0.75, 1.0]

## Grade da cobertura do leque, em celulas por eixo.
const GRADE := 64

## O criterio, para a linha final dizer OK ou FALHOU.
const MAX_FORA_DO_PLANO := 0.01
const MIN_LEQUE := 0.70


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var falhas := 0
	var medidos := 0
	for modelo: int in [Carroceria.Modelo.MAREA, Carroceria.Modelo.FUSCA,
			Carroceria.Modelo.SEDA]:
		var r := _medir(modelo)
		if r < 0:
			falhas += 1
		else:
			medidos += 1
			falhas += r
	# Sem isto, uma classe que nao compila faz o teste PASSAR por nao ter medido
	# nada. Ja aconteceu nesta mesma sonda: `Settings` nao existe em `--script`,
	# a cabine nao compilou, e a saida foi "C7 OK".
	if medidos == 0:
		print("\n=== FALHOU: nenhum modelo foi medido ===")
		quit(1)
		return
	if falhas > 0:
		print("\n=== FALHOU: %d criterio(s) de C7 ===" % falhas)
		quit(1)
		return
	print("\n=== C7 OK ===")
	quit(0)


func _medir(modelo: int) -> int:
	var medidas := Carroceria.montar(modelo, CarroCena.TINTA, CarroCena.SEMENTE)
	var cab := CarroCabine.new()
	if cab == null:
		print("\n=== modelo %d: CarroCabine NAO INSTANCIOU ===" % modelo)
		return -1
	root.add_child(cab)
	cab.montar(medidas)
	print("\n=== modelo %d ===" % modelo)

	var limpador := cab.limpadores()
	if limpador == null:
		print("  SEM LIMPADOR -> FALHOU")
		cab.queue_free()
		return 1
	var painel := _parabrisa(cab)
	if painel.is_empty():
		print("  SEM PARA-BRISA -> FALHOU")
		cab.queue_free()
		return 1
	var tam: Vector2 = painel["tam"]
	var raios := limpador.raios()
	print("  vidro %.2f x %.2f m, palheta de %.2f a %.2f m do pivo"
		% [tam.x, tam.y, raios.x, raios.y])

	# A palheta tem de estar na velocidade 2 para varrer sem pausa. Chuva 1 poe
	# o modo la; ver a histerese em `Limpador._escolher_modo`.
	var passada: float = Limpador.PASSADA[int(Limpador.Modo.VELOCIDADE_2)]
	var pior_fora := 0.0
	var visitados: Array[Vector3] = []
	var varrido := {}
	for k in PASSOS.size():
		var antes: float = 0.0 if k == 0 else float(PASSOS[k - 1])
		limpador.atualizar(1.0, 1.0, passada * (float(PASSOS[k]) - antes))
		_marcar(varrido, limpador, tam)
		for i in limpador.pivos().size():
			var no := limpador.get_node_or_null("Palheta%d" % i) as Node3D
			if no == null:
				continue
			# A ponta no espaco do carro, e dai a distancia ate o PLANO do vidro.
			var ponta: Vector3 = no.transform * Vector3(0.0, raios.y, 0.0)
			var n: Vector3 = painel["normal"]
			var fora := absf((ponta - (painel["origem"] as Vector3)).dot(n))
			# A palheta corre por FORA do vidro, entao o afastamento esperado e
			# `Limpador.FORA`; o que interessa e o desvio em relacao a ele.
			fora = absf(fora - Limpador.FORA)
			pior_fora = maxf(pior_fora, fora)
			if i == 0:
				visitados.append(ponta)
			print("  fase %.2f  Palheta%d  giro %+6.1f  ponta (%.3f, %.3f, %.3f)  fora do plano %.4f m"
				% [float(PASSOS[k]), i, no.rotation_degrees.z, ponta.x, ponta.y,
					ponta.z, fora])

	var caminho := 0.0
	for i in range(1, visitados.size()):
		caminho += visitados[i].distance_to(visitados[i - 1])
	# O criterio C7 fala da area "vista pelo motorista", e nao do vidro inteiro:
	# o que importa e enxergar a estrada, e o canto de cima do lado do
	# passageiro nunca foi caminho de nada. O motorista senta a ESQUERDA
	# (`CarroCabine.LADO_MOTORISTA` e negativo), e `u` cresce para a direita do
	# carro — entao o lado dele e a metade de baixo do `u`.
	var leque_todo := float(varrido.size()) / float(GRADE * GRADE)
	var meias := 0
	for chave: int in varrido:
		if chave % GRADE < GRADE / 2:
			meias += 1
	var leque := float(meias) / float(GRADE * GRADE / 2)
	var falhas := 0
	var v1 := "OK" if pior_fora <= MAX_FORA_DO_PLANO else "FALHOU"
	var v2 := "OK" if leque >= MIN_LEQUE else "FALHOU"
	if pior_fora > MAX_FORA_DO_PLANO:
		falhas += 1
	if leque < MIN_LEQUE:
		falhas += 1
	print("  -- a ponta percorreu %.3f m no curso inteiro" % caminho)
	print("  -- pior afastamento do plano do vidro: %.4f m (limite %.3f) -> %s"
		% [pior_fora, MAX_FORA_DO_PLANO, v1])
	print("  -- o leque cobriu %.1f%% do lado do motorista (limite %.0f%%) e %.1f%% do vidro inteiro -> %s"
		% [leque * 100.0, MIN_LEQUE * 100.0, leque_todo * 100.0, v2])
	cab.queue_free()
	return falhas


## Marca na grade as celulas que a palheta cobre nesta posicao.
func _marcar(varrido: Dictionary, limpador: Limpador, tam: Vector2) -> void:
	var setor := limpador.setor()
	if setor.is_empty():
		return
	var raios: Vector2 = setor["raios"]
	var meia: float = setor["palheta"]
	var lo: float = minf(setor["ang_de"], setor["ang_ate"]) - meia
	var hi: float = maxf(setor["ang_de"], setor["ang_ate"]) + meia
	for gy in GRADE:
		for gx in GRADE:
			var m := Vector2((gx + 0.5) / GRADE * tam.x,
				(gy + 0.5) / GRADE * tam.y)
			for pivo: Vector2 in [setor["pivo_a"], setor["pivo_b"]]:
				var d := m - pivo
				var r := d.length()
				if r < raios.x or r > raios.y:
					continue
				var ang := atan2(d.x, -d.y)
				if ang >= lo and ang <= hi:
					varrido[gy * GRADE + gx] = true
					break


func _parabrisa(cab: CarroCabine) -> Dictionary:
	for p: Dictionary in cab.paineis():
		if p["tipo"] == &"parabrisa":
			return p
	return {}
