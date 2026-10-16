# HUD artwork options

Created 2026-10-16 with the built-in imagegen tool. Each new source asset is a 2172 × 724 RGBA PNG with transparent gauge holes and background. The four complete frames are used directly; they have no baked resource fills, numbers, labels or skill icons.

| Debug choice | Source asset | Treatment |
| --- | --- | --- |
| Current · Classic | Existing HUD, no new frame | Original compact bronze-rimmed circles and skill tiles |
| Imperial Bronze | [imperial_bronze.png](../assets/ui/hud/imperial_bronze.png) | Aged bronze, gold laurel and incised meander |
| Sandstone Shrine | [sandstone_shrine.png](../assets/ui/hud/sandstone_shrine.png) | Weathered stone, fluting and gold inlay |
| Obsidian Oracle | [obsidian_oracle.png](../assets/ui/hud/obsidian_oracle.png) | Black stone, silver crescents and dim teal insets |
| Crimson Legion | [crimson_legion.png](../assets/ui/hud/crimson_legion.png) | Leather bindings, iron plates, bronze rivets and burgundy cloth |

## Select and compare

Launch Debug Mode, show the debug panel with P if needed, and use its HUD artwork dropdown. F4 cycles forward; Shift+F4 cycles backward, including while paused or while the panel is hidden. The five choices wrap. Selection is kept in the debug directory's settings.cfg as hud_art; it does not modify a run or normal settings. Normal mode retains Current · Classic. Unknown saved choices fall back to Classic.

## Integration

The frame is a mouse-ignoring TextureRect behind the existing HUD controls. Every option keeps the same health and energy ColorRects and their circular liquid-fill shader, the same six live skill buttons, their hotkeys, cooldown labels, and the dash/heal widgets. The wizard retains blue mana; other classes retain green energy; health remains red. Style swaps preserve all resource values and game state.

The registry is scripts/hud_art.gd. It records the measured transparent hole centres and opaque bounds of each generated asset, plus the palette. Frames display at 600 pixels wide; the circular gauges retain their original 112-pixel displayed diameter and are aligned with the art's openings. The six skills remain bottom-centred; utility tiles flank the new central carving. Gauge bezels, hotbar borders and key labels use a matching palette. Classic restores the original layout, colours, spacing and absence of a backplate. Source images use lossless import, generated mipmaps and bilinear mip filtering for clean downsampling. The debug action list scrolls to keep the selector visible on smaller windows.

## Validation and captures

Run tests/hud_art.gd headlessly both normally and with -- --debug-mode. It checks default and invalid settings, all five selections, original control identity, live resource fills at 0/50/100%, mana/energy labels, preserved cooldowns, real mouse clicks, bottom-centre placement at 1120×700, 1280×720 and 1440×900, input gating, backward/forward wrap, hidden-panel and paused switching, and saved selection after relaunch.

For native captures, run:

```sh
.tools/Godot.app/Contents/MacOS/Godot --path . --script tests/hud_art.gd -- --debug-mode --render-hud-art
```

The five screenshots are written to test-results/hud-art-<style-id>.png. Tests use isolated saves.

## Exact generation prompts

### Imperial Bronze

Use case: stylized-concept
Asset type: production-ready transparent PNG ornamental HUD frame/backplate for a realistic ancient Roman desert-temple action RPG. This is the actual interface artwork, not a screenshot or a concept sheet.
Canvas: exactly 3:1 wide landscape, ideally 1800x600 or higher. Transparent background with genuine alpha. Single compact symmetrical horizontal HUD chassis in the bottom two-thirds of the canvas. Leave uppermost 25% empty and transparent. Entire silhouette fits inside the image.
Precise layout: two matching circular gauge mounting rings, their centres at 17.1% and 82.9% of image width and 65% of image height. Each ring's outer diameter is 20.7% of canvas width, equivalent to 62% of canvas height. The inner hole is transparent and about 18% of canvas width. The ring circles must be truly round in this 3:1 canvas. A low, narrow connecting skill-bar frame runs between the rings: dark continuous rectangular recessed interior from 29% to 71% of width, 55% to 75% of height, surrounded by handsome carved trim. Keep that entire inner rectangle clear so six live skill buttons can be drawn over it. No individual icons, squares or dividers inside it. A small central ornament may hang below the skill bar near 87% of image height, leaving room for live utility buttons above it.
Functional constraints: artwork only. NO painted health liquid, no red or green or blue gauge fill, no numbers, no lettering, no text, no runes resembling words, no labels, no skill icons, no characters, no game scene, no filled background, no border around the canvas. Gauge holes and space outside the chassis must remain transparent. Readable strong silhouette, restrained ornament, crisp details that survive display at 600x200 pixels. Front-facing orthographic UI illustration, no perspective or camera tilt. Rich realistic handcrafted materials, believable wear, polished game-interface rendering.

Theme: IMPERIAL BRONZE. Dark aged bronze and warm antique gold, elegant sculpted Roman laurel wreaths curling around the outside of both orb rings, acanthus leaves, a subtle Greek meander incised into the skill-bar trim, tiny turquoise patina in deep recesses, dark warm bronze inner surfaces. Regal and balanced, a restrained small imperial palmette at the lower centre. Broad sculptural gold trim with tactile bevels, deep shadows and clear highlights.

### Sandstone Shrine

Use case: stylized-concept
Asset type: production-ready transparent PNG ornamental HUD frame/backplate for a realistic ancient Roman desert-temple action RPG. This is the actual interface artwork, not a screenshot or a concept sheet.
Canvas: exactly 3:1 wide landscape, ideally 1800x600 or higher. Transparent background with genuine alpha. Single compact symmetrical horizontal HUD chassis in the bottom two-thirds of the canvas. Leave uppermost 25% empty and transparent. Entire silhouette fits inside the image.
Precise layout: two matching circular gauge mounting rings, their centres at 17.1% and 82.9% of image width and 65% of image height. Each ring's outer diameter is 20.7% of canvas width, equivalent to 62% of canvas height. The inner hole is transparent and about 18% of canvas width. The ring circles must be truly round in this 3:1 canvas. A low, narrow connecting skill-bar frame runs between the rings: dark continuous rectangular recessed interior from 29% to 71% of width, 55% to 75% of height, surrounded by handsome carved trim. Keep that entire inner rectangle clear so six live skill buttons can be drawn over it. No individual icons, squares or dividers inside it. A small central ornament may hang below the skill bar near 87% of image height, leaving room for live utility buttons above it.
Functional constraints: artwork only. NO painted health liquid, no red or green or blue gauge fill, no numbers, no lettering, no text, no runes resembling words, no labels, no skill icons, no characters, no game scene, no filled background, no border around the canvas. Gauge holes and space outside the chassis must remain transparent. Readable strong silhouette, restrained ornament, crisp details that survive display at 600x200 pixels. Front-facing orthographic UI illustration, no perspective or camera tilt. Rich realistic handcrafted materials, believable wear, polished game-interface rendering.

Theme: SANDSTONE SHRINE. Pale weathered ivory limestone and warm desert sandstone carved into low classical temple mouldings. The orb rings are ancient stone torus mouldings with subtle chips, fluted fragments and shallow palmette relief. The skill-bar surround resembles a narrow temple architrave with restrained old-gold inlay and a charcoal inset. Muted honey-sand shading, believable fine stone grain, noble and architectural. Low squared masonry shoulders and clean generous shapes. No giant columns, no tall temple roof.
Input image 1 is a composition reference. Preserve its exact canvas proportions, two circular hole centres, hole sizes, and central skill-bar recess position. Completely redesign its materials and ornament in the SANDSTONE SHRINE theme: replace the bronze laurel foliage with carved stone fluting, low architectural volutes and palmettes. Keep the upper empty space and transparent gauge holes. No text.

### Obsidian Oracle

Use case: stylized-concept
Asset type: production-ready transparent PNG ornamental HUD frame/backplate for a realistic ancient Roman desert-temple action RPG. This is the actual interface artwork, not a screenshot or a concept sheet.
Canvas: exactly 3:1 wide landscape, ideally 1800x600 or higher. Transparent background with genuine alpha. Single compact symmetrical horizontal HUD chassis in the bottom two-thirds of the canvas. Leave uppermost 25% empty and transparent. Entire silhouette fits inside the image.
Precise layout: two matching circular gauge mounting rings, their centres at 17.1% and 82.9% of image width and 65% of image height. Each ring's outer diameter is 20.7% of canvas width, equivalent to 62% of canvas height. The inner hole is transparent and about 18% of canvas width. The ring circles must be truly round in this 3:1 canvas. A low, narrow connecting skill-bar frame runs between the rings: dark continuous rectangular recessed interior from 29% to 71% of width, 55% to 75% of height, surrounded by handsome carved trim. Keep that entire inner rectangle clear so six live skill buttons can be drawn over it. No individual icons, squares or dividers inside it. A small central ornament may hang below the skill bar near 87% of image height, leaving room for live utility buttons above it.
Functional constraints: artwork only. NO painted health liquid, no red or green or blue gauge fill, no numbers, no lettering, no text, no runes resembling words, no labels, no skill icons, no characters, no game scene, no filled background, no border around the canvas. Gauge holes and space outside the chassis must remain transparent. Readable strong silhouette, restrained ornament, crisp details that survive display at 600x200 pixels. Front-facing orthographic UI illustration, no perspective or camera tilt. Rich realistic handcrafted materials, believable wear, polished game-interface rendering.

Theme: OBSIDIAN ORACLE. Smooth charcoal-black obsidian and dark basalt with slender worn silver edges. Clean tapered shapes, crescent and radial star engravings, very restrained dim teal seams set inside the stone, tiny silver studs and a small downward silver crescent at the lower centre. The orb mounts have layered black stone and brushed silver bezels. Long elegant angular connecting rails with a dark blue-black recessed centre. Mystical, austere, precise and dark; no bright neon, no futuristic technology.
Input image 1 is a composition reference. Preserve its exact canvas proportions, two circular hole centres, hole sizes, and central skill-bar recess position. Completely replace the bronze floral ornament with angular black-stone crescent bezels, restrained silver radial marks and small faceted teal insets. Make the silhouette and trim distinctly austere and oracular. Keep genuine transparency outside the artwork and in the gauge holes. No text.

### Crimson Legion

Use case: stylized-concept
Asset type: production-ready transparent PNG ornamental HUD frame/backplate for a realistic ancient Roman desert-temple action RPG. This is the actual interface artwork, not a screenshot or a concept sheet.
Canvas: exactly 3:1 wide landscape, ideally 1800x600 or higher. Transparent background with genuine alpha. Single compact symmetrical horizontal HUD chassis in the bottom two-thirds of the canvas. Leave uppermost 25% empty and transparent. Entire silhouette fits inside the image.
Precise layout: two matching circular gauge mounting rings, their centres at 17.1% and 82.9% of image width and 65% of image height. Each ring's outer diameter is 20.7% of canvas width, equivalent to 62% of canvas height. The inner hole is transparent and about 18% of canvas width. The ring circles must be truly round in this 3:1 canvas. A low, narrow connecting skill-bar frame runs between the rings: dark continuous rectangular recessed interior from 29% to 71% of width, 55% to 75% of height, surrounded by handsome carved trim. Keep that entire inner rectangle clear so six live skill buttons can be drawn over it. No individual icons, squares or dividers inside it. A small central ornament may hang below the skill bar near 87% of image height, leaving room for live utility buttons above it.
Functional constraints: artwork only. NO painted health liquid, no red or green or blue gauge fill, no numbers, no lettering, no text, no runes resembling words, no labels, no skill icons, no characters, no game scene, no filled background, no border around the canvas. Gauge holes and space outside the chassis must remain transparent. Readable strong silhouette, restrained ornament, crisp details that survive display at 600x200 pixels. Front-facing orthographic UI illustration, no perspective or camera tilt. Rich realistic handcrafted materials, believable wear, polished game-interface rendering.

Theme: CRIMSON LEGION. Burnished dark iron and aged bronze reinforced by rich oxblood leather, stitched straps and small bronze rivets, recalling a Roman legionary's shield and sword belt. Orb mounts formed from sturdy overlapping metal plates with restrained leather bindings. The narrow skill-bar surround is a practical dark leather and iron belt plate with bronze corner guards and embossed laurel details. A short burgundy cloth fold beneath the centre, modest and compact. Rugged and martial, tactile worn leather, strong readable trim; no skulls, no spikes, no modern buckles.
Input image 1 is a composition reference. Preserve its exact canvas proportions, two circular hole centres, hole sizes, and central skill-bar recess position. Completely replace the golden foliage with stitched burgundy leather bindings, iron shield plates, small aged-bronze corner guards and rivets. A distinctly martial leather-and-iron silhouette, modest dark red cloth folds under the centre. Retain transparent gauge holes and transparent space outside the frame. No text.
