shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, shadows_disabled, fog_disabled, specular_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.86, 0.7, 1.0);
uniform float intensity = 0.8;

void fragment() {
	vec3 col = tint.rgb;
	ALBEDO = col;
	EMISSION = col * (1.4 * intensity);
	ALPHA = intensity * 0.42;
}
