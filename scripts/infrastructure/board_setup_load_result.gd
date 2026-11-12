class_name BoardSetupLoadResult
extends RefCounted

var map_definition: GameMapDefinition
var error_message: String


func _init(
	loaded_map_definition: GameMapDefinition = null,
	load_error_message: String = ""
) -> void:
	map_definition = loaded_map_definition
	error_message = load_error_message


func succeeded() -> bool:
	return map_definition != null
