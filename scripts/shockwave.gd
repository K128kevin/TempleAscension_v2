extends Node3D
## The shockwave of a blow on the ground (Leap's landing, Ground Slam): a
## puff of dust and smoke bursting out from the point of impact and racing
## low over the ground across the whole area the blow reaches, all round for
## the leap and across the arc ahead for the slam. Translucent billows (the
## soft dot of scripts/vfx.gd, in dust's colours), thrown out at SPEED and
## slowing as they spread, swelling as they go and thinning to nothing.
const Vfx = preload("res://scripts/vfx.gd")
const SPEED = 26.0
var age = 0.0
var life = 1.0

# `plasma` (Ground Slam): the blade's charge blasts out with the dust, a burst
# of glowing blue plasma racing ahead of it and fading fast.
static func make(at: Vector3, reach: float, direction: Vector3 = Vector3.ZERO, degrees: float = 360.0, plasma: bool = false) -> Node3D:
	var node = new()
	node.position = at+Vector3.UP*.25
	node.life = clampf(reach/SPEED*2.2+.5,.9,1.8)
	var way: Vector3 = direction.normalized() if direction.length() > .01 else Vector3.FORWARD
	# A share of a full circle: the puff is as dense across an arc as all round.
	var share = degrees/360.0
	# Heavy dust low over the ground, racing out; thinner smoke above it,
	# slower and larger.
	for layer in [[int(120*share)+24,1.0,.55,Color(.72,.62,.46),.9,2.4],[int(70*share)+16,.72,.45,Color(.58,.52,.45),1.6,3.6]]:
		var puff = Vfx.particles(node,layer[0],node.life*layer[1],true,false)
		puff.mesh.size = Vector2.ONE
		puff.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		puff.emission_sphere_radius = .4
		puff.direction = way
		puff.spread = degrees*.5
		puff.flatness = .92
		puff.initial_velocity_min = SPEED*.6
		puff.initial_velocity_max = SPEED
		puff.damping_min = SPEED*1.1
		puff.damping_max = SPEED*1.6
		puff.gravity = Vector3(0,.4,0)
		puff.scale_amount_min = layer[4]
		puff.scale_amount_max = layer[5]
		puff.scale_amount_curve = Vfx.curve(.35,1.0)
		var tint: Color = layer[3]
		puff.color_ramp = Vfx.ramp([0.0,.15,.6,1.0],[Color(tint.r,tint.g,tint.b,0.0),Color(tint.r,tint.g,tint.b,layer[2]),Color(tint.r,tint.g,tint.b,layer[2]*.5),Color(tint.r,tint.g,tint.b,0.0)])
		puff.angle_min = 0.0
		puff.angle_max = 360.0
		puff.angular_velocity_min = -60.0
		puff.angular_velocity_max = 60.0
		puff.explosiveness = .95
		puff.emitting = true
	if plasma:
		var blast = Vfx.particles(node,int(50*share)+14,minf(node.life,.7),true,true)
		blast.mesh.size = Vector2.ONE
		blast.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		blast.emission_sphere_radius = .25
		blast.direction = way
		blast.spread = degrees*.5
		blast.flatness = .85
		blast.initial_velocity_min = SPEED*.7
		blast.initial_velocity_max = SPEED*1.15
		blast.damping_min = SPEED*1.4
		blast.damping_max = SPEED*2.0
		blast.gravity = Vector3(0,.6,0)
		blast.scale_amount_min = .6
		blast.scale_amount_max = 1.4
		blast.scale_amount_curve = Vfx.curve(.6,1.0)
		blast.color_ramp = Vfx.ramp([0.0,.08,.35,1.0],[Color(.5,.75,1,0),Color(.4,.65,1,.38),Color(.2,.42,1,.22),Color(.1,.25,1,0)])
		blast.explosiveness = .97
		blast.emitting = true
	return node

func tick(dt: float) -> bool:
	age += dt
	return age >= life+.2
