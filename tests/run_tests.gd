extends SceneTree

const SCENE_TREE_TESTS: Array[String] = [
	"res://tests/unit/test_attack_phase.gd",
	"res://tests/unit/test_combat_service.gd",
	"res://tests/unit/test_dev_city_ownership.gd",
	"res://tests/unit/test_game_map_definition.gd",
	"res://tests/unit/test_game_end_conditions.gd",
	"res://tests/unit/test_game_setup.gd",
	"res://tests/unit/test_game_state.gd",
	"res://tests/unit/test_initial_reserve_placement.gd",
	"res://tests/unit/test_reorganization.gd",
	"res://tests/unit/test_reinforcement_placement.gd",
	"res://tests/integration/test_new_game_initialization.gd",
	"res://tests/integration/test_complete_game_flow.gd",
	"res://tests/integration/test_turn_progression.gd",
]
const PRESENTATION_TEST_SCENE := "res://tests/integration/test_main_screen_runner.tscn"


func _initialize() -> void:
	var failed_tests: Array[String] = []
	for test_path: String in SCENE_TREE_TESTS:
		if not _run_godot_test(test_path, "--script", test_path):
			failed_tests.append(test_path)
	if not _run_godot_test(
		PRESENTATION_TEST_SCENE,
		"--scene",
		PRESENTATION_TEST_SCENE
	):
		failed_tests.append(PRESENTATION_TEST_SCENE)

	if failed_tests.is_empty():
		print("All Godot tests passed.")
	else:
		push_error("Godot tests failed: %s" % ", ".join(failed_tests))
	quit(1 if not failed_tests.is_empty() else 0)


func _run_godot_test(test_name: String, run_mode: String, target: String) -> bool:
	print("Running %s..." % test_name)
	var output: Array = []
	var arguments := PackedStringArray([
		"--headless",
		"--path",
		ProjectSettings.globalize_path("res://"),
		run_mode,
		target,
	])
	var exit_code := OS.execute(OS.get_executable_path(), arguments, output, true)
	for output_line: String in output:
		print(output_line)
	if exit_code != 0:
		push_error("%s failed with exit code %d." % [test_name, exit_code])
		return false
	print("%s passed." % test_name)
	return true
