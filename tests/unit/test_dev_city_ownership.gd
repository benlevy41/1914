extends SceneTree

const GamePlayerScript = preload("res://scripts/domain/player.gd")
const GameCityScript = preload("res://scripts/domain/city.gd")
const GameStateScript = preload("res://scripts/domain/game_state.gd")

var _failures: int = 0


func _initialize() -> void:
	_test_owner_changes_and_preserves_units()
	_test_invalid_owner_changes_do_not_mutate_state()
	_test_development_unit_changes()
	_test_invalid_unit_changes_do_not_mutate_state()

	if _failures == 0:
		print("Developer city ownership unit tests passed.")
	quit(1 if _failures > 0 else 0)


func _test_owner_changes_and_preserves_units() -> void:
	var state := _create_state()
	var city := state.find_city("paris")
	var original_unit_count := city.unit_count

	var result := state.change_city_owner_for_development(city.id)
	_expect(result.succeeded(), "A player-owned city should change to the other player.")
	_expect(
		city.owner_id == "german_empire",
		"Ownership should change to the other player."
	)
	_expect(
		city.last_owner_id == "german_empire",
		"Changing ownership should update the remembered owner."
	)
	_expect(
		city.unit_count == original_unit_count,
		"Changing ownership must preserve the city's garrison."
	)


func _test_invalid_owner_changes_do_not_mutate_state() -> void:
	var state := _create_state()
	var unoccupied_city := GameCityScript.new("empty", "", 0)
	state.cities.append(unoccupied_city)

	var missing_result := state.change_city_owner_for_development("missing")
	_expect(not missing_result.succeeded(), "Unknown cities must be rejected.")

	var unoccupied_result := state.change_city_owner_for_development("empty")
	_expect(not unoccupied_result.succeeded(), "Unoccupied cities must be rejected.")
	_expect(
		unoccupied_city.owner_id.is_empty() and unoccupied_city.unit_count == 0,
		"Rejected ownership changes must leave unoccupied cities unchanged."
	)

	var invalid_owner_city := GameCityScript.new("invalid_owner", "unknown", 2)
	state.cities.append(invalid_owner_city)
	var invalid_owner_result := state.change_city_owner_for_development("invalid_owner")
	_expect(not invalid_owner_result.succeeded(), "Unknown owners must be rejected.")
	_expect(
		invalid_owner_city.owner_id == "unknown" and invalid_owner_city.unit_count == 2,
		"Rejected ownership changes must preserve invalid city state."
	)

	state.players.pop_back()
	var player_count_result := state.change_city_owner_for_development("paris")
	_expect(
		not player_count_result.succeeded(),
		"Ownership changes must require exactly two players."
	)
	_expect(
		state.find_city("paris").owner_id == "allies",
		"Rejected ownership changes must preserve the existing owner."
	)


func _test_development_unit_changes() -> void:
	var state := _create_state()
	var city := state.find_city("paris")

	var add_result := state.add_units_for_development(city.id, 3)
	_expect(add_result.succeeded(), "Developer mode should add a positive unit count.")
	_expect(city.unit_count == 7, "Adding units should increase the garrison by the amount.")
	_expect(city.owner_id == "allies", "Adding units should preserve city ownership.")

	var remove_result := state.remove_units_for_development(city.id, 2)
	_expect(remove_result.succeeded(), "Developer mode should remove a valid unit count.")
	_expect(city.unit_count == 5, "Removing units should decrease the garrison by the amount.")
	_expect(city.owner_id == "allies", "Removing some units should preserve ownership.")

	var remove_all_result := state.remove_units_for_development(city.id, city.unit_count)
	_expect(remove_all_result.succeeded(), "Developer mode should remove the entire garrison.")
	_expect(city.unit_count == 0, "Removing the entire garrison should leave zero units.")
	_expect(city.owner_id.is_empty(), "Removing the final unit should leave the city unoccupied.")
	_expect(
		city.last_owner_id == "allies",
		"Leaving a city unoccupied should preserve its last owner."
	)

	var reoccupy_result := state.add_units_for_development(city.id, 2)
	_expect(reoccupy_result.succeeded(), "A remembered owner should allow reoccupation.")
	_expect(
		city.owner_id == "allies" and city.unit_count == 2,
		"Adding units to an unoccupied city should restore its previous owner."
	)

	var change_after_reoccupation := state.change_city_owner_for_development(city.id)
	_expect(change_after_reoccupation.succeeded(), "The restored city should change owners.")
	_expect(
		city.owner_id == "german_empire" and city.last_owner_id == "german_empire",
		"Changing ownership after reoccupation should replace the remembered owner."
	)

	var limit_city := GameCityScript.new(
		"limit",
		"allies",
		GameState.MAX_DEV_GARRISON_SIZE - 1
	)
	state.cities.append(limit_city)
	var limit_result := state.add_units_for_development(limit_city.id, 1)
	_expect(limit_result.succeeded(), "The maximum supported garrison should be reachable.")
	_expect(
		limit_city.unit_count == GameState.MAX_DEV_GARRISON_SIZE,
		"Adding units should allow exactly the supported maximum garrison."
	)


func _test_invalid_unit_changes_do_not_mutate_state() -> void:
	var state := _create_state()
	var city := state.find_city("paris")
	var original_count := city.unit_count

	var zero_add_result := state.add_units_for_development(city.id, 0)
	_expect(not zero_add_result.succeeded(), "Adding zero units must be rejected.")
	var negative_add_result := state.add_units_for_development(city.id, -1)
	_expect(not negative_add_result.succeeded(), "Adding a negative amount must be rejected.")
	var over_limit_result := state.add_units_for_development(
		city.id,
		GameState.MAX_DEV_GARRISON_SIZE
	)
	_expect(not over_limit_result.succeeded(), "Adding above the safe garrison limit must fail.")

	var zero_remove_result := state.remove_units_for_development(city.id, 0)
	_expect(not zero_remove_result.succeeded(), "Removing zero units must be rejected.")
	var over_remove_result := state.remove_units_for_development(city.id, original_count + 1)
	_expect(not over_remove_result.succeeded(), "Removing more than the garrison must fail.")
	_expect(
		city.unit_count == original_count and city.owner_id == "allies",
		"Rejected unit changes must preserve garrison size and ownership."
	)

	var unoccupied_city := GameCityScript.new("empty", "", 0)
	state.cities.append(unoccupied_city)
	_expect(
		not state.add_units_for_development("empty", 1).succeeded(),
		"Adding units to a never-owned city must be rejected."
	)
	_expect(
		not state.remove_units_for_development("empty", 1).succeeded(),
		"Removing units from an unoccupied city must be rejected."
	)
	_expect(
		unoccupied_city.owner_id.is_empty() and unoccupied_city.unit_count == 0,
		"Rejected changes must preserve an unoccupied city."
	)


func _create_state() -> GameState:
	var allies: GamePlayer = GamePlayerScript.new("allies", "Joffre", "paris")
	var german_empire: GamePlayer = GamePlayerScript.new(
		"german_empire",
		"Moltke",
		"koblenz"
	)
	var cities: Array[GameCity] = [
		GameCityScript.new("paris", allies.id, 4),
	]
	var players: Array[GamePlayer] = [allies, german_empire]
	return GameStateScript.new(players, cities)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
