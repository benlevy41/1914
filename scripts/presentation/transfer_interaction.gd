extends Node

signal started(source_id: String)
signal target_selected(target_id: String)
signal status_changed(message: String)
signal completed(result: GameActionResult, source_id: String, target_id: String, action: int)
signal cancelled(message: String)
signal prompt_visibility_changed

enum Action { NONE, OCCUPY, REORGANIZE }

const UnitPromptScript = preload("res://scripts/presentation/unit_prompt.gd")

var _application: GameApplication
var _board: BoardView
var _prompt: UnitPromptScript
var _action: Action = Action.NONE
var _source_id: String = ""
var _target_id: String = ""
var _targeting: bool = false


func configure(application: GameApplication, board: BoardView, screen: Control) -> void:
	_application = application
	_board = board
	_prompt = UnitPromptScript.new()
	_prompt.name = "TransferPrompt"
	screen.add_child(_prompt)
	_prompt.confirm_requested.connect(_confirm)
	_prompt.cancel_requested.connect(_cancel)
	_prompt.visibility_changed.connect(func() -> void: prompt_visibility_changed.emit())


func is_targeting() -> bool:
	return _targeting


func is_pending() -> bool:
	return _prompt.is_pending()


func availability(
	action: Action, snapshot: GameViewSnapshot, source_id: String, awaiting_defender: bool
) -> String:
	if awaiting_defender:
		return "Finish or cancel the pending defender decision first."
	var source_result := (
		_application.validate_attack_source(source_id) if action == Action.OCCUPY
		else _application.validate_reorganization_source(source_id)
	)
	if not source_result.succeeded():
		return source_result.error_message
	if not _targets(action, snapshot, source_id).is_empty():
		return ""
	if action == Action.OCCUPY:
		return "No legal adjacent empty city; occupation must leave a unit in the source."
	return "No occupied friendly city is reachable from this source."


func begin(action: Action, snapshot: GameViewSnapshot, source_id: String) -> void:
	var message := availability(action, snapshot, source_id, false)
	if not message.is_empty():
		status_changed.emit(message)
		return
	clear()
	_action = action
	_source_id = source_id
	_targeting = true
	started.emit(source_id)
	_board.set_target_cities(_targets(action, snapshot, source_id))
	status_changed.emit("Select a highlighted city to %s." % (
		"occupy" if action == Action.OCCUPY else "move units to"
	))


func select_target(city_id: String) -> void:
	var result := _validate(_action, _source_id, city_id, 1)
	if not result.succeeded():
		_board.select_city(_source_id)
		status_changed.emit(result.error_message)
		return
	var snapshot := _application.get_view_snapshot()
	if snapshot == null:
		_cancel_with_message("Could not retrieve the game state for this transfer.")
		return
	var source := snapshot.find_city(_source_id)
	var target := snapshot.find_city(city_id)
	if source == null or target == null:
		_cancel_with_message("The source or destination city is no longer available.")
		return
	_target_id = city_id
	_targeting = false
	_board.set_target_cities([])
	var occupation := _action == Action.OCCUPY
	var maximum := source.unit_count - 1 if occupation else source.unit_count
	var text := (
		"Choose units to occupy %s from %s." % [target.name, source.name]
		if occupation else "Choose units to move from %s to %s." % [source.name, target.name]
	)
	_prompt.show_for(_board, city_id, text, maximum, not occupation)
	target_selected.emit(city_id)


func refresh(snapshot: GameViewSnapshot) -> String:
	if _action == Action.NONE:
		return ""
	var expected_phase := (
		GameViewSnapshot.Phase.ATTACK if _action == Action.OCCUPY
		else GameViewSnapshot.Phase.REORGANIZATION
	)
	if not snapshot.winner_id.is_empty() or snapshot.phase != expected_phase:
		clear()
		return "The pending transfer was cancelled because the game phase changed."
	if not _targeting:
		return ""
	var message := availability(_action, snapshot, _source_id, false)
	if not message.is_empty():
		clear()
		return message
	_board.set_target_cities(_targets(_action, snapshot, _source_id))
	return ""


func clear() -> void:
	if _targeting:
		_board.set_target_cities([])
	_targeting = false
	_action = Action.NONE
	_source_id = ""
	_target_id = ""
	_prompt.dismiss()


func _targets(action: Action, snapshot: GameViewSnapshot, source_id: String) -> Array[String]:
	var targets: Array[String] = []
	for city: GameViewSnapshot.CityView in snapshot.cities:
		if _validate(action, source_id, city.id, 1).succeeded():
			targets.append(city.id)
	return targets


func _validate(
	action: Action, source_id: String, target_id: String, units: int
) -> GameActionResult:
	if action == Action.OCCUPY:
		return _application.validate_occupation(source_id, target_id, units)
	if action == Action.REORGANIZE:
		return _application.validate_reorganization_move(source_id, target_id, units)
	return GameActionResult.new("Choose a transfer action first.")


func _confirm(units: int) -> void:
	var result := (
		_application.occupy_city(_source_id, _target_id, units)
		if _action == Action.OCCUPY
		else _application.move_reorganization_units(_source_id, _target_id, units)
	)
	var source_id := _source_id
	var target_id := _target_id
	var action := _action
	clear()
	completed.emit(result, source_id, target_id, action)


func _cancel() -> void:
	_cancel_with_message(
		"Occupation cancelled." if _action == Action.OCCUPY else "Transfer cancelled."
	)


func _cancel_with_message(message: String) -> void:
	clear()
	cancelled.emit(message)
