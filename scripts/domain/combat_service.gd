class_name CombatService
extends RefCounted

const DIE_MINIMUM := 1
const DIE_MAXIMUM := 6

var _random_generator: RandomNumberGenerator


func _init(random_generator: RandomNumberGenerator) -> void:
	_random_generator = random_generator


func resolve_round(
	attacker_commitment: int,
	defender_commitment: int
) -> CombatRoundResult:
	assert(attacker_commitment > 0)
	assert(defender_commitment > 0)

	var attacker_rolls := _roll_dice(attacker_commitment)
	var defender_rolls := _roll_dice(defender_commitment)
	attacker_rolls.sort()
	attacker_rolls.reverse()
	defender_rolls.sort()
	defender_rolls.reverse()

	var attacker_losses := 0
	var defender_losses := 0
	var comparisons := mini(attacker_rolls.size(), defender_rolls.size())
	for index: int in comparisons:
		if attacker_rolls[index] > defender_rolls[index]:
			defender_losses += 1
		else:
			attacker_losses += 1

	return CombatRoundResult.new(
		attacker_rolls,
		defender_rolls,
		attacker_losses,
		defender_losses
	)


func _roll_dice(count: int) -> Array[int]:
	var rolls: Array[int] = []
	for die_index: int in count:
		rolls.append(_random_generator.randi_range(DIE_MINIMUM, DIE_MAXIMUM))
	return rolls
