extends SceneTree
## Animation audit: plays every clip each unit uses, as the game plays it (with
## its in-game duration, blends and the return to the idle), sampled at 120 Hz,
## and reports, per unit and clip:
##   pop    the largest one-sample jump of a tracked point beyond what its
##          neighbouring samples move (a part leaping from place to place);
##   kink   the largest change of a point's velocity within one sample;
##   slide  how far each planted foot skates over the ground (and, running,
##          how the stride's speed compares with the unit's movement);
##   grip   how far the weapon's handle strays from the closed fist holding it.
## Run: Godot --headless --path . --script tools/anim_audit.gd [-- unit ...]
const Visual = preload("res://scripts/visual.gd")
const Data = preload("res://scripts/data.gd")
const Motion = preload("res://scripts/combat_animation.gd")
const DT = 1.0/120
const POINTS = ["hand_l","hand_r","foot_l","foot_r","ball_l","ball_r","Head","pelvis","lowerarm_l","lowerarm_r","calf_l","calf_r","spine_03"]
# The gripping hand's fingertips, whose distance from the palm shows whether
# the hand is closed on its weapon.
const TIPS = ["index_03","middle_03","ring_03"]

var report = []

func _initialize(): call_deferred("run")

func unit_specs() -> Array:
	var specs = []
	var weapons = Data.WEAPONS
	for w in weapons.size():
		var kind: String = weapons[w]
		var cls = {"bow":"ranger","staff":"wizard"}.get(kind,"warrior")
		var normal = Motion.NORMAL[w]
		var acts = [[normal.clip,normal.seconds,"attack"]]
		if kind == "bow": acts.append(["BowShot",.78,"attack"])
		elif kind in ["sword","spear","axe"]: acts.append([{"sword":"SwordSlash","spear":"SpearJab","axe":"AxeChop"}[kind],.84,"attack"])
		acts += [["Cast",.7,"attack"],["Evade",.25,"attack"],["Hit",.34,"react"],["HitHead",.34,"react"],["HitStagger",.6,"react"],["HitKnockdown",1.5,"react"]]
		specs.append({"name":"hero_"+kind,"stone":false,"weapon":kind,"size":1.0,"enemy":"","class":cls,"speed":5.94,"acts":acts})
	var statue_acts = {
		"gladiator":[["SwordSwing",.42/.52,"attack"]],
		"centurion":[["ShieldStab",.42/.5,"attack"]],
		"archer":[["ArcherShot",1.2/.78,"attack"]],
		"wizard":[["OracleCast",2.0/.8,"attack"],["OracleCast",.5/.2,"nova"]],
		"boss":[["SwordSwing",.65/.52,"attack"],["Cast",2.0,"attack"]],
		"lion":[["Attack",.67,"attack"]]}
	for kind in statue_acts:
		var c = Data.ENEMIES[kind]
		var acts = statue_acts[kind]+[["Hit",.34,"react"],["HitHead",.34,"react"],["HitStagger",.6,"react"],["HitKnockdown",1.5,"react"]]
		specs.append({"name":kind,"stone":true,"weapon":c.weapon,"size":c.size,"enemy":kind,"class":"warrior","speed":c.speed,"acts":acts})
	return specs

func points_of(v) -> Dictionary:
	var out = {}
	for b in POINTS:
		var i = v.skeleton.find_bone(b)
		if i >= 0: out[b] = v.skeleton.global_transform*v.skeleton.get_bone_global_pose(i).origin
	if is_instance_valid(v.weapon_item):
		var t: Transform3D = weapon_transform(v)
		out["weapon_tip"] = t*Vector3(0,1,0)
		out["weapon_base"] = t*Vector3(0,0,0)
	return out

# The weapon's transform now: a top-level item is placed each pose; one on a
# bone attachment follows its bone (computed here, as the attachment itself
# only updates when the scene processes a frame).
func weapon_transform(v) -> Transform3D:
	var item: Node3D = v.weapon_item
	if item.top_level: return item.global_transform
	var attachment = item.get_parent()
	var bone = v.skeleton.find_bone(attachment.bone_name)
	return v.skeleton.global_transform*v.skeleton.get_bone_global_pose(bone)*item.transform

# How far the weapon's shaft line passes from the centre of the fist that
# holds it (the bow in the left, everything else in the right).
func grip_error(v) -> float:
	if not is_instance_valid(v.weapon_item) or v.weapon_kind == "": return 0.0
	var side = "l" if v.weapon_kind == "bow" else "r"
	var fist: Vector3 = v.bow_hold(side)[0]
	var t: Transform3D = weapon_transform(v)
	if v.weapon_kind == "bow":
		return fist.distance_to(t*Visual.BOW_GRIP)
	var a: Vector3 = t*Vector3(0,0,0)
	var b: Vector3 = t*Vector3(0,1,0)
	return fist.distance_to(Geometry3D.get_closest_point_to_segment(fist,a,b))

# How far the gripping hand's fingertips are from where a fist closed on
# the weapon puts them (the hand's own frame; a closed fist reads near 0).
var fist_reference = {}
func fist_error(v) -> float:
	if not is_instance_valid(v.weapon_item) or v.weapon_kind == "": return 0.0
	var side = "l" if v.weapon_kind == "bow" else "r"
	# The bow's string hand opens to shoot; only the bow hand is checked.
	var hand: Transform3D = v.skeleton.get_bone_global_pose(v.skeleton.find_bone("hand_"+side))
	var worst = 0.0
	for tip in TIPS:
		var local: Vector3 = hand.affine_inverse()*v.skeleton.get_bone_global_pose(v.skeleton.find_bone(tip+"_"+side)).origin
		var key = side+tip
		if not fist_reference.has(key): fist_reference[key] = local
		worst = maxf(worst,local.distance_to(fist_reference[key]))
	return worst

func make(spec) -> Node3D:
	var holder = Node3D.new(); root.add_child(holder)
	var v = Visual.new(); holder.add_child(v)
	v.setup(spec.stone,Color.WHITE,spec.weapon,spec.size,spec.enemy,spec["class"])
	if spec.enemy == "boss": v.crown()
	return holder

# Runs `steps` of the game's own calls against a fresh unit and records.
# Each sample lets one frame pass, in which the skeleton applies its
# modifiers (the foot planter, the hand grip, the cloth): the points are taken
# from that final, rendered pose, inside the skeleton's update (afterwards it
# returns to the bare animation).
var shown = {}
func record(spec, plan: Array, speed: float = 0.0) -> Dictionary:
	var holder = make(spec)
	var v = holder.get_child(0)
	var capture = func():
		v.align_weapon()
		shown = {"p":points_of(v),"grip":maxf(grip_error(v),fist_error(v))}
	v.skeleton.skeleton_updated.connect(capture)
	var frames = []
	var grips = []
	var busy = 0.0
	var moving = false
	var t = 0.0
	var steps = []
	for p in plan: steps.append(p)
	var end_time = 0.0
	for p in plan: end_time = maxf(end_time,p[0])
	end_time += .8
	while t < end_time:
		while not steps.is_empty() and steps[0][0] <= t+1e-6:
			var s = steps.pop_front()
			match s[1]:
				"play":
					# (The Oracle's nova goes straight into its swing, as cast_nova.)
					if s.size() > 4 and s[4] == "nova": v.play_from(s[2],s[3],.8)
					else: v.play(s[2],s[3])
					busy = s[3]
				"react": v.react(s[2],s[3])
				"move": moving = true
				"stop": moving = false
				"turn": holder.rotation.y += s[2]
		busy = maxf(0.0,busy-DT)
		if moving: holder.position += holder.global_basis.z*speed*DT
		v.locomotion(moving,busy>0,spec.enemy=="lion",1.0,speed if moving else 0.0)
		v.advance(DT)
		shown = {}
		await process_frame
		if shown.is_empty(): shown = {"p":points_of(v),"grip":maxf(grip_error(v),fist_error(v))}
		frames.append({"t":t,"p":shown.p,"root":holder.position})
		grips.append(shown.grip)
		t += DT
	holder.queue_free()
	return {"frames":frames,"grips":grips}

func analyse(rec: Dictionary, window: Array, running: bool = false) -> Dictionary:
	var frames: Array = rec.frames
	var res = {"pop":0.0,"pop_at":"","kink":0.0,"kink_at":"","slide":0.0,"slide_at":"","grip":0.0,"grip_at":0.0}
	var keys = frames[0].p.keys()
	for k in keys:
		var d = []
		for i in range(1,frames.size()):
			d.append((frames[i].p[k]-frames[i-1].p[k]).length())
		for i in range(2,d.size()-2):
			var t = frames[i+1].t
			if t < window[0] or t > window[1]: continue
			var around = maxf(maxf(d[i-2],d[i-1]),maxf(d[i+1],d[i+2]))
			var pop = d[i]-2.0*around
			if pop > res.pop: res.pop = pop; res.pop_at = "%s@%.2f" % [k,t]
			var dv = absf(d[i]-d[i-1])/DT
			if dv > res.kink: res.kink = dv; res.kink_at = "%s@%.2f" % [k,t]
	# Feet in contact: within 1.5cm of the lowest the foot gets in this
	# record (a lifted step clears that), slow vertically.
	for foot in ["ball_l","ball_r"]:
		if not keys.has(foot): continue
		var low = INF
		for f in frames: low = minf(low,f.p[foot].y)
		var skate = 0.0
		for i in range(1,frames.size()):
			var t = frames[i].t
			if t < window[0] or t > window[1]: continue
			var a: Vector3 = frames[i-1].p[foot]; var b: Vector3 = frames[i].p[foot]
			if a.y < low+.015 and b.y < low+.015 and absf(b.y-a.y) < .002:
				skate += Vector2(b.x-a.x,b.z-a.z).length()
		if skate > res.slide: res.slide = skate; res.slide_at = foot
	for i in rec.grips.size():
		var t = frames[i].t
		if t < window[0] or t > window[1]: continue
		if rec.grips[i] > res.grip: res.grip = rec.grips[i]; res.grip_at = t
	return res

func line(unit: String, what: String, r: Dictionary, extra: String = "") -> void:
	var s = "AUDIT %-13s %-24s pop %.3f %-18s kink %5.2f %-18s slide %.3f %-6s grip %.3f@%.2f %s" % [unit,what,r.pop,r.pop_at,r.kink,r.kink_at,r.slide,r.slide_at,r.grip,r.grip_at,extra]
	print(s)

# Each locomotion clip's ground speed: how fast a planted foot sweeps back
# under the body, at normal playback and life size.
func strides() -> void:
	var holder = make({"stone":false,"weapon":"sword","size":1.0,"enemy":"","class":"warrior"})
	var v = holder.get_child(0)
	for clip in Visual.LOCOMOTION:
		if not v.clips.has(clip): continue
		var anim: Animation = v.animator.get_animation(v.clips[clip])
		var n = 120
		var speeds = []
		for foot in ["ball_l","ball_r"]:
			var pts = []
			for i in n+1:
				v.animator.play(v.clips[clip],0); v.animator.seek(anim.length*i/n,true); v.animator.advance(0)
				v.skeleton.force_update_all_bone_transforms()
				pts.append(v.bone_position(foot))
			var low = pts.map(func(p): return p.y).min()
			for i in range(1,n+1):
				if pts[i].y < low+.02 and pts[i-1].y < low+.02:
					speeds.append(-(pts[i].z-pts[i-1].z)/(anim.length/n))
		speeds.sort()
		print("STRIDE %s %.2f" % [clip,speeds[speeds.size()/2] if speeds.size() > 0 else 0.0])
	quit()

# Prints one point's height and speed each sample through one clip.
func trace(args: Array) -> void:
	var spec = unit_specs().filter(func(s): return s.name == args[1])[0]
	var plan = [[0.0,"stop"],[.4,"react" if args[2].begins_with("Hit") else "play",args[2],float(args[3])],[.4+float(args[3])+.6,"stop"]]
	if args[2].begins_with("run>"):
		var clip = args[2].trim_prefix("run>")
		plan = [[0.0,"move"],[.6,"stop"],[.6,"play",clip,float(args[3])],[.6+float(args[3])+.4,"stop"]]
	var rec = await record(spec,plan,spec.speed)
	var point = args[4]
	for i in range(1,rec.frames.size()):
		var a: Vector3 = rec.frames[i-1].p[point]; var b: Vector3 = rec.frames[i].p[point]
		print("TRACE %.3f y %.3f speed %.2f  at (%.2f %.2f %.2f)" % [rec.frames[i].t,b.y,a.distance_to(b)/DT,b.x,b.y,b.z])
	quit()

func run():
	if "--trace" in OS.get_cmdline_user_args():
		await trace(OS.get_cmdline_user_args())
		return
	if "--strides" in OS.get_cmdline_user_args():
		strides()
		return
	var only = OS.get_cmdline_user_args()
	for spec in unit_specs():
		if only.size() > 0 and not spec.name in only: continue
		# Standing in the idle.
		var rec = await record(spec,[[0.0,"stop"],[2.0,"stop"]])
		line(spec.name,"idle",analyse(rec,[.3,2.8]))
		# Running: the planted foot should keep still on the ground as the
		# unit moves; then stopping.
		rec = await record(spec,[[0.0,"stop"],[.4,"move"],[2.4,"stop"]],spec.speed)
		var run_r = analyse(rec,[.9,2.3])
		line(spec.name,"run",run_r,"(%.2fm skated over 1.4s at %.2fm/s)" % [run_r.slide,spec.speed])
		line(spec.name,"start+stop",analyse(rec,[.35,.9]),"")
		line(spec.name,"stop",analyse(rec,[2.35,3.1]),"")
		# Turning on the spot to face a new way.
		rec = await record(spec,[[0.0,"stop"],[.5,"turn",PI/2],[1.0,"stop"]])
		line(spec.name,"turn 90",analyse(rec,[.45,.6]))
		for act in spec.acts:
			var plan = [[0.0,"stop"]]
			if act[2] == "react": plan.append([.4,"react",act[0],act[1]])
			else: plan.append([.4,"play",act[0],act[1],act[2]])
			plan.append([.4+act[1]+.6,"stop"])
			rec = await record(spec,plan)
			line(spec.name,"%s %.2fs" % [act[0],act[1]],analyse(rec,[.35,.4+act[1]+.7]))
			# Attacking out of a run.
			if act[2] == "attack" and act == spec.acts[0]:
				rec = await record(spec,[[0.0,"move"],[.6,"stop"],[.6,"play",act[0],act[1],act[2]],[.6+act[1]+.4,"stop"]],spec.speed)
				line(spec.name,"run>%s" % act[0],analyse(rec,[.55,.6+act[1]+.5]))
	quit()
