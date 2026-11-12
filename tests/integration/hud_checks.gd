extends RefCounted

var _failures: int = 0


func check_banner(screen: Control) -> int:
	var snapshot := screen.get("_game_snapshot") as GameViewSnapshot
	var hud := screen.get_node("MarginContainer/Content/GameHUD") as GameHUD
	var allies_name := hud.get_node("Content/Allies/Name") as Label
	var german_name := hud.get_node("Content/Germany/Name") as Label
	var allies_stats := hud.get_node("Content/Allies/Stats") as Label
	var german_stats := hud.get_node("Content/Germany/Stats") as Label
	var allied_cities := 0
	var allied_units := 0
	var german_cities := 0
	var german_units := 0
	for city: GameViewSnapshot.CityView in snapshot.cities:
		if city.owner_id == "allies":
			allied_cities += 1
			allied_units += city.unit_count
		elif city.owner_id == "german_empire":
			german_cities += 1
			german_units += city.unit_count
	_expect(
		hud.visible
		and allies_name.text == "Allies - %s" % snapshot.find_player("allies").name
		and german_name.text == "German Empire - %s" % snapshot.find_player("german_empire").name
		and allies_stats.text == "Cities: %d  |  Units: %d" % [allied_cities, allied_units]
		and german_stats.text == "Cities: %d  |  Units: %d" % [german_cities, german_units],
		"The HUD should display both names and current city and garrison totals."
	)
	return _failures


func check_normal_game(screen: Control) -> int:
	var application := screen.get("_game_application") as GameApplication
	var state := application._active_game_state as GameState
	var menu := screen.get_node("CityContextMenu") as PopupMenu
	var status := screen.get("_turn_status") as Label
	var hud := screen.get_node("MarginContainer/Content/GameHUD") as GameHUD
	var flag := hud.get_node("Content/Center/Flag") as TextureRect
	var active := hud.get_node("Content/Center/Info/Active") as Label
	var phase := hud.get_node("Content/Center/Info/Phase") as Label
	var allies_stats := hud.get_node("Content/Allies/Stats") as Label
	var german_stats := hud.get_node("Content/Germany/Stats") as Label
	check_banner(screen)
	_expect(
		active.text == "Turn: Moltke"
		and phase.text == "Reinforcement - 3 remaining"
		and flag.texture == GameHUD.GERMAN_FLAG
		and allies_stats.text == "Cities: 16  |  Units: 21"
		and german_stats.text == "Cities: 16  |  Units: 21",
		"The initial HUD should show the German flag, active player and reinforcement count."
	)
	_check_flags()
	screen.call("_on_city_context_requested", "paris", Vector2.ZERO)
	_expect(
		menu.visible and menu.is_item_disabled(menu.get_item_index(4))
		and status.text.contains("owned by the active player"),
		"An enemy city should show a disabled reinforcement and explain why."
	)
	menu.hide()
	_expect(
		status.text.contains("Right-click a city"),
		"Closing an invalid menu should restore the phase guidance."
	)
	var paris := state.find_city("paris")
	var paris_owner := paris.owner_id
	var paris_units := paris.unit_count
	paris.owner_id = ""
	paris.unit_count = 0
	screen.call("_refresh_game_view")
	screen.call("_on_city_context_requested", "paris", Vector2.ZERO)
	_expect(
		menu.is_item_disabled(menu.get_item_index(4)),
		"An unoccupied city must not accept reinforcements."
	)
	menu.hide()
	paris.owner_id = paris_owner
	paris.unit_count = paris_units
	var owners: Dictionary = {}
	for city: GameCity in state.cities:
		owners[city.id] = city.owner_id
		city.owner_id = "allies"
	paris.owner_id = "german_empire"
	state.find_city("koblenz").owner_id = "german_empire"
	screen.call("_refresh_game_view")
	screen.call("_on_city_context_requested", "paris", Vector2.ZERO)
	_expect(
		menu.is_item_disabled(menu.get_item_index(4))
		and status.text.contains("connected to the active player's center of gravity"),
		"An isolated friendly city should show a disabled action and the connectivity reason."
	)
	menu.hide()
	for city: GameCity in state.cities:
		city.owner_id = owners[city.id]
	screen.call("_refresh_game_view")

	screen.call("_on_city_context_requested", "koblenz", Vector2.ZERO)
	_expect(
		menu.visible and not menu.is_item_disabled(menu.get_item_index(4))
		and menu.get_item_index(1) == -1 and menu.get_item_index(2) == -1
		and menu.get_item_index(3) == -1,
		"A normal game should offer legal reinforcement without developer actions."
	)
	var koblenz := state.find_city("koblenz")
	var original_units := koblenz.unit_count
	menu.emit_signal("id_pressed", 2)
	_expect(
		not (screen.get_node("UnitChangeDialog") as ConfirmationDialog).visible,
		"A forged developer action must not open a dialog in a normal game."
	)
	koblenz.owner_id = "allies"
	menu.emit_signal("id_pressed", 4)
	_expect(
		koblenz.unit_count == original_units and state.reinforcements_remaining == 3
		and status.text.contains("owned by the active player"),
		"Placement must revalidate after the menu was opened."
	)
	koblenz.owner_id = "german_empire"
	menu.hide()
	screen.call("_refresh_game_view")
	for index: int in 3:
		screen.call("_on_city_context_requested", "koblenz", Vector2.ZERO)
		menu.emit_signal("id_pressed", 4)
		menu.hide()
	_expect(
		koblenz.unit_count == original_units + 3
		and state.phase == GameState.Phase.ATTACK
		and phase.text == "Attack phase"
		and (screen.get("_attack_source_city_id") as String).is_empty(),
		"Final reinforcement should refresh the HUD and enter attack without staging an attack."
	)
	check_banner(screen)
	state.phase = GameState.Phase.REINFORCEMENT_PLACEMENT
	state.reinforcements_remaining = 0
	screen.call("_refresh_game_view")
	screen.call("_update_phase_status")
	var action := screen.get("_phase_action_button") as Button
	screen.call("_on_city_context_requested", "koblenz", Vector2.ZERO)
	_expect(
		not menu.visible and action.visible and not action.disabled
		and action.text == "Begin attack phase",
		"A zero-reinforcement turn should retain the attack phase advance."
	)
	action.emit_signal("pressed")
	_expect(state.phase == GameState.Phase.ATTACK, "The zero-pool action should begin attacks.")
	state.active_player_id = "allies"
	screen.call("_refresh_game_view")
	_expect(
		flag.texture == GameHUD.ALLIED_FLAG and active.text == "Turn: Joffre",
		"The HUD should switch to the Allied flag when the active player changes."
	)
	return _failures


func check_game_over(screen: Control) -> int:
	var hud := screen.get_node("MarginContainer/Content/GameHUD") as GameHUD
	var flag := hud.get_node("Content/Center/Flag") as TextureRect
	var active := hud.get_node("Content/Center/Info/Active") as Label
	var phase := hud.get_node("Content/Center/Info/Phase") as Label
	var menu := screen.get_node("CityContextMenu") as PopupMenu
	screen.call("_on_city_context_requested", "paris", Vector2.ZERO)
	_expect(
		flag.texture == GameHUD.ALLIED_FLAG and active.text == "Winner: Joffre"
		and phase.text == "Game over" and not menu.visible,
		"Game over should show the winner's flag and suppress context actions."
	)
	return _failures


func _check_flags() -> void:
	var german := GameHUD.GERMAN_FLAG.get_image()
	var allied := GameHUD.ALLIED_FLAG.get_image()
	_expect(
		german.get_pixel(30, 20).is_equal_approx(Color.html("#171717"))
		and german.get_pixel(30, 60).is_equal_approx(Color.WHITE)
		and german.get_pixel(30, 100).is_equal_approx(Color.html("#c4272f")),
		"The German flag should render horizontal black, white and red stripes."
	)
	_expect(
		allied.get_pixel(40, 110).is_equal_approx(Color.html("#002395"))
		and allied.get_pixel(100, 110).is_equal_approx(Color.WHITE)
		and allied.get_pixel(180, 110).is_equal_approx(Color.html("#ed2939"))
		and allied.get_pixel(180, 10).is_equal_approx(Color.html("#012169"))
		and allied.get_pixel(120, 10).is_equal_approx(Color.html("#c8102e")),
		"The Allied flag should render the French lower-left and Union Jack upper-right."
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
