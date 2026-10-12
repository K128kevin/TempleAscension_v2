extends Node3D
## A lit candlestick (the kit's triple candlestick: scripts/world_interiors.gd
## candle): a flame on each of its three wicks, the wax about each wick melted
## to a pool with a run or two down its side, and, where `light` is asked
## for, one small warm light for the three, wavering with them (no shadows, a
## short reach: a table's worth).
##
## Each flame is particles (CPUParticles3D, which this renderer runs on any
## GPU): tongues of flame (assets/shaders/candle_particle.gdshader) rising
## from the wick, white-yellow at the foot and cooling through yellow and
## orange to nothing at the tip, a little blue where they leave the wick;
## over them the flame's steady bright heart (assets/shaders/candle_flame.
## gdshader), a soft glow about it, and now and then a thread of smoke going
## up from it. The air moves them all together (a sway and a gutter, each
## stick by its own beat), and the light with them.
const Vfx = preload("res://scripts/vfx.gd")
# The wicks' tips, in the candlestick model's own unit space (its bounds a
# unit box standing on its base: found from its mesh, the little square tip
# of each wick), and the size of a flame's heart and of its tongues. The flame
# wraps the wick, from a little below its tip.
const WICKS = [Vector3(-.3915,.7355,-.0065),Vector3(-.002,.9893,-.0065),Vector3(.3835,.7335,.002)]
const WRAP = .004
const HEART = Vector2(.016,.042)
const TONGUE = Vector2(.013,.032)
const WAX = Color(.93,.88,.76)
const ENERGY = .55
const REACH = 2.6
const FLICKER = .18
static var heart_mesh: QuadMesh
static var tongue_mesh: QuadMesh
static var wax_material: StandardMaterial3D
static var smoke_material: StandardMaterial3D

var light: OmniLight3D
# The tongues of each flame (its emitter), its heart and its glow.
var flames: Array[CPUParticles3D] = []
var hearts: Array[MeshInstance3D] = []
var glows: Array[MeshInstance3D] = []
var smoke: CPUParticles3D
var clock = 0.0
var air: FastNoiseLite

# Lights the candlestick `stick` (a model of size `size`, as Kit.sized gives).
func setup(stick: Node3D, size: Vector3, with_light: bool) -> void:
	name = "LitCandles"
	if heart_mesh == null:
		heart_mesh = QuadMesh.new()
		heart_mesh.size = HEART
		heart_mesh.center_offset = Vector3(0,HEART.y*.5,0)
		var m = ShaderMaterial.new()
		m.shader = load("res://assets/shaders/candle_flame.gdshader")
		heart_mesh.material = m
		tongue_mesh = QuadMesh.new()
		tongue_mesh.size = TONGUE
		tongue_mesh.center_offset = Vector3(0,TONGUE.y*.3,0)
		var t = ShaderMaterial.new()
		t.shader = load("res://assets/shaders/candle_particle.gdshader")
		tongue_mesh.material = t
		wax_material = StandardMaterial3D.new()
		wax_material.albedo_color = WAX
		wax_material.roughness = .45
	# (Its place and turn only: the model is scaled to its size, these not.)
	position = stick.position
	rotation = stick.rotation
	clock = fposmod(stick.position.x*3.1+stick.position.z*1.7,10.0)
	air = FastNoiseLite.new()
	air.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	air.fractal_type = FastNoiseLite.FRACTAL_NONE
	air.frequency = .9
	air.seed = int(clock*1000.0)
	for i in WICKS.size():
		var wick: Vector3 = WICKS[i]*size
		flames.append(tongues(wick+Vector3.DOWN*WRAP))
		# Its heart: small, bright and steady, low in the flame.
		var heart = MeshInstance3D.new()
		heart.name = "CandleFlame"
		heart.mesh = heart_mesh
		heart.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		heart.position = wick+Vector3.DOWN*WRAP
		heart.scale = Vector3.ONE*.62
		add_child(heart)
		hearts.append(heart)
		var glow = Vfx.soft_glow(Color(1.0,.62,.28,.22),Vector2(.07,.09))
		glow.name = "CandleGlow"
		glow.position = wick+Vector3.UP*.016
		add_child(glow)
		glows.append(glow)
		# The pool of melted wax round the wick, and a run down the side.
		var pool = MeshInstance3D.new()
		var lump = SphereMesh.new()
		lump.radius = .016; lump.height = .012
		lump.material = wax_material
		pool.mesh = lump
		pool.position = wick+Vector3.DOWN*.011
		add_child(pool)
		var run = MeshInstance3D.new()
		var drip = CapsuleMesh.new()
		drip.radius = .0045; drip.height = .03+.012*i
		drip.material = wax_material
		run.mesh = drip
		var round = [.6,2.4,4.1][i]
		run.position = wick+Vector3(cos(round)*.011,-.025-.006*i,sin(round)*.011)
		add_child(run)
	# A thread of smoke off the tallest.
	smoke = Vfx.particles(self,6,1.8,false,false)
	smoke.local_coords = false
	smoke.position = WICKS[1]*size+Vector3.UP*.05
	smoke.direction = Vector3.UP
	smoke.spread = 6
	smoke.initial_velocity_min = .1
	smoke.initial_velocity_max = .16
	smoke.gravity = Vector3(0,.04,0)
	smoke.scale_amount_min = .012
	smoke.scale_amount_max = .02
	smoke.scale_amount_curve = Vfx.curve(1.0,4.0)
	smoke.color_ramp = Vfx.ramp([0,.25,1],[Color(.2,.19,.18,0),Color(.22,.21,.2,.07),Color(.3,.29,.28,0)])
	smoke.emitting = true
	if with_light:
		light = OmniLight3D.new()
		light.name = "CandleLight"
		light.light_color = Color(1.0,.68,.36)
		light.light_energy = ENERGY
		light.omni_range = REACH
		light.omni_attenuation = 1.3
		light.shadow_enabled = false
		light.position = WICKS[1]*size+Vector3.UP*.08
		add_child(light)

# A flame's tongues, rising from the wick at `at`: born small and white-hot
# (blue at their very foot), swelling yellow, drawn up and cooling to orange
# as they fade.
func tongues(at: Vector3) -> CPUParticles3D:
	var p = CPUParticles3D.new()
	p.name = "CandleTongues"
	p.mesh = tongue_mesh
	p.amount = 18
	p.lifetime = .34
	p.local_coords = true
	p.position = at
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = .0018
	p.direction = Vector3.UP
	p.spread = 5.0
	p.initial_velocity_min = .05
	p.initial_velocity_max = .08
	p.gravity = Vector3(0,.32,0)
	p.damping_min = .05
	p.damping_max = .12
	p.scale_amount_min = .8
	p.scale_amount_max = 1.1
	var shape = Curve.new()
	shape.add_point(Vector2(0,.45)); shape.add_point(Vector2(.25,1.0)); shape.add_point(Vector2(.6,.85)); shape.add_point(Vector2(1,.2))
	p.scale_amount_curve = shape
	p.color_ramp = Vfx.ramp([0,.06,.22,.5,.8,1],[Color(.3,.45,1.0,0),Color(.4,.5,1.0,.2),Color(1.0,.88,.6,.26),Color(1.0,.66,.26,.22),Color(1.0,.4,.08,.13),Color(.7,.16,.03,0)])
	p.hue_variation_min = -.01
	p.hue_variation_max = .01
	add_child(p)
	p.emitting = true
	return p

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	clock += delta
	# The air in the room: a slow sway, and now and then a gust that makes
	# the flames gutter and lean.
	var sway = Vector2(air.get_noise_2d(clock,0.0),air.get_noise_2d(0.0,clock+40.0))
	var gust: float = maxf(0.0,air.get_noise_2d(clock*.35,90.0)-.25)*2.0
	var lean = Vector3(sway.x,0,sway.y)*(.06+gust*.25)
	for flame in flames: flame.gravity = Vector3(lean.x,.32-gust*.08,lean.z)
	for heart in hearts: heart.rotation = Vector3(lean.z*1.5,0,-lean.x*1.5)
	var waver: float = sin(clock*11.0)*.5+sin(clock*6.7+1.3)*.3+sin(clock*17.0+2.1)*.2
	for glow in glows: glow.scale = Vector3(.07,.09,1.0)*(1.0+.06*waver-gust*.1)
	if light != null: light.light_energy = ENERGY*(1.0+FLICKER*waver-gust*.25)
