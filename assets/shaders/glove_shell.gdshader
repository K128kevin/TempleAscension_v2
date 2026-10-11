shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// Gloves worn over the hands (the Ice Queen's Gloves: scripts/visual.gd
// glove_shells): the hero's own body mesh, skinned with it, drawn again a
// little way out from the skin from `glove_from` (just short of the wrist,
// at rest) to the fingertips, the rest of the body cut away; a flared cuff at
// the opening, its inside seen in shadow. Soft, fine-grained leather that
// creases over the knuckles and between the fingers.
uniform vec3 tint : source_color = vec3(0.56, 0.78, 1.0);
uniform bool rest_pose = true;
uniform float glove_from = 0.668;
// How far out from the skin the leather stands, and the cuff's flare beyond it.
uniform float thickness = 0.0032;
uniform float flare = 0.006;
// One of a pair (pictured alone): the side of the body kept, +1 or -1.
uniform float keep_side = 0.0;
// (Hidden in the shadows: scripts/visual.gd set_shadowed.)
uniform float shadowed = 0.0;

varying vec3 rest;
// The skin's outward normal, in view space (the one fragment() is given is
// turned by the body's mirrored winding on the hero, and not elsewhere).
varying vec3 outward;

float hash3(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1,0,0)), f.x),
		mix(hash3(i + vec3(0,1,0)), hash3(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0,0,1)), hash3(i + vec3(1,0,1)), f.x),
		mix(hash3(i + vec3(0,1,1)), hash3(i + vec3(1,1,1)), f.x), f.y), f.z);
}

void vertex() {
	rest = rest_pose ? CUSTOM0.xyz : VERTEX;
	float reach = abs(rest.x);
	// The cuff stands out further at the opening, easing in toward the hand.
	float cuff = 1.0 - smoothstep(glove_from + 0.012, glove_from + 0.03, reach);
	VERTEX += NORMAL * (thickness + flare * cuff);
	outward = (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	float reach = abs(rest.x);
	if (reach < glove_from) discard;
	if (keep_side != 0.0 && rest.x * keep_side < 0.0) discard;
	// Fine leather grain, and creases: across the knuckles and finger joints
	// (where the hand bends, at rest a little way out along it), and fainter
	// wrinkles all over.
	float grain = noise3(rest * 900.0);
	float wrinkle = noise3(vec3(reach * 160.0, rest.y * 40.0, rest.z * 40.0));
	float joints = 0.0;
	for (int i = 0; i < 3; i++) {
		float at = vec3(0.755, 0.8, 0.84)[i];
		joints += 1.0 - smoothstep(0.0, 0.004, abs(reach - at - (noise3(rest * 60.0) - 0.5) * 0.004));
	}
	vec3 colour = tint * (0.86 + grain * 0.1 + wrinkle * 0.08);
	colour *= 1.0 - joints * 0.16;
	float h = grain * 0.0002 - joints * 0.0006 + wrinkle * 0.0003;
	// The cuff: a band turned back at the opening, edged with a stitched seam.
	float band = 1.0 - smoothstep(glove_from + 0.024, glove_from + 0.027, reach);
	colour = mix(colour, tint * 0.8 * (0.9 + grain * 0.1), band);
	h += band * 0.0006;
	if (abs(reach - glove_from - 0.03) < 0.0011 && fract((rest.y + rest.z) * 140.0) < 0.6) {
		colour = mix(tint, vec3(1.0), 0.5);
		h += 0.0003;
	}
	// Seen from within (at the cuff's opening, the skin's outward normal
	// turned away), the glove's shadowed lining.
	vec3 out_normal = normalize(outward);
	bool lining = dot(out_normal, VIEW) < -0.1;
	NORMAL = lining ? -out_normal : out_normal;
	if (lining) colour = tint * 0.3;
	ALBEDO = mix(colour, vec3(0.02, 0.02, 0.04), shadowed * 0.92);
	vec3 sx = dFdx(VERTEX);
	vec3 sy = dFdy(VERTEX);
	vec3 r1 = cross(sy, NORMAL);
	vec3 r2 = cross(NORMAL, sx);
	float det = dot(sx, r1);
	vec3 gradient = (dFdx(h) * r1 + dFdy(h) * r2) * sign(det) / max(abs(det), 0.000001);
	NORMAL = normalize(NORMAL - gradient);
	// Supple leather with a soft sheen.
	ROUGHNESS = 0.48 - band * 0.05;
	SPECULAR = 0.4;
}
