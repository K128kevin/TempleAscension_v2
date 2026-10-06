shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Fire Tornado's funnel (scripts/wizard_fx.gd): a tall tube of flame, a
// slender stem flaring toward its crown, that twists about as it spins. Its
// surface is pushed in and out by noise so its outline wavers, and its flame
// is streaks of noise wound round the tube and racing up it; at its outline,
// where the tube is seen edge-on, it tears apart into tongues rather than
// ending in a line. It burns white-hot low in the column and cools through
// orange and red into the smoke at its crown. `core` 1 is the hotter, narrower
// column drawn inside the shell. UV.x runs round the tube, UV.y up it.
// `flame_time` is driven by the combat clock, so pausing freezes the fire;
// `strength` grows and fades it; `lean` is how far its crown trails behind as
// it travels.
uniform float flame_time = 0.0;
uniform float strength = 1.0;
uniform float seed = 0.0;
uniform float core = 0.0;
uniform vec2 lean = vec2(0.0);

varying float rise;

float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

// Value noise that wraps every `period` cells along x, so it closes seamlessly
// round the tube.
float noise(vec2 p, float period) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float x0 = mod(i.x, period);
	float x1 = mod(i.x + 1.0, period);
	return mix(mix(hash(vec2(x0, i.y)), hash(vec2(x1, i.y)), f.x), mix(hash(vec2(x0, i.y + 1.0)), hash(vec2(x1, i.y + 1.0)), f.x), f.y);
}

float fbm(vec2 p, float period) {
	float total = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		total += noise(p, period) * amplitude;
		p = p * 2.0 + vec2(0.0, 1.7);
		period *= 2.0;
		amplitude *= 0.5;
	}
	return total;
}

void vertex() {
	rise = UV.y;
	float h = UV.y;
	float t = flame_time * (1.0 + core * 0.4);
	// Its surface swells and sinks in lumps that wind round and race up it.
	float lumps = fbm(vec2(UV.x * 7.0 + h * 4.0 - t * 2.2 + seed, h * 5.0 - t * 2.8), 7.0);
	VERTEX.xz += normalize(NORMAL.xz + vec2(0.0001)) * (lumps - 0.5) * (0.25 + h * 0.9) * (1.0 - core * 0.5);
	// The column twists about: its bend winds round it like a corkscrew and
	// slowly turns, more the higher it goes, with a quicker wobble on top,
	// and its crown trails behind as it travels.
	float sway = pow(h, 1.4);
	float turn = flame_time * 1.4 + seed + h * 2.6;
	float bend = 0.6 + sin(flame_time * 0.7 + seed) * 0.2;
	VERTEX.x += (cos(turn) * bend + sin(h * 6.1 - flame_time * 2.3 + seed * 2.0) * 0.12) * sway + lean.x * h * h;
	VERTEX.z += (sin(turn) * bend + cos(h * 5.3 - flame_time * 2.1) * 0.12) * sway + lean.y * h * h;
	VERTEX.y *= mix(0.35, 1.0, clamp(strength * 1.4, 0.0, 1.0));
}

vec3 heat_color(float heat) {
	vec3 soot = vec3(0.07, 0.055, 0.05);
	vec3 ember = vec3(0.55, 0.08, 0.015);
	vec3 flame = vec3(1.0, 0.38, 0.05);
	vec3 bright = vec3(1.0, 0.66, 0.2);
	vec3 white = vec3(1.0, 0.82, 0.48);
	vec3 color = mix(soot, ember, smoothstep(0.05, 0.28, heat));
	color = mix(color, flame, smoothstep(0.28, 0.55, heat));
	color = mix(color, bright, smoothstep(0.55, 0.8, heat));
	color = mix(color, white, smoothstep(0.82, 1.0, heat));
	return color * (1.0 + heat * 0.9);
}

void fragment() {
	float h = rise;
	float t = flame_time * (1.0 + core * 0.4);
	// Domain-warped streaks, wound round the tube, spinning and racing upward.
	vec2 warp = vec2(fbm(vec2(UV.x * 5.0 + seed, h * 4.0 - t * 1.7), 5.0), fbm(vec2(UV.x * 5.0 - 3.1, h * 4.0 - t * 2.3 + seed), 5.0)) - 0.5;
	vec2 spiral = vec2(UV.x * 6.0 + h * 5.0 - t * 2.6 + seed + warp.x * 1.6, h * 2.6 - t * 1.6 + warp.y * 1.4);
	float streaks = fbm(spiral, 6.0);
	float licks = fbm(vec2(UV.x * 12.0 - t * 3.4 + h * 9.0 + warp.x * 3.0, h * 14.0 - t * 7.0 + seed), 12.0);
	float n = streaks * 0.6 + licks * 0.4;
	// Seen edge-on, the tube tears apart into tongues of flame.
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float cooling = smoothstep(0.45, 1.0, h);
	float threshold = 0.36 + (1.0 - smoothstep(0.0, 0.7, facing)) * 0.32 + cooling * 0.12 - core * 0.06;
	float body = smoothstep(threshold, threshold + 0.12, n);
	float heat = clamp(n * 1.6 - 0.25 - cooling * 0.8 + (1.0 - h) * 0.12 + core * 0.2, 0.0, 1.0);
	// The crown thins into the smoke; the foot thins into the fire round it.
	float ends = smoothstep(0.0, 0.1, h) * (1.0 - smoothstep(0.6, 0.92, h + (licks - 0.5) * 0.2));
	ALBEDO = heat_color(heat);
	ALPHA = clamp(body * ends * strength * (0.4 + heat * 0.75), 0.0, 1.0);
}
