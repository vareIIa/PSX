## Quem desceu da calcada numa zebra de cruzamento com sinal, e com que boneco
## (PLANO_TRANSITO_AAA, Passo 3). Mede de fora, pela posicao: nao le a decisao do
## pedestre. Usado pela bancada do cruzamento e pelo teste do transito na cidade
## — uma contagem de violacao vale como criterio mesmo observada.
##
## Uma descida e entrar no asfalto de uma zebra (dentro da faixa, ao longo, com
## um metro de folga; dentro do asfalto do braco, atravessado) vindo da calcada,
## onde esteve por `FORA_MIN` segundos: quem ja estava no asfalto (no miolo,
## depois de um susto) e passa por uma faixa nao esta comecando a atravessar
## nada. E conta uma vez por travessia: quem
## ja comecou (no ANDA), desviou de alguem para fora da faixa e voltou nao
## comecou de novo — a primeira rodada de 10 min contou assim duas "descidas no
## PARE piscando" de gente que tinha saido no ANDA.
class_name FiscalDeTravessia
extends RefCounted

const FORA_MIN := 1.0

var descidas := 0
var fora := 0
var detalhes: Array[String] = []
## Por pessoa: [braco em que esta no asfalto (-1: fora), desde quando esta fora].
var _onde: Dictionary = {}


## Olha uma pessoa agora (`agora`: o relogio do semaforo).
func olhar(pessoa: Node3D, agora: float) -> void:
	var p := Vector2(pessoa.global_position.x, pessoa.global_position.z)
	var ij := Vias.cruzamento_mais_proximo(pessoa.global_position)
	var id := pessoa.get_instance_id()
	var antes: Array = _onde.get(id, [-1, -INF, 0])
	var braco := -1
	if Semaforo.tem_sinal(ij.x, ij.y):
		for b in 4:
			if not Esquina.existe_braco(ij, b):
				continue
			var z := Esquina.zebra(ij, b)
			var al := z.ao_longo(p)
			if al >= z.lo - 1.0 and al <= z.hi + 1.0 and absf(z.atravessado(p)) <= z.meia:
				braco = b
				var trav: Variant = pessoa.get(&"_travessia")
				var id_trav := (trav as Object).get_instance_id() if trav != null else 0
				if (int(antes[0]) != b and agora - float(antes[1]) >= FORA_MIN
						and (id_trav == 0 or id_trav != int(antes[2]))):
					antes[2] = id_trav
					descidas += 1
					var st := Semaforo.estado_pedestre(ij.x, ij.y, z.eixo_carro, agora)
					if st != Semaforo.Travessia.ANDA:
						fora += 1
						if detalhes.size() < 12:
							detalhes.append("%s em %s braco %s boneco %s estado %s travessia %s" % [
								pessoa.name, ij, Esquina.Braco.keys()[b],
								Semaforo.Travessia.keys()[st], str(pessoa.call(&"estado_nome")),
								_travessia(pessoa)])
				break
	var na_calcada := braco < 0 and not Vias.no_asfalto(pessoa.global_position)
	if braco >= 0:
		_onde[id] = [braco, INF, antes[2]]
	elif not na_calcada:
		# No asfalto fora das faixas: nao conta como tempo na calcada.
		_onde[id] = [-1, INF, antes[2]]
	elif not _onde.has(id):
		_onde[id] = [-1, -INF, 0]
	elif int(antes[0]) >= 0 or float(antes[1]) == INF:
		_onde[id] = [-1, agora, antes[2]]


static func _travessia(pessoa: Node3D) -> String:
	var t: Variant = pessoa.get(&"_travessia")
	if t == null:
		return "nenhuma"
	var tr := t as RefCounted
	var z: Variant = tr.get(&"zebra")
	return "etapa %s braco %s espera %.1f" % [str(tr.get(&"etapa")),
		Esquina.Braco.keys()[(z as Esquina.Zebra).braco] if z != null else "-",
		float(tr.get(&"espera"))]
