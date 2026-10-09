shader_type spatial;
// A bandit killed by fire or lightning (scripts/visual.gd scorch): drawn over
// every part of him, multiplying what is under it down to soot. Skin, cloth
// and leather alike go blistered black, a few patches burnt through to a
// dull brown-black, the odd fleck of grey ash left on top. `amount` takes it
// from nothing (unchanged) to fully charred as the fire takes him.
render_mode unshaded, blend_mul, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform float seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
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
		p *= 2.03;
		weight *= 0.5;
	}
	return total;
}

void fragment() {
	vec2 p = UV * 22.0 + vec2(seed * 7.3, seed * 3.1);
	float soot = fbm(p);
	// Blistered, crazed char: dark cells split by finer, darker cracks.
	float crack = smoothstep(0.03, 0.0, abs(noise(p * 3.1) - 0.5));
	float scorched = mix(0.05, 0.17, soot) * (1.0 - 0.6 * crack);
	vec3 char = vec3(scorched) * vec3(1.0, 0.86, 0.74);
	// Here and there it is burnt through to a deeper brown-black,
	float through = smoothstep(0.55, 0.7, fbm(p * 0.45 + 11.0));
	char = mix(char, vec3(0.1, 0.055, 0.03), through * 0.7);
	// and flecked with ash.
	float ash = smoothstep(0.82, 0.9, noise(p * 5.7 + 3.0));
	char = mix(char, vec3(0.32, 0.31, 0.3), ash * 0.6);
	ALBEDO = mix(vec3(1.0), char, amount);
}
