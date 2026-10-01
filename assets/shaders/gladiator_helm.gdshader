shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// The warrior's helm, after his concept art (without the crest): hammered,
// worn steel with a face mask whose two large eye openings and mouth slot are
// cut right through, so his own face shows in their shadow, a raised nose bar
// between the eyes, a riveted brow band round the helm, a low riveted ridge
// over the crown, a rolled and riveted lower rim, a Greek-key band etched
// round the cheeks, seams where the cheek plates meet the mask, and a boss
// over each ear. Inside, it is lined in dark felt. Laid on the helm's rest
// pose (CUSTOM0, from Art.rest_pose_mesh), where the face looks along +Z.
uniform bool rest_pose = false;
// Where the face sits on the rest-pose helm (mesh space, metres).
uniform float eye_height = 1.705;
uniform float face_front = 0.06;

varying vec3 helm_position;
// The surface's own outward normal, before any flip for its back face.
varying vec3 outward;

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

float box(vec2 p, vec2 half_size, float r) {
	vec2 d = abs(p) - half_size + r;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
}

// A row of round rivet heads along `run` (metres) at `across` from their line.
float rivets(float run, float across, float spacing, float size) {
	float d = length(vec2((fract(run / spacing) - 0.5) * spacing, across));
	return 1.0 - smoothstep(size * 0.6, size, d);
}

void vertex() {
	helm_position = rest_pose ? CUSTOM0.xyz : VERTEX;
	outward = (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec3 p = helm_position;
	vec2 f = vec2(abs(p.x), p.y - eye_height);
	// The eye openings: large, slanting slightly down at the outside; the
	// nose bar between them, from brow to below the eyes; the mouth slot.
	float eye = box(vec2(f.x - 0.048, f.y + (f.x - 0.048) * 0.25), vec2(0.036, 0.02), 0.012);
	float nose = box(vec2(p.x, p.y - eye_height + 0.035), vec2(0.011, 0.06), 0.004);
	float mouth = box(vec2(p.x, p.y - eye_height + 0.1), vec2(0.03, 0.009), 0.006);
	bool mask = p.z > face_front;
	if (mask && min(eye, mouth) < 0.0 && nose > 0.0) discard;
	// Seen from inside (through the eye holes): the outward normal faces away.
	if (dot(outward, VIEW) < 0.0) {
		// The felt lining inside.
		ALBEDO = vec3(0.07, 0.05, 0.035) * (0.8 + noise2(p.xy * 300.0) * 0.4);
		ROUGHNESS = 0.95;
		METALLIC = 0.0;
	} else {
		// Hammered steel: broad dents, a fine grain, darker oxidised patches,
		// rust specks, and scratches running every which way.
		float dents = noise3(p * 55.0);
		float grain = noise2(vec2(p.x + p.z, p.y) * 900.0);
		float patina = smoothstep(0.45, 0.75, noise3(p * 14.0 + 3.0));
		vec3 color = vec3(0.6, 0.61, 0.63) * (0.82 + dents * 0.22) * (0.95 + grain * 0.08);
		color = mix(color, vec3(0.32, 0.31, 0.3), patina * 0.55);
		float rust = smoothstep(0.82, 0.93, noise3(p * 60.0 + 11.0)) * smoothstep(0.55, 0.85, noise3(p * 9.0));
		color = mix(color, vec3(0.34, 0.19, 0.1), rust * 0.8);
		float scratch_a = smoothstep(0.92, 0.97, noise2(vec2(p.x * 700.0 + p.y * 120.0, p.y * 25.0 + p.z * 40.0)));
		float scratch_b = smoothstep(0.93, 0.97, noise2(vec2(p.y * 650.0 - p.z * 200.0, p.x * 30.0)));
		float scratch = max(scratch_a, scratch_b);
		color = mix(color, vec3(0.8, 0.81, 0.82), scratch * 0.6);
		float h = (dents - 0.5) * 0.0012 - scratch * 0.0002;
		float metal = 0.45;
		float rough = 0.32 + dents * 0.12 + patina * 0.25 + rust * 0.4 - scratch * 0.1;
		if (mask) {
			// The nose bar, raised; rivets round the eyes and mouth; grime
			// in the mask's recesses.
			if (nose < 0.0) h += 0.0025 * clamp(-nose / 0.006, 0.0, 1.0);
			float rim = min(eye, mouth);
			if (rim > 0.004 && rim < 0.012) {
				float rv = fract((p.x + p.y) * 70.0);
				if (rv < 0.25) { h += 0.0015; color *= 1.25; }
			}
			color *= 1.0 - 0.35 * smoothstep(0.02, 0.0, rim);
			// The seams where the cheek plates meet the mask, riveted.
			float cheek = abs(f.x - 0.088);
			if (cheek < 0.0025 && f.y < 0.02) { color *= 0.55; h -= 0.0008; }
			float cr = rivets(p.y, cheek - 0.008, 0.022, 0.0035);
			if (f.y < 0.0 && f.y > -0.14) { h += 0.0016 * cr; color = mix(color, vec3(0.75), cr * 0.5); }
		}
		// The brow band round the helm, with a row of rivets.
		float brow = p.y - (eye_height + 0.045);
		if (abs(brow) < 0.013) {
			h += 0.0016 * smoothstep(0.013, 0.009, abs(brow));
			color *= 0.92;
			float around = atan(p.x, p.z) * 0.13;
			float br = rivets(around, brow, 0.026, 0.0038);
			h += 0.0018 * br;
			color = mix(color, vec3(0.78), br * 0.5);
		}
		// The low ridge over the crown, front to back, riveted.
		if (abs(p.x) < 0.014 && p.y > eye_height + 0.07) {
			h += 0.0022 * smoothstep(0.014, 0.008, abs(p.x));
			float rr = rivets(p.z, p.x, 0.024, 0.0035);
			h += 0.0016 * rr;
			color = mix(color, vec3(0.78), rr * 0.5);
		}
		// The rolled lower rim, riveted.
		float lower = p.y - (eye_height - 0.155);
		if (lower < 0.012) {
			h += 0.002 * smoothstep(0.012, 0.004, lower);
			float lr = rivets(atan(p.x, p.z) * 0.13, lower - 0.02, 0.024, 0.0035);
			h += 0.0015 * lr;
		}
		// A Greek-key band etched round the cheeks and nape.
		float kb = (p.y - (eye_height - 0.135)) / 0.022;
		if (kb > 0.0 && kb < 1.0 && !(mask && abs(p.x) < 0.04)) {
			float kx = fract(atan(p.x, p.z) * 0.13 / 0.022);
			bool line = kb < 0.15 || kb > 0.85 || kx < 0.15 || (kx < 0.65 && kb > 0.55 && kb < 0.7) || (kx > 0.5 && kx < 0.65 && kb > 0.3);
			if (line) { color *= 0.5; h -= 0.0005; }
		}
		// A boss over each ear.
		vec2 ear = vec2(p.z + 0.005, p.y - (eye_height - 0.01));
		float boss = length(ear);
		if (abs(p.x) > 0.1 && boss < 0.03) {
			h += 0.004 * (1.0 - boss / 0.03);
			color = vec3(0.62) * (0.8 + 0.4 * (1.0 - boss / 0.03));
			float ring = abs(boss - 0.022);
			if (ring < 0.002) color *= 0.6;
		}
		ALBEDO = color;
		METALLIC = metal;
		ROUGHNESS = clamp(rough, 0.2, 0.9);
		vec3 sx = dFdx(VERTEX);
		vec3 sy = dFdy(VERTEX);
		vec3 r1 = cross(sy, NORMAL);
		vec3 r2 = cross(NORMAL, sx);
		float det = dot(sx, r1);
		vec3 gradient = (dFdx(h) * r1 + dFdy(h) * r2) * sign(det) / max(abs(det), 0.000001);
		NORMAL = normalize(NORMAL - gradient);
	}
}
