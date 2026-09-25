## Bancada da sinuca: fisica, regras e adversario, sem abrir o jogo.
##
##     godot --headless --path game --script res://tests/bancada_sinuca.gd
##
## Cada linha `[sinuca] chave=valor ok|FALHA` e um criterio. Os numeros de
## referencia saem da solucao fechada (bola que desliza e depois rola perde 2/7
## da velocidade no deslize; bola parada que leva um choque de frente sai com
## (1+e)/2 da velocidade), e nao do proprio simulador.
extends SceneTree

const R := MesaSinuca.R
var _falhas := 0


func _init() -> void:
	_rolamento()
	_choque_de_frente()
	_noventa_graus()
	_tabela()
	_quebra()
	_partida()
	print("[sinuca] falhas=%d" % _falhas)
	quit(1 if _falhas > 0 else 0)


func _criterio(chave: String, valor: Variant, ok: bool) -> void:
	print("[sinuca] %s=%s %s" % [chave, str(valor), "ok" if ok else "FALHA"])
	if not ok:
		_falhas += 1


## Mesa so com a branca (e, se pedido, uma bola).
func _mesa_vazia() -> FisicaSinuca:
	var f := FisicaSinuca.new()
	f.arrumar(1)
	for i in range(1, 16):
		f.estado[i] = FisicaSinuca.Estado.CACAPA
	return f


func _rolamento() -> void:
	var f := _mesa_vazia()
	f.por(0, Vector2(-0.8, 0.0))
	var v0 := 0.5
	f.v[0] = Vector2(v0, 0.0)
	f._classificar(0)
	f.ate_parar()
	# Deslize: dura 2 u / (7 mu_s g), termina com 5/7 de v0; depois rola ate parar.
	var g := FisicaSinuca.G
	var ts := 2.0 * v0 / (7.0 * FisicaSinuca.MU_S * g)
	var ds := v0 * ts - 0.5 * FisicaSinuca.MU_S * g * ts * ts
	var v1 := v0 * 5.0 / 7.0
	var dr := v1 * v1 / (2.0 * FisicaSinuca.MU_R * g)
	var esperado := -0.8 + ds + dr
	var erro := absf(f.r[0].x - esperado)
	_criterio("rolamento_erro_mm", "%.3f" % (erro * 1000.0), erro < 0.001)


func _choque_de_frente() -> void:
	var f := _mesa_vazia()
	f.estado[3] = FisicaSinuca.Estado.PARADA
	f.por(3, Vector2(0.0, 0.0))
	f.por(0, Vector2(-0.07, 0.0))
	f.v[0] = Vector2(1.5, 0.0)
	f._classificar(0)
	# So o choque: avanca ate a bola 3 se mexer.
	var guarda := 0
	while f.estado[3] == FisicaSinuca.Estado.PARADA and guarda < 1000:
		f._passo(FisicaSinuca.PASSO)
		guarda += 1
	var antes := f.v[0].length() + f.v[3].length()
	var razao := f.v[3].x / antes
	var sobra := f.v[0].x / antes
	_criterio("frente_bola_sai", "%.3f" % razao, absf(razao - (1.0 + FisicaSinuca.E_BOLA) * 0.5) < 0.02)
	_criterio("frente_branca_fica", "%.3f" % sobra, absf(sobra) < 0.04)


func _noventa_graus() -> void:
	var f := _mesa_vazia()
	f.estado[5] = FisicaSinuca.Estado.PARADA
	f.por(5, Vector2(0.0, 0.0))
	# Corte de 30 graus: a branca chega com o centro deslocado R da linha.
	f.por(0, Vector2(-0.3, R))
	f.v[0] = Vector2(2.0, 0.0)
	f._classificar(0)
	var guarda := 0
	while f.estado[5] == FisicaSinuca.Estado.PARADA and guarda < 2000:
		f._passo(FisicaSinuca.PASSO)
		guarda += 1
	var ang := rad_to_deg(absf(f.v[0].angle_to(f.v[5])))
	# Sem atrito entre bolas e com e < 1 o angulo fica um pouco abaixo de 90.
	_criterio("corte_angulo_graus", "%.1f" % ang, ang > 84.0 and ang < 91.0)


func _tabela() -> void:
	var f := _mesa_vazia()
	f.por(0, Vector2(0.3, 0.0))
	# Rolando a 45 graus contra a tabela comprida de cima.
	var v := Vector2(1.0, 1.0).normalized() * 1.2
	f.v[0] = v
	f.w[0] = Vector3(-v.y / R, v.x / R, 0.0)
	f._classificar(0)
	var guarda := 0
	while guarda < 3000:
		f._passo(FisicaSinuca.PASSO)
		guarda += 1
		if f.v[0].y < 0.0:
			break
	var voltou := f.v[0].y < 0.0
	var razao := -f.v[0].y / v.y if voltou else 0.0
	_criterio("tabela_voltou", voltou, voltou)
	# A componente normal volta com algo perto da restituicao (menos o que o
	# nariz alto come).
	_criterio("tabela_restituicao", "%.2f" % razao, razao > 0.6 and razao < 0.95)
	var dentro := absf(f.r[0].y) <= MesaSinuca.LARG * 0.5 - R + 0.002
	_criterio("tabela_nao_atravessa", "%.4f" % f.r[0].y, dentro)


func _quebra() -> void:
	var resultados: Array = []
	var custo := 0.0
	var tempo_sim := 0.0
	for k in 2:
		var f := FisicaSinuca.new()
		f.arrumar(77)
		f.tacar(CerebroSinuca.QUEBRA, (f.r[1] - f.r[0]).angle(), deg_to_rad(4.0), 0.0, -0.05)
		var t0 := Time.get_ticks_usec()
		f.ate_parar(40.0)
		custo = float(Time.get_ticks_usec() - t0) / 1000.0
		tempo_sim = f.tempo
		resultados.append(f)
	var a: FisicaSinuca = resultados[0]
	var b: FisicaSinuca = resultados[1]
	_criterio("quebra_parou_s", "%.1f" % a.tempo, not a.em_movimento() and a.tempo < 30.0)
	var igual := true
	for i in FisicaSinuca.BOLAS:
		if a.r[i] != b.r[i] or a.estado[i] != b.estado[i]:
			igual = false
	_criterio("quebra_determinista", igual, igual)
	var sobrepostas := 0
	var fora := 0
	var mexeram := 0
	var caidas := 0
	for i in FisicaSinuca.BOLAS:
		if not a.na_mesa(i):
			caidas += 1
			continue
		if absf(a.r[i].x) > MesaSinuca.COMP * 0.5 - R + 0.001 \
				or absf(a.r[i].y) > MesaSinuca.LARG * 0.5 - R + 0.001:
			fora += 1
		if i > 0 and a.r[i].distance_to(MesaSinuca.triangulo(77).get(i, Vector2.ZERO)) > 0.05:
			mexeram += 1
		for j in range(i + 1, FisicaSinuca.BOLAS):
			if a.na_mesa(j) and a.r[i].distance_to(a.r[j]) < 2.0 * R - 0.0005:
				sobrepostas += 1
	_criterio("quebra_sobrepostas", sobrepostas, sobrepostas == 0)
	_criterio("quebra_fora_da_mesa", fora, fora == 0)
	_criterio("quebra_espalhou", mexeram, mexeram >= 8)
	print("[sinuca] quebra_caidas=%d" % caidas)
	# Custo: milissegundos de CPU por segundo simulado. A sessao roda a 60 Hz, e
	# isto e o que a fisica tira do quadro enquanto as bolas andam.
	var por_s := custo / maxf(tempo_sim, 0.001)
	_criterio("custo_ms_por_s", "%.1f" % por_s, por_s < 120.0)


## Partida inteira, IA contra IA: o jogo termina, com vencedor, sem travar.
func _partida() -> void:
	var f := FisicaSinuca.new()
	var regras := RegrasSinuca.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	f.arrumar(4242)
	var tacadas := 0
	var faltas := 0
	while not regras.fim and tacadas < 120:
		if regras.bola_na_mao:
			var p := CerebroSinuca.bola_na_mao(f, regras.alvos(f), regras.so_cabeceira)
			f.por(0, p)
		var t := CerebroSinuca.escolher(f, regras.alvos(f), 0.75, rng, regras.quebra)
		f.tacar(t["v0"], t["phi"], t["theta"], t["a"], t["b"])
		f.ate_parar(40.0)
		var res := regras.avaliar(f)
		tacadas += 1
		if res["falta"]:
			faltas += 1
		if res["recolocar_8"]:
			f.por(8, _livre_perto(f, MesaSinuca.marca_do_pe()))
		if not f.na_mesa(0):
			f.por(0, _livre_perto(f, Vector2(MesaSinuca.linha_de_cabeceira(), 0.0)))
	_criterio("partida_terminou", regras.fim, regras.fim)
	print("[sinuca] partida_tacadas=%d faltas=%d vencedor=%d" % [tacadas, faltas, regras.vencedor])


func _livre_perto(f: FisicaSinuca, p: Vector2) -> Vector2:
	for k in 40:
		var q := p + Vector2(0.03 * float(k), 0.0)
		if f.cabe(q):
			return q
	return p
