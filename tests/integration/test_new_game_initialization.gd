extends SceneTree

const GameApplicationScript = preload("res://scripts/application/game_application.gd")
const GameSetupScript = preload("res://scripts/domain/game_setup.gd")

var _failures: int = 0


func _initialize() -> void:
	var random_generator := RandomNumberGenerator.new()
	random_generator.seed = 1914
	var application: GameApplication = GameApplicationScript.new(random_generator)
	var map_definition: GameMapDefinition = application.get_map_definition()
	var premature_placement: GameActionResult = application.place_initial_reserve("paris")
	_expect(
		not premature_placement.succeeded(),
		"Reserves cannot be placed before a new game has been initialized."
	)
	var result: GameStartResult = application.start_new_game(
		"Allied commander",
		"German commander"
	)
	var state: GameState = result.game_state

	_expect(result.succeeded(), "A new game should succeed when both leaders are named.")
	_expect(state.players.size() == 2, "A new game should initialize both players.")
	_expect(
		map_definition.cities.size() == 32,
		"The map should define all 32 cities."
	)
	_expect(map_definition.connections.size() > 0, "The map should define road connections.")
	_expect(
		state.cities.size() == map_definition.cities.size(),
		"Game state should have a state entry for every map city."
	)
	_expect(
		state.players[0].name == "Allied commander",
		"The Allies should use the entered leader name."
	)
	_expect(
		state.players[1].name == "German commander",
		"The German Empire should use the entered leader name."
	)
	_expect(
		state.find_city("paris").owner_id == state.players[0].id,
		"Paris should belong to the Allies."
	)
	_expect(
		state.find_city("koblenz").owner_id == state.players[1].id,
		"Koblenz should belong to the German Empire."
	)
	_expect(state.find_city("paris").unit_count == 1, "Paris should start with one sample unit.")
	_expect(state.find_city("koblenz").unit_count == 1, "Koblenz should start with one sample unit.")
	_expect(
		map_definition.find_city("paris").is_center_of_gravity,
		"Paris should be marked as a COG in the map."
	)
	_expect(
		map_definition.find_city("koblenz").is_center_of_gravity,
		"Koblenz should be marked as a COG in the map."
	)
	var allies_count := 0
	var german_count := 0
	for city: GameCity in state.cities:
		if city.owner_id == "allies":
			allies_count += 1
		elif city.owner_id == "german_empire":
			german_count += 1
	_expect(allies_count == 16, "The Allies should have a balanced starting territory count.")
	_expect(german_count == 16, "The German Empire should have a balanced starting territory count.")
	_expect(
		state.phase == GameState.Phase.INITIAL_RESERVE_PLACEMENT,
		"A new game should begin with initial reserve placement."
	)
	_expect(
		state.active_player_id == "german_empire",
		"The German Empire should have the first reserve placement."
	)

	for placement_index: int in GameSetupScript.INITIAL_RESERVES_PER_PLAYER * 2:
		var active_player := state.find_player(state.active_player_id)
		var placement_result: GameActionResult = application.place_initial_reserve(
			active_player.center_of_gravity_city_id
		)
		_expect(placement_result.succeeded(), "The active player should place each initial reserve.")
	_expect(
		state.phase == GameState.Phase.REINFORCEMENT_PLACEMENT,
		"Completing setup reserves should start reinforcement placement."
	)
	_expect(
		state.active_player_id == "german_empire",
		"Germany should start the first reinforcement turn."
	)
	_expect(
		state.reinforcements_remaining == 3,
		"Sixteen controlled cities should award three German reinforcements."
	)
	for reinforcement_index: int in state.reinforcements_remaining:
		var reinforcement_result: GameActionResult = application.place_reinforcement("koblenz")
		_expect(
			reinforcement_result.succeeded(),
			"Germany should be able to place reinforcements in its COG."
		)
	_expect(
		state.phase == GameState.Phase.ATTACK,
		"Completing reinforcements should begin the same player's attack phase."
	)
	_expect(
		state.active_player_id == "german_empire",
		"Completing reinforcements should not switch the active player."
	)

	var invalid_result: GameStartResult = application.start_new_game(" ", "German commander")
	_expect(not invalid_result.succeeded(), "An empty leader name should prevent game initialization.")
	_expect(
		invalid_result.error_message == "Enter a name for the Allied leader.",
		"Invalid names should return a clear message."
	)

	_test_quick_start_is_deterministic()

	if _failures == 0:
		print("New game initialization integration tests passed.")
	quit(1 if _failures > 0 else 0)


func _test_quick_start_is_deterministic() -> void:
	var first_random_generator := RandomNumberGenerator.new()
	first_random_generator.seed = 2718
	var first_application: GameApplication = GameApplicationScript.new(first_random_generator)
	var first_result: GameStartResult = first_application.start_quick_game()
	_expect(first_result.succeeded(), "Quick start should initialize successfully.")
	if not first_result.succeeded():
		return

	var second_random_generator := RandomNumberGenerator.new()
	second_random_generator.seed = 2718
	var second_application: GameApplication = GameApplicationScript.new(second_random_generator)
	var second_result: GameStartResult = second_application.start_quick_game()
	_expect(second_result.succeeded(), "A second seeded quick start should initialize.")
	if not second_result.succeeded():
		return

	var first_state := first_result.game_state
	var second_state := second_result.game_state
	_expect(first_state.players[0].name == "Joffre", "Quick start should name the Allies Joffre.")
	_expect(first_state.players[1].name == "Moltke", "Quick start should name Germany Moltke.")
	_expect(
		first_state.phase == GameState.Phase.REINFORCEMENT_PLACEMENT,
		"Quick start should finish both players' reserve placement."
	)
	_expect(
		first_state.active_player_id == "german_empire",
		"Quick start should begin the first German reinforcement phase."
	)
	var total_units := 0
	var allies_units := 0
	var german_units := 0
	for city_index: int in first_state.cities.size():
		var first_city := first_state.cities[city_index]
		var second_city := second_state.find_city(first_city.id)
		total_units += first_city.unit_count
		if first_city.owner_id == "allies":
			allies_units += first_city.unit_count
		else:
			german_units += first_city.unit_count
		_expect(
			first_city.owner_id == "allies" or first_city.owner_id == "german_empire",
			"Random reserve placement must preserve city ownership."
		)
		_expect(
			first_city.owner_id == second_city.owner_id
			and first_city.unit_count == second_city.unit_count,
			"Quick start should produce the same setup from the same random seed."
		)
	_expect(total_units == 42, "Quick start should place exactly ten reserve units.")
	_expect(allies_units == 21, "Quick start should place five reserves for the Allies.")
	_expect(german_units == 21, "Quick start should place five reserves for Germany.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
