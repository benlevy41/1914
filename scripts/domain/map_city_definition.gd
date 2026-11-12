class_name MapCityDefinition
extends RefCounted

var id: String
var name: String
var latitude: float
var longitude: float
var is_center_of_gravity: bool


func _init(
	city_id: String,
	city_name: String,
	city_latitude: float,
	city_longitude: float,
	center_of_gravity: bool = false
) -> void:
	id = city_id
	name = city_name
	latitude = city_latitude
	longitude = city_longitude
	is_center_of_gravity = center_of_gravity
