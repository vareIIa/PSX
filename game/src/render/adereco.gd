## O que uma mao segura: aqui, o cigarro e o celular da abertura.
##
## Por que nao e o baseado do Convidado
## ------------------------------------
## Porque um cigarro nao e um baseado. O da casa da fumaca tem treze centimetros
## de papel torto e uma brasa que so acende quando alguem traga; o da abertura
## tem sete, queima sozinho o tempo todo e termina o plano virando bituca no
## chao. Sao dois objetos com dois ciclos de vida, e um arquivo so para os dois
## seria um arquivo de `if`.
##
## O que eles compartilham de verdade e a FORMA de existir na mao, e e isso que
## mora aqui: `bastao` desenha um paralelepipedo com a mesma celula do atlas nas
## quatro faces longas. O Convidado usa esta funcao; a copia particular que ele
## tinha saiu.
##
## Volume, e nao quad cruzado
## --------------------------
## Um quad so tem luz pela normal, e a normal de quem esta com o braco ao lado
## do corpo aponta para o chao — foi assim que o baseado saiu preto em todas as
## capturas da casa. Um bastao de oito milimetros tem sempre uma face virada
## para alguma coisa, e custa doze triangulos.
##
## Onde ele e pendurado
## --------------------
## Num filho do BoneAttachment3D, nunca no proprio. O BoneAttachment3D reescreve
## a propria transformada com a pose do osso a cada quadro, e qualquer posicao
## escrita nele e apagada no quadro seguinte. `pendurar_em` faz essa conta e
## devolve o no certo; quem chama nao precisa saber disso.
class_name Adereco
extends Node3D

enum Tipo { CIGARRO, CELULAR }

const MATERIAL := "res://resources/materials/mat_casa_recorte.tres"
const MATERIAL_BRASA := "res://resources/materials/mat_casa_brasa.tres"
const MATERIAL_TELA := "res://resources/materials/mat_celular_tela.tres"
const MATERIAL_FUMACA := "res://resources/materials/mat_fumaca_baseado.tres"

## Celulas do casa_atlas. O papel do cigarro e a MESMA do baseado — e papel
## branco nos dois casos, e uma celula nova custaria 32 px de atlas para
## desenhar de novo o que ja esta la.
const C_PAPEL := Vector2i(0, 3)
## Plastico escuro. E a celula do console de video game, que e exatamente a
## textura que um telefone daquela epoca tem: plastico fosco arranhado.
const C_PLASTICO := Vector2i(3, 1)
## Tela. A celula da TV, que ja e uma tela — so muda o tamanho e a cor da
## emissao.
const C_TELA := Vector2i(0, 1)

# --- medidas, em metros -----------------------------------------------------
## Cigarro inteiro e bituca. Sete centimetros e o que sobra de um cigarro fumado
## pela metade, e tres e o que se joga fora — a diferenca entre os dois e o
## unico jeito de o plano final ler como "ele fumou isso" em vez de "ele largou
## um cigarro novo no chao".
const CIGARRO_COMPRIMENTO := 0.072
const CIGARRO_BITUCA := 0.031
const CIGARRO_GROSSURA := 0.0085

## Telefone de 1998: barra, tela pequena em cima, teclado embaixo. Nao e um
## retangulo de vidro — se fosse, o jogo deixaria de ser do ano que e.
const FONE := Vector3(0.049, 0.104, 0.017)
const FONE_TELA := Vector2(0.037, 0.030)
## Altura do centro da tela dentro do corpo do aparelho.
const FONE_TELA_Y := 0.028

## Alcance da luz da brasa e da tela. Curtos: sao duas fontes de centimetros, e
## o que elas iluminam e uma mao e um queixo, nao um comodo.
const ALCANCE_BRASA := 0.9
const ALCANCE_TELA := 0.62

## Densidade da coluna de fumaca parada e no auge da tragada. A de baixo nao e
## zero de proposito: cigarro aceso solta fumaca sozinho, e uma coluna que so
## existe quando alguem traga le como efeito, nao como cigarro.
const FUMACA_PARADA := 0.35
const FUMACA_TRAGADA := 1.5

var tipo: Tipo = Tipo.CIGARRO

## De 0 a 1. Na brasa e quanto o cigarro esta queimando agora; na tela e quanto
## o visor esta aceso. Escrever aqui acende a luz, a emissao e a fumaca juntas —
## quem usa nao precisa saber que sao tres coisas.
var brilho: float = 0.0:
	set(valor):
		brilho = clampf(valor, 0.0, 1.0)
		_aplicar_brilho()

var _luz: OmniLight3D
var _emissivo: ShaderMaterial
var _fumaca: MeshInstance3D
var _material_fumaca: ShaderMaterial
var _energia_base: float = 0.0
var _emissao_base: float = 0.0


# --- montagem ---------------------------------------------------------------

## Monta o adereco. `bituca` encurta o cigarro para o que sobra no fim.
func montar(qual: Tipo, bituca: bool = false) -> void:
	tipo = qual
	match tipo:
		Tipo.CIGARRO:
			_montar_cigarro(bituca)
		Tipo.CELULAR:
			_montar_celular()
	_aplicar_brilho()


func _montar_cigarro(bituca: bool) -> void:
	var comprimento := CIGARRO_BITUCA if bituca else CIGARRO_COMPRIMENTO
	var g := CIGARRO_GROSSURA

	var dados := PSXMesh.dados_vazios()
	bastao(dados, Vector3(comprimento, g, g), Vector3.ZERO, C_PAPEL,
		Color(0.98, 0.96, 0.90))
	var papel := MeshInstance3D.new()
	papel.name = "Papel"
	papel.mesh = PSXMesh.dados_para_mesh(dados)
	papel.material_override = load(MATERIAL) as Material
	papel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(papel)

	# A brasa e um pedaco a parte, no material de emissao, para poder acender
	# sem acender o cigarro inteiro. Ela avanca meio milimetro alem da ponta:
	# encaixada rente, o dither come ela e a ponta so fica mais clara.
	var d_brasa := PSXMesh.dados_vazios()
	bastao(d_brasa, Vector3(0.016, g * 1.25, g * 1.25),
		Vector3(comprimento * 0.5 + 0.006, 0.0, 0.0), C_PAPEL, Color.WHITE)
	var ponta := MeshInstance3D.new()
	ponta.name = "Brasa"
	ponta.mesh = PSXMesh.dados_para_mesh(d_brasa)
	_emissivo = (load(MATERIAL_BRASA) as ShaderMaterial).duplicate() as ShaderMaterial
	_emissao_base = float(_emissivo.get_shader_parameter("emission_energy"))
	ponta.material_override = _emissivo
	ponta.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ponta)

	_luz = OmniLight3D.new()
	_luz.name = "LuzBrasa"
	_luz.omni_range = ALCANCE_BRASA
	_luz.light_color = Color(1.0, 0.46, 0.16)
	_luz.shadow_enabled = false
	_luz.position = Vector3(comprimento * 0.5 + 0.01, 0.0, 0.0)
	add_child(_luz)
	_energia_base = 0.95

	_montar_fumaca(_luz.position)


## A coluna que sobe da brasa.
##
## Nao e filha do cigarro, e `top_level`: fumaca sobe na vertical por definicao,
## e presa ao objeto ela deitaria de lado toda vez que a mao girasse. O no
## ignora a transformada do pai e so a POSICAO e copiada a cada quadro — e a
## mesma solucao que o Convidado usa, pelo mesmo motivo.
func _montar_fumaca(onde: Vector3) -> void:
	var dados := PSXMesh.dados_vazios()
	for giro: float in [0.0, PI * 0.5]:
		var d := PSXMesh.placa_dados(Vector2(0.11, 0.36), 0.2,
			Color(1.0, 1.0, 1.0, 0.8))
		PSXMesh.acumular(dados, d,
			Transform3D(Basis(Vector3.UP, giro), Vector3(0.0, 0.18, 0.0)))
	_fumaca = MeshInstance3D.new()
	_fumaca.name = "Fumaca"
	_fumaca.mesh = PSXMesh.dados_para_mesh(dados)
	_material_fumaca = (load(MATERIAL_FUMACA) as ShaderMaterial).duplicate() as ShaderMaterial
	_fumaca.material_override = _material_fumaca
	_fumaca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fumaca.top_level = true
	add_child(_fumaca)
	_fumaca.position = onde
	set_process(true)


func _montar_celular() -> void:
	var dados := PSXMesh.dados_vazios()
	var caixa := PSXMesh.box_dados(FONE, 100.0, 100.0, Color.WHITE)
	_remapear(caixa, C_PLASTICO)
	# Cinza bem escuro, e nao preto. Plastico de telefone daquela epoca nunca era
	# preto de verdade, e preto puro no PS1 vira um buraco na silhueta.
	PSXMesh.acumular_tingido(dados, caixa, Transform3D(),
		Color(0.26, 0.27, 0.30))
	var corpo := MeshInstance3D.new()
	corpo.name = "Corpo"
	corpo.mesh = PSXMesh.dados_para_mesh(dados)
	corpo.material_override = load(MATERIAL) as Material
	corpo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(corpo)

	# A tela vai num quad a um milimetro da face, e nao numa face do corpo: ela
	# precisa de outro material — o que emite — e uma caixa so tem um.
	var d_tela := PSXMesh.placa_dados(FONE_TELA, 100.0, Color.WHITE)
	_remapear(d_tela, C_TELA)
	var tela := MeshInstance3D.new()
	tela.name = "Tela"
	tela.mesh = PSXMesh.dados_para_mesh(d_tela)
	_emissivo = (load(MATERIAL_TELA) as ShaderMaterial).duplicate() as ShaderMaterial
	_emissao_base = float(_emissivo.get_shader_parameter("emission_energy"))
	tela.material_override = _emissivo
	tela.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tela)
	tela.position = Vector3(0.0, FONE_TELA_Y, FONE.z * 0.5 + 0.001)

	# A luz da tela e o motivo de o telefone existir no plano. Sem ela o aparelho
	# e um retangulo escuro na mao; com ela o queixo de quem esta olhando fica
	# verde, e e isso que conta que ele esta mexendo no celular.
	_luz = OmniLight3D.new()
	_luz.name = "LuzTela"
	_luz.omni_range = ALCANCE_TELA
	_luz.omni_attenuation = 1.4
	_luz.light_color = Color(0.66, 0.92, 0.72)
	_luz.shadow_enabled = false
	_luz.position = Vector3(0.0, FONE_TELA_Y, FONE.z * 0.5 + 0.06)
	add_child(_luz)
	_energia_base = 1.35


## Joga a UV de 0..1 da malha dentro da celula do atlas.
static func _remapear(d: Dictionary, celula: Vector2i) -> void:
	var r := Carroceria.uv(celula)
	var uvs: PackedVector2Array = d["uv"]
	for k in uvs.size():
		uvs[k] = r.position + Vector2(clampf(uvs[k].x, 0.0, 1.0),
			clampf(uvs[k].y, 0.0, 1.0)) * r.size
	d["uv"] = uvs


func _process(_delta: float) -> void:
	# So a posicao. A rotacao fica de fora porque o no e `top_level` justamente
	# para nao herdar o giro da mao.
	if _fumaca != null:
		_fumaca.global_position = to_global(_luz.position)


func _aplicar_brilho() -> void:
	if _luz != null:
		# Fio baixo permanente mais o que a tragada acrescenta. Um cigarro que
		# apaga entre as tragadas nao e um cigarro aceso.
		_luz.light_energy = _energia_base * (0.28 + 0.72 * brilho)
	if _emissivo != null:
		_emissivo.set_shader_parameter("emission_energy",
			_emissao_base * (0.42 + 0.58 * brilho))
	if _material_fumaca != null:
		_material_fumaca.set_shader_parameter("densidade",
			lerpf(FUMACA_PARADA, FUMACA_TRAGADA, brilho))


# --- uso --------------------------------------------------------------------

## Pendura o adereco num osso e devolve o no em que ele foi posto.
##
## O deslocamento vai num FILHO do BoneAttachment3D. O BoneAttachment3D reescreve
## a propria transformada com a pose do osso a cada quadro, entao posicao escrita
## nele dura um quadro e o objeto volta para a origem do osso — que no braco e o
## COTOVELO, e nao a mao.
static func pendurar_em(esqueleto: Skeleton3D, osso: int, quem: Node3D,
		punho: Vector3 = Vector3(0.0, -0.24, 0.07)) -> Node3D:
	var junta := BoneAttachment3D.new()
	junta.name = "Junta"
	esqueleto.add_child(junta)
	junta.bone_idx = osso
	var no := Node3D.new()
	no.name = "Punho"
	junta.add_child(no)
	no.position = punho
	no.add_child(quem)
	return no


## Um paralelepipedo com a mesma celula nas quatro faces longas. As duas pontas
## nao entram: um bastao de oito milimetros nunca mostra o topo.
static func bastao(dados: Dictionary, tamanho: Vector3, centro: Vector3,
		celula: Vector2i, cor: Color) -> void:
	var h := tamanho * 0.5
	var faces: Array[Array] = [
		[Vector2(tamanho.x, tamanho.y), Basis(), Vector3(0, 0, h.z)],
		[Vector2(tamanho.x, tamanho.y), Basis(Vector3.UP, PI), Vector3(0, 0, -h.z)],
		[Vector2(tamanho.x, tamanho.z), Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, h.y, 0)],
		[Vector2(tamanho.x, tamanho.z), Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, -h.y, 0)],
	]
	var r := Carroceria.uv(celula)
	for f: Array in faces:
		var d := PSXMesh.placa_dados(f[0], 100.0, Color.WHITE)
		var uvs: PackedVector2Array = d["uv"]
		for k in uvs.size():
			uvs[k] = r.position + uvs[k] * r.size
		d["uv"] = uvs
		PSXMesh.acumular_tingido(dados, d,
			Transform3D(f[1], centro + (f[2] as Vector3)), cor)
