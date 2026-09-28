extends Sprite3D
## One small transparent effect per torch; the imported fixture stays intact.
const FLAME_SHADER = preload("res://assets/shaders/torch_flame.gdshader")
static var canvas_texture: GradientTexture2D
var light: OmniLight3D
var flame_material: ShaderMaterial
var elapsed = 0.0
var base_energy = 0.0

func setup(source: OmniLight3D, phase: float) -> void:
	light = source
	base_energy = source.light_energy
	elapsed = phase
	name = "AnimatedTorchFlame"
	if canvas_texture == null:
		canvas_texture = GradientTexture2D.new()
		canvas_texture.width = 72
		canvas_texture.height = 128
		canvas_texture.gradient = Gradient.new()
	texture = canvas_texture
	pixel_size = .01
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visibility_range_end = 40.0
	flame_material = ShaderMaterial.new()
	flame_material.shader = FLAME_SHADER
	material_override = flame_material
	advance(0.0)

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	elapsed += delta
	flame_material.set_shader_parameter("flame_time",elapsed)
	# Layered waves stay continuous, within ten percent of the original light.
	var flicker = sin(elapsed*3.1)*.055 + sin(elapsed*7.7+1.2)*.03 + sin(elapsed*13.3)*.015
	light.light_energy = base_energy*(1.0+flicker)
	light.light_color = Color(1.0,.60+flicker*.18,.28+flicker*.10)
