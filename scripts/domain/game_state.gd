class_name GameState
extends RefCounted

enum Phase {
	INITIAL_RESERVE_PLACEMENT,
	ACTIVE_PLAY,
	REINFORCEMENT_PLACEMENT,
}

const CITIES_PER_REINFORCEMENT := 5

var players: Array[GamePlayer]
var cities: Array[GameCity]
var phase: Phase
var active_player_id: String
var reserves_remaining_by_player_id: Dictionary
var reinforcements_remaining: int = 0
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


func place_initial_reserve(city_id: String) -> GameActionResult:
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

	city.add_units(1)
	reserves_remaining_by_player_id[active_player_id] = reserves_remaining - 1
	_advance_initial_reserve_placement()
	return GameActionResult.new()


func begin_reinforcement_turn(
	map_definition: GameMapDefinition,
	first_player_id: String
) -> GameActionResult:
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

	city.add_units(1)
	reinforcements_remaining -= 1
	if reinforcements_remaining == 0:
		_start_reinforcement_turn(_get_next_player_id())
	return GameActionResult.new()


func skip_reinforcement_turn() -> GameActionResult:
	if phase != Phase.REINFORCEMENT_PLACEMENT:
		return GameActionResult.new("Reinforcement placement is not in progress.")
	if reinforcements_remaining > 0:
		return GameActionResult.new("All reinforcements must be placed before passing the turn.")

	_start_reinforcement_turn(_get_next_player_id())
	return GameActionResult.new()


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


func _get_next_player_id() -> String:
	var active_player_index := -1
	for index: int in players.size():
		if players[index].id == active_player_id:
			active_player_index = index
			break
	assert(active_player_index >= 0)
	return players[(active_player_index + 1) % players.size()].id
