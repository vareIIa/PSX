## Todo shader que o jogo ja usou continua compilado ate o fim da sessao
## (PLANO_DESEMPENHO_E_HORIZONTE, Fase 2).
##
## O defeito
## ---------
## No Godot um shader vive enquanto tiver dono. O prop que cria o proprio
## material — `ShaderMaterial.new()` com `load("res://shaders/...")`, ou
## `StandardMaterial3D.new()` (36 lugares no codigo: convidado, TV, sinuca,
## fumaca, prateleira do mercado...) — e o unico dono dele. Quando o ultimo
## chunk com aquele prop sai do alcance, o shader sai junto, e o proximo chunk
## com o mesmo prop compila tudo de novo. Medido em 24/09/2026 dirigindo pela
## avenida: quadros de 50 a 70 ms que voltavam iguais na SEGUNDA volta do mesmo
## trecho, com 29 a 68 pipelines recompiladas. Com tudo preso, a segunda volta
## caiu para 11 a 18 pipelines e o pior quadro de 80 para 53 ms
## (`tests/bancada_fps_dirigir.gd --duas-voltas --segurar-shaders`).
##
## E o mesmo defeito do `RastroPneu` (memoria "clear_surfaces solta o
## material"), so que espalhado por todo prop que monta material na hora.
##
## O desenho
## ---------
##   arquivos   todo `res://shaders/*.gdshader`, carregado uma vez e preso: o
##              `load()` do prop passa a achar o shader no cache.
##   gerados    material que o MOTOR transforma em shader (Standard, ORM,
##              particula) e guardado UM por assinatura — as opcoes que mudam o
##              shader (modo, bandeira, qual textura existe), e nao cor e
##              numero, que sao so parametro. Um guardado segura o shader de
##              todos os iguais, sem guardar cada instancia.
##
## Quem chama e o `ChunkManager`, uma vez, no `_ready`.
class_name ReservaDeShaders
extends RefCounted

const PASTA := "res://shaders"

## nome do arquivo ou assinatura -> recurso preso
static var _presos := {}
static var _pendentes: Array[Node] = []
static var _ligada := false
## Custo acumulado da guarda, em ms. Para bancada.
static var custo_ms := 0.0
## Depois de `marcar()`, quem trouxe um shader que a reserva ainda nao tinha:
## "Material <- dono". E o que o aquecimento do titulo deixou de fora.
static var novos: PackedStringArray = []
static var _marcado := false


## Daqui em diante, anota em `novos` todo shader que chegar pela primeira vez.
static func marcar() -> void:
	_marcado = true
	novos.clear()


static func iniciar(arvore: SceneTree) -> void:
	if _ligada:
		return
	_ligada = true
	# Sem RenderingDevice (PS1 STYLE, Compatibility) os shaders do MODERNO nao
	# precisam existir, e carregar todos poderia acordar erro de um que so
	# compila no Vulkan. A guarda do que ja esta em uso continua valendo.
	if RenderingServer.get_rendering_device() != null:
		for arq in DirAccess.get_files_at(PASTA):
			var a := arq.trim_suffix(".remap")
			if a.ends_with(".gdshader"):
				var s := load(PASTA + "/" + a)
				if s != null:
					_presos[a] = s
	# O material e posto no `_ready` do prop, depois do node_added: a guarda
	# le no comeco do quadro seguinte.
	arvore.node_added.connect(func(no: Node) -> void:
		if no is GeometryInstance3D:
			_pendentes.append(no))
	arvore.process_frame.connect(func() -> void: _guardar_pendentes())


static func presos() -> int:
	return _presos.size()


static func _guardar_pendentes() -> void:
	if _pendentes.is_empty():
		return
	var t := Time.get_ticks_usec()
	var lista := _pendentes
	_pendentes = []
	for g: Variant in lista:
		if is_instance_valid(g):
			_guardar_de(g as GeometryInstance3D)
	custo_ms += float(Time.get_ticks_usec() - t) / 1000.0


static func _guardar_de(g: GeometryInstance3D) -> void:
	var mats: Array[Material] = [g.material_override, g.material_overlay]
	var mi := g as MeshInstance3D
	if mi != null:
		for i in mi.get_surface_override_material_count():
			mats.append(mi.get_surface_override_material(i))
		if mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				mats.append(mi.mesh.surface_get_material(i))
	var gp := g as GPUParticles3D
	if gp != null:
		mats.append(gp.process_material)
		for i in gp.draw_passes:
			var m := gp.get_draw_pass_mesh(i)
			if m != null:
				for s in m.get_surface_count():
					mats.append(m.surface_get_material(s))
	for m in mats:
		while m != null:
			var chave := _guardar(m)
			if _marcado and not chave.is_empty():
				novos.append("%s <- %s" % [chave.get_slice("|", 0), _dono(g)])
			m = m.next_pass


## O primeiro no com script subindo a partir de `g`: quem montou a peca.
static func _dono(g: Node) -> String:
	var no := g
	while no != null:
		var s := no.get_script() as Script
		if s != null:
			var nome := String(s.get_global_name())
			return nome if not nome.is_empty() else s.resource_path.get_file()
		no = no.get_parent()
	return g.get_class()


## Devolve a chave nova, se esta foi a primeira vez; vazio se ja estava preso.
static func _guardar(m: Material) -> String:
	# ShaderMaterial feito em codigo segura o shader pelo ARQUIVO: os de
	# `PASTA` ja estao presos; um de fora dela e preso aqui, pelo caminho.
	# Shader montado em codigo (`Shader.new()`) nao tem o que prender: cada um
	# e outro. Material de arquivo ja tem dono no cache de quem o carregou
	# (ChunkManager, Interiores).
	if m is ShaderMaterial:
		var sh := (m as ShaderMaterial).shader
		if sh != null and not sh.resource_path.is_empty() 				and not _presos.has(sh.resource_path.get_file()) 				and not _presos.has(sh.resource_path):
			_presos[sh.resource_path] = sh
			return "ShaderMaterial %s" % sh.resource_path
		return ""
	if not m.resource_path.is_empty():
		return ""
	if not (m is BaseMaterial3D or m is ParticleProcessMaterial):
		return ""
	var chave := _assinatura(m)
	if not _presos.has(chave):
		_presos[chave] = m
		return chave
	return ""


## As opcoes que decidem o shader gerado: toda bandeira e todo modo (bool e
## int) e QUAIS texturas existem. Cor, numero e a textura em si sao parametro.
static func _assinatura(m: Material) -> String:
	var partes := PackedStringArray([m.get_class()])
	for p: Dictionary in m.get_property_list():
		if not (int(p["usage"]) & PROPERTY_USAGE_STORAGE):
			continue
		var tipo := int(p["type"])
		if tipo == TYPE_BOOL or tipo == TYPE_INT:
			partes.append("%s=%s" % [p["name"], m.get(p["name"])])
		elif tipo == TYPE_OBJECT and p["name"] != &"next_pass":
			partes.append("%s:%d" % [p["name"], 1 if m.get(p["name"]) != null else 0])
	return "|".join(partes)
