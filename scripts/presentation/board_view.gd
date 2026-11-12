class_name BoardView
extends Control

signal city_selected(city_id: String)
signal selection_cleared
signal city_context_requested(city_id: String, screen_position: Vector2)

const OWNER_COLORS := {
	"allies": Color(0.20, 0.38, 0.68),
	"german_empire": Color(0.62, 0.24, 0.20),
}
const UNOWNED_COLOR := Color(0.36, 0.38, 0.40)
const ROAD_COLOR := Color(0.17, 0.18, 0.17)
const COG_COLOR := Color(0.88, 0.72, 0.36)
const UNIT_COLUMNS := 3
const UNIT_SPACING := 0.12
const CITY_PICK_RADIUS := 10.0
const PAN_SPEED := 8.0
const MIN_ZOOM_DISTANCE := 4.0
const MAX_ZOOM_DISTANCE := 40.0
const ZOOM_FACTOR := 0.85
const CAMERA_TRANSITION_DURATION := 0.25
const OVERVIEW_PADDING := 1.1

var _snapshot: GameViewSnapshot
var _selected_city_id: String = ""
var _city_visuals: Dictionary = {}
var _navigation_blocked: bool = false
var _camera_target: Vector3
var _camera_distance: float
var _normal_camera_pitch: float
var _overview_active: bool = false
var _camera_tween: Tween
var _transition_start_target: Vector3
var _transition_end_target: Vector3
var _transition_start_distance: float
var _transition_end_distance: float
var _transition_start_pitch: float
var _transition_end_pitch: float
var _dragging: bool = false
var _drag_anchor: Vector3
var _owner_materials: Dictionary = {}
var _unowned_material: StandardMaterial3D
var _road_material: StandardMaterial3D
var _cog_material: StandardMaterial3D
var _selection_material: StandardMaterial3D
var _road_mesh := BoxMesh.new()
var _city_base_mesh := CylinderMesh.new()
var _city_body_mesh := CylinderMesh.new()
var _unit_mesh := BoxMesh.new()
var _selection_mesh := CylinderMesh.new()

@onready var _viewport_container: SubViewportContainer = $ViewportContainer
@onready var _sub_viewport: SubViewport = $ViewportContainer/SubViewport
@onready var _board_3d: Node3D = $ViewportContainer/SubViewport/Board3D
@onready var _camera: Camera3D = $ViewportContainer/SubViewport/Board3D/Camera3D
@onready var _map_content: Node3D = $ViewportContainer/SubViewport/Board3D/MapContent
@onready var _board_surface: MeshInstance3D = (
	$ViewportContainer/SubViewport/Board3D/BoardSurface
)


func _ready() -> void:
	custom_minimum_size = Vector2(800, 500)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_configure_meshes()
	_configure_materials()
	_camera_distance = _camera.position.y / _camera.basis.z.y
	_camera_target = _camera.position - _camera.basis.z * _camera_distance
	_normal_camera_pitch = _camera.rotation.x
	_viewport_container.gui_input.connect(_on_viewport_gui_input)
	_sub_viewport.size_changed.connect(_on_viewport_size_changed)
	get_window().focus_exited.connect(_cancel_drag)


func _process(delta: float) -> void:
	if not is_visible_in_tree() or _navigation_blocked:
		return
	if _is_text_input_active():
		return

	var direction := Vector2(
		int(Input.is_physical_key_pressed(KEY_D)) - int(Input.is_physical_key_pressed(KEY_A)),
		int(Input.is_physical_key_pressed(KEY_S)) - int(Input.is_physical_key_pressed(KEY_W))
	)
	if direction.is_zero_approx():
		return
	_finish_camera_transition()
	direction = direction.normalized() * PAN_SPEED * delta
	_set_camera_target(_camera_target + Vector3(direction.x, 0.0, direction.y))


func _set_camera_target(target: Vector3) -> void:
	var board_mesh := _board_surface.mesh as BoxMesh
	if board_mesh == null:
		push_error("The 3D board surface must use a BoxMesh for camera navigation.")
		return
	_camera_target.x = clampf(
		target.x, -board_mesh.size.x / 2.0, board_mesh.size.x / 2.0
	)
	_camera_target.z = clampf(
		target.z, -board_mesh.size.z / 2.0, board_mesh.size.z / 2.0
	)
	_update_camera()


func configure(snapshot: GameViewSnapshot) -> void:
	_selected_city_id = ""
	refresh_snapshot(snapshot)


func refresh_snapshot(snapshot: GameViewSnapshot) -> void:
	if snapshot == null:
		push_error("Cannot refresh the board without a game view snapshot.")
		return
	_snapshot = snapshot
	_render_snapshot(snapshot)


func get_selected_city_id() -> String:
	return _selected_city_id


func get_city_id_at_position(screen_position: Vector2) -> String:
	if not is_visible_in_tree() or _viewport_container.size.x <= 0 or _viewport_container.size.y <= 0:
		return ""
	var local_position := (
		_viewport_container.get_global_transform_with_canvas().affine_inverse() * screen_position
	)
	if not Rect2(Vector2.ZERO, _viewport_container.size).has_point(local_position):
		return ""
	var viewport_position := local_position * Vector2(_sub_viewport.size) / _viewport_container.size
	var closest_city_id := ""
	var closest_distance := INF
	for city_id: String in _city_visuals:
		var city_visual: Node3D = _city_visuals[city_id]
		var center := city_visual.global_position + Vector3(0.0, 0.13, 0.0)
		if _camera.is_position_behind(center):
			continue
		var projected_center := _camera.unproject_position(center)
		var projected_edge := _camera.unproject_position(center + Vector3(0.15, 0.0, 0.0))
		var radius := maxf(CITY_PICK_RADIUS, projected_center.distance_to(projected_edge))
		var distance := projected_center.distance_to(viewport_position)
		if distance <= radius and distance < closest_distance:
			closest_distance = distance
			closest_city_id = city_id
	return closest_city_id


func clear_selection() -> void:
	_selected_city_id = ""
	_update_selection_visuals()


func set_navigation_blocked(blocked: bool) -> void:
	_navigation_blocked = blocked
	if blocked:
		_cancel_drag()


func _cancel_drag() -> void:
	_dragging = false


func _is_text_input_active() -> bool:
	var focus_owner := get_viewport().gui_get_focus_owner()
	return (
		focus_owner != null
		and focus_owner.is_visible_in_tree()
		and (focus_owner is LineEdit or focus_owner is TextEdit)
	)


func _on_viewport_gui_input(event: InputEvent) -> void:
	if _navigation_blocked:
		return
	if event is InputEventMouseMotion:
		if _dragging and (
			event.button_mask & MOUSE_BUTTON_MASK_MIDDLE == 0 or _is_text_input_active()
		):
			_cancel_drag()
		if _dragging:
			var point: Variant = _board_point_at_position(event.position)
			if point != null:
				_set_camera_target(_camera_target + _drag_anchor - point)
			_viewport_container.accept_event()
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
		if not mouse_event.pressed:
			_cancel_drag()
		elif not _is_text_input_active():
			_finish_camera_transition()
			var point: Variant = _board_point_at_position(mouse_event.position)
			if point != null:
				_drag_anchor = point
				_dragging = true
				_viewport_container.accept_event()
		return
	if not mouse_event.pressed:
		return
	if (
		mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP
		or mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN
	):
		if _is_text_input_active():
			return
		var factor := (
			ZOOM_FACTOR if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / ZOOM_FACTOR
		)
		_zoom_toward(mouse_event.position, factor)
		if _dragging:
			_finish_camera_transition()
			var point: Variant = _board_point_at_position(mouse_event.position)
			if point == null:
				_cancel_drag()
			else:
				_drag_anchor = point
		_viewport_container.accept_event()
		return
	if (
		mouse_event.button_index != MOUSE_BUTTON_LEFT
		and mouse_event.button_index != MOUSE_BUTTON_RIGHT
	):
		return
	var screen_position: Vector2 = (
		_viewport_container.get_global_transform_with_canvas() * mouse_event.position
	)
	var city_id := get_city_id_at_position(screen_position)
	if city_id.is_empty():
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			clear_selection()
			selection_cleared.emit()
			_viewport_container.accept_event()
		return
	_viewport_container.accept_event()
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		city_context_requested.emit(city_id, screen_position)
		return
	_selected_city_id = city_id
	_update_selection_visuals()
	city_selected.emit(city_id)


func _board_point_at_position(container_position: Vector2) -> Variant:
	if _viewport_container.size.x <= 0 or _viewport_container.size.y <= 0:
		return null
	var viewport_position := (
		container_position * Vector2(_sub_viewport.size) / _viewport_container.size
	)
	var origin := _board_3d.to_local(_camera.project_ray_origin(viewport_position))
	var direction := (
		_board_3d.global_transform.basis.inverse() * _camera.project_ray_normal(viewport_position)
	)
	return Plane(Vector3.UP, 0.0).intersects_ray(origin, direction)


func _zoom_toward(container_position: Vector2, factor: float) -> void:
	if _overview_active:
		if factor < 1.0:
			_transition_to_angled(container_position, MAX_ZOOM_DISTANCE * ZOOM_FACTOR)
		elif _camera_tween == null or not _camera_tween.is_running():
			_enter_overview()
		return
	var distance := _camera_distance
	if _camera_tween != null and _camera_tween.is_running():
		distance = _transition_end_distance
	var new_distance := clampf(distance * factor, MIN_ZOOM_DISTANCE, MAX_ZOOM_DISTANCE)
	if factor > 1.0 and is_equal_approx(new_distance, MAX_ZOOM_DISTANCE):
		_enter_overview()
		return
	if is_equal_approx(new_distance, distance):
		return
	if _camera_tween != null and _camera_tween.is_running():
		_transition_to_angled(container_position, new_distance)
		return
	var anchor: Vector3
	if _city_visuals.has(_selected_city_id):
		var city_visual: Node3D = _city_visuals[_selected_city_id]
		anchor = _board_3d.to_local(city_visual.global_position)
		anchor.y = 0.0
	else:
		var point: Variant = _board_point_at_position(container_position)
		if point == null:
			return
		anchor = point
	var target := anchor + (_camera_target - anchor) * (new_distance / _camera_distance)
	_camera_distance = new_distance
	_set_camera_target(target)


func _enter_overview() -> void:
	var distance := _overview_distance()
	if distance <= 0.0:
		return
	_overview_active = true
	_start_camera_transition(Vector3.ZERO, distance, -PI / 2.0)


func _transition_to_angled(container_position: Vector2, distance: float) -> void:
	var anchor: Vector3
	var anchor_position := container_position
	if _city_visuals.has(_selected_city_id):
		var city_visual: Node3D = _city_visuals[_selected_city_id]
		anchor = _board_3d.to_local(city_visual.global_position)
		anchor.y = 0.0
		var world_anchor := _board_3d.to_global(anchor)
		if _camera.is_position_behind(world_anchor):
			anchor_position = _viewport_container.size / 2.0
		else:
			var projected := _camera.unproject_position(world_anchor)
			anchor_position = projected * _viewport_container.size / Vector2(_sub_viewport.size)
	else:
		var point: Variant = _board_point_at_position(container_position)
		if point == null:
			return
		anchor = point

	var old_pitch := _camera.rotation.x
	var old_distance := _camera_distance
	_camera.rotation.x = _normal_camera_pitch
	_camera_distance = distance
	_update_camera()
	var projected_point: Variant = _board_point_at_position(anchor_position)
	var target := anchor
	if projected_point != null:
		target = _camera_target + anchor - projected_point
	_camera.rotation.x = old_pitch
	_camera_distance = old_distance
	_update_camera()

	var board_mesh := _board_surface.mesh as BoxMesh
	if board_mesh == null:
		push_error("The 3D board surface must use a BoxMesh for camera navigation.")
		return
	target.x = clampf(target.x, -board_mesh.size.x / 2.0, board_mesh.size.x / 2.0)
	target.z = clampf(target.z, -board_mesh.size.z / 2.0, board_mesh.size.z / 2.0)
	_overview_active = false
	_start_camera_transition(target, distance, _normal_camera_pitch)


func _overview_distance() -> float:
	var board_mesh := _board_surface.mesh as BoxMesh
	if board_mesh == null:
		push_error("The 3D board surface must use a BoxMesh for camera navigation.")
		return 0.0
	if _sub_viewport.size.x <= 0 or _sub_viewport.size.y <= 0:
		return 0.0
	var aspect := float(_sub_viewport.size.x) / float(_sub_viewport.size.y)
	var half_fov := tan(deg_to_rad(_camera.fov) / 2.0)
	var horizontal := half_fov * aspect
	var vertical := half_fov
	if _camera.keep_aspect == Camera3D.KEEP_WIDTH:
		horizontal = half_fov
		vertical = half_fov / aspect
	var fit_distance := maxf(
		board_mesh.size.x / (2.0 * horizontal), board_mesh.size.z / (2.0 * vertical)
	)
	return maxf(MAX_ZOOM_DISTANCE, fit_distance * OVERVIEW_PADDING)


func _on_viewport_size_changed() -> void:
	if not _overview_active:
		return
	var distance := _overview_distance()
	if distance <= 0.0:
		return
	var target := _camera_target
	if _camera_tween != null and _camera_tween.is_running():
		target = _transition_end_target
	_start_camera_transition(target, distance, -PI / 2.0)


func _start_camera_transition(target: Vector3, distance: float, pitch: float) -> void:
	if _camera_tween != null and _camera_tween.is_running():
		_camera_tween.kill()
	_transition_start_target = _camera_target
	_transition_end_target = target
	_transition_start_distance = _camera_distance
	_transition_end_distance = distance
	_transition_start_pitch = _camera.rotation.x
	_transition_end_pitch = pitch
	_camera_tween = create_tween()
	var transition := _camera_tween.tween_method(
		_apply_camera_transition, 0.0, 1.0, CAMERA_TRANSITION_DURATION
	)
	transition.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _apply_camera_transition(weight: float) -> void:
	_camera_target = _transition_start_target.lerp(_transition_end_target, weight)
	_camera_distance = lerpf(_transition_start_distance, _transition_end_distance, weight)
	_camera.rotation.x = lerpf(_transition_start_pitch, _transition_end_pitch, weight)
	_update_camera()


func _finish_camera_transition() -> void:
	if _camera_tween != null and _camera_tween.is_running():
		_camera_tween.kill()
		_apply_camera_transition(1.0)


func _update_camera() -> void:
	_camera.position = _camera_target + _camera.basis.z * _camera_distance


func _update_selection_visuals() -> void:
	for city_id: String in _city_visuals:
		var city_visual: Node3D = _city_visuals[city_id]
		var selection := city_visual.get_node("Selection") as MeshInstance3D
		selection.visible = city_id == _selected_city_id


func _configure_meshes() -> void:
	_road_mesh.size = Vector3.ONE
	_city_base_mesh.top_radius = 0.15
	_city_base_mesh.bottom_radius = 0.15
	_city_base_mesh.height = 0.04
	_city_base_mesh.radial_segments = 8
	_city_body_mesh.top_radius = 0.10
	_city_body_mesh.bottom_radius = 0.10
	_city_body_mesh.height = 0.18
	_city_body_mesh.radial_segments = 8
	_unit_mesh.size = Vector3(0.07, 0.12, 0.07)
	_selection_mesh.top_radius = 0.21
	_selection_mesh.bottom_radius = 0.21
	_selection_mesh.height = 0.02
	_selection_mesh.radial_segments = 16


func _configure_materials() -> void:
	_unowned_material = _create_material(UNOWNED_COLOR)
	_road_material = _create_material(ROAD_COLOR)
	_cog_material = _create_material(COG_COLOR)
	_selection_material = _create_material(Color(1.0, 0.82, 0.2))
	for owner_id: String in OWNER_COLORS:
		_owner_materials[owner_id] = _create_material(OWNER_COLORS[owner_id])


func _create_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material


func _render_snapshot(snapshot: GameViewSnapshot) -> void:
	var city_positions := _project_city_positions(snapshot)
	if city_positions.size() != snapshot.cities.size():
		_clear_map_content()
		return
	if not _validate_snapshot(snapshot, city_positions):
		_clear_map_content()
		return

	_clear_map_content()
	for connection: GameViewSnapshot.ConnectionView in snapshot.connections:
		_add_road_visual(connection, city_positions)
	for city: GameViewSnapshot.CityView in snapshot.cities:
		_add_city_visual(city, city_positions[city.id])


func _project_city_positions(snapshot: GameViewSnapshot) -> Dictionary:
	var projected_positions: Dictionary = {}
	if snapshot.cities.is_empty():
		return projected_positions

	var mean_latitude := 0.0
	for city: GameViewSnapshot.CityView in snapshot.cities:
		if projected_positions.has(city.id):
			push_error("The board snapshot contains duplicate city '%s'." % city.id)
			return {}
		mean_latitude += city.latitude
	mean_latitude /= snapshot.cities.size()
	var longitude_scale := cos(deg_to_rad(mean_latitude))

	var first_city := snapshot.cities[0]
	var min_x := first_city.longitude * longitude_scale
	var max_x := min_x
	var min_z := -first_city.latitude
	var max_z := min_z
	for city: GameViewSnapshot.CityView in snapshot.cities:
		var projected_x := city.longitude * longitude_scale
		var projected_z := -city.latitude
		min_x = minf(min_x, projected_x)
		max_x = maxf(max_x, projected_x)
		min_z = minf(min_z, projected_z)
		max_z = maxf(max_z, projected_z)

	var board_mesh := _board_surface.mesh as BoxMesh
	if board_mesh == null:
		push_error("The 3D board surface must use a BoxMesh.")
		return {}
	var map_padding := Vector2(2.0, 2.0)
	var available_size := Vector2(
		board_mesh.size.x - map_padding.x * 2.0,
		board_mesh.size.z - map_padding.y * 2.0
	)
	var projected_width := maxf(max_x - min_x, 0.001)
	var projected_depth := maxf(max_z - min_z, 0.001)
	var projection_scale := minf(
		available_size.x / projected_width,
		available_size.y / projected_depth
	)
	var center_x := (min_x + max_x) / 2.0
	var center_z := (min_z + max_z) / 2.0

	for city: GameViewSnapshot.CityView in snapshot.cities:
		projected_positions[city.id] = Vector3(
			(city.longitude * longitude_scale - center_x) * projection_scale,
			0.02,
			(-city.latitude - center_z) * projection_scale
		)
	return projected_positions


func _validate_snapshot(
	snapshot: GameViewSnapshot,
	city_positions: Dictionary
) -> bool:
	for connection: GameViewSnapshot.ConnectionView in snapshot.connections:
		if (
			not city_positions.has(connection.from_city_id)
			or not city_positions.has(connection.to_city_id)
		):
			push_error(
				"Board connection references an unknown city: %s to %s."
				% [connection.from_city_id, connection.to_city_id]
			)
			return false
	for city: GameViewSnapshot.CityView in snapshot.cities:
		if not city.owner_id.is_empty() and not OWNER_COLORS.has(city.owner_id):
			push_error("No board color is configured for player '%s'." % city.owner_id)
			return false
		if city.unit_count < 0:
			push_error("City '%s' has a negative unit count." % city.id)
			return false
	return true


func _clear_map_content() -> void:
	_city_visuals.clear()
	for child: Node in _map_content.get_children():
		_map_content.remove_child(child)
		child.queue_free()


func _add_road_visual(
	connection: GameViewSnapshot.ConnectionView,
	city_positions: Dictionary
) -> void:
	var from_position: Vector3 = city_positions[connection.from_city_id]
	var to_position: Vector3 = city_positions[connection.to_city_id]
	var direction := to_position - from_position
	var road := MeshInstance3D.new()
	road.name = "Road_%s_%s" % [connection.from_city_id, connection.to_city_id]
	road.mesh = _road_mesh
	road.material_override = _road_material
	road.position = (from_position + to_position) / 2.0
	road.scale = Vector3(direction.length(), 0.035, 0.045)
	road.rotation.y = -atan2(direction.z, direction.x)
	_map_content.add_child(road)


func _add_city_visual(city: GameViewSnapshot.CityView, position: Vector3) -> void:
	var city_visual := Node3D.new()
	city_visual.name = "City_%s" % city.id
	city_visual.position = position
	_map_content.add_child(city_visual)
	_city_visuals[city.id] = city_visual

	var selection := MeshInstance3D.new()
	selection.name = "Selection"
	selection.mesh = _selection_mesh
	selection.material_override = _selection_material
	selection.position.y = 0.015
	selection.visible = city.id == _selected_city_id
	city_visual.add_child(selection)

	var base := MeshInstance3D.new()
	base.name = "Base"
	base.mesh = _city_base_mesh
	base.material_override = _cog_material if city.is_center_of_gravity else _road_material
	base.position.y = 0.02
	city_visual.add_child(base)

	var city_model := MeshInstance3D.new()
	city_model.name = "CityModel"
	city_model.mesh = _city_body_mesh
	city_model.material_override = _owner_material(city.owner_id)
	city_model.position.y = 0.13
	city_visual.add_child(city_model)

	var name_label := Label3D.new()
	name_label.name = "NameLabel"
	name_label.text = "%s  %s" % [city.name, _owner_tag(city.owner_id)]
	name_label.font_size = 64
	name_label.pixel_size = 0.002
	name_label.outline_size = 8
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.modulate = Color(0.95, 0.92, 0.84)
	name_label.position = Vector3(0.0, 0.34, -0.16)
	city_visual.add_child(name_label)

	_add_unit_visuals(city_visual, city.unit_count, _owner_material(city.owner_id))


func _add_unit_visuals(
	city_visual: Node3D,
	unit_count: int,
	material: StandardMaterial3D
) -> void:
	for unit_index: int in unit_count:
		var row := floori(float(unit_index) / UNIT_COLUMNS)
		var column := unit_index % UNIT_COLUMNS
		var units_in_row := mini(UNIT_COLUMNS, unit_count - row * UNIT_COLUMNS)
		var x_offset := (column - float(units_in_row - 1) / 2.0) * UNIT_SPACING
		var unit := MeshInstance3D.new()
		unit.name = "Unit_%03d" % unit_index
		unit.mesh = _unit_mesh
		unit.material_override = material
		unit.position = Vector3(
			x_offset,
			0.08,
			0.24 + row * UNIT_SPACING
		)
		city_visual.add_child(unit)


func _owner_material(owner_id: String) -> StandardMaterial3D:
	if owner_id.is_empty():
		return _unowned_material
	return _owner_materials[owner_id]


func _owner_tag(owner_id: String) -> String:
	match owner_id:
		"allies":
			return "A"
		"german_empire":
			return "G"
		_:
			return "-"
