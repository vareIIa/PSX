## Onde os bancos da frente ficam.
##
## O que isto ja foi
## -----------------
## Aqui moravam porta, banco e console da cabine, feitos de `AtlasKit.caixa`:
## peitoril, apoio, macaneta, manivela, pino, alto-falante e bolso colados no
## forro, e os bancos em tres caixas cada. Era o que respondia a reclamacao do
## jogador,
##
##     "no canto inferior esquerdo da janela da esquerda do carro, nao tem a
##      parte de maçaneta do carro, parte interior nao existe e invisivel"
##
## e a regra continua valendo nas pecas que o substituiram (`CabinePortas`,
## `CabineBancos`, `CabineConsole`): tudo e medido do assoalho, da linha da
## janela e da parede da casca, nunca da largura do carro.
##
## O que sobrou e a medida dos bancos, que o console usa para caber no vao entre
## os dois e a cabine passa ao interior.
class_name CabineMoveis
extends RefCounted


## Onde os bancos da frente ficam: `x` e a distancia do centro de cada um ao
## meio do carro, `y` a largura. O console mede o vao entre os dois daqui.
##
## A largura sai da PAREDE na altura do encosto, e nao da largura do carro: no
## Fusca a lateral fecha dez centimetros entre a cintura e o assoalho, e um
## banco dimensionado pela largura cheia atravessa a porta.
static func medida_dos_bancos(info: Dictionary, piso: float, olho: Vector3) -> Vector2:
	var meia := absf(CabineCasca.parede_x(info, piso + 0.50, olho.z + 0.42, 1.0))
	var largura := clampf(meia * 0.62, 0.30, 0.50)
	return Vector2(clampf(absf(olho.x), 0.0, meia - largura * 0.5 - 0.02), largura)
