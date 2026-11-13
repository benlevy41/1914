extends Control

const DISPLAY_SECONDS := 3.0
const FEEDBACK_COLORS := {
	"allies": Color(0.35, 0.65, 1.0),
	"german_empire": Color(1.0, 0.35, 0.30),
}

var _board: BoardView
var _city_ids: Array[String] = []
var _labels: Array[Label] = []
var _remaining: float = 0.0
var _summary: Label


func _ready() -> void:
	name = "CombatFeedback"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board = get_parent() as BoardView
	for index: int in 2:
		var label := Label.new()
		label.name = "AttackerLosses" if index == 0 else "DefenderLosses"
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 28)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 5)
		label.hide()
		add_child(label)
		_labels.append(label)


func attach_summary(sidebar: Container) -> void:
	_summary = Label.new()
	_summary.name = "LastCombatResult"
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.hide()
	sidebar.add_child(_summary)


func describe_result(result: CombatRoundResult) -> String:
	return "Attacker rolls %s; defender rolls %s. Losses: attacker %d, defender %d." % [
		str(result.attacker_rolls), str(result.defender_rolls),
		result.attacker_losses, result.defender_losses,
	]


func show_result(
	result: CombatRoundResult, before: GameViewSnapshot, source_id: String, target_id: String
) -> void:
	var source := before.find_city(source_id)
	var target := before.find_city(target_id)
	if source == null or target == null:
		push_error("Cannot show combat feedback without both cities.")
		return
	_summary.text = "Last combat: %s vs %s. %s" % [
		source.name, target.name, describe_result(result)
	]
	if result.units_advanced > 0:
		_summary.text += " %s captured; %d %s advanced." % [
			target.name, result.units_advanced, "unit" if result.units_advanced == 1 else "units"
		]
	_summary.show()
	var source_owner := source.owner_id
	var target_owner := target.owner_id
	if not FEEDBACK_COLORS.has(source_owner) or not FEEDBACK_COLORS.has(target_owner):
		push_error("Cannot show combat losses without colors for both players.")
		return
	_city_ids = [source_id, target_id]
	_labels[0].text = "-%d" % result.attacker_losses
	_labels[1].text = "-%d" % result.defender_losses
	_labels[0].add_theme_color_override("font_color", FEEDBACK_COLORS[source_owner])
	_labels[1].add_theme_color_override("font_color", FEEDBACK_COLORS[target_owner])
	_remaining = DISPLAY_SECONDS
	_update_positions()


func _process(delta: float) -> void:
	if _remaining <= 0.0:
		return
	_remaining -= delta
	if _remaining <= 0.0:
		for label: Label in _labels:
			label.hide()
		return
	_update_positions()


func _update_positions() -> void:
	for index: int in _labels.size():
		var projected: Variant = _board.get_city_screen_position(_city_ids[index])
		if projected == null:
			_labels[index].hide()
			continue
		var local_position: Vector2 = get_global_transform_with_canvas().affine_inverse() * projected
		var label := _labels[index]
		label.size = label.get_combined_minimum_size()
		label.position = local_position + Vector2(
			-label.size.x - 8.0 if index == 0 else 8.0, -label.size.y - 12.0
		)
		label.show()
