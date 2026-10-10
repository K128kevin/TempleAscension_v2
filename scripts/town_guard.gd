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

# `variant` (0…1) sets him apart from the next man: his armor's wear and the
# set of his spear.
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
	var grip = ArmReach.new()
	grip.side = "r"
	grip.tool = true
	grip.curl = 1.0
	grip.weight = 1.0
	skeleton.add_child(grip)
	hands.r = grip
	pose_tree()

# Walking, he carries his spear and shield CARRY metres off the ground, at
# a stride that covers STRIDE metres a second at the clip's own pace (its
# feet, planted, pass back under him at that speed), so his feet never slide.
const CARRY = .12
const STRIDE = 1.0
var walking = false
# How fast he means to go, and how far into his walk he is (0 standing his
# watch, 1 walking), eased toward it (PACE_EASE a second) so a man who stops
# and starts again never jerks between the two.
var pace = 0.0
var stride_blend = 0.0
const PACE_EASE = 6.0

func walk(speed: float) -> void:
	walking = true
	pace = speed

func stand() -> void:
	walking = false
	pace = 0.0

# His body stands his watch (WATCH) or walks (Walk), the one blended into
# the other by how fast he goes; his left arm keeps the scutum bearer's
# carry (SHIELD_ARM, as the centurions hold theirs), the shield held up
# before him on his forearm whether he stands or walks.
const SHIELD_ARM = "ScutumSwordIdle"
const ARM_BONES = ["clavicle_l","upperarm_l","lowerarm_l","hand_l","thumb_","index_","middle_","ring_","pinky_"]
var tree: AnimationTree
func pose_tree() -> void:
	for clip in [WATCH,"Walk",SHIELD_ARM]: animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	var blend = AnimationNodeBlendTree.new()
	var still = AnimationNodeAnimation.new(); still.animation = WATCH
	var moving = AnimationNodeAnimation.new(); moving.animation = "Walk"
	var arm = AnimationNodeAnimation.new(); arm.animation = SHIELD_ARM
	var speed = AnimationNodeTimeScale.new()
	var body = AnimationNodeBlend2.new()
	var shield_arm = AnimationNodeBlend2.new()
	shield_arm.filter_enabled = true
	var held: Animation = animator.get_animation(SHIELD_ARM)
	for i in held.get_track_count():
		var path: NodePath = held.track_get_path(i)
		var bone: String = path.get_concatenated_subnames()
		if bone.ends_with("_l") and ARM_BONES.any(func(b): return bone.begins_with(b)): shield_arm.set_filter_path(path,true)
	blend.add_node("still",still,Vector2(0,0))
	blend.add_node("moving",moving,Vector2(0,150))
	blend.add_node("speed",speed,Vector2(200,150))
	blend.add_node("body",body,Vector2(400,50))
	blend.add_node("arm",arm,Vector2(400,250))
	blend.add_node("shield_arm",shield_arm,Vector2(600,100))
	blend.connect_node("speed",0,"moving")
	blend.connect_node("body",0,"still")
	blend.connect_node("body",1,"speed")
	blend.connect_node("shield_arm",0,"body")
	blend.connect_node("shield_arm",1,"arm")
	blend.connect_node("output",0,"shield_arm")
	tree = AnimationTree.new()
	tree.tree_root = blend
	figure.add_child(tree)
	tree.anim_player = tree.get_path_to(animator)
	tree.set("parameters/shield_arm/blend_amount",1.0)
	tree.set("parameters/body/blend_amount",0.0)
	tree.set("parameters/speed/scale",1.0)
	tree.active = true

# Turns him toward `direction`, at `quickness`.
func turn_to(direction: Vector3, delta: float, quickness: float = 7.0) -> void:
	if Vector2(direction.x,direction.z).length() < .01: return
	rotation.y = lerp_angle(rotation.y,atan2(direction.x,direction.z),minf(1.0,delta*quickness))

# The spear's hand goes to its grip wherever he stands (found in the world,
# so he must be placed first), and the shield is laid along his left forearm.
# Into his stride or out of it, as he means to go (scripts/town_watch.gd
# moves him at the pace his legs have come to).
var stride_rate = 1.0
func ease_pace(delta: float) -> void:
	stride_blend = move_toward(stride_blend,clampf(pace/STRIDE,0.0,1.0),delta*PACE_EASE)
	stride_rate = maxf(pace,STRIDE*.5)/STRIDE

func _process(delta: float) -> void:
	tree.set("parameters/body/blend_amount",stride_blend)
	tree.set("parameters/speed/scale",stride_rate)
	var lift = Vector3.UP*CARRY*stride_blend
	spear.position = Vector3(SPEAR_FIST.x,0,SPEAR_FIST.z)+lift
	var frame: Transform3D = global_transform
	hands.r.target = frame*(SPEAR_FIST+lift)
	hands.r.axis = frame.basis*Vector3.UP
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
