// Shared by the cloth shaders (assets/shaders/cloak.gdshader, statue_stone.gdshader).
// Cloth that never passes through the body parts beneath it. Each frame the
// wearer's limbs are given as capsules in this mesh's space (scripts/visual.gd
// sets them from the skeleton). A cloak hangs outside the legs: seen from the
// body's centre line, any cloth that lies inward of a leg, within the leg's
// width, is carried out past that leg, level with where it was. So a leg
// pressing into the cloak folds the cloth over its outer side, as real cloth
// is pushed, rather than showing through it. The capsules after the legs
// (the arms) only push cloth hanging behind the body, and only where they
// have swung behind it themselves: in front, the arms are outside the cloak.
const int CAPSULES = 12;
uniform vec3 capsule_a[CAPSULES];
uniform vec3 capsule_b[CAPSULES];
uniform float capsule_radius[CAPSULES];
uniform int capsule_count = 0;
// The body's vertical centre line, through the hips, and its facing.
uniform vec3 body_center = vec3(0.0);
uniform vec3 body_forward = vec3(0.0, 0.0, 1.0);
uniform int leg_capsules = 12;
// The closest the hanging cloth comes to the body's centre line below the
// hips, and round the waist (0: no limit); a cape over a robe keeps clear of
// the robe's skirt and sash.
uniform float min_reach = 0.16;
uniform float waist_reach = 0.0;
// Height above the body's centre above which the cloth is not folded at all,
// easing in fully FOLD_EASE below it: a kilt's waistband sits close on the
// waist instead of being carried out over the tops of the thighs.
uniform float fold_from = 10.0;
const float FOLD_EASE = 0.1;
// How far past a limb's surface the cloth starts to be carried out.
const float MARGIN = 0.03;
// How far beside a limb the cloth is still eased outward.
const float EASE = 0.12;
// How many balls stand for each limb along its length.
const int SAMPLES = 6;

vec3 fold_cloth(vec3 vertex) {
	vec3 unfolded = vertex;
	float strength = 1.0 - smoothstep(fold_from - FOLD_EASE, fold_from, vertex.y - body_center.y);
	if (strength <= 0.0) return vertex;
	vec2 across = vertex.xz - body_center.xz;
	float reach = length(across);
	vec2 out_dir = reach > 1e-4 ? across / reach : vec2(0.0, -1.0);
	float needed = reach;
	float behind = dot(vertex.xz - body_center.xz, normalize(body_forward.xz));
	for (int i = 0; i < CAPSULES; i++) {
		if (i >= capsule_count) break;
		if (i >= leg_capsules && behind > -0.06) continue;
		vec3 a = capsule_a[i];
		vec3 ab = capsule_b[i] - a;
		float r = capsule_radius[i] + MARGIN;
		// The limb, as a row of balls along its length: where each is cut by
		// the level of this vertex, the outward line from the centre through
		// the vertex must clear the cut. A limb lifted level with the cloth
		// (a thigh in a stride) is cleared to its far end, the knee.
		for (int k = 0; k <= SAMPLES; k++) {
			vec3 c = a + ab * (float(k) / float(SAMPLES));
			if (i >= leg_capsules && dot(c.xz - body_center.xz, normalize(body_forward.xz)) > -0.02) continue;
			float dy = vertex.y - c.y;
			if (abs(dy) >= r) continue;
			float slice = sqrt(r * r - dy * dy);
			vec2 h = c.xz - body_center.xz;
			float along = dot(h, out_dir);
			if (along <= 0.0) continue;
			float side2 = dot(h, h) - along * along;
			float side = sqrt(max(side2, 0.0));
			if (side < slice) {
				needed = max(needed, along + sqrt(slice * slice - side2));
			} else if (side < slice + EASE) {
				// Beside the limb the push fades out, so the cloth eases round
				// it in one smooth sheet instead of tearing at its edge.
				float fade = 1.0 - smoothstep(slice, slice + EASE, side);
				needed = max(needed, (along + slice * 0.5) * fade + needed * (1.0 - fade));
			}
		}
	}
	// Below the hips the cloth hangs around the legs, never in between them.
	if (vertex.y < body_center.y - 0.1) needed = max(needed, min_reach);
	else if (vertex.y < body_center.y + 0.3) needed = max(needed, waist_reach);
	vertex.xz = body_center.xz + out_dir * needed;
	return mix(unfolded, vertex, strength);
}
