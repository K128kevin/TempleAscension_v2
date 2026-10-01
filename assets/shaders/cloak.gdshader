shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// Cloth that never passes through the body parts beneath it. Each frame the
// wearer's limbs are given as capsules in this mesh's space (scripts/visual.gd
// sets them from the skeleton). A cloak hangs outside the legs: seen from the
// body's centre line, any cloth that lies inward of a leg, within the leg's
// width, is carried out past that leg, level with where it was. So a leg
// pressing into the cloak folds the cloth over its outer side, as real cloth
// is pushed, rather than showing through it.
const int CAPSULES = 8;
uniform vec3 capsule_a[CAPSULES];
uniform vec3 capsule_b[CAPSULES];
uniform float capsule_radius[CAPSULES];
uniform int capsule_count = 0;
// The body's vertical centre line, through the hips.
uniform vec3 body_center = vec3(0.0);
uniform vec3 cloth_color : source_color = vec3(0.1, 0.19, 0.1);
// How far past a limb's surface the cloth starts to be carried out.
const float MARGIN = 0.03;
// The closest the hanging cloth comes to the body's centre line.
const float MIN_REACH = 0.16;
// How far beside a limb the cloth is still eased outward.
const float EASE = 0.12;

void vertex() {
	vec2 across = VERTEX.xz - body_center.xz;
	float reach = length(across);
	vec2 out_dir = reach > 1e-4 ? across / reach : vec2(0.0, -1.0);
	float needed = reach;
	for (int i = 0; i < CAPSULES; i++) {
		if (i >= capsule_count) break;
		vec3 a = capsule_a[i];
		vec3 ab = capsule_b[i] - a;
		float len2 = max(dot(ab, ab), 1e-6);
		// The limb's slice level with this vertex: around the nearest point of
		// its axis, a little wider (MARGIN) so the cloth eases over its edges,
		// and wider again where the limb leans.
		vec3 c = a + ab * clamp(dot(VERTEX - a, ab) / len2, 0.0, 1.0);
		float r = capsule_radius[i] + MARGIN;
		float dy = VERTEX.y - c.y;
		if (abs(dy) >= r) continue;
		float lean = abs(ab.y) / sqrt(len2);
		float slice = sqrt(r * r - dy * dy) / (lean > 0.6 ? lean : 1.0);
		// Where the outward line from the centre through this vertex leaves
		// that slice, if it passes through it at all.
		vec2 h = c.xz - body_center.xz;
		float along = dot(h, out_dir);
		float side2 = dot(h, h) - along * along;
		if (along <= 0.0) continue;
		float side = sqrt(max(side2, 0.0));
		if (side < slice) {
			needed = max(needed, along + sqrt(slice * slice - side2));
		} else if (side < slice + EASE) {
			// Beside the limb the push fades out, so the cloth eases round it
			// in one smooth sheet instead of tearing at the limb's edge.
			float fade = 1.0 - smoothstep(slice, slice + EASE, side);
			needed = max(needed, along * fade + needed * (1.0 - fade));
		}
	}
	// Below the hips the cloth hangs around the legs, never in between them.
	if (VERTEX.y < body_center.y - 0.1) needed = max(needed, MIN_REACH);
	VERTEX.xz = body_center.xz + out_dir * needed;
}

void fragment() {
	ALBEDO = cloth_color;
	ROUGHNESS = 0.92;
	SPECULAR = 0.2;
}
