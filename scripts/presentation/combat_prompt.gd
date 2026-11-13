extends "res://scripts/presentation/unit_prompt.gd"

signal completed(result: CombatRoundResult, before: GameViewSnapshot)
signal cancelled(message: String)

enum Stage { NONE, ATTACKER, DEFENDER }

var _stage: Stage = Stage.NONE
var _application: GameApplication
var _source_id: String
var _attacker_units: int


func _ready() -> void:
	name = "CombatPrompt"
	super._ready()
	confirm_requested.connect(_confirm)
	cancel_requested.connect(_cancel)


func is_pending() -> bool:
	return _stage != Stage.NONE


func start(
	application: GameApplication,
	board: BoardView,
	source_id: String,
	target_id: String
) -> void:
	_application = application
	_board = board
	_source_id = source_id
	_target_id = target_id
	var result := _application.validate_attack(source_id, target_id, 1)
	if not result.succeeded():
		cancelled.emit(result.error_message)
		return
	var snapshot := _application.get_view_snapshot()
	if snapshot == null:
		cancelled.emit("Could not retrieve the game state for this attack.")
		return
	var source := snapshot.find_city(source_id)
	var target := snapshot.find_city(target_id)
	if source == null or target == null:
		cancelled.emit("The attacking or defending city is no longer available.")
		return
	_stage = Stage.ATTACKER
	show_for(board, target_id, "%s: choose units to attack %s from %s." % [
		snapshot.active_player_name, target.name, source.name
	], source.unit_count - 1)


func dismiss() -> void:
	_stage = Stage.NONE
	super.dismiss()


func _confirm(units: int) -> void:
	if _stage == Stage.ATTACKER:
		_confirm_attacker(units)
	elif _stage == Stage.DEFENDER:
		var before := _application.get_view_snapshot()
		if before == null:
			dismiss()
			cancelled.emit("Could not retrieve the game state for this attack.")
			return
		var result := _application.resolve_attack_round(
			_source_id, _target_id, _attacker_units, units
		)
		dismiss()
		completed.emit(result, before)


func _confirm_attacker(units: int) -> void:
	_attacker_units = units
	var result := _application.validate_attack(_source_id, _target_id, _attacker_units)
	if not result.succeeded():
		dismiss()
		cancelled.emit(result.error_message)
		return
	var snapshot := _application.get_view_snapshot()
	if snapshot == null:
		dismiss()
		cancelled.emit("Could not retrieve the defending city.")
		return
	var target := snapshot.find_city(_target_id)
	if target == null or target.owner_id.is_empty() or target.unit_count <= 0:
		dismiss()
		cancelled.emit("The defending city is no longer occupied.")
		return
	_stage = Stage.DEFENDER
	show_for(_board, _target_id, "%s: choose units to defend %s." % [
		target.owner_name, target.name
	], target.unit_count)


func _cancel() -> void:
	dismiss()
	cancelled.emit("Attack cancelled.")
