# Temple Ascension 3D

Native Godot adaptation of `/Users/ktabb/Documents/workspace/TempleAscension`.
Choose Warrior, Ranger or Wizard when creating a character. The campaign starts at the temple entrance; progression follows the class, attribute and skill rules in the v2 plan.

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
| Space | Evade, no energy cost, three-second recharge |
| Q | Drink a flask: 40% health over two seconds, three charges, eight-second cooldown |
| 1 / 2 | Cast the other two assigned active skills |
| C / K / I | Character attributes / skills and assignments / equipment |
| Mouse wheel | Zoom |
| E | Ascend, claim the crown, or rest/refill flasks at a safe entrance |
| Escape | Pause, continue saved game, choose new run/difficulty, sound, quit |
| F11 | Fullscreen |

Clicking the ground cancels a combat order. While idle, the hero faces the cursor. Architecture
between the camera and the hero becomes translucent. The HUD reports the nearest
remaining statue and the direction to it.

The HUD has a red health orb at bottom left, a blue energy orb at bottom right,
and four compact clickable ability icons centered below the action: LMB basic
attack, RMB skill, 1 and 2. Class, level, XP and
available points appear at top left. Floor, remaining statues and difficulty
appear at top right. Unassigned, incompatible, and recharging skills are disabled
with an explanation. Character, skill and equipment screens pause combat.

The temple's dark interiors are illuminated mainly by torch stations, with
animated flames, rising embers and subtle independent light flicker. The
terraces on floors four and five look down onto nearby moonlit dunes and ruins,
with mountains and a river farther away. The dark panorama appears only while the player is on a terrace,
where a dim cool moonlight also catches the paving and parapets.

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
| B | Jump to summit and grant enough XP for level 25; repeated use grants nothing extra |
| L | Return to floor 1 with stats and weapons intact |
| T | Restart the current floor with stats and weapons intact |
| R | Reset the run and turn off invulnerability |
| F10 | Jump to this adaptation's crown ending and completion summary |
| P | Hide/show the panel; shortcuts remain active |

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
statues and alert nearby allies. The five floors now use the original game's
seeded room-and-corridor format: 5–10 tile rooms, three-tile-wide passages,
extra connections that form loops, and ascent stairs in the most distant room.
Floors grow from 50×50 to 74×74 tiles. The third floor includes a large central
court with two entrances; floors four and five add mirrored wraparound galleries.
Statues line the walls facing inward, with a safe area around the entrance.
The summit remains a single arena with four corner groups of offerings.

## Classes and progression

All classes start with Strength, Dexterity, Intelligence, Vitality and Willpower
at 5, 100 health, 100 energy, and 8 energy regenerated per second. Above the base:

| Attribute | Per point |
|---|---|
| Strength | +2% melee damage |
| Dexterity | +2% ranged damage |
| Intelligence | +2% spell damage |
| Vitality | +10 maximum health |
| Willpower | +3 maximum energy and +0.1 energy per second |

Warrior starts with sword/shield and Cleave; Ranger with bow and Power Shot;
Wizard with staff and Firebolt. The first skill point is spent on that starter.
Each class has the plan's eight active skills and four passives, unlocking at
levels 1, 4, 8, 12 and 18. Active skills have five ranks; passives have three.
Rank is limited to `1 + floor((level - unlock_level) / 3)`. K shows scaling,
requirements, cost, cooldown and the next rank's value. Assign three active skills
to RMB, 1 and 2; passives work automatically. Bow skills need a bow, spells a staff,
and Shield Bash needs sword/shield. All classes can equip every owned family.

Enemy kills award XP, with diminishing rewards from enemies well below the
character's level. Each level after 1 grants three attribute points and one skill
point, up to level 30. Level alone adds no health, damage or energy. XP thresholds
and authored floor enemy levels are explicit tables in `scripts/data.gd`. The
current 247-enemy temple route reaches about level 23 before the summit; this
balance is for the existing climb, not the plan's future pre-temple regions.

Floor travel grants no points or XP. Permanent attribute gems have been removed.
Each class starts with only its own weapon: sword for Warrior, bow for Ranger,
and staff for Wizard. Bow and axe drops are disabled for now; the staff drop on
floor three remains.
Repeated death callbacks, reloads and retrying an already-rewarded enemy cannot
award its XP again. XP and skill investment survive death and travel.

Free respec is available through C at a safe floor entrance, out of combat; it
refunds earned attribute/skill points and clears the hotbar. Equipment and active
assignments can change out of combat. Maximum resource increases do not heal;
refunds clamp current resources. Flasks replace the old energy-based heal and
there is no default health regeneration. E at a safe entrance refills charges.

Sword, axe, spear and bow attacks retain their authored animation timing. Staff
basic attacks launch free arcane bolts. Bow draws stay clear of the torso and neck,
with dedicated carry poses for running and crouching. Class skills add distinct
projectiles, sweeps, traps, defensive buffs, crowd control and area effects using
the existing authored models and VFX assets.

The summit statue has 1,250 base health, cleave and a warned sweeping gaze. At
80%, 60%, 40%, and 20% health, five corner offerings awaken and try to heal it.
Claiming the crown triggers petrification and the elders' reveal, then a completion
summary. Elapsed playtime and best-time records are neither tracked nor displayed.

Each new run generates a different temple. Retrying or continuing a save restores
the same rooms, passages, stairs and statue positions for that run and floor.
Death restarts the current floor while preserving class, XP, attributes, skills and weapons.
Living enemies reset when a save is loaded; defeated enemies and loose drops
persist. Autosaves run every eight seconds and on important progression events.
Writes use a temporary file and a backup. A damaged current save falls back to its
backup. Version 3 saves keep their first three assigned skills (RMB, 1 and 2);
all learned skills remain available in K. Version 1/2 saves migrate to a Warrior (or Ranger if a bow was equipped).
Campaign progress, weapons and defeated enemies remain. Old stat/gem bonuses are
refunded into a level-based point budget; open C and K to rebuild. Legacy gem
drops are retired. Fixed-layout saves move safely to the generated entrance.
Saves use Godot's native user-data directory,
separate from earlier games:

- macOS: `~/Library/Application Support/Godot/app_userdata/Temple Ascension 3D/`
- Windows: `%APPDATA%/Godot/app_userdata/Temple Ascension 3D/`

## Adaptation decisions

The local library supplies humanoid rigs, so the original lion enemy is represented
by a crouching humanoid Lion Guardian with the original fast pursuit and attack
cadence. All humanoid statues and the hero use the requested local model and
animation library. The room placement, seeded random generator, corridor
connections, court footprint and galleries are adapted from the browser game's generator. Existing imported
3D floor, wall and prop meshes populate that layout. The third-floor court has
the original broad, shallow pool and a three-tier stone fountain. The player can
wade through the water, leaving ripples, while the solid centerpiece remains an
obstacle. The original bubbling water loop grows louder near the fountain and is
silent outside the room. The ending
is staged in the summit with dialogue. This adaptation does not submit scores to
the original public leaderboard.

All solid architecture, equipment and character meshes are imported 3D assets;
the distant desert is a generated image backdrop. There are no primitive-mesh
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
cover class creation, all 36 skills, rank limits, shared stat formulas, migration,
XP reward deduplication, 200 generated maps, navigation, attack timing, all eight
animations, bow orientation and visible blade contact. Debug regression checks
cover launch gating, save isolation, all shortcuts, floor resets, level shortcuts,
and clickable panel controls. Native input testing
uses a rendered window and injected mouse/keyboard events; screenshots and test
reports are written under `test-results/`. Test scripts are excluded from exports.
