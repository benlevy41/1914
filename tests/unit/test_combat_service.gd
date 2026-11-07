extends SceneTree

const CombatServiceScript = preload("res://scripts/domain/combat_service.gd")

var _failures: int = 0


func _initialize() -> void:
	var random_generator := RandomNumberGenerator.new()
	random_generator.seed = 1914
	var combat_service: CombatService = CombatServiceScript.new(random_generator)
	var result: CombatRoundResult = combat_service.resolve_round(3, 2)

	print(
		"Seeded combat rolls: attacker %s, defender %s; losses %d/%d."
		% [
			str(result.attacker_rolls),
			str(result.defender_rolls),
			result.attacker_losses,
			result.defender_losses,
		]
	)
	_expect(result.succeeded(), "A valid combat round should succeed.")
	_expect(result.attacker_rolls.size() == 3, "Each attacking unit should roll once.")
	_expect(result.defender_rolls.size() == 2, "Each defending unit should roll once.")
	_expect(
		result.attacker_rolls == [5, 5, 1],
		"Seeded attacker dice should be reproducible and sorted high to low."
	)
	_expect(
		result.defender_rolls == [5, 3],
		"Seeded defender dice should be reproducible and sorted high to low."
	)
	_expect(result.attacker_losses == 1, "A tie should be a loss for the attacker.")
	_expect(result.defender_losses == 1, "A higher attacker roll should defeat one defender.")
	_expect(result.attacker_losses + result.defender_losses == 2, "Compare paired dice only.")
	for roll: int in result.attacker_rolls + result.defender_rolls:
		_expect(roll >= 1 and roll <= 6, "Each combat die should be a standard d6.")

	if _failures == 0:
		print("Combat service unit tests passed.")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
