extends SceneTree

const GameCityScript = preload("res://scripts/domain/city.gd")
const GameMapDefinitionScript = preload("res://scripts/domain/game_map_definition.gd")
const MapCityDefinitionScript = preload("res://scripts/domain/map_city_definition.gd")
const MapConnectionScript = preload("res://scripts/domain/map_connection.gd")
const GamePlayerScript = preload("res://scripts/domain/player.gd")
const GameStateScript = preload("res://scripts/domain/game_state.gd")

var _failures: int = 0


func _initialize() -> void:
	_test_reinforcement_thresholds()
	_test_legal_and_rejected_placements()
	_test_cog_capture_and_zero_pool_skip()

	if _failures == 0:
		print("Reinforcement placement unit tests passed.")
	quit(1 if _failures > 0 else 0)


func _test_reinforcement_thresholds() -> void:
	var expected_counts: Dictionary = {
		0: 0,
		4: 0,
		5: 1,
		9: 1,
		10: 2,
	}
	for territory_count: int in expected_counts:
		var state := _create_threshold_state(territory_count)
		var result: GameActionResult = state.begin_reinforcement_turn(
			_create_threshold_map(),
			"allies"
		)
		_expect(result.succeeded(), "A valid map should start the reinforcement phase.")
		_expect(
			state.reinforcements_remaining == expected_counts[territory_count],
			"Reinforcement counts should award one unit for each complete five cities."
		)


func _test_legal_and_rejected_placements() -> void:
	var map_definition := _create_connectivity_map()
	var state := _create_connectivity_state()
	var start_result: GameActionResult = state.begin_reinforcement_turn(map_definition, "allies")
	_expect(start_result.succeeded(), "The reinforcement phase should start with the supplied map.")
	_expect(state.reinforcements_remaining == 1, "Five Allied cities should yield one reinforcement.")

	var isolated_city := state.find_city("allies_isolated")
	var validation_result := state.validate_reinforcement("allies_isolated")
	var isolated_result: GameActionResult = state.place_reinforcement("allies_isolated")
	_expect(
		not validation_result.succeeded()
		and validation_result.error_message == isolated_result.error_message,
		"An owned city behind an enemy-held city is not reachable."
	)
	_expect(
		isolated_city.unit_count == 1,
		"Rejected placement must not change the isolated garrison."
	)
	_expect(
		state.reinforcements_remaining == 1,
		"Rejected placement must not consume a reinforcement."
	)
	_expect(
		state.active_player_id == "allies",
		"Rejected placement must not advance the active player."
	)

	var opponent_city_result: GameActionResult = state.place_reinforcement("german_block")
	_expect(not opponent_city_result.succeeded(), "A player cannot reinforce an opponent-owned city.")
	var unknown_city_result: GameActionResult = state.place_reinforcement("missing_city")
	_expect(not unknown_city_result.succeeded(), "A reinforcement target must exist on the map.")

	var target_city := state.find_city("allies_target")
	var valid_result := state.validate_reinforcement("allies_target")
	_expect(
		valid_result.succeeded()
		and target_city.unit_count == 1
		and state.reinforcements_remaining == 1
		and state.phase == GameState.Phase.REINFORCEMENT_PLACEMENT,
		"Validating a legal placement must not change the game state."
	)
	var placement_result: GameActionResult = state.place_reinforcement("allies_target")
	_expect(placement_result.succeeded(), "A reachable owned city should accept a reinforcement.")
	_expect(target_city.unit_count == 2, "A successful placement should add one unit.")
	_expect(
		state.active_player_id == "allies",
		"Exhausting a reinforcement pool should keep the player active for attacks."
	)
	_expect(
		state.phase == GameState.Phase.ATTACK,
		"Exhausting the reinforcement pool should begin the attack phase."
	)
	var end_attack_result := state.end_attack_phase()
	_expect(end_attack_result.succeeded(), "The active player should be able to end attacks.")
	_expect(
		state.phase == GameState.Phase.REORGANIZATION,
		"Ending the attack phase should begin the reorganization phase."
	)


func _test_cog_capture_and_zero_pool_skip() -> void:
	var state := _create_threshold_state(5)
	var map_definition := _create_threshold_map()
	state.find_city("allies_cog").owner_id = "german_empire"

	var start_result: GameActionResult = state.begin_reinforcement_turn(map_definition, "allies")
	_expect(start_result.succeeded(), "The turn should start when a player's COG is captured.")
	_expect(
		state.reinforcements_remaining == 0,
		"A player whose COG is enemy-held should receive no reinforcements."
	)
	var skip_result: GameActionResult = state.begin_attack_phase()
	_expect(skip_result.succeeded(), "A player with a captured COG should begin the attack phase.")
	_expect(
		state.phase == GameState.Phase.ATTACK,
		"A captured-COG turn should advance to attack with no reinforcements."
	)
	_expect(
		state.active_player_id == "allies",
		"The player with a captured COG should remain active for their attack phase."
	)


func _create_threshold_state(allied_territory_count: int) -> GameState:
	var allies := GamePlayerScript.new("allies", "Allies", "allies_cog")
	var german_empire := GamePlayerScript.new("german_empire", "Germany", "german_cog")
	var cities: Array[GameCity] = []
	for index: int in 11:
		var city_id := "allies_city_%d" % index
		var owner_id := "german_empire"
		if index < allied_territory_count:
			owner_id = "allies"
		if index == 10:
			city_id = "german_cog"
			owner_id = "german_empire"
		cities.append(GameCityScript.new(city_id, owner_id, 1))
	if allied_territory_count == 0:
		cities[0].id = "allies_cog"
		cities[0].leave_unoccupied()
		cities[0].unit_count = 0
		return GameStateScript.new([allies, german_empire], cities)
	cities[0].id = "allies_cog"
	return GameStateScript.new([allies, german_empire], cities)


func _create_threshold_map() -> GameMapDefinition:
	var city_definitions: Array[MapCityDefinition] = []
	var connections: Array[MapConnection] = []
	for index: int in 11:
		var city_id := "allies_city_%d" % index
		var is_center_of_gravity := index == 0 or index == 10
		if index == 0:
			city_id = "allies_cog"
		elif index == 10:
			city_id = "german_cog"
		city_definitions.append(
			MapCityDefinitionScript.new(city_id, city_id, 0.0, 0.0, is_center_of_gravity)
		)
	return GameMapDefinitionScript.new(city_definitions, connections)


func _create_connectivity_state() -> GameState:
	var allies := GamePlayerScript.new("allies", "Allies", "allies_cog")
	var german_empire := GamePlayerScript.new("german_empire", "Germany", "german_cog")
	var cities: Array[GameCity] = [
		GameCityScript.new("allies_cog", allies.id, 1),
		GameCityScript.new("allies_link", allies.id, 1),
		GameCityScript.new("allies_target", allies.id, 1),
		GameCityScript.new("allies_isolated", allies.id, 1),
		GameCityScript.new("allies_extra", allies.id, 1),
		GameCityScript.new("german_cog", german_empire.id, 1),
		GameCityScript.new("german_block", german_empire.id, 1),
	]
	return GameStateScript.new([allies, german_empire], cities)


func _create_connectivity_map() -> GameMapDefinition:
	var city_definitions: Array[MapCityDefinition] = [
		MapCityDefinitionScript.new("allies_cog", "Allied COG", 0.0, 0.0, true),
		MapCityDefinitionScript.new("allies_link", "Allied Link", 0.0, 0.0),
		MapCityDefinitionScript.new("allies_target", "Allied Target", 0.0, 0.0),
		MapCityDefinitionScript.new("allies_isolated", "Allied Isolated", 0.0, 0.0),
		MapCityDefinitionScript.new("allies_extra", "Allied Extra", 0.0, 0.0),
		MapCityDefinitionScript.new("german_cog", "German COG", 0.0, 0.0, true),
		MapCityDefinitionScript.new("german_block", "German Block", 0.0, 0.0),
	]
	var connections: Array[MapConnection] = [
		MapConnectionScript.new("allies_cog", "allies_link"),
		MapConnectionScript.new("allies_link", "allies_target"),
		MapConnectionScript.new("allies_target", "german_block"),
		MapConnectionScript.new("german_block", "allies_isolated"),
	]
	return GameMapDefinitionScript.new(city_definitions, connections)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
