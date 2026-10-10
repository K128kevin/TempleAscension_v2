extends Node3D
## One of the town's people: a figure of the base character pack in the
## clothes tools/make_townsfolk.py fits to it, as its `look` says:
##   who       "man" or "woman" (which body)
##   garment   its garment (scripts/wardrobe.gd), and `under` one worn beneath
##   cloth     the garment's colour; `wear` how worn out (0 kept … 1 rags);
##             `weave` "linen" or "hessian"; `under_cloth` the under-garment's
##   skin      "light" or "dark", and `tone`, a tint over it; `dirt` 0…1
##   hair      a hairstyle of that body's, or ""; `hair_colour`; `beard`; `braid`
##   belt      a colour, or null for none
##   shoes     a colour of leather, or none: most go barefoot
##   size      its height against the body's own (a child is about .6)
##   bulk      0 as the body comes; 1 broad and heavy (thick trunk, arms and neck)
const Kit = preload("res://scripts/world_art.gd")
const Art = preload("res://scripts/assets.gd")
const Wardrobe = preload("res://scripts/wardrobe.gd")
const LOOPS = ["Idle","Talk","Walk","Jog","Sit","SitTalk","Dance","Carry","Arms"]
# The ground each stride covers a second as the library authored it, for a
# figure of full size.
const STRIDE = {"Walk":1.0,"Jog":2.9,"Carry":1.0}
# How a mug is held, as a mug is: the fingers through its handle and
# wrapped round the handle's bar, the thumb resting on top, the mug's body
# off the palm's side. In the hand bone's space (X toward the palm, Y along
# the fingers, Z across the palm toward the thumb) the handle's bar lies in
# the curl of the fingers and the mug's base is GRIP_AT, its axis along Z
# (GRIP_MUG turns it so; the model's handle is on its +X side, its body
# off-centre the other way, as the prop was centred on its bounds). GRIP_HAND is how the fist is turned, relative to
# the figure, to hold the mug upright: palm inward, fingers forward, thumb up.
const GRIP_AT = Vector3(.135,.13,-.10)
const GRIP_MUG = Basis(Vector3(-1,0,0),Vector3(0,0,1),Vector3(0,1,0))
const GRIP_HAND = Basis(Vector3(-1,0,0),Vector3(0,0,1),Vector3(0,1,0))
# The arm that lifts the mug, and the head that meets it.
const DRINKING = ["clavicle_l","upperarm_l","lowerarm_l","hand_l","index","middle","ring","pinky","thumb","neck_01","Head"]
static var materials: Dictionary = {}

var look: Dictionary = {}
var figure: Node3D
var skeleton: Skeleton3D
var animator: AnimationPlayer
var state = ""
# How it lies asleep: "Lie" on its back, "LieLeft" or "LieRight" on that side
# (the game's "Lie" plays this).
var sleep_pose = "Lie"
var size = 1.0
# What it holds in its left hand (a mug), if anything.
var held: Node3D
var hand: BoneAttachment3D
# Where a held thing sits in the hand, at its own size.
var grip: Node3D
# The left arm, reaching for what the hand goes to (scripts/arm_reach.gd).
var arm: SkeletonModifier3D

func setup(appearance: Dictionary) -> void:
	look = appearance
	size = look.get("size",1.0)
	figure = load("res://assets/models/character/towns%s.glb" % look.who).instantiate()
	add_child(figure)
	figure.scale = Vector3.ONE*size
	skeleton = figure.find_children("*","Skeleton3D",true,false)[0]
	animator = figure.find_children("*","AnimationPlayer",true,false)[0]
	for clip in animator.get_animation_list():
		animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR if clip in LOOPS else Animation.LOOP_NONE
	seated_drink()
	lying()
	var cover: Dictionary = Wardrobe.COVER[look.who]
	var worn: Array = [look.garment]
	if look.get("under","") != "": worn.append(look.under)
	var wear: float = look.get("wear",0.0)
	for mesh in skeleton.find_children("*","MeshInstance3D",true,false):
		var part: String = mesh.name
		var keep = true
		var material: Material = null
		if part == "Body": material = flesh(cover,worn,wear)
		elif part == "Eyes": material = shared("eyes")
		elif part == "Eyebrows": material = hair_material(1 if look.who == "man" else 2)
		elif part.begins_with("Hair_"):
			keep = part == look.get("hair","") or (part == "Hair_Beard" and look.get("beard",false))
			if keep: material = hair_material(2 if part in ["Hair_Long","Hair_Buns"] else 1)
		elif part == "Braid":
			keep = look.get("braid",false)
			if keep: material = hair_material(0)
		elif part == "Belt":
			keep = look.get("belt") != null
			if keep: material = belt_material(look.belt)
		else:
			keep = part in worn
			if keep: material = cloth(look.cloth if part == look.garment else look.get("under_cloth",Color(.86,.84,.78)),wear if part == look.garment else wear*.5,look.get("weave","linen") if part == look.garment else "linen")
		if not keep:
			mesh.free()
			continue
		mesh.material_override = material
		# Shoes are drawn over the feet (assets/shaders/shoes.gdshader).
		if part == "Body" and look.get("shoes") != null:
			var shoes = ShaderMaterial.new()
			shoes.shader = load("res://assets/shaders/shoes.gdshader")
			shoes.set_shader_parameter("leather",look.shoes)
			shoes.set_shader_parameter("grit",load("res://assets/textures/rock_detail.jpg"))
			mesh.material_overlay = shoes
		# (A figure's bounds follow its skeleton; a seated or reaching one
		# must not be culled by where it stood at rest.)
		mesh.extra_cull_margin = 1.0
	starve(look.get("gaunt",0.0))
	# A child's head is large for its body.
	if look.get("child",false): skeleton.set_bone_pose_scale(skeleton.find_bone("Head"),Vector3.ONE*1.22)
	# A heavy build: the whole figure broadened across and through (its own
	# frame turns with it, so the bulk never shears as the limbs move).
	var bulk: float = look.get("bulk",0.0)
	if bulk > 0.0: figure.scale = Vector3(1.0+.22*bulk,1.0,1.0+.22*bulk)*size
	hand = BoneAttachment3D.new()
	# (The library's drinker lifts the left hand.)
	hand.bone_name = "hand_l"
	skeleton.add_child(hand)
	grip = Node3D.new()
	hand.add_child(grip)
	arm = preload("res://scripts/arm_reach.gd").new()
	arm.name = "ArmReach"
	skeleton.add_child(arm)
	# In the palm, upright when the forearm is level; a thing keeps its own
	# size and shape in any hand (pin).
	pin_to_hand(grip,"hand_l",GRIP_MUG,GRIP_AT)
	skeleton.skeleton_updated.connect(pin)
	arms = {"l":arm}
	hands = {"l":hand}
	play("Idle",0.0)

# The library's drinker stands. A seated one keeps the sitting pose and takes
# the drinking arm and head from it: the clip "SitDrink", made once for each
# body.
func seated_drink() -> void:
	var library: AnimationLibrary = animator.get_animation_library(animator.get_animation_library_list()[0])
	if library.has_animation("SitDrink"): return
	var sit: Animation = animator.get_animation("Sit")
	var made: Animation = animator.get_animation("Drink").duplicate(true)
	for track in made.get_track_count():
		var bone: String = String(made.track_get_path(track)).get_slice(":",1)
		var lifts = bone.ends_with("_l") or bone in ["neck_01","Head"]
		if lifts and DRINKING.any(func(part): return bone.begins_with(part)): continue
		var kind = made.track_get_type(track)
		var source = sit.find_track(made.track_get_path(track),kind)
		if source < 0: continue
		for key in made.track_get_key_count(track):
			var time = fposmod(made.track_get_key_time(track,key),sit.length)
			if kind == Animation.TYPE_ROTATION_3D: made.track_set_key_value(track,key,sit.rotation_track_interpolate(source,time))
			elif kind == Animation.TYPE_POSITION_3D: made.track_set_key_value(track,key,sit.position_track_interpolate(source,time))
	made.loop_mode = Animation.LOOP_NONE
	library.add_animation("SitDrink",made)

# Asleep, on the back: the clip "Lie", the first moment of getting up off the
# ground held still, made once for each body. (Getting up, played backward,
# lies down: lie_down.)
func lying() -> void:
	var library: AnimationLibrary = animator.get_animation_library(animator.get_animation_library_list()[0])
	if library.has_animation("Lie"): return
	var made: Animation = animator.get_animation("GetUp").duplicate(true)
	for track in made.get_track_count():
		for key in range(made.track_get_key_count(track)-1,0,-1): made.track_remove_key(track,key)
	made.length = 1.0
	made.loop_mode = Animation.LOOP_LINEAR
	library.add_animation("Lie",made)
	library.add_animation("LieLeft",on_side(made,"l"))
	library.add_animation("LieRight",on_side(made,"r"))

# Asleep on one side (`side` "l" or "r"), made from lying on the back: the
# body rolled over onto that side about its length, the knees drawn up, the
# arms brought forward (the under one bent up under the head), the back
# curled a little and the head let down toward the ground; then let down
# itself until its lowest point is as low as on its back, so it rests on the
# ground or the bed as that does.
const ROLL = 1.5
func on_side(lie: Animation, side: String) -> Animation:
	animator.play("Lie",0.0)
	animator.seek(0.0,true)
	skeleton.force_update_all_bone_transforms()
	var resting = lowest()
	var bone = func(name: String) -> int: return skeleton.find_bone(name)
	var at = func(name: String) -> Vector3: return skeleton.get_bone_global_pose(bone.call(name)).origin
	var pelvis: int = bone.call("pelvis")
	var length: Vector3 = (at.call("neck_01")-at.call("pelvis")).normalized()
	# Over onto the named side: its shoulder goes down.
	var other = "r" if side == "l" else "l"
	var roll = Basis(length,ROLL)
	var under: Vector3 = roll*(at.call("upperarm_"+side)-at.call("pelvis"))
	var over: Vector3 = roll*(at.call("upperarm_"+other)-at.call("pelvis"))
	if under.y > over.y: roll = Basis(length,-ROLL)
	turn(pelvis,roll)
	var front: Vector3 = roll*Vector3.UP
	var across: Vector3 = (at.call("thigh_l")-at.call("thigh_r")).normalized()
	# Each joint bends about the line across the body, the way that carries
	# its limb toward `toward`.
	var bend = func(name: String, angle: float, toward: Vector3) -> void:
		var i: int = bone.call(name)
		var child: int = skeleton.get_bone_children(i)[0]
		var reach: Vector3 = skeleton.get_bone_global_pose(child).origin-skeleton.get_bone_global_pose(i).origin
		var turned = Basis(across,angle)
		if (turned*reach-reach).dot(toward) < 0.0: turned = Basis(across,-angle)
		turn(i,turned)
	bend.call("spine_02",.18,front)
	bend.call("thigh_"+side,.95,front)
	bend.call("thigh_"+other,.75,front)
	bend.call("calf_"+side,1.2,-front)
	bend.call("calf_"+other,1.0,-front)
	bend.call("upperarm_"+side,1.55,front)
	bend.call("lowerarm_"+side,1.7,length)
	bend.call("upperarm_"+other,.7,front)
	bend.call("lowerarm_"+other,.9,front)
	# The head let down toward the ground, onto the under arm.
	var neck: int = bone.call("neck_01")
	var head_way: Vector3 = at.call("Head")-at.call("neck_01")
	var tilt = Basis(length,.3)
	if (tilt*head_way-head_way).y > 0.0: tilt = Basis(length,-.3)
	turn(neck,tilt)
	# Down (or up) to rest where lying on the back rests.
	var drop: float = lowest()-resting
	var global: Transform3D = skeleton.get_bone_global_pose(pelvis)
	global.origin.y -= drop
	var parent = skeleton.get_bone_parent(pelvis)
	var local: Transform3D = (skeleton.get_bone_global_pose(parent).affine_inverse() if parent >= 0 else Transform3D())*global
	skeleton.set_bone_pose_position(pelvis,local.origin)
	skeleton.force_update_all_bone_transforms()
	var made: Animation = lie.duplicate(true)
	for track in made.get_track_count():
		var i = skeleton.find_bone(String(made.track_get_path(track)).get_slice(":",1))
		if i < 0: continue
		match made.track_get_type(track):
			Animation.TYPE_ROTATION_3D: made.track_set_key_value(track,0,skeleton.get_bone_pose_rotation(i))
			Animation.TYPE_POSITION_3D: made.track_set_key_value(track,0,skeleton.get_bone_pose_position(i))
	return made

# Turns bone `i` by `by` (in the skeleton's space) about its own joint.
func turn(i: int, by: Basis) -> void:
	var global: Basis = by*skeleton.get_bone_global_pose(i).basis
	var parent = skeleton.get_bone_parent(i)
	var local: Basis = (skeleton.get_bone_global_pose(parent).basis.inverse() if parent >= 0 else Basis())*global
	skeleton.set_bone_pose_rotation(i,local.get_rotation_quaternion())
	skeleton.force_update_all_bone_transforms()

# The height of the lowest point of the body's flesh as it is posed (in the
# skeleton's space), from every third point of it.
func lowest() -> float:
	var body: MeshInstance3D = null
	for mesh in skeleton.find_children("*","MeshInstance3D",true,false):
		if mesh.name == "Body": body = mesh
	if body == null: return 0.0
	var arrays = body.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var per: int = bones.size()/points.size()
	var skin: Skin = body.skin
	var binds: Array[Transform3D] = []
	for b in skin.get_bind_count():
		var i = skin.get_bind_bone(b)
		if i < 0: i = skeleton.find_bone(skin.get_bind_name(b))
		binds.append(skeleton.get_bone_global_pose(i)*skin.get_bind_pose(b))
	var low = INF
	for v in range(0,points.size(),3):
		var placed = Vector3.ZERO
		for k in per:
			var w = weights[v*per+k]
			if w > 0.0: placed += (binds[bones[v*per+k]]*points[v])*w
		low = minf(low,placed.y)
	return low

func lie_down(rate: float, blend: float = .3) -> void:
	state = "LieDown"
	animator.play("GetUp",blend,-rate,true)

# Gone thin with hunger (0 fed, 1 starving): the body and what it wears
# drawn in by THIN metres along each bone (assets/shaders/gaunt.gdshaderinc),
# the frame a little narrower across (GAUNT_FRAME), the skin sallow and
# pale (GAUNT_TONE).
const THIN = {"pelvis":.02,"spine_01":.028,"spine_02":.03,"spine_03":.025,"neck_01":.012,"Head":.004,
	"clavicle_l":.01,"clavicle_r":.01,"upperarm_l":.02,"upperarm_r":.02,"lowerarm_l":.014,"lowerarm_r":.014,
	"thigh_l":.027,"thigh_r":.027,"calf_l":.017,"calf_r":.017}
const GAUNT_FRAME = .08
const GAUNT_TONE = Color(.93,.9,.83)
const THIN_BINDS = 72
func starve(gaunt: float) -> void:
	if gaunt <= 0.0: return
	figure.scale = Vector3(1.0-GAUNT_FRAME*gaunt,1.0,1.0-GAUNT_FRAME*gaunt)*size
	for mesh in skeleton.find_children("*","MeshInstance3D",true,false):
		if mesh.skin == null or not mesh.material_override is ShaderMaterial: continue
		var thin = PackedFloat32Array()
		thin.resize(THIN_BINDS)
		for i in mini(mesh.skin.get_bind_count(),THIN_BINDS):
			var bone: String = String(mesh.skin.get_bind_name(i))
			if bone.is_empty() and mesh.skin.get_bind_bone(i) >= 0: bone = skeleton.get_bone_name(mesh.skin.get_bind_bone(i))
			thin[i] = THIN.get(bone,0.0)
		var material: ShaderMaterial = mesh.material_override
		while material != null:
			material.set_shader_parameter("gaunt",gaunt)
			material.set_shader_parameter("thin",thin)
			if mesh.name == "Body" and material.shader.resource_path.ends_with("townsfolk_skin.gdshader"):
				var tone: Vector3 = material.get_shader_parameter("tone")
				material.set_shader_parameter("tone",tone.lerp(tone*Vector3(GAUNT_TONE.r,GAUNT_TONE.g,GAUNT_TONE.b),gaunt))
			material = material.next_pass as ShaderMaterial

# A belt of worn leather, its own (so it is drawn in with its wearer when he
# starves: starve, as his body and clothes are).
func belt_material(tint: Color) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = load("res://assets/shaders/townsfolk_belt.gdshader")
	m.set_shader_parameter("leather",Vector3(tint.r,tint.g,tint.b))
	m.set_shader_parameter("grit",load("res://assets/textures/rock_detail.jpg"))
	return m

func flesh(cover: Dictionary, worn: Array, wear: float) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = load("res://assets/shaders/townsfolk_skin.gdshader")
	m.set_shader_parameter("skin",load("res://assets/textures/skin_%s_%s.jpg" % [look.who,look.get("skin","light")]))
	m.set_shader_parameter("grit",load("res://assets/textures/rock_detail.jpg"))
	var tone: Color = look.get("tone",Color.WHITE)
	m.set_shader_parameter("tone",Vector3(tone.r,tone.g,tone.b))
	m.set_shader_parameter("dirt",look.get("dirt",0.0))
	# What the clothes hide. Rags hide nothing: their holes show the skin.
	var top = 0.0
	var hem = 99.0
	var sleeve = 0.0
	for garment in worn:
		var reach: Array = cover[garment]
		top = maxf(top,reach[0])
		hem = minf(hem,reach[1])
		sleeve = maxf(sleeve,reach[2])
	if wear < .7:
		m.set_shader_parameter("cover",Vector2(hem+.06,top-.03))
		m.set_shader_parameter("sleeve",maxf(0.0,sleeve-.05))
	return m

func cloth(colour: Color, wear: float, weave: String) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = load("res://assets/shaders/cloth.gdshader")
	m.set_shader_parameter("weave",load("res://assets/textures/cloth_%s.jpg" % weave))
	m.set_shader_parameter("grit",load("res://assets/textures/rock_detail.jpg"))
	m.set_shader_parameter("weave_scale",{"linen":4.0,"hessian":5.0}[weave])
	m.set_shader_parameter("dye",Vector3(colour.r,colour.g,colour.b))
	m.set_shader_parameter("wear",wear)
	m.set_shader_parameter("seed",look.get("seed",0.0))
	# The cloth's inside is drawn by a second pass with the same settings.
	var inside: ShaderMaterial = m.duplicate()
	inside.shader = load("res://assets/shaders/cloth_inside.gdshader")
	m.next_pass = inside
	return m

func hair_material(sheet: int) -> StandardMaterial3D:
	var colour: Color = look.get("hair_colour",Color(.2,.14,.1))
	var key = "hair%d%s" % [sheet,colour.to_html()]
	if materials.has(key): return materials[key]
	var m = StandardMaterial3D.new()
	# (The pack's hair sheets are mid-brown; the tint takes them darker or grey.)
	if sheet > 0: m.albedo_texture = load("res://assets/textures/hair_%d.jpg" % sheet)
	m.albedo_color = colour*(2.2 if sheet > 0 else 1.0)
	m.roughness = .6
	m.metallic_specular = .3
	materials[key] = m
	return m

static func shared(kind: String) -> StandardMaterial3D:
	if materials.has(kind): return materials[kind]
	var m = StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/models/character/warrior_T_Eye_Brown.png")
	m.roughness = .3
	materials[kind] = m
	return m

func play(clip: String, blend: float = .25, rate: float = 1.0) -> void:
	# Asleep as it sleeps; rolling over onto its side takes a moment.
	if clip == "Lie" and sleep_pose != "Lie":
		clip = sleep_pose
		if blend > 0.0: blend = maxf(blend,.9)
	if clip == state and animator.is_playing():
		animator.speed_scale = rate
		return
	state = clip
	animator.play(clip,blend,rate)
	animator.speed_scale = 1.0

# Walking or running at `speed` metres a second: the stride keeps pace.
func stride(clip: String, speed: float) -> void:
	var rate = clampf(speed/(STRIDE[clip]*size),.4,2.6)
	if clip != state:
		state = clip
		animator.play(clip,.25,rate)
	else: animator.play(clip,-1,rate)

func length(clip: String) -> float:
	return animator.get_animation(clip).length

# --- A mug taken up by its handle (a patron drinking: scripts/townsfolk.gd
# sip) -------------------------------------------------------------------------

# Each arm and hand by side ("l", "r"); the right ones made when first wanted.
var arms: Dictionary = {}
var hands: Dictionary = {}
# Where a handle sits in each fist: through it, across the palm toward the
# thumb (the thing's own up), its body out on the palm's side.
var handle_grips: Dictionary = {}
# The mug model's handle, rim (middle) and base (middle), in its own unit
# box (assets: the "mug" prop, its handle on its +X side); its rim's radius
# at its own size, in metres.
const MUG_HANDLE = Vector3(.42,.6,0)
const MUG_RIM = Vector3(-.125,.985,0)
const MUG_BASE = Vector3(-.125,0,0)
const MUG_RIM_RADIUS = .068

func drinking_arm(side: String) -> SkeletonModifier3D:
	if not arms.has(side):
		var other = preload("res://scripts/arm_reach.gd").new()
		other.name = "ArmReach_"+side
		other.side = side
		skeleton.add_child(other)
		arms[side] = other
		var attached = BoneAttachment3D.new()
		attached.bone_name = "hand_"+side
		skeleton.add_child(attached)
		hands[side] = attached
	if not handle_grips.has(side):
		var reaching = arms[side]
		reaching.measure(skeleton,skeleton.find_bone("hand_"+side))
		var face: Vector3 = reaching.along.cross(reaching.across)
		if face.dot(reaching.palm-reaching.along*reaching.palm.dot(reaching.along)) < 0.0: face = -face
		var handle = Node3D.new()
		hands[side].add_child(handle)
		# (Its +X, from the mug's body to its handle, is away from the palm.)
		var turn = Basis(-face,reaching.across,(-face).cross(reaching.across)).orthonormalized()
		pin_to_hand(handle,"hand_"+side,turn,reaching.palm)
		handle_grips[side] = handle
	return arms[side]

# What is held is held in the hand's place and turn, but never in its scale:
# a starving or heavy figure is drawn narrower or broader across than up
# (starve, setup's bulk), and a mug in such a hand, turned with it, would be
# sheared out of true. So each holder (a grip, a handle's place) stands apart
# from the hand (top-level) and is set every time the skeleton is posed:
# where the hand's bone puts `at`, turned as the bone is (squared up, unscaled)
# and then by `turn`.
var pins: Array = []
func pin_to_hand(holder: Node3D, bone: String, turn: Basis, at: Vector3) -> void:
	holder.top_level = true
	pins.append({"node":holder,"bone":skeleton.find_bone(bone),"turn":turn,"at":at})
	pin()

# (Only while the skeleton is posed, when its bones are where its reaching
# arms have put them: read at any other time they are the clip's alone.)
func pin() -> void:
	if not skeleton.is_inside_tree(): return
	for p in pins:
		var bone: Transform3D = skeleton.global_transform*skeleton.get_bone_global_pose(p.bone)
		p.node.global_transform = Transform3D(bone.basis.orthonormalized()*p.turn,bone*p.at)
	# (Beer in what is held is levelled again where the hand now has it.)
	if is_instance_valid(held) and held.has_meta("beer") and is_instance_valid(held.get_meta("beer")): held.get_meta("beer").settle()

# The mug in the `side` hand, its handle in the fist: placed as it is now
# (`settle` 0) or as the fist holds it (1), between the two as it settles.
func grasp(mug: Node3D, side: String, settle: float = 1.0) -> void:
	drinking_arm(side)
	var handle: Node3D = handle_grips[side]
	var was: Transform3D = mug.global_transform
	if mug.get_parent() != handle:
		if mug.get_parent() != null: mug.get_parent().remove_child(mug)
		handle.add_child(mug)
		mug.global_transform = was
		mug.set_meta("taken",mug.transform)
	held = mug
	settle_grasp(settle)

func settle_grasp(settle: float) -> void:
	if not is_instance_valid(held) or not held.has_meta("taken"): return
	var scale: Vector3 = held.transform.basis.get_scale()
	var fist = Transform3D(Basis.from_scale(scale),-(Basis.from_scale(scale)*MUG_HANDLE))
	var taken: Transform3D = held.get_meta("taken")
	# (Turned, then sized in its own frame: sized first, it would be
	# stretched along whatever way it is turned.)
	held.transform = Transform3D(Basis(taken.basis.get_rotation_quaternion().slerp(fist.basis.get_rotation_quaternion(),settle))*Basis.from_scale(scale),taken.origin.lerp(fist.origin,settle))

# Carries the `side` hand to hold a handle at `handle_point` running along
# `up` (the mug's own up), the wrist straight, the whole arm turning to tip
# it (scripts/arm_reach.gd upright); `weight` and `curl` as reach's.
func drink_reach(side: String, handle_point: Vector3, up: Vector3, weight: float, curl: float) -> void:
	var reaching = drinking_arm(side)
	reaching.tool = true
	reaching.upright = true
	reaching.target = handle_point
	reaching.axis = up
	reaching.weight = weight
	reaching.curl = curl

# Lets the arms go back to the animation, and whatever was held go.
func let_go() -> void:
	for side in arms:
		arms[side].weight = 0.0
		arms[side].curl = 0.0
		arms[side].tool = false
		arms[side].upright = false

# His lips, in the world: from his nose's tip (found once a figure, from the
# head's own vertices: the furthest forward), a little below and behind it.
static var lip_points: Dictionary = {}
const LIPS_BELOW_NOSE = Vector3(0,-.05,-.012)
func lips() -> Vector3:
	var head = skeleton.find_bone("Head")
	if not lip_points.has(look.who):
		var nose = Vector3.ZERO
		var front = -INF
		for mesh in skeleton.find_children("*","MeshInstance3D",true,false):
			if mesh.name != "Body" or mesh.skin == null: continue
			var bind = -1
			for b in mesh.skin.get_bind_count():
				if mesh.skin.get_bind_name(b) == "Head" or mesh.skin.get_bind_bone(b) == head: bind = b
			var arrays = mesh.mesh.surface_get_arrays(0)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones = arrays[Mesh.ARRAY_BONES]
			var weights = arrays[Mesh.ARRAY_WEIGHTS]
			var per: int = bones.size()/maxi(points.size(),1)
			for i in points.size():
				var on_head = 0.0
				for k in per:
					if bones[i*per+k] == bind: on_head += weights[i*per+k]
				if on_head > .5 and points[i].z > front:
					front = points[i].z
					nose = points[i]
		lip_points[look.who] = skeleton.get_bone_global_rest(head).affine_inverse()*(nose+LIPS_BELOW_NOSE)
	return skeleton.global_transform*skeleton.get_bone_global_pose(head)*lip_points[look.who]

# Puts a thing in its left hand (or takes it away, with null).
func hold(thing: Node3D) -> void:
	if is_instance_valid(held) and held.get_parent() == grip: grip.remove_child(held)
	held = thing
	if thing == null: return
	if thing.get_parent() != null: thing.get_parent().remove_child(thing)
	grip.add_child(thing)
	thing.position = Vector3.ZERO
	thing.rotation = Vector3.ZERO

# Carries the hand to a point in the world (`weight` 1), or lets it go back to
# the animation (0); the fist closes on a handle as `curl` says, and the
# elbow swings out from the body as `splay` says (scripts/arm_reach.gd).
# `tip` tilts what is held (radians) toward him, as a mug at the lips is.
func reach(point: Vector3, weight: float, curl: float = -1.0, splay: float = 0.0, tip: float = 0.0) -> void:
	arm.tool = false
	arm.upright = false
	if weight <= 0.0 and curl <= 0.0: let_go()
	arm.target = point
	arm.splay = splay
	arm.weight = weight
	arm.grip = global_transform.basis*Basis(Vector3.RIGHT,-tip)*GRIP_HAND
	if curl >= 0.0: arm.curl = curl

# Where a mug stands when the hand is at `point`, and the reverse.
func mug_at(hand_point: Vector3) -> Vector3:
	return hand_point+global_transform.basis*GRIP_HAND*GRIP_AT
func hand_for(mug_point: Vector3) -> Vector3:
	return mug_point-global_transform.basis*GRIP_HAND*GRIP_AT

func turn_to(direction: Vector3, delta: float, quickness: float = 9.0) -> void:
	if direction.length_squared() < .0001: return
	rotation.y = lerp_angle(rotation.y,atan2(direction.x,direction.z),minf(1.0,delta*quickness))
