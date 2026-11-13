extends Node

signal game_started

var _application: GameApplication
var _setup_panel: VBoxContainer
var _setup_prompt: Label
var _leader_name_input: LineEdit
var _setup_error: Label
var _continue_button: Button
var _menu_error: Label
var _game_status: Label
var _allies_name: String = ""
var _is_entering_german_name: bool = false


func configure(application: GameApplication, screen: Control) -> void:
	_application = application
	var content := screen.get_node("MarginContainer/Content")
	var menu := content.get_node("MenuPanel") as VBoxContainer
	_setup_panel = content.get_node("SetupPanel") as VBoxContainer
	_setup_prompt = _setup_panel.get_node("Prompt") as Label
	_leader_name_input = _setup_panel.get_node("LeaderName") as LineEdit
	_setup_error = _setup_panel.get_node("Error") as Label
	_continue_button = _setup_panel.get_node("Continue") as Button
	_menu_error = menu.get_node("Error") as Label
	_game_status = content.get_node("GameStatus") as Label
	var return_button := content.get_node("MainLayout/Sidebar/ReturnToMenu") as Button
	return_button.pressed.connect(_return_to_menu)
	var dev_button := menu.get_node("DevMode") as Button
	dev_button.visible = _application.can_start_dev_mode
	(menu.get_node("CustomGame") as Button).pressed.connect(_on_custom_game_pressed.bind(menu))
	(menu.get_node("QuickStart") as Button).pressed.connect(_on_quick_start_pressed)
	dev_button.pressed.connect(_on_dev_mode_pressed)
	_continue_button.pressed.connect(_submit_current_leader_name)
	_leader_name_input.text_submitted.connect(_on_leader_name_submitted)
	_setup_prompt.text = "Who will lead the Allied forces?"
	_setup_error.text = ""
	_menu_error.text = ""


func _on_custom_game_pressed(menu: VBoxContainer) -> void:
	menu.hide()
	_setup_panel.show()
	_leader_name_input.grab_focus()


func _on_quick_start_pressed() -> void:
	_start(_application.start_quick_game())


func _on_dev_mode_pressed() -> void:
	_start(_application.start_dev_mode_game())


func _start(result: GameStartResult) -> void:
	if not result.succeeded():
		_menu_error.text = result.error_message
		return
	game_started.emit()


func _return_to_menu() -> void:
	var snapshot := _application.get_view_snapshot()
	if snapshot == null or snapshot.winner_id.is_empty():
		return
	var error := get_tree().change_scene_to_file("res://scenes/main.tscn")
	if error != OK:
		_game_status.text = "Could not return to the start menu (error %d)." % error
		push_error(_game_status.text)


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
	var result := _application.start_new_game(_allies_name, leader_name)
	if not result.succeeded():
		_setup_error.text = result.error_message
		return
	game_started.emit()
