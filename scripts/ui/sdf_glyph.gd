extends Control
class_name SdfGlyph
## A glyph drawn as a distance field (`shaders/ui/glyph.gdshader`): the view icons, the dots that lead to the
## adults' screens, the microphone. It fills its control, scales its figure to the control's shorter side, and
## never takes input (docs/ui.md).

const _SHADER: Shader = preload("res://shaders/ui/glyph.gdshader")
## The figure's radius as a fraction of the control's shorter side.
const RADIUS_FRACTION: float = 0.26

## The shader's `figure` cases, in order.
enum Figure {
	FRONT = 0,
	SIDE = 1,
	TOP = 2,
	TURN = 3,
	DOTS = 4,
	MICROPHONE = 5,
}

@export var figure: Figure = Figure.FRONT:
	set(value):
		figure = value
		_apply()
@export var width_px: float = 3.0:
	set(value):
		width_px = value
		_apply()
## Transparent means the style's text color.
@export var tint: Color = Color(0.0, 0.0, 0.0, 0.0):
	set(value):
		tint = value
		_apply()

var _material: ShaderMaterial = ShaderMaterial.new()

func _init() -> void:
	_material.shader = _SHADER
	material = _material
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	Style.changed.connect(_on_style_changed)
	_apply()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply()

func _draw() -> void:
	draw_texture_rect(SdfShape.white(), Rect2(Vector2.ZERO, size), false)

func _apply() -> void:
	_material.set_shader_parameter("rect_px", size)
	_material.set_shader_parameter("radius_px", minf(size.x, size.y) * RADIUS_FRACTION)
	_material.set_shader_parameter("width_px", width_px)
	_material.set_shader_parameter("figure", figure)
	_material.set_shader_parameter("tint", tint if tint.a > 0.0 else Style.current.text)
	queue_redraw()

func _on_style_changed(_preset: StylePreset) -> void:
	_apply()
