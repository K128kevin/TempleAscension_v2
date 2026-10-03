shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// A lump of burning charcoal in the smithy's forge (scripts/world_interiors.gd):
// a log burnt to blue-black, its skin split into small blocks along the
// grain, the splits glowing orange, hottest underneath where it lies on the
// fire and fading to dead ash-grey up its top. Each lump differs by where it
// lies.
uniform vec3 hot : source_color = vec3(1.0, 0.36, 0.05);
uniform float glow = 3.0;
// The height (world) of the fire the lumps lie on, and how far above it the
// heat reaches.
uniform float bed = 0.95;
uniform float reach = 0.2;
varying vec3 grain_position;
varying vec3 world_position;
varying float seed;

float hash3(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// The random value of the cell around `p`, and the distance to its border.
float cell(vec3 p, out float border) {
	vec3 c = floor(p);
	vec3 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	vec3 nearest = c;
	for (int x = -1; x <= 1; x++)
	for (int y = -1; y <= 1; y++)
	for (int z = -1; z <= 1; z++) {
		vec3 o = vec3(float(x), float(y), float(z));
		vec3 r = o + hash33(c + o) * 0.8 + 0.1 - f;
		float d = dot(r, r);
		if (d < d1) { d2 = d1; d1 = d; nearest = c + o; }
		else if (d < d2) { d2 = d; }
	}
	border = sqrt(d2) - sqrt(d1);
	return hash3(nearest + 7.1);
}

void vertex() {
	seed = hash3(floor(NODE_POSITION_WORLD * 37.0));
	// The mesh is a cylinder along its Y: blocks are longer across the grain
	// than along it, as charcoal splits.
	grain_position = VERTEX * vec3(1.0, 0.55, 1.0) + seed * 17.0;
	// Burnt unevenly: the skin bulges and sinks (by position alone, so the
	// caps' edges move with the sides' and the mesh stays closed).
	float lumpy = noise(VERTEX * 30.0 + seed * 31.0) - 0.5;
	VERTEX.xz *= 1.0 + lumpy * 0.3;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float split;
	float block = cell(grain_position * 24.0, split);
	float fine;
	cell(grain_position * 60.0, fine);
	// Blue-black char, greyer and ashen on some blocks and on the high faces.
	vec3 up = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float ash = smoothstep(0.75, 1.0, block) * 0.45 + smoothstep(0.5, 1.0, up.y) * 0.12;
	vec3 albedo = mix(vec3(0.03, 0.033, 0.042), vec3(0.17, 0.18, 0.22), clamp(ash, 0.0, 1.0));
	float crack = 1.0 - smoothstep(0.015, 0.07, split);
	float hair = 1.0 - smoothstep(0.005, 0.03, fine);
	albedo *= 1.0 - crack * 0.85 - hair * 0.4;
	// Each block a little its own shade, and tilted its own way to the light.
	albedo *= 0.75 + 0.5 * fract(block * 13.7);
	ALBEDO = albedo;
	vec3 tilt = (vec3(fract(block * 7.3), fract(block * 3.1), fract(block * 5.9)) - 0.5) * 0.5;
	NORMAL = normalize(NORMAL + tilt * (1.0 - crack));
	ROUGHNESS = 0.92;
	SPECULAR = 0.2;
	// Heat: from the fire below, and on the lump's underside.
	float low = 1.0 - smoothstep(0.0, reach, world_position.y - bed);
	float under = smoothstep(0.2, -0.7, up.y);
	float heat = clamp(low * low * 0.9 + under * 0.5, 0.0, 1.0);
	float breath = 0.7 + 0.3 * sin(TIME * (0.6 + seed * 1.1) + block * 6.0 + seed * 40.0);
	// The splits glow where it is hot; the hottest blocks glow through.
	float lit = crack * heat + hair * heat * heat * 0.5 + smoothstep(0.7, 1.0, heat) * smoothstep(0.35, 0.0, block) * 0.5;
	lit *= breath;
	EMISSION = hot * lit * glow + vec3(1.0, 0.7, 0.3) * pow(crack * heat * breath, 3.0) * glow * 0.7;
}
