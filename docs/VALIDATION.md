# Validation

`tests/campaign.gd` runs in a headless Godot process with test-only saves. It
checks all 247 regular enemies through the actual scheduled melee damage path,
reachable placement and stairways, weapon pickup, kill XP, point budgets,
flasks, evade invulnerability, wall collision, death persistence, boss offerings,
gaze warning, crown ending, summary and corrupted-save recovery. Stairways grant
no points, and repeat death callbacks or retries cannot duplicate kill XP.
It controls player placement and cooldowns to make the run deterministic and
fast; it is not a claim of a complete manual playthrough.

`tests/input_playtest.gd` opens a native rendered window and dispatches actual
input events through Godot. It checks mouse movement, held target attacks,
pause/resume, paused clock, dash, weapon switching and save/continue. Its cursor
regression covers UI scaling versus the camera's render coordinates.

`tests/preview.gd` captures the entrance, hall, character, crowded fifth floor and
summit, and records the fifth-floor frame rate. Screenshots and JSON/log outputs
are under `test-results/`. Native exports exclude tests. Developer controls require
the explicit debug launcher and use isolated saves.

Export success verifies packaging, not execution on another operating system.
Windows requires a playtest on Windows hardware. macOS signing is ad-hoc only.

Compact ability bar and starting equipment (0.4.1): 98 progression checks,
155 class runtime checks, 555 campaign checks and 52 native HUD checks pass.
The HUD has exactly four 56×64 buttons with 40×40 icons, ordered LMB basic
attack, RMB skill, 1 and 2. Its total width is 236 pixels instead of 482.
All four buttons were exercised with actual mouse events, and rendered captures
at four window sizes were inspected. Each new class owns only its starting
weapon. Campaign coverage confirms no bow or axe drops and retains the staff
drop. Version 3 saves keep their first three assigned skills and all learned
ranks; pending bow/axe drops are removed. Older owned weapons remain available.

Class/progression update (0.4.0): the current headless suite passes 2,705 checks:
94 progression, 155 class runtime, 1,721 procedural maps, 24 map integration,
73 scenery, 6 torch, 21 bow, 552 campaign, 37 combat timing, and 22 normal/debug
mode checks. Progression coverage includes shared stat formulas, all 36 skills,
rank gates, level-25/30 point conservation, multi-level awards, respec, migration
and save round trips. Runtime coverage exercises all 24 active skills, defensive
effects, traps, persistent attacks, weapon requirements, free basics, cooldowns,
flasks, evade and XP deduplication across death/retry.

Native class captures pass the same 155 runtime checks. Character and skill
screens for all three classes were visually inspected. The native HUD suite
passes 54 checks across four window sizes, including class creation and clickable
skill slots; directional controls pass 343 checks. These deterministic tests
verify mechanics, not campaign difficulty or a manual playthrough of every build.
The native input playtest passes 11 checks, including held movement/attacks,
pause, evade, the I equipment screen, and save/continue.
The existing temple route reaches approximately level 23 before the summit;
the plan's future regions, objectives and item economy are outside this update.

Both 0.4.0 distribution archives pass CRC checks and contain the same game data
as their unpacked builds, plus asset notes, licenses and debug launchers.
The macOS bundle reports 0.4.0 and passes strict ad-hoc signature verification.
Both exported PCKs pass an isolated-save smoke test loading all three classes,
the 36-skill roster, starter casts and XP/point budgets through the local Godot
runtime. This does not execute the Windows binary. Several headless tests,
including these smoke tests, report ObjectDB/resource-in-use messages at engine
shutdown despite passing their assertions and exiting with code 0; the native
HUD, controls and input runs exit cleanly. Checksums are in `builds/checksums.json`.

The entries below record earlier releases; their old stat, gem, weapon-hotbar
and special-attack behavior has been superseded by the class system above.

Lighting update (0.3.2): rendered entrance, hall, character, fifth-floor combat,
and summit screenshots were inspected with isolated preview saves. All 317
campaign checks passed after aligning the perimeter walls to the floor edge.
The exterior geometry and daylight are removed; 28 imported flame torches light
the interior. Architecture shadows are limited to two nearby torches, using a
1024-pixel atlas. Floor batches are spatially partitioned for local light selection.

On this Intel Iris Plus workstation, a controlled frozen-crowd comparison measured
20.17 FPS with torches versus 19.94 FPS with the former daylight configuration.
The active fifth-floor preview measured 15 FPS and 183 draw calls under the current
workstation load. These measurements replace the earlier daylight-only performance
sample; frame rate varies with load, view, combat and hardware.

Controls regression (0.3.1): `tests/controls_regression.gd` checks real rendered
cursor coordinates at four window sizes/aspect ratios, clicks in eight directions,
held steering, exact destinations, Shift stopping, doorway navigation, released
pursuit orders, and every weapon's normal/special damage in eight directions.
It also checks the animated head direction, spear shaft and arrow mesh alignment.
Mouse warps use physical window pixels; camera projection uses logical viewport
pixels. These tests isolate saves and freeze enemy AI to test controls reliably.

317 campaign checks, 343 directional controls checks and 10 native gameplay input
checks pass. This supplements automated coverage with captured leftward attack
frames; it is not a claim of manual testing on Windows.

The exported macOS app launched independently and exited cleanly after 180
frames with `--quit-after 180 --time-scale 0 --verbose`, with no script/runtime errors.
Release templates ignore `--script`; external test harnesses cannot isolate their
saves. The first normal launch briefly advanced the existing run timer before
auto-pausing; the final bounded launch froze game time. `codesign --verify --deep --strict` passed.
The Mach-O contains both x86_64 and arm64 slices; the Windows executable is
PE32+ x86-64. Both distribution ZIP archives passed CRC integrity checks.

Attack animation update (0.3.3): `tests/attack_preview.gd` renders all eight
normal/special attacks, checks full swing travel and frontal blade contact,
and samples both bow animations for upright alignment in eight aim directions.
Its 42 checks pass; the eight pose galleries were inspected. Library cuts are
retimed separately from wind-up and recovery to make the swing itself readable.
`tests/combat_timing.gd` checks anticipation, contact/release timing, three
separate Rapid Fire releases, repeated-input protection, energy costs, Dexterity
scaling and dash cancellation: 59 checks pass. The campaign and directional
controls suites also pass (317 and 343 checks). All test saves remain isolated.
The live native gameplay suite passes all 10 checks, including held cursor
steering, repeated attacks, weapon switching and save/continue. The 0.3.3
macOS/Windows exports were rebuilt; archive integrity and macOS ad-hoc signature
checks passed. The earlier standalone-launch result above applies to 0.3.2;
0.3.3 was exercised through the native Godot runtime using isolated saves.

Procedural map update (0.3.4): `tests/procedural_maps.gd` checks 200 layouts
across all five floors, including zero, high-bit and full unsigned seeds.
All 1,721 checks pass: connectivity of every walkable tile, distant/reachable
stairs, room count, enemy capacity and safe placement, deterministic regeneration,
layout variation, the central court's two doors, and mirrored galleries.
The sample run has 11 / 15 / 10 / 23 / 25 rooms on its five floors.

`tests/map_integration.gd` passes 24 checks covering radius-aware routes to
all statues, actual movement through the generated corridors to each stairway,
identical retries, saved positions, dead enemies, pending loot and legacy-save
migration. The campaign passes 317 checks, combat timing 59, native directional
controls 343, and live gameplay input 10. The controls tests choose a generated
room and navigate between the generated entrance and exit, replacing assumptions
about the former partition coordinates. All saves used by tests are isolated.

`tests/map_preview.gd` captures all six entrances, room views and map overviews.
Overview captures disable light distance fading solely to display the whole map
from above; normal game lighting retains distance fading and local torch shadows.
The court uses imported altar/chalice meshes for the original central fountain
footprint. No mesh geometry is generated at runtime. Native source playtests ran
on macOS; the Windows release still requires Windows hardware testing.

Both 0.3.4 distribution ZIPs passed CRC integrity checks. The macOS app
reports version 0.3.4 and passes strict ad-hoc signature verification.

HUD update (0.3.5): `tests/hud_regression.gd` passes 49 checks across four
window sizes. It verifies corner orbs at empty/half/full values, four centered
weapon panels without overlap, top-right floor information, locked weapons,
real mouse clicks equipping each weapon without issuing movement, and legacy
saves dropping elapsed time from both current and backup files. Completion no
longer creates time records. Rendered partial/full/unlocked HUD and completion
screens were inspected. `tools/render_weapon_icons.gd` bakes transparent icons
from the actual weapon meshes. The campaign (317), combat timing (59), map
integration (24) and procedural-map stress tests (1,721) pass with the new HUD.

The final 0.3.5 native controls suite passes 343 checks and live input passes
10 checks, for 2,523 checks in the exercised suites. Both distribution ZIPs
pass CRC checks; the macOS bundle reports 0.3.5 and passes strict ad-hoc signature
verification. Windows gameplay remains untested on Windows hardware.
