## Uma pose de lida escrita por cima da pose do Corpo: agachar, dobrar, torcer e
## levar as duas maos a pontos do mundo.
##
## Quem decide o que o corpo faz e quando e a `LidaDaSacola`, quadro a quadro;
## isto so escreve. Mora fora do Corpo porque o Corpo e a pessoa do jogo inteiro
## e isto e a lida da estufa: o Corpo so conhece o gancho (`Corpo.gesto`).
##
## Duas maneiras de escrever
## -------------------------
##   inteiro   quadril, tronco e pernas saem daqui, com os pes plantados por IK,
##             e a pose de baixo so vale na mistura do `peso`. E o de quem para
##             para colher, pegar o saco do chao ou arremessar
##   aditivo   quadril e tronco giram POR CIMA da pose de baixo, e as pernas sao
##             dela. E o tranco de ajeitar o saco nas costas andando
##
## As maos vao por IK (o mesmo de dois ossos do levantar) ate a PALMA, e nao o
## punho: quem agarra um gargalo fecha a mao em volta dele.
##
## Relogio proprio
## ---------------
## O Corpo so reescreve o esqueleto quando a assinatura da pose muda, e as
## posturas fixas mudam de pose a 2,6 Hz — era por isso que o fazendeiro mexia
## no vaso aos trancos. O gesto entra na assinatura pelo `relogio`: 60 poses por
## segundo no MODERNO, 15 no PS1 STYLE (a grade de sempre).
class_name GestoDeCarga
extends RefCounted

const O := Corpo.Osso
## Da junta do punho ao meio da palma, na altura de referencia.
const PALMA := 0.085

## Quanto o gesto vale sobre a pose de baixo, de 0 a 1.
var peso := 0.0
var aditivo := false
## Quadril: quanto desce e quanto recua (m, na altura de referencia).
var desce := 0.0
var recua := 0.0
## Tronco, em radianos: `dobra` positiva vai para a FRENTE (o Corpo escreve ao
## contrario; a troca e feita aqui, num lugar so), `torcao` positiva vira para a
## esquerda, `tomba` positivo deita para a direita. Quadril leva um terco, o
## tronco o resto: ninguem dobra so na cintura.
var dobra := 0.0
var torcao := 0.0
var tomba := 0.0
## Base: afastamento extra dos pes (m) e quanto o esquerdo vai a frente do
## direito (negativo, o direito a frente).
var abre := 0.0
var avanca := 0.0
## Maos: ponto do MUNDO onde cada palma vai (INF: a pose de baixo) e quanto.
var mao_e := Vector3.INF
var mao_d := Vector3.INF
var peso_e := 0.0
var peso_d := 0.0
## Para onde aponta cada cotovelo, no referencial do tronco.
var cotovelo_e := Vector3(-0.6, -0.8, 0.2)
var cotovelo_d := Vector3(0.6, -0.8, 0.2)
## O tempo do gesto, que quem o conduz avanca.
var relogio := 0.0


func chave() -> int:
	var passos := 60.0 if Corpo._luz_por_pixel() else 15.0
	return int(relogio * passos) * 2 + (1 if aditivo else 0)


func aplicar(c: Corpo) -> void:
	var k := clampf(peso, 0.0, 1.0)
	var sk := c.esqueleto()
	if k <= 0.0 or sk == null:
		return
	var s := c.altura() / Corpo.ALTURA_REF
	var q0 := sk.get_bone_pose_rotation(O.QUADRIL)
	var p0 := sk.get_bone_pose_position(O.QUADRIL)
	var t0 := sk.get_bone_pose_rotation(O.TORSO)
	var giro_q := Basis.from_euler(Vector3(-dobra * 0.3, torcao * 0.3, -tomba * 0.4))
	var giro_t := Basis.from_euler(Vector3(-dobra * 0.7, torcao * 0.7, -tomba * 0.6))
	var desloca := Vector3(0.0, -desce * s, recua * s)
	var q1: Quaternion
	var p1: Vector3
	var t1: Quaternion
	if aditivo:
		q1 = (giro_q * Basis(q0)).get_rotation_quaternion()
		p1 = p0 + desloca
		t1 = (giro_t * Basis(t0)).get_rotation_quaternion()
	else:
		q1 = giro_q.get_rotation_quaternion()
		p1 = sk.get_bone_rest(O.QUADRIL).origin + desloca
		t1 = giro_t.get_rotation_quaternion()
	var q := q0.slerp(q1, k)
	var p := p0.lerp(p1, k)
	sk.set_bone_pose_rotation(O.QUADRIL, q)
	sk.set_bone_pose_position(O.QUADRIL, p)
	sk.set_bone_pose_rotation(O.TORSO, t0.slerp(t1, k))
	var quadril := Transform3D(Basis(q), p)

	if not aditivo:
		# Pes plantados: o quadril desce e gira, e o IK dobra o joelho para o pe
		# ficar onde estava (o de chao, que poe a pessoa na ponta do pe em vez de
		# enterrar o bico do sapato).
		for lado: float in [-1.0, 1.0]:
			var coxa := O.COXA_E if lado < 0.0 else O.COXA_D
			var x := sk.get_bone_global_rest(coxa).origin.x + lado * abre * s
			var z := avanca * s * 0.5 * (-1.0 if lado < 0.0 else 1.0)
			var alvo := Vector3(x, Corpo.Y_TORNOZELO * s, z)
			var r := LevantarDoChao._ik_no_chao(c, quadril, coxa, alvo,
				Vector3(lado * 0.3, 0.0, -1.0), -1.0)
			sk.set_bone_pose_rotation(coxa, sk.get_bone_pose_rotation(coxa).slerp(r[0], k))
			sk.set_bone_pose_rotation(coxa + 1, sk.get_bone_pose_rotation(coxa + 1).slerp(r[1], k))

	var tronco := quadril * Transform3D(Basis(sk.get_bone_pose_rotation(O.TORSO)),
		sk.get_bone_rest(O.TORSO).origin)
	var inv := sk.global_transform.affine_inverse()
	for lado: float in [-1.0, 1.0]:
		var alvo_m := mao_e if lado < 0.0 else mao_d
		var pm := (peso_e if lado < 0.0 else peso_d) * k
		if pm <= 0.0 or not alvo_m.is_finite():
			continue
		var braco := O.BRACO_E if lado < 0.0 else O.BRACO_D
		var polo := tronco.basis * (cotovelo_e if lado < 0.0 else cotovelo_d)
		var r := LevantarDoChao._ik(c, tronco, braco, inv * alvo_m, polo, 1.0, PALMA * s)
		sk.set_bone_pose_rotation(braco, sk.get_bone_pose_rotation(braco).slerp(r[0], pm))
		sk.set_bone_pose_rotation(braco + 1, sk.get_bone_pose_rotation(braco + 1).slerp(r[1], pm))
