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
	for case in [["hero_sword","SwordSwing",.84,"play"],["hero_sword","SwordSlash",.84,"play"],["hero_axe","AxeChop",.94,"play"],["hero_bow","ArcherShot",.78,"play"],["archer","ArcherShot",1.54,"play"],["gladiator","SwordSwing",.81,"play"],["gladiator","HitKnockdown",1.5,"react"],["boss","SwordSwing",1.25,"play"],["hero_sword","HitStagger",.6,"react"],["wizard","OracleCast",2.5,"nova"]]:
		var spec = specs[case[0]]
		var plan = [[0.0,"stop"],[.4,"react" if case[3] == "react" else "play",case[1],case[2],case[3]],[.4+case[2]+.6,"stop"]]
		var r = analyse(await record(spec,plan),[.35,.4+case[2]+.7])
		var k: float = spec.size
		check(r.pop < .03*k,"%s %s: nothing leaps between frames (%.3fm at %s)" % [case[0],case[1],r.pop,r.pop_at])
		check(r.slide < .06*k,"%s %s: planted feet keep still (%.3fm)" % [case[0],case[1],r.slide])
		if spec.weapon == "bow": check(r.grip < .01,"%s %s: the bow stays in the fist (%.3fm)" % [case[0],case[1],r.grip])
	# Out of a run straight into a shot: the bow is raised, not switched.
	var archer = specs["archer"]
	var r = analyse(await record(archer,[[0.0,"move"],[.6,"stop"],[.6,"play","ArcherShot",1.54],[2.6,"stop"]],archer.speed),[.55,2.6])
	check(r.pop < .03 and r.grip < .01,"An archer shoots out of a run without the bow jumping (%.3fm)" % r.pop)
	print("ANIMATION_REGRESSION ",passed.size()," passed; ",failed)
	quit()
