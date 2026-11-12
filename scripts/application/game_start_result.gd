class_name GameStartResult
extends RefCounted

var error_message: String
var _succeeded: bool


func _init(was_successful: bool = false, initial_error_message: String = "") -> void:
	_succeeded = was_successful
	error_message = initial_error_message


func succeeded() -> bool:
	return _succeeded
