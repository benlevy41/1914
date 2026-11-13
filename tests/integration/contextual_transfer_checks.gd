extends RefCounted

const MainScene = preload("res://scenes/main.tscn")

var _failures: int = 0
var _root: Window
var _screen: Control
var _board: BoardView
var _menu: PopupMenu
var _prompt: Control
var _units: SpinBox
var _confirm: Button
var _cancel: Button
var _application: GameApplication
var _state: GameState


func run(root: Window) -> int:
	_root = root
	var original_size := root.size
	root.size = Vector2i(1152, 648)
	await _start_game()
	await _check_occupation()
	await _check_legacy_occupation()
	await _check_combat_capture()
	await _check_reorganization()
	await _check_stale_transfer()
	await _check_phase_change()
	_screen.free()
	await _start_game()
	await _check_end_phase_button()
	_screen.free()
	await _start_game()
	await _check_occupation_victory()
	_screen.free()
	if OS.is_debug_build():
		await _start_game(true)
		await _check_development_changes()
		_screen.free()
	root.size = original_size
	return _failures


func _start_game(dev_mode: bool = false) -> void:
	_screen = MainScene.instantiate() as Control
	_root.add_child(_screen)
	await _root.get_tree().process_frame
	_application = _screen.get("_game_application") as GameApplication
	var button := "DevMode" if dev_mode else "QuickStart"
	_screen.get_node("MarginContainer/Content/MenuPanel/%s" % button).emit_signal("pressed")
	await _root.get_tree().process_frame
	_board = _screen.get_node("MarginContainer/Content/MainLayout/Board") as BoardView
	_menu = _screen.get_node("CityContextMenu") as PopupMenu
	_prompt = _screen.get_node("TransferPrompt") as Control
	_units = _prompt.find_child("Units", true, false) as SpinBox
	_confirm = _prompt.find_child("Confirm", true, false) as Button
	_cancel = _prompt.find_child("Cancel", true, false) as Button
	_state = _application._active_game_state
	for index: int in _state.reinforcements_remaining:
		_expect(_application.place_reinforcement("koblenz").succeeded(), "Reach attack phase.")
	for city: GameCity in _state.cities:
		city.leave_unoccupied()
		city.unit_count = 0
	_set_city("koblenz", "german_empire", 3)
	_set_city("luxembourg", "german_empire", 2)
	_set_city("metz", "german_empire", 2)
	_set_city("liege", "german_empire", 1)
	_set_city("albert", "german_empire", 3)
	_set_city("amiens", "german_empire", 1)
	_set_city("saarbrucken", "allies", 2)
	_set_city("strasbourg", "allies", 1)
	_set_city("paris", "allies", 1)
	_refresh()
	_board.call("_enter_overview")
	await _root.get_tree().create_timer(0.35).timeout


func _set_city(city_id: String, owner_id: String, units: int) -> void:
	var city := _state.find_city(city_id)
	if owner_id.is_empty():
		city.leave_unoccupied()
	else:
		city.assign_owner(owner_id)
	city.unit_count = units


func _refresh() -> void:
	_screen.call("_refresh_game_view")
	_screen.call("_update_phase_status")


func _open_menu(city_id: String) -> void:
	_click(_board.get_city_screen_position(city_id), MOUSE_BUTTON_RIGHT)
	await _root.get_tree().process_frame


func _choose_action(city_id: String, item_id: int, mouse: bool = false) -> void:
	await _open_menu(city_id)
	var index := _menu.get_item_index(item_id)
	_expect(_menu.visible and index >= 0, "The contextual transfer action should be available.")
	if index < 0:
		return
	_expect(not _menu.is_item_disabled(index), "The contextual transfer action should be enabled.")
	if mouse:
		var fraction := 0.75 if item_id == 6 else 0.5
		_click(Vector2(_menu.position) + Vector2(_menu.size.x / 2.0, _menu.size.y * fraction),
			MOUSE_BUTTON_LEFT)
	else:
		_menu.emit_signal("id_pressed", item_id)
		_menu.hide()
	await _root.get_tree().process_frame


func _select(city_id: String) -> void:
	_click(_board.get_city_screen_position(city_id), MOUSE_BUTTON_LEFT)
	await _root.get_tree().process_frame


func _press(button: Button) -> void:
	_click(button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	await _root.get_tree().process_frame


func _highlighted(city_id: String) -> bool:
	var visual := _board.get_node(
		"ViewportContainer/SubViewport/Board3D/MapContent/City_%s/ActionTarget" % city_id
	) as MeshInstance3D
	return visual.visible


func _check_occupation() -> void:
	await _open_menu("liege")
	_expect(
		_menu.is_item_disabled(_menu.get_item_index(6))
		and _menu.get_item_tooltip(_menu.get_item_index(6)).contains("leave a unit"),
		"A one-unit source cannot occupy another city."
	)
	_menu.hide()
	await _root.get_tree().process_frame
	await _open_menu("saarbrucken")
	_expect(
		_menu.is_item_disabled(_menu.get_item_index(6)),
		"An enemy city cannot be an occupation source."
	)
	_menu.hide()
	await _root.get_tree().process_frame
	await _choose_action("koblenz", 6, true)
	_expect(
		_highlighted("aachen") and not _highlighted("saarbrucken")
		and not _highlighted("luxembourg") and not _highlighted("verdun"),
		"Occupation should highlight only legal adjacent unoccupied cities."
	)
	await _choose_action("luxembourg", 6)
	_expect(
		_highlighted("verdun") and not _highlighted("aachen"),
		"Retargeting should replace the legal occupation highlights."
	)
	await _choose_action("koblenz", 5)
	_expect(
		_highlighted("saarbrucken") and not _highlighted("aachen"),
		"Switching from occupation to attack should replace the highlights."
	)
	await _choose_action("koblenz", 6)
	await _select("verdun")
	_expect(
		not _prompt.visible and _board.get_selected_city_id() == "koblenz"
		and (_screen.get("_turn_status") as Label).text.contains("direct road"),
		"An invalid occupation target should retain the source and explain why."
	)
	_set_city("aachen", "allies", 1)
	await _select("aachen")
	_expect(
		not _prompt.visible and _board.get_selected_city_id() == "koblenz"
		and (_screen.get("_turn_status") as Label).text.contains("unoccupied"),
		"An occupation target should be revalidated when selected."
	)
	_set_city("aachen", "", 0)
	_screen.call("_refresh_game_view")
	await _select("aachen")
	_expect(
		_prompt.visible and _units.max_value == 2 and not _highlighted("aachen")
		and (_screen.get("_end_attack_button") as Button).disabled,
		"A legal occupation target should open a bounded prompt and block phase ending."
	)
	await _press(_cancel)
	_expect(
		not _prompt.visible and _state.find_city("koblenz").unit_count == 3
		and _state.find_city("aachen").owner_id.is_empty(),
		"Cancelling occupation must not move units."
	)
	await _choose_action("koblenz", 6)
	await _select("aachen")
	_set_city("aachen", "allies", 1)
	await _press(_confirm)
	_expect(
		not _prompt.visible and _state.find_city("koblenz").unit_count == 3
		and _state.find_city("aachen").unit_count == 1
		and (_screen.get("_turn_status") as Label).text.contains("unoccupied"),
		"An occupation invalidated before confirmation must not move units."
	)
	_set_city("aachen", "", 0)
	_refresh()
	await _choose_action("koblenz", 6)
	await _select("aachen")
	_units.get_line_edit().text = "2"
	await _press(_confirm)
	var snapshot := _screen.get("_game_snapshot") as GameViewSnapshot
	_expect(
		not _prompt.visible and _state.find_city("koblenz").unit_count == 1
		and _state.find_city("aachen").unit_count == 2
		and _state.find_city("aachen").owner_id == "german_empire"
		and snapshot.find_city("aachen").unit_count == 2
		and (_screen.get("_selected_city_label") as Label).text.contains("2 units")
		and (_screen.get("_turn_status") as Label).text.contains("occupied"),
		"Occupation should move units, update ownership, and refresh the view."
	)
	_check_hud_totals("german_empire")
	await _open_menu("koblenz")
	_expect(
		_menu.is_item_disabled(_menu.get_item_index(6)),
		"Occupation should not allow the last source unit to move."
	)
	_menu.hide()
	await _root.get_tree().process_frame


func _check_reorganization() -> void:
	(_screen.get("_end_attack_button") as Button).emit_signal("pressed")
	_set_city("koblenz", "german_empire", 3)
	_refresh()
	await _choose_action("luxembourg", 7)
	await _select("metz")
	_units.get_line_edit().text = "1+1"
	_units.get_line_edit().emit_signal("text_changed", "1+1")
	await _press(_confirm)
	_expect(
		_prompt.visible and (_prompt.find_child("Warning", true, false) as Label).visible
		and _state.find_city("luxembourg").unit_count == 2,
		"A full-garrison expression should show the warning before it can be confirmed."
	)
	await _press(_cancel)
	await _choose_action("luxembourg", 7)
	await _select("metz")
	var units_rect := _units.get_global_rect()
	_click(Vector2(units_rect.end.x - 8, units_rect.position.y + 8), MOUSE_BUTTON_LEFT)
	await _root.get_tree().process_frame
	_expect(
		(_prompt.find_child("Warning", true, false) as Label).visible,
		"Selecting the full garrison with the increment arrow should show the warning."
	)
	_click(_board.get_global_rect().position + Vector2(2, 2), MOUSE_BUTTON_LEFT)
	_expect(
		not _prompt.visible and _state.find_city("luxembourg").unit_count == 2,
		"Clicking empty board space should cancel the pending transfer."
	)
	await _choose_action("koblenz", 7, true)
	_expect(
		_highlighted("luxembourg") and _highlighted("metz")
		and not _highlighted("albert") and not _highlighted("saarbrucken")
		and not _highlighted("verdun"),
		"Reorganization targets should include controlled multi-road routes but not blocked cities."
	)
	await _select("albert")
	_expect(
		not _prompt.visible and _board.get_selected_city_id() == "koblenz"
		and (_screen.get("_turn_status") as Label).text.contains("roads occupied"),
		"A disconnected destination should be rejected without losing the source."
	)
	await _select("metz")
	var warning := _prompt.find_child("Warning", true, false) as Label
	_expect(
		_prompt.visible and _units.max_value == 3 and not warning.visible
		and (_screen.get("_end_reorganization_button") as Button).disabled,
		"Reorganization should open a bounded prompt and block phase ending."
	)
	_units.get_line_edit().text = "3"
	_units.get_line_edit().emit_signal("text_changed", "3")
	await _root.get_tree().process_frame
	_expect(warning.visible and warning.text.contains("unoccupied"), "Abandonment needs a warning.")
	await _press(_confirm)
	_expect(
		_state.find_city("koblenz").owner_id.is_empty()
		and _state.find_city("koblenz").unit_count == 0
		and _state.find_city("metz").unit_count == 5,
		"A full transfer should abandon the source and update the distant destination."
	)
	_check_hud_totals("german_empire")
	await _choose_action("albert", 7)
	_expect(
		_highlighted("amiens") and not _highlighted("metz"),
		"An isolated controlled network should still allow transfers within it."
	)
	await _select("amiens")
	await _press(_confirm)
	_expect(
		_state.find_city("albert").unit_count == 2
		and _state.find_city("amiens").unit_count == 2
		and _state.phase == GameState.Phase.REORGANIZATION,
		"A second transfer should be possible in the same phase."
	)


func _check_legacy_occupation() -> void:
	await _select("luxembourg")
	await _select("verdun")
	var button := _screen.get("_attack_action_button") as Button
	_expect(
		not button.disabled and button.text == "Occupy target",
		"The original occupation controls should remain available."
	)
	button.emit_signal("pressed")
	_expect(
		_state.find_city("verdun").owner_id == "german_empire"
		and _state.find_city("verdun").unit_count == 1
		and _state.find_city("luxembourg").unit_count == 1,
		"The original occupation path should still move units."
	)
	_set_city("verdun", "", 0)
	_set_city("luxembourg", "german_empire", 2)
	_refresh()


func _check_combat_capture() -> void:
	_set_city("koblenz", "german_empire", 3)
	_set_city("saarbrucken", "allies", 1)
	_refresh()
	await _choose_action("koblenz", 5)
	await _select("saarbrucken")
	var combat := _screen.get_node("CombatPrompt") as Control
	var combat_units := combat.find_child("Units", true, false) as SpinBox
	var combat_confirm := combat.find_child("Confirm", true, false) as Button
	combat_units.get_line_edit().text = "2"
	await _press(combat_confirm)
	var random := RandomNumberGenerator.new()
	for seed_value: int in 100:
		random.seed = seed_value
		var rolls: Array[int] = []
		for index: int in 2:
			rolls.append(random.randi_range(1, 6))
		if rolls.max() > random.randi_range(1, 6):
			_application._random_generator.seed = seed_value
			break
	await _press(combat_confirm)
	_expect(
		_state.find_city("saarbrucken").owner_id == "german_empire"
		and _state.find_city("saarbrucken").unit_count == 2
		and _state.find_city("koblenz").unit_count == 1,
		"Defeated cities should be occupied automatically by the committed survivors."
	)
	_set_city("saarbrucken", "allies", 2)
	_refresh()


func _check_stale_transfer() -> void:
	_set_city("koblenz", "german_empire", 3)
	_set_city("luxembourg", "german_empire", 2)
	_set_city("metz", "german_empire", 2)
	_refresh()
	await _choose_action("koblenz", 7)
	await _select("metz")
	_set_city("luxembourg", "", 0)
	await _press(_confirm)
	_expect(
		not _prompt.visible and _state.find_city("koblenz").unit_count == 3
		and _state.find_city("metz").unit_count == 2
		and (_screen.get("_turn_status") as Label).text.contains("roads occupied"),
		"A route invalidated before confirmation should be rejected without mutation."
	)
	_set_city("luxembourg", "german_empire", 2)
	_refresh()
	await _choose_action("koblenz", 7)
	_set_city("luxembourg", "", 0)
	_screen.call("_refresh_game_view")
	_expect(
		not _highlighted("metz"),
		"Refreshing the board should recompute targets after a route is broken."
	)
	_click(_board.get_global_rect().position + Vector2(2, 2), MOUSE_BUTTON_LEFT)
	_expect(not _highlighted("aachen"), "Clicking empty board space should clear targeting.")


func _check_phase_change() -> void:
	_set_city("luxembourg", "german_empire", 2)
	_refresh()
	await _choose_action("koblenz", 7)
	await _select("metz")
	_expect(_prompt.visible, "A pending transfer prompt should be visible.")
	_state.winner_id = "allies"
	_screen.call("_refresh_game_view")
	_expect(
		not _prompt.visible and not _board.get("_navigation_blocked"),
		"Game over should dismiss a pending transfer."
	)
	_state.winner_id = ""
	_refresh()
	await _choose_action("koblenz", 7)
	await _select("metz")
	_expect(_application.end_reorganization_phase().succeeded(), "Ending reorganization should work.")
	_screen.call("_refresh_game_view")
	_expect(
		not _prompt.visible and not _board.get("_navigation_blocked")
		and _state.phase == GameState.Phase.REINFORCEMENT_PLACEMENT
		and _state.active_player_id == "allies"
		and _state.find_city("koblenz").unit_count == 3,
		"A phase change should dismiss a pending transfer without executing it."
	)


func _check_occupation_victory() -> void:
	for city: GameCity in _state.cities:
		if city.owner_id == "allies":
			city.leave_unoccupied()
			city.unit_count = 0
	_set_city("amiens", "german_empire", 3)
	_refresh()
	await _choose_action("amiens", 6)
	await _select("paris")
	await _press(_confirm)
	_expect(
		_state.winner_id == "german_empire"
		and _state.find_city("paris").owner_id == "german_empire"
		and not _prompt.visible and (_screen.get("_game_status") as Label).text.contains("wins"),
		"Occupying the enemy center after elimination should display victory."
	)


func _check_end_phase_button() -> void:
	_expect(_application.end_attack_phase().succeeded(), "Start reorganization.")
	_refresh()
	await _choose_action("koblenz", 7)
	_expect(_highlighted("metz"), "A transfer should be in target-selection mode.")
	(_screen.get("_end_reorganization_button") as Button).emit_signal("pressed")
	_expect(
		not _highlighted("metz") and _state.active_player_id == "allies"
		and _state.phase == GameState.Phase.REINFORCEMENT_PLACEMENT,
		"The end-phase button should clear targeting and advance to the next player."
	)


func _check_development_changes() -> void:
	await _choose_action("koblenz", 6)
	_expect(_highlighted("aachen"), "Dev mode should include regular occupation targeting.")
	await _open_menu("koblenz")
	_expect(_menu.get_item_index(1) >= 0, "Dev mode should retain developer actions.")
	_menu.emit_signal("id_pressed", 1)
	_menu.hide()
	await _root.get_tree().process_frame
	_expect(
		not _highlighted("aachen") and not _prompt.visible
		and (_state.find_city("koblenz") as GameCity).owner_id == "allies",
		"Developer changes that invalidate the source should clear targeting."
	)


func _check_hud_totals(owner_id: String) -> void:
	var city_count := 0
	var unit_count := 0
	for city: GameCity in _state.cities:
		if city.owner_id == owner_id:
			city_count += 1
			unit_count += city.unit_count
	var stats := _screen.get_node("MarginContainer/Content/GameHUD/Content/Germany/Stats") as Label
	_expect(
		stats.text == "Cities: %d  |  Units: %d" % [city_count, unit_count],
		"The HUD should reflect the current city and unit totals."
	)


func _click(position: Vector2, button: MouseButton) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	_root.push_input(motion)
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = button
	event.pressed = true
	_root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	_root.push_input(event)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
