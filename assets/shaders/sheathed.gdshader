shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// A dagger carried in its sheath, hilt up (tools/outfit_hero.py). Laid on its
// rest pose (CUSTOM0, from Art.rest_pose_mesh), where it stands upright from
// its point (`point_height`) to its pommel (`pommel_height`): the blade, from
// `blade_start` of the way down, is clad in a sheath a little thicker than it
// of dark tooled leather with a stitched spine, a bronze throat and chape and
// a strap loop; the grip is wrapped in leather, the guard and pommel steel.
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform float pommel_height = 1.0;
uniform float point_height = 0.0;
uniform float blade_start = 0.39;
uniform bool rest_pose = true;

varying float along;
varying vec3 rest;

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
	rest = rest_pose ? CUSTOM0.xyz : VERTEX;
	along = clamp((pommel_height - rest.y) / max(0.001, pommel_height - point_height), 0.0, 1.0);
	// The sheath stands a little proud of the blade within it.
	VERTEX += NORMAL * 0.003 * step(blade_start, along);
}

void fragment() {
	vec3 c = texture(albedo_texture, UV).rgb;
	float h = 0.0;
	float rough = 0.6;
	float metal = 0.0;
	float grain = noise2(rest.xy * 900.0 + rest.z * 400.0);
	vec3 leather = vec3(0.19, 0.105, 0.055) * (0.82 + noise2(rest.yz * 120.0) * 0.35);
	vec3 bronze = mix(vec3(0.42, 0.29, 0.13), vec3(0.62, 0.46, 0.24), noise2(rest.xy * 300.0));
	if (along >= blade_start) {
		// The sheath: tooled diamonds down its face, a stitched spine.
		float s = (along - blade_start) / (1.0 - blade_start);
		vec2 q = vec2(rest.x + rest.z, rest.y) * 140.0;
		float diamond = min(abs(fract(q.x + q.y) - 0.5), abs(fract(q.x - q.y) - 0.5));
		c = leather * (0.85 + 0.25 * smoothstep(0.02, 0.12, diamond)) * (0.94 + grain * 0.1);
		h = 0.0005 * smoothstep(0.02, 0.12, diamond);
		rough = 0.85;
		// A strap loop a third of the way down.
		if (abs(s - 0.3) < 0.05) { c = vec3(0.13, 0.075, 0.045); h = 0.0012; }
		// The bronze throat and chape.
		if (s < 0.08 || s > 0.86) {
			c = bronze * (s > 0.86 ? 0.9 : 1.0);
			metal = 0.9;
			rough = 0.35;
			h = 0.001;
		}
	} else if (along > 0.07 && along < 0.29) {
		// The grip, wrapped in leather.
		float turns = fract(along * 60.0 + atan(rest.x, rest.z) * 0.16);
		c = vec3(0.17, 0.1, 0.06) * (0.65 + 0.45 * smoothstep(0.0, 0.2, turns) * smoothstep(1.0, 0.8, turns));
		h = 0.0006 * smoothstep(0.0, 0.2, turns);
		rough = 0.8;
	} else {
		// The guard and pommel: worn steel.
		c = vec3(0.55, 0.56, 0.58) * (0.75 + grain * 0.35);
		metal = 1.0;
		rough = 0.35;
	}
	ALBEDO = c;
	METALLIC = metal * 0.45;
	ROUGHNESS = rough;
	vec3 sx = dFdx(VERTEX);
	vec3 sy = dFdy(VERTEX);
	vec3 r1 = cross(sy, NORMAL);
	vec3 r2 = cross(NORMAL, sx);
	float det = dot(sx, r1);
	vec3 gradient = (dFdx(h) * r1 + dFdy(h) * r2) * sign(det) / max(abs(det), 0.000001);
	NORMAL = normalize(NORMAL - gradient);
}
