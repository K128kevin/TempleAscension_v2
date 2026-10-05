extends RefCounted
## The item system: every item in the game, what each class may wear and
## wield, the hero's equipment slots and bag, and what falls from enemies.
## (docs/ITEMS.md lists the items and their drop chances; tools/item_table.gd
## prints those tables from this file.)
##
## A run carries `equipment` (slot to item id, "" when empty) and `bag` (ten
## item ids, "" when empty). Items are fixed designs: an id is all that is kept.

# Where things are worn or held. "main" and "off" are the two hands: one
# two-handed weapon (the off hand then empty), two one-handed weapons, or a
# one-handed weapon and a shield.
const ARMOR_SLOTS = ["head","chest","legs","feet","hands"]
const SLOTS = ["head","chest","legs","feet","hands","main","off"]
const SLOT_TITLES = {"head":"Head","chest":"Chest","legs":"Legs","feet":"Feet","hands":"Hands","main":"Main hand","off":"Off hand"}
# The bag: a grid five wide and two tall.
const BAG_COLUMNS = 5
const BAG_SIZE = 10

# Armor comes in three weights, and each class wears one.
const ARMOR_OF = {"warrior":"heavy","ranger":"medium","wizard":"light"}
const ARMOR_TITLES = {"heavy":"Heavy armor","medium":"Medium armor","light":"Light armor"}
# The kinds of weapon (and the shield) each class can use.
const WIELDS = {"warrior":["sword","shield","mace","axe","spear","bow"],"ranger":["bow","dagger","sword"],"wizard":["staff","dagger"]}
const KIND_TITLES = {"sword":"Sword","mace":"Mace","axe":"Axe","spear":"Spear","bow":"Bow","staff":"Staff","dagger":"Dagger","shield":"Shield"}
# All the armor a hero wears can take off this much of a blow at most.
const ARMOR_CAP = 75.0
# With a weapon in each hand, the off hand's adds this share of its damage to
# every blow.
const OFF_HAND_SHARE = .5
# Bare hands.
const UNARMED = [1.0,3.0]

# How a weapon is swung (its clips: scripts/combat_animation.gd FAMILIES):
# one-handed swords, maces and axes share the sword's; two-handed swords, axes
# and mauls the heavy ones; the spear its own.
static func family(item: Dictionary) -> String:
	if item.is_empty(): return "fist"
	if item.kind in ["bow","staff","dagger"]: return item.kind
	if item.kind == "spear": return "pike"
	return "heavy" if item.hands == 2 else "one"

# Rarity colours an item's name, and weights its chance to drop.
const RARITY_COLORS = {"common":Color(.93,.91,.82),"uncommon":Color(.45,.92,.5),"rare":Color(.45,.65,1.0)}
const RARITY_WEIGHTS = {"common":10,"uncommon":5,"rare":2}

# What an item may add besides its armor or damage, and how each reads.
# The five attributes count as points spent on them.
const BONUS_TEXT = {"strength":"+%s Strength","dexterity":"+%s Dexterity","intelligence":"+%s Intelligence","vitality":"+%s Vitality","willpower":"+%s Willpower",
	"spell_damage":"+%s%% spell damage","crit":"+%s%% critical strike chance","haste":"+%s%% attack speed","speed":"+%s%% movement speed",
	"health":"+%s maximum health","energy":"+%s maximum energy","leech":"Restores %s health on each hit"}
const ATTRIBUTES = ["strength","dexterity","intelligence","vitality","willpower"]

# Every item. Armor: its `slot`, `weight` and `armor` (percent less damage
# taken). Weapons: `kind`, `hands` and `damage` (a hit's least and most, the
# baseline of the normal attack and of every skill made with it); a staff has
# no damage of its own, the wizard's spells being worked from his Intelligence
# (its `bonus` may raise them). Shields: `block` (percent chance) and
# `mitigation` (percent less damage from a blocked attack).
# `rarity` is absent on the gear a class starts with, which never drops.
# `look` is how it is shown (scripts/visual.gd): a weapon's or shield's model,
# its size in metres, how far up from its butt the fist holds it (`grip`), its
# `finish`, and for anything a `tint`; armor shows as its class's own piece.
const ALL = {
	# --- What the warrior starts with: heavy armor, sword and shield.
	"gladiator_helm":{"name":"Gladiator's Helm","slot":"head","weight":"heavy","armor":5.0},
	"scale_cuirass":{"name":"Scale Cuirass","slot":"chest","weight":"heavy","armor":9.0},
	"studded_kilt":{"name":"Studded War Kilt","slot":"legs","weight":"heavy","armor":6.0},
	"strapped_sandals":{"name":"Strapped Sandals","slot":"feet","weight":"heavy","armor":3.0},
	"steel_manica":{"name":"Steel Manica","slot":"hands","weight":"heavy","armor":3.0},
	"legionary_sword":{"name":"Legionary's Sword","slot":"weapon","kind":"sword","hands":1,"damage":[10.0,15.0],
		"look":{"model":"sword","size":Vector3(.19,1.3,.09),"grip":.22,"finish":"sword"}},
	"lion_shield":{"name":"Lion Shield","slot":"shield","kind":"shield","block":25.0,"mitigation":20.0,
		"look":{"model":"shield","size":Vector3(.66,.66,.12),"finish":"lion"}},
	# --- The ranger: medium armor, bow and dagger.
	"hooded_cloak":{"name":"Hooded Cloak","slot":"head","weight":"medium","armor":3.0},
	"wool_tunic":{"name":"Tattered Wool Tunic","slot":"chest","weight":"medium","armor":6.0},
	"leather_trousers":{"name":"Trousers and Knee Guards","slot":"legs","weight":"medium","armor":4.0},
	"strapped_boots":{"name":"Strapped Leather Boots","slot":"feet","weight":"medium","armor":2.0},
	"laced_bracers":{"name":"Laced Bracers","slot":"hands","weight":"medium","armor":2.0},
	"yew_longbow":{"name":"Yew Longbow","slot":"weapon","kind":"bow","hands":2,"damage":[10.0,15.0],
		"look":{"model":"bow","size":Vector3(.25,1.3,.10),"grip":.55,"finish":"bow"}},
	"hunting_dagger":{"name":"Hunting Dagger","slot":"weapon","kind":"dagger","hands":1,"damage":[10.0,15.0],
		"look":{"model":"dagger","size":Vector3(.09,.5,.045),"grip":.10,"finish":"dagger"}},
	# --- The wizard: light armor and a staff.
	"deep_hood":{"name":"Deep Hood","slot":"head","weight":"light","armor":2.0},
	"navy_robe":{"name":"Navy Wool Robe","slot":"chest","weight":"light","armor":4.0},
	"wool_trousers":{"name":"Dark Wool Trousers","slot":"legs","weight":"light","armor":2.0},
	"worn_boots":{"name":"Worn Leather Boots","slot":"feet","weight":"light","armor":1.0},
	"wrapped_bracers":{"name":"Wrapped Bracers","slot":"hands","weight":"light","armor":1.0},
	"silver_staff":{"name":"Twisted Silver Staff","slot":"weapon","kind":"staff","hands":2,"bonus":{"spell_damage":5.0},
		"look":{"model":"oracle_staff","size":Vector3(.13,1.9,.13),"grip":.45,"finish":"staff"}},

	# --- What enemies drop. Weapons and shields first.
	"bandit_sica":{"name":"Bandit's Sica","rarity":"common","slot":"weapon","kind":"sword","hands":1,"damage":[12.0,17.0],"bonus":{"haste":5.0},
		"look":{"model":"sica","size":Vector3(.19,.86,.09),"grip":.146,"finish":"sica"}},
	# (Its model's haft stands to one side of its bit: Art.held_model. The turn
	# brings the bit round to lead the forehand cuts, and a little past, toward
	# where the backhand leads.)
	"bronze_hatchet":{"name":"Bronze Hatchet","rarity":"common","slot":"weapon","kind":"axe","hands":1,"damage":[13.0,19.0],"bonus":{"crit":3.0},
		"look":{"model":"hand_axe","size":Vector3(.4,.72,.1),"grip":.13,"finish":"arms","metal_from":.55,"edge":[.6,1.0],"haft":.325,"turn":-PI*.64}},
	"flanged_mace":{"name":"Flanged Mace","rarity":"uncommon","slot":"weapon","kind":"mace","hands":1,"damage":[15.0,19.0],"bonus":{"strength":3},
		"look":{"model":"mace","size":Vector3(.17,.8,.17),"grip":.14,"finish":"arms","metal_from":.62,"edge":[.7,1.0]}},
	"greatsword":{"name":"Centurion's Greatsword","rarity":"uncommon","slot":"weapon","kind":"sword","hands":2,"damage":[22.0,32.0],"bonus":{"strength":2},
		"look":{"model":"sword_long","size":Vector3(.44,1.5,.13),"grip":.27,"finish":"arms","metal_from":.27,"edge":[.3,1.0]}},
	"executioner_axe":{"name":"Executioner's Axe","rarity":"rare","slot":"weapon","kind":"axe","hands":2,"damage":[25.0,37.0],"bonus":{"crit":5.0},
		"look":{"model":"axe","size":Vector3(.55,1.25,.12),"grip":.40,"finish":"arms","metal_from":.6,"edge":[.66,1.0]}},
	"legion_hasta":{"name":"Legionary's Hasta","rarity":"uncommon","slot":"weapon","kind":"spear","hands":2,"damage":[18.0,26.0],"bonus":{"dexterity":2},
		"look":{"model":"hasta","size":Vector3.ONE,"length":2.3,"grip":.70,"finish":"hasta","edge":[.9,1.0]}},
	"hunters_recurve":{"name":"Hunter's Recurve","rarity":"uncommon","slot":"weapon","kind":"bow","hands":2,"damage":[13.0,18.0],"bonus":{"crit":4.0},
		"look":{"model":"bow","size":Vector3(.25,1.3,.10),"grip":.55,"finish":"bow","tint":Color(.5,.36,.3)}},
	"viper_fang":{"name":"Viper's Fang","rarity":"uncommon","slot":"weapon","kind":"dagger","hands":1,"damage":[12.0,17.0],"bonus":{"leech":2.0},
		"look":{"model":"dagger","size":Vector3(.09,.56,.045),"grip":.11,"finish":"dagger","tint":Color(.62,.95,.6)}},
	"oracle_staff":{"name":"Oracle's Staff","rarity":"rare","slot":"weapon","kind":"staff","hands":2,"bonus":{"spell_damage":20.0,"intelligence":3},
		"look":{"model":"oracle_staff","size":Vector3(.13,1.9,.13),"grip":.45,"finish":"staff","tint":Color(1.0,.78,.4),"crystal":Color(1.0,.5,.2)}},
	"ashwood_staff":{"name":"Ashwood Staff","rarity":"common","slot":"weapon","kind":"staff","hands":2,"bonus":{"spell_damage":10.0},
		"look":{"model":"staff","size":Vector3(.2,1.75,.14),"grip":.45,"finish":"arms","metal_from":.87}},
	"bandit_buckler":{"name":"Bandit's Buckler","rarity":"common","slot":"shield","kind":"shield","block":18.0,"mitigation":30.0,
		"look":{"model":"shield","size":Vector3(.5,.5,.1),"finish":"lion","tint":Color(.42,.3,.24)}},
	"bronze_aspis":{"name":"Bronze Aspis","rarity":"rare","slot":"shield","kind":"shield","block":32.0,"mitigation":28.0,"bonus":{"vitality":3},
		"look":{"model":"shield","size":Vector3(.72,.72,.13),"finish":"lion","tint":Color(.80,.56,.27)}},
	# Heavy armor.
	"bronze_helm":{"name":"Bronze Arena Helm","rarity":"uncommon","slot":"head","weight":"heavy","armor":8.0,"bonus":{"vitality":2},"look":{"tint":Color(.82,.58,.3)}},
	"bronze_cuirass":{"name":"Bronze Scale Cuirass","rarity":"rare","slot":"chest","weight":"heavy","armor":13.0,"bonus":{"health":25.0},"look":{"tint":Color(.84,.6,.32)}},
	"blackened_manica":{"name":"Blackened Manica","rarity":"common","slot":"hands","weight":"heavy","armor":5.0,"bonus":{"strength":2},"look":{"tint":Color(.38,.38,.42)}},
	# Medium armor.
	"dusk_cloak":{"name":"Dusk Cloak","rarity":"uncommon","slot":"head","weight":"medium","armor":5.0,"bonus":{"speed":5.0},"look":{"tint":Color(.2,.2,.3)}},
	"stalker_jerkin":{"name":"Stalker's Jerkin","rarity":"rare","slot":"chest","weight":"medium","armor":9.0,"bonus":{"dexterity":3},"look":{"tint":Color(.62,.42,.3)}},
	"swift_boots":{"name":"Swiftfoot Boots","rarity":"common","slot":"feet","weight":"medium","armor":3.0,"bonus":{"speed":4.0},"look":{"tint":Color(.5,.5,.55)}},
	# Light armor.
	"crimson_hood":{"name":"Crimson Hood","rarity":"uncommon","slot":"head","weight":"light","armor":4.0,"bonus":{"intelligence":2},"look":{"tint":Color(.42,.07,.08)}},
	"ember_robe":{"name":"Ember Robe","rarity":"rare","slot":"chest","weight":"light","armor":7.0,"bonus":{"spell_damage":10.0},"look":{"tint":Color(.42,.07,.08)}},
	"seer_bracers":{"name":"Seer's Bracers","rarity":"common","slot":"hands","weight":"light","armor":2.0,"bonus":{"willpower":3},"look":{"tint":Color(.75,.68,.5)}}}

# What each class begins wearing and holding, and carrying in its bag.
const STARTING = {
	"warrior":{"equipment":{"head":"gladiator_helm","chest":"scale_cuirass","legs":"studded_kilt","feet":"strapped_sandals","hands":"steel_manica","main":"legionary_sword","off":"lion_shield"},"bag":[]},
	"ranger":{"equipment":{"head":"hooded_cloak","chest":"wool_tunic","legs":"leather_trousers","feet":"strapped_boots","hands":"laced_bracers","main":"yew_longbow","off":""},"bag":["hunting_dagger"]},
	"wizard":{"equipment":{"head":"deep_hood","chest":"navy_robe","legs":"wool_trousers","feet":"worn_boots","hands":"wrapped_bracers","main":"silver_staff","off":""},"bag":[]}}
# The plainest weapon of each kind (what debug grants and tests hand out).
const PLAIN = {"sword":"legionary_sword","bow":"yew_longbow","dagger":"hunting_dagger","staff":"silver_staff","axe":"executioner_axe","spear":"legion_hasta","mace":"flanged_mace","shield":"lion_shield"}

# --- Drops --------------------------------------------------------------------
# Any enemy that grants experience may drop one item as it dies: DROP_CHANCE
# percent by its kind. The item is drawn from those the hero's class can use
# (CLASS_LOOT), each weighted by its rarity (RARITY_WEIGHTS).
const DROP_CHANCE = {"bandit":8.0,"bandit_archer":8.0,"gladiator":10.0,"archer":10.0,"lion":10.0,"wizard":14.0,"centurion":14.0,"boss":100.0}
const CLASS_LOOT = true
# The Crowned Statue's drop is always one of the rarest.
const BOSS_RARITY = "rare"

static func get_item(id: String) -> Dictionary:
	return ALL.get(id,{})

static func exists(id: String) -> bool:
	return ALL.has(id)

static func is_weapon(id: String) -> bool:
	return ALL.has(id) and ALL[id].slot == "weapon"

static func is_shield(id: String) -> bool:
	return ALL.has(id) and ALL[id].slot == "shield"

static func two_handed(id: String) -> bool:
	return is_weapon(id) and ALL[id].hands == 2

static func rarity(id: String) -> String:
	return ALL[id].get("rarity","common") if ALL.has(id) else "common"

static func color(id: String) -> Color:
	return RARITY_COLORS[rarity(id)]

# Why `class_id` cannot use the item at all, or "" if it can.
static func barred(class_id: String, id: String) -> String:
	if not ALL.has(id): return "Not an item."
	var item: Dictionary = ALL[id]
	if item.slot in ARMOR_SLOTS:
		if item.weight != ARMOR_OF[class_id]: return "%s: a %s cannot wear it." % [ARMOR_TITLES[item.weight],class_id]
	elif not item.kind in WIELDS[class_id]: return "A %s cannot use a %s." % [class_id,KIND_TITLES[item.kind].to_lower()]
	return ""

static func usable(class_id: String, id: String) -> bool:
	return barred(class_id,id).is_empty()

# The items an enemy can drop for `class_id`.
static func loot(class_id: String, only_rarity: String = "") -> Array:
	var pool: Array = []
	for id in ALL:
		if not ALL[id].has("rarity") or (not only_rarity.is_empty() and ALL[id].rarity != only_rarity): continue
		if CLASS_LOOT and not usable(class_id,id): continue
		pool.append(id)
	return pool

# What an `enemy` of that kind drops for `class_id`: an item's id, or "" for nothing.
# `chance` and `pick` are rolls from 0 to 1.
static func roll_drop(class_id: String, enemy: String, chance: float, pick: float) -> String:
	if chance*100.0 >= DROP_CHANCE.get(enemy,0.0): return ""
	var pool: Array = loot(class_id,BOSS_RARITY if enemy == "boss" else "")
	var total = 0.0
	for id in pool: total += RARITY_WEIGHTS[ALL[id].rarity]
	var mark: float = pick*total
	for id in pool:
		mark -= RARITY_WEIGHTS[ALL[id].rarity]
		if mark < 0.0: return id
	return "" if pool.is_empty() else pool[-1]

# --- A run's equipment and bag ---------------------------------------------------

static func empty_equipment() -> Dictionary:
	var worn = {}
	for slot in SLOTS: worn[slot] = ""
	return worn

static func empty_bag() -> Array:
	var bag: Array = []
	bag.resize(BAG_SIZE)
	bag.fill("")
	return bag

# Gives a new character its class's starting gear.
static func outfit(run: Dictionary, class_id: String) -> void:
	run.equipment = empty_equipment()
	run.bag = empty_bag()
	var start: Dictionary = STARTING[class_id]
	for slot in start.equipment: run.equipment[slot] = start.equipment[slot]
	for i in start.bag.size(): run.bag[i] = start.bag[i]

static func worn(run: Dictionary, slot: String) -> Dictionary:
	return ALL.get(run.equipment.get(slot,""),{})

# The weapon in the main hand ({} with none), and what the off hand holds if
# it is a weapon, or a shield.
static func main(run: Dictionary) -> Dictionary:
	return worn(run,"main")
static func off_weapon(run: Dictionary) -> Dictionary:
	var held: Dictionary = worn(run,"off")
	return held if not held.is_empty() and held.slot == "weapon" else {}
static func shield(run: Dictionary) -> Dictionary:
	var held: Dictionary = worn(run,"off")
	return held if not held.is_empty() and held.slot == "shield" else {}

# The kind of weapon in the main hand: "sword", "bow"..., or "unarmed".
static func kind(run: Dictionary) -> String:
	return main(run).get("kind","unarmed")

# Everything worn and held adds up: the sum of one bonus.
static func bonus(run: Dictionary, key: String) -> float:
	var total = 0.0
	for slot in SLOTS:
		var item: Dictionary = worn(run,slot)
		if not item.is_empty(): total += float(item.get("bonus",{}).get(key,0.0))
	return total

# Percent less damage the hero takes for the armor he wears.
static func armor(run: Dictionary) -> float:
	var total = 0.0
	for slot in ARMOR_SLOTS: total += float(worn(run,slot).get("armor",0.0))
	return minf(ARMOR_CAP,total)

# The first weapon in the bag of one of `kinds` that the class can use: its
# place there, or -1.
static func bagged(run: Dictionary, kinds: Array) -> int:
	for i in run.bag.size():
		var id: String = run.bag[i]
		if is_weapon(id) and ALL[id].kind in kinds and usable(run.class_id,id): return i
	return -1

# The weapon a blow of `tag` is made with: the one in the main hand if it is
# of that sort ("ranged": a bow; "melee": anything else but a staff), else the
# first such in the bag (the ranger carries bow and dagger, and takes up the
# one a skill needs), else {}: bare hands.
static func weapon_for(run: Dictionary, tag: String) -> Dictionary:
	var held: Dictionary = main(run)
	var wanted: Array = ["bow"] if tag == "ranged" else ["sword","mace","axe","spear","dagger"]
	if not held.is_empty() and held.kind in wanted: return held
	var found = bagged(run,wanted)
	return ALL[run.bag[found]] if found >= 0 else {}

# The least and most a hit of `tag` deals before attributes and skills: the
# weapon's own damage, and with a weapon in each hand a share of the other's.
static func damage_span(run: Dictionary, tag: String = "melee") -> Array:
	var weapon: Dictionary = weapon_for(run,tag)
	if weapon.is_empty() or not weapon.has("damage"): return UNARMED.duplicate()
	var span: Array = weapon.damage.duplicate()
	var second: Dictionary = off_weapon(run)
	if weapon == main(run) and second.has("damage"):
		span[0] += second.damage[0]*OFF_HAND_SHARE
		span[1] += second.damage[1]*OFF_HAND_SHARE
	return span

# --- Moving things about ---------------------------------------------------------
# A place is a slot's name ("head", "main"...) or "bag:3".

static func in_bag(place: String) -> bool:
	return place.begins_with("bag:")

static func at(run: Dictionary, place: String) -> String:
	if in_bag(place): return run.bag[int(place.trim_prefix("bag:"))]
	return run.equipment.get(place,"")

static func put(run: Dictionary, place: String, id: String) -> void:
	if in_bag(place): run.bag[int(place.trim_prefix("bag:"))] = id
	else: run.equipment[place] = id

static func free_bag_slot(run: Dictionary, except: String = "") -> int:
	for i in run.bag.size():
		if run.bag[i].is_empty() and "bag:%d" % i != except: return i
	return -1

# Why the item cannot go in that equipment slot, or "".
static func misfit(run: Dictionary, id: String, slot: String) -> String:
	var no: String = barred(run.class_id,id)
	if not no.is_empty(): return no
	var item: Dictionary = ALL[id]
	if slot in ARMOR_SLOTS: return "" if item.slot == slot else "That goes on the %s." % (SLOT_TITLES[item.slot].to_lower() if item.slot in ARMOR_SLOTS else "hands, as a weapon")
	if item.slot in ARMOR_SLOTS: return "That is worn, not held."
	if slot == "main": return "" if item.slot == "weapon" else "A shield goes in the off hand."
	return "A two-handed weapon is held in the main hand." if item.slot == "weapon" and item.hands == 2 else ""

# Moves what is at `from` to `to` (a drag in the inventory): bag to bag swaps;
# onto a slot equips, whatever was there going back where the item came from;
# off a slot unequips. A two-handed weapon empties the off hand into the bag,
# and an off-hand item sends a two-handed weapon there. Returns "" if it was
# done, or why not.
static func move(run: Dictionary, from: String, to: String) -> String:
	if from == to: return ""
	var id: String = at(run,from)
	if id.is_empty(): return "Nothing there."
	var other: String = at(run,to)
	if not in_bag(to):
		var no: String = misfit(run,id,to)
		if not no.is_empty(): return no
	if not in_bag(from) and not other.is_empty():
		# What is displaced must be able to take the place left.
		var no: String = misfit(run,other,from)
		if not no.is_empty(): return no
	# The other hand, when a two-handed weapon is taken up or made room for.
	var spill = ""
	var spill_from = ""
	if to == "main" and two_handed(id) and not run.equipment.off.is_empty() and from != "off": spill_from = "off"
	elif to == "off" and two_handed(run.equipment.main) and from != "main": spill_from = "main"
	elif from == "off" and to == "main" and two_handed(other): return "A two-handed weapon is held in the main hand."
	if not spill_from.is_empty():
		spill = run.equipment[spill_from]
		# (It may go where the item came from, if nothing else is going there.)
		var room: int = free_bag_slot(run)
		if room < 0 and not (in_bag(from) and other.is_empty()): return "No room in the bag."
		put(run,to,id)
		put(run,from,other)
		run.equipment[spill_from] = ""
		run.bag[free_bag_slot(run)] = spill
		return ""
	put(run,to,id)
	put(run,from,other)
	return ""

# Where a right-clicked bag item would be equipped: its armor slot, or a hand
# (a shield or a second one-handed weapon the off hand, if the main is full).
static func slot_for(run: Dictionary, id: String) -> String:
	if not ALL.has(id): return ""
	var item: Dictionary = ALL[id]
	if item.slot in ARMOR_SLOTS: return item.slot
	if item.slot == "shield": return "off"
	if item.hands == 1 and not run.equipment.main.is_empty() and not two_handed(run.equipment.main) and run.equipment.off.is_empty() and item.kind != "bow": return "off"
	return "main"

# Puts a found item in the first free place in the bag; false if it is full.
static func stow(run: Dictionary, id: String) -> bool:
	var room: int = free_bag_slot(run)
	if room < 0: return false
	run.bag[room] = id
	return true

# Takes up the first weapon of one of `kinds` from the bag, the one in hand
# going back in its place. False if there is none, or no room for what the
# off hand holds. A one-handed weapon taken up with the other hand free, his
# shield comes out of the bag with it (put there when he took up a bow, say).
static func take_up(run: Dictionary, kinds: Array) -> bool:
	var found: int = bagged(run,kinds)
	if found < 0 or not move(run,"bag:%d" % found,"main").is_empty(): return false
	if not two_handed(run.equipment.main) and run.equipment.off.is_empty():
		for i in run.bag.size():
			if is_shield(run.bag[i]) and usable(run.class_id,run.bag[i]):
				move(run,"bag:%d" % i,"off")
				break
	return true

# Arms a run with the plainest weapon of `kind` (and a shield, for a sword
# given `with_shield`), whatever its class: for debug tools and tests.
static func arm(run: Dictionary, kind_name: String, with_shield: bool = false) -> void:
	run.equipment.main = PLAIN.get(kind_name,"")
	run.equipment.off = PLAIN.shield if with_shield and not two_handed(run.equipment.main) else ""

# --- Words ---------------------------------------------------------------------

# How long a weapon is, butt to point (metres).
static func length(look: Dictionary) -> float:
	return look.get("length",look.size.y)

# A number as few figures as it needs.
static func figure(amount: float) -> String:
	return String.num(snappedf(amount,.01)).trim_suffix(".0")

# What an item is, line by line, for its tip: {"title","kind","stats"
# (lines),"note"}.
static func describe(id: String, class_id: String = "") -> Dictionary:
	var item: Dictionary = ALL[id]
	var lines: Array = []
	var what = ""
	if item.slot in ARMOR_SLOTS:
		what = "%s · %s" % [ARMOR_TITLES[item.weight],SLOT_TITLES[item.slot]]
		lines.append("%s%% less damage taken" % figure(item.armor))
	elif item.slot == "shield":
		what = "Shield · Off hand"
		lines.append("%s%% chance to block" % figure(item.block))
		lines.append("Blocked attacks deal %s%% less" % figure(item.mitigation))
	else:
		what = "%s · %s" % [KIND_TITLES[item.kind],"Two-handed" if item.hands == 2 else "One-handed"]
		if item.has("damage"): lines.append("%s–%s damage" % [figure(item.damage[0]),figure(item.damage[1])])
		else: lines.append("Spells take their damage from Intelligence")
	for key in item.get("bonus",{}): lines.append(BONUS_TEXT[key] % figure(item.bonus[key]))
	return {"title":item.name,"kind":what,"stats":lines,"note":"" if class_id.is_empty() else barred(class_id,id),"rarity":rarity(id)}
