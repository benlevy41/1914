extends Control

enum DevelopmentUnitChange {
	ADD,
	REMOVE,
}

const GameApplicationScript = preload("res://scripts/application/game_application.gd")
const CityContextMenuScript = preload("res://scripts/presentation/city_context_menu.gd")
const CombatPromptScript = preload("res://scripts/presentation/combat_prompt.gd")
const CombatFeedbackScript = preload("res://scripts/presentation/combat_feedback.gd")
const DevelopmentUnitDialogScript = preload("res://scripts/presentation/development_unit_dialog.gd")
const TransferInteractionScript = preload("res://scripts/presentation/transfer_interaction.gd")
const GameStartMenuScript = preload("res://scripts/presentation/game_start_menu.gd")

var _game_application: GameApplication
var _game_snapshot: GameViewSnapshot
var _city_context_menu: CityContextMenuScript
var _combat_prompt: CombatPromptScript
var _combat_feedback: CombatFeedbackScript
var _transfer: TransferInteractionScript
var _unit_change_dialog: DevelopmentUnitDialogScript
var _context_city_id: String = ""
var _context_menu_hint: String = ""
var _pending_unit_change: DevelopmentUnitChange
var _selected_city_id: String = ""
var _attack_source_city_id: String = ""
var _attack_target_city_id: String = ""
var _contextual_attack_targeting: bool = false
var _reorganization_source_city_id: String = ""
var _reorganization_target_city_id: String = ""
var _awaiting_defender_commitment: bool = false
var _displayed_phase: int = -1

@onready var _selected_city_label: Label = $MarginContainer/Content/MainLayout/Sidebar/SelectedCity
@onready var _board: BoardView = $MarginContainer/Content/MainLayout/Board
@onready var _hud: GameHUD = $MarginContainer/Content/GameHUD
@onready var _title: Label = $MarginContainer/Content/Title
@onready var _menu_panel: VBoxContainer = $MarginContainer/Content/MenuPanel
@onready var _setup_panel: VBoxContainer = $MarginContainer/Content/SetupPanel
@onready var _game_panel: HBoxContainer = $MarginContainer/Content/MainLayout
@onready var _game_status: Label = $MarginContainer/Content/GameStatus
@onready var _turn_status: Label = $MarginContainer/Content/MainLayout/Sidebar/TurnStatus
@onready var _phase_action_button: Button = $MarginContainer/Content/MainLayout/Sidebar/PhaseAction
@onready var _attack_panel: VBoxContainer = $MarginContainer/Content/MainLayout/Sidebar/AttackPanel
@onready var _attack_selection: Label = (
	$MarginContainer/Content/MainLayout/Sidebar/AttackPanel/AttackSelection
)
@onready var _attacker_commitment: SpinBox = (
	$MarginContainer/Content/MainLayout/Sidebar/AttackPanel/AttackerCommitment
)
@onready var _defender_prompt: Label = (
	$MarginContainer/Content/MainLayout/Sidebar/AttackPanel/DefenderPrompt
)
@onready var _defender_commitment: SpinBox = (
	$MarginContainer/Content/MainLayout/Sidebar/AttackPanel/DefenderCommitment
)
@onready var _occupation_commitment: SpinBox = (
	$MarginContainer/Content/MainLayout/Sidebar/AttackPanel/OccupationCommitment
)
@onready var _attack_result: Label = (
	$MarginContainer/Content/MainLayout/Sidebar/AttackPanel/AttackResult
)
@onready var _attack_action_button: Button = (
	$MarginContainer/Content/MainLayout/Sidebar/AttackPanel/AttackAction
)
@onready var _end_attack_button: Button = (
	$MarginContainer/Content/MainLayout/Sidebar/AttackPanel/EndAttack
)
@onready var _reorganization_panel: VBoxContainer = (
	$MarginContainer/Content/MainLayout/Sidebar/ReorganizationPanel
)
@onready var _reorganization_selection: Label = (
	$MarginContainer/Content/MainLayout/Sidebar/ReorganizationPanel/ReorganizationSelection
)
@onready var _reorganization_commitment: SpinBox = (
	$MarginContainer/Content/MainLayout/Sidebar/ReorganizationPanel/ReorganizationCommitment
)
@onready var _move_units_button: Button = (
	$MarginContainer/Content/MainLayout/Sidebar/ReorganizationPanel/MoveUnits
)
@onready var _end_reorganization_button: Button = (
	$MarginContainer/Content/MainLayout/Sidebar/ReorganizationPanel/EndReorganization
)

func _ready() -> void:
	var random_generator := RandomNumberGenerator.new()
	random_generator.randomize()
	_game_application = GameApplicationScript.new(random_generator)
	_city_context_menu = CityContextMenuScript.new()
	_city_context_menu.name = "CityContextMenu"
	_city_context_menu.exclusive = false
	_city_context_menu.id_pressed.connect(_on_city_context_menu_id_pressed)
	_city_context_menu.configure_retarget(_try_open_city_context)
	add_child(_city_context_menu)
	_city_context_menu.visibility_changed.connect(_update_board_navigation)
	_city_context_menu.visibility_changed.connect(_on_context_menu_visibility_changed)
	_unit_change_dialog = DevelopmentUnitDialogScript.new()
	_unit_change_dialog.confirmed.connect(_on_unit_change_confirmed)
	add_child(_unit_change_dialog)
	_unit_change_dialog.visibility_changed.connect(_update_board_navigation)
	_combat_prompt = CombatPromptScript.new()
	add_child(_combat_prompt)
	_combat_prompt.completed.connect(_on_contextual_combat_completed)
	_combat_prompt.cancelled.connect(_on_contextual_combat_cancelled)
	_combat_prompt.visibility_changed.connect(_update_board_navigation)
	_combat_feedback = CombatFeedbackScript.new()
	_board.add_child(_combat_feedback)
	_combat_feedback.attach_summary(_attack_panel.get_parent() as Container)
	_transfer = TransferInteractionScript.new()
	add_child(_transfer)
	_transfer.configure(_game_application, _board, self)
	_transfer.started.connect(_on_transfer_started)
	_transfer.target_selected.connect(_on_transfer_target_selected)
	_transfer.status_changed.connect(_turn_status.set_text)
	_transfer.completed.connect(_on_transfer_completed)
	_transfer.cancelled.connect(_on_contextual_combat_cancelled)
	_transfer.prompt_visibility_changed.connect(_update_board_navigation)
	var start_menu := GameStartMenuScript.new()
	add_child(start_menu)
	start_menu.configure(_game_application, self)
	start_menu.game_started.connect(_show_game)
	_phase_action_button.pressed.connect(_on_phase_action_pressed)
	_attack_action_button.pressed.connect(_on_attack_action_pressed)
	_end_attack_button.pressed.connect(_on_end_attack_pressed)
	_move_units_button.pressed.connect(_on_move_units_pressed)
	_end_reorganization_button.pressed.connect(_on_end_reorganization_pressed)
	_setup_panel.hide()
	_game_panel.hide()
	_city_context_menu.hide()
	_unit_change_dialog.hide()
	_attack_panel.hide()
	_reorganization_panel.hide()
	_phase_action_button.disabled = true


func _update_board_navigation() -> void:
	_board.set_navigation_blocked(
		_city_context_menu.visible or _unit_change_dialog.visible or _combat_prompt.is_pending()
		or _transfer.is_pending()
	)


func _on_context_menu_visibility_changed() -> void:
	if not _city_context_menu.visible and not _context_menu_hint.is_empty():
		if _turn_status.text == _context_menu_hint:
			_update_phase_status()
		_context_menu_hint = ""


func _input(event: InputEvent) -> void:
	if (
		_game_snapshot == null
		or _unit_change_dialog.visible
		or _combat_prompt.is_pending()
		or _transfer.is_pending()
		or not (event is InputEventMouseButton)
		or event.button_index != MOUSE_BUTTON_RIGHT
		or not event.pressed
	):
		return

	if _try_open_city_context(event.global_position):
		get_viewport().set_input_as_handled()


func _try_open_city_context(screen_position: Vector2) -> bool:
	var city_id := _board.get_city_id_at_position(screen_position)
	if city_id.is_empty():
		return false
	return _on_city_context_requested(city_id, screen_position)


func _show_game() -> void:
	if not _refresh_game_view():
		return
	_board.city_selected.connect(_on_city_selected)
	_board.selection_cleared.connect(_on_board_selection_cleared)
	_board.city_context_requested.connect(_on_city_context_requested)
	_board.configure(_game_snapshot)
	_game_status.text = (
		"Territories assigned. Each city has one infantry unit. "
		+ "Now place the initial reserve units."
	)
	_update_phase_status()
	_menu_panel.hide()
	_setup_panel.hide()
	_title.hide()
	_hud.show()
	_game_panel.show()


func _refresh_game_view() -> bool:
	var snapshot := _game_application.get_view_snapshot()
	if snapshot == null:
		push_error("The application could not provide a game view snapshot.")
		return false
	_game_snapshot = snapshot
	_board.refresh_snapshot(_game_snapshot)
	_hud.update_snapshot(_game_snapshot)
	_refresh_contextual_attack_targets()
	var transfer_message := _transfer.refresh(_game_snapshot)
	if not transfer_message.is_empty():
		_update_phase_status()
		if _game_snapshot.winner_id.is_empty():
			_turn_status.text = transfer_message
	if _combat_prompt.is_pending() and (
		_game_snapshot.phase != GameViewSnapshot.Phase.ATTACK
		or not _game_snapshot.winner_id.is_empty()
	):
		_update_phase_status()
	return true


func _attack_targets(source_city_id: String) -> Array[String]:
	var targets: Array[String] = []
	for city: GameViewSnapshot.CityView in _game_snapshot.cities:
		if _game_application.validate_attack(source_city_id, city.id, 1).succeeded():
			targets.append(city.id)
	return targets


func _refresh_contextual_attack_targets() -> void:
	if not _contextual_attack_targeting:
		return
	var source_result := _game_application.validate_attack_source(_attack_source_city_id)
	var targets := _attack_targets(_attack_source_city_id)
	var message := source_result.error_message
	if source_result.succeeded() and targets.is_empty():
		message = "No adjacent enemy city can be attacked from the selected city."
	if not message.is_empty():
		_clear_contextual_attack()
		_attack_source_city_id = ""
		_attack_target_city_id = ""
		_update_phase_status()
		_turn_status.text = message
		return
	_board.set_target_cities(targets)


func _clear_contextual_attack() -> void:
	_contextual_attack_targeting = false
	_board.set_target_cities([])


func _on_city_context_requested(city_id: String, screen_position: Vector2) -> bool:
	if (
		_game_snapshot == null or not _game_snapshot.winner_id.is_empty()
		or _combat_prompt.is_pending() or _transfer.is_pending()
	):
		return false

	var city := _game_snapshot.find_city(city_id)
	if city == null:
		push_error("Cannot show a context menu for unknown city '%s'." % city_id)
		return false

	if _city_context_menu.visible:
		_city_context_menu.hide()
	_context_city_id = city_id
	_city_context_menu.clear()
	var initial := _game_snapshot.phase == GameViewSnapshot.Phase.INITIAL_RESERVE_PLACEMENT
	if initial or (
		_game_snapshot.phase == GameViewSnapshot.Phase.REINFORCEMENT_PLACEMENT
		and _game_snapshot.reinforcements_remaining > 0
	):
		_update_phase_status()
		_turn_status.text = _city_context_menu.add_placement_item(city, _game_application, initial)
		_context_menu_hint = _turn_status.text
	elif _game_snapshot.phase == GameViewSnapshot.Phase.ATTACK:
		_add_attack_menu_item(city)
		_add_transfer_menu_item(city, TransferInteractionScript.Action.OCCUPY)
	elif _game_snapshot.phase == GameViewSnapshot.Phase.REORGANIZATION:
		_add_transfer_menu_item(city, TransferInteractionScript.Action.REORGANIZE)
	if _game_snapshot.dev_mode_active:
		if _city_context_menu.item_count > 0:
			_city_context_menu.add_separator("Developer tools")
		_city_context_menu.add_development_items(city, _game_snapshot)
	if _city_context_menu.item_count == 0:
		return false
	_city_context_menu.popup_near(screen_position)
	return true


func _add_attack_menu_item(city: GameViewSnapshot.CityView) -> void:
	var validation := _game_application.validate_attack_source(city.id)
	var has_targets := not _attack_targets(city.id).is_empty() if validation.succeeded() else false
	var message := _city_context_menu.add_attack_item(
		city, validation, has_targets, _awaiting_defender_commitment
	)
	_update_phase_status()
	_turn_status.text = message if not message.is_empty() else "Attack from %s." % city.name
	_context_menu_hint = _turn_status.text


func _add_transfer_menu_item(city: GameViewSnapshot.CityView, action: int) -> void:
	var message := _transfer.availability(
		action, _game_snapshot, city.id, _awaiting_defender_commitment
	)
	var item_id := (
		CityContextMenuScript.OCCUPY if action == TransferInteractionScript.Action.OCCUPY
		else CityContextMenuScript.MOVE_UNITS
	)
	_city_context_menu.add_transfer_item(item_id, message)
	if action == TransferInteractionScript.Action.REORGANIZE:
		_update_phase_status()
		_turn_status.text = message if not message.is_empty() else "Move units from %s." % city.name
		_context_menu_hint = _turn_status.text


func _on_city_context_menu_id_pressed(item_id: int) -> void:
	if _context_city_id.is_empty():
		push_error("Cannot use a city context-menu action without a city.")
		return
	if item_id in [
		CityContextMenuScript.PLACE_REINFORCEMENT, CityContextMenuScript.PLACE_INITIAL_RESERVE
	]:
		_place_context_reinforcement(item_id == CityContextMenuScript.PLACE_INITIAL_RESERVE)
		return
	if item_id == CityContextMenuScript.ATTACK:
		_begin_contextual_attack()
		return
	if item_id == CityContextMenuScript.OCCUPY or item_id == CityContextMenuScript.MOVE_UNITS:
		if _awaiting_defender_commitment:
			_turn_status.text = "Finish or cancel the pending defender decision first."
			return
		var action := (
			TransferInteractionScript.Action.OCCUPY if item_id == CityContextMenuScript.OCCUPY
			else TransferInteractionScript.Action.REORGANIZE
		)
		_transfer.begin(action, _game_snapshot, _context_city_id)
		return
	if not _game_snapshot.dev_mode_active:
		_turn_status.text = "Developer tools are unavailable in this game."
		return
	if item_id == CityContextMenuScript.ADD_UNITS:
		_open_unit_change_dialog(DevelopmentUnitChange.ADD)
		return
	if item_id == CityContextMenuScript.REMOVE_UNITS:
		_open_unit_change_dialog(DevelopmentUnitChange.REMOVE)
		return
	if item_id != CityContextMenuScript.CHANGE_CITY_OWNER:
		return

	var result := _game_application.change_city_owner_for_development(_context_city_id)
	if not result.succeeded():
		_turn_status.text = result.error_message
		return

	if not _refresh_game_view():
		return
	if _selected_city_id == _context_city_id:
		_update_selected_city_label(_game_snapshot.find_city(_selected_city_id))
		_update_phase_status()
	var city := _game_snapshot.find_city(_context_city_id)
	if city == null:
		push_error("Cannot display updated state for unknown city '%s'." % _context_city_id)
		return
	_turn_status.text = "%s is now owned by %s." % [city.name, city.owner_name]
	if not _game_snapshot.winner_id.is_empty():
		_update_phase_status()


func _place_context_reinforcement(initial: bool) -> void:
	var result := (
		_game_application.place_initial_reserve(_context_city_id) if initial
		else _game_application.place_reinforcement(_context_city_id)
	)
	if not result.succeeded():
		_turn_status.text = result.error_message
		return
	if not _refresh_game_view():
		return
	var city := _game_snapshot.find_city(_context_city_id)
	if city == null:
		push_error("Cannot display updated state for unknown city '%s'." % _context_city_id)
		return
	if _selected_city_id == city.id:
		_update_selected_city_label(city)
	_update_phase_status()
	if not initial:
		_turn_status.text = "Placed one reinforcement in %s." % city.name


func _begin_contextual_attack() -> void:
	if _awaiting_defender_commitment:
		_turn_status.text = "Finish or cancel the pending defender decision first."
		return
	var validation := _game_application.validate_attack_source(_context_city_id)
	if not validation.succeeded():
		_turn_status.text = validation.error_message
		return
	var targets := _attack_targets(_context_city_id)
	if targets.is_empty():
		_turn_status.text = "No adjacent enemy city can be attacked from %s." % (
			_city_display_name(_context_city_id)
		)
		return
	_transfer.clear()
	_contextual_attack_targeting = true
	_attack_source_city_id = _context_city_id
	_attack_target_city_id = ""
	_selected_city_id = _context_city_id
	_board.select_city(_context_city_id)
	_board.set_target_cities(targets)
	_update_selected_city_label(_game_snapshot.find_city(_context_city_id))
	_update_phase_status()
	_turn_status.text = "Select a highlighted enemy city to attack."


func _open_unit_change_dialog(change: DevelopmentUnitChange) -> void:
	var city := _game_snapshot.find_city(_context_city_id)
	if city == null:
		push_error("Cannot change units for unknown city '%s'." % _context_city_id)
		return
	_pending_unit_change = change
	var message := _unit_change_dialog.open_for(
		city, _game_snapshot, change == DevelopmentUnitChange.ADD
	)
	if not message.is_empty():
		_turn_status.text = message


func _on_unit_change_confirmed() -> void:
	if _context_city_id.is_empty():
		push_error("Cannot apply a unit change without a context-menu city.")
		return

	var unit_count := int(_unit_change_dialog.unit_selector.value)
	var result := _unit_change_dialog.apply_change(
		_game_application, _context_city_id, _pending_unit_change == DevelopmentUnitChange.ADD
	)
	if not result.succeeded():
		_turn_status.text = result.error_message
		return

	if not _refresh_game_view():
		return
	if _selected_city_id == _context_city_id:
		_update_selected_city_label(_game_snapshot.find_city(_selected_city_id))
		_update_phase_status()
	var city := _game_snapshot.find_city(_context_city_id)
	if city == null:
		push_error("Cannot display updated state for unknown city '%s'." % _context_city_id)
		return
	_turn_status.text = _unit_change_dialog.action_message(
		city, unit_count, _pending_unit_change == DevelopmentUnitChange.ADD
	)
	if not _game_snapshot.winner_id.is_empty():
		_update_phase_status()


func _on_board_selection_cleared() -> void:
	_combat_prompt.dismiss()
	_transfer.clear()
	_clear_contextual_attack()
	_selected_city_id = ""
	_attack_source_city_id = ""
	_attack_target_city_id = ""
	_reorganization_source_city_id = ""
	_reorganization_target_city_id = ""
	_awaiting_defender_commitment = false
	_attacker_commitment.value = 1
	_defender_commitment.value = 1
	_occupation_commitment.value = 1
	_reorganization_commitment.value = 1
	_selected_city_label.text = "Select a city on the board."
	_update_phase_status()


func _on_city_selected(city_id: String) -> void:
	var city := _game_snapshot.find_city(city_id)
	if city == null:
		push_error("Cannot display selection for unknown city '%s'." % city_id)
		return

	if _contextual_attack_targeting:
		_select_contextual_attack_target(city_id)
		return
	if _transfer.is_targeting():
		_transfer.select_target(city_id)
		return
	_selected_city_id = city_id
	var attack_selection_result := GameActionResult.new()
	var reorganization_selection_result := GameActionResult.new()
	if (
		_game_snapshot.phase == GameViewSnapshot.Phase.ATTACK
		and not _awaiting_defender_commitment
	):
		attack_selection_result = _update_attack_selection(city_id)
	elif _game_snapshot.phase == GameViewSnapshot.Phase.REORGANIZATION:
		reorganization_selection_result = _update_reorganization_selection(city_id)
	_update_selected_city_label(city)
	_update_phase_status()
	if not attack_selection_result.succeeded():
		_turn_status.text = attack_selection_result.error_message
	elif not reorganization_selection_result.succeeded():
		_turn_status.text = reorganization_selection_result.error_message


func _select_contextual_attack_target(city_id: String) -> void:
	var result := _game_application.validate_attack(_attack_source_city_id, city_id, 1)
	if not result.succeeded():
		_board.select_city(_attack_source_city_id)
		_turn_status.text = result.error_message
		return
	_attack_target_city_id = city_id
	_selected_city_id = city_id
	_clear_contextual_attack()
	_update_selected_city_label(_game_snapshot.find_city(city_id))
	_combat_prompt.start(_game_application, _board, _attack_source_city_id, city_id)
	if _combat_prompt.is_pending():
		_update_phase_status()


func _on_contextual_combat_cancelled(message: String) -> void:
	if not _refresh_game_view():
		return
	_board.clear_selection()
	_on_board_selection_cleared()
	_turn_status.text = message


func _on_transfer_started(source_id: String) -> void:
	_clear_contextual_attack()
	_attack_source_city_id = ""
	_attack_target_city_id = ""
	_reorganization_source_city_id = ""
	_reorganization_target_city_id = ""
	_selected_city_id = source_id
	_board.select_city(source_id)
	_update_selected_city_label(_game_snapshot.find_city(source_id))
	_update_phase_status()


func _on_transfer_target_selected(city_id: String) -> void:
	_selected_city_id = city_id
	_update_selected_city_label(_game_snapshot.find_city(city_id))
	_update_phase_status()


func _on_transfer_completed(
	result: GameActionResult, source_id: String, target_id: String, action: int
) -> void:
	if not result.succeeded():
		_on_contextual_combat_cancelled(result.error_message)
		return
	if not _refresh_game_view():
		return
	_update_selected_city_label(_game_snapshot.find_city(target_id))
	_update_phase_status()
	if _game_snapshot.winner_id.is_empty():
		_turn_status.text = (
			"%s occupied %s." % [_city_display_name(source_id), _city_display_name(target_id)]
			if action == TransferInteractionScript.Action.OCCUPY
			else "Moved units from %s to %s." % [
				_city_display_name(source_id), _city_display_name(target_id)
			]
		)


func _on_contextual_combat_completed(result: CombatRoundResult, before: GameViewSnapshot) -> void:
	if not result.succeeded():
		_on_contextual_combat_cancelled(result.error_message)
		return
	_show_combat_result(result, before)


func _update_selected_city_label(city: GameViewSnapshot.CityView) -> void:
	var owner_name := city.owner_name if not city.owner_name.is_empty() else "Unoccupied"
	var unit_label := "unit" if city.unit_count == 1 else "units"
	_selected_city_label.text = "%s - %s, %d %s" % [
		city.name, owner_name, city.unit_count, unit_label,
	]


func _on_phase_action_pressed() -> void:
	var result: GameActionResult
	if _game_snapshot.phase == GameViewSnapshot.Phase.INITIAL_RESERVE_PLACEMENT:
		if _selected_city_id.is_empty():
			_turn_status.text = "Select one of your cities first."
			return
		result = _game_application.place_initial_reserve(_selected_city_id)
	elif _game_snapshot.phase == GameViewSnapshot.Phase.REINFORCEMENT_PLACEMENT:
		if _game_snapshot.reinforcements_remaining == 0:
			result = _game_application.begin_attack_phase()
		else:
			if _selected_city_id.is_empty():
				_turn_status.text = "Select a city to reinforce."
				return
			result = _game_application.place_reinforcement(_selected_city_id)
	else:
		return

	if not result.succeeded():
		_turn_status.text = result.error_message
		return

	if not _refresh_game_view():
		return
	if not _selected_city_id.is_empty():
		_on_city_selected(_selected_city_id)
	else:
		_update_phase_status()


func _update_attack_selection(city_id: String) -> GameActionResult:
	if _attack_source_city_id.is_empty() or not _attack_target_city_id.is_empty():
		_attack_source_city_id = ""
		_attack_target_city_id = ""
		var validation_result := _game_application.validate_attack_source(city_id)
		if not validation_result.succeeded():
			_update_attack_selection_label()
			return validation_result
		_attack_source_city_id = city_id
	elif city_id != _attack_source_city_id:
		var validation_result := _game_application.validate_attack_target(city_id)
		if not validation_result.succeeded():
			_update_attack_selection_label()
			return validation_result
		_attack_target_city_id = city_id
	_update_attack_selection_label()
	return GameActionResult.new()


func _update_attack_selection_label() -> void:
	var source_name := _city_display_name(_attack_source_city_id)
	var target_name := _city_display_name(_attack_target_city_id)
	if source_name.is_empty():
		_attack_selection.text = "Select an attacking city, then a target."
	elif target_name.is_empty():
		_attack_selection.text = "Attacking from %s. Select a target." % source_name
	else:
		_attack_selection.text = "%s attacks %s." % [source_name, target_name]


func _city_display_name(city_id: String) -> String:
	if city_id.is_empty():
		return ""
	var city := _game_snapshot.find_city(city_id)
	if city == null:
		push_error("Cannot display unknown map city '%s'." % city_id)
		return ""
	return city.name


func _on_attack_action_pressed() -> void:
	if _awaiting_defender_commitment:
		_resolve_attack_round()
		return

	var attacking_city := _game_snapshot.find_city(_attack_source_city_id)
	var target_city := _game_snapshot.find_city(_attack_target_city_id)
	if attacking_city == null or target_city == null:
		_turn_status.text = "Select an attacking city and a target first."
		return
	if target_city.owner_id.is_empty() or target_city.unit_count == 0:
		_occupy_selected_city()
		return

	var attacker_commitment := int(_attacker_commitment.value)
	var validation_result := _game_application.validate_attack(
		_attack_source_city_id,
		_attack_target_city_id,
		attacker_commitment
	)
	if not validation_result.succeeded():
		_turn_status.text = validation_result.error_message
		return

	_awaiting_defender_commitment = true
	_defender_prompt.text = "%s: choose defending units." % target_city.owner_name
	_defender_commitment.min_value = 1
	_defender_commitment.max_value = target_city.unit_count
	_defender_commitment.value = 1
	_update_phase_status()


func _resolve_attack_round() -> void:
	var before := _game_application.get_view_snapshot()
	if before == null:
		_turn_status.text = "Could not retrieve the game state for this attack."
		return
	var result: CombatRoundResult = _game_application.resolve_attack_round(
		_attack_source_city_id,
		_attack_target_city_id,
		int(_attacker_commitment.value),
		int(_defender_commitment.value)
	)
	if not result.succeeded():
		_awaiting_defender_commitment = false
		_update_phase_status()
		_turn_status.text = result.error_message
		return

	_awaiting_defender_commitment = false
	_show_combat_result(result, before)


func _show_combat_result(result: CombatRoundResult, before: GameViewSnapshot) -> void:
	_attack_result.text = _combat_feedback.describe_result(result)
	_attack_result.hide()
	if not _refresh_game_view():
		return
	var selected := _game_snapshot.find_city(_selected_city_id)
	if selected != null:
		_update_selected_city_label(selected)
	_combat_feedback.show_result(result, before, _attack_source_city_id, _attack_target_city_id)
	if result.units_advanced > 0:
		_attack_source_city_id = ""
		_attack_target_city_id = ""
	_update_phase_status()


func _occupy_selected_city() -> void:
	if _attack_source_city_id.is_empty() or _attack_target_city_id.is_empty():
		_turn_status.text = "Select an attacking city and an unoccupied target."
		return
	var result := _game_application.occupy_city(
		_attack_source_city_id,
		_attack_target_city_id,
		int(_occupation_commitment.value)
	)
	if not result.succeeded():
		_turn_status.text = result.error_message
		return

	_attack_result.text = "%s occupied %s." % [
		_city_display_name(_attack_source_city_id), _city_display_name(_attack_target_city_id)]
	_attack_result.show()
	_attack_target_city_id = ""
	if not _refresh_game_view():
		return
	_update_attack_selection_label()
	_update_phase_status()


func _on_end_attack_pressed() -> void:
	var result := _game_application.end_attack_phase()
	if not result.succeeded():
		_turn_status.text = result.error_message
		_update_phase_status()
		return
	if not _refresh_game_view():
		return
	_update_phase_status()


func _update_reorganization_selection(city_id: String) -> GameActionResult:
	if _reorganization_source_city_id.is_empty() or not _reorganization_target_city_id.is_empty():
		_reorganization_source_city_id = ""
		_reorganization_target_city_id = ""
		var source_result := _game_application.validate_reorganization_source(city_id)
		if not source_result.succeeded():
			_update_reorganization_controls()
			return source_result
		_reorganization_source_city_id = city_id
	elif city_id != _reorganization_source_city_id:
		var target_result := _game_application.validate_reorganization_move(
			_reorganization_source_city_id,
			city_id,
			1
		)
		if not target_result.succeeded():
			_update_reorganization_controls()
			return target_result
		_reorganization_target_city_id = city_id
	_update_reorganization_controls()
	return GameActionResult.new()


func _on_move_units_pressed() -> void:
	var result := _game_application.move_reorganization_units(
		_reorganization_source_city_id,
		_reorganization_target_city_id,
		int(_reorganization_commitment.value)
	)
	if not result.succeeded():
		_turn_status.text = result.error_message
		return

	var source_name := _city_display_name(_reorganization_source_city_id)
	var target_name := _city_display_name(_reorganization_target_city_id)
	_reorganization_source_city_id = ""
	_reorganization_target_city_id = ""
	if not _refresh_game_view():
		return
	_update_reorganization_controls()
	_turn_status.text = "Moved units from %s to %s." % [source_name, target_name]


func _on_end_reorganization_pressed() -> void:
	var result := _game_application.end_reorganization_phase()
	if not result.succeeded():
		_turn_status.text = result.error_message
		return
	if not _refresh_game_view():
		return
	_update_phase_status()


func _update_reorganization_controls() -> void:
	var source_name := _city_display_name(_reorganization_source_city_id)
	var target_name := _city_display_name(_reorganization_target_city_id)
	if source_name.is_empty():
		_reorganization_selection.text = "Select a source city, then a destination."
	elif target_name.is_empty():
		_reorganization_selection.text = "Moving from %s. Select a destination." % source_name
	else:
		_reorganization_selection.text = "%s to %s." % [source_name, target_name]

	var source_city := _game_snapshot.find_city(_reorganization_source_city_id)
	_move_units_button.disabled = (
		source_city == null or target_name.is_empty() or _transfer.is_pending()
	)
	_end_reorganization_button.disabled = _transfer.is_pending()
	if source_city != null:
		_reorganization_commitment.min_value = 1
		_reorganization_commitment.max_value = maxi(1, source_city.unit_count)
		_reorganization_commitment.value = mini(
			maxi(1, int(_reorganization_commitment.value)),
			source_city.unit_count
		)


func _update_phase_status() -> void:
	($MarginContainer/Content/MainLayout/Sidebar/ReturnToMenu as Button).visible = (
		not _game_snapshot.winner_id.is_empty())
	if not _game_snapshot.winner_id.is_empty():
		_clear_contextual_attack()
		_combat_prompt.dismiss()
		_transfer.clear()
		_game_status.text = (
			"%s wins by capturing the opposing center of gravity and eliminating all enemy forces."
			% _game_snapshot.winner_name
		)
		_turn_status.text = "Game over. %s wins." % _game_snapshot.winner_name
		_phase_action_button.hide()
		_phase_action_button.disabled = true
		_attack_action_button.disabled = true
		_end_attack_button.disabled = true
		_move_units_button.disabled = true
		_end_reorganization_button.disabled = true
		_attack_panel.hide()
		_reorganization_panel.hide()
		_city_context_menu.hide()
		_unit_change_dialog.hide()
		return

	if _displayed_phase != int(_game_snapshot.phase):
		_clear_contextual_attack()
		_combat_prompt.dismiss()
		_transfer.clear()
		if _game_snapshot.phase == GameViewSnapshot.Phase.ATTACK:
			_attack_source_city_id = ""
			_attack_target_city_id = ""
			_awaiting_defender_commitment = false
			_attack_result.text = ""
		if _game_snapshot.phase == GameViewSnapshot.Phase.REORGANIZATION:
			_reorganization_source_city_id = ""
			_reorganization_target_city_id = ""
		if (
			_game_snapshot.phase == GameViewSnapshot.Phase.REINFORCEMENT_PLACEMENT
			and _displayed_phase == int(GameViewSnapshot.Phase.REORGANIZATION)
		):
			_reorganization_source_city_id = ""
			_reorganization_target_city_id = ""
			_selected_city_id = ""
			_board.clear_selection()
			_selected_city_label.text = "Select a city on the board."
		_displayed_phase = int(_game_snapshot.phase)

	if _game_snapshot.phase == GameViewSnapshot.Phase.ACTIVE_PLAY:
		_turn_status.text = "Initial reserve placement complete."
		_phase_action_button.text = "Placement complete"
		_phase_action_button.disabled = true
		_attack_panel.hide()
		_reorganization_panel.hide()
		return

	if _game_snapshot.active_player_name.is_empty():
		push_error("Game view snapshot has no active player for the current phase.")
		return

	if _game_snapshot.phase == GameViewSnapshot.Phase.INITIAL_RESERVE_PLACEMENT:
		_attack_panel.hide()
		_reorganization_panel.hide()
		_phase_action_button.show()
		var active_player := _game_snapshot.find_player(_game_snapshot.active_player_id)
		if active_player == null:
			push_error("Game view snapshot has no active player entry.")
			return
		var reserves_remaining: int = active_player.reserves_remaining
		_turn_status.text = "%s's turn - %d reserve units remaining." % [
			_game_snapshot.active_player_name,
			reserves_remaining,
		]
		_phase_action_button.text = "Place reserve unit"
		_phase_action_button.disabled = _selected_city_id.is_empty()
		return

	if _game_snapshot.phase == GameViewSnapshot.Phase.REINFORCEMENT_PLACEMENT:
		_attack_panel.hide()
		_reorganization_panel.hide()
		_phase_action_button.show()
		_game_status.text = (
			"Reinforcement phase: place units in cities connected to your center of gravity."
		)
		if _game_snapshot.reinforcements_remaining == 0:
			_turn_status.text = (
				"%s has no reinforcements. Begin the attack phase when ready."
				% _game_snapshot.active_player_name
			)
			_phase_action_button.text = "Begin attack phase"
			_phase_action_button.disabled = false
			return

		var reinforcement_unit_label := (
			"unit" if _game_snapshot.reinforcements_remaining == 1 else "units"
		)
		_turn_status.text = "%s's reinforcement phase - %d %s remaining. Right-click a city to place." % [
			_game_snapshot.active_player_name,
			_game_snapshot.reinforcements_remaining,
			reinforcement_unit_label,
		]
		_phase_action_button.hide()
		_phase_action_button.text = "Place reinforcement"
		_phase_action_button.disabled = _selected_city_id.is_empty()
		return

	_phase_action_button.hide()
	if _game_snapshot.phase == GameViewSnapshot.Phase.ATTACK:
		_attack_panel.show()
		_reorganization_panel.hide()
		_game_status.text = (
			"Attack phase: select a source city, then an adjacent target. "
			+ "The defender chooses a commitment for each round."
		)
		if _awaiting_defender_commitment:
			var defending_city := _game_snapshot.find_city(_attack_target_city_id)
			if defending_city != null:
				_turn_status.text = "Pass the controls to %s." % defending_city.owner_name
		else:
			_turn_status.text = "%s's attack phase." % _game_snapshot.active_player_name
		_update_attack_controls()
		return

	_attack_panel.hide()
	_reorganization_panel.show()
	_game_status.text = (
		"Reorganization phase: move units between occupied friendly cities along roads "
		+ "held by your forces. The route need not connect to your center of gravity."
	)
	_turn_status.text = "%s's reorganization phase." % _game_snapshot.active_player_name
	_update_reorganization_controls()


func _update_attack_controls() -> void:
	_update_attack_selection_label()
	var attacking_city := _game_snapshot.find_city(_attack_source_city_id)
	var target_city := _game_snapshot.find_city(_attack_target_city_id)
	_attack_action_button.disabled = true
	_attack_action_button.text = "Attack"
	_attacker_commitment.hide()
	_defender_prompt.hide()
	_defender_commitment.hide()
	_occupation_commitment.hide()
	_end_attack_button.disabled = _awaiting_defender_commitment
	if _combat_prompt.is_pending() or _transfer.is_pending():
		_end_attack_button.disabled = true
		return

	if _awaiting_defender_commitment:
		_defender_prompt.show()
		_defender_commitment.show()
		_attack_action_button.text = "Resolve combat round"
		_attack_action_button.disabled = false
		return
	if attacking_city == null or target_city == null:
		return
	if target_city.owner_id.is_empty() or target_city.unit_count == 0:
		_occupation_commitment.show()
		_occupation_commitment.min_value = 1
		_occupation_commitment.max_value = maxi(1, attacking_city.unit_count - 1)
		_occupation_commitment.value = 1
		_attack_action_button.text = "Occupy target"
		_attack_action_button.disabled = (
			attacking_city.owner_id != _game_snapshot.active_player_id
			or attacking_city.unit_count < 2
		)
		return

	_attacker_commitment.show()
	_attacker_commitment.min_value = 1
	_attacker_commitment.max_value = maxi(1, attacking_city.unit_count - 1)
	_attacker_commitment.value = mini(
		maxi(1, int(_attacker_commitment.value)),
		attacking_city.unit_count - 1
	)
	_attack_action_button.disabled = attacking_city.unit_count < 2
