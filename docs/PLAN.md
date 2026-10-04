# Temple Ascension V2 — Game and implementation plan

Draft 1 · September 26, 2026

**Recommendation:** build a single-player, offline, fixed-camera 3D action RPG
with persistent characters, deliberate build choices, and equipment-driven
combat. Target 150–180 minutes before the temple, then a 75–90 minute finale.
Use Godot with typed GDScript and a modular Blender art pipeline.

This is a proposed design and production plan, not an implementation or a final
balance specification. Numbers, skill names, locations, and encounter themes
below are starting proposals. The story remains for the author to write.

## 1. Requirements and working assumptions

| Confirmed requirement | What it means for the design |
|---|---|
| Fully 3D | 3D environments, characters, equipment, animation, lighting, and collision |
| Standalone Windows and Mac game | Native desktop exports, local saves, desktop settings and packaging |
| More Diablo-like | Real-time combat, repeatable loot opportunities, equipment comparison, XP levels, and class builds |
| Substantial play before the temple | At least 2–3 hours of intended first-play content before the final climb |
| Three classes | Warrior, Ranger, Wizard, selected when creating a character |
| Shared stats | The same attributes, meanings, and calculation rules for every class |
| Class-specific skills | Learn skills and invest earned skill points to improve them |
| No floor/gem stat progression | Entering floors and collecting gems never grant permanent attributes |
| Story not yet written | Gameplay objectives and narrative triggers must support later writing |

**Proposed defaults:** single-player and offline; one campaign per character;
fixed elevated camera with limited zoom; click-to-move; stylized Mediterranean
fantasy; manually allocated attribute points; identical starting attributes
across classes. These choices can change without changing the core requirements.

Launch scope excludes multiplayer, a seamless open world, seasons, infinite
endgame, procedural storytelling, and a large crafting economy. Controller
support is a later milestone unless it becomes a launch requirement; keep input
actions independent of keyboard bindings from the beginning.

## 2. What carries forward from V1

The reviewed V1 is a Phaser/TypeScript browser game with five temple floors,
animated statues, a crowned summit boss, floor-based stat allocation, and gems
that permanently increase attributes for the run. Its local save code stores
settings and records rather than a persistent campaign character.

| Carry forward | Rework for V2 |
|---|---|
| Mediterranean architecture, stone guardians, terraces, summit spectacle | Model the world in 3D and introduce several environments before the temple |
| Readable attacks, ranged enemies, dodge timing, boss telegraphs | Animation-based attacks, class abilities, armor, resistances, and status effects |
| Five-floor climb and distinct summit | Make this the final campaign act, reached with an established build |
| Data-driven balance and engine-independent combat calculations | Reimplement as typed data and testable gameplay services |
| Seeded layouts and reward identities that survive retries | Extend to persistent encounters, generated item instances, and save-safe rewards |
| Music, atmosphere, architectural references | Audit licenses and suitability before reusing any assets |

Treat this as a new game implementation. Phaser scenes, 2D collision, sprite
rendering, browser storage, and Vite packaging do not form the V2 runtime.
Port useful rules and test cases deliberately. Do not carry over V1's floor
point awards, gem stat boosts, exact combat numbers, or mandatory full-floor
enemy clears. The original crown reveal is inspiration only; V2's ending is open.

Reviewed local sources: [V1 README](../../TempleAscension/README.md),
[design document](../../TempleAscension/docs/GDD.md),
[RunState](../../TempleAscension/src/systems/RunState.ts),
[combat](../../TempleAscension/src/systems/Combat.ts),
[gem drops](../../TempleAscension/src/systems/GemDrops.ts), and
[save data](../../TempleAscension/src/systems/SaveData.ts).

## 3. Tools and technology

### Recommended stack

| Area | Choice | Purpose |
|---|---|---|
| Engine | Godot 4.7.2 stable as the initial candidate | 3D runtime, editor, physics, navigation, animation, UI, desktop exports |
| Gameplay | Typed GDScript | Keep the initial game in one engine-native language; isolate calculations from scene code |
| Rendering | Start with Mobile renderer; benchmark before locking it | Modest stylized scenes, baked lighting, limited dynamic shadows |
| Modeling and animation | Blender; export `.glb` | Modular environments, one shared humanoid rig, weapons, interchangeable armor |
| Game definitions | Custom Godot Resources (`.tres`) | Items, affixes, skills, enemies, encounters, regions, and balance curves |
| Narrative | Stable text IDs and simple dialogue/objective data | Add story without changing combat or progression code |
| Audio | Godot audio buses; WAV effects and Ogg music | Separate master, music, ambience, UI, and combat controls |
| Version control | Git; Git LFS for large source art/audio | Review text changes and keep binary assets manageable |
| Verification | Headless Godot test runner, content validator, exported build smoke tests | Check rules and persistence separately from visual playtests |
| Builds | Pinned editor/export templates; Windows and macOS CI jobs | Reproducible downloadable test builds at every milestone |

Godot's official archive currently lists 4.7.2 as stable. Pin the selected
version and matching export templates after the technical spike; upgrades get
their own branch and regression pass. [Official release archive](https://godotengine.org/download/archive/).

The Mobile renderer also supports desktop. My recommendation is based on this
game's proposed visual scope. Compare it with Forward+ in a crowded temple
scene; choose Forward+ only if its lighting benefits justify measured cost.
Compatibility is an alternative if older hardware becomes a requirement, and
needs separate visual testing. [Renderer documentation](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html).

Godot recommends glTF for 3D assets. Keep editable `.blend` sources outside
the runtime import tree and commit exported `.glb` files so builds do not need
Blender installed. [3D import documentation](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html).

Custom Resources fit editable game definitions; keep them immutable during play
because loaded resources can be shared. Rolled items and character state must be
separate instances. [Resource documentation](https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html).

Godot is the project recommendation, not a user requirement. Revisit the engine
only if the technical spike exposes a concrete export, performance, or required
asset-pipeline problem. Unity/C# is an alternative if an existing team or asset
investment favors it; this plan assumes neither. A custom engine would add work
outside the game's distinguishing features.

### Desktop delivery and performance

- Windows: x86_64 release, distributed as an executable plus its data pack in
  a ZIP or installer. An executable need not be a single self-contained file.
  [Windows export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_windows.html).
- macOS: universal app for Apple Silicon and Intel, subject to testing on both;
  package as ZIP/DMG. Budget for Developer ID signing, notarization, and a
  stapled ticket for normal direct-download distribution. Make a signed test
  build early. [macOS export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_macos.html).
- Initial support targets: Windows 11 and macOS 13+, with exact hardware minimums
  set from measured builds. An Apple Silicon Mac and a modest Windows GPU are
  the first test machines; Intel Mac support needs an actual test machine too.
- Target 60 fps at 1080p in ordinary combat. Stress-test 30 active enemies plus
  projectiles and effects; this is a proposed test load, not a proven limit.
- Use zone loading, baked environment light, limited shadow-casting lights,
  instanced decorations, and visibility culling. Never hide attack telegraphs
  when lowering graphics settings.
- Prototype budgets: player under roughly 25k triangles, ordinary enemies under
  15k, and mostly 1k/2k textures. Profile animation, navigation, and overdraw as
  well as triangle counts. Revise these budgets from the slice.
- Test launching downloaded builds, saving outside the install directory,
  fullscreen/windowed mode, high-DPI UI, audio devices, and reopening saves.
- Put signing credentials in CI secrets. Track asset licenses and attribution
  alongside source assets. Release planning includes art/audio costs, signing
  credentials, CI, and test hardware; exact costs are not assumed here.

## 4. Campaign skeleton and duration

Use a hub connected to discrete, authored regions. Each region contains a
required route, short optional branches, a checkpoint, and a regional encounter.
The main route supplies the advertised duration; side quests add time beyond it.

```mermaid
flowchart LR
    A[Character creation and opening] --> B[Hub]
    B --> C[Region 1: fundamentals]
    C --> D[Region 2: specialization]
    D --> E[Region 3: mastery and approach]
    E --> F[Temple staging checkpoint]
    F --> G[Five temple floors]
    G --> H[Summit encounter]
    H --> I[Story resolution]
```

| Phase | Required first-play time | Expected levels | Gameplay purpose |
|---|---:|---:|---|
| Opening and first hub visit | 15–20 min | 1–3 | Move, attack, evade, equip a drop, spend a point |
| Region 1: outskirts / roads | 40–45 min | 3–8 | Melee and ranged threats, first elite, first regional boss |
| Region 2: ruins / underground works | 45–55 min | 8–13 | Flanking, status effects, environmental objectives, build specialization |
| Region 3: highlands / sacred approach | 50–60 min | 13–19 | Mixed enemy groups, dangerous elites, third regional boss, final preparation |
| **Before temple subtotal** | **150–180 min** | **About 18–20 at entry** | **A functioning character build before the finale** |
| Temple floors and summit | 75–90 min | About 19–25 | Escalation and mastery of established mechanics |
| **Campaign gameplay total** | **225–270 min** | **About 24–26 at completion** | **3 h 45 min–4 h 30 min** |

Durations are targets for a first-time Normal player, not enforced timers or
guarantees for experts. They exclude repeated deaths, deliberate grinding,
credits, and long optional dialogue. Region time includes normal short hub and
inventory stops. Story scenes can add time but must not make up a gameplay deficit.

Budget approximately three 12–16 minute gameplay sections per region, with
regional bosses and connectors filling the remaining time. Each section has
several small fights, a landmark or objective, and a meaningful reward. Vary
encounter compositions, hazards, and routes instead of merely increasing HP.

Initially plan one hub, nine required regional sections, three regional bosses,
three optional side areas totaling another 30–45 minutes, five temple floors,
and one summit arena. Regional names and motivations are placeholders. Optional
branches provide extra loot, XP, and lore; they are not mandatory level gates.

The campaign unlocks the temple through objective completion, not a required
level, gear score, or random key drop. The entrance shows a recommended level
range. A player following the required route should be ready without farming.

## 5. Character rules

### Shared attributes and progression

Every class uses these five attributes with identical formulas and starts with
5 in each. The classes differ through skills, starting equipment, and preferred
combat approaches. There are no hidden class multipliers to base health or damage.

| Attribute | Proposed effect per point above the shared base of 5 |
|---|---|
| Strength | +2% damage to attacks tagged `melee` |
| Dexterity | +2% damage to attacks tagged `ranged` |
| Intelligence | +2% damage to attacks tagged `spell` |
| Vitality | +10 maximum health |
| Willpower | +3 maximum energy and +0.1 energy regenerated per second |

`melee`, `ranged`, and `spell` are mutually exclusive scaling tags on each
damage component. Damage type is separate: a melee strike can deal fire damage,
and a wizard projectile remains a spell. A Ranger using a melee basic attack
uses Strength; a Warrior's ranged basic attack uses Dexterity. Attribute rules
never change based on class. Skill tooltips show their scaling attribute.

- Start at level 1. Proposed cap: 30; expected campaign completion: level 24–26.
- Each level after the first grants **3 unspent attribute points and 1 skill
  point**. Creating a character grants 1 initial skill point, spent on a starter
  skill during onboarding. At level 25, this means 72 earned attribute points
  and 25 total skill points; at level 30, 87 and 30.
- The level number alone adds no attributes, health, damage, or resource capacity.
  The player spends points; gear and learned skills supply the other bonuses.
- XP comes from enemies and completed objectives. Objective rewards may include
  XP, gold, and equipment, but never direct attribute or skill-point grants.
- Floor transitions award no points or special progression bonuses. A boss on
  a floor can grant ordinary XP just like a boss elsewhere.
- No permanent attribute consumables. Omit gems initially; if added later,
  sockets modify only equipped items and their bonuses disappear on removal.
- XP thresholds live in an explicit balance table. Tune required-route XP to
  the level bands above, roughly 70% combat / 30% objectives initially.
- Early levels arrive in roughly 3–6 minutes; middle levels in roughly 8–12.
  Tune from route playtests rather than enforcing these intervals mechanically.
- Regions have authored enemy level bands. Do not scale every enemy to the player
  on each level-up. Low-level farming gets diminishing XP; late areas remain
  dangerous and early enemies become easier.
- Attribute and skill respecs are free at the hub and temple safe checkpoints.
  Respecs refund earned points and revalidate skill dependencies and hotbar slots.
  Loadouts can be changed out of combat; no respec during a fight.

### Resources, defense, and combat

Start all classes with 100 health, 100 energy, and 8 energy/second. Basic attacks
cost no energy. Active skills use energy, cooldowns, or both. Keep one shared
resource system initially; class skills create different rhythms without three
separate resource implementations.

Use a refillable healing flask: three charges, restoring an initial target of
40% max health over two seconds, with a shared eight-second cooldown. Refill at
checkpoints; award limited refills from fixed encounters. No default in-combat
health regeneration. Healing affixes and skills can add explicit exceptions.

Universal evade: one charge, three-second recharge, no energy cost, with a short
tested invulnerability window. Movement must respect collision and cannot cross
walls or fall from the map. Class movement skills can supplement it. Cancel
attack recovery into evade; specify uncancellable commitment frames per ability.

Use per-ability windup, hit, recovery, and cooldown rather than V1's universal
half-second combat lock. Attack/cast speed reduces animation timing within
authored bounds; cooldown reduction is separate. Crit chance, crit multiplier,
speed, armor, and resistances are derived stats available to every class.

Provisional damage pipeline:

1. Weapon damage for melee/ranged attacks, or implement spell power for spells.
2. Skill coefficient for its invested rank.
3. Scaling attribute multiplier, then one additive bucket of applicable damage
   bonuses. Prevent one bonus from applying twice through overlapping tags.
4. Critical strike multiplier where allowed.
5. Target mitigation, then shields, then health.

Armor mitigates physical damage; fire, frost, and arcane use their respective
resistances. Start with `armor / (armor + 100 + 20 × attacker_level)` for physical
reduction, capped at 75%, and elemental resistance capped at 75%. These constants
are balancing seeds. Enemy attacks use the same mitigation service. Damage over
time does not crit initially; repeated applications refresh unless a skill
explicitly specifies stacking. Bosses resist hard crowd control through a
shared stagger meter instead of allowing permanent stun loops.

Equipment bonuses are recalculated from base values, allocated points, equipped
items, skills, and temporary effects. Never repeatedly add bonuses into saved
base stats. Removing max-health equipment clamps current health downward;
equipping it does not heal. Apply the same rule to energy.

### Controls, camera, and readability

Use an elevated fixed-angle perspective camera with limited zoom. Keep terrain
genuinely 3D, but build combat around readable ground surfaces, ramps, and stairs.
Avoid platform jumping and overlapping navigable floors in the first release.

Left click moves, interacts, or basic-attacks; Shift holds position. Right click
plus 1–4 provide five assignable active skill slots. Space evades; Q drinks a
flask; I opens inventory; C opens character stats; K opens skills; Tab opens the
map. All bindings are remappable. Loot pickup must not steal an attack click
while an enemy is being targeted; holding the loot-label key prioritizes loot.

Include separate move-only binding, wall/roof fading, target outlines, scalable
UI, readable text, independent screen-shake and flash settings, and telegraphs
that remain distinguishable without relying only on color. Single-player pause,
inventory, and skill screens pause combat. Dialogue locks gameplay input.

## 6. Classes and skill investment

Each class gets **8 active skills and 4 passives** at launch. Five active slots
force loadout choices; learned passives apply automatically. Basic attack,
evade, and flask are separate from the skill tree and require no points.

| Class | Intended play | Example build directions |
|---|---|---|
| Warrior | Close combat, positioning, stagger, survivability | Shield defender, two-handed cleaver, mobile spear fighter |
| Ranger | Ranged pressure, spacing, traps, priority targets | Precision shots, spread attacks, trap control |
| Wizard | Spell combinations, area control, resource timing | Fire damage, frost control, arcane burst |

Classes share armor access and basic weapon use. Individual class skills state
weapon requirements: shield actions need a shield; bow skills need a bow or
crossbow; spell skills need a staff or wand. Equipping an incompatible weapon
disables the affected hotbar slot with an explanation. Class identity comes
from the skills available to learn, not different definitions of Strength or
Vitality. Start each class with a suitable weapon and modest armor.

Proposed skill roster; **(P)** marks a passive. Names are placeholders.

| Unlock level | Warrior | Ranger | Wizard |
|---|---|---|---|
| 1 | Cleave: frontal sweep; Guard: brief defense; Endurance (P) | Power Shot: charged shot; Snare: slowing trap; Steady Aim (P) | Firebolt: projectile; Frost Nova: nearby control; Attunement (P) |
| 4 | Shield Bash: stagger; Lunge: gap closer; Weapon Training (P) | Multishot: spread; Retreating Shot: reposition; Quick Draw (P) | Arcane Lance: piercing line; Barrier: absorb damage; Efficient Casting (P) |
| 8 | Whirlwind: moving area attack; War Cry: short buff | Piercing Arrow: line attack; Explosive Trap: delayed area damage | Chain Lightning: jumping hit; Blink: constrained teleport |
| 12 | Thunder Slam: directional shockwave; Bulwark (P) | Marked Prey: single-target setup; Trapcraft (P) | Blizzard: persistent area control; Elemental Mastery (P) |
| 18 | Execution: finisher; Battle Rhythm (P) | Rain of Arrows: area barrage; Predator (P) | Meteor: delayed burst; Arcane Reserve (P) |

Active skills have five ranks; passives have three. One point buys a first rank
or upgrades it by one. Available rank is capped by
`1 + floor((character_level - skill_unlock_level) / 3)`, up to the skill's maximum.
This prevents maxing a freshly unlocked skill immediately. Display locked ranks
and their requirements. Avoid additional prerequisite chains in the first pass.

Ranks improve explicit values such as damage, duration, energy efficiency, or
cooldown. For example, a five-rank Cleave could progress from 140% to 220% weapon
damage in 20-point steps, with its energy cost unchanged. Every upgrade previews
its effect. Do not give the same rank damage, speed, radius, and cost improvements
simultaneously without a specific balance reason.

At level 25 the player has 25 points against 52 possible ranks. They can develop
a focused loadout but cannot maximize the entire class. No skill points drop as
loot. Initial item affixes do not grant skill ranks; build-changing items alter
specific skill behavior through bounded modifiers instead.

Validate each class with a single-target option, an area option, a defensive
answer, and a way to handle ranged pressure. Every required encounter must be
beatable with ordinary on-level gear and more than one build per class.

## 7. Equipment, drops, and economy

### Equipment model

Eleven slots: main hand, off hand, head, chest, hands, legs, feet, belt, amulet,
and two rings. Two-handed weapons occupy both hand slots. Start without a second
weapon-set hotkey to keep equipment state and animation scope manageable.

Weapon families: sword, axe, spear, bow, crossbow, staff, and wand. Shields and
arcane focuses fill the off hand. Staffs, bows, crossbows, and designated heavy
melee bases use two hands. Each definition declares its hand occupancy.

Light, medium, and heavy armor offer different intrinsic tradeoffs: lower armor
with resource benefits; balanced armor with mobility benefits; or higher armor
with fewer offensive/resource benefits. All classes can wear all three. Use level
requirements initially, avoiding attribute requirements that make respecs break
the equipped loadout.

Plan **60–90 base item definitions**, **24–30 affix types**, and **12 unique
items** for the complete campaign. Definitions include tier variants; this is
not a promise of 90 different meshes. Use three regional item tiers plus temple
roll ranges, a small set of weapon silhouettes, and interchangeable armor pieces.
Every visible equipment change should match its family and armor style; rings
and amulets need icons but not separate visible character meshes.

| Rarity | Proposed properties | Function |
|---|---|---|
| Common | Base item properties | Starter equipment and comparison baseline |
| Magic | Base plus 1–2 random affixes | Frequent useful upgrades |
| Rare | Base plus 3–4 random affixes | Main campaign build equipment |
| Unique | Authored affixes and one special behavior | New build possibilities; not required to win |

Useful affixes include attributes, maximum health/energy, physical or elemental
damage, attack/cast speed, crit, cooldown reduction, armor, resistances, and
skill-tag bonuses. Affix groups prevent contradictory or repeated rolls.
Each affix has eligible slots, minimum item level, roll range, and stacking rule.
Rarity never guarantees that an item is better for the current build.

Example unique directions: a spear that widens Lunge's impact; a bow whose
Piercing Arrow leaves a slowing trail; a focus that changes Firebolt's area
pattern. Implement these as controlled skill modifiers. Prevent recursive
on-hit triggers and cap effect frequency where needed.

### Loot rules and player flow

- Generate a base item from the encounter's item-level band, then rarity, valid
  affixes, values, and a stable instance ID. Save the actual result at generation.
  Item level determines roll ranges; it is not a second character level.
- Normal groups give gold and occasional equipment. Elites guarantee at least
  one Magic-or-better item. Regional bosses guarantee a Rare usable by the
  current class plus a separate chance for a Unique.
- Initially bias about 75% of weapon drops toward families supported by the
  chosen class's skills. Universal armor remains broadly useful. Off-class
  drops can be sold or kept for another character through a shared stash later.
- Guaranteed boss rewards and vendor stock provide a usable progression floor.
  A bad random sequence must not block the required campaign route.
- Aim for something worth inspecting every 5–8 minutes and a likely upgrade
  every 10–15 minutes. Measure actual upgrades, not just drop counts.
- Gold and small supplies can auto-collect nearby. Equipment requires deliberate
  pickup. Show rarity labels, comparisons, key build effects, and level gates.
- Use a 40-slot equal-cell inventory, sorting, item locking, junk marking,
  buyback, and a per-character hub stash. Quest items use a separate collection.
  A full inventory leaves drops in the world and gives a clear message.
- Include a basic rarity filter, item tooltips, and an accessible lost-item
  recovery for uncollected boss rewards. Persist ground loot for revisited zones.
- Gold pays for vendor gear and consumables. Defer durability, repair taxes,
  crafting trees, set bonuses, trading, and a shared stash until the basic loop
  is proven. Free respecs make experimentation affordable.

An item's numbers persist across equip/unequip, death, travel, and reload.
Comparison UI must show important tradeoffs rather than reducing every item to
one misleading gear-score arrow.

## 8. Encounters and the final temple climb

### Enemy framework

Build six reusable roles: melee pursuer, shield defender, ranged attacker,
charger, area caster, and support/summoner. Regional variants change a specific
behavior or combination, not only color and health. Budget 10–12 ordinary enemy
definitions, four elite modifiers, three regional bosses, two temple minibosses,
and the summit boss.

AI states include idle, alert, chase, windup, attack, recovery, stagger, and death.
Ranged enemies need firing positions and line of sight; melee enemies need room
to surround the player without overlapping. Use limited local group aggro and
clear encounter boundaries. Leashed enemies reset their health and state, and
resetting must never grant XP or loot.

Teach each major mechanic outside the temple before combining it inside:
projectile lanes, shield flanking, delayed area damage, chargers, interruptible
casters, and protecting an objective from support enemies. Telegraph dangerous
hits through animation, ground markers, and sound.

### Temple structure

Preserve the recognizable five floors plus summit, with different objectives
and visual identity on each floor. Use authored critical paths and modular
optional rooms. Randomize selected side routes, packs, and loot with a persistent
seed. Critical stairs, checkpoints, and boss rooms must always be reachable.

| Area | Target time | Main challenge and completion condition |
|---|---:|---|
| Floor 1 — Gate halls | 12–14 min | Animated guardians and mixed packs; defeat two named sentries to open the stairs |
| Floor 2 — Arsenal | 12–15 min | Shield formations and projectile lanes; complete two encounter objectives and beat the first miniboss |
| Floor 3 — Fountain sanctum | 13–16 min | Casters, support enemies, water hazards; disable three conduits in a compact connected loop |
| Floor 4 — Open terraces | 13–15 min | Exposed sight lines, charging enemies, wind telegraphs; defeat the second miniboss |
| Floor 5 — Crown approach | 13–15 min | Combined mechanics and final elite group; complete a short sequence of combat trials |
| Summit | 12–15 min | Brief setup, multi-phase crowned guardian encounter, short resolution transition |
| **Total** | **75–90 min** | **Final campaign act** |

Players need not hunt down every leftover enemy. Objectives open the route;
optional rooms reward exploration. Temple loot continues the ordinary item
system, and enemies continue awarding ordinary XP. Crossing a stair threshold
never grants stats, healing-based permanent power, or skill points.

### Summit boss

Build a crowned guardian as the mechanical placeholder; identity, motive,
dialogue, crown outcome, and ending remain story decisions.

- First phase: teach broad melee cleave and a clearly telegraphed sweeping beam.
- Second phase: awaken statue groups in the arena corners. Support units move
  toward the boss and can be intercepted before granting healing or a shield.
- Final phase: combine established attacks and alter safe positioning through
  arena hazards. Avoid introducing an unexplained instant-kill mechanic.
- Activate waves once per downward threshold crossing in that attempt. Boss
  healing cannot retrigger an already consumed threshold.
- Beam rotation uses a fixed angular speed, retaining V1's useful correction
  against unfairly fast close-range tracking.
- Melee builds get reliable windows to attack; ranged builds must reposition.
  No phase requires an attack type exclusive to one class.
- Target roughly 8–10 minutes of active boss combat within the summit budget.
  Tune phase transitions and adds before increasing health to fill time.

### Checkpoints, death, and return travel

Save at the entrance and after each completed floor, with mid-floor checkpoints
where traversal would otherwise exceed five minutes. Provide a final preparation
checkpoint before the summit and safe travel back to the hub from cleared floors.
Leaving the temple never resets completed floor objectives.

Death retains XP, allocated points, inventory, gold, and completed objectives.
Respawn at the last checkpoint with refilled resources and flask. Only unfinished
encounters reset; defeated persistent enemies remain defeated. Re-created boss
adds carry the same reward IDs so retries cannot duplicate rewards. Put major
boss rewards on completion rather than farmable preliminary waves.

Initial death cost is lost encounter progress and a short return, with no XP
loss or destroyed equipment. This supports a several-hour campaign. Farmable
areas can be deliberately reset from a waypoint outside combat, creating a new
encounter instance with fresh reward IDs; revisiting or dying is not a reset.
Main objective rewards remain once per character regardless of resets.

## 9. Game architecture and persistence

Use composition: one reusable character controller with stats, health/resource,
equipment, ability, status-effect, animation, and presentation components.
Classes are definitions and ability catalogs, not three unrelated player systems.

| System | Owns |
|---|---|
| Application/session | Boot, menu, character selection, loading, pause, current character |
| Character progression | XP table, level, earned/spent points, rank eligibility, respec validation |
| Stat calculation | Base + allocation + equipped bonuses + skills + temporary effects |
| Combat and abilities | Target validation, cast lifecycle, hit resolution, statuses, death events |
| Equipment and inventory | Item instances, slots, hand occupancy, comparisons, capacity, vendors |
| Loot | Weighted tables, valid affixes, item generation, drop ownership and claim IDs |
| World and encounters | Zone lifecycle, navigation, encounter state, objectives, checkpoint state |
| Quest/narrative | Objective IDs, conditions, reward claims, dialogue text IDs and story flags |
| Save service | Versioning, validation, migration, atomic writes, backups, recovery |
| UI and audio | Presentation of state and player actions; no independent combat rules |

Use `CharacterBody3D` for movement, navigation meshes/agents for routes, physics
queries for ground targeting and line of sight, and explicit hit volumes for
melee/projectiles. Visuals follow gameplay state. Pool projectiles/effects where
profiling justifies it. Keep navigation rebuilds out of routine combat updates.

Definitions use stable IDs such as `skill.warrior.cleave` and `item.spear.bronze`.
A skill definition records unlock/rank rules, scaling tag, damage type, target
mode, range, resource cost, timing, allowed weapons, and audiovisual references.
An item instance stores its ID, base ID, item level, rarity, rolled affixes, and
unique modifier. Do not save a pointer to a scene object as durable identity.

The save includes character/class, XP/level, allocated and unspent points, skill
ranks/hotbar, inventory/equipment/stash, item instances, gold, quests, checkpoints,
zone seeds, completed encounters, remaining ground drops, reward claims, and
campaign completion. Store settings separately. Support multiple character slots.

Save to the OS user-data location, never beside the executable. Use a versioned
schema, temporary-file write and replacement, and at least one known-good backup.
Validate incoming data and retain a pre-migration backup. A failed save must
produce a visible message and retain the last good copy.

Apply loot claims, their resulting inventory changes, and objective rewards as
one coherent state update. Autosave after these updates, level/point changes,
equipment changes, checkpoints, travel, and quit. Coalesce routine writes. Resume
at a safe checkpoint with unfinished fights reset; this is intentionally not an
exact mid-projectile snapshot. Retained rewards and encounter IDs must agree.

Suggested layout once implementation starts:

```text
project.godot
scenes/        boot, menus, actors, regions, temple, UI
scripts/       domain rules, components, AI, services, presentation
data/          classes, skills, items, affixes, enemies, loot, zones, quests
assets/        exported models, textures, animation, audio, fonts
source_art/    editable sources excluded from runtime import/export
tests/         progression, combat, loot, saves, content validation
tools/         build scripts, data reports, developer scenarios
docs/          design, balance decisions, asset provenance, release checklist
```

Keep tunable values in definitions and balance tables. Gameplay emits domain
events such as enemy defeated or objective completed; UI and story react to them.
Story writing should populate hooks and conditions without rewriting XP, combat,
or save code. Do not build a general-purpose quest scripting language initially.

## 10. Implementation milestones

Each milestone ends with playable Windows and Mac artifacts. These are dependency
gates, not calendar estimates; estimate production after measuring the slice and
one finished region's art/encounter throughput.

| Milestone | Deliverable | Exit condition |
|---|---|---|
| 0. Technical spike | Graybox 3D room, rigged character, camera, movement, navigation, one attack, renderer comparison, desktop packaging | Real Windows and Mac builds launch and run the representative stress room; asset pipeline and renderer chosen |
| 1. Combat foundation | Shared actor components, basic attack, evade, flask, projectiles, three enemy roles, telegraphs | Melee, ranged, and spell attacks feel readable and responsive; collision and hit timing work |
| 2. Progression and loot | XP, shared stats, point spending, equipment, affixes, inventory, checkpoint saves | A kill can produce XP and an item; equipping and ranking a skill affect combat correctly and survive restart |
| 3. Playable slice | One 20–30 minute area, small hub, boss, all three class prototypes, two actives and one passive each | Complete loop works for every class on both platforms; players understand movement, loot, skill points, and recovery |
| 4. Campaign alpha | Opening, three required regions, regional bosses, complete class rosters, temple entrance | Required route independently delivers 150–180 minutes for first-time testers without mandatory side content or grinding |
| 5. Temple alpha | All five floors, two minibosses, summit, story hooks | Every class can complete the campaign; no progression reset at temple entry and no floor stat grants |
| 6. Content and balance beta | Full loot catalog, armor visuals, audio, authored story integration, difficulty tuning, accessibility | Useful drops, several viable builds per class, stable saves, and measured pacing/performance targets |
| 7. Release candidate | Signed/notarized Mac package, Windows package, settings, credits, licenses, recovery testing | Fresh downloaded installs pass platform and full-campaign checks; debug rewards/cheats disabled |

For milestone 3, use roughly 12 base items, eight affixes, and one example Unique
per class. Prototype only enough art to prove modular equipment and combat
readability. Do not produce the full loot catalog before the item pipeline works.

Prototype the summit's cleave/beam/add mechanics in the combat test room during
milestones 1–3. This exposes camera and class fairness problems early even though
the finished temple arrives in milestone 5.

Art pipeline gates: one modular room kit, one rig with all three attack styles,
two interchangeable armor styles, and stable import/export before mass production.
Build the region and temple kits from shared proportions, doors, stairs, and
collision conventions. Decorative complexity comes after traversal works.

## 11. Validation and principal risks

Automated checks should cover rules where a regression damages a character or
invalidates combat. Test meaningful invariants rather than screenshotting every
minor interface change.

- **Progression:** XP boundaries and multi-level awards; point conservation;
  identical shared formulas across classes; floor transitions and pickups cannot
  mutate permanent attributes; respecs cannot create points.
- **Combat:** scaling tags apply once; mitigation caps work; evade respects walls;
  damage/death events resolve once; crowd control cannot lock bosses forever.
- **Items:** slot legality, two-handed occupancy, valid affix pools, stable rolls,
  no stat accumulation from equip cycling, and no loss when inventory is full.
- **Persistence:** round trips, migration, failed writes, backup recovery, claimed
  quest/boss rewards, death/reload loops, and consistent drops across travel.
- **Content:** referenced IDs exist, required paths/checkpoints are reachable,
  skill effects have valid ranks, and every class has valid guaranteed rewards.

Playtests must separately cover camera occlusion, click targeting, visual
telegraphs, animation feel, boss fairness, and downloaded desktop builds. Headless
tests cannot establish these qualities.

Collect local development measurements: first temple-entry time, completion time,
level by checkpoint, deaths, skill choices, inspected/equipped drops, time in menus,
and combat time by encounter. Do not require an online telemetry service.

For the first timing pass, recruit at least six fresh players, two per class,
then expand after obvious pacing problems are fixed. Target a 150–180 minute
pre-temple median and inspect fast first-play routes below 120 minutes. Compare
main-route runs separately from completionist runs. If time is short, add distinct
encounters, routes, and objectives; repeated clearing or inflated enemy health
does not count as adequate content.

| Main risk | Response and decision point |
|---|---|
| 3D equipment and animation dominate production | Shared rig, modular armor, limited silhouettes; prove two outfits and all attack styles in the slice |
| Three classes multiply balance work | Shared calculations; representative builds in every boss test; usable guaranteed loot |
| Promised hours become repetitive | Measure the required route by region; vary encounter goals and enemy combinations |
| Desktop export works only on the developer's machine | Export immediately, test real target hardware, trial signed Mac distribution early |
| Loot and saves duplicate or lose rewards | Stable item/encounter IDs, coherent state updates, backup saves, retry tests |
| Excessively broad feature scope | Finish the single-player campaign loop before crafting, pets, multiplayer, or endgame systems |
| Story changes invalidate world structure | Stable objective hooks; provisional names; postpone dialogue, ending cinematics, and story-specific art |

Tune Normal first. Proposed launch modes are Story, Normal, and Veteran with
separate enemy health/damage/behavior settings; avoid using tougher modes to
justify the content duration. Difficulty may be changed at a safe checkpoint
without resetting the character. Exact modifiers come from beta playtests.

## 12. Decisions intentionally left open

The story's opening motivation, regional identities, reason for entering the
temple, crowned guardian's identity, and ending belong to the author. The design
above supplies places for these decisions without prescribing their answers.

Before production art, settle the visual target and exact supported hardware.
Before expanding beyond the slice, review camera/control feel, the five proposed
attributes, point allocation, skill loadout size, and free respecs. These are
recommended defaults, not additional requirements attributed to the user.

**First implementation task:** milestone 0's graybox prototype, followed by the
20–30 minute slice. The first proof of the game is moving, fighting, finding an
upgrade, gaining a level, spending points, and resuming that character in exported
Windows and Mac builds.
