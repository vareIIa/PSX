## As chaves do acordar e do levantar na praca, no formato do `LevantarDoChao`.
##
## Classe pura (sem autoload), para a regua `tests/medir_acordar.gd` medir a
## pele contra o chao fora do jogo, como `tests/medir_levantar.gd` mede as do
## `LevantarDoChao`. Quem toca as chaves no jogo e o `AcordarNaPraca`.
##
## Referencial: o do Corpo de pe no fim, frente em -Z. Ele esta caido DE COSTAS
## com a cabeca para a frente (-Z) e os pes para tras (+Z): de pe, no fim, olha
## para onde a cabeca estava.
class_name ChavesDoAcordar
extends RefCounted

const O := Corpo.Osso
const MEIO_PI := PI * 0.5
const FRENTE := Vector3(0.0, 0.0, -1.0)
const TRAS := Vector3(0.0, 0.0, 1.0)
const CIMA := Vector3(0.0, 1.0, 0.0)
const BAIXO := Vector3(0.0, -1.0, 0.0)

## Como cada trecho chega na chave dele.
enum Curva { SUAVE, ENTRA, SAI, RETA }


static func _s(corpo: Corpo) -> float:
	return corpo.altura() / Corpo.ALTURA_REF


## De costas com a cabeca para -Z: `x` e o quanto o tronco esta deitado
## (MEIO_PI no chao, menos que isso erguido nos cotovelos).
static func _de_costas(x: float) -> Basis:
	return Basis.from_euler(Vector3(x, PI, 0.0))


## De bruços com a cabeca para -Z: `x` e o quanto o tronco esta deitado.
static func _de_brucos(x: float) -> Basis:
	return Basis.from_euler(Vector3(-x, 0.0, 0.0))


## Deitado sobre o lado direito, virado para -X: o meio do caminho entre as
## duas de cima, girando em volta do comprimento do corpo.
static func _de_lado() -> Basis:
	return Basis(Vector3(0.0, 0.0, 1.0), MEIO_PI) * _de_costas(MEIO_PI)


## Alvo de mao ou pe com o lado de pe (como o `LevantarDoChao`): `dx` soma ao x
## de repouso do membro, para fora.
static func _lado(corpo: Corpo, membro: StringName, dx: float, y: float, z: float) -> Vector3:
	var dados: Array = LevantarDoChao.MEMBROS[membro]
	var rest_x := absf(corpo.esqueleto().get_bone_global_rest(int(dados[0])).origin.x)
	var s := _s(corpo)
	return Vector3(float(dados[2]) * (rest_x + dx), y * s, z * s)


## O mesmo, de costas: deitado de barriga para cima com a cabeca para -Z, o lado
## direito do corpo fica em -X.
static func _esp(corpo: Corpo, membro: StringName, dx: float, y: float, z: float) -> Vector3:
	var v := _lado(corpo, membro, dx, y, z)
	v.x = -v.x
	return v


static func _abs(corpo: Corpo, v: Vector3) -> Vector3:
	return v * _s(corpo)


## Uma chave no formato do `LevantarDoChao` (`_entre`), com os alvos ja no
## referencial do corpo.
static func _chave(corpo: Corpo, dur: float, quadril: Vector3, giro: Basis,
		ossos: Dictionary, membros: Dictionary, assenta: bool = false,
		curva: int = Curva.SUAVE) -> Dictionary:
	var k := {
		"dur": dur,
		"pos": quadril * _s(corpo),
		"rot": giro.orthonormalized().get_rotation_quaternion(),
		"ossos": {},
		"membros": {},
		"assenta": assenta,
		"curva": curva,
	}
	for osso: int in ossos:
		(k["ossos"] as Dictionary)[osso] = Basis.from_euler(ossos[osso]).get_rotation_quaternion()
	for m: StringName in membros:
		var par: Array = membros[m]
		(k["membros"] as Dictionary)[m] = [par[0] as Vector3, (par[1] as Vector3).normalized()]
	return k


static func _bracos_no_chao(abre: float = 0.22) -> Dictionary:
	return {
		O.BRACO_E: Vector3(0.05, 0.0, -abre), O.BRACO_D: Vector3(0.05, 0.0, abre),
		O.ANTEBRACO_E: Vector3(0.28, 0.0, 0.0), O.ANTEBRACO_D: Vector3(0.22, 0.0, 0.0),
	}


static func _com(a: Dictionary, b: Dictionary) -> Dictionary:
	var c := a.duplicate()
	c.merge(b, true)
	return c


static func _pernas_deitado(corpo: Corpo) -> Dictionary:
	return {
		&"pe_e": [_esp(corpo, &"pe_e", -0.02, 0.08, 1.16), CIMA],
		&"pe_d": [_esp(corpo, &"pe_d", 0.03, 0.08, 1.14), CIMA],
	}


## Onde o quadril fica deitado. E o mesmo das chaves de bruços do
## `LevantarDoChao` (0,32 atras do lugar em que ele fica de pe), para o rolar
## nao arrastar o corpo pelo chao.
const QUADRIL_DEITADO := Vector3(0.0, 0.115, 0.32)


## Caido depois do tombo: a cabeca pendendo para o lado, um joelho dobrado e o
## outro esticado. E a pose dos planos de fora antes de ele se mexer.
static func chave_caido(corpo: Corpo, dur: float = 0.0, curva: int = Curva.SUAVE) -> Dictionary:
	return _chave(corpo, dur, QUADRIL_DEITADO, _de_costas(MEIO_PI),
		_com(_bracos_no_chao(0.34), {O.TORSO: Vector3.ZERO, O.CABECA: Vector3(0.12, 0.42, 0.0)}),
		{
			&"pe_e": [_esp(corpo, &"pe_e", -0.04, 0.08, 1.16), CIMA],
			&"pe_d": [_esp(corpo, &"pe_d", 0.08, 0.08, 0.9), Vector3(-0.25, 1.0, 0.0)],
		}, true, curva)


## A pose parada de antes de acordar (uma chave so).
static func chaves_deitado(corpo: Corpo) -> Array:
	return [chave_caido(corpo)]


## O acordar em primeira pessoa. Tempos em segundos desde o branco comecar a
## dissolver; as marcas que o roteiro espera estao em `ACORDAR_*`.
##
##   0,0   olho meio aberto, borrado, no ceu            (o branco dissolvendo)
##   2,2   a cabeca vira para um lado, depois para o outro
##   4,4   a mao direita sobe do chao
##   6,4   para na frente do rosto; os dedos abrem, fecham, a mao vira
##   8,6   a mao cai
##   9,15  apoia nos cotovelos: as pernas entram no quadro
##  10,45  puxa um joelho
##  11,45  olha a praca adiante
##  12,55  os bracos cedem e ele cai de volta (chega ao chao em 12,95)
const ACORDAR_MAO_SOBE := 4.4
const ACORDAR_MAO_NO_ROSTO := 6.4
const ACORDAR_MAO_CAI := 8.6
const ACORDAR_COTOVELOS := 9.15
const ACORDAR_JOELHO := 10.45
const ACORDAR_OLHA := 11.45
const ACORDAR_CAI := 12.55
const ACORDAR_FIM := 12.95


static func chaves_acordar(corpo: Corpo) -> Array:
	var chao := _bracos_no_chao()
	var pernas := _pernas_deitado(corpo)
	var costas := _de_costas(MEIO_PI)
	# A mao direita na frente do rosto, a um palmo e meio do olho, com o
	# cotovelo para fora e para os pes.
	var polo_mao := Vector3(-1.0, -0.3, 0.5)
	var mao_sobe := [_esp(corpo, &"mao_d", -0.10, 0.30, 0.02), polo_mao]
	var mao_rosto := [_esp(corpo, &"mao_d", -0.17, 0.50, -0.17), polo_mao]
	var mao_perto := [_esp(corpo, &"mao_d", -0.16, 0.46, -0.14), polo_mao]
	var ossos_d := {O.BRACO_E: chao[O.BRACO_E], O.ANTEBRACO_E: chao[O.ANTEBRACO_E]}
	var cotovelos := {
		&"mao_e": [_esp(corpo, &"mao_e", 0.02, 0.08, 0.10), FRENTE],
		&"mao_d": [_esp(corpo, &"mao_d", 0.02, 0.08, 0.10), FRENTE],
	}
	var q := QUADRIL_DEITADO
	return [
		_chave(corpo, 0.0, q, costas, _com(chao, {O.CABECA: Vector3(-0.1, 0.0, 0.0)}),
			pernas, true),
		_chave(corpo, 2.2, q, costas, _com(chao, {O.CABECA: Vector3(-0.1, 0.05, 0.0)}),
			pernas, true),
		_chave(corpo, 1.1, q, costas, _com(chao, {O.CABECA: Vector3(-0.08, 0.55, 0.06)}),
			pernas, true),
		_chave(corpo, 1.1, q, costas, _com(chao, {O.CABECA: Vector3(-0.1, -0.5, -0.05)}),
			pernas, true),
		_chave(corpo, 1.0, q, costas, _com(ossos_d, {O.CABECA: Vector3(-0.28, 0.08, 0.0)}),
			_com(pernas, {&"mao_d": mao_sobe}), true),
		_chave(corpo, 1.0, q, costas, _com(ossos_d, {O.CABECA: Vector3(-0.36, 0.1, 0.0)}),
			_com(pernas, {&"mao_d": mao_rosto}), true, Curva.SAI),
		_chave(corpo, 2.2, q, costas, _com(ossos_d, {O.CABECA: Vector3(-0.4, 0.06, 0.0)}),
			_com(pernas, {&"mao_d": mao_perto}), true),
		# A mao cai: acelera, como peso.
		_chave(corpo, 0.55, q, costas, _com(chao, {O.CABECA: Vector3(-0.22, 0.04, 0.0)}),
			pernas, true, Curva.ENTRA),
		# Nos cotovelos: o tronco sobe e o queixo vai ao peito — e o olhar desce
		# pelo proprio corpo ate os pes (o resto da descida e dos olhos, ver
		# `AcordarNaPraca.olho_giro`).
		_chave(corpo, 1.3, q, _de_costas(0.98), {O.TORSO: Vector3.ZERO,
			O.CABECA: Vector3(-0.88, 0.0, 0.0)}, _com(pernas, cotovelos), true),
		_chave(corpo, 1.0, q, _de_costas(1.0), {O.TORSO: Vector3(-0.04, 0.0, 0.0),
			O.CABECA: Vector3(-0.92, -0.08, 0.0)}, _com(cotovelos, {
				&"pe_e": pernas[&"pe_e"],
				&"pe_d": [_esp(corpo, &"pe_d", 0.04, 0.08, 0.80), CIMA],
			}), true),
		_chave(corpo, 1.1, q, _de_costas(0.98), {O.TORSO: Vector3.ZERO,
			O.CABECA: Vector3(-0.8, 0.18, 0.0)}, _com(cotovelos, {
				&"pe_e": pernas[&"pe_e"],
				&"pe_d": [_esp(corpo, &"pe_d", 0.05, 0.08, 0.82), CIMA],
			}), true),
		# Os bracos cedem: cai de costas, de uma vez.
		chave_caido(corpo, 0.4, Curva.ENTRA),
	]


## O levantar, de onde `chave_caido` deixou. A primeira metade (rolar, maos no
## chao, empurrar, escorregar) vai ate `LEVANTAR_CORTE`; a segunda e de quatro,
## um joelho, a mao no joelho, de pe. O plano e um so (o helicoptero da
## `Abertura`); a marca serve para cronometrar som e foto na metade.
const LEVANTAR_CORTE := 4.95


static func chaves_levantar(corpo: Corpo) -> Array:
	var q := QUADRIL_DEITADO
	var maos_brucos := {
		&"mao_e": [_lado(corpo, &"mao_e", -0.06, 0.09, -0.12), TRAS + CIMA * 0.5],
		&"mao_d": [_lado(corpo, &"mao_d", -0.06, 0.09, -0.12), TRAS + CIMA * 0.5],
	}
	var pes_brucos := {
		&"pe_e": [_lado(corpo, &"pe_e", -0.02, 0.17, 1.02), BAIXO],
		&"pe_d": [_lado(corpo, &"pe_d", 0.02, 0.17, 1.02), BAIXO],
	}
	var flexao := {
		&"mao_e": [_lado(corpo, &"mao_e", 0.0, 0.09, -0.15), TRAS + CIMA],
		&"mao_d": [_lado(corpo, &"mao_d", 0.0, 0.09, -0.15), TRAS + CIMA],
	}
	var quatro_pes := {
		&"pe_e": [_lado(corpo, &"pe_e", 0.0, 0.16, 0.69), BAIXO + FRENTE * 0.3],
		&"pe_d": [_lado(corpo, &"pe_d", 0.0, 0.16, 0.69), BAIXO + FRENTE * 0.3],
	}
	var quatro_maos := {
		&"mao_e": [_lado(corpo, &"mao_e", 0.0, 0.06, -0.15), TRAS],
		&"mao_d": [_lado(corpo, &"mao_d", 0.0, 0.06, -0.15), TRAS],
	}
	var pe_de_pe := [_lado(corpo, &"pe_d", 0.0, 0.07, 0.0), FRENTE]
	var de_pe := LevantarDoChao.de_pe(corpo)
	# De lado, a barriga (osso de mola) pende para o chao e nao entra nas
	# amostras do tronco: o gordo deita mais alto.
	var gordo := Anatomia.gordura(corpo.aparencia())
	return [
		chave_caido(corpo),
		# Os dois joelhos sobem, a cabeca volta ao meio.
		_chave(corpo, 0.9, q, _de_costas(MEIO_PI), _com(_bracos_no_chao(0.3),
			{O.TORSO: Vector3.ZERO, O.CABECA: Vector3(-0.2, 0.0, 0.0)}), {
				&"pe_e": [_esp(corpo, &"pe_e", -0.02, 0.08, 0.80), CIMA],
				&"pe_d": [_esp(corpo, &"pe_d", 0.02, 0.08, 0.78), CIMA],
			}, true),
		# Meio do rolar: o ombro de baixo passa pelo chao, e o corpo sobe o que
		# ele precisa para nao entrar nele. A mao esquerda atravessa no ar.
		_chave(corpo, 0.5, q + Vector3(0.0, 0.16 + 0.07 * gordo, 0.0),
			Basis(Vector3(0.0, 0.0, 1.0), MEIO_PI * 0.5) * _de_costas(MEIO_PI), {
			O.TORSO: Vector3(-0.12, 0.0, 0.0), O.CABECA: Vector3(-0.3, 0.0, 0.0)}, {
				&"mao_e": [_abs(corpo, Vector3(-0.15, 0.30, 0.0)), Vector3(0.3, 1.0, 0.4)],
				&"mao_d": [_abs(corpo, Vector3(-0.30, 0.07, -0.22)), Vector3(-0.3, 1.0, -0.3)],
				&"pe_e": [_abs(corpo, Vector3(-0.06, 0.16, 0.80)), Vector3(-0.7, 0.7, 0.0)],
				&"pe_d": [_abs(corpo, Vector3(0.02, 0.09, 0.82)), Vector3(-0.6, 0.8, 0.0)],
			}),
		# De lado: a mao esquerda planta no chao, a frente do peito — as maos
		# para a frente.
		_chave(corpo, 0.5, q + Vector3(0.0, 0.14 + 0.1 * gordo, 0.0), _de_lado(), {
			O.TORSO: Vector3(-0.2, 0.0, 0.0), O.CABECA: Vector3(-0.25, 0.0, 0.0)}, {
				&"mao_e": [_abs(corpo, Vector3(-0.34, 0.06, -0.02)), Vector3(0.3, 1.0, 0.4)],
				&"mao_d": [_abs(corpo, Vector3(-0.36, 0.07, -0.30)), Vector3(-0.3, 1.0, -0.3)],
				&"pe_e": [_abs(corpo, Vector3(-0.10, 0.22, 0.78)), Vector3(-1.0, 0.2, 0.0)],
				&"pe_d": [_abs(corpo, Vector3(0.02, 0.09, 0.82)), Vector3(-1.0, 0.7, 0.0)],
			}),
		# De bruços com as maos embaixo dos ombros, ja empurrando.
		_chave(corpo, 0.8, q + Vector3(0.0, 0.1 * gordo, 0.0), _de_brucos(1.3), {
			O.TORSO: Vector3.ZERO, O.CABECA: Vector3(0.25, 0.0, 0.0)},
			_com(maos_brucos, pes_brucos), gordo < 0.5),
		# A flexao: o peito sai do chao.
		_chave(corpo, 0.9, q, _de_brucos(1.15), {O.TORSO: Vector3.ZERO,
			O.CABECA: Vector3(0.35, 0.0, 0.0)}, _com(flexao, pes_brucos), true),
		# O braco direito cede: a mao escorrega para a frente e a cabeca cai.
		_chave(corpo, 0.35, q, _de_brucos(1.4), {O.TORSO: Vector3.ZERO,
			O.CABECA: Vector3(-0.1, 0.25, 0.0)}, _com(pes_brucos, {
				&"mao_e": flexao[&"mao_e"],
				&"mao_d": [_lado(corpo, &"mao_d", 0.04, 0.07, -0.34), TRAS + CIMA],
			}), true, Curva.ENTRA),
		# Empurra de novo.
		_chave(corpo, 0.75, q, _de_brucos(1.15), {O.TORSO: Vector3.ZERO,
			O.CABECA: Vector3(0.3, 0.0, 0.0)}, _com(flexao, pes_brucos), true),
		# De quatro.
		_chave(corpo, 0.9, Vector3(0.0, 0.47, 0.3), _de_brucos(1.35), {
			O.TORSO: Vector3.ZERO, O.CABECA: Vector3(0.35, 0.0, 0.0)},
			_com(quatro_maos, quatro_pes)),
		# Parado de quatro, a cabeca pendendo: o folego.
		_chave(corpo, 0.55, Vector3(0.0, 0.46, 0.3), _de_brucos(1.38), {
			O.TORSO: Vector3(0.06, 0.0, 0.0), O.CABECA: Vector3(-0.35, 0.0, 0.0)},
			_com(quatro_maos, quatro_pes)),
		# Um joelho: o pe direito vai a frente e planta onde vai ficar; a mao
		# direita no joelho da frente.
		_chave(corpo, 1.0, Vector3(0.0, 0.5, 0.25), Basis.from_euler(Vector3(-0.2, 0.0, 0.0)), {
			O.TORSO: Vector3(-0.1, 0.0, 0.0), O.CABECA: Vector3(0.1, 0.0, 0.0)}, {
				&"pe_e": [_lado(corpo, &"pe_e", 0.0, 0.15, 0.72), BAIXO + FRENTE * 0.3],
				&"pe_d": pe_de_pe,
				&"mao_e": [_lado(corpo, &"mao_e", 0.05, 0.62, 0.05), TRAS],
				&"mao_d": [_lado(corpo, &"mao_d", -0.05, 0.62, -0.18), TRAS],
			}),
		# Empurra no joelho e sobe, o pe de tras ainda arrastando.
		_chave(corpo, 1.0, Vector3(0.0, 0.76, 0.12), Basis.from_euler(Vector3(-0.4, 0.0, 0.0)), {
			O.TORSO: Vector3(-0.2, 0.0, 0.0), O.CABECA: Vector3(0.2, 0.0, 0.0)}, {
				&"pe_e": [_lado(corpo, &"pe_e", 0.0, 0.08, 0.5), FRENTE],
				&"pe_d": pe_de_pe,
				&"mao_e": [_lado(corpo, &"mao_e", 0.02, 0.72, 0.12), TRAS],
				&"mao_d": [_lado(corpo, &"mao_d", -0.06, 0.64, -0.12), TRAS],
			}),
		# De pe, curvado; o pe de tras sobe para vir.
		_chave(corpo, 0.6, Vector3(0.0, 0.86, 0.06), Basis.from_euler(Vector3(-0.2, 0.0, 0.0)),
			_com(de_pe, {O.TORSO: Vector3(-0.12, 0.0, 0.0), O.CABECA: Vector3(0.1, 0.0, 0.0)}), {
				&"pe_e": [_lado(corpo, &"pe_e", 0.0, 0.16, 0.24), FRENTE],
				&"pe_d": pe_de_pe,
			}),
		# O pe planta e o corpo balanca para tras: ainda tonto.
		_chave(corpo, 0.5, Vector3(0.0, 0.9, 0.05), Basis.from_euler(Vector3(0.05, 0.0, 0.0)),
			_com(de_pe, {O.TORSO: Vector3(0.02, 0.0, 0.0), O.CABECA: Vector3(-0.08, 0.1, 0.0)}), {
				&"pe_e": [_lado(corpo, &"pe_e", 0.0, 0.07, 0.03), FRENTE],
				&"pe_d": pe_de_pe,
			}),
		# De pe, na pose parada do proprio Corpo: soltar nao da pulo.
		_chave(corpo, 0.6, Vector3(0.0, 0.9, 0.0), Basis(), de_pe, {
				&"pe_e": [_lado(corpo, &"pe_e", 0.0, 0.07, 0.0), FRENTE],
				&"pe_d": pe_de_pe,
			}),
	]


## --- O olhar em volta (TAKE 4) ----------------------------------------------
##
## De pe, onde o levantar deixou, e sem sair do lugar: a mao vai a nuca (onde
## bateu), a cabeca procura para um lado, para o outro, sobe para a torre da
## igreja e, quando a respiracao calma volta pela esquerda, ele vira por cima
## do ombro esquerdo. Termina de novo na pose parada do Corpo, para `soltar`
## nao dar pulo. A camera da volta nele por fora (`Abertura.ORBITA_*`), e os
## tempos daqui sao os mesmos de la.
const OLHAR_MAO_NA_NUCA := 0.55
const OLHAR_MAO_CAI := 1.3
## O rosto sobe para a torre: e a passagem da camera pela frente dele.
const OLHAR_TORRE := 3.6
const OLHAR_TORRE_FIM := 4.5
## A respiracao pela esquerda e o giro por cima do ombro.
const OLHAR_OUVE := 5.5
const OLHAR_VIRA := 5.85
const OLHAR_VIROU := 6.45
const OLHAR_FIM := 8.2


static func chaves_olhar(corpo: Corpo) -> Array:
	var de_pe := LevantarDoChao.de_pe(corpo)
	var q := Vector3(0.0, 0.9, 0.0)
	var pe_e := [_lado(corpo, &"pe_e", 0.0, 0.07, 0.0), FRENTE]
	var pe_d := [_lado(corpo, &"pe_d", 0.0, 0.07, 0.0), FRENTE]
	var pes := {&"pe_e": pe_e, &"pe_d": pe_d}
	# A mao na nuca: atras da cabeca, o cotovelo aberto para o lado e para cima.
	var nuca := _com(pes, {&"mao_d": [_lado(corpo, &"mao_d", -0.15, 1.56, 0.11),
		Vector3(1.0, 0.35, -0.3)]})
	# O giro por cima do ombro: o pe esquerdo recua meio passo para o corpo abrir.
	var pe_e_recua := [_lado(corpo, &"pe_e", 0.04, 0.07, 0.12), FRENTE]
	var pes_abertos := {&"pe_e": pe_e_recua, &"pe_d": pe_d}
	var pe_e_no_ar := [_lado(corpo, &"pe_e", 0.03, 0.15, 0.07), FRENTE]
	return [
		_chave(corpo, 0.0, q, Basis(), de_pe, pes),
		# A mao sobe a nuca; o queixo cai, procurando o machucado.
		_chave(corpo, OLHAR_MAO_NA_NUCA, Vector3(0.0, 0.895, 0.01), Basis(),
			_com(de_pe, {O.TORSO: Vector3(-0.07, 0.0, 0.0), O.CABECA: Vector3(-0.32, 0.0, 0.0)}),
			nuca, false, Curva.SAI),
		# Apalpa: a cabeca vira um pouco com a mao ainda la.
		_chave(corpo, OLHAR_MAO_CAI - OLHAR_MAO_NA_NUCA, Vector3(0.0, 0.895, 0.01), Basis(),
			_com(de_pe, {O.TORSO: Vector3(-0.06, -0.05, 0.0), O.CABECA: Vector3(-0.22, -0.25, 0.0)}),
			nuca),
		# A mao cai e a cabeca levanta, ja indo para a esquerda.
		_chave(corpo, 0.5, q, Basis(), _com(de_pe, {
			O.TORSO: Vector3(-0.01, 0.1, 0.0), O.CABECA: Vector3(0.0, 0.4, 0.0)}), pes, false,
			Curva.ENTRA),
		# Esquerda.
		_chave(corpo, 0.8, q, Basis.from_euler(Vector3(0.0, 0.06, 0.0)), _com(de_pe, {
			O.TORSO: Vector3(-0.01, 0.3, 0.0), O.CABECA: Vector3(0.05, 0.95, 0.0)}), pes),
		# A torre: de volta para a frente e o rosto sobe, o corpo recuando um pouco.
		_chave(corpo, OLHAR_TORRE - 2.6, Vector3(0.0, 0.9, 0.02), Basis.from_euler(Vector3(0.03, 0.0, 0.0)),
			_com(de_pe, {O.TORSO: Vector3(0.05, 0.0, 0.0), O.CABECA: Vector3(0.34, 0.05, 0.0)}), pes),
		# Parado olhando para cima; o olho deriva.
		_chave(corpo, OLHAR_TORRE_FIM - OLHAR_TORRE, Vector3(0.0, 0.9, 0.02),
			Basis.from_euler(Vector3(0.03, 0.0, 0.0)),
			_com(de_pe, {O.TORSO: Vector3(0.05, -0.04, 0.0), O.CABECA: Vector3(0.3, -0.06, 0.0)}), pes),
		# Direita, longe.
		_chave(corpo, OLHAR_OUVE - OLHAR_TORRE_FIM, q, Basis.from_euler(Vector3(0.0, -0.08, 0.0)),
			_com(de_pe, {O.TORSO: Vector3(-0.01, -0.32, 0.0), O.CABECA: Vector3(0.0, -1.0, 0.0)}), pes),
		# Congela: ouviu.
		_chave(corpo, OLHAR_VIRA - OLHAR_OUVE, q, Basis.from_euler(Vector3(0.0, -0.08, 0.0)),
			_com(de_pe, {O.TORSO: Vector3(-0.02, -0.3, 0.0), O.CABECA: Vector3(-0.04, -1.05, 0.0)}),
			{&"pe_e": pe_e_no_ar, &"pe_d": pe_d}),
		# Vira por cima do ombro esquerdo, rapido, o pe esquerdo abrindo.
		_chave(corpo, OLHAR_VIROU - OLHAR_VIRA, Vector3(0.0, 0.895, 0.0),
			Basis.from_euler(Vector3(0.0, 0.18, 0.0)),
			_com(de_pe, {O.TORSO: Vector3(-0.02, 0.45, 0.0), O.CABECA: Vector3(0.02, 1.15, 0.0)}),
			pes_abertos, false, Curva.SAI),
		# Nao tem ninguem. Segura.
		_chave(corpo, 0.85, Vector3(0.0, 0.895, 0.0), Basis.from_euler(Vector3(0.0, 0.16, 0.0)),
			_com(de_pe, {O.TORSO: Vector3(-0.03, 0.42, 0.0), O.CABECA: Vector3(-0.02, 1.1, 0.0)}),
			pes_abertos),
		# Volta devagar para a frente, na pose parada do Corpo.
		_chave(corpo, OLHAR_FIM - OLHAR_VIROU - 0.85, q, Basis(), de_pe, pes),
	]


## A pose em `t` segundos. Como `LevantarDoChao.pose_em`, mas cada trecho chega
## na chave pela curva dela: o smoothstep puro para em toda chave, e dez chaves
## seguidas liam como dez poses de manequim.
static func pose_em(ch: Array, t: float, corpo: Corpo) -> Dictionary:
	var acumulado := 0.0
	for i in range(1, ch.size()):
		var c: Dictionary = ch[i]
		var dur := float(c["dur"])
		if t <= acumulado + dur:
			var u := clampf((t - acumulado) / maxf(dur, 0.001), 0.0, 1.0)
			return LevantarDoChao._entre(ch[i - 1], c, _curvar(u, int(c.get("curva", 0))), corpo)
		acumulado += dur
	var ultima: Dictionary = ch[ch.size() - 1]
	return LevantarDoChao._entre(ultima, ultima, 1.0, corpo)


static func duracao(ch: Array) -> float:
	var t := 0.0
	for c: Dictionary in ch:
		t += float(c["dur"])
	return t


static func _curvar(u: float, curva: int) -> float:
	match curva:
		Curva.ENTRA:
			return u * u
		Curva.SAI:
			return 1.0 - (1.0 - u) * (1.0 - u)
		Curva.RETA:
			return u
	return lerpf(u, u * u * (3.0 - 2.0 * u), 0.7)
