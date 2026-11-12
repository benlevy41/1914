class_name MapConnection
extends RefCounted

var from_city_id: String
var to_city_id: String
var road_size: int


func _init(first_city_id: String, second_city_id: String, connection_road_size: int = 1) -> void:
	from_city_id = first_city_id
	to_city_id = second_city_id
	road_size = connection_road_size
