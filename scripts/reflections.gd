extends RefCounted
## What polished things reflect: every scene's environment is given a sky to
## mirror (assets/shaders/reflection_sky.gdshader) while it keeps its own
## background and ambient light, so steel, gold and bronze can be drawn as
## full metal, and leather, skin and lacquer take a sheen at a glancing angle.
##   "desert"  the open desert by day (the Goegap HDRI); overworld.gd
##             set_time dims, tints and by night swaps it (daylight()).
##   "interior" torchlit halls: the sandstone cloister HDRI, dim and warm.
##   "studio"  previews, item pictures and the inventory's figure, seen
##             straight on: a photographer's soft studio light all round.

const SKIES = {
	"desert":{"panorama":"res://assets/textures/env/desert_day.hdr","tint":Color(1.0,.95,.86),"energy":2.1,"saturation":.35},
	"interior":{"panorama":"res://assets/textures/env/cloister.hdr","tint":Color(1.0,.72,.45),"energy":.45,"saturation":.55},
	"studio":{"panorama":"res://assets/textures/env/desert_day.hdr","tint":Color(1.0,.98,.95),"energy":1.0,"saturation":.3,"studio":1.0},
}

static func apply(e: Environment, kind: String = "studio") -> ShaderMaterial:
	var look: Dictionary = SKIES[kind]
	var m = ShaderMaterial.new()
	m.shader = load("res://assets/shaders/reflection_sky.gdshader")
	m.set_shader_parameter("panorama",load(look.panorama))
	m.set_shader_parameter("tint",Vector3(look.tint.r,look.tint.g,look.tint.b))
	m.set_shader_parameter("energy",look.energy)
	m.set_shader_parameter("saturation",look.saturation)
	m.set_shader_parameter("studio",look.get("studio",0.0))
	e.sky = Sky.new()
	e.sky.sky_material = m
	e.sky.radiance_size = Sky.RADIANCE_SIZE_128
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	return m

# The desert's sky through the day (scripts/daylight.gd sky()): the photograph
# in the colour of the light, as bright as the ambient light, giving way to
# the painted night. Each change redraws what is reflected, so it is set only
# when it has changed enough to see.
static func daylight(m: ShaderMaterial, sky: Dictionary) -> void:
	var day_tint: Color = sky.ambient.lerp(sky.light,.35)
	var energy: float = snappedf(clampf(sky.ambient_energy*3.0+sky.energy*1.3,.1,2.4),.04)
	var night: float = snappedf(sky.night,.05)
	var tint: Color = Color(snappedf(day_tint.r,.03),snappedf(day_tint.g,.03),snappedf(day_tint.b,.03))
	var key = "%.2f %.2f %s" % [night,energy,tint.to_html(false)]
	if m.get_meta("set","") == key: return
	m.set_meta("set",key)
	m.set_shader_parameter("night",night)
	m.set_shader_parameter("energy",energy)
	m.set_shader_parameter("tint",Vector3(tint.r,tint.g,tint.b))
