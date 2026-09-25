## Bancada do cruzamento (PLANO_TRANSITO_AAA, Passo 3): quem entra primeiro, e
## o pedestre. Herda a bancada do transito (o chao, o carro de verdade, as
## reguas) e monta as situacoes do Passo 3, sempre as mesmas.
##
##     godot --headless --fixed-fps 60 --path game --script res://tests/bancada_cruzamento.gd -- --sem-relevo
##     ... -- --ia-antiga     o motorista e o pedestre de antes (linha de base)
##     ... -- --so=esquerda,pare,fifo,saida,conversao,conversao_fluxo,brecha,meio,
##               meio_par,boneco,solta
##     ... -- --solta=600     segundos de rua solta (padrao 600)
##     ... -- --semente=N     sorteio global (padrao 1: a mesma rodada sempre)
##     ... -- --traco         o que o carro decide; --traco-quadro, cada quadro
##
## Tudo e medido DE FORA, pela trilha dos corpos (`Rastro`): o PET num ponto de
## conflito (quanto tempo entre um corpo deixar o ponto e o outro chegar nele;
## negativo e os dois ao mesmo tempo), a menor folga entre latarias, e o estado do
## boneco quando o pe da pessoa desce no asfalto. Nada le a decisao do motorista.
##
## As situacoes e o criterio (secao 4 do plano)
## --------------------------------------------
##   esquerda   conversao a esquerda com o fluxo de frente passando a 2, 4 e 7 s
##              um do outro, no verde da avenida e na preferencial da rua: cede
##              nas brechas curtas, entra na longa; PET >= 1,5 s
##   pare       a secundaria parada no PARE e a preferencial vindo a 16, 25 e 40
##              m (a 11 e a 14 m/s): so entra depois que ela passa ou com TTC >= 3
##              s ate o ponto de conflito, PET >= 1,5 s; com a preferencial longe
##              (brecha longa) entra antes dela
##   fifo       dois PAREs de frente, o primeiro a parar virando a esquerda por
##              cima do outro: sai primeiro quem parou primeiro, PET >= 1,5 s
##   saida      verde, e a faixa depois do cruzamento parada a 4 m da zebra: o
##              carro espera ANTES da linha e so entra quando ela anda
##   conversao  direita e esquerda no verde com gente atravessando a rua de saida
##              no ANDA: o carro cede, passa a >= 1 m da pessoa, freia <= 3 m/s2,
##              e ninguem se assusta
##   conversao_fluxo  a direita no verde com cinco pessoas atravessando a zebra de
##              saida em fila: entra, espera rente a ela e vira neste ciclo, a >= 1
##              m de quem atravessa (andando), freando <= 3 m/s2
##   brecha     esquina sem sinal, carros passando pela preferencial: a pessoa
##              espera a brecha; nenhum carro freia por ela; PET >= 1,5 s
##   meio       onde uma viela encosta na avenida, a pessoa atravessa sem sinal nem
##              cruzamento de carro, com fluxo nas duas faixas: espera a brecha;
##              nenhum carro passa a menos de 1 m dela nem a assusta
##   meio_par   as duas zebras desse no, a 5 m uma da outra: o carro que para por
##              quem atravessa a de la nao espera com a lataria em cima da de ca
##   boneco     oito pessoas nas quatro esquinas de um sinal, 70 s: nenhuma desce
##              da calcada fora do ANDA
##   solta      14 carros e 16 pessoas em volta de um cruzamento de avenidas,
##              10 min de jogo: zero lataria em lataria, zero carro em pessoa (ou
##              empurrao: tropeco com a lataria encostada), zero travessia fora do
##              ANDA, ninguem parado mais de 45 s
extends "res://tests/bancada_transito.gd"

const PET_MIN := 1.5
const TTC_MIN := 3.0
const FOLGA_PESSOA := 1.0
const PARADO_MAX_S := 45.0
const SOLTA_CARROS := 14
const SOLTA_PESSOAS := 16

var _solta_s := 600.0
var _traco_antes := ""
var _script_pessoa: GDScript
var _vel_rua := 11.0
var _vel_avenida := 14.0
var _espera_pare := 0.7
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	super()
	# O sorteio global (o olhar de quem atravessa, a multidao) e semeado pelo
	# relogio a cada partida: duas rodadas no mesmo segundo saiam iguais e a
	# seguinte, outra. Com a semente fixa a falha se repete; `--semente=N` varre.
	var semente := 1
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--solta="):
			_solta_s = float(a.trim_prefix("--solta="))
		elif a.begins_with("--semente="):
			semente = int(a.trim_prefix("--semente="))
	seed(semente)
	print("[bancada_cruzamento] semente=%d" % semente)
	_rng.seed = 20260925


func _quer(nome: String) -> bool:
	return _so.is_empty() or _so.has(nome)


func _rodar() -> void:
	await process_frame
	_script_carro = load("res://src/world/carro.gd") as GDScript
	_script_ia = load("res://src/world/transito/motorista_ia.gd") as GDScript
	# Pedestre e Carro puxam autoloads: carregados agora, e nao citados no script
	# (que compila antes de eles existirem).
	_script_pessoa = load("res://src/world/pedestre.gd") as GDScript
	var consts := _script_carro.get_script_constant_map()
	_vel_rua = float(consts["VEL_CRUZEIRO"])
	_vel_avenida = float(consts["VEL_AVENIDA"])
	_espera_pare = float(consts["ESPERA_PARE"])
	_nova = not bool(_script_ia.get("ia_antiga"))
	_registro = root.get_node(^"RegistroCivil")
	print("[bancada_cruzamento] ia=%s relevo=%s" % ["nova" if _nova else "antiga",
		str(Relevo.ativo)])
	_mundo = Node3D.new()
	root.add_child(_mundo)
	var chao := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(4000.0, 1.0, 4000.0)
	forma.shape = caixa
	chao.add_child(forma)
	chao.position = Vector3(0.0, -0.5, 0.0)
	_mundo.add_child(chao)
	# A geometria da zebra copiada no motorista tem de ser a pintada.
	_conta("esquina", "zebra", is_equal_approx(Esquina.ZEBRA_RECUO + Esquina.ZEBRA_PROFUNDIDADE,
		ZEBRA_ATE), "a zebra do motorista vai ate asf + %.2f (a pintada, %.2f)" % [
		Esquina.ZEBRA_RECUO + Esquina.ZEBRA_PROFUNDIDADE, ZEBRA_ATE])

	_conta("esquina", "vias", is_equal_approx(Movimento.V_RUA, _vel_rua)
		and is_equal_approx(Movimento.V_AVENIDA, _vel_avenida),
		"as velocidades copiadas no Movimento sao as do Carro (%.0f e %.0f)" % [_vel_rua, _vel_avenida])

	if _quer("esquerda"):
		for tipo: String in ["av_av", "rua_rua"]:
			await _c_esquerda(tipo, true)
			await _c_esquerda(tipo, false)
	if _quer("pare"):
		for caso: Array in [[16.0, 11.0], [25.0, 11.0], [40.0, 11.0], [16.0, 14.0],
				[25.0, 14.0], [40.0, 14.0]]:
			await _c_pare(caso[0], caso[1], "RETO", false)
		await _c_pare(-1.0, 11.0, "RETO", true)
		await _c_pare(25.0, 11.0, "DIREITA", false)
	if _quer("fifo"):
		await _c_fifo()
	if _quer("saida"):
		await _c_saida()
	if _quer("conversao"):
		await _c_conversao("DIREITA")
		await _c_conversao("ESQUERDA")
	if _quer("conversao_fluxo"):
		await _c_conversao_fluxo()
	if _quer("brecha"):
		await _c_brecha()
	if _quer("meio"):
		await _c_meio_de_quadra()
	if _quer("meio_par"):
		await _c_meio_par()
	if _quer("boneco"):
		await _c_boneco()
	if _quer("solta"):
		await _c_solta()
	if _nova:
		print("[bancada_cruzamento] movimento_montar_pior_ms=%.2f conflito_pior_ms=%.2f" % [
			Movimento.custo_montar_ms, Movimento.custo_conflito_ms])
		var soma: float = _script_ia.get(&"soma_passo_ms")
		var n: int = _script_ia.get(&"passos")
		print("[bancada_cruzamento] passo_medio_ms=%.4f em %d passos" % [soma / maxf(1.0, n), n])
	print("\n%d de %d criterios" % [_passou, _total])
	quit(0 if _passou == _total else 1)


# --- a trilha dos corpos ----------------------------------------------------------

## A trilha de um corpo (carro ou pessoa) quadro a quadro, para medir de fora.
class Rastro:
	var no: Node3D
	var t := PackedFloat32Array()
	var p := PackedVector2Array()
	var f := PackedVector2Array()
	var meia_c := 0.0
	var meia_l := 0.0
	var raio := 0.0

	func _init(n: Node3D, pessoa := 0.0) -> void:
		no = n
		raio = pessoa
		if pessoa <= 0.0:
			var m: Dictionary = n.get(&"_medidas")
			meia_c = float(m["comprimento"]) * 0.5
			meia_l = float(m["largura"]) * 0.5

	func gravar(tt: float) -> void:
		if not is_instance_valid(no):
			return
		t.append(tt)
		p.append(Vector2(no.global_position.x, no.global_position.z))
		var fw := -no.global_transform.basis.z
		f.append(Vector2(fw.x, fw.z).normalized())

	func contem(k: int, x: Vector2, folga: float) -> bool:
		var d := x - p[k]
		if raio > 0.0:
			return d.length() <= raio + folga
		return absf(d.dot(f[k])) <= meia_c + folga and absf(d.cross(f[k])) <= meia_l + folga

	## (primeiro, ultimo) instante em que o ponto `x` esteve dentro do corpo.
	func ocupa(x: Vector2, folga: float) -> Vector2:
		var r := Vector2(INF, -INF)
		for k in t.size():
			if contem(k, x, folga):
				r.x = minf(r.x, t[k])
				r.y = maxf(r.y, t[k])
		return r

	## Onde o centro cruzou pela primeira vez a reta por `a` de normal `n`.
	func cruza(a: Vector2, n: Vector2) -> Vector2:
		for k in range(1, t.size()):
			var d0 := (p[k - 1] - a).dot(n)
			var d1 := (p[k] - a).dot(n)
			if (d0 <= 0.0) != (d1 <= 0.0):
				return p[k - 1].lerp(p[k], d0 / (d0 - d1))
		return Vector2(INF, INF)

	## A amostra mais perto do instante `tt`.
	func em(tt: float) -> int:
		for k in t.size():
			if t[k] >= tt:
				return k
		return t.size() - 1


## PET no ponto `x`: quanto tempo entre um corpo deixar o ponto e o outro chegar
## nele. Negativo: os dois la ao mesmo tempo. INF: um deles nunca passou.
static func _pet(a: Rastro, b: Rastro, x: Vector2) -> float:
	var oa := a.ocupa(x, 0.1)
	var ob := b.ocupa(x, 0.1)
	if oa.x == INF or ob.x == INF:
		return INF
	return maxf(ob.x - oa.y, oa.x - ob.y)


## A menor folga entre dois corpos gravados juntos, em metros (negativa: um
## dentro do outro). Lataria com lataria pelos eixos separadores; lataria com
## pessoa pela distancia do centro dela a caixa, menos o raio.
static func _folga_min(a: Rastro, b: Rastro) -> float:
	var menor := INF
	if a.t.is_empty() or b.t.is_empty():
		return menor
	# Os dois gravam a cada quadro desde que nasceram: alinha pelo instante.
	var ka := a.em(b.t[0])
	var kb := b.em(a.t[0])
	while ka < a.t.size() and kb < b.t.size():
		menor = minf(menor, _folga_em(a, ka, b, kb))
		ka += 1
		kb += 1
	return menor


static func _folga_em(a: Rastro, ka: int, b: Rastro, kb: int) -> float:
	if b.raio > 0.0:
		return _caixa_ponto(a.p[ka], a.f[ka], a.meia_c, a.meia_l, b.p[kb]) - b.raio
	if a.raio > 0.0:
		return _caixa_ponto(b.p[kb], b.f[kb], b.meia_c, b.meia_l, a.p[ka]) - a.raio
	return _sat(a.p[ka], a.f[ka], a.meia_c, a.meia_l, b.p[kb], b.f[kb], b.meia_c, b.meia_l)


static func _caixa_ponto(c: Vector2, f: Vector2, mc: float, ml: float, x: Vector2) -> float:
	var d := x - c
	var dx := maxf(absf(d.dot(f)) - mc, 0.0)
	var dy := maxf(absf(d.cross(f)) - ml, 0.0)
	return sqrt(dx * dx + dy * dy)


## Separacao de duas caixas pelo melhor dos quatro eixos (> 0: separadas por
## pelo menos isso; <= 0: se tocam).
static func _sat(pa: Vector2, fa: Vector2, ca: float, la: float, pb: Vector2, fb: Vector2,
		cb: float, lb: float) -> float:
	var ea := Vector2(-fa.y, fa.x)
	var eb := Vector2(-fb.y, fb.x)
	var melhor := -INF
	for e: Vector2 in [fa, ea, fb, eb]:
		var ra := ca * absf(fa.dot(e)) + la * absf(ea.dot(e))
		var rb := cb * absf(fb.dot(e)) + lb * absf(eb.dot(e))
		melhor = maxf(melhor, absf((pb - pa).dot(e)) - ra - rb)
	return melhor


# --- plantar ------------------------------------------------------------------------

func _rumo(nome: String) -> int:
	return int(_script_ia.get_script_constant_map()["Rumo"][nome])


## A saida de quem chega por (eixo, sentido) em `ij` e faz a manobra `nome`,
## com a faixa que o motorista novo usa (e a IA antiga le da seta).
static func _saida(ij: Vector2i, eixo: int, sentido: int, nome: String) -> Vector4i:
	var outro := 1 - eixo
	var faixas_sai := Vias.faixas(MalhaUrbana.via_z(ij.y) if eixo == 0 else MalhaUrbana.via_x(ij.x))
	var s_dir := 0
	for s: int in [1, -1]:
		if Manobra.lado_da_curva(Vias.trecho(eixo, sentido, 0), Vias.trecho(outro, s, 0)) > 0:
			s_dir = s
	match nome:
		"DIREITA":
			return Vias.trecho(outro, s_dir, 0)
		"ESQUERDA":
			return Vias.trecho(outro, -s_dir, 1 if faixas_sai > 1 else 0)
	return Vias.trecho(eixo, sentido, 0)


static func _bloco(ij: Vector2i, eixo: int, sentido: int) -> float:
	var ant := _anterior(ij, eixo, sentido)
	if ant == ij:
		return 0.0
	return float(absi((ant - ij).x) + absi((ant - ij).y)) * Vias.TAM


## Um carro da IA na faixa `faixa` de quem chega a `ij` por (eixo, sentido), a
## `dist` m do centro, com a manobra `nome` imposta; `v` >= 0 impoe a velocidade.
func _carro_em(ij: Vector2i, eixo: int, sentido: int, faixa: int, dist: float, nome: String,
		v := -1.0) -> Node3D:
	var t := Vias.trecho(eixo, sentido, faixa)
	var dir := Vias.direcao(eixo, sentido)
	var ponto := Vector3(float(ij.x) * Vias.TAM, 0.05, float(ij.y) * Vias.TAM) - dir * dist
	if eixo == 0:
		ponto.x = Vias.linha_x(ij.x, sentido, faixa)
	else:
		ponto.z = Vias.linha_z(ij.y, sentido, faixa)
	var de := _anterior(ij, eixo, sentido)
	_semente += 17
	var ficha: Dictionary = _registro.call(&"identidade",
		_registro.call(&"id_de_transeunte", _semente))
	var c: Node3D = _script_carro.new()
	c.name = "%s_%d" % [nome.to_lower(), _semente]
	c.call(&"preparar", ficha, de, t, _semente)
	c.position = ponto
	_mundo.add_child(c)
	c.call(&"plantar", de, t, ponto)
	var ia: Variant = c.get(&"_ia")
	if ia != null:
		var lista: Array[int] = [_rumo(nome)]
		(ia as RefCounted).call(&"forcar", lista)
	else:
		var s := _saida(ij, eixo, sentido, nome)
		c.set(&"_saida_plana", Vias.trecho(s.z, s.w, 0) if s.z != eixo else t)
		c.set(&"_tem_plano", true)
	if v >= 0.0:
		c.set(&"_velocidade", v)
	return c


func _pessoa_em(de: Vector4i, para: Vector4i) -> Node3D:
	_semente += 17
	var ficha: Dictionary = _registro.call(&"identidade",
		_registro.call(&"id_de_transeunte", _semente))
	var p: Node3D = _script_pessoa.new()
	p.name = "pessoa_%d" % _semente
	p.call(&"preparar", ficha, de, para)
	p.add_to_group(&"pessoa_bancada")
	var onde := Rotas.ponto(de)
	onde.y = 0.1
	p.position = onde
	_mundo.add_child(p)
	return p


## O lado (atravessado da zebra) em que fica a faixa de quem sai pelo trecho `t`.
static func _lado_da_faixa(z: Esquina.Zebra, t: Vector4i) -> float:
	var d3 := Vias.direcao(t.z, t.w)
	var direita := Vector2(-d3.z, d3.x)
	return signf(direita.dot(z.u))


## O no de esquina de onde sai quem atravessa a zebra `z` comecando pelo lado
## `lado` (sinal do atravessado), e o de chegada.
static func _pernas(z: Esquina.Zebra, lado: float) -> Array[Vector4i]:
	var i := z.ij.x
	var j := z.ij.y
	var s := 1 if lado > 0.0 else -1
	match z.braco:
		Esquina.Braco.N:
			return [Vector4i(i, j, s, 1), Vector4i(i, j, -s, 1)]
		Esquina.Braco.S:
			return [Vector4i(i, j, s, -1), Vector4i(i, j, -s, -1)]
		Esquina.Braco.L:
			return [Vector4i(i, j, 1, s), Vector4i(i, j, 1, -s)]
	return [Vector4i(i, j, -1, s), Vector4i(i, j, -1, -s)]


## A pessoa ja esta na calcada do outro lado da zebra `z` (comecou do lado de
## sinal `lado_inicio` do atravessado)?
static func _do_outro_lado(pessoa: Node3D, z: Esquina.Zebra, lado_inicio: float) -> bool:
	var ac := z.atravessado(Vector2(pessoa.global_position.x, pessoa.global_position.z))
	return signf(ac) == -lado_inicio and absf(ac) > z.meia + 0.3


func _limpar(nos: Array) -> void:
	for n: Variant in nos:
		if n is Node and is_instance_valid(n):
			(n as Node).queue_free()
	await physics_frame
	await physics_frame


## `--traco`: imprime quando a decisao do motorista muda ou o pico de freada sobe.
func _tracar(quem: Node3D, tt: float, med: Regua, pico_antes: float, extra := "") -> void:
	if not OS.get_cmdline_user_args().has("--traco") or quem.get(&"_ia") == null:
		return
	var ia_q := quem.get(&"_ia") as RefCounted
	var vez_agora := "%s %s %s" % [str(ia_q.get(&"pub_vez")), str(ia_q.get(&"_veredito")),
		String(ia_q.get(&"_motivo_juiz"))]
	if (med.pico(quem) > pico_antes and med.pico(quem) > 0.8) or vez_agora != _traco_antes:
		_traco_antes = vez_agora
		print("[traco] %s t=%.2f pico %.2f v=%.2f d_ped=%.2f vez/veredito %s %s" % [quem.name, tt,
			med.pico(quem), med.vel(quem), float(ia_q.get(&"_d_pedestre")), vez_agora, extra])


# --- esquerda contra quem vem de frente ------------------------------------------

## Conversao a esquerda com o fluxo de frente passando a 2, 4 e 7 s um do outro
## (e um ultimo 3 s depois, fechando a brecha longa). `parado`: quem vira ja esta
## parado na linha, e o primeiro de frente chega no conflito uns 2 s depois — mede
## a brecha que ele aceita. Senao ele chega a toda, com o fluxo nascendo — mede a
## freada de quem decide ceder andando.
func _c_esquerda(tipo: String, parado: bool) -> void:
	var rot := "esquerda_%s_%s" % [tipo, "parado" if parado else "chegando"]
	var achado := _achar_frente_longa(tipo)
	if achado.is_empty():
		_conta(rot, "achado", false, "sem cruzamento %s" % tipo)
		return
	var ij: Vector2i = achado["ij"]
	var eixo: int = achado["eixo"]
	var sentido: int = achado["sentido"]
	var av := Vias.faixas(MalhaUrbana.via_x(ij.x) if eixo == 0 else MalhaUrbana.via_z(ij.y)) > 1
	var v_via := _vel_avenida if av else _vel_rua
	# O fluxo nasce no fundo do quarteirao de frente — o mais longe possivel, para
	# nao brotar dentro do que o motorista ja olhou —, e quem vira e plantado para
	# chegar (ou ja estar parado na linha) uns 3 s antes do primeiro de frente.
	var d_fluxo := minf(_bloco(ij, eixo, -sentido) - 8.0, 150.0)
	var chega0 := (d_fluxo - 4.0) / v_via
	var dist := Esquina.linha(ij, eixo) + 0.5 + 2.4 if parado else minf(80.0,
		float(achado["recuo"]) - 8.0)
	# Parado, fica na linha 3 s antes do primeiro de frente; chegando, larga de
	# longe (fora do alcance do juiz, como na rua) para chegar na linha junto.
	var t_quem := maxf(0.0, chega0 - (3.0 if parado else (dist - Esquina.linha(ij, eixo)) / v_via
		- 1.5))
	print("
=== %s em %s, eixo %d sentido %d: fluxo nasce a %.0f m, quem vira em %.1f s ===" % [
		rot, ij, eixo, sentido, d_fluxo, t_quem])
	if Semaforo.tem_sinal(ij.x, ij.y):
		_luz(ij, eixo, Semaforo.Luz.VERDE)
	var quem: Node3D = null
	var r_quem: Rastro = null
	var med := Regua.new()
	# Brechas de 2, 4 e 7 s entre um e outro (e um ultimo 3 s depois).
	var nascer: Array[float] = [0.0, 2.0, 6.0, 13.0, 16.0]
	var fluxo: Array[Node3D] = []
	var rastros: Array[Rastro] = []
	var tt := 0.0
	var saiu := false
	var sai3 := Vias.direcao(_saida(ij, eixo, sentido, "ESQUERDA").z,
		_saida(ij, eixo, sentido, "ESQUERDA").w)
	var c3 := Vector3(float(ij.x) * Vias.TAM, 0.0, float(ij.y) * Vias.TAM)
	while tt < 60.0:
		await physics_frame
		tt += PASSO
		while fluxo.size() < nascer.size() and tt >= nascer[fluxo.size()]:
			var c := _carro_em(ij, eixo, -sentido, 0, d_fluxo, "RETO", v_via)
			fluxo.append(c)
			rastros.append(Rastro.new(c))
		if quem == null and tt >= t_quem:
			quem = _carro_em(ij, eixo, sentido, 1 if av else 0, dist, "ESQUERDA",
				0.0 if parado else -1.0)
			r_quem = Rastro.new(quem)
		for r: Rastro in rastros:
			r.gravar(tt)
		if quem == null:
			continue
		r_quem.gravar(tt)
		var pico_antes := med.pico(quem)
		med.passo([quem])
		if OS.get_cmdline_user_args().has("--traco") and quem.get(&"_ia") != null:
			var ia_q := quem.get(&"_ia") as RefCounted
			var vez_agora := "%s %s %s" % [str(ia_q.get(&"pub_vez")), str(ia_q.get(&"_veredito")),
				String(ia_q.get(&"_motivo_juiz"))]
			if med.pico(quem) > pico_antes + 0.5 or vez_agora != _traco_antes:
				_traco_antes = vez_agora
				print("[traco] t=%.2f pico %.2f v=%.2f bico=%.2f vez/veredito %s" % [tt,
					med.pico(quem), med.vel(quem), _bico_ate_linha(quem, ij, eixo, sentido),
					vez_agora])
		if not saiu and (quem.global_position - c3).dot(sai3) > 20.0:
			saiu = true
		if saiu and fluxo.size() == nascer.size() and tt > nascer[nascer.size() - 1] + chega0 + 3.0:
			break
	# O ponto de conflito: onde o centro de quem vira cruza a faixa de quem vem.
	var faixa_frente := (Vector2(Vias.linha_x(ij.x, -sentido, 0), 0.0) if eixo == 0
		else Vector2(0.0, Vias.linha_z(ij.y, -sentido, 0)))
	var n := Vector2(1.0, 0.0) if eixo == 0 else Vector2(0.0, 1.0)
	var x := r_quem.cruza(faixa_frente, n)
	var pets: Array[String] = []
	var passagens: Array[String] = []
	var menor_pet := INF
	var menor_folga := INF
	var antes := 0
	var entrou := INF
	if x.x != INF:
		entrou = r_quem.ocupa(x, 0.1).x
	for k in rastros.size():
		var pet := _pet(r_quem, rastros[k], x) if x.x != INF else INF
		pets.append("%.2f" % pet)
		menor_pet = minf(menor_pet, pet)
		menor_folga = minf(menor_folga, _folga_min(r_quem, rastros[k]))
		var o := rastros[k].ocupa(x, 0.1) if x.x != INF else Vector2(INF, -INF)
		passagens.append("%.1f" % o.x)
		if o.y < entrou:
			antes += 1
	_relatar(rot, "fluxo_passa_no_conflito_s", ", ".join(passagens))
	_relatar(rot, "quem_vira_entra_s", "%.1f" % entrou)
	_relatar(rot, "pet_com_cada_um_s", ", ".join(pets))
	_relatar(rot, "passaram_antes_dele", antes)
	_relatar(rot, "freada_pico", "%.2f" % med.pico(quem))
	_relatar(rot, "folga_min_m", "%.2f" % menor_folga)
	_conta(rot, "virou", saiu, "fez a conversao")
	if parado:
		_conta(rot, "brecha", antes == 3,
			"entrou na brecha de 7 s (deixou passar %d; o certo e 3)" % antes)
	else:
		_conta(rot, "freada", med.pico(quem) <= FREADA_MAX, "freada %.2f m/s2 (teto %.1f)" % [
			med.pico(quem), FREADA_MAX])
	_conta(rot, "pet", menor_pet >= PET_MIN, "menor PET %.2f s (minimo %.1f)" % [menor_pet, PET_MIN])
	_conta(rot, "contato", menor_folga > 0.0, "menor folga entre latarias %.2f m" % menor_folga)
	var todos: Array = [quem]
	todos.append_array(fluxo)
	await _limpar(todos)


## Como `_achar`, mas entre os primeiros achados fica com o de quarteirao de
## frente mais longo: o fluxo de frente precisa nascer longe.
func _achar_frente_longa(tipo: String) -> Dictionary:
	var melhor := {}
	var melhor_l := 0.0
	for i in range(-12, 13):
		for j in range(-12, 13):
			var ij := Vector2i(i, j)
			if not Vias.existe_cruzamento(i, j) or not (Vias.braco_n(i, j) and Vias.braco_s(i, j)
					and Vias.braco_l(i, j) and Vias.braco_o(i, j)):
				continue
			var av_x := MalhaUrbana.via_x(i) == MalhaUrbana.Via.AVENIDA
			var av_z := MalhaUrbana.via_z(j) == MalhaUrbana.Via.AVENIDA
			for eixo in 2:
				var chega_av := av_x if eixo == 0 else av_z
				var cruza_av := av_z if eixo == 0 else av_x
				var ok := false
				match tipo:
					"av_av":
						ok = chega_av and cruza_av
					"rua_rua":
						ok = not chega_av and not cruza_av and eixo == Vias.preferencial(i, j)
				if not ok:
					continue
				for sentido: int in [1, -1]:
					var recuo := _bloco(ij, eixo, sentido)
					var frente := _bloco(ij, eixo, -sentido)
					if recuo < 40.0 or frente < 40.0:
						continue
					var outro := 1 - eixo
					var todas := true
					for s: int in [1, -1]:
						todas = todas and Vias.proximo_cruzamento(i, j, Vias.trecho(outro, s, 0)) != ij
					if not todas:
						continue
					if frente > melhor_l:
						melhor_l = frente
						melhor = {"ij": ij, "eixo": eixo, "sentido": sentido, "recuo": recuo}
	return melhor


# --- PARE por tempo --------------------------------------------------------------

## Esquina de PARE com a preferencial longa do lado de quem vem pela esquerda
## da secundaria (a faixa de perto). `mais_longo`: a de quarteirao preferencial
## mais longo entre as perto da origem, e nao a primeira.
func _achar_pare(minimo_pref: float, mais_longo := false) -> Dictionary:
	var melhor := {}
	var candidatos: Array[Vector2i] = []
	for i in range(-30, 31):
		for j in range(-30, 31):
			candidatos.append(Vector2i(i, j))
	candidatos.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.length_squared() < b.length_squared())
	for ij: Vector2i in candidatos:
		if not Vias.existe_cruzamento(ij.x, ij.y) or Semaforo.tem_sinal(ij.x, ij.y):
			continue
		if not (Vias.braco_n(ij.x, ij.y) and Vias.braco_s(ij.x, ij.y)
				and Vias.braco_l(ij.x, ij.y) and Vias.braco_o(ij.x, ij.y)):
			continue
		var pref := Vias.preferencial(ij.x, ij.y)
		var sec := 1 - pref
		for s: int in [1, -1]:
			if _bloco(ij, sec, s) < 32.0 or _bloco(ij, sec, -s) < 32.0:
				continue
			# A faixa da preferencial do lado de onde a secundaria chega.
			var s_pref := 0
			for sp: int in [1, -1]:
				var off := (Vias.linha_z(ij.y, sp, 0) - float(ij.y) * Vias.TAM if sec == 0
					else Vias.linha_x(ij.x, sp, 0) - float(ij.x) * Vias.TAM)
				if signf(off) == -float(s):
					s_pref = sp
			if s_pref == 0 or _bloco(ij, pref, s_pref) < minimo_pref:
				continue
			var todas := true
			for t: Vector4i in [Vias.trecho(sec, s, 0), Vias.trecho(pref, 1, 0), Vias.trecho(pref, -1, 0)]:
				todas = todas and Vias.proximo_cruzamento(ij.x, ij.y, t) != ij
			if not todas:
				continue
			var achado := {"ij": ij, "sec": sec, "s": s, "pref": pref, "s_pref": s_pref,
				"bloco_pref": _bloco(ij, pref, s_pref)}
			if not mais_longo:
				return achado
			if melhor.is_empty() or float(achado["bloco_pref"]) > float(melhor["bloco_pref"]):
				melhor = achado
	return melhor


## A secundaria para no PARE; quando ela para, a preferencial nasce a `d` + o que
## anda nos 0,7 s da parada obrigatoria, a `v`. `d` < 0: o mais longe que o
## quarteirao deixa (brecha longa, a secundaria deve entrar antes).
func _c_pare(d: float, v: float, manobra: String, longe: bool) -> void:
	var rot := "pare_%s_%s" % [manobra.to_lower(), ("brecha_longa" if longe else "%dm_%dms" % [
		int(d), int(v)])]
	var achado := _achar_pare(64.0, longe)
	if achado.is_empty():
		_conta(rot, "achado", false, "sem esquina de PARE com a preferencial longa")
		return
	var ij: Vector2i = achado["ij"]
	var sec: int = achado["sec"]
	var s: int = achado["s"]
	var pref: int = achado["pref"]
	var s_pref: int = achado["s_pref"]
	var nasce := (float(achado["bloco_pref"]) - 10.0 if longe
		else d + v * _espera_pare)
	# Brecha longa: a preferencial vem devagar o bastante para chegar no conflito
	# uns 8 s depois de a secundaria cumprir o PARE (o quarteirao nao deixa ela
	# nascer longe a 11 m/s).
	if longe:
		v = clampf((nasce - 4.0) / 8.0, 4.0, v)
	print("\n=== %s em %s: secundaria eixo %d sentido %d, preferencial a %.0f m ===" % [
		rot, ij, sec, s, nasce])
	var quem := _carro_em(ij, sec, s, 0, 30.0, manobra)
	var r_quem := Rastro.new(quem)
	var med := Regua.new()
	var outro: Node3D = null
	var r_outro: Rastro = null
	var tt := 0.0
	var parou := -1.0
	var entrou := -1.0
	var ttc := INF
	var fim := INF
	while tt < 30.0 and tt < fim:
		await physics_frame
		tt += PASSO
		Semaforo.avancar(PASSO)
		med.passo([quem] if outro == null else [quem, outro])
		r_quem.gravar(tt)
		if r_outro != null:
			r_outro.gravar(tt)
		var bico := _bico_ate_linha(quem, ij, sec, s)
		# Parou perto da linha (a IA antiga para 2 m alem da pintada): nasce a
		# preferencial. Entrou e quando, depois de parado, o bico passa da borda
		# de dentro da zebra — entra no miolo. (Arrancar da linha enquanto a
		# preferencial passa na frente, para chegar depois dela, e o certo.)
		if parou < 0.0 and med.vel(quem) < 0.05 and bico < 12.0 and tt > 1.0:
			parou = tt
			outro = _carro_em(ij, pref, s_pref, 0, nasce, "RETO", v)
			r_outro = Rastro.new(outro)
		var miolo := _bico_ate_zebra(quem, ij, sec, s) + ZEBRA_ATE - Esquina.ZEBRA_RECUO
		if parou >= 0.0 and entrou < 0.0 and miolo < 0.0:
			entrou = tt
			# TTC da preferencial ate a faixa da secundaria, agora.
			var ao := Vector2(outro.global_position.x, outro.global_position.z)
			var dir := Vias.direcao(pref, s_pref)
			var d2 := Vector2(dir.x, dir.z)
			var faixa_sec := Vector2(Vias.linha_x(ij.x, s, 0), 0.0) if sec == 0 \
				else Vector2(0.0, Vias.linha_z(ij.y, s, 0))
			var ate := (faixa_sec - ao).dot(d2) - float((outro.get(&"_medidas") as Dictionary)[
				"comprimento"]) * 0.5
			ttc = ate / maxf(absf(float(outro.call(&"velocidade"))), 0.1) if ate > -2.0 else INF
			fim = tt + 8.0
	var x := Vector2(INF, INF)
	if r_outro != null:
		var faixa_pref := Vector2(0.0, Vias.linha_z(ij.y, s_pref, 0)) if pref == 1 \
			else Vector2(Vias.linha_x(ij.x, s_pref, 0), 0.0)
		x = r_quem.cruza(faixa_pref, Vector2(0.0, 1.0) if pref == 1 else Vector2(1.0, 0.0))
	var pet := _pet(r_quem, r_outro, x) if x.x != INF and r_outro != null else INF
	var antes := false
	if r_outro != null and x.x != INF:
		antes = r_quem.ocupa(x, 0.1).x < r_outro.ocupa(x, 0.1).x
	_relatar(rot, "entrou_s_depois_de_parar", "%.2f" % (entrou - parou) if entrou >= 0.0 else "nunca")
	_relatar(rot, "ttc_da_preferencial_s", "%.2f" % ttc if ttc < INF else "ja_passou")
	_relatar(rot, "pet_s", "%.2f" % pet)
	_relatar(rot, "entrou_antes_da_preferencial", antes)
	_conta(rot, "entrou", entrou >= 0.0, "atravessou (%.1f s depois de parar)" % (entrou - parou))
	if longe:
		_conta(rot, "brecha_longa", antes, "com a preferencial a %.0f m entrou antes dela" % nasce)
	else:
		_conta(rot, "ttc", ttc >= TTC_MIN, "quando entrou, a preferencial estava a %s do conflito" % (
			"%.2f s" % ttc if ttc < INF else "zero: ja tinha passado"))
	_conta(rot, "pet", pet >= PET_MIN, "PET %.2f s (minimo %.1f)" % [pet, PET_MIN])
	await _limpar([quem, outro])


# --- dois PAREs --------------------------------------------------------------------

func _c_fifo() -> void:
	var rot := "fifo"
	var achado := _achar_pare(32.0)
	if achado.is_empty():
		_conta(rot, "achado", false, "sem esquina de PARE")
		return
	var ij: Vector2i = achado["ij"]
	var sec: int = achado["sec"]
	var s: int = achado["s"]
	print("\n=== fifo em %s: A (eixo %d, %d) vira a esquerda, B de frente segue reto ===" % [
		ij, sec, s])
	var a := _carro_em(ij, sec, s, 0, 20.0, "ESQUERDA")
	var b := _carro_em(ij, sec, -s, 0, minf(38.0, _bloco(ij, sec, -s) - 6.0), "RETO")
	var ra := Rastro.new(a)
	var rb := Rastro.new(b)
	var tt := 0.0
	var ent_a := -1.0
	var ent_b := -1.0
	while tt < 30.0:
		await physics_frame
		tt += PASSO
		Semaforo.avancar(PASSO)
		ra.gravar(tt)
		rb.gravar(tt)
		if ent_a < 0.0 and _bico_ate_linha(a, ij, sec, s) < 0.0:
			ent_a = tt
		if ent_b < 0.0 and _bico_ate_linha(b, ij, sec, -s) < 0.0:
			ent_b = tt
		if ent_a >= 0.0 and ent_b >= 0.0 and tt > maxf(ent_a, ent_b) + 6.0:
			break
	var faixa_b := Vector2(Vias.linha_x(ij.x, -s, 0), 0.0) if sec == 0 \
		else Vector2(0.0, Vias.linha_z(ij.y, -s, 0))
	var x := ra.cruza(faixa_b, Vector2(1.0, 0.0) if sec == 0 else Vector2(0.0, 1.0))
	var pet := _pet(ra, rb, x) if x.x != INF else INF
	_relatar(rot, "entradas_s", "A %.2f, B %.2f" % [ent_a, ent_b])
	_relatar(rot, "pet_s", "%.2f" % pet)
	_relatar(rot, "folga_min_m", "%.2f" % _folga_min(ra, rb))
	_conta(rot, "ordem", ent_a >= 0.0 and ent_b >= 0.0 and ent_a < ent_b,
		"o que parou primeiro (A) saiu primeiro")
	_conta(rot, "pet", pet >= PET_MIN, "PET %.2f s (minimo %.1f)" % [pet, PET_MIN])
	await _limpar([a, b])


# --- nao tranca o cruzamento --------------------------------------------------------

func _c_saida() -> void:
	var rot := "saida"
	var achado := _achar("av_av")
	if achado.is_empty():
		_conta(rot, "achado", false, "sem cruzamento av_av")
		return
	var ij: Vector2i = achado["ij"]
	var eixo: int = achado["eixo"]
	var sentido: int = achado["sentido"]
	print("\n=== saida cheia em %s ===" % ij)
	_luz(ij, eixo, Semaforo.Luz.VERDE)
	var asf_sai := (Vias.meia_asfalto_z_no(ij.x, ij.y) if eixo == 0
		else Vias.meia_asfalto_x_no(ij.x, ij.y))
	# O parado: traseira 4 m depois da zebra de saida, na mesma faixa.
	var bloqueio := _carro_em(ij, eixo, sentido, 0, 0.0, "RETO")
	var comp_b := float((bloqueio.get(&"_medidas") as Dictionary)["comprimento"])
	var dir := Vias.direcao(eixo, sentido)
	var alvo := Vector3(float(ij.x) * Vias.TAM, 0.05, float(ij.y) * Vias.TAM) \
		+ dir * (asf_sai + ZEBRA_ATE + 4.0 + comp_b * 0.5)
	if eixo == 0:
		alvo.x = Vias.linha_x(ij.x, sentido, 0)
	else:
		alvo.z = Vias.linha_z(ij.y, sentido, 0)
	var prox := Vias.proximo_cruzamento(ij.x, ij.y, Vias.trecho(eixo, sentido, 0))
	bloqueio.call(&"plantar", ij, Vias.trecho(eixo, sentido, 0), alvo)
	var ia_b: Variant = bloqueio.get(&"_ia")
	if ia_b != null:
		(ia_b as RefCounted).set(&"roteiro_a", -8.0)
	else:
		bloqueio.call(&"expulsar_motorista")
	bloqueio.set(&"_velocidade", 0.0)
	var quem := _carro_em(ij, eixo, sentido, 0, 45.0, "RETO")
	var med := Regua.new()
	var tt := 0.0
	var solto := -1.0
	var menor_bico := INF
	var dentro_preso := false
	var passou := false
	while tt < 30.0:
		await physics_frame
		tt += PASSO
		med.passo([quem])
		var bico := _bico_ate_linha(quem, ij, eixo, sentido)
		if solto < 0.0:
			menor_bico = minf(menor_bico, bico)
			if bico < -0.5:
				dentro_preso = true
		if solto < 0.0 and tt > 4.0 and med.vel(quem) < 0.05:
			# Parado ha um tempo: solta o da frente.
			if tt > 9.0:
				solto = tt
				if ia_b != null:
					(ia_b as RefCounted).set(&"roteiro_a", NAN)
				else:
					bloqueio.queue_free()
		if solto > 0.0 and bico < -15.0:
			passou = true
			break
	_relatar(rot, "bico_antes_da_linha_preso_m", "%.2f" % menor_bico)
	_relatar(rot, "proximo_cruzamento", prox)
	_conta(rot, "espera_fora", menor_bico >= 0.0 and not dentro_preso,
		"esperou com o bico %.2f m antes da linha, e nao dentro do cruzamento" % menor_bico)
	_conta(rot, "segue", passou, "entrou quando a faixa andou")
	await _limpar([quem, bloqueio])


# --- conversao com gente na faixa ----------------------------------------------------

func _c_conversao(manobra: String) -> void:
	var rot := "conversao_%s" % manobra.to_lower()
	var achado := _achar("av_rua")
	if achado.is_empty():
		_conta(rot, "achado", false, "sem cruzamento av_rua")
		return
	var ij: Vector2i = achado["ij"]
	var eixo: int = achado["eixo"]
	var sentido: int = achado["sentido"]
	var saida := _saida(ij, eixo, sentido, manobra)
	var z := Esquina.zebra(ij, Esquina.braco_de_saida(saida))
	var lado := _lado_da_faixa(z, saida)
	var pernas := _pernas(z, -lado)
	print("\n=== %s em %s: pessoa atravessando o braco %s ===" % [rot, ij,
		Esquina.Braco.keys()[z.braco]])
	# O comeco do verde deste eixo: o outro esta no vermelho, e o boneco da rua
	# de saida no ANDA.
	_luz(ij, eixo, Semaforo.Luz.VERDE)
	var pessoa := _pessoa_em(pernas[0], pernas[1])
	var quem := _carro_em(ij, eixo, sentido, 1 if manobra == "ESQUERDA" else 0,
		minf(80.0, float(achado["recuo"]) - 8.0), manobra)
	var rq := Rastro.new(quem)
	var rp := Rastro.new(pessoa, 0.26)
	var med := Regua.new()
	var tt := 0.0
	var susto := false
	var virou := false
	var atravessou := false
	var c3 := Vector3(float(ij.x) * Vias.TAM, 0.0, float(ij.y) * Vias.TAM)
	var d_sai := Vias.direcao(saida.z, saida.w)
	var fim_do_outro_lado := Rotas.ponto(pernas[1])
	# A folga que conta e com a pessoa na rua: na calcada da esquina, carro
	# virando a um metro dela e a rua de sempre.
	var folga_na_rua := INF
	while tt < 40.0:
		await physics_frame
		tt += PASSO
		Semaforo.avancar(PASSO)
		var pp := Vector2(pessoa.global_position.x, pessoa.global_position.z)
		if Vias.no_asfalto(pessoa.global_position):
			var fq := -quem.global_transform.basis.z
			var mq: Dictionary = quem.get(&"_medidas")
			folga_na_rua = minf(folga_na_rua, _caixa_ponto(Vector2(quem.global_position.x,
				quem.global_position.z), Vector2(fq.x, fq.z).normalized(),
				float(mq["comprimento"]) * 0.5, float(mq["largura"]) * 0.5, pp) - 0.26)
		var pico0 := med.pico(quem)
		med.passo([quem])
		rq.gravar(tt)
		rp.gravar(tt)
		var trav: Variant = pessoa.get(&"_travessia")
		_tracar(quem, tt, med, pico0, "pessoa %s %s" % [pessoa.global_position.snappedf(0.1),
			str((trav as RefCounted).get(&"etapa")) if trav != null else "-"])
		var estado := String(pessoa.call(&"estado_nome"))
		if estado.contains("SUSTO") or estado.contains("TROPE") or estado.contains("CAIDO"):
			susto = true
		if (quem.global_position - c3).dot(d_sai) > 20.0:
			virou = true
		if _do_outro_lado(pessoa, z, -lado):
			atravessou = true
		if virou and atravessou:
			break
	var folga := folga_na_rua
	_relatar(rot, "folga_carro_pessoa_m", "%.2f (com ela na calcada: %.2f)" % [folga,
		_folga_min(rq, rp)])
	_relatar(rot, "freada_pico", "%.2f" % med.pico(quem))
	_conta(rot, "cede", folga >= FOLGA_PESSOA, "passou a %.2f m da pessoa (minimo %.1f)" % [
		folga, FOLGA_PESSOA])
	_conta(rot, "sem_susto", not susto, "a pessoa nao se assustou nem foi empurrada")
	_conta(rot, "freada", med.pico(quem) <= FREADA_MAX, "freada %.2f m/s2 (teto %.1f)" % [
		med.pico(quem), FREADA_MAX])
	_conta(rot, "virou", virou and atravessou, "os dois chegaram (carro %s, pessoa %s)" % [
		virou, atravessou])
	await _limpar([quem, pessoa])


## A direita no comeco do verde, com gente atravessando a zebra de saida em fila
## (o boneco dela anda o verde inteiro deste eixo). Esperando na linha, a janela
## ate a zebra e longa e cada um que chega cabe nela: na rua solta um carro assim
## perdeu dois verdes seguidos. Tem de virar ainda neste ciclo, cedendo a todos.
func _c_conversao_fluxo() -> void:
	var rot := "conversao_fluxo"
	var achado := _achar("av_rua")
	if achado.is_empty():
		_conta(rot, "achado", false, "sem cruzamento av_rua")
		return
	var ij: Vector2i = achado["ij"]
	var eixo: int = achado["eixo"]
	var sentido: int = achado["sentido"]
	var saida := _saida(ij, eixo, sentido, "DIREITA")
	var z := Esquina.zebra(ij, Esquina.braco_de_saida(saida))
	var lado := _lado_da_faixa(z, saida)
	print("\n=== %s em %s: cinco pessoas atravessando o braco %s no verde ===" % [rot, ij,
		Esquina.Braco.keys()[z.braco]])
	_luz(ij, eixo, Semaforo.Luz.VERDE)
	var quem := _carro_em(ij, eixo, sentido, 0, minf(60.0, float(achado["recuo"]) - 8.0), "DIREITA")
	var med := Regua.new()
	var gente: Array[Node3D] = []
	var lados: Array[float] = []
	var tt := 0.0
	var susto := ""
	var folga := INF
	var folga_parado := INF
	var onde_folga := ""
	var virou_t := INF
	var c3 := Vector3(float(ij.x) * Vias.TAM, 0.0, float(ij.y) * Vias.TAM)
	var d_sai := Vias.direcao(saida.z, saida.w)
	while tt < 45.0:
		await physics_frame
		tt += PASSO
		Semaforo.avancar(PASSO)
		# Uma a cada 2,5 s, dos dois lados, nos primeiros 10 s do verde.
		if gente.size() < 5 and tt >= 2.5 * gente.size():
			var l := lado if gente.size() % 2 == 0 else -lado
			var pernas := _pernas(z, l)
			gente.append(_pessoa_em(pernas[0], pernas[1]))
			lados.append(l)
		var pico0 := med.pico(quem)
		med.passo([quem])
		_tracar(quem, tt, med, pico0, "zebra: %s" % str(gente.map(func(g: Node3D) -> String:
			var gz := Vector2(g.global_position.x, g.global_position.z)
			return "%.1f/%.1f" % [z.ao_longo(gz), z.atravessado(gz)])))
		if OS.get_cmdline_user_args().has("--traco-quadro") and quem.get(&"_ia") != null:
			var iq := quem.get(&"_ia") as RefCounted
			print("[quadro] t=%.3f v=%.3f motivo %s a=%.2f curva %s lider %s d_ped %.2f vista %s s=%.2f" % [
				tt, float(quem.get(&"_velocidade")), quem.call(&"motivo_da_parada"),
				float(iq.get(&"_a")), str(iq.get(&"_a_curva_visto")), str(iq.get(&"_lider_visto")),
				float(iq.get(&"_d_pedestre")), str(iq.get(&"_travessia_vista")), float(iq.get(&"_s"))])
		var fq := -quem.global_transform.basis.z
		var mq: Dictionary = quem.get(&"_medidas")
		# Passando perto e com o carro andando: parado, gente passa rente ao bico
		# na faixa (ela anda fora da pintura para desviar de quem vem).
		var andando := med.vel(quem) >= 0.3
		for p: Node3D in gente:
			if Vias.no_asfalto(p.global_position):
				var f_p := _caixa_ponto(Vector2(quem.global_position.x,
					quem.global_position.z), Vector2(fq.x, fq.z).normalized(),
					float(mq["comprimento"]) * 0.5, float(mq["largura"]) * 0.5,
					Vector2(p.global_position.x, p.global_position.z)) - 0.26
				if not andando:
					folga_parado = minf(folga_parado, f_p)
				elif f_p < folga:
					folga = f_p
					var pz := Vector2(p.global_position.x, p.global_position.z)
					onde_folga = "t=%.1f %s estado %s ao_longo %.2f atravessado %.2f vel %s travessia %s | carro v=%.1f motivo %s" % [
						tt, p.name, str(p.call(&"estado_nome")), z.ao_longo(pz), z.atravessado(pz),
						Vector2((p.get(&"velocity") as Vector3).x, (p.get(&"velocity") as Vector3).z).snappedf(0.1),
						FiscalDeTravessia._travessia(p), med.vel(quem), quem.call(&"motivo_da_parada")]
			var est := String(p.call(&"estado_nome"))
			if susto.is_empty() and (est.contains("susto") or est.contains("trope") or est.contains("caido")):
				susto = "%s %s em t=%.1f" % [p.name, est, tt]
		if virou_t == INF and (quem.global_position - c3).dot(d_sai) > 20.0:
			virou_t = tt
		var todos := true
		for k in gente.size():
			todos = todos and _do_outro_lado(gente[k], z, lados[k])
		if virou_t < INF and todos and gente.size() == 5:
			break
	var atravessaram := 0
	for k in gente.size():
		if _do_outro_lado(gente[k], z, lados[k]):
			atravessaram += 1
		else:
			var gz := Vector2(gente[k].global_position.x, gente[k].global_position.z)
			print("[bancada_cruzamento] %s nao atravessou: %s estado %s ao_longo %.2f atravessado %.2f lado %.0f travessia %s" % [
				rot, gente[k].name, str(gente[k].call(&"estado_nome")), z.ao_longo(gz), z.atravessado(gz),
				lados[k], FiscalDeTravessia._travessia(gente[k])])
	print("[bancada_cruzamento] %s menor folga: %s" % [rot, onde_folga])
	_relatar(rot, "virou_s", "%.1f" % virou_t)
	_relatar(rot, "folga_carro_pessoa_m", "%.2f andando (parado: %.2f)" % [folga, folga_parado])
	_relatar(rot, "freada_pico", "%.2f" % med.pico(quem))
	_conta(rot, "no_ciclo", virou_t <= Semaforo.CICLO,
		"virou em %.1f s, antes do verde seguinte (%.0f s)" % [virou_t, Semaforo.CICLO])
	_conta(rot, "cede", folga >= FOLGA_PESSOA, "passou a %.2f m de quem atravessava (minimo %.1f)" % [
		folga, FOLGA_PESSOA])
	_conta(rot, "sem_susto", susto.is_empty(), "ninguem se assustou nem foi empurrado %s" % susto)
	_conta(rot, "freada", med.pico(quem) <= FREADA_MAX, "freada %.2f m/s2 (teto %.1f)" % [
		med.pico(quem), FREADA_MAX])
	_conta(rot, "atravessaram", atravessaram == 5, "%d de 5 do outro lado" % atravessaram)
	var todos_nos: Array = [quem]
	todos_nos.append_array(gente)
	await _limpar(todos_nos)


# --- brecha sem sinal ----------------------------------------------------------------

func _c_brecha() -> void:
	var rot := "brecha"
	# Quarteirao longo depois da zebra: com a esquina seguinte a 32 m o carro ja
	# freia para o PARE dela antes de passar pela pessoa.
	var achado := _achar_frente_longa("rua_rua")
	if achado.is_empty():
		_conta(rot, "achado", false, "sem cruzamento rua_rua")
		return
	var ij: Vector2i = achado["ij"]
	var eixo: int = achado["eixo"]
	var sentido: int = achado["sentido"]
	var t := Vias.trecho(eixo, sentido, 0)
	var z := Esquina.zebra(ij, Esquina.braco_de_saida(t))
	var lado := _lado_da_faixa(z, t)
	# Comeca do lado da faixa dos carros: tem de esperar a brecha antes do
	# primeiro passo.
	var pernas := _pernas(z, lado)
	print("\n=== brecha em %s: pessoa no braco %s, fluxo pela preferencial ===" % [ij,
		Esquina.Braco.keys()[z.braco]])
	var pessoa := _pessoa_em(pernas[0], pernas[1])
	var rp := Rastro.new(pessoa, 0.26)
	var nascer: Array[float] = [0.0, 3.0, 8.0, 17.0, 21.0, 24.0]
	var fluxo: Array[Node3D] = []
	var rastros: Array[Rastro] = []
	var med := Regua.new()
	var d_fluxo := minf(60.0, float(achado["recuo"]) - 8.0)
	var tt := 0.0
	var susto := false
	var desceu := -1.0
	var atravessou := false
	var fim_do_outro_lado := Rotas.ponto(pernas[1])
	var freada_perto: Array[float] = []
	while tt < 45.0:
		await physics_frame
		tt += PASSO
		Semaforo.avancar(PASSO)
		while fluxo.size() < nascer.size() and tt >= nascer[fluxo.size()]:
			var c := _carro_em(ij, eixo, sentido, 0, d_fluxo, "RETO", _vel_rua)
			fluxo.append(c)
			rastros.append(Rastro.new(c))
			freada_perto.append(0.0)
		var picos0: Array[float] = []
		for c: Node3D in fluxo:
			picos0.append(med.pico(c))
		med.passo(fluxo)
		for k in fluxo.size():
			# So a freada ate passar da zebra da pessoa: depois dela o carro para no
			# PARE da esquina seguinte (a 32 m), e isso nao e com a pessoa.
			var perto := z.ao_longo(Vector2(fluxo[k].global_position.x,
				fluxo[k].global_position.z)) < z.hi + 3.0
			if perto:
				freada_perto[k] = maxf(freada_perto[k], med.pico(fluxo[k]))
			if med.pico(fluxo[k]) > picos0[k] and med.pico(fluxo[k]) > 0.8:
				_tracar(fluxo[k], tt, med, picos0[k], "pessoa %s" % pessoa.global_position.snappedf(0.1))
			med.desac.erase(fluxo[k].get_instance_id())
		rp.gravar(tt)
		for r: Rastro in rastros:
			r.gravar(tt)
		var estado := String(pessoa.call(&"estado_nome"))
		if estado.contains("SUSTO") or estado.contains("TROPE") or estado.contains("CAIDO"):
			susto = true
		var p2 := Vector2(pessoa.global_position.x, pessoa.global_position.z)
		if desceu < 0.0 and absf(z.atravessado(p2)) <= z.meia:
			desceu = tt
		if _do_outro_lado(pessoa, z, lado):
			atravessou = true
		if atravessou and fluxo.size() == nascer.size() and tt > nascer[nascer.size() - 1] + 8.0:
			break
	var faixa := Vector2(Vias.linha_x(ij.x, sentido, 0), 0.0) if eixo == 0 \
		else Vector2(0.0, Vias.linha_z(ij.y, sentido, 0))
	var x := rp.cruza(faixa, Vector2(1.0, 0.0) if eixo == 0 else Vector2(0.0, 1.0))
	var menor_pet := INF
	var pets: Array[String] = []
	var pior_freada := 0.0
	for k in rastros.size():
		var pet := _pet(rp, rastros[k], x) if x.x != INF else INF
		pets.append("%.2f" % pet)
		menor_pet = minf(menor_pet, pet)
		pior_freada = maxf(pior_freada, freada_perto[k])
	_relatar(rot, "desceu_da_calcada_s", "%.2f" % desceu)
	_relatar(rot, "pet_com_cada_um_s", ", ".join(pets))
	_relatar(rot, "freada_pior_carro", "%.2f" % pior_freada)
	_conta(rot, "atravessou", atravessou, "atravessou (desceu da calcada em %.1f s)" % desceu)
	_conta(rot, "pet", menor_pet >= PET_MIN, "menor PET %.2f s (minimo %.1f)" % [menor_pet, PET_MIN])
	_conta(rot, "ninguem_freou", pior_freada <= 1.0,
		"o carro que mais freou: %.2f m/s2 (teto 1,0: a brecha era dela)" % pior_freada)
	_conta(rot, "sem_susto", not susto, "a pessoa nao se assustou")
	var todos: Array = [pessoa]
	todos.append_array(fluxo)
	await _limpar(todos)


# --- no meio do quarteirao ------------------------------------------------------------

## Onde uma viela encosta na avenida a calcada atravessa a avenida sem cruzamento
## de carro: sem sinal, sem PARE, sem evento no plano do motorista. A pessoa
## espera a brecha; o carro que a ve atravessando para, ou passa devagar se ela
## esta na faixa ao lado. Fluxo nas duas faixas de um sentido.
## O no de meio de quarteirao mais perto da origem onde uma viela encosta na
## avenida: {ij, braco da zebra de la, sentido de quem vem}; vazio: nao achou.
func _achar_meio() -> Dictionary:
	for raio in range(0, 20):
		for di in range(-raio, raio + 1):
			for dj in range(-raio, raio + 1):
				if maxi(absi(di), absi(dj)) != raio:
					continue
				var ij := Vector2i(di, dj)
				if not Rotas.existe_no(ij.x, ij.y) or Vias.existe_cruzamento(ij.x, ij.y):
					continue
				if MalhaUrbana.via_x(ij.x) != MalhaUrbana.Via.AVENIDA:
					continue
				for b: int in [Esquina.Braco.N, Esquina.Braco.S]:
					if not Esquina.existe_braco(ij, b):
						continue
					var sentido := 1 if b == Esquina.Braco.N else -1
					if _bloco(ij, 0, sentido) < 60.0:
						continue
					return {"ij": ij, "braco": b, "sentido": sentido}
	return {}


func _c_meio_de_quadra() -> void:
	var rot := "meio"
	var achado := _achar_meio()
	if achado.is_empty():
		_conta(rot, "achado", false, "sem viela encostando numa avenida")
		return
	var ij: Vector2i = achado["ij"]
	var sentido: int = achado["sentido"]
	var z := Esquina.zebra(ij, achado["braco"])
	var lado := _lado_da_faixa(z, Vias.trecho(0, sentido, 0))
	var pernas := _pernas(z, lado)
	print("
=== meio de quadra em %s: pessoa atravessando a avenida (braco %s) ===" % [ij,
		Esquina.Braco.keys()[z.braco]])
	var pessoa := _pessoa_em(pernas[0], pernas[1])
	var rp := Rastro.new(pessoa, 0.26)
	var nascer: Array[float] = [0.0, 2.5, 6.0, 15.0, 19.0, 22.0]
	var fluxo: Array[Node3D] = []
	var rastros: Array[Rastro] = []
	var med := Regua.new()
	var d_fluxo := minf(90.0, _bloco(ij, 0, sentido) - 8.0)
	var tt := 0.0
	var susto := false
	var atravessou := false
	var freada := 0.0
	var fim_do_outro_lado := Rotas.ponto(pernas[1])
	while tt < 50.0:
		await physics_frame
		tt += PASSO
		while fluxo.size() < nascer.size() and tt >= nascer[fluxo.size()]:
			var c := _carro_em(ij, 0, sentido, fluxo.size() % 2, d_fluxo, "RETO", _vel_avenida)
			# Como o `Transito` planta: na velocidade da via, com a trava de nascer
			# do motorista valendo (gente atravessando logo a frente).
			var ia_f: Variant = c.get(&"_ia")
			if ia_f != null:
				(ia_f as RefCounted).call(&"_velocidade_de_nascer")
			fluxo.append(c)
			rastros.append(Rastro.new(c))
		med.passo(fluxo)
		for c: Node3D in fluxo:
			if z.ao_longo(Vector2(c.global_position.x, c.global_position.z)) < z.hi + 3.0:
				freada = maxf(freada, med.pico(c))
				if OS.get_cmdline_user_args().has("--traco") and med.pico(c) > 2.0:
					var ia_m: Variant = c.get(&"_ia")
					print("[traco] t=%.2f %s freia %.2f v=%.1f %s motivo %s vista %s lider %s | pessoa %s %s" % [
						tt, c.name, med.pico(c), med.vel(c),
						Vector2(c.global_position.x, c.global_position.z).snappedf(0.1),
						c.call(&"motivo_da_parada"),
						str((ia_m as RefCounted).get(&"_travessia_vista")) if ia_m != null else "-",
						str((ia_m as RefCounted).get(&"_lider_visto")) if ia_m != null else "-",
						Vector2(pessoa.global_position.x, pessoa.global_position.z).snappedf(0.1),
						FiscalDeTravessia._travessia(pessoa)])
			med.desac.erase(c.get_instance_id())
		rp.gravar(tt)
		for r: Rastro in rastros:
			r.gravar(tt)
		var estado := String(pessoa.call(&"estado_nome"))
		if estado.contains("susto") or estado.contains("trope") or estado.contains("caido"):
			susto = true
		var falta := pessoa.global_position - fim_do_outro_lado
		falta.y = 0.0
		# Do outro lado da avenida, na calcada: aqui a calcada faz T (a viela so
		# existe de um lado) e o canto de la fica fora da linha reta da travessia.
		var ac := z.atravessado(Vector2(pessoa.global_position.x, pessoa.global_position.z))
		if signf(ac) == -lado and absf(ac) > z.meia + 0.3:
			atravessou = true
		if OS.get_cmdline_user_args().has("--traco") and fmod(tt, 1.0) < PASSO:
			print("[traco] t=%.0f pessoa %s %s travessia %s falta %.1f" % [tt,
				pessoa.global_position.snappedf(0.1), str(pessoa.call(&"estado_nome")),
				FiscalDeTravessia._travessia(pessoa), falta.length()])
		if atravessou and fluxo.size() == nascer.size() and tt > nascer[nascer.size() - 1] + 10.0:
			break
	var menor := INF
	for r: Rastro in rastros:
		menor = minf(menor, _folga_min(r, rp))
	_relatar(rot, "folga_min_carro_pessoa_m", "%.2f" % menor)
	_relatar(rot, "freada_pior_carro", "%.2f" % freada)
	_conta(rot, "atravessou", atravessou, "a pessoa atravessou a avenida")
	_conta(rot, "sem_susto", not susto, "sem susto, tropeco nem queda")
	_conta(rot, "folga", menor >= FOLGA_PESSOA, "nenhum carro passou a menos de %.1f m dela (%.2f)" % [
		FOLGA_PESSOA, menor])
	_conta(rot, "freada", freada <= FREADA_MAX, "freada %.2f m/s2 (teto %.1f)" % [freada, FREADA_MAX])
	var todos: Array = [pessoa]
	todos.append_array(fluxo)
	await _limpar(todos)


# --- as duas zebras do meio de quadra ---------------------------------------------------

## No meio do quarteirao as duas zebras da avenida ficam a 5 m uma da outra.
## A pessoa A desce na de la e o carro que vem perto tem de parar e esperar
## por ela; a pessoa B chega a de ca junto com ele e decide descer com ele
## parado. O carro nao pode esperar com a lataria em cima
## da de ca (quem a atravessa passa rente e leva um empurrao quando ele arranca:
## rua solta, duas vezes no mesmo ponto), e ninguem encosta em ninguem.
func _c_meio_par() -> void:
	var rot := "meio_par"
	var achado := _achar_meio()
	if achado.is_empty():
		_conta(rot, "achado", false, "sem viela encostando numa avenida")
		return
	var ij: Vector2i = achado["ij"]
	var sentido: int = achado["sentido"]
	var oposto: int = Esquina.Braco.S if int(achado["braco"]) == Esquina.Braco.N else Esquina.Braco.N
	if not Esquina.existe_braco(ij, oposto):
		_conta(rot, "achado", false, "o no %s so tem uma zebra na avenida" % ij)
		return
	var trecho := Vias.trecho(0, sentido, 0)
	var dist := 18.0
	var dir := Vias.direcao(0, sentido)
	var nasce := Vector3(float(ij.x) * Vias.TAM, 0.0, float(ij.y) * Vias.TAM) - dir * dist
	var z_la := Esquina.zebra(ij, achado["braco"])
	var z_ca := Esquina.zebra(ij, oposto)
	var n2 := Vector2(nasce.x, nasce.z)
	if z_la.centro.distance_to(n2) < z_ca.centro.distance_to(n2):
		var troca := z_la
		z_la = z_ca
		z_ca = troca
	print("\n=== meio_par em %s: A atravessa a zebra %s, B a %s, pela frente do carro ===" % [
		ij, Esquina.Braco.keys()[z_la.braco], Esquina.Braco.keys()[z_ca.braco]])
	var lado_la := _lado_da_faixa(z_la, trecho)
	var lado_ca := _lado_da_faixa(z_ca, trecho)
	var pernas_a := _pernas(z_la, lado_la)
	var pernas_b := _pernas(z_ca, lado_ca)
	var grupo: Array[Node3D] = []
	var rastros: Array[Rastro] = []
	var b: Node3D = null
	var c: Node3D = null
	var rc: Rastro = null
	var med := Regua.new()
	var tt := 0.0
	var parado_s := 0.0
	var parado_max := 0.0
	var parou := false
	var em_cima := 0
	var freada := 0.0
	var susto := ""
	var la := {}
	var passou := false
	while tt < 80.0:
		await physics_frame
		tt += PASSO
		if grupo.is_empty():
			var n := _pessoa_em(pernas_a[0], pernas_a[1])
			grupo.append(n)
			rastros.append(Rastro.new(n, 0.26))
		# O carro vem quando A desce da calcada, perto e devagar o bastante para
		# ter de parar antes de ela sair da faixa dele; B nasce junto, na esquina
		# da de ca.
		var a := grupo[0]
		if c == null and FiscalDeTravessia._travessia(a).begins_with("etapa 1"):
			c = _carro_em(ij, 0, sentido, 0, dist, "RETO", 6.0)
			rc = Rastro.new(c)
			b = _pessoa_em(pernas_b[0], pernas_b[1])
			grupo.append(b)
			rastros.append(Rastro.new(b, 0.26))
		for k in grupo.size():
			rastros[k].gravar(tt)
		if c != null:
			med.passo([c])
			freada = maxf(freada, med.pico(c))
			if OS.get_cmdline_user_args().has("--traco") and med.pico(c) > 2.5:
				print("[traco] t=%.2f carro freia %.2f v=%.2f %s" % [tt, med.pico(c), med.vel(c),
					Vector2(c.global_position.x, c.global_position.z).snappedf(0.01)])
			med.desac.erase(c.get_instance_id())
			rc.gravar(tt)
			var v := med.vel(c)
			parado_s = parado_s + PASSO if v < 0.3 else 0.0
			if (c.global_position - nasce).dot(dir) < dist + 5.0:
				parado_max = maxf(parado_max, parado_s)
			if v < 0.3 and (_lataria_na_zebra(c, z_ca) or _lataria_na_zebra(c, z_la)):
				em_cima += 1
			# Parado por elas: perto do no, e nao no sinal do cruzamento seguinte.
			parou = parou or (parado_s > 0.5 and (c.global_position - nasce).dot(dir) < dist + 5.0)
			passou = passou or (c.global_position - nasce).dot(dir) > dist + 15.0
		for p: Node3D in grupo:
			var est := String(p.call(&"estado_nome"))
			if susto.is_empty() and (est.contains("susto") or est.contains("trope") or est.contains("caido")):
				susto = "%s %s em t=%.1f" % ["B" if p == b else p.name, est, tt]
			if p == b:
				if _do_outro_lado(p, z_ca, lado_ca):
					la[p] = true
			elif _do_outro_lado(p, z_la, lado_la):
				la[p] = true
		if OS.get_cmdline_user_args().has("--traco") and fmod(tt, 0.25) < PASSO and c != null:
			var ia_t: Variant = c.get(&"_ia")
			print("[traco] t=%.2f carro v=%.1f %s motivo %s vista %s em_cima %s | A %s %s | B %s %s" % [
				tt, med.vel(c), Vector2(c.global_position.x, c.global_position.z).snappedf(0.1),
				c.call(&"motivo_da_parada"),
				str((ia_t as RefCounted).get(&"_travessia_vista")) if ia_t != null else "-",
				_lataria_na_zebra(c, z_ca) or _lataria_na_zebra(c, z_la),
				FiscalDeTravessia._travessia(a), Vector2(a.global_position.x, a.global_position.z).snappedf(0.1),
				FiscalDeTravessia._travessia(b), Vector2(b.global_position.x, b.global_position.z).snappedf(0.1)])
		if b != null and la.size() == grupo.size() and passou:
			break
	var menor := INF
	if rc != null:
		for r: Rastro in rastros:
			menor = minf(menor, _folga_min(rc, r))
	_relatar(rot, "parado_s_perto_do_no", "%.1f" % parado_max)
	_relatar(rot, "quadros_parado_em_cima_da_zebra", em_cima)
	_relatar(rot, "folga_min_carro_pessoa_m", "%.2f" % menor)
	_relatar(rot, "freada_pico", "%.2f" % freada)
	_conta(rot, "parou", parou, "o carro parou por quem atravessava a zebra de la")
	_conta(rot, "faixa_livre", parou and em_cima == 0,
		"esperou sem a lataria em cima de zebra nenhuma (%d quadros em cima)" % em_cima)
	_conta(rot, "folga", menor >= FOLGA_PESSOA, "nenhuma pessoa a menos de %.1f m da lataria (%.2f)" % [
		FOLGA_PESSOA, menor])
	_conta(rot, "sem_susto", susto.is_empty(), "sem susto, tropeco nem queda %s" % susto)
	_conta(rot, "freada", freada <= FREADA_MAX, "freada %.2f m/s2 (teto %.1f)" % [freada, FREADA_MAX])
	_conta(rot, "atravessaram", b != null and la.size() == grupo.size() and passou,
		"todos do outro lado (%d de %d) e o carro seguiu (%s)" % [la.size(), grupo.size(), passou])
	var todos: Array = [c]
	todos.append_array(grupo)
	await _limpar(todos)


## A lataria do carro `c` cobre alguma parte da pintura da zebra `z`?
static func _lataria_na_zebra(c: Node3D, z: Esquina.Zebra) -> bool:
	var m: Dictionary = c.get(&"_medidas")
	var mc := float(m["comprimento"]) * 0.5
	var ml := float(m["largura"]) * 0.5
	var p := Vector2(c.global_position.x, c.global_position.z)
	var fw := -c.global_transform.basis.z
	var f := Vector2(fw.x, fw.z).normalized()
	var al := z.ao_longo(p)
	var ac := z.atravessado(p)
	var r_al := absf(f.dot(z.a)) * mc + absf(f.dot(z.u)) * ml
	var r_ac := absf(f.dot(z.u)) * mc + absf(f.dot(z.a)) * ml
	return al + r_al > z.lo and al - r_al < z.hi and ac + r_ac > -z.meia and ac - r_ac < z.meia


# --- o boneco -------------------------------------------------------------------------

func _c_boneco() -> void:
	var rot := "boneco"
	var achado := _achar("av_av")
	if achado.is_empty():
		_conta(rot, "achado", false, "sem cruzamento av_av")
		return
	var ij: Vector2i = achado["ij"]
	print("\n=== boneco em %s: oito pessoas, 70 s ===" % ij)
	Semaforo._agora = 0.0
	var pessoas: Array[Node3D] = []
	var plano: Array = []
	for sx: int in [1, -1]:
		for sz: int in [1, -1]:
			var no := Vector4i(ij.x, ij.y, sx, sz)
			plano.append([no, Vector4i(ij.x, ij.y, sx, -sz)])
			plano.append([no, Vector4i(ij.x, ij.y, -sx, sz)])
	var fiscal := FiscalDeTravessia.new()
	var tt := 0.0
	while tt < 70.0:
		await physics_frame
		tt += PASSO
		Semaforo.avancar(PASSO)
		# Uma pessoa a cada 3,7 s: chegam em fases diferentes do ciclo.
		if pessoas.size() < plano.size() and tt >= 3.7 * float(pessoas.size()):
			var par: Array = plano[pessoas.size()]
			pessoas.append(_pessoa_em(par[0], par[1]))
		for p: Node3D in pessoas:
			if is_instance_valid(p):
				fiscal.olhar(p, Semaforo.agora())
	_relatar(rot, "descidas", fiscal.descidas)
	_relatar(rot, "fora_do_anda", fiscal.fora)
	for d: String in fiscal.detalhes:
		print("[bancada_cruzamento] boneco fora: %s" % d)
	_conta(rot, "atravessam", fiscal.descidas >= 6, "%d travessias comecadas" % fiscal.descidas)
	_conta(rot, "anda", fiscal.fora == 0, "%d comecadas fora do ANDA" % fiscal.fora)
	await _limpar(pessoas)


# --- rua solta ---------------------------------------------------------------------------

func _c_solta() -> void:
	var rot := "solta"
	var achado := _achar("av_av")
	if achado.is_empty():
		_conta(rot, "achado", false, "sem cruzamento av_av")
		return
	var ij: Vector2i = achado["ij"]
	var centro := Vector3(float(ij.x) * Vias.TAM, 0.0, float(ij.y) * Vias.TAM)
	print("\n=== rua solta em volta de %s: %d carros, %d pessoas, %.0f s ===" % [ij,
		SOLTA_CARROS, SOLTA_PESSOAS, _solta_s])
	Semaforo._agora = 0.0
	var carros: Array[Node3D] = []
	var pessoas: Array[Node3D] = []
	for k in SOLTA_CARROS:
		var c := _carro_solto(centro, carros, null)
		if c != null:
			carros.append(c)
	for k in SOLTA_PESSOAS:
		var p := _pessoa_solta(centro)
		if p != null:
			pessoas.append(p)
	var fiscal := FiscalDeTravessia.new()
	var med := Regua.new()
	var contatos_cc := 0
	var contatos_cp := 0
	var em_contato := {}
	var parado := {}
	var pior_parado := 0.0
	var pior_quem := ""
	var andado := 0.0
	var antes := {}
	var freadas_fortes := 0
	var forte := {}
	var estado_ruim := {}
	var detalhes_pessoa: Array[String] = []
	var fora_da_faixa := {}
	var detalhes_fora: Array[String] = []
	# Quando cada carro nasceu: a freada dos primeiros 2 s e do nascimento (o
	# Transito tambem planta carro andando), e nao da direcao.
	var nasceu := {}
	var detalhes_freada: Array[String] = []
	var detalhes_parado: Array[String] = []
	var detalhes: Array[String] = []
	var tt := 0.0
	var recicla := 0
	while tt < _solta_s:
		await physics_frame
		tt += PASSO
		Semaforo.avancar(PASSO)
		med.passo(carros)
		# Os corpos agora.
		var cp: Array[Vector2] = []
		var cf: Array[Vector2] = []
		var cm: Array[Vector2] = []
		for c: Node3D in carros:
			var fw := -c.global_transform.basis.z
			cp.append(Vector2(c.global_position.x, c.global_position.z))
			cf.append(Vector2(fw.x, fw.z).normalized())
			var m: Dictionary = c.get(&"_medidas")
			cm.append(Vector2(float(m["comprimento"]) * 0.5, float(m["largura"]) * 0.5))
		for a in carros.size():
			for b in range(a + 1, carros.size()):
				if cp[a].distance_squared_to(cp[b]) > 49.0:
					continue
				var chave := "%d-%d" % [carros[a].get_instance_id(), carros[b].get_instance_id()]
				var toca := _sat(cp[a], cf[a], cm[a].x, cm[a].y, cp[b], cf[b], cm[b].x, cm[b].y) < -0.02
				if toca and not em_contato.has(chave):
					contatos_cc += 1
					if detalhes.size() < 10:
						detalhes.append("t=%.1f %s x %s em %s" % [tt, carros[a].name, carros[b].name,
							(cp[a] + cp[b]) * 0.5])
				if toca:
					em_contato[chave] = true
				else:
					em_contato.erase(chave)
			for p: Node3D in pessoas:
				if not is_instance_valid(p):
					continue
				var pp := Vector2(p.global_position.x, p.global_position.z)
				if cp[a].distance_squared_to(pp) > 16.0:
					continue
				var chave := "%d-%d" % [carros[a].get_instance_id(), p.get_instance_id()]
				var toca := _caixa_ponto(cp[a], cf[a], cm[a].x, cm[a].y, pp) - 0.26 < -0.02
				if toca and not em_contato.has(chave):
					contatos_cp += 1
					if detalhes.size() < 10:
						var ij_c := Vias.cruzamento_mais_proximo(p.global_position)
						var rel := pp - Vector2(float(ij_c.x) * Vias.TAM, float(ij_c.y) * Vias.TAM)
						var ia_c: Variant = carros[a].get(&"_ia")
						var vp := p.get(&"velocity") as Vector3
						detalhes.append(("t=%.1f %s (%.1f m/s, motivo %s, %s) x %s (estado %s, travessia %s, "
							+ "vel %s) a %s do centro de %s") % [tt, carros[a].name, med.vel(carros[a]),
							carros[a].call(&"motivo_da_parada"), ("vez %s juiz %s %s" % [
							str((ia_c as RefCounted).get(&"pub_vez")), str((ia_c as RefCounted).get(&"_veredito")),
							String((ia_c as RefCounted).get(&"_motivo_juiz"))]) if ia_c != null else "-",
							p.name, str(p.call(&"estado_nome")), FiscalDeTravessia._travessia(p),
							Vector2(vp.x, vp.z).snappedf(0.1), rel.snappedf(0.1), ij_c])
				if toca:
					em_contato[chave] = true
				else:
					em_contato.erase(chave)
		for p: Node3D in pessoas:
			if is_instance_valid(p):
				fiscal.olhar(p, Semaforo.agora())
				# Susto, tropeco e queda: com o carro mais perto e o que ele decidia.
				var est := String(p.call(&"estado_nome"))
				var ruim := est.contains("susto") or est.contains("trope") or est.contains("caido")
				var pid := p.get_instance_id()
				if ruim and not estado_ruim.has(pid):
					var pp2 := Vector2(p.global_position.x, p.global_position.z)
					var perto_k := -1
					var perto_d := INF
					for k2 in carros.size():
						var dk := _caixa_ponto(cp[k2], cf[k2], cm[k2].x, cm[k2].y, pp2)
						if dk < perto_d:
							perto_d = dk
							perto_k = k2
					# Tropeco ou queda com a lataria encostada e contato: o `Atropelo`
					# empurra quem o carro lento toca antes de a caixa entrar 2 cm nela
					# (a primeira rodada de 10 min teve dois assim e 0 contatos).
					var empurrao := not est.contains("susto") and perto_d - 0.26 < 0.3
					if empurrao:
						contatos_cp += 1
					var ij_p := Vias.cruzamento_mais_proximo(p.global_position)
					var info := "-"
					if perto_k >= 0 and detalhes_pessoa.size() < 12:
						var ia_p: Variant = carros[perto_k].get(&"_ia")
						info = "%s%s a %.2f m da lataria, %.1f m/s, motivo %s, lider %s, vez %s juiz %s %s" % [
							"EMPURRAO " if empurrao else "",
							carros[perto_k].name, perto_d, med.vel(carros[perto_k]),
							carros[perto_k].call(&"motivo_da_parada"),
							str((ia_p as RefCounted).get(&"_lider_visto")) if ia_p != null else "-",
							str((ia_p as RefCounted).get(&"pub_vez")) if ia_p != null else "-",
							str((ia_p as RefCounted).get(&"_veredito")) if ia_p != null else "-",
							String((ia_p as RefCounted).get(&"_motivo_juiz")) if ia_p != null else ""]
					if detalhes_pessoa.size() < 12:
						detalhes_pessoa.append("t=%.1f %s %s em %s de %s (asfalto %s) travessia %s | carro %s" % [
							tt, p.name, est, (pp2 - Vector2(float(ij_p.x) * Vias.TAM,
							float(ij_p.y) * Vias.TAM)).snappedf(0.1), ij_p, Vias.no_asfalto(p.global_position),
							FiscalDeTravessia._travessia(p), info])
				if ruim:
					estado_ruim[pid] = true
				else:
					estado_ruim.erase(pid)
				# No asfalto e fora de qualquer faixa de travessia (no miolo, no meio
				# da rua): uma vez por pessoa, com a historia.
				if Vias.no_asfalto(p.global_position) and not fora_da_faixa.has(pid):
					var pp3 := Vector2(p.global_position.x, p.global_position.z)
					var ij3 := Vias.cruzamento_mais_proximo(p.global_position)
					var na_faixa := false
					for no3: Vector2i in [ij3, Vector2i(roundi(pp3.x / Vias.TAM), roundi(pp3.y / Vias.TAM))]:
						for b3 in 4:
							var z3 := Esquina.zebra(no3, b3)
							var al3 := z3.ao_longo(pp3)
							if al3 >= z3.lo - 1.5 and al3 <= z3.hi + 1.5 and absf(z3.atravessado(pp3)) <= z3.meia + 1.0:
								na_faixa = true
					if not na_faixa:
						fora_da_faixa[pid] = true
						if detalhes_fora.size() < 12:
							detalhes_fora.append("t=%.1f %s em %s de %s estado %s vel %s travessia %s no %s destino %s alvo %s" % [
								tt, p.name, (pp3 - Vector2(float(ij3.x) * Vias.TAM, float(ij3.y) * Vias.TAM)).snappedf(0.1),
								ij3, str(p.call(&"estado_nome")), Vector2((p.get(&"velocity") as Vector3).x,
								(p.get(&"velocity") as Vector3).z).snappedf(0.1), FiscalDeTravessia._travessia(p),
								str(p.get(&"_no")), str(p.get(&"_destino")), (p.get(&"_alvo") as Vector3).snappedf(0.1)])
		for k in carros.size():
			var c := carros[k]
			var id := c.get_instance_id()
			var v := med.vel(c)
			if antes.has(id):
				var passo_m := (antes[id] as Vector2).distance_to(cp[k])
				if passo_m < 1.0:
					andado += passo_m
			antes[id] = cp[k]
			if med.pico(c) > 4.5 and tt - float(nasceu.get(id, 0.0)) > 2.0:
				if not forte.has(id):
					forte[id] = true
					freadas_fortes += 1
					if detalhes_freada.size() < 12:
						var ia_c: Variant = c.get(&"_ia")
						detalhes_freada.append("t=%.1f %s v=%.1f motivo=%s %s" % [tt, c.name, v,
							c.call(&"motivo_da_parada"), ("vez=%s juiz=%s %s lider=%s" % [
							str((ia_c as RefCounted).get(&"pub_vez")),
							str((ia_c as RefCounted).get(&"_veredito")),
							String((ia_c as RefCounted).get(&"_motivo_juiz")),
							str((ia_c as RefCounted).get(&"_lider_visto"))]) if ia_c != null else ""])
			elif med.pico(c) < 1.0:
				forte.erase(id)
			med.desac.erase(id)
			var acc := float(parado.get(id, 0.0)) + PASSO if v < 0.3 else 0.0
			parado[id] = acc
			# Parado ha muito: por que, e quem ele espera (a cada 10 s, a partir de 20).
			if acc >= 20.0 and fmod(acc, 10.0) < PASSO and detalhes_parado.size() < 16:
				var ia_p: Variant = c.get(&"_ia")
				var mj := String((ia_p as RefCounted).get(&"_motivo_juiz")) if ia_p != null else ""
				var sobre := ""
				for p: Node3D in pessoas:
					if is_instance_valid(p) and not mj.is_empty() and mj.contains(String(p.name) + " "):
						var pp4 := Vector2(p.global_position.x, p.global_position.z)
						sobre = " | %s estado %s em %s vel %s travessia %s alvo %s no %s destino %s leito %s" % [
							p.name, str(p.call(&"estado_nome")), pp4.snappedf(0.1),
							Vector2((p.get(&"velocity") as Vector3).x, (p.get(&"velocity") as Vector3).z).snappedf(0.1),
							FiscalDeTravessia._travessia(p), (p.get(&"_alvo") as Vector3).snappedf(0.1),
							str(p.get(&"_no")), str(p.get(&"_destino")), _script_ia.call(&"_no_leito", p.global_position)]
				detalhes_parado.append("t=%.1f %s parado %.0f s em %s motivo %s vez %s juiz %s %s%s" % [
					tt, c.name, acc, cp[k].snappedf(0.1), c.call(&"motivo_da_parada"),
					str((ia_p as RefCounted).get(&"pub_vez")) if ia_p != null else "-",
					str((ia_p as RefCounted).get(&"_veredito")) if ia_p != null else "-", mj, sobre])
			if acc > pior_parado:
				pior_parado = acc
				pior_quem = "%s em %s motivo %s" % [c.name, cp[k], c.call(&"motivo_da_parada")]
		# Reciclagem: quem se afasta volta para perto (o Transito faz o mesmo na rua).
		for k in carros.size():
			if cp[k].distance_to(Vector2(centro.x, centro.z)) > 140.0:
				var velho := carros[k]
				var novo := _carro_solto(centro, carros, velho)
				if novo != null:
					nasceu[novo.get_instance_id()] = tt
					carros[k] = novo
					recicla += 1
					parado.erase(velho.get_instance_id())
					velho.queue_free()
		for k in pessoas.size():
			var p := pessoas[k]
			if not is_instance_valid(p) or Vector2(p.global_position.x - centro.x,
					p.global_position.z - centro.z).length() > 90.0:
				if is_instance_valid(p):
					p.queue_free()
				var nova := _pessoa_solta(centro)
				if nova != null:
					pessoas[k] = nova
	for d: String in detalhes:
		print("[bancada_cruzamento] solta contato: %s" % d)
	for d: String in fiscal.detalhes:
		print("[bancada_cruzamento] solta fora do anda: %s" % d)
	for d: String in detalhes_freada:
		print("[bancada_cruzamento] solta freada forte: %s" % d)
	for d: String in detalhes_pessoa:
		print("[bancada_cruzamento] solta pessoa: %s" % d)
	for d: String in detalhes_parado:
		print("[bancada_cruzamento] solta parado: %s" % d)
	for d: String in detalhes_fora:
		print("[bancada_cruzamento] solta fora da faixa: %s" % d)
	_relatar(rot, "andado_km", "%.1f" % (andado / 1000.0))
	_relatar(rot, "reciclados", recicla)
	_relatar(rot, "freadas_acima_de_4_5", freadas_fortes)
	_relatar(rot, "travessias_com_sinal", fiscal.descidas)
	_relatar(rot, "maior_parada_s", "%.1f (%s)" % [pior_parado, pior_quem])
	_conta(rot, "lataria", contatos_cc == 0, "%d contatos entre carros" % contatos_cc)
	_conta(rot, "pessoa", contatos_cp == 0,
		"%d contatos de carro com pessoa (encostou ou empurrou)" % contatos_cp)
	_conta(rot, "anda", fiscal.fora == 0, "%d de %d travessias com sinal comecadas fora do ANDA" % [
		fiscal.fora, fiscal.descidas])
	_conta(rot, "sem_nó", pior_parado <= PARADO_MAX_S,
		"maior parada %.1f s (teto %.0f)" % [pior_parado, PARADO_MAX_S])
	var todos: Array = []
	todos.append_array(carros)
	todos.append_array(pessoas)
	await _limpar(todos)


## Um carro num ponto de faixa a 25-95 m do centro, longe dos outros e fora do
## miolo de qualquer cruzamento.
func _carro_solto(centro: Vector3, outros: Array[Node3D], trocando: Node3D) -> Node3D:
	var pontos := Vias.trechos_perto(centro, 25.0, 95.0)
	for _tentativa in 30:
		if pontos.is_empty():
			return null
		var t: Dictionary = pontos[_rng.randi() % pontos.size()]
		var ponto: Vector3 = t["ponto"]
		var livre := true
		for o: Node3D in outros:
			if o != trocando and is_instance_valid(o) and Vector2(o.global_position.x - ponto.x,
					o.global_position.z - ponto.z).length() < 35.0:
				livre = false
				break
		var perto := Vias.cruzamento_mais_proximo(ponto)
		if Vector2(float(perto.x) * Vias.TAM - ponto.x, float(perto.y) * Vias.TAM - ponto.z).length() < 20.0:
			livre = false
		# Nem perto de gente na rua: carro nascendo a 13 m/s a vinte metros de
		# quem atravessa e nascimento, e nao direcao.
		for pessoa: Node in get_nodes_in_group(&"pessoa_bancada"):
			var p3 := pessoa as Node3D
			if (p3 != null and Vias.no_asfalto(p3.global_position)
					and Vector2(p3.global_position.x - ponto.x, p3.global_position.z - ponto.z).length() < 45.0):
				livre = false
				break
		if not livre:
			continue
		var de: Vector2i = t["de"]
		var tr: Vector4i = t["trecho"]
		_semente += 17
		var ficha: Dictionary = _registro.call(&"identidade",
			_registro.call(&"id_de_transeunte", _semente))
		var c: Node3D = _script_carro.new()
		c.name = "carro_%d" % _semente
		c.call(&"preparar", ficha, de, tr, _semente)
		ponto.y = 0.05
		c.position = ponto
		_mundo.add_child(c)
		c.call(&"plantar", de, tr, ponto)
		return c
	return null


func _pessoa_solta(centro: Vector3) -> Node3D:
	var pontos := Rotas.trechos_perto(centro, 8.0, 60.0)
	if pontos.is_empty():
		return null
	var t: Dictionary = pontos[_rng.randi() % pontos.size()]
	_semente += 17
	var ficha: Dictionary = _registro.call(&"identidade",
		_registro.call(&"id_de_transeunte", _semente))
	var p: Node3D = _script_pessoa.new()
	p.name = "pessoa_%d" % _semente
	p.call(&"preparar", ficha, t["de"], t["para"])
	p.add_to_group(&"pessoa_bancada")
	var onde: Vector3 = t["ponto"]
	onde.y = 0.1
	p.position = onde
	_mundo.add_child(p)
	return p
