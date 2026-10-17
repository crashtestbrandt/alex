extends ChunkButton
class_name TakePill
## One pill on the recording overlay: a chunk of the phrase in its own color ([ChunkButton]), or the whole
## phrase on the style's surface. A tap selects what the big button records. The selected pill wears a thick
## border in the style's text color, and a pill with a take carries a microphone mark ([SdfGlyph]) at its
## right end. Sized for a caregiver's finger, not for the learner's tile floor.

const SELECTED_BORDER_PX: float = 5.0
const MIN_HEIGHT_PX: float = 72.0
const MARK_PX: float = 28.0
const MARK_GAP_PX: float = 8.0

## The whole phrase rather than one chunk: the surface fill, the accent when pressed.
var whole: bool = false:
	set(value):
		whole = value
		refresh()
## What the big button records.
var selected: bool = false:
	set(value):
		selected = value
		refresh()
## Whether a take exists for this pill.
var recorded: bool = false:
	set(value):
		recorded = value
		_mark.visible = value
		_apply_margins()
		refresh()

var _mark: SdfGlyph = SdfGlyph.new()
## The widest the pill may be. Text wider than that wraps inside it.
var _fit: float = INF

func _init() -> void:
	super()
	_mark.name = "Mark"
	_mark.figure = SdfGlyph.Figure.MICROPHONE
	_mark.width_px = 2.5
	_mark.visible = false
	_mark.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_mark.offset_left = -(MARK_PX + SdfButton.CONTENT_MARGIN_PX * 0.5)
	_mark.offset_right = _mark.offset_left + MARK_PX
	_mark.offset_top = -MARK_PX / 2.0
	_mark.offset_bottom = MARK_PX / 2.0
	add_child(_mark)
	_apply_margins()

func refresh() -> void:
	super()
	if _shape == null:
		return
	var preset: StylePreset = Style.current
	if whole:
		_shape.fill = preset.accent if is_active() else preset.surface
		for color_name: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
			remove_theme_color_override(color_name)
	if selected:
		_shape.border_px = SELECTED_BORDER_PX
		_shape.border_color = preset.text
	elif whole:
		_shape.border_color = preset.accent

## Room at the right end for the mark when there is one.
func _apply_margins() -> void:
	var margins: StyleBoxEmpty = StyleBoxEmpty.new()
	margins.set_content_margin_all(SdfButton.CONTENT_MARGIN_PX)
	if recorded:
		margins.content_margin_right = SdfButton.CONTENT_MARGIN_PX + MARK_PX + MARK_GAP_PX
	for state: String in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(state, margins)
	_apply_fit()

## Cap the pill at `width`. The pill takes its text's width up to that, and wraps past it. An autowrapping
## button has no width of its own in a flow container, so the cap is what gives it one.
func fit_width(width: float) -> void:
	_fit = width
	_apply_fit()

func _apply_fit() -> void:
	var font: Font = get_theme_font("font")
	var font_px: int = get_theme_font_size("font_size")
	var text_width: float = ceilf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x) + 2.0
	var margins: float = get_theme_stylebox("normal").get_minimum_size().x
	custom_minimum_size = Vector2(minf(text_width + margins, maxf(_fit, 1.0)), MIN_HEIGHT_PX)

## A caregiver's pill: the style's lettering, a height a finger can hit, never the learner's tile floor.
func _apply_style() -> void:
	add_theme_font_size_override("font_size", Style.font_px(FONT_BASE))
	_apply_fit()
