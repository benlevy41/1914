extends Node

const MainScene = preload("res://scenes/main.tscn")
const BoardNavigationChecks = preload("res://tests/integration/board_navigation_checks.gd")
const HudChecks = preload("res://tests/integration/hud_checks.gd")
const ReinforcementPathChecks = preload("res://tests/integration/reinforcement_path_checks.gd")

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
		"MarginContainer/Content/GameHUD/Content/Center/Info/DevModeIndicator"
	)
	var setup_prompt: Label = setup_panel.get_node("Prompt")
	var name_input: LineEdit = setup_panel.get_node("LeaderName")
	var setup_error: Label = setup_panel.get_node("Error")
	var continue_button: Button = setup_panel.get_node("Continue")
	var game_panel: HBoxContainer = main_screen.get_node("MarginContainer/Content/MainLayout")
	var game_status: Label = main_screen.get_node("MarginContainer/Content/GameStatus")
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

	_expect(not setup_panel.visible, "The name prompt should close after both names are entered.")
	_expect(game_panel.visible, "The game board should appear after setup.")
	_expect(
		board.get_child_count() == 1
		and board.get_node("ViewportContainer") is SubViewportContainer,
		"The board should host a 3D viewport in the game screen."
	)
	var board_snapshot := board.get("_snapshot") as GameViewSnapshot
	var sub_viewport := board.get_node("ViewportContainer/SubViewport") as SubViewport
	var board_surface := board.get_node(
		"ViewportContainer/SubViewport/Board3D/BoardSurface"
	) as MeshInstance3D
	var board_camera := board.get_node(
		"ViewportContainer/SubViewport/Board3D/Camera3D"
	) as Camera3D
	var map_content := board.get_node(
		"ViewportContainer/SubViewport/Board3D/MapContent"
	) as Node3D
	_expect(
		board_snapshot != null and board_snapshot.cities.size() == 32,
		"The 3D board should receive the game view snapshot."
	)
	var city_visual_count := 0
	var road_visual_count := 0
	var unit_visual_count := 0
	for visual: Node in map_content.get_children():
		if visual.name.begins_with("Road_"):
			road_visual_count += 1
		elif visual.name.begins_with("City_"):
			city_visual_count += 1
			for city_piece: Node in visual.get_children():
				if city_piece.name.begins_with("Unit_"):
					unit_visual_count += 1
	_expect(
		city_visual_count == board_snapshot.cities.size(),
		"Each snapshot city should have a 3D city visual."
	)
	_expect(
		road_visual_count == board_snapshot.connections.size(),
		"Each snapshot connection should have a 3D road visual."
	)
	_expect(
		unit_visual_count == board_snapshot.cities.size(),
		"Each initial garrison unit should have its own 3D visual."
	)
	var paris_visual := map_content.get_node("City_paris") as Node3D
	var koblenz_visual := map_content.get_node("City_koblenz") as Node3D
	var paris_label := paris_visual.get_node("NameLabel") as Label3D
	var koblenz_label := koblenz_visual.get_node("NameLabel") as Label3D
	_expect(
		paris_visual.position.x < koblenz_visual.position.x
		and paris_visual.position.z > koblenz_visual.position.z,
		"Geographic projection should place Paris southwest of Koblenz."
	)
	_expect(
		paris_label.text.contains("Paris")
		and paris_label.text.contains("A")
		and koblenz_label.text.contains("Koblenz")
		and koblenz_label.text.contains("G"),
		"City labels should identify the city and use an owner letter cue."
	)
	_expect(
		sub_viewport.size.x > 0
		and sub_viewport.size.y > 0
		and sub_viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS,
		"The board viewport should have a usable render size and continuously render."
	)
	var original_window_size := get_tree().root.size
	get_tree().root.size = Vector2i(1152, 648)
	for frame: int in 5:
		await get_tree().process_frame
	var original_viewport_size := sub_viewport.size
	get_tree().root.size = Vector2i(1728, 972)
	for frame: int in 5:
		await get_tree().process_frame
	_expect(
		sub_viewport.size.x > original_viewport_size.x
		and sub_viewport.size.y > original_viewport_size.y,
		"The board render target should grow when the game window is enlarged: %s to %s."
		% [original_viewport_size, sub_viewport.size]
	)
	_expect(
		board.get_city_id_at_position(_city_screen_position(board, "paris")) == "paris",
		"City picking should remain aligned after resizing the window."
	)
	get_tree().root.size = original_window_size
	for frame: int in 5:
		await get_tree().process_frame
	_expect(
		sub_viewport.scaling_3d_scale >= 2.0,
		"The 3D board should render at least twice the viewport's resolution per axis."
	)
	_expect(
		paris_label.font_size >= 64
		and is_equal_approx(paris_label.font_size * paris_label.pixel_size, 0.128)
		and is_equal_approx(paris_label.outline_size * paris_label.pixel_size, 0.016),
		"The sharper label should preserve its previous world-space text and outline sizes."
	)
	_expect(
		board_surface.mesh is BoxMesh and board_camera.current,
		"The 3D scene should contain a flat board surface and an active camera."
	)
	_failures += HudChecks.new().check_banner(main_screen)
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

	_select_city(board, "paris")
	phase_action_button.emit_signal("pressed")
	_expect(
		turn_status.text == "Choose a city owned by the player placing a reserve.",
		"The active player should not be able to place on an opponent's city."
	)
	_expect(
		_board_city(board, "paris").unit_count == 1,
		"Rejected placement must not change the garrison."
	)
	_expect(
		turn_status.text != "Ada's turn - 5 reserve units remaining.",
		"A rejected placement must not advance the turn."
	)

	_select_city(board, "koblenz")
	_failures += BoardNavigationChecks.new().check_clearing(main_screen, board, "reserve")
	_select_city(board, "koblenz")
	phase_action_button.emit_signal("pressed")
	_expect(
		_board_city(board, "koblenz").unit_count == 2,
		"A reserve should increase the garrison."
	)
	_expect(
		_count_unit_visuals(board) == 33,
		"Refreshing the snapshot should add the newly placed unit visual."
	)
	_expect(
		turn_status.text == "Ada's turn - 5 reserve units remaining.",
		"The Allies should place after the German Empire."
	)
	_select_city(board, "paris")
	phase_action_button.emit_signal("pressed")
	_expect(
		turn_status.text == "Otto's turn - 4 reserve units remaining.",
		"Players should alternate after a successful placement."
	)

	for placement_index: int in 8:
		var active_city_id := "koblenz" if placement_index % 2 == 0 else "paris"
		_select_city(board, active_city_id)
		phase_action_button.emit_signal("pressed")

	_expect(
		turn_status.text.begins_with("Otto's reinforcement phase - 3 units remaining."),
		"After setup, Germany should begin the first reinforcement phase."
	)
	_expect(
		not phase_action_button.disabled,
		"The active player should be able to place reinforcements."
	)
	_expect(
		_board_city(board, "koblenz").unit_count == 6,
		"All five German reserves should have been placed."
	)
	_expect(
		_board_city(board, "paris").unit_count == 6,
		"All five Allied reserves should have been placed."
	)
	_expect(
		game_status.visible and game_status.text.contains("Reinforcement phase"),
		"Finishing setup should display the reinforcement instructions."
	)

	_select_city(board, "paris")
	_expect(
		selected_city_label.text == "Paris - Ada, 6 units",
		"The screen should display information about the selected city."
	)
	for reinforcement_index: int in 3:
		_select_city(board, "koblenz")
		main_screen.call("_on_city_context_requested", "koblenz", Vector2.ZERO)
		(main_screen.get_node("CityContextMenu") as PopupMenu).emit_signal("id_pressed", 4)
		(main_screen.get_node("CityContextMenu") as PopupMenu).hide()
	_expect(
		_board_city(board, "koblenz").unit_count == 9,
		"All three German reinforcements should be placed before attacks begin."
	)
	_expect(
		turn_status.text == "Placed one reinforcement in Koblenz.",
		"Germany should remain active after completing reinforcement placement."
	)
	_expect(
		game_status.text.contains("Attack phase: select a source city"),
		"Placing all reinforcements should display the attack phase."
	)

	var main_game_application := main_screen.get("_game_application") as GameApplication
	var game_state := main_game_application._active_game_state as GameState
	_select_city(board, "paris")
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
	_select_city(board, "koblenz")
	_select_city(board, "saarbrucken")
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
	_select_city(board, "saarbrucken")
	attack_action_button.emit_signal("pressed")
	_expect(
		defender_prompt.text == "Ada: choose defending units.",
		"The defending player should choose a commitment for each combat round."
	)
	_failures += BoardNavigationChecks.new().check_clearing(main_screen, board, "attack")
	_select_city(board, "koblenz")
	_select_city(board, "saarbrucken")
	attack_action_button.emit_signal("pressed")
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
	_select_city(board, "koblenz")
	_select_city(board, "luxembourg")
	_expect(
		not move_units_button.disabled,
		"A legal route should enable the unit transfer action."
	)
	_failures += BoardNavigationChecks.new().check_clearing(main_screen, board, "reorganization")
	_select_city(board, "koblenz")
	_select_city(board, "luxembourg")
	reorganization_commitment.value = 1
	move_units_button.emit_signal("pressed")
	_expect(
		koblenz_city.unit_count == koblenz_units_before_move - 1
		and luxembourg_city.unit_count == 2,
		"Moving units should update both city garrisons."
	)
	_select_city(board, "luxembourg")
	_select_city(board, "koblenz")
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
		turn_status.text.begins_with("Ada's reinforcement phase - 3 units remaining."),
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
		quick_start_board.get_node("ViewportContainer/SubViewport/Board3D") != null,
		"Quick start should display the 3D board scene."
	)
	_expect(
		not quick_start_screen.get_node(
			"MarginContainer/Content/GameHUD/Content/Center/Info/DevModeIndicator"
		).visible,
		"Normal quick start should not display the developer-mode indicator."
	)
	var quick_start_context_menu := quick_start_screen.get_node("CityContextMenu") as PopupMenu
	var quick_start_selection := quick_start_screen.get_node(
		"MarginContainer/Content/MainLayout/Sidebar/SelectedCity"
	) as Label
	await _test_board_interactions(quick_start_board, quick_start_selection)
	await get_tree().process_frame
	_failures += await BoardNavigationChecks.new().run_overview(quick_start_board)
	_send_mouse(_city_screen_position(quick_start_board, "paris"), MOUSE_BUTTON_RIGHT)
	_expect(
		quick_start_context_menu.visible and quick_start_context_menu.get_item_index(1) == -1,
		"Right-clicking a city should open gameplay actions without developer options."
	)
	quick_start_screen.call(
		"_on_city_context_requested",
		"paris",
		Vector2.ZERO
	)
	_expect(
		quick_start_context_menu.visible and quick_start_context_menu.get_item_index(1) == -1,
		"Normal games should not expose developer options for a city."
	)
	_failures += HudChecks.new().check_normal_game(quick_start_screen)
	get_tree().root.remove_child(quick_start_screen)
	quick_start_screen.free()

	_failures += await ReinforcementPathChecks.new().run(get_tree().root)

	var dev_mode_screen := MainScene.instantiate() as Control
	get_tree().root.add_child(dev_mode_screen)
	await get_tree().process_frame
	var dev_mode_menu: VBoxContainer = dev_mode_screen.get_node(
		"MarginContainer/Content/MenuPanel"
	)
	var dev_mode_error: Label = dev_mode_menu.get_node("Error")
	var dev_mode_screen_button: Button = dev_mode_menu.get_node("DevMode")
	var dev_mode_screen_indicator: Label = dev_mode_screen.get_node(
		"MarginContainer/Content/GameHUD/Content/Center/Info/DevModeIndicator"
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
		_failures += await BoardNavigationChecks.new().check_dev_overview(dev_mode_screen, dev_mode_board)
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
		_failures += HudChecks.new().check_banner(dev_mode_screen)
		_expect(
			dev_mode_board.get_node("ViewportContainer/SubViewport/Board3D") != null,
			"Dev mode should display the 3D board scene."
		)
		var dev_paris_position := _city_screen_position(dev_mode_board, "paris")
		_send_mouse(dev_paris_position, MOUSE_BUTTON_RIGHT)
		_expect(
			dev_mode_context_menu.visible and dev_mode_screen.get("_context_city_id") == "paris",
			"Right-clicking a city should open its developer context menu."
		)
		await get_tree().process_frame
		var dev_camera := dev_mode_board.get_node(
			"ViewportContainer/SubViewport/Board3D/Camera3D"
		) as Camera3D
		var menu_camera_position := dev_camera.position
		_set_physical_key(KEY_D, true)
		await get_tree().process_frame
		dev_mode_board.call("_process", 1.0)
		_set_physical_key(KEY_D, false)
		_send_mouse(_city_screen_position(dev_mode_board, "paris"), MOUSE_BUTTON_WHEEL_UP)
		_expect(
			dev_camera.position == menu_camera_position,
			"The camera should not pan or zoom while the context menu is open."
		)
		await get_tree().process_frame
		_send_mouse(_city_screen_position(dev_mode_board, "koblenz"), MOUSE_BUTTON_RIGHT)
		_expect(
			dev_mode_context_menu.visible
			and dev_mode_screen.get("_context_city_id") == "koblenz",
			"Right-clicking another city should replace the open context menu target "
			+ "(visible=%s, target=%s, picked=%s)."
			% [
				dev_mode_context_menu.visible,
				dev_mode_screen.get("_context_city_id"),
				dev_mode_board.get_city_id_at_position(
					_city_screen_position(dev_mode_board, "koblenz")
				),
			]
		)
		dev_mode_context_menu.hide()
		var paris := dev_mode_state.find_city("paris")
		var original_paris_units := paris.unit_count
		var paris_model := dev_mode_board.get_node(
			"ViewportContainer/SubViewport/Board3D/MapContent/City_paris/CityModel"
		) as MeshInstance3D
		var original_paris_color := (
			paris_model.material_override as StandardMaterial3D
		).albedo_color
		dev_mode_screen.call("_on_city_context_requested", "paris", Vector2.ZERO)
		_expect(
			dev_mode_context_menu.visible,
			"Requesting developer options for a city should open its context menu."
		)
		_expect(
			dev_mode_context_menu.get_item_index(4) >= 0
			and dev_mode_context_menu.get_item_index(1) >= 0
			and dev_mode_context_menu.get_item_index(2) >= 0
			and dev_mode_context_menu.get_item_index(3) >= 0,
			"Dev mode should offer ownership, add-unit, and remove-unit options."
		)
		_expect(
			not dev_mode_context_menu.is_item_disabled(dev_mode_context_menu.get_item_index(1)),
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
			_board_city(dev_mode_board, "paris").owner_name == "Moltke",
			"The board snapshot should refresh to show the new owner."
		)
		_failures += HudChecks.new().check_banner(dev_mode_screen)
		paris_model = dev_mode_board.get_node(
			"ViewportContainer/SubViewport/Board3D/MapContent/City_paris/CityModel"
		) as MeshInstance3D
		_expect(
			(paris_model.material_override as StandardMaterial3D).albedo_color
			!= original_paris_color,
			"Changing ownership should update the city's visual material."
		)
		var units_before_dialog := paris.unit_count
		dev_mode_context_menu.emit_signal("id_pressed", 2)
		_expect(unit_change_dialog.visible, "Add units should open the unit-count dialog.")
		_set_physical_key(KEY_D, true)
		await get_tree().process_frame
		var dialog_camera_position := dev_camera.position
		dev_mode_board.call("_process", 1.0)
		_set_physical_key(KEY_D, false)
		_expect(
			dev_camera.position == dialog_camera_position,
			"The camera should not pan while the unit dialog is open."
		)
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

		dev_mode_screen.call("_on_city_context_requested", "paris", Vector2.ZERO)
		dev_mode_context_menu.emit_signal("id_pressed", 2)
		unit_count_selector.value = 3
		unit_change_dialog.get_ok_button().emit_signal("pressed")
		_expect(
			paris.unit_count == units_before_dialog + 3,
			"Confirming Add units should apply the selected amount."
		)
		_failures += HudChecks.new().check_banner(dev_mode_screen)
		_expect(
			_board_city(dev_mode_board, "paris").unit_count == paris.unit_count,
			"The board snapshot should refresh after adding units."
		)

		dev_mode_screen.call("_on_city_context_requested", "paris", Vector2.ZERO)
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
		dev_mode_screen.call("_on_city_context_requested", "paris", Vector2.ZERO)
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
			_board_city(dev_mode_board, "paris").owner_id.is_empty(),
			"An unoccupied city should remain uncontrolled in the board snapshot."
		)
		dev_mode_screen.call("_on_city_context_requested", "paris", Vector2.ZERO)
		_expect(
			not dev_mode_context_menu.is_item_disabled(dev_mode_context_menu.get_item_index(2))
			and dev_mode_context_menu.is_item_disabled(dev_mode_context_menu.get_item_index(3)),
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
			_board_city(dev_mode_board, "paris").owner_name == "Moltke",
			"Reoccupying a city should restore its remembered owner in the board snapshot."
		)

		var unoccupied_city := dev_mode_state.find_city("antwerp")
		unoccupied_city.owner_id = ""
		unoccupied_city.unit_count = 0
		dev_mode_screen.call("_refresh_game_view")
		dev_mode_screen.call("_on_city_context_requested", "antwerp", Vector2.ZERO)
		_expect(
			dev_mode_context_menu.visible,
			"The dev context menu should still open for an unoccupied city."
		)
		_expect(
			dev_mode_context_menu.get_item_index(1) >= 0
			and dev_mode_context_menu.get_item_index(2) >= 0
			and dev_mode_context_menu.get_item_index(3) >= 0,
			"Developer options should remain displayed for an unoccupied city."
		)
		_expect(
			dev_mode_context_menu.is_item_disabled(dev_mode_context_menu.get_item_index(1)),
			"Change owner should be disabled for an unoccupied city."
		)
		_expect(
			not dev_mode_context_menu.is_item_disabled(dev_mode_context_menu.get_item_index(2))
			and dev_mode_context_menu.is_item_disabled(dev_mode_context_menu.get_item_index(3)),
			"Add is enabled for an unoccupied city with a remembered owner; "
			+ "Remove should be disabled."
		)

		dev_mode_screen.call("_on_city_context_requested", "paris", Vector2.ZERO)
		dev_mode_screen.call("_on_city_context_requested", "antwerp", Vector2.ZERO)
		_expect(
			dev_mode_context_menu.visible
			and dev_mode_screen.get("_context_city_id") == "antwerp",
			"Requesting another city while the context menu is open should replace its target."
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
		_failures += HudChecks.new().check_game_over(dev_mode_screen)
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


func _select_city(board: BoardView, city_id: String) -> void:
	board.city_selected.emit(city_id)


func _test_board_interactions(board: BoardView, selected_city_label: Label) -> void:
	var container := board.get_node("ViewportContainer") as SubViewportContainer
	var camera := board.get_node("ViewportContainer/SubViewport/Board3D/Camera3D") as Camera3D
	var content := board.get_node("ViewportContainer/SubViewport/Board3D/MapContent") as Node3D
	var original_position := camera.position
	var original_rotation := camera.rotation
	var original_target: Vector3 = board.get("_camera_target")
	var original_distance: float = board.get("_camera_distance")
	var paris_position := _city_screen_position(board, "paris")
	_send_mouse(paris_position, MOUSE_BUTTON_LEFT)
	_expect(
		board.get_selected_city_id() == "paris" and selected_city_label.text.begins_with("Paris"),
		"Clicking a projected city should select it through the screen controller."
	)
	var paris_selection := content.get_node("City_paris/Selection") as MeshInstance3D
	_expect(paris_selection.visible, "The selected city should display its selection marker.")
	_send_mouse(_city_screen_position(board, "koblenz"), MOUSE_BUTTON_LEFT)
	var koblenz_selection := content.get_node("City_koblenz/Selection") as MeshInstance3D
	_expect(
		board.get_selected_city_id() == "koblenz"
		and koblenz_selection.visible
		and not paris_selection.visible,
		"Selecting another city should move the selection marker."
	)
	_send_mouse(paris_position, MOUSE_BUTTON_LEFT)
	_send_mouse(container.get_global_rect().position + Vector2(2, 2), MOUSE_BUTTON_LEFT)
	_expect(
		board.get_selected_city_id().is_empty()
		and not paris_selection.visible
		and selected_city_label.text == "Select a city on the board.",
		"Clicking empty board space should clear the city selection."
	)
	_expect(
		board.get_city_id_at_position(container.get_global_rect().position - Vector2.ONE) == "",
		"Positions outside the board must not pick a city."
	)
	_send_mouse(paris_position, MOUSE_BUTTON_LEFT)
	board.refresh_snapshot(board.get("_snapshot") as GameViewSnapshot)
	paris_selection = content.get_node("City_paris/Selection") as MeshInstance3D
	_expect(
		board.get_selected_city_id() == "paris" and paris_selection.visible,
		"Refreshing the snapshot should retain the selected city's marker."
	)
	board.clear_selection()
	_expect(
		board.get_selected_city_id().is_empty() and not paris_selection.visible,
		"Clearing selection should hide the marker."
	)

	var text_input := LineEdit.new()
	board.add_child(text_input)
	text_input.grab_focus()
	_set_physical_key(KEY_D, true)
	await get_tree().process_frame
	board.call("_process", 1.0)
	_set_physical_key(KEY_D, false)
	_send_mouse(paris_position, MOUSE_BUTTON_WHEEL_UP)
	_expect(
		camera.position.is_equal_approx(original_position),
		"Typing in a text field should prevent both panning and scroll zoom."
	)
	text_input.free()

	_failures += BoardNavigationChecks.new().run(board, _city_screen_position(board, "paris"))
	var saved_window_size := get_tree().root.size
	get_tree().root.size = Vector2i(1728, 972)
	for frame: int in 5:
		await get_tree().process_frame
	_failures += BoardNavigationChecks.new().run(board, _city_screen_position(board, "paris"))
	get_tree().root.size = saved_window_size
	for frame: int in 5:
		await get_tree().process_frame

	for step: int in 30:
		_send_mouse(paris_position, MOUSE_BUTTON_WHEEL_UP)
	var nearest_position := camera.position
	_send_mouse(paris_position, MOUSE_BUTTON_WHEEL_UP)
	_expect(
		camera.position.is_equal_approx(nearest_position)
		and nearest_position.y > 0.0
		and nearest_position.y < original_position.y,
		"Scroll zoom should stop at the near limit above the board."
	)
	for step: int in 40:
		_send_mouse(paris_position, MOUSE_BUTTON_WHEEL_DOWN)
	var farthest_position := camera.position
	_send_mouse(paris_position, MOUSE_BUTTON_WHEEL_DOWN)
	_expect(
		camera.position.is_equal_approx(farthest_position)
		and farthest_position.distance_to(original_position) > 1.0,
		"Scroll zoom should stop at the far limit."
	)
	_send_mouse(paris_position, MOUSE_BUTTON_WHEEL_UP)
	await get_tree().create_timer(0.35).timeout
	_expect(
		camera.rotation.is_equal_approx(original_rotation),
		"Zooming in from the strategic view should restore the original angle."
	)
	_set_physical_key(KEY_D, true)
	await get_tree().process_frame
	board.call("_process", 100.0)
	var pan_limit_position := camera.position
	board.call("_process", 100.0)
	_set_physical_key(KEY_D, false)
	_expect(
		camera.position.is_equal_approx(pan_limit_position)
		and pan_limit_position.x > original_position.x
		and camera.rotation.is_equal_approx(original_rotation),
		"WASD should pan within board bounds without changing camera rotation."
	)
	board.set("_camera_target", original_target)
	board.set("_camera_distance", original_distance)
	board.call("_update_camera")


func _city_screen_position(board: BoardView, city_id: String) -> Vector2:
	var container := board.get_node("ViewportContainer") as SubViewportContainer
	var viewport := container.get_node("SubViewport") as SubViewport
	var camera := viewport.get_node("Board3D/Camera3D") as Camera3D
	var city := viewport.get_node("Board3D/MapContent/City_%s" % city_id) as Node3D
	var position := camera.unproject_position(city.global_position + Vector3(0, 0.13, 0))
	return (
		container.get_global_transform_with_canvas()
		* (position * container.size / Vector2(viewport.size))
	)


func _send_mouse(position: Vector2, button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = button
	event.pressed = true
	get_tree().root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	get_tree().root.push_input(event)


func _set_physical_key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)


func _board_city(board: BoardView, city_id: String) -> GameViewSnapshot.CityView:
	var snapshot := board.get("_snapshot") as GameViewSnapshot
	return snapshot.find_city(city_id)


func _count_unit_visuals(board: BoardView) -> int:
	var map_content := board.get_node(
		"ViewportContainer/SubViewport/Board3D/MapContent"
	) as Node3D
	var unit_count := 0
	for city_visual: Node in map_content.get_children():
		for city_piece: Node in city_visual.get_children():
			if city_piece.name.begins_with("Unit_"):
				unit_count += 1
	return unit_count


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
