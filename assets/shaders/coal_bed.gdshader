shader_type spatial;
render_mode unshaded, cull_disabled;

// The fire under the smithy forge's charcoal (scripts/world_interiors.gd):
// a bed of small embers glowing yellow-orange between the lumps, some gone
// to grey ash, the glow drifting and breathing.
uniform vec3 hot : source_color = vec3(1.0, 0.38, 0.06);
uniform vec3 white_hot : source_color = vec3(1.0, 0.78, 0.38);
uniform float glow = 1.6;
varying vec3 world_position;

float hash2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1, 0)), f.x), mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	float drift = noise(p * 3.0 + vec2(TIME * 0.15, -TIME * 0.11)) * 0.6 + noise(p * 9.0 - TIME * 0.3) * 0.4;
	float grit = noise(p * 40.0);
	float ash = smoothstep(0.55, 0.8, noise(p * 14.0 + 5.3)) * 0.8;
	float heat = clamp(drift * 1.3 - 0.15, 0.0, 1.0) * (0.75 + grit * 0.5);
	// Fade out toward the bed's edge.
	float edge = smoothstep(0.5, 0.25, max(abs(UV.x - 0.5), abs(UV.y - 0.5)));
	vec3 fire = mix(hot, white_hot, smoothstep(0.55, 1.0, heat)) * heat * glow;
	vec3 grey = vec3(0.09, 0.085, 0.08) * (0.6 + grit * 0.6);
	ALBEDO = mix(mix(fire, grey, ash), vec3(0.07, 0.065, 0.06) * (0.6 + grit * 0.6), 1.0 - edge);
}
