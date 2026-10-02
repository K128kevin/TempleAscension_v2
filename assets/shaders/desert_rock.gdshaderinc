// The basin's rock: a photo scan's own colour and relief, with rock grain
// projected at one size in the world over it (a boulder scaled into a crag
// would otherwise blur), sand lying on its ledges and piled at its foot.
uniform sampler2D albedo_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_map : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 tint = vec3(1.0);
uniform vec3 sand : source_color = vec3(.70,.57,.40);
uniform float detail_scale = .21;
uniform float dust = 1.0;
uniform float alpha = 1.0;
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX*NORMAL);
}

void fragment() {
	vec3 scan = texture(albedo_map,UV).rgb;
	vec3 weight = pow(abs(world_normal),vec3(4.0));
	weight /= weight.x+weight.y+weight.z;
	vec3 p = world_position*detail_scale;
	vec3 detail = texture(detail_map,p.zy).rgb*weight.x+texture(detail_map,p.xz).rgb*weight.y+texture(detail_map,p.xy).rgb*weight.z;
	float grain = dot(detail,vec3(.333));
	vec3 rock = scan*tint*(.5+grain*1.2);
	// Beds of slightly different stone run level through every rock.
	rock *= .86+.28*smoothstep(.35,.65,fract(world_position.y*.21+grain*.6));
	float lying = smoothstep(.6,.92,world_normal.y)*smoothstep(.3,.6,grain+.1)*dust;
	float foot = (1.0-smoothstep(.0,.7,world_position.y+grain*.5))*dust;
	ALBEDO = mix(rock,sand*(.8+grain*.5),clamp(max(lying*.7,foot*.8),0.0,1.0));
	NORMAL_MAP = texture(normal_map,UV).rgb;
	NORMAL_MAP_DEPTH = 1.2;
	ROUGHNESS = .95;
	SPECULAR = .1;
#ifdef FADED
	ALPHA = alpha;
#endif
}
