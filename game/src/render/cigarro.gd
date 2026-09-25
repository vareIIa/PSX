## O cigarro da abertura: um Marlboro branco de 84 mm, filtro de cortica, que
## queima, faz cinza, solta o fio de fumaca e acaba bituca na calcada.
##
## O que ele substitui
## -------------------
## O cigarro do `Adereco`: um paralelepipedo de 7,2 x 0,85 x 0,85 cm com um
## retalho bege do casa_atlas, parafusado no osso do antebraco num angulo fixo.
## No plano do poste ele subia ate o peito e voltava (a tragada antiga, que nao
## chegava na boca), e no POV — escalado 1,5 vezes a doze centimetros do olho —
## virava um bloco amarelo aceso no canto da tela, com uma placa de fumaca em
## pe em cima.
##
## O que ele e
## -----------
## A `Blunt` com as medidas e a pele de um cigarro de maquina: cilindro reto de
## 16 lados e 7,8 mm, filtro de 27 mm em papel de cortica (o degrau de um
## decimo de milimetro na emenda e de verdade — o papel do filtro da a volta
## por cima do papel do cigarro), papel branco com a costura e a marca, e a
## boca do filtro em acetato. Queima, cinza, brasa que respira, fio de fumaca e
## baforada sao os da Blunt: o mesmo relogio (`Tragada`) e a mesma mira na boca.
##
## Os dois jeitos de existir
## -------------------------
##   no corpo   `montar(corpo, semente)`: segue a pega da mao direita e vai aos
##              labios na tragada, como a blunt da casa da fumaca.
##   livre      `montar(null, semente)`: segue o pai (a mao de primeira pessoa,
##              ou nada, caido no chao) e quem chama manda em `puxada`,
##              `consumo`, `cinza` e `vida`.
class_name Cigarro
extends Blunt

const TEXTURA_CIGARRO := "res://assets/textures/cigarro.png"
const NOME_HD_CIGARRO := &"cigarro"

## King size: 84 mm, 7,8 mm de diametro, 27 mm de filtro.
const COMPRIMENTO_CIGARRO := 0.084
const RAIO_CIGARRO := 0.0039
const FILTRO := 0.027
## O papel do filtro por cima do papel do cigarro: a espessura de uma folha.
const DEGRAU := 0.00012
## O que sobra no chao depois do ultimo trago: o filtro e seis milimetros de
## papel. Fracao queimada que deixa isso.
const QUEIMA_BITUCA := 1.0 - (FILTRO + 0.006 + 0.0028) / COMPRIMENTO_CIGARRO
## A pega na tragada, contada dos labios (referencial da cabeca). E o ponto
## fixo em que o cigarro RIGIDO nos dedos (eixo da mao vezes `dir_repouso`)
## poe a boca do filtro nos labios: o alvo muda o IK, o IK muda o giro da mao e
## o giro muda o eixo (`tests/bancada_cigarro.gd -- --ponto-fixo`, converge na
## primeira volta). Da o cigarro no canto da boca, a brasa para a frente e para
## a direita, saindo pelas costas da mao — e nao enterrado na palma.
const ALVO_NA_BOCA := Vector3(0.0205, 0.005, -0.0135)


func _init() -> void:
	comprimento = COMPRIMENTO_CIGARRO
	raio = RAIO_CIGARRO
	# Dezesseis lados: a doze centimetros do olho, doze viram um poligono.
	lados = 16
	largura_brasa = 0.0028
	cinza_max = 0.011
	# Entre o indicador e o medio, em cima do filtro: dois centimetros da boca.
	pega = 0.021
	# Atravessado nos dedos pela espessura da mao (+X, as costas), inclinado
	# para o lado do punho: na boca e isso que aponta a brasa para a frente. O
	# da blunt inclina para os dedos, e no cigarro a brasa subia rente ao nariz.
	dir_repouso = Vector3(0.9, 0.45, 0.0)
	textura = TEXTURA_CIGARRO
	nome_hd = NOME_HD_CIGARRO
	aperto = 0.0
	barriga = 0.0
	torto_raio = 0.004
	torto_eixo = 0.00003
	curva = 0.00012
	# O anel tostado de cigarro e estreito e mais escuro que o da folha.
	tostado = 0.0026
	queimado = 0.8
	umida = 0.0
	luz_da_brasa = 0.5
	# Cigarro parado quase nao brilha: um anel laranja debaixo da cinza. E a
	# puxada que acende.
	brasa_parada = 0.45
	# O cigarro e o da abertura, na rua.
	na_rua = true


## No corpo, a mao vai para a FRENTE da boca (ver `Corpo.alvo_da_pega`): a pega
## a dois centimetros e meio dos labios, que e o filtro entre os dedos.
func montar(quem: Corpo, semente: int) -> void:
	super(quem, semente)
	if quem != null:
		quem.alvo_da_pega = ALVO_NA_BOCA


## Mais aneis que a blunt: dois na emenda do filtro (o degrau) e tres no anel
## tostado junto da brasa, onde a cor de vertice escurece.
func _aneis_do_papel(lp: float) -> PackedFloat32Array:
	var xs := PackedFloat32Array([0.0, 0.004])
	if lp > FILTRO + 0.002:
		xs.append_array([FILTRO - 0.0001, FILTRO + 0.0001])
	var fim_liso := maxf(xs[xs.size() - 1] + 0.001, lp - tostado * 1.6)
	var meio := (xs[xs.size() - 1] + fim_liso) * 0.5
	if meio > xs[xs.size() - 1] + 0.004:
		xs.append(meio)
	for x: float in [fim_liso, lp - tostado * 0.6, lp]:
		if x > xs[xs.size() - 1] + 0.0002:
			xs.append(x)
	return xs


func _raio(i: int, x: float) -> float:
	var r := raio + (DEGRAU if x < FILTRO else 0.0)
	return r * (1.0 + _torto[mini(i, _torto.size() - 1)].x)
