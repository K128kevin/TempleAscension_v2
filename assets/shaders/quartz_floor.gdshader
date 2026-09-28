shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Polished milky quartz paving, drawn procedurally in world space so batched
// tiles stay continuous. Light enough that the dark stone statues read clearly.
uniform vec3 quartz_color : source_color = vec3(0.70, 0.70, 0.72);
uniform vec3 vein_color : source_color = vec3(0.42, 0.44, 0.47);
uniform float grout_width = 0.022;

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
	for (int i = 0; i < 4; i++) {
		total += noise(p) * amplitude;
		p = p * 2.03 + vec2(17.1, 9.4);
		amplitude *= 0.5;
	}
	return total;
}

void fragment() {
	// Multimesh-safe world position: VERTEX is view space in fragment().
	vec2 p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	// Tiles are centred on whole metres; each slab varies slightly in tone.
	vec2 tile = floor(p + 0.5);
	float slab = hash2(tile * 1.37 + 4.1);
	vec2 edge = abs(fract(p + 0.5) - 0.5);
	float grout = smoothstep(0.5 - grout_width, 0.5 - grout_width * 0.4, max(edge.x, edge.y));

	float milk = cloud(p * 0.85 + slab * 7.0);
	vec3 color = quartz_color * (0.90 + milk * 0.22 + (slab - 0.5) * 0.06);
	// Thin, wandering translucent veins.
	float warp = cloud(p * 1.2 + vec2(3.7, 1.9)) * 3.2;
	float vein = abs(sin((p.x * 0.55 + p.y * 0.25 + warp) * 3.1));
	vein = (1.0 - smoothstep(0.0, 0.06, vein)) * smoothstep(0.35, 0.65, cloud(p * 0.5 + 11.0));
	color = mix(color, vein_color, vein * 0.45);
	// Tiny crystalline flecks.
	float fleck = step(0.992, hash2(floor(p * 55.0)));
	color += vec3(fleck * 0.10);
	color = mix(color, color * 0.45, grout);

	ALBEDO = color;
	// The imported paving mesh carves small cobbles; polished slabs are flat,
	// so shade the whole top as one surface and keep only the slab grout.
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	ROUGHNESS = mix(0.42, 0.85, grout) - fleck * 0.2;
	SPECULAR = 0.45;
	METALLIC = 0.0;
}
