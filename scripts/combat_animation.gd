extends RefCounted
# Full anticipation, contact/release and recovery. Skill attack speed is
# separate from attributes and cooldowns, with a readability floor.
const NORMAL = [
	{"clip":"SpearStab","seconds":.64,"contacts":[.46]},
	{"clip":"SwordSwing","seconds":.84,"contacts":[.52]},
	# The ranger shoots with the archers' notch-and-shoot, at the same attack time.
	{"clip":"ArcherShot","seconds":.78,"contacts":[.78]},
	{"clip":"AxeChop","seconds":.94,"contacts":[.55]},
	{"clip":"Cast","seconds":.8,"contacts":[.5]},
	# The ranger's dagger: quick, a stab and a slash by turns (DAGGER_ATTACKS).
	{"clip":"DaggerStab","seconds":.5,"contacts":[.45]}]
const DAGGER_ATTACKS = ["DaggerStab","DaggerSlash"]
# The parts of each dagger clip (shares of it) through which the blade leaves
# a wake of air behind it, as the sword's cuts do.
const DAGGER_WAKES = {"DaggerSlash":[[.3,.62]],"SkillTripleSlash":[[.14,.3],[.42,.58],[.7,.86]]}
# The warrior's normal attack with the sword is not one swing repeated but
# three that run on into one another for as long as he keeps attacking: a cut
# down from the upper right to the lower left, a backhand cut down from the
# upper left to the lower right, and a thrust (tools/import_skills.py). Each
# takes the sword's normal time above and lands at the same moment of it.
# He walks into his target as he swings, each swing struck on a step of the
# rear foot past the front: the feet alternate, so each of the three has a
# clip stepping with either foot (its name with SWORD_FEET's R or L added).
# The first is wound up out of his stance (SWORD_OPENER), stepping with the
# right; after the thrust the first cut follows on again. Each clip is its swing and then a recovery to
# the stance, which plays out only if he swings no more: SWORD_SWING_SHARE of
# the clip is the swing. A swing follows on from the last if it is begun
# within SWORD_FOLLOW (a share of the clip) of that swing's end: so far, each
# clip carries on into the next swing's own motion, so the next clip takes
# over from it mid-motion with nothing to blend.
const SWORD_CHAIN = ["SwordCut1","SwordCut2","SwordThrust"]
# An axe is not thrust: with a one-handed axe he cuts down one way and then
# the other, back and forth, an X drawn in the air. (The first cut is keyed to
# follow the thrust, so here it is faded into from the backhand's end.)
const AXE_CHAIN = ["SwordCut1","SwordCut2"]
# The chain of swings a one-handed weapon of `kind` ("sword", "axe"...) is swung in.
static func chain(kind: String) -> Array:
	return AXE_CHAIN if kind == "axe" else SWORD_CHAIN
const SWORD_OPENER = "SwordOpen"
const SWORD_FEET = ["R","L"]
const SWORD_SWING_SHARE = 2.0/3.0
const SWORD_FOLLOW = .12
# The part of each cut (a share of the swing, from the blade starting down to
# the end of its follow-through) through which the blade leaves a wake of
# disturbed air behind it (scripts/sword_trail.gd). The thrust leaves none.
const SWORD_WAKE = [.43,.66]
static func sword_cuts(clip: String) -> bool:
	return clip == SWORD_OPENER or clip.begins_with("SwordCut")
# Flurry's stabs, one after another (tools/import_ranger.py keys the same
# times): the clip's length for `count` of them, and when each lands (shares
# of it).
const FLURRY_LEAD = .18
const FLURRY_STAB = .22
const FLURRY_END = .3
static func flurry_seconds(count: int) -> float:
	return FLURRY_LEAD+FLURRY_STAB*(count-1)+FLURRY_END
static func flurry_contacts(count: int) -> Array:
	var out: Array = []
	for i in count: out.append((FLURRY_LEAD+FLURRY_STAB*i)/flurry_seconds(count))
	return out
# How a hero swings each family of weapon (Items.family): the normal attack's
# clips (played by turns), how long a swing takes and when in it the blow
# lands, how far it reaches (centre to centre), and the clips of the
# warrior's skills, each named for the family ("SkillCleave", "HeavyCleave",
# "PikeCleave"). One-handed swords, maces and axes are swung as the sword is
# (its chain of three, above); two-handed swords, axes and mauls with the
# whole body (tools/import_heavy.py); the spear is thrust from both hands
# (tools/import_pike.py). A weapon in each hand strikes with each by turns,
# the left's blows the right's mirrored (Visual.MIRRORED); bare fists jab.
const FAMILIES = {
	"one":{"clips":[SWORD_OPENER],"off":"OffCut","seconds":.84,"contacts":[.52],"reach":1.9,"prefix":"Skill"},
	"heavy":{"clips":["HeavySwing1"],"fallback":"AxeChop","seconds":1.1,"contacts":[.5],"reach":2.3,"prefix":"Heavy"},
	"pike":{"clips":["PikeThrust1","PikeThrust2"],"fallback":"SpearStab","seconds":.8,"contacts":[.5],"reach":2.9,"prefix":"Pike"},
	"dagger":{"clips":["DaggerStab","DaggerSlash"],"off":"OffStab","seconds":.5,"contacts":[.45],"reach":1.9,"prefix":"Skill"},
	"fist":{"clips":["DaggerStab","OffStab"],"seconds":.5,"contacts":[.45],"reach":1.6,"prefix":"Skill"},
	"bow":{"clips":["ArcherShot"],"seconds":.78,"contacts":[.78],"reach":12.5,"prefix":"Skill"},
	"staff":{"clips":["Cast"],"seconds":.8,"contacts":[.5],"reach":12.5,"prefix":"Skill"}}
const SKILL_CLIPS = {"cleave":"Cleave","strike":"Strike","bash":"Bash","execute":"Execute","slam":"Slam","shockwave":"Shockwave","cry":"Cry","charge":"Charge","leap":"Leap"}
static func family(swung: String) -> Dictionary:
	return FAMILIES.get(swung,FAMILIES.one)
static func reach(swung: String) -> float:
	return family(swung).reach
# A family's normal attack as it is timed at `attack_speed_percent` (as
# profile(), below): its "duration", and the "times" in it its blows land.
# `seconds` is the weapon's own time for a blow (its attacks a second:
# scripts/items.gd), in place of the family's.
static func timed(swung: String, attack_speed_percent: float, minimum_duration: float = 0.0, speed_floor: float = .65, seconds: float = -1.0) -> Dictionary:
	var result: Dictionary = family(swung).duplicate(true)
	result.clip = result.clips[0]
	if seconds > 0.0: result.seconds = seconds
	result.duration = maxf(minimum_duration,result.seconds*maxf(speed_floor,1.0/(1.0+attack_speed_percent*.01)))
	result.times = []
	for fraction in result.contacts: result.times.append(fraction*result.duration)
	return result
# The clip of one of the warrior's skills (by its effect) with that family of weapon.
static func skill_clip(swung: String, effect: String) -> String:
	return family(swung).prefix+SKILL_CLIPS.get(effect,"")
const SPECIAL = [
	{"clip":"SpearJab","seconds":.82,"contacts":[.52]},
	{"clip":"SwordSlash","seconds":.96,"contacts":[.52]},
	{"clip":"BowRapid","seconds":1.16,"contacts":[.30,.54,.78]},
	{"clip":"AxeWhirl","seconds":1.02,"contacts":[.62]},
	{"clip":"Cast","seconds":.8,"contacts":[.5]},
	{"clip":"DaggerStab","seconds":.5,"contacts":[.45]}]
# The statue archer's notch-and-shoot, released at full draw.
const ARCHER_SHOT = {"clip":"ArcherShot","contacts":[.78]}
# The Oracle's fireball cast: weave, draw the staff back, swing and release.
const ORACLE_CAST = {"clip":"OracleCast","contacts":[.8]}
# The centurion's stepping, full-body thrust past its tower shield.
const SHIELD_STAB = {"clip":"ShieldStab","contacts":[.5]}
# The Lion Guardian's swipe: it rears, a forepaw cocked wide, and rakes it across.
const LION_SWIPE = {"clip":"Attack","contacts":[.5]}
# `speed_floor` is the readability floor: the shortest share of the clip's
# normal time that attack speed can bring it to. Melee swings pass 0 and are
# held only to `minimum_duration`.
static func profile(weapon: int, special: bool, attack_speed_percent: float, minimum_duration: float = 0.0, speed_floor: float = .65) -> Dictionary:
	var result: Dictionary = (SPECIAL if special else NORMAL)[weapon].duplicate(true)
	result.duration = maxf(minimum_duration,result.seconds * maxf(speed_floor,1.0/(1.0+attack_speed_percent*.01)))
	result.times = []
	for fraction in result.contacts: result.times.append(fraction*result.duration)
	return result
