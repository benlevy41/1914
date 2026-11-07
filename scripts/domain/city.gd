class_name GameCity
extends RefCounted

var id: String
var owner_id: String
var unit_count: int


func _init(
	city_id: String,
	city_owner_id: String,
	initial_unit_count: int
) -> void:
	id = city_id
	owner_id = city_owner_id
	unit_count = initial_unit_count


func add_units(amount: int) -> void:
	assert(amount > 0)
	unit_count += amount


func remove_units(amount: int) -> void:
	assert(amount > 0)
	assert(amount <= unit_count)
	unit_count -= amount
