shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
// A feather of the Marathon Boots' wings (tools/make_shoes.py). Its outline
// is the mesh's own (a tapering vane, its tip rounded), so it stays clean at
// any distance; its UVs run across it (0 the leading edge, .5 the quill, 1
// the trailing) and along it (0 the root, 1 the tip), and UV2.x is the
// feather's own seed. Off-white to a warm grey-cream at the tip, a little
// gilt toward the root where it sits in the mount; the quill pale horn; the
// barbs a fine sheen swept toward the tip, blurred to the vane's own shade
// far off; down at the root; shaded
// toward the root and the trailing edge, where the feathers lie over each
// other. Lit on whichever side is seen, light passing a little through.
uniform vec3 colour : source_color = vec3(0.92, 0.9, 0.84);
uniform vec3 tip_colour : source_color = vec3(0.74, 0.7, 0.63);
uniform vec3 root_colour : source_color = vec3(0.86, 0.72, 0.46);
uniform vec3 quill_colour : source_color = vec3(0.88, 0.83, 0.7);
uniform float barbs = 70.0;
varying vec2 seed;

void vertex() {
	seed = UV2;
}

void fragment() {
	// (Seen from either side: its normal turned toward the eye.)
	vec3 face = cross(dFdx(VERTEX), dFdy(VERTEX));
	if (dot(face, VIEW) < 0.0) face = -face;
	if (dot(NORMAL, face) < 0.0) NORMAL = -NORMAL;
	float across = (UV.x - 0.5) * 2.0;
	float out_ = abs(across);
	float along = UV.y;
	float s = seed.x;
	// The quill, thinning to the tip.
	float quill_w = mix(0.06, 0.012, along);
	float quill = 1.0 - smoothstep(quill_w * 0.5, quill_w * 1.2, out_);
	// The barbs: a fine sheen of lines from the quill out toward the tip.
	float b = along * barbs - out_ * barbs * 0.32;
	float blur = smoothstep(0.25, 0.7, fwidth(b));
	float groove = mix(0.5 + 0.5 * cos(b * 6.2832), 0.5, blur);
	// Down at the root, the gilt of the mount on it.
	float root = 1.0 - smoothstep(0.03, 0.16, along);
	vec3 c = mix(colour, tip_colour, smoothstep(0.45, 1.0, along) * (0.7 + 0.3 * fract(s * 5.7)));
	c = mix(c, root_colour, root * 0.8);
	c *= 0.9 + 0.1 * groove;
	// Shaded where the next feather lies over it: toward the root, and its
	// trailing vane.
	c *= mix(0.82, 1.0, smoothstep(0.0, 0.35, along));
	c *= 1.0 - 0.18 * smoothstep(0.2, 1.0, across);
	c *= 0.95 + 0.08 * fract(s * 13.1);
	c = mix(c, quill_colour, quill);
	ALBEDO = c;
	ROUGHNESS = mix(0.8, 0.45, quill);
	SPECULAR = 0.35;
	NORMAL = normalize(NORMAL + (groove - 0.5) * 0.06 * (1.0 - blur) * normalize(cross(NORMAL, vec3(0.0, 1.0, 0.0)) + 1e-4));
	BACKLIGHT = vec3(0.3, 0.28, 0.24) * (1.0 - quill);
}
