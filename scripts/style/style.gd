extends Node
## Autoload `Style`: applies a [StylePreset] to the whole interface and answers how much to animate.
##
## The Theme is built here from the preset's colors and sizes rather than authored as a .tres, so every
## control picks up a profile's choices without a theme file per preset. Apply once when a profile opens.

signal changed(preset: StylePreset)

signal fonts_changed

var units_per_point: float = 1.0
var text_scale: float = 1.0
## Device-wide accessibility preference, independent of the selected child's profile.
var settings_path: String = "user://accessibility.cfg"

var current: StylePreset = StylePreset.new()

func _ready() -> void:
	var settings: ConfigFile = ConfigFile.new()
	if settings.load(settings_path) == OK:
		text_scale = Typography.text_scale(settings.get_value("text", "scale", 1.0))
	apply(current)

func apply(preset: StylePreset) -> void:
	current = preset
	var theme: Theme = _build_theme(preset)
	get_tree().root.theme = theme
	RenderingServer.set_default_clear_color(preset.background)
	changed.emit(preset)
	fonts_changed.emit()

## 1.0 for full motion, a fraction for reduced, 0.0 for none. Multiply a tween duration by it and skip the
## tween when it is zero.
func motion_scale() -> float:
	match current.motion:
		StylePreset.Motion.REDUCED:
			return 0.4
		StylePreset.Motion.NONE:
			return 0.0
		_:
			return 1.0

func font_px(base: int) -> int:
	return Typography.font_size(base, units_per_point, current.font_scale, text_scale)

## Density and canvas changes update text without resetting room state or speech.
func set_display_metrics(window: Vector2i, canvas: Vector2i, density: float) -> void:
	var units: float = Typography.canvas_units_per_point(window, canvas, density)
	if is_equal_approx(units, units_per_point):
		return
	units_per_point = units
	_refresh_fonts()

func set_text_scale(value: float, persist: bool = false) -> Error:
	var next: float = Typography.text_scale(value)
	if persist:
		var settings: ConfigFile = ConfigFile.new()
		settings.set_value("text", "scale", next)
		var error: Error = settings.save(settings_path)
		if error != OK:
			return error
	if not is_equal_approx(next, text_scale):
		text_scale = next
		_refresh_fonts()
	return OK

func _refresh_fonts() -> void:
	get_tree().root.theme = _build_theme(current)
	fonts_changed.emit()

func _build_theme(preset: StylePreset) -> Theme:
	var theme: Theme = Theme.new()
	theme.default_font_size = font_px(Typography.BODY)
	theme.set_constant("line_spacing", "Label", ceili(font_px(Typography.BODY) * 0.18))
	theme.set_constant("line_spacing", "TextEdit", ceili(font_px(Typography.BODY) * 0.18))
	theme.set_font_size("font_size", "Label", font_px(Typography.BODY))
	theme.set_color("font_color", "Label", preset.text)
	theme.set_font_size("font_size", "Button", font_px(Typography.CONTROL))
	theme.set_font_size("font_size", "LineEdit", font_px(Typography.BODY))
	theme.set_font_size("font_size", "TextEdit", font_px(Typography.BODY))
	theme.set_font_size("font_size", "OptionButton", font_px(Typography.BODY))
	theme.set_font_size("font_size", "ItemList", font_px(Typography.BODY))
	theme.set_type_variation(&"TitleLabel", &"Label")
	theme.set_font_size("font_size", "TitleLabel", font_px(Typography.TITLE))
	# The build stamp in a corner of the profile picker: small, and faded toward the page.
	theme.set_type_variation(&"StampLabel", &"Label")
	theme.set_font_size("font_size", "StampLabel", font_px(Typography.METADATA))
	theme.set_color("font_color", "StampLabel", preset.text.lerp(preset.background, 0.2))
	theme.set_type_variation(&"SectionLabel", &"Label")
	theme.set_font_size("font_size", "SectionLabel", font_px(Typography.SECTION))
	# A line under a control that says what the choice means: label size, faded a little toward the page.
	theme.set_type_variation(&"HintLabel", &"Label")
	theme.set_font_size("font_size", "HintLabel", font_px(Typography.SUPPORTING))
	theme.set_color("font_color", "HintLabel", preset.text.lerp(preset.background, 0.3))
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		theme.set_stylebox(state, "Button", _button_box(preset, state))
	theme.set_color("font_color", "Button", preset.text)
	theme.set_color("font_hover_color", "Button", preset.text)
	theme.set_color("font_pressed_color", "Button", preset.surface)
	theme.set_color("font_focus_color", "Button", preset.text)
	var panel: StyleBoxFlat = StyleBoxFlat.new()
	panel.bg_color = preset.surface
	panel.set_corner_radius_all(preset.corner_radius)
	panel.set_content_margin_all(16.0)
	theme.set_stylebox("panel", "PanelContainer", panel)
	return theme

func _button_box(preset: StylePreset, state: String) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = preset.surface
	box.set_corner_radius_all(preset.corner_radius)
	box.set_content_margin_all(20.0)
	box.border_color = preset.accent
	match state:
		"hover":
			box.set_border_width_all(3)
		"pressed":
			box.bg_color = preset.accent
		"focus":
			box.set_border_width_all(4)
			box.draw_center = false
		"disabled":
			box.bg_color = preset.surface.lerp(preset.background, 0.5)
	return box
