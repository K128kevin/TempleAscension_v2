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
uniform sampler2D kit : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D kit_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D kit_rough : filter_linear_mipmap;
uniform sampler2D skin : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D skin_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D skin_rough : filter_linear_mipmap;
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
uniform float specular = 0.5;
uniform float kit_metal = 0.45;
varying vec3 rest;

void vertex() {
	rest = rest_pose ? CUSTOM0.xyz : VERTEX;
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
	float off = shell ? 0.0 : clamp(dot(part, bare), 0.0, 1.0);
	vec3 worn = texture(kit, UV).rgb;
	vec3 colour = part.x * tint_chest + part.y * tint_legs + part.z * tint_feet + part.w * tint_hands + (1.0 - min(1.0, part.x + part.y + part.z + part.w)) * vec3(1.0);
	float redo = clamp(dot(part, recolor), 0.0, 1.0);
	worn = mix(worn, dot(worn, vec3(0.299, 0.587, 0.114)) * colour * 1.8, redo);
	vec3 gloss = texture(kit_rough, UV).rgb;
	ALBEDO = mix(worn, texture(skin, UV).rgb, off);
	NORMAL_MAP = mix(texture(kit_normal, UV).rgb, texture(skin_normal, UV).rgb, off);
	ROUGHNESS = mix(gloss.r, max(0.55, texture(skin_rough, UV).r), off);
	METALLIC = mix(gloss.g * kit_metal, 0.0, off);
	SPECULAR = specular;
}
