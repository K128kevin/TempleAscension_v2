extends SceneTree
## The item system in play: the catalogue, what each class may wear and wield,
## the equipment slots and the bag, weapon damage as the baseline of attacks
## and skills (and the wizard's own), armor, what enemies drop and how it is
## picked up, how items show on the hero, every class's attacks with every
## kind of weapon it can hold, saves, and the inventory itself.
## (`-- --render-items` also takes pictures, in a window.)
const Data = preload("res://scripts/data.gd")
const Items = preload("res://scripts/items.gd")
const Book = preload("res://scripts/skill_data.gd")
const Save = preload("res://scripts/save.gd")
const Motion = preload("res://scripts/combat_animation.gd")
const Art = preload("res://scripts/assets.gd")
const STEP = 1.0/60
var game
var origin: Vector3
var passed: Array = []
var failed: Array = []
var render = false
func _initialize(): call_deferred("test")
func check(ok: bool, message: String):
	if ok: passed.append(message)
	else: failed.append(message); push_error(message)

func snapshot(name: String):
	if not render: return
	game.hud.tick(0)
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/items-"+name+".png")

# A character of that class on the temple's first floor, every enemy but one
# put away; nothing drops unless a test says so, and no hit is a critical
# strike or is blocked.
# (The floor is loaded once for each class in turn, and kept while the next
# character is of the same class.)
var loaded = ""
func hero(class_id: String, changes: Dictionary = {}):
	var kept: int = game.run.seed
	game.run = Data.new_run(class_id)
	for slot in changes: game.run.equipment[slot] = changes[slot]
	game.loot_off = true
	if loaded == class_id:
		game.run.seed = kept
		for p in game.pickups: p.node.queue_free()
		game.pickups.clear()
		game.pickup_goal = null
		game.refit()
	else:
		game.load_floor()
		loaded = class_id
	origin = game.world.spawn
	for e in game.enemies: e.dead = true; e.visible = false
	ready()

func ready():
	game.resume_game()
	game.player.position = origin
	game.player.busy = 0; game.player.cooldown = 0; game.player.invulnerable = 0
	game.player.max_hp = Data.max_health(game.run); game.player.hp = game.player.max_hp
	game.scheduled.clear(); game.skills.reset()
	for p in game.projectiles: p.node.queue_free()
	game.projectiles.clear()
	game.run.energy = Data.max_energy(game.run)
	game.leap_left = 0; game.dash_time = 0; game.combat_age = 10
	game.skills.crit_override = 0
	game.skills.block_override = 0

# The one enemy left standing, `ahead` metres in front of the hero, asleep
# (`which` of the floor's: one that is slain is not stood up again).
var slain = 0
func foe(ahead: float = 1.4, hp: float = 100000.0):
	var e = game.enemies[slain]
	e.dead = false; e.visible = true; e.awake = false; e.dormant = false
	e.max_hp = hp; e.hp = hp
	e.end_stun(); e.dots.clear()
	e.rally_time = 0; e.rally_bonus = 0; e.mark_time = 0; e.weak_stacks = 0; e.slow_time = 0
	e.position = game.world.move(origin,Vector3(0,0,-ahead))
	return e

func play(seconds: float):
	for i in ceili(seconds/STEP):
		game.player.tick(STEP)
		game.tick_scheduled(STEP)
		game.skills.tick(STEP)
		game.tick_projectiles(STEP)
		game.tick_fireballs(STEP)

# The least and most of `count` normal attacks on `victim`.
func blows(victim, count: int) -> Array:
	var least = INF; var most = 0.0
	for i in count:
		game.player.busy = 0; game.player.cooldown = 0
		var before: float = victim.hp
		game.attack(false,victim.position)
		play(1.4)
		least = minf(least,before-victim.hp); most = maxf(most,before-victim.hp)
	return [least,most]

func test():
	render = "--render-items" in OS.get_cmdline_user_args()
	Save.directory = ProjectSettings.globalize_path("res://test-results/items-save")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.test_mode = true
	game.set_process(false)
	game.sound.muted = true

	# --- The catalogue.
	var droppable = 0
	for id in Items.ALL:
		var item: Dictionary = Items.ALL[id]
		var sound = item.has("name") and item.slot in Items.ARMOR_SLOTS+["weapon","shield","key"]
		# (A key is only carried: it has a name, never drops at random, and is pictured.)
		if item.slot == "key": sound = sound and not item.has("rarity") and ResourceLoader.exists("res://assets/ui/items/%s.png" % id)
		elif item.slot in Items.ARMOR_SLOTS: sound = sound and item.weight in Items.ARMOR_OF.values() and item.armor > 0
		elif item.slot == "weapon": sound = sound and item.kind in Items.KIND_TITLES and item.hands in [1,2] and (item.has("damage") and item.damage[0] > 0 and item.damage[1] >= item.damage[0] or item.kind == "staff")
		else: sound = sound and item.block > 0 and item.mitigation > 0
		if item.slot in ["weapon","shield"]: sound = sound and ResourceLoader.exists("res://assets/models/props/%s.glb" % item.look.model) and item.look.has("size") and (item.slot == "shield" or item.look.has("grip"))
		for key in item.get("bonus",{}): sound = sound and Items.BONUS_TEXT.has(key)
		check(sound,"The item is well made: "+id)
		check(ResourceLoader.exists("res://assets/ui/items/%s.png" % id),"The item has its picture: "+id)
		var thing: Node3D = Art.laid(id)
		check(thing != null and not thing.find_children("*","MeshInstance3D",true,false).is_empty(),"The item has a model to lie on the ground: "+id)
		thing.free()
		check(Items.WIELDS.keys().any(func(c): return Items.usable(c,id)),"Some class can use the item: "+id)
		if item.has("rarity"): droppable += 1
	check(droppable >= 12 and droppable <= 30,"A handful of items drop (%d)" % droppable)
	for class_id in Data.CLASSES:
		var pool: Array = Items.loot(class_id)
		check(pool.size() >= 6 and pool.all(func(id): return Items.usable(class_id,id) and Items.ALL[id].has("rarity")),"Every class has its own drops, all of them usable: %s (%d)" % [class_id,pool.size()])

	# --- What each class starts with, and may use.
	var totals: Dictionary = {}
	for class_id in Data.CLASSES:
		var run = Data.new_run(class_id)
		var whole = true
		for slot in Items.ARMOR_SLOTS: whole = whole and Items.worn(run,slot).get("weight","") == Items.ARMOR_OF[class_id] and Items.worn(run,slot).slot == slot
		check(whole and run.bag.size() == Items.BAG_SIZE and Save.valid(run),"A new %s wears a whole set of %s armor, and has a bag of ten places" % [class_id,Items.ARMOR_OF[class_id]])
		totals[class_id] = Data.armor(run)
	check(totals.warrior == 26.0 and totals.ranger == 17.0 and totals.wizard == 10.0,"Heavy armor protects more than medium, and medium than light: %s" % totals)
	for slot in Items.ARMOR_SLOTS:
		check(Items.ALL[Items.STARTING.warrior.equipment[slot]].armor > Items.ALL[Items.STARTING.ranger.equipment[slot]].armor and Items.ALL[Items.STARTING.ranger.equipment[slot]].armor > Items.ALL[Items.STARTING.wizard.equipment[slot]].armor,"Piece for piece, heavier armor has more: "+slot)
	check(Items.main(Data.new_run("warrior")).kind == "sword" and not Items.shield(Data.new_run("warrior")).is_empty(),"The warrior starts with sword and shield")
	check(Items.main(Data.new_run("ranger")).kind == "bow" and "hunting_dagger" in Data.new_run("ranger").bag,"The ranger with his bow, his dagger in his bag")
	check(Items.main(Data.new_run("wizard")).kind == "staff","The wizard with his staff")
	var may = {"warrior":["sword","shield","mace","axe","spear","bow"],"ranger":["bow","dagger","sword"],"wizard":["staff","dagger"]}
	for class_id in may:
		for kind in Items.KIND_TITLES:
			check(Items.usable(class_id,Items.PLAIN[kind]) == (kind in may[class_id]),"%s %s a %s" % [class_id,"can use" if kind in may[class_id] else "cannot use",kind])
		for other in Data.CLASSES:
			check(Items.usable(class_id,Items.STARTING[other].equipment.chest) == (other == class_id),"%s armor is the %s's alone (%s)" % [Items.ARMOR_OF[other],other,class_id])

	# --- The slots and the bag.
	var w = Data.new_run("warrior")
	check(Items.misfit(w,"gladiator_helm","chest") != "" and Items.misfit(w,"lion_shield","main") != "" and Items.misfit(w,"greatsword","off") != "" and Items.misfit(w,"deep_hood","head") != "" and Items.misfit(w,"silver_staff","main") != "","Things go only where they fit, on one who can use them")
	Items.stow(w,"greatsword"); Items.stow(w,"flanged_mace"); Items.stow(w,"bronze_hatchet")
	check(Items.move(w,"bag:0","main") == "" and w.equipment.main == "greatsword" and w.equipment.off == "" and "legionary_sword" in w.bag and "lion_shield" in w.bag,"A two-handed weapon taken up empties both hands into the bag")
	check(Items.move(w,"bag:%d" % w.bag.find("lion_shield"),"off") == "" and w.equipment.off == "lion_shield" and w.equipment.main == "" and "greatsword" in w.bag,"A shield taken up sends a two-handed weapon back to it")
	check(Items.move(w,"bag:%d" % w.bag.find("flanged_mace"),"main") == "" and Items.move(w,"bag:%d" % w.bag.find("bronze_hatchet"),"off") == "" and w.equipment.main == "flanged_mace" and w.equipment.off == "bronze_hatchet" and "lion_shield" in w.bag,"Two one-handed weapons, one in each hand")
	check(Items.damage_span(w) == [15.0+13.0*.5,19.0+19.0*.5],"The off hand's weapon adds half its damage: %s" % [Items.damage_span(w)])
	check(Items.move(w,"main","off") == "" and w.equipment.main == "bronze_hatchet" and w.equipment.off == "flanged_mace","The two hands' weapons change places")
	check(Items.move(w,"head","bag:%d" % Items.free_bag_slot(w)) == "" and w.equipment.head == "" and "gladiator_helm" in w.bag and Data.armor(w) == 21.0,"Armor taken off goes into the bag, and protects no longer")
	check(Items.slot_for(w,"gladiator_helm") == "head" and Items.slot_for(w,"lion_shield") == "off" and Items.slot_for(w,"greatsword") == "main","A right click knows where a thing goes")
	check(Items.move(w,"bag:%d" % w.bag.find("gladiator_helm"),"bag:9") == "" and w.bag[9] == "gladiator_helm","Things are moved about the bag")
	check(Save.valid(w),"A character is save-valid however it is equipped")
	var full = Data.new_run("warrior")
	for i in Items.BAG_SIZE: full.bag[i] = "bandit_sica"
	check(not Items.stow(full,"greatsword") and Items.move(full,"head","bag:0") != "" and full.equipment.head == "gladiator_helm","A full bag takes nothing more")
	full.bag[3] = "greatsword"
	check(Items.move(full,"bag:3","main") != "" and full.equipment.main == "legionary_sword" and full.equipment.off == "lion_shield","With no room for the shield, a two-handed weapon cannot be taken up")
	var bad = Data.new_run("wizard"); bad.equipment.main = "legionary_sword"
	check(not Save.valid(bad),"A save in which a wizard holds a sword is refused")
	bad = Data.new_run("warrior"); bad.equipment.main = "greatsword"
	check(not Save.valid(bad),"So is a two-handed weapon beside a shield")

	# --- Weapon damage is the baseline of the normal attack and of every skill.
	hero("warrior")
	var victim = foe()
	var dealt: Array = blows(victim,24)
	check(dealt[0] >= 10.0-.001 and dealt[1] <= 15.0+.001 and dealt[1]-dealt[0] > 2.0,"The Legionary's Sword hits for 10 to 15 (%.1f to %.1f)" % dealt)
	game.run.bag[0] = "greatsword"
	check(game.move_item("bag:0","main") == "" and game.player.visual.weapon_kind == "heavy" and not is_instance_valid(game.player.visual.shield_item),"A greatsword from the bag is in both his hands, his shield put away")
	check(Data.stat(game.run,0) == 7 and Data.span(game.run,"melee") == [22.0,32.0],"It adds its Strength, and its damage is the baseline")
	ready(); victim = foe(1.6)
	dealt = blows(victim,24)
	check(dealt[0] >= 22.0*1.04-.001 and dealt[1] <= 32.0*1.04+.001 and dealt[0] > 15.0,"The greatsword hits for 22 to 32, raised by Strength (%.1f to %.1f)" % dealt)
	game.run.skills = {"powerful_strike":1}
	var least = INF; var most = 0.0
	for i in 16:
		ready(); victim = foe(1.6)
		check(game.skills.cast("powerful_strike",victim.position),"Powerful Strike is cast with the greatsword") if i == 0 else game.skills.cast("powerful_strike",victim.position)
		play(1.4)
		least = minf(least,victim.max_hp-victim.hp); most = maxf(most,victim.max_hp-victim.hp)
	check(least >= 44.0*1.04-.001 and most <= 64.0*1.04+.001,"A skill deals its percent of the weapon's damage: Powerful Strike 200%% of 22 to 32 (%.1f to %.1f)" % [least,most])
	check("23–33" in game.skills.damage_summary("powerful_strike",1).damage or "46–67" in game.skills.damage_summary("powerful_strike",1).damage,"The skill's tip shows what it hits for with this weapon: "+game.skills.damage_summary("powerful_strike",1).damage)
	check(game.skills.reason("shield_bash") == "Learn this skill first.","(Shield Bash is not learned)")
	game.run.skills = {"shield_bash":1,"cleave":1}
	check(game.skills.reason("shield_bash") == "Requires a shield." and game.skills.reason("cleave") == "","With both hands on a greatsword there is no shield to bash with; Cleave is his")

	# The ranger's bow and blade, each its own.
	hero("ranger",{"main":"hunters_recurve"})
	check(Data.span(game.run,"ranged") == [13.0,18.0] and Data.span(game.run,"melee") == [10.0,15.0],"A bow's damage is the bow's skills' baseline, the dagger in the bag the dagger's")
	victim = foe(6.0)
	dealt = blows(victim,16)
	check(dealt[0] >= 13.0-.001 and dealt[1] <= 18.0+.001,"The Hunter's Recurve shoots for 13 to 18 (%.1f to %.1f)" % dealt)
	check(is_equal_approx(Data.crit_chance(game.run),24.0),"and adds its critical strike chance")

	# The wizard: a set baseline worked from Intelligence; a staff may raise it.
	hero("wizard")
	check(Data.span(game.run,"spell") == Data.SPELL_SPAN and is_equal_approx(Data.damage_tag(game.run,"spell",100.0),105.0),"A wizard's spells have their own baseline, which the Twisted Silver Staff raises by 5%")
	game.run.stats[2] = 15
	check(is_equal_approx(Data.damage_tag(game.run,"spell",100.0),120.0*1.05),"Intelligence raises it 2% a point")
	game.run.stats[2] = 5
	game.run.skills = {"fireball":1}
	var with_silver: String = game.skills.damage_summary("fireball",1).damage
	game.run.bag[0] = "oracle_staff"
	check(game.move_item("bag:0","main") == "" and Data.stat(game.run,2) == 8 and is_equal_approx(Data.damage_tag(game.run,"spell",100.0),100.0*1.06*1.2),"The Oracle's Staff: +3 Intelligence and 20% more spell damage")
	check(game.skills.damage_summary("fireball",1).damage != with_silver,"and a spell's tip shows it (%s, was %s)" % [game.skills.damage_summary("fireball",1).damage,with_silver])
	game.run.bag[1] = "viper_fang"
	check(game.move_item("bag:1","main") == "" and game.player.visual.weapon_kind == "dagger" and is_equal_approx(Data.damage_tag(game.run,"spell",100.0),100.0),"With a dagger in hand, his spells are his Intelligence's alone")
	ready(); victim = foe(6.0)
	check(game.skills.reason("fireball") == "" and game.skills.cast("fireball",victim.position),"and can still be cast")
	play(2.0)
	check(victim.hp < victim.max_hp,"Fireball burns what it reaches")
	# (He has no normal attack, with staff or dagger: his left click casts a spell.)

	# --- Armor, and what else equipment gives.
	for class_id in Data.CLASSES:
		hero(class_id)
		game.hurt_player(50.0)
		check(is_equal_approx(game.player.max_hp-game.player.hp,50.0*(1.0-totals[class_id]*.01)),"The %s's armor takes %d%% off a blow" % [class_id,totals[class_id]])
		ready()
		game.hurt_player(50.0,"frost")
		check(is_equal_approx(game.player.max_hp-game.player.hp,50.0*(1.0-totals[class_id]*.01)),"whatever its kind: "+class_id)
	hero("warrior")
	game.run.bag[0] = "bronze_helm"; game.run.bag[1] = "bronze_cuirass"
	check(game.move_item("bag:0","head") == "" and game.move_item("bag:1","chest") == "" and Data.armor(game.run) == 33.0 and Data.max_health(game.run) == 100.0+20.0+25.0 and game.player.max_hp == 145.0,"Better armor: more protection, and its Vitality and health")
	check(game.run.bag[0] == "gladiator_helm" and game.run.bag[1] == "scale_cuirass","What it replaces goes where it came from")
	# The attributes tab shows each in all, and how much of it the items give.
	game.hud.panels.open_stats(); game.hud.panels.refresh()
	var gear: int = Data.stat(game.run,3)-int(game.run.stats[3])
	check(gear > 0 and game.hud.panels.stat_values[3].text == str(Data.stat(game.run,3)) and game.hud.panels.stat_splits[3].visible and game.hud.panels.stat_splits[3].text == "%d base · +%d items" % [game.run.stats[3],gear],"The attributes tab shows Vitality in all, its base and what items add (%s, %s)" % [game.hud.panels.stat_values[3].text,game.hud.panels.stat_splits[3].text])
	check(game.hud.panels.stat_values[0].text == str(game.run.stats[0]) and not game.hud.panels.stat_splits[0].visible,"An attribute no item raises shows only its value")
	game.hud.panels.close()
	check(game.move_item("chest","bag:5") == "" and game.player.max_hp == 120.0 and game.player.hp <= 120.0,"Taken off, its health goes with it")
	game.run.bag[6] = "bandit_sica"
	var plain: float = game.attack_profile().duration
	game.move_item("bag:6","main")
	check(is_equal_approx(game.attack_profile().duration,plain/1.05) and is_equal_approx(plain,.84),"The Bandit's Sica is 5% quicker")
	game.run.bag[7] = "bronze_aspis"
	game.move_item("bag:7","off")
	check(Data.block_chance(game.run) == 32.0 and Data.block_mitigation(game.run) == 28.0 and Data.stat(game.run,3) == 5+2+3,"A shield's block is its own")
	hero("ranger")
	var pace: float = game.player_pace()
	game.run.bag[1] = "dusk_cloak"; game.move_item("bag:1","head")
	check(is_equal_approx(game.player_pace(),pace*1.05),"The Dusk Cloak quickens his step")
	game.run.bag[2] = "viper_fang"; game.move_item("bag:2","main")
	ready(); victim = foe(1.4); game.player.hp = 50.0
	game.attack(false,victim.position); play(.6)
	check(is_equal_approx(game.player.hp,52.0),"Viper's Fang restores 2 health with a hit (%.1f)" % game.player.hp)

	# --- Every class's attacks with every kind of weapon it can hold.
	var seen = {}
	for class_id in Data.CLASSES:
		for id in Items.ALL:
			var item: Dictionary = Items.ALL[id]
			if item.slot != "weapon" or not Items.usable(class_id,id): continue
			var swung: String = Items.family(item)
			if seen.has(class_id+swung+item.kind): continue
			seen[class_id+swung+item.kind] = true
			hero(class_id,{"main":id,"off":""})
			var look = game.player.visual
			check(look.clips.has(look.idle_action()) and look.clips.has(look.run_action()),"A stance and a run for the %s with %s (%s, %s)" % [class_id,item.name,look.idle_action(),look.run_action()])
			# (The wizard has no normal attack: his left click casts a spell.)
			if Data.casts_left(game.run): continue
			var move: Dictionary = Motion.family(swung)
			victim = foe(5.0 if swung in ["bow","staff"] else 1.5)
			var states: Array = []
			for i in move.clips.size()+1:
				game.player.busy = 0; game.player.cooldown = 0
				var before: float = victim.hp
				game.attack(false,victim.position)
				states.append(look.state)
				check(look.clips.has(look.state) and (look.state in move.clips or (swung == "one" and look.state.begins_with("Sword"))),"The %s's attack with %s has its own motion: %s" % [class_id,item.name,look.state])
				play(1.6)
				check(victim.hp < before,"and it lands: %s / %s / %d" % [class_id,item.name,i])
			if move.clips.size() > 1: check(states[0] != states[1] and states[0] == states[move.clips.size()],"Its blows come by turns: %s" % [states])
	# The hatchet's haft is in his fist (its model's stands to one side of its
	# bit), and its bit is turned to lead his cuts: toward the model's -Z,
	# where a sword's edges are to either side.
	hero("warrior",{"main":"bronze_hatchet"})
	var haft_low = Vector3(INF,INF,INF); var haft_high = -haft_low
	var bit = Vector3.ZERO
	var axe: Node3D = game.player.visual.weapon_item
	for mesh in axe.find_children("*","MeshInstance3D",true,false):
		var within: Transform3D = axe.global_transform.affine_inverse()*mesh.global_transform
		for surface in mesh.mesh.get_surface_count():
			for v in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var p: Vector3 = Basis.from_scale(axe.scale)*(within*v)
				if p.y < .25: haft_low = haft_low.min(p); haft_high = haft_high.max(p)
				elif p.y > .58 and Vector2(p.x,p.z).length() > Vector2(bit.x,bit.z).length(): bit = p
	check(absf(haft_low.x+haft_high.x) < .02 and absf(haft_low.z+haft_high.z) < .02 and haft_high.x-haft_low.x < .1 and haft_high.z-haft_low.z < .1,"The hatchet's haft runs through his fist (%s to %s)" % [haft_low,haft_high])
	check(bit.z < -.2 and absf(bit.x) < absf(bit.z),"Its bit is turned to lead the cut (%s)" % bit)
	check(is_equal_approx(axe.scale.y,.72) and game.player.visual.edge[1] == 1.0,"and it is as long as it was")
	# The warrior's skills with each family of melee weapon.
	for id in ["legionary_sword","flanged_mace","bronze_hatchet","greatsword","executioner_axe","legion_hasta"]:
		var swung: String = Items.family(Items.ALL[id])
		for skill in Book.all().values():
			if skill.class_id != "warrior" or skill.effect == "passive": continue
			hero("warrior",{"main":id,"off":"lion_shield" if swung == "one" else ""})
			game.run.skills = {skill.id:1}
			victim = foe(1.5,1000.0 if skill.effect == "execute" else 100000.0)
			if skill.effect == "execute": victim.max_hp = 100000.0
			if skill.requirement == "shield" and swung != "one":
				check(game.skills.reason(skill.id) == "Requires a shield.","%s needs a shield: %s" % [skill.title,id])
				continue
			check(game.skills.cast(skill.id,victim.position),"%s is cast with %s" % [skill.title,Items.ALL[id].name])
			var wanted: String = Motion.skill_clip(swung,skill.effect)
			var state: String = game.player.visual.state
			if skill.effect in ["vampiric","shadow"]: check(game.player.visual.clips.has(state) and (state in Motion.family(swung).clips or state.begins_with("Sword")),"%s is struck with the weapon's own swing: %s / %s" % [skill.title,id,state])
			else: check(state == wanted and game.player.visual.clips.has(wanted),"%s has its own motion with %s: %s (playing %s)" % [skill.title,Items.ALL[id].name,wanted,state])
			var hp: float = victim.hp
			play(2.0)
			if skill.effect == "cry": check(victim.rally_time > 0,"War Cry cows: "+id)
			else: check(victim.hp < hp,"%s lands with %s" % [skill.title,Items.ALL[id].name])
	# A weapon in each hand strikes with each by turns.
	hero("warrior",{"main":"legionary_sword","off":"bandit_sica"})
	check(is_instance_valid(game.player.visual.off_item) and not is_instance_valid(game.player.visual.shield_item) and game.player.visual.idle_action() == "DualIdle","A second sword is held in the left hand")
	victim = foe(1.5)
	var hands: Array = []
	for i in 4:
		game.player.busy = 0; game.player.cooldown = 0
		var before: float = victim.hp
		game.attack(false,victim.position)
		hands.append(game.player.visual.state)
		play(1.4)
		check(before-victim.hp >= 10.0+12.0*.5-.001 and before-victim.hp <= 15.0+17.0*.5+.001,"Each blow has both weapons' damage in it (%.1f)" % (before-victim.hp))
	check(hands == ["SwordOpen","OffCut","SwordOpen","OffCut"],"The right hand's cut and the left's by turns: %s" % [hands])
	hero("ranger",{"main":"hunting_dagger","off":"viper_fang"})
	victim = foe(1.4)
	hands.clear()
	for i in 4:
		game.player.busy = 0; game.player.cooldown = 0
		game.attack(false,victim.position)
		hands.append(game.player.visual.state)
		play(.8)
	check(hands == ["DaggerStab","OffStab","DaggerSlash","OffStab"],"Two daggers: stab and slash with the right, the left between: %s" % [hands])
	# Bare hands.
	hero("warrior",{"main":"","off":""})
	victim = foe(1.3)
	dealt = blows(victim,8)
	check(Data.weapon(game.run) == Data.UNARMED and dealt[0] >= 1.0-.001 and dealt[1] <= 3.0+.001 and game.player.visual.weapon_kind == "","Bare hands do little (%.1f to %.1f)" % dealt)
	# X changes weapons. The warrior's skills need a melee weapon in hand:
	# with a bow he has only his normal attack, a shot.
	hero("warrior")
	game.run.bag[0] = "yew_longbow"
	game.swap_weapon()
	check(game.run.equipment.main == "yew_longbow" and game.run.equipment.off == "" and "legionary_sword" in game.run.bag and "lion_shield" in game.run.bag and game.player.visual.weapon_kind == "bow","X: the warrior takes up the bow from his bag, sword and shield put away")
	game.run.skills = {}
	for s in Book.all().values():
		if s.class_id == "warrior" and s.effect != "passive": game.run.skills[s.id] = 1
	victim = foe(5.0)
	var refused = true
	for id in game.run.skills:
		refused = refused and game.skills.reason(id) == ("Requires a shield." if Book.all()[id].requirement == "shield" else "Requires a melee weapon.") and not game.skills.cast(id,victim.position)
	check(refused and game.run.skills.size() == 11 and game.run.equipment.main == "yew_longbow" and is_equal_approx(game.run.energy,Data.max_energy(game.run)),"With a bow in hand none of the warrior's skills can be used, and none takes up the sword in his bag")
	dealt = blows(victim,1)
	check(dealt[0] > 0.0 and game.run.equipment.main == "yew_longbow","His normal attack with it is a bowshot")
	game.player.busy = 0
	game.swap_weapon()
	check(game.run.equipment.main == "legionary_sword" and game.run.equipment.off == "lion_shield" and game.skills.reason("cleave") == "" and game.skills.reason("shield_bash") == "","X again: sword and shield back in hand, and his skills with them")

	# --- Drops.
	var rng = RandomNumberGenerator.new()
	rng.seed = 20261005
	var counts: Dictionary = {}
	var fell = 0
	for i in 40000:
		var id: String = Items.roll_drop("warrior","gladiator",rng.randf(),rng.randf())
		if id.is_empty(): continue
		fell += 1
		counts[id] = counts.get(id,0)+1
	check(absf(fell/40000.0-.10) < .006,"A gladiator drops something one time in ten (%.3f)" % (fell/40000.0))
	var weight = 0.0
	for id in Items.loot("warrior"): weight += Items.RARITY_WEIGHTS[Items.rarity(id)]
	var fair = true
	for id in Items.loot("warrior"):
		var expected: float = Items.RARITY_WEIGHTS[Items.rarity(id)]/weight
		fair = fair and absf(counts.get(id,0)/float(fell)-expected) < .02
	check(fair and counts.keys().all(func(id): return Items.usable("warrior",id)),"Each by its rarity's weight, and only what a warrior can use")
	check(Items.rarity(Items.roll_drop("wizard","boss",.999,.5)) == "rare" and Items.roll_drop("wizard","bandit",.5,.5) == "","The Crowned Statue always drops a rare item; a bandit seldom drops at all")
	hero("warrior")
	victim = foe(1.4,10.0)
	game.loot_forced = "bronze_helm"
	victim.hit(1000.0)
	slain += 1
	check(victim.dead and game.pickups.size() == 1 and game.run.drops.size() == 1 and game.run.drops[0].item == "bronze_helm","A slain enemy's item falls to the ground")
	var lying = game.pickups[0]
	check(lying.node.position.distance_to(victim.position) < 1.2 and not lying.node.find_children("*","MeshInstance3D",true,false).is_empty(),"Its model lies where the enemy fell")
	game.hud.tick(0)
	var names: Array = game.hud.item_labels.filter(func(b): return b.visible)
	check(names.size() == 1 and names[0].text == "Bronze Arena Helm","Its name shows over it")
	await snapshot("ground")
	names[0].pressed.emit()
	check(game.pickups.is_empty() and game.run.drops.is_empty() and "bronze_helm" in game.run.bag,"Clicking the name picks it up, into the bag")
	game.hud.tick(0)
	check(game.hud.item_labels.filter(func(b): return b.visible).is_empty(),"and its name is gone")
	# From further off he walks to it first.
	# (Laid exactly, not where chance would put it, so he always has a path.)
	var spot: Vector3 = game.world.move(origin,Vector3(0,0,-6))
	var mace = {"item":"flanged_mace","position":[spot.x,spot.z]}
	game.run.drops.append(mace); game.create_pickup(mace)
	lying = game.pickups[0]
	game.pick_up(lying)
	check(game.pickups.size() == 1 and game.pickup_goal == lying and not game.route.is_empty(),"Clicked from afar, he sets out for it")
	for i in 900:
		game.player.tick(STEP); game.player_control(STEP)
		if game.pickups.is_empty(): break
	check(game.pickups.is_empty() and "flanged_mace" in game.run.bag and game.player.position.distance_to(origin) > 3.0,"and picks it up when he reaches it")
	# A full bag leaves it lying.
	for i in Items.BAG_SIZE: game.run.bag[i] = "bandit_sica"
	game.drop_item("greatsword",game.player.position)
	game.pick_up(game.pickups[0])
	check(game.pickups.size() == 1 and game.hud.notice.text == "Your bag is full.","With a full bag it stays on the ground")
	# What lies on the ground is kept with the save.
	game.save_run()
	game.continue_run()
	loaded = ""; slain = 0
	check(game.pickups.size() == 1 and game.run.drops[0].item == "greatsword" and game.run.bag.count("bandit_sica") == Items.BAG_SIZE,"A save keeps what lies on the ground, and the bag")
	# Thrown out of the inventory, an item lies at his feet.
	game.discard_item("bag:0")
	check(game.pickups.size() == 2 and game.run.bag[0] == "" and game.run.drops.size() == 2,"An item dragged out of the inventory is dropped")
	# A retried floor's enemies drop nothing a second time.
	hero("warrior")
	victim = foe(1.4,10.0)
	game.run.xp_claimed.append(victim.uid)
	game.loot_forced = "bronze_helm"
	victim.hit(1000.0)
	slain += 1
	check(game.pickups.is_empty(),"An enemy already rewarded drops nothing again")
	game.loot_forced = ""

	# --- Items show on the hero.
	hero("warrior")
	var look = game.player.visual
	check(look.parts.HeroHelmet.visible and look.parts.HeroArmor.visible and look.parts.HeroKilt.visible and look.parts.HeroBracers.visible and not look.parts.Hair_SimpleParted.visible and look.parts.SuperHero_Male.material_override == Art.hero_kit("warrior"),"The warrior's starting kit is drawn as it always was")
	game.move_item("head","bag:0")
	check(not look.parts.HeroHelmet.visible and look.parts.Hair_SimpleParted.visible,"Without his helm, his hair")
	game.move_item("chest","bag:1")
	check(not look.parts.HeroArmor.visible and look.parts.SuperHero_Male.material_override is ShaderMaterial and look.parts.SuperHero_Male.material_override.get_shader_parameter("bare").x == 1.0 and look.parts.SuperHero_Male.material_override.get_shader_parameter("bare").y == 0.0,"Without his cuirass, his bare chest (and his kilt still)")
	game.run.bag[2] = "bronze_cuirass"; game.move_item("bag:2","chest")
	check(look.parts.HeroArmor.visible and look.parts.HeroArmor.material_override != Art.hero_kit("warrior") and look.parts.SuperHero_Male.material_override.get_shader_parameter("recolor").x == 1.0,"A bronze cuirass is bronze")
	game.move_item("legs","bag:3"); game.move_item("hands","bag:4")
	check(not look.parts.HeroKilt.visible and not look.parts.HeroBelt.visible and not look.parts.HeroBracers.visible,"Kilt and manica come off")
	game.run.bag[5] = "executioner_axe"; game.move_item("bag:5","main")
	check(look.weapon_kind == "heavy" and look.family == "heavy" and is_instance_valid(look.weapon_item) and not is_instance_valid(look.shield_item) and look.idle_action() == "HeavyIdle" and look.two_hands.weight == 1.0,"The Executioner's Axe is held in both hands, in its own stance")
	game.run.bag[6] = "legion_hasta"; game.move_item("bag:6","main")
	check(look.weapon_kind == "pike" and look.idle_action() == "PikeIdle" and look.run_action() == "PikeRun" and look.clips.has("PikeRun") and look.clips.has("PikeWalk"),"The hasta in both hands, with its own stance, run and walk")
	check(is_equal_approx(game.attack_range(false),2.9) and game.attack_range(false) > Motion.reach("one"),"and a spear's reach")
	await snapshot("warrior-pike")
	hero("ranger")
	look = game.player.visual
	check(look.parts.RangerBody.visible and not look.parts.SuperHero_Male.visible and look.parts.RangerCloak.visible,"The ranger's kit as it always was")
	game.move_item("head","bag:1")
	check(not look.parts.RangerCloak.visible and look.parts.SuperHero_Male.visible and not look.parts.RangerBody.visible and look.parts.Hair_SimpleParted.visible,"Without his cloak, the whole of him is shown")
	game.run.bag[2] = "dusk_cloak"; game.move_item("bag:2","head")
	check(look.parts.RangerCloak.visible and look.parts.RangerCloak.material_override.get_shader_parameter("cloth_color") == Items.ALL.dusk_cloak.look.tint,"The Dusk Cloak is its own colour")
	hero("wizard")
	look = game.player.visual
	game.run.bag[0] = "ember_robe"; game.move_item("bag:0","chest")
	check(look.parts.WizardRobe.visible and look.parts.WizardRobe.material_override.get_shader_parameter("cloth_color") == Items.ALL.ember_robe.look.tint and look.parts.WizardHood.material_override.get_shader_parameter("cloth_color") != Items.ALL.ember_robe.look.tint,"The Ember Robe is red, his hood still his own")

	# --- Saves from before items.
	var old = Data.new_run("warrior")
	old.version = 10
	old.erase("equipment"); old.erase("bag")
	old.hotbar = ["","","","",""]
	old["owned"] = [false,true,true,false,false,false]; old["weapon"] = 1; old["shield"] = "round_shield"
	old.drops = [{"kind":"weapon","value":4,"id":"weapon:1","position":[0,9]}]
	var migrated = Save.migrate(old)
	check(Save.valid(old) and Save.valid(migrated) and migrated.version == Data.new_run().version and migrated.equipment == Data.new_run("warrior").equipment and "yew_longbow" in migrated.bag and migrated.drops.is_empty() and not migrated.has("owned"),"An earlier save is given its class's starting equipment, and a bow it owned in its bag")

	# --- The inventory.
	hero("warrior")
	var panels = game.hud.panels
	game.run.bag[0] = "bronze_helm"; game.run.bag[1] = "greatsword"; game.run.bag[2] = "deep_hood"
	game._input(key(KEY_I))
	game.hud.tick(0)
	check(game.mode == "character" and panels.inventory_open() and not panels.stats_open() and not panels.skills_open(),"I opens the character window at the inventory, pausing the game")
	check(panels.slots.size() == 17 and ["head","chest","legs","feet","hands","main","off"].all(func(s): return panels.slots.has(s)),"Seven equipment slots and ten bag places")
	var bag_rects: Array = []
	for i in Items.BAG_SIZE: bag_rects.append(panels.slots["bag:%d" % i].frame)
	check(bag_rects[0].get_parent() is GridContainer and bag_rects[0].get_parent().columns == 5 and bag_rects[0].get_parent().get_child_count() == 10,"The bag is a grid five wide and two tall")
	check(panels.figure.hero_class == "warrior" and panels.figure.worn == game.run.equipment,"The figure in the middle is the hero as he is dressed")
	check(panels.slots.head.icon.texture != null and panels.slots["bag:1"].icon.texture != null and panels.slots["bag:5"].icon.texture == null,"Each item is pictured in its square")
	check(panels.can_drop("head",{"item_from":"bag:0"}) and not panels.can_drop("chest",{"item_from":"bag:0"}) and not panels.can_drop("head",{"item_from":"bag:2"}) and panels.can_drop("bag:7",{"item_from":"bag:0"}),"A dragged item may be put down only where it fits")
	panels.drop_on("head",{"item_from":"bag:0"})
	check(game.run.equipment.head == "bronze_helm" and game.run.bag[0] == "gladiator_helm" and panels.figure.worn.head == "bronze_helm" and game.player.visual.worn.head == "bronze_helm","Dropped on its slot it is worn: by the hero and by his figure")
	panels.drop_on("bag:8",{"item_from":"head"})
	check(game.run.equipment.head == "" and game.run.bag[8] == "bronze_helm","Dragged off into the bag it is taken off")
	panels.quick_move("bag:1")
	check(game.run.equipment.main == "greatsword" and game.run.equipment.off == "","A right click equips from the bag")
	panels.quick_move("main")
	check(game.run.equipment.main == "" and "greatsword" in game.run.bag,"and takes off what is worn")
	panels.hovered_item = "bag:%d" % game.run.bag.find("greatsword")
	game.hud.tick(0)
	check(is_instance_valid(panels.item_tip) and panels.item_tip.visible and panels.item_tip_lines.title.text == "Centurion's Greatsword" and "22–32 damage" in panels.item_tip_lines.stats.text,"Hovering an item shows what it is")
	panels.hovered_item = "bag:%d" % game.run.bag.find("deep_hood")
	game.hud.tick(0)
	check("warrior cannot wear" in panels.item_tip_lines.note.text,"and why he cannot use another class's")
	await snapshot("inventory")
	check(is_instance_valid(panels.drop_zone),"Behind the window, the ground takes what is dragged out")
	game._input(key(KEY_C))
	check(panels.stats_open() and not panels.inventory_open() and not is_instance_valid(panels.drop_zone) or panels.drop_zone.is_queued_for_deletion(),"C turns the same window to the attributes")
	game._input(key(KEY_K))
	check(panels.skills_open() and panels.nodes.size() == 19,"K to the skills")
	panels.tab_buttons.bag.pressed.emit()
	check(panels.inventory_open(),"and its tabs are clicked")
	game._input(key(KEY_I))
	check(game.mode == "playing" and not panels.any_open(),"I closes it and play resumes")
	if render: await with_the_mouse()
	check(Save.valid(game.run),"The character is save-valid throughout")
	FileAccess.open("res://test-results/items.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failed":failed},"  "))
	print("ITEMS ",passed.size()," passed; ",failed)
	game.queue_free()
	await process_frame
	quit(0 if failed.is_empty() else 1)

# In a window, with the mouse itself: an item dragged from the bag onto its
# slot, another dragged out of the window onto the ground, and its name
# clicked there to pick it up again.
func with_the_mouse():
	var panels = game.hud.panels
	hero("warrior")
	game.run.bag[0] = "bronze_helm"
	game._input(key(KEY_I))
	game.hud.tick(0)
	await frames(6)
	await drag(panels.slots["bag:0"].frame.get_global_rect().get_center(),panels.slots.head.frame.get_global_rect().get_center())
	game.hud.tick(0)
	check(game.run.equipment.head == "bronze_helm" and game.run.bag[0] == "gladiator_helm" and game.player.visual.worn.head == "bronze_helm","Dragged with the mouse from the bag onto the head slot, the helm is worn")
	await snapshot("dragged")
	await drag(panels.slots["bag:0"].frame.get_global_rect().get_center(),Vector2(240,300))
	check(game.run.bag[0] == "" and game.pickups.size() == 1 and game.pickups[0].drop.item == "gladiator_helm","Dragged out of the window, the old helm is dropped on the ground")
	game._input(key(KEY_I))
	game.world.follow(game.player.position,1)
	game.hud.tick(0)
	await frames(6)
	game.hud.tick(0)
	var names: Array = game.hud.item_labels.filter(func(b): return b.visible)
	check(names.size() == 1,"Its name shows on the ground")
	if names.size() == 1:
		var at: Vector2 = names[0].get_global_rect().get_center()
		await snapshot("dropped")
		mouse(at,true); await frames(2)
		mouse(at,false); await frames(3)
		check(game.pickups.is_empty() and "gladiator_helm" in game.run.bag,"Clicked with the mouse, it is picked up again")

func frames(count: int):
	for i in count: await process_frame

# A mouse press or release at `at` (a place in the game's own picture).
func mouse(at: Vector2, pressed: bool):
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = root.get_final_transform()*at
	event.global_position = event.position
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func drag(from: Vector2, to: Vector2):
	mouse(from,true)
	await frames(2)
	var last = from
	for i in 12:
		var at: Vector2 = from.lerp(to,(i+1)/12.0)
		var event = InputEventMouseMotion.new()
		event.position = root.get_final_transform()*at
		event.global_position = event.position
		event.relative = at-last
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		last = at
		await frames(1)
	mouse(to,false)
	await frames(3)

func key(code: int) -> InputEventKey:
	var event = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event
