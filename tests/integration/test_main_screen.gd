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
	var test_application := main_screen.get("_game_application") as GameApplication
	test_application._random_generator.seed = 1914

	var setup_panel: VBoxContainer = main_screen.get_node("MarginContainer/Content/SetupPanel")
	var menu_panel: VBoxContainer = main_screen.get_node("MarginContainer/Content/MenuPanel")
	var custom_game_button: Button = menu_panel.get_node("CustomGame")
	var dev_mode_button: Button = menu_panel.get_node("DevMode")
	var dev_mode_indicator: Label = main_screen.get_node(
		"MarginContainer/Content/DevModeIndicator"
	)
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
	_expect(
		dev_mode_button.visible == OS.is_debug_build(),
		"Dev-mode entry should only be visible in debug builds."
	)
	_expect(not dev_mode_indicator.visible, "The dev-mode indicator should start hidden.")
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
	var paris_projection_city := board._snapshot.find_city(
		"paris"
	) as GameViewSnapshot.CityView
	var koblenz_projection_city := board._snapshot.find_city(
		"koblenz"
	) as GameViewSnapshot.CityView
	var paris_position := board._city_canvas_position(
		paris_projection_city.longitude,
		paris_projection_city.latitude
	)
	var koblenz_position := board._city_canvas_position(
		koblenz_projection_city.longitude,
		koblenz_projection_city.latitude
	)
	_expect(
		paris_position.x < koblenz_position.x and paris_position.y > koblenz_position.y,
		"Geographic projection should place Paris southwest of Koblenz."
	)
	var mean_latitude := 0.0
	for city: GameViewSnapshot.CityView in board._snapshot.cities:
		mean_latitude += city.latitude
	mean_latitude /= board._snapshot.cities.size()
	var projection_origin := board._city_canvas_position(0.0, mean_latitude)
	var one_degree_east := board._city_canvas_position(1.0, mean_latitude)
	var one_degree_north := board._city_canvas_position(0.0, mean_latitude + 1.0)
	_expect(
		is_equal_approx(
			projection_origin.distance_to(one_degree_east)
			/ projection_origin.distance_to(one_degree_north),
			cos(deg_to_rad(mean_latitude))
		),
		"Geographic projection should preserve geographic aspect ratio."
	)
	_expect_city_markers_do_not_overlap(board)
	board.size = Vector2(800, 500)
	board._layout_markers()
	_expect_city_markers_do_not_overlap(board)
	board.size = Vector2(1600, 1000)
	board._layout_markers()

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

	var main_game_application := main_screen.get("_game_application") as GameApplication
	var game_state := main_game_application._active_game_state as GameState
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
	main_screen.call("_refresh_game_view")
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
	main_screen.call("_refresh_game_view")
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
	main_screen.call("_refresh_game_view")
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
	var quick_start_state := quick_start_screen.get("_game_snapshot") as GameViewSnapshot
	quick_start_menu.get_node("QuickStart").emit_signal("pressed")
	await get_tree().process_frame
	quick_start_state = quick_start_screen.get("_game_snapshot") as GameViewSnapshot
	_expect(quick_start_error.text.is_empty(), "Quick start should complete without setup errors.")
	_expect(
		quick_start_state != null,
		"Quick start should initialize a game without manual name entry."
	)
	if quick_start_state != null:
		_expect(quick_start_state.players[0].name == "Joffre", "Quick start should use Joffre.")
		_expect(quick_start_state.players[1].name == "Moltke", "Quick start should use Moltke.")
		_expect(
			quick_start_state.phase == GameViewSnapshot.Phase.REINFORCEMENT_PLACEMENT,
			"Quick start should skip manual reserve placement and enter reinforcements."
		)
		var total_units := 0
		for city: GameViewSnapshot.CityView in quick_start_state.cities:
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
	_expect(
		not quick_start_screen.get_node("MarginContainer/Content/DevModeIndicator").visible,
		"Normal quick start should not display the developer-mode indicator."
	)
	var quick_start_context_menu := quick_start_screen.get_node("CityContextMenu") as PopupMenu
	var quick_start_paris_marker: BoardCityMarker = quick_start_board.get_node(
		"CityMarker_paris"
	)
	_emit_right_click(quick_start_paris_marker)
	_expect(
		not quick_start_context_menu.visible,
		"Right-clicking a city in a normal game should not open developer options."
	)
	get_tree().root.remove_child(quick_start_screen)
	quick_start_screen.free()

	var dev_mode_screen := MainScene.instantiate() as Control
	get_tree().root.add_child(dev_mode_screen)
	await get_tree().process_frame
	var dev_mode_menu: VBoxContainer = dev_mode_screen.get_node(
		"MarginContainer/Content/MenuPanel"
	)
	var dev_mode_error: Label = dev_mode_menu.get_node("Error")
	var dev_mode_screen_button: Button = dev_mode_menu.get_node("DevMode")
	var dev_mode_screen_indicator: Label = dev_mode_screen.get_node(
		"MarginContainer/Content/DevModeIndicator"
	)
	var dev_mode_board: BoardView = dev_mode_screen.get_node(
		"MarginContainer/Content/MainLayout/Board"
	)
	var dev_mode_game_status: Label = dev_mode_screen.get_node(
		"MarginContainer/Content/GameStatus"
	)
	var dev_mode_turn_status: Label = dev_mode_screen.get_node(
		"MarginContainer/Content/MainLayout/Sidebar/TurnStatus"
	)
	var dev_mode_phase_action: Button = dev_mode_screen.get_node(
		"MarginContainer/Content/MainLayout/Sidebar/PhaseAction"
	)
	var dev_mode_attack_action: Button = dev_mode_screen.get_node(
		"MarginContainer/Content/MainLayout/Sidebar/AttackPanel/AttackAction"
	)
	var dev_mode_reorganization_panel: VBoxContainer = dev_mode_screen.get_node(
		"MarginContainer/Content/MainLayout/Sidebar/ReorganizationPanel"
	)
	var dev_mode_context_menu := dev_mode_screen.get_node("CityContextMenu") as PopupMenu
	var unit_change_dialog := dev_mode_screen.get_node("UnitChangeDialog") as ConfirmationDialog
	var unit_count_selector := unit_change_dialog.get_node("UnitCount") as SpinBox
	dev_mode_screen_button.emit_signal("pressed")
	await get_tree().process_frame
	if OS.is_debug_build():
		var dev_application := dev_mode_screen.get("_game_application") as GameApplication
		var dev_mode_state := dev_application._active_game_state as GameState
		_expect(
			dev_mode_state != null,
			"Dev mode should start a game in debug builds."
		)
		_expect(
			dev_mode_error.text.is_empty(),
			"Dev mode should start without an error in debug builds."
		)
		_expect(
			dev_mode_screen_indicator.visible,
			"A dev-mode game should show its developer-mode indicator."
		)
		_expect(
			dev_mode_board.get_child_count() == 32,
			"Dev mode should display the regular game board."
		)
		var paris := dev_mode_state.find_city("paris")
		var original_paris_units := paris.unit_count
		var dev_paris_marker: BoardCityMarker = dev_mode_board.get_node("CityMarker_paris")
		_emit_right_click(dev_paris_marker)
		_expect(
			dev_mode_context_menu.visible,
			"Right-clicking a city in dev mode should open its context menu."
		)
		_expect(
			dev_mode_context_menu.item_count == 3
			and dev_mode_context_menu.get_item_text(0) == "Change owner"
			and dev_mode_context_menu.get_item_text(1) == "Add units"
			and dev_mode_context_menu.get_item_text(2) == "Remove units",
			"Dev mode should offer ownership, add-unit, and remove-unit options."
		)
		_expect(
			not dev_mode_context_menu.is_item_disabled(0),
			"Change owner should be enabled for an occupied city."
		)
		dev_mode_context_menu.emit_signal("id_pressed", 1)
		_expect(
			paris.owner_id == "german_empire",
			"Selecting change owner should transfer the city to the other player."
		)
		_expect(
			paris.unit_count == original_paris_units,
			"Changing owner from the context menu must preserve the garrison."
		)
		_expect(
			dev_paris_marker.text.contains("Moltke"),
			"The city marker should refresh to show its new owner."
		)
		var units_before_dialog := paris.unit_count
		dev_mode_context_menu.emit_signal("id_pressed", 2)
		_expect(unit_change_dialog.visible, "Add units should open the unit-count dialog.")
		_expect(
			unit_change_dialog.dialog_text == "Add units to Paris:",
			"The add dialog should clearly identify the action and city."
		)
		var max_development_garrison_size := (
			dev_mode_screen.get("_game_snapshot") as GameViewSnapshot
		).max_development_garrison_size
		_expect(
			unit_count_selector.min_value == 1
			and unit_count_selector.max_value
			== max_development_garrison_size - paris.unit_count
			and unit_count_selector.step == 1,
			"The add selector should use whole numbers within the safe garrison limit."
		)
		unit_count_selector.value = 5
		unit_change_dialog.get_cancel_button().emit_signal("pressed")
		_expect(
			paris.unit_count == units_before_dialog,
			"Canceling a unit change must leave the garrison unchanged."
		)

		_emit_right_click(dev_paris_marker)
		dev_mode_context_menu.emit_signal("id_pressed", 2)
		unit_count_selector.value = 3
		unit_change_dialog.get_ok_button().emit_signal("pressed")
		_expect(
			paris.unit_count == units_before_dialog + 3,
			"Confirming Add units should apply the selected amount."
		)
		_expect(
			dev_paris_marker.text.contains("%d units" % paris.unit_count),
			"The city marker should refresh after adding units."
		)

		_emit_right_click(dev_paris_marker)
		dev_mode_context_menu.emit_signal("id_pressed", 3)
		_expect(
			unit_change_dialog.dialog_text == "Remove units from Paris:",
			"The remove dialog should clearly identify the action and city."
		)
		_expect(
			unit_count_selector.max_value == paris.unit_count,
			"The remove selector should not exceed the current garrison."
		)
		unit_count_selector.value = 2
		unit_change_dialog.get_ok_button().emit_signal("pressed")
		_expect(
			paris.unit_count == units_before_dialog + 1
			and paris.owner_id == "german_empire",
			"Removing some units should preserve the remaining garrison and owner."
		)
		_emit_right_click(dev_paris_marker)
		dev_mode_context_menu.emit_signal("id_pressed", 3)
		unit_count_selector.value = paris.unit_count
		unit_change_dialog.get_ok_button().emit_signal("pressed")
		_expect(
			paris.unit_count == 0 and paris.owner_id.is_empty(),
			"Removing the last units should leave the city unoccupied."
		)
		_expect(
			paris.last_owner_id == "german_empire",
			"Removing the last units should preserve the previous owner."
		)
		_expect(
			dev_paris_marker.text.contains("Unoccupied"),
			"A remembered owner should not change an unoccupied city's display."
		)
		_emit_right_click(dev_paris_marker)
		_expect(
			not dev_mode_context_menu.is_item_disabled(1)
			and dev_mode_context_menu.is_item_disabled(2),
			"An unoccupied city with a remembered owner should allow adding, but not removing, units."
		)
		dev_mode_context_menu.emit_signal("id_pressed", 2)
		_expect(
			unit_change_dialog.dialog_text
			== "Add units to Paris: Reoccupies for Moltke.",
			"The add dialog should explain which player will reoccupy the city."
		)
		unit_count_selector.value = 2
		unit_change_dialog.get_ok_button().emit_signal("pressed")
		_expect(
			paris.unit_count == 2 and paris.owner_id == "german_empire",
			"Adding units to an unoccupied city should restore its remembered owner."
		)
		_expect(
			dev_paris_marker.text.contains("Moltke"),
			"Reoccupying a city should restore its remembered owner's display."
		)

		var unoccupied_city := dev_mode_state.find_city("antwerp")
		unoccupied_city.owner_id = ""
		unoccupied_city.unit_count = 0
		dev_mode_screen.call("_refresh_game_view")
		var unoccupied_marker: BoardCityMarker = dev_mode_board.get_node(
			"CityMarker_antwerp"
		)
		_emit_right_click(unoccupied_marker)
		_expect(
			dev_mode_context_menu.visible,
			"The dev context menu should still open for an unoccupied city."
		)
		_expect(
			dev_mode_context_menu.item_count == 3
			and dev_mode_context_menu.get_item_text(0) == "Change owner"
			and dev_mode_context_menu.get_item_text(1) == "Add units"
			and dev_mode_context_menu.get_item_text(2) == "Remove units",
			"Developer options should remain displayed for an unoccupied city."
		)
		_expect(
			dev_mode_context_menu.is_item_disabled(0),
			"Change owner should be disabled for an unoccupied city."
		)
		_expect(
			not dev_mode_context_menu.is_item_disabled(1)
			and dev_mode_context_menu.is_item_disabled(2),
			"Add is enabled for an unoccupied city with a remembered owner; "
			+ "Remove should be disabled."
		)

		_emit_right_click(dev_paris_marker)
		var replacement_event := InputEventMouseButton.new()
		replacement_event.button_index = MOUSE_BUTTON_RIGHT
		replacement_event.pressed = true
		replacement_event.global_position = unoccupied_marker.get_global_rect().get_center()
		dev_mode_screen.call("_input", replacement_event)
		_expect(
			dev_mode_context_menu.visible
			and dev_mode_screen.get("_context_city_id") == "antwerp",
			"Right-clicking another city while the context menu is open should replace its target."
		)

		for city: GameCity in dev_mode_state.cities:
			if city.owner_id == "german_empire":
				city.leave_unoccupied()
				city.unit_count = 0
		var german_cog := dev_mode_state.find_city("koblenz")
		german_cog.assign_owner("allies")
		german_cog.unit_count = 1
		paris.assign_owner("allies")
		paris.unit_count = 1
		dev_mode_screen.call("_refresh_game_view")
		dev_mode_screen.call(
			"_on_city_context_requested",
			paris.id,
			Vector2.ZERO
		)
		dev_mode_context_menu.emit_signal("id_pressed", 2)
		unit_count_selector.value = 1
		unit_change_dialog.get_ok_button().emit_signal("pressed")
		_expect(
			dev_mode_state.winner_id == "allies",
			"The game should determine the winner from the domain state."
		)
		_expect(
			(dev_mode_screen.get("_game_snapshot") as GameViewSnapshot).winner_id == "allies",
			"The application snapshot should expose the winner to the presentation."
		)
		_expect(
			dev_mode_turn_status.text == "Game over. Joffre wins."
			and dev_mode_game_status.text.contains("Joffre wins"),
			"The screen should display a clear game-over result."
		)
		_expect(
			not dev_mode_phase_action.visible
			and not dev_mode_attack_action.is_visible_in_tree()
			and not dev_mode_reorganization_panel.visible,
			"Gameplay controls should be hidden after the game ends."
		)
	else:
		_expect(
			dev_mode_screen.get("_game_snapshot") == null,
			"Release builds must reject dev-mode startup even when invoked directly."
		)
		_expect(
			dev_mode_error.text.contains("only available in debug builds"),
			"Rejected dev-mode startup should explain the build restriction."
		)
		_expect(
			not dev_mode_screen_indicator.visible,
			"Rejected startup must not display the developer-mode indicator."
		)
	get_tree().root.remove_child(dev_mode_screen)
	dev_mode_screen.free()

	if _failures == 0:
		print("Main screen integration tests passed.")
	get_tree().quit(1 if _failures > 0 else 0)


func _emit_right_click(marker: BoardCityMarker) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.global_position = marker.get_global_rect().get_center()
	marker.emit_signal("gui_input", event)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _expect_city_markers_do_not_overlap(board: BoardView) -> void:
	for first_index: int in board.get_child_count():
		var first_marker := board.get_child(first_index) as BoardCityMarker
		var first_rect := Rect2(first_marker.position, first_marker.size)
		for second_index: int in range(first_index + 1, board.get_child_count()):
			var second_marker := board.get_child(second_index) as BoardCityMarker
			var second_rect := Rect2(second_marker.position, second_marker.size)
			_expect(
				not first_rect.intersects(second_rect),
				"City markers should not overlap at the tested board size."
			)
