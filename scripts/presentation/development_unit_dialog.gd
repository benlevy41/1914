extends ConfirmationDialog

var unit_selector: SpinBox


func _ready() -> void:
	name = "UnitChangeDialog"
	title = "Developer unit change"
	get_ok_button().text = "OK"
	get_cancel_button().text = "Cancel"
	unit_selector = SpinBox.new()
	unit_selector.name = "UnitCount"
	unit_selector.min_value = 1
	unit_selector.step = 1
	unit_selector.rounded = true
	unit_selector.editable = true
	unit_selector.focus_mode = Control.FOCUS_ALL
	unit_selector.select_all_on_focus = true
	unit_selector.suffix = " units"
	add_child(unit_selector)
	hide()


func open_for(
	city: GameViewSnapshot.CityView, snapshot: GameViewSnapshot, adding: bool
) -> String:
	if not adding and (city.owner_id.is_empty() or city.unit_count <= 0):
		return "Developer unit changes require an occupied city."
	var owner_name := city.owner_name if not city.owner_id.is_empty() else city.last_owner_name
	if owner_name.is_empty():
		return "The city owner is not in this game."
	if adding:
		dialog_text = "Add units to %s:" % city.name
		if city.owner_id.is_empty():
			dialog_text += " Reoccupies for %s." % owner_name
		unit_selector.max_value = snapshot.max_development_garrison_size - city.unit_count
		if unit_selector.max_value < 1:
			return "The city's garrison is already at the supported limit."
	else:
		dialog_text = "Remove units from %s:" % city.name
		unit_selector.max_value = city.unit_count
	unit_selector.value = 1
	popup_centered(Vector2i(360, 160))
	unit_selector.grab_focus()
	return ""


func action_message(city: GameViewSnapshot.CityView, unit_count: int, adding: bool) -> String:
	var action := (
		"Added %d units to %s." % [unit_count, city.name]
		if adding else "Removed %d units from %s." % [unit_count, city.name]
	)
	if city.unit_count == 0:
		action += " The city is now unoccupied."
	return action


func apply_change(application: GameApplication, city_id: String, adding: bool) -> GameActionResult:
	var unit_count := int(unit_selector.value)
	if adding:
		return application.add_units_for_development(city_id, unit_count)
	return application.remove_units_for_development(city_id, unit_count)
