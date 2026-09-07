## Geometria mapeada em CELULA de atlas.
##
## Por que isto existe
## -------------------
## `KitModular.caixa` mapeia UV POR METRO sobre a textura inteira. Isso e certo
## para parede de reboco e chao de asfalto, que sao texturas de tile: a peca
## pega um pedaco qualquer e ninguem repara.
##
## E errado para atlas. Numa textura em que cada quadrado de 32 pixels e um
## objeto diferente, "um pedaco qualquer" significa que o sofa sai vestindo o
## gramado do jogo de futebol e a mesa sai com um saquinho estampado no tampo —
## os dois defeitos aconteceram de verdade na casa da fumaca, e nenhum dos dois
## da erro, aviso ou assercao vermelha. Os dois so existem como imagem errada.
##
## Aqui cada peca DIZ que celula quer, e a UV e remapeada para dentro dela.
##
## Repeticao
## ---------
## Uma celula tem 32 pixels. Esticada numa parede de sete metros, da quatro
## pixels por metro, que e borrao. `painel_repetido` resolve do jeito que o PS1
## resolvia: nao com UV maior que 1 — que num atlas mostra a celula vizinha —
## mas com VARIOS quads de um metro, cada um com a celula inteira dentro. Custa
## dois triangulos por metro quadrado e mantem os 32 pixels por metro.
class_name AtlasKit
extends RefCounted


## Uma face plana com uma celula do atlas.
static func face(sup: Dictionary, material: StringName, tamanho: Vector2,
		xform: Transform3D, celula: Vector2i, cor: Color = Color.WHITE) -> void:
	var d := PSXMesh.placa_dados(tamanho, 100.0, Color.WHITE)
	remapear(d, celula)
	if not sup.has(material):
		sup[material] = PSXMesh.dados_vazios()
	PSXMesh.acumular_tingido(sup[material], d, xform, cor)


## Uma superficie grande, feita de quads de `passo` metros com a celula inteira
## em cada um. Ver o cabecalho: e assim que se repete uma celula de atlas.
static func painel_repetido(sup: Dictionary, material: StringName,
		tamanho: Vector2, xform: Transform3D, celula: Vector2i,
		passo: float = 1.0, cor: Color = Color.WHITE) -> void:
	var colunas := maxi(1, roundi(tamanho.x / passo))
	var linhas := maxi(1, roundi(tamanho.y / passo))
	var w := tamanho.x / float(colunas)
	var h := tamanho.y / float(linhas)
	for lin in linhas:
		for col in colunas:
			var deslocamento := Vector3(
				-tamanho.x * 0.5 + w * (float(col) + 0.5),
				-tamanho.y * 0.5 + h * (float(lin) + 0.5), 0.0)
			face(sup, material, Vector2(w, h),
				xform * Transform3D(Basis(), deslocamento), celula, cor)


## Caixa com celula por face, e sem a base, que ninguem ve.
##
## `frente` e `topo` existem porque quase todo movel tem faces diferentes: o
## rack e madeira em volta e madeira em cima, mas a caixa de som e cone na
## frente e compensado nos lados.
static func caixa(sup: Dictionary, material: StringName, centro: Vector3,
		tamanho: Vector3, celula: Vector2i, cor: Color = Color.WHITE,
		giro: float = 0.0, frente: Vector2i = Vector2i(-1, -1),
		topo: Vector2i = Vector2i(-1, -1)) -> void:
	var h := tamanho * 0.5
	var base := Basis(Vector3.UP, giro)
	var c_frente := celula if frente.x < 0 else frente
	var c_topo := celula if topo.x < 0 else topo
	face(sup, material, Vector2(tamanho.x, tamanho.y),
		Transform3D(base, centro + base * Vector3(0, 0, h.z)), c_frente, cor)
	face(sup, material, Vector2(tamanho.x, tamanho.y),
		Transform3D(base * Basis(Vector3.UP, PI),
			centro - base * Vector3(0, 0, h.z)), celula, cor)
	face(sup, material, Vector2(tamanho.z, tamanho.y),
		Transform3D(base * Basis(Vector3.UP, PI * 0.5),
			centro + base * Vector3(h.x, 0, 0)), celula, cor)
	face(sup, material, Vector2(tamanho.z, tamanho.y),
		Transform3D(base * Basis(Vector3.UP, -PI * 0.5),
			centro - base * Vector3(h.x, 0, 0)), celula, cor)
	face(sup, material, Vector2(tamanho.x, tamanho.z),
		Transform3D(base * Basis(Vector3.RIGHT, -PI * 0.5),
			centro + Vector3(0, h.y, 0)), c_topo, cor)


## Caixa em angulo livre, para o que nao esta alinhado com a parede. Esta tem
## fundo: cabo e mangueira sao vistos de todos os lados.
static func caixa_livre(sup: Dictionary, material: StringName, centro: Vector3,
		tamanho: Vector3, base: Basis, celula: Vector2i,
		cor: Color = Color.WHITE, topo: Vector2i = Vector2i(-1, -1)) -> void:
	var h := tamanho * 0.5
	var c_topo := celula if topo.x < 0 else topo
	face(sup, material, Vector2(tamanho.x, tamanho.y),
		Transform3D(base, centro + base * Vector3(0, 0, h.z)), celula, cor)
	face(sup, material, Vector2(tamanho.x, tamanho.y),
		Transform3D(base * Basis(Vector3.UP, PI),
			centro - base * Vector3(0, 0, h.z)), celula, cor)
	face(sup, material, Vector2(tamanho.z, tamanho.y),
		Transform3D(base * Basis(Vector3.UP, PI * 0.5),
			centro + base * Vector3(h.x, 0, 0)), celula, cor)
	face(sup, material, Vector2(tamanho.z, tamanho.y),
		Transform3D(base * Basis(Vector3.UP, -PI * 0.5),
			centro - base * Vector3(h.x, 0, 0)), celula, cor)
	face(sup, material, Vector2(tamanho.x, tamanho.z),
		Transform3D(base * Basis(Vector3.RIGHT, -PI * 0.5),
			centro + base * Vector3(0, h.y, 0)), c_topo, cor)
	face(sup, material, Vector2(tamanho.x, tamanho.z),
		Transform3D(base * Basis(Vector3.RIGHT, PI * 0.5),
			centro - base * Vector3(0, h.y, 0)), celula, cor)


## Um tubo fino de um ponto a outro: cabo de video, mangueira de irrigacao,
## duto. E uma caixa girada, e nao um cilindro — a esta distancia a diferenca
## nao existe e o cilindro custaria dezesseis faces em vez de seis.
static func tubo(sup: Dictionary, material: StringName, de: Vector3,
		para: Vector3, grossura: float, celula: Vector2i,
		cor: Color = Color.WHITE) -> void:
	var vetor := para - de
	var comp := vetor.length()
	if comp < 0.02:
		return
	var direcao := vetor / comp
	var eixo := Vector3.RIGHT.cross(direcao)
	var base := Basis()
	if eixo.length_squared() > 0.000001:
		base = Basis(eixo.normalized(), Vector3.RIGHT.angle_to(direcao))
	caixa_livre(sup, material, de + vetor * 0.5,
		Vector3(comp, grossura, grossura), base, celula, cor)


## Uma placa deitada no chao ou num tampo, com uma celula do atlas.
static func deitado(sup: Dictionary, material: StringName, onde: Vector3,
		tamanho: Vector2, celula: Vector2i, giro: float,
		cor: Color = Color.WHITE) -> void:
	var d := PSXMesh.placa_dados(tamanho, 100.0, Color.WHITE)
	remapear(d, celula)
	if not sup.has(material):
		sup[material] = PSXMesh.dados_vazios()
	PSXMesh.acumular_tingido(sup[material], d,
		Transform3D(Basis(Vector3.UP, giro) * Basis(Vector3.RIGHT, -PI * 0.5),
			onde + Vector3(0.0, 0.004, 0.0)), cor)


## Uma placa vertical que CEDE AO VENTO, presa pelo pe.
##
## O alfa do vertice carrega a rigidez, e por isso a folhagem nao pode usar
## `face`: `acumular_tingido` grava a cor inteira, alfa incluso, e a planta
## ficaria com o pe balancando junto com a copa — que le como cartaz solto no
## vento, e nao como planta enraizada no vaso.
static func folha_ao_vento(sup: Dictionary, material: StringName,
		tamanho: Vector2, xform: Transform3D, celula: Vector2i,
		cor: Color = Color.WHITE) -> void:
	var d := PSXMesh.placa_dados(tamanho, 100.0, Color.WHITE)
	remapear(d, celula)
	if not sup.has(material):
		sup[material] = PSXMesh.dados_vazios()
	var pe := xform.origin.y - tamanho.y * 0.5
	PSXMesh.acumular_flexivel(sup[material], d, xform, cor, pe,
		pe + tamanho.y, 0.0, 1.0)


## Puxa a UV de 0..1 para dentro da celula pedida.
static func remapear(d: Dictionary, celula: Vector2i) -> void:
	var r := Carroceria.uv(celula)
	var uvs: PackedVector2Array = d["uv"]
	for k in uvs.size():
		uvs[k] = r.position + uvs[k] * r.size
	d["uv"] = uvs
