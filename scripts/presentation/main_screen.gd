extends Control

enum DevelopmentUnitChange {
	ADD,
	REMOVE,
}

const GameApplicationScript = preload("res://scripts/application/game_application.gd")
const CHANGE_CITY_OWNER_MENU_ITEM_ID := 1
const ADD_UNITS_MENU_ITEM_ID := 2
const REMOVE_UNITS_MENU_ITEM_ID := 3
const PLACE_REINFORCEMENT_MENU_ITEM_ID := 4

var _game_application: GameApplication
var _game_snapshot: GameViewSnapshot
var _city_context_menu: PopupMenu
var _unit_change_dialog: ConfirmationDialog
var _unit_change_selector: SpinBox
var _context_city_id: String = ""
var _context_menu_hint: String = ""
var _pending_unit_change: DevelopmentUnitChange
var _allies_name: String = ""
var _is_entering_german_name: bool = false
var _selected_city_id: String = ""
var _attack_source_city_id: String = ""
var _attack_target_city_id: String = ""
var _reorganization_source_city_id: String = ""
var _reorganization_target_city_id: String = ""
var _awaiting_defender_commitment: bool = false
var _displayed_phase: int = -1

@onready var _selected_city_label: Label = $MarginContainer/Content/MainLayout/Sidebar/SelectedCity
@onready var _board: BoardView = $MarginContainer/Content/MainLayout/Board
@onready var _hud: GameHUD = $MarginContainer/Content/GameHUD
@onready var _title: Label = $MarginContainer/Content/Title
@onready var _menu_panel: VBoxContainer = $MarginContainer/Content/MenuPanel
@onready var _custom_game_button: Button = $MarginContainer/Content/MenuPanel/CustomGame
@onready var _quick_start_button: Button = $MarginContainer/Content/MenuPanel/QuickStart
@onready var _dev_mode_button: Button = $MarginContainer/Content/MenuPanel/DevMode
@onready var _menu_error: Label = $MarginContainer/Content/MenuPanel/Error
@onready var _setup_panel: VBoxContainer = $MarginContainer/Content/SetupPanel
@onready var _setup_prompt: Label = $MarginContainer/Content/SetupPanel/Prompt
@onready var _leader_name_input: LineEdit = $MarginContainer/Content/SetupPanel/LeaderName
@onready var _setup_error: Label = $MarginContainer/Content/SetupPanel/Error
@onready var _continue_button: Button = $MarginContainer/Content/SetupPanel/Continue
@onready var _game_panel: HBoxContainer = $MarginContainer/Content/MainLayout
@onready var _game_status: Label = $MarginContainer/Content/GameStatus
@onready var _dev_mode_indicator: Label = (
	$MarginContainer/Content/GameHUD/Content/Center/Info/DevModeIndicator
)
@onready var _turn_status: Label = $MarginContainer/Content/MainLayout/Sidebar/TurnStatus
@onready var _phase_action_button: Button = $MarginContainer/Content/MainLayout/Sidebar/PhaseAction
@onready var _attack_panel: VBoxContainer = (
	$MarginContainer/Content/MainLayout/Sidebar/AttackPanel
)
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
	_city_context_menu = PopupMenu.new()
	_city_context_menu.name = "CityContextMenu"
	_city_context_menu.exclusive = false
	_city_context_menu.id_pressed.connect(_on_city_context_menu_id_pressed)
	_city_context_menu.window_input.connect(_on_context_menu_input)
	add_child(_city_context_menu)
	_city_context_menu.visibility_changed.connect(_update_board_navigation)
	_city_context_menu.visibility_changed.connect(_on_context_menu_visibility_changed)
	_unit_change_dialog = ConfirmationDialog.new()
	_unit_change_dialog.name = "UnitChangeDialog"
	_unit_change_dialog.title = "Developer unit change"
	_unit_change_dialog.get_ok_button().text = "OK"
	_unit_change_dialog.get_cancel_button().text = "Cancel"
	_unit_change_dialog.confirmed.connect(_on_unit_change_confirmed)
	_unit_change_selector = SpinBox.new()
	_unit_change_selector.name = "UnitCount"
	_unit_change_selector.min_value = 1
	_unit_change_selector.step = 1
	_unit_change_selector.rounded = true
	_unit_change_selector.editable = true
	_unit_change_selector.focus_mode = Control.FOCUS_ALL
	_unit_change_selector.select_all_on_focus = true
	_unit_change_selector.suffix = " units"
	_unit_change_dialog.add_child(_unit_change_selector)
	add_child(_unit_change_dialog)
	_unit_change_dialog.visibility_changed.connect(_update_board_navigation)
	_setup_prompt.text = "Who will lead the Allied forces?"
	_custom_game_button.pressed.connect(_on_custom_game_pressed)
	_quick_start_button.pressed.connect(_on_quick_start_pressed)
	_dev_mode_button.pressed.connect(_on_dev_mode_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	_leader_name_input.text_submitted.connect(_on_leader_name_submitted)
	_phase_action_button.pressed.connect(_on_phase_action_pressed)
	_attack_action_button.pressed.connect(_on_attack_action_pressed)
	_end_attack_button.pressed.connect(_on_end_attack_pressed)
	_move_units_button.pressed.connect(_on_move_units_pressed)
	_end_reorganization_button.pressed.connect(_on_end_reorganization_pressed)
	_setup_panel.hide()
	_game_panel.hide()
	_city_context_menu.hide()
	_unit_change_dialog.hide()
	_dev_mode_button.visible = _game_application.can_start_dev_mode
	_dev_mode_indicator.hide()
	_attack_panel.hide()
	_reorganization_panel.hide()
	_setup_error.text = ""
	_menu_error.text = ""
	_phase_action_button.disabled = true


func _update_board_navigation() -> void:
	_board.set_navigation_blocked(_city_context_menu.visible or _unit_change_dialog.visible)


func _on_context_menu_visibility_changed() -> void:
	if not _city_context_menu.visible and not _context_menu_hint.is_empty():
		if _turn_status.text == _context_menu_hint:
			_update_phase_status()
		_context_menu_hint = ""


func _input(event: InputEvent) -> void:
	if (
		_game_snapshot == null
		or _unit_change_dialog.visible
		or not (event is InputEventMouseButton)
		or event.button_index != MOUSE_BUTTON_RIGHT
		or not event.pressed
	):
		return

	if _try_open_city_context(event.global_position):
		get_viewport().set_input_as_handled()


func _on_context_menu_input(event: InputEvent) -> void:
	# Embedded popups receive outside right-clicks before the parent viewport.
	if (
		not (event is InputEventMouseButton)
		or event.button_index != MOUSE_BUTTON_RIGHT
		or not event.pressed
		or Rect2(Vector2.ZERO, Vector2(_city_context_menu.size)).has_point(event.position)
	):
		return
	var screen_position: Vector2 = event.position + Vector2(_city_context_menu.position)
	if not _city_context_menu.is_embedded():
		screen_position -= Vector2(get_window().position)
	if _try_open_city_context(screen_position):
		_city_context_menu.set_input_as_handled()


func _try_open_city_context(screen_position: Vector2) -> bool:
	var city_id := _board.get_city_id_at_position(screen_position)
	if city_id.is_empty():
		return false
	return _on_city_context_requested(city_id, screen_position)


func _on_custom_game_pressed() -> void:
	_menu_panel.hide()
	_setup_panel.show()
	_leader_name_input.grab_focus()


func _on_quick_start_pressed() -> void:
	var result: GameStartResult = _game_application.start_quick_game()
	if not result.succeeded():
		_menu_error.text = result.error_message
		return
	_show_game()


func _on_dev_mode_pressed() -> void:
	var result: GameStartResult = _game_application.start_dev_mode_game()
	if not result.succeeded():
		_menu_error.text = result.error_message
		return
	_show_game()


func _on_continue_pressed() -> void:
	_submit_current_leader_name()


func _on_leader_name_submitted(_submitted_text: String) -> void:
	_submit_current_leader_name()


func _submit_current_leader_name() -> void:
	var leader_name := _leader_name_input.text.strip_edges()
	if leader_name.is_empty():
		_setup_error.text = "Please enter a name to continue."
		_leader_name_input.grab_focus()
		return

	if not _is_entering_german_name:
		_allies_name = leader_name
		_is_entering_german_name = true
		_setup_prompt.text = "Who will lead the German Empire?"
		_leader_name_input.clear()
		_leader_name_input.placeholder_text = "German Empire leader name"
		_continue_button.text = "Start game"
		_setup_error.text = ""
		_leader_name_input.grab_focus()
		return

	var result: GameStartResult = _game_application.start_new_game(_allies_name, leader_name)
	if not result.succeeded():
		_setup_error.text = result.error_message
		return

	_show_game()


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
	_dev_mode_indicator.visible = _game_snapshot.dev_mode_active
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
	return true


func _on_city_context_requested(city_id: String, screen_position: Vector2) -> bool:
	if (
		_game_snapshot == null
		or not _game_snapshot.winner_id.is_empty()
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
	if (
		_game_snapshot.phase == GameViewSnapshot.Phase.REINFORCEMENT_PLACEMENT
		and _game_snapshot.reinforcements_remaining > 0
	):
		var validation := _game_application.validate_reinforcement(city_id)
		_city_context_menu.add_item("Place reinforcement", PLACE_REINFORCEMENT_MENU_ITEM_ID)
		_city_context_menu.set_item_disabled(0, not validation.succeeded())
		_update_phase_status()
		if not validation.succeeded():
			_turn_status.text = validation.error_message
		else:
			_turn_status.text = "Place one reinforcement in %s." % city.name
		_context_menu_hint = _turn_status.text
	if _game_snapshot.dev_mode_active:
		if _city_context_menu.item_count > 0:
			_city_context_menu.add_separator("Developer tools")
		_add_development_menu_items(city)
	if _city_context_menu.item_count == 0:
		return false
	var popup_position := screen_position
	if not get_viewport().gui_embed_subwindows:
		popup_position += Vector2(get_window().position)
	_city_context_menu.popup(
		Rect2i(Vector2i(popup_position), Vector2i.ZERO)
	)
	return true


func _add_development_menu_items(city: GameViewSnapshot.CityView) -> void:
	_city_context_menu.add_item("Change owner", CHANGE_CITY_OWNER_MENU_ITEM_ID)
	_city_context_menu.add_item("Add units", ADD_UNITS_MENU_ITEM_ID)
	_city_context_menu.add_item("Remove units", REMOVE_UNITS_MENU_ITEM_ID)
	_city_context_menu.set_item_disabled(
		_city_context_menu.get_item_index(CHANGE_CITY_OWNER_MENU_ITEM_ID),
		city.owner_id.is_empty() or city.unit_count <= 0
	)
	var add_owner_name := city.owner_name if not city.owner_id.is_empty() else city.last_owner_name
	var add_unavailable := (
		add_owner_name.is_empty()
		or city.unit_count >= _game_snapshot.max_development_garrison_size
		or (not city.owner_id.is_empty() and city.unit_count <= 0)
	)
	_city_context_menu.set_item_disabled(
		_city_context_menu.get_item_index(ADD_UNITS_MENU_ITEM_ID),
		add_unavailable
	)
	var remove_unavailable := city.owner_id.is_empty() or city.unit_count <= 0
	_city_context_menu.set_item_disabled(
		_city_context_menu.get_item_index(REMOVE_UNITS_MENU_ITEM_ID),
		remove_unavailable
	)


func _on_city_context_menu_id_pressed(item_id: int) -> void:
	if _context_city_id.is_empty():
		push_error("Cannot use a city context-menu action without a city.")
		return
	if item_id == PLACE_REINFORCEMENT_MENU_ITEM_ID:
		_place_context_reinforcement()
		return
	if not _game_snapshot.dev_mode_active:
		_turn_status.text = "Developer tools are unavailable in this game."
		return
	if item_id == ADD_UNITS_MENU_ITEM_ID:
		_open_unit_change_dialog(DevelopmentUnitChange.ADD)
		return
	if item_id == REMOVE_UNITS_MENU_ITEM_ID:
		_open_unit_change_dialog(DevelopmentUnitChange.REMOVE)
		return
	if item_id != CHANGE_CITY_OWNER_MENU_ITEM_ID:
		return

	var result := _game_application.change_city_owner_for_development(_context_city_id)
	if not result.succeeded():
		_turn_status.text = result.error_message
		return

	if not _refresh_game_view():
		return
	if _selected_city_id == _context_city_id:
		_on_city_selected(_selected_city_id)
	var city := _game_snapshot.find_city(_context_city_id)
	if city == null:
		push_error("Cannot display updated state for unknown city '%s'." % _context_city_id)
		return
	_turn_status.text = "%s is now owned by %s." % [city.name, city.owner_name]
	if not _game_snapshot.winner_id.is_empty():
		_update_phase_status()


func _place_context_reinforcement() -> void:
	var result := _game_application.place_reinforcement(_context_city_id)
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
	_turn_status.text = "Placed one reinforcement in %s." % city.name


func _open_unit_change_dialog(change: DevelopmentUnitChange) -> void:
	var city := _game_snapshot.find_city(_context_city_id)
	if city == null:
		push_error("Cannot change units for unknown city '%s'." % _context_city_id)
		return
	if change == DevelopmentUnitChange.REMOVE and (
		city.owner_id.is_empty() or city.unit_count <= 0
	):
		_turn_status.text = "Developer unit changes require an occupied city."
		return
	var owner_name := city.owner_name if not city.owner_id.is_empty() else city.last_owner_name
	if owner_name.is_empty():
		_turn_status.text = "The city owner is not in this game."
		return

	_pending_unit_change = change
	var city_name := _city_display_name(_context_city_id)
	if change == DevelopmentUnitChange.ADD:
		_unit_change_dialog.dialog_text = "Add units to %s:" % city_name
		if city.owner_id.is_empty():
			_unit_change_dialog.dialog_text += " Reoccupies for %s." % owner_name
		_unit_change_selector.max_value = (
			_game_snapshot.max_development_garrison_size - city.unit_count
		)
		if _unit_change_selector.max_value < 1:
			_turn_status.text = "The city's garrison is already at the supported limit."
			return
	else:
		_unit_change_dialog.dialog_text = "Remove units from %s:" % city_name
		_unit_change_selector.max_value = city.unit_count
	_unit_change_selector.value = 1
	_unit_change_dialog.popup_centered(Vector2i(360, 160))
	_unit_change_selector.grab_focus()


func _on_unit_change_confirmed() -> void:
	if _context_city_id.is_empty():
		push_error("Cannot apply a unit change without a context-menu city.")
		return

	var unit_count := int(_unit_change_selector.value)
	var result: GameActionResult
	if _pending_unit_change == DevelopmentUnitChange.ADD:
		result = _game_application.add_units_for_development(
			_context_city_id,
			unit_count
		)
	else:
		result = _game_application.remove_units_for_development(
			_context_city_id,
			unit_count
		)
	if not result.succeeded():
		_turn_status.text = result.error_message
		return

	if not _refresh_game_view():
		return
	if _selected_city_id == _context_city_id:
		_on_city_selected(_selected_city_id)
	var city := _game_snapshot.find_city(_context_city_id)
	if city == null:
		push_error("Cannot display updated state for unknown city '%s'." % _context_city_id)
		return
	var action := (
		"Added %d units to %s."
		% [unit_count, city.name]
		if _pending_unit_change == DevelopmentUnitChange.ADD
		else "Removed %d units from %s."
		% [unit_count, city.name]
	)
	if city.unit_count == 0:
		action += " The city is now unoccupied."
	_turn_status.text = action
	if not _game_snapshot.winner_id.is_empty():
		_update_phase_status()


func _on_board_selection_cleared() -> void:
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


func _update_selected_city_label(city: GameViewSnapshot.CityView) -> void:
	var owner_name := city.owner_name if not city.owner_name.is_empty() else "Unoccupied"
	var unit_label := "unit" if city.unit_count == 1 else "units"
	_selected_city_label.text = "%s - %s, %d %s" % [
		city.name,
		owner_name,
		city.unit_count,
		unit_label,
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
	var result: CombatRoundResult = _game_application.resolve_attack_round(
		_attack_source_city_id,
		_attack_target_city_id,
		int(_attacker_commitment.value),
		int(_defender_commitment.value)
	)
	if not result.succeeded():
		_turn_status.text = result.error_message
		_awaiting_defender_commitment = false
		_update_phase_status()
		return

	_awaiting_defender_commitment = false
	_attack_result.text = (
		"Attacker rolls %s; defender rolls %s. Losses: attacker %d, defender %d."
		% [
			str(result.attacker_rolls),
			str(result.defender_rolls),
			result.attacker_losses,
			result.defender_losses,
		]
	)
	if not _refresh_game_view():
		return
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
		_city_display_name(_attack_source_city_id),
		_city_display_name(_attack_target_city_id),
	]
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
	_move_units_button.disabled = source_city == null or target_name.is_empty()
	if source_city != null:
		_reorganization_commitment.min_value = 1
		_reorganization_commitment.max_value = maxi(1, source_city.unit_count)
		_reorganization_commitment.value = mini(
			maxi(1, int(_reorganization_commitment.value)),
			source_city.unit_count
		)


func _update_phase_status() -> void:
	if not _game_snapshot.winner_id.is_empty():
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
	_attacker_commitment.max_value = maxi(1, attacking_city.unit_count)
	_attacker_commitment.value = mini(
		maxi(1, int(_attacker_commitment.value)),
		attacking_city.unit_count
	)
	_attack_action_button.disabled = false
