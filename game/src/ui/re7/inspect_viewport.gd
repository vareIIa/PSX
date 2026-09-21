## ItemInspectViewport — Onda 3 PREP (isolado; wire na prancha só após GO PO1).
## Evolui a vitrine SubViewport parcial de prancha_inventario (_montar_vitrine).
## Spec: docs/specs/SPEC_INSPECT_VITALS_RE7.md · SPEC_VISUAL/MOTION/A11Y_RE7.
class_name ItemInspectViewport
extends Control

signal closed

const VIEW_SIZE := Vector2i(140, 150)
const PITCH_MAX := deg_to_rad(75.0)
const SENS_MOUSE := 0.0055
const SENS_STICK := 2.8
const SPIN_HALF_LIFE := 0.18  ## ~T_RE7_SPIN_DAMP/2 (SPEC_MOTION_RE7 §5)
const ZOOM_MIN := 0.8
const ZOOM_MAX := 1.4

@export var zoom: float = 1.0:
	set(v):
		zoom = clampf(v, ZOOM_MIN, ZOOM_MAX)
		_apply_zoom()

var _vp: SubViewport
var _world_root: Node3D
var _pivot: Node3D
var _item_slot: Node3D
var _camera: Camera3D
var _key: OmniLight3D
var _rim: OmniLight3D
var _view: TextureRect

var _yaw := 0.6
var _pitch := deg_to_rad(-18.0)
var _omega_yaw := 0.0
var _omega_pitch := 0.0
var _dragging := false
var _active := false
var _item_id: StringName = &""
var _decay := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(VIEW_SIZE)
	# half-life ~0,18s; janela visível ≈ UiEstilo.T_RE7_SPIN_DAMP (0,28–0,40).
	var half := maxf(0.12, UiEstilo.T_RE7_SPIN_DAMP * 0.5)
	_decay = log(2.0) / half
	_build()
	scale = Vector2.ONE
	set_process(false)
	set_process_unhandled_input(false)


func _build() -> void:
	_vp = SubViewport.new()
	_vp.name = "InspectVP"
	_vp.size = VIEW_SIZE
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.msaa_3d = Viewport.MSAA_2X
	_vp.handle_input_locally = false
	add_child(_vp)

	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.045, 0.05, 0.85)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.12, 0.14, 0.16)
	env.ambient_light_energy = 0.35
	ambiente.environment = env
	_vp.add_child(ambiente)

	_world_root = Node3D.new()
	_world_root.name = "World"
	_vp.add_child(_world_root)

	_key = OmniLight3D.new()
	_key.name = "KeyLight"
	_key.light_color = Color(1.0, 0.92, 0.82)
	_key.light_energy = 2.4
	_key.omni_range = 6.0
	_key.position = Vector3(1.2, 1.6, 1.4)
	_world_root.add_child(_key)

	_rim = OmniLight3D.new()
	_rim.name = "RimLight"
	_rim.light_color = Color(0.55, 0.72, 0.95)
	_rim.light_energy = 1.1
	_rim.omni_range = 5.0
	_rim.position = Vector3(-1.4, 0.6, -1.1)
	_world_root.add_child(_rim)

	_pivot = Node3D.new()
	_pivot.name = "OrbitPivot"
	_world_root.add_child(_pivot)

	_item_slot = Node3D.new()
	_item_slot.name = "ItemSlot"
	_pivot.add_child(_item_slot)

	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_camera.fov = 30.0
	_camera.near = 0.05
	_camera.far = 20.0
	_camera.position = Vector3(0.95, 0.75, 2.05)
	_world_root.add_child(_camera)
	_camera.look_at(Vector3(0.0, 0.05, 0.0), Vector3.UP)
	_camera.current = true
	_apply_zoom()

	_view = TextureRect.new()
	_view.name = "View"
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.texture = _vp.get_texture()
	add_child(_view)

	_apply_pivot()


func enter() -> void:
	_active = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	set_process(true)
	set_process_unhandled_input(true)
	grab_focus()
	# Enter: viewport scale 0,96→1 em T_RE7_PANEL (EXPO out). Sem BACK/ELASTIC.
	scale = Vector2(0.96, 0.96)
	if _item_slot != null:
		_item_slot.scale = Vector3(0.96, 0.96, 0.96)
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, UiEstilo.T_RE7_PANEL)
	if _item_slot != null:
		tw.tween_property(_item_slot, "scale", Vector3.ONE, UiEstilo.T_RE7_PANEL)


func exit() -> void:
	# Exit: matar ω imediatamente; fechar em T_RE7_CLOSE (EXPO in). Sem elastic.
	_active = false
	_dragging = false
	_omega_yaw = 0.0
	_omega_pitch = 0.0
	set_process(false)
	set_process_unhandled_input(false)
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "scale", Vector2(0.96, 0.96), UiEstilo.T_RE7_CLOSE)
	tw.tween_callback(func() -> void:
		_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		scale = Vector2.ONE
		if _item_slot != null:
			_item_slot.scale = Vector3.ONE
		closed.emit()
	)


func set_item(item_id: StringName) -> void:
	if item_id == _item_id and _item_slot.get_child_count() > 0:
		return
	clear()
	_item_id = item_id
	if item_id == &"":
		return
	# ItemModelo.criar — legado da vitrine; fallback caixa cinza se ausente.
	var node: Node3D = null
	if ClassDB.class_exists(&"ItemModelo") or _has_item_modelo():
		node = ItemModelo.criar(item_id)
	else:
		node = _fallback_mesh()
	_item_slot.add_child(node)


func clear() -> void:
	for c in _item_slot.get_children():
		_item_slot.remove_child(c)
		c.free()
	_item_id = &""


func _has_item_modelo() -> bool:
	return true  # class_name ItemModelo no projeto


func _fallback_mesh() -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.5, 0.5)
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.55, 0.58)
	mat.roughness = 0.7
	mi.material_override = mat
	root.add_child(mi)
	return root


func _apply_zoom() -> void:
	if _camera == null:
		return
	var base := Vector3(0.95, 0.75, 2.05)
	_camera.position = base / zoom


func _apply_pivot() -> void:
	if _pivot == null:
		return
	_pitch = clampf(_pitch, -PITCH_MAX, PITCH_MAX)
	_pivot.rotation = Vector3(_pitch, _yaw, 0.0)


func _process(delta: float) -> void:
	if not _active:
		return
	var stick := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	# Preferência: eixos de look se existirem (não compete com nav de slots).
	if InputMap.has_action("look_left"):
		stick = Vector2(
			Input.get_axis("look_left", "look_right"),
			Input.get_axis("look_up", "look_down")
		)
	if stick.length_squared() > 0.04:
		_omega_yaw = -stick.x * SENS_STICK
		_omega_pitch = -stick.y * SENS_STICK * 0.75
	elif not _dragging:
		# Spin damp: ω *= e^(-λΔt), λ=ln2/half_life — SPEC_MOTION_RE7 §5 (sem BACK/ELASTIC).
		var damp := exp(-_decay * delta)
		_omega_yaw *= damp
		_omega_pitch *= damp
		if absf(_omega_yaw) < 0.001:
			_omega_yaw = 0.0
		if absf(_omega_pitch) < 0.001:
			_omega_pitch = 0.0
	_yaw += _omega_yaw * delta
	_pitch += _omega_pitch * delta
	_apply_pivot()
	# Respiração leve da key (±5%, 5 s) — SPEC_MOTION §5.
	_key.light_energy = 2.4 + sin(Time.get_ticks_msec() * 0.00125) * 0.12


func _gui_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			if not mb.pressed:
				pass  # ω já está setado pelo motion
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom = zoom + 0.08
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom = zoom - 0.08
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		_omega_yaw = -mm.relative.x * SENS_MOUSE / maxf(get_process_delta_time(), 0.0001)
		_omega_pitch = -mm.relative.y * SENS_MOUSE / maxf(get_process_delta_time(), 0.0001)
		_yaw += -mm.relative.x * SENS_MOUSE
		_pitch += -mm.relative.y * SENS_MOUSE
		_apply_pivot()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("examinar"):
		exit()
		get_viewport().set_input_as_handled()
