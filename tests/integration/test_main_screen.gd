extends Node

const MainScene = preload("res://scenes/main.tscn")

var _failures: int = 0


func _ready() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	await get_tree().process_frame
	var main_screen := MainScene.instantiate() as Control
	get_tree().root.add_child(main_screen)
	await get_tree().process_frame

	var setup_panel: VBoxContainer = main_screen.get_node("MarginContainer/Content/SetupPanel")
	var menu_panel: VBoxContainer = main_screen.get_node("MarginContainer/Content/MenuPanel")
	var custom_game_button: Button = menu_panel.get_node("CustomGame")
	var quick_start_button: Button = menu_panel.get_node("QuickStart")
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
	var attack_action_button: Button = main_screen.get_node(
		"MarginContainer/Content/MainLayout/Sidebar/AttackPanel/AttackAction"
	)
	var end_attack_button: Button = main_screen.get_node(
		"MarginContainer/Content/MainLayout/Sidebar/AttackPanel/EndAttack"
	)
	var defender_prompt: Label = main_screen.get_node(
		"MarginContainer/Content/MainLayout/Sidebar/AttackPanel/DefenderPrompt"
	)
	var defender_commitment: SpinBox = main_screen.get_node(
		"MarginContainer/Content/MainLayout/Sidebar/AttackPanel/DefenderCommitment"
	)
	var attack_result: Label = main_screen.get_node(
		"MarginContainer/Content/MainLayout/Sidebar/AttackPanel/AttackResult"
	)
	var reorganization_panel: VBoxContainer = main_screen.get_node(
		"MarginContainer/Content/MainLayout/Sidebar/ReorganizationPanel"
	)
	var reorganization_commitment: SpinBox = main_screen.get_node(
		"MarginContainer/Content/MainLayout/Sidebar/ReorganizationPanel/ReorganizationCommitment"
	)
	var move_units_button: Button = main_screen.get_node(
		"MarginContainer/Content/MainLayout/Sidebar/ReorganizationPanel/MoveUnits"
	)
	var end_reorganization_button: Button = main_screen.get_node(
		"MarginContainer/Content/MainLayout/Sidebar/ReorganizationPanel/EndReorganization"
	)
	var board: BoardView = main_screen.get_node("MarginContainer/Content/MainLayout/Board")

	_expect(
		setup_prompt.text == "Who will lead the Allied forces?",
		"The setup should begin by prompting for the Allied leader."
	)
	_expect(menu_panel.visible, "The start menu should be visible when the game opens.")
	_expect(not setup_panel.visible, "The name prompt should wait for custom game selection.")
	_expect(not game_panel.visible, "The board should stay hidden until both names are entered.")
	custom_game_button.emit_signal("pressed")
	await get_tree().process_frame
	_expect(setup_panel.visible, "Custom game should open the leader name prompt.")
	continue_button.emit_signal("pressed")
	await get_tree().process_frame
	_expect(
		setup_error.text == "Please enter a name to continue.",
		"Empty names should be rejected."
	)

	name_input.text = "  Ada  "
	continue_button.emit_signal("pressed")
	_expect(
		setup_prompt.text == "Who will lead the German Empire?",
		"The setup should prompt for the German Empire leader second."
	)
	_expect(
		continue_button.text == "Start game",
		"The final name prompt should offer to start the game."
	)
	name_input.text = " Otto "
	continue_button.emit_signal("pressed")
	await get_tree().process_frame
	board.size = Vector2(1600, 1000)
	board._layout_markers()

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
	_expect(
		paris_marker.text == "Paris (COG)\nAda - 1 unit",
		"Rejected placement must not change the garrison."
	)
	_expect(
		turn_status.text != "Ada's turn - 5 reserve units remaining.",
		"A rejected placement must not advance the turn."
	)

	koblenz_marker.emit_signal("pressed")
	phase_action_button.emit_signal("pressed")
	_expect(
		koblenz_marker.text == "Koblenz (COG)\nOtto - 2 units",
		"A reserve should increase the garrison."
	)
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
		"After setup, Germany should begin the first reinforcement phase."
	)
	_expect(
		not phase_action_button.disabled,
		"The active player should be able to place reinforcements."
	)
	_expect(
		koblenz_marker.text == "Koblenz (COG)\nOtto - 6 units",
		"All five German reserves should have been placed."
	)
	_expect(
		paris_marker.text == "Paris (COG)\nAda - 6 units",
		"All five Allied reserves should have been placed."
	)
	_expect(
		game_status.text.contains("Reinforcement phase"),
		"Finishing setup should display the reinforcement phase."
	)

	paris_marker.emit_signal("pressed")
	_expect(
		board.get_selected_city_id() == "paris",
		"Selecting Paris should update the board selection."
	)
	_expect(paris_marker.button_pressed, "The selected marker should show visual feedback.")
	_expect(not koblenz_marker.button_pressed, "Only the selected marker should remain highlighted.")
	_expect(
		selected_city_label.text == "Paris - Ada, 6 units",
		"The screen should display information about the selected city."
	)
	for reinforcement_index: int in 3:
		koblenz_marker.emit_signal("pressed")
		phase_action_button.emit_signal("pressed")
	_expect(
		koblenz_marker.text == "Koblenz (COG)\nOtto - 9 units",
		"All three German reinforcements should be placed before attacks begin."
	)
	_expect(
		turn_status.text == "Otto's attack phase.",
		"Germany should remain active after completing reinforcement placement."
	)
	_expect(
		game_status.text.contains("Attack phase: select a source city"),
		"Placing all reinforcements should display the attack phase."
	)

	var game_state := main_screen.get("_game_state") as GameState
	paris_marker.emit_signal("pressed")
	_expect(
		(main_screen.get("_attack_source_city_id") as String).is_empty(),
		"An enemy city cannot become the attacking source."
	)
	_expect(
		(main_screen.get("_attack_target_city_id") as String).is_empty(),
		"An invalid source selection must not be treated as an attack target."
	)
	_expect(
		turn_status.text.contains("owned by the active player"),
		"Rejecting an enemy attack source should explain the selection rule."
	)
	var defending_city := game_state.find_city("saarbrucken")
	defending_city.owner_id = "german_empire"
	defending_city.unit_count = 1
	board.refresh_state(game_state)
	var saarbrucken_marker: BoardCityMarker = board.get_node("CityMarker_saarbrucken")
	koblenz_marker.emit_signal("pressed")
	saarbrucken_marker.emit_signal("pressed")
	_expect(
		(main_screen.get("_attack_target_city_id") as String).is_empty(),
		"An active player's city cannot be selected as an attack target."
	)
	_expect(
		turn_status.text.contains("already controlled by the active player"),
		"Rejecting an owned attack target should explain why it cannot be selected."
	)
	defending_city.owner_id = "allies"
	defending_city.unit_count = 1
	board.refresh_state(game_state)
	saarbrucken_marker.emit_signal("pressed")
	attack_action_button.emit_signal("pressed")
	_expect(
		defender_prompt.text == "Ada: choose defending units.",
		"The defending player should choose a commitment for each combat round."
	)
	defender_commitment.value = 1
	attack_action_button.emit_signal("pressed")
	_expect(
		not attack_result.text.is_empty(),
		"A resolved combat round should display dice and casualty results."
	)
	_expect(
		game_state.phase == GameState.Phase.ATTACK,
		"Combat should remain in the active player's attack phase."
	)
	var koblenz_city := game_state.find_city("koblenz")
	var luxembourg_city := game_state.find_city("luxembourg")
	luxembourg_city.owner_id = "german_empire"
	luxembourg_city.unit_count = 1
	board.refresh_state(game_state)
	end_attack_button.emit_signal("pressed")
	_expect(
		game_state.phase == GameState.Phase.REORGANIZATION,
		"Ending attacks should begin reorganization."
	)
	_expect(
		reorganization_panel.visible,
		"Reorganization controls should be visible during the reorganization phase."
	)
	var koblenz_units_before_move: int = koblenz_city.unit_count
	koblenz_marker.emit_signal("pressed")
	var luxembourg_marker: BoardCityMarker = board.get_node("CityMarker_luxembourg")
	luxembourg_marker.emit_signal("pressed")
	_expect(
		not move_units_button.disabled,
		"A legal route should enable the unit transfer action."
	)
	reorganization_commitment.value = 1
	move_units_button.emit_signal("pressed")
	_expect(
		koblenz_city.unit_count == koblenz_units_before_move - 1
		and luxembourg_city.unit_count == 2,
		"Moving units should update both city garrisons."
	)
	luxembourg_marker.emit_signal("pressed")
	koblenz_marker.emit_signal("pressed")
	move_units_button.emit_signal("pressed")
	_expect(
		luxembourg_city.unit_count == 1,
		"Players should be able to make multiple transfers during reorganization."
	)
	end_reorganization_button.emit_signal("pressed")
	_expect(
		game_state.phase == GameState.Phase.REINFORCEMENT_PLACEMENT
		and game_state.active_player_id == "allies",
		"Ending reorganization should begin the opposing player's reinforcement phase."
	)
	_expect(
		turn_status.text == "Ada's reinforcement phase - 3 units remaining.",
		"The next player's reinforcement phase should display the correct unit count."
	)

	get_tree().root.remove_child(main_screen)
	main_screen.free()

	var quick_start_screen := MainScene.instantiate() as Control
	get_tree().root.add_child(quick_start_screen)
	await get_tree().process_frame
	var quick_start_menu: VBoxContainer = quick_start_screen.get_node(
		"MarginContainer/Content/MenuPanel"
	)
	var quick_start_error: Label = quick_start_menu.get_node("Error")
	var quick_start_board: BoardView = quick_start_screen.get_node(
		"MarginContainer/Content/MainLayout/Board"
	)
	var quick_start_state := quick_start_screen.get("_game_state") as GameState
	quick_start_menu.get_node("QuickStart").emit_signal("pressed")
	await get_tree().process_frame
	quick_start_state = quick_start_screen.get("_game_state") as GameState
	_expect(quick_start_error.text.is_empty(), "Quick start should complete without setup errors.")
	_expect(
		quick_start_state != null,
		"Quick start should initialize a game without manual name entry."
	)
	if quick_start_state != null:
		_expect(quick_start_state.players[0].name == "Joffre", "Quick start should use Joffre.")
		_expect(quick_start_state.players[1].name == "Moltke", "Quick start should use Moltke.")
		_expect(
			quick_start_state.phase == GameState.Phase.REINFORCEMENT_PLACEMENT,
			"Quick start should skip manual reserve placement and enter reinforcements."
		)
		var total_units := 0
		for city: GameCity in quick_start_state.cities:
			total_units += city.unit_count
			_expect(
				city.owner_id == "allies" or city.owner_id == "german_empire",
				"Quick start reserves should only be placed in owned cities."
			)
		_expect(total_units == 42, "Quick start should place all ten initial reserve units.")
		_expect(
			quick_start_state.active_player_id == "german_empire",
			"Quick start should begin Germany's first reinforcement phase."
		)
	_expect(
		quick_start_board.get_child_count() == 32,
		"Quick start should display the initialized map."
	)
	get_tree().root.remove_child(quick_start_screen)
	quick_start_screen.free()

	if _failures == 0:
		print("Main screen integration tests passed.")
	get_tree().quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
