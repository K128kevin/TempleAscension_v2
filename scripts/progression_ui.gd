extends RefCounted
const Data = preload("res://scripts/data.gd")
const Book = preload("res://scripts/skill_data.gd")

static func open(game, title: String, subtitle: String) -> void:
	game.mode = "character"
	game.world.process_mode = Node.PROCESS_MODE_DISABLED
	game.left_held = false; game.right_held = false
	game.hud.dialog(title,subtitle)

static func character(game) -> void:
	var r: Dictionary = game.run
	open(game,"%s · LEVEL %d" % [r.class_id.to_upper(),r.level],"%d attribute points available · C closes this screen\n%s" % [r.points,"Maximum level" if r.level==30 else "%d / %d XP to next level" % [r.xp-Data.xp_at_level(r.level),Data.XP_STEPS[r.level-1]]])
	for i in 5:
		var b = game.hud.button("%s  %d   ·   %s   [+]" % [Data.STATS[i],r.stats[i],Data.STAT_HELP[i]],func():
			if game.run.points>0:
				game.run.stats[i] += 1; game.run.points -= 1
				game.player.max_hp = Data.max_health(game.run)
				game.save_run(); character(game))
		b.disabled = r.points<=0
	game.hud.label("Health %.0f · Energy %.0f · Regeneration %.1f/sec" % [Data.max_health(r),Data.max_energy(r),Data.energy_regen(r)],16,game.hud.cream,game.hud.modal_body)
	var reset = game.hud.button("Refund attributes and skills · free at a safe entrance",func():
		if not game.safe_checkpoint(): return
		Data.respec(game.run)
		game.player.hp = minf(game.player.hp,Data.max_health(game.run))
		game.player.max_hp = Data.max_health(game.run)
		game.skills.reset()
		game.save_run(); character(game))
	reset.disabled = not game.safe_checkpoint()
	game.hud.button("Skills",func(): skills(game))
	game.hud.button("Return to game",game.resume_game)

static func skills(game) -> void:
	open(game,"%s SKILLS" % game.run.class_id.to_upper(),"%d skill points · RMB, 1 and 2 are your active skill slots.\nLMB uses your weapon's basic attack. Passives apply automatically.\nChange assignments out of combat. K closes." % game.run.skill_points)
	for id in Book.all():
		var s: Dictionary = Book.all()[id]
		if s.class_id!=game.run.class_id: continue
		var rank = int(game.run.skills.get(id,0))
		var cap = Book.rank_cap(id,int(game.run.level))
		var scaling = {"melee":"Strength","ranged":"Dexterity","spell":"Intelligence","":"utility"}[s.tag]
		var current = "%.0f%% damage" % (Book.value(id,rank)*100) if not s.tag.is_empty() and s.effect!="passive" else "%.1f" % Book.value(id,rank)
		var next = "%.0f%% damage" % (Book.value(id,rank+1)*100) if not s.tag.is_empty() and s.effect!="passive" else "%.1f" % Book.value(id,rank+1)
		var title = "%s%s · %d/%d · level %d · %s" % [s.title," (passive)" if s.effect=="passive" else "",rank,s.max_rank,s.unlock,scaling]
		game.hud.label(title,19,game.hud.gold,game.hud.modal_body)
		var details = game.hud.label("%s\nValue %s → %s · %d energy per cast · Requires %s" % [s.description,current,next,game.skills.cost(id),s.requirement],15,game.hud.cream,game.hud.modal_body)
		details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var upgrade = game.hud.button("Learn / Upgrade" if rank<cap else ("Maximum rank" if rank==s.max_rank else "Next rank requires level %d" % (s.unlock+rank*3)),func():
			if Book.learn(game.run,id):
				game.player.max_hp = Data.max_health(game.run)
				if s.effect!="passive" and not id in game.run.hotbar and game.out_of_combat():
					var empty = game.run.hotbar.find("")
					if empty>=0: game.run.hotbar[empty] = id
				game.save_run(); skills(game))
		upgrade.disabled = game.run.skill_points<=0 or rank>=cap
		if rank>0 and s.effect!="passive":
			var assign = game.hud.button("Assign %s to a slot" % s.title,func(): assignment(game,id))
			assign.disabled = not game.out_of_combat()
	game.hud.button("Character / Free respec",func(): character(game))
	game.hud.button("Return to game",game.resume_game)

static func assignment(game, id: String) -> void:
	open(game,"ASSIGN "+Book.all()[id].title.to_upper(),"Choose an active skill slot.")
	for i in 3:
		var old: String = game.run.hotbar[i]
		game.hud.button("%s · %s" % ["RMB" if i==0 else str(i),"Empty" if old.is_empty() else Book.all()[old].title],func():
			if not game.out_of_combat(): return
			for j in 3:
				if game.run.hotbar[j]==id: game.run.hotbar[j] = ""
			game.run.hotbar[i] = id
			game.save_run(); skills(game))
	game.hud.button("Back",func(): skills(game))

static func equipment(game) -> void:
	open(game,"EQUIPMENT","All classes can use all weapon families. Class skills show their requirements.\nChange equipment out of combat. Sword includes a shield.")
	for i in 5:
		var button = game.hud.button(Data.WEAPONS[i].capitalize()+(" · equipped" if game.run.weapon==i else ""),func():
			game.equip(i); equipment(game))
		button.disabled = not game.run.owned[i] or not game.out_of_combat()
	game.hud.button("Return to game",game.resume_game)

static func creation(game, difficulty: int) -> void:
	open(game,"CHOOSE YOUR CLASS","Every class starts at level 1 with five in each attribute.\nYour first skill point learns the starter skill shown below.")
	var summaries = ["Warrior · sword and shield · Cleave","Ranger · bow · Power Shot","Wizard · staff · Firebolt"]
	for i in 3:
		game.hud.button(summaries[i],func():
			game.creating_character = false
			game.run = Data.new_run(Data.CLASSES[i]); game.run.difficulty = difficulty
			game.load_floor(); game.save_run()
			game.toast("%s created. Kill enemies to earn XP. C: attributes · K: skills · I: equipment." % Data.CLASSES[i].capitalize()))
