extends Node3D
## A glow on the hero's blade: sheathing it, hottest along its edge, with a
## light of its colour, as strong as `intensity` (0 to 1), which
## scripts/visual.gd raises and lets go: War Cry's deep red as he lifts the
## sword to shout, let go as the cry bursts from it (the ring racing out over
## the ground: scripts/war_cry.gd); Vampiric Strike's blood red and Shadow
## Strike's purple over their swings (tint()).
## Drawn only; nothing about the skill depends on it. Carried on the blade
## (attach()), as Ground Slam's charge is (scripts/blade_charge.gd).

const Vfx = preload("res://scripts/vfx.gd")
const GLOW = Color(1.0,.12,.06)
const HOT = Color(1.0,.45,.3)

var glow: CPUParticles3D
var core: CPUParticles3D
var light: OmniLight3D
var intensity = 0.0
var color = GLOW

func _init() -> void:
	name = "BladeGlow"
	# The red glow round the whole blade.
	glow = Vfx.particles(self,40,.22,false,true)
	glow.local_coords = true
	glow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	glow.direction = Vector3.UP
	glow.spread = 180
	glow.initial_velocity_min = 0.0
	glow.initial_velocity_max = .1
	glow.gravity = Vector3.ZERO
	glow.scale_amount_min = .16
	glow.scale_amount_max = .26
	glow.color_ramp = Vfx.ramp([0,.3,1],[Color(GLOW,0),Color(GLOW,.5),Color(GLOW,0)])
	# A hotter, tighter glow along the edge itself.
	core = Vfx.particles(self,24,.16,false,true)
	core.local_coords = true
	core.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	core.direction = Vector3.UP
	core.spread = 180
	core.initial_velocity_min = 0.0
	core.initial_velocity_max = .04
	core.gravity = Vector3.ZERO
	core.scale_amount_min = .07
	core.scale_amount_max = .11
	core.color_ramp = Vfx.ramp([0,.35,1],[Color(HOT,0),Color(HOT,.55),Color(GLOW,0)])
	light = OmniLight3D.new()
	light.light_color = GLOW
	light.omni_range = 2.8
	light.omni_attenuation = 1.4
	light.shadow_enabled = false
	add_child(light)
	show_strength()

# Carried on the blade itself (`weapon`, whose local Y runs up the blade from
# `from` to `to`), scaled back so it is not stretched with the weapon.
func attach(weapon: Node3D, from: float, to: float) -> void:
	if get_parent() != weapon:
		if get_parent() != null: get_parent().remove_child(self)
		weapon.add_child(self)
	var unscaled: Basis = weapon.global_basis.inverse()*weapon.global_basis.orthonormalized()
	transform = Transform3D(unscaled,Vector3(0,(from+to)*.5,0))
	var length: float = (weapon.global_basis*Vector3(0,to-from,0)).length()
	glow.emission_box_extents = Vector3(.03,length*.5,.03)
	core.emission_box_extents = Vector3(.01,length*.5,.01)

# The glow's colour (its edge a paler, hotter shade of it).
func tint(c: Color) -> void:
	if c == color: return
	color = c
	var hot: Color = c.lerp(Color.WHITE,.4)
	glow.color_ramp = Vfx.ramp([0,.3,1],[Color(c,0),Color(c,.5),Color(c,0)])
	core.color_ramp = Vfx.ramp([0,.35,1],[Color(hot,0),Color(hot,.55),Color(c,0)])
	light.light_color = c

func step(strength: float) -> void:
	intensity = clampf(strength,0.0,1.0)
	show_strength()

func show_strength() -> void:
	var on: bool = intensity > .02
	glow.emitting = on
	core.emitting = on
	# (Particles fade in rather than thin out: their colour carries the strength.)
	glow.color = Color(1,1,1,clampf(intensity*1.3,0.0,1.0))
	core.color = Color(1,1,1,clampf(intensity*1.2,0.0,1.0))
	glow.scale_amount_min = .1+.08*intensity
	glow.scale_amount_max = .16+.12*intensity
	light.light_energy = .9*intensity
	light.visible = on
