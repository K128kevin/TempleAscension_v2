shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D stone_texture : source_color, filter_linear_mipmap, repeat_enable;
varying vec3 stone_position;
varying vec3 stone_normal;

void vertex() {
	// Preserve a consistent grain size on the body and differently scaled gear.
	stone_position = VERTEX * vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	stone_normal = NORMAL;
}

void fragment() {
	vec3 weights = pow(abs(normalize(stone_normal)), vec3(4.0));
	weights /= max(dot(weights, vec3(1.0)), 0.0001);
	vec3 p = stone_position * 0.65;
	vec3 stone = texture(stone_texture, p.yz).rgb * weights.x
		+ texture(stone_texture, p.xz).rgb * weights.y
		+ texture(stone_texture, p.xy).rgb * weights.z;
	float gray = dot(stone, vec3(0.2126, 0.7152, 0.0722));
	ALBEDO = vec3(0.40 + gray * 0.32);
	ROUGHNESS = 0.94;
	METALLIC = 0.0;
}
