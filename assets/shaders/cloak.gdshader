shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// A cloak that folds over the legs instead of letting them through
// (assets/shaders/cloth_fold.gdshaderinc).
#include "res://assets/shaders/cloth_fold.gdshaderinc"
uniform vec3 cloth_color : source_color = vec3(0.1, 0.19, 0.1);

void vertex() {
	VERTEX = fold_cloth(VERTEX);
}

void fragment() {
	ALBEDO = cloth_color;
	ROUGHNESS = 0.92;
	SPECULAR = 0.2;
}
