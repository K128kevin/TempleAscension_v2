shader_type spatial;
// The arena basement's floor (scripts/temple.gd dirt_material): old dirt,
// trodden hard, nowhere the same from one stretch to the next. Over the
// gravelly ground (`ground`, sampled twice at scales and turns that never
// line up, so it shows no repeat) lie broad patches darker and damper, where
// it shines a little; paler, dustier drifts; dark stains spilt and soaked in;
// and scattered grit and small stones. Everything is placed by where it
// lies in the world.
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D ground : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D ground_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D grit : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 earth : source_color = vec3(0.3, 0.26, 0.22);
uniform vec3 damp : source_color = vec3(0.16, 0.12, 0.09);
uniform vec3 dust : source_color = vec3(0.46, 0.42, 0.37);
uniform vec3 stain : source_color = vec3(0.11, 0.08, 0.06);
varying vec3 world;

// (No sine: it loses its precision this far out in the world.)
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
	float weight = 0.5;
	for (int i = 0; i < 4; i++) {
		total += noise(p) * weight;
		p = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6)) * p;
		weight *= 0.5;
	}
	return total;
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world.xz;
	// The gravel, twice over and turned, so no tile of it repeats.
	vec2 turned = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p;
	vec3 gravel = mix(texture(ground, p * 0.55).rgb, texture(ground, turned * 0.21 + 0.37).rgb, 0.45);
	float shade = dot(gravel, vec3(0.33));
	vec3 colour = earth * (0.35 + 1.3 * shade);
	// Broad patches: darker and damp, or paler with dust.
	float wet = smoothstep(0.52, 0.72, fbm(p * 0.09 + 3.1));
	float dry = smoothstep(0.55, 0.75, fbm(p * 0.12 + 17.3)) * (1.0 - wet);
	colour = mix(colour, damp * (0.8 + 0.5 * shade), wet * 0.75);
	colour = mix(colour, dust * (0.75 + 0.4 * shade), dry * 0.45);
	// Smaller blotches and spilt stains, soaked in.
	float blotch = fbm(p * 0.6 + 41.0);
	colour *= 0.55 + 0.9 * blotch;
	// Scuffs and smears, a pace or so across.
	float smear = smoothstep(0.5, 0.8, fbm(vec2(p.x * 1.7, p.y * 0.8) + 23.0));
	colour = mix(colour, damp * 0.9, smear * 0.35);
	float spill = smoothstep(0.66, 0.74, fbm(p * 0.35 + 9.7));
	colour = mix(colour, stain, spill * 0.6);
	// Grit and small stones.
	float stones = texture(grit, p * 0.9).r;
	colour *= mix(1.15, 0.5, smoothstep(0.5, 0.8, stones));
	float pebble = smoothstep(0.93, 0.97, hash(floor(p * 7.0)) * noise(p * 7.0 + 0.5));
	colour = mix(colour, dust * 0.7, pebble * 0.6);
	ALBEDO = colour;
	ROUGHNESS = mix(0.95, 0.62, wet);
	NORMAL_MAP = texture(ground_normal, p * 0.55).rgb;
	NORMAL_MAP_DEPTH = 1.6 * (1.0 - wet * 0.6);
}
