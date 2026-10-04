extends Node3D
## A living torch flame, one per torch; the imported fixture stays intact. The
## flame is a small volume of glowing particles, so it has depth from every
## angle: tongues rise from a white-hot core, stretch, and cool through orange
## to red as they fade, with the odd ember drifting up. A per-torch noise field
## drives random flicker and gusts. The same field sways the flame and shifts
## the light's brightness, warmth and position, so the flame's dance and the
## light it casts move together. Particles stop while the torch is out of sight.
const Vfx = preload("res://scripts/vfx.gd")
# Flicker stays within this share of the torch's brightness.
const FLICKER = .14
# Drawn up to this far from the camera. The cameras stand well back from the
# hero (31m in the temple, 43m outdoors) and look over him at a slant, so a
# fire at the far edge of a wide view is some 70m off: any nearer, and a
# flame in plain view (the campfire, beyond the hero as he wakes) vanished.
const REACH = 90.0

var light: OmniLight3D
var elapsed = 0.0
var base_energy = 0.0
var base_light_position = Vector3.ZERO
var noise: FastNoiseLite
var flame: CPUParticles3D
var core: CPUParticles3D
var embers: CPUParticles3D

func setup(source: OmniLight3D, phase: float) -> void:
	light = source
	base_energy = source.light_energy
	base_light_position = source.position
	elapsed = phase
	name = "AnimatedTorchFlame"
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = int(phase*1000.0)
	noise.frequency = 1.0
	# One smooth layer; the default fractal detail makes it jitter frame to frame.
	noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	# Tongues of flame: stretched soft glows rising from the wick.
	flame = Vfx.particles(self,24,.6,false,true)
	flame.mesh.size = Vector2(.6,1.0)
	flame.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flame.emission_sphere_radius = .045
	flame.direction = Vector3.UP
	flame.spread = 10
	flame.initial_velocity_min = .45
	flame.initial_velocity_max = .8
	flame.gravity = Vector3(0,1.4,0)
	flame.damping_min = .3
	flame.damping_max = .6
	flame.scale_amount_min = .21
	flame.scale_amount_max = .32
	var taper = Curve.new()
	taper.add_point(Vector2(0,.5)); taper.add_point(Vector2(.15,1)); taper.add_point(Vector2(1,.12))
	flame.scale_amount_curve = taper
	flame.color_ramp = Vfx.ramp([0,.1,.3,.65,1],[Color(1,.9,.6,0),Color(1,.76,.34,.4),Color(1,.48,.11,.36),Color(.8,.22,.04,.22),Color(.3,.06,.02,0)])
	flame.hue_variation_min = -.02
	flame.hue_variation_max = .02
	# The white-hot heart at the base of the flame.
	core = Vfx.particles(self,6,.3,false,true)
	core.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	core.emission_sphere_radius = .02
	core.direction = Vector3.UP
	core.initial_velocity_min = .05
	core.initial_velocity_max = .15
	core.gravity = Vector3.ZERO
	core.scale_amount_min = .15
	core.scale_amount_max = .2
	core.color_ramp = Vfx.ramp([0,.3,1],[Color(1,.92,.66,.18),Color(1,.84,.5,.3),Color(1,.6,.25,0)])
	# Occasional embers carried up by the heat.
	embers = Vfx.particles(self,3,1.6,false,true)
	embers.randomness = 1.0
	embers.direction = Vector3.UP
	embers.spread = 25
	embers.initial_velocity_min = .7
	embers.initial_velocity_max = 1.3
	embers.gravity = Vector3(0,.3,0)
	embers.scale_amount_min = .025
	embers.scale_amount_max = .04
	embers.color_ramp = Vfx.ramp([0,.6,1],[Color(1,.8,.35,1),Color(1,.45,.1,.8),Color(.8,.2,.05,0)])
	for p in [flame,core,embers]:
		p.visibility_range_end = REACH
		p.preprocess = p.lifetime
	advance(0.0)

func _notification(what: int) -> void:
	# Torches out of line of sight are hidden; stop simulating them too.
	if what == NOTIFICATION_VISIBILITY_CHANGED and flame != null:
		var shown = is_visible_in_tree()
		set_process(shown)
		for p in [flame,core,embers]:
			p.process_mode = Node.PROCESS_MODE_INHERIT if shown else Node.PROCESS_MODE_DISABLED

func _process(delta: float) -> void:
	advance(delta)

# Smooth, random flicker in [-1, 1] from layered noise, with occasional gusts
# that briefly gutter the flame.
func flicker_at(t: float) -> float:
	var slow = noise.get_noise_2d(t*1.6,0.0)
	var fast = noise.get_noise_2d(t*2.3,37.0)
	var gust = minf(0.0,noise.get_noise_2d(t*.45,91.0)+.35)*1.6
	return clampf(slow*.8+fast*.35+gust*.6,-1.0,1.0)

func advance(delta: float) -> void:
	elapsed += delta
	var flicker = flicker_at(elapsed)
	var sway = Vector2(noise.get_noise_2d(elapsed*1.3,11.0),noise.get_noise_2d(elapsed*1.3,23.0))
	light.light_energy = base_energy*(1.0+flicker*FLICKER)
	light.light_color = Color(1.0,.60+flicker*.06,.28+flicker*.05)
	# The light shifts with the flame, so shadows and highlights shimmer.
	light.position = base_light_position+Vector3(sway.x,flicker*.5,sway.y)*.035
	flame.gravity = Vector3(sway.x*1.8,1.4+flicker*.5,sway.y*1.8)
	embers.gravity = Vector3(sway.x*1.2,.3,sway.y*1.2)
	flame.scale_amount_max = .32*(1.0+flicker*.25)
