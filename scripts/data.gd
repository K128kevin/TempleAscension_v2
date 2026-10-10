extends RefCounted
## Balance translated from the original game's src/config/balance.ts.
# The temple's floors: three and the summit. (No place in the game has a name.)
const FLOORS = 4
# Where a run can be: in the world outside (the town, the deserts and the
# temple's front; scripts/overworld.gd), on a floor of the temple, or on a
# level of one of the two dungeons fought through before it: the basement
# under the town's arena, and the bandits' cave in the north of the desert.
const PLACES = ["temple","world","basement","cave"]
const DUNGEONS = ["basement","cave"]
# Each place's floors, in the order they are met: how strong what is there is
# (its level), and who stands there. The dungeons hold bandits, with swords
# and with bows. The temple's first floor holds gladiators, archers and lions;
# its second adds Oracles (and has the fountain court); on its third
# centurions stand in the gladiators' place (and it has the terraces); its
# summit, the Crowned Statue.
const AREAS = {
	"basement":[{"level":1,"counts":{"bandit":36,"bandit_archer":20}},{"level":3,"counts":{"bandit":52,"bandit_archer":32}}],
	"cave":[{"level":5,"counts":{"bandit":29,"bandit_archer":18}},{"level":8,"counts":{"bandit":36,"bandit_archer":23}}],
	"temple":[{"level":11,"counts":{"gladiator":35,"archer":20,"lion":16}},
		{"level":15,"counts":{"gladiator":36,"archer":23,"lion":26,"wizard":16}},
		{"level":19,"counts":{"archer":23,"lion":36,"wizard":29,"centurion":75}},
		{"level":23,"counts":{}}]}
# The temple's own, as lists (tests and the debug tools read them).
const COUNTS = [{"gladiator":35,"archer":20,"lion":16},{"gladiator":36,"archer":23,"lion":26,"wizard":16},{"archer":23,"lion":36,"wizard":29,"centurion":75}]
# (Every enemy's health and damage were raised by half again.)
const ENEMIES = {
	"gladiator":{"title":"Gladiator","hp":49.5,"damage":11.25,"speed":3.56,"range":1.9,"interval":1.0,"weapon":"sword","shield":"scutum","size":1.0,"color":Color(.70,.73,.69)},
	"archer":{"title":"Archer","hp":27.0,"damage":18.75,"speed":3.56,"range":10.6,"interval":1.22,"weapon":"bow","size":.94,"color":Color(.59,.73,.68)},
	# A stone lion the size of a living one. It swipes from where its raised
	# forepaw reaches (its head is a metre ahead of its middle); `height` is
	# where its health bar sits, for a figure that is not a standing man.
	"lion":{"title":"Lion Guardian","hp":42.0,"damage":13.5,"speed":7.12,"range":2.3,"interval":.5,"weapon":"","size":1.0,"height":1.5,"color":Color(.79,.64,.42)},
	"wizard":{"title":"Oracle","hp":49.5,"damage":33.75,"speed":4.75,"range":11.8,"interval":3.0,"weapon":"staff","size":1.06,"color":Color(.54,.57,.78)},
	# The centurion's long spear: he thrusts from about where its point, driven
	# home with his step in, ends at his target, and it strikes whoever stands
	# within its point's reach as the blow lands ("strike", centre to centre,
	# from where his step has carried him).
	"centurion":{"title":"Centurion","hp":97.5,"damage":41.25,"speed":3.56,"range":3.0,"strike":3.1,"interval":1.0,"weapon":"spear","shield":"tower","size":1.2,"color":Color(.64,.68,.76)},
	# Bandits are people, not statues: they fall rather than crumble. Each fights
	# `as` one of the temple's guardians does (a swordsman as a gladiator, a
	# bowman as an archer), in a raider's linen, leather and red cloth
	# (scripts/bandit.gd), a man or a woman.
	"bandit":{"title":"Bandit","as":"gladiator","human":"bandit","hp":45.0,"damage":10.5,"speed":3.7,"range":1.9,"interval":1.0,"weapon":"sword","size":1.0,"color":Color(.5,.4,.3)},
	"bandit_archer":{"title":"Bandit Archer","as":"archer","human":"bandit","hp":27.0,"damage":15.0,"speed":3.6,"range":10.6,"interval":1.3,"weapon":"bow","size":1.0,"color":Color(.5,.4,.3)},
	"boss":{"title":"The Crowned Statue","hp":1875.0,"damage":101.25,"speed":4.27,"range":3.3,"interval":2.0,"weapon":"sword","size":2.0,"color":Color(.85,.75,.52)}}
const Skills = preload("res://scripts/skill_data.gd")
const Items = preload("res://scripts/items.gd")
const CLASSES = ["warrior","ranger","wizard"]
# The kinds of weapon, by number (weapon()): what is in the main hand, the
# last with nothing there. (What a hero wears and holds is scripts/items.gd.)
const WEAPONS = ["spear","sword","bow","axe","staff","dagger","mace","unarmed"]
const UNARMED = 7
const SPECIALS = ["Jab","Slash","Rapid Fire","Whirl","Arcane Bolt","Stab"]
const COSTS = [15.0,20.0,18.0,35.0,12.0,15.0]
const STATS = ["Strength","Dexterity","Intelligence","Vitality","Willpower"]
const STAT_HELP = ["+2% melee damage (dagger too)","+2% bow damage; +0.3% attack speed; +0.25% critical strike chance","+2% spell damage","+10 maximum health","+3 maximum energy; +0.1 energy/sec"]

# What the hero's skills are paid with, as he knows it: a wizard's is mana.
static func energy_word(run: Dictionary) -> String:
	return "mana" if run.get("class_id","") == "wizard" else "energy"

# Words about energy, as the hero's class calls it (`text` written of
# energy; a wizard reads mana).
static func in_his_words(run: Dictionary, text: String) -> String:
	if energy_word(run) != "mana": return text
	return text.replace("Energy","Mana").replace("energy","mana")

# What an attribute does, in the hero's own words.
static func stat_help(run: Dictionary, index: int) -> String:
	return in_his_words(run,STAT_HELP[index])
# A wizard's spells are worked from a set baseline (a hit's least and most
# before Intelligence), not from the weapon in hand; a staff may raise them.
const SPELL_SPAN = [10.0,15.0]
const GEM_COLORS = [Color(1,.20,.24),Color(.2,1,.63),Color(.2,.58,1),Color(.8,.9,1)]
const DIFFICULTIES = ["Normal","Hard"]
const HEALTH_SCALE = [1.8,2.8]
const DAMAGE_SCALE = [.7,1.4]
# (The temple's floors' levels: AREAS has every place's.)
const ENEMY_LEVELS = [11,15,19,23]
const MAX_LEVEL = 25
# Attribute points for each level gained; each level also grants a skill point.
const STAT_POINTS = 5
# XP needed to advance from levels 1 through 24; the cap is 25. (Each step
# grows by 20 more than the one before.)
const XP_STEPS = [100,150,220,300,400,520,650,800,960,1140,1340,1560,1800,2060,2340,2640,2960,3300,3660,4040,4440,4860,5300,5760]
# The fastest a melee swing can become, however much attack speed is stacked.
const MELEE_MINIMUM = .2

# The hotbar: RMB, 1 to 4, and LMB (LEFT_SLOT). Only the wizard puts a
# skill on LMB: he has no normal attack, and his left click casts it instead.
const LEFT_SLOT = 5
static func casts_left(run: Dictionary) -> bool:
	return run.get("class_id","")=="wizard"

static func new_run(class_id: String = "warrior") -> Dictionary:
	# No skill is learned yet: the first level's point goes wherever the
	# player likes.
	var run = {"version":15,"place":"temple","cleared":[],"class_id":class_id,"level":1,"xp":0,"xp_claimed":[],"skills":{},"skill_points":1,"hotbar":["","","","","",""],"floor":0,"stats":[5,5,5,5,5],"equipment":{},"bag":[],"difficulty":0,"gems":[],"dead":[],"drops":[],"keys":[],"deaths":0,"seed":randi(),"position":[0,9],"health":100.0,"energy":100.0,"phase":"playing","points":0,"completed":false,"heal_cooldown":0.0}
	Items.outfit(run,class_id)
	return run

# The floor the run is on (in the world outside, the temple's first).
static func area(run: Dictionary) -> Dictionary:
	var place: String = run.get("place","temple")
	var floors: Array = AREAS[place if AREAS.has(place) else "temple"]
	return floors[clampi(int(run.floor),0,floors.size()-1)]

static func enemy_level(run: Dictionary) -> int:
	return area(run).level

# Whether the run is on the temple's summit, or on its place's last floor.
static func summit(run: Dictionary) -> bool:
	return run.get("place","temple") in ["temple","world"] and int(run.floor)==FLOORS-1
static func last_floor(run: Dictionary) -> bool:
	var place: String = run.get("place","temple")
	return int(run.floor)>=AREAS[place if AREAS.has(place) else "temple"].size()-1

# The temple's door stays shut until both dungeons have been fought through.
static func temple_open(run: Dictionary) -> bool:
	for dungeon in DUNGEONS:
		if not dungeon in run.get("cleared",[]): return false
	return true

# An enemy's name in the run's saved lists: its floor and its number there
# (and, outside the temple, its place).
static func enemy_id(run: Dictionary, number: int) -> String:
	var place: String = run.get("place","temple")
	return "%d:%d" % [run.floor,number] if place=="temple" else "%s:%d:%d" % [place,run.floor,number]

# Whether a saved enemy's name belongs to `place`.
static func of_place(id: String, place: String) -> bool:
	if place=="temple": return not (id.begins_with("basement:") or id.begins_with("cave:"))
	return id.begins_with(place+":")

# A new character wakes on the great dune south of the town, by a campfire.
# (new_run alone starts at the temple's first floor.)
static func new_character(class_id: String = "warrior") -> Dictionary:
	var run = new_run(class_id)
	run.place = "world"
	# Overworld.START, by the camp on the dune; he sits there until he moves.
	run.position = [-262,144]
	run["resting"] = true
	# It is night (scripts/daylight.gd), some minutes before the dawn.
	run["clock"] = 1440.0
	return run

static func passive(run: Dictionary, id: String) -> float:
	return Skills.value(id,int(run.skills.get(id,0)))

# An attribute as it counts: the points spent on it, and what the hero's
# equipment adds.
static func stat(run: Dictionary, index: int) -> int:
	return int(run.stats[index])+int(Items.bonus(run,Items.ATTRIBUTES[index]))

# The kind of weapon in the main hand, as its number in WEAPONS.
static func weapon(run: Dictionary) -> int:
	return WEAPONS.find(Items.kind(run))

# How the weapon in hand is swung: "one", "heavy", "pike", "bow", "staff",
# "dagger" or "fist" (Items.family).
static func family(run: Dictionary) -> String:
	return Items.family(Items.main(run))

static func max_health(run: Dictionary) -> float:
	return 100.0+(stat(run,3)-5)*10.0+Items.bonus(run,"health")

static func max_energy(run: Dictionary) -> float:
	return 100.0+(stat(run,4)-5)*3.0+Items.bonus(run,"energy")

static func energy_regen(run: Dictionary) -> float:
	return (max_energy(run)*.1+(stat(run,4)-5)*.1)*(1.0+passive(run,"endurance")*.01)

# (Strength serves every weapon in hand, the dagger's too; Dexterity the bow.)
static func scaling_tag(kind: int) -> String:
	return "ranged" if kind==2 else ("spell" if kind==4 else "melee")

# `base` damage of `tag` as the hero's attributes raise it: 2% for each point
# of Strength (melee), Dexterity (ranged) or Intelligence (spells), and for
# spells whatever spell damage his equipment adds.
static func damage_tag(run: Dictionary, tag: String, base: float) -> float:
	var index: int = {"melee":0,"ranged":1,"spell":2}[tag]
	var gear = Items.bonus(run,"spell_damage")*.01 if tag=="spell" else 0.0
	return base*(1.0+(stat(run,index)-5)*.02)*(1.0+gear)

static func damage(run: Dictionary, roll: float = 12.5) -> float:
	return damage_tag(run,scaling_tag(weapon(run)),roll)

# The baseline of a hit of `tag`, its least and most before attributes: the
# damage of the weapon it is made with (Items.damage_span), which the normal
# attack deals and every skill deals a percentage of. A wizard's spells (and
# his staff's bolts) are not the weapon's: theirs is SPELL_SPAN.
static func span(run: Dictionary, tag: String) -> Array:
	return SPELL_SPAN if tag=="spell" else Items.damage_span(run,tag)

# One hit's baseline, by chance within its span.
static func roll(run: Dictionary, tag: String) -> float:
	var between: Array = span(run,tag)
	return randf_range(between[0],between[1])

# Percent less damage the hero takes, for the armor he wears.
static func armor(run: Dictionary) -> float:
	return Items.armor(run)

static func cooldown(_run: Dictionary) -> float: return .5

# Percent faster every attack is, melee swing or bowshot: 0.3% for each
# point of Dexterity.
const HASTE_PER_DEXTERITY = .3
static func attack_haste(run: Dictionary) -> float:
	return (stat(run,1)-5)*HASTE_PER_DEXTERITY+Items.bonus(run,"haste")

# Percent chance that a hit the hero lands is a critical hit, for double
# damage: 20%, and 0.25% more for each point of Dexterity.
const CRIT_BASE = 20.0
const CRIT_PER_DEXTERITY = .25
const CRIT_MULTIPLIER = 2.0
static func crit_chance(run: Dictionary) -> float:
	return CRIT_BASE+(stat(run,1)-5)*CRIT_PER_DEXTERITY+Items.bonus(run,"crit")

# The ranger's mastery of the weapon a hit is made with (Bow and Dagger
# Specialization): its x percent more chance to crit, and y percent more
# damage when it does.
static func specialization(run: Dictionary, weapon: int) -> Dictionary:
	var id: String = {2:"bow_specialization",5:"dagger_specialization"}.get(weapon,"")
	if id.is_empty(): return {"x":0.0,"y":0.0,"z":0.0}
	return Skills.values(id,int(run.skills.get(id,0)))

# The shield in the off hand (its "block" and "mitigation"), or {} with none.
static func shield(run: Dictionary) -> Dictionary:
	return Items.shield(run)

# Percent chance to block an attack, and percent less damage a blocked attack
# deals: the shield's own, and Shield Expertise's on top. Nothing without a shield.
static func block_chance(run: Dictionary) -> float:
	var held: Dictionary = shield(run)
	return held.block+Skills.values("shield_expertise",int(run.skills.get("shield_expertise",0))).x if not held.is_empty() else 0.0
static func block_mitigation(run: Dictionary) -> float:
	var held: Dictionary = shield(run)
	return held.mitigation+Skills.values("shield_expertise",int(run.skills.get("shield_expertise",0))).y if not held.is_empty() else 0.0

# Percent faster the normal melee attack is: Dexterity and Quick Strikes.
static func melee_attack_speed(run: Dictionary) -> float:
	return attack_haste(run)+passive(run,"quick_strikes")

static func xp_at_level(level: int) -> int:
	var total = 0
	for i in mini(level-1,MAX_LEVEL-1): total += XP_STEPS[i]
	return total

static func gain_xp(run: Dictionary, amount: int) -> int:
	var before = int(run.level)
	run.xp = mini(xp_at_level(MAX_LEVEL),int(run.xp)+maxi(0,amount))
	while run.level<MAX_LEVEL and run.xp>=xp_at_level(int(run.level)+1):
		run.level += 1
		run.points += STAT_POINTS
		run.skill_points += 1
	return int(run.level)-before

static func enemy_xp(run: Dictionary, kind: String) -> int:
	var base: int = {"bandit":26,"bandit_archer":22,"gladiator":65,"archer":55,"lion":60,"wizard":80,"centurion":120,"boss":1800}[kind]
	var level: int = enemy_level(run)
	var penalty = maxf(.1,1.0-maxi(0,int(run.level)-level-3)*.12)
	return maxi(1,roundi(base*(1.0+(level-1)*.2)*penalty))

static func mitigate(damage_value: float, armor: float, resistance: float, attacker_level: int, type: String) -> float:
	var reduction = armor/(armor+100.0+20.0*attacker_level) if type=="physical" else resistance
	return damage_value*(1.0-clampf(reduction,0,.75))

static func respec(run: Dictionary) -> void:
	run.stats = [5,5,5,5,5]
	run.points = (int(run.level)-1)*STAT_POINTS
	reset_skills(run)
	run.health = minf(run.health,max_health(run))
	run.energy = minf(run.energy,max_energy(run))

# Every skill unlearned and its points given back (one for each level, the
# first skill's among them), with the hotbar emptied.
static func reset_skills(run: Dictionary) -> void:
	run.skills = {}
	run.skill_points = int(run.level)
	run.hotbar = ["","","","","",""]
