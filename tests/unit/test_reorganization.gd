extends SceneTree

const GameCityScript = preload("res://scripts/domain/city.gd")
const GameMapDefinitionScript = preload("res://scripts/domain/game_map_definition.gd")
const MapCityDefinitionScript = preload("res://scripts/domain/map_city_definition.gd")
const MapConnectionScript = preload("res://scripts/domain/map_connection.gd")
const GamePlayerScript = preload("res://scripts/domain/player.gd")
const GameStateScript = preload("res://scripts/domain/game_state.gd")

var _failures: int = 0
var _map_definition: GameMapDefinition


func _initialize() -> void:
	_test_multiple_transfers_and_abandonment()
	_test_isolated_routes_and_blocked_routes()
	_test_rejected_moves_preserve_state()
	_test_reorganization_advances_to_the_next_player()
	_test_captured_center_of_gravity_gets_no_reinforcements()

	if _failures == 0:
		print("Reorganization unit tests passed.")
	quit(1 if _failures > 0 else 0)


func _test_multiple_transfers_and_abandonment() -> void:
	var state := _create_state()
	_start_reorganization(state)

	var first_move := state.move_reorganization_units("allies_cog", "allies_dest", 2)
	_expect(first_move.succeeded(), "Units should move along a multi-road friendly route.")
	_expect(state.find_city("allies_cog").unit_count == 1, "The source should lose moved units.")
	_expect(state.find_city("allies_dest").unit_count == 4, "The destination should gain moved units.")

	var second_move := state.move_reorganization_units("allies_link", "allies_side_dest", 1)
	_expect(second_move.succeeded(), "A second transfer should be allowed in the same phase.")
	_expect(
		state.find_city("allies_link").unit_count == 0,
		"A player may move the entire source garrison."
	)
	_expect(
		state.find_city("allies_link").owner_id.is_empty(),
		"An abandoned source city should become unoccupied."
	)
	_expect(
		not state.validate_reorganization_move("allies_cog", "allies_dest", 1).succeeded(),
		"An abandoned city must no longer be traversable."
	)


func _test_isolated_routes_and_blocked_routes() -> void:
	var state := _create_state()
	_start_reorganization(state)

	var isolated_move := state.validate_reorganization_move(
		"allies_isolated_a",
		"allies_isolated_b",
		1
	)
	_expect(
		isolated_move.succeeded(),
		"Reorganization routes need not connect to the player's center of gravity."
	)
	_expect(
		not state.validate_reorganization_move("allies_cog", "allies_isolated_b", 1).succeeded(),
		"Enemy-held cities cannot be traversed during reorganization."
	)
	_expect(
		not state.validate_reorganization_move("allies_mid", "allies_far", 1).succeeded(),
		"Unoccupied cities cannot be traversed during reorganization."
	)


func _test_rejected_moves_preserve_state() -> void:
	var state := _create_state()
	_start_reorganization(state)
	var source_units: int = state.find_city("allies_cog").unit_count
	var target_units: int = state.find_city("allies_dest").unit_count

	_expect(
		not state.move_reorganization_units("allies_cog", "allies_dest", 0).succeeded(),
		"A transfer must move at least one unit."
	)
	_expect(
		not state.move_reorganization_units("allies_cog", "allies_dest", source_units + 1).succeeded(),
		"A transfer cannot move more units than the source contains."
	)
	_expect(
		not state.move_reorganization_units("german_cog", "allies_dest", 1).succeeded(),
		"A player cannot move units from an opponent's city."
	)
	_expect(
		not state.move_reorganization_units("allies_cog", "german_cog", 1).succeeded(),
		"A transfer destination must belong to the active player."
	)
	_expect(
		not state.move_reorganization_units("allies_cog", "allies_cog", 1).succeeded(),
		"A city cannot be both the source and destination."
	)
	_expect(
		state.find_city("allies_cog").unit_count == source_units,
		"Rejected transfers must preserve source units."
	)
	_expect(
		state.find_city("allies_dest").unit_count == target_units,
		"Rejected transfers must preserve destination units."
	)


func _test_reorganization_advances_to_the_next_player() -> void:
	var state := _create_state()
	_start_reorganization(state)

	_expect(
		not state.end_reorganization_phase("allies").succeeded(),
		"The active player cannot take another turn immediately."
	)
	_expect(
		not state.end_reorganization_phase("unknown_player").succeeded(),
		"The next player must belong to the game."
	)
	_expect(
		state.phase == GameState.Phase.REORGANIZATION,
		"Rejected turn advancement must leave reorganization active."
	)

	var end_result := state.end_reorganization_phase("german_empire")
	_expect(end_result.succeeded(), "Reorganization should advance to the next player's turn.")
	_expect(
		state.phase == GameState.Phase.REINFORCEMENT_PLACEMENT,
		"The next player's turn should begin in reinforcement placement."
	)
	_expect(
		state.active_player_id == "german_empire",
		"The next player should become active."
	)
	_expect(
		state.reinforcements_remaining == 1,
		"The next player's reinforcements should be calculated from current territory."
	)


func _test_captured_center_of_gravity_gets_no_reinforcements() -> void:
	var state := _create_state()
	_start_reorganization(state)
	state.find_city("german_cog").owner_id = "allies"

	var end_result := state.end_reorganization_phase("german_empire")
	_expect(end_result.succeeded(), "A player with a captured COG should still begin its turn.")
	_expect(
		state.reinforcements_remaining == 0,
		"A player whose COG is captured should receive no reinforcements."
	)
	var attack_result := state.begin_attack_phase()
	_expect(attack_result.succeeded(), "A zero-reinforcement turn should proceed to attacks.")


func _create_state() -> GameState:
	var allies := GamePlayerScript.new("allies", "Allies", "allies_cog")
	var germans := GamePlayerScript.new("german_empire", "Germany", "german_cog")
	var cities: Array[GameCity] = [
		GameCityScript.new("allies_cog", allies.id, 3),
		GameCityScript.new("allies_link", allies.id, 1),
		GameCityScript.new("allies_mid", allies.id, 1),
		GameCityScript.new("allies_dest", allies.id, 1),
		GameCityScript.new("allies_side", allies.id, 1),
		GameCityScript.new("allies_side_dest", allies.id, 1),
		GameCityScript.new("allies_isolated_a", allies.id, 2),
		GameCityScript.new("allies_isolated_b", allies.id, 1),
		GameCityScript.new("allies_gap", "", 0),
		GameCityScript.new("allies_far", allies.id, 1),
		GameCityScript.new("german_cog", germans.id, 1),
		GameCityScript.new("german_block", germans.id, 1),
		GameCityScript.new("german_extra_a", germans.id, 1),
		GameCityScript.new("german_extra_b", germans.id, 1),
		GameCityScript.new("german_extra_c", germans.id, 1),
	]
	_map_definition = _create_map()
	return GameStateScript.new([allies, germans], cities)


func _create_map() -> GameMapDefinition:
	var city_ids: Array[String] = [
		"allies_cog",
		"allies_link",
		"allies_mid",
		"allies_dest",
		"allies_side",
		"allies_side_dest",
		"allies_isolated_a",
		"allies_isolated_b",
		"allies_gap",
		"allies_far",
		"german_cog",
		"german_block",
		"german_extra_a",
		"german_extra_b",
		"german_extra_c",
	]
	var map_cities: Array[MapCityDefinition] = []
	for city_id: String in city_ids:
		map_cities.append(
			MapCityDefinitionScript.new(
				city_id,
				city_id,
				Vector2.ZERO,
				city_id == "allies_cog" or city_id == "german_cog"
			)
		)
	var connections: Array[MapConnection] = [
		MapConnectionScript.new("allies_cog", "allies_link"),
		MapConnectionScript.new("allies_link", "allies_mid"),
		MapConnectionScript.new("allies_mid", "allies_dest"),
		MapConnectionScript.new("allies_mid", "allies_side"),
		MapConnectionScript.new("allies_side", "allies_side_dest"),
		MapConnectionScript.new("allies_mid", "german_block"),
		MapConnectionScript.new("german_block", "allies_isolated_a"),
		MapConnectionScript.new("allies_isolated_a", "allies_isolated_b"),
		MapConnectionScript.new("allies_mid", "allies_gap"),
		MapConnectionScript.new("allies_gap", "allies_far"),
	]
	return GameMapDefinitionScript.new(map_cities, connections)


func _start_reorganization(state: GameState) -> void:
	var result := state.begin_reinforcement_turn(_map_definition, "allies")
	_expect(result.succeeded(), "The fixture should begin the Allied reinforcement phase.")
	while state.phase == GameState.Phase.REINFORCEMENT_PLACEMENT:
		if state.reinforcements_remaining == 0:
			result = state.begin_attack_phase()
		else:
			result = state.place_reinforcement("allies_dest")
		_expect(result.succeeded(), "The fixture should advance through its current phase.")
	result = state.end_attack_phase()
	_expect(result.succeeded(), "The fixture should enter reorganization.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
