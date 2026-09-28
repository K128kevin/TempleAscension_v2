# Asset provenance and generation

No visible game object is built from Godot primitive meshes, CSG, surface tools,
or scripted Blender primitives. `tools/prepare_models.py` imports and normalizes
existing meshes. `scripts/layout.gd` adapts the original room-and-corridor generator;
`scripts/temple.gd` places those authored modules on its tile layout and constructs
only navigation/collision data. Runtime generation places imported meshes and
does not construct mesh geometry. The third-floor court assembles three decreasing
stone bowls from the imported chalice, with a low column base in the original
fountain obstacle footprint. Paving meshes provide the pool floor and low rim;
the water shader uses thin instances of the same mesh. Spill particles reuse the
imported gem mesh. The generated seal is a transparent VFX sprite,
not a replacement for a 3D environment object.

Torch fixtures retain the imported brazier and torch meshes. The static authored
flame is masked out in `assets/shaders/torch.gdshader` and replaced by a small,
camera-facing VFX sprite. `assets/shaders/torch_flame.gdshader` draws animated
flame tongues, a warm core, soft edges and rising embers procedurally; it requires
no new image asset. `scripts/torch_flame.gd` varies each existing local light
smoothly by at most ten percent, with independent phases and slight warmth
variation. Light range, collision and the nearby-shadow budget are preserved.

Warrior, Ranger and Wizard share the imported hero rig and armor. Starting
equipment distinguishes them: sword/shield, bow, or staff. The shield uses the
existing imported model centered against the left forearm, with its face pointing
outward. This mounting follows idle, movement and attack poses. Staff attacks reuse the Cast
animation. Class projectiles reuse the arrow and gem meshes; traps, defensive
effects and area warnings reuse the transparent seal sprite with distinct colors
and timing. This update adds no externally sourced or generated image assets.

## Requested local assets

Source directory: `/Users/ktabb/Documents/3dAssets/` (read only).

- Quaternius Universal Base Characters [Standard]: `Superhero_Male_FullBody.gltf`
  and `Hair_SimpleParted.gltf`. Used for the hero, every humanoid statue, crowned
  boss, offerings, and ending elders.
- Quaternius Universal Animation Library [Standard]: `UAL1_Standard.glb`.
  Sword Idle, Sprint, Sword Attack, Roll, Death01, Spell Simple Shoot, Punch Cross,
  Crouch Forward and Hit Chest drive ten gameplay slots (Cleave also uses Sword
  Attack). All are retargeted and baked to the supplied base character skeleton.
- Quaternius Universal Animation Library 2 [Standard]: `UAL2_Standard.glb`.
  `Sword_Regular_A` plus its recovery supplies SwordSwing; `Sword_Regular_B`
  plus its recovery supplies SwordSlash. `Sword_Regular_C` supplies AxeWhirl
  and its overhead strike supplies AxeChop. Wind-up, cutting motion and recovery
  are retimed separately for readable swings, then baked onto the character.
- Neither supplied animation library includes archery or spear thrust clips.
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
while retaining the skeleton and all twenty-two clips. The full hero remains unchanged.

`tools/prepare_enemy_outfits.py` fits the KayKit clothing meshes to that existing
Quaternius skeleton, remaps their skin weights, and joins each outfit into one
crowd surface. It exports `guardian_gladiator.glb`, `guardian_archer.glb`,
`guardian_centurion.glb` and `guardian_wizard.glb`, each retaining all 22 clips.
The supplied mage tunic is extended into an ankle-length robe; covered leg
surfaces are omitted to avoid running knees piercing the garment. The helmet
covers the centurion's whole head. Rebuild with:

```sh
.tools/Blender.app/Contents/MacOS/Blender --background --python tools/prepare_enemy_outfits.py
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
Both character exports retain
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
5. `assets/textures/hero_skin.png`
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

The generated atlas uses the original UV layout and is applied to the hero's
body surface. Statue materials use generated marble; architecture uses generated
limestone and marble. Original source-pack materials remain on selected small
props and vegetation. The bronze tile is also available as a reusable material.

## Audio

Audio is retained from the user's original Temple Ascension game. The soundtrack
was generated with Suno according to the original game's credits. The retained
combat sound effects were credited to www.zapsplat.com in that project. This
adaptation does not relicense those tracks or effects as CC0. Relevant attribution
must remain with any public distribution, and the original project's license
terms continue to apply.

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
