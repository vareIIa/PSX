## GERADO por tools/gerar_rosto.py — nao editar a mao.
##
## Onde cada recorte da cara (boca, sobrancelhas, olhos) fica na celula de
## 32 px de cada rosto, e onde o bloco daquele rosto comeca em
## `rosto_atlas.png`. A chave e a celula do rosto no atlas de gente,
## Vector2i(coluna, linha). Ver `Rosto`.
class_name RostoMeta
extends RefCounted

const ATLAS := "res://assets/textures/rosto_atlas.png"
const LADO_ATLAS := 256
const TAM_BOCA := Vector2i(10, 7)
const TAM_SOBR := Vector2i(10, 5)
const TAM_OLHO := Vector2i(10, 6)
const BOCAS: Array[StringName] = [&"ENTREABERTA", &"ABERTA", &"REDONDA", &"SORRISO", &"TRISTE", &"CERRADA"]
const SOBRANCELHAS: Array[StringName] = [&"ERGUIDA", &"FRANZIDA", &"CAIDA"]
const OLHOS: Array[StringName] = [&"FECHADO", &"SEMICERRADO", &"ARREGALADO", &"OLHA_ESQ", &"OLHA_DIR"]

## Vector2i(coluna, linha) -> {bloco, boca, sobr_e, sobr_d, olho_e, olho_d},
## cada um Vector2i em pixels (bloco na folha; os outros na celula da cara).
const CARAS := {
	Vector2i(0, 0): {"bloco": Vector2i(0, 0), "boca": Vector2i(11, 20), "sobr_e": Vector2i(3, 8), "sobr_d": Vector2i(19, 8), "olho_e": Vector2i(3, 12), "olho_d": Vector2i(19, 12)},
	Vector2i(0, 1): {"bloco": Vector2i(128, 0), "boca": Vector2i(11, 22), "sobr_e": Vector2i(5, 9), "sobr_d": Vector2i(17, 9), "olho_e": Vector2i(5, 13), "olho_d": Vector2i(17, 13)},
	Vector2i(0, 9): {"bloco": Vector2i(0, 13), "boca": Vector2i(11, 21), "sobr_e": Vector2i(4, 9), "sobr_d": Vector2i(18, 9), "olho_e": Vector2i(3, 12), "olho_d": Vector2i(18, 12)},
	Vector2i(0, 10): {"bloco": Vector2i(128, 13), "boca": Vector2i(11, 20), "sobr_e": Vector2i(4, 9), "sobr_d": Vector2i(18, 9), "olho_e": Vector2i(3, 11), "olho_d": Vector2i(19, 11)},
	Vector2i(1, 0): {"bloco": Vector2i(0, 26), "boca": Vector2i(11, 20), "sobr_e": Vector2i(3, 9), "sobr_d": Vector2i(19, 9), "olho_e": Vector2i(3, 13), "olho_d": Vector2i(19, 13)},
	Vector2i(1, 1): {"bloco": Vector2i(128, 26), "boca": Vector2i(11, 21), "sobr_e": Vector2i(4, 9), "sobr_d": Vector2i(18, 9), "olho_e": Vector2i(4, 14), "olho_d": Vector2i(18, 14)},
	Vector2i(1, 9): {"bloco": Vector2i(0, 39), "boca": Vector2i(11, 21), "sobr_e": Vector2i(4, 8), "sobr_d": Vector2i(18, 8), "olho_e": Vector2i(3, 12), "olho_d": Vector2i(18, 12)},
	Vector2i(1, 10): {"bloco": Vector2i(128, 39), "boca": Vector2i(12, 20), "sobr_e": Vector2i(4, 9), "sobr_d": Vector2i(18, 9), "olho_e": Vector2i(3, 11), "olho_d": Vector2i(19, 11)},
	Vector2i(2, 0): {"bloco": Vector2i(0, 52), "boca": Vector2i(11, 20), "sobr_e": Vector2i(4, 9), "sobr_d": Vector2i(17, 9), "olho_e": Vector2i(4, 13), "olho_d": Vector2i(18, 13)},
	Vector2i(2, 1): {"bloco": Vector2i(128, 52), "boca": Vector2i(11, 23), "sobr_e": Vector2i(4, 10), "sobr_d": Vector2i(18, 10), "olho_e": Vector2i(4, 14), "olho_d": Vector2i(18, 14)},
	Vector2i(2, 9): {"bloco": Vector2i(0, 65), "boca": Vector2i(11, 20), "sobr_e": Vector2i(5, 9), "sobr_d": Vector2i(17, 9), "olho_e": Vector2i(4, 12), "olho_d": Vector2i(17, 12)},
	Vector2i(2, 10): {"bloco": Vector2i(128, 65), "boca": Vector2i(11, 20), "sobr_e": Vector2i(5, 9), "sobr_d": Vector2i(17, 9), "olho_e": Vector2i(4, 11), "olho_d": Vector2i(18, 11)},
	Vector2i(3, 0): {"bloco": Vector2i(0, 78), "boca": Vector2i(11, 19), "sobr_e": Vector2i(4, 9), "sobr_d": Vector2i(18, 9), "olho_e": Vector2i(4, 13), "olho_d": Vector2i(18, 13)},
	Vector2i(3, 1): {"bloco": Vector2i(128, 78), "boca": Vector2i(11, 19), "sobr_e": Vector2i(3, 7), "sobr_d": Vector2i(19, 7), "olho_e": Vector2i(3, 12), "olho_d": Vector2i(19, 12)},
	Vector2i(3, 9): {"bloco": Vector2i(0, 91), "boca": Vector2i(11, 21), "sobr_e": Vector2i(3, 8), "sobr_d": Vector2i(19, 8), "olho_e": Vector2i(3, 12), "olho_d": Vector2i(19, 12)},
	Vector2i(3, 10): {"bloco": Vector2i(128, 91), "boca": Vector2i(11, 20), "sobr_e": Vector2i(4, 10), "sobr_d": Vector2i(18, 10), "olho_e": Vector2i(3, 11), "olho_d": Vector2i(19, 11)},
	Vector2i(4, 0): {"bloco": Vector2i(0, 104), "boca": Vector2i(11, 20), "sobr_e": Vector2i(3, 9), "sobr_d": Vector2i(19, 9), "olho_e": Vector2i(3, 13), "olho_d": Vector2i(19, 13)},
	Vector2i(4, 1): {"bloco": Vector2i(128, 104), "boca": Vector2i(11, 19), "sobr_e": Vector2i(4, 9), "sobr_d": Vector2i(18, 9), "olho_e": Vector2i(4, 13), "olho_d": Vector2i(18, 13)},
	Vector2i(4, 9): {"bloco": Vector2i(0, 117), "boca": Vector2i(12, 20), "sobr_e": Vector2i(4, 10), "sobr_d": Vector2i(18, 10), "olho_e": Vector2i(3, 12), "olho_d": Vector2i(18, 12)},
	Vector2i(4, 10): {"bloco": Vector2i(128, 117), "boca": Vector2i(11, 20), "sobr_e": Vector2i(4, 9), "sobr_d": Vector2i(18, 9), "olho_e": Vector2i(3, 11), "olho_d": Vector2i(19, 11)},
	Vector2i(5, 0): {"bloco": Vector2i(0, 130), "boca": Vector2i(11, 21), "sobr_e": Vector2i(4, 9), "sobr_d": Vector2i(18, 9), "olho_e": Vector2i(4, 13), "olho_d": Vector2i(18, 13)},
	Vector2i(5, 1): {"bloco": Vector2i(128, 130), "boca": Vector2i(11, 24), "sobr_e": Vector2i(4, 10), "sobr_d": Vector2i(18, 10), "olho_e": Vector2i(4, 14), "olho_d": Vector2i(18, 14)},
	Vector2i(5, 9): {"bloco": Vector2i(0, 143), "boca": Vector2i(11, 20), "sobr_e": Vector2i(4, 8), "sobr_d": Vector2i(18, 8), "olho_e": Vector2i(3, 12), "olho_d": Vector2i(18, 12)},
	Vector2i(5, 10): {"bloco": Vector2i(128, 143), "boca": Vector2i(12, 20), "sobr_e": Vector2i(3, 9), "sobr_d": Vector2i(19, 9), "olho_e": Vector2i(2, 11), "olho_d": Vector2i(20, 11)},
	Vector2i(6, 0): {"bloco": Vector2i(0, 156), "boca": Vector2i(11, 20), "sobr_e": Vector2i(4, 9), "sobr_d": Vector2i(18, 9), "olho_e": Vector2i(4, 13), "olho_d": Vector2i(18, 13)},
	Vector2i(6, 1): {"bloco": Vector2i(128, 156), "boca": Vector2i(11, 21), "sobr_e": Vector2i(4, 7), "sobr_d": Vector2i(18, 7), "olho_e": Vector2i(4, 12), "olho_d": Vector2i(18, 12)},
	Vector2i(6, 9): {"bloco": Vector2i(0, 169), "boca": Vector2i(11, 21), "sobr_e": Vector2i(5, 9), "sobr_d": Vector2i(17, 9), "olho_e": Vector2i(4, 12), "olho_d": Vector2i(17, 12)},
	Vector2i(6, 10): {"bloco": Vector2i(128, 169), "boca": Vector2i(11, 20), "sobr_e": Vector2i(4, 9), "sobr_d": Vector2i(18, 9), "olho_e": Vector2i(3, 11), "olho_d": Vector2i(19, 11)},
	Vector2i(7, 0): {"bloco": Vector2i(0, 182), "boca": Vector2i(11, 22), "sobr_e": Vector2i(4, 9), "sobr_d": Vector2i(18, 9), "olho_e": Vector2i(4, 13), "olho_d": Vector2i(18, 13)},
	Vector2i(7, 1): {"bloco": Vector2i(128, 182), "boca": Vector2i(11, 22), "sobr_e": Vector2i(5, 9), "sobr_d": Vector2i(17, 9), "olho_e": Vector2i(5, 13), "olho_d": Vector2i(17, 13)},
	Vector2i(7, 9): {"bloco": Vector2i(0, 195), "boca": Vector2i(11, 20), "sobr_e": Vector2i(4, 8), "sobr_d": Vector2i(18, 8), "olho_e": Vector2i(3, 12), "olho_d": Vector2i(18, 12)},
	Vector2i(7, 10): {"bloco": Vector2i(128, 195), "boca": Vector2i(11, 20), "sobr_e": Vector2i(4, 9), "sobr_d": Vector2i(18, 9), "olho_e": Vector2i(3, 11), "olho_d": Vector2i(19, 11)},
	Vector2i(0, 8): {"bloco": Vector2i(0, 208), "boca": Vector2i(11, 24), "sobr_e": Vector2i(4, 7), "sobr_d": Vector2i(18, 7), "olho_e": Vector2i(4, 13), "olho_d": Vector2i(18, 13)},
	Vector2i(1, 8): {"bloco": Vector2i(128, 208), "boca": Vector2i(11, 23), "sobr_e": Vector2i(4, 7), "sobr_d": Vector2i(18, 7), "olho_e": Vector2i(4, 13), "olho_d": Vector2i(18, 13)},
}
