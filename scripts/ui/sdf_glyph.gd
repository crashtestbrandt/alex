extends Control
class_name SdfGlyph
## A glyph drawn as a distance field (`shaders/ui/glyph.gdshader`): the view icons, the Words modes, the
## microphone. It fills its control, scales its figure to the control's shorter side, and never takes input
## (docs/ui.md).

const _SHADER: Shader = preload("res://shaders/ui/glyph.gdshader")
## The figure's radius as a fraction of the control's shorter side.
const RADIUS_FRACTION: float = 0.26

## The shader's `figure` cases, in order. SIDE and DOTS are drawn by the shader and used by no button.
enum Figure {
	FRONT = 0,
	SIDE = 1,
	TOP = 2,
	TILT = 3,
	DOTS = 4,
	MICROPHONE = 5,
	PALETTE = 6,
	BUILD = 7,
	ROOMS = 8,
	BACK = 9,
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
	var button: SdfButton = get_parent() as SdfButton
	if button != null:
		button.button_down.connect(_apply.call_deferred)
		button.button_up.connect(_apply.call_deferred)
		button.toggled.connect(func(_on: bool) -> void: _apply.call_deferred())
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
	var color: Color = tint if tint.a > 0.0 else Style.current.text
	var button: SdfButton = get_parent() as SdfButton
	if button != null and tint.a <= 0.0 and button.is_active():
		color = Style.current.surface
	_material.set_shader_parameter("tint", color)
	queue_redraw()

func _on_style_changed(_preset: StylePreset) -> void:
	_apply()
