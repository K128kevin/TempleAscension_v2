shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// A town guard's armor (tools/make_guard.py): the KayKit Knight's plates, read
// through the knight's own palette only to know what each part is made of,
// and finished as the real thing. Its greys are hammered steel, dented,
// scratched bright, darkened and rusting in patches; its gold is bronze trim;
// its reds are a soldier's red wool; the rest is oiled leather. All of it
// carries the road's dust, worst low down. Laid on the armor's rest pose
// (CUSTOM0, from Art.rest_pose_mesh), so the wear stays put as he moves.
uniform sampler2D palette : source_color, filter_nearest;
uniform sampler2D grit : source_color, filter_linear_mipmap, repeat_enable;
uniform bool rest_pose = false;
// A little different on each man.
uniform float seed = 0.0;

varying vec3 rest;
varying vec3 rest_normal;

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

float noise3(vec3 p) {
	return mix(noise2(p.xy + floor(p.z) * 17.0), noise2(p.xy + (floor(p.z) + 1.0) * 17.0), smoothstep(0.0, 1.0, fract(p.z)));
}

// The grit photograph laid over the rest pose from its three sides.
float photo(vec3 p, vec3 n, float scale) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= max(dot(w, vec3(1.0)), 0.0001);
	return texture(grit, p.yz * scale).r * w.x + texture(grit, p.xz * scale).r * w.y + texture(grit, p.xy * scale).r * w.z;
}

void vertex() {
	rest = rest_pose ? CUSTOM0.xyz : VERTEX;
	rest_normal = rest_pose ? CUSTOM1.xyz : NORMAL;
}

void fragment() {
	if (!FRONT_FACING) NORMAL = -NORMAL;
	vec3 p = rest + vec3(seed * 1.7, 0.0, seed * 0.9);
	vec3 base = texture(palette, UV).rgb;
	float lit = dot(base, vec3(0.299, 0.587, 0.114));
	float spread = max(base.r, max(base.g, base.b)) - min(base.r, min(base.g, base.b));
	float dust = photo(p, rest_normal, 3.1) * 0.6 + photo(p, rest_normal, 9.0) * 0.4;
	vec3 colour;
	float rough;
	float metal = 0.0;
	if (spread < 0.1) {
		// Steel: hammered, grained, oxidised dark in patches, rusting in
		// specks and scratched bright every which way. The palette's darker
		// greys are the blackened iron of straps and rims.
		float dents = noise3(p * 55.0);
		float grain = noise2(vec2(p.x + p.z, p.y) * 900.0);
		float patina = smoothstep(0.45, 0.75, noise3(p * 14.0 + 3.0));
		colour = vec3(0.58, 0.59, 0.6) * mix(0.45, 1.05, smoothstep(0.1, 0.8, lit)) * (0.82 + dents * 0.22) * (0.95 + grain * 0.08);
		colour = mix(colour, vec3(0.3, 0.29, 0.27), patina * 0.55);
		float rust = smoothstep(0.8, 0.92, noise3(p * 60.0 + 11.0)) * smoothstep(0.5, 0.85, noise3(p * 9.0));
		colour = mix(colour, vec3(0.34, 0.19, 0.1), rust * 0.85);
		float scratch = max(smoothstep(0.92, 0.97, noise2(vec2(p.x * 700.0 + p.y * 120.0, p.y * 25.0 + p.z * 40.0))), smoothstep(0.93, 0.97, noise2(vec2(p.y * 650.0 - p.z * 200.0, p.x * 30.0))));
		colour = mix(colour, vec3(0.8, 0.81, 0.82), scratch * 0.6);
		rough = 0.32 + dents * 0.12 + patina * 0.25 + rust * 0.4 - scratch * 0.1;
		metal = 0.45;
	} else if (base.r > 0.75 && base.g > 0.55 && base.b < 0.5) {
		// Bronze trim, dulled brown and green where it is not rubbed.
		float rub = noise3(p * 40.0);
		colour = mix(vec3(0.42, 0.28, 0.12), vec3(0.68, 0.5, 0.25), smoothstep(0.35, 0.8, rub));
		colour = mix(colour, vec3(0.25, 0.32, 0.24), smoothstep(0.7, 0.9, noise3(p * 22.0 + 5.0)) * 0.6);
		rough = 0.45 + 0.25 * (1.0 - rub);
		metal = 0.5;
	} else if (base.g < 0.3 && base.r > 0.35 && base.r > base.g * 1.8) {
		// A soldier's red wool, faded by the sun and frayed.
		float weave = noise2(vec2(p.x + p.z, p.y) * 520.0) * 0.5 + noise2(vec2(p.y, p.x - p.z) * 520.0) * 0.5;
		colour = vec3(0.4, 0.07, 0.07) * (0.75 + weave * 0.45) * mix(0.8, 1.15, lit);
		colour = mix(colour, vec3(0.45, 0.25, 0.22), smoothstep(0.4, 0.8, noise3(p * 7.0)) * 0.35);
		rough = 0.95;
	} else {
		// Oiled leather: straps, belts and linings, creased and scuffed.
		float crease = noise3(p * vec3(30.0, 120.0, 30.0));
		float scuff = smoothstep(0.65, 0.85, noise3(p * 48.0 + 2.0));
		colour = mix(vec3(0.2, 0.12, 0.07), vec3(0.36, 0.22, 0.12), lit) * (0.8 + crease * 0.35);
		colour = mix(colour, vec3(0.45, 0.33, 0.22), scuff * 0.45);
		rough = 0.7 + scuff * 0.2;
	}
	// The road's dust, ground into it, heaviest low down.
	float low = 1.0 - smoothstep(0.1, 0.9, rest.y);
	float grime = smoothstep(0.42, 0.75, dust + low * 0.25) * (0.35 + 0.45 * low);
	colour = mix(colour, colour * vec3(0.55, 0.47, 0.38) + vec3(0.05, 0.04, 0.03), grime);
	ALBEDO = colour;
	ROUGHNESS = clamp(rough + grime * 0.3, 0.0, 1.0);
	METALLIC = metal * (1.0 - grime * 0.6);
	SPECULAR = 0.35;
}
