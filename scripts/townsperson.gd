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
##   size      its height against the body's own (a child is about .6)
const Kit = preload("res://scripts/world_art.gd")
const Art = preload("res://scripts/assets.gd")
const Wardrobe = preload("res://scripts/wardrobe.gd")
const LOOPS = ["Idle","Talk","Walk","Jog","Sit","SitTalk","Dance","Carry","Arms"]
# The ground each stride covers a second as the library authored it, for a
# figure of full size.
const STRIDE = {"Walk":1.0,"Jog":2.9,"Carry":1.0}
# Where a mug sits in the fist (its handle in the fingers, its body beyond
# them, off the palm's side), in the hand bone's space; how it is turned
# there; and how the fist itself is turned, relative to the figure, to hold
# it upright: palm inward, fingers forward, thumb up.
const GRIP_AT = Vector3(-.085,.03,-.115)
const GRIP_TURN = Vector3(0,0,-PI/2)
const GRIP_YAW = PI
const GRIP_HAND = Basis(Vector3(0,1,0),Vector3(0,0,1),Vector3(1,0,0))
# The arm that lifts the mug, and the head that meets it.
const DRINKING = ["clavicle_l","upperarm_l","lowerarm_l","hand_l","index","middle","ring","pinky","thumb","neck_01","Head"]
static var materials: Dictionary = {}

var look: Dictionary = {}
var figure: Node3D
var skeleton: Skeleton3D
var animator: AnimationPlayer
var state = ""
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
			if keep: material = Kit.gritty(look.belt,3.0)
		else:
			keep = part in worn
			if keep: material = cloth(look.cloth if part == look.garment else look.get("under_cloth",Color(.86,.84,.78)),wear if part == look.garment else wear*.5,look.get("weave","linen") if part == look.garment else "linen")
		if not keep:
			mesh.free()
			continue
		mesh.material_override = material
		# (A figure's bounds follow its skeleton; a seated or reaching one
		# must not be culled by where it stood at rest.)
		mesh.extra_cull_margin = 1.0
	# A child's head is large for its body.
	if look.get("child",false): skeleton.set_bone_pose_scale(skeleton.find_bone("Head"),Vector3.ONE*1.22)
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
	# size in a child's hand.
	grip.transform = Transform3D((Basis.from_euler(GRIP_TURN)*Basis(Vector3.UP,GRIP_YAW)).scaled(Vector3.ONE/size),GRIP_AT)
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
# the animation (0); the fist closes on a handle as `curl` says.
func reach(point: Vector3, weight: float, curl: float = -1.0) -> void:
	arm.target = point
	arm.weight = weight
	arm.grip = global_transform.basis*GRIP_HAND
	if curl >= 0.0: arm.curl = curl

# Where a mug stands when the hand is at `point`, and the reverse.
func mug_at(hand_point: Vector3) -> Vector3:
	return hand_point+global_transform.basis*GRIP_HAND*GRIP_AT
func hand_for(mug_point: Vector3) -> Vector3:
	return mug_point-global_transform.basis*GRIP_HAND*GRIP_AT

func turn_to(direction: Vector3, delta: float, quickness: float = 9.0) -> void:
	if direction.length_squared() < .0001: return
	rotation.y = lerp_angle(rotation.y,atan2(direction.x,direction.z),minf(1.0,delta*quickness))
