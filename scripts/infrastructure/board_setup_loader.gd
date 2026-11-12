class_name BoardSetupLoader
extends RefCounted

const CITIES_CSV_PATH := "res://assets/board_setup/cities.csv"
const ROADS_CSV_PATH := "res://assets/board_setup/roads.csv"
const EXPECTED_CITY_COUNT := 32


func load_western_front() -> BoardSetupLoadResult:
	var city_data := _read_csv(CITIES_CSV_PATH)
	if city_data.has("error"):
		return _failure(city_data["error"])
	var city_headers: PackedStringArray = city_data["headers"]
	var city_rows: Array[PackedStringArray] = city_data["rows"]
	var city_name_column := _column_index(city_headers, "City")
	var latitude_column := _column_index(city_headers, "Lat")
	var longitude_column := _column_index(city_headers, "Lon")
	var value_column := _column_index(city_headers, "Value")
	if min(city_name_column, latitude_column, longitude_column, value_column) < 0:
		return _failure("cities.csv must include City, Lat, Lon, and Value columns.")
	if city_rows.size() != EXPECTED_CITY_COUNT:
		return _failure(
			"Expected %d cities in cities.csv, found %d."
			% [EXPECTED_CITY_COUNT, city_rows.size()]
		)

	var city_definitions: Array[MapCityDefinition] = []
	var city_ids: Dictionary = {}
	for row: PackedStringArray in city_rows:
		var city_name := row[city_name_column].strip_edges()
		if city_name.is_empty():
			return _failure("cities.csv contains a city with an empty name.")
		var city_id := _city_id_from_name(city_name)
		if city_ids.has(city_id):
			return _failure("cities.csv contains duplicate city ID '%s'." % city_id)
		var latitude_text := row[latitude_column].strip_edges()
		var longitude_text := row[longitude_column].strip_edges()
		if not latitude_text.is_valid_float() or not longitude_text.is_valid_float():
			return _failure("City '%s' has an invalid latitude or longitude." % city_name)
		var latitude := latitude_text.to_float()
		var longitude := longitude_text.to_float()
		if (
			not is_finite(latitude)
			or latitude < -90.0
			or latitude > 90.0
			or not is_finite(longitude)
			or longitude < -180.0
			or longitude > 180.0
		):
			return _failure("City '%s' has coordinates outside valid geographic bounds." % city_name)

		city_ids[city_id] = true
		city_definitions.append(
			MapCityDefinition.new(
				city_id,
				city_name,
				latitude,
				longitude,
				city_id == "paris" or city_id == "koblenz"
			)
		)

	if not city_ids.has("paris") or not city_ids.has("koblenz"):
		return _failure("City data must include Paris and Koblenz as centers of gravity.")
	city_definitions.sort_custom(_compare_city_ids)

	var road_data := _read_csv(ROADS_CSV_PATH)
	if road_data.has("error"):
		return _failure(road_data["error"])
	var road_headers: PackedStringArray = road_data["headers"]
	var road_rows: Array[PackedStringArray] = road_data["rows"]
	var from_city_column := _column_index(road_headers, "first_city")
	var to_city_column := _column_index(road_headers, "second_city")
	var road_size_column := _column_index(road_headers, "road_size")
	if min(from_city_column, to_city_column, road_size_column) < 0:
		return _failure(
			"roads.csv must include first_city, second_city, and road_size columns."
		)
	if road_rows.is_empty():
		return _failure("roads.csv must contain at least one road.")

	var connections: Array[MapConnection] = []
	var unique_roads: Dictionary = {}
	for row: PackedStringArray in road_rows:
		var from_city_id := row[from_city_column].strip_edges().to_lower()
		var to_city_id := row[to_city_column].strip_edges().to_lower()
		if not city_ids.has(from_city_id):
			return _failure("Road references unknown city '%s'." % from_city_id)
		if not city_ids.has(to_city_id):
			return _failure(
				"Road from '%s' references unknown city '%s'."
				% [from_city_id, to_city_id]
			)
		if from_city_id == to_city_id:
			return _failure("Road from '%s' cannot connect a city to itself." % from_city_id)
		var road_key := _road_key(from_city_id, to_city_id)
		if unique_roads.has(road_key):
			return _failure(
				"roads.csv contains a duplicate connection between '%s' and '%s'."
				% [from_city_id, to_city_id]
			)

		var road_size_text := row[road_size_column].strip_edges()
		if not road_size_text.is_valid_int() or road_size_text.to_int() < 1:
			return _failure(
				"Road from '%s' has an invalid road_size." % from_city_id
			)
		unique_roads[road_key] = true
		connections.append(
			MapConnection.new(from_city_id, to_city_id, road_size_text.to_int())
		)

	return BoardSetupLoadResult.new(
		GameMapDefinition.new(city_definitions, connections)
	)


func _read_csv(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {
			"error": "Unable to open %s: %s." % [path, error_string(FileAccess.get_open_error())]
		}
	var headers := file.get_csv_line()
	if headers.is_empty():
		return {"error": "%s is empty or has no header row." % path}

	var rows: Array[PackedStringArray] = []
	var row_number := 1
	while not file.eof_reached():
		var row := file.get_csv_line()
		row_number += 1
		if row.size() == 1 and row[0].strip_edges().is_empty():
			continue
		if row.size() != headers.size():
			return {
				"error": "%s row %d has %d fields; expected %d."
				% [path, row_number, row.size(), headers.size()]
			}
		rows.append(row)
	return {"headers": headers, "rows": rows}


func _column_index(headers: PackedStringArray, column_name: String) -> int:
	var found_index := -1
	for index: int in headers.size():
		if headers[index].strip_edges().to_lower() != column_name.to_lower():
			continue
		if found_index >= 0:
			return -2
		found_index = index
	return found_index


func _city_id_from_name(city_name: String) -> String:
	return city_name.to_lower().replace(" ", "_").replace("-", "_")


func _compare_city_ids(first_city: MapCityDefinition, second_city: MapCityDefinition) -> bool:
	return first_city.id < second_city.id


func _road_key(first_city_id: String, second_city_id: String) -> String:
	var city_ids := [first_city_id, second_city_id]
	city_ids.sort()
	return "%s|%s" % [city_ids[0], city_ids[1]]


func _failure(message: String) -> BoardSetupLoadResult:
	return BoardSetupLoadResult.new(null, message)
