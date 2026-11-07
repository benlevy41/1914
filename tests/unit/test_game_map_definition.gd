extends SceneTree

const MapCityDefinitionScript = preload("res://scripts/domain/map_city_definition.gd")
const GameMapDefinitionScript = preload("res://scripts/domain/game_map_definition.gd")

var _failures: int = 0


func _initialize() -> void:
	var map_definition: GameMapDefinition = GameMapDefinitionScript.create_western_front()
	var city_ids: Dictionary = {}
	var expected_city_ids: Array[String] = [
		"paris", "mezieres", "verdun", "meaux", "albert", "nancy", "amiens", "rheims",
		"la_bassee", "lille", "maubeuge", "soissons", "valenciennes", "cambrai",
		"saint_quentin", "laon", "hirson", "mons", "ghent", "tournai", "ypres", "liege",
		"brussels", "charleroi", "namur", "antwerp", "luxembourg", "metz", "koblenz",
		"strasbourg", "aachen", "saarbrucken",
	]
	var connected_city_ids: Dictionary = {"paris": true}
	_expect(map_definition is RefCounted, "Map definition should be independent of the scene tree.")
	_expect(map_definition.cities.size() == 32, "The complete map should define all 32 cities.")
	_expect(map_definition.connections.size() > 0, "The map should define road connections.")
	_expect(map_definition.find_city("paris").name == "Paris", "Map definition should find a city by ID.")
	_expect(
		map_definition.find_city("paris").position == Vector2(0.08, 0.76),
		"Map definition should retain a city's static map position."
	)
	_expect(
		map_definition.find_city("paris").is_center_of_gravity,
		"Map definition should retain a city's static COG marker."
	)
	for city_definition: MapCityDefinition in map_definition.cities:
		_expect(not city_ids.has(city_definition.id), "Map city IDs should be unique.")
		city_ids[city_definition.id] = true
		_expect(
			expected_city_ids.has(city_definition.id),
			"Every map city should appear in the documented city list."
		)
		_expect(
			city_definition.position.x >= 0.0
			and city_definition.position.x <= 1.0
			and city_definition.position.y >= 0.0
			and city_definition.position.y <= 1.0,
			"Map city positions should use normalized coordinates."
		)
	for connection: MapConnection in map_definition.connections:
		_expect(
			map_definition.find_city(connection.from_city_id) != null,
			"Roads should reference a known starting city."
		)
		_expect(
			map_definition.find_city(connection.to_city_id) != null,
			"Roads should reference a known destination city."
		)
	var found_new_city := true
	while found_new_city:
		found_new_city = false
		for connection: MapConnection in map_definition.connections:
			if connected_city_ids.has(connection.from_city_id) and not connected_city_ids.has(connection.to_city_id):
				connected_city_ids[connection.to_city_id] = true
				found_new_city = true
			elif connected_city_ids.has(connection.to_city_id) and not connected_city_ids.has(connection.from_city_id):
				connected_city_ids[connection.from_city_id] = true
				found_new_city = true
	_expect(
		connected_city_ids.size() == map_definition.cities.size(),
		"The provisional road network should connect all cities."
	)
	_expect(map_definition.find_city("paris").is_center_of_gravity, "Paris should be an Allied COG.")
	_expect(map_definition.find_city("koblenz").is_center_of_gravity, "Koblenz should be a German COG.")

	if _failures == 0:
		print("Game map definition unit tests passed.")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
