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
the water shader uses thin instances of the same mesh. That water
(`assets/shaders/pool_water.gdshader`) is clear and pale green-blue: the stone
shows through it, netted with moving caustic light; small crossing ripples and a
fine chop tilt its surface to catch the torches, it reflects more as it is seen
more slantwise (Fresnel), it churns white where the spill from the bowl above
lands and sends rings out from there, and it rings round the hero as he wades.
Spill particles reuse the imported gem mesh. The generated seal is a transparent VFX sprite,
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
along the walls (in the temple about half as many as in the dungeons, eight metres
apart, each reaching 16 m with a gentler falloff), then added wherever the estimated floor light (the omni falloff
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
the roll and hit reactions, the forearm running across its back (so a tall board
such as the Tower Shield stands upright when the arm is raised before him and
lies along his side, top forward, when the arm hangs); the SwordIdle stance (the
library idle with the left forearm turned 60° outward) turns it out to the side. The hero also wears brown
leather boots (the KayKit Rogue's leg pieces trimmed to the boot, close-fitted over
the lower legs) and a steel full helm matching the shield: the KayKit knight helm
sized to the head and lowered over the jaw, its open face closed by mirroring its
back half forward, whose eye-level seam becomes the visor slit. The
helm hides the hair. `tools/outfit_hero.py` adds both after the enemy outfits are
built; statues never inherit them. The hero's own helmets, though, are meshes of
their own hung from his head bone as the wizard's hat is (scripts/items.gd `mesh`,
tools/make_helms.py, Blender): the Gladiator's Helmet (a round bowl under a tall
narrow crest, a wide brim at the brow, and a visor closed round the head pierced
with holes, riveted), the Ancient Gladiator's Helmet (dark steel: a keel over the
crown set with spikes and a row down each side, a heavy rolled brow, a nose bar
and two broad cheek plates leaving the eyes open across and the mouth down the
middle) and the Steel Full Helm (a tall rounded skull down over the ears and neck
with a riveted face plate, an eye slot across it and a field of holes below). Each
part is named for its finish (Steel, Dark, Bright, Rivet) and coloured by
Art.worn_model with the plate shader as plain hammered steel (Art.hammered); the
kit's own helm is hidden while one is worn. The rest of the warrior's kit is
built by `tools/warrior_kit.py` (run from `outfit_hero.py`; `-- --warrior-only`
rebuilds just his pieces in a few minutes), every piece shaped as rigid armor
rather than a skin of his muscles: each cross-section of a shell is laid on its
convex hull, and each line down it too (`Outline`). `HeroArmor`, the scale
cuirass, is a shell of his torso and the tops of his shoulders drawn out that
way, hanging straight from the chest, its open edges evened out; its scales are
painted over everything it covers, so no skin shows on it. `HeroPauldrons` are
made afresh round each upper arm, clear of the cuirass: a domed cop and three
lames lapping down to mid upper arm. `HeroGauntlets` are his hands and wrists
stood off the skin with a flared bell cuff that ends halfway up the forearm,
their plates (cuff, four lames over the back of the hand, a knuckle plate, a
scale per finger joint, a leather palm) carried in their UVs for
`assets/shaders/harness.gdshader`, which draws both. `HeroGreaves`, the Steel
Plated Boots, are lofted from the sole a centimetre or so off the leg: a
sabaton of the foot's own size with a rounded toe and overlapping toe lames
(drawn by the shader), two lames over the ankle, and a greave following the
shin and calf to a rolled rim, level all round at mid-shin. `HeroCuisses`,
Plated Leg Armor, covers what long trousers would, from under the belt to the
ankles (cuisse lames, a domed knee cop, greaves, mail between the legs), close
over the skin (5 mm off the shins, 7 over the thighs, more about the knee, so
none shows through as it bends: `tools/warrior_kit.py` LEG_STAND), so the legs
are not thickened; worn
with the boots, it is cut off inside them (plate.gdshader `cut_below`). Both are hammered steel by
`assets/shaders/plate.gdshader` on their rest pose. `HeroKilt` is pteruges: 18
separate strips of stiff leather, each three rigid pieces creased 10 and 21 cm
down (bones `kilt_<i>`, `kilt_<i>_1`, `kilt_<i>_2`, its end `kilt_<i>_tip`),
hung from the pelvis at the belt's lower edge, and a row of 18 short tabs
(`kilt_<18+i>`) over their tops. `scripts/kilt_strips.gd` swings each piece as a
damped pendulum and keeps it out of his body, which it fits at setup from his
own skinned mesh, sampled across its faces: each thigh, hip crease and calf top
as a tube whose outline at every 1.5 cm along it and every 1/32 of a turn round
it is his outermost flesh there (the hips' own flesh moves with the hips the
strips hang from, and the strips are cut to clear it). Every frame each piece,
from the belt down, is turned out of the flesh along its normal (its middle,
tip and edges: the edges from the strip's own width and curl), and a piece
lying near a leg is drawn down onto it as it swings (its weight, damped) and
twisted a little, at a limited rate, to lie flat on it. The flesh's outline is
blended smoothly along and round each tube (tapering away where there is no
flesh, between the legs), and a push out of it, or the draw onto it, moves a
piece without setting it swinging (it keeps only the flesh's own motion), and
puts it out at once only as far as it and the flesh came together (deeper only
at `GIVE`): so a man standing still has his strips lie still, moving only as
his body does. (They did not: every jump of the flesh's outline, or of the
way out of it, threw a strip, which swung back and was thrown again; the
strips flapped and shook in an idle.)
A thigh raised up through a strip's hinge carries the hinge up onto it (under
its tab), so the strips in front of a rising knee ride on top of the thigh.
Nothing stretches (`assets/shaders/kilt.gdshader` draws them). Its data is in
flat packed arrays and nothing is allocated per frame. `tools/kilt_check.gd` measures how
far the strips go into, or stand off, his skinned body through a clip. The forearms are bare above the
gauntlets (`tools/paint_kits.py`); the statues carved from his kit keep the old
manica and wraps, the warrior's height map being painted from that. `assets/textures/wood_planks.png` (cut from the
Quaternius furniture trim sheet by `tools/paint_hero.py`) remains available as a
wood material. Hit reactions for anyone holding a shield (ShieldHit, ShieldHitHead, ShieldHitStagger,
ShieldHitKnockdown) keep that 60° forearm turn, so a hit does not flip the shield.
SwordRun is the sprint with both arms eased toward that carry, so the sword
stays low and never swings through the head. Staff attacks reuse the Cast
animation. Class projectiles reuse the arrow and gem meshes. Abilities, the
hero's and the statues', leave no coloured circles on the ground marking where
they strike; the seal sprite is kept for the exit, the crown, dropped loot and
the stun mark. This update adds no externally sourced or generated image assets.

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
flash and a fading scorch mark (no coloured ring on the ground). Damage
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
from `scripts/assets.gd`. Every enemy in sight has a 60×4 HUD health bar
projected above its head. The ring scales with the enemy's stature. Both
indicators ignore mouse input.
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
  them; the map also marks the track, water (the oasis, the palace's pools), and
  shade at the foot of walls and rocks. Water is drawn clear: its bed shows through,
  dimmed and tinted the deeper it lies (red absorbed first, silt darkening the deep
  bed), lit by caustics in the shallows; wind ripples and a chop, read from the
  noise texture, tilt it to glint in the sun; it reflects the sky overhead by
  Fresnel (the colour `scripts/overworld.gd` set_time gives it, through the day and
  night); and it laps at its edge with a running wet line and flecks of foam. The control map is a one-texel-per-metre image painted by the builders at
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
  make the rim (not round the town, which is closed by its own wall of the gate
  wall's modules, towered at the corners: Town.town_wall; the world's `walled`
  says where no rock stands), drawn in batches: cliff faces along the far walls, boulders rising
  away from the camera on the near ones. Here and there a stretch of the town
  wall has fallen into a breach (Town.ruin): no kit module, but a mesh built
  for it, column by column of stones broken off at their own heights, each
  face of the wall to its own, tops tilted and chipped, the line dropping
  from the standing wall either side (steeply where it breaks off a whole
  bay) to a low point that differs from bay to bay (1.6 to 3.8 m); its fallen
  stones lie in heaps of rubble and dressed blocks at its foot, more the lower
  it has fallen. It is drawn in the masonry shader as the rest of the wall is,
  and still closes the town. The palace hill's white wall (its gate guarded
  by marble centurions) runs from its gate's towers to the town wall's towers
  at the hill's corners, and no further.
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
  life size, both facing west. The town's statues are marble: four seated lions
  (two on the palace road, two great ones at the palace steps) and two centurions
  at the palace gate.
- **The lion.** `tools/make_lion.py` builds `assets/models/character/lion.glb`, used
  for the temple's Lion Guardian and the town's marble lions. Its body is sculpted
  by the script, volume by volume, as a lion is built: the trunk in sections from
  breast to rump (a deep ribcage, the belly tucked up behind it, loins and croup),
  shoulder blades and the muscle under them, thick forelegs with elbow, forearm and
  wrist, the hind leg's great thigh, hamstring and flank fold, the stifle, the shin
  running back to a high hock with its tendon, the long foot below, broad paws with
  four toes and claws, a hanging tail and its tuft, and a mane of some 290 long
  locks lying over the head, the neck, the shoulders and the breast, each a tapered
  tongue following the surface and lying over the next. The clay is fused into one
  surface twice. The fine one (about 330,000 faces at a 5.5 mm grain) has the detail
  cut into it: every lock combed into strands, the ribs, and the lines between the
  muscles of the shoulder, flank and thigh. The coarse one, cut to 17,000 triangles,
  is the mesh the game draws; the bare body's masses are melted into one another
  (the hair and the toes keep their edges), and the fine surface's relief is baked
  onto it as a tangent-space normal map. Its face is Poly Haven's sculpted
  [Lion Head](https://polyhaven.com/a/lion_head) (CC0), a mask of a lion's face and
  the mane round it (7,000 triangles), with its own normal map; both maps share
  `assets/textures/lion_normal.png` (the body's on the left half, the face's on the
  right), read by the statue shader through the UVs (vertex colour blue 0). The
  script builds the skeleton (30 bones: hips, spine, chest, neck, head, a five-bone
  tail, and four legs of upper leg, lower leg, paw and toes), skins the mesh to it
  by nearness to each bone (a leg holds only its own side; the mane goes with the
  head, neck and chest), and keys seven clips frame by frame, the legs by two-bone
  IK and the motion carried smoothly through its key poses: Idle (four seconds:
  breathing, shifting its weight, the head turning, the tail swaying), Run (a trot:
  each fore paw lands with the opposite hind paw, the two pairs half a stride apart,
  the paws folding up behind and reaching out to land; `LION_STRIDE_SPEED` in
  `scripts/visual.gd` is the ground it covers a second as authored), Attack (it sinks
  back, rears onto its haunches with the right forepaw drawn up and out wide, then
  uncoils behind the paw as it rakes forward and across and drops back onto its
  forefeet; the blow lands half way through, `LION_SWIPE` in
  `scripts/combat_animation.gd`), Hit, HitHead, HitStagger (driven back onto its
  haunches, a forepaw thrown out to catch itself), and Sit (on its haunches,
  forelegs straight, hind feet flat, tail curled round on the ground: the held pose
  of the town's statues). `LION_QUICK=1` skips the fine sculpt and the bake, to try
  a shape or a pose. `scripts/visual.gd` treats it as a quadruped: no hand grips,
  shield arm or equipment, and its feet are planted by `scripts/paw_planter.gd`,
  the foot planter for four legs: each paw the animation sets down is pinned and
  its leg bent to it by IK, and when the lion is driven over the ground by a blow
  the diagonal pairs of paws step in turn, landing ahead of the body the way it is
  carried.
- **The gate guards.** `tools/make_guard.py` builds `town_guard.glb`
  (`assets/models/character/`): the hero's body at the centurion's heavy build,
  in the centurion statue's armor (the KayKit Knight's cuirass, arm and leg
  plates and helm, close-fitted as `tools/prepare_enemy_outfits.py` fits them),
  at life size, its pieces kept apart and only the standing idle kept. The game
  dresses it for real (`scripts/town_guard.gd`): the body in the warrior's
  painted skin and kit, the armor through `assets/shaders/guard_armor.gdshader`
  (the knight's palette read only for what each part is made of: hammered and
  rusting steel, bronze, red wool, leather, all dusty), mail breeches under the leg
  plates (his own hips and legs, cut from his body and stood off it, drawn as rows
  of steel rings: where the knight's plates part, behind the thigh and knee and
  round the calf above the boot, mail shows rather than skin), a grounded spear, and the
  KayKit square shield painted as a red
  legionary's board (`assets/shaders/guard_shield.gdshader`). Two stand at each
  of the town's gates. The spear is a legionary's hasta (`assets/models/props/hasta.glb`,
  built by `tools/make_spear.py`), 2.3 m: a slender leaf-shaped iron head with a
  raised midrib, its faces hollowed to a fine point, on a conical socket with two
  collars and a rivet; an ash shaft bound in a spiralled leather thong where the
  fist closes; and a pointed iron butt-spike. Every part is the MedievalPack
  spear's shaft cylinder, cut from its head, subdivided and turned to the part's
  profile (the head flattened through its section into the blade), unwrapped
  round and along it for `assets/shaders/spear.gdshader`: hammered, faintly rusted
  iron with the blade's edges honed bright, oiled and handled ash grain, and the
  thong's turns.
- **The townspeople.** `tools/make_townsfolk.py` builds `townsman.glb` and
  `townswoman.glb` (`assets/models/character/`) from the base character pack's two
  bodies (its "superhero" male and female, which come unclothed, cut to 7,000
  triangles each), with the pack's hairstyles and eyebrows, and thirteen clips from
  the two animation libraries retargeted as the hero's are (standing, talking,
  walking, jogging, sitting down and getting up, sitting, sitting and talking,
  drinking, reaching, carrying, dancing, arms folded); the seated drink is made in
  the game from the sitting and drinking clips. The packs have no clothes, so a
  wardrobe is fitted by the script from each body's own shape: a garment is a tube
  lofted down the body (at each height, the outline of the body there, its convex
  hull with the arms left out, eased outward by the cloth's looseness and joined to
  the next; sleeves lofted along the arms), skinned from the flesh nearest it. Men
  have a knee-length tunic, a short sleeveless sack and a mid-calf robe; women a
  gown, a shift, and Anya's long-sleeved blouse and square-necked dress (the tube
  with its neck cut out, leaving straps over the shoulders); the gown and dress
  lie well off the shoulders and the blouse close on them, so it never shows
  through. There is a belt, and Anya's braid is laid down her back lobe over lobe.
  An apron (Selene's, Zeno's) is the front of the skirt beneath it, laid a little
  off it: held as that skirt is, so it lies on a seated lap, but standing and
  walking it hangs from the hips and a striding leg pushes it out
  (`cloth.gdshaderinc` with `cloth_fold.gdshaderinc`; `scripts/townsperson.gd`
  `apron_legs` gives it the legs). Sandals are made for each body's feet: a flat
  sole a little larger than the foot's print and straps across the toes, the
  instep, round the ankle and up the heel, each where a plane cuts the foot. All
  townsfolk wear them but the shod and the starving, who go barefoot; the
  starving also have the woman's long hair grown out and matted (fitted to the
  man's head too) and the men a long beard, the locks stretched, combed off the
  body and straggling (`grown`), and a starving woman's feet are drawn smaller.
  The body's seam points are joined, so a figure drawn in by hunger
  (`gaunt.gdshaderinc`) does not crack at its seams. Each mesh carries extra data
  in its second UV set: on the body, every point's height at rest and how far
  along the arm it is, so `assets/shaders/townsfolk_skin.gdshader` leaves out the
  flesh under a garment (and dirties the poor); on a garment, how near its hem or
  cuff a point is and how far down its length. `assets/shaders/cloth.gdshader`
  dyes Poly Haven's photographed rough linen or hessian (CC0,
  `assets/textures/cloth_*.jpg`) and wears it out as far as `wear` says: fading,
  grime toward the hem, sewn-on patches, frayed hems and cuffs, holes. The
  renderer lights two-sided cloth from the wrong side, so the inside is a second
  pass (`cloth_inside.gdshader`). `scripts/wardrobe.gd`, written by the script,
  records what each garment covers. A mug is held by its handle in the left fist
  (`scripts/arm_reach.gd`, a two-bone IK on the arm that carries the hand to a point,
  turns the fist to keep the mug upright and curls the fingers): Anya's hand holds
  the mug under the tap, carries it at her side and sets it on the table; a
  drinker's goes from his lap to the mug on the table, lifts it to his mouth and
  sets it down again; the fist holds the mug as a mug is held, fingers through the
  handle and wrapped round its bar, the thumb resting on top, the body off the
  palm's side (the mug prop's handle is on its +X side, its body off-centre the
  other way, as the prop was centred on its bounds). Orion the blacksmith is a
  townsman given a heavy build (the figure broadened across and through), shoes
  (a shell of leather drawn over his feet: `assets/shaders/shoes.gdshader`) and
  tools: a hammer assembled from the column and metal-crate props, the game's
  sword, and the column as an iron rod. `scripts/smith.gd` runs his work: each
  tool is put exactly where the work needs it and the hand holding it follows by
  IK (`scripts/arm_reach.gd`, which turns the fist to lie round the tool with the
  wrist straight), while he bends over it from the waist (`scripts/body_lean.gd`).
  He is heard at it: a blow rings out each time the hammer's face meets the blade
  (the moment the sparks fly), and the grinding sounds while the blade is on the
  turning stone (see Audio).
  The grindstone's wheel is cut from its frame by `tools/prepare_whetstone.py`
  (`whetstone_wheel.glb`) so that it can turn. `scripts/townsperson.gd` dresses a figure and
  `scripts/townsfolk.gd` runs the town: its own A* grid of the streets (the arena,
  palace hill, smithy and the inn's loft closed), the seats at the inn's tables,
  the inn's occupancy rules, Anya's rounds and the children's games.
- **Street bedding.** `tools/make_bedroll.py` builds `assets/models/props/bedroll.glb`:
  a sheet of sacking, a blanket and a stuffed sack for a pillow, from the props
  kit's banner cloth (without its rings) and its bag, let fall and settle by
  Blender's cloth simulation. The sacking is spread a little too large for the
  ground it lies on, so it buckles into creases; the blanket is dropped on it
  askew and crumples over the pillow and the sacking's ridges. (The ground the
  cloth falls on is the simulation's only.) The game dresses each piece in the
  townspeople's photographed cloth, the blanket woven in a pale lozenge
  pattern, and lays a pallet out only while its sleeper lies on it.
- **The greengrocers.** Three stalls below the market square, just inside the
  south gate (`scripts/world_town.gd` `greengrocers()`), are the props kit's
  stall with crates of its apples and carrots on the counter, a barrel of
  apples or a stack of carrot crates at one end and empty crates behind
  (`carrot_crate`, `apple_barrel`, `crate_empty`, imported by
  `tools/prepare_models.py`). The kit paints its fruit and vegetables by vertex
  colour; `assets/shaders/produce.gdshader` keeps that colour, mottles and
  bruises it with the photographed grit and gives the fruit a waxy skin, and
  turns the apples' red to oranges, lemons, pomegranates, onions or figs
  (`Kit.produce`). At night two of the kit's banner cloths, dyed as sacking,
  lie over each counter. `scripts/townsfolk.gd` gives each stall a keeper, who
  sets out his wares after sunrise, stands at the counter's end serving, and
  packs up through the sunset and goes home; townspeople with houses stop to
  buy and carry a crate home in both hands (the library's carrying walk).
- **The bandits.** `tools/make_bandits.py` builds `bandit_man.glb` and
  `bandit_woman.glb` from the same two bodies, dressed after the desert raider of
  their concept art with the townspeople's garment lofting: a long sleeveless
  linen tunic banded in red at its tattered hem, a studded leather vest with a
  strap across the chest, a red sash under a leather belt, a ragged apron over the
  skirt, a red shawl wound about the neck, a short cape down the back, a cloth
  wound about the brow and knotted behind, and leather bracers and shin bindings
  (`assets/shaders/bandit_leather.gdshader`: hide, bronze studs, strips wound over
  linen); sandals are drawn on the feet (`shoes.gdshader`'s `sandal`). The hero's
  fighting clips are retargeted to each body from `warrior.glb`, and the ranger's
  quiver and sheathed dagger are carried over from it, moved bone by bone to each
  body's frame. Their sword is a sica (`assets/models/props/sica.glb`), the bronze
  sword's blade swept back toward its point; the sword shader's `SWEEP` keeps its
  fuller on the curve. `scripts/bandit.gd` draws each bandit's look from its id
  (man or woman, skin, hair and beard, dyes, which of shawl, cape and brow wrap
  are worn), and `cloth.gdshader`'s `bands` and `lattice` weave the red stripes
  and lozenges into the linen; `scripts/bandit_wardrobe.gd`, written by the
  script, records what each garment covers.
- **Walk-in buildings.** `scripts/world_interiors.gd` builds the inn and the smithy
  as halls of the town's wall modules on all four sides, with an open doorway.
  `Overworld.rooms` holds each hall's footprint, its roof and its front (the south
  and west walls, the camera's side), hidden while the hero stands inside; its far
  walls never fade over him there. `Overworld.decks` holds floors above the ground
  (the inn's loft, and the ramp of its stair): `height_at` adds a deck's height, so
  the hero, the camera, clicks and anything set down there stand on it, as on the
  palace hill. Floors are the dungeon kit's wood and stone floor tiles; the stair,
  the bar (two long tables), the loft's rail and the wall shelves are that kit's
  shapes in sawn timber (`Kit.planks`, the plank texture at one size in the world).
  Beds, tables, benches, stools, mugs, plates, bottles, candlesticks, cabinets,
  chests, workbenches, the grindstone, anvils, pegs and the rest are the props kit's
  models in its own trim materials. The forge is built of the town's masonry in
  blackened stone (a hearth, an arched firebox, a hood and a chimney), with a bed
  of coals (the temple braziers' burning charcoal, `assets/shaders/embers.gdshader`,
  spread wide), the torches' flame, and a warm light that reaches the room. The arms
  on the smithy's walls are the game's own weapon models, smaller than the heroes'
  carry them: swords and round shields finished as the warrior's own, the rest in
  bright steel on dark wood (`assets/shaders/arms.gdshader`).
- **Gold and marble.** Gold is the rock grain photograph tinted to gold with a little
  metal and its own faint glow (the outdoor scene has no sky to reflect); marble is
  `statue_marble.png` laid at one size in the world (plinths, kerbs, columns, the
  Elders' Box), so its veins keep their shape on blocks of any proportion; the box's
  walls are built of wall modules near the kit's own four metres square rather than
  one module stretched to the wall's length. The thrones are built for the game by
  `tools/make_throne.py` (`assets/models/props/throne.glb` and `throne_elder.glb`,
  at their real size): a solid seat block of white marble on a stepped marble plinth,
  panelled and framed in gilt, gilt lion's feet; solid arms, marble side panels under
  gilt rails ending in scrolls; a tall solid back, raked a little, its inner face a
  crimson velvet pad in a gilt frame, posts with finials at its corners and a gilt
  sunburst crest; a deep velvet cushion. Their surfaces (`ThroneMarble`, `ThroneGold`,
  `ThroneVelvet`) are dressed in the world's marble, gold leaf and a crimson velvet
  whose pile catches the light at its edges. The elders' box has five of the smaller,
  plinthless throne, 1.2 m to its crest. Rails, cornices, column heads and feet are the
  paving mesh, gilded.
- **The palace hill.** The world's ground is one flat slab; the hill is
  `assets/models/props/hill.glb`, a two-metre grid raised to the hill's height by
  `tools/make_hill.py` (like the palms, built for this game rather than taken from a
  kit) and drawn with the slab's own ground shader, which tilts its shading with the
  slope. `Overworld.height_at` reports the same height, from the same numbers, and
  the test suite compares the two. Everything is still walked on one plane: what
  stands on the hill, the hero's figure and the camera are raised to its height.
- **The palace within.** `scripts/world_palace.gd` builds the palace as a walk-in
  hall of the town's wall modules (fifteen bays by six, two storeys) on its terrace,
  which is a raised deck (`Overworld.decks`) climbed by its front steps; the roof, the
  tower over it and the walls on the camera's side are lifted away while the hero is
  inside (`Overworld.rooms`). The throne room (28 m by 24) runs from the door to a
  marble dais edged with gold, a deck of its own climbed by the stairs mesh, where
  the great throne (`tools/make_throne.py`, 2.4 m to its crest on its own two-step
  plinth, its seat a big man's) stands, crimson hangings
  behind it, fires in gilded bowls either side; two rows of marble columns with
  gilded heads and feet, a crimson runner (the kit's banner cloth laid flat) and
  benches along the walls, the floor between left clear for the town to gather.
  Five bedchambers open off it through arches, three west and two east, each in its
  own colours: the kit's bed scaled up with dyed covers, its furniture in a dark
  polished wood, a rug, stands with candles, a chest, a cabinet, a gilded table with
  a marble top and gilded chairs, gilded urns, a fire, a hanging and a lamp. Two
  gate guards (`scripts/town_guard.gd`) stand at the palace gate, before its towers, and two
  at the palace's door.
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
  (`assets/textures/desert_leaves.png`, darkened). These are
  exported bare and share one copy of each texture.
- **The well.** A CC0 model by Quaternius from [Poly Pizza](https://poly.pizza/m/QlqncKYxXb)
  (`source_art/poly_pizza/`). It comes in flat colours; the game gives its stone, roof
  tiles and bag the rock grain photograph and its timber the existing plank texture.
- **The temple door's glow.** A dull amber (close to the torches' own light), unshaded
  end wall to the passage; sheets of the same amber (sprites with generated gradient
  textures) on the passage's floor and walls, clear at the threshold and full a few
  metres in; a soft round pool of it over the court before the door; and a light of
  the torches' colour. No image asset.
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
- The warrior's normal sword attack (SwordOpen, and SwordCut1, SwordCut2 and
  SwordThrust each stepping with the right foot or the left: `R`/`L`) is authored by
  `tools/import_skills.py` as one unbroken cycle of three swings, cut into a clip a
  swing: a cut down from the upper right to the lower left, a backhand cut down from
  the upper left to the lower right, and a lunging thrust, the whole body wound
  round against each and thrown into it, the cuts followed through almost to the
  ground. The cuts trail a wake of air behind the blade (`scripts/sword_trail.gd`,
  `assets/shaders/sword_trail.gdshader`): a ribbon through the blade's last places,
  fading out. A skill's swing leaves the same wake where it cuts fast before
  its blow (`scripts/visual.gd` SKILL_WAKE); a two-handed Thundering Strike's from
  the moment the weapon is hauled down off the top. He walks into his target as he swings: each
  swing is struck on a full stride of the rear foot past the front, so the feet
  alternate. Swinging on, one runs into the next (`scripts/combat_animation.gd`
  SWORD_CHAIN); broken off, the next attack starts again from SwordOpen, the first
  cut wound up out of the stance as a serve or a long throw is: the hand drops back
  past the hip as he turns away and dips, comes up behind the shoulder with the
  elbow leading, and the blade, left lying back over the shoulder, is whipped over
  the top into the cut. Each clip ends with a recovery to the stance
  (stepping back into it if the swing left the right foot forward) that plays only
  if he swings no more. Through every swing and skill of a one-handed weapon the
  shield arm is held in the town guards' guard (their SpearShieldIdle and
  ScutumSwordIdle, `tools/import_combat.py` `shield_arm`): the left forearm level
  across the front of the body, the fist before the belly (a little higher than
  theirs, and through a swing raised or lowered to the elbow's height, so the
  forearm stays level and the board strapped across it stands upright), the
  elbow forward and out, the board's face turned the way his chest faces but
  kept level. It is kept in the chest's frame, so it turns with him;
  it is raised out of the stance's hanging arm as a swing begins and lowered as
  he recovers, more gently than the rest of him moves; and with an empty left
  hand the arm is held the same. Where the sword (blade or forearm) would pass
  through the board (loading the backhand, drawing the thrust back), or his head
  bowed over a blow would, the board yields: carried out, down, up or forward,
  whichever needs least, just far enough, found at every moment and eased over
  the moments around it so it never jerks (`YIELD`; each skill's `SHIELD_CHECK`
  line gives the most it yields and how close the sword or head comes).
  Shield Bash and Shield Charge start and end in the same guard. The script
  checks every frame that the blade and sword arm keep clear of the body, the
  shield arm and the shield (`SWING_CHECK` in its output), and holds the
  wrist's bend within reach. `HERO_GLB` names another model to read and write;
  like `tools/import_pike.py` it sends every clip it does not author out with
  the timing it came in with, rather than a frame late. The library's SwordSwing
  remains the Crowned Statue's swing.
- The ranger's own clips (DaggerStab, DaggerSlash, SkillFlurry2/3/4,
  SkillTripleSlash, SkillAmbush, SkillSandR/L, SkillHide, SneakIdle, SkillVolley)
  are authored by `tools/import_ranger.py`, run after `tools/import_skills.py`:
  the dagger's motions keyed frame by frame as the warrior's swings are, the
  crouch taken from the ranger's crouched run, and Volley made from the archer's
  shot with the chest tipped back. His dagger is the adventurers pack's
  `dagger.gltf` (`assets/models/props/dagger.glb`), finished by the sword's shader
  cut to its own pommel, grip and guard.
- The warrior's skill swings (SkillCleave, SkillStrike, SkillStab, SkillBash,
  SkillExecute, SkillSlam, SkillShockwave, SkillCry, SkillCharge, SkillLeap, and
  DualSkillSlam, Thundering Strike with a weapon in each hand, both swung over the
  head and slammed down) are
  authored by `tools/import_skills.py` from the sword-and-shield stance, frame by
  frame: the hips, spine and head turned and bent along smooth curves, the sword arm
  carried by two-bone IK with the fist turned outright so the blade runs where the
  swing sends it, the shield arm held in the guards' guard (moved as the swing
  needs, as above), both feet kept planted by leg IK (the charge borrows the
  sprint's legs), and each eased
  out of the stance and back into it so nothing leaps between frames. Thunder
  Slam's arm (and both of the dual swing's) is set by `tools/blender_arm.py`,
  which the two-handed clips share: the fist is set on the weapon with the wrist
  bent no further than a wrist bends (the weapon tipped back toward square across
  the forearm, the fingers laid along the forearm's line or turned about the
  weapon no further than 55°), the elbow is swung round the arm's line from where
  it was asked to the nearest place that leaves the fist turned no further than a
  forearm turns (measured from the elbow's pit: at the middle the thumb points at
  it; and never, given the chest's front, to where the elbow points at it, which
  reads as an elbow bent the wrong way), and the forearm is rolled after the
  fist. In the two-handed clips (but Thundering Strike and the normal attack,
  whose poses say outright where each elbow points) the elbows are planned over the whole clip
  rather than searched afresh at each frame (`import_heavy.py` `elbows()`):
  each frame is posed to measure what every way round each arm's line would
  cost there (`fist`'s `profile`, 48 ways; twice, the second time as first
  planned, since each arm's costs hang on the other's), the ways that cost least
  over the whole clip are chosen together with each turn of an elbow round
  its arm counted against it, so an elbow sets off early and never leaps,
  and the clip is keyed with the elbows set those ways (`force`); the left
  thumb keeps its way along the haft unless the other wrings the forearm
  clearly less. (Searched frame by frame, an elbow was thrown from one side
  of its arm to the other wherever two ways were near enough as good: half
  round and back from frame to frame through the normal attack, and to and
  fro between two steps of the search with each breath of the stance.) Both
  exporters take `SKILLS_DRY`
  / `HEAVY_DRY` (author and check, write nothing) and `SHEET_DIR` (render each
  clip authored as a contact sheet in Blender itself, `tools/blender_sheet.py`,
  laid out by `tools/sheet_compose.py`: his right side, the front, and the
  game's own 43° downward view from his front right and from behind his left,
  a stand-in weapon on the fist), which is how a swing is judged without the
  eleven-minute export and reimport. Thundering Strike itself (all three clips) is
  one circle on his right, after the user's drawing of the head's path: the
  weapon held before the belly pointed ahead is swung down past the outside of
  his right leg and back behind him as the arms drop and swing back with the
  chest turned to it, up behind him, over the head, and down before him to meet
  the ground level, as a hammer meets a nail, a stride ahead of a deep kneel.
  The two-handed clip (HeavySlam, `tools/import_heavy.py`; 1.4 s against the
  sword's 1.6, `scripts/skills.gd` OWN_SECONDS, so it is wound up faster) is keyed as a man
  swings it rather than as the weapon's path: the hands as a direction and
  reach from the middle of the shoulders in the chest's own frame, the right
  elbow's direction in that frame, and the right wrist's cock and turn on its
  forearm, all found again each frame about the chest as it then stands. So
  the hands ride round before the turning chest, where both of his short arms
  reach them without either crossing into it, and nothing is asked of a wrist
  that it cannot give, so the fist never tips the weapon or turns it over
  between frames; the left elbow points away from the side of its arm the
  head lies on, so the left fist (thumb toward the head) is never wrung or
  flipped. Its head swings out and down past his right hip at belt height,
  the lowest it goes, round behind him and up, with no second dip. The
  two-handed normal attack (HeavySwing1) is keyed the same way (`chest_pose()`):
  the weapon carried up and back over the right shoulder as a batter loads,
  the hands by the right ear a span out from it and the haft rising behind
  the head, then brought over and down before him as the rear foot steps
  through, and cut on to the lower left with the chest turning on round.
  Keyed by the weapon's path in the world, as it was, its wind-up turned the
  chest so far that the grip came out before the face, the haft level
  through the head, and its follow-through drew the weapon in through the
  chest; each of its poses was then found (by a search over the hands'
  reach, the elbow's way and the wrist's cock and turn) where both wrists
  and forearms can give it and the weapon, war hammer, axe or greatsword,
  keeps clear of the head, face, neck, chest, belly and arms, with the
  wrists' cock and turn running on through the blow so the head is fastest
  as it lands. (The elbow's pit is read off the upper arm wherever the arm
  is bent: folded tight, the forearm runs back almost along the way the
  elbow is asked to point, and the pit read off that turned the weapon
  over between frames.) The checks (`HEAVY_CHECK`) measure the face too, a
  capsule from brow to chin before the skull's sphere, and the meshes are
  hidden while clips are posed, which makes authoring some three times
  faster. The shockwave of a blow
  on the ground is `scripts/shockwave.gd`: a disc laid on the floor over the blow's
  reach (a slice of one for the slam's arc) and a low wall standing on the front,
  both drawn by `assets/shaders/shockwave.gdshader` (the racing front, its haze,
  and the cracks about the point of impact: thin, jagged lines, the cell pattern
  they follow twisted at three scales and their width uneven along them, each
  thinning out to an end of its own, out from the blow and past the sides of the
  slam's arc, for which the slice's ground is drawn 30° wider than the front it
  carries), with a flash of light and one burst of
  the soft-dot billboards (`scripts/vfx.gd`) for the dust thrown up; the floor's
  own meshes are untouched.
  `scripts/skills.gd` picks each skill's
  clip, duration and contact point (`WARRIOR_CLIPS`). With a second weapon in the
  left hand the game plays a `Dual` variant of each sword swing and skill, derived
  at load (scripts/visual.gd derive_dual_swings): the clip with the left arm's
  tracks replaced by the dual idle's hanging arm, so the second weapon never
  crosses into the body; Thundering Strike alone has its own authored dual clip. The
  left hand's own cut (OffCut) is mirrored from the dual first cut, so the right
  hand's weapon is carried at his side meanwhile, not across the belly.
- A two-handed sword, axe or maul has its own clips (HeavyIdle, HeavySwing1,
  the one normal attack: a full-bodied cut that steps the rear foot through,
  HeavyCleave, HeavyStrike, HeavyExecute, HeavySlam, HeavyShockwave,
  HeavyCry, HeavyLeap), authored by `tools/import_heavy.py`, and the spear in both
  hands its own (PikeIdle, PikeThrust1, PikeThrust2 and the same seven skills as
  `Pike...`), by `tools/import_pike.py`: keyed frame by frame as the sword's skill
  swings are, each from its own stance and back to it, each skill's blow landing at
  the same moment of its clip as the sword's (`scripts/skills.gd` WARRIOR_CLIPS).
  The weapon is carried by the right hand; the left holds the haft 0.12 m below it
  (0.55 m ahead of it on the spear), and `scripts/two_hand_grip.gd` keeps it there
  as one clip fades into another. Each script reads the model from `HERO_GLB` (by
  default the game's own) and can author a few clips alone (`HEAVY_ONLY`,
  `PIKE_ONLY`); each sets every clip it did not author back to begin where it
  began in the file, so none is exported a frame late. Run `import_pike.py`
  last.
  `HEAVY_CHECK=2` prints every frame's wrist bends and fist turns, the weapon's
  clearances from the body and the ground and the hands' reach.
  Their run and walk are made when the figure is set up (`Visual.derive_carries`):
  the plain run and walk with both arms held as the stance holds them. So are a
  left hand's blows, for a weapon in each hand (`Visual.derive_mirrors`: OffCut,
  OffStab and OffSlash are SwordOpen, DaggerStab and DaggerSlash mirrored left for
  right through the body's middle plane, from the rest pose alone), and the stance,
  run and walk with a second weapon (`Visual.derive_duals`: the sword's, with the
  left arm carried as the right is rather than in a shield's guard).
  `tools/preview_clip.gd` renders any clip as a sheet of poses, seen from the side
  and the front, with a weapon in hand as the game holds it (and with `--shield`,
  a shield strapped across the left forearm as the game straps it).
- The wizard's stance (WizardIdle) is authored by `tools/import_wizard.py` from the
  library's relaxed Idle: the rear foot brought in under him so his robe's back
  hangs clear of it, the staff's foot planted ahead of his right foot (clear of
  the skirt) with its top leaning back toward him, the fist held still where the
  staff meets the ground, its thumb up the staff, the elbow hanging at his side.
  His casting (CastBolt, CastPoint, CastGround, CastSelf and the looping
  CastChannel) is authored by the same tool from that stance, the left
  hand gesturing while the right keeps the staff; in the game his fist is turned
  about the wrist so its grip lies along the staff in every clip
  (`scripts/staff_hand.gd`), and the staff is laid through it. `scripts/skills.gd`
  CAST_CLIPS gives each spell its clip and the moment it leaves his hand
  (CastBolt, the hurl of Fireball, Ice Bolt and Lightning Bolt, steps into the
  throw and back; those three leave from his left hand where the clip has
  thrown it). His spells' effects are `scripts/wizard_fx.gd`: particles,
  sprites, ribbons of light and the imported crystal mesh (frost on the floor,
  bolts of ice, ice closed round a frozen enemy, spikes, streams of frost, the
  storm; the ring of Blast Wave over the shockwave's front in fire, the
  tornado's column, Blazing Speed's heat, a burn; bolts, jolts, the shield's
  sparks, a rod's; the casting hand alight with a hurled spell's element, and
  what rises from where it strikes).
- The wizard's staffs are built by `tools/make_staffs.py`, every part turned on a
  lathe or swept along a path, each its own mesh by material for
  `assets/shaders/staff.gdshader`: the twisted silver staff (`silver_staff.glb`,
  1.8 m; also the Oracle's Staff in gold): three strands wound round a core rod
  opening into a cage of prongs about a long faceted crystal in a cup, with three
  small shards, a pointed ferrule, a leather grip wound with a raised thong and
  beaded collars; and the ashwood staff (`ashwood_staff.glb`, 1.75 m): a gnarled,
  knotted, bowed ash shaft splitting into three branches round a rough stone,
  bronze bands and ferrule and a cord-wound grip. Each grip is wrapped where the
  game holds it (1.254 m up).
- The hatchet is a bearded axe (`assets/models/props/bearded_axe.glb`), built by
  `tools/make_axe.py`: a long sweeping edge drawn out into a horn above and a
  beard below, hollowed under toward the haft, the cheek thick at the eye and
  ground thin to the edge; a square poll behind the eye, steel langets down the
  haft, a dark hardwood haft swelled at its capped foot, with two steel bands.
  Its parts are named for their finish (Head, Haft, Fittings: Art.axe_part); the
  head's shader (`assets/shaders/axe.gdshader`) reads the blade's UVs, dark forged
  steel etched with scrollwork on the cheek and a bright brushed bevel to the edge.
- The flanged mace (`assets/models/props/mace.glb`) is built by `tools/make_mace.py`:
  a haft, pommel, grip and collars turned on a lathe, and seven flanges cut as flat
  blades; nothing imported. The greatsword (`assets/models/props/sword_long.glb`)
  is built by `tools/make_greatsword.py`: a pear pommel, a long grip bound in a
  spiralled cord between two ferrules, a crossguard whose arms curve toward the
  blade and swell to rounded ends, a blunt ricasso, and a blade ground from a
  thick spine to thin edges with a fuller down each face, narrowing to a point
  (about 8,000 faces; its `pommel` look keeps the pommel steel and draws the grip
  as leather cord, `assets/shaders/arms.gdshader`). The war hammer's edges are
  bevelled (`tools/make_warhammer.py`). The other items' models are ones the game
  already had (the adventurers pack's one-handed axe, the battle axe, the guards'
  hasta and the bandits' sica), each with one of the game's own finishes
  (`Art.finish`).
- Items are pictured for the inventory by `tools/render_item_icons.gd`
  (`assets/ui/items/<id>.png`), each from the same model that lies on the ground
  when it drops (`Art.item_model`): a weapon's or shield's own, or for armor the
  pieces of its class's kit (and, where a piece is only painted on the body, that
  part of the body's surface: `assets/shaders/hero_body.gdshader`, which also
  draws the hero's skin wherever he wears nothing; none is shown under a
  robe). `tools/preview_gear.gd` renders a hero in any equipment, front and
  back (`--pan` frames one figure close up).
- The Robe of the Lost Emperor's dragon is painted by `tools/paint_dragon.py`
  (python3, numpy and Pillow) into `assets/textures/emperor_dragon.png`: the
  robe unrolled round the body (metres round from the middle of the back, and
  up), R the gold's cover, G the threads' height, B their tone, imported
  lossless. `cloak.gdshader` (`gilded`, `dragon_map`) lays it on the robe's
  rest pose and takes the thread's relief from its heights. The wizard wears his
  cut body (`WizardBody`) whenever a robe is on, whatever hat or shoes he has:
  the whole body's shoulders stood out through the robe.
- The Marathon Boots (`tools/make_shoes.py`, Blender) are one voxel-remeshed
  boot cut at the ankle: the foot and its sole hang from the foot bone, the
  shaft, straps, buckles and wing (parts named `...Calf`) from the shin bone,
  so it bends there; the foot is sunk a hair under the shaft where they lap, so
  no step shows. Their gilded leather is `assets/shaders/gilt_leather.gdshader`
  (`Art.gilt_leather`): the photographed leather's grain through uneven gilt,
  creases at the ankle and over the toes, seams with stitching (welt, toe cap,
  quarters, back, under the cuff) and the gilt rubbed through to brown hide on
  the toe, heel and edges. The wing is five primaries and four secondaries under
  a row of coverts, in a small riveted gilt bracket ("Metal"); the feathers are
  `assets/shaders/feather.gdshader`, their outline the mesh's own (tapered,
  round-tipped), off-white to warm grey-cream with a gilt tint at the root, the
  barbs blurred out far off, each feather's seed in its second UVs. Under the wizard's robe the wings are hidden.
- The hero's walk (the R key) is the animation library's `Walk_Loop`, retargeted as
  the clip `Walk` by `tools/import_walk.py`. The walks that carry a weapon
  (SwordWalk, RangerWalk, WizardWalk) are made from it when the figure is set up
  (`Visual.derive_walks`): the walk's stride, with each arm held most of the way to
  where the matching stance holds it, so the sword stays low, the bow at his side
  and the staff in his hand.
- Quaternius Stylized Nature MegaKit [Standard]: rocks, dead tree, grass, fern and
  pebble geometry. The pebble is reused with jewel materials for gem drops.

The character export is `assets/models/character/warrior.glb`. Character and
animation licenses sit beside it. Rebuild with Blender:

```sh
.tools/Blender.app/Contents/MacOS/Blender --background --python tools/import_character.py
.tools/Blender.app/Contents/MacOS/Blender --background --python tools/import_combat.py
.tools/Blender.app/Contents/MacOS/Blender --background --python tools/import_walk.py
.tools/Blender.app/Contents/MacOS/Blender --background --python tools/import_skills.py
.tools/Blender.app/Contents/MacOS/Blender --background --python tools/import_ranger.py
.tools/Blender.app/Contents/MacOS/Blender --background --python tools/import_heavy.py
.tools/Blender.app/Contents/MacOS/Blender --background --python tools/import_pike.py
.tools/Blender.app/Contents/MacOS/Blender --background --python tools/import_wizard.py
.tools/Blender.app/Contents/MacOS/Blender --background --python tools/prepare_guardian.py
.tools/Blender.app/Contents/MacOS/Blender --background --python tools/make_townsfolk.py
.tools/Blender.app/Contents/MacOS/Blender --background --python tools/make_bandits.py
.tools/Blender.app/Contents/MacOS/Blender --background --python tools/make_bedroll.py
.tools/Blender.app/Contents/MacOS/Blender --background --python tools/make_throne.py
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
sword the size of the hero's, in statue stone, and a tall curved scutum
(`assets/models/props/scutum.glb`, built by `tools/make_scutum.py`: a board bent
round the bearer with rounded corners, a rolled rim, two bars, a rib down its
length and a domed iron boss on a flange over a hand grip, where the guards'
shield shader paints them; it replaced the KayKit Adventurers `shield_square`), held upright in
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
# (After tools/paint_kits.py: the gate guards, from the finished hero.)
.tools/Blender.app/Contents/MacOS/Blender --background --python tools/make_guard.py
.tools/Blender.app/Contents/MacOS/Blender --background --python tools/make_spear.py
.tools/Blender.app/Contents/MacOS/Blender --background --python tools/make_staffs.py
.tools/Blender.app/Contents/MacOS/Blender --background --python tools/make_scutum.py
.tools/Blender.app/Contents/MacOS/Blender --background --python tools/make_greatsword.py
python3 -I tools/prepare_materials.py   # the photographed material arrays
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
   No longer used (2026-10-14): the terraces and summit now look down on real
   ground (`scripts/temple_desert.gd`), three storeys below, in the outdoor
   sand shader and strewn with the desert's own scanned grass, stones, shrubs,
   agaves, boulders and dead trees by moonlight. Formerly the
   fourth- and fifth-floor backdrop, edited from image 7 with the built-in
   imagegen tool. The viewpoint looks more steeply down from roughly four or five
   stories above nearby dunes and ruins. Larger foreground stones, column tops
   and exposed foundations establish the height, with the distant horizon at
   the top edge. It retains dark moonlight, runtime tint, terrace-only visibility
   and the existing dim light on terrace paving and parapets.

   Final prompt:
   > Use case: stylized-concept. Asset type: edited landscape background matte for a game. Input image 1 is the edit target: the existing dark moonlit desert with ancient ruins. Change the viewpoint and perspective: look downward from the fourth or fifth floor of a building, approximately 15 metres above the nearby desert floor, with a distinctly steeper downward camera angle. Bring the desert much closer to the viewer: nearby dunes, scattered rocks, ruined stone foundations and a few weathered columns should be larger, with clearly visible top surfaces below us. It must feel like looking down from an upper-story terrace at ground nearby, rather than looking straight out across a distant valley. Frame the ground across almost the entire image; push the distant mountain horizon into the uppermost 8 percent with only a very narrow sky strip, allowing the moon to be outside the frame. Preserve the same ancient desert setting, winding river farther back to the right, scattered colonnade ruins, restrained painterly realism, and very dark navy-charcoal and sand-brown palette. Preserve dim cool silver-blue moonlight along dunes and stone edges; no daylight or bright illumination. Keep a convincing natural transition from nearby ground at the bottom to distant mountains at the top. No foreground balcony, railing, building facade, people, interface, text, border or watermark. Landscape 3:2.

9. `assets/textures/desert_sky_only.png`
   The outdoor opening's sky-only night image, edited with the built-in imagegen
   tool from `desert_opening_sky_v2.png`: sparse pinpoint stars and one cratered
   moon, with all sand and land removed. The northern sector retains the sharp
   native texture detail. Actual 3D sand dunes, built by `scripts/world_horizon.gd`
   as one continuous surface from the flat town ground into distant rolling
   hills, form the horizon in the game's own lighting. One shared material and
   paint map avoid a texture seam. The sky image also supplies night
   reflections. Earlier versions are retained. Full prompts and geometry notes:
   [OPENING_SKY.md](OPENING_SKY.md).

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
Cloth and leather are procedural, with photographed detail over them (below).
Statue materials use generated marble; architecture uses generated
limestone and marble. Original source-pack materials remain on selected small
props and vegetation. The bronze tile is also available as a reusable material.

## Detail pass: photographed materials and reflections

On 2026-10-11 the figures, their kit and their weapons were given real
material detail and something to reflect (the user asked for them to be
"significantly more detailed and realistic looking", Diablo 4 the reference).

- **The material library.** `tools/prepare_materials.py` (plain python3 with
  numpy and Pillow) cuts CC0 photo scans into tiling 1024 px maps: brushed and
  scratched steel, rusting iron, old bronze, gold (ambientCG Metal009, Metal038,
  Metal056C, Metal017, Metal048C), three leathers (Leather037, Leather014,
  Leather033A), woven wool and coarse cloth (Fabric031, Fabric030), velvet, satin,
  ash and walnut (Poly Haven velour_velvet, crepe_satin, ash_veneer,
  american_walnut_veneer), the linen and hessian the townspeople already wore,
  and skin, which has no scan: its pores and its net of fine creases are drawn
  by the script. Each is a colour map (its mean brightness middle grey), a
  normal map and a data map (roughness, cavity, height), and the three kinds
  are packed into texture arrays, one material a layer
  (`assets/textures/materials/detail_col.jpg`, `detail_nrm.jpg`, `detail_dat.jpg`,
  4 by 5 layers, S3TC: this Mac's OpenGL has no BPTC). They are global shader
  uniforms (`project.godot` `[shader_globals]`), so a shader reads every
  material through three texture units. Downloads are in `source_art/materials/`.
- **Laying it on.** `assets/shaders/detail.gdshaderinc` lays a material on a
  piece from three sides at once in the piece's own space (a skinned figure's
  rest pose, `Art.rest_pose_mesh`; a weapon's model space in metres), so its
  grain keeps one size, runs on across UV seams and stays on the piece as it
  moves; `_up` variants turn the pictures so wood grain and brushing run along
  a haft or blade. The relief is carried onto the posed piece through the
  surface's frame found from the same step across the screen in both spaces
  (`detail_normal`; an earlier form with a matrix inverse hung this Intel GPU).
  Garments unwrapped in metres read it through their UVs instead (`mat_*_uv`).
  `edge_wear` brightens metal and chips stone where the surface turns sharply.
- **Skin** is lit as skin (`lit()` in the include, used as `light()` by
  `hero_body.gdshader` and `townsfolk_skin.gdshader`): the shadow's edge wrapped
  softer in red than in blue (light scattered under the skin), a broad second
  sheen, a faint glow through thin parts against the light; the townspeople's
  and bandits' bodies now carry their own normal maps (the male body's, and the
  female one from the base pack: `assets/textures/skin_woman_normal.png`).
- **The heroes.** `tools/paint_kits.py` also writes `hero_kit_<class>_mat.png`,
  what each texel of the kit is made of (red leather, green cloth, blue metal;
  told by the finish it is painted with), so the body shader lays leather,
  wool or steel over it; its steel is painted brighter and its scales no longer
  carry their light in their colour. `Art.hero_kit` is now that shader too (it
  was a StandardMaterial3D), on every hero mesh with its rest pose. The kit maps
  have mipmaps. `tools/outfit_hero.py` subdivides the hanging cloth once
  (`RangerCloak`, `WizardRobe`, `WizardRobeSkirt`, `WizardHood`, `HeroKilt`), so
  hoods, cloak and robe curve instead of breaking into facets, and now re-seats
  the clips' strips as `import_pike.py` does, so a run no longer exports every
  clip a frame late.
- **Cloth.** The cloak and robe wear photographed wool, their folds shaded
  deeper and their inside darker (burley light: the wrap lighting they had
  flattened them). Which side of the cloth is seen, and which way its normal
  faces, is found from the surface itself (`cloak.gdshader`: the face toward
  the eye, then whether that side faces out from the body at rest), not from
  the winding: the ranger's cloak below the waist and the wizard's skirt are
  wound inside out, which drew their whole lower half as the cloth's dark
  inside, and on the Intel Macs the engine's own flip for a two-sided face
  turns the side facing the eye away from it. The townspeople's and bandits' garments hang in folds
  (`cloth.gdshaderinc` `drape`, deeper toward the hem) and carry the weave's relief.
- **Metal and wood.** Plate, helmets, guards' armour, shields, swords, axes,
  hammers, spears, staffs, quivers and sheaths are full metal now (they were
  held at half metal because there was nothing to reflect), with scanned
  scratches, grime in their hollows and bright worn edges; wood, leather grips
  and bows wear the scanned grain.
- **Reflections.** `scripts/reflections.gd` gives every scene's environment a
  sky to reflect (`assets/shaders/reflection_sky.gdshader`) while it keeps its
  own background and ambient light: Poly Haven's Goegap HDRI (Namaqualand, as
  the rocks) for the desert, tinted, dimmed and desaturated through the day and
  giving way to the painted night sky (`Reflections.daylight`, called from
  `Overworld.set_time`, redrawn only when it changes enough to see); the
  sandstone Historic Cloister Passage HDRI, dim and warm, in the halls; the
  desert, softly, for previews, icons and the inventory's figure.
- **Statues** keep their stone, with chipped, paler edges and sand-coloured dust
  on whatever faces up.
- `tools/preview_cast.gd` renders the cast side by side (heroes, bandits,
  statues, a guard, townspeople) by day or by torchlight, straight on or from
  the game's angle; `tools/preview_world.gd` photographs the game itself (the
  street by day and night, close and at the game's zoom, the basement) and
  prints the frame rate. On this workstation (Intel Iris Plus) the pass cost
  about 3% of the frame rate.

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
instead of falling over, the statue crumbles as in the original game. The body
collapses and disappears over 0.7 s, leaving thirty-six stone fragments (the imported
rock mesh in statue stone), each a rigid body with a convex collision hull. There
is no static rubble pile. They tumble, bounce against the paving and architecture, and settle
with friction. Normal attacks push them away from the hit; Thundering Strike and Leap
throw them farther outward and upward. The body collapse and dust follow the combat
clock; the chips use Godot's physics clock, pause with the world, and expire after
eight seconds. Collision slabs and prop hulls are built when the first statue falls.

`assets/audio/fire-whoosh.mp3` is ZapSplat's "fire whoosh, fast burst, flames"
(zapsplat_sound_design_fire_whoosh_fast_burst_flames_112136.mp3, from its fire
whooshes pack), unedited: a 3.8 s burst of flame with a burning tail. It plays as
the Oracle's fireball leaves its staff and as the wizard casts Firebolt. It is
credited to www.zapsplat.com under ZapSplat's license, like the other effects.
While it is heard, a few small arcs of electricity jump about the spot it struck
(`scripts/crackle.gd`), thinning out and dying with the sound's fade.

`assets/audio/arrow-stone-impact.mp3` is the original Temple Ascension's sound of
an arrow striking stone, copied unchanged from it. As there, it plays when one of
the hero's arrows hits a statue, at the same level as `weapon-impact.mp3`.

`assets/audio/sword-hit-flesh.wav` is a blade striking flesh, a recording supplied
by the user (`source_art/audio/bandit-sword-hit.mp3`), cut by `tools/make_sounds.py`
to its slash and blow (the silence before and after taken away), given a little
more weight (the blow brought up as it lands and its very peaks saturated, the
blow about 6 dB louder than recorded and the whole about 6 dB louder) and faded out at its end: it plays whenever a bandit is hit by anything but one of the hero's
arrows (blades, skills, spells, splash alike), each time at a pitch up to 12%
higher or lower and up to 2 dB louder or softer (`scripts/audio.gd` VARIED), so
that it never sounds the same twice running. `assets/audio/arrow-flesh-1.wav` to
`arrow-flesh-3.wav` are the three arrow hits of a recording supplied by the user
(`source_art/audio/arrow-hits.mp3`), cut apart at the silences between them by
`tools/make_sounds.py` and each faded out at its end; one of them, by chance,
plays when one of the hero's arrows hits a bandit. Both play at the level of
`weapon-impact.mp3`, which is heard only on statues now; a bandit's fall adds no
second impact to the blow that killed him.

`assets/audio/rock-impact.mp3` is PMSFX's "Rock Crash, Designed Rock Impact Crash,
Big Cinematic" (PMSFX_ROCKCrsh_Designed_Rock_Impact_Carsh_Big_Cinematic_41RI2_2442.mp3),
unedited, supplied by the user: a 0.9 s crash of breaking rock. It plays as Thundering Strike's
and Shockwave's blows meet the ground. Its licence follows the user's PMSFX terms.

`assets/audio/lightning-zap.wav` is a ZapSplat electric crackle supplied by the
user (`source_art/audio/electric.m4a`, 2.19 s), decoded by `tools/make_sounds.py`
with macOS `afconvert` to 48 kHz stereo 16-bit PCM, brought up to a 0.89 peak and
faded out over its last 0.6 s rather than stopping short. It plays once as each
Lightning Shot strikes, however many enemies it hits. It is credited to
www.zapsplat.com under ZapSplat's license, like the other effects.

`assets/audio/power-whoosh.wav` is synthesised by `tools/make_sounds.py` (noise,
tones and filters; no recording) and is original to this project: the deep punch
of Power Shot striking, a quick rush of air swelling into it that stops with the
blow. The same punch is heard with every shockwave the warrior drives into the
ground (Thundering Strike, Shockwave and Leap's landing), over its crash of rock or
impact.

`assets/audio/fountain-trickle.wav` is the original game's
`public/sfx-fountain-trickle.m4a`, decoded without normalization or editing to
48 kHz stereo 16-bit PCM. macOS `afconvert` performed the decode; its extensible
WAV header was rewritten as standard PCM for Godot, preserving the decoded
samples. The full 14.294-second recording loops continuously. Gain follows the
original `LevelScene.updateFountainAmbience`: zero outside the court, otherwise
`clamp(1 - distance_to_fountain / half_room_diagonal, 0, 1)`. It uses the player's
ground position rather than the camera, respects the sound toggle, is silent
during pause, and stops when the floor is unloaded.

`assets/audio/smith-hammer-1.wav` to `smith-hammer-4.wav` and `smith-grind.wav` are
synthesised by `tools/make_sounds.py` (`python3 tools/make_sounds.py smith`: noise,
tones and filters, no recording) and are original to this project. The four blows
are Orion's hammer striking the sword on the anvil, each one short dead clank
rather than a ringing note: a hard crack of steel on steel, a dense cluster of
steel's inharmonic partials damped within a few hundredths of a second (the blade
on the face and the hammer on the blade stop each other ringing), the hammer's
weight thudding into the anvil, in a very short tail of the small stone room. One
of them, by chance, at a pitch up to 4% higher or lower, plays each time the hammer
meets the blade. The grinding is the blade's edge on the turning grindstone: steel hissing on
the stone, the grit's crackle, the blade singing faintly, the wheel's rumble and the
knock of its axle once a turn; it loops seamlessly (imported looping), louder as he
draws the blade across and with the wheel's speed. Both come from where the work is
(`AudioStreamPlayer3D`, panned by where that lies from the camera) and, like the
are as loud as the hero is near: full within 3 m, 6 dB quieter each time the
distance doubles, and heard only while the hero is inside the smithy
(`scripts/smith.gd`).

## HUD

`assets/ui/weapon-*.png` are transparent renders of the existing imported spear,
sword, bow and axe meshes, baked with `tools/render_weapon_icons.gd`. They retain
the source models' licensing. The liquid orb shader in `assets/shaders/orb.gdshader`
adapts the original game's code-drawn circular HUD treatment, with glass highlights,
a bronze rim and a level that follows current health/energy. No new world meshes
are created for the UI.
