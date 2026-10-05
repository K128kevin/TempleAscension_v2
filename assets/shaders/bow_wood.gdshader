shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// The ranger's longbow, worked in detail over the model's own palette: the
// limbs of yew, dark heartwood and pale sapwood streaked together in grain
// running down their length, darker toward the tips, which are capped in
// black horn; thread whipped round the limbs either side of a grip of dark
// leather wrapped in a spiral. The string keeps its palette colour. In the
// model's own (unit) space, where the bow runs up y from 0 to 1.
uniform sampler2D palette : source_color, filter_linear;

varying vec3 bow_position;

float hash2(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1, 0)), f.x), mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	bow_position = VERTEX;
}

// An item of another make (scripts/items.gd `tint`): its colours redrawn in
// that one, keeping their light and dark.
uniform vec3 tint : source_color = vec3(1.0);
uniform float recolor = 0.0;

void fragment() {
	vec3 p = bow_position;
	vec3 base = texture(palette, UV).rgb;
	float saturation = max(base.r, max(base.g, base.b)) - min(base.r, min(base.g, base.b));
	// How far out along a limb, from the grip (0) to the tip (1).
	float out_along = abs(p.y - 0.5) * 2.0;
	vec3 color = base;
	float rough = 0.55;
	float h = 0.0;
	if (saturation > 0.1) {
		// Yew: grain in long streaks that wander a little across the limb.
		float across = p.x * 9.0 + p.z * 7.0;
		float streak = noise2(vec2(across * 6.0 + noise2(vec2(p.y * 6.0, across)) * 2.0, p.y * 2.5));
		float fine = noise2(vec2(across * 40.0, p.y * 12.0));
		vec3 sap = vec3(0.62, 0.46, 0.28);
		vec3 heart = vec3(0.34, 0.17, 0.08);
		// Dark heartwood and pale sapwood run together in the streaks.
		color = mix(heart, sap, 0.3 + streak * 0.45) * (0.85 + streak * 0.2) * (0.92 + fine * 0.12);
		// Handled darker toward the grip, weathered darker toward the tips.
		color *= 1.0 - 0.18 * smoothstep(0.55, 0.9, out_along) - 0.12 * smoothstep(0.25, 0.1, out_along);
		h = streak * 0.0006 + fine * 0.0002;
		rough = 0.45 + fine * 0.15;
		// Thread whipped round the limb either side of the grip.
		float whip = abs(out_along - 0.27);
		if (whip < 0.03) {
			float turns = fract(p.y * 220.0);
			color = vec3(0.55, 0.5, 0.42) * (0.75 + 0.35 * smoothstep(0.0, 0.5, turns) * smoothstep(1.0, 0.5, turns));
			h = 0.0008 * sin(turns * 6.28318);
			rough = 0.8;
		}
		// Horn nocks at the tips.
		if (out_along > 0.94) {
			color = vec3(0.05, 0.04, 0.035) * (0.9 + fine * 0.3);
			rough = 0.3;
			h = 0.0;
		}
	} else if (base.r < 0.45) {
		// The grip: dark leather wrapped in a spiral, each turn raised.
		float turns = fract(p.y * 70.0 + atan(p.x + 0.38, p.z) * 0.32);
		float ridge = smoothstep(0.0, 0.18, turns) * smoothstep(1.0, 0.82, turns);
		color = vec3(0.15, 0.09, 0.055) * (0.65 + 0.45 * ridge) * (0.9 + noise2(p.xy * 300.0) * 0.2);
		h = 0.0012 * ridge;
		rough = 0.75;
	}
	ALBEDO = color;
	ROUGHNESS = rough;
	vec3 sx = dFdx(VERTEX);
	vec3 sy = dFdy(VERTEX);
	vec3 r1 = cross(sy, NORMAL);
	vec3 r2 = cross(NORMAL, sx);
	float det = dot(sx, r1);
	vec3 gradient = (dFdx(h) * r1 + dFdy(h) * r2) * sign(det) / max(abs(det), 0.000001);
	NORMAL = normalize(NORMAL - gradient);
	ALBEDO = mix(ALBEDO, dot(ALBEDO, vec3(0.299, 0.587, 0.114)) * tint * 1.8, recolor);
}
