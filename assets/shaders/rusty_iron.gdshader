shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Old wrought iron (scripts/basement_props.gd gate, key_model): blackened
// iron, hammer-pitted, rusting in blotches and in runs bleeding down from
// where it was wet, flaking orange where the rust is thick. `rust` is how far
// gone it is; `worn` polishes it bright where hands have rubbed it (a key's
// edges); `glint`, a dull gleam along its rims, so a small thing of it (the
// key) catches the eye where it lies in the dark. Patterned in its own
// space, so a swinging leaf keeps its rust.
uniform sampler2D grit : filter_linear_mipmap, repeat_enable;
uniform float rust : hint_range(0.0, 1.0) = 0.7;
uniform float worn : hint_range(0.0, 1.0) = 0.0;
uniform float glint = 0.0;
uniform vec3 iron : source_color = vec3(0.13, 0.125, 0.12);
uniform vec3 rust_dark : source_color = vec3(0.24, 0.11, 0.05);
uniform vec3 rust_bright : source_color = vec3(0.48, 0.23, 0.09);
varying vec3 local_position;
varying vec3 local_normal;

void vertex() {
	local_position = VERTEX;
	local_normal = NORMAL;
}

vec3 triplanar(vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= w.x + w.y + w.z;
	return texture(grit, p.yz).rgb * w.x + texture(grit, p.xz).rgb * w.y + texture(grit, p.xy).rgb * w.z;
}

void fragment() {
	vec3 p = local_position;
	float pits = triplanar(p * 6.0, local_normal).r;
	float blotch = triplanar(p * 0.9 + 0.7, local_normal).g;
	// Runs: the grit stretched down the bars.
	float runs = texture(grit, vec2(p.x * 3.0 + p.z * 3.0, p.y * 0.25)).b;
	float rusted = smoothstep(1.0 - rust, 1.25 - rust * 0.6, blotch * 0.7 + runs * 0.45 + pits * 0.2 - 0.1);
	float flaking = smoothstep(0.55, 0.75, pits) * rusted;
	vec3 colour = mix(iron * (0.75 + 0.5 * pits), mix(rust_dark, rust_bright, flaking), rusted);
	// Bright metal rubbed up on the edges facing out.
	float rubbed = worn * smoothstep(0.4, 0.9, pits) * (1.0 - rusted);
	ALBEDO = mix(colour, vec3(0.42, 0.4, 0.37), rubbed);
	METALLIC = mix(0.75, 0.1, rusted);
	ROUGHNESS = mix(mix(0.48, 0.3, rubbed), 0.92, rusted);
	SPECULAR = 0.5;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	EMISSION = vec3(0.62, 0.52, 0.36) * glint * (0.25 + rim) * (1.0 - rusted);
}
