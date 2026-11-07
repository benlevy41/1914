extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var main_screen := MainScene.instantiate() as Control
	root.add_child(main_screen)
	await process_frame

	var setup_panel: VBoxContainer = main_screen.get_node("MarginContainer/Content/SetupPanel")
	var setup_prompt: Label = setup_panel.get_node("Prompt")
	var name_input: LineEdit = setup_panel.get_node("LeaderName")
	var setup_error: Label = setup_panel.get_node("Error")
	var continue_button: Button = setup_panel.get_node("Continue")
	var game_panel: HBoxContainer = main_screen.get_node("MarginContainer/Content/MainLayout")
	var game_status: Label = main_screen.get_node("MarginContainer/Content/GameStatus")
	var player_list: VBoxContainer = main_screen.get_node(
		"MarginContainer/Content/MainLayout/Sidebar/PlayerList"
	)
	var selected_city_label: Label = main_screen.get_node(
		"MarginContainer/Content/MainLayout/Sidebar/SelectedCity"
	)
	var turn_status: Label = main_screen.get_node(
		"MarginContainer/Content/MainLayout/Sidebar/TurnStatus"
	)
	var phase_action_button: Button = main_screen.get_node(
		"MarginContainer/Content/MainLayout/Sidebar/PhaseAction"
	)
	var board: BoardView = main_screen.get_node("MarginContainer/Content/MainLayout/Board")

	_expect(
		setup_prompt.text == "Who will lead the Allied forces?",
		"The setup should begin by prompting for the Allied leader."
	)
	_expect(setup_panel.visible, "The name prompt should be visible before game initialization.")
	_expect(not game_panel.visible, "The board should stay hidden until both names are entered.")
	continue_button.emit_signal("pressed")
	await get_tree().process_frame
	_expect(setup_error.text == "Please enter a name to continue.", "Empty names should be rejected.")

	name_input.text = "  Ada  "
	continue_button.emit_signal("pressed")
	_expect(
		setup_prompt.text == "Who will lead the German Empire?",
		"The setup should prompt for the German Empire leader second."
	)
	_expect(continue_button.text == "Start game", "The final name prompt should offer to start the game.")
	name_input.text = " Otto "
	continue_button.emit_signal("pressed")
	await process_frame

	_expect(not setup_panel.visible, "The name prompt should close after both names are entered.")
	_expect(game_panel.visible, "The game board should appear after setup.")
	_expect(player_list.get_child_count() == 2, "The screen should display both players.")
	_expect(board.get_child_count() == 32, "The board should display all 32 map cities.")
	_expect(
		(player_list.get_child(0) as Label).text == "allies - Ada",
		"The first player label should show the trimmed Allied leader name."
	)
	_expect(
		(player_list.get_child(1) as Label).text == "german_empire - Otto",
		"The second player label should show the trimmed German Empire leader name."
	)
	_expect(
		game_status.text.contains("Now place the initial reserve units."),
		"The screen should explain that reserve placement follows territory setup."
	)
	_expect(
		turn_status.text == "Otto's turn - 5 reserve units remaining.",
		"The German Empire should be prompted to place first."
	)
	_expect(
		phase_action_button.disabled,
		"A reserve cannot be placed until an owned city is selected."
	)
	_expect(
		selected_city_label.text == "Select a city on the board.",
		"The selection label should prompt before a city is selected."
	)

	var paris_marker: BoardCityMarker = board.get_node("CityMarker_paris")
	var koblenz_marker: BoardCityMarker = board.get_node("CityMarker_koblenz")
	_expect(
		paris_marker.text == "Paris (COG)\nAda - 1 unit",
		"The Paris marker should display its name, owner, unit count, and COG status."
	)
	_expect(
		koblenz_marker.text == "Koblenz (COG)\nOtto - 1 unit",
		"The Koblenz marker should display its name, owner, unit count, and COG status."
	)
	for first_index: int in board.get_child_count():
		var first_marker := board.get_child(first_index) as BoardCityMarker
		var first_rect := Rect2(first_marker.position, first_marker.size)
		for second_index: int in range(first_index + 1, board.get_child_count()):
			var second_marker := board.get_child(second_index) as BoardCityMarker
			var second_rect := Rect2(second_marker.position, second_marker.size)
			_expect(
				not first_rect.intersects(second_rect),
				"City markers should not overlap on the schematic board."
			)

	var allies_style := paris_marker.get_theme_stylebox("normal") as StyleBoxFlat
	var german_style := koblenz_marker.get_theme_stylebox("normal") as StyleBoxFlat
	_expect(
		allies_style.bg_color != german_style.bg_color,
		"Markers owned by different players should use different colors."
	)

	paris_marker.emit_signal("pressed")
	phase_action_button.emit_signal("pressed")
	_expect(
		turn_status.text == "Choose a city owned by the player placing a reserve.",
		"The active player should not be able to place on an opponent's city."
	)
	_expect(paris_marker.text == "Paris (COG)\nAda - 1 unit", "Rejected placement must not change the garrison.")
	_expect(
		turn_status.text != "Ada's turn - 5 reserve units remaining.",
		"A rejected placement must not advance the turn."
	)

	koblenz_marker.emit_signal("pressed")
	phase_action_button.emit_signal("pressed")
	_expect(koblenz_marker.text == "Koblenz (COG)\nOtto - 2 units", "A reserve should increase the garrison.")
	_expect(
		turn_status.text == "Ada's turn - 5 reserve units remaining.",
		"The Allies should place after the German Empire."
	)
	paris_marker.emit_signal("pressed")
	phase_action_button.emit_signal("pressed")
	_expect(
		turn_status.text == "Otto's turn - 4 reserve units remaining.",
		"Players should alternate after a successful placement."
	)

	for placement_index: int in 8:
		var active_city := koblenz_marker if placement_index % 2 == 0 else paris_marker
		active_city.emit_signal("pressed")
		phase_action_button.emit_signal("pressed")

	_expect(
		turn_status.text == "Otto's reinforcement phase - 3 units remaining.",
		"After setup, Germany should begin the reinforcement-only turn loop."
	)
	_expect(not phase_action_button.disabled, "The active player should be able to place reinforcements.")
	_expect(
		koblenz_marker.text == "Koblenz (COG)\nOtto - 6 units",
		"All five German reserves should have been placed."
	)
	_expect(
		paris_marker.text == "Paris (COG)\nAda - 6 units",
		"All five Allied reserves should have been placed."
	)
	_expect(
		game_status.text.contains("Attack and reorganization are not implemented yet."),
		"The reinforcement-only loop should not imply that later phases are implemented."
	)

	paris_marker.emit_signal("pressed")
	_expect(board.get_selected_city_id() == "paris", "Selecting Paris should update the board selection.")
	_expect(paris_marker.button_pressed, "The selected marker should show visual feedback.")
	_expect(not koblenz_marker.button_pressed, "Only the selected marker should remain highlighted.")
	_expect(
		selected_city_label.text == "Paris - Ada, 6 units",
		"The screen should display information about the selected city."
	)
	phase_action_button.emit_signal("pressed")
	_expect(
		turn_status.text == "Choose a city owned by the active player.",
		"The active player should not reinforce an opponent-owned city."
	)
	koblenz_marker.emit_signal("pressed")
	for reinforcement_index: int in 3:
		phase_action_button.emit_signal("pressed")
	_expect(
		koblenz_marker.text == "Koblenz (COG)\nOtto - 9 units",
		"All three German reinforcements should be placed before the Allies become active."
	)
	_expect(
		turn_status.text == "Ada's reinforcement phase - 3 units remaining.",
		"After the German pool is exhausted, the Allies should receive their reinforcement turn."
	)
	paris_marker.emit_signal("pressed")
	phase_action_button.emit_signal("pressed")
	_expect(
		paris_marker.text == "Paris (COG)\nAda - 7 units",
		"The Allied player should be able to place a reinforcement in their COG."
	)
	_expect(
		turn_status.text == "Ada's reinforcement phase - 2 units remaining.",
		"The remaining reinforcement count should update after a placement."
	)

	if _failures == 0:
		print("Main screen integration tests passed.")
	root.remove_child(main_screen)
	main_screen.free()
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
