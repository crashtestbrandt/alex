extends PillBar
class_name GlyphBar
## A floating pill of glyph buttons, one of them the current state: the view widget under the room and the
## Palette and Build widget under Words (docs/ui.md). Each button is a distance-field glyph in a
## distance-field pill, sized from the style's touch floor: a glyph button is a secondary control, so it
## takes `BUTTON_SCALE` of a tile, never under `MIN_PX`. The pressed pill is the current state, and a tap on
## it emits again, so a widget can treat that tap as a reset.

const BUTTON_SCALE: float = 0.7
const MIN_PX: float = 96.0

var _glyph_buttons: Array[GlyphButton] = []

func _ready() -> void:
	super()
	Style.fonts_changed.connect(_size_buttons)
	_size_buttons()

## Put a glyph button in the bar.
func add_glyph(figure: SdfGlyph.Figure, tooltip: String) -> GlyphButton:
	var button: GlyphButton = GlyphButton.new()
	button.figure = figure
	button.tooltip_text = tooltip
	add_item(button)
	_glyph_buttons.push_back(button)
	_size_buttons()
	return button

## Show `current` as the pressed one without emitting.
func show_current(current: GlyphButton) -> void:
	for button: GlyphButton in _glyph_buttons:
		button.set_pressed_no_signal(button == current)
		button.refresh()
		button.update_glyph()

func _size_buttons() -> void:
	var px: float = maxf(Style.current.tile_min_size * BUTTON_SCALE, maxf(MIN_PX, Style.units_per_point * 48.0))
	for button: GlyphButton in _glyph_buttons:
		button.custom_minimum_size = Vector2(px, px)

func _on_style_changed(preset: StylePreset) -> void:
	super(preset)
	_size_buttons()

## A pill that shows one glyph, in the pressed font color while it is the current one.
class GlyphButton extends SdfButton:
	var figure: SdfGlyph.Figure = SdfGlyph.Figure.FRONT
	var _glyph: SdfGlyph = null

	func _ready() -> void:
		super()
		_glyph = SdfGlyph.new()
		_glyph.name = "Glyph"
		_glyph.figure = figure
		_glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_glyph)
		button_down.connect(update_glyph)
		button_up.connect(update_glyph)
		toggled.connect(func(_on: bool) -> void: update_glyph())
		update_glyph()

	func update_glyph() -> void:
		if _glyph == null:
			return
		_glyph.tint = Style.current.surface if is_active() else Style.current.text

	func _on_style_changed(preset: StylePreset) -> void:
		super(preset)
		update_glyph()
