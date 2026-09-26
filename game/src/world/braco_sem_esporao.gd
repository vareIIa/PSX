## O `BracoVivo` do motorista da estrada, sem o esporao do cotovelo.
##
## Por que existe
## --------------
## O tubo do antebraco da `MaoModelada` continua 22 cm alem do cotovelo
## (`ALEM_DO_COTOVELO`): foi feito para as maos do aro, que nao tem braco de cima, e
## o `BracoVivo` herdou. Com o braco reto ele some dentro do braco de cima; com o
## cotovelo dobrado (apoio, erguer, leitura) sai do cotovelo como um espeto — medido
## na Fase 1: 13 cm dentro da porta do motorista, 5 cm dentro do tunel.
##
## Como
## ----
## O mesmo `refazer` do `BracoVivo`, com uma diferenca: depois de montar a mao e o
## antebraco, os vertices que passam do cotovelo ao longo do eixo do antebraco sao
## achatados no plano do cotovelo (o tubo acaba ali, e o braco de cima cobre a
## boca). O braco de cima continua indo ate o ombro, esticando quando o celular
## esta longe (`esticou_m` diz quanto, para quem mede).
##
## Espelho do `BracoVivo.refazer`: se ele mudar, mudar aqui junto. Carregado pelo
## caminho, sem `class_name`.
extends BracoVivo

## Quantos quadros o braco de cima esticou alem de `BRACO_DE_CIMA`, e quanto na
## ultima vez (m): so para quem mede.
var esticou: int = 0
var esticou_m: float = 0.0
## O quanto o cotovelo dobra, no minimo, quando o braco nao alcanca (graus). O
## `cotovelo_entre` estica o braco reto quando o ombro fica longe do punho — e no
## chao do carona ele fica a 98 cm —, e o braco inteiro virava uma vara de 175
## graus presa num ponto: o cotovelo de gente esticado ao maximo ainda dobra uns
## graus, para o lado do `polo`. Zero e o de antes (a leitura e a esquerda).
var dobra_minima: float = 0.0


## O cotovelo para o punho `punho`, com a `dobra_minima` quando o braco estica.
func cotovelo_para(punho: Vector3) -> Vector3:
	var cot := cotovelo_entre(punho, ombro, polo)
	if dobra_minima <= 0.0:
		return cot
	var para := ombro - punho
	var dist := para.length()
	if dist < 0.01:
		return cot
	var eixo := para / dist
	var ate := cot - punho
	var agora := eixo.angle_to(ate) if ate.length_squared() > 1e-8 else 0.0
	var quer := deg_to_rad(dobra_minima)
	if agora >= quer:
		return cot
	var lado := polo - eixo * polo.dot(eixo)
	if lado.length_squared() < 1e-8:
		lado = Vector3.DOWN - eixo * Vector3.DOWN.dot(eixo)
	lado = lado.normalized()
	return punho + (eixo * cos(quer) + lado * sin(quer)) * MaoModelada.ANTEBRACO


## Os mesmos campos do `BracoVivo.criar`, num braco desta classe.
static func preparar(b: BracoVivo, nome: String, e_direita: bool, pele: Color, manga: Color,
		longa: bool) -> BracoVivo:
	b.name = nome
	b.direita = e_direita
	b._pele = pele
	b._manga = manga
	b._longa = longa
	b._semente = 3.7 if e_direita else 0.0
	b.material_override = BracoVivo.material()
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	b.layers = BracoVivo.CAMADA
	b.visible = false
	return b


func refazer() -> void:
	if pegada.is_empty():
		return
	var d: Vector3 = pegada["d"]
	var dorso: Vector3 = pegada["dorso"]
	var treme := Vector3(sin(_t * 83.0) + 0.5 * sin(_t * 37.0),
		sin(_t * 71.0 + 1.3) + 0.5 * sin(_t * 29.0),
		sin(_t * 97.0 + 2.1)) * TREMOR * tremor
	var o: Vector3 = (pegada["o"] as Vector3) + treme
	var p := MaoPosada.viva(pegada["pose"], _t,
		(DEDOS_VIVOS + DEDOS_COM_MEDO * clampf(tremor, 0.0, 1.5)) * dedos_vivos, _semente)
	var punho := MaoPosada.punho_de(o, d, dorso)
	var cotovelo := cotovelo_para(punho)
	var dados := PSXMesh.dados_vazios()
	MaoModelada.forma = forma
	var b := MaoPosada.montar(dados, o, d, dorso, p, direita, cotovelo, _pele, _manga,
		_longa)
	var pu: Vector3 = b["punho"]
	var eixo: Vector3 = b["eixo"]
	var fim := pu + eixo * clampf(cotovelo.distance_to(pu), 0.10, MaoModelada.ANTEBRACO)
	_cortar_esporao(dados, fim, eixo)
	# O braco de cima vai ate o ombro, esticando se for preciso: e o braco que o
	# jogador ve se esticar atras do celular caido longe (e fica, por escolha dele).
	var para := ombro - fim
	esticou_m = maxf(0.0, para.length() - BRACO_DE_CIMA)
	if esticou_m > 0.005:
		esticou += 1
	MaoModelada.braco_de_cima(dados, fim, ombro, _pele, _manga, _longa)
	MaoModelada.forma = {}
	mesh = PSXMesh.dados_para_mesh(dados)
	punho_montado = pu
	cotovelo_montado = fim


## Achata no plano do cotovelo o que o tubo do antebraco tem alem dele. So perto do
## eixo (o tubo tem uns 5 cm de raio): um dedo que passe atras do cotovelo nao e
## tocado.
static func _cortar_esporao(dados: Dictionary, fim: Vector3, eixo: Vector3) -> void:
	var vs: PackedVector3Array = dados["v"]
	for i in vs.size():
		var v := vs[i]
		var s := (v - fim).dot(eixo)
		if s <= 0.0:
			continue
		var radial := (v - fim) - eixo * s
		if radial.length() > 0.075:
			continue
		vs[i] = v - eixo * s
	dados["v"] = vs
