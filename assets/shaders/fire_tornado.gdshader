shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Fire Tornado's funnel (scripts/wizard_fx.gd): a tall tube of flame, narrow
// at the ground and flaring above, that snakes about as it spins. Its flame
// is streaks of noise wound round the tube and racing up it, white-hot low in
// the column and cooling through orange and red into the smoke at its crown.
// UV.x runs round the tube, UV.y up it. `flame_time` is driven by the combat
// clock, so pausing freezes the fire; `strength` grows and fades it; `lean`
// is how far its crown trails behind as it travels.
uniform float flame_time = 0.0;
uniform float strength = 1.0;
uniform float seed = 0.0;
uniform float height = 6.0;
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
	float t = flame_time;
	// The column twists about: its bend winds round it like a corkscrew and
	// slowly turns, more the higher it goes, with a quicker wobble on top,
	// and its crown trails behind as it travels.
	float sway = pow(h, 1.4);
	float turn = t * 1.4 + seed + h * 2.6;
	float bend = 0.6 + sin(t * 0.7 + seed) * 0.2;
	VERTEX.x += (cos(turn) * bend + sin(h * 6.1 - t * 2.3 + seed * 2.0) * 0.12) * sway + lean.x * h * h;
	VERTEX.z += (sin(turn) * bend + cos(h * 5.3 - t * 2.1) * 0.12) * sway + lean.y * h * h;
	// It breathes: the tube swells and pinches as it spins.
	float pulse = 1.0 + sin(h * 9.0 - t * 4.0 + seed) * 0.07;
	VERTEX.xz *= pulse;
	VERTEX.y *= mix(0.35, 1.0, clamp(strength * 1.4, 0.0, 1.0));
}

vec3 heat_color(float heat) {
	vec3 smoke = vec3(0.09, 0.075, 0.065);
	vec3 ember = vec3(0.7, 0.11, 0.02);
	vec3 flame = vec3(1.0, 0.45, 0.07);
	vec3 core = vec3(1.0, 0.82, 0.5);
	vec3 color = mix(smoke, ember, smoothstep(0.05, 0.3, heat));
	color = mix(color, flame, smoothstep(0.3, 0.62, heat));
	color = mix(color, core, smoothstep(0.62, 0.95, heat));
	return color * (1.0 + heat * 1.2);
}

void fragment() {
	float h = rise;
	float t = flame_time;
	// Streaks wound round the tube, spinning fast and racing upward.
	vec2 spiral = vec2(UV.x * 6.0 + h * 5.0 - t * 2.6 + seed, h * 7.0 - t * 4.2);
	float streaks = fbm(vec2(spiral.x, spiral.y * 0.35), 6.0);
	float licks = fbm(vec2(UV.x * 12.0 - t * 3.4 + h * 9.0, h * 14.0 - t * 7.0 + seed), 12.0);
	float n = streaks * 0.65 + licks * 0.35;
	// Hottest low in the column; it cools toward its crown, into smoke.
	float cooling = smoothstep(0.5, 1.0, h);
	float heat = clamp(n * 1.55 - 0.18 - cooling * 0.75 + (1.0 - h) * 0.15, 0.0, 1.0);
	// Soft at its silhouette, where the tube is seen edge-on.
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = smoothstep(0.05, 0.55, facing);
	float body = smoothstep(0.28, 0.55, n + (1.0 - cooling) * 0.12);
	float ends = smoothstep(0.0, 0.07, h) * (1.0 - smoothstep(0.62, 0.92, h));
	ALBEDO = heat_color(heat);
	ALPHA = clamp(body * edge * ends * strength * (0.45 + heat * 0.8), 0.0, 1.0);
}
