extends SceneTree

const CombatServiceScript = preload("res://scripts/domain/combat_service.gd")
const GameCityScript = preload("res://scripts/domain/city.gd")
const GameMapDefinitionScript = preload("res://scripts/domain/game_map_definition.gd")
const MapCityDefinitionScript = preload("res://scripts/domain/map_city_definition.gd")
const MapConnectionScript = preload("res://scripts/domain/map_connection.gd")
const GamePlayerScript = preload("res://scripts/domain/player.gd")
const GameStateScript = preload("res://scripts/domain/game_state.gd")

var _failures: int = 0


func _initialize() -> void:
	_test_eliminating_forces_after_capturing_the_enemy_center_wins()
	_test_capturing_the_enemy_center_after_elimination_wins()
	_test_final_capture_checks_victory()
	_test_one_unit_without_a_center_cannot_complete_victory()

	if _failures == 0:
		print("Game end condition unit tests passed.")
	quit(1 if _failures > 0 else 0)


func _test_eliminating_forces_after_capturing_the_enemy_center_wins() -> void:
	var state := _create_state("allies", "german_empire", 1)
	_expect(state.winner_id.is_empty(), "Remaining enemy forces should prevent victory.")
	_begin_attack(state)

	var result := state.resolve_attack_round(
		"allies_home",
		"german_last",
		2,
		1,
		_combat_service_where_attacker_wins()
	)
	_expect(result.succeeded(), "The final enemy garrison should be attackable.")
	_expect(result.defender_losses == 1, "The seeded attack should eliminate the last enemy unit.")
	_expect(
		state.winner_id == "allies",
		"Eliminating all enemy forces after capturing their center should win the game."
	)
	_expect(
		not state.end_attack_phase().succeeded(),
		"Game actions must be rejected after a winner is determined."
	)
	_expect(
		not state.validate_attack_source("allies_home").succeeded(),
		"New attacks must be rejected after the game ends."
	)


func _test_capturing_the_enemy_center_after_elimination_wins() -> void:
	var state := _create_state("", "", 0)
	_expect(
		state.winner_id.is_empty(),
		"Eliminating enemy forces without capturing their center must not win."
	)
	_begin_attack(state)

	var result := state.occupy_city("allies_home", "german_cog", 1)
	_expect(result.succeeded(), "The enemy center should be occupiable.")
	_expect(
		state.winner_id == "allies",
		"Capturing the enemy center after eliminating all enemy forces should win."
	)


func _test_final_capture_checks_victory() -> void:
	var state := _create_state("german_empire", "", 0)
	_begin_attack(state)
	var result := state.resolve_attack_round(
		"allies_home", "german_cog", 2, 1, _combat_service_where_attacker_wins()
	)
	_expect(
		result.succeeded() and result.units_advanced == 2
		and state.find_city("allies_home").unit_count == 1
		and state.find_city("german_cog").owner_id == "allies"
		and state.winner_id == "allies",
		"Capturing the last enemy unit in its center should immediately determine victory."
	)


func _test_one_unit_without_a_center_cannot_complete_victory() -> void:
	var state := _create_state("", "", 0)
	var home := state.find_city("allies_home")
	home.leave_unoccupied()
	home.unit_count = 0
	var last_city := state.find_city("german_last")
	last_city.assign_owner("allies")
	last_city.unit_count = 1
	_begin_attack(state)
	_expect(
		state.reinforcements_remaining == 0
		and not state.occupy_city("german_last", "allies_home", 1).succeeded()
		and state.winner_id.is_empty(),
		"A lone unit without its center cannot reinforce or occupy to complete victory."
	)
	_expect(state.end_attack_phase().succeeded(), "The stalled player can still end attacks.")
	_expect(
		state.end_reorganization_phase("german_empire").succeeded()
		and state.reinforcements_remaining == 0,
		"The eliminated opponent can also begin a turn with no reinforcements."
	)
	_expect(state.begin_attack_phase().succeeded(), "The opponent can skip reinforcements.")
	_expect(state.end_attack_phase().succeeded(), "The opponent can end attacks.")
	_expect(
		state.end_reorganization_phase("allies").succeeded()
		and state.reinforcements_remaining == 0 and state.winner_id.is_empty(),
		"Another turn does not resolve the stalled position."
	)


func _create_state(
	enemy_cog_owner_id: String,
	enemy_force_owner_id: String,
	enemy_force_count: int
) -> GameState:
	var allies: GamePlayer = GamePlayerScript.new("allies", "Allies", "allies_home")
	var germans: GamePlayer = GamePlayerScript.new(
		"german_empire",
		"Germany",
		"german_cog"
	)
	var enemy_cog_unit_count := 1 if not enemy_cog_owner_id.is_empty() else 0
	var cities: Array[GameCity] = [
		GameCityScript.new("allies_home", allies.id, 3),
		GameCityScript.new("german_cog", enemy_cog_owner_id, enemy_cog_unit_count),
		GameCityScript.new("german_last", enemy_force_owner_id, enemy_force_count),
	]
	return GameStateScript.new([allies, germans], cities)


func _begin_attack(state: GameState) -> void:
	var map_definition: GameMapDefinition = GameMapDefinitionScript.new(
		[
			MapCityDefinitionScript.new("allies_home", "Allies Home", 0.0, 0.0, true),
			MapCityDefinitionScript.new("german_cog", "German COG", 0.0, 0.0, true),
			MapCityDefinitionScript.new("german_last", "German Last", 0.0, 0.0),
		],
		[
			MapConnectionScript.new("allies_home", "german_cog"),
			MapConnectionScript.new("allies_home", "german_last"),
		]
	)
	var reinforcement_result := state.begin_reinforcement_turn(map_definition, "allies")
	_expect(reinforcement_result.succeeded(), "The game should begin reinforcement placement.")
	var attack_result := state.begin_attack_phase()
	_expect(attack_result.succeeded(), "Zero reinforcements should allow the attack phase.")


func _combat_service(seed_value: int) -> CombatService:
	var random_generator := RandomNumberGenerator.new()
	random_generator.seed = seed_value
	return CombatServiceScript.new(random_generator)


func _combat_service_where_attacker_wins() -> CombatService:
	var winning_seed := -1
	for seed_value: int in 1000:
		var random_generator := RandomNumberGenerator.new()
		random_generator.seed = seed_value
		var service: CombatService = CombatServiceScript.new(random_generator)
		var sample := service.resolve_round(2, 1)
		if sample.defender_losses == 1:
			winning_seed = seed_value
			break
	assert(winning_seed >= 0, "Could not find a combat seed that eliminates the defender.")
	return _combat_service(winning_seed)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
