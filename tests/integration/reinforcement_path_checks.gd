extends RefCounted

const MainScene = preload("res://scenes/main.tscn")

var _failures: int = 0


func run(root: Window) -> int:
	var original_size := root.size
	root.size = Vector2i(1152, 648)
	var screen := MainScene.instantiate() as Control
	root.add_child(screen)
	await root.get_tree().process_frame
	await root.get_tree().process_frame
	var quick_start := screen.get_node("MarginContainer/Content/MenuPanel/QuickStart") as Button
	_click(root, quick_start.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	await root.get_tree().process_frame
	var board := screen.get_node("MarginContainer/Content/MainLayout/Board") as BoardView
	var menu := screen.get_node("CityContextMenu") as PopupMenu
	var snapshot := screen.get("_game_snapshot") as GameViewSnapshot
	if snapshot == null:
		_expect(false, "Clicking quick start should initialize a game.")
		screen.free()
		root.size = original_size
		return _failures
	var initial_units := snapshot.find_city("koblenz").unit_count
	var initial_remaining := snapshot.reinforcements_remaining
	var selected_label := screen.get("_selected_city_label") as Label
	var hud := screen.get_node("MarginContainer/Content/GameHUD") as GameHUD
	var stats := hud.get_node("Content/Germany/Stats") as Label
	var phase := hud.get_node("Content/Center/Info/Phase") as Label
	var city_position := _city_screen_position(board, "koblenz")
	_click(root, city_position, MOUSE_BUTTON_LEFT)
	var marker := _city_visual(board).get_node("Selection") as MeshInstance3D
	_expect(
		board.get_selected_city_id() == "koblenz" and marker.visible,
		"Clicking Koblenz should select it and show its marker."
	)
	_expect(initial_remaining == 3, "Quick start should provide three reinforcements.")
	for placed: int in initial_remaining:
		_click(root, city_position, MOUSE_BUTTON_RIGHT)
		await root.get_tree().process_frame
		if not menu.visible:
			_expect(false, "Right-clicking Koblenz should open the reinforcement menu.")
			break
		var item_index := menu.get_item_index(4)
		if item_index < 0 or menu.is_item_disabled(item_index):
			_expect(false, "Koblenz should offer an enabled reinforcement action.")
			break
		_expect(
			menu.get_item_index(1) == -1 and menu.get_item_index(2) == -1
			and menu.get_item_index(3) == -1,
			"A normal game's reinforcement menu must not contain developer actions."
		)
		_click(root, Vector2(menu.position) + Vector2(menu.size) / 2.0, MOUSE_BUTTON_LEFT)
		await root.get_tree().process_frame
		snapshot = screen.get("_game_snapshot") as GameViewSnapshot
		var expected_units := initial_units + placed + 1
		var city_visual := _city_visual(board)
		marker = city_visual.get_node("Selection") as MeshInstance3D
		_expect(
			not menu.visible
			and snapshot.find_city("koblenz").unit_count == expected_units
			and _unit_count(city_visual) == expected_units
			and marker.visible and board.get_selected_city_id() == "koblenz"
			and selected_label.text == "Koblenz - Moltke, %d units" % expected_units
			and stats.text == "Cities: 16  |  Units: %d" % (22 + placed)
			and snapshot.reinforcements_remaining == initial_remaining - placed - 1,
			"Clicking the action should update the selected city, board, HUD and pool."
		)
		if placed < initial_remaining - 1:
			_expect(
				phase.text == "Reinforcement - %d remaining" % (initial_remaining - placed - 1),
				"The HUD should show the remaining reinforcements."
			)
		else:
			_expect(
				snapshot.phase == GameViewSnapshot.Phase.ATTACK
				and phase.text == "Attack phase"
				and (screen.get("_attack_source_city_id") as String).is_empty(),
				"The last placement should begin attack without staging an attack."
			)
	screen.free()
	root.size = original_size
	return _failures


func _city_visual(board: BoardView) -> Node3D:
	return board.get_node(
		"ViewportContainer/SubViewport/Board3D/MapContent/City_koblenz"
	) as Node3D


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


func _unit_count(city_visual: Node3D) -> int:
	var count := 0
	for child: Node in city_visual.get_children():
		if child.name.begins_with("Unit_"):
			count += 1
	return count


func _click(root: Window, position: Vector2, button: MouseButton) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion)
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = button
	event.pressed = true
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
