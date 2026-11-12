class_name GameApplication
extends RefCounted

const GameSetupScript = preload("res://scripts/domain/game_setup.gd")
const CombatServiceScript = preload("res://scripts/domain/combat_service.gd")
const GameViewSnapshotScript = preload("res://scripts/application/game_view_snapshot.gd")
const BoardSetupLoaderScript = preload("res://scripts/infrastructure/board_setup_loader.gd")

const QUICK_START_ALLIES_NAME := "Joffre"
const QUICK_START_GERMAN_NAME := "Moltke"
const DEV_MODE_UNAVAILABLE_MESSAGE := "Developer mode is only available in debug builds."

var can_start_dev_mode: bool:
	get:
		return OS.is_debug_build()

var _active_game_state: GameState
var _map_definition: GameMapDefinition
var _map_load_error: String
var _random_generator: RandomNumberGenerator
var _combat_service: CombatService
var _is_dev_mode_active: bool = false


func _init(random_generator: RandomNumberGenerator) -> void:
	_random_generator = random_generator
	var map_load_result: BoardSetupLoadResult = BoardSetupLoaderScript.new().load_western_front()
	_map_definition = map_load_result.map_definition
	_map_load_error = map_load_result.error_message
	_combat_service = CombatServiceScript.new(random_generator)


func is_dev_mode_active() -> bool:
	return _is_dev_mode_active


func get_view_snapshot() -> GameViewSnapshot:
	if _active_game_state == null:
		return null

	var snapshot := GameViewSnapshotScript.new() as GameViewSnapshot
	var snapshot_phase := _snapshot_phase(_active_game_state.phase)
	if snapshot_phase < 0:
		return null
	snapshot.phase = snapshot_phase as GameViewSnapshot.Phase
	snapshot.active_player_id = _active_game_state.active_player_id
	snapshot.reinforcements_remaining = _active_game_state.reinforcements_remaining
	snapshot.winner_id = _active_game_state.winner_id
	snapshot.dev_mode_active = _is_dev_mode_active
	snapshot.max_development_garrison_size = GameState.MAX_DEV_GARRISON_SIZE

	var active_player := _active_game_state.find_player(snapshot.active_player_id)
	if active_player != null:
		snapshot.active_player_name = active_player.name
	elif not snapshot.active_player_id.is_empty():
		push_error("Game state has an unknown active player '%s'." % snapshot.active_player_id)
		return null

	var winner := _active_game_state.find_player(snapshot.winner_id)
	if winner != null:
		snapshot.winner_name = winner.name
	elif not snapshot.winner_id.is_empty():
		push_error("Game state has an unknown winner '%s'." % snapshot.winner_id)
		return null

	for player: GamePlayer in _active_game_state.players:
		var player_view := GameViewSnapshot.PlayerView.new()
		player_view.id = player.id
		player_view.name = player.name
		player_view.center_of_gravity_city_id = player.center_of_gravity_city_id
		player_view.reserves_remaining = int(
			_active_game_state.reserves_remaining_by_player_id.get(player.id, 0)
		)
		snapshot.players.append(player_view)

	for city_definition: MapCityDefinition in _map_definition.cities:
		var city_state := _active_game_state.find_city(city_definition.id)
		if city_state == null:
			push_error("Game state has no entry for map city '%s'." % city_definition.id)
			return null
		var city_view := GameViewSnapshot.CityView.new()
		city_view.id = city_definition.id
		city_view.name = city_definition.name
		city_view.latitude = city_definition.latitude
		city_view.longitude = city_definition.longitude
		city_view.is_center_of_gravity = city_definition.is_center_of_gravity
		city_view.owner_id = city_state.owner_id
		city_view.unit_count = city_state.unit_count
		if not city_state.owner_id.is_empty():
			var owner := _active_game_state.find_player(city_state.owner_id)
			if owner == null:
				push_error(
					"City '%s' has unknown owner '%s'."
					% [city_definition.id, city_state.owner_id]
				)
				return null
			city_view.owner_name = owner.name
		if not city_state.last_owner_id.is_empty():
			var last_owner := _active_game_state.find_player(city_state.last_owner_id)
			if last_owner == null:
				push_error(
					"City '%s' has unknown last owner '%s'."
					% [city_definition.id, city_state.last_owner_id]
				)
				return null
			city_view.last_owner_name = last_owner.name
		snapshot.cities.append(city_view)

	for connection: MapConnection in _map_definition.connections:
		if (
			snapshot.find_city(connection.from_city_id) == null
			or snapshot.find_city(connection.to_city_id) == null
		):
			push_error(
				"Map connection references an unknown city: %s to %s."
				% [connection.from_city_id, connection.to_city_id]
			)
			return null
		var connection_view := GameViewSnapshot.ConnectionView.new()
		connection_view.from_city_id = connection.from_city_id
		connection_view.to_city_id = connection.to_city_id
		snapshot.connections.append(connection_view)

	return snapshot


func _snapshot_phase(game_phase: GameState.Phase) -> int:
	match game_phase:
		GameState.Phase.INITIAL_RESERVE_PLACEMENT:
			return GameViewSnapshot.Phase.INITIAL_RESERVE_PLACEMENT
		GameState.Phase.ACTIVE_PLAY:
			return GameViewSnapshot.Phase.ACTIVE_PLAY
		GameState.Phase.REINFORCEMENT_PLACEMENT:
			return GameViewSnapshot.Phase.REINFORCEMENT_PLACEMENT
		GameState.Phase.ATTACK:
			return GameViewSnapshot.Phase.ATTACK
		GameState.Phase.REORGANIZATION:
			return GameViewSnapshot.Phase.REORGANIZATION
	push_error("Cannot create a view snapshot for an unknown game phase.")
	return -1


func change_city_owner_for_development(city_id: String) -> GameActionResult:
	var authorization_result := _validate_development_operation()
	if not authorization_result.succeeded():
		return authorization_result
	return _active_game_state.change_city_owner_for_development(city_id)


func add_units_for_development(city_id: String, amount: int) -> GameActionResult:
	var authorization_result := _validate_development_operation()
	if not authorization_result.succeeded():
		return authorization_result
	return _active_game_state.add_units_for_development(city_id, amount)


func remove_units_for_development(city_id: String, amount: int) -> GameActionResult:
	var authorization_result := _validate_development_operation()
	if not authorization_result.succeeded():
		return authorization_result
	return _active_game_state.remove_units_for_development(city_id, amount)


func _validate_development_operation() -> GameActionResult:
	if not can_start_dev_mode:
		return GameActionResult.new(DEV_MODE_UNAVAILABLE_MESSAGE)
	if not _is_dev_mode_active:
		return GameActionResult.new("Start a dev-mode game before using developer tools.")
	if _active_game_state == null:
		return GameActionResult.new("Start a game before using developer tools.")
	return GameActionResult.new()


func start_new_game(allies_name: String, german_empire_name: String) -> GameStartResult:
	var trimmed_allies_name := allies_name.strip_edges()
	var trimmed_german_empire_name := german_empire_name.strip_edges()
	if trimmed_allies_name.is_empty():
		return GameStartResult.new(false, "Enter a name for the Allied leader.")
	if trimmed_german_empire_name.is_empty():
		return GameStartResult.new(false, "Enter a name for the German Empire leader.")
	if _map_definition == null:
		return GameStartResult.new(false, _map_load_error)

	_is_dev_mode_active = false
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
	return GameStartResult.new(true)


func start_dev_mode_game() -> GameStartResult:
	if not can_start_dev_mode:
		return GameStartResult.new(false, DEV_MODE_UNAVAILABLE_MESSAGE)

	var result := start_quick_game()
	if result.succeeded():
		_is_dev_mode_active = true
	return result


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
				false,
				"The active player has no city for initial reserve placement."
			)

		var random_index := _random_generator.randi_range(0, owned_city_ids.size() - 1)
		var placement_result := place_initial_reserve(owned_city_ids[random_index])
		if not placement_result.succeeded():
			return GameStartResult.new(false, placement_result.error_message)

	return GameStartResult.new(true)


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
