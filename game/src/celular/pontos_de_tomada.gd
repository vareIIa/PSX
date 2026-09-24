## Onde ficam as tomadas de um interior: dos pontos candidatos (na face de uma
## parede, a 30 cm do chao, olhando para dentro do comodo), os que nao tem movel
## na frente.
##
## Classe pura, sem nos e sem autoload: os builders de interior rodam em thread
## e em teste de `--script`, e referenciar a `Tomada` (que conhece o `Celular` e
## o `Inventario`) derrubaria a compilacao deles — ver a memoria da classe leve.
##
## Sem sorteio: o interior sai de uma semente, e um numero a mais tirado do
## sorteio mudaria a mobilia de todas as casas da cidade.
class_name PontosDeTomada
extends RefCounted

## Altura da tomada baixa (NBR 5410: 30 cm do piso ao centro).
const ALTURA := 0.30


## `candidatos`: [[posicao na face da parede (y do chao), giro], ...], o giro
## sendo para onde a tomada olha (+Z antes do giro). Devolve ate `quantas`
## entradas de prop `tomada`.
static func escolher(candidatos: Array, colisao: Array[Dictionary], quantas: int) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	for c: Array in candidatos:
		if saida.size() >= quantas:
			break
		var chao: Vector3 = c[0]
		var giro: float = c[1]
		var pos := chao + Vector3(0.0, ALTURA, 0.0)
		var frente := pos + Vector3(sin(giro), 0.0, cos(giro)) * 0.25 + Vector3(0.0, 0.1, 0.0)
		var livre := true
		for caixa: Dictionary in colisao:
			var t: Vector3 = caixa["tamanho"]
			var r := AABB((caixa["pos"] as Vector3) - t * 0.5, t)
			if r.has_point(frente):
				livre = false
				break
		if livre:
			saida.append({"tipo": "tomada", "pos": pos, "giro": giro, "chao": chao.y})
	return saida
