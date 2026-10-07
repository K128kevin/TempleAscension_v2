shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Lightning Shield's bubble (scripts/shield_bubble.gd): a thin, translucent
// shell of light, clear where it faces the eye and brighter toward its rim,
// with faint currents drifting over it. `flare` (0 to 1) lights it up round
// `hit_dir` (a direction from its middle, in its own space) as a blow is
// absorbed there. `shell_time` is driven by the combat clock.
uniform float shell_time = 0.0;
uniform float flare = 0.0;
uniform vec3 hit_dir = vec3(0.0, 0.0, 1.0);
uniform vec4 tint : source_color = vec4(0.45, 0.7, 1.0, 1.0);
// 1 while it holds, falling to 0 as it gives out.
uniform float strength = 1.0;

varying vec3 around;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	around = normalize(VERTEX);
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), VIEW));
	float rim = pow(1.0 - facing, 2.6);
	// Faint currents: thin bands of light wandering slowly over the shell.
	float drift = noise(around * 3.0 + vec3(0.0, shell_time * 0.4, shell_time * 0.25));
	float bands = pow(0.5 + 0.5 * sin(drift * 18.0 + shell_time * 1.5), 12.0);
	float shell = 0.012 + rim * 0.42 + bands * (0.02 + rim * 0.15);
	// Lit up where a blow lands, and a little all over.
	float struck = pow(max(dot(around, normalize(hit_dir)), 0.0), 7.0);
	shell += flare * (struck * 0.4 + 0.03);
	// (Its far side, seen through it, dimmer.)
	shell *= FRONT_FACING ? 1.0 : 0.45;
	ALBEDO = tint.rgb * shell * strength;
}
