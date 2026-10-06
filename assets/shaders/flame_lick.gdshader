shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// A tongue of flame (scripts/wizard_fx.gd: Fire Tornado's fire round its
// foot): a card that stands upright and turns about its upright to face the
// camera, as large as the node's scale, its foot at the node. The flame is
// noise: a broad hot root that tears upward into wavering, splitting tongues
// and cools from white-yellow through orange into a dull red at their tips.
// `flame_time` runs on the combat clock.
uniform float flame_time = 0.0;
uniform float seed = 0.0;
uniform float strength = 1.0;

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
		p = p * 2.1 + vec2(1.7, 9.2);
		amplitude *= 0.5;
	}
	return total;
}

void vertex() {
	// Upright, turned about its upright toward the camera.
	vec3 right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 facing = cross(right, up);
	float width = length(MODEL_MATRIX[0].xyz);
	float height = length(MODEL_MATRIX[1].xyz);
	vec3 at = MODEL_MATRIX[3].xyz;
	vec3 corner = at + right * VERTEX.x * width + up * (VERTEX.y + 0.5) * height;
	// (Drawn a little toward the camera so the floor does not clip its root.)
	corner += INV_VIEW_MATRIX[2].xyz * 0.4;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(corner, 1.0);
	NORMAL = facing;
}

vec3 heat_color(float heat) {
	vec3 ember = vec3(0.45, 0.06, 0.01);
	vec3 flame = vec3(1.0, 0.36, 0.04);
	vec3 bright = vec3(1.0, 0.68, 0.2);
	vec3 core = vec3(1.0, 0.84, 0.5);
	vec3 color = mix(ember, flame, smoothstep(0.1, 0.4, heat));
	color = mix(color, bright, smoothstep(0.4, 0.7, heat));
	return mix(color, core, smoothstep(0.75, 1.0, heat));
}

void fragment() {
	vec2 uv = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y);
	float t = flame_time;
	// The flame rises through the noise, faster than the noise drifts aside,
	// and the higher it is the more it wavers.
	float rise = fbm(vec2(uv.x * 1.6 + seed, uv.y * 2.2 - t * 2.4));
	float tear = fbm(vec2(uv.x * 4.2 - seed, uv.y * 3.0 - t * 4.1));
	float waver = (rise - 0.5) * 1.1 * uv.y;
	float x = uv.x + waver;
	// Broad at its root, narrowing to its tips, and split across into
	// tongues of uneven height.
	float tongues = 0.45 + 1.1 * noise(vec2(x * 3.0 + seed, uv.y * 1.5 - t * 3.0));
	float width = mix(0.8, 0.05, pow(uv.y, 0.7)) * tongues * (0.55 + 0.45 * smoothstep(0.0, 0.25, uv.y));
	float shape = abs(x) / max(width, 0.02) + (tear - 0.5) * 1.6 * uv.y;
	float body = 1.0 - smoothstep(0.6, 1.0, shape);
	float root = smoothstep(0.0, 0.3, uv.y + (tear - 0.5) * 0.25);
	float heat = clamp((1.0 - shape) * 0.9 - uv.y * 0.6 + (tear - 0.5) * 0.6 + 0.15, 0.0, 1.0);
	ALBEDO = heat_color(heat) * (1.0 + heat * 0.8);
	ALPHA = clamp(body * root * strength * (0.3 + heat * 0.8), 0.0, 1.0);
}
