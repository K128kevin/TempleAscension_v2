shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// The wizard's staff, after his concept art: a shaft of silvered metal with
// strands twisted round it, rising to a pale crystal held in a pointed cage.
// Drawn in the staff model's own space (tools/prepare_staff.py: +Y along the
// staff, 0..1, centred on X and Z), so it is fixed to the staff.
uniform vec3 silver : source_color = vec3(0.62, 0.63, 0.66);
uniform vec3 crystal : source_color = vec3(0.82, 0.9, 1.0);
// Where the crystal begins, along the staff.
uniform float crown = 0.86;

varying vec3 local;

float hash(float n) { return fract(sin(n) * 43758.5453); }

void vertex() {
	local = VERTEX;
}

void fragment() {
	float along = local.y;
	float around = atan(local.z, local.x);
	if (along > crown) {
		// The crystal: pale, faintly glowing, brighter at its facets' edges.
		float facet = abs(fract(around / 6.28318 * 4.0) - 0.5);
		ALBEDO = crystal;
		EMISSION = crystal * (0.6 + facet * 0.8);
		METALLIC = 0.0;
		ROUGHNESS = 0.1;
		SPECULAR = 0.9;
	} else {
		// Strands twisting round the shaft: three, wound once every 14cm.
		float twist = fract((around / 6.28318) * 3.0 + along * 13.5);
		float strand = smoothstep(0.0, 0.25, twist) * smoothstep(1.0, 0.75, twist);
		float scratch = hash(floor(along * 400.0) + floor(around * 6.0));
		vec3 color = silver * (0.65 + strand * 0.45) * (0.92 + scratch * 0.1);
		// Darker where the hand wears the grip.
		color *= 1.0 - 0.25 * smoothstep(0.42, 0.5, along) * smoothstep(0.62, 0.54, along);
		ALBEDO = color;
		METALLIC = 0.85;
		ROUGHNESS = mix(0.45, 0.3, strand);
		NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(cos(around), 0.0, sin(around), 0.0)).xyz * (strand - 0.5) * 0.35);
	}
}
