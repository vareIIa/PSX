## O caminho a pe dentro da estufa, de um ponto a outro, passando pelo elevador
## quando os dois estao em andares diferentes.
##
## A estufa nao tem malha de navegacao (o fazendeiro anda em linha reta, ver
## Convidado._andando), e numa galeria linha reta atravessa o poco. Entao o
## caminho e feito de pontos: os dois corredores compridos, entre os vasos e o
## guarda-corpo; a passarela no norte, onde a cabine abre; e a faixa do sul, do
## lado oposto. Na lavoura, o corredor rente a grade de cada lado: primeiro ao
## longo dele ate a linha do alvo, depois de lado ate o alvo. Em linha reta o
## fazendeiro batia no vaso de dentro indo ao de fora da mesma linha e ficava
## raspando nele — foi o que parou Jota e Helmer por quarenta segundos.
##
## Tudo em coordenada do comodo (a da EstufaBuilder). Quem anda converte.
class_name RotaDoPoco
extends RefCounted

## A faixa do sul das galerias, de um corredor ao outro.
const Z_SUL := 2.4
## Ate onde os corredores vao no norte: a porta das estacoes e do caixote.
const Z_NORTE := 16.2


## Os passos de `de` ate `para`: pontos (Vector3) e, no meio, `{"elevador": n}`
## — pegar a cabine no patamar do andar em que se esta e descer (ou subir) ao n.
static func rota(de: Vector3, para: Vector3) -> Array:
	var a := EstufaBuilder.andar_de_y(de.y)
	var b := EstufaBuilder.andar_de_y(para.y)
	if a == b:
		return _no_andar(de, para, a)
	var saida := _no_andar(de, patamar(a), a)
	saida.append({"elevador": b})
	saida.append_array(_no_andar(patamar(b), para, b))
	return saida


## Os corredores da lavoura, entre a coluna de dentro dos vasos e a grade.
const CORREDOR_LAVOURA := Vector2(3.4, 8.6)


## Onde se espera o elevador no andar `n`.
static func patamar(n: int) -> Vector3:
	return EstufaBuilder.PATAMAR + Vector3(0.0, EstufaBuilder.nivel(n), 0.0)


static func _no_andar(de: Vector3, para: Vector3, andar: int) -> Array:
	if andar >= EstufaBuilder.ANDARES:
		return [para]
	if andar <= 1:
		return _na_lavoura(de, para)
	var y := EstufaBuilder.nivel(andar)
	var la := _lado(de)
	var lb := _lado(para)
	var saida: Array = []
	var ca := _no_corredor(de, la, y)
	var cb := _no_corredor(para, lb, y)
	if la == lb:
		saida.append(ca)
		saida.append(cb)
		saida.append(para)
		return saida
	# Lados diferentes: pela passarela (norte) ou pela faixa do sul, o que for
	# mais curto. O ponto de virada e o canto do corredor de cada lado.
	var z_norte := EstufaBuilder.PATAMAR.z
	var por_norte := absf(ca.z - z_norte) + absf(cb.z - z_norte)
	var por_sul := absf(ca.z - Z_SUL) + absf(cb.z - Z_SUL)
	var zv := z_norte if por_norte <= por_sul else Z_SUL
	# Da passarela so se sai para o norte; da faixa sul, so para o sul.
	if la == &"ponte" or lb == &"ponte":
		zv = z_norte
	elif la == &"sul" or lb == &"sul":
		zv = Z_SUL
	saida.append(ca)
	saida.append(Vector3(ca.x, y, zv))
	saida.append(Vector3(cb.x, y, zv))
	saida.append(cb)
	saida.append(para)
	return saida


## A faixa do meio da lavoura (os dois corredores e a grade) nao tem vaso: quem
## esta fora dela sai para o corredor do proprio lado pela linha em que esta (o
## vao entre as linhas, ou a faixa do sul), atravessa a faixa, e so entao entra.
static func _na_lavoura(de: Vector3, para: Vector3) -> Array:
	var y := de.y
	var saida: Array = []
	if not _na_faixa(de):
		saida.append(Vector3(_corredor_lavoura(de), y, de.z))
	if not _na_faixa(para):
		saida.append(Vector3(_corredor_lavoura(para), y, para.z))
	saida.append(para)
	return saida


static func _na_faixa(p: Vector3) -> bool:
	return p.x > CORREDOR_LAVOURA.x - 0.1 and p.x < CORREDOR_LAVOURA.y + 0.1


static func _corredor_lavoura(p: Vector3) -> float:
	return CORREDOR_LAVOURA.x if p.x < EstufaBuilder.LARGURA * 0.5 else CORREDOR_LAVOURA.y


## Em que parte da galeria o ponto esta: um dos dois lados compridos, a
## passarela ou a faixa do sul.
static func _lado(p: Vector3) -> StringName:
	if p.x < EstufaBuilder.POCO_X.x:
		return &"oeste"
	if p.x > EstufaBuilder.POCO_X.y:
		return &"leste"
	if p.z < EstufaBuilder.POCO_Z.x:
		return &"sul"
	return &"ponte"


## O ponto do corredor mais perto de `p`, no lado dele. Na passarela e na
## faixa sul o proprio ponto serve.
static func _no_corredor(p: Vector3, lado: StringName, y: float) -> Vector3:
	match lado:
		&"oeste":
			return Vector3(EstufaBuilder.CORREDOR_GALERIA.x, y, clampf(p.z, Z_SUL, Z_NORTE))
		&"leste":
			return Vector3(EstufaBuilder.CORREDOR_GALERIA.y, y, clampf(p.z, Z_SUL, Z_NORTE))
	return Vector3(p.x, y, p.z)
