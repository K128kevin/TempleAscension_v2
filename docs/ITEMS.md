# Items

Everything here is defined in `scripts/items.gd`. The tables below are printed
from that file by `tools/item_table.gd`; after changing an item, an affix, a
drop chance or a rarity weight, run it again and paste its output over them:

```sh
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/item_table.gd
```

## Slots

A hero wears armor in five slots (**head, chest, legs, feet, hands**) and holds
things in two (**main hand, off hand**): one two-handed weapon, two one-handed
weapons, or a one-handed weapon and a shield. His bag holds ten more items.

## Who can use what

| Class | Armor | Weapons |
|---|---|---|
| Warrior | Heavy | Swords, maces, axes, spears, bows, shields |
| Ranger | Medium | Bows, daggers, swords |
| Wizard | Light | Staves, daggers |

A class wears only its own weight of armor (the Marathon Boots, made for
everyone, are the one exception). Swords come one-handed and two-handed, maces
two-handed (the war hammer), axes and daggers one-handed; bows and staves are
two-handed. (No spear is made yet; the spear's own motions are kept for one.)

## Rarity

- **Starting gear and common items** are white. The starting gear never
  drops. The common items drop, and are what every magic item is made of.
- **Uncommon** (green): a common item with one **prefix** or one **suffix**.
- **Rare** (blue): a common item with both a prefix and a suffix, or with
  one of the **rare** prefixes or suffixes alone.
- **Unique** (purple): one of a kind, with an effect of its own. Each class
  has one that drops for it alone; the Marathon Boots drop for everyone.

An item in play is its base with its affixes, so "Swift Steel Full Helm of
Zeus" is a Steel Full Helm with Swift's Dexterity and Zeus's Strength and
Dexterity on top of its own. Its picture is its base's.

## What the numbers do

- **Armor** is a number: all the hero wears adds up (A), with the armor of
  the shield on his arm, and takes A/(A+150) off every blow he takes, of any
  kind, to 75% at most. The starting sets add to 108 (heavy, with the
  buckler's 17, 41.9% off), 58 (medium, 27.9%) and 31 (light, 17.1%). Durable adds a fifth to a piece's
  armor.
- **Weapon damage**: a weapon's range (say 20–28) is what one normal attack
  hits for before attributes, and the baseline of every skill made with it:
  a skill that deals 200% deals 200% of that roll. Strength raises melee
  damage and Dexterity bow damage, 2% a point. Sharpened and Heavy add a
  fifth to the range.
- **Attacks per second** is each weapon's own: a Simple Shortsword swings 1.3
  times a second, a War Hammer 0.9, a Ranger's Dagger 2. Dexterity, Quick
  Strikes, Frenzy and Rallying Cry quicken it from there; Lightweight adds 0.2
  attacks a second. The skills struck with the weapon's own swing (Vampiric
  and Shadow Strike) take its time too; the warrior's other skills keep their
  own motions' times.
- **Two weapons**: with a weapon in each hand, every blow adds half the off
  hand's damage range to the main hand's, the main hand sets the pace, and
  the hands strike by turns.
- **Wizards**: a wizard's spells, and his staff's bolts, do not use weapon
  damage. Their baseline is fixed at 10–15, raised 2% for each point of
  Intelligence (so a staff's Intelligence raises them). A wizard's spells
  can be cast with anything in hand, or nothing. A dagger in a wizard's hand
  stabs for its own damage, by Strength.
- **Bare hands** hit for 1–3, twice a second.
- **Shields**: armor, counted with what is worn; the chance to block an
  attack, and how much less a blocked attack deals. Shield Bash and Shield
  Charge need one. Durable adds a fifth to a shield's armor, as to any
  piece; Spiked deals a tenth of a blocked attack's damage back to the
  attacker.
- **Reach**: a two-handed sword or hammer strikes from 2.3 m, against 1.9 m
  for one-handed weapons and daggers.
- **Attributes** on an item count exactly as points spent on them, while it
  is worn or held; the Marathon Boots' movement speed likewise.

## The uniques' effects

- **Robe of the Lost Emperor** (wizard): every time a spell damages a target,
  a 10% chance to recover 20 mana.
- **Ancient Gladiator's Helmet** (warrior): every attack has a 10% chance to
  grant **Rallying Cry**, 25% more attack speed and damage for 10 seconds,
  at most once every 30 seconds. It shows on the buff bar.
- **The Bow of Odysseus** (ranger): each arrow has a 25% chance to stun its
  target for 2 seconds (as Shield Bash's stun, shorter when repeated).
- **Marathon Boots** (everyone): +6 to every attribute and 20% faster
  movement; light armor any class may wear.
- **Lightning Hammer** (warrior): a two-handed hammer; each hit has a 10%
  chance to call lightning down on its target for 200–300 damage, which
  leaps to up to 4 more targets within 10 m, a quarter weaker with each leap.
- **Ice Queen's Gloves** (wizard): +15 Intelligence, Vitality and Willpower
  and 25% more spell damage, but no frost spell can be cast while they are
  worn (Freeze Floor and Frost Blast end at once).

## Drops

- Every enemy that grants experience can drop **one** item when it dies. The
  chance depends on the enemy: bandits 9%, gladiators, archers and lions 11%,
  Oracles and centurions 15%, the Crowned Statue 100%.
- What drops is made for the hero's class: its rarity is drawn by weight
  (common 58, uncommon 28, rare 11, unique 3; the Crowned Statue rare 75,
  unique 25), then a common item the class can use is drawn and given its
  affixes, or one of the class's uniques is chosen.
- The centurions the Crowned Statue summons drop nothing, and an enemy killed
  again after a death and retry drops nothing a second time.
- A dropped item lies on the ground as its own model, with its name over it
  in its rarity's colour. Click the name to pick it up; from further away the
  hero walks to it first. With a full bag it stays there.
- Items on the ground are kept in the save for the floor they fell on, and are
  left behind when the hero changes floor.
- In debug mode, F5 opens the item browser: every base item, each put in the
  bag with a click, and beside each common one U and R buttons that put in a
  random uncommon or rare one made of it; F6 drops a random item.

## The items

Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

### Starting equipment

**Warrior** (heavy armor)

| Slot | Item | What it gives |
|---|---|---|
| Head | Gladiator's Helmet | Heavy armor · Head: 15 armor |
| Chest | Scale Cuirass | Heavy armor · Chest: 23 armor |
| Legs | Studded War Kilt | Heavy armor · Legs: 23 armor |
| Feet | Steel Plated Boots | Heavy armor · Feet: 15 armor |
| Hands | Steel Plated Gauntlets | Heavy armor · Hands: 15 armor |
| Main hand | Simple Shortsword | Sword · One-handed: 17–25 damage; 1.3 attacks per second |
| Off hand | Lion's Buckler | Shield · Off hand: 17 armor; 25% chance to block; Blocked attacks deal 30% less |

**Ranger** (medium armor)

| Slot | Item | What it gives |
|---|---|---|
| Head | Leather Hood | Medium armor · Head: 10 armor |
| Chest | Worn Leather Tunic | Medium armor · Chest: 15 armor |
| Legs | Worn Leather Trousers | Medium armor · Legs: 15 armor |
| Feet | Worn Leather Boots | Medium armor · Feet: 9 armor |
| Hands | Worn Leather Gloves | Medium armor · Hands: 9 armor |
| Main hand | Ranger's Bow | Bow · Two-handed: 16–24 damage; 1.2 attacks per second |
| Bag | Ranger's Dagger | Dagger · One-handed: 12–20 damage; 2 attacks per second |

**Wizard** (light armor)

| Slot | Item | What it gives |
|---|---|---|
| Head | Wool Hood | Light armor · Head: 5 armor |
| Chest | Wool Robe | Light armor · Chest: 8 armor |
| Legs | Wool Trousers | Light armor · Legs: 8 armor |
| Feet | Sandals | Light armor · Feet: 5 armor |
| Hands | Wool Gloves | Light armor · Hands: 5 armor |
| Main hand | Twisted Silver Staff | Staff · Two-handed: Spells take their damage from Intelligence; +4 Intelligence |

### Common items

What drops, and what the prefixes and suffixes are put on.

| Item | Kind | Used by | What it gives |
|---|---|---|---|
| Silk Gloves | Light armor · Hands | Wizard | 5 armor; +2 Intelligence |
| Silk Robe | Light armor · Chest | Wizard | 8 armor; +3 Intelligence |
| Silk Pants | Light armor · Legs | Wizard | 8 armor; +2 Intelligence |
| Wizard Hat | Light armor · Head | Wizard | 4 armor; +2 Intelligence |
| Sandals | Light armor · Feet | Wizard | 5 armor |
| Leather Gloves | Medium armor · Hands | Ranger | 10 armor |
| Fingerless Leather Gloves | Medium armor · Hands | Ranger | 7 armor; +2 Dexterity |
| Leather Tunic | Medium armor · Chest | Ranger | 18 armor |
| Studded Leather Tunic | Medium armor · Chest | Ranger | 20 armor |
| Leather Boots | Medium armor · Feet | Ranger | 12 armor |
| Leather Hood | Medium armor · Head | Ranger | 10 armor |
| Steel Breastplate | Heavy armor · Chest | Warrior | 21 armor; +2 Strength |
| Scale Cuirass | Heavy armor · Chest | Warrior | 23 armor |
| Plated Leg Armor | Heavy armor · Legs | Warrior | 26 armor |
| Steel Full Helm | Heavy armor · Head | Warrior | 20 armor |
| Steel Longsword | Sword · One-handed | Warrior, Ranger | 20–28 damage; 1.1 attacks per second |
| Steel Shortsword | Sword · One-handed | Warrior, Ranger | 16–22 damage; 1.5 attacks per second |
| Gladiator's Round Shield | Shield · Off hand | Warrior | 20 armor; 25% chance to block; Blocked attacks deal 20% less; +1 Strength; +1 Dexterity |
| Tower Shield | Shield · Off hand | Warrior | 25 armor; 28% chance to block; Blocked attacks deal 28% less |
| Hunter's Bow | Bow · Two-handed | Warrior, Ranger | 15–23 damage; 1.5 attacks per second; +1 Dexterity |
| Longbow | Bow · Two-handed | Warrior, Ranger | 20–27 damage; 1 attacks per second |
| Bandit Blade | Dagger · One-handed | Ranger, Wizard | 16–24 damage; 1.7 attacks per second |
| Greatsword | Sword · Two-handed | Warrior, Ranger | 30–42 damage; 1.2 attacks per second |
| War Hammer | Mace · Two-handed | Warrior | 35–45 damage; 0.9 attacks per second |
| Hatchet | Axe · One-handed | Warrior | 16–24 damage; 1.6 attacks per second |
| Gnarled Staff | Staff · Two-handed | Wizard | Spells take their damage from Intelligence; +3 Intelligence; +2 Vitality; +2 Willpower |
| Crystal Staff | Staff · Two-handed | Wizard | Spells take their damage from Intelligence; +4 Intelligence; +4 Willpower |

### Prefixes and suffixes

An uncommon item is a common item with one of these; a rare item has a prefix and a suffix, or one of the rare ones alone.

**Prefixes**

| Affix | What it gives | Goes on |
|---|---|---|
| Swift | +5 Dexterity | heavy armor, medium armor, shields |
| Brutal | +5 Strength | heavy armor, medium armor, shields |
| Tough | +5 Vitality | all items |
| Fine | +5 Intelligence | light armor, daggers, staves |
| Powerful | +5 Willpower | all items |
| Durable | +20% armor | light armor, medium armor, heavy armor, shields |
| Sharpened | +20% damage | swords, spears, daggers, axes |
| Heavy | +20% damage | maces |
| Lightweight | +0.2 attacks per second | daggers, swords, spears, bows |
| Spiked | Blocked attacks deal 10% of their damage to the attacker | shields |

**Suffixes**

| Affix | What it gives | Goes on |
|---|---|---|
| of Zeus | +3 Strength, +2 Dexterity | heavy armor, medium armor, shields, swords, spears, daggers, axes, maces |
| of Aphrodite | +3 Intelligence, +2 Willpower | light armor, daggers, staves |
| of Poseidon | +2 Strength, +3 Dexterity | heavy armor, medium armor, shields, swords, spears, daggers, axes, maces |
| of Athena | +2 Intelligence, +3 Willpower | light armor, daggers, staves |
| of Apollo | +3 Dexterity, +2 Willpower | heavy armor, medium armor, shields, swords, spears, daggers, axes, maces |
| of Demeter | +2 Vitality, +3 Willpower | all items |
| of Hera | +3 Intelligence, +2 Vitality | light armor, daggers, staves |
| of Hephaestus | +3 Strength, +2 Vitality | heavy armor, medium armor, shields, swords, spears, daggers, axes, maces |
| of Dionysus | +3 Vitality, +2 Willpower | all items |
| of Hermes | +3 Dexterity, +2 Vitality | heavy armor, medium armor, shields, swords, spears, daggers, axes, maces |

**Rare prefixes**

| Affix | What it gives | Goes on |
|---|---|---|
| Enchanted | +10 Intelligence, +8 Willpower | light armor, daggers, staves |
| Hero's | +12 Strength, +6 Vitality | heavy armor, medium armor, shields, swords, spears, daggers, axes, maces |
| Starry | +6 Intelligence, +6 Vitality, +6 Willpower | light armor, daggers, staves |
| Thief's | +12 Dexterity, +6 Willpower | medium armor, daggers, swords |
| Sorcerer's | +8 Intelligence, +4 Vitality, +8 Willpower | light armor, daggers, staves |

**Rare suffixes**

| Affix | What it gives | Goes on |
|---|---|---|
| of Hades | +6 Strength, +6 Dexterity, +6 Vitality | heavy armor, medium armor, shields, swords, spears, daggers, axes, maces |
| of the Ancients | +10 Vitality, +10 Willpower | all items |
| of the Champion | +10 Strength, +8 Vitality | heavy armor, medium armor, shields, swords, spears, daggers, axes, maces |

### Unique items

| Item | Kind | Drops for | What it gives |
|---|---|---|---|
| Robe of the Lost Emperor | Light armor · Chest | Wizard | 10 armor; +12 Intelligence; +8 Vitality; +10 Willpower. Every time your spells damage a target there is a 10% chance you recover 20 energy |
| Ancient Gladiator's Helmet | Heavy armor · Head | Warrior | 22 armor; +15 Strength; +12 Dexterity. Every attack has a 10% chance to grant Rallying Cry: 25% more attack speed and damage for 10 seconds, at most once every 30 seconds |
| Marathon Boots | Light armor · Feet | Everyone | 8 armor; +6 Strength; +6 Dexterity; +6 Intelligence; +6 Vitality; +6 Willpower; +20% movement speed |
| The Bow of Odysseus | Bow · Two-handed | Ranger | 43–55 damage; 1.5 attacks per second; +15 Dexterity; +8 Vitality. Your arrows have a 25% chance to stun the target for 2 seconds |
| Lightning Hammer | Mace · Two-handed | Warrior | 60–76 damage; 0.8 attacks per second; +15 Strength; +12 Vitality. 10% chance on hit to call down lightning on the target for 200–300 damage, leaping to up to 4 more targets, 25% weaker with each leap |
| Ice Queen's Gloves | Light armor · Hands | Wizard | 8 armor; +15 Intelligence; +15 Vitality; +15 Willpower; +25% spell damage. You cannot use any frost abilities |

### Drop chances

Chance that one kill drops an item of that rarity, in percent (the item is made for the hero's class).

| Enemy | Any item | Common | Uncommon | Rare | Unique |
|---|---|---|---|---|---|
| Bandit | 9 | 5.22 | 2.52 | 0.99 | 0.27 |
| Bandit Archer | 9 | 5.22 | 2.52 | 0.99 | 0.27 |
| Gladiator | 11 | 6.38 | 3.08 | 1.21 | 0.33 |
| Archer | 11 | 6.38 | 3.08 | 1.21 | 0.33 |
| Lion Guardian | 11 | 6.38 | 3.08 | 1.21 | 0.33 |
| Oracle | 15 | 8.70 | 4.20 | 1.65 | 0.45 |
| Centurion | 15 | 8.70 | 4.20 | 1.65 | 0.45 |
| The Crowned Statue | 100 | – | – | 75.00 | 25.00 |
