class_name GameViewSnapshot
extends RefCounted

enum Phase {
	INITIAL_RESERVE_PLACEMENT,
	ACTIVE_PLAY,
	REINFORCEMENT_PLACEMENT,
	ATTACK,
	REORGANIZATION,
}

class PlayerView:
	extends RefCounted

	var id: String
	var name: String
	var center_of_gravity_city_id: String
	var reserves_remaining: int


class CityView:
	extends RefCounted

	var id: String
	var name: String
	var latitude: float
	var longitude: float
	var is_center_of_gravity: bool
	var owner_id: String
	var owner_name: String
	var last_owner_name: String
	var unit_count: int


class ConnectionView:
	extends RefCounted

	var from_city_id: String
	var to_city_id: String


var players: Array[PlayerView] = []
var cities: Array[CityView] = []
var connections: Array[ConnectionView] = []
var phase: Phase
var active_player_id: String
var active_player_name: String
var reinforcements_remaining: int
var winner_id: String
var winner_name: String
var dev_mode_active: bool
var max_development_garrison_size: int


func find_player(player_id: String) -> PlayerView:
	for player: PlayerView in players:
		if player.id == player_id:
			return player
	return null


func find_city(city_id: String) -> CityView:
	for city: CityView in cities:
		if city.id == city_id:
			return city
	return null
