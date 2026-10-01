shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// The warrior's helm, after his concept art (without the crest): worn steel
// with a face mask of two large dark eye openings, a raised nose bar between
// them and a dark mouth slot below, a row of rivets round the mask, and a
// round boss over each ear. Laid on the helm's rest pose (CUSTOM0, from
// Art.rest_pose_mesh), where the face looks along +Z.
uniform bool rest_pose = false;
// Where the face sits on the rest-pose helm (mesh space, metres).
uniform float eye_height = 1.705;
uniform float face_front = 0.06;

varying vec3 helm_position;

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

float box(vec2 p, vec2 half_size, float r) {
	vec2 d = abs(p) - half_size + r;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
}

void vertex() {
	helm_position = rest_pose ? CUSTOM0.xyz : VERTEX;
}

void fragment() {
	vec3 p = helm_position;
	float wear = noise2(p.xy * 40.0 + p.z * 13.0) * 0.6 + noise2(p.xz * 140.0) * 0.4;
	vec3 color = vec3(0.56, 0.57, 0.59) * (0.72 + wear * 0.4);
	float h = 0.0;
	// Half metal: there are no reflections for full metal to show.
	float metal = 0.45;
	float rough = 0.35 + wear * 0.15;
	if (p.z > face_front) {
		vec2 f = vec2(abs(p.x), p.y - eye_height);
		// The eye openings: large, slanting slightly down at the outside.
		float eye = box(vec2(f.x - 0.048, f.y + (f.x - 0.048) * 0.25), vec2(0.036, 0.02), 0.012);
		// The nose bar, from brow to below the eyes.
		float nose = box(vec2(p.x, p.y - eye_height + 0.035), vec2(0.011, 0.06), 0.004);
		// The mouth slot.
		float mouth = box(vec2(p.x, p.y - eye_height + 0.1), vec2(0.03, 0.009), 0.006);
		if (min(eye, mouth) < 0.0 && nose > 0.0) {
			color = vec3(0.02);
			metal = 0.0;
			rough = 0.95;
			h = -0.003;
		} else {
			if (nose < 0.0) h = 0.0025 * clamp(-nose / 0.006, 0.0, 1.0);
			// Rivets round the eyes and along the mask's edge.
			float rim = min(eye, mouth);
			if (rim > 0.004 && rim < 0.012) {
				float rv = fract((p.x + p.y) * 70.0);
				if (rv < 0.25) { h = 0.0015; color *= 1.25; }
			}
			// Darker grime in the mask's recesses.
			color *= 1.0 - 0.35 * smoothstep(0.02, 0.0, rim);
		}
	}
	// A boss over each ear.
	vec2 ear = vec2(p.z + 0.005, p.y - (eye_height - 0.01));
	float boss = length(ear);
	if (abs(p.x) > 0.1 && boss < 0.03) {
		h = 0.004 * (1.0 - boss / 0.03);
		color = vec3(0.6) * (0.8 + 0.4 * (1.0 - boss / 0.03));
	}
	ALBEDO = color;
	METALLIC = metal;
	ROUGHNESS = rough;
	vec3 sx = dFdx(VERTEX);
	vec3 sy = dFdy(VERTEX);
	vec3 r1 = cross(sy, NORMAL);
	vec3 r2 = cross(NORMAL, sx);
	float det = dot(sx, r1);
	vec3 gradient = (dFdx(h) * r1 + dFdy(h) * r2) * sign(det) / max(abs(det), 0.000001);
	NORMAL = normalize(NORMAL - gradient);
}
