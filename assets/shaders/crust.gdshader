shader_type spatial;
// A loaf's crust (scripts/bread_cart.gd loaf): baked a deep brown, darker on
// top where the oven was hottest, paler and floury toward its foot, crazed
// with fine cracks and scored across its top, pale crumb showing in the cuts.
render_mode diffuse_burley;
varying vec3 local;

float hash(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}
float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	local = VERTEX;
}

void fragment() {
	float up = clamp(local.y / 0.05, -1.0, 1.0);
	vec3 baked = mix(vec3(0.62, 0.4, 0.17), vec3(0.42, 0.24, 0.09), smoothstep(-0.2, 0.9, up));
	baked = mix(baked, vec3(0.78, 0.66, 0.48), smoothstep(-0.3, -0.9, up) * 0.6);
	float crazed = noise(local * 260.0);
	baked *= 0.85 + 0.25 * crazed;
	// Scored across the top: three cuts, the crumb showing pale in them.
	float cut = abs(fract(local.z * 22.0 + local.x * 6.0) - 0.5);
	float scored = (1.0 - smoothstep(0.04, 0.09, cut)) * smoothstep(0.4, 0.8, up);
	baked = mix(baked, vec3(0.86, 0.74, 0.52), scored * 0.8);
	ALBEDO = baked;
	ROUGHNESS = 0.75;
}
