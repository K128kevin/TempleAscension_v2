shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// The warrior's round shield, after his concept art, worked in steel: a
// riveted rim, a Greek-key (meander) band, a sunburst of long petals, and a
// domed boss with a lion's head in relief. Drawn from the prepared shield
// model's own space (tools/prepare_models.py: centred on X, 0..1 on Y, its
// faces looking along Z), so it is fixed to the shield.
uniform vec3 steel : source_color = vec3(0.5, 0.51, 0.53);

varying vec3 local;

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

float fbm2(vec2 p) {
	float t = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) { t += noise2(p) * a; p = p * 2.03 + 7.1; a *= 0.5; }
	return t / 0.9375;
}

// Relief height (0..1) and an engraving mask at a point of the face.
vec2 relief(vec2 q) {
	float r = length(q);
	float a = atan(q.y, q.x);
	float h = 0.15;
	float cut = 0.0;
	if (r > 0.92) {
		// The rolled rim, with rivets.
		h = 0.7 + 0.25 * sin((r - 0.92) / 0.08 * 3.14159);
		float rv = abs(fract(a / 6.28318 * 40.0) - 0.5);
		if (abs(r - 0.955) < 0.018 && rv < 0.12) h += 0.35;
	} else if (r > 0.76) {
		// The Greek key: a running meander in a raised band.
		float u = fract(a / 6.28318 * 48.0);
		float v = (r - 0.76) / 0.16;
		bool line = v < 0.12 || v > 0.88
			|| (u < 0.12 && v < 0.75)
			|| (u > 0.12 && u < 0.62 && v > 0.63 && v < 0.75)
			|| (u > 0.5 && u < 0.62 && v > 0.25 && v < 0.75)
			|| (u > 0.3 && u < 0.62 && v > 0.25 && v < 0.37)
			|| (u > 0.3 && u < 0.42 && v > 0.25 && v < 0.55);
		h = line ? 0.5 : 0.25;
		cut = line ? 0.0 : 0.6;
	} else if (r > 0.34) {
		// A sunburst of long pointed petals.
		float petal = abs(fract(a / 6.28318 * 22.0) - 0.5) * 2.0;
		float width = mix(0.9, 0.05, (r - 0.34) / 0.42);
		h = petal < width ? 0.45 - petal * 0.2 : 0.2;
		cut = petal < width && petal > width - 0.12 ? 0.5 : 0.0;
	} else {
		// The boss: a dome with a lion's head, a ruffled mane round a face.
		float rr = r / 0.34;
		h = 0.55 + 0.35 * (1.0 - rr * rr);
		float mane = sin(a * 16.0 + fbm2(q * 30.0) * 4.0) * 0.5 + 0.5;
		if (rr > 0.5 && rr < 0.92) h += mane * 0.18;
		vec2 f = q / 0.34;
		float face = 1.0 - smoothstep(0.0, 0.5, length(f * vec2(1.0, 0.85)));
		h += face * 0.25;
		if (abs(abs(f.x) - 0.16) < 0.06 && abs(f.y - 0.12) < 0.05) h -= 0.2;
		if (rr > 0.92) h = 0.95;
	}
	return vec2(h, cut);
}

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec2 q = vec2(local.x, local.y - 0.5) * 2.0;
	vec2 rc = relief(q);
	float e = 0.004;
	float hx = relief(q + vec2(e, 0.0)).x;
	float hy = relief(q + vec2(0.0, e)).x;
	float wear = fbm2(q * 6.0);
	vec3 color = steel * (0.7 + rc.x * 0.5) * (0.85 + wear * 0.3);
	color *= 1.0 - rc.y * 0.45;
	// Rust and grime gather low and in the recesses.
	float rust = smoothstep(0.62, 0.8, fbm2(q * 9.0 + 3.0)) * (1.0 - rc.x);
	color = mix(color, vec3(0.34, 0.2, 0.12), rust * 0.6);
	ALBEDO = color;
	METALLIC = 0.75;
	ROUGHNESS = mix(0.38, 0.7, rust + rc.y * 0.4);
	// The relief bends the light; the shield's faces look along local Z.
	vec3 n = normalize(vec3(-(hx - rc.x) / e * 0.02, -(hy - rc.x) / e * 0.02, 1.0));
	vec3 world_n = normalize((MODEL_MATRIX * vec4(n.x, n.y, sign(local.z + 1e-4) * n.z, 0.0)).xyz);
	NORMAL = normalize(mix(NORMAL, normalize((VIEW_MATRIX * vec4(world_n, 0.0)).xyz), 0.8));
}
