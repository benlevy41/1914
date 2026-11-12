extends SceneTree

const BoardSetupLoaderScript = preload("res://scripts/infrastructure/board_setup_loader.gd")

var _failures: int = 0


func _initialize() -> void:
	var load_result: BoardSetupLoadResult = BoardSetupLoaderScript.new().load_western_front()
	_expect(load_result.succeeded(), "The CSV-backed map should load successfully.")
	if not load_result.succeeded():
		quit(1)
		return
	var map_definition: GameMapDefinition = load_result.map_definition
	var city_ids: Dictionary = {}
	var expected_city_ids: Array[String] = [
		"aachen", "albert", "amiens", "antwerp", "brussels", "cambrai", "charleroi",
		"ghent", "hasselt", "hirson", "koblenz", "la_bassee", "laon", "liege", "lille",
		"luxembourg", "maubeuge", "metz", "mezieres", "mons", "namur", "nancy", "paris",
		"rheims", "saarbrucken", "saint_quentin", "soissons", "strasbourg", "tournai",
		"valenciennes", "verdun", "ypres",
	]
	var connected_city_ids: Dictionary = {"paris": true}
	var charleroi_neighbors: Dictionary = {
		"maubeuge": false,
		"namur": false,
		"mezieres": false,
		"mons": false,
	}
	var has_amiens_brussels_road := false
	_expect(
		map_definition is RefCounted,
		"Map definition should be independent of the scene tree."
	)
	_expect(map_definition.cities.size() == 32, "The complete map should define all 32 cities.")
	_expect(
		map_definition.connections.size() == 62,
		"The map should load all 62 CSV road connections."
	)
	_expect(
		map_definition.find_city("paris").name == "Paris",
		"Map definition should find a city by ID."
	)
	_expect(
		is_equal_approx(map_definition.find_city("paris").latitude, 48.857)
		and is_equal_approx(map_definition.find_city("paris").longitude, 2.357),
		"Map definition should retain CSV geographic coordinates."
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
			city_definition.latitude >= -90.0
			and city_definition.latitude <= 90.0
			and city_definition.longitude >= -180.0
			and city_definition.longitude <= 180.0,
			"Map city coordinates should use valid geographic bounds."
		)
	_expect(map_definition.find_city("meaux") == null, "Cities should come from cities.csv.")
	_expect(
		map_definition.find_city("hasselt") != null,
		"Cities added to cities.csv should appear in the loaded map."
	)
	_expect(
		map_definition.find_city("mezieres").name == "Mezieres",
		"The city label should come from cities.csv while preserving its existing ID."
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
		_expect(connection.road_size == 1, "The current CSV road sizes should be retained.")
		var endpoints := [connection.from_city_id, connection.to_city_id]
		if endpoints.has("charleroi"):
			for neighbor: String in charleroi_neighbors:
				if endpoints.has(neighbor):
					charleroi_neighbors[neighbor] = true
		if endpoints.has("amiens") and endpoints.has("brussels"):
			has_amiens_brussels_road = true
	for neighbor: String in charleroi_neighbors:
		_expect(charleroi_neighbors[neighbor], "Charleroi should connect to %s." % neighbor)
	_expect(not has_amiens_brussels_road, "Amiens should not have a direct road to Brussels.")
	var found_new_city := true
	while found_new_city:
		found_new_city = false
		for connection: MapConnection in map_definition.connections:
			if (
				connected_city_ids.has(connection.from_city_id)
				and not connected_city_ids.has(connection.to_city_id)
			):
				connected_city_ids[connection.to_city_id] = true
				found_new_city = true
			elif (
				connected_city_ids.has(connection.to_city_id)
				and not connected_city_ids.has(connection.from_city_id)
			):
				connected_city_ids[connection.from_city_id] = true
				found_new_city = true
	_expect(
		connected_city_ids.size() == map_definition.cities.size(),
		"The provisional road network should connect all cities."
	)
	_expect(
		map_definition.find_city("paris").is_center_of_gravity,
		"Paris should be an Allied COG."
	)
	_expect(
		map_definition.find_city("koblenz").is_center_of_gravity,
		"Koblenz should be a German COG."
	)

	if _failures == 0:
		print("Game map definition unit tests passed.")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
