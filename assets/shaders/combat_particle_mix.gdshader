shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled, fog_disabled, specular_disabled;

uniform vec4 tint : source_color = vec4(0.42, 0.04, 0.04, 0.92);
uniform float glow = 0.15;
uniform float softness = 1.15;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float radial = length(centered) * 2.0;
	float grain = fract(sin(dot(UV * 7.1, vec2(27.13, 91.7))) * 24634.19);
	float mask = pow(clamp(1.0 - radial, 0.0, 1.0), softness);
	mask *= mix(0.7, 1.0, grain);
	vec3 col = tint.rgb * COLOR.rgb;
	ALBEDO = col;
	EMISSION = col * glow;
	ALPHA = mask * COLOR.a * tint.a;
}
