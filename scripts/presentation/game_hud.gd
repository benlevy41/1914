class_name GameHUD
extends PanelContainer

const ALLIED_FLAG = preload("res://assets/ui/allied_flag.svg")
const GERMAN_FLAG = preload("res://assets/ui/german_empire_flag.svg")

@onready var _allies_name: Label = $Content/Allies/Name
@onready var _allies_stats: Label = $Content/Allies/Stats
@onready var _germany_name: Label = $Content/Germany/Name
@onready var _germany_stats: Label = $Content/Germany/Stats
@onready var _flag: TextureRect = $Content/Center/Flag
@onready var _active: Label = $Content/Center/Info/Active
@onready var _phase: Label = $Content/Center/Info/Phase
@onready var _dev_indicator: Label = $Content/Center/Info/DevModeIndicator


func update_snapshot(snapshot: GameViewSnapshot) -> void:
	var allies := snapshot.find_player("allies")
	var germany := snapshot.find_player("german_empire")
	if allies == null or germany == null:
		push_error("The game HUD requires both Allied and German players.")
		return
	_allies_name.text = "Allies - %s" % allies.name
	_allies_name.tooltip_text = _allies_name.text
	_germany_name.text = "German Empire - %s" % germany.name
	_germany_name.tooltip_text = _germany_name.text
	var allies_cities := 0
	var allies_units := 0
	var german_cities := 0
	var german_units := 0
	for city: GameViewSnapshot.CityView in snapshot.cities:
		if city.owner_id == "allies":
			allies_cities += 1
			allies_units += city.unit_count
		elif city.owner_id == "german_empire":
			german_cities += 1
			german_units += city.unit_count
	_allies_stats.text = "Cities: %d  |  Units: %d" % [allies_cities, allies_units]
	_germany_stats.text = "Cities: %d  |  Units: %d" % [german_cities, german_units]
	_dev_indicator.visible = snapshot.dev_mode_active

	var displayed_id := snapshot.active_player_id
	if not snapshot.winner_id.is_empty():
		displayed_id = snapshot.winner_id
		_active.text = "Winner: %s" % snapshot.winner_name
		_phase.text = "Game over"
	else:
		_active.text = "Turn: %s" % snapshot.active_player_name
		_phase.text = _phase_description(snapshot)
	if displayed_id == "allies":
		_flag.texture = ALLIED_FLAG
		_flag.tooltip_text = "Allied forces"
	elif displayed_id == "german_empire":
		_flag.texture = GERMAN_FLAG
		_flag.tooltip_text = "German Empire"
	else:
		push_error("The game HUD cannot display unknown player '%s'." % displayed_id)


func _phase_description(snapshot: GameViewSnapshot) -> String:
	match snapshot.phase:
		GameViewSnapshot.Phase.INITIAL_RESERVE_PLACEMENT:
			var player := snapshot.find_player(snapshot.active_player_id)
			if player == null:
				push_error("The game HUD cannot find the active player.")
				return ""
			return "Setup - %d reserves remaining" % player.reserves_remaining
		GameViewSnapshot.Phase.ACTIVE_PLAY:
			return "Setup complete"
		GameViewSnapshot.Phase.REINFORCEMENT_PLACEMENT:
			return "Reinforcement - %d remaining" % snapshot.reinforcements_remaining
		GameViewSnapshot.Phase.ATTACK:
			return "Attack phase"
		GameViewSnapshot.Phase.REORGANIZATION:
			return "Reorganization phase"
	push_error("The game HUD cannot display an unknown phase.")
	return ""
