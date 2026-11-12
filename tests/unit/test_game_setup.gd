extends SceneTree

const GameSetupScript = preload("res://scripts/domain/game_setup.gd")
const GamePlayerScript = preload("res://scripts/domain/player.gd")
const BoardSetupLoaderScript = preload("res://scripts/infrastructure/board_setup_loader.gd")

var _failures: int = 0


func _initialize() -> void:
	var map_load_result: BoardSetupLoadResult = BoardSetupLoaderScript.new().load_western_front()
	_expect(map_load_result.succeeded(), "Game setup should load the CSV-backed map.")
	if not map_load_result.succeeded():
		quit(1)
		return
	var map_definition: GameMapDefinition = map_load_result.map_definition
	var allies: GamePlayer = GamePlayerScript.new("allies", "Allied leader", "paris")
	var german_empire: GamePlayer = GamePlayerScript.new("german_empire", "German leader", "koblenz")
	var first_rng := RandomNumberGenerator.new()
	first_rng.seed = 1914
	var second_rng := RandomNumberGenerator.new()
	second_rng.seed = 1914

	var first_state: GameState = GameSetupScript.create_initial_state(
		map_definition,
		allies,
		german_empire,
		first_rng
	)
	var second_state: GameState = GameSetupScript.create_initial_state(
		map_definition,
		allies,
		german_empire,
		second_rng
	)
	var owned_city_counts: Dictionary = {
		allies.id: 0,
		german_empire.id: 0,
	}

	_expect(first_state.cities.size() == 32, "Initial game state should include all 32 cities.")
	_expect(
		first_state.find_city("paris").owner_id == allies.id,
		"Paris should always belong to the Allies."
	)
	_expect(
		first_state.find_city("koblenz").owner_id == german_empire.id,
		"Koblenz should always belong to the German Empire."
	)
	for city: GameCity in first_state.cities:
		_expect(
			city.owner_id == allies.id or city.owner_id == german_empire.id,
			"Every city should be assigned to exactly one player."
		)
		_expect(city.unit_count == 1, "Every city should start with one infantry unit.")
		owned_city_counts[city.owner_id] += 1
		_expect(
			city.owner_id == second_state.find_city(city.id).owner_id,
			"A fixed random seed should reproduce city ownership."
		)
	_expect(owned_city_counts[allies.id] == 16, "The Allies should start with 15 cities plus Paris.")
	_expect(
		owned_city_counts[german_empire.id] == 16,
		"The German Empire should start with 15 cities plus Koblenz."
	)

	if _failures == 0:
		print("Game setup unit tests passed.")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
