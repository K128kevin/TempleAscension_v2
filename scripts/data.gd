extends RefCounted
## Balance translated from the original game's src/config/balance.ts.
# The temple's floors: five and the summit. (No place in the game has a name.)
const FLOORS = 6
const COUNTS = [
	{"gladiator":14,"archer":10},
	{"gladiator":12,"archer":10,"lion":10},
	{"gladiator":18,"archer":15,"lion":12,"wizard":9},
	{"gladiator":15,"archer":12,"lion":12,"wizard":12,"centurion":6},
	{"gladiator":23,"archer":12,"lion":15,"wizard":18,"centurion":12}]
const ENEMIES = {
	"gladiator":{"title":"Gladiator","hp":33.0,"damage":7.5,"speed":3.56,"range":1.9,"interval":1.0,"weapon":"sword","shield":"scutum","size":1.0,"color":Color(.70,.73,.69)},
	"archer":{"title":"Archer","hp":18.0,"damage":12.5,"speed":3.56,"range":10.6,"interval":1.22,"weapon":"bow","size":.94,"color":Color(.59,.73,.68)},
	# A stone lion the size of a living one. It swipes from where its raised
	# forepaw reaches (its head is a metre ahead of its middle); `height` is
	# where its health bar sits, for a figure that is not a standing man.
	"lion":{"title":"Lion Guardian","hp":28.0,"damage":4.5,"speed":7.12,"range":2.3,"interval":.5,"weapon":"","size":1.0,"height":1.5,"color":Color(.79,.64,.42)},
	"wizard":{"title":"Oracle","hp":33.0,"damage":22.5,"speed":4.75,"range":11.8,"interval":3.0,"weapon":"staff","size":1.06,"color":Color(.54,.57,.78)},
	# The centurion's long spear: he thrusts from about where its point, driven
	# home with his step in, ends at his target, and it strikes whoever stands
	# within its point's reach as the blow lands ("strike", centre to centre,
	# from where his step has carried him).
	"centurion":{"title":"Centurion","hp":65.0,"damage":27.5,"speed":3.56,"range":3.0,"strike":3.1,"interval":1.0,"weapon":"spear","shield":"tower","size":1.2,"color":Color(.64,.68,.76)},
	"boss":{"title":"The Crowned Statue","hp":1250.0,"damage":67.5,"speed":4.27,"range":3.3,"interval":2.0,"weapon":"sword","size":2.0,"color":Color(.85,.75,.52)}}
const Skills = preload("res://scripts/skill_data.gd")
const CLASSES = ["warrior","ranger","wizard"]
const WEAPONS = ["spear","sword","bow","axe","staff"]
const SPECIALS = ["Jab","Slash","Rapid Fire","Whirl","Arcane Bolt"]
const COSTS = [15.0,20.0,18.0,35.0,12.0]
const STATS = ["Strength","Dexterity","Intelligence","Vitality","Willpower"]
const STAT_HELP = ["+2% melee damage","+2% ranged damage; +1% melee attack speed","+2% spell damage","+10 maximum health","+3 maximum energy; +0.1 energy/sec"]
const GEM_COLORS = [Color(1,.20,.24),Color(.2,1,.63),Color(.2,.58,1),Color(.8,.9,1)]
const DIFFICULTIES = ["Easy","Moderate","Hard"]
const HEALTH_SCALE = [.9,1.1,1.4]
const DAMAGE_SCALE = [.7,1.1,1.4]
const ENEMY_LEVELS = [1,4,8,12,18,22]
const MAX_LEVEL = 20
# Attribute points for each level gained; each level also grants a skill point.
const STAT_POINTS = 5
# XP needed to advance from levels 1 through 19; the cap is 20.
const XP_STEPS = [100,150,220,300,400,520,650,800,960,1140,1340,1560,1800,2060,2340,2640,2960,3300,3660]
# The fastest a melee swing can become, however much attack speed is stacked.
const MELEE_MINIMUM = .2

static func new_run(class_id: String = "warrior") -> Dictionary:
	var starter: String = {"warrior":"cleave","ranger":"power_shot","wizard":"firebolt"}.get(class_id,"cleave")
	var ranks = {}; ranks[starter] = 1
	return {"version":7,"place":"temple","class_id":class_id,"level":1,"xp":0,"xp_claimed":[],"skills":ranks,"skill_points":0,"hotbar":[starter,"",""],"floor":0,"stats":[5,5,5,5,5],"owned":[false,class_id=="warrior",class_id=="ranger",false,class_id=="wizard"],"weapon":{"warrior":1,"ranger":2,"wizard":4}.get(class_id,1),"difficulty":0,"gems":[],"dead":[],"drops":[],"deaths":0,"seed":randi(),"position":[0,9],"health":100.0,"energy":100.0,"phase":"playing","points":0,"completed":false,"heal_cooldown":0.0}

# Where a run can be: on a floor of the temple, or in the world outside it
# (the town, the desert and the temple's front; scripts/overworld.gd).
const PLACES = ["temple","world"]

# A new character wakes in the middle of the desert, between the town and the
# temple. (new_run alone starts at the temple's first floor.)
static func new_character(class_id: String = "warrior") -> Dictionary:
	var run = new_run(class_id)
	run.place = "world"
	# Overworld.START, beside the lost caravan.
	run.position = [-52,-15]
	return run

static func passive(run: Dictionary, id: String) -> float:
	return Skills.value(id,int(run.skills.get(id,0)))

static func max_health(run: Dictionary) -> float:
	return 100.0+(run.stats[3]-5)*10.0

static func max_energy(run: Dictionary) -> float:
	return 100.0+(run.stats[4]-5)*3.0+passive(run,"arcane_reserve")

static func energy_regen(run: Dictionary) -> float:
	return (max_energy(run)*.1+(run.stats[4]-5)*.1+passive(run,"attunement"))*(1.0+passive(run,"endurance")*.01)

static func scaling_tag(weapon: int) -> String:
	return "ranged" if weapon==2 else ("spell" if weapon==4 else "melee")

static func damage_tag(run: Dictionary, tag: String, base: float) -> float:
	var index: int = {"melee":0,"ranged":1,"spell":2}[tag]
	var bonus = 0.0 if tag=="melee" else passive(run,{"ranged":"steady_aim","spell":"elemental_mastery"}[tag])*.01
	return base*(1.0+(run.stats[index]-5)*.02)*(1.0+bonus)

static func damage(run: Dictionary, roll: float = 12.5) -> float:
	return damage_tag(run,scaling_tag(int(run.weapon)),roll)

static func cooldown(_run: Dictionary) -> float: return .5

# Percent faster every melee swing is: 1% for each point of Dexterity.
static func melee_haste(run: Dictionary) -> float:
	return (run.stats[1]-5)*1.0

# Percent faster the normal melee attack is: Dexterity and Quick Strikes.
static func melee_attack_speed(run: Dictionary) -> float:
	return melee_haste(run)+passive(run,"quick_strikes")

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
	var base: int = {"gladiator":65,"archer":55,"lion":60,"wizard":80,"centurion":120,"boss":1800}[kind]
	var level: int = ENEMY_LEVELS[run.floor]
	var penalty = maxf(.1,1.0-maxi(0,int(run.level)-level-3)*.12)
	return maxi(1,roundi(base*(1.0+(level-1)*.2)*penalty))

static func mitigate(damage_value: float, armor: float, resistance: float, attacker_level: int, type: String) -> float:
	var reduction = armor/(armor+100.0+20.0*attacker_level) if type=="physical" else resistance
	return damage_value*(1.0-clampf(reduction,0,.75))

static func respec(run: Dictionary) -> void:
	run.stats = [5,5,5,5,5]
	run.points = (int(run.level)-1)*STAT_POINTS
	run.skills = {}
	run.skill_points = int(run.level)
	run.hotbar = ["","",""]
	run.health = minf(run.health,max_health(run))
	run.energy = minf(run.energy,max_energy(run))
