## Reacoes da criacao, medidas pela ponta: onde a mao chega no pico.
##
##     godot --headless --path game --script res://tests/medir_reacao.gd
##     ... -- --resolver    imprime a tabela de angulos que leva cada mao ao alvo
##
## A reacao "mao no rosto" que nao chega no rosto e o defeito classico de pose
## tateada: o braco sobe, o antebraco dobra, e a mao para a doze centimetros da
## bochecha, abanando o ar. Na tela de 104 px isso le como gesto qualquer. Entao
## os alvos sao PONTOS no corpo de referencia, e o criterio e distancia.
## (Memoria: "animacao se mede pela ponta".)
##
## `--resolver` e a origem dos numeros de `ReacaoCorpo.POSES`: busca em grade,
## grossa e depois fina, os quatro angulos (ombro em tres eixos, cotovelo em um)
## que levam o centro da mao ao alvo. A conta de cinematica e a do esqueleto —
## a pose do tronco vem do proprio Skeleton3D, o resto e o mesmo produto de
## transformadas que ele faz.
extends SceneTree

## Tolerancia da ponta: meia mao. A caixa da mao tem 9 cm.
const TOLERANCIA := 0.045

var _passou := 0
var _total := 0


func _init() -> void:
	_rodar()


func _rodar() -> void:
	await process_frame
	var corpo := Corpo.new()
	root.add_child(corpo)
	corpo.montar(Aparencia.de_ficha({"id": 7, "sexo": &"M", "idade": 31}))
	var aparencia := Aparencia.de_ficha({"id": 7, "sexo": &"M", "idade": 31})
	aparencia["altura"] = Corpo.ALTURA_REF
	aparencia["ombro"] = 0.42
	aparencia["gordura"] = 0.5
	corpo.montar(aparencia)
	if OS.get_cmdline_user_args().has("--resolver"):
		_resolver(corpo)
	else:
		await _medir(corpo)
		print("\n%d de %d criterios" % [_passou, _total])
	quit(0 if _passou == _total else 1)


# --- medida -------------------------------------------------------------------

func _medir(corpo: Corpo) -> void:
	print("\n=== reacoes: mao no alvo, no pico ===\n")
	for tipo: int in ReacaoCorpo.POSES:
		var pose: Dictionary = ReacaoCorpo.POSES[tipo]
		if not pose.has("alvos"):
			continue
		corpo.reagir(tipo)
		# Meio da reacao: dentro da janela em que o envelope esta cheio.
		var pico := ReacaoCorpo.duracao(tipo) * 0.5
		corpo.animar(0.0, pico)
		# A pose-base, sem o gesto secundario: com o envelope cheio, `aplicar`
		# leva cada osso exatamente ao angulo da tabela.
		ReacaoCorpo.aplicar(corpo, tipo, pico, false)
		var alvos: Dictionary = pose["alvos"]
		for lado: int in alvos:
			var alvo: Vector3 = alvos[lado]
			var mao := _mao(corpo, lado)
			var dist := mao.distance_to(alvo)
			_total += 1
			var ok := dist <= TOLERANCIA
			if ok:
				_passou += 1
			print("[%s] %-9s mao %s  alvo %s  %.1f cm" % ["OK" if ok else "XX",
				ReacaoCorpo.nome(tipo) + ("_E" if lado < 0 else "_D"),
				_v(mao), _v(alvo), dist * 100.0])
		corpo.reagir(0)
		corpo.animar(0.0, 0.016)


func _mao(corpo: Corpo, lado: int) -> Vector3:
	var sk := corpo.esqueleto()
	var osso := Corpo.Osso.ANTEBRACO_E if lado < 0 else Corpo.Osso.ANTEBRACO_D
	var g := sk.get_bone_global_pose(osso)
	return g * Vector3(0.0, corpo._y(0.80 - Corpo.Y_COTOVELO), 0.0)


static func _v(p: Vector3) -> String:
	return "(%+.2f %+.2f %+.2f)" % [p.x, p.y, p.z]


# --- resolvedor ---------------------------------------------------------------

func _resolver(corpo: Corpo) -> void:
	var sk := corpo.esqueleto()
	for tipo: int in ReacaoCorpo.POSES:
		var pose: Dictionary = ReacaoCorpo.POSES[tipo]
		if not pose.has("alvos"):
			continue
		# O tronco (e o quadril) da pose ja aplicados: o ombro pendura dele.
		sk.reset_bone_poses()
		var ossos: Dictionary = pose.get("ossos", {})
		for osso: int in [Corpo.Osso.QUADRIL, Corpo.Osso.TORSO]:
			if ossos.has(osso):
				var e: Vector3 = ossos[osso]
				sk.set_bone_pose_rotation(osso,
					Basis.from_euler(e).get_rotation_quaternion())
		if pose.has("quadril"):
			var desvio: Vector3 = pose["quadril"]
			sk.set_bone_pose_position(Corpo.Osso.QUADRIL,
				sk.get_bone_rest(Corpo.Osso.QUADRIL).origin
				+ Vector3(desvio.x, corpo._y(desvio.y), desvio.z))
		var torso := sk.get_bone_global_pose(Corpo.Osso.TORSO)
		var alvos: Dictionary = pose["alvos"]
		for lado: int in alvos:
			var braco := Corpo.Osso.BRACO_E if lado < 0 else Corpo.Osso.BRACO_D
			var ombro_local := sk.get_bone_rest(braco).origin
			var cotovelo_local := sk.get_bone_rest(braco + 1).origin
			var mao_local := Vector3(0.0, corpo._y(0.80 - Corpo.Y_COTOVELO), 0.0)
			var alvo: Vector3 = alvos[lado]
			var dica: Vector3 = pose.get("cotovelos", {}).get(lado, Vector3.INF)
			var melhor := _buscar(torso, ombro_local, cotovelo_local, mao_local, alvo,
				dica, Vector4(0.0, 0.0, 0.0, 1.2), 2.6, 0.26, lado)
			melhor = _buscar(torso, ombro_local, cotovelo_local, mao_local, alvo,
				dica, melhor, 0.18, 0.03, lado)
			melhor = _buscar(torso, ombro_local, cotovelo_local, mao_local, alvo,
				dica, melhor, 0.04, 0.01, lado)
			var mao := _fk(torso, ombro_local, cotovelo_local, mao_local, melhor)
			print("%-9s %s  braco Vector3(%.2f, %.2f, %.2f)  antebraco Vector3(%.2f, 0, 0)  erro %.1f cm" % [
				ReacaoCorpo.nome(tipo), "E" if lado < 0 else "D",
				melhor.x, melhor.y, melhor.z, melhor.w,
				mao.distance_to(alvo) * 100.0])


static func _fk(torso: Transform3D, ombro: Vector3, cotovelo: Vector3,
		mao: Vector3, q: Vector4) -> Vector3:
	var braco := torso * Transform3D(Basis.from_euler(Vector3(q.x, q.y, q.z)), ombro)
	var ante := braco * Transform3D(Basis.from_euler(Vector3(q.w, 0.0, 0.0)), cotovelo)
	return ante * mao


## Grade em volta de `centro`.
##
## Quatro angulos para tres coordenadas de mao: sobra um grau de liberdade, que
## e o cotovelo girando em volta da linha ombro-mao. A primeira rodada deixou
## isso solto e a mao chegava ao queixo com o braco aberto para o alto, como
## quem acena. O custo agora leva a DICA de cotovelo de cada reacao, com peso
## pequeno: a mao continua mandando, e entre as poses que chegam a ela ganha a
## que poe o cotovelo onde uma pessoa poria.
const PESO_COTOVELO := 0.006

static func _buscar(torso: Transform3D, ombro: Vector3, cotovelo: Vector3,
		mao: Vector3, alvo: Vector3, dica: Vector3, centro: Vector4, raio: float,
		passo: float, lado: int) -> Vector4:
	var melhor := centro
	var custo_min := INF
	var n := int(round(raio / passo))
	for i in range(-n, n + 1):
		var bx := centro.x + float(i) * passo
		for j in range(-n, n + 1):
			var by := centro.y + float(j) * passo
			for k in range(-n, n + 1):
				var bz := centro.z + float(k) * passo
				# O braco nao entra no tronco. Fechar para dentro e z com o
				# sinal CONTRARIO ao lado: na pose parada o direito leva -0,07 e
				# o esquerdo +0,07, e os dois ficam encostados no corpo.
				if bz * float(lado) < -0.45:
					continue
				for m in range(-n, n + 1):
					var fx := clampf(centro.w + float(m) * passo, 0.0, 2.45)
					var q := Vector4(bx, by, bz, fx)
					var p := _fk(torso, ombro, cotovelo, mao, q)
					var custo := p.distance_squared_to(alvo) \
						+ 0.00002 * (by * by + bz * bz)
					if dica != Vector3.INF:
						var braco := torso * Transform3D(
							Basis.from_euler(Vector3(bx, by, bz)), ombro)
						custo += PESO_COTOVELO * (braco * cotovelo).distance_squared_to(dica)
					if custo < custo_min:
						custo_min = custo
						melhor = q
	return melhor
