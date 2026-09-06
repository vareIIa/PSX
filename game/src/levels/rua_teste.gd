## Rua de teste. Subúrbio japonês à noite, montado com o material novo.
##
## Serve para duas coisas. Provar que as texturas importadas leem bem sob o
## contrato PSX, e ser o ensaio do kit modular da Fase 3: tudo aqui sai de
## PSXMesh na grade de 2 m, com pivo no canto, exatamente como o kit vai exigir.
##
## Nao e conteudo final. Quando o ChunkManager existir, este arquivo vira
## gerador de chunk em vez de cena unica.
extends Node3D

const MAT := "res://resources/materials/mat_%s.tres"

# Medidas em metros, na grade de 2 m.
const COMPRIMENTO := 72.0
const LARGURA_RUA := 6.0
const LARGURA_CALCADA := 2.5
const ALTURA_MEIO_FIO := 0.16
const ALTURA_ANDAR := 3.0

const ESPACO_POSTE := 12.0

## ART-BIBLE secao 7 limita a 4 fontes dinamicas por chunk de 32 m. O teto duro
## do renderizador Compatibility e outro: 8 luzes por objeto. Entre poste, vitrine
## e maquina de venda, o alvo aqui e ficar perto de 4 por chunk e compensar a
## escassez com alcance maior, que e como o PS1 fazia de qualquer jeito.
const LUZ_POSTE_COR := Color("ffb763")
const LUZ_POSTE_ENERGIA := 3.6
const LUZ_POSTE_ALCANCE := 11.5

@onready var _geo: Node3D = $Geometria
@onready var _luzes: Node3D = $Luzes

var _mats: Dictionary[StringName, ShaderMaterial] = {}
var _tris: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	# Semente fixa: a rua tem que sair igual em toda captura, senao a comparacao
	# visual entre execucoes nao vale nada.
	_rng.seed = 19950909
	_carregar_materiais()
	_construir()
	var chunks := COMPRIMENTO / 32.0
	var por_chunk := _luzes.get_child_count() / chunks
	print("[rua_teste] %d triangulos, %d luzes (%.1f por chunk de 32 m)"
		% [_tris, _luzes.get_child_count(), por_chunk])
	if por_chunk > 8.0:
		push_warning("rua_teste: %.1f luzes por chunk, acima do razoavel" % por_chunk)


func _carregar_materiais() -> void:
	var nomes: Array[StringName] = [
		&"asfalto", &"asfalto_remendo", &"calcada", &"calcada_ladrilho", &"meio_fio",
		&"terra", &"concreto", &"concreto_sujo", &"azulejo", &"tijolo",
		&"metal_ondulado", &"metal_enferrujado", &"vitrine", &"maquina_venda",
		&"janela_acesa", &"janela_apagada", &"letreiro", &"metal", &"tabua",
	]
	for nome: StringName in nomes:
		var caminho := MAT % nome
		if not ResourceLoader.exists(caminho):
			push_error("rua_teste: material ausente %s" % caminho)
			continue
		_mats[nome] = load(caminho) as ShaderMaterial


# --- construcao -------------------------------------------------------------

func _construir() -> void:
	var meio := -COMPRIMENTO * 0.5
	var borda := LARGURA_RUA * 0.5

	# Leito da rua, com uma faixa de remendo assimetrica para quebrar a repeticao
	_plano("Asfalto", Vector2(LARGURA_RUA, COMPRIMENTO), &"asfalto",
		_deitado(Vector3(0.0, 0.0, meio)))
	_plano("Remendo", Vector2(2.0, 12.0), &"asfalto_remendo",
		_deitado(Vector3(-1.2, 0.012, -26.0)))

	for lado in [-1.0, 1.0]:
		var cx := borda + LARGURA_CALCADA * 0.5
		# Calcada
		_plano("Calcada%s" % lado, Vector2(LARGURA_CALCADA, COMPRIMENTO), &"calcada",
			_deitado(Vector3(lado * cx, ALTURA_MEIO_FIO, meio)))
		# Face vertical do meio-fio
		_plano("MeioFio%s" % lado, Vector2(COMPRIMENTO, ALTURA_MEIO_FIO), &"meio_fio",
			Transform3D(Basis(Vector3.UP, -lado * PI * 0.5),
				Vector3(lado * borda, ALTURA_MEIO_FIO * 0.5, meio)))

		# Muro de fundo continuo. Sem ele o vao entre predios vira faixa de ceu.
		_plano("MuroFundo%s" % lado, Vector2(COMPRIMENTO, 14.0), &"concreto_sujo",
			Transform3D(Basis(Vector3.UP, -lado * PI * 0.5),
				Vector3(lado * (borda + LARGURA_CALCADA + 0.6), 7.0, meio)))

		_construir_quarteirao(lado, borda + LARGURA_CALCADA)

	# Postes com fiacao, alternando de lado
	var z := -8.0
	var lado_poste := 1.0
	while z > -COMPRIMENTO + 6.0:
		_poste(Vector3(lado_poste * (borda + LARGURA_CALCADA - 0.5), 0.0, z), lado_poste)
		z -= ESPACO_POSTE
		lado_poste *= -1.0

	_colisao_chao(meio)


## Uma fileira de predios num lado da rua.
func _construir_quarteirao(lado: float, x_fachada: float) -> void:
	var fachadas: Array[StringName] = [&"azulejo", &"concreto", &"tijolo", &"concreto_sujo"]
	var z := -2.0
	var i := 0

	while z > -COMPRIMENTO + 4.0:
		var largura: float = [8.0, 10.0, 12.0][i % 3]
		var andares: int = [3, 4, 3, 4][i % 4]
		var mat := fachadas[i % fachadas.size()]

		if largura > -(z + COMPRIMENTO):
			largura = maxf(6.0, -(z + COMPRIMENTO))

		_predio(Vector3(lado * x_fachada, 0.0, z), largura, andares, mat, lado, i)
		z -= largura + 0.4
		i += 1


func _predio(pos: Vector3, largura: float, andares: int, mat_fachada: StringName,
		lado: float, indice: int) -> void:
	var altura := andares * ALTURA_ANDAR
	var centro_z := pos.z - largura * 0.5
	var giro := Basis(Vector3.UP, -lado * PI * 0.5)

	# Fachada voltada para a rua
	_plano("Fachada%d" % indice, Vector2(largura, altura), mat_fachada,
		Transform3D(giro, Vector3(pos.x, altura * 0.5, centro_z)))

	# Termino lateral, para o predio nao virar cartao de papel visto de lado
	_plano("Lateral%d" % indice, Vector2(3.0, altura), &"concreto_sujo",
		Transform3D(Basis(), Vector3(pos.x + lado * 1.5, altura * 0.5, pos.z)))

	# Terreo: vitrine acesa ou portao de metal fechado
	var tem_loja := indice % 2 == 0
	var mat_terreo: StringName = &"vitrine" if tem_loja else &"metal_ondulado"
	_plano("Terreo%d" % indice, Vector2(largura - 1.0, 2.2), mat_terreo,
		Transform3D(giro, Vector3(pos.x - lado * 0.06, 1.3, centro_z)))

	if tem_loja:
		# Letreiro vertical, elemento tipico da rua comercial japonesa
		_plano("Letreiro%d" % indice, Vector2(0.55, 2.4), &"letreiro",
			Transform3D(giro, Vector3(pos.x - lado * 0.32,
				3.4, centro_z + largura * 0.35)))

	# Janelas dos andares de cima, algumas acesas
	for andar in range(1, andares):
		var y := andar * ALTURA_ANDAR + 1.5
		var n := int(largura / 2.6)
		for j in n:
			var jz := centro_z - largura * 0.5 + 1.3 + j * 2.6
			var acesa := _rng.randf() < 0.34
			_plano("Jan%d_%d_%d" % [indice, andar, j], Vector2(1.1, 1.3),
				&"janela_acesa" if acesa else &"janela_apagada",
				Transform3D(giro, Vector3(pos.x - lado * 0.07, y, jz)))

	# Maquina de venda encostada na fachada, a cada tres predios
	if indice % 4 == 1:
		_maquina_venda(Vector3(pos.x - lado * 0.45, ALTURA_MEIO_FIO,
			centro_z + largura * 0.2), lado)


func _maquina_venda(pos: Vector3, lado: float) -> void:
	var giro := Basis(Vector3.UP, -lado * PI * 0.5)

	var corpo := MeshInstance3D.new()
	corpo.name = "MaquinaCorpo"
	var mesh := PSXMesh.box(Vector3(1.1, 1.9, 0.7), 1.0)
	corpo.mesh = mesh
	corpo.material_override = _mats.get(&"metal")
	corpo.transform = Transform3D(giro, pos + Vector3(0.0, 0.95, 0.0))
	corpo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_geo.add_child(corpo)
	_tris += PSXMesh.triangle_count(mesh)

	# A vitrine acesa e o que faz a maquina virar farol na rua escura
	_plano("MaquinaVitrine", Vector2(0.92, 1.5), &"maquina_venda",
		Transform3D(giro, pos + Vector3(-lado * 0.37, 1.05, 0.0)))

	var luz := OmniLight3D.new()
	luz.position = pos + Vector3(-lado * 0.9, 1.1, 0.0)
	luz.light_color = Color("eaf2ff")
	luz.light_energy = 2.2
	luz.omni_range = 5.5
	luz.shadow_enabled = false
	_luzes.add_child(luz)


func _poste(pos: Vector3, lado: float) -> void:
	var mastro := MeshInstance3D.new()
	mastro.name = "Poste"
	var mesh := PSXMesh.box(Vector3(0.22, 7.0, 0.22), 0.6)
	mastro.mesh = mesh
	mastro.material_override = _mats.get(&"meio_fio")
	mastro.position = pos + Vector3(0.0, 3.5, 0.0)
	mastro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_geo.add_child(mastro)
	_tris += PSXMesh.triangle_count(mesh)

	# Braco e luminaria projetados sobre a rua
	var braco := MeshInstance3D.new()
	braco.name = "PosteBraco"
	var bm := PSXMesh.box(Vector3(1.5, 0.1, 0.1), 1.0)
	braco.mesh = bm
	braco.material_override = _mats.get(&"metal")
	braco.position = pos + Vector3(-lado * 0.75, 6.6, 0.0)
	braco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_geo.add_child(braco)
	_tris += PSXMesh.triangle_count(bm)

	var luz := OmniLight3D.new()
	luz.position = pos + Vector3(-lado * 1.4, 6.4, 0.0)
	luz.light_color = LUZ_POSTE_COR
	luz.light_energy = LUZ_POSTE_ENERGIA
	luz.omni_range = LUZ_POSTE_ALCANCE
	luz.omni_attenuation = 1.1
	luz.shadow_enabled = false
	_luzes.add_child(luz)


# --- utilitarios ------------------------------------------------------------

## Transform que deita um plano no chao, virado para cima.
func _deitado(pos: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), pos)


func _plano(nome: String, tamanho: Vector2, mat: StringName, xform: Transform3D) -> void:
	var mesh := PSXMesh.plane(tamanho)
	var mi := MeshInstance3D.new()
	mi.name = nome
	mi.mesh = mesh
	mi.material_override = _mats.get(mat)
	mi.transform = xform
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_geo.add_child(mi)
	_tris += PSXMesh.triangle_count(mesh)


func _colisao_chao(meio_z: float) -> void:
	var corpo := StaticBody3D.new()
	corpo.name = "ColisaoChao"
	var largura_total := LARGURA_RUA + LARGURA_CALCADA * 2.0

	var caixas: Array[Array] = [
		# chao
		[Vector3(largura_total, 0.4, COMPRIMENTO), Vector3(0.0, -0.2, meio_z)],
		# paredes dos predios, dos dois lados
		[Vector3(0.4, 12.0, COMPRIMENTO),
			Vector3(-(LARGURA_RUA * 0.5 + LARGURA_CALCADA), 6.0, meio_z)],
		[Vector3(0.4, 12.0, COMPRIMENTO),
			Vector3(LARGURA_RUA * 0.5 + LARGURA_CALCADA, 6.0, meio_z)],
		# tampas das pontas
		[Vector3(largura_total, 12.0, 0.4), Vector3(0.0, 6.0, 0.4)],
		[Vector3(largura_total, 12.0, 0.4), Vector3(0.0, 6.0, -COMPRIMENTO - 0.4)],
	]
	for caixa: Array in caixas:
		var forma := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = caixa[0]
		forma.shape = box
		forma.position = caixa[1]
		corpo.add_child(forma)
	add_child(corpo)
