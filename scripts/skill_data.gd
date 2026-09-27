extends RefCounted
## The proposed roster in v2/docs/PLAN.md. Rank changes one primary value.
static var definitions: Dictionary = {}

static func all() -> Dictionary:
	if not definitions.is_empty(): return definitions
	# id, title, class, unlock, behavior, requirement, scaling, cost, cooldown,
	# first-rank value, increment, radius, duration, description
	var rows = [
		["cleave","Cleave","warrior",1,"cone","melee","melee",15,3,1.4,.2,3,0,"Sweep enemies in front."],
		["guard","Guard","warrior",1,"guard","any","",15,10,2,.5,0,0,"Reduce incoming damage by 60% for the listed seconds."],
		["shield_bash","Shield Bash","warrior",4,"bash","shield","melee",18,7,1.2,.2,2.5,1.5,"Strike and stagger the nearest foe. Bosses build stagger."],
		["lunge","Lunge","warrior",4,"lunge","melee","melee",20,6,1.5,.2,6,0,"Rush toward a target and strike; walls stop movement."],
		["whirlwind","Whirlwind","warrior",8,"whirlwind","melee","melee",28,10,.6,.1,3,3,"Deal damage each second while moving through nearby foes."],
		["war_cry","War Cry","warrior",8,"war_cry","any","",25,18,6,1,0,0,"Gain 25% damage for the listed seconds."],
		["ground_slam","Ground Slam","warrior",12,"line","melee","melee",25,9,1.8,.25,7,0,"Send a wide shockwave through foes ahead."],
		["execution","Execution","warrior",18,"execution","melee","melee",30,12,2.5,.4,3,0,"A single strike; double damage against foes below 35% health."],
		["endurance","Endurance","warrior",1,"passive","any","",0,0,10,10,0,0,"Additional maximum health."],
		["weapon_training","Weapon Training","warrior",4,"passive","any","melee",0,0,5,5,0,0,"Percent additional melee damage."],
		["bulwark","Bulwark","warrior",12,"passive","any","",0,0,5,5,0,0,"Percent incoming damage reduction."],
		["battle_rhythm","Battle Rhythm","warrior",18,"passive","any","",0,0,4,4,0,0,"Energy restored on a rewarded kill."],
		["power_shot","Power Shot","ranger",1,"shot","bow","ranged",15,3,1.8,.25,13,0,"Draw and release a powerful arrow."],
		["snare","Snare","ranger",1,"snare","any","",15,8,3,1,2,0,"Place a trap that slows nearby enemies by 60%; value is duration."],
		["multishot","Multishot","ranger",4,"multishot","bow","ranged",22,6,.9,.15,13,0,"Fire three arrows in a spread."],
		["retreating_shot","Retreating Shot","ranger",4,"retreat","bow","ranged",20,7,1.2,.2,13,0,"Fire while stepping back from the target."],
		["piercing_arrow","Piercing Arrow","ranger",8,"pierce","bow","ranged",22,6,1.5,.2,14,0,"An arrow that passes through enemies."],
		["explosive_trap","Explosive Trap","ranger",8,"trap","any","ranged",25,9,2,.3,3,1,"Arm a trap after one second; it bursts when a foe enters."],
		["marked_prey","Marked Prey","ranger",12,"mark","any","",15,10,6,1,13,0,"Mark one foe to take 20% more damage; value is duration."],
		["rain_of_arrows","Rain of Arrows","ranger",18,"rain","bow","ranged",35,15,.8,.15,4,4,"Four volleys strike the selected area."],
		["steady_aim","Steady Aim","ranger",1,"passive","any","ranged",0,0,5,5,0,0,"Percent additional ranged damage."],
		["quick_draw","Quick Draw","ranger",4,"passive","any","",0,0,6,6,0,0,"Percent faster bow attack animations; cooldowns are separate."],
		["trapcraft","Trapcraft","ranger",12,"passive","any","",0,0,20,20,0,0,"Percent longer snare and trap duration."],
		["predator","Predator","ranger",18,"passive","any","",0,0,10,10,0,0,"Percent additional damage against marked prey."],
		["firebolt","Firebolt","wizard",1,"firebolt","staff","spell",12,1.5,1.5,.25,13,0,"Launch a bolt of fire."],
		["frost_nova","Frost Nova","wizard",1,"nova","staff","spell",20,8,1,.2,3.5,3,"Damage nearby foes and slow them by 60%."],
		["arcane_lance","Arcane Lance","wizard",4,"lance","staff","spell",22,5,1.6,.25,14,0,"An arcane projectile that pierces enemies."],
		["barrier","Barrier","wizard",4,"barrier","staff","",22,14,35,15,0,8,"Absorb the listed damage for up to eight seconds."],
		["chain_lightning","Chain Lightning","wizard",8,"chain","staff","spell",28,8,1.4,.2,12,0,"Lightning jumps to up to four nearby enemies."],
		["blink","Blink","wizard",8,"blink","staff","",18,7,5,.5,0,0,"Teleport the listed distance, stopping before walls."],
		["blizzard","Blizzard","wizard",12,"blizzard","staff","spell",32,13,.6,.1,4,5,"Five pulses of frost damage and slowing in the target area."],
		["meteor","Meteor","wizard",18,"meteor","staff","spell",40,16,3.5,.5,4,1.2,"Call a fiery impact after a visible warning."],
		["attunement","Attunement","wizard",1,"passive","any","",0,0,.8,.8,0,0,"Additional energy regenerated per second."],
		["efficient_casting","Efficient Casting","wizard",4,"passive","any","",0,0,8,8,0,0,"Percent less energy spent on spell skills."],
		["elemental_mastery","Elemental Mastery","wizard",12,"passive","any","spell",0,0,5,5,0,0,"Percent additional spell damage."],
		["arcane_reserve","Arcane Reserve","wizard",18,"passive","any","",0,0,10,10,0,0,"Additional maximum energy."]]
	for r in rows:
		definitions[r[0]] = {"id":r[0],"title":r[1],"class_id":r[2],"unlock":r[3],"effect":r[4],"requirement":r[5],"tag":r[6],"cost":r[7],"cooldown":r[8],"base":r[9],"step":r[10],"radius":r[11],"duration":r[12],"description":r[13],"max_rank":3 if r[4]=="passive" else 5}
	return definitions

static func rank_cap(id: String, level: int) -> int:
	var s: Dictionary = all()[id]
	return 0 if level<s.unlock else mini(s.max_rank,1+int((level-s.unlock)/3))

static func value(id: String, rank: int) -> float:
	var s: Dictionary = all()[id]
	return 0.0 if rank<=0 else float(s.base+s.step*(rank-1))

static func compatible(id: String, weapon: int) -> bool:
	match all()[id].requirement:
		"melee": return weapon in [0,1,3]
		"shield": return weapon==1
		"bow": return weapon==2
		"staff": return weapon==4
	return true

static func learn(run: Dictionary, id: String) -> bool:
	if not all().has(id): return false
	var s: Dictionary = all()[id]
	var rank = int(run.skills.get(id,0))
	if s.class_id!=run.class_id or run.skill_points<=0 or rank>=rank_cap(id,int(run.level)): return false
	run.skills[id] = rank+1
	run.skill_points -= 1
	return true
