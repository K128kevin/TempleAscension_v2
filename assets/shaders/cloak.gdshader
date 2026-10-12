shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// A cloak that folds over the legs instead of letting them through
// (assets/shaders/cloth_fold.gdshaderinc), in felted wool: mottled, with a
// fuzzy weave. With `tatter` the hem is frayed and torn into ragged tongues,
// the wool is rubbed thin in places low down (never through), and
// the cloth is grimed toward the hem. Patterns are laid on the cloak's rest pose (CUSTOM0, from
// Art.rest_pose_mesh), so they stay fixed to the cloth as it swings.
#include "res://assets/shaders/cloth_fold.gdshaderinc"
// The weave itself is photographed wool (assets/shaders/detail.gdshaderinc),
// laid on the rest pose as the patterns are.
#include "res://assets/shaders/detail.gdshaderinc"
// Which photographed cloth (detail.gdshaderinc MAT_*), and its tile's size.
uniform float weave_layer = 8.0;
uniform float weave_tile = 0.08;
uniform float shadowed = 0.0;
uniform vec3 cloth_color : source_color = vec3(0.1, 0.19, 0.1);
uniform bool rest_pose = false;
// 0: a clean garment; 1: a ranger's weathered, tattered cloak.
uniform float tatter = 0.0;
// The rest-pose height of the hem, in metres.
uniform float hem_height = 0.3;
// The drape: soft vertical folds that deepen toward the hem.
uniform float fold_depth = 0.004;
// A wizard's robe (1), after his concept art: a wrap collar crossing the
// chest, the front opened below the sash over a dark under-robe, a stitched
// band round the hem and cuffs at the wide sleeves' ends (`sleeve_end`: how
// far out along the arms they reach, in the rest pose).
uniform float robe = 0.0;
uniform float sleeve_end = 0.56;
// A gilded robe (1: the Robe of the Lost Emperor): cleanly hemmed, never worn,
// its stitching gold, and a long eastern dragon embroidered down its back in
// couched gold thread among clouds (tools/paint_dragon.py paints it:
// `dragon_map`, the robe unrolled about the body over DRAGON_SPAN; R the
// gold's cover, G its threads' height, B their tone).
uniform float gilded = 0.0;
uniform vec3 gold_color : source_color = vec3(0.86, 0.63, 0.25);
uniform sampler2D dragon_map : hint_default_black, filter_linear_mipmap_anisotropic, repeat_disable;
// The picture's span on the robe unrolled: from (x0, y0), metres round from
// the middle of the back (to the right as the back is seen) and up, its
// width and height (tools/paint_dragon.py U0..U1, V0..V1).
const vec4 DRAGON_SPAN = vec4(-0.32, 0.12, 0.64, 1.36);
// How high the gold thread stands from the wool (metres), for its relief.
const float THREAD_RELIEF = 0.0009;

varying vec3 cloth_position;
varying vec3 cloth_normal;
// The mesh's own normal, in view space, as it is posed: which side of the
// cloth it points out of (the mesh's skirts and hems are not all wound the
// same way: the ranger's cloak below the waist and the wizard's robe's skirt
// have theirs pointing in, toward the legs).
varying vec3 posed_normal;

float hash3(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1,0,0)), f.x),
		mix(hash3(i + vec3(0,1,0)), hash3(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0,0,1)), hash3(i + vec3(1,0,1)), f.x),
		mix(hash3(i + vec3(0,1,1)), hash3(i + vec3(1,1,1)), f.x), f.y), f.z);
}

float fbm3(vec3 p) {
	float total = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		total += noise3(p) * amplitude;
		p = p * 2.07 + vec3(11.3, 7.1, 3.7);
		amplitude *= 0.5;
	}
	return total / 0.9375;
}

// Where a point of the robe (its rest pose) lies on the dragon's picture:
// metres round the body from the middle of the back (as the back is seen,
// left to right) and down from the picture's top, as a share of the picture.
vec2 dragon_uv(vec3 p) {
	vec2 c = vec2(p.x, p.z + 0.02);
	float round_back = -atan(c.x, -c.y) * length(c);
	return vec2((round_back - DRAGON_SPAN.x) / DRAGON_SPAN.z, (DRAGON_SPAN.y + DRAGON_SPAN.w - p.y) / DRAGON_SPAN.w);
}

void vertex() {
	cloth_position = rest_pose ? CUSTOM0.xyz : VERTEX;
	cloth_normal = rest_pose ? CUSTOM1.xyz : NORMAL;
	VERTEX = fold_cloth(VERTEX);
	posed_normal = (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec3 p = cloth_position;
	// The side of the cloth seen, and its normals, found from the surface
	// itself rather than from its winding: the face as it lies on screen,
	// turned toward the eye; the mesh's normal turned to that side (the
	// renderer's own flip for a two-sided face is not to be trusted on every
	// GPU: on the Intel Macs it flips the side facing the eye); and, in the
	// cloak's rest pose, whether that side faces out from the body (the
	// outside of the cloth) or in toward it (its inside, in shadow).
	vec3 face = cross(dFdx(VERTEX), dFdy(VERTEX));
	if (dot(face, VIEW) < 0.0) face = -face;
	bool stored_side = dot(posed_normal, face) >= 0.0;
	NORMAL = normalize(stored_side ? posed_normal : -posed_normal);
	vec3 seen_normal = stored_side ? cloth_normal : -cloth_normal;
	// (Out from the body's middle line up to the chest, and from the chest
	// over the shoulders and the hood: their tops face up and out.)
	vec3 from_body = p - vec3(0.0, clamp(p.y, 0.0, 1.15), 0.0);
	bool outside = dot(seen_normal, from_body) >= 0.0;
	float thin = 0.0;
	// (Gilded: hemmed straight, and of an even, unworn cloth.)
	if (gilded > 0.5 && p.y < hem_height) discard;
	// The gold stitched into a gilded robe: its dragon, laid on the robe
	// unrolled round the body (the rest pose), kept off the sleeves.
	float gold = 0.0;
	float gold_shade = 1.0;
	// The embroidery's relief, as the slope of its threads round the body
	// and up it.
	vec2 thread_slope = vec2(0.0);
	float thread_crown = 0.5;
	if (gilded > 0.5) {
		vec2 uv = dragon_uv(p);
		if (all(greaterThan(uv, vec2(0.0))) && all(lessThan(uv, vec2(1.0)))) {
			vec4 work = texture(dragon_map, uv);
			// (The heights a pixel's breadth along and down, or a texel's
			// close up.)
			vec2 reach = max(fwidth(uv), 1.0 / vec2(textureSize(dragon_map, 0)));
			float along = texture(dragon_map, uv + vec2(reach.x, 0.0)).g;
			float below = texture(dragon_map, uv + vec2(0.0, reach.y)).g;
			thread_slope = vec2((along - work.g) / (reach.x * DRAGON_SPAN.z), (work.g - below) / (reach.y * DRAGON_SPAN.w)) * THREAD_RELIEF;
			// Kept off the sleeves.
			float sleeve = smoothstep(0.2, 0.24, abs(p.x)) * smoothstep(1.15, 1.25, p.y);
			gold = work.r * (1.0 - sleeve);
			gold_shade = (0.35 + 0.75 * work.b * 1.1) * (0.8 + 0.3 * work.g);
			thread_crown = work.g;
		}
	}
	if (tatter > 0.0) {
		// The hem frays into ragged tongues of differing length.
		float ragged = fbm3(vec3(p.x, 0.0, p.z) * 9.0) * 0.11 + noise3(vec3(p.x, 0.0, p.z) * 55.0) * 0.025;
		if (p.y < hem_height + ragged * tatter) discard;
		// Low on a badly worn cloak the wool is rubbed thin in patches: paler,
		// flatter, its weave showing.
		float wear = fbm3(p * 7.0 + 21.0);
		float low = 1.0 - smoothstep(hem_height + 0.15, hem_height + 0.5, p.y);
		thin = smoothstep(0.58, 0.7, wear * low) * step(0.6, tatter);
	}
	// Felted wool: broad mottling, a darker grain and a fuzz.
	float mottle = fbm3(p * 4.5);
	float grain = noise3(p * 60.0);
	float fuzz = noise3(p * 260.0);
	vec3 color = cloth_color * mix(0.72 + mottle * 0.55, 0.9 + mottle * 0.2, gilded);
	color *= 0.9 + grain * 0.14 + fuzz * 0.08;
	// Paler, olive patches where the dye has faded.
	color = mix(color, color * vec3(1.25, 1.2, 0.95), smoothstep(0.62, 0.8, fbm3(p * 2.2 + 5.0)) * tatter);
	// Grime and wear darken the cloth toward the hem.
	float grime = (1.0 - smoothstep(hem_height, hem_height + 0.45, p.y)) * tatter;
	color *= 1.0 - grime * (0.35 + mottle * 0.2);
	// Worn patches: the nap rubbed off, the weave showing through.
	float weave = abs(sin(p.x * 900.0 + p.z * 900.0)) * abs(sin(p.y * 900.0));
	color = mix(color, color * (1.15 + weave * 0.25), thin);
	// The grain catches the light a little (the fuzz only tints: as relief
	// it glittered like satin).
	float h = grain * 0.0006;
	// The drape: folds running down from the shoulders, deeper and broader
	// toward the hem, wandering a little.
	float around = atan(p.x, p.z + 0.03);
	float hang = clamp((1.45 - p.y) / 1.1, 0.0, 1.0);
	float wander = fbm3(vec3(p.x, p.y * 0.35, p.z) * 3.0) * 4.0;
	float fold = sin(around * 7.0 + wander) * 0.65 + sin(around * 13.0 + wander * 1.7) * 0.35;
	h += fold * fold_depth * hang;
	color *= 1.0 - (0.5 - 0.5 * fold) * 0.24 * hang;
	// Worn: the dye faded and dusty on the raised folds and toward the hem.
	float dust = (1.0 - smoothstep(hem_height, hem_height + 0.7, p.y)) * 0.5 + max(fold, 0.0) * 0.25 * hang;
	float grey = dot(color, vec3(0.3, 0.5, 0.2));
	color = mix(color, vec3(grey) * vec3(1.12, 1.06, 0.95), clamp(dust * (0.25 + mottle * 0.3), 0.0, 0.4));
	if (robe > 0.5) {
		vec3 trim = color * 0.55;
		vec3 thread = mix(cloth_color * 2.4, vec3(0.42, 0.44, 0.48), 0.35);
		// (Gilded, the stitching is gold: `gold` is 1 where it runs, 0 on the
		// plain trim.)
		float stitch = 0.0;
		// (Its lines bolder and unbroken, gilded.)
		float tw = mix(0.0016, 0.003, gilded);
		float dash = mix(0.55, 1.01, gilded);
		bool front = p.z > 0.03 && abs(p.x) < 0.3;
		// The hem band, with a line of stitching along its top.
		float band = hem_height + 0.075;
		if (p.y < band) { color = trim; h += 0.0012; gold = 0.0; }
		if (abs(p.y - band + 0.008) < tw && fract(around * 60.0) < dash) { color = thread; stitch = 1.0; }
		// The cuffs of the wide sleeves.
		float reach = abs(p.x);
		if (reach > sleeve_end - 0.06 && reach > 0.4) { color = trim; h += 0.0012; gold = 0.0; }
		if (reach > 0.4 && abs(reach - sleeve_end + 0.068) < tw && fract(p.y * 220.0 + p.z * 220.0) < dash) { color = thread; stitch = 1.0; }
		if (front && p.y < 0.975) {
			// Below the sash the robe falls open a little over a dark under-robe,
			// wider toward the hem, each edge bound in a darker trim. (The
			// under-robe is a deep shade of the robe's own wool, so where a stride
			// draws the opening wide it reads as cloth in shadow, not a hole.)
			float open = 0.004 + 0.03 * clamp((0.975 - p.y) / 0.8, 0.0, 1.0);
			float edge = abs(p.x - 0.012);
			if (edge < open) { gold = 0.0; color = cloth_color * 0.42 * (0.8 + mottle * 0.4) * (0.9 + grain * 0.14); h -= 0.003; }
			else if (edge < open + 0.02) { color = trim; h += 0.0015; gold = 0.0; }
			if (abs(edge - open - 0.024) < tw && fract(p.y * 110.0) < dash) { color = thread; stitch = 1.0; }
		} else if (front && p.y < 1.55) {
			// The wrap collar: the right lapel crossing over to the left hip,
			// the left one's edge showing at the neck.
			float lapel = -0.06 + (p.y - 1.0) * 0.31;
			float under = 0.07 - (p.y - 1.0) * 0.36;
			float d = min(abs(p.x - lapel), p.y > 1.3 ? abs(p.x + under) : 1.0);
			if (d < 0.022) { gold = 0.0; color = trim * (0.9 + 0.2 * smoothstep(0.022, 0.0, d)); h += 0.0018 * smoothstep(0.022, 0.012, d); }
			if (abs(d - 0.027) < tw && fract(p.y * 110.0) < dash) { color = thread; stitch = 1.0; }
			// The overlapping lapel casts a little shadow on the cloth beneath.
			if (p.x < lapel - 0.022 && p.x > lapel - 0.05) color *= 0.8;
		}
		// A gilded robe's hem is edged in gold just above its cut.
		if (gilded > 0.5 && p.y < hem_height + 0.012 && p.y > hem_height + 0.004) stitch = 1.0;
		gold = max(gold, stitch * gilded);
		if (stitch > 0.5) gold_shade = 1.0;
	}
	// The gold thread: raised a little, its satin stitches catching the
	// light along them.
	color = mix(color, gold_color * 0.85 * gold_shade * (0.92 + grain * 0.16), gold);
	h += gold * 0.0004;
	// The weave: photographed wool, its threads' relief and the shade
	// down in between them; the gold thread lies over it.
	vec3 rn = normalize(seen_normal);
	vec3 tw = tri_weights(rn);
	vec3 wp = p / weave_tile;
	vec4 wd = mat_data(wp, rn, tw, weave_layer);
	float ws = mat_shade(wp, rn, tw, weave_layer);
	color *= mix(1.0, mix(1.0, ws, 0.3) * (0.82 + 0.18 * wd.g), 1.0 - gold);
	// (Lit without the wrap it once had, which flattened it, the wool is
	// drawn a little lighter to keep its colour; less so now that its
	// normals face the light they should, so it keeps the shade it had.)
	color *= 1.15;
	// The inside of the cloth, out of the light.
	if (!outside) color *= 0.55;
	// (Hidden in the shadows: scripts/visual.gd set_shadowed.)
	ALBEDO = mix(color, vec3(0.02, 0.02, 0.04), shadowed * 0.92);
	vec3 sx = dFdx(VERTEX);
	vec3 sy = dFdy(VERTEX);
	vec3 r1 = cross(sy, NORMAL);
	vec3 r2 = cross(NORMAL, sx);
	float det = dot(sx, r1);
	vec3 gradient = (dFdx(h) * r1 + dFdy(h) * r2) * sign(det) / max(abs(det), 0.000001);
	NORMAL = normalize(NORMAL - gradient);
	vec3 bent = mat_normal(wp, rn, tw, weave_layer, mix(1.5, 0.0, gold));
	if (gold > 0.0) {
		// The gold thread's own relief, from the picture: round the body and
		// up it, on the cloth's rest pose.
		vec3 round_way = normalize(cross(vec3(0.0, 1.0, 0.0), rn) + vec3(1e-4, 0.0, 0.0));
		vec3 up_way = normalize(cross(rn, round_way));
		vec3 relief = normalize(rn - (round_way * thread_slope.x + up_way * thread_slope.y) * gold);
		bent = bend_more(bent, relief, rn);
	}
	NORMAL = detail_normal(bent, rn, p, VERTEX, NORMAL);
	// Wool's fibres catch the light at a glancing angle: a soft sheen at the
	// edges of the folds.
	RIM = 0.18 * (1.0 - gold);
	RIM_TINT = 0.7;
	// A dull, matte wool; the gold thread has a satin sheen, no mirror's
	// gloss (that threw a broad pale highlight over the embroidery).
	// (The thread's crowns, burnished, glint; down between them it is duller.)
	ROUGHNESS = mix(0.86 + wd.r * 0.12, mix(0.66, 0.44, thread_crown), gold);
	SPECULAR = mix(0.03, 0.35, gold);
	METALLIC = gold * 0.8;
}
