shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// A blade carried in its sheath: the prop's own colours, with the bare grey
// steel turned into dark, stitched leather (the hilt and fittings unchanged).
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform vec3 leather : source_color = vec3(0.2, 0.11, 0.06);

void fragment() {
	vec3 c = texture(albedo_texture, UV).rgb;
	float spread = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
	float steel = step(spread, 0.06) * step(0.3, c.g);
	ALBEDO = mix(c, leather * (0.85 + 0.3 * fract(sin(dot(floor(UV * 400.0), vec2(12.9898, 78.233))) * 43758.5)), steel);
	ROUGHNESS = mix(0.6, 0.65, steel);
	METALLIC = mix(0.4, 0.0, steel);
}
