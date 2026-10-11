shader_type spatial;
// A hero's body, and the raised pieces painted with it: his class's kit
// (tools/paint_kits.py) where an item is worn, his bare skin where none is.
//
// The kit is painted on the body itself, so taking a piece off cannot hide a
// mesh: the body is divided, by where each part of it stands at rest (arms
// out), into what each equipment slot covers (chest, legs, feet, hands), and
// each is drawn from the kit or from the skin. An item of another make is
// redrawn in its own colour (`tint_*`). `shell` is a raised piece (a cuirass,
// a bracer), all of it one item's. `only` draws a single slot's part and
// nothing else: an item lying on the ground, or pictured in the inventory.
//
// Over the painted kit and the skin lies photographed detail
// (assets/shaders/detail.gdshaderinc): the grain and scuffs of leather, the
// weave of wool and linen, the brushing and scratches of steel (by what the
// kit's `kit_mat` map says each part is made of), and the pores and fine
// creases of skin, which is lit as skin is (light()).
#include "res://assets/shaders/detail.gdshaderinc"
uniform sampler2D kit : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D kit_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D kit_rough : filter_linear_mipmap;
// What the kit is made of: red leather, green cloth, blue metal (none: skin).
uniform sampler2D kit_mat : filter_linear_mipmap;
uniform sampler2D skin : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D skin_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform bool rest_pose = true;
uniform bool shell = false;
// Chest, legs, feet, hands: 1 where nothing is worn.
uniform vec4 bare = vec4(0.0);
uniform vec4 recolor = vec4(0.0);
uniform vec3 tint_chest : source_color = vec3(1.0);
uniform vec3 tint_legs : source_color = vec3(1.0);
uniform vec3 tint_feet : source_color = vec3(1.0);
uniform vec3 tint_hands : source_color = vec3(1.0);
// Where the slots meet, at rest (metres): what is on the feet reaches up to
// `feet_top`; the legs' up to `waist`; the hands' begins `arm_from` out from
// the middle; the head is above `neck`.
uniform float feet_top = 0.16;
uniform float waist = 1.0;
uniform float arm_from = 0.46;
uniform float neck = 1.57;
uniform int only = -1;
// (Pictured alone, what is worn on the chest is cut off at the shoulders,
// and what is worn on the legs at `only_from` up from the ground.)
uniform float only_reach = 0.27;
uniform float only_from = 0.0;
// One of a pair (a single bracer): the side of the body kept, +1 or -1.
uniform float keep_side = 0.0;
// Gloves that cover the whole hand (the Ice Queen's Gloves: scripts/items.gd
// `gloved`), of `tint_hands`, from `glove_from` out (just short of the wrist,
// at rest) to the fingertips, a cuff at their opening.
uniform float gloved = 0.0;
uniform float glove_from = 0.665;
uniform float specular = 0.5;
uniform float kit_metal = 1.0;
// How strongly the photographed detail shows (0: the painted kit alone).
uniform float detail = 1.0;
varying vec3 rest;
varying vec3 rest_normal;
// (Handed to light(): how much of this point is skin, and its specular.)
varying float skin_part;
varying float spec_level;

void vertex() {
	rest = rest_pose ? CUSTOM0.xyz : VERTEX;
	rest_normal = rest_pose ? CUSTOM1.xyz : NORMAL;
}

void fragment() {
	float arm = smoothstep(arm_from - 0.004, arm_from + 0.004, abs(rest.x));
	float low = 1.0 - smoothstep(waist - 0.004, waist + 0.004, rest.y);
	float foot = 1.0 - smoothstep(feet_top - 0.004, feet_top + 0.004, rest.y);
	float head = smoothstep(neck - 0.004, neck + 0.004, rest.y) * (1.0 - step(0.16, abs(rest.x)));
	// How much of this point each slot covers: chest, legs, feet, hands.
	vec4 part = vec4((1.0 - low) * (1.0 - arm) * (1.0 - head), (low - foot) * (1.0 - arm), foot * (1.0 - arm), arm);
	if (shell) part = vec4(1.0, 0.0, 0.0, 0.0);
	if (only >= 0 && (part[only] < 0.5 || (only == 0 && abs(rest.x) > only_reach) || (only == 1 && rest.y < only_from))) discard;
	if (keep_side != 0.0 && rest.x * keep_side < 0.0) discard;
	// (Gloves pictured alone: the hand, without the arm above them.)
	if (only == 3 && gloved > 0.5 && abs(rest.x) < glove_from) discard;
	float off = shell ? 0.0 : clamp(dot(part, bare), 0.0, 1.0);
	vec3 worn = texture(kit, UV).rgb;
	vec3 colour = part.x * tint_chest + part.y * tint_legs + part.z * tint_feet + part.w * tint_hands + (1.0 - min(1.0, part.x + part.y + part.z + part.w)) * vec3(1.0);
	vec3 gloss = texture(kit_rough, UV).rgb;
	vec3 made = texture(kit_mat, UV).rgb;
	// (Only the kit is recoloured, never the skin it leaves bare: the rough
	// map's blue marks where it covers. A raised piece is kit throughout.)
	float redo = clamp(dot(part, recolor), 0.0, 1.0) * (shell ? 1.0 : gloss.b);
	worn = mix(worn, dot(worn, vec3(0.299, 0.587, 0.114)) * colour * 1.8, redo);
	vec3 albedo = mix(worn, texture(skin, UV).rgb, off);
	vec3 macro = mix(texture(kit_normal, UV).rgb, texture(skin_normal, UV).rgb, off);
	float rough = mix(gloss.r, 0.5, off);
	// What this point is: skin where the kit leaves it bare or the slot is
	// empty, else the kit's leather, cloth or metal.
	float kit_here = shell ? 1.0 : gloss.b * (1.0 - off);
	float leather = made.r * kit_here;
	float cloth = made.g * kit_here;
	float metal = made.b * kit_here;
	float flesh = clamp(1.0 - leather - cloth - metal, 0.0, 1.0);
	// --- The photographed detail, laid on the body at rest.
	vec3 n = normalize(rest_normal);
	vec3 w = tri_weights(n);
	vec3 bent = n;
	if (detail > 0.0) {
		// Skin: pores and the net of fine creases, a 6 cm tile.
		if (flesh > 0.01) {
			vec3 sp = rest / 0.06;
			vec4 sd = mat_data(sp, n, w, MAT_SKIN);
			bent = bend_more(bent, mat_normal(sp, n, w, MAT_SKIN, 0.9 * flesh * detail), n);
			albedo *= mix(1.0, 0.86 + 0.14 * sd.g, flesh * detail);
			rough = mix(rough, clamp(rough + (sd.r - 0.5) * 0.35, 0.3, 0.85), flesh * detail);
		}
		// Leather: a worn hide's grain, scuffs and creases, a 22 cm tile.
		if (leather > 0.01) {
			vec3 lp = rest / 0.22;
			vec4 ld = mat_data(lp, n, w, MAT_LEATHER_WORN);
			float lc = mat_shade(lp, n, w, MAT_LEATHER_WORN);
			albedo *= mix(1.0, mix(1.0, lc, 0.5) * (0.8 + 0.2 * ld.g), leather * detail);
			bent = bend_more(bent, mat_normal(lp, n, w, MAT_LEATHER_WORN, 1.3 * leather * detail), n);
			rough = mix(rough, clamp(0.42 + ld.r * 0.45, 0.35, 0.85), leather * detail);
		}
		// Cloth: woven wool, a 9 cm tile, and a coarser weave under it.
		if (cloth > 0.01) {
			vec3 cp = rest / 0.09;
			vec4 cd = mat_data(cp, n, w, MAT_WOOL);
			float cc = mat_shade(cp * 2.3, n, w, MAT_CLOTH_COARSE);
			albedo *= mix(1.0, mix(1.0, cc, 0.35) * (0.72 + 0.28 * cd.g), cloth * detail);
			bent = bend_more(bent, mat_normal(cp, n, w, MAT_WOOL, 1.6 * cloth * detail), n);
			rough = mix(rough, 0.86 + cd.r * 0.12, cloth * detail);
		}
		// Steel: brushed and scratched, a 30 cm tile, scuffed bright on edges.
		if (metal > 0.01) {
			vec3 mp = rest / 0.3;
			vec4 md = mat_data(mp, n, w, MAT_STEEL_WORN);
			float mc = mat_shade(mp, n, w, MAT_STEEL_WORN);
			// Grime and old oil lie dark in its hollows and seams (the kit's
			// own relief, read from its normal map's tilt), and dull it there.
			float hollow = clamp(1.0 - macro.b * 1.6 + 0.6, 0.0, 1.0);
			float grime = clamp((1.0 - md.g) * 1.5 + (1.0 - hollow) * 0.8, 0.0, 1.0);
			albedo *= mix(1.0, mix(1.0, mc, 0.7) * (1.0 - 0.45 * grime), metal * detail);
			bent = bend_more(bent, mat_normal(mp, n, w, MAT_STEEL_WORN, 0.9 * metal * detail), n);
			rough = mix(rough, clamp(0.32 + md.r * 0.4 + grime * 0.25, 0.28, 0.85), metal * detail);
		}
	}
	ALBEDO = albedo;
	NORMAL = detail_normal(bent, n, rest, VERTEX, NORMAL);
	NORMAL_MAP = macro;
	ROUGHNESS = rough;
	METALLIC = mix(gloss.g * kit_metal, 0.0, off);
	SPECULAR = specular;
	float reach = abs(rest.x);
	float glove = shell ? 0.0 : gloved * part.w * smoothstep(glove_from - 0.003, glove_from + 0.003, reach);
	if (glove > 0.0) {
		// Fine soft leather, the hand's own creases showing through (the
		// skin's normals), a shade darker in them; the cuff a turned-back band.
		float crease = dot(texture(skin, UV).rgb, vec3(0.3, 0.5, 0.2));
		vec3 glove_leather = tint_hands * (0.78 + crease * 0.45);
		float cuff = 1.0 - smoothstep(glove_from + 0.022, glove_from + 0.026, reach);
		glove_leather = mix(glove_leather, tint_hands * 0.82, cuff);
		ALBEDO = mix(ALBEDO, glove_leather, glove);
		NORMAL_MAP = mix(NORMAL_MAP, texture(skin_normal, UV).rgb, glove);
		ROUGHNESS = mix(ROUGHNESS, 0.5, glove);
		METALLIC = mix(METALLIC, 0.0, glove);
		flesh *= 1.0 - glove;
	}
	skin_part = flesh;
	spec_level = specular;
}

void light() {
	lit(NORMAL, LIGHT, VIEW, LIGHT_COLOR, ATTENUATION, ALBEDO, ROUGHNESS, METALLIC, spec_level, skin_part, SPECULAR_AMOUNT, DIFFUSE_LIGHT, SPECULAR_LIGHT);
}
