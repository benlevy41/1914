extends PanelContainer

signal confirm_requested(unit_count: int)
signal cancel_requested

var _board: BoardView
var _target_id: String
var _prompt: Label
var _units: SpinBox
var _warning: Label
var _warn_on_max: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 12)
	add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)
	_prompt = Label.new()
	_prompt.name = "Prompt"
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt.custom_minimum_size.x = 256
	_prompt.size.x = 256
	content.add_child(_prompt)
	_units = SpinBox.new()
	_units.name = "Units"
	_units.min_value = 1
	_units.step = 1
	_units.rounded = true
	_units.suffix = " units"
	content.add_child(_units)
	_warning = Label.new()
	_warning.name = "Warning"
	_warning.text = "Moving all units will leave the source city unoccupied."
	_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warning.custom_minimum_size.x = 256
	_warning.size.x = 256
	content.add_child(_warning)
	_warning.hide()
	_units.value_changed.connect(_on_value_changed)
	_units.get_line_edit().text_changed.connect(_on_text_changed)
	var buttons := HBoxContainer.new()
	content.add_child(buttons)
	var confirm := Button.new()
	confirm.name = "Confirm"
	confirm.text = "Confirm"
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.pressed.connect(_submit)
	buttons.add_child(confirm)
	var cancel := Button.new()
	cancel.name = "Cancel"
	cancel.text = "Cancel"
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(_request_cancel)
	buttons.add_child(cancel)
	hide()


func is_pending() -> bool:
	return visible


func show_for(
	board: BoardView, target_id: String, text: String, maximum: int, warn_on_max: bool = false
) -> void:
	_board = board
	_target_id = target_id
	_prompt.text = text
	_warn_on_max = warn_on_max
	_units.max_value = maximum
	_units.value = 1
	_units.get_line_edit().text = "1"
	_set_warning(1 == maximum)
	custom_minimum_size = Vector2(280, 0)
	size = get_combined_minimum_size()
	_position_near_target()
	show()
	_units.get_line_edit().grab_focus()


func dismiss() -> void:
	hide()


func _input(event: InputEvent) -> void:
	if not is_pending():
		return
	var empty_board_click: bool = (
		event is InputEventMouseButton and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
		and _board.get_global_rect().has_point(event.global_position)
		and not get_global_rect().has_point(event.global_position)
		and _board.get_city_id_at_position(event.global_position).is_empty()
	)
	if event.is_action_pressed("ui_cancel") or empty_board_click:
		get_viewport().set_input_as_handled()
		_request_cancel()


func _process(_delta: float) -> void:
	if is_pending():
		_position_near_target()


func _submit() -> void:
	var warning_was_visible := _warning.visible
	_units.apply()
	if _warn_on_max and _units.value == _units.max_value and not warning_was_visible:
		_set_warning(true)
		return
	confirm_requested.emit(int(_units.value))


func _request_cancel() -> void:
	cancel_requested.emit()


func _on_value_changed(value: float) -> void:
	_set_warning(value == _units.max_value)


func _on_text_changed(text: String) -> void:
	var entered := text.strip_edges()
	_set_warning(entered.is_valid_int() and int(entered) >= int(_units.max_value))


func _set_warning(at_maximum: bool) -> void:
	_warning.visible = _warn_on_max and at_maximum


func _position_near_target() -> void:
	var board_rect := _board.get_global_rect()
	var city_position: Variant = _board.get_city_screen_position(_target_id)
	var anchor: Vector2 = board_rect.get_center() if city_position == null else city_position
	var desired := anchor + Vector2(20, 20)
	desired.x = clampf(desired.x, board_rect.position.x, maxf(
		board_rect.position.x, board_rect.end.x - size.x
	))
	desired.y = clampf(desired.y, board_rect.position.y, maxf(
		board_rect.position.y, board_rect.end.y - size.y
	))
	position = get_parent_control().get_global_transform_with_canvas().affine_inverse() * desired
