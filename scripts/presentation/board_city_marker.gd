class_name BoardCityMarker
extends Button


func configure(
	city: GameViewSnapshot.CityView,
	owner_name: String,
	owner_color: Color
) -> void:
	var city_name := city.name
	if city.is_center_of_gravity:
		city_name += " (COG)"
	var unit_label := "unit" if city.unit_count == 1 else "units"
	text = "%s\n%s - %d %s" % [city_name, owner_name, city.unit_count, unit_label]
	tooltip_text = city.name
	toggle_mode = true
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(86, 48)
	add_theme_font_size_override("font_size", 9)

	var normal_style := _create_style(owner_color, Color(0.85, 0.88, 0.94), 2)
	var hover_style := _create_style(owner_color.lightened(0.15), Color(0.85, 0.88, 0.94), 2)
	var selected_style := _create_style(owner_color, Color(1.0, 0.82, 0.2), 4)
	add_theme_stylebox_override("normal", normal_style)
	add_theme_stylebox_override("hover", hover_style)
	add_theme_stylebox_override("pressed", selected_style)
	add_theme_stylebox_override("focus", selected_style)
	add_theme_color_override("font_color", Color.WHITE)
	add_theme_color_override("font_hover_color", Color.WHITE)
	add_theme_color_override("font_pressed_color", Color.WHITE)


func _create_style(
	background_color: Color,
	outline_color: Color,
	outline_width: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = outline_color
	style.set_border_width_all(outline_width)
	style.set_corner_radius_all(8)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style
