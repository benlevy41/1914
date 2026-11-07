class_name GamePlayer
extends RefCounted

var id: String
var name: String
var center_of_gravity_city_id: String


func _init(
	player_id: String,
	player_name: String,
	player_center_of_gravity_city_id: String = ""
) -> void:
	id = player_id
	name = player_name
	center_of_gravity_city_id = player_center_of_gravity_city_id
