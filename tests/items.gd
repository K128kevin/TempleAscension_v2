extends SceneTree
## The item system in play: the base items, the prefixes and suffixes and the
## magic items made of them, the uniques and their effects, what each class
## may wear and wield, the equipment slots and the bag, weapon damage and
## attack speed as the baseline of attacks and skills (and the wizard's own),
## armor, what enemies drop and how it is picked up, how items show on the
## hero, every class's attacks with every kind of weapon it can hold, saves,
## and the inventory itself.
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

# An item of a base, plain or with its affixes.
func it(base: String, prefix: String = "", suffix: String = "") -> Dictionary:
	return Items.make(base,prefix,suffix)

# A character of that class on the temple's first floor, every enemy but one
# put away; nothing drops unless a test says so, and no hit is a critical
# strike or is blocked. `changes`: slot to base id (or an instance; "" for
# nothing there).
# (The floor is loaded once for each class in turn, and kept while the next
# character is of the same class.)
var loaded = ""
func hero(class_id: String, changes: Dictionary = {}):
	var kept: int = game.run.seed
	game.run = Data.new_run(class_id)
	for slot in changes:
		var wanted = changes[slot]
		game.run.equipment[slot] = wanted if wanted is Dictionary else ({} if wanted.is_empty() else it(wanted))
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
	ready()
	for e in game.enemies:
		e.dead = true; e.visible = false; e.awake = false
	slain = 0

func ready():
	game.mode = "playing"
	game.player.position = origin
	game.player.busy = 0; game.player.cooldown = 0; game.player.dead = false
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

func within(span: Array, low: float, high: float, scale: float = 1.0) -> bool:
	return span[0] >= low*scale-.001 and span[1] <= high*scale+.001 and span[1]-span[0] > 1.0

func test():
	render = "--render-items" in OS.get_cmdline_user_args()
	Save.directory = ProjectSettings.globalize_path("res://test-results/items-save")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.test_mode = true
	game.set_process(false)
	game.sound.muted = true

	# --- The catalogue of base items.
	var commons = 0
	for id in Items.BASES:
		var item: Dictionary = Items.BASES[id]
		var sound = item.has("name") and item.slot in Items.ARMOR_SLOTS+["weapon","shield","key"]
		if item.slot == "key": sound = sound and not item.has("rarity")
		else: sound = sound and item.rarity in ["starting","common","unique"]
		if item.slot in Items.ARMOR_SLOTS: sound = sound and item.weight in Items.ARMOR_OF.values() and item.armor > 0
		elif item.slot == "weapon": sound = sound and item.kind in Items.KIND_TITLES and item.hands in [1,2] and ((item.has("damage") and item.damage[0] > 0 and item.damage[1] >= item.damage[0] and item.speed > 0) or item.kind == "staff")
		elif item.slot == "shield": sound = sound and item.block > 0 and item.mitigation > 0
		if item.slot in ["weapon","shield"]: sound = sound and ResourceLoader.exists("res://assets/models/props/%s.glb" % item.look.model) and item.look.has("size") and (item.slot == "shield" or item.look.has("grip"))
		if item.get("rarity","") == "unique": sound = sound and item.has("for") and (item["for"].is_empty() or item["for"] in Data.CLASSES)
		for key in item.get("bonus",{}): sound = sound and Items.BONUS_TEXT.has(key)
		check(sound,"The base item is well made: "+id)
		check(ResourceLoader.exists("res://assets/ui/items/%s.png" % id),"The item has its picture: "+id)
		var thing: Node3D = Art.laid(id)
		check(thing != null and not thing.find_children("*","MeshInstance3D",true,false).is_empty(),"The item has a model to lie on the ground: "+id)
		thing.free()
		check(Items.WIELDS.keys().any(func(c): return Items.usable(c,id)),"Some class can use the item: "+id)
		if item.get("rarity","") == "common": commons += 1
	check(commons == 27,"Twenty-seven common items drop and take affixes (%d)" % commons)
	for class_id in Data.CLASSES:
		var pool: Array = Items.loot(class_id)
		check(pool.size() >= 6 and pool.all(func(id): return Items.usable(class_id,id) and Items.BASES[id].rarity == "common"),"Every class has its own drops, all of them usable: %s (%d)" % [class_id,pool.size()])
		var own: Array = Items.loot(class_id,true)
		check(own.size() == (2 if class_id == "ranger" else 3) and own.all(func(id): return Items.BASES[id]["for"] in [class_id,""] and Items.usable(class_id,id)),"Each class has its own uniques, and the boots made for everyone: %s %s" % [class_id,own])
	check(Items.usable("warrior","marathon_boots") and Items.usable("ranger","marathon_boots") and Items.usable("wizard","marathon_boots") and not Items.usable("warrior","sandals"),"The Marathon Boots are light armor every class can wear; other light armor is the wizard's")

	# --- Prefixes and suffixes: what goes on what.
	for table in [Items.PREFIXES,Items.SUFFIXES,Items.RARE_PREFIXES,Items.RARE_SUFFIXES]:
		for id in table:
			var affix: Dictionary = table[id]
			check(affix.has("name") and affix.on.all(func(c): return c in Items.ON_ALL) and (affix.has("bonus") or affix.has("armor") or affix.has("damage") or affix.has("speed") or affix.has("spiked")),"The affix is well made: "+id)
	check(Items.takes("silk_robe",Items.prefix("fine")) and not Items.takes("steel_breastplate",Items.prefix("fine")) and Items.takes("bandit_blade",Items.prefix("fine")) and Items.takes("twisted_silver_staff",Items.prefix("fine")) == false,"Fine goes on light armor, daggers and staves that drop (not the starting staff)")
	check(Items.takes("lions_buckler",Items.prefix("spiked")) == false and Items.takes("tower_shield",Items.prefix("spiked")) and not Items.takes("steel_longsword",Items.prefix("spiked")),"Spiked goes on shields that drop")
	check(Items.takes("leather_tunic",Items.prefix("thiefs")) and Items.takes("steel_shortsword",Items.prefix("thiefs")) and not Items.takes("steel_breastplate",Items.prefix("thiefs")) and not Items.takes("silk_robe",Items.prefix("thiefs")),"Thief's goes on medium armor, daggers and swords")
	check(Items.takes("longbow",Items.prefix("lightweight")) and not Items.takes("war_hammer",Items.prefix("lightweight")) and Items.takes("war_hammer",Items.prefix("heavy")) and not Items.takes("greatsword",Items.prefix("heavy")) and Items.takes("greatsword",Items.prefix("sharpened")),"Lightweight for daggers, swords and bows; Heavy for maces, Sharpened for blades")
	check(not Items.takes("longbow",Items.suffix("zeus")) and Items.takes("greatsword",Items.suffix("zeus")) and Items.takes("tower_shield",Items.suffix("hades")) and not Items.takes("bow_of_odysseus",Items.suffix("ancients")),"Of Zeus is for melee weapons and hard armor, not bows; nothing goes on a unique")
	for id in Items.BASES:
		if Items.BASES[id].get("rarity","") != "common": continue
		check(not Items.prefixes_for(id).is_empty() and not Items.suffixes_for(id).is_empty() and not Items.suffixes_for(id,true).is_empty(),"Every common item can take a prefix, a suffix and a rare suffix: "+id)

	# --- Instances: what an item is with its affixes.
	var sword: Dictionary = Items.get_item(it("steel_longsword","swift","zeus"))
	check(Items.name_of(it("steel_longsword","swift","zeus")) == "Swift Steel Longsword of Zeus" and Items.name_of(it("silk_robe","enchanted")) == "Enchanted Silk Robe" and Items.name_of(it("tower_shield","","ancients")) == "Tower Shield of the Ancients","An item is named by its prefix and suffix")
	check(not Items.valid_instance(it("steel_longsword","swift","zeus")) and Items.valid_instance(it("steel_longsword","sharpened","zeus")),"Swift is not for swords; Sharpened is")
	sword = Items.get_item(it("steel_longsword","sharpened","zeus"))
	check(sword.damage == [24.0,33.6] and sword.bonus == {"strength":3,"dexterity":2} and sword.rarity == "rare" and sword.speed == 1.1 and sword.affixes.size() == 1,"A Sharpened Steel Longsword of Zeus: 20%% more damage, Zeus's attributes, rare (%s)" % [sword])
	check(Items.rarity(it("steel_longsword")) == "common" and Items.rarity(it("steel_longsword","lightweight")) == "uncommon" and Items.rarity(it("steel_longsword","","zeus")) == "uncommon" and Items.rarity(it("steel_longsword","heros")) == "rare" and Items.rarity(it("steel_longsword","","hades")) == "rare" and Items.rarity(it("bow_of_odysseus")) == "unique" and Items.rarity(it("simple_shortsword")) == "common","Rarity: none, one, both, a rare affix, a unique")
	check(not Items.valid_instance(it("steel_longsword","heros","zeus")) and not Items.valid_instance(it("steel_longsword","sharpened","hades")) and not Items.valid_instance(it("bow_of_odysseus","tough")) and not Items.valid_instance(it("simple_shortsword","tough")) and not Items.valid_instance({"base":"steel_longsword","extra":1}) and not Items.valid_instance("steel_longsword"),"A rare affix stands alone; nothing goes on a unique or the starting gear")
	check(is_equal_approx(Items.get_item(it("steel_longsword","lightweight")).speed,1.3) and Items.get_item(it("steel_breastplate","durable")).armor == 21.0*1.2 and Items.get_item(it("war_hammer","heavy")).damage == [42.0,54.0],"Lightweight +0.2 attacks a second; Durable +20% armor; Heavy +20% damage")
	var shield: Dictionary = Items.get_item(it("tower_shield","spiked"))
	check(shield.spiked == 10.0 and Items.get_item(it("tower_shield","durable")).armor == 25.0*1.2 and Items.get_item(it("tower_shield","durable")).mitigation == 28.0 and Items.get_item(it("lions_buckler")).get("spiked",0.0) == 0.0,"A Spiked shield gives a tenth back; a Durable one has a fifth more armor, its block its own")
	check(Items.get_item(it("silk_robe","starry","ancients")).is_empty() == false and Items.get_item(it("silk_robe","starry")).bonus == {"intelligence":9,"vitality":6,"willpower":6},"Affix attributes add to the item's own (Starry Silk Robe: %s)" % [Items.get_item(it("silk_robe","starry")).bonus])
	check(Items.get_item(it("nothing_here")).is_empty() and Items.get_item({}).is_empty() and Items.get_item("").is_empty(),"What is no item resolves to nothing")
	var about: Dictionary = Items.describe(it("steel_longsword","sharpened","zeus"),"ranger")
	check(about.title == "Sharpened Steel Longsword of Zeus" and about.rarity == "rare" and "24–33.6 damage" in about.stats and "1.1 attacks per second" in about.stats and "+3 Strength" in about.stats and "Sharpened: +20% damage" in about.stats and about.note.is_empty(),"Its tip tells all of it: %s" % [about.stats])
	about = Items.describe(it("robe_of_the_lost_emperor"),"wizard")
	check("mana" in about.effect and not "energy" in about.effect and "energy" in Items.describe(it("robe_of_the_lost_emperor"),"warrior").effect,"A unique's effect is told, in the hero's own words")
	about = Items.describe(it("marathon_boots"),"warrior")
	check("+20% movement speed" in about.stats and "+6 Strength" in about.stats and about.note.is_empty(),"The Marathon Boots: their speed and all six attributes (%s)" % [about.stats])

	# --- Magic items made at random.
	var rng = RandomNumberGenerator.new()
	rng.seed = 20261010
	var fine = true
	var uncommon_sides = {"prefix":0,"suffix":0}
	var rare_kinds = {"both":0,"prefix":0,"suffix":0}
	for i in 600:
		var base: String = Items.pick(rng,Items.loot(Data.CLASSES[i%3]))
		var u: Dictionary = Items.enchant(base,"uncommon",rng)
		var r: Dictionary = Items.enchant(base,"rare",rng)
		fine = fine and Items.valid_instance(u) and Items.rarity(u) == "uncommon" and Items.valid_instance(r) and Items.rarity(r) == "rare" and u.base == base and r.base == base
		uncommon_sides["prefix" if u.has("prefix") else "suffix"] += 1
		rare_kinds["both" if r.has("prefix") and r.has("suffix") else ("prefix" if r.has("prefix") else "suffix")] += 1
	check(fine and uncommon_sides.prefix > 150 and uncommon_sides.suffix > 150 and rare_kinds.both > 150 and rare_kinds.prefix > 40 and rare_kinds.suffix > 40,"Uncommon items take a prefix or a suffix, rare ones both or one rare affix, all well made (%s %s)" % [uncommon_sides,rare_kinds])
	for class_id in Data.CLASSES:
		var all_usable = true
		for i in 200:
			var made: Dictionary = Items.generate(class_id,Items.RARITIES[i%4],rng)
			all_usable = all_usable and Items.valid_instance(made) and Items.usable(class_id,made) and (Items.rarity(made) == Items.RARITIES[i%4])
		check(all_usable,"Whatever is made for a %s, of any rarity, he can use" % class_id)
	var counts = {"common":0,"uncommon":0,"rare":0,"unique":0}
	var fell = 0
	var uniques_seen = {}
	for i in 40000:
		var found: Dictionary = Items.roll_drop("warrior","gladiator",rng)
		if found.is_empty(): continue
		fell += 1
		counts[Items.rarity(found)] += 1
		if Items.rarity(found) == "unique": uniques_seen[found.base] = true
	check(absf(fell/40000.0-Items.DROP_CHANCE.gladiator*.01) < .006,"A gladiator drops something about one time in nine (%.3f)" % (fell/40000.0))
	var total_weight = 0.0
	for r in Items.RARITY_WEIGHTS: total_weight += Items.RARITY_WEIGHTS[r]
	var shares_fair = true
	for r in counts: shares_fair = shares_fair and absf(counts[r]/float(fell)-Items.RARITY_WEIGHTS[r]/total_weight) < .02
	check(shares_fair and uniques_seen.keys().all(func(id): return id in ["ancient_gladiators_helmet","lightning_hammer","marathon_boots"]) and uniques_seen.size() == 3,"Each rarity by its weight, and a warrior's uniques are his helmet, his hammer and the boots for everyone (%s, %s)" % [counts,uniques_seen.keys()])
	var boss_rare = true
	for i in 200:
		var found: Dictionary = Items.roll_drop("wizard","boss",rng)
		boss_rare = boss_rare and not found.is_empty() and Items.rarity(found) in ["rare","unique"] and Items.usable("wizard",found)
	check(boss_rare,"The Crowned Statue always drops, rare or unique")
	var bandit_rng = RandomNumberGenerator.new(); bandit_rng.seed = 1
	var bandit_fell = 0
	for i in 2000:
		if not Items.roll_drop("ranger","bandit",bandit_rng).is_empty(): bandit_fell += 1
	check(bandit_fell > 100 and bandit_fell < 280,"A bandit seldom drops at all (%d in 2000)" % bandit_fell)

	# --- What each class starts with, and may use.
	var totals: Dictionary = {}
	for class_id in Data.CLASSES:
		var run = Data.new_run(class_id)
		var whole = true
		for slot in Items.ARMOR_SLOTS:
			whole = whole and Items.worn(run,slot).get("weight","") == Items.ARMOR_OF[class_id] and Items.worn(run,slot).slot == slot and Items.rarity(run.equipment[slot]) == "common"
		check(whole and run.bag.size() == Items.BAG_SIZE and Save.valid(run),"A new %s wears his class's starting armor (white), and has a bag of ten places" % class_id)
		totals[class_id] = Data.armor_points(run)
	check(totals.warrior == 108.0 and totals.ranger == 58.0 and totals.wizard == 31.0 and Data.new_run("ranger").equipment.head == it("leather_hood") and Items.BASES.lions_buckler.armor == 17.0 and Items.BASES.lions_buckler.mitigation == 30.0,"Heavy armor adds up to more than medium, and medium than light (%s); the ranger starts in a leather hood, the buckler's armor counts" % totals)
	check(is_equal_approx(Items.reduction_of(91.0),100.0*91.0/(91.0+Items.ARMOR_SCALE)) and Items.reduction_of(0.0) == 0.0 and Items.reduction_of(100000.0) == Items.ARMOR_CAP,"Armor takes armor/(armor+%d) off a blow, to %d%% at most" % [int(Items.ARMOR_SCALE),int(Items.ARMOR_CAP)])
	check(Items.main(Data.new_run("warrior")).kind == "sword" and Items.main(Data.new_run("warrior")).name == "Simple Shortsword" and Items.shield(Data.new_run("warrior")).name == "Lion's Buckler","The warrior starts with a shortsword and a buckler")
	check(Items.main(Data.new_run("ranger")).name == "Ranger's Bow" and it("rangers_dagger") in Data.new_run("ranger").bag,"The ranger with his bow, his dagger in his bag")
	check(Items.main(Data.new_run("wizard")).kind == "staff" and Data.stat(Data.new_run("wizard"),2) == 9,"The wizard with his staff, and its Intelligence")
	var may = {"warrior":["sword","shield","mace","axe","bow"],"ranger":["bow","dagger","sword"],"wizard":["staff","dagger"]}
	for class_id in may:
		for kind in Items.PLAIN:
			check(Items.usable(class_id,Items.PLAIN[kind]) == (kind in may[class_id]),"%s %s a %s" % [class_id,"can use" if kind in may[class_id] else "cannot use",kind])
		for other in Data.CLASSES:
			check(Items.usable(class_id,Items.STARTING[other].equipment.chest) == (other == class_id),"%s armor is the %s's alone (%s)" % [Items.ARMOR_OF[other],other,class_id])

	# --- The slots and the bag.
	var w = Data.new_run("warrior")
	check(Items.misfit(w,it("gladiators_helmet"),"chest") != "" and Items.misfit(w,it("lions_buckler"),"main") != "" and Items.misfit(w,it("greatsword"),"off") != "" and Items.misfit(w,it("wool_hood"),"head") != "" and Items.misfit(w,it("twisted_silver_staff"),"main") != "" and Items.misfit(w,it("marathon_boots"),"feet") == "","Things go only where they fit, on one who can use them")
	Items.stow(w,it("greatsword")); Items.stow(w,it("war_hammer")); Items.stow(w,it("hatchet"))
	check(Items.move(w,"bag:0","main") == "" and w.equipment.main == it("greatsword") and w.equipment.off.is_empty() and it("simple_shortsword") in w.bag and it("lions_buckler") in w.bag,"A two-handed weapon taken up empties both hands into the bag")
	check(Items.move(w,"bag:%d" % w.bag.find(it("lions_buckler")),"off") == "" and w.equipment.off == it("lions_buckler") and w.equipment.main.is_empty() and it("greatsword") in w.bag,"A shield taken up sends a two-handed weapon back to it")
	check(Items.move(w,"bag:%d" % w.bag.find(it("simple_shortsword")),"main") == "" and Items.move(w,"bag:%d" % w.bag.find(it("hatchet")),"off") == "" and w.equipment.main == it("simple_shortsword") and w.equipment.off == it("hatchet") and it("lions_buckler") in w.bag,"Two one-handed weapons, one in each hand")
	check(Items.damage_span(w) == [17.0+16.0*.5,25.0+24.0*.5] and Items.attack_speed(w) == 1.3,"The off hand's weapon adds half its damage; the main hand sets the pace: %s" % [Items.damage_span(w)])
	check(Items.move(w,"main","off") == "" and w.equipment.main == it("hatchet") and w.equipment.off == it("simple_shortsword") and Items.attack_speed(w) == 1.6,"The two hands' weapons change places")
	check(Items.move(w,"head","bag:%d" % Items.free_bag_slot(w)) == "" and w.equipment.head.is_empty() and it("gladiators_helmet") in w.bag and Data.armor_points(w) == 76.0,"Armor taken off goes into the bag, and protects no longer")
	check(Items.slot_for(w,it("gladiators_helmet")) == "head" and Items.slot_for(w,it("lions_buckler")) == "off" and Items.slot_for(w,it("greatsword")) == "main" and Items.slot_for(w,it("gate_key")) == "","A right click knows where a thing goes")
	check(Items.move(w,"bag:%d" % w.bag.find(it("gladiators_helmet")),"bag:9") == "" and w.bag[9] == it("gladiators_helmet"),"Things are moved about the bag")
	check(Save.valid(w),"A character is save-valid however it is equipped")
	var full = Data.new_run("warrior")
	for i in Items.BAG_SIZE: full.bag[i] = it("steel_shortsword","lightweight")
	check(not Items.stow(full,it("greatsword")) and Items.move(full,"head","bag:0") != "" and full.equipment.head == it("gladiators_helmet") and Items.free_places(full) == 0,"A full bag takes nothing more")
	full.bag[3] = it("greatsword")
	check(Items.move(full,"bag:3","main") != "" and full.equipment.main == it("simple_shortsword") and full.equipment.off == it("lions_buckler"),"With no room for the shield, a two-handed weapon cannot be taken up")
	var bad = Data.new_run("wizard"); bad.equipment.main = it("simple_shortsword")
	check(not Save.valid(bad),"A save in which a wizard holds a sword is refused")
	bad = Data.new_run("warrior"); bad.equipment.main = it("greatsword")
	check(not Save.valid(bad),"So is a two-handed weapon beside a shield")
	bad = Data.new_run("warrior"); bad.bag[0] = it("steel_longsword","swift")
	check(not Save.valid(bad),"And an affix on an item it cannot go on")
	bad = Data.new_run("warrior"); bad.bag[0] = "steel_longsword"
	check(not Save.valid(bad),"And an item that is only a name")

	# --- Weapon damage and speed are the baseline of the normal attack and of every skill.
	hero("warrior")
	var victim = foe()
	var dealt: Array = blows(victim,24)
	check(within(dealt,17.0,25.0),"The Simple Shortsword hits for 17 to 25 (%.1f to %.1f)" % dealt)
	check(is_equal_approx(game.attack_profile().duration,1.0/1.3) and is_equal_approx(Data.attack_seconds(game.run),1.0/1.3),"and swings 1.3 times a second (%.3f s)" % game.attack_profile().duration)
	game.run.bag[0] = it("steel_shortsword","lightweight")
	check(game.move_item("bag:0","main") == "" and is_equal_approx(game.attack_profile().duration,1.0/1.7),"A Lightweight Steel Shortsword: 1.7 times a second (%.3f s)" % game.attack_profile().duration)
	game.run.bag[0] = it("greatsword")
	check(game.move_item("bag:0","main") == "" and game.player.visual.weapon_kind == "heavy" and not is_instance_valid(game.player.visual.shield_item),"A greatsword from the bag is in both his hands, his shield put away")
	check(Data.span(game.run,"melee") == [30.0,42.0] and is_equal_approx(game.attack_profile().duration,1.0/1.2),"Its damage is the baseline, and its speed the pace")
	ready(); victim = foe(1.6)
	dealt = blows(victim,24)
	check(within(dealt,30.0,42.0),"The greatsword hits for 30 to 42 (%.1f to %.1f)" % dealt)
	game.run.skills = {"powerful_strike":1}
	var least = INF; var most = 0.0
	for i in 16:
		ready(); victim = foe(1.6)
		check(game.skills.cast("powerful_strike",victim.position),"Powerful Strike is cast with the greatsword") if i == 0 else game.skills.cast("powerful_strike",victim.position)
		play(1.4)
		least = minf(least,victim.max_hp-victim.hp); most = maxf(most,victim.max_hp-victim.hp)
	check(least >= 60.0-.001 and most <= 84.0+.001,"A skill deals its percent of the weapon's damage: Powerful Strike 200%% of 30 to 42 (%.1f to %.1f)" % [least,most])
	check("60–84" in game.skills.damage_summary("powerful_strike",1).damage,"The skill's tip shows what it hits for with this weapon: "+game.skills.damage_summary("powerful_strike",1).damage)
	game.run.skills = {"shield_bash":1,"cleave":1}
	check(game.skills.reason("shield_bash") == "Requires a shield." and game.skills.reason("cleave") == "","With both hands on a greatsword there is no shield to bash with; Cleave is his")
	# A Sharpened sword hits a fifth harder, and Strength on top.
	hero("warrior",{"main":it("steel_longsword","sharpened","zeus")})
	check(Data.stat(game.run,0) == 8 and Data.span(game.run,"melee") == [24.0,33.6],"A Sharpened Steel Longsword of Zeus: 24 to 33.6 and its Strength")
	victim = foe()
	dealt = blows(victim,16)
	check(within(dealt,24.0,33.6,1.06),"and it hits so, raised by Strength (%.1f to %.1f)" % dealt)

	# The ranger's bow and blade, each its own.
	hero("ranger",{"main":"hunters_bow"})
	check(Data.span(game.run,"ranged") == [15.0,23.0] and Data.span(game.run,"melee") == [12.0,20.0] and Data.stat(game.run,1) == 6,"A bow's damage is the bow's skills' baseline, the dagger in the bag the dagger's; the Hunter's Bow adds Dexterity")
	check(is_equal_approx(game.attack_profile().duration,(1.0/1.5)/(1.0+Data.HASTE_PER_DEXTERITY*.01)),"It shoots 1.5 times a second, a point of Dexterity quicker (%.3f s)" % game.attack_profile().duration)
	victim = foe(6.0)
	dealt = blows(victim,16)
	check(within(dealt,15.0,23.0,1.02),"The Hunter's Bow shoots for 15 to 23, raised by its Dexterity (%.1f to %.1f)" % dealt)

	# The wizard: a set baseline worked from Intelligence; his staff adds to it.
	hero("wizard")
	check(Data.span(game.run,"spell") == Data.SPELL_SPAN and is_equal_approx(Data.damage_tag(game.run,"spell",100.0),108.0),"A wizard's spells have their own baseline, which the Twisted Silver Staff's Intelligence raises by 8%")
	game.run.stats[2] = 15
	check(is_equal_approx(Data.damage_tag(game.run,"spell",100.0),128.0),"Intelligence raises it 2% a point")
	game.run.stats[2] = 5
	game.run.skills = {"fireball":1}
	var with_staff: String = game.skills.damage_summary("fireball",1).damage
	game.run.bag[0] = it("silk_robe","enchanted")
	check(game.move_item("bag:0","chest") == "" and Data.stat(game.run,2) == 5+4+3+10 and is_equal_approx(Data.damage_tag(game.run,"spell",100.0),134.0),"An Enchanted Silk Robe: +13 Intelligence in all")
	check(game.skills.damage_summary("fireball",1).damage != with_staff,"and a spell's tip shows it (%s, was %s)" % [game.skills.damage_summary("fireball",1).damage,with_staff])
	game.run.bag[1] = it("bandit_blade")
	check(game.move_item("bag:1","main") == "" and game.player.visual.weapon_kind == "dagger" and is_equal_approx(Data.damage_tag(game.run,"spell",100.0),126.0),"With a dagger in hand, his staff's Intelligence is gone")
	ready(); victim = foe(6.0)
	check(game.skills.reason("fireball") == "" and game.skills.cast("fireball",victim.position),"and Fireball can still be cast")
	play(2.0)
	check(victim.hp < victim.max_hp,"Fireball burns what it reaches")

	# --- Armor, and what else equipment gives.
	for class_id in Data.CLASSES:
		hero(class_id)
		var cut: float = Items.reduction_of(totals[class_id])
		game.hurt_player(50.0)
		check(is_equal_approx(game.player.max_hp-game.player.hp,50.0*(1.0-cut*.01)),"The %s's %d armor takes %.1f%% off a blow" % [class_id,int(totals[class_id]),cut])
		ready()
		game.hurt_player(50.0,"frost")
		check(is_equal_approx(game.player.max_hp-game.player.hp,50.0*(1.0-cut*.01)),"whatever its kind: "+class_id)
	hero("warrior")
	game.run.bag[0] = it("steel_full_helm","tough"); game.run.bag[1] = it("steel_breastplate","durable")
	check(game.move_item("bag:0","head") == "" and game.move_item("bag:1","chest") == "" and Data.armor_points(game.run) == 108.0-15.0-23.0+20.0+21.0*1.2 and Data.stat(game.run,3) == 10 and Data.stat(game.run,0) == 7 and game.player.max_hp == 150.0,"Better armor: more protection, and its Vitality and Strength")
	check(game.run.bag[0] == it("gladiators_helmet") and game.run.bag[1] == it("scale_cuirass"),"What it replaces goes where it came from")
	# The attributes tab shows each in all, and how much of it the items give.
	game.hud.panels.open_stats(); game.hud.panels.refresh()
	var gear: int = Data.stat(game.run,3)-int(game.run.stats[3])
	check(gear == 5 and game.hud.panels.stat_values[3].text == str(Data.stat(game.run,3)) and game.hud.panels.stat_splits[3].visible and game.hud.panels.stat_splits[3].text == "%d base · +%d items" % [game.run.stats[3],gear],"The attributes tab shows Vitality in all, its base and what items add (%s, %s)" % [game.hud.panels.stat_values[3].text,game.hud.panels.stat_splits[3].text])
	check(game.hud.panels.stat_values[1].text == str(game.run.stats[1]) and not game.hud.panels.stat_splits[1].visible,"An attribute no item raises shows only its value")
	check("Armor %s" % Items.figure(Data.armor_points(game.run)) in game.hud.panels.stat_summary.text and "attacks/s" in game.hud.panels.stat_summary.text,"It shows his armor and his attacks a second: "+game.hud.panels.stat_summary.text.replace("\n"," · "))
	game.hud.panels.close()
	check(game.move_item("chest","bag:5") == "" and game.player.max_hp == 150.0 and Data.stat(game.run,0) == 5,"Taken off, its Strength goes with it")
	game.run.bag[7] = it("tower_shield","durable")
	var unshielded: float = Data.armor_points(game.run)
	game.move_item("bag:7","off")
	check(Data.block_chance(game.run) == 28.0 and Data.block_mitigation(game.run) == 28.0 and is_equal_approx(Data.armor_points(game.run),unshielded-17.0+25.0*1.2),"A shield's block is its own; its armor counts with what is worn, a Durable one's a fifth more")
	# A spiked shield gives a tenth of a blocked blow back.
	game.run.bag[8] = it("tower_shield","spiked"); game.move_item("bag:8","off")
	victim = foe(1.5)
	game.skills.block_override = 1
	var hp: float = victim.hp
	var left: float = game.skills.defend(50.0,victim)
	check(is_equal_approx(left,50.0*.72) and is_equal_approx(hp-victim.hp,5.0),"A Spiked Tower Shield: the blow blocked, and a tenth of it dealt back (%.1f left, %.1f back)" % [left,hp-victim.hp])
	game.skills.block_override = 0
	hero("ranger")
	var pace: float = game.player_pace()
	game.run.bag[1] = it("marathon_boots"); game.move_item("bag:1","feet")
	check(is_equal_approx(game.player_pace(),pace*1.2) and Data.stat(game.run,0) == 11 and Data.stat(game.run,4) == 11,"The Marathon Boots quicken his step by a fifth, and add six to everything")

	# --- The uniques' own effects.
	hero("wizard",{"chest":"robe_of_the_lost_emperor"})
	check(Items.effect(game.run,"emperor") and Data.stat(game.run,2) == 5+4+12,"The Robe of the Lost Emperor is worn, with its Intelligence")
	victim = foe(3.0)
	game.run.energy = 0.0
	var restored = 0
	for i in 300:
		var before: float = game.run.energy
		game.skills.spell_hit(victim,10.0,"fire")
		if game.run.energy > before: restored += 1
		game.run.energy = 0.0
	check(restored > 10 and restored < 60,"One spell's hit in ten gives 20 mana back (%d of 300)" % restored)
	hero("warrior",{"head":"ancient_gladiators_helmet"})
	check(Items.effect(game.run,"rallying_cry") and Data.stat(game.run,0) == 20 and Data.stat(game.run,1) == 17,"The Ancient Gladiator's Helmet is worn, with its Strength and Dexterity")
	victim = foe(1.5)
	var plain_time: float = game.attack_profile().duration
	var rallied = false
	for i in 200:
		game.skills.strike(victim,10.0)
		if game.skills.rally_time > 0: rallied = true; break
	check(rallied and game.skills.rally_cooldown > 0 and game.skills.effects().any(func(e): return e.id == "rallying_cry") and is_equal_approx(game.skills.haste(),1.25) and is_equal_approx(game.attack_profile().duration,plain_time/1.25),"A blow raises Rallying Cry: a quarter faster, shown on the buff bar")
	hp = victim.hp
	game.skills.strike(victim,10.0)
	check(is_equal_approx(hp-victim.hp,12.5),"and a quarter more damage (%.1f)" % (hp-victim.hp))
	game.skills.rally_time = 0.0
	var again = false
	for i in 200:
		game.skills.strike(victim,10.0)
		if game.skills.rally_time > 0: again = true; break
	check(not again and game.skills.rally_cooldown > 0,"Not again until thirty seconds have passed")
	game.skills.rally_cooldown = 0.0
	hero("ranger",{"main":"bow_of_odysseus"})
	check(Items.effect(game.run,"stunning_arrows") and Data.span(game.run,"ranged") == [43.0,55.0] and Data.stat(game.run,1) == 20,"The Bow of Odysseus: 43 to 55, and its Dexterity")
	victim = foe(5.0)
	var stunned = 0
	for i in 200:
		victim.end_stun(); victim.stun_memory = 0.0; victim.stun_count = 0
		game.skills.arrow_hit(victim,{"damage":1.0,"direction":Vector3.FORWARD,"skill":false})
		if victim.stunned: stunned += 1
	check(stunned > 25 and stunned < 80,"One arrow in four stuns (%d of 200)" % stunned)
	victim.end_stun()
	hero("warrior",{"main":"lightning_hammer","off":""})
	check(Items.effect(game.run,"lightning_hammer") and Data.span(game.run,"melee") == [60.0,76.0] and Data.stat(game.run,0) == 20 and Data.stat(game.run,3) == 17 and game.player.visual.weapon_kind == "heavy","The Lightning Hammer: 60 to 76 in both hands, with its Strength and Vitality")
	victim = foe(1.5)
	# (Two more within a leap of each other, and one far beyond any.)
	var others: Array = []
	for ahead in [4.0,8.0,30.0]:
		var e = game.spawn_enemy("gladiator","hammer:%d" % others.size(),game.world.move(origin,Vector3(0,0,-ahead)))
		e.puppet = true; e.awake = true; e.max_hp = 100000.0; e.hp = e.max_hp
		others.append(e)
	# (The far one may stand nearer than asked, where the floor's walls stop
	# it: it is spared only if it is truly beyond a leap.)
	var beyond: bool = others[2].position.distance_to(others[1].position) > game.skills.LIGHTNING_LEAP+.5
	var bolts = 0; var leapt = 0; var spared = true
	for i in 300:
		var before: Array = [victim.hp,others[0].hp,others[1].hp]
		game.skills.strike(victim,10.0)
		if before[0]-victim.hp > 100.0:
			bolts += 1
			if others[0].hp < before[1] and others[1].hp < before[2]: leapt += 1
			spared = spared and (others[2].hp == others[2].max_hp or not beyond)
		game.skills.tick(.1)
	check(bolts > 10 and bolts < 60 and leapt == bolts and spared,"One hit in ten calls lightning on the target, leaping to those near, not the far (%d of 300, %d leapt, far one %.1f m off)" % [bolts,leapt,others[2].position.distance_to(others[1].position)])
	for e in others:
		game.enemies.erase(e); e.queue_free()
	hero("wizard",{"hands":"ice_queens_gloves"})
	check(Items.effect(game.run,"ice_queen") and Data.stat(game.run,2) == 5+4+15 and is_equal_approx(Items.bonus(game.run,"spell_damage"),25.0),"The Ice Queen's Gloves are worn: Intelligence and a quarter more spell damage")
	victim = foe(3.0)
	hp = victim.hp
	game.skills.spell_hit(victim,100.0,"fire")
	check(hp-victim.hp > 0.0 and is_equal_approx(Data.damage_tag(game.run,"spell",100.0),100.0*(1.0+(Data.stat(game.run,2)-5)*.02)*1.25),"A spell deals a quarter more (%.1f)" % (hp-victim.hp))
	game.run.skills["ice_bolt"] = 1; game.run.skills["fireball"] = 1
	check("Ice Queen" in game.skills.reason("ice_bolt") and game.skills.reason("fireball") == "","and no frost spell may be cast, fire still may")
	game.move_item("hands","bag:%d" % Items.free_bag_slot(game.run))
	check(game.skills.reason("ice_bolt") == "","Gloves off, frost again")

	# --- Every class's attacks with every kind of weapon it can hold.
	var seen = {}
	for class_id in Data.CLASSES:
		for id in Items.BASES:
			var item: Dictionary = Items.BASES[id]
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
	hero("warrior",{"main":"hatchet"})
	var haft_low = Vector3(INF,INF,INF); var haft_high = -haft_low
	var bit = Vector3.ZERO
	var axe: Node3D = game.player.visual.weapon_item
	for mesh in axe.find_children("*","MeshInstance3D",true,false):
		var inside: Transform3D = axe.global_transform.affine_inverse()*mesh.global_transform
		for surface in mesh.mesh.get_surface_count():
			for v in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var p: Vector3 = Basis.from_scale(axe.scale)*(inside*v)
				if p.y < .25: haft_low = haft_low.min(p); haft_high = haft_high.max(p)
				elif p.y > .58 and Vector2(p.x,p.z).length() > Vector2(bit.x,bit.z).length(): bit = p
	check(absf(haft_low.x+haft_high.x) < .02 and absf(haft_low.z+haft_high.z) < .02 and haft_high.x-haft_low.x < .1 and haft_high.z-haft_low.z < .1,"The hatchet's haft runs through his fist (%s to %s)" % [haft_low,haft_high])
	check(bit.z < -.2 and absf(bit.x) < absf(bit.z),"Its bit is turned to lead the cut (%s)" % bit)
	# The war hammer's haft too, its head's face out along its edge.
	hero("warrior",{"main":"war_hammer","off":""})
	var hammer: Node3D = game.player.visual.weapon_item
	haft_low = Vector3(INF,INF,INF); haft_high = -haft_low
	var head_low = Vector3(INF,INF,INF); var head_high = -head_low
	for mesh in hammer.find_children("*","MeshInstance3D",true,false):
		var inside: Transform3D = hammer.global_transform.affine_inverse()*mesh.global_transform
		for surface in mesh.mesh.get_surface_count():
			for v in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var p: Vector3 = Basis.from_scale(hammer.scale)*(inside*v)
				if p.y < .6: haft_low = haft_low.min(p); haft_high = haft_high.max(p)
				elif p.y > 1.12: head_low = head_low.min(p); head_high = head_high.max(p)
	check(absf(haft_low.x+haft_high.x) < .02 and absf(haft_low.z+haft_high.z) < .02 and head_high.x > .1 and head_low.x < -.15 and absf(head_high.z) < .08,"The war hammer's haft runs through his fist, its head across his X (%s to %s)" % [head_low,head_high])
	check(game.player.visual.idle_action() == "HeavyIdle" and is_equal_approx(game.attack_profile().duration,1.0/.9),"It is swung as a heavy weapon, nine times in ten seconds")
	# The warrior's skills with each family of melee weapon.
	for id in ["simple_shortsword","hatchet","greatsword","war_hammer"]:
		var swung: String = Items.family(Items.BASES[id])
		for skill in Book.all().values():
			if skill.class_id != "warrior" or skill.effect == "passive": continue
			hero("warrior",{"main":id,"off":"lions_buckler" if swung == "one" else ""})
			game.run.skills = {skill.id:1}
			victim = foe(1.5,1000.0 if skill.effect == "execute" else 100000.0)
			if skill.effect == "execute": victim.max_hp = 100000.0
			if skill.requirement == "shield" and swung != "one":
				check(game.skills.reason(skill.id) == "Requires a shield.","%s needs a shield: %s" % [skill.title,id])
				continue
			check(game.skills.cast(skill.id,victim.position),"%s is cast with %s" % [skill.title,Items.BASES[id].name])
			var wanted: String = Motion.skill_clip(swung,skill.effect)
			var state: String = game.player.visual.state
			if skill.effect in ["vampiric","shadow"]: check(game.player.visual.clips.has(state) and (state in Motion.family(swung).clips or state.begins_with("Sword")),"%s is struck with the weapon's own swing: %s / %s" % [skill.title,id,state])
			else: check(state == wanted and game.player.visual.clips.has(wanted),"%s has its own motion with %s: %s (playing %s)" % [skill.title,Items.BASES[id].name,wanted,state])
			hp = victim.hp
			play(2.0)
			if skill.effect == "cry": check(victim.rally_time > 0,"War Cry cows: "+id)
			else: check(victim.hp < hp,"%s lands with %s" % [skill.title,Items.BASES[id].name])
	# A weapon in each hand strikes with each by turns.
	hero("warrior",{"main":"simple_shortsword","off":"steel_shortsword"})
	check(is_instance_valid(game.player.visual.off_item) and not is_instance_valid(game.player.visual.shield_item) and game.player.visual.idle_action() == "DualIdle","A second sword is held in the left hand")
	victim = foe(1.5)
	var hands: Array = []
	for i in 4:
		game.player.busy = 0; game.player.cooldown = 0
		var before: float = victim.hp
		game.attack(false,victim.position)
		hands.append(game.player.visual.state)
		play(1.4)
		check(before-victim.hp >= 17.0+16.0*.5-.001 and before-victim.hp <= 25.0+22.0*.5+.001,"Each blow has both weapons' damage in it (%.1f)" % (before-victim.hp))
	check(hands == ["SwordOpen","OffCut","SwordOpen","OffCut"],"The right hand's cut and the left's by turns: %s" % [hands])
	hero("ranger",{"main":"rangers_dagger","off":"bandit_blade"})
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
	check(Data.weapon(game.run) == Data.UNARMED and dealt[0] >= 1.0-.001 and dealt[1] <= 3.0+.001 and game.player.visual.weapon_kind == "" and is_equal_approx(Data.attack_seconds(game.run),.5),"Bare hands do little, twice a second (%.1f to %.1f)" % dealt)
	# X changes weapons. The warrior's skills need a melee weapon in hand:
	# with a bow he has only his normal attack, a shot.
	hero("warrior")
	game.run.bag[0] = it("rangers_bow")
	game.swap_weapon()
	check(game.run.equipment.main == it("rangers_bow") and game.run.equipment.off.is_empty() and it("simple_shortsword") in game.run.bag and it("lions_buckler") in game.run.bag and game.player.visual.weapon_kind == "bow","X: the warrior takes up the bow from his bag, sword and shield put away")
	game.run.skills = {}
	for s in Book.all().values():
		if s.class_id == "warrior" and s.effect != "passive": game.run.skills[s.id] = 1
	victim = foe(5.0)
	var refused = true
	for id in game.run.skills:
		refused = refused and game.skills.reason(id) == ("Requires a shield." if Book.all()[id].requirement == "shield" else "Requires a melee weapon.") and not game.skills.cast(id,victim.position)
	check(refused and game.run.skills.size() == 11 and game.run.equipment.main == it("rangers_bow") and is_equal_approx(game.run.energy,Data.max_energy(game.run)),"With a bow in hand none of the warrior's skills can be used, and none takes up the sword in his bag")
	dealt = blows(victim,1)
	check(dealt[0] > 0.0 and game.run.equipment.main == it("rangers_bow"),"His normal attack with it is a bowshot")
	game.player.busy = 0
	game.swap_weapon()
	check(game.run.equipment.main == it("simple_shortsword") and game.run.equipment.off == it("lions_buckler") and game.skills.reason("cleave") == "" and game.skills.reason("shield_bash") == "","X again: sword and shield back in hand, and his skills with them")

	# --- Drops in play.
	hero("warrior")
	victim = foe(1.4,10.0)
	game.loot_forced = it("steel_full_helm","swift")
	victim.hit(1000.0)
	slain += 1
	check(victim.dead and game.pickups.size() == 1 and game.run.drops.size() == 1 and game.run.drops[0].item == it("steel_full_helm","swift"),"A slain enemy's item falls to the ground")
	var lying = game.pickups[0]
	check(lying.node.position.distance_to(victim.position) < 1.2 and not lying.node.find_children("*","MeshInstance3D",true,false).is_empty(),"Its model lies where the enemy fell")
	game.hud.tick(0)
	var names: Array = game.hud.item_labels.filter(func(b): return b.visible)
	check(names.size() == 1 and names[0].text == "Swift Steel Full Helm" and names[0].get_theme_color("font_color") == Items.RARITY_COLORS.uncommon,"Its name shows over it, in its rarity's colour")
	await snapshot("ground")
	names[0].pressed.emit()
	check(game.pickups.is_empty() and game.run.drops.is_empty() and it("steel_full_helm","swift") in game.run.bag,"Clicking the name picks it up, into the bag")
	game.hud.tick(0)
	check(game.hud.item_labels.filter(func(b): return b.visible).is_empty(),"and its name is gone")
	# From further off he walks to it first.
	# (Laid exactly, not where chance would put it, so he always has a path.)
	var spot: Vector3 = game.world.move(origin,Vector3(0,0,-6))
	var hammer_drop = {"item":it("war_hammer"),"position":[spot.x,spot.z]}
	game.run.drops.append(hammer_drop); game.create_pickup(hammer_drop)
	lying = game.pickups[0]
	game.pick_up(lying)
	check(game.pickups.size() == 1 and game.pickup_goal == lying and not game.route.is_empty(),"Clicked from afar, he sets out for it")
	for i in 900:
		game.player.tick(STEP); game.player_control(STEP)
		if game.pickups.is_empty(): break
	check(game.pickups.is_empty() and it("war_hammer") in game.run.bag and game.player.position.distance_to(origin) > 3.0,"and picks it up when he reaches it")
	# A full bag leaves it lying.
	for i in Items.BAG_SIZE: game.run.bag[i] = it("bandit_blade")
	game.drop_item(it("greatsword"),game.player.position)
	game.pick_up(game.pickups[0])
	check(game.pickups.size() == 1 and game.hud.notice.text == "Your bag is full.","With a full bag it stays on the ground")
	# What lies on the ground is kept with the save.
	game.save_run()
	game.continue_run()
	loaded = ""; slain = 0
	check(game.pickups.size() == 1 and game.run.drops[0].item == it("greatsword") and game.run.bag.count(it("bandit_blade")) == Items.BAG_SIZE,"A save keeps what lies on the ground, and the bag")
	# Thrown out of the inventory, an item lies at his feet.
	game.discard_item("bag:0")
	check(game.pickups.size() == 2 and game.run.bag[0].is_empty() and game.run.drops.size() == 2,"An item dragged out of the inventory is dropped")
	# A retried floor's enemies drop nothing a second time.
	hero("warrior")
	victim = foe(1.4,10.0)
	game.run.xp_claimed.append(victim.uid)
	game.loot_forced = it("steel_full_helm")
	victim.hit(1000.0)
	slain += 1
	check(game.pickups.is_empty(),"An enemy already rewarded drops nothing again")
	game.loot_forced = {}
	# What falls in play is made for the class, with the game's own dice.
	hero("wizard")
	game.loot_off = false
	var fallen = 0
	var right = true
	for i in 60:
		victim = foe(1.4,10.0)
		victim.hit(1000.0)
		slain = (slain+1)%game.enemies.size()
		for p in game.pickups:
			fallen += 1
			right = right and Items.valid_instance(p.drop.item) and Items.usable("wizard",p.drop.item)
			p.node.queue_free()
		game.pickups.clear(); game.run.drops.clear()
	check(right,"Whatever falls for a wizard, he can use (%d fell of 60)" % fallen)
	game.loot_off = true

	# --- Items show on the hero.
	hero("warrior")
	var look = game.player.visual
	check(look.parts.HeroHelmet.visible and look.parts.HeroArmor.visible and look.parts.HeroKilt.visible and look.parts.HeroBracers.visible and look.parts.HeroGreaves.visible and not look.parts.HeroCuisses.visible and not look.parts.Hair_SimpleParted.visible,"The warrior's starting kit is drawn, his greaves with it")
	game.move_item("head","bag:0")
	check(not look.parts.HeroHelmet.visible and look.parts.Hair_SimpleParted.visible,"Without his helm, his hair")
	game.move_item("chest","bag:1")
	check(not look.parts.HeroArmor.visible and look.parts.SuperHero_Male.material_override is ShaderMaterial and look.parts.SuperHero_Male.material_override.get_shader_parameter("bare").x == 1.0 and look.parts.SuperHero_Male.material_override.get_shader_parameter("bare").y == 0.0,"Without his cuirass, his bare chest (and his kilt still)")
	game.run.bag[2] = it("steel_breastplate","durable"); game.move_item("bag:2","chest")
	check(look.parts.HeroArmor.visible and look.parts.HeroArmor.material_override != Art.hero_kit("warrior") and look.parts.SuperHero_Male.material_override.get_shader_parameter("recolor").x == 1.0 and look.parts.SuperHero_Male.material_override.get_shader_parameter("tint_chest") == Items.BASES.steel_breastplate.look.tint,"A steel breastplate is steel, affix or no")
	game.move_item("legs","bag:3"); game.move_item("hands","bag:4")
	check(not look.parts.HeroKilt.visible and not look.parts.HeroBelt.visible and not look.parts.HeroBracers.visible,"Kilt and gauntlets come off")
	game.run.bag[9] = it("plated_leg_armor","tough"); game.move_item("bag:9","legs")
	check(look.parts.HeroCuisses.visible and look.parts.HeroBelt.visible and not look.parts.HeroKilt.visible and look.parts.HeroCuisses.material_override.shader.resource_path.ends_with("plate.gdshader"),"Plated leg armor is steel cuisses in the kilt's place")
	game.move_item("legs","bag:9"); game.move_item("feet","bag:%d" % Items.free_bag_slot(game.run))
	check(not look.parts.HeroCuisses.visible and not look.parts.HeroGreaves.visible and look.parts.SuperHero_Male.material_override.get_shader_parameter("bare").z == 1.0,"Boots off: no greaves, his bare feet and shins")
	game.run.bag[5] = it("war_hammer"); game.move_item("bag:5","main")
	check(look.weapon_kind == "heavy" and look.family == "heavy" and is_instance_valid(look.weapon_item) and not is_instance_valid(look.shield_item) and look.idle_action() == "HeavyIdle" and look.two_hands.weight == 1.0,"The War Hammer is held in both hands, in its own stance")
	game.run.bag[6] = it("tower_shield"); game.run.bag[7] = it("steel_longsword"); game.move_item("bag:7","main"); game.move_item("bag:6","off")
	check(look.weapon_kind == "sword" and is_instance_valid(look.shield_item) and look.shield_item.scale.y > 1.0,"A tower shield on his arm, tall as it is")
	await snapshot("warrior-tower")
	hero("ranger")
	look = game.player.visual
	check(look.parts.RangerCloak.visible and look.parts.RangerBody.visible and not look.parts.SuperHero_Male.visible and look.parts.RangerCloak.material_override.get_shader_parameter("cloth_color") == Items.BASES.leather_hood.look.tint,"The ranger starts in his Leather Hood: his cloak, in leather's colour")
	game.move_item("head","bag:2")
	check(look.parts.SuperHero_Male.visible and not look.parts.RangerBody.visible and not look.parts.RangerCloak.visible and look.parts.Hair_SimpleParted.visible and game.run.bag[2] == it("leather_hood"),"Hood off, he is bareheaded, the whole of him shown")
	hero("wizard")
	look = game.player.visual
	game.run.bag[0] = it("robe_of_the_lost_emperor"); game.move_item("bag:0","chest")
	check(look.parts.WizardRobe.visible and look.parts.WizardRobe.material_override.get_shader_parameter("cloth_color") == Items.BASES.robe_of_the_lost_emperor.look.tint and look.parts.WizardHood.material_override.get_shader_parameter("cloth_color") != Items.BASES.robe_of_the_lost_emperor.look.tint,"The Robe of the Lost Emperor is purple, his hood still his own")
	game.run.bag[1] = it("wizard_hat"); game.move_item("bag:1","head")
	check(not look.parts.WizardHood.visible and is_instance_valid(look.hat_item) and look.hat_item.bone_name == "Head" and not look.hat_item.find_children("*","MeshInstance3D",true,false).is_empty() and not look.parts.Hair_SimpleParted.visible,"A Wizard Hat is a hat of its own on his head, his hood put away")
	game.move_item("head","bag:%d" % Items.free_bag_slot(game.run))
	check(not is_instance_valid(look.hat_item) and look.parts.Hair_SimpleParted.visible and game.run.equipment.head.is_empty(),"Taken off, it is gone")
	await snapshot("wizard-hat")

	# --- Saves from before this item system.
	var old = Data.new_run("warrior")
	old.version = 15
	old.equipment = {"head":"gladiator_helm","chest":"scale_cuirass","legs":"studded_kilt","feet":"strapped_sandals","hands":"steel_manica","main":"legionary_sword","off":"lion_shield"}
	old.bag = ["bronze_helm","gate_key","","","","","","","",""]
	old.drops = [{"item":"greatsword","position":[0,9]}]
	var migrated = Save.migrate(old)
	check(Save.valid(old) and Save.valid(migrated) and migrated.version == Data.new_run().version and migrated.equipment == Data.new_run("warrior").equipment and Items.carries(migrated,"gate_key") and migrated.bag.filter(func(i): return not i.is_empty()).size() == 1 and migrated.drops.is_empty(),"An earlier save is given its class's new starting equipment, keeping only its gate key")

	# --- The inventory.
	hero("warrior")
	var panels = game.hud.panels
	game.run.bag[0] = it("steel_full_helm","tough"); game.run.bag[1] = it("greatsword"); game.run.bag[2] = it("wool_hood"); game.run.bag[3] = it("ancient_gladiators_helmet")
	game._input(key(KEY_I))
	game.hud.tick(0)
	check(game.mode == "character" and panels.inventory_open() and not panels.stats_open() and not panels.skills_open(),"I opens the character window at the inventory, pausing the game")
	check(panels.slots.size() == 17 and ["head","chest","legs","feet","hands","main","off"].all(func(s): return panels.slots.has(s)),"Seven equipment slots and ten bag places")
	var bag_rects: Array = []
	for i in Items.BAG_SIZE: bag_rects.append(panels.slots["bag:%d" % i].frame)
	check(bag_rects[0].get_parent() is GridContainer and bag_rects[0].get_parent().columns == 5 and bag_rects[0].get_parent().get_child_count() == 10,"The bag is a grid five wide and two tall")
	check(panels.figure.hero_class == "warrior" and panels.figure.worn == game.run.equipment,"The figure in the middle is the hero as he is dressed")
	check(panels.slots.head.icon.texture != null and panels.slots["bag:1"].icon.texture != null and panels.slots["bag:5"].icon.texture == null,"Each item is pictured in its square")
	check(panels.slots["bag:0"].frame.get_theme_stylebox("panel") == panels.slot_styles.uncommon and panels.slots["bag:3"].frame.get_theme_stylebox("panel") == panels.slot_styles.unique and panels.slots["bag:1"].frame.get_theme_stylebox("panel") == panels.slot_styles.common,"Each square is framed in its item's rarity")
	check(panels.can_drop("head",{"item_from":"bag:0"}) and not panels.can_drop("chest",{"item_from":"bag:0"}) and not panels.can_drop("head",{"item_from":"bag:2"}) and panels.can_drop("bag:7",{"item_from":"bag:0"}),"A dragged item may be put down only where it fits")
	panels.drop_on("head",{"item_from":"bag:0"})
	check(game.run.equipment.head == it("steel_full_helm","tough") and game.run.bag[0] == it("gladiators_helmet") and panels.figure.worn.head == it("steel_full_helm","tough") and game.player.visual.worn.head == it("steel_full_helm","tough"),"Dropped on its slot it is worn: by the hero and by his figure")
	panels.drop_on("bag:8",{"item_from":"head"})
	check(game.run.equipment.head.is_empty() and game.run.bag[8] == it("steel_full_helm","tough"),"Dragged off into the bag it is taken off")
	panels.quick_move("bag:1")
	check(game.run.equipment.main == it("greatsword") and game.run.equipment.off.is_empty(),"A right click equips from the bag")
	panels.quick_move("main")
	check(game.run.equipment.main.is_empty() and it("greatsword") in game.run.bag,"and takes off what is worn")
	panels.hovered_item = "bag:%d" % game.run.bag.find(it("greatsword"))
	game.hud.tick(0)
	check(is_instance_valid(panels.item_tip) and panels.item_tip.visible and panels.item_tip_lines.title.text == "Greatsword" and "30–42 damage" in panels.item_tip_lines.stats.text and "1.2 attacks per second" in panels.item_tip_lines.stats.text and not panels.item_tip_lines.effect.visible,"Hovering an item shows what it is")
	panels.hovered_item = "bag:8"
	game.hud.tick(0)
	check(panels.item_tip_lines.title.text == "Tough Steel Full Helm" and panels.item_tip_lines.title.get_theme_color("font_color") == Items.RARITY_COLORS.uncommon and "+5 Vitality" in panels.item_tip_lines.stats.text,"A magic item's whole name, in its colour, and its affix")
	panels.hovered_item = "bag:3"
	game.hud.tick(0)
	check(panels.item_tip_lines.effect.visible and "Rallying Cry" in panels.item_tip_lines.effect.text and panels.item_tip_lines.title.get_theme_color("font_color") == Items.RARITY_COLORS.unique,"A unique's effect is told")
	panels.hovered_item = "bag:%d" % game.run.bag.find(it("wool_hood"))
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
	game.run.bag[0] = it("steel_full_helm")
	game._input(key(KEY_I))
	game.hud.tick(0)
	await frames(6)
	await drag(panels.slots["bag:0"].frame.get_global_rect().get_center(),panels.slots.head.frame.get_global_rect().get_center())
	game.hud.tick(0)
	check(game.run.equipment.head == it("steel_full_helm") and game.run.bag[0] == it("gladiators_helmet") and game.player.visual.worn.head == it("steel_full_helm"),"Dragged with the mouse from the bag onto the head slot, the helm is worn")
	await snapshot("dragged")
	await drag(panels.slots["bag:0"].frame.get_global_rect().get_center(),Vector2(240,300))
	check(game.run.bag[0].is_empty() and game.pickups.size() == 1 and game.pickups[0].drop.item == it("gladiators_helmet"),"Dragged out of the window, the old helm is dropped on the ground")
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
		check(game.pickups.is_empty() and it("gladiators_helmet") in game.run.bag,"Clicked with the mouse, it is picked up again")

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
