class_name BoardView
extends Control

signal city_selected(city_id: String)

const CityMarkerScene = preload("res://scenes/board_city_marker.tscn")

const BACKGROUND_COLOR := Color(0.12, 0.14, 0.16)
const ROAD_COLOR := Color(0.72, 0.74, 0.76)
const OWNER_COLORS := {
	"allies": Color(0.20, 0.38, 0.68),
	"german_empire": Color(0.62, 0.24, 0.20),
}
const UNOWNED_COLOR := Color(0.36, 0.38, 0.40)

var _map_definition: GameMapDefinition
var _game_state: GameState
var _markers: Dictionary = {}
var _selected_city_id: String = ""


func _ready() -> void:
	custom_minimum_size = Vector2(800, 500)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout_markers)


func configure(map_definition: GameMapDefinition, game_state: GameState) -> void:
	_map_definition = map_definition
	_game_state = game_state
	_selected_city_id = ""

	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_markers.clear()

	for city_definition: MapCityDefinition in _map_definition.cities:
		var city_state := _game_state.find_city(city_definition.id)
		if city_state == null:
			push_error("Game state has no entry for map city '%s'." % city_definition.id)
			return

		var marker := CityMarkerScene.instantiate() as BoardCityMarker
		marker.name = "CityMarker_%s" % city_definition.id
		marker.pressed.connect(_on_marker_pressed.bind(city_definition.id))
		add_child(marker)
		_markers[city_definition.id] = marker

	refresh_state(game_state)


func refresh_state(game_state: GameState) -> void:
	_game_state = game_state
	if _map_definition == null:
		push_error("Configure the board map before refreshing its game state.")
		return

	for city_definition: MapCityDefinition in _map_definition.cities:
		if not _markers.has(city_definition.id):
			continue
		var city_state := _game_state.find_city(city_definition.id)
		if city_state == null:
			push_error("Game state has no entry for map city '%s'." % city_definition.id)
			return
		var owner_name := "Unoccupied"
		var owner_color := UNOWNED_COLOR
		if not city_state.owner_id.is_empty():
			var owner := _game_state.find_player(city_state.owner_id)
			if owner == null:
				push_error("City '%s' has unknown owner '%s'." % [city_definition.id, city_state.owner_id])
				return
			if not OWNER_COLORS.has(owner.id):
				push_error("No board color is configured for player '%s'." % owner.id)
				return
			owner_name = owner.name
			owner_color = OWNER_COLORS[owner.id]

		var marker: BoardCityMarker = _markers[city_definition.id]
		marker.configure(city_definition, city_state, owner_name, owner_color)
		marker.button_pressed = city_definition.id == _selected_city_id

	_layout_markers()
	queue_redraw()


func get_selected_city_id() -> String:
	return _selected_city_id


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND_COLOR)
	if _map_definition == null:
		return

	for connection: MapConnection in _map_definition.connections:
		var from_city := _map_definition.find_city(connection.from_city_id)
		var to_city := _map_definition.find_city(connection.to_city_id)
		if from_city == null or to_city == null:
			push_error(
				"Map connection references an unknown city: %s to %s."
				% [connection.from_city_id, connection.to_city_id]
			)
			continue
		draw_line(
			_city_canvas_position(from_city),
			_city_canvas_position(to_city),
			ROAD_COLOR,
			4.0,
			true
		)


func _layout_markers() -> void:
	if _map_definition == null:
		return
	for city_definition: MapCityDefinition in _map_definition.cities:
		if not _markers.has(city_definition.id):
			continue
		var marker: BoardCityMarker = _markers[city_definition.id]
		marker.size = marker.custom_minimum_size
		marker.position = _city_canvas_position(city_definition) - marker.size / 2.0


func _city_canvas_position(city_definition: MapCityDefinition) -> Vector2:
	const MAP_PADDING := Vector2(32.0, 32.0)
	var map_size := size - MAP_PADDING * 2.0
	return MAP_PADDING + Vector2(
		city_definition.position.x * map_size.x,
		city_definition.position.y * map_size.y
	)


func _on_marker_pressed(city_id: String) -> void:
	_selected_city_id = city_id
	for marker_id: String in _markers:
		var marker: BoardCityMarker = _markers[marker_id]
		marker.button_pressed = marker_id == city_id
	city_selected.emit(city_id)
