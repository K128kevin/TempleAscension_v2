shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// The ends of the wizard's sash: worn, matte leather (as Art.leather) hanging
// on his robe's skirt, folded over his legs with it just outside it
// (assets/shaders/cloth_fold.gdshaderinc, with fold_lift).
#include "res://assets/shaders/cloth_fold.gdshaderinc"
uniform float shadowed = 0.0;
uniform vec3 leather_color : source_color = vec3(0.21, 0.11, 0.05);

void vertex() {
	VERTEX = fold_cloth(VERTEX);
}

void fragment() {
	// (Hidden in the shadows: scripts/visual.gd set_shadowed.)
	ALBEDO = mix(leather_color, vec3(0.02, 0.02, 0.04), shadowed * 0.92);
	ROUGHNESS = 0.88;
	SPECULAR = 0.3;
}
