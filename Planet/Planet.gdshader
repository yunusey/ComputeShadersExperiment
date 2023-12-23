shader_type spatial;

instance uniform vec3 color: source_color = vec3(1., .5, .5);
uniform float emission_strength: hint_range(0.0, 20.0, 0.1) = 10.;
uniform sampler2D noise_texture;

void fragment() {
	float brightness = texture(noise_texture, UV).r;
	ALBEDO = color * brightness;
	EMISSION = ALBEDO * emission_strength;
}
