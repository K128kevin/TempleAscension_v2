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
		check(run.stats==[5,5,5,5,5] and run.level==1 and Data.max_health(run)==100 and Data.max_energy(run)==100 and Data.energy_regen(run)==10,"Shared base resources and attributes: "+class_id)
		check(run.skills.size()==1 and run.skill_points==0 and Book.compatible(run.hotbar[0],run.weapon),"Starter point is spent on a usable skill: "+class_id)
		check(run.owned.count(true)==1 and run.owned[run.weapon],"Each class owns only its starting weapon: "+class_id)
		var active = 0; var passive = 0
		for s in Book.all().values():
			if s.class_id!=class_id: continue
			if s.effect=="passive": passive += 1
			else: active += 1
			check(s.tree in Book.TREES,"Every skill sits in one of the three trees: "+s.id)
			if class_id=="warrior": check(s.max_rank==5 and s.ranks.size()==5 and s.points in [0,5,10,15] and Book.rank_cap(s.id,1)==5,"Warrior skills have five listed ranks behind a tree requirement: "+s.id)
			else: check(Book.rank_cap(s.id,s.unlock-1)==0 and Book.rank_cap(s.id,s.unlock)==1 and Book.rank_cap(s.id,s.unlock+3)==2,"Level/rank gate: "+s.id)
		check(active==(11 if class_id=="warrior" else 8) and passive==(8 if class_id=="warrior" else 4),"The class's active skills and passives: "+class_id)
		Data.gain_xp(run,Data.xp_at_level(15))
		check(run.level==15 and run.points==70 and run.skill_points==14 and Data.max_health(run)==100,"Level 15 awards 70 attributes and 15 total skills without implicit stats: "+class_id)
		check(Save.valid(run),"Progression state validates: "+class_id)
		Data.gain_xp(run,100000000)
		check(run.level==20 and Data.MAX_LEVEL==20 and run.points==95 and run.skill_points==19,"Level cap of 20 and point budgets (five attributes and one skill a level): "+class_id)
		var points = run.points
		Data.gain_xp(run,100000)
		check(run.points==points,"XP at cap cannot mint points: "+class_id)
		Data.respec(run)
		check(run.skill_points==20 and run.points==95 and run.hotbar==["","",""] and Save.valid(run),"Respec refunds exact budgets and clears slots: "+class_id)
		for tag in ["melee","ranged","spell"]:
			var i: int = {"melee":0,"ranged":1,"spell":2}[tag]
			run.stats[i] += 10
			check(is_equal_approx(Data.damage_tag(run,tag,100),120),"Shared +2%% scaling for %s / %s" % [class_id,tag])
			for other in ["melee","ranged","spell"]:
				if other!=tag: check(is_equal_approx(Data.damage_tag(run,other,100),100),"Exclusive scaling tag %s does not affect %s" % [tag,other])
			run.stats[i] -= 10
	# The warrior's trees, as listed in the design document.
	var cleave = Book.values("cleave",1); var cleave_top = Book.values("cleave",5)
	check(cleave.x==140 and cleave.y==125 and cleave_top.x==180 and cleave_top.y==165 and Book.all().cleave.cost==25,"Cleave's listed ranks and cost")
	var slam = Book.values("ground_slam",5)
	check(slam.x==250 and slam.y==120 and slam.z==21 and Book.all().ground_slam.cost==40 and Book.all().ground_slam.points==5,"Ground Slam's listed ranks, cost and requirement")
	var bash = Book.values("shield_bash",1); var bash_top = Book.values("shield_bash",5)
	check(bash.x==25 and bash.y==5 and bash.z==32 and bash_top.x==50 and bash_top.y==10 and bash_top.z==20 and Book.all().shield_bash.cost==35,"Shield Bash's listed ranks and cost")
	check(Book.values("execute",5).x==450 and Book.values("execute",5).y==40 and Book.all().execute.cost==45 and Book.all().execute.points==10,"Execute's listed ranks, cost and requirement")
	check(Book.values("quick_strikes",5).x==170 and Book.values("dash_attack",5).x==0 and Book.values("dash_attack",1).x==20 and Book.values("cursed_blade",5).y==8,"Passive ranks as listed")
	var requirements = {}
	for s in Book.all().values():
		if s.class_id=="warrior": requirements[s.id] = s.points
	check(requirements=={"cleave":0,"leap":5,"ground_slam":5,"powerful_strike":0,"shield_bash":0,"vampiric_strike":5,"shadow_strike":5,"execute":10,"war_cry":0,"shield_charge":10,"shockwave":10,"dash_attack":0,"shield_expertise":0,"endurance":0,"quick_strikes":5,"cursed_blade":5,"offensive_rhythm":10,"defensive_rhythm":10,"spiked_shield":10},"Document levels 1, 5, 10 and 15 become 0, 5, 10 and 15 points in the tree (Shadow Strike opening with Vampiric Strike, at 5; Execute at 10)")
	# A skill opens once enough points are spent in its own tree.
	var fresh = Data.new_run()
	fresh.skill_points = 1
	check(not Book.learn(fresh,"meteor"),"Cannot learn another class's skill")
	check(not Book.learn(fresh,"leap") and fresh.skill_points==1,"Leap is locked without five points in Area of Effect")
	check(Book.learn(fresh,"cleave") and fresh.skills.cleave==2 and fresh.skill_points==0,"Ranks are bought with skill points, not held back by level")
	check(not Book.learn(fresh,"cleave"),"No skill points, no rank")
	fresh.skill_points = 30
	for i in 3: Book.learn(fresh,"cleave")
	check(fresh.skills.cleave==5 and not Book.learn(fresh,"cleave"),"Five ranks at most")
	check(not Book.can_learn(fresh,"vampiric_strike") and "Single Target" in Book.locked(fresh,"vampiric_strike"),"Points in one tree do not open another")
	check(Book.learn(fresh,"leap") and Book.learn(fresh,"ground_slam"),"Five points in the tree open its second row")
	for i in 4: Book.learn(fresh,"powerful_strike")
	check(not Book.can_learn(fresh,"shadow_strike"),"Four Single Target points do not open Shadow Strike")
	Book.learn(fresh,"powerful_strike")
	check(Book.can_learn(fresh,"shadow_strike") and not Book.can_learn(fresh,"execute"),"Five Single Target points open Shadow Strike, not Execute")
	for i in 4: Book.learn(fresh,"shield_bash")
	check(not Book.can_learn(fresh,"execute"),"Nine points still do not open Execute")
	Book.learn(fresh,"shield_bash")
	check(Book.tree_points(fresh.skills,"single")==10 and Book.learn(fresh,"execute"),"Ten points open Execute")
	check(Book.reachable(fresh.skills) and not Book.reachable({"leap":1,"cleave":4}) and not Book.reachable({"execute":1,"powerful_strike":5,"shield_bash":4}),"Saved ranks must be reachable through the tree")
	var cheat = Data.new_run(); cheat.skills = {"execute":1}
	check(not Save.valid(cheat),"A save with a skill its tree has not opened is rejected")
	# Dexterity quickens melee swings; Endurance, energy recovery.
	var quick = Data.new_run(); quick.stats[1] = 25
	check(Data.melee_attack_speed(quick)==20 and is_equal_approx(Data.damage_tag(quick,"ranged",100),140),"Each point of Dexterity adds 1% melee attack speed and still 2% ranged damage")
	quick.skills.quick_strikes = 5
	check(Data.melee_attack_speed(quick)==190 and Data.melee_haste(quick)==20,"Quick Strikes adds to normal attack speed only")
	var hardy = Data.new_run(); hardy.skills.endurance = 5
	check(is_equal_approx(Data.energy_regen(hardy),17.5) and Data.max_health(hardy)==100,"Endurance speeds energy recovery by its listed percent")
	# Earlier saves: everything spent is refunded under the new rules.
	var prior = Data.new_run(); prior.version=3
	prior.level=4; prior.xp=Data.xp_at_level(4); prior.points=9; prior.skill_points=1
	prior.skills={"cleave":1,"guard":1,"shield_bash":1}
	prior.hotbar=["cleave","","","guard","shield_bash"]
	prior.drops=[{"kind":"weapon","value":2,"id":"weapon:0","position":[0,9]},{"kind":"weapon","value":3,"id":"weapon:1","position":[0,9]}]
	var converted = Save.migrate(prior)
	check(Save.valid(prior) and Save.valid(converted) and converted.version==Data.new_run().version and converted.place=="temple" and converted.hotbar==["","",""] and converted.drops.is_empty() and converted.skills.is_empty() and converted.skill_points==4 and converted.points==15,"Version 3 saves migrate, retire pending bow/axe drops and refund their points")
	var veteran = Data.new_run("wizard"); veteran.version=5
	veteran.level=27; veteran.xp=60000; veteran.stats=[5,5,60,10,18]; veteran.points=0
	veteran.skills={"firebolt":5,"meteor":4}; veteran.skill_points=18; veteran.hotbar=["firebolt","meteor",""]
	var capped = Save.migrate(veteran)
	check(Save.valid(capped) and capped.level==20 and capped.xp==Data.xp_at_level(20) and capped.stats==[5,5,5,5,5] and capped.points==95 and capped.skill_points==20 and capped.get("migration_notice",false),"Version 5 saves above the new cap come down to level 20 with every point refunded")
	var old = {"version":2,"floor":3,"stats":[6,3,2,5],"owned":[true,true,true,true],"weapon":0,"difficulty":1,"dead":["3:0"],"gems":["gem:2:0"],"drops":[],"deaths":2,"seed":78,"position":[0,9],"health":140,"energy":120,"phase":"allocation","points":5,"completed":false}
	var migrated = Save.migrate(old)
	check(Save.valid(migrated) and migrated.stats==[5,5,5,5,5] and migrated.level==12 and migrated.points==55,"Legacy saves retain campaign progress and refund old bonuses into the new level budget")
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
	check(simulated.level>=18 and simulated.level<=20,"The temple's enemies bring a character to the level cap by the summit")
	FileAccess.open("res://test-results/progression-regression.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failed":failed},"  "))
	print("PROGRESSION_REGRESSION ",passed.size()," passed; ",failed)
	quit(0 if failed.is_empty() else 1)
