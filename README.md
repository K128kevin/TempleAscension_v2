# Temple Ascension 3D

Native Godot adaptation of `/Users/ktabb/Documents/workspace/TempleAscension`.
Choose Warrior, Ranger or Wizard when creating a character. A new character wakes in the middle of the desert, between the town in the west and the temple in the east; walking in through the temple's door begins the ascent. Progression follows the class, attribute and skill rules in the v2 plan.

## Play

- macOS: `builds/macos/Temple Ascension 3D.app` (Intel and Apple Silicon, macOS 13+).
- macOS archive: `builds/TempleAscension-macOS.zip`.
- Windows: extract `builds/TempleAscension-Windows.zip`, then run `TempleAscension.exe` with its `.pck` file beside it (x86-64).
- Source: open `project.godot` with Godot 4.7.2, or launch `.tools/Godot.app/Contents/MacOS/Godot --path .` on this workstation.

The macOS app is ad-hoc signed. It is not notarized for public distribution.
The Windows build is unsigned; it needs a Windows hardware playtest.

## Controls

| Input | Action |
|---|---|
| Left click ground | Move to destination |
| Left click statue | Approach and attack; hold to repeat |
| Shift + left click | Attack toward cursor without moving |
| Right click | Cast active skill slot 1 |
| Hold left mouse | Continuously repath toward the cursor |
| Space | Dash: spend 10 energy |
| R | Toggle between running and walking (a slower pace) |
| Q | Healing spell: instantly restore 60% maximum health for 60 energy, 20-second cooldown |
| 1 / 2 | Cast the other two assigned active skills |
| C / K / I | Attribute panel (left) / skill tree panel (right) / equipment |
| Mouse wheel, trackpad scroll or pinch | Zoom (in close enough to look at the models) |
| E | Ascend, claim the crown, or rest at a safe entrance |
| Walk through the temple's door | Enter the temple's first floor from the desert, or leave it again |
| Escape | Pause, continue saved game, choose new run/difficulty, sound, quit |
| F11 | Fullscreen |

Clicking the ground cancels a combat order. While idle, the hero faces the cursor. Architecture
between the camera and the hero, or an enemy near a wall, turns semi-transparent. Once
five or fewer statues remain, an arrow around the hero points to the nearest one.

The HUD has a red health orb at bottom left, a blue energy orb at bottom right,
and four compact clickable ability icons centered below the action: LMB basic
attack, RMB skill, 1 and 2, each skill with its icon and, while it recharges,
the seconds left. Class and level, with a thin XP bar, appear at top left.
Floor, remaining statues and difficulty
appear at top right. Unassigned, incompatible, and recharging skills are disabled
with an explanation.

Gaining a level puts a small + button above each orb: the left one opens the
attribute panel on the left side of the screen, the right one the skill tree
panel on the right. Each stays until its points are spent. C and K open and
close the same panels; both can be open at once, Escape closes them, and the
game is paused while either is open (as it is in the equipment screen).

The temple's dark interiors are illuminated mainly by torch stations, placed so every
hallway and room stays readable, with
animated flames, rising embers and subtle independent light flicker. On the
low parapets of the terraces and the summit the light comes from bronze
braziers standing on the wall tops, burning with the same flame. The
terraces on floors four and five look down onto nearby moonlit dunes and ruins,
with mountains and a river farther away. The terraces are paved in grey
cleft slate laid in an ashlar pattern of mixed-size slabs, unlike the halls'
quartz. Below the summit, the building steps down: one storey lower, the stone roof of floor 5
wraps its south and east sides, and a storey below that, floor 4's quartz-paved terrace.
The south and east sides of the building on the terrace floors, and of the summit, drop away
as several storeys of stone wall, ledges and columns, so the galleries read as the roof
of a tall building. The dark panorama appears only while the player is on a terrace,
where a dim cool moonlight also catches the paving and parapets.

## The world

The temple stands in a larger world, one continuous outdoor map
(`scripts/overworld.gd`) about 420 m from west to east:

- **The town**, at the western end. A colosseum-style arena stands at
  its centre: an oval of sand 60 m by 48 m, with two banks of stone seating
  raised on a three-metre wall above it (the top row ten metres up), inside a
  two-storey arcade ninety metres across. A gate pierces it at each compass
  point; the eastern one faces the town gate. In the north stands, over the
  north gate, is the elders' box: a pavilion of white marble with five gilded
  thrones in a row facing the sand, a crimson canopy on gilded columns behind
  them, a gilded rail, crimson hangings and fire in gilded bowls.
  A broad paved street rings the arena, lined with palms. The inn and the
  smithy stand on its north side, a provisioner's shop by the main street in
  the east, and a market square with stalls and the well in the south-east
  corner. Five streets and alleys run off the ring, each with houses down both
  sides: thirty-five in all. A wall with a towered gateway closes the town off
  from the desert.
- **The townspeople.** Twenty-five grown townspeople wander the ring street, the
  market and, now and then, an alley, stopping here and there; two who pass
  may stop a moment to talk (no words, just the gestures). They drift in and
  out of the inn so that between three and eight of them are inside at any
  moment: one who comes in sits at a table and waits; Anya, the innkeeper (a
  young woman, dark hair in a braid, a white blouse under a brown dress; her
  name shows when the cursor is on her), fills a mug at the barrels behind her
  bar, carries it upright in her fist round to the table and sets it down in
  front of the drinker, clearing the empties; a patron drinks for a minute,
  lifting the mug to his mouth for a sip now and then and setting it back on
  the table, then leaves or waits for another. Their clothes are
  neutral and plain, and most are poor: ten in rags (frayed, patched, holed
  and filthy), nine in worn and patched tunics and gowns, six decently
  dressed. Six ragged children run about the streets at tag and
  follow-my-leader, resting in a huddle between games; they never go into the
  inn. No one goes into the arena, through the palace gate or out of the town,
  and all give way to the hero.
- **The inn and the smithy** stand open: the hero walks in through the
  doorway, and while he is inside the roof and the two walls on the camera's
  side are lifted away, so the room is seen from above. The inn is a
  two-storey hall with a plank floor: a common room with two tables set with
  plates and mugs, a long bar with stools before it and kegs, shelves and
  bottles behind, the kitchen's wall and door at the back, and above the
  kitchen a loft with four beds, reached by a stair along the east wall (the
  hero climbs it as he climbs the palace hill). The smithy has a stone floor,
  a forge against the north wall with a bed of glowing coals, a fire, a hood
  and a chimney up through the roof, anvils on their logs before it, a
  quenching barrel, two workbenches, a grindstone, racks, crates of iron, and
  swords, axes and shields hung on pegs along its walls. Orion, the
  blacksmith (bald, black-bearded, heavy and strong, in a sleeveless brown
  tunic; named under the cursor), works there all day: hammering at the
  anvil, drawing a blade along the grindstone, and stoking the forge with an
  iron rod, walking from one to the next.
- **The elders' palace.** From the arena's north gate a paved road runs north
  some fifty metres, through a towered gate in a white wall that shuts the
  hill off from the town (a marble centurion stands either side of it), and
  up a short five-metre hill between marble lions and fires to the palace: a two-storey hall of white stone on a terrace, with
  a tower, two wings, a portico of six marble columns under a stepped gable,
  gilded cornices, crimson hangings, two pools, palms and olives, and a great
  marble lion either side of its steps. The town's four lion statues (two on
  the road, two at the palace) sit on their haunches. The hill is the one place the ground rises:
  the hero, the camera and clicks all follow it.
- **Rich and poor.** The arena and the palace are dressed stone kept
  spotless. The town is not: about three houses in four are stained,
  streaked and cracked, their limewash gone in sheets over mud brick, dirt
  two metres up their walls, some with walls broken down, rubble and broken
  pots at the door, and three have lost their roofs and been left. One house
  in four is kept up, and the inn and shops are shabby but sound. The alleys
  are trodden dirt with what is left of their paving. Every door and shutter
  in the world is bare or oiled wood, in one brown or another.
- **The desert** between them: wind-rippled sand and low
  dunes, crossed by a worn track from the town gate to the temple. Running it
  from gate to door (about 250 m) takes some forty seconds. On the way are an abandoned caravan
  (where a new character starts, in the middle), a palm-ringed pool, a ruined
  colonnade, boundary stones along the track, rock outcrops, dead trees and
  dry scrub.
- **The temple**, at the eastern end: the stepped building whose
  floors the hero climbs inside, with a paved forecourt lined with pillars and
  fire bowls, two colossal stone centurions (the temple's own, three times life size, both
  looking out west down the road) and four great columns before its
  door, from which a dull amber light, the colour of the fires, glows and
  spills over the threshold.
  Walking in through the door loads the first floor, with the hero
  standing just inside. The first floor has the same door from within (a short
  passage through the wall of its entrance room, daylight beyond); walking out
  through it returns to the forecourt. The floor is not reset by leaving:
  statues already slain stay slain.

Rock rims the whole basin: sheer crags on the north and east, a rising slope
of boulders on the south and west, where the camera looks from. Nothing
walkable reaches past it. Outdoors it is late afternoon, the low sun in the
west lighting the temple's front; the camera looks from the south-west (inside
the temple it still looks from the south-east), so west and south faces are
the ones seen. Trees, buildings, the arena's wall and anything else tall turn
see-through while they stand between the camera and the hero. No statue
stands outside the temple. No place in the game has a name: the temple's
floors are numbered, and outdoors the top right of the screen only says which
way the temple and the town lie.

The temple's interior is a separate place, loaded on entering, as before.
Outdoors the same controls apply.

## Debug mode

Launch `builds/macos/Debug Mode.command` on macOS or
`builds/windows/Debug Mode.bat` on Windows. For the source project, run:

```sh
sh tools/debug.sh
sh tools/debug.sh --floor=3 --bow --axe
sh tools/debug.sh --boss
```

You can also pass `-- --debug-mode` to the game executable or to Godot after
`--path .`. The separator matters: these are game arguments. Debug controls
are available in packaged releases only when launched with this flag.
Optional `--floor=1` through `--floor=5`, `--boss`, `--bow`, and `--axe` choose
the starting encounter and weapons; they require `--debug-mode`.

The debug panel retains the original controls, with F9/F10 freeing K/C for character screens:

| Input | Action |
|---|---|
| G | Toggle invulnerability (persists across floors until toggled off) |
| F9 | Kill every enemy, award ordinary kill XP, drop loot, and unlock stairs/crown |
| F | Refill health and energy |
| H / J | Grant battle axe / bow; equip through I |
| Ctrl + 1–5 | Jump directly to that floor, retaining stats and weapons |
| N | Jump to the next floor without progression awards; on summit, defeat boss |
| B | Jump to summit and grant enough XP for level 20, the cap; repeated use grants nothing extra |
| L | Return to floor 1 with stats and weapons intact |
| O / U | Jump outside the temple: to the desert where a character starts / inside the town gate |
| T | Restart the current floor with stats and weapons intact |
| F8 | Reset the run and turn off invulnerability |
| F10 | Jump to this adaptation's crown ending and completion summary |
| P | Hide/show the panel; shortcuts remain active |
| Shift + P | Open/leave the playground: an evenly lit plane with a hero of each class and one of every statue, including the boss. Select a unit with the panel or Tab. A selected hero uses the normal controls with every class skill learned and full energy; a selected statue walks with left click on the ground, attacks toward the cursor with right click, and uses its special (frost nova, gaze) with 1. Any unit attacks by left clicking another unit (hero or statue) or with Shift + left click, and every attack can hit any other unit. Hits play their reactions but deal no damage and nothing dies; X (or the panel) kills the selected unit with its death animation, and again revives it. Nothing is saved while it is open. |

The panel also offers an instant summit jump without extra XP. Bare
1 and 2 cast assigned skills. Floor jumps retain level and point budgets, refill health/energy, and reset enemies,
loose drops, combat effects, and pending attacks. Restart and jump controls
also work from pause, death, character, and completion screens.

Debug runs autosave in the `debug/` subfolder of the normal save directory,
and only continue other debug runs. Launching normally restores your regular
ascent. Invulnerability is a session toggle and starts off on each launch.

## Campaign

The original 24 / 32 / 54 / 57 / 80 enemy counts are preserved. Gladiators,
archers, fast Lion Guardians, spellcasting oracles and centurions activate as
statues and alert nearby allies. Hitting an enemy pushes back its next attack by 50% of its normal
time between attacks and roots it for that time; further hits add 30%, then 15%,
then nothing, until it lands an attack. A hit during a wind-up breaks it off: the
enemy flinches and starts the attack over once the delay ends. A hit during an Oracle's
cast pushes the cast back by the same amount instead. Oracles cast two-second fireballs, shown by a cast
bar, and answer a close approach with an instant frost nova that slows the hero. The five floors now use the original game's
seeded room-and-corridor format: 8–15 tile rooms, five-tile-wide passages,
extra connections that form loops, and ascent stairs in the most distant room.
Floors grow from 50×50 to 74×74 tiles. The third floor includes a large central
court with two entrances; floors four and five add mirrored wraparound galleries.
Statues line the walls facing inward, with a safe area around the entrance.
The summit remains a single arena with four corner groups of dormant centurions.

## Classes and progression

All classes start with Strength, Dexterity, Intelligence, Vitality and Willpower
at 5, 100 health and 100 energy. Health regenerates at 1% of maximum per second,
quadrupled after three seconds without an active enemy. Energy regenerates at 10%
of maximum per second. Above the base:

| Attribute | Per point |
|---|---|
| Strength | +2% melee damage |
| Dexterity | +2% ranged damage; +1% melee attack speed |
| Intelligence | +2% spell damage |
| Vitality | +10 maximum health |
| Willpower | +3 maximum energy and +0.1 energy per second |

Each hero wears a painted, detailed kit after his concept art
(tools/paint_kits.py paints it through the body's UVs, with relief and sheen
maps; outfit_hero.py adds raised shells and props). Warrior starts with a
large sword, a round steel shield worked with a lion boss, a sunburst and a
Greek-key band, and Cleave, wearing a gladiator's steel helm with a face mask
(large eye openings, a nose bar, a brim and a low spiked ridge), a cuirass of
large overlapping steel scales
with lion medallions and a baldric, a broad studded belt with a lion boss,
leather strips at the shoulders, a steel manica on the sword arm, a kilt of
leather pteruges (studded tabs, steel leaf motifs and a Greek-key band) that
swings and folds over his legs like the ranger's cloak, over a tattered
underskirt, steel greaves and knee guards, and strapped
sandals. Ranger with bow and Power Shot: knee-high strapped leather boots,
leather knee guards, a tattered green wool tunic, a broad belt and crossed
straps, laced bracers, fingerless gloves, a beard, and a quiver, sheathed
dagger, pouch and brooch; over it a weathered, frayed dark green hooded cloak
whose brim shades his face (the mid-calf cloak swings on a spring simulation
and flows back as he moves; its shader folds the cloth over his legs wherever
they press into it, so they never show through). He stands, runs and crouches
as the warrior does, carrying the bow at his side in his left hand, the hand
he shoots from; to shoot he turns side-on, locks the bow arm out at the target
and draws the string to his jaw. Wizard with a twisted silver staff crowned
with a pale crystal, and Firebolt, in a deep navy wool robe, hood and cape,
with a knotted leather sash, wrapped leather bracers and worn leather boots. The first skill point is spent on that starter.

Every class's skills sit in three trees, shown side by side in the skill panel
(K): Area of Effect, Single Target and Passive. Click a skill to spend a point
on it; hovering shows what it does at its current and next rank. A learned
active skill takes the first empty slot; right-click it, or press 1 or 2 while
pointing at it, to put it on RMB, 1 or 2 (swapping a slot's skill waits until
out of combat). Passives work automatically. Bow skills need a bow, spells a
staff, and Shield Bash needs sword/shield. All classes can equip every owned family.

The warrior's skills follow the leveling and skills design document. Each has
five ranks, limited only by skill points, and opens once 0, 5, 10 or 15 points
are spent in its own tree (the document's level 1, 5, 10 and 15 skills;
Shadow Strike, a level 10 skill there, opens at 5 points instead).
Percentages of damage are of a normal attack.

| Tree | Points | Skill | Energy | Rank 1 → 5 |
|---|---|---|---|---|
| Area of Effect | 0 | Cleave | 25 | A 140° → 180° arc for 125% → 165% damage |
| | 5 | Leap | 40 | Leap to a target in sight (up to 10 m): 100% → 250% to everyone around the landing |
| | 5 | Ground Slam | 40 | 100% → 250% in a 70° → 120° arc, out to 10 → 21 m; a shockwave of dust and a shake of the screen |
| | 0 | War Cry | 30 | Every enemy within 6 → 10 m takes 20% → 100% more damage for 6 → 10 seconds |
| | 10 | Shield Charge | 35 | Sword and shield only: a charge of 8 → 14 m behind the shield, 100% → 200% to everyone in the path, thrown aside; the first one hit stunned for 1 → 2 seconds |
| | 10 | Shockwave | 40 | 180% → 360% to everyone within 4 → 7 m, thrown back; 10-second cooldown; a shockwave of dust and a shake of the screen |
| Single Target | 0 | Powerful Strike | 25 | 200% → 300% to one enemy |
| | 0 | Shield Bash | 35 | 25% → 50% and a 5 → 10 second stun, broken by damage; 32 → 20 second cooldown; half the stun each time the same target is bashed again within 30 seconds |
| | 5 | Vampiric Strike | 25 | 80% → 125% plus 3% → 12% of the target's total health, healing the same share of your own |
| | 5 | Shadow Strike | 25 | 25% → 70%, then 100% → 220% over 5 seconds; refreshes Cursed Blade on the target |
| | 10 | Execute | 45 | 200% → 450%, only on an enemy below 20% → 40% health |
| Passive | 0 | Dash Attack | | The dash ends in a Cleave (at your Cleave's rank, at least 1) and costs 20 → 0 extra energy |
| | 0 | Shield Expertise | | 5% → 50% chance to block any attack with the shield, for 25% → 80% less damage |
| | 0 | Endurance | | Energy recovers 10% → 75% faster |
| | 5 | Quick Strikes | | Normal attacks 20% → 170% faster |
| | 5 | Cursed Blade | | Hits add 10% → 65% of their damage over 4 seconds, in up to 1 → 8 stacks |
| | 10 | Offensive Rhythm | | Each hit: +5% → 30% damage, up to 5 → 10 stacks, lasting 4 → 12 seconds |
| | 10 | Defensive Rhythm | | Each hit taken: 3% → 12% less damage, up to 2 → 6 stacks, lasting 4 → 12 seconds |
| | 10 | Spiked Shield | | A blocked attacker takes 10% → 80% of a normal attack |

The sword's normal attack is three swings that run into one another while he keeps
attacking: a cut down from upper right to lower left, a backhand cut down from upper
left to lower right, then a lunging thrust, and round again, his whole body thrown
into each. He walks into his target as he swings, stepping with each foot in turn. If
he breaks off (moves, casts, or simply stops), the next attack starts from the first.

With the sword, every warrior skill has a swing of its own (`tools/import_skills.py`):
a level sweep for Cleave, an overhead chop for Powerful Strike, a lunging thrust for
Vampiric and Shadow Strike, the shield shoved out behind a step for Shield Bash, the
blade wound far back and brought down with the whole body for Execute, driven
point-first into the ground for Ground Slam, the pommel hammered down from a deep
crouch for Shockwave, the blade thrust at the sky for War Cry, a braced run behind
the shield for Shield Charge (the sprint, the shield held straight out before him),
and for Leap a deep crouch, the spring, the body stretched in the air with the blade
over the head, and the landing driven down with everything behind it. Leap's
landing and Ground Slam send a shockwave over the ground: a puff of dust and
smoke bursting from the point of impact and racing low across the whole area the
blow reaches (all round the warrior under the leap, across the arc ahead for the
slam), translucent, swelling as it spreads and thinning to nothing; and the screen
shakes hard.

Shield Bash is the one skill with a cooldown; energy is the others' only cost.
Dexterity quickens every melee swing, skills included; Quick Strikes only the
normal attack. No swing is faster than a fifth of a second. A right click (or
1 / 2) on an enemy walks into reach before a melee skill, leaps from Leap's
range, and slams from within Ground Slam's.

The ranger and wizard keep the earlier roster for now, arranged in the same
three trees: eight active skills and four passives, unlocking at levels 1, 4,
8, 12 and 18. Their active skills have five ranks and passives three, with rank
limited to `1 + floor((level - unlock_level) / 3)`.

Enemy kills award XP, with diminishing rewards from enemies well below the
character's level. Each level after 1 grants five attribute points, to spend on
any attribute, and one skill point, up to level 20. Level alone adds no health,
damage or energy. XP thresholds
and authored floor enemy levels are explicit tables in `scripts/data.gd`. The
current 247-enemy temple route reaches level 20 before the summit; this
balance is for the existing climb, not the plan's future pre-temple regions.

Floor travel grants no points or XP. Permanent attribute gems have been removed.
Each class starts with only its own weapon: sword for Warrior, bow for Ranger,
and staff for Wizard. Bow and axe drops are disabled for now; the staff drop on
floor three remains.
Repeated death callbacks, reloads and retrying an already-rewarded enemy cannot
award its XP again. XP and skill investment survive death and travel.

Free respec is available in the attribute panel (C) at a safe floor entrance, out of combat; it
refunds earned attribute/skill points and clears the hotbar. Equipment and active
assignments can change out of combat. Maximum resource increases do not heal;
refunds clamp current resources. The Q healing spell has no charges; it spends 60
energy, heals 60% of maximum health instantly and recharges after 20 seconds. E
at a safe entrance opens the attribute panel; ascending restores health and energy.

All attack clips scale to the character's attack duration and restart for every
attack. Animation, contact/release and recovery advance on the same combat clock,
including held attacks, Quick Draw and enemy wind-ups delayed by a hit. Staff
basic attacks launch free arcane bolts. Bow draws stay clear of the torso and neck,
with dedicated carry poses for running and crouching. Class skills add distinct
projectiles, sweeps, traps, defensive buffs, crowd control and area effects using
the existing authored models and VFX assets.

The summit statue has 1,250 base health, cleave and a warned sweeping gaze. At
80%, 60%, 40%, and 20% health, it summons a corner group of five centurions.
They never attack and grant no experience: they run to it, and each one that
reaches it heals it by 5%. Any still standing crumble when it falls.
Claiming the crown triggers petrification and the elders' reveal, then a completion
summary. Elapsed playtime and best-time records are neither tracked nor displayed.

Each new run generates a different temple. Retrying or continuing a save restores
the same rooms, passages, stairs and statue positions for that run and floor.
Death restarts the current floor while preserving class, XP, attributes, skills and weapons.
Living enemies reset when a save is loaded; defeated enemies and loose drops
persist. A save also records whether the hero is outside the temple or on one
of its floors, and where; saves from before the outdoor world (version 6 and
earlier) continue inside the temple. Autosaves run every eight seconds and on important progression events.
Writes use a temporary file and a backup. A damaged current save falls back to its
backup. Saves from before the level cap of 20 and the skill trees (version 5
and earlier) keep their class, campaign progress, weapons and defeated enemies;
a level above 20 comes down to 20, and every attribute and skill point is
refunded to spend again under the new rules. Version 1/2 saves migrate to a Warrior (or Ranger if a bow was equipped).
Old stat/gem bonuses are
refunded into a level-based point budget; use the + buttons (or C and K) to rebuild. Legacy gem
drops are retired. Fixed-layout saves move safely to the generated entrance.
Saves use Godot's native user-data directory,
separate from earlier games:

- macOS: `~/Library/Application Support/Godot/app_userdata/Temple Ascension 3D/`
- Windows: `%APPDATA%/Godot/app_userdata/Temple Ascension 3D/`

## Adaptation decisions

Enemy click areas have a minimum radius of 64 logical pixels, with extra room
for tall enemies at close zoom. Hovering shows a red ring at their feet and a
small health bar above their head. While the ring shows, every attack and
ability (Shift+click, held clicks, right click, 1 and 2) aims at the centre of
that enemy rather than the ground under the cursor. Hover and attack selection use the same area;
HUD controls, dead enemies and dormant centurions do not trigger this feedback.

The Lion Guardian is a stone lion the size of a living one (1.15 m at the
shoulder, about 2.1 m from nose to rump), with the original fast pursuit and
attack cadence. It is sculpted as a lion is built: a deep chest and tucked
belly, heavy shoulders, the great thigh of the hind leg running down to the
stifle, the shin back to a high hock and the long foot below it, thick
forelegs, broad four-toed paws with claws, a hanging tail with its tuft, and a
full mane of long locks swept back from the face over the neck, the shoulders
and the breast, every lock combed into strands. It stands watch, breathing and
looking about; it moves at a trot, each fore paw stepping with the opposite
hind paw and the two pairs in turn; and it attacks by sinking back, rearing
onto its haunches with the right forepaw drawn up and out wide, then throwing
its whole body behind the paw as it rakes forward and across, and dropping
back onto its forefeet. It flinches when struck, and when an attacker pushes
into it its four paws step away under it (the diagonal pairs in turn) rather
than slide, as the other units' feet do. The local
library has no four-legged figure, so the lion is built for this game by
`tools/make_lion.py` (see `docs/ASSETS.md`). All humanoid statues and the hero
use the requested local model and animation library.
Gladiators are murmillones with a crested, brimmed helmet, the warrior's armor
in stone (a scale cuirass with shoulder guards and forearm bracers), an armored
kilt of plates to mid-thigh and bare legs; they carry a sword and a tall scutum.
Archers wear close-fitting light leathers and a hood, centurions are powerfully
built legionaries in close-fitting heavy plate and helmets behind tall tower
shields, and oracles wear long robes, a cape and a deep hood. The Crowned
Statue is a Roman general: a cuirass with shoulder guards, the gladiator's
armored kilt, a cape, a full beard and its crown. The wizard's, the oracles'
and the Crowned Statue's capes are hanging cloth, like the ranger's cloak:
they swing as heavier cloth and fold over the legs rather than letting them
through, the statues' in stone.
Enemy bodies and their equipment share a dark, rough stone-gray finish with
fine grain, weathering and a few thin cracks. On animated statues the stone is
laid out from the rest pose, so it stays fixed to the body as it moves. The warrior's shield is centered against the left
forearm, and the gladiator's scutum is held upright in front of it, throughout idle,
movement and attacks.
These outfits use authored meshes fitted to the existing
enemy skeleton and retain the current combat animations.

The room placement, seeded random generator, corridor
connections, court footprint and galleries are adapted from the browser game's generator. Existing imported
3D floor, wall and prop meshes populate that layout. The third-floor court has
the original broad, shallow pool and a three-tier stone fountain. The player can
wade through the water, leaving ripples, while the solid centerpiece remains an
obstacle. The original bubbling water loop grows louder near the fountain and is
silent outside the room. The ending
is staged in the summit with dialogue. This adaptation does not submit scores to
the original public leaderboard.

All solid architecture, equipment and character meshes are imported 3D assets;
the distant desert seen from the terraces is a generated image backdrop. The
outdoor world is built the same way: its buildings, arena and temple front are
assembled from the wall kit's modules, weathered by a masonry shader; its rocks,
stones and shrubs are photo scans; its palms are modelled for this game; and
its sand (photographed), paving, track and pool are drawn by one ground shader
on a single slab. There are no primitive-mesh
stand-ins or runtime mesh construction.
Imported modular assets are placed by the scene builder; invisible collision and
navigation calculations are separate from their rendered meshes. VFX use a generated
transparent seal texture. See `docs/ASSETS.md` for provenance and image prompts.

## Build and test

```sh
sh tools/test.sh
RENDER_TEST=1 sh tools/test.sh  # also run native animation and input checks
sh tools/build.sh
```

The `.tools` directory links the existing Godot/Blender installation and export
templates on this workstation. On another workstation, install Godot 4.7.2 and its
matching export templates, and update the custom-template paths in
`export_presets.cfg`. `GODOT_BIN` can override the editor executable used by scripts.

The headless campaign test exercises combat, all floors, drops, XP progression,
boss phases, ending and save recovery using isolated saves. Additional checks
cover class creation, all 40 skills, the warrior's three trees with every listed
rank in play (`tests/warrior_skills.gd`), rank limits, shared stat formulas, migration,
XP reward deduplication, 200 generated maps, the outdoor world (`tests/overworld.gd`:
the start, the crossing time, the sealed rim, the town's buildings on every side
of the central arena, the street round it, its four gates, its size and raised
stands, the brown woodwork, the Elders' Box, the palace road and hill, the
alleys, the upkeep of rich and poor, the temple door both ways and saves made
outdoors), navigation, attack timing, all eight
animations, bow orientation and visible blade contact. Debug regression checks
cover launch gating, save isolation, all shortcuts, floor resets, level shortcuts,
and clickable panel controls. Native input testing
uses a rendered window and injected mouse/keyboard events; screenshots and test
reports are written under `test-results/`. Test scripts are excluded from exports.
