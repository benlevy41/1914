class_name GameActionResult
extends RefCounted

var error_message: String


func _init(initial_error_message: String = "") -> void:
	error_message = initial_error_message


func succeeded() -> bool:
	return error_message.is_empty()
