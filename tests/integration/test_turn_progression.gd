extends SceneTree

const GameApplicationScript = preload("res://scripts/application/game_application.gd")

var _failures: int = 0


func _initialize() -> void:
	var random_generator := RandomNumberGenerator.new()
	random_generator.seed = 1914
	var application: GameApplication = GameApplicationScript.new(random_generator)
	var start_result := application.start_quick_game()
	_expect(start_result.succeeded(), "Quick start should initialize a game.")
	if not start_result.succeeded():
		quit(1)
		return

	var state := start_result.game_state
	_complete_current_turn(application, state)
	_expect(
		state.phase == GameState.Phase.REINFORCEMENT_PLACEMENT,
		"The opposing player should begin reinforcement placement after reorganization."
	)
	_expect(
		state.active_player_id == "allies",
		"The Allies should follow Germany's opening turn."
	)
	_expect(
		state.reinforcements_remaining == 3,
		"The next player's reinforcements should reflect their territory count."
	)

	_complete_current_turn(application, state)
	_expect(
		state.phase == GameState.Phase.REINFORCEMENT_PLACEMENT,
		"Turn progression should continue after both players complete a turn."
	)
	_expect(
		state.active_player_id == "german_empire",
		"Turn progression should return to Germany."
	)

	if _failures == 0:
		print("Turn progression integration tests passed.")
	quit(1 if _failures > 0 else 0)


func _complete_current_turn(application: GameApplication, state: GameState) -> void:
	while state.reinforcements_remaining > 0:
		var active_player := state.find_player(state.active_player_id)
		var placement_result := application.place_reinforcement(
			active_player.center_of_gravity_city_id
		)
		_expect(placement_result.succeeded(), "The active player should place each reinforcement.")

	if state.phase == GameState.Phase.REINFORCEMENT_PLACEMENT:
		var begin_attack_result := application.begin_attack_phase()
		_expect(begin_attack_result.succeeded(), "The active player should begin attacks.")
	var end_attack_result := application.end_attack_phase()
	_expect(end_attack_result.succeeded(), "The active player should finish the attack phase.")
	var end_reorganization_result := application.end_reorganization_phase()
	_expect(
		end_reorganization_result.succeeded(),
		"The active player should finish reorganization and advance the turn."
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
