class_name GameStartResult
extends RefCounted

var _succeeded: bool
var error_message: String


func _init(was_successful: bool = false, initial_error_message: String = "") -> void:
	_succeeded = was_successful
	error_message = initial_error_message


func succeeded() -> bool:
	return _succeeded
