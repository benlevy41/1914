class_name CombatRoundResult
extends RefCounted

var attacker_rolls: Array[int]
var defender_rolls: Array[int]
var attacker_losses: int
var defender_losses: int
var error_message: String


func _init(
	initial_attacker_rolls: Array[int] = [],
	initial_defender_rolls: Array[int] = [],
	initial_attacker_losses: int = 0,
	initial_defender_losses: int = 0,
	initial_error_message: String = ""
) -> void:
	attacker_rolls = initial_attacker_rolls
	defender_rolls = initial_defender_rolls
	attacker_losses = initial_attacker_losses
	defender_losses = initial_defender_losses
	error_message = initial_error_message


func succeeded() -> bool:
	return error_message.is_empty()
