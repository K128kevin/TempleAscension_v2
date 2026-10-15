// The mountains (scripts/world_mountains.gd): the photographed cliff,
// projected on them from three sides at two sizes so neither repeats, with the
// rim's boulder scan in the gullies, beds of paler and darker stone running
// level through them, grit over all, and sand lying wherever the slope lets
// it settle: on ledges, in the hollows and banked against the foot.
shader_type spatial;
render_mode cull_back;
uniform sampler2D cliff_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cliff_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D boulder_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// The rim's rock is the same stone (desert_rock.gdshader's tints).
uniform vec3 tint = vec3(1.0,.93,.85);
uniform vec3 sand : source_color = vec3(.72,.58,.41);
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX*NORMAL);
}

vec3 triplanar(sampler2D map, vec3 p, vec3 weight) {
	return texture(map,p.zy).rgb*weight.x+texture(map,p.xz).rgb*weight.y+texture(map,p.xy).rgb*weight.z;
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 weight = pow(abs(n),vec3(5.0));
	weight /= weight.x+weight.y+weight.z;
	vec3 p = world_position;
	// The cliff at a crag's size, and again at a whole face's, mixed in patches.
	vec3 near = triplanar(cliff_map,p*.055,weight);
	vec3 broad = triplanar(cliff_map,p*.013+vec3(.37,.11,.71),weight);
	float patch = smoothstep(.3,.7,triplanar(detail_map,p*.006,weight).r*1.8);
	vec3 rock = mix(near,broad,.2+.25*patch);
	// The boulder scan's darker, rougher stone down the gullies.
	vec3 gully = triplanar(boulder_map,p*.07,weight);
	float hollow = smoothstep(.45,.75,triplanar(detail_map,p*.011+vec3(.5),weight).g*1.6);
	rock = mix(rock,gully*.92,hollow*.45);
	float grain = dot(triplanar(detail_map,p*.21,weight),vec3(.333));
	rock *= tint*(.62+grain*.95);
	// Beds of slightly different stone, level, wavering a little.
	float warp = triplanar(detail_map,p*.004+vec3(.2),weight).b;
	float beds = fract(p.y*.045+grain*.5+warp*2.6+sin(p.x*.013+p.z*.011)*.6);
	rock *= .93+.12*smoothstep(.35,.65,beds);
	// Sand settles where the slope is gentle, and banks against the foot.
	vec3 settled = texture(sand_map,p.xz*.29).rgb*sand*1.55;
	float lying = smoothstep(.72,.9,n.y+(grain-.45)*.5);
	float foot = 1.0-smoothstep(-.5,2.5,p.y+(grain-.5)*2.0);
	ALBEDO = mix(rock,settled,clamp(max(lying*.85,foot),0.0,1.0));
	// The cliff's own relief, from whichever side faces the eye most.
	vec3 relief = texture(cliff_normal,p.zy*.055).rgb*weight.x+texture(cliff_normal,p.xz*.055).rgb*weight.y+texture(cliff_normal,p.xy*.055).rgb*weight.z;
	NORMAL_MAP = relief;
	NORMAL_MAP_DEPTH = 1.4*(1.0-lying*.7);
	ROUGHNESS = .95;
	SPECULAR = .12;
}
