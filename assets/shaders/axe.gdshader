shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// The head of the warrior's bearded axe (tools/make_axe.py): forged, dark
// steel, hammer-marked and oxidised, its cheek etched with curling
// scrollwork; toward the cutting edge the steel is ground to a bright
// polished bevel, brushed along the edge, with a hairline of light at the
// edge itself. The blade's UVs say where a point lies: U from the eye (0)
// to the edge (1), V along the edge from the horn to the beard. The eye
// block has no UVs (0,0): plain forged steel.
uniform vec3 steel : source_color = vec3(0.42, 0.44, 0.48);
uniform vec3 bright : source_color = vec3(0.86, 0.88, 0.91);
// An item of another make: its steel recoloured, keeping light and dark.
uniform vec3 tint : source_color = vec3(1.0);
uniform float recolor = 0.0;

varying vec3 local;
varying vec2 blade_uv;

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

float fbm2(vec2 p) {
	float total = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		total += noise2(p) * amplitude;
		p = p * 2.03 + vec2(5.2, 1.3);
		amplitude *= 0.5;
	}
	return total / 0.9375;
}

void vertex() {
	local = VERTEX;
	blade_uv = UV;
}

void fragment() {
	// (The model is a unit box: its coordinates are scaled up here to
	// something like metres for the marks' sizes.)
	vec2 p = vec2(local.x * 0.24, local.y * 0.72) * 40.0 + local.z * 7.0;
	float dents = fbm2(p * 1.6);
	float grain = noise2(p * 14.0);
	float patina = smoothstep(0.5, 0.78, fbm2(p * 0.7 + 9.0));
	vec3 dark = steel * (0.8 + dents * 0.3) * (0.94 + grain * 0.1);
	dark = mix(dark, steel * 0.55, patina * 0.6);
	float rough = 0.42 + dents * 0.15 + patina * 0.25;
	// The scrollwork etched into the cheek: the contour of a soft noise,
	// drawn thin and dark, fading before the bevel and the eye.
	float field = fbm2(blade_uv * vec2(6.0, 9.0) + 3.7);
	float line = 1.0 - smoothstep(0.0, 0.025, abs(field - 0.5));
	float line2 = 1.0 - smoothstep(0.0, 0.02, abs(field - 0.36));
	float etched = max(line, line2 * 0.8) * smoothstep(0.08, 0.2, blade_uv.x) * (1.0 - smoothstep(0.5, 0.62, blade_uv.x));
	dark *= 1.0 - 0.55 * etched;
	// The bevel, ground bright, with fine brush marks along the edge and a
	// hairline of light at the edge itself.
	float bevel = smoothstep(0.6, 0.76, blade_uv.x);
	float brush = 0.92 + 0.08 * noise2(vec2(blade_uv.y * 180.0, blade_uv.x * 6.0));
	vec3 polished = bright * brush * (0.97 + 0.03 * grain);
	float hairline = smoothstep(0.975, 1.0, blade_uv.x);
	polished = mix(polished, vec3(1.0), hairline * 0.6);
	vec3 color = mix(dark, polished, bevel);
	ALBEDO = mix(color, dot(color, vec3(0.299, 0.587, 0.114)) * tint * 1.8, recolor);
	METALLIC = mix(0.55, 0.92, bevel);
	ROUGHNESS = mix(clamp(rough, 0.3, 0.85), 0.16 + 0.06 * brush, bevel);
	SPECULAR = 0.5;
}
