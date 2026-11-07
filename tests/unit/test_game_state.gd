extends SceneTree

const GamePlayerScript = preload("res://scripts/domain/player.gd")
const GameCityScript = preload("res://scripts/domain/city.gd")
const GameStateScript = preload("res://scripts/domain/game_state.gd")

var _failures: int = 0


func _initialize() -> void:
	var player: GamePlayer = GamePlayerScript.new("allies", "Allies", "paris")
	var city: GameCity = GameCityScript.new("paris", player.id, 1)
	var players: Array[GamePlayer] = [player]
	var cities: Array[GameCity] = [city]
	var state: GameState = GameStateScript.new(players, cities)

	_expect(player is RefCounted, "Player should be a non-Node domain object.")
	_expect(city is RefCounted, "City should be a non-Node domain object.")
	_expect(state is RefCounted, "GameState should be a non-Node domain object.")
	_expect(
		state.get_class() == "RefCounted",
		"GameState should use the non-Node RefCounted base."
	)
	_expect(state.players.size() == 1, "GameState should retain its players.")
	_expect(state.cities.size() == 1, "GameState should retain its cities.")
	_expect(
		state.cities[0].owner_id == player.id,
		"City ownership should be represented by player ID."
	)
	_expect(state.cities[0].unit_count == 1, "City should retain its initial unit count.")
	_expect(state.cities[0].id == "paris", "City state should identify the corresponding map city.")

	if _failures == 0:
		print("GameState unit tests passed.")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
