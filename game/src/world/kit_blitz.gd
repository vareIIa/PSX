## Pecas de uma blitz: cone, placa, bollard, giroflex e o adesivo da viatura.
##
## Geometria procedural no mesmo estilo do KitModular — caixas e cones PSX,
## materiais ja carregados pela cidade. Nada de asset novo: a leitura vem da
## cor (laranja/branco do cone, amarelo do bollard, R/B do giroflex).
class_name KitBlitz
extends RefCounted

const MAT_METAL := "res://resources/materials/mat_metal.tres"
const MAT_CONCRETO := "res://resources/materials/mat_concreto.tres"
const MAT_FAIXA := "res://resources/materials/mat_asfalto_faixa.tres"


## Cone de transito laranja com faixas brancas e base quadrada. Altura ~0,7 m,
## base em y = 0.
##
## Material da tinta de pista, e nao o metal: com o metal o laranja saia marrom
## quase preto na nevoa da noite, e o cone e a unica peca da blitz que precisa
## ler de longe. A tinta de pista e a mesma do zebrado, que le.
static func cone_transito() -> MeshInstance3D:
	var dados := PSXMesh.dados_vazios()
	var corpo := PSXMesh.cone_dados(0.04, 0.22, 0.68, 6, 2,
		Color(1.0, 0.42, 0.12), Color(0.95, 0.38, 0.10))
	PSXMesh.acumular(dados, corpo, Transform3D.IDENTITY)
	for y_faixa: float in [0.22, 0.42]:
		var anel := PSXMesh.box_dados(Vector3(0.34, 0.06, 0.34), 0.8, 2.0,
			Color(0.92, 0.92, 0.88))
		PSXMesh.acumular(dados, anel,
			Transform3D(Basis.IDENTITY, Vector3(0.0, -y_faixa, 0.0)))
	var base := PSXMesh.box_dados(Vector3(0.42, 0.04, 0.42), 0.8, 2.0,
		Color(0.12, 0.12, 0.12))
	PSXMesh.acumular(dados, base, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.66, 0.0)))
	var mi := MeshInstance3D.new()
	mi.name = "Cone"
	mi.mesh = PSXMesh.dados_para_mesh(dados)
	mi.material_override = load(MAT_FAIXA)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A malha tem o bico na origem e cresce para baixo.
	mi.position = Vector3(0.0, 0.68, 0.0)
	return mi


## Bollard / inflavel amarelo DIRECAO SEGURA — caixa alta com placa.
static func bollard() -> MeshInstance3D:
	var dados := PSXMesh.dados_vazios()
	var corpo := PSXMesh.box_dados(Vector3(0.55, 1.6, 0.35), 0.8, 2.0,
		Color(0.95, 0.82, 0.12))
	PSXMesh.acumular(dados, corpo, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.8, 0.0)))
	var placa := PSXMesh.box_dados(Vector3(0.48, 0.55, 0.04), 0.8, 2.0,
		Color(0.12, 0.18, 0.45))
	PSXMesh.acumular(dados, placa, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.05, 0.2)))
	var mi := MeshInstance3D.new()
	mi.name = "Bollard"
	mi.mesh = PSXMesh.dados_para_mesh(dados)
	mi.material_override = load(MAT_CONCRETO)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Placa branca baixa de sinalizacao de blitz.
static func placa() -> MeshInstance3D:
	var dados := PSXMesh.dados_vazios()
	var mastro := PSXMesh.box_dados(Vector3(0.05, 1.1, 0.05), 0.8, 2.0,
		Color(0.45, 0.45, 0.48))
	PSXMesh.acumular(dados, mastro, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.55, 0.0)))
	var face := PSXMesh.box_dados(Vector3(0.55, 0.4, 0.04), 0.8, 2.0,
		Color(0.92, 0.92, 0.9))
	PSXMesh.acumular(dados, face, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.05, 0.0)))
	var disco := PSXMesh.box_dados(Vector3(0.28, 0.28, 0.03), 0.8, 2.0,
		Color(0.85, 0.15, 0.12))
	PSXMesh.acumular(dados, disco, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.05, 0.04)))
	var mi := MeshInstance3D.new()
	mi.name = "Placa"
	mi.mesh = PSXMesh.dados_para_mesh(dados)
	mi.material_override = load(MAT_METAL)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Par de luzes R/B no teto da viatura. Pisca sozinho (`Giroflex`).
static func giroflex() -> Giroflex:
	var raiz := Giroflex.new()
	raiz.name = "Giroflex"
	# Barra: a base preta que segura as duas lentes.
	var barra := MeshInstance3D.new()
	barra.mesh = PSXMesh.box(Vector3(0.62, 0.06, 0.2), 0.8, 2.0, Color(0.1, 0.1, 0.1))
	barra.material_override = load(MAT_FAIXA)
	barra.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(barra)
	for item: Array in [["R", Color(1.0, 0.12, 0.1), -0.18], ["B", Color(0.15, 0.35, 1.0), 0.18]]:
		var luz := OmniLight3D.new()
		luz.name = item[0]
		luz.light_color = item[1]
		luz.light_energy = 3.5
		luz.omni_range = 8.0
		luz.omni_attenuation = 1.2
		luz.shadow_enabled = false
		luz.position = Vector3(item[2], 0.15, 0.0)
		raiz.add_child(luz)
		var bola := MeshInstance3D.new()
		bola.mesh = PSXMesh.box(Vector3(0.22, 0.1, 0.16), 0.8, 2.0, item[1])
		bola.material_override = load(MAT_FAIXA)
		bola.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bola.position = Vector3(item[2], 0.08, 0.0)
		raiz.add_child(bola)
	return raiz


## Faixas da viatura sobre a lataria branca: preta na linha da porta e vermelha
## fina embaixo, nos dois lados. Em 480x270 e isso que separa
## "viatura" de "sedan branco" — a primeira blitz tinha so o giroflex, de 12 cm.
static func adesivo_viatura(medidas: Dictionary) -> MeshInstance3D:
	var comp := float(medidas["comprimento"])
	var larg := float(medidas["largura"])
	var dados := PSXMesh.dados_vazios()
	for lado: float in [-1.0, 1.0]:
		var x := lado * (larg * 0.5 + 0.012)
		var preta := PSXMesh.box_dados(Vector3(0.02, 0.2, comp * 0.62), 0.8, 2.0,
			Color(0.07, 0.07, 0.08))
		PSXMesh.acumular(dados, preta, Transform3D(Basis.IDENTITY, Vector3(x, 0.66, 0.05)))
		var vermelha := PSXMesh.box_dados(Vector3(0.02, 0.05, comp * 0.62), 0.8, 2.0,
			Color(0.75, 0.08, 0.06))
		PSXMesh.acumular(dados, vermelha, Transform3D(Basis.IDENTITY, Vector3(x, 0.52, 0.05)))
	var mi := MeshInstance3D.new()
	mi.name = "Adesivo"
	mi.mesh = PSXMesh.dados_para_mesh(dados)
	mi.material_override = load(MAT_FAIXA)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
