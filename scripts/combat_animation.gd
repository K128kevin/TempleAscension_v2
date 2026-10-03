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
