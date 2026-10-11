shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// A plain worn piece in one material (Art.worn_part: a hat's felt, its
// leather band and bronze buckle, the Marathon Boots' gold): its colour,
// with photographed detail over it (assets/shaders/detail.gdshaderinc) laid
// in the model's own space in metres.
#include "res://assets/shaders/detail.gdshaderinc"
uniform vec3 colour : source_color = vec3(0.5);
uniform float layer = 8.0;
uniform float tile = 0.1;
uniform float metallic = 0.0;
uniform vec2 roughness = vec2(0.6, 0.9);
uniform float relief = 1.0;
varying vec3 metric_position;
varying vec3 metric_normal;

void vertex() {
	vec3 size = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	metric_position = VERTEX * size;
	metric_normal = normalize(NORMAL / size);
}

void fragment() {
	vec3 n = normalize(metric_normal);
	vec3 w = tri_weights(n);
	vec3 p = metric_position / tile;
	vec4 d = mat_data(p, n, w, layer);
	float edge = edge_wear(NORMAL, VERTEX, 0.003) * metallic;
	ALBEDO = mix(colour * mix(1.0, mat_shade(p, n, w, layer), 0.5) * (0.75 + 0.25 * d.g), colour * 1.15, edge * 0.5);
	METALLIC = metallic;
	ROUGHNESS = mix(mix(roughness.x, roughness.y, d.r), roughness.x * 0.7, edge);
	NORMAL = detail_normal(mat_normal(p, n, w, layer, relief), n, metric_position, VERTEX, NORMAL);
}
