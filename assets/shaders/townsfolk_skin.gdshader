shader_type spatial;
// The townspeople's flesh (tools/make_townsfolk.py). The body's second UV set
// carries each point's height at rest and how far along the arm it is: what
// lies under a garment is not drawn, so it never shows through the cloth.
uniform sampler2D skin : source_color, filter_linear_mipmap;
uniform sampler2D grit : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 tone = vec3(1.0);
// How dirty: 0 washed, 1 unwashed, the feet and shins worst.
uniform float dirt = 0.0;
// Covered from this height (x) up to this one (y), and this far down the arm.
uniform vec2 cover = vec2(0.0);
uniform float sleeve = 0.0;

void fragment() {
	// (The exporter turns a UV's second coordinate over.)
	float along_arm = 1.0 - UV2.y;
	bool on_arm = along_arm > 0.001;
	if (!on_arm && UV2.x > cover.x && UV2.x < cover.y) discard;
	if (on_arm && along_arm < sleeve) discard;
	vec3 colour = texture(skin, UV).rgb * tone;
	float blotch = texture(grit, UV * 5.0).r;
	float low = 1.0 - smoothstep(0.0, 0.55, UV2.x);
	float grime = clamp(dirt * (0.2 + 0.7 * low) * smoothstep(0.25, 0.6, blotch + low * 0.25), 0.0, 1.0);
	ALBEDO = mix(colour, colour * vec3(0.52, 0.44, 0.36), grime);
	ROUGHNESS = 0.78;
	SPECULAR = 0.2;
}
