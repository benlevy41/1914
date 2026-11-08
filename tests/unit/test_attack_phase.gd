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
	_test_attack_validation()
	_test_resolving_and_occupying()
	_test_attacker_elimination()
	_test_unoccupied_city_occupation()

	if _failures == 0:
		print("Attack phase unit tests passed.")
	quit(1 if _failures > 0 else 0)


func _test_attack_validation() -> void:
	var state := _create_state()
	_expect(
		not state.validate_attack_source("allies_home").succeeded(),
		"Attack origins cannot be selected outside the attack phase."
	)
	_begin_attack(state)

	_expect(
		state.validate_attack_source("allies_home").succeeded(),
		"The active player should be able to select an owned city with units as an origin."
	)
	_expect(
		not state.validate_attack_source("german_home").succeeded(),
		"An enemy-controlled city must not be selectable as an attack origin."
	)
	_expect(
		not state.validate_attack_target("allies_target").succeeded(),
		"A city controlled by the active player must not be selectable as an attack target."
	)
	_expect(
		state.validate_attack_target("german_target").succeeded(),
		"An enemy-controlled city should be selectable as an attack target."
	)
	_expect(
		not state.validate_attack_target("unknown_city").succeeded(),
		"An unknown city must not be selectable as an attack target."
	)
	state.find_city("allies_home").unit_count = 0
	_expect(
		not state.validate_attack_source("allies_home").succeeded(),
		"A city without units must not be selectable as an attack origin."
	)
	state.find_city("allies_home").unit_count = 3
	_expect(
		not state.validate_attack("allies_home", "german_home", 1).succeeded(),
		"An attack must target a city connected by a direct road."
	)
	_expect(
		not state.validate_attack("german_target", "allies_home", 1).succeeded(),
		"Only the active player's cities may attack."
	)
	_expect(
		not state.validate_attack("allies_home", "allies_target", 1).succeeded(),
		"A player cannot attack their own city."
	)
	_expect(
		not state.validate_attack("allies_home", "german_target", 0).succeeded(),
		"An attack must commit at least one attacker."
	)
	_expect(
		not state.validate_attack("allies_home", "german_target", 4).succeeded(),
		"An attack cannot commit more units than its source garrison."
	)
	_expect(
		not state.resolve_attack_round("allies_home", "german_target", 1, 0, _service()).succeeded(),
		"The defender must commit at least one unit."
	)
	_expect(
		not state.resolve_attack_round("allies_home", "german_target", 1, 2, _service()).succeeded(),
		"The defender cannot commit more units than its garrison."
	)
	_expect(
		state.find_city("allies_home").unit_count == 3,
		"Rejected attacks must not change the attacking garrison."
	)
	_expect(
		state.find_city("german_target").unit_count == 1,
		"Rejected attacks must not change the defending garrison."
	)


func _test_resolving_and_occupying() -> void:
	var state := _create_state()
	_begin_attack(state)
	var result: CombatRoundResult = state.resolve_attack_round(
		"allies_home",
		"german_target",
		2,
		1,
		_service(0)
	)
	_expect(result.succeeded(), "A legal combat round should resolve.")
	_expect(
		state.find_city("allies_home").unit_count == 3 - result.attacker_losses,
		"Attacker casualties should be applied to the source garrison."
	)
	_expect(
		state.find_city("german_target").unit_count == 1 - result.defender_losses,
		"Defender casualties should be applied to the target garrison."
	)
	_expect(
		state.find_city("german_target").owner_id.is_empty(),
		"A defeated city should become unoccupied until the attacker moves in."
	)
	var source_units: int = state.find_city("allies_home").unit_count
	var occupation_result: GameActionResult = state.occupy_city(
		"allies_home",
		"german_target",
		1
	)
	_expect(occupation_result.succeeded(), "The attacker should occupy a defeated city.")
	_expect(
		state.find_city("german_target").owner_id == "allies",
		"Moving units into the target should change its ownership."
	)
	_expect(
		state.find_city("allies_home").unit_count == source_units - 1,
		"Occupation should move units from the source garrison."
	)


func _test_attacker_elimination() -> void:
	var state := _create_state()
	_begin_attack(state)
	state.find_city("allies_home").unit_count = 1
	var result: CombatRoundResult = state.resolve_attack_round(
		"allies_home",
		"german_target",
		1,
		1,
		_service(3)
	)
	_expect(result.succeeded(), "A valid one-unit attack should resolve.")
	_expect(result.attacker_losses == 1, "The seeded dice comparison should favor the defender.")
	_expect(
		state.find_city("allies_home").unit_count == 0,
		"An eliminated attacking garrison should have no units remaining."
	)
	_expect(
		state.find_city("allies_home").owner_id.is_empty(),
		"An eliminated attacking garrison should become unoccupied."
	)


func _test_unoccupied_city_occupation() -> void:
	var state := _create_state()
	_begin_attack(state)
	state.find_city("german_target").owner_id = ""
	state.find_city("german_target").unit_count = 0

	var invalid_occupation := state.occupy_city("allies_home", "german_target", 3)
	_expect(
		not invalid_occupation.succeeded(),
		"An attacker must leave at least one unit in its source city."
	)
	_expect(
		state.find_city("allies_home").unit_count == 3,
		"Rejected occupation must not change the source garrison."
	)
	var valid_occupation := state.occupy_city("allies_home", "german_target", 2)
	_expect(valid_occupation.succeeded(), "A valid adjacent empty city should be occupiable.")
	_expect(
		state.find_city("allies_home").unit_count == 1,
		"Occupation must leave at least one unit at the source."
	)
	_expect(
		state.find_city("german_target").unit_count == 2,
		"Moved units should form the occupying garrison."
	)
	_expect(
		state.find_city("german_target").owner_id == "allies",
		"The occupying player should own the newly occupied city."
	)


func _create_state() -> GameState:
	var allies := GamePlayerScript.new("allies", "Allies", "allies_home")
	var germans := GamePlayerScript.new("german_empire", "Germany", "german_home")
	var cities: Array[GameCity] = [
		GameCityScript.new("allies_home", allies.id, 3),
		GameCityScript.new("allies_target", allies.id, 2),
		GameCityScript.new("german_home", germans.id, 2),
		GameCityScript.new("german_target", germans.id, 1),
	]
	return GameStateScript.new([allies, germans], cities)


func _begin_attack(state: GameState) -> void:
	var map_definition: GameMapDefinition = GameMapDefinitionScript.new(
		[
			MapCityDefinitionScript.new("allies_home", "Allies Home", Vector2.ZERO, true),
			MapCityDefinitionScript.new("allies_target", "Allies Target", Vector2.ZERO),
			MapCityDefinitionScript.new("german_home", "German Home", Vector2.ZERO, true),
			MapCityDefinitionScript.new("german_target", "German Target", Vector2.ZERO),
		],
		[
			MapConnectionScript.new("allies_home", "german_target"),
		]
	)
	var reinforcement_result: GameActionResult = state.begin_reinforcement_turn(
		map_definition,
		"allies"
	)
	_expect(reinforcement_result.succeeded(), "The test state should enter reinforcement.")
	var attack_phase_result: GameActionResult = state.begin_attack_phase()
	_expect(
		attack_phase_result.succeeded(),
		"Zero reinforcements should allow the attack phase to start."
	)


func _service(seed_value: int = 1914) -> CombatService:
	var random_generator := RandomNumberGenerator.new()
	random_generator.seed = seed_value
	return CombatServiceScript.new(random_generator)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
