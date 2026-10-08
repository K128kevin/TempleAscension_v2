# Temple Ascension 3D

Native Godot adaptation of `/Users/ktabb/Documents/workspace/TempleAscension`.
Choose Warrior, Ranger or Wizard when creating a character. A new character wakes sitting by a campfire on top of a great dune in the desert south of the town, with the temple far to the east. The campaign runs through two bandit dungeons of two levels each (the basement under the town's arena, reached from the space under its stands, and a cave in the northern rocks of the desert before the temple) and then the temple: three floors and the summit. The temple's door stays shut until both dungeons are cleared. Progression follows the class, attribute and skill rules in the v2 plan.

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
| Hold left mouse | Continuously repath toward the cursor (a hold begun on the ground keeps walking when dragged over a statue) |
| Space | Dash: a short sprint toward the cursor, untouchable while it lasts; no energy cost, recharges for 3 seconds |
| R | Toggle between running and walking (a slower pace) |
| Q | Healing spell: instantly restore 60% maximum health for 60 energy, 20-second cooldown |
| 1 – 4 | Cast the other four assigned active skills |
| C / K / I | The character window, on the right: its attributes, skills and inventory tabs |
| Left click an item's name | Pick the item up off the ground (walking to it first if it is not at hand) |
| X | The other weapon: a ranger's bow for his blade and back; anyone's weapon for the first in the bag he can use |
| Mouse wheel, trackpad scroll or pinch | Zoom (in close enough to look at the models) |
| E | Ascend, claim the crown, or rest at a safe entrance |
| Walk through the temple's door | Enter the temple's first floor from the desert, or leave it again |
| Escape | Pause, continue saved game, choose new run/difficulty, sound, quit |
| Ctrl + Z | Hide the whole interface (every bar, icon, panel and word, damage numbers included), and show it again |
| F11, Alt+Enter, or Ctrl+Cmd+F on a Mac | Fullscreen on or off (also in the Escape menu; remembered between launches) |

Clicking the ground cancels a combat order. While idle, the hero faces the cursor. Architecture
between the camera and the hero, or an enemy near a wall, turns semi-transparent. Once
five or fewer statues remain, an arrow around the hero points to the nearest one.

The HUD keeps to the foot of the screen: a compact row of clickable ability
icons in the middle (LMB basic attack, RMB and 1 to 4, each skill with its icon
and, while it recharges, the seconds left), with the red health orb just to its
left and the green energy orb just to its right. No line of controls is shown
on screen; they are listed above. Above them a row shows what is on the hero: each buff
(gold-framed) and debuff (red-framed) as an icon, its stacks in the corner,
with a thin bar under it running down with the time it has left; hovering one
names it. Class and level, with a thin XP bar, appear at top left.
Floor, remaining statues and difficulty
appear at top right. Unassigned, incompatible, and recharging skills are disabled
with an explanation.

Attributes, skills and inventory are three tabs of one character window on the
right side of the screen. C, K and I open it at each (or turn it to that tab,
or close it from there); its tabs can be clicked; Escape closes it; and the
game is paused while it is open. Gaining a level puts a small + button at each
lower corner: the left one opens the window at the attributes, the right one
at the skills. Each stays until its points are spent.

The inventory tab shows a figure of the hero as he is dressed and armed (drag
across it to turn it), with his head, chest and legs slots to its left, his
hands and feet to its right, and his main hand and off hand under it. Below
are the ten places of his bag, five wide and two tall. Drag an item onto a
slot to put it on, off a slot to take it off, between places to rearrange, or
out of the window to drop it on the ground; a right click (or a double click)
puts on an item in the bag or takes off one that is worn. A square lights only
where the dragged item fits. Hovering an item shows what it is and does, and
why the hero's class cannot use it if it cannot.

The temple's dark interiors are illuminated mainly by torch stations, placed so every
hallway and room stays readable, with
animated flames, rising embers and subtle independent light flicker. On the
low parapets of the terraces and the summit the light comes from bronze
braziers standing on the wall tops, burning with the same flame. The
terraces on the third floor (galleries round its west, north and east sides) look down onto nearby moonlit dunes and ruins,
with mountains and a river farther away. The terraces are paved in grey
cleft slate laid in an ashlar pattern of mixed-size slabs, unlike the halls'
quartz. Below the summit, the building steps down: one storey lower, a stone roof
wraps its south and east sides, and a storey below that, a quartz-paved terrace.
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
  tunic and leather shoes; named under the cursor), works there all day
  (`scripts/smith.gd`): he takes a sword down from its peg on the north wall,
  carries it to the anvil, picks up his hammer, lays the blade flat on the
  anvil's face and beats it (the hammer's face meeting the steel at each
  stroke, with a few sparks); hangs it back; works the forge's coals with an
  iron rod; then takes the sword to the grindstone and holds its edge across
  the turning stone, sparks flying. The arms on the walls are bright steel on
  dark hafts, with swords and shields like the warrior's own.
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
- **Day and night** (`scripts/daylight.gd`): the outdoor world turns through a
  thirty-minute day: a three-minute sunrise, fourteen minutes of day, a
  three-minute sunset and ten minutes of night. The sun rises in the east,
  stands in the south at noon and sets in the west, with red-gold light at
  both ends of the day; at night the moon lights the world, much darker and
  blue but easy to see by, and every fire lights what stands round it and
  glows on the ground. Mist lies from the end of the night through the early
  morning. A new character wakes at night, six minutes before the dawn, by
  his campfire. The clock is kept in the save and runs indoors too (the
  light beyond a door to the outside follows it). Debug: F7 advances the day
  three minutes.
- **The southern desert**, apart from the one the track crosses: a gap in the
  rocks at the end of the town's south-eastern alley opens on it. A great dune
  nine metres high looks down on the town from the south; on its crown is the
  camp a new character wakes at, seated on a log by his fire, with a sleeping
  pad and his supplies beside it. He gets up the moment he moves.
- **The dungeons' entrances**: under the arena's stands runs a paved, shadowed
  undercroft (a doorway in each side of the east, south and west gateways lets
  into it; the seats overhead are lifted away while the hero is inside), with
  the kerbed stair down to the basement under the south-eastern stands; and a
  defile in the desert's northern rocks leads to the black mouth of the
  bandits' cave. Both dungeons are generated like the temple's floors, in
  their own stone (dressed masonry and slate; living rock over bare earth),
  are gone down into (E at the far stair descends, E at the arrival stair
  climbs back, and the first level's door leads out), and hold bandits with
  swords and with bows: men, who fall rather than crumble.
- **The desert** between them: wind-rippled sand and low
  dunes, crossed by a worn track from the town gate to the temple. Running it
  from gate to door (about 250 m) takes some forty seconds. On the way are an abandoned caravan
  (in the middle), a palm-ringed pool, a ruined
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
Optional `--floor=1` through `--floor=3`, `--boss`, `--bow`, and `--axe` choose
the starting encounter and weapons; they require `--debug-mode`.

The debug panel retains the original controls, with F9/F10 freeing K/C for character screens:

| Input | Action |
|---|---|
| G | Toggle invulnerability (persists across floors until toggled off) |
| F9 | Kill every enemy, award ordinary kill XP, drop loot, and unlock stairs/crown |
| F | Refill health and energy |
| H / J | Grant a battle axe / a bow, into the bag; equip through I (if the class can use it) |
| F6 | Drop a random one of the items enemies drop (any class's) at the hero's feet |
| Y | Reset skills: unlearn every skill, refund all skill points and empty the hotbar; attributes stay |
| Ctrl + 1–3 | Jump directly to that floor, retaining stats and weapons |
| N | Jump to the next floor without progression awards; on summit, defeat boss |
| B | Jump to summit and grant enough XP for level 25, the cap; repeated use grants nothing extra |
| L | Return to floor 1 with stats and weapons intact |
| M | Go to the arena basement's first level |
| V | Go to the bandit cave's first level |
| O / U | Jump outside the temple: to the desert where a character starts / inside the town gate |
| T | Restart the current floor with stats and weapons intact |
| F8 | Reset the run and turn off invulnerability |
| F10 | Jump to this adaptation's crown ending and completion summary |
| P | Hide/show the panel; shortcuts remain active |
| Shift + P | Open/leave the playground: an evenly lit plane with a hero of each class and one of every statue, including the boss. Select a unit with the panel or Tab. A selected hero uses the normal controls with every class skill learned and full energy; a selected statue walks with left click on the ground, attacks toward the cursor with right click, and uses its special (frost nova, gaze) with 1. Any unit attacks by left clicking another unit (hero or statue) or with Shift + left click, and every attack can hit any other unit. Hits play their reactions but deal no damage and nothing dies (Execute works on any target there, whatever its health); X (or the panel) kills the selected unit with its death animation, and again revives it. Nothing is saved while it is open. |

The panel also offers an instant summit jump without extra XP. Bare
1 and 2 cast assigned skills. Floor jumps retain level and point budgets, refill health/energy, and reset enemies,
loose drops, combat effects, and pending attacks. Restart and jump controls
also work from pause, death, character, and completion screens.

Debug runs autosave in the `debug/` subfolder of the normal save directory,
and only continue other debug runs. Launching normally restores your regular
ascent. Invulnerability is a session toggle and starts off on each launch.

## Campaign

Each floor holds three quarters more statues than the original's 24 / 32 / 54 / 57 /
80: 42 / 56 / 95 / 100 / 140, most of the added ones gladiators, centurions and lions
(lions now stand on every floor; centurions only from the third up, their places
on the first two taken by gladiators and lions). Gladiators,
archers, fast Lion Guardians, spellcasting oracles and centurions activate as
statues and alert nearby allies. Hitting an enemy pushes back its next attack by 50% of its normal
time between attacks and roots it for that time; further hits add 30%, then 15%,
then nothing, until it lands an attack. A hit during a wind-up breaks it off: the
enemy flinches and starts the attack over once the delay ends. A hit during an Oracle's
cast pushes the cast back by the same amount instead. Oracles cast two-second fireballs, shown by a cast
bar, and answer a close approach with an instant frost nova that slows the hero. The temple's three floors (gladiators, archers and lions on the first; Oracles added, with the fountain court, on the second; centurions in the gladiators' place, with the terraces, on the third) and the dungeons' levels use the original game's
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
| Strength | +2% melee damage (every weapon in hand, the dagger's too) |
| Dexterity | +2% ranged damage; +0.3% attack speed, melee and ranged; +0.25% critical hit chance |
| Intelligence | +2% spell damage |
| Vitality | +10 maximum health |
| Willpower | +3 maximum energy and +0.1 energy per second |

Every hit the hero lands, a normal attack's or a skill's, has a 20% chance
(plus Dexterity's share) to be a critical hit for double damage, rolled
separately for each target. Damage numbers show a normal attack's hit in white,
a skill's in yellow and a critical hit's in orange, swelling as it rises;
Cursed Blade's damage over time shows in purple.

Each hero wears a painted, detailed kit after his concept art
(tools/paint_kits.py paints it through the body's UVs, with relief and sheen
maps; outfit_hero.py adds raised shells and props). Warrior starts with a
large sword, a round steel shield worked with a lion boss, a sunburst and a
Greek-key band, wearing a gladiator's steel helm with a face mask
(large eye openings, a nose bar, a brim and a low spiked ridge), a cuirass of
large overlapping steel scales
with lion medallions and a baldric, a broad studded belt with a lion boss,
leather strips at the shoulders, a steel manica on the sword arm, a kilt of
leather pteruges (studded tabs, steel leaf motifs and a Greek-key band) that
swings and folds over his legs like the ranger's cloak, over a tattered
underskirt, steel greaves and knee guards, and strapped
sandals. Ranger with bow: knee-high strapped leather boots,
leather knee guards, a tattered green wool tunic, a broad belt and crossed
straps, laced bracers, fingerless gloves, a beard, and a quiver, sheathed
dagger, pouch and brooch; over it a weathered, frayed dark green hooded cloak
whose brim shades his face (the mid-calf cloak swings on a spring simulation
and flows back as he moves; its shader folds the cloth over his legs wherever
they press into it, so they never show through). He stands, runs and crouches
as the warrior does, carrying the bow at his side in his left hand, the hand
he shoots from; to shoot he turns side-on, locks the bow arm out at the target
and draws the string to his jaw. Wizard with a twisted silver staff crowned
with a pale crystal, in a deep navy wool robe and hood, with a knotted
leather sash, wrapped leather bracers and worn leather boots (the robe's
ankle-length skirt hangs from his waist on a spring simulation, the sash's
ends with it, and folds over his legs as the ranger's cloak does). No class starts with a skill learned: each begins with
one skill point to spend on any skill it can learn.

Every class's skills sit in three trees, shown side by side in the skill panel
(K): Area of Effect, Single Target and Passive. Click a skill to spend a point
on it; hovering shows what it does at its current and next rank. A learned
active skill takes the first empty slot; right-click it, or press 1 to 4 while
pointing at it, to put it on RMB or 1 to 4, in or out of combat. Passives work automatically. The warrior's attacks need a
melee weapon in hand (a sword, mace, axe or spear), Shield Bash and Shield Charge a shield; bow skills need a bow and
dagger skills a dagger; a wizard's spells need nothing. A ranger's skill made with a weapon that is in the bag takes
it up (see Items); a warrior holding a bow can use none of his skills, only his normal attack, a bowshot.

The warrior's skills follow the leveling and skills design document. Each has
five ranks, limited only by skill points, and opens once 0, 5, 10 or 15 points
are spent in its own tree (the document's level 1, 5, 10 and 15 skills;
Shadow Strike, a level 10 skill there, opens at 5 points instead).
Percentages of damage are of a normal attack.

| Tree | Points | Skill | Energy | Rank 1 → 5 |
|---|---|---|---|---|
| Area of Effect | 0 | Cleave | 25 | A 140° → 180° arc for 125% → 165% damage |
| | 5 | Leap | 40 | Leap to a target in sight (up to 10 m): 125% → 300% to everyone around the landing (4.5 m) |
| | 5 | Thunder Slam | 40 | 100% → 250% in a 70° → 120° arc, out to 5 → 9 m; a shockwave of dust and a shake of the screen |
| | 0 | War Cry | 30 | Every enemy within 6 → 10 m takes 20% → 100% more damage for 6 → 10 seconds |
| | 10 | Shield Charge | 35 | Sword and shield only: a charge of 8 → 14 m behind the shield, 100% → 200% to everyone in the path, thrown aside; the first one hit stunned for 1 → 2 seconds |
| | 10 | Shockwave | 40 | 180% → 360% to everyone within 4 → 7 m, thrown back; 10-second cooldown; a shockwave of dust and a shake of the screen |
| Single Target | 0 | Powerful Strike | 25 | 200% → 300% to one enemy |
| | 0 | Shield Bash | 35 | 25% → 50% and a 5 → 10 second stun, broken by damage; 32 → 20 second cooldown; half the stun each time the same target is bashed again within 30 seconds |
| | 5 | Vampiric Strike | 25 | 80% → 125% plus 3% → 12% of the target's total health, healing the same share of your own |
| | 5 | Shadow Strike | 25 | 25% → 70%, then 100% → 220% over 5 seconds; refreshes Cursed Blade on the target |
| | 10 | Execute | 45 | 200% → 450%, only on an enemy below 20% → 40% health |
| Passive | 0 | Dash Attack | | Enemies the dash passes through take 50% → 200% damage and are pushed back; the dash recharges 0.4 → 2 seconds sooner (0.4 a rank) |
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
into each: the cuts are struck fast and followed through almost to the ground, the
blade trailing a translucent wake of air (`scripts/sword_trail.gd`; drawn only, it
changes nothing about the blow). He walks into his target as he swings, stepping with
each foot in turn. If
he breaks off (moves, casts, or simply stops), the next attack starts from the first.

With the sword, every warrior skill has a swing of its own (`tools/import_skills.py`):
a level sweep for Cleave, an overhead chop for Powerful Strike, a lunging thrust for
Vampiric and Shadow Strike, the shield shoved out behind a step for Shield Bash, the
blade wound far back and brought down with the whole body for Execute, driven
point-first into the ground for Thunder Slam, the pommel hammered down from a deep
crouch for Shockwave, the blade thrust at the sky for War Cry, a braced run behind
the shield for Shield Charge (the sprint, the shield held straight out before him),
and for Leap a deep crouch, the spring, the body stretched in the air with the blade
over the head, and the landing driven down with everything behind it. Leap's
landing, Thunder Slam and Shockwave put everything into the ground at once
(`scripts/shockwave.gd`): a flash where the blow lands, the floor cracked about it
(dark splits lit along their lips, dying away), a column of dust thrown up, and a
single front racing out across the whole area the blow reaches, like a sonic boom
(a hard pale edge with a fainter one after it and a low wall of haze standing on
it; all round the warrior under the leap, across the arc ahead for the slam),
quick at first and gone as it reaches the blow's edge; and the screen shakes. The
charge on the blade in Thunder Slam does not shoot out: it is spent into the
ground (the cracks glow blue with it), and what is left on the blade drifts off it
in wisps and fades.

Shield Bash is the one skill with a cooldown; energy is the others' only cost.
Dexterity quickens every attack, melee or bow, skills included; Quick Strikes only the
normal attack. No swing is faster than a fifth of a second. A right click (or
1 to 4) on an enemy walks into reach before a melee skill, leaps from Leap's
range, and slams from within Thunder Slam's.

### The ranger

The ranger carries a bow and a dagger (one in hand, the other in his bag), and
fights with either: **X** changes between them at any time (in combat too), and a
skill made with the other takes it up. The bow does its damage by Dexterity, the dagger by Strength. The dagger's normal attack is quick (half a
second), a stab and a slash by turns. His skills sit in three trees (Attacks,
Utility, Passive), each skill opening once enough points are spent in its own tree,
as the warrior's do.

| Tree | Points | Skill | Energy | Ranks 1 → 5 |
|---|---|---|---|---|
| Attacks | 0 | Rapid Fire (bow) | 35 → 20 | 2 → 4 arrows in a row |
| | 0 | Power Shot (bow) | 30 | 200% → 400% to its target and every enemy within 2.5 m of it, after 3 → 1 seconds of aiming (a bar over his head fills as he aims) |
| | 0 | Flurry (dagger) | 25 | 2 → 4 stabs of 100% → 275% |
| | 5 | Volley (bow) | 40 | 15 → 30 arrows falling at random in the area aimed at (4.25 m radius), 80% → 150% each |
| | 5 | Lightning Shot (bow) | 35 | 100% → 250%, leaping to 1 → 5 more enemies within 10 m of the last, each leap 20% weaker than the one before |
| | 5 | Frenzy | 0 | Attacks 10% → 35% faster for 6 → 15 seconds; 30-second cooldown |
| | 10 | Triple Slash (dagger) | 25 | Three cuts of 130% → 250% on the target and on 2 → 4 more enemies around him (within 2.6 m, on any side) |
| Utility | 0 | Slow Shot (bow) | 20 | The target moves 30% → 75% slower for 3 → 6 seconds |
| | 0 | Weakening Strike (bow or dagger) | 15 | Critical strikes on the target deal 10% → 15% more a stack for 6 seconds, in 2 → 5 stacks (75% at most) |
| | 5 | Hide in Shadows | 20 | Unseen by enemies, moving 50% → 15% slower; out of combat only; ended by attacking, being struck or dashing |
| | 5 | Throw Sand | 40 | An enemy within 3 m wanders blind, unable to attack, for 3 → 12 seconds, or until hurt; 45-second cooldown |
| | 5 | Tranquilizer (bow) | 40 | The target sleeps for 3 → 12 seconds, or until hurt; the arrow does no damage; 45-second cooldown |
| | 10 | Vanish (1 rank) | 40 | Hidden at once, in combat: every enemy loses him; 60-second cooldown |
| | 10 | Surprise Attack | 50 | Only while hidden: the target is stunned for 3 → 5 seconds (damage does not break it) and takes 20% → 60% more |
| Passive | 0 | Swift Footed | | 5% → 40% faster on his feet |
| | 0 | Bow Specialization | | +4% → 30% chance of a critical strike with the bow, which deals 25% → 150% extra |
| | 0 | Dagger Specialization | | The same, with the dagger |
| | 5 | Element of Surprise | | 40% → 100% more damage for 4 → 10 seconds after leaving the shadows |
| | 5 | Poisons | | Arrow and dagger hits deal 10% → 65% more over 5 seconds, in 1 → 8 stacks |
| | 10 | Penetrating Arrows (1 rank) | | Arrows carry on through their targets, out to the bow's usual 13 m reach |

Each has its own motion (`tools/import_ranger.py`) and effect
(`scripts/ranger_fx.gd`): the dagger's stab and slash, Flurry's stabs high and low,
Triple Slash's three cuts (the blade trailing a wake, as the sword does), a blow
brought down from on high for Surprise Attack, a stoop and a fling for Throw Sand
(with whichever hand is free), Power Shot's bow held at full draw while motes
gather at the arrow, Volley loosed high (arrows going up, then raining down on the
marked ground), Rapid Fire's quick draws, lightning leaping from enemy to enemy,
arrows trailing the colour of what they carry, embers about him in a Frenzy, and
a crouch into shadow: hidden, he is drawn as a dark shape, creeps crouched, and
goes in and out of sight in a puff of smoke. Sleeping enemies show drifting Zs,
blinded ones question marks, ambushed ones a red halo.

### The wizard

The wizard's spells follow the wizard skills document: three trees, **Ice**,
**Fire** and **Lightning**, each spell opening once 0, 5 or 10 points are spent
in its own tree, with five ranks (Blazing Speed, Pyromaniac and Conductive Ice
have one). Percentages are of his spell baseline (10–15, raised 2% a point of
Intelligence and by his staff). Spells need nothing in hand. Every ice spell
chills what it hits (slowed 40% for 3 seconds) and ices the floor under it; ice
on the floor is what Conductive Ice conducts along. Two spells are **channelled**:
hold their button and they pour out for as long as it is held and his energy
lasts; letting go, moving or casting anything else ends them.

| Tree | Points | Spell | Energy | Ranks 1 → 5 |
|---|---|---|---|---|
| Ice | 0 | Ice Bolt | 10 | 100% → 180% ice damage; 4% → 20% chance to freeze the target for 3 seconds |
| | 0 | Freeze Floor | 10 a second | Channelled: a ray of frost ices the floor where it falls for 10 seconds; enemies on it move 40% → 80% slower |
| | 5 | Ice Spikes | 35 | Spikes across 4 metres where he aims: 100% → 180% |
| | 5 | Ice Prison | 45 | One enemy frozen in a block of ice for 2 → 6 seconds, unable to act and taking 20% → 60% more damage (damage does not break it) |
| | 5 | Improved Chill | | The chill slows 10% → 40% more and lasts 1 → 5 seconds longer |
| | 10 | Frost Blast | 20 a second | Channelled: frost 10 metres ahead, 70% → 150% a second to everyone within 3 metres of the stream |
| | 10 | Ice Storm | 40 | Frost about him for 6 → 15 seconds: 60% → 100% a second within 4 metres; frost spells deal double, and nothing else can be cast; 60-second cooldown |
| Fire | 0 | Fireball | 10 | 120% → 280% fire damage |
| | 5 | Blast Wave | 45 | Flame 5 metres in every direction: 125% → 235% |
| | 5 | Frostburn | | Fire deals 50% → 175% more to chilled enemies |
| | 10 | Fire Tornado | 45 | A tornado 4 metres across for 6 seconds: 50% → 100% a second; each second a 10% → 30% chance to make an enemy in it a Lightning Rod (if known) |
| | 10 | Blazing Speed | 50 | 6 seconds: run 75% faster, fire spells free; 60-second cooldown |
| | 10 | Pyromaniac | | Fire deals double, but each fire spell burns him for 10% of what it dealt, over 3 seconds |
| Lightning | 0 | Lightning Bolt | 10 | 100% → 220% lightning damage, instantly |
| | 0 | Lightning Shield | 50 | Absorbs 50 → 150 damage and shocks whoever strikes him for 20% → 50%, for 60 seconds; 60-second cooldown |
| | 5 | Lightning Rod | 30 | One enemy a rod for 10 seconds: whenever it is hurt, a jolt of 100% → 200% leaps to the nearest enemy within 5 metres and on to 3 more, each 30% weaker, at most twice a second |
| | 5 | Ignition | | Lightning spells have a 5% → 35% chance to set off 75% → 200% of fire within 2 metres of the target |
| | 10 | System Shock | 45 | Stuns one enemy for 5 → 12 seconds; damage breaks it; 45-second cooldown |
| | 10 | Conductive Ice | | Lightning leaps between enemies standing on one continuous stretch of ice |

Each spell is cast with its own gesture (`tools/import_wizard.py`): a one-handed
hurl for the bolts and the fireball, a pointed arm for Ice Prison, Lightning Rod
and System Shock, both hands raised and the palm driven down for Ice Spikes and
Fire Tornado, arms flung wide for Blast Wave, Ice Storm, Lightning Shield and
Blazing Speed, and a braced, held pose for the channels. Their effects are
`scripts/wizard_fx.gd`: frost on the floor that glitters and melts, bolts of ice
trailing cold and shattering, enemies closed in crystals of ice, spikes thrown up
from the floor, streams of frost, frost whirling about him; fire bursting out in
a ring with embers and smoke, a turning column of flame, heat and embers about
him as he runs, flames on him as he burns; lightning hurled and crackling where
it lands, jolting from a rod, sparking round a shield.

Enemy kills award XP, with diminishing rewards from enemies well below the
character's level. Each level after 1 grants five attribute points, to spend on
any attribute, and one skill point, up to level 25. Level alone adds no health,
damage or energy. XP thresholds
and authored floor enemy levels are explicit tables in `scripts/data.gd`. The
dungeons (enemy levels 1, 3, 5 and 8) bring a character to about level ten, and the
temple's three floors (levels 11, 15 and 19) to the cap of 25 before the summit.

Floor travel grants no points or XP. Permanent attribute gems have been removed.
Each class starts with its own armor and weapons (see Items), and finds more on
the enemies it kills.
Repeated death callbacks, reloads and retrying an already-rewarded enemy cannot
award its XP again. XP and skill investment survive death and travel.

Free respec is available in the attribute panel (C) at a safe floor entrance, out of combat; it
refunds earned attribute/skill points and clears the hotbar. Equipment and skill
assignments can change at any time. "In combat" means an enemy is
after the hero (awake to him and hunting him); his own attacks and skills do
not put him in combat. Maximum resource increases do not heal;
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
Living enemies reset when a save is loaded; defeated enemies, items lying on the
ground, and what the hero wears and carries persist. A save also records whether the hero is outside the temple or on one
of its floors, and where; saves from before the outdoor world (version 6 and
earlier) continue inside the temple. Autosaves run every eight seconds and on important progression events.
Writes use a temporary file and a backup. A damaged current save falls back to its
backup. Saves from before the level cap and the skill trees (version 5
and earlier) keep their class, campaign progress, weapons and defeated enemies;
a level above the cap of 25 comes down to 25, and every attribute and skill point is
refunded to spend again under the new rules. Saves from before the ranger's new
skills (version 7) gain the dagger slot; a ranger's skill points are refunded and
he is given his dagger. Version 1/2 saves migrate to a Warrior (or Ranger if a bow was equipped).
Saves from before items (version 10) are given their class's starting equipment, with any
other weapon they owned and can use in the bag. Old stat/gem bonuses are
refunded into a level-based point budget; use the + buttons (or C and K) to rebuild. Legacy gem
drops are retired. Fixed-layout saves move safely to the generated entrance.
Saves use Godot's native user-data directory,
separate from earlier games:

- macOS: `~/Library/Application Support/Godot/app_userdata/Temple Ascension 3D/`
- Windows: `%APPDATA%/Godot/app_userdata/Temple Ascension 3D/`

## Items

The whole of it, with every item's numbers and its chance to drop from each
kind of enemy for each class, is in **[docs/ITEMS.md](docs/ITEMS.md)**; all of
it is defined in `scripts/items.gd`.

A hero wears armor on his **head, chest, legs, feet and hands**, and holds
things in his **main hand** and **off hand**: one two-handed weapon, two
one-handed weapons, or a one-handed weapon and a shield. His bag holds ten
more items. What he wears and holds shows on him, in the world and in the
inventory.

| Class | Armor | Weapons |
|---|---|---|
| Warrior | Heavy | Swords, maces, axes, spears, bows, shields |
| Ranger | Medium | Bows, daggers, swords |
| Wizard | Light | Staves, daggers |

- **Armor** takes its percent off every blow, the pieces adding up (75% at
  most). The starting sets, which are the kits the heroes have always worn:
  heavy 26% (helm 5, cuirass 9, kilt 6, sandals 3, manica 3), medium 17%
  (3, 6, 4, 2, 2), light 10% (2, 4, 2, 1, 1).
- **A weapon's damage range** is what a normal attack hits for and the
  baseline of every skill made with it (a 200% skill deals 200% of that
  roll), before Strength or Dexterity. The starting sword, bow and dagger
  are all 10–15, as attacks were before items.
- **Wizards** are the exception: their spells and their staff's bolts have a
  fixed baseline of 10–15 raised by Intelligence, whatever they hold. A staff
  has no damage range; it can carry **spell damage** (the starting staff +5%).
- **Two weapons**: each blow adds half the off hand's damage range, and the
  hands strike by turns. **Bare hands** hit for 1–3.
- A **spear** reaches 2.9 m and a **two-handed** sword or axe 2.3 m, against
  1.9 m for the rest.
- The ranger starts with his bow in hand and his dagger in his bag. **X**
  changes between them, and a skill made with the one in the bag takes it up.
  A warrior's skills do not: with a bow in hand he cannot use them (his
  normal attack is a bowshot) until X puts a melee weapon back in it.

### How each weapon is swung

- **One-handed swords, maces and axes** are swung as the sword always was: its
  chain of three swings, and a swing of its own for each of the warrior's
  skills. An axe is not thrust: the one-handed axe's normal attack is the two
  cuts only, down one way and then the other, back and forth in an X.
- **Two-handed swords and axes** are held in both hands in their own stance,
  run and walk. The normal attack is two heavy blows by turns (a cut down from
  the right shoulder, then the return from the low left), and Cleave, Powerful
  Strike, Execute, Thunder Slam, Shockwave, War Cry and Leap each have their
  own two-handed motion (`tools/import_heavy.py`).
- **The spear** likewise, in both hands: two thrusts by turns (level, then
  low and rising), and its own sweep, lunge, plunge, slam, butt-strike, cry
  and leap for the same seven skills (`tools/import_pike.py`).
- Vampiric and Shadow Strike are struck with the weapon's own normal swing,
  the weapon glowing. Shield Bash and Shield Charge are the shield's, whatever
  one-handed weapon is beside it.
- **A weapon in each hand**: the right hand's blow and the left's by turns,
  the left's a mirror of the right's; standing and running, the left arm
  carries its weapon as the right does.
- **Daggers, bows and staves** keep the motions they had (any class that can
  hold them), and bare hands jab with each fist by turns.

### What drops

Any enemy that grants experience can drop one item as it dies: bandits 8% of
the time, gladiators, archers and lions 10%, Oracles and centurions 14%, and
the Crowned Statue always (a rare one). The item is one the hero's class can
use, common items five times as likely as rare ones (weights: common 10,
uncommon 5, rare 2). It lies on the ground as its own model with its name over
it; click the name to pick it up.

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

## Adaptation decisions

Enemy click areas have a minimum radius of 64 logical pixels, with extra room
for tall enemies at close zoom. Every enemy in sight carries a small health
bar above its head; hovering one shows a red ring at its feet. While the ring
shows, every attack and
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
3D floor, wall and prop meshes populate that layout. The second- and third-floor
courts have the original broad, shallow pool and a three-tier stone fountain. The player can
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
cover the wizard's spells (`tests/wizard_skills.gd`: every spell's numbers, its chill, freeze, fire and lightning, the channels, Ice Storm's rule and the passives), the item system (`tests/items.gd`: the catalogue, class rules, the slots
and the bag, weapon damage under attacks and skills, armor, drops and picking
up, items on the hero's figure, every class's attacks with every kind of
weapon, and the inventory), class creation, all 40 skills, the warrior's three trees with every listed
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
