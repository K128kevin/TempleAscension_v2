extends RefCounted
## The item system: every base item in the game, the prefixes and suffixes
## that make uncommon and rare items of them, the uniques, what each class
## may wear and wield, the hero's equipment slots and bag, and what falls
## from enemies. (docs/ITEMS.md lists it all; tools/item_table.gd prints
## those tables from this file.)
##
## An item in play is an *instance*: {"base": its base item's id, and for a
## magic item "prefix" and/or "suffix"}. A run carries `equipment` (slot to
## instance, {} when empty) and `bag` (ten instances, {} when empty).
## `get_item(instance)` resolves one to its full stats (resolve()).

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
# Armor is a number: all the hero wears adds up, and takes armor/(armor+
# ARMOR_SCALE) off every blow, to ARMOR_CAP percent at most.
const ARMOR_SCALE = 150.0
const ARMOR_CAP = 75.0
# With a weapon in each hand, the off hand's adds this share of its damage to
# every blow.
const OFF_HAND_SHARE = .5
# Bare hands: their damage, and their blows a second.
const UNARMED = [1.0,3.0]
const UNARMED_SPEED = 2.0

# How a weapon is swung (its clips: scripts/combat_animation.gd FAMILIES):
# one-handed swords, maces and axes share the sword's; two-handed swords,
# maces and axes the heavy ones; the spear its own.
static func family(item: Dictionary) -> String:
	if item.is_empty(): return "fist"
	if item.kind in ["bow","staff","dagger"]: return item.kind
	if item.kind == "spear": return "pike"
	return "heavy" if item.hands == 2 else "one"

# Rarity colours an item's name. The gear a class starts with and the common
# items are white; a prefix or a suffix makes an uncommon (green) item of a
# common one, both or one of the rare affixes a rare (blue) one; the uniques
# are purple.
const RARITIES = ["common","uncommon","rare","unique"]
const RARITY_COLORS = {"common":Color(.93,.91,.82),"uncommon":Color(.45,.92,.5),"rare":Color(.45,.65,1.0),"unique":Color(.8,.52,1.0)}
# How likely each rarity is when something drops (weights), and from the
# Crowned Statue, which drops nothing less than rare.
const RARITY_WEIGHTS = {"common":58,"uncommon":28,"rare":11,"unique":3}
const BOSS_WEIGHTS = {"rare":75,"unique":25}

# What an item may add besides its armor or damage, and how each reads.
# The five attributes count as points spent on them.
const BONUS_TEXT = {"strength":"+%s Strength","dexterity":"+%s Dexterity","intelligence":"+%s Intelligence","vitality":"+%s Vitality","willpower":"+%s Willpower","speed":"+%s%% movement speed"}
const ATTRIBUTES = ["strength","dexterity","intelligence","vitality","willpower"]

# Every base item. Armor: its `slot`, `weight` and `armor`. Weapons: `kind`,
# `hands`, `damage` (a hit's least and most, the baseline of the normal attack
# and of every skill made with it) and `speed` (attacks a second); a staff
# has no damage of its own, the wizard's spells being worked from his
# Intelligence. Shields: `block` (percent chance), `mitigation` (percent
# less damage from a blocked attack) and `armor`, counted with what is worn.
# `bonus`: attributes it adds.
# `rarity`: "starting" never drops; "common" drops, and is what prefixes and
# suffixes are put on; "unique" drops only for the class it is `for` (for
# every class if that is ""), with its own `effect`; `any_class` armor is
# worn by every class, whatever its weight. `look` is how it is shown (scripts/visual.gd): a
# weapon's or shield's model, its size in metres, how far up from its butt
# the fist holds it (`grip`), its `finish` and colours; armor shows as its
# class's own piece, in a `tint` of its own, or as a `mesh` of its own (the
# wizard's hat).
const BASES = {
	# --- What the wizard starts with: wool, sandals and his twisted staff.
	"wool_hood":{"name":"Wool Hood","rarity":"starting","slot":"head","weight":"light","armor":5.0},
	"wool_robe":{"name":"Wool Robe","rarity":"starting","slot":"chest","weight":"light","armor":8.0},
	"wool_trousers":{"name":"Wool Trousers","rarity":"starting","slot":"legs","weight":"light","armor":8.0},
	"wool_gloves":{"name":"Wool Gloves","rarity":"starting","slot":"hands","weight":"light","armor":5.0},
	"twisted_silver_staff":{"name":"Twisted Silver Staff","rarity":"starting","slot":"weapon","kind":"staff","hands":2,"bonus":{"intelligence":4},
		"look":{"model":"silver_staff","size":Vector3.ONE,"length":1.8,"grip":1.254,"finish":"parts"}},
	# --- The ranger: worn leather under a leather hood, a dagger and a bow.
	"worn_leather_tunic":{"name":"Worn Leather Tunic","rarity":"starting","slot":"chest","weight":"medium","armor":15.0},
	"worn_leather_trousers":{"name":"Worn Leather Trousers","rarity":"starting","slot":"legs","weight":"medium","armor":15.0},
	"worn_leather_boots":{"name":"Worn Leather Boots","rarity":"starting","slot":"feet","weight":"medium","armor":9.0},
	"worn_leather_gloves":{"name":"Worn Leather Gloves","rarity":"starting","slot":"hands","weight":"medium","armor":9.0},
	"rangers_dagger":{"name":"Ranger's Dagger","rarity":"starting","slot":"weapon","kind":"dagger","hands":1,"damage":[12.0,20.0],"speed":2.0,
		"look":{"model":"dagger","size":Vector3(.09,.5,.045),"grip":.10,"finish":"dagger"}},
	"rangers_bow":{"name":"Ranger's Bow","rarity":"starting","slot":"weapon","kind":"bow","hands":2,"damage":[16.0,24.0],"speed":1.2,
		"look":{"model":"bow","size":Vector3(.25,1.3,.10),"grip":.55,"finish":"bow"}},
	# --- The warrior: his gladiator's kit, a shortsword and a buckler.
	"gladiators_helmet":{"name":"Gladiator's Helmet","rarity":"starting","slot":"head","weight":"heavy","armor":15.0},
	"steel_plated_gauntlets":{"name":"Steel Plated Gauntlets","rarity":"starting","slot":"hands","weight":"heavy","armor":15.0},
	"steel_plated_boots":{"name":"Steel Plated Boots","rarity":"starting","slot":"feet","weight":"heavy","armor":15.0,"look":{"tint":Color(.66,.68,.72)}},
	"studded_war_kilt":{"name":"Studded War Kilt","rarity":"starting","slot":"legs","weight":"heavy","armor":23.0},
	"simple_shortsword":{"name":"Simple Shortsword","rarity":"starting","slot":"weapon","kind":"sword","hands":1,"damage":[17.0,25.0],"speed":1.3,
		"look":{"model":"sword","size":Vector3(.17,.92,.08),"grip":.16,"finish":"sword","blade":Color(.64,.65,.68),"fittings":Color(.46,.46,.48),"wrap":Color(.14,.09,.05)}},
	"lions_buckler":{"name":"Lion's Buckler","rarity":"starting","slot":"shield","kind":"shield","armor":17.0,"block":25.0,"mitigation":30.0,
		"look":{"model":"shield","size":Vector3(.5,.5,.1),"finish":"lion","tint":Color(.72,.62,.42)}},

	# --- Common: what drops, and what the prefixes and suffixes are put on.
	# Light armor.
	"silk_gloves":{"name":"Silk Gloves","rarity":"common","slot":"hands","weight":"light","armor":5.0,"bonus":{"intelligence":2},"look":{"tint":Color(.9,.8,1.0)}},
	"silk_robe":{"name":"Silk Robe","rarity":"common","slot":"chest","weight":"light","armor":8.0,"bonus":{"intelligence":3},"look":{"tint":Color(.5,.38,.68)}},
	"silk_pants":{"name":"Silk Pants","rarity":"common","slot":"legs","weight":"light","armor":8.0,"bonus":{"intelligence":2},"look":{"tint":Color(.46,.36,.62)}},
	"wizard_hat":{"name":"Wizard Hat","rarity":"common","slot":"head","weight":"light","armor":4.0,"bonus":{"intelligence":2},"look":{"mesh":"wizard_hat","tint":Color(.12,.13,.2)}},
	"sandals":{"name":"Sandals","rarity":"common","slot":"feet","weight":"light","armor":5.0},
	# Medium armor.
	"leather_gloves":{"name":"Leather Gloves","rarity":"common","slot":"hands","weight":"medium","armor":10.0,"look":{"tint":Color(.42,.27,.15)}},
	"fingerless_leather_gloves":{"name":"Fingerless Leather Gloves","rarity":"common","slot":"hands","weight":"medium","armor":7.0,"bonus":{"dexterity":2},"look":{"tint":Color(.3,.2,.12)}},
	"leather_tunic":{"name":"Leather Tunic","rarity":"common","slot":"chest","weight":"medium","armor":18.0,"look":{"tint":Color(.46,.3,.17)}},
	"studded_leather_tunic":{"name":"Studded Leather Tunic","rarity":"common","slot":"chest","weight":"medium","armor":20.0,"look":{"tint":Color(.3,.23,.18)}},
	"leather_boots":{"name":"Leather Boots","rarity":"common","slot":"feet","weight":"medium","armor":12.0,"look":{"tint":Color(.4,.25,.13)}},
	"leather_hood":{"name":"Leather Hood","rarity":"common","slot":"head","weight":"medium","armor":10.0,"look":{"tint":Color(.3,.19,.11)}},
	# Heavy armor.
	"steel_breastplate":{"name":"Steel Breastplate","rarity":"common","slot":"chest","weight":"heavy","armor":21.0,"bonus":{"strength":2},"look":{"tint":Color(.72,.74,.78)}},
	"scale_cuirass":{"name":"Scale Cuirass","rarity":"common","slot":"chest","weight":"heavy","armor":23.0},
	"plated_leg_armor":{"name":"Plated Leg Armor","rarity":"common","slot":"legs","weight":"heavy","armor":26.0,"look":{"tint":Color(.68,.7,.74)}},
	"steel_full_helm":{"name":"Steel Full Helm","rarity":"common","slot":"head","weight":"heavy","armor":20.0,"look":{"tint":Color(.74,.76,.8)}},
	# Weapons and shields.
	"steel_longsword":{"name":"Steel Longsword","rarity":"common","slot":"weapon","kind":"sword","hands":1,"damage":[20.0,28.0],"speed":1.1,
		"look":{"model":"sword","size":Vector3(.19,1.25,.09),"grip":.22,"finish":"sword","blade":Color(.84,.86,.9),"fittings":Color(.6,.62,.66),"wrap":Color(.3,.1,.08)}},
	"steel_shortsword":{"name":"Steel Shortsword","rarity":"common","slot":"weapon","kind":"sword","hands":1,"damage":[16.0,22.0],"speed":1.5,
		"look":{"model":"sword","size":Vector3(.18,.95,.085),"grip":.17,"finish":"sword","blade":Color(.84,.86,.9)}},
	"gladiators_round_shield":{"name":"Gladiator's Round Shield","rarity":"common","slot":"shield","kind":"shield","armor":20.0,"block":25.0,"mitigation":20.0,"bonus":{"dexterity":1,"strength":1},
		"look":{"model":"shield","size":Vector3(.66,.66,.12),"finish":"lion"}},
	"tower_shield":{"name":"Tower Shield","rarity":"common","slot":"shield","kind":"shield","armor":25.0,"block":28.0,"mitigation":28.0,
		"look":{"model":"scutum","size":Vector3(.6,1.1,.2),"finish":"tower","drop":.1}},
	"hunters_bow":{"name":"Hunter's Bow","rarity":"common","slot":"weapon","kind":"bow","hands":2,"damage":[15.0,23.0],"speed":1.5,"bonus":{"dexterity":1},
		"look":{"model":"bow","size":Vector3(.24,1.2,.10),"grip":.5,"finish":"bow","tint":Color(.52,.34,.26)}},
	"longbow":{"name":"Longbow","rarity":"common","slot":"weapon","kind":"bow","hands":2,"damage":[20.0,27.0],"speed":1.0,
		"look":{"model":"bow","size":Vector3(.27,1.65,.11),"grip":.68,"finish":"bow","tint":Color(.8,.72,.54)}},
	"bandit_blade":{"name":"Bandit Blade","rarity":"common","slot":"weapon","kind":"dagger","hands":1,"damage":[16.0,24.0],"speed":1.7,
		"look":{"model":"sica","size":Vector3(.15,.62,.07),"grip":.105,"finish":"sica"}},
	"greatsword":{"name":"Greatsword","rarity":"common","slot":"weapon","kind":"sword","hands":2,"damage":[30.0,42.0],"speed":1.2,
		"look":{"model":"sword_long","size":Vector3(.44,1.5,.13),"grip":.27,"finish":"arms","metal_from":.27,"edge":[.3,1.0]}},
	"war_hammer":{"name":"War Hammer","rarity":"common","slot":"weapon","kind":"mace","hands":2,"damage":[35.0,45.0],"speed":.9,
		"look":{"model":"war_hammer","size":Vector3(.34,1.35,.14),"grip":.40,"finish":"arms","metal_from":.78,"edge":[.8,1.0],"haft":.088}},
	# (Its model's haft stands to one side of its bit: Art.held_model. The turn
	# brings the bit round to lead the forehand cuts, and a little past, toward
	# where the backhand leads.)
	"hatchet":{"name":"Hatchet","rarity":"common","slot":"weapon","kind":"axe","hands":1,"damage":[16.0,24.0],"speed":1.6,
		"look":{"model":"hand_axe","size":Vector3(.4,.72,.1),"grip":.13,"finish":"arms","metal_from":.55,"edge":[.6,1.0],"haft":.325,"turn":-PI*.64}},
	# Staves: a wizard's, for his Intelligence; no damage of their own.
	"gnarled_staff":{"name":"Gnarled Staff","rarity":"common","slot":"weapon","kind":"staff","hands":2,"bonus":{"intelligence":3,"vitality":2,"willpower":2},
		"look":{"model":"ashwood_staff","size":Vector3.ONE,"length":1.75,"grip":1.254,"finish":"parts","crystal":Color(.74,.62,.4)}},
	"crystal_staff":{"name":"Crystal Staff","rarity":"common","slot":"weapon","kind":"staff","hands":2,"bonus":{"intelligence":4,"willpower":4},
		"look":{"model":"silver_staff","size":Vector3.ONE,"length":1.8,"grip":1.254,"finish":"parts","tint":Color(.3,.31,.38),"crystal":Color(.72,.5,1.0)}},

	# --- Unique: one for each class, which drops for that class alone.
	"robe_of_the_lost_emperor":{"name":"Robe of the Lost Emperor","rarity":"unique","for":"wizard","slot":"chest","weight":"light","armor":10.0,"bonus":{"intelligence":12,"willpower":10,"vitality":8},
		"effect":"emperor","effect_text":"Every time your spells damage a target there is a 10% chance you recover 20 energy","look":{"tint":Color(.3,.08,.34)}},
	"ancient_gladiators_helmet":{"name":"Ancient Gladiator's Helmet","rarity":"unique","for":"warrior","slot":"head","weight":"heavy","armor":22.0,"bonus":{"dexterity":12,"strength":15},
		"effect":"rallying_cry","effect_text":"Every attack has a 10% chance to grant Rallying Cry: 25% more attack speed and damage for 10 seconds, at most once every 30 seconds","look":{"tint":Color(.88,.68,.32)}},
	# (Light armor, but made for anyone: it drops for every class, and every
	# class may wear it.)
	"marathon_boots":{"name":"Marathon Boots","rarity":"unique","for":"","any_class":true,"slot":"feet","weight":"light","armor":8.0,"bonus":{"strength":6,"dexterity":6,"intelligence":6,"vitality":6,"willpower":6,"speed":20.0},
		"look":{"tint":Color(.86,.7,.32)}},
	"bow_of_odysseus":{"name":"The Bow of Odysseus","rarity":"unique","for":"ranger","slot":"weapon","kind":"bow","hands":2,"damage":[43.0,55.0],"speed":1.5,"bonus":{"dexterity":15,"vitality":8},
		"effect":"stunning_arrows","effect_text":"Your arrows have a 25% chance to stun the target for 2 seconds",
		"look":{"model":"bow","size":Vector3(.27,1.5,.11),"grip":.62,"finish":"bow","tint":Color(.74,.56,.24)}},

	# --- Carried, not worn or held: the key to the arena basement's gate,
	# which one of its bandits keeps (scripts/game.gd). Never random loot.
	"gate_key":{"name":"Rusted Gate Key","slot":"key"}}
# (`ALL` is the name the rest of the game has long used for the catalogue.)
const ALL = BASES

# --- Prefixes and suffixes ----------------------------------------------------------
# What a magic item's affix is put on: an armor weight, "shield", or a kind
# of weapon (category()). Staves are not melee weapons for this.
const ON_ALL = ["light","medium","heavy","shield","sword","spear","dagger","axe","mace","bow","staff"]
const ON_HARD = ["heavy","medium","shield"]
const ON_SOFT = ["light","dagger","staff"]
const ON_MELEE = ["heavy","medium","shield","sword","spear","dagger","axe","mace"]
# Each affix: its `name`, what it is put `on`, and what it does: `bonus`
# (attributes), `armor` or `damage` (percent more), `speed` (attacks a second
# more) or `spiked` (percent of a blocked attack's damage dealt back).
const PREFIXES = {
	"swift":{"name":"Swift","on":ON_HARD,"bonus":{"dexterity":5}},
	"brutal":{"name":"Brutal","on":ON_HARD,"bonus":{"strength":5}},
	"tough":{"name":"Tough","on":ON_ALL,"bonus":{"vitality":5}},
	"fine":{"name":"Fine","on":ON_SOFT,"bonus":{"intelligence":5}},
	"powerful":{"name":"Powerful","on":ON_ALL,"bonus":{"willpower":5}},
	"durable":{"name":"Durable","on":["light","medium","heavy","shield"],"armor":20.0},
	"sharpened":{"name":"Sharpened","on":["sword","spear","dagger","axe"],"damage":20.0},
	"heavy":{"name":"Heavy","on":["mace"],"damage":20.0},
	"lightweight":{"name":"Lightweight","on":["dagger","sword","spear","bow"],"speed":.2},
	"spiked":{"name":"Spiked","on":["shield"],"spiked":10.0}}
const SUFFIXES = {
	"zeus":{"name":"of Zeus","on":ON_MELEE,"bonus":{"strength":3,"dexterity":2}},
	"aphrodite":{"name":"of Aphrodite","on":ON_SOFT,"bonus":{"intelligence":3,"willpower":2}},
	"poseidon":{"name":"of Poseidon","on":ON_MELEE,"bonus":{"dexterity":3,"strength":2}},
	"athena":{"name":"of Athena","on":ON_SOFT,"bonus":{"willpower":3,"intelligence":2}},
	"apollo":{"name":"of Apollo","on":ON_MELEE,"bonus":{"dexterity":3,"willpower":2}},
	"demeter":{"name":"of Demeter","on":ON_ALL,"bonus":{"willpower":3,"vitality":2}},
	"hera":{"name":"of Hera","on":ON_SOFT,"bonus":{"intelligence":3,"vitality":2}},
	"hephaestus":{"name":"of Hephaestus","on":ON_MELEE,"bonus":{"strength":3,"vitality":2}},
	"dionysus":{"name":"of Dionysus","on":ON_ALL,"bonus":{"vitality":3,"willpower":2}},
	"hermes":{"name":"of Hermes","on":ON_MELEE,"bonus":{"dexterity":3,"vitality":2}}}
# The rare affixes: an item has one of these alone, or a prefix and a suffix
# from above.
const RARE_PREFIXES = {
	"enchanted":{"name":"Enchanted","on":ON_SOFT,"bonus":{"intelligence":10,"willpower":8}},
	"heros":{"name":"Hero's","on":ON_MELEE,"bonus":{"strength":12,"vitality":6}},
	"starry":{"name":"Starry","on":ON_SOFT,"bonus":{"intelligence":6,"willpower":6,"vitality":6}},
	"thiefs":{"name":"Thief's","on":["medium","dagger","sword"],"bonus":{"dexterity":12,"willpower":6}},
	"sorcerers":{"name":"Sorcerer's","on":ON_SOFT,"bonus":{"intelligence":8,"willpower":8,"vitality":4}}}
const RARE_SUFFIXES = {
	"hades":{"name":"of Hades","on":ON_MELEE,"bonus":{"strength":6,"dexterity":6,"vitality":6}},
	"ancients":{"name":"of the Ancients","on":ON_ALL,"bonus":{"vitality":10,"willpower":10}},
	"champion":{"name":"of the Champion","on":ON_MELEE,"bonus":{"strength":10,"vitality":8}}}

# A prefix or suffix by its id, uncommon or rare; {} for none.
static func prefix(id: String) -> Dictionary:
	return PREFIXES.get(id,RARE_PREFIXES.get(id,{}))
static func suffix(id: String) -> Dictionary:
	return SUFFIXES.get(id,RARE_SUFFIXES.get(id,{}))

# What a base item is for the affixes: its armor's weight, "shield", or its
# kind of weapon ("" for a key).
static func category(base_id: String) -> String:
	var base: Dictionary = BASES.get(base_id,{})
	if base.is_empty() or base.slot == "key": return ""
	if base.slot in ARMOR_SLOTS: return base.weight
	return base.kind

# Whether an affix may go on a base item: a common one only.
static func takes(base_id: String, affix: Dictionary) -> bool:
	return not affix.is_empty() and BASES.get(base_id,{}).get("rarity","") == "common" and category(base_id) in affix.on

# The prefixes and suffixes that may go on a base item (by id), uncommon
# (`rare` false) or rare.
static func prefixes_for(base_id: String, rare: bool = false) -> Array:
	return (RARE_PREFIXES if rare else PREFIXES).keys().filter(func(id): return takes(base_id,prefix(id)))
static func suffixes_for(base_id: String, rare: bool = false) -> Array:
	return (RARE_SUFFIXES if rare else SUFFIXES).keys().filter(func(id): return takes(base_id,suffix(id)))

# --- Instances -----------------------------------------------------------------

# An instance of a base item, with its prefix and suffix if any.
static func make(base_id: String, prefix_id: String = "", suffix_id: String = "") -> Dictionary:
	var made = {"base":base_id}
	if not prefix_id.is_empty(): made.prefix = prefix_id
	if not suffix_id.is_empty(): made.suffix = suffix_id
	return made

# Whether a thing is a well-formed instance of an item: a base that exists,
# and affixes that may be on it (a rare affix alone).
static func valid_instance(thing) -> bool:
	if not thing is Dictionary or not thing.get("base") is String or not BASES.has(thing.base): return false
	for key in thing:
		if not key in ["base","prefix","suffix"]: return false
	var p: String = thing.get("prefix","")
	var s: String = thing.get("suffix","")
	if not p is String or not s is String: return false
	if not p.is_empty() and not takes(thing.base,prefix(p)): return false
	if not s.is_empty() and not takes(thing.base,suffix(s)): return false
	if (RARE_PREFIXES.has(p) or RARE_SUFFIXES.has(s)) and not (p.is_empty() or s.is_empty()): return false
	return true

static func exists(thing) -> bool:
	return valid_instance(thing)

# An instance's rarity: its base's for a unique; rare with a rare affix or
# both an uncommon prefix and suffix; uncommon with one; else common (the
# starting gear too: it is white).
static func rarity(thing) -> String:
	var inst: Dictionary = thing if thing is Dictionary else {"base":thing}
	var base: Dictionary = BASES.get(inst.get("base",""),{})
	if base.get("rarity","") == "unique": return "unique"
	var p: String = inst.get("prefix","")
	var s: String = inst.get("suffix","")
	if RARE_PREFIXES.has(p) or RARE_SUFFIXES.has(s): return "rare"
	if not p.is_empty() and not s.is_empty(): return "rare"
	if not p.is_empty() or not s.is_empty(): return "uncommon"
	return "common"

static func color(thing) -> Color:
	return RARITY_COLORS[rarity(thing)]

# An instance's whole name: "Swift Steel Longsword of Zeus".
static func name_of(thing) -> String:
	var inst: Dictionary = thing if thing is Dictionary else {"base":thing}
	var base: Dictionary = BASES.get(inst.get("base",""),{})
	if base.is_empty(): return ""
	var words: String = base.name
	var p: Dictionary = prefix(inst.get("prefix",""))
	var s: Dictionary = suffix(inst.get("suffix",""))
	if not p.is_empty(): words = p.name+" "+words
	if not s.is_empty(): words += " "+s.name
	return words

static var resolved: Dictionary = {}

# An instance resolved to the item it is: its base's stats with its affixes
# worked in (`bonus` summed; armor, damage and speed raised; `spiked`;
# `rarity`, its whole `name`, and `affixes`, what each affix does, line by
# line). Also takes a base id. {} for nothing.
static func get_item(thing) -> Dictionary:
	if thing == null or (thing is String and thing.is_empty()): return {}
	var inst: Dictionary = thing if thing is Dictionary else {"base":thing}
	if inst.is_empty() or not BASES.has(inst.get("base","")): return {}
	var key = "%s|%s|%s" % [inst.base,inst.get("prefix",""),inst.get("suffix","")]
	if resolved.has(key): return resolved[key]
	var item: Dictionary = BASES[inst.base].duplicate(true)
	item.base = inst.base
	item.prefix = inst.get("prefix","")
	item.suffix = inst.get("suffix","")
	item.rarity = rarity(inst)
	item.name = name_of(inst)
	item.affixes = []
	var bonus: Dictionary = item.get("bonus",{}).duplicate()
	for affix in [prefix(item.prefix),suffix(item.suffix)]:
		if affix.is_empty(): continue
		for stat in affix.get("bonus",{}): bonus[stat] = bonus.get(stat,0)+affix.bonus[stat]
		if affix.has("armor") and item.has("armor"):
			item.armor = item.armor*(1.0+affix.armor*.01)
			item.affixes.append("%s: +%s%% armor" % [affix.name,figure(affix.armor)])
		if affix.has("damage") and item.has("damage"):
			item.damage = [item.damage[0]*(1.0+affix.damage*.01),item.damage[1]*(1.0+affix.damage*.01)]
			item.affixes.append("%s: +%s%% damage" % [affix.name,figure(affix.damage)])
		if affix.has("speed") and item.has("speed"):
			item.speed += affix.speed
			item.affixes.append("%s: +%s attacks per second" % [affix.name,figure(affix.speed)])
		if affix.has("spiked"):
			item.spiked = item.get("spiked",0.0)+affix.spiked
			item.affixes.append("%s: blocked attacks deal %s%% of their damage to the attacker" % [affix.name,figure(affix.spiked)])
	item.bonus = bonus
	resolved[key] = item
	return item

static func is_weapon(thing) -> bool:
	return get_item(thing).get("slot","") == "weapon"

static func is_shield(thing) -> bool:
	return get_item(thing).get("slot","") == "shield"

static func two_handed(thing) -> bool:
	return get_item(thing).get("hands",1) == 2

# --- Who may use what ---------------------------------------------------------------

# Why `class_id` cannot use the item at all, or "" if it can.
static func barred(class_id: String, thing) -> String:
	var item: Dictionary = get_item(thing)
	if item.is_empty(): return "Not an item."
	if item.slot == "key": return ""
	if item.slot in ARMOR_SLOTS:
		if item.weight != ARMOR_OF[class_id] and not item.get("any_class",false): return "%s: a %s cannot wear it." % [ARMOR_TITLES[item.weight],class_id]
	elif not item.kind in WIELDS[class_id]: return "A %s cannot use a %s." % [class_id,KIND_TITLES[item.kind].to_lower()]
	return ""

static func usable(class_id: String, thing) -> bool:
	return barred(class_id,thing).is_empty()

# Whether a hero of `class_id` wears this piece of armor as his own kit's
# (its weight his class's, or made for anyone).
static func wears(class_id: String, item: Dictionary) -> bool:
	return not item.is_empty() and item.get("slot","") in ARMOR_SLOTS and (item.get("weight","") == ARMOR_OF.get(class_id,"") or item.get("any_class",false))

# The base items that drop for `class_id`: the common ones it can use (the
# ground magic items are made on), and with `uniques` its own unique items.
static func loot(class_id: String, uniques: bool = false) -> Array:
	var pool: Array = []
	for id in BASES:
		var base: Dictionary = BASES[id]
		if uniques:
			if base.get("rarity","") == "unique" and base.get("for","") in [class_id,""]: pool.append(id)
		elif base.get("rarity","") == "common" and usable(class_id,id): pool.append(id)
	return pool

# --- Drops --------------------------------------------------------------------
# Any enemy that grants experience may drop one item as it dies: DROP_CHANCE
# percent by its kind. Its rarity is drawn by RARITY_WEIGHTS (the Crowned
# Statue's by BOSS_WEIGHTS), and the item made for the hero's class.
const DROP_CHANCE = {"bandit":9.0,"bandit_archer":9.0,"gladiator":11.0,"archer":11.0,"lion":11.0,"wizard":15.0,"centurion":15.0,"boss":100.0}

static func pick(rng: RandomNumberGenerator, list: Array):
	return list[rng.randi_range(0,list.size()-1)]

static func weighted(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var total = 0.0
	for key in weights: total += weights[key]
	var mark: float = rng.randf()*total
	for key in weights:
		mark -= weights[key]
		if mark < 0.0: return key
	return weights.keys()[-1]

# A common base item made magic, of `rarity`: an uncommon item has one
# affix, prefix or suffix; a rare one both, or one of the rare affixes.
static func enchant(base_id: String, wanted: String, rng: RandomNumberGenerator) -> Dictionary:
	if wanted == "common" or BASES.get(base_id,{}).get("rarity","") != "common": return make(base_id)
	var p: Array = prefixes_for(base_id)
	var s: Array = suffixes_for(base_id)
	if wanted == "uncommon":
		if rng.randf() < .5 and not p.is_empty(): return make(base_id,pick(rng,p))
		return make(base_id,"",pick(rng,s)) if not s.is_empty() else make(base_id,pick(rng,p))
	var rp: Array = prefixes_for(base_id,true)
	var rs: Array = suffixes_for(base_id,true)
	var both: bool = not p.is_empty() and not s.is_empty()
	if rng.randf() < .5 and both: return make(base_id,pick(rng,p),pick(rng,s))
	if rng.randf() < .5 and not rp.is_empty(): return make(base_id,pick(rng,rp))
	if not rs.is_empty(): return make(base_id,"",pick(rng,rs))
	if not rp.is_empty(): return make(base_id,pick(rng,rp))
	return make(base_id,pick(rng,p),pick(rng,s))

# An item of `wanted` rarity for `class_id`: one of its uniques, or a common
# base it can use, enchanted.
static func generate(class_id: String, wanted: String, rng: RandomNumberGenerator) -> Dictionary:
	if wanted == "unique":
		var own: Array = loot(class_id,true)
		if not own.is_empty(): return make(pick(rng,own))
		wanted = "rare"
	var pool: Array = loot(class_id)
	if pool.is_empty(): return {}
	return enchant(pick(rng,pool),wanted,rng)

# What an `enemy` of that kind drops for `class_id`: an item, or {} for nothing.
static func roll_drop(class_id: String, enemy: String, rng: RandomNumberGenerator) -> Dictionary:
	if rng.randf()*100.0 >= DROP_CHANCE.get(enemy,0.0): return {}
	return generate(class_id,weighted(rng,BOSS_WEIGHTS if enemy == "boss" else RARITY_WEIGHTS),rng)

# --- A run's equipment and bag ---------------------------------------------------

# What each class begins wearing and holding, and carrying in its bag.
const STARTING = {
	"warrior":{"equipment":{"head":"gladiators_helmet","chest":"scale_cuirass","legs":"studded_war_kilt","feet":"steel_plated_boots","hands":"steel_plated_gauntlets","main":"simple_shortsword","off":"lions_buckler"},"bag":[]},
	"ranger":{"equipment":{"head":"leather_hood","chest":"worn_leather_tunic","legs":"worn_leather_trousers","feet":"worn_leather_boots","hands":"worn_leather_gloves","main":"rangers_bow","off":""},"bag":["rangers_dagger"]},
	"wizard":{"equipment":{"head":"wool_hood","chest":"wool_robe","legs":"wool_trousers","feet":"sandals","hands":"wool_gloves","main":"twisted_silver_staff","off":""},"bag":[]}}
# The plainest weapon of each kind (what debug grants and tests hand out).
# (No spear is made yet: a hero armed with one goes bare-handed.)
const PLAIN = {"sword":"simple_shortsword","bow":"rangers_bow","dagger":"rangers_dagger","staff":"twisted_silver_staff","axe":"hatchet","mace":"war_hammer","shield":"lions_buckler"}

static func empty_equipment() -> Dictionary:
	var worn = {}
	for slot in SLOTS: worn[slot] = {}
	return worn

static func empty_bag() -> Array:
	var bag: Array = []
	for i in BAG_SIZE: bag.append({})
	return bag

# Gives a new character its class's starting gear.
static func outfit(run: Dictionary, class_id: String) -> void:
	run.equipment = empty_equipment()
	run.bag = empty_bag()
	var start: Dictionary = STARTING[class_id]
	for slot in start.equipment:
		if not start.equipment[slot].is_empty(): run.equipment[slot] = make(start.equipment[slot])
	for i in start.bag.size(): run.bag[i] = make(start.bag[i])

static func worn(run: Dictionary, slot: String) -> Dictionary:
	return get_item(run.equipment.get(slot,{}))

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

# Whether something worn or held has a unique `effect`, and what a spiked
# shield in hand deals back (percent of a blocked attack).
static func effect(run: Dictionary, name: String) -> bool:
	for slot in SLOTS:
		if worn(run,slot).get("effect","") == name: return true
	return false
static func spiked(run: Dictionary) -> float:
	return float(shield(run).get("spiked",0.0))

# The armor of all the hero wears and of the shield on his arm, and the
# percent less damage he takes for it.
static func armor(run: Dictionary) -> float:
	var total = 0.0
	for slot in ARMOR_SLOTS: total += float(worn(run,slot).get("armor",0.0))
	return total+float(shield(run).get("armor",0.0))

static func reduction_of(points: float) -> float:
	return minf(ARMOR_CAP,100.0*points/(points+ARMOR_SCALE)) if points > 0.0 else 0.0

static func reduction(run: Dictionary) -> float:
	return reduction_of(armor(run))

# The first weapon in the bag of one of `kinds` that the class can use: its
# place there, or -1.
static func bagged(run: Dictionary, kinds: Array) -> int:
	for i in run.bag.size():
		var item: Dictionary = get_item(run.bag[i])
		if not item.is_empty() and item.slot == "weapon" and item.kind in kinds and usable(run.class_id,run.bag[i]): return i
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
	return get_item(run.bag[found]) if found >= 0 else {}

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

# How many attacks a second the weapon a blow of `tag` is made with makes
# (bare hands UNARMED_SPEED), and how long one takes.
static func attack_speed(run: Dictionary, tag: String = "melee") -> float:
	var weapon: Dictionary = weapon_for(run,tag)
	return float(weapon.get("speed",UNARMED_SPEED)) if not weapon.is_empty() else UNARMED_SPEED
static func seconds(run: Dictionary, tag: String = "melee") -> float:
	return 1.0/maxf(.1,attack_speed(run,tag))

# --- Moving things about ---------------------------------------------------------
# A place is a slot's name ("head", "main"...) or "bag:3".

static func in_bag(place: String) -> bool:
	return place.begins_with("bag:")

static func at(run: Dictionary, place: String) -> Dictionary:
	if in_bag(place): return run.bag[int(place.trim_prefix("bag:"))]
	return run.equipment.get(place,{})

static func put(run: Dictionary, place: String, inst: Dictionary) -> void:
	if in_bag(place): run.bag[int(place.trim_prefix("bag:"))] = inst
	else: run.equipment[place] = inst

static func free_bag_slot(run: Dictionary, except: String = "") -> int:
	for i in run.bag.size():
		if run.bag[i].is_empty() and "bag:%d" % i != except: return i
	return -1

static func free_places(run: Dictionary) -> int:
	var count = 0
	for inst in run.bag:
		if inst.is_empty(): count += 1
	return count

# Whether the bag holds an item of that base (the gate key).
static func carries(run: Dictionary, base_id: String) -> bool:
	for inst in run.bag:
		if not inst.is_empty() and inst.get("base","") == base_id: return true
	return false

# Why the item cannot go in that equipment slot, or "".
static func misfit(run: Dictionary, inst: Dictionary, slot: String) -> String:
	var no: String = barred(run.class_id,inst)
	if not no.is_empty(): return no
	var item: Dictionary = get_item(inst)
	if item.slot == "key": return "A key is carried, not worn or held."
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
	var inst: Dictionary = at(run,from)
	if inst.is_empty(): return "Nothing there."
	var other: Dictionary = at(run,to)
	if not in_bag(to):
		var no: String = misfit(run,inst,to)
		if not no.is_empty(): return no
	if not in_bag(from) and not other.is_empty():
		# What is displaced must be able to take the place left.
		var no: String = misfit(run,other,from)
		if not no.is_empty(): return no
	# The other hand, when a two-handed weapon is taken up or made room for.
	var spill_from = ""
	if to == "main" and two_handed(inst) and not run.equipment.off.is_empty() and from != "off": spill_from = "off"
	elif to == "off" and two_handed(run.equipment.main) and from != "main": spill_from = "main"
	elif from == "off" and to == "main" and two_handed(other): return "A two-handed weapon is held in the main hand."
	if not spill_from.is_empty():
		var spill: Dictionary = run.equipment[spill_from]
		# (It may go where the item came from, if nothing else is going there.)
		var room: int = free_bag_slot(run)
		if room < 0 and not (in_bag(from) and other.is_empty()): return "No room in the bag."
		put(run,to,inst)
		put(run,from,other)
		run.equipment[spill_from] = {}
		run.bag[free_bag_slot(run)] = spill
		return ""
	put(run,to,inst)
	put(run,from,other)
	return ""

# Where a right-clicked bag item would be equipped: its armor slot, or a hand
# (a shield or a second one-handed weapon the off hand, if the main is full).
static func slot_for(run: Dictionary, inst: Dictionary) -> String:
	var item: Dictionary = get_item(inst)
	if item.is_empty() or item.slot == "key": return ""
	if item.slot in ARMOR_SLOTS: return item.slot
	if item.slot == "shield": return "off"
	if item.hands == 1 and not run.equipment.main.is_empty() and not two_handed(run.equipment.main) and run.equipment.off.is_empty() and item.kind != "bow": return "off"
	return "main"

# Puts a found item in the first free place in the bag; false if it is full.
static func stow(run: Dictionary, inst: Dictionary) -> bool:
	var room: int = free_bag_slot(run)
	if room < 0: return false
	run.bag[room] = inst
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
	run.equipment.main = make(PLAIN[kind_name]) if PLAIN.has(kind_name) else {}
	run.equipment.off = make(PLAIN.shield) if with_shield and not two_handed(run.equipment.main) else {}

# --- Words ---------------------------------------------------------------------

# How long a weapon is, butt to point (metres).
static func length(look: Dictionary) -> float:
	return look.get("length",look.size.y)

# A number as few figures as it needs.
static func figure(amount: float) -> String:
	return String.num(snappedf(amount,.01)).trim_suffix(".0")

# What an item is, line by line, for its tip: {"title","kind","stats"
# (lines),"effect","note","rarity"}.
static func describe(thing, class_id: String = "") -> Dictionary:
	var item: Dictionary = get_item(thing)
	if item.is_empty(): return {"title":"","kind":"","stats":[],"effect":"","note":"","rarity":"common"}
	var lines: Array = []
	var what = ""
	if item.slot == "key":
		what = "Key"
		lines.append("Opens the locked gate at the end of the basement's hallway")
	elif item.slot in ARMOR_SLOTS:
		what = "%s · %s" % [ARMOR_TITLES[item.weight],SLOT_TITLES[item.slot]]
		lines.append("%s armor" % figure(item.armor))
	elif item.slot == "shield":
		what = "Shield · Off hand"
		if item.get("armor",0.0) > 0.0: lines.append("%s armor" % figure(item.armor))
		lines.append("%s%% chance to block" % figure(item.block))
		lines.append("Blocked attacks deal %s%% less" % figure(item.mitigation))
	else:
		what = "%s · %s" % [KIND_TITLES[item.kind],"Two-handed" if item.hands == 2 else "One-handed"]
		if item.has("damage"):
			lines.append("%s–%s damage" % [figure(item.damage[0]),figure(item.damage[1])])
			lines.append("%s attacks per second" % figure(item.speed))
		else: lines.append("Spells take their damage from Intelligence")
	for key in BONUS_TEXT:
		if item.bonus.get(key,0) != 0: lines.append(BONUS_TEXT[key] % figure(item.bonus[key]))
	for line in item.affixes: lines.append(line)
	var effect_text: String = item.get("effect_text","")
	if class_id == "wizard": effect_text = effect_text.replace("energy","mana")
	return {"title":item.name,"kind":what,"stats":lines,"effect":effect_text,"note":"" if class_id.is_empty() else barred(class_id,thing),"rarity":item.rarity}
