shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Finished arms (the hero's greatsword and war hammers, and those hung in the
// smithy: scripts/world_interiors.gd): steel from `metal_from` of the
// model's length up (an axe's head, a long sword's blade and guard), dark
// oiled wood below it (the haft, the grip). Both wear photographed detail
// (assets/shaders/detail.gdshaderinc): the steel brushed along its length,
// scratched and mottled, grimed in its recesses and honed bright at its
// edges; the wood's grain running up the haft, darker where hands have
// handled it.
#include "res://assets/shaders/detail.gdshaderinc"
uniform float metal_from = 0.5;
// A sword's pommel: steel again below this much of its length, and the grip
// between it and `metal_from` bound in dark leather cord, not bare wood.
uniform float pommel = 0.0;
uniform vec3 steel : source_color = vec3(0.8, 0.82, 0.85);
uniform vec3 wood : source_color = vec3(0.2, 0.125, 0.07);
varying float along;
varying vec3 at;
// The model's own space in metres (it is made a unit long and sized by its
// node).
varying vec3 metric_position;
varying vec3 metric_normal;

void vertex() {
	along = VERTEX.y;
	at = VERTEX;
	vec3 size = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	metric_position = VERTEX * size;
	metric_normal = normalize(NORMAL / size);
}

void fragment() {
	vec3 p = metric_position;
	vec3 n = normalize(metric_normal);
	vec3 w = tri_weights(n);
	vec3 bent;
	if (along >= metal_from || along < pommel) {
		float edge = edge_wear(NORMAL, VERTEX, 0.004);
		vec3 sp = p / 0.35;
		vec4 d = mat_data_up(sp, n, w, MAT_STEEL_BRUSHED);
		float brushed = mat_shade_up(sp, n, w, MAT_STEEL_BRUSHED);
		vec4 worn = mat_data(p / 0.22, n, w, MAT_STEEL_WORN);
		float mottle = mat_shade(p / 0.22, n, w, MAT_STEEL_WORN);
		vec3 colour = steel * 0.8 * mix(1.0, brushed, 0.35) * mix(1.0, mottle, 0.5);
		// Grime in the hollows and old oil, rubbed off the high places.
		colour *= 0.7 + 0.3 * worn.g;
		ALBEDO = mix(colour, steel, edge * 0.7);
		METALLIC = 1.0;
		ROUGHNESS = mix(clamp(0.3 + d.r * 0.25 + worn.r * 0.2, 0.26, 0.7), 0.2, edge);
		bent = bend_more(mat_normal_up(sp, n, w, MAT_STEEL_BRUSHED, 0.5), mat_normal(p / 0.22, n, w, MAT_STEEL_WORN, 0.6), n);
	} else if (pommel > 0.0) {
		vec3 lp = p / 0.08;
		vec4 d = mat_data(lp, n, w, MAT_LEATHER_WORN);
		ALBEDO = wood * 0.9 * mix(1.0, mat_shade(lp, n, w, MAT_LEATHER_WORN), 0.5) * (0.7 + 0.3 * d.g);
		METALLIC = 0.0;
		ROUGHNESS = clamp(0.5 + d.r * 0.35, 0.4, 0.9);
		bent = mat_normal(lp, n, w, MAT_LEATHER_WORN, 1.2);
	} else {
		vec3 wp = p / 0.3;
		vec4 d = mat_data_up(wp, n, w, MAT_WOOD_ASH);
		float grain = mat_shade_up(wp, n, w, MAT_WOOD_ASH);
		ALBEDO = wood * mix(1.0, grain, 0.8) * (0.8 + 0.2 * d.g);
		METALLIC = 0.0;
		// Oiled, and polished by the hands.
		ROUGHNESS = clamp(0.45 + d.r * 0.35, 0.4, 0.85);
		bent = mat_normal_up(wp, n, w, MAT_WOOD_ASH, 1.0);
	}
	NORMAL = detail_normal(bent, n, p, VERTEX, NORMAL);
}
