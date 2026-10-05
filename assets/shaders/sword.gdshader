shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// The hero's sword, colored by part along the imported mesh's normalized
// length: brass pommel and cross guard, a dark brown leather grip, and a
// silver blade with a fuller (groove) down the middle of both flat faces.
// (Uniforms, so that the ranger's dagger, cut differently along its length,
// is finished the same way: Art.dagger_material.)
uniform float POMMEL_TOP = 0.045;
uniform float GRIP_TOP = 0.215;
uniform float GUARD_TOP = 0.33;
// How far the blade sweeps back toward its point (the bandits' sica,
// tools/make_bandits.py): its fuller follows the curve.
uniform float SWEEP = 0.0;
const float FULLER_END = 0.86;
const float FULLER_HALF_WIDTH = 0.04;

varying vec3 local_position;
varying vec3 local_normal;

void vertex() {
	local_position = VERTEX;
	float swept = max(0.0, VERTEX.y - 0.36) / 0.64;
	local_position.x += SWEEP * swept * swept;
	local_normal = NORMAL;
}

// An item of another make (scripts/items.gd `tint`): its colours redrawn in
// that one, keeping their light and dark.
uniform vec3 tint : source_color = vec3(1.0);
uniform float recolor = 0.0;

void fragment() {
	float y = local_position.y;
	vec3 brass = vec3(0.78, 0.58, 0.25);
	vec3 leather = vec3(0.16, 0.085, 0.04);
	vec3 steel = vec3(0.82, 0.84, 0.87);
	if (y < POMMEL_TOP || (y >= GRIP_TOP && y < GUARD_TOP)) {
		ALBEDO = brass;
		METALLIC = 0.9;
		ROUGHNESS = 0.32;
	} else if (y < GRIP_TOP) {
		// Leather wrap: faint diagonal bands.
		float wrap = 0.85 + 0.15 * step(0.5, fract((y + local_position.x * 0.6) * 60.0));
		ALBEDO = leather * wrap;
		METALLIC = 0.0;
		ROUGHNESS = 0.8;
	} else {
		// Partly metallic so the blade reads as silver even with little around
		// it to reflect, as in the dark temple.
		ALBEDO = steel;
		METALLIC = 0.6;
		ROUGHNESS = 0.28;
		// The fuller runs along the flat faces, fading out toward the point.
		bool flat_face = abs(normalize(local_normal).z) > 0.6;
		float along = smoothstep(GUARD_TOP, GUARD_TOP + 0.02, y) * (1.0 - smoothstep(FULLER_END - 0.04, FULLER_END, y));
		float groove = (1.0 - smoothstep(FULLER_HALF_WIDTH * 0.6, FULLER_HALF_WIDTH, abs(local_position.x))) * along;
		if (flat_face && groove > 0.0) {
			ALBEDO = mix(steel, steel * 0.32, groove);
			ROUGHNESS = mix(0.28, 0.5, groove);
			// Tilt the normal across the groove so it catches light like a channel.
			float slope = clamp(local_position.x / FULLER_HALF_WIDTH, -1.0, 1.0);
			vec3 tilt = (VIEW_MATRIX * MODEL_MATRIX * vec4(sign(local_normal.z) * vec3(-slope * 0.6, 0.0, 0.0), 0.0)).xyz;
			NORMAL = normalize(NORMAL + tilt * groove);
		}
	}
	ALBEDO = mix(ALBEDO, dot(ALBEDO, vec3(0.299, 0.587, 0.114)) * tint * 1.8, recolor);
}
