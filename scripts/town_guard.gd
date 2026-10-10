extends Node3D
## A guard at one of the town's gates (scripts/world_town.gd): a man armored as
## the centurion statues are (tools/make_guard.py), at life size and in real
## steel, leather and wool, steel gauntlets on his hands. He stands his watch
## day and night, his spear grounded upright in his right fist
## (scripts/arm_reach.gd holds the hand to its grip) and his shield on his
## left forearm. He is no part of the town's round (scripts/townsfolk.gd): he
## keeps his post, or walks the town with another, until he is relieved or
## relieves another pair at theirs (scripts/town_watch.gd).
const Art = preload("res://scripts/assets.gd")
const ArmReach = preload("res://scripts/arm_reach.gd")
# Measured from him (he faces +Z, his right toward -X): where his right fist
# closes on the spear, and where his shield stands, turned out to his left.
const SPEAR_FIST = Vector3(-.3,1.0,.24)
# His spear's parts, each what it is made of (tools/make_spear.py), as
# assets/shaders/spear.gdshader's `part`.
const SPEAR_PARTS = {"Head":0,"Socket":0,"Rivet":0,"Butt":0,"Shaft":1,"Grip":2}
const SHIELD_SIZE = Vector3(.6,1.0,.2)
# The stance he keeps on watch, spear grounded and shield on his arm.
const WATCH = "SpearShieldIdle"
static var materials: Dictionary = {}

var figure: Node3D
var skeleton: Skeleton3D
var animator: AnimationPlayer
var hands: Dictionary = {}
var spear: Node3D
var shield: Node3D

# `variant` (0…1) sets him apart from the next man: his armor's wear and where
# his breathing is when he is first seen.
func setup(variant: float) -> void:
	figure = load("res://assets/models/character/town_guard.glb").instantiate()
	add_child(figure)
	skeleton = figure.find_children("*","Skeleton3D",true,false)[0]
	animator = figure.find_children("*","AnimationPlayer",true,false)[0]
	var armor = ShaderMaterial.new()
	armor.shader = load("res://assets/shaders/guard_armor.gdshader")
	armor.set_shader_parameter("palette",load("res://assets/models/character/warrior_knight_texture.png"))
	armor.set_shader_parameter("grit",load("res://assets/textures/rock_detail.jpg"))
	armor.set_shader_parameter("rest_pose",true)
	armor.set_shader_parameter("seed",variant)
	for mesh in skeleton.find_children("*","MeshInstance3D",true,false):
		var part: String = mesh.name
		if part == "Body": mesh.material_override = Art.hero_kit("warrior")
		elif part == "Eyes": mesh.material_override = shared("eyes")
		elif part == "Eyebrows": mesh.material_override = shared("brows")
		elif part.begins_with("Armor"):
			if mesh.mesh is ArrayMesh: mesh.mesh = Art.rest_pose_mesh(mesh.mesh)
			mesh.material_override = armor
			if part == "ArmorGauntlets":
				var gauntlets: ShaderMaterial = armor.duplicate()
				gauntlets.set_shader_parameter("gauntlet",true)
				mesh.material_override = gauntlets
		mesh.extra_cull_margin = 1.0
	# His spear (a legionary's hasta), its butt on the ground below his fist,
	# its blade's flat turned to the front; no two quite alike.
	spear = Art.model("hasta",Vector3.ONE)
	for mesh in spear.find_children("*","MeshInstance3D",true,false):
		var finish = ShaderMaterial.new()
		finish.shader = load("res://assets/shaders/spear.gdshader")
		finish.set_shader_parameter("part",SPEAR_PARTS.get(String(mesh.name),1))
		finish.set_shader_parameter("blade",mesh.name == "Head")
		finish.set_shader_parameter("seed",variant)
		mesh.material_override = finish
	add_child(spear)
	spear.position = Vector3(SPEAR_FIST.x,0,SPEAR_FIST.z)
	spear.rotation.y = (variant-.5)*.3
	# His shield, on his left forearm (laid along it every frame: strap).
	shield = Art.model("scutum",Vector3.ONE)
	var board = ShaderMaterial.new()
	board.shader = load("res://assets/shaders/guard_shield.gdshader")
	board.set_shader_parameter("grit",load("res://assets/textures/rock_detail.jpg"))
	board.set_shader_parameter("size",SHIELD_SIZE)
	board.set_shader_parameter("seed",variant)
	for mesh in shield.find_children("*","MeshInstance3D",true,false): mesh.material_override = board
	add_child(shield)
	shield.top_level = true
	for side in ["l","r"]:
		var arm = ArmReach.new()
		arm.side = side
		arm.tool = true
		arm.curl = 1.0
		arm.weight = 1.0 if side == "r" else 0.0
		skeleton.add_child(arm)
		hands[side] = arm
	var clip = WATCH
	animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	animator.play(clip)
	animator.seek(variant*animator.get_animation(clip).length,true)

# Walking, he carries his spear and shield CARRY metres off the ground, at
# a stride that covers STRIDE metres a second at the clip's own pace.
const CARRY = .12
const STRIDE = 1.25
var walking = false

func walk(speed: float) -> void:
	if not walking:
		walking = true
		animator.play("Walk",.25)
		animator.get_animation("Walk").loop_mode = Animation.LOOP_LINEAR
	animator.speed_scale = speed/STRIDE

func stand() -> void:
	if not walking: return
	walking = false
	animator.play(WATCH,.35)
	animator.speed_scale = 1.0

# Turns him toward `direction`, at `quickness`.
func turn_to(direction: Vector3, delta: float, quickness: float = 7.0) -> void:
	if Vector2(direction.x,direction.z).length() < .01: return
	rotation.y = lerp_angle(rotation.y,atan2(direction.x,direction.z),minf(1.0,delta*quickness))

# The spear's hand goes to its grip wherever he stands (found in the world,
# so he must be placed first); walking, his shield hand is held at CARRY_FIST,
# its fist round the shield's grip, so the shield is carried before him
# rather than swung; and the shield is laid along that forearm.
const CARRY_FIST = Vector3(.3,.95,.3)
func _process(delta: float) -> void:
	var lift = Vector3.UP*(CARRY if walking else 0.0)
	spear.position = Vector3(SPEAR_FIST.x,0,SPEAR_FIST.z)+lift
	var frame: Transform3D = global_transform
	hands.r.target = frame*(SPEAR_FIST+lift)
	hands.r.axis = frame.basis*Vector3.UP
	hands.l.weight = move_toward(hands.l.weight,1.0 if walking else 0.0,delta*4.0)
	hands.l.target = frame*CARRY_FIST
	hands.l.axis = frame.basis*Vector3.RIGHT
	strap()

# The shield laid along his left forearm, its back against the outside of
# it, its face turned out the way he faces and held upright as nearly as the
# forearm allows, crossed by the forearm a little above its middle (STRAP).
const STRAP = .6
func strap() -> void:
	var at = func(bone: String) -> Vector3: return skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin
	var elbow: Vector3 = at.call("lowerarm_l")
	var wrist: Vector3 = at.call("hand_l")
	var forearm: Vector3 = (wrist-elbow).normalized()
	var facing: Basis = global_basis.orthonormalized()
	var out: Vector3 = facing.z-forearm*facing.z.dot(forearm)
	if out.length() < .35: out = facing.x-forearm*facing.x.dot(forearm)
	out = out.normalized()
	var up: Vector3 = facing.y-out*facing.y.dot(out)
	if up.length() < .2: up = facing.y
	var side: Vector3 = up.normalized().cross(out).normalized()
	up = out.cross(side).normalized()
	var middle: Vector3 = elbow.lerp(wrist,.55)+out*(.045+SHIELD_SIZE.z*.5)
	shield.global_transform = Transform3D(Basis(side*SHIELD_SIZE.x,up*SHIELD_SIZE.y,out*SHIELD_SIZE.z),middle-up*SHIELD_SIZE.y*STRAP)

static func shared(kind: String) -> StandardMaterial3D:
	if materials.has(kind): return materials[kind]
	var m = StandardMaterial3D.new()
	if kind == "eyes":
		m.albedo_texture = load("res://assets/models/character/warrior_T_Eye_Brown.png")
		m.roughness = .3
	else:
		m.albedo_texture = load("res://assets/textures/hair_1.jpg")
		m.albedo_color = Color(.2,.14,.1)*2.2
		m.roughness = .6
	materials[kind] = m
	return m
