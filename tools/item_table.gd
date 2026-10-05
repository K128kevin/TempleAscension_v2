extends SceneTree
## Prints the tables of docs/ITEMS.md from scripts/items.gd: every item, and
## each droppable item's chance to fall from each kind of enemy, by class.
##
##   Godot --headless --path . --script tools/item_table.gd
const Items = preload("res://scripts/items.gd")
const ENEMIES = [["bandit","Bandit"],["bandit_archer","Bandit Archer"],["gladiator","Gladiator"],["archer","Archer"],["lion","Lion Guardian"],["wizard","Oracle"],["centurion","Centurion"],["boss","The Crowned Statue"]]
func _initialize():
	var out: Array = []
	out.append("### Starting equipment\n")
	for class_id in Items.STARTING:
		out.append("**%s** (%s)\n" % [class_id.capitalize(),Items.ARMOR_TITLES[Items.ARMOR_OF[class_id]].to_lower()])
		out.append("| Slot | Item | What it gives |\n|---|---|---|")
		var start: Dictionary = Items.STARTING[class_id]
		for slot in Items.SLOTS:
			if not start.equipment[slot].is_empty(): out.append(row(Items.SLOT_TITLES[slot],start.equipment[slot]))
		for id in start.bag: out.append(row("Bag",id))
		out.append("")
	out.append("### Items that drop\n")
	out.append("| Item | Rarity | Kind | Used by | What it gives |\n|---|---|---|---|---|")
	for id in Items.ALL:
		if not Items.ALL[id].has("rarity"): continue
		var about: Dictionary = Items.describe(id)
		out.append("| %s | %s | %s | %s | %s |" % [about.title,about.rarity.capitalize(),about.kind,", ".join(users(id)),"; ".join(about.stats)])
	out.append("\n### Drop chances\n")
	out.append("Chance that one kill drops that particular item, in percent.\n")
	for class_id in Items.WIELDS:
		out.append("**%s**\n" % class_id.capitalize())
		var header = "| Item |"
		var rule = "|---|"
		for enemy in ENEMIES:
			header += " %s |" % enemy[1]
			rule += "---|"
		out.append(header+"\n"+rule)
		var pool: Array = Items.loot(class_id)
		var total = 0.0
		for id in pool: total += Items.RARITY_WEIGHTS[Items.rarity(id)]
		var rare: Array = Items.loot(class_id,Items.BOSS_RARITY)
		for id in pool:
			var line = "| %s |" % Items.ALL[id].name
			for enemy in ENEMIES:
				var chance: float
				if enemy[0] == "boss": chance = (100.0/rare.size() if id in rare else 0.0)*Items.DROP_CHANCE.boss*.01
				else: chance = Items.DROP_CHANCE[enemy[0]]*Items.RARITY_WEIGHTS[Items.rarity(id)]/total
				line += " %s |" % ("%.2f" % chance if chance > 0 else "–")
			out.append(line)
		var any = "| *Any item* |"
		for enemy in ENEMIES: any += " *%s* |" % Items.figure(Items.DROP_CHANCE[enemy[0]])
		out.append(any+"\n")
	print("\n".join(out))
	quit(0)
func users(id: String) -> Array:
	return Items.WIELDS.keys().filter(func(c): return Items.usable(c,id)).map(func(c): return c.capitalize())
func row(place: String, id: String) -> String:
	var about: Dictionary = Items.describe(id)
	return "| %s | %s | %s: %s |" % [place,about.title,about.kind,"; ".join(about.stats)]
