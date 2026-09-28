extends RefCounted
const Data = preload("res://scripts/data.gd")
static var directory = "user://"

static func migrate(d: Dictionary) -> Dictionary:
	if int(d.get("version",0))>=5: return d
	if int(d.get("version",0))==4:
		var updated = d.duplicate(true)
		updated.version = 5
		updated.erase("flasks")
		updated.erase("flask_cooldown")
		updated.heal_cooldown = 0.0
		return updated
	if int(d.get("version",0))==3:
		if not d.get("hotbar") is Array or d.hotbar.size()!=5: return {}
		var updated = d.duplicate(true)
		updated.version = 4
		updated.hotbar = updated.hotbar.slice(0,3)
		updated.drops = updated.drops.filter(func(drop): return drop is Dictionary and drop.get("value",-1) not in [2,3])
		return migrate(updated)
	if not d.has("stats") or not d.stats is Array or d.stats.size()!=4: return {}
	var old_floor = clampi(int(d.get("floor",0)),0,5)
	var fresh = Data.new_run("ranger" if int(d.get("weapon",0))==2 else "warrior")
	for key in ["floor","weapon","difficulty","dead","drops","deaths","seed","position","completed"]:
		if d.has(key): fresh[key] = d[key]
	if int(d.get("version",0))<2: fresh.position = [0,9]
	if d.get("owned",[]) is Array and d.owned.size()==4: fresh.owned = d.owned.duplicate()+[false]
	var previous_points = float(d.get("points",0))
	for stat in d.stats:
		if not (stat is int or stat is float) or stat<0: return {}
		previous_points += stat
	var level = clampi(maxi(Data.ENEMY_LEVELS[old_floor],1+ceili(previous_points/3.0)),1,30)
	Data.gain_xp(fresh,Data.xp_at_level(level))
	fresh.xp_claimed = fresh.dead.duplicate()
	fresh.drops = fresh.drops.filter(func(drop): return drop is Dictionary and drop.get("kind","")=="weapon" and drop.get("value",-1) not in [2,3])
	fresh.health = 100.0
	fresh.energy = 100.0
	fresh["migration_notice"] = true
	return fresh

static func valid(d) -> bool:
	if not d is Dictionary: return false
	if int(d.get("version",0))<5:
		var converted = migrate(d)
		return not converted.is_empty() and valid(converted)
	for key in Data.new_run():
		if not d.has(key): return false
	for key in ["version","floor","weapon","difficulty","level","xp","points","skill_points","deaths","seed","health","energy","heal_cooldown"]:
		if not (d[key] is int or d[key] is float) or not is_finite(float(d[key])) or d[key]<0: return false
	for key in ["version","floor","weapon","difficulty","level","xp","points","skill_points","deaths"]:
		if d[key]!=int(d[key]): return false
	if not d.class_id in Data.CLASSES: return false
	if not d.stats is Array or d.stats.size()!=5 or not d.owned is Array or d.owned.size()!=5: return false
	if not d.position is Array or d.position.size()!=2: return false
	for value in d.position:
		if not (value is int or value is float) or not is_finite(float(value)): return false
	for value in d.owned:
		if not value is bool: return false
	if int(d.floor)<0 or int(d.floor)>5 or int(d.difficulty)<0 or int(d.difficulty)>2: return false
	if int(d.weapon)<0 or int(d.weapon)>4 or not d.owned[int(d.weapon)]: return false
	if not d.level is float and not d.level is int: return false
	if d.level<1 or d.level>30 or d.level!=int(d.level): return false
	if d.xp<Data.xp_at_level(int(d.level)) or d.xp>Data.xp_at_level(30): return false
	if d.level<30 and d.xp>=Data.xp_at_level(int(d.level)+1): return false
	var spent = 0
	for stat in d.stats:
		if not (stat is float or stat is int) or stat<5 or stat>92 or stat!=int(stat): return false
		spent += int(stat)-5
	if d.points<0 or spent+d.points!=(d.level-1)*3: return false
	if not d.skills is Dictionary or not d.hotbar is Array or d.hotbar.size()!=3: return false
	var ranks = 0
	for id in d.skills:
		if not Data.Skills.all().has(id): return false
		var skill: Dictionary = Data.Skills.all()[id]
		if not (d.skills[id] is int or d.skills[id] is float) or d.skills[id]!=int(d.skills[id]): return false
		var rank = int(d.skills[id])
		if skill.class_id!=d.class_id or rank<1 or rank>Data.Skills.rank_cap(id,int(d.level)): return false
		ranks += rank
	if d.skill_points<0 or ranks+d.skill_points!=d.level: return false
	var assigned = []
	for id in d.hotbar:
		if not id is String: return false
		if not id.is_empty():
			if id in assigned: return false
			assigned.append(id)
		if id!="" and (not d.skills.has(id) or Data.Skills.all()[id].effect=="passive"): return false
	if not (d.dead is Array and d.gems is Array and d.drops is Array and d.xp_claimed is Array): return false
	for drop in d.drops:
		if not drop is Dictionary or drop.get("kind","")!="weapon" or not drop.get("id",0) is String: return false
		if not (drop.get("value") is int or drop.get("value") is float) or drop.value<0 or drop.value>4: return false
		if not drop.get("position") is Array or drop.position.size()!=2: return false
	return true

static func load_run() -> Dictionary:
	for file in ["run.json","run.backup.json"]:
		var path = directory.path_join(file)
		if not FileAccess.file_exists(path): continue
		var parser = JSON.new()
		if parser.parse(FileAccess.get_file_as_string(path)) != OK: continue
		var parsed = parser.data
		if valid(parsed):
			parsed = migrate(parsed)
			parsed.erase("seconds")
			for key in ["floor","weapon","difficulty","points","deaths","seed","level","xp","skill_points"]: parsed[key] = int(parsed[key])
			for i in parsed.stats.size(): parsed.stats[i] = int(parsed.stats[i])
			for id in parsed.skills: parsed.skills[id] = int(parsed.skills[id])
			return parsed
	return {}

static func write(run: Dictionary) -> bool:
	run.erase("seconds")
	DirAccess.make_dir_recursive_absolute(directory)
	var file = FileAccess.open(directory.path_join("run.tmp"),FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(run))
	file.flush()
	file.close()
	var current = directory.path_join("run.json")
	var parser = JSON.new()
	if FileAccess.file_exists(current) and parser.parse(FileAccess.get_file_as_string(current))==OK and valid(parser.data):
		var backup_data: Dictionary = parser.data
		backup_data.erase("seconds")
		var backup = FileAccess.open(directory.path_join("run.backup.json"),FileAccess.WRITE)
		if backup:
			backup.store_string(JSON.stringify(backup_data))
			backup.close()
	return DirAccess.rename_absolute(directory.path_join("run.tmp"),current)==OK
