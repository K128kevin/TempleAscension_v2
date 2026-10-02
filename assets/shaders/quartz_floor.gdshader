shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Polished marble paving for the temple's rooms, drawn procedurally in world
// space so batched tiles stay continuous. One-metre slabs, each cut from a
// different part of the block: its veins run their own way, through a milky
// ground with soft clouding, bold veins with finer hairline veins branching
// off them and faint ghost veins deeper in the stone, and tiny crystalline
// flecks. Each slab's edges are softly bevelled down to a thin joint, so the
// light picks out every slab. Light enough that the dark stone statues read
// clearly against it; the colours are set by `quartz_color` and `vein_color`.
uniform vec3 quartz_color : source_color = vec3(0.70, 0.70, 0.72);
uniform vec3 vein_color : source_color = vec3(0.42, 0.44, 0.47);
// The joint between slabs, and the bevel falling to it (metres).
uniform float grout_width = 0.008;
uniform float bevel_width = 0.035;

float hash2(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(cell), hash2(cell + vec2(1, 0)), f.x),
		mix(hash2(cell + vec2(0, 1)), hash2(cell + vec2(1, 1)), f.x), f.y);
}

float cloud(vec2 p) {
	float total = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 5; i++) {
		total += noise(p) * amplitude;
		p = p * 2.03 + vec2(17.1, 9.4);
		amplitude *= 0.5;
	}
	return total / 0.97;
}

// A vein: a thin line where a warped band's phase crosses zero, `width` wide
// (in phase units).
float vein(vec2 q, float frequency, float width, float warp) {
	float phase = q.x * frequency + warp;
	float line = abs(fract(phase) - 0.5) * 2.0;
	return 1.0 - smoothstep(0.0, width, 1.0 - line);
}

void fragment() {
	// Multimesh-safe world position: VERTEX is view space in fragment().
	vec2 p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	// Slabs are centred on whole metres; each is its own piece of stone.
	vec2 tile = floor(p + 0.5);
	vec2 inside = fract(p + 0.5) - 0.5;
	float slab = hash2(tile * 1.37 + 4.1);
	float slab2 = hash2(tile * 2.91 + 7.3);
	// The slab's own grain: turned and shifted, so no two slabs match.
	float angle = slab * 6.2831;
	mat2 turn = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle)));
	vec2 q = turn * p + vec2(slab * 37.0, slab2 * 53.0);

	// The milky ground, softly clouded, each slab a touch lighter or darker.
	float milk = cloud(q * 0.9);
	float haze = cloud(q * 2.6 + 5.0);
	vec3 color = quartz_color * (0.88 + milk * 0.2 + haze * 0.06 + (slab - 0.5) * 0.07);

	// Drifts of cloudy veining through the stone (where the veins gather),
	// bold veins swelling and thinning as they wander through them, hairline
	// veins branching off at another slant, faint ghost veins deeper in the
	// stone, and pale quartz seams between.
	float drift = smoothstep(0.3, 0.7, cloud(q * 0.45 + 11.0));
	float warp = cloud(q * 0.7 + vec2(3.7, 1.9)) * 4.0 + cloud(q * 2.2) * 0.7;
	float swell = 0.02 + cloud(q * 1.3 + 4.0) * 0.06;
	float bold = vein(q, 0.55, swell, warp) * drift;
	float halo = vein(q, 0.55, swell * 5.0 + 0.08, warp) * drift;
	vec2 q2 = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * q;
	float hair_warp = cloud(q2 * 1.4 + 2.0) * 3.0 + warp * 0.35;
	float hair = vein(q2, 1.7, 0.025, hair_warp) * smoothstep(0.4, 0.7, cloud(q2 * 0.9 + 21.0));
	float ghost = vein(q * 0.8, 0.9, 0.18, warp * 0.8 + 1.3);
	vec2 q3 = mat2(vec2(0.6, -0.8), vec2(0.8, 0.6)) * q;
	float seam = vein(q3, 1.1, 0.03, cloud(q3 * 1.1 + 9.0) * 3.5) * smoothstep(0.5, 0.75, cloud(q3 * 0.6 + 31.0));
	color = mix(color, mix(color, vein_color, 0.45), cloud(q * 1.6 + 2.0) * drift * 0.35);
	color = mix(color, mix(quartz_color, vein_color, 0.5), ghost * 0.22);
	color = mix(color, mix(color, vein_color, 0.5), halo * 0.3);
	color = mix(color, vein_color * 0.9, bold * 0.75);
	color = mix(color, vein_color * 1.05, hair * 0.45);
	color = mix(color, quartz_color * 1.18 + 0.03, seam * 0.5);
	// Fine grain and tiny crystalline flecks.
	color *= 0.97 + noise(p * 160.0) * 0.06;
	float fleck = step(0.993, hash2(floor(p * 70.0)));
	color += vec3(fleck * 0.08);

	// The bevel: within `bevel_width` of an edge the slab's top rounds down
	// to the joint, its face turning out toward that edge.
	vec2 from_edge = 0.5 - abs(inside);
	vec2 outward = sign(inside);
	vec2 slope = vec2(0.0);
	for (int axis = 0; axis < 2; axis++) {
		float d = from_edge[axis];
		float u = clamp((bevel_width - d) / max(bevel_width - grout_width, 0.0001), 0.0, 1.0);
		// A rounded profile: flat at the top, steepening toward the edge.
		slope[axis] = outward[axis] * u * u * 1.6;
	}
	float d_edge = min(from_edge.x, from_edge.y);
	// The joint, its edge softened by a pixel's width so thin joints far off
	// stay unbroken lines rather than dashes.
	float aa = fwidth(d_edge);
	float joint = 1.0 - smoothstep(grout_width - aa, grout_width + aa, d_edge);
	// The bevel catches dust and a little shade toward the joint.
	float lip = 1.0 - smoothstep(grout_width, bevel_width, d_edge);
	color = mix(color, color * 0.86, lip * 0.5);
	color = mix(color, quartz_color * 0.32, joint);

	ALBEDO = color;
	// The imported paving mesh carves small cobbles; polished slabs are flat,
	// so shade the top as one surface, turned only by the bevels.
	vec3 n = normalize(vec3(slope.x, 1.0, slope.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ROUGHNESS = mix(0.3 + haze * 0.12 + bold * 0.1, 0.9, max(joint, lip * 0.3)) - fleck * 0.15;
	SPECULAR = 0.5;
	METALLIC = 0.0;
}
