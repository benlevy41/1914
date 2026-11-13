extends RefCounted

const MainScene = preload("res://scenes/main.tscn")

var _failures: int = 0
var _root: Window
var _screen: Control
var _board: BoardView
var _menu: PopupMenu
var _application: GameApplication
var _state: GameState


func run(root: Window) -> int:
	_root = root
	var original_size := root.size
	root.size = Vector2i(1152, 648)
	await _start_game(false)
	await _check_normal_game()
	_screen.free()
	if OS.is_debug_build():
		await _start_game(true)
		_check_development_changes()
		_screen.free()
	root.size = original_size
	return _failures


func _start_game(dev_mode: bool) -> void:
	_screen = MainScene.instantiate() as Control
	_root.add_child(_screen)
	await _root.get_tree().process_frame
	_application = _screen.get("_game_application") as GameApplication
	var start_button := "DevMode" if dev_mode else "QuickStart"
	_screen.get_node("MarginContainer/Content/MenuPanel/%s" % start_button).emit_signal("pressed")
	await _root.get_tree().process_frame
	_board = _screen.get_node("MarginContainer/Content/MainLayout/Board") as BoardView
	_menu = _screen.get_node("CityContextMenu") as PopupMenu
	_state = _application._active_game_state
	for index: int in _state.reinforcements_remaining:
		_expect(_application.place_reinforcement("koblenz").succeeded(), "Setup should reach attack.")
	_set_city("koblenz", "german_empire", 3)
	_set_city("luxembourg", "german_empire", 2)
	_set_city("aachen", "", 0)
	_set_city("saarbrucken", "allies", 2)
	_set_city("strasbourg", "allies", 1)
	_set_city("paris", "allies", 1)
	for city_id: String in ["liege", "metz", "verdun"]:
		_set_city(city_id, "german_empire", 1)
	_screen.call("_refresh_game_view")
	_screen.call("_update_phase_status")
	await _root.get_tree().process_frame


func _set_city(city_id: String, owner_id: String, units: int) -> void:
	var city := _state.find_city(city_id)
	if owner_id.is_empty():
		city.leave_unoccupied()
	else:
		city.assign_owner(owner_id)
	city.unit_count = units


func _check_normal_game() -> void:
	_open_menu("paris")
	_expect(
		_menu.visible and _menu.is_item_disabled(_menu.get_item_index(5))
		and (_screen.get("_turn_status") as Label).text.contains("owned by the active player"),
		"An enemy source should offer a disabled attack with an explanation."
	)
	_menu.hide()
	await _root.get_tree().process_frame
	_open_menu("aachen")
	_expect(
		_menu.is_item_disabled(_menu.get_item_index(5)),
		"An unoccupied source should not be allowed to attack."
	)
	_menu.hide()
	await _root.get_tree().process_frame
	_open_menu("liege")
	_expect(
		_menu.is_item_disabled(_menu.get_item_index(5))
		and (_screen.get("_turn_status") as Label).text.contains("at least two units"),
		"A one-unit source must not be allowed to attack."
	)
	_menu.hide()
	await _root.get_tree().process_frame
	_open_menu("luxembourg")
	_expect(
		_menu.is_item_disabled(_menu.get_item_index(5))
		and (_screen.get("_turn_status") as Label).text.contains("No adjacent enemy"),
		"A source with no legal enemy targets should explain why attack is disabled."
	)
	_menu.hide()
	await _root.get_tree().process_frame
	_open_menu("koblenz")
	await _root.get_tree().process_frame
	_expect(
		_menu.visible and not _menu.is_item_disabled(_menu.get_item_index(5))
		and _menu.get_item_index(1) == -1 and _menu.get_item_index(2) == -1
		and _menu.get_item_index(3) == -1,
		"A legal source should offer attack without developer actions."
	)
	if not _menu.visible or _menu.get_item_index(5) < 0:
		return
	_click(Vector2(_menu.position) + Vector2(_menu.size.x / 2.0, 10.0), MOUSE_BUTTON_LEFT)
	await _root.get_tree().process_frame
	_expect(
		not _menu.visible and _screen.get("_contextual_attack_targeting")
		and _board.get_selected_city_id() == "koblenz"
		and _highlighted("saarbrucken") and _highlighted("strasbourg")
		and not _highlighted("aachen") and not _highlighted("luxembourg")
		and not _highlighted("paris"),
		"Choosing attack with the mouse should highlight only adjacent occupied enemies."
	)
	var before_units := _state.find_city("koblenz").unit_count
	_click(_city_position("paris"), MOUSE_BUTTON_LEFT)
	_expect(
		_screen.get("_contextual_attack_targeting")
		and (_screen.get("_attack_target_city_id") as String).is_empty()
		and _board.get_selected_city_id() == "koblenz"
		and (_screen.get("_turn_status") as Label).text.contains("directly connected")
		and _state.find_city("koblenz").unit_count == before_units,
		"An invalid target should keep the source and explain the rejection without mutation."
	)
	_set_city("saarbrucken", "german_empire", 2)
	_click(_city_position("saarbrucken"), MOUSE_BUTTON_LEFT)
	_expect(
		_screen.get("_contextual_attack_targeting")
		and (_screen.get("_attack_target_city_id") as String).is_empty()
		and (_screen.get("_turn_status") as Label).text.contains("already controlled"),
		"Target selection should revalidate a stale highlight against current game state."
	)
	_set_city("saarbrucken", "allies", 2)
	_set_city("metz", "allies", 1)
	_screen.call("_refresh_game_view")
	_open_menu("luxembourg")
	_menu.emit_signal("id_pressed", 5)
	_menu.hide()
	_expect(
		_screen.get("_attack_source_city_id") == "luxembourg"
		and _highlighted("metz") and not _highlighted("saarbrucken"),
		"Choosing another source should replace the highlighted target set."
	)
	var container := _board.get_node("ViewportContainer") as SubViewportContainer
	_click(container.get_global_rect().position + Vector2(2, 2), MOUSE_BUTTON_LEFT)
	_expect(
		not _screen.get("_contextual_attack_targeting") and not _highlighted("metz")
		and (_screen.get("_attack_source_city_id") as String).is_empty(),
		"Clicking empty board space should clear targeting and its highlights."
	)
	_open_menu("koblenz")
	_menu.emit_signal("id_pressed", 5)
	_menu.hide()
	_click(_city_position("saarbrucken"), MOUSE_BUTTON_LEFT)
	var attack_button := _screen.get("_attack_action_button") as Button
	var combat_prompt := _screen.get_node("CombatPrompt") as Control
	_expect(
		_screen.get("_attack_target_city_id") == "saarbrucken"
		and not _screen.get("_contextual_attack_targeting")
		and not _highlighted("saarbrucken") and combat_prompt.visible and attack_button.disabled,
		"Clicking a legal target should open the contextual combat prompt."
	)
	(combat_prompt.find_child("Cancel", true, false) as Button).emit_signal("pressed")
	_click(_city_position("koblenz"), MOUSE_BUTTON_LEFT)
	_click(_city_position("saarbrucken"), MOUSE_BUTTON_LEFT)
	attack_button.emit_signal("pressed")
	_open_menu("koblenz")
	_expect(
		_menu.is_item_disabled(_menu.get_item_index(5))
		and _menu.is_item_disabled(_menu.get_item_index(6))
		and (_screen.get("_turn_status") as Label).text.contains("pending defender"),
		"A new attack or occupation should not replace a pending defender decision."
	)
	_menu.hide()
	_click(container.get_global_rect().position + Vector2(2, 2), MOUSE_BUTTON_LEFT)
	_open_menu("koblenz")
	_set_city("koblenz", "allies", 3)
	_menu.emit_signal("id_pressed", 5)
	_expect(
		not _screen.get("_contextual_attack_targeting")
		and (_screen.get("_turn_status") as Label).text.contains("owned by the active player"),
		"The action should revalidate its source after the menu was opened."
	)
	_menu.hide()
	_set_city("koblenz", "german_empire", 3)
	_screen.call("_refresh_game_view")
	_open_menu("koblenz")
	_menu.emit_signal("id_pressed", 5)
	_menu.hide()
	(_screen.get("_end_attack_button") as Button).emit_signal("pressed")
	_expect(
		_state.phase == GameState.Phase.REORGANIZATION
		and not _screen.get("_contextual_attack_targeting")
		and not _highlighted("saarbrucken"),
		"Ending the attack phase should clear contextual targeting."
	)
	_open_menu("koblenz")
	_expect(
		_menu.visible and _menu.get_item_index(5) == -1 and _menu.get_item_index(7) >= 0,
		"Reorganization should offer movement but not attack."
	)
	_menu.hide()


func _check_development_changes() -> void:
	_open_menu("koblenz")
	_expect(
		_menu.get_item_index(5) >= 0 and _menu.get_item_index(1) >= 0
		and _menu.get_item_index(2) >= 0 and _menu.get_item_index(3) >= 0,
		"Dev mode should extend the attack menu with its separate developer actions."
	)
	_menu.emit_signal("id_pressed", 5)
	_menu.hide()
	_open_menu("saarbrucken")
	_menu.emit_signal("id_pressed", 1)
	_menu.hide()
	_expect(
		_screen.get("_contextual_attack_targeting")
		and not _highlighted("saarbrucken") and _highlighted("strasbourg"),
		"Developer ownership changes should refresh the remaining legal target highlights."
	)
	_open_menu("strasbourg")
	_menu.emit_signal("id_pressed", 1)
	_menu.hide()
	_expect(
		not _screen.get("_contextual_attack_targeting")
		and (_screen.get("_attack_source_city_id") as String).is_empty()
		and not _highlighted("strasbourg"),
		"Removing the last legal target should cancel contextual targeting."
	)
	_set_city("saarbrucken", "allies", 2)
	_screen.call("_refresh_game_view")
	_open_menu("koblenz")
	_menu.emit_signal("id_pressed", 5)
	_menu.hide()
	_open_menu("koblenz")
	_menu.emit_signal("id_pressed", 1)
	_menu.hide()
	_expect(
		not _screen.get("_contextual_attack_targeting")
		and (_screen.get("_attack_source_city_id") as String).is_empty()
		and not _highlighted("saarbrucken"),
		"Changing the source owner should cancel targeting and clear highlights."
	)
	_open_menu("koblenz")
	_menu.emit_signal("id_pressed", 1)
	_menu.hide()
	_open_menu("koblenz")
	_menu.emit_signal("id_pressed", 5)
	_menu.hide()
	_state.winner_id = "allies"
	_screen.call("_refresh_game_view")
	_expect(
		not _screen.get("_contextual_attack_targeting")
		and not _highlighted("saarbrucken") and not _menu.visible,
		"Game over should clear targeting and close the context menu."
	)


func _open_menu(city_id: String) -> void:
	_click(_city_position(city_id), MOUSE_BUTTON_RIGHT)


func _highlighted(city_id: String) -> bool:
	var visual := _board.get_node(
		"ViewportContainer/SubViewport/Board3D/MapContent/City_%s/ActionTarget" % city_id
	) as MeshInstance3D
	return visual.visible


func _city_position(city_id: String) -> Vector2:
	var container := _board.get_node("ViewportContainer") as SubViewportContainer
	var viewport := container.get_node("SubViewport") as SubViewport
	var camera := viewport.get_node("Board3D/Camera3D") as Camera3D
	var city := viewport.get_node("Board3D/MapContent/City_%s" % city_id) as Node3D
	var position := camera.unproject_position(city.global_position + Vector3(0, 0.13, 0))
	return (
		container.get_global_transform_with_canvas()
		* (position * container.size / Vector2(viewport.size))
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
