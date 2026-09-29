# Asset provenance and generation

No visible game object is built from Godot primitive meshes, CSG, surface tools,
or scripted Blender primitives. `tools/prepare_models.py` imports and normalizes
existing meshes. `scripts/layout.gd` adapts the original room-and-corridor generator;
`scripts/temple.gd` places those authored modules on its tile layout and constructs
only navigation/collision data. Each floor's ascent reuses the imported stairs mesh,
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

The Oracle's fire spell is a lobbed fireball (`scripts/fireball.gd`). A camera-facing
card drawn by `assets/shaders/fireball.gdshader` renders procedural, flowing fire; an
ember trail and a travelling light follow it. On impact it swells into an explosion
that cools from white-hot through orange and red into smoke, with sparks, a light
flash, a ground shockwave from the existing seal VFX and a fading scorch mark. Damage
lands on impact. The Oracle casts it for two seconds, shown by an amber cast bar over
its head, and the ground warning lasts through the cast and the flight. It adds no
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
`guardian_centurion.glb` and `guardian_wizard.glb`, each retaining all 30 clips.
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
