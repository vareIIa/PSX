## O equilibrio de quem esta de pe: balanca, tropeca e, se nao der, cai.
##
## E o "bodyBalance" e o "stumble" do Euphoria no GTA IV — trombar num pedestre
## faz ele cambalear dois ou tres passos, abrir os bracos e, conforme o
## empurrao, se recuperar ou ir ao chao. Aqui sem fisica de corpo inteiro: o
## corpo de pe e um PENDULO INVERTIDO (o centro de massa numa haste sobre os
## pes), que e o modelo que a robotica usa para decidir quando um passo e
## necessario.
##
## O estado e o deslocamento do centro de massa em relacao aos pes, no plano
## (`desvio`, metros), e a velocidade dele. Por passo de fisica:
##
## - o pendulo cai sozinho: aceleracao w^2 * desvio, com w = sqrt(g / altura);
## - o tornozelo e o quadril seguram, ate um teto (ACELERACAO_MAX). Empurrao
##   pequeno volta so com isso: o corpo balanca e para;
## - o "ponto de captura" (desvio + velocidade / w) diz onde o pe teria de
##   estar para o corpo parar. Passou de RAIO_SEM_PASSO, a pessoa DA UM PASSO
##   para la: o apoio anda, e o dono do corpo anda junto (`velocidade_do_pe`);
## - passo nao alcanca (ponto de captura alem de PASSO_MAX depois de
##   PASSOS_MAX passos) ou inclinacao alem de QUEDA: caiu. O dono troca para o
##   `BonecoDePano` com a velocidade do centro de massa.
##
## Quem desenha e o Corpo: `inclinacao` (o corpo todo inclinado sobre os pes),
## `debater` (bracos em moinho, o "armsWindmill") e `rumo_passo` (para que lado
## as pernas dao o passo).
class_name Equilibrio
extends RefCounted

const G := 9.8
## O quanto tornozelo e quadril seguram sem passo, em m/s^2 de centro de massa.
const ACELERACAO_MAX := 2.6
## Ganho da correcao (criticamente amortecida sobre w^2).
const KP_FATOR := 2.2
## Ponto de captura ate onde nao precisa de passo (m).
const RAIO_SEM_PASSO := 0.1
## Maior passo de recuperacao (m, corpo de 1,72) e quanto ele leva.
const PASSO_MAX := 0.62
const TEMPO_PASSO := 0.26
## Passos de recuperacao antes de desistir e cair.
const PASSOS_MAX := 5
## Inclinacao (desvio / altura do centro) em que nao ha mais o que fazer.
const QUEDA := 0.5

var altura_cm: float = 0.95
var desvio := Vector2.ZERO
var velocidade := Vector2.ZERO

var _w: float = 3.2
var _passo := Vector2.ZERO
var _t_passo := 0.0
var _passos := 0
var _caiu := false
var _quieto := 0.0
var _maior_passos := 0


func _init(altura_do_corpo: float = Corpo.ALTURA_REF) -> void:
	altura_cm = 0.55 * altura_do_corpo
	_w = sqrt(G / altura_cm)


## Empurrao: `dv` e a velocidade que o centro de massa ganha (m/s, no plano).
func empurrar(dv: Vector3) -> void:
	velocidade += Vector2(dv.x, dv.z)
	_quieto = 0.0


func ativo() -> bool:
	return not _caiu and (desvio.length() > 0.004 or velocidade.length() > 0.02 \
		or _t_passo > 0.0)


func caiu() -> bool:
	return _caiu


## A velocidade do centro de massa no mundo, para passar ao boneco de pano.
func velocidade_3d() -> Vector3:
	return Vector3(velocidade.x, 0.0, velocidade.y)


## Onde o ponto de captura esta: onde o pe teria de ir para parar o corpo.
func captura() -> Vector2:
	return desvio + velocidade / _w


## Um passo de fisica. Devolve a velocidade dos pes no mundo (m/s, no plano):
## e o quanto o dono tem de andar neste passo para acompanhar o tropeco.
func passo(delta: float) -> Vector3:
	if _caiu:
		return Vector3.ZERO
	# O pendulo, com o tornozelo e o quadril segurando ate o teto.
	var kp := KP_FATOR * _w * _w
	var kd := 2.0 * sqrt(kp - _w * _w)
	# O teto e o que separa balancar de tropecar: alem dele o pe tem de ir.
	var controle := (desvio * kp + velocidade * kd).limit_length(ACELERACAO_MAX)
	var acel := desvio * _w * _w - controle
	velocidade += acel * delta
	desvio += velocidade * delta

	# O passo em curso leva o apoio para baixo do centro de massa.
	var pe := Vector2.ZERO
	if _t_passo > 0.0:
		var fatia := minf(delta, _t_passo)
		pe = _passo / TEMPO_PASSO
		desvio -= pe * fatia
		_t_passo -= delta
	elif captura().length() > RAIO_SEM_PASSO:
		_passos += 1
		_maior_passos = maxi(_maior_passos, _passos)
		# Quem tropeca erra o passo para menos: 80% do ponto de captura. E o que
		# faz o tropeco ter dois, tres passos, e nao um passo certeiro de robo.
		var alvo := captura() * 0.8
		var maximo := PASSO_MAX * altura_cm / (0.55 * Corpo.ALTURA_REF)
		# Nao cabe num passo (nem com 15% de sobra, que o proximo passo cobre):
		# o empurrao e maior que o que perna segura. E muitos passos seguidos
		# sem parar e o corpo correndo atras do proprio peso ate o chao.
		if captura().length() > maximo * 1.15 or _passos > PASSOS_MAX:
			_caiu = true
			return Vector3.ZERO
		_passo = alvo.limit_length(maximo)
		_t_passo = TEMPO_PASSO
	if desvio.length() > QUEDA * altura_cm:
		_caiu = true
		return Vector3.ZERO
	if captura().length() < RAIO_SEM_PASSO * 0.5 and _t_passo <= 0.0:
		_quieto += delta
		if _quieto > 0.6:
			_passos = 0
	# O atrito com o chao desgasta o que sobrou quando ja esta quase parado.
	if desvio.length() < 0.01 and velocidade.length() < 0.05:
		velocidade = velocidade.lerp(Vector2.ZERO, minf(1.0, delta * 6.0))
	return Vector3(pe.x, 0.0, pe.y)


## Inclinacao do corpo em radianos, no referencial de quem tem o rumo `giro_y`
## (x: para a direita, y: para a frente).
func inclinacao_local(giro_y: float) -> Vector2:
	var d := Vector3(desvio.x, 0.0, desvio.y).rotated(Vector3.UP, -giro_y)
	# Frente do corpo e -Z.
	return Vector2(atan2(d.x, altura_cm), atan2(-d.z, altura_cm))


## Bracos em moinho: nada ate a pessoa precisar de passo, cheio perto da queda.
func debater() -> float:
	return smoothstep(RAIO_SEM_PASSO * 0.8, 0.45, captura().length())


## Para que lado o passo vai, no referencial do corpo (0 = para a frente).
func rumo_do_passo(giro_y: float) -> float:
	var d := Vector3(_passo.x, 0.0, _passo.y).rotated(Vector3.UP, -giro_y)
	return atan2(d.x, -d.z)


func dando_passo() -> bool:
	return _t_passo > 0.0


## Quantos passos o maior tropeco desde o empurrao teve.
func passos_dados() -> int:
	return _maior_passos
