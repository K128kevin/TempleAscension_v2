shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Polished marble paving for the temple's rooms, drawn procedurally in world
// space so batched tiles stay continuous. One-metre slabs, each cut from a
// different part of the block: its veins run their own way, through a milky
// ground with soft clouding, bold veins with finer hairline veins branching
// off them and faint ghost veins deeper in the stone, and tiny crystalline
// flecks. Each slab's edges are softly bevelled down to a thin joint, so the
// light picks out every slab. Light enough that the dark stone statues read
// clearly against it; the colours are set by `quartz_color` and `vein_color`.
uniform vec3 quartz_color : source_color = vec3(0.70, 0.70, 0.72);
uniform vec3 vein_color : source_color = vec3(0.42, 0.44, 0.47);
// The joint between slabs, and the bevel falling to it (metres).
uniform float grout_width = 0.008;
uniform float bevel_width = 0.035;

#include "quartz.gdshaderinc"

void fragment() {
	// Multimesh-safe world position: VERTEX is view space in fragment().
	vec2 p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	vec2 tile = floor(p + 0.5);
	vec2 inside = fract(p + 0.5) - 0.5;
	float haze;
	float bold;
	float fleck;
	vec3 color = quartz_marble(p, quartz_color, vein_color, haze, bold, fleck);

	// The bevel: within `bevel_width` of an edge the slab's top rounds down
	// to the joint, its face turning out toward that edge.
	vec2 from_edge = 0.5 - abs(inside);
	vec2 outward = sign(inside);
	vec2 slope = vec2(0.0);
	for (int axis = 0; axis < 2; axis++) {
		float d = from_edge[axis];
		float u = clamp((bevel_width - d) / max(bevel_width - grout_width, 0.0001), 0.0, 1.0);
		// A rounded profile: flat at the top, steepening toward the edge.
		slope[axis] = outward[axis] * u * u * 1.6;
	}
	float d_edge = min(from_edge.x, from_edge.y);
	// The joint, its edge softened by a pixel's width so thin joints far off
	// stay unbroken lines rather than dashes.
	float aa = fwidth(d_edge);
	float joint = 1.0 - smoothstep(grout_width - aa, grout_width + aa, d_edge);
	// The bevel catches dust and a little shade toward the joint.
	float lip = 1.0 - smoothstep(grout_width, bevel_width, d_edge);
	color = mix(color, color * 0.86, lip * 0.5);
	color = mix(color, quartz_color * 0.32, joint);

	ALBEDO = color;
	// The imported paving mesh carves small cobbles; polished slabs are flat,
	// so shade the top as one surface, turned only by the bevels.
	vec3 n = normalize(vec3(slope.x, 1.0, slope.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ROUGHNESS = mix(0.3 + haze * 0.12 + bold * 0.1, 0.9, max(joint, lip * 0.3)) - fleck * 0.15;
	SPECULAR = 0.5;
	METALLIC = 0.0;
}
