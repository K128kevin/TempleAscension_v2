shader_type spatial;
// A cobweb (scripts/basement_props.gd web, wall_web), drawn over a sheet laid
// round its hub: UV.x the angle round it (0 to 1), UV.y the distance out (0 at
// the hub, 1 at the rim), UV2.x the web's size in metres. Not a garden
// spider's orb but an old cellar cobweb: a loose tangle of hair-fine threads
// strung between anchors round its edge (CHORDS, each sagging a little toward
// the hub), a few drawn in toward the hub (SPOKES), some snapped and hanging
// free (LOOSE), and here and there a grey film of dust caught between them.
// The threads are far finer than a pixel at any distance the game is seen
// from; each is drawn as a faint, unbroken line, its strength what it would
// cover of the pixel, but never less than FAINTEST, so it still reads as a
// glint of silk catching the torchlight.
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, diffuse_lambert, specular_disabled;
uniform vec3 silk : source_color = vec3(0.93, 0.92, 0.9);
uniform float opacity = 0.9;
// A thread's width (metres), and the least share of a pixel it is drawn as.
uniform float thread_width = 0.0018;
uniform float faintest = 0.4;
const int CHORDS = 22;
const int SPOKES = 9;
const int LOOSE = 5;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

// A point on the web's rim, `t` of the way round (on the unit circle).
vec2 rim(float t) {
	return vec2(cos(t * 6.2832), sin(t * 6.2832));
}

float segment(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float h = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
	return length(p - a - ab * h);
}

// A thread from `a` to `b` sagging by `sag` toward the hub at its middle.
float sagging(vec2 p, vec2 a, vec2 b, float sag) {
	vec2 mid = (a + b) * 0.5 * (1.0 - sag);
	return min(segment(p, a, mid), segment(p, mid, b));
}

void fragment() {
	float size = UV2.x;
	// The sheet as a flat disc, in metres from the hub.
	float scale = size * 0.5;
	vec2 p = rim(UV.x) * UV.y;
	float near = 1e3;
	for (int i = 0; i < CHORDS; i++) {
		float k = float(i);
		float t1 = hash(vec2(k, 1.7));
		float t2 = t1 + 0.18 + 0.5 * hash(vec2(k, 5.3));
		float in1 = 0.75 + 0.25 * hash(vec2(k, 2.9));
		float in2 = 0.75 + 0.25 * hash(vec2(k, 7.1));
		near = min(near, sagging(p, rim(t1) * in1, rim(t2) * in2, 0.05 + 0.25 * hash(vec2(k, 3.3))));
	}
	for (int i = 0; i < SPOKES; i++) {
		float k = float(i) + 40.0;
		vec2 from = rim(hash(vec2(k, 4.1))) * (0.05 + 0.25 * hash(vec2(k, 6.6)));
		near = min(near, sagging(p, from, rim(hash(vec2(k, 8.2))) * (0.8 + 0.2 * hash(vec2(k, 1.1))), 0.04));
	}
	// Snapped threads, hanging from one anchor part way across.
	for (int i = 0; i < LOOSE; i++) {
		float k = float(i) + 80.0;
		vec2 from = rim(hash(vec2(k, 2.2))) * 0.95;
		vec2 to = from + (vec2(hash(vec2(k, 3.7)), hash(vec2(k, 9.4))) - 0.5) * 0.9;
		near = min(near, segment(p, from, to));
	}
	float d = near * scale;
	float pixel = max(fwidth(d), 1e-5);
	float cover = max(thread_width / pixel, faintest);
	float strands = clamp(1.0 - d / max(pixel, thread_width), 0.0, 1.0) * min(cover, 1.0);
	// Dust: a fine grey film caught here and there among the threads,
	// thickest toward the corner where the web is oldest.
	float film = smoothstep(0.62, 0.85, noise(p * 3.2 + 7.0)) * smoothstep(1.0, 0.3, UV.y);
	film *= 0.55 + 0.45 * noise(p * 26.0);
	float grime = noise(p * 40.0);
	ALBEDO = mix(silk, silk * 0.62, film) * (0.85 + 0.2 * grime);
	EMISSION = silk * 0.35;
	ALPHA = clamp(strands * 0.85 + film * 0.18, 0.0, 1.0) * opacity;
}
