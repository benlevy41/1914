class_name BoardView
extends Control

signal city_selected(city_id: String)
signal city_context_requested(city_id: String, screen_position: Vector2)

const CityMarkerScene = preload("res://scenes/board_city_marker.tscn")

const BACKGROUND_COLOR := Color(0.12, 0.14, 0.16)
const ROAD_COLOR := Color(0.72, 0.74, 0.76)
const ROAD_ANCHOR_COLOR := Color(0.88, 0.76, 0.46)
const OWNER_COLORS := {
	"allies": Color(0.20, 0.38, 0.68),
	"german_empire": Color(0.62, 0.24, 0.20),
}
const UNOWNED_COLOR := Color(0.36, 0.38, 0.40)

var _snapshot: GameViewSnapshot
var _markers: Dictionary = {}
var _selected_city_id: String = ""
var _city_anchor_positions: Dictionary = {}
var _marker_center_positions: Dictionary = {}
var _projection_bounds: Rect2
var _projection_origin: Vector2
var _projection_scale: float = 1.0
var _projection_longitude_scale: float = 1.0


func _ready() -> void:
	custom_minimum_size = Vector2(800, 500)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout_markers)


func configure(snapshot: GameViewSnapshot) -> void:
	_snapshot = snapshot
	_selected_city_id = ""

	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_markers.clear()

	for city: GameViewSnapshot.CityView in _snapshot.cities:
		var marker := CityMarkerScene.instantiate() as BoardCityMarker
		marker.name = "CityMarker_%s" % city.id
		marker.pressed.connect(_on_marker_pressed.bind(city.id))
		marker.gui_input.connect(_on_marker_gui_input.bind(city.id))
		add_child(marker)
		_markers[city.id] = marker

	refresh_snapshot(snapshot)


func refresh_snapshot(snapshot: GameViewSnapshot) -> void:
	_snapshot = snapshot
	if _snapshot == null:
		push_error("Cannot refresh the board without a game view snapshot.")
		return

	for city: GameViewSnapshot.CityView in _snapshot.cities:
		if not _markers.has(city.id):
			continue
		var owner_name := city.owner_name if not city.owner_name.is_empty() else "Unoccupied"
		var owner_color := UNOWNED_COLOR
		if not city.owner_id.is_empty():
			if not OWNER_COLORS.has(city.owner_id):
				push_error("No board color is configured for player '%s'." % city.owner_id)
				return
			owner_color = OWNER_COLORS[city.owner_id]

		var marker: BoardCityMarker = _markers[city.id]
		marker.configure(city, owner_name, owner_color)
		marker.button_pressed = city.id == _selected_city_id

	_layout_markers()
	queue_redraw()


func get_selected_city_id() -> String:
	return _selected_city_id


func get_city_id_at_position(screen_position: Vector2) -> String:
	for city_id: String in _markers:
		var marker: BoardCityMarker = _markers[city_id]
		if marker.get_global_rect().has_point(screen_position):
			return city_id
	return ""


func clear_selection() -> void:
	_selected_city_id = ""
	for marker_id: String in _markers:
		var marker: BoardCityMarker = _markers[marker_id]
		marker.button_pressed = false


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND_COLOR)
	if _snapshot == null:
		return

	for connection: GameViewSnapshot.ConnectionView in _snapshot.connections:
		var from_city := _snapshot.find_city(connection.from_city_id)
		var to_city := _snapshot.find_city(connection.to_city_id)
		if from_city == null or to_city == null:
			push_error(
				"Board connection references an unknown city: %s to %s."
				% [connection.from_city_id, connection.to_city_id]
			)
			return
		draw_line(
			_city_canvas_position(from_city.longitude, from_city.latitude),
			_city_canvas_position(to_city.longitude, to_city.latitude),
			ROAD_COLOR,
			4.0,
			true
		)
	for city: GameViewSnapshot.CityView in _snapshot.cities:
		var anchor_position: Vector2 = _city_anchor_positions.get(city.id, Vector2.ZERO)
		var marker_center: Vector2 = _marker_center_positions.get(city.id, anchor_position)
		if not anchor_position.is_equal_approx(marker_center):
			draw_line(anchor_position, marker_center, ROAD_ANCHOR_COLOR, 1.5, true)
		draw_circle(anchor_position, 3.0, ROAD_ANCHOR_COLOR)


func _layout_markers() -> void:
	if _snapshot == null:
		return
	_update_projection()
	_city_anchor_positions.clear()
	_marker_center_positions.clear()
	var placed_marker_rects: Array[Rect2] = []
	for city: GameViewSnapshot.CityView in _snapshot.cities:
		if not _markers.has(city.id):
			continue
		var marker: BoardCityMarker = _markers[city.id]
		marker.size = marker.custom_minimum_size
		var anchor_position := _city_canvas_position(city.longitude, city.latitude)
		var marker_center := _find_marker_position(
			anchor_position,
			marker.size,
			placed_marker_rects
		)
		_city_anchor_positions[city.id] = anchor_position
		_marker_center_positions[city.id] = marker_center
		marker.position = marker_center - marker.size / 2.0
		placed_marker_rects.append(Rect2(marker.position, marker.size).grow(4.0))
	queue_redraw()


func _update_projection() -> void:
	if _snapshot.cities.is_empty():
		_projection_bounds = Rect2()
		_projection_origin = Vector2.ZERO
		_projection_scale = 1.0
		_projection_longitude_scale = 1.0
		return

	var mean_latitude := 0.0
	for city: GameViewSnapshot.CityView in _snapshot.cities:
		mean_latitude += city.latitude
	mean_latitude /= _snapshot.cities.size()
	_projection_longitude_scale = cos(deg_to_rad(mean_latitude))

	var first_city := _snapshot.cities[0]
	var min_x := first_city.longitude * _projection_longitude_scale
	var max_x := min_x
	var min_y := -first_city.latitude
	var max_y := min_y
	for city: GameViewSnapshot.CityView in _snapshot.cities:
		var projected_x := city.longitude * _projection_longitude_scale
		var projected_y := -city.latitude
		min_x = minf(min_x, projected_x)
		max_x = maxf(max_x, projected_x)
		min_y = minf(min_y, projected_y)
		max_y = maxf(max_y, projected_y)

	_projection_bounds = Rect2(
		Vector2(min_x, min_y),
		Vector2(max_x - min_x, max_y - min_y)
	)
	const MAP_PADDING := Vector2(56.0, 44.0)
	var available_size := Vector2(
		maxf(size.x - MAP_PADDING.x * 2.0, 1.0),
		maxf(size.y - MAP_PADDING.y * 2.0, 1.0)
	)
	_projection_scale = minf(
		available_size.x / _projection_bounds.size.x,
		available_size.y / _projection_bounds.size.y
	)
	var projected_size := _projection_bounds.size * _projection_scale
	_projection_origin = MAP_PADDING + (available_size - projected_size) / 2.0


func _city_canvas_position(longitude: float, latitude: float) -> Vector2:
	var projected_position := Vector2(
		longitude * _projection_longitude_scale,
		-latitude
	)
	return _projection_origin + (
		projected_position - _projection_bounds.position
	) * _projection_scale


func _find_marker_position(
	anchor_position: Vector2,
	marker_size: Vector2,
	placed_marker_rects: Array[Rect2]
) -> Vector2:
	var first_position := _clamp_marker_center(anchor_position, marker_size)
	if not _marker_position_overlaps(first_position, marker_size, placed_marker_rects):
		return first_position

	var max_radius := maxf(size.x, size.y)
	for radius_step: int in range(1, int(max_radius / 20.0) + 1):
		var radius := radius_step * 20.0
		for direction_index: int in 16:
			var angle := TAU * direction_index / 16.0
			var candidate := _clamp_marker_center(
				anchor_position + Vector2(cos(angle), sin(angle)) * radius,
				marker_size
			)
			if not _marker_position_overlaps(candidate, marker_size, placed_marker_rects):
				return candidate
	return first_position


func _clamp_marker_center(center: Vector2, marker_size: Vector2) -> Vector2:
	var half_size := marker_size / 2.0
	var min_x := minf(half_size.x + 8.0, size.x / 2.0)
	var max_x := maxf(size.x - half_size.x - 8.0, size.x / 2.0)
	var min_y := minf(half_size.y + 8.0, size.y / 2.0)
	var max_y := maxf(size.y - half_size.y - 8.0, size.y / 2.0)
	return Vector2(
		clampf(center.x, min_x, max_x),
		clampf(center.y, min_y, max_y)
	)


func _marker_position_overlaps(
	center: Vector2,
	marker_size: Vector2,
	placed_marker_rects: Array[Rect2]
) -> bool:
	var marker_rect := Rect2(center - marker_size / 2.0, marker_size).grow(4.0)
	for placed_rect: Rect2 in placed_marker_rects:
		if marker_rect.intersects(placed_rect):
			return true
	return false


func _on_marker_pressed(city_id: String) -> void:
	_selected_city_id = city_id
	for marker_id: String in _markers:
		var marker: BoardCityMarker = _markers[marker_id]
		marker.button_pressed = marker_id == city_id
	city_selected.emit(city_id)


func _on_marker_gui_input(event: InputEvent, city_id: String) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_RIGHT
		and event.pressed
	):
		var marker := _markers[city_id] as BoardCityMarker
		marker.accept_event()
		city_context_requested.emit(city_id, event.global_position)
