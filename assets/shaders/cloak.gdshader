shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, specular_schlick_ggx;

// A cloak that folds over the legs instead of letting them through
// (assets/shaders/cloth_fold.gdshaderinc), in felted wool: mottled, with a
// fuzzy weave. With `tatter` the hem is frayed and torn into ragged tongues,
// the wool is rubbed thin in places low down (never through), and
// the cloth is grimed toward the hem. Patterns are laid on the cloak's rest pose (CUSTOM0, from
// Art.rest_pose_mesh), so they stay fixed to the cloth as it swings.
#include "res://assets/shaders/cloth_fold.gdshaderinc"
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
// its stitching gold, and a dragon embroidered on it in gold thread: its
// head and winding body down the back, the head at the top, mouth open
// upward, and its wings wrapped round both sides to the front of the chest
// as if it held the wearer.
uniform float gilded = 0.0;
uniform vec3 gold_color : source_color = vec3(0.86, 0.63, 0.25);

varying vec3 cloth_position;

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

// Distance from `q` to the segment `a`-`b`.
float seg(vec2 q, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float t = clamp(dot(q - a, ab) / dot(ab, ab), 0.0, 1.0);
	return length(q - a - ab * t);
}

// The dragon's right wing, as a polygon on the robe unrolled (metres round
// it from the middle of the back, and up): from its root at the shoulder
// along the arm to the wrist, then its four fingers' tips with the membrane
// scalloped between them, and the trailing edge back to the body. (The left
// wing is its mirror.)
const vec2 WING[12] = {vec2(0.03, 1.24), vec2(0.16, 1.34), vec2(0.42, 1.36), vec2(0.43, 1.29), vec2(0.50, 1.26), vec2(0.47, 1.18), vec2(0.52, 1.14), vec2(0.45, 1.07), vec2(0.48, 1.02), vec2(0.36, 1.05), vec2(0.22, 1.05), vec2(0.03, 1.08)};
const vec2 WRIST = vec2(0.16, 1.34);

// Signed distance from `q` to the wing (negative inside).
float wing_shape(vec2 q) {
	float d = dot(q - WING[0], q - WING[0]);
	float s = 1.0;
	for (int i = 0, j = 11; i < 12; j = i, i++) {
		vec2 e = WING[j] - WING[i];
		vec2 w = q - WING[i];
		vec2 b = w - e * clamp(dot(w, e) / dot(e, e), 0.0, 1.0);
		d = min(d, dot(b, b));
		bvec3 c = bvec3(q.y >= WING[i].y, q.y < WING[j].y, e.x * w.y > e.y * w.x);
		if (all(c) || all(not(c))) s *= -1.0;
	}
	return s * sqrt(d);
}

float cover(float d, float blur) {
	return 1.0 - smoothstep(-blur, blur, d);
}

// The dragon embroidered on a gilded robe, on the robe unrolled (`q`: metres
// round it from the middle of the back, and up): its cover (x, 0 to 1) and
// the shade of its thread there (y: 1 plain, less in the scales' shadows,
// more along the outlines).
vec2 dragon(vec2 q) {
	float blur = max((fwidth(q.x) + fwidth(q.y)) * 0.5, 0.0006);
	// The body: a serpent winding down the back from the neck to the tail's
	// point, thickest under the wings.
	float wave = (q.y - 1.30) * 20.94;
	float spine = 0.04 * sin(wave);
	float slope = 0.838 * cos(wave);
	float girth = mix(0.0, 0.034, smoothstep(0.34, 1.05, q.y)) * (1.0 - 0.3 * smoothstep(1.2, 1.3, q.y));
	float body = abs(q.x - spine) / sqrt(1.0 + slope * slope) - girth;
	body = max(body, max(0.34 - q.y, q.y - 1.30));
	// Its scales: rows of arcs across it, staggered.
	vec2 sc = vec2(q.x - spine, q.y) / 0.013;
	sc.x += 0.5 * mod(floor(sc.y), 2.0);
	vec2 cell = fract(sc) - 0.5;
	float ring = abs(length(cell) - 0.42);
	float scales = (1.0 - smoothstep(0.05, 0.13, ring)) * step(cell.y, 0.0) * smoothstep(0.012, 0.02, girth);
	// The head: a long skull, the jaws open upward with a gap between them,
	// an eye, and two horns swept back down along the neck.
	vec2 hc = vec2(0.0, 1.315);
	float head = (length((q - hc) / vec2(0.05, 0.045)) - 1.0) * 0.045;
	float upper = seg(q, vec2(-0.03, 1.33), vec2(-0.017, 1.41)) - 0.012;
	float lower = seg(q, vec2(0.03, 1.33), vec2(0.023, 1.41)) - 0.011;
	float horns = min(seg(q, vec2(-0.035, 1.305), vec2(-0.075, 1.245)), seg(q, vec2(0.035, 1.305), vec2(0.075, 1.245))) - 0.004;
	float eye = length(q - vec2(-0.018, 1.325)) - 0.006;
	// Its teeth: small points along the jaws' inner edges.
	float teeth = min(seg(q, vec2(-0.01, 1.365), vec2(-0.004, 1.372)), seg(q, vec2(0.012, 1.375), vec2(0.006, 1.383)));
	teeth = min(teeth, seg(q, vec2(-0.005, 1.39), vec2(0.0, 1.396))) - 0.0025;
	float skull = min(min(head, min(upper, lower)), min(horns, teeth));
	// The wings, mirrored: the membrane stitched in rays from the wrist,
	// the arm and the fingers in solid thread.
	vec2 w = vec2(abs(q.x), q.y);
	float wing = wing_shape(w);
	float bones = seg(w, WING[0], WRIST) - 0.009;
	for (int i = 2; i <= 8; i += 2) bones = min(bones, seg(w, WRIST, WING[i]) - 0.0045);
	vec2 ray = w - WRIST;
	float fan = step(0.5, fract(atan(ray.y, ray.x) * 26.0));
	float membrane = cover(wing, blur) * mix(0.0, 1.0, fan) * smoothstep(0.03, 0.08, length(ray));
	// Put together: cover, and the thread's shade.
	float outline = cover(abs(body) - 0.003, blur) + cover(abs(skull) - 0.0025, blur) + cover(abs(wing) - 0.002, blur);
	float c = max(max(cover(body, blur), cover(skull, blur)), max(membrane, cover(bones, blur)));
	c = max(c, min(outline, 1.0));
	c *= 1.0 - cover(eye, blur);
	float shade = 1.0 - 0.4 * scales * cover(body, blur) + 0.18 * min(outline, 1.0) - 0.12 * membrane * (1.0 - cover(bones, blur));
	return vec2(clamp(c, 0.0, 1.0), shade);
}

void vertex() {
	cloth_position = rest_pose ? CUSTOM0.xyz : VERTEX;
	VERTEX = fold_cloth(VERTEX);
}

void fragment() {
	vec3 p = cloth_position;
	float thin = 0.0;
	// (Gilded: hemmed straight, and of an even, unworn cloth.)
	if (gilded > 0.5 && p.y < hem_height) discard;
	// The gold stitched into a gilded robe: its dragon, laid on the robe
	// unrolled round the body (the rest pose), kept off the sleeves.
	float gold = 0.0;
	float gold_shade = 1.0;
	if (gilded > 0.5) {
		vec2 unrolled = vec2(atan(p.x, -p.z) * 0.2, p.y);
		vec2 embroidery = dragon(unrolled);
		float sleeve = smoothstep(0.2, 0.24, abs(p.x)) * smoothstep(1.15, 1.25, p.y);
		gold = embroidery.x * (1.0 - sleeve);
		gold_shade = embroidery.y;
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
	color *= 1.0 - (0.5 - 0.5 * fold) * 0.12 * hang;
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
	float satin = 0.85 + 0.25 * step(0.5, fract((p.x + p.y + p.z) * 260.0));
	color = mix(color, gold_color * 0.85 * satin * gold_shade * (0.9 + grain * 0.2), gold);
	h += gold * 0.0008;
	// (Hidden in the shadows: scripts/visual.gd set_shadowed.)
	ALBEDO = mix(color, vec3(0.02, 0.02, 0.04), shadowed * 0.92);
	vec3 sx = dFdx(VERTEX);
	vec3 sy = dFdy(VERTEX);
	vec3 r1 = cross(sy, NORMAL);
	vec3 r2 = cross(NORMAL, sx);
	float det = dot(sx, r1);
	vec3 gradient = (dFdx(h) * r1 + dFdy(h) * r2) * sign(det) / max(abs(det), 0.000001);
	NORMAL = normalize(NORMAL - gradient);
	// A dull, matte wool; the gold thread has a satin sheen, no mirror's
	// gloss (that threw a broad pale highlight over the embroidery).
	ROUGHNESS = mix(1.0, 0.62, gold);
	SPECULAR = mix(0.03, 0.35, gold);
	METALLIC = gold * 0.35;
}
