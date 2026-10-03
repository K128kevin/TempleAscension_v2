extends Node3D
## The Oracle's frost nova: ice blasting out in every direction from the
## caster. A cold flash and a frost shockwave race outward; ice shards fly out
## along the ground, a ring of ice spikes erupts as the wave passes and then
## sinks, and frost mist rolls out and settles. Shards and spikes reuse the
## imported crystal (gem) mesh; everything else is particles, sprites and light.
## Advanced by Game on the combat clock. Damage is applied by Game.frost_nova.
const Art = preload("res://scripts/assets.gd")
const Vfx = preload("res://scripts/vfx.gd")
const WAVE_TIME = .32
const SPIKE_HOLD = .55
const SPIKE_SINK = .6
const LIFETIME = 2.6
const SHARDS = 28
const SPIKES = 16

var game
var radius = 3.8
var age = 0.0
var ice: StandardMaterial3D
var flash: OmniLight3D
var shock: Sprite3D
var frost: Sprite3D
var shards: Array = []
var spikes: Array = []
var mist: CPUParticles3D
var glints: CPUParticles3D

func setup(owner_game, center: Vector3, blast_radius: float) -> void:
	game = owner_game
	radius = blast_radius
	name = "OracleFrostNova"
	position = center
	ice = StandardMaterial3D.new()
	ice.albedo_color = Color(.74,.9,1.0,.82)
	ice.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ice.emission_enabled = true
	ice.emission = Color(.35,.62,.9)
	ice.emission_energy_multiplier = .7
	ice.roughness = .12
	ice.metallic_specular = .8
	flash = OmniLight3D.new()
	flash.light_color = Color(.62,.84,1.0)
	flash.omni_range = radius*1.7
	flash.omni_attenuation = 1.2
	# Above the caster, so it lights the robe as well as the floor around it.
	flash.position = Vector3.UP*2.4
	add_child(flash)
	# Pale frost settling on the floor, and the shockwave racing across it.
	frost = ground_sprite(radius*2.3,Vfx.ramp([0,.6,.85,1],[Color(.82,.94,1,.5),Color(.72,.88,1,.35),Color(.8,.93,1,.45),Color(.8,.93,1,0)]))
	frost.modulate.a = 0
	shock = Art.seal(radius*2.2,Color(.72,.9,1,.95))
	shock.position = Vector3.UP*.06
	add_child(shock)
	# No coloured ring on the ground marks the blast; the frost and shards do.
	shock.visible = false
	var seed = fposmod(center.x*3.7+center.z*1.3,TAU)
	for i in SHARDS:
		var angle = seed+TAU*i/SHARDS+sin(i*12.9898)*.08
		var shard = Art.model("gem",Vector3(.13,.13,.7)*(.8+fposmod(i*.618,1.0)*.5),ice)
		add_child(shard)
		shard.rotation.y = angle
		shards.append({"node":shard,"size":shard.scale,"dir":Vector3(sin(angle),0,cos(angle)),"lift":.25+fposmod(i*.37,1.0)*.55,"reach":.8+fposmod(i*.53,1.0)*.3})
	for i in SPIKES:
		var angle = seed+TAU*(i+.5)/SPIKES
		var spike = Art.model("gem",Vector3(.2,.95,.2)*(.75+fposmod(i*.41,1.0)*.5),ice)
		add_child(spike)
		var dir = Vector3(sin(angle),0,cos(angle))
		var at = radius*(.62+fposmod(i*.29,1.0)*.3)
		spike.position = dir*at
		# Lean outward, as if thrown up by the blast.
		spike.rotation = Vector3(.45+fposmod(i*.7,1.0)*.25,angle,0)
		spikes.append({"node":spike,"height":spike.scale,"arrive":WAVE_TIME*at/radius})
		spike.scale.y = .001
	mist = Vfx.particles(self,46,1.3,true,false)
	mist.explosiveness = .95
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	mist.emission_sphere_radius = .3
	mist.direction = Vector3(1,0,0)
	mist.spread = 180
	mist.flatness = 1.0
	mist.initial_velocity_min = radius*2.0
	mist.initial_velocity_max = radius*2.8
	mist.damping_min = radius*2.2
	mist.damping_max = radius*3.0
	mist.gravity = Vector3(0,.25,0)
	mist.position = Vector3.UP*.35
	mist.scale_amount_min = .9
	mist.scale_amount_max = 1.6
	mist.scale_amount_curve = Vfx.curve(.5,1.8)
	mist.color_ramp = Vfx.ramp([0,.2,1],[Color(.9,.97,1,.0),Color(.85,.95,1,.55),Color(.8,.92,1,0)])
	mist.emitting = true
	glints = Vfx.particles(self,40,1.1,true,true)
	glints.explosiveness = .8
	glints.direction = Vector3(1,0,0)
	glints.spread = 180
	glints.flatness = .7
	glints.initial_velocity_min = radius*1.2
	glints.initial_velocity_max = radius*2.6
	glints.damping_min = radius*2.0
	glints.damping_max = radius*2.6
	glints.gravity = Vector3(0,.6,0)
	glints.position = Vector3.UP*.6
	glints.scale_amount_min = .06
	glints.scale_amount_max = .13
	glints.color_ramp = Vfx.ramp([0,.5,1],[Color(1,1,1,1),Color(.7,.9,1,.8),Color(.6,.85,1,0)])
	glints.emitting = true
	game.sound.play("whirl-impact",-10)
	tick(0.0)

func ground_sprite(diameter: float, gradient: Gradient) -> Sprite3D:
	var texture = GradientTexture2D.new()
	texture.width = 128; texture.height = 128
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(.5,.5); texture.fill_to = Vector2(1,.5)
	texture.gradient = gradient
	var sprite = Sprite3D.new()
	sprite.texture = texture
	sprite.pixel_size = diameter/128.0
	sprite.rotation.x = -PI/2
	sprite.position = Vector3.UP*.03
	sprite.shaded = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprite)
	return sprite

# Returns false once every part of the effect has finished.
func tick(dt: float) -> bool:
	age += dt
	var t = age
	var wave = minf(1.0,t/WAVE_TIME)
	var eased = 1.0-pow(1.0-wave,3.0)
	flash.light_energy = 5.5*exp(-t*5.0)
	shock.scale = Vector3.ONE*lerpf(.1,1.05,eased)
	shock.modulate.a = .95*(1.0-smoothstep(.55,1.0,wave))
	frost.modulate.a = minf(1.0,t/WAVE_TIME)*clampf((LIFETIME-t)/1.2,0.0,1.0)
	# Shards streak out along the ground to the edge of the blast, then melt.
	var shard_fade = clampf((t-WAVE_TIME)/.35,0.0,1.0)
	for s in shards:
		var r = radius*s.reach*eased
		s.node.position = s.dir*r+Vector3.UP*(s.lift*(1.0-.5*eased))
		s.node.visible = shard_fade<1.0
		s.node.scale = s.size*Vector3(1,1,maxf(.001,1.0-shard_fade))
	# Spikes erupt as the wave reaches them, hold, then sink back into the frost.
	var spikes_left = false
	for s in spikes:
		var since = t-s.arrive
		var grow = clampf(since/.1,0.0,1.0)
		var sink = clampf((since-SPIKE_HOLD)/SPIKE_SINK,0.0,1.0)
		var h = 0.0 if since<0 else (1.0-pow(1.0-grow,2.0))*(1.0-sink*sink)
		s.node.scale = Vector3(s.height.x,maxf(.001,s.height.y*h),s.height.z)
		s.node.visible = h>.002
		spikes_left = spikes_left or sink<1.0
	ice.albedo_color.a = .82*clampf(1.0-(t-(WAVE_TIME+SPIKE_HOLD))/SPIKE_SINK*.5,.35,1.0)
	visible = game.world.can_see(position)
	return t<LIFETIME or spikes_left

func _process(_delta: float) -> void:
	Vfx.hold_when_paused(game,[mist,glints])
