class_name GameApplication
extends RefCounted

const GameSetupScript = preload("res://scripts/domain/game_setup.gd")

var _active_game_state: GameState
var _map_definition: GameMapDefinition
var _random_generator: RandomNumberGenerator


func _init(random_generator: RandomNumberGenerator) -> void:
	_random_generator = random_generator
	_map_definition = GameMapDefinition.create_western_front()


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


func skip_reinforcement_turn() -> GameActionResult:
	if _active_game_state == null:
		return GameActionResult.new("Start a new game before advancing reinforcement turns.")
	return _active_game_state.skip_reinforcement_turn()
