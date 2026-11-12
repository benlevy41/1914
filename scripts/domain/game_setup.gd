class_name GameSetup
extends RefCounted

const ALLIES_ID := "allies"
const GERMAN_EMPIRE_ID := "german_empire"
const ALLIES_COG_ID := "paris"
const GERMAN_EMPIRE_COG_ID := "koblenz"
const INITIAL_CITY_UNIT_COUNT := 1
const INITIAL_RESERVES_PER_PLAYER := 5
const INITIAL_RESERVE_PLACEMENT_PLAYER_ID := GERMAN_EMPIRE_ID


static func create_initial_state(
	map_definition: GameMapDefinition,
	allies: GamePlayer,
	german_empire: GamePlayer,
	random_generator: RandomNumberGenerator
) -> GameState:
	assert(allies.id == ALLIES_ID)
	assert(german_empire.id == GERMAN_EMPIRE_ID)
	assert(allies.center_of_gravity_city_id == ALLIES_COG_ID)
	assert(german_empire.center_of_gravity_city_id == GERMAN_EMPIRE_COG_ID)
	assert(map_definition.cities.size() == 32)
	assert(map_definition.cities.size() % 2 == 0)
	assert(map_definition.find_city(ALLIES_COG_ID) != null)
	assert(map_definition.find_city(GERMAN_EMPIRE_COG_ID) != null)

	var unassigned_city_ids: Array[String] = []
	for city_definition: MapCityDefinition in map_definition.cities:
		if city_definition.id != ALLIES_COG_ID and city_definition.id != GERMAN_EMPIRE_COG_ID:
			unassigned_city_ids.append(city_definition.id)

	for index: int in range(
		unassigned_city_ids.size() - 1,
		0,
		-1
	):  # random shuffle of unoccupied cities
		var swap_index := random_generator.randi_range(0, index)
		var city_id := unassigned_city_ids[index]
		unassigned_city_ids[index] = unassigned_city_ids[swap_index]
		unassigned_city_ids[swap_index] = city_id

	var ownership_by_city_id: Dictionary = {
		ALLIES_COG_ID: allies.id,
		GERMAN_EMPIRE_COG_ID: german_empire.id,
	}
	var cities_per_player: int = unassigned_city_ids.size() / 2
	for index: int in unassigned_city_ids.size():
		var owner_id := allies.id if index < cities_per_player else german_empire.id
		ownership_by_city_id[unassigned_city_ids[index]] = owner_id

	var cities: Array[GameCity] = []
	for city_definition: MapCityDefinition in map_definition.cities:
		cities.append(
			GameCity.new(
				city_definition.id,
				ownership_by_city_id[city_definition.id],
				INITIAL_CITY_UNIT_COUNT
			)
		)

	return GameState.new(
		[allies, german_empire],
		cities,
		INITIAL_RESERVES_PER_PLAYER,
		INITIAL_RESERVE_PLACEMENT_PLAYER_ID
	)
