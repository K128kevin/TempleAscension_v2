shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Camera-facing fire for the Oracle's fireball and its explosion. `burst` 0 is
// the travelling ball; 1 is the explosion, which swells and cools through
// orange and red into smoke as `progress` runs from 0 to 1. `flame_time` is
// driven by the combat clock, so pausing freezes the fire.
uniform float flame_time = 0.0;
uniform float burst = 0.0;
uniform float progress = 0.0;
uniform float seed = 0.0;

float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float total = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		total += noise(p) * amplitude;
		p = p * 2.07 + vec2(5.3, 1.7);
		amplitude *= 0.5;
	}
	return total;
}

void vertex() {
	// Billboard: keep the node's position and scale, face the camera.
	float size = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * size, INV_VIEW_MATRIX[1] * size, INV_VIEW_MATRIX[2] * size, MODEL_MATRIX[3]);
	// Pull the card toward the camera so the floor does not cut off its lower
	// half. The camera is orthographic, so its place on screen is unchanged.
	MODELVIEW_MATRIX[3].z += size * 0.75;
}

vec3 heat_color(float heat) {
	vec3 smoke = vec3(0.10, 0.085, 0.075);
	vec3 ember = vec3(0.75, 0.12, 0.02);
	vec3 flame = vec3(1.0, 0.48, 0.08);
	vec3 core = vec3(1.0, 0.93, 0.62);
	vec3 color = mix(smoke, ember, smoothstep(0.02, 0.28, heat));
	color = mix(color, flame, smoothstep(0.28, 0.6, heat));
	color = mix(color, core, smoothstep(0.6, 0.95, heat));
	// Hot parts glow above white so the filmic tonemap keeps them bright.
	return color * (1.0 + heat * 1.6);
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float r = length(c);
	float t = flame_time;
	float swirl = atan(c.y, c.x);
	// Licking flames flow outward from the centre; the burst churns faster.
	vec2 flow = vec2(swirl * 1.3 + seed, r * 3.0 - t * (3.0 + burst * 2.0));
	float n = fbm(flow + seed) * 0.65 + fbm(c * 3.1 + vec2(seed, -t * 2.2)) * 0.35;
	float cooling = burst * progress;
	float shape = r * (1.0 - burst * 0.12) + (n - 0.5) * (0.55 + burst * 0.25);
	float body = 1.0 - smoothstep(0.58, 0.95, shape);
	// The ball is white-hot through its core; the burst stays hot further out
	// until it cools.
	float falloff = mix(1.45, 0.95, burst);
	float heat = clamp(1.2 - shape * falloff + (n - 0.5) * 0.45 - cooling * 1.1, 0.0, 1.0);
	float fade = 1.0 - burst * smoothstep(0.55, 1.0, progress);
	ALBEDO = heat_color(heat);
	ALPHA = clamp(body * fade * (0.55 + heat), 0.0, 1.0);
}
