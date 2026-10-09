shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Old bone (scripts/basement_props.gd skeleton, bones): yellowed ivory gone
// grey, pitted and stained, dirt ground into its undersides and into the
// grain of the long bones. The vertex colour is each bone's own shade (and
// the eye sockets' dark).
uniform sampler2D grit : filter_linear_mipmap, repeat_enable;
uniform vec3 bone : source_color = vec3(0.6, 0.57, 0.5);
uniform vec3 stain : source_color = vec3(0.34, 0.29, 0.22);
uniform vec3 dirt : source_color = vec3(0.24, 0.19, 0.14);
varying vec3 local_position;
varying vec3 local_normal;

void vertex() {
	local_position = VERTEX;
	local_normal = NORMAL;
}

vec3 triplanar(vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= w.x + w.y + w.z;
	return texture(grit, p.yz).rgb * w.x + texture(grit, p.xz).rgb * w.y + texture(grit, p.xy).rgb * w.z;
}

void fragment() {
	float fine = triplanar(local_position * 9.0, local_normal).r;
	float coarse = triplanar(local_position * 1.7 + 0.3, local_normal).g;
	vec3 colour = bone * COLOR.rgb;
	// Brown staining in blotches, darker in the pits of the fine grain.
	colour = mix(colour, stain * COLOR.rgb, smoothstep(0.38, 0.62, coarse) * 0.65);
	colour *= 0.72 + 0.56 * fine;
	// Dirt where it lay against the floor, and caked under it.
	float under = smoothstep(0.1, -0.7, local_normal.y) + smoothstep(0.05, 0.0, local_position.y) * 0.5;
	colour = mix(colour, dirt, clamp(under, 0.0, 1.0) * 0.7);
	ALBEDO = colour;
	ROUGHNESS = 0.82 - fine * 0.15;
	SPECULAR = 0.2;
}
