extends SceneTree

const GameCityScript = preload("res://scripts/domain/city.gd")
const GamePlayerScript = preload("res://scripts/domain/player.gd")
const GameSetupScript = preload("res://scripts/domain/game_setup.gd")
const GameStateScript = preload("res://scripts/domain/game_state.gd")

var _failures: int = 0


func _initialize() -> void:
	var allies: GamePlayer = GamePlayerScript.new("allies", "Allied leader", "paris")
	var german_empire: GamePlayer = GamePlayerScript.new("german_empire", "German leader", "koblenz")
	var cities: Array[GameCity] = [
		GameCityScript.new("allies_city", allies.id, 1),
		GameCityScript.new("german_city_a", german_empire.id, 1),
		GameCityScript.new("german_city_b", german_empire.id, 1),
	]
	var state: GameState = GameStateScript.new(
		[allies, german_empire],
		cities,
		GameSetupScript.INITIAL_RESERVES_PER_PLAYER,
		GameSetupScript.INITIAL_RESERVE_PLACEMENT_PLAYER_ID
	)
	var initial_reserves_per_player: int = GameSetupScript.INITIAL_RESERVES_PER_PLAYER

	_expect(
		state.phase == GameState.Phase.INITIAL_RESERVE_PLACEMENT,
		"Initial reserves should have their own game phase."
	)
	_expect(
		state.active_player_id == german_empire.id,
		"The German Empire should place the first reserve."
	)
	_expect(
		state.reserves_remaining_by_player_id[german_empire.id] == initial_reserves_per_player,
		"Reserve counts should use the centralized initial reserve setting."
	)

	var wrong_owner_validation := state.validate_initial_reserve("allies_city")
	var wrong_owner_result: GameActionResult = state.place_initial_reserve("allies_city")
	_expect(
		not wrong_owner_validation.succeeded()
		and wrong_owner_validation.error_message == wrong_owner_result.error_message,
		"Validation and placement must both reject an opponent-owned city."
	)
	_expect(
		state.find_city("allies_city").unit_count == 1,
		"Rejected placement must not change units."
	)
	_expect(
		state.reserves_remaining_by_player_id[german_empire.id] == initial_reserves_per_player,
		"Rejected placement must not consume a reserve."
	)
	_expect(
		state.active_player_id == german_empire.id,
		"Rejected placement must not advance the placement turn."
	)

	var unknown_city_result: GameActionResult = state.place_initial_reserve("missing_city")
	_expect(not unknown_city_result.succeeded(), "A placement must reference a known city.")
	_expect(
		state.reserves_remaining_by_player_id[german_empire.id] == initial_reserves_per_player,
		"An unknown city must not consume a reserve."
	)

	_expect(
		state.validate_initial_reserve("german_city_b").succeeded()
		and state.find_city("german_city_b").unit_count == 1
		and state.reserves_remaining_by_player_id[german_empire.id] == initial_reserves_per_player
		and state.active_player_id == german_empire.id,
		"Validating a legal placement must not change the game state."
	)
	var first_german_placement: GameActionResult = state.place_initial_reserve("german_city_b")
	_expect(first_german_placement.succeeded(), "An owned city should accept a reserve.")
	_expect(
		state.find_city("german_city_b").unit_count == 2,
		"Placing a reserve should increment the selected city's units."
	)
	_expect(
		state.active_player_id == allies.id,
		"The Allies should take their turn after the first German placement."
	)

	for placement_index: int in range(initial_reserves_per_player * 2 - 1):
		var active_city_id := "allies_city" if state.active_player_id == allies.id else "german_city_a"
		var result: GameActionResult = state.place_initial_reserve(active_city_id)
		_expect(result.succeeded(), "The active player should be able to place on their own city.")

	_expect(
		state.phase == GameState.Phase.ACTIVE_PLAY,
		"Completing both reserve pools should finish initial placement."
	)
	_expect(
		state.active_player_id.is_empty(),
		"No player should remain active after setup placement."
	)
	_expect(
		state.reserves_remaining_by_player_id[allies.id] == 0,
		"All Allied reserves should be placed."
	)
	_expect(
		state.reserves_remaining_by_player_id[german_empire.id] == 0,
		"All German reserves should be placed."
	)
	var placement_after_completion := state.place_initial_reserve("german_city_a")
	_expect(
		not placement_after_completion.succeeded()
		and state.validate_initial_reserve("german_city_a").error_message
		== placement_after_completion.error_message,
		"Validation and placement must reject reserves after setup completes."
	)
	_expect(
		state.find_city("german_city_a").unit_count == 1 + initial_reserves_per_player - 1,
		"Rejected post-setup placement must not change the city."
	)

	var remote_german_city: GameCity = GameCityScript.new("remote_german_city", german_empire.id, 1)
	var isolated_state: GameState = GameStateScript.new(
		[allies, german_empire],
		[remote_german_city],
		1,
		german_empire.id
	)
	_expect(
		isolated_state.place_initial_reserve("remote_german_city").succeeded(),
		"Initial placement should require ownership only, not a road or adjacency."
	)

	if _failures == 0:
		print("Initial reserve placement unit tests passed.")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
