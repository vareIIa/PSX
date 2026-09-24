## O jeito de cada um: como a pessoa anda, fica parada e mexe as maos.
##
## Antes a ficha so variava o tamanho do passo e a cadencia, e a rua inteira
## andava com o mesmo balanco de braco, a mesma cabeca e o mesmo parado. Aqui a
## ficha (e o temperamento, e a idade, e a gordura) vira um punhado de eixos que
## o `Corpo` le a cada pose:
##
##     curvatura     tronco curvado ou peito aberto (rad)
##     cabeca        cabeca baixa ou alta (rad; positivo olha para baixo)
##     braco         quanto o braco balanca andando (x AMPLITUDE_BRACO)
##     assimetria    um braco balanca mais que o outro
##     maos          onde ficam as maos andando: livres, bolso, atras, celular
##     quique        o sobe e desce do passo (x 2,2 cm)
##     largura       pes mais abertos (m)
##     bamboleio     o quadril que vai de um lado para o outro (gordura)
##     zigue         o bebado cambaleando de lado
##     gesto         quanto gesticula falando (0 quase nada, 1,6 muito)
##     ocios         os tres ocios dela, entre os doze (`ReacaoCorpo`)
##     intervalo     de quanto em quanto tempo parada ela faz um ocio (s)
##     fase          onde o ciclo de andar comeca (senao todo mundo que nasce
##                   junto pisa junto)
##
## Tudo sai de `Aparencia._h(id, canal)` — a mesma pessoa tem o mesmo jeito
## sempre, nesta maquina e na do amigo (plano, regra 4). Canais a partir de 27.
class_name Jeito
extends RefCounted

enum Maos { LIVRES, BOLSO, ATRAS, CELULAR }


## Os ocios que cada temperamento puxa (o primeiro e o que mais aparece).
## Indices de `Personalidade.LISTA`.
const OCIOS_DO_TEMPERAMENTO: Array = [
	[ReacaoCorpo.OCIO_BOLSO, ReacaoCorpo.OCIO_OLHAR, ReacaoCorpo.OCIO_CRUZA],          # DESCONFIADO
	[ReacaoCorpo.OCIO_CELULAR, ReacaoCorpo.OCIO_OLHAR, ReacaoCorpo.OCIO_PESO],         # TAGARELA
	[ReacaoCorpo.OCIO_RELOGIO, ReacaoCorpo.OCIO_CELULAR, ReacaoCorpo.OCIO_PESO],       # APRESSADO
	[ReacaoCorpo.OCIO_NUCA, ReacaoCorpo.OCIO_PESO, ReacaoCorpo.OCIO_CEU],              # MELANCOLICO
	[ReacaoCorpo.OCIO_OLHAR, ReacaoCorpo.OCIO_PESO, ReacaoCorpo.OCIO_ESPREGUICA],      # GENTIL
	[ReacaoCorpo.OCIO_BOCEJO, ReacaoCorpo.OCIO_PESO, ReacaoCorpo.OCIO_NUCA],           # BEBADO
	[ReacaoCorpo.OCIO_BENZE, ReacaoCorpo.OCIO_PESO, ReacaoCorpo.OCIO_OLHAR],           # DEVOTO
	[ReacaoCorpo.OCIO_CRUZA, ReacaoCorpo.OCIO_BOLSO, ReacaoCorpo.OCIO_RELOGIO],        # CINICO
	[ReacaoCorpo.OCIO_OLHAR, ReacaoCorpo.OCIO_NUCA, ReacaoCorpo.OCIO_CELULAR],         # ASSUSTADO
	[ReacaoCorpo.OCIO_CINTURA, ReacaoCorpo.OCIO_CRUZA, ReacaoCorpo.OCIO_RELOGIO],      # MANDAO
	[ReacaoCorpo.OCIO_CEU, ReacaoCorpo.OCIO_ESPREGUICA, ReacaoCorpo.OCIO_BOCEJO],      # SONHADOR
	[ReacaoCorpo.OCIO_ESFREGA, ReacaoCorpo.OCIO_OLHAR, ReacaoCorpo.OCIO_BOLSO],        # VIGARISTA
]

## Ocios que qualquer um pode ter, para a ficha trocar um dos tres do
## temperamento e dois desconfiados nao ficarem iguais.
const OCIOS_SOLTOS: Array[int] = [ReacaoCorpo.OCIO_PESO, ReacaoCorpo.OCIO_OLHAR, ReacaoCorpo.OCIO_RELOGIO, ReacaoCorpo.OCIO_CELULAR,
	ReacaoCorpo.OCIO_BOLSO, ReacaoCorpo.OCIO_CRUZA, ReacaoCorpo.OCIO_NUCA, ReacaoCorpo.OCIO_ESPREGUICA]


## O jeito neutro: quem nao tem ficha (retrato, teste) anda como antes.
static func neutro() -> Dictionary:
	return {
		"curvatura": 0.0, "cabeca": 0.0, "braco": 1.0, "assimetria": 0.0,
		"maos": Maos.LIVRES, "quique": 1.0, "largura": 0.0, "bamboleio": 0.0,
		"zigue": 0.0, "gesto": 1.0, "ocios": [], "intervalo": 8.0, "fase": 0.0,
		# Contato de olho: -1 desvia (assustado, vigarista), 1 encara (mandao).
		"contato": 0,
	}


static func _u(id: int, canal: int) -> float:
	return float(Aparencia._h(id, canal) % 1000) / 1000.0


static func de(ficha: Dictionary) -> Dictionary:
	var j := neutro()
	var id := int(ficha.get("id", 0))
	var p := int(ficha.get("personalidade", 0))
	var a: Dictionary = ficha.get("aparencia", {})
	var idade := int(ficha.get("idade", 35))
	var g := Anatomia.gordura(a)
	var velho := smoothstep(55.0, 80.0, float(idade))

	j["curvatura"] = lerpf(-0.035, 0.025, _u(id, 27)) - 0.06 * velho
	j["cabeca"] = lerpf(-0.04, 0.05, _u(id, 28)) + 0.05 * velho
	j["braco"] = lerpf(0.75, 1.2, _u(id, 29))
	j["assimetria"] = lerpf(-0.22, 0.22, _u(id, 30))
	j["quique"] = lerpf(0.75, 1.3, _u(id, 31)) * (1.0 - 0.35 * velho)
	j["largura"] = 0.035 * smoothstep(0.55, 1.0, g) + 0.01 * _u(id, 32)
	j["bamboleio"] = smoothstep(0.6, 1.0, g)
	j["gesto"] = lerpf(0.7, 1.2, _u(id, 33))
	j["intervalo"] = lerpf(6.0, 11.0, _u(id, 34))
	j["fase"] = _u(id, 35) * TAU
	var m := _u(id, 36)
	j["maos"] = Maos.LIVRES if m < 0.62 else (Maos.BOLSO if m < 0.8 else (
		Maos.ATRAS if m < 0.9 else Maos.CELULAR))

	# O temperamento puxa os eixos para o lado dele.
	match p:
		2:  # APRESSADO
			j["braco"] = j["braco"] * 1.25
			j["curvatura"] -= 0.03
			j["maos"] = Maos.LIVRES
		3:  # MELANCOLICO
			j["curvatura"] -= 0.06
			j["cabeca"] += 0.12
			j["braco"] = j["braco"] * 0.7
			j["quique"] = j["quique"] * 0.7
		5:  # BEBADO
			j["zigue"] = 1.0
			j["largura"] += 0.04
			j["cabeca"] += 0.06
		6:  # DEVOTO
			if m < 0.7:
				j["maos"] = Maos.ATRAS
		7:  # CINICO
			j["braco"] = j["braco"] * 0.65
			j["gesto"] = j["gesto"] * 0.7
		0:  # DESCONFIADO
			j["gesto"] = j["gesto"] * 0.5
			if m < 0.6:
				j["maos"] = Maos.BOLSO
		1, 11:  # TAGARELA, VIGARISTA
			j["gesto"] = j["gesto"] * 1.4
			if p == 11:
				j["contato"] = -1
		8:  # ASSUSTADO
			j["contato"] = -1
			j["curvatura"] -= 0.03
			j["intervalo"] = j["intervalo"] * 0.6
		9:  # MANDAO
			j["contato"] = 1
			j["curvatura"] += 0.05
			j["cabeca"] -= 0.06
			j["braco"] = j["braco"] * 1.1
		10:  # SONHADOR
			j["cabeca"] -= 0.06
	# Os tres ocios: os do temperamento, com um trocado pela ficha.
	var ocios: Array = (OCIOS_DO_TEMPERAMENTO[clampi(p, 0, 11)] as Array).duplicate()
	var troca := Aparencia._h(id, 37) % 3
	var solto: int = OCIOS_SOLTOS[Aparencia._h(id, 38) % OCIOS_SOLTOS.size()]
	if troca > 0 and not ocios.has(solto):
		ocios[troca] = solto
	j["ocios"] = ocios
	return j


## Uma assinatura curta do jeito, para a regua contar jeitos distintos.
static func assinatura(j: Dictionary) -> String:
	return "%d/%d/%d/%d/%d/%s/%d" % [roundi(float(j["curvatura"]) * 40.0),
		roundi(float(j["cabeca"]) * 40.0), roundi(float(j["braco"]) * 8.0),
		int(j["maos"]), roundi(float(j["quique"]) * 6.0), str(j["ocios"]),
		roundi(float(j["assimetria"]) * 10.0)]
