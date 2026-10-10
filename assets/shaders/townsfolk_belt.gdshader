shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// A townsperson's belt (scripts/townsperson.gd belt): worn leather, the grit
// photograph laid over it from the world's three sides (as Kit.gritty is).
// Over a starving body it is drawn in with the body and the garment under
// it (gaunt.gdshaderinc), so it stays on the waist.
#include "gaunt.gdshaderinc"
uniform vec3 leather : source_color = vec3(0.3, 0.2, 0.12);
uniform sampler2D grit : source_color, filter_linear_mipmap, repeat_enable;
uniform float scale = 3.0;
varying vec3 world;
varying vec3 world_normal;

void vertex() {
	VERTEX = gaunt_inset(VERTEX, NORMAL, BONE_INDICES, BONE_WEIGHTS);
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 w = pow(abs(world_normal), vec3(4.0));
	w /= max(dot(w, vec3(1.0)), 0.0001);
	vec3 p = world * scale;
	float g = texture(grit, p.yz).r * w.x + texture(grit, p.xz).r * w.y + texture(grit, p.xy).r * w.z;
	// (The grit photograph averages .41: as Kit.gritty, its tint is raised.)
	ALBEDO = leather * 2.3 * g;
	ROUGHNESS = 0.92;
	SPECULAR = 0.25;
}
