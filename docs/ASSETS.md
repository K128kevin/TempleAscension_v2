# Asset provenance and generation

No visible game object is built from Godot primitive meshes, CSG, surface tools,
or scripted Blender primitives. `tools/prepare_models.py` imports and normalizes
existing meshes. `scripts/layout.gd` adapts the original room-and-corridor generator;
`scripts/temple.gd` places those authored modules on its tile layout and constructs
only navigation/collision data. From the second floor up, the stairwell the hero climbed from the floor below opens in
the entrance room (or the nearest room with space): the same stairs mesh descends a full
storey into an opening in the floor, its top step level with the room, its deep end
against a wall. Plain stone blocks (the paving slab mesh) line it flush with the flight,
and a flat quartz coping frames the opening; its cells are solid. The first floor has
no stairwell. Each floor's ascent reuses the imported stairs mesh,
scaled to a two-tile-wide flight four tiles deep and exactly wall height. It stands
against a solid wall of the farthest suitable room, so its top step meets the top
of that wall; its footprint is solid and the ascent point is the floor at its foot. Runtime generation places imported meshes and
does not construct mesh geometry. The third-floor court assembles three decreasing
stone bowls from the imported chalice, with a low column base in the original
fountain obstacle footprint. Paving meshes provide the pool floor and low rim;
the water shader uses thin instances of the same mesh. Spill particles reuse the
imported gem mesh. The generated seal is a transparent VFX sprite,
not a replacement for a 3D environment object.

Floor paving keeps the imported tile mesh with `assets/shaders/quartz_floor.gdshader`:
pale, polished milky quartz slabs with soft clouding, faint veins, tiny flecks and thin
grout on each one-metre tile. The mesh's small carved cobbles are shaded flat. The
light floor contrasts with the dark stone statues; floor 3's court uses a faint rose
tint. It is procedural and adds no image asset.

Torch fixtures retain the imported brazier and torch meshes. The static authored
flame is masked out in `assets/shaders/torch.gdshader` and replaced by a living
particle flame (`scripts/torch_flame.gd`): a small volume of soft glowing particles,
so it has depth from every angle. Tongues rise from a white-hot core, stretch, and
cool through orange to red as they fade, with the odd ember drifting up. A
per-torch noise field drives random flicker and occasional gusts that gutter the
flame; the same field sways the flame and shifts the light's brightness (within 14%),
warmth and position, so the light shimmers with the flame. The light sits just
above the torch cup. Particles stop simulating while a torch is out of sight. No
image asset or mesh geometry is added. Light range and the nearby-shadow budget
are preserved.
Hallways are five tiles wide and rooms 8–15 tiles across. Torches are spaced
along the walls, then added wherever the estimated floor light (the omni falloff
and floor incidence of every torch) would fall below a dim but readable level.
Every torch is mounted on a wall, its fixture turned so the back plate lies flat
against it; there are no freestanding torches. Room centers beyond a wall torch's
reach rely on a raised ambient fill (0.24), enough to keep the middle of large rooms
readable. Torches beyond line of sight are switched off, keeping about a dozen lights
active in any view. The torch shader hides the fixture's authored flame, both its
orange tongues and its pale core, so only the particle flame shows.

Warrior, Ranger and Wizard share the imported hero rig and armor. Starting
equipment distinguishes them: a larger sword (`assets/shaders/sword.gdshader`: brass pommel and cross guard, a
dark brown leather grip, and a silver blade with a fuller down both flat faces) with
a round grey steel shield, a bow,
or a staff. The shield is the original round shield mesh at 0.66m, strapped flat to
the outside of the left forearm through every hero clip, including runs, strikes,
the roll and hit reactions; the SwordIdle stance (the library idle with the left
forearm turned 60° outward) turns it out to the side. The hero also wears brown
leather boots (the KayKit Rogue's leg pieces trimmed to the boot, close-fitted over
the lower legs) and a steel full helm matching the shield: the KayKit knight helm
sized to the head and lowered over the jaw, its open face closed by mirroring its
back half forward, whose eye-level seam becomes the visor slit. The
helm hides the hair. `tools/outfit_hero.py` adds both after the enemy outfits are
built; statues never inherit them. `assets/textures/wood_planks.png` (cut from the
Quaternius furniture trim sheet by `tools/paint_hero.py`) remains available as a
wood material. Hit reactions for anyone holding a shield (ShieldHit, ShieldHitHead, ShieldHitStagger,
ShieldHitKnockdown) keep that 60° forearm turn, so a hit does not flip the shield.
SwordRun is the sprint with both arms eased toward that carry, so the sword
stays low and never swings through the head. Staff attacks reuse the Cast
animation. Class projectiles reuse the arrow and gem meshes; traps, defensive
effects and area warnings reuse the transparent seal sprite with distinct colors
and timing. This update adds no externally sourced or generated image assets.

`scripts/visual.gd` scales imported clips to each attack's duration and restarts
every attack at its wind-up. `scripts/actor.gd` advances animation manually on the
combat clock, so held attacks finish their recovery before the next swing.
Damage and projectile jobs follow the same clock. Enemy hit delays pause the
pose and telegraph together; culled actors retain elapsed animation time.

The Crowned Statue (`guardian_boss.glb`) is armored after a Roman general's statue the
user shared: the knight's cuirass close-fitted over the chest, the shoulder guards of
the knight's arm plates (bare forearms), the barbarian's studded belt with its tabs
lengthened into pteruges to mid-thigh, the knight's cape down its back, and bare legs.
Its face and hair follow the statue too: the base character pack's `Hair_Beard`,
brought out over the jaw, and the statue's short hair worked into tight curls with a
noise along the scalp. The crown sits on its head. It wields a great sword (the hero's sword in statue stone, 1.35 times
as large before its double stature) and fights with the sword swing; statues carry a
shield only if they are shield bearers. The Crowned Statue's gaze (`scripts/boss_laser.gd`) is drawn like Temple Ascension v1's
laser: a red lightning beam in three passes (a faint broad glow, a red band and a bright
core) along a path whose sideways jitter re-rolls every 55 ms. A beam leaves each of the
boss's eyes; the two converge on the aim point, sloping from the eyes through the
hero's chest height, and run on until they strike the floor or a wall. Red lights glow
at the eyes and the point of impact. As in v1, the beam sweeps toward the hero at a
steady 30 degrees a second for five seconds. The beams are camera-facing ribbons
built each frame; no image asset or solid geometry is added.

The Oracle carries a slender staff crowned with a round, pointed diamond, after a
reference staff the user shared: `tools/prepare_staff.py` reshapes the Kenney Mini
Dungeon spear's own vertices (shaft drawn out, collar kept, head enlarged and rounded)
into `assets/models/props/oracle_staff.glb`, in statue stone. Its cast, OracleCast,
holds the staff at its side while the left hand weaves slow circles and a small flame
(particles and a warm light) grows in the crown; then the staff is drawn back and
swung out in front, and the fireball leaves the crown at the release. The staff's
lean through the cast is set in `scripts/visual.gd`; the frost nova goes straight
to the swing. The player Wizard's staff is unchanged.

The Oracle's fire spell is a fireball shot in a straight line (`scripts/fireball.gd`). A camera-facing
card drawn by `assets/shaders/fireball.gdshader` renders procedural, flowing fire; an
ember trail and a travelling light follow it. On impact it swells into an explosion
that cools from white-hot through orange and red into smoke, with sparks, a light
flash, a ground shockwave from the existing seal VFX and a fading scorch mark. Damage
lands on impact. The Oracle casts it for two seconds, shown by an amber cast bar over
its head; no ground marking shows where it will land. It adds no
image asset or mesh geometry.

The Oracle's frost nova (`scripts/frost_nova.gd`) replaces its ice bolt. It is
instant, cast when the hero comes within 3.8m (twice a sword's reach) at most once
every 15 seconds, and deals the old bolt's frost damage and five-second slow to the
hero anywhere in that radius. A cold flash and a frost shockwave race outward; ice
shards streak out along the ground, a ring of ice spikes erupts as the wave passes and
then sinks, and frost mist and glints roll out over a pale frost patch. Shards and
spikes reuse the imported gem mesh with a translucent ice material; the rest is
particles, sprites and light, with shared helpers in `scripts/vfx.gd`.

Enemy hover feedback uses a flat red sprite with a procedural radial gradient
from `scripts/assets.gd`, plus a 72×8 HUD health bar projected above the head.
The ring scales with the enemy's stature. Both indicators ignore mouse input.
This UI effect adds no external bitmap or solid geometry.

## The outdoor world

`scripts/overworld.gd` and its three builders (`world_desert.gd`, `world_town.gd`,
`world_temple_front.gd`) place imported meshes only, as the temple does; collision,
paths and the ground's control map are data, not geometry. Its look is meant to be
gritty and down to earth: photographed sand, scanned rock and shrubs, weathered
masonry. (A first version used the stylized kits' flat-coloured palms, rocks and
bushes; they were replaced.)

- **Ground.** One slab (the KayKit paving mesh, as under the temple's terraces) carries
  `assets/shaders/desert_ground.gdshader`. Its sand is two Poly Haven photographs
  (CC0): [Dense Sand](https://polyhaven.com/a/dense_sand) where it lies deep and
  [Gravelly Sand](https://polyhaven.com/a/gravelly_sand) in patches, along the track,
  in the arena and at the foot of rocks (`assets/textures/sand_fine.jpg`,
  `sand_gravel.jpg` and their normal maps, 1024 px). The fine sand is laid twice,
  turned against itself and mixed in patches, and tinted by a much larger laying of
  itself, so it never reads as a grid. Dune relief and wind ripples are shading only
  (the ground is flat to walk on). Where the control map marks paving the existing
  `limestone.png` flags show, dirtied by the sand photograph with sand drifted into
  them; the map also marks the track, the oasis pool, and shade at the foot of walls
  and rocks. The control map is a one-texel-per-metre image painted by the builders at
  load; the shader's noise is read from a small tiling noise texture generated at load.
- **Rocks.** Poly Haven photo scans (CC0), cut down and normalised by
  `tools/prepare_scans.py`: boulders [03](https://polyhaven.com/a/namaqualand_boulder_03),
  [04](https://polyhaven.com/a/namaqualand_boulder_04),
  [05](https://polyhaven.com/a/namaqualand_boulder_05) and
  [06](https://polyhaven.com/a/namaqualand_boulder_06) (`boulder_a`–`boulder_d`, about
  2,000 triangles each), a twenty-metre run of
  [cliff](https://polyhaven.com/a/namaqualand_cliff_02) (`crag`, 7,000 triangles) and
  three loose [stones](https://polyhaven.com/a/namaqualand_stones_01) (`stone_a`–`stone_c`).
  Each scan is welded, cut in two passes with the surface relaxed after each (one hard
  cut leaves folds that throw hard little shadows), and exported bare; its colour and
  normal maps are `assets/textures/scan_*_diff.jpg` and `scan_*_nor_gl.jpg` (512 px;
  the cliff 1024). `assets/shaders/desert_rock.gdshaderinc` adds rock grain at one
  size in the world (`assets/textures/rock_detail.jpg`, from Poly Haven's
  [Rock Face 03](https://polyhaven.com/a/rock_face_03)), level beds of slightly
  different stone, and sand lying on ledges and piled at the foot. About 1,400 of them
  make the rim, drawn in batches: cliff faces along the far walls, boulders rising
  away from the camera on the near ones.
- **Buildings, arena, town wall and temple front.** KayKit Dungeon Remastered wall
  modules: `wall`, `wall_arched`, `wall_window` (closed shutters), `wall_archwindow`,
  `wall_door`, `arch`, `wall_broken`, `wall_half`, `pillar`, `pillar_decorated`,
  `stairs` (the arena's seating), `floor` (roofs, terraces and the walls of the arena's
  gateways), and the Kenney Mini Dungeon `column`. `assets/shaders/masonry.gdshaderinc`
  repaints them: the kit's grey stone becomes the existing `limestone.png`, projected
  at one size in the world and tinted per building (limewash, cream, ochre, rose),
  while its orange timber (doors, shutters) is repainted blue, teal, brown or rust.
  It then weathers them with the rock grain photograph: pitting, broad stains, patches
  where limewash has gone, streaks run down from the top, dust and splashed sand a
  metre up from the ground and thick on ledges and roofs, and flaking paint. A twin
  shader draws the same masonry see-through for whatever hides the hero.
- **Upkeep.** The masonry shader takes a `wear` from 0 to 1. The arena and the palace
  are built at .06: clean dressed stone with a little dust at the foot. Houses run from
  .3 to 1: heavier pitting and stains, streaks, limewash gone in sheets (down to dark
  mud brick on the worst), cracks traced from the grain photograph's own contours,
  dirt climbing two metres up the wall, and flaking woodwork. The worst houses also
  use the kit's `wall_broken` module, and three are roofless shells with rubble inside.
  Doors and shutters everywhere are one of six browns.
- **Statues and sculpture.** `Overworld.statue` stands one of the temple's figures
  still, at any size, in the temple's own statue shader: `figure_scale` enlarges the
  stone's grain, wear and cracks with the figure, so a colossus is the same carving
  grown, and `pale` renders it as white marble rather than dark stone. The temple's
  two guardians are the centurion (its stone, armor relief and all) at three times
  life size, both facing west. Every statue of the town is the lion below, in
  marble: four in the Elders' Box, two at the palace gate, two on the road and two
  great ones at the palace steps.
- **The lion.** `tools/make_lion.py` builds `assets/models/character/lion.glb`, used
  for the temple's Lion Guardian and the town's marble lions. Its body is
  ["Lion" by Poly by Google](https://poly.pizza/m/3XAJojWxSWz) (**CC-BY 3.0**, via
  Poly Pizza; attribution required, see `assets/licenses/PolyByGoogle-Lion-CC-BY.txt`),
  a low-poly standing lion: sized to a real lion, smoothed, its stick legs filled
  out, haunches and shoulders raised, its mane carved into locks and its paws into
  toes. Its face is Poly Haven's sculpted [Lion Head](https://polyhaven.com/a/lion_head)
  (CC0), a mask of a lion's face and the mane round it, set in place of the body's
  own plain head; the mask's normal map (`assets/textures/lion_head_normal.jpg`)
  carries the finest work, read by the statue shader through the mask's UVs
  (vertex colour blue 0 marks the mask). The whole is about 16,000 triangles. The
  model had no skeleton: the script builds one (24 bones: spine, neck, head, four
  two-jointed legs with paws, a four-bone tail), skins the mesh to it, and keys six
  clips frame by frame, the legs by two-bone IK: Idle (breathing, the head turning,
  the tail swaying), Run (a rotary gallop), Attack (it rears and rakes its right
  forepaw forward and across; the blow lands 63% of the way through), Hit, HitHead
  and HitStagger. `scripts/visual.gd` treats it as a quadruped: no foot planter,
  hand grips, shield arm or equipment.
- **Gold and marble.** Gold is the rock grain photograph tinted to gold with a little
  metal and its own faint glow (the outdoor scene has no sky to reflect); marble is
  `statue_marble.png` at world scale (plinths, kerbs, columns). Thrones are the props kit's `chair`, gilded;
  rails, cornices, column heads and feet are the paving mesh, gilded.
- **The palace hill.** The world's ground is one flat slab; the hill is
  `assets/models/props/hill.glb`, a two-metre grid raised to the hill's height by
  `tools/make_hill.py` (like the palms, built for this game rather than taken from a
  kit) and drawn with the slab's own ground shader, which tilts its shading with the
  slope. `Overworld.height_at` reports the same height, from the same numbers, and
  the test suite compares the two. Everything is still walked on one plane: what
  stands on the hill, the hero's figure and the camera are raised to its height.
- **Litter.** `urn_broken` (the props kit's `Vase_Rubble_Medium`) and the existing
  `rubble`, in each house's own masonry.
- **Town and camp dressing.** Quaternius Fantasy Props MegaKit: `barrel`, `barrel_rack`,
  `crate`, `farm_crate`, `stall`, `cart`, `bench`, `table`, `stool`, `urn`, `bag`,
  `bucket`, `cloth_red`, `cloth_blue`, `weapon_stand`, `dummy`, `anvil`, `lantern`.
  They are exported without the kit's trim sheets; the game gives each surface a
  shared material by its name, from one 1024-pixel copy of each sheet
  (`assets/textures/trim_furniture.png`, `trim_metal.png`). Cloth and pottery, which
  the kit colours through a second texture layer, are a dye or clay colour broken up
  by the rock grain photograph.
- **Palms.** No kit offered a palm that was not a toy, so the date palms are modelled
  for this game by `tools/make_palm.py` (the one exception to using only authored
  meshes): a ringed, leaning trunk that swells at its foot and under its crown, and
  thirty arching feather fronds in tiers, the oldest hanging dry against the trunk,
  about 1,100 triangles a tree in three variants. The bark is Poly Haven's
  [Palm Bark](https://polyhaven.com/a/palm_bark) photograph (CC0;
  `assets/textures/palm_bark.jpg` and its normal map); the fronds
  (`palm_frond.png`, `palm_frond_dry.png`) are painted leaflet by leaflet by
  `tools/paint_flora.py`.
- **Shrubs.** Poly Haven scans (CC0): [Shrub 02](https://polyhaven.com/a/shrub_02)
  (`shrub_a`, `shrub_b`) and the [Wild Rooibos Bush](https://polyhaven.com/a/wild_rooibos_bush)
  (`scrub`), with their colour and alpha maps combined into
  `assets/textures/scan_shrub_02.png` and `scan_wild_rooibos_bush.png`.
- **Other plants and stones.** Stylized Nature MegaKit: `dead_tree`, `olive_a`, `olive_b`
  (the twisted tree; `tools/paint_flora.py` repaints its leaf cards with clusters of
  narrow grey-green olive leaves, inside the kit texture's own shapes, as
  `assets/textures/olive_leaves.png`), `dry_grass`, `agave`
  (`assets/textures/desert_leaves.png`, darkened), `pavers_a`, `pavers_c`. These are
  exported bare and share one copy of each texture.
- **The well.** A CC0 model by Quaternius from [Poly Pizza](https://poly.pizza/m/QlqncKYxXb)
  (`source_art/poly_pizza/`). It comes in flat colours; the game gives its stone, roof
  tiles and bag the rock grain photograph and its timber the existing plank texture.
- **Fire.** Bowls outdoors reuse the `fire_bowl` mesh and the torches' particle flame;
  in daylight their light is kept off every surface.

The Poly Haven downloads are in `source_art/polyhaven/`. This renderer does not
convert texture colours to linear light, so the shaders' tints are tuned by eye
against the photographs' own brightness.

The kit models are normalised by `tools/prepare_models.py` (`--only` now takes a
comma-separated list). The first floor's door, seen from inside, is the existing open
`arch` at the end of a short passage, with an unshaded sand-coloured slab (the paving
mesh) beyond it as the daylight outside.

## Requested local assets

Source directory: `/Users/ktabb/Documents/3dAssets/` (read only).

- Quaternius Universal Base Characters [Standard]: `Superhero_Male_FullBody.gltf`
  and `Hair_SimpleParted.gltf`. Used for the hero, every humanoid statue, crowned
  boss, offerings, and ending elders.
- Quaternius Universal Animation Library [Standard]: `UAL1_Standard.glb`.
  Sword Idle, Sprint, Sword Attack, Roll, Death01, Spell Simple Shoot, Punch Cross,
  Crouch Forward, Hit Chest and Hit Head drive eleven gameplay slots (Cleave also
  uses Sword Attack). All are retargeted and baked to the supplied base character skeleton.
- Quaternius Universal Animation Library 2 [Standard]: `UAL2_Standard.glb`.
  `Sword_Regular_A` plus its recovery supplies SwordSwing; `Sword_Regular_B`
  plus its recovery supplies SwordSlash. `Sword_Regular_C` supplies AxeWhirl
  and its overhead strike supplies AxeChop. Wind-up, cutting motion and recovery
  are retimed separately for readable swings, then baked onto the character.
  `Hit_Knockback` followed by `LayToIdle` supplies HitKnockdown; its opening
  crumple, blended back to the idle stance, supplies HitStagger.
- Hit reactions: light hits alternate Hit (chest) and HitHead flinches on the
  hero and every statue. Hits of at least 20% of the hero's maximum health play
  HitStagger. Shield Bash knocks statues down for the stagger's duration; the
  boss's short stagger uses HitStagger. Reactions never interrupt wind-ups,
  attack recoveries, skills, evades, the boss's gaze or death, and locomotion
  resumes when they finish.
- Neither supplied animation library includes archery or spear thrust clips
  (the Standard editions of both were searched, including their FBX and
  root-motion variants).
  `tools/import_combat.py` authors and bakes BowIdle, BowShot, BowRapid, BowRun, BowCrouch,
  SpearIdle, SpearStab and SpearJab on the supplied skeleton. These animate
  existing bones and meshes; no replacement geometry is generated.
- Quaternius Stylized Nature MegaKit [Standard]: rocks, dead tree, grass, fern and
  pebble geometry. The pebble is reused with jewel materials for gem drops.

The character export is `assets/models/character/warrior.glb`. Character and
animation licenses sit beside it. Rebuild with Blender:

```sh
.tools/Blender.app/Contents/MacOS/Blender --background --python tools/import_character.py
.tools/Blender.app/Contents/MacOS/Blender --background --python tools/import_combat.py
.tools/Blender.app/Contents/MacOS/Blender --background --python tools/prepare_guardian.py
```

## Additional authored geometry (CC0)

- [Kenney Mini Dungeon](https://kenney.nl/assets/mini-dungeon): column and spear.
- [KayKit Dungeon Remastered](https://github.com/KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0):
  paving, walls, open doorway, stairs, rubble, lit torch and altar/table mesh. The doorway's
  separate door leaf is omitted to make a permanently open portal.
- [KayKit Adventurers](https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0):
  axe, arrow and staff, plus authored Barbarian/Rogue light armor,
  Knight plate armor/full helmet, and Mage robe/cape geometry.
- [Quaternius Fantasy Props MegaKit](https://opengameart.org/content/fantasy-props-megakit):
  sword, shield, vase, torch, banner, bookcase, books and chalice.
- [Crown by Quaternius](https://poly.pizza/m/i0PZVuVlYv), CC0.
- [Bow by CreativeTrio](https://poly.pizza/m/H6vbuPvWtg), CC0.

Pack licenses are retained in `assets/licenses/`. Normalized individual exports
are under `assets/models/props/`. Original downloads are under `source_art/` on
this workstation and excluded from native exports. Prop normalization preserves mesh topology; it recenters bounds, corrects orientation, and repacks textures.
`tools/prepare_guardian.py` makes a crowd variant of the supplied character: it
merges the stone surfaces and reduces the mesh to about 5,450 export vertices,
while retaining the skeleton and all thirty clips. The full hero remains unchanged.

`tools/prepare_enemy_outfits.py` fits the KayKit clothing meshes to that existing
Quaternius skeleton, remaps their skin weights, and joins each outfit into one
crowd surface. It exports `guardian_gladiator.glb`, `guardian_archer.glb`,
`guardian_centurion.glb`, `guardian_wizard.glb` and `guardian_boss.glb`, each retaining all 30 clips.
Every outfit piece is then close-fitted over its wearer: shrink-wrapped onto its
own region of the statue (torso, each arm, each leg) at a garment's thickness, with
part of its authored shape kept so belts, cuffs, plate edges and pauldrons still
read, and skinned to the flesh beneath it. Leather (archer sleeves, trousers and
boots; robe sleeves) sits at about 2cm, plate at 3–4.5cm. The oracle's robe fits over
the chest and sleeves while its lengthened skirt stays loose with its own weights,
so it still swings. No unit keeps the KayKit pieces' toy-proportioned tubes.
The gladiator is a murmillo: the bare statue torso wears the barbarian's studded
belt and fringe (trimmed below the chest) and the knight's plated right arm, with
bare legs, and the knight helm reshaped from its own vertices, sized to the statue's
head, with the ridge spikes raised into a crest and the rim flared into a brim. Its
visor shows the statue's face. Its body keeps the statue's own shape. It carries a
sword the size of the hero's, in statue stone, and a tall curved scutum (KayKit Adventurers
`shield_square`, normalized as `assets/models/props/scutum.glb`), held upright in
front of the left forearm. ScutumSwordIdle holds the sword low beside the shield, and
ScutumRun (shared with the centurion) keeps the sprint's legs while reaching the
shield arm to its stance position, so the shield stays upright; it attacks with the
sword swing. The supplied mage tunic is extended into an ankle-length robe; covered leg
surfaces are omitted to avoid running knees piercing the garment. The helmet
covers the centurion's whole head. The centurion is a heavy legionary: its body takes a broad,
thickset build at full height (the gladiator's reshaping without leg shortening),
and the knight's plate is close-fitted over it. Each piece is shrink-wrapped onto its
own region of the statue (torso, each arm, each leg) at a plate's thickness, keeps
35% of its authored shape so plate edges, belt and pauldrons still read, and takes
the skin weights of the flesh beneath it so it moves with the limb. The helm is
sized to the statue's head. It carries a tall tower shield (the scutum mesh at
1.3m) upright from shin to chin. Its attack (ShieldStab) coils deeply, the right
side and spear rotating well back (about 32°) as the left shoulder and shield swing
forward; then it
takes a long step with the left foot as the hips drive forward and the torso turns
the other way, the right shoulder driving the spear forward while the left side and
shield arm pull back. The right foot stays planted by leg IK. Rebuild with:

```sh
.tools/Blender.app/Contents/MacOS/Blender --background --python tools/prepare_enemy_outfits.py
.tools/Blender.app/Contents/MacOS/Blender --background --python tools/outfit_hero.py
```

Bodies, armor, robes, weapons, shields, arrows and the boss's crown share
`assets/shaders/statue_stone.gdshader`. It samples the existing cracked marble
texture in grayscale with dark gray shading, procedural grain, worn patches and
small pits. Surface bumps affect lighting, with high roughness and low specular
reflection. Grain size stays consistent on scaled equipment. Original colored/metallic equipment materials are overridden
for enemies. This update adds no generated bitmap or primitive geometry.

`tools/prepare_bow_draw.py` adds a draw morph to the existing bowstring vertices.
Run it after normalizing the bow with `tools/prepare_models.py`. At runtime the
bow follows the left palm's position and rotation. Dedicated running and crouching
clips carry it beside the body, tilting it clear of the ground when crouched.
The draw wrist and elbow remain on the right side of the torso and neck, with
a 36cm pull and a matching upward string morph. The string follows the baked
hand position until release; the imported arrow follows the draw/release cycles.
Statue archers, and the Ranger's basic bow attack, shoot with ArcherShot, modeled on Quaternius's Bow_Notch followed by
Bow_Shoot. Those clips are in the paid Source edition of Universal Animation Library
2, not the Standard one used here; they were studied in the online viewer and this
clip was authored with the same IK tools, not copied. From a relaxed stance the draw
hand reaches over the right shoulder to the quiver, brings the arrow down to nock it
at the bow in front of the chest as the body turns side-on, then the bow arm extends
at shoulder height, the string is drawn to the cheek, held, and released at 0.78, the
draw hand flicking back. The whole body takes part: the archer steps into a staggered
stance (left foot forward, right back) with soft knees, the hips carry half of the
side-on turn, the weight rises on the quiver reach, settles onto the rear leg through
the draw and rocks forward on the release; leg IK keeps the feet planted. The arrow shows from the nock to the release, and the
string follows the hand. The archer winds up for 1.2 seconds; its interval is
shortened to keep 2.42 seconds between shots. Both character exports retain
all eight weapon attack clips, including the statue archer's bow shot.

## Generated images

All eight images were created with the built-in imagegen tool.
They are saved inside the project; no game resource references the generator's
external output folder. The icon reuses the generated seal.

1. `assets/textures/limestone.png`
   Prompt: "Seamless warm ivory limestone block wall texture for a Mediterranean
   temple, weathered chisel marks, fine fossil grain, subtle golden age patina,
   realistic stone, large staggered ashlar masonry blocks, restrained cracks,
   muted warm pale sand palette. Perfectly flat orthographic surface with uniform
   diffuse illumination, no perspective, objects, cast shadows or text. Tileable
   on all four edges. Applied to real 3D architectural meshes."
2. `assets/textures/bronze_scales.png`
   Prompt: "Seamless ancient dark bronze scale armor: small overlapping forged
   bronze scales, worn golden edges, oxblood dark red leather glimpsed between
   scales, Mediterranean warrior craftsmanship, realistic brushed metal grain,
   rich brown and bronze, evenly lit flat orthographic material scan, no
   directional light, perspective, objects or text. Fine scales cover the image."
3. `assets/textures/statue_marble.png`
   Prompt: "Seamless base color skin texture for animated marble temple statues.
   Cool pale gray weathered marble, subtle thin dark cracks, faint teal mineral
   patina, delicate veins and micrograin. No masonry seams, objects, faces, text
   or perspective. Even flat illumination, tileable on all edges. Classical
   carved stone surface with enough contrast to read on a statue."
4. `assets/textures/seal.png`
   Prompt: "Transparent game VFX texture projected on the ground. A single
   luminous white-gold ancient circular magical warning seal, top-down, thin
   broken concentric rings with tiny antique Mediterranean rune-like marks,
   luminous dust and delicate radial wisps, hollow transparent center and
   background. No text or letters. White linework tintable for danger, healing
   and exit markers."
5. `assets/textures/hero_skin.png` (retained; the hero now wears `hero_kit.png`, below)
   Edited from the base character's `T_Superhero_Male_Dark.png`, after inspecting it.
   Prompt: "This is a UV texture atlas, not a picture of a character. Preserve
   canvas dimensions, UV island locations, silhouettes, face, hands, feet, torso,
   arms and legs. Keep face, ears and hands as natural warm human skin. Paint
   bronze scale cuirass with ornate gold borders directly over the torso UV
   islands; oxblood cloth on hips, leather bracers, bronze greaves and sandals.
   Preserve island boundaries and seam alignment. Flat albedo, no cast shadows
   or perspective. Game-ready armor skin retaining face identity."

6. `assets/textures/desert_night.png`
   Earlier dune-only terrace image, retained as source artwork. The active
   background is now image 8 below.

   Final prompt:
   > Use case: stylized-concept. Asset type: square high-resolution background terrain image for a 3D ancient temple game. Primary request: a vast empty desert at night, seen far below a high temple terrace. Composition: true straight-down aerial orthographic view of sweeping natural sand dunes, filling every edge, no horizon and no sky. Broad softly curving dune crests and a few subtle wind ripples; dunes large enough to read from a distance. Style: polished atmospheric game environment matte painting with believable sand, restrained detail, compatible with weathered classical stone architecture. Lighting: dark moonlit night, muted indigo and slate-blue shadows with subdued silver-blue light brushing the dune ridges; low contrast and dark overall so warm torchlit gameplay above remains the focus, but clearly legible as sand dunes. Constraints: terrain only, no temple, buildings, terrace, people, vegetation, water, stars, moon disk, text, border or watermark. Output 2048x2048 or larger square image.

7. `assets/textures/desert_moonlit_ruins.png`
   Earlier fourth- and fifth-floor backdrop, generated with the built-in imagegen
   tool using the user's `background_inspo.png` as a visual reference. It includes
   distant classical ruins, mountains, a winding river and a dim moon. Runtime
   tint keeps it subdued. The background is visible only when the player occupies
   a terrace tile; it disappears immediately on reentering the temple. A weak
   directional light illuminates only the terrace surfaces on a dedicated layer.
   The matte preserves its aspect ratio and frames the horizon near the top,
   with gentle parallax and overscan at all supported zooms.

   Final prompt:
   > Use case: stylized-concept. Asset type: landscape background matte for an ancient temple game, viewed from an elevated outdoor terrace. Input image: reference for the landscape, architectural motifs and composition, not an edit target. Generate a new wide 3:2 landscape inspired by this reference: an expansive desert valley far below, scattered ancient classical temple ruins and worn colonnades on rocky outcrops, rolling dunes, distant rugged mountains, a winding river catching moonlight, sparse dark vegetation, a full moon and scattered clouds in a starry night sky. Keep the elevated panorama and convincing sense of great distance. Make the entire scene substantially darker than the reference: deep near-black navy and charcoal shadows, very subdued sand-brown tones, only a dim cool silver-blue moonlight glow along dune ridges, ruined columns and thin river reflections. This is late night, not sunset; no golden daylight, no brightly lit sand, no artificial illumination. The moon may glow softly but must not blow out or dominate. Compose useful landscape details across both sides because the game's terrace covers part of the image. Place the horizon in the upper fifth and retain a narrow strip of sky. Polished atmospheric painterly game art, believable scale and depth, restrained fine detail. No foreground terrace, player, characters, interface, text, borders or watermark. Output 2304x1536 landscape if possible.

8. `assets/textures/desert_moonlit_ruins_v2.png`
   Active fourth- and fifth-floor backdrop, edited from image 7 with the built-in
   imagegen tool. The viewpoint looks more steeply down from roughly four or five
   stories above nearby dunes and ruins. Larger foreground stones, column tops
   and exposed foundations establish the height, with the distant horizon at
   the top edge. It retains dark moonlight, runtime tint, terrace-only visibility
   and the existing dim light on terrace paving and parapets.

   Final prompt:
   > Use case: stylized-concept. Asset type: edited landscape background matte for a game. Input image 1 is the edit target: the existing dark moonlit desert with ancient ruins. Change the viewpoint and perspective: look downward from the fourth or fifth floor of a building, approximately 15 metres above the nearby desert floor, with a distinctly steeper downward camera angle. Bring the desert much closer to the viewer: nearby dunes, scattered rocks, ruined stone foundations and a few weathered columns should be larger, with clearly visible top surfaces below us. It must feel like looking down from an upper-story terrace at ground nearby, rather than looking straight out across a distant valley. Frame the ground across almost the entire image; push the distant mountain horizon into the uppermost 8 percent with only a very narrow sky strip, allowing the moon to be outside the frame. Preserve the same ancient desert setting, winding river farther back to the right, scattered colonnade ruins, restrained painterly realism, and very dark navy-charcoal and sand-brown palette. Preserve dim cool silver-blue moonlight along dunes and stone edges; no daylight or bright illumination. Keep a convincing natural transition from nearby ground at the bottom to distant mountains at the top. No foreground balcony, railing, building facade, people, interface, text, border or watermark. Landscape 3:2.

The hero's body texture, `assets/textures/hero_kit.png`, is baked by
`tools/paint_hero.py` through the character's own UVs. Each vertex takes a region from
its skin weights and rest-pose height: bronze scale armor over the chest, back,
shoulders and upper arms, projected onto the body in 3D from generated image 2 so
its scales keep one size and direction across seams; a dark leather belt; long brown
woven trousers; leather forearm bracers; and bare skin from the
character's original `T_Superhero_Male_Dark.png` elsewhere. The scale armor also has
bulk: `tools/outfit_hero.py` copies the armored part of the body and thickens it outward
(2.5cm, 3.5cm at the shoulders, as a 2cm solid shell) with the same UVs, texture and
skin weights.
Cloth and leather are procedural. Statue materials use generated marble; architecture uses generated
limestone and marble. Original source-pack materials remain on selected small
props and vegetation. The bronze tile is also available as a reusable material.

## Audio

Audio is retained from the user's original Temple Ascension game. The soundtrack
was generated with Suno according to the original game's credits. The retained
combat sound effects were credited to www.zapsplat.com in that project. This
adaptation does not relicense those tracks or effects as CC0. Relevant attribution
must remain with any public distribution, and the original project's license
terms continue to apply.

`assets/audio/stone-crumble.wav` is the original game's `public/stone-crumble.m4a`,
decoded with macOS `afconvert` to 48 kHz stereo 16-bit PCM (1.02 s) and its extensible
WAV header rewritten as standard PCM, samples unchanged. It plays when a statue dies:
instead of falling over, the statue crumbles as in the original game. The body sinks
and spreads over 0.7 s into a rubble pile (the KayKit rubble mesh in statue stone),
twelve stone chips (the imported rock mesh) burst out and fall around it, and dust
rises, all on the combat clock.

`assets/audio/fountain-trickle.wav` is the original game's
`public/sfx-fountain-trickle.m4a`, decoded without normalization or editing to
48 kHz stereo 16-bit PCM. macOS `afconvert` performed the decode; its extensible
WAV header was rewritten as standard PCM for Godot, preserving the decoded
samples. The full 14.294-second recording loops continuously. Gain follows the
original `LevelScene.updateFountainAmbience`: zero outside the court, otherwise
`clamp(1 - distance_to_fountain / half_room_diagonal, 0, 1)`. It uses the player's
ground position rather than the camera, respects the sound toggle, is silent
during pause, and stops when the floor is unloaded.

## HUD

`assets/ui/weapon-*.png` are transparent renders of the existing imported spear,
sword, bow and axe meshes, baked with `tools/render_weapon_icons.gd`. They retain
the source models' licensing. The liquid orb shader in `assets/shaders/orb.gdshader`
adapts the original game's code-drawn circular HUD treatment, with glass highlights,
a bronze rim and a level that follows current health/energy. No new world meshes
are created for the UI.
