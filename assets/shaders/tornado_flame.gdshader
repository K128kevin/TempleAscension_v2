shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Fire Tornado's fire (scripts/wizard_fx.gd), one MultiMesh of it: each
// instance a tongue of flame like the torches', much larger, that faces the
// camera and is drawn out along the way it moves, so tongues whirled round
// the column streak round it. Its shape is torn by noise, broad and hot at its
// root, ragged toward its tip, and it glows brightest through its heart.
// Instance scale is its width (x) and length (y); INSTANCE_CUSTOM.xyz is its
// velocity in world space and .w its seed; COLOR is its colour and fade.
// `ember` 1 draws a small hard spark instead of a tongue. Blended with
// premultiplied alpha: its light adds to what lies behind it and its body
// partly hides it, so thick fire reads as flame, not a white-out, even over
// pale sand. `flame_time` runs on the combat clock.
uniform float flame_time = 0.0;
uniform float ember = 0.0;

varying float seed;

float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float total = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 3; i++) {
		total += noise(p) * amplitude;
		p = p * 2.2 + vec2(3.1, 7.7);
		amplitude *= 0.5;
	}
	return total;
}

void vertex() {
	seed = INSTANCE_CUSTOM.w;
	vec3 at = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz;
	float width = length(MODEL_MATRIX[0].xyz);
	float length_ = length(MODEL_MATRIX[1].xyz);
	// Drawn out along its motion as the camera sees it (upright if still).
	vec2 way = (VIEW_MATRIX * vec4(INSTANCE_CUSTOM.xyz, 0.0)).xy;
	vec2 along = length(way) > 0.001 ? normalize(way) : vec2(0.0, 1.0);
	vec2 across = vec2(along.y, -along.x);
	vec2 offset = across * VERTEX.x * width + along * VERTEX.y * length_;
	POSITION = PROJECTION_MATRIX * vec4(at + vec3(offset, 0.0), 1.0);
}

void fragment() {
	// x across it, y from its root (-1) to its tip (1).
	vec2 uv = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	float glow;
	float heart;
	if (ember > 0.5) {
		float d = length(vec2(uv.x * 1.6, uv.y));
		glow = pow(clamp(1.0 - d, 0.0, 1.0), 1.6);
		heart = smoothstep(0.5, 0.0, d);
	} else {
		float tip = uv.y * 0.5 + 0.5;
		// The flame boils up through it, faster than it drifts aside.
		float n = fbm(vec2(uv.x * 1.7 + seed, uv.y * 1.3 - flame_time * 3.2 + seed * 0.37));
		float tear = noise(vec2(uv.x * 4.0 - seed, uv.y * 3.0 - flame_time * 5.0));
		// Round at its root, narrowing and wavering toward its tip.
		float x = uv.x + (n - 0.5) * 0.7 * tip;
		float spread = mix(0.95, 0.3, tip);
		float d = length(vec2(x / spread, uv.y * (uv.y < 0.0 ? 1.15 : 1.0)));
		float edge = d + (n - 0.5) * 0.9 + (tear - 0.5) * 0.45 * tip;
		glow = smoothstep(1.0, 0.25, edge);
		heart = smoothstep(0.55, 0.0, edge) * (1.0 - tip * 0.6);
	}
	vec3 color = mix(COLOR.rgb, vec3(1.0, 0.9, 0.62), heart * 0.55);
	ALBEDO = color * COLOR.a * glow * (1.3 + heart * 0.6);
	// (Its body hides somewhat less than it lights: fire is more glow than stuff.)
	ALPHA = COLOR.a * glow * 0.45;
}
