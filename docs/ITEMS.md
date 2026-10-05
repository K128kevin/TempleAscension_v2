# Items

Everything here is defined in `scripts/items.gd`. The tables below are printed
from that file by `tools/item_table.gd`; after changing an item, a drop chance
or a rarity weight, run it again and paste its output over them:

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

A class wears only its own weight of armor. Swords and axes come one-handed and
two-handed; maces and daggers are one-handed; spears, bows and staves are
two-handed.

## What the numbers do

- **Armor**: each piece takes its percent off every blow the hero takes, of
  any kind. The pieces add up, to 75% at most. The three starting sets give
  26% (heavy), 17% (medium) and 10% (light).
- **Weapon damage**: a weapon's range (say 10–15) is what one normal attack
  hits for before attributes, and the baseline of every skill made with it:
  a skill that deals 200% deals 200% of that roll. Strength raises melee
  damage and Dexterity bow damage, 2% a point, as before.
- **Two weapons**: with a weapon in each hand, every blow adds half the off
  hand's damage range to the main hand's, and the hands strike by turns.
- **Wizards**: a wizard's spells, and his staff's bolts, do not use weapon
  damage. Their baseline is fixed at 10–15, raised 2% for each point of
  Intelligence. A staff has no damage range; it may carry **spell damage**,
  a percent added to all of it. A wizard's spells can be cast with anything
  in hand, or nothing. A dagger in a wizard's hand stabs for its own damage,
  by Strength.
- **Bare hands** hit for 1–3.
- **Shields**: the chance to block an attack, and how much less a blocked
  attack deals. Shield Bash and Shield Charge need one.
- **Reach**: a spear strikes from 2.9 m and a two-handed weapon from 2.3 m,
  against 1.9 m for one-handed weapons and daggers.
- **Bonuses** on an item apply while it is worn or held: attribute points
  (counted exactly as points spent), critical strike chance, attack speed,
  movement speed, maximum health or energy, spell damage, and health restored
  on each hit landed.

## Drops

- Every enemy that grants experience can drop **one** item when it dies. The
  chance depends on the enemy: bandits 8%, gladiators, archers and lions 10%,
  Oracles and centurions 14%, the Crowned Statue 100%.
- The item is drawn only from those the hero's class can use, each weighted by
  rarity: common 10, uncommon 5, rare 2. The Crowned Statue always drops a
  rare item.
- The centurions the Crowned Statue summons drop nothing, and an enemy killed
  again after a death and retry drops nothing a second time.
- A dropped item lies on the ground as its own model, with its name over it in
  its rarity's colour (cream, green, blue). Click the name to pick it up; from
  further away the hero walks to it first. With a full bag it stays there.
- Items on the ground are kept in the save for the floor they fell on, and are
  left behind when the hero changes floor.

## The items


### Starting equipment

**Warrior** (heavy armor)

| Slot | Item | What it gives |
|---|---|---|
| Head | Gladiator's Helm | Heavy armor · Head: 5% less damage taken |
| Chest | Scale Cuirass | Heavy armor · Chest: 9% less damage taken |
| Legs | Studded War Kilt | Heavy armor · Legs: 6% less damage taken |
| Feet | Strapped Sandals | Heavy armor · Feet: 3% less damage taken |
| Hands | Steel Manica | Heavy armor · Hands: 3% less damage taken |
| Main hand | Legionary's Sword | Sword · One-handed: 10–15 damage |
| Off hand | Lion Shield | Shield · Off hand: 25% chance to block; Blocked attacks deal 20% less |

**Ranger** (medium armor)

| Slot | Item | What it gives |
|---|---|---|
| Head | Hooded Cloak | Medium armor · Head: 3% less damage taken |
| Chest | Tattered Wool Tunic | Medium armor · Chest: 6% less damage taken |
| Legs | Trousers and Knee Guards | Medium armor · Legs: 4% less damage taken |
| Feet | Strapped Leather Boots | Medium armor · Feet: 2% less damage taken |
| Hands | Laced Bracers | Medium armor · Hands: 2% less damage taken |
| Main hand | Yew Longbow | Bow · Two-handed: 10–15 damage |
| Bag | Hunting Dagger | Dagger · One-handed: 10–15 damage |

**Wizard** (light armor)

| Slot | Item | What it gives |
|---|---|---|
| Head | Deep Hood | Light armor · Head: 2% less damage taken |
| Chest | Navy Wool Robe | Light armor · Chest: 4% less damage taken |
| Legs | Dark Wool Trousers | Light armor · Legs: 2% less damage taken |
| Feet | Worn Leather Boots | Light armor · Feet: 1% less damage taken |
| Hands | Wrapped Bracers | Light armor · Hands: 1% less damage taken |
| Main hand | Twisted Silver Staff | Staff · Two-handed: Spells take their damage from Intelligence; +5% spell damage |

### Items that drop

| Item | Rarity | Kind | Used by | What it gives |
|---|---|---|---|---|
| Bandit's Sica | Common | Sword · One-handed | Warrior, Ranger | 12–17 damage; +5% attack speed |
| Bronze Hatchet | Common | Axe · One-handed | Warrior | 13–19 damage; +3% critical strike chance |
| Flanged Mace | Uncommon | Mace · One-handed | Warrior | 15–19 damage; +3 Strength |
| Centurion's Greatsword | Uncommon | Sword · Two-handed | Warrior, Ranger | 22–32 damage; +2 Strength |
| Executioner's Axe | Rare | Axe · Two-handed | Warrior | 25–37 damage; +5% critical strike chance |
| Legionary's Hasta | Uncommon | Spear · Two-handed | Warrior | 18–26 damage; +2 Dexterity |
| Hunter's Recurve | Uncommon | Bow · Two-handed | Warrior, Ranger | 13–18 damage; +4% critical strike chance |
| Viper's Fang | Uncommon | Dagger · One-handed | Ranger, Wizard | 12–17 damage; Restores 2 health on each hit |
| Oracle's Staff | Rare | Staff · Two-handed | Wizard | Spells take their damage from Intelligence; +20% spell damage; +3 Intelligence |
| Ashwood Staff | Common | Staff · Two-handed | Wizard | Spells take their damage from Intelligence; +10% spell damage |
| Bandit's Buckler | Common | Shield · Off hand | Warrior | 18% chance to block; Blocked attacks deal 30% less |
| Bronze Aspis | Rare | Shield · Off hand | Warrior | 32% chance to block; Blocked attacks deal 28% less; +3 Vitality |
| Bronze Arena Helm | Uncommon | Heavy armor · Head | Warrior | 8% less damage taken; +2 Vitality |
| Bronze Scale Cuirass | Rare | Heavy armor · Chest | Warrior | 13% less damage taken; +25 maximum health |
| Blackened Manica | Common | Heavy armor · Hands | Warrior | 5% less damage taken; +2 Strength |
| Dusk Cloak | Uncommon | Medium armor · Head | Ranger | 5% less damage taken; +5% movement speed |
| Stalker's Jerkin | Rare | Medium armor · Chest | Ranger | 9% less damage taken; +3 Dexterity |
| Swiftfoot Boots | Common | Medium armor · Feet | Ranger | 3% less damage taken; +4% movement speed |
| Crimson Hood | Uncommon | Light armor · Head | Wizard | 4% less damage taken; +2 Intelligence |
| Ember Robe | Rare | Light armor · Chest | Wizard | 7% less damage taken; +10% spell damage |
| Seer's Bracers | Common | Light armor · Hands | Wizard | 2% less damage taken; +3 Willpower |

### Drop chances

Chance that one kill drops that particular item, in percent.

**Warrior**

| Item | Bandit | Bandit Archer | Gladiator | Archer | Lion Guardian | Oracle | Centurion | The Crowned Statue |
|---|---|---|---|---|---|---|---|---|
| Bandit's Sica | 1.13 | 1.13 | 1.41 | 1.41 | 1.41 | 1.97 | 1.97 | – |
| Bronze Hatchet | 1.13 | 1.13 | 1.41 | 1.41 | 1.41 | 1.97 | 1.97 | – |
| Flanged Mace | 0.56 | 0.56 | 0.70 | 0.70 | 0.70 | 0.99 | 0.99 | – |
| Centurion's Greatsword | 0.56 | 0.56 | 0.70 | 0.70 | 0.70 | 0.99 | 0.99 | – |
| Executioner's Axe | 0.23 | 0.23 | 0.28 | 0.28 | 0.28 | 0.39 | 0.39 | 33.33 |
| Legionary's Hasta | 0.56 | 0.56 | 0.70 | 0.70 | 0.70 | 0.99 | 0.99 | – |
| Hunter's Recurve | 0.56 | 0.56 | 0.70 | 0.70 | 0.70 | 0.99 | 0.99 | – |
| Bandit's Buckler | 1.13 | 1.13 | 1.41 | 1.41 | 1.41 | 1.97 | 1.97 | – |
| Bronze Aspis | 0.23 | 0.23 | 0.28 | 0.28 | 0.28 | 0.39 | 0.39 | 33.33 |
| Bronze Arena Helm | 0.56 | 0.56 | 0.70 | 0.70 | 0.70 | 0.99 | 0.99 | – |
| Bronze Scale Cuirass | 0.23 | 0.23 | 0.28 | 0.28 | 0.28 | 0.39 | 0.39 | 33.33 |
| Blackened Manica | 1.13 | 1.13 | 1.41 | 1.41 | 1.41 | 1.97 | 1.97 | – |
| *Any item* | *8* | *8* | *10* | *10* | *10* | *14* | *14* | *100* |

**Ranger**

| Item | Bandit | Bandit Archer | Gladiator | Archer | Lion Guardian | Oracle | Centurion | The Crowned Statue |
|---|---|---|---|---|---|---|---|---|
| Bandit's Sica | 1.90 | 1.90 | 2.38 | 2.38 | 2.38 | 3.33 | 3.33 | – |
| Centurion's Greatsword | 0.95 | 0.95 | 1.19 | 1.19 | 1.19 | 1.67 | 1.67 | – |
| Hunter's Recurve | 0.95 | 0.95 | 1.19 | 1.19 | 1.19 | 1.67 | 1.67 | – |
| Viper's Fang | 0.95 | 0.95 | 1.19 | 1.19 | 1.19 | 1.67 | 1.67 | – |
| Dusk Cloak | 0.95 | 0.95 | 1.19 | 1.19 | 1.19 | 1.67 | 1.67 | – |
| Stalker's Jerkin | 0.38 | 0.38 | 0.48 | 0.48 | 0.48 | 0.67 | 0.67 | 100.00 |
| Swiftfoot Boots | 1.90 | 1.90 | 2.38 | 2.38 | 2.38 | 3.33 | 3.33 | – |
| *Any item* | *8* | *8* | *10* | *10* | *10* | *14* | *14* | *100* |

**Wizard**

| Item | Bandit | Bandit Archer | Gladiator | Archer | Lion Guardian | Oracle | Centurion | The Crowned Statue |
|---|---|---|---|---|---|---|---|---|
| Viper's Fang | 1.18 | 1.18 | 1.47 | 1.47 | 1.47 | 2.06 | 2.06 | – |
| Oracle's Staff | 0.47 | 0.47 | 0.59 | 0.59 | 0.59 | 0.82 | 0.82 | 50.00 |
| Ashwood Staff | 2.35 | 2.35 | 2.94 | 2.94 | 2.94 | 4.12 | 4.12 | – |
| Crimson Hood | 1.18 | 1.18 | 1.47 | 1.47 | 1.47 | 2.06 | 2.06 | – |
| Ember Robe | 0.47 | 0.47 | 0.59 | 0.59 | 0.59 | 0.82 | 0.82 | 50.00 |
| Seer's Bracers | 2.35 | 2.35 | 2.94 | 2.94 | 2.94 | 4.12 | 4.12 | – |
| *Any item* | *8* | *8* | *10* | *10* | *10* | *14* | *14* | *100* |

