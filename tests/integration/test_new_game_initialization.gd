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

	var invalid_result: GameStartResult = application.start_new_game(" ", "German commander")
	_expect(not invalid_result.succeeded(), "An empty leader name should prevent game initialization.")
	_expect(
		invalid_result.error_message == "Enter a name for the Allied leader.",
		"Invalid names should return a clear message."
	)

	if _failures == 0:
		print("New game initialization integration tests passed.")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
