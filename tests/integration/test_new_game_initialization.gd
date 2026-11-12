extends SceneTree

const GameApplicationScript = preload("res://scripts/application/game_application.gd")
const GameSetupScript = preload("res://scripts/domain/game_setup.gd")

var _failures: int = 0


func _initialize() -> void:
	var random_generator := RandomNumberGenerator.new()
	random_generator.seed = 1914
	var application: GameApplication = GameApplicationScript.new(random_generator)
	var premature_placement: GameActionResult = application.place_initial_reserve("paris")
	_expect(
		not premature_placement.succeeded(),
		"Reserves cannot be placed before a new game has been initialized."
	)
	var result: GameStartResult = application.start_new_game(
		"Allied commander",
		"German commander"
	)
	_expect(result.succeeded(), "A new game should succeed when both leaders are named.")
	var state: GameViewSnapshot = application.get_view_snapshot()
	_expect(state.players.size() == 2, "A new game should initialize both players.")
	var independent_snapshot: GameViewSnapshot = application.get_view_snapshot()
	independent_snapshot.find_city("paris").unit_count = 17
	_expect(
		application.get_view_snapshot().find_city("paris").unit_count == 1,
		"Changing a view snapshot must not modify authoritative game state."
	)
	_expect(
		state.cities.size() == 32,
		"The map should define all 32 cities."
	)
	_expect(
		state.connections.size() == 59,
		"The map should expose all 59 CSV-backed road connections."
	)
	_expect(
		state.find_city("hasselt") != null and state.find_city("meaux") == null,
		"The game should use the current CSV city set."
	)
	_expect(
		is_equal_approx(state.find_city("paris").latitude, 48.857)
		and is_equal_approx(state.find_city("paris").longitude, 2.357),
		"City snapshots should expose geographic coordinates."
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
		state.find_city("paris").is_center_of_gravity,
		"Paris should be marked as a COG in the map."
	)
	_expect(
		state.find_city("koblenz").is_center_of_gravity,
		"Koblenz should be marked as a COG in the map."
	)
	var allies_count := 0
	var german_count := 0
	for city: GameViewSnapshot.CityView in state.cities:
		if city.owner_id == "allies":
			allies_count += 1
		elif city.owner_id == "german_empire":
			german_count += 1
	_expect(allies_count == 16, "The Allies should have a balanced starting territory count.")
	_expect(german_count == 16, "The German Empire should have a balanced starting territory count.")
	_expect(
		state.phase == GameViewSnapshot.Phase.INITIAL_RESERVE_PLACEMENT,
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
		state = application.get_view_snapshot()
	_expect(
		state.phase == GameViewSnapshot.Phase.REINFORCEMENT_PLACEMENT,
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
	for reinforcement_index: int in state.reinforcements_remaining:
		var reinforcement_result: GameActionResult = application.place_reinforcement("koblenz")
		_expect(
			reinforcement_result.succeeded(),
			"Germany should be able to place reinforcements in its COG."
		)
		state = application.get_view_snapshot()
	_expect(
		state.phase == GameViewSnapshot.Phase.ATTACK,
		"Completing reinforcements should begin the same player's attack phase."
	)
	_expect(
		state.active_player_id == "german_empire",
		"Completing reinforcements should not switch the active player."
	)

	var invalid_result: GameStartResult = application.start_new_game(" ", "German commander")
	_expect(not invalid_result.succeeded(), "An empty leader name should prevent game initialization.")
	_expect(
		invalid_result.error_message == "Enter a name for the Allied leader.",
		"Invalid names should return a clear message."
	)

	_test_quick_start_is_deterministic()
	_test_dev_mode_uses_quick_start()

	if _failures == 0:
		print("New game initialization integration tests passed.")
	quit(1 if _failures > 0 else 0)


func _test_quick_start_is_deterministic() -> void:
	var first_random_generator := RandomNumberGenerator.new()
	first_random_generator.seed = 2718
	var first_application: GameApplication = GameApplicationScript.new(first_random_generator)
	var first_result: GameStartResult = first_application.start_quick_game()
	_expect(first_result.succeeded(), "Quick start should initialize successfully.")
	if not first_result.succeeded():
		return

	var second_random_generator := RandomNumberGenerator.new()
	second_random_generator.seed = 2718
	var second_application: GameApplication = GameApplicationScript.new(second_random_generator)
	var second_result: GameStartResult = second_application.start_quick_game()
	_expect(second_result.succeeded(), "A second seeded quick start should initialize.")
	if not second_result.succeeded():
		return

	var first_state: GameViewSnapshot = first_application.get_view_snapshot()
	var second_state: GameViewSnapshot = second_application.get_view_snapshot()
	_expect(first_state.players[0].name == "Joffre", "Quick start should name the Allies Joffre.")
	_expect(first_state.players[1].name == "Moltke", "Quick start should name Germany Moltke.")
	_expect(
		first_state.phase == GameViewSnapshot.Phase.REINFORCEMENT_PLACEMENT,
		"Quick start should finish both players' reserve placement."
	)
	_expect(
		first_state.active_player_id == "german_empire",
		"Quick start should begin the first German reinforcement phase."
	)
	var total_units := 0
	var allies_units := 0
	var german_units := 0
	for first_city: GameViewSnapshot.CityView in first_state.cities:
		var second_city := second_state.find_city(first_city.id)
		total_units += first_city.unit_count
		if first_city.owner_id == "allies":
			allies_units += first_city.unit_count
		else:
			german_units += first_city.unit_count
		_expect(
			first_city.owner_id == "allies" or first_city.owner_id == "german_empire",
			"Random reserve placement must preserve city ownership."
		)
		_expect(
			first_city.owner_id == second_city.owner_id
			and first_city.unit_count == second_city.unit_count,
			"Quick start should produce the same setup from the same random seed."
		)
	_expect(total_units == 42, "Quick start should place exactly ten reserve units.")
	_expect(allies_units == 21, "Quick start should place five reserves for the Allies.")
	_expect(german_units == 21, "Quick start should place five reserves for Germany.")


func _test_dev_mode_uses_quick_start() -> void:
	var dev_random_generator := RandomNumberGenerator.new()
	dev_random_generator.seed = 3141
	var dev_application: GameApplication = GameApplicationScript.new(dev_random_generator)
	var unauthorized_result := dev_application.change_city_owner_for_development("paris")
	_expect(
		not unauthorized_result.succeeded(),
		"Developer ownership changes must be rejected before starting dev mode."
	)
	_expect(
		not dev_application.add_units_for_development("paris", 1).succeeded(),
		"Developer unit additions must be rejected before starting dev mode."
	)
	_expect(
		not dev_application.remove_units_for_development("paris", 1).succeeded(),
		"Developer unit removals must be rejected before starting dev mode."
	)
	_expect(
		dev_application.can_start_dev_mode == OS.is_debug_build(),
		"Dev-mode availability should follow the current build's debug status."
	)
	var dev_result: GameStartResult = dev_application.start_dev_mode_game()
	if not OS.is_debug_build():
		_expect(not dev_result.succeeded(), "Release builds must reject developer-mode startup.")
		_expect(
			not dev_application.is_dev_mode_active(),
			"Rejected startup must not activate developer mode."
		)
		return

	_expect(dev_result.succeeded(), "Debug builds should allow developer-mode startup.")
	if not dev_result.succeeded():
		return
	_expect(dev_application.is_dev_mode_active(), "Successful dev startup should activate dev mode.")

	var quick_random_generator := RandomNumberGenerator.new()
	quick_random_generator.seed = 3141
	var quick_application: GameApplication = GameApplicationScript.new(quick_random_generator)
	var quick_result: GameStartResult = quick_application.start_quick_game()
	_expect(quick_result.succeeded(), "Quick start should succeed for comparison.")
	if not quick_result.succeeded():
		return

	var dev_state: GameViewSnapshot = dev_application.get_view_snapshot()
	var quick_state: GameViewSnapshot = quick_application.get_view_snapshot()
	_expect(
		dev_state.phase == quick_state.phase
		and dev_state.active_player_id == quick_state.active_player_id,
		"Dev mode should use the same starting phase and player as quick start."
	)
	_expect(
		dev_state.players[0].name == quick_state.players[0].name
		and dev_state.players[1].name == quick_state.players[1].name,
		"Dev mode should use the same players as quick start."
	)
	for city: GameViewSnapshot.CityView in dev_state.cities:
		var quick_city := quick_state.find_city(city.id)
		_expect(
			city.owner_id == quick_city.owner_id and city.unit_count == quick_city.unit_count,
			"Dev mode should use the same initial city state as quick start."
		)

	var paris := dev_state.find_city("paris")
	var original_paris_units := paris.unit_count
	var ownership_result := dev_application.change_city_owner_for_development("paris")
	_expect(
		ownership_result.succeeded(),
		"Developer mode should allow changing ownership through the application."
	)
	_expect(
		dev_application.get_view_snapshot().find_city("paris").owner_id == "german_empire",
		"Developer ownership changes should assign the other player's ID."
	)
	_expect(
		dev_application.get_view_snapshot().find_city("paris").unit_count == original_paris_units,
		"Developer ownership changes must preserve garrison size."
	)
	var add_units_result := dev_application.add_units_for_development("paris", 3)
	_expect(add_units_result.succeeded(), "Dev mode should add units through the application.")
	_expect(
		dev_application.get_view_snapshot().find_city("paris").unit_count == original_paris_units + 3,
		"Application unit addition should update the authoritative garrison."
	)
	var remove_units_result := dev_application.remove_units_for_development("paris", 2)
	_expect(
		remove_units_result.succeeded(),
		"Dev mode should remove units through the application."
	)
	_expect(
		dev_application.get_view_snapshot().find_city("paris").unit_count == original_paris_units + 1,
		"Application unit removal should update the authoritative garrison."
	)

	var normal_start_result := dev_application.start_quick_game()
	_expect(normal_start_result.succeeded(), "Normal quick start should remain available.")
	_expect(
		not dev_application.is_dev_mode_active(),
		"Starting a normal game should deactivate developer mode."
	)
	var disabled_result := dev_application.change_city_owner_for_development("paris")
	_expect(
		not disabled_result.succeeded(),
		"Developer ownership changes must be rejected in a normal game."
	)
	_expect(
		not dev_application.add_units_for_development("paris", 1).succeeded(),
		"Developer unit additions must be rejected in a normal game."
	)
	_expect(
		not dev_application.remove_units_for_development("paris", 1).succeeded(),
		"Developer unit removals must be rejected in a normal game."
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
