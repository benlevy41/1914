class_name GameState
extends RefCounted

enum Phase {
	INITIAL_RESERVE_PLACEMENT,
	ACTIVE_PLAY,
	REINFORCEMENT_PLACEMENT,
	ATTACK,
	REORGANIZATION,
}

const CITIES_PER_REINFORCEMENT := 5
const MAX_DEV_GARRISON_SIZE := 9007199254740991

var players: Array[GamePlayer]
var cities: Array[GameCity]
var phase: Phase
var active_player_id: String
var reserves_remaining_by_player_id: Dictionary
var reinforcements_remaining: int = 0
var winner_id: String = ""
var _map_definition: GameMapDefinition


func _init(
	initial_players: Array[GamePlayer],
	initial_cities: Array[GameCity],
	initial_reserves_per_player: int = 0,
	first_reserve_placement_player_id: String = ""
) -> void:
	assert(initial_reserves_per_player >= 0)
	players = initial_players
	cities = initial_cities
	phase = Phase.INITIAL_RESERVE_PLACEMENT if initial_reserves_per_player > 0 else Phase.ACTIVE_PLAY
	active_player_id = (
		first_reserve_placement_player_id
		if phase == Phase.INITIAL_RESERVE_PLACEMENT
		else ""
	)
	reserves_remaining_by_player_id = {}
	for player: GamePlayer in players:
		reserves_remaining_by_player_id[player.id] = initial_reserves_per_player
	if phase == Phase.INITIAL_RESERVE_PLACEMENT:
		assert(not active_player_id.is_empty())
		assert(reserves_remaining_by_player_id.has(active_player_id))
	_check_for_winner()


func find_player(player_id: String) -> GamePlayer:
	for player: GamePlayer in players:
		if player.id == player_id:
			return player
	return null


func find_city(city_id: String) -> GameCity:
	for city: GameCity in cities:
		if city.id == city_id:
			return city
	return null


func change_city_owner_for_development(city_id: String) -> GameActionResult:
	var game_over_error := _game_over_error()
	if not game_over_error.is_empty():
		return GameActionResult.new(game_over_error)

	var city := find_city(city_id)
	if city == null:
		return GameActionResult.new("That city is not on the map.")
	if city.owner_id.is_empty() or city.unit_count <= 0:
		return GameActionResult.new("An unoccupied city has no owner to change.")
	if players.size() != 2:
		return GameActionResult.new("Changing city ownership requires exactly two players.")

	var current_owner := find_player(city.owner_id)
	if current_owner == null:
		return GameActionResult.new("The city owner is not in this game.")
	var other_player: GamePlayer
	for player: GamePlayer in players:
		if player.id != current_owner.id:
			other_player = player
			break
	if other_player == null:
		return GameActionResult.new("The other player could not be found.")

	city.assign_owner(other_player.id)
	_check_for_winner()
	return GameActionResult.new()


func add_units_for_development(city_id: String, amount: int) -> GameActionResult:
	var game_over_error := _game_over_error()
	if not game_over_error.is_empty():
		return GameActionResult.new(game_over_error)

	var city := find_city(city_id)
	if city == null:
		return GameActionResult.new("That city is not on the map.")
	var owner_id := city.owner_id if not city.owner_id.is_empty() else city.last_owner_id
	if owner_id.is_empty() or find_player(owner_id) == null:
		return GameActionResult.new(
			"Developer unit additions require a current or remembered owner."
		)
	if not city.owner_id.is_empty() and city.unit_count <= 0:
		return GameActionResult.new("The city's current garrison is invalid.")
	if amount <= 0:
		return GameActionResult.new("Choose a positive number of units to add.")
	if city.unit_count > MAX_DEV_GARRISON_SIZE:
		return GameActionResult.new("The city's garrison is already above the supported limit.")
	if amount > MAX_DEV_GARRISON_SIZE - city.unit_count:
		return GameActionResult.new("The city's garrison cannot exceed the supported limit.")

	if city.owner_id.is_empty() and not city.restore_last_owner():
		return GameActionResult.new("The city's previous owner could not be restored.")
	city.add_units(amount)
	_check_for_winner()
	return GameActionResult.new()


func remove_units_for_development(city_id: String, amount: int) -> GameActionResult:
	var game_over_error := _game_over_error()
	if not game_over_error.is_empty():
		return GameActionResult.new(game_over_error)

	var city := _find_occupied_development_city(city_id)
	if city == null:
		return GameActionResult.new(_development_city_error(city_id))
	if amount <= 0:
		return GameActionResult.new("Choose a positive number of units to remove.")
	if amount > city.unit_count:
		return GameActionResult.new("Cannot remove more units than the city garrison contains.")

	city.remove_units(amount)
	if city.unit_count == 0:
		city.leave_unoccupied()
	_check_for_winner()
	return GameActionResult.new()


func _find_occupied_development_city(city_id: String) -> GameCity:
	var city := find_city(city_id)
	if city == null or city.owner_id.is_empty() or city.unit_count <= 0:
		return null
	if find_player(city.owner_id) == null:
		return null
	return city


func _development_city_error(city_id: String) -> String:
	var city := find_city(city_id)
	if city == null:
		return "That city is not on the map."
	if city.owner_id.is_empty() or city.unit_count <= 0:
		return "Developer unit changes require an occupied city."
	return "The city owner is not in this game."


func validate_initial_reserve(city_id: String) -> GameActionResult:
	var game_over_error := _game_over_error()
	if not game_over_error.is_empty():
		return GameActionResult.new(game_over_error)
	if phase != Phase.INITIAL_RESERVE_PLACEMENT:
		return GameActionResult.new("Initial reserve placement is not in progress.")

	var reserves_remaining: int = reserves_remaining_by_player_id.get(active_player_id, 0)
	if reserves_remaining <= 0:
		return GameActionResult.new("The active player has no reserve units remaining.")

	var city := find_city(city_id)
	if city == null:
		return GameActionResult.new("That city is not on the map.")
	if city.owner_id != active_player_id:
		return GameActionResult.new("Choose a city owned by the player placing a reserve.")
	return GameActionResult.new()


func place_initial_reserve(city_id: String) -> GameActionResult:
	var validation_result := validate_initial_reserve(city_id)
	if not validation_result.succeeded():
		return validation_result
	var city := find_city(city_id)
	var reserves_remaining: int = reserves_remaining_by_player_id[active_player_id]
	city.add_units(1)
	reserves_remaining_by_player_id[active_player_id] = reserves_remaining - 1
	_advance_initial_reserve_placement()
	_check_for_winner()
	return GameActionResult.new()


func begin_reinforcement_turn(
	map_definition: GameMapDefinition,
	first_player_id: String
) -> GameActionResult:
	var game_over_error := _game_over_error()
	if not game_over_error.is_empty():
		return GameActionResult.new(game_over_error)
	if phase != Phase.ACTIVE_PLAY:
		return GameActionResult.new("Reinforcement placement cannot start right now.")
	if players.is_empty():
		return GameActionResult.new("A game must have players before reinforcement placement.")
	if map_definition == null:
		return GameActionResult.new("A map is required to start reinforcement placement.")
	if not _validate_reinforcement_map(map_definition):
		return GameActionResult.new("The map is missing a player's center of gravity or a city.")
	if find_player(first_player_id) == null:
		return GameActionResult.new("The first reinforcement player is not in this game.")

	_map_definition = map_definition
	_start_reinforcement_turn(first_player_id)
	return GameActionResult.new()


func place_reinforcement(city_id: String) -> GameActionResult:
	var validation_result := validate_reinforcement(city_id)
	if not validation_result.succeeded():
		return validation_result

	var city := find_city(city_id)
	city.add_units(1)
	reinforcements_remaining -= 1
	if reinforcements_remaining == 0:
		phase = Phase.ATTACK
	_check_for_winner()
	return GameActionResult.new()


func validate_reinforcement(city_id: String) -> GameActionResult:
	var game_over_error := _game_over_error()
	if not game_over_error.is_empty():
		return GameActionResult.new(game_over_error)
	if phase != Phase.REINFORCEMENT_PLACEMENT:
		return GameActionResult.new("Reinforcement placement is not in progress.")
	if reinforcements_remaining <= 0:
		return GameActionResult.new("The active player has no reinforcements remaining.")

	var city := find_city(city_id)
	if city == null:
		return GameActionResult.new("That city is not on the map.")
	if city.owner_id != active_player_id:
		return GameActionResult.new("Choose a city owned by the active player.")
	if not _get_reinforcement_reachable_city_ids(active_player_id).has(city_id):
		return GameActionResult.new(
			"Choose a city connected to the active player's center of gravity by controlled roads."
		)

	return GameActionResult.new()


func begin_attack_phase() -> GameActionResult:
	var game_over_error := _game_over_error()
	if not game_over_error.is_empty():
		return GameActionResult.new(game_over_error)
	if phase != Phase.REINFORCEMENT_PLACEMENT:
		return GameActionResult.new("The attack phase cannot start right now.")
	if reinforcements_remaining > 0:
		return GameActionResult.new("All reinforcements must be placed before attacking.")

	phase = Phase.ATTACK
	return GameActionResult.new()


func validate_attack_source(attacking_city_id: String) -> GameActionResult:
	var game_over_error := _game_over_error()
	if not game_over_error.is_empty():
		return GameActionResult.new(game_over_error)
	if phase != Phase.ATTACK:
		return GameActionResult.new("Attacking cities can only be selected during the attack phase.")
	var attacking_city := find_city(attacking_city_id)
	if attacking_city == null:
		return GameActionResult.new("The attacking city is not on the map.")
	if attacking_city.owner_id != active_player_id:
		return GameActionResult.new("Choose a city owned by the active player to attack from.")
	if attacking_city.unit_count < 2:
		return GameActionResult.new(
			"Choose an active player's city with at least two units; leave a unit in the source."
		)
	return GameActionResult.new()


func validate_attack_target(defending_city_id: String) -> GameActionResult:
	var game_over_error := _game_over_error()
	if not game_over_error.is_empty():
		return GameActionResult.new(game_over_error)
	if phase != Phase.ATTACK:
		return GameActionResult.new("Attack targets can only be selected during the attack phase.")
	var defending_city := find_city(defending_city_id)
	if defending_city == null:
		return GameActionResult.new("The target city is not on the map.")
	if defending_city.owner_id == active_player_id:
		return GameActionResult.new("The target city is already controlled by the active player.")
	return GameActionResult.new()


func validate_attack(
	attacking_city_id: String,
	defending_city_id: String,
	attacker_commitment: int
) -> GameActionResult:
	var source_result := validate_attack_source(attacking_city_id)
	if not source_result.succeeded():
		return source_result
	var attacking_city := find_city(attacking_city_id)
	var defending_city := find_city(defending_city_id)
	if defending_city == null:
		return GameActionResult.new("The defending city is not on the map.")
	if attacking_city_id == defending_city_id:
		return GameActionResult.new("A city cannot attack itself.")
	if attacker_commitment < 1 or attacker_commitment >= attacking_city.unit_count:
		return GameActionResult.new("Commit at least one unit and leave one in the source city.")
	if not _are_cities_connected(attacking_city_id, defending_city_id):
		return GameActionResult.new("Attacks must target a city directly connected by a road.")
	if defending_city.owner_id == active_player_id:
		return GameActionResult.new("The target city is already controlled by the active player.")
	if defending_city.owner_id.is_empty() or defending_city.unit_count == 0:
		return GameActionResult.new("The target city is unoccupied and can be occupied.")
	return GameActionResult.new()


func resolve_attack_round(
	attacking_city_id: String,
	defending_city_id: String,
	attacker_commitment: int,
	defender_commitment: int,
	combat_service: CombatService
) -> CombatRoundResult:
	var game_over_error := _game_over_error()
	if not game_over_error.is_empty():
		return CombatRoundResult.new([], [], 0, 0, game_over_error)
	var validation_result := validate_attack(
		attacking_city_id,
		defending_city_id,
		attacker_commitment
	)
	if not validation_result.succeeded():
		return CombatRoundResult.new([], [], 0, 0, validation_result.error_message)

	var attacking_city := find_city(attacking_city_id)
	var defending_city := find_city(defending_city_id)
	if defender_commitment < 1 or defender_commitment > defending_city.unit_count:
		return CombatRoundResult.new(
			[],
			[],
			0,
			0,
			"Choose at least one defending unit, up to the defending garrison."
		)
	if combat_service == null:
		return CombatRoundResult.new(
			[],
			[],
			0,
			0,
			"A combat service is required to resolve the round."
		)

	var result := combat_service.resolve_round(attacker_commitment, defender_commitment)
	if result.attacker_losses > 0:
		attacking_city.remove_units(result.attacker_losses)
	if result.defender_losses > 0:
		defending_city.remove_units(result.defender_losses)
	if defending_city.unit_count == 0:
		result.units_advanced = attacker_commitment - result.attacker_losses
		attacking_city.remove_units(result.units_advanced)
		defending_city.add_units(result.units_advanced)
		defending_city.assign_owner(active_player_id)
	_check_for_winner()
	return result


func validate_occupation(
	attacking_city_id: String,
	target_city_id: String,
	unit_count: int
) -> GameActionResult:
	var game_over_error := _game_over_error()
	if not game_over_error.is_empty():
		return GameActionResult.new(game_over_error)
	if phase != Phase.ATTACK:
		return GameActionResult.new("Cities can only be occupied during the attack phase.")
	var attacking_city := find_city(attacking_city_id)
	if attacking_city == null:
		return GameActionResult.new("The attacking city is not on the map.")
	var target_city := find_city(target_city_id)
	if target_city == null:
		return GameActionResult.new("The target city is not on the map.")
	if attacking_city_id == target_city_id:
		return GameActionResult.new("A city cannot occupy itself.")
	if attacking_city.owner_id != active_player_id:
		return GameActionResult.new("Choose a city owned by the active player to occupy from.")
	if target_city.owner_id != "" or target_city.unit_count != 0:
		return GameActionResult.new("Only an unoccupied city can be occupied.")
	if not _are_cities_connected(attacking_city_id, target_city_id):
		return GameActionResult.new("A city can only be occupied along a direct road.")
	if unit_count < 1 or unit_count >= attacking_city.unit_count:
		return GameActionResult.new("Move at least one unit and leave at least one in the source city.")
	return GameActionResult.new()


func occupy_city(
	attacking_city_id: String,
	target_city_id: String,
	unit_count: int
) -> GameActionResult:
	var validation_result := validate_occupation(attacking_city_id, target_city_id, unit_count)
	if not validation_result.succeeded():
		return validation_result
	var attacking_city := find_city(attacking_city_id)
	var target_city := find_city(target_city_id)
	attacking_city.remove_units(unit_count)
	target_city.add_units(unit_count)
	target_city.assign_owner(active_player_id)
	_check_for_winner()
	return GameActionResult.new()


func end_attack_phase() -> GameActionResult:
	var game_over_error := _game_over_error()
	if not game_over_error.is_empty():
		return GameActionResult.new(game_over_error)
	if phase != Phase.ATTACK:
		return GameActionResult.new("The attack phase is not in progress.")
	phase = Phase.REORGANIZATION
	return GameActionResult.new()


func validate_reorganization_source(source_city_id: String) -> GameActionResult:
	var game_over_error := _game_over_error()
	if not game_over_error.is_empty():
		return GameActionResult.new(game_over_error)
	if phase != Phase.REORGANIZATION:
		return GameActionResult.new("Cities can only be selected during reorganization.")
	var source_city := find_city(source_city_id)
	if source_city == null:
		return GameActionResult.new("The source city is not on the map.")
	if source_city.owner_id != active_player_id or source_city.unit_count <= 0:
		return GameActionResult.new("Choose an occupied city owned by the active player.")
	return GameActionResult.new()


func validate_reorganization_move(
	source_city_id: String,
	target_city_id: String,
	unit_count: int
) -> GameActionResult:
	var game_over_error := _game_over_error()
	if not game_over_error.is_empty():
		return GameActionResult.new(game_over_error)
	var source_result := validate_reorganization_source(source_city_id)
	if not source_result.succeeded():
		return source_result

	var source_city := find_city(source_city_id)
	var target_city := find_city(target_city_id)
	if target_city == null:
		return GameActionResult.new("The target city is not on the map.")
	if source_city_id == target_city_id:
		return GameActionResult.new("Units must move to a different city.")
	if target_city.owner_id != active_player_id or target_city.unit_count <= 0:
		return GameActionResult.new("Choose an occupied city owned by the active player.")
	if unit_count < 1 or unit_count > source_city.unit_count:
		return GameActionResult.new("Choose at least one unit, up to the source garrison.")
	if not _has_controlled_route(source_city_id, target_city_id):
		return GameActionResult.new(
			"Units can only move along roads occupied by the active player's forces."
		)
	return GameActionResult.new()


func move_reorganization_units(
	source_city_id: String,
	target_city_id: String,
	unit_count: int
) -> GameActionResult:
	var game_over_error := _game_over_error()
	if not game_over_error.is_empty():
		return GameActionResult.new(game_over_error)
	var validation_result := validate_reorganization_move(
		source_city_id,
		target_city_id,
		unit_count
	)
	if not validation_result.succeeded():
		return validation_result

	var source_city := find_city(source_city_id)
	var target_city := find_city(target_city_id)
	source_city.remove_units(unit_count)
	target_city.add_units(unit_count)
	if source_city.unit_count == 0:
		source_city.leave_unoccupied()
	_check_for_winner()
	return GameActionResult.new()


func end_reorganization_phase(next_player_id: String) -> GameActionResult:
	var game_over_error := _game_over_error()
	if not game_over_error.is_empty():
		return GameActionResult.new(game_over_error)
	if phase != Phase.REORGANIZATION:
		return GameActionResult.new("The reorganization phase is not in progress.")
	if _map_definition == null or not _validate_reinforcement_map(_map_definition):
		return GameActionResult.new("A valid map is required to begin the next turn.")
	if find_player(next_player_id) == null:
		return GameActionResult.new("The next player is not in this game.")
	if next_player_id == active_player_id:
		return GameActionResult.new("The next turn must belong to a different player.")

	_start_reinforcement_turn(next_player_id)
	return GameActionResult.new()


func _game_over_error() -> String:
	if winner_id.is_empty():
		return ""
	return "The game is over."


func _check_for_winner() -> void:
	if not winner_id.is_empty():
		return

	for player: GamePlayer in players:
		var has_opponents := false
		var opponents_have_units := false
		var opponents_centers_occupied := true
		for opponent: GamePlayer in players:
			if opponent.id == player.id:
				continue
			has_opponents = true
			var opponent_center := find_city(opponent.center_of_gravity_city_id)
			if (
				opponent_center == null
				or opponent_center.owner_id != player.id
				or opponent_center.unit_count <= 0
			):
				opponents_centers_occupied = false
			for city: GameCity in cities:
				if city.owner_id == opponent.id and city.unit_count > 0:
					opponents_have_units = true

		if has_opponents and not opponents_have_units and opponents_centers_occupied:
			winner_id = player.id
			return


func _advance_initial_reserve_placement() -> void:
	var all_reserves_placed := true
	for player: GamePlayer in players:
		if reserves_remaining_by_player_id[player.id] > 0:
			all_reserves_placed = false
			break

	if all_reserves_placed:
		phase = Phase.ACTIVE_PLAY
		active_player_id = ""
		return

	for player: GamePlayer in players:
		if player.id != active_player_id and reserves_remaining_by_player_id[player.id] > 0:
			active_player_id = player.id
			return


func _validate_reinforcement_map(map_definition: GameMapDefinition) -> bool:
	for player: GamePlayer in players:
		if player.center_of_gravity_city_id.is_empty():
			return false
		if map_definition.find_city(player.center_of_gravity_city_id) == null:
			return false
		if find_city(player.center_of_gravity_city_id) == null:
			return false
	for connection: MapConnection in map_definition.connections:
		if map_definition.find_city(connection.from_city_id) == null:
			return false
		if map_definition.find_city(connection.to_city_id) == null:
			return false
		if find_city(connection.from_city_id) == null or find_city(connection.to_city_id) == null:
			return false
	return true


func _start_reinforcement_turn(player_id: String) -> void:
	phase = Phase.REINFORCEMENT_PLACEMENT
	active_player_id = player_id
	reinforcements_remaining = 0

	var player := find_player(player_id)
	var center_of_gravity := find_city(player.center_of_gravity_city_id)
	if center_of_gravity.owner_id != player_id:
		return

	var owned_city_count := 0
	for city: GameCity in cities:
		if city.owner_id == player_id:
			owned_city_count += 1
	reinforcements_remaining = floori(
		float(owned_city_count) / float(CITIES_PER_REINFORCEMENT)
	)


func _get_reinforcement_reachable_city_ids(player_id: String) -> Dictionary:
	var player := find_player(player_id)
	if player == null:
		return {}
	var center_of_gravity := find_city(player.center_of_gravity_city_id)
	if center_of_gravity == null or center_of_gravity.owner_id != player_id:
		return {}

	var reachable_city_ids: Dictionary = {center_of_gravity.id: true}
	var city_ids_to_visit: Array[String] = [center_of_gravity.id]
	var visit_index := 0
	while visit_index < city_ids_to_visit.size():
		var current_city_id := city_ids_to_visit[visit_index]
		visit_index += 1
		for connection: MapConnection in _map_definition.connections:
			var neighbor_city_id := ""
			if connection.from_city_id == current_city_id:
				neighbor_city_id = connection.to_city_id
			elif connection.to_city_id == current_city_id:
				neighbor_city_id = connection.from_city_id
			if neighbor_city_id.is_empty() or reachable_city_ids.has(neighbor_city_id):
				continue

			var neighbor_city := find_city(neighbor_city_id)
			if neighbor_city.owner_id != player_id:
				continue
			reachable_city_ids[neighbor_city_id] = true
			city_ids_to_visit.append(neighbor_city_id)
	return reachable_city_ids


func _has_controlled_route(first_city_id: String, second_city_id: String) -> bool:
	if _map_definition == null:
		return false

	var visited_city_ids: Dictionary = {first_city_id: true}
	var city_ids_to_visit: Array[String] = [first_city_id]
	var visit_index := 0
	while visit_index < city_ids_to_visit.size():
		var current_city_id := city_ids_to_visit[visit_index]
		visit_index += 1
		for connection: MapConnection in _map_definition.connections:
			var neighbor_city_id := ""
			if connection.from_city_id == current_city_id:
				neighbor_city_id = connection.to_city_id
			elif connection.to_city_id == current_city_id:
				neighbor_city_id = connection.from_city_id
			if neighbor_city_id.is_empty() or visited_city_ids.has(neighbor_city_id):
				continue

			var neighbor_city := find_city(neighbor_city_id)
			if neighbor_city.owner_id != active_player_id or neighbor_city.unit_count <= 0:
				continue
			if neighbor_city_id == second_city_id:
				return true
			visited_city_ids[neighbor_city_id] = true
			city_ids_to_visit.append(neighbor_city_id)
	return false


func _are_cities_connected(first_city_id: String, second_city_id: String) -> bool:
	if _map_definition == null:
		return false
	for connection: MapConnection in _map_definition.connections:
		if (
			connection.from_city_id == first_city_id
			and connection.to_city_id == second_city_id
		):
			return true
		if (
			connection.from_city_id == second_city_id
			and connection.to_city_id == first_city_id
		):
			return true
	return false
