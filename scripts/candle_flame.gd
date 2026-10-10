extends Node3D
## A lit candlestick (the kit's triple candlestick: scripts/world_interiors.gd
## candle): a flame on each of its three wicks (assets/shaders/candle_flame.
## gdshader), the wax about each wick melted to a pool with a run or two
## down its side, and, where `light` is asked for, one small warm light for
## the three, wavering with them (no shadows, a short reach: a table's
## worth).
const Vfx = preload("res://scripts/vfx.gd")
# The wicks, in the candlestick model's own unit space (its bounds a unit box
# standing on its base), and the size of a flame.
const WICKS = [Vector3(-.397,.722,.013),Vector3(.004,.985,.019),Vector3(.387,.721,-.022)]
const FLAME = Vector2(.028,.075)
const WAX = Color(.93,.88,.76)
const ENERGY = .55
const REACH = 2.6
const FLICKER = .18
static var flame_mesh: QuadMesh
static var wax_material: StandardMaterial3D

var light: OmniLight3D
var flames: Array[MeshInstance3D] = []
var clock = 0.0

# Lights the candlestick `stick` (a model of size `size`, as Kit.sized gives).
func setup(stick: Node3D, size: Vector3, with_light: bool) -> void:
	name = "LitCandles"
	if flame_mesh == null:
		flame_mesh = QuadMesh.new()
		flame_mesh.size = FLAME
		flame_mesh.center_offset = Vector3(0,FLAME.y*.5,0)
		var m = ShaderMaterial.new()
		m.shader = load("res://assets/shaders/candle_flame.gdshader")
		flame_mesh.material = m
		wax_material = StandardMaterial3D.new()
		wax_material.albedo_color = WAX
		wax_material.roughness = .45
	# (Its place and turn only: the model is scaled to its size, these not.)
	position = stick.position
	rotation = stick.rotation
	clock = fposmod(stick.position.x*3.1+stick.position.z*1.7,10.0)
	for i in WICKS.size():
		var wick: Vector3 = WICKS[i]*size
		var flame = MeshInstance3D.new()
		flame.name = "CandleFlame"
		flame.mesh = flame_mesh
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flame.position = wick+Vector3.UP*.004
		add_child(flame)
		flames.append(flame)
		# The pool of melted wax round the wick, and a run down the side.
		var pool = MeshInstance3D.new()
		var lump = SphereMesh.new()
		lump.radius = .016; lump.height = .012
		lump.material = wax_material
		pool.mesh = lump
		pool.position = wick+Vector3.DOWN*.004
		add_child(pool)
		var run = MeshInstance3D.new()
		var drip = CapsuleMesh.new()
		drip.radius = .0045; drip.height = .03+.012*i
		drip.material = wax_material
		run.mesh = drip
		var round = [.6,2.4,4.1][i]
		run.position = wick+Vector3(cos(round)*.011,-.018-.006*i,sin(round)*.011)
		add_child(run)
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

func _process(delta: float) -> void:
	if light == null or not is_visible_in_tree(): return
	clock += delta
	var waver: float = sin(clock*11.0)*.5+sin(clock*6.7+1.3)*.3+sin(clock*17.0+2.1)*.2
	light.light_energy = ENERGY*(1.0+FLICKER*waver)
