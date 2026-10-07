extends RefCounted
## The skill roster. Every class's skills sit in three trees. The warrior's
## (area of effect, single target, passive) and the ranger's (attacks,
## utility, passive) follow the leveling and skills design documents: up to
## five ranks each, with every rank's values listed, and a skill opens once
## enough points are spent in its tree. The wizard's (ice, fire, lightning)
## follow the wizard skills document the same way; its passives sit in the
## tree of the element they serve.
const Items = preload("res://scripts/items.gd")
static var definitions: Dictionary = {}
const TREES = ["aoe","single","passive"]
const RANGER_TREES = ["attack","utility","passive"]
const WIZARD_TREES = ["ice","fire","lightning"]
const TREE_TITLES = {"aoe":"Area of Effect","single":"Single Target","passive":"Passive","attack":"Attacks","utility":"Utility","ice":"Ice","fire":"Fire","lightning":"Lightning"}

# The three trees a class's skills sit in.
static func trees(class_id: String) -> Array:
	return RANGER_TREES if class_id=="ranger" else (WIZARD_TREES if class_id=="wizard" else TREES)

# id, title, tree, points required in that tree, behavior, requirement, energy
# cost, description, and each rank's [x, y, z].
const WARRIOR = [
	["cleave", "Cleave", "aoe", 0, "cleave", "melee", 25, "Swipe at all enemies in a {x}° arc for {y}% damage.", [[140,125],[150,135],[160,145],[170,155],[180,165]]],
	["leap", "Leap", "aoe", 5, "leap", "melee", 40, "Leap into the air and land at a target in line of sight, dealing {x}% damage to all enemies in the area.", [[125],[165],[205],[245],[300]]],
	["ground_slam", "Thunder Slam", "aoe", 5, "slam", "melee", 40, "Smash the ground, dealing {x}% damage to all enemies in front of you in a {y}° arc, up to {z} meters away.", [[100,70,5],[120,80,5.5],[150,90,6],[190,100,7],[250,120,9]]],
	["war_cry", "War Cry", "aoe", 0, "cry", "melee", 30, "A shout that makes every enemy within {x} meters take {y}% more damage for {z} seconds.", [[6,20,6],[7,40,7],[8,60,8],[9,80,9],[10,100,10]]],
	["shield_charge", "Shield Charge", "aoe", 10, "charge", "shield", 35, "Charge up to {x} meters behind your shield, dealing {y}% damage to every enemy in your path and knocking them aside; the first one hit is stunned for {z} seconds. Your chance to block adds to its critical strike chance, and your block's damage reduction to its damage.", [[8,100,1],[9.5,125,1.25],[11,150,1.5],[12.5,175,1.75],[14,200,2]]],
	["shockwave", "Shockwave", "aoe", 10, "shockwave", "melee", 40, "Hammer the ground: a ring races out, dealing {x}% damage to all enemies within {y} meters and throwing them back. {z}-second cooldown.", [[180,4,10],[225,4.75,10],[270,5.5,10],[315,6.25,10],[360,7,10]]],
	["powerful_strike", "Powerful Strike", "single", 0, "strike", "melee", 25, "A powerful strike against a single enemy for {x}% damage.", [[200],[225],[250],[275],[300]]],
	["shield_bash", "Shield Bash", "single", 0, "bash", "shield", 35, "Bash the target with your shield for {x}% damage, stunning it for {y} seconds. Damage to the target breaks the stun. {z}-second cooldown. Bashing the same target again within 30 seconds stuns it for less time.", [[25,5,32],[30,6,29],[35,7,26],[40,8,23],[50,10,20]]],
	["vampiric_strike", "Vampiric Strike", "single", 5, "vampiric", "melee", 25, "Hit the target for {x}% damage and drain {y}% of its total health, healing you for {y}% of your own.", [[80,3],[90,5],[100,7],[110,9],[125,12]]],
	["shadow_strike", "Shadow Strike", "single", 5, "shadow", "melee", 25, "Deal {x}% damage, and {y}% more over 5 seconds. Refreshes Cursed Blade on the target.", [[25,100],[30,120],[40,150],[50,180],[70,220]]],
	["execute", "Execute", "single", 10, "execute", "melee", 45, "Deal {x}% damage to an enemy. Only usable on enemies below {y}% health.", [[200,20],[250,25],[300,30],[380,35],[450,40]]],
	["dash_attack", "Dash Attack", "passive", 0, "passive", "any", 0, "Enemies you dash through take {x}% damage and are pushed back, and the dash recharges {y} seconds sooner.", [[50,.4],[75,.8],[100,1.2],[150,1.6],[200,2]]],
	["shield_expertise", "Shield Expertise", "passive", 0, "passive", "any", 0, "+{x}% chance to block any attack with your shield (melee attacks, arrows and spells), and blocked attacks deal {y}% less damage, on top of the shield's own.", [[4,4],[8,8],[12,12],[16,16],[20,20]]],
	["endurance", "Endurance", "passive", 0, "passive", "any", 0, "Energy recovers {x}% faster.", [[10],[20],[30],[50],[75]]],
	["quick_strikes", "Quick Strikes", "passive", 5, "passive", "any", 0, "Normal attacks are {x}% faster.", [[20],[40],[70],[110],[170]]],
	["cursed_blade", "Cursed Blade", "passive", 5, "passive", "any", 0, "Your attacks make enemies take {x}% extra damage over 4 seconds. Stacks up to {y}×.", [[10,1],[15,2],[25,3],[40,5],[65,8]]],
	["offensive_rhythm", "Offensive Rhythm", "passive", 10, "passive", "any", 0, "Each hit on an enemy raises your damage by {x}%, stacking up to {y}×. Lasts {z} seconds, refreshed by every hit.", [[5,5,4],[10,6,5],[15,7,6],[20,8,9],[30,10,12]]],
	["defensive_rhythm", "Defensive Rhythm", "passive", 10, "passive", "any", 0, "Each hit you take lowers the damage you take by {x}%, stacking up to {y}×. Lasts {z} seconds, refreshed whenever you are hit.", [[3,2,4],[5,3,5],[7,4,6],[9,5,9],[12,6,12]]],
	["spiked_shield", "Spiked Shield", "passive", 10, "passive", "any", 0, "Attackers take {x}% of your normal attack damage whenever you block their attack.", [[10],[20],[35],[55],[80]]]]

# The ranger's, laid out as the warrior's. A cost of -1 is the rank's x (Rapid
# Fire grows cheaper); "bow", "dagger" or "bow_dagger" is the weapon the skill
# is made with (the ranger carries both, and takes up the one a skill needs).
const RANGER = [
	["rapid_fire", "Rapid Fire", "attack", 0, "rapid", "bow", -1, "Rapidly fires {y} arrows in a row. Costs {x} energy. Requires bow.", [[35,2],[32,2],[28,3],[24,3],[20,4]]],
	["power_shot", "Power Shot", "attack", 0, "power", "bow", 30, "A powerful shot that deals {x}% damage to its target and every enemy within 2.5 meters of it. Takes {y} seconds to aim and fire. Requires bow.", [[200,3],[240,2.6],[280,2.2],[330,1.7],[400,1]]],
	["flurry", "Flurry", "attack", 0, "flurry", "dagger", 25, "Rapidly stab an enemy {x} times in a row for {y}% damage each. Requires dagger.", [[2,100],[2,125],[3,150],[3,200],[4,275]]],
	["volley", "Volley", "attack", 5, "volley", "bow", 40, "Fire a volley of {x} arrows that land at random in the targeted area, each dealing {y}% damage. Requires bow.", [[15,80],[18,90],[21,100],[24,120],[30,150]]],
	["lightning_shot", "Lightning Shot", "attack", 5, "lightning", "bow", 35, "Fire an arrow charged with lightning: it deals {x}% damage and leaps between enemies within 10 meters of your target, up to {y} times, each leap dealing 25% less damage than the last. Requires bow.", [[100,1],[120,2],[150,3],[190,4],[250,5]]],
	["frenzy", "Frenzy", "attack", 5, "frenzy", "any", 0, "Attack {x}% faster for {y} seconds. 30-second cooldown.", [[10,6],[15,8],[20,10],[25,12],[35,15]]],
	["triple_slash", "Triple Slash", "attack", 10, "triple", "dagger", 25, "Slash three times with the dagger for {x}% damage each, hitting up to {y} nearby enemies around you as well. Requires dagger.", [[130,2],[150,2],[170,3],[200,3],[250,4]]],
	["slow_shot", "Slow Shot", "utility", 0, "slowshot", "bow", 20, "Shoot an arrow that slows its target by {x}% for {y} seconds. Requires bow.", [[30,3],[35,3.5],[45,4],[60,5],[75,6]]],
	["weakening_strike", "Weakening Strike", "utility", 0, "weaken", "bow_dagger", 15, "Attack the target and leave it taking {x}% more damage from critical strikes for 6 seconds. Stacks up to {y} times. With bow or dagger.", [[10,2],[11,2],[12,3],[13,4],[15,5]]],
	["hide_in_shadows", "Hide in Shadows", "utility", 5, "hide", "any", 20, "Hide in the shadows: enemies cannot see you, but you move {x}% slower. Attacking, being attacked or dashing ends it. Only out of combat.", [[50],[42],[34],[26],[15]]],
	["throw_sand", "Throw Sand", "utility", 5, "sand", "any", 40, "Throw sand in the eyes of an enemy within 3 meters: it wanders at random, unable to attack, for {x} seconds. Damage ends it. 45-second cooldown.", [[3],[5],[7],[9],[12]]],
	["tranquilizer", "Tranquilizer", "utility", 5, "tranq", "bow", 40, "Shoot an arrow that puts its target to sleep for {x} seconds. Damage wakes it. Requires bow. 45-second cooldown.", [[3],[5],[7],[9],[12]]],
	["vanish", "Vanish", "utility", 10, "vanish", "any", 40, "Hide in the shadows at once, even in combat: every enemy loses you. 60-second cooldown.", [[60]]],
	["surprise_attack", "Surprise Attack", "utility", 10, "ambush", "any", 50, "Stun an enemy for {x} seconds; it takes {y}% more damage while stunned. Only while hidden in shadows.", [[3,20],[3.5,30],[4,40],[4.5,50],[5,60]]],
	["swift_footed", "Swift Footed", "passive", 0, "passive", "any", 0, "Move {x}% faster.", [[5],[10],[18],[28],[40]]],
	["bow_specialization", "Bow Specialization", "passive", 0, "passive", "any", 0, "Bow attacks are {x}% more likely to strike critically, and their critical strikes deal {y}% extra damage.", [[4,25],[8,50],[12,75],[20,100],[30,150]]],
	["dagger_specialization", "Dagger Specialization", "passive", 0, "passive", "any", 0, "Dagger attacks are {x}% more likely to strike critically, and their critical strikes deal {y}% extra damage.", [[4,25],[8,50],[12,75],[20,100],[30,150]]],
	["element_of_surprise", "Element of Surprise", "passive", 5, "passive", "any", 0, "Deal {x}% more damage for {y} seconds after leaving the shadows.", [[40,4],[50,5],[60,6],[75,8],[100,10]]],
	["poisons", "Poisons", "passive", 5, "passive", "any", 0, "Your dagger and arrows carry a corrosive poison: {x}% extra damage over 5 seconds, stacking up to {y} times.", [[10,1],[15,2],[25,3],[40,5],[65,8]]],
	["penetrating_arrows", "Penetrating Arrows", "passive", 10, "passive", "any", 0, "Your arrows carry on through their targets, and may strike others behind them.", [[1]]]]

# The wizard's, laid out as the warrior's: each tree is an element, and a
# spell's percentages are of his spell baseline (Data.SPELL_SPAN by his
# Intelligence), as a warrior's are of his weapon's damage. The cost of a
# channelled spell (CHANNELS) is energy a second while it is held. Every ice
# spell chills what it hits (slowed 40% for 3 seconds) and ices the floor
# under it.
const WIZARD = [
	["ice_bolt", "Ice Bolt", "ice", 0, "icebolt", "any", 10, "Shoot a bolt of ice that strikes the first enemy in its path for {x}% ice damage, with a {y}% chance to freeze it in place for 3 seconds.", [[100,4],[120,8],[140,12],[160,16],[180,20]]],
	["freeze_floor", "Freeze Floor", "ice", 0, "freezefloor", "any", 10, "Channel a ray of frost that freezes the floor 2.5 meters across wherever you spray it, for 12 seconds: enemies on frozen floor move {x}% slower. Costs 10 energy a second while held.", [[40],[50],[60],[70],[80]]],
	["ice_spikes", "Ice Spikes", "ice", 5, "spikes", "any", 35, "Raise spikes of ice out of the floor across 4 meters where you aim, for {x}% ice damage.", [[100],[120],[140],[160],[180]]],
	["ice_prison", "Ice Prison", "ice", 5, "prison", "any", 45, "Freeze an enemy in a block of ice for {x} seconds: it can do nothing, and takes {y}% more damage.", [[2,20],[3,25],[4,35],[5,45],[6,60]]],
	["improved_chill", "Improved Chill", "ice", 5, "passive", "any", 0, "Your ice spells' chill slows {x}% more, and lasts {y} seconds longer.", [[10,1],[15,2],[20,3],[30,4],[40,5]]],
	["frost_blast", "Frost Blast", "ice", 10, "frostblast", "any", 20, "Channel frost from your hands 10 meters ahead, for {x}% frost damage a second to every enemy within 3 meters of the stream. Costs 20 energy a second while held.", [[70],[90],[110],[130],[150]]],
	["ice_storm", "Ice Storm", "ice", 10, "icestorm", "any", 40, "Frost swirls about you for {x} seconds, dealing {y}% frost damage a second to every enemy within 4 meters. Your frost spells deal double damage while it lasts, and you can cast nothing else. 60-second cooldown.", [[6,60],[8,70],[10,80],[12,90],[15,100]]],
	["fireball", "Fireball", "fire", 0, "fireball", "any", 10, "Hurl a ball of fire that bursts on the first enemy in its path for {x}% fire damage.", [[120],[160],[200],[240],[280]]],
	["blast_wave", "Blast Wave", "fire", 5, "blastwave", "any", 45, "A wave of flame bursts out 5 meters in every direction, for {x}% fire damage to every enemy it touches.", [[125],[145],[170],[200],[235]]],
	["frostburn", "Frostburn", "fire", 5, "passive", "any", 0, "Your fire spells deal {x}% more damage to chilled enemies, and to those standing on your ice.", [[50],[75],[100],[135],[175]]],
	["fire_tornado", "Fire Tornado", "fire", 10, "tornado", "any", 65, "Conjure a tornado of fire 4 meters across where you aim: for 8 seconds it deals {x}% fire damage a second to everything it touches, and each time it burns an enemy there is a {y}% chance to make that enemy a Lightning Rod, if you know that spell.", [[50,1],[60,2],[70,3],[85,4],[100,5]]],
	["blazing_speed", "Blazing Speed", "fire", 10, "blazing", "any", 50, "For {x} seconds you run 75% faster and your fire spells cost nothing. 60-second cooldown.", [[6]]],
	["pyromaniac", "Pyromaniac", "fire", 10, "passive", "any", 0, "Your fire spells deal double damage, but each burns you for 10% of the damage it deals, over 3 seconds.", [[100]]],
	["lightning_bolt", "Lightning Bolt", "lightning", 0, "bolt", "any", 10, "Hurl a bolt of lightning at the target for {x}% lightning damage.", [[100],[130],[160],[190],[220]]],
	["lightning_shield", "Lightning Shield", "lightning", 0, "lshield", "any", 50, "A shield of lightning about you absorbs up to {x} damage and deals {y}% lightning damage to whoever strikes you, for 60 seconds. Cast again, it replaces the shield you have. {z}-second cooldown.", [[50,20,60],[70,25,55],[90,30,50],[120,40,40],[150,50,30]]],
	["lightning_rod", "Lightning Rod", "lightning", 5, "rod", "any", 30, "Makes an enemy a Lightning Rod for 10 seconds: whenever it is hurt, a jolt of {x}% lightning damage leaps to the nearest enemy within 5 meters and on to up to 3 more, each leap 30% weaker; at most once every half second.", [[100],[125],[150],[175],[200]]],
	["ignition", "Ignition", "lightning", 5, "passive", "any", 0, "Your lightning spells have a {x}% chance to set off an explosion of {y}% fire damage within 2 meters of the target.", [[5,75],[10,100],[17,130],[25,160],[35,200]]],
	["system_shock", "System Shock", "lightning", 10, "shock", "any", 45, "Shocks an enemy, stunning it for {x} seconds; damage breaks the stun. 45-second cooldown.", [[5],[6],[8],[10],[12]]],
	["conductive_ice", "Conductive Ice", "lightning", 10, "passive", "any", 0, "Your lightning leaps between enemies standing on one continuous stretch of ice.", [[1]]]]
const CHANNELS = ["freezefloor","frostblast"]

static func all() -> Dictionary:
	if not definitions.is_empty(): return definitions
	for r in WARRIOR:
		definitions[r[0]] = {"id":r[0],"title":r[1],"class_id":"warrior","tree":r[2],"points":r[3],"unlock":1,"effect":r[4],"requirement":r[5],"tag":"" if r[4]=="passive" else "melee","cost":r[6],"description":r[7],"ranks":r[8],"max_rank":r[8].size()}
	for r in RANGER:
		definitions[r[0]] = {"id":r[0],"title":r[1],"class_id":"ranger","tree":r[2],"points":r[3],"unlock":1,"effect":r[4],"requirement":r[5],"tag":"" if r[4]=="passive" else "ranged","cost":r[6],"description":r[7],"ranks":r[8],"max_rank":r[8].size()}
	for r in WIZARD:
		definitions[r[0]] = {"id":r[0],"title":r[1],"class_id":"wizard","tree":r[2],"points":r[3],"unlock":1,"effect":r[4],"requirement":r[5],"tag":"" if r[4]=="passive" else "spell","cost":r[6],"description":r[7],"ranks":r[8],"max_rank":r[8].size(),"element":r[2]}
	return definitions

# A wizard's spell is of its tree's element: "ice", "fire" or "lightning".
static func element(id: String) -> String:
	return all()[id].get("element","")

static func channeled(id: String) -> bool:
	return all().has(id) and all()[id].effect in CHANNELS

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
		return s.description.format({"x":figure(v.x),"y":figure(v.y),"z":figure(v.z)})
	var amount = "%.0f%% damage" % (value(id,rank)*100) if not s.tag.is_empty() and s.effect!="passive" else ("%.1f" % value(id,rank)).trim_suffix(".0")
	return "%s (%s)" % [s.description,amount]

# A number as few figures as it needs: 15, 1.25, 0.5.
static func figure(amount: float) -> String:
	return String.num(snappedf(amount,.01)).trim_suffix(".0")

# Whether a skill can be made with a weapon of that kind in hand (its number
# in Data.WEAPONS). A "shield" skill needs a shield in the off hand besides:
# fits() has the whole of it.
static func compatible(id: String, weapon: int) -> bool:
	match all()[id].requirement:
		"melee","shield": return weapon in [0,1,3,6]
		"bow": return weapon==2
		"dagger": return weapon==5
		"bow_dagger": return weapon in [2,5]
	return true

# The kinds of weapon a skill is made with ([] for any).
const MADE_WITH = {"melee":["sword","mace","axe","spear"],"bow":["bow"],"dagger":["dagger"],"bow_dagger":["bow","dagger"]}
static func kinds(id: String) -> Array:
	return MADE_WITH.get(all()[id].requirement,[])

# Whether the hero can use the skill with what he holds now: a weapon of the
# kind it is made with in the main hand, or for a shield's skill a shield in
# the off hand.
static func fits(run: Dictionary, id: String) -> bool:
	var need: String = all()[id].requirement
	if need == "shield": return not Items.shield(run).is_empty()
	return not MADE_WITH.has(need) or Items.kind(run) in MADE_WITH[need]

# Whether the skill takes up the weapon it is made with from the bag: the
# ranger's do (he carries his bow and his dagger both). The warrior's need a
# melee weapon in hand already: with a bow he has only his normal attack.
static func takes_up(id: String) -> bool:
	return all()[id].class_id == "ranger" and not kinds(id).is_empty()

# Whether he could, taking up a weapon from his bag.
static func in_reach(run: Dictionary, id: String) -> bool:
	return fits(run,id) or (takes_up(id) and Items.bagged(run,kinds(id)) >= 0)

# The kind of weapon (its number in Data.WEAPONS) the skill would be made
# with: the one in hand if it serves, else the one he would take up.
static func made_with(run: Dictionary, id: String, in_hand: int) -> int:
	if fits(run,id) or not takes_up(id): return in_hand
	var found: int = Items.bagged(run,kinds(id))
	return in_hand if found < 0 else ["spear","sword","bow","axe","staff","dagger","mace"].find(Items.ALL[run.bag[found]].kind)

# What the skill costs at `rank` (a cost of -1 is the rank's x).
static func cost(id: String, rank: int) -> float:
	var s: Dictionary = all()[id]
	return float(s.cost) if s.cost>=0 else values(id,maxi(1,rank)).x

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
