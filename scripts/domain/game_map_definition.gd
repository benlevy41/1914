class_name GameMapDefinition
extends RefCounted

var cities: Array[MapCityDefinition]
var connections: Array[MapConnection]


func _init(
	city_definitions: Array[MapCityDefinition],
	city_connections: Array[MapConnection]
) -> void:
	cities = city_definitions
	connections = city_connections


func find_city(city_id: String) -> MapCityDefinition:
	for city: MapCityDefinition in cities:
		if city.id == city_id:
			return city
	return null
