extends Control

const GameApplicationScript = preload("res://scripts/application/game_application.gd")

@onready var _player_list: VBoxContainer = $MarginContainer/Content/MainLayout/Sidebar/PlayerList
@onready var _selected_city_label: Label = $MarginContainer/Content/MainLayout/Sidebar/SelectedCity
@onready var _board: BoardView = $MarginContainer/Content/MainLayout/Board
@onready var _setup_panel: VBoxContainer = $MarginContainer/Content/SetupPanel
@onready var _setup_prompt: Label = $MarginContainer/Content/SetupPanel/Prompt
@onready var _leader_name_input: LineEdit = $MarginContainer/Content/SetupPanel/LeaderName
@onready var _setup_error: Label = $MarginContainer/Content/SetupPanel/Error
@onready var _continue_button: Button = $MarginContainer/Content/SetupPanel/Continue
@onready var _game_panel: HBoxContainer = $MarginContainer/Content/MainLayout
@onready var _game_status: Label = $MarginContainer/Content/GameStatus
@onready var _turn_status: Label = $MarginContainer/Content/MainLayout/Sidebar/TurnStatus
@onready var _phase_action_button: Button = $MarginContainer/Content/MainLayout/Sidebar/PhaseAction

var _game_application: GameApplication
var _map_definition: GameMapDefinition
var _game_state: GameState
var _allies_name: String = ""
var _is_entering_german_name: bool = false
var _selected_city_id: String = ""


func _ready() -> void:
	var random_generator := RandomNumberGenerator.new()
	random_generator.randomize()
	_game_application = GameApplicationScript.new(random_generator)
	_map_definition = _game_application.get_map_definition()
	_setup_prompt.text = "Who will lead the Allied forces?"
	_continue_button.pressed.connect(_on_continue_pressed)
	_leader_name_input.text_submitted.connect(_on_leader_name_submitted)
	_phase_action_button.pressed.connect(_on_phase_action_pressed)
	_leader_name_input.grab_focus()
	_game_panel.hide()
	_setup_error.text = ""
	_phase_action_button.disabled = true


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

	_game_state = result.game_state
	_display_players()
	_board.city_selected.connect(_on_city_selected)
	_board.configure(_map_definition, _game_state)
	_game_status.text = (
		"Territories assigned. Each city has one infantry unit. "
		+ "Now place the initial reserve units."
	)
	_update_phase_status()
	_setup_panel.hide()
	_game_panel.show()


func _display_players() -> void:
	for player: GamePlayer in _game_state.players:
		var player_label := Label.new()
		player_label.text = "%s - %s" % [player.id, player.name]
		_player_list.add_child(player_label)


func _on_city_selected(city_id: String) -> void:
	var city_definition := _map_definition.find_city(city_id)
	var city_state := _game_state.find_city(city_id)
	if city_definition == null or city_state == null:
		push_error("Cannot display selection for unknown city '%s'." % city_id)
		return

	_selected_city_id = city_id
	_update_phase_status()
	var owner_name := "Unoccupied"
	if not city_state.owner_id.is_empty():
		var owner := _game_state.find_player(city_state.owner_id)
		if owner == null:
			push_error("City '%s' has unknown owner '%s'." % [city_id, city_state.owner_id])
			return
		owner_name = owner.name

	var unit_label := "unit" if city_state.unit_count == 1 else "units"
	_selected_city_label.text = "%s - %s, %d %s" % [
		city_definition.name,
		owner_name,
		city_state.unit_count,
		unit_label,
	]
	_update_phase_status()


func _on_phase_action_pressed() -> void:
	var result: GameActionResult
	if _game_state.phase == GameState.Phase.INITIAL_RESERVE_PLACEMENT:
		if _selected_city_id.is_empty():
			_turn_status.text = "Select one of your cities first."
			return
		result = _game_application.place_initial_reserve(_selected_city_id)
	elif _game_state.phase == GameState.Phase.REINFORCEMENT_PLACEMENT:
		if _game_state.reinforcements_remaining == 0:
			result = _game_application.skip_reinforcement_turn()
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

	_board.refresh_state(_game_state)
	if not _selected_city_id.is_empty():
		_on_city_selected(_selected_city_id)
	else:
		_update_phase_status()


func _update_phase_status() -> void:
	if _game_state.phase == GameState.Phase.ACTIVE_PLAY:
		_turn_status.text = "Initial reserve placement complete."
		_phase_action_button.text = "Placement complete"
		_phase_action_button.disabled = true
		return

	var active_player := _game_state.find_player(_game_state.active_player_id)
	if active_player == null:
		push_error("Game state has no active player for the current phase.")
		return

	if _game_state.phase == GameState.Phase.INITIAL_RESERVE_PLACEMENT:
		var reserves_remaining: int = _game_state.reserves_remaining_by_player_id[active_player.id]
		_turn_status.text = "%s's turn - %d reserve units remaining." % [
			active_player.name,
			reserves_remaining,
		]
		_phase_action_button.text = "Place reserve unit"
		_phase_action_button.disabled = _selected_city_id.is_empty()
		return

	_game_status.text = (
		"Reinforcement-only turns are active. Attack and reorganization are not implemented yet."
	)
	if _game_state.reinforcements_remaining == 0:
		_turn_status.text = "%s has no reinforcements to place. Pass to the next player." % [
			active_player.name,
		]
		_phase_action_button.text = "Skip reinforcement turn"
		_phase_action_button.disabled = false
		return

	var unit_label := "unit" if _game_state.reinforcements_remaining == 1 else "units"
	_turn_status.text = "%s's reinforcement phase - %d %s remaining." % [
		active_player.name,
		_game_state.reinforcements_remaining,
		unit_label,
	]
	_phase_action_button.text = "Place reinforcement"
	_phase_action_button.disabled = _selected_city_id.is_empty()
