extends HoldButton
class_name ChunkButton
## A chunk the learner can tap in Build: an [SdfButton] pill filled with the chunk's own color (ChunkColors),
## its text in the style's text color, so it is the same chunk the tiles and captions show. While pressed it
## brightens the way a spoken pill does at motion NONE, keeping its hue. A hold fires `held` (from
## [HoldButton]) for the recording flow, and `consumed_by_hold` keeps that press from counting as a tap.

const FONT_BASE: int = 24

var chunk: String = "":
	set(value):
		chunk = value
		text = value
		refresh()

func _init() -> void:
	super()
	shape = Shape.PILL
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	focus_mode = Control.FOCUS_ALL

func _ready() -> void:
	super()
	_apply_style()

func refresh() -> void:
	super()
	if _shape == null:
		return
	var rest: Color = ChunkColors.color_for(chunk, Style.current.chunk_palette)
	_shape.fill = ChunkColors.spoken(rest) if is_active() else rest
	_shape.border_color = Style.current.text
	for color_name: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		add_theme_color_override(color_name, Style.current.text)

## The lettering follows the style, and the pill honors the touch floor as a tile does.
func _apply_style() -> void:
	add_theme_font_size_override("font_size", Style.font_px(FONT_BASE))
	custom_minimum_size = Vector2(0.0, Style.current.tile_min_size)

func _on_style_changed(preset: StylePreset) -> void:
	super(preset)
	_apply_style()
