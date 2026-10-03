extends RefCounted
## The skill roster. Every class's skills sit in three trees: area of effect,
## single target and passive. The warrior's follow the leveling and skills
## design document: five ranks each, with every rank's values listed, and a
## skill opens once enough points are spent in its tree. The ranger's and
## wizard's are the earlier roster in v2/docs/PLAN.md, still opened by level,
## where rank changes one primary value.
static var definitions: Dictionary = {}
const TREES = ["aoe","single","passive"]
const TREE_TITLES = {"aoe":"Area of Effect","single":"Single Target","passive":"Passive"}

# id, title, tree, points required in that tree, behavior, requirement, energy
# cost, description, and each rank's [x, y, z].
const WARRIOR = [
	["cleave", "Cleave", "aoe", 0, "cleave", "melee", 25, "Swipe at all enemies in a {x}° arc for {y}% damage.", [[140,125],[150,135],[160,145],[170,155],[180,165]]],
	["leap", "Leap", "aoe", 5, "leap", "melee", 40, "Leap into the air and land at a target in line of sight, dealing {x}% damage to all enemies in the area.", [[100],[120],[150],[190],[250]]],
	["ground_slam", "Ground Slam", "aoe", 5, "slam", "melee", 40, "Smash the ground, dealing {x}% damage to all enemies in front of you in a {y}° arc, up to {z} meters away.", [[100,70,10],[120,80,12],[150,90,15],[190,100,18],[250,120,21]]],
	["war_cry", "War Cry", "aoe", 0, "cry", "melee", 30, "A shout that makes every enemy within {x} meters take {y}% more damage for {z} seconds.", [[6,20,6],[7,40,7],[8,60,8],[9,80,9],[10,100,10]]],
	["shield_charge", "Shield Charge", "aoe", 10, "charge", "shield", 35, "Charge up to {x} meters behind your shield, dealing {y}% damage to every enemy in your path and knocking them aside; the first one hit is stunned for {z} seconds.", [[8,100,1],[9.5,125,1.25],[11,150,1.5],[12.5,175,1.75],[14,200,2]]],
	["shockwave", "Shockwave", "aoe", 10, "shockwave", "melee", 40, "Hammer the ground: a ring races out, dealing {x}% damage to all enemies within {y} meters and throwing them back. {z}-second cooldown.", [[180,4,10],[225,4.75,10],[270,5.5,10],[315,6.25,10],[360,7,10]]],
	["powerful_strike", "Powerful Strike", "single", 0, "strike", "melee", 25, "A powerful strike against a single enemy for {x}% damage.", [[200],[225],[250],[275],[300]]],
	["shield_bash", "Shield Bash", "single", 0, "bash", "shield", 35, "Bash the target with your shield for {x}% damage, stunning it for {y} seconds. Damage to the target breaks the stun. {z}-second cooldown. Bashing the same target again within 30 seconds stuns it for less time.", [[25,5,32],[30,6,29],[35,7,26],[40,8,23],[50,10,20]]],
	["vampiric_strike", "Vampiric Strike", "single", 5, "vampiric", "melee", 25, "Hit the target for {x}% damage and drain {y}% of its total health, healing you for {y}% of your own.", [[80,3],[90,5],[100,7],[110,9],[125,12]]],
	["shadow_strike", "Shadow Strike", "single", 5, "shadow", "melee", 25, "Deal {x}% damage, and {y}% more over 5 seconds. Refreshes Cursed Blade on the target.", [[25,100],[30,120],[40,150],[50,180],[70,220]]],
	["execute", "Execute", "single", 10, "execute", "melee", 45, "Deal {x}% damage to an enemy. Only usable on enemies below {y}% health.", [[200,20],[250,25],[300,30],[380,35],[450,40]]],
	["dash_attack", "Dash Attack", "passive", 0, "passive", "any", 0, "You Cleave at the end of your dash, but the dash costs {x} extra energy.", [[20],[15],[10],[5],[0]]],
	["shield_expertise", "Shield Expertise", "passive", 0, "passive", "any", 0, "{x}% chance to block any attack with your shield: melee attacks, arrows and spells. Blocked attacks deal {y}% less damage.", [[5,25],[10,35],[20,45],[30,60],[50,80]]],
	["endurance", "Endurance", "passive", 0, "passive", "any", 0, "Energy recovers {x}% faster.", [[10],[20],[30],[50],[75]]],
	["quick_strikes", "Quick Strikes", "passive", 5, "passive", "any", 0, "Normal attacks are {x}% faster.", [[20],[40],[70],[110],[170]]],
	["cursed_blade", "Cursed Blade", "passive", 5, "passive", "any", 0, "Your attacks make enemies take {x}% extra damage over 4 seconds. Stacks up to {y}×.", [[10,1],[15,2],[25,3],[40,5],[65,8]]],
	["offensive_rhythm", "Offensive Rhythm", "passive", 10, "passive", "any", 0, "Each hit on an enemy raises your damage by {x}%, stacking up to {y}×. Lasts {z} seconds, refreshed by every hit.", [[5,5,4],[10,6,5],[15,7,6],[20,8,9],[30,10,12]]],
	["defensive_rhythm", "Defensive Rhythm", "passive", 10, "passive", "any", 0, "Each hit you take lowers the damage you take by {x}%, stacking up to {y}×. Lasts {z} seconds, refreshed whenever you are hit.", [[3,2,4],[5,3,5],[7,4,6],[9,5,9],[12,6,12]]],
	["spiked_shield", "Spiked Shield", "passive", 10, "passive", "any", 0, "Attackers take {x}% of your normal attack damage whenever you block their attack.", [[10],[20],[35],[55],[80]]]]

static func all() -> Dictionary:
	if not definitions.is_empty(): return definitions
	for r in WARRIOR:
		definitions[r[0]] = {"id":r[0],"title":r[1],"class_id":"warrior","tree":r[2],"points":r[3],"unlock":1,"effect":r[4],"requirement":r[5],"tag":"" if r[4]=="passive" else "melee","cost":r[6],"description":r[7],"ranks":r[8],"max_rank":r[8].size()}
	# id, title, class, unlock, behavior, requirement, scaling, cost,
	# first-rank value, increment, radius, duration, description, tree
	var rows = [
		["power_shot", "Power Shot", "ranger", 1, "shot", "bow", "ranged", 15, 1.8, .25, 13, 0, "Draw and release a powerful arrow.", "single"],
		["snare", "Snare", "ranger", 1, "snare", "any", "", 15, 3, 1, 2, 0, "Place a trap that slows nearby enemies by 60%; value is duration.", "aoe"],
		["multishot", "Multishot", "ranger", 4, "multishot", "bow", "ranged", 22, .9, .15, 13, 0, "Fire three arrows in a spread.", "aoe"],
		["retreating_shot", "Retreating Shot", "ranger", 4, "retreat", "bow", "ranged", 20, 1.2, .2, 13, 0, "Fire while stepping back from the target.", "single"],
		["piercing_arrow", "Piercing Arrow", "ranger", 8, "pierce", "bow", "ranged", 22, 1.5, .2, 14, 0, "An arrow that passes through enemies.", "aoe"],
		["explosive_trap", "Explosive Trap", "ranger", 8, "trap", "any", "ranged", 25, 2, .3, 3, 1, "Arm a trap after one second; it bursts when a foe enters.", "aoe"],
		["marked_prey", "Marked Prey", "ranger", 12, "mark", "any", "", 15, 6, 1, 13, 0, "Mark one foe to take 20% more damage; value is duration.", "single"],
		["rain_of_arrows", "Rain of Arrows", "ranger", 18, "rain", "bow", "ranged", 35, .8, .15, 4, 4, "Four volleys strike the selected area.", "aoe"],
		["steady_aim", "Steady Aim", "ranger", 1, "passive", "any", "ranged", 0, 5, 5, 0, 0, "Percent additional ranged damage.", "passive"],
		["quick_draw", "Quick Draw", "ranger", 4, "passive", "any", "", 0, 6, 6, 0, 0, "Percent faster bow attack animations without changing energy cost.", "passive"],
		["trapcraft", "Trapcraft", "ranger", 12, "passive", "any", "", 0, 20, 20, 0, 0, "Percent longer snare and trap duration.", "passive"],
		["predator", "Predator", "ranger", 18, "passive", "any", "", 0, 10, 10, 0, 0, "Percent additional damage against marked prey.", "passive"],
		["firebolt", "Firebolt", "wizard", 1, "firebolt", "staff", "spell", 12, 1.5, .25, 13, 0, "Launch a bolt of fire.", "single"],
		["frost_nova", "Frost Nova", "wizard", 1, "nova", "staff", "spell", 20, 1, .2, 3.5, 3, "Damage nearby foes and slow them by 60%.", "aoe"],
		["arcane_lance", "Arcane Lance", "wizard", 4, "lance", "staff", "spell", 22, 1.6, .25, 14, 0, "An arcane projectile that pierces enemies.", "single"],
		["barrier", "Barrier", "wizard", 4, "barrier", "staff", "", 22, 35, 15, 0, 8, "Absorb the listed damage for up to eight seconds.", "single"],
		["chain_lightning", "Chain Lightning", "wizard", 8, "chain", "staff", "spell", 28, 1.4, .2, 12, 0, "Lightning jumps to up to four nearby enemies.", "aoe"],
		["blink", "Blink", "wizard", 8, "blink", "staff", "", 18, 5, .5, 0, 0, "Teleport the listed distance, stopping before walls.", "single"],
		["blizzard", "Blizzard", "wizard", 12, "blizzard", "staff", "spell", 32, .6, .1, 4, 5, "Five pulses of frost damage and slowing in the target area.", "aoe"],
		["meteor", "Meteor", "wizard", 18, "meteor", "staff", "spell", 40, 3.5, .5, 4, 1.2, "Call a fiery impact after a visible warning.", "aoe"],
		["attunement", "Attunement", "wizard", 1, "passive", "any", "", 0, .8, .8, 0, 0, "Additional energy regenerated per second.", "passive"],
		["efficient_casting", "Efficient Casting", "wizard", 4, "passive", "any", "", 0, 8, 8, 0, 0, "Percent less energy spent on spell skills.", "passive"],
		["elemental_mastery", "Elemental Mastery", "wizard", 12, "passive", "any", "spell", 0, 5, 5, 0, 0, "Percent additional spell damage.", "passive"],
		["arcane_reserve", "Arcane Reserve", "wizard", 18, "passive", "any", "", 0, 10, 10, 0, 0, "Additional maximum energy.", "passive"]]
	for r in rows:
		definitions[r[0]] = {"id":r[0],"title":r[1],"class_id":r[2],"tree":r[13],"points":0,"unlock":r[3],"effect":r[4],"requirement":r[5],"tag":r[6],"cost":r[7],"base":r[8],"step":r[9],"radius":r[10],"duration":r[11],"description":r[12],"max_rank":3 if r[4]=="passive" else 5}
	return definitions

# The highest rank that can be bought at `level`. Skills with listed ranks are
# limited only by their tree; the others gain a rank every three levels.
static func rank_cap(id: String, level: int) -> int:
	var s: Dictionary = all()[id]
	if s.has("ranks"): return s.max_rank
	return 0 if level<s.unlock else mini(s.max_rank,1+int((level-s.unlock)/3))

# A skill's primary value at `rank` (the x of a skill with listed ranks).
static func value(id: String, rank: int) -> float:
	var s: Dictionary = all()[id]
	if rank<=0: return 0.0
	if s.has("ranks"): return float(s.ranks[mini(rank,s.max_rank)-1][0])
	return float(s.base+s.step*(rank-1))

# The listed x, y and z of a skill at `rank`; zeros while unlearned.
static func values(id: String, rank: int) -> Dictionary:
	var result = {"x":0.0,"y":0.0,"z":0.0}
	var s: Dictionary = all()[id]
	if rank<=0 or not s.has("ranks"): return result
	var row: Array = s.ranks[mini(rank,s.max_rank)-1]
	for i in row.size(): result["xyz"[i]] = float(row[i])
	return result

# What the skill does at `rank`, in words.
static func describe(id: String, rank: int) -> String:
	var s: Dictionary = all()[id]
	rank = clampi(rank,1,s.max_rank)
	if s.has("ranks"):
		var v = values(id,rank)
		return s.description.format({"x":"%d" % v.x,"y":"%d" % v.y,"z":"%d" % v.z})
	var amount = "%.0f%% damage" % (value(id,rank)*100) if not s.tag.is_empty() and s.effect!="passive" else ("%.1f" % value(id,rank)).trim_suffix(".0")
	return "%s (%s)" % [s.description,amount]

static func compatible(id: String, weapon: int) -> bool:
	match all()[id].requirement:
		"melee": return weapon in [0,1,3]
		"shield": return weapon==1
		"bow": return weapon==2
		"staff": return weapon==4
	return true

# Points spent in one of the class's trees.
static func tree_points(skills: Dictionary, tree: String) -> int:
	var total = 0
	for id in skills:
		if all().has(id) and all()[id].tree==tree: total += int(skills[id])
	return total

# Why the skill cannot be learned yet, or "" once it is open.
static func locked(run: Dictionary, id: String) -> String:
	var s: Dictionary = all()[id]
	if s.class_id!=run.class_id: return "Another class's skill."
	var spent = tree_points(run.skills,s.tree)
	if spent<s.points: return "Requires %d points in %s (%d/%d)." % [s.points,TREE_TITLES[s.tree],spent,s.points]
	if int(run.level)<s.unlock: return "Requires level %d." % s.unlock
	return ""

static func can_learn(run: Dictionary, id: String) -> bool:
	if not all().has(id) or run.skill_points<=0: return false
	return locked(run,id).is_empty() and int(run.skills.get(id,0))<rank_cap(id,int(run.level))

static func learn(run: Dictionary, id: String) -> bool:
	if not can_learn(run,id): return false
	run.skills[id] = int(run.skills.get(id,0))+1
	run.skill_points -= 1
	return true

# Whether these ranks could have been bought in some order: a skill behind a
# tree requirement needs that many points in the skills that open before it.
static func reachable(skills: Dictionary) -> bool:
	for id in skills:
		var s: Dictionary = all()[id]
		if s.points<=0: continue
		var below = 0
		for other in skills:
			var o: Dictionary = all()[other]
			if o.tree==s.tree and o.class_id==s.class_id and o.points<s.points: below += int(skills[other])
		if below<s.points: return false
	return true
