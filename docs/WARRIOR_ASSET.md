# Warrior asset

Original stylized Mediterranean warrior, authored locally in Blender 4.5.3 LTS
and imported into Godot as a GLB. This is an actual UV-mapped, skinned 3D mesh,
not a billboard or a rendered character picture.

## Files

- `assets/warrior/warrior.glb`: one skinned mesh, eight material surfaces, one
  embedded texture, 19 joints, and six animation clips.
- `assets/warrior/warrior_atlas.png`: generated base-color texture atlas.
- `source_art/warrior.blend`: editable geometry, UVs, named vertex groups,
  armature, animation actions and NLA tracks, with the image packed into the file.
- `tools/create_warrior.py`: reproducible modeling, rigging, UV, and export script.
- `scripts/warrior_visual.gd`: Godot presentation adapter.

The source mesh has 10,892 vertices and 8,817 polygons before glTF triangulation
and attribute splitting. The model uses blended joint weights on the limbs and
cape, and rigid weighting on hard armor. Its six clips are Idle, Run, Attack,
Cleave, Evade, and Death. Combat timing remains in `actor.gd`; presentation
adapts clip speed to it. Movement remains controlled by game physics.

Visual design: sculpted bronze cuirass, open-faced crested helmet, leather
pteruges, bracers, greaves, teal tunic/cape, a steel xiphos, and a sun-emblem
hoplite shield. This is an initial game model with stylized anatomy, not a
photorealistic final art pass. Additional equipment variants can use the rig.

## Texture provenance and prompt

Texture generated with the **built-in imagegen tool**. No third-party model or
texture pack was used. The selected PNG was copied into the project. The 3D mesh
and animations were authored through Blender; image generation only produced
the material atlas.

Prompt:

> Create a production game character BASE COLOR TEXTURE ATLAS, 2048x1024
> landscape, exactly FOUR equal columns and TWO equal rows (8 rectangular
> material tiles), flush edge-to-edge, with no gutters, no borders, no text,
> no labels. This is a flat unlit 2D material texture sheet that will be UV mapped
> onto a 3D ancient Mediterranean warrior, NOT a character illustration and NOT
> a rendered sphere. Top row, left to right: 1 weathered warm bronze metal with
> subtle hammered texture and fine scratches, no large shapes; 2 rich dark teal
> woven linen with subtle small scale fiber texture; 3 dark brown worn leather
> with fine leather grain and subtle scuffs; 4 warm medium tan skin with subtle
> natural pore texture, uniform and unobtrusive, no facial features. Bottom row
> left to right: 1 brushed cool steel silver gray, small scratches; 2 warm ivory
> pale gold material with subtle ancient engraved meander ornament along
> horizontal bands; 3 dark crimson horsehair fabric with fine vertical strands
> for a helmet crest; 4 circular bronze Greek hoplite shield face centered
> precisely inside that tile, a simple embossed eight-point sun with teal enamel
> accents and a bronze concentric rim, readable from a distant overhead camera.
> Material color only, flat even neutral illumination with NO cast shadows, NO
> directional lighting, NO perspective, NO objects floating on a background.
> Rich restrained colors, high quality stylized realistic game materials. Every
> tile fills its entire exact quarter-width and half-height region. Texture
> atlas only.

## Rebuild

```sh
.tools/Blender.app/Contents/MacOS/Blender --background --python tools/create_warrior.py
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --editor --import --quit
sh tools/test.sh
sh tools/build.sh
```

The script rebuilds both the Blender source and GLB from the committed PNG;
it does not call an image-generation service again. Edit the script for
reproducible changes, or edit the Blender source manually and export a GLB.
Do not rerun the script over manual Blender edits you want to keep.

Blender coordinates are Z-up / -Y-forward. glTF converts to Y-up, and the Godot
visual adapter turns the asset 180 degrees to match the game's -Z-forward actors.
The source's NLA tracks are muted for easy rest-pose editing; unmute one to
preview it. The exporter enables and exports each named track separately.
