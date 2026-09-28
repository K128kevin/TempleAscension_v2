extends SceneTree
const Data = preload("res://scripts/data.gd")
const Book = preload("res://scripts/skill_data.gd")
const Save = preload("res://scripts/save.gd")
var passed: Array = []
var failed: Array = []
func _initialize(): call_deferred("test")
func check(ok: bool, message: String):
	if ok: passed.append(message)
	else: failed.append(message); push_error(message)
func test():
	for class_id in Data.CLASSES:
		var run = Data.new_run(class_id)
		check(run.stats==[5,5,5,5,5] and run.level==1 and Data.max_health(run)==100 and Data.max_energy(run)==100 and Data.energy_regen(run)==8,"Shared base resources and attributes: "+class_id)
		check(run.skills.size()==1 and run.skill_points==0 and Book.compatible(run.hotbar[0],run.weapon),"Starter point is spent on a usable skill: "+class_id)
		check(run.owned.count(true)==1 and run.owned[run.weapon],"Each class owns only its starting weapon: "+class_id)
		var active = 0; var passive = 0
		for s in Book.all().values():
			if s.class_id!=class_id: continue
			if s.effect=="passive": passive += 1
			else: active += 1
			check(Book.rank_cap(s.id,s.unlock-1)==0 and Book.rank_cap(s.id,s.unlock)==1 and Book.rank_cap(s.id,s.unlock+3)==2,"Level/rank gate: "+s.id)
		check(active==8 and passive==4,"Eight active and four passive skills: "+class_id)
		Data.gain_xp(run,Data.xp_at_level(25))
		check(run.level==25 and run.points==72 and run.skill_points==24 and Data.max_health(run)==100,"Level 25 awards 72 attributes and 25 total skills without implicit stats: "+class_id)
		check(Save.valid(run),"Progression state validates: "+class_id)
		Data.gain_xp(run,100000000)
		check(run.level==30 and run.points==87 and run.skill_points==29,"Level cap and point budgets: "+class_id)
		var points = run.points
		Data.gain_xp(run,100000)
		check(run.points==points,"XP at cap cannot mint points: "+class_id)
		Data.respec(run)
		check(run.skill_points==30 and run.points==87 and run.hotbar==["","",""] and Save.valid(run),"Respec refunds exact budgets and clears slots: "+class_id)
		for tag in ["melee","ranged","spell"]:
			var i: int = {"melee":0,"ranged":1,"spell":2}[tag]
			run.stats[i] += 10
			check(is_equal_approx(Data.damage_tag(run,tag,100),120),"Shared +2%% scaling for %s / %s" % [class_id,tag])
			for other in ["melee","ranged","spell"]:
				if other!=tag: check(is_equal_approx(Data.damage_tag(run,other,100),100),"Exclusive scaling tag %s does not affect %s" % [tag,other])
			run.stats[i] -= 10
	var prior = Data.new_run(); prior.version=3
	Data.gain_xp(prior,Data.xp_at_level(4)); Book.learn(prior,"guard"); Book.learn(prior,"shield_bash")
	prior.hotbar=["cleave","","","guard","shield_bash"]
	prior.drops=[{"kind":"weapon","value":2,"id":"weapon:0","position":[0,9]},{"kind":"weapon","value":3,"id":"weapon:1","position":[0,9]}]
	var converted = Save.migrate(prior)
	check(Save.valid(prior) and Save.valid(converted) and converted.hotbar==["cleave","",""] and converted.drops.is_empty() and converted.skills==prior.skills,"Version 3 saves migrate to three active slots and retire pending bow/axe drops")
	var fresh = Data.new_run()
	fresh.skill_points = 1
	check(not Book.learn(fresh,"meteor"),"Cannot learn another class's or locked skill")
	check(not Book.learn(fresh,"cleave"),"Cannot buy rank two at level one")
	var old = {"version":2,"floor":3,"stats":[6,3,2,5],"owned":[true,true,true,true],"weapon":0,"difficulty":1,"dead":["3:0"],"gems":["gem:2:0"],"drops":[],"deaths":2,"seed":78,"position":[0,9],"health":140,"energy":120,"phase":"allocation","points":5,"completed":false}
	var migrated = Save.migrate(old)
	check(Save.valid(migrated) and migrated.stats==[5,5,5,5,5] and migrated.level==12 and migrated.points==33,"Legacy saves retain campaign progress and refund old bonuses into the new level budget")
	check("3:0" in migrated.xp_claimed and migrated.gems.is_empty(),"Migration retires permanent gems and remembers rewarded enemies")
	Save.directory = ProjectSettings.globalize_path("res://test-results/progression-save")
	check(Save.write(migrated),"Write migrated save")
	var loaded = Save.load_run()
	check(loaded.class_id==migrated.class_id and loaded.skills==migrated.skills and loaded.xp==migrated.xp,"Class, skills, XP and budgets survive save round-trip")
	var simulated = Data.new_run()
	for floor_index in 5:
		simulated.floor = floor_index
		for kind in Data.COUNTS[floor_index]:
			for i in Data.COUNTS[floor_index][kind]: Data.gain_xp(simulated,Data.enemy_xp(simulated,kind))
	print("TEMPLE_XP_SIMULATION level=",simulated.level," xp=",simulated.xp)
	check(simulated.level>=18 and simulated.level<=26,"Existing temple enemies unlock the final skill tier by the summit")
	FileAccess.open("res://test-results/progression-regression.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failed":failed},"  "))
	print("PROGRESSION_REGRESSION ",passed.size()," passed; ",failed)
	quit(0 if failed.is_empty() else 1)
