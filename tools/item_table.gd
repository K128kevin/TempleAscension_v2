extends SceneTree
## Prints the tables of docs/ITEMS.md from scripts/items.gd: the starting
## equipment, the common base items, the prefixes and suffixes (uncommon and
## rare), the uniques, and each enemy's drop chances by rarity.
##
##   Godot --headless --path . --script tools/item_table.gd
const Items = preload("res://scripts/items.gd")
const ENEMIES = [["bandit","Bandit"],["bandit_archer","Bandit Archer"],["gladiator","Gladiator"],["archer","Archer"],["lion","Lion Guardian"],["wizard","Oracle"],["centurion","Centurion"],["boss","The Crowned Statue"]]
const CATEGORY_TITLES = {"light":"light armor","medium":"medium armor","heavy":"heavy armor","shield":"shields","sword":"swords","spear":"spears","dagger":"daggers","axe":"axes","mace":"maces","bow":"bows","staff":"staves"}
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
	out.append("### Common items\n")
	out.append("What drops, and what the prefixes and suffixes are put on.\n")
	out.append("| Item | Kind | Used by | What it gives |\n|---|---|---|---|")
	for id in Items.BASES:
		if Items.BASES[id].get("rarity","") != "common": continue
		var about: Dictionary = Items.describe(id)
		out.append("| %s | %s | %s | %s |" % [about.title,about.kind,", ".join(users(id)),"; ".join(about.stats)])
	out.append("\n### Prefixes and suffixes\n")
	out.append("An uncommon item is a common item with one of these; a rare item has a prefix and a suffix, or one of the rare ones alone.\n")
	for table in [["Prefixes",Items.PREFIXES],["Suffixes",Items.SUFFIXES],["Rare prefixes",Items.RARE_PREFIXES],["Rare suffixes",Items.RARE_SUFFIXES]]:
		out.append("**%s**\n" % table[0])
		out.append("| Affix | What it gives | Goes on |\n|---|---|---|")
		for id in table[1]: out.append("| %s | %s | %s |" % [table[1][id].name,affix_text(table[1][id]),on_text(table[1][id].on)])
		out.append("")
	out.append("### Unique items\n")
	out.append("| Item | Kind | Drops for | What it gives |\n|---|---|---|---|")
	for id in Items.BASES:
		if Items.BASES[id].get("rarity","") != "unique": continue
		var about: Dictionary = Items.describe(id)
		var who: String = Items.BASES[id]["for"].capitalize() if not Items.BASES[id]["for"].is_empty() else "Everyone"
		out.append("| %s | %s | %s | %s%s |" % [about.title,about.kind,who,"; ".join(about.stats),". "+about.effect if not about.effect.is_empty() else ""])
	out.append("\n### Drop chances\n")
	out.append("Chance that one kill drops an item of that rarity, in percent (the item is made for the hero's class).\n")
	var header = "| Enemy | Any item |"
	var rule = "|---|---|"
	for r in Items.RARITIES:
		header += " %s |" % r.capitalize()
		rule += "---|"
	out.append(header+"\n"+rule)
	for enemy in ENEMIES:
		var line = "| %s | %s |" % [enemy[1],Items.figure(Items.DROP_CHANCE[enemy[0]])]
		var weights: Dictionary = Items.BOSS_WEIGHTS if enemy[0] == "boss" else Items.RARITY_WEIGHTS
		var total = 0.0
		for r in weights: total += weights[r]
		for r in Items.RARITIES: line += " %s |" % ("%.2f" % (Items.DROP_CHANCE[enemy[0]]*weights[r]/total) if weights.has(r) else "–")
		out.append(line)
	print("\n".join(out))
	quit(0)
func users(id: String) -> Array:
	return Items.WIELDS.keys().filter(func(c): return Items.usable(c,id)).map(func(c): return c.capitalize())
func row(place: String, id: String) -> String:
	var about: Dictionary = Items.describe(id)
	return "| %s | %s | %s: %s |" % [place,about.title,about.kind,"; ".join(about.stats)]
func affix_text(affix: Dictionary) -> String:
	var parts: Array = []
	for key in Items.ATTRIBUTES:
		if affix.get("bonus",{}).has(key): parts.append(Items.BONUS_TEXT[key] % Items.figure(affix.bonus[key]))
	if affix.has("armor"): parts.append("+%s%% armor" % Items.figure(affix.armor))
	if affix.has("damage"): parts.append("+%s%% damage" % Items.figure(affix.damage))
	if affix.has("speed"): parts.append("+%s attacks per second" % Items.figure(affix.speed))
	if affix.has("spiked"): parts.append("Blocked attacks deal %s%% of their damage to the attacker" % Items.figure(affix.spiked))
	return ", ".join(parts)
func on_text(on: Array) -> String:
	if on == Items.ON_ALL: return "all items"
	return ", ".join(on.map(func(c): return CATEGORY_TITLES[c]))
