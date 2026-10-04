extends RefCounted
## Orion at his work in the smithy (scripts/townsfolk.gd owns him and walks
## him about; scripts/world_interiors.gd furnishes the room).
##
## His day goes round three jobs. For the anvil he takes a sword down from
## the north wall with his left hand, carries it to the anvil, picks his
## hammer up off the anvil's face, lays the blade flat on the face and beats
## it, the hammer's face meeting the steel at every stroke; then puts the
## hammer down and hangs the sword back. At the forge he takes up the iron
## rod that lies with its end in the coals and works them. For the
## grindstone he takes the sword down with his right hand and holds its edge
## across the turning stone, his left hand pressing the blade to it.
##
## Each tool is put exactly where the work needs it (its grip, the way it
## points, and which way it is turned about that), eased from one place to
## the next, and the hand that holds it follows by the arm's IK
## (scripts/arm_reach.gd, `tool`), the fist closed round it with the wrist
## straight; he bends over his work from the waist (scripts/body_lean.gd).
const Interiors = preload("res://scripts/world_interiors.gd")
const Art = preload("res://scripts/assets.gd")
const Kit = preload("res://scripts/world_art.gd")
const ArmReach = preload("res://scripts/arm_reach.gd")
const BodyLean = preload("res://scripts/body_lean.gd")
const Vfx = preload("res://scripts/vfx.gd")

const JOBS = ["anvil","forge","wheel","forge"]
# The sword he works on: its size, how far its grip's middle is above its
# pommel, and where its blade begins.
const SWORD: Vector3 = Interiors.ARMS.sword[0]
const HILT = .105
const BLADE = .27
# The hammer's head: how far along the shaft from the fist, and how far its
# striking face is from the shaft.
const HEAD_ALONG = .3275
const HEAD_FACE = .075
# The floor's tiles lie this far above the ground, and his shoes' soles
# this far below his feet: he stands on the one in the other.
const STAND = .072
# How fast a hand comes to where it is wanted, and the body leans.
const EASE = 7.0
const NEAR = .03
# A stroke of the hammer: its time, and how far round the hammer swings up.
const STROKE = 1.15
const SWING = 1.9
const WHEEL_SPEED = 9.0

var folk
var world
var walker
var body
var corner: Vector3
var arms = {}
var lean: SkeletonModifier3D
var lean_wanted = 0.0
# Each hand: where its grip is and how it is turned (`at`, `axis`, `side`),
# where that is going (`want`), how far the arm follows (`weight`), the tool
# in it, and whether these are measured from him (carrying) or in the world.
var hands = {}
# Each tool: its node, where it rests when not in a hand, and the hand it is in.
var tools = {}
var plan: Array = []
var job = 0
var clock = 0.0
var places = {}
var wheel: Node3D
var wheel_size = Vector3.ONE
var wheel_turn = 0.0
var wheel_rate = 0.0
var sparks: CPUParticles3D
var struck = false

func setup(townsfolk, overworld, smith_walker) -> void:
	folk = townsfolk
	world = overworld
	walker = smith_walker
	body = walker.body
	corner = Interiors.SMITHY
	var room: Dictionary = world.rooms[1]
	wheel = room.wheel
	wheel_size = wheel.scale
	var forge: Vector3 = corner+Vector3(9.0,0,1.0)
	var anvil: Vector3 = room.anvil.position
	var top = 1.07
	# The anvil's face: its middle line, a little north of the block's.
	var face = Vector3(anvil.x,top,anvil.z-.065)
	var stone = corner+Interiors.WHEEL+Vector3(0,1.17,Interiors.WHEEL_STONE)
	places = {"forge":forge,"face":face,"stone":stone,
		"wall_stand":corner+Vector3(Interiors.WORK_SWORD.x,0,1.86),"anvil_stand":Vector3(anvil.x-.36,0,anvil.z+.64),
		"wheel_stand":Vector3(stone.x-.64,0,stone.z+.08),"forge_stand":forge+Vector3(.5,0,2.36)}
	# The arms and the lean: the lean first, then the arms that reach from it.
	lean = BodyLean.new()
	body.skeleton.add_child(lean)
	body.skeleton.move_child(lean,body.arm.get_index())
	var right = ArmReach.new()
	right.side = "r"
	body.skeleton.add_child(right)
	arms = {"l":body.arm,"r":right}
	for side in arms:
		arms[side].tool = true
		hands[side] = {"at":Vector3.ZERO,"axis":Vector3.UP,"side":Vector3.RIGHT,"weight":0.0,"want":null,"tool":"","local":true,"curl":1.0}
	# His tools, each made about its grip, its length along +Y: the sword (as
	# the warrior's), the hammer (an iron head across a wooden shaft, a
	# hand's breadth of it below the fist) and the iron rod.
	var sword = Node3D.new()
	var blade = Art.model("sword",SWORD,Art.sword_material())
	blade.position.y = -HILT
	sword.add_child(blade)
	var hammer = Node3D.new()
	var shaft = Art.model("column",Vector3(.034,.42,.034),Kit.planks(Color(.55,.41,.26),2.0))
	shaft.position.y = -.07
	hammer.add_child(shaft)
	var head = Art.model("crate_metal",Vector3(HEAD_FACE*2.0,.075,.075),Kit.iron())
	head.position.y = HEAD_ALONG-.0375
	hammer.add_child(head)
	var rod = Node3D.new()
	var iron = Art.model("column",Vector3(.024,1.05,.024),Kit.iron())
	iron.position.y = -.1
	rod.add_child(iron)
	var coals: Vector3 = forge+Vector3(.1,.99,1.05)
	var rod_at: Vector3 = forge+Vector3(.78,1.0,1.96)
	var rests = {"sword":pose(corner+Interiors.WORK_SWORD+Vector3.UP*HILT,Vector3.UP,Vector3.RIGHT),
		"hammer":pose(face+Vector3(-.1,.0375,0),Vector3.LEFT,Vector3.BACK),
		"rod":pose(rod_at,coals-rod_at,(coals-rod_at).cross(Vector3.UP))}
	for name in rests:
		var node: Node3D = {"sword":sword,"hammer":hammer,"rod":rod}[name]
		node.name = "Orion_"+name
		folk.add_child(node)
		node.top_level = true
		tools[name] = {"node":node,"rest":rests[name],"hand":""}
		node.global_transform = placed(rests[name])
	# Sparks off the grindstone, while he grinds.
	sparks = Vfx.particles(folk,24,.35,false,true)
	sparks.top_level = true
	sparks.global_position = stone+Vector3(.02,.02,0)
	sparks.direction = Vector3(-.5,.5,0)
	sparks.spread = 22
	sparks.gravity = Vector3(0,-6,0)
	sparks.initial_velocity_min = 1.5; sparks.initial_velocity_max = 3.2
	sparks.scale_amount_min = .02; sparks.scale_amount_max = .05
	sparks.color = Color(1,.72,.3,.95)
	sparks.emitting = false
	walker.at = places.anvil_stand
	body.rotation.y = PI
	begin()

# A tool's place: its grip, the way it points, and which way its side faces.
func pose(at: Vector3, axis: Vector3, side: Vector3) -> Dictionary:
	axis = axis.normalized()
	return {"at":at,"axis":axis,"side":(side-axis*side.dot(axis)).normalized()}

func placed(p: Dictionary) -> Transform3D:
	return Transform3D(Basis(p.side,p.axis,p.side.cross(p.axis)),p.at)

# Carried at his side as he walks, measured from him: the blade up and ahead.
func carried(side: String) -> Dictionary:
	return pose(Vector3(.31 if side == "l" else -.31,1.0,.2),Vector3(.12 if side == "l" else -.12,.8,.6),Vector3.RIGHT)

# The hammer through a stroke: `raised` 0 on the blade, 1 back over his shoulder.
func stroke(raised: float) -> Dictionary:
	var face: Vector3 = places.face
	var swing = SWING*raised
	var axis = Vector3(0,sin(swing),-cos(swing))
	var side = Vector3(0,-cos(swing),-sin(swing))
	# Its face on the blade's top, over the middle of the anvil.
	var contact: Vector3 = face+Vector3(-.12,SWORD.z,0)-side*HEAD_FACE-axis*HEAD_ALONG
	var high: Vector3 = Vector3(face.x+.04,1.66,face.z+.5)
	var at: Vector3 = contact.lerp(high,raised)
	# (It rises forward of the straight line between the two, as an arm swings it.)
	at.z -= .08*sin(raised*PI)
	return pose(at,axis,side)

# The sword on the grindstone, drawn `along` its length across it; and the
# left hand, pressing the flat of the blade to the stone beyond it.
func grinding(along: float) -> Dictionary:
	var stone: Vector3 = places.stone
	return pose(stone+Vector3(.015,.045,.46+along),Vector3(0,0,-1),Vector3(.94,.34,0))
func pressing(along: float) -> Dictionary:
	var stone: Vector3 = places.stone
	return pose(stone+Vector3(.0,.085,-.2+along),Vector3(0,0,1),Vector3.RIGHT)

# The rod worked in the coals: thrust in and drawn back, its end stirred round.
func stoking(t: float) -> Dictionary:
	var forge: Vector3 = places.forge
	var at: Vector3 = forge+Vector3(.62+.04*sin(t*.9),1.12,2.0-.1*(sin(t*1.7)*.5+.5))
	var tip: Vector3 = forge+Vector3(.1+.22*cos(t*1.3),1.0,1.1+.14*sin(t*1.3))
	return pose(at,tip-at,(tip-at).cross(Vector3.UP))

# ---- The day's plan ----

func begin() -> void:
	var sword_rest: Dictionary = tools.sword.rest
	var hammer_rest: Dictionary = tools.hammer.rest
	var rod_rest: Dictionary = tools.rod.rest
	var face: Vector3 = places.face
	var on_anvil: Dictionary = pose(face+Vector3(-.63,SWORD.z*.5,0),Vector3.RIGHT,Vector3.BACK)
	plan = []
	match JOBS[job]:
		"anvil":
			plan += fetch("l")
			plan += [{"go":places.anvil_stand,"face":Vector3(0,0,-1)},{"lean":.5},
				{"reach":"r","to":hammer_rest},{"take":"hammer","hand":"r"},{"reach":"r","to":stroke(.55)},
				{"reach":"l","to":on_anvil},{"lean":.42},
				{"work":"hammer","time":folk.rng.randf_range(14.0,22.0)},
				{"reach":"r","to":stroke(.55)},{"reach":"l","to":carried("l"),"local":true},
				{"lean":.5},{"reach":"r","to":hammer_rest},{"drop":"hammer","hand":"r"},{"free":"r"},{"lean":0.0}]
			plan += hang("l")
		"wheel":
			plan += fetch("r")
			plan += [{"go":places.wheel_stand,"face":Vector3(1,0,0)},{"lean":.4},
				{"reach":"r","to":grinding(0.0)},{"reach":"l","to":pressing(0.0),"curl":.45},
				{"work":"grind","time":folk.rng.randf_range(12.0,18.0)},
				{"free":"l"},{"reach":"r","to":carried("r"),"local":true},{"lean":0.0}]
			plan += hang("r")
		"forge":
			plan += [{"go":places.forge_stand,"face":Vector3(0,0,-1)},{"lean":.34},
				{"reach":"r","to":rod_rest},{"take":"rod","hand":"r"},{"reach":"r","to":stoking(0.0)},
				{"work":"stoke","time":folk.rng.randf_range(10.0,16.0)},
				{"reach":"r","to":rod_rest},{"drop":"rod","hand":"r"},{"free":"r"},{"lean":0.0}]
	clock = 0.0

# To the wall, the sword taken down with one hand; and back, to hang it up.
func fetch(side: String) -> Array:
	return [{"go":wall_stand(side),"face":Vector3(0,0,-1)},{"lean":.2},{"reach":side,"to":tools.sword.rest},{"take":"sword","hand":side},
		{"reach":side,"to":carried(side),"local":true},{"lean":0.0}]
# (He stands with the shoulder of the hand he uses before the sword: facing
# north, his left is to the west.)
func wall_stand(side: String) -> Vector3:
	return places.wall_stand+Vector3(.2 if side == "l" else -.2,0,0)
func hang(side: String) -> Array:
	return [{"go":wall_stand(side),"face":Vector3(0,0,-1)},{"lean":.2},{"reach":side,"to":tools.sword.rest},{"drop":"sword","hand":side},
		{"free":side},{"lean":0.0}]

func tick(delta: float) -> void:
	clock += delta
	if plan.is_empty():
		job = (job+1) % JOBS.size()
		begin()
	var step: Dictionary = plan[0]
	var done = false
	var working = ""
	if step.has("go"):
		if not step.has("route"):
			step.route = true
			walker.route = folk.way(walker.at,step.go)
			walker.route.append(step.go)
			walker.speed = folk.WALK*.9
			walker.pace = "Walk"
		if walker.route.is_empty() or folk.advance(walker,delta):
			# Arrived: he turns to his work before he begins it.
			if body.state != "Idle": body.play("Idle",.3)
			body.turn_to(step.face,delta,7.0)
			done = absf(angle_difference(body.rotation.y,atan2(step.face.x,step.face.z))) < .04
	elif step.has("lean"):
		lean_wanted = step.lean
		done = absf(lean.lean-lean_wanted) < .03
	elif step.has("reach"):
		var hand: Dictionary = hands[step.reach]
		if hand.want != step.to:
			# (From where the hand is now: measured from him, or in the world.)
			var local: bool = step.get("local",false)
			if hand.weight <= 0.0: start(step.reach,local)
			elif local != hand.local: rebase(hand,local)
			hand.want = step.to
			hand.curl = step.get("curl",1.0)
		done = hand.weight > .97 and hand.at.distance_to(step.to.at) < NEAR and hand.axis.angle_to(step.to.axis) < .12
	elif step.has("take"):
		tools[step.take].hand = step.hand
		hands[step.hand].tool = step.take
		done = true
	elif step.has("drop"):
		tools[step.drop].hand = ""
		tools[step.drop].node.global_transform = placed(tools[step.drop].rest)
		hands[step.hand].tool = ""
		done = true
	elif step.has("free"):
		hands[step.free].want = null
		done = hands[step.free].weight < .03
	elif step.has("work"):
		if not step.has("began"): step.began = clock
		var t: float = clock-step.began
		working = step.work
		# (A stroke, a pass or a stir is finished before he stops.)
		done = t >= step.time and work(working,t,true)
		if not done: work(working,t,false)
	if done: plan.remove_at(0)
	# The wheel turns while he grinds, and runs down after.
	wheel_rate = move_toward(wheel_rate,WHEEL_SPEED if working == "grind" else 0.0,delta*(6.0 if working == "grind" else 2.5))
	wheel_turn = fposmod(wheel_turn+wheel_rate*delta,TAU)
	wheel.basis = Basis(Vector3.BACK,wheel_turn)*Basis.from_scale(wheel_size)
	sparks.emitting = working == "grind" and wheel_rate > WHEEL_SPEED*.6
	settle(delta,working)

# Done for the day at once (the clock has jumped to the night): every tool
# back in its place, his hands empty, upright, and the wheel still. (At an
# ordinary bedtime scripts/townsfolk.gd waits for him to finish a job.)
func down_tools() -> void:
	for name in tools:
		tools[name].hand = ""
		tools[name].node.global_transform = placed(tools[name].rest)
	for side in hands:
		hands[side].tool = ""
		hands[side].want = null
		hands[side].weight = 0.0
		arms[side].weight = 0.0
	lean_wanted = 0.0
	lean.lean = 0.0
	plan = []
	wheel_rate = 0.0
	sparks.emitting = false

# One of his labours at `t` seconds into it: the hands put where it has
# them. `ending` asks only whether it is at a moment he can stop on.
func work(kind: String, t: float, ending: bool) -> bool:
	match kind:
		"hammer":
			var through = fposmod(t,STROKE)/STROKE
			if ending: return through > .5 and through < .62
			# Up over the shoulder, a breath there, down hard, a moment on the steel.
			var raised: float
			if through < .5: raised = smoothstep(0.0,.5,through)
			elif through < .6: raised = 1.0
			elif through < .78: raised = 1.0-pow((through-.6)/.18,2.0)
			else: raised = 0.0
			put("r",stroke(raised))
			if through >= .78 and not struck: spark()
			struck = through >= .78
			lean_wanted = .42-.1*raised
		"grind":
			if ending: return absf(sin(t*1.7)) < .12
			var along = .13*sin(t*1.7)
			put("r",grinding(along))
			put("l",pressing(along))
		"stoke":
			if ending: return true
			put("r",stoking(t))
	return false

# A hand set straight to its place in the work (the work's own motion is smooth).
func put(side: String, to: Dictionary) -> void:
	var hand: Dictionary = hands[side]
	hand.want = to
	hand.at = hand.at.lerp(to.at,.5)
	hand.axis = hand.axis.lerp(to.axis,.5).normalized()
	hand.side = hand.side.lerp(to.side,.5).normalized()

# The hammer meeting the blade: a few sparks.
func spark() -> void:
	var burst = Vfx.particles(folk,8,.3,true,true)
	burst.top_level = true
	burst.global_position = places.face+Vector3(-.12,SWORD.z+.01,0)
	burst.explosiveness = 1.0
	burst.direction = Vector3.UP
	burst.spread = 70
	burst.gravity = Vector3(0,-7,0)
	burst.initial_velocity_min = 1.0; burst.initial_velocity_max = 2.4
	burst.scale_amount_min = .02; burst.scale_amount_max = .045
	burst.color = Color(1,.75,.35,.95)
	burst.emitting = true
	folk.get_tree().create_timer(.8).timeout.connect(burst.queue_free)

# A hand beginning to reach: from where the arm hangs now.
func start(side: String, local: bool) -> void:
	var hand: Dictionary = hands[side]
	var bone = body.skeleton.find_bone("hand_"+side)
	var now: Transform3D = body.skeleton.global_transform*body.skeleton.get_bone_global_pose(bone)
	hand.local = false
	hand.at = now.origin
	hand.axis = now.basis.z.normalized()
	hand.side = now.basis.x.normalized()
	rebase(hand,local)

func rebase(hand: Dictionary, local: bool) -> void:
	if local == hand.local: return
	var frame: Transform3D = body.global_transform if hand.local else body.global_transform.affine_inverse()
	hand.at = frame*hand.at
	hand.axis = frame.basis*hand.axis
	hand.side = frame.basis*hand.side
	hand.local = local

# Hands eased toward where they are wanted, the arms and the tools after them.
func settle(delta: float, working: String) -> void:
	lean.lean = lerpf(lean.lean,lean_wanted,1.0-exp(-delta*5.0))
	# (On the smithy's tiles; on the street, coming from his house, on the ground.)
	body.figure.position.y = STAND if world.rooms[1].area.has_point(Vector2(walker.at.x,walker.at.z)) else 0.0
	var blend = 1.0-exp(-delta*EASE)
	for side in hands:
		var hand: Dictionary = hands[side]
		var arm = arms[side]
		if hand.want == null:
			hand.weight = move_toward(hand.weight,0.0,delta*2.5)
		else:
			hand.weight = move_toward(hand.weight,1.0,delta*2.5)
			hand.at = hand.at.lerp(hand.want.at,blend)
			hand.axis = hand.axis.lerp(hand.want.axis,blend).normalized()
			hand.side = hand.side.lerp(hand.want.side,blend)
		var frame: Transform3D = body.global_transform if hand.local else Transform3D.IDENTITY
		var shown: Dictionary = pose(frame*hand.at,frame.basis*hand.axis,frame.basis*hand.side)
		arm.target = shown.at
		arm.axis = shown.axis
		arm.weight = smoothstep(0.0,1.0,hand.weight)
		arm.curl = hand.curl*arm.weight
		if hand.tool != "": tools[hand.tool].node.global_transform = placed(shown)
