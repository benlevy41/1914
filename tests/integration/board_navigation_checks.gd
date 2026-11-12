extends RefCounted

var _failures: int = 0
var _root: Window


func check_clearing(screen: Control, board: BoardView, stage: String) -> int:
	_root = board.get_tree().root
	var application := screen.get("_game_application") as GameApplication
	var state := application._active_game_state as GameState
	var source := state.find_city("koblenz")
	var other := state.find_city("luxembourg" if stage == "reorganization" else "saarbrucken")
	var source_units := source.unit_count
	var other_units := other.unit_count
	var attack_result := (screen.get("_attack_result") as Label).text
	var container := board.get_node("ViewportContainer") as SubViewportContainer
	_send_mouse(container.get_global_rect().position + Vector2(2, 2), MOUSE_BUTTON_LEFT)
	_expect(
		(screen.get("_selected_city_id") as String).is_empty()
		and (screen.get("_selected_city_label") as Label).text == "Select a city on the board.",
		"An empty click should clear the screen's city selection."
	)
	match stage:
		"reserve":
			_expect(
				(screen.get("_phase_action_button") as Button).disabled,
				"Deselection should disable reserve placement."
			)
		"attack":
			_expect(
				(screen.get("_attack_source_city_id") as String).is_empty()
				and (screen.get("_attack_target_city_id") as String).is_empty()
				and not screen.get("_awaiting_defender_commitment")
				and (screen.get("_attack_action_button") as Button).disabled
				and not (screen.get("_defender_prompt") as Label).visible,
				"Deselection should cancel an unresolved attack and defender commitment."
			)
		"reorganization":
			_expect(
				(screen.get("_reorganization_source_city_id") as String).is_empty()
				and (screen.get("_reorganization_target_city_id") as String).is_empty()
				and (screen.get("_move_units_button") as Button).disabled
				and (screen.get("_attack_result") as Label).text == attack_result,
				"Deselection should cancel a staged transfer but retain completed combat results."
			)
	_expect(
		source.unit_count == source_units and other.unit_count == other_units,
		"Clearing pending choices must not change any garrisons."
	)
	return _failures


func run_overview(board: BoardView) -> int:
	_root = board.get_tree().root
	var container := board.get_node("ViewportContainer") as SubViewportContainer
	var viewport := container.get_node("SubViewport") as SubViewport
	var camera := viewport.get_node("Board3D/Camera3D") as Camera3D
	var paris := viewport.get_node("Board3D/MapContent/City_paris") as Node3D
	var original_target: Vector3 = board.get("_camera_target")
	var original_distance: float = board.get("_camera_distance")
	var original_pitch := camera.rotation.x
	var original_window_size := _root.size
	board.clear_selection()
	_send_mouse(_city_screen_position(container, viewport, camera, paris), MOUSE_BUTTON_LEFT)
	board.call("_set_camera_target", Vector3(12, 0, -8))
	var center := container.get_global_rect().get_center()
	for step: int in 20:
		_send_mouse(center, MOUSE_BUTTON_WHEEL_DOWN)
	await board.get_tree().create_timer(0.35).timeout
	_expect(
		is_equal_approx(camera.rotation.x, -PI / 2.0)
		and (board.get("_camera_target") as Vector3).is_equal_approx(Vector3.ZERO)
		and board.get_selected_city_id() == "paris",
		"Maximum zoom should center the top-down view without clearing the selected city."
		+ " (pitch=%s, target=%s, selected=%s)" % [
			camera.rotation.x, board.get("_camera_target"), board.get_selected_city_id()
		]
	)
	_check_board_fits(viewport, camera)
	_send_mouse(_city_screen_position(container, viewport, camera, paris), MOUSE_BUTTON_LEFT)
	_expect(board.get_selected_city_id() == "paris", "Cities should be selectable in overview.")

	_root.size = Vector2i(1100, 2200)
	for frame: int in 5:
		await board.get_tree().process_frame
	await board.get_tree().create_timer(0.35).timeout
	_expect(
		float(viewport.size.x) / float(viewport.size.y) < 0.5 and camera.position.y > 40.0,
		"A narrow strategic viewport should increase camera height to fit the board."
	)
	_check_board_fits(viewport, camera)
	_root.size = original_window_size
	for frame: int in 5:
		await board.get_tree().process_frame
	await board.get_tree().create_timer(0.35).timeout
	_check_board_fits(viewport, camera)

	var city_ground := Vector3(paris.global_position.x, 0, paris.global_position.z)
	var selected_screen_position := camera.unproject_position(city_ground)
	center = container.get_global_rect().get_center()
	_send_mouse(center, MOUSE_BUTTON_WHEEL_UP)
	await board.get_tree().create_timer(0.35).timeout
	_expect(
		is_equal_approx(camera.rotation.x, original_pitch)
		and camera.unproject_position(city_ground).distance_to(selected_screen_position) < 0.2,
		"Exiting overview should restore the angled view and zoom toward the selected city."
	)

	_send_mouse(center, MOUSE_BUTTON_WHEEL_DOWN)
	await board.get_tree().create_timer(0.35).timeout
	board.clear_selection()
	var viewport_center := Vector2(viewport.size) / 2.0
	var ground: Vector3 = Plane(Vector3.UP, 0.0).intersects_ray(
		camera.project_ray_origin(viewport_center), camera.project_ray_normal(viewport_center)
	)
	_send_mouse(center, MOUSE_BUTTON_WHEEL_UP)
	await board.get_tree().create_timer(0.35).timeout
	_expect(
		is_equal_approx(camera.rotation.x, original_pitch)
		and camera.unproject_position(ground).distance_to(viewport_center) < 0.2,
		"With no selection, exiting overview should zoom toward the cursor."
	)

	_send_mouse(center, MOUSE_BUTTON_WHEEL_DOWN)
	await board.get_tree().create_timer(0.35).timeout
	_send_middle_button(center, true)
	_send_mouse_motion(center, center + Vector2(70, 30), true)
	_send_middle_button(center + Vector2(70, 30), false)
	_expect(
		not (board.get("_camera_target") as Vector3).is_equal_approx(Vector3.ZERO)
		and is_equal_approx(camera.rotation.x, -PI / 2.0),
		"Middle-button panning should work in the strategic view."
	)
	_send_mouse(center, MOUSE_BUTTON_WHEEL_DOWN)
	_send_mouse(center, MOUSE_BUTTON_WHEEL_UP)
	await board.get_tree().create_timer(0.35).timeout
	_expect(
		is_equal_approx(camera.rotation.x, original_pitch) and not board.get("_overview_active"),
		"Rapidly reversing an overview transition should return to the angled view."
	)
	_send_mouse(center, MOUSE_BUTTON_WHEEL_DOWN)
	var transition_pitch := camera.rotation.x
	_send_mouse(center, MOUSE_BUTTON_WHEEL_DOWN)
	_expect(
		is_equal_approx(camera.rotation.x, transition_pitch),
		"Repeated zoom-out events must not snap an in-progress overview transition."
	)
	_send_mouse(center, MOUSE_BUTTON_WHEEL_UP)
	_expect(
		is_equal_approx(camera.rotation.x, transition_pitch),
		"Reversing an in-progress transition should start from the current camera angle."
	)
	await board.get_tree().create_timer(0.35).timeout
	_expect(
		is_equal_approx(camera.rotation.x, original_pitch),
		"A reversed transition should finish at the original camera angle."
	)
	board.set("_camera_distance", original_distance)
	board.call("_set_camera_target", original_target)
	return _failures


func check_dev_overview(screen: Control, board: BoardView) -> int:
	_root = board.get_tree().root
	var container := board.get_node("ViewportContainer") as SubViewportContainer
	var viewport := container.get_node("SubViewport") as SubViewport
	var camera := viewport.get_node("Board3D/Camera3D") as Camera3D
	var paris := viewport.get_node("Board3D/MapContent/City_paris") as Node3D
	var koblenz := viewport.get_node("Board3D/MapContent/City_koblenz") as Node3D
	var menu := screen.get_node("CityContextMenu") as PopupMenu
	var target: Vector3 = board.get("_camera_target")
	var distance: float = board.get("_camera_distance")
	var center := container.get_global_rect().get_center()
	for step: int in 20:
		_send_mouse(center, MOUSE_BUTTON_WHEEL_DOWN)
	await board.get_tree().create_timer(0.35).timeout
	_send_mouse(_city_screen_position(container, viewport, camera, paris), MOUSE_BUTTON_RIGHT)
	await board.get_tree().process_frame
	_expect(
		menu.visible and screen.get("_context_city_id") == "paris",
		"Right-clicking a city should open the developer menu in strategic view."
	)
	_send_mouse(_city_screen_position(container, viewport, camera, koblenz), MOUSE_BUTTON_RIGHT)
	_expect(
		menu.visible and screen.get("_context_city_id") == "koblenz",
		"Right-clicking another city should retarget the menu in strategic view."
	)
	menu.hide()
	_send_mouse(center, MOUSE_BUTTON_WHEEL_UP)
	await board.get_tree().create_timer(0.35).timeout
	board.set("_camera_distance", distance)
	board.call("_set_camera_target", target)
	return _failures


func _check_board_fits(viewport: SubViewport, camera: Camera3D) -> void:
	var bounds := Rect2(Vector2.ZERO, Vector2(viewport.size))
	var all_visible := true
	for x: float in [-12.0, 12.0]:
		for z: float in [-8.0, 8.0]:
			all_visible = all_visible and bounds.has_point(
				camera.unproject_position(Vector3(x, 0, z))
			)
	_expect(all_visible, "The centered strategic view should show all four board corners.")


func _city_screen_position(
	container: SubViewportContainer, viewport: SubViewport, camera: Camera3D, city: Node3D
) -> Vector2:
	var position := camera.unproject_position(city.global_position + Vector3(0, 0.13, 0))
	return (
		container.get_global_transform_with_canvas()
		* (position * container.size / Vector2(viewport.size))
	)


func run(board: BoardView, paris_screen_position: Vector2) -> int:
	_root = board.get_tree().root
	var container := board.get_node("ViewportContainer") as SubViewportContainer
	var camera := board.get_node("ViewportContainer/SubViewport/Board3D/Camera3D") as Camera3D
	var viewport := container.get_node("SubViewport") as SubViewport
	var paris := viewport.get_node("Board3D/MapContent/City_paris") as Node3D
	var original_target: Vector3 = board.get("_camera_target")
	var original_distance: float = board.get("_camera_distance")
	var center := container.get_global_rect().get_center()
	var cursor := center + Vector2(100, 0)
	var local_cursor := container.get_global_transform_with_canvas().affine_inverse() * cursor
	var viewport_cursor := local_cursor * Vector2(viewport.size) / container.size
	var ground: Vector3 = Plane(Vector3.UP, 0.0).intersects_ray(
		camera.project_ray_origin(viewport_cursor), camera.project_ray_normal(viewport_cursor)
	)
	_send_mouse(cursor, MOUSE_BUTTON_WHEEL_UP)
	var zoom_target: Vector3 = board.get("_camera_target")
	_expect(
		camera.unproject_position(ground).distance_to(viewport_cursor) < 0.1
		and zoom_target.distance_to(original_target) > 0.1,
		"With no selection, zoom should keep the ground beneath the cursor stationary."
	)
	_send_mouse(cursor, MOUSE_BUTTON_WHEEL_DOWN)
	zoom_target = board.get("_camera_target")
	_expect(
		zoom_target.distance_to(original_target) < 0.01,
		"Zooming back out around the cursor should reverse the zoom-in movement."
	)

	_send_mouse(paris_screen_position, MOUSE_BUTTON_LEFT)
	board.set("_camera_distance", 8.0)
	board.call("_set_camera_target", Vector3(12, 0, -8))
	var target_before: Vector3 = board.get("_camera_target")
	var city_ground := Vector3(paris.position.x, 0, paris.position.z)
	_expect(
		camera.is_position_behind(city_ground)
		or not Rect2(Vector2.ZERO, Vector2(viewport.size)).has_point(
			camera.unproject_position(city_ground)
		),
		"The selected-city zoom test should start with the city off-screen."
	)
	_send_mouse(center, MOUSE_BUTTON_WHEEL_UP)
	var target_after: Vector3 = board.get("_camera_target")
	_expect(
		board.get_selected_city_id() == "paris"
		and target_after.distance_to(target_before.lerp(city_ground, 0.15)) < 0.01,
		"Zoom should prioritize the selected city even when it is off-screen."
	)
	_send_mouse(center, MOUSE_BUTTON_WHEEL_DOWN)
	target_after = board.get("_camera_target")
	_expect(
		target_after.distance_to(target_before) < 0.01,
		"Zooming back out should reverse the selected-city zoom."
	)

	board.clear_selection()
	board.set("_camera_distance", original_distance)
	board.call("_set_camera_target", original_target)
	var local_center := container.get_global_transform_with_canvas().affine_inverse() * center
	var viewport_center := local_center * Vector2(viewport.size) / container.size
	var drag_ground: Vector3 = Plane(Vector3.UP, 0.0).intersects_ray(
		camera.project_ray_origin(viewport_center), camera.project_ray_normal(viewport_center)
	)
	var drag_end := center + Vector2(80, 40)
	_send_middle_button(center, true)
	_send_mouse_motion(center, drag_end, true)
	var expected_position := (
		viewport_center + Vector2(80, 40) * Vector2(viewport.size) / container.size
	)
	_expect(
		camera.unproject_position(drag_ground).distance_to(expected_position) < 0.1,
		"Middle-button dragging should move the anchored map point with the cursor."
	)
	_send_middle_button(drag_end, false)
	var released_target: Vector3 = board.get("_camera_target")
	_send_mouse_motion(drag_end, drag_end + Vector2(50, 0), false)
	_expect(
		(board.get("_camera_target") as Vector3).is_equal_approx(released_target),
		"Releasing the middle button should stop dragging."
	)
	_send_middle_button(center, true)
	board.set_navigation_blocked(true)
	board.set_navigation_blocked(false)
	_send_mouse_motion(center, center + Vector2(50, 0), true)
	_send_middle_button(center + Vector2(50, 0), false)
	_expect(
		(board.get("_camera_target") as Vector3).is_equal_approx(released_target),
		"Opening a menu or dialog during a drag should cancel it."
	)
	_send_middle_button(center, true)
	_send_mouse_motion(center, center + Vector2(10, 0), false)
	_send_mouse_motion(center, center + Vector2(50, 0), true)
	_send_middle_button(center + Vector2(50, 0), false)
	_expect(
		(board.get("_camera_target") as Vector3).is_equal_approx(released_target),
		"A mouse motion without the middle button should cancel a missed release."
	)
	_send_middle_button(center, true)
	_root.focus_exited.emit()
	_send_mouse_motion(center, center + Vector2(50, 0), true)
	_send_middle_button(center + Vector2(50, 0), false)
	_expect(
		(board.get("_camera_target") as Vector3).is_equal_approx(released_target),
		"Losing window focus during a drag should cancel it."
	)
	var text_input := LineEdit.new()
	board.add_child(text_input)
	text_input.grab_focus()
	_send_middle_button(center, true)
	_send_mouse_motion(center, center + Vector2(50, 0), true)
	_send_middle_button(center + Vector2(50, 0), false)
	_expect(
		(board.get("_camera_target") as Vector3).is_equal_approx(released_target),
		"Dragging should not pan the board while typing in a text field."
	)
	text_input.free()

	board.set("_camera_distance", original_distance)
	board.call("_set_camera_target", original_target)
	_send_middle_button(center, true)
	_send_mouse_motion(center, center + Vector2(10000, 0), true)
	_send_middle_button(center + Vector2(10000, 0), false)
	var bounded_target: Vector3 = board.get("_camera_target")
	_expect(
		is_equal_approx(bounded_target.x, -12.0),
		"Dragging should stop at the existing board pan boundary."
	)
	_send_mouse(cursor, MOUSE_BUTTON_WHEEL_DOWN)
	bounded_target = board.get("_camera_target")
	_expect(
		bounded_target.x >= -12.0 and bounded_target.x <= 12.0
		and bounded_target.z >= -8.0 and bounded_target.z <= 8.0,
		"Targeted zoom should also respect the existing pan boundaries."
	)
	board.set("_camera_distance", original_distance)
	board.call("_set_camera_target", original_target)
	return _failures


func _send_mouse(position: Vector2, button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = button
	event.pressed = true
	_root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	_root.push_input(event)


func _send_middle_button(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_MIDDLE
	event.button_mask = MOUSE_BUTTON_MASK_MIDDLE if pressed else 0
	event.pressed = pressed
	_root.push_input(event)


func _send_mouse_motion(from: Vector2, to: Vector2, middle_pressed: bool) -> void:
	var event := InputEventMouseMotion.new()
	event.position = to
	event.global_position = to
	event.relative = to - from
	event.button_mask = MOUSE_BUTTON_MASK_MIDDLE if middle_pressed else 0
	_root.push_input(event)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
