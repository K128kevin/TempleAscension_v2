extends RefCounted
# Full anticipation, contact/release and recovery. Skill attack speed is
# separate from attributes and cooldowns, with a readability floor.
const NORMAL = [
	{"clip":"SpearStab","seconds":.64,"contacts":[.46]},
	{"clip":"SwordSwing","seconds":.84,"contacts":[.52]},
	# The ranger shoots with the archers' notch-and-shoot, at the same attack time.
	{"clip":"ArcherShot","seconds":.78,"contacts":[.78]},
	{"clip":"AxeChop","seconds":.94,"contacts":[.55]},
	{"clip":"Cast","seconds":.8,"contacts":[.5]}]
# The warrior's normal attack with the sword is not one swing repeated but
# three that run on into one another for as long as he keeps attacking: a cut
# down from the upper right to the lower left, a backhand cut down from the
# upper left to the lower right, and a thrust (tools/import_skills.py). Each
# takes the sword's normal time above and lands at the same moment of it.
# The first is wound up out of his stance (SWORD_OPENER); after the thrust the
# first cut follows on again. Each clip is its swing and then a recovery to
# the stance, which plays out only if he swings no more: SWORD_SWING_SHARE of
# the clip is the swing. A swing follows on from the last if it is begun
# within SWORD_FOLLOW (a share of the clip) of that swing's end: so far, each
# clip carries on into the next swing's own motion, so the next clip takes
# over from it mid-motion with nothing to blend.
const SWORD_CHAIN = ["SwordCut1","SwordCut2","SwordThrust"]
const SWORD_OPENER = "SwordOpen"
const SWORD_SWING_SHARE = 2.0/3.0
const SWORD_FOLLOW = .12
const SPECIAL = [
	{"clip":"SpearJab","seconds":.82,"contacts":[.52]},
	{"clip":"SwordSlash","seconds":.96,"contacts":[.52]},
	{"clip":"BowRapid","seconds":1.16,"contacts":[.30,.54,.78]},
	{"clip":"AxeWhirl","seconds":1.02,"contacts":[.62]},
	{"clip":"Cast","seconds":.8,"contacts":[.5]}]
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
