class_name BoardView
extends Control

signal city_selected(city_id: String)
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

var _snapshot: GameViewSnapshot
var _selected_city_id: String = ""
var _owner_materials: Dictionary = {}
var _unowned_material: StandardMaterial3D
var _road_material: StandardMaterial3D
var _cog_material: StandardMaterial3D
var _road_mesh := BoxMesh.new()
var _city_base_mesh := CylinderMesh.new()
var _city_body_mesh := CylinderMesh.new()
var _unit_mesh := BoxMesh.new()

@onready var _map_content: Node3D = $ViewportContainer/SubViewport/Board3D/MapContent
@onready var _board_surface: MeshInstance3D = (
	$ViewportContainer/SubViewport/Board3D/BoardSurface
)


func _ready() -> void:
	custom_minimum_size = Vector2(800, 500)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_configure_meshes()
	_configure_materials()


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


func get_city_id_at_position(_screen_position: Vector2) -> String:
	return ""


func clear_selection() -> void:
	_selected_city_id = ""


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


func _configure_materials() -> void:
	_unowned_material = _create_material(UNOWNED_COLOR)
	_road_material = _create_material(ROAD_COLOR)
	_cog_material = _create_material(COG_COLOR)
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
