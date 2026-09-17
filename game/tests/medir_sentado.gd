## Onde cada osso para nas posturas de quem esta jogando. Criterio de aceite.
##
##   godot --headless --path game --script res://tests/medir_sentado.gd
##
## Existe porque "o sentado esta quebrado" e uma frase, e o que conserta e um
## numero: a que altura o quadril para, para que lado a coxa aponta, onde o pe
## termina em relacao ao piso (y=0) e onde as duas maos param em relacao a
## frente do corpo (-Z).
##
## Foi esta medida que achou o defeito. O comentario de `_pose_sentado` dizia
## "girar as coxas para a FRENTE" e o codigo girava -1,42 rad, que na convencao
## do proprio arquivo (`_pose_andando`: coxa positiva = perna a frente) joga a
## coxa para TRAS. Lendo o codigo as duas linhas pareciam concordar.
extends SceneTree

const OSSOS := {
	"quadril": Corpo.Osso.QUADRIL,
	"torso": Corpo.Osso.TORSO,
	"cabeca": Corpo.Osso.CABECA,
	"coxa_d": Corpo.Osso.COXA_D,
	"canela_d": Corpo.Osso.CANELA_D,
	"canela_e": Corpo.Osso.CANELA_E,
	"antebraco_d": Corpo.Osso.ANTEBRACO_D,
	"antebraco_e": Corpo.Osso.ANTEBRACO_E,
}

## O mesmo deslocamento que Convidado._montar_mao poe no Punho.
const PUNHO := Vector3(0.0, -0.24, 0.07)

## Quanto o quadril de quem esta sentado de pernas cruzadas fica do chao.
const SENTADO_QUADRIL := Vector2(0.16, 0.30)
## Onde as duas maos de quem segura um controle tem de estar, contado do tronco.
## Negativo e a FRENTE do corpo.
const MAOS_Z := Vector2(-0.34, -0.12)
## Separacao entre os punhos de quem segura UM controle com as duas maos.
const MAOS_SEPARACAO := Vector2(0.16, 0.34)

var _falhas: int = 0


func _init() -> void:
	for nome: String in ["SENTADO", "CONTROLE", "LIVRE"]:
		var corpo := Corpo.new()
		root.add_child(corpo)
		corpo.montar(Aparencia.de_ficha({"id": 4242, "sexo": &"M", "idade": 23}))
		match nome:
			"SENTADO":
				corpo.postura(Corpo.Postura.SENTADO)
			"CONTROLE":
				corpo.postura(Corpo.Postura.CONTROLE)
			_:
				corpo.postura(Corpo.Postura.LIVRE)
		# Alguns quadros para o relogio da postura sair de zero.
		for _k in 20:
			corpo.animar(0.0, 1.0 / 60.0)
		var esq := corpo.esqueleto()
		esq.force_update_all_bone_transforms()

		print("--- %s ---  altura %.2f  %d triangulos  %d ossos"
			% [nome, corpo.altura(), corpo.triangulos(), corpo.ossos()])
		for chave: String in OSSOS:
			var g: Vector3 = esq.get_bone_global_pose(int(OSSOS[chave])).origin
			print("  %-12s  x %6.3f   y %6.3f   z %6.3f" % [chave, g.x, g.y, g.z])

		var quadril: Vector3 = esq.get_bone_global_pose(Corpo.Osso.QUADRIL).origin
		var joelho: Vector3 = esq.get_bone_global_pose(Corpo.Osso.CANELA_D).origin
		var pe_d := _ponta_do_pe(esq, Corpo.Osso.CANELA_D)
		var pe_e := _ponta_do_pe(esq, Corpo.Osso.CANELA_E)
		var punho_d: Vector3 = esq.get_bone_global_pose(Corpo.Osso.ANTEBRACO_D) * PUNHO
		var punho_e: Vector3 = esq.get_bone_global_pose(Corpo.Osso.ANTEBRACO_E) * PUNHO
		print("  %-12s  x %6.3f   y %6.3f   z %6.3f" % ["ponta pe D", pe_d.x, pe_d.y, pe_d.z])
		print("  %-12s  x %6.3f   y %6.3f   z %6.3f" % ["ponta pe E", pe_e.x, pe_e.y, pe_e.z])
		print("  %-12s  x %6.3f   y %6.3f   z %6.3f" % ["punho D", punho_d.x, punho_d.y, punho_d.z])
		print("  %-12s  x %6.3f   y %6.3f   z %6.3f" % ["punho E", punho_e.x, punho_e.y, punho_e.z])

		# --- criterios ---
		#
		# Valem para as duas posturas de quem joga. Nenhum deles e sobre estilo:
		# pe abaixo do piso, joelho apontando para tras e mao atras do tronco
		# sao defeitos que a captura mostra e a leitura do codigo nao.
		_checar("pe D no piso ou acima", pe_d.y >= -0.005, "y=%.3f" % pe_d.y)
		_checar("pe E no piso ou acima", pe_e.y >= -0.005, "y=%.3f" % pe_e.y)
		_checar("perna D nao cruza a linha de centro", pe_d.x > -0.02,
			"x=%.3f" % pe_d.x)
		_checar("perna E nao cruza a linha de centro", pe_e.x < 0.02,
			"x=%.3f" % pe_e.x)
		if nome == "SENTADO":
			_checar("quadril na altura de quem senta no chao",
				quadril.y >= SENTADO_QUADRIL.x and quadril.y <= SENTADO_QUADRIL.y,
				"y=%.3f fora de %.2f..%.2f" % [quadril.y, SENTADO_QUADRIL.x,
					SENTADO_QUADRIL.y])
			_checar("joelho a FRENTE do corpo", joelho.z < -0.10,
				"z=%.3f" % joelho.z)
		if nome != "LIVRE":
			_checar("mao D a frente do tronco",
				punho_d.z >= MAOS_Z.x and punho_d.z <= MAOS_Z.y,
				"z=%.3f fora de %.2f..%.2f" % [punho_d.z, MAOS_Z.x, MAOS_Z.y])
			_checar("mao E a frente do tronco",
				punho_e.z >= MAOS_Z.x and punho_e.z <= MAOS_Z.y,
				"z=%.3f fora de %.2f..%.2f" % [punho_e.z, MAOS_Z.x, MAOS_Z.y])
			var sep := punho_d.distance_to(punho_e)
			_checar("as duas maos cabem no mesmo controle",
				sep >= MAOS_SEPARACAO.x and sep <= MAOS_SEPARACAO.y,
				"%.3f m fora de %.2f..%.2f" % [sep, MAOS_SEPARACAO.x,
					MAOS_SEPARACAO.y])
		corpo.queue_free()

	print("")
	if _falhas == 0:
		print("[medir_sentado] todos os criterios passaram")
	else:
		print("[medir_sentado] %d criterio(s) falharam" % _falhas)
	quit(0 if _falhas == 0 else 1)


func _checar(o_que: String, passou: bool, detalhe: String) -> void:
	if passou:
		print("    ok    %s" % o_que)
		return
	_falhas += 1
	print("    FALHA %s  (%s)" % [o_que, detalhe])


## A ponta do pe em espaco do modelo. A caixa do sapato mora no osso da canela,
## centro em (x, 0.037, -0.045) no repouso, e mede 0.25 de profundidade.
func _ponta_do_pe(esq: Skeleton3D, osso: int) -> Vector3:
	var rest := _global_rest(esq, osso)
	var local := rest.affine_inverse() * Vector3(rest.origin.x, 0.037,
		-0.045 - 0.125)
	return esq.get_bone_global_pose(osso) * local


static func _global_rest(esq: Skeleton3D, idx: int) -> Transform3D:
	var t := Transform3D()
	var pilha: Array[int] = []
	var atual := idx
	while atual >= 0:
		pilha.append(atual)
		atual = esq.get_bone_parent(atual)
	pilha.reverse()
	for k: int in pilha:
		t = t * esq.get_bone_rest(k)
	return t
