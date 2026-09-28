extends RefCounted
# Full anticipation, contact/release and recovery. Skill attack speed is
# separate from attributes and cooldowns, with a readability floor.
const NORMAL = [
	{"clip":"SpearStab","seconds":.64,"contacts":[.46]},
	{"clip":"SwordSwing","seconds":.84,"contacts":[.52]},
	{"clip":"BowShot","seconds":.78,"contacts":[.62]},
	{"clip":"AxeChop","seconds":.94,"contacts":[.55]},
	{"clip":"Cast","seconds":.8,"contacts":[.5]}]
const SPECIAL = [
	{"clip":"SpearJab","seconds":.82,"contacts":[.52]},
	{"clip":"SwordSlash","seconds":.96,"contacts":[.52]},
	{"clip":"BowRapid","seconds":1.16,"contacts":[.30,.54,.78]},
	{"clip":"AxeWhirl","seconds":1.02,"contacts":[.62]},
	{"clip":"Cast","seconds":.8,"contacts":[.5]}]
# The gladiator's single stepping spear thrust, contact at its full extension.
const LUNGE = {"clip":"SpearLunge","contacts":[.52]}
static func profile(weapon: int, special: bool, attack_speed_percent: float, minimum_duration: float = 0.0) -> Dictionary:
	var result: Dictionary = (SPECIAL if special else NORMAL)[weapon].duplicate(true)
	result.duration = maxf(minimum_duration,result.seconds * maxf(.65,1.0/(1.0+attack_speed_percent*.01)))
	result.times = []
	for fraction in result.contacts: result.times.append(fraction*result.duration)
	return result
