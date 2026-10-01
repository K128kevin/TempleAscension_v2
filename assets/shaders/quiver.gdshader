shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, specular_schlick_ggx;

// The ranger's quiver (built in tools/outfit_hero.py), each part told by its
// UVs: U's whole number is the part (0 the tube, 1 its lining, 2 the rolled
// rim, 3 the cap, 4 an arrow's shaft, 5 a fletching vane, 6 a nock), its
// fraction runs round or along the part; V runs along it, plus ten times the
// arrow's number.
//
// The tube is worn, tooled leather: mottled and grained, a stitched seam up
// the back, a panel of embossed scrollwork framed by tooled lines, two dark
// straps with bronze buckles, and bronze fittings riveted round the mouth and
// foot. The arrows have ash shafts with painted cresting, barred feathers
// that differ from arrow to arrow, and horn nocks.
const float ROUND = 0.36;
const float LENGTH = 0.56;

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

vec3 bronze(float wear) {
	return mix(vec3(0.42, 0.29, 0.13), vec3(0.62, 0.46, 0.24), wear);
}

void fragment() {
	float part = floor(UV.x + 0.0001);
	float u = UV.x - part;
	float arrow = floor(UV.y / 10.0);
	float v = UV.y - arrow * 10.0;
	float seed = hash2(vec2(arrow, 3.7));
	vec3 color;
	float h = 0.0;
	float rough = 0.85;
	float metal = 0.0;
	if (part < 0.5) {
		// Leather, in metres round and along the tube.
		vec2 m = vec2(u * ROUND, v * LENGTH);
		float mottle = fbm2(m * 14.0);
		float grain = noise2(m * 420.0);
		color = vec3(0.30, 0.17, 0.09) * (0.78 + mottle * 0.4) * (0.92 + grain * 0.12);
		color *= 0.82 + 0.18 * v;
		h = grain * 0.0003;
		// Scuffed paler where it rubs.
		color = mix(color, color * 1.35, smoothstep(0.68, 0.82, fbm2(m * 30.0 + 5.0)) * 0.6);
		// The seam up the back, stitched either side.
		float seam = min(u, 1.0 - u) * ROUND;
		if (seam < 0.005) { color *= 0.55; h -= 0.0008; }
		if (abs(seam - 0.009) < 0.0013 && fract(m.y * 130.0) < 0.55) { color = vec3(0.5, 0.41, 0.28); h += 0.0004; }
		// A panel of embossed scrollwork round the front, framed by tooled lines.
		float front = abs(u - 0.5) * ROUND;
		if (v > 0.33 && v < 0.62 && front < 0.075) {
			float frame = min(min(v - 0.33, 0.62 - v) * LENGTH, 0.075 - front);
			if (frame < 0.004 || abs(frame - 0.008) < 0.0012) { color *= 0.6; h -= 0.0006; }
			else {
				vec2 s = vec2(m.x - 0.5 * ROUND, m.y) * 70.0;
				float vine = abs(sin(s.y * 0.9 + sin(s.x * 1.3) * 1.6) - s.x * 0.12 * sin(s.y * 0.45));
				float leaf = smoothstep(0.35, 0.0, abs(sin(s.x * 2.1 + s.y * 1.7)) * abs(sin(s.y * 1.1 - s.x * 0.8)));
				float relief = max(smoothstep(0.25, 0.05, vine), leaf * 0.7);
				color *= 0.75 + 0.45 * relief;
				h += 0.0012 * relief;
			}
		}
		// Two straps round it, each with a bronze buckle at the front.
		for (int k = 0; k < 2; k++) {
			float centre = k == 0 ? 0.24 : 0.7;
			float d = abs(v - centre) * LENGTH;
			if (d < 0.011) {
				color = vec3(0.16, 0.09, 0.05) * (0.85 + mottle * 0.3);
				h = 0.0016 * smoothstep(0.011, 0.008, d);
				if (abs(d - 0.0085) < 0.0011 && fract(m.x * 110.0) < 0.5) color = vec3(0.42, 0.34, 0.24);
				vec2 b = vec2(front, d);
				if (front < 0.014 && d < 0.013) {
					float ring = abs(max(b.x / 0.014, b.y / 0.013) - 0.8);
					if (ring < 0.2) { color = bronze(fbm2(m * 80.0)); metal = 0.9; rough = 0.35; h = 0.0025; }
				}
			}
		}
		// Bronze fittings round the mouth and the foot, riveted.
		if (v > 0.93 || v < 0.05) {
			float wear = fbm2(m * 60.0);
			color = bronze(wear) * (0.75 + 0.25 * wear);
			metal = 0.9;
			rough = 0.35 + 0.2 * (1.0 - wear);
			h = 0.0015;
			// Green-brown verdigris in the recesses.
			color = mix(color, vec3(0.2, 0.25, 0.18), smoothstep(0.62, 0.8, fbm2(m * 40.0 + 2.0)) * 0.5);
			float row = v > 0.5 ? (0.965 - v) * LENGTH : (v - 0.025) * LENGTH;
			float rivet = length(vec2((fract(u * 14.0) - 0.5) * ROUND / 14.0, row));
			if (rivet < 0.0035) { color = bronze(1.0) * 1.1; h = 0.0028 * (1.0 - rivet / 0.0035); rough = 0.25; }
		}
	} else if (part < 1.5) {
		// The lining, dark in the quiver's mouth.
		color = vec3(0.09, 0.055, 0.035) * (0.8 + noise2(vec2(u * 60.0, v * 30.0)) * 0.3);
		rough = 0.95;
	} else if (part < 2.5) {
		// The rolled leather rim, stitched round.
		color = vec3(0.24, 0.13, 0.07) * (0.85 + noise2(vec2(u * 80.0, v * 4.0)) * 0.3);
		if (abs(v - 0.5) < 0.08 && fract(u * 70.0) < 0.5) color = vec3(0.48, 0.39, 0.27);
	} else if (part < 3.5) {
		// The bronze cap over the foot.
		color = bronze(fbm2(vec2(u * 20.0, v * 6.0))) * 0.85;
		metal = 0.9;
		rough = 0.4;
	} else if (part < 4.5) {
		// Ash shafts: pale wood with a fine grain, painted cresting below the
		// fletching, in two colours that differ from arrow to arrow.
		float grain = noise2(vec2(u * 6.0, v * 90.0 + arrow * 13.0));
		color = vec3(0.62, 0.48, 0.3) * (0.82 + grain * 0.3);
		vec3 crest = seed < 0.33 ? vec3(0.45, 0.07, 0.05) : (seed < 0.66 ? vec3(0.08, 0.2, 0.12) : vec3(0.06, 0.06, 0.07));
		if (abs(v - 0.71) < 0.012) color = crest;
		if (abs(v - 0.74) < 0.005 || abs(v - 0.68) < 0.005) color = vec3(0.05, 0.04, 0.04);
		rough = 0.7;
	} else if (part < 5.5) {
		// Feathers: grey goose, barred brown or dyed green, by arrow; barbs
		// slanting back from the quill, darker toward it, the edge ragged.
		vec3 base = seed < 0.4 ? vec3(0.72, 0.7, 0.65) : (seed < 0.75 ? vec3(0.42, 0.3, 0.19) : vec3(0.16, 0.3, 0.2));
		float barbs = smoothstep(0.35, 0.5, abs(fract(u * 34.0 - v * 4.0) - 0.5));
		float bars = seed >= 0.4 && seed < 0.75 ? step(0.5, fract(u * 4.0 + 0.2)) : 0.0;
		color = base * (0.78 + 0.22 * barbs) * (1.0 - 0.35 * bars) * (0.75 + 0.25 * v);
		// The quill along the shaft.
		if (v < 0.12) color = vec3(0.8, 0.78, 0.7);
		h = barbs * 0.0002;
		rough = 0.95;
	} else {
		// Horn nocks.
		color = vec3(0.07, 0.05, 0.04) * (0.9 + seed * 0.4);
		rough = 0.35;
	}
	ALBEDO = color;
	METALLIC = metal * 0.45;
	ROUGHNESS = rough;
	SPECULAR = mix(0.2, 0.5, metal);
	vec3 sx = dFdx(VERTEX);
	vec3 sy = dFdy(VERTEX);
	vec3 r1 = cross(sy, NORMAL);
	vec3 r2 = cross(NORMAL, sx);
	float det = dot(sx, r1);
	vec3 gradient = (dFdx(h) * r1 + dFdy(h) * r2) * sign(det) / max(abs(det), 0.000001);
	NORMAL = normalize(NORMAL - gradient);
}
