shader_type spatial;
// The foam left clinging to the inside of a mug as its beer is drunk down
// (scripts/beer.gd): rings of it where the beer stood between sips, joined
// by a lacy net that runs down the wall, thick toward the top, thinning
// below; nothing below the beer or above where it ever stood. Drawn on a
// bore-sized tube inside the mug, its far wall only.
render_mode cull_front, shadows_disabled, blend_mix, depth_draw_never;

// The beer's level now and the highest it has stood, metres up the bore.
uniform float low = 0.0;
uniform float high = 0.0;
uniform float seed = 0.0;
// Metres to each unit of the tube's height (its middle at 0, its ends at
// -1 and 1).
uniform float half_bore = 0.075;

varying vec3 local;

// (Hashes without sines: a sine of a large number goes to pieces on some
// GPUs, and drew streaks.)
float hash1(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx + seed * 1.37) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash1(i), hash1(i + vec2(1.0, 0.0)), f.x), mix(hash1(i + vec2(0.0, 1.0)), hash1(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	local = vec3(VERTEX.x, (VERTEX.y + 1.0) * half_bore, VERTEX.z);
}

void fragment() {
	float y = local.y;
	if (y < low + 0.003 || y > high - 0.001) discard;
	float round = atan(local.z, local.x) / 6.2832 + 0.5;
	// The rings where it stood, here and there up the wall: thin, and broken.
	float level = value_noise(vec2(y * 420.0, seed * 3.0));
	float ring = smoothstep(0.8, 0.9, level) * smoothstep(0.3, 0.55, value_noise(vec2(round * 40.0, y * 90.0)));
	// The net between: fine threads of it drawn down the wall.
	vec2 at = vec2(round * 90.0, y * 260.0 + value_noise(vec2(round * 50.0, seed)) * 4.0);
	float net = value_noise(at) * 0.6 + value_noise(at * 2.3 + 4.1) * 0.4;
	float thread = 1.0 - smoothstep(0.02, 0.12, abs(net - 0.5));
	float top = smoothstep(low, high, y);
	float lace = max(ring, thread * (0.25 + 0.75 * top) * step(0.4, value_noise(at * 0.3)));
	if (lace < 0.05) discard;
	ALBEDO = vec3(0.62, 0.57, 0.45) * (0.8 + 0.2 * net);
	ALPHA = lace * 0.6;
	ROUGHNESS = 0.6;
	SPECULAR = 0.3;
}
