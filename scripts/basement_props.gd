extends RefCounted
## The arena basement's dressing: what is left down there of the arena's old
## days and of those who came before the bandits. Every piece is built here,
## for scripts/temple.gd to set down:
##   damaged_statue   a gladiator in weathered stone, broken and crumbling on
##                    a cracked plinth (the temple's own carving, frozen still)
##   skeleton, bones  human remains, sprawled, slumped against a wall, or a
##                    scattered few (procedural: no kit carries bones)
##   web, wall_web    spider webs, across a corner or draped on a wall face
##   gate, open_gate  an iron grille gate in a stone doorway, and its swing
##   key_model        the great iron key that opens it
## Each comes back unparented, its origin on the floor (the key's at its
## middle); none collides with anything: the caller takes its cells out of
## the floor where it should stand in the way.
const Art = preload("res://scripts/assets.gd")
const Visual = preload("res://scripts/visual.gd")
const Kit = preload("res://scripts/world_art.gd")

static var cache: Dictionary = {}

# --- The statues ----------------------------------------------------------------

# A gladiator's statue, life size (STATUE_STATURE), on a plinth of the same
# weathered stone: the plinth is cracked and canted, a chunk of it broken off
# and lying by it, and the figure on it is damaged by one or more of:
#   its head broken off at the neck (lying among the rubble),
#   its sword arm broken off at the elbow (the blade fallen by the plinth),
#   its shield gone from its arm (leaning against the plinth).
# It holds a pose of the living gladiator's, frozen; the pose and the damage
# are drawn from `rng`. It faces +Z; its plinth is PLINTH wide and deep.
const STATUE_STATURE = 1.0
const PLINTH = Vector3(1.0,.42,1.0)
# Where the head breaks away, above the figure's feet (life size), and how
# ragged the break is.
const NECK_BREAK = 1.57
const BREAK_BAND = .07
const STATUE_POSES = [["ScutumSwordIdle",.4],["ScutumSwordIdle",1.3],["ScutumSwordSwing",.18],["ScutumHitStagger",.25],["ScutumSwordSwing",.32]]
static func damaged_statue(rng: RandomNumberGenerator) -> Node3D:
	var stand = Node3D.new()
	stand.name = "DamagedStatue"
	stand.set_meta("statue","gladiator")
	var stone: ShaderMaterial = Art.statue_material()
	# The plinth: a footing slab and the block on it, of the figure's own
	# stone, settled askew.
	var lean = Vector3(rng.randf_range(-.035,.035),rng.randf_range(-.12,.12),rng.randf_range(-.035,.035))
	var plinth = Node3D.new()
	plinth.name = "Plinth"
	plinth.rotation = lean
	stand.add_child(plinth)
	plinth.add_child(block(Vector3(PLINTH.x+.14,.1,PLINTH.z+.14),0.0,stone))
	plinth.add_child(block(Vector3(PLINTH.x,PLINTH.y-.18,PLINTH.z),.1,stone))
	# A cornice round its top, chipped.
	plinth.add_child(block(Vector3(PLINTH.x+.06,.08,PLINTH.z+.06),PLINTH.y-.08,stone))
	# A corner of the block has cracked away: the chunk lies at its foot.
	var corner = Vector3(signf(rng.randf()-.5)*PLINTH.x*.5,0,signf(rng.randf()-.5)*PLINTH.z*.5)
	var chunk = rubble_piece(rng,.28,["rock"])
	chunk.position = corner
	stand.add_child(chunk)
	# The figure, frozen once it is in the world (a figure poses only there).
	var figure: Node3D = Visual.new()
	figure.name = "Figure"
	figure.position.y = PLINTH.y
	figure.rotation = Vector3(rng.randf_range(-.06,.06),0,rng.randf_range(-.06,.06))
	plinth.add_child(figure)
	var damage: Array = []
	var roll = rng.randf()
	if roll < .4: damage = ["head"]
	elif roll < .65: damage = ["arm"]
	elif roll < .8: damage = ["head","arm"]
	else: damage = ["head","shield"]
	if rng.randf() < .25 and not "shield" in damage: damage.append("shield")
	stand.set_meta("damage",damage)
	var pose: Array = STATUE_POSES[rng.randi()%STATUE_POSES.size()]
	# (A raised blade would be cut off with the head: the headless keep low.)
	if "head" in damage and pose[0] != "ScutumSwordIdle": pose = STATUE_POSES[rng.randi()%2]
	stand.ready.connect(func(): pose_statue(stand,figure,pose,damage),CONNECT_ONE_SHOT)
	# Rubble round the plinth: chips and a few larger lumps of the same stone.
	for i in rng.randi_range(5,9):
		var piece = rubble_piece(rng,rng.randf_range(.08,.18))
		var side = Vector3(rng.randf_range(-1,1),0,rng.randf_range(-1,1)).normalized()
		piece.position = Vector3(side.x*rng.randf_range(.48,.55),0,side.z*rng.randf_range(.48,.55))
		stand.add_child(piece)
	if "head" in damage:
		# The head (a lump of the carving: helmet and all, worn past knowing).
		var head = rubble_piece(rng,.26,["rock"])
		head.position = Vector3(rng.randf_range(-.4,.4),0,.54)
		stand.add_child(head)
	if "arm" in damage:
		var blade = Art.model("sword",Vector3(.17,.82,.08),Art.statue_material())
		blade.rotation = Vector3(-PI/2,0,PI/2+rng.randf_range(-.25,.25))
		blade.position = Vector3(rng.randf_range(-.12,.12),.04,.6)
		stand.add_child(blade)
	if "shield" in damage:
		var shield = Art.model("scutum",Visual.SCUTUM_SIZE,Art.statue_material())
		shield.position = Vector3(PLINTH.x*.5+.1,0,rng.randf_range(-.2,.2))
		shield.rotation = Vector3(0,PI/2,rng.randf_range(.25,.4))
		stand.add_child(shield)
	return stand

# Sets the figure in its pose, still, and breaks what is broken off it.
static func pose_statue(stand: Node3D, figure: Node3D, pose: Array, damage: Array) -> void:
	figure.setup(true,Color.WHITE,"sword",STATUE_STATURE,"gladiator")
	figure.play(pose[0] if figure.clips.has(pose[0]) else figure.idle_action())
	figure.animator.play(figure.clips[figure.state],0)
	figure.animator.seek(0,true)
	figure.advance(pose[1])
	figure.animator.pause()
	var skeleton: Skeleton3D = figure.skeleton
	if "arm" in damage:
		# Broken at the elbow: the forearm, hand and blade are gone.
		var forearm = skeleton.find_bone("lowerarm_r")
		if forearm >= 0: skeleton.set_bone_pose_scale(forearm,Vector3.ONE*.001)
		if is_instance_valid(figure.equipment): figure.equipment.visible = false
	if "shield" in damage and is_instance_valid(figure.shield_item): figure.shield_item.visible = false
	# The statue's own stone, on this figure alone, worn and cracked; with its
	# head broken away above the neck in a ragged edge (the stone's own
	# breaking front: assets/shaders/statue_stone.gdshader, a world height).
	var front = INF
	if "head" in damage: front = stand.global_position.y+PLINTH.y+NECK_BREAK*STATUE_STATURE
	for mesh in figure.find_children("*","MeshInstance3D",true,false):
		var stone: Material = mesh.material_override
		if not stone is ShaderMaterial: continue
		var broken: ShaderMaterial = stone.duplicate()
		if front < INF:
			broken.set_shader_parameter("shatter_front",front)
			broken.set_shader_parameter("shatter_band",BREAK_BAND)
		mesh.material_override = broken

# A box of `size` standing at `rise`, in `stone`.
static func block(size: Vector3, rise: float, stone: Material) -> MeshInstance3D:
	var box = BoxMesh.new()
	box.size = size
	var node = MeshInstance3D.new()
	node.mesh = box
	node.material_override = stone
	node.position.y = rise+size.y*.5
	return node

# A broken lump of statue stone, about `width` across, lying on the floor
# (the scanned stones are flat slabs: a lump is sized by its breadth).
static func rubble_piece(rng: RandomNumberGenerator, width: float, ids: Array = ["stone_a","stone_b","stone_c","rock"]) -> Node3D:
	var id: String = ids[rng.randi()%ids.size()]
	var native: Vector3 = Kit.SIZE[id]
	var piece = Art.model(id,native*(width/maxf(native.x,native.z)),Art.statue_material())
	piece.rotation.y = rng.randf_range(-PI,PI)
	return piece

# --- The dead ----------------------------------------------------------------------

# Human remains, long picked clean: a man's bones, life size, lying where he
# fell. Not `slumped`: sprawled on his back across the floor, along X (his
# skull toward +X), about 1.8 by 0.7 metres about the origin. `slumped`: he
# sat down against a wall (its face at local z = -0.15) and never got up,
# facing +Z, the origin on the floor at the wall's foot. Some bones have come
# apart and lie off where they were (rats, or whoever came after). One mesh.
static func skeleton(rng: RandomNumberGenerator, slumped: bool) -> Node3D:
	var j: Dictionary = slumped_joints(rng) if slumped else sprawled_joints(rng)
	var st = bone_tool()
	body(st,j,rng)
	var node = bone_node(st,"Skeleton")
	node.set_meta("slumped",slumped)
	return node

# A few bones lying scattered: a skull, and long bones crossed over one
# another, within about 0.8 metres.
static func bones(rng: RandomNumberGenerator) -> Node3D:
	var st = bone_tool()
	var up = Vector3(rng.randf_range(-.6,.6),rng.randf_range(.2,.8),rng.randf_range(-.6,.6)).normalized()
	skull(st,Vector3(rng.randf_range(-.2,.2),.075,rng.randf_range(-.2,.2)),up,Vector3(rng.randf_range(-1,1),0,rng.randf_range(-1,1)).normalized(),rng.randf()<.5)
	for i in rng.randi_range(3,5):
		var length = rng.randf_range(.25,.46)
		var middle = Vector3(rng.randf_range(-.25,.25),.025+i*.012,rng.randf_range(-.25,.25))
		var way = Vector3.FORWARD.rotated(Vector3.UP,rng.randf_range(-PI,PI))
		long_bone(st,middle-way*length*.5,middle+way*length*.5,rng.randf_range(.014,.02),bone_tint(rng))
	if rng.randf() < .7:
		# A stray jaw, or a run of vertebrae.
		var at = Vector3(rng.randf_range(-.3,.3),.02,rng.randf_range(-.3,.3))
		for k in 3: ellipsoid(st,at+Vector3(.04*k,0,.01*k),Vector3(.018,.016,.02),Basis(),bone_tint(rng))
	return bone_node(st,"Bones")

# The joints of a man lying on his back, his head toward +X: hips, spine,
# skull and limbs, each thrown a little out of true, an arm or a shin come
# away and lying apart.
static func sprawled_joints(rng: RandomNumberGenerator) -> Dictionary:
	var j = {}
	var floor_y = .028
	j.pelvis = Vector3(-.06,.06,rng.randf_range(-.03,.03))
	j.neck = Vector3(.46,.07,rng.randf_range(-.05,.05))
	j.front = Vector3.UP
	# (His chest has fallen in: the ribs lie spread, low over the spine.)
	j.ribs = Vector2(1.25,.45)
	j.head = j.neck+Vector3(.12,.02,rng.randf_range(-.07,.07))
	j.head_up = Vector3(1,0,rng.randf_range(-.5,.5)).normalized()
	j.head_front = Vector3(0,1,rng.randf_range(-1.2,1.2)).normalized()
	j.jaw_open = rng.randf() < .6
	var spread = rng.randf_range(.0,.06)
	for s in [-1,1]:
		var side = "l" if s < 0 else "r"
		var shoulder = j.neck+Vector3(-.04,-.02,s*.18)
		var elbow = shoulder+Vector3(rng.randf_range(-.28,-.2),floor_y-shoulder.y,s*rng.randf_range(.02,.1))
		var wrist = elbow+Vector3(rng.randf_range(-.26,-.14),0,s*rng.randf_range(-.04,.06))
		var hip = j.pelvis+Vector3(-.02,-.02,s*.1)
		var knee = hip+Vector3(-.43,floor_y-hip.y,s*rng.randf_range(.02,.06+spread))
		var ankle = knee+Vector3(-.4,0,s*rng.randf_range(-.02,.06+spread))
		j["shoulder_"+side] = shoulder; j["elbow_"+side] = elbow; j["wrist_"+side] = wrist
		j["hip_"+side] = hip; j["knee_"+side] = knee; j["ankle_"+side] = ankle
		j["toe_"+side] = ankle+Vector3(-.14,-.005,s*.03)
	j.loose = loose_limb(rng)
	return j

# The joints of a man sat with his back to the wall (its face at z = -0.15),
# slumped: his spine leaning back on it, his skull fallen forward onto his
# chest or aside, his legs out before him (a knee drawn up, maybe), his arms
# hanging down to the floor at his sides.
static func slumped_joints(rng: RandomNumberGenerator) -> Dictionary:
	var j = {}
	var floor_y = .028
	j.pelvis = Vector3(rng.randf_range(-.03,.03),.1,.06)
	j.neck = Vector3(rng.randf_range(-.06,.06),.6,-.08)
	j.front = Vector3(0,.25,1).normalized()
	var droop = rng.randf_range(-1,1)
	j.head = j.neck+Vector3(droop*.07,.07,.09)
	j.head_up = Vector3(droop*.6,.6,.8).normalized()
	j.head_front = Vector3(droop*.3,-.75,.6).normalized()
	j.jaw_open = rng.randf() < .7
	var drawn = rng.randi()%3
	for s in [-1,1]:
		var side = "l" if s < 0 else "r"
		var shoulder = j.neck+Vector3(s*.18,-.04,-.01)
		var elbow = shoulder+Vector3(s*rng.randf_range(.05,.1),-.27,rng.randf_range(-.02,.08))
		var wrist = Vector3(elbow.x+s*rng.randf_range(.02,.1),floor_y,elbow.z+rng.randf_range(.08,.24))
		var hip = j.pelvis+Vector3(s*.1,-.03,.0)
		var knee: Vector3
		if drawn == (0 if s < 0 else 1): knee = hip+Vector3(s*.06,.3,.3)
		else: knee = Vector3(hip.x+s*rng.randf_range(.02,.12),.07,hip.z+.43)
		var ankle = Vector3(knee.x+s*rng.randf_range(.0,.1),floor_y+.02,knee.z+(.2 if knee.y > .2 else .42))
		j["shoulder_"+side] = shoulder; j["elbow_"+side] = elbow; j["wrist_"+side] = wrist
		j["hip_"+side] = hip; j["knee_"+side] = knee; j["ankle_"+side] = ankle
		j["toe_"+side] = ankle+Vector3(s*.03,-.01,.14)
	j.loose = loose_limb(rng)
	return j

# Which limb has come apart (`part`: a forearm or a shin), and how far off it
# lies: its bones keep their length, moved along the floor and turned.
static func loose_limb(rng: RandomNumberGenerator) -> Dictionary:
	if rng.randf() < .3: return {}
	return {"part":["wrist_l","wrist_r","ankle_l","ankle_r"][rng.randi()%4],"shift":Vector3(rng.randf_range(-.2,.2),0,rng.randf_range(-.12,.12)),"turn":rng.randf_range(-1.2,1.2)}

# The bones between the joints: the spine and the ribs off it, the pelvis,
# the skull and the limbs (two bones to each forearm and shin, the hands and
# feet a few small ones).
static func body(st: SurfaceTool, j: Dictionary, rng: RandomNumberGenerator) -> void:
	var up: Vector3 = (j.neck-j.pelvis).normalized()
	var front: Vector3 = (j.front-up*j.front.dot(up)).normalized()
	var side: Vector3 = up.cross(front).normalized()
	# The spine: a column of vertebrae, the neck's finer.
	var count = 17
	for i in count:
		var t = float(i)/(count-1)
		var at: Vector3 = j.pelvis.lerp(j.neck,t)-front*(.02*sin(t*PI))
		var size = lerpf(.024,.016,t)
		ellipsoid(st,at,Vector3(size*1.3,size*.8,size),Basis(side,up,front),bone_tint(rng,.95))
		# The spinous process, a knob on the back of each.
		ellipsoid(st,at-front*size*1.1,Vector3(size*.35,size*.5,size*.6),Basis(side,up,front),bone_tint(rng,.9))
	for i in 3: ellipsoid(st,j.neck.lerp(j.head,.25+i*.2),Vector3(.014,.01,.014),Basis(side,up,front),bone_tint(rng))
	# The ribcage: seven pairs curving forward from the spine to the
	# breastbone, falling as they go, the lowest short and floating.
	var chest_top: Vector3 = j.neck-up*.05
	for i in 7:
		var t = float(i)/6.0
		var root: Vector3 = chest_top-up*(t*.24)
		var ribs: Vector2 = j.get("ribs",Vector2.ONE)
		var width = lerpf(.09,.15,sin(minf(t*1.3,1.0)*PI*.5))*ribs.x
		var depth = lerpf(.12,.17,t)*ribs.y
		var reach = .85 if i < 5 else .55
		for s in [-1,1]:
			var points = PackedVector3Array()
			var radii = PackedFloat32Array()
			for k in 9:
				var phi = float(k)/8.0*PI*reach
				points.append(root+side*(s*width*sin(phi))+front*(depth*(1.0-cos(phi))*.5)-up*(.05*phi/PI))
				radii.append(.0075 if k > 0 and k < 8 else .004)
			tube(st,points,radii,5,bone_tint(rng))
	var sternum: Vector3 = chest_top-up*.09+front*(.16*j.get("ribs",Vector2.ONE).y)
	ellipsoid(st,sternum,Vector3(.022,.08,.008),Basis(side,up,front),bone_tint(rng))
	# Collarbones and shoulder blades.
	for s in ["l","r"]:
		long_bone(st,chest_top+front*.1,j["shoulder_"+s],.008,bone_tint(rng))
		ellipsoid(st,j["shoulder_"+s].lerp(j.neck,.4)-up*.07-front*.04,Vector3(.055,.065,.008),Basis(side,up,front),bone_tint(rng,.92))
	# The pelvis: the hip bones flaring either side of the sacrum.
	for s in [-1,1]:
		ellipsoid(st,j.pelvis+side*(s*.075)+up*.03,Vector3(.06,.07,.025),Basis(side,up,front).rotated(up,s*.6),bone_tint(rng))
		ellipsoid(st,j.pelvis+side*(s*.05)-up*.04+front*.04,Vector3(.03,.025,.02),Basis(side,up,front),bone_tint(rng,.92))
	ellipsoid(st,j.pelvis-front*.02,Vector3(.035,.055,.02),Basis(side,up,front),bone_tint(rng))
	skull(st,j.head,j.head_up,j.head_front,j.jaw_open)
	# The limbs, the loose one moved off where it lies.
	var loose: Dictionary = j.get("loose",{})
	for s in ["l","r"]:
		long_bone(st,j["shoulder_"+s],j["elbow_"+s],.016,bone_tint(rng))
		long_bone(st,j["hip_"+s],j["knee_"+s],.021,bone_tint(rng))
		var arm = [j["elbow_"+s],j["wrist_"+s]]
		var leg = [j["knee_"+s],j["ankle_"+s],j["toe_"+s]]
		if loose.get("part","") == "wrist_"+s: arm = displaced(arm,loose)
		if loose.get("part","") == "ankle_"+s: leg = displaced(leg,loose)
		# Forearm (radius and ulna) and hand.
		var across: Vector3 = (arm[1]-arm[0]).cross(Vector3.UP).normalized()*.012
		long_bone(st,arm[0]+across,arm[1]+across,.009,bone_tint(rng))
		long_bone(st,arm[0]-across,arm[1]-across,.008,bone_tint(rng))
		hand(st,arm[1],(arm[1]-arm[0]).normalized(),rng)
		# Shin (tibia and fibula) and foot.
		across = (leg[1]-leg[0]).cross(Vector3.UP).normalized()*.016
		long_bone(st,leg[0]+across*.4,leg[1]+across*.4,.014,bone_tint(rng))
		long_bone(st,leg[0]-across,leg[1]-across,.007,bone_tint(rng))
		ellipsoid(st,leg[0]+(leg[0]-j["hip_"+s]).normalized()*.012,Vector3(.022,.022,.022),Basis(),bone_tint(rng))
		foot(st,leg[1],leg[2],rng)

# `points` moved together by `loose`: along the floor and turned about the
# first of them.
static func displaced(points: Array, loose: Dictionary) -> Array:
	var pivot: Vector3 = points[0]
	var out = []
	for p in points:
		var moved: Vector3 = pivot+(p-pivot).rotated(Vector3.UP,loose.turn)+loose.shift
		moved.y = maxf(p.y,.02) if p.y < .2 else .03
		out.append(moved)
	return out

# A skull at `at`, its crown toward `up`, its face toward `front`: the
# cranium, the cheekbones and upper jaw, the dark sockets of the eyes and
# nose, a row of teeth, and the jaw (dropped open, maybe, or fallen away).
static func skull(st: SurfaceTool, at: Vector3, up: Vector3, front: Vector3, jaw_open: bool) -> void:
	front = (front-up*front.dot(up)).normalized()
	var side = up.cross(front).normalized()
	var b = Basis(side,up,front)
	var bone = Color(.95,.92,.84)
	var dark = Color(.05,.04,.03)
	ellipsoid(st,at+up*.02-front*.012,Vector3(.07,.075,.093),b,bone)
	ellipsoid(st,at-up*.03+front*.05,Vector3(.055,.045,.045),b,bone)
	for s in [-1,1]:
		ellipsoid(st,at-up*.012+front*.08+side*(s*.026),Vector3(.019,.017,.014),b,dark)
		ellipsoid(st,at-up*.03+front*.055+side*(s*.055),Vector3(.014,.012,.025),b,bone)
	ellipsoid(st,at-up*.045+front*.088,Vector3(.009,.013,.008),b,dark)
	for k in 6:
		var a = (float(k)/5.0-.5)*1.4
		ellipsoid(st,at-up*.068+front*(.083*cos(a*.5))+side*(.04*sin(a)),Vector3(.006,.008,.006),b,Color(.98,.95,.86))
	var drop = .03 if jaw_open else 0.0
	var jaw = PackedVector3Array()
	var radii = PackedFloat32Array()
	for k in 7:
		var a = (float(k)/6.0-.5)*2.4
		jaw.append(at-up*(.085+drop*(cos(a*.5)))+front*(.075*cos(a*.5)-.01)+side*(.05*sin(a))-up*(.0 if absf(a) < 1.0 else -.03*(absf(a)-1.0)))
		radii.append(.004 if k == 0 or k == 6 else .011)
	tube(st,jaw,radii,5,bone)

# A long bone from `a` to `b`: a shaft swelling to knobbed ends, each end two
# rounded heads side by side.
static func long_bone(st: SurfaceTool, a: Vector3, b: Vector3, radius: float, tint: Color) -> void:
	var points = PackedVector3Array()
	var radii = PackedFloat32Array()
	var profile = [[0.0,0.0],[.015,1.3],[.05,1.55],[.13,.9],[.5,.75],[.87,.9],[.95,1.55],[.985,1.3],[1.0,0.0]]
	for p in profile:
		points.append(a.lerp(b,p[0]))
		radii.append(radius*p[1])
	tube(st,points,radii,6,tint)
	var way = (b-a).normalized()
	var across = way.cross(Vector3.UP if absf(way.y) < .9 else Vector3.RIGHT).normalized()
	for end in [[a,-1.0],[b,1.0]]:
		for s in [-1,1]: ellipsoid(st,end[0]+way*(end[1]*radius*.2)+across*(s*radius*.75),Vector3.ONE*radius*1.15,Basis(),tint)

# The small bones of a hand at the wrist `at`, reaching on along `way`: a
# few, come apart and lying anyhow.
static func hand(st: SurfaceTool, at: Vector3, way: Vector3, rng: RandomNumberGenerator) -> void:
	way = Vector3(way.x,0,way.z).normalized()
	for k in rng.randi_range(3,5):
		var root: Vector3 = Vector3(at.x,.012,at.z)+way.rotated(Vector3.UP,rng.randf_range(-1.2,1.2))*rng.randf_range(.01,.05)
		var tip: Vector3 = root+way.rotated(Vector3.UP,rng.randf_range(-.9,.9))*rng.randf_range(.03,.055)
		long_bone(st,root,tip,.0045,bone_tint(rng))

# The bones of a foot, from the ankle `at` to the toes at `toe`.
static func foot(st: SurfaceTool, at: Vector3, toe: Vector3, rng: RandomNumberGenerator) -> void:
	ellipsoid(st,at,Vector3(.022,.018,.028),Basis(),bone_tint(rng))
	var way = (toe-at)
	var across = way.cross(Vector3.UP).normalized()
	for k in 3:
		var root = at.lerp(toe,.2)+across*((k-1)*.014)
		long_bone(st,root,toe+across*((k-1)*.02)+Vector3(rng.randf_range(-.02,.02),0,rng.randf_range(-.02,.02)),.0055,bone_tint(rng))

# Old bone's colour, a little different bone to bone (each long in the dirt).
static func bone_tint(rng: RandomNumberGenerator, light: float = 1.0) -> Color:
	var v = rng.randf_range(.78,1.0)*light
	return Color(v,v*rng.randf_range(.95,1.0),v*rng.randf_range(.86,.96))

static func bone_tool() -> SurfaceTool:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st

# The bones as one mesh, in aged bone (assets/shaders/bone.gdshader).
static func bone_node(st: SurfaceTool, name: String) -> MeshInstance3D:
	if not cache.has("bone"):
		var m = ShaderMaterial.new()
		m.shader = load("res://assets/shaders/bone.gdshader")
		m.set_shader_parameter("grit",load("res://assets/textures/rock_detail.jpg"))
		cache.bone = m
	var node = MeshInstance3D.new()
	node.name = name
	node.mesh = st.commit()
	node.material_override = cache.bone
	return node

# An ellipsoid of half-sizes `radii` in the frame `b` about `at`.
static func ellipsoid(st: SurfaceTool, at: Vector3, radii: Vector3, b: Basis, tint: Color, rings: int = 5, segments: int = 8) -> void:
	var grid = []
	for r in rings+1:
		var lat = PI*float(r)/rings-PI*.5
		var row = []
		for s in segments+1:
			var lon = TAU*float(s)/segments
			var unit = Vector3(cos(lat)*cos(lon),sin(lat),cos(lat)*sin(lon))
			row.append([at+b*(unit*radii),(b*(unit/radii)).normalized()])
		grid.append(row)
	for r in rings:
		for s in segments:
			quad(st,grid[r][s],grid[r+1][s],grid[r+1][s+1],grid[r][s+1],tint)

# A tube through `points`, `radii` thick at each, `sides` round.
static func tube(st: SurfaceTool, points: PackedVector3Array, radii: PackedFloat32Array, sides: int, tint: Color) -> void:
	var rings = []
	for i in points.size():
		var way: Vector3 = (points[mini(i+1,points.size()-1)]-points[maxi(i-1,0)]).normalized()
		var ref = Vector3.UP if absf(way.dot(Vector3.UP)) < .9 else Vector3.RIGHT
		var n = ref.cross(way).normalized()
		var b = way.cross(n)
		var ring = []
		for s in sides+1:
			var a = TAU*float(s)/sides
			var out: Vector3 = n*cos(a)+b*sin(a)
			ring.append([points[i]+out*radii[i],out])
		rings.append(ring)
	for i in points.size()-1:
		for s in sides:
			quad(st,rings[i][s],rings[i][s+1],rings[i+1][s+1],rings[i+1][s],tint)

static func quad(st: SurfaceTool, a: Array, b: Array, c: Array, d: Array, tint: Color) -> void:
	for v in [a,c,b,a,d,c]:
		st.set_color(tint)
		st.set_normal(v[1])
		st.add_vertex(v[0])

# --- Webs ----------------------------------------------------------------------------

# A spider web across an inner corner of two walls: the corner's edge runs
# down the local Y axis, the walls' faces lie on the planes x = 0 and z = 0
# and the room is toward +X and +Z. It is anchored down each wall from `span`
# metres out from the corner, into the angle 1.2 `span` down it, and at the
# top by a free thread between the walls; it hangs from y = 0 down, sagging. The
# threads are drawn by its shader (assets/shaders/cobweb.gdshader) over a
# sheet laid round its hub.
static func web(span: float) -> MeshInstance3D:
	# (Hung near upright across the corner, so it faces into the room, and
	# so up at the camera, rather than lying flat as a roof over the angle.)
	var outline = [Vector3(span,0,0),Vector3(span*.5,-span,0),Vector3(0,-span*1.2,0),Vector3(0,-span,span*.5),Vector3(0,0,span)]
	var hub = Vector3(span*.36,-span*.48,span*.36)
	var node = web_mesh(hub,func(t): return around(outline,t),func(r): return Vector3(.06,-.1,.06)*span*sin(r*PI),span)
	node.name = "CornerWeb"
	return node

# A web draped flat on a wall whose face lies on the plane z = 0 (the room
# toward +Z), `width` wide about x = 0, hanging from y = 0 down and standing a
# little off the stone toward its hub.
static func wall_web(width: float) -> MeshInstance3D:
	var drop = width*.75
	var hub = Vector3(width*.04,-drop*.45,.05)
	var edge = func(t: float) -> Vector3:
		var a = TAU*t
		var ragged = 1.0+.08*sin(a*5.0+1.3)+.05*sin(a*9.0)
		return Vector3(cos(a)*width*.5*ragged,minf(0.0,-drop*.5+sin(a)*drop*.5*ragged),.008)
	var node = web_mesh(hub,edge,func(r): return Vector3(0,-.04*width*sin(r*PI),.03*width*(1.0-r)),width)
	node.name = "WallWeb"
	return node

# A web strung between a wall and something standing before it (a statue's
# shoulders): anchored along the wall's face on the plane z = 0, `width`
# wide about x = 0, from `top` down `drop`, and out across the gap to points
# `reach` along +Z (the room's side) a little below `top`, sagging between.
static func bridge_web(reach: float, width: float, top: float, drop: float) -> MeshInstance3D:
	var outline = [Vector3(-width*.5,top,0),Vector3(width*.5,top,0),Vector3(width*.35,top-drop,0),
		Vector3(width*.2,top-drop*.75,reach),Vector3(-width*.15,top-drop*.45,reach),Vector3(-width*.45,top-drop*.35,reach*.4)]
	var hub = Vector3(0,top-drop*.45,reach*.45)
	var node = web_mesh(hub,func(t): return around(outline,t),func(r): return Vector3(0,-.12*drop*sin(r*PI),0),maxf(width,reach))
	node.name = "BridgeWeb"
	return node

# A point `t` (0 to 1) of the way round the closed outline `points`.
static func around(points: Array, t: float) -> Vector3:
	var lengths = []
	var total = 0.0
	for i in points.size():
		var l = points[i].distance_to(points[(i+1)%points.size()])
		lengths.append(l)
		total += l
	var at = fposmod(t,1.0)*total
	for i in points.size():
		if at <= lengths[i] or i == points.size()-1: return points[i].lerp(points[(i+1)%points.size()],clampf(at/lengths[i],0,1))
		at -= lengths[i]
	return points[0]

# The sheet a web is drawn on: rings round `hub` out to `edge` (a point of its
# rim for each of 0 to 1 round it), sagging by `sag` (an offset for each
# distance out, 0 at the hub to 1 at the rim). Its UV is the angle round
# (x, 0 to 1) and the distance out (y); UV2.x carries `size` (metres), so
# the shader keeps its threads one width at any size.
const WEB_RINGS = 10
const WEB_SEGMENTS = 48
static func web_mesh(hub: Vector3, edge: Callable, sag: Callable, size: float) -> MeshInstance3D:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid = []
	for r in WEB_RINGS+1:
		var out = float(r)/WEB_RINGS
		var row = []
		for s in WEB_SEGMENTS+1:
			var t = float(s)/WEB_SEGMENTS
			row.append([hub.lerp(edge.call(t),out)+sag.call(out),Vector2(t,out)])
		grid.append(row)
	for r in WEB_RINGS:
		for s in WEB_SEGMENTS:
			for v in [grid[r][s],grid[r+1][s+1],grid[r][s+1],grid[r][s],grid[r+1][s],grid[r+1][s+1]]:
				st.set_uv(v[1])
				st.set_uv2(Vector2(size,0))
				st.set_normal(Vector3.UP)
				st.add_vertex(v[0])
	if not cache.has("cobweb"):
		var m = ShaderMaterial.new()
		m.shader = load("res://assets/shaders/cobweb.gdshader")
		cache.cobweb = m
	var node = MeshInstance3D.new()
	node.mesh = st.commit()
	node.material_override = cache.cobweb
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

# --- The gate --------------------------------------------------------------------------

# An iron grille gate shutting a doorway `width` wide and `height` high: two
# leaves of wrought bars, riveted where the rails cross them and spiked along
# the top, rust bleeding from the joints, meeting at a lock plate in the
# middle. They span local X from -width/2 to width/2 in the plane z = 0,
# hinged at their outer edges ("LeafL", "LeafR"), and swing open toward +Z
# (open_gate). Stone jambs stand either side, and a lintel spans the opening
# from `height` up to `lintel_top`, of `stone` (the basement's own masonry,
# unless given).
const JAMB = Vector2(.34,.42)
const BAR_SPACING = .14
static func gate(width: float, height: float, lintel_top: float, stone: Material = null) -> Node3D:
	if stone == null: stone = Art.material("stone",Color(.62,.58,.52))
	var root = Node3D.new()
	root.name = "Gate"
	for s in [-1,1]:
		var jamb = Art.model("wall",Vector3(JAMB.x,lintel_top,JAMB.y),stone)
		jamb.position = Vector3(s*(width*.5+JAMB.x*.5),0,0)
		root.add_child(jamb)
	if lintel_top > height:
		var lintel = Art.model("wall",Vector3(width+JAMB.x*2.0,lintel_top-height,JAMB.y),stone)
		lintel.position.y = height
		root.add_child(lintel)
	var leaf_width = width*.5-.01
	for s in [-1,1]:
		var pivot = Node3D.new()
		pivot.name = "LeafL" if s < 0 else "LeafR"
		pivot.position = Vector3(s*width*.5,0,0)
		root.add_child(pivot)
		var leaf = MeshInstance3D.new()
		leaf.name = "Grille"
		leaf.mesh = grille(leaf_width,height-.02,s > 0)
		leaf.material_override = iron(.75)
		# The leaf reaches from its hinge in toward the middle.
		leaf.position = Vector3(-s*leaf_width*.5,0,0)
		pivot.add_child(leaf)
		# Hinge straps on the jamb.
		for y in [.35,height-.45]:
			var strap = MeshInstance3D.new()
			var box = BoxMesh.new(); box.size = Vector3(.14,.06,.05)
			strap.mesh = box
			strap.material_override = iron(.9)
			strap.position = Vector3(-s*.03,y,0)
			pivot.add_child(strap)
	open_gate(root,0.0)
	return root

# How far open `gate` stands: shut (0) to wide open (1, OPEN_ANGLE), each leaf
# swung about its hinge toward +Z.
const OPEN_ANGLE = 95.0
static func open_gate(gate: Node3D, t: float) -> void:
	var angle = deg_to_rad(OPEN_ANGLE)*clampf(t,0.0,1.0)
	var left = gate.get_node_or_null("LeafL")
	var right = gate.get_node_or_null("LeafR")
	if left: left.rotation.y = -angle
	if right: right.rotation.y = angle
	gate.set_meta("open",t)

# One leaf's bars, `width` by `height` about its own middle (x), on the floor:
# uprights a hand apart, each spiked above the top rail; three rails across,
# riveted at every crossing; on the leaf that carries it (`lock`), the lock
# plate and its keyhole at the meeting edge.
static func grille(width: float, height: float, lock: bool) -> Mesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bars = maxi(2,roundi(width/BAR_SPACING))
	var top_rail = height-.22
	for i in bars+1:
		var x = -width*.5+width*float(i)/bars
		var bar = CylinderMesh.new()
		bar.top_radius = .018; bar.bottom_radius = .018; bar.height = top_rail+.04; bar.radial_segments = 6; bar.rings = 1
		st.append_from(bar,0,Transform3D(Basis(),Vector3(x,(top_rail+.04)*.5,0)))
		if i > 0 and i < bars:
			var spike = CylinderMesh.new()
			spike.top_radius = 0.0; spike.bottom_radius = .026; spike.height = .2; spike.radial_segments = 4; spike.rings = 1
			st.append_from(spike,0,Transform3D(Basis(),Vector3(x,top_rail+.04+.1,0)))
			var collar = SphereMesh.new()
			collar.radius = .028; collar.height = .05; collar.radial_segments = 6; collar.rings = 3
			st.append_from(collar,0,Transform3D(Basis(),Vector3(x,top_rail+.05,0)))
	# The frame's outer stiles, heavier.
	for x in [-width*.5,width*.5]:
		var stile = BoxMesh.new(); stile.size = Vector3(.05,height,.05)
		st.append_from(stile,0,Transform3D(Basis(),Vector3(x,height*.5,0)))
	for y in [.12,height*.48,top_rail]:
		var rail = BoxMesh.new(); rail.size = Vector3(width+.04,.06,.035)
		st.append_from(rail,0,Transform3D(Basis(),Vector3(0,y,0)))
		for i in bars+1:
			var rivet = SphereMesh.new()
			rivet.radius = .016; rivet.height = .02; rivet.radial_segments = 6; rivet.rings = 2
			var x = -width*.5+width*float(i)/bars
			for z in [-.02,.02]: st.append_from(rivet,0,Transform3D(Basis.from_euler(Vector3(PI/2,0,0)),Vector3(x,y,z)))
	if lock:
		# The lock plate at the meeting edge (this leaf's -X side), a keyhole
		# through it either side.
		var plate = BoxMesh.new(); plate.size = Vector3(.2,.28,.07)
		var at = Vector3(-width*.5+.08,height*.48,0)
		st.append_from(plate,0,Transform3D(Basis(),at))
		var hasp = BoxMesh.new(); hasp.size = Vector3(.12,.05,.09)
		st.append_from(hasp,0,Transform3D(Basis(),at+Vector3(-.1,.06,0)))
	st.generate_normals()
	var mesh = st.commit()
	if lock:
		# The keyhole, dark, a surface of its own.
		var hole = SurfaceTool.new()
		hole.begin(Mesh.PRIMITIVE_TRIANGLES)
		var at = Vector3(-width*.5+.08,height*.48-.03,0)
		for z in [-.0375,.0375]:
			var ring = CylinderMesh.new()
			ring.top_radius = .016; ring.bottom_radius = .016; ring.height = .005; ring.radial_segments = 8; ring.rings = 1
			hole.append_from(ring,0,Transform3D(Basis.from_euler(Vector3(PI/2,0,0)),at+Vector3(0,.02,z)))
			var slot = BoxMesh.new(); slot.size = Vector3(.014,.04,.005)
			hole.append_from(slot,0,Transform3D(Basis(),at+Vector3(0,0,z)))
		hole.commit(mesh)
		var black = StandardMaterial3D.new()
		black.albedo_color = Color(.01,.01,.01)
		black.roughness = 1.0
		mesh.surface_set_material(1,black)
	return mesh

# Wrought iron gone to rust (assets/shaders/rusty_iron.gdshader): `rust`, how
# much of it has (0, dark worn iron, to 1, rust bleeding from every joint).
static func iron(rust: float) -> ShaderMaterial:
	var key = "iron%f" % rust
	if cache.has(key): return cache[key]
	var m = ShaderMaterial.new()
	m.shader = load("res://assets/shaders/rusty_iron.gdshader")
	m.set_shader_parameter("grit",load("res://assets/textures/rock_detail.jpg"))
	m.set_shader_parameter("rust",rust)
	cache[key] = m
	return m

# --- The key ------------------------------------------------------------------------------

# The gate's key: a great old iron key, KEY_LENGTH long, lying flat (its
# shaft along X, the bow toward -X), its origin at its middle. Darkened iron
# worn bright where hands have held it, and gleaming dully along its rims
# (KEY_GLINT), so it catches the eye on a dark floor.
const KEY_LENGTH = .2
const KEY_GLINT = .6
static func key_model() -> Node3D:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half = KEY_LENGTH*.5
	var flat = Basis()
	# The bow: a ring.
	var bow = TorusMesh.new()
	bow.inner_radius = .016; bow.outer_radius = .028; bow.rings = 16; bow.ring_segments = 6
	st.append_from(bow,0,Transform3D(flat,Vector3(-half+.028,0,0)))
	# The shaft, with a collar at each end.
	var shaft = CylinderMesh.new()
	shaft.top_radius = .0065; shaft.bottom_radius = .0065; shaft.height = KEY_LENGTH-.07; shaft.radial_segments = 8; shaft.rings = 1
	st.append_from(shaft,0,Transform3D(Basis.from_euler(Vector3(0,0,PI/2)),Vector3(.005,0,0)))
	for x in [-half+.058,-half+.072,half-.05]:
		var collar = CylinderMesh.new()
		collar.top_radius = .0105; collar.bottom_radius = .0105; collar.height = .006; collar.radial_segments = 8; collar.rings = 1
		st.append_from(collar,0,Transform3D(Basis.from_euler(Vector3(0,0,PI/2)),Vector3(x,0,0)))
	# The bit: a plate off the shaft's end, cut into wards.
	var bit = BoxMesh.new(); bit.size = Vector3(.034,.006,.028)
	st.append_from(bit,0,Transform3D(Basis(),Vector3(half-.022,0,.019)))
	for k in 3:
		var ward = BoxMesh.new(); ward.size = Vector3(.007,.006,.012)
		st.append_from(ward,0,Transform3D(Basis(),Vector3(half-.034+k*.012,0,.036+(k%2)*.004)))
	st.generate_normals()
	var mesh = st.commit()
	var key = MeshInstance3D.new()
	key.name = "Key"
	key.mesh = mesh
	if not cache.has("key"):
		var m: ShaderMaterial = iron(.12).duplicate()
		m.set_shader_parameter("worn",1.0)
		m.set_shader_parameter("glint",KEY_GLINT)
		cache.key = m
	key.material_override = cache.key
	var root = Node3D.new()
	root.name = "IronKey"
	root.add_child(key)
	return root
