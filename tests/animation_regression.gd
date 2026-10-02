extends "res://tools/anim_audit.gd"
## Animation regression (tools/anim_audit.gd's measures, on a sample of units
## and clips, as rendered: foot planting, hand grips and cloth applied):
## nothing leaps from one frame to the next, planted feet keep still, the run
## cycle keeps pace with the ground, and held weapons stay in the fist.
var passed: Array = []
var failed: Array = []

func check(ok: bool, message: String) -> void:
	if ok: passed.append(message)
	else:
		failed.append(message)
		push_error(message)

# How deep, at worst, the body reaches into the shield's board, and the
# spear into it, through one clip as rendered.
const BODY = [["pelvis","spine_03",.15],["spine_03","neck_01",.16],["neck_01","Head",.1],["thigh_l","calf_l",.09],["thigh_r","calf_r",.09],["upperarm_r","lowerarm_r",.06],["lowerarm_r","hand_r",.05]]
func into_board(v, p: Vector3, r: float) -> float:
	var board: Transform3D = v.shield_item.global_transform
	var centre: Vector3 = board*Vector3(0,.5,0)
	var d = INF
	for axis in 3:
		var dir: Vector3 = board.basis[axis]
		d = minf(d,dir.length()*(.5 if axis != 2 else .3)+r-absf((p-centre).dot(dir.normalized())))
	return d
func shield_depth(spec, clip: String) -> Array:
	var holder = make(spec)
	var v = holder.get_child(0)
	var worst = [0.0,0.0]
	# Measured only through the clip itself (not while the unit settles).
	var measuring = [false]
	var take = func():
		if not measuring[0]: return
		v.align_weapon()
		for limb in BODY:
			var a = v.bone_position(limb[0]); var b = v.bone_position(limb[1])
			for i in 9: worst[0] = maxf(worst[0],into_board(v,a.lerp(b,i/8.0),limb[2]*v.rig.scale.x))
		if v.weapon_kind == "spear":
			for i in 25: worst[1] = maxf(worst[1],into_board(v,v.weapon_item.global_transform*Vector3(0,i/24.0,0),.01))
	v.skeleton.skeleton_updated.connect(take)
	for i in 20: v.locomotion(false,false); v.advance(DT); await process_frame
	var duration = .84 if clip == "ShieldStab" else .34
	measuring[0] = true
	if clip == "ShieldStab": v.play(clip,duration)
	else: v.react(clip,duration)
	var busy = duration
	for i in int((duration+.4)/DT):
		busy -= DT
		v.locomotion(false,busy>0); v.advance(DT)
		holder.position += holder.global_basis.z*v.take_travel()
		await process_frame
	holder.queue_free()
	return worst

func run():
	var specs = {}
	for spec in unit_specs(): specs[spec.name] = spec
	# Standing, turning on the spot and stopping: feet planted, nothing jumps.
	for name in ["hero_sword","archer"]:
		var spec = specs[name]
		var r = analyse(await record(spec,[[0.0,"stop"],[.5,"turn",PI/2],[1.2,"stop"]]),[.45,1.9])
		check(r.pop < .02 and r.slide < .03,"%s turns on the spot without a jump or sliding feet (pop %.3f, slide %.3f)" % [name,r.pop,r.slide])
		var rec = await record(spec,[[0.0,"stop"],[.4,"move"],[2.4,"stop"]],spec.speed)
		r = analyse(rec,[.9,2.3])
		check(r.slide < .05,"%s's stride keeps pace with the ground (%.3fm skated)" % [name,r.slide])
		r = analyse(rec,[2.35,3.1])
		check(r.pop < .02 and r.slide < .08,"%s stops without sliding (%.3fm)" % [name,r.slide])
	# Attacks and reactions: in and out of the idle without a jump, feet
	# planted, weapons in the fist.
	for case in [["hero_sword","SwordSwing",.84,"play"],["hero_sword","SwordSlash",.84,"play"],["hero_axe","AxeChop",.94,"play"],["hero_bow","ArcherShot",.78,"play"],["archer","ArcherShot",1.54,"play"],["gladiator","ScutumSwordSwing",.81,"play"],["gladiator","HitKnockdown",1.5,"react"],["boss","SwordSwing",1.25,"play"],["hero_sword","HitStagger",.6,"react"],["wizard","OracleCast",2.5,"nova"]]:
		var spec = specs[case[0]]
		var plan = [[0.0,"stop"],[.4,"react" if case[3] == "react" else "play",case[1],case[2],case[3]],[.4+case[2]+.6,"stop"]]
		var r = analyse(await record(spec,plan),[.35,.4+case[2]+.7])
		var k: float = spec.size
		check(r.pop < .03*k,"%s %s: nothing leaps between frames (%.3fm at %s)" % [case[0],case[1],r.pop,r.pop_at])
		check(r.slide < .06*k,"%s %s: planted feet keep still (%.3fm)" % [case[0],case[1],r.slide])
		if spec.weapon == "bow": check(r.grip < .01,"%s %s: the bow stays in the fist (%.3fm)" % [case[0],case[1],r.grip])
	# The warrior's swing and cleave step forward, carrying him on (the
	# centurion's thrust too), his feet planted as he goes.
	for case in [["hero_sword","SwordSwing",.84],["hero_sword","SwordSlash",.84],["centurion","ShieldStab",.84]]:
		var spec = specs[case[0]]
		var rec = await record(spec,[[0.0,"stop"],[.4,"play",case[1],case[2],"play"],[.4+case[2]+.6,"stop"]])
		var moved: float = rec.frames[-1].root.z-rec.frames[0].root.z
		check(moved > .3*spec.size,"%s %s steps forward (%.2fm)" % [case[0],case[1],moved])
	# The shield bearers' shields stay out of their bodies as they flinch, and
	# the centurion's spear out of his shield as he thrusts.
	for case in [["gladiator","Hit"],["gladiator","HitHead"],["centurion","Hit"],["centurion","HitHead"],["centurion","ShieldStab"]]:
		var depth = await shield_depth(specs[case[0]],case[1])
		check(depth[0] < .015,"%s %s: the shield stays out of the body (%.3fm)" % [case[0],case[1],depth[0]])
		if case[0] == "centurion": check(depth[1] < .03,"%s %s: the spear stays out of the shield (%.3fm)" % [case[0],case[1],depth[1]])
	# Out of a run straight into a shot: the bow is raised, not switched.
	var archer = specs["archer"]
	var r = analyse(await record(archer,[[0.0,"move"],[.6,"stop"],[.6,"play","ArcherShot",1.54],[2.6,"stop"]],archer.speed),[.55,2.6])
	check(r.pop < .03 and r.grip < .01,"An archer shoots out of a run without the bow jumping (%.3fm)" % r.pop)
	print("ANIMATION_REGRESSION ",passed.size()," passed; ",failed)
	quit()
