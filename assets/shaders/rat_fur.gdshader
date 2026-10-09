shader_type spatial;
// The basement's rats (scripts/rats.gd), all of one mesh, each drawn by a
// one-instance MultiMesh and moved by its INSTANCE_CUSTOM: x its gait's phase (radians), y how
// hard it runs (0 still to 1 flat out), z its sniffing's phase, w its tail's.
// Running, its back humps and its legs scrabble; still, its head bobs and
// sniffs; its tail always swings a little, more as it runs. The mesh's UV.x
// runs down the tail (0 at its root to 1 at its tip, 0 elsewhere), UV.y marks
// a leg (.25, .5, .75, 1: front left, front right, hind left, hind right),
// UV2.x its bare skin (tail, ears, feet) from its fur, and UV2.y its eyes.
// Its coat is a dusty brown-grey, darker along the spine and paler on the
// belly, broken up by the lie of the fur. (Every part of it is closed, the
// ears made two-sided in the mesh, so its back faces are culled: drawn
// double-sided, the faces turned to this camera were lit as their backs.)
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
uniform vec3 fur_dark : source_color = vec3(0.15, 0.13, 0.11);
uniform vec3 fur_light : source_color = vec3(0.34, 0.29, 0.24);
uniform vec3 belly : source_color = vec3(0.44, 0.39, 0.33);
uniform vec3 skin : source_color = vec3(0.52, 0.39, 0.35);
// Where the head begins (metres forward of the body's middle).
const float NECK = 0.045;
varying vec3 local;
varying float bare;
varying float eye;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	local = VERTEX;
	bare = UV2.x;
	eye = UV2.y;
	float gait = INSTANCE_CUSTOM.x;
	float run = INSTANCE_CUSTOM.y;
	float sniff = INSTANCE_CUSTOM.z;
	float swing = INSTANCE_CUSTOM.w;
	vec3 v = VERTEX;
	// The back humps with each bound.
	float body = 1.0 - step(0.001, UV.x);
	v.y += run * 0.009 * abs(sin(gait)) * body * smoothstep(0.0, 0.03, v.y);
	// Legs: fore and hind pairs reaching out of step with each other.
	if (UV.y > 0.1) {
		float leg = UV.y;
		float offset = leg < 0.6 ? 0.0 : 3.1416;
		bool right = (leg > 0.4 && leg < 0.6) || leg > 0.9;
		offset += right ? 0.6 : 0.0;
		float reach = 1.0 - clamp(VERTEX.y / 0.032, 0.0, 1.0);
		v.z += sin(gait + offset) * 0.022 * run * reach;
		v.y += max(0.0, cos(gait + offset)) * 0.008 * run * reach;
	}
	// The head: bobbing and turning as it sniffs, when it is still.
	float head = smoothstep(NECK - 0.01, NECK + 0.02, VERTEX.z) * body;
	float still = 1.0 - run;
	v.y += head * still * (0.006 * sin(sniff * 2.3) + 0.004 * sin(sniff * 5.1));
	v.x += head * still * 0.008 * sin(sniff * 0.7);
	// The tail swings behind it, a wave running down it.
	float t = UV.x;
	v.x += sin(swing - t * 4.0) * 0.045 * t * (0.35 + 0.65 * run);
	VERTEX = v;
}

void fragment() {
	float grain = noise(local * vec3(260.0, 260.0, 90.0));
	float patch = noise(local * 45.0 + 3.0);
	vec3 coat = mix(fur_dark, fur_light, 0.35 + 0.4 * patch + 0.25 * grain);
	// Darker down the spine, paler underneath.
	coat = mix(coat, fur_dark * 0.8, smoothstep(0.022, 0.0, abs(local.x)) * smoothstep(0.045, 0.07, local.y) * 0.45);
	coat = mix(coat, belly, smoothstep(0.03, 0.016, local.y) * 0.7);
	vec3 bare_skin = skin * (0.8 + 0.25 * grain);
	// The tail's rings of scales, darker toward its root.
	bare_skin *= 0.85 + 0.15 * sin(local.z * 900.0);
	ALBEDO = mix(mix(coat, bare_skin, bare), vec3(0.015), eye);
	ROUGHNESS = mix(mix(0.82, 0.55, bare), 0.15, eye);
	SPECULAR = mix(mix(0.15, 0.3, bare), 0.7, eye);
}
