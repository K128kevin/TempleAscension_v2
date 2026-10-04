shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Fruit and vegetables (the props kit's crates of apples and carrots, its
// barrel of apples: scripts/world_art.gd produce()). The kit colours each
// piece by its vertices: red apples, orange carrots, green tops, brown stalks.
// That colour is kept, mottled and bruised by the photographed grit; where
// `recolour` is set, the apples' red is turned to `fruit` (oranges, lemons,
// pomegranates, onions, figs), each piece a little different from the next.
uniform sampler2D grit : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 fruit : source_color = vec3(0.8, 0.4, 0.1);
uniform float recolour = 0.0;
varying vec3 world_at;

void vertex() {
	world_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 painted = COLOR.rgb;
	// The apples' flesh: strongly red, little green.
	float skin = smoothstep(0.08, 0.18, painted.r - painted.g * 1.5);
	float mottle = texture(grit, world_at.xz * 5.0 + world_at.y * 3.0).r;
	float speck = texture(grit, world_at.zy * 17.0 + world_at.x * 5.0).r;
	vec3 colour = painted * 2.2;
	if (recolour > 0.0) {
		// Each piece a shade apart: ripe and less ripe.
		float piece = texture(grit, floor(world_at.xz * 12.0) / 12.0 * 0.37).r;
		vec3 own = fruit * mix(0.78, 1.18, piece);
		colour = mix(colour, own * (painted.r / 0.29), skin);
	}
	colour *= 0.78 + 0.5 * mottle;
	// Bruises and blemishes.
	colour = mix(colour, colour * vec3(0.45, 0.36, 0.26), smoothstep(0.62, 0.8, speck) * 0.6);
	ALBEDO = colour;
	// A waxy skin on the fruit; matt leaves and stalks.
	ROUGHNESS = mix(0.85, 0.42 + 0.2 * mottle, skin);
	SPECULAR = mix(0.25, 0.45, skin);
}
