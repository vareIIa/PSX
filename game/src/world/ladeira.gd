## O declive de cada trecho de rua, e onde a rua vira escadaria.
##
## Por que existe
## -------------
## No morro (Morros, Relevo) uma parte das ruas passa de 20%: na cidade mineira
## de verdade ali nao sobe carro, sobe gente, e a rua e escadaria de pedra com
## corrimao no meio. Aqui se decide qual trecho e escadaria, numa funcao pura da
## coordenada — o chunk que desenha o degrau, o transito que nao entra, o mapa
## que risca diferente e o GPS perguntam a mesma coisa.
##
## O trecho e o de sempre (MalhaUrbana.via_x_em / via_z_em): uma borda de chunk.
## Avenida nunca vira escadaria — ela e aterrada no Relevo e o transito depende
## dela para atravessar a cidade.
class_name Ladeira
extends RefCounted

## Declive a partir do qual rua e viela viram escadaria.
const LIMITE := 0.20


## Declive do trecho da linha x = i entre os nos j e j + 1.
static func declive_x(i: int, j: int) -> float:
	return absf(Relevo.no(i, j + 1) - Relevo.no(i, j)) / Relevo.TAM


## Declive do trecho da linha z = j entre os nos i e i + 1.
static func declive_z(j: int, i: int) -> float:
	return absf(Relevo.no(i + 1, j) - Relevo.no(i, j)) / Relevo.TAM


## O trecho da linha x = i entre j e j + 1 e escadaria?
static func escadaria_x(i: int, j: int) -> bool:
	return _pode_ser_escada(MalhaUrbana.via_x_em(i, j)) and declive_x(i, j) > LIMITE


## O trecho da linha z = j entre i e i + 1 e escadaria?
static func escadaria_z(j: int, i: int) -> bool:
	return _pode_ser_escada(MalhaUrbana.via_z_em(j, i)) and declive_z(j, i) > LIMITE


static func _pode_ser_escada(via: MalhaUrbana.Via) -> bool:
	return via == MalhaUrbana.Via.RUA or via == MalhaUrbana.Via.VIELA


## As bordas do chunk (cx, cz) que sao escadaria, nas chaves de MalhaUrbana.bordas.
static func bordas_em_escada(cx: int, cz: int) -> Dictionary:
	return {
		"x0": escadaria_x(cx, cz),
		"x1": escadaria_x(cx + 1, cz),
		"z0": escadaria_z(cz, cx),
		"z1": escadaria_z(cz + 1, cx),
	}
