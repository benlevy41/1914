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
	await _check_rounds_and_cancellation()
	await _check_stale_decisions()
	await _check_legacy_capture()
	await _check_allied_attacker()
	await _check_phase_change()
	_screen.free()
	await _start_game()
	await _check_victory()
	_screen.free()
	if OS.is_debug_build():
		await _start_game(true)
		await _check_dev_mode()
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
	_prompt = _screen.get_node("CombatPrompt") as Control
	_units = _prompt.find_child("Units", true, false) as SpinBox
	_confirm = _prompt.find_child("Confirm", true, false) as Button
	_cancel = _prompt.find_child("Cancel", true, false) as Button
	_state = _application._active_game_state
	for index: int in _state.reinforcements_remaining:
		_expect(_application.place_reinforcement("koblenz").succeeded(), "Reach attack phase.")
	_set_city("koblenz", "german_empire", 4)
	_set_city("saarbrucken", "allies", 2)
	_set_city("paris", "allies", 1)
	_refresh()
	await _root.get_tree().process_frame


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


func _open_attack(source: String = "koblenz", target: String = "saarbrucken") -> void:
	_click(_board.get_city_screen_position(source), MOUSE_BUTTON_RIGHT)
	_expect(_menu.visible and _menu.get_item_index(5) >= 0, "The attack menu should open.")
	_menu.emit_signal("id_pressed", 5)
	_menu.hide()
	await _root.get_tree().process_frame
	_click(_board.get_city_screen_position(target), MOUSE_BUTTON_LEFT)
	await _root.get_tree().process_frame


func _press(button: Button) -> void:
	_click(button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	await _root.get_tree().process_frame


func _check_rounds_and_cancellation() -> void:
	await _open_attack()
	var prompt_label := _prompt.find_child("Prompt", true, false) as Label
	_expect(
		_prompt.visible and prompt_label.text.contains("Moltke")
		and _units.min_value == 1 and _units.max_value == 3
		and _board.get("_navigation_blocked"),
		"The attacker prompt should identify the player, constrain units, and block navigation."
	)
	var board_rect := _board.get_global_rect()
	_expect(
		board_rect.encloses(_prompt.get_global_rect()),
		"The combat prompt %s should fit within the board viewport %s."
		% [_prompt.get_global_rect(), board_rect]
	)
	_click(_board.get_city_screen_position("koblenz"), MOUSE_BUTTON_RIGHT)
	_expect(
		not _menu.visible and _screen.get("_attack_target_city_id") == "saarbrucken",
		"Board and context actions should not interrupt a pending combat prompt."
	)
	_root.size = Vector2i(1280, 720)
	await _root.get_tree().process_frame
	await _root.get_tree().process_frame
	_expect(
		_board.get_global_rect().encloses(_prompt.get_global_rect()),
		"The prompt should stay within the board when the window is resized."
	)
	_root.size = Vector2i(1152, 648)
	await _root.get_tree().process_frame
	await _root.get_tree().process_frame
	await _press(_cancel)
	_expect(
		not _prompt.visible and not _board.get("_navigation_blocked")
		and _state.find_city("koblenz").unit_count == 4
		and _state.find_city("saarbrucken").unit_count == 2,
		"Cancelling the attacker prompt must not resolve combat."
	)
	await _open_attack()
	_units.get_line_edit().text = "3"
	await _press(_confirm)
	_expect(
		_prompt.visible and prompt_label.text.contains("Joffre") and _units.max_value == 2,
		"Confirming the attacker should request the defender's commitment."
	)
	await _press(_cancel)
	_expect(
		not _prompt.visible and _state.find_city("koblenz").unit_count == 4
		and _state.find_city("saarbrucken").unit_count == 2,
		"Cancelling the defender prompt must not resolve combat."
	)
	await _open_attack()
	_units.get_line_edit().text = "3"
	await _press(_confirm)
	_units.get_line_edit().text = "2"
	_application._random_generator.seed = 1914
	await _press(_confirm)
	var summary := (_screen.get("_attack_result") as Label).text
	var feedback := _board.get_node("CombatFeedback")
	var attacker := feedback.get_node("AttackerLosses") as Label
	var defender := feedback.get_node("DefenderLosses") as Label
	_expect(
		not _prompt.visible and _state.find_city("koblenz").unit_count == 3
		and _state.find_city("saarbrucken").unit_count == 1
		and summary.contains("[5, 5, 1]") and summary.contains("[5, 3]")
		and summary.contains("attacker 1, defender 1")
		and (_screen.get("_selected_city_label") as Label).text.contains("1 unit"),
		"Both commitments should resolve exactly one seeded round and retain its rolls."
	)
	_expect(
		attacker.visible and defender.visible and attacker.text == "-1" and defender.text == "-1"
		and attacker.get_theme_color("font_color").r > attacker.get_theme_color("font_color").b
		and defender.get_theme_color("font_color").b > defender.get_theme_color("font_color").r,
		"Losses should appear over both cities using their pre-combat owner colors."
	)
	var hud := _screen.get_node("MarginContainer/Content/GameHUD/Content")
	_expect(
		(hud.get_node("Allies/Stats") as Label).text.contains("Units: %d" % _total_units("allies"))
		and (hud.get_node("Germany/Stats") as Label).text.contains(
			"Units: %d" % _total_units("german_empire")
		),
		"The HUD should reflect both sides' losses."
	)
	await _root.get_tree().create_timer(0.1).timeout
	_expect(attacker.visible and defender.visible, "Losses should remain visible briefly.")
	await _root.get_tree().create_timer(3.1).timeout
	_expect(
		not attacker.visible and not defender.visible
		and (_screen.get("_attack_result") as Label).text == summary,
		"Floating losses should expire while the combat summary remains available."
	)
	await _open_attack()
	var units_rect := _units.get_global_rect()
	_click(Vector2(units_rect.end.x - 8, units_rect.position.y + 8), MOUSE_BUTTON_LEFT)
	await _root.get_tree().process_frame
	_expect(_units.value == 2, "The unit selector's increment arrow should change the commitment.")
	await _press(_confirm)
	_seed_attacker_loss(2)
	await _press(_confirm)
	_expect(
		_state.find_city("koblenz").unit_count == 2
		and _state.find_city("saarbrucken").unit_count == 1,
		"The attacker should be able to initiate another round."
	)
	await _open_attack()
	await _press(_confirm)
	_seed_attacker_loss(1)
	await _press(_confirm)
	_expect(
		_state.find_city("koblenz").unit_count == 1
		and _state.find_city("koblenz").owner_id == "german_empire"
		and _state.find_city("saarbrucken").unit_count == 1,
		"Losing committed attackers should leave the source occupied: %s vs %s."
		% [_state.find_city("koblenz").unit_count, _state.find_city("saarbrucken").unit_count]
	)
	_set_city("koblenz", "german_empire", 3)
	_set_city("saarbrucken", "allies", 1)
	_set_city("strasbourg", "allies", 1)
	_refresh()
	await _open_attack()
	_units.get_line_edit().text = "2"
	await _press(_confirm)
	_seed_attacker_win()
	await _press(_confirm)
	_expect(
		_state.find_city("saarbrucken").owner_id == "german_empire"
		and _state.find_city("saarbrucken").unit_count == 2
		and _state.find_city("koblenz").unit_count == 1
		and (_screen.get("_attack_action_button") as Button).disabled
		and (_screen.find_child("LastCombatResult", true, false) as Label).text.contains(
			"Saarbrucken captured; 2 units advanced."
		),
		"Defeating the defender should capture automatically and report the transfer."
	)
	await _open_attack("saarbrucken", "strasbourg")
	_expect(
		_prompt.visible and _units.max_value == 1,
		"Captured units may launch a further attack while leaving one unit behind."
	)
	await _press(_cancel)


func _check_stale_decisions() -> void:
	_set_city("koblenz", "german_empire", 3)
	_set_city("saarbrucken", "allies", 2)
	_refresh()
	await _open_attack()
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	_root.push_input(escape)
	_expect(
		not _prompt.visible and _state.find_city("koblenz").unit_count == 3,
		"Escape should cancel a pending decision without combat."
	)
	await _open_attack()
	_click(_board.get_global_rect().position + Vector2(2, 2), MOUSE_BUTTON_LEFT)
	_expect(
		not _prompt.visible and _state.find_city("saarbrucken").unit_count == 2,
		"Clicking empty board space should cancel the pending decision without combat."
	)
	await _open_attack()
	_set_city("koblenz", "allies", 3)
	await _press(_confirm)
	_expect(
		not _prompt.visible
		and (_screen.get("_turn_status") as Label).text.contains("owned by the active player")
		and _state.find_city("saarbrucken").unit_count == 2,
		"A stale attacker decision should be rejected without combat."
	)
	_set_city("koblenz", "german_empire", 3)
	_refresh()
	await _open_attack()
	await _press(_confirm)
	_units.get_line_edit().text = "2"
	_set_city("saarbrucken", "allies", 1)
	await _press(_confirm)
	_expect(
		not _prompt.visible
		and (_screen.get("_turn_status") as Label).text.contains("defending unit")
		and _state.find_city("koblenz").unit_count == 3
		and _state.find_city("saarbrucken").unit_count == 1,
		"A stale defender commitment should be rejected without combat."
	)
	_set_city("saarbrucken", "allies", 2)
	_refresh()
	await _open_attack()
	_units.get_line_edit().text = "2"
	await _press(_confirm)
	_set_city("koblenz", "german_empire", 2)
	await _press(_confirm)
	_expect(
		not _prompt.visible and _state.find_city("koblenz").unit_count == 2
		and _state.find_city("saarbrucken").unit_count == 2
		and (_screen.get("_turn_status") as Label).text.contains("leave one"),
		"A stale attacker commitment must be rejected before combat can abandon the source."
	)


func _check_legacy_capture() -> void:
	_set_city("koblenz", "german_empire", 3)
	_set_city("saarbrucken", "allies", 1)
	_refresh()
	_click(_board.get_city_screen_position("koblenz"), MOUSE_BUTTON_LEFT)
	_click(_board.get_city_screen_position("saarbrucken"), MOUSE_BUTTON_LEFT)
	var attack_button := _screen.get("_attack_action_button") as Button
	var commitment := _screen.get("_attacker_commitment") as SpinBox
	_expect(
		not attack_button.disabled and commitment.max_value == 2,
		"The legacy attack selector should also leave one unit behind."
	)
	commitment.value = 2
	attack_button.emit_signal("pressed")
	_seed_attacker_win()
	attack_button.emit_signal("pressed")
	_expect(
		_state.find_city("koblenz").unit_count == 1
		and _state.find_city("saarbrucken").unit_count == 2
		and _state.find_city("saarbrucken").owner_id == "german_empire"
		and attack_button.disabled,
		"The legacy combat path should capture automatically and clear the old attack."
	)


func _check_allied_attacker() -> void:
	_state.active_player_id = "allies"
	_set_city("saarbrucken", "allies", 4)
	_set_city("koblenz", "german_empire", 2)
	_refresh()
	await _open_attack("saarbrucken", "koblenz")
	_units.get_line_edit().text = "3"
	await _press(_confirm)
	_units.get_line_edit().text = "2"
	_application._random_generator.seed = 1914
	await _press(_confirm)
	var feedback := _board.get_node("CombatFeedback")
	var attacker := feedback.get_node("AttackerLosses") as Label
	var defender := feedback.get_node("DefenderLosses") as Label
	_expect(
		attacker.get_theme_color("font_color").b > attacker.get_theme_color("font_color").r
		and defender.get_theme_color("font_color").r > defender.get_theme_color("font_color").b,
		"Loss colors should follow ownership when the Allies attack."
	)


func _check_phase_change() -> void:
	await _open_attack("saarbrucken", "koblenz")
	_state.winner_id = "allies"
	_screen.call("_refresh_game_view")
	_expect(
		not _prompt.visible and not _board.get("_navigation_blocked"),
		"Game over should dismiss a pending decision."
	)
	_state.winner_id = ""
	_refresh()
	await _open_attack("saarbrucken", "koblenz")
	_expect(_prompt.visible, "The prompt should open before the phase change.")
	_expect(_application.end_attack_phase().succeeded(), "The attack phase should end.")
	_screen.call("_refresh_game_view")
	_expect(
		not _prompt.visible and not _board.get("_navigation_blocked")
		and _state.phase == GameState.Phase.REORGANIZATION
		and (_screen.find_child("LastCombatResult", true, false) as Label).is_visible_in_tree(),
		"A phase change should dismiss pending combat without rolling."
	)


func _check_victory() -> void:
	for city: GameCity in _state.cities:
		if city.owner_id == "allies":
			city.leave_unoccupied()
	_set_city("paris", "german_empire", 1)
	_set_city("koblenz", "german_empire", 3)
	_set_city("saarbrucken", "allies", 1)
	_refresh()
	await _open_attack()
	_units.get_line_edit().text = "2"
	await _press(_confirm)
	_seed_attacker_win()
	await _press(_confirm)
	_expect(
		_state.winner_id == "german_empire"
		and _state.find_city("saarbrucken").owner_id == "german_empire"
		and (_screen.find_child("LastCombatResult", true, false) as Label).is_visible_in_tree()
		and (_screen.find_child("LastCombatResult", true, false) as Label).text.contains(
			"Attacker rolls"
		)
		and not _prompt.visible,
		"Victory should preserve the last combat result and show the captured city."
	)


func _check_dev_mode() -> void:
	await _open_attack()
	_expect(
		(_screen.get("_game_snapshot") as GameViewSnapshot).dev_mode_active
		and _menu.get_item_index(1) >= 0 and _prompt.visible,
		"Developer mode should extend the same contextual combat flow."
	)
	await _press(_confirm)
	_seed_attacker_win()
	await _press(_confirm)
	_expect(
		not _prompt.visible and not (_screen.get("_attack_result") as Label).text.is_empty(),
		"Developer mode should resolve combat through the regular workflow."
	)


func _seed_attacker_win() -> void:
	var random := RandomNumberGenerator.new()
	for seed_value: int in 100:
		random.seed = seed_value
		var rolls: Array[int] = []
		for index: int in 2:
			rolls.append(random.randi_range(1, 6))
		if rolls.max() > random.randi_range(1, 6):
			_application._random_generator.seed = seed_value
			return
	_expect(false, "A seeded attacker win should be available.")


func _seed_attacker_loss(commitment: int) -> void:
	var random := RandomNumberGenerator.new()
	for seed_value: int in 100:
		random.seed = seed_value
		var rolls: Array[int] = []
		for index: int in commitment:
			rolls.append(random.randi_range(1, 6))
		if rolls.max() <= random.randi_range(1, 6):
			_application._random_generator.seed = seed_value
			return
	_expect(false, "A seeded attacker loss should be available.")


func _total_units(owner_id: String) -> int:
	var total := 0
	for city: GameCity in _state.cities:
		if city.owner_id == owner_id:
			total += city.unit_count
	return total


func _click(position: Vector2, button: MouseButton) -> void:
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
