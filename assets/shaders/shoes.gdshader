shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// A townsman's shoes (scripts/townsperson.gd `shoes`): soft leather drawn
// over his feet, a little out from the skin, up to the ankle, with a darker
// sole. The body's second UV set carries each point's height at rest
// (tools/make_townsfolk.py), which is what says where the foot ends.
uniform vec3 leather : source_color = vec3(0.2, 0.12, 0.07);
uniform sampler2D grit : source_color, filter_linear_mipmap, repeat_enable;
// How high the shoe comes (metres on the body at rest), and how thick it is.
uniform float top = 0.115;
uniform float thick = 0.012;
varying float height;

void vertex() {
	height = UV2.x;
	// Thicker under the foot: the sole.
	VERTEX += NORMAL * thick * (1.0 + 1.2 * smoothstep(-0.2, -0.8, NORMAL.y));
}

void fragment() {
	// (An arm's points carry how far along the arm they are instead.)
	if (height > top || 1.0 - UV2.y > 0.001) discard;
	float worn = texture(grit, UV * 9.0).r;
	float sole = 1.0 - smoothstep(0.012, 0.022, height);
	// A stitched cuff at the ankle.
	float cuff = smoothstep(top - 0.014, top - 0.008, height);
	ALBEDO = leather * (0.75 + 0.5 * worn) * mix(1.0, 0.45, sole) * mix(1.0, 0.7, cuff);
	ROUGHNESS = 0.82;
	SPECULAR = 0.25;
}
