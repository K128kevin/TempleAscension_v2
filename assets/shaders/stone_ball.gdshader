shader_type spatial;
// The basement's boulders (scripts/basement_puzzle.gd): a photo scan's rock
// laid over the ball three ways in its own space (so that it turns with the
// ball as it rolls, and has no seam or pinched pole as a sphere's UVs
// would), blended by the surface's facing, with finer grain over it and a
// darker grime in its pits.
uniform sampler2D albedo_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_map : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 tint = vec3(1.0);
uniform float scan_scale = .55;
uniform float detail_scale = 1.6;
varying vec3 local_position;
varying vec3 local_normal;

void vertex() {
	local_position = VERTEX;
	local_normal = NORMAL;
}

vec3 three_ways(sampler2D map, vec3 p, vec3 weight) {
	return texture(map,p.zy).rgb*weight.x+texture(map,p.xz).rgb*weight.y+texture(map,p.xy).rgb*weight.z;
}

void fragment() {
	vec3 weight = pow(abs(normalize(local_normal)),vec3(4.0));
	weight /= weight.x+weight.y+weight.z;
	vec3 scan = three_ways(albedo_map,local_position*scan_scale+.37,weight);
	vec3 detail = three_ways(detail_map,local_position*detail_scale,weight);
	float grain = dot(detail,vec3(.333));
	// Pits (where the ball is knobbled in) hold old grime.
	float pit = smoothstep(.97,.88,length(local_position)/.92);
	vec3 rock = scan*tint*(.55+grain*1.1)*(1.0-.35*pit);
	ALBEDO = rock;
	ROUGHNESS = .93;
	SPECULAR = .12;
}
