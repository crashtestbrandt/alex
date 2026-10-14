extends GlyphBar
class_name WordsWidget
## The learner's Words buttons: Palette, every phrase as a tile, and Build, a strip filled from chunks. The
## pressed pill is the current one, so the widget reads as a state, not a menu ([GlyphBar]).

signal mode_chosen(mode: Mode)

## Words' two modes, in widget order.
enum Mode {
	PALETTE = 0,
	BUILD = 1,
}

const _FIGURES: Dictionary[int, SdfGlyph.Figure] = {
	Mode.PALETTE: SdfGlyph.Figure.PALETTE,
	Mode.BUILD: SdfGlyph.Figure.BUILD,
}

var _buttons: Dictionary[int, GlyphBar.GlyphButton] = {}

func _ready() -> void:
	super()
	for m: int in Mode.values():
		var mode: Mode = m as Mode
		var mode_name: String = Mode.keys()[m]
		var button: GlyphBar.GlyphButton = add_glyph(_FIGURES[m], mode_name.capitalize())
		button.pressed.connect(_on_pressed.bind(mode))
		_buttons[m] = button

## Show `mode` as the current one without emitting.
func show_mode(mode: Mode) -> void:
	show_current(_buttons[mode])

func _on_pressed(mode: Mode) -> void:
	mode_chosen.emit(mode)
