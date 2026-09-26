## Por onde a mao direita do motorista da estrada anda dentro da cabine do Marea: do
## colo ao chao do carona, e do chao de volta a leitura, sem atravessar a manopla do
## cambio, o console, o radio nem o painel.
##
## Por que existe
## --------------
## A mao ia de uma pegada a outra em linha reta, com um bojo de seno no meio
## (`BracoVivo.ir`). A reta do colo ao chao cruzava a alavanca exatamente no z dela
## (-0,21), com o antebraco 5,7 cm dentro da haste. Na volta, o aparelho subia do
## chao direto para a frente da lente: saindo de baixo do painel ja subindo, a mao
## entrava 4,8 cm no fundo dele, e o braco esticado, com o corpo voltando para o
## banco, varria a manopla (5,4 cm).
##
## Como
## ----
## O caminho e uma curva por pontos de passagem medidos na cabine (Catmull-Rom
## centripeta, amostrada por comprimento de arco):
## - na ida, por tras da manopla e por cima do freio de mao, desce do lado do
##   carona entre a alavanca e o assento, e entra no vao por baixo do painel;
## - na volta, o aparelho sai primeiro de baixo do painel, baixo e para tras (a
##   mao recolhe o braco pelo mesmo caminho que ele esticou), sobe do lado do
##   carona, a um palmo da manopla, e so por cima dela cruza para a lente.
## O braco continua esticando quando o celular esta longe: e escolha da cena.
##
## Tudo no espaco da `MotoristaCena` (= da cabine = do carro): -Z a frente, +X o
## carona, +Y para cima. Carregado pelo caminho, sem `class_name`.
extends RefCounted

## O topo do pomo da manopla (em ponto morto, depois da batida).
const POMO_TOPO := Vector3(0.0, 0.818, -0.172)


## Os pontos de passagem da palma do colo ate a espera no chao (`chao`, a um palmo
## do aparelho): para o meio por tras da manopla, desce do lado do carona a frente
## do assento e entra no vao por baixo do painel.
static func ida_ao_chao(de: Vector3, chao: Vector3) -> PackedVector3Array:
	var pts := PackedVector3Array()
	pts.append(de)
	# Por tras do pomo, catorze centimetros, e por cima do freio de mao: os dedos
	# apontando para o vao passam a seis centimetros dele.
	pts.append(Vector3(0.0, 0.83, -0.02))
	# Do lado do carona, entre a alavanca e o assento (a borda da frente dele fica
	# em -0,155, o tampo em 0,655).
	pts.append(Vector3(0.20, 0.70, -0.25))
	# Debaixo do painel (o fundo dele fica em 0,75 ali).
	pts.append(Vector3(0.31, 0.55, -0.55))
	pts.append(chao)
	return pts


## A volta do aparelho (o centro dele), do chao ate a leitura (`leitura`, que anda
## com a lente): sai de baixo do painel baixo e para tras, sobe do lado do carona a
## um palmo da manopla e cruza por cima dela.
static func volta_do_chao(no_chao: Vector3, leitura: Vector3) -> PackedVector3Array:
	var pts := PackedVector3Array()
	pts.append(no_chao)
	# Descolado do corta-fogo, ainda baixo.
	pts.append(no_chao + Vector3(-0.03, 0.07, 0.12))
	# Fora do painel: atras do joelho dele (-0,51) antes de subir.
	pts.append(Vector3(0.24, 0.60, -0.40))
	# Do lado do carona, acima do pomo: o aparelho de pe tem seis centimetros abaixo
	# do centro.
	pts.append(Vector3(0.15, POMO_TOPO.y + 0.09, -0.27))
	pts.append(leitura)
	return pts


## Um ponto da curva pelos pontos `pts` em `s` (0 a 1, por comprimento de arco).
static func ponto(pts: PackedVector3Array, s: float) -> Vector3:
	return _no_arco(pts, _tabela(pts), s)


# --- a curva ------------------------------------------------------------------

## Catmull-Rom centripeta pelos pontos, com os extremos repetidos.
static func _catmull(pts: PackedVector3Array, seg: int, t: float) -> Vector3:
	var n := pts.size()
	var p0 := pts[maxi(seg - 1, 0)]
	var p1 := pts[seg]
	var p2 := pts[mini(seg + 1, n - 1)]
	var p3 := pts[mini(seg + 2, n - 1)]
	var t0 := 0.0
	var t1 := t0 + maxf(pow(p0.distance_to(p1), 0.5), 1e-4)
	var t2 := t1 + maxf(pow(p1.distance_to(p2), 0.5), 1e-4)
	var t3 := t2 + maxf(pow(p2.distance_to(p3), 0.5), 1e-4)
	var tt := lerpf(t1, t2, t)
	var a1 := p0 * (t1 - tt) / (t1 - t0) + p1 * (tt - t0) / (t1 - t0)
	var a2 := p1 * (t2 - tt) / (t2 - t1) + p2 * (tt - t1) / (t2 - t1)
	var a3 := p2 * (t3 - tt) / (t3 - t2) + p3 * (tt - t2) / (t3 - t2)
	var b1 := a1 * (t2 - tt) / (t2 - t0) + a2 * (tt - t0) / (t2 - t0)
	var b2 := a2 * (t3 - tt) / (t3 - t1) + a3 * (tt - t1) / (t3 - t1)
	return b1 * (t2 - tt) / (t2 - t1) + b2 * (tt - t1) / (t2 - t1)


## Comprimento acumulado ao longo da curva (16 passos por trecho).
static func _tabela(pts: PackedVector3Array) -> PackedFloat32Array:
	var tab := PackedFloat32Array()
	tab.append(0.0)
	var ant := pts[0]
	var acc := 0.0
	for seg in pts.size() - 1:
		for k in range(1, 17):
			var p := _catmull(pts, seg, float(k) / 16.0)
			acc += p.distance_to(ant)
			tab.append(acc)
			ant = p
	return tab


static func _no_arco(pts: PackedVector3Array, tab: PackedFloat32Array, s: float) -> Vector3:
	if pts.size() < 2:
		return pts[0] if pts.size() == 1 else Vector3.ZERO
	var total := tab[tab.size() - 1]
	var alvo := clampf(s, 0.0, 1.0) * total
	var i := tab.bsearch(alvo)
	i = clampi(i, 1, tab.size() - 1)
	var a := tab[i - 1]
	var b := tab[i]
	var f := (alvo - a) / maxf(b - a, 1e-6)
	var u := (float(i - 1) + f) / 16.0
	var seg := mini(int(u), pts.size() - 2)
	return _catmull(pts, seg, u - float(seg))
