shader_type spatial;
// The hero burned through by the basement's lasers (scripts/ash_death.gd):
// in place of every part of him, flesh and kit gone molten red and yellow
// (`heat`, 1) and cooling to char crazed with glowing cracks (0), crumbling
// away from the head down. Where it is about to go it glows orange, like the
// edge of burning paper. `progress` takes it from whole (0) to gone (1);
// `ground` and `height` place the figure in the world.
render_mode cull_disabled;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float ground = 0.0;
uniform float height = 2.0;
// How hot the cracks still are (1, burning; 0, out).
uniform float glow = 1.0;
uniform float heat = 0.0;
varying vec3 world;

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

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float up = clamp((world.y - ground) / height, 0.0, 1.0);
	vec2 p = vec2(world.x * 6.0 + world.y * 3.1, world.z * 6.0 - world.y * 4.7);
	float grain = fbm(p);
	// Highest first, broken up so that it falls away in flakes.
	float order = up * 0.62 + grain * 0.38;
	float cut = 1.0 - progress * 1.2;
	if (order > cut) {
		discard;
	}
	float edge = smoothstep(cut - 0.09, cut, order);
	float crack = smoothstep(0.04, 0.0, abs(noise(p * 3.3) - 0.5));
	vec3 char = vec3(mix(0.035, 0.13, grain)) * vec3(1.0, 0.88, 0.78);
	// A dusting of pale ash over the char.
	char = mix(char, vec3(0.36, 0.35, 0.34), smoothstep(0.78, 0.9, noise(p * 6.1 + 2.0)) * 0.55);
	// Molten: red, flaring yellow where the grain runs hottest, darker in its
	// cracks, all of it giving off its own light.
	vec3 molten = mix(vec3(0.75, 0.08, 0.02), vec3(1.0, 0.72, 0.18), smoothstep(0.35, 0.75, grain + 0.25 * noise(p * 1.7 + TIME * 3.0)));
	molten *= 1.0 - 0.6 * crack;
	ALBEDO = mix(char, molten * 0.4, heat);
	ROUGHNESS = 1.0;
	EMISSION = vec3(1.0, 0.36, 0.08) * (edge * 3.5 + crack * 0.9 * glow) + molten * heat * 2.2;
}
