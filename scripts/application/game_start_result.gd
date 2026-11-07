class_name GameStartResult
extends RefCounted

var game_state: GameState
var error_message: String


func _init(initial_game_state: GameState = null, initial_error_message: String = "") -> void:
	game_state = initial_game_state
	error_message = initial_error_message


func succeeded() -> bool:
	return game_state != null
