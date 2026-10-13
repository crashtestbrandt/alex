extends Node
## Autoload `Style`: applies a [StylePreset] to the whole interface and answers how much to animate.
##
## The Theme is built here from the preset's colors and sizes rather than authored as a .tres, so every
## control picks up a profile's choices without a theme file per preset. Apply once when a profile opens.

signal changed(preset: StylePreset)

const _BASE_TILE_FONT: int = 24
const _BASE_LABEL_FONT: int = 22
const _BASE_TITLE_FONT: int = 32

var current: StylePreset = StylePreset.new()

func _ready() -> void:
	apply(current)

func apply(preset: StylePreset) -> void:
	current = preset
	var theme: Theme = _build_theme(preset)
	get_tree().root.theme = theme
	RenderingServer.set_default_clear_color(preset.background)
	changed.emit(preset)

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
	return roundi(base * current.font_scale)

func _build_theme(preset: StylePreset) -> Theme:
	var theme: Theme = Theme.new()
	theme.set_font_size("font_size", "Label", font_px(_BASE_LABEL_FONT))
	theme.set_color("font_color", "Label", preset.text)
	theme.set_font_size("font_size", "Button", font_px(_BASE_TILE_FONT))
	theme.set_font_size("font_size", "LineEdit", font_px(_BASE_LABEL_FONT))
	theme.set_font_size("font_size", "OptionButton", font_px(_BASE_LABEL_FONT))
	theme.set_font_size("font_size", "ItemList", font_px(_BASE_LABEL_FONT))
	theme.set_type_variation(&"TitleLabel", &"Label")
	theme.set_font_size("font_size", "TitleLabel", font_px(_BASE_TITLE_FONT))
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
