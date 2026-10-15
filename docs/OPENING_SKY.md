# Opening desert sky

Active asset: `assets/textures/desert_sky_only.png` (1774 × 887, RGB PNG).

Created on 2026-10-14 with the built-in imagegen tool by editing `desert_opening_sky_v2.png`. The active image contains only sky, sparse pinpoint stars and one cratered moon. All sand and terrain have been removed. Earlier landscape images remain as legacy assets.

The outdoor sky and its night reflections use this image. The shader devotes its full width to a 90-degree northern sector and its height to 45 degrees, preserving the previous revision's angular detail. It samples native texture level zero with bilinear filtering. A wider mapping supplies the rest of the sky, blended outside the opening view. The wider mapping's moon is covered by the detailed northern sector, avoiding a duplicate moon.

`scripts/world_horizon.gd` builds one continuous ground mesh from town to the horizon. Its flat interior and outer terrain share welded perimeter vertices and the exact same material, paint map, world-space sand coordinates and lighting. This replaces the overlapping original slab and separate extension, removing their material and shading boundary. Painted ground channels ease into plain sand over the first 48 metres outside the map instead of switching to a blank control texture. The mesh uses 384 angular segments and 64 radial bands. Low foothills grow gradually into broad distant crests around 38 metres high; the flat playable map and a margin beyond its rock rim stay at zero height. The far skirt drops behind the crests so the outer mesh boundary is hidden. The camera's far plane is 3,000 metres, beyond the terrain's complete extent. Playable heights, navigation and collisions are unchanged. `tests/desert_horizon.gd` checks the welded interior, flat map, shared material and paint, gradually increasing relief, far-plane coverage and the geometric skyline from the opening camera.

## Current sky-only edit prompt

Use case: precise-object-edit
Asset type: sky-only background texture for the opening scene of a 3D game.
Input image 1 is the edit target.
Remove ALL sand, desert, dunes, ground, land and every terrain silhouette from the image. Replace the entire lower half with a seamless continuation of the night sky above it. The finished image must contain sky across every pixel, right down to the bottom edge. There must be NO land/sky horizon line, no ground-shaped band and no bottom terrain strip.
Preserve the existing sharp stars, the single cratered gibbous moon, its exact location and apparent size, the smooth deep navy palette, restrained illumination, and the existing composition of the upper sky. Continue that same blue-black sky smoothly into the removed area, with sparse natural small stars. The lower sky may be slightly lighter navy, but no horizontal stripe or glowing atmospheric band.
Maintain optical sharpness and clear fine star points. Opaque 2:1 landscape PNG, highest native resolution available. No mountains, dunes, rocks, clouds shaped like land, buildings, people, vegetation, text, border, interface or watermark.

## Previous sharp landscape prompt

Use case: photorealistic-natural
Asset type: high-resolution night desert background for a realistic 3D game's opening shot.
Generate a fresh, optically sharp image. Wide 2:1 composition, highest native resolution available, preferably 3840x1920. This image represents a 120-degree horizontal by 60-degree vertical view looking north, not a full globe.
A quiet empty sand desert under a deep navy night sky, with scattered small sharp stars and a single small natural gibbous moon. The moon is lightly cratered, crisp and ivory, centred at 60 percent of image width and 36 percent of height, with almost no bloom.
The land meets the sky at approximately 54 percent of the image height. This boundary is extremely clean and in focus. It is mostly level, but has small natural elevation changes: a sequence of broad shallow asymmetrical dune rises and dips, only 0.5 to 1 percent of the full image height from highest crest to lowest dip. The edge must read as a real remote sand desert, neither a geometric straight line nor a mountain range. Make individual low dune crests clearly outlined against the sky.
The entire landscape is sand: no mountains, cliffs, mesas, crags, rocks or jagged peaks anywhere. Low rolling dunes with sharply resolved fine wind ripples fill the lower half, dim silver-blue moonlight along occasional ridges, dark grey-blue shaded faces. Keep dune forms broad and modest.
Sky is smooth and dark with sparse fine pinpoint stars of natural varied brightness. Only a trace of a faint star cloud high above. Clear dry air, no haze at the horizon. No smeared or tangled Milky Way, no painted texture, no noisy grain, no fog, no softness, no depth of field, no motion blur.
Restrained realistic photography and crisp landscape detail. Very dark late-night setting, no sunset colours, no dawn glow. No oversharpening halos. No buildings, people, trees, water, text, interface, border or watermark.

The generated image was selected at native 1774 × 887 resolution. The runtime sector is narrower than the requested 120 × 60 degrees to provide more angular detail and keep the generated moon fully inside the opening camera view.

## Previous generation prompt

Use case: photorealistic-natural
Asset type: production 360-degree equirectangular environment panorama for the opening scene of a realistic ancient desert game.
Primary request: a new moonlit desert night sky that continues all the way down to a believable, irregular desert horizon, with fine stars and one moon.
Composition/projection: true latitude-longitude 2:1 panorama, 360 degrees horizontally and 180 degrees vertically, ideally 3840x1920 or higher. Zenith at the top, geometric horizon exactly at the vertical midpoint, nadir at the bottom. Left and right edges must join seamlessly. Upper half is sky. Lower half is subdued empty sand terrain. Distant low dunes and gently weathered rocky ridgelines rise irregularly only 0–4 degrees above the midpoint; varying heights, overlapping distant layers, asymmetrical wind-shaped silhouettes, never a straight horizontal boundary. Avoid a towering mountain range.
Sky: deep midnight navy, delicate sparse sharp stars at varied brightness, very subtle diffuse star-cloud haze higher overhead. Atmosphere becomes gently smoky slate-blue near the land, but it is still clearly night. Stars remain small pinpoints, no large glowing dots or artificial starbursts.
Moon: one small realistic lightly cratered waning gibbous moon, a softly lit ivory disc with restrained halo, placed at approximately 53 percent of image width and 45.5 percent of image height (low above the horizon in the centre-facing opening view). Moon diameter approximately 0.6 percent of image width; keep it modest and astronomically believable.
Land: layered distant windswept dunes, low rugged eroded ridges, muted grey sand and cool charcoal shadows; dim silver-blue moonlight on occasional crests. Smooth atmospheric depth, details becoming indistinct with distance. Lower half gradually resolves into quiet dark sandy ground, no foreground focal objects.
Style: convincing natural photographic landscape detail, restrained cinematic atmosphere, compatible with weathered stone architecture rendered in a dark 3D game.
Constraints: sky extends continuously down to the dune silhouette, no empty black band, no visible rectangular edge, no hard horizon stripe. No sunset or sunrise glow, no orange light, no buildings, ruins, people, trees, water, text, interface, borders or watermark.

## Previous refinement prompt

Use case: compositing
Asset type: corrected 2:1 equirectangular night desert sky panorama for a 3D game.
Edit target: the generated moonlit desert panorama.
Preserve the existing photoreal desert, restrained navy palette, fine stars, and natural layered dune silhouettes.
Change only the layout/projection: move the land/sky boundary upward so the distant horizon sits exactly at 50 percent of the image height, with the highest distant ridges at 47–49 percent and valleys at 50 percent. Keep the boundary irregular and organic. Fill the lower half with the same dim moonlit desert sand.
Move and shrink the single moon: its centre must be at 53 percent of the image width and 45.5 percent of the image height. Make its diameter only 0.7 percent of the full image width. It should be a small circular cratered gibbous disc just above the land, with a delicate halo. Remove the original moon from its old place. Keep just ONE moon. These placements matter because the game camera shows only a narrow band of the panorama near the horizon.
Keep the sky continuous to the terrain, fine pinpoint stars, and true 360 degree horizontal equirectangular layout with matching left/right edges. No text, labels, ruler marks, buildings, people, water or artificial light. Requested canvas 3840x1920.
