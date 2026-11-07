class_name MapCityDefinition
extends RefCounted

var id: String
var name: String
var position: Vector2
var is_center_of_gravity: bool


func _init(
	city_id: String,
	city_name: String,
	map_position: Vector2,
	center_of_gravity: bool = false
) -> void:
	id = city_id
	name = city_name
	position = map_position
	is_center_of_gravity = center_of_gravity
