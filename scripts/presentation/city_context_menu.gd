extends PopupMenu

const CHANGE_CITY_OWNER := 1
const ADD_UNITS := 2
const REMOVE_UNITS := 3
const PLACE_REINFORCEMENT := 4
const ATTACK := 5
const OCCUPY := 6
const MOVE_UNITS := 7
const PLACE_INITIAL_RESERVE := 8

var _retarget: Callable


func configure_retarget(retarget: Callable) -> void:
	_retarget = retarget
	window_input.connect(_on_window_input)


func _on_window_input(event: InputEvent) -> void:
	if (
		not (event is InputEventMouseButton)
		or event.button_index != MOUSE_BUTTON_RIGHT
		or not event.pressed
		or Rect2(Vector2.ZERO, Vector2(size)).has_point(event.position)
	):
		return
	var screen_position: Vector2 = event.position + Vector2(position)
	if not is_embedded():
		screen_position -= Vector2(get_parent().get_window().position)
	if _retarget.call(screen_position):
		set_input_as_handled()


func popup_near(screen_position: Vector2) -> void:
	var popup_position := screen_position
	var parent := get_parent()
	if not parent.get_viewport().gui_embed_subwindows:
		popup_position += Vector2(parent.get_window().position)
	popup(Rect2i(Vector2i(popup_position), Vector2i.ZERO))


func add_placement_item(
	city: GameViewSnapshot.CityView, application: GameApplication, initial: bool
) -> String:
	var validation := (
		application.validate_initial_reserve(city.id) if initial
		else application.validate_reinforcement(city.id)
	)
	var item_id := PLACE_INITIAL_RESERVE if initial else PLACE_REINFORCEMENT
	add_item("Place reserve unit" if initial else "Place reinforcement", item_id)
	var index := get_item_index(item_id)
	set_item_disabled(index, not validation.succeeded())
	set_item_tooltip(index, validation.error_message)
	if not validation.succeeded():
		return validation.error_message
	return "Place one %s in %s." % ["reserve" if initial else "reinforcement", city.name]


func add_attack_item(
	city: GameViewSnapshot.CityView,
	validation: GameActionResult,
	has_targets: bool,
	awaiting_defender: bool
) -> String:
	var error_message := validation.error_message
	if awaiting_defender:
		error_message = "Finish or cancel the pending defender decision first."
	elif validation.succeeded() and not has_targets:
		error_message = "No adjacent enemy city can be attacked from %s." % city.name
	add_item("Attack", ATTACK)
	set_item_disabled(get_item_index(ATTACK), not error_message.is_empty())
	set_item_tooltip(get_item_index(ATTACK), error_message)
	return error_message


func add_transfer_item(item_id: int, error_message: String) -> void:
	add_item("Occupy" if item_id == OCCUPY else "Move units", item_id)
	var index := get_item_index(item_id)
	set_item_disabled(index, not error_message.is_empty())
	set_item_tooltip(index, error_message)


func add_development_items(city: GameViewSnapshot.CityView, snapshot: GameViewSnapshot) -> void:
	add_item("Change owner", CHANGE_CITY_OWNER)
	add_item("Add units", ADD_UNITS)
	add_item("Remove units", REMOVE_UNITS)
	set_item_disabled(
		get_item_index(CHANGE_CITY_OWNER), city.owner_id.is_empty() or city.unit_count <= 0
	)
	var add_owner_name := city.owner_name if not city.owner_id.is_empty() else city.last_owner_name
	var add_unavailable := (
		add_owner_name.is_empty()
		or city.unit_count >= snapshot.max_development_garrison_size
		or (not city.owner_id.is_empty() and city.unit_count <= 0)
	)
	set_item_disabled(get_item_index(ADD_UNITS), add_unavailable)
	var remove_unavailable := city.owner_id.is_empty() or city.unit_count <= 0
	set_item_disabled(get_item_index(REMOVE_UNITS), remove_unavailable)
