extends Control
class_name SdfShape
## A rounded rectangle drawn as a distance field (`shaders/ui/shape.gdshader`): fill, hairline border, a rim lit
## from above and a soft shadow, all one field. Every button, panel, tile and bar in the app is one of these
## behind its content (docs/ui.md). It draws one quad grown by `PAD_PX` so the shadow has room, and never takes
## input.

const _SHADER: Shader = preload("res://shaders/ui/shape.gdshader")
## How far past the control's rect the quad extends, for the shadow.
const PAD_PX: float = 24.0

static var _white: ImageTexture = null

@export var radius_px: float = 18.0:
	set(value):
		radius_px = value
		_apply()
@export var fill: Color = Color.WHITE:
	set(value):
		fill = value
		_apply()
@export var border_color: Color = Color(0.0, 0.0, 0.0, 0.0):
	set(value):
		border_color = value
		_apply()
@export var border_px: float = 0.0:
	set(value):
		border_px = value
		_apply()
## Below zero, the style preset's relief is used.
@export var relief: float = -1.0:
	set(value):
		relief = value
		_apply()
## 0 at rest, 1 fully pressed.
var press: float = 0.0:
	set(value):
		press = value
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
	var pad: Vector2 = Vector2(PAD_PX, PAD_PX)
	draw_texture_rect(white(), Rect2(-pad, size + pad * 2.0), false)

func _apply() -> void:
	var preset: StylePreset = Style.current
	_material.set_shader_parameter("rect_px", size + Vector2(PAD_PX, PAD_PX) * 2.0)
	_material.set_shader_parameter("pad_px", PAD_PX)
	_material.set_shader_parameter("radius_px", radius_px)
	_material.set_shader_parameter("fill", fill)
	_material.set_shader_parameter("border", border_color)
	_material.set_shader_parameter("border_px", border_px)
	_material.set_shader_parameter("relief", relief if relief >= 0.0 else preset.relief)
	_material.set_shader_parameter("press", press)
	_material.set_shader_parameter("shadow", Color(0.0, 0.0, 0.0, 0.28))
	queue_redraw()

func _on_style_changed(_preset: StylePreset) -> void:
	_apply()

## A 2 by 2 white texture: the quad the shader paints has to carry UVs, and a plain rect carries none.
static func white() -> ImageTexture:
	if _white == null:
		var image: Image = Image.create(2, 2, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(image)
	return _white
