## Autoload. Entra e sai de interiores sem tela de carregamento.
##
## A promessa da Fase 4 e que a porta abra e o jogador entre, sem corte. O truque
## tem tres partes:
##
##   1. O interior e construido numa thread, no mesmo formato do chunk.
##   2. A construcao comeca junto com a animacao da porta, que dura 1,2 s.
##   3. Os chunks da rua ficam carregados, so escondidos, entao sair e imediato.
##
## Manter a cidade na memoria custa uns 48 MB e paga com uma saida instantanea.
## Descarregar e recarregar levaria os mesmos 49 chunks de volta pela fila.
extends Node

## Interiores vivem bem acima da cidade. Separar por espaco em vez de por cena
## evita trocar de arvore, que e o que faria a rua ter de recarregar na volta.
const DESLOCAMENTO := Vector3(0.0, 2000.0, 0.0)

## Duracao da abertura da porta. E o orcamento de tempo da construcao.
const ABERTURA := 1.2

const MAT_DIR := "res://resources/materials/mat_%s.tres"

signal entrou()
signal saiu()

var dentro: bool = false

var _raiz: Node3D
var _no: Node3D
var _retorno := Transform3D()
var _tarefa: int = -1
var _dados: Dictionary = {}
var _mutex := Mutex.new()
var _pronto_em: float = 0.0
var _materiais: Dictionary[StringName, ShaderMaterial] = {}


func _ready() -> void:
	set_process(false)


## Comeca a entrada. `retorno` e para onde o jogador volta ao sair.
func entrar(semente: int, retorno: Transform3D) -> void:
	if dentro or _tarefa >= 0:
		return
	_retorno = retorno
	_pronto_em = float(Time.get_ticks_msec()) / 1000.0 + ABERTURA
	_dados = {}
	_tarefa = WorkerThreadPool.add_task(_construir.bind(semente), false, "interior")
	set_process(true)


func sair() -> void:
	if not dentro:
		return
	dentro = false

	var jogador := get_tree().get_first_node_in_group(&"player") as Node3D
	if jogador != null:
		jogador.global_transform = _retorno
		if jogador.has_method("zerar_velocidade"):
			jogador.call("zerar_velocidade")

	if _no != null:
		_no.queue_free()
		_no = null

	_mostrar_cidade(true)
	_liberar_ambiente()
	saiu.emit()


func _exit_tree() -> void:
	if _tarefa >= 0:
		WorkerThreadPool.wait_for_task_completion(_tarefa)
		_tarefa = -1
	if _no != null and is_instance_valid(_no):
		_no.free()
		_no = null
	_dados.clear()
	_materiais.clear()


func _construir(semente: int) -> void:
	var d := InteriorBuilder.construir(semente)
	_mutex.lock()
	_dados = d
	_mutex.unlock()


func _process(_delta: float) -> void:
	if _tarefa < 0:
		set_process(false)
		return

	_mutex.lock()
	var pronto := not _dados.is_empty()
	_mutex.unlock()
	if not pronto:
		return
	# Espera a porta terminar de abrir mesmo que a construcao acabe antes. Entrar
	# no meio da animacao entrega que o interior ja estava pronto.
	if float(Time.get_ticks_msec()) / 1000.0 < _pronto_em:
		return

	WorkerThreadPool.wait_for_task_completion(_tarefa)
	_tarefa = -1
	set_process(false)
	_materializar()


func _materializar() -> void:
	var arvore := get_tree().current_scene
	if arvore == null:
		return

	_no = Node3D.new()
	_no.name = "Interior"
	_no.position = DESLOCAMENTO

	var superficies: Dictionary = _dados["superficies"]
	for material: StringName in superficies:
		var d: Dictionary = superficies[material]
		if PSXMesh.dados_vazio(d):
			continue
		var mi := MeshInstance3D.new()
		mi.name = String(material)
		mi.mesh = PSXMesh.dados_para_mesh(d)
		mi.material_override = _material(material)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_no.add_child(mi)

	var corpo := StaticBody3D.new()
	corpo.name = "Colisao"
	for caixa: Dictionary in _dados["colisao"]:
		var forma := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = caixa["tamanho"]
		forma.shape = box
		forma.position = caixa["pos"]
		corpo.add_child(forma)
	_no.add_child(corpo)

	for prop: Dictionary in _dados["props"]:
		if prop.get("tipo", "") != "lampada":
			continue
		var l := Lampada.new()
		l.position = prop["pos"]
		l.padrao = prop["padrao"]
		l.semente = prop["semente"]
		l.cor = prop.get("cor", Color("ffe0b0"))
		l.energia = prop.get("energia", 1.5)
		l.alcance = prop.get("alcance", 6.0)
		l.facho_visivel = prop.get("facho", false)
		_no.add_child(l)

	_no.add_child(_saida())
	arvore.add_child(_no)

	var entrada: Vector3 = _dados["entrada"]
	var jogador := get_tree().get_first_node_in_group(&"player") as Node3D
	if jogador != null:
		jogador.global_position = DESLOCAMENTO + entrada + Vector3(0.0, 0.15, 0.0)
		if jogador.has_method("olhar_para"):
			jogador.call("olhar_para", DESLOCAMENTO + Vector3(_dados["olhar"]))
		if jogador.has_method("zerar_velocidade"):
			jogador.call("zerar_velocidade")

	_mostrar_cidade(false)
	_forcar_ambiente()
	dentro = true
	entrou.emit()


## Porta de saida, no vao da parede oeste.
func _saida() -> Interativo:
	var area := Interativo.new()
	area.name = "Saida"
	area.rotulo = "Sair"
	area.position = Vector3(0.25, 1.0, InteriorBuilder.ENTRADA.z)
	var forma := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.7, 2.0, 1.4)
	forma.shape = box
	area.add_child(forma)
	area.acionado.connect(func(_quem: Node) -> void: sair())
	return area


func _mostrar_cidade(visivel: bool) -> void:
	if ChunkManager.raiz != null:
		ChunkManager.raiz.visible = visivel
	var chuva := get_tree().current_scene.get_node_or_null("Chuva") as GPUParticles3D
	if chuva != null:
		chuva.visible = visivel
		chuva.emitting = visivel


func _forcar_ambiente() -> void:
	var fog := get_tree().get_first_node_in_group(&"fog_controller") as FogController
	if fog != null:
		fog.forcar("res://resources/fog/fog_interior.tres")


func _liberar_ambiente() -> void:
	var fog := get_tree().get_first_node_in_group(&"fog_controller") as FogController
	if fog != null:
		fog.liberar()


func _material(nome: StringName) -> ShaderMaterial:
	if _materiais.has(nome):
		return _materiais[nome]
	var caminho := MAT_DIR % nome
	if not ResourceLoader.exists(caminho):
		push_error("Interiores: material ausente %s" % caminho)
		return null
	var m := load(caminho) as ShaderMaterial
	_materiais[nome] = m
	return m
