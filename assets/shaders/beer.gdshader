shader_type spatial;
// The top of the beer in a mug (scripts/beer.gd): a disc of the mug's bore,
// kept level. `head` 1 is a fresh pour's head of foam; as it is drunk the
// foam thins, breaks up into islands and is gone but for a ring of it
// clinging round the wall and a scum of fine bubbles, over dark amber beer.
//
// The foam is bubbles packed together at three sizes (cells of a jittered
// grid: the nearest few centres make each bubble's dome, and the walls
// between them its shading), the larger toward the wall, with the odd pore
// where a bubble has burst; its surface domed a little and slick on the
// bubble tops. The beer is near black-brown in the depth of a wooden mug,
// amber where it is shallow at the wall and in the light, glassy, catching
// the room's light; fine bubbles rise through it and wink at its surface.
render_mode cull_back, shadows_disabled;

uniform float head : hint_range(0.0, 1.0) = 1.0;
uniform float seed = 0.0;
// How far the foam's dome rises at its middle, in metres.
uniform float dome = 0.004;

varying vec2 disc;

// (Hashes without sines: a sine of a large number goes to pieces on some
// GPUs, and drew streaks.)
float hash1(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx + seed * 1.37) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
vec2 hash2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx + seed * 0.71) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash1(i), hash1(i + vec2(1.0, 0.0)), f.x), mix(hash1(i + vec2(0.0, 1.0)), hash1(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	return value_noise(p) * 0.55 + value_noise(p * 2.1 + 3.7) * 0.3 + value_noise(p * 4.3 + 7.1) * 0.15;
}

// Bubbles at `scale` a unit: x, how high on its bubble a point is (1 on its
// top, falling to 0 at its edge, where it meets the next); y, a die for the
// bubble.
vec2 bubbles(vec2 p, float scale) {
	vec2 q = p * scale;
	vec2 cell = floor(q);
	float first = 8.0;
	vec2 nearest = vec2(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 c = cell + vec2(float(i), float(j));
			vec2 centre = c + 0.1 + 0.8 * hash2(c);
			float d = length(q - centre) / (0.62 + 0.25 * hash1(c + 2.7));
			if (d < first) {
				first = d;
				nearest = c;
			}
		}
	}
	return vec2(sqrt(max(1.0 - first * first, 0.0)), hash1(nearest + 5.9));
}

// The foam at a point of the disc, `r` from its middle: x, its height (the
// bubbles' domes, the larger standing over the small); y, its shade.
vec2 foam_at(vec2 p, float r) {
	vec2 fine = bubbles(p, 58.0);
	vec2 mid = bubbles(p + 0.37, 27.0);
	vec2 big = bubbles(p + 0.71, 13.0);
	// Larger bubbles here and there, the more toward the wall.
	float big_here = step(1.0 - (0.04 + 0.22 * smoothstep(0.6, 1.0, r)), big.y) * step(0.08, big.x);
	float mid_here = step(0.72, mid.y) * step(0.08, mid.x);
	float top = fine.x;
	top = mix(top, mid.x, mid_here);
	top = mix(top, big.x, big_here);
	float h = mix(fine.x * 0.5, mix(0.5 + mid.x * 0.6, 0.8 + big.x * 0.9, big_here), max(mid_here, big_here));
	// A bubble just burst: a dark pit.
	float pore = step(0.975, mid.y) * smoothstep(0.3, 0.8, mid.x);
	float shade = 0.5 + 0.5 * pow(top, 1.2) - pore * 0.25;
	return vec2(h - pore, shade);
}

void vertex() {
	disc = VERTEX.xz;
	float r2 = dot(disc, disc);
	// The head stands up a little in the middle, and creeps up the wall.
	VERTEX.y += head * dome * (1.0 - r2) * (0.6 + 0.4 * fbm(disc * 3.0 + seed));
}

void fragment() {
	vec2 p = disc;
	float r = length(p);
	float drift = TIME * 0.004;
	// Where the foam lies: all of it on a fresh head; breaking up into
	// islands, then gone, but for its ring at the wall and a scum.
	float lie = fbm(p * 3.2 + vec2(seed, drift)) * 0.8 + fbm(p * 9.0 + seed * 2.0) * 0.2;
	float ring = smoothstep(0.62, 0.98, r) * (0.75 + 0.5 * fbm(vec2(atan(p.y, p.x) * 2.0, seed)));
	float cover = smoothstep(-0.16, 0.12, lie + ring * 0.75 + head * 1.0 - 0.92);
	// The ring at the wall after it is drunk: thin, broken, lace-edged.
	float scum = smoothstep(0.6, 0.85, fbm(p * 14.0 + seed * 3.0)) * smoothstep(0.3, 0.95, r) * (1.0 - head) * 0.8;
	vec2 f = foam_at(p, r);
	// The foam's surface tipped by its bubbles' domes (their slope, a small
	// step either way).
	float e = 0.004;
	float hx = foam_at(p + vec2(e, 0.0), r).x - foam_at(p - vec2(e, 0.0), r).x;
	float hz = foam_at(p + vec2(0.0, e), r).x - foam_at(p - vec2(0.0, e), r).x;
	vec3 foam_normal = normalize(vec3(-hx * 0.25, 1.0, -hz * 0.25));
	vec3 cream = vec3(0.66, 0.6, 0.47);
	vec3 foam = cream * f.y;
	// Thinner (and the beer showing through, yellower) at its broken edge.
	float thin = 1.0 - smoothstep(0.0, 0.8, cover);
	foam = mix(foam, vec3(0.6, 0.42, 0.18) * f.y, thin * 0.8);
	// The beer: dark in the depth of the mug, amber where shallow at the
	// wall; a few fine bubbles at its surface, winking as they burst.
	vec3 deep = vec3(0.17, 0.075, 0.012);
	vec3 amber = vec3(0.55, 0.30, 0.06);
	vec3 beer = mix(deep, amber, smoothstep(0.55, 1.0, r) * 0.55 + fbm(p * 2.0 + seed) * 0.12);
	vec2 sparkle = bubbles(p + vec2(0.0, TIME * 0.01), 60.0);
	float fizz = step(0.97, sparkle.y) * smoothstep(0.4, 0.9, sparkle.x) * (0.5 + 0.5 * sin(TIME * 3.0 + sparkle.y * 40.0));
	beer = mix(beer, vec3(0.8, 0.66, 0.42), fizz * 0.4);
	// A scum of fine foam over it, as lace.
	vec3 lace = mix(beer, cream * f.y, 0.8);
	beer = mix(beer, lace, scum);
	float foamy = max(cover, scum * 0.6);
	ALBEDO = mix(beer, foam, cover);
	ROUGHNESS = mix(0.06, 0.45, foamy);
	SPECULAR = mix(0.6, 0.35, foamy);
	vec3 n = mix(vec3(0.0, 1.0, 0.0), foam_normal, cover);
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
}
