extends RefCounted
const Data = preload("res://scripts/data.gd")
const Items = preload("res://scripts/items.gd")
static var directory = "user://"

static func migrate(d: Dictionary) -> Dictionary:
	if int(d.get("version",0))>=14: return d
	if int(d.get("version",0))==13:
		# Easy, Moderate and Hard became Normal and Hard: Moderate is Normal.
		var updated = d.duplicate(true)
		updated.version = 14
		updated.difficulty = 1 if int(updated.get("difficulty",0))>=2 else 0
		return updated
	if int(d.get("version",0))==12:
		# The hotbar gained an LMB slot (Data.LEFT_SLOT), the wizard's.
		if not d.get("hotbar") is Array or d.hotbar.size()!=5: return {}
		var updated = d.duplicate(true)
		updated.version = 13
		updated.hotbar = updated.hotbar+[""]
		return migrate(updated)
	if int(d.get("version",0))==11:
		# The wizard's spells were replaced (ice, fire and lightning): a
		# wizard's skill points are refunded.
		var updated = d.duplicate(true)
		updated.version = 12
		if updated.get("class_id","")=="wizard":
			updated.skills = {}
			updated.skill_points = int(updated.get("level",1))
			updated.hotbar = ["","","","",""]
			updated["migration_notice"] = true
		return migrate(updated)
	if int(d.get("version",0))==10:
		# Items: what was a list of weapons owned and one in hand became
		# equipment and a bag. A character from before is given its class's
		# starting gear, with any other weapon it owned and can use in its bag.
		if not d.get("class_id","") in Data.CLASSES: return {}
		var updated = d.duplicate(true)
		updated.version = 11
		Items.outfit(updated,updated.class_id)
		var had: Array = d.get("owned",[]) if d.get("owned") is Array else []
		for i in mini(had.size(),6):
			var plain: String = Items.PLAIN.get(Data.WEAPONS[i],"")
			if had[i] is bool and had[i] and not plain.is_empty() and Items.usable(updated.class_id,plain) and not plain in updated.equipment.values() and not plain in updated.bag: Items.stow(updated,plain)
		for key in ["owned","weapon","shield"]: updated.erase(key)
		updated.drops = []
		return migrate(updated)
	if int(d.get("version",0))==9:
		# The temple became three floors and a summit, with two dungeons to
		# fight through before it. A character from before keeps the temple
		# open, and stands at the start of the floor his old one became.
		var updated = d.duplicate(true)
		updated.version = 10
		updated.cleared = Data.DUNGEONS.duplicate()
		var old_floor = clampi(int(d.get("floor",0)),0,5)
		updated.floor = [0,1,1,2,2,3][old_floor]
		if updated.get("place","temple")=="temple":
			updated.dead = []
			updated.drops = []
			updated.position = [0,9]
		elif updated.floor != old_floor: updated.dead = []
		return migrate(updated)
	if int(d.get("version",0))==8:
		# The hotbar grew from RMB, 1 and 2 to RMB and 1 to 4.
		if not d.get("hotbar") is Array or d.hotbar.size()!=3: return {}
		var updated = d.duplicate(true)
		updated.version = 9
		updated.hotbar = updated.hotbar+["",""]
		return migrate(updated)
	if int(d.get("version",0))==7:
		# The dagger joined the weapons (the ranger carries one with his bow),
		# and the ranger's skills were replaced: his are refunded.
		var updated = d.duplicate(true)
		updated.version = 8
		if updated.get("owned") is Array and updated.owned.size()==5: updated.owned.append(updated.get("class_id","")=="ranger")
		if updated.get("class_id","")=="ranger":
			updated.skills = {}
			updated.skill_points = int(updated.get("level",1))
			updated.hotbar = ["","",""]
			updated["migration_notice"] = true
		return migrate(updated)
	if int(d.get("version",0))==6:
		# Saves from before the outdoor world were all made inside the temple.
		var updated = d.duplicate(true)
		updated.version = 7
		updated.place = "temple"
		return migrate(updated)
	if int(d.get("version",0))==5:
		# The level cap fell (to 20 then; it is 25 now), each level now grants five attribute points,
		# and the skill trees changed: everything spent is refunded.
		for key in ["level","xp"]:
			if not (d.get(key) is int or d.get(key) is float) or not is_finite(float(d[key])) or d[key]<0: return {}
		var updated = d.duplicate(true)
		updated.version = 6
		updated.level = clampi(int(d.level),1,Data.MAX_LEVEL)
		updated.xp = clampi(int(d.xp),Data.xp_at_level(updated.level),Data.xp_at_level(Data.MAX_LEVEL) if updated.level==Data.MAX_LEVEL else Data.xp_at_level(updated.level+1)-1)
		updated.stats = [5,5,5,5,5]
		updated.points = (updated.level-1)*Data.STAT_POINTS
		updated.skills = {}
		updated.skill_points = updated.level
		updated.hotbar = ["","",""]
		updated["migration_notice"] = true
		return migrate(updated)
	if int(d.get("version",0))==4:
		var updated = d.duplicate(true)
		updated.version = 5
		updated.erase("flasks")
		updated.erase("flask_cooldown")
		updated.heal_cooldown = 0.0
		return migrate(updated)
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
	for key in ["floor","difficulty","dead","deaths","seed","position","completed"]:
		if d.has(key): fresh[key] = d[key]
	if int(d.get("version",0))<2: fresh.position = [0,9]
	var previous_points = float(d.get("points",0))
	for stat in d.stats:
		if not (stat is int or stat is float) or stat<0: return {}
		previous_points += stat
	var level = clampi(maxi([1,4,8,12,18,22][old_floor],1+ceili(previous_points/3.0)),1,Data.MAX_LEVEL)
	Data.gain_xp(fresh,Data.xp_at_level(level))
	fresh.xp_claimed = fresh.dead.duplicate()
	# (The temple is three floors now; the dungeons before it are behind him.)
	fresh.floor = [0,1,1,2,2,3][old_floor]
	fresh.cleared = Data.DUNGEONS.duplicate()
	if fresh.floor != old_floor: fresh.dead = []
	fresh.health = 100.0
	fresh.energy = 100.0
	fresh["migration_notice"] = true
	# (new_run made it as the game is now; its old weapons are its class's.)
	return fresh

static func valid(d) -> bool:
	if not d is Dictionary: return false
	if int(d.get("version",0))<14:
		var converted = migrate(d)
		return not converted.is_empty() and valid(converted)
	for key in Data.new_run():
		if not d.has(key): return false
	for key in ["version","floor","difficulty","level","xp","points","skill_points","deaths","seed","health","energy","heal_cooldown"]:
		if not (d[key] is int or d[key] is float) or not is_finite(float(d[key])) or d[key]<0: return false
	for key in ["version","floor","difficulty","level","xp","points","skill_points","deaths"]:
		if d[key]!=int(d[key]): return false
	if not d.class_id in Data.CLASSES or not d.place in Data.PLACES: return false
	if not d.stats is Array or d.stats.size()!=5: return false
	# What is worn and held: every slot there, each empty or holding an item
	# that fits it and that the class can use; a two-handed weapon alone.
	if not d.equipment is Dictionary or d.equipment.size()!=Items.SLOTS.size() or not d.bag is Array or d.bag.size()!=Items.BAG_SIZE: return false
	for slot in Items.SLOTS:
		if not d.equipment.get(slot) is String: return false
		if not d.equipment[slot].is_empty() and not Items.misfit(d,d.equipment[slot],slot).is_empty(): return false
	if Items.two_handed(d.equipment.main) and not d.equipment.off.is_empty(): return false
	for id in d.bag:
		if not id is String or not (id.is_empty() or Items.exists(id)): return false
	if not d.position is Array or d.position.size()!=2: return false
	for value in d.position:
		if not (value is int or value is float) or not is_finite(float(value)): return false
	if int(d.floor)<0 or int(d.floor)>=Data.AREAS[d.place if Data.AREAS.has(d.place) else "temple"].size() or int(d.difficulty)<0 or int(d.difficulty)>=Data.DIFFICULTIES.size(): return false
	if not d.cleared is Array: return false
	for place in d.cleared:
		if not place in Data.DUNGEONS: return false
	if not d.level is float and not d.level is int: return false
	if d.level<1 or d.level>Data.MAX_LEVEL or d.level!=int(d.level): return false
	if d.xp<Data.xp_at_level(int(d.level)) or d.xp>Data.xp_at_level(Data.MAX_LEVEL): return false
	if d.level<Data.MAX_LEVEL and d.xp>=Data.xp_at_level(int(d.level)+1): return false
	var spent = 0
	for stat in d.stats:
		if not (stat is float or stat is int) or stat<5 or stat>5+(Data.MAX_LEVEL-1)*Data.STAT_POINTS or stat!=int(stat): return false
		spent += int(stat)-5
	if d.points<0 or spent+d.points!=(d.level-1)*Data.STAT_POINTS: return false
	if not d.skills is Dictionary or not d.hotbar is Array or d.hotbar.size()!=6: return false
	if not Data.casts_left(d) and d.hotbar[Data.LEFT_SLOT]!="": return false
	var ranks = 0
	for id in d.skills:
		if not Data.Skills.all().has(id): return false
		var skill: Dictionary = Data.Skills.all()[id]
		if not (d.skills[id] is int or d.skills[id] is float) or d.skills[id]!=int(d.skills[id]): return false
		var rank = int(d.skills[id])
		if skill.class_id!=d.class_id or rank<1 or rank>Data.Skills.rank_cap(id,int(d.level)): return false
		ranks += rank
	if d.skill_points<0 or ranks+d.skill_points!=d.level or not Data.Skills.reachable(d.skills): return false
	var assigned = []
	for id in d.hotbar:
		if not id is String: return false
		if not id.is_empty():
			if id in assigned: return false
			assigned.append(id)
		if id!="" and (not d.skills.has(id) or Data.Skills.all()[id].effect=="passive"): return false
	if not (d.dead is Array and d.gems is Array and d.drops is Array and d.xp_claimed is Array): return false
	for drop in d.drops:
		if not drop is Dictionary or not drop.get("item") is String or not Items.exists(drop.item): return false
		if not drop.get("position") is Array or drop.position.size()!=2: return false
	return true

# The player's own settings, kept apart from the run (settings.cfg): whether
# the game fills the screen.
static func setting(key: String, default):
	var config = ConfigFile.new()
	if config.load(directory.path_join("settings.cfg")) != OK: return default
	return config.get_value("settings",key,default)

static func keep_setting(key: String, value) -> void:
	var config = ConfigFile.new()
	var path = directory.path_join("settings.cfg")
	config.load(path)
	config.set_value("settings",key,value)
	DirAccess.make_dir_recursive_absolute(directory)
	config.save(path)

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
			for key in ["floor","difficulty","points","deaths","seed","level","xp","skill_points"]: parsed[key] = int(parsed[key])
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
