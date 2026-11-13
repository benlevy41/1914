extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var error := change_scene_to_file(MAIN_SCENE)
	if error != OK:
		push_error("Could not load the main scene: %d" % error)
		quit(1)
		return
	await process_frame
	await process_frame
	var screen := current_scene as Control
	var app := screen.get("_game_application") as GameApplication
	var return_button := (
		screen.get_node("MarginContainer/Content/MainLayout/Sidebar/ReturnToMenu") as Button
	)
	_expect(not return_button.visible, "Returning to the menu should not be offered during play.")
	if OS.is_debug_build():
		_button(screen, "DevMode").emit_signal("pressed")
	else:
		_button(screen, "QuickStart").emit_signal("pressed")
	await process_frame
	var state := app._active_game_state as GameState
	for index: int in state.reinforcements_remaining:
		_expect(app.place_reinforcement("koblenz").succeeded(), "Place German reinforcements.")
	_refresh(screen)
	var paris := state.find_city("paris")
	paris.assign_owner("german_empire")
	(screen.get("_end_attack_button") as Button).emit_signal("pressed")
	(screen.get("_end_reorganization_button") as Button).emit_signal("pressed")
	_expect(
		state.active_player_id == "allies" and state.reinforcements_remaining == 0,
		"The Allies should receive no reinforcements when Paris is captured."
	)
	var phase_button := screen.get("_phase_action_button") as Button
	_expect(
		phase_button.visible and not phase_button.disabled
		and phase_button.text == "Begin attack phase",
		"The next player should be able to advance from a zero-reinforcement turn."
	)
	phase_button.emit_signal("pressed")
	_expect(state.phase == GameState.Phase.ATTACK, "The zero-pool action should begin attacks.")
	for city: GameCity in state.cities:
		if city.owner_id == "german_empire":
			city.leave_unoccupied()
			city.unit_count = 0
	var luxembourg := state.find_city("luxembourg")
	luxembourg.assign_owner("allies")
	luxembourg.unit_count = 3
	_refresh(screen)
	_open_action(screen, "luxembourg", 6)
	(screen.get("_board") as BoardView).city_selected.emit("koblenz")
	var prompt := screen.get_node("TransferPrompt") as Control
	_expect(prompt.visible, "A legal occupation should open the transfer prompt.")
	(prompt.find_child("Confirm", true, false) as Button).emit_signal("pressed")
	_expect(
		state.winner_id == "allies" and return_button.visible
		and (screen.get("_game_status") as Label).text.contains("wins"),
		"Capturing Koblenz after elimination should show the Allied winner and menu action."
	)
	_expect(not app.end_attack_phase().succeeded(), "Actions should be rejected after victory.")
	return_button.emit_signal("pressed")
	await process_frame
	await process_frame
	screen = current_scene as Control
	app = screen.get("_game_application") as GameApplication
	_expect(
		app.get_view_snapshot() == null and not app.is_dev_mode_active()
		and (screen.get_node("MarginContainer/Content/MenuPanel") as Control).visible
		and not (screen.get_node("MarginContainer/Content/GameHUD") as Control).visible
		and not (
			screen.get_node("MarginContainer/Content/MainLayout/Sidebar/ReturnToMenu") as Button
		).visible,
		"Returning to the menu should create a fresh screen without prior game or dev state."
	)
	_button(screen, "QuickStart").emit_signal("pressed")
	await process_frame
	state = app._active_game_state
	_expect(
		not app.is_dev_mode_active() and state.winner_id.is_empty()
		and not app.add_units_for_development("paris", 1).succeeded(),
		"A normal game after dev mode must not retain its winner or developer privileges."
	)
	for index: int in state.reinforcements_remaining:
		_expect(app.place_reinforcement("koblenz").succeeded(), "Place new-game reinforcements.")
	for city: GameCity in state.cities:
		if city.owner_id == "allies":
			city.leave_unoccupied()
			city.unit_count = 0
	paris = state.find_city("paris")
	paris.assign_owner("german_empire")
	paris.unit_count = 3
	var amiens := state.find_city("amiens")
	amiens.assign_owner("allies")
	amiens.unit_count = 1
	_set_winning_seed(app)
	_refresh(screen)
	_open_action(screen, "paris", 5)
	(screen.get("_board") as BoardView).city_selected.emit("amiens")
	var combat_prompt := screen.get_node("CombatPrompt") as Control
	_expect(combat_prompt.visible, "A legal attack should open the combat prompt.")
	(combat_prompt.find_child("Units", true, false) as SpinBox).value = 2
	(combat_prompt.find_child("Confirm", true, false) as Button).emit_signal("pressed")
	(combat_prompt.find_child("Confirm", true, false) as Button).emit_signal("pressed")
	return_button = screen.get_node("MarginContainer/Content/MainLayout/Sidebar/ReturnToMenu")
	_expect(
		state.winner_id == "german_empire" and return_button.visible
		and (screen.get("_turn_status") as Label).text.contains("Moltke wins"),
		"Eliminating the last Allied unit after capturing Paris should show German victory."
	)
	_expect(
		not app.resolve_attack_round("paris", "amiens", 1, 1).succeeded(),
		"Combat should be rejected after victory."
	)
	return_button.emit_signal("pressed")
	await process_frame
	await process_frame
	screen = current_scene as Control
	_button(screen, "CustomGame").emit_signal("pressed")
	var name_input := screen.get_node("MarginContainer/Content/SetupPanel/LeaderName") as LineEdit
	var next := screen.get_node("MarginContainer/Content/SetupPanel/Continue") as Button
	name_input.text = "New Allied leader"
	next.emit_signal("pressed")
	name_input.text = "New German leader"
	next.emit_signal("pressed")
	await process_frame
	app = screen.get("_game_application") as GameApplication
	var snapshot := app.get_view_snapshot()
	_expect(
		snapshot != null and snapshot.winner_id.is_empty()
		and snapshot.phase == GameViewSnapshot.Phase.INITIAL_RESERVE_PLACEMENT
		and snapshot.find_player("allies").name == "New Allied leader"
		and snapshot.find_player("german_empire").name == "New German leader",
		"A second return should allow a fresh custom game with new names."
	)
	if _failures == 0:
		print("Complete game flow integration tests passed.")
	quit(1 if _failures > 0 else 0)


func _button(screen: Control, name: String) -> Button:
	return screen.get_node("MarginContainer/Content/MenuPanel/" + name) as Button


func _refresh(screen: Control) -> void:
	screen.call("_refresh_game_view")
	screen.call("_update_phase_status")


func _open_action(screen: Control, city_id: String, action: int) -> void:
	screen.call("_on_city_context_requested", city_id, Vector2.ZERO)
	var menu := screen.get_node("CityContextMenu") as PopupMenu
	menu.emit_signal("id_pressed", action)
	menu.hide()


func _set_winning_seed(app: GameApplication) -> void:
	var generator := RandomNumberGenerator.new()
	for seed_value: int in 1000:
		generator.seed = seed_value
		if CombatService.new(generator).resolve_round(2, 1).defender_losses == 1:
			app._random_generator.seed = seed_value
			return
	push_error("Could not find a winning combat seed.")
	_failures += 1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
