class_name GameApplication
extends RefCounted

const GameSetupScript = preload("res://scripts/domain/game_setup.gd")
const CombatServiceScript = preload("res://scripts/domain/combat_service.gd")

const QUICK_START_ALLIES_NAME := "Joffre"
const QUICK_START_GERMAN_NAME := "Moltke"

var _active_game_state: GameState
var _map_definition: GameMapDefinition
var _random_generator: RandomNumberGenerator
var _combat_service: CombatService


func _init(random_generator: RandomNumberGenerator) -> void:
	_random_generator = random_generator
	_map_definition = GameMapDefinition.create_western_front()
	_combat_service = CombatServiceScript.new(random_generator)


func get_map_definition() -> GameMapDefinition:
	return _map_definition


func start_new_game(allies_name: String, german_empire_name: String) -> GameStartResult:
	var trimmed_allies_name := allies_name.strip_edges()
	var trimmed_german_empire_name := german_empire_name.strip_edges()
	if trimmed_allies_name.is_empty():
		return GameStartResult.new(null, "Enter a name for the Allied leader.")
	if trimmed_german_empire_name.is_empty():
		return GameStartResult.new(null, "Enter a name for the German Empire leader.")

	var allies := GamePlayer.new(
		GameSetupScript.ALLIES_ID,
		trimmed_allies_name,
		GameSetupScript.ALLIES_COG_ID
	)
	var german_empire := GamePlayer.new(
		GameSetupScript.GERMAN_EMPIRE_ID,
		trimmed_german_empire_name,
		GameSetupScript.GERMAN_EMPIRE_COG_ID
	)
	_active_game_state = GameSetup.create_initial_state(
		_map_definition,
		allies,
		german_empire,
		_random_generator
	)
	return GameStartResult.new(_active_game_state)


func start_quick_game() -> GameStartResult:
	var start_result := start_new_game(
		QUICK_START_ALLIES_NAME,
		QUICK_START_GERMAN_NAME
	)
	if not start_result.succeeded():
		return start_result

	while _active_game_state.phase == GameState.Phase.INITIAL_RESERVE_PLACEMENT:
		var active_player_id := _active_game_state.active_player_id
		var owned_city_ids: Array[String] = []
		for city: GameCity in _active_game_state.cities:
			if city.owner_id == active_player_id:
				owned_city_ids.append(city.id)
		if owned_city_ids.is_empty():
			return GameStartResult.new(
				null,
				"The active player has no city for initial reserve placement."
			)

		var random_index := _random_generator.randi_range(0, owned_city_ids.size() - 1)
		var placement_result := place_initial_reserve(owned_city_ids[random_index])
		if not placement_result.succeeded():
			return GameStartResult.new(null, placement_result.error_message)

	return GameStartResult.new(_active_game_state)


func place_initial_reserve(city_id: String) -> GameActionResult:
	if _active_game_state == null:
		return GameActionResult.new("Start a new game before placing reserves.")
	var result := _active_game_state.place_initial_reserve(city_id)
	if result.succeeded() and _active_game_state.phase == GameState.Phase.ACTIVE_PLAY:
		return _active_game_state.begin_reinforcement_turn(
			_map_definition,
			GameSetupScript.GERMAN_EMPIRE_ID
		)
	return result


func place_reinforcement(city_id: String) -> GameActionResult:
	if _active_game_state == null:
		return GameActionResult.new("Start a new game before placing reinforcements.")
	return _active_game_state.place_reinforcement(city_id)


func begin_attack_phase() -> GameActionResult:
	if _active_game_state == null:
		return GameActionResult.new("Start a new game before beginning an attack phase.")
	return _active_game_state.begin_attack_phase()


func validate_attack(
	attacking_city_id: String,
	defending_city_id: String,
	attacker_commitment: int
) -> GameActionResult:
	if _active_game_state == null:
		return GameActionResult.new("Start a new game before attacking.")
	return _active_game_state.validate_attack(
		attacking_city_id,
		defending_city_id,
		attacker_commitment
	)


func validate_attack_source(attacking_city_id: String) -> GameActionResult:
	if _active_game_state == null:
		return GameActionResult.new("Start a new game before selecting an attacking city.")
	return _active_game_state.validate_attack_source(attacking_city_id)


func validate_attack_target(defending_city_id: String) -> GameActionResult:
	if _active_game_state == null:
		return GameActionResult.new("Start a new game before selecting an attack target.")
	return _active_game_state.validate_attack_target(defending_city_id)


func resolve_attack_round(
	attacking_city_id: String,
	defending_city_id: String,
	attacker_commitment: int,
	defender_commitment: int
) -> CombatRoundResult:
	if _active_game_state == null:
		return CombatRoundResult.new([], [], 0, 0, "Start a new game before attacking.")
	return _active_game_state.resolve_attack_round(
		attacking_city_id,
		defending_city_id,
		attacker_commitment,
		defender_commitment,
		_combat_service
	)


func occupy_city(
	attacking_city_id: String,
	target_city_id: String,
	unit_count: int
) -> GameActionResult:
	if _active_game_state == null:
		return GameActionResult.new("Start a new game before occupying cities.")
	return _active_game_state.occupy_city(
		attacking_city_id,
		target_city_id,
		unit_count
	)


func end_attack_phase() -> GameActionResult:
	if _active_game_state == null:
		return GameActionResult.new("Start a new game before ending the attack phase.")
	return _active_game_state.end_attack_phase()


func validate_reorganization_source(source_city_id: String) -> GameActionResult:
	if _active_game_state == null:
		return GameActionResult.new("Start a new game before selecting a city to reorganize.")
	return _active_game_state.validate_reorganization_source(source_city_id)


func validate_reorganization_move(
	source_city_id: String,
	target_city_id: String,
	unit_count: int
) -> GameActionResult:
	if _active_game_state == null:
		return GameActionResult.new("Start a new game before moving units.")
	return _active_game_state.validate_reorganization_move(
		source_city_id,
		target_city_id,
		unit_count
	)


func move_reorganization_units(
	source_city_id: String,
	target_city_id: String,
	unit_count: int
) -> GameActionResult:
	if _active_game_state == null:
		return GameActionResult.new("Start a new game before moving units.")
	return _active_game_state.move_reorganization_units(
		source_city_id,
		target_city_id,
		unit_count
	)


func end_reorganization_phase() -> GameActionResult:
	if _active_game_state == null:
		return GameActionResult.new("Start a new game before ending reorganization.")
	var players := _active_game_state.players
	if players.size() < 2:
		return GameActionResult.new("At least two players are required to advance the turn.")

	var active_player_index := -1
	for player_index: int in players.size():
		if players[player_index].id == _active_game_state.active_player_id:
			active_player_index = player_index
			break
	if active_player_index < 0:
		return GameActionResult.new("The active player is not in this game.")

	var next_player_index := (active_player_index + 1) % players.size()
	return _active_game_state.end_reorganization_phase(players[next_player_index].id)
